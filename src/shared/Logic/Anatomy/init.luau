--!strict
-- Procedural monster, boss and pet looks (S24, docs/MODELE.md). Pure: a Look (Data/MonsterLooks) and options
-- in, a Rig out:
--   root      : hitbox size (the server's HumanoidRootPart)
--   hipHeight : Humanoid.HipHeight (ground to the bottom of the root; fliers + hover)
--   height    : top of the look above the ground (name plates)
--   pieces    : parts relative to the root centre, already scaled (see Builder.Piece); `parent` names an
--               earlier piece (nil: the root), `joint` makes a Gait_<name> Motor6D (Logic/Gait roles)
--   sockets   : mounting points (Head, Back, Hand_R, ...) relative to the root centre
--   fx        : particle preset ("embers", "frost", "mist", "spores") or nil
-- Same inputs, same pieces (randomness only from the id seed). LOD "far" keeps at most 3 pieces, no joints.

local Accessories = require("@self/Accessories")
local Builder = require("@self/Builder")
local Plans = require("@self/Plans")
local Weapons = require("@self/Weapons")

local Anatomy = {}

export type Vec = Builder.Vec
export type Piece = Builder.Piece
export type Joint = Builder.Joint

export type Look = {
	plan: string,
	build: { [string]: number }?,
	colors: { base: string, accent: string, detail: string?, eye: string? },
	materials: { base: string?, accent: string?, detail: string? }?,
	parts: { string }?,
	weapon: string?,
	offhand: string?,
	glow: string?,
	fx: string?,
	elite: { string }?,
	elite2: { string }?,
	weaponScale: number?,
	glowEyes: boolean?, -- glowing eyes always (undead, elementals, constructs)
}

export type Options = {
	id: string, -- seed
	variant: string?, -- "normal" | "elite" | "elite2" | "boss" | "pet"
	scale: number?,
	lod: "full" | "far" | nil,
}

export type Rig = {
	root: { size: Vec },
	hipHeight: number,
	height: number,
	pieces: { Piece },
	sockets: { [string]: { pos: Vec, parent: string? } },
	fx: string?,
	plan: string,
}

-- Materials a look may use (checked by tests).
Anatomy.MATERIALS = {
	"SmoothPlastic",
	"Fabric",
	"Leather",
	"Wood",
	"WoodPlanks",
	"Slate",
	"Basalt",
	"Rock",
	"Limestone",
	"Metal",
	"CorrodedMetal",
	"DiamondPlate",
	"Ice",
	"Glacier",
	"Glass",
	"Neon",
	"CrackedLava",
	"Grass",
	"Sand",
	"Granite",
}

-- Part budgets per variant (normal monsters include weapons, accessories and Elite II extras).
Anatomy.BUDGET = { normal = 36, elite = 36, elite2 = 36, boss = 90, pet = 16, far = 3 }

-- Joint roles Logic/Gait knows.
Anatomy.ROLES = {
	"body",
	"leg",
	"spiderLeg",
	"arm",
	"head",
	"tail",
	"wing",
	"flap",
	"segment",
	"claw",
	"sting",
	"jaw",
	"orbit",
}

Anatomy.HOVER = 2.5 -- studs at scale 1 for floating plans

-- Default extra accessories of elites when the look gives none.
local ELITE_DEFAULT = { "eliteHorns" }
local ELITE2_DEFAULT = { "runes" }

Anatomy.tone = Builder.tone
Anatomy.mix = Builder.mix
Anatomy.isHex = Builder.isHex

local function seedOf(text: string): number
	local h = 7
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

-- Palette of a look: three tones of the base colour plus accent, detail, eye and glow.
function Anatomy.palette(look: Look): Builder.Palette
	local base = Builder.clampColor(look.colors.base)
	return {
		base = base,
		shade = Builder.tone(base, 0.75),
		light = Builder.tone(base, 1.25),
		accent = Builder.clampColor(look.colors.accent),
		detail = Builder.clampColor(look.colors.detail or Builder.tone(base, 0.55)),
		eye = Builder.clampColor(look.colors.eye or "#E8D9A0"),
		glow = look.glow or look.colors.eye or "#FFD86E",
	}
end

-- Rotation of a piece as a 3x3 matrix (CFrame.Angles order: X, then Y, then Z applied to the vector).
local function matrix(rot: Vec): { { number } }
	local x, y, z = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
	-- R = Rx * Ry * Rz
	return {
		{ cy * cz, -cy * sz, sy },
		{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
		{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
	}
end

-- Half extents of a rotated box on the world axes.
local function extents(size: Vec, rot: Vec): Vec
	local m = matrix(rot)
	local h = { size[1] / 2, size[2] / 2, size[3] / 2 }
	local out = {}
	for i = 1, 3 do
		out[i] = math.abs(m[i][1]) * h[1] + math.abs(m[i][2]) * h[2] + math.abs(m[i][3]) * h[3]
	end
	return out
end
Anatomy.extents = extents

local function apply(b: Builder.Builder, names: { string }?)
	for _, name in names or ({} :: { string }) do
		local accessory = (Accessories :: any)[name]
		if accessory then
			accessory(b)
		end
	end
end

-- Builds the rig of a look.
function Anatomy.build(look: Look, opts: Options): Rig
	local variant = opts.variant or "normal"
	local scale = opts.scale or 1
	local build = table.clone(look.build or {})
	local glowEyes = look.glowEyes == true or variant == "elite" or variant == "elite2" or variant == "boss"
	if glowEyes then
		build.glowEyes = 1
	end
	if variant == "pet" then
		build.chibi = build.chibi or 1
	end
	local palette = Anatomy.palette(look)
	if variant == "elite2" or variant == "boss" then
		palette.glow = look.glow or "#C77BFF"
	end
	local materials = {
		base = (look.materials and look.materials.base) or "Fabric",
		accent = (look.materials and look.materials.accent) or "SmoothPlastic",
		detail = (look.materials and look.materials.detail) or "Leather",
	}
	local b = Builder.new(palette, materials, build, seedOf(opts.id))
	local plan = Plans.get(look.plan) or Plans.get("humanoid")
	assert(plan, "Anatomy: no humanoid plan")
	plan(b)
	apply(b, look.parts)
	if look.weapon then
		Weapons.mount(b, look.weapon, nil, look.weaponScale)
	end
	if look.offhand then
		if Weapons.exists(look.offhand) then
			Weapons.mount(b, look.offhand, "Hand_L", look.weaponScale)
		else
			apply(b, { look.offhand })
		end
	end
	if variant == "elite" or variant == "elite2" then
		apply(b, look.elite or ELITE_DEFAULT)
	end
	if variant == "elite2" then
		apply(b, look.elite2 or ELITE2_DEFAULT)
	end

	local pieces = b.pieces
	local core = b.core and b.byName[b.core] or pieces[1]
	if opts.lod == "far" then
		local kept: { Piece } = {}
		for _, piece in pieces do
			if piece.far and #kept < 3 then
				local copy = table.clone(piece)
				copy.joint = nil
				copy.parent = nil
				table.insert(kept, copy)
			end
		end
		pieces = kept
	end

	-- Bounds in ground space.
	local lowest, highest = math.huge, -math.huge
	for _, piece in b.pieces do
		local e = extents(piece.size, piece.rot)
		lowest = math.min(lowest, piece.pos[2] - e[2])
		highest = math.max(highest, piece.pos[2] + e[2])
	end
	local coreExt = extents(core.size, core.rot)
	local centre = { core.pos[1], core.pos[2], core.pos[3] }
	local rootSize = {
		math.max(0.8, coreExt[1] * 2 * 1.08 + 0.1),
		math.max(0.6, coreExt[2] * 2 * 1.08 + 0.1),
		math.max(0.8, coreExt[3] * 2 * 1.08 + 0.1),
	}
	-- The root's bottom must stay above the ground (HipHeight >= 0.1).
	local maxHalf = centre[2] - lowest - 0.1
	if rootSize[2] / 2 > maxHalf then
		rootSize[2] = math.max(0.4, maxHalf * 2)
	end
	local hover = if Plans.hovers(look.plan) then Anatomy.HOVER else 0
	local hipHeight = math.max(0.1, centre[2] - rootSize[2] / 2 - lowest) + hover
	local height = (highest - lowest) + hover

	local out: { Piece } = {}
	for _, piece in pieces do
		local p = piece.pos
		local size = { piece.size[1] * scale, piece.size[2] * scale, piece.size[3] * scale }
		local joint: Joint? = nil
		if piece.joint then
			local j = piece.joint
			local at = j.at or p
			joint = {
				role = j.role,
				side = j.side or 0,
				phase = j.phase or 0,
				amp = j.amp or 1,
				at = { (at[1] - centre[1]) * scale, (at[2] - centre[2]) * scale, (at[3] - centre[3]) * scale },
			}
		end
		table.insert(out, {
			name = piece.name,
			shape = piece.shape,
			size = size,
			pos = { (p[1] - centre[1]) * scale, (p[2] - centre[2]) * scale, (p[3] - centre[3]) * scale },
			rot = piece.rot,
			color = piece.color,
			material = piece.material,
			transparency = piece.transparency,
			glow = piece.glow,
			parent = piece.parent,
			joint = joint,
			far = piece.far,
			shadow = math.max(size[1], size[2], size[3]) >= 1.5 and (piece.transparency or 0) < 0.5,
		})
	end
	local sockets = {}
	for name, socket in b.sockets do
		sockets[name] = {
			pos = {
				(socket.pos[1] - centre[1]) * scale,
				(socket.pos[2] - centre[2]) * scale,
				(socket.pos[3] - centre[3]) * scale,
			},
			parent = socket.parent,
		}
	end
	return {
		root = { size = { rootSize[1] * scale, rootSize[2] * scale, rootSize[3] * scale } },
		hipHeight = hipHeight * scale,
		height = height * scale,
		pieces = out,
		sockets = sockets,
		fx = look.fx,
		plan = look.plan,
	}
end

return Anatomy
