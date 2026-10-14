--!strict
-- Sprint toggle for touch devices (S18, DESIGN §24), above the movement joystick. S96: hidden while riding (no
-- sprint in the saddle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Sprinting: Fusion.UsedAs<boolean>,
	OnToggle: () -> (),
	Riding: Fusion.UsedAs<any>?, -- S96
}

local ART = UiArt.hud("sprint") -- S119
local SIZE = 64

local function SprintButton(scope: Scope, props: Props): Instance
	local artShown = ArtIcon.Shown(scope, ART)
	return scope:New("TextButton")({
		Name = "SprintButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 60, 1, -260),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Visible = scope:Computed(function(use): boolean
			return use(Device.Touch) and not (props.Riding ~= nil and use(props.Riding) == true)
		end),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(props.Sprinting) then Theme.Colors.Accent else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.15,
		Text = Text.T(scope, "hud.sprint"),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = scope:Computed(function(use): number
			return if use(artShown) then 12 else Theme.TextSize.Small
		end),
		TextYAlignment = scope:Computed(function(use): Enum.TextYAlignment
			return if use(artShown) then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center
		end),
		TextColor3 = Theme.Colors.Text,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
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
				Tint = Theme.Colors.Text,
				Size = UDim2.fromScale(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.4),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Colors.Gold,
			}),
		},
	})
end

return SprintButton
