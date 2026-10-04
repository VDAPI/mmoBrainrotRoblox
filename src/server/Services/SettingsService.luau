--!strict
-- Account-wide player settings: language, damage numbers, volume (quality etc. arrive with the options window).

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

-- Settings a client may change, with their validators.
local SETTINGS: { [string]: (value: any) -> boolean } = {
	dmgNumbers = function(value)
		return type(value) == "boolean"
	end,
	volume = function(value)
		return type(value) == "number" and value == value and value >= 0 and value <= 1
	end,
}

function SettingsService.Start()
	Net.On("SetSetting", function(player: Player, name: string, value: any)
		local validate = SETTINGS[name]
		if not validate or not validate(value) or not PlayerStateService.HasState(player) then
			return
		end
		PlayerStateService.Set(player, { "account", "settings", name }, value)
	end)

	Net.On("SetLanguage", function(player: Player, lang: string)
		if not Locale.isSupported(lang) or not PlayerStateService.HasState(player) then
			return
		end
		PlayerStateService.Set(player, { "account", "settings", "lang" }, lang)
	end)
end

return SettingsService
