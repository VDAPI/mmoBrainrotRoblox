--!strict
-- Equipment silhouette: 10 gear slots + the backpack slot (DESIGN §5.1) around the class emblem.
-- Slots are ItemSlots ("eq:<slot>"): drag items from the backpack onto them, drag them back to unequip,
-- double-click / tap twice to unequip, hover for the item tooltip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOT = 72
local GAP = 12

-- slot id, placeholder glyph, column, row (3 x 4 grid; the middle column frames the silhouette)
local LAYOUT: { { id: string, glyph: string, col: number, row: number } } = {
	{ id = "necklace", glyph = "◎", col = 1, row = 1 },
	{ id = "helmet", glyph = "⛑", col = 2, row = 1 },
	{ id = "talisman", glyph = "✧", col = 3, row = 1 },
	{ id = "weapon", glyph = "⚔", col = 1, row = 2 },
	{ id = "armor", glyph = "♜", col = 2, row = 2 },
	{ id = "offhand", glyph = "⛨", col = 3, row = 2 },
	{ id = "ring1", glyph = "○", col = 1, row = 3 },
	{ id = "gloves", glyph = "✋", col = 2, row = 3 },
	{ id = "ring2", glyph = "○", col = 3, row = 3 },
	{ id = "backpack", glyph = "▣", col = 1, row = 4 },
	{ id = "boots", glyph = "⛸", col = 2, row = 4 },
}

local function Equipment(scope: Scope, props: { LayoutOrder: number? }): Instance
	local equipment = State.Value({ "character", "equipment" })
	local classId = State.Value({ "character", "class" })

	local slots = {}
	for _, entry in LAYOUT do
		table.insert(
			slots,
			ItemSlot(scope, {
				SlotId = `eq:{entry.id}`,
				Size = SLOT,
				Placeholder = entry.glyph,
				Position = UDim2.fromOffset((entry.col - 1) * (SLOT + GAP), (entry.row - 1) * (SLOT + GAP)),
				Item = scope:Computed(function(use): Types.ItemInstance?
					local eq = use(equipment)
					return if type(eq) == "table" then eq[entry.id] else nil
				end),
				EmptyTooltip = Text.T(scope, `slot.{entry.id}`),
			})
		)
	end

	local width = 3 * SLOT + 2 * GAP
	local height = 4 * SLOT + 3 * GAP

	return scope:New("Frame")({
		Name = "Equipment",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		[Children] = {
			-- Silhouette behind the middle column.
			scope:New("TextLabel")({
				Name = "Silhouette",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, SLOT / 2),
				Size = UDim2.fromOffset(SLOT + GAP * 2, height - SLOT),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = 0.5,
				Text = scope:Computed(function(use): string
					local class = Classes.get(use(classId) or "")
					return if class then class.icon else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 64,
				TextTransparency = 0.8,
				TextColor3 = Theme.Colors.Gold,
				ZIndex = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
				},
			}),
			slots :: any,
		},
	})
end

return Equipment
