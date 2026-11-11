--!strict
-- S156: the player's HUD layout (Logic/HudLayout): what a client may save and where a moved element lands.
-- Owner 2026-10-21: the HUD column and the bottom-right corner (Logic/HudStack): at the common screen sizes the quest
-- tracker, the event panels, the arena pill, the Elite II timers, the mail, PvP and attack buttons never overlap.
-- UI plan phase 1 (owner 2026-10-31): one row of menu buttons, so the PC column starts under the minimap's area line
-- (under the guide bar while one shows), and the chat window in the lower left corner ends left of the action bar.
-- UI plan package A (owner 2026-11-10: "things covering each other, nothing folds"): nothing of the column passes its
-- floor; with no room the tracker keeps its header and two lines, the lowest panels fold to their line, then the
-- lowest elements hide behind a '+N' chip at the floor (L4: 500 random columns, the fold order, the '+N' count).

local fs = require("@lune/fs")

local HudLayout = require("../src/shared/Logic/HudLayout")
local HudStack = require("../src/shared/Logic/HudStack")
local Locale = require("../src/shared/Util/Locale")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")
local UiScale = require("../src/shared/Logic/UiScale")

T.describe("HUD layout (S156)", function()
	T.it("accepts known elements with fractions and sizes in range", function()
		T.expect(HudLayout.valid({})).toBe(true)
		T.expect(HudLayout.valid({ questTracker = { x = 0.5, y = 0.2 } })).toBe(true)
		T.expect(HudLayout.valid({ questTracker = { x = 0.5, y = 0.2, w = 300, h = 400 } })).toBe(true)
	end)
	T.it("refuses unknown elements, fields and values out of range", function()
		T.expect(HudLayout.valid({ minimap = { x = 0, y = 0 } })).toBe(false)
		T.expect(HudLayout.valid({ questTracker = { x = 1.5, y = 0 } })).toBe(false)
		T.expect(HudLayout.valid({ questTracker = { x = 0 / 0, y = 0 } })).toBe(false)
		T.expect(HudLayout.valid({ questTracker = { x = 0, y = 0, w = 10, h = 400 } })).toBe(false)
		T.expect(HudLayout.valid({ questTracker = { x = 0, y = 0, w = 300 } })).toBe(false)
		T.expect(HudLayout.valid({ questTracker = { x = 0, y = 0, z = 1 } })).toBe(false)
		T.expect(HudLayout.valid("x")).toBe(false)
	end)
	T.it("keeps a dragged element on the screen", function()
		local x, y = HudLayout.place({ x = 1, y = 1 }, 300, 1000, 800)
		T.expect(x).toBe(1000 - HudLayout.KEEP)
		T.expect(y).toBe(800 - HudLayout.KEEP)
		x, y = HudLayout.place({ x = 0, y = 0 }, 300, 1000, 800)
		T.expect(x).toBe(0)
		T.expect(y).toBe(0)
	end)
	T.it("saves fractions and whole sizes, and replaces one element", function()
		local e = HudLayout.entryAt(250, 200, 1000, 800, 300.4, 420.6)
		T.expect(e).toEqual({ x = 0.25, y = 0.25, w = 300, h = 421 })
		T.expect(HudLayout.valid(HudLayout.with({ junk = 1 }, "questTracker", e))).toBe(true)
		T.expect(HudLayout.with({ questTracker = e }, "questTracker", nil)).toEqual({})
	end)
	T.it("UI plan package A: a saved place in a reserved zone falls back, valid() is unchanged", function()
		-- PC 1920 x 1022: the target band at its tallest, the message zone under it and the card slot
		local w, h = 1920, 1022
		local pc = HudLayout.reserved(w, h, false, false)
		T.expect(pc.band ~= nil and pc.messages ~= nil and pc.card ~= nil).toBe(true)
		-- a tracker dropped on the target frame, among the toasts or on the card slot; then in its column
		T.expect(HudLayout.usable({ left = 800, top = 30, right = 1100, bottom = 200 }, w, h, false, false)).toBe(false)
		T.expect(HudLayout.usable({ left = 700, top = 300, right = 1000, bottom = 380 }, w, h, false, false))
			.toBe(false)
		T.expect(HudLayout.usable({ left = 1600, top = 850, right = 1890, bottom = 900 }, w, h, false, false))
			.toBe(false)
		T.expect(HudLayout.usable({ left = 1598, top = 460, right = 1898, bottom = 700 }, w, h, false, false))
			.toBe(true)
		-- a tablet's touch buttons stand where PC's card slot is: no card slot of its own
		T.expect(HudLayout.reserved(1280, 720, true, false).card).toBeNil()
		-- a phone: the target with the M zone under it and the thumb zone
		local pw, ph = PhoneHud.area(PhoneHud.DEVICES[1])
		local phone = HudLayout.reserved(pw, ph, true, true)
		T.expect(HudLayout.usable(phone.thumb, pw, ph, true, true)).toBe(false)
		T.expect(HudLayout.usable(phone.messages, pw, ph, true, true)).toBe(false)
		T.expect(HudLayout.usable({ left = 8, top = 153, right = 268, bottom = 200 }, pw, ph, true, true)).toBe(true)
		-- old saves still read (valid() does not know the screen); UI/HudDrag shows the built-in place for such a
		-- save and keeps the old place when a drag ends on a reserved one
		T.expect(HudLayout.valid({ questTracker = { x = 0.45, y = 0.02 } })).toBe(true)
		local drag = fs.readFile("src/client/UI/HudDrag.luau")
		T.expect(string.find(drag, "HudLayout.usable(rect, screen.X, screen.Y,", 1, true) ~= nil).toBe(true)
		T.expect(string.find(drag, "if not free and use(live) == nil then", 1, true) ~= nil).toBe(true)
		T.expect(string.find(drag, "local _, free = placed(Fusion.peek, now)", 1, true) ~= nil).toBe(true)
	end)

	T.it("moves and scales the event panels (owner 2026-10-21)", function()
		for _, id in { "worldEvent", "worldBoss", "bloodMoon", "tourney" } do
			T.expect(HudLayout.valid({ [id] = { x = 0.1, y = 0.6 } })).toBe(true)
			T.expect(HudLayout.valid({ [id] = { x = 0.1, y = 0.6, s = 1.25 } })).toBe(true)
			-- a panel follows its content: no width or height, and the scale stays in range
			T.expect(HudLayout.valid({ [id] = { x = 0.1, y = 0.6, w = 300, h = 300 } })).toBe(false)
			T.expect(HudLayout.valid({ [id] = { x = 0.1, y = 0.6, s = 3 } })).toBe(false)
			T.expect(HudLayout.valid({ [id] = { x = 0.1, y = 0.6, s = 0 / 0 } })).toBe(false)
		end
		T.expect(HudLayout.valid({ questTracker = { x = 0, y = 0, s = 1 } })).toBe(false)
		T.expect(HudLayout.clampScale("worldEvent", 9)).toBe(1.5)
		T.expect(HudLayout.clampScale("worldEvent", 0.1)).toBe(0.7)
		T.expect(HudLayout.clampScale("questTracker", 2)).toBe(1)
		T.expect(HudLayout.scaleOf(nil)).toBe(1)
		local e = HudLayout.entryAt(100, 400, 1000, 800, nil, nil, 1.234)
		T.expect(e).toEqual({ x = 0.1, y = 0.5, s = 1.23 })
		local both = HudLayout.with(HudLayout.with({}, "questTracker", { x = 0.5, y = 0.5 }), "worldEvent", e)
		T.expect(HudLayout.valid(both)).toBe(true)
		T.expect(both.questTracker).toEqual({ x = 0.5, y = 0.5 })
		-- a scaled panel is kept on the screen by its scaled width
		local x = HudLayout.place({ x = 0, y = 0 }, 280 * 1.5, 1000, 800)
		T.expect(x).toBe(0)
		x = HudLayout.place({ x = 1, y = 0 }, 280 * 1.5, 1000, 800)
		T.expect(x).toBe(1000 - HudLayout.KEEP)
	end)
end)

type Rect = HudStack.Rect
type Box = HudStack.Box

-- Virtual screens (UI/Scale): PC 1366 x 768, 1600 x 900, 1920 x 1080 and 2560 x 1440 (all 1920 x 1080), 1920 x 1200,
-- a 2560 x 1080 ultrawide, 1280 x 1024 (1920 x 1536), 1024 x 768 at the 0.6 floor (1707 x 1280), 1024 x 600 and a
-- short 1280 x 600 window (1707 x 1000, 2133 x 1000).
local PC = {
	{ 1920, 1080 },
	{ 1920, 1200 },
	{ 2560, 1080 },
	{ 1920, 1536 },
	{ 1707, 1280 },
	{ 1707, 1000 },
	{ 2133, 1000 },
}
-- Touch screens that are not phones: a 1920 x 1080 touch laptop and 1280 x 720 (1280 x 720), 1280 x 800, an iPad
-- 1024 x 768 at the touch floor (1210 x 907), a 1024 x 600 tablet (1210 x 709), an iPad Pro (1280 x 960).
local TABLET = { { 1280, 720 }, { 1280, 800 }, { 1210, 907 }, { 1210, 709 }, { 1280, 960 } }

-- An element of the column; `line` its folded line (UI plan package A: a panel's header, the tracker's header).
local function box(w: number, h: number, custom: Rect?, line: number?): Box
	return { shown = true, w = w, h = h, custom = custom, line = line }
end

-- The column's elements of a scenario on a w x h screen (panel widths per device; heights: the world boss panel at
-- its tallest on PC, standing at the barrow on a touch screen, folded to its line, a world event panel, the Elite II
-- timers' header and rows).
local function scenario(name: string, touch: boolean, w: number): { [string]: Box }
	local panel = if touch then HudStack.PANEL_TOUCH else HudStack.PANEL_PC
	local pill = if touch then 44 else 36
	local boss = if touch then 130 else 211
	local event = if touch then 120 else 160
	local line = if touch then HudStack.LINE_TOUCH else HudStack.LINE_PC
	local tracker = box(HudStack.TRACKER, HudStack.TRACKER_MIN, nil, HudStack.TRACKER_LEAST)
	local top = if touch then HudStack.TOUCH_TOP else HudStack.RIGHT_TOP
	if name == "tracker" then
		return { questTracker = tracker }
	elseif name == "bossLine" then
		return { worldBoss = box(panel, 40, nil, line), questTracker = tracker }
	elseif name == "bossAndEvent" then
		return {
			worldBoss = box(panel, boss, nil, line),
			worldEvent = box(panel, event, nil, line),
			questTracker = tracker,
		}
	elseif name == "busy" then
		if touch then
			return {
				arena = box(HudStack.ARENA_PILL, pill),
				worldBoss = box(panel, 40, nil, line),
				elite = box(HudStack.ELITE, 32 + 44, nil, line),
				questTracker = tracker,
			}
		end
		return {
			arena = box(HudStack.ARENA_PILL, pill),
			worldBoss = box(panel, 40, nil, line),
			worldEvent = box(panel, event, nil, line),
			elite = box(HudStack.ELITE, 32 + 3 * 44),
			questTracker = tracker,
		}
	elseif name == "movedTracker" then
		-- the tracker dragged onto its own built-in place (or only scaled there): the boss panel goes round it
		local left = if touch then HudStack.MARGIN else w - HudStack.MARGIN - HudStack.TRACKER
		-- PC: tall enough that the boss panel has no room under it at 1920 x 1080 (UI plan phase 4: the column starts
		-- 24 px higher, so 324 instead of 300 keeps the bottom where it was)
		local tall = if touch then 120 else 324
		local moved = { left = left, top = top, right = left + HudStack.TRACKER, bottom = top + tall }
		return { worldBoss = box(panel, boss, nil, line), questTracker = box(HudStack.TRACKER, tall, moved) }
	elseif name == "movedBoss" then
		local left = if touch then HudStack.MARGIN else w - HudStack.MARGIN - panel
		local moved = { left = left, top = top, right = left + panel, bottom = top + 120 }
		return {
			worldBoss = box(panel, 120, moved),
			worldEvent = box(panel, 160, nil, line),
			questTracker = tracker,
		}
	end
	error(name)
end
local SCENARIOS = { "tracker", "bossLine", "bossAndEvent", "busy", "movedTracker", "movedBoss" }
-- every scenario without and with the guide bar under the minimap (UI plan phase 1) and the row of "something
-- waits" buttons under them (phase 2)
local SCENARIOS_GUIDE: { { name: string, guide: boolean, waiting: boolean } } = {}
for _, name in SCENARIOS do
	for _, guide in { false, true } do
		for _, waiting in { false, true } do
			table.insert(SCENARIOS_GUIDE, { name = name, guide = guide, waiting = waiting })
		end
	end
end

-- UI plan phase 2: the row of "something waits" buttons on PC (Hud/WaitingRow): right-aligned under the minimap's area
-- line or under the guide bar, at most four buttons
local function waitingRow(w: number, guide: boolean): Rect
	local top = if guide then HudStack.RIGHT_TOP_GUIDE else HudStack.RIGHT_TOP
	local right = w - 22
	local width = 4 * HudStack.WAITING + 3 * 8
	return { left = right - width, top = top, right = right, bottom = top + HudStack.WAITING }
end

local function show(r: Rect): string
	return `({r.left}, {r.top})-({r.right}, {r.bottom})`
end

-- Every rectangle on the screen: the corner's buttons, the buttons right of the portrait, the moved elements, the PC
-- Elite II timers and the column's places, by name.
local function screen(
	touch: boolean,
	w: number,
	h: number,
	boxes: { [string]: Box },
	guide: boolean?,
	waiting: boolean?
): { [string]: Rect }
	local all: { [string]: Rect } = table.clone(HudStack.fixed(touch, w, h))
	-- the row stands in the menu: an element the player moved there may lie under it (their choice), the column's own
	-- places never do
	local moved = false
	for _, b in boxes do
		moved = moved or b.custom ~= nil
	end
	if waiting and not touch and not moved then
		all.waiting = waitingRow(w, guide == true)
	end
	local e = HudStack.EXTRAS
	all.extras = { left = e.x, top = e.y, right = e.x + e.w, bottom = e.y + e.h }
	for id, b in boxes do
		if b.custom then
			all[id] = b.custom
		elseif id == "elite" and not touch then
			all.elite = HudStack.elite(w, h, b.h)
		end
	end
	for id, r in HudStack.layout(touch, false, w, h, 0, boxes, nil, guide, waiting) do
		all[id] = r
	end
	return all
end

-- "a / b" for every pair that overlaps, but the skill arc's own buttons (round, Hud/MobileSkills) among themselves.
local function clashes(all: { [string]: Rect }): { string }
	local names = {}
	for name in all do
		table.insert(names, name)
	end
	table.sort(names)
	local out = {}
	for i, a in names do
		for j = i + 1, #names do
			local b = names[j]
			local arcA = string.match(a, "^skill") ~= nil or a == "attack"
			local arcB = string.match(b, "^skill") ~= nil or b == "attack"
			if not (arcA and arcB) and HudStack.overlaps(all[a], all[b]) then
				table.insert(out, `{a} {show(all[a])} / {b} {show(all[b])}`)
			end
		end
	end
	return out
end

T.describe("HUD column and corner (owner 2026-10-21)", function()
	T.it("the corner's buttons stand apart: the mail in its own slot under the PvP toggle", function()
		for _, touch in { false, true } do
			local f = HudStack.fixed(touch, 1920, 1080)
			-- at least a gap's clearance round the envelope
			local mail = f.mail
			local grown = {
				left = mail.left - HudStack.GAP,
				top = mail.top - HudStack.GAP,
				right = mail.right + HudStack.GAP,
				bottom = mail.bottom + HudStack.GAP,
			}
			for name, r in f do
				if name ~= "mail" and HudStack.overlaps(grown, r) then
					error(`{if touch then "touch" else "PC"}: the mail is closer than a gap to {name}`)
				end
			end
			T.expect(mail.top >= f.pvp.bottom + HudStack.GAP).toBe(true)
			T.expect(HudStack.overlaps(f.pvp, f.pvpBadge)).toBe(false)
			if touch then
				T.expect(HudStack.overlaps(f.attack, f.pvp)).toBe(false)
				T.expect(HudStack.overlaps(f.attack, f.pvpBadge)).toBe(false)
			end
		end
	end)

	T.it("nothing overlaps and nothing leaves the screen on PC and tablets", function()
		local function check(touch: boolean, sizes: { { number } })
			for _, size in sizes do
				local w, h = size[1], size[2]
				for _, check in SCENARIOS_GUIDE do
					local name, guide, waiting = check.name, check.guide, check.waiting
					local boxes = scenario(name, touch, w)
					local all = screen(touch, w, h, boxes, guide, waiting)
					local where =
						`{if touch then "touch" else "PC"} {w} x {h} {name}{if guide then " (guide)" else ""}{if waiting
							then " (waiting)"
							else ""}`
					local bad = clashes(all)
					if #bad > 0 then
						error(`{where}: {table.concat(bad, "; ")}`)
					end
					for id, r in all do
						if r.left < 0 or r.top < 0 or r.right > w or r.bottom > h then
							error(`{where}: {id} {show(r)} leaves the screen`)
						end
					end
					-- every shown element has a place above the column's floor (PC the corner, a touch screen the
					-- thumbstick's zone) of its full height (the tracker: at least its header), its folded line, or stands behind the
					-- '+N' chip (UI plan package A: nothing passes the floor)
					local floor = HudStack.column(touch, false, w, h, 0).floor
					local placed = HudStack.arrange(touch, false, w, h, 0, boxes, nil, guide, waiting)
					for id, b in boxes do
						local r = all[id]
						if table.find(placed.hidden, id) then
							T.expect(r == nil and placed.chip ~= nil).toBe(true)
							continue
						end
						if not r then
							error(`{where}: {id} has no place`)
						end
						local folded = table.find(placed.folded, id) ~= nil
						local least = if folded
							then b.line or b.h
							elseif id == "questTracker" then HudStack.TRACKER_LEAST
							else b.h
						if not b.custom and (r.bottom - r.top < least - 1e-6 or r.bottom > floor + 1e-6) then
							error(`{where}: {id} {show(r)} is shorter than {least} or under the floor {floor}`)
						end
					end
				end
			end
		end
		check(false, PC)
		check(true, TABLET)
	end)

	T.it("PC: the column stays under the minimap and over the corner, the tracker takes the room left", function()
		for _, size in PC do
			local w, h = size[1], size[2]
			local places = HudStack.layout(false, false, w, h, 0, scenario("bossLine", false, w))
			local boss, tracker = places.worldBoss, places.questTracker
			T.expect(boss.top).toBe(HudStack.RIGHT_TOP)
			T.expect(boss.right).toBe(w - HudStack.MARGIN)
			-- the tracker right under the boss's line, down to the corner (its list scrolls inside)
			T.expect(tracker.top).toBe(boss.bottom + HudStack.GAP)
			T.expect(tracker.right).toBe(w - HudStack.MARGIN)
			T.expect(tracker.bottom).toBe(HudStack.cornerTop(false, w, h) - HudStack.GAP)
		end
	end)

	T.it("a moved element stays an obstacle: the boss panel goes round a tracker dragged onto its place", function()
		local w, h = 1920, 1080
		local boxes = scenario("movedTracker", false, w)
		local places = HudStack.layout(false, false, w, h, 0, boxes)
		T.expect(places.questTracker).toBe(nil)
		local custom = boxes.questTracker.custom :: Rect
		T.expect(HudStack.overlaps(places.worldBoss, custom)).toBe(false)
		-- under the tracker it has no room left for the whole panel: UI plan package A folds it to its line there
		T.expect(places.worldBoss.top).toBe(custom.bottom + HudStack.GAP)
		T.expect(places.worldBoss.bottom - places.worldBoss.top).toBe(HudStack.LINE_PC)
		T.expect(places.worldBoss.right).toBe(w - HudStack.MARGIN)
		-- a tracker so tall that not even the line fits under it: the spare column beside it, from its top (GAP under
		-- the message zone, which it never covers)
		local taller = { left = custom.left, top = custom.top, right = custom.right, bottom = custom.top + 504 }
		local aside = HudStack.layout(false, false, w, h, 0, {
			worldBoss = box(HudStack.PANEL_PC, 211, nil, HudStack.LINE_PC),
			questTracker = box(HudStack.TRACKER, 504, taller),
		})
		T.expect(aside.worldBoss.top).toBe(HudStack.column(false, false, w, h, 0).spareTop)
		T.expect(aside.worldBoss.top).toBe(h * HudStack.MESSAGE_BOTTOM + HudStack.GAP)
		T.expect(aside.worldBoss.right <= custom.left - HudStack.GAP).toBe(true)
		-- a shorter moved tracker leaves it room under it
		local short = { left = custom.left, top = custom.top, right = custom.right, bottom = custom.top + 120 }
		boxes.questTracker = box(HudStack.TRACKER, 120, short)
		local under = HudStack.layout(false, false, w, h, 0, boxes)
		T.expect(under.worldBoss.top).toBe(short.bottom + HudStack.GAP)
		T.expect(under.worldBoss.right).toBe(w - HudStack.MARGIN)
		-- a boss panel dragged onto its place: the tracker starts under it
		local moved = scenario("movedBoss", false, w)
		local after = HudStack.layout(false, false, w, h, 0, moved)
		local boss = moved.worldBoss.custom :: Rect
		T.expect(after.worldEvent.top).toBe(boss.bottom + HudStack.GAP)
		T.expect(after.questTracker.top).toBe(after.worldEvent.bottom + HudStack.GAP)
	end)

	T.it("a touch screen stacks the column under the portrait and the party, clear of the thumbstick's zone", function()
		-- final UI review 2026-11-10: the floor is the thumbstick's zone (Logic/HudZones.thumb, Logic/PhoneHud.THUMB)
		-- less a gap; the sprint and mount buttons moved into the corner beside the page button
		for _, size in TABLET do
			local w, h = size[1], size[2]
			T.expect(HudStack.column(true, false, w, h, 0).floor).toBe(HudStack.touchFloor(h))
			for others = 0, 4 do
				local places = HudStack.layout(true, false, w, h, others, scenario("tracker", true, w))
				local tracker = places.questTracker
				local top = if others > 0 then HudStack.PARTY_TOP + others * HudStack.PARTY_ROW else HudStack.TOUCH_TOP
				local floor = HudStack.touchFloor(h)
				if top + HudStack.TRACKER_MIN <= floor then
					T.expect(tracker.left).toBe(HudStack.MARGIN)
					T.expect(tracker.top).toBe(top)
				end
				-- UI plan package A: at least its header always finds a place on these tablets
				T.expect(tracker ~= nil and tracker.bottom <= floor).toBe(true)
			end
		end
	end)

	T.it("a phone stacks the column in its left stack, clear of every other place", function()
		-- UI plan package A: 52-px lines from PhoneHud.STACK_TOP down to the thumb zone, the party strip one of them, the
		-- rest behind the '+N' chip at the stack's right end. Package A review (owner 2026-11-10): with the widths a phone
		-- draws (Logic/PhoneHud: the party's strip, the panels, the arena's pill, the guide line and the tracker) every
		-- element stands beside the chip, so the stack never shows '+N' alone, and one picked from the '+N' list (`keep`,
		-- UI/HudSlots.bring) shows.
		local line = PhoneHud.LINE
		local panel = PhoneHud.PANEL_WIDTH
		local tracker = box(PhoneHud.TRACKER_WIDTH, HudStack.TRACKER_MIN, nil, line)
		local party = box(PhoneHud.PARTY_WIDTH, line, nil, line)
		local every: { [string]: Box } = {
			party = party,
			arena = box(panel, line, nil, line), -- the queue's pill
			worldBoss = box(panel, 120, nil, line),
			worldEvent = box(panel, 120, nil, line),
			bloodMoon = box(panel, 140, nil, line),
			tourney = box(panel, 120, nil, line),
			guide = box(panel, line, nil, line),
			questTracker = tracker,
		}
		local scenarios: { { [string]: Box } } = {
			{ questTracker = tracker },
			{ worldBoss = box(panel, 120, nil, line), questTracker = tracker },
			{ party = party, worldBoss = box(panel, 120, nil, line), questTracker = tracker },
			every,
		}
		for id, b in every do
			if id ~= "questTracker" then
				table.insert(scenarios, { [id] = b, questTracker = tracker })
			end
		end
		local function check(d: any, bar: number, boxes: { [string]: Box }, w: number, h: number): HudStack.Placed
			local places = PhoneHud.places(w, h)
			local placed = HudStack.arrange(true, true, w, h, 0, boxes)
			local all = table.clone(placed.rects)
			if placed.chip then
				all["+N"] = placed.chip
			end
			for id, r in all do
				T.expect(r.left >= places.stack.x).toBe(true)
				T.expect(r.right <= places.stack.x + PhoneHud.STACK_WIDTH).toBe(true)
				T.expect(r.top >= PhoneHud.STACK_TOP).toBe(true)
				T.expect(r.bottom <= PhoneHud.stackBottom(h) + 1e-6).toBe(true)
				for name, place in places do
					if name ~= "stack" and HudStack.overlaps(r, PhoneHud.rect(place, w, h)) then
						error(`{d.name} bar {bar}: {id} {show(r)} / {name}`)
					end
				end
				for other, o in all do
					if other ~= id and HudStack.overlaps(r, o) then
						error(`{d.name} bar {bar}: {id} {show(r)} / {other} {show(o)}`)
					end
				end
			end
			-- one line or more always shows something: the first element, beside the chip while one hides
			local shown = 0
			for _ in placed.rects do
				shown += 1
			end
			if shown < 1 then
				error(`{d.name} bar {bar}: only '+N' ({table.concat(placed.hidden, ", ")})`)
			end
			T.expect(#placed.hidden > 0).toBe(placed.chip ~= nil)
			return placed
		end
		for _, d in PhoneHud.DEVICES do
			for _, bar in { 0, 36, 58 } do
				local w, h = PhoneHud.area(d, bar)
				for _, boxes in scenarios do
					local placed = check(d, bar, boxes, w, h)
					-- the player picks a hidden one from the '+N' list: it stands in the stack, the others give way
					for _, id in placed.hidden do
						local brought = table.clone(boxes)
						brought[id] = table.clone(boxes[id])
						brought[id].keep = true
						local again = check(d, bar, brought, w, h)
						if not again.rects[id] then
							error(`{d.name} bar {bar}: {id} picked from '+N' stays hidden`)
						end
					end
				end
			end
		end
	end)

	T.it("a phone's stack elements draw the widths of Logic/PhoneHud", function()
		-- package A review (owner 2026-11-10): the model above holds only while the files draw these widths
		local hud = "src/client/UI/Screens/Hud/"
		for file, width in
			{
				["src/client/UI/Screens/PartyFrames.luau"] = "PhoneHud.PARTY_WIDTH",
				[hud .. "QuestTracker.luau"] = "PhoneHud.TRACKER_WIDTH",
				[hud .. "WorldBossPanel.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "WorldEventPanel.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "BloodMoonPanel.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "TourneyPanel.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "ArenaPanel.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "ArenaTeams.luau"] = "PhoneHud.PANEL_WIDTH",
				[hud .. "NavBar.luau"] = "PhoneHud.PANEL_WIDTH",
			}
		do
			if not string.find(fs.readFile(file), width, 1, true) then
				error(`{file} does not draw {width} on a phone`)
			end
		end
		T.expect(PhoneHud.PARTY_WIDTH <= PhoneHud.PANEL_WIDTH).toBe(true)
		T.expect(PhoneHud.TRACKER_WIDTH <= PhoneHud.PANEL_WIDTH).toBe(true)
		T.expect(PhoneHud.PANEL_WIDTH + 6 + PhoneHud.CHIP.w <= PhoneHud.STACK_WIDTH).toBe(true)
	end)

	T.it("Studio and browser viewports: the column stops above the PvP toggle, its badge and the mail", function()
		-- owner 2026-10-22 (Studio, a 1456 x 776 viewport): the tracker ran 26 px into the PvP toggle. The HUD's
		-- layer keeps clear of the top bar (CoreUISafeInsets), so the column is laid out in the layer's size
		-- (UiScale.hud, UI/Scale.HudSize), the size the corner buttons anchored to its bottom stand in.
		local VIEWPORTS = {
			{ 1456, 776 }, -- the Studio check
			{ 1366, 768 },
			{ 1366, 657 }, -- a browser-like window on a 1366 x 768 screen
			{ 1280, 593 },
			{ 1600, 787 },
			{ 1920, 929 },
			{ 1920, 1009 },
			{ 1920, 1080 },
			{ 2560, 1305 },
		}
		for _, v in VIEWPORTS do
			for _, inset in { UiScale.TOP_BAR, 36 } do
				local k = UiScale.factor(v[1], v[2], false)
				local w, h = UiScale.hud(v[1], v[2], false, inset)
				-- the layer is shorter than the screen in virtual pixels: laid out in the screen's size the column
				-- would end `inset / k` lower than the buttons
				T.expect(h < v[2] / k).toBe(true)
				local corner = HudStack.fixed(false, w, h)
				for _, name in SCENARIOS do
					local boxes = scenario(name, false, w)
					local places = HudStack.layout(false, false, w, h, 0, boxes)
					for id, r in places do
						for _, button in { "pvp", "pvpBadge", "mail" } do
							if HudStack.overlaps(r, corner[button]) then
								error(`{v[1]} x {v[2]} (top bar {inset}) {name}: {id} {show(r)} / {button}`)
							end
						end
						if r.right > corner.pvp.left and r.bottom > corner.pvp.top - HudStack.GAP then
							error(
								`{v[1]} x {v[2]} (top bar {inset}) {name}: {id} ends {r.bottom}, the toggle at {corner.pvp.top}`
							)
						end
					end
				end
			end
		end
	end)

	T.it(
		"measured corner (Studio 1462 x 793): the real toggle bounds the column whatever the computed height",
		function()
			-- owner 2026-10-22: the tracker's Body ran from y 361 to 621 px, the PvP toggle stood at (1403, 599), 46 x 46 px.
			-- UI/HudSlots measures the corner's buttons (AbsolutePosition / AbsoluteSize, from the panels' frame) and
			-- HudStack.layout keeps the column above them even when its own height of the layer is too tall.
			local k = 46 / HudStack.PVP.w
			local pvp = HudStack.fromScreen(1403, 599, 46, 46, 0, 0, k)
			T.expect(math.abs((pvp.right - pvp.left) - HudStack.PVP.w) < 1e-6).toBe(true)
			T.expect(math.abs(pvp.top - 599 / k) < 1e-6).toBe(true)
			-- the frame's corner is the origin: the same button 30 px lower in a frame 30 px lower is the same rectangle
			local shifted = HudStack.fromScreen(1403, 629, 46, 46, 0, 30, k)
			T.expect(math.abs(shifted.top - pvp.top) < 1e-6).toBe(true)
			local badge = HudStack.fromScreen(1352, 648, 97, 17, 0, 0, k)
			local measured = { pvp, badge }
			-- the column computed for a layer 46 virtual px taller than the real one: its corner (and floor) too low
			local w = pvp.right + HudStack.PVP.right
			local h = pvp.bottom + HudStack.PVP.bottom + 46
			local unclamped = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w))
			T.expect(HudStack.overlaps(unclamped.questTracker, pvp)).toBe(true) -- the Studio bug, reproduced
			for _, name in SCENARIOS do
				local boxes = scenario(name, false, w)
				for id, r in HudStack.layout(false, false, w, h, 0, boxes, measured) do
					for _, button in measured do
						if HudStack.overlaps(r, button) then
							error(`{name}: {id} {show(r)} / measured {show(button)}`)
						end
					end
					if r.right > pvp.left and r.bottom > pvp.top - HudStack.GAP then
						error(`{name}: {id} ends {r.bottom}, the real toggle at {pvp.top}`)
					end
				end
				local elite = boxes.elite
				if elite then
					local timers = HudStack.elite(w, h, elite.h, measured)
					T.expect(timers.bottom <= pvp.top - HudStack.GAP).toBe(true)
				end
			end
			-- the tracker still takes the room down to just above the real toggle
			local placed = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), measured)
			T.expect(math.abs(placed.questTracker.bottom - (pvp.top - HudStack.GAP)) < 1e-6).toBe(true)
		end
	)

	T.it("floorAbove: only buttons under the column's top and in its lanes lower the floor, never raise it", function()
		local column = HudStack.column(false, false, 1920, 1080, 0)
		local floor = column.floor
		local function rect(left: number, top: number): Rect
			return { left = left, top = top, right = left + 64, bottom = top + 64 }
		end
		local lane = column.x - 100 -- inside the main column
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, {})).toBe(floor)
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, { rect(lane, floor - 40) })).toBe(floor - 48)
		-- lower than the floor already: the computed floor stays
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, { rect(lane, floor + 40) })).toBe(floor)
		-- above the column's top (the minimap's row): not under the column
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, { rect(lane, column.top - 10) })).toBe(floor)
		-- left of every lane (the column and its two spares)
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, { rect(400, floor - 40) })).toBe(floor)
		-- in a spare lane
		local spares = column.spares :: { number }
		T.expect(HudStack.floorAbove(column, HudStack.TRACKER, { rect(spares[2] - 80, floor - 30) })).toBe(floor - 38)
		-- a phone lays out without measured buttons; a tablet's column (left) ignores the right corner
		local tablet = HudStack.column(true, false, 1280, 720, 0)
		T.expect(HudStack.floorAbove(tablet, HudStack.TRACKER, { rect(1200, 300) })).toBe(tablet.floor)
	end)

	T.it("a moved tracker stops above the corner (Studio diagnostics 1462 x 793, Root 1991 x 1001 units)", function()
		-- owner 2026-10-22: QuestTracker at (1675, 455) (moved by a few pixels from its built-in place), 300 x 400 with
		-- a 355 unit list (its content: quests, 3 contracts, the daily set); the PvP toggle's top at 1001 - 120 - 64
		local w, h = 1991, 1001
		local chrome = HudStack.TRACKER_LEAST -- padding 6, header 28, gap 3, padding 8
		local corner = HudStack.fixed(false, w, h)
		T.expect(corner.pvp.top).toBe(817)
		local left, top, content = 1675, 455, 355
		local screenFloor = h - 24
		-- before: the floor of a moved tracker was the screen's bottom, its frame ended at 855
		T.expect(top + chrome + HudStack.trackerBody(top, screenFloor, chrome, content)).toBe(855)
		-- now: GAP above the toggle in its lane
		local corners: { Rect } = {}
		for _, r in corner do
			table.insert(corners, r)
		end
		local floor = HudStack.floorUnder(left, left + HudStack.TRACKER, top, screenFloor, corners)
		T.expect(floor).toBe(corner.pvp.top - HudStack.GAP)
		local body = HudStack.trackerBody(top, floor, chrome, content)
		T.expect(top + chrome + body <= corner.pvp.top - HudStack.GAP).toBe(true)
		T.expect(body).toBe(floor - top - chrome) -- the list scrolls in what is left
		-- a resized tracker is capped the same way; a short one keeps its content's height
		T.expect(HudStack.trackerBody(top, floor, chrome, content, 500)).toBe(body)
		T.expect(HudStack.trackerBody(top, floor, chrome, 120)).toBe(120)
		T.expect(HudStack.trackerBody(top, floor, chrome, 120, 200)).toBe(200 - chrome)
		-- no room under the top (moved right over the toggle's row): the header stays, the list hides
		T.expect(HudStack.trackerBody(810, floor, chrome, content)).toBe(0)
		-- buttons above its top (the mail starts at 917) or outside its lane leave the screen's bottom
		T.expect(HudStack.floorUnder(left, left + HudStack.TRACKER, 950, screenFloor, corners)).toBe(screenFloor)
		T.expect(HudStack.floorUnder(400, 700, top, screenFloor, corners)).toBe(screenFloor)
		-- the measured toggle counts like the computed one (it may stand higher than the formula says)
		local measuredPvp = { left = 1911, top = 780, right = 1975, bottom = 844 }
		T.expect(HudStack.floorUnder(left, left + HudStack.TRACKER, top, screenFloor, { measuredPvp })).toBe(772)
	end)

	T.it("UI plan phase 1: one row of menu buttons, the column starts under the minimap or the guide bar", function()
		-- Hud menu: Theme.Padding.Large 22, one row of 52 px buttons, 8, the minimap frame (266; phase 4: its one caption
		-- inside, the area line under it is gone); the guide bar (44) stands 8 under the minimap frame
		T.expect(HudStack.RIGHT_TOP).toBe(22 + 52 + 8 + 266 + HudStack.GAP)
		T.expect(HudStack.RIGHT_TOP_GUIDE).toBe(22 + 52 + 8 + 266 + 8 + 44 + HudStack.GAP)
		T.expect(HudStack.RIGHT_TOP_GUIDE > HudStack.RIGHT_TOP).toBe(true)
		-- 104 px higher than the two rows of 14 buttons (460) without a guide, 52 with one
		T.expect(460 - HudStack.RIGHT_TOP).toBe(104)
		for _, size in PC do
			local w, h = size[1], size[2]
			local free = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w))
			local guided = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), nil, true)
			T.expect(free.questTracker.top).toBe(HudStack.RIGHT_TOP)
			T.expect(guided.questTracker.top).toBe(HudStack.RIGHT_TOP_GUIDE)
			-- both reach down to the corner: the tracker is taller without the guide bar
			T.expect(free.questTracker.bottom).toBe(guided.questTracker.bottom)
		end
		-- the guide bar is a PC thing: a tablet's and a phone's column start where they did
		local tablet = HudStack.column(true, false, 1280, 720, 0, true)
		T.expect(tablet.top).toBe(HudStack.TOUCH_TOP)
		local phone = HudStack.column(true, true, 886, 435, 0, true)
		T.expect(phone.top).toBe(PhoneHud.stackTop(0))
		-- phase 2: right of the portrait only the "Auto" button (the login reward and the season pass moved under the
		-- minimap)
		T.expect(HudStack.EXTRAS.h).toBe(44)
	end)

	T.it('UI plan phase 2: the row of "something waits" buttons pushes the PC column down by its height', function()
		-- Hud/WaitingRow: under the area line it starts where the column did (RIGHT_TOP), under the guide bar too
		T.expect(HudStack.WAITING).toBe(44)
		for _, size in PC do
			local w, h = size[1], size[2]
			for _, guide in { false, true } do
				local without = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), nil, guide)
				local with = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), nil, guide, true)
				T.expect(with.questTracker.top - without.questTracker.top).toBe(HudStack.WAITING + HudStack.GAP)
				T.expect(with.questTracker.top).toBe(waitingRow(w, guide).bottom + HudStack.GAP)
				T.expect(with.questTracker.bottom).toBe(without.questTracker.bottom)
			end
		end
		-- a tablet's and a phone's column do not move (the row is in the PC menu; a phone keeps its drawer)
		T.expect(HudStack.column(true, false, 1280, 720, 0, false, true).top).toBe(HudStack.TOUCH_TOP)
		T.expect(HudStack.column(true, true, 886, 435, 0, false, true).top).toBe(PhoneHud.stackTop(0))
	end)

	T.it("Studio check 2026-10-31: the PC column never starts above the menu's measured bottom", function()
		-- the row stood inside the tracker (the column had not stepped down): the column also follows where the menu
		-- over the minimap really ends (UI/HudSlots.MenuBottom), whatever the flags say
		for _, size in PC do
			local w, h = size[1], size[2]
			local flagged = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), nil, false, true)
			local measured = HudStack.layout(
				false,
				false,
				w,
				h,
				0,
				scenario("tracker", false, w),
				nil,
				false,
				false,
				waitingRow(w, false).bottom
			)
			T.expect(measured.questTracker.top).toBe(flagged.questTracker.top)
			-- a menu that ends higher (nothing under the minimap) never lifts the column above its place
			local high = HudStack.layout(false, false, w, h, 0, scenario("tracker", false, w), nil, false, false, 100)
			T.expect(high.questTracker.top).toBe(HudStack.RIGHT_TOP)
		end
		-- a phone's and a tablet's column do not follow it
		T.expect(HudStack.column(true, false, 1280, 720, 0, false, false, 600).top).toBe(HudStack.TOUCH_TOP)
		-- the row says it shows per row (a rebuilt row's cleanup cannot switch the new one off), and it steps out of
		-- sight with the menu's buttons above it
		local row = fs.readFile("src/client/UI/Screens/Hud/WaitingRow.luau")
		T.expect(string.find(row, "HudSlots.SetWaiting(owner", 1, true) ~= nil).toBe(true)
		T.expect(string.find(row, "props.Covered", 1, true) ~= nil).toBe(true)
		local hud = fs.readFile("src/client/UI/Screens/Hud/init.luau")
		T.expect(string.find(hud, "HudSlots.SetMenu(scope, root)", 1, true) ~= nil).toBe(true)
	end)

	T.it("UI plan phase 2: a window covers a HUD part only when it overlaps it by more than the margin", function()
		local tracker = { left = 1600, top = 380, right = 1900, bottom = 700 }
		-- a 1240 wide window in the middle of 1920 ends at 1580: clear
		T.expect(HudStack.covers(tracker, { left = 340, top = 190, right = 1580, bottom = 890 }, 4)).toBe(false)
		-- a window dragged over it
		T.expect(HudStack.covers(tracker, { left = 900, top = 190, right = 1700, bottom = 890 }, 4)).toBe(true)
		-- an edge that only touches it, or a sliver under the margin, does not count
		T.expect(HudStack.covers(tracker, { left = 300, top = 100, right = 1603, bottom = 900 }, 4)).toBe(false)
		T.expect(HudStack.covers(tracker, { left = 300, top = 100, right = 1610, bottom = 900 }, 4)).toBe(true)
		-- a full-screen window (touch) covers everything
		T.expect(HudStack.covers(tracker, { left = 0, top = 0, right = 1920, bottom = 1080 }, 4)).toBe(true)
	end)

	T.it("UI plan phase 1: the chat window ends left of the action bar, within its width range", function()
		local gap, min = HudStack.CHAT_GAP, HudStack.CHAT_MIN
		-- 1920 wide: room to spare, Roblox's own width
		T.expect(HudStack.chatWidthScale(8, 400, 1, 501)).toBe(1)
		-- 1280 x 720 (UI scale 2/3): the bar starts at 334, a 400 px chat narrows to end `gap` left of it
		local scale = HudStack.chatWidthScale(8, 400, 1, 334)
		T.expect(math.abs(8 + 400 * scale - (334 - gap)) < 1e-6).toBe(true)
		-- already narrowed: the same answer from the narrowed size (no back and forth)
		T.expect(math.abs(HudStack.chatWidthScale(8, 400 * scale, scale, 334) - scale) < 1e-6).toBe(true)
		-- a very narrow screen: never under the minimum
		T.expect(HudStack.chatWidthScale(8, 400, 1, 100)).toBe(min)
		-- a hidden window keeps its scale
		T.expect(HudStack.chatWidthScale(8, 0, 0.8, 334)).toBe(0.8)
	end)

	T.it("Studio check 2026-10-31: moved elements stay under the menu, windows hide the tracker", function()
		-- 1108 x 576 (scale 0.6): the menu with the row of "something waits" buttons ends at 423, a tracker the player
		-- had moved near its built-in place started at 392 (under the row's icons)
		local menu = { left = 1847 - 22 - 352, top = 22, right = 1847 - 22, bottom = 423 }
		local tracker = { left = 1847 - 22 - 300, right = 1847 - 22 }
		T.expect(HudStack.belowMenu(tracker.left, tracker.right, 392, menu)).toBe(423 + HudStack.GAP)
		-- already under it, or beside it (the left half of the screen), or no menu measured: where the player put it
		T.expect(HudStack.belowMenu(tracker.left, tracker.right, 500, menu)).toBe(500)
		T.expect(HudStack.belowMenu(20, 320, 100, menu)).toBe(100)
		T.expect(HudStack.belowMenu(tracker.left, tracker.right, 392, nil)).toBe(392)
		local drag = fs.readFile("src/client/UI/HudDrag.luau")
		T.expect(string.find(drag, "HudStack.belowMenu(", 1, true) ~= nil).toBe(true)
		-- the tracker steps out of sight under any open window (the backpack stood beside it)
		local source = fs.readFile("src/client/UI/Screens/Hud/QuestTracker.luau")
		T.expect(string.find(source, "use(HudCover.Open)", 1, true) ~= nil).toBe(true)
		-- final UI review 2026-11-10 (a service window with its backpack left the column's panels and the party rows
		-- half in sight beside it): the event panels, the arena's teams and the party rows step out of sight under a
		-- window that covers them and keep their slots
		T.expect(string.find(drag, "HudCover.bind(scope, frame, props.Visible)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(drag, "Visible = props.Visible", 1, true)).toBeNil()
		for _, path in { "src/client/UI/Screens/Hud/ArenaTeams.luau", "src/client/UI/Screens/PartyFrames.luau" } do
			T.expect(string.find(fs.readFile(path), "HudCover%.bind%(%s*scope,%s*root,") ~= nil).toBe(true)
		end
		-- the travel screen switches itself off when its fade ends (it stayed on, drawn over every window)
		local world = fs.readFile("src/client/Controllers/WorldController.luau")
		T.expect(string.find(world, "fade.Completed:Connect", 1, true) ~= nil).toBe(true)
		-- and never stays over the character select (Studio check 2026-10-31, after a character switch)
		T.expect(string.find(world, '~= "playing" and loadingGui and loadingGui.Enabled', 1, true) ~= nil).toBe(true)
	end)

	T.it("UI plan phase 4: one spacing grid, a smaller portrait", function()
		-- Theme's numbers are the grid's (the HUD's margin, the gap between its elements, a HUD button)
		local theme = fs.readFile("src/client/UI/Theme.luau")
		local function number(block: string, key: string): number
			local start = assert(string.find(theme, block, 1, true))
			return tonumber(string.match(theme, `{key} = (%d+)`, start)) :: number
		end
		T.expect(number("Theme.Padding = {", "Large")).toBe(HudStack.MARGIN)
		T.expect(number("Theme.Padding = {", "Small")).toBe(HudStack.GAP)
		T.expect(number("Theme.Size = {", "IconButton")).toBe(HudStack.ICON)
		-- the column and the corner's buttons stand as far from the edge as the minimap above them
		T.expect(HudStack.MAIL.right).toBe(HudStack.MARGIN)
		T.expect(HudStack.PVP.right).toBe(HudStack.MARGIN)
		T.expect(HudStack.column(false, false, 1920, 1080, 0).x).toBe(1920 - HudStack.MARGIN)
		-- the portrait: about 340 x 110 (it was 400 x 136); the "Auto" button GAP right of it, on its bottom edge; a touch
		-- screen's column under its effects row
		T.expect(HudStack.PORTRAIT.w).toBe(340)
		T.expect(HudStack.PORTRAIT.h).toBe(110)
		T.expect(HudStack.EXTRAS.x).toBe(HudStack.MARGIN + HudStack.PORTRAIT.w + HudStack.GAP)
		T.expect(HudStack.EXTRAS.y + HudStack.EXTRAS.h).toBe(HudStack.MARGIN + HudStack.PORTRAIT.h)
		T.expect(HudStack.TOUCH_TOP).toBe(22 + 110 + 8 + 44 + 8)
		T.expect(HudStack.PARTY_TOP >= HudStack.TOUCH_TOP).toBe(true)
		-- the HUD draws them from here (no copy of the old numbers left)
		local hud = fs.readFile("src/client/UI/Screens/Hud/init.luau")
		T.expect(string.find(hud, "Size = UDim2.fromOffset(PORTRAIT.w, PORTRAIT.h)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(hud, "400 + 12", 1, true)).toBeNil()
		local party = fs.readFile("src/client/UI/Screens/PartyFrames.luau")
		T.expect(string.find(party, "HudStack.PARTY_TOP", 1, true) ~= nil).toBe(true)
		-- one caption under the minimap
		local minimap = fs.readFile("src/client/UI/Screens/Hud/Minimap.luau")
		T.expect(string.find(minimap, '"AreaName"', 1, true)).toBeNil()
	end)

	T.it("Studio check of phase 4: the right column stands MARGIN inside the screen at small viewports", function()
		-- 1108 x 576 (scale 0.6): the tracker's right edge stood 3 px past the screen's edge
		for _, v in { { 1108, 576 }, { 1024, 576 }, { 1280, 593 }, { 1366, 657 } } do
			for _, inset in { UiScale.TOP_BAR, 36 } do
				local w, h = UiScale.hud(v[1], v[2], false, inset)
				for _, name in SCENARIOS do
					for _, waiting in { false, true } do
						local boxes = scenario(name, false, w)
						for id, r in HudStack.layout(false, false, w, h, 0, boxes, nil, false, waiting) do
							if
								boxes[id]
								and boxes[id].custom == nil
								and (r.right > w - HudStack.MARGIN or r.left < 0)
							then
								error(`{v[1]} x {v[2]} {name}: {id} {show(r)} past the margin of {w}`)
							end
						end
					end
				end
			end
		end
		-- the HUD lays out in the part of its layer that is on the screen, and its frames take that size
		local ui = fs.readFile("src/client/Controllers/UIController.luau")
		T.expect(string.find(ui, "Scale.SetHudArea(hudArea(root))", 1, true) ~= nil).toBe(true)
		for _, path in { "src/client/UI/Screens/Hud/init.luau", "src/client/UI/HudGate.luau" } do
			T.expect({ path, string.find(fs.readFile(path), "use(Scale.HudSize)", 1, true) ~= nil })
				.toEqual({ path, true })
		end
		-- the tutorial's tile left of a menu button keeps clear of the whole menu (the minimap under the row): the
		-- controller passes the menu as measured, Logic/TutorialTile (UI plan package A) goes left of it
		local tutorial = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(tutorial, "Fusion.peek(HudSlots.Menu)", 1, true) ~= nil).toBe(true)
		local tile = fs.readFile("src/shared/Logic/TutorialTile.luau")
		T.expect(string.find(tile, "edge = math.min(edge, menu.left)", 1, true) ~= nil).toBe(true)
	end)

	T.it("Studio check of phase 4: a moved element ends MARGIN inside the screen like the built-in column", function()
		-- the tracker the owner moved at 1462 x 793 (2026-10-22: 1675 of a 1991 wide HUD, a share of 0.8413), seen at
		-- 1108 x 576 (scale 0.6): HudLayout.place put its 300 px 3 screen px past the right edge
		local w, h = UiScale.hud(1108, 576, false, UiScale.TOP_BAR)
		local x = HudLayout.place({ x = 1675 / 1991, y = 0.4 }, 300, w, h)
		T.expect(x + 300 > w).toBe(true)
		local inside = HudStack.insideX(x, 300, w)
		T.expect(math.abs(inside + 300 - (w - HudStack.MARGIN)) < 1e-6).toBe(true)
		-- the built-in column ends at the same place
		local column = HudStack.column(false, false, w, h, 0)
		T.expect(column.right).toBe(true)
		T.expect(column.x).toBe(w - HudStack.MARGIN)
		-- the left edge too; a place inside the margins stays; an element wider than the room keeps its own place
		T.expect(HudStack.insideX(-40, 300, w)).toBe(HudStack.MARGIN)
		T.expect(HudStack.insideX(700, 300, w)).toBe(700)
		T.expect(HudStack.insideX(-40, w, w)).toBe(-40)
		local drag = fs.readFile("src/client/UI/HudDrag.luau")
		T.expect(string.find(drag, "x = HudStack.insideX(x, w, screen.X)", 1, true) ~= nil).toBe(true)
	end)

	T.it("the PvP badge stays on the screen, right-aligned with the toggle", function()
		local f = HudStack.fixed(false, 1920, 1080)
		T.expect(f.pvpBadge.right).toBe(f.pvp.right)
		T.expect(f.pvpBadge.right <= 1920).toBe(true)
	end)
end)

T.describe("HUD column folds (UI plan package A, owner 2026-11-10)", function()
	-- a seeded random generator (Lune's math.random is not seeded the same everywhere)
	local function lcg(seed: number): (number, number) -> number
		local state = seed
		return function(low: number, high: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return low + state % (high - low + 1)
		end
	end

	T.it(
		"L4: 500 random columns never pass the floor; folded and hidden ids are returned, the chip counts them",
		function()
			local rand = lcg(20261110)
			for case = 1, 500 do
				local right = rand(0, 1) == 1
				local top = rand(40, 400)
				local floor = top + rand(60, 700)
				local column: HudStack.Column = {
					x = if right then 1898 else 22,
					right = right,
					top = top,
					floor = floor,
					width = 300,
					chip = if rand(0, 1) == 1 then HudStack.CHIP else PhoneHud.CHIP,
					spares = if rand(0, 2) == 0 then { if right then 1590 else 330 } else nil,
					spareTop = top + rand(0, 80),
				}
				local items: { HudStack.Item } = {}
				local count = rand(1, 7)
				for i = 1, count do
					local tracker = i == count and rand(0, 3) > 0
					local h = rand(32, 260)
					table.insert(items, {
						id = `e{i}`,
						w = if tracker then 300 else rand(200, 280),
						h = h,
						grow = tracker,
						least = if tracker then math.min(h, HudStack.TRACKER_MIN) else nil,
						line = if rand(0, 4) > 0
							then math.min(h, if tracker then HudStack.TRACKER_LEAST else 32)
							else nil,
						keep = rand(0, 9) == 0,
					})
				end
				local fixed: { Rect } = {}
				if rand(0, 2) == 0 then
					-- a moved element in the lane
					local y = rand(top, floor)
					local x = if right then 1898 - 300 else 22
					table.insert(fixed, { left = x, top = y, right = x + 300, bottom = y + rand(20, 200) })
				end
				local placed = HudStack.place(items, column, fixed)
				local where = `case {case}`
				local seen: { [string]: boolean } = {}
				local others: { Rect } = table.clone(fixed)
				if placed.chip then
					table.insert(others, placed.chip)
				end
				for _, item in items do
					local r = placed.rects[item.id]
					local hidden = table.find(placed.hidden, item.id) ~= nil
					T.expect({ where, item.id, r == nil }).toEqual({ where, item.id, hidden })
					if r then
						seen[item.id] = true
						if r.bottom > floor + 1e-6 or r.top < math.min(top, column.spareTop or top) - 1e-6 then
							error(`{where}: {item.id} {show(r)} leaves the column {top}..{floor}`)
						end
						local folded = table.find(placed.folded, item.id) ~= nil
						local least = if folded then item.line or item.h else math.min(item.h, item.least or item.h)
						T.expect({ where, item.id, r.bottom - r.top >= least - 1e-6 }).toEqual({ where, item.id, true })
						for _, o in others do
							if HudStack.overlaps(r, o) then
								error(`{where}: {item.id} {show(r)} meets {show(o)}`)
							end
						end
						table.insert(others, r)
					end
				end
				-- the '+N' chip shows exactly while something is hidden, inside the column
				T.expect({ where, placed.chip ~= nil }).toEqual({ where, #placed.hidden > 0 })
				local chip = placed.chip
				if chip and floor - top >= (column.chip :: HudStack.Size).h then
					T.expect({ where, chip.bottom <= floor + 1e-6, chip.top >= top - 1e-6 })
						.toEqual({ where, true, true })
				end
			end
		end
	)

	T.it(
		"the fold order: least height, the lowest panel's line, the tracker's header, then '+N' from the lowest",
		function()
			local column: HudStack.Column =
				{ x = 1898, right = true, top = 356, floor = 830, width = 300, chip = HudStack.CHIP }
			local function items(): { HudStack.Item }
				return {
					{ id = "worldBoss", w = 280, h = 211, line = 32 },
					{ id = "worldEvent", w = 280, h = 160, line = 32 },
					{ id = "bloodMoon", w = 280, h = 120, line = 32 },
					{ id = "questTracker", w = 300, h = 200, grow = true, least = HudStack.TRACKER_MIN, line = 45 },
				}
			end
			-- 516 px: the tracker keeps its header and two lines, the lowest panel folds, the others stay open
			column.floor = 356 + 211 + 160 + 32 + HudStack.TRACKER_MIN + 3 * HudStack.GAP
			local placed = HudStack.place(items(), column, {})
			T.expect(placed.folded).toEqual({ "bloodMoon" })
			T.expect(placed.hidden).toEqual({})
			T.expect(placed.rects.bloodMoon.bottom - placed.rects.bloodMoon.top).toBe(32)
			T.expect(placed.rects.questTracker.bottom).toBe(column.floor)
			-- 300 px: every panel folds, the tracker keeps its header and two lines
			column.floor = 356 + 300
			placed = HudStack.place(items(), column, {})
			T.expect(placed.folded).toEqual({ "worldBoss", "worldEvent", "bloodMoon" })
			T.expect(placed.hidden).toEqual({})
			T.expect(placed.rects.questTracker.bottom - placed.rects.questTracker.top >= HudStack.TRACKER_MIN)
				.toBe(true)
			-- 160 px: the tracker folds to its header after the panels, then the lowest go behind '+N' (the chip at the floor)
			column.floor = 356 + 160
			placed = HudStack.place(items(), column, {})
			T.expect(#placed.hidden > 0).toBe(true)
			T.expect(placed.hidden[#placed.hidden]).toBe("questTracker")
			local chip = assert(placed.chip, "a '+N' chip")
			T.expect(chip.bottom).toBe(column.floor)
			T.expect(chip.right).toBe(column.x)
			for _, id in placed.hidden do
				T.expect(placed.rects[id]).toBeNil()
			end
			-- the first panel stays (folded) above the chip
			T.expect(placed.rects.worldBoss ~= nil).toBe(true)
			T.expect(placed.rects.worldBoss.bottom <= chip.top - HudStack.GAP).toBe(true)
			-- an element the player took from the '+N' list folds and hides after the others
			local kept = items()
			kept[4].keep = true
			placed = HudStack.place(kept, column, {})
			T.expect(placed.rects.questTracker ~= nil).toBe(true)
			T.expect(placed.hidden).toEqual({ "worldEvent", "bloodMoon" })
		end
	)

	T.it("the '+N' list names every element of the column in pl and en, with the game's own words", function()
		for _, id in HudStack.ORDER do
			for _, lang in { "pl", "en" } do
				local key = `hud.stack.{id}`
				T.expect({ key = key, lang = lang, has = Locale.has(key, lang) }).toEqual({
					key = key,
					lang = lang,
					has = true,
				})
			end
			-- package A review: the English list said "Tourney", a word the game uses nowhere else
			local en = Locale.T(`hud.stack.{id}`, nil, "en")
			T.expect({ id = id, tourney = string.find(en, "Tourney", 1, true) ~= nil }).toEqual({
				id = id,
				tourney = false,
			})
		end
		T.expect(Locale.T("hud.stack.tourney", nil, "en")).toBe("Tournament")
	end)

	T.it("1280 x 720 with every panel, the guide and the waiting row: panels fold, then '+N'; Z6 stays free", function()
		local w, h = UiScale.hud(1280, 720, false, UiScale.TOP_BAR)
		local panel = HudStack.PANEL_PC
		local line = HudStack.LINE_PC
		local boxes: { [string]: Box } = {
			arena = box(HudStack.ARENA_PILL, 36),
			worldBoss = box(panel, 211, nil, line),
			worldEvent = box(panel, 160, nil, line),
			bloodMoon = box(panel, 120, nil, line),
			tourney = box(panel, 140, nil, line),
			elite = box(HudStack.ELITE, 32 + 3 * 44),
			questTracker = box(HudStack.TRACKER, HudStack.TRACKER_MIN, nil, HudStack.TRACKER_LEAST),
		}
		local placed = HudStack.arrange(false, false, w, h, 0, boxes, nil, true, true)
		local column = HudStack.column(false, false, w, h, 0, true, true)
		T.expect(#placed.folded > 0).toBe(true)
		local corner = HudStack.cornerTop(false, w, h)
		for id, r in placed.rects do
			T.expect({ id, r.bottom <= column.floor + 1e-6 }).toEqual({ id, true })
			-- the PC corner under the floor (the card slot, Logic/HudZones Z6) keeps clear
			T.expect({ id, r.bottom <= corner - HudStack.GAP + 1e-6 }).toEqual({ id, true })
			-- the spare columns start under the message zone
			if r.right <= column.x - HudStack.TRACKER then
				T.expect({ id, r.top >= h * HudStack.MESSAGE_BOTTOM }).toEqual({ id, true })
			end
		end
		local chip = placed.chip
		if chip then
			T.expect(chip.bottom <= column.floor + 1e-6).toBe(true)
		end
		-- every panel is still there: open, folded to its line, or listed behind '+N'
		for id in boxes do
			if id ~= "elite" then
				local listed = table.find(placed.hidden, id) ~= nil
				T.expect({ id, placed.rects[id] ~= nil or listed }).toEqual({ id, true })
			end
		end
	end)
end)

return nil
