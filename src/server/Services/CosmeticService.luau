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
-- dye recolours the worn outfit. The frame, chat frame and level-up effect are mirrored as player attributes
-- CosmeticFrame, CosmeticChatFrame, CosmeticLevelUp (on the Player, so they outlive respawns and exist before the first
-- model) for the HUD portrait, chat lines and bubbles and the level-up effect of every client. Emotes and titles have
-- no slot (EmoteService, SetTitle). A bought title owned or taken refreshes the shown title (TitleService, taken lazily:
-- it is never needed during Init).
-- S132 (DESIGN-17 §9a): class looks. The character spawns from a HumanoidDescription this service gives
-- CharacterService (SetDescriptionProvider): standard R15, the class look (face, skin, hair of character.look, the
-- class outfit of account.cosmetics.classOutfits[class]) or the player's Roblox avatar in standard proportions
-- (settings.robloxAvatar; the avatar's description cached per player). The procedural look is drawn over it
-- (Util/AvatarBuild, the dye already in Logic/CharacterLook.resolve); RefreshAppearance re-applies the description only
-- when a catalog id or the mode changed (model attribute VaelthornLookKey). SetCharacterLook: the free change, then gold
-- at the barber. Class outfits of a quest (GrantQuestOutfits) and of a boss win (GrantBossWin), given back on entering
-- the world when the save proves them. The mannequin of the client previews (ReplicatedStorage.VaelthornMannequin).

local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local AvatarBuild = require(Shared.Util.AvatarBuild)
local BodyLooks = require(Shared.Data.BodyLooks)
local CharacterLook = require(Shared.Logic.CharacterLook)
local ClassLooks = require(Shared.Data.ClassLooks)
local CosmeticLook = require(Shared.Util.CosmeticLook)
local Cosmetics = require(Shared.Data.Cosmetics)
local Log = require(Shared.Util.Log)
local LookBuild = require(Shared.Util.LookBuild)
local Lure = require(Shared.Logic.Lure)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local Quests = require(Shared.Data.Quests)
local Types = require(Shared.Types)

local log = Log.new("CosmeticService")

local CosmeticService = {
	Name = "CosmeticService",
	-- S121: Garderoba+ (MonetizationService); S132: the barber (NpcService depends only on WorldService)
	Deps = { "DataService", "PlayerStateService", "CharacterService", "MonetizationService", "NpcService" },
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local MonetizationService: any
local NpcService: any
local Registry: any
local MountService: any
local TitleService: any
local EquipmentService: any

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

-- Lazy (S132): the held models again after Humanoid:ApplyDescription (EquipmentService depends on CharacterService and
-- the item services; taken during play only).
local function equipmentService(): any
	EquipmentService = EquipmentService or Registry.Get("EquipmentService")
	return EquipmentService
end

-- S123: equipped slots mirrored as player attributes (nil = none).
local ATTRIBUTES: { [string]: string } = {
	frame = "CosmeticFrame",
	chatframe = "CosmeticChatFrame",
	levelup = "CosmeticLevelUp",
}

local petFolder: Folder
local pets: { [Player]: Model } = {}
local modelWatch: { [Player]: { RBXScriptConnection } } = {}

-- S132: the model attribute with the look key (mode + catalog ids) of the description the model wears.
local LOOK_KEY = "VaelthornLookKey"
-- the player's own description (false = Roblox refused it: the class look until the next attempt)
local avatars: { [Player]: HumanoidDescription | false } = {}
local fetching: { [Player]: boolean } = {}
local spawnKey: { [Player]: string } = {}
local busy: { [Player]: boolean } = {}
local again: { [Player]: boolean } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

-- A Roblox method by its new name (…Async) or its old one; nil when neither exists. Verify the Async variant in the
-- Roblox documentation (the old names are deprecated, not removed).
local function method(object: Instance, asyncName: string, oldName: string): ((...any) -> ...any)?
	for _, name in { asyncName, oldName } do
		local ok, fn = pcall(function()
			return (object :: any)[name]
		end)
		if ok and type(fn) == "function" then
			return fn
		end
	end
	return nil
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

-- S132: the player's own HumanoidDescription (cached; yields on the first call). Nil when Roblox refused it.
local function avatarOf(player: Player): HumanoidDescription?
	local cached = avatars[player]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: HumanoidDescription
	end
	if fetching[player] then
		while fetching[player] and player.Parent do
			task.wait(0.1)
		end
		local now = avatars[player]
		return if now == false or now == nil then nil else now :: HumanoidDescription
	end
	fetching[player] = true
	local fetch = method(Players, "GetHumanoidDescriptionFromUserIdAsync", "GetHumanoidDescriptionFromUserId")
	local ok, result = false, nil :: any
	if fetch then
		ok, result = pcall(fetch, Players, player.UserId)
	end
	fetching[player] = nil
	if not player.Parent then
		return nil
	end
	if ok and typeof(result) == "Instance" and result:IsA("HumanoidDescription") then
		avatars[player] = result
		return result
	end
	log:warn("no avatar description for %s (%s): class look", player.Name, tostring(result))
	avatars[player] = false
	return nil
end

-- S132: the look of the active character (`char`: the one being spawned). With the avatar switched on and the avatar's
-- description known, avatar mode; otherwise the class look.
local function specOf(player: Player, char: Types.CharacterData?): CharacterLook.LookSpec?
	local data = account(player)
	local c: Types.CharacterData? = char or PlayerStateService.GetCharacter(player)
	if not data or not c then
		return nil
	end
	local cached = avatars[player]
	local avatar = data.settings.robloxAvatar == true and cached ~= nil and cached ~= false
	return CharacterLook.resolve({
		classId = c.class,
		look = c.look,
		outfitId = CharacterLook.outfitOf(data, c.class),
		dye = data.cosmetics.equipped.dye,
		robloxAvatar = avatar,
		lure = Lure.active(data.lure, os.time()),
	})
end

local function keyOf(spec: CharacterLook.LookSpec): string
	return `{spec.mode}|{spec.catalogKey}`
end

-- S132: the description of the active character (fetches the avatar's first when the switch is on; may yield).
local function describe(player: Player, char: Types.CharacterData?): (HumanoidDescription?, CharacterLook.LookSpec?)
	local data = account(player)
	if data and data.settings.robloxAvatar == true then
		avatarOf(player)
	end
	local spec = specOf(player, char)
	if not spec then
		return nil, nil
	end
	local base = if spec.mode == "avatar" then avatarOf(player) else nil
	local ok, description = pcall(AvatarBuild.description, spec, base)
	if not ok then
		log:warn("description for %s failed: %s", player.Name, tostring(description))
		return nil, spec
	end
	return description, spec
end

local function applyLook(player: Player)
	publishAttributes(player)
	local data = account(player)
	local model = player.Character
	local spec = specOf(player)
	if not data or not model or not spec then
		return
	end
	-- S132: the class look (outfit and dye are in the spec), then the effects as before; never applyOutfit / applyDye
	AvatarBuild.applyProcedural(model, spec)
	CosmeticLook.applyEffects(model, data.cosmetics.equipped)
end

-- One refresh: the description when the look key changed (or the avatar is still unknown), then the procedural look.
local function refreshNow(player: Player)
	local model = player.Character
	local data = account(player)
	local spec = specOf(player)
	if not model or not spec or not data then
		return
	end
	local unknownAvatar = data.settings.robloxAvatar == true and avatars[player] == nil
	if model:GetAttribute(LOOK_KEY) ~= keyOf(spec) or unknownAvatar then
		local description, used = describe(player, nil)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if description and used and humanoid and player.Character == model then
			local mounts = mountService()
			-- a description resets HipHeight: off the mount and on again (the S97 RefreshLook way)
			local riding = mounts.IsRiding(player)
			if riding then
				mounts.Dismount(player, "look")
			end
			-- the procedural state off first, so the description lands on the model's own colours, clothes and face
			-- (otherwise the next applyLook restores the stale class colours and the parked face over it)
			AvatarBuild.clearProcedural(model)
			local apply = method(humanoid, "ApplyDescriptionAsync", "ApplyDescription")
			local applied, why = false, "no ApplyDescription" :: any
			if apply then
				applied, why = pcall(apply, humanoid, description)
			end
			if player.Character ~= model then
				return
			end
			if applied then
				model:SetAttribute(LOOK_KEY, keyOf(used))
			else
				log:warn("ApplyDescription for %s failed: %s", player.Name, tostring(why))
			end
			if riding then
				mounts.Ride(player, true)
			end
			-- D4: the held models (main hand and off hand) again when the description took them
			local char = PlayerStateService.GetCharacter(player)
			local equipment = if char then char.equipment :: any else nil
			if
				equipment
				and (
					(equipment.weapon and not model:FindFirstChild("VaelthornWeapon", true))
					or (equipment.offhand and not model:FindFirstChild("VaelthornOffhand", true))
				)
			then
				equipmentService().RefreshHeld(player)
			end
		end
	end
	applyLook(player)
end

-- S132: the appearance again after a change of outfit, look, the avatar switch or an admin command: the description
-- only when a catalog id or the mode changed, then the procedural look. One at a time per player; a change during a
-- running one runs once more after it.
function CosmeticService.RefreshAppearance(player: Player)
	if busy[player] then
		again[player] = true
		return
	end
	busy[player] = true
	task.spawn(function()
		repeat
			again[player] = nil
			local ok, err = pcall(refreshNow :: any, player)
			if not ok then
				log:warn("appearance of %s failed: %s", player.Name, tostring(err))
			end
		until not again[player] or not player.Parent
		busy[player] = nil
		again[player] = nil
	end)
end

local function watchModel(player: Player, model: Model)
	local old = modelWatch[player]
	if old then
		for _, connection in old do
			connection:Disconnect()
		end
	end
	local function relook(child: Instance)
		if child.Name == "VaelthornWeapon" then
			task.defer(function()
				local data = account(player)
				if data and player.Character == model then
					CosmeticLook.applyWeapon(model, data.cosmetics.equipped.weapon)
				end
			end)
		elseif child.Name == "VaelthornOffhand" then
			-- S132: a quiver from the equipment hides the procedural one (and brings it back when it goes)
			task.defer(function()
				if player.Character == model then
					applyLook(player)
				end
			end)
		end
	end
	modelWatch[player] = { model.DescendantAdded:Connect(relook), model.DescendantRemoving:Connect(relook) }
end

local function onModel(player: Player, model: Model, described: boolean?)
	-- the spawn key only counts when the model was really loaded from that description (a plain fallback keeps none)
	local key = if described then spawnKey[player] else nil
	spawnKey[player] = nil
	if key then
		model:SetAttribute(LOOK_KEY, key)
	end
	applyLook(player)
	spawnPet(player)
	watchModel(player, model)
	if not key then
		-- the description was refused at spawn (a plain character): one more try on the standing model
		CosmeticService.RefreshAppearance(player)
	end
end

local function equip(player: Player, kind: string, id: string?): (boolean, string?)
	local data = account(player)
	if not data then
		return false, "error.wrongPhase"
	end
	local owned = if kind == "pet" then data.pets.owned else data.cosmetics.owned
	-- S123: emotes and titles have no slot (canEquip refuses them); dye, frame, chatframe, levelup are slots.
	-- S132: an outfit is worn by the active character's class (account.cosmetics.classOutfits[class]; nil = the class
	-- look)
	local char = PlayerStateService.GetCharacter(player)
	local ok, err = Premium.canEquip(kind, id, owned, if char then char.class else nil)
	if not ok then
		return false, err
	end
	if kind == "outfit" and char then
		PlayerStateService.Set(player, { "account", "cosmetics", "classOutfits", char.class }, id)
		CosmeticService.RefreshAppearance(player)
	elseif kind == "pet" then
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
	elseif def.kind == "outfit" then
		-- S132: off every class that wore it
		local worn = false
		local wornBy: { [string]: string } = data.cosmetics.classOutfits or {}
		for classId, outfit in wornBy do
			if outfit == id then
				PlayerStateService.Set(player, { "account", "cosmetics", "classOutfits", classId }, nil)
				worn = true
			end
		end
		if worn then
			CosmeticService.RefreshAppearance(player)
		end
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
	-- S132: with the class outfit of the active character's class and the class it was saved on
	local char = PlayerStateService.GetCharacter(player)
	outfits[index] = Premium.snapshotOutfit(data.cosmetics, data.pets, if char then char.class else nil)
	PlayerStateService.Set(player, { "account", "outfits" }, outfits)
	DataService.Save(player)
	Net.Fire(player, "Toast", "wardrobe.outfit.saved", { n = index }, "success")
	return true, nil
end

-- S121: puts on look `index`: only what the account still owns, the rest of each slot is taken off.
-- S132: the outfit goes to the class of the active character (when allowed and owned), never into `equipped`.
local function wearOutfit(player: Player, index: number): (boolean, string?)
	local data = account(player)
	local char = PlayerStateService.GetCharacter(player)
	if not data or not char then
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
	local looks, pet, classOutfit = Premium.applySet(outfit, char.class, data.cosmetics.owned, data.pets.owned)
	local skinBefore = data.cosmetics.equipped.mountskin
	PlayerStateService.Set(player, { "account", "cosmetics", "equipped" }, looks)
	PlayerStateService.Set(player, { "account", "pets", "equipped" }, pet)
	if classOutfit then
		PlayerStateService.Set(player, { "account", "cosmetics", "classOutfits", char.class }, classOutfit)
	end
	CosmeticService.RefreshAppearance(player)
	spawnPet(player)
	if looks.mountskin ~= skinBefore then
		mountService().RefreshLook(player)
	end
	Net.Fire(player, "Toast", "wardrobe.outfit.worn", nil, "success")
	return true, nil
end

-- S132: the class outfits of the quest `questId` for a character of `classId` (obtain.quest); the number given.
function CosmeticService.GrantQuestOutfits(player: Player, questId: string, classId: string): number
	local n = 0
	for _, id in CharacterLook.questOutfits(questId, classId) do
		if CosmeticService.Grant(player, id) then
			n += 1
		end
	end
	return n
end

-- S132: the class outfits of a won boss for a winner of `classId` (obtain.bossWin; no roll); the number given.
function CosmeticService.GrantBossWin(player: Player, bossId: string, classId: string): number
	local n = 0
	for _, id in CharacterLook.bossWinOutfits(bossId, classId) do
		if CosmeticService.Grant(player, id) then
			n += 1
		end
	end
	return n
end

-- S132: what the save proves for good. A handed-in quest; a won boss = the story quest with that boss objective or the
-- S98 boss quest handed in (bossRuns counts only today and starts at the dungeon's door, so it is no proof).
local function questDone(character: Types.CharacterData, questId: string): boolean
	local quests = character.quests
	local index = Quests.Main.indexOf[questId]
	if index then
		return (tonumber(quests.mainDone) or 0) >= index
	end
	return quests.side.done[questId] == true
end

local function bossWon(character: Types.CharacterData, bossId: string): boolean
	if questDone(character, `boss_{bossId}`) then
		return true
	end
	for _, quest in Quests.Main.list do
		for _, objective: any in quest.objectives do
			if objective.type == "boss" and objective.boss == bossId and questDone(character, quest.id) then
				return true
			end
		end
	end
	return false
end

-- S132: class outfits earned before this session (or before the account owned them), given on entering the world.
local function grantEarned(player: Player, character: Types.CharacterData)
	if PlayerStateService.GetCharacter(player) ~= character then
		return
	end
	local ids = CharacterLook.earnedOutfits(character.class, function(questId: string): boolean
		return questDone(character, questId)
	end, function(bossId: string): boolean
		return bossWon(character, bossId)
	end)
	for _, id in ids do
		CosmeticService.Grant(player, id)
	end
end

-- S132: the look change (SetCharacterLook): free once from anywhere, then gold next to the barber. The gold, the free
-- flag and the look are written in one step without a yield.
local function setLook(player: Player, face: string, skin: string, hair: string): (boolean, string?)
	local char = PlayerStateService.GetCharacter(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local valid, bad = CharacterLook.isValid(face, skin, hair)
	if not valid then
		return false, bad
	end
	local look = { face = face, skin = skin, hair = hair }
	local near = NpcService.NearService(player, "look") ~= nil
	local ok, err, cost = CharacterLook.canChange(char, look, near)
	if not ok then
		return false, err
	end
	local free = char.lookFree == true
	if cost > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold - cost
		end)
		Analytics.gold(player, -cost, balance, "look")
	end
	if free then
		PlayerStateService.Set(player, { "character", "lookFree" }, false)
	end
	PlayerStateService.Set(player, { "character", "look" }, look)
	CosmeticService.RefreshAppearance(player)
	DataService.Save(player)
	Analytics.custom(player, if free then "LookChangeFree" else "LookChangeGold", 1)
	Net.Fire(player, "Toast", "look.changed", nil, "success")
	return true, nil
end

-- S132 (admin /charlook): the look without a cost and without touching the free change. False for a bad look or no
-- character.
function CosmeticService.AdminSetLook(player: Player, look: ClassLooks.Look): boolean
	if not PlayerStateService.GetCharacter(player) or not CharacterLook.isValid(look.face, look.skin, look.hair) then
		return false
	end
	PlayerStateService.Set(player, { "character", "look" }, { face = look.face, skin = look.skin, hair = look.hair })
	CosmeticService.RefreshAppearance(player)
	return true
end

-- S132: "Show my Roblox avatar" (SettingsService and admin /avatarmode): the setting, then the appearance.
function CosmeticService.SetRobloxAvatar(player: Player, on: boolean)
	PlayerStateService.Set(player, { "account", "settings", "robloxAvatar" }, on)
	if on and avatars[player] == false then
		avatars[player] = nil -- refused before: ask Roblox again
	end
	CosmeticService.RefreshAppearance(player)
end

-- W09: the Roblox hairstyles of Data/BodyLooks into ReplicatedStorage (AvatarBuild puts them on characters and
-- previews; a style that does not load keeps the procedural hair).
local function loadHairs()
	local folder = Instance.new("Folder")
	folder.Name = BodyLooks.HAIR_FOLDER
	for style, def in BodyLooks.hairs do
		local ok, loaded = pcall(function()
			return InsertService:LoadAsset(def.id)
		end)
		local accessory = if ok and loaded then loaded:FindFirstChildWhichIsA("Accessory", true) else nil
		if accessory then
			LookBuild.stripScripts(accessory)
			accessory.Name = style
			accessory.Parent = folder
		else
			log:warn("hairstyle %s (%d) did not load: procedural hair", style, def.id)
		end
		if ok and loaded then
			loaded:Destroy()
		end
	end
	folder.Parent = ReplicatedStorage
end

-- S132: the standard figure of the client previews (creator, wardrobe, look window).
local function buildMannequin()
	local spec = CharacterLook.resolve({ classId = "Warrior", look = ClassLooks.DEFAULT_LOOK, robloxAvatar = false })
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(AvatarBuild.description(spec, nil), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		log:warn("no mannequin (%s): the previews use the block figure", tostring(model))
		return
	end
	local mannequin = model :: Model
	LookBuild.stripScripts(mannequin)
	-- W09: outside the Workspace no joint is solved (the dynamic head and the brows stayed where they loaded): every
	-- part goes where its joint (Motor6D / weld, or the AnimationConstraint of the body) puts it, from the root
	-- outwards, before the figure is anchored
	local root = mannequin:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local links: { { any } } = {}
		for _, item in mannequin:GetDescendants() do
			if item:IsA("JointInstance") and item.Part0 and item.Part1 then
				table.insert(links, { item.Part0, item.Part1, item.C0, item.C1 })
			elseif item:IsA("AnimationConstraint") and item.Attachment0 and item.Attachment1 then
				local a0, a1 = item.Attachment0 :: Attachment, item.Attachment1 :: Attachment
				table.insert(links, { a0.Parent, a1.Parent, a0.CFrame, a1.CFrame })
			end
		end
		local placed: { [Instance]: boolean } = { [root] = true }
		local moved = true
		while moved do
			moved = false
			for _, link in links do
				local p0, p1, c0, c1 = link[1], link[2], link[3], link[4]
				if p0:IsA("BasePart") and p1:IsA("BasePart") then
					if placed[p0] and not placed[p1] then
						p1.CFrame = p0.CFrame * c0 * c1:Inverse()
						placed[p1], moved = true, true
					elseif placed[p1] and not placed[p0] then
						p0.CFrame = p1.CFrame * c1 * c0:Inverse()
						placed[p0], moved = true, true
					end
				end
			end
		end
	end
	mannequin.Name = AvatarBuild.MANNEQUIN
	mannequin.Archivable = true
	for _, item in mannequin:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
		end
	end
	local humanoid = mannequin:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	mannequin:PivotTo(CFrame.new())
	mannequin.Parent = ReplicatedStorage
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
	NpcService = registry.Get("NpcService")
end

function CosmeticService.Start()
	petFolder = Instance.new("Folder")
	petFolder.Name = "VaelthornPets"
	petFolder.Parent = Workspace

	Net.Handle("CosmeticEquip", equip)
	Net.Handle("OutfitSave", saveOutfit)
	Net.Handle("OutfitWear", wearOutfit)
	Net.Handle("SetCharacterLook", setLook)
	-- S132: the character spawns in its look (CharacterService yields for it; the avatar's description first)
	CharacterService.SetDescriptionProvider(function(player: Player, character: Types.CharacterData)
		local description, spec = describe(player, character)
		if spec and description then
			spawnKey[player] = keyOf(spec)
		end
		return description
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player, character: Types.CharacterData)
		task.defer(grantEarned, player, character)
	end)
	CharacterService.ModelSpawned:Connect(onModel)
	CharacterService.CharacterLeaving:Connect(removePet)
	-- S123: the frame / chat frame / level-up attributes exist before the first character model
	PlayerStateService.Ready:Connect(function(player: Player)
		publishAttributes(player)
		-- S132: the avatar's description early, so a switched-on avatar does not wait at the first spawn
		local data = account(player)
		if data and data.settings.robloxAvatar == true then
			task.spawn(avatarOf, player)
		end
	end)
	task.spawn(loadHairs)
	task.spawn(buildMannequin)
	Players.PlayerRemoving:Connect(function(player)
		removePet(player)
		local watch = modelWatch[player]
		modelWatch[player] = nil
		if watch then
			for _, connection in watch do
				connection:Disconnect()
			end
		end
		avatars[player] = nil
		fetching[player] = nil
		spawnKey[player] = nil
		busy[player] = nil
		again[player] = nil
	end)
end

return CosmeticService
