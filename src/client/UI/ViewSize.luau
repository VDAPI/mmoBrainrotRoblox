--!strict
-- The size of a view in virtual px, measured on screen. Owner 2026-11-10 via the UI plan (L10, "niektóre rzeczy
-- zasłaniają inne"): the item and character windows lay their parts out from their own content (Logic/GearLayout),
-- not from the screen. An AbsoluteSize divided by the UI scale (Scale.Value) alone is not that size inside a window:
-- the window's opening and closing motion scales its content too (Components/Window, a UIScale from 0.93 to 1 that
-- overshoots), so the size seemed to change on every frame of it. That slid the pinned buttons while a window opened
-- and rebuilt the whole backpack window on a phone (review of package D, 2026-11-10). A ruler of RULER virtual px among
-- the view's parts carries every scale above it, the layer's and the motion's, so the view's size over the ruler's is
-- the view's own. Both are read together once the frame has laid out (task.defer) and rounded to whole px, so the
-- size stays put through the motion.
--   local view = ViewSize.new(scope)  view.size: nil until measured; view.ruler goes among the frame's children
--   view.watch(frame)                 the frame whose size it is (once, right after creating it)
-- The ruler is a frame like any other: put it among absolutely placed parts, never under a UIListLayout or a
-- UIGridLayout, where it would take a place in the list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Size = { w: number, h: number }

export type View = {
	size: Fusion.Value<Size?>,
	ruler: Instance,
	watch: (frame: Instance) -> (), -- a GuiObject (scope:New gives an Instance)
}

local ViewSize = {}

ViewSize.RULER = 100

function ViewSize.new(scope: Scope): View
	local size = scope:Value(nil :: Size?)
	local ruler = scope:New("Frame")({
		Name = "Ruler",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(ViewSize.RULER, 0),
	}) :: Frame
	local frame: GuiObject? = nil
	local alive, queued = true, false

	local function read()
		queued = false
		if not alive or not frame then
			return
		end
		local unit = ruler.AbsoluteSize.X / ViewSize.RULER
		local absolute = frame.AbsoluteSize
		if unit <= 0 or absolute.X <= 0 or absolute.Y <= 0 then
			return
		end
		local w, h = math.round(absolute.X / unit), math.round(absolute.Y / unit)
		local old = Fusion.peek(size)
		if not old or old.w ~= w or old.h ~= h then
			size:set({ w = w, h = h })
		end
	end
	-- one read for the frame's and the ruler's change of the same layout pass
	local function queue()
		if not queued then
			queued = true
			task.defer(read)
		end
	end

	table.insert(scope, ruler:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue))
	table.insert(scope, function()
		alive = false
	end)
	return {
		size = size,
		ruler = ruler,
		watch = function(f: Instance)
			local gui = f :: GuiObject
			frame = gui
			table.insert(scope, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue))
			queue()
		end,
	}
end

return ViewSize
