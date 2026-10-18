--!strict
-- Character titles (S16): the player picks one of the unlocked titles (Logic/Titles); it is saved on the
-- character and mirrored to the "Title" attribute of the character model for the nameplates.
-- S59: the main path title shows by default (Titles.shown; S138: the leading direction's), refreshed on
-- PathService.Changed (nodes bought or refunded, build set switched); "no title" is saved as Titles.NONE.
-- S121: the account context (VIP title while MonetizationService.HasVip), refreshed on VipChanged.
-- S123: the context also carries the owned cosmetics (bought titles, Titles.contextOf); CosmeticService refreshes
-- after a title cosmetic is given or taken.
-- S125: timed titles (character.timedTitles, Data/Titles req.kind "timed"): GrantTimed (weekly ranking mail; S129 Blood
-- Moon, S130 tournament), the context carries Clock.now(); expired entries are pruned on entering the world and by a
-- check every TIMED_CHECK s for online players (the nameplate falls back to Titles.shown).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Clock = require(Shared.Util.Clock)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Net = require(Shared.Net)
local TitleData = require(Shared.Data.Titles)
local Titles = require(Shared.Logic.Titles)
local Types = require(Shared.Types)

local TIMED_CHECK = 60 -- s between checks for expired timed titles of online players

local TitleService = {
	Name = "TitleService",
	Deps = { "PlayerStateService", "CharacterService", "PathService", "MonetizationService" },
}

local PlayerStateService: any
local CharacterService: any
local PathService: any
local MonetizationService: any

-- S123: one context for every account-dependent title (VIP and bought titles, Titles.contextOf).
local function contextOf(player: Player): Titles.Context
	return Titles.contextOf(
		PlayerStateService.Get(player, { "account" }),
		MonetizationService.HasVip(player),
		Clock.now()
	)
end

-- Writes the shown title onto the character model (nil hides it).
function TitleService.Refresh(player: Player)
	local model = player.Character
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if model and character then
		local shown = Titles.shown(character, nil, contextOf(player))
		model:SetAttribute("Title", shown)
		-- S128: the season of an arena season title (nameplates of every player read the model)
		local args = if shown then Titles.argsOf(character, shown) else nil
		model:SetAttribute("TitleSeason", if args then args.season else nil)
	end
end

local function setTitle(player: Player, id: string?): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.internal"
	end
	if id == nil or id == Titles.NONE then
		-- nil in the save means "never chose" (the leading direction's title shows), so hiding stores NONE
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

-- S125: unlocks the timed title `id` until `untilTs` (unix seconds; a later term never gets shorter). The title shows
-- at once when the player has not chosen one. False for an unknown or non-timed title, an expired term or no
-- character. S129 / S130 use it too.
function TitleService.GrantTimed(player: Player, id: string, untilTs: number): boolean
	local def = TitleData.get(id)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not def or def.req.kind ~= "timed" or not character or untilTs <= Clock.now() then
		return false
	end
	PlayerStateService.Set(
		player,
		{ "character", "timedTitles" },
		Titles.grantTimed(character.timedTitles, id, untilTs)
	)
	Net.Fire(player, "Toast", "title.timedGot", {
		title = `@{def.nameKey}`,
		["until"] = { key = "leaderboard.date", args = Leaderboard.dateParts(untilTs) },
	}, "success")
	if character.title == nil then
		setTitle(player, id)
	else
		TitleService.Refresh(player)
	end
	return true
end

-- S125: takes the timed title `id` away (/timedtitle <id> 0). False without a character.
function TitleService.RemoveTimed(player: Player, id: string): boolean
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false
	end
	local timed = table.clone(character.timedTitles or {})
	timed[id] = nil
	PlayerStateService.Set(player, { "character", "timedTitles" }, timed)
	TitleService.Refresh(player)
	return true
end

-- S125: drops expired timed titles of the player's character; refreshes the nameplate when something went.
local function pruneTimed(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character or next(character.timedTitles or {}) == nil then
		return
	end
	local kept, removed = Titles.pruneTimed(character.timedTitles, Clock.now())
	if removed then
		PlayerStateService.Set(player, { "character", "timedTitles" }, kept)
		TitleService.Refresh(player)
	end
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
	CharacterService.CharacterEntered:Connect(function(player: Player)
		pruneTimed(player)
	end)
	task.spawn(function()
		while true do
			task.wait(TIMED_CHECK)
			for _, player in Players:GetPlayers() do
				if PlayerStateService.GetPhase(player) == "playing" then
					pruneTimed(player)
				end
			end
		end
	end)
end

return TitleService
