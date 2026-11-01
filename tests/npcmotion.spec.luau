--!strict
-- NPC animation (owner 2026-10-26: "after the monsters, the NPCs"): Logic/NpcMotion on the owner's NPC models' rig
-- dumps (tools/anim/rigs/npc_<id>.json) with their Data/NpcStyles: no NaN through every state; the feet planted while
-- it stands, works and talks; a turn to a partner behind it made on stepping feet, never both feet up; the paced walk
-- with planted feet and back to its spot; the smith's hammer coming down onto the anvil; one greeting per approach;
-- talk gestures and the work resumed after; no joint jumps; the seed's variety; every NPC of Data/Npcs with a style
-- whose moves exist; Data/NpcRigs; the AnimLab states; Teodor's channel (hands raised, palms forward, the glow on); the
-- beat walked smoothly at 60 fps on every dump and an R15 figure (knees, held frames, planted ankles, lifts alike).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AnimLab = require("../src/shared/Logic/AnimLab")
local BipedPose = require("../src/shared/Logic/BipedPose")
local BipedRigs = require("../src/shared/Data/BipedRigs")
local NpcMotion = require("../src/shared/Logic/NpcMotion")
local NpcRigs = require("../src/shared/Data/NpcRigs")
local NpcSteps = require("../src/shared/Logic/NpcSteps")
local NpcStyles = require("../src/shared/Data/NpcStyles")
local Npcs = require("../src/shared/Data/Npcs")
local T = require("./Test")

type Vec = { number }

-- the dumps with bones (the caravan has none) and the NPC whose style each one shows
local MODELS: { { string } } = {
	{ "npc_blacksmith", "blacksmith" },
	{ "npc_merchant", "merchant" },
	{ "npc_innkeeper", "innkeeper" },
	{ "npc_guard", "guard" },
	{ "npc_healer", "healer" },
	{ "npc_banker", "banker" },
	{ "npc_captain", "captain" },
	{ "npc_wanderer", "wanderer" },
	{ "npc_vendor_hunter", "vendor_hunter" },
	-- Teodor's new export (2026-10-31: Mixamo, a T-pose, read from its FBX)
	{ "portalmaster_v2", "portalmaster" },
}
local HEIGHT = 5.5 -- studs: the models are scaled to about a player's height
local DT = 1 / 30

local function unitV(v: Vec): Vec
	local l = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function dist(a: Vec, b: Vec): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

local function finite(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

type Rig = { skel: BipedPose.Skeleton, keep: { [string]: boolean }, palms: { [string]: Vec } }

-- A new export's dump (FBX units, bone heads and tails, the lowest vertex at y = 0) as Studio imports it: without the
-- leaf bones no vertex weighs on (the toe and head ends, the fingers' fourth bones), a rest frame along each bone rolled
-- a little more each (nothing may lean on them being tidy), in the Studio dump's shape.
local function fromExport(model: string): any
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local bones = {}
	for i, b in dump.bones do
		if string.match(b.name, "_End$") or string.match(b.name, "%a4$") then
			continue
		end
		local d = unitV({ b.tail[1] - b.head[1], b.tail[2] - b.head[2], b.tail[3] - b.head[3] })
		local a = i * 0.7
		local ref = if math.abs(d[1]) < 0.9 then { math.cos(a), 0, -math.sin(a) } else { 0, math.cos(a), math.sin(a) }
		local up = unitV(cross(ref, d))
		table.insert(bones, { name = b.name, pos = b.head, look = d, up = up })
	end
	return { height = dump.size[2], bones = bones }
end

-- A dump's skeleton as client/Anim/NpcRig reads the model (root space, ground at its feet), its palms fitted.
local function rigOf(model: string): Rig
	local dump = if string.match(model, "_v2$")
		then fromExport(model)
		else serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local scale = HEIGHT / dump.height
	local rest: { [string]: BipedPose.Bone } = {}
	local names: { [string]: string } = {}
	local at: { [string]: Vec } = {}
	for _, b in dump.bones do
		local back = unitV({ -b.look[1], -b.look[2], -b.look[3] })
		local up0 = b.up
		local k = up0[1] * back[1] + up0[2] * back[2] + up0[3] * back[3]
		local up = unitV({ up0[1] - back[1] * k, up0[2] - back[2] * k, up0[3] - back[3] * k })
		local right = cross(up, back)
		local pos = { b.pos[1] * scale, b.pos[2] * scale, b.pos[3] * scale }
		rest[b.name] =
			{ rest = { right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3] }, pos = pos }
		local key = BipedRigs.keyOf(b.name)
		if not names[key] then
			names[key] = b.name
		end
		at[(string.gsub(b.name, "^mixamorig%d*:", ""))] = pos
	end
	local bones = BipedPose.collect(names, rest, nil)
	local skel = BipedPose.skeleton(bones, {})
	assert(skel, model)
	local palms: { [string]: Vec } = {}
	for _, s in { "Right", "Left" } do
		local i1, p1 = at[s .. "HandIndex1"], at[s .. "HandPinky1"] or at[s .. "HandRing1"]
		local h, m1 = at[s .. "Hand"], at[s .. "HandMiddle1"]
		if i1 and p1 and h and m1 then
			local across = { i1[1] - p1[1], i1[2] - p1[2], i1[3] - p1[3] }
			local dir = { m1[1] - h[1], m1[2] - h[2], m1[3] - h[3] }
			palms[string.sub(s, 1, 1)] = unitV(if s == "Right" then cross(across, dir) else cross(dir, across))
		end
	end
	NpcMotion.fitPalms(skel, palms)
	local id = string.gsub(string.gsub(model, "^npc_", ""), "_v2$", "")
	return { skel = skel, keep = NpcRigs.keep(NpcRigs.of(id)), palms = palms }
end

local rigs: { [string]: Rig } = {}
local function rig(model: string): Rig
	local r = rigs[model]
	if not r then
		r = rigOf(model)
		rigs[model] = r
	end
	return r
end

-- An R15 figure as client/Anim/NpcRig.newR15 reads it (Motor6D joints, every part unturned): farmer_bartosz's legs as
-- Studio printed them (2026-11-01), the hips from the LowerTorso; the arms and the spine a plain R15's.
local function r15Figure(): Rig
	local function add(a: Vec, b: Vec): Vec
		return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
	end
	local function sub(a: Vec, b: Vec): Vec
		return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
	end
	local pts: { [string]: Vec } = {}
	for _, s in { { "Right", 1 }, { "Left", -1 } } do
		local side, m = s[1] :: string, s[2] :: number
		-- each joint: the parent's C0 out of the parent part, the child's C1 back to the child part
		local hip = { m * 0.360, -0.172, -0.034 }
		local knee = add(sub(hip, { m * 0.028, 0.545, -0.009 }), { m * -0.025, -0.546, -0.029 })
		local ankle = add(sub(knee, { m * 0.002, 0.624, -0.115 }), { m * -0.055, -0.637, 0.078 })
		pts[side .. "UpLeg"], pts[side .. "Leg"], pts[side .. "Foot"] = hip, knee, ankle
		pts[side .. "Sole"] = sub(ankle, { m * -0.031, 0.117 + 0.305 / 2, 0.191 })
		pts[side .. "Shoulder"] = { m * 0.35, 1.6, 0 }
		pts[side .. "Arm"] = { m * 1.0, 1.6, 0 }
		pts[side .. "ForeArm"] = { m * 1.05, 0.95, 0 }
		pts[side .. "Hand"] = { m * 1.05, 0.25, 0 }
	end
	local ground = math.min(pts.RightSole[2], pts.LeftSole[2])
	local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	local bones: { [string]: BipedPose.Bone } = {}
	local function bone(key: string, p: Vec)
		bones[key] = { rest = I, pos = { p[1], p[2] - ground, p[3] } }
	end
	bone("Hips", { 0, 0, 0 })
	for _, key in { "Spine", "Spine1", "Spine2" } do
		bone(key, { 0, 0.37, 0 })
	end
	bone("Neck", { 0, 1.85, 0 })
	bone("Head", { 0, 2.3, 0 })
	for _, side in { "Right", "Left" } do
		for _, key in { "Shoulder", "Arm", "ForeArm", "Hand", "UpLeg", "Leg", "Foot" } do
			bone(side .. key, pts[side .. key])
		end
	end
	local skel = BipedPose.skeleton(bones, nil)
	assert(skel, "R15")
	return { skel = skel, keep = NpcRigs.keep(NpcRigs.of("farmer_bartosz")), palms = {} }
end

local function new(model: string, npcId: string, seed: number?, style: NpcStyles.Style?): NpcMotion.Instance
	local r = rig(model)
	local def = Npcs.get(npcId)
	local s = style or NpcStyles.of(npcId, if def then def.services :: any else nil)
	return NpcMotion.new(r.skel, s, seed or 0.37, r.keep)
end

type Frame = { t: number, posed: NpcMotion.Posed, pos: { [string]: Vec }, inst: NpcMotion.Instance }

-- Runs `inst` for `seconds` more with the input of each moment (seconds into this run); `each` sees every frame.
local clocks: { [NpcMotion.Instance]: number } = {}
local function run(
	inst: NpcMotion.Instance,
	seconds: number,
	input: (t: number) -> NpcMotion.Input,
	each: (f: Frame) -> ()
)
	local t0 = clocks[inst]
	local t = 0
	while t <= seconds + 1e-9 do
		local i = input(t)
		local now = (t0 or 0) + t
		i.now, i.dt = now, if t0 == nil and t == 0 then 0 else DT
		local posed = NpcMotion.step(inst, i)
		each({ t = now, posed = posed, pos = BipedPose.positions(inst.skel, posed.world, posed.shift), inst = inst })
		t += DT
	end
	clocks[inst] = (t0 or 0) + t
end

local function person(x: number, z: number): { NpcMotion.Person }
	return { { id = 7, x = x, y = 5, z = z, me = true } }
end

local function allFinite(f: Frame): boolean
	for _, p in f.pos do
		if not (finite(p[1]) and finite(p[2]) and finite(p[3])) then
			return false
		end
	end
	for _, m in f.posed.world do
		for _, x in m do
			if not finite(x) then
				return false
			end
		end
	end
	return true
end

-- the inputs of the states every model goes through
local STATES: { [string]: (t: number) -> NpcMotion.Input } = {
	idle = function()
		return { now = 0, dt = 0, work = false }
	end,
	work = function()
		return { now = 0, dt = 0 }
	end,
	talk = function()
		return {
			now = 0,
			dt = 0,
			talk = true,
			partner = { 1.5, 5, -5 },
			people = person(1.5, -5),
			point = { -1, 0, 0 },
			force = "point",
		}
	end,
	greet = function(t)
		local k = math.min(1, t / 3)
		return { now = 0, dt = 0, people = person(-6 + 5 * k, -14 + 10 * k) }
	end,
	fidget = function()
		return { now = 0, dt = 0, work = false, force = "fidget" }
	end,
	pace = function()
		return { now = 0, dt = 0, work = false, force = "pace" }
	end,
}

T.describe("NpcMotion on the NPC rig dumps (2026-10-26)", function()
	T.it("poses every model through every state without NaN, joint jumps or the ground broken", function()
		for _, m in MODELS do
			for state, input in STATES do
				local inst = new(m[1], m[2])
				local L = inst.L
				local last: { [string]: Vec }? = nil
				local worst, worstKey = 0, ""
				run(inst, 14, input, function(f)
					assert(allFinite(f), `{m[1]} {state} NaN at {f.t}`)
					for _, key in { "RightFoot", "LeftFoot" } do
						T.expect(f.pos[key][2] > -0.05 * L).toBe(true)
					end
					local prev = last
					if prev then
						for key, p in f.pos do
							local d = dist(p, prev[key])
							if d > worst then
								worst, worstKey = d, key
							end
						end
					end
					last = f.pos
				end)
				-- a frame moves no joint farther than a quick blow does (0.3 leg lengths at 30 fps)
				if worst > 0.3 * L then
					error(`{m[1]} {state}: {worstKey} jumped {worst / L} leg lengths in a frame`)
				end
			end
		end
	end)

	T.it("keeps the feet planted while it stands, works and talks, and lifts at most one at a time", function()
		for _, m in MODELS do
			for _, state in { "idle", "work", "talk", "greet", "fidget" } do
				local inst = new(m[1], m[2])
				local spots: { [string]: Vec? } = {}
				run(inst, 14, STATES[state], function(f)
					local feet = f.inst.feet
					T.expect(feet.R.swing and feet.L.swing).toBe(false)
					for _, s in { "R", "L" } do
						local foot = (feet :: any)[s] :: NpcSteps.Foot
						local spot = spots[s]
						if not foot.swing and spot then
							-- a planted foot stays where it stood
							T.expect(math.abs(foot.x - spot[1]) + math.abs(foot.z - spot[2])).toBeNear(0, 1e-9)
						end
						spots[s] = if foot.swing then nil else { foot.x, foot.z }
						if not foot.swing and feet.heel < 0.01 then
							-- and the ankle is on it
							local ankle = f.pos[if s == "R" then "RightFoot" else "LeftFoot"]
							local d = math.sqrt((ankle[1] - foot.x) ^ 2 + (ankle[3] - foot.z) ^ 2)
							if d > 0.05 * inst.L then
								error(`{m[1]} {state} {s}: the ankle {d / inst.L} leg lengths off its spot at {f.t}`)
							end
						end
					end
				end)
			end
		end
	end)

	T.it("turns to a partner behind it on stepping feet", function()
		for _, m in MODELS do
			local inst = new(m[1], m[2])
			local steps = 0
			local was = false
			run(inst, 6, function(t)
				return { now = 0, dt = 0, talk = t > 0.5, partner = { 1, 5, 6 }, people = person(1, 6) }
			end, function(f)
				local feet = f.inst.feet
				T.expect(feet.R.swing and feet.L.swing).toBe(false)
				local swinging = feet.R.swing or feet.L.swing
				if swinging and not was then
					steps += 1
				end
				was = swinging
			end)
			-- facing the partner (behind: yaw toward +z)
			local want = NpcMotion.yawTo(1 - inst.bx, 6 - inst.bz)
			T.expect(math.abs(NpcSteps.angleTo(inst.yaw, want)) < 0.35).toBe(true)
			T.expect(steps >= 2).toBe(true)
		end
	end)

	T.it("walks its beat on planted feet and comes back to its spot", function()
		for _, m in MODELS do
			local inst = new(m[1], m[2])
			local L = inst.L
			local spots: { [string]: Vec? } = {}
			local far = 0
			local home = { inst.centre[1], inst.centre[3] }
			run(inst, 16, STATES.pace, function(f)
				local feet = f.inst.feet
				for _, s in { "R", "L" } do
					local foot = (feet :: any)[s] :: NpcSteps.Foot
					local spot = spots[s]
					if not foot.swing and spot then
						T.expect(math.abs(foot.x - spot[1]) + math.abs(foot.z - spot[2])).toBeNear(0, 1e-9)
					end
					spots[s] = if foot.swing then nil else { foot.x, foot.z }
				end
				far = math.max(far, math.sqrt((f.inst.bx - home[1]) ^ 2 + (f.inst.bz - home[2]) ^ 2))
			end)
			T.expect(far > 1.5).toBe(true) -- studs (the beat's span)
			-- it stops back on its spot, the feet down
			run(inst, 10, STATES.idle, function() end)
			T.expect(math.sqrt((inst.bx - home[1]) ^ 2 + (inst.bz - home[2]) ^ 2) < 0.3 * L).toBe(true)
			T.expect(inst.feet.R.swing or inst.feet.L.swing).toBe(false)
		end
	end)

	T.it("Teodor's T-pose export: the arms hang at his sides, his work holds the glow before his chest", function()
		-- the same as on an A-pose model (the banker's), in leg lengths
		local function hands(model: string): (Vec, Vec, Vec)
			local inst = new(model, "portalmaster")
			local L = inst.L
			local idle: { [string]: Vec } = {}
			run(inst, 4, STATES.idle, function(f)
				idle = f.pos
			end)
			local work: { [string]: Vec } = {}
			run(inst, 6, STATES.work, function(f)
				work = f.pos
			end)
			local function rel(p: Vec): Vec
				return { p[1] / L, p[2] / L, p[3] / L }
			end
			return rel(idle.RightHand), rel(work.RightHand), rel(work.LeftHand)
		end
		local idle, workR, workL = hands("portalmaster_v2")
		local idle0, workR0, workL0 = hands("npc_banker")
		for _, pair in { { idle, idle0 }, { workR, workR0 }, { workL, workL0 } } do
			T.expect(dist(pair[1], pair[2])).toBeBetween(0, 0.2)
		end
		-- hanging below the chest at his side; at work before it, apart
		T.expect(idle[2]).toBeBetween(0.8, 1.25)
		T.expect(workR[3] < -0.25 and workL[3] < -0.25 and workR[1] - workL[1] > 0.3).toBe(true)
	end)

	-- studio review 2026-10-31: his hands hung limp before him, the palms down, and no glow showed
	T.it("Teodor channels the portal: the hands raised before his chest, the palms forward, the glow on", function()
		for _, model in { "portalmaster_v2", "npc_banker" } do
			local inst = new(model, "portalmaster")
			local L = inst.L
			local palms = rig(model).palms
			local held = 0
			run(inst, 3, STATES.work, function(f)
				if f.t < 1.5 then
					return
				end
				local chest = f.pos.Spine2 or f.pos.Spine1
				for _, s in { "R", "L" } do
					local side = if s == "R" then "Right" else "Left"
					local hand = f.pos[side .. "Hand"]
					-- up at the chest's height and a forearm out before it, apart
					T.expect((hand[2] - chest[2]) / L).toBeBetween(0, 0.35)
					T.expect((hand[3] - chest[3]) / L).toBeBetween(-0.6, -0.3)
					local palm = palms[s]
					if palm then
						local m = f.posed.world[side .. "Hand"]
						local z = m[7] * palm[1] + m[8] * palm[2] + m[9] * palm[3]
						-- the palm toward the portal (front -Z)
						T.expect(z).toBeBetween(-1, -0.6)
					end
				end
				held = math.min(1, f.inst.layered.controls.channel or 0)
			end)
			T.expect(held).toBeBetween(0.9, 1)
		end
		local style = NpcStyles.of("portalmaster", nil)
		T.expect((style.work :: NpcStyles.Work).prop).toBe("channel")
	end)

	T.it("brings the smith's hammer down onto the anvil, again and again", function()
		local inst = new("npc_blacksmith", "blacksmith")
		local L = inst.L
		local top = NpcStyles.ANVIL.top * L
		local blows, down = 0, false
		local lowest, highest = math.huge, -math.huge
		run(inst, 20, STATES.work, function(f)
			if f.t < 2 then
				return
			end
			local hand = f.pos.RightHand
			lowest = math.min(lowest, hand[2])
			highest = math.max(highest, hand[2])
			local onAnvil = hand[2] < top + 0.2 * L
			if onAnvil and not down then
				blows += 1
			end
			down = onAnvil
		end)
		T.expect(lowest < top + 0.15 * L).toBe(true)
		T.expect(lowest > top - 0.15 * L).toBe(true)
		-- raised well above the anvil between the blows
		T.expect(highest > top + 0.35 * L).toBe(true)
		T.expect(blows >= 8).toBe(true)
	end)

	T.it("greets a player coming close once, and again only after they were away", function()
		local inst = new("npc_healer", "healer")
		local greets, was = 0, false
		local function count(f: Frame)
			local g = f.inst.move ~= nil and f.inst.move.kind == "greet"
			if g and not was then
				greets += 1
			end
			was = g
		end
		run(inst, 10, STATES.greet, count)
		T.expect(greets).toBe(1)
		-- standing on near it: no second greeting
		run(inst, 10, function()
			return { now = 0, dt = 0, people = person(-1, -4) }
		end, count)
		T.expect(greets).toBe(1)
	end)

	T.it("gestures while talking and goes back to its work after", function()
		local inst = new("npc_merchant", "merchant")
		run(inst, 6, STATES.work, function() end)
		T.expect(inst.work.weight > 0.9).toBe(true)
		local gestures = 0
		local seen: { [string]: boolean } = {}
		local last: string? = nil
		local talkFor = 16
		local t = 6
		while t <= 6 + talkFor do
			local i = STATES.talk(t)
			i.now, i.dt = t, DT
			NpcMotion.step(inst, i)
			local g = inst.talk.gesture
			local name = if g then g.name else nil
			if name and name ~= last then
				gestures += 1
				seen[name] = true
			end
			last = name
			t += DT
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		T.expect(gestures >= 3).toBe(true)
		T.expect(kinds >= 2).toBe(true)
		T.expect(seen.talkPoint).toBe(true)
		T.expect(inst.work.weight < 0.1).toBe(true)
		-- the dialogue closed: back to the stall
		local tEnd = t + 8
		while t <= tEnd do
			NpcMotion.step(inst, { now = t, dt = DT })
			t += DT
		end
		T.expect(inst.work.weight > 0.9).toBe(true)
	end)

	T.it("looks at a player passing by, the head first", function()
		local inst = new("npc_banker", "banker")
		local led = false
		run(inst, 8, function(t)
			return { now = 0, dt = 0, work = false, people = person(-9 + 2.25 * t, -5) }
		end, function(f)
			local a = f.inst.attn
			if a.weight > 0.5 and math.abs(a.yaw) > 0.2 and math.abs(a.yaw) > math.abs(a.chest) * 1.2 then
				led = true
			end
		end)
		T.expect(led).toBe(true)
	end)

	T.it("walks its beat smoothly at 60 fps, its feet on their spots (2026-11-01 Studio)", function()
		-- Studio on guard2 and farmer_bartosz's R15 figure: knees up to 16.5 deg a frame and held frames between, a
		-- foot planted at the start of the beat dragged 0.4 studs, one foot lifted 0.43 and the other 0.27; then (on
		-- e75960f5) feet near the floor going 0.26-0.46 studs
		local function turn(a: { number }, b: { number }): number
			local tr = 0
			for i = 1, 9 do
				tr += a[i] * b[i]
			end
			return math.deg(math.acos(math.clamp((tr - 1) / 2, -1, 1)))
		end
		local function relative(world: BipedPose.World, parent: string, child: string): { number }
			local a, b = world[parent], world[child]
			local o = {}
			for r = 0, 2 do
				for c = 0, 2 do
					local v = 0
					for k = 0, 2 do
						v += a[k * 3 + r + 1] * b[k * 3 + c + 1]
					end
					o[r * 3 + c + 1] = v
				end
			end
			return o
		end
		local JOINTS = {
			RightKnee = { "RightUpLeg", "RightLeg" },
			LeftKnee = { "LeftUpLeg", "LeftLeg" },
			RightHip = { "Hips", "RightUpLeg" },
			LeftHip = { "Hips", "LeftUpLeg" },
		}
		local cases: { { any } } = {}
		for _, m in MODELS do
			table.insert(cases, { m[1], m[2], rig(m[1]) })
		end
		table.insert(cases, { "R15", "farmer_bartosz", r15Figure() })
		for _, case in cases do
			local name, npcId, r = case[1], case[2], case[3] :: Rig
			local def = Npcs.get(npcId)
			local inst =
				NpcMotion.new(r.skel, NpcStyles.of(npcId, if def then def.services :: any else nil), 0.73, r.keep)
			local L = inst.L
			local last: { [string]: { number } }? = nil
			local rates: { [string]: { number } } = {}
			local lift = { R = { math.huge, -math.huge }, L = { math.huge, -math.huge } }
			local track: { [string]: { { number } } } = { R = {}, L = {} }
			local walked = 0
			local t = 0
			while t <= 16 do
				local posed =
					NpcMotion.step(inst, { now = t, dt = if t == 0 then 0 else 1 / 60, work = false, force = "pace" })
				local pos = BipedPose.positions(inst.skel, posed.world, posed.shift)
				local rel = {}
				for joint, pair in JOINTS do
					rel[joint] = relative(posed.world, pair[1], pair[2])
					if last then
						local a = turn(last[joint], rel[joint])
						if a > 12 then
							error(`{name}: {joint} turned {a} deg in a frame at {t}`)
						end
						rates[joint] = rates[joint] or {}
						table.insert(rates[joint], a)
					end
				end
				last = rel
				for _, s in { "R", "L" } do
					local foot = (inst.feet :: any)[s] :: NpcSteps.Foot
					local ankle = pos[if s == "R" then "RightFoot" else "LeftFoot"]
					lift[s][1] = math.min(lift[s][1], ankle[2])
					lift[s][2] = math.max(lift[s][2], ankle[2])
					table.insert(track[s], ankle)
					if not foot.swing then
						-- a planted ankle on its spot, walking too (the leg never stretched past its reach)
						local d = math.sqrt((ankle[1] - foot.x) ^ 2 + (ankle[3] - foot.z) ^ 2)
						if d > 0.01 * L then
							error(`{name} {s}: the planted ankle {d / L} leg lengths off its spot at {t}`)
						end
					end
				end
				if inst.feet.walking then
					walked += 1 / 60
				end
				t += 1 / 60
			end
			T.expect(walked > 1).toBe(true)
			-- no held frame: a joint does not stop for a frame between two that turn it
			for joint, list in rates do
				for i = 2, #list - 1 do
					local a, b, c = list[i - 1], list[i], list[i + 1]
					if a > 1.5 and c > 1.5 and b < 0.35 * math.min(a, c) then
						error(`{name}: {joint} held at frame {i}: {a} {b} {c} deg`)
					end
				end
			end
			-- read as Studio reads it, a foot is down while its ankle is near its lowest: one so low goes nowhere (the
			-- 2026-11-01 review took the last 0.3-0.5 studs of a swing, skimmed along the floor, for a planted foot sliding)
			for s, list in track do
				local from: { number }? = nil
				for _, ankle in list do
					if ankle[2] > lift[s][1] + 0.02 * L then
						from = nil
					elseif not from then
						from = ankle
					else
						local d = math.sqrt((ankle[1] - from[1]) ^ 2 + (ankle[3] - from[3]) ^ 2)
						if d > 0.02 * L then
							error(`{name} {s}: a foot down went {d / L} leg lengths`)
						end
					end
				end
			end
			-- both feet lift alike
			local liftR, liftL = lift.R[2] - lift.R[1], lift.L[2] - lift.L[1]
			if math.abs(liftR - liftL) > 0.2 * math.max(liftR, liftL) then
				error(`{name}: the feet lift {liftR / L} and {liftL / L} leg lengths`)
			end
		end
	end)

	T.it("is its own with every seed: two NPCs of one style do not move alike", function()
		local a = new("npc_guard", "guard", 0.11)
		local b = new("npc_guard", "guard", 0.83)
		local pa: { Vec } = {}
		run(a, 12, STATES.idle, function(f)
			table.insert(pa, f.pos.Head)
		end)
		local differ = 0
		local i = 0
		run(b, 12, STATES.idle, function(f)
			i += 1
			differ = math.max(differ, dist(f.pos.Head, pa[i]))
		end)
		T.expect(differ > 0.01 * a.L).toBe(true)
		-- and one seed repeats itself exactly
		local c = new("npc_guard", "guard", 0.11)
		local same = 0
		i = 0
		run(c, 12, STATES.idle, function(f)
			i += 1
			same = math.max(same, dist(f.pos.Head, pa[i]))
		end)
		T.expect(same).toBeNear(0, 1e-9)
	end)
end)

T.describe("Data/NpcStyles (2026-10-26)", function()
	T.it("gives every NPC of Data/Npcs a style whose moves all exist", function()
		for id, def in Npcs.byId do
			local style = NpcStyles.of(id, def.services :: any)
			T.expect(style.talk ~= nil).toBe(true)
			for _, name in NpcStyles.moveNames(style) do
				if not (NpcStyles.MOVES[name] or NpcStyles.MIRRORED[name]) then
					error(`{id}: move {name} is missing`)
				end
			end
			if style.work then
				T.expect(#style.work.phrases > 0).toBe(true)
			end
		end
		for id in NpcStyles.NPCS do
			T.expect(Npcs.get(id) ~= nil).toBe(true)
		end
	end)

	T.it("mirrors a move onto the other arm", function()
		local m = NpcStyles.MOVES.talkPoint
		local mirrored = NpcStyles.MIRRORED.talkPoint
		T.expect(m.arms.R).toBe(true)
		T.expect(mirrored.arms.L).toBe(true)
		T.expect(mirrored.arms.R).toBe(false)
	end)

	T.it("takes a work from the model's Work attribute and drops it for none", function()
		local smith = NpcStyles.of("blacksmith")
		T.expect(smith.work ~= nil).toBe(true)
		T.expect(NpcStyles.withWork(smith, "none").work).toBeNil()
		local healer = NpcStyles.of("healer")
		local hammering = NpcStyles.withWork(healer, "hammer")
		T.expect(hammering.work == smith.work).toBe(true)
		T.expect(NpcStyles.withWork(healer, nil) == healer).toBe(true)
		-- a role named on the model
		T.expect(NpcStyles.of("healer", nil, "guard").id).toBe("guard")
	end)
end)

T.describe("Data/NpcRigs (2026-10-26)", function()
	T.it("finds a model's entry by its id or the id without its number", function()
		T.expect(NpcRigs.keep(NpcRigs.of("guard")).R).toBe(true)
		T.expect(NpcRigs.keep(NpcRigs.of("guard2")).R).toBe(true)
		local none = NpcRigs.keep(NpcRigs.of("healer"))
		T.expect(none.R or none.L).toBe(false)
	end)
end)

T.describe("AnimLab NPC states (2026-10-26)", function()
	T.it("parses every NPC state and refuses an unknown one", function()
		for _, slot in AnimLab.NPC_SLOTS do
			local command = AnimLab.parse({ "npc", "blacksmith", slot })
			T.expect(command ~= nil).toBe(true)
		end
		local _, err = AnimLab.parse({ "npc", "blacksmith", "dance" })
		T.expect(err).toBe("animlab.error.npc")
		-- Teodor: every state, his work the mage's channel
		for _, slot in AnimLab.NPC_SLOTS do
			T.expect(AnimLab.parse({ "npc", "portalmaster", slot }) ~= nil).toBe(true)
		end
		local def = Npcs.get("portalmaster")
		local style = NpcStyles.of("portalmaster", if def then def.services :: any else nil)
		T.expect(style.id).toBe("mage")
		T.expect(style.work ~= nil and style.work.phrases[1].name == "channelHold").toBe(true)
	end)
end)
