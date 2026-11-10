--!strict
-- S156 / owner 2026-10-21: a HUD element the player moves and sizes (Logic/HudLayout, account.settings.hud.<id>).
-- `HudDrag.new` holds the saved entry, the one being dragged (`live`, until the save comes back) and the corner it
-- gives; a drag starts with `begin("move" | "size", input)` on a grip and follows the mouse or finger. A sized element
-- with `w` / `h` (the quest tracker) changes its size; a scaled one (the event panels, HudLayout `minS`) its UIScale.
-- `HudDrag.frame` wraps an event panel: the outer frame takes the saved place (or the built-in one), the scale and two
-- grips: "≡" on a tab at the side facing the middle of the screen, "◢" on the bottom-right corner.
-- Owner 2026-11-10 ("things covering each other"; UI plan package A): a moved element never stands in a reserved place
-- (Logic/HudLayout.reserved: the target band, the message zone and the card slot on PC and a tablet, the target with
-- its M zone and the thumb zone on a phone). A saved place there (saved on another screen, or before this rule) falls
-- back to the built-in place, and a drop there keeps the place the element had (HudLayout.valid() is unchanged: old
-- saves still read). While a drag runs the element follows the pointer anywhere, so the player sees what they do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudSlots = require(script.Parent.HudSlots)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local Net = require(ReplicatedStorage.Shared.Net)
local PhoneLayout = require(script.Parent.PhoneLayout)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local HudDrag = {}

-- The top of the right column on PC (the quest tracker and the event panels): under the one row of menu buttons, the
-- minimap (UI plan phase 1 and 4; the guide bar pushes it to HudStack.RIGHT_TOP_GUIDE while it shows).
-- Owner 2026-10-21: the column itself is Logic/HudStack (UI/HudSlots).
HudDrag.RIGHT_TOP = HudStack.RIGHT_TOP

local TAB_W, TAB_H = 20, 30
local TAB_TOUCH_W, TAB_TOUCH_H = 30, 44
local CORNER, CORNER_TOUCH = 18, 28
local DEAD_ZONE = 6 -- screen pixels a grip's pointer moves before the element does

export type Handle = {
	id: string,
	entry: Fusion.Computed<HudLayout.Entry?>,
	-- the top-left corner in virtual pixels while the element has a saved place (nil: its built-in place)
	corner: Fusion.Computed<Vector2?>,
	scale: Fusion.Computed<number>,
	begin: (mode: string, input: InputObject) -> (),
	bind: (frame: GuiObject) -> (),
}

-- `width(use, entry)`: the element's own width (before its scale) for an entry. `height(use, entry, x, y)`: its own
-- height (before its scale) with its top-left corner at x, y and folded only as the player folded it. Package A
-- review (owner 2026-11-10, "things covering each other"): the height as drawn shrinks while the column folds the
-- element, so a saved place could look free only while it stood folded in the column, and the element would flip
-- between that place and the column; without `height` the drawn height is measured.
function HudDrag.new(
	scope: Scope,
	id: string,
	width: (use: Fusion.Use, entry: HudLayout.Entry?) -> number,
	height: ((use: Fusion.Use, entry: HudLayout.Entry, x: number, y: number) -> number)?
): Handle
	local def = HudLayout.ELEMENTS[id]
	local scaled = def.minS ~= nil
	local saved = State.Value({ "account", "settings", "hud" })
	local live = scope:Value(nil :: HudLayout.Entry?)
	scope:Observer(saved):onChange(function()
		live:set(nil)
	end)
	local entry = scope:Computed(function(use): HudLayout.Entry?
		local now = use(live)
		if now then
			return now
		end
		local layout = use(saved)
		local e = if type(layout) == "table" then layout[id] else nil
		return if type(e) == "table" and type(e.x) == "number" and type(e.y) == "number" then e else nil
	end)
	local scale = scope:Computed(function(use): number
		return HudLayout.scaleOf(use(entry))
	end)
	-- the element's height as drawn (virtual px, with its scale): a sized one keeps its own, a scaled panel is measured
	local measured = scope:Value(0)
	-- the corner entry `e` gives on the screen now, and whether the element stands clear of the reserved places there
	local function placed(use: Fusion.Use, e: HudLayout.Entry): (Vector2, boolean)
		local screen = use(Scale.HudSize)
		local s = HudLayout.scaleOf(e)
		local w = width(use, e) * s
		local x, y = HudLayout.place(e, w, screen.X, screen.Y)
		-- Studio check of phase 4: whole on the screen, MARGIN from its edges (a place saved at a larger window ran
		-- past the right edge of a smaller one)
		x = HudStack.insideX(x, w, screen.X)
		-- Studio check 2026-10-31: never under the menu over the minimap (a phone keeps its own stack)
		local compact = use(PhoneLayout.Compact)
		if not compact then
			y = HudStack.belowMenu(x, x + w, y, use(HudSlots.Menu))
		end
		local h = if e.w and e.h then e.h * s elseif height then height(use, e, x, y) * s else use(measured)
		local rect = { left = x, top = y, right = x + w, bottom = y + h }
		return Vector2.new(x, y), HudLayout.usable(rect, screen.X, screen.Y, use(Device.Touch) == true, compact)
	end
	local corner = scope:Computed(function(use): Vector2?
		local e = use(entry)
		if not e then
			return nil
		end
		local at, free = placed(use, e)
		-- a saved place in a reserved zone: the built-in place (a drag in progress follows the pointer)
		if not free and use(live) == nil then
			return nil
		end
		return at
	end)

	local root: GuiObject? = nil
	local drag: {
		mode: string,
		start: Vector2,
		x: number,
		y: number,
		w: number,
		h: number,
		s: number,
		moving: boolean,
	}? =
		nil
	local function begin(mode: string, input: InputObject)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local frame = root
		local parent = frame and frame.Parent
		if not frame or not parent or not parent:IsA("GuiObject") then
			return
		end
		local k = Scale.get()
		local at = (frame.AbsolutePosition - parent.AbsolutePosition) / k
		local size = frame.AbsoluteSize / k
		drag = {
			mode = mode,
			start = Vector2.new(input.Position.X, input.Position.Y),
			x = at.X,
			y = at.Y,
			w = size.X,
			h = size.Y,
			s = Fusion.peek(scale),
			moving = false,
		}
	end
	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			local d = drag
			local kind = input.UserInputType
			if not d or (kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch) then
				return
			end
			local pointer = Vector2.new(input.Position.X, input.Position.Y)
			-- owner 2026-10-22: a click on a grip (or a wobble of a few pixels) moves nothing: the element keeps its
			-- built-in place in the column (a tracker "moved" 5 px up left its column and ran into the PvP toggle)
			if not d.moving and (pointer - d.start).Magnitude < DEAD_ZONE then
				return
			end
			d.moving = true
			local delta = (pointer - d.start) / Scale.get()
			local screen = Fusion.peek(Scale.HudSize)
			local e = Fusion.peek(entry)
			if d.mode == "size" and scaled then
				-- the panel grows with the corner: its new width over the width it had
				local s = HudLayout.clampScale(id, d.s * (d.w + delta.X) / math.max(1, d.w))
				live:set(HudLayout.entryAt(d.x, d.y, screen.X, screen.Y, nil, nil, s))
			elseif d.mode == "size" then
				local w, h = HudLayout.clampSize(id, d.w + delta.X, d.h + delta.Y)
				live:set(HudLayout.entryAt(d.x, d.y, screen.X, screen.Y, w, h))
			else
				local w = if e and e.w and e.h then e.w else nil
				local h = if e and e.w and e.h then e.h else nil
				local s = if e and e.s then e.s else nil
				live:set(HudLayout.entryAt(d.x + delta.X, d.y + delta.Y, screen.X, screen.Y, w, h, s))
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			local kind = input.UserInputType
			if not drag or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
				return
			end
			drag = nil
			local now = Fusion.peek(live)
			if now then
				local _, free = placed(Fusion.peek, now)
				if free then
					Net.Send("SetSetting", "hud", HudLayout.with(Fusion.peek(saved), id, now))
				else
					-- dropped on a reserved place: it goes back where it stood
					live:set(nil)
				end
			end
		end)
	)

	return {
		id = id,
		entry = entry,
		corner = corner,
		scale = scale,
		begin = begin,
		bind = function(frame: GuiObject)
			root = frame
			local function measure()
				local k = Scale.get()
				if k > 0 then
					measured:set(frame.AbsoluteSize.Y / k)
				end
			end
			table.insert(scope, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure))
			task.defer(measure)
		end,
	}
end

export type FrameProps = {
	Name: string,
	-- the built-in place (used while the element has no saved one)
	AnchorPoint: Fusion.UsedAs<Vector2>,
	Position: Fusion.UsedAs<UDim2>,
	Size: Fusion.UsedAs<UDim2>, -- before the scale
	Visible: Fusion.UsedAs<boolean>,
	Content: Instance, -- fills the frame
}

-- The outer frame of a movable event panel (see the header).
function HudDrag.frame(scope: Scope, handle: Handle, props: FrameProps): Instance
	-- the tab faces the middle of the screen: left of a panel on the right half, right of one on the left half
	local tabLeft = scope:Computed(function(use): boolean
		local at = use(handle.corner)
		local screen = use(Scale.HudSize)
		if at then
			return at.X > screen.X / 2
		end
		-- the built-in place (a UI/HudSlots slot is an offset from the left edge)
		local position: UDim2 = use(props.Position)
		return position.X.Scale * screen.X + position.X.Offset >= screen.X / 2
	end)
	local frame = scope:New("Frame")({
		Name = props.Name,
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(handle.corner) then Vector2.zero else use(props.AnchorPoint)
		end),
		Position = scope:Computed(function(use): UDim2
			local at = use(handle.corner)
			return if at then UDim2.fromOffset(at.X, at.Y) else use(props.Position)
		end),
		Size = props.Size,
		BackgroundTransparency = 1,
		Visible = props.Visible,
		[Children] = {
			scope:New("UIScale")({ Scale = handle.scale }),
			props.Content,
			scope:New("TextButton")({
				Name = "MoveGrip",
				AnchorPoint = scope:Computed(function(use): Vector2
					return if use(tabLeft) then Vector2.new(1, 0) else Vector2.zero
				end),
				Position = scope:Computed(function(use): UDim2
					return if use(tabLeft) then UDim2.fromOffset(-2, 0) else UDim2.new(1, 2, 0, 0)
				end),
				Size = scope:Computed(function(use): UDim2
					return if use(Device.Touch)
						then UDim2.fromOffset(TAB_TOUCH_W, TAB_TOUCH_H)
						else UDim2.fromOffset(TAB_W, TAB_H)
				end),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				AutoButtonColor = false,
				Text = "≡",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.TextMuted,
				[OnEvent("InputBegan")] = function(input: InputObject)
					handle.begin("move", input)
				end,
				[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			}),
			scope:New("TextButton")({
				Name = "SizeGrip",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -2, 1, -2),
				Size = scope:Computed(function(use): UDim2
					local side = if use(Device.Touch) then CORNER_TOUCH else CORNER
					return UDim2.fromOffset(side, side)
				end),
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "◢",
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = Theme.Iron.TextMuted,
				ZIndex = 3,
				[OnEvent("InputBegan")] = function(input: InputObject)
					handle.begin("size", input)
				end,
			}),
		},
	}) :: Frame
	handle.bind(frame)
	return frame
end

return HudDrag
