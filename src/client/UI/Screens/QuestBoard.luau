--!strict
-- Contract board on the plaza (DESIGN §20): today's three contracts with progress, rewards and "Collect",
-- and the time until the new set at 00:00 UTC. S98 (docs/DESIGN-15.md §3.1): a second tab with the week's three
-- contracts (new set on Monday 00:00 UTC) and the week's boss contract (no card below the first boss's entry level);
-- the list scrolls (phones). S99 (§3.3): over both tabs the hunting contract (the active one with "Hand in" once done
-- and "Track" before, or the next one with "Accept", or "Next contract from level N" instead of a button; hidden once
-- all 99 are done), its hunting ground in the colour of its level band with the S33 profile, and the backlog. S134k: the
-- hunting contracts' counts (to take, active, finished), the Hunter's Marks and "Accept all" / "Hand in all" instead.
-- S159 (owner 2026-10-20): over the list the set's progress ("Today's contracts 2/4"), the time to the new set and the
-- account's streak; "Swap" on an open daily contract while today's free reroll is left; under the contracts the set
-- bonus card (EXP with the streak, blessings, Dragon Shards; why there are no shards: taken on this account, level).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local ContractActions = require(script.Parent.Parent.ContractActions)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Dailies = require(ReplicatedStorage.Shared.Logic.Dailies)
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
	header ..= `   <font color="{Theme.hex(Theme.Paper.Success)}">{Text.get(use, "contract.marks", { n = state.marks })}</font>`
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
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 134),
				BackgroundColor3 = Theme.Paper.Raised,
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
						TextColor3 = Theme.Paper.Heading,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = s:New("UITextSizeConstraint")({
							MaxTextSize = Theme.TextSize.Body,
							MinTextSize = Theme.TextSize.Small,
						}),
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(0, 26),
						Size = UDim2.new(1, 0, 0, 40),
						BackgroundTransparency = 1,
						Text = hint,
						TextWrapped = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.TextMuted,
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
	reroll: (() -> ())?, -- S159: "Swap" (nil = no button)
}

-- S159: runs a board action and shows its error.
local function act(fn: () -> (boolean, string?), after: (() -> ())?)
	task.spawn(function()
		local ok, err = fn()
		if not ok then
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		elseif after then
			after()
		end
	end)
end

local function card(s: Scope, use: Fusion.Use, c: Card): Instance
	return s:New("Frame")({
		LayoutOrder = c.order,
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundColor3 = Theme.Paper.Raised,
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
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = s:New("UITextSizeConstraint")({
					MaxTextSize = Theme.TextSize.Body,
					MinTextSize = Theme.TextSize.Small,
				}),
			}),
			s:New("TextLabel")({
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.new(1, -170, 0, 28),
				BackgroundTransparency = 1,
				Text = c.line,
				TextWrapped = true,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyMedium,
				TextColor3 = if c.done then Theme.Paper.Success else Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = s:New("UITextSizeConstraint")({
					MaxTextSize = Theme.TextSize.Small,
					MinTextSize = Theme.TextSize.Small,
				}),
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
				Position = UDim2.new(1, -10, 0.5, if c.reroll then 12 else -4),
				Size = UDim2.fromOffset(150, if c.reroll then 44 else 50),
				Variant = "primary",
				Text = Text.get(use, if c.claimed then "quest.claimed" else "quest.claim"),
				Disabled = c.claimed or not c.done,
				OnClick = function()
					act(c.claim)
				end,
			}),
			if c.reroll
				then Button(s, {
					Name = "Reroll",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 0),
					Size = UDim2.fromOffset(150, 30),
					Variant = "ghost",
					TextSize = Theme.TextSize.Small,
					Text = `⟳ {Text.get(use, "quest.reroll")}`,
					OnClick = c.reroll,
				}) :: any
				else nil,
		},
	})
end

-- S159: the set bonus card: what the bonus gives now (EXP with the streak it would pay, blessings, shards when they are
-- still due on this account), whether it is taken, and the streak rule (daily only).
local function bonusCard(
	s: Scope,
	use: Fusion.Use,
	id: string,
	reward: Quests.Reward,
	lines: { string },
	taken: boolean
)
	local text = `<b>{Text.get(use, if taken then "quest.set.bonusTaken" else "quest.set.bonus")}</b>`
	for _, line in lines do
		text ..= `\n<font color="{Theme.hex(Theme.Paper.TextMuted)}">{line}</font>`
	end
	return s:New("Frame")({
		LayoutOrder = 200,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = if taken then 0.6 else 0.2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("UIStroke")({
				Color = if taken then Theme.Paper.TextMuted else Theme.Paper.Heading,
				Thickness = 1,
				Transparency = 0.4,
			}),
			s:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			s:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				RichText = true,
				TextWrapped = true,
				Text = text,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			if taken
				then nil :: any
				else QuestRewards(s, { Id = id, Reward = reward, SlotSize = 38, LayoutOrder = 2 }) :: any,
		},
	})
end

-- S159: the lines under the bonus card's title (why there are no shards, the streak rule).
local function bonusLines(
	use: Fusion.Use,
	reward: Quests.Reward,
	shardsDue: boolean,
	level: number,
	weekly: boolean
): ({ string }, Quests.Reward)
	local lines = {}
	local shown = table.clone(reward)
	if not shardsDue then
		shown.shards = nil
		if level < Quests.Daily.SHARD_MIN_LEVEL then
			table.insert(lines, Text.get(use, "quest.set.shardsLevel", { level = Quests.Daily.SHARD_MIN_LEVEL }))
		else
			table.insert(lines, Text.get(use, if weekly then "quest.set.shardsTakenWeek" else "quest.set.shardsTaken"))
		end
	end
	table.insert(lines, Text.get(use, "quest.set.bonusHint"))
	if not weekly then
		local b = Quests.Daily.BONUS
		table.insert(
			lines,
			Text.get(
				use,
				"quest.set.streakHint",
				{ cap = Quests.Daily.STREAK_CAP, from = b.streakShardsFrom, n = b.streakShards }
			)
		)
	end
	return lines, shown
end

local function QuestBoard(scope: Scope, props: Props?): Fusion.Child
	local p: Props = props or {}
	local quests = State.Value({ "character", "quests" })
	local daily = State.Value({ "character", "quests", "daily" })
	local weekly = State.Value({ "character", "quests", "weekly" })
	local level = State.Value({ "character", "level" })
	local account = State.Value({ "account", "dailies" }) -- S159: the streak and the account's bonus shards
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
				local canReroll = Dailies.canReroll(d, i)
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
						reroll = if canReroll
							then function()
								act(function()
									return Net.Invoke("DailyReroll", i)
								end, function()
									local now = State.Get({ "character", "quests", "daily", "list", i, "template" })
									if type(now) == "string" then
										Toast.push(
											Text.now("quest.reroll.ok", { title = Text.now(`daily.{now}.title`) }),
											"success"
										)
									end
								end)
							end
							else nil,
					})
				)
			end
			-- S159: the set bonus with the streak it would pay
			local state = Dailies.sanitize(use(account))
			local today = Time.dayNumber(use(now))
			local streak = Dailies.nextStreak(state, today)
			local lines, shown =
				bonusLines(use, Quests.Daily.bonus(lvl, streak), Dailies.dayShardsDue(state, today, lvl), lvl, false)
			if #(d.list or {}) > 0 then
				table.insert(list, bonusCard(s, use, "dailyBonus", shown, lines, d.bonus == true))
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
		-- S159: the weekly set bonus (the boss contract is apart from the set)
		if #(w.list or {}) > 0 then
			local state = Dailies.sanitize(use(account))
			local lines, shown =
				bonusLines(use, Quests.Weekly.bonus(lvl), Dailies.weekShardsDue(state, w.week or 0, lvl), lvl, true)
			table.insert(list, bonusCard(s, use, "weeklyBonus", shown, lines, w.bonus == true))
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
				-- S159: the set's progress, the time to the new set and (daily) the streak and the free swap
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(0, 46),
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					RichText = true,
					TextWrapped = true,
					Text = scope:Computed(function(use): string
						local t = use(now)
						local muted = Theme.hex(Theme.Paper.TextMuted)
						if use(tab) == "weekly" then
							local w = use(weekly)
							local p = Dailies.progress(if type(w) == "table" then w.list else nil)
							local days, hours = Time.split(Time.weekStart(Time.weekNumber(t) + 1) - t)
							return `<b>{Text.get(use, "quest.set.weekly", { done = p.complete, total = p.total })}</b>`
								.. `  <font color="{muted}">{Text.get(
									use,
									"quest.weeklyReset",
									{ days = days, hours = hours }
								)}</font>`
						end
						local d = use(daily)
						local p = Dailies.progress(if type(d) == "table" then d.list else nil)
						local today = Time.dayNumber(t)
						local streak = Dailies.streakNow(Dailies.sanitize(use(account)), today)
						local swaps =
							math.max(0, Quests.Daily.REROLLS - (if type(d) == "table" then d.swaps or 0 else 0))
						return `<b>{Text.get(use, "quest.set.daily", { done = p.complete, total = p.total })}</b>`
							.. `  <font color="{muted}">{Text.get(
								use,
								"quest.dailyReset",
								{ time = Time.format((today + 1) * 86400 - t) }
							)}</font>\n`
							.. `<font color="{Theme.hex(Theme.Paper.Heading)}">{if streak > 0
								then Text.get(use, "quest.set.streak", { n = streak })
								else Text.get(use, "quest.set.streakNone")}</font>`
							.. `  <font color="{muted}">{Text.get(use, "quest.reroll.left", { n = swaps })}</font>`
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				scope:New("ScrollingFrame")({
					Position = UDim2.fromOffset(0, 94),
					Size = UDim2.new(1, 0, 1, -94),
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
