--!strict
-- World events (S101, docs/DESIGN-15.md §4): data, schedule, region / hunting ground / kind, route and points,
-- scale and waves, contribution, reward, chest and the HUD progress (Logic/WorldEvents).
local Areas = require("../src/shared/Data/Areas")
local Classes = require("../src/shared/Data/Classes")
local Data = require("../src/shared/Data/WorldEvents")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local Maps = require("../src/shared/Data/Maps")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Spawns = require("../src/shared/Data/Spawns")
local T = require("./Test")
local WorldEvents = require("../src/shared/Logic/WorldEvents")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function areasOf(mapId: string): { Areas.Area }
	return (Areas.byMap[mapId] :: any).areas
end

local function areaWith(mapId: string, kind: string): Areas.Area?
	for _, area in areasOf(mapId) do
		if table.find(area.kinds, kind) then
			return area
		end
	end
	return nil
end

local function key(p: WorldEvents.Point): string
	return `{p.x},{p.z}`
end

T.describe("WorldEvents: data", function()
	T.it("has both kinds with texts, open regions, rising scales and a Unique / Heroic chest", function()
		T.expect(table.isfrozen(Data)).toBe(true)
		T.expect(Data.order).toEqual({ "invasion", "champion" })
		for _, id in Data.order do
			local def = WorldEvents.kindOf(id)
			assert(def, id)
			T.expect(def.id).toBe(id)
			T.expect(def.duration > 0).toBe(true)
			for _, k in { def.nameKey, def.descKey } do
				T.expect(type(pl[k])).toBe("string")
				T.expect(type(en[k])).toBe("string")
			end
		end
		T.expect(WorldEvents.kindOf("nope")).toBeNil()
		for _, id in Data.regions do
			local map = Maps.get(id)
			assert(map, id)
			T.expect(map.zone ~= "red").toBe(true)
			T.expect(Areas.byMap[id] ~= nil).toBe(true)
		end
		for _, which in { "commander", "champion" } do
			local s = (Data.scale :: any)[which]
			for _, field in { "hp", "atk" } do
				local list = s[field]
				T.expect(#list > 0).toBe(true)
				for i = 2, #list do
					T.expect(list[i] >= list[i - 1]).toBe(true)
				end
			end
		end
		local keys = {}
		for k in Data.reward.chest.rarity :: { [number]: number } do
			table.insert(keys, k)
		end
		table.sort(keys)
		T.expect(keys).toEqual({ 2, 3 })
		T.expect(2).toBe(Rarities.UNIQUE)
		T.expect(3).toBe(Rarities.HEROIC)
		T.expect(Data.reward.chest.bound).toBe(true)
		T.expect(Data.schedule.warn).toBe(120)
	end)
end)

T.describe("WorldEvents: schedule", function()
	T.it("starts 15-35 min after the server and then about every hour", function()
		for seed = 1, 200 do
			T.expect(WorldEvents.firstStart(0, Rng.new(seed))).toBeBetween(900, 2100)
			T.expect(WorldEvents.nextStart(5000, Rng.new(seed))).toBeBetween(5000 + 3000, 5000 + 4200)
		end
		local rng = Rng.new(42)
		local sum = 0
		for _ = 1, 2000 do
			sum += WorldEvents.nextStart(0, rng)
		end
		T.expect(sum / 2000).toBeNear(3600, 30)
		T.expect(WorldEvents.nextStart(0, Rng.new(3), 9000)).toBe(9000)
		T.expect(WorldEvents.nextStart(0, Rng.new(3), 10)).toBe(WorldEvents.nextStart(0, Rng.new(3)))
		T.expect(WorldEvents.retryAt(100)).toBe(100 + Data.schedule.retry)
	end)
end)

T.describe("WorldEvents: region", function()
	T.it("picks an open region weighted by its players", function()
		T.expect(WorldEvents.pickRegion({}, Rng.new(1))).toBeNil()
		T.expect(WorldEvents.pickRegion({ city = 5, meadows_cave = 3 }, Rng.new(1))).toBeNil()
		for seed = 1, 50 do
			T.expect(WorldEvents.pickRegion({ meadows = 1 }, Rng.new(seed))).toBe("meadows")
		end
		local rng = Rng.new(9)
		local meadows = 0
		for _ = 1, 4000 do
			if WorldEvents.pickRegion({ meadows = 3, duskwood = 1, city = 10 }, rng) == "meadows" then
				meadows += 1
			end
		end
		T.expect(meadows / 4000).toBeNear(0.75, 0.03)
		local a, b = Rng.new(77), Rng.new(77)
		for _ = 1, 20 do
			T.expect(WorldEvents.pickRegion({ ashen = 2, frostpeak = 5 }, a))
				.toBe(WorldEvents.pickRegion({ ashen = 2, frostpeak = 5 }, b))
		end
	end)
end)

T.describe("WorldEvents: hunting ground", function()
	T.it("takes the lower median level", function()
		T.expect(WorldEvents.medianLevel({ 5, 18, 7 })).toBe(7)
		T.expect(WorldEvents.medianLevel({ 4, 10 })).toBe(4)
		T.expect(WorldEvents.medianLevel({})).toBe(1)
	end)

	T.it("every region has a hosting ground and every level of the map gets one that fits", function()
		local w = Data.levelWindow
		for _, mapId in Data.regions do
			local hosts = {}
			for _, area in areasOf(mapId) do
				if WorldEvents.canHost(area) then
					table.insert(hosts, area)
				end
			end
			if #hosts == 0 then
				error(`{mapId}: no hunting ground can host an event`, 0)
			end
			local map = Maps.get(mapId) :: any
			for level = map.minLevel, map.maxLevel do
				local fitting = false
				for _, area in hosts do
					if area.lv[1] - w <= level and level <= area.lv[2] + w then
						fitting = true
					end
				end
				for seed = 1, 5 do
					local area = WorldEvents.pickArea(mapId, level, Rng.new(seed))
					assert(area, `{mapId} L{level}`)
					T.expect(WorldEvents.canHost(area)).toBe(true)
					local _, areaMap = Areas.areaById(area.id)
					T.expect(areaMap).toBe(mapId)
					if fitting then
						T.expect(area.lv[1] - w <= level and level <= area.lv[2] + w).toBe(true)
					end
					local L = WorldEvents.eventLevel(area, level)
					T.expect(L).toBeBetween(area.lv[1], area.lv[2])
				end
			end
		end
	end)

	T.it("does not repeat the last ground while another fits, and never hosts a rabbit", function()
		for _, mapId in Data.regions do
			local map = Maps.get(mapId) :: any
			for level = map.minLevel, map.maxLevel, 3 do
				local first = WorldEvents.pickArea(mapId, level, Rng.new(1)) :: Areas.Area
				local others = 0
				for _, area in areasOf(mapId) do
					if
						area.id ~= first.id
						and WorldEvents.canHost(area)
						and area.lv[1] - Data.levelWindow <= level
						and level <= area.lv[2] + Data.levelWindow
					then
						others += 1
					end
				end
				if others > 0 then
					for seed = 1, 20 do
						local again = WorldEvents.pickArea(mapId, level, Rng.new(seed), first.id) :: Areas.Area
						T.expect(again.id ~= first.id).toBe(true)
					end
				end
			end
		end
		local withRabbit = areaWith("meadows", "rabbit")
		assert(withRabbit, "a meadows ground with rabbits")
		T.expect(table.find(WorldEvents.hostKinds(withRabbit), "rabbit")).toBeNil()
		T.expect(table.find(WorldEvents.waveKinds(withRabbit), "rabbit")).toBeNil()
	end)

	T.it("picks the kinds by weight", function()
		local rng = Rng.new(5)
		local counts: { [string]: number } = { invasion = 0, champion = 0 }
		for _ = 1, 2000 do
			local kind = WorldEvents.pickKind(rng)
			counts[kind] += 1
		end
		T.expect(counts.invasion / 2000).toBeNear(0.5, 0.04)
	end)
end)

T.describe("WorldEvents: points and route", function()
	T.it("uses the ground's spawners, the centre is one of them, the route loops through fitting grounds", function()
		for _, mapId in Data.regions do
			for _, area in areasOf(mapId) do
				if WorldEvents.canHost(area) then
					local expected: { [string]: boolean } = {}
					local n = 0
					for _, spawner in Spawns.byMap[mapId] do
						if spawner.areaId == area.id then
							expected[`{spawner.position.x},{spawner.position.z}`] = true
							n += 1
						end
					end
					local points = WorldEvents.spawnPoints(mapId, area.id)
					T.expect(#points).toBe(n)
					for _, p in points do
						T.expect(expected[key(p)]).toBe(true)
					end
					local centre = WorldEvents.centre(mapId, area)
					T.expect(expected[key(centre)]).toBe(true)
					local level = math.floor((area.lv[1] + area.lv[2]) / 2)
					local route = WorldEvents.route(mapId, area, level, Rng.new(11))
					T.expect(#route).toBeBetween(2, Data.kinds.champion.routePoints)
					T.expect(key(route[1])).toBe(key(centre))
					local allowed: { [string]: boolean } = {}
					for _, other in areasOf(mapId) do
						local fits = other.lv[1] - Data.levelWindow <= level and level <= other.lv[2] + Data.levelWindow
						if other.id == area.id or (fits and WorldEvents.canHost(other)) then
							for _, p in WorldEvents.spawnPoints(mapId, other.id) do
								allowed[key(p)] = true
							end
						end
					end
					local seen: { [string]: boolean } = {}
					for _, p in route do
						T.expect(seen[key(p)]).toBeNil()
						seen[key(p)] = true
						T.expect(allowed[key(p)]).toBe(true)
					end
					T.expect(WorldEvents.route(mapId, area, level, Rng.new(11))).toEqual(route)
				end
			end
		end
		T.expect(WorldEvents.spawnPoints("duskwood", areasOf("meadows")[1].id)).toEqual({})
	end)
end)

T.describe("WorldEvents: scale and waves", function()
	T.it("scales the Elite II by players and caps the waves", function()
		local s = Data.scale.commander
		T.expect(WorldEvents.scaleOf("commander", 1).hpMul).toBe(s.hp[1])
		T.expect(WorldEvents.scaleOf("commander", 0).hpMul).toBe(s.hp[1])
		T.expect(WorldEvents.scaleOf("commander", 99).hpMul).toBe(s.hp[#s.hp])
		T.expect(WorldEvents.scaleOf("champion", 2).atkMul).toBe(Data.scale.champion.atk[2])
		local w = Data.kinds.invasion.wave
		T.expect(WorldEvents.waveSize(1)).toBe(w.base + w.perPlayer)
		T.expect(WorldEvents.waveSize(0)).toBe(w.base + w.perPlayer)
		T.expect(WorldEvents.waveSize(50)).toBe(w.max)
	end)
end)

T.describe("WorldEvents: contribution", function()
	T.it("counts damage, healing, shields and intercepted damage alike", function()
		local s = Data.share
		local c = { dmg = 100, heal = 50, shield = 20, intercept = 10 }
		T.expect(WorldEvents.points(c)).toBe(100 + 50 * s.healMul + 20 * s.shieldMul + 10 * s.interceptMul)
		T.expect(WorldEvents.threshold(0, 30)).toBe(math.huge)
		T.expect(WorldEvents.threshold(100000, 30)).toBe(math.min(3000, 3 * MonsterStats.baseHp(30)))
		T.expect(WorldEvents.eligible(0, 100000, 30, 30)).toBe(false)
		local need = WorldEvents.threshold(100000, 30)
		T.expect(WorldEvents.eligible(need, 100000, 30, 30 + s.maxLevelAbove + 1)).toBe(false)
		T.expect(WorldEvents.eligible(need, 100000, 30, 30 + s.maxLevelAbove)).toBe(true)
		local healer = WorldEvents.points({ dmg = 0, heal = need, shield = 0, intercept = 0 })
		T.expect(WorldEvents.eligible(healer, 100000, 30, 30)).toBe(true)
		T.expect(WorldEvents.eligible(need - 1, 100000, 30, 30)).toBe(false)
	end)
end)

T.describe("WorldEvents: reward", function()
	T.it("pays EXP and gold, half on a defeat, less EXP far above the event", function()
		local r = Data.reward
		for L = 1, 100 do
			local win = WorldEvents.reward(L, L, true)
			T.expect(win.exp).toBe(math.floor(r.expKills * Exp.monsterExp(L, "normal") + 0.5))
			T.expect(win.gold > 0).toBe(true)
			T.expect(win.chest).toBe(true)
			local lost = WorldEvents.reward(L, L, false)
			T.expect(lost.chest).toBe(false)
			T.expect(math.abs(lost.exp - win.exp * r.failMul) <= 1).toBe(true)
			T.expect(math.abs(lost.gold - win.gold * r.failMul) <= 1).toBe(true)
		end
		T.expect(WorldEvents.reward(30, 36, true).exp < WorldEvents.reward(30, 30, true).exp).toBe(true)
	end)
end)

T.describe("WorldEvents: chest", function()
	T.it("rolls a Unique or Heroic item of the right level, mostly for the class", function()
		local heroic, total, mage = 0, 0, 0
		for _, L in { 1, 20, 45, 70, 100 } do
			for seed = 1, 2000 do
				local drop = WorldEvents.rollChest(L, L, "Mage", Rng.new(seed * 31 + L))
				assert(drop, `L{L} seed {seed}`)
				T.expect(drop.rarity == Rarities.UNIQUE or drop.rarity == Rarities.HEROIC).toBe(true)
				T.expect(drop.ilvl).toBeBetween(1, L)
				total += 1
				if drop.rarity == Rarities.HEROIC then
					heroic += 1
				end
				local def = Items.get(drop.defId) :: Items.ItemDef
				if def.classes == nil or table.find(def.classes, "Mage") ~= nil then
					mage += 1
				end
			end
		end
		T.expect(heroic / total).toBeNear(0.2, 0.03)
		T.expect(mage / total >= 0.7).toBe(true)
		for seed = 1, 50 do
			local drop = WorldEvents.rollChest(18, 10, "Warrior", Rng.new(seed)) :: any
			T.expect(drop.ilvl <= 10).toBe(true)
		end
		T.expect(WorldEvents.rollChest(40, 40, "Hunter", Rng.new(7)))
			.toEqual(WorldEvents.rollChest(40, 40, "Hunter", Rng.new(7)))
	end)

	T.it("always finds an item for every class and level", function()
		for _, classId in Classes.order do
			for L = 1, 100 do
				for seed = 1, 50 do
					if not WorldEvents.rollChest(L, L, classId, Rng.new(seed * 100 + L)) then
						error(`{classId} L{L} seed {seed}: no chest item`, 0)
					end
				end
			end
		end
	end)
end)

T.describe("WorldEvents: HUD progress", function()
	T.it("follows the waves, then the commander, and the champion's HP", function()
		local base: WorldEvents.Public = {
			id = "e1",
			kind = "invasion",
			phase = "active",
			map = "meadows",
			area = "x",
			level = 10,
			x = 0,
			z = 0,
			startsAt = 0,
			endsAt = 1,
		}
		local p = table.clone(base)
		p.wave, p.waves, p.size, p.left = 1, 6, 8, 8
		T.expect(WorldEvents.progressOf(p)).toBe(0)
		p.wave, p.left = 3, 4
		T.expect(WorldEvents.progressOf(p)).toBeNear(2.5 / 6, 1e-9)
		p.boss, p.hp = "monster.wolf.elite2", 0.25
		T.expect(WorldEvents.progressOf(p)).toBeNear(0.75, 1e-9)
		local c = table.clone(base)
		c.kind = "champion"
		T.expect(WorldEvents.progressOf(c)).toBe(0)
		c.boss, c.hp = "monster.wolf.elite2", 1
		T.expect(WorldEvents.progressOf(c)).toBe(0)
	end)
end)
