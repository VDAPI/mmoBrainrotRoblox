--!strict
-- PvP state dot next to a name (S18, DESIGN §3.3): green off, red on / forced, orange pulsing while
-- switching, grey with a padlock when it cannot change. Hover / long press explains the state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	State: Fusion.UsedAs<string>, -- PvpRules.Indicator
	Size: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Tooltip: boolean?,
}

local COLORS: { [string]: Color3 } = {
	off = Color3.fromHex("#4FD16B"),
	on = Color3.fromHex("#D64A3E"),
	forced = Color3.fromHex("#D64A3E"),
	switching = Color3.fromHex("#F0962E"),
	locked = Color3.fromHex("#7C7F88"),
}

local function PvpDot(scope: Scope, props: Props): Frame
	local size = props.Size or 14
	local pulse = scope:Value(0)
	local clock = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			if Fusion.peek(props.State) == "switching" then
				clock += dt
				pulse:set(0.5 + 0.5 * math.sin(clock * 8))
			elseif Fusion.peek(pulse) ~= 0 then
				pulse:set(0)
			end
		end)
	)
	local dot = scope:New("Frame")({
		Name = "PvpDot",
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0.5),
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = scope:Computed(function(use): Color3
			return COLORS[use(props.State)] or COLORS.off
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			return use(pulse) * 0.6
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("UIStroke")({ Color = Theme.Colors.Background, Thickness = 1.5 }),
			scope:New("TextLabel")({
				Name = "Lock",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = scope:Computed(function(use): boolean
					return use(props.State) == "locked"
				end),
				Text = "🔒",
				TextScaled = true,
				TextColor3 = Theme.Colors.Text,
			}),
		},
	}) :: Frame
	if props.Tooltip ~= false then
		Tooltip.attach(
			scope,
			dot,
			scope:Computed(function(use): string
				return Text.get(use, `pvp.dot.{use(props.State)}`)
			end)
		)
	end
	return dot
end

return PvpDot
