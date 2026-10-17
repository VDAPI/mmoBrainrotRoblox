--!strict
-- Quest conversation with an NPC (DESIGN §20; S27 rewrite for the side quests): the NPC's portrait and name, the
-- story on pages (side quests: quest.<id>.p1..pN with "Next"; the story: quest.<id>.text), then the objectives and
-- rewards with "Accept" / "Not now". A quest in progress shows its progress line (quest.<id>.progress); one that
-- is done shows the thanks (quest.<id>.done) and "Hand in" — with three items for the character's class to pick
-- from on an arc's last quest (rolled by the server when the quest was finished, tooltip compares with the
-- equipped item). S98: the quest's category over the title (quest.tab.<category>) and, on an offer far below the
-- character (NpcMarks.isLow, the grey "!"), a note that it pays less than hunting at the character's level. S99: the
-- hunting contract at the scout of its region (title and pages with arguments, ContractAccept / ContractTurnIn).
-- S101b (DESIGN-15 §3.5): a page with 2-3 answers of the player (Logic/Dialogue): "Next" / "Accept" / "Hand in" wait
-- for an answer there, QuestSay saves it, then the NPC's reply shows under the page (and on every later visit); pages
-- may pick a variant by an earlier answer (`recall`). A side quest taken before it was answered shows the page again
-- at its giver while it runs.
-- S102: story quests with `pages` offer them like the side quests (p1..pN, the answers on a page number).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Dialogue = require(ReplicatedStorage.Shared.Logic.Dialogue)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Net = require(ReplicatedStorage.Shared.Net)
local NpcQuests = require(script.Parent.Parent.NpcQuests)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Preview = require(script.Parent.WorldMap.Preview)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRewards = require(script.Parent.Parent.Components.QuestRewards)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	Row: Fusion.UsedAs<NpcQuests.Row?>,
	Close: () -> (),
	Back: () -> (),
	-- S27: "Track" after accepting a side quest.
	OnAccepted: ((row: NpcQuests.Row) -> ())?,
}

local PORTRAIT = Vector2.new(84, 96)

-- What the conversation shows for the selected quest.
type View = {
	row: NpcQuests.Row,
	mode: "offer" | "active" | "turnIn" | "later" | "elsewhere",
	title: string, -- locale key
	titleArgs: { [string]: any }?, -- S99: arguments of the title (the hunting contract)
	pages: { string }, -- locale keys
	pageArgs: { [string]: any }?, -- S99: arguments of every page
	objectives: { Quests.Objective },
	progress: { number },
	reward: Quests.Reward,
	turnIn: string,
	choice: { any }?,
	-- S101b: the page with answers (`say`), its index in `pages` (`sayAt`) and the saved answer (`said`; not `choice`,
	-- which is the rolled reward items)
	say: Quests.ChoicePage?,
	sayAt: number?,
	said: string?,
}

-- S101b: a page key's text, a variant by an earlier answer when the quest recalls one.
local function hasText(key: string): boolean
	return Locale.has(key, "pl") and Locale.has(key, "en")
end

local function pageKeys(quest: any, ids: { string }, quests: any): { string }
	local keys: { string } = {}
	for _, id in ids do
		table.insert(keys, Dialogue.pageKey(quest, id, quests, hasText))
	end
	return keys
end

-- S101b: where the answers stand among the shown pages (nil = not on this conversation).
local function answersAt(quest: any, ids: { string }, mode: string): (Quests.ChoicePage?, number?)
	local page = Dialogue.choicePage(quest)
	if not page or (mode ~= "offer" and mode ~= "active" and mode ~= "turnIn") then
		return nil, nil
	end
	local name = Dialogue.pageName(page.page)
	if (name == "done") ~= (mode == "turnIn") then
		return nil, nil
	end
	local at = table.find(ids, name)
	return if at then page else nil, at
end

-- `keep` (S101b): a quest answered in this conversation keeps its page with the reply in view.
local function buildView(row: NpcQuests.Row?, quests: any, npcId: string?, keep: string?): View?
	if not row or type(quests) ~= "table" then
		return nil
	end
	if row.kind == "contract" then
		-- S99: the hunting contract (taken and handed in here at the scout of its region)
		local contract = Quests.Contracts.get(row.id)
		if not contract then
			return nil
		end
		-- S134k: this contract's own entry among the active ones
		local entry = Contracts.activeEntry(Contracts.stateOf(quests), contract.level)
		local progress = if entry then entry.progress else QuestLogic.emptyProgress(contract.objectives)
		local mode: any = if entry
			then (if QuestLogic.isComplete(entry.progress, contract.objectives) then "turnIn" else "active")
			else (if row.mode == "later" then "later" else "offer")
		local area = Areas.areaById(contract.area)
		local areaArg = if area then `@{area.nameKey}` else "?"
		local kind = Monsters.get(contract.objectives[1].monster or "")
		local monsterArg = if kind then `@{kind.nameKeys.normal}` else "?"
		return {
			row = row,
			mode = mode,
			title = "contract.title",
			titleArgs = { n = contract.level, monster = monsterArg, area = areaArg },
			pages = {
				if mode == "turnIn"
					then "contract.done"
					elseif mode == "active" then "contract.progress"
					else "contract.text",
			},
			-- S134k: the monster kind of the contract
			pageArgs = { area = areaArg, n = contract.objectives[1].n, monster = monsterArg },
			objectives = contract.objectives,
			progress = progress,
			reward = contract.reward,
			turnIn = npcId or Contracts.BOARD,
		}
	end
	if row.kind == "main" then
		local quest = Quests.Main.get(row.id)
		if not quest then
			return nil
		end
		local main = quests.main
		local active = type(main) == "table" and main.id == quest.id
		local progress = if active then main.progress or {} else QuestLogic.emptyProgress(quest.objectives)
		local mode: any = if active
			then (if QuestLogic.isComplete(progress, quest.objectives) and quest.turnIn == npcId
				then "turnIn"
				else "active")
			else (if row.mode == "later" then "later" else "offer")
		-- S102: an offer of a story quest with pages shows quest.<id>.p1..pN; in progress quest.<id>.text, hand-in .done
		local ids: { string } = {}
		if mode == "offer" and quest.pages then
			for i = 1, quest.pages do
				table.insert(ids, Dialogue.pageOf(quest, "main", "offer", i))
			end
		else
			ids = { if mode == "turnIn" then "done" else "text" }
		end
		local say, sayAt = answersAt(quest, ids, mode)
		return {
			row = row,
			mode = mode,
			title = `quest.{quest.id}.title`,
			pages = pageKeys(quest, ids, quests),
			objectives = quest.objectives,
			progress = progress,
			reward = quest.reward,
			turnIn = quest.turnIn,
			say = say,
			sayAt = sayAt,
			said = Dialogue.saidOf(quests, quest.id),
		}
	end
	local quest = Quests.npcQuest(row.id)
	if not quest then
		return nil
	end
	local entry = SideQuests.activeOf(quests)[quest.id]
	local mode: any
	local ids: { string } = {}
	if type(entry) == "table" then
		if SideQuests.isComplete(entry, quest) then
			mode = if quest.turnIn == npcId then "turnIn" else "elsewhere"
		else
			mode = "active"
		end
		ids = { if mode == "turnIn" then "done" else "progress" }
		-- S101b: not answered at the offer: the giver shows that page again before the progress
		local page = Dialogue.choicePage(quest)
		if
			mode == "active"
			and page
			and type(page.page) == "number"
			and npcId == quest.giver
			and (Dialogue.saidOf(quests, quest.id) == nil or keep == quest.id)
		then
			table.insert(ids, 1, Dialogue.pageName(page.page))
		end
	else
		mode = if row.mode == "later" then "later" else "offer"
		for i = 1, quest.pages do
			table.insert(ids, Dialogue.pageOf(quest, "side", "offer", i))
		end
	end
	local say, sayAt = answersAt(quest, ids, mode)
	return {
		row = row,
		mode = mode,
		title = `quest.{quest.id}.title`,
		pages = pageKeys(quest, ids, quests),
		say = say,
		sayAt = sayAt,
		said = Dialogue.saidOf(quests, quest.id),
		objectives = quest.objectives,
		progress = if type(entry) == "table" then entry.progress or {} else QuestLogic.emptyProgress(quest.objectives),
		reward = quest.reward,
		turnIn = quest.turnIn,
		choice = if type(entry) == "table" then entry.choice else nil,
	}
end

-- S99: "@key" arguments of a view (area names) in the player's language.
local function resolveWith(use: any, args: { [string]: any }?): { [string]: any }?
	if not args then
		return nil
	end
	local out = {}
	for key, value in args do
		out[key] = if type(value) == "string" and string.sub(value, 1, 1) == "@"
			then Text.get(use, string.sub(value, 2))
			else value
	end
	return out
end

local function resolve(args: { [string]: any }?): { [string]: any }?
	if not args then
		return nil
	end
	local out = {}
	for key, value in args do
		out[key] = if type(value) == "string" and string.sub(value, 1, 1) == "@"
			then Text.now(string.sub(value, 2))
			else value
	end
	return out
end

local function QuestDialog(scope: Scope, props: Props): Fusion.Child
	local quests = State.Value({ "character", "quests" })
	local level = State.Value({ "character", "level" })
	local page = scope:Value(1)
	local picked = scope:Value(nil :: number?)
	local busy = scope:Value(false)
	local saying = scope:Value(false) -- S101b: an answer on its way
	local answered = scope:Value(nil :: string?) -- S101b: the quest answered in this conversation

	local view = scope:Computed(function(use): View?
		return buildView(use(props.Row), use(quests), use(props.NpcId), use(answered))
	end)
	-- A new quest starts on its first page with nothing picked.
	scope
		:Observer(scope:Computed(function(use): string
			local row = use(props.Row)
			return if row then `{row.kind}:{row.id}` else ""
		end))
		:onChange(function()
			page:set(1)
			picked:set(nil)
			answered:set(nil)
		end)

	local preview = Preview.new(scope, nil, { portrait = true })
	local function showPortrait()
		local npcId = Fusion.peek(props.NpcId)
		local def = npcId and Npcs.get(npcId)
		preview.show(if def and def.body ~= "board"
			then { kind = "npc", id = def.id, glyph = def.icon }
			else {
				kind = "glyph",
				id = "",
				glyph = if def then def.icon else "?",
				color = Theme.Colors.Parchment,
			})
	end
	scope:Observer(props.NpcId):onChange(showPortrait)
	task.defer(showPortrait)

	local lastPage = scope:Computed(function(use): boolean
		local v = use(view)
		return v == nil or use(page) >= #v.pages
	end)
	-- S101b: the shown page has answers (and whether one was given)
	local onAnswers = scope:Computed(function(use): boolean
		local v = use(view)
		return v ~= nil and v.say ~= nil and v.sayAt == math.clamp(use(page), 1, #v.pages)
	end)
	local mustAnswer = scope:Computed(function(use): boolean
		local v = use(view)
		return use(onAnswers) and v ~= nil and v.said == nil
	end)

	local function answer(choiceId: string)
		local v = Fusion.peek(view)
		if not v or Fusion.peek(saying) then
			return
		end
		saying:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("QuestSay", v.row.id, choiceId)
			saying:set(false)
			if ok then
				answered:set(v.row.id)
				Sounds.play("click")
			else
				Sounds.play("error")
				Toast.push(
					Text.now(if err == "inventory.full" then "quest.say.later" else err or "error.internal"),
					"error"
				)
			end
		end)
	end

	local function act()
		local v = Fusion.peek(view)
		local npcId = Fusion.peek(props.NpcId)
		if not v or not npcId or Fusion.peek(busy) then
			return
		end
		local name: string
		local args: { any }
		if v.row.kind == "main" then
			name = if v.mode == "offer" then "QuestAccept" else "QuestTurnIn"
			args = { npcId }
		elseif v.row.kind == "contract" then
			name = if v.mode == "offer" then "ContractAccept" else "ContractTurnIn"
			args = { npcId }
		elseif v.mode == "offer" then
			name, args = "SideAccept", { v.row.id }
		else
			name = "SideTurnIn"
			local choice = Fusion.peek(picked)
			args = if choice then { v.row.id, choice } else { v.row.id }
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke(name, table.unpack(args))
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				if v.mode == "offer" then
					Toast.push(
						Text.now("quest.accepted", { title = Text.now(v.title, resolve(v.titleArgs)) }),
						"success"
					)
					if props.OnAccepted then
						props.OnAccepted(v.row)
					end
				end
				props.Close()
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local bodyText = scope:Computed(function(use): string
		local v = use(view)
		if not v then
			return Text.get(use, "quest.nothing")
		end
		if v.mode == "later" then
			return Text.get(use, "quest.nextAt", { level = NpcQuests.minLevel(v.row) })
		end
		if v.mode == "elsewhere" then
			local npc = Npcs.get(v.turnIn)
			return Text.get(use, "quest.handInAt", { npc = if npc then Text.get(use, npc.nameKey) else "?" })
		end
		local key = v.pages[math.clamp(use(page), 1, #v.pages)]
		return Text.get(use, key, resolveWith(use, v.pageArgs))
	end)

	-- Objectives and rewards show on the last page.
	local details = scope:Computed(function(use): string
		local v = use(view)
		if not v or not use(lastPage) or v.mode == "later" then
			return ""
		end
		local lines = { `<b>{Text.get(use, "quest.objectives")}</b>` }
		-- S29: the same rows as the tracker (finished objectives stay green; "Return to" when talking to another NPC).
		for _, line in
			QuestText.richRows(use, QuestText.rows(use, v.objectives, v.progress, v.turnIn), v.mode == "active")
		do
			table.insert(lines, line)
		end
		return table.concat(lines, "\n")
	end)
	-- S31: rewards as icons and item slots with tooltips (on the last page, under the objectives).
	local rewards = scope:Computed(function(use, s: Scope): Instance?
		local v = use(view)
		if not v or not use(lastPage) or v.mode == "later" then
			return nil
		end
		return QuestRewards(s, { Id = v.row.id, Reward = v.reward, ShowTitle = true, LayoutOrder = 4 })
	end)

	-- S101b: the answers under the page, or the given answer and the NPC's reply
	local answers = scope:Computed(function(use, s: Scope): Instance?
		local v = use(view)
		if not v or not use(onAnswers) or not v.say then
			return nil
		end
		local id = v.row.id
		local children: { Instance } = {
			s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }) :: any,
		}
		if v.said == nil then
			table.insert(
				children,
				s:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = Text.get(use, "quest.say.pick"),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
			for i, option in v.say.options do
				table.insert(
					children,
					Button(s, {
						LayoutOrder = i,
						Size = UDim2.new(1, 0, 0, 44),
						Variant = "secondary",
						Text = Text.get(use, `quest.{id}.say.{option.id}`),
						Disabled = s:Computed(function(use2): boolean
							return use2(saying)
						end),
						OnClick = function()
							answer(option.id)
						end,
					})
				)
			end
		else
			table.insert(
				children,
				s:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = Text.get(use, "quest.say.you", { answer = Text.get(use, `quest.{id}.say.{v.said}`) }),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
			table.insert(
				children,
				s:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					RichText = true,
					Text = `<i>{Text.get(use, `quest.{id}.say.{v.said}.reply`)}</i>`,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Parchment,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		return s:New("Frame")({
			Name = "Answers",
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = children :: any,
		})
	end)

	local choices = scope:Computed(function(use, s: Scope): { Instance }
		local v = use(view)
		local list: { Instance } = {}
		if not v or v.mode ~= "turnIn" or not v.choice then
			return list
		end
		for i, item in v.choice do
			table.insert(
				list,
				SelectableSlot(s, {
					Id = `sidechoice:{v.row.id}:{i}`,
					Item = item,
					Size = 72,
					LayoutOrder = i,
					Selected = s:Computed(function(use2): boolean
						return use2(picked) == i
					end),
					OnToggle = function()
						picked:set(if Fusion.peek(picked) == i then nil else i)
					end,
				})
			)
		end
		return list
	end)
	local hasChoice = scope:Computed(function(use): boolean
		local v = use(view)
		return v ~= nil and v.mode == "turnIn" and v.choice ~= nil and #v.choice > 0
	end)

	local function npcName(use: Fusion.Use): string
		local npcId = use(props.NpcId)
		local def = npcId and Npcs.get(npcId)
		return if def then Text.get(use, def.nameKey) else ""
	end

	return {
		scope:New("Frame")({
			Name = "Portrait",
			Size = UDim2.fromOffset(PORTRAIT.X, PORTRAIT.Y),
			BackgroundColor3 = Theme.Colors.Background,
			ClipsDescendants = true,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
				scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 2 }),
				preview.frame,
			},
		}),
		scope:New("TextLabel")({
			Name = "Category",
			Position = UDim2.fromOffset(PORTRAIT.X + 14, 0),
			Size = UDim2.new(1, -PORTRAIT.X - 14, 0, 14),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local v = use(view)
				return if v then string.upper(Text.get(use, `quest.tab.{v.row.category}`)) else ""
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = 12,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("TextLabel")({
			Name = "Title",
			Position = UDim2.fromOffset(PORTRAIT.X + 14, 14),
			Size = UDim2.new(1, -PORTRAIT.X - 14, 0, 32),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local v = use(view)
				return if v then Text.get(use, v.title, resolveWith(use, v.titleArgs)) else ""
			end),
			TextWrapped = true,
			TextScaled = true,
			FontFace = Theme.Fonts.Heading,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
			[Children] = scope:New("UITextSizeConstraint")({ MaxTextSize = 26, MinTextSize = 16 }),
		}),
		scope:New("TextLabel")({
			Name = "Speaker",
			Position = UDim2.fromOffset(PORTRAIT.X + 14, 48),
			Size = UDim2.new(1, -PORTRAIT.X - 14, 0, 22),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local v = use(view)
				local pageText = if v and #v.pages > 1
					then `  ·  {Text.get(use, "quest.page", { page = use(page), pages = #v.pages })}`
					else ""
				return `{npcName(use)}{pageText}`
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("ScrollingFrame")({
			Name = "Body",
			Position = UDim2.fromOffset(0, PORTRAIT.Y + 10),
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 1, -(PORTRAIT.Y + 10) - 64 - (if use(hasChoice) then 92 else 0))
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				-- S98: an offer far below the character's level (the grey "!")
				scope:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = Text.T(scope, "quest.lowLevel"),
					Visible = scope:Computed(function(use): boolean
						local v = use(view)
						return v ~= nil and v.mode == "offer" and NpcMarks.isLow(v.row.level, use(level) or 1)
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					Text = bodyText,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Parchment,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				answers :: any,
				scope:New("TextLabel")({
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					TextWrapped = true,
					RichText = true,
					Text = details,
					Visible = scope:Computed(function(use): boolean
						return use(details) ~= ""
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
				rewards :: any,
			},
		}),
		scope:New("Frame")({
			Name = "Choice",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -64),
			Size = UDim2.new(1, 0, 0, 88),
			BackgroundTransparency = 1,
			Visible = hasChoice,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					Text = Text.T(scope, "quest.choose"),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = 14,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("Frame")({
					Position = UDim2.fromOffset(0, 16),
					Size = UDim2.new(1, 0, 0, 72),
					BackgroundTransparency = 1,
					[Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 14),
						}),
						choices :: any,
					},
				}),
			},
		}),
		-- Buttons: [Not now / Back]  [Next | Accept | Hand in]
		Button(scope, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(170, 52),
			Variant = "ghost",
			Text = scope:Computed(function(use): string
				local v = use(view)
				return Text.get(use, if v and v.mode == "offer" then "quest.notNow" else "quest.back")
			end),
			OnClick = props.Back,
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(230, 52),
			Variant = "primary",
			Visible = scope:Computed(function(use): boolean
				local v = use(view)
				return v ~= nil and (not use(lastPage) or v.mode == "offer" or v.mode == "turnIn")
			end),
			Text = scope:Computed(function(use): string
				local v = use(view)
				if not use(lastPage) then
					return Text.get(use, "quest.next")
				end
				return Text.get(use, if v and v.mode == "turnIn" then "quest.turnIn" else "quest.accept")
			end),
			Disabled = scope:Computed(function(use): boolean
				local v = use(view)
				if use(busy) or use(mustAnswer) then
					return true
				end
				return v ~= nil and use(lastPage) and v.mode == "turnIn" and use(hasChoice) and use(picked) == nil
			end),
			OnClick = function()
				if Fusion.peek(mustAnswer) then
					return
				end
				if not Fusion.peek(lastPage) then
					Sounds.play("click")
					page:set(Fusion.peek(page) + 1)
					return
				end
				act()
			end,
		}),
	}
end

return QuestDialog
