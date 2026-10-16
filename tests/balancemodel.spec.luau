--!strict
-- The S83 world and boss model in tests/Balance.luau: boss schedule (control numbers on the data of 05b859d, renewed on
-- the data of S134 bosses 2.0; S87: reproduced with Balance.PICK_LIST_ORDER, the default is Logic/BossSchedule and
-- has its own spec), the opts.pick hook, the server constants the model mirrors, regions,
-- quests on their own level, potions on the S54 interval and the cave Elites from the real spawners.
local fs = require("@lune/fs")

local B = require("./Balance")
local Bosses = require("../src/shared/Data/Bosses")
local Exp = require("../src/shared/Logic/Exp")
local Monsters = require("../src/shared/Data/Monsters")
local Potions = require("../src/shared/Logic/Potions")
local Quests = require("../src/shared/Data/Quests")
local T = require("./Test")

T.describe("Balance model: boss schedule", function()
	-- Boss.Step every 0.05 s, list order (S83 rule), 600 s in one phase, nextGlobal from 4 s, first use 5 s, gap 2.2
	-- S134: the data of bosses 2.0 (the S83 rule still starves Morvane's ring and her new attacks)
	local CONTROL: { { string | number } } = {
		{ "grimrok", 1, "sweep", 7.4 },
		{ "grimrok", 1, "leap", 3.8 },
		{ "grimrok", 3, "sweep", 5.0 },
		{ "grimrok", 3, "leap", 3.4 },
		{ "grimrok", 3, "whirlwind", 3.3 },
		{ "morvane", 3, "shadowBoltFast", 8.8 },
		{ "morvane", 3, "curseField", 8.7 },
		{ "morvane", 3, "deathRing", 0 },
		{ "azgor", 3, "fireWave", 5.2 },
		{ "azgor", 3, "flameCleave", 5.1 },
		{ "azgor", 3, "meteor", 2.6 },
		{ "azgor", 3, "inferno", 2.5 },
		{ "vaelgrath", 3, "frostBreath", 4.7 },
		{ "vaelgrath", 3, "blizzard", 3.1 },
		{ "vaelgrath", 3, "glacialRing", 2.4 },
	}

	T.it("the S83 list order reproduces the control numbers (+-0.15 / min)", function()
		local listOrder = { pick = B.PICK_LIST_ORDER }
		for _, c in CONTROL do
			local def = Bosses.byId[c[1] :: string]
			local cad = B.bossCadence(def, c[2] :: number, listOrder)
			local got = cad.perMinute[c[3] :: string]
			if got == nil or math.abs(got - (c[4] :: number)) > 0.15 then
				error(`{c[1]} phase {c[2]} {c[3]}: {got} per minute, control {c[4]}`, 0)
			end
		end
		local grimrok = B.bossCadence(Bosses.byId.grimrok, 3, listOrder)
		T.expect(grimrok.casting).toBeBetween(0.42, 0.46) -- S134 (0.33-0.37 before)
		-- S134: the ground splitter takes a turn from the sweep in phase 1 too (1.0 before)
		T.expect(B.bossCadence(Bosses.byId.grimrok, 1, listOrder).rateShare.sweep).toBeBetween(0.95, 1)
	end)

	-- S93: Azgor's meteor every 18 s no longer starves the inferno in the list order; Morvane's ring stays the case
	T.it("opts.pick decides among the ready attacks (the default S87 rule gives the starved ring its turn)", function()
		local cad = B.bossCadence(Bosses.byId.morvane, 3)
		T.expect(cad.perMinute.deathRing > 0).toBe(true)
		T.expect(B.bossCadence(Bosses.byId.morvane, 3, { pick = B.PICK_LIST_ORDER }).perMinute.deathRing).toBe(0)
		local none = B.bossCadence(Bosses.byId.azgor, 3, {
			pick = function()
				return nil
			end,
		})
		T.expect(none.casting).toBe(0)
	end)

	-- S87: the gap and the hazard damage are read through Data/BossTuning (require); the ticks stay as text.
	T.it(
		"the server reads Data/BossTuning and Logic/BossSchedule (else fix Balance.HAZARDS / BOSS_GLOBAL_GAP)",
		function()
			local message = "zmieniono stałą bossa: popraw `Balance.HAZARDS` / `BOSS_GLOBAL_GAP`"
			local function has(path: string, text: string)
				if not string.find(fs.readFile(path), text, 1, true) then
					error(`{message} ({path}: "{text}")`, 0)
				end
			end
			has("src/server/Entities/Boss.luau", "BossTuning.globalGap")
			has("src/server/Entities/Boss.luau", "BossSchedule.pick(")
			has("src/server/Entities/BossScripts/azgor.luau", `local TICK = {B.HAZARDS.azgor.every}`)
			has("src/server/Entities/BossScripts/azgor.luau", "BossTuning.hazards.azgor.lava")
			has("src/server/Entities/BossScripts/vaelgrath.luau", `local STORM_TICK = {B.HAZARDS.vaelgrath.every}`)
			has("src/server/Entities/BossScripts/vaelgrath.luau", "BossTuning.hazards.vaelgrath.freezingStorm")
			T.expect(B.bossScriptConsts("vaelgrath").FLIGHT_SECONDS ~= nil).toBe(true)
		end
	)

	T.it("a boss fight has three phases, shield waves and a tank damage rate", function()
		local fight = B.bossFight("grimrok", B.team(3, 19))
		T.expect(#fight.phases).toBe(3)
		T.expect(fight.phases[1].shieldSeconds).toBe(0)
		T.expect(fight.phases[2].shieldSeconds > 0).toBe(true)
		T.expect(fight.tankDps > 0).toBe(true)
		T.expect(fight.potionHps > 0).toBe(true)
		local share = 0
		for _, phase in fight.phases do
			share += phase.share
		end
		T.expect(share).toBeNear(1, 1e-9)
	end)

	T.it("raid is per member: a class twice in the team (two Warriors) does not double its share", function()
		-- every member takes every `all` attack, so the Warrior / Mage ratio is one hit / HP over the other and does
		-- not depend on the team (team(5) has two Warriors, team(4) one)
		local five = B.bossFight("azgor", B.team(5, 69)).raid
		local four = B.bossFight("azgor", B.team(4, 69)).raid
		T.expect(five.Warrior > 0 and four.Warrior > 0).toBe(true)
		T.expect((five.Warrior / five.Mage) / (four.Warrior / four.Mage)).toBeNear(1, 1e-6)
	end)
end)

T.describe("Balance model: regions, quests, potions", function()
	T.it("kindAtRegion: a kind of regionAt(L) whose range holds L (or is nearest); below 20 kindAt", function()
		for L = 1, 19 do
			T.expect(B.kindAtRegion(L)).toBe(B.kindAt(L))
		end
		for L = 20, 100 do
			local kind = B.kindAtRegion(L)
			local def = Monsters.get(kind) :: any
			local r = B.regionAt(L)
			T.expect(def.region).toBe(r)
			local gap = math.max(def.levels.min - L, L - def.levels.max, 0)
			for _, id in B.outdoorKinds(r) do
				local other = Monsters.get(id) :: any
				T.expect(gap <= math.max(other.levels.min - L, L - other.levels.max, 0)).toBe(true)
			end
		end
	end)

	T.it(
		"questsAt: main quests 20-99 (+ bosses with opts.bosses) sum to Quests.Main; 1-19 match questRewards",
		function()
			local model, data = 0, 0
			for L = 20, 99 do
				local q = B.questsAt(L)
				model += q.main + B.questsAt(L, { bosses = true }).boss
			end
			for _, q in Quests.Main.list :: { any } do
				if q.level >= 20 and q.level <= 99 then
					data += q.reward.exp or 0
				end
			end
			T.expect(model).toBe(data)
			local spread, own = 0, 0
			for L = 1, 19 do
				spread += (B.questRewards(L))
				own += B.questsAt(L, { bosses = true }).exp
			end
			T.expect(own).toBeNear(spread, 1e-6 * spread)
		end
	)

	T.it("paceAt carries the quest EXP above a level's need to the next level", function()
		local band = B.paceBand("Warrior", 44, 46)
		local first = band.levels[1]
		T.expect(first.carryOut >= 0).toBe(true)
		T.expect(math.max(0, first.questExp - Exp.expToNext(44)) <= first.carryOut + 1e-9).toBe(true)
	end)

	T.it("potionsAt: nothing to heal, the S54 interval and the potion levels", function()
		T.expect(B.potionsAt("Warrior", 30, 0, 7).drinks).toBe(0)
		-- a potion drunk at once and one more every interval: 6 s at 45, 1.5 s at 19
		local big = { { quality = 1, heal = 1, price = 1, level = 1 } }
		local at45 = B.potionsAt("Warrior", 45, 0.9, 0, big)
		T.expect(at45.wait).toBeNear((at45.drinks - 1) * 6, 1e-6)
		local at19 = B.potionsAt("Warrior", 19, 0.9, 0, big)
		T.expect(at19.wait).toBeNear((at19.drinks - 1) * 1.5, 1e-6)
		-- a potion above the level is never chosen
		local list = {
			{ quality = 1, heal = 10, price = 1, level = 1 },
			{ quality = 9, heal = 1e9, price = 1, level = 50 },
		}
		T.expect(B.potionsAt("Warrior", 40, 0.9, 7, list).quality).toBe(1)
		T.expect(B.potionsAt("Warrior", 50, 0.9, 7, list).quality).toBe(9)
		T.expect(B.potionHps(40, list)).toBeNear(10 / Potions.interval(40), 1e-9)
		T.expect(Potions.interval(45)).toBeNear(6, 1e-9)
		-- S87: on the real data Great (4) from 45, Mighty (5) from 70 (more to heal than any drink and no time:
		-- the biggest allowed)
		T.expect(B.potionsAt("Warrior", 44, 50, 0).quality).toBe(3)
		T.expect(B.potionsAt("Warrior", 45, 50, 0).quality).toBe(4)
		T.expect(B.potionsAt("Warrior", 69, 50, 0).quality).toBe(4)
		T.expect(B.potionsAt("Warrior", 70, 50, 0).quality).toBe(5)
	end)

	T.it(
		"caveElites(meadows): pair share in 0-1, a pair costs more than one Elite, three beat an Elite II better",
		function()
			local caves = B.caveElites("meadows")
			T.expect(#caves > 0).toBe(true)
			for _, cave in caves do
				T.expect(cave.pairShare).toBeBetween(0, 1)
				for _, kind in cave.kinds do
					for _, f in kind.fights do
						T.expect(f.pair.hpLost > f.single.hpLost).toBe(true)
					end
				end
				for _, e in cave.elite2 do
					T.expect(e.byTeam[3].hpLost < e.byTeam[1].hpLost).toBe(true)
				end
			end
		end
	)
end)
