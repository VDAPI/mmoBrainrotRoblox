--!strict
-- Blood Moon on the client (S129, DESIGN-17 §7): registers the results window (UI/Screens/BloodMoonWindow; no key, it
-- opens from the HUD menu, the HUD panel and the game menu) and reddens the sky over the four open regions while the
-- event runs (WorldController.SetEventTint with Data/ScheduledEvents.bloodMoon.sky, faded in and out). Caves, dungeons
-- and the city keep their light. The RegionLightController of the contract only sets light detail, so the sky lives
-- here (DECYZJE S129). No start sound: Data/Sfx has no announcement or horn with an id yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoon = require(ReplicatedStorage.Shared.Logic.BloodMoon)
local BloodMoonView = require(script.Parent.Parent.UI.BloodMoonView)
local BloodMoonWindow = require(script.Parent.Parent.UI.Screens.BloodMoonWindow)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ScheduledEvents = require(ReplicatedStorage.Shared.Data.ScheduledEvents)
local State = require(script.Parent.Parent.UI.State)

local BloodMoonController = {
	Name = "BloodMoonController",
	Deps = { "WorldController", "WindowManager" },
}

local scope = Fusion.scoped(Fusion)
local WorldController: any
local WindowManager: any

local SKY = ScheduledEvents.bloodMoon.sky

local function tint(): any
	return {
		fogColor = Color3.fromHex(SKY.fogColor),
		fogMix = SKY.fogMix,
		tint = Color3.fromHex(SKY.tint),
		tintMix = SKY.tintMix,
		brightness = SKY.brightness,
		saturation = SKY.saturation,
		haze = SKY.haze,
		fade = SKY.fade,
	}
end

function BloodMoonController.Open()
	WindowManager.Open("bloodmoon")
end

function BloodMoonController.Init(registry)
	WorldController = registry.Get("WorldController")
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "bloodmoon",
		titleKey = "window.bloodmoon.title",
		size = Vector2.new(860, 600),
		build = function(s: any)
			return BloodMoonWindow(s)
		end,
	})
end

function BloodMoonController.Start()
	local zoneMap = State.Value({ "zone", "map" })
	local red = scope:Computed(function(use): boolean
		local map = use(zoneMap)
		return use(BloodMoonView.Phase) == "active" and type(map) == "string" and BloodMoon.isEventMap(map)
	end)
	local value = tint()
	scope:Observer(red):onBind(function()
		WorldController.SetEventTint(if Fusion.peek(red) then value else nil)
	end)
end

return BloodMoonController
