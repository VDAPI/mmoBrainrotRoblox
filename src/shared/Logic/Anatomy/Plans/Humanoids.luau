--!strict
-- Upright body plans (S24): humanoid (bandits, goblins, cultists, skeletons, witches, orcs, dwarves, giants...)
-- and beast (werewolf, troll, ghoul, yeti: hunched, long arms, bent-back legs). Ground space at scale 1.
-- Sockets: Head, Back, Hand_R, Hand_L, Hip.

local Builder = require("../Builder")

type B = Builder.Builder

local Plans = {}

-- Humanoid. build: height (1 ≈ 5 studs), bulk (width), head (head size), hunch (0..1 forward stoop), bones
-- (skeleton), robe (long robe instead of legs), ears (pointed ears length), nose (long nose), muzzle (snout),
-- tail (0/1).
function Plans.humanoid(b: B)
	local height = b:get("height", 1)
	local bulk = b:get("bulk", 1)
	local headScale = b:get("head", 1)
	local hunch = b:get("hunch", 0)
	local bones = b:get("bones", 0) > 0
	local robe = b:get("robe", 0) > 0
	local ears = b:get("ears", 0)
	local nose = b:get("nose", 0)
	local muzzle = b:get("muzzle", 0)
	local limb = if bones then 0.22 else 0.42 * math.sqrt(bulk)
	local legLen = 2.0 * height
	local torsoH = 1.55 * height
	local torsoW = 1.35 * bulk
	local torsoD = 0.85 * bulk
	local torsoY = legLen + torsoH / 2 + 0.05
	local lean = hunch * 25
	local forward = hunch * 0.5
	b:coreBody("Torso", "ball", { torsoW, torsoH, torsoD }, { 0, torsoY, forward * 0.3 }, {
		tone = if bones then "light" else "base",
		material = if bones then "base" else "accent",
		rot = { -lean, 0, 0 },
		transparency = if bones then 0.6 else nil,
	})
	if bones then
		for i = 1, 3 do
			b:add("Rib", "cyl", { torsoW * 0.95, 0.12, 0.12 }, { 0, torsoY + 0.45 - i * 0.32, -torsoD * 0.25 }, {
				tone = "light",
				parent = "Torso",
			})
		end
		b:add(
			"Spine",
			"cyl",
			{ torsoH, 0.18, 0.18 },
			{ 0, torsoY, torsoD * 0.2 },
			{ tone = "light", rot = { 0, 0, 90 }, parent = "Torso" }
		)
	end
	b:add("Belt", "cyl", { 0.3, torsoW * 0.98, torsoD * 1.1 }, { 0, legLen + 0.12, forward * 0.1 }, {
		tone = "detail",
		material = "detail",
		rot = { 0, 0, 90 },
		parent = "Torso",
	})
	local headSize = 0.95 * headScale * math.sqrt(height)
	local headY = legLen + torsoH + headSize * 0.5 - hunch * 0.35
	local headZ = -forward * 0.9
	local head = b:add("Head", "ball", { headSize, headSize * 1.05, headSize }, { 0, headY, headZ }, {
		tone = if bones then "light" else "detail",
		material = if bones then "base" else "SmoothPlastic",
		parent = "Torso",
		far = true,
		joint = { role = "head", at = { 0, headY - headSize * 0.4, headZ } },
	})
	local face = headZ - headSize * 0.45
	if muzzle > 0 then
		b:add(
			"Muzzle",
			"wedge",
			{ headSize * 0.55, headSize * 0.42, 0.6 * muzzle },
			{ 0, headY - headSize * 0.12, face - 0.25 * muzzle },
			{
				tone = "detail",
				parent = head.name,
			}
		)
	end
	if nose > 0 then
		b:add("Nose", "wedge", { 0.18, 0.3 * nose, 0.45 * nose }, { 0, headY - 0.05, face - 0.18 * nose }, {
			tone = "detail",
			rot = { 90, 0, 0 },
			parent = head.name,
		})
	end
	if ears > 0 then
		b:pair("Ear", "wedge", { 0.1, 0.3, 0.75 * ears }, { headSize * 0.5 + 0.25 * ears, headY + 0.1, headZ + 0.05 }, {
			tone = "detail",
			rot = { 0, -90, 15 },
			parent = head.name,
		})
	end
	if bones then
		b:add(
			"Jaw",
			"block",
			{ headSize * 0.6, headSize * 0.22, headSize * 0.5 },
			{ 0, headY - headSize * 0.5, headZ - headSize * 0.15 },
			{
				tone = "light",
				parent = head.name,
				joint = { role = "jaw", at = { 0, headY - headSize * 0.35, headZ + headSize * 0.1 } },
			}
		)
	end
	b:eyes(
		head.name,
		{ headSize * 0.22, headY + headSize * 0.08, face + 0.05 },
		0.13 * headScale,
		bones or b:get("glowEyes", 0) > 0
	)
	-- Arms: upper arm (jointed at the shoulder), forearm and hand welded below it.
	local shoulderY = torsoY + torsoH * 0.35 - hunch * 0.2
	local shoulderX = torsoW / 2 + limb * 0.45
	local armLen = 1.05 * height
	b:pair("Arm", "cyl", { armLen, limb, limb }, { shoulderX, shoulderY - armLen / 2, forward * 0.2 }, {
		tone = if bones then "light" else "base",
		material = if bones then "base" else "accent",
		rot = { 0, 0, 90 },
		parent = "Torso",
		joint = { role = "arm", at = { shoulderX, shoulderY, forward * 0.2 } },
	})
	b:pair(
		"Forearm",
		"cyl",
		{ armLen * 0.95, limb * 0.92, limb * 0.92 },
		{ shoulderX + 0.05, shoulderY - armLen * 1.4, forward * 0.2 - 0.2 },
		{
			tone = if bones then "light" else "detail",
			material = if bones then "base" else "SmoothPlastic",
			rot = { 15, 0, 90 },
			parent = "Arm*",
		}
	)
	local handY = shoulderY - armLen * 1.95
	b:pair("Hand", "ball", { limb * 1.3, limb * 1.3, limb * 1.3 }, { shoulderX + 0.05, handY, forward * 0.2 - 0.4 }, {
		tone = if bones then "light" else "detail",
		material = "SmoothPlastic",
		parent = "Arm*",
	})
	if robe then
		b:add("Robe", "ball", { torsoW * 1.35, legLen * 1.45, torsoD * 1.7 }, { 0, legLen * 0.62, forward * 0.1 }, {
			tone = "accent",
			material = "Fabric",
			parent = "Torso",
			far = true,
		})
	else
		local legW = if bones then 0.24 else 0.5 * math.sqrt(bulk)
		b:pair("Leg", "cyl", { legLen, legW, legW }, { torsoW * 0.25, legLen / 2, 0 }, {
			tone = if bones then "light" else "shade",
			material = if bones then "base" else "accent",
			rot = { 0, 0, 90 },
			parent = "Torso",
			joint = { role = "leg", phase = 0, at = { torsoW * 0.25, legLen, 0 } },
		})
		b:pair("Foot", "block", { legW * 1.15, 0.28, legW * 1.9 }, { torsoW * 0.25, 0.14, -legW * 0.4 }, {
			tone = if bones then "light" else "#3A2E26",
			material = if bones then "base" else "Leather",
			parent = "Leg*",
		})
	end
	if b:get("tail", 0) > 0 then
		b:add("Tail", "cyl", { 1.6 * height, 0.3, 0.3 }, { 0, legLen * 0.6, 0.85 }, {
			rot = { 0, 90, 35 },
			parent = "Torso",
			joint = { role = "tail", at = { 0, legLen, 0.35 } },
		})
	end
	b:socket("Head", { 0, headY + headSize * 0.5, headZ }, head.name)
	b:socket("Back", { 0, torsoY + 0.2, torsoD * 0.55 + forward * 0.3 }, "Torso")
	b:socket("Hand_R", { shoulderX + 0.05, handY, forward * 0.2 - 0.5 }, "ArmR")
	b:socket("Hand_L", { -shoulderX - 0.05, handY, forward * 0.2 - 0.5 }, "ArmL")
	b:socket("Hip", { torsoW * 0.5, legLen + 0.1, 0 }, "Torso")
	b:socket("Chest", { 0, torsoY + torsoH * 0.15, -torsoD * 0.5 + forward * 0.1 }, "Torso")
	b:socket("Shoulders", { 0, shoulderY + 0.25, forward * 0.2 }, "Torso")
end

-- Beast: hunched heavy torso, long arms reaching the ground, bent-back legs. build: height, bulk, arms (arm
-- length), wolf (wolf head), gaunt (thin, ribs), nose (big nose), head.
function Plans.beast(b: B)
	local height = b:get("height", 1)
	local bulk = b:get("bulk", 1)
	local gaunt = b:get("gaunt", 0) > 0
	local wolf = b:get("wolf", 0) > 0
	local arms = b:get("arms", 1)
	local nose = b:get("nose", 0)
	local headScale = b:get("head", 1)
	local legTop = 1.7 * height
	local torsoW = (if gaunt then 1.25 else 1.85) * bulk
	local torsoH = 1.9 * height
	local torsoY = legTop + torsoH * 0.45
	b:coreBody("Torso", "ball", { torsoW, torsoH, 1.4 * bulk }, { 0, torsoY, -0.25 }, { rot = { -30, 0, 0 } })
	b:add("Hump", "ball", { torsoW * 0.95, torsoH * 0.6, 1.2 * bulk }, { 0, torsoY + torsoH * 0.35, 0.2 }, {
		tone = "shade",
		far = true,
		parent = "Torso",
	})
	if not gaunt then
		b:add("Chest", "ball", { torsoW * 0.8, torsoH * 0.55, 0.8 * bulk }, { 0, torsoY + 0.1, -0.85 * bulk }, {
			tone = "light",
			parent = "Torso",
		})
	else
		for i = 1, 3 do
			b:add(
				"Rib",
				"cyl",
				{ torsoW * 0.85, 0.12, 0.12 },
				{ 0, torsoY + 0.45 - i * 0.3, -0.75 },
				{ tone = "shade", parent = "Torso" }
			)
		end
	end
	local headY = torsoY + torsoH * 0.5
	local headZ = -1.15 * bulk - 0.2
	local hs = (if wolf then 1.05 else 0.85) * headScale * math.sqrt(height)
	local head = b:add("Head", "ball", { hs, hs * 0.95, hs }, { 0, headY, headZ }, {
		tone = if wolf then "base" else "detail",
		material = if wolf then "base" else "SmoothPlastic",
		parent = "Torso",
		far = true,
		joint = { role = "head", at = { 0, headY - hs * 0.3, headZ + 0.3 } },
	})
	if wolf then
		b:add("Snout", "wedge", { hs * 0.55, hs * 0.45, hs * 0.85 }, { 0, headY - hs * 0.15, headZ - hs * 0.75 }, {
			tone = "light",
			parent = head.name,
		})
		b:pair("Ear", "wedge", { 0.14, hs * 0.55, hs * 0.38 }, { hs * 0.3, headY + hs * 0.65, headZ + 0.05 }, {
			tone = "shade",
			rot = { 0, 180, -10 },
			parent = head.name,
		})
	end
	if nose > 0 then
		b:add("Nose", "ball", { 0.35 * nose, 0.45 * nose, 0.5 * nose }, { 0, headY - 0.05, headZ - hs * 0.5 }, {
			tone = "detail",
			parent = head.name,
		})
	end
	b:eyes(head.name, { hs * 0.22, headY + hs * 0.12, headZ - hs * 0.45 }, 0.13, b:get("glowEyes", 0) > 0)
	local shoulderY = torsoY + torsoH * 0.25
	local shoulderX = torsoW / 2 + 0.15
	local armLen = 1.25 * height * arms
	local thick = (if gaunt then 0.3 else 0.55) * bulk
	b:pair("Arm", "cyl", { armLen, thick, thick }, { shoulderX, shoulderY - armLen / 2, -0.75 }, {
		rot = { 0, 0, 90 },
		parent = "Torso",
		joint = { role = "arm", at = { shoulderX, shoulderY, -0.75 } },
	})
	b:pair(
		"Forearm",
		"cyl",
		{ armLen, thick * 0.9, thick * 0.9 },
		{ shoulderX + 0.1, shoulderY - armLen * 1.45, -1.05 },
		{
			tone = "shade",
			rot = { 20, 0, 90 },
			parent = "Arm*",
		}
	)
	local handY = math.max(0.3, shoulderY - armLen * 1.95)
	b:pair("Hand", "ball", { thick * 1.5, thick * 1.2, thick * 1.6 }, { shoulderX + 0.1, handY, -1.35 }, {
		tone = "detail",
		material = "SmoothPlastic",
		parent = "Arm*",
	})
	b:pair("Claw", "wedge", { thick * 1.1, 0.16, 0.45 }, { shoulderX + 0.1, handY - thick * 0.45, -1.85 }, {
		tone = "#E8E0CC",
		material = "SmoothPlastic",
		parent = "Arm*",
	})
	-- Digitigrade legs: thigh forward, shin back.
	b:pair("Thigh", "cyl", { legTop * 0.6, thick * 1.15, thick * 1.15 }, { torsoW * 0.28, legTop * 0.72, -0.15 }, {
		tone = "shade",
		rot = { 0, 90, -70 },
		parent = "Torso",
		joint = { role = "leg", phase = 0, at = { torsoW * 0.28, legTop, 0.0 } },
	})
	b:pair("Shin", "cyl", { legTop * 0.65, thick * 0.9, thick * 0.9 }, { torsoW * 0.28, legTop * 0.3, 0.15 }, {
		tone = "shade",
		rot = { 0, 90, 70 },
		parent = "Thigh*",
	})
	b:pair("Foot", "wedge", { thick * 1.1, 0.3, thick * 2.2 }, { torsoW * 0.28, 0.15, -0.2 }, {
		tone = "detail",
		parent = "Thigh*",
	})
	b:socket("Head", { 0, headY + hs * 0.5, headZ }, head.name)
	b:socket("Back", { 0, torsoY + torsoH * 0.45, 0.45 }, "Torso")
	b:socket("Hand_R", { shoulderX + 0.1, handY + 0.1, -1.6 }, "ArmR")
	b:socket("Hand_L", { -shoulderX - 0.1, handY + 0.1, -1.6 }, "ArmL")
	b:socket("Hip", { torsoW * 0.5, legTop, 0 }, "Torso")
	b:socket("Shoulders", { 0, shoulderY + 0.3, -0.5 }, "Torso")
end

return Plans
