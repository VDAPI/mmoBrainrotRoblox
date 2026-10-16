--!strict
-- World events (S101, docs/DESIGN-15.md §4): pure rules WorldEventService runs. The schedule (one event per server
-- about every hour), the region (weighted by players), the hunting ground (median level of the players there), the
-- kind, the Elite II scale by players, the waves, the champion's route, the contribution (damage, healing, shields,
-- intercepted damage), the reward threshold, the reward and the chest. The HUD reads `progressOf`.
-- Points are map-relative (like Data/Spawns); every random choice goes through the given Rng.

local Areas = require("../Data/Areas")
local Data = require("../Data/WorldEvents")
local Exp = require("./Exp")
local ItemRoll = require("./ItemRoll")
local Loot = require("./Loot")
local LootTables = require("../Data/LootTables")
local MonsterAbilities = require("../Data/MonsterAbilities")
local Monsters = require("../Data/Monsters")
local MonsterStats = require("./MonsterStats")
local Rng = require("./Rng")
local Spawns = require("../Data/Spawns")
local AreaAdvice = require("./AreaAdvice")

type Area = Areas.Area

export type KindId = Data.KindId
export type KindDef = Data.KindDef
export type Point = { x: number, z: number }
export type Contribution = { dmg: number, heal: number, shield: number, intercept: number }
export type Reward = { exp: number, gold: number, chest: boolean }

-- What every client sees (the state branch `worldEvent`, WorldEventService). Times are server times
-- (Workspace:GetServerTimeNow), x / z map-relative, `boss` the name key of the commander / champion, `hp` 0-1.
export type Public = {
	id: string,
	kind: KindId,
	phase: "warn" | "active",
	map: string,
	area: string,
	level: number,
	x: number,
	z: number,
	startsAt: number,
	endsAt: number,
	wave: number?,
	waves: number?,
	size: number?, -- monsters of the current wave
	left: number?, -- of them still alive
	boss: string?,
	hp: number?,
}

local WorldEvents = {}

WorldEvents.Data = Data

-- The shared fields of a kind, or nil for an unknown id.
function WorldEvents.kindOf(kind: string): KindDef?
	local def = (Data.kinds :: any)[kind]
	return if def then def :: KindDef else nil
end

function WorldEvents.isRegion(mapId: string): boolean
	return table.find(Data.regions, mapId) ~= nil
end

-- Schedule (B1) ---------------------------------------------------------------------------------------------

-- First start after the server started at `now`.
function WorldEvents.firstStart(now: number, rng: Rng.Rng): number
	return now + rng:float(Data.schedule.first[1], Data.schedule.first[2])
end

-- Next start from the PLANNED start of the previous event (one an hour on average whatever its length), never
-- before `notBefore` (the end of the current event + the gap).
function WorldEvents.nextStart(plannedStart: number, rng: Rng.Rng, notBefore: number?): number
	local at = plannedStart + Data.schedule.interval + rng:float(-Data.schedule.jitter, Data.schedule.jitter)
	if notBefore and at < notBefore then
		return notBefore
	end
	return at
end

-- S129: how long a world event starting now may last at most (the warning when announced, then the longest kind):
-- WorldEventService checks [now, now + window) against Logic/Schedule.blocking (the Blood Moon).
function WorldEvents.window(warn: boolean): number
	local longest = 0
	for _, id in Data.order do
		local def = WorldEvents.kindOf(id)
		if def then
			longest = math.max(longest, def.duration)
		end
	end
	return (if warn then Data.schedule.warn else 0) + longest
end

-- No player in an open region: the next try.
function WorldEvents.retryAt(now: number): number
	return now + Data.schedule.retry
end

-- Region, hunting ground and kind (B2) ----------------------------------------------------------------------

-- An open region weighted by its players (`counts` map id -> players); nil when nobody is in one. Iterates the
-- regions in data order, so the same Rng gives the same region.
function WorldEvents.pickRegion(counts: { [string]: number }, rng: Rng.Rng): string?
	local total = 0
	for _, id in Data.regions do
		local n = counts[id] or 0
		if n > 0 then
			total += n
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:next() * total
	local last: string? = nil
	for _, id in Data.regions do
		local n = counts[id] or 0
		if n > 0 then
			last = id
			roll -= n
			if roll < 0 then
				return id
			end
		end
	end
	return last
end

-- Median of the levels (the lower middle one for an even count, never scaling up); 1 for none.
function WorldEvents.medianLevel(levels: { number }): number
	if #levels == 0 then
		return 1
	end
	local sorted = table.clone(levels)
	table.sort(sorted)
	return sorted[math.floor((#sorted + 1) / 2)]
end

-- Kinds of the ground that can lead an event as an Elite II: known, not passive, with elites and an ability.
function WorldEvents.hostKinds(area: Area): { string }
	local out = {}
	for _, id in area.kinds do
		local def = Monsters.get(id)
		if def and not def.passive and def.elites and def.ability ~= nil then
			table.insert(out, id)
		end
	end
	return out
end

-- Kinds that come in the waves (no passive ones: a rabbit does not invade).
function WorldEvents.waveKinds(area: Area): { string }
	local out = {}
	for _, id in area.kinds do
		local def = Monsters.get(id)
		if def and not def.passive then
			table.insert(out, id)
		end
	end
	return out
end

-- Kinds of the ground with an Elite variant (the Elites of the waves, WorldEvents.elitesOf).
function WorldEvents.eliteKinds(area: Area): { string }
	local out = {}
	for _, id in area.kinds do
		local def = Monsters.get(id)
		if def and not def.passive and def.elites then
			table.insert(out, id)
		end
	end
	return out
end

-- Spawner points of every hunting ground, sorted by spawner id (built once).
local pointsByArea: { [string]: { Point } }? = nil

local function areaPoints(areaId: string): { Point }
	if not pointsByArea then
		local byArea: { [string]: { { id: string, x: number, z: number } } } = {}
		for _, mapId in Data.regions do
			local spawners: { Spawns.Spawner } = Spawns.byMap[mapId] or {}
			for _, spawner in spawners do
				local id = spawner.areaId
				if id then
					local list = byArea[id] or {}
					byArea[id] = list
					table.insert(list, { id = spawner.id, x = spawner.position.x, z = spawner.position.z })
				end
			end
		end
		local built: { [string]: { Point } } = {}
		for id, list in byArea do
			table.sort(list, function(a, b): boolean
				return a.id < b.id
			end)
			local points: { Point } = {}
			for _, entry in list do
				table.insert(points, { x = entry.x, z = entry.z })
			end
			built[id] = points
		end
		pointsByArea = built
	end
	return (pointsByArea :: { [string]: { Point } })[areaId] or {}
end

-- Spawner points of a hunting ground on its map (map-relative), sorted by spawner id.
function WorldEvents.spawnPoints(mapId: string, areaId: string): { Point }
	local _, areaMap = Areas.areaById(areaId)
	if areaMap ~= mapId then
		return {}
	end
	local out = {}
	for _, p in areaPoints(areaId) do
		table.insert(out, { x = p.x, z = p.z })
	end
	return out
end

-- Whether a hunting ground can host an event: a commander / champion kind and at least 2 spawner points.
function WorldEvents.canHost(area: Area): boolean
	return #WorldEvents.hostKinds(area) > 0 and #areaPoints(area.id) >= 2
end

local function fits(area: Area, level: number): boolean
	local w = Data.levelWindow
	return area.lv[1] - w <= level and level <= area.lv[2] + w
end

local function areasOf(mapId: string): { Area }
	local data = Areas.byMap[mapId]
	return if data then data.areas else {}
end

-- The hunting ground of an event on `mapId` for `level`: one of the hosting grounds whose range (with the window)
-- holds the level, not `exclude` while another remains, equal chances; else the hosting ground whose range middle
-- is nearest (the first in data order on a tie); nil on a map without any.
function WorldEvents.pickArea(mapId: string, level: number, rng: Rng.Rng, exclude: string?): Area?
	local hosts: { Area } = {}
	for _, area in areasOf(mapId) do
		if WorldEvents.canHost(area) then
			table.insert(hosts, area)
		end
	end
	if #hosts == 0 then
		return nil
	end
	local candidates: { Area } = {}
	for _, area in hosts do
		if fits(area, level) then
			table.insert(candidates, area)
		end
	end
	if #candidates > 1 and exclude then
		local kept = {}
		for _, area in candidates do
			if area.id ~= exclude then
				table.insert(kept, area)
			end
		end
		candidates = kept
	end
	if #candidates > 0 then
		return rng:pick(candidates)
	end
	local best: Area? = nil
	local bestScore = math.huge
	for _, area in hosts do
		local score = math.abs((area.lv[1] + area.lv[2]) / 2 - level)
		if score < bestScore then
			best, bestScore = area, score
		end
	end
	return best
end

-- A kind by the weights, in `order`.
function WorldEvents.pickKind(rng: Rng.Rng): KindId
	local total = 0
	for _, id in Data.order do
		local def = WorldEvents.kindOf(id)
		total += if def then def.weight else 0
	end
	local roll = rng:next() * total
	for _, id in Data.order do
		local def = WorldEvents.kindOf(id)
		if def then
			roll -= def.weight
			if roll < 0 then
				return def.id
			end
		end
	end
	return (Data.order[#Data.order] :: any) :: KindId
end

-- Level of the event (reward, waves, commander before the Elite II levels): the players' level within the ground.
function WorldEvents.eventLevel(area: Area, level: number): number
	return math.clamp(math.floor(level), area.lv[1], area.lv[2])
end

-- Points and route (B3) -------------------------------------------------------------------------------------

local function dist2(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return dx * dx + dz * dz
end

-- Centre of an event: the spawner point nearest the middle of the ground's rectangle (always on good ground; the
-- middle itself may be a lake or a road).
function WorldEvents.centre(mapId: string, area: Area): Point
	local cx, cz = AreaAdvice.centre(area)
	local mid = { x = cx, z = cz }
	local best: Point? = nil
	local bestD = math.huge
	for _, p in WorldEvents.spawnPoints(mapId, area.id) do
		local d = dist2(p, mid)
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best or mid
end

-- The champion's route (a loop): spawner points of the event ground and of up to `nearbyAreas - 1` other fitting
-- grounds of the map (nearest by their middle), `routePoints` of them spread evenly over those grounds (random
-- within a ground), ordered from the centre by nearest neighbour (the lower index on a tie).
function WorldEvents.route(mapId: string, area: Area, level: number, rng: Rng.Rng): { Point }
	local def = Data.kinds.champion
	local centre = WorldEvents.centre(mapId, area)
	local cx, cz = AreaAdvice.centre(area)
	local others: { { area: Area, d: number, index: number } } = {}
	for index, other in areasOf(mapId) do
		if other.id ~= area.id and WorldEvents.canHost(other) and fits(other, level) then
			local ox, oz = AreaAdvice.centre(other)
			table.insert(others, { area = other, d = (ox - cx) ^ 2 + (oz - cz) ^ 2, index = index })
		end
	end
	table.sort(others, function(a, b): boolean
		if a.d ~= b.d then
			return a.d < b.d
		end
		return a.index < b.index
	end)
	local grounds: { { Point } } = {}
	local own: { Point } = {}
	for _, p in WorldEvents.spawnPoints(mapId, area.id) do
		if not (p.x == centre.x and p.z == centre.z) then
			table.insert(own, p)
		end
	end
	table.insert(grounds, own)
	for i = 1, math.min(#others, def.nearbyAreas - 1) do
		table.insert(grounds, WorldEvents.spawnPoints(mapId, others[i].area.id))
	end
	-- Spread the picks over the grounds: round robin from the event ground, random within each ground.
	for _, list in grounds do
		rng:shuffle(list)
	end
	local picked: { Point } = {}
	local wanted = def.routePoints - 1
	local taken = table.create(#grounds, 0)
	local progress = true
	while #picked < wanted and progress do
		progress = false
		for g, list in grounds do
			if #picked >= wanted then
				break
			end
			if taken[g] < #list then
				taken[g] += 1
				table.insert(picked, list[taken[g]])
				progress = true
			end
		end
	end
	-- Order: nearest neighbour from the centre.
	local route: { Point } = { centre }
	local remaining = picked
	local at = centre
	while #remaining > 0 do
		local bestI, bestD = 1, math.huge
		for i, p in remaining do
			local d = dist2(at, p)
			if d < bestD then
				bestI, bestD = i, d
			end
		end
		at = table.remove(remaining, bestI) :: Point
		table.insert(route, at)
	end
	return route
end

-- Monsters of one wave (all waves equal; `wave` stays for a later growing rule), without its Elites.
function WorldEvents.waveSize(players: number, _wave: number?): number
	local w = Data.kinds.invasion.wave
	return math.min(w.max, w.base + w.perPlayer * math.max(1, players))
end

-- S134c: Elites of wave `wave` (Data elitesPerWave; none past the list).
function WorldEvents.elitesOf(wave: number): number
	return Data.kinds.invasion.elitesPerWave[wave] or 0
end

-- S134c: whether wave `wave` also brings one Elite II of the ground (the last wave, lastWaveElite2).
function WorldEvents.hasWaveElite2(wave: number): boolean
	local def = Data.kinds.invasion
	return def.lastWaveElite2 == true and wave == def.waves
end

-- S134c: the kinds the last wave's Elite II may be: the ground's host kinds other than the commander's, or all of
-- them when the ground has only the commander's.
function WorldEvents.waveElite2Kinds(area: Area, commanderKind: string?): { string }
	local hosts = WorldEvents.hostKinds(area)
	local others = {}
	for _, id in hosts do
		if id ~= commanderKind then
			table.insert(others, id)
		end
	end
	return if #others > 0 then others else hosts
end

-- S134c: the commander's blows on top of its own ability, in priority order (Data commanderAbilities).
function WorldEvents.commanderAbilities(): { MonsterAbilities.Ability }
	local out = {}
	for _, id in Data.kinds.invasion.commanderAbilities do
		local ability = MonsterAbilities.get(id)
		assert(ability, `WorldEvents: unknown commander ability {id}`)
		table.insert(out, ability)
	end
	return out
end

-- Stat multipliers of the commander / champion by the players near it when it spawns.
function WorldEvents.scaleOf(which: "commander" | "champion", players: number): MonsterStats.Mods
	local t = Data.scale[which]
	local hpIndex = math.clamp(math.floor(players), 1, #t.hp)
	local atkIndex = math.clamp(math.floor(players), 1, #t.atk)
	return { hpMul = t.hp[hpIndex], atkMul = t.atk[atkIndex] }
end

-- Contribution and reward (B4) ------------------------------------------------------------------------------

function WorldEvents.emptyContribution(): Contribution
	return { dmg = 0, heal = 0, shield = 0, intercept = 0 }
end

-- Points of a contribution: damage, healing, shields and intercepted damage count alike (DESIGN-15 §4).
function WorldEvents.points(c: Contribution): number
	local s = Data.share
	return c.dmg + c.heal * s.healMul + c.shield * s.shieldMul + c.intercept * s.interceptMul
end

-- Points needed for the reward: share.min of all points, or hpEquivalent normal monsters of the event level,
-- whichever is lower; nobody fought (total 0) = never.
function WorldEvents.threshold(total: number, level: number): number
	if total <= 0 then
		return math.huge
	end
	local s = Data.share
	return math.min(s.min * total, s.hpEquivalent * MonsterStats.baseHp(level))
end

-- Whether a participant gets the event reward: enough points and not more than maxLevelAbove over the event.
function WorldEvents.eligible(points: number, total: number, eventLevel: number, charLevel: number): boolean
	return points > 0
		and points >= WorldEvents.threshold(total, eventLevel)
		and charLevel <= eventLevel + Data.share.maxLevelAbove
end

-- The event reward of a character: EXP (no quest budget multiplier: events stand outside it, DESIGN-15 §4) with
-- the level difference rule, gold, and the chest on a victory. On a defeat failMul of both and no chest.
function WorldEvents.reward(eventLevel: number, charLevel: number, success: boolean): Reward
	local r = Data.reward
	local mul = if success then 1 else r.failMul
	local exp = r.expKills * Exp.monsterExp(eventLevel, "normal") * Exp.levelDiffMultiplier(charLevel, eventLevel) * mul
	local gold = r.goldKills * MonsterStats.gold(eventLevel, "normal", 0.5) * mul
	return { exp = math.floor(exp + 0.5), gold = math.floor(gold + 0.5), chest = success }
end

-- The chest item: drop level from the lower of the two levels, a boss-slot item (classBias for the class), then
-- the rarity (the S100 order: dropLevel -> pickItem -> weighted). nil when no item exists for the level.
function WorldEvents.rollChest(eventLevel: number, charLevel: number, classId: string?, rng: Rng.Rng): Loot.ItemDrop?
	local chest = Data.reward.chest
	local ilvl = ItemRoll.dropLevel(math.max(1, math.min(charLevel, eventLevel)), rng)
	local defId = Loot.pickItem(LootTables.bossSlots, ilvl, chest.classBias, classId, rng)
	if not defId then
		return nil
	end
	local rarity = rng:weighted(chest.rarity :: { [number]: number })
	return { defId = defId, ilvl = ilvl, rarity = rarity, forClass = classId }
end

-- Client state (B5) -----------------------------------------------------------------------------------------

-- Progress 0-1 for the HUD bar: an Invasion by its waves until the commander comes, then the commander's HP; the
-- champion by its HP.
function WorldEvents.progressOf(p: Public): number
	if p.boss ~= nil then
		return math.clamp(1 - (p.hp or 1), 0, 1)
	end
	if p.kind ~= "invasion" then
		return 0
	end
	local waves = p.waves or 0
	local wave = p.wave or 0
	if waves <= 0 or wave <= 0 then
		return 0
	end
	local size = p.size or 0
	local killed = if size > 0 then math.clamp((size - (p.left or size)) / size, 0, 1) else 0
	return math.clamp((wave - 1 + killed) / waves, 0, 1)
end

return WorldEvents
