--!strict
-- Emote wheel buttons (S123, DESIGN-17 §4): a slot at the end of the action bar on PC (after the mount slot, with the
-- key label of Data/Keybinds "emote_wheel") and a round button right of the mount button on touch devices. Both open
-- the emote wheel (EmoteController.Toggle); the tooltip names the key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.2,
		Text = "",
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnOpen()
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = Theme.Colors.Gold,
				Transparency = 0.3,
			}),
			scope:New("TextLabel")({
				Name = "Icon",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = GLYPH,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 28,
				TextColor3 = Theme.Colors.Text,
			}),
			scope:New("TextLabel")({
				Name = "Key",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 2),
				Size = UDim2.fromOffset(16, 14),
				BackgroundTransparency = 1,
				Text = Keybinds.Label(scope, "emote_wheel"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 12,
				TextColor3 = Theme.Colors.TextMuted,
			}),
		},
	})
	Tooltip.attach(scope, slot :: GuiObject, tooltip(scope))
	return slot
end

-- Touch: a round button right of the mount button (same row as sprint and mount).
function EmoteButton.Touch(scope: Scope, props: { OnOpen: () -> () }): Instance
	return scope:New("TextButton")({
		Name = "EmoteButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 132 + 64 + 10, 1, -264),
		Size = UDim2.fromOffset(TOUCH_SIZE, TOUCH_SIZE),
		Visible = scope:Computed(function(use): boolean
			return use(Device.Touch) == true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		Text = GLYPH,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = 26,
		TextColor3 = Theme.Colors.Text,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnOpen()
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

return EmoteButton
