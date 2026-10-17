--!strict
-- wiki/src/styles/tokens.data.css (S34): colours from the game data under the design system's names
-- (wiki/design/vaelthorn.css): --vw-r-<key> and --vw-glow-<key> per rarity KEY (--vw-r-0/1/2 are radii), a text
-- variant --vw-r-<key>-text with WCAG contrast >= 5.5:1 on --vw-panel (S44; AA on tinted surfaces too) (lighter in the dark theme, darker in
-- [data-theme="light"]), --vw-el-<id> from Data/Elements (--vw-el-physical stays in tokens.css), --vw-class-<id>
-- from Data/Classes and --vw-zone-green|yellow|red from Data/UiPalette.zone (S135; before: Theme.luau as text).

local Basics = require("./Basics")
local Classes = require("../../src/shared/Data/Classes")
local Contrast = require("../../src/shared/Logic/Contrast")
local Clean = require("./Clean")
local Elements = require("../../src/shared/Data/Elements")
local Places = require("./Places")
local Rarities = require("../../src/shared/Data/Rarities")

local TokensCss = {}

TokensCss.HEADER = "/* GENEROWANE przez tools/wikidump.luau — nie edytuj (kolory z danych gry). */"
TokensCss.PANEL_DARK = "#1B1D23" -- --vw-panel in wiki/design/vaelthorn.css
TokensCss.PANEL_LIGHT = "#FBF8F1" -- --vw-panel in [data-theme="light"]
TokensCss.MIN_CONTRAST = 5.5 -- S44: AA also on the tinted chips and callouts (colour-mixed backgrounds)

local rgb = Contrast.rgb

-- WCAG 2 relative luminance and contrast ratio (S135: the formula lives in src/shared/Logic/Contrast).
TokensCss.luminance = Contrast.luminance
TokensCss.contrast = Contrast.contrast

-- The colour mixed towards `target` (white or black) until it reaches the contrast on `background`.
function TokensCss.readable(hex: string, background: string, target: string): string
	return Contrast.readable(hex, background, TokensCss.MIN_CONTRAST, target)
end

-- Glow of a rarity like the design system: stronger with the rarity (index 0 = Common).
function TokensCss.glow(hex: string, index: number): string
	local r, g, b = rgb(hex)
	local blur = 12 + 6 * index
	local alpha = 0.10 + 0.045 * index
	local parts = { "0 0 0 1px #14161B", string.format("0 0 %dpx rgba(%d,%d,%d,%.2f)", blur, r, g, b, alpha) }
	if index >= 3 then
		table.insert(
			parts,
			string.format(
				"0 0 %dpx rgba(%d,%d,%d,%.2f)",
				if index >= 4 then 72 else 2,
				r,
				g,
				b,
				if index >= 4 then 0.10 else 0.6
			)
		)
	end
	return table.concat(parts, ", ")
end

function TokensCss.generate(ctx: any): string
	local dark, light = {}, {}
	for i, r in Rarities.list do
		local readableDark = TokensCss.readable(r.hex, TokensCss.PANEL_DARK, "#FFFFFF")
		local readableLight = TokensCss.readable(r.hex, TokensCss.PANEL_LIGHT, "#000000")
		table.insert(dark, `  --vw-r-{r.key}: {string.upper(r.hex)};`)
		table.insert(dark, `  --vw-r-{r.key}-text: {readableDark};`)
		table.insert(dark, `  --vw-glow-{r.key}: {TokensCss.glow(r.hex, i - 1)};`)
		table.insert(light, `  --vw-r-{r.key}: {readableLight};`)
		table.insert(light, `  --vw-r-{r.key}-text: {readableLight};`)
	end
	for _, id in Clean.keys(Elements.COLORS) do
		local hex = Elements.COLORS[id]
		table.insert(dark, `  --vw-el-{id}: {string.upper(hex)};`)
		table.insert(light, `  --vw-el-{id}: {TokensCss.readable(hex, TokensCss.PANEL_LIGHT, "#000000")};`)
	end
	for _, id in Classes.order do
		local c = Classes.get(id) :: any
		table.insert(dark, `  --vw-class-{id}: {string.upper(c.color)};`)
		table.insert(light, `  --vw-class-{id}: {TokensCss.readable(c.color, TokensCss.PANEL_LIGHT, "#000000")};`)
	end
	local zones = Basics.zoneColors()
	for _, zone in { "green", "yellow", "red" } do
		table.insert(dark, `  --vw-zone-{zone}: {zones[zone]};`)
		table.insert(light, `  --vw-zone-{zone}: {TokensCss.readable(zones[zone], TokensCss.PANEL_LIGHT, "#000000")};`)
	end
	-- S37: map sketch colours (raw game values; wiki/src/styles/map.css tones them for each theme).
	local readText = ctx.readText
	local sketch = if readText then readText("src/client/UI/MapSketch.luau") else nil
	for _, c in Places.sketchColors(sketch, ctx.warnings) do
		table.insert(dark, `  --vw-map-{c.name}: {c.hex};`)
	end
	return table.concat({
		TokensCss.HEADER,
		':root, [data-theme="dark"] {',
		table.concat(dark, "\n"),
		"}",
		'[data-theme="light"] {',
		table.concat(light, "\n"),
		"}",
		"",
	}, "\n")
end

return TokensCss
