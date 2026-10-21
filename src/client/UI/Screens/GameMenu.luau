--!strict
-- Options window (Esc / ☰, DESIGN §23): resume, switch character, language, effects and music volume,
-- damage numbers, effects quality, minimap mode, camera sensitivity, quick cast, confirmations and the
-- list of hotkeys. Every change is saved on the account through SetSetting / SetLanguage.
-- S121: "VIP" (the VIP window) and, with VIP, "Return to the city (VIP)" with its countdown under "Switch character".
-- S122: the Cloak of Luring switch with its time after the sound rows (only while the account has cloak time).
-- Owner 2026-10-21 (too many detailed descriptions): the settings in sections with headings (Sound, Graphics and camera,
-- Combat, Interface); the rare ones (Loot and trade, Social, Hotkeys) folded (Details); short row labels, what a
-- setting does behind the "i" next to its control (`<label>.info`, InfoTip).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Components.Button)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Details = require(script.Parent.Parent.Components.Details)
local DamageNumbers = require(ReplicatedStorage.Shared.Data.DamageNumbers)
local DamageText = require(ReplicatedStorage.Shared.Logic.DamageText)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local KeybindData = require(ReplicatedStorage.Shared.Data.Keybinds)
local Keybinds = require(script.Parent.Parent.Keybinds)
local LanguageToggle = require(script.Parent.Parent.Components.LanguageToggle)
local ListRow = require(script.Parent.Parent.Components.ListRow)
local Lure = require(ReplicatedStorage.Shared.Logic.Lure)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Toast = require(script.Parent.Parent.Components.Toast)
local Vip = require(ReplicatedStorage.Shared.Logic.Vip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- Fixed keys listed under the rebindable ones (S17).
local FIXED_KEYS = {
	{ "menu.keys.lmb", "menu.keys.attack" },
	{ "Esc", "menu.keys.close" },
}

-- S135: a settings row is a ListRow (alternating parchment) with the control on the right. Owner 2026-10-21: with
-- `infoKey` an "i" left of the control holds what the setting does (the label stays short).
local INFO_W = 32
local rowCount = 0
local function row(scope: Scope, order: number, labelKey: string, control: Instance, infoKey: string?): Instance
	rowCount += 1
	local width = if control:IsA("GuiObject") then control.Size.X.Offset else 0
	local controlAny: any = control
	controlAny.Position = UDim2.new(1, -4, 0, 3)
	local right = (if width > 0 then width else 160) + 8
	return ListRow(scope, {
		LayoutOrder = order,
		Index = rowCount,
		Height = Theme.Size.MinTouch + 6,
		Text = Text.T(scope, labelKey),
		RightInset = right + (if infoKey then INFO_W else 0),
		[Children] = {
			control,
			if infoKey
				then InfoTip.new(scope, {
					Text = Text.T(scope, infoKey),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -right - INFO_W / 2, 0.5, 0),
				}) :: any
				else nil,
		},
	})
end

-- Owner 2026-10-21: a section of settings: its heading and its rows in order.
local function section(scope: Scope, order: number, titleKey: string, rows: { Instance }): Instance
	return scope:New("Frame")({
		Name = titleKey,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			scope:New("TextLabel")({
				Name = "Heading",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				Text = Text.T(scope, titleKey),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
			}),
			rows :: any,
		},
	})
end

-- Owner 2026-10-21: a rarely changed section, folded under its title ("Loot and trade ▸"; Details remembers it).
local function foldedSection(scope: Scope, order: number, titleKey: string, rows: { Instance }): Instance
	return Details.new(scope, {
		Key = `menu.{titleKey}`,
		Name = titleKey,
		LayoutOrder = order,
		Padding = Theme.Padding.Small,
		MoreText = scope:Computed(function(use): string
			return `{Text.get(use, titleKey)} ▸`
		end),
		LessText = scope:Computed(function(use): string
			return `{Text.get(use, titleKey)} ▾`
		end),
		Children = rows,
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

-- Loot filter tiers (S30): 0 = off, otherwise a rarity id of the 5-step ladder.
local function rarityLabel(use: Fusion.Use, value: any): string
	local id = tonumber(value) or 0
	if id < Rarities.COMMON or id > Rarities.MAX then
		return Text.get(use, "menu.off")
	end
	return Text.get(use, Rarities.get(id).nameKey)
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
			return if use(on) then "primary" else "secondary"
		end),
		Text = scope:Computed(function(use): string
			return Text.get(use, if use(on) then "menu.on" else "menu.off")
		end),
		OnClick = function()
			Net.Send("SetSetting", name, not Fusion.peek(on))
		end,
	})
end

-- S29: "Damage numbers: all / mine and received / off". Reads through DamageText.mode, so an old save with
-- the dmgNumbers switch off shows (and cycles on from) "off".
local function damageNumbers(scope: Scope): Instance
	local modeValue = State.Value({ "account", "settings", "dmgMode" })
	local oldSwitch = State.Value({ "account", "settings", "dmgNumbers" })
	local mode = scope:Computed(function(use): string
		return DamageText.mode({ dmgMode = use(modeValue), dmgNumbers = use(oldSwitch) })
	end)
	return Button(scope, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(150, 44),
		Text = scope:Computed(function(use): string
			return Text.get(use, `menu.damageNumbers.{use(mode)}`)
		end),
		OnClick = function()
			local modes = DamageNumbers.modes
			local index = table.find(modes, Fusion.peek(mode)) or 0
			Net.Send("SetSetting", "dmgMode", modes[index % #modes + 1])
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
				TextColor3 = Theme.Paper.Heading,
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
		LayoutOrder = 8,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		[Children] = {
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.35, 1),
				Text = Text.T(scope, "codes.title"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
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

-- S121: what the menu may open (ScreenController passes WindowManager.Open).
export type Extra = { OpenWindow: ((id: string) -> ())? }

-- S121: the VIP row: "VIP" always, "Return to the city (VIP)" only with VIP (disabled with the countdown or in town).
local function vipRow(scope: Scope, close: () -> (), extra: Extra?): Instance
	local active = State.Value({ "vip", "active" })
	local vipState = State.Value({ "account", "vip" })
	local map = State.Value({ "character", "location", "map" })
	local now = scope:Value(Clock.now())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Clock.now())
			end
		end
	end)
	local left = scope:Computed(function(use): number
		return Vip.recallLeft(use(vipState), use(now))
	end)
	local isVip = scope:Computed(function(use): boolean
		return use(active) == true
	end)
	local openWindow = extra and extra.OpenWindow
	return scope:New("Frame")({
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
		[Children] = {
			Button(scope, {
				Text = Text.T(scope, "menu.vip"),
				Variant = "secondary",
				Size = scope:Computed(function(use): UDim2
					return if use(isVip) then UDim2.new(0.4, -4, 1, 0) else UDim2.fromScale(1, 1)
				end),
				Disabled = openWindow == nil,
				OnClick = function()
					if openWindow then
						close()
						openWindow("vip")
					end
				end,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0.6, -4, 1, 0),
				Variant = "secondary",
				Visible = isVip,
				Disabled = scope:Computed(function(use): boolean
					return use(left) > 0 or use(map) == Config.StartingMap
				end),
				Text = scope:Computed(function(use): string
					local wait = use(left)
					if wait > 0 then
						return `{Text.get(use, "menu.vipRecall")} · {Time.format(wait)}`
					end
					return Text.get(use, "menu.vipRecall")
				end),
				OnClick = function()
					task.spawn(function()
						local ok, err, args = Net.Invoke("VipRecall")
						if ok then
							Sounds.play("levelUp")
							close()
						else
							Sounds.play("error")
							local resolved = if type(args) == "table" then args else nil
							Toast.push(Text.now(err or "error.internal", resolved), "error")
						end
					end)
				end,
			}),
		},
	})
end

-- S122: the Cloak of Luring row right after the sound rows, only while the account has cloak time (no dead switch).
local function lureRow(scope: Scope): Instance
	local lure = State.Value({ "account", "lure" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Workspace:GetServerTimeNow())
			end
		end
	end)
	local left = scope:Computed(function(use): number
		local state = use(lure)
		return Lure.left(if type(state) == "table" then state else nil, use(now))
	end)
	local on = scope:Computed(function(use): boolean
		local state = use(lure)
		return type(state) == "table" and state.on == true
	end)
	return scope:New("Frame")({
		LayoutOrder = 0,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 46),
		Visible = scope:Computed(function(use): boolean
			return use(left) > 0
		end),
		[Children] = {
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.6, 1),
				Text = scope:Computed(function(use): string
					local key, args = Lure.timeKey(use(left))
					return Text.get(use, "menu.lure", { time = Text.get(use, key, args) })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Paper.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(150, 44),
				Variant = "secondary",
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(on) then "premium.lure.toggleOff" else "premium.lure.toggleOn")
				end),
				OnClick = function()
					local wanted = not Fusion.peek(on)
					task.spawn(function()
						local ok, err = Net.Invoke("LureToggle", wanted)
						if ok then
							Sounds.play("levelUp")
						else
							Sounds.play("error")
							Toast.push(Text.now(err or "error.internal"), "error")
						end
					end)
				end,
			}),
		},
	})
end

local function GameMenu(scope: Scope, close: () -> (), extra: Extra?): Fusion.Child
	local busy = scope:Value(false)
	local dataMock = State.Value({ "session", "dataMock" })

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
						TextColor3 = Theme.Paper.TextMuted,
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
					return `<font color="#{Theme.Paper.Heading:ToHex()}"><b>{key}</b></font>   {Text.get(use, entry[2])}`
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		)
	end
	order += 1
	-- owner 2026-10-21: one short line, Esc and the swap behind the "i"
	table.insert(
		hotkeyRows,
		scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -INFO_W, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = Text.T(scope, "keys.hint"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				InfoTip.new(scope, {
					Text = Text.T(scope, "keys.hint.info"),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
				}),
			},
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
				LayoutOrder = 0,
				Text = Text.T(scope, "menu.resume"),
				Variant = "primary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				OnClick = close,
			}),
			Button(scope, {
				LayoutOrder = 1,
				Text = Text.T(scope, "menu.switchCharacter"),
				Variant = "secondary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Disabled = busy,
				OnClick = switchCharacter,
			}),
			vipRow(scope, close, extra),
			-- S129: the Blood Moon window (always: it shows when the next one starts)
			Button(scope, {
				LayoutOrder = 2.5,
				Text = Text.T(scope, "menu.bloodmoon"),
				Variant = "secondary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Disabled = extra == nil or extra.OpenWindow == nil,
				OnClick = function()
					local open = extra and extra.OpenWindow
					if open then
						close()
						open("bloodmoon")
					end
				end,
			}),
			-- S151b: the achievements window (the phone has no N key)
			Button(scope, {
				LayoutOrder = 2.6,
				Text = Text.T(scope, "menu.achievements"),
				Variant = "secondary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Disabled = extra == nil or extra.OpenWindow == nil,
				OnClick = function()
					local open = extra and extra.OpenWindow
					if open then
						close()
						open("achievements")
					end
				end,
			}),
			-- S152b: the season pass window (the phone has no C key)
			Button(scope, {
				LayoutOrder = 2.7,
				Text = Text.T(scope, "menu.season"),
				Variant = "secondary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Disabled = extra == nil or extra.OpenWindow == nil,
				OnClick = function()
					local open = extra and extra.OpenWindow
					if open then
						close()
						open("season")
					end
				end,
			}),
			-- S153: the "What has changed" letter again (the latest entries)
			Button(scope, {
				LayoutOrder = 2.8,
				Text = Text.T(scope, "menu.whatsnew"),
				Variant = "secondary",
				Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
				Disabled = extra == nil or extra.OpenWindow == nil,
				OnClick = function()
					local open = extra and extra.OpenWindow
					if open then
						close()
						open("whatsnew")
					end
				end,
			}),
			row(
				scope,
				3,
				"menu.language",
				LanguageToggle(scope, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) })
			),
			-- owner 2026-10-21: sections with headings; the rare ones folded
			section(scope, 4, "menu.section.sound", {
				row(scope, 1, "menu.volume", stepper(scope, "volume", 0.8, 0.1, 0, 1)),
				row(scope, 2, "menu.musicVolume", stepper(scope, "musicVolume", 0.6, 0.1, 0, 1)),
				row(scope, 3, "menu.ambientVolume", stepper(scope, "ambientVolume", 0.7, 0.1, 0, 1)),
			}),
			section(scope, 5, "menu.section.graphics", {
				-- W01: three graphics levels (Config.Graphics) and the camera mode (CameraController)
				row(
					scope,
					1,
					"menu.quality",
					cycle(scope, "quality", "high", { "low", "medium", "high" }, function(use, value)
						return Text.get(use, `menu.quality.{value}`)
					end)
				),
				row(
					scope,
					2,
					"menu.decor",
					cycle(scope, "decor", "mid", { "low", "mid", "high" }, function(use, value)
						return Text.get(use, `menu.decor.{value}`)
					end)
				),
				row(
					scope,
					3,
					"menu.cameraMode",
					cycle(scope, "cameraMode", "free", { "free", "top" }, function(use, value)
						return Text.get(use, `menu.cameraMode.{value}`)
					end)
				),
				row(scope, 4, "menu.cameraSens", stepper(scope, "cameraSens", 1, 0.1, 0.2, 3)),
				row(scope, 5, "menu.shake", stepper(scope, "shake", 1, 0.1, 0, 1), "menu.shake.info"),
				row(scope, 6, "menu.minimapRotate", toggle(scope, "minimapRotate", false)),
			}),
			section(scope, 6, "menu.section.combat", {
				lureRow(scope), -- S122 (order 0: only while the account has cloak time)
				row(scope, 1, "menu.quickCast", toggle(scope, "quickCast", false), "menu.quickCast.info"),
				row(scope, 2, "menu.autoTarget", toggle(scope, "autoTarget", true), "menu.autoTarget.info"),
				row(scope, 3, "menu.groupRings", toggle(scope, "groupRings", true)),
				row(scope, 4, "menu.damageNumbers", damageNumbers(scope)),
				-- S134f: low health vignette and heartbeat; the after-fight card
				row(scope, 5, "menu.lowHpWarn", toggle(scope, "lowHpWarn", true), "menu.lowHpWarn.info"),
				row(scope, 6, "menu.fightCard", toggle(scope, "fightCard", true), "menu.fightCard.info"),
			}),
			section(scope, 7, "menu.section.interface", {
				-- S156: the moved and sized HUD elements back to their places
				row(
					scope,
					1,
					"menu.hudLayout",
					Button(scope, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(150, 44),
						Variant = "secondary",
						Text = Text.T(scope, "menu.hudLayout.reset"),
						OnClick = function()
							Net.Send("SetSetting", "hud", {})
						end,
					}),
					"menu.hudLayout.info"
				),
				row(scope, 2, "menu.betterItem", toggle(scope, "betterItem", true)),
				row(scope, 3, "menu.barks", toggle(scope, "barks", true)), -- S101b: NPC comments during quests
				-- S151: achievement toasts
				row(scope, 4, "menu.achToasts", toggle(scope, "achToasts", true), "menu.achToasts.info"),
				row(scope, 5, "menu.mapCloseOnWalk", toggle(scope, "mapCloseOnWalk", true)),
			}),
			codeRow(scope),
			foldedSection(scope, 9, "menu.section.loot", {
				row(
					scope,
					1,
					"menu.lootHideBelow",
					cycle(
						scope,
						"lootHideBelow",
						0,
						{ 0, Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY },
						rarityLabel
					)
				),
				row(
					scope,
					2,
					"menu.lootAutoFrom",
					cycle(
						scope,
						"lootAutoFrom",
						0,
						{ 0, Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY, Rarities.MYTHIC },
						function(use, value)
							return if value == 0 then Text.get(use, "menu.all") else rarityLabel(use, value)
						end
					)
				),
				row(scope, 3, "menu.bindConfirm", toggle(scope, "bindConfirm", true)),
				row(scope, 4, "menu.sellConfirm", toggle(scope, "sellConfirm", true)),
			}),
			foldedSection(scope, 10, "menu.section.social", {
				-- S133: who may whisper, and the "<name> is in the game" toast
				row(
					scope,
					1,
					"menu.whispers",
					cycle(scope, "whispers", "all", { "all", "friends" }, function(use, value)
						return Text.get(use, `menu.whispers.{value}`)
					end)
				),
				row(scope, 2, "menu.friendAlerts", toggle(scope, "friendAlerts", true)),
				-- S150: appear offline and who may join my server (FriendService writes the presence entry by them)
				row(scope, 3, "menu.appearOffline", toggle(scope, "appearOffline", false), "menu.appearOffline.info"),
				row(
					scope,
					4,
					"menu.friendJoin",
					cycle(scope, "friendJoin", "friends", { "friends", "none" }, function(use, value)
						return Text.get(use, `menu.friendJoin.{value}`)
					end)
				),
				-- S132: the server writes the setting and changes the look
				row(scope, 5, "menu.robloxAvatar", toggle(scope, "robloxAvatar", false), "menu.robloxAvatar.hint"),
			}),
			foldedSection(scope, 11, "menu.hotkeys", {
				scope:New("Frame")({
					LayoutOrder = 1,
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
			}),
			scope:New("TextLabel")({
				Name = "MockWarning",
				LayoutOrder = 12,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = scope:Computed(function(use): boolean
					return use(dataMock) == true
				end),
				Text = Text.T(scope, "charSelect.mockWarning"),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Warning,
				TextWrapped = true,
			}),
		},
	})
end

return GameMenu
