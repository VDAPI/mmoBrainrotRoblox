--!strict
-- Class looks (S132, DESIGN-17 §9a): the data of Data/ClassLooks and the class outfits of Data/Cosmetics, the pure
-- rules of Logic/CharacterLook (validation, resolve, budget, cost, scales, outfits from the game) and the saved looks
-- of Logic/Premium.

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

	T.it("2. the creator: 8 faces, 10 skins, 12 hairstyles with valid parts and names", function()
		T.expect(#ClassLooks.FACES).toBe(8)
		T.expect(#ClassLooks.SKINS).toBe(10)
		T.expect(#ClassLooks.HAIRS).toBe(12)
		local seen: { [string]: boolean } = {}
		local function unique(id: string)
			T.expect({ id, seen[id] }).toEqual({ id, nil })
			seen[id] = true
		end
		local function isIn(list: { string }, value: string?): boolean
			return value ~= nil and table.find(list, value) ~= nil
		end
		local function catalogOk(n: any): boolean
			return n == nil or (type(n) == "number" and n >= 0 and n == math.floor(n))
		end
		for _, f in ClassLooks.FACES do
			unique(f.id)
			T.expect({
				f.id,
				isIn(CharacterLook.FACE_PARTS.eyes, f.eyes),
				isIn(CharacterLook.FACE_PARTS.brows, f.brows),
				isIn(CharacterLook.FACE_PARTS.mouth, f.mouth),
				f.mark == nil or isIn(CharacterLook.FACE_PARTS.mark, f.mark),
				catalogOk(f.catalog),
			}).toEqual({ f.id, true, true, true, true, true })
			bothLanguages(`look.face.{f.id}`)
		end
		for _, s in ClassLooks.SKINS do
			unique(s.id)
			T.expect({ s.id, hex(s.color) }).toEqual({ s.id, true })
		end
		for _, h in ClassLooks.HAIRS do
			unique(h.id)
			T.expect({ h.id, CharacterLook.GARMENTS[`hair_{h.style}`] ~= nil, hex(h.color), catalogOk(h.catalog) })
				.toEqual({ h.id, true, true, true })
			bothLanguages(`look.hair.{h.id}`)
		end
		local d = ClassLooks.DEFAULT_LOOK
		T.expect({
			ClassLooks.faceById[d.face] ~= nil,
			ClassLooks.skinById[d.skin] ~= nil,
			ClassLooks.hairById[d.hair] ~= nil,
		}).toEqual({ true, true, true })
		for _, key in
			{ "look.skin.n", "look.row.face", "look.row.skin", "look.row.hair", "look.random", "look.default" }
		do
			bothLanguages(key)
		end
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
		local look = { face = "face_stern", skin = "skin_7", hair = "hair_long_red" }
		local warrior = CharacterLook.resolve(input("Warrior", { look = look }))
		T.expect(warrior.mode).toBe("class")
		T.expect(warrior.skin).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.Head).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.LeftHand).toBe(ClassLooks.skinById.skin_7.color)
		T.expect(warrior.body.UpperTorso).toBe((ClassLooks.get("Warrior") :: any).outfit.colors.main)
		T.expect(names(warrior).cape).toBe(true)
		T.expect((warrior.hair :: CharacterLook.HairSpec).style).toBe("long")
		T.expect((warrior.face :: CharacterLook.FaceSpec).eyes).toBe("narrow")
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
		local class = CharacterLook.resolve(input("Warrior"))
		local avatar = CharacterLook.resolve(input("Warrior", { robloxAvatar = true, outfitId = "outfit_ranger" }))
		T.expect(class.catalogKey).toBe(avatar.catalogKey)
		T.expect(#class.accessories).toBe(0)
		local spec: any = deepCopy((ClassLooks.get("Warrior") :: any).outfit)
		spec.garments[1].catalog = 12345
		spec.shirt = 777
		local withIds = CharacterLook.resolve(input("Warrior", { spec = spec }))
		T.expect(withIds.catalogKey ~= class.catalogKey).toBe(true)
		T.expect(withIds.accessories).toEqual({ 12345 })
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
		T.expect(d).toEqual({
			face = ClassLooks.DEFAULT_LOOK.face,
			skin = ClassLooks.DEFAULT_LOOK.skin,
			hair = ClassLooks.DEFAULT_LOOK.hair,
		})
		T.expect(d == (ClassLooks.DEFAULT_LOOK :: any)).toBe(false)
		local mixed = { face = "x", skin = "skin_2", hair = "hair_long_red" }
		local fixed = CharacterLook.normalize(mixed)
		T.expect(fixed).toEqual({ face = ClassLooks.DEFAULT_LOOK.face, skin = "skin_2", hair = "hair_long_red" })
		T.expect(fixed == mixed).toBe(false)
		T.expect({ CharacterLook.isValid("face_calm", "skin_1", "hair_shaved") }).toEqual({ true, nil })
		T.expect({ CharacterLook.isValid("face_calm", "skin_11", "hair_shaved") }).toEqual({ false, "look.error.bad" })
		T.expect({ CharacterLook.isValid(1, "skin_1", "hair_shaved") }).toEqual({ false, "look.error.bad" })

		local cfg = Config.LookChange
		T.expect({ CharacterLook.changeCost({ lookFree = true, level = 50 }) }).toEqual({ 0, true })
		T.expect({ CharacterLook.changeCost({ lookFree = false, level = 5 }) }).toEqual({ cfg.goldMin, false })
		T.expect({ CharacterLook.changeCost({ lookFree = false, level = 80 }) })
			.toEqual({ cfg.goldPerLevel * 80, false })

		local current = { face = "face_calm", skin = "skin_4", hair = "hair_short_dark" }
		local other = { face = "face_sharp", skin = "skin_4", hair = "hair_short_dark" }
		local paid = { look = current, lookFree = false, level = 80, gold = cfg.goldPerLevel * 80 }
		T.expect({ CharacterLook.canChange(paid, { face = "nope", skin = "skin_4", hair = "hair_short_dark" }, true) })
			.toEqual({ false, "look.error.bad", cfg.goldPerLevel * 80 })
		T.expect((select(2, CharacterLook.canChange(paid, current, true)))).toBe("look.error.same")
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
					CharacterLook.canChange({ look = current, lookFree = false, level = 1, gold = 0 }, current, false)
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
