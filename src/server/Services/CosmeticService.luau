--!strict
-- Cosmetics on characters (DESIGN §22): the account's equipped outfit, aura, trail and weapon effect are
-- applied to every spawned character model (Util/CosmeticLook; re-applied when the weapon model changes),
-- and the equipped pet is spawned in Workspace.VaelthornPets with attribute OwnerId. Pets are anchored
-- and never move on the server; every client moves all pets smoothly behind their owners (PetController).
-- S97: Grant (boss drops, quest rewards) and the mount skin slot ("mountskin": nothing on the character, the ridden
-- mount is rebuilt through MountService.RefreshLook; MountService depends on this service, so it is taken lazily).
-- S121: saved looks (Garderoba+, DESIGN-17 §2): account.outfits is an array 1..n without holes; OutfitSave stores the
-- current look, OutfitWear puts on what the account still owns (Logic/Premium.outfitLooks). Products.OUTFITS_FREE
-- looks without the pass, OUTFITS_PLUS with it; looks above the limit stay saved but cannot be worn.
-- S123 (DESIGN-17 §4): dye, frame, chatframe and levelup slots in account.cosmetics.equipped like the outfit; the
-- dye recolours the worn outfit (CosmeticLook.applyDye inside applyAll). The frame, chat frame and level-up effect
-- are mirrored as player attributes CosmeticFrame, CosmeticChatFrame, CosmeticLevelUp (on the Player, so they outlive
-- respawns and exist before the first model) for the HUD portrait, chat lines and bubbles and the level-up effect of
-- every client. Emotes and titles have no slot (EmoteService, SetTitle). A bought title owned or taken refreshes the
-- shown title (TitleService, taken lazily: it is never needed during Init).

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
	Deps = { "DataService", "PlayerStateService", "CharacterService", "MonetizationService" }, -- S121: Garderoba+
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local MonetizationService: any
local Registry: any
local MountService: any
local TitleService: any

-- Lazy: MountService depends on this service (RollBossDrop), so a Deps entry here would be a cycle. Never call during
-- Init.
local function mountService(): any
	MountService = MountService or Registry.Get("MountService")
	return MountService
end

-- Lazy (S123): TitleService -> PathService pulls in many services; only a bought title needs it, never during Init.
local function titleService(): any
	TitleService = TitleService or Registry.Get("TitleService")
	return TitleService
end

-- S123: equipped slots mirrored as player attributes (nil = none).
local ATTRIBUTES: { [string]: string } = {
	frame = "CosmeticFrame",
	chatframe = "CosmeticChatFrame",
	levelup = "CosmeticLevelUp",
}

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
	pet.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	pet:PivotTo(root.CFrame * CFrame.new(2.5, 0, 2.5))
	pet.Parent = petFolder
	pets[player] = pet
end

local function publishAttributes(player: Player)
	local data = account(player)
	for kind, attribute in ATTRIBUTES do
		local id = data and data.cosmetics.equipped[kind]
		local def = if type(id) == "string" then Cosmetics.get(id) else nil
		player:SetAttribute(attribute, if def and def.kind == kind then def.id else nil)
	end
end

local function applyLook(player: Player)
	publishAttributes(player)
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
	-- S123: emotes and titles have no slot (canEquip refuses them); dye, frame, chatframe, levelup are slots
	local ok, err = Premium.canEquip(kind, id, owned)
	if not ok then
		return false, err
	end
	if kind == "pet" then
		PlayerStateService.Set(player, { "account", "pets", "equipped" }, id)
		spawnPet(player)
	elseif kind == "mountskin" then
		PlayerStateService.Set(player, { "account", "cosmetics", "equipped", kind }, id)
		mountService().RefreshLook(player)
	else
		PlayerStateService.Set(player, { "account", "cosmetics", "equipped", kind }, id)
		applyLook(player)
	end
	return true, nil
end

-- Gives one cosmetic to the account (boss drops, quest rewards). False for an unknown or already owned id.
-- S121: `toastKey` replaces cosmetic.got (the VIP cosmetic of the month says so); args { name }.
function CosmeticService.Grant(player: Player, id: string, toastKey: string?): boolean
	local def = Cosmetics.get(id)
	local data = account(player)
	if not def or not data then
		return false
	end
	local branch = if def.kind == "pet" then "pets" else "cosmetics"
	local owned = if def.kind == "pet" then data.pets.owned else data.cosmetics.owned
	if owned[id] then
		return false
	end
	PlayerStateService.Set(player, { "account", branch, "owned", id }, true)
	Net.Fire(player, "Toast", toastKey or "cosmetic.got", { name = `@{def.nameKey}` }, "success")
	DataService.Save(player)
	CosmeticService.OwnedChanged(player, id)
	return true
end

-- S123: after a cosmetic was given or taken (purchase, Grant, admin): a bought title chosen on the character shows
-- or hides at once.
function CosmeticService.OwnedChanged(player: Player, id: string)
	local def = Cosmetics.get(id)
	if def and def.kind == "title" then
		titleService().Refresh(player)
	end
end

-- S123 (admin /cosmetic take): the account no longer owns `id`; worn, it comes off. False when not owned (a free one
-- can never be taken).
function CosmeticService.Take(player: Player, id: string): boolean
	local def = Cosmetics.get(id)
	local data = account(player)
	if not def or not data or def.free == true then
		return false
	end
	local isPet = def.kind == "pet"
	local owned = if isPet then data.pets.owned else data.cosmetics.owned
	if owned[id] ~= true then
		return false
	end
	PlayerStateService.Set(player, { "account", if isPet then "pets" else "cosmetics", "owned", id }, nil)
	if isPet and data.pets.equipped == id then
		PlayerStateService.Set(player, { "account", "pets", "equipped" }, nil)
		spawnPet(player)
	elseif not isPet and data.cosmetics.equipped[def.kind] == id then
		PlayerStateService.Set(player, { "account", "cosmetics", "equipped", def.kind }, nil)
		if def.kind == "mountskin" then
			mountService().RefreshLook(player)
		else
			applyLook(player)
		end
	end
	DataService.Save(player)
	CosmeticService.OwnedChanged(player, id)
	return true
end

-- S121: saves the current look as look `index` (1..Premium.outfitSlots).
local function saveOutfit(player: Player, index: number): (boolean, string?)
	local data = account(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if index < 1 or index > Premium.outfitSlots(MonetizationService.Passes(player)) then
		return false, "wardrobe.error.outfitLocked"
	end
	local outfits: { Types.Outfit } = {}
	for i = 1, math.max(index, #(data.outfits or {})) do
		local saved = data.outfits and data.outfits[i]
		outfits[i] = if type(saved) == "table" then saved else { equipped = {} }
	end
	outfits[index] = Premium.snapshotOutfit(data.cosmetics, data.pets)
	PlayerStateService.Set(player, { "account", "outfits" }, outfits)
	DataService.Save(player)
	Net.Fire(player, "Toast", "wardrobe.outfit.saved", { n = index }, "success")
	return true, nil
end

-- S121: puts on look `index`: only what the account still owns, the rest of each slot is taken off.
local function wearOutfit(player: Player, index: number): (boolean, string?)
	local data = account(player)
	if not data then
		return false, "error.wrongPhase"
	end
	local outfit = data.outfits and data.outfits[index]
	if index < 1 or index > Premium.outfitSlots(MonetizationService.Passes(player)) then
		return false, "wardrobe.error.outfitLocked"
	end
	if
		type(outfit) ~= "table"
		or type(outfit.equipped) ~= "table"
		or (next(outfit.equipped) == nil and outfit.pet == nil)
	then
		return false, "wardrobe.outfit.empty"
	end
	local looks, pet = Premium.outfitLooks(outfit, data.cosmetics.owned, data.pets.owned)
	local skinBefore = data.cosmetics.equipped.mountskin
	PlayerStateService.Set(player, { "account", "cosmetics", "equipped" }, looks)
	PlayerStateService.Set(player, { "account", "pets", "equipped" }, pet)
	applyLook(player)
	spawnPet(player)
	if looks.mountskin ~= skinBefore then
		mountService().RefreshLook(player)
	end
	Net.Fire(player, "Toast", "wardrobe.outfit.worn", nil, "success")
	return true, nil
end

-- Admin: owns every cosmetic and pet (S123: free ones are owned anyway; bought titles too, so the picker shows them).
function CosmeticService.GrantAll(player: Player)
	for _, def in Cosmetics.list do
		if def.free ~= true then
			PlayerStateService.Set(
				player,
				{ "account", if def.kind == "pet" then "pets" else "cosmetics", "owned", def.id },
				true
			)
		end
	end
	titleService().Refresh(player)
end

function CosmeticService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	MonetizationService = registry.Get("MonetizationService")
end

function CosmeticService.Start()
	petFolder = Instance.new("Folder")
	petFolder.Name = "VaelthornPets"
	petFolder.Parent = Workspace

	Net.Handle("CosmeticEquip", equip)
	Net.Handle("OutfitSave", saveOutfit)
	Net.Handle("OutfitWear", wearOutfit)
	CharacterService.ModelSpawned:Connect(onModel)
	CharacterService.CharacterLeaving:Connect(removePet)
	-- S123: the frame / chat frame / level-up attributes exist before the first character model
	PlayerStateService.Ready:Connect(publishAttributes)
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
