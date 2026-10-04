--!strict
-- Gathering (DESIGN §12): ore veins and herb bushes built from Data/GatherNodes as models tagged
-- "GatherNode" (attributes Kind, Uid, Available). StartGather checks distance, tool and that nobody else is
-- gathering the node, then holds for the node's time on the server (state branch `gather` = { endsAt,
-- duration, kind } drives the client bar). Moving > 3 studs or taking damage interrupts. Loot goes to the
-- backpack, the node hides and respawns after its timer (per server). Fishing spots are nodes too
-- (FishingService runs their minigame).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local GatherNodes = require(Shared.Data.GatherNodes)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)

local GatherService = {
	Name = "GatherService",
	Deps = { "PlayerStateService", "InventoryService", "ResourceService", "CharacterService", "WorldService" },
}

local TAG = "GatherNode"
local FLOOR_TOP = 1

export type Node = {
	uid: string,
	kind: GatherNodes.NodeKind,
	position: Vector3,
	model: Model,
	available: boolean,
	busyBy: Player?,
}

local PlayerStateService: any
local InventoryService: any
local ResourceService: any
local CharacterService: any
local WorldService: any

local rng = Rng.new()
local nodes: { [string]: Node } = {}
-- Active gathering per player: node uid + token for interrupting.
local active: { [Player]: { uid: string, token: number } } = {}
local tokenCounter = 0

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function setVisible(node: Node, visible: boolean)
	node.available = visible
	node.model:SetAttribute("Available", visible)
	for _, part in node.model:GetDescendants() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("BaseTransparency")
			part.Transparency = if visible then (if type(base) == "number" then base else 0) else 1
			part.CanCollide = visible and part:GetAttribute("Solid") == true
		end
	end
end

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p:SetAttribute("BaseTransparency", p.Transparency)
	p:SetAttribute("Solid", p.CanCollide)
	p.Parent = model
	return p
end

-- Placeholder looks: rock with coloured ore chunks, bush with flowers, pond.
local function buildModel(kind: GatherNodes.NodeKind, at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = kind.id
	local color = Color3.fromHex(kind.look.color)
	local accent = Color3.fromHex(kind.look.accent)
	if kind.look.shape == "rock" then
		local rock = part(model, {
			Name = "Rock",
			Size = Vector3.new(6, 4.5, 5),
			CFrame = CFrame.new(at + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, math.rad(rng:int(0, 90)), 0.15),
			Color = color,
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
		model.PrimaryPart = rock
		for i = 1, 4 do
			local angle = i * math.pi / 2 + rng:float(0, 0.6)
			part(model, {
				Name = "Ore",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.4, 1.4, 1.4),
				CFrame = CFrame.new(
					at + Vector3.new(math.cos(angle) * 2.6, 2 + rng:float(0, 2), math.sin(angle) * 2.2)
				),
				Color = accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	elseif kind.look.shape == "bush" then
		local bush = part(model, {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4.5, 3.5, 4.5),
			CFrame = CFrame.new(at + Vector3.new(0, 1.6, 0)),
			Color = color,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
		model.PrimaryPart = bush
		for i = 1, 6 do
			local angle = i * math.pi / 3
			part(model, {
				Name = "Flower",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.8, 0.8, 0.8),
				CFrame = CFrame.new(
					at + Vector3.new(math.cos(angle) * 1.8, 2.6 + rng:float(0, 0.8), math.sin(angle) * 1.8)
				),
				Color = accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	else
		-- Fishing spot marker at the water's edge (the layout provides the lake): sign post and buoys.
		local post = part(model, {
			Name = "Post",
			Size = Vector3.new(0.6, 6, 0.6),
			CFrame = CFrame.new(at + Vector3.new(0, 3, 0)),
			Color = Color3.fromHex("#5A4632"),
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
		model.PrimaryPart = post
		part(model, {
			Name = "Sign",
			Size = Vector3.new(3, 1.6, 0.3),
			CFrame = CFrame.new(at + Vector3.new(0, 5.4, 0)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
		})
		for i = 1, 3 do
			local angle = i * 2.1
			part(model, {
				Name = "Buoy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1),
				CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 9, -0.2, 8 + math.sin(angle) * 5)),
				Color = accent,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		end
	end
	return model
end

-- Ground below a map point (terrain and map geometry; starts low so cave roofs are not hit).
local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(position + Vector3.new(0, 14, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else position + Vector3.new(0, FLOOR_TOP, 0)
end

function GatherService.Spawn(kindId: string, mapId: string, x: number, z: number): Node?
	local kind = GatherNodes.get(kindId)
	local map = Maps.get(mapId)
	if not kind or not map then
		return nil
	end
	local folder = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("GatherNodes")
	if not folder then
		return nil
	end
	local at = groundAt(Vector3.new(map.offset.x + x, map.offset.y, map.offset.z + z))
	local uid = HttpService:GenerateGUID(false)
	local model = buildModel(kind, at)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Kind", kind.id)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("Available", true)
	CollectionService:AddTag(model, TAG)
	model.Parent = folder
	local node: Node = { uid = uid, kind = kind, position = at, model = model, available = true }
	nodes[uid] = node
	return node
end

function GatherService.Get(uid: string): Node?
	return nodes[uid]
end

-- Distance from the player to the node, in studs (math.huge without a character).
function GatherService.Distance(player: Player, node: Node): number
	local root = rootOf(player)
	if not root then
		return math.huge
	end
	local offset = root.Position - node.position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude
end

-- Range check that accounts for the pond size of fishing spots.
function GatherService.InRange(player: Player, node: Node): boolean
	local range = GatherNodes.RANGE + (if node.kind.category == "fishing" then 14 else 2)
	return GatherService.Distance(player, node) <= range
end

local function stop(player: Player, notify: boolean)
	local current = active[player]
	if not current then
		return
	end
	active[player] = nil
	local node = nodes[current.uid]
	if node and node.busyBy == player then
		node.busyBy = nil
	end
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "gather" }, nil)
	end
	if notify then
		Net.Fire(player, "Toast", "gather.interrupted", nil, "warning")
	end
end

function GatherService.Busy(player: Player): boolean
	return active[player] ~= nil
end

local function rollLoot(node: Node): { { id: string, n: number } }
	local result = {}
	for _, entry in node.kind.loot do
		if rng:chance(entry.chance) then
			table.insert(result, { id = entry.id, n = rng:int(entry.min, entry.max) })
		end
	end
	return result
end

local function finish(player: Player, node: Node)
	local loot = rollLoot(node)
	local stacks = {}
	for _, drop in loot do
		table.insert(stacks, ItemRoll.makeStack(drop.id, drop.n, "check"))
	end
	if not InventoryService.CanFit(player, stacks) then
		Net.Fire(player, "Toast", "inventory.full", nil, "error")
		return
	end
	for _, drop in loot do
		InventoryService.GiveNew(player, drop.id, drop.n)
		Net.Fire(player, "Toast", "gather.got", { name = `#item:{drop.id}:0`, n = drop.n }, "success")
	end
	setVisible(node, false)
	task.delay(node.kind.respawn, function()
		if nodes[node.uid] == node then
			setVisible(node, true)
		end
	end)
end

local function startGather(player: Player, uid: string): (boolean, string?, number?)
	local node = nodes[uid]
	if not node or node.kind.category == "fishing" then
		return false, "error.badRequest"
	end
	if not PlayerStateService.GetCharacter(player) or ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	if not node.available then
		return false, "gather.depleted"
	end
	if node.busyBy and node.busyBy ~= player then
		return false, "gather.busy"
	end
	if active[player] then
		return false, "gather.already"
	end
	if not GatherService.InRange(player, node) then
		return false, "npc.error.tooFar"
	end
	local tool = node.kind.tool
	if tool and InventoryService.Count(player, tool) < 1 then
		return false, `gather.needTool.{tool}`
	end
	local root = rootOf(player)
	if not root then
		return false, "error.wrongPhase"
	end
	tokenCounter += 1
	local token = tokenCounter
	active[player] = { uid = uid, token = token }
	node.busyBy = player
	local duration = node.kind.time
	PlayerStateService.Set(player, { "gather" }, {
		endsAt = Workspace:GetServerTimeNow() + duration,
		duration = duration,
		kind = node.kind.id,
		category = node.kind.category,
	})
	local start = root.Position
	task.spawn(function()
		local finishAt = os.clock() + duration
		while os.clock() < finishAt do
			task.wait(0.1)
			local current = active[player]
			if not current or current.token ~= token then
				return
			end
			local now = rootOf(player)
			if
				not now
				or ((now.Position - start) * Vector3.new(1, 0, 1)).Magnitude > GatherNodes.MOVE_LIMIT
				or ResourceService.IsDead(player)
			then
				stop(player, true)
				return
			end
		end
		local current = active[player]
		if not current or current.token ~= token then
			return
		end
		stop(player, false)
		if node.available then
			finish(player, node)
		end
	end)
	return true, nil, duration
end

-- Admin /nodes respawn.
function GatherService.RespawnAll(): number
	local count = 0
	for _, node in nodes do
		if not node.available then
			setVisible(node, true)
			count += 1
		end
	end
	return count
end

function GatherService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	ResourceService = registry.Get("ResourceService")
	CharacterService = registry.Get("CharacterService")
	WorldService = registry.Get("WorldService")
end

function GatherService.Start()
	local world = Workspace:WaitForChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "GatherNodes"
	folder.Parent = world
	for _, placement in WorldService.GetNodePlacements() do
		GatherService.Spawn(placement.kind, placement.map, placement.x, placement.z)
	end

	Net.Handle("StartGather", startGather)
	Net.On("CancelGather", function(player: Player)
		stop(player, false)
	end)
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 and active[player] then
			stop(player, true)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		stop(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stop(player, false)
	end)
end

return GatherService
