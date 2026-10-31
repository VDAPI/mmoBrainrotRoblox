--!strict
-- W09: how a Roblox hairstyle (Data/BodyLooks.hairs) takes the hair colour of the look. The texture of a light hair is
-- multiplied by the colour (SurfaceAppearance.Color), lifted a little toward white so the strands keep their light;
-- a black texture keeps its strands under a dark colour and gives way to the plain colour for a light one (a black
-- texture times any colour stays black: still used by the brows). Hair fixes 2026-10-31: a hair whose texture has its
-- own colour (`tone`: dark, red, pink) keeps the texture and has only its hue nudged toward the colour (`nudge`); a
-- tint can only darken, so such a hair offers just the colours its texture reaches (`reach`, REACH). Pure.

local HairTint = {}

-- Colours with a luminance below this keep a black texture.
HairTint.DARK = 0.22
-- How far the tint of a light texture moves toward white (less for a colour darker than DARK).
HairTint.LIFT = 0.3
-- A toned hair offers a colour when the colour is at most this many times brighter than its texture in any channel
-- (the nudged hair then has at least 1 / REACH of the colour's brightness, in its hue).
HairTint.REACH = 1.5
-- A texture channel below this counts as this (a pure black channel would need an endless multiplier).
local FLOOR = 0.02

-- r, g, b of a "#RRGGBB" colour, in 0..1.
local function channels(hex: string): (number, number, number)
	local s = string.gsub(hex, "#", "")
	local r = tonumber(string.sub(s, 1, 2), 16) or 0
	local g = tonumber(string.sub(s, 3, 4), 16) or 0
	local b = tonumber(string.sub(s, 5, 6), 16) or 0
	return r / 255, g / 255, b / 255
end
HairTint.channels = channels

function HairTint.luminance(hex: string): number
	local r, g, b = channels(hex)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

-- CIE L*a*b* (D65) of a "#RRGGBB" colour.
local function lab(hex: string): (number, number, number)
	local function linear(c: number): number
		return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
	end
	local function f(t: number): number
		return if t > 0.008856 then t ^ (1 / 3) else 7.787 * t + 16 / 116
	end
	local r, g, b = channels(hex)
	r, g, b = linear(r), linear(g), linear(b)
	local x = f((0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047)
	local y = f(0.2126 * r + 0.7152 * g + 0.0722 * b)
	local z = f((0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883)
	return 116 * y - 16, 500 * (x - y), 200 * (y - z)
end

-- How far apart two hair colours look: the L*a*b* distance with the lightness at half weight, so a dark range keeps
-- the hue of a light colour (grey to the neutral dark brown, blond to the lightest warm one, not to red).
function HairTint.distance(a: string, b: string): number
	local l1, a1, b1 = lab(a)
	local l2, a2, b2 = lab(b)
	return math.sqrt(((l1 - l2) * 0.5) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end

-- The multiplier per channel that turns a texture of colour `tone` into the colour `hex`.
local function ratio(hex: string, tone: string): (number, number, number)
	local r, g, b = channels(hex)
	local tr, tg, tb = channels(tone)
	return r / math.max(tr, FLOOR), g / math.max(tg, FLOOR), b / math.max(tb, FLOOR)
end

-- How many times brighter than the texture `tone` the colour `hex` is in its brightest channel (1 or less: the tint
-- reaches the colour exactly).
function HairTint.reach(hex: string, tone: string): number
	local r, g, b = ratio(hex, tone)
	return math.max(r, g, b)
end

-- The tint (r, g, b in 0..1) of a texture of colour `tone` for the colour `hex`: the colour's own hue at the colour's
-- brightness, or as near it as a darkening tint goes (scaled down by the reach).
function HairTint.nudge(hex: string, tone: string): { number }
	local r, g, b = ratio(hex, tone)
	local k = math.max(r, g, b, 1)
	return { r / k, g / k, b / k }
end

-- "texture": keep the hair's texture, tinted by `tint` (r, g, b in 0..1); "flat": no texture, the plain colour.
-- `tone` (the texture's own colour) nudges the texture and never goes flat.
function HairTint.plan(hex: string, light: boolean, tone: string?): ("texture" | "flat", { number })
	if tone then
		return "texture", HairTint.nudge(hex, tone)
	end
	local r, g, b = channels(hex)
	if light then
		-- Studio review 2026-10-31: the lift fades out below DARK, so black reads black and not dark grey
		local t = HairTint.LIFT * math.min(1, HairTint.luminance(hex) / HairTint.DARK)
		return "texture", { r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t }
	end
	if HairTint.luminance(hex) < HairTint.DARK then
		return "texture", { 1, 1, 1 }
	end
	return "flat", { r, g, b }
end

return HairTint
