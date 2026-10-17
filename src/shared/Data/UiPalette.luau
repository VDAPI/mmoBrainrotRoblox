--!strict
-- S135 "Parchment and iron" (owner's mock-up A, 2026-10-15; DESIGN §23): the only place with interface colour values.
-- Pure hex data (Lune, wiki, tests); UI/Theme builds the Color3 roles from it (Theme.Paper, Theme.Iron, Theme.Brass,
-- Theme.Resource, Theme.Zone). Every text-on-background pair the interface uses is in PAIRS with its WCAG minimum
-- (text 4.5:1, informative edges 3:1) and tests/uipalette.spec checks each one. Decorative lines (`rule`,
-- `brass.line`) carry no information and are not in PAIRS.
--
-- Two surfaces with the same roles:
--   paper  the inside of windows (light parchment, dark ink)
--   iron   title bars, tooltips, HUD, overlays, nameplates (dark iron, parchment-coloured text)
-- Roles: surface (base), raised (slot, card), sunken (field, alternate row), hover, selected, text, textMuted, label
-- (upper-case section labels), heading, border (informative edge), rule (decorative line), accent (primary button)
-- with accentText, danger (error text and danger button) with dangerText (text on a danger button), success,
-- warning, link.

export type Surface = {
	surface: string,
	raised: string,
	sunken: string,
	hover: string,
	selected: string,
	text: string,
	textMuted: string,
	label: string,
	heading: string,
	border: string,
	rule: string,
	accent: string,
	accentText: string,
	danger: string,
	dangerText: string,
	success: string,
	warning: string,
	link: string,
}

export type Pair = { fg: string, bg: string, min: number, what: string }

local paper: Surface = {
	surface = "#EFE3C6",
	raised = "#E2D2AC",
	sunken = "#E8DBBB",
	hover = "#E6D6B0",
	selected = "#E4D0A2",
	text = "#2A2016",
	textMuted = "#634C2E", -- mock-up start #6B5434 was 4.8:1 on the slot; darker for the selected row
	label = "#5A4528",
	heading = "#3B2E1C",
	border = "#7A6136", -- mock-up #8C7448 was 2.98:1 on the slot
	rule = "#B89B5E",
	accent = "#4E6A26", -- mock-up #6B8A3A with white text was 3.95:1
	accentText = "#F3E6C4",
	danger = "#9A2F28", -- the old Danger #B8423A was 4.25:1 on parchment
	dangerText = "#F3E6C4",
	success = "#2F5A22",
	warning = "#744300",
	link = "#1F4E9A",
}

local iron: Surface = {
	surface = "#2A2016",
	raised = "#3B2E1C",
	sunken = "#211910",
	hover = "#46371F",
	selected = "#4E3D24",
	text = "#F3E6C4",
	textMuted = "#CDB98F",
	label = "#D8C08A",
	heading = "#E8C25A",
	border = "#A08654",
	rule = "#6B5434",
	accent = "#4E6A26",
	accentText = "#F3E6C4",
	danger = "#FF8A7E",
	dangerText = "#2A2016",
	success = "#8FD07A",
	warning = "#E8B04A",
	link = "#8DB8F0",
}

local UiPalette = {}

UiPalette.paper = paper
UiPalette.iron = iron

-- Window frame and accents: `frame` the iron frame (3 px), `line` the inner brass line (decorative), `bright` gold
-- text accents on iron (guild tag, own name on the nameplate).
UiPalette.brass = {
	frame = "#4A3A24",
	line = "#B89B5E",
	bright = "#E8C25A",
}

-- Resource bars: the fills on the dark `track` (>= 3:1 each).
UiPalette.resource = {
	hp = "#D0402F",
	mana = "#4A7BE0",
	energy = "#D9B23A",
	exp = "#9563DE",
	track = "#1A140C",
}

-- PvP zones (S16; the wiki reads them from here since S135).
UiPalette.zone = {
	green = "#4FD16B",
	yellow = "#E0C23B",
	red = "#D64A3E",
}

-- PvP indicator dot (S16): the zone colours plus the switching / locked states (PvpDot).
UiPalette.pvp = {
	switching = "#F0962E",
	locked = "#7C7F88",
}

-- Server-wide drop announcements (Announcement, HUD): the dark backdrop gradients and the mythic text.
UiPalette.announce = {
	legendaryGlow = "#3A2A10",
	legendaryBase = "#1B1D23",
	mythicGlow = "#4A0C0A",
	mythicBase = "#1B1013",
	mythicText = "#FFD0C8",
}

-- Currency glyphs shown before the atlases load (CurrencyIcon; identity colours, made readable per surface).
UiPalette.currency = {
	gold = "#E8C25A",
	exp = "#8E5BD9",
	dragon = "#E5302A",
	token = "#D9A441",
	huntmarks = "#9BC46A",
}

-- Neutral values: `plain` is an untinted image (ImageColor3 white), `shade` the black of overlays and text strokes.
UiPalette.neutral = {
	plain = "#FFFFFF",
	shade = "#000000",
}

UiPalette.SURFACES = { "paper", "iron" }
UiPalette.BACKGROUNDS = { "surface", "raised", "sunken", "hover", "selected" }
UiPalette.TEXT_ROLES = { "text", "textMuted", "label", "heading", "link", "danger", "success", "warning" }
UiPalette.MIN_TEXT = 4.5
UiPalette.MIN_EDGE = 3

local function buildPairs(): { Pair }
	local out: { Pair } = {}
	for _, name in UiPalette.SURFACES do
		local s: Surface = (UiPalette :: any)[name]
		for _, bg in UiPalette.BACKGROUNDS do
			for _, fg in UiPalette.TEXT_ROLES do
				table.insert(out, {
					fg = (s :: any)[fg],
					bg = (s :: any)[bg],
					min = UiPalette.MIN_TEXT,
					what = `{name}.{fg} on {name}.{bg}`,
				})
			end
		end
		for _, bg in { "surface", "raised", "sunken" } do
			table.insert(out, {
				fg = s.border,
				bg = (s :: any)[bg],
				min = UiPalette.MIN_EDGE,
				what = `{name}.border on {name}.{bg}`,
			})
		end
		table.insert(
			out,
			{ fg = s.accentText, bg = s.accent, min = UiPalette.MIN_TEXT, what = `{name}.accentText on {name}.accent` }
		)
		table.insert(
			out,
			{ fg = s.dangerText, bg = s.danger, min = UiPalette.MIN_TEXT, what = `{name}.dangerText on {name}.danger` }
		)
	end
	-- the window: the iron frame on the parchment, the title text on the iron bar
	table.insert(out, {
		fg = UiPalette.brass.frame,
		bg = paper.surface,
		min = UiPalette.MIN_EDGE,
		what = "brass.frame on paper.surface",
	})
	table.insert(out, {
		fg = UiPalette.brass.bright,
		bg = iron.surface,
		min = UiPalette.MIN_TEXT,
		what = "brass.bright on iron.surface",
	})
	table.insert(out, {
		fg = UiPalette.brass.bright,
		bg = iron.raised,
		min = UiPalette.MIN_TEXT,
		what = "brass.bright on iron.raised",
	})
	for _, key in { "hp", "mana", "energy", "exp" } do
		table.insert(out, {
			fg = (UiPalette.resource :: any)[key],
			bg = UiPalette.resource.track,
			min = UiPalette.MIN_EDGE,
			what = `resource.{key} on resource.track`,
		})
	end
	-- bar numbers: iron text with a dark stroke on the track
	table.insert(out, {
		fg = iron.text,
		bg = UiPalette.resource.track,
		min = UiPalette.MIN_TEXT,
		what = "iron.text on resource.track",
	})
	return out
end

UiPalette.PAIRS = buildPairs()

return UiPalette
