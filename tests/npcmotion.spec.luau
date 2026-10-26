--!strict
-- NPC animation (owner 2026-10-26: "after the monsters, the NPCs"): Logic/NpcMotion on the owner's NPC models' rig
-- dumps (tools/anim/rigs/npc_<id>.json) with their Data/NpcStyles: no NaN through every state; the feet planted while
-- it stands, works and talks; a turn to a partner behind it made on stepping feet, never both feet up; the paced walk
-- with planted feet and back to its spot; the smith's hammer coming down onto the anvil; one greeting per approach;
-- talk gestures and the work resumed after; no joint jumps; the seed's variety; every NPC of Data/Npcs with a style
-- whose moves exist; Data/NpcRigs; the AnimLab states.

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

type Rig = { skel: BipedPose.Skeleton, keep: { [string]: boolean } }

-- A dump's skeleton as client/Anim/NpcRig reads the model (root space, ground at its feet), its palms fitted.
local function rigOf(model: string): Rig
	local dump = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
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
	local id = string.gsub(model, "^npc_", "")
	return { skel = skel, keep = NpcRigs.keep(NpcRigs.of(id)) }
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
	end)
end)
