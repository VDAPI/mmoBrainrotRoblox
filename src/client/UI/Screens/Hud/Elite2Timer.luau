--!strict
-- Elite II respawn countdown (FIX 2026-10-09, DESIGN §15.3), seen only by the players who fought the Elite II (their
-- own `character.e2timers`). One line per timer: the Elite II and its map, then mm:ss until it is back; past that "may
-- appear any moment" (its spawner wakes when a player is near). Timers from another server only say so.
-- FIX 2026-10-15 (owner): a timer that ran out stays green only for READY_SECONDS, then its line goes; a timer from
-- another server goes once its time is up. The server still drops a timer the moment its Elite II is back
-- (MonsterService.clearTimers).
-- UI plan phase 3 (plan §3 row 17): no panel of its own any more (it stood over the corner's buttons on PC and in the
-- column on a touch screen): an "Elite II" group of the quest tracker (Hud/QuestTracker, Logic/TrackerFold "e2") shows
-- these lines.
--   Elite2Timer.state(scope): the shown timers and the clock (ticks every 0.5 s);
--   Elite2Timer.row(s, timer, now, order, height): one line of the tracker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type TimerState = {
	list: Fusion.Computed<{ any }>, -- the timers that show now
	now: Fusion.Value<number>, -- the server clock
}

local READY_SECONDS = 30
local TIME_WIDTH = 96

local Elite2Timer = {}

function Elite2Timer.state(scope: Scope): TimerState
	local timers = State.Value({ "character", "e2timers" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local clock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			clock += dt
			if clock >= 0.5 then
				clock = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	-- Changes when a line appears or goes or the timers change; `now` ticks the countdowns inside the lines.
	local shownKey = scope:Computed(function(use): string
		local value = use(timers)
		local t = use(now)
		local keys = {}
		if type(value) == "table" then
			for i, timer in value do
				local limit = if timer.job == game.JobId then timer.to + READY_SECONDS else timer.to
				if t < limit then
					table.insert(keys, tostring(i))
				end
			end
		end
		return table.concat(keys, ",")
	end)
	local list = scope:Computed(function(use): { any }
		local value = use(timers)
		local out = {}
		if type(value) == "table" then
			for key in string.gmatch(use(shownKey), "%d+") do
				local timer = value[tonumber(key) :: number]
				if timer then
					table.insert(out, timer)
				end
			end
		end
		return out
	end)
	return { list = list, now = now }
end

-- One line: "<Elite II> (<map>)" on the left, the time left (or "any moment", green) on the right.
function Elite2Timer.row(s: Scope, timer: any, now: Fusion.Value<number>, order: number, height: number): Instance
	return s:New("Frame")({
		Name = "Elite2",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		[Children] = {
			s:New("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -TIME_WIDTH - 4, 1, 0),
				Text = s:Computed(function(use): string
					local def = Monsters.get(timer.kind)
					local name = if def then Text.get(use, def.nameKeys.elite2) else timer.kind
					local map = Maps.get(timer.map)
					local where = if map then Text.get(use, map.nameKey) else timer.map
					return `{name} ({where})`
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			s:New("TextLabel")({
				Name = "Time",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, TIME_WIDTH, 1, 0),
				Text = s:Computed(function(use): string
					local t = use(now)
					if timer.job ~= game.JobId then
						return Text.get(use, "e2timer.otherServer")
					elseif t < timer.to then
						return Time.format(timer.to - t)
					end
					return Text.get(use, "e2timer.anyShort")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = s:Computed(function(use): Color3
					return if use(now) < timer.to then Theme.Iron.Text else Theme.Iron.Success
				end),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		},
	})
end

return Elite2Timer
