--!strict
-- Blood Moon rules (S129, DESIGN-17 §7), pure: regions and the red-zone overlay, points, the ranking sort key, reward
-- tiers, the Elite roll of a respawning group and the pay2win blocks. BloodMoonService, ZoneService, DeathService and
-- the client call these; the numbers live in Data/ScheduledEvents.bloodMoon.

local Maps = require("../Data/Maps")
local Rng = require("./Rng")
local Schedule = require("./Schedule")
local ScheduledEvents = require("../Data/ScheduledEvents")
local Time = require("./Time")
local Types = require("../Types")

export type State = Types.BloodMoonState
export type KillCtx = { killerLevel: number, victimLevel: number, prior: number }
export type Tier = { participation: boolean, title: boolean, frame: boolean, winner: boolean }
export type Rewards = {
	tokens: number,
	blessing: boolean,
	titleId: string?,
	titleDays: number?,
	frameId: string?,
	shards: number,
}
-- the client's view of the event from the ReplicatedStorage attributes (Hud/BloodMoonPanel, menu entry)
export type Phase = "soon" | "active" | "ended"

local Rules = ScheduledEvents.bloodMoon
local Reward = Rules.reward

local SORT_BASE = 10000 -- points x SORT_BASE + the time part (an occurrence lasts < SORT_BASE seconds)
local SOON = 600 -- the panel and the menu entry show this long before the start (= the first warning)

local BloodMoon = {}

BloodMoon.SOON = SOON

local REGION: { [string]: boolean } = {}
for _, id in Rules.regions do
	REGION[id] = true
end

-- Open regions only: the red zone, the red sky and the Elites (S129).
function BloodMoon.isEventMap(mapId: string): boolean
	return REGION[mapId] == true
end

-- The ranking region of a map: an open region itself, a cave or crypt of a region (boss caves by dungeonRegion,
-- the small caves by their link back to the region); boss dungeons, the city and the rest: nil. Points count in a
-- region and its caves (DECYZJE S129).
function BloodMoon.regionOf(mapId: string): string?
	if REGION[mapId] then
		return mapId
	end
	local map = Maps.get(mapId)
	if not map or (map.biome ~= "cave" and map.biome ~= "crypt") then
		return nil
	end
	local owner = map.dungeonRegion
	if owner and REGION[owner] then
		return owner
	end
	for _, link in map.links do
		if REGION[link] then
			return link
		end
	end
	return nil
end

-- The zone of a map during the event: yellow on an open region turns red; green and red stay.
function BloodMoon.forcedZone(mapId: string, zone: Types.PvpZone, active: boolean): Types.PvpZone
	if active and REGION[mapId] and zone == "yellow" then
		return "red"
	end
	return zone
end

-- Points for defeating a player: 0 when the victim is levelGap or more levels below the killer, or after
-- sameVictimMax kills of the same victim; a higher-level victim always counts. Nothing from the account comes in.
function BloodMoon.playerPoints(ctx: KillCtx): number
	if ctx.victimLevel <= ctx.killerLevel - Rules.levelGap then
		return 0
	end
	if ctx.prior >= Rules.sameVictimMax then
		return 0
	end
	return Rules.points.player
end

-- Why a player kill gave nothing (the toast key), nil when it gave points.
function BloodMoon.noPointsKey(ctx: KillCtx): string?
	if ctx.victimLevel <= ctx.killerLevel - Rules.levelGap then
		return "bloodmoon.noPoints.level"
	end
	if ctx.prior >= Rules.sameVictimMax then
		return "bloodmoon.noPoints.repeat"
	end
	return nil
end

-- Points for a monster by its variant: Elite and Elite II only.
function BloodMoon.monsterPoints(variant: string): number
	if variant == "elite" then
		return Rules.points.elite
	elseif variant == "elite2" then
		return Rules.points.elite2
	end
	return 0
end

-- The ranking sort key: more points first, on a tie the one who reached them earlier.
function BloodMoon.sortKey(points: number, reachedAt: number, startsAt: number): number
	local elapsed = math.clamp(math.floor(reachedAt - startsAt), 0, SORT_BASE - 1)
	return math.max(0, math.floor(points)) * SORT_BASE + (SORT_BASE - 1 - elapsed)
end

function BloodMoon.pointsOf(sortKey: number): number
	return math.floor(sortKey) // SORT_BASE
end

-- Reward thresholds; every higher tier needs participation (minPoints).
function BloodMoon.tierOf(points: number, bestRank: number?): Tier
	local participation = points >= Reward.minPoints
	local ranked = participation and bestRank ~= nil
	return {
		participation = participation,
		title = ranked and (bestRank :: number) <= Reward.titleTop,
		frame = ranked and (bestRank :: number) <= Reward.frameTop,
		winner = ranked and (bestRank :: number) <= Reward.shardsTop,
	}
end

-- 0 none, 1 participation, 2 title, 3 frame, 4 winner (analytics).
function BloodMoon.tierIndex(tier: Tier): number
	if tier.winner then
		return 4
	elseif tier.frame then
		return 3
	elseif tier.title then
		return 2
	elseif tier.participation then
		return 1
	end
	return 0
end

function BloodMoon.rewardsOf(tier: Tier): Rewards
	if not tier.participation then
		return { tokens = 0, blessing = false, shards = 0 }
	end
	return {
		tokens = Reward.tokens,
		blessing = true,
		titleId = if tier.title then Reward.titleId else nil,
		titleDays = if tier.title then Reward.titleDays else nil,
		frameId = if tier.frame then Reward.frameId else nil,
		shards = if tier.winner then Reward.shards else 0,
	}
end

-- The item id of the participation blessing of `line` (Data/Blessings.lines).
function BloodMoon.blessingItem(line: string): string
	return `blessing_{line}_{Reward.blessingRarity}`
end

-- One roll per respawn of a normal group in an open region.
function BloodMoon.rollElite(rng: Rng.Rng): boolean
	return rng:chance(Rules.eliteChance)
end

-- Paid (shards, Robux) and free VIP instant respawns and the pass shortcut are off for a death in a region or its
-- caves during the event.
function BloodMoon.paidRespawnBlocked(active: boolean, mapId: string): boolean
	return active and BloodMoon.regionOf(mapId) ~= nil
end

-- The Elixir of Wholeness and the Cloak of Luring are off on the whole server during the event (DESIGN-17 §3).
function BloodMoon.consumableBlocked(active: boolean): boolean
	return active
end

function BloodMoon.newState(id: string): State
	return { id = id, points = 0, kills = {}, regions = {}, at = 0, paid = false }
end

-- A copy of `state` with `n` points more in `region` (at = the time of the last point).
function BloodMoon.addPoints(state: State, region: string, n: number, at: number): State
	local regions = table.clone(state.regions)
	local out = table.clone(state)
	out.regions = regions
	out.kills = table.clone(state.kills)
	if n > 0 then
		out.points += n
		regions[region] = (regions[region] or 0) + n
		out.at = at
	end
	return out
end

-- A copy of `state` with one more kill of `victimKey` (also kills worth 0 points count toward sameVictimMax).
function BloodMoon.countKill(state: State, victimKey: string): State
	local out = table.clone(state)
	out.kills = table.clone(state.kills)
	out.regions = table.clone(state.regions)
	out.kills[victimKey] = (out.kills[victimKey] or 0) + 1
	return out
end

-- The best rank of an entry key among the regions it has points in; `ranks[region][key]` = rank (1 = first).
function BloodMoon.bestRank(state: State, key: string, ranks: { [string]: { [string]: number } }?): number?
	if ranks == nil then
		return nil
	end
	local best: number? = nil
	for region, points in state.regions do
		local rank = if points > 0 and ranks[region] then ranks[region][key] else nil
		if rank and (best == nil or rank < best) then
			best = rank
		end
	end
	return best
end

-- The id of an occurrence forced by an admin (/bloodmoon start): "t" + the UTC date + the minute of the day, so its
-- boards never mix with a scheduled one.
function BloodMoon.forcedId(now: number): string
	local minute = math.floor((now % 86400) / 60)
	return `t{Schedule.dateKey(now)}{string.format("%04d", minute)}`
end

-- Whether an occurrence id comes from /bloodmoon start (the admin who forced it is not left out of the boards).
function BloodMoon.isForcedId(id: string): boolean
	return string.sub(id, 1, 1) == "t"
end

-- (startsAt, endsAt) of an occurrence from its id alone (a character settled long after the event, on any server):
-- a scheduled id is the date of a slot of Data/ScheduledEvents, a forced one ("t" + date + minute of the day) is
-- taken as one of the usual length. nil for a malformed id.
function BloodMoon.spanOf(id: string): (number?, number?)
	local forced = BloodMoon.isForcedId(id)
	local digits = if forced then string.sub(id, 2) else id
	local year, month, day = string.match(digits, "^(%d%d%d%d)(%d%d)(%d%d)")
	if not year then
		return nil, nil
	end
	local def = ScheduledEvents.get("bloodmoon")
	local duration = if def then def.duration else 0
	local dayStart = Time.fromCivil(tonumber(year) :: number, tonumber(month) :: number, tonumber(day) :: number)
		* 86400
	if forced then
		local minute = tonumber(string.sub(digits, 9, 12)) or 0
		local startsAt = dayStart + minute * 60
		return startsAt, startsAt + duration
	end
	local weekday = Schedule.weekday(dayStart)
	if def then
		for _, slot in def.slots do
			if slot.weekday == weekday then
				local startsAt = dayStart + slot.hour * 3600 + slot.minute * 60
				return startsAt, startsAt + duration
			end
		end
	end
	return dayStart, dayStart + duration
end

-- The region board name suffix ("BloodMoon_<id>_<region>"; Leaderboard/Stores adds its prefix).
function BloodMoon.boardId(id: string, region: string): string
	return `BloodMoon_{id}_{region}`
end

-- What the client shows from the attributes BloodMoon (id or ""), BloodMoonEndsAt and BloodMoonNext: "soon" in the
-- SOON seconds before the next start, "active" while one runs, "ended" while the results are still published
-- (`hasBoard`), else nil.
function BloodMoon.phaseOf(now: number, id: string?, endsAt: number?, nextAt: number?, hasBoard: boolean): Phase?
	if type(id) == "string" and id ~= "" and type(endsAt) == "number" and now < endsAt then
		return "active"
	end
	if type(nextAt) == "number" and nextAt > now and nextAt - now <= SOON then
		return "soon"
	end
	if hasBoard then
		return "ended"
	end
	return nil
end

-- The UTC weekday (1..7) and "HH:MM" of a start (the window's "Next: Tuesday 19:00 UTC").
function BloodMoon.when(startsAt: number): (number, string)
	local seconds = math.floor(startsAt) % 86400
	return Schedule.weekday(startsAt), string.format("%02d:%02d", seconds // 3600, (seconds % 3600) // 60)
end

return BloodMoon
