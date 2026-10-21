--!strict
-- Shared "i" info button (2026-10-21, owner: too many detailed descriptions make the game hard to read). A window shows
-- one short line and puts the long text (rules, formulas, sources, lore) behind a small round "i" next to it.
-- PC: pointing at the "i" shows the popover, a click pins it (a second click or a click outside closes it). Touch: a
-- tap toggles it, a tap outside closes it. The touch target is at least Theme.Size.MinTouch, the drawn circle stays
-- small. The popover is one panel for the whole game in the Tooltip layer (InfoTip.mount from UIController), so a
-- ScrollingFrame never clips it. Text and title may be rich text and Fusion states (they update while it is open).
--
--   InfoTip.new(scope, { Text = Text.T(scope, "craft.info.long"), Title = ..., Surface = "paper", LayoutOrder = 2 })
--
-- Recipe "short line + (i)": docs/JAK-DODAC.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Text: UsedAs<string>, -- the detailed text (rich text allowed)
	Title: UsedAs<string>?, -- optional bold first line of the popover
	Surface: Theme.SurfaceName?, -- what the "i" stands on: "paper" (default, windows) or "iron" (HUD, tooltips)
	Size: number?, -- drawn diameter on PC in virtual pixels (default 20; touch draws it TOUCH_EXTRA larger)
	LayoutOrder: UsedAs<number>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	Visible: UsedAs<boolean>?,
	ZIndex: number?,
	Name: string?,
}

local DEFAULT_SIZE = 20
local TOUCH_EXTRA = 6 -- touch draws the circle a little larger
local PC_HIT_EXTRA = 8 -- PC: the pointer area is this much larger than the circle
local MAX_WIDTH = 320
local MARGIN = 8 -- distance from the screen edges
local GAP = 6 -- between the "i" and the popover
local Z = 220 -- above the item tooltip (200) and its details panel (210)

local InfoTip = {}

local moduleScope = Fusion.scoped(Fusion)
local shownText = moduleScope:Value(nil :: string?)
local shownTitle = moduleScope:Value(nil :: string?)
local anchorAt = moduleScope:Value(Vector2.zero) -- virtual top left of the open "i" in the layer
local anchorSize = moduleScope:Value(Vector2.zero)
local owner: GuiObject? = nil
local pinned = false
local layerRoot: GuiObject? = nil
local panel: GuiObject? = nil
local follow: RBXScriptConnection? = nil

local function place(object: GuiObject)
	local root = layerRoot
	anchorAt:set(
		if root then Scale.toLayer(object.AbsolutePosition, root) else Scale.toVirtual(object.AbsolutePosition)
	)
	anchorSize:set(Scale.toVirtual(object.AbsoluteSize))
end

local function close()
	owner = nil
	pinned = false
	if follow then
		follow:Disconnect()
		follow = nil
	end
	shownText:set(nil)
	shownTitle:set(nil)
end

-- Closes whatever popover is open (e.g. a window that hides its content).
function InfoTip.close()
	close()
end

-- True while the popover belongs to `object` (the hit area of an InfoTip).
function InfoTip.isOpen(object: GuiObject): boolean
	return owner == object
end

local function open(object: GuiObject, text: string, title: string?, pin: boolean)
	if owner ~= object then
		close()
		owner = object
		-- the popover follows its "i" while the list under it scrolls
		follow = object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if owner == object then
				place(object)
			end
		end)
	end
	pinned = pin
	place(object)
	shownTitle:set(if title ~= "" then title else nil)
	shownText:set(text)
end

-- The "i" itself: a frame of the drawn size (fits a row of text) with a larger transparent hit area centred on it.
function InfoTip.new(scope: Scope, props: Props): Instance
	local text = scope:Computed(function(use): string
		return use(props.Text)
	end)
	local title = scope:Computed(function(use): string
		return if props.Title then use(props.Title) else ""
	end)
	local hovered = scope:Value(false)
	local isOpen = scope:Value(false)
	local size = props.Size or DEFAULT_SIZE
	local drawn = scope:Computed(function(use): number
		return if use(Device.Touch) then size + TOUCH_EXTRA else size
	end)
	local roles = Theme.surface(props.Surface)
	local iron = props.Surface == "iron"
	-- iron: a gold circle with a dark letter (as the item tooltip's "i"); paper: a brown circle with a parchment letter
	local base = if iron then Theme.Brass.Bright else roles.Border
	local letter = if iron then Theme.Iron.Surface else roles.Surface

	local hit: GuiObject
	hit = scope:New("TextButton")({
		Name = "Hit",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = scope:Computed(function(use): UDim2
			local d = use(drawn)
			local side = if use(Device.Touch) then math.max(Theme.Size.MinTouch, d) else d + PC_HIT_EXTRA
			return UDim2.fromOffset(side, side)
		end),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = (props.ZIndex or 1) + 1,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
			if UserInputService.MouseEnabled and not Fusion.peek(Device.Touch) and not (pinned and owner == hit) then
				open(hit, Fusion.peek(text), Fusion.peek(title), false)
			end
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
			if owner == hit and not pinned then
				close()
			end
		end,
		[OnEvent("Activated")] = function()
			if owner == hit and pinned then
				close()
			else
				open(hit, Fusion.peek(text), Fusion.peek(title), true)
			end
		end,
	}) :: any

	-- The open state of this "i" (drawn darker while its popover is open).
	local function sync()
		isOpen:set(owner == hit)
	end
	scope:Observer(shownText):onChange(sync)
	-- A text / title state that changes while the popover is open updates it.
	scope:Observer(text):onChange(function()
		if owner == hit then
			shownText:set(Fusion.peek(text))
		end
	end)
	scope:Observer(title):onChange(function()
		if owner == hit then
			local value = Fusion.peek(title)
			shownTitle:set(if value ~= "" then value else nil)
		end
	end)
	table.insert(scope, function()
		if owner == hit then
			close()
		end
	end)

	return scope:New("Frame")({
		Name = props.Name or "InfoTip",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Size = scope:Computed(function(use): UDim2
			local d = use(drawn)
			return UDim2.fromOffset(d, d)
		end),
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(isOpen) then
				return Theme.mix(base, Theme.Shade, 0.3)
			elseif use(hovered) then
				return Theme.mix(base, Theme.Shade, 0.15)
			end
			return base
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
			scope:New("TextLabel")({
				Name = "Letter",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "i",
				FontFace = Theme.Fonts.Display,
				TextSize = scope:Computed(function(use): number
					return if use(Device.Touch) then Theme.TextSize.Body else Theme.TextSize.Small
				end),
				TextColor3 = letter,
				ZIndex = props.ZIndex,
			}),
			hit,
		},
	})
end

-- Builds the popover inside `parent` (the Tooltip layer root, UIController) and closes it on a tap / click outside.
function InfoTip.mount(scope: Scope, parent: Instance)
	layerRoot = if parent:IsA("GuiObject") then parent else nil
	local boxSize = scope:Value(Vector2.zero)
	local box = scope:New("TextLabel")({
		Name = "InfoTip",
		Parent = parent,
		ZIndex = Z,
		Visible = scope:Computed(function(use): boolean
			return use(shownText) ~= nil
		end),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = scope:Computed(function(use): UDim2
			local at: Vector2 = use(anchorAt)
			local size: Vector2 = use(anchorSize)
			local screen: Vector2 = use(Scale.VirtualSize)
			local own = use(boxSize) / use(Scale.Value)
			local x = at.X
			if x + own.X > screen.X - MARGIN then
				x = at.X + size.X - own.X
			end
			local y = at.Y + size.Y + GAP
			if y + own.Y > screen.Y - MARGIN then
				y = at.Y - GAP - own.Y
			end
			return UDim2.fromOffset(
				math.clamp(x, MARGIN, math.max(MARGIN, screen.X - MARGIN - own.X)),
				math.clamp(y, MARGIN, math.max(MARGIN, screen.Y - MARGIN - own.Y))
			)
		end),
		BackgroundColor3 = Theme.Iron.Surface, -- S135: tooltips and popovers on iron
		Text = scope:Computed(function(use): string
			local body = use(shownText) or ""
			local heading = use(shownTitle)
			if heading then
				return `<font color="{Theme.hex(Theme.Iron.Heading)}"><b>{heading}</b></font>\n{body}`
			end
			return body
		end),
		RichText = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Iron.Text,
		[Out("AbsoluteSize")] = boxSize,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Brass.Line,
				Thickness = Theme.Stroke.Thin,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Padding.Small),
				PaddingBottom = UDim.new(0, Theme.Padding.Small),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(MAX_WIDTH, math.huge) }),
		},
	}) :: GuiObject
	panel = box

	-- A tap / click anywhere but the popover and its "i" closes a pinned popover (deferred: a tap on another "i" opens
	-- that one on release).
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			local current = owner
			if not current or not pinned then
				return
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			task.defer(function()
				if owner ~= current then
					return
				end
				local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
				if not playerGui then
					return
				end
				for _, object in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
					if object == current or object == panel or (panel and object:IsDescendantOf(panel)) then
						return
					end
				end
				close()
			end)
		end)
	)
	table.insert(scope, close)
end

return InfoTip
