--!strict
-- Body plans of birds, bats, serpents, spiders, scorpions and dragons (S24). Ground space at scale 1 (see
-- Builder). Fliers hover (Anatomy adds the hover height); their core joint uses amp > 1 for the bob.

local Builder = require("../Builder")

type B = Builder.Builder

local Plans = {}

-- Two-segment wing (inner + outer plate) on the right side, mirrored: flap role, the outer part lags behind
-- and is narrower and set back, so the wing tapers towards the tip.
local function wings(
	b: B,
	root: { number },
	span: number,
	depth: number,
	tone: string,
	parent: string,
	membrane: boolean?
)
	local half = span / 2
	local material = if membrane then "accent" else "base"
	b:pair("WingIn", "block", { half, 0.12, depth }, { root[1] + half / 2, root[2], root[3] }, {
		tone = tone,
		far = true,
		material = material,
		parent = parent,
		joint = { role = "flap", phase = 0, at = { root[1], root[2], root[3] } },
	})
	b:pair("WingOut", "block", { half * 0.95, 0.1, depth * 0.62 }, {
		root[1] + half * 1.45,
		root[2] + 0.02,
		root[3] + depth * 0.2,
	}, {
		tone = tone,
		material = material,
		parent = "WingIn*",
		joint = { role = "flap", phase = 0.12, amp = 0.7, at = { root[1] + half, root[2], root[3] } },
	})
end

-- Bird: crow, vulture (build.neck = long bald neck + ruff), harpy (build.harpy: human head and torso).
function Plans.bird(b: B)
	local harpy = b:get("harpy", 0)
	local neck = b:get("neck", 0)
	local chibi = b:get("chibi", 0)
	if harpy > 0 then
		b:coreBody("Body", "ball", { 1.2, 1.5, 1.0 }, { 0, 1.9, 0 }, { joint = { role = "body", amp = 1.35 } })
		local head = b:add("Head", "ball", { 0.85, 0.95, 0.85 }, { 0, 3.05, -0.1 }, {
			tone = "light",
			parent = "Body",
			far = true,
			joint = { role = "head", at = { 0, 2.65, -0.05 } },
		})
		b:add(
			"Hair",
			"ball",
			{ 1.0, 0.9, 1.0 },
			{ 0, 3.25, 0.15 },
			{ tone = "accent", material = "Fabric", parent = head.name }
		)
		b:eyes(head.name, { 0.2, 3.1, -0.45 }, 0.14, b:get("glowEyes", 0) > 0)
		b:add("Breast", "ball", { 1.0, 0.8, 0.6 }, { 0, 2.1, -0.4 }, { tone = "light", parent = "Body" })
		wings(b, { 0.5, 2.4, 0.1 }, 4.2, 1.3, "base", "Body")
		b:pair("Leg", "cyl", { 1.1, 0.28, 0.28 }, { 0.3, 0.75, 0.1 }, {
			tone = "shade",
			rot = { 0, 0, 90 },
			parent = "Body",
			joint = { role = "leg", phase = 0, at = { 0.3, 1.3, 0.1 } },
		})
		b:pair("Talon", "wedge", { 0.4, 0.2, 0.55 }, { 0.3, 0.1, -0.1 }, { tone = "detail", parent = "Leg*" })
		b:add("TailFan", "wedge", { 0.9, 0.12, 1.1 }, { 0, 1.35, 0.85 }, { rot = { -150, 0, 0 }, parent = "Body" })
		b:socket("Head", { 0, 3.55, -0.1 }, head.name)
		b:socket("Back", { 0, 2.4, 0.4 }, "Body")
		return
	end
	local s = 1 - chibi * 0.15
	b:coreBody(
		"Body",
		"ball",
		{ 1.05 * s, 1.0 * s, 1.6 * s },
		{ 0, 1.25, 0.1 },
		{ joint = { role = "body", amp = 1.35 } }
	)
	b:add("Breast", "ball", { 0.85 * s, 0.85 * s, 0.8 }, { 0, 1.15, -0.45 }, { tone = "light", parent = "Body" })
	local headY = 1.75 + neck * 0.75
	if neck > 0 then
		b:add(
			"Ruff",
			"ball",
			{ 1.15, 0.7, 0.9 },
			{ 0, 1.65, -0.55 },
			{ tone = "light", material = "Fabric", parent = "Body" }
		)
		b:add(
			"Neck",
			"cyl",
			{ 1.0, 0.25, 0.25 },
			{ 0, 2.0, -0.85 },
			{ tone = "accent", rot = { 0, 0, 70 }, parent = "Body" }
		)
	end
	local headSize = (0.7 - neck * 0.12) * (1 + chibi * 0.6)
	local head = b:add("Head", "ball", { headSize, headSize, headSize * 1.05 }, { 0, headY, -0.75 - neck * 0.45 }, {
		tone = if neck > 0 then "accent" else "base",
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, headY - 0.25, -0.6 - neck * 0.35 } },
	})
	local beakLen = (0.55 + neck * 0.2) * (1 - chibi * 0.4)
	b:add(
		"Beak",
		"wedge",
		{ 0.24, 0.26, beakLen },
		{ 0, headY - 0.05, -0.75 - neck * 0.45 - headSize * 0.45 - beakLen / 2 + 0.05 },
		{
			tone = "detail",
			material = "SmoothPlastic",
			parent = head.name,
		}
	)
	b:eyes(
		head.name,
		{ headSize * 0.32, headY + 0.08, -0.75 - neck * 0.45 - headSize * 0.32 },
		0.12 + chibi * 0.1,
		b:get("glowEyes", 0) > 0
	)
	if chibi > 0 then
		b:pair(
			"Tuft",
			"wedge",
			{ 0.14, 0.35, 0.25 },
			{ 0.22, headY + headSize * 0.5, -0.75 },
			{ rot = { 0, 180, -15 }, parent = head.name }
		)
	end
	wings(b, { 0.45 * s, 1.45, 0.05 }, 3.4 * s * (1 + neck * 0.35), 1.0 * s, "shade", "Body")
	b:add("TailFan", "wedge", { 0.75 * s, 0.1, 0.95 * s }, { 0, 1.3, 1.05 }, {
		tone = "shade",
		rot = { -165, 0, 0 },
		parent = "Body",
		joint = { role = "tail", amp = 0.4, at = { 0, 1.3, 0.75 } },
	})
	b:pair(
		"Leg",
		"cyl",
		{ 0.55, 0.12, 0.12 },
		{ 0.22, 0.55, 0.15 },
		{ tone = "detail", rot = { 0, 0, 90 }, parent = "Body" }
	)
	b:socket("Head", { 0, headY + headSize * 0.5, -0.75 }, head.name)
	b:socket("Back", { 0, 1.75, 0.15 }, "Body")
end

-- Bat: small furry body, huge ears, membrane wings with bone wedges.
function Plans.bat(b: B)
	b:coreBody("Body", "ball", { 0.9, 1.1, 0.9 }, { 0, 1.4, 0 }, { joint = { role = "body", amp = 1.4 } })
	local head = b:add("Head", "ball", { 0.8, 0.75, 0.75 }, { 0, 2.15, -0.15 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 1.85, -0.1 } },
	})
	b:add("Snout", "wedge", { 0.35, 0.3, 0.35 }, { 0, 2.0, -0.6 }, { tone = "light", parent = head.name })
	b:pair(
		"Ear",
		"wedge",
		{ 0.14, 0.75, 0.5 },
		{ 0.3, 2.75, -0.05 },
		{ tone = "shade", rot = { 0, 180, -12 }, parent = head.name }
	)
	b:pair(
		"Fang",
		"wedge",
		{ 0.07, 0.18, 0.08 },
		{ 0.1, 1.85, -0.62 },
		{ tone = "#E8E2D0", material = "SmoothPlastic", rot = { 180, 0, 0 }, parent = head.name }
	)
	b:eyes(head.name, { 0.2, 2.2, -0.5 }, 0.15, true)
	wings(b, { 0.35, 1.65, 0.05 }, 3.6, 1.3, "accent", "Body", true)
	b:pair("Bone", "cyl", { 1.8, 0.12, 0.12 }, { 1.25, 1.72, -0.55 }, { tone = "shade", parent = "WingIn*" })
	b:pair(
		"Leg",
		"cyl",
		{ 0.5, 0.12, 0.12 },
		{ 0.2, 0.75, 0.1 },
		{ tone = "shade", rot = { 0, 0, 90 }, parent = "Body" }
	)
	b:socket("Head", { 0, 2.55, -0.15 }, head.name)
	b:socket("Back", { 0, 1.8, 0.35 }, "Body")
end

-- Serpent: a chain of shrinking segments that wave, head with a jaw, crest and fins. build: segments (8–12),
-- legs (0/1: two front legs), wings (0/1).
function Plans.serpent(b: B)
	local count = math.floor(b:get("segments", 9))
	local hasLegs = b:get("legs", 0) > 0
	local hasWings = b:get("wings", 0) > 0
	local thick = b:get("thick", 1)
	local y = 0.75 * thick
	b:coreBody("Body", "ball", { 1.2 * thick, 1.1 * thick, 1.5 }, { 0, y, -0.4 })
	local head = b:add("Head", "ball", { 1.0 * thick, 0.8 * thick, 1.25 }, { 0, y + 0.55, -1.55 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, y + 0.35, -1.0 } },
	})
	b:add("Jaw", "wedge", { 0.7 * thick, 0.22, 0.8 }, { 0, y + 0.28, -1.75 }, {
		tone = "light",
		parent = head.name,
		joint = { role = "jaw", at = { 0, y + 0.35, -1.3 } },
	})
	b:eyes(head.name, { 0.35 * thick, y + 0.8, -1.95 }, 0.16, b:get("glowEyes", 0) > 0)
	b:pair(
		"Fin",
		"wedge",
		{ 0.1, 0.5, 0.6 },
		{ 0.5 * thick, y + 0.75, -1.2 },
		{ tone = "accent", rot = { 0, 180, -35 }, parent = head.name }
	)
	local prev = "Body"
	local z = 0.35
	for i = 1, count do
		local k = 1 - (i / (count + 1)) * 0.75
		local seg = b:add(`Seg{i}`, "ball", { 1.15 * thick * k, 1.0 * thick * k, 1.05 }, { 0, y * k + 0.05, z + 0.4 }, {
			tone = if i % 2 == 0 then "shade" else "base",
			far = i == 2,
			parent = prev,
			joint = { role = "segment", phase = i * 0.11, amp = 0.9, at = { 0, y * k + 0.05, z } },
		})
		if i <= 4 then
			b:add("Crest", "wedge", { 0.1, 0.45 * k, 0.6 }, { 0, y * k + 0.55 * k + 0.1, z + 0.4 }, {
				tone = "accent",
				parent = seg.name,
			})
		end
		prev = seg.name
		z += 0.82
	end
	if hasLegs then
		b:pair("Leg", "cyl", { 1.0, 0.3, 0.3 }, { 0.7 * thick, 0.45, -0.35 }, {
			tone = "shade",
			rot = { 0, 0, 65 },
			parent = "Body",
			joint = { role = "leg", phase = 0, at = { 0.5, 0.8, -0.35 } },
		})
	end
	if hasWings then
		wings(b, { 0.5, y + 0.6, -0.2 }, 4.4, 1.5, "accent", "Body", true)
	end
	b:socket("Head", { 0, y + 0.95, -1.55 }, head.name)
	b:socket("Back", { 0, y + 0.6, -0.2 }, "Body")
end

-- Spider: thorax + patterned abdomen, 6 small eyes, fangs, 8 two-segment legs.
function Plans.spider(b: B)
	b:coreBody("Thorax", "ball", { 1.3, 0.85, 1.3 }, { 0, 1.05, -0.35 })
	b:add("Abdomen", "ball", { 1.8, 1.45, 2.0 }, { 0, 1.45, 1.05 }, { tone = "shade", parent = "Thorax", far = true })
	b:add(
		"Pattern",
		"ball",
		{ 1.0, 0.25, 1.25 },
		{ 0, 2.12, 1.05 },
		{ tone = "accent", rot = { -10, 0, 0 }, parent = "Abdomen" }
	)
	for i = 1, 3 do
		local x = (i - 2) * 0.22
		b:add("Eye", "ball", { 0.13, 0.13, 0.13 }, { x, 1.4, -0.98 }, { tone = "glow", parent = "Thorax" })
		b:add("Eye", "ball", { 0.1, 0.1, 0.1 }, { x * 1.4, 1.27, -0.95 }, { tone = "glow", parent = "Thorax" })
	end
	b:pair("Fang", "wedge", { 0.14, 0.4, 0.22 }, { 0.17, 0.75, -1.0 }, {
		tone = "detail",
		rot = { 180, 0, 0 },
		parent = "Thorax",
		joint = { role = "jaw", at = { 0.17, 0.95, -0.9 } },
	})
	for i = 1, 4 do
		local z = -0.75 + (i - 1) * 0.35
		local spread = (i - 2.5) * 12
		b:pair(`Leg{i}`, "cyl", { 1.3, 0.16, 0.16 }, { 1.15, 1.35, z }, {
			tone = "base",
			rot = { 0, spread, 30 },
			parent = "Thorax",
			joint = { role = "spiderLeg", phase = (i % 2) * 0.5, at = { 0.55, 1.05, z } },
		})
		b:pair(`Foot{i}`, "cyl", { 1.35, 0.13, 0.13 }, { 2.05, 0.62, z + (i - 2.5) * 0.25 }, {
			tone = "shade",
			rot = { 0, spread, -60 },
			parent = `Leg{i}*`,
		})
	end
	b:socket("Head", { 0, 1.5, -0.6 }, "Thorax")
	b:socket("Back", { 0, 2.15, 1.05 }, "Abdomen")
end

-- Scorpion: segmented armour, claws on arms (claw role), a five-segment tail over the back with a sting.
function Plans.scorpion(b: B)
	b:coreBody("Body", "ball", { 1.7, 0.8, 1.9 }, { 0, 0.8, 0.1 })
	b:add("Plate", "ball", { 1.5, 0.45, 1.3 }, { 0, 1.15, 0.5 }, { tone = "shade", parent = "Body" })
	local head = b:add("Head", "ball", { 1.2, 0.6, 0.9 }, { 0, 0.9, -1.0 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 0.85, -0.6 } },
	})
	b:eyes(head.name, { 0.25, 1.18, -1.3 }, 0.13, b:get("glowEyes", 0) > 0)
	b:pair("Arm", "cyl", { 1.1, 0.28, 0.28 }, { 0.85, 0.85, -1.15 }, {
		tone = "shade",
		rot = { 0, -55, 0 },
		parent = "Body",
		joint = { role = "arm", at = { 0.65, 0.85, -0.75 } },
	})
	b:pair("Claw", "ball", { 0.5, 0.42, 0.8 }, { 1.2, 0.85, -1.85 }, { tone = "base", parent = "Arm*" })
	b:pair("ClawTop", "wedge", { 0.24, 0.22, 0.6 }, { 1.12, 0.98, -2.4 }, {
		tone = "detail",
		parent = "Claw*",
		joint = { role = "claw", at = { 1.12, 0.95, -2.1 } },
	})
	b:pair(
		"ClawLow",
		"wedge",
		{ 0.22, 0.2, 0.55 },
		{ 1.3, 0.72, -2.38 },
		{ tone = "detail", rot = { 180, 0, 0 }, parent = "Claw*" }
	)
	local prev = "Body"
	local points = { { 0, 1.15, 1.1 }, { 0, 1.65, 1.45 }, { 0, 2.2, 1.55 }, { 0, 2.7, 1.3 }, { 0, 2.95, 0.85 } }
	for i, p in points do
		local k = 1 - i * 0.1
		local seg = b:add(`Tail{i}`, "ball", { 0.55 * k, 0.55 * k, 0.6 * k }, p, {
			tone = if i % 2 == 0 then "shade" else "base",
			far = i == 3,
			parent = prev,
			joint = { role = "sting", phase = i * 0.1, at = if i == 1 then { 0, 1.0, 0.9 } else points[i - 1] },
		})
		prev = seg.name
	end
	b:add(
		"Sting",
		"wedge",
		{ 0.2, 0.3, 0.6 },
		{ 0, 2.85, 0.45 },
		{ tone = "accent", rot = { 150, 0, 0 }, parent = prev }
	)
	for i = 1, 3 do
		local z = -0.35 + (i - 1) * 0.45
		b:pair(`Leg{i}`, "cyl", { 1.1, 0.14, 0.14 }, { 1.05, 0.4, z }, {
			tone = "shade",
			rot = { 0, (i - 2) * 15, 40 },
			parent = "Body",
			joint = { role = "spiderLeg", phase = (i % 2) * 0.5, at = { 0.7, 0.7, z } },
		})
	end
	b:socket("Head", { 0, 1.25, -1.0 }, head.name)
	b:socket("Back", { 0, 1.35, 0.4 }, "Body")
	b:socket("Tail", { 0, 2.95, 0.85 }, prev)
end

-- Dragon: long neck, horned head with a jaw, wings (wing arms for wyverns), long tail with a spike.
-- build: legs (2 or 4), wings (0/1), neck (length), span (wing span factor), slim, chibi (pets: no neck, jaw,
-- belly or spike, one tail segment, two legs).
function Plans.dragon(b: B)
	local chibi = b:get("chibi", 0)
	local small = chibi > 0
	local legs = if small then 2 else b:get("legs", 4)
	local hasWings = b:get("wings", 1) > 0
	local neckLen = if small then 0.5 else b:get("neck", 1)
	local slim = b:get("slim", 0)
	local span = b:get("span", 1)
	local w = (1.7 - slim * 0.35) * (1 - chibi * 0.2)
	local legTop = 1.35 - chibi * 0.55
	local bodyY = legTop + 0.55
	b:coreBody("Body", "ball", { w, 1.4, 2.9 }, { 0, bodyY, 0.2 })
	if not small then
		b:add("Belly", "ball", { w * 0.8, 0.9, 2.5 }, { 0, bodyY - 0.35, 0.15 }, { tone = "light", parent = "Body" })
	end
	local headParent = "Body"
	if not small then
		local neck = b:add(
			"Neck",
			"cyl",
			{ 1.3 * neckLen, 0.6, 0.6 },
			{ 0, bodyY + 0.65 * neckLen, -1.55 - 0.15 * neckLen },
			{
				rot = { 0, 90, -55 },
				parent = "Body",
				joint = { role = "head", amp = 0.5, at = { 0, bodyY + 0.25, -1.05 } },
			}
		)
		headParent = neck.name
	end
	local headY = bodyY + 1.2 * neckLen + chibi * 0.2
	local headSize = 0.9 + chibi * 0.55
	local hz = -2.15 - 0.35 * neckLen
	local head = b:add("Head", "ball", { headSize * 0.9, headSize * 0.75, headSize * 1.2 }, { 0, headY, hz }, {
		parent = headParent,
		far = true,
		joint = { role = "head", at = { 0, headY - 0.25, -1.85 - 0.3 * neckLen } },
	})
	if not small then
		b:add("Jaw", "wedge", { headSize * 0.7, 0.28, headSize * 0.95 }, { 0, headY - 0.3, hz - headSize * 0.55 }, {
			tone = "light",
			parent = head.name,
			joint = { role = "jaw", at = { 0, headY - 0.2, hz - 0.1 } },
		})
	end
	b:add(
		"Snout",
		"wedge",
		{ headSize * 0.6, headSize * 0.4, headSize * 0.8 },
		{ 0, headY + 0.02, hz - headSize * 0.65 },
		{ parent = head.name }
	)
	b:pair("Horn", "wedge", { 0.16, 0.22, 0.85 }, { 0.25, headY + headSize * 0.42, hz + headSize * 0.5 }, {
		tone = "detail",
		material = "detail",
		rot = { -25, 180, 0 },
		parent = head.name,
	})
	b:eyes(
		head.name,
		{ headSize * 0.3, headY + 0.12, hz - headSize * 0.42 },
		0.14 + chibi * 0.1,
		b:get("glowEyes", 0) > 0
	)
	local prev = "Body"
	local z = 1.45
	for i = 1, if small then 1 else 3 do
		local k = 1 - i * 0.22
		local seg = b:add(
			`Tail{i}`,
			"ball",
			{ 0.9 * k * w / 1.7, 0.75 * k, 1.25 },
			{ 0, bodyY - 0.1 - i * 0.12, z + 0.55 },
			{
				tone = if i == 3 then "shade" else "base",
				parent = prev,
				joint = { role = "tail", phase = i * 0.15, amp = 0.7, at = { 0, bodyY - i * 0.12, z } },
			}
		)
		prev = seg.name
		z += 1.05
	end
	if not small then
		b:add(
			"TailSpike",
			"wedge",
			{ 0.35, 0.5, 0.8 },
			{ 0, bodyY - 0.35, z + 0.35 },
			{ tone = "detail", parent = prev }
		)
	end
	if hasWings then
		wings(
			b,
			{ w * 0.35, bodyY + 0.6, -0.35 },
			5.2 * span * (1 - chibi * 0.45),
			1.8 * math.sqrt(span) * (1 - chibi * 0.3),
			"accent",
			"Body",
			true
		)
	end
	if legs >= 4 then
		b:pair("LegF", "cyl", { legTop + 0.1, 0.48, 0.48 }, { w * 0.32, legTop / 2, -0.9 }, {
			tone = "shade",
			rot = { 0, 0, 90 },
			parent = "Body",
			joint = { role = "leg", phase = 0, at = { w * 0.32, legTop, -0.9 } },
		})
	end
	b:pair("LegB", "cyl", { legTop + 0.15, 0.55, 0.55 }, { w * 0.34, legTop / 2, 0.95 }, {
		tone = "shade",
		rot = { 0, 0, 90 },
		parent = "Body",
		joint = { role = "leg", phase = 0.5, at = { w * 0.34, legTop, 0.95 } },
	})
	b:socket("Head", { 0, headY + headSize * 0.4, hz }, head.name)
	b:socket("Back", { 0, bodyY + 0.75, 0.0 }, "Body")
	b:socket("Tail", { 0, bodyY - 0.2, 2.0 }, "Tail1")
end

return Plans
