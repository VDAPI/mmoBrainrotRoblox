--!strict
-- S160k (owner 2026-10-21): "Change effect" at the smith (Logic/EffectReroll). One skill effect of a Legendary or
-- Mythic item becomes another effect of the same tier from the drop pool (class, element, weapon pool), never one the
-- item already has; named items and lower rarities are refused; the cost is gold, essence and a stone together.

local Config = require("../src/shared/Config")
local EffectReroll = require("../src/shared/Logic/EffectReroll")
local ItemEffects = require("../src/shared/Logic/ItemEffects")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local Upgrade = require("../src/shared/Logic/Upgrade")

local function tierId(baseType: string, ilvl: number): string
	return `{baseType}_{Items.generate.tierFor(ilvl)}`
end

local function roll(baseType: string, ilvl: number, rarity: number, seed: number, class: string): any
	return ItemRoll.rollItem(tierId(baseType, ilvl), ilvl, rarity, Rng.new(seed), `u{seed}`, class)
end

T.describe("EffectReroll (S160k)", function()
	T.it("accepts Legendary and Mythic items with effects only", function()
		T.expect((EffectReroll.eligible(roll("sword1h", 50, Rarities.LEGENDARY, 1, "Warrior")))).toBe(true)
		T.expect((EffectReroll.eligible(roll("sword1h", 50, Rarities.MYTHIC, 1, "Warrior")))).toBe(true)
		T.expect({ EffectReroll.eligible(roll("sword1h", 50, Rarities.HEROIC, 1, "Warrior")) }).toEqual({
			false,
			"smith.effect.error.rarity",
		})
		local named = 0
		for _, def in Items.uniques do
			named += 1
			local item = ItemRoll.rollItem(def.id, def.level, Rarities.MYTHIC, Rng.new(1), "n", nil)
			T.expect({ def.id, EffectReroll.eligible(item) }).toEqual({ def.id, false, "smith.effect.error.fixed" })
		end
		T.expect(named > 0).toBe(true)
		local plain = roll("sword1h", 50, Rarities.LEGENDARY, 2, "Warrior")
		T.expect({ EffectReroll.canIndex(plain, 9) }).toEqual({ false, "smith.effect.error.none" })
	end)

	T.it("keeps the tier, the class and the weapon pool and never repeats an effect", function()
		for _, spec in
			{
				{ "sword1h", "Warrior" },
				{ "bow", "Hunter" },
				{ "crossbow", "Hunter" },
				{ "wand", "Mage" },
				{ "scepter", "Cleric" },
				{ "ring", "Mage" },
			}
		do
			for _, rarity in { Rarities.LEGENDARY, Rarities.MYTHIC } do
				for seed = 1, 12 do
					local item = roll(spec[1], 60, rarity, seed, spec[2])
					local def = Items.get(item.id) :: any
					local weaponType = if def.slot == "weapon" then def.type else nil
					for index, id in item.fx or {} do
						local current = ItemEffects.resolve(id) :: any
						local own = ItemEffects.weaponPool(current.class, weaponType)
						local element = ItemRoll.elementOf(item)
						local pool = EffectReroll.pool(item, index, spec[2])
						for _, candidate in pool do
							T.expect(candidate.tier).toBe(current.tier)
							T.expect(candidate.class).toBe(spec[2])
							T.expect(table.find(item.fx, candidate.id)).toBeNil()
							if element == nil and own then
								T.expect(candidate.pool == own or candidate.pool == "common").toBe(true)
							end
						end
						local preview = EffectReroll.preview(item, index, spec[2])
						T.expect(#preview).toBe(#pool)
						if #pool > 0 then
							local sum = 0
							for _, outcome in preview do
								sum += outcome.chance
							end
							T.expect(math.abs(sum - 1) < 1e-9).toBe(true)
							local copy = table.clone(item)
							local new = EffectReroll.roll(copy, index, spec[2], Rng.new(seed * 7))
							EffectReroll.apply(copy, index, new)
							T.expect(copy.fx[index]).toBe(new)
							T.expect(#copy.fx).toBe(#item.fx)
							T.expect(item.fx[index]).toBe(id) -- the original list is untouched
							local seen: { [string]: boolean } = {}
							for _, fxId in copy.fx do
								T.expect(seen[fxId]).toBeNil()
								seen[fxId] = true
							end
							T.expect(ItemEffects.migrateItem(copy, nil, spec[2])).toBe(false) -- already valid
						end
					end
				end
			end
		end
	end)

	T.it("a class-free item of another class rolls for the replaced effect's class", function()
		local ring = roll("ring", 60, Rarities.LEGENDARY, 3, "Mage")
		local current = ItemEffects.resolve(ring.fx[1]) :: any
		T.expect(current.class).toBe("Mage")
		for _, candidate in EffectReroll.pool(ring, 1, "Warrior") do
			T.expect(candidate.class).toBe("Warrior") -- a ring fits every class: the character's class
		end
		local sword = roll("sword1h", 60, Rarities.LEGENDARY, 3, "Warrior")
		for _, candidate in EffectReroll.pool(sword, 1, "Mage") do
			T.expect(candidate.class).toBe("Warrior") -- a Mage holding a sword keeps the Warrior's effects
		end
	end)

	T.it("costs gold, the rarity's essence and one stone together", function()
		local c = Config.Reroll
		for _, rarity in { Rarities.LEGENDARY, Rarities.MYTHIC } do
			local item = roll("sword1h", 70, rarity, 4, "Warrior")
			local cost = EffectReroll.cost(item)
			local ilvl = item.ilvl
			T.expect(cost.gold).toBe(math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * c.effectGoldMul + 0.5))
			local e = (c.effectEssence :: any)[Rarities.get(rarity).key]
			T.expect(cost.materials).toEqual({ { id = e.id, n = e.n } })
			local payment = EffectReroll.payment(item)
			T.expect(payment.gold).toBe(cost.gold)
			T.expect(payment.materials).toEqual({ { id = e.id, n = e.n }, { id = EffectReroll.STONE, n = 1 } })
		end
		T.expect(Items.get(EffectReroll.STONE) ~= nil).toBe(true)
	end)
end)
