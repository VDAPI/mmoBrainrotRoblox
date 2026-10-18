--!strict
-- S117: monster telegraphs 2.0 (Logic/Telegraph): progress, the filling front, the band covering the server's area at
-- the blow, the server's area rule, the rim pulse, the flash and the fade.

local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local T = require("./Test")
local Telegraph = require("../src/shared/Logic/Telegraph")

local CFG = Config.Telegraph

type Area = { label: string, shape: Telegraph.Shape, dims: Telegraph.Dims }

-- Every area of the game: Elite II abilities and boss attacks.
local function areas(): { Area }
	local out: { Area } = {}
	for id, a in MonsterAbilities.byId do
		table.insert(out, {
			label = id,
			shape = a.shape,
			dims = { r = a.radius, ir = a.inner, an = a.angle, l = a.length, w = a.width },
		})
	end
	for _, boss in Bosses.all do
		for _, a in boss.attacks do
			table.insert(out, {
				label = `{boss.id}.{a.id}`,
				shape = a.shape,
				dims = { r = a.radius, ir = a.inner, an = a.angle, l = a.length, w = a.width },
			})
		end
	end
	return out
end

-- Share of the area's grid points covered by the band, and the band's points outside the area per area point. A
-- cone's first stud counts whole on the server (any angle): it is left out of the coverage (the band is the cone).
local function coverage(area: Area, p: number, segments: number): (number, number)
	local pieces = Telegraph.band(area.shape, p, area.dims, segments)
	local reach = if area.shape == "line"
		then math.max(Telegraph.length(area.dims), Telegraph.width(area.dims))
		else Telegraph.radius(area.shape, area.dims)
	-- the grid is shifted off the round numbers, so no point sits exactly on an edge (a ray of the cone, the radius)
	local step = reach / 60
	local inside, covered, outside = 0, 0, 0
	local x = -reach * 1.1 + step * 0.371
	while x <= reach * 1.1 do
		local z = -reach * 1.1 + step * 0.613
		while z <= reach * 1.1 do
			local isIn = Telegraph.contains(area.shape, area.dims, x, z)
			if area.shape == "cone" and math.sqrt(x * x + z * z) < 1 then
				isIn = false
			end
			local inBand = false
			for _, piece in pieces do
				if Telegraph.inPiece(piece, x, z) then
					inBand = true
					break
				end
			end
			if isIn then
				inside += 1
				if inBand then
					covered += 1
				end
			elseif inBand and not (area.shape == "cone" and math.sqrt(x * x + z * z) < 1) then
				outside += 1
			end
			z += step
		end
		x += step
	end
	return covered / math.max(1, inside), outside / math.max(1, inside)
end

T.describe("Telegraph (S117)", function()
	T.it("12. progress runs 0 -> 1 over the windup, clamped to 0.2..5", function()
		T.expect(Telegraph.progress(0, 1.2)).toBe(0)
		T.expect(Telegraph.progress(1.2, 1.2)).toBe(1)
		T.expect(Telegraph.progress(0.6, 1.2)).toBeNear(0.5, 1e-9)
		T.expect(Telegraph.progress(0.1, 0.05)).toBeNear(0.5, 1e-9) -- windup 0.05 counts as 0.2
		T.expect(Telegraph.progress(5, 9)).toBe(1)
		T.expect(Telegraph.windup(9)).toBe(5)
		T.expect(Telegraph.windup(0.01)).toBe(0.2)
	end)

	T.it("13. the front moves from the edge to the centre (a ring to its safe centre)", function()
		local dims: Telegraph.Dims = { r = 10, ir = 4, an = 90, l = 20, w = 6 }
		T.expect(Telegraph.front("circle", 0, dims)).toBe(10)
		T.expect(Telegraph.front("circle", 1, dims)).toBe(0)
		T.expect(Telegraph.front("ring", 0, dims)).toBe(10)
		T.expect(Telegraph.front("ring", 1, dims)).toBe(4)
		T.expect(Telegraph.front("cone", 1, dims)).toBe(0)
		T.expect(Telegraph.front("line", 0, dims)).toBe(3)
		T.expect(Telegraph.front("line", 1, dims)).toBe(0)
		for _, shape in { "circle", "ring", "cone", "line" } :: { Telegraph.Shape } do
			local last = math.huge
			for i = 0, 20 do
				local f = Telegraph.front(shape, i / 20, dims)
				T.expect({ shape, f <= last }).toEqual({ shape, true })
				if shape == "ring" then
					T.expect(f >= 4).toBe(true)
				end
				last = f
			end
		end
	end)

	T.it("14. at the blow the band covers the server's area (>= 99 %, <= 5 % outside), empty at the start", function()
		for _, area in areas() do
			for _, segments in { CFG.segments, CFG.segmentsLow } do
				local full, excess = coverage(area, 1, segments)
				T.expect({ area.label, segments, full >= 0.99 }).toEqual({ area.label, segments, true })
				T.expect({ area.label, segments, excess <= 0.05 }).toEqual({ area.label, segments, true })
				local empty = coverage(area, 0, segments)
				T.expect({ area.label, segments, empty }).toEqual({ area.label, segments, 0 })
				local last = -1
				for i = 1, 4 do
					local c = coverage(area, i / 4, segments)
					T.expect({ area.label, c >= last - 1e-9 }).toEqual({ area.label, true })
					last = c
				end
			end
			local count = #Telegraph.band(area.shape, 0.5, area.dims, CFG.segments)
			local low = #Telegraph.band(area.shape, 0.5, area.dims, CFG.segmentsLow)
			if area.shape == "circle" or area.shape == "ring" then
				T.expect({ area.label, count, low }).toEqual({ area.label, CFG.segments, CFG.segmentsLow })
			elseif area.shape == "cone" then
				T.expect({ area.label, count, low }).toEqual({ area.label, CFG.segments // 2, CFG.segmentsLow // 2 })
			else
				T.expect({ area.label, count }).toEqual({ area.label, 2 })
			end
		end
	end)

	T.it("15. contains follows the server's rule on the edges", function()
		local circle: Telegraph.Dims = { r = 8 }
		T.expect(Telegraph.contains("circle", circle, 0, -7.99)).toBe(true)
		T.expect(Telegraph.contains("circle", circle, 0, -8.01)).toBe(false)
		T.expect(Telegraph.contains("circle", circle, 0, 0, 12.5)).toBe(false) -- above the height window
		local cone: Telegraph.Dims = { r = 10, an = 90 }
		local a = math.rad(44.9)
		T.expect(Telegraph.contains("cone", cone, -math.sin(a) * 5, -math.cos(a) * 5)).toBe(true)
		local b = math.rad(45.1)
		T.expect(Telegraph.contains("cone", cone, -math.sin(b) * 5, -math.cos(b) * 5)).toBe(false)
		T.expect(Telegraph.contains("cone", cone, 0, 0.5)).toBe(true) -- the first stud counts whole
		T.expect(Telegraph.contains("cone", cone, 0, 3)).toBe(false) -- behind
		T.expect(Telegraph.contains("cone", cone, 0, -10.01)).toBe(false)
		local line: Telegraph.Dims = { l = 20, w = 6 }
		T.expect(Telegraph.contains("line", line, 2.99, -19.99)).toBe(true)
		T.expect(Telegraph.contains("line", line, 3.01, -10)).toBe(false)
		T.expect(Telegraph.contains("line", line, 0, 0.01)).toBe(false)
		T.expect(Telegraph.contains("line", line, 0, -20.01)).toBe(false)
		local ring: Telegraph.Dims = { r = 30, ir = 8 }
		T.expect(Telegraph.contains("ring", ring, 0, -8)).toBe(false) -- the safe centre's edge is safe
		T.expect(Telegraph.contains("ring", ring, 0, -8.01)).toBe(true)
		T.expect(Telegraph.contains("ring", ring, 0, -30)).toBe(true)
		T.expect(Telegraph.contains("ring", ring, 0, -30.01)).toBe(false)
	end)

	T.it("16. the rim beats faster towards the blow, the flash and the fade come after it", function()
		local last = math.huge
		for i = 0, 10 do
			local period = Telegraph.pulsePeriod(i / 10, CFG)
			T.expect(period <= last).toBe(true)
			last = period
		end
		T.expect(Telegraph.pulsePeriod(0, CFG)).toBeNear(CFG.pulseSlow, 1e-9)
		T.expect(Telegraph.pulsePeriod(1, CFG)).toBeNear(CFG.pulseFast, 1e-9)
		local w = 1.3
		for i = 0, 100 do
			local t = i * 0.02
			local rim = Telegraph.rimPulse(t, w, CFG)
			T.expect(rim >= 0 and rim <= 1).toBe(true)
			local flash = Telegraph.flashing(t, w, CFG)
			local inFlash = t >= w and t <= w + CFG.flashSeconds
			if not inFlash then
				T.expect({ t, flash }).toEqual({ t, 0 })
			end
		end
		T.expect(Telegraph.flashing(w, w, CFG)).toBe(1)
		T.expect(Telegraph.fade(w, w, CFG)).toBe(0)
		T.expect(Telegraph.fade(w + CFG.flashSeconds + CFG.fadeSeconds, w, CFG)).toBeNear(1, 1e-9)
		T.expect(Telegraph.fade(w + CFG.flashSeconds + CFG.fadeSeconds + 0.01, w, CFG)).toBe(1)
		T.expect(Telegraph.duration(w, CFG)).toBeNear(w + CFG.flashSeconds + CFG.fadeSeconds, 1e-9)
		T.expect(Telegraph.fillAlpha(0, CFG)).toBe(CFG.fillFrom)
		T.expect(Telegraph.fillAlpha(1, CFG)).toBe(CFG.fillTo)
	end)
end)
