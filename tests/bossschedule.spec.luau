--!strict
-- S87 (balance plan D3, target G11): Logic/BossSchedule picks the boss attack in Entities/Boss.Step and in the
-- balance model (Balance.bossCadence); Data/BossTuning holds the constants moved out of Boss.luau and the scripts.
local fs = require("@lune/fs")

local B = require("./Balance")
local BossSchedule = require("../src/shared/Logic/BossSchedule")
local BossTuning = require("../src/shared/Data/BossTuning")
local Bosses = require("../src/shared/Data/Bosses")
local T = require("./Test")

local function attack(id: string, cooldown: number, phases: { number }?): BossSchedule.Attack
	return { id = id, cooldown = cooldown, phases = phases or { 1 } }
end

T.describe("BossSchedule (S87)", function()
	T.it("pick takes the biggest overdue / cooldown ratio, not the oldest nextAttack", function()
		local a = attack("a", 20)
		local b = attack("b", 4)
		-- a waits 4 s of 20 (0.2), b waits 2 s of 4 (0.5): b wins although a became ready first
		local next = { a = 6, b = 8 }
		T.expect(BossSchedule.pick({ a, b }, 10, next)).toBe(b)
		-- a waits 12 s of 20 (0.6) > b 0.5
		T.expect(BossSchedule.pick({ a, b }, 10, { a = -2, b = 8 })).toBe(a)
	end)

	T.it("ties go to list order, an empty list gives nil, a missing nextAttack counts as 0", function()
		local a = attack("a", 5)
		local b = attack("b", 10)
		T.expect(BossSchedule.pick({ a, b }, 10, { a = 5, b = 0 })).toBe(a) -- 1.0 vs 1.0
		T.expect(BossSchedule.pick({ b, a }, 10, { a = 5, b = 0 })).toBe(b)
		T.expect(BossSchedule.pick({}, 10, {})).toBeNil()
		-- b has no entry: (10 - 0) / 10 = 1.0; a: (10 - 8) / 5 = 0.4
		T.expect(BossSchedule.pick({ a, b }, 10, { a = 8 })).toBe(b)
	end)

	T.it("ready keeps list order, the phase and the cooldown", function()
		local a = attack("a", 5, { 1, 2 })
		local b = attack("b", 5, { 3 })
		local c = attack("c", 5, { 1 })
		local ready = BossSchedule.ready({ a, b, c }, 1, 10, { a = 9, c = 11 })
		T.expect(#ready).toBe(1)
		T.expect(ready[1]).toBe(a)
		T.expect(#BossSchedule.ready({ a, b, c }, 1, 11, { a = 9, c = 11 })).toBe(2)
		T.expect(#BossSchedule.ready({ a, b, c }, 2, 0, {})).toBe(1)
		T.expect(#BossSchedule.ready({ b }, 1, 100, {})).toBe(0)
	end)

	T.it("G11: every attack of every phase of the four bosses gets at least half its rate; inferno flies", function()
		for _, id in { "grimrok", "morvane", "azgor", "vaelgrath" } do
			local def = Bosses.byId[id]
			for phase = 1, 3 do
				local cad = B.bossCadence(def, phase)
				for attackId, share in cad.rateShare do
					if share < 0.5 then
						error(`{id} phase {phase} {attackId}: {share} of its rate (G11 >= 0.5)`, 0)
					end
				end
			end
		end
		T.expect(B.bossCadence(Bosses.byId.azgor, 3).perMinute.inferno > 2).toBe(true)
	end)

	-- Control numbers of the default rule (S87; +-0.15 / min): 600 s in one phase, 0.05 s step, first use 5 s.
	T.it("the default rule reproduces the S87 control numbers (+-0.15 / min)", function()
		local CONTROL: { { string | number } } = {
			{ "grimrok", 1, "sweep", 7.5 },
			{ "grimrok", 1, "leap", 3.7 },
			{ "grimrok", 3, "sweep", 4.7 },
			{ "grimrok", 3, "leap", 4.6 },
			{ "grimrok", 3, "whirlwind", 4.6 },
			-- S92: Morvane's curse field every 6.5 s (was 11; 8.0 / 4.0 / 4.0 before)
			{ "morvane", 3, "shadowBoltFast", 8.5 },
			{ "morvane", 3, "curseField", 5.7 },
			{ "morvane", 3, "deathRing", 2.8 },
			-- S93: Azgor's meteor every 18 s (was 10; 4.5 / 4.4 / 4.4 / 2.9 before)
			{ "azgor", 3, "fireWave", 5.5 },
			{ "azgor", 3, "flameCleave", 5.4 },
			{ "azgor", 3, "meteor", 2.7 },
			{ "azgor", 3, "inferno", 2.8 },
			{ "vaelgrath", 3, "frostBreath", 4.1 },
			{ "vaelgrath", 3, "wingBuffet", 4.0 },
			{ "vaelgrath", 3, "tailSwipe", 4.0 },
			{ "vaelgrath", 3, "blizzard", 2.1 },
			{ "vaelgrath", 3, "glacialRing", 2.1 },
		}
		for _, c in CONTROL do
			local cad = B.bossCadence(Bosses.byId[c[1] :: string], c[2] :: number)
			local got = cad.perMinute[c[3] :: string]
			if got == nil or math.abs(got - (c[4] :: number)) > 0.15 then
				error(`{c[1]} phase {c[2]} {c[3]}: {got} per minute, control {c[4]}`, 0)
			end
		end
		-- the S83 list order stays reproducible through Balance.PICK_LIST_ORDER
		local old = B.bossCadence(Bosses.byId.grimrok, 3, { pick = B.PICK_LIST_ORDER })
		T.expect(old.perMinute.sweep).toBeNear(6.4, 0.15)
	end)

	-- S93: Azgor's lava 0.7 -> 2.2 (one tick ~20 % of a level 70 Mage after atkMul 0.36). S94: Vaelgrath's storm
	-- 1.4 -> 3.9 (one tick ~38 % of a level 100 Mage after atkMul 0.38)
	T.it("BossTuning keeps the values moved out of the server (2.2 / 2.2 / 3.9) and the model reads them", function()
		T.expect(BossTuning.globalGap).toBe(2.2)
		T.expect(BossTuning.hazards.azgor.lava).toBe(2.2)
		T.expect(BossTuning.hazards.vaelgrath.freezingStorm).toBe(3.9)
		T.expect(B.BOSS_GLOBAL_GAP).toBe(BossTuning.globalGap)
		T.expect(B.HAZARDS.azgor.damage).toBe(BossTuning.hazards.azgor.lava)
		T.expect(B.HAZARDS.vaelgrath.damage).toBe(BossTuning.hazards.vaelgrath.freezingStorm)
		-- S94 (B1b): the storm's tick and the flight come from the script's text, like the wiki's scriptConsts
		local consts = B.bossScriptConsts("vaelgrath")
		T.expect(B.HAZARDS.vaelgrath.every).toBe(consts.STORM_TICK)
		T.expect(consts.FLIGHT_SECONDS).toBe(12)
	end)

	T.it("the server reads BossSchedule and BossTuning; the wiki's script constants stay as text", function()
		local function has(path: string, text: string)
			if not string.find(fs.readFile(path), text, 1, true) then
				error(`{path}: missing "{text}"`, 0)
			end
		end
		has("src/server/Entities/Boss.luau", "BossTuning.globalGap")
		has("src/server/Entities/Boss.luau", "BossSchedule.pick(")
		has("src/server/Entities/BossScripts/azgor.luau", "local TICK = 1")
		has("src/server/Entities/BossScripts/azgor.luau", "BossTuning.hazards.azgor.lava")
		has("src/server/Entities/BossScripts/vaelgrath.luau", "local STORM_TICK = 3")
		has("src/server/Entities/BossScripts/vaelgrath.luau", "BossTuning.hazards.vaelgrath.freezingStorm")
		-- S94 (C7): the flight lasts max(flight, shield wave) and landing keeps a living wave's shield
		has("src/server/Entities/BossScripts/vaelgrath.luau", "#boss.shielded > 0")
		has("src/server/Entities/BossScripts/vaelgrath.luau", "flightUntil")
		T.expect(string.find(fs.readFile("src/server/Entities/Boss.luau"), "local GLOBAL_GAP", 1, true)).toBeNil()
	end)
end)
