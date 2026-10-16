--!strict
-- S134e: what an Elite / Elite II with a kit (Data/MonsterAbilities.KITS) does next, and the numbers of its blows.
-- Pure: Entities/Monster gathers the state and acts on the answer, CombatService multiplies a lethal blow, the balance
-- model (tests/Balance.elite2Kite) reads the same rules. No Roblox API.
--
--   pick      the kit's abilities in order (each ready, in its range, a kiteOnly one only at a fleeing target), then
--             the monster's own ability (in reach of its area, as before S134e), then the throw at a fleeing target;
--             no ability within the kit's globalGap after the last blow (the throw is a regular attack: it may come)
--   canLand   whether a leaping monster may land on a point (not in a safe zone, within its hard leash)
--   firstReady when an ability is first ready after the fight starts
--   lethalMul the extra multiplier of a lethal blow from the monster's level advantage (gapRamp)

local MonsterAbilities = require("../Data/MonsterAbilities")

local MonsterCast = {}

export type State = {
	now: number,
	distance: number, -- flat studs to the target
	reach: number, -- the monster's melee reach (range + half its size)
	outOfReachFor: number, -- seconds the target has been out of reach (0 in reach)
	ready: { [string]: boolean }, -- ability id -> off cooldown (kit and own)
	lastCast: number, -- when the last ability landed (-math.huge = never)
	kit: MonsterAbilities.Kit,
	own: MonsterAbilities.Ability?,
	throwReady: boolean?, -- the throw's interval has passed
}

-- Whether the target counts as fleeing (out of reach for the kit's kiteSeconds).
function MonsterCast.fleeing(kit: MonsterAbilities.Kit, outOfReachFor: number): boolean
	local seconds = kit.kiteSeconds
	return seconds ~= nil and outOfReachFor >= seconds
end

-- The farthest target an ability may be announced at: its castRange, else the old rule (the reach or the area's size).
function MonsterCast.rangeOf(ability: MonsterAbilities.Ability, reach: number): number
	if ability.castRange then
		return ability.castRange
	end
	return math.max(reach, ability.radius or ability.length or 10)
end

-- Whether `ability` may be cast at a target `distance` away now.
local function usable(ability: MonsterAbilities.Ability, state: State, fleeing: boolean): boolean
	if state.ready[ability.id] ~= true then
		return false
	end
	if ability.kiteOnly and not fleeing then
		return false
	end
	if ability.minRange and state.distance < ability.minRange then
		return false
	end
	return state.distance <= MonsterCast.rangeOf(ability, state.reach)
end

-- The next action: an ability id, "throw" or nil (walk / regular blow).
function MonsterCast.pick(state: State): string?
	local kit = state.kit
	local fleeing = MonsterCast.fleeing(kit, state.outOfReachFor)
	if state.now - state.lastCast >= kit.globalGap then
		for _, id in kit.abilities do
			local ability = MonsterAbilities.get(id)
			if ability and usable(ability, state, fleeing) then
				return id
			end
		end
		local own = state.own
		if own and usable(own, state, fleeing) then
			return own.id
		end
	end
	local throw = kit.throw
	if throw and fleeing and state.throwReady and state.distance <= throw.range then
		return "throw"
	end
	return nil
end

-- Whether a leap may land on a point: not in a safe zone (`safe`, ctx.isSafePosition) and within the hard leash
-- (`distHome` = flat studs from the monster's home, `leashMax`). Plain numbers: the module runs in Lune.
function MonsterCast.canLand(safe: boolean, distHome: number, leashMax: number): boolean
	return not safe and distHome <= leashMax
end

-- The extra multiplier of a lethal blow of a monster `monsterLevel` on a player `playerLevel`: 1 + perLevel per level
-- of the monster's advantage from `from` on, up to maxSteps levels (from 6 levels Damage.levelGap adds its own); 1
-- for a blow without `lethal` / `gapRamp` and for a player at or above the monster's level.
function MonsterCast.lethalMul(ability: MonsterAbilities.Ability, monsterLevel: number, playerLevel: number): number
	if not ability.lethal then
		return 1
	end
	return MonsterCast.gapMul(ability.gapRamp, monsterLevel, playerLevel)
end

-- A gap ramp's multiplier (lethal blows, the kit's throw): 1 + perLevel per level of the monster's advantage from
-- `from` on, counted up to maxSteps levels; 1 without a ramp and for a player at or above the monster.
function MonsterCast.gapMul(ramp: MonsterAbilities.GapRamp?, monsterLevel: number, playerLevel: number): number
	if not ramp then
		return 1
	end
	local steps = math.clamp(monsterLevel - playerLevel - ramp.from + 1, 0, ramp.maxSteps)
	return 1 + steps * ramp.perLevel
end

-- S134e: the multiplier of the kit's throw on a player of `playerLevel` (its damage x its gap ramp).
function MonsterCast.throwMul(throw: MonsterAbilities.ThrowSpec, monsterLevel: number, playerLevel: number): number
	return throw.damage * MonsterCast.gapMul(throw.gapRamp, monsterLevel, playerLevel)
end

-- The seconds after the fight starts an ability is first ready (its firstAfter, else 3-6 s), `roll` in 0..1.
function MonsterCast.firstReady(ability: MonsterAbilities.Ability, roll: number): number
	local span = ability.firstAfter or { 3, 6 }
	return span[1] + (span[2] - span[1]) * roll
end

return MonsterCast
