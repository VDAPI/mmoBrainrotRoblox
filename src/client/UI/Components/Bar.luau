--!strict
-- Resource bar (HP / Mana / Energy / EXP) with a spring-animated fill and an optional "cur / max" label.
-- W28: `Ghost` leaves a pale brass segment where a loss was, which holds briefly and drains to the new value
-- (several hits in a row add up first); `Pulse` makes the fill breathe (the player's HP when it is low).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children
local peek = Fusion.peek

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Value: UsedAs<number>,
	Max: UsedAs<number>,
	Color: UsedAs<Color3>,
	Label: UsedAs<string>?, -- prefix, e.g. "HP"
	ShowNumbers: boolean?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	Name: string?,
	Surface: Theme.SurfaceName?, -- S135: the bar always draws its dark track; kept so callers can say where it stands
	Ghost: boolean?, -- W28: trailing segment of a loss (a bar whose owner never changes: the player's own HP)
	Pulse: Fusion.StateObject<boolean>?, -- W28: the fill breathes while true
}

local GHOST_MIX = 0.55 -- how far the ghost goes from the bar colour towards bright brass
local PULSE_PEAK = 0.72 -- transparency of the light veil over the fill at the top of a breath

local function Bar(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local ratio = scope:Computed(function(use): number
		local max: number = use(props.Max)
		if max <= 0 then
			return 0
		end
		local value: number = use(props.Value)
		return math.clamp(value / max, 0, 1)
	end)
	local animated = scope:Spring(ratio, Theme.Anim.BarSpeed, 1)

	-- W28: the ghost of a loss. A drop starts (or restarts) the hold; when it ends the ghost drains to the value.
	-- A gain hides the ghost at once.
	local ghost: Instance? = nil
	if props.Ghost then
		local alive = true
		table.insert(scope, function()
			alive = false
		end)
		local goal = scope:Value(peek(ratio))
		local draining = scope:Value(false)
		local shown = scope:Tween(goal, Theme.Anim.BarGhost)
		local token = 0
		scope:Observer(ratio):onChange(function()
			local now = peek(ratio)
			token += 1
			if now >= peek(goal) then
				draining:set(false)
				goal:set(now)
				return
			end
			draining:set(true)
			local mine = token
			task.delay(Theme.Anim.BarGhostHold, function()
				if alive and mine == token then
					goal:set(peek(ratio))
				end
			end)
		end)
		ghost = scope:New("Frame")({
			Name = "Ghost",
			BackgroundColor3 = scope:Computed(function(use): Color3
				return Theme.mix(use(props.Color), Theme.Brass.Bright, GHOST_MIX)
			end),
			Visible = draining,
			Size = scope:Computed(function(use): UDim2
				return UDim2.fromScale(math.clamp(use(shown), 0, 1), 1)
			end),
			ZIndex = 1,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	-- W28: a light veil over the fill that breathes in and out while `Pulse` is true (an engine tween, no per-frame work)
	local veil: Instance? = nil
	local pulse = props.Pulse
	if pulse then
		local frame = scope:New("Frame")({
			Name = "Pulse",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Plain,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		}) :: Frame
		veil = frame
		local tween: Tween? = nil
		table.insert(scope, function()
			if tween then
				tween:Cancel()
			end
		end)
		scope:Observer(pulse):onBind(function()
			if tween then
				tween:Cancel()
				tween = nil
			end
			frame.BackgroundTransparency = 1
			if peek(pulse) then
				local breath = TweenService:Create(frame, Theme.Anim.BarPulse, { BackgroundTransparency = PULSE_PEAK })
				breath:Play()
				tween = breath
			end
		end)
	end

	return scope:New("Frame")({
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.BarHeight),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Theme.Resource.Track,
		ClipsDescendants = true,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Brass.Line,
				Thickness = Theme.Stroke.Thin,
			}),
			ghost :: any,
			scope:New("Frame")({
				Name = "Fill",
				BackgroundColor3 = props.Color,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1)
				end),
				ZIndex = 2,
				[Children] = {
					veil :: any,
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIGradient")({
						Rotation = 90,
						Color = ColorSequence.new(Theme.Plain, Theme.mix(Theme.Plain, Theme.Shade, 0.3)),
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Label",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = scope:Computed(function(use): string
					local label = use(props.Label)
					if props.ShowNumbers == false then
						return label or ""
					end
					local numbers = `{Format.number(use(props.Value))} / {Format.number(use(props.Max))}`
					return if label then `{label}  {numbers}` else numbers
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				TextStrokeColor3 = Theme.Iron.Surface,
				TextStrokeTransparency = 0.3,
				ZIndex = 3,
			}),
		},
	})
end

return Bar
