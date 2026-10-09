--!strict
-- Small and middle props of the Frost Peaks (S47) shared by its modules: the palette of the region and of its
-- monsters (Data/MonsterLooks), icicles, snow caps, crystals (glow), blocks of ice with things locked inside, frozen
-- banners, giant and dragon statues, mammoth skeletons, rune menhirs, braziers of blue fire, footprints and tufts of
-- fur. All draw into a Blueprint in its current frame (front = -Z). Pure.

local Kit = require("../WorldGen/Kit")

local o = Kit.o

local Props = {}

type BP = Kit.BP
type Swatch = Kit.Swatch
type Ground = (lx: number, lz: number) -> number

-- Palette ---------------------------------------------------------------------------------------------------------

Props.snow = { c = "#EEF3F7", m = "Snow" }
Props.rime = { c = "#D6E2EA", m = "Snow" }
Props.ice = { c = "#BFE6F7", m = "Ice" }
Props.glacier = { c = "#A8D8F0", m = "Glacier" }
Props.slate = { c = "#4A4744", m = "Slate" }
Props.frostStone = { c = "#8E9CA8", m = "Slate" } -- grey-blue stone of statues and walls
Props.paleStone = { c = "#B4C0C8", m = "Slate" }
Props.darkStone = { c = "#3E434A", m = "Slate" }
Props.frozenWood = { c = "#5E5650", m = "Wood" }
Props.oldWood = { c = "#4A3E34", m = "Wood" }
Props.hide = { c = "#7A6450", m = "Fabric" }
Props.paleHide = { c = "#B8A68C", m = "Fabric" }
Props.wolfFur = { c = "#C8DDEB", m = "Fabric" } -- ice wolf
Props.leopardFur = { c = "#E8E4DA", m = "Fabric" } -- snow leopard
Props.yetiFur = { c = "#E4EAF0", m = "Fabric" }
Props.harpyFeather = { c = "#8A9AB0", m = "Fabric" }
Props.mammothFur = { c = "#7A6A5A", m = "Fabric" }
Props.tusk = { c = "#E4F0F7", m = "SmoothPlastic" }
Props.orderDark = { c = "#2F3A4A", m = "Fabric" } -- the order of the Ice Watch
Props.orderPale = { c = "#9FB6C9", m = "Fabric" }
Props.cultBlue = { c = "#3A4A6B", m = "Fabric" } -- dragonspawn cult
Props.gold = { c = "#C9A45C", m = "Metal" }
Props.iron = { c = "#4A4E56", m = "CorrodedMetal" }
Props.wyrmScale = { c = "#7FD4FF", m = "SmoothPlastic" }
Props.dragonScale = { c = "#3A4A6B", m = "SmoothPlastic" }
Props.trackColor = { c = "#AFC0CC", m = "Snow" }

Props.CRYSTAL = "#CFF6FF" -- ice elementals' crystals (glow)
Props.RUNE = "#9FE0FF" -- the giants' runes
Props.ICEFIRE = "#6BC9FF" -- blue fire of the temple and the Ice Watch
Props.EYES = "#6BC9FF" -- frozen knights' eyes, the loopholes at night
Props.HARPY = "#E8E25A"

-- Small helpers --------------------------------------------------------------------------------------------------

-- A row of icicles hanging from y along local X (centre x, z), up to `len` studs long.
function Props.icicles(bp: BP, x: number, y: number, z: number, w: number, n: number, len: number, lod: any?)
	local rng = bp.rng
	for i = 1, n do
		local lx = x - w / 2 + (i - 0.5) * w / n + rng:float(-0.3, 0.3)
		local l = len * rng:float(0.35, 1)
		local t = math.max(0.25, l * 0.16)
		bp:add(
			"wedge",
			t,
			l,
			t,
			lx,
			y - l / 2,
			z,
			180,
			rng:float(0, 90),
			0,
			o(Props.ice, lod or "fine", { col = false, t = 0.2 })
		)
	end
end

-- A cap of snow (flattened ball) on a surface at y.
function Props.snowCap(bp: BP, x: number, y: number, z: number, sx: number, sz: number, lod: any?)
	bp:add(
		"ball",
		sx,
		math.min(sx, sz) * 0.3 + 0.4,
		sz,
		x,
		y,
		z,
		0,
		0,
		0,
		o(Props.snow, lod or "detail", { col = false })
	)
end

-- A cluster of glowing ice crystals (glass shards with the "glow" tag) and, with `light`, a crystal light (LOD on the
-- client, Controllers/RegionLightController).
function Props.crystals(bp: BP, x: number, y: number, z: number, s: number, lod: any?, light: boolean?)
	local rng = bp.rng
	local n = rng:int(4, 6)
	for i = 1, n do
		local a = i * (2 * math.pi / n) + rng:float(-0.3, 0.3)
		local d = if i == 1 then 0 else rng:float(0.8, 2) * s
		local h = (if i == 1 then 7 else rng:float(2.6, 5)) * s
		local w = (if i == 1 then 1.6 else rng:float(0.8, 1.2)) * s
		local tilt = if i == 1 then 0 else rng:float(14, 32)
		bp:push(x + math.cos(a) * d, y - 0.3, z + math.sin(a) * d, 0, math.deg(-a), tilt)
		local level = if i == 1 then lod or "shell" else "detail"
		bp:add("cyl", h, w, w, 0, h / 2, 0, 0, 0, 90, {
			c = "#9FE0FF",
			m = "Glass",
			lod = level,
			col = i == 1 and level == "shell",
			q = false,
			t = 0.25,
			tag = "glow",
			jitter = 0,
			fxColor = Props.CRYSTAL,
		})
		bp:add("wedge", w, w * 1.4, w, 0, h + w * 0.7, 0, 0, 0, 0, o(Props.ice, "detail", { col = false, t = 0.2 }))
		bp:pop()
	end
	if light then
		bp:light(x, y + 4 * s, z, Props.CRYSTAL, 18 + 4 * s, 1.2, "crystal")
	end
end

-- A block of clear ice standing out of the ice or snow with something locked inside it (chest, shield, sword,
-- coins, a gold vessel).
function Props.iceBlock(bp: BP, x: number, y: number, z: number, s: number, inner: string, yaw: number?)
	bp:push(x, y, z, 0, yaw or 0, 0)
	bp:rbox(5 * s, 4.4 * s, 4.4 * s, 0, 1.6 * s, 0, 6, 0, -4, o(Props.ice, "shell", { q = false, t = 0.45 }))
	local level: any = "detail"
	if inner == "chest" then
		bp:box(2.6 * s, 1.5 * s, 1.6 * s, 0, 1 * s, 0, o(Props.oldWood, level, { col = false }))
		bp:box(2.7 * s, 0.25 * s, 1.7 * s, 0, 1.8 * s, 0, o(Props.gold, level, { col = false }))
	elseif inner == "shield" then
		bp:add("cyl", 0.3 * s, 2.6 * s, 2.6 * s, 0, 1.8 * s, 0, 70, 0, 0, o(Props.orderPale, level, { col = false }))
		bp:add("cyl", 0.32 * s, 1 * s, 1 * s, 0, 1.8 * s, 0, 70, 0, 0, o(Props.gold, "fine", { col = false }))
	elseif inner == "sword" then
		bp:rbox(0.3 * s, 3.6 * s, 0.1 * s, 0, 1.8 * s, 0, 0, 30, 70, o(Props.iron, level, { col = false }))
		bp:rbox(1.2 * s, 0.25 * s, 0.25 * s, -1.3 * s, 2.4 * s, 0, 0, 30, 70, o(Props.gold, "fine", { col = false }))
	elseif inner == "vessel" then
		bp:add("ball", 1.4 * s, 1.8 * s, 1.4 * s, 0, 1.4 * s, 0, 0, 0, 0, o(Props.gold, level, { col = false }))
		bp:add("cyl", 0.6 * s, 0.9 * s, 0.9 * s, 0, 2.4 * s, 0, 0, 0, 90, o(Props.gold, "fine", { col = false }))
	else
		for k = 1, 6 do
			bp:add(
				"cyl",
				0.12 * s,
				0.6 * s,
				0.6 * s,
				(k % 3 - 1) * 0.5 * s,
				0.4 * s + k * 0.12 * s,
				(k // 3) * 0.4 * s,
				0,
				0,
				90,
				o(Props.gold, "fine", { col = false })
			)
		end
	end
	bp:pop()
end

-- A banner on a pole: `frozen` = stiff in mid-flap with icicles (no flag tag), else it flaps (flag tag).
function Props.banner(
	bp: BP,
	x: number,
	y: number,
	z: number,
	h: number,
	cloth: Swatch,
	trim: Swatch,
	frozen: boolean,
	lod: any?
)
	local l = lod or "detail"
	bp:box(0.4, h, 0.4, x, y + h / 2, z, o(Props.iron, l, { col = false }))
	bp:box(3.2, 0.25, 0.25, x + 1.4, y + h - 0.3, z, o(Props.iron, l, { col = false }))
	if frozen then
		bp:rbox(2.8, 4.6, 0.2, x + 1.6, y + h - 2.8, z - 0.3, 0, 18, 6, o(cloth, l, { col = false }))
		bp:rbox(2.8, 0.5, 0.22, x + 1.8, y + h - 5.1, z - 0.4, 0, 18, 6, o(trim, "fine", { col = false }))
		Props.icicles(bp, x + 1.6, y + h - 5.3, z - 0.4, 2.6, 4, 1.4)
		Props.snowCap(bp, x + 1.4, y + h - 0.05, z, 3.2, 0.8, "fine")
	else
		bp:box(
			2.8,
			4.6,
			0.15,
			x + 1.6,
			y + h - 2.8,
			z,
			{ c = cloth.c, m = cloth.m, lod = l, col = false, tag = "flag" }
		)
		bp:box(2.8, 0.5, 0.17, x + 1.6, y + h - 5.1, z, o(trim, "fine", { col = false }))
	end
end

-- Brazier of blue (or other) fire on an iron tripod.
function Props.brazier(bp: BP, x: number, y: number, z: number, color: string?, lod: any?)
	local l = lod or "detail"
	for k = 0, 2 do
		bp:rbox(
			0.3,
			3.2,
			0.3,
			x + math.cos(k * 2.1) * 0.8,
			y + 1.4,
			z + math.sin(k * 2.1) * 0.8,
			0,
			k * 120,
			14,
			o(Props.iron, l, { col = false })
		)
	end
	bp:add("cyl", 1, 2.2, 2.2, x, y + 3.2, z, 0, 0, 90, o(Props.iron, l, { col = false }))
	Kit.fire(bp, x, y + 3.8, z, 1.3, color or Props.ICEFIRE, l)
end

-- Wall torch of blue fire at (x, y, z) facing -Z.
function Props.torch(bp: BP, x: number, y: number, z: number, color: string?)
	bp:rbox(0.3, 1.8, 0.3, x, y, z - 0.4, 25, 0, 0, o(Props.iron, "detail", { col = false }))
	Kit.fire(bp, x, y + 1, z - 0.9, 0.6, color or Props.ICEFIRE, "detail")
end

-- Footprints in the snow from (x, z) towards local yaw `yaw` (degrees, 0 = -Z): `n` prints `step` studs apart.
function Props.tracks(bp: BP, ground: Ground, x: number, z: number, yaw: number, n: number, size: number, step: number)
	local a = math.rad(yaw)
	local dx, dz = -math.sin(a), -math.cos(a)
	for i = 0, n - 1 do
		local side = if i % 2 == 0 then 1 else -1
		local px = x + dx * step * i + dz * side * size * 0.6
		local pz = z + dz * step * i - dx * side * size * 0.6
		bp:rbox(
			size * 0.7,
			0.08,
			size,
			px,
			ground(px, pz) + 0.06,
			pz,
			0,
			yaw,
			0,
			o(Props.trackColor, "fine", { col = false })
		)
	end
end

-- Tuft of fur caught on a bush or a rock.
function Props.fur(bp: BP, x: number, y: number, z: number, sw: Swatch)
	bp:add("ball", 0.9, 0.5, 0.7, x, y, z, 0, bp.rng:float(0, 180), 0, o(sw, "fine", { col = false }))
end

-- Boulder of frosted stone with a snow cap (shell collides).
function Props.boulder(bp: BP, x: number, y: number, z: number, s: number, lod: any?)
	Kit.rock(bp, x, y - 0.4, z, s, Props.frostStone, lod or "shell")
	Props.snowCap(bp, x, y + s * 0.62, z, s * 1.1, s * 0.9, "detail")
end

-- Statues and bones -------------------------------------------------------------------------------------------------

-- A seated giant carved in stone, facing -Z (s = 1: ~22 studs tall): plinth, legs, hands on knees, a bearded head
-- (`headless` = the head is gone). Rimed with frost.
function Props.giantStatue(bp: BP, x: number, y: number, z: number, s: number, yaw: number, headless: boolean?)
	local st = Props.frostStone
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(14 * s, 4 * s, 14 * s, 0, 1.6 * s, 0, o(st, "shell", { q = false }))
	bp:box(16 * s, 10, 16 * s, 0, -5, 0, o(Props.darkStone, "shell", { q = false })) -- footing into the slope
	-- throne back and seat
	bp:box(12 * s, 18 * s, 3 * s, 0, 12 * s, 5 * s, o(st, "shell", { q = false }))
	bp:box(12 * s, 3 * s, 9 * s, 0, 5 * s, 1 * s, o(st, "shell", { q = false }))
	for _, side in { -1, 1 } do
		-- shins, thighs, arms resting on the knees, fists
		bp:box(3.2 * s, 7 * s, 3.2 * s, side * 3 * s, 3.5 * s, -3.6 * s, o(st, "shell", { q = false }))
		bp:box(3.6 * s, 3.2 * s, 8 * s, side * 3 * s, 7.6 * s, -0.4 * s, o(st, "detail", { col = false }))
		bp:rbox(
			2.6 * s,
			8 * s,
			2.6 * s,
			side * 5.6 * s,
			12 * s,
			-0.2 * s,
			-40,
			0,
			side * 6,
			o(st, "detail", { col = false })
		)
		bp:add(
			"ball",
			3 * s,
			2.6 * s,
			3 * s,
			side * 4.4 * s,
			8.6 * s,
			-3.4 * s,
			0,
			0,
			0,
			o(st, "detail", { col = false })
		)
	end
	-- torso
	bp:box(9 * s, 10 * s, 5 * s, 0, 13 * s, 1.6 * s, o(st, "shell", { q = false }))
	if not headless then
		bp:add("ball", 5 * s, 6 * s, 5 * s, 0, 21 * s, 1 * s, 0, 0, 0, o(st, "shell", { q = false }))
		bp:rbox(4 * s, 5 * s, 2 * s, 0, 17.6 * s, -1.2 * s, 10, 0, 0, o(st, "detail", { col = false })) -- beard
		for _, side in { -1, 1 } do
			bp:box(0.9 * s, 0.6 * s, 0.3, side * 1.1 * s, 21.6 * s, -1.5 * s, o(Kit.dark, "fine", { col = false }))
		end
		Props.snowCap(bp, 0, 24 * s, 1 * s, 4 * s, 4 * s)
	else
		bp:box(5 * s, 1 * s, 4 * s, 0, 18.4 * s, 1.4 * s, o(Props.paleStone, "detail", { col = false }))
	end
	Props.snowCap(bp, 0, 21.2 * s, 5 * s, 12 * s, 3 * s)
	for _, side in { -1, 1 } do
		Props.snowCap(bp, side * 3 * s, 9.4 * s, -1 * s, 3.6 * s, 7 * s)
	end
	Props.icicles(bp, 0, 3.6 * s, -7.1 * s, 12 * s, 9, 2.4 * s)
	bp:pop()
end

-- A dragon statue on a plinth, facing -Z (s = 1: ~14 studs long): crouched body, raised neck and horned head, folded
-- (or with `spread`, outspread) wings; eyes glow at night ("glow").
function Props.dragonStatue(
	bp: BP,
	x: number,
	y: number,
	z: number,
	s: number,
	yaw: number,
	spread: boolean?,
	lod: any?
)
	local st = Props.frostStone
	local l = lod or "shell"
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(6 * s, 2 * s, 12 * s, 0, 1 * s, 0, o(st, l, { q = false }))
	bp:add("ball", 5 * s, 4.4 * s, 9 * s, 0, 4.4 * s, 1 * s, 0, 0, 0, o(st, l, { q = false }))
	bp:rbox(2.4 * s, 7 * s, 2.4 * s, 0, 8 * s, -3.2 * s, -24, 0, 0, o(st, "detail", { col = false }))
	bp:add("ball", 2.6 * s, 2.4 * s, 4.4 * s, 0, 11.2 * s, -5.6 * s, 0, 0, 0, o(st, "detail", { col = false }))
	bp:rbox(1.8 * s, 1 * s, 3 * s, 0, 10.4 * s, -7.6 * s, 8, 0, 0, o(st, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:rbox(
			0.5 * s,
			3 * s,
			0.5 * s,
			side * 0.9 * s,
			13 * s,
			-4.4 * s,
			-30,
			0,
			side * 18,
			o(st, "fine", { col = false })
		)
		bp:box(0.5 * s, 0.4 * s, 0.3, side * 0.8 * s, 11.6 * s, -7.7 * s, {
			c = Props.EYES,
			m = "Neon",
			lod = "detail",
			col = false,
			tag = "glow",
			jitter = 0,
			fxColor = Props.EYES,
		})
		if spread then
			bp:rbox(
				12 * s,
				0.6 * s,
				7 * s,
				side * 8 * s,
				9 * s,
				2 * s,
				0,
				side * -10,
				side * 28,
				o(st, "detail", { col = false })
			)
		else
			bp:rbox(
				1 * s,
				6 * s,
				8 * s,
				side * 2.8 * s,
				6.4 * s,
				2 * s,
				0,
				0,
				side * 12,
				o(st, "detail", { col = false })
			)
		end
		-- front claws
		bp:box(1.4 * s, 3 * s, 1.6 * s, side * 1.8 * s, 2.8 * s, -3.6 * s, o(st, "detail", { col = false }))
	end
	bp:rbox(1.6 * s, 1.6 * s, 7 * s, 1.2 * s, 2.6 * s, 7.4 * s, 0, 24, 0, o(st, "detail", { col = false })) -- tail
	Props.snowCap(bp, 0, 6.6 * s, 2 * s, 4 * s, 7 * s)
	bp:pop()
end

-- A mammoth skeleton lying on the snow along local Z (s = 1: ~16 studs long), head at -Z: skull, tusks curving up
-- and in (crossing over a road when big), ribs, spine, leg bones. `ground` gives the ground in the Build's frame.
function Props.mammothSkeleton(bp: BP, ground: Ground, x: number, z: number, s: number, yaw: number, lod: any?)
	local l = lod or "detail"
	local a = math.rad(yaw)
	local function at(lx: number, lz: number): (number, number)
		return x + math.cos(a) * lx + math.sin(a) * lz, z - math.sin(a) * lx + math.cos(a) * lz
	end
	bp:push(x, ground(x, z), z, 0, yaw, 0)
	local function gy(lx: number, lz: number): number
		local wx, wz = at(lx, lz)
		return ground(wx, wz) - ground(x, z)
	end
	-- spine
	for k = 0, 7 do
		local lz = -4 * s + k * 1.6 * s
		bp:add(
			"ball",
			1.2 * s,
			1 * s,
			1.4 * s,
			0,
			gy(0, lz) + 3.6 * s - k * 0.12 * s,
			lz,
			0,
			0,
			0,
			o(Kit.oldBone, if k % 3 == 0 then l else "fine", { col = false })
		)
	end
	-- ribs: arcs down both sides
	for k = 0, 5 do
		local lz = -3 * s + k * 1.6 * s
		for _, side in { -1, 1 } do
			bp:beam(
				0,
				gy(0, lz) + 3.6 * s,
				lz,
				side * 2.6 * s,
				gy(side * 2.6 * s, lz) + 2.2 * s,
				lz,
				0.35 * s,
				o(Kit.bone, l, { col = false })
			)
			bp:beam(
				side * 2.6 * s,
				gy(side * 2.6 * s, lz) + 2.2 * s,
				lz,
				side * 2.2 * s,
				gy(side * 2.2 * s, lz) + 0.2,
				lz + 0.4 * s,
				0.3 * s,
				o(Kit.bone, "fine", { col = false })
			)
		end
	end
	-- skull and tusks
	bp:add(
		"ball",
		3.4 * s,
		3.6 * s,
		3.4 * s,
		0,
		gy(0, -6 * s) + 2.2 * s,
		-6 * s,
		0,
		0,
		0,
		o(Kit.oldBone, l, { col = false })
	)
	for _, side in { -1, 1 } do
		local px, py, pz = side * 1.2 * s, gy(0, -7 * s) + 1.6 * s, -7.4 * s
		local mx, my, mz = side * 2.6 * s, py + 1.8 * s, -10.6 * s
		local tx, ty, tz = side * -0.6 * s, py + 5.4 * s, -12.4 * s
		bp:beam(px, py, pz, mx, my, mz, 0.7 * s, o(Props.tusk, l, { col = false }))
		bp:beam(mx, my, mz, tx, ty, tz, 0.55 * s, o(Props.tusk, l, { col = false }))
	end
	-- scattered leg bones
	for k = 1, 3 do
		local lx, lz = (k - 2) * 2.4 * s, 6 * s + k * 0.8 * s
		bp:rbox(
			0.6 * s,
			0.6 * s,
			4 * s,
			lx,
			gy(lx, lz) + 0.3 * s,
			lz,
			0,
			k * 40,
			0,
			o(Kit.oldBone, "fine", { col = false })
		)
	end
	bp:pop()
end

-- A standing stone with a glowing rune (the giants' rune stones; "glow" breathes at night).
function Props.runeStone(bp: BP, x: number, y: number, z: number, h: number, yaw: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:rbox(2.6, h, 1.8, 0, h / 2 - 0.6, 0, 3, 0, -2, o(Props.frostStone, "shell", { q = false }))
	bp:box(1.2, 1.6, 0.12, 0, h * 0.6, -0.95, {
		c = Props.RUNE,
		m = "Neon",
		lod = "detail",
		col = false,
		tag = "glow",
		jitter = 0,
		fxColor = Props.RUNE,
	})
	bp:light(0, h * 0.6, -1.6, Props.RUNE, 12, 0.8, "crystal")
	Props.snowCap(bp, 0, h - 0.4, 0, 2.6, 1.8, "fine")
	bp:pop()
end

-- A tent of hides on a frame of bones / poles (giants' and hunters' camps), facing -Z.
function Props.hideTent(bp: BP, x: number, y: number, z: number, s: number, yaw: number, bone: boolean)
	bp:push(x, y, z, 0, yaw, 0)
	local pole = if bone then Kit.oldBone else Props.oldWood
	for _, side in { -1, 1 } do
		bp:rbox(
			0.5 * s,
			9 * s,
			0.5 * s,
			side * 2.6 * s,
			3.8 * s,
			-3 * s,
			0,
			0,
			side * -30,
			o(pole, "detail", { col = false })
		)
		bp:rbox(
			0.5 * s,
			9 * s,
			0.5 * s,
			side * 2.6 * s,
			3.8 * s,
			3 * s,
			0,
			0,
			side * -30,
			o(pole, "detail", { col = false })
		)
		bp:rbox(
			0.3 * s,
			6 * s,
			7 * s,
			side * 2.2 * s,
			2.6 * s,
			0,
			0,
			0,
			side * -30,
			o(Props.hide, "shell", { q = false })
		)
	end
	bp:box(0.5 * s, 0.5 * s, 8 * s, 0, 7.6 * s, 0, o(pole, "detail", { col = false }))
	bp:box(4 * s, 5 * s, 0.25, 0, 2.6 * s, 3.4 * s, o(Props.paleHide, "detail", { col = false }))
	Props.snowCap(bp, 0, 6.8 * s, 0, 3 * s, 7 * s, "fine")
	bp:pop()
end

return Props
