--!strict
-- UI plan phase 2 (owner 2026-10-31, "too much information and too many options on one screen"): the top band of
-- messages (Logic/TopBand). The toasts start under the lowest banner that shows, two at most, and the achievement
-- toast waits while the zone or area banner shows.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the band stands GAP
-- under the target band (Logic/HudZones.messageZone, owner question 2) and one queue (Logic/NoticeQueue) decides what
-- shows, so the old guarantees hold through the queue and TopBand.slots: every toast under the banner that shows, at
-- most two toasts, the achievement waiting for the zone and area banners, nothing moving up while it shows. The
-- dungeon boss bar stands in the target band (a phone: a strip across M's width under the target row). A source check
-- keeps every message in UI/Notify's host: nothing outside package B's files parents into the Toasts layer or makes a
-- ScreenGui for one.
local fs = require("@lune/fs")

local HudZones = require("../src/shared/Logic/HudZones")
local NoticeQueue = require("../src/shared/Logic/NoticeQueue")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")
local TextScan = require("./TextScan")
local TopBand = require("../src/shared/Logic/TopBand")

type Entry = NoticeQueue.Entry
type Rect = TopBand.Rect

local EPS = 1e-6

local function overlaps(a: { top: number, bottom: number }, b: { top: number, bottom: number }): boolean
	return a.top < b.bottom and b.top < a.bottom
end

local function shownIds(shown: { Entry }): { [number]: boolean }
	local out = {}
	for _, e in shown do
		out[e.id] = true
	end
	return out
end

local function banner(q: NoticeQueue.Queue, now: number, tone: string, extra: { [string]: any }?): Entry
	local spec: NoticeQueue.Spec = { class = "banner", text = tone, tone = tone }
	for k, v in extra or {} do
		(spec :: any)[k] = v
	end
	return NoticeQueue.push(q, now, spec) :: Entry
end

-- The plan's PC and tablet layers (whole screen, virtual pixels) and its phones, each with Roblox's bar of 0 and 58.
type Screen = { name: string, device: TopBand.Device, w: number, h: number, bar: number, hudW: number, hudH: number }
local function screens(): { Screen }
	local out: { Screen } = {}
	for _, set in
		{
			{ device = "pc", sizes = { { 1920, 1080 }, { 1366, 768 }, { 1280, 720 }, { 2560, 1080 } } },
			{ device = "tablet", sizes = { { 1280, 800 }, { 1024, 768 } } },
		}
	do
		for _, size in set.sizes do
			for _, bar in { 0, 58 } do
				local lw, lh, k = HudZones.layer(size[1], size[2], set.device == "tablet", bar)
				table.insert(out, {
					name = `{set.device} {size[1]}x{size[2]} bar {bar}`,
					device = set.device :: TopBand.Device,
					w = size[1] / k,
					h = size[2] / k,
					bar = size[2] / k - lh,
					hudW = lw,
					hudH = lh,
				})
			end
		end
	end
	for _, device in PhoneHud.DEVICES do
		for _, bar in { 0, 58 } do
			local w, h = PhoneHud.area(device)
			local b = bar / PhoneHud.SCALE
			table.insert(out, {
				name = `phone {device.name} bar {bar}`,
				device = "phone",
				w = w,
				h = h,
				bar = b,
				hudW = w,
				hudH = h - b,
			})
		end
	end
	return out
end

local function fail(problems: { string })
	if #problems > 0 then
		error(table.concat(problems, "\n"))
	end
end

T.describe("Top band of messages (UI plan phase 2, package B)", function()
	T.it("the toasts keep their place with no banner and go under every banner that shows", function()
		T.expect(TopBand.toastTop({})).toBe(TopBand.TOAST_TOP)
		T.expect(TopBand.toastTop({ zone = false, area = false })).toBe(TopBand.TOAST_TOP)
		for id, b in TopBand.BANNERS do
			local top = TopBand.toastTop({ [id] = true })
			T.expect(top).toBe(b.bottom + TopBand.GAP)
			-- a toast never stands over the banner
			T.expect(overlaps({ top = top, bottom = top + 60 }, b)).toBe(false)
		end
		-- several at once: under the lowest
		T.expect(TopBand.toastTop({ area = true, zone = true, achievement = true }))
			.toBe(TopBand.BANNERS.zone.bottom + TopBand.GAP)
	end)

	T.it("package B: every toast stands under the banner that shows, on every screen", function()
		local problems: { string } = {}
		local checked = 0
		for _, s in screens() do
			if s.device ~= "phone" then
				for _, size in { TopBand.BANNER, TopBand.BANNER_BIG } do
					local placed = TopBand.slots({
						w = s.w,
						h = s.h,
						bar = s.bar,
						device = s.device,
						items = {
							{ id = "banner", w = size.w, h = size.h },
							{ id = "toast1", w = TopBand.TOAST_WIDTH, h = 52 },
							{ id = "toast2", w = TopBand.TOAST_WIDTH, h = 76 },
						},
					})
					local b = placed.rects.banner
					if b == nil then
						table.insert(problems, `{s.name}: no place for the banner`)
					else
						for _, id in { "toast1", "toast2" } do
							local r = placed.rects[id]
							if r then
								checked += 1
								if r.top < b.bottom + TopBand.GAP - EPS then
									table.insert(
										problems,
										`{s.name}: {id} at {r.top} over the banner ending {b.bottom}`
									)
								end
							end
						end
					end
				end
			end
		end
		fail(problems)
		T.expect(checked > 10).toBe(true)
		-- PC: the banner and two toasts show at once, each in its own place; a phone's one line: the toast waits
		local pc = NoticeQueue.new("pc", 0)
		banner(pc, 0, "legendary")
		NoticeQueue.push(pc, 0, { class = "toast", text = "a" })
		NoticeQueue.push(pc, 0, { class = "toast", text = "b" })
		T.expect(#NoticeQueue.update(pc, 0.1)).toBe(3)
		local phone = NoticeQueue.new("phone", 0)
		local onPhone = banner(phone, 0, "legendary")
		local toast = NoticeQueue.push(phone, 0, { class = "toast", text = "a" }) :: Entry
		local shown = shownIds(NoticeQueue.update(phone, 0.1))
		T.expect(shown[onPhone.id] == true and shown[toast.id] == nil).toBe(true)
		T.expect(shownIds(NoticeQueue.update(phone, NoticeQueue.SECONDS.banner + 0.2))[toast.id]).toBe(true)
	end)

	T.it("two toasts at once", function()
		T.expect(TopBand.MAX_TOASTS).toBe(2)
		T.expect(NoticeQueue.CAPACITY.pc.toast).toBe(TopBand.MAX_TOASTS)
		T.expect(NoticeQueue.CAPACITY.tablet.toast).toBe(TopBand.MAX_TOASTS)
		local q = NoticeQueue.new("pc", 0)
		local list: { Entry } = {}
		for i = 1, 5 do
			table.insert(list, NoticeQueue.push(q, i * 0.01, { class = "toast", text = `toast {i}` }) :: Entry)
		end
		local shown = NoticeQueue.update(q, 0.1)
		T.expect(#shown).toBe(2)
		-- the oldest two first; the third comes when the first goes
		local first = shownIds(shown)
		T.expect(first[list[1].id] and first[list[2].id]).toBe(true)
		local later = shownIds(NoticeQueue.update(q, 0.1 + NoticeQueue.SECONDS.toast + 0.05))
		T.expect(later[list[3].id]).toBe(true)
		T.expect(later[list[1].id]).toBeNil()
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
		T.expect(math.abs(right + shift - (tile.left - TopBand.GAP)) < EPS).toBe(true)
		-- no tile, a tile under the band, or one clear of the column: no move
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, nil)).toBe(0)
		local low = { left = 1086, top = 600, right = 1526, bottom = 734 }
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, low)).toBe(0)
		local clear = { left = right + TopBand.GAP, top = tile.top, right = right + 400, bottom = tile.bottom }
		T.expect(TopBand.toastShift(w, width, TopBand.TOAST_TOP, clear)).toBe(0)
		-- a tile on the left half: the column moves right
		local leftTile = { left = 100, top = tile.top, right = 900, bottom = tile.bottom }
		local moved = TopBand.toastShift(w, width, TopBand.TOAST_TOP, leftTile)
		T.expect(math.abs((w - width) / 2 + moved - (900 + TopBand.GAP)) < EPS).toBe(true)
		-- a narrow layer: never closer than EDGE to its side
		T.expect(
			TopBand.toastShift(600, width, TopBand.TOAST_TOP, { left = 300, top = 100, right = 590, bottom = 200 })
		)
			.toBe(TopBand.EDGE - 40)
		-- package B: the band's toast moves beside a tile at the zone's end where it fits in the zone, else under it
		local sw, sh = 1920, 1080
		local zone = TopBand.zone({ w = sw, h = sh, bar = 0, device = "pc", items = {} })
		local item = { { id = "toast1", w = width, h = 52 } }
		local atEnd = { left = zone.right - 250, top = zone.top - 20, right = zone.right + 50, bottom = zone.top + 100 }
		local placed = TopBand.slots({ w = sw, h = sh, bar = 0, device = "pc", keep = atEnd, items = item })
		local r = placed.rects.toast1
		T.expect(TopBand.meets(r, atEnd)).toBe(false)
		if zone.right - zone.left >= width + 250 + TopBand.GAP then
			T.expect(r.top).toBe(zone.top) -- beside, in the band's own row
			T.expect(r.right <= atEnd.left - TopBand.GAP + EPS and r.left >= zone.left - EPS).toBe(true)
		else
			T.expect(r.top).toBe(atEnd.bottom + TopBand.GAP)
		end
		local cx = (zone.left + zone.right) / 2
		local middle = { left = cx - 200, top = zone.top - 20, right = cx + 200, bottom = zone.top + 100 }
		local under = TopBand.slots({ w = sw, h = sh, bar = 0, device = "pc", keep = middle, items = item })
		T.expect(under.rects.toast1.top).toBe(middle.bottom + TopBand.GAP)
		-- the client: the tutorial tells UI/Notify where its tile stands, Notify hands it to TopBand.slots
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "Fusion.peek(TopBandState.Keep)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(notify, "keep = if keep then toLayer(keep, at, k) else nil", 1, true) ~= nil).toBe(true)
		local tutorial = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(tutorial, "TopBandState.keep({", 1, true) ~= nil).toBe(true)
		T.expect(string.find(tutorial, "TopBandState.keep(nil)", 1, true) ~= nil).toBe(true)
	end)

	T.it("Studio check of phase 4: the top band's messages stay under Roblox's top bar", function()
		-- 1108 x 576 (scale 0.6): the Toasts layer covers the whole screen, the HUD's layer starts 58 px lower; a
		-- toast at 90 virtual px (54 screen px) stood 3 px into the bar
		local k = 0.6
		T.expect(math.abs(TopBand.underBars(TopBand.TOAST_TOP, 58, nil, k) - (58 / k + TopBand.GAP)) < EPS).toBe(true)
		-- at scale 1 the toasts keep their own place; no bar measured yet: their own place
		T.expect(TopBand.underBars(TopBand.TOAST_TOP, 58, nil, 1)).toBe(TopBand.TOAST_TOP)
		T.expect(TopBand.underBars(TopBand.TOAST_TOP, 0, nil, k)).toBe(TopBand.TOAST_TOP)
		-- an open window's title bar lower than the top bar wins, and the other way round
		T.expect(TopBand.underBars(90, 58, 300, 1)).toBe(300 + TopBand.GAP)
		T.expect(TopBand.underBars(90, 120, 30, 1)).toBe(120 + TopBand.GAP)
		-- the zone and area banners stood in the HUD's layer: the toasts went under them by the bar too
		local bar = 58 / k
		local zoneBanner = TopBand.BANNERS.zone
		T.expect(math.abs(TopBand.toastTop({ zone = true }, bar) - (zoneBanner.bottom + bar + TopBand.GAP)) < EPS)
			.toBe(true)
		local achievement = TopBand.BANNERS.achievement
		local pushed = TopBand.underBars(achievement.top, 58, nil, k)
		T.expect(math.abs(TopBand.toastTop({ achievement = true }, bar) - (pushed + 104 + TopBand.GAP)) < EPS)
			.toBe(true)
		T.expect(TopBand.toastTop({}, bar)).toBe(TopBand.TOAST_TOP)
		-- package B: on every screen, with every bar, the band and everything placed in it stand GAP under the bar
		local problems: { string } = {}
		for _, s in screens() do
			for _, hud in { {} :: HudZones.State, { bossBar = true }, { target = "player", arena = "match" } } do
				local placed = TopBand.slots({
					w = s.w,
					h = s.h,
					bar = s.bar,
					device = s.device,
					hud = hud,
					items = { { id = "toast", w = TopBand.TOAST_WIDTH, h = 52 } },
					card = if s.device == "pc" then "fight" else nil,
				})
				if placed.zone.top < s.bar + TopBand.GAP - EPS then
					table.insert(problems, `{s.name}: the zone at {placed.zone.top} under a bar of {s.bar}`)
				end
				for id, r in placed.rects do
					if r.top < s.bar + TopBand.GAP - EPS then
						table.insert(problems, `{s.name}: {id} at {r.top} under a bar of {s.bar}`)
					end
				end
			end
		end
		fail(problems)
		-- the client: UIController measures the bar, UI/Notify hands it to TopBand.context (virtual pixels there)
		local ui = fs.readFile("src/client/Controllers/UIController.luau")
		T.expect(
			string.find(
				ui,
				"Scale.SetTopBar(roots.Screens.AbsolutePosition.Y - roots.Toasts.AbsolutePosition.Y)",
				1,
				true
			) ~= nil
		).toBe(true)
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "topBar = Fusion.peek(Scale.TopBar),", 1, true) ~= nil).toBe(true)
		T.expect(string.find(notify, "local ctx = TopBand.context({", 1, true) ~= nil).toBe(true)
		-- the tutorial's tile hides with its frame (Studio read the tile's own Visible after the closing tile went)
		local hint = fs.readFile("src/client/UI/Screens/Hud/TutorialHint.luau")
		local _, count = string.gsub(hint, "Visible = props%.Visible", "")
		T.expect(count).toBe(2)
	end)

	T.it("Studio check of phase 4, third round: the band's messages wait for each other and hold still", function()
		-- the achievement toast and the server's announcement stood at the same height: each waits for the other
		T.expect(TopBand.achievementWaits({ announcement = true })).toBe(true)
		T.expect(TopBand.announcementWaits({ achievement = true })).toBe(true)
		T.expect(TopBand.announcementWaits({ zone = true, area = true })).toBe(false)
		T.expect(TopBand.announcementWaits({})).toBe(false)
		T.expect(TopBand.toastTop({ announcement = true })).toBe(TopBand.BANNERS.announcement.bottom + TopBand.GAP)
		-- a toast keeps its height until it leaves: down at once, never up while toasts show
		T.expect(TopBand.holdTop(90, 268, true)).toBe(268)
		T.expect(TopBand.holdTop(268, 90, true)).toBe(268)
		T.expect(TopBand.holdTop(90, 268, false)).toBe(90)
		T.expect(TopBand.holdTop(90, nil, true)).toBe(90)
		-- package B: one banner place, the first to show keeps it (the announcement and the achievement, both ways)
		for _, order in { { "legendary", "achievement" }, { "achievement", "legendary" } } do
			local q = NoticeQueue.new("pc", 0)
			local a = banner(q, 0, order[1])
			NoticeQueue.update(q, 0)
			local b = banner(q, 0.5, order[2])
			local shown = shownIds(NoticeQueue.update(q, 1))
			T.expect({ order[1], shown[a.id] == true, shown[b.id] == nil }).toEqual({ order[1], true, true })
			local after = shownIds(NoticeQueue.update(q, (a.seconds :: number) + 0.1))
			T.expect({ order[2], after[b.id] == true }).toEqual({ order[2], true })
		end
		-- the band's toasts keep their tops while they show when the banner over them goes; free again, they rise
		local sw, sh = 1920, 1080
		local list = {
			{ id = "banner", w = TopBand.BANNER.w, h = TopBand.BANNER.h },
			{ id = "toast1", w = TopBand.TOAST_WIDTH, h = 52 },
			{ id = "toast2", w = TopBand.TOAST_WIDTH, h = 52 },
		}
		local before = TopBand.slots({ w = sw, h = sh, bar = 0, device = "pc", items = list })
		local held = { toast1 = before.rects.toast1.top, toast2 = before.rects.toast2.top }
		local rest = { list[2], list[3] }
		local after = TopBand.slots({ w = sw, h = sh, bar = 0, device = "pc", items = rest, held = held })
		T.expect(after.rects.toast1.top).toBe(held.toast1)
		T.expect(after.rects.toast2.top).toBe(held.toast2)
		T.expect(TopBand.slots({ w = sw, h = sh, bar = 0, device = "pc", items = rest }).rects.toast1.top < held.toast1)
			.toBe(true)
		-- what shows keeps showing: combat or a window that opens never takes a message off the screen
		local q = NoticeQueue.new("pc", 0)
		local info = NoticeQueue.push(q, 0, { class = "toast", text = "Zapisano." }) :: Entry
		local ach = banner(q, 0, "achievement", { windowWaits = true })
		NoticeQueue.update(q, 0.1)
		local still = shownIds(NoticeQueue.update(q, 0.2, { combat = true, window = true }))
		T.expect(still[info.id] == true and still[ach.id] == true).toBe(true)
		-- the client hands the shown tops back to TopBand.slots
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "ctx.held = held", 1, true) ~= nil).toBe(true)
		T.expect(string.find(notify, "held[tostring(e.id)] = r.top", 1, true) ~= nil).toBe(true)
		-- the tutorial's tile at its default place (the closing one) ends GAP over the cast bar, right over the bar
		local cast = fs.readFile("src/client/UI/Screens/Hud/CastBar.luau")
		T.expect(string.find(cast, "UDim2.new(0.5, 0, 1, -100)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(cast, "UDim2.fromOffset(360, 26)", 1, true) ~= nil).toBe(true)
		local tutorial = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(tutorial, "local OVER_BAR = 100 + 26 + GAP", 1, true) ~= nil).toBe(true)
		T.expect(string.find(tutorial, "h - OVER_BAR - tall", 1, true) ~= nil).toBe(true)
	end)

	T.it("the achievement toast waits for the zone and the area banner only", function()
		T.expect(TopBand.achievementWaits({})).toBe(false)
		T.expect(TopBand.achievementWaits({ zone = true })).toBe(true)
		T.expect(TopBand.achievementWaits({ area = true })).toBe(true)
		T.expect(TopBand.achievementWaits({ achievement = true })).toBe(false)
		-- package B: in the queue the zone and area banners show at once and the achievement waits for them, also
		-- when it came first (it comes back for the time it had left)
		for _, tone in { "zone", "area" } do
			local q = NoticeQueue.new("pc", 0)
			local first = banner(q, 0, tone)
			local ach = banner(q, 0.2, "achievement")
			local shown = shownIds(NoticeQueue.update(q, 0.5))
			T.expect({ tone, shown[first.id] == true, shown[ach.id] == nil }).toEqual({ tone, true, true })
			local seconds = first.seconds :: number
			T.expect({ tone, shownIds(NoticeQueue.update(q, 0.5 + seconds + 0.1))[ach.id] == true })
				.toEqual({ tone, true })
			-- the achievement shows; the banner comes: it takes the place, the achievement waits and comes back
			local q2 = NoticeQueue.new("pc", 0)
			local ach2 = banner(q2, 0, "achievement")
			NoticeQueue.update(q2, 0)
			NoticeQueue.update(q2, 1)
			local later = banner(q2, 1, tone)
			local now = shownIds(NoticeQueue.update(q2, 1.1))
			T.expect({ tone, now[later.id] == true, now[ach2.id] == nil }).toEqual({ tone, true, true })
			local back = shownIds(NoticeQueue.update(q2, 1 + seconds + 0.2))
			T.expect({ tone, back[ach2.id] == true }).toEqual({ tone, true })
			T.expect({ tone, math.abs((ach2.left :: number) - (NoticeQueue.SECONDS.achievement - 1.1)) < 0.25 })
				.toEqual({ tone, true })
		end
	end)

	T.it("package B: the band stands GAP under the target band, in the same place with or without a target", function()
		T.expect(TopBand.GAP).toBe(8)
		local problems: { string } = {}
		for _, size in { { 1920, 1080 }, { 1600, 900 }, { 1366, 768 }, { 2560, 1440 } } do
			local w, h = size[1], size[2]
			local tops: { [number]: boolean } = {}
			local count = 0
			for _, target in { "none", "monster", "player", "elite" } do
				local state: HudZones.State = { target = target :: HudZones.TargetKind }
				local zone = HudZones.messageZone(w, h, state)
				local band = HudZones.targetBand(w, state)
				if zone.top ~= band.bottom + TopBand.GAP then
					table.insert(
						problems,
						`{w}x{h} {target}: messageZone.top {zone.top}, targetBand.bottom {band.bottom}`
					)
				end
				-- TopBand.zone is that zone in the whole screen's pixels (the HUD's layer starts under the bar)
				local mine = TopBand.zone({ w = w, h = h + 36, bar = 36, device = "pc", hud = state, items = {} })
				if math.abs(mine.top - (zone.top + 36)) > EPS or mine.left ~= zone.left or mine.right ~= zone.right then
					table.insert(problems, `{w}x{h} {target}: TopBand.zone is not messageZone under the bar`)
				end
				if not tops[zone.top] then
					tops[zone.top] = true
					count += 1
				end
			end
			if count ~= 1 then
				table.insert(problems, `{w}x{h}: the band moves with the target`)
			end
			-- the dungeon boss bar and the arena panel make the target band longer: the band goes down with it
			for _, state in { { bossBar = true } :: HudZones.State, { target = "player", arena = "match" } } do
				local zone = HudZones.messageZone(w, h, state)
				if zone.top ~= HudZones.targetBand(w, state).bottom + TopBand.GAP then
					table.insert(problems, `{w}x{h}: the zone is not GAP under the longer band`)
				end
			end
		end
		fail(problems)
	end)

	T.it("package B: the dungeon boss bar stands in the target band, on a phone a strip under it", function()
		local problems: { string } = {}
		for _, s in screens() do
			if s.device ~= "phone" then
				local r = TopBand.bossBar(s.device, s.hudW, s.hudH)
				local state: HudZones.State = { bossBar = true, touch = s.device == "tablet" }
				local band = HudZones.targetBand(s.hudW, state)
				local zones = HudZones.pc(s.hudW, s.hudH, state)
				local own = zones.bossBar
				if own == nil then
					table.insert(problems, `{s.name}: HudZones has no boss bar`)
				elseif r.left ~= own.left or r.top ~= own.top or r.right ~= own.right or r.bottom ~= own.bottom then
					table.insert(problems, `{s.name}: the boss bar is not HudZones' place`)
				end
				if r.left < band.left - EPS or r.right > band.right + EPS or r.top < band.top - EPS then
					table.insert(problems, `{s.name}: the boss bar leaves the target band`)
				end
				if math.abs((r.left + r.right) / 2 - s.hudW / 2) > EPS or r.right - r.left ~= HudZones.BOSS_BAR.w then
					table.insert(problems, `{s.name}: the boss bar is not centred at its width`)
				end
			else
				-- review 2026-11-10: a strip PHONE_BOSS_H tall across M's width (the centre column), never over the
				-- portrait, the toggles, the minimap, ☰ or PvP
				local r = TopBand.bossBar("phone", s.hudW, s.hudH)
				local place = PhoneHud.place("target")
				local target = PhoneHud.rect(assert(place, "PhoneHud has no target place"), s.hudW, s.hudH)
				local m = TopBand.phoneZone(s.hudW, s.hudH)
				if math.abs(r.left - m.left) > EPS or math.abs(r.right - m.right) > EPS then
					table.insert(problems, `{s.name}: the boss bar is not as wide as M`)
				end
				if r.top ~= target.bottom + TopBand.PHONE_M.gap or r.bottom - r.top ~= TopBand.PHONE_BOSS_H then
					table.insert(problems, `{s.name}: the boss bar is not a strip under the target row`)
				end
				for _, name in { "portrait", "lure", "autoGrind", "autoPotion", "minimap", "menuToggle", "pvp" } do
					local other = PhoneHud.rect(assert(PhoneHud.place(name), name), s.hudW, s.hudH)
					if TopBand.meets(r, other) then
						table.insert(problems, `{s.name}: the boss bar meets {name}`)
					end
				end
				-- M starts under it while it shows
				local zone = TopBand.zone({
					w = s.w,
					h = s.h,
					bar = s.bar,
					device = "phone",
					hud = { bossBar = true },
					items = {},
				})
				if zone.top < r.bottom + s.bar + TopBand.PHONE_M.gap - EPS then
					table.insert(problems, `{s.name}: M at {zone.top} meets the boss bar ending {r.bottom + s.bar}`)
				end
			end
		end
		fail(problems)
		-- the client reads the place from TopBand.bossBar (no number of its own)
		local dungeon = fs.readFile("src/client/Controllers/DungeonController.luau")
		T.expect(string.find(dungeon, "return TopBand.bossBar(device, size.X, size.Y)", 1, true) ~= nil).toBe(true)
	end)
end)

-- The source check (UI plan package B acceptance) -------------------------------------------------------------------

local function files(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			files(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

-- The ScreenGuis that hold no message: the layers, the combat numbers and the hurt flash, the guide's pointer, the
-- player menu (it opens at the mouse, unscaled), the item preview of the developer tools, the loading screen and the
-- texture check.
local SCREEN_GUIS: { [string]: number } = {
	["src/client/Controllers/UIController.luau"] = 1,
	["src/client/Controllers/CombatFxController.luau"] = 2,
	["src/client/Controllers/GuidePointerController.luau"] = 1,
	["src/client/Controllers/PartyController.luau"] = 1,
	["src/client/Controllers/UiDevController.luau"] = 1,
	["src/client/Controllers/WorldController.luau"] = 1,
	["src/client/Vfx/Textures.luau"] = 1,
}

T.describe("Messages only through UI/Notify (UI plan package B)", function()
	T.it("nothing outside package B's files parents into the Toasts layer", function()
		local owned: { [string]: boolean } = {}
		for _, path in TextScan.OWNERS.B do
			owned[path] = true
		end
		local list: { string } = {}
		files("src/client", list)
		T.expect(#list > 200).toBe(true)
		local problems: { string } = {}
		for _, path in list do
			local source = fs.readFile(path)
			if string.find(source, "Vaelthorn_Toasts", 1, true) then
				table.insert(problems, `{path}: finds the Toasts layer by name`)
			end
			if not owned[path] and string.find(source, 'GetLayer("Toasts")', 1, true) then
				table.insert(problems, `{path}: parents into the Toasts layer (push through UI/Notify)`)
			end
			if path ~= "src/client/Controllers/UIController.luau" and string.find(source, "roots.Toasts", 1, true) then
				table.insert(problems, `{path}: reaches the Toasts layer's root`)
			end
		end
		-- UIController owns the layers: in the Toasts layer it mounts UI/Notify's host (Toast.mount) and measures the
		-- top bar, nothing else
		for line in string.gmatch(fs.readFile("src/client/Controllers/UIController.luau"), "[^\n]+") do
			if string.find(line, "roots.Toasts", 1, true) then
				local ok = string.find(line, "Toast.mount(scope, roots.Toasts)", 1, true)
					or string.find(line, "Announcement.mount(scope, roots.Toasts)", 1, true)
					or string.find(line, "AbsolutePosition", 1, true)
					or string.find(line, "{ roots.Screens, roots.Toasts }", 1, true) -- the bar's measure, too
				if not ok then
					table.insert(problems, `UIController: {line}`)
				end
			end
		end
		fail(problems)
		-- B's own files draw there only through UI/Notify's host: no GetLayer("Toasts") left in them
		for path in owned do
			if fs.isFile(path) then
				local source = fs.readFile(path)
				T.expect({ path, string.find(source, 'GetLayer("Toasts")', 1, true) == nil }).toEqual({ path, true })
			end
		end
	end)

	T.it("no message makes a ScreenGui of its own", function()
		local list: { string } = {}
		files("src/client", list)
		local problems: { string } = {}
		for _, path in list do
			local source = fs.readFile(path)
			local _, a = string.gsub(source, 'Instance%.new%("ScreenGui"%)', "")
			local _, b = string.gsub(source, 'New%("ScreenGui"%)', "")
			local count = a + b
			local allowed = SCREEN_GUIS[path] or 0
			if count > allowed then
				table.insert(problems, `{path}: {count} ScreenGui (a message goes through UI/Notify)`)
			end
		end
		fail(problems)
		-- the boss's danger banner and the dungeon's announcer lost theirs (the alert line of UI/Notify)
		local cast = fs.readFile("src/client/Vfx/BossCastBar.luau")
		T.expect(string.find(cast, "ScreenGui", 1, true)).toBeNil()
		T.expect(string.find(cast, "Notify.alert(", 1, true) ~= nil).toBe(true)
		local dungeon = fs.readFile("src/client/Controllers/DungeonController.luau")
		T.expect(string.find(dungeon, "Notify.alert(text, ANNOUNCE_SECONDS)", 1, true) ~= nil).toBe(true)
	end)
end)

return nil
