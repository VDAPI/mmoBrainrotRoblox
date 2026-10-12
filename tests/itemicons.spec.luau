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
		for _, set in { Atlas.ICONS, Atlas.PNG } do
			for key, icon in set do
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
		end
		for _, icon in Atlas.ICONS do
			for _, layer in icon.layers do
				T.expect(layer.s <= Atlas.SVG_SHEETS).toBe(true)
			end
		end
	end)

	T.it("equipment: base icon tinted by tier, named boss items have their own", function()
		-- Code-drawn sheets only (as before the pictures of S52 are uploaded).
		local svgOnly = function(n: number): boolean
			return n <= Atlas.SVG_SHEETS
		end
		local sword = ItemIcons.resolve(Items.get("sword1h_30") :: any, nil, svgOnly)
		T.expect(sword and sword.key).toBe("eq/sword1h")
		-- The tier layer exists only when the icon has a material (m) layer.
		local hasTier = false
		for _, layer in (Atlas.ICONS["eq/sword1h"] :: any).layers do
			hasTier = hasTier or layer.t == "tier"
		end
		local tinted = false
		for _, layer in (sword :: any).layers do
			if layer.tint == Atlas.TIER_TINT[30] then
				tinted = true
			end
		end
		T.expect(tinted).toBe(hasTier)
		T.expect(ItemIcons.tierTint(37)).toBe(Atlas.TIER_TINT[35])
		local cleaver = ItemIcons.resolve(Items.get("unique_grimrok_cleaver") :: any, nil, svgOnly)
		T.expect(cleaver and cleaver.key).toBe("uniq/unique_grimrok_cleaver")
	end)

	T.it("accents: element for mage weapons, data colour for potions and ores", function()
		-- Accent layers are drawn last.
		local function accentOf(r: ItemIcons.Resolved?): string?
			local layers = (r :: any).layers
			return layers[#layers].tint
		end
		-- Code-drawn icons (pictures of S52 have no accent layer).
		local svgOnly = function(n: number): boolean
			return n <= Atlas.SVG_SHEETS
		end
		T.expect(accentOf(ItemIcons.resolve(Items.get("wand_10") :: any, "ice", svgOnly))).toBe("#9FE0FF")
		local hp = Items.get("potion_hp_3") :: any
		local r = ItemIcons.resolve(hp, nil, svgOnly)
		T.expect(r and r.key).toBe("pot/3")
		local foundRed = false
		for _, layer in (r :: any).layers do
			if layer.tint == hp.icon.color then
				foundRed = true
			end
		end
		T.expect(foundRed).toBe(true)
		T.expect((ItemIcons.resolve(Items.get("ore_iron") :: any, nil, svgOnly) :: any).key).toBe("mat/ore")
		T.expect((ItemIcons.resolve(Items.get("blessing_sage_2") :: any, nil, svgOnly) :: any).key).toBe("bless/sage")
	end)

	T.it("not ready until every code-drawn sheet has an asset id", function()
		T.expect(type(ItemIcons.ready())).toBe("boolean")
		for n = 1, Atlas.SHEETS do
			local id = ItemIcons.sheet(n)
			if id then
				T.expect(string.match(id, "^rbxassetid://%d+$") ~= nil).toBe(true)
			end
		end
	end)

	T.it("ready only with an asset id for every code-drawn sheet (S35); picture sheets do not count", function()
		local ids = {}
		for n = 1, Atlas.SVG_SHEETS do
			ids[n] = `rbxassetid://{n}`
		end
		T.expect(ItemIcons.readyFor(ids)).toBe(true)
		local missing = table.clone(ids)
		missing[Atlas.SVG_SHEETS] = ""
		T.expect(ItemIcons.readyFor(missing)).toBe(false)
		local wrong = table.clone(ids)
		wrong[1] = "oops"
		T.expect(ItemIcons.readyFor(wrong)).toBe(false)
		T.expect(ItemIcons.readyFor({})).toBe(false)
	end)

	T.it("pictures per sheet (S52): a ready picture wins, otherwise the code-drawn icon", function()
		local all = function(_n: number): boolean
			return true
		end
		local svgOnly = function(n: number): boolean
			return n <= Atlas.SVG_SHEETS
		end
		local none = function(_n: number): boolean
			return false
		end
		for key, icon in Atlas.PNG do
			local base = string.match(key, "^eq/(.+)@(%d+)$")
			if base then
				local tier = tonumber(string.match(key, "@(%d+)$")) :: number
				local def = Items.get(`{base}_{tier}`) :: any
				local withAccent = false
				for _, layer in icon.layers do
					withAccent = withAccent or layer.t == "accent"
				end
				if def.elemental and not withAccent then
					-- Mage weapons keep the drawn icon (element accent) until the picture has an accent layer.
					local fire = ItemIcons.resolve(def, "fire", all) :: any
					local ice = ItemIcons.resolve(def, "ice", all) :: any
					T.expect(fire.key).toBe(`eq/{base}`)
					T.expect(fire.layers[#fire.layers].tint == ice.layers[#ice.layers].tint).toBe(false)
					continue
				end
				T.expect((ItemIcons.resolve(def, nil, all) :: any).key).toBe(key)
				T.expect((ItemIcons.resolve(def, nil, svgOnly) :: any).key).toBe(`eq/{base}`)
				-- A higher tier without its own picture takes this one (or a nearer one), never a higher tier's.
				local higher = Items.get(`{base}_100`) :: any
				local picked = (ItemIcons.resolve(higher, nil, all) :: any).key
				T.expect(string.match(picked, "^eq/" .. base .. "@") ~= nil).toBe(true)
				T.expect(icon.layers[1].s > Atlas.SVG_SHEETS).toBe(true)
			end
		end
		T.expect(ItemIcons.resolve(Items.get("sword1h_1") :: any, nil, none)).toBeNil()
		-- Default readiness = the sheet has an asset id (server and wiki): sheets without ids keep the drawn icon.
		for key, icon in Atlas.PNG do
			if not ItemIcons.hasId(icon.layers[1].s) then
				T.expect(ItemIcons.iconOf(key) == icon).toBe(false)
			end
		end
	end)

	T.it("item pictures come before shared keys, a lower tier only from the same type (S52)", function()
		local fake = {
			["eq/sword1h@5"] = true,
			["mat/ore_copper"] = true,
		}
		local function first(def: any): string?
			for _, c in ItemIcons.candidates(def) do
				if fake[c.key] or Atlas.ICONS[c.key] then
					return c.key
				end
			end
			return nil
		end
		T.expect(first(Items.get("sword1h_1"))).toBe("eq/sword1h")
		T.expect(first(Items.get("sword1h_5"))).toBe("eq/sword1h@5")
		T.expect(first(Items.get("sword1h_70"))).toBe("eq/sword1h@5")
		T.expect(first(Items.get("unique_grimrok_cleaver"))).toBe("uniq/unique_grimrok_cleaver")
		T.expect(first(Items.get("ore_copper"))).toBe("mat/ore_copper")
		T.expect(first(Items.get("ore_iron"))).toBe("mat/ore")
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
