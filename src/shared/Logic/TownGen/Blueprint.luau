--!strict
-- Blueprint: primitive pieces in building-local space, produced by TownGen and turned into Parts by
-- Util/BlueprintBuild (S21). Pure: plain numbers only, no CFrame, so it runs in Lune.
--
-- Local space: origin at the footprint centre on the floor level, x along the frontage, y up, the front of the
-- building faces -Z. Each piece stores its centre `p` and a 3x3 rotation `r` (row-major, the same order as the
-- CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22) constructor).
--
-- Shapes follow Roblox parts: "box" = Part Block, "wedge" = WedgePart (slope falls from the top of the +Z face to
-- the bottom of the -Z face), "cyl" = Part Cylinder (axis along local X), "ball" = Part Ball, "corner" =
-- CornerWedgePart.

local Rng = require("../Rng")

export type Shape = "box" | "wedge" | "cyl" | "ball" | "corner"
-- shell: always built (server, collision, far silhouette); detail: built by the client near the camera;
-- fine: small ornaments built only very close (flowers, iron studs, moss, window bars).
export type Lod = "shell" | "detail" | "fine"

export type Piece = {
	s: Shape,
	size: { number },
	p: { number },
	r: { number },
	c: string,
	m: string,
	lod: Lod,
	col: boolean, -- CanCollide
	q: boolean, -- CanQuery (camera and clicks; only meaningful with col = true)
	t: number?, -- Transparency
	tag: string?, -- client behaviour: "window", "smoke", "lamp", "flag", "wheel", "sail", "fire", "water"
}

export type Light = { p: { number }, color: string, range: number, brightness: number, tag: string? }

export type Options = {
	c: string,
	m: string,
	lod: Lod?,
	col: boolean?,
	q: boolean?,
	t: number?,
	tag: string?,
	jitter: number?, -- colour jitter override (0..1), default 0.05
}

type Mat3 = { number }
type Frame = { o: { number }, r: Mat3 }

local Blueprint = {}
Blueprint.__index = Blueprint

export type Blueprint = typeof(setmetatable(
	{} :: {
		pieces: { Piece },
		lights: { Light },
		rng: Rng.Rng,
		frames: { Frame },
		shell: number,
		detail: number,
		fine: number,
	},
	Blueprint
))

local IDENTITY: Mat3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function mul(a: Mat3, b: Mat3): Mat3
	local out = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
		end
	end
	return out
end

local function apply(r: Mat3, x: number, y: number, z: number): (number, number, number)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end

-- Rotation matrix of CFrame.Angles(rx, ry, rz) (= Rx * Ry * Rz), angles in degrees.
function Blueprint.angles(rx: number, ry: number, rz: number): Mat3
	local a, b, c = math.rad(rx), math.rad(ry), math.rad(rz)
	local cx, sx, cy, sy, cz, sz = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return mul(mul(X, Y), Z)
end

function Blueprint.new(seed: number): Blueprint
	return setmetatable({
		pieces = {},
		lights = {},
		rng = Rng.new(seed),
		frames = { { o = { 0, 0, 0 }, r = IDENTITY } },
		shell = 0,
		detail = 0,
		fine = 0,
	}, Blueprint)
end

-- Enters a sub-frame: translate by (x, y, z) in the current frame, then rotate (degrees, Angles order).
function Blueprint.push(self: Blueprint, x: number, y: number, z: number, rx: number?, ry: number?, rz: number?)
	local top = self.frames[#self.frames]
	local dx, dy, dz = apply(top.r, x, y, z)
	local r = top.r
	if rx or ry or rz then
		r = mul(top.r, Blueprint.angles(rx or 0, ry or 0, rz or 0))
	end
	table.insert(self.frames, { o = { top.o[1] + dx, top.o[2] + dy, top.o[3] + dz }, r = r })
end

function Blueprint.pop(self: Blueprint)
	assert(#self.frames > 1, "Blueprint.pop: no frame to pop")
	table.remove(self.frames)
end

-- Weathered colour: random brightness/saturation drift so no two beams match exactly.
function Blueprint.jitter(self: Blueprint, hex: string, amount: number?): string
	local a = amount or 0.05
	if a <= 0 then
		return hex
	end
	local r = tonumber(string.sub(hex, 2, 3), 16) :: number
	local g = tonumber(string.sub(hex, 4, 5), 16) :: number
	local b = tonumber(string.sub(hex, 6, 7), 16) :: number
	local k = 1 + self.rng:float(-a, a)
	local warm = self.rng:float(-a, a) * 40
	local function clamp(v: number): number
		return math.clamp(math.floor(v + 0.5), 0, 255)
	end
	return string.format("#%02X%02X%02X", clamp(r * k + warm), clamp(g * k), clamp(b * k - warm * 0.5))
end

-- Adds a piece at local position (x, y, z) of the current frame with rotation (rx, ry, rz) degrees.
function Blueprint.add(
	self: Blueprint,
	shape: Shape,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	o: Options
): Piece
	local top = self.frames[#self.frames]
	local dx, dy, dz = apply(top.r, x, y, z)
	local r = if rx == 0 and ry == 0 and rz == 0 then top.r else mul(top.r, Blueprint.angles(rx, ry, rz))
	local lod: Lod = o.lod or "detail"
	local col = if o.col ~= nil then o.col else lod == "shell"
	local piece: Piece = {
		s = shape,
		size = { math.max(sx, 0.05), math.max(sy, 0.05), math.max(sz, 0.05) },
		p = { top.o[1] + dx, top.o[2] + dy, top.o[3] + dz },
		r = r,
		c = self:jitter(o.c, o.jitter),
		m = o.m,
		lod = lod,
		col = col,
		q = if o.q ~= nil then o.q else col,
		t = o.t,
		tag = o.tag,
	}
	table.insert(self.pieces, piece)
	if lod == "shell" then
		self.shell += 1
	elseif lod == "fine" then
		self.fine += 1
	else
		self.detail += 1
	end
	return piece
end

function Blueprint.box(self: Blueprint, sx: number, sy: number, sz: number, x: number, y: number, z: number, o: Options)
	return self:add("box", sx, sy, sz, x, y, z, 0, 0, 0, o)
end

-- Box rotated by (rx, ry, rz) degrees around its own centre.
function Blueprint.rbox(
	self: Blueprint,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	o: Options
)
	return self:add("box", sx, sy, sz, x, y, z, rx, ry, rz, o)
end

-- Beam between two local points: `t` studs thick, `h` (default t) tall.
function Blueprint.beam(
	self: Blueprint,
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	t: number,
	o: Options,
	h: number?
): Piece?
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 0.05 then
		return nil
	end
	-- Local X of the beam runs from a to b: yaw around Y, then pitch around Z.
	local yaw = math.deg(math.atan2(-dz, dx))
	local pitch = math.deg(math.asin(math.clamp(dy / len, -1, 1)))
	return self:add("box", len, h or t, t, (ax + bx) / 2, (ay + by) / 2, (az + bz) / 2, 0, yaw, pitch, o)
end

function Blueprint.light(
	self: Blueprint,
	x: number,
	y: number,
	z: number,
	color: string,
	range: number,
	brightness: number,
	tag: string?
)
	local top = self.frames[#self.frames]
	local dx, dy, dz = apply(top.r, x, y, z)
	table.insert(self.lights, {
		p = { top.o[1] + dx, top.o[2] + dy, top.o[3] + dz },
		color = color,
		range = range,
		brightness = brightness,
		tag = tag,
	})
end

return Blueprint
