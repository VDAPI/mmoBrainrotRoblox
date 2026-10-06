--!strict
-- Four-legged body plans (S24): hare, canine (wolf, lynx, hyena, leopard), bear, boar, toad, lizard,
-- mammoth. Ground space at scale 1 (see Builder). Every plan sets the core body, the head joint, the legs and
-- the sockets Head, Back, Tail (and Hip) for accessories.

local Builder = require("../Builder")

type B = Builder.Builder

local Plans = {}

-- Vertical cylinder leg from the ground to `top`, jointed at the top.
local function leg(b: B, name: string, x: number, z: number, top: number, thick: number, phase: number, tone: string?)
	b:add(name, "cyl", { top, thick, thick }, { x, top / 2, z }, {
		tone = tone or "shade",
		rot = { 0, 0, 90 },
		parent = b.core,
		joint = { role = "leg", side = if x < 0 then -1 else 1, phase = phase, at = { x, top, z } },
	})
end

local function fourLegs(b: B, halfWidth: number, front: number, back: number, top: number, thick: number, tone: string?)
	leg(b, "LegFL", -halfWidth, front, top, thick, 0, tone)
	leg(b, "LegFR", halfWidth, front, top, thick, 0.5, tone)
	leg(b, "LegBL", -halfWidth, back, top, thick, 0.5, tone)
	leg(b, "LegBR", halfWidth, back, top, thick, 0, tone)
end

-- Hare: round body, long ears, puffball tail, light belly, big hind legs (hops).
function Plans.hare(b: B)
	local chibi = b:get("chibi", 0)
	b:coreBody("Body", "ball", { 1.3, 1.15, 1.7 }, { 0, 0.95, 0.15 })
	b:add("Belly", "ball", { 1.0, 0.8, 1.3 }, { 0, 0.8, -0.05 }, { tone = "light", parent = "Body" })
	local head = b:add("Head", "ball", { 0.95 + chibi * 0.3, 0.85 + chibi * 0.3, 0.95 }, { 0, 1.55, -0.85 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 1.35, -0.6 } },
	})
	b:add("Muzzle", "ball", { 0.5, 0.38, 0.4 }, { 0, 1.42, -1.3 }, { tone = "light", parent = head.name })
	b:pair(
		"Ear",
		"ball",
		{ 0.24, 1.15, 0.38 },
		{ 0.2, 2.35, -0.75 },
		{ rot = { -10, 0, -8 }, parent = head.name, far = true }
	)
	b:pair(
		"EarIn",
		"ball",
		{ 0.13, 0.85, 0.2 },
		{ 0.2, 2.33, -0.85 },
		{ tone = "accent", rot = { -10, 0, -8 }, parent = head.name }
	)
	b:eyes(head.name, { 0.3, 1.65, -1.2 }, 0.2 + chibi * 0.08, b:get("glowEyes", 0) > 0)
	b:add(
		"Tail",
		"ball",
		{ 0.5, 0.5, 0.5 },
		{ 0, 1.05, 1.05 },
		{ tone = "light", parent = "Body", joint = { role = "tail", at = { 0, 1.05, 0.85 } } }
	)
	-- Big hind legs, short front legs.
	b:pair("Thigh", "ball", { 0.45, 0.7, 0.9 }, { 0.5, 0.55, 0.45 }, {
		tone = "shade",
		parent = "Body",
		joint = { role = "leg", phase = 0, at = { 0.5, 0.9, 0.45 } },
	})
	leg(b, "LegFL", -0.3, -0.45, 0.6, 0.22, 0.5, "shade")
	leg(b, "LegFR", 0.3, -0.45, 0.6, 0.22, 0.5, "shade")
	b:socket("Head", { 0, 2.0, -0.85 }, head.name)
	b:socket("Back", { 0, 1.5, 0.1 }, "Body")
	b:socket("Tail", { 0, 1.05, 1.1 }, "Body")
end

-- Canine: wolf / lynx / hyena / leopard. build: snout (length), ears (size), tail (0 stub, 1 brush, 2 long
-- thick), mane (0/1), frontHigh (hyena), chibi (pets).
function Plans.canine(b: B)
	local snout = b:get("snout", 1)
	local ears = b:get("ears", 1)
	local tail = b:get("tail", 1)
	local mane = b:get("mane", 1)
	local frontHigh = b:get("frontHigh", 0)
	local chibi = b:get("chibi", 0)
	local thinTail = b:get("thinTail", 0) > 0
	local h = 1.25 - chibi * 0.35 -- leg length
	local bodyY = h + 0.45
	b:coreBody(
		"Body",
		"ball",
		{ 1.35, 1.15, 2.6 },
		{ 0, bodyY + frontHigh * 0.1, 0.2 },
		{ rot = { -frontHigh * 8, 0, 0 } }
	)
	b:add(
		"Chest",
		"ball",
		{ 1.3, 1.35, 1.25 },
		{ 0, bodyY + 0.15 + frontHigh * 0.25, -0.85 },
		{ tone = "light", parent = "Body" }
	)
	if mane > 0 then
		b:add(
			"Mane",
			"ball",
			{ 1.45, 1.15, 1.05 },
			{ 0, bodyY + 0.55 + frontHigh * 0.3, -0.75 },
			{ tone = "shade", parent = "Body" }
		)
	end
	local headY = bodyY + 0.75 + frontHigh * 0.35
	local headSize = 0.95 + chibi * 0.45
	local head = b:add("Head", "ball", { headSize, headSize * 0.92, headSize * 1.05 }, { 0, headY, -1.6 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, headY - 0.2, -1.25 } },
	})
	local snoutLen = 0.75 * snout * (1 - chibi * 0.5)
	b:add("Snout", "wedge", { 0.55, 0.5, snoutLen }, { 0, headY - 0.18, -1.6 - headSize * 0.45 - snoutLen / 2 + 0.1 }, {
		tone = "light",
		parent = head.name,
	})
	b:add("Nose", "ball", { 0.24, 0.2, 0.2 }, { 0, headY - 0.02, -1.6 - headSize * 0.45 - snoutLen + 0.15 }, {
		tone = "#2A2426",
		parent = head.name,
	})
	b:pair("Ear", "wedge", { 0.14, 0.5 * ears, 0.36 * ears }, { 0.3, headY + headSize * 0.5 + 0.18 * ears, -1.5 }, {
		tone = "shade",
		rot = { 0, 180, -10 },
		parent = head.name,
	})
	b:eyes(head.name, { 0.26, headY + 0.12, -1.6 - headSize * 0.42 }, 0.17 + chibi * 0.1, b:get("glowEyes", 0) > 0)
	if thinTail then
		b:add("Tail", "cyl", { 1.3, 0.16, 0.16 }, { 0, bodyY + 0.45, 1.75 }, {
			rot = { 0, 90, 45 },
			parent = "Body",
			joint = { role = "tail", at = { 0, bodyY + 0.2, 1.3 } },
		})
	elseif tail >= 1 then
		local t1 = b:add("Tail", "ball", { 0.42, 0.42, 1.0 + (tail - 1) * 0.4 }, { 0, bodyY + 0.35, 1.75 }, {
			far = true,
			rot = { -35 + tail * 8, 0, 0 },
			parent = "Body",
			joint = { role = "tail", at = { 0, bodyY + 0.2, 1.35 } },
		})
		b:add(
			"TailTip",
			"ball",
			{ 0.55, 0.55, 0.85 + (tail - 1) * 0.3 },
			{ 0, bodyY + 0.75 - (tail - 1) * 0.3, 2.45 + (tail - 1) * 0.3 },
			{
				tone = "light",
				rot = { -45 + tail * 12, 0, 0 },
				parent = t1.name,
			}
		)
	else
		b:add("Tail", "ball", { 0.35, 0.35, 0.5 }, { 0, bodyY + 0.3, 1.45 }, {
			parent = "Body",
			joint = { role = "tail", at = { 0, bodyY + 0.25, 1.3 } },
		})
	end
	fourLegs(b, 0.45, -0.85, 1.0, h + 0.1 + frontHigh * 0.15, 0.36 - chibi * 0.06)
	b:socket("Head", { 0, headY + headSize * 0.5, -1.6 }, head.name)
	b:socket("Back", { 0, bodyY + 0.55, 0.2 }, "Body")
	b:socket("Tail", { 0, bodyY + 0.3, 1.5 }, "Body")
	b:socket("Hip", { 0, bodyY - 0.2, 0.9 }, "Body")
end

-- Bear: heavy body with a shoulder hump, round ears, light muzzle, claws.
function Plans.bear(b: B)
	b:coreBody("Body", "ball", { 2.1, 1.75, 3.1 }, { 0, 2.0, 0.25 })
	b:add("Hump", "ball", { 1.8, 1.4, 1.5 }, { 0, 2.65, -0.65 }, { tone = "shade", parent = "Body", far = true })
	b:add("Chest", "ball", { 1.6, 1.5, 1.2 }, { 0, 1.85, -1.1 }, { tone = "light", parent = "Body" })
	local head = b:add("Head", "ball", { 1.3, 1.15, 1.3 }, { 0, 2.5, -2.05 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 2.3, -1.6 } },
	})
	b:add("Muzzle", "ball", { 0.75, 0.6, 0.8 }, { 0, 2.3, -2.75 }, { tone = "light", parent = head.name })
	b:add("Nose", "ball", { 0.3, 0.24, 0.22 }, { 0, 2.42, -3.15 }, { tone = "#2A2426", parent = head.name })
	b:pair("Ear", "ball", { 0.42, 0.42, 0.24 }, { 0.45, 3.05, -1.95 }, { tone = "shade", parent = head.name })
	b:eyes(head.name, { 0.3, 2.65, -2.6 }, 0.18, b:get("glowEyes", 0) > 0)
	b:add(
		"Tail",
		"ball",
		{ 0.45, 0.45, 0.45 },
		{ 0, 2.3, 1.85 },
		{ parent = "Body", joint = { role = "tail", at = { 0, 2.3, 1.7 } } }
	)
	fourLegs(b, 0.7, -1.0, 1.15, 1.5, 0.62)
	b:pair(
		"Claws",
		"wedge",
		{ 0.55, 0.22, 0.4 },
		{ 0.7, 0.11, -1.35 },
		{ tone = "detail", material = "detail", parent = "LegF*" }
	)
	b:socket("Head", { 0, 3.1, -2.05 }, head.name)
	b:socket("Back", { 0, 3.2, -0.4 }, "Body")
	b:socket("Chest", { 0, 2.0, -1.68 }, "Chest")
	b:socket("Tail", { 0, 2.3, 1.8 }, "Body")
	b:socket("Hip", { 0, 1.6, 1.0 }, "Body")
end

-- Boar: massive front, low back, snout cylinder, white tusks, bristle ridge.
function Plans.boar(b: B)
	b:coreBody("Body", "ball", { 1.7, 1.55, 2.7 }, { 0, 1.55, 0.25 })
	b:add("Shoulders", "ball", { 1.85, 1.75, 1.4 }, { 0, 1.75, -0.65 }, { tone = "shade", parent = "Body", far = true })
	local head = b:add("Head", "ball", { 1.15, 1.0, 1.2 }, { 0, 1.55, -1.7 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 1.55, -1.2 } },
	})
	b:add(
		"Snout",
		"cyl",
		{ 0.6, 0.62, 0.62 },
		{ 0, 1.35, -2.4 },
		{ tone = "light", rot = { 0, 90, 0 }, parent = head.name }
	)
	b:add(
		"Nose",
		"cyl",
		{ 0.1, 0.5, 0.5 },
		{ 0, 1.35, -2.72 },
		{ tone = "accent", rot = { 0, 90, 0 }, parent = head.name }
	)
	b:pair(
		"Tusk",
		"wedge",
		{ 0.14, 0.5, 0.3 },
		{ 0.33, 1.4, -2.35 },
		{ tone = "#E8E2D0", material = "SmoothPlastic", rot = { 0, 180, 0 }, parent = head.name }
	)
	b:pair(
		"Ear",
		"wedge",
		{ 0.14, 0.45, 0.35 },
		{ 0.4, 2.15, -1.55 },
		{ tone = "shade", rot = { 25, 180, -25 }, parent = head.name }
	)
	b:eyes(head.name, { 0.33, 1.75, -2.12 }, 0.15, b:get("glowEyes", 0) > 0)
	for i = 0, 3 do
		b:add("Bristle", "wedge", { 0.25, 0.42 - i * 0.05, 0.5 }, { 0, 2.5 - i * 0.12, -0.75 + i * 0.5 }, {
			tone = "detail",
			parent = "Body",
		})
	end
	b:add(
		"Tail",
		"cyl",
		{ 0.6, 0.12, 0.12 },
		{ 0, 1.75, 1.7 },
		{ rot = { 0, 90, 30 }, parent = "Body", joint = { role = "tail", at = { 0, 1.8, 1.5 } } }
	)
	fourLegs(b, 0.55, -0.8, 1.0, 1.0, 0.42)
	b:socket("Head", { 0, 2.1, -1.7 }, head.name)
	b:socket("Back", { 0, 2.4, 0 }, "Body")
	b:socket("Tail", { 0, 1.7, 1.6 }, "Body")
end

-- Toad: squat ball, wide jaw, eyes on top, folded hind legs, warts.
function Plans.toad(b: B)
	local chibi = b:get("chibi", 0)
	b:coreBody("Body", "ball", { 2.0, 1.35, 1.9 }, { 0, 0.95, 0.1 })
	b:add("Belly", "ball", { 1.7, 0.9, 1.6 }, { 0, 0.7, -0.05 }, { tone = "light", parent = "Body" })
	local head = b:add("Head", "ball", { 1.8, 0.95, 1.2 }, { 0, 1.25, -0.75 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 1.1, -0.4 } },
	})
	b:add("Jaw", "ball", { 1.7, 0.45, 1.1 }, { 0, 0.85, -0.85 }, {
		tone = "light",
		far = true,
		parent = head.name,
		joint = { role = "jaw", at = { 0, 0.95, -0.4 } },
	})
	if chibi == 0 then
		b:add(
			"Mouth",
			"block",
			{ 1.5, 0.08, 0.95 },
			{ 0, 1.05, -0.95 },
			{ tone = "#5A2A2E", material = "SmoothPlastic", parent = head.name }
		)
	end
	b:pair("EyeBump", "ball", { 0.55, 0.55, 0.55 }, { 0.55, 1.75, -0.8 }, { parent = head.name })
	b:eyes(head.name, { 0.55, 1.85, -1.0 }, 0.34 + chibi * 0.08, b:get("glowEyes", 0) > 0)
	b:pair("Thigh", "ball", { 0.55, 0.8, 1.3 }, { 0.95, 0.55, 0.55 }, {
		tone = "shade",
		parent = "Body",
		joint = { role = "leg", phase = 0, at = { 0.85, 0.8, 0.3 } },
	})
	if chibi == 0 then
		b:pair("Foot", "block", { 0.5, 0.15, 0.75 }, { 1.1, 0.08, 0.2 }, { tone = "shade", parent = "Thigh*" })
	end
	leg(b, "LegFL", -0.65, -0.55, 0.65, 0.28, 0.5, "shade")
	leg(b, "LegFR", 0.65, -0.55, 0.65, 0.28, 0.5, "shade")
	for i = 1, if chibi > 0 then 2 else 4 do
		local a = i * 1.7
		b:add("Wart", "ball", { 0.3, 0.2, 0.3 }, { math.cos(a) * 0.6, 1.5, 0.3 + math.sin(a) * 0.45 }, {
			tone = "accent",
			parent = "Body",
		})
	end
	b:socket("Head", { 0, 1.85, -0.75 }, head.name)
	b:socket("Back", { 0, 1.6, 0.2 }, "Body")
end

-- Lizard: flat long body, segmented tail, splayed legs. build: heavy (basilisk), crest (0/1).
function Plans.lizard(b: B)
	local heavy = b:get("heavy", 0)
	local w = 1.2 + heavy * 0.5
	b:coreBody("Body", "ball", { w, 0.85 + heavy * 0.3, 2.6 + heavy * 0.6 }, { 0, 0.85 + heavy * 0.15, 0.1 })
	local head = b:add(
		"Head",
		"ball",
		{ 0.95 + heavy * 0.3, 0.6 + heavy * 0.15, 1.2 + heavy * 0.2 },
		{ 0, 1.0 + heavy * 0.2, -1.75 - heavy * 0.3 },
		{
			parent = "Body",
			far = true,
			joint = { role = "head", at = { 0, 0.95, -1.3 } },
		}
	)
	b:add("Jaw", "wedge", { 0.7 + heavy * 0.2, 0.22, 0.75 }, { 0, 0.8 + heavy * 0.15, -2.0 - heavy * 0.3 }, {
		tone = "light",
		parent = head.name,
		joint = { role = "jaw", at = { 0, 0.9, -1.75 } },
	})
	b:eyes(head.name, { 0.36 + heavy * 0.1, 1.2 + heavy * 0.25, -2.05 - heavy * 0.3 }, 0.17, b:get("glowEyes", 0) > 0)
	local prev = "Body"
	local z = 1.45 + heavy * 0.3
	for i = 1, 3 do
		local s = 1 - i * 0.22
		local seg = b:add(`Tail{i}`, "ball", { 0.75 * s * w, 0.5 * s, 1.0 }, { 0, 0.78 - i * 0.08, z + 0.35 }, {
			tone = if i == 3 then "shade" else "base",
			far = i == 1,
			parent = prev,
			joint = { role = "segment", phase = i * 0.18, at = { 0, 0.8, z - 0.15 } },
		})
		prev = seg.name
		z += 0.9
	end
	b:pair("Leg", "cyl", { 0.85, 0.3 + heavy * 0.1, 0.3 + heavy * 0.1 }, { 0.75 + heavy * 0.2, 0.42, -0.75 }, {
		tone = "shade",
		rot = { 0, 0, -55 },
		parent = "Body",
		joint = { role = "leg", phase = 0, at = { 0.55, 0.75, -0.75 } },
	})
	b:pair("LegB", "cyl", { 0.85, 0.32 + heavy * 0.1, 0.32 + heavy * 0.1 }, { 0.75 + heavy * 0.2, 0.42, 0.95 }, {
		tone = "shade",
		rot = { 0, 0, -55 },
		parent = "Body",
		joint = { role = "leg", phase = 0.5, at = { 0.55, 0.75, 0.95 } },
	})
	b:add("BellyStripe", "ball", { w * 0.7, 0.4, 2.0 }, { 0, 0.55, 0.0 }, { tone = "light", parent = "Body" })
	b:socket("Head", { 0, 1.35 + heavy * 0.3, -1.75 }, head.name)
	b:socket("Back", { 0, 1.3 + heavy * 0.3, 0.1 }, "Body")
	b:socket("Tail", { 0, 0.9, 1.6 }, "Body")
end

-- Mammoth: huge furry body, hump, trunk from segments, curled tusks, small ears, pillar legs.
function Plans.mammoth(b: B)
	b:coreBody("Body", "ball", { 2.6, 2.4, 3.6 }, { 0, 3.0, 0.3 }, { material = "base" })
	b:add("Hump", "ball", { 2.2, 1.6, 1.6 }, { 0, 4.1, -0.6 }, { tone = "shade", parent = "Body", far = true })
	b:add("Skirt", "ball", { 2.7, 1.2, 3.4 }, { 0, 2.1, 0.3 }, { tone = "shade", parent = "Body" })
	local head = b:add("Head", "ball", { 1.8, 1.8, 1.6 }, { 0, 3.5, -2.0 }, {
		parent = "Body",
		far = true,
		joint = { role = "head", at = { 0, 3.3, -1.5 } },
	})
	b:add("HeadFur", "ball", { 1.6, 0.9, 1.2 }, { 0, 4.35, -1.95 }, { tone = "shade", parent = head.name })
	local prev = head.name
	for i = 1, 4 do
		local s = 1 - i * 0.14
		local seg = b:add(`Trunk{i}`, "cyl", { 0.75, 0.7 * s, 0.7 * s }, { 0, 3.3 - i * 0.62, -2.7 - i * 0.1 }, {
			tone = if i == 4 then "light" else "base",
			rot = { 0, 0, 90 },
			parent = prev,
			joint = { role = "segment", phase = i * 0.15, amp = 0.8, at = { 0, 3.65 - i * 0.62, -2.65 - i * 0.1 } },
		})
		prev = seg.name
	end
	b:pair(
		"Tusk",
		"cyl",
		{ 1.5, 0.28, 0.28 },
		{ 0.55, 2.55, -2.95 },
		{ tone = "#E8E0CC", material = "SmoothPlastic", rot = { 0, 70, -40 }, parent = head.name }
	)
	b:pair(
		"TuskTip",
		"cyl",
		{ 0.9, 0.2, 0.2 },
		{ 0.75, 2.45, -3.75 },
		{ tone = "#E8E0CC", material = "SmoothPlastic", rot = { 0, 30, 40 }, parent = "Tusk*" }
	)
	b:pair("Ear", "ball", { 0.25, 0.75, 0.65 }, { 0.95, 3.6, -1.75 }, { tone = "shade", parent = head.name })
	b:eyes(head.name, { 0.55, 3.75, -2.6 }, 0.18, b:get("glowEyes", 0) > 0)
	fourLegs(b, 0.9, -1.2, 1.35, 2.2, 0.85)
	b:add(
		"Tail",
		"cyl",
		{ 0.9, 0.18, 0.18 },
		{ 0, 3.0, 2.15 },
		{ rot = { 0, 90, 60 }, parent = "Body", joint = { role = "tail", at = { 0, 3.3, 2.0 } } }
	)
	b:socket("Head", { 0, 4.6, -2.0 }, head.name)
	b:socket("Back", { 0, 4.8, -0.4 }, "Body")
	b:socket("Tail", { 0, 3.1, 2.0 }, "Body")
end

return Plans
