--!strict
-- Contract board on the plaza (DESIGN §20): today's three contracts with progress, rewards and "Collect",
-- and the time until the new set at 00:00 UTC. S98 (docs/DESIGN-15.md §3.1): a second tab with the week's three
-- contracts (new set on Monday 00:00 UTC) and the week's boss contract (no card below the first boss's entry level);
-- the list scrolls (phones).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local QuestRewards = require(script.Parent.Parent.Components.QuestRewards)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

type Card = {
	id: string,
	order: number,
	title: string,
	line: string,
	done: boolean,
	claimed: boolean,
	reward: Quests.Reward,
	claim: () -> (boolean, string?),
}

local function card(s: Scope, use: Fusion.Use, c: Card): Instance
	return s:New("Frame")({
		LayoutOrder = c.order,
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.35,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }),
			s:New("TextLabel")({
				Size = UDim2.new(1, -170, 0, 26),
				BackgroundTransparency = 1,
				Text = c.title,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = 20, MinTextSize = 14 }),
			}),
			s:New("TextLabel")({
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, -170, 0, 28),
				BackgroundTransparency = 1,
				Text = c.line,
				TextWrapped = true,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyMedium,
				TextColor3 = if c.done then Theme.Colors.Success else Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = 17, MinTextSize = 11 }),
			}),
			-- S31: rewards as icons and item slots with tooltips.
			QuestRewards(s, {
				Id = c.id,
				Reward = c.reward,
				SlotSize = 38,
				Position = UDim2.fromOffset(0, 58),
				Width = UDim.new(1, -170),
			}),
			Button(s, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, -4),
				Size = UDim2.fromOffset(150, 50),
				Variant = "primary",
				Text = Text.get(use, if c.claimed then "quest.claimed" else "quest.claim"),
				Disabled = c.claimed or not c.done,
				OnClick = function()
					task.spawn(function()
						local ok, err = c.claim()
						if not ok then
							Sounds.play("error")
							Toast.push(Text.now(err or "error.internal"), "error")
						end
					end)
				end,
			}),
		},
	})
end

local function QuestBoard(scope: Scope): Fusion.Child
	local daily = State.Value({ "character", "quests", "daily" })
	local weekly = State.Value({ "character", "quests", "weekly" })
	local level = State.Value({ "character", "level" })
	local tab = scope:Value("daily")
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
		local list = {}
		local lvl = use(level) or 1
		if use(tab) == "daily" then
			local d = use(daily)
			if type(d) ~= "table" then
				return list
			end
			local reward = Quests.Daily.reward(lvl)
			for i, entry in d.list or {} do
				table.insert(
					list,
					card(s, use, {
						id = `daily{i}`,
						order = i,
						title = Text.get(use, `daily.{entry.template}.title`),
						line = QuestText.objective(use, entry.objective, entry.progress),
						done = entry.progress >= entry.objective.n,
						claimed = entry.claimed,
						reward = reward,
						claim = function()
							return Net.Invoke("DailyClaim", i)
						end,
					})
				)
			end
			return list
		end
		local w = use(weekly)
		if type(w) ~= "table" then
			return list
		end
		local reward = Quests.Weekly.reward(lvl)
		for i, entry in w.list or {} do
			table.insert(
				list,
				card(s, use, {
					id = `weekly{i}`,
					order = i,
					title = Text.get(use, `weekly.{entry.template}.title`),
					line = QuestText.objective(use, entry.objective, entry.progress),
					done = entry.progress >= entry.objective.n,
					claimed = entry.claimed,
					reward = reward,
					claim = function()
						return Net.Invoke("WeeklyClaim", i)
					end,
				})
			)
		end
		local contract = w.boss
		if type(contract) == "table" then
			local n = Quests.Weekly.bossContract.n
			local boss = Bosses.get(contract.boss)
			local bossName = if boss then Text.get(use, boss.nameKey) else "?"
			table.insert(
				list,
				card(s, use, {
					id = "bossContract",
					order = 100,
					title = `{Text.get(use, "quest.bossContract.title")}: {bossName}`,
					line = Text.get(use, "quest.bossContract.text", { boss = bossName, n = n })
						.. "  "
						.. `{math.min(contract.progress, n)}/{n}`,
					done = contract.progress >= n,
					claimed = contract.claimed == true,
					reward = Quests.Weekly.bossReward(lvl),
					claim = function()
						return Net.Invoke("BossContractClaim")
					end,
				})
			)
		end
		return list
	end)

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = {
				{ id = "daily", label = Text.T(scope, "quest.board.daily") },
				{ id = "weekly", label = Text.T(scope, "quest.board.weekly") },
			},
		}),
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local t = use(now)
				if use(tab) == "weekly" then
					local days, hours = Time.split(Time.weekStart(Time.weekNumber(t) + 1) - t)
					return Text.get(use, "quest.weeklyReset", { days = days, hours = hours })
				end
				return Text.get(use, "quest.dailyReset", { time = Time.format((Time.dayNumber(t) + 1) * 86400 - t) })
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 78),
			Size = UDim2.new(1, 0, 1, -78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				rows :: any,
			},
		}),
	}
end

return QuestBoard
