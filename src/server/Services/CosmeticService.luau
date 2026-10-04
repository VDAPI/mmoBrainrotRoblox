--!strict
-- Cosmetics on characters (DESIGN §22): the account's equipped outfit, aura, trail and weapon effect are
-- applied to every spawned character model (Util/CosmeticLook; re-applied when the weapon model changes),
-- and the equipped pet is spawned in Workspace.VaelthornPets with attribute OwnerId. Pets are anchored
-- and never move on the server; every client moves all pets smoothly behind their owners (PetController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local CosmeticLook = require(Shared.Util.CosmeticLook)
local Cosmetics = require(Shared.Data.Cosmetics)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local Types = require(Shared.Types)

local CosmeticService = {
	Name = "CosmeticService",
	Deps = { "DataService", "PlayerStateService", "CharacterService" },
}

local DataService: any
local PlayerStateService: any
local CharacterService: any

local petFolder: Folder
local pets: { [Player]: Model } = {}
local weaponWatch: { [Player]: RBXScriptConnection } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

local function removePet(player: Player)
	local pet = pets[player]
	pets[player] = nil
	if pet then
		pet:Destroy()
	end
end

local function spawnPet(player: Player)
	removePet(player)
	local data = account(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local id = data and data.pets.equipped
	if not id or not root then
		return
	end
	local pet = CosmeticLook.buildPet(id)
	if not pet then
		return
	end
	pet.Name = `Pet_{player.UserId}`
	pet:SetAttribute("OwnerId", player.UserId)
	pet:SetAttribute("PetId", id)
	pet:PivotTo(root.CFrame * CFrame.new(2.5, 0, 2.5))
	pet.Parent = petFolder
	pets[player] = pet
end

local function applyLook(player: Player)
	local data = account(player)
	local model = player.Character
	if not data or not model then
		return
	end
	CosmeticLook.applyAll(model, data.cosmetics.equipped)
end

local function onModel(player: Player, model: Model)
	applyLook(player)
	spawnPet(player)
	local old = weaponWatch[player]
	if old then
		old:Disconnect()
	end
	weaponWatch[player] = model.DescendantAdded:Connect(function(child)
		if child.Name == "VaelthornWeapon" then
			task.defer(function()
				local data = account(player)
				if data and player.Character == model then
					CosmeticLook.applyWeapon(model, data.cosmetics.equipped.weapon)
				end
			end)
		end
	end)
end

local function equip(player: Player, kind: string, id: string?): (boolean, string?)
	local data = account(player)
	if not data then
		return false, "error.wrongPhase"
	end
	local owned = if kind == "pet" then data.pets.owned else data.cosmetics.owned
	local ok, err = Premium.canEquip(kind, id, owned)
	if not ok then
		return false, err
	end
	if kind == "pet" then
		PlayerStateService.Set(player, { "account", "pets", "equipped" }, id)
		spawnPet(player)
	else
		PlayerStateService.Set(player, { "account", "cosmetics", "equipped", kind }, id)
		applyLook(player)
	end
	return true, nil
end

-- Admin: owns every cosmetic and pet.
function CosmeticService.GrantAll(player: Player)
	for _, def in Cosmetics.list do
		PlayerStateService.Set(
			player,
			{ "account", if def.kind == "pet" then "pets" else "cosmetics", "owned", def.id },
			true
		)
	end
end

function CosmeticService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
end

function CosmeticService.Start()
	petFolder = Instance.new("Folder")
	petFolder.Name = "VaelthornPets"
	petFolder.Parent = Workspace

	Net.Handle("CosmeticEquip", equip)
	CharacterService.ModelSpawned:Connect(onModel)
	CharacterService.CharacterLeaving:Connect(removePet)
	Players.PlayerRemoving:Connect(function(player)
		removePet(player)
		local watch = weaponWatch[player]
		weaponWatch[player] = nil
		if watch then
			watch:Disconnect()
		end
	end)
end

return CosmeticService
