--!strict
-- Test helper (the mount styles, Data/QuadStyles `horse` and `lion`): two placeholder skeletons laid out like a Tripo
-- Auto Rig Quadruped (a root at the pelvis carrying the hind legs and the tail, a spine to the withers carrying the fore
-- legs and the neck), with the proportions of a riding horse and a broad lion of mount size, in studs (feet at y = 0,
-- the front toward -Z, rest axes along the model's). The real bone maps come from the rig dumps of the models (Data/
-- QuadRigs); these only let the specs run the styles at the mount speeds and measure what the rider sits on. Each
-- skeleton has a leaf bone `saddle` on the mid spine (not driven): the point the rider sits over.

local QuadPose = require("../src/shared/Logic/QuadPose")
local QuadRigs = require("../src/shared/Data/QuadRigs")

local QuadMountRigs = {}

type Vec = { number }

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

-- name -> { position, parent }
type Layout = { [string]: { pos: Vec, parent: string? } }

local function bones(layout: Layout): { [string]: QuadPose.Bone }
	local out: { [string]: QuadPose.Bone } = {}
	for name, b in layout do
		out[name] = { rest = table.clone(IDENTITY), pos = table.clone(b.pos), parent = b.parent }
	end
	return out
end

-- A leg of `names` at side `x` (- left): joint heights and depths from the top down.
local function leg(layout: Layout, parent: string, names: { string }, x: number, at: { Vec })
	local up = parent
	for i, name in names do
		layout[name] = { pos = { x, at[i][1], at[i][2] }, parent = up }
		up = name
	end
end

-- Riding horse: the hind hip 3.4 studs over the ground (L), withers at 4.1, the head carried up at 5.7.
local function horseLayout(): Layout
	local layout: Layout = {
		Root = { pos = { 0, 3.9, 0.9 } },
		Spine_0 = { pos = { 0, 4.0, 0.3 }, parent = "Root" },
		Spine_1 = { pos = { 0, 4.05, -0.4 }, parent = "Spine_0" },
		Spine_2 = { pos = { 0, 4.1, -1.1 }, parent = "Spine_1" },
		saddle = { pos = { 0, 4.6, -0.3 }, parent = "Spine_1" },
		Head_0 = { pos = { 0, 4.4, -1.5 }, parent = "Spine_2" },
		Head_1 = { pos = { 0, 5.1, -2.0 }, parent = "Head_0" },
		Head_2 = { pos = { 0, 5.7, -2.4 }, parent = "Head_1" },
		Head_3 = { pos = { 0, 5.2, -3.0 }, parent = "Head_2" },
		Ear_L = { pos = { -0.2, 6.1, -2.3 }, parent = "Head_2" },
		Ear_R = { pos = { 0.2, 6.1, -2.3 }, parent = "Head_2" },
		Tail_0 = { pos = { 0, 4.1, 1.5 }, parent = "Root" },
		Tail_1 = { pos = { 0, 3.6, 1.8 }, parent = "Tail_0" },
		Tail_2 = { pos = { 0, 3.0, 1.95 }, parent = "Tail_1" },
		Tail_3 = { pos = { 0, 2.4, 2.0 }, parent = "Tail_2" },
	}
	-- the fore leg from the top of the shoulder blade at the withers (laid back: the shoulder joint ahead and below
	-- it), the elbow behind, the pastern sloped; the hind leg's stifle forward, its hock back
	local fore = { { 4.0, -0.95 }, { 3.2, -1.35 }, { 2.45, -0.85 }, { 1.3, -0.95 }, { 0.35, -0.95 }, { 0.04, -1.2 } }
	local hind = { { 3.4, 1.0 }, { 2.4, 0.6 }, { 1.45, 1.3 }, { 0.35, 1.2 }, { 0.04, 1.05 } }
	leg(layout, "Spine_2", { "FL_0", "FL_1", "FL_2", "FL_3", "FL_4", "FL_5" }, -0.45, fore)
	leg(layout, "Spine_2", { "FR_0", "FR_1", "FR_2", "FR_3", "FR_4", "FR_5" }, 0.45, fore)
	leg(layout, "Root", { "HL_0", "HL_1", "HL_2", "HL_3", "HL_4" }, -0.45, hind)
	leg(layout, "Root", { "HR_0", "HR_1", "HR_2", "HR_3", "HR_4" }, 0.45, hind)
	return layout
end

-- Broad lion of mount size: the hind hip 3.0 studs over the ground (L), a long back, a head with a jaw, six tail bones.
local function lionLayout(): Layout
	local layout: Layout = {
		Root = { pos = { 0, 3.3, 1.2 } },
		Spine_0 = { pos = { 0, 3.35, 0.5 }, parent = "Root" },
		Spine_1 = { pos = { 0, 3.4, -0.3 }, parent = "Spine_0" },
		Spine_2 = { pos = { 0, 3.45, -1.1 }, parent = "Spine_1" },
		saddle = { pos = { 0, 3.95, -0.2 }, parent = "Spine_1" },
		Head_0 = { pos = { 0, 3.6, -1.5 }, parent = "Spine_2" },
		Head_1 = { pos = { 0, 4.0, -1.9 }, parent = "Head_0" },
		Head_2 = { pos = { 0, 4.3, -2.3 }, parent = "Head_1" },
		Jaw = { pos = { 0, 4.1, -2.5 }, parent = "Head_2" },
		Ear_L = { pos = { -0.3, 4.75, -2.2 }, parent = "Head_2" },
		Ear_R = { pos = { 0.3, 4.75, -2.2 }, parent = "Head_2" },
	}
	local tail = { { 3.4, 1.8 }, { 3.1, 2.3 }, { 2.7, 2.8 }, { 2.4, 3.3 }, { 2.3, 3.8 }, { 2.4, 4.3 } }
	local up = "Root"
	for i, at in tail do
		local name = `Tail_{i - 1}`
		layout[name] = { pos = { 0, at[1], at[2] }, parent = up }
		up = name
	end
	local fore = { { 3.5, -0.9 }, { 2.7, -1.25 }, { 1.75, -0.95 }, { 0.45, -1.05 }, { 0.06, -1.3 } }
	local hind = { { 3.0, 1.3 }, { 1.9, 0.9 }, { 0.9, 1.5 }, { 0.06, 1.35 } }
	leg(layout, "Spine_2", { "FL_0", "FL_1", "FL_2", "FL_3", "FL_4" }, -0.55, fore)
	leg(layout, "Spine_2", { "FR_0", "FR_1", "FR_2", "FR_3", "FR_4" }, 0.55, fore)
	leg(layout, "Root", { "HL_0", "HL_1", "HL_2", "HL_3" }, -0.5, hind)
	leg(layout, "Root", { "HR_0", "HR_1", "HR_2", "HR_3" }, 0.5, hind)
	return layout
end

local function horseLeg(side: string): { QuadRigs.Joint }
	if string.sub(side, 1, 1) == "F" then
		-- shoulder blade, shoulder, elbow, knee (carpus), fetlock, hoof
		return {
			{ bone = side .. "_0", swing = 0.3 },
			{ bone = side .. "_1", swing = 0.7, fold = 0.2, spread = 1 },
			{ bone = side .. "_2", fold = 0.4 },
			{ bone = side .. "_3", fold = -1.5 },
			{ bone = side .. "_4", fold = 0.9 },
			{ bone = side .. "_5", paw = 1 },
		}
	end
	-- hip, stifle, hock, fetlock, hoof
	return {
		{ bone = side .. "_0", swing = 1, fold = 0.3, spread = 1 },
		{ bone = side .. "_1", fold = -1 },
		{ bone = side .. "_2", fold = 0.9 },
		{ bone = side .. "_3", fold = -0.3 },
		{ bone = side .. "_4", paw = 1 },
	}
end

local function lionLeg(side: string): { QuadRigs.Joint }
	if string.sub(side, 1, 1) == "F" then
		-- shoulder blade, shoulder, elbow, wrist, paw
		return {
			{ bone = side .. "_0", swing = 0.25 },
			{ bone = side .. "_1", swing = 0.75, fold = 0.2, spread = 1 },
			{ bone = side .. "_2", fold = -1.4 },
			{ bone = side .. "_3", fold = 1.2 },
			{ bone = side .. "_4", paw = 1 },
		}
	end
	-- hip, knee, hock, paw
	return {
		{ bone = side .. "_0", swing = 1, fold = 0.3, spread = 1 },
		{ bone = side .. "_1", fold = -1 },
		{ bone = side .. "_2", fold = 0.9 },
		{ bone = side .. "_3", paw = 1 },
	}
end

local function rigOf(kind: string): QuadRigs.Rig
	local isLion = kind == "lion"
	local legOf = if isLion then lionLeg else horseLeg
	local tail: { string } = {}
	for i = 1, if isLion then 6 else 4 do
		table.insert(tail, `Tail_{i - 1}`)
	end
	return {
		body = "Root",
		spine = {
			{ bone = "Spine_0", share = 0.3 },
			{ bone = "Spine_1", share = 0.35 },
			{ bone = "Spine_2", share = 0.35 },
		},
		neck = { { bone = "Head_0", share = 0.5 }, { bone = "Head_1", share = 0.5 } },
		head = "Head_2",
		jaw = if isLion then { bone = "Jaw", sign = 1 } else nil,
		ears = { L = "Ear_L", R = "Ear_R" },
		tail = tail,
		legs = { FL = legOf("FL"), FR = legOf("FR"), HL = legOf("HL"), HR = legOf("HR") },
	}
end

-- The placeholder skeleton of `kind` ("horse" or "lion", the style it rides with).
function QuadMountRigs.skeleton(kind: string): QuadPose.Skeleton
	local layout = if kind == "lion" then lionLayout() else horseLayout()
	return assert(QuadPose.skeleton(bones(layout), rigOf(kind)), kind)
end

-- The saddle point at rest (model frame, studs).
function QuadMountRigs.saddle(skel: QuadPose.Skeleton): Vec
	return table.clone(skel.bones.saddle.pos)
end

return QuadMountRigs
