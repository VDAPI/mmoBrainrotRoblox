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
export type Rect = { left: number, top: number, right: number, bottom: number }

TopBand.GAP = 8
TopBand.TOAST_TOP = 90 -- the toasts' own place under the target frame
TopBand.MAX_TOASTS = 2 -- was 4
TopBand.TOAST_WIDTH = 520 -- Components/Toast
TopBand.TOAST_BAND = 2 * 64 + 8 -- about as tall as MAX_TOASTS toasts of two lines
TopBand.EDGE = 16 -- the toasts never move closer than this to the layer's side

-- Where each banner stands while it shows (its top and bottom edge; the area banner with its profile line, the
-- achievement toast at its PC size, the larger of the two). `hud`: the banner stands in the HUD's layer, which starts
-- under Roblox's top bar (UI/Scale.TopBar); the toasts and the achievement toast stand in the Toasts layer, which
-- covers the whole screen.
TopBand.BANNERS = table.freeze({
	achievement = table.freeze({ top = 64, bottom = 64 + 104 }),
	area = table.freeze({ top = 96, bottom = 96 + 34 + 22, hud = true }),
	zone = table.freeze({ top = 150, bottom = 150 + 110, hud = true }),
})

-- The top of the toasts while the banners in `shown` show: GAP under the lowest of them, never above TOAST_TOP.
-- `bar`: how far (virtual pixels) under the toasts' layer the HUD's layer starts, Roblox's top bar (Studio check of
-- phase 4): the zone and area banners stand that much lower than their own numbers say, the achievement toast at
-- least GAP under it (underBars).
function TopBand.toastTop(shown: Shown, bar: number?): number
	local top = TopBand.TOAST_TOP
	local under = bar or 0
	for id, on in shown do
		local banner = (TopBand.BANNERS :: any)[id]
		if on and banner then
			local push = if banner.hud then under else math.max(0, under + TopBand.GAP - banner.top)
			top = math.max(top, banner.bottom + push + TopBand.GAP)
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

-- Studio check of UI plan phase 4 (1108 x 576: a toast's top stood 3 px into Roblox's top bar; the Toasts layer covers
-- the whole screen and its places are scaled, the bar is not): the top of a message of the Toasts layer at `top`, kept
-- GAP under the top bar (`bar`: how far under the layer's top the HUD's layer starts, screen pixels, UI/Scale.TopBar)
-- and under the title bar of an open window (`header`, as underHeader).
function TopBand.underBars(top: number, bar: number?, header: number?, scale: number): number
	local line = if bar and header then math.max(bar, header) else bar or header
	return TopBand.underHeader(top, line, scale)
end

-- Studio check of UI plan phase 4 (1108 x 576: in the "backpack" step the tutorial's tile, left of the menu over the
-- minimap, stood with its top left corner under the right end of the daily reward's toast): how far (virtual pixels,
-- negative: left) the column of toasts, `width` wide in the middle of a layer `screenW` wide from `top` down
-- (TOAST_BAND), moves so that it keeps GAP clear of `keep`, a tile that stays (in the same layer's pixels): away from
-- the tile's side, never closer than EDGE to the layer's sides; 0 when they do not meet or with no tile. The tile
-- keeps its place: it points at a button, and the toasts go in a few seconds.
function TopBand.toastShift(screenW: number, width: number, top: number, keep: Rect?): number
	if not keep or keep.bottom <= top or keep.top >= top + TopBand.TOAST_BAND then
		return 0
	end
	local left = (screenW - width) / 2
	local right = left + width
	if keep.right + TopBand.GAP <= left or keep.left - TopBand.GAP >= right then
		return 0
	end
	local shift = if keep.left + keep.right >= screenW
		then keep.left - TopBand.GAP - right
		else keep.right + TopBand.GAP - left
	return math.clamp(shift, math.min(0, TopBand.EDGE - left), math.max(0, screenW - TopBand.EDGE - right))
end

-- Whether the achievement toast waits before it slides in: while the zone or the area banner shows.
function TopBand.achievementWaits(shown: Shown): boolean
	return shown.zone == true or shown.area == true
end

return table.freeze(TopBand)
