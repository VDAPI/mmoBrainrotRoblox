--!strict
-- W02: the asset kit (Data/Kit, Logic/KitPick) and the kit slots of the generators (Logic/TownGen/Blueprint).

local Blueprint = require("../src/shared/Logic/TownGen/Blueprint")
local Kit = require("../src/shared/Data/Kit")
local KitPick = require("../src/shared/Logic/KitPick")
local Maps = require("../src/shared/Data/Maps")
local Test = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

local FOLDERS = { common = true }
for _, map in Maps.byId do
	FOLDERS[map.biome] = true
end

-- Every slot key the generators draw (W02 inventory; W12 the city), collected once.
local generated: { [string]: number } = {}
for _, b in TownGen.all(Town.city, TownTerrain.heightAt) do
	for _, slot in (b.bp :: any).kits do
		generated[slot.key] = (generated[slot.key] or 0) + 1
	end
end
for _, mapId in WorldGen.maps() do
	local gen = assert(WorldGen.get(mapId))
	for _, b in gen.all() do
		for _, slot in b.bp.kits do
			generated[slot.key] = (generated[slot.key] or 0) + 1
		end
	end
end

describe("Asset kit data (W02)", function()
	it("names only slot keys the generators draw, fits and sizes in range", function()
		for key, entry in Kit.slots do
			expect(`{key} {generated[key] ~= nil}`).toBe(`{key} true`)
			expect(`{key} {entry.fit == "height" or entry.fit == "width"}`).toBe(`{key} true`)
			expect(`{key} {entry.size > 0 and entry.size <= 60}`).toBe(`{key} true`)
		end
	end)

	it("keeps every variant list on a biome of Data/Maps with sane weights, scales and names", function()
		for key, entry in Kit.slots do
			for biome, list in entry :: any do
				if biome == "fit" or biome == "size" then
					continue
				end
				local label = `{key}/{biome}`
				expect(`{label} {biome == "default" or FOLDERS[biome] == true}`).toBe(`{label} true`)
				expect(`{label} {#list > 0}`).toBe(`{label} true`)
				for _, v in list :: { Kit.Variant } do
					local folder, prefab = string.match(v.model, "^(%l+)_(%l+)_%d%d$")
					local ok = folder ~= nil
						and FOLDERS[folder] == true
						and prefab ~= nil
						and v.weight > 0
						and v.scale[1] >= 0.5
						and v.scale[2] <= 2
						and v.scale[1] <= v.scale[2]
						and (v.sink == nil or (v.sink >= 0 and v.sink < 0.6))
						and (v.tint == nil or string.match(v.tint, "^#%x%x%x%x%x%x$") ~= nil)
					expect(`{label} {v.model} {ok}`).toBe(`{label} {v.model} true`)
				end
			end
		end
	end)
end)

describe("Kit pick (W02)", function()
	it("is deterministic and depends on the position", function()
		local a = assert(KitPick.pick("tree:oak", "grass", 120.3, -455.7, 1.1))
		local b = assert(KitPick.pick("tree:oak", "grass", 120.3, -455.7, 1.1))
		expect(a.variant.model).toBe(b.variant.model)
		expect(a.size).toBe(b.size)
		expect(a.yaw).toBe(b.yaw)
		local models: { [string]: boolean } = {}
		for i = 1, 60 do
			local c = assert(KitPick.pick("tree:oak", "grass", i * 37.1, i * -13.3, 1))
			models[c.variant.model] = true
			expect(c.yaw >= 0 and c.yaw < 360).toBe(true)
		end
		local n = 0
		for _ in models do
			n += 1
		end
		expect(n >= 3).toBe(true)
	end)

	it("scales with the slot and stays inside the variant's range", function()
		local entry = Kit.slots["tree:pine"]
		for i = 1, 40 do
			local s = 0.8 + i * 0.01
			local c = assert(KitPick.pick("tree:pine", "grass", i * 11, i * 7, s))
			local extra = c.size / (entry.size * s)
			expect(extra >= c.variant.scale[1] - 1e-9 and extra <= c.variant.scale[2] + 1e-9).toBe(true)
		end
	end)

	it("leaves unknown keys and biomes without a list to the generator", function()
		expect(KitPick.pick("tree:nothing", "grass", 0, 0, 1) == nil).toBe(true)
		expect(KitPick.pick("tree:oak", "desert", 0, 0, 1) == nil).toBe(true)
	end)

	it("hashes into [0, 1) the same way for negative coordinates", function()
		for i = -20, 20 do
			local h = KitPick.hash("rock", i * 13.7, i * -9.1)
			expect(h >= 0 and h < 1).toBe(true)
		end
	end)
end)

describe("Kit slots of the generators (W02)", function()
	it("does not change the pieces a Blueprint draws", function()
		local function draw(slotted: boolean): { any }
			local bp = Blueprint.new(42)
			for i = 1, 5 do
				if slotted then
					bp:beginKit("rock", i, 0, 0, 1, "shell")
				end
				bp:box(1 + bp.rng:float(0, 1), 1, 1, i, 0.5, 0, { c = "#808080", m = "Slate", lod = "shell" })
				if slotted then
					bp:endKit()
				end
			end
			return bp.pieces
		end
		local plain, slotted = draw(false), draw(true)
		expect(#plain).toBe(#slotted)
		for i, p in plain do
			local q = slotted[i]
			expect(p.size[1]).toBe(q.size[1])
			expect(p.c).toBe(q.c)
			expect(p.k == nil).toBe(true)
			expect(q.k).toBe(i)
		end
	end)

	it("keeps nested slots in the outer one", function()
		local bp = Blueprint.new(1)
		bp:beginKit("tree:oak", 0, 0, 0, 1, "shell")
		bp:box(1, 1, 1, 0, 0, 0, { c = "#808080", m = "Wood" })
		bp:beginKit("rock", 0, 0, 0, 1, "shell")
		bp:box(1, 1, 1, 0, 0, 0, { c = "#808080", m = "Slate" })
		bp:endKit()
		bp:box(1, 1, 1, 0, 0, 0, { c = "#808080", m = "Wood" })
		bp:endKit()
		bp:box(1, 1, 1, 0, 0, 0, { c = "#808080", m = "Wood" })
		expect(#bp.kits).toBe(1)
		expect(bp.pieces[1].k).toBe(1)
		expect(bp.pieces[2].k).toBe(1)
		expect(bp.pieces[3].k).toBe(1)
		expect(bp.pieces[4].k == nil).toBe(true)
	end)

	it("marks the trees, bushes and rocks of every region", function()
		for _, key in { "tree:oak", "tree:pine", "rock", "under:bush", "tree:darkPine", "tree:snowPine" } do
			expect(`{key} {(generated[key] or 0) > 0}`).toBe(`{key} true`)
		end
	end)
end)
