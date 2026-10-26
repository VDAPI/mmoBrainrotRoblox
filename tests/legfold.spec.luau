--!strict
-- Template animation (owner 2026-10-26: "nogi się nie składają, jedynie postać przewraca się na bok"): Logic/LegFold
-- finds the legs of a mesh without bones (tests/LegFoldMesh: a Tripo-like cave spider and a scorpion) and curls them
-- in: the body and the scorpion's tail never move, the rest pose is exact, the folded tips come in under the body and
-- off the ground, the fold is finite and continuous, a texture seam does not cut a leg, and the boxes along the fold
-- only ever shrink toward the curled one.
local LegFold = require("../src/shared/Logic/LegFold")
local Mesh = require("./LegFoldMesh")
local RigidRigs = require("../src/shared/Data/RigidRigs")
local T = require("./Test")

local SPIDER = RigidRigs.fold("caveSpider") :: LegFold.Options
local SCORPION = RigidRigs.fold("desertScorpion") :: LegFold.Options
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 }

local function planOf(m: Mesh.Mesh, o: LegFold.Options, faces: boolean?): LegFold.Plan
	local plan, why = LegFold.plan(m.pos, if faces == false then nil else m.tris, o)
	if not plan then
		error(`no plan: {why}`)
	end
	return plan
end

-- How many of a part's vertices are leg vertices, and its size.
local function legShare(m: Mesh.Mesh, plan: LegFold.Plan, name: string): (number, number)
	local isLeg: { [number]: boolean } = {}
	for _, i in plan.idx do
		isLeg[i] = true
	end
	local range = m.parts[name]
	local c = 0
	for i = range[1], range[2] do
		if isLeg[i] then
			c += 1
		end
	end
	return c, range[2] - range[1] + 1
end

local function posed(plan: LegFold.Plan, fold: number, seed: number?): { number }
	local out = table.create(#plan.idx * 3, 0)
	LegFold.pose(plan, fold, seed, IDENTITY, out)
	return out
end

-- Each leg's tip: its vertex farthest (horizontally) from its hip at rest.
local function tips(m: Mesh.Mesh, plan: LegFold.Plan): { number }
	local best: { number }, far: { number } = {}, {}
	for j, i in plan.idx do
		local leg = plan.legs[plan.leg[j]]
		local d = (m.pos[i * 3 - 2] - leg.hx) ^ 2 + (m.pos[i * 3] - leg.hz) ^ 2
		local l = plan.leg[j]
		if not far[l] or d > far[l] then
			best[l], far[l] = j, d
		end
	end
	return best
end

-- The spider with a texture seam across a leg: the faces of the leg's outer half use copies of their vertices.
local function seamed(): (Mesh.Mesh, { [number]: number })
	local m = Mesh.spider(true)
	local range = m.parts["leg11"]
	local mid = (range[1] + range[2]) // 2
	local copyOf: { [number]: number } = {}
	local tris = m.tris
	for t = 1, #tris, 3 do
		local a, b, c = tris[t], tris[t + 1], tris[t + 2]
		if math.min(a, b, c) > mid and math.max(a, b, c) <= range[2] then
			for k = 0, 2 do
				local v = tris[t + k]
				if not copyOf[v] then
					table.insert(m.pos, m.pos[v * 3 - 2])
					table.insert(m.pos, m.pos[v * 3 - 1])
					table.insert(m.pos, m.pos[v * 3])
					copyOf[v] = #m.pos // 3
				end
				tris[t + k] = copyOf[v]
			end
		end
	end
	return m, copyOf
end

T.describe("LegFold legs", function()
	T.it("finds the cave spider's eight legs and never its body (loose or fused, thick, arched, decimated)", function()
		for _, o in { {}, { thick = 0.22 }, { knee = 1.3 }, { knee = 0.1 }, { step = 0.45 } } :: { { [string]: any } } do
			for _, fused in { false, true } do
				local m = Mesh.spider(fused, o)
				local plan = planOf(m, SPIDER)
				T.expect(#plan.legs).toBe(8)
				for name in m.parts do
					local c, size = legShare(m, plan, name)
					if name == "abdomen" or name == "head" then
						T.expect(c).toBe(0)
					elseif c < 0.4 * size then
						error(`{name}: only {c} of {size} vertices fold`)
					end
				end
			end
		end
	end)

	T.it("folds the palps as legs too", function()
		local plan = planOf(Mesh.spider(true, { palps = true }), SPIDER)
		T.expect(#plan.legs).toBe(10)
	end)

	T.it("finds the scorpion's legs and pincers, keeps the pincers still and never moves the tail or body", function()
		local m = Mesh.scorpion()
		local plan = planOf(m, SCORPION)
		T.expect(#plan.legs).toBe(10)
		T.expect((legShare(m, plan, "tail"))).toBe(0)
		T.expect((legShare(m, plan, "body"))).toBe(0)
		local still = 0
		for _, leg in plan.legs do
			if leg.mul == 0 then
				still += 1
				T.expect(leg.dz < -0.8).toBe(true)
			end
		end
		T.expect(still).toBe(2)
		-- the pincers (with their claws) do not move at full fold
		local out = posed(plan, 1, 5)
		for j, i in plan.idx do
			if plan.legs[plan.leg[j]].mul == 0 then
				T.expect(out[j * 3 - 1]).toBeNear(m.pos[i * 3 - 1], 1e-9)
			end
		end
	end)

	T.it("finds the legs without faces too (a radius graph)", function()
		T.expect(#planOf(Mesh.spider(false), SPIDER, false).legs).toBe(8)
		T.expect(#planOf(Mesh.spider(true), SPIDER, false).legs).toBe(8)
	end)

	T.it("gives up on a mesh without legs (the rigid death stays)", function()
		local m: Mesh.Mesh = { pos = {}, tris = {}, parts = {} }
		Mesh.ellipsoid(m, "blob", { 0, 1, 0 }, { 1, 1, 1 })
		local plan, why = LegFold.plan(m.pos, m.tris, SPIDER)
		T.expect(plan).toBeNil()
		T.expect(#why > 0).toBe(true)
		T.expect(LegFold.plan({}, {}, SPIDER)).toBeNil()
	end)

	T.it("keeps a leg whole across a texture seam (the copies move as one)", function()
		local m, copyOf = seamed()
		local plan = planOf(m, SPIDER)
		T.expect(#plan.legs).toBe(8)
		local slot: { [number]: number } = {}
		for j, i in plan.idx do
			slot[i] = j
		end
		local out = posed(plan, 0.7, 3)
		local count = 0
		for v, copy in copyOf do
			local a, b = slot[v], slot[copy]
			T.expect(a ~= nil and b ~= nil).toBe(true)
			for k = 0, 2 do
				T.expect(out[(b :: number) * 3 - k]).toBeNear(out[(a :: number) * 3 - k], 1e-9)
			end
			count += 1
		end
		T.expect(count > 10).toBe(true)
	end)
end)

T.describe("LegFold pose", function()
	T.it("leaves every vertex exactly at rest at fold 0, with or without a seed", function()
		for _, case in { { Mesh.spider(true), SPIDER }, { Mesh.scorpion(), SCORPION } } :: { any } do
			local m: Mesh.Mesh, o: LegFold.Options = case[1], case[2]
			local plan = planOf(m, o)
			for _, seed in { 0, 7 } do
				local out = posed(plan, 0, if seed == 0 then nil else seed)
				for j, i in plan.idx do
					for k = 0, 2 do
						T.expect(out[j * 3 - k]).toBeNear(m.pos[i * 3 - k], 1e-9)
					end
				end
			end
		end
	end)

	T.it("curls the tips in under the body and off the ground at fold 1", function()
		for _, case in
			{
				{ Mesh.spider(true), SPIDER },
				{ Mesh.spider(false, { thick = 0.22 }), SPIDER },
				{ Mesh.scorpion(), SCORPION },
			} :: { any }
		do
			local m: Mesh.Mesh, o: LegFold.Options = case[1], case[2]
			local plan = planOf(m, o)
			local out = posed(plan, 1, 11)
			for l, j in tips(m, plan) do
				local leg = plan.legs[l]
				if leg.mul > 0 then
					local i = plan.idx[j]
					local rest = math.sqrt((m.pos[i * 3 - 2] - leg.hx) ^ 2 + (m.pos[i * 3] - leg.hz) ^ 2)
					local x, y, z = out[j * 3 - 2], out[j * 3 - 1], out[j * 3]
					local now = math.sqrt((x - leg.hx) ^ 2 + (z - leg.hz) ^ 2)
					-- in from the hip by more than half its reach (or past it, under the body)
					if (x - leg.hx) * leg.dx + (z - leg.hz) * leg.dz > 0.5 * rest then
						error(`leg {l}: its tip stays out ({now} of {rest} from the hip)`)
					end
					T.expect(y > m.pos[i * 3 - 1] + 0.05).toBe(true)
				end
			end
		end
	end)

	T.it("never puts a curling leg under the ground and stays finite from the splay to the curl", function()
		for _, case in { { Mesh.spider(true, { palps = true }), SPIDER }, { Mesh.scorpion(), SCORPION } } :: { any } do
			local m: Mesh.Mesh, o: LegFold.Options = case[1], case[2]
			local plan = planOf(m, o)
			local low = math.huge
			for i = 1, #m.pos // 3 do
				low = math.min(low, m.pos[i * 3 - 1])
			end
			local out = table.create(#plan.idx * 3, 0)
			local angles = table.create(#plan.idx, 0)
			for step = -30, 100 do
				local fold = step / 100
				LegFold.pose(plan, fold, 4, IDENTITY, out, angles)
				for k, x in out do
					if x ~= x or math.abs(x) > 1e6 then
						error(`fold {fold}: coordinate {k} is {x}`)
					end
				end
				for _, a in angles do
					T.expect(a == a).toBe(true)
				end
				if fold >= 0 then
					local box = plan.boxes[1]
					-- the box of this fold, between the eighths: the body comes down as the legs fold, so the
					-- lowest leg vertex is measured against the body's lowest point (the drop)
					local at = 1 + fold * (#plan.boxes - 1)
					local a = plan.boxes[math.min(#plan.boxes - 1, math.floor(at))]
					local b = plan.boxes[math.min(#plan.boxes - 1, math.floor(at)) + 1]
					local f = at - math.min(#plan.boxes - 1, math.floor(at))
					local drop = a.y0 + (b.y0 - a.y0) * f - box.y0
					for j = 1, #plan.idx do
						if out[j * 3 - 1] < low + drop - 0.02 then
							error(`fold {fold}: leg vertex {j} at {out[j * 3 - 1]}, under the drop {low + drop}`)
						end
					end
				end
			end
		end
	end)

	T.it("moves continuously along the fold (no vertex jumps)", function()
		local m = Mesh.spider(true, { thick = 0.16 })
		local plan = planOf(m, SPIDER)
		local prev = posed(plan, -0.3, 9)
		local out = table.create(#plan.idx * 3, 0)
		local worst = 0
		for step = -299, 1000 do
			LegFold.pose(plan, step / 1000, 9, IDENTITY, out)
			for k = 1, #out do
				worst = math.max(worst, math.abs(out[k] - prev[k]))
				prev[k] = out[k]
			end
		end
		-- the spider is about 5 across; 1/1000 of the fold moves no vertex more than a few hundredths
		T.expect(worst < 0.05).toBe(true)
	end)

	T.it("gives each leg its own pace with a seed and all the same without", function()
		local plan = planOf(Mesh.spider(true), SPIDER)
		local a, b, c = posed(plan, 0.5, 1), posed(plan, 0.5, 2), posed(plan, 0.5, nil)
		local diff = 0
		for k = 1, #a do
			diff = math.max(diff, math.abs(a[k] - b[k]))
		end
		T.expect(diff > 0.05).toBe(true)
		-- unseeded legs alike: every knee the same share of its whole turn
		local share = plan.legs[1].t2 / plan.legs[1].d2
		for _, leg in plan.legs do
			T.expect(leg.t2).toBeNear(share * leg.d2, 1e-9)
		end
		T.expect(#c).toBe(#a)
	end)

	T.it("maps the folded vertices by the client's affine map", function()
		local plan = planOf(Mesh.scorpion(), SCORPION)
		local plain = posed(plan, 0.8, 2)
		local map = { 0, 0, 2, 0, 2, 0, -2, 0, 0, 1, 2, 3 }
		local out = table.create(#plan.idx * 3, 0)
		LegFold.pose(plan, 0.8, 2, map, out)
		for j = 1, #plan.idx do
			local x, y, z = plain[j * 3 - 2], plain[j * 3 - 1], plain[j * 3]
			T.expect(out[j * 3 - 2]).toBeNear(2 * z + 1, 1e-9)
			T.expect(out[j * 3 - 1]).toBeNear(2 * y + 2, 1e-9)
			T.expect(out[j * 3]).toBeNear(-2 * x + 3, 1e-9)
		end
	end)

	T.it("turns a normal in its leg's plane, keeping its length", function()
		local plan = planOf(Mesh.spider(true), SPIDER)
		for l = 1, #plan.legs do
			local x, y, z = LegFold.turn(plan, l, 0, 0.6, 0, 0.8)
			T.expect(x).toBeNear(0.6, 1e-12)
			T.expect(z).toBeNear(0.8, 1e-12)
			x, y, z = LegFold.turn(plan, l, 1.3, 0.48, 0.6, -0.64)
			T.expect(x * x + y * y + z * z).toBeNear(1, 1e-9)
			-- a quarter turn down takes the leg's up to its outward direction
			local leg = plan.legs[l]
			x, y, z = LegFold.turn(plan, l, math.pi / 2, 0, 1, 0)
			T.expect(x).toBeNear(leg.dx, 1e-9)
			T.expect(y).toBeNear(0, 1e-9)
			T.expect(z).toBeNear(leg.dz, 1e-9)
		end
	end)
end)

T.describe("LegFold boxes", function()
	T.it("keeps the box at rest exactly, then only ever shrinks it to the curled one", function()
		-- `rise`: how far the lowest point comes up curled (share of the height): the spider's body sinks onto its
		-- curled legs, the scorpion's legs tuck in beside its low belly
		for _, case in { { Mesh.spider(true), SPIDER, 0.1 }, { Mesh.scorpion(), SCORPION, 0.01 } } :: { any } do
			local m: Mesh.Mesh, o: LegFold.Options, rise: number = case[1], case[2], case[3]
			local plan = planOf(m, o)
			T.expect(#plan.boxes).toBe(9)
			local rest = plan.boxes[1]
			local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
			for i = 1, #m.pos // 3 do
				local x, y, z = m.pos[i * 3 - 2], m.pos[i * 3 - 1], m.pos[i * 3]
				x0, y0, z0 = math.min(x0, x), math.min(y0, y), math.min(z0, z)
				x1, y1, z1 = math.max(x1, x), math.max(y1, y), math.max(z1, z)
			end
			T.expect(rest.x0).toBeNear(x0, 1e-9)
			T.expect(rest.y0).toBeNear(y0, 1e-9)
			T.expect(rest.z1).toBeNear(z1, 1e-9)
			for k = 2, #plan.boxes - 1 do
				local a, b = plan.boxes[k], plan.boxes[k + 1]
				T.expect(a.x0 <= b.x0 and a.y0 <= b.y0 and a.z0 <= b.z0).toBe(true)
				T.expect(a.x1 >= b.x1 and a.y1 >= b.y1 and a.z1 >= b.z1).toBe(true)
			end
			-- curled: narrower and the lowest point up (the legs no longer hold the body)
			local last = plan.boxes[#plan.boxes]
			T.expect(last.x1 - last.x0 < 0.8 * (x1 - x0)).toBe(true)
			T.expect(last.y0 > y0 + rise * (y1 - y0)).toBe(true)
		end
	end)
end)
