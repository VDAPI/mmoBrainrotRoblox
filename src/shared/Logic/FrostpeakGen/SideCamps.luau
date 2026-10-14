--!strict
-- Camps of the Frost Peaks side arc NPCs (S108): a small camp 5 studs behind each NPC place of Data/Areas/frostpeak
-- (`npcSpots` cairn, horn, skald, icefisher, bonecarver, squire, scholar), turned like the NPC (the camp's front, local
-- -Z, looks where the NPC looks; the NPC stands at local 0 / -5). Mostly detail and fine pieces, only the tents
-- collide; at most one light each. Every camp's clearing lies inside the avoid circle of its place grown by 6 studs,
-- so the gathering nodes and the monster groups do not move (tests/frostpeak.spec S108). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local SideCamps = {}

type Build = Kit.Build
type BP = Kit.BP

-- How far behind its NPC a camp's middle stands, and the radius of its clearing (no trees or rocks).
SideCamps.BEHIND = 5
SideCamps.CLEAR = 5

-- The camps in a fixed order: the NPC place key and its builder.
local ORDER = { "cairn", "horn", "skald", "icefisher", "bonecarver", "squire", "scholar" }

local RIBBONS = { "#A3282A", "#2E5A8A", "#C9A45C", "#6E6A64" }
local FISH = { c = "#8A9AA8", m = "SmoothPlastic" }

local function gy(env: Env.Env, b: Build, lx: number, lz: number): number
	return Kit.gy(env.ctx, b, lx, lz)
end

-- A low wooden stool (a sawn log).
local function stool(env: Env.Env, b: Build, x: number, z: number)
	b.bp:add("cyl", 1, 1.2, 1.2, x, gy(env, b, x, z) + 0.5, z, 0, 0, 90, o(Props.oldWood, "detail", { col = false }))
end

-- Old Ingrid: a stool, a basket of coloured ribbons, a small lantern.
local function cairn(env: Env.Env, b: Build)
	local bp = b.bp
	stool(env, b, -1.4, -0.6)
	local y = gy(env, b, 1.4, 0.4)
	bp:add("cyl", 0.9, 1.5, 1.5, 1.4, y + 0.45, 0.4, 0, 0, 90, o(Kit.straw, "detail", { col = false }))
	for k, color in RIBBONS do
		local a = k * 1.5
		bp:rbox(
			0.12,
			1.1,
			0.3,
			1.4 + math.cos(a) * 0.6,
			y + 0.75,
			0.4 + math.sin(a) * 0.6,
			0,
			math.deg(a),
			20,
			o({ c = color, m = "Fabric" }, "fine", { col = false })
		)
	end
	bp:box(1.6, 0.4, 1.2, -1.4, gy(env, b, -1.4, 1.4) + 0.2, 1.4, o(Props.paleHide, "detail", { col = false }))
	Kit.lantern(bp, -2.6, gy(env, b, -2.6, 1.6), 1.6, nil, 3.5)
end

-- Eskil: a screen of hides on two poles, the empty stand of the great horn, a brazier.
local function horn(env: Env.Env, b: Build)
	local bp = b.bp
	for _, x in { -2.6, 2.6 } do
		bp:box(0.4, 4.2, 0.4, x, gy(env, b, x, 2.6) + 2.1, 2.6, o(Props.oldWood, "detail", { col = false }))
	end
	bp:rbox(5.2, 3.2, 0.2, 0, gy(env, b, 0, 2.6) + 2.4, 2.8, 8, 0, 0, o(Props.hide, "detail", { col = false }))
	-- the stand: a tripod with two hooks and nothing on them
	local sy = gy(env, b, -1.6, 0.4)
	for k = 0, 2 do
		local a = k * 2.1
		bp:rbox(
			0.3,
			3,
			0.3,
			-1.6 + math.cos(a) * 0.6,
			sy + 1.4,
			0.4 + math.sin(a) * 0.6,
			0,
			k * 120,
			12,
			o(Props.oldWood, "detail", { col = false })
		)
	end
	bp:box(2.4, 0.25, 0.25, -1.6, sy + 2.7, 0.4, o(Props.oldWood, "detail", { col = false }))
	for _, x in { -2.5, -0.7 } do
		bp:box(0.15, 0.6, 0.15, x, sy + 2.4, 0.4, o(Props.iron, "fine", { col = false }))
	end
	Props.brazier(bp, 2, gy(env, b, 2, 0.2), 0.2, Kit.FIRE)
end

-- Ragnvald: a bedroll, a small fire, a writing board on a stone and a tube for scrolls.
local function skald(env: Env.Env, b: Build)
	local bp = b.bp
	bp:box(1.6, 0.3, 3.4, -2.2, gy(env, b, -2.2, 1.2) + 0.15, 1.2, o(Props.hide, "detail", { col = false }))
	bp:add(
		"cyl",
		1.6,
		0.7,
		0.7,
		-2.2,
		gy(env, b, -2.2, 2.7) + 0.4,
		2.7,
		0,
		0,
		0,
		o(Props.paleHide, "fine", { col = false })
	)
	Kit.campfire(bp, 1.8, gy(env, b, 1.8, 1.6), 1.6)
	local y = gy(env, b, -0.4, -1.4)
	bp:box(1.4, 0.8, 1.2, -0.4, y + 0.4, -1.4, o(Props.frostStone, "detail", { col = false }))
	bp:rbox(1.2, 0.1, 0.9, -0.4, y + 0.9, -1.4, 10, 0, 0, o(Props.oldWood, "fine", { col = false }))
	bp:box(0.8, 0.02, 0.6, -0.4, y + 0.97, -1.4, o({ c = "#D8C8A0", m = "SmoothPlastic" }, "fine", { col = false }))
	bp:add(
		"cyl",
		1.4,
		0.4,
		0.4,
		0.6,
		y + 0.2,
		-0.6,
		0,
		30,
		0,
		o({ c = "#6B3A2A", m = "Fabric" }, "fine", { col = false })
	)
end

-- Torvi: a sledge with crates of fish, two ice augers, a rack of drying fish.
local function icefisher(env: Env.Env, b: Build)
	local bp = b.bp
	local y = gy(env, b, -1.8, 1)
	for _, x in { -2.5, -1.1 } do
		bp:box(0.2, 0.3, 3.6, x, y + 0.15, 1, o(Props.oldWood, "detail", { col = false }))
	end
	bp:box(1.8, 0.25, 3, -1.8, y + 0.5, 1, o(Props.frozenWood, "detail", { col = false }))
	for k = 0, 1 do
		local z = 0.2 + k * 1.6
		bp:box(1.3, 0.7, 1.2, -1.8, y + 1, z, o(Props.oldWood, "detail", { col = false }))
		bp:rbox(0.9, 0.25, 0.3, -1.8, y + 1.45, z, 0, k * 40, 0, o(FISH, "fine", { col = false }))
	end
	for k = 0, 1 do
		local x = 0.4 + k * 0.8
		local ay = gy(env, b, x, 2.4)
		bp:rbox(0.18, 3, 0.18, x, ay + 1.4, 2.4, 0, 0, -10 + k * 20, o(Props.iron, "detail", { col = false }))
		bp:box(1.2, 0.2, 0.2, x, ay + 2.9, 2.4, o(Props.oldWood, "fine", { col = false }))
	end
	local ry = gy(env, b, 2.6, 0.6)
	for _, z in { -0.6, 1.8 } do
		bp:box(0.3, 2.6, 0.3, 2.6, ry + 1.3, z, o(Props.oldWood, "detail", { col = false }))
	end
	bp:box(0.2, 0.2, 2.8, 2.6, ry + 2.5, 0.6, o(Props.oldWood, "detail", { col = false }))
	for k = 0, 3 do
		bp:box(0.25, 0.9, 0.35, 2.6, ry + 1.95, -0.3 + k * 0.6, o(FISH, "fine", { col = false }))
	end
end

-- Gunnar: a carver's bench, pieces of tusk, a few bone figurines and a tent of hides on bones.
local function bonecarver(env: Env.Env, b: Build)
	local bp = b.bp
	Props.hideTent(bp, 0, gy(env, b, 0, 2.4), 2.4, 0.55, 0, true)
	local y = gy(env, b, -2.6, -0.8)
	bp:box(2.6, 0.3, 0.9, -2.6, y + 0.8, -0.8, o(Props.oldWood, "detail", { col = false }))
	for _, x in { -3.6, -1.6 } do
		bp:box(0.3, 0.7, 0.7, x, y + 0.35, -0.8, o(Props.oldWood, "detail", { col = false }))
	end
	for k = 0, 2 do
		bp:box(0.25, 0.5, 0.25, -3.3 + k * 0.6, y + 1.2, -0.8, o(Kit.bone, "fine", { col = false }))
	end
	local ty = gy(env, b, 2.6, -0.6)
	for k = 0, 1 do
		bp:add(
			"cyl",
			2.4 - k * 0.6,
			0.5,
			0.5,
			2.6,
			ty + 0.25 + k * 0.45,
			-0.6 + k * 0.3,
			0,
			20 + k * 50,
			0,
			o(Props.tusk, "detail", { col = false })
		)
	end
end

-- Asmund: a lean-to of his old shield and cloak, a small fire.
local function squire(env: Env.Env, b: Build)
	local bp = b.bp
	local y = gy(env, b, -1.6, 1.8)
	bp:box(0.3, 3, 0.3, -1.6, y + 1.5, 1.8, o(Props.oldWood, "detail", { col = false }))
	bp:rbox(2.6, 0.12, 3.2, -1.6, y + 1.4, 2.4, 50, 0, 0, o(Props.orderDark, "detail", { col = false }))
	bp:add("cyl", 0.25, 2.2, 2.2, -0.4, y + 1, 1.4, 0, 70, 80, o(Props.orderPale, "detail", { col = false }))
	bp:add("cyl", 0.3, 0.6, 0.6, -0.5, y + 1, 1.3, 0, 70, 80, o(Props.iron, "fine", { col = false }))
	Kit.campfire(bp, 1.8, gy(env, b, 1.8, 0.6), 0.6)
end

-- Vigdis: a tent, a chest of books, an easel with a drawing of a scale, a lantern.
local function scholar(env: Env.Env, b: Build)
	local bp = b.bp
	Props.hideTent(bp, 0, gy(env, b, 0, 2.6), 2.6, 0.55, 0, false)
	local y = gy(env, b, -2.6, -0.6)
	bp:box(1.6, 0.9, 1, -2.6, y + 0.45, -0.6, o(Props.oldWood, "detail", { col = false }))
	for k = 0, 2 do
		bp:box(
			0.3,
			0.9,
			0.7,
			-3.1 + k * 0.4,
			y + 1.35,
			-0.6,
			o({ c = RIBBONS[k + 1], m = "Fabric" }, "fine", { col = false })
		)
	end
	local ey = gy(env, b, 2.4, -0.4)
	for k = 0, 2 do
		bp:rbox(
			0.15,
			2.8,
			0.15,
			2.4 + math.cos(k * 2.1) * 0.5,
			ey + 1.3,
			-0.4 + math.sin(k * 2.1) * 0.5,
			0,
			k * 120,
			10,
			o(Props.oldWood, "fine", { col = false })
		)
	end
	bp:rbox(
		1.4,
		1.1,
		0.08,
		2.4,
		ey + 2.2,
		-0.7,
		-12,
		0,
		0,
		o({ c = "#D8C8A0", m = "SmoothPlastic" }, "detail", { col = false })
	)
	bp:rbox(
		0.7,
		0.7,
		0.02,
		2.4,
		ey + 2.2,
		-0.75,
		-12,
		0,
		45,
		o({ c = "#3A6B8A", m = "SmoothPlastic" }, "fine", { col = false })
	)
	Kit.lantern(bp, -3.6, gy(env, b, -3.6, 1.4), 1.4, nil, 3.5)
end

local BUILDERS: { [string]: (Env.Env, Build) -> () } = {
	cairn = cairn,
	horn = horn,
	skald = skald,
	icefisher = icefisher,
	bonecarver = bonecarver,
	squire = squire,
	scholar = scholar,
}

-- The middle of the camp behind an NPC place (facing in degrees, the NPC's front is (-sin, -cos)).
function SideCamps.at(spot: { x: number, z: number, facing: number }): (number, number)
	local a = math.rad(spot.facing)
	return spot.x + math.sin(a) * SideCamps.BEHIND, spot.z + math.cos(a) * SideCamps.BEHIND
end

-- The keys of the camps in building order (tests).
function SideCamps.keys(): { string }
	return table.clone(ORDER)
end

-- Builds the camps into `out`, each with its clearing (after the bridges, poles and rocks, before the trees).
function SideCamps.all(env: Env.Env, out: { Build })
	local spots = env.areas.npcSpots or {}
	for _, key in ORDER do
		local spot = spots[key]
		if not spot then
			continue
		end
		local x, z = SideCamps.at(spot)
		Env.clear(env, x, z, SideCamps.CLEAR)
		local b = Kit.build(env.ctx, `SideCamp_{key}`, "camp", x, z, spot.facing)
		BUILDERS[key](env, b)
		table.insert(out, b)
	end
end

return SideCamps
