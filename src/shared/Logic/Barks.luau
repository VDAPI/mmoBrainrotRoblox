--!strict
-- NPC comments during quests (S101b, DESIGN-15 §3.5). Pure (Lune tests); BarkController runs them on the client from
-- the replicated state, so comments never touch play (no remote). Events: `accept` (the quest became active), `half`
-- (the summed progress reached half and the quest is not complete), `done` (every objective just filled), `near`
-- (close to where the objective points), `death` (the player died during the quest), `stuck` (long play without
-- progress outside town). A quest without `barks`, or without a variant of the event, says nothing. The line is
-- picked deterministically from a seed (quest.<id>.bark.<event><n>); a limiter keeps the pace (Config.Barks).

local Config = require("../Config")
local Npcs = require("../Data/Npcs")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")
local SideQuests = require("./SideQuests")

export type Kind = "main" | "side"
export type Event = { quest: string, kind: Kind, event: string }
export type Limiter = { last: number, byKey: { [string]: number }, recent: { number } }
export type Point = { map: string, x: number?, z: number? }

local Barks = {}

Barks.EVENTS = table.freeze({ "accept", "half", "near", "done", "death", "stuck" })
Barks.COMPANION_EVENTS = table.freeze({ "join", "wait", "arrive", "back" })
Barks.MAX_VARIANTS = 4
Barks.HALF = 0.5

local KNOWN: { [string]: boolean } = {}
for _, event in Barks.EVENTS do
	KNOWN[event] = true
end

-- The story or side quest record of an id.
function Barks.questOf(id: string): (any, Kind?)
	local main = Quests.Main.get(id)
	if main then
		return main, "main"
	end
	local side = Quests.npcQuest(id)
	if side then
		return side, "side"
	end
	return nil, nil
end

-- Variants of an event of a quest (0 = none).
function Barks.count(quest: any, event: string): number
	local set = if type(quest) == "table" then quest.barks else nil
	local n = if type(set) == "table" then set[event] else nil
	return if type(n) == "number" and n >= 1 then math.floor(n) else 0
end

-- Summed progress Σ min(p, n) / Σ n of a quest (0..1).
function Barks.share(progress: { number }?, objectives: { Quests.Objective }): number
	local have, need = 0, 0
	for i, objective in objectives do
		need += objective.n
		have += math.min((progress or {})[i] or 0, objective.n)
	end
	return if need > 0 then have / need else 0
end

-- Σ n of a quest's objectives.
function Barks.total(quest: any): number
	local sum = 0
	for _, objective in quest.objectives do
		sum += objective.n
	end
	return sum
end

type Snapshot = { kind: Kind, quest: any, share: number, complete: boolean }

-- Active quests with comments in a `character.quests` copy: id -> snapshot.
local function active(quests: any): { [string]: Snapshot }
	local out: { [string]: Snapshot } = {}
	if type(quests) ~= "table" then
		return out
	end
	local main = quests.main
	if type(main) == "table" and type(main.id) == "string" then
		local quest = Quests.Main.get(main.id)
		if quest and quest.barks then
			local progress = if type(main.progress) == "table" then main.progress else {}
			out[quest.id] = {
				kind = "main",
				quest = quest,
				share = Barks.share(progress, quest.objectives),
				complete = QuestLogic.isComplete(progress, quest.objectives),
			}
		end
	end
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.npcQuest(id)
		if quest and quest.barks and type(entry) == "table" then
			local progress = if type(entry.progress) == "table" then entry.progress else {}
			out[id] = {
				kind = "side",
				quest = quest,
				share = Barks.share(progress, quest.objectives),
				complete = QuestLogic.isComplete(progress, quest.objectives),
			}
		end
	end
	return out
end

-- Comment events between two snapshots of `character.quests` (story first, then side quests by id). A quest that
-- appears already complete gives `done` only; `half` and `done` in one change give `done` only; a quest that left
-- (handed in, abandoned) gives nothing.
function Barks.events(prev: any, next: any, _level: number?): { Event }
	local before = active(prev)
	local after = active(next)
	local ids: { string } = {}
	for id in after do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ka, kb = after[a].kind, after[b].kind
		if ka ~= kb then
			return ka == "main"
		end
		return a < b
	end)
	local out: { Event } = {}
	for _, id in ids do
		local now = after[id]
		local was = before[id]
		local event: string? = nil
		if not was then
			event = if now.complete then "done" else "accept"
		elseif now.complete and not was.complete then
			event = "done"
		elseif not now.complete and was.share < Barks.HALF and now.share >= Barks.HALF then
			event = "half"
		end
		if event and Barks.count(now.quest, event) > 0 then
			table.insert(out, { quest = id, kind = now.kind, event = event })
		end
	end
	return out
end

-- Whether the player stands within `radius` of where an objective points (same map, flat distance).
function Barks.nearHit(target: Point?, position: { x: number, z: number }, map: string?, radius: number): boolean
	if not target or target.map ~= map or not target.x or not target.z then
		return false
	end
	local dx, dz = position.x - target.x, position.z - target.z
	return dx * dx + dz * dz <= radius * radius
end

-- Long play without progress (never in town).
function Barks.isStuck(lastProgressAt: number, now: number, inTown: boolean): boolean
	return not inTown and now - lastProgressAt >= Config.Barks.stuckAfter
end

local function variant(seed: number, count: number): number
	local s = math.abs(math.floor(seed))
	return 1 + (s % count)
end

-- The locale key of a comment (quest.<id>.bark.<event><n>, n = 1 + seed % variants), nil without one.
function Barks.pick(quest: any, event: string, seed: number): string?
	local count = Barks.count(quest, event)
	if count == 0 then
		return nil
	end
	return `quest.{quest.id}.bark.{event}{variant(seed, count)}`
end

-- Variants of a companion line (0 = none).
function Barks.compCount(quest: any, event: string): number
	local def = if type(quest) == "table" then quest.companion else nil
	local lines = if type(def) == "table" then def.lines else nil
	local n = if type(lines) == "table" then lines[event] else nil
	return if type(n) == "number" and n >= 1 then math.floor(n) else 0
end

-- The locale key of a companion line (quest.<id>.comp.<event><n>), nil without one.
function Barks.pickComp(quest: any, event: string, seed: number): string?
	local count = Barks.compCount(quest, event)
	if count == 0 then
		return nil
	end
	return `quest.{quest.id}.comp.{event}{variant(seed, count)}`
end

-- Who says a comment: the fixed `by`, else the companion (when the client sees it near), else the turn-in NPC for
-- `done`, else the giver. Givers and turn-in NPCs are never "classVendor" (tests/quest.spec).
function Barks.speaker(quest: any, event: string, companionNpc: string?): string
	local set = quest.barks
	if type(set) == "table" and type(set.by) == "string" then
		return set.by
	end
	if companionNpc then
		return companionNpc
	end
	if event == "done" then
		return quest.turnIn
	end
	return quest.giver
end

function Barks.newLimiter(): Limiter
	return { last = -math.huge, byKey = {}, recent = {} }
end

-- Whether a comment may be said now (and records it when yes): `gap` between any two, `sameEvent` for the same quest
-- and event (`stuckRepeat` for stuck, `deathRepeat` for death), at most `perMinute` in the last 60 seconds.
function Barks.allow(limiter: Limiter, questId: string, event: string, now: number): boolean
	local c = Config.Barks
	if now - limiter.last < c.gap then
		return false
	end
	local key = `{questId}:{event}`
	local again = if event == "stuck" then c.stuckRepeat elseif event == "death" then c.deathRepeat else c.sameEvent
	local last = limiter.byKey[key]
	if last and now - last < again then
		return false
	end
	local recent: { number } = {}
	for _, t in limiter.recent do
		if now - t < 60 then
			table.insert(recent, t)
		end
	end
	limiter.recent = recent
	if #recent >= c.perMinute then
		return false
	end
	limiter.last = now
	limiter.byKey[key] = now
	table.insert(limiter.recent, now)
	return true
end

-- Events every quest with comments must have (the minimum of DESIGN-15 §3.5): accept and done always, half only when
-- the objectives sum to 2 or more (with n = 1 there is no half, the line would never be said).
function Barks.required(quest: any): { string }
	local out = { "accept", "done" }
	if Barks.total(quest) >= 2 then
		table.insert(out, 2, "half")
	end
	return out
end

-- Whether an objective of the quest (or its `where` hint) points at a place (for `near`).
local function hasPoint(quest: any): boolean
	if type(quest.where) == "table" then
		return true
	end
	for _, objective in quest.objectives do
		local t = objective.type
		if t == "reach" or t == "use" or t == "escort" or t == "talk" or t == "deliver" then
			return true
		end
		if (t == "kill" or t == "collect") and objective.area then
			return true
		end
	end
	return false
end

-- Problems of the comment data ("<questId>: <problem>"); empty = fine.
function Barks.validate(list: { any }?): { string }
	local problems: { string } = {}
	local quests: { any } = list or {}
	if not list then
		for _, quest in Quests.Main.list do
			table.insert(quests, quest)
		end
		for _, quest in Quests.npcList do
			table.insert(quests, quest)
		end
	end
	for _, quest in quests do
		local set = quest.barks
		if set == nil then
			continue
		end
		local function bad(text: string)
			table.insert(problems, `{quest.id}: {text}`)
		end
		if type(set) ~= "table" then
			bad("barks is not a table")
			continue
		end
		for key, value in set do
			if key == "by" then
				if type(value) ~= "string" or (not Npcs.get(value) and value ~= QuestLogic.CLASS_VENDOR) then
					bad(`unknown speaker {tostring(value)}`)
				end
			elseif not KNOWN[key] then
				bad(`unknown event {tostring(key)}`)
			elseif type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > Barks.MAX_VARIANTS then
				bad(`{key}: {tostring(value)} variants (1..{Barks.MAX_VARIANTS})`)
			end
		end
		if set.half ~= nil and Barks.total(quest) < 2 then
			bad("half with one objective unit (never said)")
		end
		if set.near ~= nil and not hasPoint(quest) then
			bad("near without an objective that points at a place")
		end
	end
	return problems
end

return Barks
