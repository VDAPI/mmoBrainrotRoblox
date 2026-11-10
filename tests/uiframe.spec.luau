--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): the UI
-- plan's rules for windows (L7) and popovers (L8) on Logic/WindowFrame and Logic/Popover. Windows: every registered
-- size, read from the controllers' `size = Vector2.new(W, H)` lines, on the plan's PC screens with Roblox's top bar 0,
-- 36 and 58 px keeps its title bar at least top bar + 8 down, centred and dragged to each edge, and the service pairs
-- fit side by side; on a touch screen the window starts at the top bar with its ✕ inside the title bar, and a phone's
-- keeps 280 px of content. Popovers: next to anchors on a 12 x 8 grid of every screen they stay inside the safe area
-- less 8, never cover their anchor, flip above when there is no room below and keep off a rectangle they are told to
-- avoid. UI package C owns this spec after package F: it empties RATCHET.
-- UI package C (2026-11-10): the components read these modules (source checks), a phone's title bar is 44 px with a
-- 52 x 44 ✕, a modal stays under the top bar and inside the screen (its body scrolls past that), and on a touch
-- screen the item tooltip takes the half of the screen away from the tapped slot (Popover.away) and keeps off a
-- window's action buttons.

local fs = require("@lune/fs")

local PhoneHud = require("../src/shared/Logic/PhoneHud")
local Popover = require("../src/shared/Logic/Popover")
local T = require("./Test")
local UiScale = require("../src/shared/Logic/UiScale")
local WindowFrame = require("../src/shared/Logic/WindowFrame")
local WindowRules = require("../src/shared/Logic/WindowRules")

type Rect = WindowFrame.Rect

-- Real screens: the plan's PC screens (hudlayout.spec's set as real screens), its tablets, and Logic/PhoneHud's phones.
local PC = {
	{ 1920, 1080 },
	{ 1366, 768 },
	{ 1280, 720 },
	{ 1920, 1200 },
	{ 2560, 1080 },
	{ 1280, 1024 },
	{ 1024, 768 },
	{ 1024, 600 },
	{ 1280, 600 },
}
local TABLET = { { 1280, 720 }, { 1280, 800 }, { 1024, 768 }, { 1024, 600 }, { 1366, 1024 } }
local BARS = { 0, 36, 58 }

-- The windows' layer of a screen (it covers the whole screen) in virtual pixels, and Roblox's top bar in it.
type Screen = { name: string, touch: boolean, compact: boolean, w: number, h: number, bar: number }

local function screens(): { Screen }
	local out: { Screen } = {}
	for _, set in { { touch = false, sizes = PC }, { touch = true, sizes = TABLET } } do
		for _, size in set.sizes do
			local k = UiScale.factor(size[1], size[2], set.touch)
			for _, bar in BARS do
				table.insert(out, {
					name = `{if set.touch then "tablet" else "PC"} {size[1]}x{size[2]} bar {bar}`,
					touch = set.touch,
					compact = false,
					w = size[1] / k,
					h = size[2] / k,
					bar = bar / k,
				})
			end
		end
	end
	-- a phone's layer is its safe area (PhoneHud.area); whether Roblox's bar is taken from it is inferred, so all three
	for _, device in PhoneHud.DEVICES do
		local w, h = PhoneHud.area(device)
		for _, bar in BARS do
			table.insert(out, {
				name = `phone {device.name} bar {bar}`,
				touch = true,
				compact = true,
				w = w,
				h = h,
				bar = bar / PhoneHud.SCALE,
			})
		end
	end
	return out
end

-- Every registered window: its id and size, from the Register calls of src/client/Controllers.
type Window = { id: string, w: number, h: number }

local function windows(): { Window }
	local out: { Window } = {}
	local function walk(dir: string)
		local names = fs.readDir(dir)
		table.sort(names)
		for _, name in names do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				walk(path)
			elseif string.sub(name, -5) == ".luau" then
				local id: string? = nil
				for line in string.gmatch(fs.readFile(path), "[^\n]+") do
					id = string.match(line, '^%s*id = "([%w_]+)",') or id
					local w, h = string.match(line, "^%s*size = Vector2%.new%((%d+), (%d+)%)")
					if w and h then
						table.insert(out, {
							id = assert(id, `{path}: a window size without an id`),
							w = assert(tonumber(w), path),
							h = assert(tonumber(h), path),
						})
						id = nil
					end
				end
			end
		end
	end
	walk("src/client/Controllers")
	return out
end

-- Window ids (and service pairs, "pair <service>") that fail L7 today, for package C to empty. A listed one that
-- passes on every screen fails, so the list only shrinks.
local RATCHET: { [string]: boolean } = {}

local function show(r: Rect): string
	return string.format("(%.1f, %.1f)-(%.1f, %.1f)", r.left, r.top, r.right, r.bottom)
end

local function inside(r: Rect, outer: Rect): boolean
	local e = 1e-6
	return r.left >= outer.left - e
		and r.top >= outer.top - e
		and r.right <= outer.right + e
		and r.bottom <= outer.bottom + e
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- What breaks L7 for a window of `size` on `screen` (empty when nothing does).
local function windowProblems(size: WindowFrame.Size, screen: Screen): { string }
	local problems: { string } = {}
	local canvas = { w = screen.w, h = screen.h }
	local layer = { left = 0, top = 0, right = screen.w, bottom = screen.h }
	local top = screen.bar + WindowFrame.TOP_GAP
	local function closeOk(frame: WindowFrame.Frame, how: string)
		local c = frame.close
		if
			c.right - c.left < WindowFrame.CLOSE
			or c.bottom - c.top < WindowFrame.CLOSE
			or not inside(c, frame.header)
		then
			table.insert(
				problems,
				`{how}: the close button {show(c)} is not a 44 px target inside {show(frame.header)}`
			)
		end
	end
	if screen.touch then
		local frame = WindowFrame.rect(canvas, size, nil, true, screen.bar, screen.compact)
		if math.abs(frame.header.top - screen.bar) > 1e-6 then
			table.insert(problems, `touch: the title bar starts at {frame.header.top}, not at the top bar`)
		end
		closeOk(frame, "touch")
		local content = frame.content.bottom - frame.content.top
		if screen.compact and content < 280 then
			table.insert(problems, `phone: {content} px of content`)
		end
		return problems
	end
	local function check(frame: WindowFrame.Frame, how: string)
		if frame.header.top < top - 1e-6 then
			table.insert(problems, `{how}: the title bar {show(frame.header)} is above top bar + 8 ({top})`)
		end
		closeOk(frame, how)
	end
	local centred = WindowFrame.rect(canvas, size, nil, false, screen.bar)
	check(centred, "centred")
	if not inside(centred.window, layer) then
		table.insert(problems, `centred: {show(centred.window)} leaves the screen`)
	end
	local far = 100000
	for _, drag in { { x = -far, y = 0 }, { x = far, y = 0 }, { x = 0, y = -far }, { x = 0, y = far } } do
		local offset = WindowFrame.clampDrag(canvas, size, drag, screen.bar)
		local frame = WindowFrame.rect(canvas, size, offset, false, screen.bar)
		local how = `dragged to ({drag.x}, {drag.y})`
		check(frame, how)
		local header = frame.header
		local seen = math.min(header.right, screen.w) - math.max(header.left, 0)
		if header.bottom > screen.h + 1e-6 or seen < WindowFrame.KEEP - 1e-6 then
			table.insert(problems, `{how}: only {seen} px of the title bar {show(header)} on the screen`)
		end
	end
	return problems
end

-- What breaks the service pair `service` next to the companion `backpack` on `screen`.
local function pairProblems(service: WindowFrame.Size, backpack: WindowFrame.Size, screen: Screen): { string }
	local problems: { string } = {}
	local canvas = { w = screen.w, h = screen.h }
	local layer = { left = 0, top = screen.bar + WindowFrame.TOP_GAP, right = screen.w, bottom = screen.h }
	local left, right = WindowFrame.pair(service, backpack)
	local bag = WindowFrame.rect(canvas, backpack, left, false, screen.bar).window
	local other = WindowFrame.rect(canvas, service, right, false, screen.bar).window
	for _, r in { bag, other } do
		if not inside(r, layer) then
			table.insert(problems, `{show(r)} leaves the screen or reaches the top bar`)
		end
	end
	if overlaps(bag, other) or math.abs(other.left - bag.right - WindowFrame.PAIR_GAP) > 1e-6 then
		table.insert(problems, `the backpack {show(bag)} and the service {show(other)} are not side by side`)
	end
	return problems
end

-- The popovers of the UI: an (i) note's box (Theme.Size.InfoTipWidth; Components/InfoTip: 8 lines of Small + 4 and
-- its padding, then it scrolls), the compact item tooltip (Theme.Size.TooltipWidth; about 300 tall [estimate]: at
-- most 10 lines of 60, package D's tooltip.spec) and a plain tooltip (Components/Tooltip: at most 360 wide); anchors
-- are touch targets and item slots (MinTouch, SlotSize).
local POPOVERS = {
	{ name = "info", w = 320, h = 8 * (17 + 4) + 2 * 8 },
	{ name = "item", w = 340, h = 300 },
	{ name = "tooltip", w = 360, h = 80 },
}
local ITEM_TOOLTIP = POPOVERS[2]
local ANCHORS = { 44, 64 }

-- Anchors of `side` px on a 12 x 8 grid over `safe`.
local function grid(safe: Rect, side: number): { Rect }
	local out: { Rect } = {}
	for i = 0, 11 do
		for j = 0, 7 do
			local x = safe.left + (safe.right - safe.left - side) * i / 11
			local y = safe.top + (safe.bottom - safe.top - side) * j / 7
			table.insert(out, { left = x, top = y, right = x + side, bottom = y + side })
		end
	end
	return out
end

-- Components/InfoTip's own placement today (the box's top-left on a w x h layer).
local function infoTipToday(anchor: Rect, size: WindowFrame.Size, w: number, h: number): Rect
	local x = anchor.left
	if x + size.w > w - 8 then
		x = anchor.right - size.w
	end
	local y = anchor.bottom + 6
	if y + size.h > h - 8 then
		y = anchor.top - 6 - size.h
	end
	x = math.clamp(x, 8, math.max(8, w - 8 - size.w))
	y = math.clamp(y, 8, math.max(8, h - 8 - size.h))
	return { left = x, top = y, right = x + size.w, bottom = y + size.h }
end

local function theme(block: string): { [string]: number }
	local source = fs.readFile("src/client/UI/Theme.luau")
	local start = assert(string.find(source, `{block} = \{`, 1, true), block)
	local stop = string.find(source, "\n}", start, true)
	local out: { [string]: number } = {}
	for name, value in string.gmatch(string.sub(source, start, stop), "(%w+) = (%d+)") do
		out[name] = assert(tonumber(value), name)
	end
	return out
end

T.describe("Windows (L7, owner 2026-11-10)", function()
	T.it("reads every registered window size", function()
		local all = windows()
		T.expect(#all >= 40).toBe(true)
		local seen: { [string]: boolean } = {}
		for _, w in all do
			if seen[w.id] then
				error(`window {w.id} is registered twice`)
			end
			seen[w.id] = true
		end
		T.expect(seen.inventory).toBe(true)
	end)

	T.it("keeps every title bar under the top bar, centred, dragged and on touch, but the ratchet's", function()
		local failing: { [string]: string } = {}
		local all = windows()
		local byId: { [string]: Window } = {}
		for _, w in all do
			byId[w.id] = w
		end
		local backpack = assert(byId[WindowRules.INVENTORY], "the companion backpack")
		for _, screen in screens() do
			for _, w in all do
				local problems = windowProblems({ w = w.w, h = w.h }, screen)
				if #problems > 0 and not failing[w.id] then
					failing[w.id] = `{screen.name}: {problems[1]}`
				end
			end
			if not screen.touch then
				for id in WindowRules.SERVICES do
					local service = byId[id]
					if service and WindowRules.bringsBackpack(id) then
						local problems = pairProblems(
							{ w = service.w, h = service.h },
							{ w = backpack.w, h = backpack.h },
							screen
						)
						local key = `pair {id}`
						if #problems > 0 and not failing[key] then
							failing[key] = `{screen.name}: {problems[1]}`
						end
					end
				end
			end
		end
		local bad = {}
		for key, why in failing do
			if not RATCHET[key] then
				table.insert(bad, `{key} ({why})`)
			end
		end
		table.sort(bad)
		if #bad > 0 then
			error(`windows break L7:\n{table.concat(bad, "\n")}`)
		end
		for key in RATCHET do
			if not failing[key] then
				error(`{key} passes now: take it off RATCHET`)
			end
		end
	end)

	T.it("reproduces today's window, its drag and the service pairs by default", function()
		-- Components/Window: centred at the offset, ✕ 6 from the right, content Padding.Large under a 52 title bar
		local frame = WindowFrame.rect({ w = 1920, h = 1080 }, { w = 900, h = 620 }, { x = 30, y = -10 }, false)
		T.expect(frame.window).toEqual({ left = 540, top = 220, right = 1440, bottom = 840 })
		T.expect(frame.header.bottom).toBe(272)
		T.expect(frame.close).toEqual({ left = 1390, top = 224, right = 1434, bottom = 268 })
		T.expect(frame.content).toEqual({ left = 562, top = 294, right = 1418, bottom = 818 })
		T.expect(frame.footer.top).toBe(818 - 52)
		-- touch: the whole layer
		local touch = WindowFrame.rect({ w = 1280, h = 720 }, { w = 900, h = 620 }, nil, true)
		T.expect(touch.window).toEqual({ left = 0, top = 0, right = 1280, bottom = 720 })
		-- the drag keeps 80 px and the title bar on the screen, as Components/Window's clampOffset does; only the top
		-- edge moves (from the screen's edge to the top bar + 8)
		local screen = { w = 1920, h = 1080 }
		local size = { w = 900, h = 620 }
		local o = WindowFrame.clampDrag(screen, size, { x = 5000, y = 5000 }, 0)
		T.expect(o).toEqual({ x = 1920 / 2 + 900 / 2 - 80, y = 1080 / 2 + 620 / 2 - 52 })
		o = WindowFrame.clampDrag(screen, size, { x = -5000, y = -5000 }, 87)
		T.expect(WindowFrame.rect(screen, size, o, false).window.top).toBe(87 + 8)
		-- WindowManager's pairOffsets: half = (backpack + service + 12) / 2
		local bag, service = WindowFrame.pair({ w = 720, h = 640 }, { w = 560, h = 640 })
		T.expect(bag).toEqual({ x = -(560 + 720 + 12) / 2 + 280, y = 0 })
		T.expect(service).toEqual({ x = (560 + 720 + 12) / 2 - 360, y = 0 })
	end)

	T.it("gives a phone a 44-px title bar with a 52 x 44 ✕ and keeps a pinned footer under the body", function()
		local phones = 0
		for _, screen in screens() do
			if screen.compact then
				phones += 1
				local frame = WindowFrame.rect(
					{ w = screen.w, h = screen.h },
					{ w = 900, h = 620 },
					nil,
					true,
					screen.bar,
					true
				)
				T.expect(frame.header.bottom - frame.header.top).toBe(WindowFrame.HEADER_COMPACT)
				T.expect(frame.close.right - frame.close.left).toBe(WindowFrame.CLOSE_WIDE)
				T.expect(frame.close.bottom - frame.close.top).toBe(WindowFrame.HEADER_COMPACT)
				T.expect(inside(frame.close, frame.header)).toBe(true)
			end
		end
		T.expect(phones > 0).toBe(true)
		-- Components/Window's Footer: the buttons at the content's bottom, the rest FOOTER_GAP above them
		local frame = WindowFrame.rect({ w = 1920, h = 1080 }, { w = 900, h = 620 }, nil, false)
		T.expect(WindowFrame.body(frame, true)).toEqual({
			left = frame.content.left,
			top = frame.content.top,
			right = frame.content.right,
			bottom = frame.footer.top - WindowFrame.FOOTER_GAP,
		})
		T.expect(WindowFrame.body(frame)).toEqual(frame.content)
	end)

	T.it(
		"keeps a modal under the top bar and inside the screen, at most 520 wide, its body scrolling past that",
		function()
			for _, screen in screens() do
				local area = {
					left = 0,
					top = screen.bar + WindowFrame.TOP_GAP,
					right = screen.w,
					bottom = screen.h - WindowFrame.TOP_GAP,
				}
				local header = if screen.compact then WindowFrame.HEADER_COMPACT else WindowFrame.HEADER
				local pad = if screen.compact then WindowFrame.PADDING_COMPACT else WindowFrame.PADDING
				for _, height in { 160, 400, math.huge } do
					local r = WindowFrame.modal({ w = screen.w, h = screen.h }, height, screen.bar)
					local where = `{screen.name}, a modal {height} px tall`
					if not inside(r, area) then
						error(`{where}: {show(r)} reaches the top bar or leaves the screen`)
					end
					if
						r.right - r.left > WindowFrame.MODAL_W + 1e-6
						or math.abs(r.left + r.right - screen.w) > 1e-6
					then
						error(`{where}: {show(r)} is not centred and at most {WindowFrame.MODAL_W} wide`)
					end
					if height <= area.bottom - area.top and math.abs(r.bottom - r.top - height) > 1e-6 then
						error(`{where}: cut to {r.bottom - r.top} px though it fits`)
					end
					-- Components/Modal: what is left for the body between the title bar and the buttons
					local body = r.bottom - r.top - header - WindowFrame.FOOTER - pad
					if height == math.huge and body < 120 then
						error(`{where}: {body} px for the body`)
					end
				end
			end
		end
	)

	T.it("uses Theme's numbers", function()
		local size = theme("Theme.Size")
		local padding = theme("Theme.Padding")
		T.expect(size.WindowHeader).toBe(WindowFrame.HEADER)
		T.expect(size.WindowHeaderCompact).toBe(WindowFrame.HEADER_COMPACT)
		T.expect(size.MinTouch).toBe(WindowFrame.CLOSE)
		T.expect(size.ButtonHeight).toBe(WindowFrame.FOOTER)
		T.expect(size.ModalWidth).toBe(WindowFrame.MODAL_W)
		T.expect(padding.Large).toBe(WindowFrame.PADDING)
		T.expect(padding.Medium).toBe(WindowFrame.PADDING_COMPACT)
		T.expect(size.InfoTipWidth).toBe(POPOVERS[1].w)
		T.expect(size.TooltipWidth).toBe(ITEM_TOOLTIP.w)
		T.expect(padding.Small).toBe(Popover.MARGIN)
		-- UI package C: the footer's gap and the tab strip (Components/Tabs)
		T.expect(padding.Small).toBe(WindowFrame.FOOTER_GAP)
		T.expect(padding.Small).toBe(WindowFrame.TAB_GAP)
		T.expect(size.TabHeight).toBe(size.MinTouch)
		local text = theme("Theme.TextSize")
		local levels = WindowFrame.TAB_LEVELS
		T.expect({ levels[1].pad, levels[2].pad, levels[3].pad })
			.toEqual({ padding.Large, padding.Medium, padding.Small })
		T.expect({ levels[1].size, levels[2].size, levels[3].size }).toEqual({ text.Body, text.Body, text.Small })
	end)

	T.it("is what the window chrome and the popovers read (UI package C)", function()
		local function calls(path: string, needles: { string }): string
			local source = fs.readFile(path)
			for _, needle in needles do
				if not string.find(source, needle, 1, true) then
					error(`{path} does not read {needle}`)
				end
			end
			return source
		end
		local function lacks(path: string, source: string, needles: { string })
			for _, needle in needles do
				if string.find(source, needle, 1, true) then
					error(`{path} still has its own "{needle}"`)
				end
			end
		end
		local path = "src/client/UI/Components/Window.luau"
		local source = calls(path, {
			"WindowFrame.clampDrag(",
			"WindowFrame.HEADER_COMPACT",
			"WindowFrame.CLOSE_WIDE",
			"WindowFrame.FOOTER_GAP",
		})
		lacks(path, source, { "UDim2.new(1, -6, 0.5, 0)", "props.Size.X / 2 - 80)" })
		path = "src/client/Controllers/WindowManager.luau"
		lacks(path, calls(path, { "WindowFrame.pair(", "WindowRules.partner(" }), { "local GAP = " })
		calls("src/client/UI/Components/Modal.luau", { "WindowFrame.modal(", "WindowFrame.CLOSE_WIDE" })
		calls("src/client/UI/Components/Tabs.luau", { "WindowFrame.tabFit(", "WindowFrame.TAB_GAP" })
		for _, name in { "Tooltip", "ItemTooltip", "InfoTip" } do
			path = `src/client/UI/Components/{name}.luau`
			lacks(path, calls(path, { "Popover.place(" }), { "local OFFSET = " })
		end
		calls("src/client/UI/Components/ItemTooltip.luau", { "Popover.away(", "function ItemTooltip.avoid(" })
		path = "src/client/UI/Components/InfoTip.luau"
		lacks(path, calls(path, { "local MAX_LINES = 8\n", "Tooltip.SafeArea" }), { "local MARGIN = ", "local GAP = " })
	end)
end)

T.describe("Popovers (L8, owner 2026-11-10)", function()
	T.it("stay inside the safe area, off their anchor, flip and keep off what they avoid", function()
		for _, screen in screens() do
			local safe = { left = 0, top = screen.bar, right = screen.w, bottom = screen.h }
			local area = { left = 8, top = screen.bar + 8, right = screen.w - 8, bottom = screen.h - 8 }
			for _, side in ANCHORS do
				for _, anchor in grid(safe, side) do
					for _, pop in POPOVERS do
						local size = { w = pop.w, h = pop.h }
						local where = `{screen.name}, {pop.name} at {show(anchor)}`
						local rect, took = Popover.place(anchor, size, safe)
						if not inside(rect, area) then
							error(`{where}: {show(rect)} leaves the safe area less 8`)
						end
						if overlaps(rect, anchor) then
							error(`{where}: {show(rect)} covers its anchor`)
						end
						local below = anchor.bottom + Popover.GAP + size.h <= area.bottom
						local above = anchor.top - Popover.GAP - size.h >= area.top
						if below and took ~= "below" then
							error(`{where}: room below, but it went {took}`)
						elseif not below and above and took ~= "above" then
							error(`{where}: no room below, room above, but it went {took}`)
						end
						-- told to keep off the place under the anchor, it goes above when there is room
						if below and above then
							local avoided, side2 = Popover.place(anchor, size, safe, { avoid = rect })
							if side2 ~= "above" or overlaps(avoided, rect) then
								error(`{where}: did not keep off {show(rect)} (went {side2})`)
							end
						end
					end
				end
			end
		end
	end)

	T.it("the largest compact item tooltip fits every screen", function()
		for _, screen in screens() do
			local room = { w = screen.w - 16, h = screen.h - screen.bar - 16 }
			if ITEM_TOOLTIP.w > room.w or ITEM_TOOLTIP.h > room.h then
				error(`{screen.name}: {room.w} x {room.h} px for the item tooltip`)
			end
		end
	end)

	T.it("places like today's InfoTip and cursor tooltips by default", function()
		local w, h = 1920, 1080
		local layer = { left = 0, top = 0, right = w, bottom = h }
		for _, side in ANCHORS do
			for _, anchor in grid(layer, side) do
				for _, pop in POPOVERS do
					local size = { w = pop.w, h = pop.h }
					local today = infoTipToday(anchor, size, w, h)
					-- today's box sometimes lands on its anchor (no room above either): there the new one moves
					if not overlaps(today, anchor) then
						T.expect(Popover.place(anchor, size, layer)).toEqual(today)
					end
				end
			end
		end
		-- ItemTooltip on PC: 20 right of and 20 under the cursor, left of it at the right edge
		local item = { w = 340, h = 192 }
		local options = { prefer = "right" :: Popover.Side, gap = Popover.ITEM.gap }
		T.expect(Popover.place(Popover.cursor(500, 300, Popover.ITEM.drop), item, layer, options)).toEqual({
			left = 520,
			top = 320,
			right = 860,
			bottom = 512,
		})
		T.expect(Popover.place(Popover.cursor(1700, 300, Popover.ITEM.drop), item, layer, options).left)
			.toBe(1700 - 20 - 340)
		-- Components/Tooltip: 18 right of and 22 under the cursor
		local tip, took = Popover.place(
			Popover.cursor(800, 400, Popover.TOOLTIP.drop),
			{ w = 360, h = 80 },
			layer,
			{ prefer = "right", gap = Popover.TOOLTIP.gap }
		)
		T.expect(took).toBe("right")
		T.expect(tip.left).toBe(818)
		T.expect(tip.top).toBe(422)
	end)

	T.it(
		"on touch, the item tooltip takes the half away from the tapped slot and keeps off the action buttons",
		function()
			local size = { w = ITEM_TOOLTIP.w, h = ITEM_TOOLTIP.h }
			local touch = 0
			for _, screen in screens() do
				if not screen.touch then
					continue
				end
				touch += 1
				local safe = { left = 0, top = screen.bar, right = screen.w, bottom = screen.h }
				local area = { left = 8, top = screen.bar + 8, right = screen.w - 8, bottom = screen.h - 8 }
				local middle = screen.w / 2
				for _, side in ANCHORS do
					for _, anchor in grid(safe, side) do
						local where = `{screen.name}, slot {show(anchor)}`
						local rect, took = Popover.away(anchor, size, safe)
						if not inside(rect, area) then
							error(`{where}: {show(rect)} leaves the safe area less 8`)
						end
						local far: Popover.Side = if (anchor.left + anchor.right) / 2 < middle then "right" else "left"
						if took ~= far then
							error(`{where}: went {took}, not to the far half`)
						end
						-- the far half has room for it (the slot does not reach across the middle): there, clear of the slot
						local room = if far == "right"
							then area.right - math.max(middle, anchor.right) - Popover.GAP
							else math.min(middle, anchor.left) - Popover.GAP - area.left
						if room >= size.w then
							local onFar = if far == "right" then rect.left >= middle else rect.right <= middle
							if overlaps(rect, anchor) or not onFar then
								error(`{where}: {show(rect)} is not on the far half, clear of the slot`)
							end
							-- a strip of buttons across the place it took: under or over it when there is room
							local strip = {
								left = 0,
								top = rect.top + size.h / 2 - 26,
								right = screen.w,
								bottom = rect.top + size.h / 2 + 26,
							}
							local below = strip.bottom + Popover.GAP + size.h <= area.bottom
							local above = strip.top - Popover.GAP - size.h >= area.top
							local moved = Popover.away(anchor, size, safe, { avoid = strip })
							if not inside(moved, area) then
								error(`{where}: {show(moved)} leaves the safe area less 8`)
							end
							if (below or above) and overlaps(moved, strip) then
								error(`{where}: {show(moved)} covers the buttons {show(strip)}`)
							end
						end
					end
				end
			end
			T.expect(touch > 0).toBe(true)
		end
	)
end)
