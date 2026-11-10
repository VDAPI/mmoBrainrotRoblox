--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): the UI
-- plan's HUD zone map as pure rectangles, so every HUD element has one place and a spec can prove that no two places
-- meet. The zones on PC (and on a tablet, a touch screen that is not a phone):
--   Z1 the character (portrait, Auto button, effects row) top left; Z2 the party rows and the NPC bark under it;
--   Z3 the target band top centre (target or dungeon boss bar, the add under the bar, the arena panel);
--   Z8 the message zone under the band (the alert, banner, toasts and prompt of Logic/TopBand);
--   Z4 the menu, minimap, guide bar and "something waits" row top right; Z5 the column of panels under them;
--   Z6 the card slot of the PC corner (a tablet's touch buttons stand there); Z7 the action bar, cast line and EXP
--   bar at the bottom; and the Roblox chat window in the lower left (an estimate: it is Roblox's own CoreGui).
-- Numbers come from today's code, through Logic/HudStack where it already holds them (never copied here); the few
-- that only client files hold are kept below with their file named. The plan's [proposed] places (the Auto popover,
-- the effects cap, the bark slot, the add frame under the boss bar, the arena panel under the target, the card slot)
-- are marked so. A phone's HUD is Logic/PhoneHud's. Nothing reads this module yet: UI package A moves Screens/Hud
-- onto it, package B the message band. All numbers are virtual pixels of the HUD's layer (Screens, which starts under
-- Roblox's top bar), measured from its top-left corner; w x h is that layer's size (`layer`).

local HudMenu = require("./HudMenu")
local HudStack = require("./HudStack")
local PhoneHud = require("./PhoneHud")
local UiScale = require("./UiScale")

local HudZones = {}

export type Rect = HudStack.Rect
export type TargetKind = "none" | "monster" | "player" | "elite"
-- "queue": the arena's queue pill, which stands in the column (HudStack.ORDER "arena"), not in the band
export type ArenaState = "none" | "match" | "return" | "queue"
export type CardKind = "betterItem" | "fight" | "bossReward" | "legend"
export type Device = "pc" | "tablet" | "phone"

-- What the HUD shows. Every field may be left out: no target, no boss bar, no party, nothing waiting.
export type State = {
	touch: boolean?, -- a tablet: touch, not a phone (PhoneHud.compact false); PC zones with the touch corner
	target: TargetKind?, -- the target frame (no boss bar)
	bossBar: boolean?, -- the dungeon boss bar (the boss itself has no target frame)
	add: boolean?, -- with the boss bar: an add or a player is the target, its frame goes under the bar
	arena: ArenaState?,
	party: number?, -- party members besides the player, 0..4
	guide: boolean?, -- the guide bar under the minimap (Hud/NavBar)
	waiting: number?, -- buttons in the "something waits" row (Hud/WaitingRow), 0..4
	column: { number }?, -- heights of the column's shown elements, top down (Logic/HudStack.place lays them out)
	effects: number?, -- the player's own effect icons
	autoPopover: boolean?, -- the Auto popover is open
	scale: number?, -- the screen's UI scale (`layer`): Roblox sizes its chat window in real pixels; default 1
}

-- The places of one HUD state by name. A missing place is not shown in that state (or has no room).
export type Zones = {
	portrait: Rect,
	auto: Rect,
	autoPopover: Rect?,
	effects: Rect,
	party: { Rect },
	bark: Rect?,
	target: Rect?,
	targetEffects: Rect?,
	targetActions: Rect?,
	bossBar: Rect?,
	addFrame: Rect?,
	arenaPanel: Rect?,
	menuBar: Rect,
	minimap: Rect,
	guide: Rect?,
	waiting: Rect?,
	column: Rect?,
	card: Rect?,
	corner: { [string]: Rect },
	castLine: Rect,
	actionBar: Rect,
	expBar: Rect,
	chatEstimate: Rect?,
}

-- One place of `list`: its name ("party2", "corner.attack"), its zone ("Z1".."Z7", "chat") and whether it is an
-- overlay the player opens (it may cover the HUD, never the controls).
export type Named = { name: string, zone: string, rect: Rect, overlay: boolean }

local GAP = HudStack.GAP
local MARGIN = HudStack.MARGIN

-- Z1. [proposed] The Auto popover (Hud/AutoGroup's panel of Lure, Auto Hunt and Auto Potion) opens right of the Auto
-- button, top-aligned with it: today it opens under the button, over the effects row.
HudZones.AUTO_POPOVER = table.freeze({ w = 170, h = 72 })
-- [proposed] At most this many own effect icons, then a '+N' chip (Hud/EffectIcons' frame holds 8 today, more run
-- past it).
HudZones.EFFECTS_CAP = 9

-- Z2. UI/Screens/PartyFrames: WIDTH x HEIGHT, a row every HudStack.PARTY_ROW from HudStack.PARTY_TOP.
HudZones.PARTY_FRAME = table.freeze({ w = 260, h = 58 })
HudZones.PARTY_MAX = 4
-- Hud/BarkToast at its PC size. [proposed] GAP under the last party row: today it stands at x 16, 42 % down the
-- screen, over party rows 3 and 4.
HudZones.BARK = table.freeze({ w = 380, h = 76 })

-- Z3. Hud/TargetFrame: 420 x 92 at the top centre (Theme.Padding.Large down); its effect icons (Hud/EffectIcons at
-- size 26: 26 * 8 + 28 by 26 + 14) stand Theme.Padding.Medium in from its left and 10 under it; a player target's
-- 'Actions' button (120 x MinTouch + 8) stands right of it, Padding.Medium + 8 from its padded edge and its top
-- padding (8) down.
HudZones.TARGET = table.freeze({
	w = 420,
	h = 92,
	effectsInset = 14,
	effectsGap = 10,
	effectsW = 236,
	effectsH = 40,
	actionsW = 120,
	actionsH = 52,
	actionsGap = 8,
	actionsTop = 8,
})
-- Controllers/DungeonController: the boss bar, 720 x 112 centred. The band starts at MARGIN like the target frame
-- (the plan's 22..134, package B moves the bar there; today it stands at 16). [proposed] An add or player target goes
-- GAP under the bar (today the target frame lies under it).
HudZones.BOSS_BAR = table.freeze({ w = 720, h = 112 })
-- Hud/ArenaPanel's PANEL_WIDTH. [proposed] 68 tall, GAP under the target's effects: today the match panel stands at
-- 70 and the return panel at 160, over the target frame.
HudZones.ARENA_PANEL = table.freeze({ w = 420, h = 68 })

-- Z4. Hud/Minimap's frame (SIZE 220 + 44; its height is counted in HudStack.RIGHT_TOP) and Hud/NavBar's WIDTH (the
-- guide bar), both right-aligned in the menu over the minimap (Hud/init).
HudZones.MINIMAP_W = 264
HudZones.GUIDE_W = 264
HudZones.WAITING_MAX = 4

-- Z6. [proposed] The card slot of the PC corner (owner question 1 of the plan, on by default): one card at a time,
-- this wide, bottom-aligned; the height of each kind's one-line summary.
HudZones.CARD_W = 330
HudZones.CARDS = table.freeze({ betterItem = 96, fight = 152, bossReward = 152, legend = 152 } :: { [string]: number })

-- Z7. Hud/init's action bar: SKILL_SLOTS (Data/Skills.HOTBAR_SLOTS) slots of SLOT_SIZE, then a Gap frame
-- (Theme.Padding.Large = MARGIN), Hud/PotionBar (SIZE * 3 + 12: `potions` slots `gap` apart) and, on PC with a mount,
-- MountGap (Padding.Large) and the mount slot; every part `gap` apart (its UIListLayout), the bar 14 +
-- Theme.Padding.Medium over the bottom. The widest bar (with the mount) is the zone.
HudZones.ACTION_BAR = table.freeze({ slots = 10, slot = 56, gap = 6, potions = 3, bottom = 28 })
-- Hud/CastBar: 360 x 26, its bottom 100 over the layer's bottom.
HudZones.CAST_BAR = table.freeze({ w = 360, h = 26, bottom = 100 })
-- Hud/init's EXP bar: the full width less 8, 10 tall, 2 over the bottom.
HudZones.EXP_BAR = table.freeze({ inset = 4, h = 10, bottom = 2 })
-- [inferred] Roblox's chat window, which Hud/ChatDock moves to the lower left on PC: about this many real pixels
-- tall, give or take `spread`; its bottom GAP over the EXP bar (Hud/init: in Studio 2026-10-31 they touched while the
-- bar's top stood 20 over the bottom). A touch screen keeps Roblox's own top-left place, opened from the top bar.
HudZones.CHAT = table.freeze({ height = 250, spread = 0.2 })

-- Z8. The message zone: at most this wide, centred where the screen has room (`messageZone` cuts it short of Z1 and
-- the right column on a narrow one), from GAP under the target band down to this share of the layer's height.
HudZones.MESSAGE = table.freeze({ width = 980, bottom = 0.4 })

-- The thumbstick zone of a touch screen as shares of the layer (left, top, width, height): UI/HudAnchors' JOYSTICK
-- model of Roblox's dynamic thumbstick [inferred]. Kept here as data; package A makes HudAnchors read it.
HudZones.THUMB = table.freeze({ x = 0.04, y = 0.58, w = 0.26, h = 0.34 })

-- The elements of src/client/UI/Screens/Hud that are to stand at a HudZones place (their Name, then the place),
-- once package A moves them; the party rows (UI/Screens/PartyFrames) and the boss bar (DungeonController) live
-- outside Screens/Hud. The menu's root holds the minimap, the guide bar and the waiting row in its list.
HudZones.ELEMENTS = table.freeze({
	Portrait = "portrait",
	AutoButton = "auto",
	AutoPanel = "autoPopover",
	EffectsRow = "effects",
	BarkToast = "bark",
	TargetFrame = "target",
	PlayerMenu = "targetActions",
	ArenaMatch = "arenaPanel",
	ArenaReturn = "arenaPanel",
	Menu = "menuBar",
	CastBar = "castLine",
	ActionBar = "actionBar",
	Exp = "expBar",
} :: { [string]: string })

local function box(left: number, top: number, w: number, h: number): Rect
	return { left = left, top = top, right = left + w, bottom = top + h }
end

local function centred(cx: number, top: number, w: number, h: number): Rect
	return box(cx - w / 2, top, w, h)
end

-- The HUD layer of a real w x h screen with Roblox's top bar `topBar` real pixels tall: its size and the UI scale
-- (Logic/UiScale; a phone's area is PhoneHud.area).
function HudZones.layer(w: number, h: number, touch: boolean, topBar: number): (number, number, number)
	local lw, lh = UiScale.hud(w, h, touch, topBar)
	return lw, lh, UiScale.factor(w, h, touch)
end

-- Which HUD a touch flag and layer height get: "pc", "tablet" or "phone" (Logic/PhoneHud's).
function HudZones.device(touch: boolean, h: number): Device
	if PhoneHud.compact(touch, h) then
		return "phone"
	end
	return if touch then "tablet" else "pc"
end

-- Own effect icons shown in the row and the number behind its '+N' chip.
function HudZones.effectsShown(count: number): (number, number)
	local shown = math.min(math.max(0, count), HudZones.EFFECTS_CAP)
	return shown, math.max(0, count) - shown
end

local function others(state: State): number
	return math.clamp(state.party or 0, 0, HudZones.PARTY_MAX)
end

-- Party row `i` (1-based).
local function partyRow(i: number): Rect
	return box(
		MARGIN,
		HudStack.PARTY_TOP + (i - 1) * HudStack.PARTY_ROW,
		HudZones.PARTY_FRAME.w,
		HudZones.PARTY_FRAME.h
	)
end

-- The right edge of Z1: the Auto button's (the effects row ends there too).
local function zoneOneRight(): number
	return HudStack.EXTRAS.x + HudStack.EXTRAS.w
end

local function minimapRect(w: number): Rect
	local top = MARGIN + HudStack.ICON + GAP
	return {
		left = w - MARGIN - HudZones.MINIMAP_W,
		top = top,
		right = w - MARGIN,
		bottom = HudStack.RIGHT_TOP - GAP,
	}
end

-- The parts of the target band, top down: the target frame or the boss bar (with the add's frame under it), the
-- frame's effects, the arena panel. The band keeps the effects' room whether or not a frame shows, so the messages
-- under it never jump.
type Band = {
	rect: Rect,
	target: Rect?,
	effects: Rect?,
	actions: Rect?,
	boss: Rect?,
	add: Rect?,
	arena: Rect?,
}

local function band(w: number, state: State): Band
	local t = HudZones.TARGET
	local cx = w / 2
	local out: Band = { rect = box(0, 0, 0, 0) }
	local frame: Rect
	local shown: boolean
	if state.bossBar then
		local boss = centred(cx, MARGIN, HudZones.BOSS_BAR.w, HudZones.BOSS_BAR.h)
		out.boss = boss
		frame = centred(cx, boss.bottom + GAP, t.w, t.h)
		shown = state.add == true
	else
		frame = centred(cx, MARGIN, t.w, t.h)
		shown = (state.target or "none") ~= "none"
	end
	local effects = box(frame.left + t.effectsInset, frame.bottom + t.effectsGap, t.effectsW, t.effectsH)
	if shown then
		if state.bossBar then
			out.add = frame
		else
			out.target = frame
		end
		out.effects = effects
		if state.target == "player" then
			out.actions = box(frame.right + t.actionsGap, frame.top + t.actionsTop, t.actionsW, t.actionsH)
		end
	end
	local bottom = effects.bottom
	if state.arena == "match" or state.arena == "return" then
		local arena = centred(cx, bottom + GAP, HudZones.ARENA_PANEL.w, HudZones.ARENA_PANEL.h)
		out.arena = arena
		bottom = arena.bottom
	end
	out.rect =
		{ left = cx - HudZones.BOSS_BAR.w / 2, top = MARGIN, right = cx + HudZones.BOSS_BAR.w / 2, bottom = bottom }
	return out
end

-- Z3: the target band of a layer `w` wide: as wide as the boss bar, from MARGIN down to the lowest of its parts.
function HudZones.targetBand(w: number, state: State): Rect
	return band(w, state).rect
end

-- Z8: the message zone, GAP under the target band, MESSAGE.width wide where the screen has room and never closer than
-- GAP to Z1 / Z2 on the left or the minimap and the column on the right.
function HudZones.messageZone(w: number, h: number, state: State): Rect
	local top = band(w, state).rect.bottom + GAP
	local right = minimapRect(w).left
	if not state.touch then
		right = math.min(right, w - MARGIN - math.max(HudStack.TRACKER, HudStack.PANEL_PC))
	end
	local half = HudZones.MESSAGE.width / 2
	return {
		left = math.max(w / 2 - half, zoneOneRight() + GAP),
		top = top,
		right = math.min(w / 2 + half, right - GAP),
		bottom = math.max(top, h * HudZones.MESSAGE.bottom),
	}
end

-- Z6: the card slot of a w x h PC layer, or the place of a card of `kind` in it (bottom-aligned): from the column's
-- floor + GAP (the corner's top, HudStack.cornerTop) down to the mail spot's bottom, CARD_W wide at MARGIN from the
-- right edge. PC only: a tablet's touch buttons stand in that corner, its cards go into the message zone (package B).
function HudZones.cardSlot(w: number, h: number, kind: CardKind?): Rect
	local right = w - MARGIN
	local bottom = h - HudStack.MAIL.bottom
	local top = if kind then bottom - HudZones.CARDS[kind] else HudStack.cornerTop(false, w, h)
	return { left = right - HudZones.CARD_W, top = top, right = right, bottom = bottom }
end

-- Z2: the NPC bark's slot GAP under the last party row (at the first row's place with no party). PC only: a tablet's
-- column of panels stands there (the bark gives way to it, the plan's yield ladder), so nil.
function HudZones.barkSlot(state: State): Rect?
	if state.touch then
		return nil
	end
	local n = others(state)
	local top = if n > 0 then partyRow(n).bottom + GAP else HudStack.PARTY_TOP
	return box(MARGIN, top, HudZones.BARK.w, HudZones.BARK.h)
end

-- The thumbstick zone of a touch layer w x h (nothing persistent belongs there).
function HudZones.thumb(w: number, h: number): Rect
	local t = HudZones.THUMB
	return { left = w * t.x, top = h * t.y, right = w * (t.x + t.w), bottom = h * (t.y + t.h) }
end

-- The action bar's width: the skill slots, the potions and, on PC, the mount.
function HudZones.actionBarWidth(touch: boolean): number
	local b = HudZones.ACTION_BAR
	local skills = b.slots * b.slot + (b.slots - 1) * b.gap
	local potions = b.potions * b.slot + (b.potions - 1) * b.gap
	local width = skills + b.gap + MARGIN + b.gap + potions
	if not touch then
		width += b.gap + MARGIN + b.gap + b.slot
	end
	return width
end

local function actionBar(w: number, h: number, touch: boolean): Rect
	local b = HudZones.ACTION_BAR
	return centred(w / 2, h - b.bottom - b.slot, HudZones.actionBarWidth(touch), b.slot)
end

local function expBar(w: number, h: number): Rect
	local e = HudZones.EXP_BAR
	return { left = e.inset, top = h - e.bottom - e.h, right = w - e.inset, bottom = h - e.bottom }
end

-- The estimated chat window on a w x h PC layer at UI scale `scale`, its height grown by `grow` (-0.2 .. 0.2 covers
-- the estimate's spread): from MARGIN to HudStack.CHAT_GAP screen pixels left of the action bar (Hud/ChatDock).
function HudZones.chat(w: number, h: number, scale: number, grow: number?): Rect
	local bottom = expBar(w, h).top - GAP
	local height = HudZones.CHAT.height * (1 + (grow or 0)) / scale
	return {
		left = MARGIN,
		top = bottom - height,
		right = actionBar(w, h, false).left - HudStack.CHAT_GAP / scale,
		bottom = bottom,
	}
end

-- Every place of `state` on a w x h layer (PC, or a tablet with `state.touch`).
function HudZones.pc(w: number, h: number, state: State): Zones
	local touch = state.touch == true
	local n = others(state)
	local waiting = math.clamp(state.waiting or 0, 0, HudZones.WAITING_MAX)
	local e = HudStack.EXTRAS
	local auto = box(e.x, e.y, e.w, e.h)
	local parts = band(w, state)

	local party: { Rect } = {}
	for i = 1, n do
		table.insert(party, partyRow(i))
	end

	local buttons = #HudMenu.BAR
	local menuW = buttons * HudStack.ICON + (buttons - 1) * GAP
	local minimap = minimapRect(w)
	local guide = if state.guide
		then {
			left = w - MARGIN - HudZones.GUIDE_W,
			top = HudStack.RIGHT_TOP,
			right = w - MARGIN,
			bottom = HudStack.RIGHT_TOP_GUIDE - GAP,
		}
		else nil
	local waitingRect: Rect? = nil
	if waiting > 0 then
		local top = if state.guide then HudStack.RIGHT_TOP_GUIDE else HudStack.RIGHT_TOP
		local width = waiting * HudStack.WAITING + (waiting - 1) * GAP
		waitingRect = box(w - MARGIN - width, top, width, HudStack.WAITING)
	end

	-- Z5: the column's whole lane, as wide as its widest element (the tracker), from its top down to its floor
	local col = HudStack.column(touch, false, w, h, n, state.guide, waiting > 0)
	local laneW = math.max(HudStack.TRACKER, if touch then HudStack.PANEL_TOUCH else HudStack.PANEL_PC)
	local laneLeft = if col.right then col.x - laneW else col.x
	local column = if col.floor > col.top
		then { left = laneLeft, top = col.top, right = laneLeft + laneW, bottom = col.floor }
		else nil

	local portrait = HudStack.PORTRAIT
	local effectsTop = MARGIN + portrait.h + GAP
	return {
		portrait = box(MARGIN, MARGIN, portrait.w, portrait.h),
		auto = auto,
		autoPopover = if state.autoPopover
			then box(auto.right + GAP, auto.top, HudZones.AUTO_POPOVER.w, HudZones.AUTO_POPOVER.h)
			else nil,
		effects = { left = MARGIN, top = effectsTop, right = zoneOneRight(), bottom = effectsTop + HudStack.EFFECTS },
		party = party,
		bark = HudZones.barkSlot(state),
		target = parts.target,
		targetEffects = parts.effects,
		targetActions = parts.actions,
		bossBar = parts.boss,
		addFrame = parts.add,
		arenaPanel = parts.arena,
		menuBar = box(w - MARGIN - menuW, MARGIN, menuW, HudStack.ICON),
		minimap = minimap,
		guide = guide,
		waiting = waitingRect,
		column = column,
		card = if touch then nil else HudZones.cardSlot(w, h, nil),
		corner = if touch then HudStack.fixed(true, w, h) else {},
		castLine = centred(
			w / 2,
			h - HudZones.CAST_BAR.bottom - HudZones.CAST_BAR.h,
			HudZones.CAST_BAR.w,
			HudZones.CAST_BAR.h
		),
		actionBar = actionBar(w, h, touch),
		expBar = expBar(w, h),
		chatEstimate = if touch then nil else HudZones.chat(w, h, state.scale or 1),
	}
end

-- The zone of each place of `Zones` (party rows and corner buttons by their prefix).
local ZONE = table.freeze({
	portrait = "Z1",
	auto = "Z1",
	autoPopover = "Z1",
	effects = "Z1",
	bark = "Z2",
	target = "Z3",
	targetEffects = "Z3",
	targetActions = "Z3",
	bossBar = "Z3",
	addFrame = "Z3",
	arenaPanel = "Z3",
	menuBar = "Z4",
	minimap = "Z4",
	guide = "Z4",
	waiting = "Z4",
	column = "Z5",
	card = "Z6",
	castLine = "Z7",
	actionBar = "Z7",
	expBar = "Z7",
	chatEstimate = "chat",
} :: { [string]: string })
-- The order of `list` (stable, for readable spec messages).
local ORDER = table.freeze({
	"portrait",
	"auto",
	"autoPopover",
	"effects",
	"bark",
	"target",
	"targetEffects",
	"targetActions",
	"bossBar",
	"addFrame",
	"arenaPanel",
	"menuBar",
	"minimap",
	"guide",
	"waiting",
	"column",
	"card",
	"castLine",
	"actionBar",
	"expBar",
	"chatEstimate",
})
-- The overlays the player opens.
HudZones.OVERLAYS = table.freeze({ autoPopover = true } :: { [string]: boolean })

-- Every place of `zones` as one list: the named places in a fixed order, then the party rows ("party1"..) and the
-- corner's buttons ("corner.attack"..., sorted).
function HudZones.list(zones: Zones): { Named }
	local out: { Named } = {}
	local byName = zones :: any
	for _, name in ORDER do
		local rect: Rect? = byName[name]
		if rect then
			table.insert(
				out,
				{ name = name, zone = ZONE[name], rect = rect, overlay = HudZones.OVERLAYS[name] == true }
			)
		end
	end
	for i, rect in zones.party do
		table.insert(out, { name = `party{i}`, zone = "Z2", rect = rect, overlay = false })
	end
	local corner: { string } = {}
	for name in zones.corner do
		table.insert(corner, name)
	end
	table.sort(corner)
	for _, name in corner do
		table.insert(out, { name = `corner.{name}`, zone = "Z6", rect = zones.corner[name], overlay = false })
	end
	return out
end

return HudZones
