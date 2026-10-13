--!strict
-- Contract board on the plaza (DESIGN §20): today's three contracts with progress, rewards and "Collect",
-- and the time until the new set at 00:00 UTC. S98 (docs/DESIGN-15.md §3.1): a second tab with the week's three
-- contracts (new set on Monday 00:00 UTC) and the week's boss contract (no card below the first boss's entry level);
-- the list scrolls (phones). S99 (§3.3): over both tabs the hunting contract (the active one with "Hand in" once done
-- and "Track" before, or the next one with "Accept", or "Next contract from level N" instead of a button; hidden once
-- all 99 are done), its hunting ground in the colour of its level band with the S33 profile, and the backlog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestTrack = require(script.Parent.Parent.QuestTrack)
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

-- S99: "Track" on the board (QuestController.Track); without them the contract has no track button.
export type Props = {
	Tracked: Fusion.Value<boolean>?,
	Focus: Fusion.Value<QuestTrack.Focus>?,
	Track: ((focus: QuestTrack.Focus) -> ())?,
}

local CONTRACT_HEIGHT = 168 -- header 26 + card 134 + gap 8

local function invoke(name: string)
	task.spawn(function()
		local ok, err = Net.Invoke(name, Contracts.BOARD)
		if ok then
			Sounds.play("levelUp")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

-- S99: the hunting contract section (nil when every contract is done or the list is empty).
local function contractSection(s: Scope, use: Fusion.Use, quests: any, lvl: number, props: Props): Instance?
	local state = Contracts.stateOf(quests)
	local active, entry = Contracts.active(state)
	local contract = active or Contracts.next(state)
	if not contract then
		return nil
	end
	local function lookup(key: string, args: { [string]: any }?): string
		return Text.get(use, key, args)
	end
	local progress = if entry then entry.progress else QuestLogic.emptyProgress(contract.objectives)
	local done = active ~= nil and Contracts.isComplete(state)
	local canTake = active == nil and Contracts.canAccept(state, lvl)
	local areaLine = QuestText.contractAreaLine(use, contract, lvl)
	local backlog = Contracts.backlog(state, lvl)
	local action: Instance
	if active and done then
		action = Button(s, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -4),
			Size = UDim2.fromOffset(150, 50),
			Variant = "primary",
			Text = Text.get(use, "contract.turnIn"),
			OnClick = function()
				invoke("ContractTurnIn")
			end,
		})
	elseif active then
		local focus: any = if props.Focus then use(props.Focus) else nil
		local tracked = props.Tracked ~= nil and use(props.Tracked) and focus ~= nil and focus.kind == "contract"
		action = Button(s, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -4),
			Size = UDim2.fromOffset(150, 40),
			Variant = "secondary",
			Text = Text.get(use, if tracked then "quest.untrack" else "quest.track"),
			Disabled = props.Track == nil,
			OnClick = function()
				local track = props.Track
				if track then
					track(if tracked then nil else { kind = "contract" })
				end
			end,
		})
	elseif canTake then
		action = Button(s, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -4),
			Size = UDim2.fromOffset(150, 50),
			Variant = "primary",
			Text = Text.get(use, "contract.accept"),
			OnClick = function()
				invoke("ContractAccept")
			end,
		})
	else
		-- waiting for the level: the reason instead of a button that does nothing
		action = s:New("TextLabel")({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -4),
			Size = UDim2.fromOffset(150, 50),
			BackgroundTransparency = 1,
			Text = Text.get(use, "contract.waiting", { level = contract.level }),
			TextWrapped = true,
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	local header = Text.get(use, "contract.board.title", { done = state.done, max = Quests.Contracts.MAX_LEVEL })
	if backlog > 1 then
		header ..= `   <font color="#9A9DA8">{Text.get(use, "contract.backlog", { n = backlog })}</font>`
	end
	local objective = contract.objectives[1]
	return s:New("Frame")({
		Size = UDim2.new(1, 0, 0, CONTRACT_HEIGHT - 8),
		BackgroundTransparency = 1,
		[Children] = {
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				RichText = true,
				Text = header,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Parchment,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 134),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = 0.35,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("UIPadding")({ PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 8) }),
					s:New("TextLabel")({
						Size = UDim2.new(1, -170, 0, 24),
						BackgroundTransparency = 1,
						Text = QuestText.contractTitle(lookup, contract),
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = if active or canTake then Theme.Colors.GoldBright else Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = 20, MinTextSize = 14 }),
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(0, 25),
						Size = UDim2.new(1, -170, 0, 20),
						BackgroundTransparency = 1,
						RichText = true,
						Text = areaLine,
						TextTruncate = Enum.TextTruncate.AtEnd,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(0, 46),
						Size = UDim2.new(1, -170, 0, 24),
						BackgroundTransparency = 1,
						Text = QuestText.objective(use, objective, progress[1] or 0),
						TextScaled = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextColor3 = if done then Theme.Colors.Success else Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = 17, MinTextSize = 11 }),
					}),
					QuestRewards(s, {
						Id = "contract",
						Reward = contract.reward,
						SlotSize = 38,
						Position = UDim2.fromOffset(0, 76),
						Width = UDim.new(1, -170),
					}),
					action,
				},
			}),
		},
	})
end

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

local function QuestBoard(scope: Scope, props: Props?): Fusion.Child
	local p: Props = props or {}
	local quests = State.Value({ "character", "quests" })
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

	-- S99: the hunting contract over both tabs
	local contract = scope:Computed(function(use, s: Scope): Instance?
		return contractSection(s, use, use(quests), use(level) or 1, p)
	end)
	local top = scope:Computed(function(use): number
		return if use(contract) then CONTRACT_HEIGHT else 0
	end)

	return {
		contract :: any,
		scope:New("Frame")({
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, use(top))
			end),
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 1, -use(top))
			end),
			BackgroundTransparency = 1,
			[Children] = {
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
						return Text.get(
							use,
							"quest.dailyReset",
							{ time = Time.format((Time.dayNumber(t) + 1) * 86400 - t) }
						)
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
			},
		}),
	}
end

return QuestBoard
