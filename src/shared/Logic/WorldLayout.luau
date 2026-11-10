--!strict
-- Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne, zbyt szczegółowe opisy, nic się nie
-- zwija"): the chrome heights and list rows of the world and social windows (UI plan, package E), so a phone keeps
-- room for its lists. Every function takes the window's content size (Logic/WindowFrame.rect(...).content, virtual
-- pixels) and the device ("phone" = a compact touch screen, UI/PhoneLayout.Compact; "tablet" = any other touch
-- screen) and returns the heights the window lays out with and the list it scrolls; the windows read the chrome
-- numbers, tests/worldlayout.spec checks the lists on every screen of tests/uiframe.spec (at least 2-3 rows on a
-- phone, 5 on PC, never a negative size). The emote wheel, the fishing panel and the character select take the
-- whole layer instead. Pure (Lune).

local PhoneHud = require("./PhoneHud")
local TextCaps = require("./TextCaps")

local WorldLayout = {}

export type Device = "pc" | "tablet" | "phone"
export type Size = { w: number, h: number }
export type Rect = { left: number, top: number, right: number, bottom: number }
-- A scrolling list: where it starts in its frame, how tall it is, its row and the gap between rows.
export type List = { top: number, height: number, row: number, gap: number }

-- The content a window passes when it reads only its chrome (its list fills the rest of its frame with a scale of 1).
WorldLayout.CHROME = table.freeze({ w = 0, h = 0 }) :: Size

-- Components/Section's numbers (tests/worldlayout.spec reads Section.luau and Theme.luau to keep them equal): the
-- header Theme.Size.SectionHeader (32) on PC and Theme.Size.MinTouch on touch, the folded summary line 26 / 44, the
-- gap Theme.Padding.Small.
WorldLayout.SECTION = table.freeze({ header = 32, headerTouch = 44, summary = 26, summaryTouch = 44, gap = 8 })
-- Theme.TextSize.Body and Small: the line heights the dialogue boxes count in.
WorldLayout.BODY = 20
WorldLayout.SMALL = 17

-- The device of a screen: a touch screen is a phone while compact (UI/PhoneLayout.Compact).
function WorldLayout.device(touch: boolean, compact: boolean): Device
	if compact then
		return "phone"
	elseif touch then
		return "tablet"
	end
	return "pc"
end

-- Whole rows of `list` that show at once, after `skip` pixels at its top (a folded section header in the list).
function WorldLayout.rows(list: List, skip: number?): number
	local free = list.height - (skip or 0)
	return math.max(0, math.floor((free + list.gap) / (list.row + list.gap) + 1e-6))
end

-- The height of a Components/Section: open with a body `body` tall, or folded (its summary line when it has one).
function WorldLayout.section(device: Device, open: boolean, body: number, summary: boolean?): number
	local touch = device ~= "pc"
	local S = WorldLayout.SECTION
	local header = if touch then S.headerTouch else S.header
	if open then
		return header + S.gap + body
	end
	if summary then
		return header + S.gap + (if touch then S.summaryTouch else S.summary)
	end
	return header
end

-- Rankings ---------------------------------------------------------------------------------------------------------
-- PC: the tab column on the left (`side`, the board 12 px right of it); touch: the tab strip on top (`strip`, the board
-- 8 px under it). The board: the title with its (i), the filter strip (on a phone a button at the title's right that
-- steps through the filter), the column heads, the rows (the podium of the first three is a Section in the list:
-- rankPodium, folded on a phone) and the footer (PC: the week's countdown, my place, the update time; a phone keeps
-- only my place, the countdown goes into the title row, the update time behind the title's (i)).
-- Review 2026-11-10: the weekly board's rewards line (`rewards`, its height at the top of the rows: Small 17 and its
-- padding 6, one line) shows on PC and a tablet only; a phone keeps its rows, the rewards are behind the title's (i).
export type Rankings = {
	side: number,
	strip: number,
	title: number,
	filter: number,
	filterButton: number,
	headTop: number,
	head: number,
	footer: number,
	footerLines: number,
	podium: number,
	rewards: number,
	list: List,
}

WorldLayout.REWARDS_LINE = 23

function WorldLayout.rankings(
	content: Size,
	device: Device,
	filter: boolean,
	info: boolean,
	rewards: boolean?
): Rankings
	local touch = device ~= "pc"
	local phone = device == "phone"
	local strip = if touch then 50 else 0
	local board = content.h - (if touch then strip + 8 else 0)
	local title = if phone then 30 else 34
	local filterH = if filter and not phone then 50 else 0
	local headTop = title + 4 + (if filterH > 0 then filterH + 4 else 0)
	local head = if phone then 26 else 30
	local footerLines = if phone then 1 elseif info then 3 else 2
	local footer = footerLines * 22 + (if phone then 0 else 4)
	local top = headTop + head + 2
	return {
		side = if touch then 0 else 200,
		strip = strip,
		title = title,
		filter = filterH,
		filterButton = if filter and phone then 150 else 0,
		headTop = headTop,
		head = head,
		footer = footer,
		footerLines = footerLines,
		podium = (if touch then 104 else 118) + 8,
		rewards = if rewards and not phone then WorldLayout.REWARDS_LINE else 0,
		list = { top = top, height = board - top - footer - 2, row = if touch then 44 else 40, gap = 2 },
	}
end

-- Season pass ------------------------------------------------------------------------------------------------------
-- The header (PC and tablet: the season, its tier, when it ends, the points bar and the week's limits; a phone: the
-- season, when it ends and its (i) and the tier on one line over a thin points bar, the limits behind the (i)), the
-- toolbar (tabs and the claim and unlock buttons), then PC the horizontal strip of tiers, touch a list of tier rows
-- under their heads (the list's own top padding 4; a phone's rows 50: the icon 40, the name and the state one line
-- each).
export type Season = {
	header: number,
	toolbar: number,
	gap: number,
	heads: number,
	row: number,
	icon: number,
	tierCol: number,
	tabsWidth: number,
	list: List,
	columns: number,
}

WorldLayout.SEASON_STRIP = table.freeze({ col = 128, tierRow = 28, cell = 134, side = 112 })

function WorldLayout.season(content: Size, device: Device): Season
	local phone = device == "phone"
	local header = if device == "pc" then 128 elseif phone then 40 else 120
	local toolbar, gap = 44, 8 -- Theme.Padding.Small
	local heads = if phone then 24 else 28
	local top = header + toolbar + gap + heads + 4 + 4
	local strip = WorldLayout.SEASON_STRIP
	local row = if phone then 50 else 96
	return {
		header = header,
		toolbar = toolbar,
		gap = gap,
		heads = heads,
		row = row,
		icon = if phone then 40 else 48,
		tierCol = if phone then 52 else 64,
		tabsWidth = if phone then 240 else 360,
		list = { top = top, height = content.h - top, row = row, gap = gap },
		-- PC: tier columns that show in the strip
		columns = math.floor((content.w - strip.side + gap) / (strip.col + gap)),
	}
end

-- The PC strip's height: the tier row and the two tracks.
function WorldLayout.seasonStrip(): number
	local strip = WorldLayout.SEASON_STRIP
	return 4 + strip.tierRow + 6 + strip.cell + 6 + strip.cell
end

-- Achievements ------------------------------------------------------------------------------------------------------
-- The summary (points, earned, the range and filter switches), PC the categories column with the list in the middle;
-- touch the category tabs over the list. Touch (owner 2026-11-10, a phone kept one row of the list): the numbers on
-- one line with a thin bar under it, both switches in one row under them; a phone's rows 52 (name, the short line and
-- a 3-px bar), a tablet's 66.
-- Review 2026-11-10: `switchButton` is one button of the range and filter switches (three buttons 6 apart): PC's switch
-- is ACH_SWITCH wide, a touch screen's half the content; the labels fit it in one line with the button's padding.
export type Achievements = {
	summary: number,
	numbers: number,
	switches: number,
	switchButton: number,
	tabsTop: number,
	tabs: number,
	list: List,
}

WorldLayout.ACH_SWITCH = 372

function WorldLayout.achievements(content: Size, device: Device): Achievements
	if device == "pc" then
		local summary = 40 * 2 + 6 -- Summary.HEIGHT: two ButtonHeightSmall rows
		local top = summary + 8
		return {
			summary = summary,
			numbers = 0,
			switches = 40,
			switchButton = WorldLayout.ACH_SWITCH / 3 - 6,
			tabsTop = 0,
			tabs = 0,
			list = { top = top, height = content.h - top, row = 66, gap = 0 },
		}
	end
	local phone = device == "phone"
	local numbers = 26 + 4 -- the line and the bar
	local summary = numbers + 4 + 44
	local gap = if phone then 4 else 8
	local tabsTop = summary + gap
	local top = tabsTop + 50 + gap
	return {
		summary = summary,
		numbers = numbers,
		switches = 44,
		switchButton = content.w / 2 / 3 - 6,
		tabsTop = tabsTop,
		tabs = 50,
		list = { top = top, height = content.h - top, row = if phone then 52 else 66, gap = 0 },
	}
end

-- The bestiary tab in the achievements list's place: the regions as a Section (bestiaryRegions, folded on a phone; the
-- folded header names the chosen region and its tiers), the entries of the chosen region under it. Open on a screen
-- too short for both, the region rows scroll in what is left and the entries keep the rest, never less than nothing.
WorldLayout.BESTIARY = table.freeze({ regionRow = 40, entryRow = 58, entryRowPhone = 52, gap = 6 })

export type Bestiary = { regions: number, list: List }

function WorldLayout.bestiaryRegions(regions: number): number
	local B = WorldLayout.BESTIARY
	return regions * (B.regionRow + 2) - 2
end

function WorldLayout.bestiary(middle: Size, device: Device, regionsOpen: boolean, regions: number): Bestiary
	local B = WorldLayout.BESTIARY
	local header = WorldLayout.section(device, false, 0)
	local free = math.max(0, middle.h - header - B.gap)
	local shown = 0
	if regionsOpen then
		shown = math.min(WorldLayout.bestiaryRegions(regions), math.max(0, free - WorldLayout.SECTION.gap))
		free = math.max(0, free - WorldLayout.SECTION.gap - shown)
	end
	local top = middle.h - free
	return {
		regions = shown,
		list = { top = top, height = free, row = if device == "phone" then B.entryRowPhone else B.entryRow, gap = 0 },
	}
end

-- Quest board -------------------------------------------------------------------------------------------------------
-- The hunting contracts' block as a Section (boardHunt, folded on a phone; its rule and the "next contract from level
-- N" line behind the (i)), the daily / weekly tabs with the set's line (beside the tabs on a phone), the cards (a
-- phone's card 92: the title, the objective and smaller reward slots).
export type QuestBoard = {
	hunt: number,
	card: number,
	tabsWidth: number,
	setTop: number,
	setLine: number,
	list: List,
}

WorldLayout.HUNT_CARD = 94 -- the block's card: the counts and the two buttons
WorldLayout.BOARD_CARD = table.freeze({ height = 110, compact = 92, slot = 38, compactSlot = 32 })

function WorldLayout.questBoard(content: Size, device: Device, hunt: boolean, huntOpen: boolean): QuestBoard
	local phone = device == "phone"
	local block = if hunt then WorldLayout.section(device, huntOpen, WorldLayout.HUNT_CARD) + 8 else 0
	local setTop = if phone then 0 else 46
	local tabsRow = if phone then 46 else 46 + 44 + 4
	local top = block + tabsRow
	local card = if phone then WorldLayout.BOARD_CARD.compact else WorldLayout.BOARD_CARD.height
	return {
		hunt = block,
		card = card,
		tabsWidth = if phone then 240 else 0,
		setTop = setTop,
		setLine = 44,
		list = { top = top, height = content.h - top, row = card, gap = 8 },
	}
end

-- Quest dialog ------------------------------------------------------------------------------------------------------
-- The portrait with the quest's name, the page (scrolls), the reward choice and the buttons. A phone: a smaller
-- portrait and the reward choice in one row (its label at the left, the slots beside it), so the page keeps 3 lines.
export type QuestDialog = {
	portrait: Size,
	bodyTop: number,
	body: number,
	bodyLines: number,
	choice: number,
	choiceLabel: number,
	slot: number,
	buttons: number,
}

function WorldLayout.questDialog(content: Size, device: Device, hasChoice: boolean): QuestDialog
	local phone = device == "phone"
	local portrait = if phone then { w = 64, h = 72 } else { w = 84, h = 96 }
	local bodyTop = portrait.h + (if phone then 8 else 10)
	local buttons = 52 + (if phone then 8 else 12)
	local choice = if hasChoice then (if phone then 56 + 6 else 88 + 4) else 0
	local body = content.h - bodyTop - buttons - choice
	return {
		portrait = portrait,
		bodyTop = bodyTop,
		body = body,
		bodyLines = math.max(0, math.floor(body / (WorldLayout.BODY + 2))),
		choice = choice,
		choiceLabel = if phone then 150 else 0,
		slot = if phone then 52 else 72,
		buttons = buttons,
	}
end

-- NPC dialog ----------------------------------------------------------------------------------------------------------
-- The portrait, the name and role, the NPC's line (a greeting or a line of at most TextCaps dialogPage characters, in
-- quotes, the (i) of its `.info` at the right) and the choices under it: the line's box holds the longest line, so it
-- never runs into the choices.
export type NpcDialog = {
	portrait: Size,
	line: Rect,
	lines: number,
	choicesTop: number,
	choices: List,
}

-- The longest line a box must hold: TextCaps dialogPage characters in words of six letters, plus the quotes.
local function longestLine(): string
	local chars = TextCaps.SURFACES.dialogPage.chars
	local words: { string } = {}
	local left = chars
	while left > 7 do
		table.insert(words, "xxxxxx")
		left -= 7
	end
	table.insert(words, string.rep("x", left))
	return `“{table.concat(words, " ")}”`
end
WorldLayout.longestLine = longestLine

function WorldLayout.npcDialog(content: Size, device: Device): NpcDialog
	local phone = device == "phone"
	local portrait = if phone then { w = 88, h = 104 } else { w = 120, h = 140 }
	local left = portrait.w + 16
	-- the (i) at the right; a window not measured yet (0 wide) gets a narrow box for one frame, never a negative one
	local width = math.max(120, content.w - left - 32)
	local lines = TextCaps.lines(longestLine(), WorldLayout.BODY, width)
	local lineTop = 56
	local height = lines * (WorldLayout.BODY + 2)
	local choicesTop = math.max(portrait.h, lineTop + height) + (if phone then 10 else 14)
	return {
		portrait = portrait,
		line = { left = left, top = lineTop, right = left + width, bottom = lineTop + height },
		lines = lines,
		choicesTop = choicesTop,
		choices = { top = choicesTop, height = content.h - choicesTop, row = 52, gap = 8 },
	}
end

-- Party ---------------------------------------------------------------------------------------------------------------
-- The tabs (members, the party finder), the invite row, the members, the bonus as one line with the rest behind its
-- (i) and the chat and leave buttons. A phone puts the invite, chat and leave into one row on top, rows 52.
export type Party = {
	tabs: number,
	invite: number,
	footer: number,
	bonus: number,
	row: number,
	avatar: number,
	list: List,
}

function WorldLayout.party(content: Size, device: Device): Party
	local phone = device == "phone"
	local tabs = if phone then 44 else 48
	local invite = if phone then 44 + 6 else 44 + 8
	local bonus = 22 + 4
	local footer = if phone then 0 else 46 + 4
	local members = content.h - tabs
	local row = if phone then 52 else 64
	return {
		tabs = tabs,
		invite = invite,
		footer = footer,
		bonus = bonus,
		row = row,
		avatar = if phone then 40 else 48,
		list = {
			top = tabs + invite,
			height = members - invite - bonus - footer,
			row = row,
			gap = if phone then 4 else 6,
		},
	}
end

-- Friends -------------------------------------------------------------------------------------------------------------
-- The tabs (friends, ignored) with, on a phone, the online count beside them; the header (the online count and the
-- two switches; a phone: only the switches); the rows: name and state on one line, the reason under it, the buttons
-- at the right (Join and "⋯" on touch; Join, Whisper and "⋯" on PC).
export type Friends = {
	tabs: number,
	header: number,
	status: number,
	row: number,
	list: List,
}

function WorldLayout.friends(content: Size, device: Device): Friends
	local phone = device == "phone"
	local tabs = 40 + 6
	local status = if phone then 0 else 22 + 4
	local header = status + 44 + 6
	local top = tabs + header
	return {
		tabs = tabs,
		header = header,
		status = status,
		row = 56,
		list = { top = top, height = content.h - top, row = 56, gap = if phone then 4 else 6 },
	}
end

-- Party finder's form cells (a UIGridLayout of 290-px cells): the "wanted classes" row keeps its label and a button
-- per class inside one cell, the steppers keep their text between the − and + buttons.
WorldLayout.FINDER = table.freeze({ cell = 290, button = 44, gap = 6, minLabel = 60 })

function WorldLayout.finderClassLabel(classes: number): number
	local F = WorldLayout.FINDER
	return F.cell - classes * (F.button + F.gap)
end

function WorldLayout.finderStepperText(): number
	local F = WorldLayout.FINDER
	return F.cell - 2 * (F.button + 4)
end

-- Character select ------------------------------------------------------------------------------------------------
-- The whole layer: the title and subtitle under Roblox's top bar, the slot cards, the test-mode line. A card keeps
-- "Graj" and "Usuń" pinned to its bottom; what is above them (emblem, name, class, map) shrinks on a short screen.
export type CharacterSelect = {
	header: number,
	titleTop: number,
	title: number,
	subtitleTop: number,
	subtitle: number,
	footer: number,
	body: Rect,
	cardWidth: number,
	cardHeight: number,
	padding: number,
	emblem: number,
	info: number,
	actions: number,
	play: Rect,
	delete: Rect,
}

WorldLayout.CHAR_CARD = table.freeze({ width = 300, maxHeight = 440, play = 52, delete = 40, gap = 8 })

function WorldLayout.characterSelect(layer: Size, compact: boolean, topBar: number): CharacterSelect
	local C = WorldLayout.CHAR_CARD
	local titleTop = if compact then topBar + 4 else math.max(24, topBar + 8)
	local title = if compact then 40 else 72
	local subtitleTop = titleTop + title + 4
	local subtitle = if compact then 24 else 30
	local header = subtitleTop + subtitle + (if compact then 6 else 20)
	local footer = if compact then 30 else 56
	local body = { left = 0, top = header, right = layer.w, bottom = layer.h - footer }
	local cardHeight = math.min(C.maxHeight, body.bottom - body.top - 8)
	local padding = if compact then 12 else 22
	local actions = C.play + C.gap + C.delete
	local info = cardHeight - 2 * padding - actions - C.gap
	local cardTop = body.top + ((body.bottom - body.top) - cardHeight) / 2
	local cardBottom = cardTop + cardHeight - padding
	local width = if compact then 260 else C.width
	local left = (layer.w - width) / 2 + padding
	local right = left + width - 2 * padding
	return {
		header = header,
		titleTop = titleTop,
		title = title,
		subtitleTop = subtitleTop,
		subtitle = subtitle,
		footer = footer,
		body = body,
		cardWidth = width,
		cardHeight = cardHeight,
		padding = padding,
		-- the emblem fits the info part with the name (32 / 40), class (24 / 26) and map (20 / 22) under it
		emblem = if compact then math.clamp(info - (32 + 24 + 20 + 3 * 4), 0, 56) else 84,
		info = info,
		actions = actions,
		play = { left = left, top = cardBottom - actions, right = right, bottom = cardBottom - actions + C.play },
		delete = { left = left, top = cardBottom - C.delete, right = right, bottom = cardBottom },
	}
end

-- Emote wheel ------------------------------------------------------------------------------------------------------
-- The buttons on a circle round the centre of the layer under Roblox's top bar. A tall screen: the title above and
-- the page arrows under the circle (today's wheel, radius 150); a short one: the radius from the free height and the
-- arrows at the circle's sides, no title, so nothing reaches the top bar or the screen's bottom. The circle is at
-- least `radiusX` wide (an ellipse when the height is short): 8 buttons 112 px wide never overlap (today's circle of
-- 150 overlapped its neighbours by 6 px).
export type EmoteWheel = {
	centerY: number, -- the circle's centre, from the layer's centre (positive = down)
	radius: number, -- vertical
	radiusX: number, -- horizontal
	button: Size,
	title: boolean,
	titleY: number,
	arrowX: number,
	arrowY: number,
}

WorldLayout.EMOTE = table.freeze({
	radius = 150,
	minRadius = 102,
	radiusX = 160,
	button = { w = 112, h = 72 },
	close = 84, -- "Zamknij" in the centre
	arrow = 56,
	margin = 8,
})

function WorldLayout.emoteWheel(layer: Size, topBar: number): EmoteWheel
	local E = WorldLayout.EMOTE
	local free = layer.h - topBar - 2 * E.margin
	local centerY = topBar / 2
	-- today's wheel: title 36 over the circle, arrows under it
	local tall = 2 * (E.radius + E.button.h + 10 + 18)
	if free >= tall then
		return {
			centerY = centerY,
			radius = E.radius,
			radiusX = math.max(E.radius, E.radiusX),
			button = E.button,
			title = true,
			titleY = -(E.radius + E.button.h + 10),
			arrowX = 70,
			arrowY = E.radius + E.button.h,
		}
	end
	local radius = math.clamp((free - E.button.h) / 2, E.minRadius, E.radius)
	local radiusX = math.max(radius, E.radiusX)
	return {
		centerY = centerY,
		radius = radius,
		radiusX = radiusX,
		button = E.button,
		title = false,
		titleY = 0,
		arrowX = radiusX + E.button.w / 2 + E.arrow / 2 + 12,
		arrowY = 0,
	}
end

-- The rectangles of the wheel's buttons (count of a page), arrows, "Zamknij" in the centre and title in the layer.
function WorldLayout.emoteRects(layer: Size, wheel: EmoteWheel, count: number): { Rect }
	local cx, cy = layer.w / 2, layer.h / 2 + wheel.centerY
	local out: { Rect } = {}
	local function box(x: number, y: number, w: number, h: number)
		table.insert(out, { left = x - w / 2, top = y - h / 2, right = x + w / 2, bottom = y + h / 2 })
	end
	for i = 1, count do
		local angle = math.rad(-90 + (i - 1) * 360 / math.max(count, 1))
		box(cx + math.cos(angle) * wheel.radiusX, cy + math.sin(angle) * wheel.radius, wheel.button.w, wheel.button.h)
	end
	local arrow = WorldLayout.EMOTE.arrow
	box(cx, cy, WorldLayout.EMOTE.close, WorldLayout.EMOTE.close)
	box(cx - wheel.arrowX, cy + wheel.arrowY, arrow, arrow)
	box(cx + wheel.arrowX, cy + wheel.arrowY, arrow, arrow)
	if wheel.title then
		box(cx, cy + wheel.titleY, 300, 36)
	end
	return out
end

-- Fishing --------------------------------------------------------------------------------------------------------------
-- The minigame's panel in the windows' layer: PC and tablet 680 x 190, 230 px over the bottom (the action bar and the
-- cast bar stay free), never under Roblox's top bar; a phone: between the HUD's left column and its right one
-- (Logic/PhoneHud), under the top bar, over the bottom buttons, 170 tall (the title and "Anuluj" in one row, the bar,
-- the touch hint in two lines under it). The target frame's band in the middle is
-- free while fishing (nothing is targeted), so the panel may stand there.
export type Fishing = { panel: Rect, bar: number, compact: boolean }

WorldLayout.FISHING = table.freeze({ width = 680, height = 190, bottom = 230, compactHeight = 170, margin = 8 })
-- PhoneHud's places of the middle band (the target frame and what hangs under it).
WorldLayout.FISHING_FREE =
	table.freeze({ target = true, targetEffects = true, castBar = true, actions = true, pool = true })

-- PhoneHud's places as rectangles in a layer `layer` whose HUD starts `topBar` down (the stack to the bottom gap).
function WorldLayout.phonePlaces(layer: Size, topBar: number): { [string]: Rect }
	local out: { [string]: Rect } = {}
	local hudH = layer.h - topBar
	for name, place in PhoneHud.PLACES do
		local r = PhoneHud.rect(place, layer.w, hudH)
		out[name] = { left = r.left, top = r.top + topBar, right = r.right, bottom = r.bottom + topBar }
	end
	return out
end

function WorldLayout.fishing(layer: Size, topBar: number, compact: boolean): Fishing
	local F = WorldLayout.FISHING
	if not compact then
		local width = math.min(F.width, layer.w - 2 * F.margin)
		local bottom = layer.h - F.bottom
		local top = math.max(topBar + F.margin, bottom - F.height)
		local left = (layer.w - width) / 2
		return {
			panel = { left = left, top = top, right = left + width, bottom = top + F.height },
			bar = width - 40,
			compact = false,
		}
	end
	local places = WorldLayout.phonePlaces(layer, topBar)
	local left, right = 0, layer.w
	for name, r in places do
		if WorldLayout.FISHING_FREE[name] or r.top >= layer.h / 2 then
			continue
		end
		-- the upper left and right columns: whatever starts in the left or the right half
		if (r.left + r.right) / 2 < layer.w / 2 then
			left = math.max(left, r.right)
		else
			right = math.min(right, r.left)
		end
	end
	left += F.margin
	right -= F.margin
	local width = math.min(F.width, right - left)
	local x = left + ((right - left) - width) / 2
	local top = topBar + F.margin
	return {
		panel = { left = x, top = top, right = x + width, bottom = top + F.compactHeight },
		bar = width - 24,
		compact = true,
	}
end

return WorldLayout
