--!strict
-- Text caps per UI surface (owner 2026-11-10: "bardzo dużo napisów, niektóre rzeczy zasłaniają inne, zbyt szczegółowe
-- opisy"): how long a text may be where the player reads it, in visible characters after the placeholders are filled
-- with sample values and the rich-text tags are dropped, the same for pl and en (docs/UI-ZASADY.md §2 lists the same
-- numbers). The width model is the one uifit.spec used since the Studio review of 2026-10-22 (no TextService in Lune):
-- a letter, digit or mark LETTER em, a space SPACE em, a symbol at or above U+2000 (◆ ▸ ✕) SYMBOL em, generous on
-- purpose, so a text that fits here leaves room in Studio. Pure (Lune): tests/textcaps.spec (every key at its
-- surfaces, the per-package ratchets in tests/fixtures/textcaps), tests/uifit.spec (width).

local TextCaps = {}

TextCaps.LETTER = 0.56
TextCaps.SPACE = 0.3
TextCaps.SYMBOL = 1.0

-- One more room a text must also fit: the toast on the narrowest phone, the mythic banner.
export type Wrap = { lines: number, width: number, size: number }

export type Surface = {
	chars: number, -- visible characters after expand (each line on its own where `perLine`)
	lines: number?, -- at most this many lines: wrapped in `width` at `size`, or hard lines ("\n") without a width
	width: number?, -- px the text wraps in
	size: number?, -- the TextSize it is set in (Theme.TextSize: Small 17, Body 20, Large 24, Title 30)
	alt: Wrap?,
	sentences: number?, -- at most this many sentences
	perLine: boolean?, -- tooltips: `chars` caps each line, `lines` the whole text
}

-- Surface id -> its cap (docs/UI-ZASADY.md §2). A key shown on several surfaces keeps the strictest of them.
TextCaps.SURFACES = table.freeze({
	-- controls and titles
	button = { chars = 18, lines = 1, size = 20 }, -- one line, never wrapped (ButtonHeight 52, Body 20)
	modalButton = { chars = 14, lines = 1, size = 20 }, -- a modal's confirm and cancel buttons ("przycisk 14")
	tab = { chars = 12 },
	windowTitle = { chars = 22, lines = 1 },
	modalTitle = { chars = 28 },
	sectionTitle = { chars = 24 },
	panelTitle = { chars = 20 }, -- the name of a HUD panel (world boss, event, Blood Moon, tourney, arena)
	sectionSummary = { chars = 36, lines = 1 }, -- the line of a folded section
	label = { chars = 20 }, -- a label before its value
	line = { chars = 60, lines = 1 }, -- a window status line, a `.short`
	-- HUD
	hudLine = { chars = 32 }, -- a tracker entry, a panel line, a party row, the guide
	hudTip = { chars = 48, lines = 1 }, -- the tooltip of a HUD element: its name and state
	tileLabel = { chars = 18 }, -- a ☰ tile or a bar button, its key included
	-- messages
	toast = { chars = 60, lines = 2, width = 520 - 28, size = 20, alt = { lines = 3, width = 286, size = 17 } },
	alert = { chars = 28 }, -- a boss's big blow, a countdown, a phase
	banner = { -- one line in the legendary frame at Large + 2, and in the mythic one at Title
		chars = 56,
		lines = 1,
		width = 900 - 44,
		size = 24 + 2,
		alt = { lines = 1, width = 980 - 44, size = 30 },
	},
	card = { chars = 40 }, -- a line of a card (better item, fight, boss reward, legendary)
	prompt = { chars = 60 }, -- an invitation (party, duel, trade, guild, friend, arena, ready check)
	-- modals and details
	modalBody = { chars = 90 },
	modalDetails = { chars = 240 }, -- a modal's "Więcej ▸"
	infoTip = { chars = 240, sentences = 3 }, -- the popover of an (i)
	details = { chars = 300 }, -- a window's "Więcej ▸"
	-- tooltips
	tooltipCompact = { chars = 60, lines = 10, perLine = true }, -- the compact item tooltip (tooltip.spec)
	-- the skill bar tooltip: TipText.SKILL_MAX_LINES lines, none longer than a skill's short line (skillShort)
	skillTip = { chars = 60, lines = 5, perLine = true },
	skillShort = { chars = 60 }, -- the short line of a skill or a path node
	breakpoint = { chars = 48 }, -- a breakpoint option
	-- dialogue
	npcGreeting = { chars = 60 }, -- one sentence, the rest in `.info` behind the (i)
	dialogPage = { chars = 140 }, -- an offer page p1-p4, a hand-in `.done` / `.doneN`, an NPC line; more on "Dalej ▸"
	reply = { chars = 44 }, -- the player's answer
	-- other
	tutorialTile = { chars = 80 }, -- per device text
	loadingTip = { chars = 80 },
	cutscene = { chars = 140 },
	placeholder = { chars = 20 }, -- an input field's placeholder
	keyName = { chars = 18 },
} :: { [string]: Surface })

-- Sample lengths of the placeholders: names of their kind, numbers 6, anything else OTHER.
TextCaps.SAMPLE = table.freeze({
	player = 20,
	name = 20,
	nick = 20,
	item = 28,
	monster = 24,
	boss = 24,
	npc = 16,
	area = 20,
	map = 20,
	zone = 20,
	guild = 24,
	key = 6,
} :: { [string]: number })
TextCaps.NUMBER = 6
TextCaps.OTHER = 12

-- Placeholders that hold a number (an amount, a level, a time in seconds or minutes, a percentage): NUMBER each.
TextCaps.NUMBERS = table.freeze({
	n = true,
	count = true,
	gold = true,
	exp = true,
	level = true,
	lvl = true,
	ilvl = true,
	pct = true,
	min = true,
	max = true,
	hours = true,
	minutes = true,
	seconds = true,
	ms = true,
	days = true,
	day = true,
	week = true,
	s = true,
	h = true,
	m = true,
	d = true,
	x = true,
	y = true,
	z = true,
	left = true,
	total = true,
	points = true,
	shards = true,
	price = true,
	cost = true,
	fee = true,
	amount = true,
	rank = true,
	place = true,
	rating = true,
	delta = true,
	gap = true,
	kills = true,
	wins = true,
	tokens = true,
	score = true,
	tier = true,
	phase = true,
	v = true,
	value = true,
	dmg = true,
	crit = true,
	radius = true,
	range = true,
	speed = true,
	mul = true,
	slow = true,
	duration = true,
	hp = true,
	chance = true,
	hits = true,
	cap = true,
	done = true,
	have = true,
	need = true,
	used = true,
	up = true,
} :: { [string]: boolean })

-- A number placeholder by name: the list above, or a name that ends in a measure (slowDuration, healPct, ...).
local MEASURES = { "Duration", "Pct", "Dmg", "Radius", "Hp", "Mul", "Max", "Min", "Stacks", "Chance", "Time" }

local function sampleLength(name: string): number
	local length = TextCaps.SAMPLE[name]
	if length then
		return length
	end
	if TextCaps.NUMBERS[name] then
		return TextCaps.NUMBER
	end
	for _, tail in MEASURES do
		if #name > #tail and string.sub(name, -#tail) == tail then
			return TextCaps.NUMBER
		end
	end
	return TextCaps.OTHER
end
TextCaps.sampleLength = sampleLength

-- The template with every {placeholder} filled by a sample of its length: a name as "Xxxx" (names start with a
-- capital, which the sentence count reads), a number as "8888", anything else as "xxxx".
function TextCaps.expand(template: string): string
	return (
		string.gsub(template, "{([%w_]+)}", function(name: string): string
			local length = sampleLength(name)
			if TextCaps.SAMPLE[name] and name ~= "key" then
				return "X" .. string.rep("x", length - 1)
			end
			return string.rep(if length == TextCaps.NUMBER then "8" else "x", length)
		end)
	)
end

-- The text without rich-text tags (<b>, <font color="...">, </font>, <br/>), as the player sees it.
function TextCaps.plain(text: string): string
	return (string.gsub(text, "<[^<>]+>", ""))
end

-- Visible characters of one line or of the whole text: line breaks are not counted.
function TextCaps.chars(text: string): number
	local plain = string.gsub(TextCaps.plain(text), "[\r\n]", "")
	return utf8.len(plain) or #plain
end

-- Estimated width in px of `text` on one line at TextSize `size` (moved here unchanged from uifit.spec).
function TextCaps.width(text: string, size: number): number
	local em = 0
	for _, code in utf8.codes(text) do
		em += if code == 32 then TextCaps.SPACE elseif code >= 0x2000 then TextCaps.SYMBOL else TextCaps.LETTER
	end
	return em * size
end

-- Lines the text takes in `width` px at `size`: hard breaks start a line, words wrap greedily, a word wider than the
-- line breaks over as many lines as it needs (as TextWrapped does).
function TextCaps.lines(text: string, size: number, width: number): number
	local count = 0
	local space = TextCaps.SPACE * size
	for paragraph in string.gmatch(TextCaps.plain(text) .. "\n", "([^\n]*)\n") do
		count += 1
		local used = 0
		for word in string.gmatch(paragraph, "[^ ]+") do
			local w = TextCaps.width(word, size)
			if used > 0 and used + space + w <= width then
				used += space + w
			else
				if used > 0 then
					count += 1
				end
				if w > width then
					local extra = math.ceil(w / width) - 1
					count += extra
					used = w - extra * width
				else
					used = w
				end
			end
		end
	end
	return count
end

-- Capital letters of Polish beyond ASCII (two bytes each in UTF-8).
local CAPITALS = table.freeze({
	["Ą"] = true,
	["Ć"] = true,
	["Ę"] = true,
	["Ł"] = true,
	["Ń"] = true,
	["Ó"] = true,
	["Ś"] = true,
	["Ź"] = true,
	["Ż"] = true,
})

-- Quotation marks read as '"' when counting sentences (each is several bytes, so not in a pattern class).
local QUOTES = { "„", "”", "“", "«", "»" }

-- Sentences of the text: one, plus one for each end mark (. ! ? …) followed by a space and a capital letter, so
-- "np. miecz", "1.5" and a closing mark do not start one.
function TextCaps.sentences(text: string): number
	local plain = TextCaps.plain(text)
	plain = string.gsub(plain, "…", "...")
	for _, quote in QUOTES do
		plain = string.gsub(plain, quote, '"')
	end
	if not string.find(plain, "%S") then
		return 0
	end
	local count = 1
	for at in string.gmatch(plain, "[%.!%?][\"')]*%s+[\"'(]*()") do
		local first = string.sub(plain, at, at)
		if string.match(first, "^%u") or CAPITALS[string.sub(plain, at, at + 1)] then
			count += 1
		end
	end
	return count
end

-- Whether `text` (already expanded) fits surface `id` (or a Surface): ok, or false and the first reason.
function TextCaps.check(surface: string | Surface, text: string): (boolean, string?)
	local cap: Surface? = if type(surface) == "string" then TextCaps.SURFACES[surface] else surface
	assert(cap, `TextCaps: unknown surface {surface}`)
	local plain = TextCaps.plain(text)
	if cap.perLine then
		local count = 0
		for line in string.gmatch(plain .. "\n", "([^\n]*)\n") do
			count += 1
			local n = TextCaps.chars(line)
			if n > cap.chars then
				return false, `{n} > {cap.chars} chars in a line`
			end
		end
		if cap.lines and count > cap.lines then
			return false, `{count} > {cap.lines} lines`
		end
		return true, nil
	end
	local n = TextCaps.chars(plain)
	if n > cap.chars then
		return false, `{n} > {cap.chars} chars`
	end
	if cap.lines then
		if cap.width and cap.size then
			local lines = TextCaps.lines(plain, cap.size, cap.width)
			if lines > cap.lines then
				return false, `{lines} > {cap.lines} lines in {cap.width} px at {cap.size}`
			end
		else
			local _, breaks = string.gsub(plain, "\n", "")
			if breaks + 1 > cap.lines then
				return false, `{breaks + 1} > {cap.lines} lines`
			end
		end
	end
	local alt = cap.alt
	if alt then
		local lines = TextCaps.lines(plain, alt.size, alt.width)
		if lines > alt.lines then
			return false, `{lines} > {alt.lines} lines in {alt.width} px at {alt.size}`
		end
	end
	if cap.sentences then
		local count = TextCaps.sentences(plain)
		if count > cap.sentences then
			return false, `{count} > {cap.sentences} sentences`
		end
	end
	return true, nil
end

return TextCaps
