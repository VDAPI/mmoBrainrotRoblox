--!strict
-- "Character progression has changed" (S56, ROZWOJ 5): a character migrated to save schema 6 (skill points gone,
-- stats reset for free, the bar rebuilt) has character.reworkNotice = true. When it enters the world, one modal
-- explains the change (a reset must never stay unexplained); either button sends AckRework so it never shows again,
-- "Open skills" also opens the Skills window. Every migrated character of the account gets it once.
-- S137 (DESIGN-18 §10): migration 12 sets the flag again; the notice now explains skill points, weapon pools and the
-- free reset (rework2.*).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)

local ReworkController = {
	Name = "ReworkController",
	Deps = { "WindowManager" },
}

local WindowManager: any
local scope = Fusion.scoped(Fusion)
local shown = false -- this character's notice is open or answered (reset when leaving the world)

local function check()
	if State.Get({ "session", "phase" }) ~= "playing" then
		shown = false
		return
	end
	if shown or State.Get({ "character", "reworkNotice" }) ~= true then
		return
	end
	shown = true
	-- S137: skill points, pools and the free reset (rework2.*); the Mage paragraph names the element pools
	-- Owner 2026-10-21: two short sentences, the rest (with the bar size and the free refund level) under "More ▸"
	local args = {
		slots = SkillData.HOTBAR_SLOTS,
		level = Progression.freeRespecLevel,
	}
	local message = Text.now("rework2.body", args)
	local details = Text.now("rework2.body.info", args)
	if State.Get({ "character", "class" }) == "Mage" then
		message ..= "\n\n" .. Text.now("rework2.mage")
		details ..= "\n\n" .. Text.now("rework2.mage.info")
	end
	WindowManager.ShowModal({
		Title = Text.now("rework2.title"),
		Message = message,
		Details = details,
		ConfirmText = Text.now("rework2.button"),
		CancelText = Text.now("rework.later"),
		OnConfirm = function(): (boolean, string?)
			Net.Send("AckRework")
			WindowManager.Open("skills")
			return true, nil
		end,
		OnCancel = function()
			Net.Send("AckRework")
		end,
	})
end

function ReworkController.Init(registry)
	WindowManager = registry.Get("WindowManager")
end

function ReworkController.Start()
	scope:Observer(State.Value({ "session", "phase" })):onBind(check)
	scope:Observer(State.Value({ "character", "reworkNotice" })):onBind(check)
end

return ReworkController
