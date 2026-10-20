--!strict
-- W26: variants reuse the imported model of their base (Data/MonsterAssetVariants): every base is a real look the
-- variant inherits, no chains, and the look of a variant resolves to its base's model in its own colour.
local T = require("./Test")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MonsterAssetVariants = require("../src/shared/Data/MonsterAssetVariants")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")

T.describe("MonsterAssetVariants", function()
	T.it("every variant points to an existing base look it inherits, never to another variant", function()
		for id, variant in MonsterAssetVariants do
			T.expect({ id, MonsterLooks.has(variant.from) }).toEqual({ id, true })
			T.expect({ id, MonsterLooks.raw[id] and MonsterLooks.raw[id].inherit }).toEqual({ id, variant.from })
			T.expect({ id, variant.from ~= id and MonsterAssetVariants[variant.from] == nil }).toEqual({ id, true })
			T.expect({ id, string.match(variant.tint, "^#%x%x%x%x%x%x$") ~= nil }).toEqual({ id, true })
		end
	end)

	T.it("every asset entry with a base points to a real model entry", function()
		for id, entry in MonsterAssets do
			if entry.from then
				local base = MonsterAssets[entry.from]
				T.expect({ id, base ~= nil and base.from == nil }).toEqual({ id, true })
				T.expect({ id, MonsterAssetVariants[id] ~= nil }).toEqual({ id, true })
			end
		end
	end)

	T.it("the look resolves a variant to its base's model and its own colour", function()
		for id, variant in MonsterAssetVariants do
			local look = MonsterLooks.get(id) :: MonsterLooks.Look
			if MonsterAssets[variant.from] then
				local asset = look.asset :: MonsterLooks.AssetLook
				T.expect({ id, asset.model, asset.color, asset.tint, asset.variant })
					.toEqual({ id, variant.from, variant.tint, false, true })
				T.expect(MonsterLooks.assetModel(id)).toBe(variant.from)
			else
				-- no base model yet: the generated look stays
				T.expect({ id, look.asset == nil }).toEqual({ id, true })
				T.expect(MonsterLooks.assetModel(id)).toBe(nil)
			end
		end
		T.expect(MonsterLooks.assetModel("iceWolf")).toBe("wolf")
		T.expect(MonsterLooks.assetModel("snowLeopard")).toBe("lynx")
		T.expect(MonsterLooks.assetModel("blackBear")).toBe(nil)
		T.expect(MonsterLooks.assetModel("wolf")).toBe("wolf")
	end)
end)
