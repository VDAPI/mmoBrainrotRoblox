--!strict
-- Template animation (2026-10-26): the four bosses on the biped template (Data/BossStyles) and the young frost dragon
-- on the regular wyvern's style. On the bosses' rig dumps (tools/anim/rigs) at their clones' scales: every attack,
-- pattern and extra cast picks an action of its boss; every blow's strike ends on the server's hit and a held pattern
-- plays a channel held over the hold; the facing / centring correction puts the export's own hierarchy where the pose
-- says; the leg IK lands the ankle on its target; nothing under the ground and no NaN in any action at its server
-- timing, the deaths lying low; Morvane floats; the leap flies its arc to its target, the whirlwind spins twice, the
-- spiral turns with its stream; the enraged and shielded stances; no pops through a long fight; the AnimLab commands.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local BasicBlow = require("../src/shared/Logic/BasicBlow")
local BipedMotion = require("../src/shared/Logic/BipedMotion")
local BipedPose = require("../src/shared/Logic/BipedPose")
local BipedRigs = require("../src/shared/Data/BipedRigs")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local BossMotions = require("../src/shared/Data/BossMotions")
local BossTuning = require("../src/shared/Data/BossTuning")
local Bosses = require("../src/shared/Data/Bosses")
local HazardGesture = require("../src/shared/Logic/HazardGesture")
local HazardPatterns = require("../src/shared/Data/HazardPatterns")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local SpiritMotion = require("../src/shared/Logic/SpiritMotion")
local Telegraph = require("../src/shared/Logic/Telegraph")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local BOSSES = { "grimrok", "morvane", "azgor", "hrimvald" }
-- the clones' studs per dump unit in the game (MonsterLooks size over the dump's height)
local SCALES: { [string]: number } =
	{ grimrok = 3.38, morvane = 3.12, azgor = 3.64, hrimvald = 7.8, youngFrostDragon = 1.3 }
-- client/Controllers/AnimationController: a boss's windup as the server sends it, clamped to these
local BOSS_WINDUP_MAX = 8
local IDENTITY: Mat = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

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

-- A dump's bones in the look's root space at the clone's scale, as client/Anim/BipedRig reads them (the first bone of
-- each key). The boss dumps carry no hierarchy: the keyed bones' parents are the template's (Mixamo's).
local function load(model: string): Dump
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local scale = SCALES[model]
	local rest: { [string]: BipedPose.Bone } = {}
	local names: { [string]: string } = {}
	for _, b in dump.bones do
		local back = unitV({ -b.look[1], -b.look[2], -b.look[3] })
		local up0 = b.up
		local k = up0[1] * back[1] + up0[2] * back[2] + up0[3] * back[3]
		local up = unitV({ up0[1] - back[1] * k, up0[2] - back[2] * k, up0[3] - back[3] * k })
		local right = cross(up, back)
		rest[b.name] = {
			rest = { right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3] },
			pos = { b.pos[1] * scale, b.pos[2] * scale, b.pos[3] * scale },
		}
		local key = BipedRigs.keyOf(b.name)
		if not names[key] then
			names[key] = b.name
		end
	end
	local parent: { [string]: string? } = {}
	for key, name in names do
		local parentKey = BipedPose.PARENT[key]
		parent[name] = if parentKey then names[parentKey] else nil
	end
	return { rest = rest, parent = parent, names = names }
end

type Rig = { dump: Dump, skel: BipedPose.Skeleton, keyed: { [string]: string } }

local rigs: { [string]: Rig } = {}
local function rigOf(model: string): Rig
	local cached = rigs[model]
	if cached then
		return cached
	end
	local dump = load(model)
	local bones, keyed, options = BipedPose.collect(dump.names, dump.rest, BipedRigs.get(model))
	local skel = BipedPose.skeleton(bones, options)
	assert(skel, model)
	local rig = { dump = dump, skel = skel, keyed = keyed }
	rigs[model] = rig
	return rig
end

-- Where the keyed bones of the export's own hierarchy end up with the posed Transforms as client/Anim/BipedRig applies
-- them (the Hips' through BipedPose.hipsFixed; Bone: parent * rest-local * Transform).
local function forward(rig: Rig, posed: BipedPose.Posed): { [string]: Vec }
	local bones = rig.dump.rest
	local entries: { [string]: { rot: Mat, offset: Vec? } } = {}
	for key, name in rig.keyed do
		local entry = posed[key]
		if entry then
			if key == "Hips" then
				local rot, offset = BipedPose.hipsFixed(rig.skel, entry)
				entries[name] = { rot = rot, offset = offset }
			else
				entries[name] = entry
			end
		end
	end
	local out: { [string]: { rot: Mat, pos: Vec } } = {}
	local function visit(name: string): { rot: Mat, pos: Vec }
		local done = out[name]
		if done then
			return done
		end
		local b = bones[name]
		local entry = entries[name]
		local q = if entry then entry.rot else IDENTITY
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
	local at: { [string]: Vec } = {}
	for key, name in rig.keyed do
		at[key] = visit(name).pos
	end
	return at
end

-- The joints (root space, the corrected frame the pose is solved in) of a pose: its world turns back from the
-- Transforms (no pivot on these rigs: the Hips offset is the shift).
local function joints(skel: BipedPose.Skeleton, posed: BipedPose.Posed): { [string]: Vec }
	local world: BipedPose.World = {}
	local shift: Vec = { 0, 0, 0 }
	for _, key in BipedPose.KEYS do
		local entry = posed[key]
		local bone = skel.bones[key]
		if entry and bone then
			local parentKey = BipedPose.PARENT[key]
			local pw = if parentKey then world[parentKey] or IDENTITY else IDENTITY
			local r = bone.rest
			world[key] = mul(pw, mul(mul(r, entry.rot), transpose(r)))
			if key == "Hips" and entry.offset then
				shift = apply(r, entry.offset)
			end
		end
	end
	return BipedPose.positions(skel, world, shift)
end

-- A pseudo-random control set over every control the pose reads.
local function randomControls(seed: number, size: number): BipedPose.Controls
	local state = seed * 7919 + 17
	local out: BipedPose.Controls = {}
	for _, key in BipedPose.CONTROLS do
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648 * 2 - 1
		local first = string.sub(key, 1, 1)
		out[key] = if first == "f" and #key == 3
			then u * 0.2
			elseif key == "px" or key == "pz" then u * 0.1
			else u * size
	end
	out.py = (out.py or 0) * 0.3
	return out
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

type Motion = {
	new: (BipedPose.Skeleton, string, number, { number }?) -> any,
	step: (any, BipedMotion.Input) -> BipedPose.Posed,
}
local function motionOf(styleId: string): Motion
	return (if SpiritMotion.handles(styleId) then SpiritMotion else BipedMotion) :: any
end

local function styleOf(id: string): BipedStyles.Style
	return BipedStyles.get(id) :: BipedStyles.Style
end

-- The hips' heading (rad, + = left) from the line across the hips (left to right along +X at rest).
local function heading(at: { [string]: Vec }): number
	local across = sub(at.RightUpLeg, at.LeftUpLeg)
	return math.atan2(-across[3], across[1])
end

-- The server's timing of every action a boss's attacks and patterns play: { action, hit, hold, what }.
type Cast = { name: string, hit: number, hold: number, what: string }
local function castsOf(id: string): { Cast }
	local style = styleOf(id)
	local def = Bosses.byId[id]
	local out: { Cast } = {}
	local windupOf: { [string]: number } = {}
	for _, attack in def.attacks do
		local hit = math.clamp(attack.windup, Telegraph.WINDUP_MIN, BOSS_WINDUP_MAX)
		table.insert(out, { name = style.abilities[attack.id], hit = hit, hold = 0, what = attack.id })
		windupOf[attack.id] = attack.windup
	end
	local tuning = (BossTuning.patterns :: any)[id] or {}
	local patternWindup: { [string]: number } = {}
	for attackId, patternId in tuning.replace or {} do
		patternWindup[patternId] = windupOf[attackId]
	end
	local extra = (BossTuning.extra :: any)[id] or {}
	for _, kind in { "shield", "far" } do
		local e = extra[kind]
		if e and e.pattern then
			patternWindup[e.pattern] = patternWindup[e.pattern] or e.windup
		end
	end
	local motion = BossMotions.get(id) :: BossMotions.BossMotion
	for patternId, gesture in motion.patterns do
		if not gesture.rides then
			local timing = HazardGesture.timing(HazardPatterns.get(patternId) :: any, patternWindup[patternId])
			table.insert(out, {
				name = style.abilities[patternId],
				hit = math.clamp(timing.windup, Telegraph.WINDUP_MIN, BOSS_WINDUP_MAX),
				hold = timing.hold,
				what = patternId,
			})
		end
	end
	local wind = BasicBlow.wind(def.attack, "boss")
	for _, name in style.basic do
		table.insert(out, { name = name, hit = wind, hold = 0, what = "basic" })
	end
	local boss = style.boss :: BipedStyles.BossLayer
	for _, name in { boss.roar, boss.rageRoar } do
		table.insert(out, { name = name, hit = boss.roarHit, hold = 0, what = "roar" })
	end
	for _, name in { boss.stagger, "spawn", "death" } do
		local action = style.actions[name]
		table.insert(out, { name = name, hit = if action then action.strike else 0.2, hold = 0, what = name })
	end
	return out
end

-- The lowest joint (leg lengths) of `id`'s action played at its timing, sampled every `dt`; also the hips' height at
-- the start and the end and the highest the hips reach.
local function play(id: string, cast: Cast, dt: number): (number, string, number, number, number)
	local rig = rigOf(id)
	local style = styleOf(id)
	local action = style.actions[cast.name]
	local motion = motionOf(id)
	local inst = motion.new(rig.skel, id, 3.1, nil)
	local L = rig.skel.legLength
	local run = {
		name = cast.name,
		start = 0.5,
		hit = cast.hit,
		hold = if cast.hold > 0 then cast.hold else nil,
		turn = if action.channel then { 0.8, -0.8 } else nil,
		arc = if action.leap then { 6, 0.35 } else nil,
		reach = if action.leap then { 0, 0, -10 } else nil,
	}
	local finish = 0.5 + BipedMotion.length(action, cast.hit, run.hold) + 0.3
	local low, lowKey = math.huge, ""
	local startHips, endHips, topHips = 0, 0, -math.huge
	local t = 0
	while t < finish do
		local posed = motion.step(inst, input({ now = t, dt = dt, combat = true, action = run, snap = t == 0 }))
		checkFinite(posed, `{id} {cast.name} at {t}`)
		local at = joints(rig.skel, posed)
		if t > 0.55 then
			for key, p in at do
				if p[2] < low then
					low, lowKey = p[2], key
				end
			end
		end
		if t <= 0.5 then
			startHips = at.Hips[2] / L
		end
		endHips = at.Hips[2] / L
		topHips = math.max(topHips, at.Hips[2] / L)
		t += dt
	end
	return low / L, lowKey, startHips, endHips, topHips
end

-- The continuity of a long run (as tests/bipedrigs.spec): the largest change of a rotation entry per frame in windows
-- of 0.1 s at `fine` against `fine` / 2; a continuous motion halves with the step, a pop keeps its size.
local function continuity(
	written: { [string]: string },
	fine: number,
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
	local coarse, half = windows(fine), windows(fine / 2)
	local largest = 0
	for _, d in coarse do
		largest = math.max(largest, d)
	end
	local excess, at = 0, 0
	for w, d in half do
		local ref = math.max(coarse[w - 1] or 0, coarse[w] or 0, coarse[w + 1] or 0)
		local over = d - (0.65 * ref + 0.004)
		if over > excess then
			excess, at = over, w / 10
		end
	end
	return largest, excess, at
end

T.describe("BossStyles: the bosses' kits", function()
	T.it(
		"MonsterAssets: each boss on its own style, the young frost dragon on frostDragon; Morvane a spirit",
		function()
			for _, id in BOSSES do
				T.expect((MonsterAssets :: any)[id].motion).toBe(id)
				local style = styleOf(id)
				local boss = style.boss :: BipedStyles.BossLayer
				T.expect(boss ~= nil).toBe(true)
				for _, name in { boss.roar, boss.rageRoar, boss.stagger, "spawn" } do
					T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
				end
				for _, name in style.death do
					T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
				end
				T.expect(SpiritMotion.handles(id)).toBe(id == "morvane")
			end
			T.expect(MonsterAssets.youngFrostDragon.motion).toBe("frostDragon")
		end
	)

	T.it(
		"every attack, pattern (a riding one: its attack) and extra cast of a boss plays one of its actions",
		function()
			for _, id in BOSSES do
				local style = styleOf(id)
				local def = Bosses.byId[id]
				local function check(what: string)
					local name = style.abilities[what]
					T.expect({ id, what, name ~= nil and style.actions[name] ~= nil }).toEqual({ id, what, true })
				end
				for _, attack in def.attacks do
					check(attack.id)
					-- a leaping attack flies the leap's arc
					if attack.leap then
						T.expect({ id, attack.id, style.actions[style.abilities[attack.id]].leap }).toEqual({
							id,
							attack.id,
							true,
						})
					end
				end
				local motion = BossMotions.get(id) :: BossMotions.BossMotion
				for patternId, gesture in motion.patterns do
					check(gesture.rides or patternId)
				end
				local extra = (BossTuning.extra :: any)[id] or {}
				for _, kind in { "shield", "far" } do
					if extra[kind] and extra[kind].pattern then
						check(extra[kind].pattern)
					end
				end
				for _, name in style.basic do
					T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
				end
				if style.throw then
					T.expect(style.actions[style.throw] ~= nil).toBe(true)
				end
			end
		end
	)

	T.it("every blow's strike ends on the server's hit; a held pattern is a channel held over the hold", function()
		for _, id in BOSSES do
			local style = styleOf(id)
			for _, cast in castsOf(id) do
				local action = style.actions[cast.name]
				local tag = `{id}.{cast.what}.{cast.name}`
				local hold = if cast.hold > 0 then cast.hold else nil
				-- a pattern releasing over time holds its blow (a channel)
				if cast.hold > 0.05 then
					T.expect({ tag, action.channel }).toEqual({ tag, true })
				end
				local peak, at, finish = BipedMotion.times(action, cast.hit, hold)
				T.expect(at).toBe(cast.hit)
				T.expect({ tag, peak <= cast.hit + 1e-9 }).toEqual({ tag, true })
				local held = if action.channel then cast.hold else 0
				T.expect(finish).toBeNear(cast.hit + held + action.follow + action.recover, 1e-9)
				-- the windup reads: the strike is shorter than the server's windup
				if cast.what ~= "death" and cast.what ~= "spawn" and cast.name ~= (style.boss :: any).stagger then
					T.expect({ tag, action.strike < cast.hit }).toEqual({ tag, true })
				end
				-- at the hit the controls are the strike's last key (the head and the free arm trail by the lag)
				local last
				for _, key in action.keys do
					if key.seg == "S" then
						last = key
					end
				end
				if last and last.u == 1 then
					local c = BipedMotion.controlsAt(style, cast.name, cast.hit, cast.hit, hold) :: BipedPose.Controls
					local lag = action.lag or {}
					for k, v in last.pose do
						local head = string.sub(k, 1, 1) == "h"
						local free = string.find(k, "^[acew]L") ~= nil
						if not (head and (lag.head or 0) > 0) and not (free and (lag.free or 0) > 0) then
							T.expect({ tag, k, math.abs(c[k] - v) < 1e-9 }).toEqual({ tag, k, true })
						end
					end
				end
			end
		end
	end)

	T.it("the long death plays on the look's clone: it stays whole first and breaks up as he lies down", function()
		for _, id in BOSSES do
			local style = styleOf(id)
			local death = (BossMotions.get(id) :: BossMotions.BossMotion).death
			local action = style.actions[style.death[1]]
			local length = BipedMotion.length(action, action.strike)
			local hold = death.hold or 0
			T.expect({ id, hold > 0 and hold < length }).toEqual({ id, true })
			T.expect({ id, length <= hold + (death.seconds or 0) }).toEqual({ id, true })
		end
	end)
end)

T.describe("BossStyles: on the boss rigs", function()
	T.it(
		"Grimrok and Azgor stand corrected to face -Z over the root; the export's hierarchy follows the pose",
		function()
			for _, id in { "grimrok", "azgor" } do
				local skel = rigOf(id).skel
				T.expect(skel.fix ~= nil).toBe(true)
				local across = sub(skel.bones.RightUpLeg.pos, skel.bones.LeftUpLeg.pos)
				T.expect(math.abs(across[3]) / len(across)).toBeBetween(0, 0.12)
				T.expect(across[1] > 0).toBe(true)
				local hips = skel.bones.Hips.pos
				T.expect(math.abs(hips[1]) + math.abs(hips[3])).toBeBetween(0, 1e-9)
			end
			T.expect(rigOf("morvane").skel.fix).toBeNil()
			T.expect(rigOf("hrimvald").skel.fix).toBeNil()
			for _, id in BOSSES do
				local rig = rigOf(id)
				for seed = 1, 8 do
					local world, shift = BipedPose.world(rig.skel, randomControls(seed, 0.6))
					local at = BipedPose.positions(rig.skel, world, shift)
					local fk = forward(rig, BipedPose.transforms(rig.skel, world, shift))
					for key, p in fk do
						if at[key] then
							T.expect({ id, key, len(sub(p, at[key])) < 1e-6 * SCALES[id] }).toEqual({ id, key, true })
						end
					end
				end
			end
		end
	)

	T.it("the leg IK lands the ankle on its target on the bowed boss legs", function()
		for _, id in BOSSES do
			local rig = rigOf(id)
			local L = rig.skel.legLength
			for seed = 1, 10 do
				local world, shift = BipedPose.world(rig.skel, randomControls(seed, 0.3))
				local at = BipedPose.positions(rig.skel, world, shift)
				local targets: { [string]: Vec? } = {}
				local state = seed
				for _, s in { "R", "L" } do
					local side = if s == "R" then "Right" else "Left"
					local ankle = at[side .. "Foot"]
					state = (state * 1103515245 + 12345) % 2147483648
					local u = state / 2147483648 * 2 - 1
					-- up toward the hip (always within reach) and a little aside
					targets[s] = { ankle[1] + 0.08 * u * L, ankle[2] + 0.12 * L, ankle[3] - 0.06 * u * L }
				end
				BipedPose.fixLegs(rig.skel, world, shift, targets)
				local after = BipedPose.positions(rig.skel, world, shift)
				for _, s in { "R", "L" } do
					local side = if s == "R" then "Right" else "Left"
					local miss = len(sub(after[side .. "Foot"], targets[s] :: Vec)) / L
					T.expect({ id, seed, s, miss < 1e-4 }).toEqual({ id, seed, s, true })
				end
			end
		end
	end)

	T.it("every action at its server timing: no NaN, nothing under the ground, the deaths lying low", function()
		for _, id in BOSSES do
			local dt = 1 / 30
			for _, cast in castsOf(id) do
				local low, lowKey, startHips, endHips, topHips = play(id, cast, dt)
				local tag = `{id}.{cast.name}`
				-- (the mocap's own idle dips the toes 0.07)
				if low < -0.08 then
					error(`{tag}: {lowKey} {low} leg lengths under the ground`)
				end
				if cast.name == "death" then
					if id == "morvane" then
						-- she rises before she sags (her clone fades on her)
						T.expect({ tag, topHips > startHips + 0.03, endHips < startHips }).toEqual({ tag, true, true })
					else
						T.expect({ tag, endHips < 0.3 }).toEqual({ tag, true })
					end
				end
			end
		end
	end)

	T.it("Morvane floats: never on her feet, bobbing, through her idle and her drift", function()
		local rig = rigOf("morvane")
		local L = rig.skel.legLength
		local rest = rig.skel.bones.Hips.pos[2]
		local inst = SpiritMotion.new(rig.skel, "morvane", 4) :: SpiritMotion.Instance
		local lowest, hipsLow, hipsHigh = math.huge, math.huge, -math.huge
		local t = 0
		while t < 9 do
			local speed = if t > 5 and t < 7.5 then 10 else 0
			local posed = SpiritMotion.step(inst, input({ now = t, speed = speed, combat = t > 3, snap = t == 0 }))
			local at = joints(rig.skel, posed)
			for _, p in at do
				lowest = math.min(lowest, p[2])
			end
			if t > 0.5 and t < 5 then
				hipsLow, hipsHigh = math.min(hipsLow, at.Hips[2]), math.max(hipsHigh, at.Hips[2])
			end
			t += 1 / 30
		end
		T.expect(lowest / L).toBeBetween(0, 1)
		T.expect((hipsLow - rest) / L).toBeBetween(0.02, 0.3)
		T.expect((hipsHigh - hipsLow) / L).toBeBetween(0.01, 0.2)
	end)

	T.it("Grimrok's leap flies the boss's arc and lands on the target at the hit; the whirlwind spins twice", function()
		local rig = rigOf("grimrok")
		local style = styleOf("grimrok")
		local name = style.abilities.leap
		local hit = 1.8
		local inst = BipedMotion.new(rig.skel, "grimrok", 2) :: BipedMotion.Instance
		local run = { name = name, start = 0, hit = hit, arc = { 6, 0.35 }, reach = { 0, 0, -12 } }
		local rest = rig.skel.bones.Hips.pos
		local top, atHit = -math.huge, rest
		local t = 0
		while t <= hit + 0.2 do
			local posed = BipedMotion.step(inst, input({ now = t, combat = true, action = run, snap = t == 0 }))
			local hips = joints(rig.skel, posed).Hips
			if t > hit - 0.35 and t < hit then
				top = math.max(top, hips[2] - rest[2])
			end
			if math.abs(t - hit) < 1 / 120 then
				atHit = hips
			end
			t += 1 / 60
		end
		-- the arc's 6 studs over the action's own crouch and spring
		T.expect(top).toBeBetween(4, 9)
		T.expect(atHit[3] - rest[3]).toBeBetween(-14, -10)
		-- the whirlwind: two whole turns, back to the front
		local spin = BipedMotion.new(rig.skel, "grimrok", 2) :: BipedMotion.Instance
		local whirl = { name = style.abilities.whirlwind, start = 0, hit = 2.0 }
		local finish = BipedMotion.length(style.actions[whirl.name], 2.0)
		local turned, last = 0, 0
		t = 0
		while t <= finish do
			local posed = BipedMotion.step(spin, input({ now = t, combat = true, action = whirl, snap = t == 0 }))
			local h = heading(joints(rig.skel, posed))
			if t > 0 then
				turned += (h - last + math.pi) % (2 * math.pi) - math.pi
			end
			last = h
			t += 1 / 60
		end
		T.expect(math.abs(turned) / (2 * math.pi)).toBeBetween(1.9, 2.1)
	end)

	T.it("Morvane's spiral turns her with the stream over its hold", function()
		local rig = rigOf("morvane")
		local style = styleOf("morvane")
		local hit, hold = 1.2, 1.98
		local inst = SpiritMotion.new(rig.skel, "morvane", 2) :: SpiritMotion.Instance
		local run = { name = style.abilities.mv_spiral, start = 0, hit = hit, hold = hold, turn = { 0, -2.2 } }
		local atHit, atEnd = 0, 0
		local t = 0
		while t <= hit + hold + 0.02 do
			local posed = SpiritMotion.step(inst, input({ now = t, combat = true, action = run, snap = t == 0 }))
			local h = heading(joints(rig.skel, posed))
			if math.abs(t - hit) < 1 / 120 then
				atHit = h
			end
			atEnd = h
			t += 1 / 60
		end
		T.expect(math.abs(atHit)).toBeBetween(0, 0.35)
		T.expect(atEnd).toBeBetween(-2.2 - 0.35, -2.2 + 0.35)
	end)

	T.it("the enraged and the shielded stances change the guard (and Hrimvald has no shield)", function()
		for _, id in BOSSES do
			local rig = rigOf(id)
			local motion = motionOf(id)
			local function pose(over: { [string]: any }): BipedPose.Posed
				local inst = motion.new(rig.skel, id, 5, nil)
				local posed
				local t = 0
				while t < 2.5 do
					local i: { [string]: any } = { now = t, combat = true, snap = t == 0 }
					for k, v in over do
						i[k] = v
					end
					posed = motion.step(inst, input(i))
					t += 1 / 30
				end
				return posed
			end
			local function differs(a: BipedPose.Posed, b: BipedPose.Posed): number
				local most = 0
				for key, entry in a do
					local other = b[key]
					if other then
						for i = 1, 9 do
							most = math.max(most, math.abs(entry.rot[i] - other.rot[i]))
						end
					end
				end
				return most
			end
			local calm = pose({})
			T.expect({ id, differs(calm, pose({ enraged = true })) > 0.05 }).toEqual({ id, true })
			local boss = styleOf(id).boss :: BipedStyles.BossLayer
			T.expect({ id, boss.shield ~= nil }).toEqual({ id, id ~= "hrimvald" })
			if boss.shield then
				T.expect({ id, differs(calm, pose({ shielded = true })) > 0.05 }).toEqual({ id, true })
			end
		end
	end)

	T.it(
		"no NaN and no pops through a fight: the walk, a roar, blows, a channel turning, hits, the stagger, the death",
		function()
			for _, id in BOSSES do
				local rig = rigOf(id)
				local style = styleOf(id)
				local boss = style.boss :: BipedStyles.BossLayer
				local def = Bosses.byId[id]
				local first = def.attacks[1]
				local channel, channelHit, channelHold = nil, 0, 0
				for _, cast in castsOf(id) do
					if cast.hold > 0 and not channel then
						channel, channelHit, channelHold = cast.name, cast.hit, cast.hold
					end
				end
				local plan = {
					{ name = boss.roar, start = 2, hit = boss.roarHit },
					{ name = style.basic[1], start = 4.6, hit = 0.74 },
					{ name = style.basic[2], start = 6.1, hit = 0.74 },
					{
						name = style.abilities[first.id],
						start = 7.6,
						hit = first.windup,
						arc = if first.leap then { 6, 0.35 } else nil,
						reach = if first.leap then { 0, 0, -8 } else nil,
					},
				}
				local at = 7.6 + BipedMotion.length(style.actions[style.abilities[first.id]], first.windup) + 0.3
				if channel then
					table.insert(
						plan,
						{ name = channel, start = at, hit = channelHit, hold = channelHold, turn = { 0.6, -0.6 } }
					)
					at += BipedMotion.length(style.actions[channel], channelHit, channelHold) + 0.3
				end
				table.insert(plan, { name = boss.stagger, start = at, hit = style.actions[boss.stagger].strike })
				at += 1.5
				table.insert(plan, { name = "death", start = at, hit = style.actions.death.strike })
				local finish = at + 2
				local hitAt = 5.3
				local motion = motionOf(id)
				local largest, excess, when = continuity(rig.keyed, 1 / 120, function(dt, sink)
					local inst = motion.new(rig.skel, id, 11, nil)
					local t, yaw = 0, 0
					while t < finish do
						local action = nil
						for _, step in plan do
							if t >= step.start then
								action = step
							end
						end
						yaw += ((if t > 0.8 and t < 1.6 then 0.8 else 0) - yaw) * math.min(1, dt * 10)
						local posed = motion.step(
							inst,
							input({
								now = t,
								dt = dt,
								speed = if t < 1.8 then 6 else 0,
								yawRate = yaw,
								combat = t > 1,
								gait = "walk",
								action = action,
								hitAt = if t > hitAt and t < hitAt + 1 then hitAt else nil,
								hitSide = "left",
								look = { 0.3, 0.1, -1 },
								enraged = t > 9,
								snap = t == 0,
							})
						)
						checkFinite(posed, `{id} at {t}`)
						sink(t, posed)
						t += dt
					end
				end)
				if excess > 0 then
					error(`{id}: a pop at {when}: {excess} over a continuous motion`)
				end
				-- (the fastest strikes, a swing of the whole arm in a tenth of a second, stay under 70 rad/s)
				T.expect({ id, largest < 0.6 }).toEqual({ id, true })
			end
		end
	)
end)

T.describe("The young frost dragon (the regular wyvern's style on its rig)", function()
	T.it("its rig builds, its kit is the wyvern's in melee, it walks and breathes without NaN", function()
		local rig = rigOf("youngFrostDragon")
		local style = styleOf("frostDragon")
		for _, name in style.basic do
			T.expect({ name, style.actions[name] ~= nil }).toEqual({ name, true })
		end
		T.expect(BipedMotion.pick(style, "frostBreath", nil, 1)).toBe("breath")
		local inst = BipedMotion.new(rig.skel, "frostDragon", 3) :: BipedMotion.Instance
		local run = { name = "breath", start = 2, hit = 1.5 }
		local L = rig.skel.legLength
		local low = math.huge
		local t = 0
		while t < 5 do
			local posed = BipedMotion.step(
				inst,
				input({ now = t, speed = if t < 2 then 5.7 else 0, combat = true, action = if t >= 2 then run else nil })
			)
			checkFinite(posed, `youngFrostDragon at {t}`)
			for _, p in joints(rig.skel, posed) do
				low = math.min(low, p[2])
			end
			t += 1 / 30
		end
		T.expect(low / L).toBeBetween(-0.1, 2)
	end)
end)

T.describe("AnimLab: the bosses", function()
	T.it("boss <id> takes every attack, every pattern (a riding one too), the roar, the rage and the death", function()
		for _, id in BOSSES do
			local function shows(what: string): boolean
				return AnimLab.parse({ "boss", id, what }) ~= nil
			end
			for _, attack in Bosses.byId[id].attacks do
				T.expect({ id, attack.id, shows(attack.id) }).toEqual({ id, attack.id, true })
			end
			for patternId in (BossMotions.get(id) :: BossMotions.BossMotion).patterns do
				T.expect({ id, patternId, shows(patternId) }).toEqual({ id, patternId, true })
			end
			for _, extra in AnimLab.BOSS_EXTRAS do
				T.expect({ id, extra, shows(extra) }).toEqual({ id, extra, true })
			end
		end
	end)

	T.it("mob <id> takes every action of a boss's style and its states", function()
		for _, id in { "grimrok", "morvane", "azgor", "hrimvald", "youngFrostDragon" } do
			local styleId = (MonsterAssets :: any)[id].motion
			local function shows(state: string): boolean
				local command = AnimLab.parse({ "mob", id, state })
				return command ~= nil and (command :: any).slot == state
			end
			local states = { "enraged", "shielded", "fight", "walk", "idle" }
			for name in styleOf(styleId).actions do
				table.insert(states, name)
			end
			for _, state in states do
				T.expect({ id, state, shows(state) }).toEqual({ id, state, true })
			end
		end
	end)
end)
