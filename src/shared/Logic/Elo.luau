--!strict
-- Elo rating of the ranked arena (DESIGN-17 §6, S126), pure. Numbers from Data/Arena.ELO. The rating moves only
-- with match results: no account, gear or purchase ever reaches these functions (tests/paywall.spec).

local Arena = require("../Data/Arena")

local ELO = Arena.ELO

local Elo = {}

-- Expected score of a player rated `r` against `opp` (0..1).
function Elo.expected(r: number, opp: number): number
	return 1 / (1 + 10 ^ ((opp - r) / ELO.scale))
end

-- K factor: kNew for the first ELO.newGames rated matches of the season, then k.
function Elo.k(played: number): number
	return if played < ELO.newGames then ELO.kNew else ELO.k
end

-- Rating change for `score` (1 win, 0.5 draw, 0 loss), rounded to a whole number (symmetric for equal ratings).
function Elo.delta(r: number, opp: number, score: number, k: number): number
	return math.floor(k * (score - Elo.expected(r, opp)) + 0.5)
end

-- The new rating, never below ELO.floor.
function Elo.apply(r: number, delta: number): number
	return math.max(ELO.floor, r + delta)
end

-- Rating of a side: the rounded mean (one fighter in 1v1; S128 teams use the same formula).
function Elo.sideRating(ratings: { number }): number
	if #ratings == 0 then
		return ELO.start
	end
	local sum = 0
	for _, r in ratings do
		sum += r
	end
	return math.floor(sum / #ratings + 0.5)
end

return Elo
