--!strict
-- Resource bar (HP / Mana / Energy / EXP) with a spring-animated fill and an optional "cur / max" label.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

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
}

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

	return scope:New("Frame")({
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.BarHeight),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.GoldDim,
				Thickness = 1,
			}),
			scope:New("Frame")({
				Name = "Fill",
				BackgroundColor3 = props.Color,
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromScale(math.clamp(use(animated), 0, 1), 1)
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIGradient")({
						Rotation = 90,
						Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
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
				TextColor3 = Theme.Colors.Text,
				TextStrokeTransparency = 0.5,
				ZIndex = 2,
			}),
		},
	})
end

return Bar
