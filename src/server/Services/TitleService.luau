--!strict
-- Character titles (S16): the player picks one of the unlocked titles (Logic/Titles); it is saved on the
-- character and mirrored to the "Title" attribute of the character model for the nameplates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Titles = require(Shared.Logic.Titles)
local Types = require(Shared.Types)

local TitleService = {
	Name = "TitleService",
	Deps = { "PlayerStateService", "CharacterService" },
}

local PlayerStateService: any
local CharacterService: any

-- Writes the shown title onto the character model (nil hides it).
function TitleService.Refresh(player: Player)
	local model = player.Character
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if model and character then
		model:SetAttribute("Title", Titles.shown(character))
	end
end

local function setTitle(player: Player, id: string?): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.internal"
	end
	if id ~= nil and not Titles.isUnlocked(character, id) then
		return false, "title.error.locked"
	end
	PlayerStateService.Set(player, { "character", "title" }, id)
	TitleService.Refresh(player)
	return true
end

function TitleService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
end

function TitleService.Start()
	Net.Handle("SetTitle", setTitle)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		TitleService.Refresh(player)
	end)
end

return TitleService
