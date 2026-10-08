--!strict
-- Small and middle props of the Ashen Wastes (S46) shared by its modules: the palette of the region and of its
-- monsters (Data/MonsterLooks), bones of giant beasts, statues and stone figures, obelisks, columns, sarcophagi and
-- urns, wagons, crates and coins, palms, burrows and shed carapaces, ember heaps, scorch marks. All draw into a
-- Blueprint in its current frame (front = -Z). Pure.

local Kit = require("../WorldGen/Kit")

local o = Kit.o

local Props = {}

type BP = Kit.BP
type Swatch = Kit.Swatch

-- Palette ---------------------------------------------------------------------------------------------------------

Props.ash = { c = "#6E6862", m = "Slate" }
Props.ashDark = { c = "#4A4542", m = "Slate" }
Props.basalt = { c = "#2E2A2C", m = "Basalt" }
Props.rust = { c = "#7A4A34", m = "Sandstone" }
Props.redRock = Kit.redRock
Props.sandstone = { c = "#B89A6A", m = "Sandstone" }
Props.paleStone = { c = "#C8B48A", m = "Sandstone" }
Props.darkSand = { c = "#8E7450", m = "Sandstone" }
Props.petrified = { c = "#8A8680", m = "Slate" } -- turned to stone by the basilisk
Props.gold = { c = "#C9A45C", m = "Metal" }
Props.linen = { c = "#D8C9A0", m = "Fabric" }
Props.rustCloth = { c = "#8A3A2A", m = "Fabric" }
Props.orcHide = { c = "#5A4A3A", m = "Fabric" }
Props.obsidian = { c = "#16141C", m = "Glass" }
Props.salt = { c = "#E2DACB", m = "SmoothPlastic" }
Props.soot = { c = "#1A1716", m = "Slate" }
Props.ironDark = { c = "#3A3634", m = "CorrodedMetal" }
Props.scale = { c = "#6B2E25", m = "SmoothPlastic" } -- wyvern scales
Props.carapace = { c = "#C29A5B", m = "SmoothPlastic" } -- scorpion carapace

Props.EMBER = "#FF7A1A"
Props.LAVA = "#FF6A20"
Props.TURQUOISE = "#6BE0FF"
Props.SULPHUR = "#E8D24A"

-- Bones of giants -------------------------------------------------------------------------------------------------

-- Giant skull (cranium, brow, eye sockets, jaw with teeth), facing -Z.
function Props.bigSkull(bp: BP, x: number, y: number, z: number, s: number, yaw: number, lod: string?)
	local l = (lod or "shell") :: any
	bp:push(x, y, z, 0, yaw, 0)
	bp:add("ball", 8 * s, 6.4 * s, 9 * s, 0, 3 * s, 0, 0, 0, 0, o(Kit.bone, l, { q = false }))
	bp:add("ball", 6 * s, 3 * s, 5 * s, 0, 1.4 * s, -3.6 * s, 0, 0, 0, o(Kit.oldBone, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:add(
			"ball",
			1.8 * s,
			1.6 * s,
			1,
			side * 1.8 * s,
			3.6 * s,
			-4.3 * s,
			0,
			0,
			0,
			o(Kit.dark, "detail", { col = false })
		)
		bp:rbox(
			1.2 * s,
			0.6 * s,
			4 * s,
			side * 3.2 * s,
			1.2 * s,
			-2.4 * s,
			0,
			side * 12,
			0,
			o(Kit.oldBone, "detail", { col = false })
		)
	end
	for i = -2, 2 do
		bp:add("wedge", 0.5 * s, 1 * s, 0.4 * s, i * 0.8 * s, 0.3 * s, -5.6 * s, 180, 0, 0, o(Kit.bone, "fine"))
	end
	bp:pop()
end

-- Scatter of gnawed bones and a small skull (detail / fine).
function Props.gnawed(bp: BP, x: number, y: number, z: number, n: number)
	Kit.bones(bp, x, y, z, n)
end

-- Stone figures --------------------------------------------------------------------------------------------------

-- King's statue `s` scale: plinth, robed body, arms, head with a crown (`sw` stone); `fallen` lays it on the side.
function Props.king(bp: BP, x: number, y: number, z: number, s: number, yaw: number, sw: Swatch, lod: string?)
	local l = (lod or "shell") :: any
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(5 * s, 2 * s, 5 * s, 0, s, 0, o(sw, l, { q = false }))
	bp:box(3.4 * s, 7 * s, 2.6 * s, 0, 5.5 * s, 0, o(sw, l, { q = false }))
	bp:box(4.6 * s, 1.6 * s, 2.8 * s, 0, 8.6 * s, 0, o(sw, "detail", { col = false }))
	bp:add("ball", 2.2 * s, 2.4 * s, 2.2 * s, 0, 10.4 * s, 0, 0, 0, 0, o(sw, "detail", { col = false }))
	for i = -1, 1 do
		bp:add("wedge", 0.5 * s, 1 * s, 0.5 * s, i * 0.7 * s, 12 * s, 0, 0, 0, 0, o(sw, "fine"))
	end
	-- arms holding a sceptre on the chest
	bp:rbox(1 * s, 4.4 * s, 1 * s, -1.6 * s, 6.2 * s, -0.9 * s, -20, 0, -8, o(sw, "detail", { col = false }))
	bp:rbox(1 * s, 4.4 * s, 1 * s, 1.6 * s, 6.2 * s, -0.9 * s, -20, 0, 8, o(sw, "detail", { col = false }))
	bp:box(0.4 * s, 6 * s, 0.4 * s, 0, 6 * s, -1.6 * s, o(sw, "fine"))
	bp:pop()
end

-- Standing stone person (petrified traveller): legs, torso, arms raised against something, head.
function Props.person(bp: BP, x: number, y: number, z: number, yaw: number, pose: number, sw: Swatch)
	bp:push(x, y, z, 0, yaw, 0)
	bp:rbox(0.7, 2.6, 0.7, -0.45, 1.3, 0, pose * 8, 0, 0, o(sw, "detail", { col = false }))
	bp:rbox(0.7, 2.6, 0.7, 0.45, 1.3, 0, -pose * 10, 0, 0, o(sw, "detail", { col = false }))
	bp:rbox(1.8, 2.6, 1, 0, 3.8, 0.2 * pose, 10 * pose, 0, 0, o(sw, "shell", { q = false }))
	bp:add("ball", 1.1, 1.2, 1.1, 0, 5.6, 0.4 * pose, 0, 0, 0, o(sw, "detail", { col = false }))
	bp:rbox(0.5, 2.4, 0.5, -1.2, 5, -0.4, -60 - pose * 30, 0, -20, o(sw, "detail", { col = false }))
	bp:rbox(0.5, 2.4, 0.5, 1.2, 4.6, -0.2, -40, 0, 30, o(sw, "detail", { col = false }))
	bp:pop()
end

-- Ox (or any pack beast): body, head with horns, four legs; `sw` stone or hide.
function Props.ox(bp: BP, x: number, y: number, z: number, yaw: number, sw: Swatch, lod: string?)
	local l = (lod or "detail") :: any
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(2.6, 2.6, 5.4, 0, 3, 0, o(sw, l, { col = l == "shell", q = false }))
	bp:box(1.6, 1.6, 2, 0, 3.6, -3.4, o(sw, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:rbox(0.3, 0.3, 1.6, side * 1, 4.6, -3.6, 0, side * 50, 20, o(Kit.bone, "fine"))
		for _, dz in { -1.8, 1.8 } do
			bp:box(0.7, 2, 0.7, side * 0.9, 1, dz, o(sw, "detail", { col = false }))
		end
	end
	bp:pop()
end

-- Skeleton of a pack beast: spine, ribs, skull (detail / fine).
function Props.carcass(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(0.5, 0.5, 6, 0, 1.2, 0, o(Kit.oldBone, "detail", { col = false }))
	for k = -2, 2 do
		for _, side in { -1, 1 } do
			bp:rbox(0.3, 2.2, 0.3, side * 0.9, 0.8, k * 1.1, 0, 0, side * 28, o(Kit.bone, "fine"))
		end
	end
	Kit.skull(bp, 0, 0.2, -3.6, 1.4, 0)
	bp:pop()
end

-- Monuments ------------------------------------------------------------------------------------------------------

function Props.obelisk(bp: BP, x: number, y: number, z: number, h: number, sw: Swatch, lod: string?)
	local l = (lod or "shell") :: any
	bp:box(2.6, 1, 2.6, x, y + 0.3, z, o(sw, "detail", { col = false }))
	bp:box(1.8, h, 1.8, x, y + h / 2 + 0.6, z, o(sw, l, { q = false }))
	bp:add("corner", 0.9, 1.6, 0.9, x - 0.45, y + h + 1.4, z - 0.45, 0, 0, 0, o(Props.gold, "fine"))
	bp:add("corner", 0.9, 1.6, 0.9, x + 0.45, y + h + 1.4, z + 0.45, 0, 180, 0, o(Props.gold, "fine"))
end

-- Column (a drum shaft with a capital); `broken` leaves a stump and the fallen drums beside it.
function Props.column(bp: BP, x: number, y: number, z: number, h: number, sw: Swatch, broken: boolean?)
	local rng = bp.rng
	local stand = if broken then h * rng:float(0.25, 0.55) else h
	bp:add("cyl", stand, 2.2, 2.2, x, y + stand / 2 - 0.3, z, 0, 0, 90, o(sw, "shell", { q = false }))
	if broken then
		local a = rng:float(0, math.pi * 2)
		for k = 1, 2 do
			bp:add(
				"cyl",
				2.4,
				2.2,
				2.2,
				x + math.cos(a) * (2 + k * 2.6),
				y + 0.9,
				z + math.sin(a) * (2 + k * 2.6),
				0,
				math.deg(-a) + rng:float(-20, 20),
				0,
				o(sw, "detail", { col = false })
			)
		end
	else
		bp:box(3, 0.8, 3, x, y + stand, z, o(sw, "detail", { col = false }))
	end
end

-- Sarcophagus (lid on, or pushed aside and empty), facing -Z.
function Props.sarcophagus(bp: BP, x: number, y: number, z: number, yaw: number, open: boolean)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(3, 2, 7, 0, 1, 0, o(Props.sandstone, "shell", { q = false }))
	if open then
		bp:box(2.2, 0.4, 6.2, 0, 1.85, 0, o(Kit.dark, "detail", { col = false }))
		bp:rbox(3.2, 0.6, 7.2, 2.6, 0.5, 0.6, 0, 14, -20, o(Props.paleStone, "detail", { col = false }))
		bp:box(0.8, 0.1, 2.4, 0, 1.95, -1, o(Props.linen, "fine"))
	else
		bp:box(3.2, 0.6, 7.2, 0, 2.3, 0, o(Props.paleStone, "detail", { col = false }))
		bp:add("ball", 1.4, 0.8, 1.6, 0, 2.8, -2.4, 0, 0, 0, o(Props.gold, "fine"))
	end
	bp:pop()
end

-- Canopic urn (fine).
function Props.urn(bp: BP, x: number, y: number, z: number)
	bp:add("cyl", 1.4, 1, 1, x, y + 0.7, z, 0, 0, 90, o(Props.darkSand, "fine"))
	bp:add("ball", 0.8, 0.7, 0.8, x, y + 1.6, z, 0, 0, 0, o(Props.gold, "fine"))
end

-- Coins and a gold mask spilt on the ground (fine; the gold profile).
function Props.coins(bp: BP, x: number, y: number, z: number, n: number)
	local rng = bp.rng
	for _ = 1, n do
		bp:add(
			"cyl",
			0.12,
			0.6,
			0.6,
			x + rng:float(-1.8, 1.8),
			y + 0.06,
			z + rng:float(-1.8, 1.8),
			0,
			0,
			90,
			o(Props.gold, "fine", { col = false, jitter = 0.1 })
		)
	end
end

-- Camp and caravan --------------------------------------------------------------------------------------------------

-- Crate (`broken`: staves apart and the goods spilt).
function Props.crate(bp: BP, x: number, y: number, z: number, s: number, broken: boolean?, lod: string?)
	local l = (lod or "detail") :: any
	if broken then
		for k = 0, 3 do
			bp:rbox(
				s,
				0.2,
				s * 0.3,
				x + k * 0.4,
				y + 0.1,
				z + k * 0.5,
				0,
				k * 40,
				8,
				o(Kit.planks, "detail", { col = false })
			)
		end
		bp:add("ball", s * 0.9, s * 0.4, s * 0.8, x + 1, y + 0.2, z - 0.8, 0, 0, 0, o(Kit.cloth, "fine"))
	else
		bp:box(s, s, s, x, y + s / 2, z, o(Kit.planks, l, { col = l == "shell", q = false }))
	end
end

-- Wagon: bed, wheels, shafts; `over` turns it onto its side, `burnt` blackens it, `cover` adds a torn tilt.
function Props.wagon(
	bp: BP,
	x: number,
	y: number,
	z: number,
	yaw: number,
	over: boolean,
	burnt: boolean,
	cover: boolean
)
	local wood = if burnt then Kit.charred else Kit.planks
	bp:push(x, y, z, 0, yaw, if over then 80 else 0)
	bp:box(5, 0.6, 9, 0, 2.2, 0, o(wood, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:box(0.3, 1.4, 9, side * 2.5, 3.1, 0, o(wood, "detail", { col = false }))
		for _, dz in { -3, 3 } do
			bp:add("cyl", 0.4, 3.2, 3.2, side * 2.8, 1.6, dz, 0, 0, 0, o(Kit.darkBark, "detail", { col = false }))
		end
	end
	bp:beam(-0.8, 1.8, -4.5, -0.8, 1, -8, 0.3, o(wood, "detail", { col = false }))
	bp:beam(0.8, 1.8, -4.5, 0.8, 1, -8, 0.3, o(wood, "detail", { col = false }))
	if cover then
		for k = -1, 1 do
			bp:rbox(
				5.4,
				0.2,
				2.4,
				0,
				5,
				k * 2.8,
				0,
				0,
				k * 6,
				o(if burnt then Kit.rag else Kit.cloth, "detail", { col = false })
			)
		end
		Kit.claws(bp, 2.75, 4.2, 0, 1.4)
	end
	bp:pop()
end

-- Tent of patched cloth on poles (torn).
function Props.rag(bp: BP, x: number, y: number, z: number, yaw: number, sw: Swatch)
	bp:rbox(0.1, 2.2, 1.4, x, y, z, 0, yaw, 6, o(sw, "fine", { tag = "flag" }))
end

-- Palm: a leaning trunk of rings and a crown of drooping fronds (`dead`: dry grey-brown fronds, some broken).
function Props.palm(bp: BP, x: number, y: number, z: number, s: number, dead: boolean, big: boolean?)
	local rng = bp.rng
	local lean = rng:float(6, 16)
	local yaw = rng:float(0, 360)
	local trunkLod = (if big == false then "detail" else "shell") :: any
	bp:push(x, y, z, 0, yaw, 0)
	local h = 13 * s
	bp:rbox(
		1.1 * s,
		h,
		1.1 * s,
		0,
		h / 2 - 0.4,
		h * math.sin(math.rad(lean)) / 2,
		lean,
		0,
		0,
		o(Kit.deadBark, trunkLod, { q = false })
	)
	local tx, ty, tz = 0, h - 0.6, h * math.sin(math.rad(lean))
	local frond = if dead then { c = "#7A6A50", m = "Grass" } else { c = "#556B2F", m = "LeafyGrass" }
	for i = 0, 6 do
		local a = i * 360 / 7 + rng:float(-10, 10)
		local droop = rng:float(30, 60) + (if dead then 25 else 0)
		bp:push(tx, ty, tz, 0, a, 0)
		bp:rbox(
			0.55 * s,
			0.15,
			5.5 * s,
			0,
			-1.2 * s,
			-2.6 * s,
			-droop,
			0,
			0,
			o(frond, "detail", { col = false, q = false })
		)
		bp:pop()
	end
	bp:pop()
end

-- Traces --------------------------------------------------------------------------------------------------------

-- Scorpion burrow: a ring of thrown-out sand round a dark hole, a shed carapace beside it.
function Props.burrow(bp: BP, x: number, y: number, z: number)
	local rng = bp.rng
	for k = 0, 5 do
		local a = k * math.pi / 3 + rng:float(-0.3, 0.3)
		bp:add(
			"ball",
			2.4,
			0.9,
			1.8,
			x + math.cos(a) * 2,
			y + 0.1,
			z + math.sin(a) * 2,
			0,
			math.deg(-a),
			0,
			o({ c = "#C8A878", m = "Sand" }, "detail", { col = false })
		)
	end
	bp:add("cyl", 0.2, 2, 2, x, y + 0.05, z, 0, 0, 90, o(Kit.dark, "detail", { col = false }))
	Props.husk(bp, x + 3.4, y, z - 1.2, rng:float(0, 360))
end

-- Shed scorpion carapace (fine): segmented shell and a tail.
function Props.husk(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y + 0.2, z, 0, yaw, 0)
	bp:add("ball", 1.6, 0.5, 2.2, 0, 0, 0, 0, 0, 0, o(Props.carapace, "fine", { t = 0.15 }))
	for k = 1, 3 do
		bp:add("ball", 0.7, 0.4, 0.8, 0, 0.1 + k * 0.25, 1 + k * 0.7, 0, 0, 0, o(Props.carapace, "fine", { t = 0.15 }))
	end
	bp:pop()
end

-- Heap of glowing coal (ember tag: flicker and sparks on the client) with a warm light.
function Props.embers(bp: BP, x: number, y: number, z: number, r: number, light: boolean?)
	bp:add("ball", r * 2, r * 0.7, r * 2, x, y + 0.1, z, 0, 0, 0, o(Kit.charred, "detail", { col = false }))
	bp:add(
		"ball",
		r * 1.4,
		r * 0.45,
		r * 1.4,
		x,
		y + 0.3,
		z,
		0,
		0,
		0,
		{ c = Props.EMBER, m = "Neon", lod = "detail", col = false, t = 0.25, tag = "ember", jitter = 0 }
	)
	if light then
		bp:light(x, y + 2, z, Props.EMBER, 14, 0.9, "fire")
	end
end

-- Soot or scorch mark on a wall plane facing -Z at (x, y, z) (fine).
function Props.scorch(bp: BP, x: number, y: number, z: number, w: number, h: number)
	bp:box(w, h, 0.08, x, y, z, o(Props.soot, "fine", { t = 0.15 }))
end

return Props
