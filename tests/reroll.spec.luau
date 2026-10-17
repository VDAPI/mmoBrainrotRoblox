--!strict
-- S134j: bonus reroll at the smith (Logic/Reroll, docs/DESIGN.md §6a). Only random regular lines, one line per item
-- (locked by the first reroll), the pool of the item without the other lines, the value like a drop, the cost growing
-- with the item's count up to growthCap, the Stone of Transmutation paying only the essence.

local Bonuses = require("../src/shared/Data/Bonuses")
local Config = require("../src/shared/Config")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Rarities = require("../src/shared/Data/Rarities")
local Reroll = require("../src/shared/Logic/Reroll")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")
local Upgrade = require("../src/shared/Logic/Upgrade")

local function tierId(baseType: string, ilvl: number): string
	return `{baseType}_{Items.generate.tierFor(ilvl)}`
end

local function item(defId: string, ilvl: number, rarity: number, bonuses: { any }, extra: { [string]: any }?): any
	local out: any = {
		uid = "u1",
		id = defId,
		rarity = rarity,
		ilvl = ilvl,
		bonuses = bonuses,
		up = 3,
		bound = true,
		n = 1,
		rv = Rarities.RV,
		locked = true,
	}
	for k, v in extra or {} do
		out[k] = v
	end
	return out
end

local SWORD = tierId("sword1h", 45)
local function heroicSword(extra: { [string]: any }?): any
	return item(
		SWORD,
		45,
		Rarities.HEROIC,
		{ { stat = "str", v = 5 }, { stat = "critChance", v = 2 }, { stat = "vs_undead", v = 6 } },
		extra
	)
end

local function count(t: { [string]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

T.describe("Reroll state (S134j)", function()
	T.it("no field, garbage and an index outside: open choice, the count kept when valid", function()
		T.expect(Reroll.state(heroicSword())).toEqual({ line = nil, n = 0 })
		T.expect(Reroll.state(heroicSword({ rr = "x" }))).toEqual({ line = nil, n = 0 })
		T.expect(Reroll.state(heroicSword({ rr = { i = 2, n = -1 } }))).toEqual({ line = 2, n = 0 })
		T.expect(Reroll.state(heroicSword({ rr = { i = 2, n = 1.5 } }))).toEqual({ line = 2, n = 0 })
		T.expect(Reroll.state(heroicSword({ rr = { i = 9, n = 4 } }))).toEqual({ line = nil, n = 4 })
		T.expect(Reroll.state(heroicSword({ rr = { i = 0, n = 4 } }))).toEqual({ line = nil, n = 4 })
		T.expect(Reroll.state(heroicSword({ rr = { i = "1", n = 4 } }))).toEqual({ line = nil, n = 4 })
		T.expect(Reroll.state(heroicSword({ rr = { i = 3, n = 7 } }))).toEqual({ line = 3, n = 7 })
		-- a locked index on a line that is no longer regular opens the choice
		local legacy = heroicSword({ rr = { i = 1, n = 2 } })
		legacy.bonuses[1] = { stat = "leg_bossDamage", v = 10 }
		T.expect(Reroll.state(legacy)).toEqual({ line = nil, n = 2 })
	end)
end)

T.describe("Reroll eligible and canLine (S134j)", function()
	T.it("Common, crafted, named, materials: no; Unique, Heroic, Legendary and Mythic: yes", function()
		T.expect((Reroll.eligible(item(SWORD, 45, Rarities.COMMON, {})))).toBe(false)
		local _, why = Reroll.eligible(item(SWORD, 45, Rarities.COMMON, {}))
		T.expect(why).toBe("smith.reroll.error.noLines")
		local named = ItemRoll.rollItem("unique_grimrok_cleaver", 20, Rarities.MYTHIC, Rng.new(1), "n1")
		local ok, err = Reroll.eligible(named)
		T.expect({ ok, err }).toEqual({ false, "smith.reroll.error.fixed" })
		T.expect((Reroll.eligible(ItemRoll.makeStack("essence_dust", 5, "m1")))).toBe(false)
		for _, rarity in { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC } do
			local rolled = ItemRoll.rollItem(SWORD, 45, rarity, Rng.new(rarity), `r{rarity}`, "Warrior")
			T.expect({ rarity, #rolled.bonuses > 0, (Reroll.eligible(rolled)) }).toEqual({ rarity, true, true })
		end
	end)

	T.it("a legacy legendary line and an unknown id are refused; after the first reroll only that line", function()
		local legacy = heroicSword()
		legacy.bonuses[2] = { stat = "leg_bossDamage", v = 10 }
		legacy.bonuses[3] = { stat = "nope", v = 1 }
		T.expect({ Reroll.canLine(legacy, 2) }).toEqual({ false, "smith.reroll.error.notRegular" })
		T.expect({ Reroll.canLine(legacy, 3) }).toEqual({ false, "smith.reroll.error.notRegular" })
		T.expect({ Reroll.canLine(legacy, 4) }).toEqual({ false, "smith.reroll.error.notRegular" })
		T.expect((Reroll.canLine(legacy, 1))).toBe(true)
		local sword = heroicSword()
		for index = 1, 3 do
			T.expect((Reroll.canLine(sword, index))).toBe(true)
		end
		Reroll.apply(sword, 2, Reroll.roll(sword, 2, "Warrior", Rng.new(5)))
		T.expect({ Reroll.canLine(sword, 1) }).toEqual({ false, "smith.reroll.error.lockedOther" })
		T.expect({ Reroll.canLine(sword, 3) }).toEqual({ false, "smith.reroll.error.lockedOther" })
		T.expect((Reroll.canLine(sword, 2))).toBe(true)
	end)
end)

T.describe("Reroll pool (S134j)", function()
	T.it("without the other lines and their markers, with the current stat, filtered by class", function()
		local sword = heroicSword()
		local full = ItemRoll.poolWeights(SWORD, "Warrior")
		local pool = Reroll.pool(sword, 1, "Warrior")
		T.expect(pool.str).toBe(full.str)
		T.expect(pool.critChance).toBeNil()
		T.expect(pool["@vsFamily"]).toBeNil()
		T.expect(count(pool)).toBe(count(full) - 2)
		-- rerolling the family line keeps its marker
		T.expect(Reroll.pool(sword, 3, "Warrior")["@vsFamily"]).toBe(full["@vsFamily"])
		-- jewellery for the character's class: CLASS_STATS filter
		local ring = item(tierId("ring", 45), 45, Rarities.HEROIC, { { stat = "vit", v = 4 } })
		T.expect(Reroll.pool(ring, 1, "Mage").str).toBeNil()
		T.expect(Reroll.pool(ring, 1, "Mage").int ~= nil).toBe(true)
		T.expect(Reroll.pool(ring, 1, "Warrior").int).toBeNil()
	end)

	T.it("an item of another class rolls for the classes of its definition", function()
		local mace = item(tierId("mace1h", 45), 45, Rarities.HEROIC, { { stat = "vit", v = 4 } })
		T.expect(Reroll.classFor(mace, "Mage")).toBeNil()
		T.expect(Reroll.classFor(mace, "Cleric")).toBe("Cleric")
		T.expect(Reroll.pool(mace, 1, "Mage")).toEqual(ItemRoll.poolWeights(mace.id, nil))
		T.expect(Reroll.pool(mace, 1, "Cleric")).toEqual(ItemRoll.poolWeights(mace.id, "Cleric"))
	end)
end)

T.describe("Reroll roll and apply (S134j)", function()
	T.it("the value inside bonusRange, markers expanded, the same seed the same line", function()
		local sword = heroicSword()
		local a = Reroll.roll(sword, 1, "Warrior", Rng.new(42))
		local b = Reroll.roll(sword, 1, "Warrior", Rng.new(42))
		T.expect(a).toEqual(b)
		local pool = Reroll.pool(sword, 3, "Warrior")
		local seen: { [string]: boolean } = {}
		local rng = Rng.new(7)
		for _ = 1, 2000 do
			local line = Reroll.roll(sword, 3, "Warrior", rng)
			T.expect(Bonuses.isParam(line.stat)).toBe(false)
			local def = Bonuses.get(line.stat) :: Bonuses.BonusDef
			local key = def.param or line.stat
			T.expect({ line.stat, pool[key] ~= nil }).toEqual({ line.stat, true })
			seen[key] = true
			local low, high = ItemRoll.bonusRange(line.stat, sword.ilvl, sword.rarity)
			local step = 10 ^ -def.decimals
			T.expect(line.v >= math.min(low, high) - step and line.v <= high + step).toBe(true)
		end
		for id in pool do
			T.expect({ id, seen[id] == true }).toEqual({ id, true })
		end
	end)

	T.it("apply changes only bonuses[index] and rr; the first reroll locks, every one counts", function()
		local sword = heroicSword({ el = "fire", fx = { "x" } })
		local before = TableUtil.deepCopy(sword)
		local line = { stat = "dotPower", v = 9 }
		Reroll.apply(sword, 2, line)
		T.expect(sword.rr).toEqual({ i = 2, n = 1 })
		T.expect(sword.bonuses[2]).toEqual(line)
		T.expect(sword.bonuses[1]).toEqual(before.bonuses[1])
		T.expect(sword.bonuses[3]).toEqual(before.bonuses[3])
		-- the original list is not edited in place
		T.expect(before.bonuses[2]).toEqual({ stat = "critChance", v = 2 })
		local after = TableUtil.deepCopy(sword)
		after.bonuses = before.bonuses
		after.rr = nil
		T.expect(TableUtil.deepEqual(after, before)).toBe(true)
		Reroll.apply(sword, 2, { stat = "str", v = 3 })
		T.expect(sword.rr).toEqual({ i = 2, n = 2 })
	end)
end)

T.describe("Reroll preview (S134j)", function()
	T.it("chances add up to 1 and match the pool; ranges x the two-handed multiplier", function()
		local sword = heroicSword()
		local pool = Reroll.pool(sword, 3, "Warrior")
		local total = 0
		for _, w in pool do
			total += w
		end
		local sum = 0
		local rows = Reroll.preview(sword, 3, "Warrior")
		T.expect(#rows).toBe(count(pool))
		for _, row in rows do
			sum += row.chance
			T.expect(row.chance).toBeNear(pool[row.stat] / total, 1e-9)
			T.expect(row.marker).toBe(Bonuses.isParam(row.stat))
		end
		T.expect(sum).toBeNear(1, 1e-9)
		local two = item(tierId("sword2h", 45), 45, Rarities.HEROIC, { { stat = "str", v = 5 } })
		for _, row in Reroll.preview(two, 1, "Warrior") do
			if not row.marker then
				local low, high = ItemRoll.bonusRange(row.stat, 45, Rarities.HEROIC)
				local mul = ItemRoll.lineMultiplier(two, row.stat)
				T.expect(row.min).toBeNear(low * mul, 1e-9)
				T.expect(row.max).toBeNear(high * mul, 1e-9)
				if ItemRoll.isRegularLine(row.stat) then
					T.expect(mul).toBe(Rarities.twoHandedBonusMul)
				end
			end
		end
	end)
end)

T.describe("Reroll cost (S134j)", function()
	T.it("grows with n, flat from growthCap, the rarity's essence; the stone keeps the gold only", function()
		local c = Config.Reroll
		local sword = heroicSword()
		local base = 45 * Upgrade.goldPerIlvl(45) * c.goldMul
		local previous = 0
		local capAt = math.ceil((c.growthCap - 1) / c.growth)
		for n = 0, capAt + 3 do
			local cost = Reroll.costAt(sword, n)
			local mul = math.min(1 + c.growth * n, c.growthCap)
			T.expect(cost.gold).toBe(math.floor(base * mul + 0.5))
			T.expect(cost.gold >= previous).toBe(true)
			previous = cost.gold
			T.expect(cost.materials[1].id).toBe(c.essence.heroic.id)
		end
		T.expect(Reroll.costAt(sword, capAt + 5)).toEqual(Reroll.costAt(sword, capAt))
		T.expect(Reroll.costAt(sword, capAt).gold).toBe(math.floor(base * c.growthCap + 0.5))
		sword.rr = { i = 1, n = 3 }
		T.expect(Reroll.cost(sword)).toEqual(Reroll.costAt(sword, 3))
		for _, rarity in { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC } do
			local x = item(SWORD, 45, rarity, { { stat = "str", v = 5 } })
			local cost = Reroll.cost(x)
			local e = (c.essence :: any)[Rarities.get(rarity).key]
			T.expect(cost.materials).toEqual({ { id = e.id, n = e.n } })
			local stone = Reroll.costWithStone(x)
			T.expect(stone.gold).toBe(cost.gold)
			T.expect(#stone.materials).toBe(0)
		end
	end)
end)
