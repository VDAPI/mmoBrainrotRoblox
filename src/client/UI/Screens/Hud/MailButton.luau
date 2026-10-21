--!strict
-- Owner 2026-10-21 ("when the player gets something in the mail, show a mail icon with the number of messages in the
-- bottom-right corner under the attack button"): an envelope with the number of parcels waiting (state branch `mail`,
-- MailService publish, Logic/Mail.badge), only while there are any; a click opens the mail window (viewing works
-- anywhere, collecting at the mailbox). A phone in landscape: over the target button, left of the skill arc
-- (Logic/PhoneHud `mail`). It replaces the S156 envelope by the minimap.
-- Owner 2026-10-21 ("it touches the quest tracker and sits right by the attack button"): PC and tablet in its own slot
-- in the corner under the PvP toggle and its badge, over the EXP bar, clear of the attack button, the skill arc and the
-- column of panels above (Logic/HudStack.MAIL).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local Mail = require(ReplicatedStorage.Shared.Logic.Mail)
local Motion = require(script.Parent.Parent.Parent.Motion)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Open: () -> (),
}

local ART = UiArt.hud("mail")
local SPOT = HudStack.MAIL

local function MailButton(scope: Scope, props: Props): Instance
	local state = State.Value({ "mail" })
	local count = scope:Computed(function(use): number
		return (Mail.badge(use(state)))
	end)
	local label = scope:Computed(function(use): string
		local _, text = Mail.badge(use(state))
		return text or ""
	end)
	local artShown = ArtIcon.Shown(scope, ART)
	local button = scope:New("TextButton")({
		Name = "MailButton",
		AnchorPoint = PhoneLayout.Anchor(scope, "mail", Vector2.new(1, 1)),
		Position = PhoneLayout.Position(scope, "mail", UDim2.new(1, -SPOT.right, 1, -SPOT.bottom)),
		Size = PhoneLayout.Size(scope, "mail", UDim2.fromOffset(SPOT.w, SPOT.h)),
		Visible = scope:Computed(function(use): boolean
			return use(count) > 0
		end),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Text = scope:Computed(function(use): string
			return if use(artShown) then "" else "✉"
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Brass.Bright,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.Open()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = Theme.Brass.Line,
			}),
			ArtIcon.Image(scope, {
				Key = ART,
				Tint = Theme.Brass.Bright,
				Size = UDim2.fromScale(0.55, 0.55),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
			scope:New("TextLabel")({
				Name = "Count",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Theme.Iron.Danger,
				Text = label,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Iron.Text,
				ZIndex = 2,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({ Color = Theme.Iron.Surface, Thickness = Theme.Stroke.Thin }),
				},
			}),
		},
	})
	Motion.feedback(scope, button :: GuiButton, nil)
	Tooltip.attach(
		scope,
		button :: GuiObject,
		scope:Computed(function(use): string
			return Text.get(use, "hud.mail", { count = use(count) })
		end)
	)
	return button
end

return MailButton
