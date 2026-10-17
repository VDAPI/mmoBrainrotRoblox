--!strict
-- S95 (DESIGN-15 §1, MIASTO.md §6): the class vendors' new buildings. The hunters' lodge (one timber storey with
-- antlers, hide racks, an archery target and a green banner) by the stable and the east gate, and the mages'
-- tower (slim stone tower with windows, a balcony, a conical roof and a glowing crystal) in the upper town. Built in
-- the local frame of the plan's footprint (front = local -Z, like every special). Specials passes its helpers in
-- `kit` (no require cycle). Pure.

local Blueprint = require("./Blueprint")
local Houses = require("./Houses")
local Palette = require("./Palette")
local Parts = require("./Parts")
local Structures = require("./Structures")
local TownGeom = require("../TownGeom")

type BP = Blueprint.Blueprint
type Build = Structures.Build
type Ground = Houses.Ground

export type Kit = {
	houseLike: (
		sp: any,
		ground: Ground,
		style: string,
		kind: string,
		floors: number
	) -> (BP, Houses.Placement, Houses.Info),
	seedOf: (id: string) -> number,
	lookFor: (bp: BP, stone: Palette.Swatch, roof: Palette.Swatch) -> Parts.Look,
	floorOf: (sp: any, ground: Ground, pad: number?) -> (number, number),
	banner: (bp: BP, x: number, y: number, z: number, w: number, h: number, colour: string) -> (),
	o: (s: Palette.Swatch, lod: Blueprint.Lod?, extra: { [string]: any }?) -> Blueprint.Options,
}

local ClassHalls = {}

local BONE = "#D8CBB0"
local HIDE = { "#8A6A44", "#6E5236" }
local HUNTER_GREEN = "#3E5A34"
local MAGE_BLUE = "#2E3A6B"
local CRYSTAL = "#8E7CC3"

-- x of the door leaf Houses put on the front wall (its round top: a 0.3-thick plank cylinder), else 0.
local function doorX(bp: BP, zf: number): number
	for _, p in bp.pieces do
		if p.s == "cyl" and math.abs(p.size[1] - 0.3) < 1e-6 and p.m == "WoodPlanks" and p.p[3] < zf + 0.5 then
			return p.p[1]
		end
	end
	return 0
end

-- Antlers mounted on a front wall facing -Z at z = zf: a skull plate and two branched beams, `s` = scale.
local function antlers(bp: BP, x: number, y: number, zf: number, s: number, lod: Blueprint.Lod)
	local bone = { c = BONE, m = "SmoothPlastic", lod = lod }
	local z = zf - 0.5
	bp:box(0.7 * s, 0.9 * s, 0.4, x, y, z, { c = "#5A4634", m = "Wood", lod = lod })
	for _, side in { -1, 1 } do
		local ax, ay = x + side * 0.25 * s, y + 0.3 * s
		local bx, by = x + side * 1.25 * s, y + 1.2 * s
		bp:beam(ax, ay, z - 0.15, bx, by, z - 0.15, 0.22 * s, bone)
		-- two tines up from the main beam
		bp:beam(x + side * 0.7 * s, y + 0.7 * s, z - 0.15, x + side * 0.55 * s, y + 1.5 * s, z - 0.15, 0.16 * s, bone)
		bp:beam(bx, by, z - 0.15, bx + side * 0.15 * s, by + 0.6 * s, z - 0.15, 0.16 * s, bone)
	end
end

-- Drying rack along local Z (two posts, a top bar) with hides hanging from it, slightly tilted.
local function hideRack(bp: BP, x: number, z: number, len: number, hides: number)
	local wood = Palette.timber[1]
	bp:box(0.35, 3.4, 0.35, x, 1.7, z - len / 2, Parts.o(wood))
	bp:box(0.35, 3.4, 0.35, x, 1.7, z + len / 2, Parts.o(wood))
	bp:box(0.3, 0.3, len + 0.6, x, 3.3, z, Parts.o(wood))
	for i = 1, hides do
		local hz = z - len / 2 + (i - 0.5) * len / hides
		local colour = HIDE[(i - 1) % #HIDE + 1]
		bp:rbox(0.12, 2.2, len / hides - 0.3, x + 0.15, 2.1, hz, 0, 0, 8, { c = colour, m = "Fabric", lod = "detail" })
	end
end

-- Archery target on a two-legged stand (the training yard's, Gardens), facing local -Z.
local function archeryTarget(bp: BP, x: number, z: number)
	bp:push(x, 0, z, 0, 0, 0)
	bp:beam(0.8, 0, 0.6, 0, 3.6, 0, 0.3, Parts.o(Palette.timber[1]))
	bp:beam(-0.8, 0, 0.6, 0, 3.6, 0, 0.3, Parts.o(Palette.timber[1]))
	bp:add("cyl", 0.5, 3.4, 3.4, 0, 3.2, -0.3, 0, 90, 0, { c = "#C8B890", m = "Fabric", lod = "detail" })
	bp:add("cyl", 0.55, 2.2, 2.2, 0, 3.2, -0.32, 0, 90, 0, { c = "#8A2A22", m = "Fabric", lod = "detail" })
	bp:add("cyl", 0.6, 0.9, 0.9, 0, 3.2, -0.34, 0, 90, 0, { c = "#E0C050", m = "Fabric", lod = "fine" })
	bp:pop()
end

-- Leather quiver leaning on the wall with three arrows.
local function quiver(bp: BP, x: number, z: number)
	bp:rbox(0.7, 2, 0.7, x, 1, z, 10, 0, 0, { c = "#6E5236", m = "Fabric", lod = "fine" })
	for i = -1, 1 do
		bp:rbox(0.12, 1.2, 0.12, x + i * 0.18, 2.4, z - 0.15, 10, 0, 0, { c = "#C8B890", m = "Wood", lod = "fine" })
	end
end

-- Hunters' lodge (26 x 16): a one-storey timber house of the craft quarter with its trimmings.
function ClassHalls.hunterLodge(sp: any, ground: Ground, kit: Kit): Build
	local bp, at, info = kit.houseLike(sp, ground, "craft", "workshopHouse", 1)
	local zf = info.zFront
	local G = info.ground
	local left = info.bodyX - info.bodyW / 2
	local right = info.bodyX + info.bodyW / 2
	local dx = doorX(bp, zf)
	-- antlers: a big pair over the door, two smaller ones by the corners
	-- (the tips stay under the eaves: wall top G)
	antlers(bp, dx, G - 1.7, zf, 1, "detail")
	antlers(bp, left + 2, G - 2.9, zf, 0.75, "detail")
	antlers(bp, right - 2, G - 2.9, zf, 0.75, "detail")
	kit.banner(bp, dx + 4.4, G - 3.6, zf - 0.2, 2.2, 3.4, HUNTER_GREEN)
	-- archery target and a quiver at the left corner, facing the square
	archeryTarget(bp, left + 1.8, zf - 1.8)
	quiver(bp, left + 4, zf - 0.8)
	-- the yard by the right wall: two racks of drying hides and a woodpile
	local yard = sp.w / 2 - right
	if yard >= 2.5 then
		hideRack(bp, right + yard * 0.35, -1.5, 5, 2)
		hideRack(bp, right + yard * 0.75, -1.5, 5, 2)
		Parts.woodpile(bp, right + yard / 2, 0, sp.d / 2 - 1.6, 0, math.min(3.6, yard - 0.6))
	else
		hideRack(bp, right - 1.5, zf - 1.2, 4, 2)
	end
	-- barrels and crates beside the door
	Parts.barrel(bp, dx + 3, 0, zf - 1.4)
	Parts.barrel(bp, dx + 5.2, 0, zf - 1.4)
	Parts.crate(bp, dx + 7.2, 0, zf - 1.2, 1.5)
	Parts.crate(bp, dx + 7.2, 1.5, zf - 1.2, 1.1)
	return { name = sp.id, bp = bp, at = at, tag = "special" }
end

-- Mages' tower (14 x 14): a slim stone shaft on a rubble plinth, windows in rows, a balcony at two thirds, a cone
-- of slate rings and a breathing crystal on top; two glowing crystals flank the door.
function ClassHalls.mageTower(sp: any, ground: Ground, kit: Kit): Build
	local bp = Blueprint.new(kit.seedOf(sp.id))
	local o = kit.o
	local y0, lo = kit.floorOf(sp, ground)
	local stone = Palette.ashlar[2]
	local rubble = Palette.rubble[1]
	local look = kit.lookFor(bp, stone, Palette.slateRoof[1])
	local R, H = 5.5, 30
	local below = y0 - lo + 1.5
	local function vcyl(h: number, d: number, y: number, opts: Blueprint.Options)
		bp:add("cyl", h, d, d, 0, y, 0, 0, 0, 90, opts)
	end
	-- plinth (reaching below the lowest ground) and the shaft
	vcyl(2 + below, 13, (2 - below) / 2, o(rubble, "shell", { q = true }))
	-- W12: the shaft, windows, balcony, roof and crystal are one asset kit slot (Data/Kit "landmark:mageTower": the
	-- painted tower model); the plinth, the door, the steps and the crystals at the foot stay
	bp:beginKit("landmark:mageTower", 0, 2, 0, 1, "shell")
	vcyl(H, R * 2, H / 2, o(stone, "shell", { q = true }))
	vcyl(0.6, R * 2 + 0.6, 12, o(Palette.ashlar[4], "detail"))
	-- windows: three rows of four, turned away from the door
	for row, y in { 9, 16, 24 } do
		for i = 0, 3 do
			bp:push(0, 0, 0, 0, 45 + i * 90 + (row % 2) * 20, 0)
			bp:box(0.9, 2.4, 0.3, 0, y, -R - 0.02, o(Palette.glass, "detail", { tag = "window", jitter = 0 }))
			bp:box(1.5, 0.35, 0.6, 0, y - 1.35, -R - 0.15, o(stone))
			bp:pop()
		end
	end
	-- balcony at two thirds of the height: a ring floor, eight posts and the rails between them
	local by = 20
	vcyl(0.6, 13, by, o(stone, "shell", { q = true }))
	local posts = 8
	for i = 0, posts - 1 do
		local a1, a2 = math.rad(i * 360 / posts), math.rad((i + 1) * 360 / posts)
		local px, pz = math.sin(a1) * 6.1, math.cos(a1) * 6.1
		bp:box(0.35, 1.6, 0.35, px, by + 1.1, pz, o(Palette.metal[1]))
		bp:beam(px, by + 1.8, pz, math.sin(a2) * 6.1, by + 1.8, math.cos(a2) * 6.1, 0.2, o(Palette.metal[1]))
	end
	-- balcony door
	bp:box(1.6, 2.8, 0.3, 0, by + 1.7, R + 0.02, o(look.door))
	-- eaves and the cone roof of slate rings (about 8 studs)
	vcyl(0.8, R * 2 + 1.2, H + 0.4, o(Palette.slate[1]))
	local diameters = { 12.4, 10, 7.6, 5.2, 2.8 }
	for i, d in diameters do
		vcyl(1.6, d, H + 0.8 + (i - 0.5) * 1.6, o(Palette.slateRoof[1], "shell"))
	end
	local top = H + 0.8 + #diameters * 1.6
	-- the spire and the crystal: a cube on its corner (a rhomb), Neon, breathing (TownFxController "glow")
	bp:add("cyl", 2.2, 0.4, 0.4, 0, top + 1.1, 0, 0, 0, 90, o(Palette.metal[1]))
	bp:rbox(1.7, 1.7, 1.7, 0, top + 3.2, 0, 45, 0, 35.26, { c = CRYSTAL, m = "Neon", lod = "detail", tag = "glow" })
	bp:rbox(1, 1, 1, 0, top + 4.6, 0, 45, 0, 35.26, { c = "#B8A8F0", m = "Neon", lod = "fine", tag = "glow" })
	bp:endKit()
	bp:light(0, top + 2, 0, "#A08CFF", 24, 1.2, "glow")
	-- the door on the front (local -Z) standing on the plinth top (y = 2), its stone portal, the banner, the steps
	-- down over the plinth edge and two glowing crystals on pedestals at the plinth's foot
	local fx, fz = TownGeom.front(sp.rot)
	local drop = y0 - ground(sp.x + fx * (sp.d / 2 + 1), sp.z + fz * (sp.d / 2 + 1))
	bp:push(0, 2, 0, 0, 0, 0)
	bp:box(4.6, 7.6, 1.4, 0, 3.8, -R + 0.3, o(stone, "shell", { q = true }))
	Parts.door(bp, look, 0, -R - 0.4, 3.2, 6.4, stone)
	Parts.steps(bp, look, 0, -R - 0.4, 4, drop + 2)
	kit.banner(bp, 0, 9.6, -R - 0.55, 2.2, 3.2, MAGE_BLUE)
	bp:pop()
	for _, side in { -1, 1 } do
		bp:box(0.9, 1.2, 0.9, side * 2.9, 0.6, -R - 1, o(stone))
		bp:rbox(
			0.6,
			0.6,
			0.6,
			side * 2.9,
			1.7,
			-R - 1,
			45,
			0,
			35.26,
			{ c = CRYSTAL, m = "Neon", lod = "detail", tag = "glow" }
		)
	end
	bp:light(0, 2.5, -R - 1.5, "#A08CFF", 10, 0.6, "glow")
	return { name = sp.id, bp = bp, at = { x = sp.x, y = y0, z = sp.z, rot = sp.rot }, tag = "special" }
end

return ClassHalls
