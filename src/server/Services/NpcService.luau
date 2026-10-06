--!strict
-- City NPCs (Data/Npcs). Builds a simple R15 figure per NPC (default avatar coloured from the data, with a
-- coloured hat), anchored in place. Clients add the localized nameplate and the "Talk [E]" prompt
-- (NpcController); every service call on the server checks the distance with NpcService.Near.
-- S21: in the city NPCs stand on the plan's terrain (TownTerrain.heightAt); `body = "board"` NPCs (the quest
-- board) get no figure, only an invisible anchored Head over the board model the city already has.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Npcs = require(Shared.Data.Npcs)
local TownTerrain = require(Shared.Logic.TownTerrain)

local log = Log.new("NpcService")

local NpcService = {
	Name = "NpcService",
	Deps = { "WorldService" },
}

local TOLERANCE = 4

local positions: { [string]: Vector3 } = {}

-- Ground point under the NPC: the terrain surface (the world is built in WorldService.Init, before Start);
-- without a hit the plan's height in the city (TownTerrain), y = 0 elsewhere.
local function worldPosition(def: Npcs.NpcDef): Vector3
	local map = Maps.get(def.map)
	local origin = if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else Vector3.zero
	local planned = if def.map == "city" then TownTerrain.heightAt(def.position.x, def.position.z) else 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local from = origin + Vector3.new(def.position.x, planned + 30, def.position.z)
	local hit = Workspace:Raycast(from, Vector3.new(0, -80, 0), params)
	local y = if hit then hit.Position.Y - origin.Y else planned
	return origin + Vector3.new(def.position.x, y, def.position.z)
end

-- Quest board (S21): an invisible anchored Head (nameplate, prompt and quest marker hang on it) about 5 studs
-- over the ground, inside the board model built by the city layout. No Humanoid.
local function buildBoard(def: Npcs.NpcDef, parent: Instance)
	local position = worldPosition(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(4, 3, 1)
	head.Transparency = 1
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(def.facing), 0)
	head.Parent = model
	model.PrimaryPart = head
	model:SetAttribute("NpcId", def.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent
	positions[def.id] = position
end

local function build(def: Npcs.NpcDef, parent: Instance)
	local description = Instance.new("HumanoidDescription")
	local body = Color3.fromHex(def.colors.body)
	local skin = Color3.fromHex("#C9A27E")
	description.HeadColor = skin
	description.LeftArmColor = body
	description.RightArmColor = body
	description.TorsoColor = body
	description.LeftLegColor = Color3.fromHex("#2F2F35")
	description.RightLegColor = Color3.fromHex("#2F2F35")

	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		log:warn("could not build NPC %s: %s", def.id, tostring(model))
		return
	end
	local npc = model :: Model
	npc.Name = def.id
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	-- Placeholder hat in the accent colour.
	local head = npc:FindFirstChild("Head") :: BasePart?
	if head then
		local hat = Instance.new("Part")
		hat.Name = "Hat"
		hat.Size = Vector3.new(1.4, 0.5, 1.4)
		hat.Color = Color3.fromHex(def.colors.accent)
		hat.Material = Enum.Material.Fabric
		hat.Anchored = true
		hat.CanCollide = false
		hat.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.2, 0)
		hat.Parent = npc
	end
	local position = worldPosition(def)
	local height = if root and humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	npc:PivotTo(CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, math.rad(def.facing), 0))
	npc:SetAttribute("NpcId", def.id)
	npc.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	npc.Parent = parent
	positions[def.id] = position
end

-- Whether the player stands close enough to the NPC to use it.
function NpcService.Near(player: Player, npcId: string): boolean
	local position = positions[npcId]
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not position or not root then
		return false
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Npcs.INTERACT_RANGE + TOLERANCE
end

-- NPC id the player is near that offers `service` (and, for shops, `shopId`), or nil.
function NpcService.NearService(player: Player, service: string, shopId: string?): string?
	for _, def in Npcs.list do
		if
			table.find(def.services, service :: any)
			and (shopId == nil or def.shop == shopId)
			and NpcService.Near(player, def.id)
		then
			return def.id
		end
	end
	return nil
end

function NpcService.Position(npcId: string): Vector3?
	return positions[npcId]
end

function NpcService.Start()
	local world = Workspace:WaitForChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = world
	for _, def in Npcs.list do
		if def.body == "board" then
			buildBoard(def, folder)
		else
			build(def, folder)
		end
	end
	log:info("%d NPCs placed", #Npcs.list)
end

return NpcService
