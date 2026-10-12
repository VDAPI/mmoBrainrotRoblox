--!strict
local PartyBuffRules = require("./PartyBuffRules")
local Rng = require("../src/shared/Logic/Rng")
local Roll = require("../src/shared/Logic/Roll")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local N = 3000

T.describe("Roll (S70)", function()
	T.it("one face, uniform", function()
		-- one Rng for every draw: the first draw of many small seeds is nearly always face 1 (Logic/Rng)
		local rng = Rng.new(12345)
		local counts = { 0, 0, 0 }
		for _ = 1, N do
			local face = Roll.face(rng, 3)
			T.expect(face >= 1 and face <= 3 and face == math.floor(face)).toBe(true)
			counts[face] += 1
		end
		for i = 1, 3 do
			T.expect(math.abs(counts[i] / N - 1 / 3) < 0.05).toBe(true)
		end
		local doubles = 0
		for _ = 1, N do
			T.expect(#Roll.pick(rng, 3, 0)).toBe(1)
			local two = Roll.pick(rng, 3, 100)
			T.expect(#two == 2 and two[1] ~= two[2]).toBe(true)
			if #Roll.pick(rng, 3, 30) == 2 then
				doubles += 1
			end
		end
		T.expect(math.abs(doubles / N - 0.3) < 0.05).toBe(true)
		T.expect(#Roll.pick(rng, 1, 100)).toBe(1)
		local a, b = Rng.new(7), Rng.new(7)
		for _ = 1, 50 do
			T.expect(Roll.face(a, 3)).toBe(Roll.face(b, 3))
		end
	end)

	T.it("multipliers", function()
		T.expect(Roll.strength(0)).toBe(1)
		T.expect(Roll.strength(50)).toBe(1.5)
		T.expect(Roll.strength(100)).toBe(2)
		T.expect(Roll.multipliers(3, { 2 }, false, 0)).toEqual({ 0, 1, 0 })
		T.expect(Roll.multipliers(3, { 2 }, true, 50)).toEqual({ 1, 1.5, 1 })
		T.expect(Roll.multipliers(3, { 1, 3 }, false, 0)).toEqual({ 1, 0, 1 })
	end)

	T.it("dice data: three faces, cooldown >= duration", function()
		local CATEGORY = { blade = "allyCrit", wind = "allyHaste" }
		for _, id in { "fortuneDice", "wheelOfFortune" } do
			local skill = SkillData.byId[id]
			local seen: { [string]: number } = {}
			local misfortune = false
			for _, effect in skill.effects or {} do
				if effect.face then
					seen[effect.face] = (seen[effect.face] or 0) + 1
					T.expect({ id, effect.face, effect.category, effect.target })
						.toEqual({ id, effect.face, CATEGORY[effect.face], "allies" })
				elseif effect.kind == "misfortune" then
					misfortune = effect.target == "enemy" and effect.category == "enemyMiss"
				end
			end
			T.expect({ id, seen }).toEqual({ id, { blade = 1, wind = 1, spring = 1 } })
			T.expect({ id, misfortune }).toEqual({ id, id == "wheelOfFortune" })
			for _, rank in { 1, 5, 10 } do
				for _, five in { "a", "b" } do
					for _, ten in { "a", "b" } do
						local choices = { [`{id}:5`] = five, [`{id}:10`] = ten }
						local def = Skills.effective(skill, rank, choices, nil, true)
						local cooldown = Skills.cooldown(def, rank, 0)
						for _, effect in def.effects or {} do
							if effect.face then
								local duration = Skills.scaled(def, effect.duration, rank)
								T.expect({ id, rank, five, ten, cooldown >= duration })
									.toEqual({ id, rank, five, ten, true })
							end
						end
					end
				end
			end
		end
		for _, id in { "fortuneDice", "wheelOfFortune", "sanctuary", "guardianAngel", "prayer" } do
			T.expect({ id, PartyBuffRules.check(SkillData.byId[id]) }).toEqual({ id, {} })
		end
	end)
end)

return nil
