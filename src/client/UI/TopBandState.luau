--!strict
-- UI plan phase 2: which banner of the top band shows now (Logic/TopBand). Hud/ZoneBanner, Hud/AreaBanner and
-- Hud/AchievementToast set their flag; Components/Toast moves its stack under them and AchievementController waits for
-- the zone and area banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
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

-- The top of the toasts now (Logic/TopBand.toastTop).
TopBandState.ToastTop = scope:Computed(function(use): number
	return TopBand.toastTop(use(TopBandState.Shown))
end)

return TopBandState
