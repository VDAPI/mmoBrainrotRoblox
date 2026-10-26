--!strict
-- Template animation (owner 2026-10-26, docs/ANIM-WZORCE.md F5): the rigid models moved whole by Logic/RigidMotion
-- (Data/RigidStyles): every kind's kit has its action, every blow lands on the server's hit, the poses stay finite,
-- rigid and continuous, deaths never sink and come to rest, a hop's feet stay planted, flights follow the Dash* arc,
-- the serpent's wave grows to its tail, and AnimLab can show every state.
local AnimLab = require("../src/shared/Logic/AnimLab")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local RigidMotion = require("../src/shared/Logic/RigidMotion")
local RigidStyles = require("../src/shared/Data/RigidStyles")
local T = require("./Test")

type Body = RigidMotion.Body

-- The drawn looks (studs, roughly the rig dumps x LookScale x visual): h top, lift bottom (a flyer's hover), B, W.
local KINDS: { [string]: { style: string, h: number, lift: number, B: number, W: number } } = {
	caveSpider = { style = "spider", h = 3.4, lift = 0, B = 6.7, W = 7.3 },
	desertScorpion = { style = "scorpion", h = 5.3, lift = 0, B = 7.5, W = 5.6 },
	basilisk = { style = "lizard", h = 2.7, lift = 0, B = 4.2, W = 2.4 },
	salamander = { style = "lizard", h = 3.7, lift = 0, B = 4.7, W = 2.7 },
	bogSerpent = { style = "serpent", h = 3.7, lift = 0, B = 5.0, W = 5.0 },
	frostWyrm = { style = "serpent", h = 3.7, lift = 0, B = 3.2, W = 3.8 },
	carrionCrow = { style = "crow", h = 3.4, lift = 1.95, B = 1.5, W = 1.5 },
	bloodBat = { style = "bat", h = 4.7, lift = 2.3, B = 2.1, W = 2.5 },
	swampToad = { style = "toad", h = 2.4, lift = 0, B = 3.5, W = 3.1 },
	rabbit = { style = "hare", h = 1.9, lift = 0, B = 1.7, W = 0.86 },
	rotEnt = { style = "ent", h = 13.4, lift = 0, B = 13.2, W = 12.3 },
	lynx = { style = "cat", h = 3.75, lift = 0, B = 4.2, W = 1.9 },
	snowLeopard = { style = "cat", h = 4.2, lift = 0, B = 4.7, W = 2.1 },
}
local HITS = { 0.45, 0.5, 0.55, 0.74, 0.81, 1.2, 1.3, 1.4, 1.8, 2.2 }

local function bodyOf(id: string): Body
	local k = KINDS[id]
	return { h = k.h, lift = k.lift, B = k.B, W = k.W, x0 = 0, z0 = 0, squash = true }
end

local function finite(x: number): boolean
	return x == x and x > -1e9 and x < 1e9
end

-- The angle (rad) between two rotations (row-major 1..9).
local function angleBetween(a: { number }, b: { number }): number
	local tr = 0
	for i = 0, 2 do
		for j = 0, 2 do
			tr += a[i * 3 + j + 1] * b[i * 3 + j + 1]
		end
	end
	return math.acos(math.clamp((tr - 1) / 2, -1, 1))
end

local function orthonormal(m: { number }): boolean
	for i = 0, 2 do
		for j = 0, 2 do
			local d = 0
			for k = 0, 2 do
				d += m[i * 3 + k + 1] * m[j * 3 + k + 1]
			end
			if math.abs(d - (if i == j then 1 else 0)) > 1e-6 then
				return false
			end
		end
	end
	return true
end

local function input(now: number, dt: number, o: { [string]: any }?): RigidMotion.Input
	local i: { [string]: any } = { now = now, dt = dt, speed = 0, yawRate = 0, combat = false, squash = true }
	if o then
		for k, v in o do
			i[k] = v
		end
	end
	return i :: any
end

T.describe("RigidMotion kinds", function()
	T.it("sets a rigid style on every boneless kind and leaves the spirits to the flyer worker", function()
		for id, k in KINDS do
			local look = MonsterLooks.get(id)
			T.expect(look and look.asset and look.asset.motion).toBe(k.style)
			T.expect(RigidStyles.get(k.style) ~= nil).toBe(true)
		end
		for _, id in { "specter", "iceElemental" } do
			local look = MonsterLooks.get(id)
			local motion = look and look.asset and look.asset.motion
			T.expect(motion == nil or RigidStyles.get(motion) == nil).toBe(true)
		end
	end)

	T.it("has an action for every blow of each kind's kit, its deaths, appear and fidgets", function()
		for id, k in KINDS do
			local style = RigidStyles.get(k.style) :: RigidStyles.Style
			local function has(name: string?, what: string)
				if not name or not style.actions[name] then
					error(`{id} ({k.style}): no action for {what} ({name})`)
				end
			end
			for i = 1, 4 do
				has(RigidMotion.pick(style, nil, "melee", i), "regular blow")
			end
			local def = Monsters.get(id)
			if def and def.ability then
				T.expect(style.abilities[def.ability] ~= nil).toBe(true)
				has(RigidMotion.pick(style, def.ability, nil, 1), def.ability)
			end
			for _, ability in { "heavyBlow", "crush", "pounce" } do
				has(RigidMotion.pick(style, ability, nil, 1), ability)
			end
			has(RigidMotion.pick(style, nil, "throw", 1), "throw")
			for _, entry in style.death do
				has(entry.name, "death")
			end
			has(style.aggro, "aggro")
			has(style.spawn, "spawn")
			has(style.summon, "summon")
			for _, name in style.fidgets do
				has(name, "fidget")
			end
			for _, name in style.order do
				T.expect(style.gaits[name] ~= nil).toBe(true)
			end
		end
	end)

	T.it("lets AnimLab show every state of every rigid kind", function()
		for id, k in KINDS do
			for _, state in RigidStyles.labStates(k.style) do
				local command, err = AnimLab.parse({ "mob", id, state })
				if not command then
					error(`/animlab mob {id} {state}: {err}`)
				end
			end
		end
	end)
end)

T.describe("RigidMotion timeline", function()
	T.it("ends every strike exactly on the server's hit and samples like MotionTimeline", function()
		for _, styleId in RigidStyles.ids() do
			local style = RigidStyles.get(styleId) :: RigidStyles.Style
			for name, action in style.actions do
				local start = if action.keys[1].u == 0 and action.keys[1].seg == "A"
					then action.keys[1].pose
					else style.stance
				local strikeKey: RigidStyles.Key? = nil
				for _, key in action.keys do
					if key.seg == "S" and key.u == 1 then
						strikeKey = key
					end
				end
				for _, hit in HITS do
					local a, h, length = RigidMotion.times(action, hit)
					T.expect(math.abs(h - hit) < 1e-9).toBe(true)
					T.expect(math.abs(a - (hit - math.min(action.strike, 0.7 * hit))) < 1e-9).toBe(true)
					T.expect(math.abs(length - (hit + action.follow + action.recover)) < 1e-9).toBe(true)
					if strikeKey then
						local at = RigidMotion.controlsAt(style, name, hit, hit) :: { [string]: number }
						for key, v in strikeKey.pose do
							if math.abs((at[key] or 0) - v) > 1e-9 then
								error(`{styleId}.{name} at the hit {hit}: {key} {at[key]} ~= {v}`)
							end
						end
					end
					for step = 0, 60 do
						local t = length * step / 60
						local got = RigidMotion.controlsAt(style, name, hit, t) :: { [string]: number }
						local want = MotionTimeline.at(action :: any, hit, t, start)
						for key, v in want do
							if math.abs((got[key] or 0) - v) > 1e-9 then
								error(`{styleId}.{name} t {t}: {key} {got[key]} ~= {v}`)
							end
						end
						for key, v in got do
							T.expect(finite(v)).toBe(true)
							if want[key] == nil and math.abs(v) > 1e-9 then
								error(`{styleId}.{name} t {t}: extra {key}`)
							end
						end
					end
				end
			end
		end
	end)

	T.it("flies the pounce from the crouch to the target over the strike", function()
		for _, styleId in RigidStyles.ids() do
			local style = RigidStyles.get(styleId) :: RigidStyles.Style
			local name = style.abilities.pounce
			if not name then
				continue -- the hare has no Elites
			end
			local action = style.actions[name]
			T.expect(action ~= nil and action.flight == true).toBe(true)
			local a = RigidMotion.times(action :: RigidStyles.Action, 1.4)
			T.expect(((RigidMotion.controlsAt(style, name, 1.4, a + 1e-6) :: any).travel or 0) < 0.01).toBe(true)
			T.expect((RigidMotion.controlsAt(style, name, 1.4, 1.4) :: any).travel).toBe(1)
		end
	end)
end)

-- One kind's life at 60 Hz: idle, the server's walk / trot / run, a turn, the alert, blows, the own ability, hits from
-- each side, stun, freeze, a death; every frame is checked.
local function life(id: string, seed: number)
	local k = KINDS[id]
	local style = RigidStyles.get(k.style) :: RigidStyles.Style
	local inst = RigidMotion.new(bodyOf(id), k.style, seed) :: RigidMotion.Instance
	local def = Monsters.get(id)
	local ms = if def and def.moveSpeed then def.moveSpeed else 13
	local own = if def and def.ability then style.abilities[def.ability] else nil
	local ownWindup = if def and def.ability then (MonsterAbilities.get(def.ability) :: any).windup else 1.3
	local deathName = RigidMotion.death(inst)
	local plan: { { at: number, name: string, hit: number, mirror: boolean? } } = {
		{ at = 7, name = style.aggro :: string, hit = 0.45 },
		{ at = 8, name = RigidMotion.pick(style, nil, "melee", 1), hit = 0.74 },
		{ at = 9, name = RigidMotion.pick(style, nil, "melee", 2), hit = 0.74, mirror = true },
		{ at = 10, name = own or style.basic[1], hit = ownWindup },
		{ at = 12.5, name = RigidMotion.pick(style, "crush", nil, 1), hit = 2.2 },
		{ at = 15.5, name = style.spawn :: string, hit = 0.5 },
		{ at = 21, name = deathName, hit = style.actions[deathName].strike },
	}
	local sides = { "front", "back", "left", "right" }
	local dt = 1 / 60
	local prevM: { number }? = nil
	local prevT = { 0, 0, 0 }
	local maxH = math.max(k.h, k.B)
	local hMesh = k.h - k.lift
	for frame = 0, math.floor(23 / dt) do
		local now = frame * dt
		local o: { [string]: any } = {}
		if now >= 2 and now < 3 then
			o.speed, o.gait = ms * 0.4, "walk"
		elseif now >= 3 and now < 4 then
			o.speed, o.gait = ms * 0.7, "trot"
		elseif now >= 4 and now < 6 then
			o.speed, o.gait, o.combat = ms, "run", true
		elseif now >= 6 and now < 6.6 then
			o.yawRate, o.yawDelta = 2.4, 2.4 * dt
		end
		if now >= 7 then
			o.combat = true
			o.look = { 0, 0, -8 }
		end
		for _, step in plan do
			if now >= step.at then
				o.action =
					{ name = step.name, start = step.at, hit = step.hit, reach = { 0, 0, -8 }, mirror = step.mirror }
			end
		end
		if now >= 11.5 and now < 12.5 then
			local i = math.floor((now - 11.5) / 0.25)
			o.hitAt, o.hitSide = 11.5 + i * 0.25, sides[i + 1]
		end
		o.stun = now >= 17 and now < 18.5
		o.frozen = now >= 19 and now < 20.5
		local posed = RigidMotion.step(inst, input(now, dt, o))
		local m = posed.m
		for i = 1, 12 do
			if not finite(m[i]) then
				error(`{id} t {now}: m[{i}] = {m[i]}`)
			end
		end
		if not orthonormal(m) then
			error(`{id} t {now}: the rotation is not rigid`)
		end
		for _, s in { posed.sx, posed.sy, posed.sz } do
			if s < 0.85 - 1e-9 or s > 1.15 + 1e-9 then
				error(`{id} t {now}: scale {s}`)
			end
		end
		T.expect(posed.alpha >= 0 and posed.alpha <= 1).toBe(true)
		if prevM then
			local turn = angleBetween(prevM, m)
			-- the box's centre (the ground point under the root swings far when the body turns about its middle)
			local cy = k.lift + hMesh / 2
			local cx, cyy, cz = m[2] * cy + m[10], m[5] * cy + m[11], m[8] * cy + m[12]
			local move = math.sqrt((cx - prevT[1]) ^ 2 + (cyy - prevT[2]) ^ 2 + (cz - prevT[3]) ^ 2)
			-- no pops: a frame turns less than 35 degrees and moves less than a third of the body
			if turn > math.rad(35) or move > 0.34 * maxH + 0.6 then
				error(`{id} t {now}: a pop of {math.deg(turn)} deg, {move} studs`)
			end
		end
		prevM = table.clone(m)
		local cy = k.lift + hMesh / 2
		prevT[1], prevT[2], prevT[3] = m[2] * cy + m[10], m[5] * cy + m[11], m[8] * cy + m[12]
		-- the corpse at rest on the ground at the end
		if now > 22.9 then
			local low = RigidMotion.lowest(m, inst.body, posed.sx, posed.sy, posed.sz, style.footprint)
			if math.abs(low) > 0.04 * hMesh + 0.02 then
				error(`{id}: the corpse rests {low} studs off the ground`)
			end
		end
	end
end

T.describe("RigidMotion poses", function()
	T.it("stays finite, rigid, within the squash limits and without pops through a whole life", function()
		for id in KINDS do
			life(id, 3.7)
			life(id, 11.2)
		end
	end)

	T.it("never sinks a dying body into the ground and lays it to rest", function()
		for id, k in KINDS do
			local style = RigidStyles.get(k.style) :: RigidStyles.Style
			for _, entry in style.death do
				local action = style.actions[entry.name]
				local inst = RigidMotion.new(bodyOf(id), k.style, 5) :: RigidMotion.Instance
				local hMesh = k.h - k.lift
				local run = { name = entry.name, start = 0, hit = action.strike }
				local length = RigidMotion.length(action, action.strike)
				local dt = 1 / 60
				local low = 0
				for frame = 0, math.ceil((length + 0.5) / dt) do
					local now = frame * dt
					local posed = RigidMotion.step(inst, input(now, dt, { action = run, snap = frame == 0 }))
					low = RigidMotion.lowest(posed.m, inst.body, posed.sx, posed.sy, posed.sz, style.footprint)
					if low < -0.06 * hMesh - 0.02 then
						error(`{id} {entry.name} t {now}: {low} studs under the ground`)
					end
				end
				if math.abs(low) > 0.03 * hMesh + 0.02 then
					error(`{id} {entry.name}: rests {low} studs off the ground`)
				end
			end
		end
	end)

	T.it("keeps a hopper's feet planted while they touch the ground (the body catches up in the air)", function()
		for _, id in { "swampToad", "rabbit" } do
			local k = KINDS[id]
			local style = RigidStyles.get(k.style) :: RigidStyles.Style
			local hop = style.gaits[style.order[1]].hop :: RigidStyles.Hop
			local inst = RigidMotion.new(bodyOf(id), k.style, 2) :: RigidMotion.Instance
			local def = Monsters.get(id)
			local v = if def and def.moveSpeed then def.moveSpeed else 11
			for _, speed in { v * 0.4, v } do
				local dt = 1 / 120
				local rootZ = 0
				local slide, travel = 0, 0
				local lastZ: number? = nil
				local lastPhase = 0
				for frame = 0, 600 do
					local now = frame * dt
					rootZ -= speed * dt
					local posed = RigidMotion.step(inst, input(now, dt, { speed = speed, snap = frame == 0 }))
					local m = posed.m
					-- the bottom centre of the body in the world (front -Z)
					local z = rootZ + m[7] * 0 + m[8] * inst.body.lift + m[9] * 0 + m[12]
					local phase = inst.phase
					if
						frame > 240
						and lastZ
						and phase < hop.ground
						and lastPhase < hop.ground
						and phase > lastPhase
					then
						slide += math.abs(z - lastZ)
						travel += speed * dt
					end
					lastZ, lastPhase = z, phase
				end
				T.expect(travel > 0).toBe(true)
				if slide > 0.2 * travel then
					error(`{id} at {speed}: the feet slide {slide} over {travel} studs of ground contact`)
				end
			end
		end
	end)

	T.it("gives each monster its own rhythm (seed)", function()
		local a = RigidMotion.new(bodyOf("caveSpider"), "spider", 1.3) :: RigidMotion.Instance
		local b = RigidMotion.new(bodyOf("caveSpider"), "spider", 8.9) :: RigidMotion.Instance
		T.expect(a.rate ~= b.rate).toBe(true)
		local diff = 0
		for frame = 0, 120 do
			local now = frame / 60
			local pa = RigidMotion.step(a, input(now, 1 / 60, { speed = 6, snap = frame == 0 }))
			local ya = pa.m[11]
			local pb = RigidMotion.step(b, input(now, 1 / 60, { speed = 6, snap = frame == 0 }))
			diff = math.max(diff, math.abs(ya - pb.m[11]))
		end
		T.expect(diff > 0.01).toBe(true)
	end)

	T.it("follows the server's gait intent for the cat and the lizard", function()
		local cat = RigidMotion.new(bodyOf("lynx"), "cat", 4) :: RigidMotion.Instance
		RigidMotion.step(cat, input(0, 1 / 60, { speed = 9.8, gait = "trot", snap = true }))
		T.expect(cat.weights.trot).toBe(1)
		RigidMotion.step(cat, input(0, 1 / 60, { speed = 14, gait = "run", snap = true }))
		T.expect(cat.weights.gallop).toBe(1)
		local lizard = RigidMotion.new(bodyOf("basilisk"), "lizard", 4) :: RigidMotion.Instance
		RigidMotion.step(lizard, input(0, 1 / 60, { speed = 13, gait = "run", snap = true }))
		T.expect(lizard.weights.sprint).toBe(1)
	end)

	T.it("flies a pounce on the Dash* arc, else toward the target with its own arc", function()
		local style = RigidStyles.get("spider") :: RigidStyles.Style
		local name = style.abilities.pounce :: string
		local run = { name = name, start = 0, hit = 1.4, reach = { 0, 0, -12 } }
		local inst = RigidMotion.new(bodyOf("caveSpider"), "spider", 2) :: RigidMotion.Instance
		local free = RigidMotion.step(inst, input(1.2, 0, { action = run, snap = true, combat = true }))
		local fy, fz = free.m[11], free.m[12]
		T.expect(fy > 0.5).toBe(true) -- its own arc
		T.expect(fz < -1).toBe(true)
		local flight = { x = 0, y = 2.5, z = -4, pitch = 0.3 }
		local posed =
			RigidMotion.step(inst, input(1.2, 0, { action = run, snap = true, combat = true, flight = flight }))
		-- the server's arc replaces the own one (the keyed crouch / stretch on top is small)
		T.expect(math.abs(posed.m[12] - -4) < 0.8).toBe(true)
		T.expect(math.abs(posed.m[11] - 2.5) < 0.8).toBe(true)
	end)

	T.it("runs the serpent's wave down its bones, growing to the tail, the head steady", function()
		local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
		local function chain(prefix: string, n: number): RigidMotion.Chain
			local names, rest = {}, {}
			for i = 1, n do
				table.insert(names, `{prefix}{i}`)
				table.insert(rest, table.clone(I))
			end
			return { names = names, rest = rest }
		end
		local chains: RigidMotion.Chains =
			{ tail = chain("t", 9), coil = chain("c", 5), neck = chain("n", 6), head = chain("h", 1) }
		local inst = RigidMotion.new(bodyOf("frostWyrm"), "serpent", 6, chains) :: RigidMotion.Instance
		local peak: { [string]: number } = {}
		for frame = 0, 240 do
			local posed = RigidMotion.step(inst, input(frame / 60, 1 / 60, { speed = 8, snap = frame == 0 }))
			local bones = posed.bones :: { [string]: { number } }
			for name, m in bones do
				for i = 1, 9 do
					T.expect(finite(m[i])).toBe(true)
				end
				T.expect(orthonormal(m)).toBe(true)
				local yaw = math.abs(math.atan2(m[3], m[1]))
				peak[name] = math.max(peak[name] or 0, yaw)
			end
		end
		T.expect(peak.t9 > peak.t1).toBe(true)
		T.expect(peak.t9 > math.rad(10)).toBe(true)
		T.expect(peak.h1 < 1e-6).toBe(true)
	end)

	T.it("tells the flinch side and mirrors every other blow", function()
		T.expect(RigidMotion.side({ 0, 0, 1 })).toBe("front")
		T.expect(RigidMotion.side({ 0, 0, -1 })).toBe("back")
		T.expect(RigidMotion.side({ 1, 0, 0 })).toBe("left")
		T.expect(RigidMotion.side({ -1, 0, 0 })).toBe("right")
		T.expect(RigidMotion.mirror(1)).toBe(false)
		T.expect(RigidMotion.mirror(2)).toBe(true)
	end)
end)
