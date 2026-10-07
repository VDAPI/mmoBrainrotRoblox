--!strict
local Atlas = require("../src/shared/Data/ItemIconAtlas")
local ItemIcons = require("../src/shared/Logic/ItemIcons")
local Items = require("../src/shared/Data/Items")
local T = require("./Test")

T.describe("Item icons", function()
	T.it("every item definition has an icon", function()
		local missing = {}
		for id, def in Items.byId do
			if not ItemIcons.resolve(def) then
				table.insert(missing, id)
			end
		end
		table.sort(missing)
		T.expect(table.concat(missing, ", ")).toBe("")
	end)

	T.it("atlas cells are inside the sheets and do not overlap", function()
		local used = {}
		for key, icon in Atlas.ICONS do
			T.expect(#icon.layers >= 1).toBe(true)
			for _, layer in icon.layers do
				T.expect(layer.s >= 1 and layer.s <= Atlas.SHEETS).toBe(true)
				T.expect(layer.x % Atlas.CELL == 0 and layer.y % Atlas.CELL == 0).toBe(true)
				T.expect(layer.x <= 1024 - Atlas.CELL and layer.y <= 1024 - Atlas.CELL).toBe(true)
				local cell = `{layer.s}:{layer.x}:{layer.y}`
				T.expect(used[cell]).toBeNil()
				used[cell] = key
			end
		end
	end)

	T.it("equipment: base icon tinted by tier, named boss items have their own", function()
		local sword = ItemIcons.resolve(Items.get("sword1h_30") :: any)
		T.expect(sword and sword.key).toBe("eq/sword1h")
		local tinted = false
		for _, layer in (sword :: any).layers do
			if layer.tint == Atlas.TIER_TINT[30] then
				tinted = true
			end
		end
		T.expect(tinted).toBe(true)
		T.expect(ItemIcons.tierTint(37)).toBe(Atlas.TIER_TINT[35])
		local cleaver = ItemIcons.resolve(Items.get("unique_grimrok_cleaver") :: any)
		T.expect(cleaver and cleaver.key).toBe("uniq/unique_grimrok_cleaver")
	end)

	T.it("accents: element for mage weapons, data colour for potions and ores", function()
		-- Accent layers are drawn last.
		local function accentOf(r: ItemIcons.Resolved?): string?
			local layers = (r :: any).layers
			return layers[#layers].tint
		end
		T.expect(accentOf(ItemIcons.resolve(Items.get("wand_10") :: any, "ice"))).toBe("#9FE0FF")
		local hp = Items.get("potion_hp_3") :: any
		local r = ItemIcons.resolve(hp)
		T.expect(r and r.key).toBe("pot/3")
		local foundRed = false
		for _, layer in (r :: any).layers do
			if layer.tint == hp.icon.color then
				foundRed = true
			end
		end
		T.expect(foundRed).toBe(true)
		T.expect((ItemIcons.resolve(Items.get("ore_iron") :: any) :: any).key).toBe("mat/ore")
		T.expect((ItemIcons.resolve(Items.get("blessing_sage_2") :: any) :: any).key).toBe("bless/sage")
	end)

	T.it("not ready until every sheet has an asset id", function()
		T.expect(type(ItemIcons.ready())).toBe("boolean")
		for n = 1, Atlas.SHEETS do
			local id = ItemIcons.sheet(n)
			if id then
				T.expect(string.match(id, "^rbxassetid://%d+$") ~= nil).toBe(true)
			end
		end
	end)

	T.it("ready only with an asset id for every sheet (S35)", function()
		T.expect(ItemIcons.readyFor({ "", "", "" })).toBe(false)
		T.expect(ItemIcons.readyFor({ "rbxassetid://1", "rbxassetid://2" })).toBe(false)
		T.expect(ItemIcons.readyFor({ "rbxassetid://1", "rbxassetid://2", "oops" })).toBe(false)
		T.expect(ItemIcons.readyFor({ "rbxassetid://1", "rbxassetid://22", "rbxassetid://333" })).toBe(true)
	end)

	T.it("the drag ghost of an item carries its definition and element (S35)", function()
		local wand = ItemIcons.visualOf({ id = "wand_10", el = "ice" }) :: any
		T.expect(wand.def.id).toBe("wand_10")
		T.expect(wand.element).toBe("ice")
		local old = ItemIcons.visualOf({ id = "wand_10" }) :: any
		T.expect(old.element).toBe("fire")
		local potion = ItemIcons.visualOf({ id = "potion_hp_2" }) :: any
		T.expect(potion.element).toBeNil()
		T.expect(potion.glyph).toBe((Items.get("potion_hp_2") :: any).icon.glyph)
		T.expect(ItemIcons.visualOf({ id = "no_such_item" })).toBeNil()
		T.expect(ItemIcons.visualOf(nil)).toBeNil()
	end)
end)
