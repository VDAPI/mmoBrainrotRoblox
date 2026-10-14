--!strict
-- Pictures of the quest objective items (S118): a row of small chips (picture + name) for the `item` of deliver and
-- collect objectives that have an owner's picture ("quest/<item>", UI/IconState.questPicture). Built inside the
-- Computed that draws a quest (it passes its `use`); returns nil when no item of the quest has a loaded picture, so
-- the quest window stays text only, as before the pictures.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.IconState)
local ItemIcons = require(ReplicatedStorage.Shared.Logic.ItemIcons)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 34

local function QuestItemIcons(
	scope: Scope,
	use: Fusion.Use,
	objectives: { Quests.Objective },
	layoutOrder: number?
): Instance?
	local chips: { Instance } = {}
	local seen: { [string]: boolean } = {}
	for _, objective in objectives do
		local item = objective.item
		if not item or seen[item] then
			continue
		end
		seen[item] = true
		local picture = IconState.questPicture(use, item)
		if not picture then
			continue
		end
		local layer = picture.layers[1]
		table.insert(
			chips,
			scope:New("Frame")({
				Name = item,
				LayoutOrder = #chips + 1,
				Size = UDim2.fromOffset(0, SIZE),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = 0.35,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					scope:New("ImageLabel")({
						LayoutOrder = 1,
						Size = UDim2.fromOffset(SIZE, SIZE),
						BackgroundTransparency = 1,
						Image = ItemIcons.sheet(layer.image) or "",
						ImageRectOffset = Vector2.new(layer.x, layer.y),
						ImageRectSize = Vector2.new(ItemIcons.CELL, ItemIcons.CELL),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.fromOffset(0, SIZE),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = Text.get(use, `quest.item.{item}`),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = 14,
						TextColor3 = Theme.Colors.Parchment,
					}),
				},
			})
		)
	end
	if #chips == 0 then
		return nil
	end
	return scope:New("Frame")({
		Name = "QuestItems",
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			chips :: any,
		},
	})
end

return QuestItemIcons
