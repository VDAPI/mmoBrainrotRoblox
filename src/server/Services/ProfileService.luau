--!strict
-- Player profiles (S15): what anyone may see about another character on the same server — name, class,
-- level, guild, PvP and duel records and the equipped items (with their rolls, like inspecting in Margonem).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Types = require(ReplicatedStorage.Shared.Types)

local ProfileService = {
	Name = "ProfileService",
	Deps = { "PlayerStateService", "GuildService" },
}

local PlayerStateService: any
local GuildService: any

local function profile(_viewer: Player, userId: number): (boolean, any)
	local target = Players:GetPlayerByUserId(userId)
	local char: Types.CharacterData? = target and PlayerStateService.GetCharacter(target)
	if not target or not char then
		return false, "profile.error.notFound"
	end
	local guild = GuildService.Data(target)
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
			title = Titles.shown(char),
		}
end

function ProfileService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	GuildService = registry.Get("GuildService")
end

function ProfileService.Start()
	Net.Handle("PlayerProfile", profile)
end

return ProfileService
