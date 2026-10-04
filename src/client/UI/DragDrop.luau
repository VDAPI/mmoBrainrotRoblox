--!strict
-- Item slot interaction shared by the backpack, equipment and potion bar (DESIGN §23):
--   mouse : click selects, drag & drop moves, double-click activates (equip / use / unequip)
--   touch : tap selects, tap another slot moves there, tap the selected slot again activates
-- Slots register with an id ("inv:5", "eq:weapon", "pot:hp"); ItemController sets the drop/activate handlers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Scale)
local Sounds = require(script.Parent.Sounds)

local DragDrop = {}

local DRAG_THRESHOLD = 6
local DOUBLE_CLICK = 0.35

local scope = Fusion.scoped(Fusion)
-- Currently selected slot id (highlighted; the inventory action bar acts on it).
DragDrop.Selected = scope:Value(nil :: string?)
-- Slot id being dragged and the ghost position (virtual pixels) for the drag preview.
DragDrop.Dragging = scope:Value(nil :: string?)
DragDrop.GhostPosition = scope:Value(Vector2.zero)

export type Handlers = {
	drop: (from: string, to: string) -> (),
	activate: (slotId: string) -> (),
	hasItem: (slotId: string) -> boolean,
}

local handlers: Handlers? = nil
local slots: { [GuiObject]: string } = {}
local pressed: { slotId: string, at: Vector2 }? = nil
local lastClick: { slotId: string, time: number }? = nil

function DragDrop.SetHandlers(h: Handlers)
	handlers = h
end

local function slotAt(position: Vector2): string?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		local id = slots[object]
		if id then
			return id
		end
	end
	return nil
end

local function activate(slotId: string)
	if handlers then
		Sounds.play("click")
		handlers.activate(slotId)
	end
end

-- os.clock() of the last drop, so a slot's own click handler can ignore the tap that completed a drop.
DragDrop.LastDropAt = 0

local function drop(from: string, to: string)
	if handlers and from ~= to then
		DragDrop.LastDropAt = os.clock()
		handlers.drop(from, to)
	end
end

local function hasItem(slotId: string): boolean
	return handlers ~= nil and handlers.hasItem(slotId)
end

-- Called by ItemSlot. The registration lives as long as `ownerScope`.
function DragDrop.register(ownerScope: Fusion.Scope<any>, object: GuiObject, slotId: string)
	slots[object] = slotId
	table.insert(ownerScope, function()
		slots[object] = nil
		if Fusion.peek(DragDrop.Selected) == slotId then
			DragDrop.Selected:set(nil)
		end
	end)

	table.insert(
		ownerScope,
		object.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed = { slotId = slotId, at = Vector2.new(input.Position.X, input.Position.Y) }
			elseif input.UserInputType == Enum.UserInputType.Touch then
				local selected = Fusion.peek(DragDrop.Selected)
				if selected == slotId then
					DragDrop.Selected:set(nil)
					activate(slotId)
				elseif selected and hasItem(selected) then
					DragDrop.Selected:set(nil)
					drop(selected, slotId)
				elseif hasItem(slotId) then
					DragDrop.Selected:set(slotId)
				end
			end
		end)
	)
end

function DragDrop.Clear()
	DragDrop.Selected:set(nil)
	DragDrop.Dragging:set(nil)
	pressed = nil
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	local press = pressed
	if press and Fusion.peek(DragDrop.Dragging) == nil then
		if (position - press.at).Magnitude >= DRAG_THRESHOLD and hasItem(press.slotId) then
			DragDrop.Dragging:set(press.slotId)
		end
	end
	if Fusion.peek(DragDrop.Dragging) then
		DragDrop.GhostPosition:set(Scale.toVirtual(position))
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local position = Vector2.new(input.Position.X, input.Position.Y)
	local dragging = Fusion.peek(DragDrop.Dragging)
	local press = pressed
	pressed = nil
	if dragging then
		DragDrop.Dragging:set(nil)
		local target = slotAt(position)
		if target then
			drop(dragging, target)
		end
		return
	end
	if not press then
		return
	end
	-- A click: select, or activate on double click.
	local now = os.clock()
	local last = lastClick
	if last and last.slotId == press.slotId and now - last.time <= DOUBLE_CLICK then
		lastClick = nil
		activate(press.slotId)
		return
	end
	lastClick = { slotId = press.slotId, time = now }
	if hasItem(press.slotId) then
		DragDrop.Selected:set(press.slotId)
	end
end)

return DragDrop
