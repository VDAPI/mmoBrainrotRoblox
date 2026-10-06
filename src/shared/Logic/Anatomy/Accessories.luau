--!strict
-- Accessories of the procedural monster looks (S24): small part groups mounted on the plan's sockets (Head,
-- Back, Tail, Hip, Hand_R, Hand_L, Chest, Shoulders). Each returns nothing and skips quietly when its socket is
-- missing. Ground space at scale 1, relative to the socket position.

local Builder = require("./Builder")

type B = Builder.Builder
type Socket = { pos: { number }, parent: string? }

local Accessories = {}

local function at(s: Socket, dx: number, dy: number, dz: number): { number }
	return { s.pos[1] + dx, s.pos[2] + dy, s.pos[3] + dz }
end

local function socketOf(b: B, ...: string): Socket?
	for _, name in { ... } do
		local s = b.sockets[name]
		if s then
			return s
		end
	end
	return nil
end

-- Head ----------------------------------------------------------------------------------------------------

local function horns(b: B, tone: string?, size: number?)
	local s = socketOf(b, "Head")
	if not s then
		return
	end
	local k = size or 1
	b:pair("Horn", "wedge", { 0.2 * k, 0.75 * k, 0.4 * k }, at(s, 0.32, 0.25 * k, 0.05), {
		tone = tone or "detail",
		material = "detail",
		rot = { -20, 0, -20 },
		parent = s.parent,
	})
end

Accessories.horns = function(b: B)
	horns(b, "detail", 1)
end

Accessories.hood = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Hood",
			"ball",
			{ 1.25, 1.2, 1.3 },
			at(s, 0, -0.35, 0.12),
			{ tone = "accent", material = "Fabric", parent = s.parent, far = true }
		)
		b:add(
			"HoodTip",
			"wedge",
			{ 0.5, 0.45, 0.6 },
			at(s, 0, 0.05, 0.65),
			{ tone = "accent", material = "Fabric", rot = { 0, 180, 0 }, parent = s.parent }
		)
	end
end

Accessories.helmet = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Helmet",
			"ball",
			{ 1.12, 0.75, 1.12 },
			at(s, 0, -0.18, 0.02),
			{ tone = "#7A7E86", material = "Metal", parent = s.parent }
		)
		b:add(
			"Nasal",
			"block",
			{ 0.1, 0.45, 0.08 },
			at(s, 0, -0.45, -0.55),
			{ tone = "#7A7E86", material = "Metal", parent = s.parent }
		)
	end
end

Accessories.rustyHelmet = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Helmet",
			"ball",
			{ 1.1, 0.72, 1.1 },
			at(s, 0, -0.2, 0.02),
			{ tone = "#6E5A48", material = "CorrodedMetal", parent = s.parent }
		)
		b:add(
			"Crest",
			"wedge",
			{ 0.12, 0.35, 0.8 },
			at(s, 0, 0.15, 0.05),
			{ tone = "#6E5A48", material = "CorrodedMetal", parent = s.parent }
		)
	end
end

Accessories.hornedHelmet = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Helmet",
			"ball",
			{ 1.15, 0.8, 1.15 },
			at(s, 0, -0.15, 0.02),
			{ tone = "#8A8E96", material = "Metal", parent = s.parent }
		)
		b:pair(
			"Horn",
			"cyl",
			{ 0.85, 0.24, 0.24 },
			at(s, 0.6, 0.15, 0.05),
			{ tone = "#E8E0CC", material = "SmoothPlastic", rot = { 0, 0, 40 }, parent = s.parent }
		)
	end
end

Accessories.visor = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Helm",
			"block",
			{ 1.05, 1.1, 1.05 },
			at(s, 0, -0.45, 0.02),
			{ tone = "accent", material = "Metal", parent = s.parent }
		)
		b:add("Slit", "block", { 0.8, 0.1, 0.06 }, at(s, 0, -0.45, -0.55), { tone = "glow", parent = s.parent })
	end
end

Accessories.crown = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Crown",
			"cyl",
			{ 0.3, 1.0, 1.0 },
			at(s, 0, 0.05, 0),
			{ tone = "#C9A45C", material = "Metal", rot = { 0, 0, 90 }, parent = s.parent }
		)
		for i = 1, 3 do
			local a = (i - 2) * 0.35
			b:add(
				"CrownSpike",
				"wedge",
				{ 0.14, 0.45, 0.2 },
				at(s, a, 0.4, -0.42),
				{ tone = "glow", parent = s.parent }
			)
		end
	end
end

Accessories.spikeCrown = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		for i = 1, 5 do
			local a = (i - 3) * 0.24
			b:add(
				"CrownSpike",
				"wedge",
				{ 0.14, 0.8 + (2 - math.abs(i - 3)) * 0.3, 0.22 },
				at(s, a, 0.45 + (2 - math.abs(i - 3)) * 0.15, 0.0),
				{
					tone = "detail",
					material = "Metal",
					rot = { 0, 180, (i - 3) * -12 },
					parent = s.parent,
				}
			)
		end
	end
end

Accessories.flameCrown = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		for i = 1, 4 do
			local a = (i - 2.5) * 0.3
			b:add(
				"Flame",
				"wedge",
				{ 0.2, 0.7, 0.3 },
				at(s, a, 0.35, -0.1),
				{ tone = "glow", rot = { 0, 180, (i - 2.5) * -10 }, parent = s.parent }
			)
		end
	end
end

Accessories.beard = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Beard",
			"wedge",
			{ 0.8, 0.9, 0.5 },
			at(s, 0, -1.2, -0.45),
			{ tone = "detail", material = "Fabric", rot = { 180, 0, 0 }, parent = s.parent }
		)
	end
end

Accessories.braids = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Beard",
			"wedge",
			{ 0.85, 1.0, 0.5 },
			at(s, 0, -1.25, -0.45),
			{ tone = "accent", material = "Fabric", rot = { 180, 0, 0 }, parent = s.parent }
		)
		b:pair(
			"Braid",
			"cyl",
			{ 0.8, 0.18, 0.18 },
			at(s, 0.25, -1.95, -0.5),
			{ tone = "accent", material = "Fabric", rot = { 0, 0, 90 }, parent = s.parent }
		)
	end
end

Accessories.frostBeard = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Beard",
			"wedge",
			{ 0.9, 1.2, 0.55 },
			at(s, 0, -1.35, -0.45),
			{ tone = "#D8E8F2", material = "Ice", rot = { 180, 0, 0 }, parent = s.parent }
		)
	end
end

Accessories.whiskers = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:pair(
			"Whisker",
			"cyl",
			{ 0.7, 0.04, 0.04 },
			at(s, 0.35, -0.55, -0.55),
			{ tone = "#E8E4DA", material = "SmoothPlastic", rot = { 0, 20, 8 }, parent = s.parent }
		)
	end
end

Accessories.earTufts = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:pair(
			"Tuft",
			"wedge",
			{ 0.08, 0.4, 0.14 },
			at(s, 0.3, 0.45, 0.1),
			{ tone = Builder.DARKEST, material = "Fabric", rot = { 0, 180, -8 }, parent = s.parent }
		)
	end
end

Accessories.skullMask = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Mask",
			"ball",
			{ 0.85, 0.9, 0.45 },
			at(s, 0, -0.45, -0.38),
			{ tone = "#E0D8C4", material = "SmoothPlastic", parent = s.parent }
		)
		b:pair("Socket", "ball", { 0.2, 0.2, 0.1 }, at(s, 0.18, -0.38, -0.6), { tone = "glow", parent = s.parent })
	end
end

Accessories.feathers = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		for i = 1, 3 do
			b:add("Feather", "wedge", { 0.1, 0.7, 0.25 }, at(s, (i - 2) * 0.25, 0.3, 0.3), {
				tone = if i == 2 then "accent" else "#C2352E",
				material = "Fabric",
				rot = { -25, 180, (i - 2) * 18 },
				parent = s.parent,
			})
		end
	end
end

Accessories.witchHat = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Brim",
			"cyl",
			{ 0.1, 1.7, 1.7 },
			at(s, 0, -0.05, 0),
			{ tone = "accent", material = "Fabric", rot = { 0, 0, 90 }, parent = s.parent }
		)
		b:add(
			"HatCone",
			"wedge",
			{ 0.9, 1.4, 0.9 },
			at(s, 0, 0.7, 0.1),
			{ tone = "accent", material = "Fabric", rot = { 0, 180, 0 }, parent = s.parent }
		)
	end
end

Accessories.lanternHelmet = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Helmet",
			"ball",
			{ 1.05, 0.7, 1.05 },
			at(s, 0, -0.18, 0.02),
			{ tone = "#C9A45C", material = "Metal", parent = s.parent }
		)
		b:add(
			"Lamp",
			"ball",
			{ 0.3, 0.3, 0.3 },
			at(s, 0, 0.0, -0.52),
			{ tone = "#FFE08A", material = "Neon", glow = true, parent = s.parent }
		)
	end
end

Accessories.tusks = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:pair(
			"Tusk",
			"wedge",
			{ 0.12, 0.35, 0.16 },
			at(s, 0.22, -0.8, -0.45),
			{ tone = "#E8E0CC", material = "SmoothPlastic", parent = s.parent }
		)
	end
end

Accessories.flameHead = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Flame",
			"wedge",
			{ 0.45, 0.85, 0.45 },
			at(s, 0, 0.35, 0),
			{ tone = "glow", rot = { 0, 45, 0 }, parent = s.parent }
		)
		b:add(
			"FlameIn",
			"ball",
			{ 0.35, 0.5, 0.35 },
			at(s, 0, 0.2, 0),
			{ tone = "#FFE08A", material = "Neon", glow = true, parent = s.parent }
		)
	end
end

Accessories.crest = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		for i = 1, 3 do
			b:add(
				"Crest",
				"wedge",
				{ 0.12, 0.55 - i * 0.08, 0.45 },
				at(s, 0, 0.1, (i - 1) * 0.35),
				{ tone = "accent", rot = { 0, 180, 0 }, parent = s.parent }
			)
		end
	end
end

-- Back ----------------------------------------------------------------------------------------------------

Accessories.mane = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Mane",
			"ball",
			{ 1.2, 0.8, 1.6 },
			at(s, 0, 0.05, -0.4),
			{ tone = "shade", material = "Fabric", parent = s.parent }
		)
	end
end

local function backSpikes(b: B, tone: string, material: string, glow: boolean?)
	local s = socketOf(b, "Back")
	if s then
		for i = 1, 3 do
			b:add("Spike", "wedge", { 0.18, 0.55 - i * 0.07, 0.45 }, at(s, 0, 0.15, (i - 2) * 0.55), {
				tone = tone,
				material = material,
				glow = glow,
				parent = s.parent,
			})
		end
	end
end

Accessories.spikesBack = function(b: B)
	backSpikes(b, "detail", "detail")
end

Accessories.iceSpikes = function(b: B)
	backSpikes(b, "#B8E4F5", "Ice")
end

Accessories.flameSpikes = function(b: B)
	backSpikes(b, "glow", "Neon", true)
end

Accessories.backpack = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Pack",
			"block",
			{ 1.0, 1.1, 0.6 },
			at(s, 0, 0, 0.25),
			{ tone = "#6B4A2B", material = "Leather", parent = s.parent }
		)
	end
end

Accessories.sack = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Sack",
			"ball",
			{ 1.0, 1.15, 0.85 },
			at(s, 0.1, -0.1, 0.35),
			{ tone = "#A88A5A", material = "Fabric", parent = s.parent }
		)
	end
end

Accessories.cape = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Cape",
			"block",
			{ 1.4, 2.4, 0.12 },
			at(s, 0, -0.9, 0.15),
			{ tone = "accent", material = "Fabric", rot = { 8, 0, 0 }, parent = s.parent, far = true }
		)
	end
end

Accessories.banner = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Pole",
			"cyl",
			{ 3.2, 0.14, 0.14 },
			at(s, 0.3, 1.0, 0.25),
			{ tone = "#5A4632", material = "Wood", rot = { 0, 0, 90 }, parent = s.parent }
		)
		b:add(
			"Banner",
			"block",
			{ 0.08, 1.2, 0.9 },
			at(s, 0.3, 2.05, 0.75),
			{ tone = "accent", material = "Fabric", parent = s.parent }
		)
	end
end

Accessories.moss = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Moss",
			"ball",
			{ 1.5, 0.45, 1.3 },
			at(s, 0, 0.1, 0),
			{ tone = "#4E6E36", material = "Grass", parent = s.parent }
		)
		b:add(
			"Moss",
			"ball",
			{ 0.8, 0.35, 0.7 },
			at(s, 0.4, 0.2, -0.5),
			{ tone = "#5E7A3A", material = "Grass", parent = s.parent }
		)
	end
end

Accessories.crystals = function(b: B)
	local s = socketOf(b, "Shoulders", "Back")
	if s then
		b:pair(
			"Crystal",
			"corner",
			{ 0.55, 1.1, 0.55 },
			at(s, 0.75, 0.45, 0),
			{ tone = "accent", material = "Glass", rot = { 0, 45, -15 }, parent = s.parent }
		)
		b:add(
			"Crystal",
			"corner",
			{ 0.6, 1.3, 0.6 },
			at(s, 0, 0.6, 0.3),
			{ tone = "light", material = "Glass", rot = { 0, 45, 0 }, parent = s.parent }
		)
	end
end

Accessories.leaves = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Leaves",
			"ball",
			{ 1.6, 1.0, 1.4 },
			at(s, 0.3, 0.1, 0.3),
			{ tone = "#5E7A3A", material = "Grass", parent = s.parent }
		)
	end
end

Accessories.mushrooms = function(b: B)
	local s = socketOf(b, "Back", "Chest")
	if s then
		for i = 1, 2 do
			b:add(
				"Stem",
				"cyl",
				{ 0.4, 0.14, 0.14 },
				at(s, (i - 1.5) * 0.7, 0.1, 0.1),
				{ tone = "#E8DCC8", material = "SmoothPlastic", rot = { 0, 0, 90 }, parent = s.parent }
			)
			b:add(
				"Cap",
				"ball",
				{ 0.55, 0.25, 0.55 },
				at(s, (i - 1.5) * 0.7, 0.32, 0.1),
				{ tone = "#B8423A", material = "SmoothPlastic", parent = s.parent }
			)
		end
	end
end

Accessories.orbitSkulls = function(b: B)
	local s = socketOf(b, "Chest", "Back")
	if s then
		b:add("SkullOrbit", "ball", { 0.1, 0.1, 0.1 }, at(s, 0, 0.2, 0.5), {
			tone = "glow",
			parent = s.parent,
			joint = { role = "orbit", at = at(s, 0, 0.2, 0.5) },
		})
		for i = 1, 3 do
			local a = (i - 1) / 3 * math.pi * 2
			b:add(
				"Skull",
				"ball",
				{ 0.45, 0.45, 0.45 },
				at(s, math.cos(a) * 1.7, 0.4 + (i % 2) * 0.4, 0.5 + math.sin(a) * 1.7),
				{
					tone = "#E0D8C4",
					material = "SmoothPlastic",
					parent = "SkullOrbit",
				}
			)
		end
	end
end

Accessories.chains = function(b: B)
	local s = socketOf(b, "Chest", "Back")
	if s then
		b:add(
			"Chain",
			"cyl",
			{ 1.6, 0.14, 0.14 },
			at(s, 0, 0.0, -0.05),
			{ tone = "#7A7E86", material = "CorrodedMetal", rot = { 0, 0, 35 }, parent = s.parent }
		)
		b:add(
			"Chain",
			"cyl",
			{ 1.6, 0.14, 0.14 },
			at(s, 0, -0.4, -0.05),
			{ tone = "#7A7E86", material = "CorrodedMetal", rot = { 0, 0, -35 }, parent = s.parent }
		)
	end
end

-- Body ----------------------------------------------------------------------------------------------------

Accessories.robe = function(b: B)
	local s = socketOf(b, "Chest")
	if s then
		b:add(
			"Tabard",
			"block",
			{ 0.9, 1.6, 0.12 },
			at(s, 0, -0.6, -0.08),
			{ tone = "accent", material = "Fabric", parent = s.parent }
		)
	end
end

Accessories.collar = function(b: B)
	local s = socketOf(b, "Shoulders")
	if s then
		b:add(
			"Collar",
			"wedge",
			{ 1.5, 1.0, 0.25 },
			at(s, 0, 0.45, 0.35),
			{ tone = "accent", material = "Fabric", rot = { 0, 180, 0 }, parent = s.parent }
		)
	end
end

Accessories.scarf = function(b: B)
	local s = socketOf(b, "Head")
	if s then
		b:add(
			"Scarf",
			"ball",
			{ 0.95, 0.4, 0.9 },
			at(s, 0, -0.75, -0.05),
			{ tone = "accent", material = "Fabric", parent = s.parent }
		)
	end
end

Accessories.pouches = function(b: B)
	local s = socketOf(b, "Hip")
	if s then
		b:add(
			"Pouch",
			"block",
			{ 0.35, 0.4, 0.4 },
			at(s, 0.05, -0.15, -0.1),
			{ tone = "#6B4A2B", material = "Leather", parent = s.parent }
		)
		b:add(
			"Pouch",
			"block",
			{ 0.32, 0.35, 0.35 },
			at(s, -0.4, -0.15, 0.3),
			{ tone = "#5A3D2B", material = "Leather", parent = s.parent }
		)
	end
end

Accessories.herbs = function(b: B)
	local s = socketOf(b, "Hip")
	if s then
		b:add(
			"Herbs",
			"ball",
			{ 0.35, 0.55, 0.35 },
			at(s, 0.05, -0.2, 0),
			{ tone = "#7ACB3A", material = "Grass", parent = s.parent }
		)
	end
end

Accessories.apron = function(b: B)
	local s = socketOf(b, "Chest")
	if s then
		b:add(
			"Apron",
			"block",
			{ 1.0, 1.9, 0.12 },
			at(s, 0, -0.75, -0.06),
			{ tone = "#5A3D2B", material = "Leather", parent = s.parent }
		)
	end
end

Accessories.bandages = function(b: B)
	local s = socketOf(b, "Chest")
	if s then
		for i = 1, 3 do
			b:add(
				"Bandage",
				"cyl",
				{ 0.16, 1.25, 0.95 },
				at(s, 0, 0.35 - i * 0.4, 0.35),
				{ tone = "#D8CBA8", material = "Fabric", rot = { (i - 2) * 8, 0, 90 }, parent = s.parent }
			)
		end
	end
end

Accessories.runes = function(b: B)
	local s = socketOf(b, "Chest", "Back")
	if s then
		b:add(
			"Rune",
			"block",
			{ 0.45, 0.45, 0.06 },
			at(s, 0, 0.1, -0.03),
			{ tone = "glow", rot = { 0, 0, 45 }, parent = s.parent }
		)
		b:add("Rune", "block", { 0.12, 0.7, 0.06 }, at(s, 0, -0.45, -0.03), { tone = "glow", parent = s.parent })
	end
end

Accessories.vMark = function(b: B)
	local s = socketOf(b, "Chest", "Back")
	if s then
		b:add(
			"Mark",
			"wedge",
			{ 0.9, 0.7, 0.12 },
			at(s, 0, 0, -0.04),
			{ tone = "#D8C9A8", material = "Fabric", rot = { 180, 0, 0 }, parent = s.parent }
		)
	end
end

Accessories.pauldrons = function(b: B)
	local s = socketOf(b, "Shoulders")
	if s then
		b:pair(
			"Pauldron",
			"ball",
			{ 0.95, 0.65, 0.95 },
			at(s, 0.95, 0, 0),
			{ tone = "#5A5650", material = "Metal", parent = s.parent }
		)
		b:pair(
			"PauldronSpike",
			"wedge",
			{ 0.15, 0.5, 0.3 },
			at(s, 1.05, 0.45, 0),
			{ tone = "#8A8E96", material = "Metal", rot = { 0, 180, -20 }, parent = s.parent }
		)
	end
end

Accessories.skullPauldrons = function(b: B)
	local s = socketOf(b, "Shoulders")
	if s then
		b:pair(
			"SkullPauldron",
			"ball",
			{ 0.75, 0.7, 0.75 },
			at(s, 1.0, 0.05, 0),
			{ tone = "#E0D8C4", material = "SmoothPlastic", parent = s.parent }
		)
	end
end

Accessories.iceArmor = function(b: B)
	local s = socketOf(b, "Shoulders", "Chest")
	if s then
		b:pair(
			"IcePlate",
			"corner",
			{ 0.85, 0.75, 0.85 },
			at(s, 0.9, 0.05, 0),
			{ tone = "#B8E4F5", material = "Ice", parent = s.parent }
		)
		b:add(
			"IceChest",
			"block",
			{ 1.2, 0.9, 0.2 },
			at(s, 0, -0.9, -0.5),
			{ tone = "#B8E4F5", material = "Glacier", parent = s.parent }
		)
	end
end

Accessories.warPaint = function(b: B)
	local s = socketOf(b, "Chest")
	if s then
		b:add(
			"Paint",
			"block",
			{ 1.05, 0.14, 0.06 },
			at(s, 0, 0.2, -0.02),
			{ tone = "#C2352E", material = "SmoothPlastic", rot = { 0, 0, 20 }, parent = s.parent }
		)
		b:add(
			"Paint",
			"block",
			{ 1.05, 0.14, 0.06 },
			at(s, 0, -0.2, -0.02),
			{ tone = "#C2352E", material = "SmoothPlastic", rot = { 0, 0, -20 }, parent = s.parent }
		)
	end
end

Accessories.spots = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		for i = 1, 4 do
			b:add("Spot", "ball", { 0.28, 0.12, 0.28 }, at(s, (b:rand(i) - 0.5) * 0.9, -0.05, (i - 2.5) * 0.45), {
				tone = Builder.DARKEST,
				material = "Fabric",
				parent = s.parent,
			})
		end
	end
end

Accessories.amulets = function(b: B)
	local s = socketOf(b, "Chest")
	if s then
		b:add(
			"Amulet",
			"ball",
			{ 0.28, 0.28, 0.15 },
			at(s, -0.2, 0.25, -0.05),
			{ tone = "accent", material = "SmoothPlastic", parent = s.parent }
		)
		b:add("Amulet", "ball", { 0.22, 0.22, 0.12 }, at(s, 0.22, 0.1, -0.05), { tone = "glow", parent = s.parent })
	end
end

Accessories.flameHands = function(b: B)
	for _, name in { "Hand_R", "Hand_L" } do
		local s = b.sockets[name]
		if s then
			b:add("HandFlame", "ball", { 0.55, 0.75, 0.55 }, at(s, 0, 0.2, 0.3), { tone = "glow", parent = s.parent })
		end
	end
end

Accessories.wings = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:pair("SmallWing", "block", { 1.1, 0.08, 0.7 }, at(s, 0.65, 0.35, 0.1), {
			tone = "accent",
			rot = { 0, 0, 25 },
			parent = s.parent,
			joint = { role = "flap", at = at(s, 0.15, 0.35, 0.1) },
		})
	end
end

Accessories.tailBlade = function(b: B)
	local s = socketOf(b, "Hip", "Back")
	if s then
		b:add(
			"TailBlade",
			"wedge",
			{ 0.15, 0.35, 0.45 },
			at(s, -0.5, -0.9, 1.6),
			{ tone = "accent", parent = s.parent }
		)
	end
end

Accessories.lantern = function(b: B)
	local s = socketOf(b, "Hand_L", "Hip")
	if s then
		b:add(
			"Lantern",
			"block",
			{ 0.35, 0.5, 0.35 },
			at(s, 0, -0.35, 0),
			{ tone = "#5A4632", material = "Metal", parent = s.parent }
		)
		b:add(
			"LanternLight",
			"ball",
			{ 0.25, 0.3, 0.25 },
			at(s, 0, -0.35, 0),
			{ tone = "#FFD08A", material = "Neon", glow = true, parent = s.parent }
		)
	end
end

Accessories.cloakTatters = function(b: B)
	local s = socketOf(b, "Back")
	if s then
		b:add(
			"Tatter",
			"wedge",
			{ 0.9, 1.5, 0.1 },
			at(s, 0, -1.4, 0.15),
			{ tone = "shade", material = "Fabric", rot = { 180, 0, 0 }, parent = s.parent }
		)
	end
end

-- Elite marks: small extra pieces that read from afar.
Accessories.eliteHorns = function(b: B)
	horns(b, "accent", 0.8)
end

Accessories.glowRunes = Accessories.runes

return Accessories
