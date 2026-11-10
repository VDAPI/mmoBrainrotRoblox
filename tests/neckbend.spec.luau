--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"): Logic/NeckBend finds the
-- head of a model without bones from its vertices alone (tests/NeckBendMesh: a lynx-like cat, a neckless toad, a bird;
-- the cave spider of tests/LegFoldMesh): the tip at the snout, the cut at the narrow neck, the head whole with its ears
-- and its loose eyes, the body, the legs, the tail and the wings still, no face torn, a texture seam whole, the same
-- without faces; it gives up cleanly. The data: a head only on the models the rig dumps show without bones (all of
-- them, each on the rigid template), its numbers in sane ranges.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local LegFoldMesh = require("./LegFoldMesh")
local Mesh = require("./NeckBendMesh")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local NeckBend = require("../src/shared/Logic/NeckBend")
local RigidRigs = require("../src/shared/Data/RigidRigs")
local RigidStyles = require("../src/shared/Data/RigidStyles")
local T = require("./Test")

-- The model's `gaze` with `over` on it (`seek = false`: none).
local function optionsOf(model: string, over: { [string]: any }?): NeckBend.Options
	local o = table.clone(RigidRigs.gaze(model) :: NeckBend.Options) :: any
	for k, v in over or {} do
		o[k] = v
	end
	if over and over.seek == false then
		o.seek = nil
	end
	return o :: NeckBend.Options
end

local function planOf(m: Mesh.Mesh, o: NeckBend.Options, noFaces: boolean?): (NeckBend.Plan, { number })
	local plan, why = NeckBend.plan(m.pos, if noFaces then nil else m.tris, o, 0)
	if not plan then
		error(`no plan: {why}`)
	end
	return plan, NeckBend.shares(plan, #m.pos // 3)
end

local function at(m: Mesh.Mesh, i: number): (number, number, number)
	return m.pos[i * 3 - 2], m.pos[i * 3 - 1], m.pos[i * 3]
end

-- The largest share and the smallest of the parts named `prefix...` (where `keep(x, y, z)`, if given).
local function range(
	m: Mesh.Mesh,
	share: { number },
	prefix: string,
	keep: ((number, number, number) -> boolean)?
): (number, number, number)
	local lo, hi, count = math.huge, -math.huge, 0
	Mesh.each(m, prefix, function(i: number)
		if not keep or keep(at(m, i)) then
			lo, hi, count = math.min(lo, share[i]), math.max(hi, share[i]), count + 1
		end
	end)
	return lo, hi, count
end

-- The largest difference of share between two corners of a face, and the faces torn (a corner whole, another still).
local function tear(m: Mesh.Mesh, share: { number }): (number, number)
	local most, torn = 0, 0
	for f = 0, #m.tris // 3 - 1 do
		local a, b, c = share[m.tris[f * 3 + 1]], share[m.tris[f * 3 + 2]], share[m.tris[f * 3 + 3]]
		most = math.max(most, math.abs(a - b), math.abs(b - c), math.abs(c - a))
		if math.max(a, b, c) >= 0.95 and math.min(a, b, c) <= 0.05 then
			torn += 1
		end
	end
	return most, torn
end

-- The distance of a point behind the tip along the plan's axis.
local function behind(plan: NeckBend.Plan, p: { number }): number
	local a = plan.axis
	local tip = plan.tip
	return (tip[1] - p[1]) * a[1] + (tip[2] - p[2]) * a[2] + (tip[3] - p[3]) * a[3]
end

local LYNX = optionsOf("lynx")

T.describe("NeckBend: a cat with a neck", function()
	local m = Mesh.cat()
	local plan, share = planOf(m, LYNX)

	T.it("takes the snout's tip and cuts at the narrow neck between the head and the chest", function()
		local tip = plan.tip
		T.expect(tip[3]).toBeBetween(-1.95, -1.8)
		T.expect(tip[2]).toBeBetween(2.5, 2.8)
		T.expect(plan.neck).toBe(true)
		-- the neck runs from the head's back (about 0.7 behind the tip) to the chest (about 1.3)
		T.expect(plan.cut).toBeBetween(0.75, 1.25)
		local joint = plan.joint
		T.expect(math.abs(joint[1]) < 1e-6).toBe(true)
		T.expect(joint[2]).toBeBetween(1.85, 2.5)
		T.expect(joint[3]).toBeBetween(-1.2, -0.6)
	end)

	T.it("puts the joint the data's pivot of the blend behind the cut", function()
		local slice = plan.length / 48
		local want = plan.cut + LYNX.pivot * plan.half
		T.expect(behind(plan, plan.joint)).toBeBetween(want - 3 * slice, want + 3 * slice)
		T.expect(plan.half).toBeNear(LYNX.blend * plan.length / 2, 1e-9)
	end)

	T.it("turns the head whole with its ears and its loose eyes", function()
		T.expect((range(m, share, "ear"))).toBe(1)
		T.expect((range(m, share, "eye"))).toBe(1)
		T.expect(plan.loose).toBe(2)
		local front = range(m, share, "head", function(_x, _y, z)
			return z < -1.45
		end)
		T.expect(front).toBe(1)
		T.expect((range(m, share, "head"))).toBeBetween(0.5, 1)
	end)

	T.it("keeps the body, the legs and the tail still", function()
		local _, body = range(m, share, "body")
		local _, legs = range(m, share, "leg")
		local _, tail = range(m, share, "tail")
		T.expect(body).toBe(0)
		T.expect(legs).toBe(0)
		T.expect(tail).toBe(0)
	end)

	T.it("bends the neck from the head down to the chest, ring by ring", function()
		local first, last = m.parts.neck[1], m.parts.neck[2]
		local rings: { number } = {}
		-- (8 vertices a ring from the head's end; the bridges and caps add none)
		for i = first, last - 7, 8 do
			local sum = 0
			for k = 0, 7 do
				sum += share[i + k]
			end
			table.insert(rings, sum / 8)
		end
		T.expect(rings[1]).toBeBetween(0.6, 1)
		T.expect(rings[#rings]).toBeBetween(0, 0.1)
		for k = 2, #rings do
			T.expect(rings[k] <= rings[k - 1] + 1e-9).toBe(true)
		end
	end)

	T.it("tears no face: the corners of every face stay close", function()
		local most, torn = tear(m, share)
		T.expect(most).toBeBetween(0, 0.5)
		T.expect(torn).toBe(0)
	end)

	T.it("leaves a loose piece beside the head where it is", function()
		local m2 = Mesh.cat({ stray = true })
		local plan2, share2 = planOf(m2, LYNX)
		local _, stray = range(m2, share2, "stray")
		T.expect(stray).toBe(0)
		T.expect((range(m2, share2, "eye"))).toBe(1)
		T.expect(plan2.loose).toBe(2)
	end)

	T.it("finds the same head without faces (by nearness)", function()
		local plan2, share2 = planOf(m, LYNX, true)
		T.expect(plan2.neck).toBe(true)
		local front = range(m, share2, "head", function(_x, _y, z)
			return z < -1.45
		end)
		T.expect(front).toBe(1)
		local _, back = range(m, share2, "body", function(_x, _y, z)
			return z > 0
		end)
		local _, legs = range(m, share2, "leg")
		T.expect(back).toBe(0)
		T.expect(legs).toBe(0)
	end)

	T.it("cuts at the data's share when it is not to look for a neck", function()
		local fixed = planOf(m, optionsOf("lynx", { seek = false }))
		T.expect(fixed.neck).toBe(false)
		T.expect(fixed.cut).toBeNear(LYNX.neck * fixed.length, 1e-9)
	end)

	T.it("plans the same twice", function()
		local _, again = planOf(m, LYNX)
		T.expect(again).toEqual(share)
	end)

	T.it("draws the side and the top views for Studio", function()
		local view: { string } = {}
		NeckBend.plan(m.pos, m.tris, LYNX, 0, nil, view)
		local text = table.concat(view, "\n")
		T.expect(string.find(text, "side", 1, true) ~= nil).toBe(true)
		T.expect(string.find(text, "top", 1, true) ~= nil).toBe(true)
		for _, mark in { "H", "+", "#", "*" } do
			T.expect(string.find(text, mark, 1, true) ~= nil).toBe(true)
		end
	end)
end)

T.describe("NeckBend: a toad, a bird and a spider", function()
	T.it("turns the toad's front softly and leaves its back and its splayed feet", function()
		local m = Mesh.toad()
		local o = optionsOf("swampToad")
		local plan, share = planOf(m, o)
		T.expect(plan.neck).toBe(false)
		local front = range(m, share, "body", function(x, _y, z)
			return z < -1.3 and math.abs(x) < 0.4
		end)
		T.expect(front).toBe(1)
		local _, back = range(m, share, "body", function(_x, _y, z)
			return z > 0.3
		end)
		T.expect(back).toBe(0)
		local _, feet = range(m, share, "leg", function(_x, y, _z)
			return y < 0.2
		end)
		T.expect(feet).toBe(0)
		local most, torn = tear(m, share)
		T.expect(most).toBeBetween(0, 0.75)
		T.expect(torn).toBe(0)
	end)

	T.it("finds no neck in a toad that widens all the way back", function()
		local m = Mesh.toad()
		local plan = planOf(m, optionsOf("swampToad", { seek = { 0.1, 0.5 } }))
		T.expect(plan.neck).toBe(false)
	end)

	T.it("keeps a texture seam whole (the copies of a vertex share alike)", function()
		local m = Mesh.toad()
		local _, share = planOf(m, optionsOf("swampToad"))
		local seen: { [string]: number } = {}
		local twins = 0
		for i = 1, #m.pos // 3 do
			local x, y, z = at(m, i)
			local key = string.format("%.6f,%.6f,%.6f", x, y, z)
			local other = seen[key]
			if other then
				twins += 1
				T.expect(share[i]).toBe(share[other])
			else
				seen[key] = i
			end
		end
		T.expect(twins > 0).toBe(true)
	end)

	T.it("turns the bird's beak and head and leaves its wings and legs", function()
		local m = Mesh.bird()
		local _, share = planOf(m, optionsOf("carrionCrow"))
		T.expect((range(m, share, "beak"))).toBe(1)
		local front = range(m, share, "head", function(_x, y, z)
			return z < -0.45 and y > 1.45
		end)
		T.expect(front).toBe(1)
		T.expect((range(m, share, "head"))).toBeBetween(0, 1)
		local _, wings = range(m, share, "wing")
		local _, legs = range(m, share, "leg")
		T.expect(wings).toBe(0)
		T.expect(legs).toBe(0)
		local _, torn = tear(m, share)
		T.expect(torn).toBe(0)
	end)

	T.it("turns only the spider's face, between its legs, which stay", function()
		local m = LegFoldMesh.spider(true, { palps = true })
		local o = optionsOf("caveSpider")
		local plan, share = planOf(m, o)
		T.expect(plan.whole >= 8).toBe(true)
		-- (the band about the midline: nothing outside its soft edge turns)
		local lx, hx = math.huge, -math.huge
		for i = 1, #m.pos // 3 do
			lx, hx = math.min(lx, m.pos[i * 3 - 2]), math.max(hx, m.pos[i * 3 - 2])
		end
		local band = (o.side :: number) * math.max(hx, -lx)
		local outside = 0
		for i = 1, #m.pos // 3 do
			if math.abs(m.pos[i * 3 - 2]) > 1.25 * band + 1e-9 and share[i] > 0 then
				outside += 1
			end
		end
		T.expect(outside).toBe(0)
		local _, abdomen = range(m, share, "abdomen")
		local _, tips = range(m, share, "leg", function(_x, y, _z)
			return y < 0.4
		end)
		T.expect(abdomen).toBe(0)
		T.expect(tips).toBe(0)
		local _, torn = tear(m, share)
		T.expect(torn).toBe(0)
	end)
end)

T.describe("NeckBend: gives up cleanly", function()
	T.it("on a flat mesh, too few vertices or nothing above the floor", function()
		local flat = {}
		for i = 0, 19 do
			table.insert(flat, i % 5)
			table.insert(flat, 0)
			table.insert(flat, i // 5)
		end
		local plan, why = NeckBend.plan(flat, nil, LYNX)
		T.expect(plan).toBeNil()
		T.expect(why).toBe("a flat mesh")
		local few, whyFew = NeckBend.plan({ 0, 0, 0, 1, 1, 1 }, nil, LYNX)
		T.expect(few).toBeNil()
		T.expect(whyFew).toBe("too few vertices")
		local m = Mesh.cat()
		local high, whyHigh = NeckBend.plan(m.pos, m.tris, optionsOf("lynx", { floor = 0.999 }), 0)
		T.expect(high).toBeNil()
		T.expect(string.find(whyHigh, "no tip", 1, true) ~= nil).toBe(true)
	end)
end)

T.describe("RigidRigs gaze: the data", function()
	-- the models the rig dumps show without bones, one visible mesh (tools/anim/rigs; the new exports *_v2 have bones)
	local boneless: { string } = {}
	for _, file in fs.readDir("tools/anim/rigs") do
		local name = string.match(file, "^(.+)%.json$")
		if name and not string.find(name, "_v2", 1, true) then
			local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{file}`))
			if #dump.bones == 0 and dump.visibleMeshParts == 1 then
				table.insert(boneless, name)
			end
		end
	end
	table.sort(boneless)

	T.it("gives a head to every model without bones and to none with them", function()
		T.expect(#boneless >= 11).toBe(true)
		T.expect(RigidRigs.gazes()).toEqual(boneless)
		for _, model in { "frostWyrm", "vaelgrath", "boar", "brownBear" } do
			T.expect(RigidRigs.gaze(model)).toBeNil()
		end
	end)

	T.it("each on the rigid template (client/Anim/RigidRig turns it)", function()
		for _, model in RigidRigs.gazes() do
			local asset = MonsterAssets[model]
			T.expect(asset ~= nil).toBe(true)
			T.expect(RigidStyles.get(asset.motion :: string) ~= nil).toBe(true)
		end
	end)

	T.it("keeps its numbers in sane ranges", function()
		for _, model in RigidRigs.gazes() do
			local o = RigidRigs.gaze(model) :: RigidRigs.Gaze
			T.expect(o.rise).toBeBetween(0, 90)
			T.expect(o.mid).toBeBetween(0.05, 1)
			T.expect(o.floor).toBeBetween(0, 0.8)
			if o.side then
				T.expect(o.side).toBeBetween(0.05, 1)
			end
			local seek = o.seek
			if seek then
				T.expect(seek[1]).toBeBetween(0, 0.9)
				T.expect(seek[2]).toBeBetween(seek[1] + 0.05, 1)
			end
			T.expect(o.neck).toBeBetween(0.05, 0.8)
			T.expect(o.blend).toBeBetween(0.02, 0.5)
			T.expect(o.pivot).toBeBetween(0, 1)
			T.expect(o.yaw).toBeBetween(0, 60)
			T.expect(o.up).toBeBetween(0, 40)
			T.expect(o.down).toBeBetween(0, 40)
			T.expect(o.glance).toBeBetween(0, o.yaw)
			T.expect(o.tilt).toBeBetween(0, 30)
			T.expect(o.sniff).toBeBetween(0, 6)
			T.expect(o.nod).toBeBetween(0, 6)
			T.expect(o.flinch).toBeBetween(0, 15)
			T.expect(o.steady).toBeBetween(0, 1)
			T.expect(o.rate).toBeBetween(1, 20)
		end
	end)
end)
