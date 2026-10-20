--!strict
-- W28: the shared open / close motion of windows, dialogs and popups (Theme.Anim.Window*). Opening: a slightly
-- bouncy spring from Theme.Anim.WindowFrom scale and WindowRise pixels lower; closing (when `closing` turns true):
-- the same path backwards on a short accelerating tween (Theme.Anim.WindowClose), after which the owner removes it.
--   local p = Motion.progress(scope, closing?)   0 = hidden, 1 = in place (may overshoot 1 a little)
--   Motion.scale(scope, p)                       a UIScale child following p
--   Motion.rise(p)                               pixels to add to the Y offset (inside a Computed: rise(use(p)))
--   Motion.popWhen(scope, shown)                 a UIScale child that springs open each time `shown` turns true
--                                                (popups that stay mounted and only toggle Visible)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

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

return Motion
