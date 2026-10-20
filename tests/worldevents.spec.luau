--!strict
-- World events (S101, docs/DESIGN-15.md §4): data, schedule, region / hunting ground / kind, route and points,
-- scale and waves, contribution, reward, chest and the HUD progress (Logic/WorldEvents). S134d: the Invasion zone
-- (spawn points, population and refill, phases, the zone leash).
local Areas = require("../src/shared/Data/Areas")
local Classes = require("../src/shared/Data/Classes")
local Data = require("../src/shared/Data/WorldEvents")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local Maps = require("../src/shared/Data/Maps")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterMotions = require("../src/shared/Data/MonsterMotions")
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
	T.it("has both kinds with texts, open regions, rising scales and a Unique / Heroic / Legendary chest", function()
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
		-- S134c: the chest may hold a Legendary item (owner 2026-10-15), never a Mythic one
		T.expect(keys).toEqual({ 2, 3, 4 })
		T.expect(2).toBe(Rarities.UNIQUE)
		T.expect(3).toBe(Rarities.HEROIC)
		T.expect(4).toBe(Rarities.LEGENDARY)
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

T.describe("WorldEvents: scale and population", function()
	T.it("scales the Elite II by players and caps the population", function()
		local s = Data.scale.commander
		T.expect(WorldEvents.scaleOf("commander", 1).hpMul).toBe(s.hp[1])
		T.expect(WorldEvents.scaleOf("commander", 0).hpMul).toBe(s.hp[1])
		T.expect(WorldEvents.scaleOf("commander", 99).hpMul).toBe(s.hp[#s.hp])
		T.expect(WorldEvents.scaleOf("champion", 2).atkMul).toBe(Data.scale.champion.atk[2])
		local w = Data.kinds.invasion.population
		T.expect(WorldEvents.population(1)).toBe(w.base + w.perPlayer)
		T.expect(WorldEvents.population(0)).toBe(w.base + w.perPlayer)
		T.expect(WorldEvents.population(50)).toBe(w.max)
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

	-- S149: the rule moved to Logic/Contribution (shared with the world boss); the event's results stay the same
	T.it(
		"delegates to Logic/Contribution: the same points, threshold and eligibility for random contributions",
		function()
			local Contribution = require("../src/shared/Logic/Contribution")
			local rng = Rng.new(149)
			for _ = 1, 200 do
				local c = {
					dmg = rng:float(0, 50000),
					heal = rng:float(0, 20000),
					shield = rng:float(0, 10000),
					intercept = rng:float(0, 5000),
				}
				T.expect(WorldEvents.points(c)).toBe(Contribution.points(c, Data.share))
				local level = rng:int(1, 100)
				local total = rng:float(0, 1e6)
				local hpEq = Data.share.hpEquivalent * MonsterStats.baseHp(level)
				T.expect(WorldEvents.threshold(total, level)).toBe(Contribution.threshold(total, hpEq, Data.share))
				local points = WorldEvents.points(c)
				T.expect(WorldEvents.eligible(points, total, level, level))
					.toBe(Contribution.eligible(points, total, hpEq, Data.share))
			end
			T.expect(WorldEvents.emptyContribution()).toEqual(Contribution.empty())
		end
	)
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
	-- S134c: Unique 60 / Heroic 37 / Legendary 3 (S101: Unique 80 / Heroic 20)
	T.it("rolls a Unique, Heroic or Legendary item of the right level, mostly for the class", function()
		local heroic, legendary, total, mage = 0, 0, 0, 0
		for _, L in { 1, 20, 45, 70, 100 } do
			for seed = 1, 2000 do
				local drop = WorldEvents.rollChest(L, L, "Mage", Rng.new(seed * 31 + L))
				assert(drop, `L{L} seed {seed}`)
				T.expect(drop.rarity >= Rarities.UNIQUE and drop.rarity <= Rarities.LEGENDARY).toBe(true)
				T.expect(drop.ilvl).toBeBetween(1, L)
				total += 1
				if drop.rarity == Rarities.HEROIC then
					heroic += 1
				elseif drop.rarity == Rarities.LEGENDARY then
					legendary += 1
				end
				local def = Items.get(drop.defId) :: Items.ItemDef
				if def.classes == nil or table.find(def.classes, "Mage") ~= nil then
					mage += 1
				end
			end
		end
		T.expect(heroic / total).toBeNear(0.37, 0.03) -- S134c: 0.2 -> 0.37
		T.expect(legendary / total).toBeNear(0.03, 0.01) -- S134c
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
	T.it("follows the phases (kills or time), then the commander, and the champion's HP", function()
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
		p.stage, p.stages, p.quota, p.got, p.stageAt = 1, 6, 30, 0, 100
		T.expect(WorldEvents.progressOf(p)).toBe(0)
		T.expect(WorldEvents.progressOf(p, 100)).toBe(0)
		p.stage, p.got = 3, 15
		T.expect(WorldEvents.progressOf(p)).toBeNear(2.5 / 6, 1e-9)
		-- the time counts when it is further than the kills
		local every = Data.kinds.invasion.phaseEvery
		T.expect(WorldEvents.progressOf(p, 100 + every * 0.75)).toBeNear(2.75 / 6, 1e-9)
		T.expect(WorldEvents.progressOf(p, 100 + every * 0.25)).toBeNear(2.5 / 6, 1e-9)
		p.boss, p.hp = "monster.wolf.elite2", 0.25
		T.expect(WorldEvents.progressOf(p)).toBeNear(0.75, 1e-9)
		local c = table.clone(base)
		c.kind = "champion"
		T.expect(WorldEvents.progressOf(c)).toBe(0)
		c.boss, c.hp = "monster.wolf.elite2", 1
		T.expect(WorldEvents.progressOf(c)).toBe(0)
	end)
end)

T.describe("WorldEvents: Blood Moon block (S129)", function()
	local Schedule = require("../src/shared/Logic/Schedule")
	local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
	local TUESDAY_19 = 1791918000 -- 2026-10-13 19:00 UTC

	T.it("a world event whose window meets the Blood Moon does not start", function()
		local window = WorldEvents.window(true)
		T.expect(window).toBe(Data.schedule.warn + Data.kinds.champion.duration)
		T.expect(WorldEvents.window(false)).toBe(Data.kinds.champion.duration)
		-- the warning at 18:40 would run to 18:57 at the latest: inside the quiet 10 min before 19:00
		local from = TUESDAY_19 - 20 * 60
		T.expect(Schedule.blocking(ScheduledEvents.list, from, from + window) ~= nil).toBe(true)
		-- 17:30: over by 17:47
		local early = TUESDAY_19 - 90 * 60
		T.expect(Schedule.blocking(ScheduledEvents.list, early, early + window)).toBeNil()
		-- during the Blood Moon and right after it
		T.expect(Schedule.blocking(ScheduledEvents.list, TUESDAY_19 + 600, TUESDAY_19 + 600 + window) ~= nil).toBe(true)
		T.expect(Schedule.blocking(ScheduledEvents.list, TUESDAY_19 + 1800, TUESDAY_19 + 1800 + window)).toBeNil()
	end)

	T.it("the window covers more than the quiet minutes (no world event runs when the Blood Moon rises)", function()
		local def = ScheduledEvents.get("bloodmoon") :: any
		T.expect(WorldEvents.window(true) > def.quietBefore).toBe(true)
	end)
end)

-- S134c: the harder Invasion (owner 2026-10-15): the commander the same for every party with the bosses 2.0 blows, the
-- chest up to Legendary. S134d: the zone's phases (more Elites, an Elite II, the commander last).
T.describe("WorldEvents: harder Invasion (S134c)", function()
	T.it(
		"phases bring more Elites, the Elite II in elite2Phase (another kind than the commander), the commander in time",
		function()
			local inv = Data.kinds.invasion
			for phase = 2, inv.phases do
				T.expect({ phase, WorldEvents.elitesOf(phase) >= WorldEvents.elitesOf(phase - 1) })
					.toEqual({ phase, true })
				T.expect({ phase, WorldEvents.hasPhaseElite2(phase) }).toEqual({ phase, phase == inv.elite2Phase })
			end
			T.expect(WorldEvents.elitesOf(inv.phases) > WorldEvents.elitesOf(1)).toBe(true)
			T.expect(WorldEvents.elitesOf(inv.phases + 1)).toBe(0)
			T.expect(inv.elite2Phase < inv.phases).toBe(true)
			T.expect(WorldEvents.commanderLatest() < inv.duration).toBe(true)
			-- the phase's Elite II is another kind than the commander when the ground has two
			for _, mapId in Data.regions do
				for _, area in areasOf(mapId) do
					local hosts = WorldEvents.hostKinds(area)
					if #hosts > 0 then
						local others = WorldEvents.phaseElite2Kinds(area, hosts[1])
						T.expect({ area.id, #others > 0 }).toEqual({ area.id, true })
						if #hosts > 1 then
							T.expect({ area.id, table.find(others, hosts[1]) }).toEqual({ area.id, nil })
						end
					end
				end
			end
		end
	)

	T.it("the commander does not scale with the party", function()
		for _, n in { 1, 2, 3, 4, 5, 9 } do
			T.expect(WorldEvents.scaleOf("commander", n)).toEqual(WorldEvents.scaleOf("commander", 5))
		end
	end)

	T.it(
		"the commander's blows: two big blows to dodge and a shared blow, with texts and a motion on every plan",
		function()
			local abilities = WorldEvents.commanderAbilities()
			T.expect(#abilities).toBe(#Data.kinds.invasion.commanderAbilities)
			local avoid, split = 0, 0
			for _, ability in abilities do
				T.expect(MonsterAbilities.get(ability.id)).toBe(ability)
				for _, locale in { pl, en } :: { { [string]: string } } do
					T.expect({ ability.id, type(locale[`ability.{ability.id}.name`]) })
						.toEqual({ ability.id, "string" })
				end
				for plan in MonsterMotions.PLANS do
					local style = MonsterMotions.styleFor(plan, nil, ability.id)
					T.expect({ plan, ability.id, style ~= nil and MonsterMotions.STYLES[style] ~= nil })
						.toEqual({ plan, ability.id, true })
				end
				if ability.avoid then
					avoid += 1
				end
				if ability.mechanic == "split" then
					split += 1
				end
			end
			T.expect(avoid >= 2).toBe(true)
			T.expect(split).toBe(1)
			for _, k in { "event.elite2", "event.phase", "hud.event.phase", "boss.mechanic.split.hint" } do
				T.expect({ k, type(pl[k]), type(en[k]) }).toEqual({ k, "string", "string" })
			end
		end
	)

	T.it(
		"the chest: never Mythic, at most Legendary, weights sum to 100, the Legendary no more than a boss's",
		function()
			local sum, top = 0, 0
			for k, w in Data.reward.chest.rarity :: { [number]: number } do
				sum += w
				top = math.max(top, k)
			end
			T.expect(sum).toBe(100)
			T.expect(top).toBe(Rarities.LEGENDARY)
			local legendary = (Data.reward.chest.rarity :: { [number]: number })[Rarities.LEGENDARY] or 0
			T.expect(legendary <= LootTables.bosses.grimrok.legendaryChance * 100 + 1e-9).toBe(true)
			for seed = 1, 300 do
				local drop = WorldEvents.rollChest(47, 47, "Warrior", Rng.new(seed))
				assert(drop, `seed {seed}`)
				T.expect(drop.rarity <= Rarities.LEGENDARY).toBe(true)
			end
		end
	)
end)

-- S134d (owner 2026-10-20: few monsters, easy, they just run in): the Invasion zone. A live population growing with the
-- players, refilled in batches (Elites first), the phases by time or kills, spread spawn points away from the
-- players, a leash that keeps the monsters in the zone.
T.describe("WorldEvents: Invasion zone (S134d)", function()
	local inv = Data.kinds.invasion

	T.it("the population is 24 / 36 / 48 for 1 / 3 / 5 players and caps at 60", function()
		T.expect(WorldEvents.population(1)).toBe(24)
		T.expect(WorldEvents.population(3)).toBe(36)
		T.expect(WorldEvents.population(5)).toBe(48)
		T.expect(WorldEvents.population(7)).toBe(60)
		T.expect(WorldEvents.population(40)).toBe(60)
		for n = 1, 10 do
			T.expect(WorldEvents.population(n + 1) >= WorldEvents.population(n)).toBe(true)
			T.expect(WorldEvents.quota(n)).toBe(math.ceil(inv.phaseKills * WorldEvents.population(n)))
		end
	end)

	T.it("a refill tops the zone up in batches, Elites first, never over the population or the budget", function()
		-- an empty zone of one player in phase 1 (no Elites): a full batch of normals
		T.expect(WorldEvents.refill(0, 0, 1, 1)).toEqual({ normals = inv.refillBatch, elites = 0 })
		-- the batches fill it exactly to the population, then nothing
		for _, players in { 1, 3, 5, 9 } do
			for phase = 1, inv.phases do
				local alive, elites, ticks = 0, 0, 0
				while ticks < 50 do
					local r = WorldEvents.refill(alive, elites, players, phase)
					if r.normals + r.elites == 0 then
						break
					end
					T.expect(r.normals + r.elites <= inv.refillBatch).toBe(true)
					alive += r.normals + r.elites
					elites += r.elites
					ticks += 1
				end
				T.expect({ players, phase, alive }).toEqual({ players, phase, WorldEvents.population(players) })
				T.expect({ players, phase, elites }).toEqual({ players, phase, WorldEvents.elitesOf(phase) })
			end
		end
		-- a kill is refilled; a dead Elite comes back as an Elite
		local full = WorldEvents.population(3)
		T.expect(WorldEvents.refill(full, 2, 3, 4)).toEqual({ normals = 0, elites = 0 })
		T.expect(WorldEvents.refill(full - 3, 2, 3, 4)).toEqual({ normals = 3, elites = 0 })
		T.expect(WorldEvents.refill(full - 1, 1, 3, 4)).toEqual({ normals = 0, elites = 1 })
		-- a new phase with more Elites: they come first
		T.expect(WorldEvents.refill(full - 5, 0, 3, 6)).toEqual({ normals = 2, elites = 3 })
		-- the server budget caps a tick; a player leaving never removes monsters
		T.expect(WorldEvents.refill(0, 0, 5, 1, 3)).toEqual({ normals = 3, elites = 0 })
		T.expect(WorldEvents.refill(0, 0, 5, 1, 0)).toEqual({ normals = 0, elites = 0 })
		T.expect(WorldEvents.refill(WorldEvents.population(5), 0, 1, 1)).toEqual({ normals = 0, elites = 0 })
	end)

	T.it("a phase ends after phaseEvery, or early after minPhase with its kills and its Elite II dead", function()
		local q = WorldEvents.quota(3)
		T.expect(WorldEvents.phaseDone(1, inv.phaseEvery, 0, q, false)).toBe(true)
		T.expect(WorldEvents.phaseDone(1, inv.phaseEvery - 1, 0, q, false)).toBe(false)
		T.expect(WorldEvents.phaseDone(1, inv.minPhase, q, q, false)).toBe(true)
		T.expect(WorldEvents.phaseDone(1, inv.minPhase - 1, q * 3, q, false)).toBe(false)
		T.expect(WorldEvents.phaseDone(1, inv.minPhase, q - 1, q, false)).toBe(false)
		-- the Elite II holds an early end, never the time
		T.expect(WorldEvents.phaseDone(inv.elite2Phase, inv.minPhase, q, q, true)).toBe(false)
		T.expect(WorldEvents.phaseDone(inv.elite2Phase, inv.phaseEvery, 0, q, true)).toBe(true)
		-- the last phase (the commander's) never ends by itself
		T.expect(WorldEvents.phaseDone(inv.phases, 10 * inv.phaseEvery, 999, q, false)).toBe(false)
		-- the commander comes at the latest after (phases - 1) full phases, with time left to fight it
		T.expect(WorldEvents.commanderLatest()).toBe((inv.phases - 1) * inv.phaseEvery)
		T.expect(inv.duration - WorldEvents.commanderLatest() >= 240).toBe(true)
	end)

	T.it("spawn points spread over the ring inside the zone, the core stays free", function()
		local z = inv.zone
		for seed = 1, 20 do
			local points = WorldEvents.zonePoints(Rng.new(seed))
			T.expect(#points).toBe(z.points)
			local inner, near, far = 0, 0, 0
			for _, p in points do
				local r = math.sqrt(p.x * p.x + p.z * p.z)
				T.expect(r >= z.core - 1e-9 and r <= z.radius - z.edge + 1e-9).toBe(true)
				if r < (z.core + z.radius) / 2 then
					inner += 1
				end
				if r > z.radius * 0.7 then
					far += 1
				end
				-- no two points on top of each other
				for _, q in points do
					if q ~= p then
						near = math.max(near, if (p.x - q.x) ^ 2 + (p.z - q.z) ^ 2 < 4 then 1 else 0)
					end
				end
			end
			-- equal areas: both halves of the ring hold points, the outer part too
			T.expect(inner >= 3 and far >= 3).toBe(true)
			T.expect(near).toBe(0)
		end
	end)

	T.it("a monster spawns clear of the players, else as far as possible", function()
		local points = { { x = 0, z = 0 }, { x = 40, z = 0 }, { x = 0, z = 40 } }
		local clear = inv.zone.clear
		for seed = 1, 30 do
			local i = WorldEvents.pickSpawn(points, { { x = 1, z = 1 } }, Rng.new(seed))
			T.expect(i ~= nil and i ~= 1).toBe(true)
		end
		-- every point taken: the farthest from its nearest player
		local crowd = { { x = 0, z = 0 }, { x = 40, z = 2 }, { x = 2, z = 40 - clear / 2 } }
		T.expect(WorldEvents.pickSpawn(points, crowd, Rng.new(1))).toBe(3)
		T.expect(WorldEvents.pickSpawn({}, crowd, Rng.new(1))).toBeNil()
		-- nobody there: any point
		T.expect(WorldEvents.pickSpawn(points, {}, Rng.new(4)) ~= nil).toBe(true)
	end)

	T.it(
		"the zone leash keeps a monster within radius + margin of the centre and never below the soft leash",
		function()
			local z = inv.zone
			for _, d in { 0, z.core, 30, z.radius - z.edge } do
				local hard = WorldEvents.hardLeash(d)
				T.expect(hard >= z.leash).toBe(true)
				T.expect(d + hard <= z.radius + z.margin or hard == z.leash).toBe(true)
			end
			-- aggro and leash far below the S134c event (120 studs from the centre): no long runs at players
			T.expect(z.aggro <= 30 and z.leash <= 40).toBe(true)
			T.expect(z.radius >= 60 and z.radius <= 80).toBe(true)
			-- the zone's monsters are tougher and pay more per kill
			T.expect(inv.mods.hpMul > 1 and inv.mods.atkMul > 1 and inv.expMul > 1).toBe(true)
		end
	)
end)

return nil
