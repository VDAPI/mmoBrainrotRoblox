--!strict
-- Colours of monster groups by the number of living members (S19, DESIGN §15.1): 1 grey-white, 2 green,
-- 3 orange, 4 red. Used by the ground rings, the "xN" plate badge and the minimap dots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local GroupColors = {}

-- S136: the values live in Data/UiPalette.group (the plate badge pair is contrast-tested on iron)
local COLORS: { Color3 } = {}
for i, hex in UiPalette.group do
	COLORS[i] = Theme.tint(hex)
end

function GroupColors.of(size: number?): Color3
	return COLORS[math.clamp(math.floor(size or 1), 1, #COLORS)]
end

return GroupColors
