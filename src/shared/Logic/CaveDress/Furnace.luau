--!strict
-- Azgor's Furnace (boss 70) dressing (S50), round the arena (the contract: nothing collidable within 75 studs of the
-- fight's centre (0, -10), nothing in the flat circle higher than 0.15 over the floor; Azgor's phase 3 disc of lava
-- (r 64, burning ring to 74) lies on the plain basalt):
--   * ten furnace columns on r ~78 outside the causeway (slits of embers, baskets of fire) and a low balustrade on
--     r ~81 along the moat,
--   * the Maw of the Furnace in the north wall: a huge arched furnace mouth glowing white-orange, lava spilling over
--     its threshold into the moat, two colossal bellows and chains at its sides, Azgor's horned sign over it,
--   * four nozzles shaped like horned heads (NE, NW, E, W) pouring lava into the moat, veins of magma running up the
--     walls towards the dome, embers falling from glowing cracks in the dome,
--   * the unreachable ledges east and west behind the moat: anvils, kneeling dwarves in chains, Azgor's banners. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Furnace = {}

type Build = Kit.Build
type Env = Kit.Env

local CX, CZ = 0, -10
local EMBER = "#FF7A1A"
local AZGOR = "#FF3A1A"
local STONE = { c = "#3A2A22", m = "Slate" }
local IRON = { c = "#3A3A40", m = "CorrodedMetal" }
local LEATHER = { c = "#4A2E1E", m = "Fabric" }
local BANNER = { c = "#5A1410", m = "Fabric" }
local DWARF = { c = "#5A524C", m = "Slate" }

local function at(r: number, deg: number): (number, number)
	local a = math.rad(deg)
	return CX + math.cos(a) * r, CZ + math.sin(a) * r
end

-- Bearing in the south sector (the causeway and the niche, |x| <= 34 south of the centre).
local function causeway(deg: number): boolean
	local x, z = at(78, deg)
	return z > CZ and math.abs(x) < 40
end

local function columns(env: Env, out: { Build })
	local n = 0
	for k = 0, 11 do
		local deg = k * 30 + 15
		if not causeway(deg) then
			n += 1
			local x, z = at(78, deg)
			local b = Kit.build(env, `FurnaceColumn_{n}`, "forge", x, z, deg + 90)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:box(5, 18, 5, 0, y + 9, 0, o(STONE, "shell", { q = false }))
			b.bp:box(5.6, 1.2, 5.6, 0, y + 18.4, 0, o(STONE, "detail", { col = false }))
			for t = 0, 2 do
				b.bp:box(0.5, 4, 0.2, -1.2 + t * 1.2, y + 7, -2.6, Kit.lavaOpts(EMBER, 0.1, "forge"))
			end
			Kit.fire(b.bp, 0, y + 19.4, 0, 1.6, EMBER, "detail")
			table.insert(out, b)
		end
	end
	-- the low balustrade along the moat (r 81), open at the causeway
	local rail = Kit.build(env, "MoatRail", "traces", CX, CZ + 81, 0)
	local ry = rail.at.y
	for k = 0, 47 do
		local deg = (k + 0.5) * 7.5
		local x, z = at(81, deg)
		if not causeway(deg) then
			local f = env.T.floor(x, z) or 0
			rail.bp:rbox(
				1,
				2,
				10,
				x - rail.at.x,
				f - ry + 1,
				z - rail.at.z,
				0,
				-deg,
				0,
				o(STONE, "detail", { col = false })
			)
		end
	end
	table.insert(out, rail)
end

local function maw(env: Env, out: { Build })
	-- the arched furnace mouth in the north wall over its pool (0, -138)
	local b = Kit.build(env, "FurnaceMaw", "landmark", 0, -126, 0)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	for _, s in { -1, 1 } do
		bp:box(4, 18, 6, s * 12, y + 9, -6, o(STONE, "shell", { q = false }))
		-- the bellows and their chains
		bp:rbox(6, 3, 10, s * 20, y + 4, -8, 0, s * 10, 0, o(LEATHER, "detail", { col = false }))
		bp:box(0.3, 20, 0.3, s * 20, y + 16, -8, o(IRON, "fine", { col = false }))
	end
	bp:box(28, 4, 6, 0, y + 19, -6, o(STONE, "detail", { col = false }))
	bp:box(20, 16, 0.4, 0, y + 8, -12, Kit.lavaOpts("#FFD8A0", 0.1, "glow"))
	bp:light(0, y + 8, -6, "#FFB070", 60, 2.4, "lava")
	-- Azgor's horned sign over it
	bp:box(1.4, 8, 0.3, 0, y + 27, -8.6, Kit.lavaOpts(AZGOR, 0, "glow"))
	for _, s in { -1, 1 } do
		bp:rbox(1.2, 7, 0.3, s * 4, y + 30, -8.6, 0, 0, s * -28, Kit.lavaOpts(AZGOR, 0, "glow"))
	end
	Kit.lifeAt(env.ctx, b, "embers", 0, 2, -8, 8)
	Kit.lifeAt(env.ctx, b, "smokeColumn", 0, 20, -10, 4)
	table.insert(out, b)
end

local function walls(env: Env, out: { Build })
	-- four horned heads pouring lava into the moat (on the rim behind it) and veins of magma up the walls
	for k, deg in { 315, 225, 0, 180 } do
		local x, z = at(100, deg)
		local b = Kit.build(env, `HornedNozzle_{k}`, "landmark", x, z, deg - 90)
		local y = Kit.gy(env, b, 0, 0)
		b.bp:box(6, 6, 4, 0, y + 10, 0, o(STONE, "detail", { col = false }))
		for _, s in { -1, 1 } do
			b.bp:rbox(1, 5, 1, s * 3.4, y + 14, 0, 0, 0, s * -30, o(STONE, "detail", { col = false }))
			b.bp:box(1, 0.6, 0.2, s * 1.4, y + 11, -2.1, Kit.lavaOpts(EMBER, 0, "glow"))
		end
		b.bp:rbox(2.4, 9, 0.4, 0, y + 4, -3, -20, 0, 0, Kit.lavaOpts(Kit.LAVA, 0.15, "lavafall"))
		b.bp:light(0, y + 6, -4, Kit.LAVA, 26, 1.4, "lava")
		-- the vein of magma up the wall above it
		for t = 0, 3 do
			b.bp:rbox(
				0.8,
				8,
				0.2,
				(t % 2) * 2 - 1,
				y + 18 + t * 7,
				1,
				0,
				0,
				(t % 2) * 30 - 15,
				Kit.lavaOpts(EMBER, 0.2, "ember")
			)
		end
		table.insert(out, b)
	end
	-- embers falling from the glowing cracks in the dome
	for k = 0, 5 do
		local x, z = at(50, k * 60 + 20)
		Kit.life(env.ctx, "embers", x, 40, z, 10)
	end
	Kit.life(env.ctx, "drips", CX, 44, CZ, 40)
end

local function ledges(env: Env, out: { Build })
	-- the unreachable ledges east (0 deg) and west (180 deg) behind the moat: anvils, chained dwarves, banners
	for k, deg in { 0, 180 } do
		local x, z = at(106, deg)
		local b = Kit.build(env, `FurnaceLedge_{k}`, "landmark", x, z, deg - 90)
		local y = Kit.gy(env, b, 0, 0)
		b.bp:box(1.6, 1.6, 1.6, -6, y + 0.8, 0, o(IRON, "detail", { col = false }))
		b.bp:box(3.4, 0.9, 1.4, -6, y + 2, 0, o(IRON, "detail", { col = false }))
		for t = -1, 1, 2 do
			local lx = t * 6 + 3
			b.bp:box(2.6, 4, 2, lx, y + 2, 0, o(DWARF, "detail", { col = false }))
			b.bp:box(1.8, 1.8, 1.8, lx, y + 5, 0, o(DWARF, "detail", { col = false }))
			b.bp:beam(lx, y + 3, 0, lx, y + 0.2, 3, 0.2, o(IRON, "fine", { col = false }))
		end
		b.bp:box(4, 12, 0.2, 10, y + 8, 2, o(BANNER, "detail", { col = false }))
		b.bp:box(1.2, 2.4, 0.1, 10, y + 9, 1.85, Kit.lavaOpts(AZGOR, 0, "glow"))
		table.insert(out, b)
	end
end

function Furnace.all(env: Env, out: { Build })
	columns(env, out)
	maw(env, out)
	walls(env, out)
	ledges(env, out)
end

return Furnace
