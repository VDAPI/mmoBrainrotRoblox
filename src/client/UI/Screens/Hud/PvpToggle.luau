--!strict
-- PvP switch in the bottom-right corner (DESIGN §3.3). Red glow when enabled, countdown while switching,
-- greyed out in green zones and "forced" in red zones. Clicking during a countdown cancels it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local Net = require(ReplicatedStorage.Shared.Net)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SPOT = HudStack.PVP -- owner 2026-10-21: the corner's places in one module (the mail under it)
local SIZE = SPOT.w
local BADGE = HudStack.PVP_BADGE
local ART = UiArt.hud("pvp") -- S119

local function PvpToggle(scope: Scope): Instance
	local enabled = State.Value({ "character", "pvpEnabled" })
	local pvp = State.Value({ "pvp" })
	local zone = State.Value({ "zone" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local busy = false

	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= 0.1 then
				accumulator = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)

	local zoneType = scope:Computed(function(use): string
		local z = use(zone)
		return if z then z.pvp else "green"
	end)
	local isOn = scope:Computed(function(use): boolean
		local z = use(zoneType)
		if z == "red" then
			return true
		elseif z == "green" then
			return false
		end
		return use(enabled) == true
	end)
	local remaining = scope:Computed(function(use): number?
		local state = use(pvp)
		if state and state.switchAt and state.pendingTarget ~= nil then
			return math.max(0, state.switchAt - use(now))
		end
		return nil
	end)

	local function click()
		if busy or Fusion.peek(zoneType) ~= "yellow" then
			Sounds.play("error")
			Toast.push(Text.now("pvp.error.zone"), "warning")
			return
		end
		local state = Fusion.peek(pvp)
		local target = if state and state.pendingTarget ~= nil
			then not state.pendingTarget
			else not Fusion.peek(enabled)
		busy = true
		Sounds.play("click")
		task.spawn(function()
			local ok, err = Net.Invoke("SetPvp", target)
			busy = false
			if not ok then
				Toast.push(Text.now(err or "error.internal", { seconds = Config.PvpCombatLock }), "error")
			end
		end)
	end

	local glyphColor = scope:Computed(function(use): Color3
		if use(zoneType) == "green" then
			return Theme.Iron.TextMuted
		end
		return if use(isOn) then Theme.Iron.Text else Theme.Iron.Heading
	end)
	local artShown = ArtIcon.Shown(scope, ART)
	local button = scope:New("TextButton")({
		Name = "PvpToggle",
		-- W29: under the menu drawer button left of the minimap on a phone in landscape (Logic/PhoneHud)
		AnchorPoint = PhoneLayout.Anchor(scope, "pvp", Vector2.new(1, 1)),
		Position = PhoneLayout.Position(scope, "pvp", UDim2.new(1, -SPOT.right, 1, -SPOT.bottom)),
		Size = UDim2.fromOffset(SIZE, SIZE),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(isOn) then
				return Theme.Iron.Danger:Lerp(Theme.Iron.Surface, 0.35)
			end
			return Theme.Iron.Surface
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(zoneType) == "green" then 0.45 else 0.05
		end),
		Text = scope:Computed(function(use): string
			return if use(artShown) then "" else "⚔"
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Title,
		TextColor3 = glyphColor,
		[OnEvent("Activated")] = click,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			-- S119: the PvP silhouette in the colour of the state once loaded.
			ArtIcon.Image(scope, {
				Key = ART,
				Tint = glyphColor,
				Size = UDim2.fromScale(0.6, 0.6),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					return if use(isOn) then 4 else Theme.Stroke.Normal
				end),
				Color = scope:Computed(function(use): Color3
					return if use(isOn) then Theme.Zone.Red else Theme.Iron.Rule
				end),
			}),
			-- Countdown / "forced" badge under the button.
			scope:New("TextLabel")({
				Name = "Badge",
				-- W29: under the button, as wide as it, on a phone in landscape (above it the drawer button)
				-- owner 2026-10-21: PC and tablet under the toggle too, right-aligned with it and as wide as its text
				-- (centred above it the text ran past the screen's edge; the mail has its own slot under it,
				-- Logic/HudStack)
				AnchorPoint = PhoneLayout.Pick(scope, Vector2.new(0.5, 0), Vector2.new(1, 0)),
				Position = PhoneLayout.Pick(scope, UDim2.new(0.5, 0, 1, 4), UDim2.new(1, 0, 1, BADGE.gap)),
				Size = PhoneLayout.Pick(scope, UDim2.fromOffset(SIZE, 24), UDim2.fromOffset(0, BADGE.h)),
				AutomaticSize = PhoneLayout.Pick(scope, Enum.AutomaticSize.None, Enum.AutomaticSize.X),
				TextScaled = PhoneLayout.Compact,
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				Visible = scope:Computed(function(use): boolean
					return use(remaining) ~= nil or use(zoneType) == "red"
				end),
				Text = scope:Computed(function(use): string
					local left = use(remaining)
					if left then
						return Text.get(use, "pvp.countdown", { seconds = math.ceil(left) })
					end
					return Text.get(use, "pvp.forced")
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Small),
						PaddingRight = UDim.new(0, Theme.Padding.Small),
					}),
					scope:New("UISizeConstraint")({
						MinSize = Vector2.new(SIZE, 0),
						MaxSize = Vector2.new(BADGE.w, BADGE.h),
					}),
				},
			}),
		},
	})

	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			local z = use(zoneType)
			local stateKey = if use(enabled) then "pvp.state.on" else "pvp.state.off"
			return `{Text.get(use, `pvp.rules.{z}`)}\n{Text.get(use, stateKey)}`
		end)
	)
	return button
end

return PvpToggle
