--!strict
-- Character window (C), DESIGN §23: equipment silhouette on the left, primary stats with point
-- allocation and the grouped derived statistics on the right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local StatAllocator = require(script.StatAllocator)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local LEFT_WIDTH = 260
-- 4 stat rows (44 + 4) + points line + buttons + spacing.
local ALLOCATOR_HEIGHT = 290

local function CharacterWindow(scope: Scope): Fusion.Child
	local pending = scope:Value({} :: { [string]: number })
	local name = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })

	-- Any change of free points (confirm, level-up, reset) starts the allocation over.
	scope:Observer(State.Value({ "character", "statPoints" })):onChange(function()
		pending:set({})
	end)

	return {
		scope:New("Frame")({
			Name = "Left",
			Size = UDim2.new(0, LEFT_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, Theme.Padding.Small),
				}),
				scope:New("TextLabel")({
					Name = "CharName",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return use(name) or ""
					end),
					FontFace = Theme.Fonts.Heading,
					TextSize = Theme.TextSize.Title,
					TextColor3 = Theme.Colors.Gold,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextLabel")({
					Name = "ClassLevel",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local class = Classes.get(use(classId) or "")
						local className = if class then Text.get(use, class.nameKey) else ""
						return Text.get(use, "charSelect.classLevel", { class = className, level = use(level) or 1 })
					end),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.Parchment,
				}),
				Equipment(scope, { LayoutOrder = 3 }),
			},
		}),
		scope:New("Frame")({
			Name = "Right",
			Position = UDim2.fromOffset(LEFT_WIDTH + Theme.Padding.Large, 0),
			Size = UDim2.new(1, -(LEFT_WIDTH + Theme.Padding.Large), 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("Frame")({
					Name = "Allocator",
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = StatAllocator(scope, { Pending = pending }),
				}),
				DerivedList(scope, {
					Pending = pending,
					Position = UDim2.fromOffset(0, ALLOCATOR_HEIGHT),
					Size = UDim2.new(1, 0, 1, -ALLOCATOR_HEIGHT),
				}) :: any,
			},
		}),
	}
end

return CharacterWindow
