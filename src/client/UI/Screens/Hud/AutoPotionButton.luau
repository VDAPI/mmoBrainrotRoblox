--!strict
-- Auto Potions on the HUD (S134d): a small "A" button right of Auto Hunt, shown while the account owns the service
-- (forever or with time; never a dead button). States: on (gold frame), off (grey), paused (on, but the state branch
-- `autoPotion.blocked` names a block: amber frame and the reason in the tooltip). Click / tap opens the panel under
-- it: the switch and the two thresholds (HP and the class resource) with -/+ buttons every Config.AutoPotion.step %
-- (touch friendly, no slider). Every change is one AutoPotionSet(on, hp, res); the server clamps the values
-- (Logic/AutoPotion.clampThreshold) and answers on the state branch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AutoPotion = require(ReplicatedStorage.Shared.Logic.AutoPotion)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Lure = require(ReplicatedStorage.Shared.Logic.Lure)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 48
local PANEL_W = 236
local AMBER = Theme.Glyph.Amber
local POTION = Theme.Glyph.Potion

local function AutoPotionButton(scope: Scope, position: UDim2): Instance
	local account = State.Value({ "account", "autoPotion" })
	local runtime = State.Value({ "autoPotion" })
	local classId = State.Value({ "character", "class" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local open = scope:Value(false)
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(5)
			if alive then
				now:set(Workspace:GetServerTimeNow())
			end
		end
	end)

	local state = scope:Computed(function(use): AutoPotion.State?
		local s = use(account)
		return if type(s) == "table" then s else nil
	end)
	local owned = scope:Computed(function(use): boolean
		return AutoPotion.owned(use(state), use(now))
	end)
	local on = scope:Computed(function(use): boolean
		local s = use(state)
		return s ~= nil and s.on == true
	end)
	local blocked = scope:Computed(function(use): string?
		local rt = use(runtime)
		return if use(on) and type(rt) == "table" and type(rt.blocked) == "string" then rt.blocked else nil
	end)
	local resKey = scope:Computed(function(use): string
		local class = Classes.get(use(classId) or "")
		return if class and class.resource == "energy"
			then "autoPotion.threshold.energy"
			else "autoPotion.threshold.mana"
	end)

	-- sends the whole state with one change; the server clamps and saves
	local function send(wantOn: boolean, hp: number, res: number)
		task.spawn(function()
			local ok, err = Net.Invoke("AutoPotionSet", wantOn, hp, res)
			if not ok then
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end
	local function current(): (boolean, number, number)
		local s = Fusion.peek(state)
		return s ~= nil and s.on == true,
			if s then AutoPotion.clampThreshold(s.hp) else 0,
			if s then AutoPotion.clampThreshold(s.res) else 0
	end
	local function nudge(field: "hp" | "res", delta: number)
		local isOn, hp, res = current()
		local function moved(value: number): number
			if value <= 0 and delta > 0 then
				return Config.AutoPotion.minPct
			end
			local nextValue = value + delta
			if nextValue < Config.AutoPotion.minPct then
				return 0 -- below the minimum: the threshold is off
			end
			return AutoPotion.clampThreshold(nextValue)
		end
		if field == "hp" then
			hp = moved(hp)
		else
			res = moved(res)
		end
		send(isOn, hp, res)
	end

	local function thresholdRow(order: number, field: "hp" | "res"): Instance
		local value = scope:Computed(function(use): number
			local s = use(state)
			return if s then AutoPotion.clampThreshold((s :: any)[field]) else 0
		end)
		return scope:New("Frame")({
			Name = `Row_{field}`,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -84, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					Text = scope:Computed(function(use): string
						local v = use(value)
						local key = if field == "hp" then "autoPotion.threshold.hp" else use(resKey)
						if v <= 0 then
							return Text.get(use, key, { pct = Text.get(use, "autoPotion.threshold.off") })
						end
						return Text.get(use, key, { pct = `{v}%` })
					end),
				}),
				Button(scope, {
					Surface = "iron", -- S135: on a dark HUD / overlay surface
					Name = "Minus",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -42, 0.5, 0),
					Size = UDim2.fromOffset(36, 30),
					Text = "−",
					OnClick = function()
						nudge(field, -Config.AutoPotion.step)
					end,
				}),
				Button(scope, {
					Surface = "iron", -- S135: on a dark HUD / overlay surface
					Name = "Plus",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(36, 30),
					Text = "+",
					OnClick = function()
						nudge(field, Config.AutoPotion.step)
					end,
				}),
			},
		})
	end

	local panel = scope:New("Frame")({
		Name = "AutoPotionPanel",
		Position = UDim2.fromOffset(0, SIZE + 24),
		Size = UDim2.fromOffset(PANEL_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Active = true,
		Visible = scope:Computed(function(use): boolean
			return use(open) and use(owned)
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Thickness = Theme.Stroke.Thin, Color = Theme.Brass.Line }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
			scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Brass.Bright,
				Text = Text.T(scope, "autoPotion.name"),
			}),
			thresholdRow(2, "hp"),
			thresholdRow(3, "res"),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Name = "Switch",
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				Variant = scope:Computed(function(use): any
					return if use(on) then "secondary" else "primary"
				end) :: any,
				TextSize = Theme.TextSize.Small,
				Text = scope:Computed(function(use): string
					return Text.get(use, if use(on) then "autoPotion.toggleOff" else "autoPotion.toggleOn")
				end),
				OnClick = function()
					local isOn, hp, res = current()
					send(not isOn, hp, res)
				end,
			}),
		},
	})

	local button = scope:New("TextButton")({
		Name = "AutoPotionButton",
		Size = UDim2.fromOffset(SIZE, SIZE),
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Text = "A",
		TextScaled = true,
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(on) then POTION else Theme.Iron.TextMuted
		end),
		TextTransparency = scope:Computed(function(use): number
			return if use(blocked) ~= nil then 0.45 else 0
		end),
		[OnEvent("Activated")] = function()
			open:set(not Fusion.peek(open))
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = scope:Computed(function(use): Color3
					if use(blocked) ~= nil then
						return AMBER
					end
					return if use(on) then Theme.Brass.Bright else Theme.Iron.TextMuted
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		},
	})
	local timeText = scope:Computed(function(use): string
		local s = use(state)
		if s and s.permanent then
			return Text.get(use, "autoPotion.forever")
		end
		local key, args = Lure.timeKey(AutoPotion.left(s, use(now)))
		return Text.get(use, key, args)
	end)
	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			local reason = use(blocked)
			local status = if reason
				then Text.get(use, "hud.autoPotion.paused", { reason = Text.get(use, reason) })
				elseif use(on) then Text.get(use, "hud.autoPotion.on")
				else Text.get(use, "hud.autoPotion.off")
			return Text.get(use, "hud.autoPotion", { state = status, time = use(timeText) })
		end)
	)

	return scope:New("Frame")({
		Name = "AutoPotion",
		Position = position,
		Size = UDim2.fromOffset(SIZE, SIZE + 20),
		BackgroundTransparency = 1,
		Visible = owned,
		[Children] = {
			button,
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(-12, SIZE),
				Size = UDim2.fromOffset(SIZE + 24, 20),
				BackgroundTransparency = 1,
				Text = timeText,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeTransparency = 0.3,
			}),
			panel,
		},
	})
end

return AutoPotionButton
