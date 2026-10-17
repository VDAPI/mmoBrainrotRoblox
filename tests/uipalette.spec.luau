--!strict
-- S135 "Parchment and iron": every colour pair of the interface palette (Data/UiPalette.PAIRS) meets its WCAG minimum
-- (Logic/Contrast), the rarity colours have readable parchment / night variants, the class and element colours can be
-- made readable on both surfaces, Logic/Contrast gives the numbers the wiki used before (S44), and Logic/TextCase
-- upper-cases Polish letters.

local Classes = require("../src/shared/Data/Classes")
local Contrast = require("../src/shared/Logic/Contrast")
local Elements = require("../src/shared/Data/Elements")
local LevelBand = require("../src/shared/Logic/LevelBand")
local Rarities = require("../src/shared/Data/Rarities")
local T = require("./Test")
local TextCase = require("../src/shared/Logic/TextCase")
local TokensCss = require("../tools/WikiData/TokensCss")
local UiPalette = require("../src/shared/Data/UiPalette")

local describe, it, expect = T.describe, T.it, T.expect

local function isHex(hex: any): boolean
	return type(hex) == "string" and string.match(hex, "^#%x%x%x%x%x%x$") ~= nil
end

describe("UiPalette (S135)", function()
	it("has the same roles, all hex, on both surfaces", function()
		for _, name in UiPalette.SURFACES do
			local s = (UiPalette :: any)[name]
			for role, hex in UiPalette.paper :: any do
				expect(isHex(s[role])).toBe(true)
				expect(isHex(hex)).toBe(true)
			end
		end
		for _, group in { UiPalette.brass, UiPalette.resource, UiPalette.zone, UiPalette.currency, UiPalette.pvp } do
			for _, hex in group :: any do
				expect(isHex(hex)).toBe(true)
			end
		end
	end)

	it("keeps the mock-up's parchment, ink and iron", function()
		expect(UiPalette.paper.surface).toBe("#EFE3C6")
		expect(UiPalette.paper.text).toBe("#2A2016")
		expect(UiPalette.iron.surface).toBe("#2A2016")
		expect(UiPalette.iron.raised).toBe("#3B2E1C")
		expect(UiPalette.iron.text).toBe("#F3E6C4")
		expect(UiPalette.brass.line).toBe("#B89B5E")
		expect(UiPalette.brass.frame).toBe("#4A3A24")
	end)

	it("every pair meets its minimum (text 4.5:1, edges 3:1)", function()
		expect(#UiPalette.PAIRS > 90).toBe(true)
		local failed = {}
		for _, pair in UiPalette.PAIRS do
			local ratio = Contrast.contrast(pair.fg, pair.bg)
			if ratio < pair.min then
				table.insert(failed, `{pair.what}: {string.format("%.2f", ratio)} < {pair.min}`)
			end
		end
		expect(table.concat(failed, "; ")).toBe("")
	end)

	it("covers every text role on every background of both surfaces", function()
		local seen: { [string]: boolean } = {}
		for _, pair in UiPalette.PAIRS do
			seen[pair.what] = true
		end
		for _, name in UiPalette.SURFACES do
			for _, bg in UiPalette.BACKGROUNDS do
				for _, fg in UiPalette.TEXT_ROLES do
					expect(seen[`{name}.{fg} on {name}.{bg}`]).toBe(true)
				end
			end
			expect(seen[`{name}.accentText on {name}.accent`]).toBe(true)
			expect(seen[`{name}.border on {name}.raised`]).toBe(true)
		end
	end)
end)

describe("S136 pairs: HUD tiles, plates, medals, chat", function()
	local function seen(): { [string]: boolean }
		local out = {}
		for _, pair in UiPalette.PAIRS do
			out[pair.what] = true
		end
		return out
	end

	it("covers the HUD tile, plates, marks, groups, medals, chat and glyphs", function()
		local s = seen()
		for _, role in UiPalette.TEXT_ROLES do
			expect(s[`iron.{role} on the HUD tile`]).toBe(true)
		end
		for _, key in { "normal", "elite", "elite2", "boss" } do
			expect(s[`plate.{key} on the HUD tile`]).toBe(true)
		end
		for key in UiPalette.mark :: { [string]: string } do
			expect(s[`mark.{key} on the HUD tile`]).toBe(true)
		end
		for i in UiPalette.group do
			expect(s[`group[{i}] on the plate badge`]).toBe(true)
		end
		for key in UiPalette.medal :: { [string]: string } do
			expect(s[`medal.{key} on iron.raised`]).toBe(true)
		end
		for _, key in { "trade", "party", "guild", "whisper" } do
			expect(s[`chat.{key} on chat.window`]).toBe(true)
		end
		for key in UiPalette.glyph :: { [string]: string } do
			expect(s[`glyph.{key} on iron.surface`]).toBe(true)
			expect(s[`glyph.{key} on the HUD tile`]).toBe(true)
		end
		for _, key in { "hp", "mana", "energy", "exp" } do
			expect(s[`resource.{key} on resource.track`]).toBe(true)
		end
	end)

	it("mixes the HUD tile with the brightest world", function()
		local hud = Contrast.mix(UiPalette.iron.surface, UiPalette.WORLD_BRIGHT, UiPalette.HUD_ALPHA)
		expect(hud ~= UiPalette.iron.surface).toBe(true)
		expect(Contrast.contrast(UiPalette.iron.text, hud) >= UiPalette.MIN_TEXT).toBe(true)
		expect(UiPalette.HUD_ALPHA > 0 and UiPalette.HUD_ALPHA <= 0.2).toBe(true)
		expect(UiPalette.HUD_TILES[1]).toBe(hud)
	end)

	it("makes data colours readable on the HUD tiles (Theme.readable 'hud')", function()
		-- Theme.readableHex(hex, "hud") = readableOn over the iron backgrounds plus HUD_TILES
		local list = {}
		for _, role in UiPalette.BACKGROUNDS do
			table.insert(list, (UiPalette.iron :: any)[role])
		end
		for _, tile in UiPalette.HUD_TILES do
			table.insert(list, tile)
		end
		for _, hex in { UiPalette.glyph.enemy, UiPalette.map.event, "#E0564A", "#D84A3E" } do
			local out = Contrast.readableOn(hex, list, UiPalette.MIN_TEXT)
			for _, tile in UiPalette.HUD_TILES do
				expect(Contrast.contrast(out, tile) >= UiPalette.MIN_TEXT).toBe(true)
			end
		end
	end)

	it("keeps gold out of parchment text: the medals pass only on iron", function()
		expect(Contrast.contrast(UiPalette.medal.gold, UiPalette.paper.surface) < UiPalette.MIN_TEXT).toBe(true)
		expect(Contrast.contrast(UiPalette.medal.gold, UiPalette.iron.raised) >= UiPalette.MIN_TEXT).toBe(true)
	end)
end)

describe("Rarity colours on parchment and iron (S135)", function()
	it("names on parchment >= 4.5:1 on the page and the slot, on iron >= 4.5:1, frames on the slot >= 3:1", function()
		for _, r in Rarities.list do
			expect(Contrast.contrast(r.textHex, UiPalette.paper.surface) >= 4.5).toBe(true)
			expect(Contrast.contrast(r.textHex, UiPalette.paper.raised) >= 4.5).toBe(true)
			expect(Contrast.contrast(r.nightHex, UiPalette.iron.surface) >= 4.5).toBe(true)
			expect(Contrast.contrast(r.paperHex, UiPalette.paper.raised) >= 3).toBe(true)
		end
	end)

	it("keeps the S30 ladder as the identity colours", function()
		local hexes = {}
		for _, r in Rarities.list do
			table.insert(hexes, r.hex)
		end
		expect(table.concat(hexes, " ")).toBe("#9DA3AB #F2D33A #3D8BFF #FF9F1C #E5302A")
	end)
end)

describe("Game-data colours made readable (S135)", function()
	it(
		"class, element and level-band colours reach 4.5:1 on every background role after Contrast.readableOn",
		function()
			local colours: { string } = {}
			for _, id in Classes.order do
				table.insert(colours, (Classes.get(id) :: any).color)
			end
			for _, hex in Elements.COLORS do
				table.insert(colours, hex)
			end
			for _, hex in LevelBand.COLORS do
				table.insert(colours, hex)
			end
			for _, hex in colours do
				for _, name in UiPalette.SURFACES do
					local s = (UiPalette :: any)[name]
					local backgrounds: { string } = {}
					for _, role in UiPalette.BACKGROUNDS do
						table.insert(backgrounds, s[role])
					end
					local fixed = Contrast.readableOn(hex, backgrounds, UiPalette.MIN_TEXT)
					for _, bg in backgrounds do
						expect(Contrast.contrast(fixed, bg) >= UiPalette.MIN_TEXT).toBe(true)
					end
				end
			end
		end
	)
end)

describe("Logic/Contrast (S135, moved from the wiki S44)", function()
	it("gives the WCAG numbers", function()
		expect(Contrast.contrast("#FFFFFF", "#000000")).toBeNear(21, 0.001)
		expect(Contrast.contrast("#B8423A", "#EFE3C6")).toBeNear(4.25, 0.01)
		expect(Contrast.contrast("#2A2016", "#EFE3C6")).toBeNear(12.51, 0.01)
		expect(Contrast.contrast("#C9A45C", "#EFE3C6") < 2).toBe(true)
	end)

	it("matches the wiki's readable colours (tokens.data.css before S135)", function()
		expect(TokensCss.readable("#F2D33A", TokensCss.PANEL_LIGHT, "#000000")).toBe("#72631B")
		expect(TokensCss.readable("#FF9F1C", TokensCss.PANEL_LIGHT, "#000000")).toBe("#8C570F")
		expect(TokensCss.readable("#F2D33A", TokensCss.PANEL_DARK, "#FFFFFF")).toBe("#F2D33A")
		expect(Contrast.readable("#F2D33A", TokensCss.PANEL_LIGHT, TokensCss.MIN_CONTRAST)).toBe("#72631B")
	end)

	it("mixes channels", function()
		expect(Contrast.mix("#000000", "#FFFFFF", 0.5)).toBe("#808080")
		expect(Contrast.mix("#102030", "#102030", 0.3)).toBe("#102030")
	end)
end)

describe("Logic/TextCase (S135)", function()
	it("upper-cases Polish letters and ASCII", function()
		expect(TextCase.upper("łąki, źródło, żółć")).toBe("ŁĄKI, ŹRÓDŁO, ŻÓŁĆ")
		expect(TextCase.upper("Ranga 6/10 · ęń ś")).toBe("RANGA 6/10 · ĘŃ Ś")
		expect(TextCase.upper("abc XYZ 123")).toBe("ABC XYZ 123")
	end)
end)
