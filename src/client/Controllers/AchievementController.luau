--!strict
-- Achievement notices (S151, docs/DESIGN.md §20b): AchievementDone from AchievementService. A done achievement
-- ({ id, reward }) or the catch-up of old progress ({ backfill = n }) goes into a queue shown one at a time in
-- Hud/AchievementToast (Config.Achievements.toastSeconds each, sound ui.achievement); with the setting off
-- (account.settings.achToasts) every notice is one line in the system chat instead. The server is the authority:
-- nothing here reports progress.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchData = require(ReplicatedStorage.Shared.Data.Achievements)
local AchievementToast = require(script.Parent.Parent.UI.Screens.Hud.AchievementToast)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)

local AchievementController = {
	Name = "AchievementController",
	Deps = { "UIController", "NotificationController", "SfxController" },
}

local scope = Fusion.scoped(Fusion)
local NotificationController: any
local SfxController: any
local toast: AchievementToast.Api? = nil

local MAX_QUEUE = 8

local queue: { AchievementToast.View } = {}
local showing = false

local function num(value: any): number?
	return if type(value) == "number" and value == value and value > 0 and value < 1e9 then math.floor(value) else nil
end

-- The reward lines of a payload ("Title: …", "Dragon Shards: 25", …), joined.
local function rewardText(reward: any): string
	if type(reward) ~= "table" then
		return ""
	end
	local parts: { string } = {}
	local title = if type(reward.title) == "string" then TitleData.get(reward.title) else nil
	if title then
		table.insert(parts, Text.now("ach.toast.title", { name = Text.now(title.nameKey) }))
	end
	local cosmetic = if type(reward.cosmetic) == "string" then Cosmetics.get(reward.cosmetic) else nil
	if cosmetic then
		table.insert(parts, Text.now("ach.toast.cosmetic", { name = Text.now(cosmetic.nameKey) }))
	end
	local shards = num(reward.shards)
	if shards then
		table.insert(parts, Text.now("ach.toast.shards", { n = shards }))
	end
	local gold = num(reward.gold)
	if gold then
		table.insert(parts, Text.now("ach.toast.gold", { n = gold }))
	end
	return table.concat(parts, " · ")
end

-- The texts of one notice (nil for a malformed payload).
local function viewOf(payload: any): AchievementToast.View?
	if type(payload) ~= "table" then
		return nil
	end
	local backfill = num(payload.backfill)
	if backfill then
		return {
			header = Text.now("ach.toast.header"),
			name = Text.now("ach.backfill", { n = backfill }),
			meta = "",
			reward = "",
		}
	end
	local def = if type(payload.id) == "string" then AchData.get(payload.id) else nil
	if not def then
		return nil
	end
	return {
		header = Text.now("ach.toast.header"),
		name = Text.now(`ach.{def.id}.name`),
		meta = Text.now("ach.toast.meta", { cat = Text.now(`ach.cat.{def.cat}`), points = def.points }),
		reward = rewardText(payload.reward),
	}
end

local function pump()
	if showing or not toast then
		return
	end
	local nextView = table.remove(queue, 1)
	if not nextView then
		return
	end
	showing = true
	if SfxController then
		SfxController.Ui("ui.achievement")
	end
	toast.show(nextView, function()
		showing = false
		pump()
	end)
end

local function onDone(payload: any)
	local view = viewOf(payload)
	if not view then
		return
	end
	if State.Get({ "account", "settings", "achToasts" }) == false then
		local line = if view.reward ~= "" then `{view.name} ({view.reward})` else view.name
		NotificationController.System(Text.now("ach.chat", { text = line }))
		return
	end
	if #queue >= MAX_QUEUE then
		table.remove(queue, 1)
	end
	table.insert(queue, view)
	pump()
end

function AchievementController.Init(registry)
	NotificationController = registry.Get("NotificationController")
	SfxController = registry.Get("SfxController")
	local api = AchievementToast.new(scope)
	api.frame.Parent = registry.Get("UIController").GetLayer("Toasts")
	toast = api
end

function AchievementController.Start()
	Net.On("AchievementDone", onDone)
	scope:Observer(State.Value({ "account", "settings", "achToasts" })):onChange(function()
		if State.Get({ "account", "settings", "achToasts" }) == false then
			table.clear(queue)
			if toast then
				toast.hide()
			end
		end
	end)
end

return AchievementController
