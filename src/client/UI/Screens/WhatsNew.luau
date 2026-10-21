--!strict
-- "What has changed" letter (S153, docs/DESIGN.md §11): the Data/Changelog entries the controller picked (the new ones
-- after the last read, or the latest ones from the game menu), newest first, on parchment: a heading, each entry with
-- its date (SectionLabel), title and text, scrolled, and "To the game" at the bottom. Static: the list is fixed when
-- the window opens (ReturningController).
-- 2026-10-21 (owner: too many descriptions): each entry shows its date and title, its text is folded
-- (Components/Details); only the newest entry opens unfolded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Changelog = require(ReplicatedStorage.Shared.Data.Changelog)
local Details = require(script.Parent.Parent.Components.Details)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SectionLabel = require(script.Parent.Parent.Components.SectionLabel)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Entries: { Changelog.Entry }, -- newest first
	Close: () -> (),
}

local HEADER = 44
local FOOTER = Theme.Size.ButtonHeight + Theme.Padding.Medium

local function dateArgs(day: number): { [string]: any }
	local y, m, d = Time.civil(day * 86400)
	return { d = string.format("%02d", d), m = string.format("%02d", m), y = y }
end

local function entryCard(scope: Scope, order: number, entry: Changelog.Entry, open: boolean): Instance
	return scope:New("Frame")({
		Name = entry.key,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Tiny),
			}),
			SectionLabel(scope, {
				LayoutOrder = 1,
				Text = Text.T(scope, "changelog.date", dateArgs(entry.day)),
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = Text.T(scope, `changelog.{entry.key}.title`),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Heading,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Details.new(scope, {
				LayoutOrder = 3,
				Open = scope:Value(open),
				Children = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = Text.T(scope, `changelog.{entry.key}.body`),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
		},
	})
end

local function WhatsNew(scope: Scope, props: Props): Fusion.Child
	local cards: { Instance } = {}
	for i, entry in props.Entries do
		table.insert(cards, entryCard(scope, i, entry, i == 1))
	end
	return scope:New("Frame")({
		Name = "WhatsNew",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "changelog.window.header"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("ScrollingFrame")({
				Name = "Entries",
				Position = UDim2.fromOffset(0, HEADER),
				Size = UDim2.new(1, 0, 1, -HEADER - FOOTER),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Large),
					}),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, Theme.Padding.Medium) }),
					cards :: any,
				},
			}),
			Button(scope, {
				Name = "ToTheGame",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(220, Theme.Size.ButtonHeight),
				Text = Text.T(scope, "changelog.window.close"),
				Variant = "primary",
				OnClick = props.Close,
			}),
		},
	})
end

return WhatsNew
