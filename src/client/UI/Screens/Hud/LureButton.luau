--!strict
-- Cloak of Luring on the HUD (S122, DESIGN-17 §3): right of the login reward button, below the elixir icons. Shown
-- only while the account has cloak time (never a dead button); the time left under the icon. States: on (gold
-- frame), off (grey), paused (on, but the state branch `lure.blocked` names a block: amber frame, dimmed glyph and
-- the reason in the tooltip). Click / tap switches it (LureToggle; the server answers with a toast).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
local GLYPH = "❂"
local CLOAK = Color3.fromHex("#7A1F24")
local AMBER = Color3.fromHex("#D9922E")

local function LureButton(scope: Scope, position: UDim2): Instance
	local lure = State.Value({ "account", "lure" })
	local runtime = State.Value({ "lure" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	-- the clock ticks once a second, only while the button is shown (the account has cloak time)
	task.spawn(function()
		while alive do
			task.wait(1)
			local state = Fusion.peek(lure)
			if alive and type(state) == "table" and (state.untilTs or 0) > Fusion.peek(now) then
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
	local blocked = scope:Computed(function(use): string?
		local rt = use(runtime)
		return if use(on) and type(rt) == "table" and type(rt.blocked) == "string" then rt.blocked else nil
	end)
	local timeText = scope:Computed(function(use): string
		local key, args = Lure.timeKey(use(left))
		return Text.get(use, key, args)
	end)

	local button = scope:New("TextButton")({
		Name = "LureButton",
		Size = UDim2.fromOffset(SIZE, SIZE),
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		Text = GLYPH,
		TextScaled = true,
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = scope:Computed(function(use): Color3
			return if use(on) then CLOAK else Theme.Colors.TextMuted
		end),
		TextTransparency = scope:Computed(function(use): number
			return if use(blocked) ~= nil then 0.45 else 0
		end),
		[OnEvent("Activated")] = function()
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
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					if use(blocked) ~= nil then
						return AMBER
					end
					return if use(on) then Theme.Colors.GoldBright else Theme.Colors.TextMuted
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		},
	})
	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			local reason = use(blocked)
			local state = if reason
				then Text.get(use, "hud.lure.paused", { reason = Text.get(use, reason) })
				elseif use(on) then Text.get(use, "hud.lure.on")
				else Text.get(use, "hud.lure.off")
			return Text.get(use, "hud.lure", { state = state, time = use(timeText) })
		end)
	)

	return scope:New("Frame")({
		Name = "Lure",
		Position = position,
		Size = UDim2.fromOffset(SIZE, SIZE + 16),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(left) > 0
		end),
		[Children] = {
			button,
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(-12, SIZE),
				Size = UDim2.fromOffset(SIZE + 24, 16),
				BackgroundTransparency = 1,
				Text = timeText,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 12,
				TextColor3 = Theme.Colors.Text,
				TextStrokeTransparency = 0.3,
			}),
		},
	})
end

return LureButton
