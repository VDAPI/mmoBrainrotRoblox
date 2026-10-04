--!strict
-- PvP switch in the bottom-right corner (DESIGN §3.3). Red glow when enabled, countdown while switching,
-- greyed out in green zones and "forced" in red zones. Clicking during a countdown cancels it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 64

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

	local button = scope:New("TextButton")({
		Name = "PvpToggle",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -Theme.Padding.Large, 1, -120),
		Size = UDim2.fromOffset(SIZE, SIZE),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(isOn) then
				return Theme.Colors.Danger:Lerp(Theme.Colors.Panel, 0.35)
			end
			return Theme.Colors.Panel
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(zoneType) == "green" then 0.45 else 0.05
		end),
		Text = "⚔",
		FontFace = Theme.Fonts.BodyBold,
		TextSize = 34,
		TextColor3 = scope:Computed(function(use): Color3
			if use(zoneType) == "green" then
				return Theme.Colors.TextMuted
			end
			return if use(isOn) then Theme.Colors.Text else Theme.Colors.Gold
		end),
		[OnEvent("Activated")] = click,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Computed(function(use): number
					return if use(isOn) then 4 else Theme.Stroke.Normal
				end),
				Color = scope:Computed(function(use): Color3
					return if use(isOn) then Theme.Colors.ZoneRed else Theme.Colors.GoldDim
				end),
			}),
			-- Countdown / "forced" badge above the button.
			scope:New("TextLabel")({
				Name = "Badge",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -4),
				Size = UDim2.fromOffset(110, 24),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.15,
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
				TextColor3 = Theme.Colors.Parchment,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
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
