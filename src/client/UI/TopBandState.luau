--!strict
-- UI plan phase 2: which banner of the top band shows now (Logic/TopBand). Hud/ZoneBanner, Hud/AreaBanner and
-- Hud/AchievementToast set their flag; Components/Toast moves its stack under them and AchievementController waits for
-- the zone and area banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Scale)
local SoftRequire = require(script.Parent.SoftRequire)
-- Studio check 2026-10-31: without the module (not synced yet) the toasts keep their old place
local TopBand = SoftRequire(
	function()
		return require(ReplicatedStorage.Shared.Logic.TopBand)
	end,
	{
		toastTop = function(_shown: any): number
			return 90
		end,
	} :: any,
	"Logic/TopBand"
)

-- Logic/TopBand's types (a soft require carries none)
type Id = "achievement" | "area" | "zone"
type Shown = { [string]: boolean }
type Rect = { left: number, top: number, right: number, bottom: number }

local TopBandState = {}

local scope = Fusion.scoped(Fusion)

TopBandState.Shown = scope:Value({} :: Shown)

-- Banner `id` (TopBand.BANNERS) shows or not.
function TopBandState.set(id: Id, shown: boolean)
	local now = Fusion.peek(TopBandState.Shown)
	if (now[id] == true) == shown then
		return
	end
	local copy = table.clone(now)
	copy[id] = shown
	TopBandState.Shown:set(copy)
end

-- Studio check of UI plan phase 4: a tile that stays near the top while it shows (the tutorial's,
-- Controllers/TutorialController), in screen pixels (as AbsolutePosition), which the toasts' column keeps clear of
-- (Logic/TopBand.toastShift); nil: none.
TopBandState.Keep = scope:Value(nil :: Rect?)

-- Sets the tile the toasts keep clear of (nil: none), only when it changed.
function TopBandState.keep(rect: Rect?)
	local now = Fusion.peek(TopBandState.Keep)
	if rect == nil or now == nil then
		if rect ~= now then
			TopBandState.Keep:set(rect)
		end
		return
	end
	if now.left ~= rect.left or now.top ~= rect.top or now.right ~= rect.right or now.bottom ~= rect.bottom then
		TopBandState.Keep:set(rect)
	end
end

-- The top of the toasts now (Logic/TopBand.toastTop).
TopBandState.ToastTop = scope:Computed(function(use): number
	-- the zone and area banners stand in the HUD's layer, under Roblox's top bar (Studio check of phase 4)
	local k: number = use(Scale.Value)
	local bar: number = use(Scale.TopBar)
	return TopBand.toastTop(use(TopBandState.Shown), if k > 0 then bar / k else 0)
end)

return TopBandState
