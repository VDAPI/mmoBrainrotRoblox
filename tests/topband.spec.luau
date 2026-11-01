--!strict
-- UI plan phase 2 (owner 2026-10-31, "too much information and too many options on one screen"): the top band of
-- messages (Logic/TopBand). The toasts start under the lowest banner that shows, two at most, and the achievement
-- toast waits while the zone or area banner shows; the client's banners use these places.
local fs = require("@lune/fs")

local T = require("./Test")
local TopBand = require("../src/shared/Logic/TopBand")

local function overlaps(a: { top: number, bottom: number }, b: { top: number, bottom: number }): boolean
	return a.top < b.bottom and b.top < a.bottom
end

T.describe("Top band of messages (UI plan phase 2)", function()
	T.it("the toasts keep their place with no banner and go under every banner that shows", function()
		T.expect(TopBand.toastTop({})).toBe(TopBand.TOAST_TOP)
		T.expect(TopBand.toastTop({ zone = false, area = false })).toBe(TopBand.TOAST_TOP)
		for id, banner in TopBand.BANNERS do
			local top = TopBand.toastTop({ [id] = true })
			T.expect(top).toBe(banner.bottom + TopBand.GAP)
			-- a toast never stands over the banner
			T.expect(overlaps({ top = top, bottom = top + 60 }, banner)).toBe(false)
		end
		-- several at once: under the lowest
		T.expect(TopBand.toastTop({ area = true, zone = true, achievement = true }))
			.toBe(TopBand.BANNERS.zone.bottom + TopBand.GAP)
	end)

	T.it("two toasts at once", function()
		T.expect(TopBand.MAX_TOASTS).toBe(2)
		local toast = fs.readFile("src/client/UI/Components/Toast.luau")
		T.expect(string.find(toast, "local MAX_VISIBLE = TopBand.MAX_TOASTS", 1, true) ~= nil).toBe(true)
	end)

	T.it("a message over the windows keeps clear of an open window's title bar", function()
		-- no window: its own place
		T.expect(TopBand.underHeader(90, nil, 1)).toBe(90)
		-- a title bar ending 242 screen pixels down at scale 1: GAP under it
		T.expect(TopBand.underHeader(90, 242, 1)).toBe(242 + TopBand.GAP)
		-- at UI scale 0.5 the same 242 screen pixels are 484 virtual ones
		T.expect(TopBand.underHeader(90, 242, 0.5)).toBe(484 + TopBand.GAP)
		-- a title bar higher than the message's own place changes nothing
		T.expect(TopBand.underHeader(300, 100, 1)).toBe(300)
	end)

	T.it("Studio check of phase 4: the toasts stand beside the tutorial's tile, not under it", function()
		-- 1108 x 576 (scale 0.6, the HUD's layer 58 px under the toasts' one): the tile left of the menu over the
		-- minimap, 440 x 134 at 1086, 16 of the HUD, stood under the left part of the toasts' column
		local w = 1108 / 0.6
		local below = 58 / 0.6
		local tile = { left = 1086, top = 16 + below, right = 1086 + 440, bottom = 16 + below + 134 }
		local width = TopBand.TOAST_WIDTH
		local right = (w + width) / 2
		local shift = TopBand.toastShift(w, width, TopBand.TOAST_TOP, tile)
		T.expect(shift < 0).toBe(true)
		T.expect(math.abs(right + shift - (tile.left - TopBand.GAP)) < 1e-6).toBe(true)
		-- no tile, a tile under the band, or one clear of the column: no move
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, nil)).toBe(0)
		local low = { left = 1086, top = 600, right = 1526, bottom = 734 }
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, low)).toBe(0)
		local clear = { left = right + TopBand.GAP, top = tile.top, right = right + 400, bottom = tile.bottom }
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, clear)).toBe(0)
		-- a tile on the left half: the column moves right
		local leftTile = { left = 100, top = tile.top, right = 900, bottom = tile.bottom }
		local moved = TopBand.toastShift(w, width, TopBand.TOAST_TOP, leftTile)
		T.expect(math.abs((w - width) / 2 + moved - (900 + TopBand.GAP)) < 1e-6).toBe(true)
		-- a narrow layer: never closer than EDGE to its side
		T.expect(
			TopBand.toastShift(600, width, TopBand.TOAST_TOP, { left = 300, top = 100, right = 590, bottom = 200 })
		)
			.toBe(TopBand.EDGE - 40)
		-- the toasts use it, the tutorial tells them where its tile stands, and the toast keeps the band's width
		local toast = fs.readFile("src/client/UI/Components/Toast.luau")
		T.expect(string.find(toast, "TopBand.toastShift(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(toast, "local WIDTH = TopBand.TOAST_WIDTH", 1, true) ~= nil).toBe(true)
		local tutorial = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(tutorial, "TopBandState.keep({", 1, true) ~= nil).toBe(true)
		T.expect(string.find(tutorial, "TopBandState.keep(nil)", 1, true) ~= nil).toBe(true)
	end)

	T.it("Studio check of phase 4: the top band's messages stay under Roblox's top bar", function()
		-- 1108 x 576 (scale 0.6): the Toasts layer covers the whole screen, the HUD's layer starts 58 px lower; a
		-- toast at 90 virtual px (54 screen px) stood 3 px into the bar
		local k = 0.6
		T.expect(math.abs(TopBand.underBars(TopBand.TOAST_TOP, 58, nil, k) - (58 / k + TopBand.GAP)) < 1e-6).toBe(true)
		-- at scale 1 the toasts keep their own place; no bar measured yet: their own place
		T.expect(TopBand.underBars(TopBand.TOAST_TOP, 58, nil, 1)).toBe(TopBand.TOAST_TOP)
		T.expect(TopBand.underBars(TopBand.TOAST_TOP, 0, nil, k)).toBe(TopBand.TOAST_TOP)
		-- an open window's title bar lower than the top bar wins, and the other way round
		T.expect(TopBand.underBars(90, 58, 300, 1)).toBe(300 + TopBand.GAP)
		T.expect(TopBand.underBars(90, 120, 30, 1)).toBe(120 + TopBand.GAP)
		-- the zone and area banners stand in the HUD's layer: the toasts go under them by the bar too
		local bar = 58 / k
		local zone = TopBand.BANNERS.zone
		T.expect(math.abs(TopBand.toastTop({ zone = true }, bar) - (zone.bottom + bar + TopBand.GAP)) < 1e-6).toBe(true)
		local area = TopBand.BANNERS.area
		T.expect(math.abs(TopBand.toastTop({ area = true }, bar) - (area.bottom + bar + TopBand.GAP)) < 1e-6).toBe(true)
		-- the achievement toast stands in the toasts' own layer, pushed GAP under the bar at this scale (underBars)
		local achievement = TopBand.BANNERS.achievement
		local pushed = TopBand.underBars(achievement.top, 58, nil, k)
		T.expect(math.abs(TopBand.toastTop({ achievement = true }, bar) - (pushed + 104 + TopBand.GAP)) < 1e-6)
			.toBe(true)
		-- at scale 1 it moves 2 px down (64 under a 58 px bar is 2 px short of GAP)
		T.expect(TopBand.toastTop({ achievement = true }, 58)).toBe(achievement.bottom + 2 + TopBand.GAP)
		T.expect(TopBand.toastTop({}, bar)).toBe(TopBand.TOAST_TOP)
		-- the client: UIController measures the bar, every message of the Toasts layer keeps under it
		local ui = fs.readFile("src/client/Controllers/UIController.luau")
		T.expect(
			string.find(
				ui,
				"Scale.SetTopBar(roots.Screens.AbsolutePosition.Y - roots.Toasts.AbsolutePosition.Y)",
				1,
				true
			) ~= nil
		).toBe(true)
		for _, path in
			{
				"src/client/UI/Components/Toast.luau",
				"src/client/UI/Components/Announcement.luau",
				"src/client/UI/Screens/Hud/AchievementToast.luau",
			}
		do
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "TopBand.underBars(", 1, true) ~= nil }).toEqual({ path, true })
			T.expect({ path, string.find(source, "use(Scale.TopBar)", 1, true) ~= nil }).toEqual({ path, true })
		end
		local state = fs.readFile("src/client/UI/TopBandState.luau")
		T.expect(
			string.find(state, "TopBand.toastTop(use(TopBandState.Shown), if k > 0 then bar / k else 0)", 1, true)
				~= nil
		)
			.toBe(true)
		-- the tutorial's tile hides with its frame (Studio read the tile's own Visible after the closing tile went)
		local hint = fs.readFile("src/client/UI/Screens/Hud/TutorialHint.luau")
		local _, count = string.gsub(hint, "Visible = props%.Visible", "")
		T.expect(count).toBe(2)
	end)

	T.it("the achievement toast waits for the zone and the area banner only", function()
		T.expect(TopBand.achievementWaits({})).toBe(false)
		T.expect(TopBand.achievementWaits({ zone = true })).toBe(true)
		T.expect(TopBand.achievementWaits({ area = true })).toBe(true)
		T.expect(TopBand.achievementWaits({ achievement = true })).toBe(false)
	end)

	T.it("the banners' places match the client's", function()
		local function y(file: string, pattern: string): number
			local source = fs.readFile(file)
			local value = string.match(source, pattern)
			if not value then
				error(`{file}: {pattern} not found`)
			end
			return tonumber(value) :: number
		end
		local hud = "src/client/UI/Screens/Hud/"
		T.expect(y(`{hud}ZoneBanner.luau`, "Position = UDim2%.new%(0%.5, 0, 0, (%d+)%)")).toBe(TopBand.BANNERS.zone.top)
		T.expect(y(`{hud}AreaBanner.luau`, "Position = UDim2%.new%(0%.5, 0, 0, (%d+)%)")).toBe(TopBand.BANNERS.area.top)
		T.expect(y(`{hud}AchievementToast.luau`, "local TOP = (%d+)")).toBe(TopBand.BANNERS.achievement.top)
		T.expect(y(`{hud}ZoneBanner.luau`, "Size = UDim2%.fromOffset%(640, (%d+)%)"))
			.toBe(TopBand.BANNERS.zone.bottom - TopBand.BANNERS.zone.top)
	end)
end)

return nil
