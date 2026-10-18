--!strict
-- S149: the world boss (Data/WorldBoss, Logic/WorldBoss, Logic/Contribution): the UTC schedule (02..23 every 3 h,
-- ids wbYYYYMMDDHH, warnings, linger), the block by the Blood Moon, the phase, the reward rule (level, share, one per
-- account and occurrence, admin occurrences apart), the reward and its item, the public branch and the arena spot.
-- S149b: the view (map marker, map card, HUD panel, safe-zone note), the arena as a reserved place, the search.

local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local Bosses = require("../src/shared/Data/Bosses")
local Contribution = require("../src/shared/Logic/Contribution")
local Data = require("../src/shared/Data/WorldBoss")
local Items = require("../src/shared/Data/Items")
local LootRules = require("../src/shared/Data/LootRules")
local MapSearch = require("../src/shared/Logic/MapSearch")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local Maps = require("../src/shared/Data/Maps")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Portals = require("../src/shared/Data/Portals")
local Rarities = require("../src/shared/Data/Rarities")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local Rng = require("../src/shared/Logic/Rng")
local Schedule = require("../src/shared/Logic/Schedule")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")
local WorldBoss = require("../src/shared/Logic/WorldBoss")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local DAY = 86400
local SPACING = 120 -- the arena centre from portals, cave mouths and hideouts; the road edge from the centre

-- The first UTC Tuesday on or after 2026-10-12.
local function tuesday(): number
	local t = Time.fromCivil(2026, 10, 12) * DAY -- a day number
	while Schedule.weekday(t) ~= 2 do
		t += DAY
	end
	return t
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Distance from the point to the nearest road's edge (the S134i hideout helper).
local function roadEdge(mapId: string, x: number, z: number): number
	local best = math.huge
	for _, road in Areas.byMap[mapId].roads do
		local p = road.points
		for i = 1, #p - 3, 2 do
			local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
			local dx, dz = bx - ax, bz - az
			local l2 = dx * dx + dz * dz
			local t = if l2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / l2, 0, 1) else 0
			best = math.min(best, math.sqrt((x - ax - dx * t) ^ 2 + (z - az - dz * t) ^ 2) - road.width / 2)
		end
	end
	return best
end

T.describe("World boss: data (S149)", function()
	T.it("names a world boss on an open late map with a reward level, texts in both languages", function()
		local def = WorldBoss.def()
		T.expect(def.id).toBe(Data.boss)
		T.expect(def.world).toBe(true)
		T.expect(def.region).toBe(Data.map)
		T.expect(WorldBoss.minLevel()).toBe(80)
		local map = assert(Maps.get(Data.map), Data.map)
		T.expect(def.level <= map.maxLevel and WorldBoss.minLevel() >= map.minLevel).toBe(true)
		for _, key in
			{
				def.nameKey,
				"worldboss.name",
				"worldboss.warn",
				"worldboss.spawn",
				"worldboss.slain",
				"worldboss.left",
				"worldboss.reward",
				"worldboss.mailed",
				"worldboss.noReward.level",
				"worldboss.noReward.share",
				"worldboss.noReward.claimed",
				"fight.kind.worldboss",
				"mail.subject.worldBoss",
				"pvp.deny.worldBoss",
				"admin.usage.worldboss",
				`boss.{def.id}.phase1`,
				`boss.{def.id}.phase2`,
				`boss.{def.id}.phase3`,
				`boss.{def.id}.enrage`,
			}
		do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			-- the tone of the boss and event texts: no exclamation marks
			T.expect({ key, string.find(pl[key] or "", "!", 1, true) }).toEqual({ key, nil })
		end
		-- the rarity table is Heroic / Legendary / Mythic only
		for rarity, w in Data.reward.rarity :: { [number]: number } do
			T.expect(rarity >= Rarities.HEROIC and rarity <= Rarities.MYTHIC and w > 0).toBe(true)
		end
		for _, m in Data.reward.materials do
			T.expect({ m.id, Items.get(m.id) ~= nil, m.min <= m.max }).toEqual({ m.id, true, true })
		end
		-- no party scaling, no shield: an open-world boss is never invulnerable
		for _, summon in def.summons do
			T.expect({ summon.monster, summon.shield, summon.every }).toEqual({ summon.monster, nil, nil })
		end
	end)
end)

T.describe("World boss: schedule (S149)", function()
	T.it("starts at 02, 05, ..., 23 UTC every day with ids wbYYYYMMDDHH, the same on every server", function()
		local day0 = Time.dayNumber(tuesday())
		for day = day0, day0 + 13 do
			local starts = WorldBoss.startsOn(day)
			T.expect(#starts).toBe(8)
			for i, start in starts do
				T.expect(start).toBe(day * DAY + (2 + 3 * (i - 1)) * 3600)
			end
			local list = WorldBoss.list(day * DAY, (day + 1) * DAY)
			T.expect(#list).toBe(8)
			for i, occ in list do
				T.expect(occ.id).toBe(`wb{Schedule.dateKey(occ.startsAt)}{string.format("%02d", 2 + 3 * (i - 1))}`)
				T.expect(occ.endsAt - occ.startsAt).toBe(WorldBoss.def().timeLimit)
				-- the next one starts long after this one's marker is gone
				if list[i + 1] then
					T.expect(occ.endsAt + Data.schedule.linger < list[i + 1].startsAt - Data.schedule.warn[1])
						.toBe(true)
				end
			end
		end
		local occ = WorldBoss.list(tuesday(), tuesday() + DAY)[1]
		T.expect(occ.id).toBe(`wb{Schedule.dateKey(tuesday())}02`)
	end)

	T.it("an occurrence runs from the 10 min warning to the end of the marker; next and phase", function()
		local occ = WorldBoss.list(tuesday(), tuesday() + DAY)[3] -- 08:00
		local s = Data.schedule
		T.expect(s.warn).toEqual({ 600, 120 })
		T.expect((WorldBoss.occurrenceAt(occ.startsAt - 600) :: any).id).toBe(occ.id)
		T.expect(WorldBoss.occurrenceAt(occ.startsAt - 601)).toBeNil()
		T.expect((WorldBoss.occurrenceAt(occ.endsAt + s.linger) :: any).id).toBe(occ.id)
		T.expect(WorldBoss.occurrenceAt(occ.endsAt + s.linger + 1)).toBeNil()
		T.expect(WorldBoss.next(occ.startsAt - 1)).toEqual({ id = occ.id, startsAt = occ.startsAt })
		T.expect(WorldBoss.next(occ.startsAt).startsAt).toBe(occ.startsAt + 3 * 3600)
		-- 23:00 -> 02:00 the next day
		local late = WorldBoss.list(tuesday(), tuesday() + DAY)[8]
		T.expect(WorldBoss.next(late.startsAt).startsAt).toBe(tuesday() + DAY + 2 * 3600)
		T.expect(WorldBoss.phase(occ, occ.startsAt - 1)).toBe("warn")
		T.expect(WorldBoss.phase(occ, occ.startsAt)).toBe("active")
		T.expect(WorldBoss.phase(occ, occ.endsAt - 1)).toBe("active")
		T.expect(WorldBoss.phase(occ, occ.endsAt)).toBe("gone")
	end)

	T.it(
		"never meets the Blood Moon (with its quiet time) nor the tournament start; a 19:00 Tuesday one is blocked",
		function()
			local from = tuesday()
			for day = Time.dayNumber(from), Time.dayNumber(from) + 27 do
				for _, start in WorldBoss.startsOn(day) do
					local occ = { id = "x", startsAt = start, endsAt = start + WorldBoss.def().timeLimit }
					T.expect({ start, WorldBoss.blocked(occ) }).toEqual({ start, nil })
					-- the tournament (Saturday 19:00) does not block world events: checked by hand
					local weekday = Schedule.weekday(start)
					local cup = day * DAY + 19 * 3600
					if weekday == 6 then
						T.expect(occ.endsAt <= cup or occ.startsAt >= cup + 3600).toBe(true)
					end
				end
			end
			local moon = from + 19 * 3600
			T.expect(WorldBoss.blocked({ id = "x", startsAt = moon, endsAt = moon + 900 })).toBe("bloodmoon.name")
			-- the 17:00 one ends before the quiet time (18:50), the 20:00 one starts after the moon (19:30)
			T.expect(WorldBoss.blocked({ id = "x", startsAt = moon - 2 * 3600, endsAt = moon - 2 * 3600 + 900 }))
				.toBeNil()
			T.expect(WorldBoss.blocked({ id = "x", startsAt = moon + 3600, endsAt = moon + 3600 + 900 })).toBeNil()
			T.expect(WorldBoss.blocked({ id = "x", startsAt = moon - 900, endsAt = moon })).toBe("bloodmoon.name")
		end
	)

	T.it("an admin occurrence has its own id and never counts as a real one", function()
		local occ = WorldBoss.forced(3, 1000)
		T.expect(occ).toEqual({ id = "wbforce3", startsAt = 1000, endsAt = 1000 + WorldBoss.def().timeLimit })
		T.expect(WorldBoss.isForced(occ.id)).toBe(true)
		T.expect(WorldBoss.isForced(`wb{Schedule.dateKey(tuesday())}02`)).toBe(false)
	end)
end)

T.describe("World boss: reward (S149)", function()
	local occId = `wb{Schedule.dateKey(tuesday())}14`
	local total = 1e7
	local need = Contribution.threshold(total, WorldBoss.hpEquivalent(), Data.share)

	T.it("uses the shared contribution rule with the world boss's share", function()
		T.expect(WorldBoss.hpEquivalent()).toBe(Data.share.hpEquivalent * MonsterStats.baseHp(WorldBoss.def().level))
		T.expect(need).toBe(math.min(Data.share.min * total, WorldBoss.hpEquivalent()))
		local c = { dmg = 1000, heal = 200, shield = 50, intercept = 10 }
		T.expect(WorldBoss.points(c)).toBe(Contribution.points(c, Data.share))
	end)

	T.it("canReward: level, share and one reward per account and occurrence; admin occurrences apart", function()
		local fresh = { worldBoss = { last = "" } }
		T.expect({ WorldBoss.canReward(fresh, 79, need, total, occId) }).toEqual({ false, "level" })
		T.expect({ WorldBoss.canReward(fresh, 80, need, total, occId) }).toEqual({ true })
		T.expect({ WorldBoss.canReward(fresh, 100, need - 1, total, occId) }).toEqual({ false, "share" })
		T.expect({ WorldBoss.canReward(fresh, 100, 0, 0, occId) }).toEqual({ false, "share" })
		-- an old account without the field (reconcile adds it) and no account at all
		T.expect({ WorldBoss.canReward({}, 90, need, total, occId) }).toEqual({ true })
		T.expect({ WorldBoss.canReward(nil, 90, need, total, occId) }).toEqual({ true })
		local claimed = { worldBoss = { last = occId } }
		T.expect({ WorldBoss.canReward(claimed, 90, need, total, occId) }).toEqual({ false, "claimed" })
		-- the next occurrence is free again
		T.expect({ WorldBoss.canReward(claimed, 90, need, total, `wb{Schedule.dateKey(tuesday())}17`) })
			.toEqual({ true })
		-- an admin occurrence never blocks a real one, nor is it ever claimed
		local forced = WorldBoss.forced(1, 0).id
		T.expect({ WorldBoss.canReward({ worldBoss = { last = forced } }, 90, need, total, occId) }).toEqual({ true })
		T.expect({ WorldBoss.canReward({ worldBoss = { last = forced } }, 90, need, total, forced) }).toEqual({ true })
		T.expect({ WorldBoss.canReward(claimed, 90, need, total, forced) }).toEqual({ true })
	end)

	T.it("pays EXP and gold from the character's level; nothing when the boss left", function()
		for _, level in { 80, 90, 99, 100 } do
			local r = WorldBoss.reward(level, true)
			T.expect(r.exp > 0 and r.gold > 0).toBe(true)
			T.expect(WorldBoss.reward(level, false)).toEqual({ exp = 0, gold = 0 })
		end
		T.expect(WorldBoss.reward(99).gold > WorldBoss.reward(80).gold).toBe(true)
	end)

	T.it("rolls one Heroic+ item of the clamped level from the table, the same item for the same seed", function()
		local Classes = require("../src/shared/Data/Classes")
		local seen: { [number]: number } = {}
		for _, classId in Classes.order do
			for _, level in { 60, 80, 87, 99, 100 } do
				for seed = 1, 60 do
					local drop = WorldBoss.rollItem(level, classId, Rng.new(seed * 101 + level))
					local again = WorldBoss.rollItem(level, classId, Rng.new(seed * 101 + level))
					T.expect(drop).toEqual(again)
					local item = assert(drop, "an item")
					local top = math.clamp(level, WorldBoss.minLevel(), WorldBoss.def().level)
					T.expect({ level, item.ilvl >= top - LootRules.dropLevelBelow and item.ilvl <= top })
						.toEqual({ level, true })
					T.expect((Data.reward.rarity :: any)[item.rarity] ~= nil).toBe(true)
					T.expect(Items.get(item.defId) ~= nil).toBe(true)
					seen[item.rarity] = (seen[item.rarity] or 0) + 1
					if item.rarity == Rarities.MYTHIC then
						-- a Mythic always fits the class (Loot.pickUsable)
						local def = Items.get(item.defId) :: any
						T.expect(def.classes == nil or table.find(def.classes, classId) ~= nil).toBe(true)
					end
				end
			end
		end
		T.expect((seen[Rarities.HEROIC] or 0) > (seen[Rarities.LEGENDARY] or 0)).toBe(true)
		T.expect((seen[Rarities.LEGENDARY] or 0) > 0).toBe(true)
		T.expect(seen[Rarities.UNIQUE]).toBeNil()
		local materials = WorldBoss.rollMaterials(Rng.new(7))
		T.expect(#materials >= 1).toBe(true)
		T.expect(materials[1].id).toBe("essence_crystal")
	end)
end)

T.describe("World boss: client state (S149)", function()
	T.it("publicOf carries the spot, the times, the rounded HP and the levels; mineOf the own line", function()
		local occ = WorldBoss.list(tuesday(), tuesday() + DAY)[5]
		local p = WorldBoss.publicOf(occ, { phase = "active", hp = 0.4567, bossPhase = 2 })
		local spot = WorldBoss.spot()
		T.expect(p.id).toBe(occ.id)
		T.expect({ p.boss, p.nameKey, p.map }).toEqual({ Data.boss, WorldBoss.def().nameKey, Data.map })
		T.expect({ p.x, p.z, p.r }).toEqual({ spot.x, spot.z, spot.r })
		T.expect({ p.startsAt, p.endsAt }).toEqual({ occ.startsAt, occ.endsAt })
		T.expect(p.hp).toBeNear(0.46, 1e-9)
		T.expect({ p.phase, p.bossPhase, p.level, p.minLevel }).toEqual({ "active", 2, 100, 80 })
		T.expect(p.mine).toBeNil()
		T.expect(WorldBoss.mineOf(250, 1000, false, "share")).toEqual({
			points = 250,
			pct = 0.25,
			ok = false,
			reason = "share",
		})
		T.expect(WorldBoss.mineOf(0, 0, false, "level").pct).toBe(0)
		T.expect(WorldBoss.mineOf(10, 100, true, nil).reason).toBeNil()
		T.expect(WorldBoss.idleOf(occ.startsAt - 1)).toEqual({ next = { id = occ.id, startsAt = occ.startsAt } })
	end)

	T.it("no PvP in the fighters' circle while the boss lives", function()
		local spot = WorldBoss.spot()
		local edge = spot.r + Data.fighterReach
		T.expect(Data.pvpSafe).toBe(true)
		T.expect(WorldBoss.pvpSafe(spot, spot.x, spot.z, true)).toBe(true)
		T.expect(WorldBoss.pvpSafe(spot, spot.x + edge, spot.z, true)).toBe(true)
		T.expect(WorldBoss.pvpSafe(spot, spot.x + edge + 1, spot.z, true)).toBe(false)
		T.expect(WorldBoss.pvpSafe(spot, spot.x, spot.z, false)).toBe(false)
		T.expect(WorldBoss.inArena(spot, spot.x - edge + 1, spot.z)).toBe(true)
	end)
end)

T.describe("World boss: the spot (S149)", function()
	T.it("stands on dry, gentle ground in the whole circle, inside a late area and the map", function()
		local map = assert(Maps.get(Data.map), Data.map)
		local region = assert(RegionTerrain.get(Data.map), Data.map)
		T.expect(#Data.spots).toBe(1)
		for _, spot in Data.spots do
			T.expect(spot.r).toBe(70)
			T.expect(MapTerrain.walkable(Data.map, spot.x, spot.z, spot.r)).toBe(true)
			T.expect(region.dryAround(spot.x, spot.z, spot.r)).toBe(true)
			for dx = -spot.r, spot.r, 7 do
				for dz = -spot.r, spot.r, 7 do
					if dx * dx + dz * dz <= spot.r * spot.r then
						local ok = MapTerrain.walkable(Data.map, spot.x + dx, spot.z + dz)
						T.expect(`{dx} {dz} {ok}`).toBe(`{dx} {dz} true`)
					end
				end
			end
			T.expect(math.abs(spot.x) + spot.r <= map.size.x / 2 - 20).toBe(true)
			T.expect(math.abs(spot.z) + spot.r <= map.size.z / 2 - 20).toBe(true)
			local area: Areas.Area? = nil
			for _, a in Areas.byMap[Data.map].areas do
				local rect = a.rect
				if spot.x >= rect[1] and spot.x <= rect[3] and spot.z >= rect[2] and spot.z <= rect[4] then
					area = a
				end
			end
			local found = assert(area, "the spot's area")
			T.expect(found.lv[1] >= 85 and found.lv[2] >= 100).toBe(true)
		end
	end)

	T.it("keeps away from portals, cave mouths, hideouts, roads, water and landmarks", function()
		local data = Areas.byMap[Data.map]
		for _, spot in Data.spots do
			for _, portal in Portals.onMap(Data.map) do
				T.expect(`{portal.id} {dist(spot.x, spot.z, portal.x, portal.z) >= SPACING}`).toBe(`{portal.id} true`)
			end
			for _, cave in data.caves do
				T.expect(`{cave.cave} {dist(spot.x, spot.z, cave.x, cave.z) >= SPACING}`).toBe(`{cave.cave} true`)
			end
			for _, lair in data.lairs or {} do
				T.expect(`{lair.id} {dist(spot.x, spot.z, lair.x, lair.z) >= SPACING}`).toBe(`{lair.id} true`)
			end
			T.expect(roadEdge(Data.map, spot.x, spot.z) >= SPACING).toBe(true)
			for _, lake in data.lakes do
				T.expect(dist(spot.x, spot.z, lake.x, lake.z) >= lake.r + spot.r).toBe(true)
			end
			T.expect(AreaSpawns.nearStream(data.streams, spot.x, spot.z, AreaSpawns.STREAM_CLEARANCE + spot.r))
				.toBe(false)
			for _, c in data.avoid do
				T.expect(dist(spot.x, spot.z, c.x, c.z) >= c.r + spot.r).toBe(true)
			end
		end
	end)
end)

T.describe("World boss: the boss (S149)", function()
	T.it("is no dungeon boss: not in the dungeon list, its map's dungeon keeps Vaelgrath", function()
		T.expect(table.find(Bosses.list, WorldBoss.def())).toBeNil()
		T.expect(table.find(Bosses.world, WorldBoss.def()) ~= nil).toBe(true)
		T.expect((Bosses.forRegion(Data.map) :: any).id).toBe("vaelgrath")
		local def = WorldBoss.def()
		T.expect(def.enrageAfter).toBe(780)
		T.expect(def.timeLimit).toBe(900)
		-- three brands at once
		local brands = 0
		for _, attack in def.attacks do
			if attack.mechanic == "mark" and attack.mark then
				brands = math.max(brands, attack.mark.count or 1)
			end
		end
		T.expect(brands).toBe(3)
	end)
end)

T.describe("World boss: the view (S149b)", function()
	local occ = WorldBoss.list(tuesday(), tuesday() + DAY)[5]
	local function public(phase: string, hp: number?, mine: any?): any
		local p: any = WorldBoss.publicOf(occ, { phase = phase :: any, hp = hp or 1, bossPhase = 1 })
		p.mine = mine
		return p
	end

	T.it("markerOf: the barrow with the next start between occurrences, the phase and its time during one", function()
		local spot = WorldBoss.spot()
		local idle = WorldBoss.markerOf(WorldBoss.idleOf(occ.startsAt - 5000), occ.startsAt - 5000)
		T.expect({ idle.state, idle.map, idle.x, idle.z, idle.at }).toEqual({
			"idle",
			Data.map,
			spot.x,
			spot.z,
			occ.startsAt,
		})
		T.expect(WorldBoss.markerLive(idle)).toBe(false)
		-- before the first send: the next start from the clock
		T.expect(WorldBoss.markerOf(nil, occ.startsAt - 5000).at).toBe(occ.startsAt)
		local warn = WorldBoss.markerOf(public("warn"), occ.startsAt - 60)
		T.expect({ warn.state, warn.at }).toEqual({ "warn", occ.startsAt })
		T.expect(WorldBoss.markerLive(warn)).toBe(true)
		local active = WorldBoss.markerOf(public("active", 0.63), occ.startsAt + 60)
		T.expect({ active.state, active.at, active.hp }).toEqual({ "active", occ.endsAt, 0.63 })
		for _, phase in { "slain", "left" } do
			local m = WorldBoss.markerOf(public(phase), occ.endsAt)
			T.expect({ m.state, m.at == nil, WorldBoss.markerLive(m) }).toEqual({ phase, true, true })
		end
	end)

	T.it("cardOf: asleep / wakes / fights / slain / gone, the reward level, claimed, blows and loot", function()
		local states: { { any } } = {
			{ WorldBoss.idleOf(occ.startsAt - 5000), "sleeps", occ.startsAt },
			{ public("warn"), "wakes", occ.startsAt },
			{ public("active", 0.5), "fights", occ.endsAt },
			{ public("slain"), "slain", -1 },
			{ public("left"), "left", -1 },
		}
		for _, case in states do
			local card = WorldBoss.cardOf(case[1], { level = 90, now = occ.startsAt - 5000 })
			T.expect({ card.state, card.at or -1 }).toEqual({ case[2], case[3] })
		end
		local card = WorldBoss.cardOf(public("active", 0.5), { level = 90, now = occ.startsAt })
		T.expect(card.hp).toBe(0.5)
		T.expect({ card.boss, card.map, card.level, card.minLevel }).toEqual({ Data.boss, Data.map, 100, 80 })
		T.expect(card.placeKey).toBe(WorldBoss.spot().nameKey)
		T.expect(card.players).toEqual({ 10, 20 })
		T.expect(card.belowLevel).toBe(false)
		T.expect(card.claimed).toBe(false)
		T.expect(WorldBoss.cardOf(public("active"), { level = 79, now = 0 }).belowLevel).toBe(true)
		T.expect(WorldBoss.cardOf(public("active"), { level = 80, now = 0 }).belowLevel).toBe(false)
		local claimed = public("active", 1, WorldBoss.mineOf(10, 100, false, "claimed"))
		T.expect(WorldBoss.cardOf(claimed, { level = 90, now = 0 }).claimed).toBe(true)
		local share = public("active", 1, WorldBoss.mineOf(1, 100, false, "share"))
		T.expect(WorldBoss.cardOf(share, { level = 90, now = 0 }).claimed).toBe(false)
		-- the blows to know: the dodges and the three mechanics, never the plain blows
		local kinds: { [string]: string } = {}
		for _, attack in card.attacks do
			kinds[attack.id] = attack.kind
			T.expect({ attack.nameKey, pl[attack.nameKey] ~= nil, en[attack.nameKey] ~= nil }).toEqual({
				attack.nameKey,
				true,
				true,
			})
			local kindKey = `worldboss.card.kind.{attack.kind}`
			T.expect({ kindKey, pl[kindKey] ~= nil, en[kindKey] ~= nil }).toEqual({ kindKey, true, true })
		end
		T.expect(kinds).toEqual({
			glacierStomp = "avoid",
			iceSpikes = "avoid",
			avalanche = "avoid",
			shatterStone = "split",
			frostBrand = "mark",
			endlessWinter = "channel",
		})
		T.expect(card.rarities).toEqual({ Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC })
		T.expect(card.materials).toEqual({ "essence_crystal", "legend_core" })
	end)

	T.it("panelOf: full on the boss's map, one line elsewhere only during the warning", function()
		T.expect(WorldBoss.panelOf(nil, Data.map)).toBeNil()
		T.expect(WorldBoss.panelOf(WorldBoss.idleOf(occ.startsAt - 5000), Data.map)).toBeNil()
		for _, phase in { "warn", "active", "slain", "left" } do
			T.expect(WorldBoss.panelOf(public(phase), Data.map)).toBe("full")
		end
		T.expect(WorldBoss.panelOf(public("warn"), "meadows")).toBe("line")
		T.expect(WorldBoss.panelOf(public("warn"), nil)).toBe("line")
		T.expect(WorldBoss.panelOf(public("active"), "meadows")).toBeNil()
		T.expect(WorldBoss.panelOf(public("slain"), "city")).toBeNil()
	end)

	T.it("zoneNote: the safe circle of a living boss on its map only", function()
		local spot = WorldBoss.spot()
		local edge = spot.r + Data.fighterReach
		T.expect(WorldBoss.zoneNote(public("active"), Data.map, spot.x, spot.z)).toBe("worldboss.safeZone")
		T.expect(WorldBoss.zoneNote(public("active"), Data.map, spot.x + edge, spot.z)).toBe("worldboss.safeZone")
		T.expect(WorldBoss.zoneNote(public("active"), Data.map, spot.x + edge + 1, spot.z)).toBeNil()
		T.expect(WorldBoss.zoneNote(public("active"), "meadows", spot.x, spot.z)).toBeNil()
		for _, phase in { "warn", "slain", "left" } do
			T.expect(WorldBoss.zoneNote(public(phase), Data.map, spot.x, spot.z)).toBeNil()
		end
		T.expect(WorldBoss.zoneNote(WorldBoss.idleOf(0), Data.map, spot.x, spot.z)).toBeNil()
		T.expect(pl["worldboss.safeZone"] ~= nil and en["worldboss.safeZone"] ~= nil).toBe(true)
		T.expect(pl[spot.nameKey] ~= nil and en[spot.nameKey] ~= nil).toBe(true)
	end)
end)

T.describe("World boss: the arena is a reserved place (S149b)", function()
	T.it("the area groups, the arrival points and Auto Hunt keep out of r + LAIR_CLEARANCE", function()
		local spot = WorldBoss.spot()
		local def = Areas.byMap[Data.map]
		local reach = spot.r + AreaSpawns.LAIR_CLEARANCE
		local circles = AreaSpawns.reservedCircles(def)
		T.expect(#circles).toBe(#AreaSpawns.lairCircles(def) + 1)
		local found = false
		for _, c in circles do
			if c.x == spot.x and c.z == spot.z then
				found = true
				T.expect(c.r).toBe(reach)
			end
		end
		T.expect(found).toBe(true)
		-- other maps: only their hideouts
		for _, mapId in { "meadows", "duskwood", "ashen" } do
			local other = Areas.byMap[mapId]
			T.expect(#AreaSpawns.reservedCircles(other)).toBe(#AreaSpawns.lairCircles(other))
			T.expect(AreaSpawns.reservedAt(other, spot.x, spot.z)).toBe(AreaSpawns.lairAt(other, spot.x, spot.z) ~= nil)
		end
		local map = assert(Maps.get(Data.map), Data.map)
		for _, s in AreaSpawns.region(def, { x = map.size.x, z = map.size.z }) do
			if dist(s.position.x, s.position.z, spot.x, spot.z) < reach then
				error(`group {s.id} stands in the world boss's arena`)
			end
		end
		for _, area in def.areas do
			local arrive = (area :: any).arrive
			if arrive then
				T.expect({ area.id, dist(arrive.x, arrive.z, spot.x, spot.z) >= reach }).toEqual({ area.id, true })
			end
		end
		T.expect(AreaSpawns.reservedAt(def, spot.x, spot.z)).toBe(true)
		T.expect(AreaSpawns.reservedAt(def, spot.x + spot.r + 1, spot.z)).toBe(true)
		T.expect(AreaSpawns.reservedAt(def, spot.x + reach - 1, spot.z)).toBe(true)
		T.expect(AreaSpawns.reservedAt(def, spot.x + reach + 1, spot.z)).toBe(false)
	end)

	T.it("the map search leads to the barrow by the boss, the place and the words 'world boss'", function()
		local index = MapSearch.build(function(key: string): string
			return pl[key] or key
		end)
		for _, query in { "Hrimvald", "kurhan", "boss swiata" } do
			local found = false
			for _, result in MapSearch.search(index, query) do
				if result.kind == "worldboss" then
					found = true
					T.expect({ result.map, result.x, result.z }).toEqual({
						Data.map,
						WorldBoss.spot().x,
						WorldBoss.spot().z,
					})
				end
			end
			T.expect({ query, found }).toEqual({ query, true })
		end
	end)
end)

return nil
