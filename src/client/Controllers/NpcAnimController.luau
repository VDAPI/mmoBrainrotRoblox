--!strict
-- W30: procedural animation of the owner's NPC models (Tripo Auto Rig Biped, Mixamo bones, no clips;
-- NpcService.Figure welds them as "Asset" and marks the NPC "NpcAsset"). Without it they would stand in the T-pose.
-- One rig per NPC model of World.Npcs (Anim/NpcRig, kept until the model leaves): on load the relaxed stance, then
-- breathing, weight shift and looks; while the player's dialogue (or a service window) with that NPC is open it turns
-- to face the player and gestures and nods; the smith hammers (model attribute "Work": "hammer" for any NPC, "none"
-- turns the smith's off). Only NPCs within the graphics level's `npcRadius` of the camera move, `npcRate` times a
-- second (Config.Graphics.levels, W29); farther ones keep their last pose.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local NpcPose = require(ReplicatedStorage.Shared.Logic.NpcPose)
local NpcRig = require(script.Parent.Parent.Anim.NpcRig)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.UI.State)

local NpcAnimController = {
	Name = "NpcAnimController",
	Deps = { "NpcController" },
}

-- Radians per second the body turns toward the player (and back to its own facing after the talk).
local TURN_RATE = 4
-- Seconds the talk gestures take to fade in and out.
local BLEND_TIME = 0.4
-- Seconds between two checks of the distance to the camera.
local CULL_EVERY = 0.5

type Entry = {
	model: Model,
	root: BasePart,
	rig: NpcRig.Rig,
	npcId: string,
	work: boolean,
	near: boolean,
	wait: number, -- seconds until the next pose update
	facing: number, -- current yaw of the body (Hips)
	blend: number, -- 0..1 talk gestures
	talkTime: number, -- seconds since the dialogue opened
}

local NpcController: any = nil
local entries: { [Model]: Entry } = {}

local function works(model: Model, npcId: string, asset: Model): boolean
	local work = asset:GetAttribute("Work")
	if work == nil then
		work = model:GetAttribute("Work")
	end
	if work == "hammer" then
		return true
	end
	if work == "none" then
		return false
	end
	local def = Npcs.get(npcId)
	return def ~= nil and table.find(def.services, "blacksmith" :: any) ~= nil
end

local function seedOf(npcId: string): number
	local h = 0
	for i = 1, #npcId do
		h = (h * 31 + string.byte(npcId, i)) % 1000
	end
	return h / 1000
end

local function track(model: Model)
	if entries[model] or model:GetAttribute("NpcAsset") ~= true then
		return
	end
	local npcId = model:GetAttribute("NpcId")
	local asset = model:WaitForChild("Asset", 10)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if type(npcId) ~= "string" or not asset or not asset:IsA("Model") or not root or not model.Parent then
		return
	end
	local seed = seedOf(npcId)
	local rig = NpcRig.new(model, asset, seed)
	if not rig or entries[model] then
		return
	end
	local entry: Entry = {
		model = model,
		root = root,
		rig = rig,
		npcId = npcId,
		work = works(model, npcId, asset),
		near = false,
		wait = 0,
		facing = 0,
		blend = 0,
		talkTime = 0,
	}
	entries[model] = entry
	-- the relaxed stance right away, even out of range
	NpcRig.apply(rig, NpcPose.frame(os.clock(), seed, if entry.work then "hammer" else "idle", 0, 0))
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			entries[model] = nil
		end
	end)
end

local function cull(radius: number)
	local camera = Workspace.CurrentCamera
	local at = if camera then camera.Focus.Position else Vector3.zero
	for _, entry in entries do
		entry.near = (entry.root.Position - at).Magnitude <= radius
	end
end

-- Yaw (in the NPC's root space) toward the local character, or nil without one.
local function yawToPlayer(entry: Entry): number?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local p = entry.root.CFrame:PointToObjectSpace(root.Position)
	return NpcPose.faceYaw(p.X, p.Z)
end

local function step(entry: Entry, dt: number, talkingTo: string?, now: number)
	local talking = talkingTo == entry.npcId
	if talking then
		entry.talkTime += dt
	end
	entry.blend = math.clamp(entry.blend + (if talking then dt else -dt) / BLEND_TIME, 0, 1)
	if not talking and entry.blend == 0 then
		entry.talkTime = 0
	end
	local target = if talking then yawToPlayer(entry) or 0 else 0
	entry.facing = NpcPose.turnToward(entry.facing, target, TURN_RATE, dt)
	local activity: NpcPose.Activity = if entry.blend > 0 then "talk" elseif entry.work then "hammer" else "idle"
	local t = if activity == "talk" then entry.talkTime else now
	NpcRig.apply(entry.rig, NpcPose.frame(t, entry.rig.seed, activity, entry.blend, entry.facing))
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
			cull(level.npcRadius)
		end
		local period = 1 / math.max(1, level.npcRate)
		local talkingTo = NpcController.TalkingTo()
		local now = os.clock()
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
			step(entry, math.min(spent, 0.25), talkingTo, now)
		end
	end)
end

return NpcAnimController
