--!strict
-- Mount buttons (S96, docs/DESIGN-15.md §2): a slot after the potions in the action bar on PC (with the key label)
-- and a round button right of the sprint button on touch devices. Both only show once the character owns a mount
-- (MountController.Has); the accent colour means riding. Both call MountController.Toggle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Motion = require(script.Parent.Parent.Parent.Motion)
local Keybinds = require(script.Parent.Parent.Parent.Keybinds)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Riding: Fusion.UsedAs<any>,
	Has: Fusion.UsedAs<boolean>,
	OnToggle: () -> (),
	LayoutOrder: number?, -- slot: place in the action bar
	SlotSize: number?, -- slot: side (the action bar's slot size)
}

local TOUCH_SIZE = 64
local GLYPH = "🐎"

local MountButton = {}

local function riding(use: Fusion.Use, value: Fusion.UsedAs<any>): boolean
	return use(value) == true
end

local function label(scope: Scope, props: Props): Fusion.Computed<string>
	return scope:Computed(function(use): string
		return Text.get(use, if riding(use, props.Riding) then "hud.dismount" else "hud.mount")
	end)
end

-- PC: a square slot after the potion bar.
function MountButton.Slot(scope: Scope, props: Props): Instance
	local size = props.SlotSize or 56
	local slot = scope:New("TextButton")({
		Name = "MountSlot",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(size, size),
		Visible = scope:Computed(function(use): boolean
			return use(props.Has) == true and use(Device.Touch) ~= true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if riding(use, props.Riding) then Theme.Iron.Accent else Theme.Iron.Raised
		end),
		BackgroundTransparency = Theme.HudAlpha,
		Text = "",
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
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
				Text = Keybinds.Label(scope, "mount"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.Text,
			}),
		},
	})
	Motion.feedback(scope, slot :: GuiButton, Theme.Corner.Small) -- W28: hover sheen and a sink while held
	Tooltip.attach(scope, slot :: GuiObject, label(scope, props))
	return slot
end

-- Touch: a round button right of the sprint button, in the same row.
function MountButton.Touch(scope: Scope, props: Props): Instance
	local button = scope:New("TextButton")({
		Name = "MountButton",
		AnchorPoint = PhoneLayout.Anchor(scope, "mount", Vector2.new(0, 1)), -- W29: Logic/PhoneHud
		Position = PhoneLayout.Position(scope, "mount", UDim2.new(0, 132, 1, -260)),
		Size = PhoneLayout.Size(scope, "mount", UDim2.fromOffset(TOUCH_SIZE, TOUCH_SIZE)),
		Visible = scope:Computed(function(use): boolean
			return use(props.Has) == true and use(Device.Touch) == true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if riding(use, props.Riding) then Theme.Iron.Accent else Theme.Iron.Surface
		end),
		BackgroundTransparency = Theme.HudAlpha,
		Text = label(scope, props),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Iron.Text,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
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

return MountButton
