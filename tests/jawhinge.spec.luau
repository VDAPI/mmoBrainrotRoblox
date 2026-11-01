--!strict
-- Template animation (owner 2026-11-01: Vaelgrath's mouth is modelled open and has no jaw bone): Logic/JawHinge finds
-- the lower jaw of a head (tests/JawHingeMesh: an open-mouthed snout with teeth, a spike under the chin, a beard, a
-- neck), puts the hinge at the back of the mouth, closes it until the teeth tips nearly meet (never into each other),
-- blends the cheek near the hinge, keeps a texture seam whole, never moves the upper jaw, the skull or the neck, gives
-- up on a closed mouth; moves a vertex's head skin onto the jaw bone; and opens the jaw along Vaelgrath's actions
-- (Data/BipedRigs `jaw` on Data/BipedStyles `wyvern`).
local ActionFx = require("../src/shared/Logic/ActionFx")
local BipedRigs = require("../src/shared/Data/BipedRigs")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local JawHinge = require("../src/shared/Logic/JawHinge")
local Mesh = require("./JawHingeMesh")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MotionFx = require("../src/shared/Data/MotionFx")
local T = require("./Test")

local O = BipedRigs.jaw("vaelgrath") :: JawHinge.Options

local function planOf(m: Mesh.Mesh, o: JawHinge.Options?): JawHinge.Plan
	local plan, why = JawHinge.plan(m.pos, m.head, m.tris, o or O)
	if not plan then
		error(`no plan: {why}`)
	end
	return plan
end

-- Each vertex's share of the jaw (0 when it is not on it).
local function sharesOf(m: Mesh.Mesh, plan: JawHinge.Plan): { number }
	local out = table.create(#m.head, 0)
	for j, i in plan.idx do
		out[i] = plan.share[j]
	end
	return out
end

local function eachIn(m: Mesh.Mesh, prefix: string, fn: (number) -> ())
	for name, range in m.parts do
		if string.sub(name, 1, #prefix) == prefix and #range == 2 then
			for i = range[1], range[2] do
				fn(i)
			end
		end
	end
end

-- The side view (z, y) of every face whose corners all lie in parts starting with `prefix`.
local function facesOf(m: Mesh.Mesh, prefix: string): { { { number } } }
	local inPart = table.create(#m.head, false)
	eachIn(m, prefix, function(i)
		inPart[i] = true
	end)
	local out = {}
	for f = 0, #m.tris // 3 - 1 do
		local a, b, c = m.tris[f * 3 + 1], m.tris[f * 3 + 2], m.tris[f * 3 + 3]
		if inPart[a] and inPart[b] and inPart[c] then
			table.insert(out, {
				{ m.pos[a * 3], m.pos[a * 3 - 1] },
				{ m.pos[b * 3], m.pos[b * 3 - 1] },
				{ m.pos[c * 3], m.pos[c * 3 - 1] },
			})
		end
	end
	return out
end

local function insideTri(t: { { number } }, z: number, y: number): boolean
	local function side(p: { number }, q: { number }): number
		return (q[1] - p[1]) * (y - p[2]) - (q[2] - p[2]) * (z - p[1])
	end
	local d1, d2, d3 = side(t[1], t[2]), side(t[2], t[3]), side(t[3], t[1])
	local neg = d1 < -1e-12 or d2 < -1e-12 or d3 < -1e-12
	local pos = d1 > 1e-12 or d2 > 1e-12 or d3 > 1e-12
	return not (neg and pos) and math.abs(d1) + math.abs(d2) + math.abs(d3) > 1e-12
end

-- Whether the lower jaw and its teeth turned up by `angle` reach into the upper jaw or its teeth anywhere in the front
-- part of the mouth (the side view; the edges of the lower faces sampled densely).
local function bites(m: Mesh.Mesh, plan: JawHinge.Plan, angle: number): boolean
	local upper = facesOf(m, "upper")
	for _, t in facesOf(m, "lower") do
		for e = 1, 3 do
			local p, q = t[e], t[e % 3 + 1]
			for k = 0, 40 do
				local w = k / 40
				local z, y = p[1] + (q[1] - p[1]) * w, p[2] + (q[2] - p[2]) * w
				if z < -0.45 then
					local ty, tz = JawHinge.turn(plan, angle, y, z)
					for _, u in upper do
						if insideTri(u, tz, ty) then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

T.describe("JawHinge plan", function()
	T.it("finds the lower jaw, its teeth and the spike under the chin, all moving wholly with it", function()
		local m = Mesh.build()
		local plan = planOf(m)
		local share = sharesOf(m, plan)
		for _, v in m.parts.lowerFront do
			T.expect(share[v]).toBe(1)
		end
		eachIn(m, "lowerTooth", function(i)
			T.expect(share[i]).toBe(1)
		end)
		eachIn(m, "spike", function(i)
			T.expect(share[i]).toBe(1)
		end)
		T.expect(plan.full >= 20).toBe(true)
	end)

	T.it("never moves the upper jaw, its teeth, the skull, the neck or the throat behind the hinge", function()
		local m = Mesh.build()
		local share = sharesOf(m, planOf(m))
		for _, prefix in { "upperTooth", "skull", "neck", "throat" } do
			eachIn(m, prefix, function(i)
				T.expect(share[i]).toBe(0)
			end)
		end
		-- the upper jaw: at most a trace at the mouth's corner, where it is one vertex with the lower jaw
		eachIn(m, "upper", function(i)
			T.expect(share[i] <= 0.05).toBe(true)
		end)
	end)

	T.it("puts the hinge at the back of the mouth and the seam through the opening", function()
		local m = Mesh.build()
		local plan = planOf(m)
		local cell = plan.snout / O.cells
		T.expect(plan.snout).toBeNear(1, 1e-9)
		-- the corner where the jaws meet (z -0.3, y 0), the hinge 0.06 behind and 0.02 under it
		T.expect(plan.corner[2]).toBeNear(-0.3, 2 * cell)
		T.expect(plan.corner[1]).toBeNear(0, 2 * cell)
		T.expect(plan.hinge[2]).toBeNear(-0.3 + O.hinge.back, 2 * cell)
		T.expect(plan.hinge[1]).toBeNear(-O.hinge.down, 2 * cell)
		-- the seam runs between the jaws: under the upper jaw's underside, over the lower jaw's top
		for _, z in { -0.4, -0.6, -0.8 } do
			local y = plan.seam[1] + plan.seam[2] * z
			T.expect(y < 0 and y > Mesh.lowerTop(z)).toBe(true)
		end
		T.expect(plan.columns >= O.minColumns).toBe(true)
	end)

	T.it("closes until the teeth tips nearly meet, never into each other", function()
		local m = Mesh.build()
		local plan = planOf(m)
		T.expect(plan.closed > math.rad(5)).toBe(true)
		T.expect(bites(m, plan, plan.closed)).toBe(false)
		-- not much short of the contact: a little past the margin they meet
		local margin = O.margin * plan.snout / plan.tipRadius
		T.expect(bites(m, plan, plan.closed + margin + math.rad(1.5))).toBe(true)
		-- the opening at the front shrinks from as modelled to closed, and opens past the model when asked
		local modelled = JawHinge.gap(plan, 0)
		local closed = JawHinge.gap(plan, plan.closed)
		T.expect(modelled > closed and closed > 0).toBe(true)
		T.expect(JawHinge.gap(plan, plan.closed - math.rad(40)) > modelled).toBe(true)
	end)

	T.it("lets a data override set the closed turn (Studio tuning), within the cap", function()
		local m = Mesh.build()
		local o = table.clone(O)
		o.closed = 7
		T.expect(planOf(m, o).closed).toBeNear(math.rad(7), 1e-9)
		o.closed = nil
		o.maxClosed = 4
		T.expect(planOf(m, o).closed).toBeNear(math.rad(4), 1e-9)
	end)

	T.it("blends the cheek: a beard behind the corner hangs on with a share falling off behind the hinge", function()
		local m = Mesh.build()
		local plan = planOf(m)
		local share = sharesOf(m, plan)
		local range = m.parts.beard
		local any = false
		for i = range[1], range[2] do
			T.expect(share[i] < 1).toBe(true)
			any = any or share[i] > 0
		end
		T.expect(any).toBe(true)
		-- ahead of the blend all, behind it nothing, monotonic between (by distance ahead of the hinge)
		local pairs: { { number } } = {}
		for j, i in plan.idx do
			local y, z = m.pos[i * 3 - 1], m.pos[i * 3]
			local below = plan.seam[1] + plan.seam[2] * z - y
			if below > O.blend.seam * plan.snout then
				table.insert(pairs, { plan.hinge[2] - z, plan.share[j] })
			end
		end
		table.sort(pairs, function(a, b)
			return a[1] < b[1]
		end)
		for k = 2, #pairs do
			T.expect(pairs[k][2] >= pairs[k - 1][2] - 1e-9).toBe(true)
		end
		for _, p in pairs do
			if p[1] >= O.blend.front * plan.snout then
				T.expect(p[2]).toBe(1)
			end
		end
	end)

	T.it("moves the copies of a vertex along a texture seam as one", function()
		local m = Mesh.build()
		local share = sharesOf(m, planOf(m))
		local range = m.parts.seam
		for k = 0, 2 do
			T.expect(share[range[1] + k]).toBe(share[m.parts.lowerFront[k + 1]])
		end
	end)

	T.it("keeps the corner when a tooth closes the opening near it", function()
		local m = Mesh.build({ nearTooth = true })
		local plan = planOf(m)
		local cell = plan.snout / O.cells
		T.expect(plan.corner[2]).toBeNear(-0.3, 3 * cell)
		local share = sharesOf(m, plan)
		eachIn(m, "nearTooth", function(i)
			T.expect(share[i]).toBe(0)
		end)
	end)

	T.it("does not depend on the model's size", function()
		local m = Mesh.build()
		local a = planOf(m)
		local b = planOf(Mesh.scaled(m, 2.5))
		T.expect(b.idx).toEqual(a.idx)
		T.expect(b.closed).toBeNear(a.closed, 1e-6)
		T.expect(b.hinge[2]).toBeNear(a.hinge[2] * 2.5, 1e-6)
		for j = 1, #a.share do
			T.expect(b.share[j]).toBeNear(a.share[j], 1e-6)
		end
	end)

	T.it("gives up on a closed mouth, a mesh without a head and a mesh too small", function()
		local closed = Mesh.build({ closed = true })
		local plan, why = JawHinge.plan(closed.pos, closed.head, closed.tris, O)
		T.expect(plan).toBeNil()
		T.expect(#why > 0).toBe(true)
		local m = Mesh.build()
		local none = table.create(#m.head, 0)
		T.expect((JawHinge.plan(m.pos, none, m.tris, O))).toBeNil()
		T.expect((JawHinge.plan({ 0, 0, 0 }, { 1 }, nil, O))).toBeNil()
	end)

	T.it("draws the side view when it gives up (Studio prints it), and only then", function()
		local closed = Mesh.build({ closed = true })
		local view: { string } = {}
		T.expect((JawHinge.plan(closed.pos, closed.head, closed.tris, O, nil, view))).toBeNil()
		T.expect(#view > 4).toBe(true)
		local width = #view[1]
		local faces = 0
		for _, line in view do
			T.expect(#line).toBe(width)
			T.expect(string.match(line, "^[#o.| ]*$") ~= nil).toBe(true)
			faces += #string.gsub(line, "[^#]", "")
		end
		T.expect(faces > 0).toBe(true)
		local open = Mesh.build()
		local fine: { string } = {}
		T.expect(JawHinge.plan(open.pos, open.head, open.tris, O, nil, fine) ~= nil).toBe(true)
		T.expect(#fine).toBe(0)
	end)

	T.it("a tooth wider than `bridge` splits the mouth, a wider `bridge` joins it again", function()
		local m = Mesh.build({ nearTooth = true })
		local narrow = table.clone(O)
		narrow.bridge = 0
		local wide = table.clone(O)
		wide.bridge = 6
		local a = JawHinge.plan(m.pos, m.head, m.tris, narrow)
		local b = JawHinge.plan(m.pos, m.head, m.tris, wide)
		T.expect(b ~= nil).toBe(true)
		if a and b then
			T.expect(b.columns >= a.columns).toBe(true)
		end
	end)

	T.it("never errors without faces (the side view and the mesh by the vertices alone)", function()
		local m = Mesh.build()
		local ok = pcall(function()
			JawHinge.plan(m.pos, m.head, nil, O)
		end)
		T.expect(ok).toBe(true)
	end)

	T.it("turns a point about the hinge (the hinge stays, a turn and back is the point)", function()
		local plan = planOf(Mesh.build())
		local y, z = JawHinge.turn(plan, 0.4, plan.hinge[1], plan.hinge[2])
		T.expect(y).toBeNear(plan.hinge[1], 1e-12)
		T.expect(z).toBeNear(plan.hinge[2], 1e-12)
		local y1, z1 = JawHinge.turn(plan, 0.3, -0.25, -0.8)
		local y2, z2 = JawHinge.turn(plan, -0.3, y1, z1)
		T.expect(y2).toBeNear(-0.25, 1e-12)
		T.expect(z2).toBeNear(-0.8, 1e-12)
		-- + closes: a point ahead of the hinge goes up
		T.expect(y1 > -0.25).toBe(true)
	end)
end)

T.describe("JawHinge reweigh", function()
	local HEAD = { [10] = true, [11] = true }
	T.it("moves its share of the head skin onto the jaw, the rest as it was, summing to 1", function()
		local bones, weights = JawHinge.reweigh({ 10, 3 }, { 0.7, 0.3 }, HEAD, 0.5, 99)
		assert(bones and weights, "a vertex with head skin is reweighed")
		local by: { [number]: number } = {}
		local sum = 0
		for k, b in bones do
			by[b] = weights[k]
			sum += weights[k]
		end
		T.expect(by[10]).toBeNear(0.35, 1e-9)
		T.expect(by[99]).toBeNear(0.35, 1e-9)
		T.expect(by[3]).toBeNear(0.3, 1e-9)
		T.expect(sum).toBeNear(1, 1e-9)
	end)

	T.it("moves the head bone's children too, drops a head bone with nothing left and keeps four bones", function()
		local bones, weights = JawHinge.reweigh({ 10, 11, 1, 2, 3, 4 }, { 0.4, 0.2, 0.15, 0.1, 0.1, 0.05 }, HEAD, 1, 99)
		assert(bones and weights, "a vertex with head skin is reweighed")
		T.expect(#bones).toBe(4)
		T.expect(table.find(bones, 10)).toBeNil()
		T.expect(table.find(bones, 11)).toBeNil()
		T.expect(table.find(bones, 4)).toBeNil()
		local sum = 0
		for k, b in bones do
			sum += weights[k]
			if b == 99 then
				T.expect(weights[k]).toBeNear(0.6 / 0.95, 1e-9)
			end
		end
		T.expect(sum).toBeNear(1, 1e-9)
	end)

	T.it("leaves a vertex without head skin as it is", function()
		local bones = JawHinge.reweigh({ 1, 2 }, { 0.5, 0.5 }, HEAD, 1, 99)
		T.expect(bones).toBeNil()
		local none = JawHinge.reweigh({ 10 }, { 1 }, HEAD, 0, 99)
		T.expect(none).toBeNil()
	end)
end)

T.describe("JawHinge timing", function()
	local style = BipedStyles.get("wyvern") :: any

	local function openAt(name: string, hit: number, t: number): number
		return JawHinge.open(O, name, style.actions[name], hit, t)
	end

	local function markTime(name: string, hit: number, text: string): number
		return ActionFx.time(style.actions[name], hit, MotionFx.mark(text))
	end

	T.it(
		"is Vaelgrath's: its model runs the wyvern style, every keyed action is the style's, the marks parse",
		function()
			T.expect(MonsterAssets.vaelgrath.motion).toBe("wyvern")
			for name, keys in O.actions do
				T.expect(style.actions[name] ~= nil).toBe(true)
				local last = -1
				for _, key in keys do
					T.expect(key.open).toBeBetween(0, 60)
					local t = ActionFx.time(style.actions[name], 0.8, MotionFx.mark(key.at))
					T.expect(t >= last).toBe(true)
					last = t
				end
			end
			T.expect(O.head).toBe("Head")
			-- only Vaelgrath has a jaw
			T.expect(BipedRigs.jaw("wyvern")).toBeNil()
		end
	)

	T.it("stays closed without a keyed action, and between its actions", function()
		T.expect(openAt("claw", 0.6, 0.5)).toBe(0)
		T.expect(openAt("stomp", 1.2, 1)).toBe(0)
		T.expect(openAt("roar", 0.45, 0)).toBe(0)
		T.expect(openAt("roar", 0.45, 30)).toBe(0)
		T.expect(openAt("bite", 0.55, 30)).toBe(0)
	end)

	T.it("roars wide on the thrust and holds it", function()
		local hit = 0.45
		T.expect(openAt("roar", hit, hit)).toBeNear(40, 1e-9)
		T.expect(openAt("roar", hit, markTime("roar", hit, "F0.5")) > 30).toBe(true)
		T.expect(openAt("heavy", hit, hit)).toBeNear(40, 1e-9)
	end)

	T.it("opens while the breath streams (Data/MotionFx: W to F0.85) and closes after", function()
		local hit = 1.3
		local from, to = markTime("breath", hit, "W"), markTime("breath", hit, "F0.85")
		for k = 0, 10 do
			local t = from + (to - from) * k / 10
			T.expect(openAt("breath", hit, t) >= 30).toBe(true)
		end
		-- the inhale opens it a little first
		local inhale = openAt("breath", hit, markTime("breath", hit, "A1"))
		T.expect(inhale).toBeBetween(1, 20)
		T.expect(openAt("breath", hit, markTime("breath", hit, "R1"))).toBe(0)
	end)

	T.it("bites: open in the coil, snapped shut on the hit", function()
		local hit = 0.55
		T.expect(openAt("bite", hit, markTime("bite", hit, "A1"))).toBeNear(30, 1e-9)
		T.expect(openAt("bite", hit, hit)).toBe(0)
	end)

	T.it("cries out in the death and hangs slack after", function()
		local action = style.actions.deathDragon
		local hit = action.strike
		T.expect(openAt("deathDragon", hit, hit)).toBeNear(34, 1e-9)
		T.expect(openAt("deathDragon", hit, 60)).toBeNear(14, 1e-9)
	end)

	T.it("moves continuously along every action (no jump between two frames)", function()
		for name in O.actions do
			local hit = if string.sub(name, 1, 5) == "death" then style.actions[name].strike else 0.6
			local last = openAt(name, hit, 0)
			for k = 1, 600 do
				local now = openAt(name, hit, k / 200)
				T.expect(math.abs(now - last) < 12).toBe(true)
				last = now
			end
		end
	end)
end)
