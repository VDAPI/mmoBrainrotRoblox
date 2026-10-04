--!strict
-- Options window (Esc / ☰, DESIGN §23): resume, switch character, language, effects and music volume,
-- damage numbers, effects quality, minimap mode, camera sensitivity, quick cast, confirmations and the
-- list of hotkeys. Every change is saved on the account through SetSetting / SetLanguage.

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

local HOTKEYS = {
	{ "C", "hud.menu.character" },
	{ "B", "hud.menu.inventory" },
	{ "K", "hud.menu.skills" },
	{ "M", "hud.menu.map" },
	{ "L", "hud.menu.quests" },
	{ "G", "hud.menu.guild" },
	{ "P", "hud.menu.party" },
	{ "1-0", "menu.keys.skills" },
	{ "Z X V", "menu.keys.potions" },
	{ "Tab", "menu.keys.target" },
	{ "E / F", "menu.keys.interact" },
	{ "Esc", "menu.keys.close" },
}

local function row(scope: Scope, order: number, labelKey: string, control: Instance): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		[Children] = {
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.5, 1),
				Text = Text.T(scope, labelKey),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			control,
		},
	})
end

-- Two-state switch bound to a boolean setting (`default` when unset).
local function toggle(scope: Scope, name: string, default: boolean): Instance
	local value = State.Value({ "account", "settings", name })
	local on = scope:Computed(function(use): boolean
		local v = use(value)
		return if v == nil then default else v == true
	end)
	return Button(scope, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 44),
		Variant = scope:Computed(function(use): any
			return if use(on) then "primary" else "ghost"
		end),
		Text = scope:Computed(function(use): string
			return Text.get(use, if use(on) then "menu.on" else "menu.off")
		end),
		OnClick = function()
			Net.Send("SetSetting", name, not Fusion.peek(on))
		end,
	})
end

-- − value + stepper for a numeric setting.
local function stepper(scope: Scope, name: string, default: number, step: number, min: number, max: number): Instance
	local value = State.Value({ "account", "settings", name })
	local current = scope:Computed(function(use): number
		local v = use(value)
		return if type(v) == "number" then v else default
	end)
	local function change(delta: number)
		local nextValue = math.clamp(math.floor((Fusion.peek(current) + delta) * 100 + 0.5) / 100, min, max)
		Net.Send("SetSetting", name, nextValue)
	end
	return scope:New("Frame")({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(230, 44),
		BackgroundTransparency = 1,
		[Children] = {
			Button(scope, {
				Size = UDim2.fromOffset(52, 44),
				Text = "−",
				OnClick = function()
					change(-step)
				end,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(56, 0),
				Size = UDim2.new(1, -112, 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return `{math.floor(use(current) * 100 + 0.5)}%`
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.GoldBright,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(52, 44),
				Text = "+",
				OnClick = function()
					change(step)
				end,
			}),
		},
	})
end

local function GameMenu(scope: Scope, close: () -> ()): Fusion.Child
	local busy = scope:Value(false)
	local dataMock = State.Value({ "session", "dataMock" })
	local quality = State.Value({ "account", "settings", "quality" })

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

	local hotkeyRows = {}
	for i, entry in HOTKEYS do
		table.insert(
			hotkeyRows,
			scope:New("TextLabel")({
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					return `<font color="#{Theme.Colors.GoldBright:ToHex()}"><b>{entry[1]}</b></font>   {Text.get(
						use,
						entry[2]
					)}`
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	end

	return scope:New("ScrollingFrame")({
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
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
			row(
				scope,
				3,
				"menu.language",
				LanguageToggle(scope, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) })
			),
			row(scope, 4, "menu.volume", stepper(scope, "volume", 0.8, 0.1, 0, 1)),
			row(scope, 5, "menu.musicVolume", stepper(scope, "musicVolume", 0.6, 0.1, 0, 1)),
			row(scope, 6, "menu.cameraSens", stepper(scope, "cameraSens", 1, 0.1, 0.2, 3)),
			row(
				scope,
				7,
				"menu.quality",
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(150, 44),
					Text = scope:Computed(function(use): string
						return Text.get(use, if use(quality) == "low" then "menu.quality.low" else "menu.quality.high")
					end),
					OnClick = function()
						Net.Send("SetSetting", "quality", if Fusion.peek(quality) == "low" then "high" else "low")
					end,
				})
			),
			row(scope, 8, "menu.damageNumbers", toggle(scope, "dmgNumbers", true)),
			row(scope, 9, "menu.minimapRotate", toggle(scope, "minimapRotate", false)),
			row(scope, 10, "menu.quickCast", toggle(scope, "quickCast", false)),
			row(scope, 11, "menu.bindConfirm", toggle(scope, "bindConfirm", true)),
			row(scope, 12, "menu.sellConfirm", toggle(scope, "sellConfirm", true)),
			scope:New("TextLabel")({
				LayoutOrder = 13,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "menu.hotkeys"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				LayoutOrder = 14,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder }),
					hotkeyRows :: any,
				},
			}),
			scope:New("TextLabel")({
				Name = "MockWarning",
				LayoutOrder = 15,
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
		},
	})
end

return GameMenu
