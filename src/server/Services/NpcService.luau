--!strict
-- City NPCs (Data/Npcs). Builds a simple R15 figure per NPC (default avatar coloured from the data, with a
-- coloured hat), anchored in place. Clients add the localized nameplate and the "Talk [E]" prompt
-- (NpcController); every service call on the server checks the distance with NpcService.Near.
-- S21: in the city NPCs stand on the plan's terrain (TownTerrain.heightAt); `body = "board"` NPCs (the quest
-- board) get no figure, only an invisible anchored Head over the board model the city already has.
-- S29: feet on the ground. The ground ray ignores NPCs and characters and stops on the top surface of the map's
-- own geometry (porch, stairs, paving; WorldService.FloorAt); after placing, the figure's real lowest corner
-- (Logic/Footing) is moved onto that ground and HipHeight is set to match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Npcs = require(Shared.Data.Npcs)
local Footing = require(Shared.Logic.Footing)
local MapTerrain = require(Shared.Logic.MapTerrain)

local log = Log.new("NpcService")

local NpcService = {
	Name = "NpcService",
	Deps = { "WorldService" },
}

local TOLERANCE = 4
-- The ground ray starts this far over the plan height: over a porch or stairs, under stall awnings and roofs.
local RAY_OVER_PLAN = 6
-- Lifts larger than this are reported once in the log (diagnostics for the owner).
local REPORT_LIFT = 0.3

local WorldService: any = nil

local positions: { [string]: Vector3 } = {}

-- Ground point under the NPC (the world is built in WorldService.Init, before Start): the top surface of the
-- terrain or the map's geometry under a ray from just over the plan height (Logic/MapTerrain: the city, S26 the
-- Meadows; y = 0 elsewhere). S29: NPCs and characters are ignored (WorldService.FloorAt), so a figure never
-- stands on another one.
local function worldPosition(def: Npcs.NpcDef): Vector3
	local map = Maps.get(def.map)
	if not map then
		return Vector3.new(def.position.x, 0, def.position.z)
	end
	local planned = MapTerrain.height(def.map, def.position.x, def.position.z)
	local fromY = if planned then planned + RAY_OVER_PLAN else nil
	return WorldService.FloorAt(def.map, def.position.x, def.position.z, fromY)
end

-- Every part that shapes the figure's silhouette, as Footing boxes: not the root part (it hangs at hip
-- height) and not accessory handles.
local function bodyBoxes(model: Model): { Footing.Box }
	local out: { Footing.Box } = {}
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then
			continue
		end
		if part.Parent and part.Parent:IsA("Accessory") then
			continue
		end
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
		local p, size = part.Position, part.Size
		table.insert(out, {
			p = { p.X, p.Y, p.Z },
			r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			size = { size.X, size.Y, size.Z },
		})
	end
	return out
end

-- Moves the placed figure so its lowest corner rests on groundY and makes HipHeight agree.
local function settle(npc: Model, def: Npcs.NpcDef, groundY: number)
	local dy = Footing.liftFor(bodyBoxes(npc), groundY)
	npc:PivotTo(npc:GetPivot() + Vector3.new(0, dy, 0))
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root then
		humanoid.HipHeight = Footing.hipHeight(root.Position.Y, root.Size.Y, groundY)
	end
	if math.abs(dy) > REPORT_LIFT then
		print(`[Npc] lift {def.id} {string.format("%.2f", dy)}`)
	end
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
	-- S25: always on every client (the world map clones NPCs for its 3D preview).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
	-- S25: Persistent (~15 light models) so the world map can clone any NPC for its 3D preview, even one on
	-- another map or out of the streaming radius.
	npc.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	npc.Parent = parent
	settle(npc, def, position.Y)
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

function NpcService.Init(registry: any)
	WorldService = registry.Get("WorldService")
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
