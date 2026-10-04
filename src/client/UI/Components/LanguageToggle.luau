--!strict
-- PL / EN switch. Saves the choice on the account (SettingsService); the UI re-renders through Text.Lang.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
}

local BUTTON = Vector2.new(64, 44)

local function LanguageToggle(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local buttons = {}
	-- Display order: Polish first (primary audience), then the rest of Config.Languages.
	local order = { "pl" }
	for _, lang in Config.Languages do
		if lang ~= "pl" then
			table.insert(order, lang)
		end
	end

	for index, lang in order do
		local active = scope:Computed(function(use): boolean
			return use(Text.Lang) == lang
		end)
		table.insert(
			buttons,
			scope:New("TextButton")({
				Name = lang,
				LayoutOrder = index,
				Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(active) then Theme.Colors.PanelHover else Theme.Colors.Panel
				end),
				Text = string.upper(lang),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(active) then Theme.Colors.Gold else Theme.Colors.TextMuted
				end),
				[OnEvent("Activated")] = function()
					if Fusion.peek(active) then
						return
					end
					Sounds.play("click")
					Text.setPreferred(lang)
					Net.Send("SetLanguage", lang)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Normal,
						Color = Theme.Colors.Gold,
						Transparency = scope:Computed(function(use): number
							return if use(active) then 0 else 0.6
						end),
					}),
				},
			})
		)
	end

	return scope:New("Frame")({
		Name = "LanguageToggle",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(#order * BUTTON.X + (#order - 1) * Theme.Padding.Small, BUTTON.Y),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			buttons :: any,
		},
	})
end

return LanguageToggle
