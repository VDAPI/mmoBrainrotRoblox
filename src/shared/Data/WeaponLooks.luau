--!strict
-- Placeholder 3D looks of held weapons and off-hands (S18), built from a few Parts by EquipmentService.
-- Frame: origin at the palm of the hand ("back": centre of the upper torso), -Z = forward (the way the
-- weapon points), +Y = up the arm, +X = right. Sizes and positions in studs, rotations in degrees.
-- The first piece is the main part (named VaelthornWeapon / VaelthornOffhand; weapon cosmetics and the
-- epic+ glow attach to it). Colour "rarity" takes the item's rarity colour.
-- A real model can replace these later without touching the item data.

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

WeaponLooks.list = looks

function WeaponLooks.get(itemType: string): Look?
	return looks[itemType]
end

return WeaponLooks
