--!strict
-- After-fight meter on the client (S134f, DESIGN §17): keeps the last Config.FightLog.keep summaries of this session
-- (`FightSummary` from FightLogService), shows the small card (UI/Screens/FightCard) after an Elite II or an Invasion
-- (a boss has its reward card with "Details" instead; the setting `fightCard` turns only the card off) and owns the
-- "fightlog" window (UI/Screens/FightLogWindow), opened from the card, the boss reward card and the party window.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the card is one
-- of UI/Notify's cards (FightCard.push: the PC corner, a phone's M zone) with the full table behind 'Szczegóły'.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FightCard = require(script.Parent.Parent.UI.Screens.FightCard)
local FightLogWindow = require(script.Parent.Parent.UI.Screens.FightLogWindow)
local FightView = require(script.Parent.Parent.UI.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.UI.Notify)
local State = require(script.Parent.Parent.UI.State)

local FightLogController = {
	Name = "FightLogController",
	Deps = { "WindowManager", "UIController" },
}

local CFG = Config.FightLog

local scope = Fusion.scoped(Fusion)
local WindowManager: any

-- Newest first.
FightLogController.Recent = scope:Value({} :: { FightView.Summary })
-- Index into Recent shown by the window.
FightLogController.Selected = scope:Value(1)

local card: Notify.Handle? = nil

local function closeCard()
	if card then
		card.close()
		card = nil
	end
end

function FightLogController.Open(index: number?)
	FightLogController.Selected:set(index or 1)
	closeCard()
	WindowManager.Open("fightlog")
end

local function showCard(summary: FightView.Summary)
	closeCard()
	card = FightCard.push(summary, function()
		FightLogController.Open(1)
	end, CFG.cardSeconds)
end

local function onSummary(raw: any)
	local summary = FightView.summary(raw)
	if not summary then
		return
	end
	local list = table.clone(Fusion.peek(FightLogController.Recent))
	table.insert(list, 1, summary)
	while #list > CFG.keep do
		table.remove(list)
	end
	FightLogController.Recent:set(list)
	FightLogController.Selected:set(1)
	if summary.kind ~= "boss" and State.Get({ "account", "settings", "fightCard" }) ~= false then
		showCard(summary)
	end
end

function FightLogController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	WindowManager.Register({
		id = "fightlog",
		titleKey = "window.fightlog.title",
		size = Vector2.new(640, 520),
		build = function(s)
			return FightLogWindow(s, {
				Recent = FightLogController.Recent,
				Selected = FightLogController.Selected,
			})
		end,
	})
end

function FightLogController.Start()
	Net.On("FightSummary", onSummary)
end

return FightLogController
