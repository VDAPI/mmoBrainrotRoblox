--!strict
-- Template animation (owner 2026-10-26: "/animlab mob caveSpider deathCurl nogi sie nie skladaja jedynie posiac
-- przewraca sie na bok"): the legs of a rigid look (one MeshPart, no bones: caveSpider, desertScorpion, Data/RigidRigs
-- `fold`) really curl in on its death, by moving the vertices of an EditableMesh (Logic/LegFold).
-- * Once per mesh, when its first look is built: a throwaway EditableMesh is read (positions and faces, in batches),
--   Logic/LegFold finds the legs (spread over frames: a few ms each) and the plan is kept for every later look.
-- * A dying look (client/Anim/RigidRig, a death action) gets its own fixed-size EditableMesh, shown on its MeshPart
--   (AssetService:CreateMeshPartAsync, MeshPart:ApplyMesh: the look keeps its texture); only the leg vertices and their
--   normals are written, each in one batch, at most WRITE_EVERY and only while the fold changes. RigidMotion gets the
--   share it draws (ramped in over RAMP, so a mesh that arrives late does not pop) and the folded boxes (the body
--   sinks onto the curled legs).
-- * At most MAX_LIVE looks at once, within MAX_DISTANCE of the camera; the look's own mesh goes back and the
--   EditableMesh is destroyed when the look goes away (the corpse) or stops folding (AnimLab back to idle).
-- * Feature-detected throughout: no EditableMesh (an older client, the game setting "Enable Mesh / Image APIs" off, a
--   mesh the game may not read, the memory budget spent, a mesh whose legs cannot be told apart) and the death stays
--   rigid, silently (Studio prints why once per mesh). Nothing runs for a living monster.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LegFold = require(ReplicatedStorage.Shared.Logic.LegFold)
local RigidMotion = require(ReplicatedStorage.Shared.Logic.RigidMotion)
local RigidRigs = require(ReplicatedStorage.Shared.Data.RigidRigs)

local MeshFold = {}

-- Dying looks folding at once, and how far from the camera (studs).
local MAX_LIVE = 3
local MAX_DISTANCE = 150
-- Vertex writes: at most this often (s), only for a fold change bigger than this.
local WRITE_EVERY = 1 / 30
local FOLD_STEP = 0.004
-- The drawn share ramps in over this (s) once the mesh is shown.
local RAMP = 0.15
-- A look not folding for this long (s) gets its own mesh back.
local QUIET = 0.5
-- Planning work per frame (s).
local SLICE = 0.004
-- Rest positions compared to tell a new copy of the mesh is the planned one.
local PROBES = 12

type Shape = {
	state: "loading" | "ready" | "failed",
	plan: LegFold.Plan?,
	count: number,
	centre: Vector3, -- the mesh's box centre (its own units)
	extent: Vector3, -- its box size
	ratio: Vector3, -- the shape correction into the plan's frame
	rot: CFrame, -- the mesh's axes in the look
	probe: { [number]: Vector3 },
}

export type Handle = {
	key: string,
	mesh: MeshPart,
	rel: CFrame, -- the mesh in the look's frame at rest
	size: Vector3, -- its rest Size
	seed: number,
	state: "idle" | "loading" | "live" | "failed",
	token: number, -- bumped by every start and release (a mesh still loading for an old one is dropped)
	em: EditableMesh?,
	temp: MeshPart?,
	original: MeshPart?,
	ids: { number },
	values: { Vector3 },
	out: { number },
	angles: { number },
	map: { number },
	normalIds: { number },
	normalOf: { number },
	normalRest: { number },
	normalValues: { Vector3 },
	folds: { RigidMotion.Fold }?,
	liveAt: number,
	lastFold: number,
	lastWrite: number,
	quietSince: number?,
	gone: RBXScriptConnection?,
}

local shapes: { [string]: Shape } = {}
local byMesh: { [MeshPart]: Handle } = setmetatable({} :: any, { __mode = "k" })
local busy = 0
local supported: boolean? = nil
local batchSet: boolean? = nil

-- The API is there at all (an older client has no EditableMesh).
local function available(): boolean
	if supported == nil then
		supported = pcall(function()
			assert(type(AssetService.CreateEditableMeshAsync) == "function", "no EditableMesh")
			assert(type(AssetService.CreateMeshPartAsync) == "function", "no CreateMeshPartAsync")
			assert(type(Content.fromObject) == "function", "no Content.fromObject")
		end)
	end
	return supported == true
end

local function note(text: string)
	if RunService:IsStudio() then
		print(`[MeshFold] {text}`)
	end
end

-- A yield for long work: lets the frame go every SLICE seconds.
local function slicer(): () -> ()
	local from = os.clock()
	return function()
		if os.clock() - from > SLICE then
			task.wait()
			from = os.clock()
		end
	end
end

-- Writes `values` to `ids` (one batch, else one by one on a client without it).
local function setValues(em: EditableMesh, ids: { number }, values: { Vector3 }, normals: boolean)
	if batchSet ~= false then
		local ok = pcall(function()
			em:BatchSetValues(ids, values)
		end)
		if ok then
			batchSet = true
			return
		end
		if batchSet == nil then
			batchSet = false
		else
			error("batch write failed")
		end
	end
	for i, id in ids do
		if normals then
			em:SetNormal(id, values[i])
		else
			em:SetPosition(id, values[i])
		end
	end
end

-- Reads a mesh once and plans its legs (in the background); what was found.
local function plan(shape: Shape, em: EditableMesh, rel: CFrame, size: Vector3, fold: RigidRigs.Fold): string
	local yield = slicer()
	local ids = em:GetVertices()
	local n = #ids
	local positions: { Vector3 } = {}
	local ok, got = pcall(function()
		return em:BatchGetValues(ids)
	end)
	if ok and type(got) == "table" and #got == n then
		positions = got
	else
		for i, id in ids do
			positions[i] = em:GetPosition(id)
			if i % 500 == 0 then
				yield()
			end
		end
	end
	local index: { [number]: number } = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for i, id in ids do
		index[id] = i
		local p = positions[i]
		lo, hi = lo:Min(p), hi:Max(p)
	end
	local extent = hi - lo
	if extent.X <= 0 or extent.Y <= 0 or extent.Z <= 0 then
		error("flat mesh")
	end
	local scale = size / extent
	local mean = (scale.X + scale.Y + scale.Z) / 3
	local ratio = scale / mean
	local centre = (lo + hi) / 2
	local rot = rel.Rotation
	-- the plan's frame: the look's axes, the mesh's units
	local pos = table.create(n * 3, 0)
	for i = 1, n do
		local p = rot * ((positions[i] - centre) * ratio)
		pos[i * 3 - 2], pos[i * 3 - 1], pos[i * 3] = p.X, p.Y, p.Z
	end
	yield()
	-- the faces as triangles (a polygon as a fan); none readable: LegFold goes by nearness
	local tris: { number }? = nil
	local okFaces = pcall(function()
		local faces = em:GetFaces()
		local corners: { any }
		local okBatch, batch = pcall(function()
			return em:BatchGetFaceAttributes(Enum.MeshAttribute.Vertex, faces)
		end)
		if okBatch and type(batch) == "table" and #batch == #faces then
			corners = batch
		else
			corners = {}
			for f, face in faces do
				corners[f] = em:GetFaceVertices(face)
				if f % 500 == 0 then
					yield()
				end
			end
		end
		local list = table.create(#faces * 3, 0)
		local at = 0
		for _, c in corners do
			for k = 2, #c - 1 do
				local a, b, d = index[c[1]], index[c[k]], index[c[k + 1]]
				if a and b and d then
					list[at + 1], list[at + 2], list[at + 3] = a, b, d
					at += 3
				end
			end
		end
		tris = list
	end)
	if not okFaces then
		tris = nil
	end
	yield()
	local result, why = LegFold.plan(pos, tris, fold, yield)
	if not result then
		error(why)
	end
	local probe: { [number]: Vector3 } = {}
	for k = 1, PROBES do
		local i = math.max(1, math.floor(k * n / PROBES))
		probe[i] = positions[i]
	end
	shape.plan, shape.count, shape.centre, shape.extent = result, n, centre, extent
	shape.ratio, shape.rot, shape.probe = ratio, rot, probe
	shape.state = "ready"
	return why
end

-- Starts reading the mesh of `model` once.
local function warm(key: string, mesh: MeshPart, rel: CFrame, size: Vector3, fold: RigidRigs.Fold, name: string)
	local shape: Shape = {
		state = "loading",
		plan = nil,
		count = 0,
		centre = Vector3.zero,
		extent = Vector3.one,
		ratio = Vector3.one,
		rot = CFrame.identity,
		probe = {},
	}
	shapes[key] = shape
	task.spawn(function()
		local okMesh, em = pcall(function()
			return AssetService:CreateEditableMeshAsync(mesh.MeshContent)
		end)
		if not okMesh or not em then
			shape.state = "failed"
			note(`{name}: no EditableMesh ({tostring(em)}); the death stays rigid`)
			return
		end
		local ok, found = pcall(plan, shape, em, rel, size, fold)
		em:Destroy()
		if ok then
			note(`{name}: {found}`)
		else
			shape.state = "failed"
			note(`{name}: the legs were not found ({tostring(found)}); the death stays rigid`)
		end
	end)
end

-- The handle of a rigid look whose legs may fold (nil: its model has no `fold`, or no EditableMesh here). Starts
-- planning its mesh the first time; nothing else runs until it dies.
function MeshFold.attach(model: string, mesh: MeshPart, rel: CFrame, size: Vector3, seed: number): Handle?
	local fold = RigidRigs.fold(model)
	if not fold or not available() then
		return nil
	end
	local own = byMesh[mesh]
	if own then
		own.seed = seed
		return own
	end
	local key = `{model}|{tostring(mesh.MeshId)}`
	if not shapes[key] then
		warm(key, mesh, rel, size, fold, model)
	end
	local handle: Handle = {
		key = key,
		mesh = mesh,
		rel = rel,
		size = size,
		seed = seed,
		state = "idle",
		token = 0,
		em = nil,
		temp = nil,
		original = nil,
		ids = {},
		values = {},
		out = {},
		angles = {},
		map = {},
		normalIds = {},
		normalOf = {},
		normalRest = {},
		normalValues = {},
		folds = nil,
		liveAt = 0,
		lastFold = 0,
		lastWrite = -math.huge,
		quietSince = nil,
		gone = nil,
	}
	byMesh[mesh] = handle
	return handle
end

-- Gives the look its own mesh back and frees the EditableMesh.
function MeshFold.release(h: Handle)
	if h.state == "idle" or h.state == "failed" then
		return
	end
	if h.state == "loading" or h.state == "live" then
		busy -= 1
	end
	h.token += 1
	h.state = "idle"
	h.folds = nil
	h.quietSince = nil
	if h.gone then
		h.gone:Disconnect()
		h.gone = nil
	end
	local original = h.original
	if original then
		if h.mesh.Parent then
			pcall(function()
				h.mesh:ApplyMesh(original)
			end)
		end
		original:Destroy()
		h.original = nil
	end
	if h.temp then
		h.temp:Destroy()
		h.temp = nil
	end
	if h.em then
		h.em:Destroy()
		h.em = nil
	end
	h.lastFold, h.lastWrite = 0, -math.huge
end

-- The dying look's own EditableMesh on its MeshPart (in the background); what it makes is dropped when the look
-- was released (or started again) meanwhile.
local function show(h: Handle, shape: Shape, token: number)
	local planned = shape.plan :: LegFold.Plan
	local em = AssetService:CreateEditableMeshAsync(h.mesh.MeshContent)
	if not em then
		error("memory budget")
	end
	local temp: MeshPart? = nil
	local copy: MeshPart? = nil
	local ok, err = pcall(function()
		if h.token ~= token or not h.mesh:IsDescendantOf(game) then
			error("gone")
		end
		local ids = em:GetVertices()
		if #ids ~= shape.count then
			error("another mesh")
		end
		local tolerance = shape.extent.Magnitude * 1e-4
		for i, p in shape.probe do
			if (em:GetPosition(ids[i]) - p).Magnitude > tolerance then
				error("another vertex order")
			end
		end
		local count = #planned.idx
		h.ids = table.create(count, 0)
		for j, i in planned.idx do
			h.ids[j] = ids[i]
		end
		h.values = table.create(count, Vector3.zero)
		h.out = table.create(count * 3, 0)
		h.angles = table.create(count, 0)
		-- the plan's frame -> the mesh: centre + rot^-1 * n / ratio
		local inv = shape.rot:Inverse()
		local r = shape.ratio
		local ax, ay, az = inv.XVector, inv.YVector, inv.ZVector
		local c = shape.centre
		h.map = {
			ax.X / r.X,
			ay.X / r.X,
			az.X / r.X,
			ax.Y / r.Y,
			ay.Y / r.Y,
			az.Y / r.Y,
			ax.Z / r.Z,
			ay.Z / r.Z,
			az.Z / r.Z,
			c.X,
			c.Y,
			c.Z,
		}
		-- the leg vertices' normals turn with them (lighting); none readable: they stay as they are
		h.normalIds, h.normalOf, h.normalRest, h.normalValues = {}, {}, {}, {}
		pcall(function()
			local lists = em:BatchGetVertexAttributes(Enum.MeshAttribute.Normal, h.ids)
			local seen: { [number]: boolean } = {}
			local normalIds, normalOf = {}, {}
			for j, list in lists do
				for _, id in list do
					if not seen[id] then
						seen[id] = true
						table.insert(normalIds, id)
						table.insert(normalOf, j)
					end
				end
			end
			local rest = em:BatchGetValues(normalIds)
			local flat = table.create(#normalIds * 3, 0)
			for k, nv in rest do
				local p = (shape.rot * (nv / r)).Unit
				flat[k * 3 - 2], flat[k * 3 - 1], flat[k * 3] = p.X, p.Y, p.Z
			end
			h.normalIds, h.normalOf, h.normalRest = normalIds, normalOf, flat
			h.normalValues = table.create(#normalIds, Vector3.zero)
		end)
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = h.mesh.RenderFidelity,
		})
		temp = part
		pcall(function()
			part.TextureContent = h.mesh.TextureContent
		end)
		-- the look's own mesh, to give it back (a look that cannot be copied keeps the EditableMesh until it goes)
		local okCopy, made = pcall(function()
			return h.mesh:Clone()
		end)
		if okCopy and made then
			made:ClearAllChildren()
			copy = made
		end
		if h.token ~= token or not h.mesh:IsDescendantOf(game) then
			error("gone")
		end
		h.mesh:ApplyMesh(part)
	end)
	if not ok then
		if temp then
			temp:Destroy()
		end
		if copy then
			copy:Destroy()
		end
		em:Destroy()
		error(err)
	end
	h.em, h.temp, h.original = em, temp, copy
	-- the folded boxes in the look's frame (the plan's frame scaled by this look's size)
	local scale = h.size / shape.extent
	local k = (scale.X + scale.Y + scale.Z) / 3
	local at = h.rel.Position
	local folds: { RigidMotion.Fold } = {}
	for _, b in planned.boxes do
		table.insert(folds, {
			h = at.Y + k * b.y1,
			lift = at.Y + k * b.y0,
			B = k * (b.z1 - b.z0),
			W = k * (b.x1 - b.x0),
			x0 = at.X + k * (b.x0 + b.x1) / 2,
			z0 = at.Z + k * (b.z0 + b.z1) / 2,
		})
	end
	h.folds = folds
	h.gone = h.mesh.AncestryChanged:Connect(function()
		if not h.mesh:IsDescendantOf(game) then
			MeshFold.release(h)
		end
	end)
	h.liveAt = os.clock()
	h.lastFold, h.lastWrite = 0, -math.huge
	h.state = "live"
end

-- Starts folding a dying look when a slot is free and it is near.
local function begin(h: Handle)
	local shape = shapes[h.key]
	if not shape or shape.state ~= "ready" or busy >= MAX_LIVE then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - h.mesh.Position).Magnitude > MAX_DISTANCE then
		return
	end
	busy += 1
	h.token += 1
	local token = h.token
	h.state = "loading"
	task.spawn(function()
		local ok = pcall(show, h, shape, token)
		if not ok and h.token == token then
			-- this look stays rigid (another may still fold)
			busy -= 1
			h.state = "failed"
		end
	end)
end

-- The share (0..1) of the keyed fold the look draws now; a dying look (`dying`) starts folding here.
function MeshFold.share(h: Handle, dying: boolean): number
	if dying and h.state == "idle" then
		begin(h)
	end
	if h.state ~= "live" then
		return 0
	end
	return math.clamp((os.clock() - h.liveAt) / RAMP, 0, 1)
end

-- The boxes of the folded mesh while it is drawn (Logic/RigidMotion `body.folds`), else nil.
function MeshFold.folds(h: Handle): { RigidMotion.Fold }?
	return if h.state == "live" then h.folds else nil
end

-- Writes the legs folded by `fold` (Logic/RigidMotion's posed.fold).
function MeshFold.write(h: Handle, fold: number)
	if h.state ~= "live" then
		return
	end
	local now = os.clock()
	if fold == 0 then
		h.quietSince = h.quietSince or now
		if now - (h.quietSince :: number) > QUIET and h.original then
			MeshFold.release(h)
			return
		end
	else
		h.quietSince = nil
	end
	if math.abs(fold - h.lastFold) < FOLD_STEP or now - h.lastWrite < WRITE_EVERY then
		return
	end
	local em = h.em
	local shape = shapes[h.key]
	local planned = shape and shape.plan
	if not em or not planned then
		return
	end
	h.lastFold, h.lastWrite = fold, now
	local out, values = h.out, h.values
	LegFold.pose(planned, fold, h.seed, h.map, out, h.angles)
	for j = 1, #values do
		values[j] = Vector3.new(out[j * 3 - 2], out[j * 3 - 1], out[j * 3])
	end
	local ok = pcall(setValues, em, h.ids, values, false)
	if not ok then
		MeshFold.release(h)
		h.state = "failed"
		return
	end
	local normalIds = h.normalIds
	if #normalIds > 0 then
		local rest, of, angles, nv = h.normalRest, h.normalOf, h.angles, h.normalValues
		local m = h.map
		local r = shape.ratio
		for k = 1, #normalIds do
			local j = of[k]
			local x, y, z =
				LegFold.turn(planned, planned.leg[j], angles[j], rest[k * 3 - 2], rest[k * 3 - 1], rest[k * 3])
			-- back to the mesh: the map's rotation, the shape correction the other way (normals)
			local mx = (m[1] * x + m[2] * y + m[3] * z) * r.X * r.X
			local my = (m[4] * x + m[5] * y + m[6] * z) * r.Y * r.Y
			local mz = (m[7] * x + m[8] * y + m[9] * z) * r.Z * r.Z
			nv[k] = Vector3.new(mx, my, mz).Unit
		end
		if not pcall(setValues, em, normalIds, nv, true) then
			table.clear(normalIds)
		end
	end
end

return MeshFold
