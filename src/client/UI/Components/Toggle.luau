--!strict
-- On/off switch with a label (S23): a 44 px row, a box "☑ / ☐" and the label; click flips the Value and
-- calls OnChange.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

export type Props = {
	Value: Fusion.Value<boolean>,
	Label: Fusion.UsedAs<string>,
	OnChange: ((value: boolean) -> ())?,
	Size: Fusion.UsedAs<UDim2>?,
	LayoutOrder: number?,
	Disabled: Fusion.UsedAs<boolean>?,
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

local function Toggle(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	return scope:New("TextButton")({
		Name = "Toggle",
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromOffset(220, Theme.Size.MinTouch),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(props.Value) then roles.Selected else roles.Raised
		end),
		Text = scope:Computed(function(use): string
			return `{if use(props.Value) then "☑" else "☐"}  {use(props.Label)}`
		end),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = scope:Computed(function(use): Color3
			if use(props.Disabled) == true then
				return roles.TextMuted
			end
			return if use(props.Value) then roles.Heading else roles.Text
		end),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		[OnEvent("Activated")] = function()
			if Fusion.peek(props.Disabled) == true then
				return
			end
			Sounds.play("click")
			local value = not Fusion.peek(props.Value)
			props.Value:set(value)
			if props.OnChange then
				props.OnChange(value)
			end
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = roles.Border,
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 6) }),
		},
	})
end

return Toggle
