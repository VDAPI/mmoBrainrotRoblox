--!strict
-- Character titles (S16): the player picks one of the unlocked titles (Logic/Titles); it is saved on the
-- character and mirrored to the "Title" attribute of the character model for the nameplates.
-- S59: the main path title shows by default (Titles.shown), refreshed on PathService.Changed (main path chosen or
-- changed, build set switched); "no title" is saved as Titles.NONE.
-- S121: the account context (VIP title while MonetizationService.HasVip), refreshed on VipChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Titles = require(Shared.Logic.Titles)
local Types = require(Shared.Types)

local TitleService = {
	Name = "TitleService",
	Deps = { "PlayerStateService", "CharacterService", "PathService", "MonetizationService" },
}

local PlayerStateService: any
local CharacterService: any
local PathService: any
local MonetizationService: any

local function contextOf(player: Player): Titles.Context
	return { vip = MonetizationService.HasVip(player) }
end

-- Writes the shown title onto the character model (nil hides it).
function TitleService.Refresh(player: Player)
	local model = player.Character
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if model and character then
		model:SetAttribute("Title", Titles.shown(character, nil, contextOf(player)))
	end
end

local function setTitle(player: Player, id: string?): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.internal"
	end
	if id == nil or id == Titles.NONE then
		-- nil in the save means "never chose" (the main path title shows), so hiding stores NONE
		PlayerStateService.Set(player, { "character", "title" }, Titles.NONE)
		TitleService.Refresh(player)
		return true
	end
	if not Titles.isUnlocked(character, id, nil, contextOf(player)) then
		return false, "title.error.locked"
	end
	PlayerStateService.Set(player, { "character", "title" }, id)
	TitleService.Refresh(player)
	return true
end

function TitleService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	PathService = registry.Get("PathService")
	MonetizationService = registry.Get("MonetizationService")
end

function TitleService.Start()
	Net.Handle("SetTitle", setTitle)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		TitleService.Refresh(player)
	end)
	PathService.Changed:Connect(function(player: Player)
		TitleService.Refresh(player)
	end)
	MonetizationService.VipChanged:Connect(function(player: Player)
		TitleService.Refresh(player)
	end)
end

return TitleService
