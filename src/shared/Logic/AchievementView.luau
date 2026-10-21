--!strict
-- S151b (docs/DESIGN.md §20b): the view model of the achievements window, the HUD tracker section and the achievement
-- card of the player profile. Pure (Lune tests): it reads a Logic/Achievements state and the data, never a rule of its
-- own: progress only through Achievements.progress / isDone, the reward through Achievements.reward.
--   summary(st, scope)        points, done / total and per category (scope "all" | "account" | "character");
--                             S151c: the points include the bestiary's (a character's), also apart in `bestiary`
--   rows(st, cat, filter, scope)  the window list: a series (`after`) folded to its current step, secret ones not
--                             done as "???", order: in progress (closest to the goal), not started, done (newest)
--   detail(st, id)            one step and its whole series (goals, points, rewards, dates)
--   rewardLines(def, st)      the reward as text keys ("Title: {name}", "Dragon Shards: {n}", already paid …)
--   trackedRows(st)           the HUD tracker section
--   recent(st, n)             the latest done achievements of the account and the character (profile)

local AchData = require("../Data/Achievements")
local Achievements = require("./Achievements")
local Bestiary = require("./Bestiary")
local Cosmetics = require("../Data/Cosmetics")
local Titles = require("../Data/Titles")

type AchDef = AchData.AchDef
type State = Achievements.State

export type Count = { points: number, pointsMax: number, done: number, total: number }
export type CatCount = { done: number, total: number }
export type Summary = {
	points: number,
	pointsMax: number,
	done: number,
	total: number,
	byCat: { [string]: CatCount },
	bestiary: { points: number, pointsMax: number }, -- S151c: inside points / pointsMax (not for "account")
}

-- kind: "title" | "cosmetic" | "shards" | "shardsPaid" | "gold"; `nameKey` of the title or cosmetic, `n` an amount.
export type RewardLine = { kind: string, key: string, id: string?, nameKey: string?, n: number? }

export type Step = { id: string, goal: number, points: number, done: boolean, doneAt: number?, reward: { RewardLine } }

export type Row = {
	id: string,
	cat: string,
	nameKey: string,
	descKey: string?, -- nil for a hidden (secret, not done) one
	args: { goal: number },
	value: number,
	goal: number,
	pct: number, -- 0..1
	done: boolean,
	doneAt: number?,
	scope: string, -- "account" | "character"
	points: number,
	reward: { RewardLine },
	tracked: boolean,
	hidden: boolean,
	next: string?, -- the next step of the series
	steps: { Step }, -- the whole series (empty for a single achievement)
}

export type Recent = { id: string, at: number }

local AchievementView = {}

AchievementView.SECRET_NAME = "ach.secret.name"
AchievementView.SCOPES = table.freeze({ "all", "account", "character" })
AchievementView.FILTERS = table.freeze({ "all", "open", "done" })

-- Series --------------------------------------------------------------------------------------------------------------

local order: { [string]: number } = {}
local children: { [string]: { AchDef } } = {}
for i, def in AchData.list do
	order[def.id] = i
	if def.after then
		local list = children[def.after]
		if not list then
			list = {}
			children[def.after] = list
		end
		table.insert(list, def)
	end
end

local chains: { [string]: { AchDef } } = {}

local function rootOf(def: AchDef): AchDef
	local current = def
	local guard = 0
	while current.after and AchData.get(current.after) and guard < 32 do
		current = AchData.get(current.after) :: AchDef
		guard += 1
	end
	return current
end

-- The steps of the series of `def` in order (the def alone when it has no series).
function AchievementView.chainOf(def: AchDef): { AchDef }
	local root = rootOf(def)
	local cached = chains[root.id]
	if cached then
		return cached
	end
	local chain: { AchDef } = {}
	local function walk(step: AchDef)
		if #chain > 32 then
			return
		end
		table.insert(chain, step)
		local kids: { AchDef } = children[step.id] or {}
		for _, child in kids do
			walk(child)
		end
	end
	walk(root)
	chains[root.id] = chain
	return chain
end

-- Rewards -------------------------------------------------------------------------------------------------------------

local function branchOf(st: State, def: AchDef): Achievements.Branch
	return if Achievements.scopeOf(def.counter) == "account" then st.acc else st.chr
end

-- The reward of `def` as text lines (the toast's keys: "Title: {name}", "Cosmetic: {name}", "Dragon Shards: {n}",
-- "Gold: {n}"). With a state: Dragon Shards already paid on this account read "already received on this account"
-- unless this branch received them (an account achievement done, a character achievement in the character's
-- `paidHere`: the same character achievement done by a second character got no shards).
function AchievementView.rewardLines(def: AchDef, st: State?): { RewardLine }
	local out: { RewardLine } = {}
	local r = def.reward
	if not r then
		return out
	end
	if r.title then
		local title = Titles.get(r.title)
		if title then
			table.insert(out, { kind = "title", key = "ach.toast.title", id = r.title, nameKey = title.nameKey })
		end
	end
	if r.cosmetic then
		local cosmetic = Cosmetics.get(r.cosmetic)
		if cosmetic then
			table.insert(
				out,
				{ kind = "cosmetic", key = "ach.toast.cosmetic", id = r.cosmetic, nameKey = cosmetic.nameKey }
			)
		end
	end
	local shards = math.floor(r.shards or 0)
	if shards > 0 then
		local paid = st ~= nil and (st.acc.paid or {})[def.id] == true
		local mine = false
		if st ~= nil then
			mine = if Achievements.scopeOf(def.counter) == "account"
				then st.acc.done[def.id] ~= nil
				else (st.chr.paidHere or {})[def.id] == true
		end
		if paid and not mine then
			table.insert(out, { kind = "shardsPaid", key = "ach.reward.shardsPaid" })
		else
			table.insert(out, { kind = "shards", key = "ach.toast.shards", n = shards })
		end
	end
	local gold = Achievements.reward(def, nil).gold
	if gold > 0 then
		table.insert(out, { kind = "gold", key = "ach.toast.gold", n = gold })
	end
	return out
end

-- Rows ----------------------------------------------------------------------------------------------------------------

local function isTracked(st: State, id: string): boolean
	local list = st.chr.track
	return list ~= nil and table.find(list, id) ~= nil
end

local function steps(st: State, chain: { AchDef }): { Step }
	local out: { Step } = {}
	if #chain < 2 then
		return out
	end
	for _, step in chain do
		local doneAt = branchOf(st, step).done[step.id]
		table.insert(out, {
			id = step.id,
			goal = Achievements.goalOf(step),
			points = step.points,
			done = doneAt ~= nil,
			doneAt = doneAt,
			reward = AchievementView.rewardLines(step, st),
		})
	end
	return out
end

-- The row of one step (`chain` its series, `index` its place there).
local function rowOf(st: State, chain: { AchDef }, index: number): Row
	local def = chain[index]
	local value, goal = Achievements.progress(st, def)
	local doneAt = branchOf(st, def).done[def.id]
	local done = doneAt ~= nil
	local hidden = def.secret == true and not done
	if hidden then
		value, goal = 0, 0
	end
	local nextDef = chain[index + 1]
	return {
		id = def.id,
		cat = def.cat,
		nameKey = if hidden then AchievementView.SECRET_NAME else `ach.{def.id}.name`,
		descKey = if hidden then nil else `ach.{def.id}.desc`,
		args = { goal = goal },
		value = if done then math.max(value, goal) else value,
		goal = goal,
		pct = if done then 1 elseif goal > 0 then math.clamp(value / goal, 0, 1) else 0,
		done = done,
		doneAt = doneAt,
		scope = Achievements.scopeOf(def.counter),
		points = def.points,
		reward = if hidden then {} else AchievementView.rewardLines(def, st),
		tracked = isTracked(st, def.id),
		hidden = hidden,
		next = if nextDef then nextDef.id else nil,
		steps = if hidden then {} else steps(st, chain),
	}
end

local function inScope(def: AchDef, scope: string?): boolean
	return scope == nil or scope == "all" or Achievements.scopeOf(def.counter) == scope
end

local function rank(row: Row): number
	if row.done then
		return 3
	end
	return if row.value > 0 then 1 else 2
end

-- The list of the window. `cat` nil = every category; `filter` "all" | "open" | "done" (a series shows its current
-- step, under "done" its highest done step); `scope` "all" | "account" | "character".
function AchievementView.rows(st: State, cat: string?, filter: string?, scope: string?): { Row }
	local out: { Row } = {}
	local seen: { [string]: boolean } = {}
	for _, def in AchData.list do
		if (cat ~= nil and def.cat ~= cat) or not inScope(def, scope) then
			continue
		end
		local chain = AchievementView.chainOf(def)
		local root = chain[1]
		if seen[root.id] then
			continue
		end
		seen[root.id] = true
		local index: number? = nil
		if filter == "done" then
			for i = #chain, 1, -1 do
				if Achievements.isDone(st, chain[i]) then
					index = i
					break
				end
			end
		else
			index = #chain
			for i, step in chain do
				if not Achievements.isDone(st, step) then
					index = i
					break
				end
			end
		end
		if index == nil then
			continue
		end
		local row = rowOf(st, chain, index)
		if filter == "open" and row.done then
			continue
		end
		table.insert(out, row)
	end
	table.sort(out, function(a: Row, b: Row): boolean
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if ra == 1 and a.pct ~= b.pct then
			return a.pct > b.pct
		end
		if ra == 3 and a.doneAt ~= b.doneAt then
			return (a.doneAt or 0) > (b.doneAt or 0)
		end
		return (order[a.id] or 0) < (order[b.id] or 0)
	end)
	return out
end

-- One step (`id`) with its series (nil for an unknown id).
function AchievementView.detail(st: State, id: string): Row?
	local def = AchData.get(id)
	if not def then
		return nil
	end
	local chain = AchievementView.chainOf(def)
	local index = table.find(chain, def) or 1
	return rowOf(st, chain, index)
end

-- Summary -------------------------------------------------------------------------------------------------------------

function AchievementView.summary(st: State, scope: string?): Summary
	local out: Summary =
		{ points = 0, pointsMax = 0, done = 0, total = 0, byCat = {}, bestiary = { points = 0, pointsMax = 0 } }
	for _, cat in AchData.CATEGORIES do
		out.byCat[cat] = { done = 0, total = 0 }
	end
	for _, def in AchData.list do
		if not inScope(def, scope) then
			continue
		end
		local cat = out.byCat[def.cat]
		if not cat then
			cat = { done = 0, total = 0 }
			out.byCat[def.cat] = cat
		end
		out.total += 1
		out.pointsMax += def.points
		cat.total += 1
		if Achievements.isDone(st, def) then
			out.done += 1
			out.points += def.points
			cat.done += 1
		end
	end
	-- S151c: the bestiary tiers belong to the character
	if scope ~= "account" then
		out.bestiary = { points = Bestiary.points(st.chr), pointsMax = Bestiary.pointsMax() }
		out.points += out.bestiary.points
		out.pointsMax += out.bestiary.pointsMax
	end
	return out
end

-- Tracker and profile -------------------------------------------------------------------------------------------------

-- The tracked achievements that are not done, in the tracker's order.
function AchievementView.trackedRows(st: State): { Row }
	local out: { Row } = {}
	local track: { string } = st.chr.track or {}
	for _, id in track do
		local row = AchievementView.detail(st, id)
		if row and not row.done and not row.hidden then
			table.insert(out, row)
		end
	end
	return out
end

-- The `n` latest done achievements of the account and the character (newest first).
function AchievementView.recent(st: State, n: number): { Recent }
	local all: { Recent } = {}
	for _, branch in { st.acc, st.chr } do
		for id, at in branch.done do
			if type(at) == "number" and AchData.get(id) then
				table.insert(all, { id = id, at = at })
			end
		end
	end
	table.sort(all, function(a: Recent, b: Recent): boolean
		if a.at ~= b.at then
			return a.at > b.at
		end
		return a.id < b.id
	end)
	local out: { Recent } = {}
	for i = 1, math.min(n, #all) do
		table.insert(out, all[i])
	end
	return out
end

-- A read-only state over replicated (or any) save branches: the branch tables are fresh wrappers, so the repairs of
-- Achievements.state never touch the mirror of the client.
function AchievementView.read(account: any, character: any): State
	local function wrap(raw: any, withPaid: boolean): any
		local b: any = if type(raw) == "table" then raw else {}
		return {
			c = if type(b.c) == "table" then b.c else {},
			s = if type(b.s) == "table" then b.s else {},
			done = if type(b.done) == "table" then b.done else {},
			paid = if withPaid and type(b.paid) == "table" then b.paid else nil,
			paidHere = if not withPaid and type(b.paidHere) == "table" then b.paidHere else nil,
			track = if type(b.track) == "table" then table.clone(b.track) else nil,
			-- S151c: the bestiary (read only: Bestiary.repair keeps good tables as they are)
			b = if not withPaid and type(b.b) == "table" then b.b else nil,
			bd = if not withPaid and type(b.bd) == "table" then b.bd else nil,
		}
	end
	local acc = { ach = wrap(if type(account) == "table" then account.ach else nil, true) }
	local chr = { ach = wrap(if type(character) == "table" then character.ach else nil, false) }
	return Achievements.state(acc, chr)
end

return table.freeze(AchievementView)
