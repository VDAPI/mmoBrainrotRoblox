--!strict
-- Dead Oasis (46–52, better loot) (S46): a dry lake bed of salt cracked into polygons.
--   * the stranded boat (the landmark): a boat lying on its keel on the dry bed far from any water,
--   * the old jetty running from the north shore over the dry bed down to the last murky, steaming pond (fishing at
--     its foot),
--   * the caravan graveyard: torn tents, overturned wagons, broken crates with goods spilt (the loot profile),
--     skeletons of pack animals still in their saddles; the chest in the middle of the bed the vultures circle,
--   * a ring of dead palms on the old shore with white streaks under them, trampled paths down to the pond. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Oasis = {}

type Build = Kit.Build

local function boat(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "strandedBoat", "landmark", 16)
	local bp = b.bp
	-- hull of planks on its keel, listing to one side
	bp:push(0, 1.6, 0, 0, 0, 14)
	bp:box(5, 0.5, 15, 0, 0, 0, o(Kit.greyPlanks, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:rbox(0.5, 2.6, 15, side * 2.6, 1, 0, 0, 0, side * -18, o(Kit.greyPlanks, "shell", { q = false }))
	end
	bp:add("wedge", 5, 2.8, 3, 0, 1, -8.8, 0, 180, 0, o(Kit.greyPlanks, "detail", { col = false }))
	bp:box(0.5, 9, 0.5, 0, 5, -2, o(Kit.deadBark, "detail", { col = false }))
	bp:rbox(0.1, 4, 3, 0.3, 6, -2, 0, 0, 8, o(Kit.rag, "fine", { tag = "flag" }))
	for k = 0, 3 do
		bp:box(4.6, 0.2, 0.3, 0, 0.3, -6 + k * 4, o(Kit.timber, "fine"))
	end
	bp:pop()
	Kit.claws(bp, 3.2, 2.4, 0, 1)
	Kit.lifeAt(ctx, b, "vulturePerch", 0, 10.6, -2)
	table.insert(out, b)
end

-- The jetty over the dry bed: posts and planks from the shore to the pond (fishing at its foot).
local function jetty(env: Env.Env, out: { Build })
	local s = env.sites.oasisJetty
	local lake = env.areas.lakes[1]
	local fromZ, toZ = 490, lake.z - lake.r + 4
	local mid = (fromZ + toZ) / 2
	for z = fromZ, toZ, 30 do
		Env.clear(env, s.x, z, 8)
	end
	local top = math.max(env.T.height(s.x, fromZ), env.T.shape.lakeLevel) + 2.4
	local b = Kit.buildAt("oasisJetty", "jetty", s.x, top, mid, 0)
	local bp = b.bp
	local len = toZ - fromZ
	for k = 0, math.floor(len / 2) do
		local z = -len / 2 + k * 2
		bp:box(
			6,
			0.3,
			1.6,
			0,
			0,
			z,
			o(
				if k % 7 == 3 then Kit.charred else Kit.greyPlanks,
				if k % 4 == 0 then "shell" else "detail",
				{ q = false }
			)
		)
	end
	for k = 0, math.floor(len / 8) do
		local z = -len / 2 + k * 8
		for _, side in { -1, 1 } do
			local g = env.T.height(s.x + side * 2.8, mid + z) - top
			bp:add(
				"cyl",
				-g + 0.6,
				0.8,
				0.8,
				side * 2.8,
				g / 2 + 0.1,
				z,
				0,
				0,
				90,
				o(Kit.deadBark, "detail", { col = false })
			)
		end
	end
	Kit.lantern(bp, 3.6, 0, len / 2 - 2, Props.EMBER, 5)
	table.insert(out, b)
end

-- The caravan graveyard on the east side of the bed and the chest in the middle.
local function caravan(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "caravanGrave", "camp", 30)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Props.wagon(bp, -8, gy(-8, 4), 4, 30, true, false, true)
	Props.wagon(bp, 10, gy(10, -6), -6, 200, false, true, false)
	Props.wagon(bp, 2, gy(2, 16), 16, 110, true, false, false)
	for k = 1, 3 do
		local lx, lz = -14 + k * 9, -14 + (k % 2) * 4
		bp:push(lx, gy(lx, lz), lz, 0, k * 70, 0)
		for _, side in { -1, 1 } do
			bp:rbox(
				7,
				0.3,
				4.6,
				0,
				2.2,
				side * 1.6,
				side * (40 + k * 8),
				0,
				0,
				o(if k == 2 then Props.rustCloth else Kit.cloth, "detail", { col = false })
			)
		end
		bp:box(0.35, 4.4, 0.35, 3.2, 2, 0, o(Kit.timber, "detail"))
		bp:pop()
	end
	for k = 1, 6 do
		local lx, lz = bp.rng:float(-16, 16), bp.rng:float(-16, 16)
		Props.crate(bp, lx, gy(lx, lz), lz, 2.4, k % 2 == 0, if k == 1 then "shell" else nil)
	end
	for k = 1, 3 do
		local lx, lz = -18 + k * 10, 12 + k * 2
		Props.carcass(bp, lx, gy(lx, lz), lz, k * 60)
		bp:box(1.8, 0.6, 1.4, lx, gy(lx, lz) + 1.5, lz, o(Kit.hide, "fine")) -- the saddle still on
	end
	Props.coins(bp, 4, gy(4, 6), 6, 6)
	Kit.lifeAt(ctx, b, "vultures", 0, 46, 0, 24)
	table.insert(out, b)

	local c = Env.atSite(env, "caravanChest", "camp", 8)
	local cp = c.bp
	cp:box(3, 2, 2, 0, 1, 0, o(Kit.planks, "shell", { q = false }))
	cp:rbox(3.1, 0.4, 2.1, 0, 2.5, 0.9, -40, 0, 0, o(Kit.planks, "detail", { col = false }))
	cp:box(3.1, 0.3, 0.3, 0, 1.5, -1, o(Props.ironDark, "fine"))
	Props.coins(cp, 0, 0, -2.4, 10)
	cp:add("ball", 1, 1.2, 0.4, 1.6, 0.4, -2.2, 70, 0, 0, o(Props.gold, "fine")) -- a gold mask
	Kit.lifeAt(ctx, c, "vultures", 0, 38, 0, 18)
	table.insert(out, c)
end

-- Dead palms on the old shore with white streaks under them; feathers.
local function palms(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local dl = assert(env.T.shape.drylakes, "drylakes")[1]
	local n = 0
	for k = 0, 21 do
		local a = k * 2 * math.pi / 22 + 0.13
		local e = 1.04 + 0.06 * math.sin(k * 2.3)
		local x, z = dl.x + math.cos(a) * dl.rx * e, dl.z + math.sin(a) * dl.rz * e
		if env.T.roadDistance(x, z) > 6 and Env.isClear(env, x, z, 2) and env.T.slope(x, z, 2) < 0.6 then
			n += 1
			Env.clear(env, x, z, 4)
			local b = Kit.build(ctx, `OasisPalm_{n}`, "trees", x, z, 0)
			Props.palm(b.bp, 0, -0.3, 0, 0.9 + (k % 3) * 0.12, true)
			b.bp:add(
				"ball",
				3.6,
				0.1,
				2.4,
				2,
				0.05,
				1.4,
				0,
				k * 20,
				0,
				o({ c = "#E8E4DA", m = "SmoothPlastic" }, "fine")
			)
			if k % 4 == 0 then
				Kit.lifeAt(ctx, b, "vulturePerch", 0, 12.5, 2.4)
			end
			table.insert(out, b)
		end
	end
end

function Oasis.all(env: Env.Env, out: { Build })
	boat(env, out)
	jetty(env, out)
	caravan(env, out)
	palms(env, out)
	-- the last pond is a hot spring too: steam and a faint orange glow from under the water
	local lake = env.areas.lakes[1]
	local pond = Kit.buildAt("OasisPond", "pool", lake.x, env.T.shape.lakeLevel, lake.z, 0)
	pond.bp:light(0, -1.5, 0, Props.LAVA, 24, 0.6)
	table.insert(out, pond)
	Kit.life(env.ctx, "steam", lake.x, env.T.shape.lakeLevel + 0.4, lake.z, lake.r * 0.8)
end

return Oasis
