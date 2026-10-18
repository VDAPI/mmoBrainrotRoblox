--!strict
-- Fury of the Warrior (ROZWOJ 10.4; S143: Rage of the two-handed pool, DESIGN-18 §6.2): pure stack rules. The server
-- keeps one State per player (StatusEffectService) and passes Data/Paths HOOK_RULES.fury as the rules; times are
-- os.clock() seconds. Every function returns a new table and never changes its input.

local Fury = {}

export type Rules = { gainInterval: number, decayAfter: number, decayPerSecond: number }

export type State = {
	stacks: number,
	base: number, -- stacks when the decay clock last restarted (a hit, Carnage, set)
	quietSince: number, -- the last hit (or Carnage step, or set): decay starts decayAfter seconds later
	lastGain: number, -- when a stack was last gained (gainInterval throttle); -math.huge = never
}

function Fury.new(): State
	return { stacks = 0, base = 0, quietSince = 0, lastGain = -math.huge }
end

-- A hit that dealt damage: +amount (1; Carnage: HOOK_RULES.carnage.furyGain) up to max, at most one gain per
-- gainInterval. The decay clock restarts even when nothing was gained (at max or throttled).
function Fury.gain(state: State, now: number, max: number, amount: number, rules: Rules): State
	if max <= 0 then
		return { stacks = 0, base = 0, quietSince = now, lastGain = state.lastGain }
	end
	local stacks = math.min(state.stacks, max)
	local lastGain = state.lastGain
	if stacks < max and now - lastGain >= rules.gainInterval then
		stacks = math.min(max, stacks + amount)
		lastGain = now
	end
	return { stacks = stacks, base = stacks, quietSince = now, lastGain = lastGain }
end

-- Time passing. Out of combat or with max <= 0: a new (empty) state. Carnage (`frozen`) holds the stacks and
-- restarts the decay clock. Otherwise, decayAfter seconds after quietSince the stacks fall from `base` by
-- decayPerSecond per second (one stack every 0.5 s with the default rules).
function Fury.step(state: State, now: number, max: number, inCombat: boolean, frozen: boolean, rules: Rules): State
	if not inCombat or max <= 0 then
		return Fury.new()
	end
	local stacks = math.min(state.stacks, max)
	local base = math.min(state.base, max)
	if frozen then
		return { stacks = stacks, base = stacks, quietSince = now, lastGain = state.lastGain }
	end
	local elapsed = now - state.quietSince - rules.decayAfter
	if elapsed <= 0 then
		return { stacks = stacks, base = base, quietSince = state.quietSince, lastGain = state.lastGain }
	end
	local lost = math.floor(elapsed * rules.decayPerSecond + 1e-9)
	return {
		stacks = math.max(0, math.min(stacks, base - lost)),
		base = base,
		quietSince = state.quietSince,
		lastGain = state.lastGain,
	}
end

-- Spends every stack (furyConsume, S73): the new state and how many were spent.
function Fury.consume(state: State): (State, number)
	return { stacks = 0, base = 0, quietSince = state.quietSince, lastGain = state.lastGain }, state.stacks
end

-- S143 (DESIGN-18 §6.2): the Fury cap of a character. Fury exists only with Rage (the two-handed school's passive, hook
-- `rage` > 0); then the furyMax hook (Rage and the Berserker's nodes), at most maxStacks. Without Rage: 0 (no Fury, so
-- the Fury nodes and furyConsume do nothing).
function Fury.cap(furyMax: number, rage: number, maxStacks: number): number
	if rage <= 0 then
		return 0
	end
	return math.clamp(math.floor(furyMax), 0, maxStacks)
end

-- S143: the stacks one damaging hit gives: the skill's furyGain (Brutal Strike 2; default 1) or Carnage's gain while it
-- lasts, whichever is larger.
function Fury.hitGain(skillGain: number?, carnage: boolean, carnageGain: number): number
	return math.max(skillGain or 1, if carnage then carnageGain else 1)
end

-- S143 (Unstoppable): the hook works only at full Fury (stacks == the cap, the cap above 0).
function Fury.unstoppable(hook: number, stacks: number, max: number): boolean
	return hook > 0 and max > 0 and stacks >= max
end

-- Sets the stacks (furyRestore, S75), clamped to 0..max; the decay clock restarts at `now`.
function Fury.set(state: State, now: number, stacks: number, max: number): State
	local s = math.clamp(math.floor(stacks), 0, math.max(0, max))
	return { stacks = s, base = s, quietSince = now, lastGain = state.lastGain }
end

return table.freeze(Fury)
