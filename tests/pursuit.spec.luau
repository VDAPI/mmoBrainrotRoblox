--!strict
-- S162e (owner's tester 2026-10-31: monsters stuck on obstacles were cheesed): progress, repath and evade of a chasing
-- monster (Logic/Pursuit).

local Anatomy = require("../src/shared/Logic/Anatomy")
local Combat = require("../src/shared/Data/Combat")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local Pursuit = require("../src/shared/Logic/Pursuit")
local T = require("./Test")

local cfg = Combat :: any
local TICK = 1 / Combat.aiTickRate

local function situation(over: { [string]: any }?): Pursuit.Situation
	local s: { [string]: any } = {
		stalled = 0,
		canHit = false,
		asked = false,
		pending = false,
		noPath = false,
		failStreak = 0,
		mayEvade = true,
	}
	for key, value in over or {} do
		s[key] = value
	end
	return s :: any
end

-- Runs a chase tick by tick: `step(i)` returns the flat move (dx, dz) of tick i while the goal stays `goalX` studs
-- ahead on +x; the monster asks for a path when told to (the answer comes `answerAfter` ticks later, with `noPath`).
-- Returns the seconds of the first "repath" and the first "evade" (nil = never).
local function run(
	ticks: number,
	step: (i: number) -> (number, number),
	answer: { after: number, noPath: boolean }?
): (number?, number?)
	local x, z = 0, 0
	local acc, progressAt = 0, 0
	local askedAt: number? = nil
	local failedAt: number? = nil
	local repathAt, evadeAt = nil, nil
	for i = 1, ticks do
		local now = i * TICK
		local dx, dz = step(i)
		local advance = Pursuit.advance(x, z, x + dx, z + dz, x + 50, z)
		x, z = x + dx, z + dz
		local progressed
		acc, progressed = Pursuit.track(acc, advance, cfg)
		if progressed then
			progressAt = now
		end
		if askedAt and answer and failedAt == nil and now >= askedAt + answer.after * TICK and answer.noPath then
			failedAt = now
		end
		local pending = askedAt ~= nil and answer ~= nil and now < askedAt + answer.after * TICK
		local action = Pursuit.decide({
			stalled = now - progressAt,
			canHit = false,
			asked = askedAt ~= nil and askedAt > progressAt,
			pending = pending,
			noPath = failedAt ~= nil and failedAt > progressAt,
			failStreak = 0,
			mayEvade = true,
		}, cfg)
		if action == "repath" and repathAt == nil then
			repathAt = now
			askedAt = now
		elseif action == "evade" then
			evadeAt = now
			break
		end
	end
	return repathAt, evadeAt
end

T.describe("Pursuit (S162e)", function()
	T.it("counts only the studs walked towards the goal", function()
		T.expect(Pursuit.advance(0, 0, 3, 0, 10, 0)).toBeNear(3)
		T.expect(Pursuit.advance(0, 0, 0, 3, 10, 0)).toBeNear(0) -- sliding along a wall across the way
		T.expect(Pursuit.advance(0, 0, -2, 0, 10, 0)).toBeNear(-2) -- pushed back
		T.expect(Pursuit.advance(0, 0, 3, 4, 10, 0)).toBeNear(3)
		T.expect(Pursuit.advance(5, 5, 6, 6, 5, 5)).toBe(0) -- standing on the goal
	end)

	T.it("books progress once pursuitProgress studs are gained; jittering gains nothing", function()
		local acc, progressed = Pursuit.track(0, cfg.pursuitProgress - 0.1, cfg)
		T.expect(progressed).toBe(false)
		acc, progressed = Pursuit.track(acc, 0.2, cfg)
		T.expect(progressed).toBe(true)
		T.expect(acc).toBe(0)
		local sum = 0
		for i = 1, 100 do
			local hit
			sum, hit = Pursuit.track(sum, if i % 2 == 0 then 0.8 else -0.8, cfg)
			T.expect(hit).toBe(false)
		end
		-- a long step back is forgotten soon (never below -pursuitProgress)
		T.expect((Pursuit.track(0, -40, cfg))).toBe(-cfg.pursuitProgress)
	end)

	T.it("chases on while it can hit, whatever the stall, and bosses never evade", function()
		T.expect(Pursuit.decide(situation({ stalled = 60, canHit = true, noPath = true }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ stalled = 60, noPath = true, mayEvade = false, asked = true }), cfg))
			.toBe("chase")
		T.expect(Pursuit.decide(situation({ stalled = 60, mayEvade = false }), cfg)).toBe("repath")
	end)

	T.it("asks for a new path after pursuitRepath s, evades on no path or after pursuitEvade s", function()
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath - 0.05 }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath }), cfg)).toBe("repath")
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath, asked = true }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath, pending = true }), cfg)).toBe("chase")
		-- no path found: it does not stand there taking hits
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath - 0.05, noPath = true }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitRepath, noPath = true }), cfg)).toBe("evade")
		-- a path that does not help either
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitEvade, asked = true }), cfg)).toBe("evade")
		T.expect(Pursuit.decide(situation({ stalled = cfg.pursuitEvade, pending = true }), cfg)).toBe("evade")
	end)

	T.it("never stalls chasing a kiting target across open ground (S22: running away does not win)", function()
		local speed = 13 * TICK -- the usual chase speed, the target as fast
		local repathAt, evadeAt = run(30 * Combat.aiTickRate, function()
			return speed, 0
		end)
		T.expect(repathAt).toBeNil()
		T.expect(evadeAt).toBeNil()
		-- slowed to 30 % it still gains a step's worth well within the repath time
		local slowRepath, slowEvade = run(30 * Combat.aiTickRate, function()
			return speed * 0.3, 0
		end)
		T.expect(slowRepath).toBeNil()
		T.expect(slowEvade).toBeNil()
	end)

	T.it("pressed against a wall (sliding, jittering): a new path within ~2 s, an evade by pursuitEvade", function()
		local function jitter(i: number): (number, number)
			return if i % 2 == 0 then 0.4 else -0.4, if i % 4 < 2 then 1.2 else -1.2
		end
		local repathAt, evadeAt = run(20 * Combat.aiTickRate, jitter, { after = 2, noPath = false })
		T.expect(repathAt).toBeBetween(cfg.pursuitRepath, 2.05)
		T.expect(evadeAt).toBeBetween(cfg.pursuitEvade, cfg.pursuitEvade + TICK + 1e-6)
		-- no path at all: the evade comes right with the answer
		local _, noWay = run(20 * Combat.aiTickRate, jitter, { after = 2, noPath = true })
		T.expect(noWay).toBeBetween(cfg.pursuitRepath, 2.05 + 3 * TICK)
	end)

	T.it("a path around the obstacle is progress (it walks towards the path's points)", function()
		local repathAt, evadeAt = run(20 * Combat.aiTickRate, function(i)
			-- first stuck 2 s, then the path leads sideways and on: walking to each point counts
			if i <= 10 then
				return 0, 0
			end
			return 13 * TICK, 0
		end, { after = 2, noPath = false })
		T.expect(repathAt).toBeBetween(cfg.pursuitRepath, 2.05)
		T.expect(evadeAt).toBeNil()
	end)

	T.it("keeps the stall rules inside the owner's 1.5-2 s and before the old 5 s stuck rule", function()
		T.expect(cfg.pursuitRepath).toBeBetween(1.5, 2)
		T.expect(cfg.pursuitEvade > cfg.pursuitRepath).toBe(true)
		T.expect(cfg.pursuitEvade < 5).toBe(true)
		T.expect(cfg.returnTimeout > cfg.pursuitEvade).toBe(true)
		-- a chasing monster at 13 studs/s gains pursuitProgress in well under a second
		T.expect(cfg.pursuitProgress / 13 < cfg.pursuitRepath / 2).toBe(true)
	end)

	T.it("budgets paths for the whole server (no per-frame pathfinding)", function()
		local bucket = Pursuit.newBucket(cfg, 0)
		local granted = 0
		-- 100 monsters asking on every tick for 10 s
		for i = 1, 10 * Combat.aiTickRate do
			for _ = 1, 100 do
				if Pursuit.take(bucket, i * TICK, cfg) then
					granted += 1
				end
			end
		end
		T.expect(granted <= cfg.pathBurst + 10 * cfg.pathPerSecond).toBe(true)
		T.expect(granted >= 10 * cfg.pathPerSecond - 1).toBe(true)
		-- a quiet server saves at most pathBurst
		local idle = Pursuit.newBucket(cfg, 0)
		local burst = 0
		while Pursuit.take(idle, 1000, cfg) do
			burst += 1
		end
		T.expect(burst).toBe(cfg.pathBurst)
		T.expect(cfg.pathGap >= 1).toBe(true)
	end)

	T.it("rounds a body up to a few agent sizes", function()
		-- a small body gets Roblox's default agent (2 x 5): no navmesh of its own to build (Studio 2026-10-31)
		local radius, height = Pursuit.agent(1.5, 1.8, 1, 1.9)
		T.expect(radius).toBe(2)
		T.expect(height).toBe(5)
		radius, height = Pursuit.agent(4, 3, 6, 4.5)
		T.expect(radius).toBe(3)
		T.expect(height).toBe(9)
		radius, height = Pursuit.agent(30, 30, 30, 30)
		T.expect(radius).toBe(Pursuit.RADII[#Pursuit.RADII])
		T.expect(height).toBe(Pursuit.HEIGHTS[#Pursuit.HEIGHTS])
	end)

	-- Studio 2026-11-01 (most path asks around the meadows barn found no way): the radius came from the body's length,
	-- so a 1.7 studs wide ice wolf got 4 and needed an 8 studs wide way (a barn 6-7 studs from a fence: no path)
	T.it("sizes the agent by the body's width, not its length", function()
		-- a long, narrow body walks lengthwise: Roblox's default agent
		T.expect((Pursuit.agent(1.7, 1.5, 3.2, 1.2))).toBe(2) -- ice wolf
		T.expect((Pursuit.agent(1.5, 1.1, 3.2, 0.4))).toBe(2) -- salamander
		T.expect((Pursuit.agent(3.6, 3, 5.2, 1.6))).toBe(3) -- bear
		-- every monster 3 studs wide or less (the wolves, boars, goblins, bandits) is a 2 studs agent
		local checked = 0
		for id, def in Monsters.byId do
			local region = if (def.region or 0) > 0 then def.region else nil
			local look = MonsterLooks.get(id, region)
			local size: { number }? = nil
			local hip = 0
			if look and look.asset then
				local k = def.size * (look.asset.scale or 1)
				size = { look.asset.rootSize[1] * k, look.asset.rootSize[2] * k, look.asset.rootSize[3] * k }
				hip = math.max(0.1, look.asset.hipHeight * k)
			else
				local ok, rig = pcall(Anatomy.build, (look or MonsterLooks.get("bandit")) :: any, {
					id = id,
					variant = "normal",
					scale = def.size,
				})
				if ok then
					size = { rig.root.size[1], rig.root.size[2], rig.root.size[3] }
					hip = rig.hipHeight
				end
			end
			if size then
				local radius = Pursuit.agent(size[1], size[2], size[3], hip)
				T.expect(radius >= size[1] / 2).toBe(true)
				if size[1] <= 3 then
					T.expect(radius).toBe(2)
				end
				checked += 1
			end
		end
		T.expect(checked >= 40).toBe(true)
	end)

	T.it("walks over what lies below its root (step height from the hip height)", function()
		T.expect(Pursuit.stepHeight(0.1)).toBe(Pursuit.STEP_MIN)
		T.expect(Pursuit.stepHeight(2)).toBeNear(1.6)
		T.expect(Pursuit.stepHeight(4.5) < 4.5).toBe(true)
	end)

	-- Studio test 2026-10-31: a wolf under a target on a 34 studs high block counted as in reach (flat distance 4), never
	-- gave up and its blows landed through the air
	T.it("a melee blow reaches only so high: roofs, rocks and ledges 3+ studs up are out of a wolf's reach", function()
		local wolf = 3.5 -- feet to the top of its root
		T.expect(Pursuit.meleeReaches(0, wolf, cfg)).toBe(true)
		T.expect(Pursuit.meleeReaches(cfg.meleeUp - 0.1, wolf, cfg)).toBe(true)
		T.expect(Pursuit.meleeReaches(3, wolf, cfg)).toBe(false)
		T.expect(Pursuit.meleeReaches(6, wolf, cfg)).toBe(false)
		T.expect(Pursuit.meleeReaches(34, wolf, cfg)).toBe(false)
		-- below it: a short drop is fine, a cliff is not
		T.expect(Pursuit.meleeReaches(-cfg.meleeDown + 0.1, wolf, cfg)).toBe(true)
		T.expect(Pursuit.meleeReaches(-cfg.meleeDown - 1, wolf, cfg)).toBe(false)
		-- a tall body reaches half its height up
		T.expect(Pursuit.meleeReaches(5, 12, cfg)).toBe(true)
		T.expect(Pursuit.meleeReaches(7, 12, cfg)).toBe(false)
		T.expect(cfg.meleeUp < 3).toBe(true)
	end)

	T.it("path answers with no way in a row make it evade, unless it can hit or is a boss", function()
		T.expect(Pursuit.decide(situation({ failStreak = cfg.pathFailEvade }), cfg)).toBe("evade")
		T.expect(Pursuit.decide(situation({ failStreak = cfg.pathFailEvade - 1 }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ failStreak = cfg.pathFailEvade, canHit = true }), cfg)).toBe("chase")
		T.expect(Pursuit.decide(situation({ failStreak = 10, mayEvade = false }), cfg)).toBe("chase")
	end)

	T.it("under a perched target (cannot hit, no way up) it evades in about 2 s, not never", function()
		-- it stands under the target: no progress; every answer is "no way"
		local stalledAt, evadeAt = 0, nil
		local asked, failedAt, streak = nil :: number?, nil :: number?, 0
		for i = 1, 30 * Combat.aiTickRate do
			local now = i * TICK
			if asked and failedAt == nil and now >= asked + 2 * TICK then
				failedAt = now
				streak += 1
			end
			local action = Pursuit.decide({
				stalled = now - stalledAt,
				canHit = false,
				asked = asked ~= nil,
				pending = asked ~= nil and failedAt == nil,
				noPath = failedAt ~= nil,
				failStreak = streak,
				mayEvade = true,
			}, cfg)
			if action == "repath" then
				asked = now
			elseif action == "evade" then
				evadeAt = now
				break
			end
		end
		T.expect(evadeAt).toBeBetween(cfg.pursuitRepath, cfg.pursuitRepath + 3 * TICK + 1e-6)
	end)
end)
