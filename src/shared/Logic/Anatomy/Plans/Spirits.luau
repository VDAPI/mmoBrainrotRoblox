--!strict
-- Body plans of constructs and spirits (S24): golem (stone, lava, crystal, frost giant), treant, ghost
-- (wraiths, specters; floats, no legs) and elemental (crystal core with orbiting shards; floats). Ground space
-- at scale 1.

local Builder = require("../Builder")

type B = Builder.Builder

local Plans = {}

-- Golem: blocky torso, boulder shoulders, heavy arms and fists, short legs, small head sunk between the
-- shoulders. build: crystal (crystal shapes), cracks (glowing seams), height.
function Plans.golem(b: B)
	local height = b:get("height", 1)
	local crystal = b:get("crystal", 0) > 0
	local cracks = b:get("cracks", 0) > 0
	local legTop = 1.4 * height
	local torsoY = legTop + 1.25 * height
	b:coreBody("Torso", if crystal then "corner" else "block", { 2.3, 2.3 * height, 1.6 }, { 0, torsoY, 0 }, {
		rot = if crystal then { 0, 45, 0 } else { -6, 0, 0 },
	})
	b:add("Belly", "block", { 1.8, 0.9, 1.35 }, { 0, legTop + 0.3, 0.05 }, { tone = "shade", parent = "Torso" })
	if cracks then
		b:add("Core", "ball", { 0.9, 0.9, 0.5 }, { 0, torsoY + 0.1, -0.68 }, { tone = "glow", parent = "Torso" })
		b:add(
			"Crack",
			"block",
			{ 0.12, 1.5 * height, 0.1 },
			{ -0.5, torsoY - 0.1, -0.8 },
			{ tone = "glow", rot = { 0, 0, 18 }, parent = "Torso" }
		)
		b:add(
			"Crack",
			"block",
			{ 0.12, 1.1 * height, 0.1 },
			{ 0.6, torsoY + 0.3, -0.8 },
			{ tone = "glow", rot = { 0, 0, -25 }, parent = "Torso" }
		)
	end
	local head = b:add(
		"Head",
		if crystal then "corner" else "block",
		{ 0.95, 0.85, 0.9 },
		{ 0, torsoY + 1.25 * height + 0.25, -0.35 },
		{
			tone = "shade",
			parent = "Torso",
			far = true,
			joint = { role = "head", at = { 0, torsoY + 1.1 * height, -0.2 } },
		}
	)
	b:eyes(head.name, { 0.22, torsoY + 1.3 * height + 0.25, -0.82 }, 0.17, true)
	b:pair(
		"Shoulder",
		if crystal then "corner" else "ball",
		{ 1.3, 1.1, 1.3 },
		{ 1.45, torsoY + 0.9 * height, -0.05 },
		{
			tone = "shade",
			far = true,
			parent = "Torso",
		}
	)
	local shoulderY = torsoY + 0.7 * height
	b:pair("Arm", "block", { 0.85, 1.9 * height, 0.85 }, { 1.65, shoulderY - 0.95 * height, -0.1 }, {
		rot = { 8, 0, 6 },
		parent = "Torso",
		joint = { role = "arm", at = { 1.55, shoulderY, -0.1 } },
	})
	b:pair(
		"Fist",
		if crystal then "corner" else "ball",
		{ 1.25, 1.2, 1.25 },
		{ 1.75, shoulderY - 2.05 * height, -0.35 },
		{
			tone = "shade",
			parent = "Arm*",
		}
	)
	b:pair("Leg", "block", { 1.0, legTop, 1.0 }, { 0.65, legTop / 2, 0 }, {
		tone = "shade",
		parent = "Torso",
		joint = { role = "leg", phase = 0, at = { 0.65, legTop, 0 } },
	})
	b:socket("Head", { 0, torsoY + 1.25 * height + 0.7, -0.35 }, head.name)
	b:socket("Back", { 0, torsoY + 0.4, 0.85 }, "Torso")
	b:socket("Shoulders", { 0, torsoY + 1.2 * height, 0 }, "Torso")
	b:socket("Hand_R", { 1.75, shoulderY - 2.05 * height, -0.9 }, "ArmR")
	b:socket("Hand_L", { -1.75, shoulderY - 2.05 * height, -0.9 }, "ArmL")
	b:socket("Chest", { 0, torsoY, -0.82 }, "Torso")
end

-- Treant: bark trunk, root legs, branch arms, a crown of leaf balls, hollow eyes.
function Plans.treant(b: B)
	local trunkH = 4.2
	b:coreBody("Trunk", "cyl", { trunkH, 1.7, 1.7 }, { 0, 0.6 + trunkH / 2, 0 }, { rot = { 0, 0, 90 } })
	b:add(
		"Bark",
		"cyl",
		{ trunkH * 0.75, 1.82, 1.82 },
		{ 0, 1.0 + trunkH * 0.4, 0 },
		{ tone = "shade", rot = { 0, 30, 90 }, parent = "Trunk", transparency = 0 }
	)
	b:pair("Root", "cyl", { 1.7, 0.75, 0.75 }, { 0.55, 0.7, 0 }, {
		tone = "shade",
		rot = { 0, 0, 70 },
		parent = "Trunk",
		joint = { role = "leg", phase = 0, at = { 0.4, 1.3, 0 } },
	})
	b:pair("RootFoot", "wedge", { 0.8, 0.45, 1.4 }, { 0.85, 0.22, -0.2 }, { tone = "shade", parent = "Root*" })
	local face = 0.6 + trunkH * 0.7
	b:pair(
		"Hollow",
		"ball",
		{ 0.42, 0.5, 0.25 },
		{ 0.38, face, -0.8 },
		{ tone = Builder.DARKEST, material = "SmoothPlastic", parent = "Trunk" }
	)
	b:eyes("Trunk", { 0.38, face, -0.9 }, 0.16, true)
	b:add(
		"Mouth",
		"ball",
		{ 0.75, 0.3, 0.2 },
		{ 0, face - 0.75, -0.82 },
		{ tone = Builder.DARKEST, material = "SmoothPlastic", parent = "Trunk" }
	)
	local shoulderY = 0.6 + trunkH * 0.78
	b:pair("Branch", "cyl", { 1.9, 0.5, 0.5 }, { 1.4, shoulderY - 0.35, -0.1 }, {
		rot = { 0, 0, -25 },
		parent = "Trunk",
		joint = { role = "arm", at = { 0.8, shoulderY, -0.1 } },
	})
	b:pair(
		"Twig",
		"cyl",
		{ 1.5, 0.32, 0.32 },
		{ 2.25, shoulderY - 1.35, -0.3 },
		{ tone = "shade", rot = { 0, 15, -65 }, parent = "Branch*" }
	)
	b:pair(
		"Claw",
		"wedge",
		{ 0.35, 0.2, 0.7 },
		{ 2.55, shoulderY - 2.05, -0.55 },
		{ tone = "shade", parent = "Branch*" }
	)
	local top = 0.6 + trunkH
	b:add(
		"Crown",
		"ball",
		{ 3.2, 2.2, 3.0 },
		{ 0, top + 0.75, 0.1 },
		{ tone = "accent", material = "accent", parent = "Trunk", far = true }
	)
	b:pair(
		"Leaves",
		"ball",
		{ 1.9, 1.6, 1.9 },
		{ 1.25, top + 0.25, 0.3 },
		{ tone = "accent", material = "accent", parent = "Trunk" }
	)
	b:socket("Head", { 0, top + 1.6, 0 }, "Trunk")
	b:socket("Back", { 0, top - 1.0, 0.85 }, "Trunk")
	b:socket("Hand_R", { 2.55, shoulderY - 2.0, -0.7 }, "BranchR")
	b:socket("Hand_L", { -2.55, shoulderY - 2.0, -0.7 }, "BranchL")
	b:socket("Chest", { 0, face - 1.2, -0.85 }, "Trunk")
end

-- Ghost: hooded floating cloak with a tattered hem, a dark face with glowing eyes, clawed arms. Floats.
function Plans.ghost(b: B)
	local fade = b:get("fade", 0.2)
	b:coreBody(
		"Cloak",
		"ball",
		{ 1.6, 2.6, 1.3 },
		{ 0, 1.7, 0 },
		{ tone = "base", material = "Fabric", transparency = fade, joint = { role = "body", amp = 1.3 } }
	)
	for i = 1, 4 do
		local a = (i - 0.5) / 4 * math.pi * 2
		b:add("Hem", "wedge", { 0.55, 0.9, 0.35 }, { math.cos(a) * 0.55, 0.45, math.sin(a) * 0.45 }, {
			tone = "shade",
			material = "Fabric",
			rot = { 180, math.deg(a) + 90, 0 },
			parent = "Cloak",
			transparency = fade,
		})
	end
	local head = b:add("Hood", "ball", { 1.25, 1.35, 1.25 }, { 0, 3.15, 0.05 }, {
		tone = "shade",
		material = "Fabric",
		parent = "Cloak",
		far = true,
		transparency = fade * 0.5,
		joint = { role = "head", at = { 0, 2.8, 0.05 } },
	})
	b:add(
		"Face",
		"ball",
		{ 0.85, 0.9, 0.5 },
		{ 0, 3.05, -0.4 },
		{ tone = Builder.DARKEST, material = "SmoothPlastic", parent = head.name }
	)
	b:eyes(head.name, { 0.2, 3.1, -0.62 }, 0.16, true)
	b:pair("Arm", "cyl", { 1.5, 0.32, 0.32 }, { 0.95, 2.05, -0.3 }, {
		tone = "base",
		material = "Fabric",
		rot = { 0, 0, 70 },
		parent = "Cloak",
		transparency = fade,
		joint = { role = "arm", at = { 0.7, 2.6, -0.2 } },
	})
	b:pair("Talon", "wedge", { 0.35, 0.18, 0.7 }, { 1.25, 1.35, -0.6 }, { tone = "detail", parent = "Arm*" })
	b:socket("Head", { 0, 3.8, 0.05 }, head.name)
	b:socket("Back", { 0, 2.5, 0.6 }, "Cloak")
	b:socket("Hand_R", { 1.25, 1.4, -0.7 }, "ArmR")
	b:socket("Hand_L", { -1.25, 1.4, -0.7 }, "ArmL")
	b:socket("Chest", { 0, 2.3, -0.6 }, "Cloak")
end

-- Elemental: crystal core with a shell and shards orbiting around it, glowing face. Floats.
function Plans.elemental(b: B)
	local chibi = b:get("chibi", 0)
	local s = 1 - chibi * 0.55
	b:coreBody("Core", "ball", { 1.4 * s, 1.7 * s, 1.4 * s }, { 0, 1.8 * s, 0 }, {
		tone = "light",
		material = "accent",
		joint = { role = "body", amp = 1.45 },
	})
	b:add("Heart", "ball", { 0.75 * s, 0.75 * s, 0.75 * s }, { 0, 1.8 * s, 0 }, { tone = "glow", parent = "Core" })
	b:add(
		"Shell",
		"corner",
		{ 1.3 * s, 1.0 * s, 1.3 * s },
		{ 0, 2.55 * s, 0 },
		{ tone = "base", material = "accent", rot = { 0, 45, 0 }, parent = "Core", far = true }
	)
	b:add(
		"ShellLow",
		"corner",
		{ 1.2 * s, 0.9 * s, 1.2 * s },
		{ 0, 1.0 * s, 0 },
		{ tone = "shade", material = "accent", rot = { 180, 45, 0 }, parent = "Core" }
	)
	b:eyes("Core", { 0.25 * s, 2.0 * s, -0.66 * s }, 0.15 + chibi * 0.08, true)
	local count = if chibi > 0 then 3 else 4
	b:add("Orbit", "ball", { 0.1, 0.1, 0.1 }, { 0, 1.8 * s, 0 }, {
		tone = "glow",
		parent = "Core",
		joint = { role = "orbit", at = { 0, 1.8 * s, 0 } },
	})
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2
		b:add(
			"Shard",
			"corner",
			{ 0.45 * s, 0.75 * s, 0.45 * s },
			{ math.cos(a) * 1.55 * s, 1.8 * s + math.sin(a * 2) * 0.35, math.sin(a) * 1.55 * s },
			{
				tone = if i % 2 == 0 then "accent" else "base",
				material = "accent",
				rot = { 0, math.deg(a), 20 },
				parent = "Orbit",
			}
		)
	end
	b:socket("Head", { 0, 3.1 * s, 0 }, "Core")
	b:socket("Back", { 0, 2.2 * s, 0.6 * s }, "Core")
	b:socket("Chest", { 0, 1.8 * s, -0.7 * s }, "Core")
end

return Plans
