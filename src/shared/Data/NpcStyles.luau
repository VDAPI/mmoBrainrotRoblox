--!strict
-- NPC animation (owner 2026-10-26: "after the monster animations, the NPCs"; alive, believable, varied): how each town
-- NPC stands, breathes, fidgets, works, greets and talks (Logic/NpcMotion). A role style per kind of person (a guard, a
-- merchant, an elder...), every NPC of Data/Npcs mapped onto one with its own overrides (NPCS below).
-- Poses are Logic/BipedPose controls (signs: pitch > 0 bends forward / the head down, yaw > 0 turns left, roll > 0 leans
-- left; an arm's p raises it forward, o lifts it out, y swings it across the body, t twists it in, e bends the elbow;
-- distances in leg lengths L, the hip joint's height), plus the hands' shapes: g<S> grip 0 open .. 1 fist, i<S> 1 the
-- index pointing.
-- A move is a list of keys on its own clock (seconds): a key's arm and hand controls are absolute (where the arm
-- goes), its body controls (p*, s*, h*) add to the layers under it; keys carry their values forward until a later key
-- changes them. A hand may instead reach a target (HandTarget): a point in the frame of the chest (the base of the
-- neck turned with the chest), the head, the hips or the ground under the NPC's own spot (root space), in leg lengths
-- (x right, y up, z back), reached by arm IK with the elbow toward `pole` (chest frame, right arm; mirrored for the
-- left); `false` in a later key lets the hand go. `osc` adds a wave to a control ("eR") or to a hand target's offset
-- ("R.x"); `gaze` is where the eyes go while it plays ({ yaw, pitch } from the body's front); `hold` keeps the last key
-- until the layer lets go.

local NpcStyles = {}

export type HandTarget = { at: string, x: number, y: number, z: number, pole: { number }? }
export type Key = { t: number, ease: string?, pose: { [string]: number }?, R: HandTarget?, L: HandTarget? }
export type Osc = { c: string, amp: number, hz: number, from: number, to: number }
export type Move = {
	keys: { Key },
	fadeIn: number?,
	fadeOut: number?,
	osc: { Osc }?,
	gaze: { number }?,
	hold: boolean?,
	arms: { R: boolean, L: boolean }, -- the arms the move keys (filled in below)
}
export type Weighted = { name: string, weight: number, reps: { number }?, effort: number? }
export type Work = {
	base: Move?, -- the posture while working (sampled once, held)
	phrases: { Weighted }, -- moves played in phrases (repeated `reps` times), picked by the NPC's seed
	gaze: { number }?, -- where it looks while working
	behind: boolean?, -- the work is behind its back (a stall): it turns round to work, and back to a player near
	stand: { number }?, -- where it stands to work: { x, z } leg lengths from its spot (root axes)
	prop: string?, -- a client prop the work needs (Anim/NpcRig: "anvil")
}
export type Style = {
	id: string,
	-- the stance: its controls, the feet's extra width (leg lengths) and turn-out (rad, each foot), the hands' grip
	stance: { pose: { [string]: number }, width: number?, toeOut: number?, grip: number },
	breath: number, -- seconds of a breath
	breathDepth: number,
	shift: number, -- 0..1 how far the weight moves onto one leg
	shiftEvery: { number }, -- seconds between weight shifts (min, max)
	sway: number,
	tempo: number, -- how quick the body is (turns, steps, looks)
	walkSpeed: number, -- studs per second of a walk (the pace)
	glance: { every: { number }, ahead: number, yaw: number, pitch: number, down: number, turn: number },
	look: { range: number, hold: { number }, away: { number }, weight: number, atWork: number },
	greet: { range: number, me: string, other: string }?,
	fidgets: { Weighted },
	fidgetEvery: { number },
	work: Work?,
	talk: {
		listen: string, -- the move held while listening (the hands' rest in the dialogue)
		gestures: { Weighted },
		speak: { number }, -- seconds of a speaking phase
		listenFor: { number },
		energy: number, -- gesture tempo
		beats: number, -- strength of the beats on the accents
	},
	pace: { span: number, every: { number }, axis: string }?, -- a sentry's beat: studs out and back
	float: number?, -- a ghost's bob (leg lengths)
	prop: string?,
}

-- The elbow's default pole for hand targets (chest frame, right arm): out, a little down and back.
NpcStyles.POLE = { 0.8, -0.35, 0.5 }

---------------------------------------------------------------- building moves

local function T(at: string, x: number, y: number, z: number, pole: { number }?): HandTarget
	return { at = at, x = x, y = y, z = z, pole = pole }
end

local function key(t: number, pose: { [string]: number }?, extra: { [string]: any }?): Key
	local k: any = { t = t, pose = pose }
	if extra then
		for name, v in extra do
			-- the third table holds the hand targets and the ease only (a control there would be lost)
			assert(name == "R" or name == "L" or name == "ease", `NpcStyles key at {t}: {name} belongs in the pose`)
			k[name] = v
		end
	end
	return k
end

local function sideOf(control: string): string?
	local first = string.sub(control, 1, 1)
	if first == "a" or first == "e" or first == "w" or first == "c" or first == "g" or first == "i" then
		if string.find(control, "R") then
			return "R"
		elseif string.find(control, "L") then
			return "L"
		end
	end
	return nil
end

-- A move from its keys: values carried forward key to key, the arms it keys found.
local function move(def: { [string]: any }): Move
	local keys: { Key } = def.keys
	local arms = { R = false, L = false }
	local carried: { [string]: number } = {}
	local hands: { [string]: any } = { R = nil, L = nil }
	local out: { Key } = {}
	for _, k in keys do
		local pose: { [string]: number } = k.pose or {}
		for name, v in pose do
			carried[name] = v
			local s = sideOf(name)
			if s then
				(arms :: any)[s] = true
			end
		end
		local nk: any = { t = k.t, ease = k.ease, pose = table.clone(carried) }
		for _, s in { "R", "L" } do
			local v = (k :: any)[s]
			if v ~= nil then
				hands[s] = if v == false then nil else v
			end
			if hands[s] then
				nk[s] = hands[s];
				(arms :: any)[s] = true
			end
		end
		table.insert(out, nk)
	end
	for _, o in def.osc or {} do
		local s = sideOf(o.c) or (if string.sub(o.c, 2, 2) == "." then string.sub(o.c, 1, 1) else nil)
		if s then
			(arms :: any)[s] = true
		end
	end
	return {
		keys = out,
		fadeIn = def.fadeIn,
		fadeOut = def.fadeOut,
		osc = def.osc,
		gaze = def.gaze,
		hold = def.hold,
		arms = arms,
	}
end

-- The same move on the other side (a hand that holds a prop gives its gestures to the other one).
local FLIP: { [string]: boolean } =
	{ pyaw = true, proll = true, syaw = true, sroll = true, hyaw = true, hroll = true, px = true }
local function mirrorName(name: string): string
	local first = string.sub(name, 1, 1)
	if first == "a" or first == "e" or first == "w" or first == "c" or first == "g" or first == "i" then
		if string.find(name, "R") then
			return (string.gsub(name, "R", "L", 1))
		elseif string.find(name, "L") then
			return (string.gsub(name, "L", "R", 1))
		end
	end
	return name
end

local function mirrorTarget(t: HandTarget?): HandTarget?
	if not t then
		return nil
	end
	return { at = t.at, x = -t.x, y = t.y, z = t.z, pole = t.pole }
end

local function mirror(m: Move): Move
	local keys: { Key } = {}
	for _, k in m.keys do
		local pose: { [string]: number } = {}
		local from: { [string]: number } = k.pose or {}
		for name, v in from do
			pose[mirrorName(name)] = if FLIP[name] then -v else v
		end
		table.insert(keys, { t = k.t, ease = k.ease, pose = pose, R = mirrorTarget(k.L), L = mirrorTarget(k.R) })
	end
	local osc: { Osc }? = nil
	if m.osc then
		local list: { Osc } = {}
		for _, o in m.osc do
			local c = o.c
			local amp = o.amp
			if string.sub(c, 2, 2) == "." then
				local s = if string.sub(c, 1, 1) == "R" then "L" else "R"
				local axis = string.sub(c, 3, 3)
				c = s .. "." .. axis
				if axis == "x" then
					amp = -amp
				end
			else
				if FLIP[c] then
					amp = -amp
				end
				c = mirrorName(c)
			end
			table.insert(list, { c = c, amp = amp, hz = o.hz, from = o.from, to = o.to })
		end
		osc = list
	end
	return {
		keys = keys,
		fadeIn = m.fadeIn,
		fadeOut = m.fadeOut,
		osc = osc,
		gaze = if m.gaze then { -m.gaze[1], m.gaze[2] } else nil,
		hold = m.hold,
		arms = { R = m.arms.L, L = m.arms.R },
	}
end

---------------------------------------------------------------- moves

-- Hand targets used often (leg lengths). The chest point is the base of the neck.
local CHIN = T("head", 0.04, -0.1, -0.2, { 0.6, -0.8, -0.2 })
local BROW_R = T("head", 0.1, 0.16, -0.19, { 1, 0.1, -0.2 })
local HEAD_SIDE = T("head", 0.15, 0.24, -0.02, { 1, 0.4, -0.3 })
local NAPE = T("head", 0.05, 0.04, 0.12, { 1, 0.3, 0.2 })
local CHEST_R = T("chest", 0.02, -0.22, -0.2, { 0.8, -0.6, 0.2 })
local BELT_R = T("hips", 0.14, 0.1, -0.21, { 1, -0.2, 0.4 })
local BELT_L = T("hips", -0.14, 0.1, -0.21, { 1, -0.2, 0.4 })
local HIP_R = T("hips", 0.27, 0.12, -0.02, { 1, 0.1, 0.6 })
local HIP_L = T("hips", -0.27, 0.12, -0.02, { 1, 0.1, 0.6 })
local CLASP_R = T("hips", 0.035, 0.24, -0.25, { 0.9, -0.5, 0.5 })
local CLASP_L = T("hips", -0.035, 0.24, -0.25, { 0.9, -0.5, 0.5 })
local BACK_R = T("hips", 0.05, 0.16, 0.24, { 1, -0.3, 0.4 })
local BACK_L = T("hips", -0.05, 0.16, 0.24, { 1, -0.3, 0.4 })
local PRAY_R = T("chest", 0.025, -0.3, -0.24, { 0.9, -0.9, 0.2 })
local PRAY_L = T("chest", -0.025, -0.3, -0.24, { 0.9, -0.9, 0.2 })

local MOVES: { [string]: Move } = {}
NpcStyles.MOVES = MOVES

---------------------------------------------------------------- greetings

-- A nod: the head dips once, the chest follows a little.
MOVES.greetNod = move({
	fadeIn = 0.1,
	fadeOut = 0.25,
	keys = {
		key(0, { hpitch = 0, spitch = 0 }),
		key(0.18, { hpitch = 0.32, spitch = 0.04 }, { ease = "out" }),
		key(0.42, { hpitch = 0.06, spitch = 0.01 }, { ease = "inout" }),
		key(0.6, { hpitch = 0.12, spitch = 0.01 }, { ease = "inout" }),
		key(0.95, { hpitch = 0, spitch = 0 }),
	},
})
MOVES.greetNodOther = move({
	fadeIn = 0.1,
	fadeOut = 0.2,
	keys = {
		key(0, { hpitch = 0 }),
		key(0.2, { hpitch = 0.2 }, { ease = "out" }),
		key(0.6, { hpitch = 0 }),
	},
})
-- A wave: the right hand rises open beside the head, waves from the elbow two or three times, comes down; the head
-- tilts and nods into it.
MOVES.greetWave = move({
	fadeIn = 0.25,
	fadeOut = 0.45,
	keys = {
		key(
			0,
			{ aRp = 0.25, aRo = 0.5, aRy = 0, aRt = -0.5, eR = 1.1, wRp = 0, wRy = 0, wRr = 0, gR = 0.15, hroll = 0 }
		),
		key(
			0.38,
			{ aRp = 0.3, aRo = 1.25, aRt = -1.3, eR = 1.55, wRp = -0.15, gR = 0.05, hroll = 0.08, hpitch = 0.08 },
			{
				ease = "out",
			}
		),
		key(1.55, { aRp = 0.3, aRo = 1.2, aRt = -1.3, eR = 1.5, hroll = 0.06, hpitch = 0 }),
		key(1.95, { aRp = 0.15, aRo = 0.3, aRt = 0, eR = 0.5, wRp = 0, gR = 0.3, hroll = 0 }, { ease = "inout" }),
	},
	osc = {
		{ c = "aRt", amp = 0.38, hz = 2.6, from = 0.38, to = 1.55 },
		{ c = "wRr", amp = 0.2, hz = 2.6, from = 0.38, to = 1.55 },
	},
})
-- A raised palm (a busy worker's "hello" without stopping long).
MOVES.greetRaise = move({
	fadeIn = 0.2,
	fadeOut = 0.35,
	keys = {
		key(0, { aRp = 0.35, aRo = 0.35, aRt = -0.4, eR = 1.3, wRy = 0, gR = 0.1, hpitch = 0 }),
		key(
			0.3,
			{ aRp = 0.45, aRo = 0.75, aRt = -1.0, eR = 1.75, wRp = -0.2, gR = 0.05, hpitch = 0.15 },
			{ ease = "out" }
		),
		key(0.9, { aRp = 0.45, aRo = 0.72, aRt = -1.0, eR = 1.7, hpitch = 0.05 }),
		key(1.2, { aRp = 0.15, aRo = 0.2, aRt = 0, eR = 0.6, wRp = 0, gR = 0.3, hpitch = 0 }, { ease = "inout" }),
	},
})
-- A salute: the right hand snaps to the brow, the body straightens, a short hold, the hand cuts away.
MOVES.greetSalute = move({
	fadeIn = 0.12,
	fadeOut = 0.35,
	keys = {
		key(0, { gR = 0.05, spitch = 0, hpitch = 0 }),
		key(0.34, { gR = 0.02, spitch = -0.05, hpitch = -0.05, wRp = -0.2 }, { ease = "inout", R = BROW_R }),
		key(1.1, { spitch = -0.05, hpitch = -0.04 }, { R = BROW_R }),
		key(1.45, { aRp = 0.35, aRo = 0.6, eR = 0.9, gR = 0.3, spitch = 0, hpitch = 0 }, { ease = "inout", R = false }),
	},
})
-- A bow from the waist, the hand on the chest (a priest, an elder, a courtly banker).
MOVES.greetBow = move({
	fadeIn = 0.25,
	fadeOut = 0.45,
	keys = {
		key(0, { spitch = 0, hpitch = 0, ppitch = 0, gR = 0.2 }, { R = CHEST_R }),
		key(0.55, { spitch = 0.32, hpitch = 0.18, ppitch = 0.08, pz = 0.03 }, { ease = "inout", R = CHEST_R }),
		key(1.05, { spitch = 0.32, hpitch = 0.2, ppitch = 0.08, pz = 0.03 }, { R = CHEST_R }),
		key(1.6, { spitch = 0, hpitch = 0, ppitch = 0, pz = 0 }, { ease = "inout", R = CHEST_R }),
	},
})
-- A guard's acknowledgement: the chin lifts, a curt nod.
MOVES.greetGuard = move({
	fadeIn = 0.1,
	fadeOut = 0.25,
	keys = {
		key(0, { hpitch = 0, spitch = 0 }),
		key(0.15, { hpitch = -0.08, spitch = -0.03 }, { ease = "out" }),
		key(0.35, { hpitch = 0.24, spitch = 0.02 }, { ease = "in" }),
		key(0.75, { hpitch = 0, spitch = 0 }, { ease = "inout" }),
	},
})

---------------------------------------------------------------- fidgets

MOVES.scratchHead = move({
	fadeIn = 0.45,
	fadeOut = 0.5,
	gaze = { 0.15, 0.1 },
	keys = {
		key(0, { gR = 0.45, hroll = 0, hpitch = 0 }, { R = HEAD_SIDE }),
		key(0.4, { hroll = -0.1, hpitch = 0.08 }, { R = HEAD_SIDE }),
		key(1.6, { hroll = -0.08, hpitch = 0.06 }, { R = HEAD_SIDE }),
		key(1.9, { hroll = 0, hpitch = 0 }, { R = HEAD_SIDE }),
	},
	osc = {
		{ c = "R.z", amp = 0.025, hz = 4.5, from = 0.4, to = 1.6 },
		{ c = "R.y", amp = 0.012, hz = 4.5, from = 0.4, to = 1.6 },
	},
})
MOVES.scratchChin = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { -0.2, -0.1 },
	keys = {
		key(0, { gR = 0.55, wRp = 0.3, hpitch = -0.05 }, { R = CHIN }),
		key(1.8, { hpitch = -0.02 }, { R = CHIN }),
		key(2.1, { hpitch = 0 }, { R = CHIN }),
	},
	osc = { { c = "R.x", amp = 0.018, hz = 3.2, from = 0.35, to = 1.8 } },
})
-- Thinking: the hand at the chin a while, the eyes off to the side.
MOVES.thinkChin = move({
	fadeIn = 0.5,
	fadeOut = 0.55,
	gaze = { 0.35, -0.12 },
	keys = {
		key(0, { gR = 0.6, wRp = 0.35, hpitch = -0.04, spitch = -0.02 }, { R = CHIN }),
		key(3.2, { hpitch = -0.06 }, { R = CHIN }),
		key(3.6, { hpitch = 0, spitch = 0 }, { R = CHIN }),
	},
})
-- The back stretched: hands to the small of the back, the chest arches, the head goes back.
MOVES.stretchBack = move({
	fadeIn = 0.5,
	fadeOut = 0.6,
	gaze = { 0, -0.3 },
	keys = {
		key(0, { gR = 0.5, gL = 0.5, spitch = 0, hpitch = 0 }, { R = BACK_R, L = BACK_L }),
		key(
			0.7,
			{ spitch = -0.28, hpitch = -0.25, py = -0.015, pz = -0.02 },
			{ ease = "inout", R = BACK_R, L = BACK_L }
		),
		key(1.6, { spitch = -0.3, hpitch = -0.28 }, { R = BACK_R, L = BACK_L }),
		key(2.2, { spitch = 0, hpitch = 0, py = 0, pz = 0 }, { ease = "inout", R = BACK_R, L = BACK_L }),
	},
})
-- Arms up over the head, a long stretch, the arms come down.
MOVES.stretchArms = move({
	fadeIn = 0.4,
	fadeOut = 0.5,
	keys = {
		key(0, { aRp = 0.6, aRo = 0.4, eR = 1.2, aLp = 0.6, aLo = 0.4, eL = 1.2, gR = 0.6, gL = 0.6 }),
		key(0.7, {
			aRp = 2.7,
			aRo = 0.35,
			aRy = 0.2,
			eR = 0.5,
			aLp = 2.7,
			aLo = 0.35,
			aLy = 0.2,
			eL = 0.5,
			spitch = -0.12,
			hpitch = -0.22,
			cRu = 0.12,
			cLu = 0.12,
			py = 0.01,
		}, { ease = "inout" }),
		key(1.5, { aRp = 2.8, aLp = 2.8, spitch = -0.15, hpitch = -0.25, sroll = 0.05 }),
		key(2.2, {
			aRp = 0.3,
			aRo = 0.2,
			aRy = 0,
			eR = 0.5,
			aLp = 0.3,
			aLo = 0.2,
			aLy = 0,
			eL = 0.5,
			spitch = 0,
			hpitch = 0,
			cRu = 0,
			cLu = 0,
			py = 0,
			sroll = 0,
		}, {
			ease = "inout",
		}),
	},
})
-- Thumbs in the belt, a tug up, a settle.
MOVES.adjustBelt = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { 0, 0.35 },
	keys = {
		key(0, { gR = 0.7, gL = 0.7 }, { R = BELT_R, L = BELT_L }),
		key(
			0.5,
			{ py = 0.01 },
			{ R = T("hips", 0.15, 0.15, -0.21, BELT_R.pole), L = T("hips", -0.15, 0.15, -0.21, BELT_L.pole) }
		),
		key(0.75, { py = 0 }, { ease = "in", R = BELT_R, L = BELT_L }),
		key(
			1.05,
			{},
			{ R = T("hips", 0.15, 0.13, -0.21, BELT_R.pole), L = T("hips", -0.15, 0.13, -0.21, BELT_L.pole) }
		),
		key(1.5, {}, { R = BELT_R, L = BELT_L }),
	},
})
-- The shoulders roll and the neck turns out the stiffness.
MOVES.rollShoulders = move({
	fadeIn = 0.25,
	fadeOut = 0.35,
	keys = {
		key(0, { cRu = 0, cLu = 0, cRf = 0, cLf = 0, hroll = 0, hpitch = 0 }),
		key(0.35, { cRu = 0.22, cLu = 0.22, cRf = 0.12, cLf = 0.12, hpitch = 0.05 }, { ease = "inout" }),
		key(0.7, { cRu = 0.1, cLu = 0.1, cRf = -0.15, cLf = -0.15, spitch = -0.05 }, { ease = "inout" }),
		key(1.0, { cRu = 0, cLu = 0, cRf = 0, cLf = 0, spitch = 0, hroll = 0.18 }, { ease = "inout" }),
		key(1.45, { hroll = -0.16, hpitch = 0.08 }, { ease = "inout" }),
		key(1.85, { hroll = 0, hpitch = 0 }, { ease = "inout" }),
	},
})
-- Rubbing the hands together in front (the cold, an expected sale).
MOVES.rubHands = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { 0, 0.3 },
	keys = {
		key(0, { gR = 0.25, gL = 0.25, wRy = 0.6, wLy = 0.6, hpitch = 0.05 }, {
			R = T("chest", 0.03, -0.42, -0.26, { 0.9, -0.6, 0.3 }),
			L = T("chest", -0.03, -0.42, -0.26, { 0.9, -0.6, 0.3 }),
		}),
		key(1.6, {}),
	},
	osc = {
		{ c = "R.y", amp = 0.025, hz = 3.4, from = 0.3, to = 1.5 },
		{ c = "L.y", amp = -0.025, hz = 3.4, from = 0.3, to = 1.5 },
	},
})
-- A look up at the sky (the weather), the hand shading the eyes now and then.
MOVES.lookSky = move({
	fadeIn = 0.6,
	fadeOut = 0.7,
	gaze = { 0.25, -0.45 },
	keys = {
		key(0, { spitch = -0.04 }),
		key(2.4, { spitch = -0.05 }),
	},
})
-- A glance at the fingernails, then the hand drops.
MOVES.checkHand = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { -0.1, 0.4 },
	keys = {
		key(0, { aLp = 0.75, aLo = 0.15, aLy = 0.35, eL = 1.9, wLy = 0.9, wLp = -0.3, gL = 0.55, hpitch = 0.1 }),
		key(1.4, { wLy = 0.6, wLp = -0.45 }, { ease = "inout" }),
		key(1.8, {}),
	},
})
-- Wiping the brow with the back of the wrist, a puff of breath.
MOVES.wipeBrow = move({
	fadeIn = 0.35,
	fadeOut = 0.45,
	keys = {
		key(0, { gR = 0.6, hpitch = 0.06 }, { R = T("head", -0.06, 0.2, -0.22, { 1, 0.5, -0.4 }) }),
		key(0.45, { hpitch = 0.02 }, { ease = "inout", R = T("head", 0.16, 0.2, -0.18, { 1, 0.5, -0.4 }) }),
		key(0.7, { hpitch = -0.06, spitch = -0.03 }, { R = T("head", 0.2, 0.14, -0.1, { 1, 0.5, -0.4 }) }),
		key(1.15, { hpitch = 0, spitch = 0, aRp = 0.25, aRo = 0.25, eR = 0.5 }, { ease = "inout", R = false }),
	},
})
-- The neck rubbed, the head tilted (a long day).
MOVES.rubNeck = move({
	fadeIn = 0.45,
	fadeOut = 0.5,
	keys = {
		key(0, { gR = 0.35, hpitch = 0.1, hroll = 0.05 }, { R = NAPE }),
		key(1.6, { hpitch = 0.18, hroll = 0.12 }, { R = NAPE }),
		key(2.0, { hpitch = 0, hroll = 0 }, { R = NAPE }),
	},
	osc = { { c = "R.x", amp = 0.025, hz = 1.8, from = 0.3, to = 1.6 } },
})
-- A yawn: the head back, the chest rising, the hand to the mouth.
MOVES.yawn = move({
	fadeIn = 0.45,
	fadeOut = 0.55,
	keys = {
		key(0, { gR = 0.45, hpitch = 0, spitch = 0 }, { R = T("head", 0.02, 0.0, -0.24, { 0.7, -0.6, -0.3 }) }),
		key(0.6, { hpitch = -0.28, spitch = -0.1, cRu = 0.1, cLu = 0.1, py = 0.01 }, { ease = "inout" }),
		key(1.5, { hpitch = -0.3, spitch = -0.11 }),
		key(2.0, { hpitch = 0.05, spitch = 0, cRu = 0, cLu = 0, py = 0 }, { ease = "inout" }),
	},
})
-- Hands on the hips (held for a while).
MOVES.handsOnHips = move({
	fadeIn = 0.5,
	fadeOut = 0.55,
	keys = {
		key(0, { gR = 0.65, gL = 0.65, wRp = -0.2, wLp = -0.2, spitch = -0.03 }, { R = HIP_R, L = HIP_L }),
		key(6, { spitch = -0.02 }, { R = HIP_R, L = HIP_L }),
	},
})
-- Arms folded over the chest (held for a while).
MOVES.crossArms = move({
	fadeIn = 0.55,
	fadeOut = 0.6,
	keys = {
		key(0, { gR = 0.6, gL = 0.6, spitch = -0.02, wRy = 0.5, wLy = 0.5 }, {
			R = T("chest", -0.17, -0.34, -0.24, { 1, -0.5, 0.2 }),
			L = T("chest", 0.15, -0.3, -0.27, { 1, -0.5, 0.2 }),
		}),
		key(7, { spitch = -0.03 }),
	},
})
-- Hands clasped behind the back (held for a while).
MOVES.handsBehind = move({
	fadeIn = 0.6,
	fadeOut = 0.6,
	keys = {
		key(0, { gR = 0.55, gL = 0.55, spitch = -0.02 }, { R = BACK_R, L = BACK_L }),
		key(8, {}, { R = BACK_R, L = BACK_L }),
	},
})
-- The hair smoothed back with one hand.
MOVES.smoothHair = move({
	fadeIn = 0.35,
	fadeOut = 0.45,
	keys = {
		key(0, { gR = 0.15, hpitch = 0.05 }, { R = T("head", 0.12, 0.3, -0.12, { 1, 0.6, -0.3 }) }),
		key(0.6, { hpitch = -0.04 }, { ease = "inout", R = T("head", 0.12, 0.32, 0.1, { 1, 0.6, 0.1 }) }),
		key(1.15, { hpitch = 0, aRp = 0.25, aRo = 0.3, eR = 0.6, gR = 0.35 }, { ease = "inout", R = false }),
	},
})
-- A slow look round over the shoulder and back (a ghost, an elder).
MOVES.lookBehind = move({
	fadeIn = 0.6,
	fadeOut = 0.8,
	gaze = { 1.4, 0.05 },
	keys = {
		key(0, { syaw = 0.15 }),
		key(2.0, { syaw = 0.2 }),
	},
})

---------------------------------------------------------------- talk

-- Listening: the hands clasped in front, behind the back, at the belt, or at rest.
MOVES.listenClasp = move({
	hold = true,
	fadeIn = 0.4,
	keys = { key(0, { gR = 0.5, gL = 0.5 }, { R = CLASP_R, L = CLASP_L }), key(2, {}) },
})
MOVES.listenBehind = move({
	hold = true,
	fadeIn = 0.45,
	keys = { key(0, { gR = 0.55, gL = 0.55, spitch = -0.02 }, { R = BACK_R, L = BACK_L }), key(2, {}) },
})
MOVES.listenBelt = move({
	hold = true,
	fadeIn = 0.4,
	keys = { key(0, { gR = 0.7, gL = 0.7 }, { R = BELT_R, L = BELT_L }), key(2, {}) },
})
MOVES.listenHips = move({
	hold = true,
	fadeIn = 0.45,
	keys = { key(0, { gR = 0.65, gL = 0.65, wRp = -0.2, wLp = -0.2 }, { R = HIP_R, L = HIP_L }), key(2, {}) },
})
MOVES.listenRest = move({
	hold = true,
	fadeIn = 0.4,
	keys = {
		key(0, { aRp = 0.12, aRo = 0.12, eR = 0.35, aLp = 0.12, aLo = 0.12, eL = 0.35, gR = 0.35, gL = 0.35 }),
		key(2, {}),
	},
})
MOVES.listenPray = move({
	hold = true,
	fadeIn = 0.45,
	keys = { key(0, { gR = 0.1, gL = 0.1, wRy = 0.3, wLy = 0.3 }, { R = PRAY_R, L = PRAY_L }), key(2, {}) },
})

-- A beat with the right hand: it comes up open in front and marks the words, then settles.
MOVES.talkBeat = move({
	fadeIn = 0.25,
	fadeOut = 0.4,
	keys = {
		key(0, { aRp = 0.4, aRo = 0.18, aRy = 0.1, aRt = 0, eR = 1.35, wRp = -0.1, wRy = -0.8, gR = 0.2 }),
		key(0.35, { aRp = 0.5, aRo = 0.2, eR = 1.5, gR = 0.15, spitch = 0.02 }, { ease = "out" }),
		key(1.5, { aRp = 0.45, eR = 1.42, spitch = 0.01 }),
		key(1.85, {}),
	},
})
MOVES.talkBeatL = mirror(MOVES.talkBeat)
-- Both palms open outward and down: "you see", "that's how it is".
MOVES.talkOpen = move({
	fadeIn = 0.3,
	fadeOut = 0.45,
	keys = {
		key(0, {
			aRp = 0.3,
			aRo = 0.25,
			aRt = -0.1,
			eR = 1.3,
			wRy = -1.3,
			gR = 0.1,
			aLp = 0.3,
			aLo = 0.25,
			aLt = -0.1,
			eL = 1.3,
			wLy = -1.3,
			gL = 0.1,
		}),
		key(
			0.4,
			{ aRo = 0.42, aLo = 0.42, eR = 1.2, eL = 1.2, aRt = -0.35, aLt = -0.35, spitch = -0.02, hpitch = -0.04 },
			{
				ease = "out",
			}
		),
		key(1.3, { aRo = 0.38, aLo = 0.38, hpitch = 0.02 }),
		key(1.7, {}),
	},
})
-- A hand to the chest: "I", "me".
MOVES.talkSelf = move({
	fadeIn = 0.3,
	fadeOut = 0.4,
	keys = {
		key(0, { gR = 0.15, wRp = -0.3, spitch = 0, hpitch = 0 }, { R = CHEST_R }),
		key(0.4, { spitch = -0.03, hpitch = 0.05 }, { R = CHEST_R }),
		key(1.2, { spitch = 0, hpitch = 0 }, { R = CHEST_R }),
	},
})
-- A shrug: the shoulders up, palms up and out, the head tilted.
MOVES.talkShrug = move({
	fadeIn = 0.2,
	fadeOut = 0.4,
	keys = {
		key(0, {
			aRp = 0.15,
			aRo = 0.25,
			aRt = -0.5,
			eR = 1.35,
			wRy = -1.3,
			gR = 0.05,
			aLp = 0.15,
			aLo = 0.25,
			aLt = -0.5,
			eL = 1.35,
			wLy = -1.3,
			gL = 0.05,
		}),
		key(
			0.3,
			{ cRu = 0.2, cLu = 0.2, aRo = 0.35, aLo = 0.35, aRt = -0.85, aLt = -0.85, hroll = 0.12, hpitch = -0.03 },
			{
				ease = "out",
			}
		),
		key(0.85, { cRu = 0.17, cLu = 0.17, hroll = 0.1 }),
		key(1.2, { cRu = 0, cLu = 0, aRt = -0.3, aLt = -0.3, hroll = 0, hpitch = 0 }, { ease = "inout" }),
	},
})
-- Explaining: both hands in front turning over each other.
MOVES.talkExplain = move({
	fadeIn = 0.3,
	fadeOut = 0.45,
	keys = {
		key(0, { gR = 0.25, gL = 0.25, wRy = -0.5, wLy = -0.5 }, {
			R = T("chest", 0.12, -0.42, -0.36, { 1, -0.5, 0.3 }),
			L = T("chest", -0.12, -0.42, -0.36, { 1, -0.5, 0.3 }),
		}),
		key(1.8, {}),
	},
	osc = {
		{ c = "R.y", amp = 0.04, hz = 1.4, from = 0.25, to = 1.7 },
		{ c = "R.z", amp = 0.04, hz = 1.4, from = 0.43, to = 1.7 },
		{ c = "L.y", amp = -0.04, hz = 1.4, from = 0.25, to = 1.7 },
		{ c = "L.z", amp = -0.04, hz = 1.4, from = 0.43, to = 1.7 },
	},
})
-- A dismissive wave of the hand ("never mind", "off you go").
MOVES.talkWave = move({
	fadeIn = 0.2,
	fadeOut = 0.35,
	keys = {
		key(0, { aRp = 0.45, aRo = 0.35, aRy = 0.25, eR = 1.5, wRy = -0.5, gR = 0.15 }),
		key(0.25, { aRy = 0.45, aRt = 0.3, wRp = 0.3, hroll = -0.05 }, { ease = "out" }),
		key(0.55, { aRy = -0.15, aRt = -0.4, wRp = -0.35, hroll = 0.04 }, { ease = "inout" }),
		key(0.9, { aRy = 0.05, aRt = 0, wRp = 0, hroll = 0 }, { ease = "inout" }),
	},
})
-- An emphatic fist (a guard, a captain): it comes down once with the word.
MOVES.talkFist = move({
	fadeIn = 0.2,
	fadeOut = 0.4,
	keys = {
		key(0, { aRp = 0.45, aRo = 0.3, aRy = 0.15, eR = 1.6, gR = 0.9, spitch = 0 }),
		key(0.35, { aRp = 0.55, eR = 1.8, spitch = -0.02, hpitch = -0.04 }, { ease = "out" }),
		key(0.5, { aRp = 0.42, eR = 1.45, spitch = 0.03, hpitch = 0.08 }, { ease = "in" }),
		key(1.1, { spitch = 0, hpitch = 0 }),
	},
})
-- Pointing the way (the quest's direction; Logic/NpcMotion turns the arm and the chest toward it): the arm reaches out
-- straight, the index points, the head follows it.
MOVES.talkPoint = move({
	fadeIn = 0.35,
	fadeOut = 0.45,
	keys = {
		key(0, { aRp = 0.8, aRo = 0.2, aRy = 0, eR = 0.8, wRp = 0, wRy = -0.3, gR = 0.85, iR = 0.4 }),
		key(0.45, { aRp = 1.38, aRo = 0.12, eR = 0.12, wRp = -0.1, gR = 0.9, iR = 1 }, { ease = "out" }),
		key(1.4, { aRp = 1.3, eR = 0.16 }),
		key(1.75, { aRp = 0.6, eR = 0.6, iR = 0.2, gR = 0.4 }, { ease = "inout" }),
	},
})
-- A finger raised: "mark my words".
MOVES.talkFinger = move({
	fadeIn = 0.25,
	fadeOut = 0.4,
	keys = {
		key(0, { aRp = 0.55, aRo = 0.35, aRy = 0.1, eR = 1.9, wRy = -0.3, gR = 0.9, iR = 1, hpitch = 0 }),
		key(0.35, { aRp = 0.65, eR = 2.05, hpitch = -0.03 }, { ease = "out" }),
		key(1.2, { aRp = 0.6, eR = 1.95, hpitch = 0.03 }),
		key(1.5, {}),
	},
	osc = { { c = "wRp", amp = 0.12, hz = 2.6, from = 0.4, to = 1.2 } },
})

---------------------------------------------------------------- work

-- Hammering at the anvil in front (Anim/NpcRig puts a small anvil there): the tongs hold the piece on its face with
-- the left hand; the right raises the hammer over the shoulder, a beat of stillness at the top, then down onto the
-- piece (accelerating), the rebound and the next lift. Series of three to six blows, then the piece is turned and
-- looked at, the brow wiped, the back straightened.
local ANVIL = T("ground", 0.08, 1.1, -0.45, { 1, -0.4, 0.5 })
local ON_PIECE = T("ground", 0.08, 1.13, -0.45, { 1, -0.4, 0.5 })
local TONGS = T("ground", -0.2, 1.12, -0.42, { 1, -0.6, 0.4 })
-- The anvil Anim/NpcRig puts before the smith: its face's centre (leg lengths from his spot, root axes; `top` its height).
NpcStyles.ANVIL = { x = 0.02, z = -0.56, top = 1.0 }
MOVES.smithBase = move({
	hold = true,
	keys = {
		-- the tongs on the piece, the hammer resting on it between the phrases
		key(0, { spitch = 0.16, hpitch = 0.15, py = -0.012, gL = 0.85, gR = 0.9, wLy = 0.4, wRp = 0.2 }, {
			L = TONGS,
			R = ON_PIECE,
		}),
		key(1, {}),
	},
})
MOVES.smithBlow = move({
	fadeIn = 0.05,
	fadeOut = 0.05,
	keys = {
		-- resting on the piece after the last blow
		key(0, { gR = 0.95, wRp = 0.25, spitch = 0.02 }, { R = ON_PIECE }),
		-- up: the elbow lifts out and back, the hammer over the shoulder, the chest rises
		key(0.42, { wRp = -0.55, spitch = -0.05, hpitch = -0.02, sroll = -0.03, cRu = 0.12 }, {
			ease = "out",
			R = T("chest", 0.3, 0.1, -0.08, { 0.7, -0.1, 0.6 }),
		}),
		-- the beat at the top
		key(0.52, { wRp = -0.65 }, { R = T("chest", 0.31, 0.13, -0.06, { 0.7, -0.1, 0.6 }) }),
		-- the blow: down onto the piece, the chest into it
		key(
			0.7,
			{ wRp = 0.3, spitch = 0.06, hpitch = 0.04, sroll = 0.02, cRu = 0, py = -0.012 },
			{ ease = "fall", R = ANVIL }
		),
		-- the rebound
		key(
			0.8,
			{ wRp = 0.1, spitch = 0.03, py = -0.005 },
			{ ease = "out", R = T("ground", 0.08, 1.2, -0.44, { 1, -0.4, 0.5 }) }
		),
		key(1.0, { wRp = 0.2, spitch = 0.02, py = 0 }, { ease = "inout", R = ON_PIECE }),
	},
})
-- A light tap between the heavy blows (shaping).
MOVES.smithTap = move({
	fadeIn = 0.05,
	fadeOut = 0.05,
	keys = {
		key(0, { gR = 0.95, wRp = 0.2 }, { R = ON_PIECE }),
		key(0.2, { wRp = -0.3, spitch = -0.01 }, { ease = "out", R = T("ground", 0.1, 1.32, -0.42, { 1, -0.2, 0.5 }) }),
		key(0.32, { wRp = 0.25, spitch = 0.02 }, { ease = "fall", R = ANVIL }),
		key(0.48, { wRp = 0.2, spitch = 0.01 }, { R = ON_PIECE }),
	},
})
-- The piece lifted in the tongs and turned before the eyes, then laid back.
MOVES.smithInspect = move({
	fadeIn = 0.3,
	fadeOut = 0.35,
	gaze = { -0.25, 0.15 },
	keys = {
		key(0, { gR = 0.9, wLy = 0.4, spitch = 0.1 }, {
			R = T("ground", 0.18, 1.12, -0.38, { 1, -0.4, 0.5 }),
			L = TONGS,
		}),
		key(0.6, { wLy = 0.9, spitch = 0, hpitch = 0.05 }, {
			ease = "inout",
			L = T("chest", -0.1, -0.22, -0.34, { 1, -0.5, 0.3 }),
		}),
		key(1.4, { wLy = -0.2 }, { ease = "inout" }),
		key(2.0, { wLy = 0.6 }, { ease = "inout" }),
		key(2.5, { wLy = 0.4, spitch = 0.1, hpitch = 0.1 }, { ease = "inout", L = TONGS }),
	},
})
-- Straightening up from the anvil: the back stretched, a deep breath.
MOVES.smithRest = move({
	fadeIn = 0.4,
	fadeOut = 0.5,
	gaze = { 0.3, -0.1 },
	keys = {
		key(0, { spitch = -0.1, hpitch = -0.05, aRp = 0.2, aRo = 0.25, eR = 0.6, gR = 0.9 }, { R = false }),
		key(1.2, { spitch = -0.12, hpitch = -0.08, cRu = 0.08, cLu = 0.08 }, { ease = "inout" }),
		key(2.4, { spitch = -0.05, cRu = 0, cLu = 0 }, { ease = "inout" }),
	},
})

-- The merchant arranging his stall behind him: reaching for a piece, setting it straight, patting a pile; leaning in.
local STALL_R = T("ground", 0.25, 1.15, 0.52, { 1, -0.5, -0.1 })
local STALL_L = T("ground", -0.25, 1.15, 0.52, { 1, -0.5, -0.1 })
MOVES.goodsBase = move({
	hold = true,
	keys = { key(0, { spitch = 0.18, hpitch = 0.16, py = -0.01 }), key(1, {}) },
})
MOVES.goodsArrange = move({
	fadeIn = 0.4,
	fadeOut = 0.4,
	gaze = { 0, 0.45 },
	keys = {
		key(0, { gR = 0.3, gL = 0.3 }, { R = STALL_R }),
		key(0.6, { gR = 0.75, syaw = -0.05 }, { ease = "inout", R = T("ground", 0.4, 1.12, 0.58, { 1, -0.5, -0.1 }) }),
		key(1.2, { syaw = 0.08 }, { ease = "inout", R = T("ground", -0.05, 1.16, 0.54, { 1, -0.5, -0.1 }) }),
		key(1.45, { gR = 0.3 }, { R = T("ground", -0.05, 1.13, 0.54, { 1, -0.5, -0.1 }) }),
		key(2.0, { syaw = 0 }, { ease = "inout", L = STALL_L }),
		key(2.6, { gL = 0.2 }, { L = T("ground", -0.3, 1.12, 0.5, { 1, -0.5, -0.1 }) }),
		key(3.0, {}),
	},
	osc = { { c = "L.y", amp = 0.02, hz = 3, from = 2.1, to = 2.9 } },
})
MOVES.goodsLook = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { 0.3, 0.35 },
	keys = {
		key(0, { gR = 0.6, gL = 0.6, spitch = -0.08 }, { R = HIP_R, L = HIP_L }),
		key(2.2, {}),
	},
})
-- Counting coins: the left palm up before the belly, the right fingers picking coins over it.
local PALM_L = T("hips", -0.06, 0.2, -0.3, { 1, -0.6, 0.4 })
MOVES.coins = move({
	fadeIn = 0.45,
	fadeOut = 0.5,
	gaze = { -0.05, 0.55 },
	keys = {
		key(0, { gL = 0.25, wLy = -1.2, gR = 0.6, wRp = 0.4, hpitch = 0.08 }, {
			L = PALM_L,
			R = T("hips", 0.07, 0.25, -0.29, { 1, -0.5, 0.4 }),
		}),
		key(2.8, {}),
	},
	osc = {
		{ c = "R.y", amp = 0.02, hz = 2.2, from = 0.4, to = 2.6 },
		{ c = "R.x", amp = 0.015, hz = 1.1, from = 0.4, to = 2.6 },
	},
})
-- The coins weighed in the palm and pocketed.
MOVES.coinsPocket = move({
	fadeIn = 0.35,
	fadeOut = 0.4,
	gaze = { 0, 0.4 },
	keys = {
		key(0, { gL = 0.5, wLy = -1.0 }, { L = PALM_L }),
		key(0.5, {}, { L = T("hips", -0.06, 0.23, -0.3, { 1, -0.6, 0.4 }) }),
		key(0.9, { gL = 0.8 }, { ease = "in", L = T("hips", -0.06, 0.17, -0.3, { 1, -0.6, 0.4 }) }),
		key(1.5, { gL = 0.7 }, { ease = "inout", L = T("hips", -0.27, 0.08, -0.08, { 1, 0, 0.5 }) }),
		key(1.9, {}),
	},
})

-- The innkeeper's rag on the counter: circles, a stretch to the far side, a look at the shine.
local COUNTER_R = T("ground", 0.12, 1.08, -0.52, { 1, -0.5, 0.4 })
MOVES.wipeBase = move({
	hold = true,
	keys = {
		key(0, { spitch = 0.14, hpitch = 0.1, gL = 0.3 }, { L = T("ground", -0.3, 1.1, -0.42, { 1, -0.6, 0.3 }) }),
		key(1, {}),
	},
})
MOVES.wipeCircles = move({
	fadeIn = 0.35,
	fadeOut = 0.35,
	gaze = { -0.05, 0.5 },
	keys = {
		key(0, { gR = 0.45, wRp = 0.35 }, { R = COUNTER_R }),
		key(3.2, {}),
	},
	osc = {
		{ c = "R.x", amp = 0.09, hz = 1.15, from = 0.2, to = 3.0 },
		{ c = "R.z", amp = 0.06, hz = 1.15, from = 0.42, to = 3.0 },
		{ c = "syaw", amp = 0.04, hz = 1.15, from = 0.2, to = 3.0 },
	},
})
MOVES.wipeLong = move({
	fadeIn = 0.3,
	fadeOut = 0.35,
	gaze = { 0.1, 0.45 },
	keys = {
		key(0, { gR = 0.45, wRp = 0.35 }, { R = COUNTER_R }),
		key(
			0.7,
			{ spitch = 0.08, syaw = 0.15 },
			{ ease = "inout", R = T("ground", -0.25, 1.08, -0.62, { 1, -0.5, 0.4 }) }
		),
		key(1.4, { spitch = 0, syaw = -0.08 }, { ease = "inout", R = T("ground", 0.4, 1.08, -0.5, { 1, -0.5, 0.4 }) }),
		key(2.0, { syaw = 0 }, { ease = "inout", R = COUNTER_R }),
	},
})
MOVES.wipeCheck = move({
	fadeIn = 0.35,
	fadeOut = 0.4,
	gaze = { 0.2, 0.3 },
	keys = {
		key(0, { gR = 0.5, spitch = -0.06, hpitch = 0 }, { R = HIP_R }),
		key(1.8, {}),
	},
})

-- The stablemaster cleaning a piece of tack (a bit, a buckle) held in the left hand, the right rubbing it.
local TACK_L = T("hips", -0.08, 0.32, -0.3, { 1, -0.6, 0.4 })
MOVES.tackClean = move({
	fadeIn = 0.45,
	fadeOut = 0.45,
	gaze = { -0.05, 0.5 },
	keys = {
		key(0, { gL = 0.7, wLy = 0.4, gR = 0.55, hpitch = 0.05 }, {
			L = TACK_L,
			R = T("hips", 0.02, 0.34, -0.32, { 1, -0.5, 0.4 }),
		}),
		key(3.0, {}),
	},
	osc = {
		{ c = "R.x", amp = 0.045, hz = 2.1, from = 0.3, to = 2.8 },
		{ c = "R.y", amp = 0.015, hz = 4.2, from = 0.3, to = 2.8 },
		{ c = "wLy", amp = 0.25, hz = 0.35, from = 0.3, to = 2.8 },
	},
})

-- A guard on watch: a slow scan along the street, chin up; the weapon hand regripped.
MOVES.watchScan = move({
	fadeIn = 0.6,
	fadeOut = 0.6,
	keys = {
		key(0, { spitch = -0.03, hpitch = -0.04 }),
		key(5.5, {}),
	},
	osc = { { c = "hyaw", amp = 0.75, hz = 0.16, from = 0, to = 5.5 } },
})
MOVES.watchRegrip = move({
	fadeIn = 0.25,
	fadeOut = 0.35,
	keys = {
		key(0, { aRp = 0.2, aRo = 0.1, eR = 1.2, gR = 0.9, cRu = 0 }),
		key(0.35, { aRp = 0.32, eR = 1.45, gR = 0.5, cRu = 0.08, py = 0.008 }, { ease = "out" }),
		key(0.6, { aRp = 0.22, eR = 1.25, gR = 0.95, cRu = 0, py = 0 }, { ease = "in" }),
		key(1.0, {}),
	},
})

-- Teodor channelling the portal: the hands forward, palms toward each other, slow circles around a held glow, a surge.
MOVES.channelBase = move({
	hold = true,
	keys = { key(0, { spitch = -0.04, hpitch = 0.04 }), key(1, {}) },
})
MOVES.channelHold = move({
	fadeIn = 0.8,
	fadeOut = 0.8,
	gaze = { 0, 0.15 },
	keys = {
		key(0, { gR = 0.15, gL = 0.15, wRy = 0.9, wLy = 0.9 }, {
			R = T("chest", 0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
			L = T("chest", -0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
		}),
		key(4.5, {}),
	},
	osc = {
		{ c = "R.y", amp = 0.045, hz = 0.45, from = 0.4, to = 4.2 },
		{ c = "R.z", amp = 0.04, hz = 0.45, from = 0.95, to = 4.2 },
		{ c = "L.y", amp = -0.045, hz = 0.45, from = 0.4, to = 4.2 },
		{ c = "L.z", amp = -0.04, hz = 0.45, from = 0.95, to = 4.2 },
	},
})
MOVES.channelSurge = move({
	fadeIn = 0.5,
	fadeOut = 0.7,
	gaze = { 0, -0.05 },
	keys = {
		key(0, { gR = 0.15, gL = 0.15, wRy = 0.9, wLy = 0.9 }, {
			R = T("chest", 0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
			L = T("chest", -0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
		}),
		key(0.9, { spitch = -0.08, hpitch = -0.06, cRu = 0.08, cLu = 0.08 }, {
			ease = "inout",
			R = T("chest", 0.24, -0.1, -0.44, { 1, -0.3, 0.2 }),
			L = T("chest", -0.24, -0.1, -0.44, { 1, -0.3, 0.2 }),
		}),
		key(1.8, { spitch = -0.1, gR = 0.0, gL = 0.0 }, {
			R = T("chest", 0.3, 0.02, -0.46, { 1, -0.2, 0.2 }),
			L = T("chest", -0.3, 0.02, -0.46, { 1, -0.2, 0.2 }),
		}),
		key(2.8, { spitch = 0, hpitch = 0, cRu = 0, cLu = 0, gR = 0.15, gL = 0.15 }, {
			ease = "inout",
			R = T("chest", 0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
			L = T("chest", -0.17, -0.38, -0.38, { 1, -0.6, 0.3 }),
		}),
	},
	osc = {
		{ c = "wRp", amp = 0.06, hz = 7, from = 0.9, to = 1.8 },
		{ c = "wLp", amp = 0.06, hz = 7, from = 0.9, to = 1.8 },
	},
})

-- Reading a book held in both hands, the head bent over it; a page turned now and then.
local BOOK_R = T("chest", 0.11, -0.4, -0.34, { 1, -0.7, 0.3 })
local BOOK_L = T("chest", -0.11, -0.4, -0.34, { 1, -0.7, 0.3 })
MOVES.readBase = move({
	hold = true,
	keys = {
		key(0, { spitch = 0.06, gR = 0.45, gL = 0.45, wRy = 0.7, wLy = 0.7 }, { R = BOOK_R, L = BOOK_L }),
		key(1, {}),
	},
})
MOVES.readHold = move({
	fadeIn = 0.3,
	fadeOut = 0.3,
	gaze = { 0, 0.55 },
	keys = { key(0, {}, { R = BOOK_R, L = BOOK_L }), key(4.5, {}) },
	osc = { { c = "hyaw", amp = 0.08, hz = 0.33, from = 0.2, to = 4.3 } },
})
MOVES.readPage = move({
	fadeIn = 0.25,
	fadeOut = 0.3,
	gaze = { 0, 0.55 },
	keys = {
		key(0, {}, { R = BOOK_R, L = BOOK_L }),
		key(0.4, { gR = 0.6 }, { ease = "inout", R = T("chest", 0.08, -0.37, -0.35, { 1, -0.7, 0.3 }) }),
		key(0.85, { gR = 0.6 }, { ease = "inout", R = T("chest", -0.08, -0.36, -0.37, { 1, -0.6, 0.3 }) }),
		key(1.3, { gR = 0.45 }, { ease = "inout", R = BOOK_R }),
	},
})

-- Prayer: the palms together before the chest, the head bowed; a deep breath and the lips moving.
MOVES.prayHold = move({
	fadeIn = 0.7,
	fadeOut = 0.7,
	gaze = { 0, 0.5 },
	keys = {
		key(0, { gR = 0.1, gL = 0.1, wRy = 0.3, wLy = 0.3, spitch = 0.06 }, { R = PRAY_R, L = PRAY_L }),
		key(6, {}),
	},
	osc = { { c = "hpitch", amp = 0.025, hz = 0.5, from = 0.5, to = 5.5 } },
})

-- The fisherman: the rod held in both hands before the hip, a cast over the shoulder, the wait with small twitches,
-- the reel turned.
local ROD_R = T("hips", 0.12, 0.28, -0.3, { 1, -0.4, 0.4 })
local ROD_L = T("hips", -0.04, 0.42, -0.42, { 1, -0.5, 0.3 })
MOVES.fishBase = move({
	hold = true,
	keys = { key(0, { gR = 0.85, gL = 0.8, spitch = 0.04 }, { R = ROD_R, L = ROD_L }), key(1, {}) },
})
MOVES.fishWait = move({
	fadeIn = 0.3,
	fadeOut = 0.3,
	gaze = { 0, 0.15 },
	keys = { key(0, {}, { R = ROD_R, L = ROD_L }), key(5, {}) },
	osc = { { c = "L.y", amp = 0.015, hz = 0.7, from = 1.5, to = 3.2 } },
})
MOVES.fishCast = move({
	fadeIn = 0.2,
	fadeOut = 0.3,
	gaze = { 0, 0.05 },
	keys = {
		key(0, { syaw = 0 }, { R = ROD_R, L = ROD_L }),
		-- back over the right shoulder
		key(0.7, { syaw = -0.35, spitch = -0.08, sroll = -0.04 }, {
			ease = "inout",
			R = T("chest", 0.3, 0.08, -0.15, { 1, 0.1, 0.3 }),
			L = T("chest", 0.08, -0.15, -0.32, { 1, -0.3, 0.3 }),
		}),
		-- the cast: forward and down
		key(0.95, { syaw = 0.08, spitch = 0.08, sroll = 0.02 }, {
			ease = "in",
			R = T("hips", 0.1, 0.45, -0.46, { 1, -0.4, 0.4 }),
			L = T("hips", -0.06, 0.5, -0.5, { 1, -0.5, 0.3 }),
		}),
		key(1.6, { syaw = 0, spitch = 0, sroll = 0 }, { ease = "inout", R = ROD_R, L = ROD_L }),
	},
})
MOVES.fishReel = move({
	fadeIn = 0.3,
	fadeOut = 0.3,
	gaze = { 0, 0.2 },
	keys = { key(0, {}, { R = ROD_R, L = ROD_L }), key(3, {}) },
	osc = {
		{ c = "R.y", amp = 0.035, hz = 1.6, from = 0.2, to = 2.8 },
		{ c = "R.z", amp = 0.035, hz = 1.6, from = 0.36, to = 2.8 },
	},
})

-- Stirring a pot with a long spoon in both hands (a witch, the herbalist, the alchemist).
MOVES.stir = move({
	fadeIn = 0.45,
	fadeOut = 0.45,
	gaze = { 0, 0.55 },
	keys = {
		key(0, { gR = 0.8, gL = 0.8, spitch = 0.12, hpitch = 0.1 }, {
			R = T("hips", 0.05, 0.3, -0.4, { 1, -0.5, 0.4 }),
			L = T("hips", -0.02, 0.42, -0.36, { 1, -0.5, 0.4 }),
		}),
		key(4, {}),
	},
	osc = {
		{ c = "R.x", amp = 0.07, hz = 0.6, from = 0.3, to = 3.8 },
		{ c = "R.z", amp = 0.07, hz = 0.6, from = 0.72, to = 3.8 },
		{ c = "L.x", amp = 0.05, hz = 0.6, from = 0.3, to = 3.8 },
		{ c = "L.z", amp = 0.05, hz = 0.6, from = 0.72, to = 3.8 },
		{ c = "syaw", amp = 0.05, hz = 0.6, from = 0.3, to = 3.8 },
	},
})
-- Sorting herbs in the palm (the herbalist, the alchemist's vial).
MOVES.herbs = move({
	fadeIn = 0.45,
	fadeOut = 0.45,
	gaze = { 0, 0.5 },
	keys = {
		key(
			0,
			{ gL = 0.3, wLy = -1.1, gR = 0.65, wRp = 0.3 },
			{ L = PALM_L, R = T("hips", 0.05, 0.36, -0.32, { 1, -0.5, 0.4 }) }
		),
		key(1.0, {}, { R = T("hips", 0.0, 0.32, -0.32, { 1, -0.5, 0.4 }) }),
		key(1.5, {}, { R = T("hips", 0.12, 0.4, -0.28, { 1, -0.5, 0.4 }) }),
		key(2.3, {}, { R = T("hips", 0.02, 0.33, -0.32, { 1, -0.5, 0.4 }) }),
		key(3.0, {}),
	},
})
-- The alchemist holds a vial up to the light and swirls it.
MOVES.vial = move({
	fadeIn = 0.4,
	fadeOut = 0.45,
	gaze = { -0.12, -0.12 },
	keys = {
		key(0, { gR = 0.7, wRp = -0.2 }, { R = T("head", 0.1, 0.04, -0.4, { 1, -0.3, 0.3 }) }),
		key(2.4, {}),
	},
	osc = { { c = "wRr", amp = 0.25, hz = 1.8, from = 0.4, to = 2.1 } },
})

-- The barber's scissors snipping the air before him, the comb in the other hand.
MOVES.snip = move({
	fadeIn = 0.35,
	fadeOut = 0.4,
	gaze = { 0, 0.15 },
	keys = {
		key(0, { gR = 0.6, gL = 0.5, wRp = -0.3 }, {
			R = T("chest", 0.14, -0.2, -0.42, { 1, -0.3, 0.3 }),
			L = T("chest", -0.1, -0.15, -0.4, { 1, -0.4, 0.3 }),
		}),
		key(2.4, {}),
	},
	osc = {
		{ c = "gR", amp = 0.25, hz = 3.4, from = 0.3, to = 2.2 },
		{ c = "R.x", amp = 0.03, hz = 0.8, from = 0.3, to = 2.2 },
	},
})

-- A lookout: the hand shading the eyes, a long look out, a turn of the head across the distance.
MOVES.lookout = move({
	fadeIn = 0.5,
	fadeOut = 0.55,
	gaze = { 0.1, -0.08 },
	keys = {
		key(0, { gR = 0.1, wRp = 0.2, spitch = -0.03 }, { R = T("head", 0.0, 0.2, -0.24, { 1, 0.3, -0.3 }) }),
		key(3.5, {}),
	},
	osc = { { c = "hyaw", amp = 0.35, hz = 0.18, from = 0.5, to = 3.4 } },
})

-- The ledger: a book in the left hand, the right writing.
MOVES.ledger = move({
	fadeIn = 0.45,
	fadeOut = 0.45,
	gaze = { 0, 0.55 },
	keys = {
		key(0, { gL = 0.45, wLy = 0.8, gR = 0.8, wRp = 0.35, hpitch = 0.08 }, {
			L = T("chest", -0.08, -0.42, -0.33, { 1, -0.7, 0.3 }),
			R = T("chest", 0.05, -0.38, -0.36, { 1, -0.5, 0.3 }),
		}),
		key(3.5, {}),
	},
	osc = {
		{ c = "R.x", amp = 0.025, hz = 0.9, from = 0.3, to = 3.3 },
		{ c = "R.y", amp = 0.006, hz = 5, from = 0.3, to = 3.3 },
	},
})

---------------------------------------------------------------- mirrored copies

-- Every move on the other side (Logic/NpcMotion takes it when the model's hand that the move uses holds a prop).
NpcStyles.MIRRORED = {} :: { [string]: Move }
for name, m in MOVES do
	NpcStyles.MIRRORED[name] = mirror(m)
end
NpcStyles.mirror = mirror

---------------------------------------------------------------- role styles

local function W(name: string, weight: number, reps: { number }?, effort: number?): Weighted
	return { name = name, weight = weight, reps = reps, effort = effort }
end

-- Every style starts from this: a relaxed townsperson.
local BASE: Style = {
	id = "townsfolk",
	stance = {
		pose = { aRp = 0.08, aRo = 0.13, eR = 0.32, aLp = 0.08, aLo = 0.13, eL = 0.32, wRy = 0, wLy = 0, py = -0.004 },
		width = 0,
		toeOut = 0.18,
		grip = 0.35,
	},
	breath = 4.2,
	breathDepth = 1,
	shift = 0.85,
	shiftEvery = { 4, 10 },
	sway = 1,
	tempo = 1,
	walkSpeed = 3.6,
	glance = { every = { 2.5, 6.5 }, ahead = 0.4, yaw = 0.65, pitch = 0.02, down = 0.15, turn = 0.4 },
	look = { range = 13, hold = { 2.2, 5 }, away = { 2, 6 }, weight = 1, atWork = 0.7 },
	greet = { range = 8.5, me = "greetWave", other = "greetNodOther" },
	fidgets = {
		W("scratchHead", 1),
		W("rollShoulders", 1),
		W("handsOnHips", 1),
		W("crossArms", 0.8),
		W("rubNeck", 0.6),
		W("lookSky", 0.5),
		W("stretchBack", 0.5),
		W("checkHand", 0.5),
		W("scratchChin", 0.6),
	},
	fidgetEvery = { 6, 14 },
	work = nil,
	talk = {
		listen = "listenRest",
		gestures = {
			W("talkBeat", 1.2),
			W("talkBeatL", 0.6),
			W("talkOpen", 1),
			W("talkSelf", 0.5),
			W("talkShrug", 0.5),
			W("talkExplain", 0.7),
			W("talkWave", 0.4),
		},
		speak = { 2.5, 4.5 },
		listenFor = { 3, 6 },
		energy = 1,
		beats = 1,
	},
	pace = nil,
	float = nil,
	prop = nil,
}

-- A style: BASE with `over` laid on (tables in `over` replace BASE's whole; `stance.pose` keys add to BASE's).
local function style(id: string, over: { [string]: any }): Style
	local out: any = table.clone(BASE)
	for k, v in over do
		out[k] = v
	end
	if over.stance then
		local pose = table.clone(BASE.stance.pose)
		for k, v in over.stance.pose or {} do
			pose[k] = v
		end
		out.stance = {
			pose = pose,
			width = over.stance.width or BASE.stance.width,
			toeOut = over.stance.toeOut or BASE.stance.toeOut,
			grip = over.stance.grip or BASE.stance.grip,
		}
	end
	out.id = id
	return out
end

local function talk(over: { [string]: any }): { [string]: any }
	local out = table.clone(BASE.talk)
	for k, v in over do
		(out :: any)[k] = v
	end
	return out
end

local ROLES: { [string]: Style } = {}
NpcStyles.ROLES = ROLES

ROLES.townsfolk = BASE

-- Merchants and stallholders: easy, the belly forward, generous gestures; the stall behind them gets tidied.
ROLES.merchant = style("merchant", {
	stance = { pose = { spitch = -0.05, ppitch = -0.03, hpitch = 0.03 }, width = 0.02, toeOut = 0.22 },
	shift = 1,
	greet = { range = 9, me = "greetWave", other = "greetNodOther" },
	fidgets = {
		W("rubHands", 1.4),
		W("adjustBelt", 1),
		W("handsOnHips", 0.8),
		W("scratchChin", 0.6),
		W("rollShoulders", 0.5),
	},
	work = {
		base = MOVES.goodsBase,
		behind = true,
		stand = { 0, 0.22 },
		phrases = { W("goodsArrange", 3), W("goodsLook", 1), W("coins", 1.2) },
	},
	talk = talk({
		listen = "listenClasp",
		gestures = {
			W("talkOpen", 1.4),
			W("talkBeat", 1),
			W("talkSelf", 0.6),
			W("talkExplain", 0.8),
			W("talkShrug", 0.5),
		},
		energy = 1.1,
		beats = 1.1,
	}),
})
-- A shopkeeper at his counter (class vendors, the backpacker): like a merchant, more upright, counts his coins.
ROLES.vendor = style("vendor", {
	stance = { pose = { spitch = -0.02 }, toeOut = 0.2 },
	greet = { range = 9, me = "greetRaise", other = "greetNodOther" },
	fidgets = {
		W("rubHands", 1),
		W("adjustBelt", 0.8),
		W("crossArms", 0.8),
		W("checkHand", 0.5),
		W("scratchChin", 0.5),
	},
	work = { phrases = { W("coins", 2), W("coinsPocket", 1), W("goodsLook", 0.6) } },
	talk = talk({ listen = "listenClasp" }),
})
-- The smith: broad stance over the anvil, heavy blows in series, short rests.
ROLES.smith = style("smith", {
	stance = {
		pose = { aRo = 0.2, aLo = 0.2, eR = 0.4, eL = 0.4, spitch = 0.02 },
		width = 0.06,
		toeOut = 0.25,
		grip = 0.6,
	},
	breathDepth = 1.2,
	shift = 0.5,
	greet = { range = 8, me = "greetRaise", other = "greetNodOther" },
	fidgets = { W("wipeBrow", 1.2), W("rollShoulders", 1), W("handsOnHips", 1), W("stretchBack", 0.8) },
	work = {
		base = MOVES.smithBase,
		prop = "anvil",
		gaze = { 0.05, 0.55 },
		phrases = {
			W("smithBlow", 3, { 3, 6 }, 0.35),
			W("smithTap", 1.2, { 3, 5 }, 0.15),
			W("smithInspect", 1),
			W("smithRest", 0.5),
			W("wipeBrow", 0.4),
		},
	},
	look = { range = 12, hold = { 1, 2.2 }, away = { 4, 9 }, weight = 1, atWork = 0.5 },
	talk = talk({
		listen = "listenHips",
		gestures = { W("talkBeat", 1), W("talkFist", 0.8), W("talkOpen", 0.6), W("talkShrug", 0.4) },
		energy = 0.95,
	}),
})
-- A guard: upright, square on both feet, chin up; the weapon held, a slow scan of the street, a few paces now and then.
ROLES.guard = style("guard", {
	stance = {
		pose = {
			spitch = -0.05,
			hpitch = -0.04,
			ppitch = -0.02,
			aRp = 0.1,
			aRo = 0.1,
			eR = 0.25,
			aLp = 0.05,
			aLo = 0.1,
			eL = 0.2,
			cRu = -0.02,
			cLu = -0.02,
		},
		width = 0.05,
		toeOut = 0.28,
		grip = 0.7,
	},
	shift = 0.35,
	shiftEvery = { 9, 18 },
	sway = 0.5,
	breathDepth = 0.85,
	glance = { every = { 3, 7 }, ahead = 0.55, yaw = 0.8, pitch = -0.02, down = 0.02, turn = 0.55 },
	look = { range = 14, hold = { 1.5, 3.5 }, away = { 3, 7 }, weight = 1, atWork = 0.8 },
	greet = { range = 8, me = "greetGuard", other = "greetGuard" },
	fidgets = { W("rollShoulders", 0.6), W("handsBehind", 1), W("watchRegrip", 1) },
	fidgetEvery = { 8, 16 },
	work = { phrases = { W("watchScan", 2), W("watchRegrip", 1) } },
	talk = talk({
		listen = "listenRest",
		gestures = { W("talkFist", 0.8), W("talkBeat", 1), W("talkFinger", 0.6), W("talkWave", 0.3) },
		energy = 0.9,
		beats = 0.7,
	}),
	pace = { span = 2.6, every = { 14, 26 }, axis = "side" },
	walkSpeed = 3.2,
})
-- A captain or a sergeant: upright, hands behind the back, surveys the plaza; firm gestures, a finger raised.
ROLES.captain = style("captain", {
	stance = { pose = { spitch = -0.06, hpitch = -0.05, ppitch = -0.02 }, width = 0.05, toeOut = 0.25 },
	shift = 0.45,
	shiftEvery = { 7, 14 },
	sway = 0.6,
	glance = { every = { 3, 7 }, ahead = 0.4, yaw = 0.85, pitch = -0.02, down = 0.05, turn = 0.5 },
	greet = { range = 9, me = "greetSalute", other = "greetGuard" },
	fidgets = { W("handsBehind", 2), W("crossArms", 0.6), W("rollShoulders", 0.4), W("thinkChin", 0.4) },
	fidgetEvery = { 5, 10 },
	talk = talk({
		listen = "listenBehind",
		gestures = { W("talkFinger", 1), W("talkFist", 0.8), W("talkBeat", 1), W("talkOpen", 0.5) },
		energy = 0.95,
	}),
	pace = { span = 2.2, every = { 18, 32 }, axis = "side" },
	walkSpeed = 3.2,
})
-- An elder: stooped, knees soft, slow; hands behind the back or clasped; small, slow gestures and many nods.
ROLES.elder = style("elder", {
	stance = {
		pose = { spitch = 0.2, hpitch = -0.12, ppitch = 0.06, py = -0.035, aRp = 0.15, aLp = 0.15 },
		toeOut = 0.24,
	},
	breath = 5,
	shift = 0.6,
	shiftEvery = { 6, 13 },
	tempo = 0.75,
	walkSpeed = 2.4,
	glance = { every = { 4, 9 }, ahead = 0.45, yaw = 0.5, pitch = 0.05, down = 0.25, turn = 0.7 },
	greet = { range = 8, me = "greetNod", other = "greetNodOther" },
	fidgets = {
		W("handsBehind", 1.5),
		W("rubNeck", 0.8),
		W("lookSky", 0.6),
		W("scratchChin", 0.6),
		W("stretchBack", 0.6),
	},
	fidgetEvery = { 7, 15 },
	talk = talk({
		listen = "listenBehind",
		gestures = { W("talkBeat", 1), W("talkOpen", 0.6), W("talkFinger", 0.5), W("talkSelf", 0.4) },
		speak = { 2.5, 5 },
		energy = 0.75,
		beats = 0.6,
	}),
})
-- A priest or a healer: serene, palms together; a bow; slow open-handed gestures.
ROLES.priest = style("priest", {
	stance = { pose = { spitch = 0.03, hpitch = 0.06 }, toeOut = 0.16 },
	breath = 4.8,
	shift = 0.45,
	sway = 0.7,
	tempo = 0.85,
	greet = { range = 8.5, me = "greetBow", other = "greetNodOther" },
	fidgets = { W("handsBehind", 0.6), W("lookSky", 1), W("thinkChin", 0.5) },
	fidgetEvery = { 8, 16 },
	work = { phrases = { W("prayHold", 1) } },
	talk = talk({
		listen = "listenPray",
		gestures = { W("talkOpen", 1.4), W("talkSelf", 1), W("talkBeat", 0.6) },
		energy = 0.8,
		beats = 0.6,
	}),
})
-- A scholar: reads, thinks with a hand at the chin, explains with a raised finger.
ROLES.scholar = style("scholar", {
	stance = { pose = { spitch = 0.06, hpitch = 0.08 }, toeOut = 0.16 },
	shift = 0.7,
	greet = { range = 8, me = "greetNod", other = "greetNodOther" },
	fidgets = { W("thinkChin", 1.5), W("smoothHair", 0.6), W("rubNeck", 0.6), W("scratchHead", 0.5) },
	work = { phrases = { W("readHold", 3), W("readPage", 1.2) } },
	look = { range = 11, hold = { 1.2, 2.5 }, away = { 4, 9 }, weight = 1, atWork = 0.45 },
	talk = talk({
		listen = "listenClasp",
		gestures = { W("talkFinger", 1.2), W("talkExplain", 1), W("talkBeat", 0.8), W("talkOpen", 0.5) },
	}),
})
-- A mage (the Portal Master Teodor): composed, hands that hold power; channels the portal's magic.
ROLES.mage = style("mage", {
	stance = { pose = { spitch = -0.03, hpitch = 0.02 }, toeOut = 0.18 },
	breath = 4.6,
	shift = 0.55,
	sway = 0.8,
	greet = { range = 9, me = "greetBow", other = "greetNodOther" },
	fidgets = { W("thinkChin", 1), W("handsBehind", 1), W("lookSky", 0.5) },
	work = {
		base = MOVES.channelBase,
		gaze = { 0, 0.12 },
		phrases = { W("channelHold", 2.5), W("channelSurge", 1) },
	},
	look = { range = 12, hold = { 1.5, 3 }, away = { 3, 8 }, weight = 1, atWork = 0.55 },
	talk = talk({
		listen = "listenBehind",
		gestures = { W("talkOpen", 1.2), W("talkExplain", 1.2), W("talkFinger", 0.8), W("talkBeat", 0.6) },
		energy = 0.9,
	}),
})
-- The innkeeper: jovial, wipes the counter, laughs with his hands.
ROLES.innkeeper = style("innkeeper", {
	stance = { pose = { spitch = -0.04, ppitch = -0.03 }, width = 0.03, toeOut = 0.22 },
	shift = 0.9,
	greet = { range = 9.5, me = "greetWave", other = "greetNodOther" },
	fidgets = { W("rubHands", 1), W("handsOnHips", 1), W("adjustBelt", 0.8), W("wipeBrow", 0.5) },
	work = {
		base = MOVES.wipeBase,
		gaze = { 0, 0.45 },
		phrases = { W("wipeCircles", 3), W("wipeLong", 1.5), W("wipeCheck", 0.7) },
	},
	talk = talk({
		listen = "listenBelt",
		gestures = { W("talkOpen", 1), W("talkBeat", 1), W("talkShrug", 0.8), W("talkWave", 0.6), W("talkSelf", 0.4) },
		energy = 1.1,
		beats = 1.1,
	}),
})
-- A stablemaster, a wagoner: rough, hands on hips, cleans his tack.
ROLES.stablemaster = style("stablemaster", {
	stance = { pose = { spitch = 0.02 }, width = 0.04, toeOut = 0.26, grip = 0.5 },
	shift = 0.9,
	greet = { range = 8.5, me = "greetRaise", other = "greetNodOther" },
	fidgets = { W("handsOnHips", 1.4), W("wipeBrow", 0.8), W("stretchBack", 0.8), W("rubNeck", 0.6) },
	work = { phrases = { W("tackClean", 2.5), W("goodsLook", 0.6) } },
	talk = talk({
		listen = "listenHips",
		gestures = { W("talkBeat", 1), W("talkWave", 0.8), W("talkShrug", 0.6), W("talkOpen", 0.6) },
	}),
})
-- A labourer (woodcutter, miner, gravedigger, mason, farmer): tired, a sore back, hands on the hips.
ROLES.laborer = style("laborer", {
	stance = { pose = { spitch = 0.05, hpitch = 0.03 }, width = 0.05, toeOut = 0.25, grip = 0.55 },
	breathDepth = 1.15,
	shift = 1,
	greet = { range = 8, me = "greetRaise", other = "greetNodOther" },
	fidgets = {
		W("stretchBack", 1.4),
		W("wipeBrow", 1.2),
		W("handsOnHips", 1),
		W("rubNeck", 0.8),
		W("rollShoulders", 0.7),
	},
	fidgetEvery = { 5, 11 },
	talk = talk({
		listen = "listenHips",
		gestures = { W("talkBeat", 1), W("talkShrug", 0.8), W("talkWave", 0.6), W("talkOpen", 0.5) },
	}),
})
-- A hunter, a scout, a trapper: alert, light on the feet, scanning the distance with a hand over the eyes.
ROLES.hunter = style("hunter", {
	stance = { pose = { spitch = 0.03, hpitch = -0.02 }, width = 0.04, toeOut = 0.2 },
	shift = 0.7,
	tempo = 1.15,
	glance = { every = { 2, 5 }, ahead = 0.3, yaw = 0.9, pitch = -0.02, down = 0.1, turn = 0.3 },
	look = { range = 15, hold = { 1.5, 3.5 }, away = { 2, 5 }, weight = 1, atWork = 0.8 },
	greet = { range = 9, me = "greetRaise", other = "greetNodOther" },
	fidgets = { W("crossArms", 0.8), W("handsOnHips", 0.6), W("rollShoulders", 0.6), W("scratchChin", 0.4) },
	work = { phrases = { W("lookout", 1.5), W("watchScan", 1) } },
	talk = talk({
		listen = "listenRest",
		gestures = { W("talkBeat", 1), W("talkWave", 0.6), W("talkOpen", 0.6), W("talkFinger", 0.5) },
	}),
})
-- The fisherman: the rod held, a cast now and then, the long wait, the reel.
ROLES.fisher = style("fisher", {
	stance = { pose = { spitch = 0.06 }, width = 0.04, toeOut = 0.24 },
	shift = 0.6,
	tempo = 0.9,
	greet = { range = 8, me = "greetNod", other = "greetNodOther" },
	work = {
		base = MOVES.fishBase,
		gaze = { 0, 0.15 },
		phrases = { W("fishWait", 3), W("fishCast", 1), W("fishReel", 1.2) },
	},
	look = { range = 11, hold = { 1.2, 2.5 }, away = { 5, 10 }, weight = 1, atWork = 0.55 },
	talk = talk({
		listen = "listenRest",
		gestures = { W("talkBeat", 1), W("talkShrug", 0.6), W("talkWave", 0.5) },
		energy = 0.85,
	}),
})
-- A witch, a shaman, a herbalist: hunched over the pot, stirring; slow, knowing gestures.
ROLES.witch = style("witch", {
	stance = { pose = { spitch = 0.12, hpitch = -0.05, py = -0.02 }, toeOut = 0.2 },
	breath = 4.8,
	tempo = 0.85,
	greet = { range = 8, me = "greetNod", other = "greetNodOther" },
	fidgets = { W("thinkChin", 1), W("rubHands", 0.8), W("lookSky", 0.5) },
	work = { gaze = { 0, 0.5 }, phrases = { W("stir", 2.5), W("herbs", 1.2) } },
	talk = talk({
		listen = "listenClasp",
		gestures = { W("talkFinger", 1), W("talkExplain", 1), W("talkOpen", 0.6) },
		energy = 0.85,
	}),
})
-- A noble or a banker: upright, a hand on the belt, measured gestures; writes in the ledger.
ROLES.noble = style("noble", {
	stance = { pose = { spitch = -0.05, hpitch = -0.04 }, toeOut = 0.2 },
	shift = 0.55,
	sway = 0.7,
	greet = { range = 9, me = "greetBow", other = "greetNodOther" },
	fidgets = { W("handsBehind", 1.2), W("smoothHair", 0.6), W("adjustBelt", 0.6), W("checkHand", 0.6) },
	work = { phrases = { W("ledger", 2), W("coins", 0.7) } },
	talk = talk({
		listen = "listenBehind",
		gestures = { W("talkOpen", 1), W("talkFinger", 0.8), W("talkBeat", 0.8), W("talkSelf", 0.5) },
		energy = 0.9,
	}),
})
-- The barber: chatty, snips the air, combs.
ROLES.barber = style("barber", {
	stance = { pose = { spitch = 0.0 }, toeOut = 0.2 },
	tempo = 1.1,
	greet = { range = 9, me = "greetWave", other = "greetNodOther" },
	fidgets = { W("smoothHair", 1), W("rubHands", 0.8), W("checkHand", 0.6) },
	work = { phrases = { W("snip", 2), W("checkHand", 0.6) } },
	talk = talk({ listen = "listenClasp", energy = 1.15, beats = 1.2 }),
})
-- A ghost: floats a little, slow, the head bowed, arms hanging; it looks long and turns away.
ROLES.ghost = style("ghost", {
	stance = {
		pose = { spitch = 0.08, hpitch = 0.15, aRo = 0.08, aLo = 0.08, eR = 0.2, eL = 0.2 },
		toeOut = 0.15,
		grip = 0.2,
	},
	breath = 6,
	breathDepth = 0.6,
	shift = 0.25,
	sway = 1.6,
	tempo = 0.6,
	float = 0.03,
	glance = { every = { 5, 10 }, ahead = 0.5, yaw = 0.6, pitch = 0.2, down = 0.4, turn = 1.1 },
	look = { range = 12, hold = { 3, 6 }, away = { 4, 9 }, weight = 1, atWork = 1 },
	greet = { range = 7, me = "greetNodOther", other = "greetNodOther" },
	fidgets = { W("lookBehind", 1), W("lookSky", 0.6) },
	fidgetEvery = { 9, 18 },
	talk = talk({
		listen = "listenRest",
		gestures = { W("talkOpen", 1), W("talkSelf", 0.6) },
		energy = 0.6,
		beats = 0.4,
	}),
})
-- A skald: big gestures, the storyteller.
ROLES.bard = style("bard", {
	stance = { pose = { spitch = -0.04 }, toeOut = 0.22 },
	tempo = 1.05,
	greet = { range = 9.5, me = "greetWave", other = "greetNodOther" },
	fidgets = { W("lookSky", 1), W("handsOnHips", 0.8), W("rubHands", 0.6) },
	talk = talk({
		listen = "listenRest",
		gestures = {
			W("talkOpen", 1.4),
			W("talkExplain", 1.2),
			W("talkBeat", 1),
			W("talkFinger", 0.6),
			W("talkSelf", 0.6),
		},
		energy = 1.2,
		beats = 1.25,
	}),
})

---------------------------------------------------------------- NPCs

-- Every NPC of Data/Npcs: its role and what it does differently (a key of the style replaced: `work = false` takes the
-- work away). The quest board has no figure.
local NPCS: { [string]: { [string]: any } } = {
	healer = { role = "priest" },
	blacksmith = { role = "smith" },
	vendor_warrior = { role = "vendor", greet = { range = 9, me = "greetGuard", other = "greetGuard" } },
	vendor_cleric = { role = "priest", work = false },
	vendor_hunter = { role = "hunter", work = false },
	vendor_mage = { role = "mage", work = false },
	fence = { role = "vendor", greet = { range = 8, me = "greetNodOther", other = "greetNodOther" } },
	alchemist = { role = "witch", work = { gaze = { -0.1, 0.1 }, phrases = { W("vial", 1.5), W("herbs", 1) } } },
	merchant = { role = "merchant" },
	backpacker = { role = "merchant" },
	banker = { role = "noble" },
	teacher = { role = "scholar" },
	guildmaster = { role = "noble", work = false },
	auctioneer = { role = "noble" },
	captain = { role = "captain" },
	scout_meadows = { role = "hunter" },
	scout_duskwood = { role = "hunter" },
	scout_ashen = { role = "hunter" },
	scout_frostpeak = { role = "hunter" },
	guard1 = { role = "guard" },
	guard2 = { role = "guard" },
	granary_keeper = { role = "noble", work = { phrases = { W("ledger", 1), W("goodsLook", 0.5) } } },
	brother_anzelm = { role = "priest" },
	fishwife = { role = "merchant" },
	innkeeper = { role = "innkeeper" },
	miller_widow = { role = "elder" },
	stablemaster = { role = "stablemaster" },
	sergeant = { role = "captain", pace = false },
	barber = { role = "barber" },
	arenamaster = { role = "captain", pace = false },
	huntmaster = { role = "hunter" },
	portalmaster = { role = "mage" },
	farmer_bartosz = { role = "laborer" },
	fisher_wit = { role = "fisher" },
	woodcutter_gerwazy = { role = "laborer" },
	merchant_lucjan = {
		role = "merchant",
		work = { phrases = { W("coins", 1.5), W("coinsPocket", 1), W("goodsLook", 0.5) } },
	},
	miner_dobromir = { role = "laborer" },
	hunter_borys = { role = "hunter" },
	forester_radomir = { role = "hunter" },
	ghost_oswin = { role = "ghost" },
	defector_jorund = {
		role = "captain",
		pace = false,
		greet = { range = 7, me = "greetNodOther", other = "greetNodOther" },
	},
	witch_ragna = { role = "witch" },
	huntress_wanda = { role = "hunter" },
	beekeeper_maciej = { role = "laborer" },
	gravedigger_bogumil = { role = "laborer" },
	herbalist_dobrawa = { role = "witch", work = { gaze = { 0, 0.5 }, phrases = { W("herbs", 2), W("stir", 0.6) } } },
	warden_zbyszko = { role = "guard", pace = false },
	ferryman_oldrzych = { role = "elder" },
	exorcist_kalina = { role = "priest" },
	mason_wojslaw = { role = "laborer" },
	runesmith_brokk = { role = "smith" },
	shaman_ghasha = { role = "witch" },
	hermit_kaspar = { role = "elder", work = { phrases = { W("prayHold", 1) } } },
	waterkeeper_orren = { role = "elder" },
	prospector_dragan = { role = "laborer" },
	wyvernhunter_wieslawa = { role = "hunter" },
	tombwarden_ezra = { role = "elder" },
	wagoner_bogna = { role = "stablemaster" },
	trapper_sigrun = { role = "hunter" },
	ghost_halgrim = { role = "ghost" },
	cairn_ingrid = { role = "elder" },
	hornblower_eskil = { role = "hunter" },
	skald_ragnvald = { role = "bard" },
	icefisher_torvi = { role = "fisher" },
	bonecarver_gunnar = { role = "laborer" },
	squire_asmund = { role = "guard", pace = false, greet = { range = 9, me = "greetSalute", other = "greetGuard" } },
	scholar_vigdis = { role = "scholar" },
	-- the wandering merchant: his wagon stands behind him; a few paces to stretch the legs of the road
	wanderer = { role = "merchant", pace = { span = 2.2, every = { 20, 40 }, axis = "side" } },
}
NpcStyles.NPCS = NPCS

local resolved: { [string]: Style } = {}

-- The style of NPC `npcId`: its role with its own overrides (NPCS), a role by its services for one not listed
-- (Data/Npcs `services`). `role` (the model's attribute "NpcRole", set in Studio) puts the NPC in another role, its own
-- overrides still on it.
function NpcStyles.of(npcId: string, services: { string }?, role: string?): Style
	local override = role ~= nil and ROLES[role] ~= nil
	local done = resolved[npcId]
	if done and not override then
		return done
	end
	local entry = NPCS[npcId]
	local roleId = if override then role else entry and entry.role
	if not roleId then
		local list = services or {}
		roleId = if table.find(list, "blacksmith")
			then "smith"
			elseif table.find(list, "shop") then "vendor"
			else "townsfolk"
	end
	local base = ROLES[roleId :: string] or BASE
	local out: any = table.clone(base)
	if entry then
		for k, v in entry do
			if k ~= "role" and not (override and k == "work") then
				out[k] = if v == false then nil else v
			end
		end
	end
	out.id = roleId
	if not override then
		resolved[npcId] = out
	end
	return out
end

-- The work the model's attribute "Work" asks for: "none" none, a role's id (or "hammer", the smith's) that role's
-- work; nil leaves the style's.
NpcStyles.WORK_ALIASES =
	{ hammer = "smith", goods = "merchant", wipe = "innkeeper", channel = "mage", read = "scholar" }
function NpcStyles.withWork(style: Style, work: string?): Style
	if work == nil then
		return style
	end
	local out: any = table.clone(style)
	if work == "none" then
		out.work = nil
		return out
	end
	local role = ROLES[NpcStyles.WORK_ALIASES[work] or work]
	if role and role.work then
		out.work = role.work
	end
	return out
end

-- The roles' and the NPCs' every move name (tests: each one exists).
function NpcStyles.moveNames(s: Style): { string }
	local out: { string } = {}
	local function addName(name: string)
		if not table.find(out, name) then
			table.insert(out, name)
		end
	end
	for _, e in s.fidgets do
		addName(e.name)
	end
	if s.greet then
		addName(s.greet.me)
		addName(s.greet.other)
	end
	addName(s.talk.listen)
	for _, e in s.talk.gestures do
		addName(e.name)
	end
	addName("talkPoint")
	if s.work then
		for _, e in s.work.phrases do
			addName(e.name)
		end
	end
	return out
end

return NpcStyles
