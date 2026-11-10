--!strict
-- Owner 2026-11-10 ("too much text, things covering each other, too detailed descriptions, nothing folds"): the UI
-- plan's HUD zone map (Logic/HudZones) on the plan's PC screens and tablets, with Roblox's top bar 0, 36 and 58 px
-- tall: every place lies inside the HUD layer, no two persistent places meet, and the message zone starts GAP under
-- the target band in every named state and holds the alert line. UI package A owns this spec after package F: it adds
-- the plan's full state matrix to `states` (the checks take any HudZones.State) and empties KNOWN and THIN.

local fs = require("@lune/fs")

local HudStack = require("../src/shared/Logic/HudStack")
local HudZones = require("../src/shared/Logic/HudZones")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")

type Rect = HudZones.Rect
type State = HudZones.State
type Named = HudZones.Named

-- Real screens: the plan's three PC screens, then hudlayout.spec's virtual set as the real screens that give it (1920
-- x 1200, a 2560 x 1080 ultrawide, 1280 x 1024, 1024 x 768 and 1024 x 600 at the 0.6 floor, a short 1280 x 600
-- window); tablets: hudlayout.spec's TABLET list as real screens (1280 x 720, 1280 x 800, an iPad 1024 x 768 and a
-- 1024 x 600 tablet at the touch floor, an iPad Pro 1366 x 1024). The HUD layer always comes from Logic/UiScale.
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

type Screen = { name: string, device: string, touch: boolean, w: number, h: number, scale: number }

local function screens(): { Screen }
	local out: { Screen } = {}
	for _, set in { { touch = false, sizes = PC }, { touch = true, sizes = TABLET } } do
		for _, size in set.sizes do
			for _, bar in BARS do
				local w, h, k = HudZones.layer(size[1], size[2], set.touch, bar)
				local device = if set.touch then "tablet" else "pc"
				table.insert(out, {
					name = `{device} {size[1]}x{size[2]} bar {bar}`,
					device = device,
					touch = set.touch,
					w = w,
					h = h,
					scale = k,
				})
			end
		end
	end
	return out
end

-- The plan's named states, each quiet and busy (4 party members, the guide bar, 4 waiting buttons, 15 effects, the
-- Auto popover open).
local NAMED: { { name: string, state: State } } = {
	{ name = "no target", state = { target = "none" } },
	{ name = "monster target", state = { target = "monster" } },
	{ name = "arena panel", state = { target = "player", arena = "match" } },
	{ name = "dungeon boss bar with an add", state = { bossBar = true, add = true, target = "monster" } },
}

-- Every named state, quiet and busy; `base` is the name in NAMED.
local function states(): { { name: string, base: string, state: State } }
	local out = {}
	for _, named in NAMED do
		table.insert(out, { name = named.name, base = named.name, state = named.state })
		local busy = table.clone(named.state)
		busy.party = 4
		busy.guide = true
		busy.waiting = 4
		busy.effects = 15
		busy.autoPopover = true
		table.insert(out, { name = `{named.name}, busy`, base = named.name, state = busy })
	end
	return out
end

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

-- Every place of `state` on `screen`: HudZones.pc's, the message zone, the target band and the chat estimate at both
-- ends of its spread (PC).
local function places(screen: Screen, state: State): { Named }
	local s = table.clone(state)
	s.touch = screen.touch
	s.scale = screen.scale
	local all = HudZones.list(HudZones.pc(screen.w, screen.h, s))
	local function add(name: string, zone: string, rect: Rect)
		table.insert(all, { name = name, zone = zone, rect = rect, overlay = false })
	end
	add("messageZone", "Z8", HudZones.messageZone(screen.w, screen.h, s))
	add("targetBand", "band", HudZones.targetBand(screen.w, s))
	if not screen.touch then
		for _, grow in { -HudZones.CHAT.spread, HudZones.CHAT.spread } do
			add("chatEstimate", "chat", HudZones.chat(screen.w, screen.h, screen.scale, grow))
		end
	end
	return all
end

local function control(p: Named): boolean
	return p.name == "actionBar" or string.sub(p.name, 1, 7) == "corner."
end

-- Whether two places may meet: the band holds its own parts; the corner's buttons among themselves are
-- hudlayout.spec's (the skill arc's round buttons); the chat estimate is checked against Z1, Z2 and Z7 only (the plan:
-- Roblox's window, its size inferred); an overlay the player opens may cover the HUD but never the controls.
local function mayMeet(a: Named, b: Named): boolean
	if (a.zone == "band" and b.zone == "Z3") or (b.zone == "band" and a.zone == "Z3") then
		return true
	end
	if string.sub(a.name, 1, 7) == "corner." and string.sub(b.name, 1, 7) == "corner." then
		return true
	end
	local function chatFree(c: Named, o: Named): boolean
		return c.zone == "chat" and o.zone ~= "Z1" and o.zone ~= "Z2" and o.zone ~= "Z7"
	end
	if chatFree(a, b) or chatFree(b, a) then
		return true
	end
	if a.overlay or b.overlay then
		return not control(if a.overlay then b else a)
	end
	return false
end

-- Collisions the zone map does not remove yet, by device and pair, for package A (and B: the boss bar) to empty. A
-- listed pair that no longer meets anywhere fails, so the list only shrinks.
local KNOWN: { [string]: boolean } = {
	-- PC, short screens: the chat estimate at +20 % (at the 0.6 floor with a 36 or 58 px bar already at its estimate)
	-- reaches the [proposed] bark slot under 4 party members, and party rows 3 and 4 on 1024 x 600
	["pc bark/chatEstimate"] = true,
	["pc chatEstimate/party3"] = true,
	["pc chatEstimate/party4"] = true,
	-- Tablets ("PC zones apply" in the plan): 1210..1280 wide, so the 720-wide target band and boss bar do not fit
	-- between Z1 (to x 414) and the menu (from w - 374); a player target's 'Actions' button reaches the menu; 1210 wide,
	-- not even the 420-wide target frame and its effects clear the Auto button and the effects row
	["tablet auto/targetBand"] = true,
	["tablet effects/targetBand"] = true,
	["tablet portrait/targetBand"] = true,
	["tablet menuBar/targetBand"] = true,
	["tablet minimap/targetBand"] = true,
	["tablet column/targetBand"] = true,
	["tablet party1/targetBand"] = true,
	["tablet party2/targetBand"] = true,
	["tablet auto/bossBar"] = true,
	["tablet bossBar/portrait"] = true,
	["tablet bossBar/menuBar"] = true,
	["tablet bossBar/minimap"] = true,
	["tablet menuBar/targetActions"] = true,
	["tablet auto/target"] = true,
	["tablet auto/targetEffects"] = true,
	["tablet effects/targetEffects"] = true,
	["tablet addFrame/effects"] = true,
	["tablet arenaPanel/effects"] = true,
	-- Tablets up to 800 tall: the touch corner's skill arc and target button (HudStack.fixed) reach up into the minimap,
	-- the guide bar and the waiting row
	["tablet corner.attack/guide"] = true,
	["tablet corner.attack/waiting"] = true,
	["tablet corner.skill2/guide"] = true,
	["tablet corner.skill2/minimap"] = true,
	["tablet corner.skill3/guide"] = true,
	["tablet corner.skill3/minimap"] = true,
	["tablet corner.skill3/waiting"] = true,
	["tablet corner.skill4/guide"] = true,
	["tablet corner.skill4/minimap"] = true,
	["tablet corner.skill4/waiting"] = true,
	["tablet corner.skill5/guide"] = true,
	["tablet corner.skill5/minimap"] = true,
	["tablet corner.skill5/waiting"] = true,
	["tablet corner.target/guide"] = true,
	["tablet corner.target/minimap"] = true,
	["tablet corner.target/waiting"] = true,
}

-- Message zones shorter than the alert line (HudZones.MESSAGE.alert, the one message that always shows), by device and
-- named state, for package A to clear (package B places its messages in the zone). On tablets the PC band ends less
-- than 44 above 0.4 h, or below it: with the arena panel on 1280 x 720 and 1024 x 600 (8 to 40 px left), with the boss
-- bar on 1280 x 720 and 1024 x 600 (nothing left), 1280 x 800 (5 to 28 px) and 1024 x 768 under the 58 px bar (43.6
-- px). A listed state that has room everywhere fails, so the list only shrinks.
local THIN: { [string]: boolean } = {
	["tablet arena panel"] = true,
	["tablet dungeon boss bar with an add"] = true,
}

-- The pairs that meet on `screen` in `state` ("pc bark/chatEstimate"), with where.
local function collisions(screen: Screen, label: string, state: State, out: { [string]: string })
	local all = places(screen, state)
	for i, a in all do
		for j = i + 1, #all do
			local b = all[j]
			if not mayMeet(a, b) and HudStack.overlaps(a.rect, b.rect) then
				local first, second = a, b
				if b.name < a.name then
					first, second = b, a
				end
				local key = `{screen.device} {first.name}/{second.name}`
				if not out[key] then
					out[key] = `{screen.name}, {label}: {show(first.rect)} / {show(second.rect)}`
				end
			end
		end
	end
end

T.describe("HUD zones (owner 2026-11-10)", function()
	T.it("every place lies inside the HUD layer", function()
		for _, screen in screens() do
			local layer = { left = 0, top = 0, right = screen.w, bottom = screen.h }
			for _, named in states() do
				for _, p in places(screen, named.state) do
					if not inside(p.rect, layer) then
						error(`{screen.name}, {named.name}: {p.name} {show(p.rect)} leaves the layer`)
					end
				end
			end
		end
	end)

	T.it("no two persistent places meet but the listed ones, and every listed one still does", function()
		local found: { [string]: string } = {}
		for _, screen in screens() do
			for _, named in states() do
				collisions(screen, named.name, named.state, found)
			end
		end
		local bad = {}
		for key, where in found do
			if not KNOWN[key] then
				table.insert(bad, `{key} ({where})`)
			end
		end
		table.sort(bad)
		if #bad > 0 then
			error(`places meet:\n{table.concat(bad, "\n")}`)
		end
		for key in KNOWN do
			if not found[key] then
				error(`{key} no longer meets: take it off KNOWN`)
			end
		end
	end)

	T.it("the message zone starts GAP under the target band, which holds its parts", function()
		for _, screen in screens() do
			for _, named in states() do
				local s = table.clone(named.state)
				s.touch = screen.touch
				local band = HudZones.targetBand(screen.w, s)
				local zone = HudZones.messageZone(screen.w, screen.h, s)
				local where = `{screen.name}, {named.name}`
				T.expect(zone.top).toBe(band.bottom + HudStack.GAP)
				T.expect(zone.bottom >= zone.top).toBe(true)
				if zone.right <= zone.left then
					error(`{where}: a message zone with no width {show(zone)}`)
				end
				for _, p in HudZones.list(HudZones.pc(screen.w, screen.h, s)) do
					if p.zone == "Z3" and not inside(p.rect, band) then
						error(`{where}: {p.name} {show(p.rect)} leaves the target band {show(band)}`)
					end
				end
			end
		end
	end)

	T.it("the message zone holds the alert line but in the listed states", function()
		local found: { [string]: string } = {}
		for _, screen in screens() do
			for _, named in states() do
				local s = table.clone(named.state)
				s.touch = screen.touch
				local zone = HudZones.messageZone(screen.w, screen.h, s)
				local tall = zone.bottom - zone.top
				local key = `{screen.device} {named.base}`
				if tall < HudZones.MESSAGE.alert and not found[key] then
					found[key] = string.format("%s, %s: %.1f px", screen.name, named.name, tall)
				end
			end
		end
		local bad = {}
		for key, where in found do
			if not THIN[key] then
				table.insert(bad, `{key} ({where})`)
			end
		end
		table.sort(bad)
		if #bad > 0 then
			error(`message zones under the {HudZones.MESSAGE.alert} px alert line:\n{table.concat(bad, "\n")}`)
		end
		for key in THIN do
			if not found[key] then
				error(`{key} holds the alert line everywhere: take it off THIN`)
			end
		end
	end)

	T.it("the card slot stands under the column's floor, the bark slot under the last party row", function()
		for _, screen in screens() do
			if screen.touch then
				continue
			end
			local floor = HudStack.column(false, false, screen.w, screen.h, 0).floor
			local slot = HudZones.cardSlot(screen.w, screen.h)
			T.expect(slot.top).toBe(floor + HudStack.GAP)
			for kind in HudZones.CARDS do
				local card = HudZones.cardSlot(screen.w, screen.h, kind :: any)
				if not inside(card, slot) or card.bottom ~= slot.bottom then
					error(`{screen.name}: the {kind} card {show(card)} is not at the bottom of its slot {show(slot)}`)
				end
			end
		end
		for n = 0, HudZones.PARTY_MAX do
			local zones = HudZones.pc(1920, 1022, { party = n })
			local bark = assert(HudZones.barkSlot({ party = n }), "a PC bark slot")
			T.expect(#zones.party).toBe(n)
			local last = zones.party[n]
			T.expect(bark.top).toBe(if last then last.bottom + HudStack.GAP else HudStack.PARTY_TOP)
		end
		-- a tablet's column of panels stands there: the bark has no slot of its own
		T.expect(HudZones.barkSlot({ touch = true, party = 2 })).toBeNil()
	end)

	T.it("reproduces the zone map's numbers at 1920 x 1080 with the 58 px bar", function()
		local w, h = HudZones.layer(1920, 1080, false, 58)
		T.expect(h).toBe(1022)
		local function rect(left: number, top: number, right: number, bottom: number): Rect
			return { left = left, top = top, right = right, bottom = bottom }
		end
		local busy = HudZones.pc(w, h, { target = "player", party = 4, guide = true, waiting = 4, autoPopover = true })
		T.expect(busy.portrait).toEqual(rect(22, 22, 362, 132))
		T.expect(busy.auto).toEqual(rect(370, 88, 414, 132))
		T.expect(busy.autoPopover).toEqual(rect(422, 88, 592, 160))
		T.expect(busy.effects).toEqual(rect(22, 140, 414, 184))
		T.expect(busy.party[4]).toEqual(rect(22, 394, 282, 452))
		T.expect(busy.bark).toEqual(rect(22, 460, 402, 536))
		T.expect(busy.target).toEqual(rect(750, 22, 1170, 114))
		T.expect((assert(busy.targetEffects, "target effects")).bottom).toBe(164)
		T.expect(busy.menuBar).toEqual(rect(1546, 22, 1898, 74))
		T.expect(busy.minimap).toEqual(rect(1634, 82, 1898, 348))
		T.expect(busy.guide).toEqual(rect(1634, 356, 1898, 400))
		T.expect(busy.column).toEqual(rect(1598, 356 + 52 + 52, 1898, 830))
		T.expect(busy.card).toEqual(rect(1568, 838, 1898, 990))
		T.expect(busy.castLine).toEqual(rect(780, 896, 1140, 922))
		T.expect(busy.actionBar.top).toBe(h - 84)
		T.expect(busy.actionBar.bottom).toBe(h - 28)
		T.expect(busy.expBar.top).toBe(h - 12)
		T.expect(busy.expBar.bottom).toBe(h - 2)
		local arena = HudZones.pc(w, h, { target = "monster", arena = "match" })
		T.expect(arena.arenaPanel).toEqual(rect(750, 172, 1170, 240))
		local boss = HudZones.pc(w, h, { bossBar = true, add = true })
		T.expect(boss.bossBar).toEqual(rect(600, 22, 1320, 134))
		T.expect(boss.addFrame).toEqual(rect(750, 142, 1170, 234))
		T.expect((assert(boss.targetEffects, "add effects")).bottom).toBe(284)
		T.expect(boss.target).toBeNil()
		-- the message zone: 172 / 248 / 292 down to 0.40 h (409 / 399 / 397 at 1080p / 1366 / 1280)
		T.expect(HudZones.messageZone(w, h, {})).toEqual(rect(470, 172, 1450, h * 0.4))
		T.expect(HudZones.messageZone(w, h, { arena = "return" }).top).toBe(248)
		T.expect(HudZones.messageZone(w, h, { bossBar = true }).top).toBe(292)
		for _, case in { { 1366, 768, 399.4 }, { 1280, 720, 397.2 } } do
			local lw, lh = HudZones.layer(case[1], case[2], false, 58)
			T.expect(HudZones.messageZone(lw, lh, {}).bottom).toBeNear(case[3], 0.05)
		end
	end)

	T.it("takes its numbers from today's code", function()
		local function has(path: string, literal: string)
			if not string.find(fs.readFile(path), literal, 1, true) then
				error(`{path} no longer has '{literal}': HudZones copies it`)
			end
		end
		local hud = "src/client/UI/Screens/Hud/"
		local bar = HudZones.ACTION_BAR
		has("src/shared/Data/Skills/init.luau", `HOTBAR_SLOTS = {bar.slots},`)
		has(hud .. "init.luau", `local SKILL_SLOTS = {bar.slots}`)
		has(hud .. "init.luau", `local SLOT_SIZE = {bar.slot}`)
		has(hud .. "init.luau", "UDim2.new(0.5, 0, 1, -(14 + Theme.Padding.Medium))")
		has(hud .. "init.luau", "Padding = UDim.new(0, 6)")
		has(hud .. "init.luau", "Position = UDim2.new(0.5, 0, 1, -2)")
		has(hud .. "init.luau", "Size = UDim2.new(1, -8, 0, 10)")
		has("src/client/UI/Theme.luau", "Medium = 14,")
		has("src/client/UI/Theme.luau", `Large = {HudStack.MARGIN},`)
		has(hud .. "PotionBar.luau", `local SIZE = {bar.slot}`)
		has(hud .. "PotionBar.luau", "UDim2.fromOffset(SIZE * 3 + 12, SIZE)")
		-- 10 slots, Gap, 3 potions, MountGap and the mount, 6 apart (the plan inferred x 513..1407: 894 wide)
		T.expect(HudZones.actionBarWidth(false)).toBe(918)
		T.expect(HudZones.actionBarWidth(true)).toBe(828)
		local cast = HudZones.CAST_BAR
		has(hud .. "CastBar.luau", `UDim2.new(0.5, 0, 1, -{cast.bottom})`)
		has(hud .. "CastBar.luau", `UDim2.fromOffset({cast.w}, {cast.h})`)
		local t = HudZones.TARGET
		has(hud .. "TargetFrame.luau", `UDim2.fromOffset({t.w}, {t.h})`)
		has(hud .. "TargetFrame.luau", "UDim2.new(0, 0, 1, 10)")
		has(hud .. "TargetFrame.luau", "Size = 26,")
		has(hud .. "TargetFrame.luau", "UDim2.fromOffset(120, Theme.Size.MinTouch + 8)")
		has(hud .. "TargetFrame.luau", "UDim2.new(1, Theme.Padding.Medium + 8, 0, 0)")
		has(hud .. "TargetFrame.luau", "PaddingTop = UDim.new(0, 8)")
		has(hud .. "EffectIcons.luau", "UDim2.fromOffset(size * 8 + 28, size + 14)")
		T.expect(t.effectsW).toBe(26 * 8 + 28)
		T.expect(t.effectsH).toBe(26 + 14)
		-- the minimap's frame (its height is in HudStack.RIGHT_TOP), the guide bar, the arena panel, the party rows
		has(hud .. "Minimap.luau", "local SIZE = 220")
		has(hud .. "Minimap.luau", "UDim2.fromOffset(SIZE + 44, SIZE + 46)")
		T.expect(HudZones.MINIMAP_W).toBe(220 + 44)
		T.expect(HudStack.RIGHT_TOP - HudStack.MARGIN - HudStack.ICON - 2 * HudStack.GAP).toBe(220 + 46)
		has(hud .. "NavBar.luau", `local WIDTH = {HudZones.GUIDE_W}`)
		has(hud .. "ArenaPanel.luau", `local PANEL_WIDTH = {HudZones.ARENA_PANEL.w}`)
		has("src/client/UI/Screens/PartyFrames.luau", `local WIDTH = {HudZones.PARTY_FRAME.w}`)
		has("src/client/UI/Screens/PartyFrames.luau", `local HEIGHT = {HudZones.PARTY_FRAME.h}`)
		T.expect(HudStack.PARTY_ROW - HudZones.PARTY_FRAME.h).toBe(6)
		-- the thumbstick model (UI/HudAnchors) and the plan's number for it: 253..401 on an 844 x 390 phone
		local j = HudZones.THUMB
		has("src/client/UI/HudAnchors.luau", `local JOYSTICK = \{ x = {j.x}, y = {j.y}, w = {j.w}, h = {j.h} }`)
		local pw, ph = PhoneHud.area(PhoneHud.DEVICES[1])
		local thumb = HudZones.thumb(pw, ph)
		T.expect(thumb.top).toBeNear(252.9, 0.05)
		T.expect(thumb.bottom).toBeNear(401.2, 0.05)
	end)

	T.it("names elements of Screens/Hud and places pc returns", function()
		local sources = {}
		for _, file in fs.readDir("src/client/UI/Screens/Hud") do
			table.insert(sources, fs.readFile(`src/client/UI/Screens/Hud/{file}`))
		end
		local all = table.concat(sources, "\n")
		local zones = HudZones.pc(1920, 1022, {
			target = "player",
			arena = "match",
			party = 1,
			guide = true,
			waiting = 1,
			autoPopover = true,
		})
		local named: { [string]: boolean } = {}
		for _, p in HudZones.list(zones) do
			named[p.name] = true
		end
		for name, place in HudZones.ELEMENTS do
			if not string.find(all, `Name = "{name}"`, 1, true) then
				error(`no element {name} in Screens/Hud`)
			end
			if not named[place] then
				error(`{name}: pc has no place {place}`)
			end
		end
	end)

	T.it("tells PC, tablet and phone HUDs apart", function()
		for _, screen in screens() do
			T.expect(HudZones.device(screen.touch, screen.h)).toBe(screen.device)
		end
		for _, device in PhoneHud.DEVICES do
			local _, h = PhoneHud.area(device)
			T.expect(HudZones.device(true, h)).toBe("phone")
		end
	end)
end)
