--!strict
-- NPC animation (owner 2026-10-26: "after the monster animations, the NPCs": alive, believable, varied, never
-- robotic). Every NPC figure of World.Npcs moves on the biped template (Logic/NpcMotion through Anim/NpcRig): the
-- owner's models (Tripo Auto Rig Biped, Mixamo bones, no clips) and the R15 figures in their outfits alike.
-- * Its role's character (Data/NpcStyles: a guard upright, a merchant easy, an elder stooped; the NPC's own seed
--   picks its timing and choices), its work (the smith's blows, the merchant's stall behind him, the innkeeper's rag,
--   Teodor's channelling...), fidgets, a greeting for a player coming close, the look following players near;
-- * while this player's dialogue (or a service window) with it is open: it turns to the player, stepping, talks with
--   its hands and points along the tracked quest's way (QuestTrack.Target: the place, its NPC, or the next portal
--   of the route), and goes back to its work after.
-- * Model attributes (on the NPC or its "Asset"): "Work" = "none" (no work loop), a role's id or "hammer" (that
--   role's work); "NpcRole" = a role of Data/NpcStyles for the whole NPC.
-- Only NPCs within the graphics level's `npcRadius` of the camera move, `npcRate` times a second (Config.Graphics,
-- W29), at most the `npcMax` nearest (W31); farther ones keep their last pose. The one in the dialogue always moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.UI.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NpcMotion = require(ReplicatedStorage.Shared.Logic.NpcMotion)
local NpcRig = require(script.Parent.Parent.Anim.NpcRig)
local NpcStyles = require(ReplicatedStorage.Shared.Data.NpcStyles)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestTrack = require(script.Parent.Parent.UI.QuestTrack)
local State = require(script.Parent.Parent.UI.State)

local NpcAnimController = {
	Name = "NpcAnimController",
	Deps = { "NpcController" },
}

-- Seconds between two checks of the distance to the camera.
local CULL_EVERY = 0.5
-- Studs within which players are handed to an NPC's motion (to look at, to greet).
local PEOPLE_RANGE = 22
-- Seconds between two resolutions of the quest's way while talking.
local POINT_EVERY = 1
-- The quest's way is pointed at only when its place is at least this far (studs).
local POINT_FROM = 10
-- A player's eyes over the root part (studs) when the character has no head.
local EYES = 1.6

type Player_ = { id: number, at: Vector3, me: boolean }
type Entry = {
	model: Model,
	root: BasePart,
	rig: NpcRig.Rig,
	npcId: string,
	work: boolean, -- false: the model's "Work" is "none"
	near: boolean,
	wait: number, -- seconds until the next pose update
	people: { NpcMotion.Person }, -- reused every update
	input: NpcMotion.Input,
	moved: { number },
	lastRoot: CFrame,
	pointAt: number,
	point: { number }?,
}

local NpcController: any = nil
local entries: { [Model]: Entry } = {}
local players: { Player_ } = {}

local function seedOf(npcId: string): number
	local h = 0
	for i = 1, #npcId do
		h = (h * 31 + string.byte(npcId, i)) % 1000
	end
	return h / 1000
end

-- The model's attribute `name`, on its owner's model first.
local function attribute(model: Model, asset: Model?, name: string): any
	local value = if asset then asset:GetAttribute(name) else nil
	if value == nil then
		value = model:GetAttribute(name)
	end
	return value
end

-- The rig of an NPC model: the owner's model's bones or the R15 figure's joints; nil for the quest board and a figure
-- without its joints. Yields while the model's parts arrive.
local function rigOf(model: Model, npcId: string, seed: number): (NpcRig.Rig?, boolean)
	local def = Npcs.get(npcId)
	local asset: Model? = nil
	if model:GetAttribute("NpcAsset") == true then
		local found = model:WaitForChild("Asset", 10)
		if not found or not found:IsA("Model") then
			return nil, true
		end
		asset = found
	elseif not model:FindFirstChildOfClass("Humanoid") or not model:WaitForChild("RightHand", 10) then
		return nil, true
	end
	local role = attribute(model, asset, "NpcRole")
	local work = attribute(model, asset, "Work")
	local style =
		NpcStyles.of(npcId, if def then def.services :: any else nil, if type(role) == "string" then role else nil)
	style = NpcStyles.withWork(style, if type(work) == "string" then work else nil)
	local rig = if asset then NpcRig.new(model, asset, npcId, style, seed) else NpcRig.newR15(model, npcId, style, seed)
	if rig then
		NpcRig.addProps(rig, model, npcId)
	end
	return rig, work ~= "none"
end

local function track(model: Model)
	if entries[model] then
		return
	end
	local npcId = model:GetAttribute("NpcId")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if type(npcId) ~= "string" or not root then
		return
	end
	local seed = seedOf(npcId)
	local rig, work = rigOf(model, npcId, seed)
	if not rig or entries[model] or not model.Parent then
		return
	end
	local entry: Entry = {
		model = model,
		root = root,
		rig = rig,
		npcId = npcId,
		work = work,
		near = false,
		wait = 0,
		people = {},
		input = { now = 0, dt = 0 },
		moved = { 0, 0, 0 },
		lastRoot = root.CFrame,
		pointAt = -math.huge,
		point = nil,
	}
	entries[model] = entry
	-- its stance right away, even out of range
	NpcRig.apply(rig, NpcMotion.step(rig.motion, { now = os.clock(), dt = 0, snap = true, work = work }))
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

-- Marks the NPCs that move: within `radius` studs of the camera, the `most` nearest of them.
local function cull(radius: number, most: number)
	local camera = Workspace.CurrentCamera
	local at = if camera then camera.Focus.Position else Vector3.zero
	local inside: { { entry: Entry, distance: number } } = {}
	for _, entry in entries do
		local distance = (entry.root.Position - at).Magnitude
		entry.near = distance <= radius
		if entry.near then
			table.insert(inside, { entry = entry, distance = distance })
		end
	end
	if #inside > most then
		table.sort(inside, function(a, b)
			return a.distance < b.distance
		end)
		for i = most + 1, #inside do
			inside[i].entry.near = false
		end
	end
end

-- The players' eyes this frame (the list is reused).
local function gatherPlayers()
	local me = Players.LocalPlayer
	local n = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local at = if head then head.Position elseif root then root.Position + Vector3.new(0, EYES, 0) else nil
		if at then
			n += 1
			local row = players[n]
			if not row then
				row = { id = 0, at = at, me = false }
				players[n] = row
			end
			row.id, row.at, row.me = player.UserId, at, player == me
		end
	end
	for i = #players, n + 1, -1 do
		players[i] = nil
	end
end

-- The tracked quest's way from the NPC (a unit direction in its motion's space), nil without one or when it is here.
local function questPoint(entry: Entry, frame: CFrame): { number }?
	local target = Fusion.peek(QuestTrack.Target)
	if not target or target.npc == entry.npcId then
		return nil
	end
	local mapId = State.Get({ "character", "location", "map" })
	local here = Maps.get(if type(mapId) == "string" then mapId else "")
	if not here then
		return nil
	end
	local offset = Vector3.new(here.offset.x, here.offset.y, here.offset.z)
	local goal: Vector3? = nil
	if target.map ~= here.id then
		local exit = MapRoute.nextExit(here.id, target.map, MapSketch.isBuilt)
		goal = if exit then offset + Vector3.new(exit.x, 0, exit.z) else nil
	elseif target.npc then
		local model = entry.model.Parent and entry.model.Parent:FindFirstChild(target.npc)
		if model and model:IsA("Model") then
			goal = model:GetPivot().Position
		else
			local def = Npcs.get(target.npc)
			goal = if def and def.map == here.id then offset + Vector3.new(def.position.x, 0, def.position.z) else nil
		end
	elseif target.x and target.z then
		goal = offset + Vector3.new(target.x, 0, target.z)
	end
	if not goal then
		return nil
	end
	local p = frame:PointToObjectSpace(goal)
	local d = math.sqrt(p.X * p.X + p.Z * p.Z)
	if d < POINT_FROM then
		return nil
	end
	return { p.X / d, 0, p.Z / d }
end

local function step(entry: Entry, dt: number, talkingTo: string?, now: number)
	local rig = entry.rig
	local frame = entry.root.CFrame * rig.space
	local input = entry.input
	-- the players near, in its space (the reused rows)
	local people = entry.people
	local n = 0
	local partner: { number }? = nil
	local talking = talkingTo == entry.npcId
	for _, p in players do
		local at = frame:PointToObjectSpace(p.at)
		if at.X * at.X + at.Z * at.Z <= PEOPLE_RANGE * PEOPLE_RANGE then
			n += 1
			local row = people[n]
			if not row then
				row = { id = 0, x = 0, y = 0, z = 0, me = false }
				people[n] = row
			end
			row.id, row.x, row.y, row.z, row.me = p.id, at.X, at.Y, at.Z, p.me
			if p.me and talking then
				partner = { at.X, at.Y, at.Z }
			end
		end
	end
	for i = #people, n + 1, -1 do
		people[i] = nil
	end
	input.now, input.dt = now, dt
	input.people = people
	input.talk = talking and partner ~= nil
	input.partner = partner
	input.work = if entry.work then nil else false
	if talking and now - entry.pointAt >= POINT_EVERY then
		entry.pointAt = now
		entry.point = questPoint(entry, frame)
	elseif not talking then
		entry.point = nil
	end
	input.point = entry.point
	-- a root the server moved: its own move since the last update (the planted feet stay in the world)
	local root = entry.root.CFrame
	if root ~= entry.lastRoot then
		local d = entry.lastRoot:ToObjectSpace(root)
		local look = d.LookVector
		local moved = entry.moved
		moved[1], moved[2], moved[3] = d.X, d.Z, math.atan2(-look.X, -look.Z)
		input.moved = moved
		entry.lastRoot = root
	else
		input.moved = nil
	end
	NpcRig.apply(rig, NpcMotion.step(rig.motion, input))
end

function NpcAnimController.Init(registry: any)
	NpcController = registry.Get("NpcController")
end

function NpcAnimController.Start()
	local function watch(folder: Instance)
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				task.spawn(track, child)
			end
		end
		folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				task.defer(track, child)
			end
		end)
	end
	task.spawn(function()
		local world = Workspace:WaitForChild("World")
		local folder = world:WaitForChild("Npcs", 60)
		if folder then
			watch(folder)
		end
	end)
	local cullTimer = CULL_EVERY
	RunService.Heartbeat:Connect(function(dt: number)
		if next(entries) == nil then
			return
		end
		local level = GraphicsLevel.get(State.Get({ "account", "settings", "quality" }))
		cullTimer += dt
		if cullTimer >= CULL_EVERY then
			cullTimer = 0
			cull(level.npcRadius, level.npcMax)
		end
		local period = 1 / math.max(1, level.npcRate)
		local talkingTo = NpcController.TalkingTo()
		local now = os.clock()
		local gathered = false
		for _, entry in entries do
			-- the NPC in the dialogue always moves (it is next to the player)
			if not entry.near and talkingTo ~= entry.npcId then
				continue
			end
			entry.wait -= dt
			if entry.wait > 0 then
				continue
			end
			local spent = period - entry.wait
			entry.wait = period
			if not gathered then
				gathered = true
				gatherPlayers()
			end
			step(entry, math.min(spent, 0.25), talkingTo, now)
		end
	end)
end

return NpcAnimController
