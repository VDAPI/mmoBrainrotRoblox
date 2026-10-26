--!strict
-- Template animation, the heavy quadrupeds (docs/ANIM-WZORCE.md §3.9): the bear (brownBear, blackBear), the boar and the
-- ice mammoth on the Studio rig dumps of their models (tools/anim/rigs/<model>.json), through Logic/QuadMotion and the
-- forward kinematics of tests/QuadRigFk: the role maps, every blow of each kind's kit landing on the server's hit,
-- the planted feet at the server's paces, nothing through the ground, no NaN, no pops where actions blend.

local AnimLab = require("../src/shared/Logic/AnimLab")
local Combat = require("../src/shared/Data/Combat")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local QuadMotion = require("../src/shared/Logic/QuadMotion")
local QuadPose = require("../src/shared/Logic/QuadPose")
local QuadRigFk = require("./QuadRigFk")
local QuadStyles = require("../src/shared/Data/QuadStyles")
local T = require("./Test")

type Vec = { number }

local KINDS = { "brownBear", "blackBear", "boar", "iceMammoth" }
local MODELS = { "brownBear", "boar", "iceMammoth" }
local LEGS = { "FL", "FR", "HL", "HR" }
local DT = 1 / 60

-- The style and the skeleton (dump units) a kind animates with, and the model's scale in the game.
local function kindRig(kind: string): (QuadStyles.Style, QuadPose.Skeleton, number, string)
	local look = assert(MonsterLooks.get(kind), kind)
	local asset = assert(look.asset, kind)
	local styleId = assert(asset.motion, kind)
	local skel = assert((QuadRigFk.skeleton(asset.model)), asset.model)
	local monster = assert(Monsters.get(kind), kind)
	local scale = (asset.visual or 1) * monster.size
	return assert(QuadStyles.get(styleId), styleId), skel, scale, styleId
end

-- The windup an action plays with in the game (AnimLab's rule): its ability's, the throw's, the regular blow's.
local function windupOf(style: QuadStyles.Style, name: string): number
	local action = style.actions[name]
	if string.sub(name, 1, 5) == "death" then
		return action.strike
	end
	local best: number? = nil
	for id, act in style.abilities do
		local ability = MonsterAbilities.get(id)
		if act == name and ability then
			best = math.max(best or 0, ability.windup)
		end
	end
	if best then
		return best
	elseif name == style.throw then
		return Combat.basicWind.throw * Combat.basicWindVariant.elite2
	elseif name == style.aggro then
		return 0.45
	elseif name == style.spawn or table.find(style.fidgets, name) then
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

-- The lowest joint (model frame, leg lengths) other than the body bone, and whether any joint is NaN.
local function lowest(skel: QuadPose.Skeleton, at: { [string]: Vec }): (number, boolean)
	local low, nan = math.huge, false
	for name, p in at do
		if p[1] ~= p[1] or p[2] ~= p[2] or p[3] ~= p[3] then
			nan = true
		elseif name ~= skel.rig.body then
			low = math.min(low, p[2] / skel.L)
		end
	end
	return low, nan
end

T.describe("Heavy quadrupeds: role maps on the rig dumps", function()
	for _, model in MODELS do
		local skel, dump = QuadRigFk.skeleton(model)
		T.it(`{model}: every role is a bone of the dump`, function()
			T.expect(skel ~= nil).toBe(true)
		end)
		if not skel then
			continue
		end
		local L = skel.L
		T.it(`{model}: the rest pose is the dump's`, function()
			local at = QuadRigFk.positions(skel, {})
			for name, bone in dump.bones do
				for i = 1, 3 do
					T.expect(at[name][i]).toBeNear(bone.pos[i], 1e-6)
				end
			end
		end)
		T.it(`{model}: the feet rest on the ground and a positive fold lifts them`, function()
			local rest = QuadRigFk.feetAt(skel, {})
			for _, leg in LEGS do
				T.expect(rest[leg][2] / L).toBeBetween(-0.01, 0.12)
				local folded = QuadRigFk.feetAt(skel, { [leg .. "f"] = 0.6 })
				T.expect((folded[leg][2] - rest[leg][2]) / L > 0.05).toBe(true)
			end
		end)
		T.it(`{model}: a planted foot reaches its target under a moving body`, function()
			local rest = QuadRigFk.feetAt(skel, {})
			for _, body in
				{ { by = -0.05 }, { by = -0.06, bpitch = 0.05 }, { by = -0.06, bpitch = -0.05, broll = 0.04 } }
			do
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
	end
end)

T.describe("Heavy quadrupeds: the kit lands on the hit", function()
	for _, kind in KINDS do
		local style, skel, _, styleId = kindRig(kind)
		local monster = assert(Monsters.get(kind))
		-- every blow of the kind: the regular one at each variant's draw, its own ability, the Elite and Elite II kits, the
		-- throw at a fleeing target
		local blows: { { name: string, hit: number } } = {}
		local melee = Combat.basicWind.melee
		for _, variant in { "normal", "elite", "elite2" } do
			for count = 1, #style.basic do
				local name = QuadMotion.pick(style, nil, nil, count)
				table.insert(blows, { name = name, hit = melee * Combat.basicWindVariant[variant] })
			end
		end
		local abilities: { string } = { monster.ability :: string }
		for _, kit in { "elite", "elite2" } do
			for _, id in assert(MonsterAbilities.kit(kit)).abilities do
				table.insert(abilities, id)
			end
		end
		for _, id in abilities do
			T.it(`{kind}: {id} has its own action`, function()
				T.expect(style.abilities[id] ~= nil).toBe(true)
			end)
			local ability = assert(MonsterAbilities.get(id), id)
			table.insert(blows, { name = QuadMotion.pick(style, id, nil, 1), hit = ability.windup })
		end
		local throw = QuadMotion.pick(style, nil, "throw", 1)
		T.it(`{kind}: the throw has its own action`, function()
			T.expect(throw).toBe(style.throw)
		end)
		table.insert(blows, { name = throw, hit = Combat.basicWind.throw * Combat.basicWindVariant.elite2 })
		for _, blow in blows do
			T.it(`{kind}: {blow.name} strikes exactly at W {blow.hit}`, function()
				local action = style.actions[blow.name]
				T.expect(action ~= nil).toBe(true)
				-- the last strike key ends the strike, so its pose is the pose at the hit
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
				local at = assert(QuadMotion.controlsAt(style, blow.name, blow.hit, blow.hit))
				for name, v in key.pose do
					T.expect(at[name]).toBeNear(v, 1e-9)
				end
			end)
		end
		T.it(`{kind}: the style is planted and the skeleton has a trunk only on the mammoth`, function()
			local inst = assert(QuadMotion.new(skel, styleId, 1))
			T.expect(inst.planted).toBe(true)
			T.expect(skel.rig.trunk ~= nil).toBe(kind == "iceMammoth")
		end)
	end
end)

-- The blows whose feet strike the ground on the hit, and whether they come down from high.
local IMPACTS: { [string]: { { name: string, hit: number, feet: { string }, high: boolean } } } = {
	bear = {
		{ name = "swipe", hit = 0.55, feet = { "FR" }, high = true },
		{ name = "swipeL", hit = 0.55, feet = { "FL" }, high = true },
		{ name = "slam", hit = 1.4, feet = { "FL", "FR" }, high = true },
		{ name = "crush", hit = 2.2, feet = { "FL", "FR" }, high = true },
		{ name = "maul", hit = 1.8, feet = { "FL", "FR" }, high = true },
		{ name = "bodyslam", hit = 1.4, feet = { "FL", "FR" }, high = true },
	},
	boar = {
		{ name = "gore", hit = 0.55, feet = { "FL", "FR" }, high = true },
		{ name = "rake", hit = 1.8, feet = { "FL", "FR" }, high = false },
		{ name = "stomp", hit = 2.2, feet = { "FL", "FR" }, high = true },
		{ name = "leap", hit = 1.4, feet = { "FL", "FR" }, high = true },
	},
	mammoth = {
		{ name = "stomp", hit = 1.4, feet = { "FL", "FR" }, high = true },
		{ name = "crush", hit = 2.2, feet = { "FL", "FR" }, high = true },
		{ name = "lunge", hit = 1.4, feet = { "FL", "FR" }, high = true },
	},
}
local MODEL_OF = { bear = "brownBear", boar = "boar", mammoth = "iceMammoth" }

T.describe("Heavy quadrupeds: what the model shows", function()
	for styleId, impacts in IMPACTS do
		local skel = assert((QuadRigFk.skeleton(MODEL_OF[styleId])), styleId)
		local L = skel.L
		local rest = QuadRigFk.feetAt(skel, {})
		for _, blow in impacts do
			T.it(`{styleId} {blow.name}: the feet strike the ground at W`, function()
				local inst = assert(QuadMotion.new(skel, styleId, 4))
				local look = { 0, 0, -5 * L }
				local now = settle(inst, 0, 1, { speed = 0, yawRate = 0, combat = true, look = look })
				-- frames that land on the hit exactly
				local n = math.ceil(blow.hit / DT)
				local dt = blow.hit / n
				local run = { name = blow.name, start = now, hit = blow.hit, reach = { 0, 0, -5 * L } }
				local high = 0
				for i = 1, n do
					local posed = QuadMotion.step(inst, {
						now = now + i * dt,
						dt = dt,
						speed = 0,
						yawRate = 0,
						combat = true,
						action = run,
						look = look,
					})
					local at, turns = QuadRigFk.posed(skel, posed)
					local feet = QuadRigFk.feetOf(skel, at, turns)
					for _, leg in blow.feet do
						local y = (feet[leg][2] - rest[leg][2]) / L
						if i < n then
							high = math.max(high, y)
						else
							T.expect(math.abs(y) < 0.02).toBe(true)
						end
					end
				end
				if blow.high then
					T.expect(high > 0.15).toBe(true)
				end
			end)
		end
	end

	for styleId, model in MODEL_OF do
		local skel = assert((QuadRigFk.skeleton(model)), model)
		local style = assert(QuadStyles.get(styleId))
		local names: { string } = {}
		for name in style.actions do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			T.it(`{styleId} {name}: no NaN, nothing through the ground, no pop where it starts or ends`, function()
				local action = style.actions[name]
				local hit = windupOf(style, name)
				local inst = assert(QuadMotion.new(skel, styleId, 6))
				local look = { 0, 0, -5 * skel.L }
				-- from a walk into the action, standing for it, then the walk again
				local now = settle(inst, 0, 1.5, { speed = 1.2 * skel.L, yawRate = 0, combat = true, look = look })
				local start = now + DT
				local run = { name = name, start = start, hit = hit, reach = { 0, 0, -4 * skel.L } }
				local length = MotionTimeline.length(action, hit)
				local prev: { [string]: Vec }? = nil
				local low, nan, pop = math.huge, false, 0
				for _ = 1, math.ceil((length + 0.8) / DT) do
					now += DT
					local t = now - start
					local speed = if t < 0.15 or t > length + 0.3 then 1.2 * skel.L else 0
					local posed = QuadMotion.step(
						inst,
						{ now = now, dt = DT, speed = speed, yawRate = 0, combat = true, action = run, look = look }
					)
					local at = QuadRigFk.posed(skel, posed)
					local l, bad = lowest(skel, at)
					low, nan = math.min(low, l), nan or bad
					-- the blends: the first 0.2 s of the action and its fade (a flight's own travel fades out with it)
					local edge = t < 0.2 or (t > length - 0.2 and t < length + 0.1 and not action.travel)
					if prev and edge and not action.hold then
						for bone, p in at do
							local q = prev[bone]
							local d = math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2) / skel.L
							pop = math.max(pop, d - speed * DT / skel.L)
						end
					end
					prev = at
				end
				T.expect(nan).toBe(false)
				T.expect(low > -0.02).toBe(true)
				T.expect(pop < 0.12).toBe(true)
			end)
		end
	end
end)

T.describe("Heavy quadrupeds: gaits at the server's paces", function()
	for _, kind in KINDS do
		local style, skel, scale, styleId = kindRig(kind)
		local monster = assert(Monsters.get(kind))
		local L = skel.L
		local rest = QuadRigFk.feetAt(skel, {})
		-- walk (wandering) 0.4x, trot (going home) 0.7x, run (the chase) 1x moveSpeed, in dump units
		for _, pace in { { "walk", 0.4 }, { "home", 0.7 }, { "chase", 1 } } do
			local speed = monster.moveSpeed * pace[2] / scale
			T.it(`{kind} {pace[1]}: one gait, feet planted in stance, nothing through the ground`, function()
				local inst = assert(QuadMotion.new(skel, styleId, 9))
				local now = settle(inst, 0, 2, { speed = speed, yawRate = 0, combat = pace[1] == "chase" })
				local slide, hover, low, nan = 0, 0, math.huge, false
				local runs: { [string]: { number } } = {}
				local gait, weight = "walk", 0
				for name, w in inst.weights do
					if w > weight then
						gait, weight = name, w
					end
				end
				T.expect(weight > 0.97).toBe(true)
				local g = style.gaits[gait]
				for _ = 1, 240 do
					now += DT
					local posed = QuadMotion.step(
						inst,
						{ now = now, dt = DT, speed = speed, yawRate = 0, combat = pace[1] == "chase" }
					)
					local at, turns = QuadRigFk.posed(skel, posed)
					local l, bad = lowest(skel, at)
					low, nan = math.min(low, l), nan or bad
					local feet = QuadRigFk.feetOf(skel, at, turns)
					for _, leg in LEGS do
						local duty = if string.sub(leg, 1, 1) == "F" then (g.dutyFront or g.duty) else g.duty
						local p = (inst.phase - g.foot[leg]) % 1
						-- the foot's place on the ground (the model goes toward -Z at `speed`)
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
			end)
		end
	end

	T.it("the mammoth never gallops: an amble at every speed", function()
		local style = assert(QuadStyles.get("mammoth"))
		T.expect(style.gaits.gallop).toBe(style.gaits.trot)
		T.expect(style.thresholds.gallop > 20).toBe(true)
	end)

	T.it("the boar's charge: the scrape on one fore hoof, then the gallop at the dash's speed", function()
		local style, skel, scale = kindRig("boar")
		local L = skel.L
		local rest = QuadRigFk.feetAt(skel, {})
		local inst = assert(QuadMotion.new(skel, "boar", 5))
		local now = settle(inst, 0, 1, { speed = 0, yawRate = 0, combat = true })
		local charge = assert(MonsterAbilities.get("charge"))
		local dash = assert(charge.dash, "charge dash")
		local W = charge.windup
		-- the server runs the boar along the line the last `dash.seconds`: about 20 studs
		local dashSpeed = 20 / dash.seconds / scale
		local run = { name = "charge", start = now, hit = W }
		local t0 = now
		local scrape, planted, galloping, low, cycles = 0, 0, 0, math.huge, 0
		local phase = inst.phase
		for i = 1, math.ceil((MotionTimeline.length(style.actions.charge, W) + 0.2) / DT) do
			now = t0 + i * DT
			local t = now - t0
			local speed = if t > W - dash.seconds and t <= W then dashSpeed else 0
			local posed =
				QuadMotion.step(inst, { now = now, dt = DT, speed = speed, yawRate = 0, combat = true, action = run })
			local at, turns = QuadRigFk.posed(skel, posed)
			low = math.min(low, (lowest(skel, at)))
			local feet = QuadRigFk.feetOf(skel, at, turns)
			if t > 0.2 and t < 0.55 then
				scrape = math.max(scrape, (feet.FR[2] - rest.FR[2]) / L)
				planted = math.max(planted, math.abs(feet.FL[2] - rest.FL[2]) / L)
			end
			if t > W - dash.seconds + 0.1 and t <= W then
				galloping = math.max(galloping, inst.weights.gallop or 0)
				cycles += (inst.phase - phase) % 1
			end
			phase = inst.phase
		end
		T.expect(scrape > 0.05).toBe(true)
		T.expect(planted < 0.01).toBe(true)
		T.expect(galloping > 0.95).toBe(true)
		-- the feet keep up with the dash: about one stride per k leg lengths travelled
		local k = style.gaits.gallop.k
		T.expect(cycles).toBeNear(dashSpeed * (dash.seconds - 0.1) / (k * L), 0.35)
		T.expect(low > -0.02).toBe(true)
	end)

	T.it("the mammoth's trunk swings behind the head while it walks", function()
		local _, skel = kindRig("iceMammoth")
		local trunk = assert(skel.rig.trunk, "trunk")
		local tip, head = trunk[#trunk], skel.rig.head
		local inst = assert(QuadMotion.new(skel, "mammoth", 2))
		local now = settle(inst, 0, 2, { speed = 0.85 * skel.L, yawRate = 0, combat = false })
		local lo, hi = math.huge, -math.huge
		for _ = 1, 180 do
			now += DT
			local at = QuadRigFk.posed(
				skel,
				QuadMotion.step(inst, {
					now = now,
					dt = DT,
					speed = 0.85 * skel.L,
					yawRate = 0,
					combat = false,
				})
			)
			local x = (at[tip][1] - at[head][1]) / skel.L
			lo, hi = math.min(lo, x), math.max(hi, x)
		end
		T.expect(hi - lo > 0.03).toBe(true)
	end)

	T.it("two bears of one kind do not move in step", function()
		local _, skel = kindRig("brownBear")
		local a = assert(QuadMotion.new(skel, "bear", 11))
		local b = assert(QuadMotion.new(skel, "bear", 12))
		T.expect(a.phase ~= b.phase or a.rate ~= b.rate).toBe(true)
	end)

	T.it("the wolf's style plants no feet (its motion stays the approved one)", function()
		local _, skel = kindRig("brownBear")
		local wolf = assert(QuadMotion.new(skel, "canine", 1))
		T.expect(wolf.planted).toBe(false)
		T.expect(wolf.style.ground).toBeNil()
		T.expect(wolf.style.trunk).toBeNil()
	end)
end)

T.describe("Heavy quadrupeds: AnimLab", function()
	for _, kind in KINDS do
		local look = assert(MonsterLooks.get(kind))
		local styleId = assert(assert(look.asset, kind).motion, kind)
		T.it(`/animlab mob {kind} <state> takes every state of the {styleId} style`, function()
			for _, state in QuadStyles.labStates(styleId) do
				local command, err = AnimLab.parseLine(`mob {kind} {state}`)
				T.expect(err).toBeNil()
				T.expect(command ~= nil).toBe(true)
			end
		end)
	end
	T.it("the assets name the styles (blackBear through the brown bear's model)", function()
		T.expect(MonsterAssets.brownBear.motion).toBe("bear")
		T.expect(MonsterAssets.boar.motion).toBe("boar")
		T.expect(MonsterAssets.iceMammoth.motion).toBe("mammoth")
		local black = assert(assert(MonsterLooks.get("blackBear"), "blackBear").asset, "blackBear")
		T.expect(black.motion).toBe("bear")
		T.expect(black.model).toBe("brownBear")
	end)
end)
