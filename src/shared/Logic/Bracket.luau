--!strict
-- A single elimination bracket (S130, DESIGN-17 §8): the Champion's Tournament. Pure, deterministic and serializable
-- (arrays, strings and numbers only), so the server keeps it in memory and a light copy (`view`) goes to the clients
-- through the runtime state branch `tourney`. Nothing here knows the game: players are keys ("<userId>_<slot>"),
-- `seeds` come sorted (the best first, Logic/Tourney.seedOrder).
--   * size: the smallest power of two >= the number of players; the empty places of the first round are byes, always
--     for the highest seeds (the standard seeding: 1 meets the last, the top seeds meet as late as possible);
--   * a match with a bye is decided at once (reason "bye"), its winner moves on;
--   * report(match, winner, "win" | "walkover"): the result of a fought match (the server's ArenaService match);
--   * withdraw(key): a player who is gone; a known opponent wins by walkover, an opponent still unknown wins it as soon
--     as known; two absent players: the higher seed goes on (absent, so it loses the next one by walkover), and a final
--     won by an absent player has no champion.
-- Places: 1 champion, 2 finalist, 3 both semifinal losers (no match for third place), a loser of round r of a bracket
-- of `size` shares place size / 2^r + 1 (quarterfinal 5, round of 16 9, round of 32 17).

export type Match = {
	id: number,
	round: number,
	a: string?,
	b: string?,
	winner: string?,
	reason: ("win" | "walkover" | "bye")?,
	field: number?,
}
export type Bracket = {
	size: number,
	rounds: number,
	seeds: { string },
	matches: { Match },
	absent: { [string]: boolean },
	eliminated: { [string]: number }, -- key -> the round it lost
}

local Bracket = {}

-- The smallest power of two >= max(n, 2).
function Bracket.size(n: number): number
	local size = 2
	while size < n do
		size *= 2
	end
	return size
end

-- The standard seeding of the first round: the seed number of every place (for 8: 1, 8, 4, 5, 2, 7, 3, 6), pairs
-- of neighbours meet; every pair sums to size + 1.
function Bracket.order(size: number): { number }
	local order = { 1 }
	while #order < size do
		local n = #order * 2
		local nextOrder = table.create(n, 0)
		for i, s in order do
			nextOrder[i * 2 - 1] = s
			nextOrder[i * 2] = n + 1 - s
		end
		order = nextOrder
	end
	return order
end

-- The id of the j-th match (1-based) of round `round`.
local function idOf(b: Bracket, round: number, j: number): number
	local id = 0
	local count = b.size // 2
	for _ = 1, round - 1 do
		id += count
		count //= 2
	end
	return id + j
end

-- (round, index in the round) of a match id.
local function placeOfId(b: Bracket, id: number): (number, number)
	local count = b.size // 2
	local first = 1
	for round = 1, b.rounds do
		if id < first + count then
			return round, id - first + 1
		end
		first += count
		count //= 2
	end
	error(`bracket: no match {id}`)
end

local function seedIndex(b: Bracket, key: string): number
	return table.find(b.seeds, key) or math.huge
end

-- The winner moves to its place in the next round (odd match = side a, even = side b).
local function promote(b: Bracket, m: Match)
	if m.round >= b.rounds or not m.winner then
		return
	end
	local _, j = placeOfId(b, m.id)
	local nextMatch = b.matches[idOf(b, m.round + 1, (j + 1) // 2)]
	if j % 2 == 1 then
		nextMatch.a = m.winner
	else
		nextMatch.b = m.winner
	end
end

local function decide(b: Bracket, m: Match, winner: string, reason: "win" | "walkover" | "bye")
	m.winner = winner
	m.reason = reason
	m.field = nil
	local loser = if m.a == winner then m.b else m.a
	if loser then
		b.eliminated[loser] = m.round
	end
	promote(b, m)
end

-- Decides every match whose players are known and one (or both) of them is absent; repeats until nothing changes.
local function settle(b: Bracket)
	local changed = true
	while changed do
		changed = false
		for _, m in b.matches do
			if m.winner == nil and m.a ~= nil and m.b ~= nil then
				local a, c = m.a :: string, m.b :: string
				local absA, absB = b.absent[a] == true, b.absent[c] == true
				if absA or absB then
					local winner: string
					if absA and absB then
						winner = if seedIndex(b, a) <= seedIndex(b, c) then a else c
					else
						winner = if absA then c else a
					end
					decide(b, m, winner, "walkover")
					changed = true
				end
			end
		end
	end
end

-- A new bracket of `seeds` (sorted, the best first; 2 or more distinct keys).
function Bracket.new(seeds: { string }): Bracket
	local n = #seeds
	if n < 2 then
		error("bracket needs 2+ players")
	end
	local size = Bracket.size(n)
	local rounds = 0
	local s = size
	while s > 1 do
		s //= 2
		rounds += 1
	end
	local b: Bracket = {
		size = size,
		rounds = rounds,
		seeds = table.clone(seeds),
		matches = {},
		absent = {},
		eliminated = {},
	}
	local id = 0
	local count = size // 2
	for round = 1, rounds do
		for _ = 1, count do
			id += 1
			table.insert(b.matches, { id = id, round = round })
		end
		count //= 2
	end
	local order = Bracket.order(size)
	for j = 1, size // 2 do
		local m = b.matches[j]
		local sa, sb = order[j * 2 - 1], order[j * 2]
		m.a = seeds[sa]
		m.b = seeds[sb]
	end
	for j = 1, size // 2 do
		local m = b.matches[j]
		if m.a ~= nil and m.b == nil then
			decide(b, m, m.a :: string, "bye")
		elseif m.b ~= nil and m.a == nil then
			decide(b, m, m.b :: string, "bye")
		end
	end
	settle(b)
	return b
end

-- Matches ready to be fought: both players known, no winner; in the order of rounds and ids.
function Bracket.ready(b: Bracket): { Match }
	local out: { Match } = {}
	for _, m in b.matches do
		if m.winner == nil and m.a ~= nil and m.b ~= nil then
			table.insert(out, m)
		end
	end
	return out
end

function Bracket.get(b: Bracket, matchId: number): Match?
	return b.matches[matchId]
end

-- The result of a fought match. Errors on a match without two players, a winner that is not one of them, or a match
-- already decided (the server never does that).
function Bracket.report(b: Bracket, matchId: number, winner: string, reason: "win" | "walkover")
	local m = b.matches[matchId]
	if not m then
		error(`bracket: no match {matchId}`)
	end
	if m.a == nil or m.b == nil then
		error(`bracket: match {matchId} has no pair yet`)
	end
	if m.winner ~= nil then
		error(`bracket: match {matchId} is decided`)
	end
	if winner ~= m.a and winner ~= m.b then
		error(`bracket: {winner} does not play match {matchId}`)
	end
	decide(b, m, winner, reason)
	settle(b)
end

-- A player who is gone (left the server, did not arrive).
function Bracket.withdraw(b: Bracket, key: string)
	if b.absent[key] then
		return
	end
	b.absent[key] = true
	settle(b)
end

-- The field a ready match is fought on (nil = none / over).
function Bracket.setField(b: Bracket, matchId: number, field: number?)
	local m = b.matches[matchId]
	if m and m.winner == nil then
		m.field = field
	end
end

local function final(b: Bracket): Match
	return b.matches[#b.matches]
end

function Bracket.done(b: Bracket): boolean
	return final(b).winner ~= nil
end

-- The winner of the final, nil while it is not decided or when the winner is absent.
function Bracket.champion(b: Bracket): string?
	local w = final(b).winner
	if w and not b.absent[w] then
		return w
	end
	return nil
end

-- The loser of the final (nil before it is decided).
function Bracket.finalist(b: Bracket): string?
	local m = final(b)
	if m.winner == nil then
		return nil
	end
	return if m.winner == m.a then m.b else m.a
end

-- The place range (from, to) shared by `place` ("5" = 5th to 8th).
function Bracket.rangeOf(place: number): (number, number)
	if place <= 2 then
		return place, place
	end
	return place, (place - 1) * 2
end

function Bracket.placeRange(_b: Bracket, place: number): (number, number)
	return Bracket.rangeOf(place)
end

-- The place of a player: 1 champion (an absent final winner: 2, no champion), 2 finalist, 3 semifinal losers,
-- size / 2^round + 1 for a loser of `round`; nil while the player still plays (or is not in the bracket).
function Bracket.placeOf(b: Bracket, key: string): number?
	local m = final(b)
	if m.winner ~= nil and m.winner == key then
		return if b.absent[key] then 2 else 1
	end
	local round = b.eliminated[key]
	if round == nil then
		return nil
	end
	return b.size // (2 ^ round) + 1
end

-- The rounds a player stood in a match (fought, a walkover or a bye) before the round it lost (or all, still in).
function Bracket.status(b: Bracket, key: string): "playing" | "out" | "champion"
	if Bracket.champion(b) == key then
		return "champion"
	end
	if b.eliminated[key] ~= nil or (Bracket.done(b) and final(b).winner == key) then
		return "out"
	end
	return "playing"
end

-- The next match of a player still in: the match without a winner in which it stands (nil = waiting for a pair or out).
function Bracket.matchOf(b: Bracket, key: string): Match?
	for _, m in b.matches do
		if m.winner == nil and (m.a == key or m.b == key) then
			return m
		end
	end
	return nil
end

-- A light copy for the clients (state branch `tourney.live.view`): rounds, matches, keys, winners, fields.
function Bracket.view(b: Bracket): any
	local matches = table.create(#b.matches)
	for _, m in b.matches do
		table.insert(matches, {
			id = m.id,
			round = m.round,
			a = m.a,
			b = m.b,
			winner = m.winner,
			reason = m.reason,
			field = m.field,
		})
	end
	return { size = b.size, rounds = b.rounds, seeds = table.clone(b.seeds), matches = matches }
end

return Bracket
