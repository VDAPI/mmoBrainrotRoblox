--!strict
-- Elite II respawn countdown (FIX 2026-10-09, DESIGN §15.3): a small panel in the bottom right corner, seen only
-- by the players who fought the Elite II (their own `character.e2timers`). One row per timer: the Elite II and
-- its map, then mm:ss until it is back; past that "may appear any moment" (its spawner wakes when a player is
-- near). Timers from another server only say so.
-- FIX 2026-10-15 (owner): a timer that ran out stays green only for READY_SECONDS, then its row goes (and the panel
-- with the last one); a timer from another server goes once its time is up. The server still drops a timer the
-- moment its Elite II is back (MonsterService.clearTimers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local TextCase = require(ReplicatedStorage.Shared.Logic.TextCase)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local WIDTH = 240
local READY_SECONDS = 30

local function Elite2Timer(scope: Scope): Instance
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
	-- Rebuilt when a row appears or goes or the timers change; `now` ticks the countdowns inside the rows.
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

	return scope:New("Frame")({
		Name = "Elite2Timer",
		AnchorPoint = Vector2.new(1, 1),
		Position = scope:Computed(function(use): UDim2
			-- Touch: above the attack and skill buttons.
			return UDim2.new(1, -Theme.Padding.Large, 1, if use(Device.Touch) then -290 else -130)
		end),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = scope:Computed(function(use): boolean
			return #use(list) > 0
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
			scope:New("TextLabel")({
				LayoutOrder = 0,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 20),
				Text = scope:Computed(function(use): string
					return TextCase.upper(Text.get(use, "e2timer.header"))
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:ForPairs(list, function(_use, s: Scope, i: number, timer: any): (number, Instance)
				return i,
					s:New("Frame")({
						LayoutOrder = i,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 42),
						[Children] = {
							s:New("TextLabel")({
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 0, 0, 20),
								Text = s:Computed(function(use2): string
									local def = Monsters.get(timer.kind)
									local name = if def then Text.get(use2, def.nameKeys.elite2) else timer.kind
									local map = Maps.get(timer.map)
									local where = if map then Text.get(use2, map.nameKey) else timer.map
									return `{name} ({where})`
								end),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Iron.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(0, 21),
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 0, 0, 20),
								Text = s:Computed(function(use2): string
									local t = use2(now)
									if timer.job ~= game.JobId then
										return Text.get(use2, "e2timer.otherServer")
									elseif t < timer.to then
										return Time.format(timer.to - t)
									end
									return Text.get(use2, "e2timer.any")
								end),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Small,
								TextColor3 = s:Computed(function(use2): Color3
									return if use2(now) < timer.to then Theme.Iron.Text else Theme.Iron.Success
								end),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
						},
					})
			end) :: any,
		},
	})
end

return Elite2Timer
