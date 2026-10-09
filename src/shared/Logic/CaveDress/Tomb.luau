--!strict
-- The Tomb of Morvane (boss of Duskwood) dressing (S49), round the arena (the contract: nothing collidable within 50
-- studs of the fight's centre (0, -10), the entry sector free):
--   * a black floor with the mosaic (terrain), sarcophagi of knights and ladies under the wall at r ~80 in shallow
--     arcades, the south sector (entry, exit, respawn, the party's landing) free,
--   * baskets of ghost flame between the sarcophagi, a chandelier of chains and candles over the middle (no
--     collision),
--   * the queen's apse in the north: the broken empty sarcophagus of Morvane on its dais with the lid on the floor,
--     the statue of the young queen in her crown of thorns with her hands on the scythe, two banners,
--   * the unreachable gallery (+14): statues of mourners, the queen's torn banners, mist spilling over the edge. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Tomb = {}

type Build = Kit.Build
type Env = Kit.Env

local CX, CZ = 0, -10
local WRAITH = "#9FE0C9"
local STONE = { c = "#4E4B4E", m = "Slate" }
local PALE = { c = "#8A8680", m = "Slate" }
local ROYAL = { c = "#3A2A4A", m = "Fabric" }
local SILVER = { c = "#B8B0C8", m = "Metal" }

-- Whether a bearing (radians, atan2(dz, dx)) lies in the south sector (entry) or the north (apse).
local function blocked(a: number): boolean
	local deg = math.deg(a) % 360
	return (deg > 50 and deg < 130) or (deg > 250 and deg < 290)
end

local function sarcophagi(env: Env, out: { Build })
	local n = 0
	for k = 0, 9 do
		local a = k * 2 * math.pi / 10 + math.pi / 10
		if not blocked(a) then
			n += 1
			local x, z = CX + math.cos(a) * 82, CZ + math.sin(a) * 82
			local yaw = math.deg(math.atan2(-(CX - x), -(CZ - z)))
			local b = Kit.build(env, `TombSarcophagus_{n}`, "landmark", x, z, yaw + 180)
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			bp:box(4, 2.6, 8, 0, y + 1.3, 0, o(STONE, "shell", { q = false }))
			bp:rbox(
				4.2,
				0.8,
				8.2,
				if n % 3 == 0 then 1.6 else 0,
				y + 3,
				if n % 3 == 0 then 1 else 0,
				0,
				if n % 3 == 0 then 14 else 0,
				0,
				o(PALE, "detail", { col = false })
			)
			bp:add("ball", 1.6, 1.2, 4.6, 0, y + 3.6, 0, 0, 0, 0, o(PALE, "fine", { col = false }))
			-- the arcade behind it
			for _, s in { -1, 1 } do
				bp:box(1.2, 10, 1.2, s * 4, y + 5, 5, o(STONE, "shell", { q = false }))
			end
			bp:box(10, 1.6, 1.6, 0, y + 10.4, 5, o(STONE, "detail", { col = false }))
			table.insert(out, b)
		end
	end
	-- baskets of ghost flame between them (r 77)
	for k = 0, 9 do
		local a = k * 2 * math.pi / 10
		if not blocked(a) then
			local x, z = CX + math.cos(a) * 77, CZ + math.sin(a) * 77
			local b = Kit.build(env, `GhostBasket_{k}`, "lamp", x, z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:box(0.6, 3.4, 0.6, 0, y + 1.6, 0, o(Kit.iron, "shell", { q = false }))
			Kit.fire(b.bp, 0, y + 3.8, 0, 1.6, WRAITH, "detail")
			table.insert(out, b)
		end
	end
end

local function chandelier(env: Env, out: { Build })
	local b = Kit.build(env, "TombChandelier", "lamp", CX, CZ, 0)
	local y = Kit.gy(env, b, 0, 0) + 34
	local top = (Kit.ceil(env, CX, CZ) or 56) - b.at.y
	for k = 0, 3 do
		local a = k * math.pi / 2
		b.bp:beam(
			math.cos(a) * 2,
			top,
			math.sin(a) * 2,
			math.cos(a) * 7,
			y,
			math.sin(a) * 7,
			0.25,
			o(Kit.iron, "fine", { col = false })
		)
	end
	b.bp:add("cyl", 0.6, 15, 15, 0, y, 0, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
	for k = 0, 11 do
		local a = k * math.pi / 6
		Kit.candle(b.bp, math.cos(a) * 7, y + 0.3, math.sin(a) * 7, 0.8, "#FFC46E")
	end
	b.bp:light(0, y - 2, 0, "#FFC46E", 40, 1, "candle")
	Kit.lifeAt(env.ctx, b, "dustBeam", 0, y - 12, 0, 14)
	table.insert(out, b)
end

local function apse(env: Env, out: { Build })
	-- the broken sarcophagus on the dais (0, -128), its lid on the floor, the statue of the young queen behind
	local b = Kit.build(env, "MorvaneSarcophagus", "landmark", 0, -132, 180)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	bp:box(5, 3, 9, 0, y + 1.5, 0, o(STONE, "shell", { q = false }))
	bp:box(4, 0.4, 8, 0, y + 3, 0, o(Kit.dark, "fine", { col = false }))
	bp:rbox(5.4, 0.8, 9.4, 6, Kit.gy(env, b, 6, -2) + 0.6, -2, 0, 24, 12, o(PALE, "detail", { col = false }))
	bp:rbox(5.4, 0.8, 4, -5, Kit.gy(env, b, -5, 3) + 0.4, 3, 0, -30, 6, o(PALE, "fine", { col = false }))
	-- the statue (behind, north: local +Z at rot 180 = world -Z)
	local sy = Kit.gy(env, b, 0, 10)
	bp:box(5, 2, 5, 0, sy + 1, 10, o(STONE, "shell", { q = false }))
	bp:box(3.4, 10, 2.4, 0, sy + 7, 10, o(PALE, "detail", { col = false }))
	bp:add("ball", 2.4, 2.8, 2.4, 0, sy + 13.4, 10, 0, 0, 0, o(PALE, "detail", { col = false }))
	for k = -2, 2 do
		bp:rbox(0.3, 1.6, 0.3, k * 0.6, sy + 15.2, 10, 0, 0, k * 10, o(SILVER, "fine", { col = false }))
	end
	bp:rbox(0.4, 14, 0.4, 1.6, sy + 7, 8.6, 0, 0, -6, o(Kit.iron, "detail", { col = false }))
	bp:rbox(4, 0.6, 0.3, 3, sy + 13.6, 8.6, 0, 0, -6, o(Kit.iron, "fine", { col = false }))
	for _, s in { -1, 1 } do
		Kit.banner(bp, s * 9, Kit.gy(env, b, s * 9, 6), 6, 14, ROYAL)
	end
	table.insert(out, b)
end

local function gallery(env: Env, out: { Build })
	-- statues of mourners and the queen's banners on the unreachable gallery (+14, r 90..112)
	local n = 0
	for k = 0, 11 do
		local a = k * math.pi / 6 + math.pi / 12
		if not blocked(a) then
			local x, z = CX + math.cos(a) * 100, CZ + math.sin(a) * 100
			if env.T.floor(x, z) then
				n += 1
				local b = Kit.build(env, `GalleryMourner_{n}`, "landmark", x, z, math.deg(math.atan2(x - CX, z - CZ)))
				local y = Kit.gy(env, b, 0, 0)
				b.bp:box(2.6, 8, 2, 0, y + 4, 0, o(PALE, "detail", { col = false }))
				b.bp:add("ball", 2, 2.4, 2, 0, y + 9, 0, 0, 0, 0, o(PALE, "detail", { col = false }))
				b.bp:rbox(3, 3, 0.6, 0, y + 9, -0.6, -20, 0, 0, o(PALE, "fine", { col = false }))
				if n % 2 == 0 then
					b.bp:box(2.6, 9, 0.15, 3, y + 7, 0, o(ROYAL, "detail", { col = false, t = 0.1 }))
					b.bp:box(1.2, 1.2, 0.18, 3, y + 9, -0.05, o(SILVER, "fine", { col = false }))
				end
				Kit.lifeAt(env.ctx, b, "mist", 0, 0.5, 0, 6)
				table.insert(out, b)
			end
		end
	end
end

function Tomb.all(env: Env, out: { Build })
	sarcophagi(env, out)
	chandelier(env, out)
	apse(env, out)
	gallery(env, out)
	Kit.life(env.ctx, "drips", CX, 40, CZ, 50)
end

return Tomb
