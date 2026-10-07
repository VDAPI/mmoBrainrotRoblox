--!strict
-- Equipment silhouette: 10 gear slots + the backpack slot (DESIGN §5.1) around the class emblem.
-- Slots are ItemSlots ("eq:<slot>"): drag items from the backpack onto them, drag them back to unequip,
-- double-click / tap twice to unequip, hover for the item tooltip. S29: while an item is dragged (or, on
-- touch, selected) the slots it fits light up green, red when level / class does not allow it (with the
-- reason below the slots); the "Unequip" button acts on the selected slot. Slot size is a parameter
-- (72 on desktop, 56 on touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.Parent.DragDrop)
local EquipFit = require(ReplicatedStorage.Shared.Logic.EquipFit)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	LayoutOrder: number?,
	SlotSize: number?, -- default 72
	Gap: number?, -- default 12
	Unequip: ((slot: string) -> ())?, -- shows the "Unequip" button for the selected slot
}

local SLOT = 72
local GAP = 12
local HINT_HEIGHT = 22

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

-- Item behind a slot id ("inv:N" / "eq:<slot>"), for the drag highlight.
local function itemAt(slotId: string?, inventory: any, equipment: any): Types.ItemInstance?
	if not slotId then
		return nil
	end
	local kind, rest = string.match(slotId, "^(%a+):(.+)$")
	if kind == "inv" and type(inventory) == "table" then
		return inventory[rest]
	elseif kind == "eq" and type(equipment) == "table" then
		return equipment[rest]
	end
	return nil
end

local function Equipment(scope: Scope, props: Props): Instance
	local slot = props.SlotSize or SLOT
	local gap = props.Gap or GAP
	local equipment = State.Value({ "character", "equipment" })
	local inventory = State.Value({ "character", "inventory" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })

	-- What is being moved: the dragged slot, or on touch the selected one (tap item, then tap slot).
	local source = scope:Computed(function(use): string?
		local dragging = use(DragDrop.Dragging)
		if dragging then
			return dragging
		end
		return if use(Device.Touch) then use(DragDrop.Selected) else nil
	end)
	local moving = scope:Computed(function(use): Types.ItemInstance?
		return itemAt(use(source), use(inventory), use(equipment))
	end)
	local function fitFor(use: Fusion.Use, slotId: string): (string?, string?, number?)
		local item = use(moving)
		local from = use(source)
		if not item or not from or from == `eq:{slotId}` then
			return nil, nil, nil
		end
		if string.sub(from, 1, 3) == "eq:" then
			-- Only the rings move between equipment slots.
			local fromSlot = string.sub(from, 4)
			if EquipFit.group(fromSlot) == "ring" and EquipFit.group(slotId) == "ring" then
				return "ok", nil, nil
			end
			return nil, nil, nil
		end
		if not EquipFit.matchesSlot(item, slotId) then
			return nil, nil, nil
		end
		local eq = use(equipment)
		local ok, reason, required = EquipFit.check(item, slotId, {
			level = use(level) or 1,
			class = use(classId) or "",
			equipment = if type(eq) == "table" then eq else nil,
		})
		return if ok then "ok" else "bad", reason, required
	end

	local slots = {}
	for _, entry in LAYOUT do
		table.insert(
			slots,
			ItemSlot(scope, {
				SlotId = `eq:{entry.id}`,
				Size = slot,
				Placeholder = entry.glyph,
				Position = UDim2.fromOffset((entry.col - 1) * (slot + gap), (entry.row - 1) * (slot + gap)),
				Item = scope:Computed(function(use): Types.ItemInstance?
					local eq = use(equipment)
					return if type(eq) == "table" then eq[entry.id] else nil
				end),
				EmptyTooltip = Text.T(scope, `slot.{entry.id}`),
				DropHint = scope:Computed(function(use): string?
					return (fitFor(use, entry.id))
				end),
			})
		)
	end

	-- Why the dragged item does not fit (first matching slot that refuses it).
	local hintText = scope:Computed(function(use): string
		if not use(moving) then
			return ""
		end
		for _, entry in LAYOUT do
			local state, reason, required = fitFor(use, entry.id)
			if state == "ok" then
				return ""
			elseif state == "bad" and reason then
				local key, args = EquipFit.messageKey(reason, required)
				return Text.get(use, key, args)
			end
		end
		return ""
	end)

	local selectedSlot = scope:Computed(function(use): string?
		local selected = use(DragDrop.Selected)
		local id = selected and string.match(selected, "^eq:(.+)$")
		if not id or id == "backpack" then
			return nil
		end
		local eq = use(equipment)
		return if type(eq) == "table" and eq[id] then id else nil
	end)

	local width = 3 * slot + 2 * gap
	local height = 4 * slot + 3 * gap

	return scope:New("Frame")({
		Name = "Equipment",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(
			width,
			height + HINT_HEIGHT + (if props.Unequip then Theme.Size.ButtonHeightSmall else 0)
		),
		BackgroundTransparency = 1,
		[Children] = {
			-- Silhouette behind the middle column.
			scope:New("TextLabel")({
				Name = "Silhouette",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, slot / 2),
				Size = UDim2.fromOffset(slot + gap * 2, height - slot),
				BackgroundColor3 = Theme.Colors.PanelRaised,
				BackgroundTransparency = 0.5,
				Text = scope:Computed(function(use): string
					local class = Classes.get(use(classId) or "")
					return if class then class.icon else ""
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = math.floor(slot * 0.9),
				TextTransparency = 0.8,
				TextColor3 = Theme.Colors.Gold,
				ZIndex = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Large }),
				},
			}),
			slots :: any,
			scope:New("TextLabel")({
				Name = "FitHint",
				Position = UDim2.fromOffset(0, height + 2),
				Size = UDim2.new(1, 0, 0, HINT_HEIGHT - 2),
				BackgroundTransparency = 1,
				Text = hintText,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.DangerHover,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			if props.Unequip
				then Button(scope, {
					Name = "Unequip",
					Position = UDim2.fromOffset(0, height + HINT_HEIGHT),
					Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
					Text = Text.T(scope, "inventory.action.unequip"),
					TextSize = Theme.TextSize.Small,
					Visible = scope:Computed(function(use): boolean
						return use(selectedSlot) ~= nil
					end),
					OnClick = function()
						local id = Fusion.peek(selectedSlot)
						local unequip = props.Unequip
						if id and unequip then
							DragDrop.Clear()
							unequip(id)
						end
					end,
				})
				else nil :: any,
		},
	})
end

return Equipment
