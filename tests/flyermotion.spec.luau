--!strict
-- Template animation F3 (docs/ANIM-WZORCE.md §4): the flyer's pose (Logic/FlyerPose) and motion (Logic/FlyerMotion,
-- Data/FlyerStyles) on the rig dumps of the imported models (tools/anim/rigs: ashVulture, peakHarpy): the skeleton
-- turned to face -Z and centred, the Transforms putting every bone where the pose says (forward kinematics of the
-- real hierarchy, the harpy's wings pinned to the chest), the canonical wing spread flat and its controls' signs, the
-- wingbeat's range and rate, glides, the flare, freeze and stun, every blow landing on the server's hit, poses
-- continuous across blends, the death lying on the ground, and the muzzle at the beak / between the wing tips.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local FlyerMotion = require("../src/shared/Logic/FlyerMotion")
local FlyerPose = require("../src/shared/Logic/FlyerPose")
local FlyerRigs = require("../src/shared/Data/FlyerRigs")
local FlyerStyles = require("../src/shared/Data/FlyerStyles")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local SCALE = 1.3 -- the clone's studs per dump unit (any scale works the same)

local function unitV(v: Vec): Vec
	local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The bones of a dump in the look's root space (the root 2.5 below the feet), rest frames from the up / look axes.
local function load(model: string): { [string]: FlyerPose.Bone }
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local out: { [string]: FlyerPose.Bone } = {}
	for _, b in dump.bones do
		local back = unitV({ -b.look[1], -b.look[2], -b.look[3] })
		local up0 = b.up
		local k = up0[1] * back[1] + up0[2] * back[2] + up0[3] * back[3]
		local up = unitV({ up0[1] - back[1] * k, up0[2] - back[2] * k, up0[3] - back[3] * k })
		local right = cross(up, back)
		out[b.name] = {
			rest = { right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3] },
			pos = { b.pos[1] * SCALE, (b.pos[2] + 2.5) * SCALE, b.pos[3] * SCALE },
			parent = if type(b.parent) == "string" then b.parent else nil,
		}
	end
	return out
end

local function mul(a: Mat, b: Mat): Mat
	local o = table.create(9, 0)
	for r = 0, 2 do
		for c = 1, 3 do
			o[r * 3 + c] = a[r * 3 + 1] * b[c] + a[r * 3 + 2] * b[3 + c] + a[r * 3 + 3] * b[6 + c]
		end
	end
	return o
end

local function transpose(a: Mat): Mat
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end

local function apply(m: Mat, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- Where every bone of the real hierarchy ends up with the posed Transforms (Bone: parent * rest-local * Transform).
local function forward(
	bones: { [string]: FlyerPose.Bone },
	posed: FlyerPose.Posed
): { [string]: { rot: Mat, pos: Vec } }
	local out: { [string]: { rot: Mat, pos: Vec } } = {}
	local function visit(name: string): { rot: Mat, pos: Vec }
		local done = out[name]
		if done then
			return done
		end
		local b = bones[name]
		local entry = posed[name]
		local q = if entry then entry.rot else { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		local o = if entry and entry.offset then entry.offset else { 0, 0, 0 }
		local result
		if b.parent and bones[b.parent] then
			local p = bones[b.parent]
			local pw = visit(b.parent)
			local carry = mul(pw.rot, transpose(p.rest)) -- parent's turn since rest
			local unposed = mul(carry, b.rest)
			local rel = apply(carry, { b.pos[1] - p.pos[1], b.pos[2] - p.pos[2], b.pos[3] - p.pos[3] })
			local shift = apply(unposed, o)
			result = {
				rot = mul(unposed, q),
				pos = { pw.pos[1] + rel[1] + shift[1], pw.pos[2] + rel[2] + shift[2], pw.pos[3] + rel[3] + shift[3] },
			}
		else
			local shift = apply(b.rest, o)
			result = { rot = mul(b.rest, q), pos = { b.pos[1] + shift[1], b.pos[2] + shift[2], b.pos[3] + shift[3] } }
		end
		out[name] = result
		return result
	end
	for name in bones do
		visit(name)
	end
	return out
end

local function skeletonOf(model: string): (FlyerPose.Skeleton, { [string]: FlyerPose.Bone })
	local bones = load(model)
	local rig = FlyerRigs.get(model)
	assert(rig, model)
	local skel = FlyerPose.skeleton(bones, rig)
	assert(skel, model)
	return skel, bones
end

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

local function at(skel: FlyerPose.Skeleton, name: string): Vec
	return FlyerPose.at(skel, name) :: Vec
end

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function len(a: Vec): number
	return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

-- A pseudo-random control set touching every control the pose reads.
local KEYS = {
	"bx",
	"by",
	"bz",
	"bpitch",
	"byaw",
	"broll",
	"spitch",
	"syaw",
	"sroll",
	"npitch",
	"nyaw",
	"hpitch",
	"hyaw",
	"hroll",
	"tpitch",
	"tyaw",
	"fan",
}
for _, side in { "L", "R" } do
	for _, letter in { "s", "f", "c", "o" } do
		table.insert(KEYS, "l" .. side .. letter)
	end
	for _, letter in { "e", "s", "t", "f", "h", "b", "w", "p", "q" } do
		table.insert(KEYS, "w" .. side .. letter)
	end
end
local function randomControls(seed: number): FlyerPose.Controls
	local state = seed * 7919 + 17
	local out: FlyerPose.Controls = {}
	for _, key in KEYS do
		state = (state * 1103515245 + 12345) % 2147483648
		out[key] = (state / 2147483648) * 1.6 - 0.8
	end
	return out
end

local function hover(over: { [string]: any }?): FlyerMotion.Input
	local input: any = {
		now = 0,
		dt = 1 / 60,
		speed = 0,
		yawRate = 0,
		combat = false,
		action = nil,
		hitAt = nil,
		hitSide = nil,
		look = nil,
	}
	for k, v in over or {} do
		input[k] = v
	end
	return input
end

-- Steps `inst` from `from` to `to` seconds at 60 fps with `make(t)` as the input; `each(t, posed)` after each frame.
local function run(
	inst: FlyerMotion.Instance,
	from: number,
	to: number,
	make: (t: number) -> FlyerMotion.Input,
	each: ((t: number, posed: FlyerPose.Posed) -> ())?
)
	local t = from
	local first = true
	while t <= to + 1e-9 do
		local input = make(t)
		input.now = t
		input.dt = 1 / 60
		input.snap = first
		first = false
		local posed = FlyerMotion.step(inst, input)
		if each then
			each(t, posed)
		end
		t += 1 / 60
	end
end

T.describe("FlyerPose on the rig dumps", function()
	for _, model in { "ashVulture", "peakHarpy" } do
		T.it(`{model}: the skeleton builds, with wings only where the map lists them`, function()
			local skel = skeletonOf(model)
			T.expect(skel.wings).toBe(model == "peakHarpy")
			T.expect(skel.unit).toBeNear(SCALE, 1e-6)
		end)

		T.it(`{model}: the Transforms put every bone where the pose says (rest and random poses)`, function()
			local skel, bones = skeletonOf(model)
			for seed = 0, 6 do
				local controls = if seed == 0 then {} else randomControls(seed)
				local posed = FlyerPose.solve(skel, controls)
				local world = forward(bones, posed)
				for name, node in skel.byName do
					local want = node.at
					local got = world[name].pos
					T.expect(len(sub(got, want))).toBeBetween(0, 1e-6)
				end
				for _, entry in posed do
					local r = entry.rot
					local det = r[1] * (r[5] * r[9] - r[6] * r[8])
						- r[2] * (r[4] * r[9] - r[6] * r[7])
						+ r[3] * (r[4] * r[8] - r[5] * r[7])
					T.expect(det).toBeNear(1, 1e-6)
					for i = 1, 9 do
						T.expect(finite(r[i])).toBe(true)
					end
				end
			end
		end)

		T.it(`{model}: turned to face -Z and centred over the root`, function()
			local skel = skeletonOf(model)
			FlyerPose.solve(skel, {})
			local rig = skel.rig
			local cx, cz = 0, 0
			for _, name in rig.centre do
				cx += at(skel, name)[1]
				cz += at(skel, name)[3]
			end
			T.expect(cx / #rig.centre).toBeNear(0, 1e-6)
			T.expect(cz / #rig.centre).toBeNear(0, 1e-6)
			-- the hips side by side across -Z: left at -X, right at +X, level in z
			local hipL = at(skel, rig.legs.L[1].bone)
			local hipR = at(skel, rig.legs.R[1].bone)
			T.expect(hipL[1] < 0 and hipR[1] > 0).toBe(true)
			T.expect(math.abs(hipL[3] - hipR[3])).toBeBetween(0, 0.05 * SCALE)
			-- the head in front of the body
			local head = at(skel, rig.head)
			local body = skel.pivot
			T.expect(head[3] < body[3] or model == "peakHarpy").toBe(true)
			local dir = sub(head, { 0, head[2], 0 })
			if model == "ashVulture" then
				T.expect(math.deg(math.atan2(-dir[1], -dir[3]))).toBeBetween(-20, 20)
			end
		end)
	end

	T.it("peakHarpy: the canonical wing lies spread straight out, flat, mirrored", function()
		local skel = skeletonOf("peakHarpy")
		FlyerPose.solve(skel, {})
		local wings = skel.rig.wings :: { [string]: FlyerRigs.Wing }
		local tips: { [string]: Vec } = {}
		for side, wing in wings do
			local shoulder = at(skel, wing.humerus)
			local tip = at(skel, wing.tip :: string)
			local reach = sub(tip, shoulder)
			local span = len(reach)
			T.expect(span).toBeBetween(1.5 * SCALE, 3.5 * SCALE)
			local sx = if side == "R" then 1 else -1
			T.expect(reach[1] * sx / span).toBeBetween(0.97, 1)
			T.expect(math.abs(reach[2]) / span).toBeBetween(0, 0.15)
			T.expect(math.abs(reach[3]) / span).toBeBetween(0, 0.15)
			-- the joints in a line out to the side
			local elbow = at(skel, wing.forearm)
			local wrist = at(skel, wing.hand)
			T.expect((elbow[1] - shoulder[1]) * sx > 0 and (wrist[1] - elbow[1]) * sx > 0).toBe(true)
			tips[side] = tip
		end
		T.expect(tips.L[1] + tips.R[1]).toBeBetween(-0.3 * SCALE, 0.3 * SCALE)
		T.expect(tips.L[2] - tips.R[2]).toBeBetween(-0.2 * SCALE, 0.2 * SCALE)
	end)

	T.it("peakHarpy: the wing controls turn the way their names say, the same on both sides", function()
		local skel = skeletonOf("peakHarpy")
		local wings = skel.rig.wings :: { [string]: FlyerRigs.Wing }
		local function tipOf(side: string, controls: FlyerPose.Controls): Vec
			FlyerPose.solve(skel, controls)
			return table.clone(at(skel, wings[side].tip :: string))
		end
		local function wristOf(side: string, controls: FlyerPose.Controls): Vec
			FlyerPose.solve(skel, controls)
			return table.clone(at(skel, wings[side].hand))
		end
		for _, side in { "L", "R" } do
			local rest = tipOf(side, {})
			local up = tipOf(side, { ["w" .. side .. "e"] = 0.5 })
			T.expect(up[2] - rest[2]).toBeBetween(0.5 * SCALE, 3 * SCALE)
			local fore = tipOf(side, { ["w" .. side .. "s"] = 0.5 })
			T.expect(fore[3] - rest[3]).toBeBetween(-3 * SCALE, -0.5 * SCALE)
			local wrist0 = wristOf(side, {})
			local folded = wristOf(side, { ["w" .. side .. "f"] = 0.8 })
			T.expect(folded[3] - wrist0[3]).toBeBetween(-2 * SCALE, -0.1 * SCALE)
			local handBack = tipOf(side, { ["w" .. side .. "h"] = 0.8 })
			T.expect(handBack[3] - rest[3]).toBeBetween(0.1 * SCALE, 3 * SCALE)
			local whip = tipOf(side, { ["w" .. side .. "w"] = 0.6 })
			T.expect(whip[2] - rest[2]).toBeBetween(0.1 * SCALE, 2 * SCALE)
		end
		-- the wings stay on the chest when the head turns (Tripo hung them from the head)
		local shoulder0 = table.clone(at(skel, wings.R.humerus))
		FlyerPose.solve(skel, { hyaw = 0.8, hpitch = 0.5, npitch = -0.4 })
		T.expect(len(sub(at(skel, wings.R.humerus), shoulder0))).toBeBetween(0, 1e-6)
	end)

	T.it("legs: + swing brings the foot forward, + fold tucks it up, both sides alike", function()
		for _, model in { "ashVulture", "peakHarpy" } do
			local skel = skeletonOf(model)
			for _, side in { "L", "R" } do
				local chain = skel.rig.legs[side]
				local foot = chain[#chain].bone
				FlyerPose.solve(skel, {})
				local rest = table.clone(at(skel, foot))
				FlyerPose.solve(skel, { ["l" .. side .. "s"] = 0.6 })
				T.expect(at(skel, foot)[3] - rest[3]).toBeBetween(-2 * SCALE, -0.05 * SCALE)
				FlyerPose.solve(skel, { ["l" .. side .. "s"] = -0.5, ["l" .. side .. "f"] = 1 })
				T.expect(at(skel, foot)[2] - rest[2]).toBeBetween(0.05 * SCALE, 2 * SCALE)
			end
		end
	end)
end)

T.describe("FlyerMotion", function()
	local function newInst(model: string, style: string, seed: number): FlyerMotion.Instance
		local skel = skeletonOf(model)
		return FlyerMotion.new(skel, style, seed) :: FlyerMotion.Instance
	end

	T.it("the hover's wingbeat swings between the table's top and bottom at its rate", function()
		local inst = newInst("peakHarpy", "harpy", 3)
		local mode = inst.style.modes.hover
		local low, high = math.huge, -math.huge
		local tops = 0
		local last = inst.phase
		run(inst, 0, 10, function()
			return hover()
		end, function()
			local e = inst.controls.wRe
			low, high = math.min(low, e), math.max(high, e)
			if inst.phase < last then
				tops += 1
			end
			last = inst.phase
		end)
		T.expect(high).toBeNear(mode.top, math.rad(4))
		T.expect(low).toBeNear(mode.bottom, math.rad(4))
		local hz = tops / 10
		local expected = mode.hz / math.sqrt(SCALE)
		T.expect(hz).toBeBetween(expected * 0.9, expected * 1.1)
	end)

	T.it("nothing turns NaN through flight, turns, a glide, the flare, blows, a hit, stun and death", function()
		for _, pair in { { "ashVulture", "vulture" }, { "peakHarpy", "harpy" } } do
			local inst = newInst(pair[1], pair[2], 11)
			local style = inst.style
			local plan = {
				{ at = 6, name = style.basic[1], hit = 0.5 },
				{ at = 7.5, name = style.abilities.wail, hit = 1.2 },
				{ at = 10, name = style.abilities.heavyBlow, hit = 1.8 },
				{ at = 13, name = style.abilities.crush, hit = 2.2 },
				{ at = 16.5, name = style.abilities.pounce, hit = 1.4 },
				{ at = 19, name = FlyerMotion.death(inst), hit = 0.5 },
			}
			run(inst, 0, 21, function(t)
				local input = hover({
					speed = if t < 2 then 2 elseif t < 4.5 then 13 elseif t < 4.6 then 3 else 0,
					yawRate = if t > 3 and t < 4 then 1.2 else 0,
					combat = t > 5,
					look = if t > 5 then { 1, -2, -8 } else nil,
					glide = t > 2.5 and t < 3,
					stunned = t > 17.8 and t < 18.6,
					hitAt = if t > 9 then 9 else nil,
					hitSide = "left",
				})
				for _, step in plan do
					if t >= step.at then
						input.action = { name = step.name, start = step.at, hit = step.hit, reach = { 2, 0, -9 } }
					end
				end
				return input
			end, function(_, posed)
				for name, entry in posed do
					for i = 1, 9 do
						assert(finite(entry.rot[i]), `{pair[1]} {name}`)
					end
					if entry.offset then
						for i = 1, 3 do
							assert(finite(entry.offset[i]), `{pair[1]} {name}`)
						end
					end
				end
				for key, v in inst.controls do
					assert(finite(v), `{pair[1]} {key}`)
				end
			end)
		end
	end)

	T.it("every blow's strike ends on the server's hit (W) and lasts at most 0.7 W", function()
		for _, id in { "vulture", "harpy" } do
			local style = FlyerStyles.get(id) :: FlyerStyles.Style
			for name, action in style.actions do
				local strikeEnd = false
				for _, key in action.keys do
					if key.seg == "S" and key.u == 1 then
						strikeEnd = true
					end
				end
				T.expect(strikeEnd).toBe(true)
				for _, w in { 0.5, 0.675, 1.2, 1.8, 2.2 } do
					local wind, hit = FlyerMotion.times(action, w)
					T.expect(hit).toBe(w)
					T.expect(wind).toBeNear(w - math.min(action.strike, 0.7 * w), 1e-9)
				end
				T.expect(name ~= "").toBe(true)
			end
		end
	end)

	T.it(
		"the volley's downstroke and the fling land on W, the shot leaving at the beak / between the wing tips",
		function()
			for _, pair in { { "ashVulture", "vulture" }, { "peakHarpy", "harpy" } } do
				local inst = newInst(pair[1], pair[2], 5)
				local name = inst.style.basic[1]
				local w = 0.5
				local muzzleAtW: Vec? = nil
				local headAtW: Vec? = nil
				local chestAtW: Vec? = nil
				run(inst, 0, 1.2, function()
					return hover({ combat = true, action = { name = name, start = 0.2, hit = w } })
				end, function(t)
					if math.abs(t - (0.2 + w)) < 1 / 120 then
						muzzleAtW = table.clone(FlyerMotion.muzzle(inst) :: Vec)
						headAtW = table.clone(at(inst.skel, inst.skel.rig.head))
						local spine = inst.skel.rig.spine
						chestAtW = table.clone(at(inst.skel, spine[#spine].bone))
						-- the strike's pose itself on the hit (no blend left)
						local keyed = FlyerMotion.controlsAt(inst.style, name, w, w) :: FlyerPose.Controls
						local action = inst.style.actions[name]
						local strike: FlyerPose.Controls? = nil
						for _, key in action.keys do
							if key.seg == "S" and key.u == 1 then
								strike = key.pose
							end
						end
						T.expect(keyed.wRe).toBeNear((strike :: FlyerPose.Controls).wRe, 1e-9)
					end
				end)
				local m = muzzleAtW :: Vec
				-- in front of the chest
				T.expect(m[3] < (chestAtW :: Vec)[3]).toBe(true)
				if pair[1] == "ashVulture" then
					T.expect(len(sub(m, headAtW :: Vec))).toBeBetween(0.2 * SCALE, 0.5 * SCALE)
				end
			end
		end
	)

	T.it("poses stay continuous where a blow blends in and out", function()
		local inst = newInst("peakHarpy", "harpy", 2)
		local prev: { [string]: number } = {}
		local worst = 0
		local worstKey = ""
		local worstT = 0
		run(inst, 0, 3, function()
			return hover({ combat = true, look = { 0, -1, -8 }, action = { name = "fling", start = 0.5, hit = 0.5 } })
		end, function(t)
			if t > 0.05 then
				for key, v in inst.controls do
					-- the wings may move as fast as the free beat does (about 0.13 rad a frame mid-downstroke)
					local d = math.abs(v - (prev[key] or 0)) / (if string.sub(key, 1, 1) == "w" then 1.6 else 1)
					-- the strike itself is fast (a fling of about 60 degrees in 0.16 s): checked outside it
					local inStrike = t > 0.5 + 0.34 - 0.02 and t < 0.5 + 0.5 + 0.02
					if not inStrike and d > worst then
						worst, worstKey, worstT = d, key, t
					end
				end
			end
			table.clear(prev)
			for key, v in inst.controls do
				prev[key] = v
			end
		end)
		if worst > 0.12 then
			print("worst", worstKey, worst, worstT)
		end
		T.expect(worst).toBeBetween(0, 0.1)
	end)

	T.it("the death falls under gravity and lies on the ground, nothing deep under it", function()
		for _, pair in { { "ashVulture", "vulture" }, { "peakHarpy", "harpy" } } do
			for _, seed in { 1, 2, 3, 4 } do
				local inst = newInst(pair[1], pair[2], seed)
				local name = FlyerMotion.death(inst)
				local action = inst.style.actions[name]
				local skel = inst.skel
				local heights: { [number]: number } = {}
				local function centre(): number
					local y = 0
					for _, bone in skel.rig.centre do
						y += at(skel, bone)[2]
					end
					return y / #skel.rig.centre
				end
				run(inst, 0, 2, function()
					return hover({ action = { name = name, start = 0.5, hit = action.strike } })
				end, function(t)
					heights[math.floor(t * 60 + 0.5)] = centre()
				end)
				-- it lies there: the body's centre about half its width over the ground, no bone deep in it
				local body = centre()
				-- (the body bone is Tripo's origin between the feet, off the harpy's body: it carries the turn, not skin)
				local lowest = math.huge
				for _, node in skel.nodes do
					if node.role ~= "body" then
						lowest = math.min(lowest, node.at[2])
					end
				end
				T.expect(lowest).toBeBetween(-0.45 * SCALE, 1.2 * SCALE)
				T.expect(body).toBeBetween(0.1 * SCALE, 1.2 * SCALE)
				-- falling: lower and lower from the jolt to the impact
				local f1 = heights[math.floor((0.5 + 0.25) * 60 + 0.5)]
				local f2 = heights[math.floor((0.5 + 0.4) * 60 + 0.5)]
				local f0 = heights[math.floor((0.5 + 0.1) * 60 + 0.5)]
				T.expect(f0 > f1 and f1 > f2).toBe(true)
			end
		end
	end)

	T.it("glides on a long straight flight, never in a fight", function()
		local glided = 0
		for seed = 1, 6 do
			local inst = newInst("peakHarpy", "harpy", seed)
			local any = false
			run(inst, 0, 20, function()
				return hover({ speed = 9, gait = "walk" })
			end, function()
				if inst.glide > 0.99 then
					any = true
				end
			end)
			if any then
				glided += 1
			end
			local fighting = newInst("peakHarpy", "harpy", seed)
			run(fighting, 0, 12, function()
				return hover({ speed = 13, combat = true, gait = "run" })
			end, function()
				T.expect(fighting.glide).toBe(0)
			end)
		end
		T.expect(glided).toBeBetween(2, 6)
	end)

	T.it("brakes with a flare, banks into turns, holds still when frozen, sinks when stunned", function()
		local inst = newInst("peakHarpy", "harpy", 4)
		local pitchBefore, pitchFlare = 0, -math.huge
		run(inst, 0, 3, function(t)
			return hover({ speed = if t < 2 then 13 else 0 })
		end, function(t)
			if t < 1.99 and t > 1.9 then
				pitchBefore = inst.controls.bpitch
			elseif t > 2 and t < 2.35 then
				pitchFlare = math.max(pitchFlare, inst.controls.bpitch)
			end
		end)
		T.expect(pitchFlare - pitchBefore).toBeBetween(math.rad(8), math.rad(40))
		-- banking left into a left turn (roll + raises the right side)
		local banking = newInst("peakHarpy", "harpy", 4)
		run(banking, 0, 1.5, function()
			return hover({ speed = 13, yawRate = 1 })
		end)
		T.expect(banking.bank).toBeBetween(math.rad(15), math.rad(35))
		-- frozen: the same Transforms frame after frame
		local frozen = newInst("ashVulture", "vulture", 4)
		local first: { number }? = nil
		run(frozen, 0, 1, function(t)
			return hover({ frozen = t > 0.5 })
		end, function(t, posed)
			local rot = posed["tripo::Head_1"].rot
			if t > 0.55 then
				if not first then
					first = table.clone(rot)
				else
					for i = 1, 9 do
						T.expect(rot[i]).toBe((first :: { number })[i])
					end
				end
			end
		end)
		-- stunned: lower than its hover
		local free = newInst("ashVulture", "vulture", 4)
		local stunned = newInst("ashVulture", "vulture", 4)
		local sumFree, sumStun = 0, 0
		run(free, 0, 3, function()
			return hover()
		end, function()
			sumFree += free.controls.by
		end)
		run(stunned, 0, 3, function()
			return hover({ stunned = true })
		end, function()
			sumStun += stunned.controls.by
		end)
		T.expect(sumFree - sumStun).toBeBetween(0.3 * 180, 0.9 * 180)
	end)

	T.it("reads stun and freeze from the Effects attribute (server time)", function()
		local inst = newInst("ashVulture", "vulture", 4)
		run(inst, 0, 0.5, function()
			return hover({ effects = "stun:105.5;slow:120:30", serverNow = 100 })
		end)
		T.expect(inst.stun).toBeBetween(0.9, 1)
		T.expect(inst.stunEnds).toBe(105.5)
		run(inst, 0.6, 1, function()
			return hover({ effects = "stun:105.5", serverNow = 106 })
		end)
		T.expect(inst.stun).toBeBetween(0, 0.2)
	end)

	T.it("the game's choices: its blows, the Elite kit, the throw, the deaths", function()
		local style = FlyerStyles.get("vulture") :: FlyerStyles.Style
		T.expect(FlyerMotion.pick(style, nil, nil, 1)).toBe("volley")
		T.expect(FlyerMotion.pick(style, "wail", nil, 1)).toBe("wail")
		T.expect(FlyerMotion.pick(style, "heavyBlow", nil, 1)).toBe("rake")
		T.expect(FlyerMotion.pick(style, "crush", nil, 1)).toBe("stoop")
		T.expect(FlyerMotion.pick(style, "pounce", nil, 1)).toBe("pounce")
		T.expect(FlyerMotion.pick(style, nil, "throw", 1)).toBe("volley")
		T.expect(FlyerMotion.pick(style, "unknownAbility", nil, 1)).toBe("rake")
		local harpy = FlyerStyles.get("harpy") :: FlyerStyles.Style
		T.expect(FlyerMotion.pick(harpy, nil, nil, 2)).toBe("fling")
		for _, style2 in { style, harpy } do
			for _, name in style2.death do
				T.expect(style2.actions[name] ~= nil).toBe(true)
			end
			for _, name in style2.abilities do
				T.expect(style2.actions[name] ~= nil).toBe(true)
			end
			for _, name in style2.fidgets do
				T.expect(style2.actions[name] ~= nil).toBe(true)
			end
		end
		T.expect(FlyerMotion.side({ 0, 0, 1 })).toBe("front")
		T.expect(FlyerMotion.side({ 1, 0, 0 })).toBe("left")
	end)

	T.it("/animlab mob takes every flyer state", function()
		for _, state in FlyerStyles.LAB_STATES do
			local command = AnimLab.parse({ "mob", "ashVulture", state })
			T.expect(command ~= nil and (command :: any).slot == state).toBe(true)
		end
	end)

	T.it("the timeline's length is the hit plus follow and recover", function()
		local style = FlyerStyles.get("vulture") :: FlyerStyles.Style
		T.expect(FlyerMotion.length(style.actions.volley, 0.5)).toBeNear(0.5 + 0.15 + 0.2, 1e-9)
		T.expect(MotionTimeline.length(style.actions.wail, 1.2)).toBeNear(1.2 + 0.3 + 0.35, 1e-9)
	end)
end)
