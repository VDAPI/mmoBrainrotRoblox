--!strict
-- S162e (Studio test 2026-10-31: one server frame of 1.7 s at a wolf's first path): the monsters' path asks only queue
-- (Logic/PathQueue); Entities/PathWorker starts at most Combat.pathPerFrame engine calls per frame, outside the AI tick.
-- A path that never answers cannot hold the AI loop: the monster decides on and evades by the clock.

local fs = require("@lune/fs")

local Combat = require("../src/shared/Data/Combat")
local PathQueue = require("../src/shared/Logic/PathQueue")
local Pursuit = require("../src/shared/Logic/Pursuit")
local T = require("./Test")

local cfg = Combat :: any
local TICK = 1 / Combat.aiTickRate

T.describe("PathQueue (S162e)", function()
	T.it("keeps one job per monster, oldest first, and forgets dropped ones", function()
		local queue = PathQueue.new()
		T.expect(PathQueue.push(queue, "a", 1)).toBe(false)
		PathQueue.push(queue, "b", 2)
		T.expect(PathQueue.push(queue, "a", 3)).toBe(true) -- a newer ask replaces the waiting one, in its place
		PathQueue.push(queue, "c", 4)
		PathQueue.drop(queue, "b")
		T.expect(PathQueue.size(queue)).toBe(2)
		local first = PathQueue.take(queue, 1)
		T.expect(first[1]).toBe(3)
		T.expect(PathQueue.take(queue, 5)[1]).toBe(4)
		T.expect(PathQueue.size(queue)).toBe(0)
		PathQueue.drop(queue, "nobody") -- harmless
	end)

	T.it("starts at most pathPerFrame engine calls a frame, however many monsters ask at once", function()
		local queue = PathQueue.new()
		for i = 1, 40 do
			PathQueue.push(queue, i, i)
		end
		local most = 0
		for _ = 1, 60 do
			most = math.max(most, #PathQueue.take(queue, Combat.pathPerFrame))
		end
		T.expect(most).toBe(Combat.pathPerFrame)
		T.expect(Combat.pathPerFrame <= 2).toBe(true)
		-- a full second of frames drains more than the server's budget can ask
		T.expect(Combat.pathPerFrame * 60 > cfg.pathPerSecond + cfg.pathBurst).toBe(true)
	end)

	T.it(
		"a path that never answers does not hold the AI loop: 100 monsters tick on and give up by the clock",
		function()
			local queue = PathQueue.new()
			local bucket = Pursuit.newBucket(cfg, 0)
			local engineCalls = 0
			local ticks = 0
			local evaded = 0
			local monsters = {}
			for i = 1, 100 do
				monsters[i] = { pending = false, asked = false, gone = false }
			end
			for frame = 1, 10 * 60 do
				local now = frame / 60
				-- the AI pass (5 per second): only queues, never waits for an answer
				if frame % (60 / Combat.aiTickRate) == 0 then
					for i, m in monsters do
						if not m.gone then
							ticks += 1
							local action = Pursuit.decide({
								stalled = now,
								canHit = false,
								asked = m.asked,
								pending = m.pending,
								noPath = false,
								failStreak = 0,
								mayEvade = true,
							}, cfg)
							if action == "repath" and Pursuit.take(bucket, now, cfg) then
								m.asked, m.pending = true, true
								PathQueue.push(queue, i, i)
							elseif action == "evade" then
								m.gone = true
								evaded += 1
							end
						end
					end
				end
				-- the worker: starts its calls; the engine never answers
				engineCalls += #PathQueue.take(queue, Combat.pathPerFrame)
			end
			T.expect(evaded).toBe(100) -- every one gave up at pursuitEvade although its path never came
			T.expect(ticks >= 100 * cfg.pursuitEvade * Combat.aiTickRate - 100).toBe(true)
			T.expect(engineCalls <= 10 * 60 * Combat.pathPerFrame).toBe(true)
			T.expect(TICK > 0).toBe(true)
		end
	)

	T.it("the AI never calls the engine itself: Monster only queues, PathWorker defers every call", function()
		local monster = fs.readFile("src/server/Entities/Monster.luau")
		T.expect(string.find(monster, "ComputeAsync", 1, true)).toBeNil()
		T.expect(string.find(monster, "CreatePath", 1, true)).toBeNil()
		T.expect(string.find(monster, "PathWorker.request(", 1, true) ~= nil).toBe(true)
		local worker = fs.readFile("src/server/Entities/PathWorker.luau")
		-- the engine call sits in `compute`, which only ever runs deferred (its own thread, never in the caller's)
		T.expect(string.find(worker, "task.defer(compute, job)", 1, true) ~= nil).toBe(true)
		local _, calls = string.gsub(worker, "compute%(", "")
		T.expect(calls).toBe(1) -- the definition only: nobody calls it directly
		T.expect(string.find(worker, "task.wait", 1, true)).toBeNil()
	end)
end)
