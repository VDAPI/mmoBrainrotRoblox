--!strict
-- S156 / owner 2026-10-21: a HUD element the player moves and sizes (Logic/HudLayout, account.settings.hud.<id>).
-- `HudDrag.new` holds the saved entry, the one being dragged (`live`, until the save comes back) and the corner it
-- gives; a drag starts with `begin("move" | "size", input)` on a grip and follows the mouse or finger. A sized element
-- with `w` / `h` (the quest tracker) changes its size; a scaled one (the event panels, HudLayout `minS`) its UIScale.
-- `HudDrag.frame` wraps an event panel: the outer frame takes the saved place (or the built-in one), the scale and two
-- grips: "≡" on a tab at the side facing the middle of the screen, "◢" on the bottom-right corner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudLayout = require(ReplicatedStorage.Shared.Logic.HudLayout)
local HudStack = require(ReplicatedStorage.Shared.Logic.HudStack)
local Net = require(ReplicatedStorage.Shared.Net)
local Scale = require(script.Parent.Scale)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local HudDrag = {}

-- The top of the right column on PC (the quest tracker and the event panels): under the two rows of menu buttons,
-- the minimap and the guide bar (Hud menu: 16 + 2 x 52 + 8, then 8 + 220 + 8 + 44 = 408; one more row: 460).
-- Owner 2026-10-21: the column itself is Logic/HudStack (UI/HudSlots).
HudDrag.RIGHT_TOP = HudStack.RIGHT_TOP

local TAB_W, TAB_H = 20, 30
local TAB_TOUCH_W, TAB_TOUCH_H = 30, 44
local CORNER, CORNER_TOUCH = 18, 28

export type Handle = {
	id: string,
	entry: Fusion.Computed<HudLayout.Entry?>,
	-- the top-left corner in virtual pixels while the element has a saved place (nil: its built-in place)
	corner: Fusion.Computed<Vector2?>,
	scale: Fusion.Computed<number>,
	begin: (mode: string, input: InputObject) -> (),
	bind: (frame: GuiObject) -> (),
}

-- `width(use, entry)`: the element's own width (before its scale) for an entry.
function HudDrag.new(scope: Scope, id: string, width: (use: Fusion.Use, entry: HudLayout.Entry?) -> number): Handle
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
	local corner = scope:Computed(function(use): Vector2?
		local e = use(entry)
		if not e then
			return nil
		end
		local screen = use(Scale.VirtualSize)
		local x, y = HudLayout.place(e, width(use, e) * HudLayout.scaleOf(e), screen.X, screen.Y)
		return Vector2.new(x, y)
	end)

	local root: GuiObject? = nil
	local drag: { mode: string, start: Vector2, x: number, y: number, w: number, h: number, s: number }? = nil
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
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - d.start) / Scale.get()
			local screen = Fusion.peek(Scale.VirtualSize)
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
				Net.Send("SetSetting", "hud", HudLayout.with(Fusion.peek(saved), id, now))
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
		local screen = use(Scale.VirtualSize)
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
