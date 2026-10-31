--!strict
-- Template animation, the dragon (docs/ANIM-WZORCE.md F4, 2026-10-31): the young frost dragon's new model (the dump
-- tools/anim/rigs/youngFrostDragon_v2.json read from its FBX) through Logic/QuadMotion with Logic/DragonMotion's wings
-- and the forward kinematics of tests/QuadRigFk: the role map with the wing chains, the wings as modelled and the
-- procedural fold along the body, every blow of its kit landing on the server's hit, the pounce on its flight, the
-- breath sweeping the cone, the planted feet at the server's paces with the gallop's wingbeat, nothing through the
-- ground, no NaN, no pops where actions blend, the stun and the freeze, the old model keeping its wyvern style.

local ActionFx = require("../src/shared/Logic/ActionFx")
local AnimLab = require("../src/shared/Logic/AnimLab")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local Combat = require("../src/shared/Data/Combat")
local DragonMotion = require("../src/shared/Logic/DragonMotion")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local MotionFx = require("../src/shared/Data/MotionFx")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local QuadMotion = require("../src/shared/Logic/QuadMotion")
local QuadPose = require("../src/shared/Logic/QuadPose")
local QuadRigFk = require("./QuadRigFk")
local QuadStyles = require("../src/shared/Data/QuadStyles")
local T = require("./Test")

type Vec = { number }

local KIND = "youngFrostDragon"
local LEGS = { "FL", "FR", "HL", "HR" }
local DT = 1 / 60
local STYLE = assert(QuadStyles.get("dragon"))
local SKEL, DUMP = QuadRigFk.skeleton(KIND, 1, "youngFrostDragon_v2")
local skel = assert(SKEL, "dragon skeleton")
local L = skel.L
local MONSTER = assert(Monsters.get(KIND))
-- the model in the game: the import scaled to the old model's height, times the drawn size and the kind's size
local ASSET = assert(MonsterAssets[KIND], KIND)
local SCALE = ASSET.height / DUMP.height * (ASSET.visual or 1) * MONSTER.size
local WING_TIPS = { L = "bone_15", R = "bone_21" }

local function dist(a: Vec, b: Vec): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- The windup an action plays with in the game (AnimLab's rule): its ability's, the throw's, the regular blow's.
local function windupOf(name: string): number
	local action = STYLE.actions[name]
	if string.sub(name, 1, 5) == "death" then
		return action.strike
	end
	local best: number? = nil
	for id, act in STYLE.abilities do
		local ability = MonsterAbilities.get(id)
		if act == name and ability then
			best = math.max(best or 0, ability.windup)
		end
	end
	if best then
		return best
	elseif name == STYLE.throw then
		return Combat.basicWind.throw * Combat.basicWindVariant.elite2
	elseif name == STYLE.aggro then
		return 0.45
	elseif name == STYLE.spawn or table.find(STYLE.fidgets, name) then
		return 0.5
	end
	return Combat.basicWind.melee
end

local function settle(inst: QuadMotion.Instance, now: number, seconds: number, input: { [string]: any }): number
	for _ = 1, math.floor(seconds / DT) do
		now += DT
		local i = table.clone(input)
		i.now, i.dt = now, DT
		QuadMotion.step(inst, i :: any)
	end
	return now
end

-- The lowest joint (leg lengths) other than the body bone, and whether any joint is NaN.
local function lowest(at: { [string]: Vec }): (number, boolean)
	local low, nan = math.huge, false
	for name, p in at do
		if p[1] ~= p[1] or p[2] ~= p[2] or p[3] ~= p[3] then
			nan = true
		elseif name ~= skel.rig.body then
			low = math.min(low, p[2] / L)
		end
	end
	return low, nan
end

-- Plays `name` standing (hit `hit`, the target `reach` ahead) and calls `each(t, at, turns)` every frame; the frames
-- land on the hit exactly.
local function play(
	name: string,
	hit: number,
	each: (t: number, at: { [string]: Vec }, turns: { [string]: any }) -> (),
	extra: { [string]: any }?
)
	local inst = assert(QuadMotion.new(skel, "dragon", 4))
	local look = { 0, 0, -5 * L }
	local now = settle(inst, 0, 1, { speed = 0, yawRate = 0, combat = true, look = look })
	local action = STYLE.actions[name]
	local length = MotionTimeline.length(action, hit)
	local n = math.ceil(hit / DT)
	local dt = hit / n
	local run = { name = name, start = now, hit = hit, reach = { 0, 0, -5 * L } }
	if extra then
		for k, v in extra do
			(run :: any)[k] = v
		end
	end
	local t = 0
	while t < length + 0.3 do
		t += dt
		local posed = QuadMotion.step(inst, {
			now = now + t,
			dt = dt,
			speed = 0,
			yawRate = 0,
			combat = true,
			action = run,
			look = if string.sub(name, 1, 5) == "death" then nil else look,
		})
		local at, turns = QuadRigFk.posed(skel, posed)
		each(t, at, turns)
	end
end

-- The wing controls of a pose as Logic/DragonMotion resolves them.
local function resolved(controls: { [string]: number }): { [string]: number }
	local d = assert(DragonMotion.new(skel, STYLE.wings, 1))
	local c = table.clone(controls)
	DragonMotion.resolve(d, c)
	return c
end

T.describe("Dragon: the new model's role map", function()
	T.it("maps every role, both wing chains and the six tail bones onto bones of the dump", function()
		T.expect(#skel.rig.tail).toBe(6)
		local segs: { [number]: number } = {}
		for _, w in skel.wings do
			segs[w.seg] = (segs[w.seg] or 0) + 1
		end
		for seg = 0, 4 do
			T.expect(segs[seg]).toBe(2)
		end
		for _, tip in WING_TIPS do
			T.expect(DUMP.bones[tip] ~= nil).toBe(true)
		end
	end)

	T.it("rests the feet on the ground, the left legs and wing on the left", function()
		local rest = QuadRigFk.feetAt(skel, resolved({ wo = 1 }))
		for _, leg in LEGS do
			T.expect(rest[leg][2] / L).toBeBetween(-0.01, 0.25)
			T.expect(rest[leg][1] < 0).toBe(string.sub(leg, 2, 2) == "L")
		end
		T.expect(DUMP.bones[WING_TIPS.L].pos[1] < 0).toBe(true)
		T.expect(DUMP.bones[WING_TIPS.R].pos[1] > 0).toBe(true)
	end)

	T.it("shows the wings as modelled at openness 1, whatever the bones' rest axes", function()
		local at = QuadRigFk.positions(skel, resolved({ wo = 1 }))
		for name, bone in DUMP.bones do
			for i = 1, 3 do
				T.expect(at[name][i]).toBeNear(bone.pos[i], 1e-6)
			end
		end
	end)

	T.it("plants a foot on its target under a moving body", function()
		local rest = QuadRigFk.feetAt(skel, {})
		for _, body in { { by = -0.05 }, { by = -0.12, bpitch = 0.05 }, { by = -0.06, bpitch = -0.05, broll = 0.04 } } do
			for _, leg in LEGS do
				for _, target in { { 0, -0.15 }, { 0, 0 }, { 0, 0.15 }, { 0.1, 0 } } do
					local c: QuadPose.Controls = table.clone(body) :: any
					c[leg .. "k"], c[leg .. "y"], c[leg .. "z"] = 1, target[1], target[2]
					local foot = QuadRigFk.feetAt(skel, c)[leg]
					T.expect((foot[2] - rest[leg][2]) / L).toBeNear(target[1], 0.012)
					T.expect((foot[3] - rest[leg][3]) / L).toBeNear(target[2], 0.012)
				end
			end
		end
	end)
end)

T.describe("Dragon: the wings", function()
	T.it("folds each wing along the body: over the back, tucked in, from the shoulder back toward the hips", function()
		local at = QuadRigFk.positions(skel, resolved({}))
		local shoulder = at["tripo::Spine_3"]
		local hips = at["bone_37"]
		for side, tip in WING_TIPS do
			local m = if side == "R" then 1 else -1
			for _, name in
				{ tip, if side == "R" then "bone_18" else "bone_12", if side == "R" then "bone_19" else "bone_13" }
			do
				local p = at[name]
				-- tucked in: within the body's width, on its own side
				T.expect(p[1] * m / L).toBeBetween(0, 0.6)
				-- over the back, not on the ground nor high above it
				T.expect(p[2] / L).toBeBetween(1.0, 1.75)
				-- between the shoulders and the hips
				T.expect(p[3]).toBeBetween(shoulder[3] - 0.1 * L, hips[3] + 0.2 * L)
			end
		end
	end)

	T.it("opens smoothly from folded through as modelled to flat out", function()
		local prev: { [string]: Vec }? = nil
		local o = 0
		local worst = 0
		while o <= 2.2 + 1e-9 do
			local at = QuadRigFk.positions(skel, resolved({ wo = o }))
			if prev then
				for name, p in at do
					worst = math.max(worst, dist(p, prev[name]) / L)
				end
			end
			prev = at
			o += 0.05
		end
		T.expect(worst < 0.12).toBe(true)
		-- as modelled the wings span the model's width; flat out a little wider and lower
		local spread = QuadRigFk.positions(skel, resolved({ wo = 1 }))
		local flat = QuadRigFk.positions(skel, resolved({ wo = 2 }))
		local width = DUMP.width / L
		T.expect((spread[WING_TIPS.R][1] - spread[WING_TIPS.L][1]) / L > 0.65 * width).toBe(true)
		T.expect(flat[WING_TIPS.R][1] - flat[WING_TIPS.L][1] > spread[WING_TIPS.R][1] - spread[WING_TIPS.L][1])
			.toBe(true)
		T.expect(flat[WING_TIPS.R][2] < spread[WING_TIPS.R][2]).toBe(true)
	end)

	T.it("beats on the timeline: the downstroke from the top to the bottom over 0.45 of a beat", function()
		local top = QuadRigFk.positions(skel, resolved({ wo = 2, flap = 1, beat = 0 }))
		local bottom = QuadRigFk.positions(skel, resolved({ wo = 2, flap = 1, beat = 0.45 }))
		local again = QuadRigFk.positions(skel, resolved({ wo = 2, flap = 1, beat = 1 }))
		for _, tip in WING_TIPS do
			T.expect((top[tip][2] - bottom[tip][2]) / L > 1.2).toBe(true)
			T.expect(dist(top[tip], again[tip]) / L < 1e-6).toBe(true)
		end
	end)

	T.it("mirrors a run's wing keys onto the other wing and twins the left claw from the right one", function()
		local claw, clawL = STYLE.actions.claw, STYLE.actions.clawL
		T.expect(claw.sided).toBe(true)
		local function wingKeys(action: MotionTimeline.Action, side: string): number
			local n = 0
			for _, key in action.keys do
				for name in key.pose do
					if string.match(name, "^w" .. side .. "%a$") then
						n += 1
					end
				end
			end
			return n
		end
		T.expect(wingKeys(claw, "R") > 0).toBe(true)
		T.expect(wingKeys(clawL, "L")).toBe(wingKeys(claw, "R"))
		T.expect(wingKeys(clawL, "R")).toBe(0)
		local deathR = STYLE.actions.deathR.keys
		local deathL = STYLE.actions.deathL.keys
		T.expect(deathR[#deathR].pose.wLo).toBe(deathL[#deathL].pose.wRo)
		T.expect(deathR[#deathR].pose.tyaw).toBe(-(deathL[#deathL].pose.tyaw :: number))
	end)
end)

T.describe("Dragon: the kit lands on the hit", function()
	local blows: { { name: string, hit: number } } = {}
	local melee = Combat.basicWind.melee
	for _, variant in { "normal", "elite", "elite2" } do
		for count = 1, #STYLE.basic do
			table.insert(
				blows,
				{ name = QuadMotion.pick(STYLE, nil, nil, count), hit = melee * Combat.basicWindVariant[variant] }
			)
		end
	end
	local abilities: { string } = { MONSTER.ability :: string }
	for _, kit in { "elite", "elite2" } do
		for _, id in assert(MonsterAbilities.kit(kit)).abilities do
			table.insert(abilities, id)
		end
	end
	for _, id in abilities do
		T.it(`{id} has its own action`, function()
			T.expect(STYLE.abilities[id] ~= nil).toBe(true)
		end)
		local ability = assert(MonsterAbilities.get(id), id)
		table.insert(blows, { name = QuadMotion.pick(STYLE, id, nil, 1), hit = ability.windup })
	end
	table.insert(blows, {
		name = QuadMotion.pick(STYLE, nil, "throw", 1),
		hit = Combat.basicWind.throw * Combat.basicWindVariant.elite2,
	})
	T.it("bites, claws on both sides, buffets with the wings and whips the tail in its regular blows", function()
		for _, name in { "bite", "claw", "clawL", "buffet", "tail" } do
			T.expect(table.find(STYLE.basic, name) ~= nil).toBe(true)
		end
		T.expect(QuadMotion.pick(STYLE, "frostBreath", nil, 1)).toBe("breath")
		T.expect(QuadMotion.pick(STYLE, nil, "throw", 1)).toBe("spit")
	end)
	for _, blow in blows do
		T.it(`{blow.name} strikes exactly at W {blow.hit}`, function()
			local action = STYLE.actions[blow.name]
			T.expect(action ~= nil).toBe(true)
			local last: MotionTimeline.Key? = nil
			for _, key in action.keys do
				if key.seg == "S" then
					last = key
				end
			end
			local key = assert(last, blow.name)
			T.expect(key.u).toBe(1)
			local seg = MotionTimeline.segments(action, blow.hit)
			T.expect(seg.S[1] + seg.S[2]).toBeNear(blow.hit, 1e-9)
			local at = assert(QuadMotion.controlsAt(STYLE, blow.name, blow.hit, blow.hit))
			for name, v in key.pose do
				T.expect(at[name]).toBeNear(v, 1e-9)
			end
		end)
	end
end)

T.describe("Dragon: what the model shows", function()
	local rest = QuadRigFk.feetAt(skel, {})
	-- the blows whose feet strike the ground on the hit
	for _, blow in
		{
			{ name = "claw", hit = 0.55, feet = { "FR" } },
			{ name = "clawL", hit = 0.66, feet = { "FL" } },
			{ name = "rake", hit = 1.8, feet = { "FL", "FR" } },
			{ name = "stomp", hit = 2.2, feet = { "FL", "FR" } },
			{ name = "pounce", hit = 1.4, feet = { "FL", "FR" } },
		}
	do
		T.it(`{blow.name}: the feet come down from high and strike the ground at W`, function()
			local high, atHit = 0, math.huge
			play(blow.name, blow.hit, function(t, at, turns)
				local feet = QuadRigFk.feetOf(skel, at, turns)
				for _, leg in blow.feet do
					local y = (feet[leg][2] - rest[leg][2]) / L
					if t < blow.hit - 1e-6 then
						high = math.max(high, y)
					elseif math.abs(t - blow.hit) < 1e-6 then
						atHit = math.max(math.abs(y), if atHit == math.huge then 0 else atHit)
					end
				end
			end)
			T.expect(atHit < 0.02).toBe(true)
			T.expect(high > 0.15).toBe(true)
		end)
	end

	T.it("bite: the snout strikes forward, furthest out at W", function()
		local restSnout = QuadRigFk.positions(skel, {})["tripo::Head_4"]
		local atHit: Vec? = nil
		local front = math.huge
		play("bite", 0.55, function(t, at)
			local snout = at["tripo::Head_4"]
			front = math.min(front, snout[3])
			if math.abs(t - 0.55) < 1e-6 then
				atHit = snout
			end
		end)
		local hitSnout = assert(atHit, "the frame of the hit")
		T.expect((restSnout[3] - hitSnout[3]) / L > 0.3).toBe(true)
		T.expect((hitSnout[3] - front) / L < 0.06).toBe(true)
	end)

	T.it("buffet: both wings beat down from high to W", function()
		local action = STYLE.actions.buffet
		local seg = MotionTimeline.segments(action, 0.55)
		local cocked = seg.A[1] + seg.A[2]
		local up: { [string]: number } = {}
		local down: { [string]: number } = {}
		play("buffet", 0.55, function(t, at)
			for side, tip in WING_TIPS do
				if math.abs(t - cocked) < DT / 2 + 1e-6 and up[side] == nil then
					up[side] = at[tip][2]
				elseif math.abs(t - 0.55) < 1e-6 then
					down[side] = at[tip][2]
				end
			end
		end)
		for side in WING_TIPS do
			T.expect(((up[side] or 0) - (down[side] or 0)) / L > 0.8).toBe(true)
		end
	end)

	T.it("tail: the tail's tip sweeps through the front on the hit", function()
		local heading: number? = nil
		play("tail", 0.55, function(t, at)
			if math.abs(t - 0.55) < 1e-6 then
				local tip, root = at["tripo::Tail_3"], at["tripo::Root"]
				heading = math.deg(math.atan2(-(tip[1] - root[1]), -(tip[3] - root[3])))
			end
		end)
		-- (heading 0 = straight ahead)
		T.expect(math.abs(assert(heading, "the frame of the hit")) < 50).toBe(true)
	end)

	T.it("pounce: flies on its arc with the wings out and lands short of the target on W", function()
		local hit = 1.4
		local reach = 5 * L
		local action = STYLE.actions.pounce
		local seg = MotionTimeline.segments(action, hit)
		local top, span = 0, 0
		local landed: Vec? = nil
		play("pounce", hit, function(t, at)
			local root = at["tripo::Root"]
			if t > seg.S[1] and t < hit then
				top = math.max(top, root[2] / L)
				span = math.max(span, (at[WING_TIPS.R][1] - at[WING_TIPS.L][1]) / L)
			end
			if math.abs(t - hit) < 1e-6 then
				landed = root
			end
		end)
		local root = assert(landed, "the frame of the hit")
		-- the server's arc: a quarter of the flight, at least a leg length over the stance
		T.expect(top > 0.138 + 0.9).toBe(true)
		T.expect(span > 2.5).toBe(true)
		-- the jaws at the target: the body a little more than a leg length short of it
		T.expect(-root[3] / L).toBeNear((reach - 1.1 * L) / L, 0.25)
	end)

	-- The head's heading (degrees, + to its left) from the head bone's joint to the snout's.
	local function heading(at: { [string]: Vec }): number
		local a, b = at["tripo::Head_3"], at["tripo::Head_4"]
		return math.deg(math.atan2(-(b[1] - a[1]), -(b[3] - a[3])))
	end

	T.it("breath: mantles the wings and sweeps the head across the cone while the stream runs", function()
		local hit = 1.3
		local action = STYLE.actions.breath
		local seg = MotionTimeline.segments(action, hit)
		local stop = seg.F[1] + 0.85 * seg.F[2]
		local h0: number? = nil
		local h1: number? = nil
		local span = math.huge
		play("breath", hit, function(t, at)
			if math.abs(t - hit) < DT / 2 then
				h0 = heading(at)
			end
			if math.abs(t - stop) < DT / 2 then
				h1 = heading(at)
			end
			if t >= hit and t <= stop then
				span = math.min(span, (at[WING_TIPS.R][1] - at[WING_TIPS.L][1]) / L)
			end
		end)
		-- from its right to its left over a good part of the server's 60 degree cone, within it
		local from, to = assert(h0, "the hit"), assert(h1, "the stream's end")
		T.expect(from < -5).toBe(true)
		T.expect(to > 5).toBe(true)
		T.expect(to - from).toBeBetween(25, 60)
		-- the wings held half open over the back all the while
		T.expect(span > 1.6).toBe(true)
	end)

	T.it("roar: the wings spread wide and high on the hit", function()
		local span, high = 0, 0
		local shoulder = 0
		play("roar", 0.45, function(t, at)
			if math.abs(t - 0.45) < 1e-6 then
				span = (at[WING_TIPS.R][1] - at[WING_TIPS.L][1]) / L
				high = math.min(at[WING_TIPS.R][2], at[WING_TIPS.L][2]) / L
				shoulder = at["tripo::Spine_3"][2] / L
			end
		end)
		T.expect(span > 2.4).toBe(true)
		T.expect(high > shoulder + 0.3).toBe(true)
	end)

	for _, name in { "deathL", "deathR" } do
		T.it(`{name}: ends on its side with the wings fanned out, nothing through the ground`, function()
			local action = STYLE.actions[name]
			local low = math.huge
			local last: { [string]: Vec }? = nil
			local lastTurns: { [string]: any }? = nil
			play(name, action.strike, function(_, at, turns)
				low = math.min(low, (lowest(at)))
				last, lastTurns = at, turns
			end)
			T.expect(low > -0.02).toBe(true)
			local turns = assert(lastTurns, name)
			local body = turns["tripo::Root"]
			-- the body's up axis (its turn's second column) lies close to the ground plane
			T.expect(math.abs(body[5]) < 0.2).toBe(true)
			-- on the left flank the up axis points to -X (its back to the left)
			T.expect(body[2] < 0).toBe(name == "deathL")
			local at = assert(last, name)
			for _, tip in WING_TIPS do
				T.expect(dist(at[tip], at["tripo::Spine_3"]) / L > 1).toBe(true)
			end
		end)
	end

	local names: { string } = {}
	for name in STYLE.actions do
		table.insert(names, name)
	end
	table.sort(names)
	-- the wings' bones (a wing's tip sweeps far on a short lever: its pop is a frame out of step with its neighbours)
	local wingBone: { [string]: boolean } = {}
	for name in DUMP.bones do
		local b: string? = name
		while b do
			if skel.wings[b] then
				wingBone[name] = true
				break
			end
			b = DUMP.bones[b].parent
		end
	end
	for _, name in names do
		T.it(`{name}: no NaN, nothing through the ground, no pop where it starts or ends`, function()
			local action = STYLE.actions[name]
			local hit = windupOf(name)
			local inst = assert(QuadMotion.new(skel, "dragon", 6))
			local look = { 0, 0, -5 * L }
			-- it walks up and stops for the blow (the server stops it), and walks on after it
			local now =
				settle(inst, 0, 1.5, { speed = 1.2 * L, gait = "walk", yawRate = 0, combat = true, look = look })
			local start = now + DT
			local run = { name = name, start = start, hit = hit, reach = { 0, 0, -4 * L } }
			local length = MotionTimeline.length(action, hit)
			local prev: { [string]: Vec }? = nil
			local low, nan = math.huge, false
			local moves: { { [string]: number } } = {}
			local edges: { boolean } = {}
			for _ = 1, math.ceil((length + 0.8) / DT) do
				now += DT
				local t = now - start
				local speed = if t > length + 0.3 then 1.2 * L else 0
				local posed = QuadMotion.step(inst, {
					now = now,
					dt = DT,
					speed = speed,
					gait = "walk",
					yawRate = 0,
					combat = true,
					action = run,
					look = look,
				})
				local at = QuadRigFk.posed(skel, posed)
				local l, bad = lowest(at)
				low, nan = math.min(low, l), nan or bad
				if prev then
					local frame: { [string]: number } = {}
					for bone, p in at do
						frame[bone] = dist(p, prev[bone]) / L - speed * DT / L
					end
					table.insert(moves, frame)
					local edge = t < 0.2 or (t > length - 0.2 and t < length + 0.1 and not action.travel)
					table.insert(edges, edge and not action.hold)
				end
				prev = at
			end
			local pop, wingPop, spike = 0, 0, 0
			for i, frame in moves do
				if edges[i] then
					for bone, d in frame do
						if wingBone[bone] then
							local before = if moves[i - 1] then moves[i - 1][bone] else 0
							local after = if moves[i + 1] then moves[i + 1][bone] else 0
							wingPop = math.max(wingPop, d)
							spike = math.max(spike, d - 1.6 * math.max(before, after))
						else
							pop = math.max(pop, d)
						end
					end
				end
			end
			T.expect(nan).toBe(false)
			T.expect(low > -0.02).toBe(true)
			T.expect(pop < 0.12).toBe(true)
			T.expect(wingPop < 0.4).toBe(true)
			T.expect(spike < 0.03).toBe(true)
		end)
	end
end)

T.describe("Dragon: gaits at the server's paces", function()
	local rest = QuadRigFk.feetAt(skel, {})
	-- the server's intent: wander 0.4x, home 0.7x, the chase 1x moveSpeed (dump units: the game's model scale)
	for _, pace in { { "walk", 0.4, "walk" }, { "trot", 0.7, "trot" }, { "run", 1, "gallop" } } do
		local speed = MONSTER.moveSpeed * pace[2] / SCALE
		T.it(`{pace[1]}: the {pace[3]}, feet planted in stance, nothing through the ground`, function()
			local inst = assert(QuadMotion.new(skel, "dragon", 9))
			local fighting = pace[1] == "run"
			local input = { speed = speed, gait = pace[1], yawRate = 0, combat = fighting }
			local now = settle(inst, 0, 2, input)
			T.expect((inst.weights[pace[3]] or 0) > 0.97).toBe(true)
			local g = STYLE.gaits[pace[3]]
			local slide, hover, low, nan = 0, 0, math.huge, false
			local runs: { [string]: { number } } = {}
			local tipLow, tipHigh = math.huge, -math.huge
			for _ = 1, 240 do
				now += DT
				local i = table.clone(input) :: any
				i.now, i.dt = now, DT
				local posed = QuadMotion.step(inst, i)
				local at, turns = QuadRigFk.posed(skel, posed)
				local l, bad = lowest(at)
				low, nan = math.min(low, l), nan or bad
				tipLow = math.min(tipLow, at[WING_TIPS.R][2] / L)
				tipHigh = math.max(tipHigh, at[WING_TIPS.R][2] / L)
				local feet = QuadRigFk.feetOf(skel, at, turns)
				for _, leg in LEGS do
					local duty = if string.sub(leg, 1, 1) == "F" then (g.dutyFront or g.duty) else g.duty
					local p = (inst.phase - g.foot[leg]) % 1
					local ground = (feet[leg][3] - speed * now) / L
					if p > 0.08 * duty and p < 0.75 * duty then
						local r = runs[leg]
						if not r then
							r = { ground, ground }
							runs[leg] = r
						end
						r[1], r[2] = math.min(r[1], ground), math.max(r[2], ground)
						slide = math.max(slide, r[2] - r[1])
						hover = math.max(hover, math.abs(feet[leg][2] - rest[leg][2]) / L)
					else
						runs[leg] = nil
					end
				end
			end
			T.expect(nan).toBe(false)
			T.expect(low > -0.02).toBe(true)
			T.expect(slide < 0.015).toBe(true)
			T.expect(hover < 0.015).toBe(true)
			if pace[3] == "gallop" then
				-- the wings beat once a stride in the bound
				T.expect(tipHigh - tipLow > 0.5).toBe(true)
			else
				-- folded while it walks and trots
				T.expect(tipHigh - tipLow < 0.15).toBe(true)
			end
		end)
	end

	T.it("steps down from the gallop when the chase is too slow for it", function()
		local inst = assert(QuadMotion.new(skel, "dragon", 3))
		settle(inst, 0, 2, { speed = MONSTER.moveSpeed * 0.45 / SCALE, gait = "run", yawRate = 0, combat = true })
		T.expect((inst.weights.gallop or 0) < 0.03).toBe(true)
	end)
end)

T.describe("Dragon: stun and freeze", function()
	T.it("hangs its head while the server's stun lasts, then recovers", function()
		local inst = assert(QuadMotion.new(skel, "dragon", 2))
		local base = { speed = 0, yawRate = 0, combat = true, serverNow = 100 }
		local now = settle(inst, 0, 1, base)
		local function head(input: { [string]: any }): number
			local i = table.clone(input) :: any
			i.now, i.dt = now, 0
			local at = QuadRigFk.posed(skel, QuadMotion.step(inst, i))
			return at["tripo::Head_3"][2] / L
		end
		local free = head(base)
		local stunned = table.clone(base)
		stunned.effects = "stun:101.5"
		now = settle(inst, now, 1, stunned)
		T.expect(inst.stun > 0.95).toBe(true)
		T.expect(free - head(stunned) > 0.1).toBe(true)
		-- the stun's end (server time) passes: it comes to
		local after = table.clone(stunned)
		after.serverNow = 102
		now = settle(inst, now, 1.5, after)
		T.expect(inst.stun < 0.05).toBe(true)
		T.expect(math.abs(free - head(after)) < 0.03).toBe(true)
	end)

	T.it("holds its pose exactly while frozen (the server's freeze and AnimLab's), mid-blow", function()
		for _, frozen in { { effects = "freeze:105", serverNow = 100 }, { frozen = true } } do
			local inst = assert(QuadMotion.new(skel, "dragon", 5))
			local now = settle(inst, 0, 1, { speed = 0, yawRate = 0, combat = true })
			local run = { name = "bite", start = now, hit = 0.55 }
			now = settle(inst, now, 0.3, { speed = 0, yawRate = 0, combat = true, action = run })
			local first: { [string]: Vec }? = nil
			for i = 1, 30 do
				local input = table.clone(frozen) :: any
				input.now, input.dt, input.speed, input.yawRate, input.combat = now + i * DT, DT, 0, 0, true
				input.action = run
				local at = QuadRigFk.posed(skel, QuadMotion.step(inst, input))
				local ref = first or at
				first = ref
				for bone, p in at do
					T.expect(dist(p, ref[bone])).toBeNear(0, 1e-9)
				end
			end
			-- thawed, it moves on
			local thawed = QuadRigFk.posed(
				skel,
				QuadMotion.step(inst, { now = now + 0.6, dt = DT, speed = 0, yawRate = 0, combat = true, action = run })
			)
			T.expect(dist(thawed["tripo::Head_4"], assert(first)["tripo::Head_4"]) / L > 0.02).toBe(true)
		end
	end)

	T.it("leaves the other quadrupeds' styles without a stun", function()
		for _, id in { "canine", "bear", "boar", "mammoth" } do
			T.expect((assert(QuadStyles.get(id)) :: any).stun).toBeNil()
		end
		T.expect(STYLE.stun ~= nil).toBe(true)
	end)
end)

T.describe("Dragon: the old model and the new one", function()
	local function names(path: string): { [string]: boolean }
		local out: { [string]: boolean } = {}
		for name in QuadRigFk.load(path).bones do
			out[name] = true
		end
		return out
	end

	T.it(
		"keeps the regular wyvern's style on the old model and takes the dragon on the new one by its bones",
		function()
			local look = assert(MonsterLooks.get(KIND))
			local asset = assert(look.asset, KIND)
			T.expect(asset.motion).toBe("frostDragon")
			T.expect(BipedStyles.get("frostDragon") ~= nil).toBe(true)
			local old, new = names(KIND), names("youngFrostDragon_v2")
			local function hasIn(set: { [string]: boolean }): (string) -> boolean
				return function(bone: string): boolean
					return set[bone] == true
				end
			end
			T.expect(MonsterLooks.motionOf(asset, hasIn(old))).toBe("frostDragon")
			T.expect(MonsterLooks.motionOf(asset, hasIn(new))).toBe("dragon")
			-- the old model's skeleton is not the new map's
			T.expect((QuadRigFk.skeleton(KIND))).toBeNil()
		end
	)

	T.it("shows every state of either model in AnimLab", function()
		for _, state in QuadStyles.labStates("dragon") do
			local command = AnimLab.parseLine(`mob {KIND} {state}`)
			T.expect(command ~= nil).toBe(true)
		end
		for _, state in { "stun", "freeze", "pounce", "breath", "buffet", "tail", "deathL", "deathR", "roar", "rake" } do
			T.expect(table.find(QuadStyles.labStates("dragon"), state) ~= nil).toBe(true)
		end
		-- the old model's own states stay
		for _, state in BipedStyles.LAB_STATES do
			T.expect(AnimLab.parseLine(`mob {KIND} {state}`) ~= nil).toBe(true)
		end
	end)

	T.it("breathes frost from the mouth on the breath's action, released on W, the cold mist after it", function()
		local list = assert(MotionFx.get("dragon", "breath"))
		local kinds: { [string]: MotionFx.Fx } = {}
		for _, fx in list do
			kinds[fx.kind] = fx
			T.expect(fx.at).toBe("mouth")
		end
		local breath = assert(kinds.breath, "the stream")
		local t0, t1 = ActionFx.window(STYLE.actions.breath, 1.3, breath)
		T.expect(t0).toBeNear(1.3, 1e-9)
		T.expect(t1 - t0 >= 0.9).toBe(true)
		T.expect(kinds.charge ~= nil and kinds.smolder ~= nil).toBe(true)
		local bound = ActionFx.bound(KIND, STYLE.abilities, "breath", nil)
		T.expect(bound.element).toBe("ice")
		T.expect(bound.radius).toBe(17)
		local _, release = ActionFx.claims("dragon", STYLE.abilities, "frostBreath")
		T.expect(release).toBe(true)
	end)
end)
