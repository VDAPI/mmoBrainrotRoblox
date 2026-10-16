--!strict
-- S134h: the underground maps (caves, crypts, boss chambers) stay readable without their lamps, also on a phone with
-- low graphics: every preset bright enough, a light ambient in the preset's hue, long fog, thin atmosphere; more lamps
-- on the lowest setting and a soft light on the player (Config.CaveLights).

local Config = require("../src/shared/Config")
local Maps = require("../src/shared/Data/Maps")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local UNDERGROUND = { cave = true, crypt = true, dungeon = true }

local function linear(c: number): number
	c /= 255
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

-- Relative luminance (sRGB) of "#RRGGBB".
local function luminance(hex: string): number
	local r, g, b =
		tonumber(string.sub(hex, 2, 3), 16), tonumber(string.sub(hex, 4, 5), 16), tonumber(string.sub(hex, 6, 7), 16)
	return 0.2126 * linear(assert(r, hex)) + 0.7152 * linear(assert(g, hex)) + 0.0722 * linear(assert(b, hex))
end

describe("Underground light (S134h)", function()
	it("keeps every underground preset readable without its lamps", function()
		local n = 0
		for id, map in Maps.byId do
			if UNDERGROUND[map.biome] then
				n += 1
				local l = map.lighting
				local label = `{id}`
				expect(`{label} {l.brightness >= 0.8}`).toBe(`{label} true`)
				expect(`{label} {luminance(l.ambient) >= 0.10}`).toBe(`{label} true`)
				expect(`{label} {luminance(l.outdoorAmbient) >= 0.06}`).toBe(`{label} true`)
				expect(`{label} {l.fogEnd >= 380}`).toBe(`{label} true`)
				expect(`{label} {l.atmosphere.density <= 0.42}`).toBe(`{label} true`)
				expect(`{label} {l.atmosphere.haze <= 0.4}`).toBe(`{label} true`)
			end
		end
		expect(n >= 16).toBe(true)
	end)

	it("lights more lamps on the lowest setting and gives the player a soft light", function()
		local lights = Config.CaveLights :: any
		expect(lights.low >= 12).toBe(true)
		expect(lights.low <= lights.mid and lights.mid <= lights.high).toBe(true)
		local p = lights.player
		expect(p.range > 0 and p.range <= 40).toBe(true)
		expect(p.brightness > 0 and p.brightness <= 1.5).toBe(true)
		expect(type(p.color) == "string" and #p.color == 7).toBe(true)
	end)
end)
