--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F5 §6): an imported model without bones (one rigid mesh)
-- moved whole by Logic/RigidMotion: the look's PrimaryPart on its Gait_Body motor (else its LookWeld; the anchored
-- preview of AnimLab directly), the mesh's Size for the squash (one visible MeshPart, the nearest few looks only,
-- §6.1), its Transparency, and the bone chains of Data/RigidRigs when the model has a skeleton (frostWyrm). In the
-- game it reads what the server publishes on the monster (§10): `Gait`, `Effects` (stun, freeze), `Dash*` (the pounce
-- and leap flights), the root's turns, `SpawnedAt` / `Summoned` (the appear of a look built late), and it moves the
-- root's `Muzzle` with the body while it acts. The rig has the shape of client/Anim/QuadRig's (`motion`, `mod`,
-- `kind`), so AnimationController and AnimLab drive it like the others. A model whose legs fold in its death
-- (Data/RigidRigs `fold`: spider, scorpion) bends its mesh then through client/Anim/MeshFold (only while it dies).
-- A model whose head turns (Data/RigidRigs `gaze`, owner 2026-11-10) hangs it on a bone added in code through
-- client/Anim/MeshHead (the nearest few looks): it looks at its target, glances about, sniffs, nods and flinches.
-- A crawler whose model has leg bones (Data/OctoRigs: the rigged caveSpider, picked by the bones present, so the old
-- rigid model of the same id keeps the paths above) walks them through Logic/OctoMotion over the same recipe: the
-- root's move each frame plants the feet in the world, a ray finds the ground under a foot as it steps (the nearest
-- few only, §1.10), the legs curl in its death instead of the mesh fold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local MeshFold = require(script.Parent.MeshFold)
local MeshHead = require(script.Parent.MeshHead)
local MonsterMove = require(ReplicatedStorage.Shared.Logic.MonsterMove)
local OctoMotion = require(ReplicatedStorage.Shared.Logic.OctoMotion)
local OctoPose = require(ReplicatedStorage.Shared.Logic.OctoPose)
local OctoRigs = require(ReplicatedStorage.Shared.Data.OctoRigs)
local RigidMotion = require(ReplicatedStorage.Shared.Logic.RigidMotion)
local RigidRigs = require(ReplicatedStorage.Shared.Data.RigidRigs)

local RigidRig = {}

-- The looks nearest to the camera that may squash (MeshPart.Size writes, §6.1) and how often they are picked (s).
local SQUASH_NEAREST = 8
local PICK_EVERY = 0.25
-- After a flight lands the body stays on its landing point this long (until the server's teleport arrives), s.
local LANDED_HOLD = 0.5
-- A look built this soon after the server's SpawnedAt plays the appear (§10); a summoned helper climbs out.
local APPEAR_WITHIN = 0.6
local SUMMON_WITHIN = 1.0
-- Size and transparency are written only when they change by more than this.
local SIZE_STEP = 0.003
local ALPHA_STEP = 0.01
-- The crawlers with leg bones nearest the camera that probe the ground and solve their legs fully (§1.10 tier A:
-- desktop, touch); a leg bone's turn is written only when it changed by more than this (rad), or when something else
-- wrote the bone since (an Animator, a script: the bone would show its rest pose on the frames the rig skips).
local LEGS_NEAREST, LEGS_NEAREST_TOUCH = 12, 6
local TURN_STEP = math.rad(0.1)
-- A leg is written whole once any of its joints moved LEG_STEP (rad): written joint by joint, each as it passed
-- TURN_STEP, a standing leg's foot wandered a few hundredths of a stud about its point every frame as the body moved
-- (Studio review 2026-10-31: the planted tips' slide).
local LEG_STEP = math.rad(0.03)
local OVERWRITE_EPS = 1e-4

-- One leg bone the rig turns: about the model's vertical (`y`, the first joint of a leg: its yaw) and its bend axis
-- `n`, both in the bone's own axes (rest^-1 * R * rest is a turn about rest^-1 * axis), by `share` of the angle; the
-- angles written last.
-- (`cf`: the Transform last written, so a bone something else turned in between is written again)
-- (a bone turns `a` about `n` and then `b` about `y`, its own second axis: a leg's yaw or its last bone's roll)
type Joint = { bone: Bone, y: Vector3?, n: Vector3, share: number, a: number, b: number, cf: CFrame? }
-- The legs of a crawler with bones (Logic/OctoMotion) and how the rig writes them.
type Legs = {
	motion: OctoMotion.Instance,
	input: OctoMotion.Input,
	legs: { { Joint } },
	arms: { { Joint } },
	fangs: { { Joint } },
	abdomen: { Joint },
	tail: { Joint },
	frame: CFrame, -- the ground frame (the look's rest under the root) in the world this frame
	lastRoot: CFrame?,
	full: boolean, -- among the nearest: the ground probe and the full solver
	probe: (x: number, z: number) -> number?,
	-- Studio checks (attributes on the look): the bone turns another writer changed between two frames
	look: Model,
	overwritten: number,
	shownAt: number,
}

export type Rig = {
	kind: "rigid",
	motion: RigidMotion.Instance,
	mod: any,
	look: Model,
	primary: BasePart,
	monster: Model?, -- the server's monster (nil in AnimLab)
	root: BasePart?, -- its HumanoidRootPart
	motor: Motor6D?,
	weld: Weld?,
	c0: CFrame,
	base: CFrame, -- AnimLab: the anchored PrimaryPart at rest
	written: CFrame, -- AnimLab: the CFrame written last (the lab moving the look moves `base`)
	lastT: CFrame,
	mesh: MeshPart?, -- the one visible mesh (squash)
	size: Vector3,
	axes: { number }, -- the model axis (1 x, 2 y, 3 z) of each of the mesh's own axes
	scaled: { number }, -- the scale per model axis written last
	near: boolean,
	distance: number,
	parts: { BasePart },
	opaque: { number }, -- each part's own Transparency
	alpha: number,
	bones: { [string]: Bone },
	lastYaw: number?,
	effects: any,
	stunUntil: number,
	freezeUntil: number,
	muzzle: Attachment?,
	muzzleRest: Vector3,
	muzzleMoved: boolean,
	appearName: string?,
	appear: RigidMotion.ActionRun?,
	flight: RigidMotion.Flight,
	lab: boolean,
	legs: MeshFold.Handle?, -- the legs curl in on its death (client/Anim/MeshFold)
	octo: Legs?, -- the legs walk on their bones (Data/OctoRigs)
	head: MeshHead.Handle?, -- the head turns on a bone added in code (client/Anim/MeshHead)
	input: RigidMotion.Input?, -- the input of the frame being posed
	dying: boolean, -- a held action plays (a death), or the legs' fold still has the mesh: the head stays off
}

-- Every live rig by its motion (weak: a look destroyed takes its rig along).
local live: { [RigidMotion.Instance]: Rig } = setmetatable({} :: any, { __mode = "kv" })
local pickAt = -math.huge
-- The legs' ground probe skips the monsters and the players (the list renewed with the nearest pick).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The model axis a direction lies along (1 x, 2 y, 3 z).
local function axisOf(v: Vector3): number
	local x, y, z = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if x >= y and x >= z then
		return 1
	end
	return if y >= z then 2 else 3
end

-- The box of the visible parts in the PrimaryPart's frame (the ground point under the server's root, front -Z).
local function measure(look: Model, primary: BasePart): (RigidMotion.Body, { BasePart })
	local space = primary.CFrame
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	local visible: { BasePart } = {}
	for _, item in look:GetDescendants() do
		if
			item:IsA("BasePart")
			and item ~= primary
			and item.Name ~= "HumanoidRootPart"
			and item.Transparency < 0.99
		then
			table.insert(visible, item)
			local rel = space:ToObjectSpace(item.CFrame)
			local half = item.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = rel * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	if #visible == 0 then
		lo, hi = Vector3.new(-1, 0, -1), Vector3.new(1, 2, 1)
	end
	return {
		h = hi.Y,
		lift = lo.Y,
		B = math.max(0.2, hi.Z - lo.Z),
		W = math.max(0.2, hi.X - lo.X),
		x0 = (lo.X + hi.X) / 2,
		z0 = (lo.Z + hi.Z) / 2,
		squash = false,
	},
		visible
end

-- The chains of Data/RigidRigs whose bones all exist, with their rest rotations in the PrimaryPart's frame.
local function chainsOf(model: string, look: Model, primary: BasePart): (RigidMotion.Chains?, { [string]: Bone })
	local map = RigidRigs.get(model)
	local byName: { [string]: Bone } = {}
	if not map then
		return nil, byName
	end
	for _, item in look:GetDescendants() do
		if item:IsA("Bone") and not byName[item.Name] and not MeshHead.owns(item) then
			byName[item.Name] = item
			item.Transform = CFrame.identity
		end
	end
	local space = primary.CFrame
	local function chain(names: { string }?): RigidMotion.Chain?
		if not names then
			return nil
		end
		local rest = {}
		for _, name in names do
			local bone = byName[name]
			if not bone then
				return nil
			end
			table.insert(rest, toMat(space:ToObjectSpace(bone.WorldCFrame)))
		end
		return { names = names, rest = rest }
	end
	local chains: RigidMotion.Chains = {
		tail = chain(map.tail),
		coil = chain(map.coil),
		neck = chain(map.neck),
		head = chain(map.head),
	}
	if not chains.tail and not chains.neck then
		return nil, byName
	end
	return chains, byName
end

-- A rest value kept on the instance the first time (a rig built again over a look it already moved starts clean).
local function rest(item: Instance, name: string, now: any): any
	local kept = item:GetAttribute(name)
	if kept == nil then
		item:SetAttribute(name, now)
		return now
	end
	return kept
end

-- The joints of the bones `names` (rest frames by name) turning about `axis` (model frame), each by its share; a leg's
-- first also yaws about the up, its last rolls its bone about `roll` (the leg's rest direction: Logic/OctoPose.pinned).
local function jointsOf(
	names: { string },
	bones: { [string]: Bone },
	frames: { [string]: CFrame },
	axis: { Vector3 },
	share: { number }?,
	roll: Vector3?
): { Joint }
	local out: { Joint } = {}
	for j, name in names do
		local rest = frames[name]
		out[j] = {
			bone = bones[name] :: Bone,
			y = if roll and j == 1
				then rest:VectorToObjectSpace(Vector3.yAxis)
				elseif roll and j == #names then rest:VectorToObjectSpace(roll)
				else nil,
			n = rest:VectorToObjectSpace(axis[math.min(j, #axis)]),
			share = if share then share[j] else 1,
			a = 0,
			b = 0,
			cf = CFrame.identity, -- (the rig sets every bone to rest first)
		}
	end
	return out
end

-- The legs of `look` when Data/OctoRigs has a map of `model` whose bones it all has (the rigged model; the old rigid
-- one has none): the skeleton from the bones' rest frames in the PrimaryPart's frame, the ground the mesh's lowest
-- point. Also every bone by name (the rig clears them, Vfx/MotionFx finds its anchors on them).
local function legsOf(
	model: string,
	look: Model,
	primary: BasePart,
	body: RigidMotion.Body,
	seed: number,
	bones: { [string]: Bone }
): Legs?
	for _, item in look:GetDescendants() do
		if item:IsA("Bone") and not bones[item.Name] and not MeshHead.owns(item) then
			bones[item.Name] = item
		end
	end
	local found: { [string]: Bone? } = bones
	local map = OctoRigs.find(model, function(name: string): boolean
		return found[name] ~= nil
	end)
	if not map then
		return nil
	end
	-- the rest frames from the bones' own offsets up to their part (never the animated frames: a look the rig moved
	-- before keeps its Transforms until the next render)
	local function restOf(item: Instance): CFrame?
		if item:IsA("Bone") then
			local parent = item.Parent
			local base = if parent then restOf(parent) else nil
			return if base then base * item.CFrame else nil
		elseif item:IsA("BasePart") then
			return item.CFrame
		end
		return nil
	end
	local space = primary.CFrame
	local rest: { [string]: OctoPose.Bone } = {}
	local frames: { [string]: CFrame } = {}
	for name, bone in bones do
		bone.Transform = CFrame.identity
		local cf = space:ToObjectSpace(restOf(bone) or bone.WorldCFrame)
		local p = cf.Position
		frames[name] = cf.Rotation
		rest[name] = { rest = toMat(cf), pos = { p.X, p.Y, p.Z }, parent = nil }
	end
	local skel = OctoPose.skeleton(rest, map, body.lift)
	if not skel then
		return nil
	end
	local function limbs(list: { OctoPose.Leg }): { { Joint } }
		local out = {}
		for i, leg in list do
			out[i] = jointsOf(
				leg.bones,
				bones,
				frames,
				{ Vector3.new(leg.ax, 0, leg.az) },
				nil,
				Vector3.new(leg.rx, 0, leg.rz)
			)
		end
		return out
	end
	local function turn(t: OctoPose.Turn?): { Joint }
		if not t then
			return {}
		end
		local axis = {}
		for j, v in t.axis do
			axis[j] = Vector3.new(v[1], v[2], v[3])
		end
		return jointsOf(t.bones, bones, frames, axis, t.share, nil)
	end
	local fangs = {}
	for i, t in skel.fangs do
		fangs[i] = turn(t)
	end
	local legs: Legs = {
		motion = OctoMotion.new(skel, seed),
		input = {},
		legs = limbs(skel.legs),
		arms = limbs(skel.arms),
		fangs = fangs,
		abdomen = turn(skel.abdomen),
		tail = turn(skel.tail),
		frame = space,
		lastRoot = nil,
		full = true,
		probe = function(_x: number, _z: number): number?
			return nil
		end,
		look = look,
		overwritten = 0,
		shownAt = 0,
	}
	-- what the Studio session reads to know the code and the skeleton it runs (docs/ANIM-WZORCE.md §6.6)
	look:SetAttribute("OctoVersion", OctoMotion.VERSION)
	look:SetAttribute("OctoHipH", math.round(skel.hipH * 100) / 100)
	look:SetAttribute("OctoSpan", math.round(skel.span * 100) / 100)
	look:SetAttribute("OctoLegs", #skel.legs)
	look:SetAttribute("OctoOverwritten", 0)
	-- the ground under a point of the ground frame (once per footfall: Logic/OctoMotion asks as a foot sets off)
	local up, down = skel.ground + 2 * skel.hipH, Vector3.new(0, -5 * skel.hipH, 0)
	legs.probe = function(x: number, z: number): number?
		local frame = legs.frame
		local hit = Workspace:Raycast(frame:PointToWorldSpace(Vector3.new(x, up, z)), down, groundParams)
		return if hit then frame:PointToObjectSpace(hit.Position).Y else nil
	end
	return legs
end

-- The rig of `look` (the cloned model of Assets.Monsters `model`) in `styleId` (Data/RigidStyles); `monster` is the
-- server's monster in the game, nil in AnimLab (the anchored preview).
function RigidRig.new(look: Model, styleId: string, seed: number, model: string, monster: Model?): Rig?
	local primary = look.PrimaryPart
	if not primary then
		return nil
	end
	local motor = primary:FindFirstChild("Gait_Body")
	local weld = primary:FindFirstChild("LookWeld")
	local driver: Motor6D? = if motor and motor:IsA("Motor6D") then motor else nil
	local welded: Weld? = if not driver and weld and weld:IsA("Weld") then weld else nil
	local c0 = CFrame.identity
	if driver then
		driver.Transform = CFrame.identity
		c0 = driver.C0
	elseif welded then
		c0 = rest(welded, "RigidC0", welded.C0) :: CFrame
		welded.C0 = c0
	end
	local chains, bones = chainsOf(model, look, primary)
	local body, parts = measure(look, primary)
	local octo = legsOf(model, look, primary, body, seed, bones)
	local mesh: MeshPart? = nil
	local size = Vector3.one
	local axes = { 1, 2, 3 }
	-- (the bones client/Anim/MeshHead added to a look rigged before are not the model's)
	local skinned = next(bones) ~= nil
	for _, item in look:GetDescendants() do
		if not skinned and item:IsA("Bone") and not MeshHead.owns(item) then
			skinned = true
		end
	end
	local legs: MeshFold.Handle? = nil
	local head: MeshHead.Handle? = nil
	if #parts == 1 and parts[1]:IsA("MeshPart") and not skinned then
		local part = parts[1] :: MeshPart
		mesh = part
		size = rest(part, "RigidSize", part.Size) :: Vector3
		part.Size = size
		local rel = primary.CFrame:ToObjectSpace(part.CFrame)
		axes = { axisOf(rel.XVector), axisOf(rel.YVector), axisOf(rel.ZVector) }
		body.squash = true
		legs = MeshFold.attach(model, part, rel, size, seed)
		head = MeshHead.attach(model, look, part, rel, seed, monster == nil)
	end
	local opaque = {}
	for i, part in parts do
		opaque[i] = rest(part, "RigidAlpha", part.Transparency) :: number
		part.Transparency = opaque[i]
	end
	local motion = RigidMotion.new(body, styleId, seed, chains)
	if not motion then
		return nil
	end
	if octo then
		-- the body sinks and topples over the curled legs in its death
		body.folds = OctoMotion.folds(octo.motion, body)
	end
	local root = if monster then monster:FindFirstChild("HumanoidRootPart") else nil
	local serverRoot: BasePart? = if root and root:IsA("BasePart") then root else nil
	local muzzle = if serverRoot then serverRoot:FindFirstChild("Muzzle") else nil
	local attachment: Attachment? = if muzzle and muzzle:IsA("Attachment") then muzzle else nil
	local rig: Rig = {
		kind = "rigid",
		motion = motion,
		mod = nil,
		look = look,
		primary = primary,
		monster = monster,
		root = serverRoot,
		motor = driver,
		weld = welded,
		c0 = c0,
		base = primary.CFrame,
		written = primary.CFrame,
		lastT = CFrame.identity,
		mesh = mesh,
		size = size,
		axes = axes,
		scaled = { 1, 1, 1 },
		near = monster == nil,
		distance = 0,
		parts = parts,
		opaque = opaque,
		alpha = 0,
		bones = bones,
		lastYaw = nil,
		effects = nil,
		stunUntil = 0,
		freezeUntil = 0,
		muzzle = attachment,
		muzzleRest = if attachment then rest(attachment, "RigidRest", attachment.Position) :: Vector3 else Vector3.zero,
		muzzleMoved = false,
		appearName = nil,
		appear = nil,
		flight = { x = 0, y = 0, z = 0, pitch = 0 },
		lab = monster == nil,
		legs = legs,
		octo = octo,
		head = head,
		input = nil,
		dying = false,
	}
	rig.mod = RigidRig.Mod
	if monster and monster:GetAttribute("Dead") ~= true then
		-- the look came after the spawn's first moments (it was still loading): it appears now
		local spawnedAt = monster:GetAttribute("SpawnedAt")
		local age = if type(spawnedAt) == "number" then Workspace:GetServerTimeNow() - spawnedAt else math.huge
		local style = motion.style
		if monster:GetAttribute("Summoned") == true and age < SUMMON_WITHIN then
			rig.appearName = style.summon
		elseif age < APPEAR_WITHIN then
			rig.appearName = style.spawn
		end
	end
	live[motion] = rig
	return rig
end

-- The nearest few rigs (to the camera) may squash; the nearest crawlers with leg bones probe the ground.
local function pickNear()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local list: { Rig } = {}
	for _, rig in live do
		rig.near = false
		local legs = rig.octo
		if legs then
			legs.full = rig.root == nil
		end
		local root = rig.root
		if (rig.mesh or legs) and root and rig.look.Parent then
			rig.distance = (root.Position - eye).Magnitude
			table.insert(list, rig)
		end
	end
	table.sort(list, function(a: Rig, b: Rig)
		return a.distance < b.distance
	end)
	local squash, walk = 0, 0
	local most = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then LEGS_NEAREST_TOUCH
		else LEGS_NEAREST
	for _, rig in list do
		if rig.mesh and squash < SQUASH_NEAREST then
			squash += 1
			rig.near = true
		end
		local legs = rig.octo
		if legs and walk < most then
			walk += 1
			legs.full = true
		end
	end
	if walk > 0 then
		local skip: { Instance } = {}
		local monsters = Workspace:FindFirstChild("Monsters")
		if monsters then
			table.insert(skip, monsters)
		end
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.Character then
				table.insert(skip, player.Character)
			end
		end
		groundParams.FilterDescendantsInstances = skip
	end
end

-- The flight on the server's Dash* arc (root space) while it flies and a moment after, else nil.
local function flightOf(rig: Rig, monster: Model, root: BasePart, serverNow: number): RigidMotion.Flight?
	local at, seconds = monster:GetAttribute("DashAt"), monster:GetAttribute("DashTime")
	local from, to = monster:GetAttribute("DashFrom"), monster:GetAttribute("DashTo")
	if type(at) ~= "number" or type(seconds) ~= "number" or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return nil
	end
	if serverNow < at or serverNow > at + seconds + LANDED_HOLD then
		return nil
	end
	local k = MonsterMove.flightProgress(serverNow, at, seconds) or 1
	local arc = tonumber(monster:GetAttribute("DashArc")) or 0
	local a, b = from :: Vector3, to :: Vector3
	local x, y, z = Gait.leapArc(k, { a.X, a.Y, a.Z }, { b.X, b.Y, b.Z }, arc)
	local offset = root.CFrame:VectorToObjectSpace(Vector3.new(x, y, z) - root.Position)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	local rise = (b.Y - a.Y) + 4 * arc * (1 - 2 * k)
	local flight = rig.flight
	flight.x, flight.y, flight.z = offset.X, offset.Y, offset.Z
	-- levelled toward the take-off and the landing, so the nose never digs into the ground
	flight.pitch = if k < 1 and flat > 0.05 then math.atan2(rise, flat) * math.sin(math.pi * k) else 0
	return flight
end

-- What the game's input lacks, read from the monster (AnimLab: only the squash and the legs).
local function augment(rig: Rig, input: RigidMotion.Input)
	rig.input = input
	local held = input.action
	local heldAction = if held then rig.motion.style.actions[held.name] else nil
	local dying = held ~= nil and heldAction ~= nil and heldAction.hold == true and input.now >= held.start
	rig.dying = dying
	local legs = rig.legs
	if legs then
		-- a death (a held action) folds the legs where the mesh can be bent; the body learns the folded boxes (the
		-- head's mesh off first: the fold bends the look's own)
		if dying and rig.head then
			MeshHead.stop(rig.head)
		end
		input.fold = MeshFold.share(legs, dying)
		rig.motion.body.folds = MeshFold.folds(legs)
		-- (and it stays off while the fold's mesh is on: AnimLab's death played again, the legs unfolding)
		rig.dying = dying or legs.state == "loading" or legs.state == "live"
	elseif rig.octo then
		-- the leg bones draw the whole fold
		input.fold = 1
	end
	local monster = rig.monster
	local root = rig.root
	if not monster or not root then
		input.squash = rig.mesh ~= nil
		return
	end
	local clock = os.clock()
	if clock - pickAt >= PICK_EVERY then
		pickAt = clock
		pickNear()
	end
	input.squash = rig.near and rig.mesh ~= nil
	local gait = monster:GetAttribute("Gait")
	input.gait = if type(gait) == "string" then gait else nil
	-- the root's turn this frame (face() turns it in jumps: the body lags and springs after it)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local last = rig.lastYaw
	input.yawDelta = if last then (yaw - last + math.pi) % (2 * math.pi) - math.pi else 0
	rig.lastYaw = yaw
	local serverNow = Workspace:GetServerTimeNow()
	local dead = monster:GetAttribute("Dead") == true
	-- stun and freeze from the effects (decoded only when the attribute changes)
	local raw = monster:GetAttribute("Effects")
	if raw ~= rig.effects then
		rig.effects = raw
		rig.stunUntil, rig.freezeUntil = 0, 0
		for _, shown in EffectStack.decode(raw, serverNow) do
			if shown.kind == "stun" then
				rig.stunUntil = serverNow + shown.left
			elseif shown.kind == "freeze" then
				rig.freezeUntil = serverNow + shown.left
			end
		end
	end
	input.stun = not dead and serverNow < rig.stunUntil
	input.frozen = not dead and serverNow < rig.freezeUntil
	-- the appear of a look built late (nothing newer playing)
	local name = rig.appearName
	if name then
		rig.appearName = nil
		rig.appear = { name = name, start = input.now, hit = 0.5 }
	end
	local appear = rig.appear
	if appear then
		local action = rig.motion.style.actions[appear.name]
		local run = input.action
		if dead or not action or input.now - appear.start > RigidMotion.length(action, appear.hit) then
			rig.appear = nil
		elseif run == nil or run.start < appear.start then
			input.action = appear
		end
	end
	-- a pounce or leap flies on the server's arc; with no flight announced it stays where it is
	local run = input.action
	local action = if run then rig.motion.style.actions[run.name] else nil
	if run and action and action.flight then
		input.flight = flightOf(rig, monster, root, serverNow)
		if not input.flight and run.reach and input.now - run.start >= run.hit - action.strike then
			run.reach = nil
		end
	end
end

-- The legs of a crawler with bones for the frame RigidMotion just posed: the root's move since the last frame (its own
-- frame before the turn; AnimLab: none, the ground runs under the look at its speed), the probe of the nearest.
local function walk(rig: Rig, legs: Legs, input: RigidMotion.Input, posed: RigidMotion.Posed)
	local into = legs.input
	local root = rig.root
	if root then
		local now = root.CFrame
		local last = legs.lastRoot
		if last and not input.snap then
			local d = last:PointToObjectSpace(now.Position)
			into.dx, into.dz = d.X, d.Z
		else
			into.dx, into.dz = 0, 0
		end
		into.dyaw = input.yawDelta or 0
		legs.lastRoot = now
		-- (the look hangs at c0 under the root: the ground frame is the look's rest)
		legs.frame = now * rig.c0
	else
		into.dx, into.dz, into.dyaw = nil, nil, nil
		legs.frame = rig.base
	end
	into.coarse = not legs.full
	into.ground = if legs.full and root then legs.probe else nil
	OctoMotion.step(legs.motion, rig.motion, input, posed, into)
end

-- Whether something else wrote the joint's bone since the rig did (it shows another pose: written again).
local function overwritten(joint: Joint): boolean
	local cf = joint.cf
	return cf ~= nil and not joint.bone.Transform:FuzzyEq(cf, OVERWRITE_EPS)
end

-- The turns of one leg (the yaw on its first joint, the roll on its last), the whole leg once one moved LEG_STEP, and
-- the bones something else wrote; the number of bones found written by another.
local function writeLeg(joints: { Joint }, f: OctoMotion.Foot): number
	local c = f.c
	local other = 0
	local last = #joints
	local whole = false
	for j, joint in joints do
		local b = if j == 1 then f.psi elseif j == last then c[last + 1] or 0 else 0
		if math.abs(c[j] - joint.a) > LEG_STEP or math.abs(b - joint.b) > LEG_STEP then
			whole = true
			break
		end
	end
	for j, joint in joints do
		local a = c[j]
		local b = if j == 1 then f.psi elseif j == last then c[last + 1] or 0 else 0
		local moved = whole and (a ~= joint.a or b ~= joint.b)
		if not moved and overwritten(joint) then
			other += 1
			moved = true
		end
		if moved then
			joint.a, joint.b = a, b
			local y = joint.y
			local cf = if y
				then CFrame.fromAxisAngle(y, b) * CFrame.fromAxisAngle(joint.n, a)
				else CFrame.fromAxisAngle(joint.n, a)
			joint.bone.Transform = cf
			joint.cf = cf
		end
	end
	return other
end

-- The turns of a chain about its axes by `angle` (each bone its share) where they changed (or were written by
-- another).
local function writeTurn(joints: { Joint }, angle: number): number
	local other = 0
	for _, joint in joints do
		local a = angle * joint.share
		local moved = math.abs(a - joint.a) > TURN_STEP
		if not moved and overwritten(joint) then
			other += 1
			moved = true
		end
		if moved then
			joint.a = a
			local cf = CFrame.fromAxisAngle(joint.n, a)
			joint.bone.Transform = cf
			joint.cf = cf
		end
	end
	return other
end

local function writeLegs(legs: Legs)
	local motion = legs.motion
	local other = 0
	for i, joints in legs.legs do
		other += writeLeg(joints, motion.feet[i])
	end
	for i, joints in legs.arms do
		other += writeLeg(joints, motion.arms[i])
	end
	for _, joints in legs.fangs do
		other += writeTurn(joints, motion.fang)
	end
	other += writeTurn(legs.abdomen, motion.pump)
	other += writeTurn(legs.tail, motion.tail)
	if other > 0 then
		-- (a Studio check: shown at most once a second)
		legs.overwritten += other
		local clock = os.clock()
		if clock - legs.shownAt >= 1 then
			legs.shownAt = clock
			legs.look:SetAttribute("OctoOverwritten", legs.overwritten)
		end
	end
end

-- The functions the game and AnimLab call on `rig.mod` (Logic/RigidMotion's, the step reading the monster first).
RigidRig.Mod = {
	length = RigidMotion.length,
	pick = RigidMotion.pick,
	death = RigidMotion.death,
	side = RigidMotion.side,
	mirror = RigidMotion.mirror,
	step = function(motion: RigidMotion.Instance, input: RigidMotion.Input): RigidMotion.Posed
		local rig = live[motion]
		if rig then
			augment(rig, input)
		end
		local posed = RigidMotion.step(motion, input)
		local legs = rig and rig.octo
		if rig and legs then
			walk(rig, legs, input, posed)
		end
		return posed
	end,
}

-- Writes one frame: the body, the mesh's size and transparency, the bones, the muzzle.
function RigidRig.apply(rig: Rig, posed: RigidMotion.Posed)
	local m = posed.m
	local t = CFrame.new(m[10], m[11], m[12], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
	local motor, weld = rig.motor, rig.weld
	if motor then
		motor.Transform = t
	elseif weld then
		weld.C0 = rig.c0 * t
	else
		-- AnimLab: the anchored preview; the lab moving the look (a PivotTo) moves its rest with it
		local primary = rig.primary
		local now = primary.CFrame
		local was = rig.written
		if (now.Position - was.Position).Magnitude > 0.01 or now.LookVector:Dot(was.LookVector) < 0.99999 then
			rig.base = now * rig.lastT:Inverse()
		end
		local cf = rig.base * t
		primary.CFrame = cf
		rig.written = cf
	end
	rig.lastT = t
	local mesh = rig.mesh
	if mesh then
		local s = rig.scaled
		local sx, sy, sz = posed.sx, posed.sy, posed.sz
		if math.abs(sx - s[1]) > SIZE_STEP or math.abs(sy - s[2]) > SIZE_STEP or math.abs(sz - s[3]) > SIZE_STEP then
			s[1], s[2], s[3] = sx, sy, sz
			local a, size = rig.axes, rig.size
			mesh.Size = Vector3.new(size.X * s[a[1]], size.Y * s[a[2]], size.Z * s[a[3]])
			if rig.head then
				MeshHead.resize(rig.head)
			end
		end
	end
	local alpha = posed.alpha
	if math.abs(alpha - rig.alpha) > ALPHA_STEP or (alpha == 0 and rig.alpha ~= 0) then
		rig.alpha = alpha
		for i, part in rig.parts do
			local own = rig.opaque[i]
			part.Transparency = own + (1 - own) * alpha
		end
	end
	local bones = posed.bones
	if bones then
		for name, r in bones do
			local bone = rig.bones[name]
			if bone then
				bone.Transform = CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			end
		end
	end
	if rig.legs then
		MeshFold.write(rig.legs, posed.fold)
	end
	if rig.octo then
		writeLegs(rig.octo)
	end
	local head = rig.head
	if head then
		-- the look's PrimaryPart as posed: under the server's root (its motor or weld), else AnimLab's stage
		local part0 = if motor then motor.Part0 elseif weld then weld.Part0 else nil
		local restAt = if part0 then part0.CFrame * rig.c0 else rig.base
		MeshHead.drive(head, rig.motion, rig.input, posed, restAt * t, restAt, rig.monster, rig.dying)
	end
	local muzzle = rig.muzzle
	if muzzle then
		if posed.acting then
			-- the shot leaves the body where it is now (root space: the look hangs at c0 under the root)
			muzzle.Position = (rig.c0 * t * rig.c0:Inverse()) * rig.muzzleRest
			rig.muzzleMoved = true
		elseif rig.muzzleMoved then
			muzzle.Position = rig.muzzleRest
			rig.muzzleMoved = false
		end
	end
end

-- Back to rest (the look keeps living without the rig).
function RigidRig.clear(rig: Rig)
	if rig.motor then
		rig.motor.Transform = CFrame.identity
	elseif rig.weld then
		rig.weld.C0 = rig.c0
	end
	if rig.mesh then
		rig.mesh.Size = rig.size
		rig.scaled[1], rig.scaled[2], rig.scaled[3] = 1, 1, 1
	end
	if rig.head then
		MeshHead.stop(rig.head)
	end
	for i, part in rig.parts do
		part.Transparency = rig.opaque[i]
	end
	rig.alpha = 0
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
	local octo = rig.octo
	if octo then
		for _, list in { octo.legs, octo.arms, octo.fangs, { octo.abdomen, octo.tail } } do
			for _, joints in list do
				for _, joint in joints do
					joint.a, joint.b, joint.cf = 0, 0, nil
				end
			end
		end
		octo.motion.ready = false
	end
	if rig.muzzle then
		rig.muzzle.Position = rig.muzzleRest
		rig.muzzleMoved = false
	end
	if rig.legs then
		MeshFold.release(rig.legs)
	end
	live[rig.motion] = nil
end

return RigidRig
