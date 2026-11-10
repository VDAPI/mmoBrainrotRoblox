--!strict
-- Global tooltip: a single parchment label that follows the mouse (PC) or appears above the element on a
-- long press (touch). Tooltip.attach(scope, guiObject, text, details?) wires an element; Tooltip.mount(parent) is
-- called once by UIController.
-- 2026-10-21 (owner: descriptions too long): an optional `details` text. The tooltip shows the short `text` and a small
-- hint ("Alt: details"); holding the details key (Keybinds "item_details", default Alt) shows `details` under it, on
-- touch holding the press longer (DETAILS_PRESS) does. With details both texts are rich text. Recipe: docs/JAK-DODAC.md.
-- Owner 2026-11-10 ("things covering each other"), UI package C: the tooltip stands where Logic/Popover puts it, from
-- its measured size: 18 right of and 22 under the cursor (Popover.TOOLTIP), flipped and kept inside the safe area 8
-- from its edges (the skill and potion bar's tooltips ran off the screen's bottom); on touch above the pressed
-- element, under it when there is no room. Tooltip.SafeArea is that area for the layer's other popovers
-- (ItemTooltip, InfoTip).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.Keybinds)
local Popover = require(ReplicatedStorage.Shared.Logic.Popover)
local Scale = require(script.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TipText = require(ReplicatedStorage.Shared.Logic.TipText)

local Children, Out = Fusion.Children, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>

local Tooltip = {}

local LONG_PRESS = 0.45
local DETAILS_PRESS = 1.2 -- touch: still held this long, the details show
local MAX_WIDTH = 360

local moduleScope = Fusion.scoped(Fusion)
local currentText = moduleScope:Value(nil :: string?)
local currentDetails = moduleScope:Value(nil :: string?)
-- The details key is held (PC) or the press held long (touch).
local expanded = moduleScope:Value(false)
-- What the tooltip stands next to (layer virtual pixels): the cursor (Popover.cursor) or, on touch, the element.
local anchor = moduleScope:Value(Popover.cursor(0, 0, 0))
local onTouch = moduleScope:Value(false)
local owner: GuiObject? = nil
-- Layer root (FIX 2026-10-14): AbsolutePosition is measured below the top bar, the layer from the screen top.
local layerRoot: GuiObject? = nil
local layerSize = moduleScope:Value(nil :: Vector2?) -- the layer root's AbsoluteSize (screen pixels)

-- The safe area of the Tooltip layer for Logic/Popover: the layer root (the device's safe area) less Roblox's top bar,
-- in virtual pixels; the whole screen until the layer is mounted.
Tooltip.SafeArea = moduleScope:Computed(function(use): Popover.Rect
	local scale = use(Scale.Value)
	local real = use(layerSize)
	local size: Vector2 = if real and real.X > 0 and real.Y > 0 then real / scale else use(Scale.VirtualSize)
	return { left = 0, top = use(Scale.TopBar) / scale, right = size.X, bottom = size.Y }
end)

-- An element's rectangle in the Tooltip layer (virtual pixels).
function Tooltip.rectOf(object: GuiObject): Popover.Rect
	local root = layerRoot
	local at = if root then Scale.toLayer(object.AbsolutePosition, root) else Scale.toVirtual(object.AbsolutePosition)
	local size = Scale.toVirtual(object.AbsoluteSize)
	return { left = at.X, top = at.Y, right = at.X + size.X, bottom = at.Y + size.Y }
end

local function show(guiObject: GuiObject, text: string, details: string?, at: Popover.Rect, touch: boolean)
	owner = guiObject
	currentText:set(text)
	currentDetails:set(if details ~= "" then details else nil)
	anchor:set(at)
	onTouch:set(touch)
end

local function cursor(x: number, y: number): Popover.Rect
	local at = Scale.toVirtual(Vector2.new(x, y))
	return Popover.cursor(at.X, at.Y, Popover.TOOLTIP.drop)
end

local function hide(guiObject: GuiObject?)
	if guiObject == nil or owner == guiObject then
		owner = nil
		currentText:set(nil)
		currentDetails:set(nil)
		if Fusion.peek(Device.Touch) then
			expanded:set(false)
		end
	end
end

function Tooltip.hide()
	hide(nil)
end

function Tooltip.attach(
	scope: Fusion.Scope<typeof(Fusion)>,
	guiObject: GuiObject,
	text: UsedAs<string>,
	details: UsedAs<string?>?
)
	local function resolve(): string
		return Fusion.peek(text)
	end
	local function resolveDetails(): string?
		return if details ~= nil then Fusion.peek(details) else nil
	end

	table.insert(
		scope,
		guiObject.MouseEnter:Connect(function(x, y)
			if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
				show(guiObject, resolve(), resolveDetails(), cursor(x, y), false)
			end
		end)
	)
	table.insert(
		scope,
		guiObject.MouseMoved:Connect(function(x, y)
			if owner == guiObject then
				anchor:set(cursor(x, y))
			end
		end)
	)
	table.insert(
		scope,
		guiObject.MouseLeave:Connect(function()
			hide(guiObject)
		end)
	)

	-- Touch: long press shows above the element (under it without room above); releasing hides.
	local pressToken = 0
	table.insert(
		scope,
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			pressToken += 1
			local token = pressToken
			expanded:set(false)
			task.delay(LONG_PRESS, function()
				if token == pressToken and guiObject.Parent then
					show(guiObject, resolve(), resolveDetails(), Tooltip.rectOf(guiObject), true)
				end
			end)
			task.delay(DETAILS_PRESS, function()
				if token == pressToken and owner == guiObject then
					expanded:set(true)
				end
			end)
		end)
	)
	table.insert(
		scope,
		guiObject.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				pressToken += 1
				hide(guiObject)
			end
		end)
	)
	table.insert(scope, function()
		hide(guiObject)
	end)
end

-- Builds the floating tooltip inside `parent` (a scaled layer Root, see UI/Scale).
function Tooltip.mount(scope: Fusion.Scope<typeof(Fusion)>, parent: Instance)
	layerRoot = if parent:IsA("GuiObject") then parent else nil
	local root = layerRoot
	if root then
		local function report()
			layerSize:set(root.AbsoluteSize)
		end
		report()
		table.insert(scope, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(report))
	end
	local tipSize = scope:Value(Vector2.zero)
	local detailsKey = Keybinds.Label(scope, "item_details")
	-- PC: the details show while the details key is held.
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Keyboard
				and Keybinds.is(input.KeyCode, "item_details")
				and UserInputService:GetFocusedTextBox() == nil
			then
				expanded:set(true)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Keyboard and Keybinds.is(input.KeyCode, "item_details") then
				expanded:set(false)
			end
		end)
	)
	scope:New("TextLabel")({
		Name = "Tooltip",
		Parent = parent,
		Visible = scope:Computed(function(use): boolean
			return use(currentText) ~= nil
		end),
		-- Logic/Popover from the measured size: right of the cursor (left of it at the right edge, rising at the bottom),
		-- on touch above the element
		Position = scope:Computed(function(use): UDim2
			local own = use(tipSize) / use(Scale.Value)
			local options: Popover.Options = if use(onTouch)
				then { prefer = "above" :: Popover.Side }
				else { prefer = "right" :: Popover.Side, gap = Popover.TOOLTIP.gap }
			local rect = Popover.place(use(anchor), { w = own.X, h = own.Y }, use(Tooltip.SafeArea), options)
			return UDim2.fromOffset(rect.left, rect.top)
		end),
		[Out("AbsoluteSize")] = tipSize,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Iron.Surface, -- S135: tooltips on iron
		Text = scope:Computed(function(use): string
			local hint = if use(Device.Touch)
				then Text.get(use, "tooltip.more.touch")
				else Text.get(use, "tooltip.more.mouse", { key = use(detailsKey) })
			return TipText.compose(
				use(currentText) or "",
				use(currentDetails),
				use(expanded),
				`<font color="{Theme.hex(Theme.Iron.TextMuted)}">{hint}</font>`
			)
		end),
		-- plain text unless details came with it (callers without details may use "<" freely)
		RichText = scope:Computed(function(use): boolean
			return use(currentDetails) ~= nil
		end),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Iron.Text,
		TextWrapped = true,
		ZIndex = 100,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(MAX_WIDTH, math.huge) }),
		},
	})
end

return Tooltip
