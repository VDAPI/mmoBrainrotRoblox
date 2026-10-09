--!strict
-- Frozen Hold (83-92) dressing (S51): the fortress of the Ice Guard swallowed by the glacier. The order's colours:
-- banners #2F3A4A with a silver sign, torches with blue flames; the one warm light is the giants' fire.
--   1 the Gate under the Ice: the raised frozen portcullis over the exit (no collision), two guard niches with empty
--     armour in the ice, a frozen banner, the drift under the gate, the glacier's tongue in the north wall,
--   2 the Giants' Breach ("wow"): the frozen wave of the glacier through the south-east wall (ice, rubble of the
--     walls), the giants' camp: a fire of broken benches and the order's banners, a seat of the fallen commander's
--     statue (its head beside it), mammoth bones, boulders to throw, a club of a log,
--   3 the Courtyard under the Glacier: arcades along the walls, the frozen well, the Frost Flower (a huge cluster of
--     crystals hanging from the glacier's vault 18+ studs up, pulsing cyan and dripping sparks), the elementals'
--     crystals breaking through the paving,
--   4 the Chapel of Eternal Winter: the altar with the order's sword in a block of ice on its dais, the ice windows
--     with the glacier pressing behind, benches thrown about, candlesticks with frozen candles, knights' statues with
--     beards of ice,
--   5 the Guard's Barracks: stone bunks with frozen blankets, racks of swords, shields and armour, a table with frozen
--     bowls, the north wall broken by the giants into the glacier with giant footprints,
--   6 the Commander's Hall ("wow", Elite II): the commander's high chair on its dais under the great banner frozen
--     mid-flap, the Wall of the Fallen (knights and giants frozen in their last battle behind the ice), the table of a
--     frozen feast, the map of the Peaks pinned with a dagger, a war chest; baskets of blue fire. Pure.

local Grotto = require("./Grotto")
local Kit = require("./Kit")

local o = Kit.o

local Hold = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local BLUE = "#6BC9FF"
local FIRE = "#FF9A3A"
local ORDER = { c = "#2F3A4A", m = "Fabric" }
local SILVER = { c = "#B8D0E0", m = "Metal" }
local STONE = { c = "#4A4744", m = "Slate" }
local ICE = { c = "#A8D8F0", m = "Ice" }
local ICEGLASS = { c = "#BFE8FF", m = "Glass" }
local STEEL = { c = "#9FB6C9", m = "Metal" }
local WOOD = { c = "#4A3E34", m = "Wood" }

local function banner(bp: BP, x: number, y: number, z: number, h: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(4, h, 0.2, 0, h / 2 + 2, 0, o(ORDER, "detail", { col = false }))
	bp:box(1.6, 1.6, 0.25, 0, h * 0.6 + 2, -0.05, o(SILVER, "fine", { col = false }))
	bp:box(4.6, 0.4, 0.4, 0, h + 2.2, 0, o(STEEL, "fine", { col = false }))
	bp:pop()
end

local function knight(bp: BP, x: number, y: number, z: number, yaw: number, lod: any?)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(2.2, 4.4, 1.4, 0, 3.2, 0, o(STEEL, lod or "detail", { q = false, col = lod == "shell" }))
	bp:box(1.4, 1.6, 1.4, 0, 6.2, 0, o(STEEL, "detail", { col = false }))
	bp:box(0.6, 2, 0.5, 0, 4.6, -0.8, o(ICE, "fine", { col = false })) -- a beard of ice
	bp:rbox(0.3, 5, 0.3, 1.4, 3, -0.6, 0, 0, 10, o(SILVER, "fine", { col = false }))
	bp:box(2.4, 1, 1.6, 0, 0.5, 0, o(STONE, "detail", { col = false }))
	bp:pop()
end

local function torches(env: Env, out: { Build }, i: number, n: number)
	local r = env.T.rooms[i]
	for k = 0, n - 1 do
		local x, z = Kit.spot(env, r, (k + 0.5) * 2 * math.pi / n, 3, 1, false)
		if x and z then
			local t = Kit.build(env, `BlueTorch_{i}_{k}`, "lamp", x, z, 0)
			Kit.torch(t.bp, 0, Kit.gy(env, t, 0, 0), 0, BLUE)
			table.insert(out, t)
		end
	end
end

local function glacierTongue(env: Env, out: { Build }, name: string, x: number, z: number, r: number)
	local b = Kit.build(env, name, "traces", x, z, 0)
	local y = Kit.gy(env, b, 0, 0)
	for k = 0, 5 do
		local a = k * 1.05
		b.bp:add(
			"ball",
			r * 0.9,
			r * 0.7,
			r * 0.6,
			math.cos(a) * r * 0.4,
			y + r * 0.2,
			math.sin(a) * r * 0.4,
			0,
			k * 30,
			0,
			o(ICEGLASS, "detail", { col = false, t = 0.3 })
		)
	end
	for k = 0, 4 do
		b.bp:rbox(
			2.4,
			1.4,
			1.8,
			math.cos(k * 1.3) * (r + 2),
			Kit.gy(env, b, math.cos(k * 1.3) * (r + 2), math.sin(k * 1.3) * (r + 2)) + 0.6,
			math.sin(k * 1.3) * (r + 2),
			10,
			k * 40,
			20,
			o(STONE, "detail", { col = false })
		)
	end
	table.insert(out, b)
end

local function gatehouse(env: Env, out: { Build })
	-- the raised frozen portcullis over the exit (-211, 0): lower edge 20+ over the floor
	local p = Kit.build(env, "FrozenPortcullis", "landmark", -214, 0, 90)
	for k = -4, 4 do
		p.bp:box(0.6, 6, 0.6, k * 2, 23, 0, o(Kit.iron, "detail", { col = false }))
		p.bp:add("cyl", 2, 0.5, 0.5, k * 2, 19, 0, 0, 0, 90, o(ICE, "fine", { col = false }))
	end
	for t = 0, 1 do
		p.bp:box(18, 0.6, 0.6, 0, 21 + t * 4, 0, o(Kit.iron, "detail", { col = false }))
	end
	table.insert(out, p)
	-- guard niches with empty armour in the ice, the frozen banner
	local g = Kit.build(env, "GuardNiches", "landmark", -185, 0, 0)
	for _, side in { -1, 1 } do
		local lz = side * 24
		local y = Kit.gy(env, g, 8, lz)
		knight(g.bp, 8, y, lz, if side > 0 then 180 else 0, "shell")
		g.bp:box(4, 9, 3, 8, y + 4.5, lz, o(ICEGLASS, "detail", { col = false, t = 0.4 }))
	end
	banner(g.bp, 30, Kit.gy(env, g, 30, 18), 18, 10, 270)
	table.insert(out, g)
	glacierTongue(env, out, "GateGlacier", -185, -24, 7)
	torches(env, out, 1, 4)
	Kit.life(env.ctx, "snowGust", -205, 0.5, 0, 8)
	Kit.life(env.ctx, "drips", -185, 18, 0, 16)
end

local function breach(env: Env, out: { Build })
	local r = env.T.rooms[2]
	glacierTongue(env, out, "BreachGlacier", -58, 106, 12)
	-- the giants' fire of broken benches and banners (the one warm light of the Hold)
	local x, z = Kit.spot(env, r, math.rad(10), 6, 4)
	if x and z then
		local f = Kit.build(env, "GiantsFire", "camp", x, z, 0)
		local y = Kit.gy(env, f, 0, 0)
		for m = 0, 5 do
			local a = m * math.pi / 3
			f.bp:rbox(
				6,
				0.8,
				0.8,
				math.cos(a) * 1.4,
				y + 0.6,
				math.sin(a) * 1.4,
				0,
				math.deg(-a),
				20,
				o(WOOD, "detail", { col = false })
			)
		end
		f.bp:rbox(3, 0.1, 4, 3, y + 0.5, 0, 0, 30, 30, o(ORDER, "fine", { col = false }))
		Kit.fire(f.bp, 0, y + 1.4, 0, 3.4, FIRE, "detail")
		Kit.lifeAt(env.ctx, f, "embers", 0, 2, 0, 2)
		Kit.lifeAt(env.ctx, f, "smoke", 0, 6, 0, 2)
		Kit.clear(env, x, z, 6)
		table.insert(out, f)
	end
	-- the seat of the fallen statue, its head, mammoth bones, boulders, the club
	local sx, sz = Kit.spot(env, r, math.rad(170), 6, 4)
	if sx and sz then
		local s = Kit.build(env, "GiantsSeat", "landmark", sx, sz, 80)
		local y = Kit.gy(env, s, 0, 0)
		s.bp:rbox(4, 3.6, 14, 0, y + 1.8, 0, 0, 0, 90, o(STONE, "shell", { q = false }))
		s.bp:box(4, 4, 4, 0, y + 2, 10, o(STONE, "detail", { col = false }))
		for m = 0, 4 do
			s.bp:beam(-6 + m * 1.6, y, 6, -6 + m * 1.6, y + 7, 9, 0.6, o(Kit.bone, "detail", { col = false }))
		end
		s.bp:rbox(1.4, 10, 1.4, 5, y + 0.7, -4, 0, 30, 85, o(WOOD, "detail", { col = false }))
		for m = 0, 2 do
			s.bp:add("ball", 3, 2.6, 3, -4 + m * 3, y + 1.2, -6, 0, 0, 0, o(STONE, "detail", { col = false }))
		end
		Kit.clear(env, sx, sz, 8)
		table.insert(out, s)
	end
	torches(env, out, 2, 4)
	Kit.life(env.ctx, "drips", r.x, 26, r.z, 30)
end

local function courtyard(env: Env, out: { Build })
	local r = env.T.rooms[3]
	-- arcades along the walls (columns 44+ studs from the centre)
	local a = Kit.build(env, "CourtyardArcades", "landmark", r.x, r.z, 0)
	for k = 0, 15 do
		local deg = k * 22.5 + 11.25
		local t = math.rad(deg)
		local lx, lz = math.cos(t) * 46, math.sin(t) * 46
		if Kit.free(env, r.x + lx, r.z + lz, 1.6) then
			local y = Kit.gy(env, a, lx, lz)
			a.bp:add("cyl", 18, 2.4, 2.4, lx, y + 9, lz, 0, 0, 90, o(STONE, "shell", { q = false }))
		end
	end
	table.insert(out, a)
	-- the frozen well
	local wx, wz = Kit.spot(env, r, math.rad(270), 6, 4)
	if wx and wz then
		local w = Kit.build(env, "FrozenWell", "landmark", wx, wz, 0)
		local y = Kit.gy(env, w, 0, 0)
		for m = 0, 7 do
			local t = m * math.pi / 4
			w.bp:rbox(
				2,
				2.4,
				1,
				math.cos(t) * 3,
				y + 1.2,
				math.sin(t) * 3,
				0,
				math.deg(-t) + 90,
				0,
				o(STONE, "shell", { q = false })
			)
		end
		w.bp:add("cyl", 0.3, 5, 5, 0, y + 1.6, 0, 0, 0, 90, o(ICE, "detail", { col = false }))
		Kit.clear(env, wx, wz, 5)
		table.insert(out, w)
	end
	-- the Frost Flower hanging from the glacier's vault (18+ studs up, no collision)
	local f = Kit.build(env, "FrostFlower", "glow", r.x, r.z, 0)
	local y = Kit.gy(env, f, 0, 0)
	local top = math.min((Kit.ceil(env, r.x + 8, r.z + 8) or 42) - f.at.y, 42)
	for m = 0, 9 do
		local t = m * 2 * math.pi / 10
		f.bp:beam(
			0,
			top,
			0,
			math.cos(t) * 6,
			math.max(y + 22, top - 14 - (m % 3) * 2),
			math.sin(t) * 6,
			1.4 - (m % 2) * 0.4,
			{
				c = "#9FE0FF",
				m = "Neon",
				lod = "detail",
				col = false,
				q = false,
				t = 0.2,
				tag = "glow",
				jitter = 0,
				fxColor = "#9FE0FF",
			}
		)
	end
	f.bp:light(0, math.max(y + 22, top - 10), 0, "#CFF6FF", 50, 1.8, "crystal")
	Kit.lifeAt(env.ctx, f, "sparkle", 0, math.max(y + 20, top - 16), 0, 6)
	Kit.lifeAt(env.ctx, f, "snowBeam", 0, top, 0, 6)
	table.insert(out, f)
	-- the elementals' crystals breaking through the paving
	for k, deg in { 60, 150, 240, 330 } do
		local x, z = Kit.spot(env, r, math.rad(deg), 6, 2.5)
		if x and z then
			local c = Kit.build(env, `ElementalCrystals_{k}`, "glow", x, z, deg)
			local cy = Kit.gy(env, c, 0, 0)
			for m = 0, 3 do
				c.bp:rbox(
					1.4,
					4 + m,
					1.4,
					(m - 1.5) * 1.2,
					cy + 2 + m / 2,
					(m % 2) * 1,
					0,
					m * 30,
					(m - 1.5) * 14,
					o(ICEGLASS, if m == 1 then "shell" else "detail", { q = false, col = m == 1, t = 0.25 })
				)
			end
			table.insert(out, c)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 30, r.z, 30)
end

local function chapel(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the altar on its dais (130, -77): the order's sword in a block of ice
	local a = Kit.build(env, "IceAltar", "landmark", 130, -78, 0)
	local y = Kit.gy(env, a, 0, 0)
	a.bp:box(6, 3, 3, 0, y + 1.5, 0, o(STONE, "shell", { q = false }))
	a.bp:box(2.4, 6, 2.4, 0, y + 6, 0, o(ICEGLASS, "detail", { col = false, t = 0.35 }))
	a.bp:box(0.4, 5, 0.2, 0, y + 6, 0, o(SILVER, "detail", { col = false }))
	a.bp:box(1.8, 0.4, 0.4, 0, y + 7.4, 0, o(SILVER, "fine", { col = false }))
	Kit.candles(a.bp, -2.4, y + 3, 0, 3, BLUE)
	Kit.candles(a.bp, 2.4, y + 3, 0, 3, BLUE)
	Kit.clear(env, 130, -78, 5)
	table.insert(out, a)
	-- the ice windows (light from the glacier)
	for k, w in env.T.windows() do
		if (w.x - r.x) ^ 2 + (w.z - r.z) ^ 2 < (r.r + 20) ^ 2 then
			Grotto.window(env, out, w, `ChapelWindow_{k}`, "")
		end
	end
	-- benches thrown about, knights' statues with beards of ice
	for k, deg in { 30, 150, 200, 340 } do
		local x, z = Kit.spot(env, r, math.rad(deg), 5, 3)
		if x and z then
			local b = Kit.build(env, `ChapelProps_{k}`, "traces", x, z, deg + k * 25)
			local by = Kit.gy(env, b, 0, 0)
			if k % 2 == 0 then
				knight(b.bp, 0, by, 0, 0, "shell")
			else
				b.bp:rbox(7, 1, 1.6, 0, by + 0.6, 0, 0, 0, 12, o(WOOD, "detail", { col = false }))
			end
			table.insert(out, b)
		end
	end
	torches(env, out, 4, 4)
	Kit.life(env.ctx, "drips", r.x, 24, r.z, 24)
end

local function barracks(env: Env, out: { Build })
	local r = env.T.rooms[5]
	for k, deg in { 0, 60, 120, 180, 240 } do
		local x, z = Kit.spot(env, r, math.rad(deg), 5, 3)
		if x and z then
			local b = Kit.build(env, `Barracks_{k}`, "traces", x, z, deg + 90)
			local y = Kit.gy(env, b, 0, 0)
			if k % 2 == 1 then
				b.bp:box(3, 1.6, 7, 0, y + 0.8, 0, o(STONE, "shell", { q = false }))
				b.bp:box(2.6, 0.3, 6, 0, y + 1.75, 0, o({ c = "#6A7A8A", m = "Fabric" }, "fine", { col = false }))
			elseif k == 2 then
				b.bp:box(6, 2, 3, 0, y + 1, 0, o(WOOD, "shell", { q = false }))
				for m = 0, 3 do
					b.bp:add("cyl", 0.4, 1, 1, -2 + m * 1.3, y + 2.2, 0, 0, 0, 90, o(ICE, "fine", { col = false }))
				end
			else
				b.bp:box(5, 0.5, 1, 0, y + 3.5, 0, o(WOOD, "detail", { col = false }))
				for m = -2, 2 do
					b.bp:rbox(0.3, 4, 0.3, m, y + 2, 0.2, 0, 0, 5, o(STEEL, "fine", { col = false }))
				end
				b.bp:add("cyl", 0.3, 2.6, 2.6, 3.4, y + 1.4, 0, 90, 0, 0, o(ORDER, "fine", { col = false }))
			end
			table.insert(out, b)
		end
	end
	glacierTongue(env, out, "BarracksBreach", -110, -111, 5)
	local t = Kit.build(env, "GiantFootprints", "traces", -110, -104, 0)
	for k = 0, 3 do
		t.bp:rbox(
			4,
			0.06,
			7,
			(k % 2) * 5 - 2.5,
			Kit.gy(env, t, 0, k * 8) + 0.05,
			k * 8,
			0,
			0,
			0,
			o({ c = "#C8D8E4", m = "Snow" }, "fine", { col = false })
		)
	end
	table.insert(out, t)
	torches(env, out, 5, 4)
	Kit.life(env.ctx, "mist", r.x, 0.5, r.z, 36)
	Kit.life(env.ctx, "drips", r.x, 22, r.z, 24)
end

local function commandery(env: Env, out: { Build })
	local r = env.T.rooms[6]
	-- the high chair on its dais under the banner frozen mid-flap
	local c = Kit.build(env, "CommanderChair", "landmark", 209, 95, 270)
	local y = Kit.gy(env, c, 0, 0)
	c.bp:box(4, 2, 3.4, 0, y + 1, 0, o(STONE, "shell", { q = false }))
	c.bp:box(4, 9, 0.8, 0, y + 5.5, 1.6, o(STONE, "detail", { col = false }))
	c.bp:rbox(8, 12, 0.3, 0, y + 16, 3, 0, 0, 6, o(ORDER, "detail", { col = false }))
	c.bp:box(2.6, 2.6, 0.35, 0, y + 17, 2.8, o(SILVER, "fine", { col = false }))
	Kit.clear(env, 209, 95, 5)
	table.insert(out, c)
	-- the Wall of the Fallen
	for k, w in env.T.windows() do
		if (w.x - r.x) ^ 2 + (w.z - r.z) ^ 2 < (r.r + 20) ^ 2 then
			Grotto.window(env, out, w, `WallOfTheFallen_{k}`, "fallen")
		end
	end
	-- the table of the frozen feast, the map pinned with a dagger, the war chest, baskets of blue fire
	local tx, tz = Kit.spot(env, r, math.rad(120), 6, 4)
	if tx and tz then
		local t = Kit.build(env, "FrozenFeast", "traces", tx, tz, 30)
		local ty = Kit.gy(env, t, 0, 0)
		t.bp:box(10, 0.6, 4, 0, ty + 3, 0, o(WOOD, "shell", { q = false }))
		for _, sx in { -4, 4 } do
			for _, sz in { -1.6, 1.6 } do
				t.bp:box(0.6, 3, 0.6, sx, ty + 1.5, sz, o(WOOD, "detail", { col = false }))
			end
		end
		for m = 0, 5 do
			t.bp:add(
				"cyl",
				0.8,
				0.6,
				0.6,
				-4 + m * 1.6,
				ty + 3.7,
				(m % 2) - 0.5,
				0,
				0,
				90,
				o(SILVER, "fine", { col = false })
			)
		end
		t.bp:box(3, 0.05, 2, 2, ty + 3.33, 0.4, o({ c = "#C8B890", m = "Fabric" }, "fine", { col = false }))
		t.bp:rbox(0.2, 1.2, 0.2, 2, ty + 3.8, 0.4, 0, 0, 0, o(STEEL, "fine", { col = false }))
		Kit.crate(t.bp, 7, ty, 2, 1, 20, "detail")
		Kit.clear(env, tx, tz, 7)
		table.insert(out, t)
	end
	for k, deg in { 60, 300 } do
		local x, z = Kit.spot(env, r, math.rad(deg), 4, 1.5, false)
		if x and z then
			local f = Kit.build(env, `BlueBasket_{k}`, "lamp", x, z, 0)
			local fy = Kit.gy(env, f, 0, 0)
			f.bp:box(0.6, 3.4, 0.6, 0, fy + 1.7, 0, o(Kit.iron, "detail", { col = false }))
			Kit.fire(f.bp, 0, fy + 3.8, 0, 1.4, BLUE, "detail")
			table.insert(out, f)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 26, r.z, 24)
end

function Hold.all(env: Env, out: { Build })
	gatehouse(env, out)
	breach(env, out)
	courtyard(env, out)
	chapel(env, out)
	barracks(env, out)
	commandery(env, out)
end

return Hold
