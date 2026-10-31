--!strict
-- Template animation F3 (docs/ANIM-WZORCE.md §4): the flyer's pose (Logic/FlyerPose) and motion (Logic/FlyerMotion,
-- Data/FlyerStyles) on the rig dumps of the imported models (tools/anim/rigs: ashVulture, peakHarpy from Studio; the new
-- exports ashVulture_v2, carrionCrow_v2, bloodBat_v2 from their FBX): the map picked by the bones the model has, the
-- skeleton turned to face -Z, laid level and centred at its hover, the Transforms putting every bone where the pose
-- says (forward kinematics of the real hierarchy, wings pinned to the chest), the canonical wing spread flat and its
-- controls' signs (the fingers, the followers, the jaw), the wingbeat's range and rate, glides, the flare, freeze and
-- stun, every blow landing on the server's hit, poses continuous across blends, the death lying on the ground, the
-- muzzle at the beak / between the wing tips, the crow's perch and hops (its idles on the ground as actions too), the
-- bat's aimed dive down to its target and erratic flutter, no bone under the ground, AnimLab's loop fading out of the
-- pose shown.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local FlyerMotion = require("../src/shared/Logic/FlyerMotion")
local FlyerPose = require("../src/shared/Logic/FlyerPose")
local FlyerRigs = require("../src/shared/Data/FlyerRigs")
local FlyerStyles = require("../src/shared/Data/FlyerStyles")
local MotionFx = require("../src/shared/Data/MotionFx")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local RigidStyles = require("../src/shared/Data/RigidStyles")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local SCALE = 1.3 -- the clone's studs per dump unit (any scale works the same)

-- The dumps: an old Studio dump or a new export's (`k`: old-template studs per FBX unit), the map it must pick.
type Case = { id: string, model: string, v2: boolean, k: number, style: string }
local CASES: { [string]: Case } = {
	ashVulture = { id = "ashVulture", model = "ashVulture", v2 = false, k = 1, style = "vulture" },
	peakHarpy = { id = "peakHarpy", model = "peakHarpy", v2 = false, k = 1, style = "harpy" },
	ashVulture_v2 = { id = "ashVulture_v2", model = "ashVulture", v2 = true, k = 4.2, style = "vulture" },
	carrionCrow_v2 = { id = "carrionCrow_v2", model = "carrionCrow", v2 = true, k = 3.2, style = "crow" },
	bloodBat_v2 = { id = "bloodBat_v2", model = "bloodBat", v2 = true, k = 3.4, style = "bat" },
}
local ALL = { "ashVulture", "peakHarpy", "ashVulture_v2", "carrionCrow_v2", "bloodBat_v2" }
local WINGED = { "peakHarpy", "ashVulture_v2", "carrionCrow_v2", "bloodBat_v2" }
local NEW = { "ashVulture_v2", "carrionCrow_v2", "bloodBat_v2" }

local function unitV(v: Vec): Vec
	local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The bones of a new export's dump (FBX units, bone heads and tails, the mesh's lowest point at y = 0) in the look's
-- root space as the swap builds the asset (times `k`, the root 2.5 under the mesh); rest frames along each bone,
-- rolled a little more each (Studio gives every bone some rest frame: nothing may lean on them being tidy).
local function loadV2(model: string, k: number): { [string]: FlyerPose.Bone }
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}_v2.json`))
	local out: { [string]: FlyerPose.Bone } = {}
	for i, b in dump.bones do
		local d = { b.tail[1] - b.head[1], b.tail[2] - b.head[2], b.tail[3] - b.head[3] }
		if math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3]) < 1e-6 then
			d = { 0, 1, 0 }
		end
		local y = unitV(d)
		local a = i * 0.7
		local ref = if math.abs(y[1]) < 0.9 then { math.cos(a), 0, -math.sin(a) } else { 0, math.cos(a), math.sin(a) }
		local z = unitV(cross(ref, y))
		local x = cross(y, z)
		out[b.name] = {
			rest = { x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3] },
			pos = { b.head[1] * k * SCALE, (b.head[2] * k + 2.5) * SCALE, b.head[3] * k * SCALE },
			parent = if type(b.parent) == "string" then b.parent else nil,
		}
	end
	return out
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

local function bonesOf(id: string): { [string]: FlyerPose.Bone }
	local case = CASES[id]
	return if case.v2 then loadV2(case.model, case.k) else load(case.model)
end

-- The skeleton of a dump on the map its model picks by its bones (it must be the dump's own).
local function skeletonOf(id: string): (FlyerPose.Skeleton, { [string]: FlyerPose.Bone })
	local case = CASES[id]
	local bones = bonesOf(id)
	local rig = FlyerRigs.pick(case.model, bones)
	assert(rig and rig.id == id, id)
	local skel = FlyerPose.skeleton(bones, rig, { scale = SCALE })
	assert(skel, id)
	return skel, bones
end

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

local function at(skel: FlyerPose.Skeleton, name: string): Vec
	return FlyerPose.at(skel, name) :: Vec
end

-- Where any bone is in the last solved pose (a bone the skeleton does not drive rides its parent).
local function pos(skel: FlyerPose.Skeleton, bones: { [string]: FlyerPose.Bone }, name: string): Vec
	return FlyerPose.at(skel, name) or forward(bones, skel.posed)[name].pos
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
	T.it("each model picks the map whose bones it has: the new export's, else the old one's", function()
		T.expect((FlyerRigs.pick("ashVulture", load("ashVulture")) :: FlyerRigs.Rig).id).toBe("ashVulture")
		T.expect((FlyerRigs.pick("ashVulture", loadV2("ashVulture", 1)) :: FlyerRigs.Rig).id).toBe("ashVulture_v2")
		T.expect((FlyerRigs.pick("peakHarpy", load("peakHarpy")) :: FlyerRigs.Rig).id).toBe("peakHarpy")
		T.expect((FlyerRigs.pick("carrionCrow", loadV2("carrionCrow", 1)) :: FlyerRigs.Rig).id).toBe("carrionCrow_v2")
		T.expect((FlyerRigs.pick("bloodBat", loadV2("bloodBat", 1)) :: FlyerRigs.Rig).id).toBe("bloodBat_v2")
		-- the old crow and bat have no bones (their rigid recipe plays), a model missing one bone of the map neither
		T.expect(FlyerRigs.pick("carrionCrow", {})).toBe(nil)
		local partial = loadV2("bloodBat", 1)
		partial.bone_57 = nil
		T.expect(FlyerRigs.pick("bloodBat", partial)).toBe(nil)
		-- the old vulture's 18 bones never pass for the new map, nor the new one's for the old
		local function fits(rig: FlyerRigs.Rig, bones: { [string]: FlyerPose.Bone }): boolean
			for name in FlyerRigs.bones(rig) do
				if not bones[name] then
					return false
				end
			end
			return true
		end
		local old, new = FlyerRigs.byId("ashVulture") :: FlyerRigs.Rig, FlyerRigs.byId("ashVulture_v2") :: FlyerRigs.Rig
		T.expect(fits(new, load("ashVulture"))).toBe(false)
		T.expect(fits(old, loadV2("ashVulture", 1))).toBe(false)
		T.expect(#FlyerRigs.maps("ashVulture")).toBe(2)
		T.expect(FlyerRigs.byId("carrionCrow_v2") ~= nil).toBe(true)
	end)

	for _, model in ALL do
		T.it(`{model}: the skeleton builds, with wings only where the map lists them`, function()
			local skel = skeletonOf(model)
			T.expect(skel.wings).toBe(model ~= "ashVulture")
			T.expect(skel.unit).toBeNear(SCALE, if CASES[model].v2 then 0.002 * SCALE else 1e-6)
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
			local skel, bones = skeletonOf(model)
			FlyerPose.solve(skel, {})
			local rig = skel.rig
			local cx, cy, cz = 0, 0, 0
			for _, name in rig.centre do
				local p = pos(skel, bones, name)
				cx += p[1]
				cy += p[2]
				cz += p[3]
			end
			T.expect(cx / #rig.centre).toBeNear(0, 1e-6)
			T.expect(cz / #rig.centre).toBeNear(0, 1e-6)
			-- a new export's centre at the old one's hover (old-template studs times the clone's scale), its wings level
			if rig.hover then
				T.expect(cy / #rig.centre).toBeNear(rig.hover * SCALE, 0.05 * SCALE)
			end
			-- the hips side by side across -Z: left at -X, right at +X, level in z (the bat's legs ride its body: the
			-- shoulders then)
			local wings = rig.wings
			local hipL = if rig.legs.L then at(skel, rig.legs.L[1].bone) else at(skel, (wings :: any).L.humerus)
			local hipR = if rig.legs.R then at(skel, rig.legs.R[1].bone) else at(skel, (wings :: any).R.humerus)
			T.expect(hipL[1] < 0 and hipR[1] > 0).toBe(true)
			T.expect(math.abs(hipL[3] - hipR[3])).toBeBetween(0, (if CASES[model].v2 then 0.12 else 0.05) * SCALE)
			-- the head in front of the body
			local head = at(skel, rig.head)
			local body = skel.pivot
			T.expect(head[3] < body[3] or model == "peakHarpy").toBe(true)
			local dir = sub(head, { 0, head[2], 0 })
			if model ~= "peakHarpy" then
				T.expect(math.deg(math.atan2(-dir[1], -dir[3]))).toBeBetween(-20, 20)
			end
			-- a new export laid level: its head no higher over its tail's root than a flying body carries it
			if rig.level then
				local tail = pos(skel, bones, rig.tail[1])
				T.expect(math.deg(math.atan2(head[2] - tail[2], tail[3] - head[3]))).toBeBetween(-15, 40)
			end
		end)
	end

	for _, model in WINGED do
		T.it(`{model}: the canonical wing lies spread straight out, flat, mirrored`, function()
			local skel, bones = skeletonOf(model)
			FlyerPose.solve(skel, {})
			local wings = skel.rig.wings :: { [string]: FlyerRigs.Wing }
			local tips: { [string]: Vec } = {}
			for side, wing in wings do
				local shoulder = at(skel, wing.humerus)
				local tip = pos(skel, bones, wing.tip :: string)
				local reach = sub(tip, shoulder)
				local span = len(reach)
				T.expect(span).toBeBetween(1.0 * SCALE, 3.5 * SCALE)
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

		T.it(`{model}: the wing controls turn the way their names say, the same on both sides`, function()
			local skel, bones = skeletonOf(model)
			local wings = skel.rig.wings :: { [string]: FlyerRigs.Wing }
			local function tipOf(side: string, controls: FlyerPose.Controls): Vec
				FlyerPose.solve(skel, controls)
				return table.clone(pos(skel, bones, wings[side].tip :: string))
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
			for _, side in { "L", "R" } do
				local shoulder0 = table.clone(at(skel, wings[side].humerus))
				FlyerPose.solve(skel, { hyaw = 0.8, hpitch = 0.5, npitch = -0.4 })
				T.expect(len(sub(at(skel, wings[side].humerus), shoulder0))).toBeBetween(0, 1e-6)
				FlyerPose.solve(skel, {})
			end
		end)
	end

	T.it(
		"the new exports: the fingers fan back on `n`, the followers turn with their wing bone, the bat's jaw opens",
		function()
			for _, model in NEW do
				local skel = skeletonOf(model)
				local rig = skel.rig
				local wings = rig.wings :: { [string]: FlyerRigs.Wing }
				local function tipOf(name: string, controls: FlyerPose.Controls): Vec
					FlyerPose.solve(skel, controls)
					-- (a finger's own tip: the next bone along it, carried by its turn)
					local node = skel.byName[name]
					local w = node.world
					local d = { 0.3 * SCALE, 0, 0 }
					return { node.at[1] + w[1] * d[1], node.at[2] + w[4] * d[1], node.at[3] + w[7] * d[1] }
				end
				for side, wing in wings do
					for _, finger in wing.fingers or {} do
						local open = tipOf(finger.bone, { ["w" .. side .. "n"] = 0.5 })
						local shut = tipOf(finger.bone, { ["w" .. side .. "n"] = -0.5 })
						local turned = len(sub(open, shut))
						T.expect(turned > 0.02 * SCALE * finger.spread).toBe(true)
					end
				end
				for _, row in rig.follow or {} do
					-- a full follower turns exactly as its wing bone
					local node = skel.byName[row.bone]
					local like = skel.byName[row.like]
					FlyerPose.solve(skel, { wLe = 0.6, wRe = 0.6, wLs = 0.3, wRs = 0.3, wLf = 0.4, wRf = 0.4 })
					local d = 0
					for i = 1, 9 do
						d = math.max(d, math.abs(node.world[i] - like.world[i]))
					end
					if (row.share or 1) >= 1 then
						T.expect(d).toBeBetween(0, 1e-9)
					else
						T.expect(d > 1e-3).toBe(true)
					end
				end
				if rig.jaw then
					-- the jaw turns down about its own pivot (a probe ahead of it drops)
					local jaw = skel.byName[rig.jaw]
					FlyerPose.solve(skel, {})
					local shut = table.clone(jaw.at)
					local ahead0 = -jaw.world[9] * SCALE * 0.3 + jaw.at[3]
					local drop0 = -jaw.world[6] * SCALE * 0.3 + jaw.at[2]
					FlyerPose.solve(skel, { jaw = 0.6 })
					T.expect(len(sub(jaw.at, shut))).toBeBetween(0, 1e-9)
					local drop1 = -jaw.world[6] * SCALE * 0.3 + jaw.at[2]
					T.expect(drop1 < drop0 - 0.05 * SCALE).toBe(true)
					T.expect(ahead0 == ahead0).toBe(true)
				end
			end
		end
	)

	T.it("legs: + swing brings the foot forward, + fold tucks it up, both sides alike", function()
		for _, model in { "ashVulture", "peakHarpy", "ashVulture_v2", "carrionCrow_v2" } do
			local skel = skeletonOf(model)
			for _, side in { "L", "R" } do
				local chain = skel.rig.legs[side]
				local foot = chain[#chain].bone
				-- (a one-bone leg swings its own pivot: the toes' bone under it then)
				if #chain == 1 then
					continue
				end
				FlyerPose.solve(skel, {})
				local rest = table.clone(at(skel, foot))
				FlyerPose.solve(skel, { ["l" .. side .. "s"] = 0.6 })
				T.expect(at(skel, foot)[3] - rest[3]).toBeBetween(-2 * SCALE, -0.02 * SCALE)
				FlyerPose.solve(skel, { ["l" .. side .. "s"] = -0.5, ["l" .. side .. "f"] = 1 })
				T.expect(at(skel, foot)[2] - rest[2]).toBeBetween(0.01 * SCALE, 2 * SCALE)
			end
		end
	end)
end)

T.describe("FlyerMotion", function()
	local function newInst(
		model: string,
		style: string,
		seed: number
	): (FlyerMotion.Instance, { [string]: FlyerPose.Bone })
		local skel, bones = skeletonOf(model)
		return FlyerMotion.new(skel, style, seed) :: FlyerMotion.Instance, bones
	end
	-- every dump on its style (the old vulture and the harpy, the new exports)
	local FLIGHTS: { { string } } = {}
	for _, id in ALL do
		table.insert(FLIGHTS, { id, CASES[id].style })
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
		for _, pair in FLIGHTS do
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
		for _, id in { "vulture", "harpy", "crow", "bat" } do
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
			local shooters = { { "ashVulture", "vulture" }, { "peakHarpy", "harpy" } }
			table.insert(shooters, { "ashVulture_v2", "vulture" })
			table.insert(shooters, { "carrionCrow_v2", "crow" })
			for _, pair in shooters do
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
				if pair[1] ~= "peakHarpy" then
					T.expect(len(sub(m, headAtW :: Vec))).toBeBetween(0.05 * SCALE, 0.5 * SCALE)
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
		for _, pair in FLIGHTS do
			for _, seed in { 1, 2, 3, 4 } do
				local inst, bones = newInst(pair[1], pair[2], seed)
				local name = FlyerMotion.death(inst)
				local action = inst.style.actions[name]
				local skel = inst.skel
				local heights: { [number]: number } = {}
				local function centre(): number
					local y = 0
					for _, bone in skel.rig.centre do
						y += pos(skel, bones, bone)[2]
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

	-- studio review 2026-10-31: the vulture's stoop and deaths, the crow's and the bat's deaths dug bones into the floor
	T.it(
		"no bone goes under the ground: the deaths, the stoop, the dive, the summon (FlyerPose.lowest = the bones)",
		function()
			for _, id in NEW do
				local case = CASES[id]
				local style = FlyerStyles.get(case.style) :: FlyerStyles.Style
				local names: { string } = table.clone(style.death)
				for _, name in { style.abilities.crush, style.summon, style.spawn, style.basic[1] } do
					if name then
						table.insert(names, name)
					end
				end
				for _, name in names do
					local inst, bones = newInst(id, case.style, 3)
					local action = inst.style.actions[name]
					local dying = action.hold == true
					local hit = if dying then action.strike elseif name == style.abilities.crush then 2.2 else 0.55
					local low, lowName = math.huge, ""
					local mismatch = 0
					local n = 0
					run(inst, 0, 2.6 + hit, function()
						return hover({
							combat = not dying,
							look = if dying then nil else { 0, -0.5, -6 },
							action = { name = name, start = 0, hit = hit, reach = { 0, 0, -6 } },
						})
					end, function()
						n += 1
						if n % 4 ~= 0 then
							return
						end
						local world = forward(bones, inst.skel.posed)
						local own = math.huge
						for bone, e in world do
							if bone ~= inst.skel.rig.body then
								own = math.min(own, e.pos[2])
								if e.pos[2] < low then
									low, lowName = e.pos[2], bone
								end
							end
						end
						mismatch = math.max(mismatch, math.abs(own - FlyerPose.lowest(inst.skel)))
					end)
					if low < -1e-3 then
						print(id, name, "under the ground:", lowName, low)
					end
					T.expect(low).toBeBetween(-1e-3, math.huge)
					T.expect(mismatch).toBeBetween(0, 1e-6)
				end
			end
		end
	)

	-- studio review 2026-10-31: AnimLab loops a death back to the hover and starts every state from the rig's first pose
	T.it("a jump back in time fades out of the pose it showed (AnimLab's loop): no pop on the first frame", function()
		for _, id in NEW do
			local case = CASES[id]
			local inst = newInst(id, case.style, 4)
			local name = FlyerMotion.death(inst)
			local strike = inst.style.actions[name].strike
			run(inst, 0, 2, function()
				return hover({ action = { name = name, start = 0, hit = strike } })
			end)
			local before = table.clone(inst.controls)
			local lowBefore = FlyerPose.lowest(inst.skel)
			-- the loop starts again: the same pose on its first frame, the new one after the fade
			FlyerMotion.step(inst, hover({ now = 0, snap = true, action = { name = name, start = 0, hit = strike } }))
			local worst = 0
			for key, v in before do
				worst = math.max(worst, math.abs((inst.controls[key] or 0) - v))
			end
			T.expect(worst).toBeBetween(0, 1e-6)
			T.expect(FlyerPose.lowest(inst.skel)).toBeNear(lowBefore, 1e-3)
			local t = 0
			while t < 0.6 do
				t += 1 / 60
				FlyerMotion.step(inst, hover({ now = t }))
			end
			local fresh = newInst(id, case.style, 4)
			run(fresh, 0, t, function()
				return hover()
			end)
			T.expect(FlyerPose.lowest(inst.skel)).toBeNear(FlyerPose.lowest(fresh.skel), 0.35 * SCALE)
		end
	end)

	T.it("the vulture's death keeps the lower wing level as it rolls (no wing swung down into the ground)", function()
		for _, name in { "deathL", "deathR" } do
			local inst = newInst("ashVulture_v2", "vulture", 1)
			local down = if name == "deathL" then "wLe" else "wRe"
			local worstStep, worstT, prev = 0, 0, nil :: number?
			run(inst, 0, 1, function()
				return hover({ action = { name = name, start = 0, hit = 0.5 } })
			end, function(t)
				local c = inst.controls
				-- the lower wing's elevation against the body's roll: about level from the jolt to the ground
				if t > 0.2 and t < 0.5 then
					local roll = math.abs(c.broll or 0)
					T.expect((c[down] or 0) - roll).toBeBetween(math.rad(-40), math.rad(45))
				end
				-- (its elevation against the ground: the control less the body's roll toward that side)
				local e = (c[down] or 0) - math.abs(c.broll or 0)
				if prev and math.abs(e - prev) > worstStep then
					worstStep, worstT = math.abs(e - prev), t
				end
				prev = e
			end)
			if worstStep > math.rad(9) then
				print(name, "wing step", math.deg(worstStep), "at", worstT)
			end
			-- no snap of the wing on the jolt (the old key swung it 75 degrees down in 0.07 s), none on the ground
			T.expect(worstStep).toBeBetween(0, math.rad(9))
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

	T.it("the crow lands after hovering still, stands on its feet, hops about and flies up into a fight", function()
		for _, seed in { 1, 2, 3 } do
			local inst = newInst("carrionCrow_v2", "crow", seed)
			local skel = inst.skel
			local perch = inst.style.perch :: FlyerStyles.Perch
			T.expect(inst.perchDrop ~= nil and (inst.perchDrop :: number) > 1).toBe(true)
			local landed: number? = nil
			local lowest, standing = math.huge, math.huge
			local hops = 0
			run(inst, 0, 24, function(t)
				return hover({ combat = t > 22, look = if t > 22 then { 0, 0, -8 } else nil })
			end, function(t)
				if inst.perch >= 1 and not landed then
					landed = t
				end
				if inst.perch >= 1 and t < 22 then
					hops = inst.hopCount
					local low = math.huge
					for _, leg in skel.rig.legs do
						for _, joint in leg do
							low = math.min(low, at(skel, joint.bone)[2])
						end
					end
					lowest = math.min(lowest, low)
					-- between hops, the toes on the ground
					if t > inst.hop[7] + perch.hop.length + 0.05 then
						standing = math.min(standing, math.abs(low - perch.toe * skel.unit))
					end
				end
			end)
			-- it lands within its wait and the landing, never before it has hovered still a while
			T.expect(landed ~= nil).toBe(true)
			T.expect(landed :: number)
				.toBeBetween(perch.after[1] + perch.land - 0.05, perch.after[2] + perch.land + 0.1)
			T.expect(standing).toBeBetween(0, 0.05 * SCALE)
			T.expect(lowest).toBeBetween(-0.02 * SCALE, 0.3 * SCALE)
			T.expect(hops).toBeBetween(1, 12)
			-- the fight lifts it off at once
			T.expect(inst.perch).toBe(0)
		end
		-- never down in a fight, nor soon after a hit; the bat (no legs) and the vulture (no perch) never land
		for _, pair in { { "carrionCrow_v2", "crow" }, { "bloodBat_v2", "bat" }, { "ashVulture_v2", "vulture" } } do
			local inst = newInst(pair[1], pair[2], 4)
			run(inst, 0, 14, function(t)
				return hover({
					combat = pair[2] == "crow" and t < 7,
					hitAt = if pair[2] == "crow" and t > 7 then 6.9 else nil,
				})
			end, function()
				T.expect(inst.perch).toBe(0)
			end)
		end
		-- /animlab perch: down at once
		local lab = newInst("carrionCrow_v2", "crow", 5)
		run(lab, 0, 2, function()
			return hover({ perch = true })
		end)
		T.expect(lab.perch).toBe(1)
		-- /animlab perchLook, perchPreen, peck (a perch's idle as an action, with a fight's input): standing on the
		-- ground like the perch, the toes on it all through (studio review 2026-10-31: they hovered)
		local crow = FlyerStyles.get("crow") :: FlyerStyles.Style
		for _, name in (crow.perch :: FlyerStyles.Perch).fidgets do
			local idle = newInst("carrionCrow_v2", "crow", 6)
			local skel = idle.skel
			local length = MotionTimeline.length(crow.actions[name], 0.55)
			local off = 0
			run(idle, 0, length, function()
				return hover({ combat = true, look = { 0, -0.5, -6 }, action = { name = name, start = 0, hit = 0.55 } })
			end, function()
				T.expect(idle.perch).toBe(1)
				local low = math.huge
				for _, leg in skel.rig.legs do
					for _, joint in leg do
						low = math.min(low, at(skel, joint.bone)[2])
					end
				end
				off = math.max(off, math.abs(low - (crow.perch :: FlyerStyles.Perch).toe * skel.unit))
			end)
			T.expect(off).toBeBetween(0, 0.12 * SCALE)
		end
	end)

	T.it("the bat's dive flies at its target until the strike, then holds its line", function()
		local function diveTo(look: Vec, swerve: boolean): (number, number)
			local inst = newInst("bloodBat_v2", "bat", 2)
			local w = 0.6
			local struck: { number }? = nil
			run(inst, 0, 0.5 + w + 0.01, function(t)
				-- the target slips aside once the strike starts
				local aim = if swerve and t > 0.5 + w - 0.15 then { -look[1], look[2], look[3] } else look
				return hover({ combat = true, look = aim, action = { name = "dive", start = 0.5, hit = w } })
			end, function(t)
				if math.abs(t - (0.5 + w)) < 1 / 120 then
					struck = { inst.controls.bx * inst.skel.unit, inst.controls.bz * inst.skel.unit }
				end
			end)
			local s = struck :: { number }
			return s[1], s[2]
		end
		-- down toward the target's chest: the centre most of two studs (at scale 1) under its hover on the hit
		local inst, bones = newInst("bloodBat_v2", "bat", 2)
		local hover0, atHit = 0, 0
		local function centreY(): number
			local y = 0
			for _, bone in inst.skel.rig.centre do
				y += pos(inst.skel, bones, bone)[2]
			end
			return y / #inst.skel.rig.centre
		end
		run(inst, 0, 1.1, function()
			return hover({ combat = true, look = { 0, -0.5, -4 }, action = { name = "dive", start = 0.5, hit = 0.55 } })
		end, function(t)
			if math.abs(t - 0.5) < 1 / 120 then
				hover0 = centreY()
			elseif math.abs(t - 1.05) < 1 / 120 then
				atHit = centreY()
			end
		end)
		T.expect(hover0 - atHit).toBeBetween(1.2 * SCALE, 2.6 * SCALE)
		local x, z = diveTo({ 3, 0, -4 }, false)
		-- toward the target on the hit: as far as it lies less a strike's length, aimed at it
		T.expect(x > 0.5 * SCALE and z < -0.5 * SCALE).toBe(true)
		T.expect(math.atan2(x, -z)).toBeNear(math.atan2(3, 4), 0.25)
		T.expect(math.sqrt(x * x + z * z)).toBeBetween(1 * SCALE, 4.5 * SCALE)
		-- locked when the strike starts: the same line though the target moved
		local x2, z2 = diveTo({ 3, 0, -4 }, true)
		T.expect(x2).toBeNear(x, 0.05 * SCALE)
		T.expect(z2).toBeNear(z, 0.05 * SCALE)
	end)

	T.it(
		"the bat flutters: an uneven drift, wings faster than the vulture's, fingers fanned on the downstroke",
		function()
			local inst = newInst("bloodBat_v2", "bat", 6)
			local lo, hi = math.huge, -math.huge
			local spreadDown, spreadUp = -math.huge, math.huge
			local beats: { number } = {}
			local last = inst.phase
			run(inst, 0, 8, function()
				return hover()
			end, function(t)
				if t > 1 then
					lo, hi = math.min(lo, inst.controls.bx), math.max(hi, inst.controls.bx)
					local n = inst.controls.wLn or 0
					spreadDown, spreadUp = math.max(spreadDown, n), math.min(spreadUp, n)
					if inst.phase < last then
						table.insert(beats, t)
					end
				end
				last = inst.phase
			end)
			T.expect(hi - lo).toBeBetween(0.05, 0.8)
			-- the beat's rate wanders: some beats longer than others
			local short, long = math.huge, 0
			for i = 2, #beats do
				short, long = math.min(short, beats[i] - beats[i - 1]), math.max(long, beats[i] - beats[i - 1])
			end
			T.expect(long / short > 1.15).toBe(true)
			T.expect(spreadDown > math.rad(5) and spreadUp < 0).toBe(true)
			local bat = (FlyerStyles.get("bat") :: FlyerStyles.Style).modes.hover.hz
			local vulture = (FlyerStyles.get("vulture") :: FlyerStyles.Style).modes.hover.hz
			T.expect(bat > 2 * vulture).toBe(true)
		end
	)

	T.it("the crow and the bat keep their rigid kit: blows, slots, the effects' action names", function()
		for _, id in { "crow", "bat" } do
			local flyer = FlyerStyles.get(id) :: FlyerStyles.Style
			local rigid = RigidStyles.get(id) :: any
			for slot, name in rigid.abilities do
				T.expect(flyer.abilities[slot]).toBe(name)
				T.expect(flyer.actions[name] ~= nil).toBe(true)
			end
			T.expect(flyer.basic[1]).toBe(rigid.basic[1])
			T.expect(flyer.throw).toBe(rigid.throw)
			for _, entry in rigid.death do
				local name = if type(entry) == "table" then entry.name else entry
				T.expect(flyer.actions[name] ~= nil).toBe(true)
			end
			for name in MotionFx.STYLES[id] do
				T.expect(flyer.actions[name] ~= nil).toBe(true)
			end
			for _, list in { flyer.death, flyer.fidgets, (flyer.perch and flyer.perch.fidgets) or {} } do
				for _, name in list do
					T.expect(flyer.actions[name] ~= nil).toBe(true)
				end
			end
			for _, name in { flyer.aggro, flyer.spawn, flyer.summon } do
				T.expect(flyer.actions[name :: string] ~= nil).toBe(true)
			end
		end
	end)

	T.it("/animlab mob takes every flyer state, the crow's and the bat's rigid ones too", function()
		for _, state in FlyerStyles.LAB_STATES do
			local command = AnimLab.parse({ "mob", "ashVulture", state })
			T.expect(command ~= nil and (command :: any).slot == state).toBe(true)
		end
		for _, pair in { { "ashVulture", "vulture" }, { "carrionCrow", "crow" }, { "bloodBat", "bat" } } do
			for _, state in FlyerStyles.labStates(pair[2]) do
				local command = AnimLab.parse({ "mob", pair[1], state })
				T.expect(command ~= nil and (command :: any).slot == state).toBe(true)
			end
		end
		for _, state in RigidStyles.labStates("crow") do
			T.expect(AnimLab.parse({ "mob", "carrionCrow", state }) ~= nil).toBe(true)
		end
		T.expect(AnimLab.parse({ "mob", "carrionCrow", "perch" }) ~= nil).toBe(true)
		T.expect(AnimLab.parse({ "mob", "bloodBat", "perch" })).toBe(nil)
	end)

	T.it("the timeline's length is the hit plus follow and recover", function()
		local style = FlyerStyles.get("vulture") :: FlyerStyles.Style
		T.expect(FlyerMotion.length(style.actions.volley, 0.5)).toBeNear(0.5 + 0.15 + 0.2, 1e-9)
		T.expect(MotionTimeline.length(style.actions.wail, 1.2)).toBeNear(1.2 + 0.3 + 0.35, 1e-9)
	end)
end)
