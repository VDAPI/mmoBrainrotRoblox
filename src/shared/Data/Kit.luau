--!strict
-- W02: the asset kit (docs/WYGLAD.md §5, docs/wyglad/ZASOBY.md): which models stand in for the generators' props.
-- A generator marks every prop it draws (a tree, a rock, a bush...) as a kit slot (Logic/TownGen/Blueprint beginKit);
-- when a slot's key has variants here for the map's biome (Data/Maps `biome`, else `default`) and the model exists in
-- ReplicatedStorage.Assets.Kit (Util/KitAssets), the model replaces the slot's pieces and only their collision stays
-- (invisible). A key without variants, or a missing model, keeps the generator's pieces as before.
--
-- Entry of a slot key:
--   fit / size: the model is scaled so that its height ("height") or its widest horizontal side ("width") equals
--               `size` x the generator's slot scale (the measured size of the generator's own prop, W02 inventory);
--   <biome> / default: the variants, each { model, weight, scale = { min, max }, yaw, sink? }:
--     model:  name in Assets.Kit.<folder>, where the folder is the name's first part (`grass_tree_01` in Kit.grass,
--             `common_rock_03` in Kit.common); convention `<biome>_<prefab>_<nr>`,
--     weight: relative chance among the list,
--     scale:  extra scale range on top of the fit (picked from the slot's position, Logic/KitPick),
--     yaw:    turned at random around the vertical axis,
--     sink:   fraction of the model's height below the slot's foot (rocks sit in the ground),
--     tint:   colour of the leaves (SurfaceAppearance.Color of the model's "Canopy" / "Leaves" parts; the packs' leaf
--             textures are colourless), so one model serves several regions.
-- Looks only, no gameplay: the collision of a replaced prop is its old shell pieces.

export type Variant = {
	model: string,
	weight: number,
	scale: { number },
	yaw: boolean,
	sink: number?,
	tint: string?,
}

export type Entry = {
	fit: "height" | "width",
	size: number,
	[string]: any, -- biome -> { Variant }
}

local Kit = {}

local function v(model: string, weight: number, lo: number, hi: number, sink: number?, tint: string?): Variant
	return { model = model, weight = weight, scale = { lo, hi }, yaw = true, sink = sink, tint = tint }
end

-- Leaf colours of the Meadows (docs/WYGLAD.md §4.2: bright green, gold; W02 screenshots under the 17:00 light).
local OAK = "#3A5A22"
local PINE = "#22381C"
local BIRCH = "#5E7A2A"

-- Yasu's Stylized Tree Pack (docs/ASSETS.md "Zestaw (W02)"): broadleaf 01-07, 13, 15, 19; conifers 08, 10, 11, 12;
-- the slim 16 and the small 14 stand in for birches and saplings.
local BROADLEAF = {
	v("grass_tree_01", 3, 0.95, 1.1, nil, OAK),
	v("grass_tree_02", 3, 0.95, 1.1, nil, OAK),
	v("grass_tree_04", 3, 0.95, 1.1, nil, OAK),
	v("grass_tree_05", 3, 0.95, 1.1, nil, OAK),
	v("grass_tree_13", 2, 0.95, 1.1, nil, OAK),
	v("grass_tree_15", 2, 0.95, 1.1, nil, OAK),
}
local CONIFER = {
	v("grass_tree_08", 3, 0.95, 1.1, nil, PINE),
	v("grass_tree_10", 3, 0.95, 1.1, nil, PINE),
	v("grass_tree_11", 2, 0.95, 1.1, nil, PINE),
	v("grass_tree_12", 2, 0.9, 1.05, nil, PINE),
}
local ROCKS = {
	v("common_rock_01", 2, 0.9, 1.15, 0.15),
	v("common_rock_02", 2, 0.9, 1.15, 0.15),
	v("common_rock_03", 2, 0.9, 1.15, 0.15),
	v("common_rock_04", 2, 0.9, 1.15, 0.15),
	v("common_rock_05", 1, 0.9, 1.15, 0.15),
	v("common_rock_06", 1, 0.9, 1.15, 0.15),
}

-- Slot keys of the generators (W02 inventory: docs/wyglad/SESJE-W.md "W02"). Sizes are the generators' own props at
-- slot scale 1; the trees about a third taller, so their slimmer crowns are as wide as the old ball crowns (W02
-- screenshots).
Kit.slots = {
	["tree:oak"] = { fit = "height", size = 17, grass = BROADLEAF },
	["tree:giantOak"] = {
		fit = "height",
		size = 22,
		grass = { v("grass_tree_19", 2, 0.95, 1.05, nil, OAK), v("grass_tree_15", 1, 1, 1.1, nil, OAK) },
	},
	["tree:birch"] = {
		fit = "height",
		size = 19,
		grass = { v("grass_tree_16", 3, 0.95, 1.1, nil, BIRCH), v("grass_tree_07", 2, 0.95, 1.05, nil, BIRCH) },
	},
	["tree:willow"] = {
		fit = "height",
		size = 15,
		grass = { v("grass_tree_06", 1, 0.95, 1.05, nil, BIRCH), v("grass_tree_03", 1, 0.95, 1.05, nil, BIRCH) },
	},
	["tree:pine"] = { fit = "height", size = 24, grass = CONIFER },
	["under:bush"] = {
		fit = "height",
		size = 3.2,
		grass = {
			v("grass_bush_01", 1, 0.85, 1.15, nil, OAK),
			v("grass_bush_02", 1, 0.85, 1.15, nil, OAK),
			v("grass_bush_03", 1, 0.85, 1.15, nil, OAK),
		},
	},
	["under:sapling"] = {
		fit = "height",
		size = 5.5,
		grass = { v("grass_tree_14", 1, 0.85, 1.1, nil, OAK), v("grass_tree_12", 1, 0.85, 1.05, nil, PINE) },
	},
	["rock"] = { fit = "width", size = 1.25, grass = ROCKS },
} :: { [string]: Entry }

return Kit
