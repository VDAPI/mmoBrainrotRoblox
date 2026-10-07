--!strict
-- Action sheet (S29): a titled list of buttons over a dimmed backdrop, e.g. the item menu opened by holding a
-- slot on touch ("Equip / Unequip / Sell ..."). Tapping the backdrop or "Cancel" closes it; an option closes
-- it and then runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

export type Option = {
	label: string,
	variant: ("primary" | "secondary" | "danger")?,
	run: () -> (),
}

export type Props = {
	Title: string,
	Options: { Option },
	CancelText: string,
	Close: () -> (),
}

local WIDTH = 340
local ROW = Theme.Size.ButtonHeight

local function ActionMenu(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local buttons = {}
	for index, option in props.Options do
		table.insert(
			buttons,
			Button(scope, {
				LayoutOrder = index,
				Text = option.label,
				Variant = (option.variant or "secondary") :: any,
				Size = UDim2.new(1, 0, 0, ROW),
				OnClick = function()
					props.Close()
					option.run()
				end,
			})
		)
	end
	table.insert(
		buttons,
		Button(scope, {
			LayoutOrder = #props.Options + 1,
			Text = props.CancelText,
			Variant = "ghost",
			Size = UDim2.new(1, 0, 0, ROW),
			OnClick = props.Close,
		})
	)

	return scope:New("TextButton")({
		Name = "ActionMenu",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		ZIndex = 50,
		[OnEvent("Activated")] = props.Close,
		[Children] = {
			scope:New("Frame")({
				Name = "Sheet",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(WIDTH, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Panel,
				Active = true,
				ZIndex = 51,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Thick,
						Color = Theme.Colors.Gold,
					}),
					scope:New("UIPadding")({
						PaddingTop = UDim.new(0, Theme.Padding.Medium),
						PaddingBottom = UDim.new(0, Theme.Padding.Medium),
						PaddingLeft = UDim.new(0, Theme.Padding.Medium),
						PaddingRight = UDim.new(0, Theme.Padding.Medium),
					}),
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Padding.Small),
					}),
					scope:New("TextLabel")({
						Name = "Title",
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						Text = props.Title,
						FontFace = Theme.Fonts.Heading,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Colors.Gold,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					buttons :: any,
				},
			}),
		},
	})
end

return ActionMenu
