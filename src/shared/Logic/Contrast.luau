--!strict
-- S135: WCAG 2 colour contrast on hex strings ("#RRGGBB"), pure (Lune, wiki, client). Moved from
-- tools/WikiData/TokensCss (S44) so the game palette (Data/UiPalette), its test and the wiki share one formula.
--   luminance(hex)                       relative luminance 0..1
--   contrast(a, b)                       ratio 1..21
--   mix(a, b, t)                         a mixed towards b by t (0..1), rounded per channel
--   readable(hex, background, min, target?)
--                                        hex mixed towards white or black (or `target`) in 1 % steps until it reaches
--                                        `min` on `background`; unchanged (upper case) when it already does
--   readableOn(hex, backgrounds, min)    readable on every background of a list (all light or all dark: the roles of
--                                        one surface), so a colour corrected once holds on raised / selected rows too

local Contrast = {}

local function rgb(hex: string): (number, number, number)
	local r, g, b = string.match(hex, "^#(%x%x)(%x%x)(%x%x)$")
	assert(r and g and b, `Contrast: bad colour {hex}`)
	return tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number
end

local function hexOf(r: number, g: number, b: number): string
	local function c(x: number): number
		return math.clamp(math.floor(x + 0.5), 0, 255)
	end
	return string.format("#%02X%02X%02X", c(r), c(g), c(b))
end

Contrast.rgb = rgb
Contrast.hexOf = hexOf

function Contrast.luminance(hex: string): number
	local r, g, b = rgb(hex)
	local function channel(v: number): number
		local s = v / 255
		return if s <= 0.03928 then s / 12.92 else ((s + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

function Contrast.contrast(a: string, b: string): number
	local la, lb = Contrast.luminance(a), Contrast.luminance(b)
	local hi, lo = math.max(la, lb), math.min(la, lb)
	return (hi + 0.05) / (lo + 0.05)
end

function Contrast.mix(a: string, b: string, t: number): string
	local ar, ag, ab = rgb(a)
	local br, bg, bb = rgb(b)
	return hexOf(ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t)
end

-- Towards white on a dark background, towards black on a light one (unless `target` says otherwise).
function Contrast.readable(hex: string, background: string, min: number, target: string?): string
	if Contrast.contrast(hex, background) >= min then
		return string.upper(hex)
	end
	local towards = target or (if Contrast.luminance(background) < 0.18 then "#FFFFFF" else "#000000")
	for step = 1, 100 do
		local mixed = Contrast.mix(hex, towards, step / 100)
		if Contrast.contrast(mixed, background) >= min then
			return mixed
		end
	end
	return string.upper(towards)
end

-- Each pass only moves further towards black (light backgrounds) or white (dark ones), so a background met earlier
-- stays met.
function Contrast.readableOn(hex: string, backgrounds: { string }, min: number): string
	local out = string.upper(hex)
	for _, background in backgrounds do
		out = Contrast.readable(out, background, min)
	end
	return out
end

return Contrast
