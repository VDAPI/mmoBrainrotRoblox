--!strict
-- Ruins of the Dragon Temple (85–95, gold) (S47): terraces climbing east to the glacier.
--   * the Dragon Stairs (the landmark): broad procession steps where the road climbs each terrace, dragon statues
--     either side, broken steps, retaining walls along the terraces' edges,
--   * the sanctuary: roofless, a colonnade half in ice, a colossal dragon statue with outspread wings half sunk in
--     ice (eyes glow at night),
--   * dragonspawn: cult banners in navy and gold, shed scales, spear racks, baskets of blue fire; frozen knights:
--     frozen armour of the fallen, patrol tracks on the stairs; gold: offering altars with coins and gold vessels
--     locked in blocks of ice. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Temple = {}

type Build = Kit.Build

-- x of the terraces' edges the road climbs (Data/Terrain/frostpeak lifts) and their tops
local EDGES = { { 500, 30, 36 }, { 580, 36, 42 }, { 650, 42, 48 } }

local function stairs(env: Env.Env, out: { Build })
	for i, e in EDGES do
		local x = e[1]
		local name = if i == 1 then "dragonStairs" else `DragonStairs_{i}`
		Env.clear(env, x, 0, 26)
		local b = Kit.buildAt(name, "landmark", x, e[2], 0, 90)
		local bp = b.bp
		-- steps across the road (local X across, local -Z = west: the stairs climb towards +Z = east)
		local n = 8
		for k = 0, n - 1 do
			local lz = -12 + k * 3
			local top = e[2] + (e[3] - e[2]) * (k + 1) / n
			local broken = (k == 2 and i == 2) or (k == 5 and i == 1)
			bp:box(
				if broken then 11 else 18,
				0.8,
				3.2,
				if broken then 3 else 0,
				top - e[2] - 0.4,
				lz,
				o(Props.paleStone, "detail", { col = false })
			)
		end
		-- dragon statues either side of the top step, banners, baskets of blue fire
		for _, side in { -1, 1 } do
			Props.dragonStatue(bp, side * 13, e[3] - e[2], 10, 0.55, 0, false)
			Props.brazier(bp, side * 11, e[3] - e[2], -12, Props.ICEFIRE)
			if i ~= 2 then
				Props.banner(bp, side * 15, e[3] - e[2], 2, 10, Props.cultBlue, Props.gold, false)
			end
		end
		table.insert(out, b)
	end
	-- retaining walls along the terraces' edges (off the road)
	for i, e in EDGES do
		for _, side in { -1, 1 } do
			local zFrom, zTo = 20, 240 - i * 40
			local len = zTo - zFrom
			local cz = side * (zFrom + len / 2)
			local w = Kit.buildAt(`TerraceWall_{i}_{side}`, "wall", e[1] - 7, e[2], cz, 0)
			w.bp:box(3, e[3] - e[2] + 1.4, len, 0, (e[3] - e[2]) / 2, 0, o(Props.frostStone, "shell", { q = false }))
			w.bp:box(3.6, 0.8, len, 0, e[3] - e[2] + 1, 0, o(Props.paleStone, "detail", { col = false }))
			Props.snowCap(w.bp, 0, e[3] - e[2] + 1.4, 0, 3, len * 0.9, "fine")
			table.insert(out, w)
		end
	end
end

local function sanctuary(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "sanctuary", "landmark", 34)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	-- the floor, broken colonnade, ice welling up round the back
	bp:box(40, 1, 30, 0, y - 0.3, 0, o(Props.paleStone, "detail", { col = false }))
	for k = 0, 7 do
		for _, side in { -1, 1 } do
			local lz = -12 + k * 3.6
			local h = if (k + (side > 0 and 1 or 0)) % 3 == 0 then 5 else 13
			bp:add(
				"cyl",
				h,
				2.2,
				2.2,
				side * 18,
				y + h / 2,
				lz,
				0,
				0,
				90,
				o(Props.frostStone, if h > 6 then "shell" else "detail", { q = false })
			)
			if h > 6 then
				bp:box(3, 1, 3, side * 18, y + h + 0.4, lz, o(Props.paleStone, "detail", { col = false }))
				Props.snowCap(bp, side * 18, y + h + 1, lz, 3, 3, "fine")
			end
		end
	end
	bp:rbox(44, 9, 14, 0, y + 2, 14, 4, 0, 2, o(Props.ice, "shell", { q = false, t = 0.25 }))
	-- the colossal dragon half sunk in the ice, wings spread, facing the road (south)
	Props.dragonStatue(bp, 0, y - 3, 8, 1.6, 0, true)
	Kit.lifeAt(ctx, b, "icicleDust", 0, 14, 8)
	table.insert(out, b)
end

local function altars(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "offeringAltars", "landmark", 20)
	local bp = b.bp
	for k, inner in { "vessel", "coins", "chest", "vessel" } do
		local a = k * math.pi / 2 + 0.4
		local lx, lz = math.cos(a) * 9, math.sin(a) * 9
		local ly = Kit.gy(ctx, b, lx, lz)
		bp:box(5, 3, 3.4, lx, ly + 1.4, lz, o(Props.paleStone, "shell", { q = false }))
		Props.iceBlock(bp, lx, ly + 3, lz, 0.7, inner, k * 30)
	end
	Props.brazier(bp, 0, Kit.gy(ctx, b, 0, 0), 0, Props.ICEFIRE, "shell")
	-- scattered gold and scales
	for k = 1, 10 do
		local a = k * 0.63
		local lx, lz = math.cos(a) * 5, math.sin(a) * 5
		bp:add(
			"cyl",
			0.12,
			0.7,
			0.7,
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.1,
			lz,
			0,
			0,
			90,
			o(if k % 3 == 0 then Props.dragonScale else Props.gold, "fine", { col = false })
		)
	end
	table.insert(out, b)
end

-- Cult spear racks, frozen armour of fallen knights, patrol tracks, scales.
local function cult(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in { { 470, -150 }, { 540, 150 }, { 620, -60 }, { 700, 100 }, { 460, 220 } } do
		if Env.isClear(env, p[1], p[2], 6) and env.T.roadDistance(p[1], p[2]) > 10 then
			Env.clear(env, p[1], p[2], 8)
			local b = Kit.build(ctx, `CultCamp_{i}`, "traces", p[1], p[2], i * 61)
			local bp = b.bp
			local y = Kit.gy(ctx, b, 0, 0)
			if i % 2 == 1 then
				for m = -2, 2 do
					bp:rbox(0.3, 9, 0.3, m * 1, y + 4.2, 0, 8, 0, m * 3, o(Props.iron, "detail", { col = false }))
				end
				bp:box(6, 0.4, 0.4, 0, y + 6, 0.6, o(Props.oldWood, "detail", { col = false }))
				Props.banner(bp, 4, y, 2, 9, Props.cultBlue, Props.gold, false)
			else
				-- a fallen knight's armour frozen to the ground, a helm with dark eye slits
				bp:box(2.6, 1.2, 5, 0, y + 0.4, 0, o(Props.orderPale, "detail", { col = false }))
				bp:add("ball", 1.8, 1.8, 1.8, 0, y + 0.8, -3.2, 0, 0, 0, o(Props.iron, "detail", { col = false }))
				bp:rbox(0.3, 4, 0.3, 1.6, y + 0.3, 1, 90, 30, 0, o(Props.iron, "fine", { col = false }))
				bp:add("ball", 4, 0.8, 6.4, 0, y + 0.2, 0, 0, 0, 0, o(Props.rime, "fine", { col = false, t = 0.2 }))
				Props.brazier(bp, -4, y, 0, Props.ICEFIRE)
			end
			table.insert(out, b)
		end
	end
	local t = Kit.build(ctx, "PatrolTracks", "traces", 600, 6, 0)
	Props.tracks(t.bp, function(lx: number, lz: number): number
		return Kit.gy(ctx, t, lx, lz)
	end, -80, 0, 270, 30, 1.2, 5)
	table.insert(out, t)
end

function Temple.all(env: Env.Env, out: { Build })
	stairs(env, out)
	sanctuary(env, out)
	altars(env, out)
	cult(env, out)
end

return Temple
