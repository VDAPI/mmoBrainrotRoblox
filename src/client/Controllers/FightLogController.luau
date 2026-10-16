--!strict
-- After-fight meter on the client (S134f, DESIGN §17): keeps the last Config.FightLog.keep summaries of this session
-- (`FightSummary` from FightLogService), shows the small card (UI/Screens/FightCard) after an Elite II or an Invasion
-- (a boss has its reward card with "Details" instead; the setting `fightCard` turns only the card off) and owns the
-- "fightlog" window (UI/Screens/FightLogWindow), opened from the card, the boss reward card and the party window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FightCard = require(script.Parent.Parent.UI.Screens.FightCard)
local FightLogWindow = require(script.Parent.Parent.UI.Screens.FightLogWindow)
local FightView = require(script.Parent.Parent.UI.FightView)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local FightLogController = {
	Name = "FightLogController",
	Deps = { "WindowManager", "UIController" },
}

local CFG = Config.FightLog

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local UIController: any

-- Newest first.
FightLogController.Recent = scope:Value({} :: { FightView.Summary })
-- Index into Recent shown by the window.
FightLogController.Selected = scope:Value(1)

local cardScope: any = nil

local function closeCard()
	if cardScope then
		Fusion.doCleanup(cardScope)
		cardScope = nil
	end
end

function FightLogController.Open(index: number?)
	FightLogController.Selected:set(index or 1)
	closeCard()
	WindowManager.Open("fightlog")
end

local function showCard(summary: FightView.Summary)
	closeCard()
	local inner = scope:innerScope()
	cardScope = inner
	FightCard(inner, {
		Summary = summary,
		OpenDetails = function()
			FightLogController.Open(1)
		end,
		Close = function()
			if cardScope == inner then
				closeCard()
			end
		end,
	}).Parent =
		UIController.GetLayer("Screens")
	task.delay(CFG.cardSeconds, function()
		if cardScope == inner then
			closeCard()
		end
	end)
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
	UIController = registry.Get("UIController")
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
