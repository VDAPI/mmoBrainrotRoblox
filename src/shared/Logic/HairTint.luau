--!strict
-- W09: how a Roblox hairstyle (Data/BodyLooks.hairs) takes the hair colour of the look. The texture of a light hair is
-- multiplied by the colour (SurfaceAppearance.Color), lifted a little toward white so the strands keep their light;
-- a black texture keeps its strands under a dark colour and gives way to the plain colour for a light one (a black
-- texture times any colour stays black). Pure.

local HairTint = {}

-- Colours with a luminance below this keep a black texture.
HairTint.DARK = 0.22
-- How far the tint of a light texture moves toward white.
HairTint.LIFT = 0.3

local function channels(hex: string): (number, number, number)
	local s = string.gsub(hex, "#", "")
	local r = tonumber(string.sub(s, 1, 2), 16) or 0
	local g = tonumber(string.sub(s, 3, 4), 16) or 0
	local b = tonumber(string.sub(s, 5, 6), 16) or 0
	return r / 255, g / 255, b / 255
end

function HairTint.luminance(hex: string): number
	local r, g, b = channels(hex)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

-- "texture": keep the hair's texture, tinted by `tint` (r, g, b in 0..1); "flat": no texture, the plain colour.
function HairTint.plan(hex: string, light: boolean): ("texture" | "flat", { number })
	local r, g, b = channels(hex)
	if light then
		local t = HairTint.LIFT
		return "texture", { r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t }
	end
	if HairTint.luminance(hex) < HairTint.DARK then
		return "texture", { 1, 1, 1 }
	end
	return "flat", { r, g, b }
end

return HairTint
