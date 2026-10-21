--!strict
-- W29: the phone HUD (Logic/PhoneHud): on 844 x 390, 667 x 375 and 932 x 430 landscape phones nothing overlaps,
-- nothing leaves the safe area and every touch target keeps the minimum size.
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
		local stack = PhoneHud.rect(PhoneHud.PLACES.stack, 800, 440)
		T.expect(stack.bottom).toBe(440 - PhoneHud.STACK_BOTTOM)
	end)
end)
