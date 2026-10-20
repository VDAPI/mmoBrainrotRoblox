--!strict
-- The world boss (S149, DESIGN §15.6): pure rules WorldBossService (and S149b's HUD, map and wiki) run. Every server
-- computes the same occurrences from the UTC clock (Util/Clock.now passed in, never os.time): S149c a start at each
-- local `times` of the day in the `tz` zone (Europe/Warsaw with the EU summer time), id "wbYYYYMMDDHH" of the UTC
-- start (the same on every server, the key of the one reward per account), warnings `warn` s before, the boss leaves `timeLimit` s after the start, the marker
-- lingers `linger` s. An occurrence whose fight window meets a wall-clock event that blocks world events (the Blood
-- Moon with its quiet time, Logic/Schedule.blocking) is skipped. The reward: Logic/Contribution with
-- Data/WorldBoss.share, level >= the boss's minLevel, once per account and occurrence (account.worldBoss.last).

local Bosses = require("../Data/Bosses")
local Contribution = require("./Contribution")
local Data = require("../Data/WorldBoss")
local Exp = require("./Exp")
local ItemRoll = require("./ItemRoll")
local Loot = require("./Loot")
local LootTables = require("../Data/LootTables")
local MonsterStats = require("./MonsterStats")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Schedule = require("./Schedule")
local ScheduledEvents = require("../Data/ScheduledEvents")
local Time = require("./Time")

local DAY = 86400
local FORCED = "wbforce"

export type Spot = Data.Spot
export type Occurrence = { id: string, startsAt: number, endsAt: number }
export type Phase = "warn" | "active" | "gone"
export type Reason = string -- "level" | "share" | "claimed"
export type Reward = { exp: number, gold: number }
export type Material = { id: string, n: number }

-- The live part of the state branch (WorldBossService): "slain" / "left" after the end while the marker lingers.
export type Live = {
	phase: "warn" | "active" | "slain" | "left",
	hp: number, -- 0..1
	bossPhase: number,
	channel: { id: string, endsAt: number, need: number, done: number }?,
}
export type Mine = { points: number, pct: number, ok: boolean, reason: Reason? }
-- What every client sees in the state branch `worldBoss` during an occurrence (times in Util/Clock seconds, x / z
-- map-relative); `mine` is the player's own contribution (WorldBossService adds it per player).
export type Public = {
	id: string,
	boss: string,
	nameKey: string,
	map: string,
	x: number,
	z: number,
	r: number,
	phase: "warn" | "active" | "slain" | "left",
	startsAt: number,
	endsAt: number,
	hp: number,
	bossPhase: number,
	level: number,
	minLevel: number,
	channel: { id: string, endsAt: number, need: number, done: number }?,
	mine: Mine?,
}
-- The branch outside an occurrence: the next start ("next at 14:00").
export type Idle = { next: { id: string, startsAt: number } }

local WorldBoss = {}

WorldBoss.Data = Data

-- The world boss of Data/WorldBoss (Data/Bosses, world = true).
function WorldBoss.def(): Bosses.BossDef
	local def = Bosses.byId[Data.boss]
	assert(def and def.world == true, `WorldBoss: {Data.boss} is no world boss`)
	return def
end

-- The arena (the first spot; one today).
function WorldBoss.spot(): Spot
	return Data.spots[1]
end

-- The lowest level that gets the reward (the boss's minLevel).
function WorldBoss.minLevel(): number
	return WorldBoss.def().minLevel or WorldBoss.def().level
end

-- Schedule (B) ----------------------------------------------------------------------------------------------

local function occurrenceOf(startsAt: number): Occurrence
	local hour = math.floor((startsAt % DAY) / 3600)
	return {
		id = `wb{Schedule.dateKey(startsAt)}{string.format("%02d", hour)}`,
		startsAt = startsAt,
		endsAt = startsAt + WorldBoss.def().timeLimit,
	}
end

-- S149c: the last Sunday of `month` of `year` as a UTC day number (Logic/Time.fromCivil; ISO weekday 7 = Sunday).
local function lastSunday(year: number, month: number): number
	local day = Time.fromCivil(year, month, 31)
	while Schedule.weekday(day * DAY) ~= 7 do
		day -= 1
	end
	return day
end

-- S149c: the hours the schedule's zone is ahead of UTC at `t` (EU rule: summer time from the last Sunday of March
-- 01:00 UTC to the last Sunday of October 01:00 UTC).
function WorldBoss.utcOffset(t: number): number
	local tz = Data.schedule.tz
	local year = Time.civil(t)
	local from = lastSunday(year, 3) * DAY + 3600
	local to = lastSunday(year, 10) * DAY + 3600
	return if t >= from and t < to then tz.dst else tz.std
end

-- Every start on local day `day` (the zone's calendar day with the UTC day number `day`), ascending, in UTC seconds.
function WorldBoss.startsOn(day: number): { number }
	local out: { number } = {}
	for _, hm in Data.schedule.times do
		local naive = day * DAY + hm[1] * 3600 + hm[2] * 60
		-- the offset near that instant (no start falls near the 01:00 UTC switch)
		local start = naive - WorldBoss.utcOffset(naive - Data.schedule.tz.std * 3600) * 3600
		table.insert(out, start)
	end
	return out
end

-- S149c: the local start times as text ("10:00, 22:00"), the map card and the wiki.
function WorldBoss.timesText(): string
	local parts: { string } = {}
	for _, hm in Data.schedule.times do
		table.insert(parts, string.format("%02d:%02d", hm[1], hm[2]))
	end
	return table.concat(parts, ", ")
end

-- The name key of the wall-clock event that blocks `occ` (its fight window meets the quiet window of an event with
-- blocksWorldEvents, Logic/Schedule.blocking), or nil.
function WorldBoss.blocked(occ: Occurrence): string?
	local hit = Schedule.blocking(ScheduledEvents.list, occ.startsAt, occ.endsAt)
	if not hit then
		return nil
	end
	local def = ScheduledEvents.get(hit.key)
	return if def then def.nameKey else hit.key
end

-- Every occurrence starting in [from, to), blocked ones left out, ascending (/sched, tests).
function WorldBoss.list(from: number, to: number): { Occurrence }
	local out: { Occurrence } = {}
	for day = Time.dayNumber(from) - 1, Time.dayNumber(to) + 1 do
		for _, start in WorldBoss.startsOn(day) do
			if start >= from and start < to then
				local occ = occurrenceOf(start)
				if not WorldBoss.blocked(occ) then
					table.insert(out, occ)
				end
			end
		end
	end
	return out
end

-- The occurrence `t` belongs to: from the first warning (startsAt - warn[1]) to the end of the marker (endsAt +
-- linger); nil between them.
function WorldBoss.occurrenceAt(t: number): Occurrence?
	local s = Data.schedule
	local before = s.warn[1] or 0
	local after = WorldBoss.def().timeLimit + s.linger
	for _, occ in WorldBoss.list(t - after - 1, t + before + 1) do
		if t >= occ.startsAt - before and t <= occ.endsAt + s.linger then
			return occ
		end
	end
	return nil
end

-- The nearest start after `t` (the HUD's "next at 14:00").
function WorldBoss.next(t: number): { id: string, startsAt: number }
	local from = t
	while true do
		local list = WorldBoss.list(from, from + DAY)
		for _, occ in list do
			if occ.startsAt > t then
				return { id = occ.id, startsAt = occ.startsAt }
			end
		end
		from += DAY
	end
end

-- The phase of `occ` at `now`: before the start "warn", until the end "active", then "gone".
function WorldBoss.phase(occ: Occurrence, now: number): Phase
	if now < occ.startsAt then
		return "warn"
	elseif now < occ.endsAt then
		return "active"
	end
	return "gone"
end

-- An admin occurrence (/worldboss start): id "wbforce<n>", starting at `startsAt`; never counts as a real one.
function WorldBoss.forced(n: number, startsAt: number): Occurrence
	return { id = `{FORCED}{n}`, startsAt = startsAt, endsAt = startsAt + WorldBoss.def().timeLimit }
end

function WorldBoss.isForced(id: string): boolean
	return string.sub(id, 1, #FORCED) == FORCED
end

-- Contribution and reward (D) -------------------------------------------------------------------------------

-- The HP equivalent of the threshold: share.hpEquivalent normal monsters of the boss level.
function WorldBoss.hpEquivalent(): number
	return Data.share.hpEquivalent * MonsterStats.baseHp(WorldBoss.def().level)
end

function WorldBoss.points(c: Contribution.Contribution): number
	return Contribution.points(c, Data.share)
end

-- Whether the character gets the reward of occurrence `occId`: level >= minLevel ("level"), the account not rewarded
-- for this occurrence yet ("claimed"; an admin occurrence never claims nor is claimed) and enough points ("share").
function WorldBoss.canReward(
	account: { worldBoss: { last: string }? }?,
	charLevel: number,
	points: number,
	total: number,
	occId: string
): (boolean, Reason?)
	if charLevel < WorldBoss.minLevel() then
		return false, "level"
	end
	local last = if account and account.worldBoss then account.worldBoss.last else ""
	if not WorldBoss.isForced(occId) and last == occId then
		return false, "claimed"
	end
	if not Contribution.eligible(points, total, WorldBoss.hpEquivalent(), Data.share) then
		return false, "share"
	end
	return true, nil
end

-- EXP and gold of a character (from its own level, like S101); the boss left (`success` false): failMul of both.
function WorldBoss.reward(charLevel: number, success: boolean?): Reward
	local r = Data.reward
	local mul = if success == false then r.failMul else 1
	local level = math.clamp(math.floor(charLevel), 1, 100)
	local exp = r.expKills * Exp.monsterExp(level, "normal") * mul
	local gold = r.goldKills * MonsterStats.gold(level, "normal", 0.5) * mul
	return { exp = math.floor(exp + 0.5), gold = math.floor(gold + 0.5) }
end

-- The item level of the reward: a drop level of the character's level clamped to [minLevel, boss level].
function WorldBoss.itemLevel(charLevel: number, rng: Rng.Rng): number
	return ItemRoll.dropLevel(math.clamp(charLevel, WorldBoss.minLevel(), WorldBoss.def().level), rng)
end

-- S149c: the contribution factor of a winner: s = points / (total / fighters), f = clamp(lo + slope x s, lo, hi)
-- (reward.factor: 0.5 .. 2, 1 for an even share). `fighters` = the participants with points; nothing counted = 1.
function WorldBoss.factor(points: number, total: number, fighters: number): number
	local k = Data.reward.factor
	if total <= 0 or fighters <= 0 then
		return 1
	end
	local s = math.max(0, points) / (total / fighters)
	return math.clamp(k.lo + k.slope * s, k.lo, k.hi)
end

-- S149c: the item's rarity weights for factor `f`: the Legendary and Mythic weights times f.
function WorldBoss.rarityWeights(f: number?): { [number]: number }
	local mul = f or 1
	local out: { [number]: number } = {}
	for rarity, w in Data.reward.rarity :: { [number]: number } do
		out[rarity] = if rarity >= Rarities.LEGENDARY then w * mul else w
	end
	return out
end

-- S149c: the chance of a named item for factor `f` after `dry` rewarded fights without one: chance x f + step x dry,
-- certain from pityAt dry fights on.
function WorldBoss.namedChance(f: number, dry: number): number
	local n = Data.reward.named
	if dry >= n.pityAt then
		return 1
	end
	return math.clamp(n.chance * f + n.step * math.max(0, dry), 0, 1)
end

-- S149c: the named items a class may get (reward.named.byClass; {} for an unknown class).
function WorldBoss.namedOf(classId: string?): { string }
	return (classId and Data.reward.named.byClass[classId]) or {}
end

-- S149c: the named item roll: (item id or nil, the new dry count). Uses the rng twice at most.
function WorldBoss.rollNamed(classId: string?, f: number, dry: number, rng: Rng.Rng): (string?, number)
	local list = WorldBoss.namedOf(classId)
	if #list == 0 then
		return nil, dry
	end
	if rng:next() < WorldBoss.namedChance(f, dry) then
		return rng:pick(list), 0
	end
	return nil, dry + 1
end

-- The one item: the drop level, then the rarity (reward.rarity, S149c: Legendary and Mythic times the factor `f`),
-- then the base (a boss slot: Loot.pickItem with classBias; a Mythic always one the class can wear, Loot.pickUsable,
-- as at the dungeon bosses). nil when no item exists for the level.
function WorldBoss.rollItem(charLevel: number, classId: string?, rng: Rng.Rng, f: number?): Loot.ItemDrop?
	local r = Data.reward
	local ilvl = WorldBoss.itemLevel(charLevel, rng)
	local rarity = rng:weighted(WorldBoss.rarityWeights(f))
	local defId = if rarity == Rarities.MYTHIC
		then Loot.pickUsable(LootTables.bossSlots, ilvl, classId, rng)
		else Loot.pickItem(LootTables.bossSlots, ilvl, r.classBias, classId, rng)
	if not defId then
		return nil
	end
	return { defId = defId, ilvl = ilvl, rarity = rarity, forClass = classId }
end

-- The materials of the reward (reward.materials: chance, then min..max).
function WorldBoss.rollMaterials(rng: Rng.Rng): { Material }
	local out: { Material } = {}
	for _, drop in Data.reward.materials do
		if rng:chance(drop.chance) then
			table.insert(out, { id = drop.id, n = rng:int(drop.min, drop.max) })
		end
	end
	return out
end

-- Arena and client state (C) -------------------------------------------------------------------------------

local function flatDistance(spot: Spot, x: number, z: number): number
	return math.sqrt((x - spot.x) ^ 2 + (z - spot.z) ^ 2)
end

-- Whether a map-relative point is in the fighters' circle (r + fighterReach).
function WorldBoss.inArena(spot: Spot, x: number, z: number): boolean
	return flatDistance(spot, x, z) <= spot.r + Data.fighterReach
end

-- S156: whether a map-relative point is in the barrow's vestibule (Data/WorldBoss.antechamber, in front of the opening).
function WorldBoss.inAntechamber(spot: Spot, x: number, z: number): boolean
	local a = Data.antechamber
	local cz = spot.z - (spot.r + a.d)
	return math.sqrt((x - spot.x) ^ 2 + (z - cz) ^ 2) <= a.r
end

-- S149 (C5): whether PvP is off at a map-relative point: pvpSafe, the boss alive and the point in the circle. S156: the
-- vestibule always.
function WorldBoss.pvpSafe(spot: Spot, x: number, z: number, bossAlive: boolean): boolean
	if Data.pvpSafe ~= true then
		return false
	end
	return (bossAlive and WorldBoss.inArena(spot, x, z)) or WorldBoss.inAntechamber(spot, x, z)
end

-- The player's own line: points, share of all (0..1), whether the reward is due and why not.
function WorldBoss.mineOf(points: number, total: number, ok: boolean, reason: Reason?): Mine
	return {
		points = math.floor(points),
		pct = if total > 0 then math.floor(points / total * 1000 + 0.5) / 1000 else 0,
		ok = ok,
		reason = reason,
	}
end

-- The public branch of an occurrence (without `mine`).
function WorldBoss.publicOf(occ: Occurrence, live: Live): Public
	local def = WorldBoss.def()
	local spot = WorldBoss.spot()
	return {
		id = occ.id,
		boss = def.id,
		nameKey = def.nameKey,
		map = Data.map,
		x = spot.x,
		z = spot.z,
		r = spot.r,
		phase = live.phase,
		startsAt = occ.startsAt,
		endsAt = occ.endsAt,
		hp = math.clamp(math.floor(live.hp * 100 + 0.5) / 100, 0, 1),
		bossPhase = live.bossPhase,
		level = def.level,
		minLevel = WorldBoss.minLevel(),
		channel = live.channel,
		mine = nil,
	}
end

-- The branch outside an occurrence.
function WorldBoss.idleOf(now: number): Idle
	return { next = WorldBoss.next(now) }
end

-- The view (S149b): the map marker, the map card, the HUD panel and the safe-zone note, all from the branch the client
-- holds (`worldBoss`: a Public, an Idle or nil before the first send) -------------------------------------------------

export type MarkerState = "idle" | "warn" | "active" | "slain" | "left"
-- The marker of the world map and the minimap: always at the spot of the boss's map. `at` = Util/Clock seconds of the
-- next start (idle, warn) or of the leave (active); `hp` 0..1 while active.
export type Marker = {
	state: MarkerState,
	map: string,
	x: number,
	z: number,
	r: number,
	at: number?,
	hp: number?,
}

local PHASES: { [string]: MarkerState } = { warn = "warn", active = "active", slain = "slain", left = "left" }

local function isPublic(branch: any): boolean
	return type(branch) == "table" and type(branch.phase) == "string" and PHASES[branch.phase] ~= nil
end

-- The marker of the branch at `now` (Clock seconds): the occurrence's phase, else "idle" with the next start (the
-- branch's `next`, else computed from `now` before the first send).
function WorldBoss.markerOf(branch: any, now: number): Marker
	local spot = WorldBoss.spot()
	local marker: Marker = { state = "idle", map = Data.map, x = spot.x, z = spot.z, r = spot.r, at = nil, hp = nil }
	if isPublic(branch) then
		marker.state = PHASES[branch.phase]
		if marker.state == "warn" then
			marker.at = tonumber(branch.startsAt)
		elseif marker.state == "active" then
			marker.at = tonumber(branch.endsAt)
			marker.hp = math.clamp(tonumber(branch.hp) or 1, 0, 1)
		end
		return marker
	end
	local nextStart = if type(branch) == "table" and type(branch.next) == "table"
		then tonumber(branch.next.startsAt)
		else nil
	marker.at = nextStart or WorldBoss.next(now).startsAt
	return marker
end

-- Whether the marker draws the boss (warning, fight, the linger after it) rather than the quiet barrow.
function WorldBoss.markerLive(marker: Marker): boolean
	return marker.state ~= "idle"
end

export type CardState = "sleeps" | "wakes" | "fights" | "slain" | "left"
export type CardAttack = { id: string, nameKey: string, kind: string } -- kind "avoid" | <mechanic>
-- The map card (WorldMap/CreatureCards.worldBoss): the boss, the place, the state with its time, who it is for, the
-- blows worth knowing and the loot (no percentages: the rarities of the one item and the material ids).
export type Card = {
	boss: string,
	nameKey: string,
	placeKey: string,
	map: string,
	x: number,
	z: number,
	level: number,
	minLevel: number,
	players: { number },
	state: CardState,
	at: number?, -- sleeps / wakes: the start; fights: the leave
	hp: number?, -- fights: 0..1
	belowLevel: boolean, -- the viewer is under minLevel
	claimed: boolean, -- the viewer's account has this occurrence's reward already
	attacks: { CardAttack },
	rarities: { number }, -- of the one item, ascending
	materials: { string },
}

local CARD_STATES: { [MarkerState]: CardState } =
	{ idle = "sleeps", warn = "wakes", active = "fights", slain = "slain", left = "left" }

function WorldBoss.cardOf(branch: any, viewer: { level: number, now: number }): Card
	local def = WorldBoss.def()
	local spot = WorldBoss.spot()
	local marker = WorldBoss.markerOf(branch, viewer.now)
	local attacks: { CardAttack } = {}
	for _, attack in def.attacks do
		local kind = if attack.mechanic then attack.mechanic elseif attack.avoid then "avoid" else nil
		if kind then
			table.insert(attacks, { id = attack.id, nameKey = `boss.{def.id}.attack.{attack.id}`, kind = kind })
		end
	end
	local rarities: { number } = {}
	for rarity, weight in Data.reward.rarity :: { [number]: number } do
		if weight > 0 then
			table.insert(rarities, rarity)
		end
	end
	table.sort(rarities)
	local materials: { string } = {}
	for _, drop in Data.reward.materials do
		table.insert(materials, drop.id)
	end
	local mine = if isPublic(branch) and type(branch.mine) == "table" then branch.mine else nil
	return {
		boss = def.id,
		nameKey = def.nameKey,
		placeKey = spot.nameKey,
		map = Data.map,
		x = spot.x,
		z = spot.z,
		level = def.level,
		minLevel = WorldBoss.minLevel(),
		players = { Data.players[1], Data.players[2] },
		state = CARD_STATES[marker.state],
		at = marker.at,
		hp = marker.hp,
		belowLevel = viewer.level < WorldBoss.minLevel(),
		claimed = mine ~= nil and mine.reason == "claimed",
		attacks = attacks,
		rarities = rarities,
		materials = materials,
	}
end

-- How the HUD panel shows the branch for a player on `mapId`: "full" on the boss's map from the warning to the end of
-- the marker, "line" (one line: the countdown, then "fights, mm:ss left", with the barrow's name; a tap opens the map at
-- it) on any other map from the first warning to the end of the fight (S149c: the fight too), nil otherwise.
function WorldBoss.panelOf(branch: any, mapId: string?): ("full" | "line")?
	if not isPublic(branch) then
		return nil
	end
	if mapId == branch.map then
		return "full"
	end
	return if branch.phase == "warn" or branch.phase == "active" then "line" else nil
end

-- S149c: the text key and the seconds of the compact HUD line: before the start the countdown, during the fight the
-- time left; nil after it.
function WorldBoss.lineOf(branch: any, now: number): (string?, number?)
	if not isPublic(branch) then
		return nil, nil
	end
	if branch.phase == "warn" then
		return "hud.worldboss.line", math.max(0, (tonumber(branch.startsAt) or now) - now)
	elseif branch.phase == "active" then
		return "hud.worldboss.lineActive", math.max(0, (tonumber(branch.endsAt) or now) - now)
	end
	return nil, nil
end

-- S149b (A4): the note of the zone banner at a map-relative point: "worldboss.safeZone" in the fighters' circle of a
-- living boss when PvP is off there (Data/WorldBoss.pvpSafe, S149 C5), else nil.
function WorldBoss.zoneNote(branch: any, mapId: string?, x: number, z: number): string?
	-- S156: the vestibule is safe at every hour
	if mapId == Data.map and WorldBoss.inAntechamber(WorldBoss.spot(), x, z) then
		return "worldboss.safeZone"
	end
	if not isPublic(branch) or branch.phase ~= "active" or mapId ~= Data.map then
		return nil
	end
	if not WorldBoss.pvpSafe(WorldBoss.spot(), x, z, true) then
		return nil
	end
	return "worldboss.safeZone"
end

return WorldBoss
