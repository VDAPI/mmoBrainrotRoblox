--!strict
-- NPC conversation window: 3D portrait (S27, the world map's preview in portrait mode), name and role, a line
-- (the greeting or one of the NPC's lines; the innkeeper also passes on who has work for you), then the quests
-- this NPC has for you (UI/NpcQuests: ? to hand in, ! new, … in progress, later ones greyed) and the service
-- buttons. A quest opens the quest conversation (QuestController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NpcQuests = require(script.Parent.Parent.NpcQuests)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Preview = require(script.Parent.WorldMap.Preview)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	OnService: (service: string) -> (),
	OnQuest: (row: NpcQuests.Row) -> (),
}

local PORTRAIT = Vector2.new(120, 140)
local GOSSIP_LINES = 3
local HIDDEN_SERVICES: { [string]: boolean } = { story = true, talk = true }

local MARK: { [string]: { glyph: string, color: Color3 } } = {
	turnIn = { glyph = "?", color = Theme.Colors.GoldBright },
	offer = { glyph = "!", color = Theme.Colors.GoldBright },
	active = { glyph = "…", color = Theme.Colors.TextMuted },
	later = { glyph = "·", color = Theme.Colors.TextMuted },
}

-- Line of an NPC for this visit: [key, args]. Lines rotate at random; the innkeeper's gossip names an NPC with
-- a quest the character can take now.
local function pickLine(def: Npcs.NpcDef): (string, { [string]: any }?)
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
				else { kind = "glyph", id = "", glyph = if d then d.icon else "?", color = Theme.Colors.Parchment }
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
			local title = Text.get(use, `quest.{row.id}.title`)
			local suffix = if row.mode == "later"
				then `  ({Text.get(use, "quest.fromLevel", { level = NpcQuests.minLevel(row) })})`
				elseif row.mode == "turnIn" then `  ({Text.get(use, "quest.readyShort")})`
				else ""
			local tag = if row.kind == "side" then Text.get(use, "quest.tag.side") else Text.get(use, "quest.tag.main")
			table.insert(
				list,
				s:New("TextButton")({
					Name = `Quest_{row.id}`,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
					BackgroundColor3 = Theme.Colors.PanelRaised,
					BackgroundTransparency = if row.mode == "later" then 0.6 else 0.15,
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
							FontFace = Theme.Fonts.Heading,
							TextSize = 26,
							TextColor3 = style.color,
						}),
						s:New("TextLabel")({
							Position = UDim2.fromOffset(38, 0),
							Size = UDim2.new(1, -46, 1, 0),
							BackgroundTransparency = 1,
							RichText = true,
							TextTruncate = Enum.TextTruncate.AtEnd,
							Text = `<font color="#9A9DA8">{tag}</font>  {title}{suffix}`,
							FontFace = Theme.Fonts.BodyBold,
							TextSize = Theme.TextSize.Body,
							TextColor3 = if row.mode == "later" then Theme.Colors.TextMuted else Theme.Colors.Text,
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
					TextColor3 = Theme.Colors.TextMuted,
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

	return {
		scope:New("Frame")({
			Name = "Portrait",
			Size = UDim2.fromOffset(PORTRAIT.X, PORTRAIT.Y),
			BackgroundColor3 = Theme.Colors.Background,
			ClipsDescendants = true,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
				scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 3 }),
				preview.frame,
			},
		}),
		scope:New("TextLabel")({
			Name = "Name",
			Position = UDim2.fromOffset(PORTRAIT.X + 16, 0),
			Size = UDim2.new(1, -PORTRAIT.X - 16, 0, 32),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then Text.get(use, d.nameKey) else ""
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.Colors.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		scope:New("TextLabel")({
			Name = "Role",
			Position = UDim2.fromOffset(PORTRAIT.X + 16, 32),
			Size = UDim2.new(1, -PORTRAIT.X - 16, 0, 20),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local d = use(def)
				return if d then Text.get(use, `npc.{d.id}.role`) else ""
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("TextLabel")({
			Name = "Line",
			Position = UDim2.fromOffset(PORTRAIT.X + 16, 56),
			Size = UDim2.new(1, -PORTRAIT.X - 16, 0, PORTRAIT.Y - 56),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local l = use(line)
				return if l then `“{lineText(use, l.key, l.args)}”` else ""
			end),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		scope:New("ScrollingFrame")({
			Name = "Choices",
			Position = UDim2.fromOffset(0, PORTRAIT.Y + 14),
			Size = UDim2.new(1, 0, 1, -(PORTRAIT.Y + 14)),
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
