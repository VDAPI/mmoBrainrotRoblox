--!strict
-- Template animation, the mocap actions (2026-10-31: the owner's Mixamo download baked into Data/BipedClips). Every
-- clip decodes whole; every clip a style names is there with its timing; a blow's clip time lands its contact exactly
-- on the server's hit at every timing the server sends (squeezed at most 2.5 times, monotonic and continuous); the
-- falls and getting up at their own pace inside the corpse's fade; a mirrored clip is the mirror image; a leap's travel
-- lands on the target; a blade laid along the clip's; on a Mixamo skeleton (the guard NPC's rig dump) no NaN, nothing
-- under the ground, no pops through a fight with hits and a fall; the deaths by the blow's side, the blows from a place
-- of each instance's own; the AnimLab states.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local BipedClip = require("../src/shared/Logic/BipedClip")
local BipedClips = require("../src/shared/Data/BipedClips")
local BipedMotion = require("../src/shared/Logic/BipedMotion")
local BipedPose = require("../src/shared/Logic/BipedPose")
local BipedRigs = require("../src/shared/Data/BipedRigs")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MotionFx = require("../src/shared/Data/MotionFx")
local NpcPose = require("../src/shared/Logic/NpcPose")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local HUMANOIDS = { "humanoid1h", "humanoid2h", "caster", "brute", "ghost" }
local BOSSES = { "grimrok", "morvane", "azgor", "hrimvald" }

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

local function unitV(v: Vec): Vec
	local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function styleOf(id: string): BipedStyles.Style
	return BipedStyles.get(id) :: BipedStyles.Style
end

-- The guard NPC's rig dump (Mixamo bones with fingers) as client/Anim/BipedRig reads it, 6 studs tall.
local function skeleton(): BipedPose.Skeleton
	local dump = serde.decode("json", fs.readFile("tools/anim/rigs/npc_guard.json"))
	local scale = 6 / dump.height
	local rest: { [string]: BipedPose.Bone } = {}
	local names: { [string]: string } = {}
	for _, b in dump.bones do
		local back = unitV({ -b.look[1], -b.look[2], -b.look[3] })
		local up0 = b.up
		local k = dot(up0, back)
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
	local bones, _, options = BipedPose.collect(names, rest, nil)
	return BipedPose.skeleton(bones, options) :: BipedPose.Skeleton
end
local SKEL = skeleton()

-- The server's hits an action of `style` is played at: the regular blow's draws, its abilities' windups, the throw,
-- the shout.
local function hitsOf(style: BipedStyles.Style, name: string): { number }
	local out: { number } = {}
	local wind, variant = Combat.basicWind, Combat.basicWindVariant
	if table.find(style.basic, name) then
		for _, k in { variant.normal, variant.elite, variant.elite2, variant.boss } do
			table.insert(out, wind.melee * k)
		end
	end
	for abilityId, action in style.abilities do
		local ability = MonsterAbilities.get(abilityId)
		if action == name and ability then
			table.insert(out, ability.windup)
		end
	end
	if name == style.throw then
		table.insert(out, wind.throw * variant.elite2)
	end
	if name == style.aggro then
		table.insert(out, 0.45)
	end
	if style.boss and name == style.boss.roar then
		table.insert(out, style.boss.roarHit)
	end
	if #out == 0 then
		table.insert(out, 1.2)
	end
	return out
end

-- Every clip action of the humanoid and boss styles: { style id, action name, action }.
local function clipActions(): { { id: string, name: string, action: BipedStyles.Action } }
	local out = {}
	for _, list in { HUMANOIDS, BOSSES } do
		for _, id in list do
			for name, action in styleOf(id).actions do
				if action.clip then
					table.insert(out, { id = id, name = name, action = action })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.id .. a.name < b.id .. b.name
	end)
	return out
end

T.describe("BipedClips: the baked mocap", function()
	T.it("every clip decodes whole: its frames fill the data, unit turns, the bones the template drives", function()
		for _, name in BipedClips.names() do
			local source = BipedClips.get(name) :: BipedClip.Source
			local clip = BipedClip.decode(source)
			T.expect({ name, buffer.len(clip.buf) }).toEqual({ name, clip.frames * clip.stride })
			T.expect({ name, #source.bones }).toEqual({ name, #BipedPose.KEYS })
			for _, key in BipedPose.KEYS do
				T.expect({ name, key, table.find(source.bones, key) ~= nil }).toEqual({ name, key, true })
			end
			for f = 0, clip.frames - 1, 7 do
				for i = 1, #source.bones do
					local at = f * clip.stride + (i - 1) * 6
					local x = buffer.readi16(clip.buf, at) / 32767
					local y = buffer.readi16(clip.buf, at + 2) / 32767
					local z = buffer.readi16(clip.buf, at + 4) / 32767
					T.expect({ name, x * x + y * y + z * z <= 1.0005 }).toEqual({ name, true })
				end
			end
			-- a stride has its footfall (the breathing idle's sway is no stride)
			if source.loop and (source.speed or 0) > 0.5 then
				T.expect({ name, source.contact ~= nil }).toEqual({ name, true })
			end
			-- the same decode is shared by every instance
			T.expect(BipedClip.decode(source) == clip).toBe(true)
		end
	end)

	T.it("every clip a style names is there; a blow's clip has its hit and strike inside it", function()
		for _, entry in clipActions() do
			local ref = entry.action.clip :: BipedStyles.ClipRef
			local tag = `{entry.id}.{entry.name}`
			local source = BipedClips.get(ref.name) :: BipedClip.Source
			T.expect({ tag, source ~= nil }).toEqual({ tag, true })
			local length = (source.frames - 1) / source.fps
			local hit = ref.hit or source.hit
			T.expect({ tag, hit ~= nil and hit > (ref.from or 0) and hit < length }).toEqual({ tag, true })
			if not ref.free then
				T.expect({ tag, source.hit ~= nil and source.strike ~= nil }).toEqual({ tag, true })
				-- the action's strike is the clip's (its blow at its own pace)
				T.expect({ tag, entry.action.strike }).toEqual({ tag, source.strike })
			end
			if ref.fly then
				T.expect({ tag, ref.fly[1] < ref.fly[2] and ref.fly[2] <= (hit :: number) }).toEqual({ tag, true })
			end
			-- the clip still plays (and fades) to the action's end, not held at its last frame
			if not ref.free and not entry.action.hold then
				local after = entry.action.follow + entry.action.recover
				T.expect({ tag, (hit :: number) + after <= length + 0.05 }).toEqual({ tag, true })
			end
		end
		for _, id in HUMANOIDS do
			local style = styleOf(id)
			local clips = style.clips :: any
			for _, name in
				{ clips.walk, clips.run, clips.combat and clips.combat.idle, clips.combat and clips.combat.walk }
			do
				T.expect({ id, name, BipedClips.get(name) ~= nil }).toEqual({ id, name, true })
			end
			for side, list in style.hits or {} do
				for _, name in list do
					T.expect({ id, side, name, BipedClips.get(name) ~= nil }).toEqual({ id, side, name, true })
				end
			end
			for side, list in style.deaths or {} do
				for _, name in list do
					T.expect({ id, side, name, style.actions[name] ~= nil }).toEqual({ id, side, name, true })
				end
			end
		end
	end)

	T.it("the clips stay small: under 600 KB of source together", function()
		local total = 0
		for _, name in BipedClips.names() do
			local source = BipedClips.get(name) :: BipedClip.Source
			total += #source.data
		end
		T.expect(total < 600 * 1024).toBe(true)
	end)
end)

T.describe("BipedMotion: the clip time of a mocap blow", function()
	T.it("lands the clip's contact exactly on the server's hit at every timing it is played at", function()
		for _, entry in clipActions() do
			local ref = entry.action.clip :: BipedStyles.ClipRef
			if ref.free then
				continue
			end
			local source = BipedClips.get(ref.name) :: BipedClip.Source
			local style = styleOf(entry.id)
			for _, hit in hitsOf(style, entry.name) do
				local tag = `{entry.id}.{entry.name}@{hit}`
				local at = BipedMotion.clipTime(entry.action, source, hit, hit)
				T.expect({ tag, math.abs(at - (ref.hit or source.hit :: number)) < 1e-9 }).toEqual({ tag, true })
				-- monotonic, continuous, squeezed at most 2.5 times before the strike and played at the clip's pace
				-- after the hit
				local length = BipedMotion.length(entry.action, hit)
				local dt = 1 / 240
				local s = math.min(entry.action.strike, hit * 0.7)
				local function capAt(x: number): number
					return if x < hit - s then 2.5 elseif x < hit then entry.action.strike / s else 1
				end
				local prev = BipedMotion.clipTime(entry.action, source, hit, 0)
				T.expect({ tag, prev >= (ref.from or 0) - 1e-9 }).toEqual({ tag, true })
				local t = dt
				while t <= length do
					local c = BipedMotion.clipTime(entry.action, source, hit, t)
					local rate = (c - prev) / dt
					T.expect({ tag, rate >= -1e-6 }).toEqual({ tag, true })
					-- (a step across a phase's end: the faster phase's)
					local cap = math.max(capAt(t - dt), capAt(t))
					T.expect({ tag, t, rate <= cap + 1e-3 }).toEqual({ tag, t, true })
					prev = c
					t += dt
				end
			end
		end
	end)

	T.it("plays a fall and getting up at its own pace: the hit its own, the fall landed inside the fade", function()
		for _, id in HUMANOIDS do
			local style = styleOf(id)
			for name, action in style.actions do
				local ref = action.clip
				if ref and ref.free then
					local source = BipedClips.get(ref.name) :: BipedClip.Source
					local own = BipedMotion.ownHit(action) :: number
					local hc = ref.hit or source.hit :: number
					T.expect(own).toBeNear((hc - (ref.from or 0)) / (ref.rate or 1), 1e-9)
					-- whatever hit the game hands it
					local _, at, finish = BipedMotion.times(action, 0.2)
					T.expect(at).toBe(own)
					T.expect(finish).toBeNear(own + action.follow + action.recover, 1e-9)
					T.expect(BipedMotion.clipTime(action, source, 0.2, own)).toBeNear(hc, 1e-9)
					if string.sub(name, 1, 5) == "death" then
						-- the body on the floor (its dust: the follow-through's end) before half the corpse has faded
						T.expect({ id, name, own + action.follow < Config.CorpseSeconds * 0.72 })
							.toEqual({ id, name, true })
						T.expect({ id, name, action.hold == true and action.full == true }).toEqual({ id, name, true })
					end
				end
			end
		end
	end)
end)

T.describe("BipedClip: mirror, fit and blade", function()
	T.it("a mirrored clip is the mirror image: the left bone turns as the right one seen in a mirror", function()
		local source = BipedClips.get("mutantSwipe") :: BipedClip.Source
		local clip = BipedClip.decode(source)
		-- (a model on the clip's own rest: no retargeting turn)
		local plain = BipedClip.fit(source, source.dirs)
		local mirrorDirs: { [string]: Vec } = {}
		for key, d in source.dirs do
			mirrorDirs[BipedClip.otherSide(key)] = { -d[1], d[2], d[3] }
		end
		local mirrored = BipedClip.fit(source, mirrorDirs, { mirror = true })
		local S: Mat = { -1, 0, 0, 0, 1, 0, 0, 0, 1 }
		for _, time in { 0, 0.6, 1.27, 2 } do
			local a, offA = BipedClip.sample(clip, time, false, plain)
			local b, offB = BipedClip.sample(clip, time, false, mirrored, true)
			for _, key in { "RightArm", "LeftHand", "Spine2", "Head", "LeftUpLeg" } do
				local want = NpcPose.mul(NpcPose.mul(S, a[key]), S)
				local got = b[BipedClip.otherSide(key)]
				for i = 1, 9 do
					T.expect({ key, time, math.abs(want[i] - got[i]) < 1e-6 }).toEqual({ key, time, true })
				end
			end
			T.expect(offB[1]).toBeNear(-offA[1], 1e-9)
			T.expect(offB[3]).toBeNear(offA[3], 1e-9)
		end
	end)

	T.it("turns each bone onto the clip's rest direction, the arms keeping the knuckle line's roll", function()
		local source = BipedClips.get("swordSlash") :: BipedClip.Source
		T.expect(SKEL.knuckles ~= nil).toBe(true)
		local fit = BipedClip.fit(source, SKEL.dirs, { knuckles = SKEL.knuckles })
		for key, d in SKEL.dirs do
			local want = source.dirs[key]
			if want and fit[key] then
				local got = NpcPose.apply(fit[key], d)
				T.expect({ key, dot(got, unitV(want)) > 1 - 1e-5 }).toEqual({ key, true })
			end
		end
		local k = (SKEL.knuckles :: any).R
		local got = NpcPose.apply(fit.RightForeArm, k)
		local want = (source.knuckles :: any).R
		local dirC = source.dirs.RightForeArm
		-- the knuckle lines square to the bone agree
		local function square(v: Vec, axis: Vec): Vec
			local c = dot(v, axis)
			return unitV({ v[1] - axis[1] * c, v[2] - axis[2] * c, v[3] - axis[3] * c })
		end
		T.expect(dot(square(got, dirC), square(want, dirC)) > 1 - 1e-5).toBe(true)
	end)

	T.it("lays the model's blade along the clip's (the line its fist closes round) through the swing", function()
		local source = BipedClips.get("swordSlash") :: BipedClip.Source
		local clip = BipedClip.decode(source)
		local grip = unitV({ 0.42, -0.87, -0.22 })
		local fit = BipedClip.fit(source, SKEL.dirs, { knuckles = SKEL.knuckles, grip = grip })
		local bare: { [string]: Mat } = {}
		for _, key in source.bones do
			bare[key] = NpcPose.IDENTITY
		end
		for _, time in { 0, 0.4, 0.6, 1 } do
			local world = BipedClip.sample(clip, time, false, fit)
			local turn = BipedClip.sample(clip, time, false, bare)
			local blade = NpcPose.apply(world.RightHand, grip)
			local want = unitV(NpcPose.apply(turn.RightHand, (source.knuckles :: any).R))
			T.expect({ time, dot(blade, want) > 1 - 1e-5 }).toEqual({ time, true })
		end
	end)
end)

-- Steps `inst` through `plan` (actions by start) and hands every frame's pose to `sink`.
local function run(
	id: string,
	seed: number,
	finish: number,
	dt: number,
	over: (t: number, input: { [string]: any }) -> (),
	sink: (t: number, posed: BipedPose.Posed, inst: BipedMotion.Instance) -> ()
)
	local inst = BipedMotion.new(SKEL, id, seed, nil) :: BipedMotion.Instance
	local t = 0
	while t < finish do
		local input: { [string]: any } = { now = t, dt = dt, speed = 0, yawRate = 0, combat = true, snap = t == 0 }
		over(t, input)
		sink(t, BipedMotion.step(inst, input :: any), inst)
		t += dt
	end
end

local function checkFinite(posed: BipedPose.Posed, tag: string)
	for key, entry in posed do
		for i = 1, 9 do
			if not finite(entry.rot[i]) then
				error(`{tag}: NaN in {key}`)
			end
		end
		local o = entry.offset
		if o and not (finite(o[1]) and finite(o[2]) and finite(o[3])) then
			error(`{tag}: NaN offset`)
		end
	end
end

-- The lowest joint over the ground (leg lengths) of a pose.
local function lowest(world: BipedPose.World, shift: Vec): number
	local at = BipedPose.positions(SKEL, world, shift)
	local low = math.huge
	for _, p in at do
		low = math.min(low, p[2])
	end
	return low / SKEL.legLength
end

T.describe("BipedMotion: mocap actions on a Mixamo skeleton", function()
	T.it("every clip action at its server timing: no NaN, nothing under the ground, the falls lying low", function()
		for _, entry in clipActions() do
			if table.find(BOSSES, entry.id) then
				continue -- (on their own rigs: tests/bossstyles.spec)
			end
			local style = styleOf(entry.id)
			local hit = BipedMotion.ownHit(entry.action) or hitsOf(style, entry.name)[1]
			local length = BipedMotion.length(entry.action, hit)
			local low, lowAt, hipsEnd = math.huge, 0, 0
			local inst = BipedMotion.new(SKEL, entry.id, 3, { 0.42, -0.87, -0.22 }) :: BipedMotion.Instance
			local action = { name = entry.name, start = 0, hit = hit, reach = { 0, 0, -6 } }
			local t = 0
			while t <= length + 0.2 do
				local input: any = { now = t, dt = 1 / 30, speed = 0, yawRate = 0, combat = true, action = action }
				input.snap = t == 0
				local posed = BipedMotion.step(inst, input)
				checkFinite(posed, `{entry.id}.{entry.name} at {t}`)
				t += 1 / 30
			end
			-- the pose itself (positions): sampled through the motion's own layers
			inst = BipedMotion.new(SKEL, entry.id, 3, nil) :: BipedMotion.Instance
			local ref = entry.action.clip :: BipedStyles.ClipRef
			local source = BipedClips.get(ref.name) :: BipedClip.Source
			local clip = BipedClip.decode(source)
			local fit = BipedClip.fit(source, SKEL.dirs, { mirror = ref.mirror, knuckles = SKEL.knuckles })
			t = 0
			while t <= length do
				local tc = BipedMotion.clipTime(entry.action, source, hit, t)
				local world, off = BipedClip.sample(clip, tc, false, fit, ref.mirror)
				local L = SKEL.legLength
				local l = lowest(world, { off[1] * L, off[2] * L, off[3] * L })
				if l < low then
					low, lowAt = l, t
				end
				hipsEnd = 1 + off[2]
				t += 1 / 30
			end
			local tag = `{entry.id}.{entry.name}`
			if low < -0.12 then
				error(`{tag}: {low} leg lengths under the ground at {lowAt}`)
			end
			if string.sub(entry.name, 1, 5) == "death" then
				T.expect({ tag, hipsEnd < 0.45 }).toEqual({ tag, true })
			end
		end
	end)

	T.it("a leap's travel lands on the target at the hit; without a reach it stays over the root", function()
		for _, pair in { { "humanoid1h", "pounce" }, { "humanoid2h", "pounce" }, { "brute", "pounce" } } do
			local id, name = pair[1], pair[2]
			local hit = 1.4
			local L = SKEL.legLength
			for _, toward in { true, false } do
				local reach: Vec? = if toward then { 0, 0, -10 } else nil
				local at: { [number]: Vec } = {}
				run(id, 5, 2.6, 1 / 60, function(_, input)
					input.action = { name = name, start = 0.5, hit = hit, reach = reach }
				end, function(t, posed)
					local o = posed.Hips.offset :: Vec
					local hips = SKEL.bones.Hips
					local moved = NpcPose.apply(hips.rest, o)
					at[math.floor(t * 60 + 0.5)] = moved
				end)
				local landed = at[math.floor((0.5 + hit) * 60 + 0.5)]
				local tag = `{id}.{name} reach {reach ~= nil}`
				if reach then
					T.expect({ tag, math.abs(landed[3] - reach[3]) < 0.45 * L }).toEqual({ tag, true })
					T.expect({ tag, math.abs(landed[1]) < 0.45 * L }).toEqual({ tag, true })
				else
					T.expect({ tag, math.abs(landed[3]) < 0.6 * L }).toEqual({ tag, true })
				end
			end
		end
	end)

	T.it("no NaN and no pops through a fight: the shout, blows, a leap, hits from every side, a fall", function()
		for _, id in HUMANOIDS do
			local style = styleOf(id)
			-- (the mocap's: the caster's nova is keyed)
			local cleave = style.abilities.cleave
			if not (cleave and style.actions[cleave].clip) then
				cleave = style.basic[1]
			end
			local plan = {
				{ at = 0.3, name = style.aggro, hit = 0.45 },
				{ at = 2.2, name = style.basic[1], hit = 0.55 },
				{ at = 3.4, name = style.basic[2], hit = 0.66 },
				{ at = 4.6, name = style.basic[3] or style.basic[1], hit = 0.7425 },
				{ at = 6.0, name = style.abilities.pounce, hit = 1.4, reach = { 0, 0, -8 } },
				{ at = 7.2, name = cleave, hit = 1.0 },
			}
			local deathAt = 9.6
			local hitsAt = { 5.1, 6.6, 8.3, 8.9 }
			local sides = { "front", "left", "back", "right" }
			local function windows(dt: number): { [number]: number }
				local out: { [number]: number } = {}
				local last: BipedPose.Posed? = nil
				run(id, 7, 11.5, dt, function(t, input)
					input.speed = if t < 1.5 or (t > 8.2 and t < 9) then 6 else 0
					-- (a turn the root's smoothing hands over: no step in the rate)
					input.yawRate = if t > 1 and t < 1.4 then 0.8 * math.sin(math.pi * (t - 1) / 0.4) else 0
					input.look = { 0.2, 0, -1 }
					for _, step in plan do
						if t >= step.at and step.name then
							input.action = { name = step.name, start = step.at, hit = step.hit, reach = step.reach }
						end
					end
					for i, at in hitsAt do
						if t >= at then
							input.hitAt, input.hitSide = at, sides[i]
						end
					end
					if t >= deathAt then
						local inst0 = BipedMotion.new(SKEL, id, 7, nil) :: BipedMotion.Instance
						local name = BipedMotion.death(inst0, "front")
						local action = style.actions[name]
						local own = BipedMotion.ownHit(action) or action.strike
						input.action = { name = name, start = deathAt, hit = own }
						input.hitAt, input.combat, input.look = nil, false, nil
					end
				end, function(t, posed)
					checkFinite(posed, `{id} at {t}`)
					local prev = last
					if prev then
						local w = math.floor(t * 10)
						for key, entry in posed do
							local p = prev[key]
							if p then
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
			local coarse, half = windows(1 / 120), windows(1 / 240)
			for w, d in half do
				local ref = math.max(coarse[w - 1] or 0, coarse[w] or 0, coarse[w + 1] or 0)
				-- (a step under two degrees is the keyed layers' own, as the ghost's head at its first look)
				if d > 0.65 * ref + 0.03 then
					error(`{id}: a pop at {w / 10}: {d} against {ref}`)
				end
			end
		end
	end)

	T.it("a mocap hit turns the upper body for a moment and lets go; the keyed flinch without the clips", function()
		local base: BipedPose.Posed? = nil
		local struck: { [number]: BipedPose.Posed } = {}
		-- (0: not struck)
		for _, hitAt in { 0, 1 } do
			run("humanoid1h", 4, 1.9, 1 / 30, function(t, input)
				if hitAt > 0 and t >= hitAt then
					input.hitAt, input.hitSide = hitAt, "front"
				end
			end, function(t, posed)
				local f = math.floor(t * 30 + 0.5)
				if hitAt > 0 then
					struck[f] = posed
				elseif f == 36 then
					base = posed
				elseif f == 51 then
					struck[-1] = posed
				end
			end)
		end
		local function apart(a: BipedPose.Posed, b: BipedPose.Posed): number
			local most = 0
			for i = 1, 9 do
				most = math.max(most, math.abs(a.Spine2.rot[i] - b.Spine2.rot[i]))
			end
			return most
		end
		-- 0.2 s after the hit the chest has moved; 0.7 s after, the pose is the unstruck one again
		T.expect(apart(struck[36], base :: BipedPose.Posed) > 0.03).toBe(true)
		T.expect(apart(struck[51], struck[-1]) < 1e-6).toBe(true)
	end)

	T.it("the deaths by the blow's side; the regular blows from a place of each instance's own", function()
		local style = styleOf("humanoid1h")
		for seed = 1, 12 do
			local inst = BipedMotion.new(SKEL, "humanoid1h", seed, nil) :: BipedMotion.Instance
			T.expect(table.find((style.deaths :: any).front, BipedMotion.death(inst, "front")) ~= nil).toBe(true)
			T.expect(table.find((style.deaths :: any).back, BipedMotion.death(inst, "back")) ~= nil).toBe(true)
			T.expect(table.find(style.death, BipedMotion.death(inst, "left")) ~= nil).toBe(true)
			T.expect(table.find(style.death, BipedMotion.death(inst)) ~= nil).toBe(true)
		end
		local firsts: { [string]: boolean } = {}
		for seed = 1, 40 do
			firsts[BipedMotion.pick(style, nil, nil, 1, seed)] = true
			-- the turn goes on in order from there
			local a = BipedMotion.pick(style, nil, nil, 1, seed)
			local b = BipedMotion.pick(style, nil, nil, 2, seed)
			local ia, ib = table.find(style.basic, a) :: number, table.find(style.basic, b) :: number
			T.expect(ib).toBe(ia % #style.basic + 1)
		end
		local n = 0
		for _ in firsts do
			n += 1
		end
		T.expect(n >= 3).toBe(true)
		-- without a seed the first blow is the first
		T.expect(BipedMotion.pick(style, nil, nil, 1)).toBe(style.basic[1])
	end)
end)

T.describe("Mocap: the kinds, the effects and AnimLab", function()
	T.it("the two-handed kinds on humanoid2h; every style's actions with effects exist", function()
		for _, id in { "ashOrc", "renegadeDwarf", "frostGiant" } do
			T.expect((MonsterAssets :: any)[id].motion).toBe("humanoid2h")
		end
		for _, id in HUMANOIDS do
			local style = styleOf(id)
			for name in MotionFx.STYLES[id] or {} do
				T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
			end
			for _, name in style.basic do
				T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
			end
			for _, name in style.abilities do
				T.expect({ id, name, style.actions[name] ~= nil }).toEqual({ id, name, true })
			end
		end
	end)

	T.it("mob <id> shows the new blows, the falls and the hits", function()
		local function shows(id: string, state: string): boolean
			local command = AnimLab.parse({ "mob", id, state })
			return command ~= nil and (command :: any).slot == state
		end
		for _, pair in
			{
				{ "bandit", "chop" },
				{ "bandit", "deathBack2" },
				{ "bandit", "hitLeft" },
				{ "ashOrc", "hew" },
				{ "ashOrc", "cleave" },
				{ "yeti", "deathMutant" },
				{ "yeti", "clawR" },
				{ "darkCultist", "spellLeft" },
			}
		do
			T.expect({ pair[1], pair[2], shows(pair[1], pair[2]) }).toEqual({ pair[1], pair[2], true })
		end
	end)
end)
