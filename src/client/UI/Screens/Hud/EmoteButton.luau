--!strict
-- Emote wheel buttons (S123, DESIGN-17 §4): a slot at the end of the action bar on PC (after the mount slot, with the
-- key label of Data/Keybinds "emote_wheel") and a round button right of the mount button on touch devices. Both open
-- the emote wheel (EmoteController.Toggle); the tooltip names the key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Keybinds = require(script.Parent.Parent.Parent.Keybinds)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local GLYPH = "☺"
local TOUCH_SIZE = 56

local EmoteButton = {}

local function tooltip(scope: Scope): Fusion.Computed<string>
	local key = Keybinds.Label(scope, "emote_wheel")
	return scope:Computed(function(use): string
		return `{Text.get(use, "hud.emotes")} ({use(key)})`
	end)
end

-- PC: a square slot in the action bar.
function EmoteButton.Slot(scope: Scope, props: { OnOpen: () -> (), LayoutOrder: number, SlotSize: number }): Instance
	local slot = scope:New("TextButton")({
		Name = "EmoteSlot",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(props.SlotSize, props.SlotSize),
		Visible = scope:Computed(function(use): boolean
			return use(Device.Touch) ~= true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Iron.Raised,
		BackgroundTransparency = Theme.HudAlpha,
		Text = "",
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnOpen()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Brass.Line,
			}),
			scope:New("TextLabel")({
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = GLYPH,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Title,
				TextColor3 = Theme.Iron.Text,
			}),
			scope:New("TextLabel")({
				Name = "Key",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 2),
				Size = UDim2.fromOffset(16, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Iron.Sunken, -- S136: the key on a plaque
				BackgroundTransparency = Theme.BadgeAlpha,
				Text = Keybinds.Label(scope, "emote_wheel"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.Text,
			}),
		},
	})
	Motion.feedback(scope, slot :: GuiButton, Theme.Corner.Small) -- W28: hover sheen and a sink while held
	Tooltip.attach(scope, slot :: GuiObject, tooltip(scope))
	return slot
end

-- Touch: a round button right of the mount button (same row as sprint and mount).
function EmoteButton.Touch(scope: Scope, props: { OnOpen: () -> () }): Instance
	local button = scope:New("TextButton")({
		Name = "EmoteButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 132 + 64 + 10, 1, -264),
		Size = UDim2.fromOffset(TOUCH_SIZE, TOUCH_SIZE),
		Visible = scope:Computed(function(use): boolean
			return use(Device.Touch) == true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Text = GLYPH,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Iron.Text,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnOpen()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Brass.Line,
			}),
		},
	})
	Motion.feedback(scope, button :: GuiButton, nil) -- W28: sinks while held
	return button
end

return EmoteButton
