--!strict
-- UI plan phase 2 (owner 2026-10-31: "too much information and too many options on one screen"; plan §3, one queue
-- of messages): the band at the top centre of the screen shows its messages one under another instead of on top of
-- each other. The banners keep their places (Hud/AchievementToast slides in at 64, Hud/AreaBanner at 96, Hud/ZoneBanner
-- at 150); the toasts (Components/Toast) start under the lowest banner that shows, at most MAX_TOASTS at once, and the
-- achievement toast waits while the zone or area banner shows (it would cover them). Pure: the client tells it which
-- banner shows (UI/TopBandState). All numbers are virtual pixels of UI/Scale from the top of the screen.

local TopBand = {}

export type Id = "achievement" | "area" | "zone"
export type Shown = { [string]: boolean }

TopBand.GAP = 8
TopBand.TOAST_TOP = 90 -- the toasts' own place under the target frame
TopBand.MAX_TOASTS = 2 -- was 4

-- Where each banner stands while it shows (its top and bottom edge; the area banner with its profile line, the
-- achievement toast at its PC size, the larger of the two).
TopBand.BANNERS = table.freeze({
	achievement = table.freeze({ top = 64, bottom = 64 + 104 }),
	area = table.freeze({ top = 96, bottom = 96 + 34 + 22 }),
	zone = table.freeze({ top = 150, bottom = 150 + 110 }),
})

-- The top of the toasts while the banners in `shown` show: GAP under the lowest of them, never above TOAST_TOP.
function TopBand.toastTop(shown: Shown): number
	local top = TopBand.TOAST_TOP
	for id, on in shown do
		local banner = (TopBand.BANNERS :: any)[id]
		if on and banner then
			top = math.max(top, banner.bottom + TopBand.GAP)
		end
	end
	return top
end

-- Studio 2026-10-31 (the world boss's announcement sat on an open window's title bar): the top of a message of the
-- Toasts layer (over the windows) that keeps clear of the open windows' headers: `header` = how far under the layer's
-- top the lowest header ends, in screen pixels, at UI scale `scale` (nil with no window open); `top` its own place.
function TopBand.underHeader(top: number, header: number?, scale: number): number
	if header == nil or scale <= 0 then
		return top
	end
	return math.max(top, header / scale + TopBand.GAP)
end

-- Whether the achievement toast waits before it slides in: while the zone or the area banner shows.
function TopBand.achievementWaits(shown: Shown): boolean
	return shown.zone == true or shown.area == true
end

return table.freeze(TopBand)
