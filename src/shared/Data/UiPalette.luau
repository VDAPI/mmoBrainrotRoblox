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

local Contrast = require("../Logic/Contrast")

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
	-- S136: the mythic reveal's veil (LegendReveal), the death screen's red glow (Hud/DeathScreen)
	mythicVeil = "#2A0505",
	deathGlow = "#3A0D0B",
}

-- S136: arena league tiers (identity colours; text and edges through Theme.readable on parchment).
UiPalette.league = {
	bronze = "#A8703A",
	silver = "#B8BCC4",
	gold = "#D4A537",
	diamond = "#5EC8E6",
	master = "#B04AE0",
}

-- Currency glyphs shown before the atlases load (CurrencyIcon; identity colours, made readable per surface).
UiPalette.currency = {
	gold = "#E8C25A",
	exp = "#8E5BD9",
	dragon = "#E5302A",
	token = "#D9A441",
	huntmarks = "#9BC46A",
}

-- S136: medals of rankings, the arena and tournaments (places 1-3): a bright digit on an iron plaque (gold is not
-- readable as text on parchment).
UiPalette.medal = {
	gold = "#E8C25A",
	silver = "#C9CED6",
	bronze = "#D69A66", -- the S124 bronze #C48A58 was 4.47:1 on iron.raised
}

-- S136: HUD tiles and monster / NPC plates are iron with this background transparency; their pairs are checked on the
-- tile mixed with the brightest world behind it (snow, WORLD_BRIGHT). Badges on plates (level, group) are darker
-- (iron.sunken) and more opaque.
UiPalette.HUD_ALPHA = 0.15
UiPalette.BADGE_ALPHA = 0.1
UiPalette.WORLD_BRIGHT = "#E8EEF2"
-- The HUD tile over the brightest world: iron.surface and iron.raised at HUD_ALPHA mixed with WORLD_BRIGHT (the
-- backgrounds of Theme.readable(hex, "hud") and of the HUD pairs).
UiPalette.HUD_TILES = {
	Contrast.mix(iron.surface, UiPalette.WORLD_BRIGHT, UiPalette.HUD_ALPHA),
	Contrast.mix(iron.raised, UiPalette.WORLD_BRIGHT, UiPalette.HUD_ALPHA),
}

-- S136: monster name colours on the plate (DESIGN §15.1: elite red, Elite II purple, boss orange), lightened from the
-- S18 values to reach 4.5:1 on the HUD tile.
UiPalette.plate = {
	normal = "#F3E6C4",
	elite = "#FF9080",
	elite2 = "#D9A0FF",
	boss = "#FF9F1C",
	trail = "#F2E6C9", -- the HP bar's trail fill (a bar, not text)
}

-- S136: NPC quest marks (NpcMarkState): plates, minimap and world map.
UiPalette.mark = {
	available = "#E8C25A",
	low = "#B3B6BF", -- S98 grey offer; lighter than the S25 #9A9DA8 (3.8:1 on the HUD tile)
	turnIn = "#E8C25A",
	active = "#B3B6BF",
}

-- S136: monster group sizes 1-4 (S19, UI/GroupColors): ground rings, the "xN" plate badge, minimap dots.
UiPalette.group = { "#C9CED6", "#4FD16B", "#FF9F1C", "#FF7A7A" }

-- S136: PvP zone colours as text on iron (ZoneBanner, minimap label): red lightened (#D64A3E is 3.7:1 on iron).
UiPalette.zoneText = {
	green = "#4FD16B",
	yellow = "#E0C23B",
	red = "#FF9080",
}

-- S136: chat channel colours (ChatController) on the Roblox chat window (`window`, its default background).
-- General = iron.text, system = brass.bright.
UiPalette.chat = {
	window = "#191B1D",
	trade = "#E0A23B",
	party = "#6FB3FF",
	guild = "#6FD38A",
	whisper = "#D58CFF",
}

-- S136: HUD glyphs and edges (a graphic, >= 3:1 on iron and on the HUD tile over snow): the on-state glyphs of the
-- auto-hunt, lure and auto-potion buttons, the arena team edges, the Blood Moon panel edge. Text in these colours goes
-- through Theme.readable. The reds are lighter than their first S136 values (2.4-2.8:1 on the HUD tile).
UiPalette.glyph = {
	hunt = "#DE7058",
	lure = "#DC707A",
	potion = "#E06C60",
	amber = "#D9922E",
	ally = "#B8C85A",
	enemy = "#E06C60",
	blood = "#E6666C",
}

-- S136: the drawing of the world map and the minimap (Hud/Minimap, WorldMap/Canvas, WorldMap/Overlay): icons,
-- captions and markers are graphics on the painted terrain (DESIGN §23: the map drawing keeps its colours); the
-- frames, cards and panels around it use the roles. No pairs: the terrain behind them is the map's own picture.
UiPalette.map = {
	portal = "#B9A8FF",
	portalCaption = "#D8CCFF",
	cave = "#D9C9A8",
	caveCaption = "#F2B8A8",
	dungeon = "#D64A3E",
	dungeonMark = "#B8423A",
	lair = "#E0823C",
	lairCaption = "#F2C29A",
	worldBoss = "#8FD8FF", -- S149b: the world boss's crown and its barrow (icy blue, apart from the event's red)
	worldBossCaption = "#CDEBFA",
	node = "#E8C25A",
	vein = "#E8C25A",
	bush = "#6FCF5A",
	fishing = "#5AA8E8",
	spawn = "#C9A45C",
	quest = "#E8C25A",
	guide = "#F2E28A",
	flag = "#E8C25A",
	event = "#E0564A",
	party = "#4A8FE7",
	npc = "#F2E8C9",
	label = "#FFFFFF",
	elite2 = "#C77BFF", -- the Elite II return timer line on the creature card
}

-- Neutral values: `plain` is an untinted image (ImageColor3 white), `shade` the black of overlays and text strokes.
UiPalette.neutral = {
	plain = "#FFFFFF",
	shade = "#000000",
	swatch = "#808080", -- S136: a colour swatch without data (wardrobe)
	bubbleBg = "#FAFAFA", -- S136: the default Roblox speech bubble in the wardrobe preview
	bubbleText = "#1E1E1E",
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
	-- S152b: the season pass bar (brass on the track) and the green edge of a cell to claim on its parchment
	table.insert(out, {
		fg = UiPalette.brass.bright,
		bg = UiPalette.resource.track,
		min = UiPalette.MIN_EDGE,
		what = "brass.bright on resource.track (season pass bar)",
	})
	for _, bg in { "selected", "raised", "surface" } do
		table.insert(out, {
			fg = paper.accent,
			bg = (paper :: any)[bg],
			min = UiPalette.MIN_EDGE,
			what = `paper.accent on paper.{bg} (season pass cell to claim)`,
		})
	end
	-- bar numbers: iron text with a dark stroke on the track
	table.insert(out, {
		fg = iron.text,
		bg = UiPalette.resource.track,
		min = UiPalette.MIN_TEXT,
		what = "iron.text on resource.track",
	})
	-- S136: HUD tiles over the brightest world
	local hud = UiPalette.HUD_TILES[1]
	local badge = Contrast.mix(iron.sunken, UiPalette.WORLD_BRIGHT, UiPalette.BADGE_ALPHA)
	local function add(fg: string, bg: string, min: number, what: string)
		table.insert(out, { fg = fg, bg = bg, min = min, what = what })
	end
	for key, hex in UiPalette.glyph :: { [string]: string } do
		add(hex, iron.surface, UiPalette.MIN_EDGE, `glyph.{key} on iron.surface`)
		add(hex, iron.raised, UiPalette.MIN_EDGE, `glyph.{key} on iron.raised`)
		add(hex, hud, UiPalette.MIN_EDGE, `glyph.{key} on the HUD tile`)
	end
	for _, role in UiPalette.TEXT_ROLES do
		add((iron :: any)[role], hud, UiPalette.MIN_TEXT, `iron.{role} on the HUD tile`)
	end
	add(UiPalette.brass.bright, hud, UiPalette.MIN_TEXT, "brass.bright on the HUD tile")
	for key, hex in UiPalette.zoneText :: { [string]: string } do
		add(hex, hud, UiPalette.MIN_TEXT, `zoneText.{key} on the HUD tile`)
		add(hex, iron.surface, UiPalette.MIN_TEXT, `zoneText.{key} on iron.surface`)
	end
	for _, key in { "normal", "elite", "elite2", "boss" } do
		add((UiPalette.plate :: any)[key], hud, UiPalette.MIN_TEXT, `plate.{key} on the HUD tile`)
	end
	for key, hex in UiPalette.mark :: { [string]: string } do
		add(hex, hud, UiPalette.MIN_TEXT, `mark.{key} on the HUD tile`)
	end
	for i, hex in UiPalette.group do
		add(hex, badge, UiPalette.MIN_TEXT, `group[{i}] on the plate badge`)
	end
	for key, hex in UiPalette.medal :: { [string]: string } do
		add(hex, iron.surface, UiPalette.MIN_TEXT, `medal.{key} on iron.surface`)
		add(hex, iron.raised, UiPalette.MIN_TEXT, `medal.{key} on iron.raised`)
	end
	for _, key in { "trade", "party", "guild", "whisper" } do
		add((UiPalette.chat :: any)[key], UiPalette.chat.window, UiPalette.MIN_TEXT, `chat.{key} on chat.window`)
	end
	add(iron.text, UiPalette.chat.window, UiPalette.MIN_TEXT, "chat general (iron.text) on chat.window")
	add(
		UiPalette.announce.mythicText,
		UiPalette.announce.mythicBase,
		UiPalette.MIN_TEXT,
		"announce.mythicText on mythicBase"
	)
	add(iron.text, UiPalette.announce.legendaryBase, UiPalette.MIN_TEXT, "iron.text on announce.legendaryBase")
	add(UiPalette.brass.bright, UiPalette.chat.window, UiPalette.MIN_TEXT, "chat system (brass.bright) on chat.window")
	return out
end

UiPalette.PAIRS = buildPairs()

return UiPalette
