--!strict
-- Detail card of the world map (S25, DESIGN §23): header (icon, name, levels / role, colour of the zone or
-- band, "← back" for sub-cards, ✕) -> 3D preview (when it makes sense) -> content sections -> action bar.
-- PC: a panel at the right edge of the map; touch: a bottom sheet over the lower part of the map with the
-- preview on its left and big buttons (>= 44 px). The content is a declarative spec built by WorldMap/Cards
-- and rendered here in its own scope, rebuilt on every show (a card has a few dozen objects at most).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local Preview = require(script.Parent.Preview)
local QuestRewards = require(script.Parent.Parent.Parent.Components.QuestRewards)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Theme = require(script.Parent.Parent.Parent.Theme)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Line = { text: string, color: Color3?, size: number?, bold: boolean?, italic: boolean? }
export type Row = { text: string, sub: string?, color: Color3?, icon: string?, onClick: (() -> ())? }
-- `tooltip`: extra tooltip context (S31, e.g. the shop entry so the tooltip shows the same price).
export type ItemRow = {
	item: Types.ItemInstance,
	text: string,
	sub: string?,
	color: Color3?,
	tooltip: TooltipModel.Ctx?,
}
export type Chip = { icon: string, text: string }
export type Choice = { options: { { id: string, text: string } }, selected: string, onSelect: (id: string) -> () }
-- S31: a quest's rewards (icons + item slots with tooltips), drawn under the section's lines.
export type RewardRow = { id: string, reward: Quests.Reward }
export type Section = {
	title: string?,
	lines: { Line }?,
	rewards: { RewardRow }?,
	rows: { Row }?,
	items: { ItemRow }?,
	chips: { Chip }?,
	choice: Choice?,
}
export type Action = { text: string, onClick: () -> (), primary: boolean?, danger: boolean? }
export type Spec = {
	icon: string,
	iconColor: Color3?,
	title: string,
	subtitle: string?,
	subtitleColor: Color3?,
	accent: Color3?,
	back: (() -> ())?,
	preview: Preview.Spec?,
	sections: { Section },
	actions: { Action },
	grey: boolean?, -- "coming soon" cards
}

export type Props = {
	Touch: Fusion.Value<boolean>,
	BuildLook: Preview.BuildLook?,
	OnClose: () -> (),
}

export type Api = {
	frame: Frame,
	show: (spec: Spec?, keepScroll: boolean?) -> (),
	isOpen: () -> boolean,
}

local DetailCard = {}

local WIDTH = 316
local PREVIEW_HEIGHT = 176
local SHEET_PREVIEW = 150

function DetailCard.new(scope: Scope, props: Props): Api
	local touch = props.Touch
	local spec = scope:Value(nil :: Spec?)
	local preview = Preview.new(scope, props.BuildLook)
	local hasPreview = scope:Computed(function(use): boolean
		local s = use(spec)
		return s ~= nil and s.preview ~= nil
	end)

	local body = scope:New("ScrollingFrame")({
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Position = scope:Computed(function(use): UDim2
			if use(touch) then
				return UDim2.fromOffset(if use(hasPreview) then SHEET_PREVIEW + 10 else 0, 56)
			end
			return UDim2.fromOffset(0, 56 + (if use(hasPreview) then PREVIEW_HEIGHT + 8 else 0))
		end),
		Size = scope:Computed(function(use): UDim2
			local actions = if use(touch) then 56 else 48
			if use(touch) then
				return UDim2.new(1, -(if use(hasPreview) then SHEET_PREVIEW + 10 else 0), 1, -(56 + actions))
			end
			return UDim2.new(1, 0, 1, -(56 + actions + (if use(hasPreview) then PREVIEW_HEIGHT + 8 else 0)))
		end),
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6) }),
		},
	}) :: ScrollingFrame

	local actionsBar = scope:New("Frame")({
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, if use(touch) then 50 else 40)
		end),
		BackgroundTransparency = 1,
		[Children] = scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	}) :: Frame

	local previewHolder = scope:New("Frame")({
		Name = "PreviewHolder",
		BackgroundColor3 = Theme.Colors.Background,
		Visible = hasPreview,
		Position = UDim2.fromOffset(0, 56),
		Size = scope:Computed(function(use): UDim2
			if use(touch) then
				return UDim2.new(0, SHEET_PREVIEW, 1, -(56 + 56))
			end
			return UDim2.new(1, 0, 0, PREVIEW_HEIGHT)
		end),
		ClipsDescendants = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.Border }),
			preview.frame,
		},
	})

	local headerButton = function(text: string, onClick: () -> (), visible: Fusion.UsedAs<boolean>, right: boolean)
		return scope:New("TextButton")({
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = if right then UDim2.fromScale(1, 0) else UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			Visible = visible,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 20,
			TextColor3 = Theme.Colors.Parchment,
			ZIndex = 3,
			[OnEvent("Activated")] = onClick,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	local header = scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		[Children] = {
			headerButton(
				"←",
				function()
					local s = Fusion.peek(spec)
					if s and s.back then
						s.back()
					end
				end,
				scope:Computed(function(use): boolean
					local s = use(spec)
					return s ~= nil and s.back ~= nil
				end),
				false
			),
			scope:New("TextLabel")({
				Name = "Icon",
				Position = scope:Computed(function(use): UDim2
					local s = use(spec)
					return UDim2.fromOffset(if s and s.back then 50 else 0, 2)
				end),
				Size = UDim2.fromOffset(40, 40),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local s = use(spec)
					return if s then s.icon else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 30,
				TextColor3 = scope:Computed(function(use): Color3
					local s = use(spec)
					return if s and s.iconColor then s.iconColor else Theme.Colors.Parchment
				end),
				TextStrokeTransparency = 0.4,
			}),
			scope:New("Frame")({
				Name = "Titles",
				BackgroundTransparency = 1,
				Position = scope:Computed(function(use): UDim2
					local s = use(spec)
					return UDim2.fromOffset(if s and s.back then 94 else 44, 0)
				end),
				Size = scope:Computed(function(use): UDim2
					local s = use(spec)
					return UDim2.new(1, -((if s and s.back then 94 else 44) + Theme.Size.MinTouch + 4), 1, 0)
				end),
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local s = use(spec)
							return if s then s.title else ""
						end),
						FontFace = Theme.Fonts.Heading,
						TextSize = 21,
						TextColor3 = scope:Computed(function(use): Color3
							local s = use(spec)
							return if s and s.grey then Theme.Colors.TextMuted else Theme.Colors.GoldBright
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					scope:New("TextLabel")({
						Position = UDim2.fromOffset(0, 26),
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							local s = use(spec)
							return if s and s.subtitle then s.subtitle else ""
						end),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = 14,
						TextColor3 = scope:Computed(function(use): Color3
							local s = use(spec)
							return if s and s.subtitleColor then s.subtitleColor else Theme.Colors.TextMuted
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
				},
			}),
			headerButton("✕", props.OnClose, true, true),
			-- Stripe in the zone / band colour.
			scope:New("Frame")({
				Name = "Accent",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 4),
				Size = UDim2.new(1, 0, 0, 3),
				BorderSizePixel = 0,
				BackgroundColor3 = scope:Computed(function(use): Color3
					local s = use(spec)
					return if s and s.accent then s.accent else Theme.Colors.GoldDim
				end),
			}),
		},
	})

	local frame = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(touch) then Vector2.new(0.5, 1) else Vector2.new(1, 0)
		end),
		Position = scope:Computed(function(use): UDim2
			return if use(touch) then UDim2.new(0.5, 0, 1, -8) else UDim2.new(1, -10, 0, 10)
		end),
		Size = scope:Computed(function(use): UDim2
			return if use(touch) then UDim2.new(1, -16, 0.56, 0) else UDim2.new(0, WIDTH, 1, -20)
		end),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.04,
		Active = true,
		ZIndex = 30,
		Visible = scope:Computed(function(use): boolean
			return use(spec) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1.5 }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			header,
			previewHolder,
			body,
			actionsBar,
		},
	}) :: Frame

	-- Content -----------------------------------------------------------------------------------------------
	local content: Scope? = nil

	local function textLine(s: Scope, order: number, line: Line): Instance
		return s:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = line.text,
			TextWrapped = true,
			RichText = true,
			FontFace = if line.bold
				then Theme.Fonts.BodyBold
				elseif line.italic then Font.new(
					"rbxasset://fonts/families/BuilderSans.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Italic
				)
				else Theme.Fonts.Body,
			TextSize = line.size or 15,
			TextColor3 = line.color or Theme.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local function section(s: Scope, order: number, data: Section): Instance
		local children: { Instance } = {}
		local n = 0
		local function add(child: Instance)
			n += 1
			(child :: any).LayoutOrder = n
			table.insert(children, child)
		end
		if data.title then
			add(textLine(s, 0, { text = data.title, color = Theme.Colors.Gold, size = 14, bold = true }))
		end
		if data.choice then
			local choice = data.choice
			local buttons: { Instance } = {}
			for i, option in choice.options do
				local on = option.id == choice.selected
				table.insert(
					buttons,
					s:New("TextButton")({
						LayoutOrder = i,
						Size = UDim2.new(1 / #choice.options, -4, 1, 0),
						BackgroundColor3 = if on then Theme.Colors.Accent else Theme.Colors.PanelRaised,
						Text = option.text,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 14,
						TextColor3 = Theme.Colors.Parchment,
						AutoButtonColor = true,
						[OnEvent("Activated")] = function()
							choice.onSelect(option.id)
						end,
						[Children] = s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					})
				)
			end
			add(s:New("Frame")({
				Size = s:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(touch) then 44 else 32)
				end),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					buttons :: any,
				},
			}))
		end
		for _, line in (data.lines or {}) :: { Line } do
			add(textLine(s, 0, line))
		end
		for _, row in (data.rewards or {}) :: { RewardRow } do
			add(QuestRewards(s, { Id = row.id, Reward = row.reward, SlotSize = 36 }))
		end
		if data.chips and #data.chips > 0 then
			local chips: { Instance } = {}
			for i, chip in data.chips do
				table.insert(
					chips,
					s:New("TextLabel")({
						LayoutOrder = i,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 26),
						BackgroundColor3 = Theme.Colors.PanelRaised,
						Text = `{chip.icon}  {chip.text}`,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = 14,
						TextColor3 = Theme.Colors.Parchment,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, 13) }),
							s:New("UIPadding")({ PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
						},
					})
				)
			end
			add(s:New("Frame")({
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIGridLayout")({
						CellSize = UDim2.new(0.5, -4, 0, 26),
						CellPadding = UDim2.fromOffset(6, 5),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					chips :: any,
				},
			}))
		end
		for _, row in (data.rows or {}) :: { Row } do
			local clickable = row.onClick ~= nil
			add(s:New("TextButton")({
				Size = s:Computed(function(use): UDim2
					return UDim2.new(1, 0, 0, if use(touch) then 44 else (if row.sub then 40 else 30))
				end),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = if clickable then 0.2 else 0.6,
				AutoButtonColor = clickable,
				Active = clickable,
				Text = "",
				[OnEvent("Activated")] = function()
					if row.onClick then
						row.onClick()
					end
				end,
				[Children] = {
					s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(8, 0),
						Size = UDim2.new(1, -(if clickable then 34 else 12), if row.sub then 0.6 else 1, 0),
						BackgroundTransparency = 1,
						Text = (if row.icon then row.icon .. "  " else "") .. row.text,
						RichText = true,
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = 15,
						TextColor3 = row.color or Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					if row.sub
						then s:New("TextLabel")({
							Position = UDim2.new(0, 8, 0.55, 0),
							Size = UDim2.new(1, -(if clickable then 34 else 12), 0.4, 0),
							BackgroundTransparency = 1,
							Text = row.sub,
							FontFace = Theme.Fonts.Body,
							TextSize = 12,
							TextColor3 = Theme.Colors.TextMuted,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
						})
						else nil :: any,
					if clickable
						then s:New("TextLabel")({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(18, 18),
							BackgroundTransparency = 1,
							Text = "›",
							FontFace = Theme.Fonts.BodyBold,
							TextSize = 22,
							TextColor3 = Theme.Colors.Gold,
						})
						else nil :: any,
				},
			}))
		end
		for i, entry in (data.items or {}) :: { ItemRow } do
			add(s:New("Frame")({
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					ItemSlot(s, {
						SlotId = `view:mapcard:{order}:{i}`,
						Item = entry.item,
						TooltipCtx = entry.tooltip,
						Size = 40,
						Position = UDim2.fromOffset(0, 2),
					}),
					s:New("TextLabel")({
						Position = UDim2.fromOffset(48, 2),
						Size = UDim2.new(1, -48, 0, 22),
						BackgroundTransparency = 1,
						Text = entry.text,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 14,
						TextColor3 = entry.color or Theme.Colors.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					if entry.sub
						then s:New("TextLabel")({
							Position = UDim2.fromOffset(48, 22),
							Size = UDim2.new(1, -48, 0, 18),
							BackgroundTransparency = 1,
							Text = entry.sub,
							FontFace = Theme.Fonts.Body,
							TextSize = 13,
							TextColor3 = Theme.Colors.GoldBright,
							TextXAlignment = Enum.TextXAlignment.Left,
						})
						else nil :: any,
				},
			}))
		end
		return s:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
				children :: any,
			},
		})
	end

	local function show(next: Spec?, keepScroll: boolean?)
		local scroll = body.CanvasPosition
		if content then
			Fusion.doCleanup(content)
			content = nil
		end
		spec:set(next)
		preview.show(if next then next.preview else nil)
		if not next then
			return
		end
		local s = Fusion.scoped(Fusion) :: any
		content = s
		for i, data in next.sections do
			section(s, i, data).Parent = body
		end
		local count = math.max(1, #next.actions)
		for i, action in next.actions do
			Button(s, {
				LayoutOrder = i,
				Text = action.text,
				Variant = if action.danger then "danger" elseif action.primary then "primary" else "secondary",
				Size = UDim2.new(1 / count, -6 * (count - 1) / count, 1, 0),
				TextSize = 15,
				OnClick = action.onClick,
			}).Parent =
				actionsBar
		end
		body.CanvasPosition = if keepScroll then scroll else Vector2.zero
	end
	table.insert(scope, function()
		if content then
			Fusion.doCleanup(content)
		end
	end)

	return {
		frame = frame,
		show = show,
		isOpen = function(): boolean
			return Fusion.peek(spec) ~= nil
		end,
	}
end

return DetailCard
