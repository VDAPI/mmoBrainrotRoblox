--!strict
-- 2026-10-31 (Studio check: an admin roll of the Staff of Endless Winter came out "Kostur Wiecznej Zimy Ognia" with
-- fire while its effects are ice): a named weapon with an element keeps it on every copy, from any source, and its
-- name gets no element suffix (Data/Items/Uniques opts.element, ItemDef.element, Elements.weaponElement).
local Elements = require("../src/shared/Data/Elements")
local ItemEffects = require("../src/shared/Logic/ItemEffects")
local ItemIcons = require("../src/shared/Logic/ItemIcons")
local ItemName = require("../src/shared/Logic/ItemName")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local TooltipModel = require("../src/shared/Logic/TooltipModel")

-- The element pools of a named item's fixed effects ("ice" for Ice Shard), every class's list.
local function effectElements(def: Items.ItemDef): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local fx: any = def.fx
	if type(fx) ~= "table" then
		return out
	end
	local lists = if type(fx[1]) == "string" then { fx } else fx
	for _, list in lists do
		for _, id in list do
			local effect = ItemEffects.resolve(id)
			if effect and Elements.isWeaponElement(effect.pool) then
				out[effect.pool] = true
			end
		end
	end
	return out
end

T.describe("Named weapons keep their element (2026-10-31)", function()
	T.it("an elemental named weapon has a fixed element that matches its element effects", function()
		local n = 0
		for _, def in Items.uniques do
			if def.elemental then
				n += 1
				T.expect({ def.id, Elements.isWeaponElement(def.element) }).toEqual({ def.id, true })
				for pool in effectElements(def) do
					T.expect({ def.id, pool }).toEqual({ def.id, def.element })
				end
			end
		end
		T.expect(n >= 1).toBe(true)
		T.expect((Items.get("unique_hrimvald_staff") :: Items.ItemDef).element).toBe("ice")
	end)

	T.it(
		"every copy reads that element: rolled with any seed, or carrying another `el` (old saves, /element)",
		function()
			for _, def in Items.uniques do
				if def.elemental then
					for seed = 1, 6 do
						local item: any =
							ItemRoll.rollItem(def.id, def.level, Rarities.MYTHIC, Rng.new(seed), `n{seed}`)
						T.expect({ def.id, item.el, ItemRoll.elementOf(item) })
							.toEqual({ def.id, def.element, def.element })
					end
					for _, el in { "fire", "lightning", "ice", "nonsense" } do
						local item: any = ItemRoll.rollItem(def.id, def.level, Rarities.MYTHIC, Rng.new(1), "x")
						item.el = el
						T.expect({ def.id, el, ItemRoll.elementOf(item) }).toEqual({ def.id, el, def.element })
						T.expect({ def.id, el, (ItemIcons.visualOf(item) :: any).element })
							.toEqual({ def.id, el, def.element })
					end
				end
			end
		end
	)

	T.it("the name has no element suffix and the tooltip says the right element", function()
		local def = Items.get("unique_hrimvald_staff") :: Items.ItemDef
		local item: any = ItemRoll.rollItem(def.id, def.level, Rarities.MYTHIC, Rng.new(1), "h")
		item.el = "fire"
		for _, lang in { "pl", "en" } do
			local name = Locale.T(def.nameKey :: string, nil, lang)
			T.expect(ItemName.get(lang, def.id, nil, ItemRoll.elementOf(item))).toBe(name)
			T.expect(ItemName.get(lang, def.id, 2, "fire")).toBe(`{name} +2`)
			local lines = TooltipModel.build(item, nil, { lang = lang, class = "Mage" }).lines
			T.expect(TooltipModel.plain(lines[1].text)).toBe(name)
			local element = Locale.T("tooltip.element", { element = Locale.T("element.ice", nil, lang) }, lang)
			local found = false
			for _, line in lines do
				if line.role == "element" then
					found = true
					T.expect(line.text).toBe(element)
				end
			end
			T.expect(found).toBe(true)
		end
		-- a rolled Mage weapon still carries its rolled element and suffix
		local wand: any = ItemRoll.rollItem("wand_30", 30, Rarities.HEROIC, Rng.new(2), "w")
		wand.el = "lightning"
		T.expect(ItemRoll.elementOf(wand)).toBe("lightning")
		T.expect(ItemName.get("pl", "wand_30", nil, "lightning"))
			.toBe(`{ItemName.get("pl", "wand_30")} {Locale.T("element.suffix.lightning", nil, "pl")}`)
	end)
end)
