--!strict
-- Placeholder 3D looks of held weapons and off-hands (S17b), built from a few Parts by EquipmentService.
-- Frame: origin at the palm of the hand ("back": centre of the upper torso), -Z = forward (the way the
-- weapon points), +Y = up the arm, +X = right. Sizes and positions in studs, rotations in degrees.
-- The first piece is the main part (named VaelthornWeapon / VaelthornOffhand; weapon cosmetics and the
-- heroic+ glow attach to it). Colour "rarity" takes the item's rarity colour.
-- Real models from files replace them per item (WeaponLooks.assets, S52) without touching the item data.

local WeaponLooks = {}

export type Piece = {
	name: string,
	size: { number },
	pos: { number },
	rot: { number }?,
	color: string, -- "#RRGGBB" or "rarity"
	material: string, -- Enum.Material name
	shape: ("Ball" | "Cylinder")?,
	transparency: number?,
}

export type Look = {
	hand: "right" | "left" | "back",
	pieces: { Piece },
}

-- Materials the looks may use (checked by tests so a typo never errors on the server).
WeaponLooks.MATERIALS = { "Metal", "Wood", "Fabric", "Neon", "SmoothPlastic", "Glass", "Slate" }

local STEEL = "#C9CED6"
local IRON = "#8E8E93"
local DARK_IRON = "#5E5E66"
local WOOD = "#8A6B4A"
local DARK_WOOD = "#5A4632"
local LEATHER = "#4A3324"
local GOLD = "#E8C25A"
local STRING = "#E8E2D0"

local looks: { [string]: Look } = {
	sword1h = {
		hand = "right",
		pieces = {
			{ name = "Blade", size = { 0.12, 0.32, 2.6 }, pos = { 0, 0, -1.75 }, color = STEEL, material = "Metal" },
			{ name = "Guard", size = { 0.22, 0.9, 0.16 }, pos = { 0, 0, -0.42 }, color = IRON, material = "Metal" },
			{ name = "Grip", size = { 0.18, 0.18, 0.7 }, pos = { 0, 0, 0 }, color = LEATHER, material = "Fabric" },
			{
				name = "Pommel",
				size = { 0.28, 0.28, 0.28 },
				pos = { 0, 0, 0.42 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	sword2h = {
		hand = "right",
		pieces = {
			{ name = "Blade", size = { 0.14, 0.42, 3.6 }, pos = { 0, 0, -2.55 }, color = STEEL, material = "Metal" },
			{
				name = "Fuller",
				size = { 0.16, 0.08, 2.8 },
				pos = { 0, 0, -2.4 },
				color = "rarity",
				material = "Neon",
			},
			{ name = "Guard", size = { 0.24, 1.3, 0.2 }, pos = { 0, 0, -0.65 }, color = IRON, material = "Metal" },
			{ name = "Grip", size = { 0.2, 0.2, 1.1 }, pos = { 0, 0, 0 }, color = LEATHER, material = "Fabric" },
			{
				name = "Pommel",
				size = { 0.34, 0.34, 0.34 },
				pos = { 0, 0, 0.65 },
				color = IRON,
				material = "Metal",
				shape = "Ball",
			},
		},
	},
	axe1h = {
		hand = "right",
		pieces = {
			{ name = "Head", size = { 0.1, 0.9, 0.75 }, pos = { 0, 0.4, -1.75 }, color = IRON, material = "Metal" },
			{ name = "Edge", size = { 0.12, 0.12, 0.85 }, pos = { 0, 0.85, -1.75 }, color = STEEL, material = "Metal" },
			{ name = "Handle", size = { 0.18, 0.18, 2.4 }, pos = { 0, 0, -0.8 }, color = DARK_WOOD, material = "Wood" },
			{
				name = "Band",
				size = { 0.22, 0.22, 0.14 },
				pos = { 0, 0, -1.45 },
				color = "rarity",
				material = "Neon",
			},
		},
	},
	axe2h = {
		hand = "right",
		pieces = {
			{ name = "BladeUp", size = { 0.12, 1.3, 1.0 }, pos = { 0, 0.6, -3.1 }, color = IRON, material = "Metal" },
			{
				name = "BladeDown",
				size = { 0.12, 1.3, 1.0 },
				pos = { 0, -0.6, -3.1 },
				color = IRON,
				material = "Metal",
			},
			{ name = "Socket", size = { 0.3, 0.4, 0.5 }, pos = { 0, 0, -3.1 }, color = "rarity", material = "Neon" },
			{ name = "Handle", size = { 0.22, 0.22, 3.9 }, pos = { 0, 0, -1.3 }, color = DARK_WOOD, material = "Wood" },
		},
	},
	mace1h = {
		hand = "right",
		pieces = {
			{
				name = "Head",
				size = { 0.75, 0.75, 0.75 },
				pos = { 0, 0, -1.9 },
				color = DARK_IRON,
				material = "Metal",
				shape = "Ball",
			},
			{ name = "SpikeY", size = { 0.12, 1.05, 0.12 }, pos = { 0, 0, -1.9 }, color = STEEL, material = "Metal" },
			{ name = "SpikeX", size = { 1.05, 0.12, 0.12 }, pos = { 0, 0, -1.9 }, color = STEEL, material = "Metal" },
			{ name = "Handle", size = { 0.2, 0.2, 1.9 }, pos = { 0, 0, -0.75 }, color = DARK_WOOD, material = "Wood" },
			{
				name = "Gem",
				size = { 0.25, 0.25, 0.25 },
				pos = { 0, 0, 0.25 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	hammer2h = {
		hand = "right",
		pieces = {
			{ name = "Head", size = { 0.9, 1.5, 0.9 }, pos = { 0, 0, -3.3 }, color = DARK_IRON, material = "Metal" },
			{ name = "BandUp", size = { 0.95, 0.2, 0.95 }, pos = { 0, 0.5, -3.3 }, color = GOLD, material = "Metal" },
			{
				name = "BandDown",
				size = { 0.95, 0.2, 0.95 },
				pos = { 0, -0.5, -3.3 },
				color = GOLD,
				material = "Metal",
			},
			{ name = "Rune", size = { 0.97, 0.3, 0.3 }, pos = { 0, 0, -3.3 }, color = "rarity", material = "Neon" },
			{ name = "Handle", size = { 0.22, 0.22, 3.8 }, pos = { 0, 0, -1.4 }, color = DARK_WOOD, material = "Wood" },
		},
	},
	bow = {
		hand = "left",
		pieces = {
			{
				name = "UpperLimb",
				size = { 0.16, 1.7, 0.22 },
				pos = { 0, 1.15, 0.12 },
				rot = { 12, 0, 0 },
				color = WOOD,
				material = "Wood",
			},
			{
				name = "LowerLimb",
				size = { 0.16, 1.7, 0.22 },
				pos = { 0, -1.15, 0.12 },
				rot = { -12, 0, 0 },
				color = WOOD,
				material = "Wood",
			},
			{ name = "Grip", size = { 0.22, 0.7, 0.26 }, pos = { 0, 0, 0 }, color = LEATHER, material = "Fabric" },
			{ name = "String", size = { 0.04, 3.9, 0.04 }, pos = { 0, 0, 0.4 }, color = STRING, material = "Fabric" },
			{ name = "Tip", size = { 0.18, 0.2, 0.24 }, pos = { 0, 1.98, 0.3 }, color = "rarity", material = "Neon" },
		},
	},
	crossbow = {
		hand = "left",
		pieces = {
			{ name = "Stock", size = { 0.3, 0.3, 2.2 }, pos = { 0, 0, -0.6 }, color = DARK_WOOD, material = "Wood" },
			{ name = "Prod", size = { 2.2, 0.18, 0.22 }, pos = { 0, 0, -1.55 }, color = WOOD, material = "Wood" },
			{ name = "String", size = { 2.0, 0.04, 0.04 }, pos = { 0, 0, -1.25 }, color = STRING, material = "Fabric" },
			{ name = "Bolt", size = { 0.08, 0.08, 1.0 }, pos = { 0, 0.19, -1.0 }, color = IRON, material = "Metal" },
			{ name = "Sight", size = { 0.12, 0.2, 0.2 }, pos = { 0, 0.22, -0.2 }, color = "rarity", material = "Neon" },
		},
	},
	wand = {
		hand = "right",
		pieces = {
			{
				name = "Tip",
				size = { 0.32, 0.32, 0.32 },
				pos = { 0, 0, -1.4 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
			{ name = "Shaft", size = { 0.14, 0.14, 1.5 }, pos = { 0, 0, -0.55 }, color = DARK_WOOD, material = "Wood" },
			{ name = "Ring", size = { 0.22, 0.22, 0.12 }, pos = { 0, 0, -1.2 }, color = GOLD, material = "Metal" },
		},
	},
	staff = {
		hand = "right",
		pieces = {
			{
				name = "Orb",
				size = { 0.75, 0.75, 0.75 },
				pos = { 0, 3.95, 0 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
			{ name = "Shaft", size = { 0.26, 5.0, 0.26 }, pos = { 0, 1.2, 0 }, color = WOOD, material = "Wood" },
			{
				name = "ProngL",
				size = { 0.12, 0.8, 0.12 },
				pos = { -0.3, 3.75, 0 },
				rot = { 0, 0, 20 },
				color = GOLD,
				material = "Metal",
			},
			{
				name = "ProngR",
				size = { 0.12, 0.8, 0.12 },
				pos = { 0.3, 3.75, 0 },
				rot = { 0, 0, -20 },
				color = GOLD,
				material = "Metal",
			},
			{ name = "Foot", size = { 0.32, 0.3, 0.32 }, pos = { 0, -1.35, 0 }, color = IRON, material = "Metal" },
		},
	},
	scepter = {
		hand = "right",
		pieces = {
			{
				name = "Gem",
				size = { 0.35, 0.35, 0.35 },
				pos = { 0, 0, -1.85 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
			{
				name = "Head",
				size = { 0.45, 0.45, 0.45 },
				pos = { 0, 0, -1.5 },
				rot = { 0, 0, 45 },
				color = GOLD,
				material = "Metal",
			},
			{ name = "Shaft", size = { 0.2, 0.2, 1.7 }, pos = { 0, 0, -0.5 }, color = GOLD, material = "Metal" },
		},
	},
	-- Off-hands
	shield = {
		hand = "left",
		pieces = {
			{ name = "Board", size = { 0.2, 2.0, 1.6 }, pos = { -0.3, 0.6, 0 }, color = IRON, material = "Metal" },
			{ name = "Rim", size = { 0.16, 2.2, 1.8 }, pos = { -0.28, 0.6, 0 }, color = DARK_WOOD, material = "Wood" },
			{
				name = "Emblem",
				size = { 0.08, 0.8, 0.6 },
				pos = { -0.42, 0.6, 0 },
				color = "rarity",
				material = "Neon",
			},
		},
	},
	quiver = {
		hand = "back",
		pieces = {
			{
				name = "Tube",
				size = { 0.6, 2.2, 0.6 },
				pos = { 0.4, 0.2, 0.75 },
				rot = { 0, 0, -20 },
				color = LEATHER,
				material = "Fabric",
			},
			{
				name = "Fletching",
				size = { 0.5, 0.4, 0.5 },
				pos = { 0.8, 1.35, 0.75 },
				rot = { 0, 0, -20 },
				color = "rarity",
				material = "Neon",
			},
		},
	},
	tome = {
		hand = "left",
		pieces = {
			{
				name = "Cover",
				size = { 0.35, 1.1, 0.85 },
				pos = { 0, 0.1, -0.3 },
				color = "#6B2A2A",
				material = "Fabric",
			},
			{
				name = "Rune",
				size = { 0.37, 0.35, 0.35 },
				pos = { 0, 0.15, -0.3 },
				color = "rarity",
				material = "Neon",
			},
			{ name = "Clasp", size = { 0.4, 0.25, 0.12 }, pos = { 0, 0.1, -0.74 }, color = GOLD, material = "Metal" },
		},
	},
	orb = {
		hand = "left",
		pieces = {
			{
				name = "Orb",
				size = { 0.8, 0.8, 0.8 },
				pos = { 0, -0.55, -0.2 },
				color = "rarity",
				material = "Glass",
				shape = "Ball",
				transparency = 0.25,
			},
			{
				name = "Core",
				size = { 0.38, 0.38, 0.38 },
				pos = { 0, -0.55, -0.2 },
				color = "#FFFFFF",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	relic = {
		hand = "left",
		pieces = {
			{ name = "Stem", size = { 0.2, 1.1, 0.2 }, pos = { 0, 0, -0.35 }, color = GOLD, material = "Metal" },
			{ name = "Arm", size = { 0.65, 0.2, 0.2 }, pos = { 0, 0.2, -0.35 }, color = GOLD, material = "Metal" },
			{
				name = "Gem",
				size = { 0.22, 0.22, 0.22 },
				pos = { 0, 0.2, -0.47 },
				color = "rarity",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
}

-- Variants built from another look, scaled (S18 weapon types).
local function scaled(from: string, factor: number, tint: { [string]: string }?): Look
	local source = looks[from]
	local pieces: { Piece } = {}
	for _, piece in source.pieces do
		local copy = table.clone(piece)
		copy.size = { piece.size[1] * factor, piece.size[2] * factor, piece.size[3] * factor }
		copy.pos = { piece.pos[1] * factor, piece.pos[2] * factor, piece.pos[3] * factor }
		if tint and tint[piece.name] then
			copy.color = tint[piece.name]
		end
		table.insert(pieces, copy)
	end
	return { hand = source.hand, pieces = pieces }
end

looks.shortbow = scaled("bow", 0.8)
looks.longbow = scaled("bow", 1.25, { UpperLimb = DARK_WOOD, LowerLimb = DARK_WOOD })
looks.heavycrossbow = scaled("crossbow", 1.25, { Prod = DARK_IRON })
looks.saber1h = {
	hand = "right",
	pieces = {
		{
			name = "Blade",
			size = { 0.1, 0.28, 2.5 },
			pos = { 0, 0.12, -1.7 },
			rot = { 6, 0, 0 },
			color = STEEL,
			material = "Metal",
		},
		{ name = "Guard", size = { 0.2, 0.55, 0.14 }, pos = { 0, -0.1, -0.42 }, color = GOLD, material = "Metal" },
		{ name = "Grip", size = { 0.17, 0.17, 0.65 }, pos = { 0, 0, 0 }, color = LEATHER, material = "Fabric" },
		{
			name = "Gem",
			size = { 0.2, 0.2, 0.2 },
			pos = { 0, 0, 0.4 },
			color = "rarity",
			material = "Neon",
			shape = "Ball",
		},
	},
}
looks.spear2h = {
	hand = "right",
	pieces = {
		{ name = "Head", size = { 0.12, 0.4, 1.0 }, pos = { 0, 0, -4.4 }, color = STEEL, material = "Metal" },
		{ name = "Shaft", size = { 0.2, 0.2, 5.0 }, pos = { 0, 0, -1.6 }, color = WOOD, material = "Wood" },
		{ name = "Collar", size = { 0.26, 0.26, 0.2 }, pos = { 0, 0, -3.9 }, color = "rarity", material = "Neon" },
	},
}
looks.runestaff = {
	hand = "right",
	pieces = {
		{
			name = "Crystal",
			size = { 0.45, 1.0, 0.45 },
			pos = { 0, 4.1, 0 },
			rot = { 0, 45, 0 },
			color = "rarity",
			material = "Neon",
		},
		{ name = "Shaft", size = { 0.3, 5.2, 0.3 }, pos = { 0, 1.2, 0 }, color = DARK_WOOD, material = "Wood" },
		{ name = "RuneA", size = { 0.34, 0.12, 0.34 }, pos = { 0, 2.6, 0 }, color = "rarity", material = "Neon" },
		{ name = "RuneB", size = { 0.34, 0.12, 0.34 }, pos = { 0, 1.8, 0 }, color = "rarity", material = "Neon" },
		{ name = "Cage", size = { 0.6, 0.18, 0.6 }, pos = { 0, 3.6, 0 }, color = DARK_IRON, material = "Metal" },
	},
}
looks.flail1h = {
	hand = "right",
	pieces = {
		{
			name = "Ball",
			size = { 0.6, 0.6, 0.6 },
			pos = { 0, -0.5, -1.9 },
			color = DARK_IRON,
			material = "Metal",
			shape = "Ball",
		},
		{
			name = "Chain",
			size = { 0.08, 0.6, 0.08 },
			pos = { 0, -0.2, -1.75 },
			rot = { 20, 0, 0 },
			color = IRON,
			material = "Metal",
		},
		{ name = "Handle", size = { 0.2, 0.2, 1.6 }, pos = { 0, 0, -0.65 }, color = DARK_WOOD, material = "Wood" },
		{
			name = "Gem",
			size = { 0.24, 0.24, 0.24 },
			pos = { 0, 0, 0.2 },
			color = "rarity",
			material = "Neon",
			shape = "Ball",
		},
	},
}
looks.holystaff = {
	hand = "right",
	pieces = {
		{ name = "Halo", size = { 0.9, 0.9, 0.12 }, pos = { 0, 3.95, 0 }, color = "rarity", material = "Neon" },
		{ name = "Shaft", size = { 0.26, 5.0, 0.26 }, pos = { 0, 1.2, 0 }, color = "#E8E2D0", material = "Wood" },
		{ name = "CrossV", size = { 0.2, 1.0, 0.2 }, pos = { 0, 3.95, 0 }, color = GOLD, material = "Metal" },
		{ name = "CrossH", size = { 0.7, 0.2, 0.2 }, pos = { 0, 4.1, 0 }, color = GOLD, material = "Metal" },
	},
}

WeaponLooks.list = looks

-- War Banner (ROZWOJ 10.5, S74): the object standing on the ground; frame origin at the foot of the pole, +Y up.
-- Not in `list` (no item uses it); clients draw it on the server's anchor (Vfx/Library.banner).
WeaponLooks.BANNER = {
	{ name = "Pole", size = { 0.3, 9, 0.3 }, pos = { 0, 4.5, 0 }, color = DARK_WOOD, material = "Wood" },
	{ name = "Cloth", size = { 3, 4.5, 0.1 }, pos = { 1.65, 6.4, 0 }, color = "#C0503C", material = "Fabric" },
	{
		name = "Finial",
		size = { 0.5, 0.5, 0.5 },
		pos = { 0, 9.25, 0 },
		color = GOLD,
		material = "Metal",
		shape = "Ball",
	},
} :: { Piece }

function WeaponLooks.get(itemType: string): Look?
	return looks[itemType]
end

-- Real weapon models (2026-10-09, S52; docs/ASSETS.md "Broń", docs/GRAFIKA.md 3): item definition id (or boss item
-- id) -> a MeshPart named `model` in ReplicatedStorage.Assets.Weapons (anywhere below it, e.g. inside a saved pack).
-- The mesh is in the Grip frame (tools/weapons/prepare_glb.py turns the .glb files): +Y along the length (tip, head,
-- front of a crossbow, top edge of an off-hand), +X = edge / head / back of a bow / top of a crossbow / face. The
-- game scales it to `length` (studs along +Y) and puts the point `grip` (fraction of the length from the bottom) on
-- the mount of its type (MOUNTS). Items without their own entry take the nearest lower tier of their type
-- (Logic/ArtTiers); without any model the item keeps its Part look above. `turn` (degrees, X Y Z) turns a mesh whose
-- axes are not the Grip frame (e.g. one made with the Studio Assistant) into it. `hold` ({ x, z }, fractions of the
-- length) is the handle centre at the grip height measured from the mesh's box centre line: a MeshPart is centred on
-- its bounds, so an axe, a bow's riser or a crossbow's stock is off that line (prepare_glb.py measures it).
export type Asset = { model: string, length: number, grip: number, turn: { number }?, hold: { number }? }

-- Hand-frame directions of the Grip axes per item type (Logic/WeaponMount): `y` / `x` are "+X" .. "-Z"; `at` is the
-- grip point in the hand frame (studs, default the palm); `tilt` turns the model about it (degrees, X Y Z). Off-hands
-- use grip 0.5 with `at` = the centre of today's Part look.
export type Mount = { y: string, x: string, at: { number }?, tilt: { number }? }

local FORWARD: Mount = { y = "-Z", x = "+Y" } -- one- and two-handed weapons, crossbows: tip forward, edge up
local UPRIGHT: Mount = { y = "+Y", x = "-Z" } -- staffs (head up, ornament forward), bows (back towards the target)

WeaponLooks.MOUNTS = {
	sword1h = FORWARD,
	saber1h = FORWARD,
	axe1h = FORWARD,
	mace1h = FORWARD,
	flail1h = FORWARD,
	scepter = FORWARD,
	wand = FORWARD,
	sword2h = FORWARD,
	axe2h = FORWARD,
	hammer2h = FORWARD,
	spear2h = FORWARD,
	staff = UPRIGHT,
	runestaff = UPRIGHT,
	holystaff = UPRIGHT,
	shortbow = UPRIGHT,
	bow = UPRIGHT,
	longbow = UPRIGHT,
	crossbow = FORWARD,
	heavycrossbow = FORWARD,
	shield = { y = "+Y", x = "-X", at = { -0.3, 0.6, 0 } }, -- face outwards, along the forearm
	tome = { y = "+Y", x = "-Z", at = { 0, 0.1, -0.3 } }, -- clasp forward
	orb = { y = "+Y", x = "-Z", at = { 0, -0.55, -0.2 } }, -- hangs under the palm
	relic = { y = "+Y", x = "-Z", at = { 0, 0, -0.35 } },
	quiver = { y = "+Y", x = "-Z", at = { 0.4, 0.2, 0.75 }, tilt = { 0, 0, -20 } }, -- on the back, strap side in
} :: { [string]: Mount }

-- Turn (degrees about +Y) of every imported mesh: 0 when Studio keeps the axes of the .glb files. If every shield
-- shows its back and every axe its spike after the import, set 180 (one switch for all models).
WeaponLooks.IMPORT_YAW = 0

-- Owner's Tripo models (2026-10-12, Graphics/modele_3d/bronie, 2.6-4.1k triangles each); lengths = today's Part
-- looks (docs/GRAFIKA.md 3.4), grips and handle offsets measured on the models (tools/weapons/prepare_glb.py).
WeaponLooks.assets = {
	-- sword1h
	sword1h_1 = { model = "sword1h_1", length = 3.6, grip = 0.19, hold = { 0, -0.01 } },
	sword1h_5 = { model = "sword1h_5", length = 3.6, grip = 0.2 },
	sword1h_10 = { model = "sword1h_10", length = 3.6, grip = 0.22, hold = { -0.01, 0.01 } },
	sword1h_15 = { model = "sword1h_15", length = 3.6, grip = 0.15 },
	sword1h_20 = { model = "sword1h_20", length = 3.6, grip = 0.14 },
	-- saber1h
	saber1h_1 = { model = "saber1h_1", length = 3.5, grip = 0.17 },
	saber1h_5 = { model = "saber1h_5", length = 3.5, grip = 0.1, hold = { -0.03, 0 } },
	saber1h_10 = { model = "saber1h_10", length = 3.5, grip = 0.1, hold = { -0.03, 0 } },
	saber1h_15 = { model = "saber1h_15", length = 3.5, grip = 0.12, hold = { 0.01, 0 } },
	saber1h_20 = { model = "saber1h_20", length = 3.5, grip = 0.14 },
	-- axe1h
	axe1h_1 = { model = "axe1h_1", length = 2.6, grip = 0.15, hold = { -0.02, -0.01 } },
	axe1h_5 = { model = "axe1h_5", length = 2.6, grip = 0.15, hold = { 0.03, 0 } },
	axe1h_10 = { model = "axe1h_10", length = 2.6, grip = 0.15, hold = { -0.06, -0.01 } },
	axe1h_15 = { model = "axe1h_15", length = 2.6, grip = 0.15, hold = { 0.02, 0.03 } },
	axe1h_20 = { model = "axe1h_20", length = 2.6, grip = 0.15, hold = { -0.07, 0 } },
	-- mace1h
	mace1h_1 = { model = "mace1h_1", length = 2.65, grip = 0.15, hold = { -0.03, -0.01 } },
	mace1h_5 = { model = "mace1h_5", length = 2.65, grip = 0.15, hold = { -0.01, 0.01 } },
	mace1h_10 = { model = "mace1h_10", length = 2.65, grip = 0.15, hold = { -0.06, 0.01 } },
	mace1h_15 = { model = "mace1h_15", length = 2.65, grip = 0.15, hold = { 0.02, 0 } },
	mace1h_20 = { model = "mace1h_20", length = 2.65, grip = 0.15 },
	-- flail1h
	flail1h_1 = { model = "flail1h_1", length = 2.5, grip = 0.12, hold = { -0.03, 0 } },
	flail1h_5 = { model = "flail1h_5", length = 2.5, grip = 0.12, hold = { 0.01, 0 } },
	flail1h_10 = { model = "flail1h_10", length = 2.5, grip = 0.12, hold = { -0.01, 0 } },
	flail1h_15 = { model = "flail1h_15", length = 2.5, grip = 0.12, hold = { -0.01, 0.01 } },
	flail1h_20 = { model = "flail1h_20", length = 2.5, grip = 0.12, hold = { -0.01, 0.01 } },
	-- scepter
	scepter_1 = { model = "scepter_1", length = 2.4, grip = 0.18, hold = { 0, 0.01 } },
	scepter_5 = { model = "scepter_5", length = 2.4, grip = 0.18, hold = { -0.05, 0.01 } },
	scepter_10 = { model = "scepter_10", length = 2.4, grip = 0.18, hold = { -0.07, 0.06 } },
	scepter_15 = { model = "scepter_15", length = 2.4, grip = 0.18 },
	scepter_20 = { model = "scepter_20", length = 2.4, grip = 0.18, hold = { 0, 0.01 } },
	-- wand
	wand_1 = { model = "wand_1", length = 1.8, grip = 0.2, hold = { 0, 0.06 } },
	wand_5 = { model = "wand_5", length = 1.8, grip = 0.2 },
	wand_10 = { model = "wand_10", length = 1.8, grip = 0.2, hold = { -0.01, -0.01 } },
	wand_15 = { model = "wand_15", length = 1.8, grip = 0.2, hold = { 0.01, 0 } },
	wand_20 = { model = "wand_20", length = 1.8, grip = 0.2, hold = { -0.01, 0.01 } },
	-- sword2h
	sword2h_1 = { model = "sword2h_1", length = 5.2, grip = 0.22, hold = { -0.01, 0 } },
	sword2h_5 = { model = "sword2h_5", length = 5.2, grip = 0.17, hold = { -0.01, 0 } },
	sword2h_10 = { model = "sword2h_10", length = 5.2, grip = 0.23, hold = { 0, 0.01 } },
	sword2h_15 = { model = "sword2h_15", length = 5.2, grip = 0.25, hold = { -0.07, 0 } },
	sword2h_20 = { model = "sword2h_20", length = 5.2, grip = 0.17 },
	-- axe2h
	axe2h_1 = { model = "axe2h_1", length = 4.25, grip = 0.18, hold = { -0.05, 0 } },
	axe2h_5 = { model = "axe2h_5", length = 4.25, grip = 0.18, hold = { 0, -0.01 } },
	axe2h_10 = { model = "axe2h_10", length = 4.25, grip = 0.18, hold = { -0.13, 0.03 } },
	axe2h_15 = { model = "axe2h_15", length = 4.25, grip = 0.18 },
	axe2h_20 = { model = "axe2h_20", length = 4.25, grip = 0.18 },
	-- hammer2h
	hammer2h_1 = { model = "hammer2h_1", length = 4.3, grip = 0.15 },
	hammer2h_5 = { model = "hammer2h_5", length = 4.3, grip = 0.15, hold = { 0, -0.01 } },
	hammer2h_10 = { model = "hammer2h_10", length = 4.3, grip = 0.15, hold = { 0.01, 0.01 } },
	hammer2h_15 = { model = "hammer2h_15", length = 4.3, grip = 0.15, hold = { -0.04, 0 } },
	hammer2h_20 = { model = "hammer2h_20", length = 4.3, grip = 0.15, hold = { -0.04, 0 } },
	-- spear2h
	spear2h_1 = { model = "spear2h_1", length = 5.8, grip = 0.3, hold = { 0, 0.03 } },
	spear2h_5 = { model = "spear2h_5", length = 5.8, grip = 0.3 },
	spear2h_10 = { model = "spear2h_10", length = 5.8, grip = 0.3, hold = { -0.03, 0 } },
	spear2h_15 = { model = "spear2h_15", length = 5.8, grip = 0.3, hold = { 0, -0.03 } },
	spear2h_20 = { model = "spear2h_20", length = 5.8, grip = 0.3 },
	-- staff
	staff_1 = { model = "staff_1", length = 5.8, grip = 0.35, hold = { 0.01, 0.02 } },
	staff_5 = { model = "staff_5", length = 5.8, grip = 0.35, hold = { -0.01, 0 } },
	staff_10 = { model = "staff_10", length = 5.8, grip = 0.35, hold = { -0.04, -0.01 } },
	staff_15 = { model = "staff_15", length = 5.8, grip = 0.35, hold = { -0.04, -0.01 } },
	staff_20 = { model = "staff_20", length = 5.8, grip = 0.35, hold = { 0, 0.01 } },
	-- runestaff
	runestaff_1 = { model = "runestaff_1", length = 6, grip = 0.35, hold = { 0, 0.07 } },
	runestaff_5 = { model = "runestaff_5", length = 6, grip = 0.35, hold = { -0.05, 0 } },
	runestaff_10 = { model = "runestaff_10", length = 6, grip = 0.35 },
	runestaff_15 = { model = "runestaff_15", length = 6, grip = 0.35, hold = { 0.01, 0.03 } },
	runestaff_20 = { model = "runestaff_20", length = 6, grip = 0.35 },
	-- holystaff
	holystaff_1 = { model = "holystaff_1", length = 5.75, grip = 0.35, hold = { 0, -0.01 } },
	holystaff_5 = { model = "holystaff_5", length = 5.75, grip = 0.35, hold = { -0.04, 0 } },
	holystaff_10 = { model = "holystaff_10", length = 5.75, grip = 0.35, hold = { -0.02, 0.02 } },
	holystaff_15 = { model = "holystaff_15", length = 5.75, grip = 0.35, hold = { -0.01, 0.03 } },
	holystaff_20 = { model = "holystaff_20", length = 5.75, grip = 0.35 },
	-- shortbow
	shortbow_1 = { model = "shortbow_1", length = 3.3, grip = 0.5, hold = { 0.04, -0.01 } },
	shortbow_5 = { model = "shortbow_5", length = 3.3, grip = 0.5, hold = { 0.04, 0 } },
	shortbow_10 = { model = "shortbow_10", length = 3.3, grip = 0.5, hold = { 0.01, 0.01 } },
	shortbow_15 = { model = "shortbow_15", length = 3.3, grip = 0.5, hold = { 0.12, 0 } },
	shortbow_20 = { model = "shortbow_20", length = 3.3, grip = 0.5, hold = { 0.02, 0 } },
	-- bow
	bow_1 = { model = "bow_1", length = 4.1, grip = 0.5, hold = { 0.06, 0 } },
	bow_5 = { model = "bow_5", length = 4.1, grip = 0.5, hold = { 0.05, 0 } },
	bow_10 = { model = "bow_10", length = 4.1, grip = 0.5, hold = { 0.06, 0.01 } },
	bow_15 = { model = "bow_15", length = 4.1, grip = 0.5, hold = { 0.06, 0 } },
	bow_20 = { model = "bow_20", length = 4.1, grip = 0.5, hold = { 0.06, -0.01 } },
	-- longbow
	longbow_1 = { model = "longbow_1", length = 5.1, grip = 0.5, hold = { 0.02, 0 } },
	longbow_5 = { model = "longbow_5", length = 5.1, grip = 0.5, hold = { 0.05, -0.01 } },
	longbow_10 = { model = "longbow_10", length = 5.1, grip = 0.5, hold = { 0.06, -0.02 } },
	longbow_15 = { model = "longbow_15", length = 5.1, grip = 0.5, hold = { 0.03, 0 } },
	longbow_20 = { model = "longbow_20", length = 5.1, grip = 0.5, hold = { 0.04, 0 } },
	-- crossbow
	crossbow_1 = { model = "crossbow_1", length = 2.2, grip = 0.3, hold = { 0.02, -0.1 } },
	crossbow_5 = { model = "crossbow_5", length = 2.2, grip = 0.3, hold = { 0.01, 0.03 } },
	crossbow_10 = { model = "crossbow_10", length = 2.2, grip = 0.3, hold = { 0.06, 0.04 } },
	crossbow_15 = { model = "crossbow_15", length = 2.2, grip = 0.3, hold = { 0.1, -0.02 } },
	crossbow_20 = { model = "crossbow_20", length = 2.2, grip = 0.3, hold = { 0.02, -0.05 } },
	-- heavycrossbow
	heavycrossbow_1 = { model = "heavycrossbow_1", length = 2.75, grip = 0.3, hold = { -0.03, 0 } },
	heavycrossbow_5 = { model = "heavycrossbow_5", length = 2.75, grip = 0.3, hold = { 0.01, -0.01 } },
	heavycrossbow_10 = { model = "heavycrossbow_10", length = 2.75, grip = 0.3, hold = { -0.04, -0.03 } },
	heavycrossbow_15 = { model = "heavycrossbow_15", length = 2.75, grip = 0.3, hold = { -0.09, -0.03 } },
	heavycrossbow_20 = { model = "heavycrossbow_20", length = 2.75, grip = 0.3, hold = { 0, -0.1 } },
	-- shield
	shield_1 = { model = "shield_1", length = 2.2, grip = 0.5 },
	shield_5 = { model = "shield_5", length = 2.2, grip = 0.5 },
	shield_10 = { model = "shield_10", length = 2.2, grip = 0.5 },
	shield_15 = { model = "shield_15", length = 2.2, grip = 0.5 },
	shield_20 = { model = "shield_20", length = 2.2, grip = 0.5 },
	-- quiver
	quiver_1 = { model = "quiver_1", length = 2.5, grip = 0.5 },
	quiver_5 = { model = "quiver_5", length = 2.5, grip = 0.5 },
	quiver_10 = { model = "quiver_10", length = 2.5, grip = 0.5 },
	quiver_15 = { model = "quiver_15", length = 2.5, grip = 0.5 },
	quiver_20 = { model = "quiver_20", length = 2.5, grip = 0.5 },
	-- tome
	tome_1 = { model = "tome_1", length = 1.1, grip = 0.5 },
	tome_5 = { model = "tome_5", length = 1.1, grip = 0.5 },
	tome_10 = { model = "tome_10", length = 1.1, grip = 0.5 },
	tome_15 = { model = "tome_15", length = 1.1, grip = 0.5 },
	tome_20 = { model = "tome_20", length = 1.1, grip = 0.5 },
	-- orb
	orb_1 = { model = "orb_1", length = 0.8, grip = 0.5 },
	orb_5 = { model = "orb_5", length = 0.8, grip = 0.5 },
	orb_10 = { model = "orb_10", length = 0.8, grip = 0.5 },
	orb_15 = { model = "orb_15", length = 0.8, grip = 0.5 },
	orb_20 = { model = "orb_20", length = 0.8, grip = 0.5 },
	-- relic
	relic_1 = { model = "relic_1", length = 1.1, grip = 0.5 },
	relic_5 = { model = "relic_5", length = 1.1, grip = 0.5 },
	relic_10 = { model = "relic_10", length = 1.1, grip = 0.5 },
	relic_15 = { model = "relic_15", length = 1.1, grip = 0.5 },
	relic_20 = { model = "relic_20", length = 1.1, grip = 0.5 },
	-- Boss items (S52: before the type's tiers in ArtTiers.modelId)
	unique_grimrok_cleaver = { model = "unique_grimrok_cleaver", length = 2.8, grip = 0.15, hold = { 0, -0.01 } },
} :: { [string]: Asset }

return WeaponLooks
