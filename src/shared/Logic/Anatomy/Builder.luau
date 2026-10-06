--!strict
-- Piece builder of the procedural monster looks (S24, Logic/Anatomy). Plans and accessories author pieces in
-- "ground space" at scale 1: x to the right, y up from the ground (feet at 0), z to the back (-z is forward),
-- sizes and positions in studs, rotations in degrees (CFrame.Angles order X, Y, Z). Colours come from tones of
-- the look's palette; Anatomy.build turns the result into root-relative, scaled pieces. Pure.

local Builder = {}
Builder.__index = Builder

export type Vec = { number }

export type Joint = {
	role: string, -- Logic/Gait role
	side: number?,
	phase: number?,
	amp: number?,
	at: Vec?, -- pivot point (ground space); default: the piece's centre
}

export type Piece = {
	name: string,
	shape: string, -- "block" | "ball" | "cyl" | "wedge" | "corner"
	size: Vec,
	pos: Vec,
	rot: Vec,
	color: string,
	material: string,
	transparency: number?,
	glow: boolean?,
	parent: string?, -- piece this one hangs from (nil: the root)
	joint: Joint?,
	far: boolean?,
	shadow: boolean?,
}

export type Palette = {
	base: string,
	shade: string,
	light: string,
	accent: string,
	detail: string,
	eye: string,
	glow: string?,
}

export type Materials = { base: string, accent: string, detail: string }

export type Options = {
	tone: string?, -- "base" | "shade" | "light" | "accent" | "detail" | "eye" | "glow" | "#RRGGBB"
	material: string?, -- "base" | "accent" | "detail" | Enum.Material name
	rot: Vec?,
	parent: string?,
	joint: Joint?,
	far: boolean?,
	transparency: number?,
	glow: boolean?,
}

export type Builder = typeof(setmetatable(
	{} :: {
		pieces: { Piece },
		byName: { [string]: Piece },
		palette: Palette,
		materials: Materials,
		sockets: { [string]: { pos: Vec, parent: string? } },
		build: { [string]: number },
		seed: number,
		core: string?,
	},
	Builder
))

-- Colours --------------------------------------------------------------------------------------------------

local function channels(hex: string): (number, number, number)
	local r = tonumber(string.sub(hex, 2, 3), 16) or 0
	local g = tonumber(string.sub(hex, 4, 5), 16) or 0
	local b = tonumber(string.sub(hex, 6, 7), 16) or 0
	return r, g, b
end

local function toHex(r: number, g: number, b: number): string
	local function c(v: number): number
		return math.clamp(math.floor(v + 0.5), 0, 255)
	end
	return string.format("#%02X%02X%02X", c(r), c(g), c(b))
end

-- Darkest and brightest allowed colours (no pure black / white).
Builder.DARKEST = "#1E1E24"
Builder.BRIGHTEST = "#EDE6D6"

-- Keeps a colour between DARKEST and BRIGHTEST by brightness.
function Builder.clampColor(hex: string): string
	local r, g, b = channels(hex)
	local lo = 0x1E
	local hi = 0xED
	local maxc = math.max(r, g, b)
	local minc = math.min(r, g, b)
	if maxc < lo + 6 then
		local add = lo + 6 - maxc
		r, g, b = r + add, g + add, b + add
	end
	if minc > hi - 6 then
		local sub = minc - (hi - 6)
		r, g, b = r - sub, g - sub, b - sub
	end
	return toHex(r, g, b)
end

-- Brightness change: f < 1 darker, f > 1 lighter (towards white without clipping hue badly).
function Builder.tone(hex: string, f: number): string
	local r, g, b = channels(hex)
	if f <= 1 then
		return Builder.clampColor(toHex(r * f, g * f, b * f))
	end
	local k = math.clamp(f - 1, 0, 1)
	return Builder.clampColor(toHex(r + (255 - r) * k * 0.6, g + (255 - g) * k * 0.6, b + (255 - b) * k * 0.6))
end

-- Linear mix of two colours (t = 0: a, 1: b).
function Builder.mix(a: string, b: string, t: number): string
	local r1, g1, b1 = channels(a)
	local r2, g2, b2 = channels(b)
	return toHex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
end

function Builder.isHex(value: any): boolean
	return type(value) == "string" and string.match(value, "^#%x%x%x%x%x%x$") ~= nil
end

-- Builder ----------------------------------------------------------------------------------------------------

function Builder.new(palette: Palette, materials: Materials, build: { [string]: number }?, seed: number): Builder
	return setmetatable({
		pieces = {},
		byName = {},
		palette = palette,
		materials = materials,
		sockets = {},
		build = build or {},
		seed = seed,
		core = nil,
	}, Builder)
end

-- Proportion from the look's `build` (default when absent).
function Builder.get(self: Builder, key: string, default: number): number
	local v = self.build[key]
	return if type(v) == "number" then v else default
end

-- Deterministic pseudo-random 0..1 for index `i` (only from the look id seed).
function Builder.rand(self: Builder, i: number): number
	local x = math.sin(self.seed * 12.9898 + i * 78.233) * 43758.5453
	return x - math.floor(x)
end

function Builder.color(self: Builder, tone: string?): string
	local t = tone or "base"
	if Builder.isHex(t) then
		return Builder.clampColor(t)
	end
	local p = self.palette :: any
	return p[t] or self.palette.base
end

function Builder.materialOf(self: Builder, key: string?): string
	local k = key or "base"
	local m = self.materials :: any
	return m[k] or k
end

-- Adds a piece. Names are unique: a repeated name gets a numeric suffix.
function Builder.add(self: Builder, name: string, shape: string, size: Vec, pos: Vec, o: Options?): Piece
	local opts: Options = o or ({} :: Options)
	local unique = name
	local n = 1
	while self.byName[unique] do
		n += 1
		unique = `{name}{n}`
	end
	local tone = opts.tone or "base"
	local glow = opts.glow == true or tone == "glow"
	local piece: Piece = {
		name = unique,
		shape = shape,
		size = { size[1], size[2], size[3] },
		pos = { pos[1], pos[2], pos[3] },
		rot = if opts.rot then { opts.rot[1], opts.rot[2], opts.rot[3] } else { 0, 0, 0 },
		color = if glow then (self.palette.glow or self.palette.eye) else self:color(tone),
		material = if glow then "Neon" else self:materialOf(opts.material),
		transparency = opts.transparency,
		glow = if glow then true else nil,
		parent = opts.parent,
		joint = opts.joint,
		far = opts.far,
	}
	table.insert(self.pieces, piece)
	self.byName[unique] = piece
	return piece
end

-- Adds a left / right pair mirrored on X: names get "L" / "R", the Y and Z rotations flip, joints get
-- side -1 / 1 (and their pivots mirror too). `pos` is the right-hand piece.
function Builder.pair(self: Builder, name: string, shape: string, size: Vec, pos: Vec, o: Options?): (Piece, Piece)
	local opts: Options = o or ({} :: Options)
	local function side(sign: number, suffix: string): Piece
		local rot = opts.rot or { 0, 0, 0 }
		local joint: Joint? = nil
		if opts.joint then
			local j = opts.joint
			joint = {
				role = j.role,
				side = sign,
				phase = j.phase,
				amp = j.amp,
				at = if j.at then { j.at[1] * sign, j.at[2], j.at[3] } else nil,
			}
		end
		local parent = opts.parent
		if parent and string.sub(parent, -1) == "*" then
			parent = string.sub(parent, 1, -2) .. suffix
		end
		return self:add(`{name}{suffix}`, shape, size, { pos[1] * sign, pos[2], pos[3] }, {
			tone = opts.tone,
			material = opts.material,
			rot = if sign > 0 then rot else { rot[1], -rot[2], -rot[3] },
			parent = parent,
			joint = joint,
			far = opts.far,
			transparency = opts.transparency,
			glow = opts.glow,
		})
	end
	local l = side(-1, "L")
	local r = side(1, "R")
	return l, r
end

-- The core body piece: jointed to the root with the "body" role (bob, lean, collapse).
function Builder.coreBody(self: Builder, name: string, shape: string, size: Vec, pos: Vec, o: Options?): Piece
	local opts = table.clone(o or {}) :: Options
	opts.joint =
		{ role = "body", amp = (opts.joint and opts.joint.amp) or 1, at = { pos[1], pos[2] - size[2] / 2, pos[3] } }
	opts.far = true
	local piece = self:add(name, shape, size, pos, opts)
	self.core = piece.name
	return piece
end

-- A mounting point for accessories (ground space position, piece it moves with).
function Builder.socket(self: Builder, name: string, pos: Vec, parent: string?)
	self.sockets[name] = { pos = { pos[1], pos[2], pos[3] }, parent = parent }
end

-- Two eyes: a ball and (from 0.3 studs) a darker pupil a little in front. `pos` is the right eye; glowing
-- eyes skip the pupil.
function Builder.eyes(self: Builder, parent: string, pos: Vec, size: number, glow: boolean?)
	if glow then
		self:pair("Eye", "ball", { size, size, size }, pos, { tone = "glow", parent = parent })
		return
	end
	if size < 0.3 then
		self:pair(
			"Eye",
			"ball",
			{ size, size, size },
			pos,
			{ tone = "#2A2426", material = "SmoothPlastic", parent = parent }
		)
		return
	end
	self:pair("Eye", "ball", { size, size, size }, pos, { tone = "eye", material = "SmoothPlastic", parent = parent })
	self:pair("Pupil", "ball", { size * 0.55, size * 0.55, size * 0.55 }, { pos[1], pos[2], pos[3] - size * 0.32 }, {
		tone = Builder.DARKEST,
		material = "SmoothPlastic",
		parent = parent,
	})
end

return Builder
