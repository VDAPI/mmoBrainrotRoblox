--!strict
-- Template animation: the timing of the effects a keyed action releases (Data/MotionFx; client/Vfx/MotionFx draws
-- them). A mark sits on the action's timeline exactly like a key (Logic/MotionTimeline: the anticipation stretched to
-- the server's windup, the strike ending on its hit W), so a release lands on the frame the pose lets go. Also which
-- element and reach an action carries (its ability's, else the kind's own) and whether an attack's animation draws its
-- own gather and release (the generic ones of Controllers/CombatFxController are then left out). Pure (Lune).

local Bosses = require("../Data/Bosses")
local MonsterAbilities = require("../Data/MonsterAbilities")
local Monsters = require("../Data/Monsters")
local MotionFx = require("../Data/MotionFx")

local ActionFx = {}

-- A one-shot first seen this late after its mark (a monster that came into view mid-action) is skipped, s.
ActionFx.LATE = 0.25

export type Timed = { strike: number, follow: number, recover: number }
export type Bound = { element: string?, radius: number?, ability: string?, magic: boolean? }

-- Seconds from the action's start to `mark` (hit at `hit`): the segments of Logic/MotionTimeline.segments.
function ActionFx.time(action: Timed, hit: number, mark: MotionFx.Mark): number
	local s = math.min(action.strike, hit * 0.7)
	local seg, u = mark.seg, mark.u
	if seg == "A" then
		return math.max(0, hit - s) * u
	elseif seg == "S" then
		return math.max(0, hit - s) + s * u
	elseif seg == "F" then
		return hit + action.follow * u
	end
	return hit + action.follow + action.recover * u
end

-- When an effect starts and (a stream) stops, seconds from the action's start; a one-shot's end is its start.
function ActionFx.window(action: Timed, hit: number, fx: MotionFx.Fx): (number, number)
	local t0 = ActionFx.time(action, hit, fx.from)
	local to = fx.to
	local t1 = if to then ActionFx.time(action, hit, to) else t0
	return t0, math.max(t0, t1)
end

-- Whether a one-shot at `t0` fires in the frame from `last` (nil: the first frame of this run) to `t`: crossed in this
-- frame, or reached before the first frame by less than LATE.
function ActionFx.due(t0: number, last: number?, t: number): boolean
	if t < t0 then
		return false
	end
	if last == nil then
		return t - t0 <= ActionFx.LATE
	end
	return last < t0
end

-- Whether a stream from `t0` to `t1` runs at `t` (one first seen mid-way starts there).
function ActionFx.running(t0: number, t1: number, t: number): boolean
	return t >= t0 and t < t1
end

local function abilityOf(id: string?, bossId: string?): (string?, number?)
	if not id then
		return nil, nil
	end
	local boss = if bossId then Bosses.get(bossId) else nil
	if boss then
		for _, attack in boss.attacks do
			if attack.id == id then
				return attack.element, attack.radius
			end
		end
	end
	local own = MonsterAbilities.get(id)
	if own then
		return own.element, own.radius
	end
	return nil, nil
end

-- The element and reach an action of a kind carries: `ability` (the attack the server sent) when it has them, else
-- the boss attack or the kind's ability the style plays with this action; a monster's action without an element takes
-- the kind's own (a regular shot: the wyvern's fire spit; a fire golem's slam), else its school (Data/MotionFx.SCHOOLS:
-- the dark casters' violet). `abilities` is the style's ability -> action map. Also the ability it found (a bone nova
-- throws bones) and whether the kind's blows are magic (an orb to throw, not a rock).
function ActionFx.bound(kindId: string?, abilities: { [string]: string }, actionName: string, ability: string?): Bound
	local bossId = if kindId and Bosses.get(kindId) then kindId else nil
	local element, radius = abilityOf(ability, bossId)
	local used = if element or radius then ability else nil
	local boss = if bossId then Bosses.get(bossId) else nil
	local def = if kindId and not boss then Monsters.get(kindId) else nil
	if not used and boss then
		for _, attack in boss.attacks do
			if abilities[attack.id] == actionName and (attack.element or attack.radius) then
				element, radius, used = attack.element, attack.radius, attack.id
				break
			end
		end
	elseif not used and def then
		local own = def.ability
		if own and abilities[own] == actionName then
			element, radius = abilityOf(own, nil)
			used = own
		end
	end
	if not boss then
		element = element or (def and def.element) or (kindId and MotionFx.SCHOOLS.kinds[kindId])
		element = element or (used and MotionFx.SCHOOLS.abilities[used])
	end
	return {
		element = element,
		radius = radius,
		ability = used or ability,
		magic = def ~= nil and def.damageKind == "magic",
	}
end

-- Whether the animation of attack `attackId` (an ability id, or an action name: a boss pattern's gesture) of a style
-- draws its own gather and its own release (Data/MotionFx KINDS).
function ActionFx.claims(styleId: string, abilities: { [string]: string }, attackId: string?): (boolean, boolean)
	if not attackId then
		return false, false
	end
	local list = MotionFx.get(styleId, abilities[attackId] or attackId)
	if not list then
		return false, false
	end
	local gather, release = false, false
	for _, fx in list do
		local kind = MotionFx.KINDS[fx.kind]
		if kind then
			gather = gather or kind.gather == true
			release = release or kind.release == true
		end
	end
	return gather, release
end

return ActionFx
