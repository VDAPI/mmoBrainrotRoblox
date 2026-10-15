--!strict
-- Champion's Tournament rules (S130, DESIGN-17 §8), shared by the server (TourneyService) and the arena window. Pure:
-- every function takes the time it works on (servers and clients pass Util/Clock.now, so /time moves the tournament
-- too). The tournament is the "tourney" slot of Data/ScheduledEvents (Saturday 19:00 UTC = the bracket start); its
-- phases are offsets of Data/Arena.TOURNEY.window:
--   idle      before the signups
--   signup    [start + open, start + close)     18:00-18:50 UTC
--   closed    [start + close, start + organize)  18:50-18:55
--   inviting  [start + organize, start)          18:55-19:00: the organizer reserves the servers, invitations
--   running   [start, start + duration)          the brackets
-- No purchases, no account, no VIP: the list, the seeding and the rewards depend only on the character's level (the
-- bracket), its 1v1 rating of the season and the time of its signup (DESIGN-17 §0.2, tests/paywall.spec).

local Arena = require("../Data/Arena")
local ArenaRules = require("./ArenaRules")
local Bracket = require("./Bracket")
local Schedule = require("./Schedule")
local ScheduledEvents = require("../Data/ScheduledEvents")

export type Phase = "idle" | "signup" | "closed" | "inviting" | "running"
-- A signup: the character key "<userId>_<slot>", the 1v1 rating at the signup, the unix time of the signup, the
-- character's name and class (shown in the bracket).
export type Entry = { key: string, rating: number, t: number, name: string, class: string }
export type Rewards = {
	shards: number,
	tokens: number,
	title: string?,
	titleDays: number?,
	cosmetics: { string },
}
export type Times = { open: number, close: number, organize: number, start: number, ends: number }

local RULES = Arena.TOURNEY
local DEF = ScheduledEvents.get("tourney") :: ScheduledEvents.EventDef

local Tourney = {}

Tourney.RULES = RULES
Tourney.DEF = DEF

-- The start of the current or the next tournament (UTC): the start of the occurrence running now, else the next one
-- (its signups are always before it). 0 when the slot is disabled.
function Tourney.startAt(now: number): number
	local current = Schedule.current(DEF, now)
	if current then
		return current.startsAt
	end
	local nextOcc = Schedule.next(DEF, now)
	return if nextOcc then nextOcc.startsAt else 0
end

-- The id of a tournament: the UTC date of its start ("YYYYMMDD", the same on every server).
function Tourney.idOf(startAt: number): string
	return Schedule.idOf(DEF, startAt)
end

-- The phase boundaries of the tournament starting at `startAt` (absolute unix seconds).
function Tourney.times(startAt: number): Times
	local w = RULES.window
	return {
		open = startAt + w.open,
		close = startAt + w.close,
		organize = startAt + w.organize,
		start = startAt,
		ends = startAt + DEF.duration,
	}
end

-- S131: the phase at `now` of the tournament starting at `startAt` (a scheduled or a forced one).
function Tourney.phaseFor(startAt: number, now: number): Phase
	local t = Tourney.times(startAt)
	if now >= t.start and now < t.ends then
		return "running"
	elseif now >= t.organize and now < t.start then
		return "inviting"
	elseif now >= t.close and now < t.organize then
		return "closed"
	elseif now >= t.open and now < t.close then
		return "signup"
	end
	return "idle"
end

-- (phase, startAt) at `now`.
function Tourney.phaseAt(now: number): (Phase, number)
	local startAt = Tourney.startAt(now)
	if startAt == 0 then
		return "idle", 0
	end
	return Tourney.phaseFor(startAt, now), startAt
end

-- S131 (admin /tourney force): a real tournament forced on every server, starting `minutes` after `now` (whole
-- minutes, UTC). Its signups open at once when the start is closer than the usual opening. The id is the date, "f"
-- and the start time ("YYYYMMDDfHHMM"): never the id of a scheduled tournament (the date alone), no "_" (server refs
-- split at the first "_"), the date first (the Hall of Fame board reads it).
function Tourney.forceStart(now: number, minutes: number): number
	return (math.floor(now / 60) + math.max(1, math.floor(minutes))) * 60
end

function Tourney.forcedId(startAt: number): string
	local day = math.floor(startAt / 86400)
	local secs = startAt - day * 86400
	return `{Schedule.dateKey(startAt)}f{string.format("%02d%02d", secs // 3600, (secs % 3600) // 60)}`
end

-- The minutes `/tourney force` accepts: the signups must stay open a while before they close (window.close).
function Tourney.forceMinutesOk(minutes: number): boolean
	return minutes == math.floor(minutes) and minutes * 60 > -RULES.window.close and minutes <= 180
end

-- The moment the phase at `now` ends (the next boundary).
function Tourney.phaseEnds(phase: Phase, startAt: number): number
	local t = Tourney.times(startAt)
	if phase == "idle" then
		return t.open
	elseif phase == "signup" then
		return t.close
	elseif phase == "closed" then
		return t.organize
	elseif phase == "inviting" then
		return t.start
	end
	return t.ends
end

-- The arena bracket of a level (Logic/ArenaRules, the same as the ranked arena); nil below the first bracket. The
-- bracket of a signup is the level at the signup and stays for the whole tournament.
function Tourney.bracketOf(level: number): string?
	return ArenaRules.bracketOf(level)
end

-- "20–39" of a bracket id (the id itself when unknown).
function Tourney.rangeOf(bracket: string): string
	local b = Arena.bracket(bracket)
	return if b then `{b.min}–{b.max}` else bracket
end

-- Whether a character may sign up: level (Locale key tourney.error.level), the phase (tourney.error.closed), already
-- signed for this tournament (tourney.error.already). A signup of an older tournament does not count.
function Tourney.canSignup(
	input: { level: number, phase: Phase, signed: { id: string }?, id: string }
): (boolean, string?)
	if Tourney.bracketOf(input.level) == nil then
		return false, "tourney.error.level"
	end
	if input.phase ~= "signup" then
		return false, "tourney.error.closed"
	end
	if input.signed ~= nil and input.signed.id == input.id then
		return false, "tourney.error.already"
	end
	return true, nil
end

-- Whether a character may withdraw: only in the signup phase and only from this tournament.
function Tourney.canUnsign(input: { phase: Phase, signed: { id: string }?, id: string }): (boolean, string?)
	if input.phase ~= "signup" then
		return false, "tourney.error.closed"
	end
	if input.signed == nil or input.signed.id ~= input.id then
		return false, "tourney.error.notSigned"
	end
	return true, nil
end

-- The sort key of a signup (ascending = the better): the higher rating first, then the earlier signup. Rating and
-- seconds are floored and clamped to 0..9999.
function Tourney.sortKey(rating: number, secondsSinceOpen: number): number
	local r = math.clamp(math.floor(rating), 0, 9999)
	local t = math.clamp(math.floor(secondsSinceOpen), 0, 9999)
	return (9999 - r) * 10000 + t
end

-- Sorted copies of the entries (the best first; ties of the sort key by the key, so every server agrees). The time
-- counts from `openAt` (default: the earliest signup).
local function sorted(entries: { Entry }, openAt: number?): { Entry }
	local from = openAt
	if from == nil then
		local min = math.huge
		for _, e in entries do
			min = math.min(min, e.t)
		end
		from = if min == math.huge then 0 else min
	end
	local base = from :: number
	local list = table.clone(entries)
	local keys: { [string]: number } = {}
	for _, e in list do
		keys[e.key] = Tourney.sortKey(e.rating, e.t - base)
	end
	table.sort(list, function(x: Entry, y: Entry): boolean
		local kx, ky = keys[x.key], keys[y.key]
		if kx ~= ky then
			return kx < ky
		end
		return x.key < y.key
	end)
	return list
end

-- Who gets in: the first `cap` by the sort key; the rest is the overflow; the third result is the rating of the last
-- one taken when there was an overflow (the threshold shown to the others).
function Tourney.pick(entries: { Entry }, cap: number, openAt: number?): ({ Entry }, { Entry }, number?)
	local list = sorted(entries, openAt)
	local picked: { Entry } = {}
	local overflow: { Entry } = {}
	for i, e in list do
		if i <= cap then
			table.insert(picked, e)
		else
			table.insert(overflow, e)
		end
	end
	local threshold = if #overflow > 0 and #picked > 0 then math.floor(picked[#picked].rating) else nil
	return picked, overflow, threshold
end

-- The seeding of the bracket (Logic/Bracket.new): keys by rating, ties by the earlier signup. Nothing else is read.
function Tourney.seedOrder(entries: { Entry }, openAt: number?): { string }
	local out: { string } = {}
	for _, e in sorted(entries, openAt) do
		table.insert(out, e.key)
	end
	return out
end

-- The reward of a place (Data/Arena.TOURNEY.rewards; 3 = both semifinal losers) plus the participation tokens when
-- the player showed up. `showed == false` (lost by walkover for not being there before any match) gets nothing.
function Tourney.rewardsFor(place: number?, showed: boolean): Rewards
	local out: Rewards = { shards = 0, tokens = 0, title = nil, titleDays = nil, cosmetics = {} }
	if not showed then
		return out
	end
	out.tokens = RULES.participantTokens
	if place == nil then
		return out
	end
	for _, r in RULES.rewards do
		if r.place == place then
			out.shards = r.shards or 0
			out.title = r.title
			out.titleDays = r.titleDays
			out.cosmetics = if r.cosmetics then table.clone(r.cosmetics) else {}
		end
	end
	return out
end

-- Whether the saved signup belongs to a tournament that is over (the server clears it on entering the world).
-- `forced` is the forced tournament (/tourney force) this server knows, until its end: its signup is not stale.
function Tourney.isStale(signed: { id: string }?, now: number, forced: { id: string, startAt: number }?): boolean
	if signed == nil then
		return false
	end
	if forced and signed.id == forced.id and now < Tourney.times(forced.startAt).ends then
		return false
	end
	return signed.id ~= Tourney.idOf(Tourney.startAt(now))
end

-- The Locale key (and arguments) of a place: tourney.place.1 / .2 / .3, else the range ("5–8.").
function Tourney.placeKey(place: number): (string, { [string]: any }?)
	if place >= 1 and place <= 3 then
		return `tourney.place.{place}`, nil
	end
	local from, to = Bracket.rangeOf(math.max(4, place))
	return "tourney.place.range", { from = from, to = to }
end

-- The same as a Locale argument of a server message ("@key" or { key, args }).
function Tourney.placeArg(place: number): any
	local key, args = Tourney.placeKey(place)
	if args == nil then
		return "@" .. key
	end
	return { key = key, args = args }
end

-- The Locale key of a round of a bracket with `rounds` rounds ("tourney.round.final", ".semi", ".quarter", ".r8",
-- ".r16"); nil for earlier rounds (shown as "Round r of n").
function Tourney.roundKey(round: number, rounds: number): string?
	local fromEnd = rounds - round
	if fromEnd == 0 then
		return "tourney.round.final"
	elseif fromEnd == 1 then
		return "tourney.round.semi"
	elseif fromEnd == 2 then
		return "tourney.round.quarter"
	elseif fromEnd == 3 then
		return "tourney.round.r8"
	elseif fromEnd == 4 then
		return "tourney.round.r16"
	end
	return nil
end

-- "HH:MM" of a unix time in UTC (announcements; the window shows the player's local time itself).
function Tourney.clockUtc(t: number): string
	local s = math.floor(t) % 86400
	return string.format("%02d:%02d", s // 3600, (s % 3600) // 60)
end

return Tourney
