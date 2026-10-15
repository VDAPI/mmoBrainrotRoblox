--!strict
-- Leaderboards (S124, DESIGN-17 §5), pure: the rules every server and the Rankings window share. No Roblox API and no
-- clock of its own (time always comes in as `now`), so everything here runs in Lune (tests/leaderboard.spec).
--   * score encoding: level x 10^10 + the share of the level (10^9 steps); at the top level the moment it was reached
--     (who was first stays higher). Integers below 2^53 (OrderedDataStore keeps whole numbers only).
--     This is the only place where a leaderboard score depends on game data: a scorer gets the character, never the
--     account, so no purchase can move it (DESIGN-17 §0.2, tests/paywall.spec);
--   * board instance ids: a board with `parts` (S125+ week, season, bracket) is "<id>_<part>_<part>";
--   * an in-memory board (the fallback of OrderedDataStore / SortedMap when the services are off, Studio and Lune);
--   * write throttling: one write per board and entry key every `gap` seconds, deltas summed in between;
--   * rows for the window: exclusions, metadata, the own row, the position or "outside the top";
--   * short lists (Hall of Fame): first `max` forever or the latest `max`, ordered by the moment (idempotent);
--   * the panels of the town board.
--   * S125: weekly EXP (brackets, the character's week, the entry and its merge, the payout lock and plan) and the guild
--     score (sum of the highest member levels, older guild first on a tie).

local Classes = require("../Data/Classes")
local Config = require("../Config")
local Exp = require("./Exp")
local Leaderboards = require("../Data/Leaderboards")
local Time = require("./Time")

export type BoardDef = Leaderboards.BoardDef
export type TabDef = Leaderboards.TabDef
export type PanelDef = Leaderboards.PanelDef
export type Kind = Leaderboards.Kind
export type Format = Leaderboards.Format

-- Entry metadata (DataStore Config.Leaderboard.metaStore): name, class id, guild tag, level, userId, write time.
-- `d` = the character was deleted (KeyStore cannot remove a key, so a marker stands for "no metadata").
-- S125: `m` = members of a guild entry (the guild board; `n` = guild name, `g` = tag, `l` = highest member level).
export type Meta = { n: string, c: string?, g: string?, l: number?, u: number?, t: number, d: boolean?, m: number? }
-- `value` = the metadata of a sorted entry; S125 `raw` = the whole stored value of a sorted entry ({ s, m, cid? }).
export type Entry = { key: string, score: number, value: any?, raw: any? }
-- A row for the client: rank, name, class text key ("@class.<Id>.name"), guild tag, level, percent of the level,
-- score, date (lists), own row. Entry keys and user ids never leave the server.
export type Row = {
	r: number,
	n: string,
	c: string?,
	g: string?,
	l: number?,
	p: number?,
	s: number,
	at: number?,
	mine: boolean?,
	m: number?, -- S125: guild members
}
-- The player's own line: rank, or level and percent outside the top, or below the minimum level, or hidden; for lists
-- the free places left.
-- S125: `s` = own weekly EXP / guild score, `b` = own weekly bracket, `none` = no guild (the guild board).
export type Me = {
	r: number?,
	l: number?,
	p: number?,
	hidden: boolean?,
	below: number?,
	left: number?,
	s: number?,
	b: number?,
	none: boolean?,
}
export type Snapshot = {
	id: string,
	kind: Kind,
	format: Format,
	rows: { Row },
	me: Me?,
	at: number,
	mode: "global" | "local",
	loading: boolean?,
	-- S125: the winners of the previous week in this bracket (exp_week only; place, name, class, level, EXP)
	last: { week: number, rows: { Row } }?,
}
-- A list entry (Hall of Fame): entry key, name, class, userId, the moment, and `cid` = the character id (a slot key
-- comes back for a new character after a delete; `cid` tells the two apart, entries without it match by key alone).
export type ListEntry = { k: string, n: string, c: string?, u: number?, at: number, cid: string? }
export type Pending = {
	board: string,
	key: string,
	score: number?,
	delta: number?,
	meta: Meta?,
	remove: boolean?,
	tries: number?,
}
export type Throttle = { last: { [string]: number }, pending: { [string]: Pending } }
export type QueueEntry = { score: number?, delta: number?, meta: Meta?, remove: boolean? }
export type Cfg = { excludeAdmins: boolean, minLevel: number }
export type MemoryBoard = {
	set: (key: string, score: number, value: any?, expiresAt: number?) -> (),
	update: (
		key: string,
		fn: (old: { score: number, value: any }?) -> (number?, any?),
		expiresAt: number?,
		now: number
	) -> number?,
	remove: (key: string) -> (),
	get: (key: string, now: number) -> { score: number, value: any }?,
	top: (n: number, now: number) -> { Entry },
	size: (now: number) -> number,
	clear: () -> (),
}
export type Column = { titleKey: string?, rows: { Row } }
export type Panel = { id: string, titleKey: string, kind: "top" | "lists", columns: { Column } }

local Leaderboard = {}

Leaderboard.LEVEL_BASE = 1e10
Leaderboard.FRAC_BASE = 1e9
-- Pseudo board of the metadata writes in the throttle (the worker sends them to the meta store).
Leaderboard.META_BOARD = "@meta"
Leaderboard.MAX_ID_LENGTH = 100

-- B1. Score ---------------------------------------------------------------------------------------------------------

-- The level score: level x LEVEL_BASE + the reached share of the level (0 .. FRAC_BASE - 1); at Config.MaxLevel
-- LEVEL_BASE - 1 - the moment it was reached (earlier = higher; no `reachedAt` counts as `now`). Whole number, < 2^53.
function Leaderboard.levelScore(level: number, exp: number, reachedAt: number?, now: number): number
	local maxLevel = Config.MaxLevel
	local l = math.clamp(math.floor(tonumber(level) or 1), 1, maxLevel)
	local base = Leaderboard.LEVEL_BASE
	if l < maxLevel then
		local need = Exp.expToNext(l)
		local have = math.max(tonumber(exp) or 0, 0)
		local frac = if need > 0 then math.floor(have / need * Leaderboard.FRAC_BASE) else 0
		return l * base + math.clamp(frac, 0, Leaderboard.FRAC_BASE - 1)
	end
	local at = math.clamp(math.floor(reachedAt or now), 0, base - 1)
	return maxLevel * base + (base - 1 - at)
end

-- (level, share of the level 0..1) of a level score; the share is nil at Config.MaxLevel.
function Leaderboard.decodeLevel(score: number): (number, number?)
	local base = Leaderboard.LEVEL_BASE
	local level = math.clamp(math.floor(score / base), 1, Config.MaxLevel)
	if level >= Config.MaxLevel then
		return level, nil
	end
	local rest = score - level * base
	return level, math.clamp(rest / Leaderboard.FRAC_BASE, 0, 1)
end

-- Snapshot scorers by Data/Leaderboards `score`. A scorer gets the character only: no account, no purchases
-- (DESIGN-17 §0.2, tests/paywall.spec). S125+ add theirs.
Leaderboard.SCORERS = table.freeze({
	level = function(c: any, now: number): number?
		return Leaderboard.levelScore(c.level, c.exp, c.reached100At, now)
	end,
}) :: { [string]: (character: any, now: number) -> number? }

-- B2. Board ids -----------------------------------------------------------------------------------------------------

-- S125: index of the bracket (1..#brackets) of a level, the level clamped to 1..Config.MaxLevel.
function Leaderboard.bracketOf(level: number, brackets: { { number } }?): number
	local list = brackets or Leaderboards.WEEK_BRACKETS
	local l = math.clamp(math.floor(tonumber(level) or 1), 1, Config.MaxLevel)
	for i, b in list do
		if l >= b[1] and l <= b[2] then
			return i
		end
	end
	return if l < list[1][1] then 1 else #list
end

-- Context of the instance parts: the moment, and S125 the level or the bracket index of the weekly board.
export type PartCtx = { now: number, level: number?, bracket: number? }

-- Instance parts of boards with `parts` (Data/Leaderboards): the week of S98, the month of S121 ("YYYYMM"), S125 the
-- weekly bracket (index into Data/Leaderboards.WEEK_BRACKETS).
Leaderboard.PARTS = table.freeze({
	week = function(ctx: PartCtx): string
		return tostring(Time.weekNumber(ctx.now))
	end,
	season = function(ctx: PartCtx): string
		return Time.monthKey(ctx.now)
	end,
	bracket = function(ctx: PartCtx): string
		return tostring(ctx.bracket or Leaderboard.bracketOf(ctx.level or 1))
	end,
}) :: { [string]: (ctx: PartCtx) -> string }

-- The instance id: `def.id`, or `def.id .. "_" .. parts` for a board with parts (the count must match).
function Leaderboard.instanceId(def: BoardDef, parts: { string }?): string
	local want = if def.parts then #def.parts else 0
	local got = if parts then #parts else 0
	if want ~= got then
		error(`Leaderboard.instanceId: {def.id} needs {want} parts, got {got}`)
	end
	if want == 0 then
		return def.id
	end
	return def.id .. "_" .. table.concat(parts :: { string }, "_")
end

-- The parts of the board at `now` (Leaderboard.PARTS), for boards with parts.
function Leaderboard.partsAt(def: BoardDef, now: number): { string }?
	if not def.parts or #def.parts == 0 then
		return nil
	end
	local out = {}
	for _, name in def.parts do
		local part = Leaderboard.PARTS[name]
		if not part then
			error(`Leaderboard.partsAt: unknown part {name} of {def.id}`)
		end
		table.insert(out, part({ now = now }))
	end
	return out
end

local function cleanPart(part: string, last: boolean): boolean
	if part == "" or #part > 40 then
		return false
	end
	if not last then
		return string.match(part, "^[%w]+$") ~= nil
	end
	return string.match(part, "^[%w_]+$") ~= nil
		and string.sub(part, 1, 1) ~= "_"
		and string.sub(part, -1) ~= "_"
		and string.find(part, "__", 1, true) == nil
end

-- Definition and parts of an instance id: the exact id first, then the longest `<id>_` prefix of a board with parts;
-- the first parts are `[%w]+`, the last takes the rest (it may hold "_", e.g. the arena bracket "40_59"). Unknown or
-- malformed -> nil. `list` = the definitions to look in (tests), default Data/Leaderboards.
function Leaderboard.resolve(instanceId: string, list: { BoardDef }?): (BoardDef?, { string }?)
	if type(instanceId) ~= "string" or instanceId == "" or #instanceId > Leaderboard.MAX_ID_LENGTH then
		return nil, nil
	end
	local defs = list or Leaderboards.list
	for _, def in defs do
		if def.id == instanceId and (def.parts == nil or #def.parts == 0) then
			return def, nil
		end
	end
	local best: BoardDef? = nil
	for _, def in defs do
		if def.parts and #def.parts > 0 and string.sub(instanceId, 1, #def.id + 1) == def.id .. "_" then
			if not best or #def.id > #best.id then
				best = def
			end
		end
	end
	if not best then
		return nil, nil
	end
	local def = best :: BoardDef
	local count = #(def.parts :: { string })
	local rest = string.sub(instanceId, #def.id + 2)
	local parts = {}
	for _ = 1, count - 1 do
		local part, tail = string.match(rest, "^([%w]+)_(.*)$")
		if not part or not tail or not cleanPart(part, false) then
			return nil, nil
		end
		table.insert(parts, part)
		rest = tail
	end
	if not cleanPart(rest, true) then
		return nil, nil
	end
	table.insert(parts, rest)
	return def, parts
end

-- The board of a tab for a filter value: filter "class" -> the board of that class (nil = the board without a class).
-- S125: filter "bracket" -> the instance id of the first board at `now` for that bracket index ("1".."4"; nil
-- without `now`).
function Leaderboard.boardFor(tab: TabDef, filterValue: string?, now: number?): string?
	if tab.filter == "bracket" then
		local def = Leaderboards.get(tab.boards[1])
		if not def or now == nil then
			return nil
		end
		local count = #Leaderboards.WEEK_BRACKETS
		local bracket = math.clamp(math.floor(tonumber(filterValue) or 1), 1, count)
		local parts = {}
		local names: { string } = def.parts or {}
		for _, name in names do
			local part = Leaderboard.PARTS[name]
			if not part then
				return nil
			end
			table.insert(parts, part({ now = now :: number, bracket = bracket }))
		end
		return Leaderboard.instanceId(def, if #parts > 0 then parts else nil)
	end
	if tab.filter == "class" then
		for _, id in tab.boards do
			local def = Leaderboards.get(id)
			if def and def.class == filterValue then
				return id
			end
		end
		return nil
	end
	return tab.boards[1]
end

-- S125: how far back a client may still ask for a period part (the window builds the id from server time; an hour
-- covers the turn of the week).
Leaderboard.READ_GRACE = 3600

-- S125: whether a client may read this instance (LeaderboardGet): a board without parts always; a board with parts
-- only for the period at `now` or READ_GRACE s before it and a bracket in 1..#WEEK_BRACKETS. Any other id would make
-- the server open and read maps the client picks.
function Leaderboard.readable(def: BoardDef, parts: { string }?, now: number): boolean
	local names: { string } = def.parts or {}
	local got: { string } = parts or {}
	if #names ~= #got then
		return false
	end
	for i, name in names do
		local value = got[i]
		if name == "bracket" then
			local b = tonumber(value)
			if b == nil or tostring(b) ~= value or b < 1 or b > #Leaderboards.WEEK_BRACKETS then
				return false
			end
		else
			local part = Leaderboard.PARTS[name]
			if not part or (value ~= part({ now = now }) and value ~= part({ now = now - Leaderboard.READ_GRACE })) then
				return false
			end
		end
	end
	return true
end

function Leaderboard.entryKey(userId: number, slot: number | string): string
	return `{math.floor(userId)}_{slot}`
end

-- (userId, slot) of a character entry key; nil for guild keys ("g_<id>") and anything else.
function Leaderboard.parseKey(key: string): (number?, string?)
	if type(key) ~= "string" then
		return nil, nil
	end
	local user, slot = string.match(key, "^(%d+)_(%w+)$")
	if not user then
		return nil, nil
	end
	return tonumber(user), slot
end

-- B3. Exclusions ----------------------------------------------------------------------------------------------------

-- Left out of every leaderboard: Config.AdminUserIds (with excludeAdmins) and characters with `lbHidden` (/lb hide).
-- In Studio everyone may run admin commands (AdminService.IsAdmin), but this reads AdminUserIds only (empty in Studio),
-- so the Studio leaderboards fill up.
function Leaderboard.excluded(userId: number, character: any?, adminIds: { number }, cfg: Cfg): boolean
	if cfg.excludeAdmins and table.find(adminIds, userId) ~= nil then
		return true
	end
	return character ~= nil and character.lbHidden == true
end

function Leaderboard.eligible(character: any, cfg: Cfg): boolean
	return (tonumber(character.level) or 0) >= cfg.minLevel
end

-- B4. In-memory board -------------------------------------------------------------------------------------------------

local function better(a: Entry, b: Entry): boolean
	if a.score ~= b.score then
		return a.score > b.score
	end
	return a.key < b.key
end
Leaderboard.better = better

-- A board in memory: highest score first, ties by key ascending; entries with `expiresAt <= now` are gone.
function Leaderboard.memoryBoard(): MemoryBoard
	local entries: { [string]: { score: number, value: any, expiresAt: number? } } = {}

	local function live(key: string, now: number): { score: number, value: any, expiresAt: number? }?
		local e = entries[key]
		if e and e.expiresAt and e.expiresAt <= now then
			entries[key] = nil
			return nil
		end
		return e
	end

	local board = {}

	function board.set(key: string, score: number, value: any?, expiresAt: number?)
		entries[key] = { score = score, value = value, expiresAt = expiresAt }
	end

	function board.update(
		key: string,
		fn: (old: { score: number, value: any }?) -> (number?, any?),
		expiresAt: number?,
		now: number
	): number?
		local old = live(key, now)
		local score, value = fn(if old then { score = old.score, value = old.value } else nil)
		if score == nil then
			return nil
		end
		entries[key] = { score = score, value = value, expiresAt = expiresAt or (old and old.expiresAt) }
		return score
	end

	function board.remove(key: string)
		entries[key] = nil
	end

	function board.get(key: string, now: number): { score: number, value: any }?
		local e = live(key, now)
		return if e then { score = e.score, value = e.value } else nil
	end

	function board.top(n: number, now: number): { Entry }
		local out: { Entry } = {}
		for key in entries do
			local e = live(key, now)
			if e then
				table.insert(out, { key = key, score = e.score, value = e.value })
			end
		end
		table.sort(out, better)
		while #out > n do
			table.remove(out)
		end
		return out
	end

	function board.size(now: number): number
		local n = 0
		for key in entries do
			if live(key, now) then
				n += 1
			end
		end
		return n
	end

	function board.clear()
		table.clear(entries)
	end

	return board :: MemoryBoard
end

-- B5. Throttle ------------------------------------------------------------------------------------------------------

function Leaderboard.newThrottle(): Throttle
	return { last = {}, pending = {} }
end

local function throttleKey(instanceId: string, key: string): string
	return instanceId .. "|" .. key
end
Leaderboard.throttleKey = throttleKey

-- Queues a write: a score replaces the queued one, a delta adds up, meta replaces, remove drops what was queued (and a
-- later write drops the removal).
-- Returns true when this board and key may be written now (`gap` passed since the last write).
function Leaderboard.queue(
	t: Throttle,
	instanceId: string,
	key: string,
	entry: QueueEntry,
	now: number,
	gap: number
): boolean
	local k = throttleKey(instanceId, key)
	local p: Pending = t.pending[k] or { board = instanceId, key = key }
	if entry.remove then
		p.remove = true
		p.score = nil
		p.delta = nil
		p.meta = nil
	else
		-- anything written after a queued removal replaces it
		if entry.score ~= nil then
			p.score = entry.score
			p.remove = nil
		end
		if entry.delta ~= nil then
			p.delta = (p.delta or 0) + entry.delta
			p.remove = nil
		end
		if entry.meta ~= nil then
			p.meta = entry.meta
			p.remove = nil
		end
	end
	t.pending[k] = p
	local last = t.last[k]
	return last == nil or now - last >= gap
end

-- The queued writes that are due (all of them with `force`: leave, shutdown), in a stable order; marks them written.
function Leaderboard.due(t: Throttle, now: number, gap: number, force: boolean?): { Pending }
	local keys = {}
	for k in t.pending do
		local last = t.last[k]
		if force or last == nil or now - last >= gap then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	local out = {}
	for _, k in keys do
		table.insert(out, t.pending[k])
		t.pending[k] = nil
		t.last[k] = now
	end
	return out
end

-- Lets every queued write of entry `key` go at the next `due` (leave, delete, admin submit: "and once more on leave").
function Leaderboard.release(t: Throttle, key: string)
	for k, p in t.pending do
		if p.key == key then
			t.last[k] = nil
		end
	end
end

-- Number of queued writes.
function Leaderboard.pendingCount(t: Throttle): number
	local n = 0
	for _ in t.pending do
		n += 1
	end
	return n
end

-- B6. Rows ----------------------------------------------------------------------------------------------------------

function Leaderboard.classKey(class: string?): string?
	return if class then `@class.{class}.name` else nil
end

-- Rows of a score board: excluded users dropped (also entries written before someone became an admin), ranks from 1
-- after the filter, metadata filled in (none -> empty name), level and percent for `format = "level"`.
function Leaderboard.rows(
	def: BoardDef,
	entries: { Entry },
	metaOf: (key: string) -> Meta?,
	isExcluded: (userId: number) -> boolean,
	myKey: string?
): { Row }
	local out: { Row } = {}
	for _, e in entries do
		local user = Leaderboard.parseKey(e.key)
		if user and isExcluded(user) then
			continue
		end
		-- S125: a sorted entry carries its own metadata (the weekly board); the shared cache is for ordered boards
		local meta: Meta? = if type(e.value) == "table" and type(e.value.n) == "string" then e.value else metaOf(e.key)
		if meta and meta.d then
			meta = nil
		end
		local row: Row = {
			r = #out + 1,
			n = if meta then meta.n else "",
			c = Leaderboard.classKey(if meta and meta.c then meta.c else def.class),
			g = if meta then meta.g else nil,
			s = e.score,
			mine = if myKey ~= nil and e.key == myKey then true else nil,
		}
		if def.format == "level" then
			local level, frac = Leaderboard.decodeLevel(e.score)
			row.l = level
			row.p = if frac then math.floor(frac * 100) else nil
		elseif def.format == "guild" then
			-- S125: the decoded sum of levels, the members and the highest level from the metadata
			row.s = Leaderboard.decodeGuild(e.score)
			row.l = if meta then meta.l else nil
			row.m = if meta then meta.m else nil
			row.c = nil
		elseif def.format == "int" then
			-- S125: weekly EXP, the level at the last write
			row.l = if meta then meta.l else nil
		end
		table.insert(out, row)
	end
	return out
end

-- Rows of a list board (Hall of Fame): in list order, the date of each entry; `mine` = this key and character id.
function Leaderboard.listRows(
	def: BoardDef,
	list: { ListEntry },
	isExcluded: (userId: number) -> boolean,
	myKey: string?,
	myCid: string?
): { Row }
	local out: { Row } = {}
	for _, e in list do
		if e.u and isExcluded(e.u) then
			continue
		end
		table.insert(out, {
			r = #out + 1,
			n = e.n,
			c = Leaderboard.classKey(e.c or def.class),
			s = e.at,
			at = e.at,
			mine = if myKey ~= nil and Leaderboard.sameEntry(e, myKey, myCid) then true else nil,
		})
	end
	return out
end

-- A copy of `entries` with the own score put in its place (nil = removed), cut to `max`: a server sees its own write
-- at once instead of after the next read.
function Leaderboard.mergeLocal(entries: { Entry }, key: string, score: number?, max: number): { Entry }
	local out: { Entry } = {}
	for _, e in entries do
		if e.key ~= key then
			table.insert(out, e)
		end
	end
	if score ~= nil then
		local mine: Entry = { key = key, score = score }
		local at = #out + 1
		for i, e in out do
			if better(mine, e) then
				at = i
				break
			end
		end
		table.insert(out, at, mine)
	end
	while #out > max do
		table.remove(out)
	end
	return out
end

-- The rank of the own row (`mine`).
function Leaderboard.rankOf(rows: { Row }): number?
	for _, row in rows do
		if row.mine then
			return row.r
		end
	end
	return nil
end

-- The player's line under a score board.
function Leaderboard.me(character: any, rows: { Row }, cfg: Cfg, excluded: boolean): Me
	if excluded then
		return { hidden = true }
	end
	if not Leaderboard.eligible(character, cfg) then
		return { below = cfg.minLevel }
	end
	local rank = Leaderboard.rankOf(rows)
	if rank then
		local row = rows[rank]
		return { r = rank, l = row.l, p = row.p }
	end
	local level = math.clamp(math.floor(tonumber(character.level) or 1), 1, Config.MaxLevel)
	local pct: number? = nil
	if level < Config.MaxLevel then
		local need = Exp.expToNext(level)
		pct = if need > 0 then math.clamp(math.floor((tonumber(character.exp) or 0) / need * 100), 0, 99) else 0
	end
	return { l = level, p = pct }
end

-- The player's line under a list board: the place, or the places left.
function Leaderboard.listMe(list: { ListEntry }, key: string?, max: number, excluded: boolean, cid: string?): Me
	if excluded then
		return { hidden = true }
	end
	local place = if key then Leaderboard.placeOf(list, key, cid) else nil
	if place then
		return { r = place }
	end
	return { left = math.max(max - #list, 0) }
end

-- B7. Lists ---------------------------------------------------------------------------------------------------------

local function listOrder(a: ListEntry, b: ListEntry): boolean
	if a.at ~= b.at then
		return a.at < b.at
	end
	return a.k < b.k
end

-- The list entry of key `k` and character `cid` (nil on either side = the key alone decides).
function Leaderboard.sameEntry(e: ListEntry, k: string, cid: string?): boolean
	return e.k == k and (cid == nil or e.cid == nil or e.cid == cid)
end

-- A new list with `entry` (a copy; the input is not changed), or nil and why: "dup" (this key and character are in
-- already: nothing to write, idempotent; another character on a reused slot key is a new entry), "full" (mode "first" keeps the first `max` for good). Ordered by `at`, then key, so two servers
-- writing at once end with the same list. Fits KeyStore.update as the mutate step.
function Leaderboard.listInsert(
	list: { ListEntry }?,
	entry: ListEntry,
	max: number,
	mode: "first" | "latest"
): ({ ListEntry }?, string?)
	local out: { ListEntry } = {}
	local current: { ListEntry } = list or {}
	for _, e in current do
		if Leaderboard.sameEntry(e, entry.k, entry.cid) then
			return nil, "dup"
		end
		table.insert(out, table.clone(e))
	end
	if mode == "first" and #out >= max then
		return nil, "full"
	end
	table.insert(out, table.clone(entry))
	table.sort(out, listOrder)
	while #out > max do
		table.remove(out, 1)
	end
	return out, nil
end

function Leaderboard.placeOf(list: { ListEntry }?, key: string, cid: string?): number?
	local current: { ListEntry } = list or {}
	for i, e in current do
		if Leaderboard.sameEntry(e, key, cid) then
			return i
		end
	end
	return nil
end

-- B8. Town board ----------------------------------------------------------------------------------------------------

local function townRow(row: Row): Row
	return { r = row.r, n = row.n, c = row.c, g = row.g, l = row.l, p = row.p, s = row.s, at = row.at }
end

local function named(rows: { Row }, n: number): { Row }
	local out = {}
	for _, row in rows do
		if row.n ~= "" then
			table.insert(out, townRow(row))
			if #out >= n then
				break
			end
		end
	end
	return out
end

-- The panels of the town board from snapshots (`read(boardId)`): "top" = one column with the first `n` rows, "lists" =
-- a column per board titled with its name. Rows without a name (metadata not read yet) are skipped. Plain values only
-- (the server sends this as JSON in an attribute).
function Leaderboard.townPanels(panels: { PanelDef }, read: (boardId: string) -> Snapshot?): { Panel }
	local out: { Panel } = {}
	for _, panel in panels do
		local columns: { Column } = {}
		if panel.kind == "top" then
			local snap = read(panel.boards[1])
			table.insert(columns, { rows = if snap then named(snap.rows, panel.n) else {} })
		else
			for _, id in panel.boards do
				local def = Leaderboards.get(id)
				local snap = read(id)
				table.insert(columns, {
					titleKey = if def then def.nameKey else nil,
					rows = if snap then named(snap.rows, panel.n) else {},
				})
			end
		end
		table.insert(out, { id = panel.id, titleKey = panel.titleKey, kind = panel.kind, columns = columns })
	end
	return out
end

-- B9. Dates ---------------------------------------------------------------------------------------------------------

-- Day, month and year of a Unix time (UTC) with leading zeros; the client joins them with `leaderboard.date`.
function Leaderboard.dateParts(unix: number): { d: string, m: string, y: string }
	local year, month, day = Time.civil(unix)
	return { d = string.format("%02d", day), m = string.format("%02d", month), y = tostring(year) }
end

-- Test characters for /lb fake (Studio, in-memory boards only): `n` entries spread from the top level down, classes
-- in turn, deterministic. Key "0_<i>" (user 0 is never a real player).
function Leaderboard.fakeEntries(n: number, now: number): { { key: string, score: number, meta: Meta, at: number? } }
	local out = {}
	local count = math.clamp(math.floor(n), 0, 200)
	for i = 1, count do
		local class = Classes.order[(i - 1) % #Classes.order + 1]
		local level = math.max(1, Config.MaxLevel - math.floor((i - 1) * (Config.MaxLevel - 1) / math.max(count, 1)))
		local at: number? = nil
		local exp = 0
		if level >= Config.MaxLevel then
			at = now - (count - i + 1) * 3600
		else
			exp = math.floor(Exp.expToNext(level) * ((i * 37) % 100) / 100)
		end
		table.insert(out, {
			key = `0_{i}`,
			score = Leaderboard.levelScore(level, exp, at, now),
			meta = { n = `Test_{i}`, c = class, l = level, u = 0, t = now },
			at = at,
		})
	end
	return out
end

-- B10. Weekly EXP (S125) --------------------------------------------------------------------------------------------

-- The value of a weekly entry (MemoryStore SortedMap, the shape of Stores.sorted { s, m } plus `cid`): the week's EXP,
-- the metadata (short keys: MemoryStore counts bytes) and the character id (a slot key comes back for a new character).
export type WeeklyValue = { s: number, m: Meta, cid: string? }
export type ExpWeek = { week: number, exp: number, b: number }
export type WeeklyInput = {
	userId: number,
	slot: number | string,
	charId: string,
	name: string,
	class: string,
	level: number,
	guildTag: string?,
	exp: number,
	now: number,
}
-- One reward of a weekly payout (server only: userId and key never reach a client).
export type Payout = {
	key: string,
	userId: number,
	charId: string?,
	bracket: number,
	place: number,
	shards: number,
	title: string,
	untilTs: number,
	name: string,
	class: string?,
	level: number?,
	exp: number,
}
-- A winner as the payout record keeps it for the Rankings window: bracket, place, name, class, level, EXP.
export type Winner = { b: number, p: number, n: string, c: string?, l: number?, e: number }
export type Rewards = { shards: { number }, title: string, titleDays: number }

-- "1–19" (en dash; the same in every language, for mail subjects and the window).
function Leaderboard.bracketLabel(index: number, brackets: { { number } }?): string
	local b = (brackets or Leaderboards.WEEK_BRACKETS)[index]
	return if b then `{b[1]}–{b[2]}` else ""
end

-- The instance id of the weekly board of (week, bracket), e.g. "exp_week_2963_2"; Stores.sorted adds the store prefix,
-- tools/rankings_fetch builds the same name.
function Leaderboard.weekMapName(week: number, bracket: number): string
	local def = Leaderboards.get("exp_week") :: BoardDef
	return Leaderboard.instanceId(def, { tostring(week), tostring(bracket) })
end

-- Whether EXP of this LevelService.GiveExp source counts for the week (Data/Leaderboards.WEEK_SOURCES allowlist).
function Leaderboard.countsForWeek(source: string?): boolean
	return source ~= nil and Leaderboards.WEEK_SOURCES[source] == true
end

-- The new weekly state after `gained` EXP in `week` (the input is not changed): another week starts from 0, negative,
-- NaN and infinite amounts add nothing.
function Leaderboard.addWeekly(state: ExpWeek?, week: number, gained: number): ExpWeek
	local same = type(state) == "table" and state.week == week
	local out: ExpWeek = {
		week = week,
		exp = if same then math.max(0, math.floor(tonumber((state :: ExpWeek).exp) or 0)) else 0,
		b = if same then tonumber((state :: ExpWeek).b) or 0 else 0,
	}
	local g = tonumber(gained) or 0
	if g == g and g > 0 and g < math.huge then
		out.exp += math.floor(g)
	end
	return out
end

-- The weekly EXP of a character in `week` (0 when its state is from another week).
function Leaderboard.weekExp(character: any, week: number): number
	local state = if type(character) == "table" then character.expWeek else nil
	if type(state) == "table" and state.week == week then
		return math.max(0, math.floor(tonumber(state.exp) or 0))
	end
	return 0
end

-- The entry of a character on the weekly board: key "<userId>_<slot>", the value and its sort key (= EXP).
function Leaderboard.weeklyEntry(input: WeeklyInput): { key: string, value: WeeklyValue, sortKey: number }
	local exp = math.max(0, math.floor(tonumber(input.exp) or 0))
	return {
		key = Leaderboard.entryKey(input.userId, input.slot),
		value = {
			s = exp,
			m = {
				n = input.name,
				c = input.class,
				g = input.guildTag,
				l = input.level,
				u = input.userId,
				t = input.now,
			},
			cid = input.charId,
		},
		sortKey = exp,
	}
end

-- The UpdateAsync step of a weekly write (no side effects): the absolute week total wins when it is not lower, so a
-- retried write never counts twice and an older, lower total from another server never replaces a higher one; a new
-- character on the slot (other `cid`) replaces the entry. nil = nothing to write.
function Leaderboard.mergeWeekly(current: WeeklyValue?, incoming: WeeklyValue): WeeklyValue?
	if type(current) ~= "table" or type(current.s) ~= "number" or current.cid ~= incoming.cid then
		return incoming
	end
	if incoming.s >= current.s then
		return incoming
	end
	return nil
end

-- The UpdateAsync step of the payout lock "paid_<week>": nil record (or one reset by /rankweek reset) -> claimed by
-- `jobId`; "done" -> nil, "done"; claimed by another server less than `staleAfter` s ago -> nil, "busy"; claimed by
-- this server or stale -> taken over, keeping what was sent and planned.
function Leaderboard.claimPayout(record: any?, jobId: string, now: number, staleAfter: number): (any?, string?)
	if type(record) ~= "table" or (record.state ~= "claimed" and record.state ~= "done") then
		return { state = "claimed", job = jobId, at = now, sent = {}, winners = {} }, nil
	end
	if record.state == "done" then
		return nil, "done"
	end
	if record.job ~= jobId and now - (tonumber(record.at) or 0) < staleAfter then
		return nil, "busy"
	end
	local out = table.clone(record)
	out.job = jobId
	out.at = now
	out.sent = if type(record.sent) == "table" then record.sent else {}
	out.winners = if type(record.winners) == "table" then record.winners else {}
	return out, nil
end

-- The rewards of week `week` from the tops of its brackets (`tops[bracket]` = entries as read): per bracket the first
-- #rewards.shards entries with EXP > 0 and a character key, ordered by EXP and then key ascending (the in-memory
-- board's order; equal EXP on places 3 and 4: only the lower key is rewarded). The title lasts until titleDays after
-- the start of the next week (an absolute term, whenever the mail is taken).
function Leaderboard.payoutPlan(
	week: number,
	tops: { [number]: { { key: string, value: any } } },
	rewards: Rewards?
): { Payout }
	local r: Rewards = rewards or (Leaderboards.WEEK_REWARDS :: any)
	local untilTs = Time.weekStart(week + 1) + r.titleDays * 86400
	local brackets = {}
	for b in tops do
		table.insert(brackets, b)
	end
	table.sort(brackets)
	local out: { Payout } = {}
	for _, b in brackets do
		local list = {}
		for _, e in tops[b] do
			local v = e.value
			local user = Leaderboard.parseKey(e.key)
			if user and type(v) == "table" and type(v.s) == "number" and v.s > 0 then
				table.insert(list, { key = e.key, value = v, user = user })
			end
		end
		table.sort(list, function(x, y)
			if x.value.s ~= y.value.s then
				return x.value.s > y.value.s
			end
			return x.key < y.key
		end)
		for place = 1, math.min(#list, #r.shards) do
			local e = list[place]
			local meta = if type(e.value.m) == "table" then e.value.m else {}
			table.insert(out, {
				key = e.key,
				userId = e.user,
				charId = if type(e.value.cid) == "string" then e.value.cid else nil,
				bracket = b,
				place = place,
				shards = r.shards[place],
				title = r.title,
				untilTs = untilTs,
				name = if type(meta.n) == "string" then meta.n else "",
				class = if type(meta.c) == "string" then meta.c else nil,
				level = if type(meta.l) == "number" then meta.l else nil,
				exp = math.floor(e.value.s),
			})
		end
	end
	return out
end

-- The public part of a plan (kept in the payout record for the Rankings window): no keys, user or character ids.
function Leaderboard.winnersOf(plan: { Payout }): { Winner }
	local out: { Winner } = {}
	for _, p in plan do
		table.insert(out, { b = p.bracket, p = p.place, n = p.name, c = p.class, l = p.level, e = p.exp })
	end
	return out
end

-- Rows of the winners of one bracket (place order).
function Leaderboard.winnerRows(winners: { Winner }?, bracket: number): { Row }
	local out: { Row } = {}
	local list: { Winner } = winners or {}
	for _, w in list do
		if type(w) == "table" and w.b == bracket then
			table.insert(out, { r = w.p, n = w.n, c = Leaderboard.classKey(w.c), l = w.l, s = w.e })
		end
	end
	table.sort(out, function(a, b)
		return a.r < b.r
	end)
	return out
end

-- Seconds until the next week (Monday 00:00 UTC, the S98 week).
function Leaderboard.weekEndsIn(now: number): number
	return Time.weekStart(Time.weekNumber(now) + 1) - now
end

-- The player's line under a weekly board: rank (from the rows), the week's EXP and the own bracket.
function Leaderboard.weekMe(character: any, rows: { Row }, week: number, excluded: boolean): Me
	if excluded then
		return { hidden = true }
	end
	return {
		r = Leaderboard.rankOf(rows),
		s = Leaderboard.weekExp(character, week),
		b = Leaderboard.bracketOf(if type(character) == "table" then character.level else 1),
	}
end

-- B11. Guilds (S125) ------------------------------------------------------------------------------------------------

Leaderboard.GUILD_BASE = 1e10

function Leaderboard.guildKey(guildId: string): string
	return "g_" .. guildId
end

-- The guild score: the sum of the `top` (default Config.Leaderboard.guildTop) highest member levels; nothing else of
-- the guild (treasury, skills) counts (DESIGN-17 §0.2).
function Leaderboard.guildScore(members: { [string]: { level: number } }?, top: number?): number
	local levels = {}
	local list: { [string]: { level: number } } = members or {}
	for _, m in list do
		if type(m) == "table" then
			table.insert(levels, math.max(0, math.floor(tonumber(m.level) or 0)))
		end
	end
	table.sort(levels, function(a, b)
		return a > b
	end)
	local sum = 0
	for i = 1, math.min(#levels, top or Config.Leaderboard.guildTop) do
		sum += levels[i]
	end
	return sum
end

-- The board value of a guild: score x 10^10 + (10^10 - 1 - createdAt), so on an equal score the older guild is higher.
-- A whole number below 2^53 for any score up to 900000.
function Leaderboard.encodeGuild(score: number, createdAt: number): number
	local base = Leaderboard.GUILD_BASE
	local at = math.clamp(math.floor(tonumber(createdAt) or 0), 0, base - 1)
	return math.max(0, math.floor(score)) * base + (base - 1 - at)
end

function Leaderboard.decodeGuild(value: number): number
	return math.max(0, math.floor(value / Leaderboard.GUILD_BASE))
end

-- The player's line under the guild board: no guild, or the rank (from the rows) and the guild's score.
function Leaderboard.guildMe(guild: any?, rows: { Row }): Me
	if type(guild) ~= "table" or guild.disbanded then
		return { none = true }
	end
	return { r = Leaderboard.rankOf(rows), s = Leaderboard.guildScore(guild.members) }
end

-- Test entries for /lb fake on the in-memory weekly boards: the characters of fakeEntries with a week's EXP falling
-- with the index, each in the bracket of its level.
function Leaderboard.fakeWeekly(n: number, now: number): { { key: string, bracket: number, value: WeeklyValue } }
	local out = {}
	local fakes = Leaderboard.fakeEntries(n, now)
	for i, fake in fakes do
		table.insert(out, {
			key = fake.key,
			bracket = Leaderboard.bracketOf(fake.meta.l or 1),
			value = {
				s = (#fakes - i + 1) * 1000 + (i * 37) % 1000,
				m = fake.meta,
				cid = `fake{i}`,
			},
		})
	end
	return out
end

-- Test guilds for /lb fake (at most 30): key "g_fake<i>", score falling with the index.
function Leaderboard.fakeGuilds(n: number, now: number): { { key: string, score: number, meta: Meta } }
	local out = {}
	local count = math.clamp(math.floor(n), 0, 30)
	for i = 1, count do
		local members = math.max(1, 12 - (i - 1) % 12)
		local highest = math.max(1, Config.MaxLevel - (i - 1) * 3)
		local counted = math.min(members, Config.Leaderboard.guildTop)
		table.insert(out, {
			key = Leaderboard.guildKey(`fake{i}`),
			score = Leaderboard.encodeGuild(math.max(1, highest * counted - i), now - i * 86400),
			meta = { n = `Guild {i}`, g = `T{i}`, l = highest, m = members, t = now },
		})
	end
	return out
end

return Leaderboard
