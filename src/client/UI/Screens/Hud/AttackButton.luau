--!strict
-- Big attack button for touch devices (DESIGN §23, §24): selects the nearest monster when there is no
-- target and walks into range; the server then attacks automatically. Skill buttons join it in S05.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	OnAttack: () -> (),
}

local SIZE = 104

local function AttackButton(scope: Scope, props: Props): Instance
	local pressed = scope:Value(false)
	return scope:New("TextButton")({
		Name = "AttackButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -150),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = Device.Touch,
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(pressed) then Theme.Colors.AccentPressed else Theme.Colors.Danger
		end),
		BackgroundTransparency = 0.1,
		Text = Text.T(scope, "combat.attack"),
		FontFace = Theme.Fonts.Heading,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Colors.Text,
		[OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnAttack()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Colors.Gold,
			}),
		},
	})
end

return AttackButton
