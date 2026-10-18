--!strict
-- W08: the base motion of player characters (docs/ANIMACJE.md "Lokomocja (W08)", docs/WYGLAD.md §3): which clip plays in
-- each state of the Humanoid, how fast, and how the clips blend. The character's own Animate (src/character/Animate)
-- plays them through Logic/LocomotionPick; attacks, skills, emotes and the rider's legs stay on top (Motor6D.Transform
-- after the Animator, AnimationController). Looks only: walk speed, jump and physics are untouched.
--
-- Clip ids: the Roblox R15 default clips until the owner publishes the game's own (docs/wyglad/KLIPY-RUCH.md); a clip
-- that fails to load falls back to `fallback` of the same state (one warning). `land` and the idle variants may be
-- empty (no clip).

export type ClipSet = {
	idle: string,
	idleVariants: { string },
	walk: string,
	run: string,
	jump: string,
	fall: string,
	land: string, -- "" = no landing clip
	climb: string,
	swim: string,
	swimIdle: string,
}

local Locomotion = {}

-- The clips the game plays: the owner's Mixamo clips (docs/wyglad/KLIPY-RUCH.md), converted to R15 and published
-- 2026-10-18.
Locomotion.clips = {
	idle = "rbxassetid://101792382460064", -- Breathing Idle
	idleVariants = {
		"rbxassetid://89423908112114", -- Looking Around
		"rbxassetid://87061023593270", -- Weight Shift
	},
	walk = "rbxassetid://98435814442978", -- Walking (in place)
	run = "rbxassetid://101283575760756", -- Running (in place)
	jump = "rbxassetid://120601938643467", -- Jumping, the take-off only
	fall = "rbxassetid://134039131468808", -- Falling Idle
	land = "rbxassetid://71203138252727", -- Falling To Landing
	climb = "rbxassetid://97694774293222", -- Climbing Ladder
	swim = "rbxassetid://127317644570676", -- Swimming
	swimIdle = "rbxassetid://118483475541123", -- Treading Water
} :: ClipSet

-- Clips published for a later state: the jog between the walk and the run (KLIPY-RUCH.md, priority 3).
Locomotion.spare = { jog = "rbxassetid://82480642264616" }

-- The Roblox R15 defaults: what a clip of `clips` falls back to when it does not load.
Locomotion.fallback = {
	idle = "rbxassetid://507766388",
	idleVariants = {},
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
	jump = "rbxassetid://507765000",
	fall = "rbxassetid://507767968",
	land = "",
	climb = "rbxassetid://507765644",
	swim = "rbxassetid://507784897",
	swimIdle = "rbxassetid://507785072",
} :: ClipSet

-- Stride: studs per second the character moves when the clip plays at speed 1.0 (feet do not slide). Measured in
-- Studio on the game's body (W09) as the planted foot's speed against the root: the owner's Mixamo walk 6.5, run 16.9
-- (2026-10-18; the Roblox defaults stepped 6.6 for both, so the run was capped at 8 and slid). A new clip gets its own
-- number.
Locomotion.stride = {
	walk = 6.5,
	run = 16.9,
	climb = 5, -- the default Animate climbs at speed / 5
	swim = 10,
}

-- Walk / run blend by horizontal speed (studs/s, scaled by the character's height): walk only below `walkUntil`, run only
-- from `runFrom`, a linear crossfade between. The playback speed follows the speed / stride, within `rate`.
Locomotion.blend = {
	moving = 0.5, -- below this the character stands
	walkUntil = 7,
	runFrom = 12,
	rate = { 0.6, 2.2 },
}

-- Crossfade seconds between states.
Locomotion.fade = {
	start = 0.2, -- idle -> move
	stop = 0.2, -- move -> idle
	air = 0.1, -- into a jump or a fall
	land = 0.12,
	other = 0.25,
}

-- Jump and fall: the fall clip after the jump clip or this long in the air; the landing clip only after a fall of at
-- least `landHeight` studs (a jump on flat ground or a step down does not crouch).
Locomotion.air = {
	fallAfter = 0.35,
	landHeight = 9,
}

-- Idle variants: one after a random 8-15 s of standing, never in combat (hit or attacked within `combatQuiet` s).
Locomotion.idle = {
	variantEvery = { 8, 15 },
	combatQuiet = 8,
}

-- Foot IK on slopes (W08 D): the own character and the nearest `others` characters within `range` studs, standing or
-- walking (not running, not in the air, not mounted), only on the graphics levels in `levels`. The hips drop by the
-- foot height difference, at most `maxDrop`.
Locomotion.footIk = {
	levels = { medium = true, high = true },
	others = 3,
	range = 60,
	maxSpeed = 10,
	maxDrop = 1.2,
	ray = 4,
}

return table.freeze(Locomotion)
