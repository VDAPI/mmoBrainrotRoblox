--!strict
-- Account-wide player settings (options window, S14) and the per-character HUD guide flag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Keybinds = require(Shared.Logic.Keybinds)
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
	quickCast = function(value)
		return type(value) == "boolean"
	end,
	bindConfirm = function(value)
		return type(value) == "boolean"
	end,
	volume = function(value)
		return type(value) == "number" and value == value and value >= 0 and value <= 1
	end,
	musicVolume = function(value)
		return type(value) == "number" and value == value and value >= 0 and value <= 1
	end,
	quality = function(value)
		return value == "high" or value == "low"
	end,
	minimapRotate = function(value)
		return type(value) == "boolean"
	end,
	cameraSens = function(value)
		return type(value) == "number" and value == value and value >= 0.2 and value <= 3
	end,
	sellConfirm = function(value)
		return type(value) == "boolean"
	end,
	autoTarget = function(value)
		return type(value) == "boolean"
	end,
	groupRings = function(value)
		return type(value) == "boolean"
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

	-- The HUD guide of a new character was finished or skipped.
	Net.On("GuideDone", function(player: Player)
		if PlayerStateService.GetCharacter(player) then
			PlayerStateService.Set(player, { "character", "guideDone" }, true)
		end
	end)

	-- S17: rebinding. action "*" restores every default; key nil restores one. Keys in use swap.
	Net.Handle("SetKeybind", function(player: Player, action: string, key: string?): (boolean, string?)
		if not PlayerStateService.HasState(player) then
			return false, "error.internal"
		end
		if action == "*" then
			PlayerStateService.Set(player, { "account", "settings", "keys" }, {})
			return true
		end
		local current = PlayerStateService.Get(player, { "account", "settings", "keys" })
		local result = Keybinds.assign(if type(current) == "table" then current else nil, action, key)
		if not result then
			return false, "keys.reserved"
		end
		PlayerStateService.Set(player, { "account", "settings", "keys" }, result)
		return true
	end)

	Net.On("SetLanguage", function(player: Player, lang: string)
		if not Locale.isSupported(lang) or not PlayerStateService.HasState(player) then
			return
		end
		PlayerStateService.Set(player, { "account", "settings", "lang" }, lang)
	end)
end

return SettingsService
