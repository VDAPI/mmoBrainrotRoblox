--!strict
-- S79 (ROZWOJ 12.3, 14.4): the Mage engine's pure rules (spell tags, area / single target, zones, Mage hooks,
-- chain path, mana reserve).
local Chain = require("../src/shared/Logic/Chain")
local Channel = require("../src/shared/Logic/Channel")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Stats = require("../src/shared/Data/Stats")
local T = require("./Test")

local function skill(id: string): SkillData.SkillDef
	return SkillData.byId[id]
end

local function vortex(hits: number): any
	return {
		id = "elementalVortex",
		type = "circleSelf",
		radius = 10,
		hits = hits,
		interval = 0.4,
		adaptive = true,
		values = { dmg = { 13, 13 } },
	}
end

T.describe("S79 Mage engine", function()
	T.it("tags (ROZWOJ 12.3)", function()
		for _, id in { "firebolt", "iceShard", "blink", "manaShield" } do
			T.expect({ id, Skills.tag(skill(id)) }).toEqual({ id, "single" })
		end
		for _, id in { "fireball", "frostNova", "meteor", "firewall", "meteorStorm", "chainLightning" } do
			T.expect({ id, Skills.tag(skill(id)) }).toEqual({ id, "area" })
		end
		T.expect(Skills.tag({ type = "trap" } :: any)).toBe("single")
	end)

	T.it("areaApplies: Storm with 3 enemies counts 3, chain with 2 counts 2", function()
		T.expect(Skills.areaCount(skill("firewall"), 3, 1)).toBe(3)
		T.expect(Skills.areaApplies("area", 3, false)).toBe(true)
		T.expect(Skills.areaCount(skill("meteor"), 5, 4)).toBe(4)
		local pts: { Chain.Point } = { { x = 0, z = 0 }, { x = 5, z = 0 }, { x = 30, z = 0 } }
		local order = Chain.path(pts, 1, 13.5, 3)
		T.expect(order).toEqual({ 1, 2 })
		T.expect(Skills.areaApplies("area", #order, false)).toBe(true)
		T.expect(Skills.areaApplies("area", 1, false)).toBe(false)
		T.expect(Skills.areaApplies("single", 5, false)).toBe(false)
		T.expect(Skills.areaApplies("single", 1, true)).toBe(true)
		T.expect(Skills.singleApplies("single", false)).toBe(true)
		T.expect(Skills.singleApplies("single", true)).toBe(false)
		T.expect(Skills.singleApplies("area", false)).toBe(false)
	end)

	T.it("Chain.path", function()
		local a, b = { x = 0, z = 0 }, { x = 5, z = 0 }
		T.expect(Chain.path({ a, b, { x = 14, z = 0 } }, 1, 13.5, 3)).toEqual({ 1, 2, 3 })
		local near = { a, { x = 10, z = 0 }, { x = 4, z = 0 } }
		T.expect(Chain.path(near, 1, 13.5, 3)).toEqual({ 1, 3, 2 })
		T.expect(Chain.path(near, 1, 13.5, 2)).toEqual({ 1, 3 })
		T.expect(Chain.path({ a, b, { x = -5, z = 0 } }, 1, 13.5, 3)).toEqual({ 1, 2, 3 })
		T.expect(Chain.path(near, 1, 1, 3)).toEqual({ 1 })
		T.expect(Chain.path(near, 1, 13.5, 0)).toEqual({ 1 })
		T.expect(Chain.path(near, 4, 13.5, 3)).toEqual({})
	end)

	T.it("spellBonus and resonance", function()
		local h = { areaDamage = 6, singleDamage = 3, spellDamage = 2 }
		T.expect(Skills.spellBonus("area", 3, false, h)).toBe(8)
		T.expect(Skills.spellBonus("area", 1, false, h)).toBe(2)
		T.expect(Skills.spellBonus("single", 1, false, h)).toBe(5)
		T.expect(Skills.spellBonus("single", 1, true, h)).toBe(8)
		T.expect(Skills.spellBonus("area", 3, false, nil)).toBe(0)
		T.expect(Skills.resonanceMul(0.75, 6)).toBeNear(1.06)
		T.expect(Skills.resonanceMul(0.74, 6)).toBe(1)
		T.expect(Skills.resonanceMul(1, 0)).toBe(1)
	end)

	T.it("areaLingering next to the breakpoint zone gives two zones", function()
		local def, behaviour = Skills.effective(skill("meteor"), 10, nil, nil, true)
		local zones = Skills.castZones(def, behaviour, 1, 480, 2, 0)
		T.expect(#zones).toBe(2)
		T.expect(zones[1].pct).toBeNear(96)
		T.expect(zones[1].duration).toBe(4)
		T.expect(zones[1].kind).toBe("burn")
		T.expect(zones[2].pct).toBeNear(9.6)
		T.expect(zones[2].duration).toBe(3)
		T.expect(zones[2].kind).toBe("element")
		T.expect(zones[2].radius).toBe(10)
		T.expect(#Skills.castZones(def, behaviour, 1, 480, 0, 0)).toBe(1)
		T.expect(#Skills.castZones(def, behaviour, 2, 480, 2, 0)).toBe(0)
		local def9, behaviour9 = Skills.effective(skill("meteor"), 9, nil, nil, true)
		local zones9 = Skills.castZones(def9, behaviour9, 1, 480, 2, 0)
		T.expect(#zones9).toBe(1)
		T.expect(zones9[1].kind).toBe("element")
	end)

	T.it("Vortex with 13 waves makes one zone", function()
		local def = vortex(13)
		local count, pct = 0, 0
		for wave = 1, 13 do
			for _, zone in Skills.castZones(def, {}, wave, 13, 2, 0) do
				count += 1
				pct = zone.pct
			end
		end
		T.expect(count).toBe(1)
		T.expect(pct).toBeNear(13 * 13 * 2 / 100)
		local firewall = skill("firewall")
		T.expect(Skills.castZones(firewall, {}, 1, 50, 2, 4)[1].pct).toBeNear(2.5)
		T.expect(#Skills.castZones(firewall, {}, 1, 50, 2, 0)).toBe(0)
		T.expect(#Skills.castZones(skill("firebolt"), {}, 1, 200, 2, 0)).toBe(0)
		T.expect(#Skills.castZones(skill("chainLightning"), {}, 1, 200, 2, 0)).toBe(0)
		T.expect(Skills.zoneKind("fire")).toBe("burn")
		T.expect(Skills.zoneKind("ice")).toBe("frost")
		T.expect(Skills.zoneKind("lightning")).toBe("spark")
		T.expect(Skills.zoneKind(nil)).toBe("arcane")
	end)

	T.it("an area kill gives mana and a Bolt kill does not", function()
		T.expect(Skills.areaKillMana(Skills.tag(skill("meteor")), true, 120, 1.5, 1000)).toBe(15)
		T.expect(Skills.areaKillMana(Skills.tag(skill("firebolt")), true, 120, 1.5, 1000)).toBe(0)
		T.expect(Skills.areaKillMana("area", false, 120, 1.5, 1000)).toBe(0)
		T.expect(Skills.areaKillMana("area", true, 0, 1.5, 1000)).toBe(0)
		T.expect(Skills.areaKillMana("area", true, 120, 0, 1000)).toBe(0)
	end)

	T.it("channelGuard ends with the channel", function()
		local guard = Skills.channelGuard("channel", 12, 3) :: Skills.GuardSpec
		T.expect(guard.kind).toBe("damageReduction")
		T.expect(guard.value).toBe(12)
		T.expect(guard.duration).toBe(3)
		T.expect(guard.category).toBe("own")
		T.expect(guard.skillId).toBe("arcanist_masterMind")
		T.expect(Skills.channelGuard("castTime", 12, 1.5)).toBeNil()
		T.expect(Skills.channelGuard("channel", 0, 3)).toBeNil()
		-- the guard comes off with the channel at its one exit (SkillService endChannel); damage ends a channel
		-- S80: add the beam case (Torrent ignores damage, the guard still ends with it)
		T.expect((Channel.stops("channel", "damage", {}))).toBe(true)
	end)

	T.it("vortexGuard lasts until the last wave", function()
		local guard = Skills.castGuard(vortex(13), 12) :: Skills.GuardSpec
		T.expect(guard.duration).toBeNear(4.8)
		T.expect(guard.skillId).toBe("destroyer_mantle")
		T.expect((Skills.castGuard(vortex(10), 12) :: Skills.GuardSpec).duration).toBeNear(3.6)
		T.expect(Skills.castGuard(skill("meteor"), 12)).toBeNil()
		T.expect(Skills.castGuard(vortex(13), 0)).toBeNil()
	end)

	T.it("mana shield cost", function()
		T.expect({ Skills.manaShieldSplit(100, 50, 1000, 0) }).toEqual({ 50, 50 })
		T.expect({ Skills.manaShieldSplit(100, 50, 20, 0) }).toEqual({ 20, 20 })
		local absorbed, spent = Skills.manaShieldSplit(100, 50, 1000, -30)
		T.expect(absorbed).toBeNear(50)
		T.expect(spent).toBeNear(35)
		absorbed, spent = Skills.manaShieldSplit(100, 50, 21, -30)
		T.expect(absorbed).toBeNear(30)
		T.expect(spent).toBeNear(21)
		absorbed, spent = Skills.manaShieldSplit(100, 50, 1000, 20)
		T.expect(absorbed).toBeNear(50)
		T.expect(spent).toBeNear(60)
	end)

	T.it("areaRadius", function()
		T.expect(Skills.areaRadius(skill("meteor"), 15) :: number).toBeNear(11.5)
		T.expect(Skills.areaRadius(skill("meteor"), 0)).toBe(10)
		T.expect(Skills.areaRadius(skill("chainLightning"), 15)).toBe(12)
		T.expect(Skills.areaRadius(skill("firebolt"), 15)).toBeNil()
	end)

	T.it("manaReserve grows the pool, not the regeneration", function()
		local stats = { str = 5, dex = 5, int = 5, vit = 5 }
		local plain = StatCalc.compute({ level = 5, stats = stats })
		local reserve = StatCalc.compute({
			level = 5,
			stats = stats,
			sources = { { key = "test", flat = { manaReserve = 20 } } },
		})
		local raw = 40 + 6 * 5 + 8 * 5
		T.expect(plain.values.maxMana).toBe(raw)
		T.expect(plain.values.manaReserve).toBe(0)
		T.expect(reserve.values.maxMana).toBe(math.floor(raw * 1.2))
		T.expect(reserve.values.manaRegen).toBe(plain.values.manaRegen)
		T.expect(reserve.values.manaReserve).toBe(20)
		local found = false
		for _, part in reserve.breakdown.maxMana do
			if part.key == "breakdown.manaReserve" then
				found = part.value == 20 and part.pct == true
			end
		end
		T.expect(found).toBe(true)
		local both = StatCalc.compute({
			level = 5,
			stats = stats,
			sources = { { key = "test", pct = { maxMana = 10, manaReserve = 20 } } },
		})
		T.expect(both.values.maxMana).toBe(math.floor(raw * 1.3))
		T.expect(both.values.manaRegen).toBeNear(math.floor(raw * 1.1) * Stats.Formula.manaRegenPct / 100)
		local capped = StatCalc.compute({
			level = 5,
			stats = stats,
			sources = { { key = "test", flat = { manaReserve = 60 } } },
		})
		T.expect(capped.values.manaReserve).toBe(40)
	end)
end)

return nil
