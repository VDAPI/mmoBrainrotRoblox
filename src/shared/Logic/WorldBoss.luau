--!strict
-- The world boss (S149, DESIGN §15.6): pure rules WorldBossService (and S149b's HUD, map and wiki) run. Every server
-- computes the same occurrences from the UTC clock (Util/Clock.now passed in, never os.time): a start every
-- `everyHours` h from `offsetHour`:`minute` of each UTC day, id "wbYYYYMMDDHH" (the same on every server, the key of
-- the one reward per account), warnings `warn` s before, the boss leaves `timeLimit` s after the start, the marker
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

-- Every start of UTC day `day` (Logic/Time.dayNumber), ascending.
function WorldBoss.startsOn(day: number): { number }
	local s = Data.schedule
	local out: { number } = {}
	local hour = s.offsetHour
	while hour < 24 do
		table.insert(out, day * DAY + hour * 3600 + s.minute * 60)
		hour += s.everyHours
	end
	return out
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
	for day = Time.dayNumber(from), Time.dayNumber(to) do
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

-- The one item: the drop level, then the rarity (reward.rarity), then the base (a boss slot: Loot.pickItem with
-- classBias; a Mythic always one the class can wear, Loot.pickUsable, as at the dungeon bosses). nil when no item
-- exists for the level.
function WorldBoss.rollItem(charLevel: number, classId: string?, rng: Rng.Rng): Loot.ItemDrop?
	local r = Data.reward
	local ilvl = WorldBoss.itemLevel(charLevel, rng)
	local rarity = rng:weighted(r.rarity :: { [number]: number })
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

-- S149 (C5): whether PvP is off at a map-relative point: pvpSafe, the boss alive and the point in the circle.
function WorldBoss.pvpSafe(spot: Spot, x: number, z: number, bossAlive: boolean): boolean
	return Data.pvpSafe == true and bossAlive and WorldBoss.inArena(spot, x, z)
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

return WorldBoss
