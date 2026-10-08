--!strict
-- Scorpion Dunes (55–63, more gold) (S46): a sea of dunes on the sand plateau.
--   * the Buried King (the landmark): head and shoulder of a colossal king's statue rising from a dune, one hand
--     raised over the sand; gold glints round it, at night a cold turquoise glow like the mummies' eyes,
--   * sarcophagi laid bare by the wind, some open and empty (the mummies walked out), gold masks and coins,
--   * broken columns sticking out of the sand, scorpion burrows with thrown-out sand, shed carapaces. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Dunes = {}

type Build = Kit.Build

local function buriedKing(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "buriedKing", "landmark", 40)
	local bp = b.bp
	local stone = Props.paleStone
	local K = 1.7
	local y = Kit.range(ctx, b.at.x, b.at.z, 40, 40, 0) - b.at.y
	-- the head, tilted, buried to the chin, with its crown
	bp:push(0, y - 2, 0, -8, 0, 12)
	bp:box(12 * K, 14 * K, 11 * K, 0, 7 * K, 0, o(stone, "shell", { q = false }))
	bp:box(13 * K, 2 * K, 3 * K, 0, 10.4 * K, -5.6 * K, o(stone, "detail", { col = false }))
	bp:box(3 * K, 4 * K, 2 * K, 0, 7 * K, -6.4 * K, o(stone, "detail", { col = false })) -- the nose
	bp:box(6 * K, 1 * K, 1 * K, 0, 4 * K, -5.8 * K, o(Props.darkSand, "detail", { col = false })) -- the mouth
	for _, side in { -1, 1 } do
		bp:box(2.6 * K, 1.4 * K, 0.6, side * 3.2 * K, 9 * K, -5.6 * K - 0.3, {
			c = Props.TURQUOISE,
			m = "Neon",
			lod = "shell",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
		bp:box(1.6 * K, 5 * K, 9 * K, side * 6.6 * K, 7 * K, 0.4 * K, o(stone, "detail", { col = false })) -- the headdress
	end
	for k = -2, 2 do
		bp:add(
			"wedge",
			2 * K,
			4 * K,
			2 * K,
			k * 2.6 * K,
			15.6 * K,
			0,
			0,
			0,
			0,
			o(Props.gold, "detail", { col = false })
		)
	end
	bp:box(13 * K, 1.4 * K, 12 * K, 0, 14.2 * K, 0, o(Props.gold, "shell", { q = false }))
	bp:pop()
	bp:light(0, y + 14, -18, Props.TURQUOISE, 30, 1, "glow")
	-- the shoulder and the raised forearm with an open hand
	bp:rbox(14 * K, 8 * K, 10 * K, 15 * K, y + 1, 4 * K, 0, 10, -14, o(stone, "shell", { q = false }))
	bp:rbox(4.4 * K, 16 * K, 4.4 * K, 21 * K, y + 9 * K, -2 * K, 10, 0, -10, o(stone, "shell", { q = false }))
	bp:box(6 * K, 6 * K, 2.4 * K, 22.4 * K, y + 18.6 * K, -3.4 * K, o(stone, "detail", { col = false }))
	for k = 0, 3 do
		bp:box(1.2 * K, 3.4 * K, 1.2 * K, (20.2 + k * 1.5) * K, y + 23.2 * K, -3.4 * K, o(stone, "fine"))
	end
	Props.coins(bp, -8, Kit.gy(ctx, b, -8, -22), -22, 14)
	Props.coins(bp, 10, Kit.gy(ctx, b, 10, -20), -20, 10)
	bp:add("ball", 1.2, 1.4, 0.5, -3, Kit.gy(ctx, b, -3, -24) + 0.3, -24, 80, 20, 0, o(Props.gold, "fine"))
	Kit.lifeAt(ctx, b, "wisp", 0, y + 8, -24, 16)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 30, 22, b.at.rot)
	table.insert(out, b)
end

local function sarcophagi(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "sarcophagi", "tomb", 14)
	local bp = b.bp
	local list: { { any } } = { { -6, 0, 10, true }, { 2, -3, -6, false }, { 8, 5, 30, true }, { -2, 8, 80, true } }
	for k, p in list do
		local lx, lz = p[1] :: number, p[2] :: number
		Props.sarcophagus(bp, lx, Kit.gy(ctx, b, lx, lz) - 0.6, lz, p[3] :: number, p[4] :: boolean)
		if p[4] then
			Props.coins(bp, lx + 2, Kit.gy(ctx, b, lx + 2, lz - 4), lz - 4, 5)
		end
		if k == 2 then
			bp:add("ball", 1.2, 1.4, 0.5, lx - 3, Kit.gy(ctx, b, lx - 3, lz) + 0.3, lz, 80, 0, 0, o(Props.gold, "fine"))
		end
	end
	for k = 1, 3 do
		bp:rbox(
			0.6,
			0.06,
			3.2,
			-10 + k * 3,
			Kit.gy(ctx, b, -10 + k * 3, -8) + 0.05,
			-8,
			0,
			k * 30,
			0,
			o(Props.linen, "fine")
		)
	end
	table.insert(out, b)
end

-- Broken columns and burrows scattered in the dune valleys.
local function scatter(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local spots: { { any } } = {
		{ 420, 460, "column" },
		{ 480, 640, "column" },
		{ 700, 420, "column" },
		{ 660, 700, "column" },
		{ 400, 720, "column" },
		{ 520, 400, "burrow" },
		{ 620, 640, "burrow" },
		{ 740, 560, "burrow" },
		{ 460, 560, "burrow" },
		{ 560, 740, "burrow" },
		{ 700, 330, "burrow" },
	}
	for i, p in spots do
		local x, z = p[1] :: number, p[2] :: number
		if not Env.isClear(env, x, z, 2) or env.T.roadDistance(x, z) < 6 then
			continue
		end
		Env.clear(env, x, z, 8)
		local b = Kit.build(ctx, `Dunes_{p[3]}_{i}`, if p[3] == "column" then "ruins" else "traces", x, z, i * 37)
		if p[3] == "column" then
			for k = 0, 2 do
				Props.column(
					b.bp,
					-4 + k * 4.6,
					Kit.gy(ctx, b, -4 + k * 4.6, 0) - 1.2,
					0,
					10 + k * 2,
					Props.sandstone,
					k ~= 1
				)
			end
		else
			Props.burrow(b.bp, 0, 0, 0)
			Props.burrow(b.bp, 7, Kit.gy(ctx, b, 7, 5), 5)
		end
		table.insert(out, b)
	end
end

function Dunes.all(env: Env.Env, out: { Build })
	buriedKing(env, out)
	sarcophagi(env, out)
	scatter(env, out)
	-- crest lines for the map: where the dune profile peaks (Logic/RegionTerrain dunesAt, wind from the west)
	local shape = env.T.shape
	local d = assert(shape.dunes, "dunes")[1]
	local crest = 1 - d.lee
	local first = math.ceil(d.rect[1] / d.wave - crest)
	for k = first, math.floor(d.rect[3] / d.wave) do
		local pts = {}
		for z = d.rect[2] + 20, d.rect[4] - 10, 30 do
			local x = (k + crest) * d.wave
			for _ = 1, 4 do
				x = (k + crest) * d.wave - d.wander * (TerrainLayers.fbm(x, z, 170, shape.seed + 50, 2) - 0.5) * 2
			end
			if x > d.rect[1] + 10 and x < d.rect[3] - 10 then
				table.insert(pts, x)
				table.insert(pts, z)
			end
		end
		if #pts >= 4 then
			Kit.line(env.ctx, "dune", pts, 3)
		end
	end
end

return Dunes
