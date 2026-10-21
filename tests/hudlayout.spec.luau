--!strict
-- S156: the player's HUD layout (Logic/HudLayout): what a client may save and where a moved element lands.
-- Owner 2026-10-21: the HUD column and the bottom-right corner (Logic/HudStack): at the common screen sizes the quest
-- tracker, the event panels, the arena pill, the Elite II timers, the mail, PvP and attack buttons never overlap.

local HudLayout = require("../src/shared/Logic/HudLayout")
local HudStack = require("../src/shared/Logic/HudStack")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")

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

local function box(w: number, h: number, custom: Rect?): Box
	return { shown = true, w = w, h = h, custom = custom }
end

-- The column's elements of a scenario on a w x h screen (panel widths per device; heights: the world boss panel at
-- its tallest on PC, standing at the barrow on a touch screen, folded to its line, a world event panel, the Elite II
-- timers' header and rows).
local function scenario(name: string, touch: boolean, w: number): { [string]: Box }
	local panel = if touch then HudStack.PANEL_TOUCH else HudStack.PANEL_PC
	local pill = if touch then 44 else 36
	local boss = if touch then 130 else 211
	local event = if touch then 120 else 160
	local tracker = box(HudStack.TRACKER, HudStack.TRACKER_MIN)
	local top = if touch then HudStack.TOUCH_TOP else HudStack.RIGHT_TOP
	if name == "tracker" then
		return { questTracker = tracker }
	elseif name == "bossLine" then
		return { worldBoss = box(panel, 40), questTracker = tracker }
	elseif name == "bossAndEvent" then
		return { worldBoss = box(panel, boss), worldEvent = box(panel, event), questTracker = tracker }
	elseif name == "busy" then
		if touch then
			return {
				arena = box(HudStack.ARENA_PILL, pill),
				worldBoss = box(panel, 40),
				elite = box(HudStack.ELITE, 32 + 44),
				questTracker = tracker,
			}
		end
		return {
			arena = box(HudStack.ARENA_PILL, pill),
			worldBoss = box(panel, 40),
			worldEvent = box(panel, event),
			elite = box(HudStack.ELITE, 32 + 3 * 44),
			questTracker = tracker,
		}
	elseif name == "movedTracker" then
		-- the tracker dragged onto its own built-in place (or only scaled there): the boss panel goes round it
		local left = if touch then HudStack.MARGIN else w - HudStack.MARGIN - HudStack.TRACKER
		local tall = if touch then 120 else 300
		local moved = { left = left, top = top, right = left + HudStack.TRACKER, bottom = top + tall }
		return { worldBoss = box(panel, boss), questTracker = box(HudStack.TRACKER, tall, moved) }
	elseif name == "movedBoss" then
		local left = if touch then HudStack.MARGIN else w - HudStack.MARGIN - panel
		local moved = { left = left, top = top, right = left + panel, bottom = top + 120 }
		return { worldBoss = box(panel, 120, moved), worldEvent = box(panel, 160), questTracker = tracker }
	end
	error(name)
end
local SCENARIOS = { "tracker", "bossLine", "bossAndEvent", "busy", "movedTracker", "movedBoss" }

local function show(r: Rect): string
	return `({r.left}, {r.top})-({r.right}, {r.bottom})`
end

-- Every rectangle on the screen: the corner's buttons, the buttons right of the portrait, the moved elements, the PC
-- Elite II timers and the column's places, by name.
local function screen(touch: boolean, w: number, h: number, boxes: { [string]: Box }): { [string]: Rect }
	local all: { [string]: Rect } = table.clone(HudStack.fixed(touch, w, h))
	local e = HudStack.EXTRAS
	all.extras = { left = e.x, top = e.y, right = e.x + e.w, bottom = e.y + e.h }
	for id, b in boxes do
		if b.custom then
			all[id] = b.custom
		elseif id == "elite" and not touch then
			all.elite = HudStack.elite(w, h, b.h)
		end
	end
	for id, r in HudStack.layout(touch, false, w, h, 0, boxes) do
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
				for _, name in SCENARIOS do
					local boxes = scenario(name, touch, w)
					local all = screen(touch, w, h, boxes)
					local where = `{if touch then "touch" else "PC"} {w} x {h} {name}`
					local bad = clashes(all)
					if #bad > 0 then
						error(`{where}: {table.concat(bad, "; ")}`)
					end
					for id, r in all do
						if r.left < 0 or r.top < 0 or r.right > w or r.bottom > h then
							error(`{where}: {id} {show(r)} leaves the screen`)
						end
					end
					-- every shown element has a place of its full height (the tracker: at least its header) above the
					-- column's floor (PC the corner, a touch screen the sprint row)
					local floor = HudStack.column(touch, false, w, h, 0).floor
					for id, b in boxes do
						local r = all[id]
						if not r then
							error(`{where}: {id} has no place`)
						end
						local least = if id == "questTracker" then HudStack.TRACKER_LEAST else b.h
						if not b.custom and (r.bottom - r.top < least - 1e-6 or r.bottom > floor) then
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
		-- under the tracker it has no room left, so the spare column beside it, from the top
		T.expect(places.worldBoss.top).toBe(HudStack.RIGHT_TOP)
		T.expect(places.worldBoss.right <= custom.left - HudStack.GAP).toBe(true)
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

	T.it("a touch screen stacks the column under the portrait and the party, clear of the sprint row", function()
		for _, size in TABLET do
			local w, h = size[1], size[2]
			for others = 0, 4 do
				local places = HudStack.layout(true, false, w, h, others, scenario("tracker", true, w))
				local tracker = places.questTracker
				local top = if others > 0 then HudStack.PARTY_TOP + others * HudStack.PARTY_ROW else HudStack.TOUCH_TOP
				local floor = h - HudStack.TOUCH_ROW - HudStack.GAP
				if top + HudStack.TRACKER_MIN <= floor then
					T.expect(tracker.left).toBe(HudStack.MARGIN)
					T.expect(tracker.top).toBe(top)
				end
				T.expect(tracker.bottom <= floor).toBe(true)
			end
		end
	end)

	T.it("a phone stacks the column in its left stack, clear of every other place", function()
		local tracker = box(PhoneHud.TRACKER_WIDTH, HudStack.TRACKER_MIN)
		for _, d in PhoneHud.DEVICES do
			local w, h = PhoneHud.area(d)
			for _, boxes in
				{ { questTracker = tracker }, { worldBoss = box(PhoneHud.PANEL_WIDTH, 40), questTracker = tracker } }
			do
				local places = HudStack.layout(true, true, w, h, 0, boxes)
				for id, r in places do
					T.expect(r.left).toBe(PhoneHud.PLACES.stack.x)
					T.expect(r.top >= PhoneHud.STACK_TOP).toBe(true)
					T.expect(r.bottom <= h - PhoneHud.STACK_BOTTOM).toBe(true)
					for name, place in PhoneHud.PLACES do
						if name ~= "stack" and HudStack.overlaps(r, PhoneHud.rect(place, w, h)) then
							error(`{d.name}: {id} {show(r)} / {name}`)
						end
					end
				end
			end
		end
	end)

	T.it("the PvP badge stays on the screen, right-aligned with the toggle", function()
		local f = HudStack.fixed(false, 1920, 1080)
		T.expect(f.pvpBadge.right).toBe(f.pvp.right)
		T.expect(f.pvpBadge.right <= 1920).toBe(true)
	end)
end)

return nil
