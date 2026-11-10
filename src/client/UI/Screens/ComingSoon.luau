--!strict
-- Body for windows whose systems arrive in later sessions (character, backpack, skills, ...).
-- Each window is replaced by its real screen when that system lands.
-- Owner 2026-11-10 ("too much text, things covering each other, nothing folds"), UI package C's window parts: the body
-- scrolls in the window (Window.Parts `Scroll`) like the other dialog windows; it has no action, so no footer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Window = require(script.Parent.Parent.Components.Window)

type Scope = Fusion.Scope<typeof(Fusion)>

local function ComingSoon(scope: Scope, icon: string): Window.Parts
	return {
		Scroll = true,
		Content = {
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
				TextSize = Theme.TextSize.Hero,
				TextColor3 = Theme.Paper.Label,
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Text = Text.T(scope, "window.soon"),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Text,
			}),
		},
	}
end

return ComingSoon
