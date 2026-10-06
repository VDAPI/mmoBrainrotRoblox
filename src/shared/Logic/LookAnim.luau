--!strict
-- Animation clip choice for real monster models (S24, `asset.rig = "animator"`). Pure: the client tells what
-- the monster is doing and which clips the model has; this picks the slot, whether it loops, the fade time and
-- the playback speed.
--   priority : death > hit > attack1 / attack2 / cast > run / walk > idle; spawn plays once at the start
--   fallback : run -> walk -> idle, attack2 -> attack1, cast -> attack1, spawn -> idle; without hit / death
--              nothing plays (the client flashes / fades instead)
--   speed    : walk / run play at monster speed / asset.walkSpeed (clamped 0.5..2)

local LookAnim = {}

export type State = {
	dead: boolean?,
	hit: boolean?, -- took damage in the last moment
	attack: ("attack1" | "attack2" | "cast")?,
	speed: number, -- studs per second
	runAbove: number?, -- speed from which "run" is used (default 14)
	spawning: boolean?, -- first moments after appearing
	walkSpeed: number?, -- speed the walk clip was authored for (asset.walkSpeed, default 10)
}

export type Pick = { slot: string, looped: boolean, fade: number, speed: number }

LookAnim.SLOTS = { "idle", "walk", "run", "attack1", "attack2", "cast", "hit", "death", "spawn" }

local FALLBACK: { [string]: { string } } = {
	run = { "run", "walk", "idle" },
	walk = { "walk", "idle" },
	idle = { "idle" },
	attack1 = { "attack1" },
	attack2 = { "attack2", "attack1" },
	cast = { "cast", "attack1" },
	spawn = { "spawn", "idle" },
	hit = { "hit" },
	death = { "death" },
}

local function first(slot: string, available: { [string]: boolean }): string?
	local list: { string } = FALLBACK[slot] or { slot }
	for _, candidate in list do
		if available[candidate] then
			return candidate
		end
	end
	return nil
end

-- Clip for the state, or nil when nothing should play (the model keeps its last pose / the client fades it).
function LookAnim.pick(state: State, available: { [string]: boolean }): Pick?
	if state.dead then
		local slot = first("death", available)
		return if slot then { slot = slot, looped = false, fade = 0.1, speed = 1 } else nil
	end
	if state.hit then
		local slot = first("hit", available)
		if slot then
			return { slot = slot, looped = false, fade = 0.05, speed = 1 }
		end
	end
	if state.attack then
		local slot = first(state.attack, available)
		if slot then
			return { slot = slot, looped = false, fade = 0.08, speed = 1 }
		end
	end
	if state.spawning then
		local slot = first("spawn", available)
		if slot then
			return { slot = slot, looped = slot == "idle", fade = 0.1, speed = 1 }
		end
	end
	local moving = state.speed > 0.5
	if moving then
		local wanted = if state.speed >= (state.runAbove or 14) then "run" else "walk"
		local slot = first(wanted, available)
		if slot then
			local authored = state.walkSpeed or 10
			local speed = if slot == "idle" then 1 else math.clamp(state.speed / math.max(authored, 0.1), 0.5, 2)
			return { slot = slot, looped = true, fade = 0.2, speed = speed }
		end
		return nil
	end
	local slot = first("idle", available)
	return if slot then { slot = slot, looped = true, fade = 0.25, speed = 1 } else nil
end

return LookAnim
