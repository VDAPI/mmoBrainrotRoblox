--!strict
-- S134h: every Elite II drops only its own 2-3 slot groups (Data/LootTables.ELITE2_SLOTS through LootTables.slotsFor):
-- known groups, a kind is an Elite II in at most one place of the world, the two of a cave share no group, in every
-- band of ELITE2_BANDS the Elite IIs together drop all nine groups, weapons from at least two Elite IIs of a region,
-- and Loot.rollMonsterLoot keeps to it (the same kind as an Elite or a normal monster, and an Elite II outside the
-- table, drop every group).

local Areas = require("../src/shared/Data/Areas")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Items = require("../src/shared/Data/Items")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local Monsters = require("../src/shared/Data/Monsters")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local GROUPS = LootTables.slotGroups

-- Every Elite II spawner of the world's places (S134h: the caves; S134i adds its hideouts here).
local function elite2Spawners(): { { place: string, region: string, kind: string, min: number, max: number } }
	local out = {}
	for _, cave in Areas.caves.list do
		for _, s in AreaSpawns.cave(cave) do
			if s.variant == "elite2" then
				table.insert(
					out,
					{ place = cave.id, region = cave.region, kind = s.monster, min = s.level.min, max = s.level.max }
				)
			end
		end
	end
	return out
end

local function groupOf(defId: string): string
	local def = assert(Items.get(defId), defId)
	return assert(def.slot, defId)
end

describe("Elite II loot (S134h)", function()
	it("gives every Elite II kind of the caves 2-3 known slot groups, no group twice", function()
		expect(#GROUPS).toBe(9)
		for _, s in elite2Spawners() do
			local groups = LootTables.ELITE2_SLOTS[s.kind]
			expect(`{s.kind} {groups ~= nil}`).toBe(`{s.kind} true`)
			local list = assert(groups, s.kind)
			expect(#list >= 2 and #list <= 3).toBe(true)
			local seen = {}
			for _, g in list do
				expect(`{s.kind} {g} {table.find(GROUPS, g) ~= nil and not seen[g]}`).toBe(`{s.kind} {g} true`)
				seen[g] = true
			end
			expect(Monsters.get(s.kind) ~= nil).toBe(true)
		end
		for kind in LootTables.ELITE2_SLOTS do
			expect(`{kind} {Monsters.get(kind) ~= nil}`).toBe(`{kind} true`)
		end
	end)

	it("makes a kind an Elite II in at most one place of the world", function()
		local placeOf: { [string]: string } = {}
		for _, s in elite2Spawners() do
			local other = placeOf[s.kind]
			if other and other ~= s.place then
				error(`{s.kind} is an Elite II in {other} and {s.place}`)
			end
			placeOf[s.kind] = s.place
		end
	end)

	it("keeps the two Elite IIs of a cave apart in kind and loot", function()
		for _, cave in Areas.caves.list do
			expect(#cave.elite2).toBe(2)
			local a, b = cave.elite2[1], cave.elite2[2]
			expect(a ~= b).toBe(true)
			for _, g in LootTables.ELITE2_SLOTS[a] or {} do
				expect(`{cave.id} {g} {table.find(LootTables.ELITE2_SLOTS[b] or {}, g) == nil}`).toBe(
					`{cave.id} {g} true`
				)
			end
		end
	end)

	it("covers all nine slot groups in every level band", function()
		expect(#LootTables.ELITE2_BANDS).toBe(8)
		local spawners = elite2Spawners()
		for _, band in LootTables.ELITE2_BANDS do
			local got: { [string]: boolean } = {}
			local n = 0
			for _, s in spawners do
				if s.max >= band[1] and s.min <= band[2] then
					n += 1
					for _, g in LootTables.ELITE2_SLOTS[s.kind] or {} do
						got[g] = true
					end
				end
			end
			expect(n >= 2).toBe(true)
			for _, g in GROUPS do
				expect(`{band[1]}-{band[2]} {g} {got[g] == true}`).toBe(`{band[1]}-{band[2]} {g} true`)
			end
		end
	end)

	it("lets at least two Elite IIs of every region drop weapons", function()
		local weapons: { [string]: number } = {}
		for _, s in elite2Spawners() do
			if table.find(LootTables.ELITE2_SLOTS[s.kind] or {}, "weapon") then
				weapons[s.region] = (weapons[s.region] or 0) + 1
			end
		end
		for _, region in { "meadows", "duskwood", "ashen", "frostpeak" } do
			expect(`{region} {(weapons[region] or 0) >= 2}`).toBe(`{region} true`)
		end
	end)

	it("cuts DEFAULT_SLOTS to the kind's groups for its Elite II only (one function for every reader)", function()
		local w = LootTables.slotsFor("goblinScout", "elite2")
		local n = 0
		for g, weight in w do
			n += 1
			expect(weight).toBe(LootTables.defaultSlots[g])
			expect(table.find(LootTables.ELITE2_SLOTS.goblinScout, g) ~= nil).toBe(true)
		end
		expect(n).toBe(#LootTables.ELITE2_SLOTS.goblinScout)
		expect(LootTables.slotsFor("goblinScout", "elite")).toEqual(LootTables.defaultSlots)
		expect(LootTables.slotsFor("goblinScout", "normal")).toEqual(LootTables.defaultSlots)
		expect(LootTables.slotsFor("wolf", "elite2")).toEqual(LootTables.defaultSlots)
		expect(LootTables.elite2Groups("goblinScout")).toEqual({ "offhand", "helmet", "gloves" })
		expect(#LootTables.elite2Groups("wolf")).toBe(9)
	end)

	it("rolls only the assigned groups for an Elite II, every group for the same kind as an Elite or normal", function()
		local function groupsOf(kind: string, variant: string, rolls: number, seed: number): { [string]: number }
			local rng = Rng.new(seed)
			local out: { [string]: number } = {}
			for _ = 1, rolls do
				local result = Loot.rollMonsterLoot(kind, variant, 40, rng, { classId = "Mage", dropLevel = 40 })
				for _, item in result.items do
					local g = groupOf(item.defId)
					out[g] = (out[g] or 0) + 1
				end
			end
			return out
		end
		local own = groupsOf("necromancer", "elite2", 2000, 13401)
		local n = 0
		for g in own do
			n += 1
			expect(`{g} {table.find(LootTables.ELITE2_SLOTS.necromancer, g) ~= nil}`).toBe(`{g} true`)
		end
		expect(n).toBe(#LootTables.ELITE2_SLOTS.necromancer)
		for _, variant in { "elite", "normal" } do
			local all = groupsOf("necromancer", variant, 2000, 13402)
			for _, g in GROUPS do
				expect(`{variant} {g} {(all[g] or 0) > 0}`).toBe(`{variant} {g} true`)
			end
		end
		-- an Elite II outside the table (an event's): DEFAULT_SLOTS
		expect(LootTables.ELITE2_SLOTS.wolf).toBeNil()
		local event = groupsOf("wolf", "elite2", 2000, 13403)
		for _, g in GROUPS do
			expect(`wolf {g} {(event[g] or 0) > 0}`).toBe(`wolf {g} true`)
		end
	end)
end)
