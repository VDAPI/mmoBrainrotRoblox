--!strict
-- When a channel ends early (S70, ROZWOJ 14.1, 16.6). One pure rule set for every kind of channel; the
-- Hunter's aiming (castTime, S76) and the Mage's beams (S80) add their kinds here.
-- kind "channel" (Prayer, Evocation): moving, death and damage end it; damage does not with def.steadfast, moving
-- does not with def.channelMove (S79). Another cast ends it (S80: event "cast", asked by SkillService).
-- castTime (S76, ROZWOJ 11.3 / 14.3): aiming before the shot. Moving or being stunned ends it and gives the cost
-- and the skill's cooldown back; damage never ends it (steadfast or not). Returns (stop, refund).
-- beam (S80, ROZWOJ 12.5 / 14.4 / 15.5.8): Arcane Torrent. Damage never ends it; a stun or freeze, a knockback,
-- moving away (unless def.channelMove), losing the target, the target out of range, no mana for a tick or another
-- cast do. Nothing is given back (the cooldown stays).
-- Leaving the character is not an event: SkillService ends every channel then without asking.

local Config = require("../Config")

local Channel = {}

-- S80: knockback (the caster was knocked back or pulled, Push.Moved), cast (another skill was cast), target (the
-- beam's target died, vanished or stopped being an enemy), range (the target is out of the beam's reach), noMana (no
-- mana for the next tick)
export type Event = "damage" | "move" | "death" | "disabled" | "knockback" | "cast" | "target" | "range" | "noMana"

type Def = { steadfast: boolean?, channelMove: number? }

-- `def` is the channelled skill after Logic/Skills.effective (ctx.skill). The second result: give the cost and the
-- skill's cooldown back (only aiming does).
function Channel.stops(kind: string, event: Event, def: Def?): (boolean, boolean)
	local walks = def ~= nil and (def.channelMove or 0) > 0
	if kind == "channel" then
		-- S79: channelMove (Evocation 5B in S81) lets the caster walk; the client slows the walk to channelMove %
		-- (the cast event of the channel carries `mv`, S80)
		if event == "move" and walks then
			return false, false
		end
		if event == "damage" then
			return not (def and def.steadfast), false
		end
		if event == "disabled" then
			return false, false -- Focus and Prayer as before S76
		end
		if event == "knockback" then
			return false, false -- the move check catches a push, as before S80
		end
		if event == "target" or event == "range" or event == "noMana" then
			return false, false
		end
		return true, false -- "move", "death", "cast"
	end
	if kind == "castTime" then
		if event == "move" or event == "disabled" then
			return true, true
		end
		if event == "death" then
			return true, false
		end
		-- damage never; another cast is refused before (S76); a push is caught by the move check
		return false, false
	end
	if kind == "beam" then
		if event == "damage" then
			return false, false -- ROZWOJ 15.5.8: damage never breaks the Torrent
		end
		if event == "move" then
			return not walks, false
		end
		return true, false -- disabled, knockback (with channelMove too), cast, target, range, noMana, death
	end
	return true, false -- unknown kind: stop, to be safe
end

-- Every event of one check counts: the first in `events` that stops the channel wins, so a stunned Prayer still ends
-- when it is pushed away. Returns (event, refund); nil when none stops it.
function Channel.firstStop(kind: string, events: { string }, def: Def?): (Event?, boolean)
	for _, name in events do
		local event: Event = name :: any -- an array of literals widens to string in the type checker
		local stop, refund = Channel.stops(kind, event, def)
		if stop then
			return event, refund
		end
	end
	return nil, false
end

-- Did moving `distance` studs from the start end this channel? (Config.Skills.channelMoveLimit)
function Channel.afterMove(kind: string, distance: number, def: Def?): boolean
	if distance <= Config.Skills.channelMoveLimit then
		return false
	end
	return (Channel.stops(kind, "move", def))
end

return Channel
