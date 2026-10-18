--!strict
-- S145 (DESIGN-18 §6.4): the Cleric's pools: Logic/Faith (Light Ray's heal on the most wounded, Guiding Light's ward,
-- Zeal for the hammer pool only, the Inquisitor's Wandering Brand, Rebuke's interrupt), Logic/Channel's "interrupt"
-- event, the data and texts that read them and the model's mirror.

local B = require("./Balance")
local BossMechanics = require("../src/shared/Logic/BossMechanics")
local Channel = require("../src/shared/Logic/Channel")
local Faith = require("../src/shared/Logic/Faith")
local Paths = require("../src/shared/Logic/Paths")
local PathData = require("../src/shared/Data/Paths")
local SkillData = require("../src/shared/Data/Skills")
local SkillModel = require("./SkillModel")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local FAITH = SkillData.FAITH

-- A copy of a reference build with its own key (the model caches by key) and one rotation.
local function only(key: string, classId: string, rotation: { { [string]: any } }): any
	local build = table.clone(SkillModel.build(key, classId) :: any)
	build.key = `{key}.s145.{rotation[1].skill}`
	build.rotation = rotation
	return build
end

T.describe("Faith: the light pool (S145)", function()
	T.it("mostWounded: the lowest HP share below full, the first on a tie, nil when nobody is wounded", function()
		T.expect(Faith.mostWounded({ 1, 0.5, 0.8 })).toBe(2)
		T.expect(Faith.mostWounded({ 0.4, 0.4 })).toBe(1)
		T.expect(Faith.mostWounded({ 1, 1 })).toBeNil()
		-- solo: the list holds the caster only (Context.mostWounded with no party)
		T.expect(Faith.mostWounded({ 0.7 })).toBe(1)
		T.expect(Faith.mostWounded({})).toBeNil()
	end)

	T.it("rayHeal: Light Ray heals its share of the hit; nothing without a hit", function()
		local ray = SkillData.get("lightRay") :: any
		local pct = Skills.valueAt(ray, "rayHeal", 1)
		T.expect(pct).toBe(25)
		T.expect(Faith.rayHeal(400, pct)).toBeNear(100)
		T.expect(Faith.rayHeal(0, pct)).toBe(0)
		T.expect(Faith.rayHeal(400, 0)).toBe(0)
		-- 5A: +10 points of the hit
		local fiveA = Skills.effective(ray, 5, nil, nil, true)
		T.expect(Skills.valueAt(fiveA, "rayHeal", 5)).toBe(35)
	end)

	T.it("ward: Guiding Light's share of the restored HP, capped by the target's max HP", function()
		T.expect(Faith.ward(1000, 15, 10000)).toBeNear(150)
		T.expect(Faith.ward(20000, 20, 10000)).toBeNear(10000 * FAITH.wardCap / 100)
		T.expect(Faith.ward(0, 20, 10000)).toBe(0)
		T.expect(Faith.ward(1000, 0, 10000)).toBe(0)
		local guiding = SkillData.get("guidingLight") :: any
		T.expect({ guiding.pool, guiding.role, guiding.passive.hooks.guidingLight }).toEqual({ "light", "P2", "ward" })
	end)

	T.it("Grace: healBonus, healCrit and lowHpHealBonus hooks, the heal factor reads them", function()
		local grace = SkillData.get("grace") :: any
		T.expect(grace.passive.hooks).toEqual({ healBonus = "heal", healCrit = "healCrit", lowHpHealBonus = "lowHeal" })
		T.expect(Skills.healBonusPct({ healBonus = 0, allyHealBonus = 0, lowHpHealBonus = 30 }, true, 0.2)).toBe(30)
		T.expect(Skills.healBonusPct({ healBonus = 0, allyHealBonus = 0, lowHpHealBonus = 30 }, true, 0.5)).toBe(0)
	end)
end)

T.describe("Faith: the hammer pool (S145)", function()
	T.it("zealCut: only an offensive cast of a hammer skill; only the hammer pool's cooldowns shorten", function()
		T.expect(Faith.zealCut("hammer", 0.5)).toBe(0.5)
		T.expect(Faith.zealCut("light", 0.5)).toBe(0)
		T.expect(Faith.zealCut("common", 0.5)).toBe(0)
		T.expect(Faith.zealCut(nil, 0.5)).toBe(0)
		T.expect(Faith.zealCut("hammer", 0)).toBe(0)
		T.expect(Faith.zealShortens("hammer")).toBe(true)
		T.expect(Faith.zealShortens("light")).toBe(false)
		T.expect(Faith.zealShortens("common")).toBe(false)
		local zeal = SkillData.get("zeal") :: any
		T.expect({ zeal.pool, zeal.role, zeal.passive.hooks.zeal }).toEqual({ "hammer", "P2", "zeal" })
	end)

	T.it("brandShare: the Wandering Brand works on the brand skills only", function()
		T.expect(Faith.brandShare("brandOfLight", 60)).toBe(60)
		T.expect(Faith.brandShare("holyStrike", 60)).toBe(0)
		T.expect(Faith.brandShare("brandOfLight", 0)).toBe(0)
		local node = Paths.findNode("inquisitor_wanderingBrand") :: any
		T.expect({ node.kind, node.maxRank, node.passive.hooks.brandJump }).toEqual({ "keystone", 1, "brandJump" })
		-- the keystone is the Inquisitor's capstone: row 8 alone
		local inquisitor = PathData.byId.inquisitor :: any
		T.expect(#inquisitor.rows[8].nodes).toBe(1)
		T.expect(inquisitor.rows[8].nodes[1].id).toBe("inquisitor_wanderingBrand")
	end)

	T.it("Rebuke breaks an enemy player's channel, aim and beam, never a boss's channel", function()
		local rebuke = SkillData.get("rebuke") :: any
		T.expect({ rebuke.interrupt, rebuke.pool, rebuke.role }).toEqual({ true, "hammer", "K2" })
		for _, kind in { "channel", "castTime", "beam" } do
			local stop, refund = Channel.stops(kind, "interrupt", nil)
			T.expect({ kind, stop, refund }).toEqual({ kind, true, false })
		end
		-- steadfast (Prayer 10B) keeps a channel through damage, not through a rebuke
		T.expect((Channel.stops("channel", "interrupt", { steadfast = true }))).toBe(true)
		T.expect(Faith.interrupts(true, false)).toBe(true)
		T.expect(Faith.interrupts(false, false)).toBe(false) -- a monster's cast
		T.expect(Faith.interrupts(true, true)).toBe(false)
		-- a boss's channel breaks only by damage: the rebuke changes nothing without the HP it takes
		local maxHp, breakPct = 100000, 8
		T.expect(BossMechanics.channelBroken(maxHp, maxHp, maxHp, breakPct)).toBe(false)
		T.expect(Faith.interrupts(false, true)).toBe(false)
	end)

	T.it("Holy Chains: a root on monsters, a slow on bosses (Logic/Snare)", function()
		local chains = SkillData.get("holyChains") :: any
		local effect = chains.effects[1]
		T.expect({ effect.kind, effect.bossSlow, Skills.valueAt(chains, "slow", 1) }).toEqual({ "root", "slow", 40 })
	end)
end)

T.describe("Faith: the model's mirror (S145)", function()
	T.it("Light Ray heals the caster solo and the tank in a party", function()
		local ray = only("healer.solo", "Cleric", { { skill = "lightRay" } })
		local one = { B.monster(B.GENERIC, 20) }
		local solo = SkillModel.fight(SkillModel.player(ray, 20), { targets = one, unlimited = true })
		T.expect((solo.by.lightRay or 0) > 0).toBe(true)
		T.expect((solo.healTo.self or 0) > 0).toBe(true)
		local party = SkillModel.fight(SkillModel.player(ray, 20), {
			targets = one,
			unlimited = true,
			heal = { tank = B.player("Warrior", 20), team = 2 },
		})
		T.expect((party.healTo.tank or 0) > 0).toBe(true)
		T.expect(party.healTo.self or 0).toBe(0)
	end)

	T.it("Holy Nova: damage and the heal of the party in one cast", function()
		local nova = only("inquisitor.solo", "Cleric", { { skill = "holyNova" } })
		local two = { B.monster(B.GENERIC, 100), B.monster(B.GENERIC, 100) }
		local r = SkillModel.fight(SkillModel.player(nova, 100), {
			targets = two,
			unlimited = true,
			heal = { tank = B.player("Warrior", 100), team = 2 },
		})
		T.expect((r.casts.holyNova or 0) > 0).toBe(true)
		T.expect((r.by.holyNova or 0) > 0).toBe(true)
		T.expect((r.healTo.tank or 0) > 0).toBe(true)
		T.expect((r.healTo.self or 0) > 0).toBe(true)
	end)

	T.it("Guiding Light: every Heal on the tank adds a ward of its share at 100", function()
		local heal = only("healer.dungeon", "Cleric", { { skill = "heal", target = "tank" } })
		local sp = SkillModel.player(heal, 100)
		local ward = sp.pathHooks.guidingLight or 0
		T.expect(ward > 0).toBe(true)
		local tank = B.player("Warrior", 100)
		local amount = SkillModel.oneHeal(heal, 100, tank) * tank.values.maxHp
		local r = SkillModel.fight(sp, {
			targets = { B.monster(B.GENERIC, 100) },
			unlimited = true,
			heal = { tank = tank, team = 2 },
		})
		local casts = r.casts.heal or 0
		T.expect(casts > 0).toBe(true)
		T.expect(r.healTo.tank or 0).toBeNear(casts * amount * (1 + ward / 100), casts * amount * 0.01)
	end)

	T.it("Wandering Brand lands the brand's burn on a second target", function()
		local brand = only("inquisitor.solo", "Cleric", { { skill = "brandOfLight" } })
		local without = SkillModel.withoutNodes(brand, { "inquisitor_wanderingBrand" })
		local two = { B.monster(B.GENERIC, 100), B.monster(B.GENERIC, 100) }
		local with = SkillModel.fight(SkillModel.player(brand, 100), { targets = two, unlimited = true })
		local bare = SkillModel.fight(SkillModel.player(without, 100), { targets = two, unlimited = true })
		T.expect((with.by.brandOfLight or 0) > (bare.by.brandOfLight or 0)).toBe(true)
	end)
end)

return nil
