--!strict
-- Game menu window (Esc / ☰): resume, switch character, language.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LanguageToggle = require(script.Parent.Parent.Components.LanguageToggle)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local function GameMenu(scope: Scope, close: () -> ()): Fusion.Child
	local busy = scope:Value(false)
	local dataMock = State.Value({ "session", "dataMock" })
	local dmgNumbers = State.Value({ "account", "settings", "dmgNumbers" })

	local function switchCharacter()
		if Fusion.peek(busy) then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("SwitchCharacter")
			busy:set(false)
			if ok then
				close()
			else
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	return {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.Padding.Medium),
		}),
		Button(scope, {
			LayoutOrder = 1,
			Text = Text.T(scope, "menu.resume"),
			Variant = "primary",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			OnClick = close,
		}),
		Button(scope, {
			LayoutOrder = 2,
			Text = Text.T(scope, "menu.switchCharacter"),
			Variant = "secondary",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Disabled = busy,
			OnClick = switchCharacter,
		}),
		scope:New("Frame")({
			Name = "Language",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			[Children] = {
				scope:New("TextLabel")({
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0.5, 1),
					Text = Text.T(scope, "menu.language"),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				LanguageToggle(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
				}),
			},
		}),
		scope:New("Frame")({
			Name = "DamageNumbers",
			LayoutOrder = 4,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 44),
			[Children] = {
				scope:New("TextLabel")({
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0.6, 1),
					Text = Text.T(scope, "menu.damageNumbers"),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(136, 44),
					Variant = scope:Computed(function(use): Button.Variant
						return if use(dmgNumbers) ~= false then "primary" else "ghost"
					end) :: any,
					Text = scope:Computed(function(use): string
						return Text.get(use, if use(dmgNumbers) ~= false then "menu.on" else "menu.off")
					end),
					OnClick = function()
						Net.Send("SetSetting", "dmgNumbers", Fusion.peek(dmgNumbers) == false)
					end,
				}),
			},
		}),
		scope:New("TextLabel")({
			Name = "MockWarning",
			LayoutOrder = 5,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = scope:Computed(function(use): boolean
				return use(dataMock) == true
			end),
			Text = Text.T(scope, "charSelect.mockWarning"),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Warning,
			TextWrapped = true,
		}),
	}
end

return GameMenu
