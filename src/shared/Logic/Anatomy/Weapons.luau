--!strict
-- Weapons in monster hands (S24): the player weapon looks (Data/WeaponLooks, same palm frame: -Z the way the
-- weapon points, +Y up the arm, +X right) plus monster-only weapons below, turned into Anatomy pieces on the
-- Hand_R / Hand_L sockets (looks with hand = "back" go to the Back socket). Colour "rarity" becomes the look's
-- accent, "glow" its glow colour; "Ball" / "Cylinder" shapes become ball / cyl.

local Builder = require("./Builder")
local WeaponLooks = require("../../Data/WeaponLooks")

type B = Builder.Builder

local Weapons = {}

type Piece = WeaponLooks.Piece

local WOOD = "#6B4A2B"
local DARK_WOOD = "#4A3624"
local IRON = "#8E8E93"
local BONE = "#E0D8C4"

-- Monster-only weapons (palm frame, studs at scale 1).
local CUSTOM: { [string]: { hand: string?, pieces: { Piece } } } = {
	club = {
		pieces = {
			{
				name = "Club",
				size = { 0.75, 0.75, 1.6 },
				pos = { 0, 0, -2.0 },
				color = WOOD,
				material = "Wood",
				shape = "Ball",
			},
			{ name = "Shaft", size = { 0.3, 0.3, 1.8 }, pos = { 0, 0, -0.55 }, color = DARK_WOOD, material = "Wood" },
		},
	},
	iceClub = {
		pieces = {
			{
				name = "Club",
				size = { 0.95, 0.95, 2.0 },
				pos = { 0, 0, -2.3 },
				color = "#B8E4F5",
				material = "Ice",
				shape = "Ball",
			},
			{
				name = "Shaft",
				size = { 0.34, 0.34, 1.9 },
				pos = { 0, 0, -0.6 },
				color = "#7FA7C9",
				material = "Glacier",
			},
		},
	},
	pickaxe = {
		pieces = {
			{ name = "Shaft", size = { 0.2, 0.2, 2.4 }, pos = { 0, 0, -0.9 }, color = WOOD, material = "Wood" },
			{ name = "Pick", size = { 0.22, 1.7, 0.24 }, pos = { 0, 0.1, -2.05 }, color = IRON, material = "Metal" },
		},
	},
	cleaver = {
		pieces = {
			{
				name = "Blade",
				size = { 0.14, 1.3, 1.9 },
				pos = { 0, -0.3, -1.5 },
				color = "#9AA0A8",
				material = "Metal",
			},
			{
				name = "Edge",
				size = { 0.16, 0.18, 1.9 },
				pos = { 0, -0.95, -1.5 },
				color = "rarity",
				material = "Metal",
			},
			{ name = "Grip", size = { 0.22, 0.22, 0.8 }, pos = { 0, 0, -0.15 }, color = DARK_WOOD, material = "Wood" },
		},
	},
	scythe = {
		pieces = {
			{ name = "Shaft", size = { 0.2, 4.4, 0.2 }, pos = { 0, 1.0, 0 }, color = DARK_WOOD, material = "Wood" },
			{
				name = "Blade",
				size = { 0.12, 0.45, 2.2 },
				pos = { 0, 3.0, -1.0 },
				color = "#B8C0C8",
				material = "Metal",
			},
			{
				name = "Gem",
				size = { 0.3, 0.3, 0.3 },
				pos = { 0, 3.2, 0 },
				color = "glow",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	torch = {
		pieces = {
			{ name = "Stick", size = { 0.2, 0.2, 1.4 }, pos = { 0, 0, -0.5 }, color = WOOD, material = "Wood" },
			{
				name = "Flame",
				size = { 0.45, 0.6, 0.45 },
				pos = { 0, 0.1, -1.35 },
				color = "glow",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	dagger = {
		pieces = {
			{
				name = "Blade",
				size = { 0.1, 0.24, 1.15 },
				pos = { 0, 0, -0.95 },
				color = "#C9CED6",
				material = "Metal",
			},
			{
				name = "Grip",
				size = { 0.16, 0.16, 0.45 },
				pos = { 0, 0, -0.1 },
				color = DARK_WOOD,
				material = "Leather",
			},
		},
	},
	ritualDagger = {
		pieces = {
			{ name = "Blade", size = { 0.1, 0.28, 1.2 }, pos = { 0, 0, -0.95 }, color = "rarity", material = "Metal" },
			{
				name = "Gem",
				size = { 0.2, 0.2, 0.2 },
				pos = { 0, 0, -0.3 },
				color = "glow",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	skullStaff = {
		pieces = {
			{ name = "Shaft", size = { 0.22, 4.2, 0.22 }, pos = { 0, 1.1, 0 }, color = DARK_WOOD, material = "Wood" },
			{
				name = "Skull",
				size = { 0.6, 0.6, 0.6 },
				pos = { 0, 3.35, 0 },
				color = BONE,
				material = "SmoothPlastic",
				shape = "Ball",
			},
			{
				name = "Gem",
				size = { 0.24, 0.24, 0.24 },
				pos = { 0, 3.35, -0.32 },
				color = "glow",
				material = "Neon",
				shape = "Ball",
			},
		},
	},
	broom = {
		pieces = {
			{ name = "Shaft", size = { 0.18, 3.6, 0.18 }, pos = { 0, 0.9, 0 }, color = WOOD, material = "Wood" },
			{
				name = "Bristles",
				size = { 0.6, 1.0, 0.6 },
				pos = { 0, -1.05, 0 },
				color = "#A88A5A",
				material = "Fabric",
				shape = "Ball",
			},
		},
	},
	smithHammer = {
		pieces = {
			{ name = "Handle", size = { 0.22, 0.22, 1.7 }, pos = { 0, 0, -0.6 }, color = WOOD, material = "Wood" },
			{ name = "Head", size = { 1.0, 0.65, 0.65 }, pos = { 0, 0, -1.55 }, color = "#5E5E66", material = "Metal" },
		},
	},
	flameSword = {
		pieces = {
			{ name = "Blade", size = { 0.18, 0.5, 4.0 }, pos = { 0, 0, -2.6 }, color = "glow", material = "Neon" },
			{
				name = "Guard",
				size = { 1.1, 0.25, 0.25 },
				pos = { 0, 0, -0.5 },
				color = "#3A2A22",
				material = "Basalt",
			},
			{ name = "Grip", size = { 0.24, 0.24, 0.9 }, pos = { 0, 0, 0 }, color = "#2B1F1A", material = "Basalt" },
		},
	},
	frostSword = {
		pieces = {
			{ name = "Blade", size = { 0.16, 0.45, 3.6 }, pos = { 0, 0, -2.4 }, color = "#B8E4F5", material = "Ice" },
			{
				name = "Guard",
				size = { 1.0, 0.22, 0.22 },
				pos = { 0, 0, -0.45 },
				color = "#5A7A9A",
				material = "Metal",
			},
			{ name = "Grip", size = { 0.22, 0.22, 0.85 }, pos = { 0, 0, 0 }, color = "#2F3A4A", material = "Leather" },
		},
	},
	skullShield = {
		hand = "left",
		pieces = {
			{ name = "Shield", size = { 1.6, 1.8, 0.2 }, pos = { 0, 0, -0.35 }, color = "#5A3D2B", material = "Wood" },
			{
				name = "Skull",
				size = { 0.6, 0.6, 0.4 },
				pos = { 0, 0.1, -0.55 },
				color = BONE,
				material = "SmoothPlastic",
				shape = "Ball",
			},
		},
	},
	rustyShield = {
		hand = "left",
		pieces = {
			{
				name = "Shield",
				size = { 1.4, 1.6, 0.18 },
				pos = { 0, 0, -0.35 },
				color = "#6E5A48",
				material = "CorrodedMetal",
			},
			{
				name = "Boss",
				size = { 0.35, 0.35, 0.25 },
				pos = { 0, 0, -0.5 },
				color = "#8A7A6A",
				material = "CorrodedMetal",
				shape = "Ball",
			},
		},
	},
	tome = WeaponLooks.list.tome :: any,
}

local function shapeOf(shape: string?): string
	if shape == "Ball" then
		return "ball"
	elseif shape == "Cylinder" then
		return "cyl"
	end
	return "block"
end

function Weapons.exists(key: string): boolean
	return CUSTOM[key] ~= nil or WeaponLooks.get(key) ~= nil
end

-- Mounts weapon `key` on `socketName` (default by the look's hand) at size `k`. Returns the number of pieces.
function Weapons.mount(b: B, key: string, socketName: string?, k: number?): number
	local look = CUSTOM[key] or (WeaponLooks.get(key) :: any)
	if not look then
		return 0
	end
	local name = socketName
	if not name then
		name = if look.hand == "back" then "Back" elseif look.hand == "left" then "Hand_L" else "Hand_R"
	end
	local socket = b.sockets[name :: string]
	if not socket then
		return 0
	end
	local scale = k or 1
	local count = 0
	for _, piece in look.pieces do
		local color = piece.color
		local tone = if color == "rarity" then "accent" elseif color == "glow" then "glow" else color
		local p = piece.pos
		local s = piece.size
		b:add(`W{piece.name}`, shapeOf(piece.shape), { s[1] * scale, s[2] * scale, s[3] * scale }, {
			socket.pos[1] + p[1] * scale,
			socket.pos[2] + p[2] * scale,
			socket.pos[3] + p[3] * scale,
		}, {
			tone = tone,
			material = if color == "glow" then "Neon" else piece.material,
			rot = piece.rot,
			parent = socket.parent,
		})
		count += 1
	end
	return count
end

return Weapons
