--!strict
-- S152b: the season pass as the client sees it (Logic/SeasonView over the replicated account.season and
-- account.seasonPrev). One clock for the window, the HUD button and the shop card: Util/Clock plus the season clock
-- offset of this server (SeasonService.SetWeek, Studio only; the ReplicatedStorage attribute SeasonClockOffset).
--   SeasonState.now()   the season clock now
--   SeasonState.Now     the same as a Value, refreshed every second
--   SeasonState.View    Computed SeasonView.View

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local State = require(script.Parent.State)

local SeasonState = {}

local OFFSET_ATTRIBUTE = "SeasonClockOffset"
local TICK = 1 -- seconds between two clock updates (the "ends in" line, the season start)

local scope = Fusion.scoped(Fusion)

function SeasonState.now(): number
	local offset = ReplicatedStorage:GetAttribute(OFFSET_ATTRIBUTE)
	return Clock.now() + (if type(offset) == "number" then offset else 0)
end

SeasonState.Now = scope:Value(SeasonState.now())

local season = State.Value({ "account", "season" })
local prev = State.Value({ "account", "seasonPrev" })

SeasonState.View = scope:Computed(function(use): SeasonView.View
	return SeasonView.of(use(season), use(prev), use(SeasonState.Now))
end)

-- The view of this moment (outside a Computed).
function SeasonState.get(): SeasonView.View
	return SeasonView.of(State.Get({ "account", "season" }), State.Get({ "account", "seasonPrev" }), SeasonState.now())
end

task.spawn(function()
	while true do
		task.wait(TICK)
		SeasonState.Now:set(math.floor(SeasonState.now()))
	end
end)

return SeasonState
