--!strict
-- W12: the pieces of a map's horizon ring (Data/Horizons): pure and deterministic (Logic/Rng seeded with the map id),
-- so every client builds the same land. A piece is a part centred at (x, y, z) around the map's centre:
--   "ellipsoid" (a block part with a sphere mesh: hills, the ground band), "block" (rock towers), "wedge" (a wedge part,
--   full height at its +Z face, turned `yaw` degrees: two of them back to back make a pine or a peak).

local Horizons = require("../Data/Horizons")
local Rng = require("./Rng")

export type Piece = {
	shape: "ellipsoid" | "block" | "wedge",
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	yaw: number, -- degrees around the vertical axis
	tilt: number, -- degrees around the piece's own X axis (rock towers lean)
	color: string,
}

local HorizonGen = {}

-- The point at compass degrees `deg`, `dist` studs from the centre (0 = north = -Z, 90 = east = +X).
function HorizonGen.at(deg: number, dist: number): (number, number)
	local a = math.rad(deg)
	return math.sin(a) * dist, -math.cos(a) * dist
end

-- The yaw (degrees) that turns a part's -Z face toward the centre from compass degrees `deg` (its look vector
-- (-sin yaw, -cos yaw) = the way back to the centre (-sin deg, cos deg)).
local function facing(deg: number): number
	return 180 - deg
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function mixHex(a: string, b: string, t: number): string
	local function ch(hex: string, i: number): number
		return tonumber(string.sub(hex, i, i + 1), 16) or 0
	end
	local out = "#"
	for _, i in { 2, 4, 6 } do
		out ..= string.format("%02X", math.floor(lerp(ch(a, i), ch(b, i), t) + 0.5))
	end
	return out
end

-- A "tent": two wedges back to back, apex on top, the ridge pointing at the centre so the triangle faces the viewer (a
-- pine or a peak from afar): `w` deep along the line of sight, `d` wide across it.
local function tent(
	out: { Piece },
	deg: number,
	dist: number,
	y: number,
	w: number,
	h: number,
	d: number,
	color: string
)
	local x, z = HorizonGen.at(deg, dist)
	local yaw = facing(deg) + 90
	local r = math.rad(yaw)
	-- local +Z of a part turned by yaw (around Y): (sin yaw, 0, cos yaw)
	local fx, fz = math.sin(r), math.cos(r)
	local q = d / 4
	table.insert(out, {
		shape = "wedge",
		x = x - fx * q,
		y = y + h / 2,
		z = z - fz * q,
		sx = w,
		sy = h,
		sz = d / 2,
		yaw = yaw,
		tilt = 0,
		color = color,
	})
	table.insert(out, {
		shape = "wedge",
		x = x + fx * q,
		y = y + h / 2,
		z = z + fz * q,
		sx = w,
		sy = h,
		sz = d / 2,
		yaw = yaw + 180,
		tilt = 0,
		color = color,
	})
end

local function arcPieces(out: { Piece }, def: Horizons.Horizon, arc: Horizons.Arc, rng: any, spread: number)
	local y0 = def.groundY
	local deg = arc.from
	while deg < arc.to do
		local t = rng:next()
		local dist = lerp(arc.dist[1], arc.dist[2], rng:next())
		local h = lerp(arc.height[1], arc.height[2], rng:next())
		local color = mixHex(arc.color, arc.color2, rng:next() * 0.6)
		if arc.kind == "hills" then
			local x, z = HorizonGen.at(deg, dist)
			table.insert(out, {
				shape = "ellipsoid",
				x = x,
				y = y0 + h * 0.15,
				z = z,
				sx = h * lerp(2.6, 3.6, t),
				sy = h * 1.3,
				sz = h * 1.8,
				yaw = facing(deg),
				tilt = 0,
				color = color,
			})
		elseif arc.kind == "pines" then
			-- two rows: the far one taller and darker
			tent(out, deg, dist, y0, h * 0.42, h, h * 0.42, color)
			if t > 0.35 then
				local d2 = dist + lerp(40, 90, rng:next())
				tent(out, deg + arc.step * 0.5, d2, y0, h * 0.45, h * 1.15, h * 0.45, arc.color)
			end
		elseif arc.kind == "rocks" then
			local x, z = HorizonGen.at(deg, dist)
			table.insert(out, {
				shape = "block",
				x = x,
				y = y0 + h / 2 - 6,
				z = z,
				sx = h * lerp(0.5, 0.9, t),
				sy = h,
				sz = h * lerp(0.4, 0.7, rng:next()),
				yaw = facing(deg) + lerp(-25, 25, rng:next()),
				tilt = lerp(-6, 6, rng:next()),
				color = color,
			})
			-- a scree slope at the foot
			tent(out, deg + arc.step * 0.4, dist - h * 0.2, y0 - 4, h * 1.1, h * 0.35, h * 0.6, arc.color2)
		else -- peaks: rock with a snow cap on the same apex
			local w = h * lerp(1.1, 1.5, t)
			tent(out, deg, dist, y0 - 10, w, h, w, arc.color)
			local cap = 0.42
			tent(out, deg, dist, y0 - 10 + h * (1 - cap), w * cap, h * cap, w * cap + 2, arc.color2)
		end
		deg += arc.step * spread * lerp(0.8, 1.2, rng:next())
	end
end

-- Every piece of the horizon of `mapId` (empty when it has none). `low` = the low graphics level: silhouettes twice as
-- far apart and a coarser ground band.
function HorizonGen.pieces(mapId: string, low: boolean?): { Piece }
	local def = Horizons.get(mapId)
	local out: { Piece } = {}
	if not def then
		return out
	end
	local rng = Rng.new(Rng.seedOf(`horizon:{mapId}`))
	-- the ground band: flat ellipsoids around the ring, coloured by the arc they stand in
	local count = if low then 18 else 32
	local mid = (def.ground[1] + def.ground[2]) / 2
	local width = def.ground[2] - def.ground[1]
	for i = 0, count - 1 do
		local deg = i * 360 / count
		local color = def.groundColor
		for _, arc in def.arcs do
			local d = (deg - arc.from) % 360
			if d < (arc.to - arc.from) then
				color = mixHex(def.groundColor, arc.color, 0.5)
			end
		end
		local x, z = HorizonGen.at(deg, mid)
		table.insert(out, {
			shape = "ellipsoid",
			x = x,
			y = def.groundY - 14,
			z = z,
			sx = 2 * math.pi * mid / count * 1.7,
			sy = 36,
			sz = width,
			yaw = facing(deg),
			tilt = 0,
			color = color,
		})
	end
	for _, arc in def.arcs do
		arcPieces(out, def, arc, rng, if low then 2 else 1)
	end
	return out
end

return HorizonGen
