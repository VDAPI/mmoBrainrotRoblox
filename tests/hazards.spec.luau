--!strict
-- S159: dodgeable hazards (Logic/Hazards, Data/HazardPatterns, Data/BossTuning.patterns): geometry, timing, hit
-- detection, deterministic expansion, the fairness rules and the boss scripts' data.

local BossTuning = require("../src/shared/Data/BossTuning")
local Bosses = require("../src/shared/Data/Bosses")
local HazardPatterns = require("../src/shared/Data/HazardPatterns")
local Hazards = require("../src/shared/Logic/Hazards")
local Sfx = require("../src/shared/Data/Sfx")
local T = require("./Test")

type Inst = Hazards.Inst

local function cast(seed: number, targets: { Hazards.Point }?, yaw: number?, delay: number?, arena: any?): Hazards.Cast
	return {
		seed = seed,
		origin = { x = 0, y = 0, z = 0 },
		yaw = yaw or 0,
		targets = targets or { { x = 20, y = 0, z = 0 } },
		arena = arena,
		delay = delay,
	}
end

local function one(e: Hazards.Emitter, c: Hazards.Cast?): Inst
	local list = Hazards.expand({ look = "test", color = "#FFFFFF", emitters = { e } }, c or cast(1))
	return list[1]
end

-- Steps `inst` from 0 to `seconds` at `dt` against a player standing at (px, pz) (root at y = 3, or `py`); the first
-- hit time or nil. `move` moves the player each step (dodging).
local function firstHit(
	inst: Inst,
	px: number,
	pz: number,
	seconds: number,
	py: number?,
	move: ((t: number) -> (number, number))?,
	arena: any?,
	aim: any?
): number?
	local st = Hazards.newState(inst)
	local dt = 1 / 60
	local t = 0
	while t < seconds do
		t += dt
		if move then
			px, pz = move(t)
		end
		Hazards.advance(inst, st, t, aim, arena)
		if Hazards.hits(inst, st, px, py or Hazards.ROOT_HEIGHT, pz, 0) then
			return t
		end
	end
	return nil
end

T.describe("Hazards geometry (S159)", function()
	T.it("segment distance: ends, middle, a point", function()
		T.expect(Hazards.segmentDistance(0, 5, -10, 0, 10, 0)).toBeNear(5, 1e-9)
		T.expect(Hazards.segmentDistance(13, 4, -10, 0, 10, 0)).toBeNear(5, 1e-9)
		T.expect(Hazards.segmentDistance(3, 4, 0, 0, 0, 0)).toBeNear(5, 1e-9)
	end)

	T.it("a bolt flies at its speed after its warning and hits a player on its path", function()
		local inst = one({ kind = "bolt", aim = "target", speed = 20, radius = 1, range = 60, life = 5, delay = 0.8 })
		T.expect(inst.a).toBeNear(0, 1e-9)
		local hit = firstHit(inst, 20, 0, 4)
		T.expect(hit ~= nil).toBe(true)
		-- 0.8 s warning + (20 - 1 - PLAYER_RADIUS) / 20 s of flight
		T.expect(hit :: number).toBeNear(0.8 + (20 - 1 - Hazards.PLAYER_RADIUS) / 20, 0.05)
		-- standing 2.5 studs off its line: safe (radius 1 + body 1)
		T.expect(firstHit(inst, 20, 2.5, 4)).toBeNil()
		-- nothing during the warning, even at the muzzle
		T.expect(firstHit(inst, 0.5, 0, 0.75)).toBeNil()
	end)

	T.it("a bolt passes under a jumping player and over nobody far below", function()
		local inst = one({ kind = "bolt", aim = "target", speed = 30, radius = 1, range = 60, life = 5, delay = 0.6 })
		T.expect(firstHit(inst, 15, 0, 3, Hazards.ROOT_HEIGHT + 8)).toBeNil()
		T.expect(firstHit(inst, 15, 0, 3, Hazards.ROOT_HEIGHT - 12)).toBeNil()
	end)

	T.it("a sidestep dodges a straight bolt, a standing player is hit", function()
		local inst = one({ kind = "bolt", aim = "target", speed = 18, radius = 1.2, range = 60, life = 5, delay = 0.6 })
		-- moving sideways at 16 studs/s from the moment it launches
		local hit = firstHit(inst, 20, 0, 4, nil, function(t: number)
			return 20, math.max(0, t - 0.6) * 16
		end)
		T.expect(hit).toBeNil()
		T.expect(firstHit(inst, 20, 0, 4) ~= nil).toBe(true)
	end)

	T.it("homing turns at most its rate towards the target", function()
		local inst = one({
			kind = "bolt",
			aim = "forward",
			speed = 10,
			radius = 1,
			range = 100,
			life = 10,
			homing = 45,
			delay = 0.6,
		}, cast(1, { { x = 0, y = 0, z = 30 } }, 0))
		local st = Hazards.newState(inst)
		local aim = function(_: number): (number?, number?)
			return 0, 30
		end
		Hazards.advance(inst, st, 0.6 + 1, aim)
		T.expect(st.a).toBeNear(math.rad(45), 0.02)
		Hazards.advance(inst, st, 0.6 + 4, aim)
		T.expect(math.abs(Hazards.wrap(st.a - Hazards.angleTo(st.x, st.z, 0, 30))) < math.rad(30)).toBe(true)
	end)

	T.it("a bouncing bolt stays inside the arena and ends after its bounces", function()
		local arena = { x = 0, z = 0, r = 20 }
		local inst = one({ kind = "bolt", aim = "forward", speed = 30, radius = 1, range = 999, life = 10, bounce = 2 })
		local st = Hazards.newState(inst)
		local t = 0
		local maxD = 0
		while not st.done and t < 10 do
			t += 1 / 60
			Hazards.advance(inst, st, t, nil, arena)
			maxD = math.max(maxD, math.sqrt(st.x * st.x + st.z * st.z))
		end
		T.expect(maxD <= 20 + 30 / 30 + 0.01).toBe(true)
		T.expect(st.done).toBe(true)
		T.expect(t < 10).toBe(true)
	end)

	T.it("a boomerang flies out its range and comes back to its start", function()
		local inst =
			one({ kind = "bolt", aim = "forward", speed = 20, radius = 1, range = 20, life = 5, returns = true })
		local st = Hazards.newState(inst)
		local t, far = 0, 0
		while not st.done and t < 5 do
			t += 1 / 60
			Hazards.advance(inst, st, t)
			far = math.max(far, st.x)
		end
		T.expect(far).toBeNear(20, 0.5)
		T.expect(st.done).toBe(true)
		T.expect(st.x).toBeNear(0, 0.01)
		T.expect(t).toBeNear(0.6 + 2, 0.1)
	end)

	T.it("a lob lands once at its point after its flight, inside its radius only", function()
		local inst = one({ kind = "lob", aim = "target", radius = 5, delay = 1.4 })
		T.expect(inst.tx).toBeNear(20, 1e-9)
		local hit = firstHit(inst, 22, 3, 3)
		T.expect(hit ~= nil).toBe(true)
		T.expect(hit :: number).toBeNear(1.4, 0.02)
		T.expect(firstHit(inst, 26, 0, 3)).toBeNil()
		-- walking out of the circle before it lands
		T.expect(firstHit(inst, 20, 0, 3, nil, function(t: number)
			return 20, t * 16
		end)).toBeNil()
	end)

	T.it("a wave's front passes over a player; its gap and its sides are safe", function()
		local inst = one({ kind = "wave", aim = "target", width = 6, thick = 2, length = 40, speed = 20, delay = 1 })
		local hit = firstHit(inst, 20, 0, 5)
		T.expect(hit ~= nil).toBe(true)
		T.expect(hit :: number).toBeNear(1 + 19 / 20, 0.05)
		T.expect(firstHit(inst, 20, 3.5, 5)).toBeNil()
		T.expect(firstHit(inst, 45, 0, 5)).toBeNil()
		local wall = one({ kind = "wave", aim = "forward", width = 60, thick = 3, length = 50, speed = 10, gap = 10 })
		T.expect(firstHit(wall, 20, wall.gapAt, 8)).toBeNil()
		T.expect(firstHit(wall, 20, wall.gapAt + 12, 8) ~= nil).toBe(true)
	end)

	T.it("a ring grows over a player; jumping clears a low ring, its gaps are safe", function()
		local ring = one({ kind = "ring", aim = "forward", speed = 10, maxRadius = 20, thick = 2, low = true })
		T.expect(firstHit(ring, 10, 0, 4) ~= nil).toBe(true)
		T.expect(firstHit(ring, 10, 0, 4, Hazards.JUMP_CLEAR + 1)).toBeNil()
		T.expect(firstHit(ring, 25, 0, 4)).toBeNil()
		local gapped =
			one({ kind = "ring", aim = "forward", speed = 10, maxRadius = 20, thick = 2, gaps = 2, gapAngle = 40 })
		local g = gapped.gapStart
		T.expect(firstHit(gapped, math.cos(g) * 10, math.sin(g) * 10, 4)).toBeNil()
		T.expect(firstHit(gapped, math.cos(g + math.pi / 2) * 10, math.sin(g + math.pi / 2) * 10, 4) ~= nil).toBe(true)
	end)

	T.it("a sweep hits what its turning cone crosses and nothing behind it", function()
		local sweep = one({ kind = "sweep", aim = "forward", radius = 30, cone = 30, from = -60, to = 60, seconds = 2 })
		local inside = 0
		local behind = 0
		for deg = -55, 55, 10 do
			local a = math.rad(deg)
			if firstHit(sweep, math.cos(a) * 15, math.sin(a) * 15, 4) then
				inside += 1
			end
		end
		for deg = 110, 250, 20 do
			local a = math.rad(deg)
			if firstHit(sweep, math.cos(a) * 15, math.sin(a) * 15, 4) then
				behind += 1
			end
		end
		T.expect(inside).toBe(12)
		T.expect(behind).toBe(0)
		T.expect(firstHit(sweep, 40, 0, 4)).toBeNil()
	end)
end)

T.describe("Hazards expansion (S159)", function()
	T.it("the same cast gives the same instances (server and clients)", function()
		for id, pattern in HazardPatterns.byId do
			local a = Hazards.expand(pattern, cast(77, { { x = 10, y = 0, z = 5 }, { x = -8, y = 0, z = 12 } }, 0.3))
			local b = Hazards.expand(pattern, cast(77, { { x = 10, y = 0, z = 5 }, { x = -8, y = 0, z = 12 } }, 0.3))
			T.expect({ id, #a > 0 }).toEqual({ id, true })
			T.expect({ id, a }).toEqual({ id, b })
		end
	end)

	T.it("fans, spirals and walls have their counts and spacing", function()
		local fan = HazardPatterns.byId.gr_axeFan
		local list = Hazards.expand(fan, cast(3))
		T.expect(#list).toBe(5)
		T.expect(Hazards.wrap(list[5].a - list[1].a)).toBeNear(math.rad(70), 1e-6)
		local spiral = Hazards.expand(HazardPatterns.byId.mv_spiral, cast(3))
		T.expect(#spiral).toBe(3 * 10)
		local walls = Hazards.expand(HazardPatterns.byId.hv_glacierWalls, cast(3))
		T.expect(#walls).toBe(2)
		T.expect(math.abs(Hazards.wrap(walls[1].a - walls[2].a))).toBeNear(math.pi, 1e-6)
	end)

	T.it("a cast's delay is every instance's least warning (a boss attack's windup)", function()
		for _, inst in Hazards.expand(HazardPatterns.byId.mv_soulOrbs, cast(5, nil, 0, 1.1)) do
			T.expect(inst.delay).toBe(1.1)
		end
	end)

	T.it("a player takes at most `hits` hits of a cast, `hitGap` apart", function()
		local p = HazardPatterns.byId.gr_bombs
		T.expect(Hazards.mayHit(p, 0, nil, 1)).toBe(true)
		T.expect(Hazards.mayHit(p, 1, 1, 1.2)).toBe(false)
		T.expect(Hazards.mayHit(p, 1, 1, 1.5)).toBe(true)
		T.expect(Hazards.mayHit(p, 2, 1, 9)).toBe(false)
		T.expect(Hazards.mayHit(HazardPatterns.byId.mv_soulOrbs, 1, 0, 9)).toBe(false)
	end)
end)

-- The fairness rules of the data.
local KINDS = { bolt = true, lob = true, wave = true, ring = true, sweep = true }
local MAX_SPEED = 70 -- studs/s: nothing outruns a reaction

T.describe("Hazard patterns data (S159)", function()
	T.it("every pattern is complete; boss patterns warn >= MIN_WARN, regular shots aim at their target", function()
		for id, pattern in HazardPatterns.byId do
			T.expect({ id, #pattern.emitters > 0, string.match(pattern.color, "^#%x%x%x%x%x%x$") ~= nil })
				.toEqual({ id, true, true })
			for _, e in pattern.emitters do
				T.expect({ id, KINDS[e.kind] == true, (e.speed or 20) <= MAX_SPEED }).toEqual({ id, true, true })
				if pattern.regular then
					T.expect({ id, e.aim, e.kind }).toEqual({ id, "target", "bolt" })
				end
			end
			if not pattern.regular then
				for _, inst in Hazards.expand(pattern, cast(9)) do
					T.expect({ id, inst.delay >= Hazards.MIN_WARN }).toEqual({ id, true })
				end
			end
		end
	end)

	T.it("a standing player in the aim is hit, a player far away never", function()
		for id, pattern in HazardPatterns.byId do
			local c = cast(11, { { x = 14, y = 0, z = 0 } }, 0, nil, { x = 0, z = 0, r = 46 })
			local list = Hazards.expand(pattern, c)
			local near, far = false, false
			for _, inst in list do
				local tx, tz = if inst.kind == "lob" then inst.tx else 14, if inst.kind == "lob" then inst.tz else 0
				if inst.kind == "wave" and inst.gap > 0 then
					tz = inst.gapAt + inst.gap -- a wall: next to its gap
				end
				local aim = function(_: number): (number?, number?)
					return 14, 0
				end
				if firstHit(inst, tx, tz, Hazards.endsBy(inst) + 0.1, nil, nil, c.arena, aim) then
					near = true
				end
				if firstHit(inst, 400, 400, Hazards.endsBy(inst) + 0.1, nil, nil, c.arena, aim) then
					far = true
				end
			end
			T.expect({ id, near, far }).toEqual({ id, true, false })
		end
	end)
end)

T.describe("Hazard patterns look (S159)", function()
	-- S159a: the gestures of the patterns are checked in tests/bossgestures.spec
	T.it("sounds exist in Data/Sfx", function()
		for id, pattern in HazardPatterns.byId do
			for _, key in { pattern.sound, pattern.impactSound } do
				T.expect({ id, key, Sfx.has(key) }).toEqual({ id, key, true })
			end
		end
	end)
end)

-- The share of a Mage's HP at the boss's level one hit of an added / ambient pattern may take (they are dodged in the
-- balance model like the big blows; this keeps a mistake survivable).
local HAZARD_HIT_MAX = 0.45

T.describe("Boss patterns (BossTuning.patterns, S159)", function()
	T.it("every entry names a real boss, attack and pattern; replaced attacks have no mechanic", function()
		for bossId, entry in BossTuning.patterns :: any do
			local boss = Bosses.get(bossId)
			T.expect({ bossId, boss ~= nil }).toEqual({ bossId, true })
			if not boss then
				continue
			end
			local attacks: { [string]: any } = {}
			for _, attack in boss.attacks do
				attacks[attack.id] = attack
			end
			for attackId, patternId in entry.replace or {} do
				local attack = attacks[attackId]
				T.expect({ bossId, attackId, attack ~= nil, HazardPatterns.get(patternId) ~= nil })
					.toEqual({ bossId, attackId, true, true })
				if attack then
					T.expect({ attackId, attack.mechanic, attack.windup >= Hazards.MIN_WARN })
						.toEqual({ attackId, nil, true })
				end
			end
			for attackId, add in entry.add or {} do
				T.expect({ bossId, attackId, attacks[attackId] ~= nil, HazardPatterns.get(add.pattern) ~= nil })
					.toEqual({ bossId, attackId, true, true })
				T.expect({ attackId, add.at == "area" or add.at == "self", add.damage > 0 })
					.toEqual({ attackId, true, true })
			end
			for _, ambient in entry.ambient or {} do
				T.expect({ bossId, ambient.pattern, HazardPatterns.get(ambient.pattern) ~= nil })
					.toEqual({ bossId, ambient.pattern, true })
				T.expect({ ambient.pattern, ambient.every >= 6, ambient.damage > 0, #ambient.phases > 0 })
					.toEqual({ ambient.pattern, true, true, true })
				for _, phase in ambient.phases do
					T.expect({ ambient.pattern, phase >= 1 and phase <= #boss.phases + 1 })
						.toEqual({ ambient.pattern, true })
				end
			end
		end
		for bossId, extra in BossTuning.extra :: any do
			for _, key in { "shield", "far" } do
				local spec = extra[key]
				if spec and spec.pattern then
					T.expect({ bossId, key, HazardPatterns.get(spec.pattern) ~= nil }).toEqual({ bossId, key, true })
				end
			end
		end
	end)

	T.it("every boss has a phase-2 escalation and a flying projectile or wave", function()
		for _, boss in Bosses.all do
			local entry = (BossTuning.patterns :: any)[boss.id]
			T.expect({ boss.id, entry ~= nil }).toEqual({ boss.id, true })
			if not entry then
				continue
			end
			local escalates, flies = false, false
			for _, ambient in entry.ambient or {} do
				if table.find(ambient.phases, 2) then
					escalates = true
				end
			end
			local ids: { string } = {}
			for _, id in entry.replace or {} do
				table.insert(ids, id)
			end
			for _, add in entry.add or {} do
				table.insert(ids, add.pattern)
			end
			for _, ambient in entry.ambient or {} do
				table.insert(ids, ambient.pattern)
			end
			local extra = (BossTuning.extra :: any)[boss.id]
			if extra then
				for _, key in { "shield", "far" } do
					if extra[key] and extra[key].pattern then
						table.insert(ids, extra[key].pattern)
					end
				end
			end
			for _, id in ids do
				for _, e in (HazardPatterns.get(id) :: any).emitters do
					if e.kind == "bolt" then
						flies = true
					end
				end
			end
			-- Morvane's escalation is her shield-wave spiral (phase 2) and the phase-3 spiral
			local shieldPattern = extra and extra.shield and extra.shield.pattern
			T.expect({ boss.id, escalates or shieldPattern ~= nil, flies }).toEqual({ boss.id, true, true })
		end
	end)

	T.it("one hit of an added or ambient pattern stays survivable for a Mage of the boss's level", function()
		local Balance = require("./Balance")
		for _, boss in Bosses.all do
			local entry = (BossTuning.patterns :: any)[boss.id]
			if not entry then
				continue
			end
			local m = Balance.monster(Balance.bossKind(boss), boss.level, "boss")
			local mage = Balance.player("Mage", boss.level)
			local checks: { { any } } = {}
			for _, add in entry.add or {} do
				table.insert(checks, { add.pattern, add.damage })
			end
			for _, ambient in entry.ambient or {} do
				table.insert(checks, { ambient.pattern, ambient.damage })
			end
			for _, c in checks do
				local share = Balance.hit(m, mage, c[2], boss.damageKind, false) / mage.values.maxHp
				T.expect({ boss.id, c[1], share <= HAZARD_HIT_MAX }).toEqual({ boss.id, c[1], true })
			end
		end
	end)
end)

T.describe("Hazards budgets (audit 2026-10-21)", function()
	T.it("monster shots never take the places of boss patterns", function()
		for _, budget in { Hazards.SERVER_BUDGET, Hazards.CLIENT_BUDGET } do
			T.expect(budget.regular > 0 and budget.patterns > 0).toBe(true)
			-- every monster shot place taken: a boss pattern still fits, one more shot does not
			T.expect(Hazards.admit(budget, false, budget.regular, 0)).toBe(true)
			T.expect(Hazards.admit(budget, true, budget.regular, 0)).toBe(false)
			-- a full pattern budget (a runaway) stops patterns only
			T.expect(Hazards.admit(budget, false, 0, budget.patterns)).toBe(false)
			T.expect(Hazards.admit(budget, true, 0, budget.patterns)).toBe(true)
		end
		-- both budgets together hold at least the old shared cap of 400
		T.expect(Hazards.SERVER_BUDGET.regular + Hazards.SERVER_BUDGET.patterns >= 400).toBe(true)
	end)

	T.it("only the monsters' regular shots use the shot budget", function()
		local shots = { mobArrow = true, mobBolt = true, eliteThrow = true, eliteThrowMagic = true }
		for id, pattern in HazardPatterns.byId do
			T.expect({ id, pattern.regular == true }).toEqual({ id, shots[id] == true })
		end
	end)
end)
