--!strict
-- World events (S101, docs/DESIGN-15.md §4). About every hour each server starts one event in an open region with
-- players (weighted by players), on the hunting ground that fits the median level of the players there:
--   * Invasion: waves of the ground's monsters around its centre, then the commander (an Elite II scaled by the
--     players near it); victory = the commander dies before the end.
--   * Wandering Champion: an Elite II walking a route through the region (Monster.SetPatrol) for 15 min; victory =
--     it dies before the end, else it leaves.
-- Announced to the server 2 min before and at the start (AnnounceService.Server), shown to every player through
-- the runtime state branch `worldEvent` (map marker, minimap, HUD panel on the event's map). Contribution =
-- damage to the event's monsters (their damageBy, kept across the S22 reset) + healing and shields on players in
-- the event's radius (ResourceService.Healed) + damage taken for them (StatusEffectService.Intercepted). At the
-- end every participant over the threshold gets EXP, gold and on a victory a bound Unique / Heroic chest item
-- (backpack, else mail, else a personal bag), and one step of the weekly "event" contract (QuestEvents "event").
-- The rules are pure (Logic/WorldEvents); the schedule lives in memory (a restart starts over). All times are
-- server times (Workspace:GetServerTimeNow).
-- S129: no world event starts when its window (warning + the longest kind) meets a wall-clock event that blocks world
-- events (Logic/Schedule.blocking over Data/ScheduledEvents, in Util/Clock time; the Blood Moon and its quiet 10 min
-- before) or a blocker added by another service (AddBlocker: a Blood Moon forced by an admin).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Analytics = require(script.Parent.Parent.Analytics)
local Areas = require(Shared.Data.Areas)
local Clock = require(Shared.Util.Clock)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Rng = require(Shared.Logic.Rng)
local Schedule = require(Shared.Logic.Schedule)
local ScheduledEvents = require(Shared.Data.ScheduledEvents)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Types = require(Shared.Types)
local WorldEvents = require(Shared.Logic.WorldEvents)

local Data = WorldEvents.Data
local log = Log.new("WorldEventService")

local WorldEventService = {
	Name = "WorldEventService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ZoneService",
		"EntityService",
		"MonsterService",
		"CombatService",
		"ResourceService",
		"StatusEffectService",
		"StatService",
		"LevelService",
		"InventoryService",
		"MailService",
		"LootService",
		"AnnounceService",
		"WorldService",
	},
}

type Contribution = WorldEvents.Contribution
type EndMode = "normal" | "lost" | "cancel"

type Event = {
	id: string,
	kind: WorldEvents.KindId,
	def: WorldEvents.KindDef,
	phase: "warn" | "active",
	map: string,
	mapKey: string,
	offset: Vector3,
	area: Areas.Area,
	level: number,
	centre: Vector3, -- world space, on the ground
	plannedStart: number,
	startsAt: number,
	endsAt: number,
	monsters: { [any]: boolean }, -- every live monster of the event (Monster objects)
	byEntity: { [string]: any }, -- entity id -> monster (MonsterKilled lookup)
	seen: { [any]: { [Player]: number } }, -- damageBy of each live monster at the last look
	bank: { [Player]: Contribution }, -- banked contribution (damage of dead / reset monsters, heals, shields)
	chars: { [Player]: string }, -- the character that earned the first point (the reward goes only to it)
	wave: number,
	waveSize: number,
	waveAlive: number,
	waveStarted: number,
	nextWaveAt: number,
	waveMembers: { [any]: boolean },
	points: { Vector3 }, -- wave spawn points (world)
	route: { Vector3 }?, -- champion route (world)
	bossKind: string?,
	bossKey: string?,
	boss: any?,
	commanderDue: boolean,
	bossDead: boolean,
	bossGone: boolean,
	dirty: boolean,
}

local PlayerStateService: any
local CharacterService: any
local ZoneService: any
local MonsterService: any
local CombatService: any
local ResourceService: any
local StatusEffectService: any
local StatService: any
local LevelService: any
local InventoryService: any
local MailService: any
local LootService: any
local AnnounceService: any
local WorldService: any

local rng = Rng.new()
local current: Event? = nil
local nextAt = 0
local lastArea: string? = nil
local counter = 0
local lastPublish = 0
local lastSent: { [Player]: string } = {}

local PUBLISH_EVERY = 2

-- S129: (from, to) in Util/Clock time -> true while that window is taken (BloodMoonService: a forced Blood Moon)
type Blocker = { check: (from: number, to: number) -> boolean, nameKey: string }
local blockers: { Blocker } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function playing(player: Player): boolean
	return PlayerStateService.GetPhase(player) == "playing" and PlayerStateService.GetCharacter(player) ~= nil
end

local function mapOf(player: Player): string?
	local zone = ZoneService.GetZone(player)
	return if zone then zone.map else nil
end

-- Living players on the event's map within `radius` of `at` (flat).
local function playersNear(e: Event, at: Vector3, radius: number): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if playing(player) and not ResourceService.IsDead(player) and mapOf(player) == e.map then
			local root = rootOf(player)
			if root and flatDistance(root.Position, at) <= radius then
				table.insert(out, player)
			end
		end
	end
	return out
end

-- Players and their levels in the open regions (built maps only).
local function regionPlayers(): ({ [string]: number }, { [string]: { number } })
	local counts: { [string]: number } = {}
	local levels: { [string]: { number } } = {}
	for _, player in Players:GetPlayers() do
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		local map = mapOf(player)
		if
			char
			and map
			and PlayerStateService.GetPhase(player) == "playing"
			and WorldEvents.isRegion(map)
			and WorldService.IsBuilt(map)
		then
			counts[map] = (counts[map] or 0) + 1
			local list = levels[map] or {}
			levels[map] = list
			table.insert(list, char.level)
		end
	end
	return counts, levels
end

local function world(e: Event, p: WorldEvents.Point): Vector3
	return WorldService.FloorAt(e.map, p.x, p.z)
end

local function areaArg(e: Event): string
	return "@" .. e.area.nameKey
end

-- Contribution -------------------------------------------------------------------------------------------

local function note(e: Event, player: Player)
	if e.chars[player] == nil then
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		if char then
			e.chars[player] = char.id
		end
	end
end

local function bankAdd(e: Event, player: Player, field: "dmg" | "heal" | "shield" | "intercept", amount: number)
	if amount <= 0 or amount ~= amount then
		return
	end
	local c = e.bank[player]
	if not c then
		c = WorldEvents.emptyContribution()
		e.bank[player] = c
	end
	c[field] += amount
	note(e, player)
end

-- Reads a monster's damageBy: a value below the last look means the S22 reset cleared it, so the old value goes
-- to the bank first.
local function harvest(e: Event, monster: any)
	local seen = e.seen[monster]
	if not seen then
		return
	end
	local damageBy: { [Player]: number } = monster.damageBy
	for player, before in seen do
		local value = damageBy[player]
		if value == nil or value < before then
			bankAdd(e, player, "dmg", before)
			seen[player] = nil
		end
	end
	for player, value in damageBy do
		if value > 0 then
			seen[player] = value
			note(e, player)
		end
	end
end

-- Points of every participant and their sum.
local function contributions(e: Event): ({ [Player]: number }, number)
	local per: { [Player]: number } = {}
	for player, c in e.bank do
		per[player] = WorldEvents.points(c)
	end
	for _, seen in e.seen do
		for player, value in seen do
			per[player] = (per[player] or 0) + value
		end
	end
	local total = 0
	for _, value in per do
		total += value
	end
	return per, total
end

-- Takes a monster off the event's lists (after harvesting it). `killed` = died in combat (MonsterKilled).
local function removeMonster(e: Event, monster: any, killed: boolean)
	if not e.monsters[monster] then
		return
	end
	harvest(e, monster)
	local seen: { [Player]: number } = e.seen[monster] or {}
	for player, value in seen do
		bankAdd(e, player, "dmg", value)
	end
	e.seen[monster] = nil
	e.monsters[monster] = nil
	if monster.entity then
		e.byEntity[monster.entity.id] = nil
	end
	if e.waveMembers[monster] then
		e.waveMembers[monster] = nil
		e.waveAlive = math.max(0, e.waveAlive - 1)
		e.dirty = true
	end
	if monster == e.boss then
		e.boss = nil
		if killed then
			e.bossDead = true
		else
			e.bossGone = true
		end
		e.dirty = true
	end
end

-- Whether a healed / shielded / guarded player stands in the event's radius (Invasion: the centre; champion: the
-- champion, before it spawns its first waypoint).
local function inRange(e: Event, target: Player): boolean
	if mapOf(target) ~= e.map then
		return false
	end
	local root = rootOf(target)
	if not root then
		return false
	end
	local anchor = e.centre
	if e.kind == "champion" then
		if e.boss and e.boss:IsAlive() then
			anchor = e.boss:Position()
		elseif e.route then
			anchor = e.route[1]
		end
	end
	return flatDistance(root.Position, anchor) <= e.def.radius
end

-- Client state (the `worldEvent` branch) -------------------------------------------------------------------

local function publicOf(e: Event): WorldEvents.Public
	local x, z = e.centre.X - e.offset.X, e.centre.Z - e.offset.Z
	local boss = e.boss
	if e.kind == "champion" and boss and boss:IsAlive() then
		local p = boss:Position()
		x, z = p.X - e.offset.X, p.Z - e.offset.Z
	end
	local p: WorldEvents.Public = {
		id = e.id,
		kind = e.kind,
		phase = e.phase,
		map = e.map,
		area = e.area.id,
		level = e.level,
		x = math.floor(x + 0.5),
		z = math.floor(z + 0.5),
		startsAt = e.startsAt,
		endsAt = e.endsAt,
	}
	if e.phase == "active" then
		if e.kind == "invasion" then
			p.wave = e.wave
			p.waves = Data.kinds.invasion.waves
			p.size = e.waveSize
			p.left = e.waveAlive
		end
		if boss and boss:IsAlive() then
			p.boss = e.bossKey
			p.hp = math.floor(boss.hp / math.max(1, boss.stats.maxHp) * 100 + 0.5) / 100
		elseif e.kind == "champion" and e.bossKey then
			p.boss = e.bossKey
			p.hp = 1
		end
	end
	return p
end

local function publishTo(player: Player, base: WorldEvents.Public?, per: { [Player]: number }, total: number)
	if not PlayerStateService.HasState(player) then
		return
	end
	local value: any = nil
	local e = current
	if base and e then
		value = table.clone(base) :: any
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		local points = per[player] or 0
		value.mine = {
			points = math.floor(points),
			ok = char ~= nil and WorldEvents.eligible(points, total, e.level, char.level),
		}
	end
	local key = if value then HttpService:JSONEncode(value) else ""
	if lastSent[player] == key then
		return
	end
	lastSent[player] = key
	PlayerStateService.Set(player, { "worldEvent" }, value)
end

local function publishAll()
	lastPublish = now()
	local e = current
	local per, total = {}, 0
	local base: WorldEvents.Public? = nil
	if e then
		e.dirty = false
		per, total = contributions(e)
		base = publicOf(e)
	end
	for _, player in Players:GetPlayers() do
		publishTo(player, base, per, total)
	end
end

local function publishOne(player: Player)
	lastSent[player] = nil
	local e = current
	if e then
		local per, total = contributions(e)
		publishTo(player, publicOf(e), per, total)
	else
		publishTo(player, nil, {}, 0)
	end
end

-- Monsters ---------------------------------------------------------------------------------------------------

local function spawnOne(
	e: Event,
	kind: string,
	variant: "normal" | "elite" | "elite2",
	level: number,
	at: Vector3,
	groupSize: number?,
	mods: any?
): any?
	local attributes: { [string]: any } = { AreaId = e.area.id, WorldEvent = e.id }
	if groupSize then
		attributes.GroupSize = groupSize
	end
	local facing = CFrame.Angles(0, rng:float(0, math.pi * 2), 0)
	local monster = MonsterService.SpawnAt(kind, variant, level, CFrame.new(at) * facing, nil, attributes, mods)
	if not monster then
		return nil
	end
	monster.home = e.centre
	monster.leashRange = e.def.leash
	monster.levelCap = e.area.lv[2]
	e.monsters[monster] = true
	e.seen[monster] = {}
	if monster.entity then
		e.byEntity[monster.entity.id] = monster
	end
	return monster
end

local function waveLevel(e: Event): number
	return rng:int(math.max(e.area.lv[1], e.level - 2), math.min(e.area.lv[2], e.level + 1))
end

local function spawnWave(e: Event, t: number)
	local def = Data.kinds.invasion
	e.wave += 1
	-- the monsters of earlier waves still count for the contribution, no longer for the wave
	e.waveMembers = {}
	local players = #playersNear(e, e.centre, def.radius)
	local size = WorldEvents.waveSize(players, e.wave)
	local kinds = WorldEvents.waveKinds(e.area)
	local spawned = 0
	local remaining = if #kinds > 0 and #e.points > 0 then size else 0
	while remaining > 0 do
		local n = math.min(def.wave.cluster, remaining)
		remaining -= n
		local point = e.points[rng:int(1, #e.points)]
		for _ = 1, n do
			local angle = rng:float(0, math.pi * 2)
			local r = rng:float(0, 8)
			local at = point + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
			local monster = spawnOne(e, rng:pick(kinds), "normal", waveLevel(e), at, n)
			if monster then
				spawned += 1
				e.waveMembers[monster] = true
			end
		end
	end
	if table.find(def.eliteWaves, e.wave) and #e.points > 0 then
		local elites = WorldEvents.eliteKinds(e.area)
		if #elites > 0 then
			local monster = spawnOne(e, rng:pick(elites), "elite", waveLevel(e), e.points[rng:int(1, #e.points)])
			if monster then
				spawned += 1
				e.waveMembers[monster] = true
			end
		end
	end
	e.waveSize = spawned
	e.waveAlive = spawned
	e.waveStarted = t
	e.nextWaveAt = t + def.waveEvery
	e.dirty = true
end

local function pickBossKind(e: Event): string?
	if not e.bossKind then
		local kinds = WorldEvents.hostKinds(e.area)
		if #kinds == 0 then
			return nil
		end
		local kind = rng:pick(kinds)
		local def = Monsters.get(kind)
		e.bossKind = kind
		e.bossKey = if def then def.nameKeys.elite2 else nil
	end
	return e.bossKind
end

local function spawnCommander(e: Event)
	local kind = pickBossKind(e)
	if not kind then
		return
	end
	local players = math.max(1, #playersNear(e, e.centre, e.def.radius))
	local level = math.min(e.area.lv[2], e.level + 1)
	local monster = spawnOne(e, kind, "elite2", level, e.centre, nil, WorldEvents.scaleOf("commander", players))
	if monster then
		e.boss = monster
		e.bossKey = monster:Name()
		e.dirty = true
		AnnounceService.Server("event.commander", { name = "@" .. monster:Name(), area = areaArg(e) })
	end
end

local function spawnChampion(e: Event)
	local kind = pickBossKind(e)
	local route = e.route
	if not kind or not route or #route == 0 then
		return
	end
	local players = math.max(1, #playersNear(e, route[1], e.def.radius))
	local level = math.min(e.area.lv[2], e.level + 2)
	local monster = spawnOne(e, kind, "elite2", level, route[1], nil, WorldEvents.scaleOf("champion", players))
	if monster then
		monster:SetPatrol(route, Data.kinds.champion.pause)
		e.boss = monster
		e.bossKey = monster:Name()
		e.dirty = true
	end
end

-- Start and end ----------------------------------------------------------------------------------------------

local function scheduleNext(from: number, notBefore: number?)
	nextAt = WorldEvents.nextStart(from, rng, notBefore)
end

local function activate(e: Event, t: number)
	e.phase = "active"
	e.dirty = true
	local map = { area = areaArg(e), region = "@" .. e.mapKey, level = e.level }
	if e.kind == "invasion" then
		AnnounceService.Server("event.start.invasion", map)
		spawnWave(e, t)
	else
		pickBossKind(e)
		spawnChampion(e)
		AnnounceService.Server("event.start.champion", {
			name = "@" .. (e.bossKey or "event.champion.name"),
			region = "@" .. e.mapKey,
			area = areaArg(e),
		})
	end
end

-- Begins an event on `area` of `mapId`; with `warn` it starts after the 2 min warning.
local function begin(mapId: string, area: Areas.Area, kind: WorldEvents.KindId, level: number, warn: boolean): Event?
	local map = Maps.get(mapId)
	local def = WorldEvents.kindOf(kind)
	if not map or not def then
		return nil
	end
	local t = now()
	counter += 1
	local e: Event = {
		id = `{game.JobId ~= "" and string.sub(game.JobId, 1, 6) or "local"}-{counter}`,
		kind = kind,
		def = def,
		phase = "warn",
		map = mapId,
		mapKey = map.nameKey,
		offset = Vector3.new(map.offset.x, map.offset.y, map.offset.z),
		area = area,
		level = WorldEvents.eventLevel(area, level),
		centre = Vector3.zero,
		plannedStart = t,
		startsAt = t + (if warn then Data.schedule.warn else 0),
		endsAt = 0,
		monsters = {},
		byEntity = {},
		seen = {},
		bank = {},
		chars = {},
		wave = 0,
		waveSize = 0,
		waveAlive = 0,
		waveStarted = t,
		nextWaveAt = math.huge,
		waveMembers = {},
		points = {},
		route = nil,
		bossKind = nil,
		bossKey = nil,
		boss = nil,
		commanderDue = false,
		bossDead = false,
		bossGone = false,
		dirty = true,
	}
	e.endsAt = e.startsAt + def.duration
	e.plannedStart = e.startsAt
	e.centre = world(e, WorldEvents.centre(mapId, area))
	for _, p in WorldEvents.spawnPoints(mapId, area.id) do
		table.insert(e.points, world(e, p))
	end
	if kind == "champion" then
		local route = {}
		for _, p in WorldEvents.route(mapId, area, e.level, rng) do
			table.insert(route, world(e, p))
		end
		e.route = route
	end
	current = e
	lastArea = area.id
	log:info("%s on %s (%s), level %d, starts in %ds", kind, area.id, mapId, e.level, math.floor(e.startsAt - t))
	if warn then
		AnnounceService.Server(`event.warn.{kind}`, { area = areaArg(e), region = "@" .. map.nameKey, level = e.level })
	else
		activate(e, t)
	end
	publishAll()
	return e
end

local function mailChest(player: Player, charId: string, item: Types.ItemInstance)
	local sent, err = MailService.Send(player.UserId, {
		from = "system",
		subjectKey = "mail.subject.worldEvent",
		items = { item },
		charId = charId,
	})
	if sent then
		if player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "event.chestMailed", nil, "info")
		end
		return
	end
	log:warn("world event chest for %s not mailed: %s", player.Name, tostring(err))
	local root = if player.Parent ~= nil then rootOf(player) else nil
	if root then
		LootService.SpawnBag(player, root.Position, { item }, "worldEvent", true)
		Net.Fire(player, "Toast", "event.chestBag", nil, "warning")
	else
		log:warn("world event chest %s of %s lost: the player left", item.id, player.Name)
	end
end

local function giveReward(player: Player, char: Types.CharacterData, e: Event, success: boolean)
	local r = WorldEvents.reward(e.level, char.level, success)
	local expBonus = StatService.GetValue(player, "expBonus")
	LevelService.GiveExp(player, r.exp, "worldEvent")
	if r.gold > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold + r.gold
		end)
		Analytics.gold(player, r.gold, balance, "worldEvent")
	end
	local shownExp = if char.level >= 100 then 0 else math.floor(r.exp * (1 + expBonus / 100))
	Net.Fire(player, "CombatFx", { { k = "reward", exp = shownExp, gold = r.gold } })
	local item: Types.ItemInstance? = nil
	if r.chest then
		local drop = WorldEvents.rollChest(e.level, char.level, char.class, rng)
		if drop then
			local rolled =
				ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, InventoryService.NewUid(), drop.forClass)
			rolled.bound = Data.reward.chest.bound
			item = rolled
		else
			log:warn("no world event chest item at level %d for %s", e.level, char.class)
		end
	end
	if item then
		if not InventoryService.IsTradeLocked(player) and InventoryService.CanFit(player, { item }) then
			local leftover = InventoryService.AddItem(player, item)
			if leftover > 0 then
				log:warn("%s: world event chest %s did not fit after CanFit", player.Name, item.id)
			end
		else
			task.spawn(mailChest, player, char.id, item)
		end
		Net.Fire(
			player,
			"Toast",
			"event.reward",
			{ exp = shownExp, gold = r.gold, item = `#item:{item.id}:{item.up}` },
			"success"
		)
	else
		Net.Fire(player, "Toast", "event.rewardNoChest", { exp = shownExp, gold = r.gold }, "success")
	end
	QuestEvents.fire(player, "event", { eventId = e.id, kind = e.kind, success = success, map = e.map })
end

-- Rewards every participant still here with the same character. Returns how many got the reward.
local function rewardAll(e: Event, success: boolean): number
	local per, total = contributions(e)
	local rewarded = 0
	for player, points in per do
		if points > 0 and player.Parent ~= nil then
			local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
			if char and PlayerStateService.GetPhase(player) == "playing" and e.chars[player] == char.id then
				if WorldEvents.eligible(points, total, e.level, char.level) then
					local ok, err = pcall(function()
						giveReward(player, char, e, success)
					end)
					if ok then
						rewarded += 1
					else
						log:error("world event reward for %s failed: %s", player.Name, tostring(err))
					end
				elseif char.level > e.level + Data.share.maxLevelAbove then
					Net.Fire(player, "Toast", "event.tooHigh", nil, "info")
				else
					Net.Fire(player, "Toast", "event.noReward", nil, "info")
				end
			end
		end
	end
	return rewarded
end

-- Ends the event: the contribution of every monster is banked, the living ones leave (no rewards), then the
-- rewards ("normal"), none ("lost": the commander / champion vanished, "cancel": an admin called it off).
local function finish(e: Event, success: boolean, mode: EndMode)
	if current ~= e then
		return
	end
	for monster in table.clone(e.monsters) do
		removeMonster(e, monster, false)
		if monster.state ~= "dead" then
			MonsterService.Despawn(monster)
		end
	end
	current = nil
	local t = now()
	local rewarded = if mode == "normal" then rewardAll(e, success) else 0
	local args = { kind = "@" .. e.def.nameKey, area = areaArg(e), n = rewarded }
	if mode == "cancel" then
		AnnounceService.Server("event.end.cancelled", args)
		scheduleNext(t)
	else
		AnnounceService.Server(if success then "event.end.success" else "event.end.fail", args)
		scheduleNext(e.plannedStart, t + Data.schedule.gapAfter)
	end
	log:info("%s on %s ended (%s, %s), %d rewarded", e.kind, e.area.id, mode, tostring(success), rewarded)
	publishAll()
end

-- The schedule's own start: a region by its players, the ground by their median level.
local function plan(t: number)
	local counts, levels = regionPlayers()
	local region = WorldEvents.pickRegion(counts, rng)
	if not region then
		nextAt = WorldEvents.retryAt(t) + Data.schedule.warn
		return
	end
	local median = WorldEvents.medianLevel(levels[region] or {})
	local area = WorldEvents.pickArea(region, median, rng, lastArea)
	if not area then
		nextAt = WorldEvents.retryAt(t) + Data.schedule.warn
		return
	end
	-- the next one counts from this one's start (plannedStart), whatever its length
	if not begin(region, area, WorldEvents.pickKind(rng), median, true) then
		nextAt = WorldEvents.retryAt(t) + Data.schedule.warn
	end
end

local function stepInvasion(e: Event, t: number)
	local def = Data.kinds.invasion
	if not e.commanderDue then
		local cleared = e.waveSize > 0
			and (e.waveSize - e.waveAlive) / e.waveSize >= def.clearShare
			and t - e.waveStarted >= def.minWaveGap
		if t - e.startsAt >= def.commanderAt then
			e.commanderDue = true
		elseif t >= e.nextWaveAt or cleared then
			if e.wave >= def.waves then
				e.commanderDue = true
			else
				spawnWave(e, t)
			end
		end
	end
	if e.commanderDue and not e.boss and not e.bossDead and not e.bossGone then
		spawnCommander(e)
	end
end

-- S129: what a world event lasting `window` s from now would overlap: (the name key, the scheduled occurrence or nil
-- for a blocker); nil when free. A blocker that errors blocks (fail closed).
local function blockedBy(window: number): (string?, Schedule.Occurrence?)
	local from = Clock.now()
	local to = from + window
	local occ = Schedule.blocking(ScheduledEvents.list, from, to)
	if occ then
		local def = ScheduledEvents.get(occ.key)
		return if def then def.nameKey else occ.key, occ
	end
	for _, blocker in blockers do
		local ok, result = pcall(blocker.check, from, to)
		if not ok or result == true then
			return blocker.nameKey, nil
		end
	end
	return nil, nil
end

local function step()
	if not ServerMode.isWorld() then
		return -- S127: no world events on arena/tournament servers
	end
	local t = now()
	local e = current
	if not e then
		if t >= nextAt - Data.schedule.warn then
			local nameKey, occ = blockedBy(WorldEvents.window(true))
			if nameKey then
				-- the first try after the blocking event (its end in Clock time; a blocker: the usual retry)
				local wait = if occ then math.max(0, occ.endsAt - Clock.now()) else 0
				nextAt = t + wait + Data.schedule.retry + Data.schedule.warn
				log:info("world event postponed by %s for %d s", nameKey, math.floor(wait + Data.schedule.retry))
				return
			end
			plan(t)
		end
		return
	end
	if e.phase == "warn" then
		if t >= e.startsAt then
			activate(e, t)
			publishAll()
		end
		return
	end
	-- Monsters destroyed from outside (admin /killall and Despawn, map unload) leave the lists here.
	for monster in table.clone(e.monsters) do
		if monster.state == "dead" or monster.model.Parent == nil then
			removeMonster(e, monster, false)
		else
			harvest(e, monster)
		end
	end
	if e.kind == "invasion" then
		stepInvasion(e, t)
	elseif not e.boss and not e.bossDead and not e.bossGone then
		spawnChampion(e)
	end
	if e.bossDead then
		finish(e, true, "normal")
	elseif e.bossGone then
		finish(e, false, "lost")
	elseif t >= e.endsAt then
		-- a champion that never appeared (monster budget) gives nothing
		finish(e, false, if e.kind == "champion" and e.bossKey and e.boss == nil then "lost" else "normal")
	elseif e.dirty or t - lastPublish >= PUBLISH_EVERY then
		publishAll()
	end
end

-- Admin (/event) ---------------------------------------------------------------------------------------------

export type Info = {
	active: boolean,
	kind: string?,
	phase: string?,
	area: string?,
	level: number?,
	progress: string?,
	timeLeft: number?,
	participants: number?,
	top: { { name: string, points: number, ok: boolean } }?,
	nextIn: number?,
	counts: { [string]: number }?,
}

function WorldEventService.Info(): Info
	local t = now()
	local e = current
	if not e then
		local counts = regionPlayers()
		return { active = false, nextIn = math.max(0, nextAt - t), counts = counts }
	end
	local per, total = contributions(e)
	local rows = {}
	for player, points in per do
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		table.insert(rows, {
			name = if char then char.name else player.Name,
			points = math.floor(points),
			ok = char ~= nil and WorldEvents.eligible(points, total, e.level, char.level),
		})
	end
	table.sort(rows, function(a, b): boolean
		return a.points > b.points
	end)
	local top = {}
	for i = 1, math.min(5, #rows) do
		table.insert(top, rows[i])
	end
	local progress: string
	local boss = e.boss
	if boss and boss:IsAlive() then
		progress = `{e.bossKey} {math.floor(boss.hp / math.max(1, boss.stats.maxHp) * 100 + 0.5)}%`
	elseif e.kind == "invasion" and e.phase == "active" then
		progress = `{e.wave}/{Data.kinds.invasion.waves} ({e.waveAlive}/{e.waveSize})`
	else
		progress = "-"
	end
	return {
		active = true,
		kind = e.kind,
		phase = e.phase,
		area = e.area.id,
		level = e.level,
		progress = progress,
		timeLeft = math.max(0, (if e.phase == "warn" then e.startsAt else e.endsAt) - t),
		participants = #rows,
		top = top,
	}
end

-- Starts an event now (`warn` = after the 2 min warning). `kind` nil / "random" = by weight; `areaId` nil = the
-- admin's open region at their level, else the usual pick.
function WorldEventService.Force(
	kind: string?,
	areaId: string?,
	warn: boolean,
	by: Player
): (boolean, string?, { [string]: any }?)
	if current then
		return false, "admin.event.busy"
	end
	-- S129: not over a scheduled event (Blood Moon) or a forced one
	local blockedKey = blockedBy(WorldEvents.window(warn))
	if blockedKey then
		return false, "admin.event.blocked", { name = "@" .. blockedKey }
	end
	local chosen: WorldEvents.KindId = if kind and WorldEvents.kindOf(kind)
		then (kind :: any) :: WorldEvents.KindId
		else WorldEvents.pickKind(rng)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(by)
	local level = if char then char.level else 1
	local mapId: string? = nil
	local area: Areas.Area? = nil
	if areaId then
		local found, foundMap = Areas.areaById(areaId)
		if not found or not foundMap or not WorldEvents.isRegion(foundMap) or not WorldEvents.canHost(found) then
			return false, "admin.event.badArea"
		end
		area, mapId = found, foundMap
	else
		local here = mapOf(by)
		if here and WorldEvents.isRegion(here) then
			mapId = here
			area = WorldEvents.pickArea(here, level, rng, lastArea)
		else
			local counts, levels = regionPlayers()
			local region = WorldEvents.pickRegion(counts, rng)
			if region then
				mapId = region
				level = WorldEvents.medianLevel(levels[region] or {})
				area = WorldEvents.pickArea(region, level, rng, lastArea)
			end
		end
	end
	if not mapId or not area then
		return false, "admin.event.noRegion"
	end
	local e = begin(mapId, area, chosen, level, warn)
	if not e then
		return false, "admin.event.badArea"
	end
	return true, nil
end

-- Calls the running event off without rewards.
function WorldEventService.Stop(): boolean
	local e = current
	if not e then
		return false
	end
	finish(e, false, "cancel")
	return true
end

-- Moves the next scheduled start `seconds` from now.
function WorldEventService.SetNext(seconds: number)
	nextAt = now() + math.max(0, seconds)
end

-- S129: `check(from, to)` (Util/Clock time) -> true while a world event in that window must not start; `nameKey`
-- names it for /event start. Returns the function that removes it.
function WorldEventService.AddBlocker(check: (from: number, to: number) -> boolean, nameKey: string): () -> ()
	local blocker: Blocker = { check = check, nameKey = nameKey }
	table.insert(blockers, blocker)
	return function()
		local index = table.find(blockers, blocker)
		if index then
			table.remove(blockers, index)
		end
	end
end

function WorldEventService.Current(): Event?
	return current
end

function WorldEventService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ZoneService = registry.Get("ZoneService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	ResourceService = registry.Get("ResourceService")
	StatusEffectService = registry.Get("StatusEffectService")
	StatService = registry.Get("StatService")
	LevelService = registry.Get("LevelService")
	InventoryService = registry.Get("InventoryService")
	MailService = registry.Get("MailService")
	LootService = registry.Get("LootService")
	AnnounceService = registry.Get("AnnounceService")
	WorldService = registry.Get("WorldService")
end

function WorldEventService.Start()
	nextAt = WorldEvents.firstStart(now(), rng)
	CombatService.MonsterKilled:Connect(function(info: any)
		local e = current
		local monster = e and e.byEntity[info.entityId]
		if e and monster then
			removeMonster(e, monster, true)
		end
	end)
	ResourceService.Healed:Connect(function(target: Player, amount: number, source: Player?, kind: string)
		local e = current
		if e and e.phase == "active" and source and inRange(e, target) then
			bankAdd(e, source, if kind == "shield" then "shield" else "heal", amount)
		end
	end)
	-- S61: the part a guard took for an ally before their own reductions (like the fight summary).
	StatusEffectService.Intercepted:Connect(function(guard: Player, target: Player, moved: number)
		local e = current
		if e and e.phase == "active" and inRange(e, target) then
			bankAdd(e, guard, "intercept", moved)
		end
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		publishOne(player)
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				step()
			end)
			if not ok then
				log:error("world event step failed: %s", tostring(err))
			end
			task.wait(1)
		end
	end)
end

return WorldEventService
