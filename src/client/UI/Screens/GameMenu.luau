--!strict
-- Options window (Esc / ☰, DESIGN §23): resume, switch character, language, effects and music volume,
-- damage numbers, effects quality, minimap mode, camera sensitivity, quick cast, confirmations and the
-- list of hotkeys. Every change is saved on the account through SetSetting / SetLanguage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local KeybindData = require(ReplicatedStorage.Shared.Data.Keybinds)
local Keybinds = require(script.Parent.Parent.Keybinds)
local LanguageToggle = require(script.Parent.Parent.Components.LanguageToggle)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- Fixed keys listed under the rebindable ones (S17).
local FIXED_KEYS = {
	{ "menu.keys.lmb", "menu.keys.attack" },
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
-- Button cycling a setting through `values` (S20), labelled by `label(value)`.
local function cycle(
	scope: Scope,
	name: string,
	default: any,
	values: { any },
	label: (use: Fusion.Use, value: any) -> string
): Instance
	local value = State.Value({ "account", "settings", name })
	return Button(scope, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 44),
		Text = scope:Computed(function(use): string
			local current = use(value)
			return label(use, if current == nil then default else current)
		end),
		OnClick = function()
			local current = Fusion.peek(value)
			if current == nil then
				current = default
			end
			local index = table.find(values, current) or 0
			Net.Send("SetSetting", name, values[index % #values + 1])
		end,
	})
end

local function rarityLabel(use: Fusion.Use, value: any): string
	local def = Rarities.get(tonumber(value) or 0)
	return if def then Text.get(use, def.nameKey) else Text.get(use, "menu.off")
end

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

-- Reward code field (S17): the reward is mailed to the active character.
local function codeRow(scope: Scope): Instance
	local code = scope:Value("")
	local busy = scope:Value(false)
	local function redeem()
		local text = Fusion.peek(code)
		if Fusion.peek(busy) or text == "" then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("RedeemCode", text)
			busy:set(false)
			if ok then
				code:set("")
				Toast.push(Text.now("codes.success"), "success")
			else
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end
	return scope:New("Frame")({
		LayoutOrder = 14,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		[Children] = {
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.35, 1),
				Text = Text.T(scope, "codes.title"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			TextInput(scope, {
				Text = code,
				Placeholder = Text.T(scope, "codes.placeholder"),
				MaxLength = 24,
				Position = UDim2.fromScale(0.35, 0),
				Size = UDim2.new(0.65, -136, 0, 44),
				OnSubmit = function()
					redeem()
				end,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(128, 44),
				Variant = "primary",
				Text = Text.T(scope, "codes.redeem"),
				Disabled = busy,
				OnClick = redeem,
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

	-- Rebinding (S17): one row per action, click the key then press the new one.
	local hotkeyRows = {}
	local order = 0
	for _, action in KeybindData.actions do
		order += 1
		local capturing = scope:Computed(function(use): boolean
			return use(Keybinds.Capturing) == action.id
		end)
		local label = Keybinds.Label(scope, action.id)
		table.insert(
			hotkeyRows,
			scope:New("Frame")({
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -170, 1, 0),
						BackgroundTransparency = 1,
						Text = Text.T(scope, action.labelKey),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 2),
						Size = UDim2.fromOffset(160, 34),
						TextSize = Theme.TextSize.Small,
						Variant = scope:Computed(function(use): any
							return if use(capturing) then "primary" else "secondary"
						end),
						Text = scope:Computed(function(use): string
							return if use(capturing) then Text.get(use, "keys.press") else use(label)
						end),
						OnClick = function()
							Keybinds.capture(action.id, function(ok, err)
								if not ok then
									Toast.push(Text.now(err or "keys.reserved"), "error")
								end
							end)
						end,
					}),
				},
			})
		)
	end
	for _, entry in FIXED_KEYS do
		order += 1
		table.insert(
			hotkeyRows,
			scope:New("TextLabel")({
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					local key = if string.find(entry[1], ".", 1, true) then Text.get(use, entry[1]) else entry[1]
					return `<font color="#{Theme.Colors.GoldBright:ToHex()}"><b>{key}</b></font>   {Text.get(
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
	order += 1
	table.insert(
		hotkeyRows,
		scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = Text.T(scope, "keys.hint"),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.TextMuted,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	)
	order += 1
	table.insert(
		hotkeyRows,
		Button(scope, {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Variant = "ghost",
			Text = Text.T(scope, "keys.resetAll"),
			OnClick = function()
				task.spawn(function()
					Net.Invoke("SetKeybind", "*", nil)
				end)
			end,
		})
	)

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
			row(scope, 13, "menu.autoTarget", toggle(scope, "autoTarget", true)),
			row(scope, 13, "menu.groupRings", toggle(scope, "groupRings", true)),
			row(scope, 13, "menu.mapCloseOnWalk", toggle(scope, "mapCloseOnWalk", true)),
			row(scope, 13, "menu.betterItem", toggle(scope, "betterItem", true)),
			row(scope, 13, "menu.lootHideBelow", cycle(scope, "lootHideBelow", 0, { 0, 2, 3, 4 }, rarityLabel)),
			row(
				scope,
				13,
				"menu.lootAutoFrom",
				cycle(scope, "lootAutoFrom", 0, { 0, 2, 3, 4, 5 }, function(use, value)
					return if value == 0 then Text.get(use, "menu.all") else rarityLabel(use, value)
				end)
			),
			row(
				scope,
				7,
				"menu.decor",
				cycle(scope, "decor", "mid", { "low", "mid", "high" }, function(use, value)
					return Text.get(use, `menu.decor.{value}`)
				end)
			),
			codeRow(scope),
			scope:New("TextLabel")({
				LayoutOrder = 15,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Text = Text.T(scope, "menu.hotkeys"),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			scope:New("Frame")({
				LayoutOrder = 16,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					hotkeyRows :: any,
				},
			}),
			scope:New("TextLabel")({
				Name = "MockWarning",
				LayoutOrder = 17,
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
