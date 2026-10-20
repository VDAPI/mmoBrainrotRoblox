--!strict
-- W28: the shared open / close motion of windows, dialogs and popups (Theme.Anim.Window*). Opening: a slightly
-- bouncy spring from Theme.Anim.WindowFrom scale and WindowRise pixels lower; closing (when `closing` turns true):
-- the same path backwards on a short accelerating tween (Theme.Anim.WindowClose), after which the owner removes it.
--   local p = Motion.progress(scope, closing?)   0 = hidden, 1 = in place (may overshoot 1 a little)
--   Motion.scale(scope, p)                       a UIScale child following p
--   Motion.rise(p)                               pixels to add to the Y offset (inside a Computed: rise(use(p)))
--   Motion.popWhen(scope, shown)                 a UIScale child that springs open each time `shown` turns true
--                                                (popups that stay mounted and only toggle Visible)
--   Motion.feedback(scope, button, corner?)      a sink while held and, with `corner`, a hover sheen (mouse only),
--                                                for HUD slots and round buttons built without Button / IconButton

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

local SHEEN_HOVER = 0.9 -- transparency of the light veil over a hovered slot
local SHEEN_PRESS = 0.82

local Motion = {}

function Motion.progress(scope: Scope, closing: Fusion.Value<boolean>?): Fusion.Computed<number>
	local opening = scope:Value(0)
	local spring = scope:Spring(opening, Theme.Anim.WindowSpeed, Theme.Anim.WindowDamping)
	-- the target flips after the first frame so the spring has a start to move from
	task.defer(function()
		opening:set(1)
	end)
	if not closing then
		return scope:Computed(function(use): number
			return use(spring)
		end)
	end
	local exit = scope:Tween(
		scope:Computed(function(use): number
			return if use(closing) then 0 else 1
		end),
		Theme.Anim.WindowClose
	)
	return scope:Computed(function(use): number
		return use(spring) * use(exit)
	end)
end

function Motion.scale(scope: Scope, progress: Fusion.UsedAs<number>): Instance
	return scope:New("UIScale")({
		Scale = scope:Computed(function(use): number
			return Theme.Anim.WindowFrom + (1 - Theme.Anim.WindowFrom) * use(progress)
		end),
	})
end

function Motion.rise(progress: number): number
	return (1 - progress) * Theme.Anim.WindowRise
end

function Motion.popWhen(scope: Scope, shown: Fusion.StateObject<boolean>): Instance
	local spring = scope:Spring(1, Theme.Anim.WindowSpeed, Theme.Anim.WindowDamping)
	scope:Observer(shown):onBind(function()
		if Fusion.peek(shown) then
			spring:setPosition(0)
		end
	end)
	return Motion.scale(scope, spring)
end

function Motion.feedback(scope: Scope, button: GuiButton, corner: UDim?)
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	table.insert(
		scope,
		button.MouseEnter:Connect(function()
			hovered:set(true)
		end)
	)
	table.insert(
		scope,
		button.MouseLeave:Connect(function()
			hovered:set(false)
			pressed:set(false)
		end)
	)
	table.insert(
		scope,
		button.InputBegan:Connect(function(input: InputObject)
			if isPress(input) then
				pressed:set(true)
			end
		end)
	)
	table.insert(
		scope,
		button.InputEnded:Connect(function(input: InputObject)
			if isPress(input) then
				pressed:set(false)
			end
		end)
	)
	scope:New("UIScale")({
		Parent = button,
		Scale = scope:Spring(
			scope:Computed(function(use): number
				return if use(pressed) then Theme.Anim.PressScaleIcon else 1
			end),
			Theme.Anim.PressSpeed,
			1
		),
	})
	if not corner then
		return -- round touch buttons: the sink only (a padded caption would push the veil off the circle)
	end
	-- the veil covers the whole button even when its content is padded
	local pad = button:FindFirstChildOfClass("UIPadding")
	local left = if pad then pad.PaddingLeft.Offset else 0
	local top = if pad then pad.PaddingTop.Offset else 0
	local width = if pad then left + pad.PaddingRight.Offset else 0
	local height = if pad then top + pad.PaddingBottom.Offset else 0
	scope:New("Frame")({
		Name = "Sheen",
		Parent = button,
		Position = UDim2.fromOffset(-left, -top),
		Size = UDim2.new(1, width, 1, height),
		BackgroundColor3 = Theme.Plain,
		BackgroundTransparency = scope:Tween(
			scope:Computed(function(use): number
				if use(pressed) then
					return SHEEN_PRESS
				end
				-- touch fires MouseEnter without a matching MouseLeave: no hover veil there
				return if use(hovered) and not use(Device.Touch) then SHEEN_HOVER else 1
			end),
			Theme.Anim.Fast
		),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 20,
		[Fusion.Children] = scope:New("UICorner")({ CornerRadius = corner }),
	})
end

return Motion
