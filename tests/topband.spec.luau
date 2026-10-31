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
