--!strict
-- classlooks.json (S132, DESIGN-17 §9a): the class looks. Per class the default outfit (its name, the main / second /
-- trim colours, the translated names of its garments) and the ids of the class outfits with where they come from (shop,
-- quest, boss; details of each outfit in cosmetics.json); the number of faces and hairstyles and the skin swatches of the
-- creator. Reads only Data/ClassLooks, Data/Classes, Data/Cosmetics (class, obtain kind) and Logic/CharacterLook
-- (garment names). Never a catalog id, a model path, a price or Data/Products (docs/WIKI.md §1).

local CharacterLook = require("../../src/shared/Logic/CharacterLook")
local ClassLooks = require("../../src/shared/Data/ClassLooks")
local Classes = require("../../src/shared/Data/Classes")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Names = require("./Names")
local Schema = require("./Schema")

local S = Schema
local arr, rec, enum = S.arr, S.rec, S.enum

local ClassLooksWiki = {}

S.file(
	"classlooks",
	rec("ClassLooksFile", {
		classes = arr(rec("ClassLook", {
			class = enum("ClassId"),
			name = "name",
			colors = rec("LookColors", { main = "color", second = "color", trim = "color" }),
			garments = arr("name"),
			-- source: "shop" (Dragon Shards, no price here), "quest" (a story quest), "boss" (a boss defeated with the class)
			outfits = arr(rec("ClassOutfit", { id = "string", source = "string" })),
		})),
		faces = "int",
		hairs = "int",
		skins = arr("color"),
	})
)

local function sourceOf(def: Cosmetics.Def): string
	local obtain = def.obtain
	if obtain and obtain.bossWin then
		return "boss"
	elseif obtain and obtain.quest then
		return "quest"
	end
	return "shop"
end

function ClassLooksWiki.build(ctx: any): any
	local classes = {}
	for _, classId in Classes.order do
		local look = ClassLooks.get(classId)
		if look then
			local colors = look.outfit.colors
			local garments = {}
			for _, g in look.outfit.garments do
				if CharacterLook.GARMENTS[g.g] then
					table.insert(garments, Names.of(`garment.{g.g}`))
				end
			end
			local outfits = {}
			for _, def in Cosmetics.list do
				if def.class == classId and not ctx.hidden[def.id] then
					table.insert(outfits, { id = def.id, source = sourceOf(def) })
				end
			end
			table.insert(classes, {
				class = classId,
				name = Names.of(look.nameKey),
				colors = { main = colors.main, second = colors.second, trim = colors.trim or colors.second },
				garments = garments,
				outfits = outfits,
			})
		end
	end
	local skins = {}
	for _, skin in ClassLooks.SKINS do
		table.insert(skins, skin.color)
	end
	return { classes = classes, faces = #ClassLooks.FACES, hairs = #ClassLooks.HAIRS, skins = skins }
end

return ClassLooksWiki
