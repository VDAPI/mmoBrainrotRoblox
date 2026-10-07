--!strict
-- Quest journal (L): Main / Side / Daily tabs. Main: the active story quest (or the next one and where to get it),
-- the story so far as a list. Side (S27): the side quests by arc (arc name, "2/5"), every active one with its
-- objectives, "Track" (one tracked quest at a time: the story or a side quest) and "Abandon" (asks first); then the
-- quests on offer within reach of the level and where to get them. Daily: today's three contracts with progress and
-- the time to the reset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Modal = require(script.Parent.Parent.Components.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRewards = require(script.Parent.Parent.Components.QuestRewards)
local QuestText = require(script.Parent.Parent.QuestText)
local QuestTrack = require(script.Parent.Parent.QuestTrack)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Tracked: Fusion.Value<boolean>,
	Focus: Fusion.Value<QuestTrack.Focus>,
	Track: (focus: QuestTrack.Focus) -> (),
	ShowModal: (spec: Modal.Spec) -> (),
}

local function label(
	scope: Scope,
	order: number,
	text: Fusion.UsedAs<string>,
	font: Font,
	size: number,
	color: Color3
): Instance
	return scope:New("TextLabel")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = text,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function QuestJournal(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("main")
	local quests = State.Value({ "character", "quests" })
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

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local q = use(quests)
		local list = {}
		if type(q) ~= "table" then
			return list
		end
		if use(tab) == "main" then
			local main = q.main
			local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
			if quest and main then
				local giver = Npcs.get(quest.giver)
				-- Title with the quest giver underneath (S18).
				local title = Text.get(use, `quest.{quest.id}.title`)
				local giverLine =
					Text.get(use, "quest.journal.giver", { npc = if giver then Text.get(use, giver.nameKey) else "?" })
				table.insert(
					list,
					label(
						s,
						1,
						title .. '\n<font size="16" color="#9A9DA8">' .. giverLine .. "</font>",
						Theme.Fonts.Heading,
						26,
						Theme.Colors.GoldBright
					)
				)
				table.insert(
					list,
					label(s, 2, Text.get(use, `quest.{quest.id}.text`), Theme.Fonts.Body, 17, Theme.Colors.Parchment)
				)
				-- S29: every objective stays (finished ones green), then "Return to: <NPC>" (Logic/QuestRows).
				local lines =
					QuestText.richRows(use, QuestText.rows(use, quest.objectives, main.progress, quest.turnIn))
				table.insert(
					list,
					label(s, 3, table.concat(lines, "\n"), Theme.Fonts.BodyMedium, 17, Theme.Colors.Text)
				)
				table.insert(
					list,
					QuestRewards(s, { Id = quest.id, Reward = quest.reward, ShowTitle = true, LayoutOrder = 4 })
				)
				table.insert(
					list,
					Button(s, {
						LayoutOrder = 5,
						Size = UDim2.fromOffset(200, 44),
						Text = s:Computed(function(use2): string
							local tracked = use2(props.Tracked) and use2(props.Focus) == nil
							return Text.get(use2, if tracked then "quest.untrack" else "quest.track")
						end),
						OnClick = function()
							if Fusion.peek(props.Focus) ~= nil then
								props.Track(nil)
							else
								props.Tracked:set(not Fusion.peek(props.Tracked))
							end
						end,
					})
				)
			else
				local nextQuest, ready = QuestLogic.nextMain(q.mainDone or 0, use(level) or 1)
				if nextQuest then
					local giver = Npcs.get(nextQuest.giver)
					table.insert(
						list,
						label(
							s,
							1,
							Text.get(use, `quest.{nextQuest.id}.title`),
							Theme.Fonts.Heading,
							26,
							Theme.Colors.GoldBright
						)
					)
					table.insert(
						list,
						label(
							s,
							2,
							if ready
								then Text.get(
									use,
									"quest.getFrom",
									{ npc = if giver then Text.get(use, giver.nameKey) else "?" }
								)
								else Text.get(
									use,
									"quest.nextAt",
									{ level = nextQuest.level - Quests.Main.LEVEL_SLACK }
								),
							Theme.Fonts.BodyMedium,
							18,
							Theme.Colors.Parchment
						)
					)
				else
					table.insert(
						list,
						label(s, 1, Text.get(use, "quest.storyDone"), Theme.Fonts.Heading, 24, Theme.Colors.GoldBright)
					)
				end
			end
			-- Story so far
			local done = {}
			for i = 1, q.mainDone or 0 do
				local finished = Quests.Main.list[i]
				if finished then
					table.insert(done, `✔ {Text.get(use, `quest.{finished.id}.title`)}`)
				end
			end
			if #done > 0 then
				table.insert(
					list,
					label(s, 10, `<b>{Text.get(use, "quest.history")}</b>`, Theme.Fonts.BodyBold, 17, Theme.Colors.Gold)
				)
				table.insert(list, label(s, 11, table.concat(done, "\n"), Theme.Fonts.Body, 15, Theme.Colors.TextMuted))
			end
		elseif use(tab) == "side" then
			local order = 0
			local function add(item: Instance)
				order += 1
				(item :: any).LayoutOrder = order
				table.insert(list, item)
			end
			local lvl = use(level) or 1
			local active = SideQuests.activeOf(q)
			local anything = false
			for _, arc in Quests.Side.ARCS do
				local done, total = SideQuests.arcProgress(q, arc)
				local arcQuests: { Quests.SideQuest } = Quests.Side.byArc[arc] or {}
				local shown: { Instance } = {}
				for _, quest in arcQuests do
					local entry = active[quest.id]
					if type(entry) ~= "table" then
						continue
					end
					local rows = QuestText.rows(use, quest.objectives, entry.progress, quest.turnIn)
					local lines = QuestText.richRows(use, rows)
					local giver = Npcs.get(quest.giver)
					local from = Text.get(
						use,
						"quest.journal.giver",
						{ npc = if giver then Text.get(use, giver.nameKey) else "?" }
					)
					local title = Text.get(use, `quest.{quest.id}.title`)
					table.insert(
						shown,
						label(
							s,
							0,
							`<b>{title}</b>  <font size="14" color="#9A9DA8">{from}</font>`,
							Theme.Fonts.BodyBold,
							19,
							Theme.Colors.GoldBright
						)
					)
					table.insert(
						shown,
						label(
							s,
							0,
							Text.get(use, `quest.{quest.id}.progress`),
							Theme.Fonts.Body,
							15,
							Theme.Colors.Parchment
						)
					)
					table.insert(
						shown,
						label(s, 0, table.concat(lines, "\n"), Theme.Fonts.BodyMedium, 16, Theme.Colors.Text)
					)
					table.insert(
						shown,
						QuestRewards(s, { Id = quest.id, Reward = quest.reward, ShowTitle = true, SlotSize = 36 })
					)
					local id = quest.id
					table.insert(
						shown,
						s:New("Frame")({
							Size = UDim2.new(1, 0, 0, 40),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									Padding = UDim.new(0, 8),
								}),
								Button(s, {
									Size = UDim2.fromOffset(150, 40),
									Variant = "secondary",
									Text = s:Computed(function(use2): string
										local focus = use2(props.Focus)
										local tracked = use2(props.Tracked) and focus ~= nil and focus.id == id
										return Text.get(use2, if tracked then "quest.untrack" else "quest.track")
									end),
									OnClick = function()
										local focus = Fusion.peek(props.Focus)
										if focus and focus.id == id then
											props.Track(nil)
										else
											props.Track({ kind = "side", id = id })
										end
									end,
								}),
								Button(s, {
									Size = UDim2.fromOffset(150, 40),
									Variant = "ghost",
									Text = Text.T(s, "quest.abandon"),
									OnClick = function()
										props.ShowModal({
											Title = Text.now("quest.abandonTitle"),
											Message = Text.now(
												"quest.abandonText",
												{ title = Text.now(`quest.{id}.title`) }
											),
											ConfirmText = Text.now("quest.abandon"),
											CancelText = Text.now("quest.back"),
											Variant = "danger",
											OnConfirm = function(): (boolean, string?)
												local ok, err = Net.Invoke("SideAbandon", id)
												if not ok then
													return false, Text.now(err or "error.internal")
												end
												return true, nil
											end,
										})
									end,
								}),
							},
						})
					)
				end
				-- On offer now: where to get them.
				for _, quest in arcQuests do
					if SideQuests.canAccept(q, lvl, quest) then
						local giver = Npcs.get(quest.giver)
						local getFrom = Text.get(
							use,
							"quest.getFrom",
							{ npc = if giver then Text.get(use, giver.nameKey) else "?" }
						)
						local title = Text.get(use, `quest.{quest.id}.title`)
						table.insert(
							shown,
							label(
								s,
								0,
								`<font color="#E8C25A">!</font> {title}  <font size="14" color="#9A9DA8">{getFrom}</font>`,
								Theme.Fonts.BodyMedium,
								16,
								Theme.Colors.Parchment
							)
						)
					end
				end
				if #shown > 0 or done > 0 then
					anything = true
					local arcName = Text.get(use, `quest.arc.{arc}`)
					add(
						label(
							s,
							0,
							`{arcName}  <font color="#9A9DA8">{done}/{total}</font>`,
							Theme.Fonts.Heading,
							22,
							if done == total then Theme.Colors.Success else Theme.Colors.Gold
						)
					)
					for _, item in shown do
						add(item)
					end
				end
			end
			if not anything then
				add(label(s, 0, Text.get(use, "quest.side.none"), Theme.Fonts.Body, 17, Theme.Colors.TextMuted))
			end
			local count =
				Text.get(use, "quest.side.count", { n = SideQuests.activeCount(q), max = Config.SideQuest.maxActive })
			add(label(s, 0, count, Theme.Fonts.Body, 14, Theme.Colors.TextMuted))
		else
			local daily = q.daily
			table.insert(
				list,
				label(
					s,
					0,
					"<b>"
						.. Text.get(use, "npc.questboard.name")
						.. "</b>\n"
						.. Text.get(
							use,
							"quest.dailyReset",
							{ time = Time.format((Time.dayNumber(use(now)) + 1) * 86400 - use(now)) }
						),
					Theme.Fonts.BodyMedium,
					16,
					Theme.Colors.TextMuted
				)
			)
			local dailyReward = Quests.Daily.reward(use(level) or 1)
			for i, entry in (if type(daily) == "table" then daily.list else {}) or {} do
				local status = if entry.claimed
					then ` <font color="#8E8E93">({Text.get(use, "quest.claimed")})</font>`
					elseif entry.progress >= entry.objective.n then ` <font color="#4FD16B">({Text.get(
						use,
						"quest.claimAtBoard"
					)})</font>`
					else ""
				table.insert(
					list,
					label(
						s,
						i * 3,
						`<b>{Text.get(use, `daily.{entry.template}.title`)}</b>{status}`,
						Theme.Fonts.BodyBold,
						18,
						Theme.Colors.GoldBright
					)
				)
				table.insert(
					list,
					label(
						s,
						i * 3 + 1,
						QuestText.objective(use, entry.objective, entry.progress),
						Theme.Fonts.Body,
						16,
						Theme.Colors.Text
					)
				)
				if not entry.claimed then
					table.insert(
						list,
						QuestRewards(
							s,
							{ Id = `daily{i}`, Reward = dailyReward, SlotSize = 34, LayoutOrder = i * 3 + 2 }
						)
					)
				end
			end
		end
		return list
	end)

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = {
				{ id = "main", label = Text.T(scope, "quest.tab.main") },
				{ id = "side", label = Text.T(scope, "quest.tab.side") },
				{ id = "daily", label = Text.T(scope, "quest.tab.daily") },
			},
		}),
		scope:New("ScrollingFrame")({
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				content :: any,
			},
		}),
	}
end

return QuestJournal
