--!strict
-- Global tooltip: a single parchment label that follows the mouse (PC) or appears above the element on a
-- long press (touch). Tooltip.attach(scope, guiObject, text, details?) wires an element; Tooltip.mount(parent) is
-- called once by UIController.
-- 2026-10-21 (owner: descriptions too long): an optional `details` text. The tooltip shows the short `text` and a small
-- hint ("Alt: details"); holding the details key (Keybinds "item_details", default Alt) shows `details` under it, on
-- touch holding the press longer (DETAILS_PRESS) does. With details both texts are rich text. Recipe: docs/JAK-DODAC.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.Keybinds)
local Scale = require(script.Parent.Parent.Scale)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TipText = require(ReplicatedStorage.Shared.Logic.TipText)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

local Tooltip = {}

local LONG_PRESS = 0.45
local DETAILS_PRESS = 1.2 -- touch: still held this long, the details show
local OFFSET = Vector2.new(18, 22)

local moduleScope = Fusion.scoped(Fusion)
local currentText = moduleScope:Value(nil :: string?)
local currentDetails = moduleScope:Value(nil :: string?)
-- The details key is held (PC) or the press held long (touch).
local expanded = moduleScope:Value(false)
local position = moduleScope:Value(Vector2.zero)
local owner: GuiObject? = nil
-- Layer root (FIX 2026-10-14): AbsolutePosition is measured below the top bar, the layer from the screen top.
local layerRoot: GuiObject? = nil

local function show(guiObject: GuiObject, text: string, details: string?, at: Vector2)
	owner = guiObject
	currentText:set(text)
	currentDetails:set(if details ~= "" then details else nil)
	position:set(at)
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
				show(guiObject, resolve(), resolveDetails(), Scale.toVirtual(Vector2.new(x, y)))
			end
		end)
	)
	table.insert(
		scope,
		guiObject.MouseMoved:Connect(function(x, y)
			if owner == guiObject then
				position:set(Scale.toVirtual(Vector2.new(x, y)))
			end
		end)
	)
	table.insert(
		scope,
		guiObject.MouseLeave:Connect(function()
			hide(guiObject)
		end)
	)

	-- Touch: long press shows above the element; releasing hides.
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
					local p = guiObject.AbsolutePosition
					local root = layerRoot
					local at = if root then Scale.toLayer(p, root) else Scale.toVirtual(p)
					show(guiObject, resolve(), resolveDetails(), at - Vector2.new(0, 60))
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
		Position = scope:Computed(function(use): UDim2
			local p: Vector2 = use(position)
			return UDim2.fromOffset(p.X + OFFSET.X, p.Y + OFFSET.Y)
		end),
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
			scope:New("UISizeConstraint")({ MaxSize = Vector2.new(360, math.huge) }),
		},
	})
end

return Tooltip
