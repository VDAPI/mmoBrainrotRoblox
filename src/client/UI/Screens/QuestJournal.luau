--!strict
-- Quest journal (L): Main / Side / Daily tabs. Main: the active story quest (or the next one and where to get it),
-- the story so far as a list. Side (S27): the side quests by arc (arc name, "2/5"), every active one with its
-- objectives, "Track" (one tracked quest at a time: the story or a side quest) and "Abandon" (asks first); then the
-- quests on offer within reach of the level and where to get them. Daily: today's three contracts with progress and
-- the time to the reset. S98 (docs/DESIGN-15.md §3.1): one tab per category in Quests.CATEGORIES order on a scrolling
-- strip (six tabs on a phone): Contracts (only once Data/Quests/Contracts has any, S99), Bosses (the four Slayer
-- quests with their entry level, where to take them, progress and "Track", then the week's boss contract) and Weekly
-- (the week's three contracts and the countdown to Monday 00:00 UTC). S99: the hunting contracts tab ("Hunting"):
-- done / 99, the backlog, the active or next contract with "Track" and where to hand it in, the next three. S134k: every
-- active contract grouped by hunting ground ("Track" / "Abandon"), the Hunter's Marks, "Accept all" / "Hand in all" at
-- a giver (UI/NpcPresence) and the Huntmaster's shop, the contracts to take (folded) and the next three.
-- S159: the daily and weekly tabs show the set's progress and (daily) the streak, "Swap" on an open daily contract while
-- today's free reroll is left, and the set bonus under the contracts.
-- S102: the story tab names the chapter over the active or next quest (story.chapter.<n>), lets the player read the
-- offer pages again ("Recall the conversation", variants by earlier answers) and groups the story so far by chapter,
-- one row per quest with "▶" to watch its cutscenes again (only scenes already watched; props.Replay).
-- Owner 2026-10-21 (too many detailed descriptions): a quest card shows its title, objectives and rewards; the story
-- text (and "Recall the conversation") or the progress paragraph of a side / boss quest sit under "More" (Details),
-- rules behind an "i" (InfoTip).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local ContractActions = require(script.Parent.Parent.ContractActions)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Dailies = require(ReplicatedStorage.Shared.Logic.Dailies)
local Cutscenes = require(ReplicatedStorage.Shared.Logic.Cutscenes)
local Details = require(script.Parent.Parent.Components.Details)
local Dialogue = require(ReplicatedStorage.Shared.Logic.Dialogue)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Modal = require(script.Parent.Parent.Components.Modal)
local Net = require(ReplicatedStorage.Shared.Net)
local Toast = require(script.Parent.Parent.Components.Toast)
local NpcPresence = require(script.Parent.Parent.NpcPresence)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestItemIcons = require(script.Parent.Parent.Components.QuestItemIcons)
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
local Tooltip = require(script.Parent.Parent.Components.Tooltip)

local Children = Fusion.Children

-- Owner 2026-10-22 (Studio: the 36 px "▶" did not hold its glyph): the story row's replay button, wide enough for
-- its glyph with the button's padding (tests/uifit.spec)
local REPLAY_WIDTH = 44

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Tracked: Fusion.Value<boolean>,
	Focus: Fusion.Value<QuestTrack.Focus>,
	Track: (focus: QuestTrack.Focus) -> (),
	ShowModal: (spec: Modal.Spec) -> (),
	Replay: ((sceneId: string) -> ())?, -- S102: watch a story cutscene again (CutsceneController.Play)
	-- S134k: the selected tab (QuestController opens the journal on "contract" at a giver) and the Huntmaster's shop
	Tab: Fusion.Value<string>?,
	OpenShop: (() -> ())?,
}

-- S102: whether a page key has text in both languages (page variants of `recall`).
local function hasText(key: string): boolean
	return Locale.has(key, "pl") and Locale.has(key, "en")
end

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

-- Owner 2026-10-21: a line with an "i" on its right that holds the longer text.
local function infoRow(scope: Scope, child: Instance, info: Fusion.UsedAs<string>): Instance
	(child :: any).Size = UDim2.new(1, -32, 0, 0)
	return scope:New("Frame")({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			child,
			InfoTip.new(scope, {
				Text = info,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
			}),
		},
	})
end

-- S98: the tabs in Quests.CATEGORIES order; the contracts appear once S99 fills Data/Quests/Contracts.
local function tabIds(): { string }
	local ids = {}
	for _, category in Quests.CATEGORIES do
		if category ~= "contract" or #Quests.Contracts.list > 0 then
			table.insert(ids, category)
		end
	end
	return ids
end

-- S98: a daily or weekly contract list (title prefix "daily" / "weekly"), the reward under every open one.
local function contractRows(
	s: Scope,
	use: Fusion.Use,
	list: { any },
	prefix: string,
	reward: Quests.Reward,
	into: { Instance },
	reroll: ((index: number) -> ())? -- S159: "Swap" on the daily contracts that may be rerolled
)
	for i, entry in list do
		local status = if entry.claimed
			then ` <font color="{Theme.hex(Theme.Paper.TextMuted)}">({Text.get(use, "quest.claimed")})</font>`
			elseif entry.progress >= entry.objective.n then ` <font color="{Theme.hex(Theme.Paper.Success)}">({Text.get(
				use,
				"quest.claimAtBoard"
			)})</font>`
			else ""
		table.insert(
			into,
			label(
				s,
				i * 3,
				`<b>{Text.get(use, `{prefix}.{entry.template}.title`)}</b>{status}`,
				Theme.Fonts.BodyBold,
				Theme.TextSize.Small,
				Theme.Paper.Heading
			)
		)
		table.insert(
			into,
			label(
				s,
				i * 3 + 1,
				QuestText.objective(use, entry.objective, entry.progress),
				Theme.Fonts.Body,
				Theme.TextSize.Small,
				Theme.Paper.Text
			)
		)
		if not entry.claimed then
			local rewards = QuestRewards(s, { Id = `{prefix}{i}`, Reward = reward, SlotSize = 34 })
			if reroll and entry.progress < entry.objective.n then
				-- S159: the rewards with "Swap" on the right
				table.insert(
					into,
					s:New("Frame")({
						LayoutOrder = i * 3 + 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = {
							s:New("Frame")({
								Size = UDim2.new(1, -130, 0, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								[Children] = rewards,
							}),
							Button(s, {
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.fromOffset(120, 32),
								Variant = "ghost",
								TextSize = Theme.TextSize.Small,
								Text = `⟳ {Text.get(use, "quest.reroll")}`,
								OnClick = function()
									reroll(i)
								end,
							}),
						},
					})
				)
			else
				(rewards :: any).LayoutOrder = i * 3 + 2
				table.insert(into, rewards)
			end
		end
	end
end

-- S159: the set bonus under a daily / weekly list: its title, the rewards while not taken (shards only when still due
-- on this account).
local function setBonusRows(
	s: Scope,
	use: Fusion.Use,
	id: string,
	reward: Quests.Reward,
	shardsDue: boolean,
	taken: boolean,
	into: { Instance }
)
	local shown = table.clone(reward)
	if not shardsDue then
		shown.shards = nil
	end
	table.insert(
		into,
		label(
			s,
			100,
			`<b>{Text.get(use, if taken then "quest.set.bonusTaken" else "quest.set.bonus")}</b>`,
			Theme.Fonts.BodyBold,
			Theme.TextSize.Small,
			if taken then Theme.Paper.TextMuted else Theme.Paper.Heading
		)
	)
	if not taken then
		table.insert(into, QuestRewards(s, { Id = id, Reward = shown, SlotSize = 34, LayoutOrder = 101 }))
	end
end

-- S159: one daily reroll (errors as a toast).
local function rerollDaily(index: number)
	task.spawn(function()
		local ok, err = Net.Invoke("DailyReroll", index)
		if not ok then
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

local function QuestJournal(scope: Scope, props: Props): Fusion.Child
	local tab: Fusion.Value<string> = props.Tab or (scope:Value("main") :: any)
	local availableOpen = scope:Value(false) -- S134k: the hunting contracts to take (folded)
	local ids = tabIds()
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

	-- Track and Abandon for an active side (or boss) quest.
	local function sideButtons(s: Scope, id: string): Instance
		return s:New("Frame")({
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
							Message = Text.now("quest.abandonText", { title = Text.now(`quest.{id}.title`) }),
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
	end

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local q = use(quests)
		local list = {}
		if type(q) ~= "table" then
			return list
		end
		if use(tab) == "main" then
			local main = q.main
			local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
			-- S102: the chapter of the active or next quest
			local current = quest or QuestLogic.nextMain(q.mainDone or 0, use(level) or 1)
			if current then
				table.insert(
					list,
					label(
						s,
						0,
						Text.get(use, `story.chapter.{Quests.Main.chapterOf(current.id)}`),
						Theme.Fonts.BodyBold,
						Theme.TextSize.Small,
						Theme.Paper.TextMuted
					)
				)
			end
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
						`{title}\n<font size="{Theme.TextSize.Small}" color="{Theme.hex(Theme.Paper.TextMuted)}">{giverLine}</font>`,
						Theme.Fonts.Display,
						Theme.TextSize.Large,
						Theme.Paper.Heading
					)
				)
				-- owner 2026-10-21: the story text and "Recall the conversation" under "More" (Details)
				local story: { Instance } = {
					label(
						s,
						1,
						Text.get(use, `quest.{quest.id}.text`),
						Theme.Fonts.Body,
						Theme.TextSize.Small,
						Theme.Paper.Text
					),
				}
				-- S102: the offer pages again (with the variants of earlier answers)
				local pages = quest.pages
				if pages then
					local storyQuest = quest
					table.insert(
						story,
						Button(s, {
							LayoutOrder = 2,
							Size = UDim2.fromOffset(220, 40),
							Variant = "ghost",
							Text = Text.T(s, "quest.journal.pages"),
							OnClick = function()
								local saved = State.Get({ "character", "quests" })
								local texts: { string } = {}
								for i = 1, pages do
									table.insert(texts, Text.now(Dialogue.pageKey(storyQuest, `p{i}`, saved, hasText)))
								end
								props.ShowModal({
									Title = Text.now(`quest.{storyQuest.id}.title`),
									Message = table.concat(texts, "\n\n"),
									ConfirmText = Text.now("quest.back"),
								})
							end,
						})
					)
				end
				table.insert(list, Details.new(s, { Key = "journal.main.story", LayoutOrder = 2, Children = story }))
				-- S29: every objective stays (finished ones green), then "Return to: <NPC>" (Logic/QuestRows).
				local lines =
					QuestText.richRows(use, QuestText.rows(use, quest.objectives, main.progress, quest.turnIn))
				table.insert(
					list,
					label(
						s,
						3,
						table.concat(lines, "\n"),
						Theme.Fonts.BodyMedium,
						Theme.TextSize.Small,
						Theme.Paper.Text
					)
				)
				-- S118: pictures of the quest items (nothing without them)
				local questItems = QuestItemIcons(s, use, quest.objectives, 4)
				if questItems then
					table.insert(list, questItems)
				end
				table.insert(
					list,
					QuestRewards(s, { Id = quest.id, Reward = quest.reward, ShowTitle = true, LayoutOrder = 5 })
				)
				table.insert(
					list,
					Button(s, {
						LayoutOrder = 6,
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
							Theme.Fonts.Display,
							Theme.TextSize.Large,
							Theme.Paper.Heading
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
							Theme.TextSize.Small,
							Theme.Paper.Text
						)
					)
				else
					table.insert(
						list,
						label(
							s,
							1,
							Text.get(use, "quest.storyDone"),
							Theme.Fonts.Display,
							Theme.TextSize.Large,
							Theme.Paper.Heading
						)
					)
				end
			end
			-- Story so far (S102: by chapter, one row per quest, "▶" for its watched cutscenes)
			local doneCount = math.min(q.mainDone or 0, #Quests.Main.list)
			if doneCount > 0 then
				table.insert(
					list,
					label(
						s,
						10,
						`<b>{Text.get(use, "quest.history")}</b>`,
						Theme.Fonts.BodyBold,
						Theme.TextSize.Small,
						Theme.Paper.Heading
					)
				)
			end
			local scenes: { [string]: boolean } = if type(q.scenes) == "table" then q.scenes else {}
			local chapter = 0
			for i = 1, doneCount do
				local finished = Quests.Main.list[i]
				local n = Quests.Main.chapterOf(finished.id)
				if n ~= chapter then
					chapter = n
					table.insert(
						list,
						label(
							s,
							10 + i * 2,
							Text.get(use, `story.chapter.{n}`),
							Theme.Fonts.BodyBold,
							Theme.TextSize.Small,
							Theme.Paper.TextMuted
						)
					)
				end
				local watched: { string } = {}
				for _, id in Cutscenes.ofQuest(finished.id) do
					if scenes[id] == true then
						table.insert(watched, id)
					end
				end
				local replay = props.Replay
				local button = if #watched > 0 and replay
					then Button(s, {
						Name = "Replay",
						Size = UDim2.fromOffset(REPLAY_WIDTH, 28),
						Position = UDim2.fromScale(1, 0),
						AnchorPoint = Vector2.new(1, 0),
						Variant = "ghost",
						Text = "▶",
						TextSize = Theme.TextSize.Small,
						OnClick = function()
							-- several scenes of one quest play one after another (the controller queues replays)
							for _, id in watched do
								replay(id)
							end
						end,
					})
					else nil
				if button then
					Tooltip.attach(s, button :: GuiObject, Text.T(s, "quest.journal.replay"))
				end
				table.insert(
					list,
					s:New("Frame")({
						LayoutOrder = 11 + i * 2,
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("TextLabel")({
								Size = UDim2.new(1, if button then -(REPLAY_WIDTH + 8) else 0, 1, 0),
								BackgroundTransparency = 1,
								Text = `✔ {Text.get(use, `quest.{finished.id}.title`)}`,
								TextTruncate = Enum.TextTruncate.AtEnd,
								FontFace = Theme.Fonts.Body,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Paper.TextMuted,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							button :: any,
						} :: any,
					})
				)
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
							`<b>{title}</b>  <font size="{Theme.TextSize.Small}" color="{Theme.hex(
								Theme.Paper.TextMuted
							)}">{from}</font>`,
							Theme.Fonts.BodyBold,
							Theme.TextSize.Body,
							Theme.Paper.Heading
						)
					)
					-- owner 2026-10-21: the progress paragraph under "More" (the objectives below say the same)
					table.insert(
						shown,
						Details.new(s, {
							Key = `journal.side.{quest.id}`,
							Children = {
								label(
									s,
									0,
									Text.get(use, `quest.{quest.id}.progress`),
									Theme.Fonts.Body,
									Theme.TextSize.Small,
									Theme.Paper.Text
								),
							},
						})
					)
					table.insert(
						shown,
						label(
							s,
							0,
							table.concat(lines, "\n"),
							Theme.Fonts.BodyMedium,
							Theme.TextSize.Small,
							Theme.Paper.Text
						)
					)
					local questItems = QuestItemIcons(s, use, quest.objectives)
					if questItems then
						table.insert(shown, questItems)
					end
					table.insert(
						shown,
						QuestRewards(s, { Id = quest.id, Reward = quest.reward, ShowTitle = true, SlotSize = 36 })
					)
					table.insert(shown, sideButtons(s, quest.id))
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
								`<font color="{Theme.hex(Theme.Paper.Heading)}">!</font> {title}  <font size="{Theme.TextSize.Small}" color="{Theme.hex(
									Theme.Paper.TextMuted
								)}">{getFrom}</font>`,
								Theme.Fonts.BodyMedium,
								Theme.TextSize.Small,
								Theme.Paper.Text
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
							`{arcName}  <font color="{Theme.hex(Theme.Paper.TextMuted)}">{done}/{total}</font>`,
							Theme.Fonts.Display,
							Theme.TextSize.Large,
							if done == total then Theme.Paper.Success else Theme.Paper.Heading
						)
					)
					for _, item in shown do
						add(item)
					end
				end
			end
			if not anything then
				add(
					label(
						s,
						0,
						Text.get(use, "quest.side.none"),
						Theme.Fonts.Body,
						Theme.TextSize.Small,
						Theme.Paper.TextMuted
					)
				)
			end
			local count =
				Text.get(use, "quest.side.count", { n = SideQuests.activeCount(q), max = Config.SideQuest.maxActive })
			add(label(s, 0, count, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.TextMuted))
		elseif use(tab) == "boss" then
			local order = 0
			local function add(item: Instance)
				order += 1
				(item :: any).LayoutOrder = order
				table.insert(list, item)
			end
			local active = SideQuests.activeOf(q)
			local done = 0
			for _, quest in Quests.Boss.list do
				done += if SideQuests.isDone(q, quest.id) then 1 else 0
			end
			add(
				label(
					s,
					0,
					`{Text.get(use, "quest.arc.bosses")}  <font color="{Theme.hex(Theme.Paper.TextMuted)}">{done}/{#Quests.Boss.list}</font>`,
					Theme.Fonts.Display,
					Theme.TextSize.Large,
					if done == #Quests.Boss.list then Theme.Paper.Success else Theme.Paper.Heading
				)
			)
			for _, quest in Quests.Boss.list do
				local title = Text.get(use, `quest.{quest.id}.title`)
				local entry = active[quest.id]
				if SideQuests.isDone(q, quest.id) then
					add(label(s, 0, `✔ {title}`, Theme.Fonts.BodyMedium, Theme.TextSize.Small, Theme.Paper.Success))
				elseif type(entry) == "table" then
					add(label(s, 0, `<b>{title}</b>`, Theme.Fonts.BodyBold, Theme.TextSize.Body, Theme.Paper.Heading))
					-- owner 2026-10-21: the progress paragraph under "More"
					add(Details.new(s, {
						Key = `journal.boss.{quest.id}`,
						Children = {
							label(
								s,
								0,
								Text.get(use, `quest.{quest.id}.progress`),
								Theme.Fonts.Body,
								Theme.TextSize.Small,
								Theme.Paper.Text
							),
						},
					}))
					local rows = QuestText.rows(use, quest.objectives, entry.progress, quest.turnIn)
					add(
						label(
							s,
							0,
							table.concat(QuestText.richRows(use, rows), "\n"),
							Theme.Fonts.BodyMedium,
							Theme.TextSize.Small,
							Theme.Paper.Text
						)
					)
					local questItems = QuestItemIcons(s, use, quest.objectives)
					if questItems then
						add(questItems)
					end
					add(QuestRewards(s, { Id = quest.id, Reward = quest.reward, ShowTitle = true, SlotSize = 36 }))
					add(sideButtons(s, quest.id))
				else
					-- to take from the scout of the boss's region (giver = "scout_<region>")
					local map = Maps.get(string.sub(quest.giver, 7))
					local where =
						Text.get(use, "quest.boss.takeAt", { region = if map then Text.get(use, map.nameKey) else "?" })
					local from = Text.get(use, "quest.boss.entry", { level = SideQuests.minLevel(quest) })
					add(
						label(
							s,
							0,
							`<b>{title}</b>  <font size="{Theme.TextSize.Small}" color="{Theme.hex(
								Theme.Paper.TextMuted
							)}">{from} · {where}</font>`,
							Theme.Fonts.BodyMedium,
							Theme.TextSize.Small,
							Theme.Paper.Text
						)
					)
				end
			end
			-- the week's boss contract (none below the first boss's entry level)
			local weekly = q.weekly
			local contract = if type(weekly) == "table" then weekly.boss else nil
			if type(contract) == "table" then
				local n = Quests.Weekly.bossContract.n
				local boss = Bosses.get(contract.boss)
				local status = if contract.claimed
					then ` <font color="{Theme.hex(Theme.Paper.TextMuted)}">({Text.get(use, "quest.claimed")})</font>`
					elseif contract.progress >= n then ` <font color="{Theme.hex(Theme.Paper.Success)}">({Text.get(
						use,
						"quest.claimAtBoard"
					)})</font>`
					else ""
				add(
					label(
						s,
						0,
						`<b>{Text.get(use, "quest.bossContract.title")}</b>{status}`,
						Theme.Fonts.Display,
						Theme.TextSize.Body,
						Theme.Paper.Heading
					)
				)
				local bossArgs = { boss = if boss then Text.get(use, boss.nameKey) else "?", n = n }
				local text = Text.get(use, "quest.bossContract.text.short", bossArgs)
				local progress =
					Text.get(use, "quest.bossContract.progress", { have = math.min(contract.progress, n), n = n })
				-- owner 2026-10-21: one short line, the captaincy's words behind the "i"
				add(
					infoRow(
						s,
						label(s, 0, `{text}\n{progress}`, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Paper.Text),
						Text.get(use, "quest.bossContract.text", bossArgs)
					)
				)
				if not contract.claimed then
					add(QuestRewards(s, {
						Id = "bossContract",
						Reward = Quests.Weekly.bossReward(use(level) or 1),
						SlotSize = 34,
					}))
				end
			end
		elseif use(tab) == "weekly" then
			local weekly = q.weekly
			local week = Time.weekNumber(use(now))
			local days, hours = Time.split(Time.weekStart(week + 1) - use(now))
			local p = Dailies.progress(if type(weekly) == "table" then weekly.list else nil)
			table.insert(
				list,
				label(
					s,
					0,
					"<b>"
						.. Text.get(use, "npc.questboard.name")
						.. "</b>\n"
						.. Text.get(use, "quest.set.weekly", { done = p.complete, total = p.total })
						.. " · "
						.. Text.get(use, "quest.weeklyReset", { days = days, hours = hours }),
					Theme.Fonts.BodyMedium,
					Theme.TextSize.Small,
					Theme.Paper.TextMuted
				)
			)
			contractRows(
				s,
				use,
				(if type(weekly) == "table" then weekly.list else {}) or {},
				"weekly",
				Quests.Weekly.reward(use(level) or 1),
				list
			)
			if p.total > 0 then
				local lvl = use(level) or 1
				local state = Dailies.sanitize(use(State.Value({ "account", "dailies" })))
				setBonusRows(
					s,
					use,
					"weeklyBonus",
					Quests.Weekly.bonus(lvl),
					Dailies.weekShardsDue(state, (weekly :: any).week or 0, lvl),
					(weekly :: any).bonus == true,
					list
				)
			end
		elseif use(tab) == "contract" then
			-- S99 / S134k: the hunting contracts: done / 99, the Hunter's Marks, the active and finished counts; at a
			-- giver "Accept all" / "Hand in all" (and the Huntmaster's shop), elsewhere where to go; the active contracts
			-- grouped by map, then hunting ground (finished first, "Track" / "Abandon"), the ones to take (folded) and
			-- the next three above the level
			local lvl = use(level) or 1
			local order = 0
			local function add(item: Instance)
				order += 1
				(item :: any).LayoutOrder = order
				table.insert(list, item)
			end
			local function lookup(key: string, args: { [string]: any }?): string
				return Text.get(use, key, args)
			end
			local state = Contracts.stateOf(q)
			local npcId = use(NpcPresence.Current)
			local atGiver = npcId ~= nil and Contracts.isAnyGiver(npcId)
			local active = Contracts.activeList(state)
			local ready = Contracts.complete(state)
			local head = Text.get(
				use,
				"contract.doneCount",
				{ done = Contracts.doneCount(state), max = Quests.Contracts.MAX_LEVEL }
			)
			head ..= `   <font color="{Theme.hex(Theme.Paper.Success)}">{Text.get(
				use,
				"contract.marks",
				{ n = state.marks }
			)}</font>`
			add(label(s, 0, head, Theme.Fonts.Display, Theme.TextSize.Large, Theme.Paper.Heading))
			add(
				label(
					s,
					0,
					Text.get(use, "contract.counts", { active = #active, ready = #ready }),
					Theme.Fonts.BodyMedium,
					Theme.TextSize.Small,
					Theme.Paper.TextMuted
				)
			)
			if Contracts.allDone(state) then
				add(
					label(
						s,
						0,
						Text.get(use, "contract.allDone"),
						Theme.Fonts.Body,
						Theme.TextSize.Small,
						Theme.Paper.Success
					)
				)
			end
			-- the giver's buttons (or where they are)
			if atGiver and npcId then
				local canTake = #Contracts.acceptable(state, lvl, npcId)
				local canHand = #Contracts.ready(state, npcId)
				local buttons: { any } = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 8),
						Wraps = true,
					}),
					Button(s, {
						Size = UDim2.fromOffset(190, 40),
						Variant = "primary",
						Disabled = canTake == 0,
						Text = Text.get(use, "contract.acceptAll", { n = canTake }),
						OnClick = function()
							ContractActions.acceptAll(npcId)
						end,
					}),
					Button(s, {
						Size = UDim2.fromOffset(190, 40),
						Variant = "primary",
						Disabled = canHand == 0,
						Text = Text.get(use, "contract.turnInAll", { n = canHand }),
						OnClick = function()
							ContractActions.turnInAll(npcId)
						end,
					}),
				}
				if npcId == Contracts.HUNTMASTER and props.OpenShop then
					local open = props.OpenShop
					table.insert(
						buttons,
						Button(s, {
							Size = UDim2.fromOffset(190, 40),
							Variant = "secondary",
							Text = Text.get(use, "huntshop.title"),
							OnClick = function()
								open()
							end,
						})
					)
				end
				add(s:New("Frame")({
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = buttons :: any,
				}))
			else
				add(
					infoRow(
						s,
						label(
							s,
							0,
							Text.get(use, "contract.whereTurnIn.short"),
							Theme.Fonts.BodyBold,
							Theme.TextSize.Small,
							Theme.Paper.Heading
						),
						Text.get(use, "contract.whereTurnIn")
					)
				)
			end
			-- the active contracts by map, then hunting ground (the world's order of maps; finished first)
			type Group = { area: string, map: string, list: { Contracts.Taken } }
			local groups: { Group } = {}
			local byArea: { [string]: Group } = {}
			for _, taken in active do
				local g: Group? = byArea[taken.contract.area]
				if not g then
					local made: Group = { area = taken.contract.area, map = taken.contract.map, list = {} }
					byArea[taken.contract.area] = made
					table.insert(groups, made)
					g = made
				end
				table.insert((g :: Group).list, taken)
			end
			local MAP_ORDER = { meadows = 1, duskwood = 2, ashen = 3, frostpeak = 4 }
			table.sort(groups, function(a, b)
				local ma, mb = MAP_ORDER[a.map] or 9, MAP_ORDER[b.map] or 9
				if ma ~= mb then
					return ma < mb
				end
				return a.list[1].contract.level < b.list[1].contract.level
			end)
			local focus = use(props.Focus)
			local tracking = use(props.Tracked)
			for _, g in groups do
				table.sort(g.list, function(a, b)
					local da, db = Contracts.isTakenComplete(a), Contracts.isTakenComplete(b)
					if da ~= db then
						return da
					end
					return a.contract.level < b.contract.level
				end)
				local area = Areas.areaById(g.area)
				local groupHead = Text.get(use, "contract.group", {
					area = if area then Text.get(use, area.nameKey) else "?",
					lv = if area then `{area.lv[1]}–{area.lv[2]}` else "?",
				}) .. `  <font color="{Theme.hex(Theme.Paper.TextMuted)}">({#g.list})</font>`
				add(label(s, 0, groupHead, Theme.Fonts.Display, Theme.TextSize.Small, Theme.Paper.Heading))
				for _, taken in g.list do
					local contract = taken.contract
					local done = Contracts.isTakenComplete(taken)
					local tracked = tracking and focus ~= nil and focus.kind == "contract" and focus.id == contract.id
					local mark = if done then `<font color="{Theme.hex(Theme.Paper.Success)}">✔</font>` else "◈"
					local line = `{mark} <b>{QuestText.contractObjective(lookup, contract, taken.entry.progress[1] or 0)}</b>`
						.. `  <font color="{Theme.hex(Theme.Paper.TextMuted)}">{Text.get(
							use,
							"contract.levelTag",
							{ level = contract.level }
						)}</font>`
					add(s:New("Frame")({
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Theme.Paper.Raised,
						BackgroundTransparency = 0.45,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							s:New("UIPadding")({
								PaddingLeft = UDim.new(0, 8),
								PaddingRight = UDim.new(0, 8),
								PaddingTop = UDim.new(0, 6),
								PaddingBottom = UDim.new(0, 6),
							}),
							s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
							label(
								s,
								1,
								line,
								Theme.Fonts.BodyMedium,
								Theme.TextSize.Small,
								if done then Theme.Paper.Success else Theme.Paper.Text
							),
							QuestRewards(
								s,
								{ Id = contract.id, Reward = contract.reward, SlotSize = 30, LayoutOrder = 2 }
							),
							s:New("Frame")({
								LayoutOrder = 3,
								Size = UDim2.new(1, 0, 0, 34),
								BackgroundTransparency = 1,
								[Children] = {
									s:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										Padding = UDim.new(0, 8),
									}),
									Button(s, {
										Size = UDim2.fromOffset(130, 34),
										Variant = "secondary",
										Text = Text.get(use, if tracked then "quest.untrack" else "quest.track"),
										OnClick = function()
											if tracked then
												props.Track(nil)
											else
												props.Track({ kind = "contract", id = contract.id })
											end
										end,
									}),
									(
											if done
												then nil
												else Button(s, {
													Size = UDim2.fromOffset(130, 34),
													Variant = "ghost",
													Text = Text.get(use, "contract.abandon"),
													OnClick = function()
														props.ShowModal({
															Title = Text.now("contract.abandonTitle"),
															Message = Text.now("contract.abandonText", {
																objective = QuestText.contractObjective(
																	Text.now,
																	contract
																),
															}),
															ConfirmText = Text.now("contract.abandon"),
															CancelText = Text.now("quest.back"),
															Variant = "danger",
															OnConfirm = function(): (boolean, string?)
																local ok, err =
																	Net.Invoke("ContractAbandon", contract.level)
																if not ok then
																	return false, Text.now(err or "error.internal")
																end
																return true, nil
															end,
														})
													end,
												})
										) :: any,
								} :: any,
							}),
						},
					}))
				end
			end
			-- to take (folded): every contract up to the level not taken yet
			local eligible = Contracts.eligible(state, lvl)
			if #eligible > 0 then
				local open = use(availableOpen)
				add(Button(s, {
					Size = UDim2.new(1, 0, 0, 36),
					Variant = "ghost",
					Text = `{if open then "▾" else "▸"} {Text.get(use, "contract.available", { n = #eligible })}`,
					OnClick = function()
						availableOpen:set(not Fusion.peek(availableOpen))
					end,
				}))
				if open then
					for _, contract in eligible do
						local here = atGiver and npcId ~= nil and Contracts.isGiver(npcId, contract)
						local giver = npcId
						add(s:New("Frame")({
							Size = UDim2.new(1, 0, 0, 36),
							BackgroundTransparency = 1,
							[Children] = {
								s:New("TextLabel")({
									Size = UDim2.new(1, if here then -120 else 0, 1, 0),
									BackgroundTransparency = 1,
									Text = `{contract.level}. {QuestText.contractObjective(lookup, contract)}`,
									TextWrapped = true,
									TextTruncate = Enum.TextTruncate.AtEnd,
									FontFace = Theme.Fonts.Body,
									TextSize = Theme.TextSize.Small,
									TextColor3 = Theme.Paper.Text,
									TextXAlignment = Enum.TextXAlignment.Left,
								}),
								(if here and giver
									then Button(s, {
										AnchorPoint = Vector2.new(1, 0.5),
										Position = UDim2.fromScale(1, 0.5),
										Size = UDim2.fromOffset(110, 32),
										Variant = "secondary",
										Text = Text.get(use, "contract.accept"),
										OnClick = function()
											ContractActions.acceptOne(giver, contract.level)
										end,
									})
									else nil) :: any,
							} :: any,
						}))
					end
				end
			end
			-- the next three above the level (a mark on every 10th)
			local upcoming = Contracts.upcoming(state, lvl, 3)
			if #upcoming > 0 then
				local lines = { `<b>{Text.get(use, "contract.upcoming")}</b>` }
				for _, c in upcoming do
					local line = `{c.level}. {QuestText.contractObjective(lookup, c)}`
					if c.reward.items then
						line ..= `  <font color="{Theme.hex(Theme.Paper.Heading)}">◆ {Text.get(
							use,
							"contract.milestone"
						)}</font>`
					end
					table.insert(lines, line)
				end
				add(
					label(
						s,
						0,
						table.concat(lines, "\n"),
						Theme.Fonts.Body,
						Theme.TextSize.Small,
						Theme.Paper.TextMuted
					)
				)
			end
		else
			local daily = q.daily
			local lvl = use(level) or 1
			local today = Time.dayNumber(use(now))
			local state = Dailies.sanitize(use(State.Value({ "account", "dailies" })))
			local p = Dailies.progress(if type(daily) == "table" then daily.list else nil)
			local streak = Dailies.streakNow(state, today)
			-- owner 2026-10-21: the reroll rule behind the "i" of the status lines
			local status = label(
				s,
				0,
				"<b>"
					.. Text.get(use, "npc.questboard.name")
					.. "</b>\n"
					.. Text.get(use, "quest.set.daily", { done = p.complete, total = p.total })
					.. " · "
					.. Text.get(use, "quest.dailyReset", { time = Time.format((today + 1) * 86400 - use(now)) })
					.. "\n"
					.. (
						if streak > 0
							then Text.get(use, "quest.set.streak", { n = streak })
							else Text.get(use, "quest.set.streakNone")
					),
				Theme.Fonts.BodyMedium,
				Theme.TextSize.Small,
				Theme.Paper.TextMuted
			)
			table.insert(list, infoRow(s, status, Text.get(use, "quest.reroll.hint")))
			contractRows(
				s,
				use,
				(if type(daily) == "table" then daily.list else {}) or {},
				"daily",
				Quests.Daily.reward(lvl),
				list,
				if type(daily) == "table" and (daily.swaps or 0) < Quests.Daily.REROLLS
					then function(index: number)
						rerollDaily(index)
					end
					else nil
			)
			if p.total > 0 then
				setBonusRows(
					s,
					use,
					"dailyBonus",
					Quests.Daily.bonus(lvl, Dailies.nextStreak(state, today)),
					Dailies.dayShardsDue(state, today, lvl),
					(daily :: any).bonus == true,
					list
				)
			end
		end
		return list
	end)

	-- S98: a remembered tab that is not shown goes back to the story
	if not table.find(ids, Fusion.peek(tab)) then
		tab:set("main")
	end
	local tabList = {}
	for _, id in ids do
		table.insert(tabList, { id = id, label = Text.T(scope, `quest.tab.{id}`) })
	end

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = tabList,
			Scroll = true,
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
