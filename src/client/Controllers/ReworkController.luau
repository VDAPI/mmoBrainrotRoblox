--!strict
-- "Character progression has changed" (S56, ROZWOJ 5): a character migrated to save schema 6 (skill points gone,
-- stats reset for free, the bar rebuilt) has character.reworkNotice = true. When it enters the world, one modal
-- explains the change (a reset must never stay unexplained); either button sends AckRework so it never shows again,
-- "Open skills" also opens the Skills window. Every migrated character of the account gets it once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
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
	local message = Text.now("rework.body", { level = SkillData.RANKS.capLevel })
	-- S78: one paragraph per class whose skills moved to paths since the notice (keys literal for the key test)
	local class = State.Get({ "character", "class" })
	if class == "Hunter" then
		message ..= "\n\n" .. Text.now("rework.class.Hunter")
	elseif class == "Mage" then
		message ..= "\n\n" .. Text.now("rework.class.Mage") -- S81
	end
	WindowManager.ShowModal({
		Title = Text.now("rework.title"),
		Message = message,
		ConfirmText = Text.now("rework.open"),
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
