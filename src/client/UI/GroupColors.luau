--!strict
-- Colours of monster groups by the number of living members (S19, DESIGN §15.1): 1 grey-white, 2 green,
-- 3 orange, 4 red. Used by the ground rings, the "xN" plate badge and the minimap dots.

local GroupColors = {}

local COLORS = {
	Color3.fromHex("#C9CED6"),
	Color3.fromHex("#4FD16B"),
	Color3.fromHex("#FF9F1C"),
	Color3.fromHex("#E5484D"),
}

function GroupColors.of(size: number?): Color3
	return COLORS[math.clamp(math.floor(size or 1), 1, #COLORS)]
end

return GroupColors
