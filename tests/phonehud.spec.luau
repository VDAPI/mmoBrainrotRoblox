--!strict
-- W29: the phone HUD (Logic/PhoneHud): on 844 x 390, 667 x 375 and 932 x 430 landscape phones nothing overlaps,
-- nothing leaves the safe area and every touch target keeps the minimum size. UI plan package A (owner 2026-11-10,
-- "things covering each other"; the plan's L5): the same under Roblox's top bar of 0, 36 and 58 px, nothing in the
-- thumb zone, the right thumb's controls at least 52, the stack's lines as the zone map counts them, and the grid's
-- parts (one Auto button, the '⋯' by the target, the minimap at 0.5 under 420, the drawer clear of PvP).
local fs = require("@lune/fs")

local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")

T.describe("Phone HUD (W29)", function()
	T.it("phones in landscape are compact, tablets and PC are not", function()
		for _, d in PhoneHud.DEVICES do
			local _, h = PhoneHud.area(d)
			T.expect(PhoneHud.compact(true, h)).toBe(true)
		end
		-- a 1024 x 768 tablet at the touch minimum scale, and a mouse on a short window
		T.expect(PhoneHud.compact(true, 768 / PhoneHud.SCALE)).toBe(false)
		T.expect(PhoneHud.compact(false, 400)).toBe(false)
	end)

	T.it("nothing overlaps and nothing leaves the screen on the phones", function()
		for _, d in PhoneHud.DEVICES do
			local w, h = PhoneHud.area(d)
			local clashes, outside = PhoneHud.problems(w, h)
			if #clashes > 0 or #outside > 0 then
				error(`{d.name}: overlaps {table.concat(clashes, ", ")}; outside {table.concat(outside, ", ")}`)
			end
		end
	end)

	T.it("every touch target is at least 44 points on its short side", function()
		for name, place in PhoneHud.PLACES do
			if place.touch then
				local side = math.min(place.w, place.h) * PhoneHud.SCALE
				if side < PhoneHud.MIN_TOUCH * PhoneHud.SCALE - 1e-6 then
					error(`{name}: {side} points`)
				end
			end
		end
	end)

	T.it("UI plan phase 1: the emote button left the sprint row (a tile of the game menu now)", function()
		T.expect(PhoneHud.place("emote")).toBeNil()
		T.expect(PhoneHud.place("sprint") ~= nil).toBe(true)
		T.expect(PhoneHud.place("mount") ~= nil).toBe(true)
		-- the drawer button and the PvP toggle under it keep their places by the minimap
		T.expect(PhoneHud.place("menuToggle") ~= nil).toBe(true)
		T.expect(PhoneHud.place("pvp") ~= nil).toBe(true)
	end)

	T.it("the skill arc keeps its buttons apart and clear of the attack button", function()
		local attack = PhoneHud.rect(PhoneHud.PLACES.attack, 800, 440)
		for i = 1, #PhoneHud.ANGLES do
			local a = PhoneHud.rect(PhoneHud.PLACES[`skill{i}`], 800, 440)
			T.expect(PhoneHud.overlaps(a, attack)).toBe(false)
			if i > 1 then
				local b = PhoneHud.rect(PhoneHud.PLACES[`skill{i - 1}`], 800, 440)
				T.expect(PhoneHud.overlaps(a, b)).toBe(false)
			end
		end
	end)

	T.it("measures overlaps of rectangles and round buttons", function()
		local function r(l: number, t: number, s: number, round: boolean): PhoneHud.Rect
			return { left = l, top = t, right = l + s, bottom = t + s, round = round }
		end
		T.expect(PhoneHud.overlaps(r(0, 0, 10, false), r(5, 5, 10, false))).toBe(true)
		T.expect(PhoneHud.overlaps(r(0, 0, 10, false), r(10, 0, 10, false))).toBe(false)
		-- two circles whose boxes touch at the corner do not overlap
		T.expect(PhoneHud.overlaps(r(0, 0, 10, true), r(8, 8, 10, true))).toBe(false)
		T.expect(PhoneHud.overlaps(r(0, 0, 10, true), r(9, 9, 10, false))).toBe(false)
		T.expect(PhoneHud.overlaps(r(0, 0, 10, true), r(4, 4, 10, false))).toBe(true)
	end)

	T.it("turns a place into a UDim2 and an anchor point", function()
		local xs, xo, ys, yo, ax, ay = PhoneHud.udim(PhoneHud.PLACES.minimap)
		T.expect(xs).toBe(1)
		T.expect(xo).toBe(-8)
		T.expect(ys).toBe(0)
		T.expect(yo).toBe(8)
		T.expect(ax).toBe(1)
		T.expect(ay).toBe(0)
		-- UI plan package A: the stack ends 8 over the thumb zone (or 28 over the bottom, whichever is higher)
		local stack = PhoneHud.rect(PhoneHud.PLACES.stack, 800, 440)
		T.expect(stack.bottom).toBe(math.min(440 - PhoneHud.STACK_BOTTOM, math.round(440 * PhoneHud.THUMB_TOP) - 8))
		T.expect(stack.bottom).toBe(PhoneHud.stackBottom(440))
	end)
end)

T.describe("Phone HUD grid (UI plan package A)", function()
	T.it(
		"on every phone under a top bar of 0, 36 and 58 px: no overlap, nothing off it, in the thumb zone or small",
		function()
			local lines: { [string]: number } = {}
			for _, d in PhoneHud.DEVICES do
				for _, bar in { 0, 36, 58 } do
					local w, h = PhoneHud.area(d, bar)
					local where = `{d.name} bar {bar}`
					local clashes, outside, faults = PhoneHud.problems(w, h)
					if #clashes > 0 or #outside > 0 or #faults > 0 then
						error(
							`{where}: overlaps {table.concat(clashes, ", ")}; outside {table.concat(outside, ", ")}; `
								.. table.concat(faults, ", ")
						)
					end
					-- the stack: 52-px lines from y 153 down to min(H - 28, round(0.58 H) - 8), at least one
					T.expect(PhoneHud.stackBottom(h)).toBe(math.min(h - 28, math.round(0.58 * h) - 8))
					T.expect({ where, PhoneHud.stackLines(h) >= 1 }).toEqual({ where, true })
					lines[where] = PhoneHud.stackLines(h)
					-- the minimap at 0.5 when the layer is under 420 high, else 0.6
					T.expect(PhoneHud.minimapScale(h)).toBe(if h < 420 then 0.5 else 0.6)
					-- the open drawer (left of its button, Hud/init) never reaches the PvP toggle under the button
					local places = PhoneHud.places(w, h)
					local toggle = PhoneHud.rect(places.menuToggle, w, h)
					local pvp = PhoneHud.rect(places.pvp, w, h)
					T.expect({ where, pvp.left >= toggle.left }).toEqual({ where, true })
				end
			end
			-- the zone map's counts
			T.expect(lines["844x390 bar 0"]).toBe(1)
			T.expect(lines["844x390 bar 58"]).toBe(1)
			T.expect(lines["932x430 bar 0"]).toBe(2)
			-- a fault shows: a button in the thumb zone, a control under 52
			T.expect(PhoneHud.overlaps(PhoneHud.thumb(886, 436), { left = 40, top = 300, right = 92, bottom = 352 }))
				.toBe(true)
		end
	)

	T.it("the right thumb's controls are at least 52, every other touch target at least 44", function()
		for _, name in { "attack", "skill1", "skill2", "skill3", "skill4", "skill5", "menuToggle", "sprint", "mount" } do
			local place = assert(PhoneHud.PLACES[name], name)
			T.expect({ name, place.control == true, math.min(place.w, place.h) >= PhoneHud.CONTROL }).toEqual({
				name,
				true,
				true,
			})
		end
		for name, place in PhoneHud.PLACES do
			if place.touch then
				T.expect({ name, math.min(place.w, place.h) >= PhoneHud.MIN_TOUCH }).toEqual({ name, true })
			end
		end
	end)

	T.it(
		"one Auto button, a '⋯' by the target, the cast line in M, the party as tiles, the death screen centred",
		function()
			-- one Auto button (its popover holds Lure, Auto Hunt and Auto Potion), in the row with the effects
			T.expect(PhoneHud.place("auto") ~= nil).toBe(true)
			for _, gone in { "lure", "autoGrind", "autoPotion", "blessing", "actions", "pool", "pvpBadge" } do
				T.expect({ gone, PhoneHud.place(gone) }).toEqual({ gone, nil })
			end
			local auto, effects = PhoneHud.PLACES.auto, PhoneHud.PLACES.effects
			T.expect(auto.y).toBe(effects.y)
			local popover = fs.readFile("src/client/UI/Screens/Hud/AutoGroup.luau")
			T.expect(string.find(popover, "PhoneHud.AUTO_POPOVER", 1, true) ~= nil).toBe(true)
			-- the '⋯' actions button: 44 x 44 right of the target
			local target, actions = PhoneHud.PLACES.target, PhoneHud.PLACES.targetActions
			T.expect({ actions.w, actions.h }).toEqual({ 44, 44 })
			T.expect(actions.x >= target.x + target.w).toBe(true)
			-- the cast line and the target's effects in the M zone
			for _, d in PhoneHud.DEVICES do
				local w, h = PhoneHud.area(d, 0)
				local left, top, right, bottom = PhoneHud.mZone(w, h)
				for _, name in { "castBar", "targetEffects" } do
					local r = PhoneHud.rect(PhoneHud.places(w, h)[name], w, h)
					local inside = r.left >= left and r.top >= top and r.right <= right and r.bottom <= bottom
					T.expect({ d.name, name, inside }).toEqual({ d.name, name, true })
				end
			end
			-- the PvP countdown inside its toggle; the party at most 3 tiles of a stack line, then '+N'
			local pvp = fs.readFile("src/client/UI/Screens/Hud/PvpToggle.luau")
			T.expect(string.find(pvp, 'Name = "Countdown"', 1, true) ~= nil).toBe(true)
			local party = fs.readFile("src/client/UI/Screens/PartyFrames.luau")
			T.expect(string.find(party, "local TILES = 3", 1, true) ~= nil).toBe(true)
			T.expect(string.find(party, "local TILE = PhoneHud.LINE", 1, true) ~= nil).toBe(true)
			-- the death screen centred in the HUD's layer
			local death = fs.readFile("src/client/UI/Screens/Hud/DeathScreen.luau")
			T.expect(string.find(death, "Position = UDim2.fromScale(0.5, 0.5)", 1, true) ~= nil).toBe(true)
		end
	)
end)
