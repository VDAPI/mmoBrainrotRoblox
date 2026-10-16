--!strict
-- Auto Hunt rules (S134d, the third explicit exception of DESIGN-17 §0.2), pure:
--   * the time bank (account.autoGrind = { bank, day, used }): seconds bought or from the Scroll of the Hunt, spent only
--     while hunting, at most Config.AutoGrind.dailySeconds per UTC day (Logic/Time.dayNumber);
--   * which monsters it fights (ordinary ones of its hunting ground, within levelGap, nobody else's), the target (the
--     one hitting the player first, then the nearest within seekRadius) and the round over every group of the ground;
--   * one order of the stops (`stopReason`) and their texts;
--   * the reward: EXP and gold x Data/Progression.autoGrindExpPct / autoGrindGoldPct with the EXP source "autoGrind"
--     (not in Data/Leaderboards.WEEK_SOURCES: the weekly ranking never counts it).
-- AutoGrindService gathers the facts and asks these functions; the client only walks where the server says.

local Areas = require("../Data/Areas")
local Config = require("../Config")
local Maps = require("../Data/Maps")
local Progression = require("../Data/Progression")
local Time = require("./Time")
local UseBlocks = require("./UseBlocks")

local AutoGrind = {}

-- The EXP source of a kill while hunting (LevelService.GiveExp).
AutoGrind.SOURCE = "autoGrind"

export type State = { bank: number, day: number, used: number }

-- One monster near the player, as AutoGrindService sees it (tests pass plain tables).
export type Candidate = {
	ref: any,
	variant: string, -- "normal" | "elite" | "elite2" | "boss"
	boss: boolean,
	summoned: boolean,
	fromSpawner: boolean,
	area: string?, -- the named area of its spawner (AreaId)
	targetable: boolean,
	level: number,
	distance: number,
	fightsOther: boolean, -- has threat on a player who is neither the hunter nor in the hunter's party
	attacksMe: boolean, -- fighting the hunter right now
}

-- One spawner group of the hunting ground (map-relative or world x / z, the same frame as the position).
export type Group = { id: string, area: string?, x: number, y: number?, z: number, ready: boolean }
export type Point = { x: number, z: number }

-- What the server knows at one tick (stopReason).
export type Snapshot = {
	blocked: string?, -- the first active reason of UseBlocks.LISTS.autoGrind
	dead: boolean,
	left: number, -- AutoGrind.left (bank and day)
	todayLeft: number,
	outside: boolean, -- off the hunting ground (plus the margin) or on another map
	bossNear: boolean,
	hpPct: number,
	autoPotionHp: boolean, -- Auto Potions active with an HP threshold
	hasHpPotion: boolean, -- the potion of the HP bar slot is in the backpack
	autoLoot: boolean,
	freeSlots: number,
	sinceKill: number, -- seconds without a kill
	manual: boolean,
}

export type StopReason =
	"blocked"
	| "dead"
	| "noTime"
	| "daily"
	| "left"
	| "bossNear"
	| "lowHp"
	| "noPotions"
	| "bagFull"
	| "stuck"
	| "manual"

-- Every stop in the order stopReason checks them ("blocked" carries the block's reason).
local STOPS: { StopReason } = {
	"blocked",
	"dead",
	"noTime",
	"daily",
	"left",
	"bossNear",
	"lowHp",
	"noPotions",
	"bagFull",
	"stuck",
	"manual",
}
AutoGrind.STOPS = table.freeze(STOPS)

local function stateOf(state: State?): State
	if type(state) ~= "table" then
		return { bank = 0, day = 0, used = 0 }
	end
	return { bank = math.max(0, state.bank or 0), day = state.day or 0, used = math.max(0, state.used or 0) }
end

-- The state on the UTC day of `now` (a new day forgets the seconds used): a new table.
function AutoGrind.rollDay(state: State?, now: number): State
	local s = stateOf(state)
	local today = Time.dayNumber(now)
	if s.day ~= today then
		return { bank = s.bank, day = today, used = 0 }
	end
	return s
end

-- Seconds of hunting the daily cap still allows today.
function AutoGrind.todayLeft(state: State?, now: number): number
	return math.max(0, Config.AutoGrind.dailySeconds - AutoGrind.rollDay(state, now).used)
end

-- Seconds of hunting possible now: the bank, cut by the daily cap.
function AutoGrind.left(state: State?, now: number): number
	return math.min(AutoGrind.rollDay(state, now).bank, AutoGrind.todayLeft(state, now))
end

function AutoGrind.canStart(state: State?, now: number): (boolean, string?)
	if AutoGrind.rollDay(state, now).bank <= 0 then
		return false, "autoGrind.error.none"
	end
	if AutoGrind.todayLeft(state, now) <= 0 then
		return false, "autoGrind.error.daily"
	end
	return true, nil
end

-- The state after `dt` seconds of hunting (a new table): out of the bank, into today's used, never past either.
function AutoGrind.spend(state: State?, dt: number, now: number): State
	local s = AutoGrind.rollDay(state, now)
	local d = math.clamp(dt, 0, AutoGrind.left(s, now))
	return { bank = s.bank - d, day = s.day, used = s.used + d }
end

-- The state after `seconds` more in the bank (a purchase or a Scroll of the Hunt): a new table.
function AutoGrind.add(state: State?, seconds: number): State
	local s = stateOf(state)
	return { bank = s.bank + math.max(0, seconds), day = s.day, used = s.used }
end

-- Whether Auto Hunt may fight this monster: an ordinary monster of a spawner of the hunting ground `areaId` (never an
-- Elite, Elite II, boss, boss helper or world event monster), one the player may target, within levelGap levels,
-- fighting nobody outside the hunter's party (no stolen kills).
function AutoGrind.eligible(c: Candidate, playerLevel: number, areaId: string): boolean
	return c.variant == "normal"
		and not c.boss
		and not c.summoned
		and c.fromSpawner
		and c.area == areaId
		and c.targetable
		and not c.fightsOther
		and math.abs(c.level - playerLevel) <= Config.AutoGrind.levelGap
end

-- The target: an eligible monster hitting the player (nearest), else the nearest eligible one within seekRadius.
function AutoGrind.pickTarget(candidates: { Candidate }, playerLevel: number, areaId: string): Candidate?
	local best: Candidate? = nil
	for _, c in candidates do
		if not AutoGrind.eligible(c, playerLevel, areaId) then
			continue
		end
		if not c.attacksMe and c.distance > Config.AutoGrind.seekRadius then
			continue
		end
		if best == nil then
			best = c
		else
			local b = best :: Candidate
			if c.attacksMe ~= b.attacksMe then
				if c.attacksMe then
					best = c
				end
			elseif c.distance < b.distance then
				best = c
			end
		end
	end
	return best
end

local function distance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- The next group to walk to on the round of the whole hunting ground: the nearest ready group of `areaId` not visited
-- yet (a group waiting for its respawn is skipped); after the last one the round starts again (`visited` is cleared in
-- place). nil when no group of the ground is ready.
function AutoGrind.nextGoal(groups: { Group }, visited: { [string]: boolean }, position: Point, areaId: string): Group?
	local function nearest(): Group?
		local best: Group? = nil
		local bestDistance = math.huge
		for _, g in groups do
			if g.area == areaId and g.ready and not visited[g.id] then
				local d = distance(g, position)
				if d < bestDistance then
					best = g
					bestDistance = d
				end
			end
		end
		return best
	end
	local found = nearest()
	if found == nil and next(visited) ~= nil then
		table.clear(visited)
		found = nearest()
	end
	return found
end

-- Whether the hunter reached a group's centre (the group counts as visited).
function AutoGrind.arrived(goal: Point, position: Point): boolean
	return distance(goal, position) <= Config.AutoGrind.arrive
end

-- The hunting ground at a world point of map `mapId`: a named area of a region map (Data/Areas, its rect), or a whole
-- cave (the cave is one ground: its spawners carry the cave id as area). Returns (area id, map-relative rect, name
-- key) or nil off every ground (roads, the city, dungeons).
function AutoGrind.groundAt(mapId: string, x: number, z: number): (string?, { number }?, string?)
	local map = Maps.get(mapId)
	if not map then
		return nil, nil, nil
	end
	local rx, rz = x - map.offset.x, z - map.offset.z
	local area = Areas.areaAt(mapId, rx, rz)
	if area then
		return area.id, area.rect, area.nameKey
	end
	local cave = Areas.caves.get(mapId)
	if cave then
		local hx, hz = map.size.x / 2, map.size.z / 2
		return cave.id, { -hx, -hz, hx, hz }, cave.nameKey
	end
	return nil, nil, nil
end

-- Whether a map-relative point lies on the hunting ground's rectangle { x1, z1, x2, z2 } widened by `margin`.
function AutoGrind.inside(rect: { number }, x: number, z: number, margin: number): boolean
	return x >= rect[1] - margin and x <= rect[3] + margin and z >= rect[2] - margin and z <= rect[4] + margin
end

-- The first stop that applies (STOPS order) and, for "blocked", the block's reason; nil = keep hunting.
function AutoGrind.stopReason(s: Snapshot): (StopReason?, string?)
	local c = Config.AutoGrind
	if s.blocked then
		return "blocked", s.blocked
	elseif s.dead then
		return "dead", nil
	elseif s.left <= 0 and s.todayLeft > 0 then
		return "noTime", nil
	elseif s.todayLeft <= 0 then
		return "daily", nil
	elseif s.outside then
		return "left", nil
	elseif s.bossNear then
		return "bossNear", nil
	elseif not s.autoPotionHp and s.hpPct < c.stopHpPct then
		return "lowHp", nil
	elseif s.autoPotionHp and not s.hasHpPotion then
		return "noPotions", nil
	elseif s.autoLoot and s.freeSlots < c.minFreeSlots then
		return "bagFull", nil
	elseif s.sinceKill >= c.stuckSeconds then
		return "stuck", nil
	elseif s.manual then
		return "manual", nil
	end
	return nil, nil
end

-- The Locale key of a stop: autoGrind.block.<reason> for a block, autoGrind.stop.<stop> otherwise.
function AutoGrind.stopKey(stop: StopReason, blockReason: string?): string
	if stop == "blocked" and blockReason then
		return UseBlocks.key("autoGrind", blockReason)
	end
	return `autoGrind.stop.{stop}`
end

-- Arguments of the texts that describe Auto Hunt (shop, tooltip, wiki): hours a day, EXP and gold %, scroll minutes.
function AutoGrind.descArgs(): { hours: number, exp: number, gold: number, scroll: number }
	return {
		hours = Config.AutoGrind.dailySeconds / 3600,
		exp = Progression.autoGrindExpPct,
		gold = Progression.autoGrindGoldPct,
		scroll = Config.AutoGrind.scrollSeconds // 60,
	}
end

-- EXP and gold of one kill while hunting (after the party pool, the level difference and the quest budget) and the
-- EXP source.
function AutoGrind.reward(exp: number, gold: number): (number, number, string)
	return math.floor(exp * Progression.autoGrindExpPct / 100 + 0.5),
		math.floor(gold * Progression.autoGrindGoldPct / 100 + 0.5),
		AutoGrind.SOURCE
end

return AutoGrind
