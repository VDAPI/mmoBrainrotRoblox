--!strict
-- Hunting ground profiles (S33, DESIGN §3.6): data, spawns, rewards and the per-hour targets of the model.

local AreaAdvice = require("../src/shared/Logic/AreaAdvice")
local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local AreaRates = require("../src/shared/Logic/AreaRates")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local B = require("./Balance")
local Combat = require("../src/shared/Data/Combat")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Loot = require("../src/shared/Logic/Loot")
local Maps = require("../src/shared/Data/Maps")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Spawns = require("../src/shared/Data/Spawns")
local T = require("./Test")

local MULS = { "hpMul", "atkMul", "expMul", "goldMul", "itemChanceMul", "topTierMul", "materialMul" }

T.describe("Area profiles: data", function()
	T.it("have every field and positive multipliers", function()
		for _, id in AreaProfiles.order do
			local p = AreaProfiles.get(id) :: any
			T.expect(p).toBeTruthy()
			T.expect(p.id).toBe(id)
			T.expect(p.nameKey).toBe(`area.profile.{id}`)
			T.expect(p.descKey).toBe(`area.profile.{id}.desc`)
			T.expect(#p.icon > 0).toBe(true)
			T.expect(string.match(p.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
			for _, key in MULS do
				T.expect(type(p[key]) == "number" and p[key] > 0).toBe(true)
			end
			T.expect(p.respawn.min > 0 and p.respawn.min <= p.respawn.max).toBe(true)
			for n = 1, 4 do
				T.expect((p.sizeWeights[n] or 0) >= 0).toBe(true)
			end
		end
		for _, key in MULS do
			T.expect((AreaProfiles.NEUTRAL :: any)[key]).toBe(1)
		end
	end)

	T.it("are named only with existing ids in areas and caves", function()
		for _, data in Areas.byMap do
			for _, area in data.areas do
				if area.profile then
					T.expect(AreaProfiles.get(area.profile)).toBeTruthy()
				end
			end
		end
		for _, cave in Areas.caves.list do
			if cave.profile then
				T.expect(AreaProfiles.get(cave.profile)).toBeTruthy()
			end
		end
		T.expect(AreaProfiles.ofArea("meadows_wolfhills").id).toBe("exp")
		T.expect(AreaProfiles.ofArea("meadows_toadmire").id).toBe("loot")
		T.expect(AreaProfiles.ofArea("meadows_banditroad").id).toBe("gold")
		T.expect(AreaProfiles.ofArea("meadows_rabbitfields")).toBeNil()
		T.expect(AreaProfiles.ofArea("meadows_hideout")).toBeNil()
		T.expect(AreaProfiles.ofArea(nil)).toBeNil()
		T.expect(AreaProfiles.modsOf("nope").goldMul).toBe(1)
	end)

	T.it("give the Meadows two different choices on every level from 3 to 18", function()
		for level = 3, 18 do
			local kinds: { [string]: boolean } = {}
			local n = 0
			for _, area in Areas.byMap.meadows.areas do
				if level >= area.lv[1] and level <= area.lv[2] then
					local key = area.profile or "none"
					if not kinds[key] then
						kinds[key] = true
						n += 1
					end
				end
			end
			for _, cave in Areas.caves.list do
				if cave.region == "meadows" and level >= cave.levels[1] and level <= cave.levels[2] then
					n += if kinds.cave then 0 else 1
					kinds.cave = true
				end
			end
			if n < 2 then
				error(`level {level}: only one kind of hunting ground`)
			end
		end
	end)

	T.it("pair every overlapping area of the other regions with a fast-EXP one", function()
		local byRegion = {
			duskwood = {
				{ "werethicket", "bearhollow" },
				{ "ruins", "heart" },
				{ "cultvillage", "crossroads" },
				{ "swamp", "witchmarsh" },
			},
			ashen = { { "flats", "oasis" }, { "burntruins", "dunes" }, { "crags", "ashroad" } },
			frostpeak = { { "slopes", "harpyrocks" }, { "lake", "tundra" }, { "temple", "icewatch" } },
		}
		for region, list in byRegion do
			for _, pair in list do
				local a = AreaProfiles.ofArea(`{region}_{pair[1]}`)
				local b = AreaProfiles.ofArea(`{region}_{pair[2]}`)
				T.expect(a ~= nil and b ~= nil).toBe(true)
				local ids = { (a :: any).id, (b :: any).id }
				T.expect(table.find(ids, "exp") ~= nil).toBe(true)
				T.expect(ids[1] ~= ids[2]).toBe(true)
			end
		end
	end)
end)

T.describe("Area profiles: advice", function()
	T.it("recommends the best area of every profile at the player's level", function()
		local best = AreaAdvice.bestByProfile(5, "meadows")
		T.expect(best.exp.id).toBe("meadows_wolfhills")
		T.expect(best.loot.id).toBe("meadows_toadmire")
		T.expect(best.none).toBeNil()
		local later = AreaAdvice.bestByProfile(13, "meadows")
		T.expect(later.gold.id).toBe("meadows_banditroad")
		T.expect(later.loot.id).toBe("meadows_diggings")
		T.expect(later.exp.id).toBe("meadows_goblincamp")
		local toad = Areas.areaById("meadows_toadmire") :: any
		T.expect(AreaAdvice.isBestOfProfile(toad, 6, "meadows")).toBe(true)
	end)
end)

T.describe("Area profiles: spawns", function()
	T.it("give profiled areas their group sizes and respawn without moving any group", function()
		local wolf, toad = 0, 0
		for _, spawner in Spawns.byMap.meadows do
			local profile = AreaProfiles.ofArea(spawner.areaId)
			T.expect(spawner.respawn).toEqual(if profile then profile.respawn else AreaSpawns.RESPAWN)
			T.expect(#(spawner.members :: { string })).toBe(spawner.count)
			if spawner.areaId == "meadows_wolfhills" then
				wolf += spawner.count
			elseif spawner.areaId == "meadows_toadmire" then
				toad += spawner.count
			end
		end
		-- Same number of groups, more wolves per group on the hills than toads per group in the mire.
		T.expect(wolf / 7 > toad / 6).toBe(true)
		-- Positions come from the layout generator alone: the same with every profile removed.
		local plain = table.clone(Areas.byMap.meadows) :: any
		plain.areas = {}
		for _, area in Areas.byMap.meadows.areas do
			local copy = table.clone(area) :: any
			copy.profile = nil
			table.insert(plain.areas, copy)
		end
		local before = AreaSpawns.region(plain, (Maps.get("meadows") :: any).size)
		local after = Spawns.byMap.meadows
		T.expect(#before).toBe(#after)
		for i, spawner in before do
			T.expect(after[i].position).toEqual(spawner.position)
			T.expect(after[i].radius).toBe(spawner.radius)
			-- Fast EXP: never a smaller group; better drops: never a bigger one; more gold: the same.
			local profile = AreaProfiles.ofArea(spawner.areaId)
			local id = if profile then profile.id else "none"
			if id == "exp" then
				T.expect(after[i].count >= spawner.count).toBe(true)
			elseif id == "loot" then
				T.expect(after[i].count <= spawner.count).toBe(true)
			else
				T.expect(after[i].count).toBe(spawner.count)
				T.expect(after[i].members).toEqual(spawner.members)
			end
		end
	end)

	T.it("stay far below the active monster limit", function()
		-- Every region map full at once (groups only spawn near players; Config.MaxActiveMonsters = 600).
		local total = 0
		for mapId in Areas.byMap do
			for _, spawner in Spawns.byMap[mapId] do
				total += spawner.count
			end
		end
		T.expect(total < 600).toBe(true)
	end)
end)

T.describe("Area profiles: rewards", function()
	T.it("scale monster HP and attack", function()
		local kind = B.GENERIC :: any
		local plain = MonsterStats.compute(kind, 10, "normal", 2)
		local loot = MonsterStats.compute(kind, 10, "normal", 2, AreaProfiles.get("loot"))
		T.expect(loot.maxHp).toBe(math.floor(MonsterStats.baseHp(plain.level) * 1.25 + 0.5))
		T.expect(loot.attack).toBeNear(plain.attack * 1.1, 1e-6)
		T.expect(Combat.variants.normal.hpMul).toBe(1)
	end)

	T.it("raise the top rarity but never above the source's cap", function()
		for variant, weights in Rarities.dropWeights do
			local raised = ItemRoll.rarityWeights(variant, 2)
			local cap = Rarities.cap[variant]
			for rarity, w in raised do
				if rarity > cap then
					T.expect(w).toBe(0)
				end
			end
			for rarity in raised do
				T.expect(weights[rarity] ~= nil).toBe(true)
			end
		end
		local normal = ItemRoll.rarityWeights("normal", 2)
		T.expect(normal[Rarities.UNIQUE]).toBe(Rarities.dropWeights.normal[Rarities.UNIQUE] * 2)
		T.expect(normal[Rarities.COMMON]).toBe(Rarities.dropWeights.normal[Rarities.COMMON])
		local rng = Rng.new(5)
		for _ = 1, 300 do
			local loot = Loot.rollMonsterLoot("wolf", "normal", 10, rng, { itemChanceMul = 1.7, topTierMul = 2 })
			for _, item in loot.items do
				T.expect(item.rarity <= Rarities.cap.normal).toBe(true)
			end
		end
	end)

	T.it("drop more items and materials in a better-drop area", function()
		local function count(mods: any): (number, number)
			local rng = Rng.new(11)
			local items, mats = 0, 0
			for _ = 1, 3000 do
				local loot = Loot.rollMonsterLoot("boar", "normal", 10, rng, mods)
				items += #loot.items
				for _, m in loot.materials do
					mats += m.n
				end
			end
			return items, mats
		end
		local items, mats = count({})
		local lootItems, lootMats = count({ itemChanceMul = 1.7, topTierMul = 2, materialMul = 1.5 })
		T.expect(lootItems / items).toBeBetween(1.5, 1.9)
		T.expect(lootMats / mats).toBeBetween(1.3, 1.7)
	end)
end)

T.describe("Area profiles: model targets (DESIGN §3.6)", function()
	local LEVELS = { 4, 8, 12, 16, 19 }

	T.it("fast EXP gives at least 1.25x the EXP per hour of better drops", function()
		for _, classId in B.CLASSES do
			for _, level in LEVELS do
				local exp = B.areaRates(classId, level, "exp")
				local loot = B.areaRates(classId, level, "loot")
				local none = B.areaRates(classId, level, nil)
				T.expect(exp.expPerHour / loot.expPerHour >= 1.25).toBe(true)
				T.expect(exp.expPerHour > none.expPerHour).toBe(true)
			end
		end
	end)

	T.it("better drops give at least 1.6x the top-rarity items per hour of the others", function()
		for _, classId in B.CLASSES do
			for _, level in LEVELS do
				local loot = B.areaRates(classId, level, "loot").topPerHour
				for _, other in { "exp", "gold", "none" } do
					local rates = B.areaRates(classId, level, if other == "none" then nil else other)
					T.expect(loot / rates.topPerHour >= 1.6).toBe(true)
				end
			end
		end
	end)

	T.it("more gold gives at least 1.5x the gold per hour (drops sold) of the others", function()
		for _, classId in B.CLASSES do
			for _, level in LEVELS do
				local gold = B.areaRates(classId, level, "gold").goldPerHour
				for _, other in { "exp", "loot", "none" } do
					local rates = B.areaRates(classId, level, if other == "none" then nil else other)
					T.expect(gold / rates.goldPerHour >= 1.5).toBe(true)
				end
			end
		end
	end)

	T.it("keep the targets in the higher regions", function()
		for _, level in { 30, 55, 85 } do
			local exp = B.areaRates("Warrior", level, "exp", B.GENERIC)
			local loot = B.areaRates("Warrior", level, "loot", B.GENERIC)
			local gold = B.areaRates("Warrior", level, "gold", B.GENERIC)
			T.expect(exp.expPerHour / loot.expPerHour >= 1.25).toBe(true)
			T.expect(loot.topPerHour / exp.topPerHour >= 1.6).toBe(true)
			T.expect(gold.goldPerHour / loot.goldPerHour >= 1.5).toBe(true)
		end
	end)

	T.it("walks less between groups when they respawn faster", function()
		T.expect(AreaRates.walkSeconds(AreaProfiles.get("exp")) < AreaRates.WALK).toBe(true)
		T.expect(AreaRates.walkSeconds(AreaProfiles.get("loot")) > AreaRates.WALK).toBe(true)
		T.expect(AreaRates.walkSeconds(nil)).toBe(AreaRates.WALK)
	end)
end)
