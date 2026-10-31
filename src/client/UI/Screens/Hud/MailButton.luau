--!strict
-- Owner 2026-10-21 ("when the player gets something in the mail, show a mail icon with the number of messages in the
-- bottom-right corner under the attack button"): an envelope with the number of parcels waiting (state branch `mail`,
-- MailService publish, Logic/Mail.badge), only while there are any; a click opens the mail window (viewing works
-- anywhere, collecting at the mailbox). A phone in landscape: over the target button, left of the skill arc
-- (Logic/PhoneHud `mail`). It replaces the S156 envelope by the minimap.
-- Owner 2026-10-21 ("it touches the quest tracker and sits right by the attack button"): PC and tablet in its own slot
-- in the corner under the PvP toggle and its badge, over the EXP bar, clear of the attack button, the skill arc and the
-- column of panels above (Logic/HudStack.MAIL).
-- UI plan phase 2 (one place for "something waits"): PC and tablet in the row under the minimap (Hud/WaitingRow,
-- `InRow`); the corner's envelope is the phone's only (its own place by the skill arc).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
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
	InRow: boolean?, -- UI plan phase 2: a button of Hud/WaitingRow (PC and tablet), else the phone's envelope
}

local ART = UiArt.hud("mail")
local SPOT = HudStack.MAIL
local ROW = HudStack.WAITING

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
	local inRow = props.InRow == true
	local button = scope:New("TextButton")({
		Name = "MailButton",
		LayoutOrder = 1,
		AnchorPoint = if inRow then Vector2.zero else PhoneLayout.Anchor(scope, "mail", Vector2.new(1, 1)),
		Position = if inRow
			then UDim2.new()
			else PhoneLayout.Position(scope, "mail", UDim2.new(1, -SPOT.right, 1, -SPOT.bottom)),
		Size = if inRow
			then UDim2.fromOffset(ROW, ROW)
			else PhoneLayout.Size(scope, "mail", UDim2.fromOffset(SPOT.w, SPOT.h)),
		Visible = scope:Computed(function(use): boolean
			return use(count) > 0 and use(PhoneLayout.Compact) ~= inRow
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
	if not inRow then
		HudSlots.corner(scope, button :: GuiObject) -- owner 2026-10-22: the HUD column stays above where it really stands
	end
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
