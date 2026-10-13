--!strict
-- Mount buttons (S96, docs/DESIGN-15.md §2): a slot after the potions in the action bar on PC (with the key label)
-- and a round button right of the sprint button on touch devices. Both only show once the character owns a mount
-- (MountController.Has); the accent colour means riding. Both call MountController.Toggle.

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
			return if riding(use, props.Riding) then Theme.Colors.Accent else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.2,
		Text = "",
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
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
				Text = Keybinds.Label(scope, "mount"),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 12,
				TextColor3 = Theme.Colors.TextMuted,
			}),
		},
	})
	Tooltip.attach(scope, slot :: GuiObject, label(scope, props))
	return slot
end

-- Touch: a round button right of the sprint button, in the same row.
function MountButton.Touch(scope: Scope, props: Props): Instance
	return scope:New("TextButton")({
		Name = "MountButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 132, 1, -260),
		Size = UDim2.fromOffset(TOUCH_SIZE, TOUCH_SIZE),
		Visible = scope:Computed(function(use): boolean
			return use(props.Has) == true and use(Device.Touch) == true
		end),
		AutoButtonColor = false,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if riding(use, props.Riding) then Theme.Colors.Accent else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.15,
		Text = label(scope, props),
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

return MountButton
