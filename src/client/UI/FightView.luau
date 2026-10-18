--!strict
-- After-fight meter on the client (S134f): checks the server's `FightSummary` / boss card payloads field by field
-- (rows, header, party loot) and writes the header line "Fight time 3:42 · Deaths: Ala, Olek · Dodged blows 14 / 17".
-- Used by the boss reward card (BossReward), the small card (FightCard) and the fight log window (FightLogWindow).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Text)

local FightView = {}

-- n = name, c = class, d = damage share 0..1, a = damage, h = healing, s = shields, t = taken, i = intercepted,
-- x = deaths, v = dodged, w = telegraphed blows aimed at the player (a..w since S134f; S60 rows have n, c, d, h, s, i).
export type Row = {
	n: string,
	c: string?,
	d: number,
	a: number?,
	h: number,
	s: number,
	t: number?,
	i: number?,
	x: number?,
	v: number?,
	w: number?,
}

export type Header = { time: number, deaths: { { n: string, at: number } }, dodged: number, aimed: number }

export type DropView = {
	mine: { { id: string, r: number, up: number?, n: number? } },
	party: { { n: string, id: string, r: number, up: number? } },
	more: number,
}

-- S149b: a world boss fight's standing (Logic/FightStats.place): place n of `of`, share 0..1.
export type Place = { n: number, of: number, pct: number }

export type Summary = {
	kind: string, -- "boss" | "elite2" | "invasion" | "worldboss"
	key: string,
	nameKey: string,
	outcome: string, -- "win" | "fail" | "wipe"
	header: Header,
	rows: { Row },
	drop: DropView?,
	place: Place?, -- S149b: only a world boss fight
	at: number, -- os.time() when it arrived
}

local MAX_ROWS = 5 -- a party

local function num(value: any): number?
	return if type(value) == "number" and value == value then value else nil
end

function FightView.rows(raw: any): { Row }?
	if type(raw) ~= "table" then
		return nil
	end
	local rows: { Row } = {}
	for _, row in raw do
		if #rows >= MAX_ROWS then
			break
		end
		if type(row) == "table" and type(row.n) == "string" then
			table.insert(rows, {
				n = row.n,
				c = if type(row.c) == "string" then row.c else nil,
				d = num(row.d) or 0,
				a = num(row.a),
				h = num(row.h) or 0,
				s = num(row.s) or 0,
				t = num(row.t),
				i = num(row.i),
				x = num(row.x),
				v = num(row.v),
				w = num(row.w),
			})
		end
	end
	return rows
end

function FightView.header(raw: any): Header?
	if type(raw) ~= "table" or num(raw.time) == nil then
		return nil
	end
	local deaths = {}
	if type(raw.deaths) == "table" then
		for _, death in raw.deaths do
			if type(death) == "table" and type(death.n) == "string" then
				table.insert(deaths, { n = death.n, at = num(death.at) or 0 })
			end
		end
	end
	return { time = num(raw.time) or 0, deaths = deaths, dodged = num(raw.dodged) or 0, aimed = num(raw.aimed) or 0 }
end

function FightView.drop(raw: any): DropView?
	if type(raw) ~= "table" then
		return nil
	end
	local mine, party = {}, {}
	if type(raw.mine) == "table" then
		for _, item in raw.mine do
			if type(item) == "table" and type(item.id) == "string" and num(item.r) then
				table.insert(mine, { id = item.id, r = item.r, up = num(item.up), n = num(item.n) })
			end
		end
	end
	if type(raw.party) == "table" then
		for _, item in raw.party do
			if type(item) == "table" and type(item.id) == "string" and type(item.n) == "string" and num(item.r) then
				table.insert(party, { n = item.n, id = item.id, r = item.r, up = num(item.up) })
			end
		end
	end
	return { mine = mine, party = party, more = num(raw.more) or 0 }
end

-- S149b: the standing of a world boss summary, or nil.
function FightView.place(raw: any): Place?
	if type(raw) ~= "table" then
		return nil
	end
	local n, of, pct = num(raw.n), num(raw.of), num(raw.pct)
	if not n or not of or n < 1 or of < n then
		return nil
	end
	return { n = n, of = of, pct = math.clamp(pct or 0, 0, 1) }
end

-- S149b: "Place 3 of 14 · share 9.5 %".
function FightView.placeLine(use: Fusion.Use, place: Place): string
	return Text.get(use, "fight.place", { n = place.n, of = place.of, pct = math.floor(place.pct * 1000 + 0.5) / 10 })
end

function FightView.summary(raw: any): Summary?
	if type(raw) ~= "table" or type(raw.kind) ~= "string" then
		return nil
	end
	local rows = FightView.rows(raw.rows)
	local header = FightView.header(raw)
	if not rows or not header then
		return nil
	end
	return {
		kind = raw.kind,
		key = if type(raw.key) == "string" then raw.key else "",
		nameKey = if type(raw.nameKey) == "string" then raw.nameKey else "",
		outcome = if type(raw.outcome) == "string" then raw.outcome else "win",
		header = header,
		rows = rows,
		drop = FightView.drop(raw.drop),
		place = FightView.place(raw.place),
		at = os.time(),
	}
end

-- "Fight time 3:42 · Deaths: Ala, Olek · Dodged blows 14 / 17" (the dodges only when a blow was aimed).
function FightView.headerLine(use: Fusion.Use, header: Header): string
	local parts = { Text.get(use, "fight.time", { time = Format.time(header.time) }) }
	if #header.deaths > 0 then
		local names = {}
		for _, death in header.deaths do
			table.insert(names, death.n)
		end
		table.insert(parts, Text.get(use, "fight.deaths", { names = table.concat(names, ", ") }))
	else
		table.insert(parts, Text.get(use, "fight.noDeaths"))
	end
	if header.aimed > 0 then
		table.insert(parts, Text.get(use, "fight.dodged", { n = header.dodged, of = header.aimed }))
	end
	return table.concat(parts, " · ")
end

-- The localized name of the fight's target (a boss, an Elite II, an Invasion).
function FightView.title(use: Fusion.Use, summary: Summary): string
	if summary.nameKey ~= "" then
		return Text.get(use, summary.nameKey)
	end
	return Text.get(use, `finder.kind.{summary.kind}`)
end

return FightView
