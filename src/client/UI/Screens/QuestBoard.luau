--!strict
-- Contract board on the plaza (DESIGN §20): today's three contracts with progress, rewards and "Collect",
-- and the time until the new set at 00:00 UTC.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local QuestRewards = require(script.Parent.Parent.Components.QuestRewards)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function QuestBoard(scope: Scope): Fusion.Child
	local daily = State.Value({ "character", "quests", "daily" })
	local level = State.Value({ "character", "level" })
	local now = scope:Value(Clock.now())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator > 1 then
				accumulator = 0
				now:set(Clock.now())
			end
		end)
	)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local d = use(daily)
		local list = {}
		if type(d) ~= "table" then
			return list
		end
		local reward = Quests.Daily.reward(use(level) or 1)
		for i, entry in d.list or {} do
			local done = entry.progress >= entry.objective.n
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 110),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = 0.35,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }),
						s:New("TextLabel")({
							Size = UDim2.new(1, -170, 0, 26),
							BackgroundTransparency = 1,
							Text = Text.get(use, `daily.{entry.template}.title`),
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 20,
							TextColor3 = Theme.Colors.GoldBright,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(0, 30),
							Size = UDim2.new(1, -170, 0, 24),
							BackgroundTransparency = 1,
							Text = QuestText.objective(use, entry.objective, entry.progress),
							FontFace = Theme.Fonts.BodyMedium,
							TextSize = 17,
							TextColor3 = if done then Theme.Colors.Success else Theme.Colors.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
						-- S31: rewards as icons and item slots with tooltips.
						QuestRewards(s, {
							Id = `daily{i}`,
							Reward = reward,
							SlotSize = 38,
							Position = UDim2.fromOffset(0, 58),
							Width = UDim.new(1, -170),
						}),
						Button(s, {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -10, 0.5, -4),
							Size = UDim2.fromOffset(150, 50),
							Variant = "primary",
							Text = Text.get(use, if entry.claimed then "quest.claimed" else "quest.claim"),
							Disabled = entry.claimed or not done,
							OnClick = function()
								task.spawn(function()
									local ok, err = Net.Invoke("DailyClaim", i)
									if not ok then
										Sounds.play("error")
										Toast.push(Text.now(err or "error.internal"), "error")
									end
								end)
							end,
						}),
					},
				})
			)
		end
		return list
	end)

	return {
		scope:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local t = use(now)
				return Text.get(use, "quest.dailyReset", { time = Time.format((Time.dayNumber(t) + 1) * 86400 - t) })
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("Frame")({
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				rows :: any,
			},
		}),
	}
end

return QuestBoard
