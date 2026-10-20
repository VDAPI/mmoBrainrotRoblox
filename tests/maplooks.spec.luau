--!strict
-- W01: the look of every map (Data/MapLooks) and the graphics levels (Config.Graphics).

local Config = require("../src/shared/Config")
local MapLooks = require("../src/shared/Data/MapLooks")
local Maps = require("../src/shared/Data/Maps")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function hex(value: string): boolean
	return string.match(value, "^#%x%x%x%x%x%x$") ~= nil
end

describe("Map looks (W01)", function()
	it("gives every map a look within range", function()
		for id in Maps.byId do
			local look = MapLooks.of(id)
			local label = id
			local ok = hex(look.sunColor)
				and look.bloom.intensity >= 0
				and look.bloom.intensity <= 1
				and look.bloom.threshold >= 0.8
				and look.bloom.threshold <= 1.4
				and look.bloom.size >= 8
				and look.bloom.size <= 56
				and look.sunRays >= 0
				and look.sunRays <= 0.2
				and math.abs(look.contrast) <= 0.3
				and math.abs(look.brightness) <= 0.2
				and look.farBlur >= 0
				and look.farBlur <= 0.4
				and (look.clock == nil or (look.clock >= 0 and look.clock < 24))
			expect(`{label} {ok}`).toBe(`{label} true`)
			local clouds = look.clouds
			if clouds then
				local c = clouds.cover >= 0 and clouds.cover <= 1 and clouds.density >= 0 and clouds.density <= 1
				expect(`{label} clouds {c and hex(clouds.color)}`).toBe(`{label} clouds true`)
			end
		end
	end)

	it("keeps sun rays, clouds and far blur off underground", function()
		for id, map in Maps.byId do
			if MapLooks.isUnderground(map.biome) then
				local look = MapLooks.of(id)
				local ok = look.sunRays == 0 and look.clouds == nil and look.farBlur == 0
				expect(`{id} {ok}`).toBe(`{id} true`)
			end
		end
	end)

	it("runs the day and night cycle only in the city (owner's decision)", function()
		local cycling = {}
		for id, map in Maps.byId do
			if map.dayNight and MapLooks.of(id).clock == nil and not map.hidden then
				table.insert(cycling, id)
			end
		end
		table.sort(cycling)
		expect(table.concat(cycling, ",")).toBe("city")
	end)

	it("names painted skies that exist, each with six image ids (0 = not uploaded)", function()
		for id, look in MapLooks.byMap do
			for _, key in { look.painted, look.paintedNight } do
				expect(`{id} {key} {MapLooks.paintedSkies[key :: string] ~= nil}`).toBe(`{id} {key} true`)
			end
		end
		for key, sky in MapLooks.paintedSkies do
			local n = 0
			for _, face in { "bk", "dn", "ft", "lf", "rt", "up" } do
				local value = (sky.ids :: any)[face]
				if type(value) == "number" and value >= 0 and value == math.floor(value) then
					n += 1
				end
			end
			expect(`{key} {n}`).toBe(`{key} 6`)
		end
	end)

	it("shows a painted sky only once all six ids are in, the night one at night", function()
		local skies = MapLooks.paintedSkies :: any
		local saved = { day = skies.miastoDzien.ids, night = skies.miastoNoc.ids }
		local full = { bk = 1, dn = 2, ft = 3, lf = 4, rt = 5, up = 6 }
		local city = MapLooks.of("city")
		skies.miastoDzien.ids = { bk = 1, dn = 2, ft = 3, lf = 4, rt = 5, up = 0 }
		expect(MapLooks.paintedSky(city, 12) == nil).toBe(true)
		skies.miastoDzien.ids = full
		expect(MapLooks.paintedSky(city, 12)).toBe("miastoDzien")
		-- night without its own sky: the place's sky, never the day one
		expect(MapLooks.paintedSky(city, 22) == nil).toBe(true)
		skies.miastoNoc.ids = full
		expect(MapLooks.paintedSky(city, 22)).toBe("miastoNoc")
		expect(MapLooks.paintedSky(city, 5)).toBe("miastoNoc")
		expect(MapLooks.paintedSky(city, 6.5)).toBe("miastoDzien")
		skies.miastoDzien.ids, skies.miastoNoc.ids = saved.day, saved.night
	end)

	it("only overrides maps that exist", function()
		for id in MapLooks.byMap do
			expect(`{id} {Maps.get(id) ~= nil}`).toBe(`{id} true`)
		end
	end)
end)

describe("Graphics levels (W01)", function()
	it("defines low, medium and high with every field", function()
		local levels = Config.Graphics.levels :: any
		for _, name in { "low", "medium", "high" } do
			local level = levels[name]
			expect(`{name} {level ~= nil}`).toBe(`{name} true`)
			expect(type(level.bloom)).toBe("number")
			expect(type(level.sunRays)).toBe("boolean")
			expect(type(level.clouds)).toBe("boolean")
			expect(type(level.farBlur)).toBe("boolean")
			expect(type(level.particles)).toBe("number")
		end
		expect(levels[Config.Graphics.default] ~= nil).toBe(true)
	end)

	it("turns the expensive effects off on low and keeps the S14 particle third", function()
		local low = Config.Graphics.levels.low
		expect(low.bloom).toBe(0)
		expect(low.sunRays).toBe(false)
		expect(low.clouds).toBe(false)
		expect(low.farBlur).toBe(false)
		expect(low.particles).toBeNear(1 / 3, 1e-9)
		expect(Config.Graphics.levels.high.particles).toBe(1)
	end)

	it("keeps the top camera inside its zoom range", function()
		local c = Config.Camera
		expect(c.topMin < c.topDefault and c.topDefault < c.topMax).toBe(true)
		expect(c.underMax > c.topMin).toBe(true)
		expect(c.topPitch > 0 and c.topPitch < 90 and c.underPitch > 0 and c.underPitch <= c.topPitch).toBe(true)
	end)
end)
