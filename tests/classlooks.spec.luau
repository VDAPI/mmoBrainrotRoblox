--!strict
-- Class looks (S132, DESIGN-17 §9a): the data of Data/ClassLooks and the class outfits of Data/Cosmetics, the pure
-- rules of Logic/CharacterLook (validation, resolve, budget, cost, scales, outfits from the game) and the saved looks
-- of Logic/Premium.

local BodyLooks = require("../src/shared/Data/BodyLooks")
local Bosses = require("../src/shared/Data/Bosses")
local CharacterLook = require("../src/shared/Logic/CharacterLook")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local CosmeticRules = require("../src/shared/Logic/CosmeticRules")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Premium = require("../src/shared/Logic/Premium")
local Quests = require("../src/shared/Data/Quests")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local HEX = "^#%x%x%x%x%x%x$"
local QUEST = "queensLegacy"

local function hex(value: any): boolean
	return type(value) == "string" and string.match(value, HEX) ~= nil
end

local function bothLanguages(key: string)
	T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- A class's outfit with its procedural garments only: no catalog item, no classic clothes (the classes wear catalog
-- sets since the block body, 2026-11-01; the catalog specs start from the bare garments).
local function procedural(classId: string): any
	local spec: any = deepCopy((ClassLooks.get(classId) :: any).outfit)
	for _, g in spec.garments do
		g.catalog, g.type, g.order, g.also, g.hides = 0, nil, nil, nil, nil
	end
	spec.shirt, spec.pants = 0, 0
	return spec
end

local function names(spec: CharacterLook.LookSpec): { [string]: boolean }
	local out = {}
	for _, g in spec.garments do
		out[g.g] = true
	end
	return out
end

local function classOutfits(classId: string): { Cosmetics.Def }
	local out = {}
	for _, def in Cosmetics.list do
		if def.class == classId then
			table.insert(out, def)
		end
	end
	return out
end

local function input(classId: string, extra: { [string]: any }?): CharacterLook.LookInput
	local i: any = { classId = classId, look = ClassLooks.DEFAULT_LOOK, robloxAvatar = false }
	for k, v in (extra or {}) :: { [string]: any } do
		i[k] = v
	end
	return i
end

T.describe("Class looks: data (S132)", function()
	T.it("1. one default outfit per class, with the class's silhouette", function()
		local want: { [string]: { string } } = {
			Warrior = { "cape" },
			Cleric = { "hood", "holy_symbol" },
			Hunter = { "hood", "quiver_back" },
			Mage = { "high_collar", "belt_book" },
		}
		local count = 0
		for _, classId in Classes.order do
			local look = ClassLooks.get(classId)
			T.expect({ classId, look ~= nil }).toEqual({ classId, true })
			local l = look :: ClassLooks.ClassLook
			count += 1
			T.expect(l.class).toBe(classId)
			T.expect(l.nameKey).toBe(`classlook.{classId}.name`)
			bothLanguages(l.nameKey)
			T.expect({ classId, hex(l.outfit.colors.main), hex(l.outfit.colors.second) })
				.toEqual({ classId, true, true })
			T.expect({ classId, #l.outfit.garments >= 3 }).toEqual({ classId, true })
			T.expect(type(l.layers)).toBe("table")
			local has: { [string]: boolean } = {}
			for _, g in l.outfit.garments do
				has[g.g] = true
			end
			for _, name in want[classId] do
				T.expect({ classId, name, has[name] == true }).toEqual({ classId, name, true })
			end
		end
		T.expect(count).toBe(4)
		local metal = false
		for _, g in (ClassLooks.get("Warrior") :: ClassLooks.ClassLook).outfit.garments do
			if (g.role or (CharacterLook.GARMENTS[g.g] :: any).role) == "metal" then
				metal = true
			end
		end
		T.expect(metal).toBe(true)
	end)

	T.it("2. the creator (W10): every choice list, its ids unique, its names in both languages", function()
		T.expect(#ClassLooks.FACES).toBe(8)
		T.expect(#ClassLooks.SKINS).toBe(12)
		T.expect(#ClassLooks.HAIRS).toBe(12)
		T.expect(#ClassLooks.HAIR_COLORS).toBe(12)
		T.expect(#ClassLooks.BROWS).toBe(6)
		T.expect(#ClassLooks.BEARDS).toBe(6)
		T.expect(#ClassLooks.BUILDS).toBe(3)
		T.expect(#ClassLooks.PAINTS).toBe(6)
		T.expect(#ClassLooks.PAINT_COLORS).toBe(6)
		local seen: { [string]: boolean } = {}
		local function unique(id: string)
			T.expect({ id, seen[id] }).toEqual({ id, nil })
			seen[id] = true
		end
		for _, f in ClassLooks.FACES do
			unique(f.id)
			local head = BodyLooks.heads[f.id]
			T.expect({ f.id, head ~= nil and head.head > 0 and head.lashes > 0 }).toEqual({ f.id, true })
			T.expect({ f.id, f.legacyBeard == nil or ClassLooks.beardById[f.legacyBeard] ~= nil })
				.toEqual({ f.id, true })
			T.expect({ f.id, f.legacyPaint == nil or ClassLooks.paintById[f.legacyPaint] ~= nil })
				.toEqual({ f.id, true })
		end
		for _, s in ClassLooks.SKINS do
			unique(s.id)
			T.expect({ s.id, hex(s.color) }).toEqual({ s.id, true })
		end
		for _, h in ClassLooks.HAIRS do
			unique(h.id)
			T.expect({ h.id, CharacterLook.GARMENTS[`hair_{h.style}`] ~= nil }).toEqual({ h.id, true })
		end
		for _, list in { ClassLooks.HAIR_COLORS, ClassLooks.PAINT_COLORS } do
			for _, c in list do
				unique(c.id)
				T.expect({ c.id, hex(c.color) }).toEqual({ c.id, true })
			end
		end
		for _, b in ClassLooks.BROWS do
			unique(b.id)
			T.expect({ b.id, (BodyLooks.brows[b.id] or 0) > 0 }).toEqual({ b.id, true })
		end
		for _, b in ClassLooks.BUILDS do
			unique(b.id)
			local k = BodyLooks.builds[b.id]
			local within = k ~= nil and math.abs(k.width - 1) <= 0.05 + 1e-9 and math.abs(k.depth - 1) <= 0.05 + 1e-9
			T.expect({ b.id, within }).toEqual({ b.id, true })
		end
		for _, p in ClassLooks.PAINTS do
			unique(p.id)
			T.expect({ p.id, p.id == "paint_none" or BodyLooks.paints[p.id] ~= nil }).toEqual({ p.id, true })
		end
		for _, b in ClassLooks.BEARDS do
			unique(b.id)
		end
		-- every choice has a name in both languages (natural skins are numbered)
		for _, field in CharacterLook.FIELDS do
			for i, entry in field.list do
				if not (field.key == "skin" and i <= CharacterLook.NATURAL_SKINS) then
					bothLanguages(`look.{field.key}.{entry.id}`)
				end
			end
			bothLanguages(`look.row.{field.key}`)
		end
		T.expect(CharacterLook.isValid(ClassLooks.DEFAULT_LOOK)).toBe(true)
		for _, key in { "look.skin.n", "look.random", "look.default", "look.tab.face", "look.tab.hair" } do
			bothLanguages(key)
		end
		bothLanguages("look.tab.body")
		bothLanguages("look.tab.paint")
	end)

	T.it("3. every garment is a known procedural with a slot, parts and both names", function()
		for name, def in CharacterLook.GARMENTS do
			T.expect({ name, table.find(CharacterLook.SLOTS, def.slot) ~= nil, def.pieces > 0 })
				.toEqual({ name, true, true })
			bothLanguages(`garment.{name}`)
		end
		local function check(where: string, garments: { ClassLooks.Garment })
			for _, g in garments do
				T.expect({ where, g.g, CharacterLook.GARMENTS[g.g] ~= nil }).toEqual({ where, g.g, true })
				T.expect({ where, g.g, g.catalog == nil or (g.catalog >= 0 and g.catalog == math.floor(g.catalog)) })
					.toEqual({ where, g.g, true })
				if g.asset then
					T.expect({ where, g.asset, ClassLooks.assets[g.asset] ~= nil }).toEqual({ where, g.asset, true })
				end
			end
		end
		for classId, look in ClassLooks.classes do
			check(classId, look.outfit.garments)
		end
		for _, def in Cosmetics.list do
			if def.kind == "outfit" then
				check(def.id, CharacterLook.outfitSpec(def).garments)
				for _, part in (def.parts or {}) :: { string } do
					T.expect({ def.id, part, CharacterLook.GARMENTS[part] ~= nil }).toEqual({ def.id, part, true })
				end
			end
		end
		for _, h in ClassLooks.HAIRS do
			T.expect({ h.id, h.asset == nil or ClassLooks.assets[h.asset] ~= nil }).toEqual({ h.id, true })
		end
		T.expect(next(ClassLooks.assets)).toBeNil()
	end)

	T.it("4. every look fits the piece budget with the heaviest hairstyle and the lure cape", function()
		local heaviest, most = ClassLooks.HAIRS[1].id, 0
		for _, h in ClassLooks.HAIRS do
			local def = CharacterLook.GARMENTS[`hair_{h.style}`]
			if def and def.pieces > most then
				heaviest, most = h.id, def.pieces
			end
		end
		local look = { face = "face_bearded", skin = "skin_1", hair = heaviest }
		for _, classId in Classes.order do
			local outfits: { string | false } = { false }
			for _, def in Cosmetics.list do
				if CharacterLook.allowed(def, classId) then
					table.insert(outfits, def.id)
				end
			end
			for _, outfit in outfits do
				for _, lure in { false, true } do
					local spec = CharacterLook.resolve(input(classId, {
						look = look,
						outfitId = if outfit then outfit else nil,
						lure = lure,
					}))
					if spec.pieces > Config.CharacterLook.maxPieces then
						error(`{classId} {tostring(outfit)} lure {lure}: {spec.pieces} pieces`)
					end
				end
			end
		end
	end)
end)

T.describe("Class looks: resolve (S132)", function()
	T.it("5a. the class look: its outfit, the skin on skin parts, the hair unless a hood covers it", function()
		local look = { face = "face_stern", skin = "skin_7", hair = "hair_long_red" } -- an S132 save
		local warrior = CharacterLook.resolve(input("Warrior", { look = look }))
		T.expect(warrior.mode).toBe("class")
		T.expect(warrior.skin).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.Head).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.LeftHand).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.UpperTorso).toBe((ClassLooks.get("Warrior") :: any).outfit.colors.main)
		T.expect(names(warrior).cape).toBe(true)
		T.expect((warrior.hair :: CharacterLook.HairSpec).style).toBe("long")
		T.expect((warrior.hair :: CharacterLook.HairSpec).color).toBe(ClassLooks.hairColorById.hc_red.color)
		local face = warrior.face :: CharacterLook.FaceSpec
		T.expect(face.head).toBe(BodyLooks.heads.face_stern.head)
		T.expect(face.hair).toBe(ClassLooks.hairColorById.hc_red.color)
		T.expect(face.beard).toBe("beard_none")
		local hunter = CharacterLook.resolve(input("Hunter", { look = look }))
		T.expect(names(hunter).hood).toBe(true)
		T.expect(hunter.hair).toBeNil()
	end)

	T.it("5b. an own class outfit replaces colours and garments, another class's is ignored", function()
		local base = CharacterLook.resolve(input("Mage"))
		local ember = CharacterLook.resolve(input("Mage", { outfitId = "outfit_mage_ember" }))
		local def = Cosmetics.get("outfit_mage_ember") :: Cosmetics.Def
		T.expect(ember.body.UpperTorso).toBe((def.outfit :: any).colors.main)
		T.expect(names(ember).glow_seams).toBe(true)
		T.expect(names(base).glow_seams).toBeNil()
		local other = CharacterLook.resolve(input("Mage", { outfitId = "outfit_warrior_crimson" }))
		T.expect(other).toEqual(base)
		local shared = CharacterLook.resolve(input("Mage", { outfitId = "outfit_ranger" }))
		T.expect(shared.body.UpperTorso).toBe((Cosmetics.get("outfit_ranger") :: any).color)
		T.expect(names(shared).cape).toBe(true)
	end)

	T.it("5c. the lure keeps the outfit cape and adds its parts to the budget", function()
		local off = CharacterLook.resolve(input("Warrior"))
		local on = CharacterLook.resolve(input("Warrior", { lure = true }))
		T.expect(names(on).cape).toBe(true)
		T.expect(on.pieces).toBe(off.pieces + CharacterLook.LURE_PIECES)
	end)

	T.it("5d. a dye recolours main and second of the default and of a class outfit (S123 rule)", function()
		local dye = Cosmetics.get("dye_crimson") :: Cosmetics.Def
		local plain = CharacterLook.resolve(input("Warrior"))
		local dyed = CharacterLook.resolve(input("Warrior", { dye = "dye_crimson" }))
		local colors = (ClassLooks.get("Warrior") :: any).outfit.colors
		local main, second =
			CosmeticRules.dyed({ kind = "outfit", color = colors.main, color2 = colors.second } :: any, dye)
		T.expect(dyed.body.UpperTorso).toBe(main)
		T.expect(dyed.body.LowerTorso).toBe(second)
		T.expect(plain.body.UpperTorso).toBe(colors.main)
		local outfit = CharacterLook.resolve(input("Hunter", { outfitId = "outfit_hunter_tracker", dye = "dye_azure" }))
		T.expect(outfit.body.UpperTorso).toBe((Cosmetics.get("dye_azure") :: any).dye.main)
		-- without a dye (or with something that is not a dye) nothing changes
		T.expect(CharacterLook.resolve(input("Warrior", { dye = "aura_gold" }))).toEqual(plain)
	end)

	T.it("5e. avatar mode: nothing without an outfit, the outfit's pieces with one", function()
		local bare = CharacterLook.resolve(input("Cleric", { robloxAvatar = true }))
		T.expect(bare.mode).toBe("avatar")
		T.expect(next(bare.body)).toBeNil()
		T.expect(#bare.garments).toBe(0)
		T.expect({ bare.face, bare.hair, bare.skin }).toEqual({ nil, nil, nil })
		local dressed = CharacterLook.resolve(input("Cleric", { robloxAvatar = true, outfitId = "outfit_cleric_dawn" }))
		T.expect(names(dressed).holy_symbol).toBe(true)
		T.expect(dressed.body.Head).toBeNil()
		T.expect(dressed.body.UpperTorso).toBe((Cosmetics.get("outfit_cleric_dawn") :: any).color)
	end)

	T.it("5f. the catalog key: stable with every id 0, changed by a catalog id; the input is never changed", function()
		local class = CharacterLook.resolve(input("Warrior", { spec = procedural("Warrior") }))
		-- W10: the same look on another class (no catalog ids either) gives the same key
		T.expect(class.catalogKey)
			.toBe(CharacterLook.resolve(input("Cleric", { spec = procedural("Cleric") })).catalogKey)
		T.expect(#class.accessories).toBe(0)
		-- (the classes' own catalog sets give each class its key)
		T.expect(CharacterLook.resolve(input("Warrior")).catalogKey ~= class.catalogKey).toBe(true)
		local spec: any = procedural("Warrior")
		spec.garments[1].catalog = 12345
		spec.shirt = 777
		local withIds = CharacterLook.resolve(input("Warrior", { spec = spec }))
		T.expect(withIds.catalogKey ~= class.catalogKey).toBe(true)
		-- a bare `catalog = id` stays a rigid hat entry (catalog clothing 2026-11-01)
		T.expect(withIds.accessories).toEqual({ { id = 12345, type = "Hat", layered = false } })
		T.expect(withIds.shirt).toBe(777)
		T.expect(withIds.pieces < class.pieces).toBe(true)
		local look = { face = "face_young", skin = "skin_2", hair = "hair_braid_dark" }
		local i = input("Cleric", { look = look, outfitId = "outfit_cleric_dawn", dye = "dye_gold", lure = true })
		local before = deepCopy(i)
		local beforeData = deepCopy((Cosmetics.get("outfit_cleric_dawn") :: any).outfit)
		CharacterLook.resolve(i)
		T.expect(i).toEqual(before)
		T.expect((Cosmetics.get("outfit_cleric_dawn") :: any).outfit).toEqual(beforeData)
	end)
end)

T.describe("Class looks: validation, cost, scales (S132)", function()
	T.it("6. normalize, isValid, changeCost and canChange", function()
		local d = CharacterLook.normalize(nil)
		T.expect(d).toEqual(table.clone(ClassLooks.DEFAULT_LOOK) :: any)
		T.expect(d == (ClassLooks.DEFAULT_LOOK :: any)).toBe(false)
		-- W10: an S132 save keeps its face; its hair id splits into style and colour
		local mixed = { face = "x", skin = "skin_2", hair = "hair_long_red" }
		local fixed = CharacterLook.normalize(mixed) :: any
		T.expect({ fixed.face, fixed.skin, fixed.hair, fixed.hairColor })
			.toEqual({ ClassLooks.DEFAULT_LOOK.face, "skin_2", "hair_long", "hc_red" })
		T.expect(fixed == mixed).toBe(false)
		local valid = CharacterLook.normalize({ face = "face_calm", skin = "skin_1", hair = "hair_shaved" })
		T.expect({ CharacterLook.isValid(valid) }).toEqual({ true, nil })
		local bad = table.clone(valid) :: any
		bad.skin = "skin_13"
		T.expect({ CharacterLook.isValid(bad) }).toEqual({ false, "look.error.bad" })
		T.expect({ CharacterLook.isValid({ face = "face_calm", skin = "skin_1", hair = "hair_shaved" }) })
			.toEqual({ false, "look.error.bad" })
		T.expect({ CharacterLook.isValid(1) }).toEqual({ false, "look.error.bad" })

		local cfg = Config.LookChange
		T.expect({ CharacterLook.changeCost({ lookFree = true, level = 50 }) }).toEqual({ 0, true })
		T.expect({ CharacterLook.changeCost({ lookFree = false, level = 5 }) }).toEqual({ cfg.goldMin, false })
		T.expect({ CharacterLook.changeCost({ lookFree = false, level = 80 }) })
			.toEqual({ cfg.goldPerLevel * 80, false })

		local current = { face = "face_calm", skin = "skin_4", hair = "hair_short_dark" } -- an S132 save
		local other = CharacterLook.normalize({ face = "face_sharp", skin = "skin_4", hair = "hair_short_dark" })
		local paid = { look = current, lookFree = false, level = 80, gold = cfg.goldPerLevel * 80 }
		local nope = table.clone(other) :: any
		nope.face = "nope"
		T.expect({ CharacterLook.canChange(paid, nope, true) })
			.toEqual({ false, "look.error.bad", cfg.goldPerLevel * 80 })
		T.expect((select(2, CharacterLook.canChange(paid, CharacterLook.normalize(current), true))))
			.toBe("look.error.same")
		T.expect((select(2, CharacterLook.canChange(paid, other, false)))).toBe("look.error.barber")
		T.expect({ CharacterLook.canChange(paid, other, true) }).toEqual({ true, nil, cfg.goldPerLevel * 80 })
		local poor = table.clone(paid)
		poor.gold -= 1
		T.expect((select(2, CharacterLook.canChange(poor, other, true)))).toBe("look.error.gold")
		local free = { look = current, lookFree = true, level = 80, gold = 0 }
		T.expect({ CharacterLook.canChange(free, other, false) }).toEqual({ true, nil, 0 })
		-- the order: the same look before the barber, the barber before the gold
		T.expect(
			(
				select(
					2,
					CharacterLook.canChange(
						{ look = current, lookFree = false, level = 1, gold = 0 },
						CharacterLook.normalize(current),
						false
					)
				)
			)
		).toBe("look.error.same")
		T.expect(
			(
				select(
					2,
					CharacterLook.canChange({ look = current, lookFree = false, level = 1, gold = 0 }, other, false)
				)
			)
		)
			.toBe("look.error.barber")
		for _, key in
			{
				"look.error.bad",
				"look.error.same",
				"look.error.barber",
				"look.error.gold",
				"look.cost.free",
				"look.cost.gold",
			}
		do
			bothLanguages(key)
		end
	end)

	T.it("7. avatar scales clamped, the class look standard", function()
		local limits = Config.CharacterLook.avatarScale
		local clamped =
			CharacterLook.clampScales({ height = 1.3, width = 0.5, depth = 1, head = 2, bodyType = 1, proportion = 1 })
		T.expect(clamped).toEqual({
			height = limits.height[2],
			width = limits.width[1],
			depth = 1,
			head = limits.head[2],
			bodyType = limits.bodyType[2],
			proportion = limits.proportion[2],
		})
		local odd = CharacterLook.clampScales({ height = 0 / 0 })
		T.expect(odd).toEqual(table.clone(CharacterLook.STANDARD))
		T.expect(CharacterLook.STANDARD.bodyType).toBe(0)
		T.expect(CharacterLook.STANDARD.proportion).toBe(0)
	end)
end)

T.describe("Class looks: outfits of the classes (S132)", function()
	T.it("8. per class 3 for shards and 2 from the game; quest and boss outfits point at real ones", function()
		for _, classId in Classes.order do
			local sold, earned = 0, 0
			for _, def in classOutfits(classId) do
				if def.price > 0 then
					sold += 1
					T.expect({ def.id, def.obtain }).toEqual({ def.id, nil })
				elseif def.obtain then
					earned += 1
				end
			end
			T.expect({ classId, sold, earned }).toEqual({ classId, 3, 2 })
			local lower = string.lower(classId)
			T.expect(CharacterLook.questOutfits(QUEST, classId)).toEqual({ `outfit_{lower}_duskwood` })
			T.expect(CharacterLook.bossWinOutfits("azgor", classId)).toEqual({ `outfit_{lower}_ashen` })
			T.expect(CharacterLook.bossWinOutfits("morvane", classId)).toEqual({})
		end
		for _, def in Cosmetics.list do
			if def.class ~= nil then
				T.expect({ def.id, def.kind, Classes.get(def.class) ~= nil }).toEqual({ def.id, "outfit", true })
			end
			if def.outfit ~= nil then
				T.expect({ def.id, def.kind }).toEqual({ def.id, "outfit" })
			end
			local obtain = def.obtain
			if obtain and obtain.bossWin then
				T.expect({ def.id, Bosses.get(obtain.bossWin) ~= nil, def.class ~= nil })
					.toEqual({ def.id, true, true })
			end
			if obtain and obtain.quest and def.class then
				T.expect({ def.id, Quests.categoryOf(obtain.quest) ~= nil }).toEqual({ def.id, true })
			end
		end
		-- earned again from the save: only what the proof says
		local got = CharacterLook.earnedOutfits("Hunter", function(id)
			return id == QUEST
		end, function(_id)
			return false
		end)
		T.expect(got).toEqual({ "outfit_hunter_duskwood" })
		local both = CharacterLook.earnedOutfits("Mage", function(_id)
			return true
		end, function(id)
			return id == "azgor"
		end)
		T.expect(table.find(both, "outfit_mage_ashen") ~= nil and table.find(both, "outfit_mage_duskwood") ~= nil)
			.toBe(true)
		T.expect(table.find(both, "outfit_hunter_ashen")).toBeNil()
		for _, key in
			{ "wardrobe.onlyFor", "wardrobe.obtain.bossWin", "wardrobe.classDefault", "wardrobe.error.otherClass" }
		do
			bothLanguages(key)
		end
	end)

	T.it("9. saved looks: the class outfit only on its class, never in equipped", function()
		local owned = { outfit_warrior_vanguard = true, outfit_ranger = true, aura_gold = true, dye_crimson = true }
		local set: any = {
			equipped = { outfit = "outfit_warrior_vanguard", aura = "aura_gold", dye = "dye_crimson" },
			class = "Warrior",
		}
		local looks, pet, outfit = Premium.applySet(set, "Mage", owned, {})
		T.expect(outfit).toBeNil()
		T.expect(looks).toEqual({ aura = "aura_gold", dye = "dye_crimson" })
		T.expect(pet).toBeNil()
		local _, _, warrior = Premium.applySet(set, "Warrior", owned, {})
		T.expect(warrior).toBe("outfit_warrior_vanguard")
		local old: any = { equipped = { outfit = "outfit_ranger" } }
		for _, classId in Classes.order do
			local l, _, o = Premium.applySet(old, classId, owned, {})
			T.expect({ classId, o, l.outfit }).toEqual({ classId, "outfit_ranger", nil })
		end
		local _, _, notOwned = Premium.applySet(old, "Mage", {}, {})
		T.expect(notOwned).toBeNil()
		local cosmetics = { equipped = { aura = "aura_gold" }, classOutfits = { Mage = "outfit_mage_ember" } }
		local snap = Premium.snapshotOutfit(cosmetics, { equipped = "pet_fox" }, "Mage")
		T.expect(snap)
			.toEqual({ equipped = { aura = "aura_gold", outfit = "outfit_mage_ember" }, pet = "pet_fox", class = "Mage" })
		T.expect(cosmetics.equipped.outfit).toBeNil()
		T.expect(Premium.snapshotOutfit(cosmetics, { equipped = nil })).toEqual({ equipped = { aura = "aura_gold" } })
		bothLanguages("wardrobe.set.class")
	end)
end)

-- Catalog clothing 2026-11-01 (docs/WYGLAD-KLAS.md §3): a catalog item says its accessory type and layer order, may
-- cover more garments than its own and bring a second item; classic clothing per class; the dev trial.
local function warriorWith(fields: { [number]: { [string]: any } }): any
	local spec: any = procedural("Warrior")
	for i, item in fields do
		for k, v in item do
			spec.garments[i][k] = v
		end
	end
	return spec
end

local function garmentOf(spec: CharacterLook.LookSpec, g: string): CharacterLook.GarmentSpec
	for _, item in spec.garments do
		if item.g == g then
			return item
		end
	end
	error(`no garment {g}`)
end

local function pieceCount(g: string): number
	return (CharacterLook.GARMENTS[g] :: CharacterLook.GarmentDef).pieces
end

T.describe("Class looks: catalog clothing (2026-11-01)", function()
	T.it(
		"10. the accessory types: Roblox's default layer orders, a field for every rigid type, catalog spellings",
		function()
			local layered: { [string]: number } = {
				LeftShoe = 3,
				RightShoe = 3,
				Pants = 4,
				Shorts = 5,
				DressSkirt = 6,
				TShirt = 7,
				Shirt = 8,
				Sweater = 9,
				Jacket = 10,
			}
			local rigid: { [string]: string } = {
				Hat = "HatAccessory",
				Hair = "HairAccessory",
				Face = "FaceAccessory",
				Neck = "NeckAccessory",
				Shoulder = "ShouldersAccessory",
				Front = "FrontAccessory",
				Back = "BackAccessory",
				Waist = "WaistAccessory",
			}
			local count = 0
			for name, def in ClassLooks.CATALOG_TYPES do
				count += 1
				if def.layered then
					T.expect({ name, def.order, def.field }).toEqual({ name, layered[name], nil })
				else
					T.expect({ name, def.order, def.field }).toEqual({ name, nil, rigid[name] })
				end
			end
			T.expect(count).toBe(17)
			T.expect(ClassLooks.CATALOG_TYPES[ClassLooks.DEFAULT_CATALOG_TYPE].layered).toBe(false)
			T.expect(CharacterLook.catalogType("JacketAcc")).toBe("Jacket")
			T.expect(CharacterLook.catalogType("dressskirtacc")).toBe("DressSkirt")
			T.expect(CharacterLook.catalogType("PantsAccessory")).toBe("Pants")
			T.expect(CharacterLook.catalogType("Shoulders")).toBe("Shoulder")
			T.expect(CharacterLook.catalogType("tshirt")).toBe("TShirt")
			T.expect(CharacterLook.catalogType("Cape")).toBeNil()
			T.expect(CharacterLook.catalogType(nil)).toBeNil()
		end
	)

	T.it("11. a catalog piece: a bare id is a rigid hat, a layered type takes its default order or its own", function()
		T.expect(CharacterLook.catalogPiece(55)).toEqual({ id = 55, type = "Hat", layered = false })
		T.expect(CharacterLook.catalogPiece(55, "Back", 4)).toEqual({ id = 55, type = "Back", layered = false })
		T.expect(CharacterLook.catalogPiece(55, "Jacket"))
			.toEqual({ id = 55, type = "Jacket", layered = true, order = 10 })
		T.expect(CharacterLook.catalogPiece(55, "Pants", 12))
			.toEqual({ id = 55, type = "Pants", layered = true, order = 12 })
		T.expect(CharacterLook.catalogPiece(55, "nonsense")).toEqual({ id = 55, type = "Hat", layered = false })
		T.expect(CharacterLook.catalogPiece(0, "Jacket")).toBeNil()
		T.expect(CharacterLook.catalogPiece(nil)).toBeNil()
		local pair =
			{ g = "plate_pauldrons", catalog = 7, type = "Shoulder", also = { { catalog = 8, type = "Shoulder" } } }
		T.expect(CharacterLook.garmentPieces(pair :: any)).toEqual({
			{ id = 7, type = "Shoulder", layered = false },
			{ id = 8, type = "Shoulder", layered = false },
		})
		T.expect(CharacterLook.garmentPieces({ g = "boots", catalog = 0, also = { { catalog = 8 } } } :: any))
			.toEqual({})
	end)

	T.it("12. a layered jacket worn for the breastplate covers the belt and the pauldrons", function()
		local plain = CharacterLook.resolve(input("Warrior", { spec = procedural("Warrior") }))
		local spec = warriorWith({
			[1] = { catalog = 9001, type = "Jacket", hides = { "belt", "plate_pauldrons" } },
		})
		local dressed = CharacterLook.resolve(input("Warrior", { spec = spec }))
		T.expect(dressed.accessories).toEqual({ { id = 9001, type = "Jacket", layered = true, order = 10 } })
		T.expect(garmentOf(dressed, "breastplate").catalog).toBe(9001)
		T.expect(garmentOf(dressed, "breastplate").hidden).toBeNil()
		T.expect(garmentOf(dressed, "belt").hidden).toBe(true)
		T.expect(garmentOf(dressed, "plate_pauldrons").hidden).toBe(true)
		T.expect(garmentOf(dressed, "cape").hidden).toBeNil()
		T.expect(plain.pieces - dressed.pieces)
			.toBe(pieceCount("breastplate") + pieceCount("belt") + pieceCount("plate_pauldrons"))
		-- the jacket's type and order are in the key: another order re-applies the description
		local reordered = warriorWith({ [1] = { catalog = 9001, type = "Jacket", order = 11 } })
		T.expect(CharacterLook.resolve(input("Warrior", { spec = reordered })).catalogKey ~= dressed.catalogKey)
			.toBe(true)
		-- `hides` only counts while the item is set
		local unset = warriorWith({ [1] = { catalog = 0, type = "Jacket", hides = { "belt" } } })
		local procedural = CharacterLook.resolve(input("Warrior", { spec = unset }))
		T.expect(garmentOf(procedural, "belt").hidden).toBeNil()
		T.expect(procedural.pieces).toBe(plain.pieces)
		T.expect(procedural.catalogKey).toBe(plain.catalogKey)
	end)

	T.it(
		"13. a hood's catalog item hides the hair, a covered hood does not; catalog shoes need no plain shoes",
		function()
			local look = { face = "face_calm", skin = "skin_3", hair = "hair_long" }
			local hunter: any = procedural("Hunter")
			T.expect(CharacterLook.resolve(input("Hunter", { look = look, spec = hunter })).hair).toBeNil()
			hunter.garments[2].catalog = 617605556 -- the hood as a catalog hat
			T.expect(CharacterLook.resolve(input("Hunter", { look = look, spec = hunter })).hair).toBeNil()
			hunter.garments[2].catalog = 0
			hunter.garments[1].catalog = 9002 -- a vest that covers the hood
			hunter.garments[1].hides = { "hood" }
			T.expect(CharacterLook.resolve(input("Hunter", { look = look, spec = hunter })).hair ~= nil).toBe(true)
			T.expect(CharacterLook.resolve(input("Warrior", { spec = procedural("Warrior") })).shoes).toBe(true)
			T.expect(CharacterLook.resolve(input("Hunter", { spec = procedural("Hunter") })).shoes).toBe(false) -- boots
			T.expect(CharacterLook.resolve(input("Warrior", { robloxAvatar = true })).shoes).toBe(false)
			local shod = warriorWith({
				[4] = { catalog = 31, type = "LeftShoe", also = { { catalog = 32, type = "RightShoe" } } },
			})
			local spec = CharacterLook.resolve(input("Warrior", { spec = shod }))
			T.expect(spec.shoes).toBe(false)
			T.expect(#spec.accessories).toBe(2)
		end
	)

	T.it(
		"14. the data: known types, orders only on layered items, `hides` names other garments of the outfit",
		function()
			local function check(where: string, spec: ClassLooks.OutfitSpec)
				T.expect({ where, type(spec.shirt), type(spec.pants) }).toEqual({ where, "number", "number" })
				local names: { [string]: boolean } = {}
				for _, g in spec.garments do
					names[g.g] = true
				end
				local function item(g: string, catalog: any, kind: any, order: any)
					T.expect({ where, g, kind == nil or ClassLooks.CATALOG_TYPES[kind] ~= nil })
						.toEqual({ where, g, true })
					local layered = kind ~= nil and ClassLooks.CATALOG_TYPES[kind].layered
					T.expect({ where, g, order == nil or (layered and order == math.floor(order) and order >= 0) })
						.toEqual({ where, g, true })
					T.expect({ where, g, type(catalog) == "number" and catalog == math.floor(catalog) and catalog >= 0 })
						.toEqual({ where, g, true })
				end
				for _, g in spec.garments do
					item(g.g, g.catalog or 0, g.type, g.order)
					for _, ref in g.also or {} do
						item(g.g, ref.catalog, ref.type, ref.order)
						T.expect({ where, g.g, (g.catalog or 0) ~= 0 and ref.catalog ~= 0 })
							.toEqual({ where, g.g, true })
					end
					for _, name in g.hides or {} do
						T.expect({ where, g.g, name, names[name] == true, name ~= g.g })
							.toEqual({ where, g.g, name, true, true })
						for _, other in spec.garments do
							if other.g == name then
								-- a covered garment brings no item of its own
								T.expect({ where, name, other.catalog or 0 }).toEqual({ where, name, 0 })
							end
						end
					end
				end
			end
			for classId, look in ClassLooks.classes do
				check(classId, look.outfit)
			end
			for _, def in Cosmetics.list do
				if def.kind == "outfit" and def.class then
					check(def.id, CharacterLook.outfitSpec(def))
				end
			end
		end
	)

	T.it(
		"15. classic Shirt / Pants of a class reach the look, the description's accessory list keeps its own",
		function()
			local spec: any = deepCopy((ClassLooks.get("Mage") :: any).outfit)
			spec.shirt, spec.pants = 90288143423440, 115998093387659
			local mage = CharacterLook.resolve(input("Mage", { spec = spec }))
			T.expect({ mage.shirt, mage.pants }).toEqual({ 90288143423440, 115998093387659 })
			local avatar = CharacterLook.resolve(input("Mage", { spec = spec, robloxAvatar = true }))
			T.expect({ avatar.shirt, avatar.pants }).toEqual({ 90288143423440, 115998093387659 })
			local brows = { AssetId = 1, AccessoryType = "Eyebrow", IsLayered = true, Order = 1 }
			local hat = { AssetId = 2, AccessoryType = "Hat", IsLayered = false }
			local jacket = CharacterLook.catalogPiece(9001, "Jacket") :: CharacterLook.CatalogPiece
			local cape = CharacterLook.catalogPiece(9003, "Back") :: CharacterLook.CatalogPiece
			T.expect(CharacterLook.accessoryList({ brows, hat }, { jacket, cape }, false)).toEqual({
				brows,
				hat,
				{ AssetId = 9001, AccessoryType = "Jacket", IsLayered = true, Order = 10 },
				{ AssetId = 9003, AccessoryType = "Back", IsLayered = false },
			})
			-- avatar mode: an outfit's layered item takes the place of the avatar's of its type or category
			local own = {
				{ AssetId = 11, AccessoryType = "Jacket", IsLayered = true, Order = 10 },
				{ AssetId = 12, AccessoryType = "Shirt", IsLayered = true, Order = 8 },
				{ AssetId = 13, AccessoryType = "Pants", IsLayered = true, Order = 4 },
				hat,
			}
			local sweater = CharacterLook.catalogPiece(9004, "Sweater") :: CharacterLook.CatalogPiece
			local list = CharacterLook.accessoryList(own, { jacket, sweater, cape }, true)
			local ids = {}
			for _, entry in list do
				table.insert(ids, entry.AssetId)
			end
			T.expect(ids).toEqual({ 13, 2, 9001, 9004, 9003 })
		end
	)

	T.it(
		"16. a trial: items over the look, garments off, bare, no hair, another body; the input never changes",
		function()
			local look = { face = "face_calm", skin = "skin_3", hair = "hair_long" }
			local warrior = procedural("Warrior")
			local plain = CharacterLook.resolve(input("Warrior", { look = look, spec = warrior }))
			local jacket = CharacterLook.catalogPiece(9001, "Jacket") :: CharacterLook.CatalogPiece
			local trial: CharacterLook.Trial =
				{ pieces = { jacket }, hide = { "breastplate" }, body = { Torso = 11702287641 } }
			local before = deepCopy(trial)
			local tried = CharacterLook.resolve(input("Warrior", { look = look, spec = warrior, trial = trial }))
			T.expect(trial).toEqual(before)
			T.expect(tried.accessories).toEqual({ jacket })
			T.expect(garmentOf(tried, "breastplate").hidden).toBe(true)
			T.expect(garmentOf(tried, "cape").hidden).toBeNil()
			T.expect(tried.bodyParts).toEqual({ Torso = 11702287641 })
			T.expect(tried.pieces).toBe(plain.pieces - pieceCount("breastplate"))
			T.expect(tried.catalogKey ~= plain.catalogKey).toBe(true)
			T.expect(tried.hair ~= nil).toBe(true)
			local bare = CharacterLook.resolve(
				input("Warrior", { look = look, spec = warrior, trial = { bare = true, hideHair = true } })
			)
			for _, g in bare.garments do
				T.expect({ g.g, g.hidden }).toEqual({ g.g, true })
			end
			T.expect({ bare.hair, bare.shoes, #bare.accessories }).toEqual({ nil, false, 0 })
			T.expect(bare.catalogKey).toBe(plain.catalogKey) -- nothing of the description changes
			local key = CharacterLook.lookKey(plain)
			T.expect(key).toBe(`class|{plain.catalogKey}`)
		end
	)
end)
