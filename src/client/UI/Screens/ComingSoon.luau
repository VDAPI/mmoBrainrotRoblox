--!strict
-- Body for windows whose systems arrive in later sessions (character, backpack, skills, ...).
-- Each window is replaced by its real screen when that system lands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

local function ComingSoon(scope: Scope, icon: string): Fusion.Child
	return {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Theme.Padding.Medium),
		}),
		scope:New("TextLabel")({
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(96, 96),
			Text = icon,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 72,
			TextColor3 = Theme.Colors.GoldDim,
		}),
		scope:New("TextLabel")({
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			Text = Text.T(scope, "window.soon"),
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.Parchment,
		}),
	}
end

return ComingSoon
