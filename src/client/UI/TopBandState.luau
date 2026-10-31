--!strict
-- UI plan phase 2: which banner of the top band shows now (Logic/TopBand). Hud/ZoneBanner, Hud/AreaBanner and
-- Hud/AchievementToast set their flag; Components/Toast moves its stack under them and AchievementController waits for
-- the zone and area banners.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local TopBand = require(ReplicatedStorage.Shared.Logic.TopBand)

local TopBandState = {}

local scope = Fusion.scoped(Fusion)

TopBandState.Shown = scope:Value({} :: TopBand.Shown)

-- Banner `id` (TopBand.BANNERS) shows or not.
function TopBandState.set(id: TopBand.Id, shown: boolean)
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
