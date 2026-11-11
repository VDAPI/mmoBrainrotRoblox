--!strict
-- NPC conversation window: 3D portrait (S27, the world map's preview in portrait mode), name and role, a line
-- (the greeting or one of the NPC's lines; the innkeeper also passes on who has work for you), then the quests
-- this NPC has for you (UI/NpcQuests: ? to hand in, ! new, … in progress, later ones greyed) and the service
-- buttons. A quest opens the quest conversation (QuestController). S99: the hunting contract (at the board it opens
-- the board window instead, NpcController).
-- S102: an NPC of an active quest's `talk` / `deliver` objective with a `line` says that line (the story first).
-- Owner 2026-11-10 ("niektóre rzeczy zasłaniają inne"; UI plan E): the portrait, the line's box and where the choices
-- start come from Logic/WorldLayout.npcDialog over the measured content, so the longest line (TextCaps dialogPage)
-- never runs into the choices; a phone's portrait is smaller.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local CitySeasonState = require(script.Parent.Parent.CitySeasonState)
local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local NpcQuests = require(script.Parent.Parent.NpcQuests)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local PhoneLayout = require(script.Parent.Parent.PhoneLayout)
local Preview = require(script.Parent.WorldMap.Preview)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestText = require(script.Parent.Parent.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Scale = require(script.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextCase = require(ReplicatedStorage.Shared.Logic.TextCase)
local Theme = require(script.Parent.Parent.Theme)
local WorldLayout = require(ReplicatedStorage.Shared.Logic.WorldLayout)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	OnService: (service: string) -> (),
	OnQuest: (row: NpcQuests.Row) -> (),
}

local GOSSIP_LINES = 3
local HIDDEN_SERVICES: { [string]: boolean } = { story = true, talk = true }

local MARK: { [string]: { glyph: string, color: Color3 } } = {
	turnIn = { glyph = "?", color = Theme.Paper.Heading },
	offer = { glyph = "!", color = Theme.Paper.Heading },
	active = { glyph = "…", color = Theme.Paper.TextMuted },
	later = { glyph = "·", color = Theme.Paper.TextMuted },
}

-- S102: the `line` of a talk / deliver objective of an active quest that points at this NPC (story first, then side
-- quests), or nil. It stays while the quest is active, done or not.
local function questLine(def: Npcs.NpcDef): string?
	local quests = State.Get({ "character", "quests" })
	local class = State.Get({ "character", "class" })
	local function lineOf(quest: SideQuests.QuestLike): string?
		for _, objective in quest.objectives do
			if (objective.type == "talk" or objective.type == "deliver") and objective.line then
				local npc = QuestLogic.npcFor(objective.npc, class)
				if objective.type == "deliver" and npc == nil then
					npc = quest.turnIn
				end
				if npc == def.id then
					return objective.line
				end
			end
		end
		return nil
	end
	local story = SideQuests.mainEntry(quests)
	local found = if story then lineOf(story) else nil
	if found then
		return found
	end
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.npcQuest(id)
		local line = if quest and type(entry) == "table" then lineOf(quest) else nil
		if line then
			return line
		end
	end
	return nil
end

-- S105: NPCs with a spring greeting (npc.<id>.greetingSpring).
local SPRING_GREETINGS: { [string]: boolean } = { captain = true, brother_anzelm = true, healer = true }

-- Line of an NPC for this visit: [key, args]. Lines rotate at random; the innkeeper's gossip names an NPC with
-- a quest the character can take now.
local function pickLine(def: Npcs.NpcDef): (string, { [string]: any }?)
	local quest = questLine(def)
	if quest then
		return quest, nil
	end
	if def.gossip then
		local quests = State.Get({ "character", "quests" })
		local level = State.Get({ "character", "level" }) or 1
		local givers = SideQuests.giversWithWork(quests, level, def.id)
		if #givers > 0 and math.random() < 0.75 then
			-- mostly the nearest level, sometimes the next one
			local giver = Npcs.get(givers[if #givers > 1 and math.random() < 0.3 then 2 else 1])
			if giver then
				return `npc.{def.id}.gossip{math.random(1, GOSSIP_LINES)}`,
					{ npc = `@{giver.nameKey}`, where = `@npc.{giver.id}.where` }
			end
		end
	end
	-- S105: in the first spring of Vaelthorn (the finale handed in, Logic/CitySeason) the captain, Anzelm and the
	-- healer greet the player with a warmer word
	if SPRING_GREETINGS[def.id] and CitySeasonState.current() == "spring" and math.random() < 0.6 then
		return `npc.{def.id}.greetingSpring`, nil
	end
	local count = def.lines or 0
	if count > 0 and math.random() < 0.8 then
		return `npc.{def.id}.line{math.random(1, count)}`, nil
	end
	return def.greetingKey, nil
end

-- "@key" arguments are localized too (like Toast arguments).
local function lineText(use: Fusion.Use, key: string, args: { [string]: any }?): string
	if not args then
		return Text.get(use, key)
	end
	local resolved = {}
	for name, value in args do
		resolved[name] = if type(value) == "string" and string.sub(value, 1, 1) == "@"
			then Text.get(use, string.sub(value, 2))
			else value
	end
	return Text.get(use, key, resolved)
end

local function NpcDialog(scope: Scope, props: Props): Fusion.Child
	local quests = State.Value({ "character", "quests" })
	local level = State.Value({ "character", "level" })
	local def = scope:Computed(function(use): Npcs.NpcDef?
		local id = use(props.NpcId)
		return if id then Npcs.get(id) else nil
	end)
	-- The line is picked once per NPC visit (not on every quest state change).
	local line = scope:Computed(function(use): { key: string, args: { [string]: any }? }?
		local d = use(def)
		if not d then
			return nil
		end
		local key, args = pickLine(d)
		return { key = key, args = args }
	end)

	local preview = Preview.new(scope, nil, { portrait = true })
	local function showPortrait()
		local d = Fusion.peek(def)
		preview.show(
			if d and d.body ~= "board"
				then { kind = "npc", id = d.id, glyph = d.icon }
				else { kind = "glyph", id = "", glyph = if d then d.icon else "?", color = Theme.Paper.Text }
		)
	end
	scope:Observer(def):onChange(showPortrait)
	task.defer(showPortrait)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local d = use(def)
		local list: { Instance } = {}
		if not d then
			return list
		end
		local order = 0
		local questRows = NpcQuests.rows(use(quests), use(level) or 1, d.id)
		for _, row in questRows do
			order += 1
			local style = MARK[row.mode]
			local contract = if row.kind == "contract" then Quests.Contracts.get(row.id) else nil
			-- S134k: several hunting contracts in one row ("Hunting contracts: 4")
			local title = if contract and (row.count or 1) > 1
				then Text.get(use, "contract.titleMany", { n = row.count })
				elseif contract then QuestText.contractTitle(
					function(key: string, args: { [string]: any }?): string
						return Text.get(use, key, args)
					end,
					contract
				)
				else Text.get(use, `quest.{row.id}.title`)
			local suffix = if row.mode == "later"
				then `  ({Text.get(use, "quest.fromLevel", { level = NpcQuests.minLevel(row) })})`
				elseif row.mode == "turnIn" then `  ({Text.get(use, "quest.readyShort")})`
				else ""
			-- final UI review 2026-11-11: the quest's category, the word its window, the map's card and the journal's tab
			-- use ("GŁÓWNE", never "FABUŁA" here and "GŁÓWNE" one tap later)
			local tag = TextCase.upper(Text.get(use, `quest.tab.{row.category}`))
			table.insert(
				list,
				s:New("TextButton")({
					Name = `Quest_{row.id}`,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					BackgroundColor3 = Theme.Paper.Raised,
					BackgroundTransparency = if row.mode == "later" then 0.5 else 0,
					AutoButtonColor = row.mode ~= "later",
					Text = "",
					[OnEvent("Activated")] = function()
						Sounds.play("click")
						props.OnQuest(row)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({
							Color = style.color,
							Thickness = if row.mode == "turnIn" or row.mode == "offer" then 2 else 1,
							Transparency = if row.mode == "later" then 0.6 else 0.1,
						}),
						s:New("TextLabel")({
							Size = UDim2.new(0, 36, 1, 0),
							BackgroundTransparency = 1,
							Text = style.glyph,
							FontFace = Theme.Fonts.Display,
							TextSize = Theme.TextSize.Large,
							TextColor3 = style.color,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(38, 0),
							Size = UDim2.new(1, -46, 1, 0),
							BackgroundTransparency = 1,
							RichText = true,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Text = `<font color="{Theme.hex(Theme.Paper.TextMuted)}">{tag}</font>  {title}{suffix}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if row.mode == "later" then Theme.Paper.TextMuted else Theme.Paper.Text,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					},
				})
			)
		end
		local services = {}
		for _, service in d.services do
			if not HIDDEN_SERVICES[service] then
				table.insert(services, service)
			end
		end
		if #questRows == 0 and #services == 0 then
			order += 1
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 1,
					Text = Text.get(use, "quest.nothing"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
		end
		if #questRows > 0 and #services > 0 then
			order += 1
			table.insert(
				list,
				s:New("Frame")({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 4), BackgroundTransparency = 1 })
			)
		end
		for i, service in services do
			order += 1
			table.insert(
				list,
				Button(s, {
					LayoutOrder = order,
					Text = Text.T(s, `npc.service.{service}`),
					Variant = if i == 1 and #questRows == 0 then "primary" else "secondary",
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					OnClick = function()
						props.OnService(service)
					end,
				})
			)
		end
		return list
	end)

	-- Logic/WorldLayout over the measured content: the portrait, the line's box, the choices' top
	local measured = scope:Value(Vector2.zero)
	local layout = scope:Computed(function(use): WorldLayout.NpcDialog
		local size = Scale.toVirtual(use(measured))
		local device: WorldLayout.Device = WorldLayout.device(use(Device.Touch) == true, use(PhoneLayout.Compact))
		return WorldLayout.npcDialog({ w = size.X, h = size.Y }, device)
	end)
	local function beside(top: number, height: number): (Fusion.Computed<UDim2>, Fusion.Computed<UDim2>)
		return scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(layout).portrait.w + 16, top)
		end),
			scope:Computed(function(use): UDim2
				return UDim2.new(1, -use(layout).portrait.w - 16, 0, height)
			end)
	end
	local namePosition, nameSize = beside(0, 32)
	local rolePosition, roleSize = beside(32, 20)

	return {
		scope:New("Frame")({
			Name = "Measure",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Out("AbsoluteSize")] = measured,
		}),
		scope:New("Frame")({
			Name = "Portrait",
			Size = scope:Computed(function(use): UDim2
				local portrait = use(layout).portrait
				return UDim2.fromOffset(portrait.w, portrait.h)
			end),
			BackgroundColor3 = Theme.Paper.Sunken,
			ClipsDescendants = true,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
				scope:New("UIStroke")({ Color = Theme.Paper.Border, Thickness = 3 }),
				preview.frame,
			},
		}),
		scope:New("TextLabel")({
			Name = "Name",
			Position = namePosition,
			Size = nameSize,
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then Text.get(use, d.nameKey) else ""
			end),
			FontFace = Theme.Fonts.Display,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.Paper.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		scope:New("TextLabel")({
			Name = "Role",
			Position = rolePosition,
			Size = roleSize,
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then Text.get(use, `npc.{d.id}.role`) else ""
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		-- owner 2026-10-21: a greeting shortened to its first sentence keeps the rest behind an "i" (`<key>.info`)
		InfoTip.new(scope, {
			Name = "LineInfo",
			Text = scope:Computed(function(use): string
				local l = use(line)
				return if l then Text.get(use, `{l.key}.info`) else ""
			end),
			Visible = scope:Computed(function(use): boolean
				local l = use(line)
				return l ~= nil and Locale.has(`{l.key}.info`, use(Text.Lang))
			end),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 56),
		}),
		scope:New("TextLabel")({
			Name = "Line",
			Position = scope:Computed(function(use): UDim2
				local box = use(layout).line
				return UDim2.fromOffset(box.left, box.top)
			end),
			Size = scope:Computed(function(use): UDim2
				local box = use(layout).line
				return UDim2.fromOffset(box.right - box.left, box.bottom - box.top)
			end),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local l = use(line)
				return if l then `“{lineText(use, l.key, l.args)}”` else ""
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Paper.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("ScrollingFrame")({
			Name = "Choices",
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, use(layout).choicesTop)
			end),
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 1, -use(layout).choicesTop)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
				rows :: any,
			},
		}),
	}
end

return NpcDialog
