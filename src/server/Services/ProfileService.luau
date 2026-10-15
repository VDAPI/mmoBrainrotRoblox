--!strict
-- Player profiles (S15): what anyone may see about another character on the same server — name, class,
-- level, guild, PvP and duel records and the equipped items (with their rolls, like inspecting in Margonem).
-- S123: the shown title with the account context (VIP and bought titles) and the portrait frame (cosmetic id); nothing
-- else of the account (no owned cosmetics, no shards).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Types = require(ReplicatedStorage.Shared.Types)

local ProfileService = {
	Name = "ProfileService",
	-- S121: the VIP title; S123: DataService for the target's account (bought titles, portrait frame)
	Deps = { "PlayerStateService", "GuildService", "MonetizationService", "DataService" },
}

local PlayerStateService: any
local GuildService: any
local MonetizationService: any
local DataService: any

local function profile(_viewer: Player, userId: number): (boolean, any)
	local target = Players:GetPlayerByUserId(userId)
	local char: Types.CharacterData? = target and PlayerStateService.GetCharacter(target)
	if not target or not char then
		return false, "profile.error.notFound"
	end
	local guild = GuildService.Data(target)
	local account: Types.AccountData? = DataService.GetData(target)
	local frame = account and account.cosmetics.equipped.frame
	return true,
		{
			userId = userId,
			name = char.name,
			class = char.class,
			level = char.level,
			guild = if guild then `[{guild.tag}] {guild.name}` else nil,
			pvp = table.clone(char.pvp),
			equipment = table.clone(char.equipment),
			createdAt = char.createdAt,
			title = Titles.shown(char, nil, Titles.contextOf(account, MonetizationService.HasVip(target))),
			-- S128: the season of an arena season title (ProfileWindow, UI/TitleText)
			titleSeason = (function(): string?
				local shown = Titles.shown(char, nil, Titles.contextOf(account, MonetizationService.HasVip(target)))
				local args = if shown then Titles.argsOf(char, shown) else nil
				return if args then args.season else nil
			end)(),
			frame = if type(frame) == "string" then frame else nil,
		}
end

function ProfileService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	GuildService = registry.Get("GuildService")
	MonetizationService = registry.Get("MonetizationService")
	DataService = registry.Get("DataService")
end

function ProfileService.Start()
	Net.Handle("PlayerProfile", profile)
end

return ProfileService
