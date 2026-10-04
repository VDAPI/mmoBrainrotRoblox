--!strict
-- Account-wide player settings (language for now; volume/quality/etc. arrive with the options window).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Locale = require(Shared.Util.Locale)
local Net = require(Shared.Net)

local SettingsService = {
	Name = "SettingsService",
	Deps = { "PlayerStateService" },
}

local PlayerStateService: any

function SettingsService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
end

function SettingsService.Start()
	Net.On("SetLanguage", function(player: Player, lang: string)
		if not Locale.isSupported(lang) or not PlayerStateService.HasState(player) then
			return
		end
		PlayerStateService.Set(player, { "account", "settings", "lang" }, lang)
	end)
end

return SettingsService
