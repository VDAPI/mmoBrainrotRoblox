--!strict
-- Owner 2026-10-21 (Studio: "the world boss panel covers the tracker's first line, the mail button touches the
-- tracker"): the client side of Logic/HudStack. The column's elements (the event panels, the Elite II timers and the
-- quest tracker) tell it whether they show, their size and the place the player moved them to (UI/HudDrag), and read
-- back their built-in place: top down in HudSlots.ORDER, round every moved element and the bottom-right corner's
-- buttons, so nothing covers anything. Replaces the S101 / S149b offsets the panels passed each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local PhoneLayout = require(script.Parent.PhoneLayout)
local Scale = require(script.Parent.Scale)

type Scope = Fusion.Scope<typeof(Fusion)>

local HudSlots = {}

-- What an element tells the column (Logic/HudStack.Box): shown, its size and the place the player moved it to.
export type Box = HudStack.Box

-- The order of the stack, top down (Logic/HudStack.ORDER).
HudSlots.ORDER = HudStack.ORDER

local scope = Fusion.scoped(Fusion)
local boxes = scope:Value({} :: { [string]: Box })

-- The built-in place of every shown element that has none of its own, by id.
HudSlots.Places = scope:Computed(function(use): { [string]: HudStack.Rect }
	local screen: Vector2 = use(Scale.VirtualSize)
	return HudStack.layout(
		use(Device.Touch) == true,
		use(PhoneLayout.Compact),
		screen.X,
		screen.Y,
		use(PhoneLayout.Others),
		use(boxes)
	)
end)

-- Joins element `id` (HudSlots.ORDER) to the column for the life of `s`; its built-in place (nil while hidden or
-- moved by the player).
function HudSlots.join(s: Scope, id: string, box: Fusion.UsedAs<Box>): Fusion.Computed<HudStack.Rect?>
	local function put(value: Box?)
		local now: { [string]: Box } = table.clone(Fusion.peek(boxes))
		now[id] = value :: any
		boxes:set(now)
	end
	local current = s:Computed(function(use): Box
		return use(box)
	end)
	s:Observer(current):onBind(function()
		put(Fusion.peek(current))
	end)
	table.insert(s, function()
		put(nil)
	end)
	return s:Computed(function(use): HudStack.Rect?
		return use(HudSlots.Places)[id]
	end)
end

-- The top-left corner of a slot as a position (anchor point 0, 0); a hidden element keeps its last one.
function HudSlots.position(s: Scope, slot: Fusion.Computed<HudStack.Rect?>): Fusion.Computed<UDim2>
	local last = UDim2.new()
	return s:Computed(function(use): UDim2
		local at = use(slot)
		if at then
			last = UDim2.fromOffset(at.left, at.top)
		end
		return last
	end)
end

-- The rectangle (virtual pixels) of an element the player moved: its corner and its size times its scale; nil at its
-- built-in place.
function HudSlots.moved(corner: Vector2?, w: number, h: number, scale: number): HudStack.Rect?
	if not corner then
		return nil
	end
	return { left = corner.X, top = corner.Y, right = corner.X + w * scale, bottom = corner.Y + h * scale }
end

return HudSlots
