--!strict
-- Monster telegraphs 2.0 (S117, DESIGN-16 §8): the geometry of a red area as a function of time, the same for the game
-- (CombatFxController) and AnimLab. Pure numbers (Lune).
--   progress  0..1 over the windup (linear; the windup clamped to 0.2..5 like the client always did)
--   front     where the filling front is: the area fills from its edge to its centre; a ring fills from its outer edge to
--             the safe centre (never into it), a cone from its arc to its tip, a line from both long sides to its axis
--   band      the filled band between the edge and the front as pieces in the area's frame (forward = -Z): circle and
--             ring `segments` trapezoids around the centre, cone segments / 2 slices like the old 9, line two blocks;
--             at p = 1 they cover the server's area (test: >= 99 %, at most 5 % outside it), at p = 0 nothing
--   rimPulse  transparency of the bright rim: it pulses faster and harder towards the blow
--   fillAlpha transparency of the band (Config.Telegraph fillFrom -> fillTo)
--   flashing  0..1 for flashSeconds from the end of the windup (the blow)
--   fade      0..1 over fadeSeconds after the flash
--   contains  the server's rule (CombatService insideArea), copied: the test checks both agree on edge points
-- A piece: `pos` { x, z } in the area's frame, `size` { w, d } (w = the width of its far edge, d = its depth), `yaw`
-- (radians, CFrame.Angles(0, yaw, 0): the piece's -Z points away from the centre), `taper` = near width / far width
-- (1 = a rectangle; the near edge lies at the piece's +Z). The polygons are drawn around their circles (the apothem is
-- the radius): they cover the whole circle and reach 0.6 % (24 sides) / 2.4 % (12 sides) past it.

local Telegraph = {}

export type Shape = "circle" | "cone" | "line" | "ring"
-- The event's numbers: r radius, ir safe centre of a ring, an cone angle in degrees, l / w line length and width.
export type Dims = { r: number?, ir: number?, an: number?, l: number?, w: number? }
export type Piece = { pos: { number }, size: { number }, yaw: number, taper: number }
export type Cfg = {
	pulseSlow: number,
	pulseFast: number,
	fillFrom: number,
	fillTo: number,
	flashSeconds: number,
	fadeSeconds: number,
}

Telegraph.WINDUP_MIN = 0.2
Telegraph.WINDUP_MAX = 5
-- The server's height window of an area (studs above or below its plane).
Telegraph.HEIGHT = 12

-- Defaults of CombatService insideArea for missing numbers.
local DEFAULTS = { circle = 8, cone = 10, ring = 20, inner = 5, angle = 90, length = 15, width = 5 }

function Telegraph.windup(windup: number?): number
	return math.clamp(windup or 1, Telegraph.WINDUP_MIN, Telegraph.WINDUP_MAX)
end

function Telegraph.progress(elapsed: number, windup: number): number
	return math.clamp(elapsed / Telegraph.windup(windup), 0, 1)
end

function Telegraph.radius(shape: Shape, dims: Dims): number
	if shape == "cone" then
		return dims.r or DEFAULTS.cone
	elseif shape == "ring" then
		return dims.r or DEFAULTS.ring
	end
	return dims.r or DEFAULTS.circle
end

function Telegraph.inner(dims: Dims): number
	return dims.ir or DEFAULTS.inner
end

function Telegraph.angle(dims: Dims): number
	return dims.an or DEFAULTS.angle
end

function Telegraph.length(dims: Dims): number
	return dims.l or DEFAULTS.length
end

function Telegraph.width(dims: Dims): number
	return dims.w or DEFAULTS.width
end

-- Where the filling front is at progress p (studs from the centre; a line: from its axis).
function Telegraph.front(shape: Shape, p: number, dims: Dims): number
	p = math.clamp(p, 0, 1)
	if shape == "ring" then
		local r = Telegraph.radius(shape, dims)
		local ir = math.min(Telegraph.inner(dims), r)
		return r - (r - ir) * p
	elseif shape == "line" then
		return Telegraph.width(dims) / 2 * (1 - p)
	end
	return Telegraph.radius(shape, dims) * (1 - p)
end

-- Writes the trapezoid into `into` (reused by the client every frame) or a new table.
local function trapezoid(into: Piece?, yaw: number, near: number, far: number, half: number): Piece
	-- near / far: apothems of the inner and outer edges; half: half the slice angle
	local depth = math.max(0, far - near)
	local mid = (near + far) / 2
	local farWidth = 2 * far * math.tan(half)
	local nearWidth = 2 * near * math.tan(half)
	local piece: Piece = into or { pos = { 0, 0 }, size = { 0, 0 }, yaw = 0, taper = 1 }
	piece.pos[1], piece.pos[2] = -math.sin(yaw) * mid, -math.cos(yaw) * mid
	piece.size[1], piece.size[2] = farWidth, depth
	piece.yaw = yaw
	piece.taper = if farWidth > 1e-9 then nearWidth / farWidth else 1
	return piece
end

local function rectangle(into: Piece?, x: number, z: number, w: number, d: number): Piece
	local piece: Piece = into or { pos = { 0, 0 }, size = { 0, 0 }, yaw = 0, taper = 1 }
	piece.pos[1], piece.pos[2] = x, z
	piece.size[1], piece.size[2] = w, d
	piece.yaw = 0
	piece.taper = 1
	return piece
end

-- The filled band at progress p: pieces between the edge and the front (see the header). `out`: a list from an earlier
-- call with the same shape and segments, refilled in place (no tables per frame).
function Telegraph.band(shape: Shape, p: number, dims: Dims, segments: number, out: { Piece }?): { Piece }
	local list: { Piece } = out or {}
	local front = Telegraph.front(shape, p, dims)
	if shape == "line" then
		local w, l = Telegraph.width(dims), Telegraph.length(dims)
		local filled = w / 2 - front
		list[1] = rectangle(list[1], -(w / 2 - filled / 2), -l / 2, filled, l)
		list[2] = rectangle(list[2], w / 2 - filled / 2, -l / 2, filled, l)
		return list
	end
	local r = Telegraph.radius(shape, dims)
	if shape == "cone" then
		local count = math.max(1, math.floor(segments / 2))
		local angle = math.rad(Telegraph.angle(dims))
		local slice = angle / count
		for i = 0, count - 1 do
			local yaw = -angle / 2 + slice * (i + 0.5)
			list[i + 1] = trapezoid(list[i + 1], yaw, front, r, slice / 2)
		end
		return list
	end
	local count = math.max(3, segments)
	local slice = 2 * math.pi / count
	for i = 0, count - 1 do
		list[i + 1] = trapezoid(list[i + 1], slice * i, front, r, slice / 2)
	end
	return list
end

-- True when the point (x, z) of the area's frame lies in the piece.
function Telegraph.inPiece(piece: Piece, x: number, z: number): boolean
	local dx, dz = x - piece.pos[1], z - piece.pos[2]
	local c, s = math.cos(piece.yaw), math.sin(piece.yaw)
	-- into the piece's frame (the inverse of CFrame.Angles(0, yaw, 0))
	local lx = dx * c - dz * s
	local lz = dx * s + dz * c
	local w, d = piece.size[1], piece.size[2]
	if d <= 0 or w <= 0 or math.abs(lz) > d / 2 then
		return false
	end
	-- the far edge (-Z) is w wide, the near edge (+Z) w * taper
	local share = (lz + d / 2) / d -- 0 at the far edge, 1 at the near edge
	local width = w * (1 + (piece.taper - 1) * share)
	return math.abs(lx) <= width / 2
end

-- Seconds per rim pulse at progress p (pulseSlow -> pulseFast).
function Telegraph.pulsePeriod(p: number, cfg: Cfg): number
	p = math.clamp(p, 0, 1)
	return cfg.pulseSlow + (cfg.pulseFast - cfg.pulseSlow) * p
end

-- Pulses counted since the start (the integral of 1 / period over the windup, so the beat speeds up smoothly).
local function pulses(elapsed: number, windup: number, cfg: Cfg): number
	local w = Telegraph.windup(windup)
	local t = math.clamp(elapsed, 0, w)
	local a, b = cfg.pulseSlow, cfg.pulseFast - cfg.pulseSlow
	local count
	if math.abs(b) < 1e-9 then
		count = t / a
	else
		count = w / b * math.log((a + b * t / w) / a)
	end
	if elapsed > w then
		count += (elapsed - w) / cfg.pulseFast
	end
	return count
end

-- Transparency of the bright rim `elapsed` s into the windup: a pulse whose depth grows with p (0.15 .. 0.45 deep).
function Telegraph.rimPulse(elapsed: number, windup: number, cfg: Cfg): number
	local p = Telegraph.progress(elapsed, windup)
	local wave = 0.5 + 0.5 * math.cos(2 * math.pi * pulses(elapsed, windup, cfg))
	local depth = 0.15 + 0.3 * p
	return math.clamp(0.1 + depth * (1 - wave), 0, 1)
end

function Telegraph.fillAlpha(p: number, cfg: Cfg): number
	p = math.clamp(p, 0, 1)
	return cfg.fillFrom + (cfg.fillTo - cfg.fillFrom) * p
end

-- 1 at the end of the windup (the blow), down to 0 over flashSeconds; 0 outside.
function Telegraph.flashing(elapsed: number, windup: number, cfg: Cfg): number
	local w = Telegraph.windup(windup)
	if elapsed < w or elapsed > w + cfg.flashSeconds then
		return 0
	end
	return math.max(0, 1 - (elapsed - w) / cfg.flashSeconds)
end

-- 0 until the flash ends, then 1 over fadeSeconds (1 = gone).
function Telegraph.fade(elapsed: number, windup: number, cfg: Cfg): number
	local from = Telegraph.windup(windup) + cfg.flashSeconds
	if elapsed <= from then
		return 0
	end
	return math.clamp((elapsed - from) / cfg.fadeSeconds, 0, 1)
end

-- Seconds from the start to the end of the fade.
function Telegraph.duration(windup: number, cfg: Cfg): number
	return Telegraph.windup(windup) + cfg.flashSeconds + cfg.fadeSeconds
end

-- The server's rule (CombatService insideArea, S117 copy): `x, y, z` in the area's frame (forward = -Z).
function Telegraph.contains(shape: Shape, dims: Dims, x: number, z: number, y: number?): boolean
	if math.abs(y or 0) > Telegraph.HEIGHT then
		return false
	end
	local flat = math.sqrt(x * x + z * z)
	if shape == "circle" then
		return flat <= (dims.r or DEFAULTS.circle)
	elseif shape == "cone" then
		local radius = dims.r or DEFAULTS.cone
		if flat > radius then
			return false
		end
		if flat < 1 then
			return true
		end
		local angle = math.deg(math.acos(math.clamp(-z / flat, -1, 1)))
		return angle <= (dims.an or DEFAULTS.angle) / 2
	elseif shape == "line" then
		local length, width = dims.l or DEFAULTS.length, dims.w or DEFAULTS.width
		return z <= 0 and z >= -length and math.abs(x) <= width / 2
	elseif shape == "ring" then
		return flat <= (dims.r or DEFAULTS.ring) and flat > (dims.ir or DEFAULTS.inner)
	end
	return false
end

return Telegraph
