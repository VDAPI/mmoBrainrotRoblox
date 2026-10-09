--!strict
-- Crypt of the Forgotten (38-45, boss cave) dressing (S49): the crypt of a forgotten royal house.
--   1 the Gate of the Forgotten: a carved portal round the exit, niches of skulls, two hooded stone mourners with
--     cold lamps at the start of the procession axis (z = 0),
--   2 the Hall of Columns: torches on the pillars (every other one out), sarcophagi in the side aisles,
--   3 the Family Crypt (specters): walls of niches with shrouds and skulls, a row of sarcophagi with their lids
--     pushed aside, chiselled-off arms, withered wreaths,
--   4 the Barracks of the Dead (skeletons): stone biers in rows, racks of rusty swords and round shields, helmets on
--     pegs, the faded banner of the old guard, a shut iron-bound door,
--   5 the Soul Well ("wow"): the well's curb with an iron grate in the apse, cold light and a slow spiral of mist and
--     wisps rising into the shaft, chains from the vault,
--   6 the Ossuary ("wow"): limestone walls of niches full of skulls and bones in patterns, skull pyramids in the four
--     diagonal corners, a chandelier of bones over the middle,
--   7 the Gallery of Specters: torn banners hanging from the vault, statues of nobles with chiselled faces, knee-deep
--     mist,
--   8 the Necromancer's Sanctum (Elite II): the summoning circle (mosaic, green runes), four baskets of green fire by
--     the walls, lecterns with open books, shelves of jars and skulls, a table with a shrouded body, cages of bones,
--   9 the Antechamber of the Seal: the seal of Morvane before the gate (a breathing glow), two kneeling knights of the
--     queen by the gate, a lintel of skulls and a crown, violet banners, a path of candles, ghost-flame baskets. Pure.

local Barrow = require("./Barrow")
local Kit = require("./Kit")

local o = Kit.o

local Crypt = {}

type Build = Kit.Build
type Env = Kit.Env

local COLD = "#9FB6FF"
local GHOST = "#CFF0FF"
local GREEN = "#5FA06B"
local VIOLET = "#7A3FA0"
local WRAITH = "#9FE0C9"
local STONE = { c = "#5E5A58", m = "Slate" }
local PALE = { c = "#B9AE96", m = "Limestone" }
local SHROUD = { c = "#C8BEA8", m = "Fabric" }
local ROYAL = { c = "#3A2A4A", m = "Fabric" }
local SILVER = { c = "#B8B0C8", m = "Metal" }

-- A hooded statue (mourner, kneeling knight), facing -Z of the frame.
local function statue(bp: Kit.BP, x: number, y: number, z: number, s: number, yaw: number, kneeling: boolean)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(4 * s, 1.4 * s, 4 * s, 0, 0.7 * s, 0, o(STONE, "shell", { q = false }))
	local body = if kneeling then 5 else 8
	bp:box(2.6 * s, body * s, 2 * s, 0, (1.4 + body / 2) * s, 0, o(STONE, "detail", { col = false }))
	bp:add("ball", 2 * s, 2.4 * s, 2 * s, 0, (1.4 + body + 1) * s, 0, 0, 0, 0, o(STONE, "detail", { col = false }))
	bp:rbox(3 * s, 3 * s, 0.6 * s, 0, (1.4 + body + 0.6) * s, -0.6 * s, -20, 0, 0, o(STONE, "detail", { col = false })) -- hood
	if kneeling then
		bp:rbox(0.4 * s, 7 * s, 0.4 * s, 0, 4 * s, -1.6 * s, 0, 0, 0, o(Kit.iron, "detail", { col = false })) -- sword
		bp:box(2 * s, 0.4 * s, 0.4 * s, 0, 6.6 * s, -1.6 * s, o(Kit.iron, "fine", { col = false }))
	end
	bp:pop()
end

local function torchAt(env: Env, out: { Build }, name: string, x: number, z: number, color: string)
	local b = Kit.build(env, name, "lamp", x, z, 0)
	Kit.torch(b.bp, 0, Kit.gy(env, b, 0, 0), 0, color)
	table.insert(out, b)
end

local function gate(env: Env, out: { Build })
	local b = Kit.build(env, "CryptGate", "landmark", -268, 0, 90)
	local bp = b.bp
	for _, s in { -1, 1 } do
		bp:box(3, 20, 3, s * 9, 9, 3, o(STONE, "shell", { q = false }))
		for t = 0, 2 do
			Kit.skull(bp, s * 13, 4 + t * 4, 4, 1.1, 0)
		end
	end
	bp:box(22, 3, 4, 0, 20, 3, o(STONE, "detail", { col = false }))
	table.insert(out, b)
	-- the hooded mourners with cold lamps at the start of the axis
	local m = Kit.build(env, "CryptMourners", "landmark", -228, 0, 90)
	for _, s in { -1, 1 } do
		statue(m.bp, s * 14, Kit.gy(env, m, s * 14, 0), 0, 1.2, 0, false)
		Kit.lantern(m.bp, s * 14 + 2, Kit.gy(env, m, s * 14, 0), -2, COLD, 7, "detail")
	end
	table.insert(out, m)
end

local function columns(env: Env, out: { Build })
	local r = env.T.rooms[2]
	-- torches on the pillars (every other one), sarcophagi in the side aisles
	local n = 0
	for _, x in { -164, -146, -128, -92, -74, -56 } do
		for _, z in { -52, 52 } do
			n += 1
			if n % 2 == 0 then
				local b = Kit.build(env, `PillarTorch_{n}`, "lamp", x, z + (if z < 0 then 4 else -4), 0)
				Kit.fire(b.bp, 0, Kit.gy(env, b, 0, 0) + 9, 0, 0.8, COLD, "detail")
				b.bp:box(0.4, 1.6, 0.4, 0, Kit.gy(env, b, 0, 0) + 8, 0, o(Kit.iron, "fine", { col = false }))
				table.insert(out, b)
			end
		end
	end
	for k, p in { { -150, -60 }, { -80, -60 }, { -150, 60 }, { -80, 60 } } do
		if Kit.free(env, p[1], p[2], 3) then
			local b = Kit.build(env, `AisleSarcophagus_{k}`, "traces", p[1], p[2], 0)
			b.bp:box(8, 2.6, 3.4, 0, Kit.gy(env, b, 0, 0) + 1.3, 0, o(STONE, "shell", { q = false }))
			b.bp:box(8.4, 0.6, 3.8, 0, Kit.gy(env, b, 0, 0) + 2.9, 0, o(PALE, "detail", { col = false }))
			Kit.clear(env, p[1], p[2], 5)
			table.insert(out, b)
		end
	end
	Kit.life(env.ctx, "mist", r.x, 0.5, r.z, 40)
end

local function familycrypt(env: Env, out: { Build })
	local r = env.T.rooms[3]
	Barrow.niches(env, out, 3, true, "FamilyNiches")
	for k = -1, 1 do
		local x, z = r.x + k * 14, r.z - 34
		if Kit.free(env, x, z, 3) then
			local b = Kit.build(env, `RoyalSarcophagus_{k + 2}`, "landmark", x, z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:box(4, 2.6, 8, 0, y + 1.3, 0, o(STONE, "shell", { q = false }))
			b.bp:rbox(4.2, 0.6, 8.2, 2.2, y + 2.6, 1.4, 0, 18, 10, o(PALE, "detail", { col = false }))
			b.bp:add(
				"cyl",
				0.5,
				3,
				3,
				-1,
				y + 0.3,
				5,
				0,
				0,
				90,
				o({ c = "#5A4A2A", m = "Grass" }, "fine", { col = false })
			)
			Kit.clear(env, x, z, 5)
			table.insert(out, b)
		end
	end
	torchAt(env, out, "FamilyCandles", r.x + 30, r.z + 10, GHOST)
end

local function barracks(env: Env, out: { Build })
	local r = env.T.rooms[4]
	for k, a in { 20, 100, 160, 240, 320 } do
		local x, z = Kit.spot(env, r, math.rad(a), 5, 3)
		if x and z then
			local b = Kit.build(env, `DeadBier_{k}`, "traces", x, z, a + 90)
			local y = Kit.gy(env, b, 0, 0)
			if k % 2 == 1 then
				b.bp:box(3, 1.6, 7, 0, y + 0.8, 0, o(STONE, "shell", { q = false }))
				Kit.bones(b.bp, 0, y + 1.6, 0, 4)
			else
				b.bp:box(5, 0.4, 0.4, 0, y + 4, 0, o(Kit.wood, "shell", { q = false }))
				for m = -2, 2 do
					b.bp:rbox(
						0.2,
						4,
						0.5,
						m,
						y + 2.2,
						0.3,
						0,
						0,
						4,
						o({ c = "#6A4A3A", m = "CorrodedMetal" }, "detail", { col = false })
					)
				end
				for m = -1, 1 do
					b.bp:add(
						"cyl",
						0.3,
						2.4,
						2.4,
						m * 2.6,
						y + 1.3,
						-0.6,
						80,
						0,
						0,
						o({ c = "#5A4A3A", m = "CorrodedMetal" }, "detail", { col = false })
					)
				end
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, b)
		end
	end
	local bx, bz = Kit.spot(env, r, math.rad(270), 2, 1, false)
	if bx and bz then
		local b = Kit.build(env, "GuardBanner", "traces", bx, bz, 0)
		Kit.banner(b.bp, 0, Kit.gy(env, b, 0, 0), 0, 12, { c = "#4A4A5A", m = "Fabric" })
		table.insert(out, b)
	end
	torchAt(env, out, "BarracksTorch", r.x - 30, r.z, COLD)
end

local function soulwell(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "SoulWell", "landmark", 40, -228, 0)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	for k = 0, 11 do
		local a = k * math.pi / 6
		bp:rbox(
			2.4,
			2.6,
			1.2,
			math.cos(a) * 6.4,
			y + 1.3,
			math.sin(a) * 6.4,
			0,
			math.deg(-a) + 90,
			0,
			o(STONE, "shell", { q = false })
		)
	end
	for k = -2, 2 do
		bp:box(0.4, 0.4, 12, k * 2.2, y + 2.4, 0, o(Kit.iron, "detail", { col = false }))
		bp:box(12, 0.4, 0.4, 0, y + 2.4, k * 2.2, o(Kit.iron, "detail", { col = false }))
	end
	bp:add(
		"cyl",
		0.2,
		11,
		11,
		0,
		y + 0.4,
		0,
		0,
		0,
		90,
		{ c = GHOST, m = "Neon", lod = "detail", col = false, t = 0.3, tag = "glow", jitter = 0, fxColor = GHOST }
	)
	bp:light(0, y + 4, 0, GHOST, 30, 1.6, "crystal")
	Kit.lifeAt(env.ctx, b, "mist", 0, 1, 0, 6)
	Kit.lifeAt(env.ctx, b, "wisp", 0, 8, 0, 6)
	Kit.clear(env, 40, -228, 9)
	table.insert(out, b)
	-- chains hanging from the vault over the room
	local c = Kit.build(env, "WellChains", "traces", r.x, r.z, 0)
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.6
		local lx, lz = math.cos(a) * 24, math.sin(a) * 24
		local top = (Kit.ceil(env, r.x + lx, r.z + lz) or 24) - c.at.y
		local fy = Kit.gy(env, c, lx, lz)
		if top - fy > 16 then
			c.bp:box(0.3, top - fy - 14, 0.3, lx, (top + fy + 14) / 2, lz, o(Kit.iron, "fine", { col = false }))
		end
	end
	table.insert(out, c)
end

local function ossuary(env: Env, out: { Build })
	local r = env.T.rooms[6]
	-- walls of niches full of skulls (the shelves of the barrow, limestone)
	Barrow.niches(env, out, 6, false, "OssuaryNiches")
	-- skull pyramids in the four diagonal corners
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local x, z = Kit.spot(env, r, a, 6, 3)
		if x and z then
			local b = Kit.build(env, `SkullPyramid_{k + 1}`, "landmark", x, z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:add("ball", 5, 4, 5, 0, y + 1.2, 0, 0, 0, 0, o(PALE, "shell", { q = false }))
			for t = 0, 3 do
				for m = 0, 5 - t do
					local aa = m * 2 * math.pi / (6 - t)
					Kit.skull(
						b.bp,
						math.cos(aa) * (2.4 - t * 0.5),
						y + t * 1.1,
						math.sin(aa) * (2.4 - t * 0.5),
						1,
						math.deg(-aa)
					)
				end
			end
			Kit.clear(env, x, z, 5)
			table.insert(out, b)
		end
	end
	-- the chandelier of bones over the middle (no collision)
	local c = Kit.build(env, "BoneChandelier", "lamp", r.x, r.z, 0)
	local top = (Kit.ceil(env, r.x, r.z) or 30) - c.at.y
	local cy = math.max(16, top - 10)
	c.bp:box(0.3, top - cy, 0.3, 0, (top + cy) / 2, 0, o(Kit.iron, "fine", { col = false }))
	for k = 0, 9 do
		local a = k * math.pi / 5
		c.bp:beam(0, cy, 0, math.cos(a) * 5, cy - 1.4, math.sin(a) * 5, 0.3, o(Kit.bone, "detail", { col = false }))
		Kit.skull(c.bp, math.cos(a) * 5, cy - 2.2, math.sin(a) * 5, 0.9, math.deg(-a))
		Kit.candle(c.bp, math.cos(a) * 5, cy - 1.2, math.sin(a) * 5, 0.6, "#FFC46E")
	end
	c.bp:light(0, cy - 3, 0, "#FFC46E", 26, 0.9, "candle")
	table.insert(out, c)
end

local function gallery(env: Env, out: { Build })
	local r = env.T.rooms[7]
	local b = Kit.build(env, "SpecterGallery", "traces", r.x, r.z, 0)
	for k = -3, 3 do
		local lx = k * 13
		for _, s in { -1, 1 } do
			local lz = s * 26
			local top = (Kit.ceil(env, r.x + lx, r.z + lz) or 24) - b.at.y
			b.bp:box(2.4, 7, 0.15, lx, top - 4, lz, o(ROYAL, "detail", { col = false, t = 0.15 }))
		end
	end
	table.insert(out, b)
	for k, a in { 0, 180 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3)
		if x and z then
			local s = Kit.build(env, `NobleStatue_{k}`, "landmark", x, z, a + 90)
			statue(s.bp, 0, Kit.gy(env, s, 0, 0), 0, 1.3, 0, false)
			Kit.clear(env, x, z, 4)
			table.insert(out, s)
		end
	end
	Kit.life(env.ctx, "mist", r.x, 0.5, r.z, 44)
	Kit.life(env.ctx, "wisp", r.x, 4, r.z, 30)
end

local function sanctum(env: Env, out: { Build })
	local r = env.T.rooms[8]
	-- four baskets of green fire by the walls, lecterns, shelves, a table with a shrouded body, cages
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local x, z = Kit.spot(env, r, a, 4, 2)
		if x and z then
			local b = Kit.build(env, `GreenBasket_{k + 1}`, "lamp", x, z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:box(0.6, 3, 0.6, 0, y + 1.4, 0, o(Kit.iron, "shell", { q = false }))
			Kit.fire(b.bp, 0, y + 3.4, 0, 1.4, GREEN, "detail")
			Kit.clear(env, x, z, 3)
			table.insert(out, b)
		end
	end
	for k, a in { 30, 150, 260 } do
		local x, z = Kit.spot(env, r, math.rad(a), 4, 2.5)
		if x and z then
			local b = Kit.build(env, `NecroProp_{k}`, "traces", x, z, a + 90)
			local y = Kit.gy(env, b, 0, 0)
			if k == 1 then
				b.bp:box(6, 2.6, 3, 0, y + 1.3, 0, o(Kit.wood, "shell", { q = false }))
				b.bp:box(5, 0.8, 2, 0, y + 3, 0, o(SHROUD, "detail", { col = false }))
			elseif k == 2 then
				b.bp:rbox(1.4, 3.4, 1, 0, y + 1.7, 0, 0, 0, 0, o(Kit.wood, "shell", { q = false }))
				b.bp:rbox(
					2.2,
					0.2,
					1.6,
					0,
					y + 3.6,
					0,
					20,
					0,
					0,
					o({ c = "#D8C9A0", m = "Fabric" }, "fine", { col = false })
				)
				Kit.candle(b.bp, 1, y + 3.4, 0, 0.6, GREEN)
			else
				b.bp:box(3, 4, 3, 0, y + 2, 0, o(Kit.iron, "detail", { col = false, t = 0.5 }))
				Kit.bones(b.bp, 0, y + 0.2, 0, 4)
			end
			Kit.clear(env, x, z, 3.5)
			table.insert(out, b)
		end
	end
	local runes = Kit.build(env, "SummoningRunes", "glow", r.x, r.z, 0)
	for k = 0, 4 do
		local a = k * 2 * math.pi / 5
		runes.bp:box(
			1.4,
			0.06,
			1.4,
			math.cos(a) * 13,
			Kit.gy(env, runes, math.cos(a) * 13, math.sin(a) * 13) + 0.05,
			math.sin(a) * 13,
			{
				c = GREEN,
				m = "Neon",
				lod = "detail",
				col = false,
				tag = "glow",
				jitter = 0,
				fxColor = GREEN,
			}
		)
	end
	table.insert(out, runes)
end

local function antechamber(env: Env, out: { Build })
	-- the seal of Morvane (262, 0): a breathing glow over the mosaic
	local b = Kit.build(env, "MorvaneSeal", "landmark", 262, 0, 0)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	bp:add(
		"cyl",
		0.06,
		26,
		26,
		0,
		y + 0.05,
		0,
		0,
		0,
		90,
		{ c = VIOLET, m = "Neon", lod = "detail", col = false, t = 0.55, tag = "glow", jitter = 0, fxColor = VIOLET }
	)
	bp:add("cyl", 0.07, 10, 10, 0, y + 0.06, 0, 0, 0, 90, o(SILVER, "fine", { col = false, t = 0.3 }))
	bp:light(0, y + 3, 0, VIOLET, 24, 1, "crystal")
	table.insert(out, b)
	-- two kneeling knights by the gate (282, 0), a lintel of skulls, violet banners, a path of candles, ghost flames
	local k = Kit.build(env, "SealKnights", "landmark", 272, 0, 90)
	for _, s in { -1, 1 } do
		statue(k.bp, s * 14, Kit.gy(env, k, s * 14, 0), 2, 1.3, 0, true)
		Kit.banner(k.bp, s * 20, Kit.gy(env, k, s * 20, 4), 4, 12, ROYAL)
		k.bp:box(0.6, 3, 0.6, s * 9, Kit.gy(env, k, s * 9, -8) + 1.4, -8, o(Kit.iron, "detail", { col = false }))
		Kit.fire(k.bp, s * 9, Kit.gy(env, k, s * 9, -8) + 3.3, -8, 1.2, WRAITH, "detail")
	end
	for t = -3, 3 do
		Kit.skull(k.bp, t * 1.6, 18, 6, 1.2, 0)
	end
	table.insert(out, k)
	local c = Kit.build(env, "CandlePath", "traces", 238, 0, 0)
	for t = 0, 5 do
		for _, s in { -1, 1 } do
			Kit.candles(c.bp, -18 + t * 7, Kit.gy(env, c, -18 + t * 7, s * 8), s * 8, 2, "#FFC46E")
		end
	end
	table.insert(out, c)
	Kit.life(env.ctx, "mist", 270, 0.5, 0, 12)
end

function Crypt.all(env: Env, out: { Build })
	gate(env, out)
	columns(env, out)
	familycrypt(env, out)
	barracks(env, out)
	soulwell(env, out)
	ossuary(env, out)
	gallery(env, out)
	sanctum(env, out)
	antechamber(env, out)
	Kit.life(env.ctx, "drips", -110, 20, 0, 40)
end

return Crypt
