--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d, to przez modele
-- generowane za pomocą tripio czy przez roblox tez by sie tak zachowywały?"): the head of a rigid look (one MeshPart,
-- no bones: Data/RigidRigs `gaze`) turns on a bone added in code, as Vaelgrath's jaw does (client/Anim/MeshJaw).
-- * Once per mesh, when its first look is rigged (client/Anim/RigidRig): a growable EditableMesh of the look's mesh is
--   read (positions and faces, in batches over frames), Logic/NeckBend finds the head, two bones are added (`MeshRoot`
--   at the mesh's centre, `MeshHead` under it at the joint) and every vertex is skinned to them (the body to the
--   root, the head to the head bone, the neck blended). The mesh is shown through a MeshPart made from it
--   (AssetService:CreateMeshPartAsync), kept for every look of that model while one shows it (and LINGER after).
-- * The nearest few looks (Config.Graphics.levels `heads` within `headRadius` studs of the camera; AnimLab's subject
--   always) put it on: Bones of the same names under their MeshPart (the engine binds them by name) and
--   MeshPart:ApplyMesh (the look keeps its texture and its SurfaceAppearance; its own mesh is kept to give back).
--   `drive` turns the head each frame by Logic/HeadGaze: at the aggro player's head (AnimLab: the actor), calm glances
--   (now and then at the local player when near), the sniff, the nod with the steps, the flinch of a hit. A look that
--   leaves the budget or dies eases back to rest and gets its own mesh back once still; where the legs fold in the
--   death (client/Anim/MeshFold bends the look's own mesh) at once (`stop`).
-- * The bones follow the mesh's Size (the squash: the bind poses scale with it).
-- * Feature-detected throughout: no EditableMesh (an older client, the game setting "Enable Mesh / Image APIs" off, a
--   mesh the game may not read, the memory budget spent), a head that cannot be found, a bone or a skin the engine
--   will not take, a part that does not come out skinned: the look moves as one piece and nothing breaks (Studio
--   prints why once per mesh, else what was found with the side and the top views). Client only.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local HeadGaze = require(ReplicatedStorage.Shared.Logic.HeadGaze)
local MeshFold = require(script.Parent.MeshFold)
local NeckBend = require(ReplicatedStorage.Shared.Logic.NeckBend)
local RigidMotion = require(ReplicatedStorage.Shared.Logic.RigidMotion)
local RigidRigs = require(ReplicatedStorage.Shared.Data.RigidRigs)
local State = require(script.Parent.Parent.UI.State)

local MeshHead = {}

-- The added bones (the mesh's and the looks' Bones).
local ROOT = "MeshRoot"
local HEAD = "MeshHead"
-- A mesh no look shows is kept this long (s), then freed.
local LINGER = 20
-- A mesh that could not be read (the memory budget spent) is tried again for a later look after this (s).
local RETRY = 30
-- How often the nearest looks are picked (s), and how much nearer one already turning counts (studs).
local PICK_EVERY = 0.25
local HYSTERESIS = 10
-- A look out of the budget (or dead) gets its own mesh back once its head has been at rest this long (s).
local SETTLE = 0.4
local REST = math.rad(0.3)
-- A turn change under this (rad) is not written.
local EPS = math.rad(0.05)
-- The local player within this (studs) draws the calm glances now and then.
local NOTICE = 25
-- AnimLab's look comes from this high above the look's pivot (AnimLabController's toActor).
local LAB_EYE = 3
-- Vertices skinned between two yields.
local BATCH = 400

local STUDIO = RunService:IsStudio()

type Shared = {
	key: string,
	name: string,
	state: "loading" | "ready" | "failed",
	why: string,
	retryAt: number?,
	em: EditableMesh?,
	temp: MeshPart?,
	centre: Vector3, -- the mesh's box centre (its own units: the part's origin)
	extent: Vector3, -- its box size
	joint: Vector3, -- the head bone's bind position (the mesh's own space)
	holders: { [MeshPart]: RBXScriptConnection },
}

export type Handle = {
	shared: Shared,
	look: Instance,
	mesh: MeshPart,
	rel: CFrame, -- the mesh in the look's frame at rest
	turn: CFrame, -- its axes in the look's (rel's rotation)
	back: CFrame, -- turn's inverse
	gaze: HeadGaze.State,
	input: { [string]: any }, -- Logic/HeadGaze's input (reused)
	state: "waiting" | "rest" | "live" | "off", -- waiting: its mesh is read; rest: its own mesh on; live: turning
	lab: boolean, -- AnimLab's subject (always on)
	wanted: boolean, -- among the nearest
	distance: number,
	root: Bone?,
	head: Bone?,
	original: MeshPart?, -- the look's own mesh, to give back
	target: Vector3?, -- AnimLab: where the actor stands (fixed)
	stillSince: number?, -- out of the budget (or dead) and at rest since
	written: { number }?, -- the turn written last
	shown: { [string]: any },
	shownAt: number,
}

local entries: { [string]: Shared } = {}
local byMesh: { [MeshPart]: Handle } = setmetatable({} :: any, { __mode = "k" })
local handles: { [Handle]: boolean } = setmetatable({} :: any, { __mode = "k" })
local pickAt = -math.huge

local function note(text: string)
	if STUDIO then
		print(`[MeshHead] {text}`)
	end
end

-- An error's message without where it was raised.
local function plain(err: any): string
	local text = tostring(err)
	for _ = 1, 4 do
		local bare = string.gsub(text, "^[%w%._]+:%d+: ", "")
		if bare == text then
			break
		end
		text = bare
	end
	return text
end

local function r2(x: number): number
	return math.floor(x * 100 + 0.5) / 100
end

-- (Studio: the head's state on the look, for the checks)
local function show(h: Handle, name: string, value: any)
	if STUDIO and h.shown[name] ~= value then
		h.shown[name] = value
		pcall(function()
			h.look:SetAttribute(name, value)
		end)
	end
end

-- Whether `item` is one of the bones this adds (a rig looking for a model's own bones skips them).
function MeshHead.owns(item: Instance): boolean
	return item:IsA("Bone") and (item.Name == ROOT or item.Name == HEAD)
end

-- Reads the mesh once, finds the head, adds its bones and skins it (in the background): the first look's `mesh`,
-- `rel` (the mesh in the look's frame). What was built (for Studio).
local function build(shared: Shared, mesh: MeshPart, rel: CFrame, o: RigidRigs.Gaze): string
	local started = os.clock()
	local yield = MeshFold.slicer()
	-- (the first look as it is now: it may go away while the mesh is read)
	local content, fidelity, shown = mesh.MeshContent, mesh.RenderFidelity, mesh.Size
	-- (growable: a mesh read fixed-size takes no bone in a running game, client/Anim/MeshJaw)
	local okMesh, made = pcall(function()
		return AssetService:CreateEditableMeshAsync(content, { FixedSize = false })
	end)
	if not okMesh or not made then
		shared.retryAt = os.clock() + RETRY
		error(`no EditableMesh ({if okMesh then "the memory budget" else plain(made)})`)
	end
	local em: EditableMesh = made
	local temp: MeshPart? = nil
	local ok, built = pcall(function(): string
		local ids, positions, tris = MeshFold.read(em, yield)
		local n = #positions
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for i = 1, n do
			lo, hi = lo:Min(positions[i]), hi:Max(positions[i])
		end
		local extent = hi - lo
		if extent.X <= 0 or extent.Y <= 0 or extent.Z <= 0 then
			error("a flat mesh")
		end
		-- the plan's frame: the look's axes, the mesh's units (its shape as shown), the box's centre at the origin
		local centre = (lo + hi) / 2
		local scale = shown / extent
		local mean = (scale.X + scale.Y + scale.Z) / 3
		local ratio = scale / mean
		local rot = rel.Rotation
		local pos = table.create(n * 3, 0)
		for i = 1, n do
			local p = rot * ((positions[i] - centre) * ratio)
			pos[i * 3 - 2], pos[i * 3 - 1], pos[i * 3] = p.X, p.Y, p.Z
			if i % 2000 == 0 then
				yield()
			end
		end
		yield()
		local view: { string }? = if STUDIO then {} else nil
		-- (the look's middle: its x = 0)
		local plan, why = NeckBend.plan(pos, tris, o, -rel.Position.X / mean, yield, view)
		if not plan then
			if view and #view > 0 then
				local drawn = table.concat(view, "\n")
				note(`{shared.name}: the views (H the head, + the bend, # the body, * the joint)\n{drawn}`)
			end
			error(`the head was not found: {why}`)
		end
		local j = plan.joint
		local joint = centre + rot:VectorToObjectSpace(Vector3.new(j[1], j[2], j[3])) / ratio
		-- the bones (their bind poses in the mesh's space) and every vertex's skin
		local rootId = em:AddBone({
			Name = ROOT,
			CFrame = CFrame.new(centre),
			Virtual = false, -- (Studio 2026-11-02: the engine demands it, client/Anim/MeshJaw)
		})
		local headId = em:AddBone({
			Name = HEAD,
			ParentId = rootId,
			CFrame = CFrame.new(joint),
			Virtual = false,
		})
		local share = NeckBend.shares(plan, n)
		local onRoot, onHead, onBoth, whole = { rootId }, { headId }, { rootId, headId }, { 1 }
		for i, id in ids do
			local s = share[i]
			if s <= 0 then
				em:SetVertexBones(id, onRoot)
				em:SetVertexBoneWeights(id, whole)
			elseif s >= 1 then
				em:SetVertexBones(id, onHead)
				em:SetVertexBoneWeights(id, whole)
			else
				em:SetVertexBones(id, onBoth)
				em:SetVertexBoneWeights(id, { 1 - s, s })
			end
			if i % BATCH == 0 then
				yield()
			end
		end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = fidelity,
		})
		temp = part
		shared.centre, shared.extent, shared.joint = centre, extent, joint
		local k = mean
		local tip = plan.tip
		local found = if plan.neck then "where the head narrows into the neck" else "at the data's `neck`"
		local text = `{shared.name}: {#plan.idx} of {n} vertices turn with the head ({plan.whole} whole, `
			.. `{plan.loose} loose shells), the cut {found} {r2(plan.cut * k)} studs behind the tip (section `
			.. `{r2(plan.section * k)}, the blend {r2(2 * plan.half * k)} long), the joint {r2((j[3] - tip[3]) * k)} `
			.. `behind and {r2((tip[2] - j[2]) * k)} under the tip; built in {r2(os.clock() - started)} s`
		if view and #view > 0 then
			text ..= `\n{table.concat(view, "\n")}`
		end
		return text
	end)
	if not ok then
		if temp then
			temp:Destroy()
		end
		em:Destroy()
		error(built, 0)
	end
	shared.em, shared.temp = em, temp
	return built
end

-- Frees the mesh LINGER after the last look showing it went away.
local function linger(shared: Shared)
	task.delay(LINGER, function()
		if next(shared.holders) == nil and entries[shared.key] == shared then
			entries[shared.key] = nil
			if shared.temp then
				shared.temp:Destroy()
				shared.temp = nil
			end
			if shared.em then
				shared.em:Destroy()
				shared.em = nil
			end
		end
	end)
end

-- Starts reading the mesh of `key` (Assets.Monsters `name`) for its first look.
local function warm(key: string, name: string, mesh: MeshPart, rel: CFrame, o: RigidRigs.Gaze): Shared
	local shared: Shared = {
		key = key,
		name = name,
		state = "loading",
		why = "",
		retryAt = nil,
		em = nil,
		temp = nil,
		centre = Vector3.zero,
		extent = Vector3.one,
		joint = Vector3.zero,
		holders = {},
	}
	entries[key] = shared
	task.spawn(function()
		local ok, err = pcall(build, shared, mesh, rel, o)
		if ok then
			note(err)
			shared.state = "ready"
			if next(shared.holders) == nil then
				-- (every look went away meanwhile)
				linger(shared)
			end
		else
			shared.state = "failed"
			shared.why = plain(err)
			note(`{name}: no head ({shared.why}); the look moves as one piece`)
		end
	end)
	return shared
end

-- The bones' places under the look's MeshPart for its Size now (the root at the box's centre: the part's origin).
local function place(h: Handle)
	local shared = h.shared
	local root, head = h.root, h.head
	if root then
		root.CFrame = CFrame.identity
	end
	if head then
		head.CFrame = CFrame.new((shared.joint - shared.centre) * (h.mesh.Size / shared.extent))
	end
end

-- The head's mesh and bones on the look (its own mesh kept to give back).
local function mount(h: Handle)
	local shared = h.shared
	local temp = shared.temp
	if shared.state ~= "ready" or not temp or not h.mesh:IsDescendantOf(game) then
		return
	end
	-- the look's own mesh, to give back (a look that cannot be copied stays one piece)
	local okCopy, copy = pcall(function(): MeshPart?
		return h.mesh:Clone()
	end)
	if not okCopy or not copy then
		h.state = "off"
		show(h, "HeadState", "off: the look's MeshPart cannot be copied")
		return
	end
	copy:ClearAllChildren()
	local made: { Instance } = { copy }
	local applied = false
	local ok, err = pcall(function()
		local root = Instance.new("Bone")
		root.Name = ROOT
		table.insert(made, root)
		local head = Instance.new("Bone")
		head.Name = HEAD
		head.Parent = root
		h.root, h.head, h.original = root, head, copy
		place(h)
		root.Parent = h.mesh
		pcall(function()
			temp.TextureContent = h.mesh.TextureContent
		end)
		h.mesh:ApplyMesh(temp)
		applied = true
		-- (a part that does not come out skinned would never turn its head)
		local okSkin, skinned = pcall(function(): any
			return h.mesh.HasSkinnedMesh
		end)
		if okSkin and skinned == false then
			error("the look's part is not skinned after ApplyMesh")
		end
	end)
	if not ok then
		local original = h.original
		if applied and original then
			pcall(function()
				h.mesh:ApplyMesh(original)
			end)
		end
		for _, item in made do
			item:Destroy()
		end
		h.root, h.head, h.original = nil, nil, nil
		h.state = "off"
		-- (no other look of this mesh tries again)
		shared.state = "failed"
		shared.why = plain(err)
		show(h, "HeadState", `off: {shared.why}`)
		note(`{shared.name}: the head was not put on a look ({shared.why}); the look moves as one piece`)
		return
	end
	h.state = "live"
	h.written, h.stillSince, h.gaze.lastNow = nil, nil, nil
	show(h, "HeadState", "live")
end

-- The look's own mesh back, the bones gone.
local function unmount(h: Handle)
	if h.state ~= "live" then
		return
	end
	local original = h.original
	if original then
		if h.mesh.Parent then
			pcall(function()
				h.mesh:ApplyMesh(original)
			end)
		end
		original:Destroy()
	end
	if h.root then
		h.root:Destroy()
	end
	h.root, h.head, h.original, h.written, h.stillSince = nil, nil, nil, nil, nil
	h.state = "rest"
	show(h, "HeadState", "rest")
end

local function drop(shared: Shared, mesh: MeshPart)
	local gone = shared.holders[mesh]
	if not gone then
		return
	end
	gone:Disconnect()
	shared.holders[mesh] = nil
	if next(shared.holders) == nil and shared.em then
		linger(shared)
	end
end

local function hold(shared: Shared, h: Handle)
	local mesh = h.mesh
	if shared.holders[mesh] then
		return
	end
	shared.holders[mesh] = mesh.Destroying:Connect(function()
		drop(shared, mesh)
		if h.original then
			h.original:Destroy()
			h.original = nil
		end
		byMesh[mesh] = nil
		handles[h] = nil
	end)
end

-- The nearest looks within the level's radius keep turning their heads (AnimLab's subject always).
local function pick()
	local camera = Workspace.CurrentCamera
	local level = GraphicsLevel.get(State.Get({ "account", "settings", "quality" }))
	local eye = camera and camera.CFrame.Position
	local list: { GraphicsLevel.Candidate } = {}
	local of: { Handle } = {}
	for h in handles do
		if h.lab then
			h.wanted = true
		elseif h.state ~= "off" and eye and h.mesh.Parent then
			local d = (h.mesh.Position - eye).Magnitude
			h.distance = d
			if d <= level.headRadius + (if h.wanted then HYSTERESIS else 0) then
				table.insert(list, { d = d, on = h.wanted })
				table.insert(of, h)
			else
				h.wanted = false
			end
		else
			h.wanted = false
		end
	end
	local keep = GraphicsLevel.nearest(list, level.heads, HYSTERESIS)
	for i, h in of do
		h.wanted = keep[i] == true
	end
end

-- The head of a rigid look (`look`: the cloned model of Assets.Monsters `model`; `mesh`: its one MeshPart, `rel` in
-- the look's frame), nil when the model has none or there is no EditableMesh here. Its mesh is built in the
-- background the first time: the look moves as one piece until then (and for good when it cannot be). `lab`: AnimLab's
-- subject (always on).
function MeshHead.attach(
	model: string,
	look: Instance,
	mesh: MeshPart,
	rel: CFrame,
	seed: number,
	lab: boolean
): Handle?
	local o = RigidRigs.gaze(model)
	if not o or not RunService:IsClient() or not MeshFold.available() then
		return nil
	end
	local own = byMesh[mesh]
	if own then
		-- (a rig built again over the same look: it picks up where it was, from its rest)
		own.lab = lab
		own.target = nil
		own.written = nil
		own.gaze.lastNow = nil
		return own
	end
	local key = `{model}|{tostring(mesh.MeshId)}`
	local shared = entries[key]
	if not shared or (shared.state == "failed" and shared.retryAt and os.clock() >= shared.retryAt) then
		shared = warm(key, model, mesh, rel, o)
	end
	local s = shared :: Shared
	local turn = rel.Rotation
	local h: Handle = {
		shared = s,
		look = look,
		mesh = mesh,
		rel = rel,
		turn = turn,
		back = turn:Inverse(),
		gaze = HeadGaze.new(o, seed),
		input = {},
		state = if s.state == "failed" then "off" else "waiting",
		lab = lab,
		wanted = lab,
		distance = 0,
		root = nil,
		head = nil,
		original = nil,
		target = nil,
		stillSince = nil,
		written = nil,
		shown = {},
		shownAt = 0,
	}
	byMesh[mesh] = h
	handles[h] = true
	hold(s, h)
	show(h, "HeadState", if h.state == "off" then `off: {s.why}` else "loading")
	return h
end

-- The gait's bob bumps per cycle (its gaits by weight).
local function bumpsOf(motion: RigidMotion.Instance): number
	local sum, total = 0, 0
	local gaits = motion.style.gaits
	for name, w in motion.weights do
		local g = gaits[name]
		if g and w > 0 then
			sum += w * g.bumps
			total += w
		end
	end
	return if total > 0 then sum / total else 2
end

-- One frame of the head: `motion` and `input` the rig's Logic/RigidMotion (`posed` its pose this frame), `body` the
-- look's PrimaryPart in the world as posed, `rest` its rest frame (under the server's root; AnimLab: the stage),
-- `monster` the server's monster (nil in AnimLab), `dying` a held action plays (a death).
function MeshHead.drive(
	h: Handle,
	motion: RigidMotion.Instance,
	input: RigidMotion.Input?,
	posed: RigidMotion.Posed,
	body: CFrame,
	rest: CFrame,
	monster: Model?,
	dying: boolean
)
	local state = h.state
	if state == "off" or not input then
		return
	end
	local shared = h.shared
	if state == "waiting" then
		if shared.state == "ready" then
			h.state, state = "rest", "rest"
			show(h, "HeadState", "rest")
		elseif shared.state == "failed" then
			h.state = "off"
			show(h, "HeadState", `off: {shared.why}`)
			return
		else
			return
		end
	end
	local clock = os.clock()
	if clock - pickAt >= PICK_EVERY then
		pickAt = clock
		pick()
	end
	local wanted = h.wanted and not dying
	if state == "rest" then
		if wanted then
			mount(h)
		end
		if h.state ~= "live" then
			return
		end
	end
	local head = h.head
	if not head then
		return
	end
	-- where the head is and where it looks (the look's axes)
	local size = h.mesh.Size / shared.extent
	local joint = (body * h.rel):PointToWorldSpace((shared.joint - shared.centre) * size)
	local gi = h.input
	table.clear(gi)
	gi.now = input.now
	gi.dt = if input.frozen then 0 else input.dt
	gi.snap = input.snap
	gi.dying = not wanted
	local look = input.look
	if wanted and look then
		local target: Vector3? = nil
		local id = if monster then monster:GetAttribute("AggroUserId") else nil
		if type(id) == "number" then
			local who = Players:GetPlayerByUserId(id)
			local character = who and who.Character
			local part = character
				and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
			if part and part:IsA("BasePart") then
				target = part.Position
			end
		elseif h.lab then
			-- (the actor stands still: where AnimLab's look points to from the look's pivot, once)
			if not h.target then
				local primary = if h.look:IsA("Model") then (h.look :: Model).PrimaryPart else nil
				local at = if primary then rest * primary.PivotOffset else rest
				h.target = at.Position
					+ Vector3.new(0, LAB_EYE, 0)
					+ at:VectorToWorldSpace(Vector3.new(look[1], look[2], look[3]))
			end
			target = h.target
		end
		local towards = if target
			then target - joint
			else rest:VectorToWorldSpace(Vector3.new(look[1], look[2], look[3]))
		local d = body:VectorToObjectSpace(towards)
		gi.look = { d.X, d.Y, d.Z }
	elseif wanted and not input.combat and not h.lab then
		local me = Players.LocalPlayer and Players.LocalPlayer.Character
		local part = me and me:FindFirstChild("Head")
		if part and part:IsA("BasePart") then
			local towards = part.Position - joint
			if towards.Magnitude < NOTICE then
				local d = body:VectorToObjectSpace(towards)
				gi.notice = { d.X, d.Y, d.Z }
			end
		end
	end
	gi.combat = input.combat
	gi.returning = input.returning
	gi.acting = posed.acting
	gi.stun = input.stun
	gi.move = motion.move
	gi.phase = motion.phase
	gi.bumps = bumpsOf(motion)
	gi.hitAt = input.hitAt
	gi.hitSide = input.hitSide
	gi.bodyPitch = math.asin(math.clamp(-posed.m[6], -1, 1))
	local yaw, pitch, roll = HeadGaze.step(h.gaze, gi :: any)
	-- written only when it turned
	local w = h.written
	if not w or math.abs(yaw - w[1]) > EPS or math.abs(pitch - w[2]) > EPS or math.abs(roll - w[3]) > EPS then
		h.written = { yaw, pitch, roll }
		local m = HeadGaze.matrix(yaw, pitch, roll)
		head.Transform = h.back * CFrame.new(0, 0, 0, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]) * h.turn
	end
	if STUDIO and clock - h.shownAt >= 0.1 then
		h.shownAt = clock
		show(h, "HeadYaw", math.round(math.deg(yaw) * 10) / 10)
		show(h, "HeadPitch", math.round(math.deg(pitch) * 10) / 10)
	end
	-- out of the budget (or dead) and still: its own mesh back
	if not wanted then
		if math.abs(yaw) < REST and math.abs(pitch) < REST and math.abs(roll) < REST then
			h.stillSince = h.stillSince or clock
			if clock - (h.stillSince :: number) >= SETTLE then
				unmount(h)
			end
		else
			h.stillSince = nil
		end
	end
end

-- The bones moved with the mesh's new Size (the squash).
function MeshHead.resize(h: Handle)
	if h.state == "live" then
		place(h)
	end
end

-- The look's own mesh back at once (the head as modelled): a fold of the legs in the death bends the look's own
-- mesh, and a rig let go clears its look.
function MeshHead.stop(h: Handle)
	unmount(h)
	h.gaze.lastNow = nil
end

return MeshHead
