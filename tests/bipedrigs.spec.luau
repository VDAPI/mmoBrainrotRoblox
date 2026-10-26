--!strict
-- Template animation (2026-10-26): the bipeds with a Data/BipedRigs map on their rig dumps (tools/anim/rigs: the
-- regular wyvern on Vaelgrath's wyvern style, the specter and the ice elemental on Logic/SpiritMotion): the map's bones,
-- virtual points and pivot; the Transforms putting the real hierarchy where the pose says (forward kinematics, the body
-- turned about the pivot); a skeleton without options unchanged; the rest reproduced; the wings folded at rest and
-- spread in the roar; the feet planted in the bounds; every blow's strike ending on the server's hit and the spit
-- thrusting the jaw forward at W; no NaN and no jumps through a long scripted fight; nothing under the ground; the
-- death lying on its side; the specter's robe trailing with lag, its flicker and its death rising and fading; the
-- elemental shattering by 0.4 s; the AnimLab states.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local BipedMotion = require("../src/shared/Logic/BipedMotion")
local BipedPose = require("../src/shared/Logic/BipedPose")
local BipedRigs = require("../src/shared/Data/BipedRigs")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local SpiritMotion = require("../src/shared/Logic/SpiritMotion")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local SCALE = 1.3 -- the clone's studs per dump unit
-- the look's root under the dump's lowest point: a floating look's hangs 2.5 below
local LIFT: { [string]: number } = { wyvern = 0, specter = 2.5, iceElemental = 2.5 }

local function unitV(v: Vec): Vec
	local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
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

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function len(a: Vec): number
	return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

type Dump = {
	rest: { [string]: BipedPose.Bone },
	parent: { [string]: string? },
	names: { [string]: string },
}

-- A dump's bones in the look's root space, as client/Anim/BipedRig reads them (the first bone of each key).
local function load(model: string): Dump
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local rest: { [string]: BipedPose.Bone } = {}
	local parent: { [string]: string? } = {}
	local names: { [string]: string } = {}
	local lift = LIFT[model]
	for _, b in dump.bones do
		local back = unitV({ -b.look[1], -b.look[2], -b.look[3] })
		local up0 = b.up
		local k = up0[1] * back[1] + up0[2] * back[2] + up0[3] * back[3]
		local up = unitV({ up0[1] - back[1] * k, up0[2] - back[2] * k, up0[3] - back[3] * k })
		local right = cross(up, back)
		rest[b.name] = {
			rest = { right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3] },
			pos = { b.pos[1] * SCALE, (b.pos[2] + lift) * SCALE, b.pos[3] * SCALE },
		}
		parent[b.name] = if type(b.parent) == "string" then b.parent else nil
		local key = BipedRigs.keyOf(b.name)
		if not names[key] then
			names[key] = b.name
		end
	end
	return { rest = rest, parent = parent, names = names }
end

type Rig = { dump: Dump, skel: BipedPose.Skeleton, keyed: { [string]: string }, options: BipedPose.Options }

local function rigOf(model: string): Rig
	local dump = load(model)
	local bones, keyed, options = BipedPose.collect(dump.names, dump.rest, BipedRigs.get(model))
	local skel = BipedPose.skeleton(bones, options)
	assert(skel, model)
	return { dump = dump, skel = skel, keyed = keyed, options = options }
end

-- Where every bone of the real hierarchy ends up with the posed Transforms (Bone: parent * rest-local * Transform).
local function forward(rig: Rig, posed: BipedPose.Posed): { [string]: { rot: Mat, pos: Vec } }
	local byName: { [string]: { rot: Mat, offset: Vec? } } = {}
	for key, name in rig.keyed do
		local entry = posed[key]
		if entry then
			byName[name] = entry
		end
	end
	local bones = rig.dump.rest
	local out: { [string]: { rot: Mat, pos: Vec } } = {}
	local function visit(name: string): { rot: Mat, pos: Vec }
		local done = out[name]
		if done then
			return done
		end
		local b = bones[name]
		local entry = byName[name]
		local q = if entry then entry.rot else { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		local o = if entry and entry.offset then entry.offset else { 0, 0, 0 }
		local result
		local parentName = rig.dump.parent[name]
		if parentName and bones[parentName] then
			local p = bones[parentName]
			local pw = visit(parentName)
			local carry = mul(pw.rot, transpose(p.rest))
			local unposed = mul(carry, b.rest)
			local rel = apply(carry, sub(b.pos, p.pos))
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

-- A pseudo-random control set over every control the pose reads.
local function randomControls(seed: number, size: number): BipedPose.Controls
	local state = seed * 7919 + 17
	local out: BipedPose.Controls = {}
	for _, key in BipedPose.CONTROLS do
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648 * 2 - 1
		local first = string.sub(key, 1, 1)
		-- distances (leg lengths) small, turns up to `size` rad
		out[key] = if first == "f" and #key == 3
			then u * 0.2
			elseif key == "px" or key == "pz" then u * 0.1
			else u * size
	end
	out.py = (out.py or 0) * 0.3
	return out
end

-- The step of the long runs: fine enough that a fast strike moves little per frame while a pop would not shrink.
local FINE = 1 / 180

-- The continuity of a long run: `run(dt, sink)` plays a scenario at the step `dt`, handing each frame's pose to `sink`.
-- The largest change of a rotation entry per frame (in windows of 0.1 s) is compared between FINE and FINE / 2: a
-- continuous motion halves with the step, a pop keeps its size. Only the keys the rig writes count (`written`: a
-- virtual point has no bone). Returns the largest change at FINE, the worst excess of a window over a continuous
-- motion (0 when none) and that window's time.
local function continuity(
	written: { [string]: string },
	run: (dt: number, sink: (t: number, posed: BipedPose.Posed) -> ()) -> ()
): (number, number, number)
	local function windows(dt: number): { [number]: number }
		local out: { [number]: number } = {}
		local last: BipedPose.Posed? = nil
		run(dt, function(t: number, posed: BipedPose.Posed)
			local prev = last
			if prev then
				local w = math.floor(t * 10)
				for key, entry in posed do
					local p = prev[key]
					if p and written[key] then
						for i = 1, 9 do
							out[w] = math.max(out[w] or 0, math.abs(entry.rot[i] - p.rot[i]))
						end
					end
				end
			end
			last = posed
		end)
		return out
	end
	local fine, half = windows(FINE), windows(FINE / 2)
	local largest = 0
	for _, d in fine do
		largest = math.max(largest, d)
	end
	local excess, at = 0, 0
	for w, d in half do
		-- (the neighbours too: a frame on a window's edge falls on either side at the two steps)
		local ref = math.max(fine[w - 1] or 0, fine[w] or 0, fine[w + 1] or 0)
		local over = d - (0.65 * ref + 0.004)
		if over > excess then
			excess, at = over, w / 10
		end
	end
	return largest, excess, at
end

-- No NaN in a pose.
local function checkFinite(posed: BipedPose.Posed, label: string)
	for key, entry in posed do
		for _, x in entry.rot do
			if not finite(x) then
				error(`{label}: NaN in {key}`)
			end
		end
		if entry.offset then
			for _, x in entry.offset do
				if not finite(x) then
					error(`{label}: NaN offset in {key}`)
				end
			end
		end
	end
end

local function input(over: { [string]: any }?): BipedMotion.Input
	local i: any = { now = 0, dt = 1 / 60, speed = 0, yawRate = 0, combat = false }
	for k, v in over or {} do
		i[k] = v
	end
	return i
end

-- A bone's name of a key.
local function nameOf(rig: Rig, key: string): string
	return rig.keyed[key] :: string
end

-- The small forearms under the wyvern's chest (not driven: they follow the chest and may press into the ground lying)
local function smallArm(name: string): boolean
	local n = tonumber(string.match(name, "^bone_(%d+)$") or "")
	return n ~= nil and ((n >= 32 and n <= 37) or (n >= 39 and n <= 44))
end

T.describe("BipedRigs: the maps on the rig dumps", function()
	T.it("the name rules: a Mixamo prefix dropped, the Tripo biped aliases", function()
		T.expect(BipedRigs.keyOf("mixamorig:LeftForeArm")).toBe("LeftForeArm")
		T.expect(BipedRigs.keyOf("L_Calf")).toBe("LeftLeg")
		T.expect(BipedRigs.keyOf("Hip")).toBe("Hips")
		T.expect(BipedRigs.keyOf("tripo::Spine_0")).toBe("Spine_0")
	end)

	T.it("every mapped model builds a skeleton, its map's bones exist and its muzzle is a key", function()
		for _, model in { "wyvern", "specter", "iceElemental" } do
			local map = BipedRigs.get(model)
			assert(map, model)
			local dump = load(model)
			for _, name in map.bones or {} :: { [string]: string } do
				T.expect(dump.rest[name] ~= nil).toBe(true)
			end
			T.expect(dump.rest[map.unit.bone] ~= nil).toBe(true)
			local rig = rigOf(model)
			if map.muzzle then
				T.expect(rig.keyed[map.muzzle.key] ~= nil).toBe(true)
			end
		end
	end)

	T.it("the unit is the clone's scale; the pivots: the wyvern's pelvis, the elemental's middle", function()
		local dump = load("wyvern")
		local _, _, options, unit = BipedPose.collect(dump.names, dump.rest, BipedRigs.get("wyvern"))
		T.expect(unit).toBeNear(SCALE, 1e-6)
		local pivot = options.pivot :: Vec
		T.expect(len(sub(pivot, dump.rest.bone_1.pos))).toBeNear(0, 1e-9)
		local ice = load("iceElemental")
		local _, _, iceOptions, iceUnit = BipedPose.collect(ice.names, ice.rest, BipedRigs.get("iceElemental"))
		T.expect(iceUnit).toBeNear(SCALE, 1e-6)
		local middle = iceOptions.pivot :: Vec
		-- the mesh's middle: x 0, 1.25 over its lowest point (+ the hang), z 0
		T.expect(middle[1]).toBeNear(0, 0.02)
		T.expect(middle[2]).toBeNear((1.25 + 2.5) * SCALE, 0.03)
		T.expect(middle[3]).toBeNear(0, 0.02)
	end)

	T.it("virtual and dropped keys are posed but never written (the elemental's misplaced legs and head)", function()
		local rig = rigOf("iceElemental")
		for _, key in { "LeftUpLeg", "LeftLeg", "LeftFoot", "Neck", "Head", "LeftToeBase" } do
			T.expect(rig.keyed[key]).toBeNil()
		end
		T.expect(rig.skel.bones.LeftFoot ~= nil).toBe(true)
		T.expect(rig.keyed.Hips).toBe("Hip")
		T.expect(rig.keyed.RightHand).toBe("R_Hand")
		local specter = rigOf("specter")
		T.expect(specter.keyed.LeftFoot).toBeNil()
		T.expect(specter.keyed.LeftLeg).toBe("mixamorig:LeftLeg")
	end)
end)

T.describe("BipedPose: pivot and leg plane", function()
	T.it(
		"zero controls reproduce the wyvern's rest exactly but the wings (its splayed legs keep their plane)",
		function()
			local rig = rigOf("wyvern")
			local fk = forward(rig, BipedPose.solve(rig.skel, {}))
			-- (zero controls hang the arms, its wings, straight down)
			local function inWing(name: string): boolean
				local at: string? = name
				while at do
					if at == "bone_60" or at == "bone_50" then
						return true
					end
					at = rig.dump.parent[at]
				end
				return false
			end
			local worst = 0
			for name, b in rig.dump.rest do
				if not inWing(name) then
					worst = math.max(worst, len(sub(fk[name].pos, b.pos)))
				end
			end
			T.expect(worst).toBeBetween(0, 1e-6)
		end
	)

	T.it("the Transforms put every driven joint where BipedPose.positions says (the body about the pivot)", function()
		for _, model in { "wyvern", "iceElemental", "specter" } do
			local rig = rigOf(model)
			for seed = 1, 12 do
				local world, shift = BipedPose.world(rig.skel, randomControls(seed, 0.6))
				local at = BipedPose.positions(rig.skel, world, shift)
				local fk = forward(rig, BipedPose.transforms(rig.skel, world, shift))
				for key, name in rig.keyed do
					if at[key] and rig.skel.bones[key] then
						T.expect(len(sub(fk[name].pos, at[key]))).toBeBetween(0, 1e-6)
					end
				end
			end
		end
	end)

	T.it("the pivot stays put when only the body turns", function()
		local rig = rigOf("wyvern")
		local pivot = rig.options.pivot :: Vec
		local world, shift = BipedPose.world(rig.skel, { ppitch = 0.4, proll = -0.2, pyaw = 0.3 })
		local hips = BipedPose.positions(rig.skel, world, shift).Hips
		local w = world.Hips
		-- the Hips joint swung about the pivot: hips - pivot == W (rest hips - pivot)
		local expect = apply(w, sub(rig.skel.bones.Hips.pos, pivot))
		T.expect(len(sub(sub(hips, pivot), expect))).toBeBetween(0, 1e-9)
	end)

	T.it(
		"a skeleton without options is the old one: the Hips offset is the shift, the knees bend toward the front",
		function()
			local dump = load("specter")
			local bones = BipedPose.collect(dump.names, dump.rest, nil)
			-- the specter has no feet of its own: give it the virtual ones to make a plain skeleton
			local data = BipedPose.collect(dump.names, dump.rest, BipedRigs.get("specter"))
			bones.LeftFoot, bones.RightFoot = data.LeftFoot, data.RightFoot
			local skel = BipedPose.skeleton(bones) :: BipedPose.Skeleton
			T.expect(skel.pivot).toBeNil()
			T.expect(skel.leg.L.front).toBeNil()
			for seed = 1, 6 do
				local world, shift = BipedPose.world(skel, randomControls(seed, 0.5))
				local posed = BipedPose.transforms(skel, world, shift)
				local expected = apply(transpose(skel.bones.Hips.rest), shift)
				local o = posed.Hips.offset :: Vec
				T.expect(len(sub(o, expected))).toBeBetween(0, 1e-12)
			end
		end
	)
end)

local WYVERN = BipedStyles.get("wyvernRegular") :: BipedStyles.Style

T.describe("The regular wyvern (Vaelgrath's style on its own rig)", function()
	T.it("MonsterAssets: the wyvern on wyvernRegular, Vaelgrath keeps wyvern, the spirits on theirs", function()
		T.expect(MonsterAssets.wyvern.motion).toBe("wyvernRegular")
		T.expect(MonsterAssets.vaelgrath.motion).toBe("wyvern")
		T.expect(MonsterAssets.specter.motion).toBe("specter")
		T.expect(MonsterAssets.iceElemental.motion).toBe("iceElemental")
		T.expect(SpiritMotion.handles("specter")).toBe(true)
		T.expect(SpiritMotion.handles("wyvernRegular")).toBe(false)
		T.expect(SpiritMotion.handles("wyvern")).toBe(false)
	end)

	T.it("its kit: the spit (shot and throw), breath, claw, stomp, pounce; Vaelgrath's actions all there", function()
		T.expect(WYVERN.basic[1]).toBe("spit")
		T.expect(WYVERN.throw).toBe("spit")
		T.expect(BipedMotion.pick(WYVERN, "fireBreath", nil, 1)).toBe("breath")
		T.expect(BipedMotion.pick(WYVERN, "heavyBlow", nil, 1)).toBe("claw")
		T.expect(BipedMotion.pick(WYVERN, "crush", nil, 1)).toBe("stomp")
		T.expect(BipedMotion.pick(WYVERN, "pounce", nil, 1)).toBe("pounce")
		T.expect(BipedMotion.pick(WYVERN, nil, "throw", 1)).toBe("spit")
		local vaelgrath = BipedStyles.get("wyvern") :: BipedStyles.Style
		for name in vaelgrath.actions do
			T.expect(WYVERN.actions[name] ~= nil).toBe(true)
		end
		-- Vaelgrath's own style is untouched (its rest keeps its pitches)
		T.expect(vaelgrath.procedural and vaelgrath.procedural.rest.ppitch).toBe(0.5)
		T.expect(vaelgrath.procedural and vaelgrath.procedural.hop).toBeNil()
	end)

	T.it("the wings rest folded along the back and spread wide in the roar's scream", function()
		local rig = rigOf("wyvern")
		local spine = rig.dump.rest["tripo::Spine_0"].pos
		local rest = forward(rig, BipedPose.solve(rig.skel, (WYVERN.procedural :: any).rest))
		local roarKeys = WYVERN.actions.roar.keys
		local roar = forward(rig, BipedPose.solve(rig.skel, roarKeys[2].pose))
		for _, tip in { "bone_66", "bone_56" } do
			T.expect(math.abs(rest[tip].pos[1] - spine[1])).toBeBetween(0, 1.0 * SCALE)
			T.expect(math.abs(roar[tip].pos[1] - spine[1])).toBeBetween(2.0 * SCALE, 4 * SCALE)
		end
		-- the export rests half spread
		T.expect(math.abs(rig.dump.rest.bone_66.pos[1])).toBeBetween(2.0 * SCALE, 3 * SCALE)
	end)

	T.it("every key pose stands above the ground; the death lies low on its side", function()
		local rig = rigOf("wyvern")
		local L = rig.skel.legLength
		for name, action in WYVERN.actions do
			for i, key in action.keys do
				local fk = forward(rig, BipedPose.solve(rig.skel, key.pose))
				local low = math.huge
				for bone, f in fk do
					if bone ~= "tripo::Root" and not smallArm(bone) then
						low = math.min(low, f.pos[2])
					end
				end
				if low < -0.05 * L then
					error(`{name} key {i}: a bone {low} under the ground`)
				end
			end
		end
		local keys = WYVERN.actions.deathDragon.keys
		local fk = forward(rig, BipedPose.solve(rig.skel, keys[#keys].pose))
		T.expect(fk["tripo::Spine_1"].pos[2]).toBeBetween(0, 0.6 * SCALE)
		T.expect(fk["tripo::Head_2"].pos[2]).toBeBetween(0, 0.4 * SCALE)
		-- lying on its side: the line across its hips (level at rest) stands steep
		local across = sub(fk.bone_12.pos, fk.bone_2.pos)
		T.expect(math.abs(across[2]) / len(across)).toBeBetween(0.7, 1)
	end)

	T.it("every blow's strike ends exactly on the server's hit", function()
		for name, action in WYVERN.actions do
			for _, hit in { 0.5, 0.81, 1.3, 1.8, 2.2 } do
				local peak, at, finish = BipedMotion.times(action, hit)
				T.expect(at).toBe(hit)
				T.expect(peak <= hit).toBe(true)
				T.expect(finish).toBeNear(hit + action.follow + action.recover, 1e-9)
				-- at the hit the controls are the strike's last key
				local last
				for _, key in action.keys do
					if key.seg == "S" then
						last = key
					end
				end
				if last and last.u == 1 then
					local c = BipedMotion.controlsAt(WYVERN, name, hit, hit) :: BipedPose.Controls
					local lag = action.lag or {}
					for k, v in last.pose do
						-- (the head and the free arm trail the body by the action's lag)
						local head = string.sub(k, 1, 1) == "h"
						local free = string.find(k, "^[acew]L") ~= nil
						if not (head and (lag.head or 0) > 0) and not (free and (lag.free or 0) > 0) then
							T.expect(c[k]).toBeNear(v, 1e-9)
						end
					end
				end
			end
		end
	end)

	T.it("the spit thrusts the jaw forward to its farthest at W (the shot leaves there)", function()
		local rig = rigOf("wyvern")
		local hit = 0.5
		local inst = BipedMotion.new(rig.skel, "wyvernRegular", 3) :: BipedMotion.Instance
		local run = { name = "spit", start = 0, hit = hit }
		local frontmost, frontT = math.huge, -1
		local atPeak = 0
		local peak = BipedMotion.times(WYVERN.actions.spit, hit)
		local t = 0
		while t <= hit + 0.3 do
			local posed = BipedMotion.step(inst, input({ now = t, combat = true, action = run, snap = t == 0 }))
			local head = forward(rig, posed)["tripo::Head_2"].pos
			if head[3] < frontmost then
				frontmost, frontT = head[3], t
			end
			if math.abs(t - peak) < 1 / 120 then
				atPeak = head[3]
			end
			t += 1 / 60
		end
		T.expect(frontT).toBeBetween(hit - 0.06, hit + 0.06)
		T.expect(atPeak - frontmost).toBeBetween(0.4 * SCALE, 3 * SCALE)
	end)

	T.it("the chase bounds on both feet, planted through each stance; the walk alternates", function()
		local rig = rigOf("wyvern")
		local inst = BipedMotion.new(rig.skel, "wyvernRegular", 5) :: BipedMotion.Instance
		local L = rig.skel.legLength
		local speed = 13
		local restAnkle = rig.skel.bones.LeftFoot.pos[2]
		local lastL: Vec?, lastR: Vec? = nil, nil
		local planted, slides = 0, 0
		local airborne = 0
		local t = 0
		while t < 3 do
			local posed =
				BipedMotion.step(inst, input({ now = t, speed = speed, combat = true, gait = "run", snap = t == 0 }))
			local fk = forward(rig, posed)
			local l, r = fk[nameOf(rig, "LeftFoot")].pos, fk[nameOf(rig, "RightFoot")].pos
			if t > 1 then
				if l[2] < restAnkle + 0.02 * L and lastL then
					-- on the ground: it slides back under the body at the ground speed (root space); the frame it lands in
					-- is part swing
					planted += 1
					local v = (l[3] - lastL[3]) * 60
					if lastL[2] < restAnkle + 0.02 * L and math.abs(v - speed) > 0.2 * speed then
						slides += 1
					end
				elseif l[2] > restAnkle + 0.15 * L then
					airborne += 1
				end
			end
			lastL, lastR = l, r
			t += 1 / 60
		end
		T.expect(inst.hop).toBeNear(1, 0.01)
		T.expect(planted > 20).toBe(true)
		T.expect(airborne > 20).toBe(true)
		T.expect(slides <= 1).toBe(true)
		-- both feet together (the rest stance's offset between them only)
		local z0 = rig.skel.bones.LeftFoot.pos[3] - rig.skel.bones.RightFoot.pos[3]
		T.expect(math.abs(((lastL :: Vec)[3] - (lastR :: Vec)[3]) - z0)).toBeBetween(0, 0.1 * L)
		-- the wander alternates the feet
		local walker = BipedMotion.new(rig.skel, "wyvernRegular", 5) :: BipedMotion.Instance
		local most = 0
		t = 0
		while t < 2 do
			local posed = BipedMotion.step(walker, input({ now = t, speed = 5.2, gait = "walk", snap = t == 0 }))
			local fk = forward(rig, posed)
			local l, r = fk[nameOf(rig, "LeftFoot")].pos, fk[nameOf(rig, "RightFoot")].pos
			most = math.max(most, math.abs((l[3] - r[3]) - z0))
			t += 1 / 60
		end
		T.expect(walker.hop).toBeNear(0, 1e-9)
		T.expect(most > 0.4 * L).toBe(true)
	end)

	T.it("no NaN and no pops through a long fight: walk, trot, bounds, turns, every blow, hits, the death", function()
		local rig = rigOf("wyvern")
		local names = {}
		for name in WYVERN.actions do
			if name ~= "deathDragon" then
				table.insert(names, name)
			end
		end
		table.sort(names)
		local plan = {}
		local at = 3
		for _, name in names do
			table.insert(plan, { name = name, start = at, hit = if name == "spit" then 0.5 else 1.3 })
			at += 1.3 + 2.2
		end
		table.insert(plan, { name = "deathDragon", start = at, hit = 0.25 })
		local finish = at + 3
		local largest, excess, when = continuity(rig.keyed, function(dt, sink)
			local inst = BipedMotion.new(rig.skel, "wyvernRegular", 11) :: BipedMotion.Instance
			local t, yaw = 0, 0
			while t < finish do
				local speed = if t < 1 then 5.2 elseif t < 2 then 9.1 elseif t < 3 then 13 else 0
				local gait = if t < 1 then "walk" elseif t < 2 then "trot" else "run"
				local action = nil
				for _, step in plan do
					if t >= step.start then
						action = step
					end
				end
				-- the turn rate eased in and out as client/Controllers/AnimationController smooths it
				yaw += ((if t > 1.5 and t < 2.5 then 1.5 else 0) - yaw) * math.min(1, dt * 10)
				local posed = BipedMotion.step(
					inst,
					input({
						now = t,
						dt = dt,
						speed = speed,
						yawRate = yaw,
						combat = t > 2,
						gait = gait,
						action = action,
						hitAt = if t > 20 and t < 21 then 20.2 else nil,
						hitSide = "left",
						look = { 0.3, 0.1, -1 },
						snap = t == 0,
					})
				)
				checkFinite(posed, `wyvern at {t}`)
				sink(t, posed)
				t += dt
			end
		end)
		if excess > 0 then
			error(`a pop at {when}: {excess} over a continuous motion`)
		end
		-- the fastest blows and the bounds at full speed stay under 45 rad/s
		T.expect(largest).toBeBetween(0, 0.25)
	end)
end)

T.describe("Spirits (Logic/SpiritMotion)", function()
	local function step(inst: SpiritMotion.Instance, from: number, to: number, make: (number) -> any)
		local posed
		local t = from
		while t < to do
			posed = SpiritMotion.step(inst, make(t))
			t += 1 / 60
		end
		return posed
	end

	T.it("the specter's robe trails behind the drift with lag and out of turns", function()
		local rig = rigOf("specter")
		local inst = SpiritMotion.new(rig.skel, "specter", 2) :: SpiritMotion.Instance
		local knee = nameOf(rig, "LeftLeg")
		local still = forward(
			rig,
			step(inst, 0, 2, function(t)
				return input({ now = t })
			end)
		)[knee].pos
		local early = forward(
			rig,
			step(inst, 2, 2.1, function(t)
				return input({ now = t, speed = 13 })
			end)
		)[knee].pos
		local late = forward(
			rig,
			step(inst, 2.1, 4, function(t)
				return input({ now = t, speed = 13 })
			end)
		)[knee].pos
		T.expect(late[3] - still[3]).toBeBetween(0.2 * SCALE, 3 * SCALE)
		T.expect(early[3] - still[3] < 0.6 * (late[3] - still[3])).toBe(true)
		-- a left turn swings the robe out to the right
		local turning = forward(
			rig,
			step(inst, 4, 6, function(t)
				return input({ now = t, speed = 13, yawRate = 1.5 })
			end)
		)[knee].pos
		T.expect(turning[1] - late[1]).toBeBetween(0.1 * SCALE, 3 * SCALE)
	end)

	T.it(
		"the specter flickers between 0.15 and 0.35, dips solid at the bolt's W; the elemental does not flicker",
		function()
			local rig = rigOf("specter")
			local inst = SpiritMotion.new(rig.skel, "specter", 2) :: SpiritMotion.Instance
			local low, high = 1, 0
			step(inst, 0, 0.01, function(t)
				return input({ now = t })
			end)
			local t = 0
			while t < 4 do
				SpiritMotion.step(inst, input({ now = t }))
				local f = SpiritMotion.fade(inst)
				low, high = math.min(low, f), math.max(high, f)
				t += 1 / 30
			end
			T.expect(low).toBeBetween(0.14, 0.17)
			T.expect(high).toBeBetween(0.33, 0.36)
			local run = { name = "bolt", start = 10, hit = 0.5 }
			step(inst, 10, 10.5, function(tt)
				return input({ now = tt, combat = true, action = run })
			end)
			T.expect(SpiritMotion.fade(inst)).toBeBetween(0, 0.12)
			local ice = rigOf("iceElemental")
			local elemental = SpiritMotion.new(ice.skel, "iceElemental", 2) :: SpiritMotion.Instance
			step(elemental, 0, 2, function(tt)
				return input({ now = tt })
			end)
			T.expect(SpiritMotion.fade(elemental)).toBe(0)
		end
	)

	T.it("the bolt leaves the hand thrust forward at W", function()
		for _, model in { "specter", "iceElemental" } do
			local rig = rigOf(model)
			local inst = SpiritMotion.new(rig.skel, model, 4) :: SpiritMotion.Instance
			local hand = nameOf(rig, "RightHand")
			local run = { name = "bolt", start = 0, hit = 0.5 }
			local function handAt(time: number): Vec
				local posed = SpiritMotion.step(inst, input({ now = time, combat = true, action = run, snap = true }))
				return forward(rig, posed)[hand].pos
			end
			local drawn = handAt(BipedMotion.times(inst.style.actions.bolt, 0.5) - 0.05)
			local released = handAt(0.5)
			T.expect(drawn[3] - released[3]).toBeBetween(0.3 * SCALE, 4 * SCALE)
		end
	end)

	T.it(
		"the deaths: the specter rises 1.5 studs a scale, turns and is gone by 0.8 s; the elemental by 0.4 s",
		function()
			local rig = rigOf("specter")
			local inst = SpiritMotion.new(rig.skel, "specter", 6) :: SpiritMotion.Instance
			T.expect(SpiritMotion.death(inst)).toBe("deathRise")
			local hips = nameOf(rig, "Hips")
			local run = { name = "deathRise", start = 1, hit = 0.15 }
			local before = forward(
				rig,
				step(inst, 0, 1, function(t)
					return input({ now = t })
				end)
			)[hips].pos
			local after = forward(
				rig,
				step(inst, 1, 1.81, function(t)
					return input({ now = t, action = run })
				end)
			)[hips].pos
			T.expect(SpiritMotion.fade(inst)).toBeNear(1, 1e-6)
			T.expect(after[2] - before[2]).toBeBetween(1.2 * SCALE, 2.2 * SCALE)
			step(inst, 1.81, 4, function(t)
				return input({ now = t, action = run })
			end)
			T.expect(SpiritMotion.fade(inst)).toBeNear(1, 1e-6)
			local ice = rigOf("iceElemental")
			local elemental = SpiritMotion.new(ice.skel, "iceElemental", 6) :: SpiritMotion.Instance
			T.expect(SpiritMotion.death(elemental)).toBe("deathShatter")
			local shatter = { name = "deathShatter", start = 0, hit = 0.25 }
			step(elemental, 0, 0.2, function(t)
				return input({ now = t, action = shatter })
			end)
			T.expect(SpiritMotion.fade(elemental) < 0.5).toBe(true)
			step(elemental, 0.2, 0.41, function(t)
				return input({ now = t, action = shatter })
			end)
			T.expect(SpiritMotion.fade(elemental)).toBeNear(1, 1e-6)
		end
	)

	T.it(
		"the appear fades in; no NaN and no pops through every action, the drift, the turns, hits, the death",
		function()
			for _, model in { "specter", "iceElemental" } do
				local rig = rigOf(model)
				local fadeStart = -1
				local largest, excess, when = continuity(rig.keyed, function(dt, sink)
					local inst = SpiritMotion.new(rig.skel, model, 9) :: SpiritMotion.Instance
					local style = inst.style
					local plan = {
						{ name = style.spawn :: string, start = 0, hit = 0.5 },
						{ name = "bolt", start = 2, hit = 0.5 },
						{ name = "wail", start = 4, hit = 1.2 },
						{ name = "burst", start = 7, hit = 1.4 },
						{ name = "pool", start = 10, hit = 2.2 },
						{ name = "swoop", start = 13, hit = 1.4 },
						{ name = SpiritMotion.death(inst), start = 16, hit = 0.2 },
					}
					local t, yaw = 0, 0
					while t < 18 do
						local action = nil
						for _, s in plan do
							if t >= s.start then
								action = s
							end
						end
						yaw += ((if t > 2 and t < 3 then 1 else 0) - yaw) * math.min(1, dt * 10)
						local posed = SpiritMotion.step(
							inst,
							input({
								now = t,
								dt = dt,
								speed = if t > 1 and t < 3 then 13 else 0,
								yawRate = yaw,
								combat = t > 1,
								action = action,
								hitAt = if t > 8 and t < 9 then 8.2 else nil,
								hitSide = "front",
								look = { 0, 0, -1 },
								snap = t == 0,
							})
						)
						if t == 0 then
							fadeStart = SpiritMotion.fade(inst)
						end
						checkFinite(posed, `{model} at {t}`)
						sink(t, posed)
						t += dt
					end
				end)
				T.expect(fadeStart).toBeBetween(0.9, 1)
				if excess > 0 then
					error(`{model}: a pop at {when}: {excess} over a continuous motion`)
				end
				T.expect(largest).toBeBetween(0, 0.25)
			end
		end
	)
end)

T.describe("AnimLab: the new biped states", function()
	T.it("mob wyvern / specter / iceElemental take every state of their styles", function()
		local function shows(id: string, state: string): boolean
			local command = AnimLab.parse({ "mob", id, state })
			return command ~= nil and (command :: any).slot == state
		end
		for _, state in { "spit", "pounce", "breath", "claw", "stomp", "roar", "deathDragon", "run", "trot", "walk" } do
			T.expect(shows("wyvern", state)).toBe(true)
		end
		for _, id in { "specter", "iceElemental" } do
			for _, state in
				{ "bolt", "wail", "burst", "swoop", "pool", "deathRise", "deathShatter", "spawnSpirit", "idle" }
			do
				T.expect(shows(id, state)).toBe(true)
			end
		end
	end)
end)
