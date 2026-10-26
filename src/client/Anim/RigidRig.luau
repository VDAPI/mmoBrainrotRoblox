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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local MeshFold = require(script.Parent.MeshFold)
local MonsterMove = require(ReplicatedStorage.Shared.Logic.MonsterMove)
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
}

-- Every live rig by its motion (weak: a look destroyed takes its rig along).
local live: { [RigidMotion.Instance]: Rig } = setmetatable({} :: any, { __mode = "kv" })
local pickAt = -math.huge

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
		if item:IsA("Bone") and not byName[item.Name] then
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
	local mesh: MeshPart? = nil
	local size = Vector3.one
	local axes = { 1, 2, 3 }
	local skinned = next(bones) ~= nil or look:FindFirstChildWhichIsA("Bone", true) ~= nil
	local legs: MeshFold.Handle? = nil
	if #parts == 1 and parts[1]:IsA("MeshPart") and not skinned then
		local part = parts[1] :: MeshPart
		mesh = part
		size = rest(part, "RigidSize", part.Size) :: Vector3
		part.Size = size
		local rel = primary.CFrame:ToObjectSpace(part.CFrame)
		axes = { axisOf(rel.XVector), axisOf(rel.YVector), axisOf(rel.ZVector) }
		body.squash = true
		legs = MeshFold.attach(model, part, rel, size, seed)
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

-- The nearest few rigs (to the camera) may squash.
local function pickNear()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local list: { Rig } = {}
	for _, rig in live do
		rig.near = false
		local root = rig.root
		if rig.mesh and root and rig.look.Parent then
			rig.distance = (root.Position - eye).Magnitude
			table.insert(list, rig)
		end
	end
	table.sort(list, function(a: Rig, b: Rig)
		return a.distance < b.distance
	end)
	for i = 1, math.min(SQUASH_NEAREST, #list) do
		list[i].near = true
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
	local legs = rig.legs
	if legs then
		-- a death (a held action) folds the legs where the mesh can be bent; the body learns the folded boxes
		local run = input.action
		local action = if run then rig.motion.style.actions[run.name] else nil
		local dying = run ~= nil and action ~= nil and action.hold == true and input.now >= run.start
		input.fold = MeshFold.share(legs, dying)
		rig.motion.body.folds = MeshFold.folds(legs)
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
		return RigidMotion.step(motion, input)
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
	for i, part in rig.parts do
		part.Transparency = rig.opaque[i]
	end
	rig.alpha = 0
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
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
