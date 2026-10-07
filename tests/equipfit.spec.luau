--!strict
-- S29: drag highlighting rules of the character window (Logic/EquipFit).

local EquipFit = require("../src/shared/Logic/EquipFit")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function find(predicate: (def: any) -> boolean): string
	local ids = {}
	for id, def in Items.byId do
		if predicate(def) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	assert(ids[1], "no item matches")
	return ids[1]
end

local function item(id: string, ilvl: number): any
	local instance = ItemRoll.makeStack(id, 1, "uid_" .. id) :: any
	instance.ilvl = ilvl
	return instance
end

local warrior = { level = 30, class = "Warrior", equipment = {} }

describe("EquipFit.check", function()
	it("accepts a ring in both ring slots and nowhere else", function()
		local ring = item(
			find(function(def)
				return def.slot == "ring" and def.classes == nil and def.tier ~= nil
			end),
			1
		)
		expect((EquipFit.check(ring, "ring1", warrior))).toBe(true)
		expect((EquipFit.check(ring, "ring2", warrior))).toBe(true)
		local ok, reason = EquipFit.check(ring, "weapon", warrior)
		expect(ok).toBe(false)
		expect(reason).toBe("slot")
	end)

	it("reports the required level", function()
		local sword = item("sword1h_30", 31)
		local ok, reason, level = EquipFit.check(sword, "weapon", { level = 12, class = "Warrior" })
		expect(ok).toBe(false)
		expect(reason).toBe("level")
		expect(level).toBe(ItemRoll.requiredLevel(sword))
		local key, args = EquipFit.messageKey("level", level)
		expect(key).toBe("equip.hint.level")
		expect((args :: any).level).toBe(level)
	end)

	it("rejects another class", function()
		local id = find(function(def)
			return def.slot == "weapon" and def.classes ~= nil and not table.find(def.classes, "Warrior")
		end)
		local ok, reason = EquipFit.check(item(id, 1), "weapon", warrior)
		expect(ok).toBe(false)
		expect(reason).toBe("class")
	end)

	it("blocks the off-hand under a two-handed weapon", function()
		local twoHanded = find(function(def)
			return def.slot == "weapon" and def.weapon ~= nil and def.weapon.twoHanded
		end)
		local offhand = find(function(def)
			return def.slot == "offhand" and (def.classes == nil or table.find(def.classes, "Warrior") ~= nil)
		end)
		local char = { level = 99, class = "Warrior", equipment = { weapon = item(twoHanded, 1) } }
		local ok, reason = EquipFit.check(item(offhand, 1), "offhand", char)
		expect(ok).toBe(false)
		expect(reason).toBe("twoHanded")
		expect((EquipFit.check(item(offhand, 1), "offhand", warrior))).toBe(true)
	end)

	it("maps ring slots to the ring group", function()
		expect(EquipFit.group("ring1")).toBe("ring")
		expect(EquipFit.group("ring2")).toBe("ring")
		expect(EquipFit.group("helmet")).toBe("helmet")
	end)
end)
