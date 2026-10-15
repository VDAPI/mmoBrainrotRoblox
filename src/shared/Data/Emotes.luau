--!strict
-- Emotes (S123, DESIGN-17 §4): procedural gestures in the format of Data/SkillMotions (Motion: keys, recover,
-- loop?), played by AnimationController.Emote on every client. `aliases` are what "/e <alias>" accepts (ASCII,
-- lower case, unique across emotes). `loop` emotes hold until the character moves, attacks or casts. `clip` is a
-- reserved hook for an animation id (0 = procedural), same idea as the S113 attack clips.
-- Joint angles follow the header of Data/SkillMotions (degrees in the torso frame; root = { pitch, yaw, roll, lift }).
-- An emote never has combat events (hit, release, land) nor `lock`: it does not hold the character in place.
-- Cosmetics of kind "emote" point at these ids (Data/Cosmetics `emote`); one cosmetic per emote (tests/cosmetics2).

local SkillMotions = require("./SkillMotions")

type Pose = SkillMotions.Pose
type Key = SkillMotions.Key
type Ease = SkillMotions.Ease

export type Emote = { id: string, aliases: { string }, motion: SkillMotions.Motion, clip: number? }

local function k(t: number, pose: Pose, ease: Ease?): Key
	return { t = t, pose = pose, ease = ease }
end

local function merge(...: Pose): Pose
	local out: Pose = {}
	for i = 1, select("#", ...) do
		local pose = select(i, ...)
		for joint, value in pose do
			out[joint] = value
		end
	end
	return out
end

-- Kneeling on the left knee (as Data/SkillMotions).
local KNEEL: Pose = {
	root = { 0, 0, 0, -1.3 },
	rHip = { 80, 0, 6 },
	lHip = { -8, 0, -4 },
	rKnee = { 85 },
	lKnee = { 100 },
}

-- Sitting on the ground, legs forward, leaning on the hands behind.
local SIT: Pose = {
	root = { 0, 0, 0, -2 },
	rHip = { 84, 0, 6 },
	lHip = { 84, 0, -6 },
	rKnee = { 50 },
	lKnee = { 62 },
	waist = { 12, 0, 0 },
	rShoulder = { -32, 0, 16 },
	rElbow = { 8, 0, 0 },
	lShoulder = { -32, 0, -16 },
	lElbow = { 8, 0, 0 },
}

-- The right hand to the chin, the left arm across the chest.
local PONDER: Pose = {
	rShoulder = { 48, 30, 0 },
	rElbow = { 138, 0, 0 },
	rWrist = { 10, 0, 0 },
	lShoulder = { 38, -38, 0 },
	lElbow = { 100, 0, 0 },
	waist = { -4, 0, 5 },
}

local list: { Emote } = {
	{
		-- A greeting with the raised right hand.
		id = "wave",
		aliases = { "wave", "machaj" },
		motion = {
			keys = {
				k(0.3, { rShoulder = { 150, 0, 30 }, rElbow = { 30, 0, 0 } }, "out"),
				k(0.6, { rShoulder = { 150, 0, 44 }, rElbow = { 52, 0, 0 } }, "inOut"),
				k(0.9, { rShoulder = { 150, 0, 24 }, rElbow = { 22, 0, 0 } }, "inOut"),
				k(1.2, { rShoulder = { 150, 0, 44 }, rElbow = { 52, 0, 0 } }, "inOut"),
				k(1.5, { rShoulder = { 150, 0, 30 }, rElbow = { 30, 0, 0 } }, "inOut"),
			},
			recover = 0.4,
		},
	},
	{
		-- Pointing the way with the right arm.
		id = "point",
		aliases = { "point", "wskaz" },
		motion = {
			keys = {
				k(0.3, { rShoulder = { 88, 10, 0 }, rElbow = { 5, 0, 0 }, waist = { 0, -8, 0 } }, "out"),
				k(1.6, { rShoulder = { 90, 12, 0 }, rElbow = { 4, 0, 0 }, waist = { 0, -10, 0 } }, "inOut"),
			},
			recover = 0.4,
		},
	},
	{
		-- A court bow: the right hand on the chest, the left behind the back.
		id = "bow",
		aliases = { "bow", "uklon" },
		motion = {
			keys = {
				k(0.25, { rShoulder = { 40, 30, 0 }, rElbow = { 100, 0, 0 }, lShoulder = { -15, 0, -10 } }, "out"),
				k(0.7, {
					rShoulder = { 52, 35, 0 },
					rElbow = { 112, 0, 0 },
					lShoulder = { -22, 0, -12 },
					waist = { -42, 0, 0 },
				}, "inOut"),
				k(1.3, {
					rShoulder = { 52, 35, 0 },
					rElbow = { 112, 0, 0 },
					lShoulder = { -22, 0, -12 },
					waist = { -40, 0, 0 },
				}, "inOut"),
				k(1.7, { rShoulder = { 40, 30, 0 }, rElbow = { 100, 0, 0 }, lShoulder = { -15, 0, -10 } }, "inOut"),
			},
			recover = 0.5,
		},
	},
	{
		-- A soldier's salute: the right hand to the brow, the body straight.
		id = "salute",
		aliases = { "salute", "salut" },
		motion = {
			keys = {
				k(0.3, { rShoulder = { 110, 30, 42 }, rElbow = { 128, 0, 0 }, waist = { 4, 0, 0 } }, "out"),
				k(1.4, { rShoulder = { 112, 30, 42 }, rElbow = { 130, 0, 0 }, waist = { 4, 0, 0 } }, "inOut"),
			},
			recover = 0.35,
		},
	},
	{
		-- Kneeling on one knee, the right hand on the knee (held until the character moves).
		id = "kneel",
		aliases = { "kneel", "kleknij" },
		motion = {
			keys = {
				k(
					0.5,
					merge(KNEEL, {
						rShoulder = { 32, 0, 4 },
						rElbow = { 42, 0, 0 },
						lShoulder = { 8, 0, -6 },
						waist = { -10, 0, 0 },
					}),
					"inOut"
				),
				k(
					1.5,
					merge(KNEEL, {
						rShoulder = { 32, 0, 4 },
						rElbow = { 44, 0, 0 },
						lShoulder = { 8, 0, -6 },
						waist = { -14, 0, 0 },
					}),
					"inOut"
				),
				k(
					2.5,
					merge(KNEEL, {
						rShoulder = { 32, 0, 4 },
						rElbow = { 42, 0, 0 },
						lShoulder = { 8, 0, -6 },
						waist = { -10, 0, 0 },
					}),
					"inOut"
				),
			},
			recover = 0.6,
			loop = { from = 0.5, to = 2.5 },
		},
	},
	{
		-- A raised fist, twice (no sound).
		id = "cheer",
		aliases = { "cheer", "wiwat" },
		motion = {
			keys = {
				k(0.25, { rShoulder = { 172, 0, 10 }, rElbow = { 12, 0, 0 }, waist = { 10, 0, 0 } }, "out"),
				k(0.5, { rShoulder = { 150, 0, 12 }, rElbow = { 45, 0, 0 }, waist = { 6, 0, 0 } }, "inOut"),
				k(0.75, { rShoulder = { 174, 0, 10 }, rElbow = { 10, 0, 0 }, waist = { 12, 0, 0 } }, "out"),
				k(1.3, { rShoulder = { 170, 0, 10 }, rElbow = { 14, 0, 0 }, waist = { 10, 0, 0 } }, "inOut"),
			},
			recover = 0.4,
		},
	},
	{
		-- The hand at the chin, a slight tilt (held until the character moves).
		id = "ponder",
		aliases = { "ponder", "mysl" },
		motion = {
			keys = {
				k(0.5, PONDER, "inOut"),
				k(1.5, merge(PONDER, { waist = { -6, 0, 8 }, rElbow = { 142, 0, 0 } }), "inOut"),
				k(2.5, PONDER, "inOut"),
			},
			recover = 0.5,
			loop = { from = 0.5, to = 2.5 },
		},
	},
	{
		-- Sitting on the ground (held until the character moves).
		id = "sit",
		aliases = { "sit", "siad" },
		motion = {
			keys = {
				k(0.35, {
					root = { 0, 0, 0, -0.9 },
					rHip = { 40, 0, 2 },
					lHip = { 40, 0, -2 },
					rKnee = { 70 },
					lKnee = { 70 },
				}, "in"),
				k(0.8, SIT, "out"),
				k(2.8, merge(SIT, { waist = { 15, 0, 0 } }), "inOut"),
				k(4.8, SIT, "inOut"),
			},
			recover = 0.7,
			loop = { from = 0.8, to = 4.8 },
		},
	},
}

local byId: { [string]: Emote } = {}
local byAlias: { [string]: Emote } = {}
for _, emote in list do
	assert(byId[emote.id] == nil, `Emotes: duplicate id {emote.id}`)
	byId[emote.id] = emote
	for _, alias in emote.aliases do
		assert(byAlias[alias] == nil, `Emotes: duplicate alias {alias}`)
		byAlias[alias] = emote
	end
end

return table.freeze({
	list = list,
	get = function(id: string): Emote?
		return byId[id]
	end,
	-- Case-insensitive.
	byAlias = function(alias: string): Emote?
		return byAlias[string.lower(alias)]
	end,
	COOLDOWN = 3, -- seconds between two emotes of one player (server)
	MAX_SECONDS = 30, -- a looping emote ends by itself after this long
})
