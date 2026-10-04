--!strict
-- Teleport stones (DESIGN §13). Stone of Return: 5 s channel, interrupted by damage or moving, then a
-- teleport to the capital (the stone is consumed only on success). Map and Dungeon stones arrive with the
-- world maps (S08) and dungeons (S09). The channel replicates as state branch `travel` = { endsAt, duration }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local TravelService = {
	Name = "TravelService",
	Deps = { "PlayerStateService", "InventoryService", "ResourceService", "CharacterService", "DeathService" },
}

local CHANNEL_SECONDS = 5
local MOVE_LIMIT = 2.5

local PlayerStateService: any
local InventoryService: any
local ResourceService: any
local CharacterService: any
local DeathService: any

local tokens: { [Player]: number } = {}

local function interrupt(player: Player, notify: boolean)
	if tokens[player] then
		tokens[player] = (tokens[player] or 0) + 1
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "travel" }, nil)
		end
		if notify then
			Net.Fire(player, "Toast", "teleport.interrupted", nil, "warning")
		end
	end
end

-- Moves the character to a map's respawn point (also used by S08 portals and map stones).
function TravelService.TeleportToMap(player: Player, mapId: string)
	local model = player.Character
	if not model then
		return
	end
	model:PivotTo(DeathService.SpawnCFrame(mapId, nil))
	PlayerStateService.Set(player, { "character", "location", "map" }, mapId)
end

local function useStone(player: Player, _index: number, item: Types.ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	local target = def and def.use and def.use.target
	if target ~= "city" then
		return false, "teleport.soon"
	end
	if ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "error.wrongPhase"
	end
	local token = (tokens[player] or 0) + 1
	tokens[player] = token
	local start = root.Position
	PlayerStateService.Set(player, { "travel" }, {
		endsAt = Workspace:GetServerTimeNow() + CHANNEL_SECONDS,
		duration = CHANNEL_SECONDS,
	})
	Net.Fire(player, "Toast", "teleport.channel", nil, "info")
	task.spawn(function()
		local finish = os.clock() + CHANNEL_SECONDS
		while os.clock() < finish do
			task.wait(0.1)
			if tokens[player] ~= token then
				return
			end
			local current = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not current or (current.Position - start).Magnitude > MOVE_LIMIT or ResourceService.IsDead(player) then
				interrupt(player, true)
				return
			end
		end
		if tokens[player] ~= token then
			return
		end
		tokens[player] = token + 1
		PlayerStateService.Set(player, { "travel" }, nil)
		-- The stone may have moved; consume one by id.
		if InventoryService.Remove(player, item.id, 1) < 1 then
			return
		end
		TravelService.TeleportToMap(player, Config.StartingMap)
		Net.Fire(player, "Toast", "teleport.done", nil, "success")
	end)
	return true, nil
end

function TravelService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	ResourceService = registry.Get("ResourceService")
	CharacterService = registry.Get("CharacterService")
	DeathService = registry.Get("DeathService")
	InventoryService.UseHandlers.teleport = useStone
end

function TravelService.Start()
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 then
			interrupt(player, true)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		interrupt(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		tokens[player] = nil
	end)
end

return TravelService
