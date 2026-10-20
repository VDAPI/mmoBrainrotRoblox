--!strict
-- Test helper (S114, B4): the three layers of a skill's look (DESIGN-16 §2.6) and the signature that tells two skills
-- of one class apart (§2.7). Not a spec: tests/skillmotion.spec reads it.
--   PIECE_LAYER  every SkillVfx piece -> "core" (the flash), "body" (the skill's shape) or "trail" (what stays a moment)
--   layersOf     the layers of an entry: every list (impact, land, trigger, allies, strike), an object and a projectile
--                (body)
--   LAYER_EXCEPT skills allowed to miss a layer, with the reason
--   signature    silhouette at the event (6 joints, angles to 30°, the lift to 0.5 stud), whole-body flags over all keys
--                and the set of pieces; a duplicate = two skills of one class equal in all three
--   PIECE_COST   what one piece may hold at once (Vfx/Library): emitters, beams, lights, decals / ground images; a
--                cast's sum stays within Config.Vfx.perCast

local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillPose = require("../src/shared/Logic/SkillPose")
local SkillVfx = require("../src/shared/Data/SkillVfx")

local SkillLooks = {}

export type Layer = "core" | "body" | "trail"

SkillLooks.PIECE_LAYER = {
	-- core: the flash of the blow (0.05-0.1 s)
	impactFlash = "core",
	burst = "core",
	-- body: the shape of the skill
	slash = "body",
	whirl = "body",
	shockwave = "body",
	ringWave = "body",
	pillar = "body",
	beam = "body",
	lineBeam = "body",
	skyBolt = "body",
	meteor = "body",
	arrowRain = "body",
	fan = "body",
	rune = "body",
	magicCircle = "body",
	shield = "body",
	aura = "body",
	dash = "body",
	tether = "body",
	falcon = "body",
	shieldArc = "body", -- S114
	wings = "body", -- S114
	snare = "body", -- S115
	stormCloud = "body", -- S115
	fireBlast = "body", -- W03
	frostBlast = "body", -- W04
	-- trail: what stays for 0.3-1.5 s
	sparks = "trail",
	dust = "trail",
	smokePuff = "trail",
	smoke = "trail",
	cracks = "trail",
	groundDecal = "trail",
	sparkle = "trail",
	cloud = "trail",
} :: { [string]: Layer }

-- Skills allowed to miss a layer (reason). Every class is held to three layers (S114 Warrior and Cleric, S115 Hunter
-- and Mage).
SkillLooks.LAYER_EXCEPT = {
	chainLightning = "the body is the lightning of every link, drawn in code (VfxController chain branch)",
	camouflage = "no flash: the core is the short smoke puff the hunter vanishes into",
} :: { [string]: string }

-- What a piece may hold at once at its peak on a PC near the camera (emitter / beam / light / decal-or-ground-image
-- holders and PointLights of Vfx/Library; plain parts are not counted, the pool takes them back at once).
export type Cost = { emitters: number, beams: number, lights: number, decals: number }
local function c(emitters: number, beams: number, lights: number, decals: number): Cost
	return { emitters = emitters, beams = beams, lights = lights, decals = decals }
end
SkillLooks.PIECE_COST = {
	impactFlash = c(2, 0, 1, 0),
	burst = c(2, 0, 1, 0),
	slash = c(0, 1, 0, 0),
	whirl = c(0, 1, 0, 0),
	shockwave = c(0, 0, 0, 1),
	ringWave = c(0, 0, 0, 1),
	pillar = c(0, 1, 1, 0),
	beam = c(0, 1, 0, 0),
	lineBeam = c(2, 1, 1, 0),
	skyBolt = c(2, 1, 1, 0),
	meteor = c(1, 0, 1, 0), -- S115: the falling rock only (the entry lists its landing pieces)
	arrowRain = c(0, 0, 0, 0),
	fan = c(0, 0, 0, 0),
	rune = c(0, 0, 0, 1),
	magicCircle = c(0, 0, 0, 1),
	shield = c(0, 0, 0, 0),
	aura = c(1, 0, 1, 0),
	dash = c(0, 1, 0, 0),
	tether = c(0, 1, 0, 0),
	falcon = c(1, 0, 0, 0),
	shieldArc = c(0, 0, 0, 0),
	wings = c(2, 0, 0, 0),
	snare = c(0, 0, 0, 0), -- S115: plain parts
	stormCloud = c(4, 0, 0, 0), -- S115: a smoke burst every 0.5 s living 1.5 s
	fireBlast = c(3, 0, 0, 0), -- W03: flame, smoke and embers
	frostBlast = c(3, 0, 0, 0), -- W04: shards, mist and glints
	sparks = c(1, 0, 0, 0),
	dust = c(2, 0, 0, 0),
	smokePuff = c(1, 0, 0, 0),
	smoke = c(2, 0, 0, 0),
	cracks = c(0, 0, 0, 1),
	groundDecal = c(0, 0, 0, 1),
	sparkle = c(1, 0, 0, 0),
	cloud = c(1, 0, 1, 0),
} :: { [string]: Cost }

-- Every piece name of an entry (each list once per name), the object and the projectile as their own names.
local function pieces(entry: SkillVfx.Entry): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(name: string)
		if not seen[name] then
			seen[name] = true
			table.insert(out, name)
		end
	end
	for _, list in { entry.impact, entry.land or {}, entry.trigger or {}, entry.allies or {}, entry.strike or {} } do
		for _, name in list do
			add(name)
		end
	end
	return out
end
SkillLooks.pieces = pieces

function SkillLooks.layersOf(entry: SkillVfx.Entry): { [Layer]: boolean }
	local out: { [Layer]: boolean } = {}
	for _, name in pieces(entry) do
		local layer = SkillLooks.PIECE_LAYER[name]
		if layer then
			out[layer] = true
		end
	end
	if entry.object ~= nil or entry.projectile ~= nil then
		out.body = true
	end
	return out
end

-- The cost of one cast's impact (every piece of the impact list once; later waves replay the same holders).
function SkillLooks.costOf(entry: SkillVfx.Entry): Cost
	local total = c(0, 0, 0, 0)
	for _, name in entry.impact do
		local cost = SkillLooks.PIECE_COST[name]
		if cost then
			total.emitters += cost.emitters
			total.beams += cost.beams
			total.lights += cost.lights
			total.decals += cost.decals
		end
	end
	return total
end

local SILHOUETTE_JOINTS = { "rShoulder", "rElbow", "lShoulder", "lElbow", "waist", "root" }

local function round(v: number, step: number): number
	local r = math.floor(v / step + 0.5) * step
	return if r == 0 then 0 else r -- no "-0"
end

-- The moment the signature looks at: the hit (when after the start), else the release, else the loop's start, else
-- the first key.
function SkillLooks.eventTime(motion: SkillMotions.Motion): number
	if motion.hit and motion.hit > 0 then
		return motion.hit
	elseif motion.release then
		return motion.release
	elseif motion.loop then
		return motion.loop.from
	end
	return motion.keys[1].t
end

export type Signature = { silhouette: string, flags: string, effects: string }

function SkillLooks.signature(skillId: string): Signature
	local motion = assert(SkillMotions.get(skillId), skillId)
	local entry = assert(SkillVfx[skillId], skillId)
	local at = SkillLooks.eventTime(motion)
	local loopUntil = if motion.loop then motion.loop.to else nil
	local pose = SkillPose.sample(motion, at, { loopUntil = loopUntil })
	local parts: { string } = {}
	for _, joint in SILHOUETTE_JOINTS do
		local v = pose[joint] or {}
		local text = {}
		for i = 1, 3 do
			table.insert(text, tostring(round(v[i] or 0, 30)))
		end
		if joint == "root" then
			table.insert(text, tostring(round(v[4] or 0, 0.5)))
		end
		table.insert(parts, `{joint}={table.concat(text, ",")}`)
	end
	-- whole-body flags over every key
	local flags: { [string]: boolean } = {}
	local highest, lowest = 0, 0
	for _, key in motion.keys do
		local root = key.pose.root
		if root then
			highest = math.max(highest, root[4] or 0)
			lowest = math.min(lowest, root[4] or 0)
			if math.abs(root[2] or 0) >= 180 then
				flags.spin = true
			end
			if math.abs(root[1] or 0) >= 180 then
				flags.flip = true
			end
			local knee = math.max(key.pose.rKnee and key.pose.rKnee[1] or 0, key.pose.lKnee and key.pose.lKnee[1] or 0)
			if (root[4] or 0) <= -1.1 and knee >= 80 then
				flags.kneel = true
			end
		end
	end
	if highest >= 1.2 then
		flags.jump = true
	end
	if lowest <= -0.6 then
		flags.crouch = true
	end
	local rHip, lHip = pose.rHip, pose.lHip
	if (rHip and rHip[1] >= 40) or (lHip and lHip[1] >= 40) then
		flags.lunge = true
	end
	if motion.loop then
		flags.loop = true
	end
	local flagList = {}
	for name in flags do
		table.insert(flagList, name)
	end
	table.sort(flagList)
	-- effects
	local effects = pieces(entry)
	if entry.projectile then
		table.insert(effects, `projectile:{entry.projectile}`)
	end
	if entry.object then
		table.insert(effects, `object:{entry.object}`)
	end
	if entry.telegraph then
		table.insert(effects, `telegraph:{entry.telegraph}`)
	end
	table.sort(effects)
	return {
		silhouette = table.concat(parts, " "),
		flags = table.concat(flagList, ","),
		effects = table.concat(effects, ","),
	}
end

return SkillLooks
