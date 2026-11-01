--!strict
-- Template animation (owner 2026-11-01: Vaelgrath's mouth is modelled open and its rig has no jaw bone): a jaw bone
-- added in code to the skinned mesh of a model with a Data/BipedRigs `jaw`, closed at rest and opened by the actions.
-- * Once per mesh, when its first look is rigged (client/Anim/BipedRig): an EditableMesh of the look's mesh is read
--   (positions, faces, the skin of the vertices on the head bone and the bones under it, in batches over frames),
--   Logic/JawHinge finds the lower jaw and the hinge, a bone is added under the head bone at the hinge (its bind pose
--   in the mesh's space, turned as the head's) and the lower jaw's head skin moves onto it (blended near the hinge).
--   The mesh is shown through a MeshPart made from it (AssetService:CreateMeshPartAsync) and kept for every look of
--   that model while one shows it (and LINGER after: AnimLab builds a new look on every play).
-- * Each look then gets a Bone of the same name under its head bone (the engine binds the mesh's bones to the Bone
--   instances by name) and the mesh (MeshPart:ApplyMesh: the look's own MeshPart keeps its texture, its
--   SurfaceAppearance and its other bones); `drive` turns the bone about the look's x each frame (its Transform, like
--   the other bones): closed, less the opening the action's keys give (Logic/JawHinge.open) at the motion's time.
-- * A dead boss's look clone (MonsterViewController's long death) holds the mesh too and its jaw plays on (`rebind`).
-- * Feature-detected throughout: no EditableMesh (an older client, the game setting "Enable Mesh / Image APIs" off, a
--   mesh the game may not read, the memory budget spent), a mesh without the head bone or the bone's name taken, a
--   mouth that cannot be found, a bone the engine will not add: the mouth stays as modelled and nothing breaks
--   (Studio prints why once per mesh, and what was built). Client only; nothing runs for a model without a `jaw`.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BipedRigs = require(ReplicatedStorage.Shared.Data.BipedRigs)
local JawHinge = require(ReplicatedStorage.Shared.Logic.JawHinge)
local MeshFold = require(script.Parent.MeshFold)

local MeshJaw = {}

-- The added bone (the mesh's and the looks' Bone).
local JAW = "MeshJaw"
-- A mesh no look shows is kept this long (s), then freed.
local LINGER = 20
-- A mesh that could not be read (the memory budget spent) is tried again for a later look after this (s).
local RETRY = 30
-- The motion's clock jumping back or forward by more than this (s: AnimLab's freeze and step) snaps the jaw.
local JUMP = 0.5
-- A turn change under this (rad) is not written.
local EPS = 0.002
-- Vertices read between two yields.
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
	plan: JawHinge.Plan?,
	extent: Vector3, -- the mesh's box (its own units)
	headAt: Vector3, -- the head bone's bind position (the mesh's space)
	headTurn: CFrame, -- its bind rotation
	hinge: Vector3, -- the jaw bone's bind position
	holders: { [MeshPart]: RBXScriptConnection },
	waiting: { Handle },
}

export type Handle = {
	shared: Shared,
	look: Instance,
	mesh: MeshPart,
	head: Bone,
	root: BasePart,
	options: BipedRigs.Jaw,
	state: "waiting" | "live" | "off",
	jaw: Bone?,
	axis: Vector3, -- the look's x in the head bone's frame (the hinge's axis)
	scale: number, -- studs per unit of the plan (this look)
	drawn: number, -- rad: the jaw's turn up from as modelled (+ closes)
	written: number?,
	lastNow: number?,
	lastClock: number?,
	shown: { [string]: any },
}

local entries: { [string]: Shared } = {}
local byMesh: { [MeshPart]: Handle } = setmetatable({} :: any, { __mode = "k" })

local function note(text: string)
	if STUDIO then
		print(`[MeshJaw] {text}`)
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

-- (Studio: the jaw's state on the look, for the measures)
local function show(h: Handle, name: string, value: any)
	if STUDIO and h.shown[name] ~= value then
		h.shown[name] = value
		pcall(function()
			h.look:SetAttribute(name, value)
		end)
	end
end

-- The skinned MeshPart the head bone moves (its ancestor, else the look's one skinned MeshPart).
local function meshOf(look: Instance, head: Bone): MeshPart?
	local above = head:FindFirstAncestorWhichIsA("MeshPart")
	if above then
		return above
	end
	local found: MeshPart? = nil
	for _, item in look:GetDescendants() do
		if item:IsA("MeshPart") then
			local ok, skinned = pcall(function()
				return item.HasSkinnedMesh
			end)
			if ok and skinned then
				if found then
					return nil
				end
				found = item
			end
		end
	end
	return found
end

-- The bones of `em` under `headId` (it included), by id.
local function headSetOf(em: EditableMesh, headId: number): { [number]: boolean }
	local set: { [number]: boolean } = { [headId] = true }
	local bones = em:GetBones()
	for _, bone in bones do
		local at: any = bone
		for _ = 1, #bones do
			local ok, up = pcall(function()
				return em:GetBoneParent(at)
			end)
			if not ok or type(up) ~= "number" or up == at then
				break
			end
			if up == headId then
				set[bone :: number] = true
				break
			end
			at = up
		end
	end
	return set
end

-- The bone added to `em` at the hinge under the head bone; its id (errors when the engine will not add it).
local function addBone(em: EditableMesh, shared: Shared, headName: string): (number, { [number]: boolean })
	local headId = em:GetBoneByName(headName)
	if pcall(function()
		return em:GetBoneByName(JAW)
	end) then
		error(`the mesh already has a bone named {JAW}`)
	end
	local jawId = em:AddBone({
		Name = JAW,
		ParentId = headId,
		CFrame = CFrame.new(shared.hinge) * shared.headTurn,
		Virtual = false, -- (Studio 2026-11-02: the engine demands it, "Missing bone Virtual value")
	})
	return jawId, headSetOf(em, headId)
end

-- Reads the mesh once, finds the jaw and adds its bone (in the background): the first look's `mesh`, `head` bone and
-- `root` part. What was built (for Studio).
local function build(shared: Shared, mesh: MeshPart, head: Bone, root: BasePart, o: BipedRigs.Jaw): string
	local started = os.clock()
	local yield = MeshFold.slicer()
	-- (the first look as it is now: it may go away while the mesh is read)
	local content, fidelity, shown, place = mesh.MeshContent, mesh.RenderFidelity, mesh.Size, mesh.CFrame
	local rot = root.CFrame:ToObjectSpace(place).Rotation
	local headName, headWorld = head.Name, head.WorldPosition
	local okMesh, made = pcall(function()
		return AssetService:CreateEditableMeshAsync(content)
	end)
	if not okMesh or not made then
		shared.retryAt = os.clock() + RETRY
		error(`no EditableMesh ({if okMesh then "the memory budget" else tostring(made)})`)
	end
	local em: EditableMesh = made
	local temp: MeshPart? = nil
	local ok, built = pcall(function(): string
		local headId = em:GetBoneByName(headName)
		local headBind = em:GetBoneCFrame(headId)
		local headSet = headSetOf(em, headId)
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
		-- the plan's frame: the head bone's joint at the origin, the look's axes, the mesh's units (its shape as shown)
		local size = shown / extent
		local mean = (size.X + size.Y + size.Z) / 3
		local ratio = size / mean
		local at = headBind.Position
		-- the head's vertices (any skin on the head bone or under it) and their share of it
		local keep: { number } = {}
		local skin: { number } = {}
		for i, id in ids do
			local bones = em:GetVertexBones(id)
			local onHead = false
			for _, b in bones do
				if headSet[b :: number] then
					onHead = true
					break
				end
			end
			if onHead then
				local weights = em:GetVertexBoneWeights(id)
				local on, total = 0, 0
				for k, b in bones do
					local w = (weights[k] :: number?) or 0
					total += w
					if headSet[b :: number] then
						on += w
					end
				end
				if total > 0 and on > 0 then
					table.insert(keep, i)
					table.insert(skin, on / total)
				end
			end
			if i % BATCH == 0 then
				yield()
			end
		end
		if #keep < 8 then
			error(`nothing skinned to the head bone {headName}`)
		end
		local slot = table.create(n, 0)
		local pos = table.create(#keep * 3, 0)
		for j, i in keep do
			slot[i] = j
			local p = rot * ((positions[i] - at) * ratio)
			pos[j * 3 - 2], pos[j * 3 - 1], pos[j * 3] = p.X, p.Y, p.Z
		end
		local faces: { number }? = nil
		if tris then
			local list: { number } = {}
			for f = 0, #tris // 3 - 1 do
				local a, b, c = slot[tris[f * 3 + 1]], slot[tris[f * 3 + 2]], slot[tris[f * 3 + 3]]
				if a > 0 and b > 0 and c > 0 then
					table.insert(list, a)
					table.insert(list, b)
					table.insert(list, c)
				end
			end
			faces = list
		end
		yield()
		local view: { string }? = if STUDIO then {} else nil
		local plan, why = JawHinge.plan(pos, skin, faces, o, yield, view)
		if not plan then
			if view and #view > 0 then
				-- (the head's side view, the snout's tip on the left: `#` faces, `o` the opening taken, `.` other gaps)
				note(`{shared.name}: the side view\n{table.concat(view, "\n")}`)
			end
			error(`the mouth was not found: {why}`)
		end
		shared.plan = plan
		shared.extent = extent
		shared.headAt = at
		shared.headTurn = headBind.Rotation
		shared.hinge = at + rot:VectorToObjectSpace(Vector3.new(0, plan.hinge[1], plan.hinge[2])) / ratio
		-- the bone (a mesh read fixed-size may not take one: then read again growable, the same vertices)
		local okBone, jawId, jawSet = pcall(addBone, em, shared, headName)
		if not okBone then
			local firstWhy = plain(jawId)
			local okGrow, grown = pcall(function()
				return AssetService:CreateEditableMeshAsync(content, { FixedSize = false })
			end)
			if not okGrow or not grown then
				error(`the engine will not add a bone: {firstWhy}`)
			end
			em:Destroy()
			em = grown
			local again = em:GetVertices()
			local same = #again == n
			for k = 1, if same then 12 else 0 do
				local i = math.max(1, math.floor(k * n / 12))
				if (em:GetPosition(again[i]) - positions[i]).Magnitude > extent.Magnitude * 1e-4 then
					same = false
				end
			end
			if not same then
				error(`the engine will not add a bone: {firstWhy} (and the growable mesh is another)`)
			end
			ids = again
			local okAgain, idAgain, setAgain = pcall(addBone, em, shared, headName)
			if not okAgain then
				error(`the engine will not add a bone: {firstWhy} (growable: {plain(idAgain)})`)
			end
			jawId, jawSet = idAgain, setAgain
		end
		-- the lower jaw's share of its head skin onto it
		local moved = 0
		for j, i in plan.idx do
			local id = ids[keep[i]]
			local bones = em:GetVertexBones(id) :: { number }
			local weights = em:GetVertexBoneWeights(id) :: { number }
			local nb, nw = JawHinge.reweigh(bones, weights, jawSet, plan.share[j], jawId)
			if nb and nw then
				em:SetVertexBones(id, nb)
				em:SetVertexBoneWeights(id, nw)
				moved += 1
			end
			if j % BATCH == 0 then
				yield()
			end
		end
		if moved == 0 then
			error("no vertex took the jaw bone")
		end
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = fidelity,
		})
		temp = part
		-- (Studio: the head bone's bind pose against its Bone in this look, by the mesh centred in its part: about 0
		-- when the mesh's space is read right)
		local bindAt = place:PointToWorldSpace((at - (lo + hi) / 2) * size)
		local off = (bindAt - headWorld).Magnitude
		local k = mean
		return `{shared.name}: {moved} vertices on the jaw ({plan.full} whole), hinge {r2(-plan.hinge[2] * k)} ahead of and `
			.. `{r2(-plan.hinge[1] * k)} under the head joint, closed {r2(math.deg(plan.closed))} deg (front gap `
			.. `{r2(JawHinge.gap(plan, 0) * k)} -> {r2(JawHinge.gap(plan, plan.closed) * k)} studs), opening over `
			.. `{plan.columns} columns; head bind {r2(off)} studs off its bone; built in {r2(os.clock() - started)} s`
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

local function hold(shared: Shared, mesh: MeshPart)
	if shared.holders[mesh] then
		return
	end
	shared.holders[mesh] = mesh.Destroying:Connect(function()
		drop(shared, mesh)
		byMesh[mesh] = nil
	end)
end

-- The look's own jaw: the Bone at the hinge and the mesh on its MeshPart.
local function mount(h: Handle)
	local shared = h.shared
	local plan, temp = shared.plan, shared.temp
	if not plan or not temp or not h.mesh:IsDescendantOf(game) or not h.head:IsDescendantOf(game) then
		h.state = "off"
		show(h, "JawState", "off: the look went away")
		return
	end
	local made: Bone? = nil
	local ok, err = pcall(function()
		local size = h.mesh.Size / shared.extent
		h.scale = (size.X + size.Y + size.Z) / 3
		local found = h.head:FindFirstChild(JAW)
		local jaw: Bone
		if found and found:IsA("Bone") then
			jaw = found
		else
			jaw = Instance.new("Bone")
			made = jaw
		end
		jaw.Name = JAW
		-- its rest at the hinge, turned as the head bone: its offset from the head's bind pose, in studs
		jaw.CFrame = CFrame.new(shared.headTurn:VectorToObjectSpace((shared.hinge - shared.headAt) * size))
		jaw.Transform = CFrame.identity
		jaw.Parent = h.head
		h.axis = h.head.WorldCFrame:VectorToObjectSpace(h.root.CFrame.RightVector).Unit
		pcall(function()
			temp.TextureContent = h.mesh.TextureContent
		end)
		h.mesh:ApplyMesh(temp)
		h.jaw = jaw
	end)
	if not ok then
		if made then
			made:Destroy()
		end
		h.state = "off"
		show(h, "JawState", `off: {plain(err)}`)
		note(`{shared.name}: the jaw was not put on a look ({plain(err)})`)
		return
	end
	-- (as modelled until the first frames ease it shut)
	h.drawn, h.written, h.lastNow, h.lastClock = 0, nil, nil, nil
	h.state = "live"
	show(h, "JawState", "live")
	show(h, "JawClosed", r2(math.deg(plan.closed)))
end

-- Starts reading the mesh of `key` (Assets.Monsters `name`) for its first look.
local function warm(key: string, name: string, mesh: MeshPart, head: Bone, root: BasePart, o: BipedRigs.Jaw): Shared
	local shared: Shared = {
		key = key,
		name = name,
		state = "loading",
		why = "",
		retryAt = nil,
		em = nil,
		temp = nil,
		plan = nil,
		extent = Vector3.one,
		headAt = Vector3.zero,
		headTurn = CFrame.identity,
		hinge = Vector3.zero,
		holders = {},
		waiting = {},
	}
	entries[key] = shared
	task.spawn(function()
		local ok, err = pcall(build, shared, mesh, head, root, o)
		local waiting = shared.waiting
		shared.waiting = {}
		if ok then
			note(err)
			shared.state = "ready"
			for _, h in waiting do
				if h.state == "waiting" then
					mount(h)
				end
			end
			if next(shared.holders) == nil then
				-- (every look went away meanwhile)
				linger(shared)
			end
		else
			shared.state = "failed"
			shared.why = plain(err)
			note(`{name}: no jaw ({shared.why}); the mouth stays as modelled`)
			for _, h in waiting do
				h.state = "off"
				show(h, "JawState", `off: {shared.why}`)
			end
		end
	end)
	return shared
end

-- The jaw of a look (`look`: the cloned model of Assets.Monsters `model`; `head`: its bone the data's `head` key
-- names; `root`: its root part), nil when the model has none or there is no EditableMesh here. Its mesh is built in
-- the background the first time: the mouth stays as modelled until then (and for good when it cannot be).
function MeshJaw.attach(look: Instance, head: Bone?, model: string?, root: BasePart): Handle?
	local o = if model then BipedRigs.jaw(model) else nil
	if not o or not model or not RunService:IsClient() or not MeshFold.available() then
		return nil
	end
	if not head then
		note(`{model}: no bone for the pose key {o.head}; the mouth stays as modelled`)
		return nil
	end
	local mesh = meshOf(look, head)
	if not mesh then
		note(`{model}: no skinned MeshPart under the head bone; the mouth stays as modelled`)
		return nil
	end
	local own = byMesh[mesh]
	if own and own.head == head and own.state ~= "off" then
		own.written, own.lastNow, own.lastClock = nil, nil, nil
		return own
	end
	local key = `{model}|{tostring(mesh.MeshId)}`
	local shared = entries[key]
	if not shared or (shared.state == "failed" and shared.retryAt and os.clock() >= shared.retryAt) then
		shared = warm(key, model, mesh, head, root, o)
	end
	local s = shared :: Shared
	local h: Handle = {
		shared = s,
		look = look,
		mesh = mesh,
		head = head,
		root = root,
		options = o,
		state = "waiting",
		jaw = nil,
		axis = Vector3.xAxis,
		scale = 1,
		drawn = 0,
		written = nil,
		lastNow = nil,
		lastClock = nil,
		shown = {},
	}
	byMesh[mesh] = h
	hold(s, mesh)
	if s.state == "ready" then
		mount(h)
	elseif s.state == "loading" then
		table.insert(s.waiting, h)
		show(h, "JawState", "loading")
	else
		h.state = "off"
		show(h, "JawState", `off: {s.why}`)
	end
	return h
end

-- One frame of the jaw: closed, less the opening of the action `motion` (Logic/BipedMotion's instance) plays at `now`
-- (its clock), followed at the data's `rate` (real time: AnimLab's frozen frame still settles; a jump of the motion's
-- clock snaps it).
function MeshJaw.drive(h: Handle, motion: any, now: number)
	local jaw, plan = h.jaw, h.shared.plan
	if h.state ~= "live" or not jaw or not plan then
		return
	end
	local o = h.options
	local open = 0
	local run = motion and motion.lastAction
	local actions = motion and motion.style and motion.style.actions
	if run and actions then
		local action = actions[run.name]
		if action then
			open = JawHinge.open(o, run.name, action, run.hit, now - run.start)
		end
	end
	local target = plan.closed - math.rad(open)
	local clock = os.clock()
	local last = h.lastNow
	if last and (now < last - 1e-6 or now - last > JUMP) then
		h.drawn = target
	else
		local dt = if h.lastClock then clock - h.lastClock else 0
		h.drawn += (target - h.drawn) * (1 - math.exp(-o.rate * dt))
	end
	h.lastNow, h.lastClock = now, clock
	local written = h.written
	if written == nil or math.abs(h.drawn - written) > EPS then
		h.written = h.drawn
		jaw.Transform = CFrame.fromAxisAngle(h.axis, h.drawn)
	end
	if STUDIO then
		show(h, "JawOpen", r2(math.deg(plan.closed - h.drawn)))
		show(h, "JawTipGap", r2(JawHinge.gap(plan, h.drawn) * h.scale))
	end
end

-- The jaw moved onto a clone of its look (a dead boss's, MonsterViewController's long death): the clone's MeshPart
-- holds the mesh too and its jaw Bone plays on. nil when the jaw is not on or the clone lacks it.
function MeshJaw.rebind(h: Handle, copy: Instance): Handle?
	local temp = h.shared.temp
	if h.state ~= "live" or not temp then
		return nil
	end
	local found = copy:FindFirstChild(JAW, true)
	local head = found and found.Parent
	if not (found and found:IsA("Bone") and head and head:IsA("Bone")) then
		return nil
	end
	local mesh = found:FindFirstAncestorWhichIsA("MeshPart")
	if not mesh then
		local named = copy:FindFirstChild(h.mesh.Name, true)
		mesh = if named and named:IsA("MeshPart") then named else nil
	end
	if not mesh then
		return nil
	end
	-- (a clone may not carry over a mesh made in code: put on again)
	pcall(function()
		temp.TextureContent = mesh.TextureContent
		mesh:ApplyMesh(temp)
	end)
	local twin: Handle = table.clone(h)
	twin.look, twin.mesh, twin.head, twin.jaw = copy, mesh, head :: Bone, found :: Bone
	twin.written, twin.lastNow, twin.lastClock = nil, nil, nil
	twin.shown = {}
	byMesh[mesh] = twin
	hold(h.shared, mesh)
	return twin
end

-- Back to the mouth as modelled (the export's own pose).
function MeshJaw.clear(h: Handle)
	if h.jaw then
		h.jaw.Transform = CFrame.identity
	end
	h.drawn, h.written, h.lastNow, h.lastClock = 0, nil, nil, nil
end

return MeshJaw
