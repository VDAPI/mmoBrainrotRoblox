--!strict
-- When a channel ends early (S70, ROZWOJ 14.1, 16.6). One pure rule set for every kind of channel; the
-- Hunter's aiming (castTime, S76) and the Mage's beams add their kinds here.
-- kind "channel" (Prayer, Evocation): moving, death and damage end it; damage does not with def.steadfast, moving
-- does not with def.channelMove (S79).
-- A new cast also ends it, but SkillService does that before every cast, outside this table.
-- castTime (S76, ROZWOJ 11.3 / 14.3): aiming before the shot. Moving or being stunned ends it and gives the cost
-- and the skill's cooldown back; damage never ends it (steadfast or not). Returns (stop, refund).

local Channel = {}

export type Event = "damage" | "move" | "death" | "disabled"

-- `def` is the channelled skill after Logic/Skills.effective (ctx.skill). The second result: give the cost and the
-- skill's cooldown back (only aiming does).
function Channel.stops(
	kind: string,
	event: Event,
	def: { steadfast: boolean?, channelMove: number? }?
): (boolean, boolean)
	if kind == "channel" then
		-- S79: channelMove (Evocation 5B in S81, Torrent 5B in S80) lets the caster walk; the client slows the walk to
		-- channelMove % (cast event of the channel, S80)
		if event == "move" and def and (def.channelMove or 0) > 0 then
			return false, false
		end
		if event == "damage" then
			return not (def and def.steadfast), false
		end
		if event == "disabled" then
			return false, false -- Focus and Prayer as before S76
		end
		return true, false -- "move", "death"
	end
	if kind == "castTime" then
		if event == "damage" then
			return false, false
		end
		if event == "death" then
			return true, false
		end
		return true, true -- "move", "disabled"
	end
	return true, false -- unknown kind: stop, to be safe
end

return Channel
