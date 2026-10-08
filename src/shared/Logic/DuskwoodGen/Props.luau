--!strict
-- Small props of Duskwood (S45) shared by its modules: monster traces (paw prints, fur, claw-marked stumps,
-- three-toed prints), camp clutter (crates, sacks, coins, bedrolls, racks), cult and witch trinkets (rags,
-- amulets, bone chimes, straw dolls, skull candles), a domed hut and a cauldron. All draw into a Blueprint in its
-- current frame; most are client detail. Pure.

local Kit = require("../WorldGen/Kit")
local Parts = require("../TownGen/Parts")

local o = Kit.o

local Props = {}

type BP = Kit.BP

-- Paw prints (fine): four pads and a palm, dark and wet, along local -Z from (x, y, z).
function Props.paw(bp: BP, x: number, y: number, z: number, yaw: number, big: boolean?)
	local k = if big then 1.5 else 1
	bp:push(x, y + 0.05, z, 0, yaw, 0)
	bp:add("ball", 1.6 * k, 0.12, 1.4 * k, 0, 0, 0, 0, 0, 0, o({ c = "#241E18", m = "Mud" }, "fine"))
	for i = -1, 1 do
		bp:add(
			"ball",
			0.6 * k,
			0.1,
			0.7 * k,
			i * 0.7 * k,
			0,
			-1.3 * k,
			0,
			0,
			0,
			o({ c = "#241E18", m = "Mud" }, "fine")
		)
	end
	bp:pop()
end

-- Three-toed troll print (fine).
function Props.trollPrint(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y + 0.05, z, 0, yaw, 0)
	bp:add("ball", 2.6, 0.14, 2.2, 0, 0, 0, 0, 0, 0, o({ c = "#2A2620", m = "Mud" }, "fine"))
	for i = -1, 1 do
		bp:rbox(0.8, 0.12, 2.2, i * 1.1, 0, -2, 0, i * 18, 0, o({ c = "#2A2620", m = "Mud" }, "fine"))
	end
	bp:pop()
end

-- Tuft of grey fur caught on thorns or roots (fine).
function Props.fur(bp: BP, x: number, y: number, z: number)
	bp:add("ball", 0.9, 0.5, 0.7, x, y, z, 0, bp.rng:float(0, 180), 0, o(Kit.fur, "fine", { col = false }))
end

-- Stump of a trunk scored by claws (shell trunk, fine marks): werewolf and bear trees.
function Props.clawedStump(bp: BP, x: number, y: number, z: number, h: number, yaw: number)
	bp:add("cyl", h, 2.2, 2.2, x, y + h / 2 - 0.4, z, 0, yaw, 90, o(Kit.darkBark, "shell", { q = false }))
	bp:push(x, y, z, 0, yaw, 0)
	Kit.claws(bp, 0, h * 0.6, -1.15, 1.2)
	Kit.claws(bp, 0.4, h * 0.35, -1.12, 0.9)
	bp:box(1.4, h * 0.3, 0.2, 0, h * 0.75, 1.05, o({ c = "#8A7458", m = "Wood" }, "fine")) -- bark rubbed off
	bp:pop()
	Props.fur(bp, x + 1.2, y + 1.4, z)
end

function Props.crate(bp: BP, x: number, y: number, z: number, s: number, yaw: number, lod: any?)
	bp:rbox(s, s, s, x, y + s / 2, z, 0, yaw, 0, o(Kit.planks, lod or "detail", { col = false }))
	bp:rbox(s + 0.1, 0.2, s * 0.2, x, y + s * 0.8, z, 0, yaw, 0, o(Kit.timber, "fine"))
end

function Props.sack(bp: BP, x: number, y: number, z: number, coins: boolean?)
	bp:add("ball", 1.8, 2, 1.8, x, y + 0.9, z, 0, 0, 0, o({ c = "#8A7656", m = "Fabric" }, "detail", { col = false }))
	if coins then
		Props.coins(bp, x + 1, y, z + 0.6, 5)
	end
end

-- A spill of coins (fine, gold glint).
function Props.coins(bp: BP, x: number, y: number, z: number, n: number)
	local rng = bp.rng
	for _ = 1, n do
		bp:add(
			"cyl",
			0.1,
			0.5,
			0.5,
			x + rng:float(-0.8, 0.8),
			y + 0.08,
			z + rng:float(-0.8, 0.8),
			0,
			0,
			rng:float(-10, 10),
			{ c = "#E8C04A", m = "Neon", lod = "fine", col = false, jitter = 0.05 }
		)
	end
end

function Props.bedroll(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:rbox(2, 0.4, 5, x, y + 0.2, z, 0, yaw, 0, o({ c = "#5A4A3A", m = "Fabric" }, "detail", { col = false }))
	bp:rbox(2, 0.9, 0.9, x, y + 0.45, z, 0, yaw, 0, o({ c = "#6E5A44", m = "Fabric" }, "fine"))
end

-- Drying rack with hides (or snake skins), along local X of a sub-frame.
function Props.rack(bp: BP, x: number, y: number, z: number, yaw: number, skin: Kit.Swatch, n: number)
	bp:push(x, y, z, 0, yaw, 0)
	for _, side in { -1, 1 } do
		bp:box(0.4, 4.5, 0.4, side * 3, 2.2, 0, o(Kit.timber, "detail", { col = false }))
	end
	bp:box(6.6, 0.3, 0.3, 0, 4.3, 0, o(Kit.timber, "detail", { col = false }))
	for i = 1, n do
		local lx = -3 + i * 6 / (n + 1)
		bp:rbox(1.4, 2.6, 0.15, lx, 2.9, 0, 0, 0, bp.rng:float(-6, 6), o(skin, "fine", { col = false }))
	end
	bp:pop()
end

-- Rag on a pole (cult violet, witch green), fluttering (flag tag).
function Props.ragPole(bp: BP, x: number, y: number, z: number, h: number, cloth: Kit.Swatch)
	bp:box(0.35, h, 0.35, x, y + h / 2, z, o(Kit.darkBark, "detail", { col = false }))
	bp:box(0.1, 1.8, 1.4, x, y + h - 1.2, z + 0.75, o(cloth, "detail", { col = false, tag = "flag" }))
end

-- Hanging amulet or bone chime (detail, swings like a flag) below (x, y, z).
function Props.charm(bp: BP, x: number, y: number, z: number, bones: boolean)
	bp:box(0.06, 1.6, 0.06, x, y - 0.8, z, o(Kit.rope, "fine"))
	if bones then
		for i = -1, 1 do
			bp:box(0.15, 1.1, 0.15, x + i * 0.3, y - 2, z, o(Kit.bone, "detail", { col = false, tag = "flag" }))
		end
	else
		bp:box(0.7, 0.9, 0.12, x, y - 2, z, o({ c = "#7A6A4A", m = "Wood" }, "detail", { col = false, tag = "flag" }))
		bp:box(0.3, 0.3, 0.14, x, y - 2, z - 0.02, o({ c = "#7CFF8A", m = "Neon" }, "fine"))
	end
end

-- Straw doll (detail).
function Props.doll(bp: BP, x: number, y: number, z: number)
	bp:box(0.5, 1.4, 0.4, x, y + 0.7, z, o(Kit.straw, "detail", { col = false }))
	bp:add("ball", 0.6, 0.6, 0.6, x, y + 1.6, z, 0, 0, 0, o(Kit.straw, "fine"))
	bp:box(1.4, 0.25, 0.25, x, y + 1.1, z, o(Kit.straw, "fine"))
end

-- Pole with a skull and a candle on top.
function Props.skullCandle(bp: BP, x: number, y: number, z: number, h: number, color: string?)
	bp:box(0.3, h, 0.3, x, y + h / 2, z, o(Kit.darkBark, "detail", { col = false }))
	Kit.skull(bp, x, y + h, z, 1, bp.rng:float(0, 360))
	Kit.candle(bp, x, y + h + 0.9, z, 0.5, color)
end

-- Domed hut of logs, moss and bones (trolls) at (x, y, z), entrance towards local -Z of a sub-frame.
function Props.domeHut(bp: BP, x: number, y: number, z: number, yaw: number, r: number)
	bp:push(x, y, z, 0, yaw, 0)
	bp:add("ball", r * 2, r * 1.3, r * 2, 0, 0, 0, 0, 0, 0, o({ c = "#4A3E30", m = "Wood" }, "shell", { q = true }))
	bp:add(
		"ball",
		r * 1.6,
		r * 0.5,
		r * 1.6,
		0,
		r * 0.55,
		0,
		0,
		0,
		0,
		o({ c = "#3E5230", m = "Grass" }, "detail", { col = false })
	)
	bp:box(3, 4, 1, 0, 1.8, -r + 0.4, o(Kit.dark, "detail", { col = false }))
	for i = 0, 5 do
		local a = i * math.pi / 3
		bp:beam(
			math.cos(a) * r * 0.95,
			0,
			math.sin(a) * r * 0.95,
			math.cos(a) * r * 0.3,
			r * 0.62,
			math.sin(a) * r * 0.3,
			0.6,
			o(Kit.darkBark, "detail", { col = false })
		)
	end
	Kit.skull(bp, 0, r * 0.62 + 0.2, -r * 0.5, 1.4)
	bp:pop()
end

-- Big iron cauldron with bubbling brew (bubbles tag) over a fire of `fire` colour, at (x, y, z).
function Props.cauldron(bp: BP, x: number, y: number, z: number, size: number, brew: string, fire: string?)
	bp:add("cyl", size * 0.8, size, size, x, y + size * 0.55, z, 0, 0, 90, o(Kit.iron, "shell", { q = false }))
	bp:add("cyl", 0.3, size * 0.86, size * 0.86, x, y + size * 0.95, z, 0, 0, 90, {
		c = brew,
		m = "Neon",
		lod = "detail",
		col = false,
		tag = "bubbles",
		jitter = 0,
		fxColor = brew,
	})
	for i = 0, 2 do
		local a = i * 2.1
		bp:beam(
			x + math.cos(a) * size * 0.4,
			y + size * 0.3,
			z + math.sin(a) * size * 0.4,
			x + math.cos(a) * size * 0.65,
			y,
			z + math.sin(a) * size * 0.65,
			0.35,
			o(Kit.iron, "detail", { col = false })
		)
	end
	if fire then
		Kit.fire(bp, x, y + 0.2, z, size * 0.5, fire)
	end
end

-- Broken bow and scattered arrows (fine).
function Props.brokenBow(bp: BP, x: number, y: number, z: number, yaw: number)
	bp:push(x, y + 0.15, z, 0, yaw, 0)
	bp:rbox(2.6, 0.2, 0.2, -1.2, 0, 0, 0, 0, 0, o(Kit.timber, "fine"))
	bp:rbox(2.4, 0.2, 0.2, 1.2, 0, 0.5, 0, 34, 0, o(Kit.timber, "fine"))
	for i = 1, 3 do
		bp:rbox(2.4, 0.08, 0.08, i - 2, 0, 1.6 + i * 0.3, 0, i * 25, 0, o({ c = "#8A7458", m = "Wood" }, "fine"))
	end
	bp:pop()
end

-- Gravestone (shell when `big`).
function Props.gravestone(bp: BP, x: number, y: number, z: number, yaw: number, tilt: number, big: boolean)
	local h = if big then 4.2 else 2.6
	bp:rbox(
		if big then 2.6 else 1.8,
		h,
		0.6,
		x,
		y + h / 2 - 0.3,
		z,
		tilt,
		yaw,
		tilt * 0.5,
		o(Kit.mossyStone, if big then "shell" else "detail", { q = false, col = big })
	)
	if big then
		bp:rbox(0.5, 1.6, 0.62, x, y + h + 0.3, z, tilt, yaw, 0, o(Kit.mossyStone, "detail", { col = false }))
		bp:rbox(1.6, 0.5, 0.62, x, y + h, z, tilt, yaw, 0, o(Kit.mossyStone, "detail", { col = false }))
	end
end

Props.barrel = Parts.barrel

return Props
