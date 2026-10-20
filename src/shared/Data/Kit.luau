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
	turn: number?, -- with yaw = false: a fixed turn (degrees) instead of none
	-- W17: a painted look instead of the model's texture (models without a SurfaceAppearance, e.g. the rocks): the
	-- texture is dropped and the mesh takes `color` and the terrain `material`
	paint: { color: string, material: string }?,
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
-- W12: a model with a fixed turn (landmarks: their front matters).
local function fixed(model: string, turn: number): Variant
	return { model = model, weight = 1, scale = { 1, 1 }, yaw = false, turn = turn }
end

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
-- W15: the Duskwood (bor.md A8): the same Yasu trees under dark leaves
local DARK = "#1E2E1A"
local MOSS = "#2C3A22"
local FOREST_BROADLEAF = {
	v("grass_tree_01", 3, 0.95, 1.1, nil, DARK),
	v("grass_tree_02", 3, 0.95, 1.1, nil, MOSS),
	v("grass_tree_04", 3, 0.95, 1.1, nil, DARK),
	v("grass_tree_19", 2, 0.9, 1.05, nil, MOSS),
}
local FOREST_CONIFER = {
	v("grass_tree_08", 3, 0.95, 1.15, nil, DARK),
	v("grass_tree_10", 3, 0.95, 1.15, nil, DARK),
	v("grass_tree_11", 2, 0.95, 1.1, nil, MOSS),
	v("grass_tree_12", 2, 0.9, 1.05, nil, DARK),
}
-- W12: the city's broadleaf trees (gardens, squares): the Meadows' oaks a size smaller
local CITY_BROADLEAF = {
	v("grass_tree_01", 1, 0.7, 0.8, nil, OAK),
	v("grass_tree_02", 1, 0.7, 0.8, nil, OAK),
	v("grass_tree_05", 1, 0.7, 0.8, nil, OAK),
	v("grass_tree_13", 1, 0.7, 0.8, nil, OAK),
}
-- W17: the same rocks in rust and basalt for the Ashen Wastes (pustkowia.md 1.8)
local function painted(variant: Variant, color: string, material: string): Variant
	local out = table.clone(variant)
	out.paint = { color = color, material = material }
	return out
end
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
	["tree:oak"] = { fit = "height", size = 17, grass = BROADLEAF, city = CITY_BROADLEAF },
	["tree:birch"] = {
		fit = "height",
		size = 19,
		grass = { v("grass_tree_16", 3, 0.95, 1.1, nil, BIRCH), v("grass_tree_07", 2, 0.95, 1.05, nil, BIRCH) },
		city = { v("grass_tree_16", 1, 0.7, 0.8, nil, BIRCH) },
	},
	["tree:willow"] = {
		fit = "height",
		size = 15,
		grass = { v("grass_tree_06", 1, 0.95, 1.05, nil, BIRCH), v("grass_tree_03", 1, 0.95, 1.05, nil, BIRCH) },
		city = { v("grass_tree_06", 1, 0.75, 0.85, nil, BIRCH) },
	},
	["tree:pine"] = { fit = "height", size = 24, grass = CONIFER, city = CONIFER },
	-- W15: the Duskwood's species (WorldGen/Flora): gnarled oaks and dark pines, the giant oaks, moss willows by water
	["tree:gnarledOak"] = { fit = "height", size = 17, forest = FOREST_BROADLEAF },
	["tree:darkPine"] = { fit = "height", size = 24, forest = FOREST_CONIFER },
	["tree:giantOak"] = {
		fit = "height",
		size = 22,
		grass = { v("grass_tree_19", 2, 0.95, 1.05, nil, OAK), v("grass_tree_15", 1, 1, 1.1, nil, OAK) },
		forest = { v("grass_tree_19", 2, 1.1, 1.25, nil, MOSS), v("grass_tree_15", 1, 1.15, 1.3, nil, DARK) },
	},
	-- W19: Frostpeak's pines: the Yasu conifers under a pale, frosted green (bor.md-like rule, szczyty.md)
	["tree:snowPine"] = {
		fit = "height",
		size = 20,
		snow = {
			v("grass_tree_08", 3, 0.95, 1.15, nil, "#7E9690"),
			v("grass_tree_10", 3, 0.95, 1.15, nil, "#6F8A82"),
			v("grass_tree_11", 2, 0.9, 1.1, nil, "#8AA19A"),
			v("grass_tree_12", 2, 0.9, 1.05, nil, "#7A928B"),
		},
	},
	["tree:mossWillow"] = {
		fit = "height",
		size = 13,
		forest = { v("grass_tree_06", 1, 0.95, 1.05, nil, MOSS), v("grass_tree_03", 1, 0.95, 1.05, nil, MOSS) },
	},
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
		forest = { v("grass_tree_14", 1, 0.85, 1.1, nil, DARK), v("grass_tree_12", 1, 0.85, 1.05, nil, DARK) },
	},
	-- W28: the junipers of the Wolf Hills and the ravine were the generator's green ellipsoids on the Meadows (no
	-- model); now the small Yasu conifers under the pine green, a size smaller than the saplings
	["under:juniper"] = {
		fit = "height",
		size = 5,
		grass = { v("grass_tree_12", 2, 0.8, 1.05, nil, PINE), v("grass_tree_11", 1, 0.75, 0.95, nil, PINE) },
	},
	-- W15: the Duskwood's berry bushes and brambles: the Yasu bushes under dark leaves
	["under:berryBush"] = {
		fit = "height",
		size = 3.2,
		forest = { v("grass_bush_01", 1, 0.85, 1.15, nil, MOSS), v("grass_bush_02", 1, 0.85, 1.15, nil, DARK) },
	},
	["under:bramble"] = {
		fit = "height",
		size = 3,
		forest = { v("grass_bush_03", 1, 0.8, 1.1, nil, DARK), v("grass_bush_02", 1, 0.8, 1.1, nil, MOSS) },
	},
	["rock"] = {
		fit = "width",
		size = 1.25,
		grass = ROCKS,
		-- W15 / W19: the Duskwood keeps the grey-blue rock, Frostpeak takes a pale slate
		forest = ROCKS,
		snow = {
			painted(ROCKS[1], "#8E969E", "Slate"),
			painted(ROCKS[2], "#727A82", "Slate"),
			painted(ROCKS[3], "#A2AAB0", "Rock"),
			painted(ROCKS[4], "#646C74", "Slate"),
			painted(ROCKS[5], "#8A9298", "Rock"),
			painted(ROCKS[6], "#7A8288", "Slate"),
		},
		desert = {
			painted(ROCKS[1], "#7A4630", "Sandstone"),
			painted(ROCKS[2], "#5A3426", "Basalt"),
			painted(ROCKS[3], "#8A5A3A", "Sandstone"),
			painted(ROCKS[4], "#3E302C", "Basalt"),
			painted(ROCKS[5], "#6E3E2A", "Rock"),
			painted(ROCKS[6], "#4A3A34", "Basalt"),
		},
	},
	-- W12: the city's gardens, orchards and the cemetery yews (TownGen Parts.tree, a little smaller than in the wild)
	["tree:apple"] = {
		fit = "height",
		size = 9,
		city = { v("grass_tree_14", 2, 0.9, 1.1, nil, BIRCH), v("grass_tree_03", 1, 0.65, 0.75, nil, BIRCH) },
	},
	["tree:yew"] = {
		fit = "height",
		size = 15,
		city = { v("grass_tree_12", 1, 0.95, 1.05, nil, PINE), v("grass_tree_08", 1, 0.85, 0.95, nil, PINE) },
	},
	-- W12: landmarks from Tripo (docs/wyglad/mapy/miasto.md A2): the Mage Tower and the Lady with the Thorn
	["landmark:mageTower"] = { fit = "height", size = 48, city = { fixed("city_landmark_01", 0) } },
	["landmark:fountainStatue"] = { fit = "height", size = 6.5, city = { fixed("city_statue_01", 180) } },
	-- W12 (owner's Tripo models, 2026-10-18): the street lamp, the draw well (city, Meadows farms, villages) and the
	-- fruit stand in place of the bread stall on the market
	["prop:lamp"] = { fit = "height", size = 9, default = { v("city_lamp_01", 1, 1, 1) } },
	["prop:well"] = { fit = "height", size = 7.6, default = { v("common_well_01", 1, 0.95, 1.05) } },
	["prop:stallFruit"] = { fit = "height", size = 9, city = { fixed("city_stall_01", 0) } },
	-- 2026-10-18, the owner's Tripo models: the Old Tree of the Duskwood (bor.md A2, crown over the forest), the Meadows
	-- gate, the wayside shrine, the goblin totem, Grimrok's throne and the Moss Cave's mushrooms (cave maps: default)
	["landmark:elderTree"] = { fit = "height", size = 80, forest = { fixed("forest_landmark_03", 0) } },
	["landmark:meadowsGate"] = { fit = "width", size = 21, grass = { fixed("common_gate_01", 0) } },
	["landmark:shrine"] = { fit = "height", size = 10.5, grass = { fixed("grass_landmark_02", 0) } },
	["landmark:goblinTotem"] = { fit = "height", size = 21, grass = { fixed("grass_totem_01", 0) } },
	["landmark:grimrokThrone"] = { fit = "height", size = 14, default = { fixed("dungeon_landmark_01", 0) } },
	["landmark:caveMushrooms"] = { fit = "height", size = 4, default = { v("cave_landmark_02", 1, 0.9, 1.2) } },
	-- W13: the burnt post mill on Crow Field; its top over the saddle of the Wolf Hills (rise 9 + 34 >= 41, laki.md Z2)
	["landmark:mill"] = { fit = "height", size = 34, grass = { fixed("grass_landmark_01", 0) } },
	-- W19-20 (szczyty.md 1.2, 1.8): the Frost Peaks' Tripo landmarks to come (the generator's pieces until the models
	-- are in Assets.Kit.snow): the intact colossus of the Giants' Gate, the Frozen Falls, the Ice Watch's corner towers
	-- and the Harpy Queen's nest
	["landmark:giantColossus"] = { fit = "height", size = 24.5, snow = { fixed("snow_landmark_04", 0) } },
	["landmark:frozenFalls"] = { fit = "height", size = 39, snow = { fixed("snow_landmark_01", 180) } },
	["landmark:watchTower"] = { fit = "height", size = 34, snow = { fixed("snow_landmark_02", 0) } },
	-- owner 2026-10-20 (TRIPO-REKWIZYTY-MAP): the Duskwood's cult runestones and the Vael chapel, the Ashen Wastes'
	-- Ribcage Gate and the skull over the hyenas' den
	["landmark:cultStone"] = { fit = "height", size = 6, forest = { v("forest_landmark_01", 1, 1, 1) } },
	["landmark:chapel"] = { fit = "width", size = 18, forest = { fixed("forest_landmark_02", 90) } },
	["landmark:ribcage"] = { fit = "width", size = 30, desert = { fixed("desert_landmark_03", 90) } },
	["landmark:bigSkull"] = { fit = "height", size = 9, desert = { fixed("desert_landmark_04", 0) } },
	-- the hooded mourners with lanterns at the Gate of the Forgotten (Crypt, bor.md: forest_landmark_04)
	["landmark:mourner"] = { fit = "height", size = 14, crypt = { fixed("forest_landmark_04", 0) } },
	["landmark:harpyNest"] = { fit = "width", size = 14, snow = { fixed("snow_nest_01", 0) } },
} :: { [string]: Entry }

return Kit
