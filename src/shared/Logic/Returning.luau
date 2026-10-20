--!strict
-- S153 (docs/DESIGN.md §11): help for returning players. Pure rules, the time comes from outside (Util/Clock on the
-- server). ReturningService owns account.returning and account.stats.lastSeen.
--   check     after at least Config.Returning.awayDays without playing, once per cooldownDays, an account whose
--             highest character has minLevel gets `seconds` of play in the world (set, never added)
--   tick      counts the bonus down only while a character is in the world
--   bonus     the expBonus points while time is left (added to every other expBonus, e.g. the blessing of Fortune)
--   letter    the Data/Changelog entries newer than `seen` that are out already, newest first, at most letterMax
--   markSeen  `seen` = the highest id of the entries read
-- An account without lastSeen (the first load after S153, or a new account) gets no bonus and no letter.

local Changelog = require("../Data/Changelog")
local Config = require("../Config")
local Time = require("./Time")

export type State = {
	left: number, -- seconds of bonus play left
	at: number, -- os.time of the last grant (0 = never)
	seen: number, -- the highest Data/Changelog id the player has read
}

local DAY = 86400

local Returning = {}

local function num(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.max(0, value)
end

-- A clean copy of a saved state: numbers only, never negative or NaN, `left` at most Config.Returning.seconds.
function Returning.sanitize(state: any): State
	local s = if type(state) == "table" then state else {}
	return {
		left = math.min(num(s.left), Config.Returning.seconds),
		at = math.floor(num(s.at)),
		seen = math.floor(num(s.seen)),
	}
end

-- (state, granted): the bonus for coming back after `lastSeen` (0 = unknown: nothing), `maxLevel` = the highest
-- character level of the account. A grant sets `left` to the full time and `at` to `now`.
function Returning.check(state: State, lastSeen: number, now: number, maxLevel: number): (State, boolean)
	local cfg = Config.Returning
	local s = Returning.sanitize(state)
	local seen = num(lastSeen)
	if seen <= 0 or now - seen < cfg.awayDays * DAY then
		return s, false
	end
	if s.at > 0 and now - s.at < cfg.cooldownDays * DAY then
		return s, false
	end
	if num(maxLevel) < cfg.minLevel then
		return s, false
	end
	s.left = cfg.seconds
	s.at = now
	return s, true
end

-- Counts `dt` seconds of play down while `inWorld`; never below 0.
function Returning.tick(state: State, dt: number, inWorld: boolean): State
	local s = Returning.sanitize(state)
	if inWorld and s.left > 0 then
		s.left = math.max(0, s.left - num(dt))
	end
	return s
end

-- The expBonus points the state gives now.
function Returning.bonus(state: State): number
	return if Returning.sanitize(state).left > 0 then Config.Returning.expBonus else 0
end

-- Whole minutes of bonus left (rounded up; the HUD counter and the texts).
function Returning.minutes(state: State): number
	return math.ceil(Returning.sanitize(state).left / 60)
end

-- The entries newer than `seen` that are out at `now` (their day has come), newest first, at most letterMax.
function Returning.letter(seen: number, entries: { Changelog.Entry }, now: number): { Changelog.Entry }
	local today = Time.dayNumber(now)
	local out: { Changelog.Entry } = {}
	for _, e in entries do
		if e.id > seen and e.day <= today then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return a.id > b.id
	end)
	while #out > Config.Returning.letterMax do
		table.remove(out)
	end
	return out
end

-- The last letterMax entries out at `now` regardless of `seen` (the game menu's "What's new"), newest first.
function Returning.recent(entries: { Changelog.Entry }, now: number): { Changelog.Entry }
	return Returning.letter(0, entries, now)
end

-- `seen` raised to the highest id of `entries` (never lowered).
function Returning.markSeen(state: State, entries: { Changelog.Entry }): State
	local s = Returning.sanitize(state)
	for _, e in entries do
		if e.id > s.seen then
			s.seen = e.id
		end
	end
	return s
end

-- The entries a client may report as read: id `upTo` must exist in the log; nil for anything else.
function Returning.readUpTo(entries: { Changelog.Entry }, upTo: number): { Changelog.Entry }?
	local known = false
	local out: { Changelog.Entry } = {}
	for _, e in entries do
		if e.id == upTo then
			known = true
		end
		if e.id <= upTo then
			table.insert(out, e)
		end
	end
	return if known then out else nil
end

return Returning
