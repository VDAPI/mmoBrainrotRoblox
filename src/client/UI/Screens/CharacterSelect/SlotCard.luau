--!strict
-- One character slot on the selection screen: empty ("Create character") or occupied (name, class,
-- level, map, Play / Delete).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Slot: number,
	Summary: UsedAs<Types.SlotSummary?>,
	Busy: UsedAs<boolean>,
	OnCreate: () -> (),
	OnPlay: () -> (),
	OnDelete: (summary: Types.SlotSummary) -> (),
}

local CARD_WIDTH = 300
local CARD_MAX_HEIGHT = 440

local function label(scope: Scope, props: { [any]: any }): Instance
	local base: { [any]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, props.Height or 26),
		FontFace = Theme.Fonts.Body,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Colors.Text,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	props.Height = nil
	for key, value in props do
		base[key] = value
	end
	return scope:New("TextLabel")(base)
end

local function emblem(scope: Scope, class: Classes.ClassDef?, layoutOrder: number): Instance
	local color = if class then Color3.fromHex(class.color) else Theme.Colors.GoldDim
	return scope:New("Frame")({
		Name = "Emblem",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Theme.Colors.Background,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({ Thickness = Theme.Stroke.Thick, Color = color }),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = if class then class.icon else "+",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 44,
				TextColor3 = color,
			}),
		},
	})
end

local function occupied(scope: Scope, props: Props, summary: Types.SlotSummary): { Instance }
	local class = Classes.get(summary.class)
	local map = Maps.get(summary.map)
	return {
		emblem(scope, class, 1),
		label(scope, {
			Name = "CharName",
			LayoutOrder = 2,
			Height = 40,
			Text = summary.name,
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Title,
			TextColor3 = Theme.Colors.Gold,
		}),
		label(scope, {
			Name = "ClassLevel",
			LayoutOrder = 3,
			Text = scope:Computed(function(use): string
				local className = if class then Text.get(use, class.nameKey) else summary.class
				return Text.get(use, "charSelect.classLevel", { class = className, level = summary.level })
			end),
		}),
		label(scope, {
			Name = "Map",
			LayoutOrder = 4,
			Height = 22,
			Text = Text.T(scope, if map then map.nameKey else "map.unknown"),
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
		}),
		scope:New("Frame")({
			Name = "Spacer",
			LayoutOrder = 5,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(1, 1),
			[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
		}),
		Button(scope, {
			Name = "Play",
			LayoutOrder = 6,
			Text = Text.T(scope, "charSelect.play"),
			Variant = "primary",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Disabled = props.Busy,
			OnClick = props.OnPlay,
		}),
		Button(scope, {
			Name = "Delete",
			LayoutOrder = 7,
			Text = Text.T(scope, "charSelect.delete"),
			Variant = "ghost",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
			TextSize = Theme.TextSize.Small,
			Disabled = props.Busy,
			OnClick = function()
				props.OnDelete(summary)
			end,
		}),
	}
end

local function empty(scope: Scope, props: Props): { Instance }
	return {
		emblem(scope, nil, 1),
		label(scope, {
			Name = "Empty",
			LayoutOrder = 2,
			Height = 40,
			Text = Text.T(scope, "charSelect.emptySlot"),
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.TextMuted,
		}),
		scope:New("Frame")({
			Name = "Spacer",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(1, 1),
			[Children] = scope:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Fill }),
		}),
		Button(scope, {
			Name = "Create",
			LayoutOrder = 4,
			Text = Text.T(scope, "charSelect.createButton"),
			Variant = "secondary",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Disabled = props.Busy,
			OnClick = props.OnCreate,
		}),
	}
end

local function SlotCard(scope: Scope, props: Props): Instance
	local hasCharacter = scope:Computed(function(use): boolean
		return use(props.Summary) ~= nil
	end)

	return scope:New("Frame")({
		Name = `Slot{props.Slot}`,
		LayoutOrder = props.Slot,
		Size = UDim2.new(0, CARD_WIDTH, 1, -8),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = Theme.Colors.Gold,
				Transparency = scope:Computed(function(use): number
					return if use(hasCharacter) then 0.1 else 0.55
				end),
			}),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(CARD_WIDTH, CARD_MAX_HEIGHT) }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Large),
				PaddingBottom = UDim.new(0, Theme.Padding.Large),
				PaddingLeft = UDim.new(0, Theme.Padding.Large),
				PaddingRight = UDim.new(0, Theme.Padding.Large),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			scope:Computed(function(use, innerScope: Scope): { Instance }
				local summary = use(props.Summary)
				if summary then
					return occupied(innerScope, props, summary)
				end
				return empty(innerScope, props)
			end) :: any,
		},
	})
end

return SlotCard
