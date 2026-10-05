--!strict
-- Sprint toggle for touch devices (S18, DESIGN §24), above the movement joystick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Sprinting: Fusion.UsedAs<boolean>,
	OnToggle: () -> (),
}

local SIZE = 64

local function SprintButton(scope: Scope, props: Props): Instance
	return scope:New("TextButton")({
		Name = "SprintButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 60, 1, -260),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = Device.Touch,
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(props.Sprinting) then Theme.Colors.Accent else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.15,
		Text = Text.T(scope, "hud.sprint"),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Text,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Colors.Gold,
			}),
		},
	})
end

return SprintButton
