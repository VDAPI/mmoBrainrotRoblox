--!strict
-- Big attack button for touch devices (DESIGN §23, §24): selects the nearest monster when there is no
-- target and walks into range; the server then attacks automatically. Skill buttons join it in S05.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	OnAttack: () -> (),
}

local ART = UiArt.hud("attack") -- S119
local SIZE = 104

local function AttackButton(scope: Scope, props: Props): Instance
	local pressed = scope:Value(false)
	local artShown = ArtIcon.Shown(scope, ART)
	local button = scope:New("TextButton")({
		Name = "AttackButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -150),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = Device.Touch,
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(pressed) then Theme.Iron.Accent else Theme.Paper.Danger -- S136: dark red under light text
		end),
		BackgroundTransparency = 0.1,
		Text = Text.T(scope, "combat.attack"),
		FontFace = Theme.Fonts.Display,
		TextSize = scope:Computed(function(use): number
			return if use(artShown) then Theme.TextSize.Small else Theme.TextSize.Large
		end),
		TextYAlignment = scope:Computed(function(use): Enum.TextYAlignment
			return if use(artShown) then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center
		end),
		TextColor3 = Theme.Iron.Text,
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
			-- S119: the silhouette above a smaller caption once loaded (the caption alone otherwise).
			scope:New("UIPadding")({
				PaddingBottom = scope:Computed(function(use): UDim
					return if use(artShown) then UDim.new(0.14, 0) else UDim.new()
				end),
			}),
			ArtIcon.Image(scope, {
				Key = ART,
				Tint = Theme.Iron.Text,
				Size = UDim2.fromScale(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.4),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thick,
				Color = Theme.Brass.Line,
			}),
		},
	})
	Motion.feedback(scope, button :: GuiButton, nil) -- W28: sinks while held
	return button
end

return AttackButton
