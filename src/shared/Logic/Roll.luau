--!strict
-- Fortune's dice (S70, ROZWOJ 9.4, 14.1): which faces a roll gives and how strong each one is.
-- Pure; the caller passes a Logic/Rng (the server keeps one module-level Rng.new(), tests a fixed seed).

local Rng = require("./Rng")

local Roll = {}

-- One face out of `count`, each with chance 1/count (exactly one draw).
function Roll.face(rng: Rng.Rng, count: number): number
	return rng:int(1, count)
end

-- A die roll: one face; with doublePct % chance also a second, different face (rollDouble).
function Roll.pick(rng: Rng.Rng, count: number, doublePct: number): { number }
	local first = Roll.face(rng, count)
	if count > 1 and doublePct > 0 and rng:chance(doublePct / 100) then
		local second = rng:int(1, count - 1)
		if second >= first then
			second += 1
		end
		return { first, second }
	end
	return { first }
end

-- Strength of a rolled or pointed face: 1 + boost / 100.
function Roll.strength(boost: number): number
	return 1 + boost / 100
end

-- Multiplier per face (0 = face not given). Dice: the picked faces at strength(boost), the rest 0.
-- Wheel (all = true): every face at 1 and the picked (pointed) face at strength(boost).
function Roll.multipliers(count: number, picked: { number }, all: boolean, boost: number): { number }
	local out: { number } = {}
	for i = 1, count do
		out[i] = if all then 1 else 0
	end
	for _, i in picked do
		if i >= 1 and i <= count then
			out[i] = Roll.strength(boost)
		end
	end
	return out
end

return Roll
