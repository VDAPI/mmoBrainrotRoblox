--!strict
-- An item slot that toggles selection on click (selling, dismantling, picking an item to upgrade / unbind).
-- Shows the normal item visuals and tooltip, plus a gold check mark when selected.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.ItemSlot)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Id: string, -- unique per list, e.g. "sell:5"
	Item: UsedAs<Types.ItemInstance?>,
	Selected: UsedAs<boolean>,
	OnToggle: () -> (),
	Size: number?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
}

local function SelectableSlot(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local size = props.Size or 64
	local slot = ItemSlot(scope, {
		SlotId = `view:{props.Id}`,
		Item = props.Item,
		Size = size,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
	})
	scope:New("TextButton")({
		Name = "Toggle",
		Parent = slot,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			props.OnToggle()
		end,
		[Children] = {
			scope:New("Frame")({
				Name = "Selected",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.GoldBright,
				BackgroundTransparency = 0.75,
				Visible = props.Selected,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({ Color = Theme.Colors.GoldBright, Thickness = 3 }),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -2, 0, 0),
						Size = UDim2.fromOffset(20, 20),
						BackgroundTransparency = 1,
						Text = "✔",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 18,
						TextColor3 = Theme.Colors.GoldBright,
						TextStrokeTransparency = 0.3,
					}),
				},
			}),
		},
	})
	return slot
end

return SelectableSlot
