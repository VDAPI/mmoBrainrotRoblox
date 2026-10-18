--!strict
-- "18:50": a time of day as hours and minutes (S149b). In the player's own time by default (os.date: the client's
-- clock zone), in UTC with `utc`. The one helper for the tournament, the world boss's map, card and reward screen.

local ClockText = {}

function ClockText.hhmm(t: number, utc: boolean?): string
	local d = os.date(if utc then "!*t" else "*t", math.floor(t))
	return string.format("%02d:%02d", d.hour, d.min)
end

return ClockText
