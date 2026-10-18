--!strict
-- After-fight meter (S134f, DESIGN §16 / §17): who dealt, healed, shielded, took and intercepted how much in one fight
-- (a boss, an Elite II, an Invasion), deaths, and telegraphed blows aimed at / dodged by each player. Pure; the server
-- (FightLogService) books numbers from combat signals and builds the rows for each participant with HIS party only
-- (strangers hitting the same Elite II are not shown and do not count in the damage share). Rows keep the S60
-- SummaryRow fields (n, c, d, h, s, i) first, so the boss reward card reads old and new rows alike.

local FightStats = {}

export type Kind = "boss" | "elite2" | "invasion" | "worldboss" -- S149: the world boss (WorldBossService)
export type Outcome = "win" | "fail" | "wipe"
export type Field = "dmg" | "heal" | "shield" | "taken" | "intercept" | "deaths" | "dodged" | "aimed"

export type Stat = {
	dmg: number,
	heal: number,
	shield: number,
	taken: number,
	intercept: number,
	deaths: number,
	dodged: number,
	aimed: number,
}

export type Death = { id: number, n: string, at: number } -- at = seconds since the start

export type Fight = {
	kind: Kind,
	key: string,
	startedAt: number,
	endedAt: number?,
	outcome: Outcome?,
	stats: { [number]: Stat }, -- by user id
	deaths: { Death },
}

-- One table row (short keys: it travels to the client). d = share of the party's damage 0..1, a = damage, h = healing,
-- s = shields, t = taken, i = intercepted, x = deaths, v = dodged, w = telegraphed blows aimed at the player.
export type Row = {
	n: string,
	c: string?,
	d: number,
	a: number,
	h: number,
	s: number,
	t: number,
	i: number,
	x: number,
	v: number,
	w: number,
}

export type Summary = {
	time: number, -- seconds
	outcome: Outcome?,
	deaths: { { n: string, at: number } },
	dodged: number,
	aimed: number,
}

local FIELDS: { Field } = { "dmg", "heal", "shield", "taken", "intercept", "deaths", "dodged", "aimed" }
FightStats.FIELDS = FIELDS

local function emptyStat(): Stat
	return { dmg = 0, heal = 0, shield = 0, taken = 0, intercept = 0, deaths = 0, dodged = 0, aimed = 0 }
end

function FightStats.new(kind: Kind, key: string, startedAt: number): Fight
	return { kind = kind, key = key, startedAt = startedAt, stats = {}, deaths = {} }
end

-- Whether the user already has a line (took part).
function FightStats.has(fight: Fight, userId: number): boolean
	return fight.stats[userId] ~= nil
end

-- Makes sure the user has a line (joined without numbers yet: healed a fighter, was aimed at).
function FightStats.join(fight: Fight, userId: number)
	if fight.stats[userId] == nil then
		fight.stats[userId] = emptyStat()
	end
end

function FightStats.add(fight: Fight, userId: number, field: Field, amount: number)
	if amount ~= amount or amount <= 0 or fight.endedAt ~= nil then
		return
	end
	FightStats.join(fight, userId)
	local stat = fight.stats[userId] :: any
	stat[field] += amount
end

function FightStats.death(fight: Fight, userId: number, name: string, at: number)
	if fight.endedAt ~= nil then
		return
	end
	FightStats.join(fight, userId)
	fight.stats[userId].deaths += 1
	table.insert(fight.deaths, { id = userId, n = name, at = math.max(0, at - fight.startedAt) })
end

-- A boss walking home after a leash: the numbers start over (its damage record is cleared too); deaths stay.
function FightStats.reset(fight: Fight)
	for _, stat in fight.stats do
		local deaths = stat.deaths
		for _, field in FIELDS do
			(stat :: any)[field] = 0
		end
		stat.deaths = deaths
	end
end

function FightStats.finish(fight: Fight, endedAt: number, outcome: Outcome)
	if fight.endedAt == nil then
		fight.endedAt = endedAt
		fight.outcome = outcome
	end
end

-- User ids with a line, ascending.
function FightStats.participants(fight: Fight): { number }
	local out = {}
	for id in fight.stats do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

local function inParty(partyIds: { number }, id: number): boolean
	return table.find(partyIds, id) ~= nil
end

-- Rows of the members of `partyIds` who took part, sorted by damage, then healing (then name). `d` is the share of the
-- party's damage only.
function FightStats.rows(
	fight: Fight,
	partyIds: { number },
	names: { [number]: string },
	classes: { [number]: string }
): { Row }
	local total = 0
	for id, stat in fight.stats do
		if inParty(partyIds, id) then
			total += stat.dmg
		end
	end
	local rows: { Row } = {}
	for _, id in partyIds do
		local stat = fight.stats[id]
		if stat then
			table.insert(rows, {
				n = names[id] or tostring(id),
				c = classes[id],
				d = if total > 0 then math.floor(stat.dmg / total * 10000 + 0.5) / 10000 else 0,
				a = math.floor(stat.dmg),
				h = math.floor(stat.heal),
				s = math.floor(stat.shield),
				t = math.floor(stat.taken),
				i = math.floor(stat.intercept),
				x = stat.deaths,
				v = stat.dodged,
				w = stat.aimed,
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.a ~= b.a then
			return a.a > b.a
		end
		if a.h ~= b.h then
			return a.h > b.h
		end
		return a.n < b.n
	end)
	return rows
end

-- The header of the party's summary: fight time, deaths in order, dodged / aimed telegraphed blows.
function FightStats.summary(fight: Fight, partyIds: { number }, now: number?): Summary
	local ended = fight.endedAt or now or fight.startedAt
	local deaths = {}
	for _, death in fight.deaths do
		if inParty(partyIds, death.id) then
			table.insert(deaths, { n = death.n, at = math.floor(death.at + 0.5) })
		end
	end
	local dodged, aimed = 0, 0
	for _, id in partyIds do
		local stat = fight.stats[id]
		if stat then
			dodged += stat.dodged
			aimed += stat.aimed
		end
	end
	return {
		time = math.max(0, math.floor(ended - fight.startedAt + 0.5)),
		outcome = fight.outcome,
		deaths = deaths,
		dodged = dodged,
		aimed = aimed,
	}
end

-- One dropped item on a summary (short keys): item id, rarity, upgrade, stack size.
export type DropItem = { id: string, r: number, up: number?, n: number? }
export type DropView = {
	mine: { DropItem },
	party: { { n: string, id: string, r: number, up: number? } },
	more: number,
}

-- "Party loot" as one player sees it: all his own items, the others' items from `minRarity` up (name + item) and
-- only the count of the rest.
function FightStats.dropView(
	mine: { DropItem }?,
	others: { { n: string, items: { DropItem } } },
	minRarity: number
): DropView
	local party = {}
	local more = 0
	for _, other in others do
		for _, item in other.items do
			if item.r >= minRarity then
				table.insert(party, { n = other.n, id = item.id, r = item.r, up = item.up })
			else
				more += 1
			end
		end
	end
	return { mine = mine or {}, party = party, more = more }
end

-- Whether the party's summary is worth sending: the fight lasted at least `minSeconds` and the party dealt damage.
function FightStats.worthSending(fight: Fight, partyIds: { number }, minSeconds: number, now: number?): boolean
	local ended = fight.endedAt or now or fight.startedAt
	if ended - fight.startedAt < minSeconds then
		return false
	end
	for _, id in partyIds do
		local stat = fight.stats[id]
		if stat and stat.dmg > 0 then
			return true
		end
	end
	return false
end

return FightStats
