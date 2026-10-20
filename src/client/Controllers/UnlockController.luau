--!strict
-- S155b: new features on a level up (Logic/Unlocks). The own LevelUp that crosses an entry's level shows a toast
-- naming the feature and, for an entry with a HUD window, lights the "!" on its menu button (UI/MenuAttention) until
-- that window is first opened.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MenuAttention = require(script.Parent.Parent.UI.MenuAttention)
local Net = require(ReplicatedStorage.Shared.Net)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Unlocks = require(ReplicatedStorage.Shared.Logic.Unlocks)

local UnlockController = {
	Name = "UnlockController",
	Deps = { "WindowManager" },
}

local WindowManager: any
local scope = Fusion.scoped(Fusion)

local TOAST_SECONDS = 7

function UnlockController.Init(registry)
	WindowManager = registry.Get("WindowManager")
end

function UnlockController.Start()
	-- opening a newly unlocked window takes its "!" away
	for _, entry in Unlocks.LIST do
		local window = entry.window
		if window then
			local open = WindowManager.IsOpen(window)
			scope:Observer(open):onChange(function()
				if Fusion.peek(open) then
					MenuAttention.clear(window)
				end
			end)
		end
	end
	Net.On("LevelUp", function(player: Player, level: number, _stat: number, _path: number?, from: number?)
		if player ~= Players.LocalPlayer or type(level) ~= "number" then
			return
		end
		local before = if type(from) == "number" then from else level - 1
		for _, entry in Unlocks.crossed(before, level) do
			Toast.push(Text.now(entry.textKey, { level = entry.level }), "success", TOAST_SECONDS)
			if entry.window then
				MenuAttention.mark(entry.window)
			end
		end
	end)
end

return UnlockController
