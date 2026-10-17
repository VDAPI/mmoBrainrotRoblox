--!strict
-- Contract board on the plaza (DESIGN §20): today's three contracts with progress, rewards and "Collect",
-- and the time until the new set at 00:00 UTC. S98 (docs/DESIGN-15.md §3.1): a second tab with the week's three
-- contracts (new set on Monday 00:00 UTC) and the week's boss contract (no card below the first boss's entry level);
-- the list scrolls (phones). S99 (§3.3): over both tabs the hunting contract (the active one with "Hand in" once done
-- and "Track" before, or the next one with "Accept", or "Next contract from level N" instead of a button; hidden once
-- all 99 are done), its hunting ground in the colour of its level band with the S33 profile, and the backlog. S134k: the
-- hunting contracts' counts (to take, active, finished), the Hunter's Marks and "Accept all" / "Hand in all" instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local ContractActions = require(script.Parent.Parent.ContractActions)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local NpcPresence = require(script.Parent.Parent.NpcPresence)
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

-- S99: "Track" on the board (QuestController.Track). S134k: tracking moved to the journal's rows (kept for the caller).
export type Props = {
	Tracked: Fusion.Value<boolean>?,
	Focus: Fusion.Value<QuestTrack.Focus>?,
	Track: ((focus: QuestTrack.Focus) -> ())?,
}

local CONTRACT_HEIGHT = 168 -- header 26 + card 134 + gap 8

-- S99: the hunting contract section (nil when every contract is done or the list is empty). S134k: the counts of the
-- contracts to take, active and finished, the Hunter's Marks and "Accept all" / "Hand in all" at this NPC.
local function contractSection(s: Scope, use: Fusion.Use, quests: any, lvl: number, _props: Props): Instance?
	local state = Contracts.stateOf(quests)
	if Contracts.allDone(state) or #Quests.Contracts.list == 0 then
		return nil
	end
	-- S134k: the NPC the player talks to (the board; the Huntmaster's "quests" opens the journal instead)
	local npcId = use(NpcPresence.Current) or Contracts.BOARD
	local canTake = #Contracts.acceptable(state, lvl, npcId)
	local canHand = #Contracts.ready(state, npcId)
	local header =
		Text.get(use, "contract.board.title", { done = Contracts.doneCount(state), max = Quests.Contracts.MAX_LEVEL })
	header ..= `   <font color="#9BC46A">{Text.get(use, "contract.marks", { n = state.marks })}</font>`
	local counts = Text.get(use, "contract.boardCounts", {
		available = #Contracts.eligible(state, lvl),
		active = #state.active,
		ready = #Contracts.complete(state),
	})
	local nextOne = Contracts.upcoming(state, lvl, 1)[1]
	local hint = if canTake == 0
			and canHand == 0
			and nextOne
		then Text.get(use, "contract.waiting", { level = nextOne.level })
		else Text.get(use, "contract.boardHint")
	local function button(order: number, key: string, n: number, act: () -> ()): Instance
		return Button(s, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(200, 44),
			Variant = "primary",
			Disabled = n == 0,
			Text = Text.get(use, key, { n = n }),
			OnClick = act,
		})
	end
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
					s:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 8),
					}),
					s:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = counts,
						TextScaled = true,
						FontFace = Theme.Fonts.BodyBold,
						TextColor3 = Theme.Colors.GoldBright,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = s:New("UITextSizeConstraint")({ MaxTextSize = 19, MinTextSize = 12 }),
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(0, 26),
						Size = UDim2.new(1, 0, 0, 40),
						BackgroundTransparency = 1,
						Text = hint,
						TextWrapped = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
					s:New("Frame")({
						Position = UDim2.fromOffset(0, 70),
						Size = UDim2.new(1, 0, 0, 48),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 10),
							}),
							button(1, "contract.acceptAll", canTake, function()
								ContractActions.acceptAll(npcId)
							end),
							button(2, "contract.turnInAll", canHand, function()
								ContractActions.turnInAll(npcId)
							end),
						},
					}),
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
