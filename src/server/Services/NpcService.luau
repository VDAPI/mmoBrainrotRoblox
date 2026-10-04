--!strict
-- City NPCs (Data/Npcs). Builds a simple R15 figure per NPC (default avatar coloured from the data, with a
-- coloured hat), anchored in place. Clients add the localized nameplate and the "Talk [E]" prompt
-- (NpcController); every service call on the server checks the distance with NpcService.Near.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Npcs = require(Shared.Data.Npcs)

local log = Log.new("NpcService")

local NpcService = {
	Name = "NpcService",
	Deps = { "WorldService" },
}

local TOLERANCE = 4

local positions: { [string]: Vector3 } = {}

local function worldPosition(def: Npcs.NpcDef): Vector3
	local map = Maps.get(def.map)
	local origin = if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else Vector3.zero
	return origin + Vector3.new(def.position.x, 0, def.position.z)
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
	npc:PivotTo(CFrame.new(position + Vector3.new(0, 1 + height, 0)) * CFrame.Angles(0, math.rad(def.facing), 0))
	npc:SetAttribute("NpcId", def.id)
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
		build(def, folder)
	end
	log:info("%d NPCs placed", #Npcs.list)
end

return NpcService
