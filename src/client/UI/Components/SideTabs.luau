--!strict
-- Vertical tab list (S23, dev panel): one button per tab in a scrolling column; the selected tab is
-- highlighted with a gold bar. Rows are 44 px high (touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

export type Tab = { id: string, label: Fusion.UsedAs<string> }

export type Props = {
	Tabs: { Tab },
	Selected: Fusion.Value<string>,
	Size: Fusion.UsedAs<UDim2>?,
	Position: Fusion.UsedAs<UDim2>?,
}

local function SideTabs(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local rows = {}
	for i, tab in props.Tabs do
		local selected = scope:Computed(function(use): boolean
			return use(props.Selected) == tab.id
		end)
		table.insert(
			rows,
			scope:New("TextButton")({
				Name = tab.id,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, Theme.Size.MinTouch),
				AutoButtonColor = false,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(selected) then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
				end),
				Text = tab.label,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(selected) then Theme.Colors.GoldBright else Theme.Colors.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				[OnEvent("Activated")] = function()
					if Fusion.peek(props.Selected) ~= tab.id then
						Sounds.play("click")
						props.Selected:set(tab.id)
					end
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14) }),
					scope:New("Frame")({
						Name = "Bar",
						Position = UDim2.fromOffset(-14, 6),
						Size = UDim2.new(0, 4, 1, -12),
						BackgroundColor3 = Theme.Colors.Gold,
						BorderSizePixel = 0,
						Visible = selected,
					}),
				},
			})
		)
	end
	return scope:New("ScrollingFrame")({
		Name = "SideTabs",
		Size = props.Size or UDim2.new(0, 170, 1, 0),
		Position = props.Position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		[Children] = {
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			rows :: any,
		},
	})
end

return SideTabs
