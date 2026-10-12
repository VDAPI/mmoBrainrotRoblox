--!strict
-- When a channel ends early (S70, ROZWOJ 14.1, 16.6). One pure rule set for every kind of channel; the
-- Hunter's aiming (castTime, S76) and the Mage's beams add their kinds here.
-- kind "channel" (Prayer, Evocation): moving, death and damage end it; damage does not with def.steadfast.
-- A new cast also ends it, but SkillService does that before every cast, outside this table.

local Channel = {}

export type Event = "damage" | "move" | "death"

-- `def` is the channelled skill after Logic/Skills.effective (ctx.skill).
function Channel.stops(kind: string, event: Event, def: { steadfast: boolean? }?): boolean
	if kind == "channel" then
		if event == "damage" then
			return not (def and def.steadfast)
		end
		return true -- "move", "death"
	end
	return true -- unknown kind: stop, to be safe
end

return Channel
