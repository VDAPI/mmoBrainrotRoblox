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
export type Meta = { n: string, c: string?, g: string?, l: number?, u: number?, t: number, d: boolean? }
export type Entry = { key: string, score: number, value: any? }
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
}
-- The player's own line: rank, or level and percent outside the top, or below the minimum level, or hidden; for lists
-- the free places left.
export type Me = { r: number?, l: number?, p: number?, hidden: boolean?, below: number?, left: number? }
export type Snapshot = {
	id: string,
	kind: Kind,
	format: Format,
	rows: { Row },
	me: Me?,
	at: number,
	mode: "global" | "local",
	loading: boolean?,
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

-- Instance parts of boards with `parts` (Data/Leaderboards): the week of S98, the month of S121 ("YYYYMM").
Leaderboard.PARTS = table.freeze({
	week = function(ctx: { now: number }): string
		return tostring(Time.weekNumber(ctx.now))
	end,
	season = function(ctx: { now: number }): string
		return Time.monthKey(ctx.now)
	end,
}) :: { [string]: (ctx: { now: number }) -> string }

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
function Leaderboard.boardFor(tab: TabDef, filterValue: string?): string?
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
		local meta = metaOf(e.key)
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

return Leaderboard
