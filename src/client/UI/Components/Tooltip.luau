--!strict
-- Global tooltip: a single parchment label that follows the mouse (PC) or appears above the element on a
-- long press (touch). Tooltip.attach(scope, guiObject, text) wires an element; Tooltip.mount(parent) is
-- called once by UIController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

local Tooltip = {}

local LONG_PRESS = 0.45
local OFFSET = Vector2.new(18, 22)

local moduleScope = Fusion.scoped(Fusion)
local currentText = moduleScope:Value(nil :: string?)
local position = moduleScope:Value(Vector2.zero)
local owner: GuiObject? = nil

local function show(guiObject: GuiObject, text: string, at: Vector2)
	owner = guiObject
	currentText:set(text)
	position:set(at)
end

local function hide(guiObject: GuiObject?)
	if guiObject == nil or owner == guiObject then
		owner = nil
		currentText:set(nil)
	end
end

function Tooltip.hide()
	hide(nil)
end

function Tooltip.attach(scope: Fusion.Scope<typeof(Fusion)>, guiObject: GuiObject, text: UsedAs<string>)
	local function resolve(): string
		return Fusion.peek(text)
	end

	table.insert(
		scope,
		guiObject.MouseEnter:Connect(function(x, y)
			if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
				show(guiObject, resolve(), Scale.toVirtual(Vector2.new(x, y)))
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
			task.delay(LONG_PRESS, function()
				if token == pressToken and guiObject.Parent then
					local p = guiObject.AbsolutePosition
					show(guiObject, resolve(), Scale.toVirtual(Vector2.new(p.X, p.Y)) - Vector2.new(0, 60))
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
		BackgroundColor3 = Theme.Colors.Parchment,
		Text = scope:Computed(function(use): string
			return use(currentText) or ""
		end),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.TextDark,
		TextWrapped = true,
		ZIndex = 100,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1 }),
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
