--!strict
-- UI plan phase 2 (owner 2026-10-31: "too much information and too many options on one screen"; plan §3, one queue
-- of messages): the band at the top centre of the screen shows its messages one under another instead of on top of
-- each other: the toasts under the lowest banner that shows (toastTop), at most MAX_TOASTS at once, the achievement
-- waiting while the zone or area banner shows (achievementWaits), clear of Roblox's top bar and an open window's title
-- bar (underBars, underHeader) and of the tutorial's tile (toastShift), never moving up while they show (holdTop).
-- All numbers are virtual pixels of UI/Scale from the top of the screen.
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the band moves
-- under the target (owner question 2): `slots` places the alert, the banner, the toasts and the prompt top down in
-- Logic/HudZones.messageZone (a phone's M zone), a PC card in HudZones.cardSlot and the bark in HudZones.barkSlot,
-- all in the whole screen's pixels (the Toasts layer); UI/Notify asks it where its queue's entries (Logic/NoticeQueue,
-- which also decides which banner and how many toasts show) stand. With a window open (owner 2026-10-31, question
-- UI 8) a message stands over the window where it fits there, else under its title bar, never on it, and never waits
-- for the window to close. The phase 2 functions keep their signatures (the plan); the client places through `slots`.

local HudZones = require("./HudZones")
local PhoneHud = require("./PhoneHud")

local TopBand = {}

export type Id = "achievement" | "announcement" | "area" | "zone"
export type Shown = { [string]: boolean }
export type Rect = { left: number, top: number, right: number, bottom: number }

TopBand.GAP = 8
TopBand.TOAST_TOP = 90 -- the toasts' own place under the target frame
TopBand.MAX_TOASTS = 2 -- was 4
TopBand.TOAST_WIDTH = 520 -- Components/Toast
TopBand.TOAST_BAND = 2 * 64 + 8 -- about as tall as MAX_TOASTS toasts of two lines
TopBand.EDGE = 16 -- the toasts never move closer than this to the layer's side

-- Where each banner stands while it shows (its top and bottom edge; the area banner with its profile line, the
-- achievement toast at its PC size, the larger of the two; the server's announcement, Components/Announcement, from
-- the top of its ordinary banner to the bottom of its larger mythic one). `hud`: the banner stands in the HUD's layer,
-- which starts under Roblox's top bar (UI/Scale.TopBar); the toasts, the achievement toast and the announcement stand
-- in the Toasts layer, which covers the whole screen.
TopBand.BANNERS = table.freeze({
	achievement = table.freeze({ top = 64, bottom = 64 + 104 }),
	announcement = table.freeze({ top = 130 - 64 / 2, bottom = 150 + 84 / 2 }),
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

-- Whether the achievement toast waits before it slides in: while the zone or the area banner shows, or the server's
-- announcement (Studio check of phase 4: the two stood at the same height, one over the other).
function TopBand.achievementWaits(shown: Shown): boolean
	return shown.zone == true or shown.area == true or shown.announcement == true
end

-- Studio check of phase 4: whether the server's announcement waits before it slides in: while the achievement toast
-- shows (each waits for the other; the first to show keeps the band).
function TopBand.announcementWaits(shown: Shown): boolean
	return shown.achievement == true
end

-- Studio check of phase 4 (1108 x 576: a toast under the zone banner jumped 156 px up for its last moments when the
-- banner went): the top of the toasts' column wanted at `top`, while toasts show (`showing`) in a column that stood at
-- `held`: it never moves up while toasts show (down at once, for a banner that comes), and takes its own place again
-- once none shows.
function TopBand.holdTop(top: number, held: number?, showing: boolean): number
	if showing and held and held > top then
		return held
	end
	return top
end

-- Package B ------------------------------------------------------------------------------------------------------

-- An open window in the whole screen's pixels, with its title bar's height.
export type Window = { left: number, top: number, right: number, bottom: number, header: number }
-- A message of the band: its id, width and height.
export type Item = { id: string, w: number, h: number }
export type Device = "pc" | "tablet" | "phone"
-- What `slots` lays out. w x h: the whole screen (the Toasts layer) in virtual pixels; bar: Roblox's top bar in virtual
-- pixels (UI/Scale.TopBar / scale), where the HUD's layer starts; hud: what the HUD shows (PC and tablet);
-- items: the band's messages top down (the alert, the banner, the toasts, the prompt; a tablet's card last);
-- held: the tops the shown items had (an item never moves up while it shows, holdTop); card: a PC card's kind;
-- bark: the PC bark; keep: the tutorial's tile; modals: the open modal dialogs (a message never stands on one).
export type Context = {
	w: number,
	h: number,
	bar: number,
	device: Device,
	hud: HudZones.State?,
	windows: { Window }?,
	keep: Rect?,
	modals: { Rect }?,
	items: { Item },
	held: { [string]: number }?,
	card: HudZones.CardKind?,
	bark: boolean?,
}

-- What the client knows when it lays the band out (UI/Notify): the Toasts layer's root in real pixels, the UI scale,
-- Roblox's top bar in real pixels (UI/Scale.TopBar) and what the HUD shows: the dungeon boss bar, the arena's panel in
-- the band (arenaState) and the party members besides the player.
export type Facts = {
	layerW: number,
	layerH: number,
	scale: number,
	topBar: number,
	device: Device,
	boss: boolean?,
	arena: HudZones.ArenaState?,
	party: number?,
}

-- Review 2026-11-10 of package B: the context `slots` lays out, from the client's facts. The size is the Toasts
-- layer's own (DeviceSafeInsets: a phone's notch and home bar are not in it), not the whole viewport's (UI/Scale.
-- VirtualSize): measured from the viewport, M stood 47 px right of the target on an 844 x 390 phone and its bottom
-- below the mail button. The party moves the PC bark's slot down under its rows, the arena's return panel moves the
-- zone down under it, as the match panel does.
function TopBand.context(f: Facts): Context
	local k = if f.scale > 0 then f.scale else 1
	return {
		w = f.layerW / k,
		h = f.layerH / k,
		bar = math.max(0, f.topBar) / k,
		device = f.device,
		hud = { bossBar = f.boss == true, arena = f.arena, party = f.party },
		items = {},
	}
end

-- The arena's state in the band from the state branch `arenaLive`: "match" while a match runs (Hud/ArenaPanel's
-- panel), "return" while the way back from an arena server shows (`returnAt`), else nil.
function TopBand.arenaState(live: any): HudZones.ArenaState?
	if type(live) ~= "table" then
		return nil
	end
	if type(live.match) == "table" then
		return "match"
	end
	if tonumber(live.returnAt) ~= nil then
		return "return"
	end
	return nil
end
-- Where things stand: the zone, each placed item by id (one that has no room is missing: it waits), the card, the bark.
export type Placed = { zone: Rect, rects: { [string]: Rect }, card: Rect?, bark: Rect? }

-- The band's own sizes (virtual pixels): the alert line (as tall as HudZones.MESSAGE.alert), the banner (the
-- legendary one; the mythic and world boss one is BANNER_BIG), the prompt (Components/Prompt), a phone's line.
TopBand.ALERT_W = 640
TopBand.BANNER = table.freeze({ w = 900, h = 64 })
TopBand.BANNER_BIG = table.freeze({ w = 980, h = 84 })
TopBand.PROMPT = table.freeze({ w = 460, h = 64 })
-- A phone's M zone (UI plan zone map): 4 under the target frame, at most 114 tall (to the guide bar's bottom), never
-- closer than GAP to the mail button or the right column (minimap, ☰, PvP). `line`: a message there is never taller
-- than M (review 2026-11-10: the first one reached 30 px past M onto the mail button and the skill arc; its text is
-- cut at the end and opens whole with a tap), and M is never shorter than one HUD line (Theme.Size.HudLine).
TopBand.PHONE_M = table.freeze({ gap = 4, h = 114, line = 52 })
local RIGHT_COLUMN = { "minimap", "menuToggle", "pvp", "pvpBadge" }

local function meets(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end
TopBand.meets = meets

local function down(r: Rect, dy: number): Rect
	return { left = r.left, top = r.top + dy, right = r.right, bottom = r.bottom + dy }
end

-- A phone's M zone on its HUD layer (w x h virtual pixels): one message at a time, over the target's effects, the cast
-- line and the guide bar (they stand in it), from Logic/PhoneHud's places.
function TopBand.phoneZone(w: number, h: number): Rect
	local function at(name: string): Rect?
		local place = PhoneHud.place(name)
		if not place then
			return nil
		end
		local r = PhoneHud.rect(place, w, h)
		return { left = r.left, top = r.top, right = r.right, bottom = r.bottom }
	end
	local target = at("target") or { left = TopBand.EDGE, top = 0, right = w / 2, bottom = TopBand.EDGE }
	local top = target.bottom + TopBand.PHONE_M.gap
	local bottom = top + TopBand.PHONE_M.h
	local mail = at("mail")
	if mail then
		bottom = math.min(bottom, mail.top - TopBand.GAP)
	end
	local right = w - TopBand.GAP
	for _, name in RIGHT_COLUMN do
		local r = at(name)
		if r and r.top < bottom and r.bottom > top then
			right = math.min(right, r.left - TopBand.GAP)
		end
	end
	return { left = target.left, top = top, right = math.max(target.left, right), bottom = math.max(top, bottom) }
end

-- The HUD's state on this device (a tablet takes the PC zones with its touch corner).
local function hudState(ctx: Context): HudZones.State
	local state: HudZones.State = if ctx.hud then table.clone(ctx.hud) else {}
	state.touch = ctx.device == "tablet"
	return state
end

-- The dungeon boss bar (Controllers/DungeonController) on a HUD layer w x h: on PC and a tablet its place in the
-- target band (Logic/HudZones, the plan's 600..1320 x 22..134 at 1920 wide); on a phone a strip PHONE_BOSS_H tall
-- across the centre column, M's width (between the left column and the minimap's), PHONE_M.gap under the target row:
-- the HP fills it, the name, the phase and the time stand in it, the channel to break covers it while it runs; M starts
-- under it. Review 2026-11-10: min(720, w - 16) wide and 64 tall it stood over the portrait, the Auto toggles, the
-- minimap, ☰ and PvP, and left M 24 px on an 844 x 390 phone.
TopBand.PHONE_BOSS_H = 20
function TopBand.bossBar(device: Device, w: number, h: number): Rect
	if device ~= "phone" then
		local r = HudZones.pc(w, h, { bossBar = true, touch = device == "tablet" }).bossBar
		if r then
			return { left = r.left, top = r.top, right = r.right, bottom = r.bottom }
		end
	end
	local m = TopBand.phoneZone(w, h)
	return { left = m.left, top = m.top, right = m.right, bottom = m.top + TopBand.PHONE_BOSS_H }
end

-- The message zone (PC, tablet) or M (phone) in the whole screen's pixels, never closer than GAP to Roblox's top bar.
function TopBand.zone(ctx: Context): Rect
	local hh = ctx.h - ctx.bar
	local zone: Rect
	if ctx.device == "phone" then
		zone = TopBand.phoneZone(ctx.w, hh)
		-- a phone's boss bar stands under the target row: M starts under it
		if ctx.hud and ctx.hud.bossBar then
			local boss = TopBand.bossBar("phone", ctx.w, hh)
			zone.top = math.max(zone.top, boss.bottom + TopBand.PHONE_M.gap)
			zone.bottom = math.max(zone.bottom, zone.top)
		end
	else
		local r = HudZones.messageZone(ctx.w, hh, hudState(ctx))
		zone = { left = r.left, top = r.top, right = r.right, bottom = r.bottom }
	end
	zone = down(zone, ctx.bar)
	zone.top = math.max(zone.top, ctx.bar + TopBand.GAP)
	zone.bottom = math.max(zone.bottom, zone.top)
	return zone
end

-- Places the band's items top down in the zone, each centred and at most as wide as the zone, GAP apart:
-- - an open window: an item stands over it where the whole item fits GAP above its top, else under its title bar
--   (the stack goes on there with the zone's height again); it never touches a title bar (owner 2026-10-31);
-- - the tutorial's tile: an item that would meet it moves beside it where it fits in the zone (toastShift: the tile
--   points at a button and keeps its place), else under it;
-- - an item never moves up while it shows (`held`, holdTop);
-- - an item with no room left is missing from the result (it waits in Logic/NoticeQueue); the first always has room
--   (on PC and a tablet it may reach below a zone shorter than itself; a phone's item is cut to M's height instead);
-- - an open modal dialog: an item that would meet it waits (review 2026-11-10: the Modals layer stands under the
--   Toasts layer, so a toast covered a question's buttons).
-- A PC card stands in HudZones.cardSlot and the bark in HudZones.barkSlot, each unless a window, the tile or a modal
-- covers its place (then it waits).
function TopBand.slots(ctx: Context): Placed
	local zone = TopBand.zone(ctx)
	local windows: { Window } = ctx.windows or {}
	local tile = ctx.keep
	local blocks: { Rect } = {}
	for _, win in windows do
		table.insert(blocks, { left = win.left, top = win.top, right = win.right, bottom = win.top + win.header })
	end
	if tile then
		table.insert(blocks, tile)
	end
	local width = zone.right - zone.left
	local height = math.max(0, zone.bottom - zone.top)
	local screenFloor = ctx.h - TopBand.GAP
	local phone = ctx.device == "phone"
	-- a phone's items are at most M tall (M is at least a HUD line on the phones of Logic/PhoneHud.DEVICES)
	local tallest = if phone then math.max(height, TopBand.PHONE_M.line) else math.huge
	local limit = zone.bottom
	local first = ctx.items[1]
	if first then
		limit = math.max(limit, zone.top + math.min(first.h, tallest))
	end
	local modals: { Rect } = ctx.modals or {}
	local function onModal(r: Rect): boolean
		for _, m in modals do
			local around = {
				left = m.left - TopBand.GAP,
				top = m.top - TopBand.GAP,
				right = m.right + TopBand.GAP,
				bottom = m.bottom + TopBand.GAP,
			}
			if meets(r, around) then
				return true
			end
		end
		return false
	end
	-- where `rect` has to go down to (nil: it is free), and whether a window is in the way (else only the tile)
	local function hit(rect: Rect): (number?, boolean)
		local under: number? = nil
		local window = false
		for i, b in blocks do
			local around = {
				left = b.left - TopBand.GAP,
				top = b.top - TopBand.GAP,
				right = b.right + TopBand.GAP,
				bottom = b.bottom + TopBand.GAP,
			}
			if meets(rect, around) then
				under = math.max(under or -math.huge, b.bottom + TopBand.GAP)
				window = window or i <= #windows
			end
		end
		for _, win in windows do
			local below = win.top + win.header + TopBand.GAP
			local body = { left = win.left, top = win.top - TopBand.GAP, right = win.right, bottom = win.bottom }
			if rect.top < below and meets(rect, body) then
				under = math.max(under or -math.huge, below)
				window = true
			end
		end
		return under, window
	end
	-- beside the tile, as toastShift moves a column centred on the screen (here: on the zone), inside the zone
	local function beside(rect: Rect): Rect?
		if not tile then
			return nil
		end
		local off = (zone.left + zone.right - ctx.w) / 2
		local w = rect.right - rect.left
		local moved = { left = tile.left - off, top = tile.top, right = tile.right - off, bottom = tile.bottom }
		local shift = TopBand.toastShift(ctx.w, w, rect.top, moved)
		local side = { left = rect.left + shift, top = rect.top, right = rect.right + shift, bottom = rect.bottom }
		if shift == 0 or side.left < zone.left - 1e-6 or side.right > zone.right + 1e-6 or hit(side) ~= nil then
			return nil
		end
		return side
	end
	local cursor = zone.top
	local rects: { [string]: Rect } = {}
	local held = ctx.held or {}
	for _, item in ctx.items do
		local w = math.min(item.w, width)
		local h = math.min(item.h, tallest)
		local left = (zone.left + zone.right) / 2 - w / 2
		local top = TopBand.holdTop(cursor, held[item.id], held[item.id] ~= nil)
		local placed: Rect? = nil
		for _ = 1, 2 * (#blocks + #windows) + 1 do
			local rect = { left = left, top = top, right = left + w, bottom = top + h }
			local under, window = hit(rect)
			if under == nil then
				placed = rect
				break
			end
			local side = if window then nil else beside(rect)
			if side then
				placed = side
				break
			end
			-- under a title bar or the tile the stack has the zone's height again
			limit = math.max(limit, (under :: number) + math.max(height, h))
			top = under :: number
		end
		if placed and placed.bottom <= math.min(limit, screenFloor) and not onModal(placed) then
			rects[item.id] = placed
			cursor = placed.bottom + TopBand.GAP
		end
	end
	local out: Placed = { zone = zone, rects = rects }
	local function free(r: Rect): boolean
		for _, win in windows do
			if meets(r, win) then
				return false
			end
		end
		return not (ctx.keep and meets(r, ctx.keep :: Rect)) and not onModal(r)
	end
	if ctx.device == "pc" then
		local hh = ctx.h - ctx.bar
		if ctx.card then
			local card = down(HudZones.cardSlot(ctx.w, hh, ctx.card), ctx.bar)
			out.card = if free(card) then card else nil
		end
		if ctx.bark then
			local slot = HudZones.barkSlot(hudState(ctx))
			local bark = if slot then down(slot, ctx.bar) else nil
			out.bark = if bark and free(bark) then bark else nil
		end
	end
	return out
end

return table.freeze(TopBand)
