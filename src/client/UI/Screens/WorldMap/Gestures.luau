--!strict
-- Pointer gestures of the world map (S20, S25): drag to pan (after a few pixels, so taps stay taps), wheel and
-- pinch to zoom, taps on icons and areas (their buttons call `buttonTap`), a tap on empty ground, and a double
-- tap / long press (touch) that opens the ground menu at that point. Presses that start on a panel over the map
-- (card, legend, chips) are left to that panel. InputObject.Position and AbsolutePosition share one space, so
-- the canvas pixel under a press is (position - canvas.AbsolutePosition) / scale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Canvas = require(script.Parent.Canvas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

local Gestures = {}

local TAP_MOVE = 8 -- pixels a press may move and still be a tap
local DOUBLE_TAP = 0.35 -- seconds between the taps of a double tap
local DOUBLE_DISTANCE = 24 -- pixels between the taps of a double tap
local LONG_PRESS = 0.55 -- seconds of a long press (touch)

export type Selection = { kind: string, id: string, extra: any? }

export type Props = {
	View: Frame,
	Canvas: () -> Canvas.Cached?,
	Pan: (delta: Vector2) -> (), -- in canvas pixels (zoom 1)
	Zoom: (delta: number) -> (),
	PinchStart: () -> number,
	PinchSet: (index: number) -> (),
	Select: (entry: Selection) -> (),
	Ground: () -> (), -- a plain tap on empty ground
	Menu: (pixel: Vector2) -> (), -- double tap / long press at a canvas pixel
}

export type Api = {
	-- Icon, area and marker buttons call this from Activated.
	buttonTap: (input: InputObject, entry: Selection) -> (),
	-- A button that is not a map object (menu, card) took the press.
	consume: () -> (),
}

function Gestures.new(scope: Scope, props: Props): Api
	local view = props.View
	local dragging = false
	local moved = 0
	local started = 0
	local consumed = false
	local longPressed = false
	local lastPosition = Vector2.zero
	local pressPosition = Vector2.zero
	local lastTap = { at = -math.huge, position = Vector2.zero }

	-- True when a panel or button outside the map view (card, legend, chips, search) is under the point.
	local function overOverlay(position: Vector2): boolean
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return false
		end
		for _, object in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
			if object.Visible and object ~= view and not object:IsDescendantOf(view) then
				if
					object:IsA("GuiButton")
					or object:IsA("TextBox")
					or object:IsA("ScrollingFrame")
					or object.BackgroundTransparency < 0.95
				then
					return true
				end
			end
		end
		return false
	end

	local function scaleOf(cached: Canvas.Cached): number
		return cached.canvas.AbsoluteSize.X / math.max(1, cached.canvas.Size.X.Offset)
	end

	local function canvasPoint(position: Vector2): Vector2?
		local cached = props.Canvas()
		if not cached then
			return nil
		end
		local factor = scaleOf(cached)
		if factor <= 0 then
			return nil
		end
		return (position - cached.canvas.AbsolutePosition) / factor
	end

	-- A tap on a map object or on the ground. Two quick taps at one spot open the ground menu (also over an
	-- area: areas cover most of a region map).
	local function tap(position: Vector2, entry: Selection?)
		local now = os.clock()
		local double = now - lastTap.at < DOUBLE_TAP and (position - lastTap.position).Magnitude < DOUBLE_DISTANCE
		lastTap = { at = now, position = position }
		if double and (entry == nil or entry.kind == "area") then
			local pixel = canvasPoint(position)
			if pixel then
				props.Menu(pixel)
			end
			return
		end
		if entry then
			props.Select(entry)
		else
			props.Ground()
		end
	end

	table.insert(
		scope,
		view.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local position = Vector2.new(input.Position.X, input.Position.Y)
			if overOverlay(position) then
				return
			end
			dragging = true
			lastPosition = position
			pressPosition = position
			moved = 0
			consumed = false
			longPressed = false
			started = os.clock()
			local mine = started
			if input.UserInputType == Enum.UserInputType.Touch then
				task.delay(LONG_PRESS, function()
					if dragging and started == mine and moved <= TAP_MOVE then
						local pixel = canvasPoint(pressPosition)
						if pixel then
							longPressed = true
							props.Menu(pixel)
						end
					end
				end)
			end
		end)
	)
	table.insert(
		scope,
		view.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				props.Zoom(if input.Position.Z > 0 then 1 else -1)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			if
				not dragging
				or (
					input.UserInputType ~= Enum.UserInputType.MouseMovement
					and input.UserInputType ~= Enum.UserInputType.Touch
				)
			then
				return
			end
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local delta = position - lastPosition
			lastPosition = position
			moved = math.max(moved, (position - pressPosition).Magnitude)
			local cached = props.Canvas()
			if moved <= TAP_MOVE or not cached then
				return
			end
			local factor = scaleOf(cached)
			if factor > 0 then
				props.Pan(delta / factor)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if
				not dragging
				or (
					input.UserInputType ~= Enum.UserInputType.MouseButton1
					and input.UserInputType ~= Enum.UserInputType.Touch
				)
			then
				return
			end
			dragging = false
			-- Buttons read the gesture in this frame; forget it shortly after.
			task.delay(0.08, function()
				if not dragging then
					moved = 0
					longPressed = false
				end
			end)
			if moved > TAP_MOVE or longPressed then
				return
			end
			local position = pressPosition
			-- Buttons answer in the same frame; a tap no icon, area or panel took is a tap on the ground.
			task.delay(0.03, function()
				if consumed or overOverlay(position) then
					return
				end
				tap(position, nil)
			end)
		end)
	)
	local pinchStart = 1
	table.insert(
		scope,
		UserInputService.TouchPinch:Connect(function(_, scaleFactor, _, state)
			if state == Enum.UserInputState.Begin then
				pinchStart = props.PinchStart()
				moved = math.huge
			elseif state == Enum.UserInputState.Change then
				local target = if scaleFactor > 1.3
					then pinchStart + 1
					elseif scaleFactor < 0.75 then pinchStart - 1
					else pinchStart
				props.PinchSet(target)
			end
		end)
	)

	return {
		buttonTap = function(input: InputObject, entry: Selection)
			if moved > TAP_MOVE or longPressed then
				return
			end
			consumed = true
			tap(Vector2.new(input.Position.X, input.Position.Y), entry)
		end,
		consume = function()
			consumed = true
		end,
	}
end

return Gestures
