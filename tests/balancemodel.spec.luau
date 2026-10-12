--!strict
-- The S83 world and boss model in tests/Balance.luau: boss schedule (control numbers on the data of 05b859d, the
-- attacks did not change since), the opts.pick hook for S87, the server constants the model mirrors, regions,
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
	-- Boss.Step every 0.05 s, list order, 600 s in one phase, nextGlobal from 4 s, first use 5 s, GLOBAL_GAP 2.2
	local CONTROL: { { string | number } } = {
		{ "grimrok", 1, "sweep", 7.5 },
		{ "grimrok", 1, "leap", 3.7 },
		{ "grimrok", 3, "sweep", 6.4 },
		{ "grimrok", 3, "leap", 4.3 },
		{ "grimrok", 3, "whirlwind", 4.2 },
		{ "morvane", 3, "shadowBoltFast", 8.0 },
		{ "morvane", 3, "curseField", 4.0 },
		{ "morvane", 3, "deathRing", 4.0 },
		{ "azgor", 3, "fireWave", 5.6 },
		{ "azgor", 3, "flameCleave", 5.6 },
		{ "azgor", 3, "meteor", 5.5 },
		{ "azgor", 3, "inferno", 0 },
		{ "vaelgrath", 3, "frostBreath", 5.5 },
		{ "vaelgrath", 3, "wingBuffet", 3.6 },
		{ "vaelgrath", 3, "tailSwipe", 3.6 },
		{ "vaelgrath", 3, "blizzard", 1.8 },
		{ "vaelgrath", 3, "glacialRing", 1.8 },
	}

	T.it("the default choice reproduces the control numbers (+-0.15 / min)", function()
		for _, c in CONTROL do
			local def = Bosses.byId[c[1] :: string]
			local cad = B.bossCadence(def, c[2] :: number)
			local got = cad.perMinute[c[3] :: string]
			if got == nil or math.abs(got - (c[4] :: number)) > 0.15 then
				error(`{c[1]} phase {c[2]} {c[3]}: {got} per minute, control {c[4]}`, 0)
			end
		end
		local grimrok = B.bossCadence(Bosses.byId.grimrok, 3)
		T.expect(grimrok.casting).toBeBetween(0.33, 0.37)
		T.expect(B.bossCadence(Bosses.byId.grimrok, 1).rateShare.sweep).toBeNear(1, 1e-9)
	end)

	T.it("opts.pick decides among the ready attacks (S87's rule gives Azgor's inferno its turn)", function()
		local function longestWaiting(ready: { any }, t: number, state: B.CadenceState): any
			local best, bestValue = nil, -math.huge
			for _, attack in ready do
				local v = (t - state.nextAttack[attack.id]) / attack.cooldown
				if v > bestValue then
					best, bestValue = attack, v
				end
			end
			return best
		end
		local cad = B.bossCadence(Bosses.byId.azgor, 3, { pick = longestWaiting })
		T.expect(cad.perMinute.inferno > 0).toBe(true)
		local none = B.bossCadence(Bosses.byId.azgor, 3, {
			pick = function()
				return nil
			end,
		})
		T.expect(none.casting).toBe(0)
	end)

	T.it("the mirrored server constants did not change (else fix Balance.HAZARDS / BOSS_GLOBAL_GAP)", function()
		local message = "zmieniono stałą bossa: popraw `Balance.HAZARDS` / `BOSS_GLOBAL_GAP`"
		local function has(path: string, text: string)
			if not string.find(fs.readFile(path), text, 1, true) then
				error(`{message} ({path}: "{text}")`, 0)
			end
		end
		has("src/server/Entities/Boss.luau", `local GLOBAL_GAP = {B.BOSS_GLOBAL_GAP}`)
		has("src/server/Entities/BossScripts/azgor.luau", `local TICK = {B.HAZARDS.azgor.every}`)
		has("src/server/Entities/BossScripts/azgor.luau", `damage = {B.HAZARDS.azgor.damage}`)
		has("src/server/Entities/BossScripts/vaelgrath.luau", `local STORM_TICK = {B.HAZARDS.vaelgrath.every}`)
		has("src/server/Entities/BossScripts/vaelgrath.luau", `damage = {B.HAZARDS.vaelgrath.damage}`)
		T.expect(B.bossScriptConsts("vaelgrath").FLIGHT_SECONDS ~= nil).toBe(true)
	end)

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
