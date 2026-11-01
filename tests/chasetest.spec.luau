--!strict
-- S162e follow-up (Studio test 2026-10-31): the pure half of /chasetest (Logic/ChaseTest): the route around a
-- building, the press counter, the verdicts and the result line.

local fs = require("@lune/fs")

local AdminCommands = require("../src/shared/Data/AdminCommands")
local ChaseTest = require("../src/shared/Logic/ChaseTest")
local Combat = require("../src/shared/Data/Combat")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local cfg = Combat :: any

-- A 20 x 10 building at (100, 50), its local x along world x.
local BOX: ChaseTest.Box = { cx = 100, cz = 50, ux = 1, uz = 0, hx = 10, hz = 5 }
-- The same one turned a quarter: local x along world z.
local TURNED: ChaseTest.Box = { cx = 100, cz = 50, ux = 0, uz = 1, hx = 10, hz = 5 }

-- `drop` = fields left out (a nil in `over` would be no field at all)
local function result(over: { [string]: any }, drop: { string }?): ChaseTest.Result
	local r: { [string]: any } = {
		scenario = "corner",
		monster = "wolf",
		level = 5,
		count = 1,
		ranged = false,
		asks = 2,
		ok = 2,
		fails = 0,
		tight = 0,
		denied = 0,
		repaths = 0,
		pressMax = 0,
		pressTotal = 0,
		caughtAt = 3.2,
		evades = 0,
		homeTeleport = false,
		aggressive = true,
		shots = 0,
		blind = 0,
		slowest = 30,
		answers = "",
		hbMax = 18,
		hbAfterPath = false,
		hbAvg = 16,
		notes = {},
	}
	for key, value in over do
		r[key] = value
	end
	for _, key in drop or {} do
		r[key] = nil
	end
	return r :: any
end

T.describe("ChaseTest route (S162e)", function()
	T.it("grows the footprint into a ring of four corners, counter-clockwise", function()
		local ring = ChaseTest.ring(BOX, 6)
		T.expect(ring[1].x).toBeNear(116)
		T.expect(ring[1].z).toBeNear(61)
		T.expect(ring[2].x).toBeNear(84)
		T.expect(ring[3].z).toBeNear(39)
		T.expect(ring[4].x).toBeNear(116)
		T.expect(ring[4].z).toBeNear(39)
		-- turned: the long side runs along z
		local turned = ChaseTest.ring(TURNED, 0)
		T.expect(math.abs(turned[1].z - 50)).toBeNear(10)
		T.expect(math.abs(turned[1].x - 100)).toBeNear(5)
	end)

	T.it("puts a point on the nearest edge and names the next corner", function()
		local point, nextCorner = ChaseTest.onRing(BOX, 6, 140, 52)
		T.expect(point.x).toBeNear(116)
		T.expect(point.z).toBeNear(52)
		T.expect(nextCorner).toBe(1)
		point, nextCorner = ChaseTest.onRing(BOX, 6, 95, 90)
		T.expect(point.z).toBeNear(61)
		T.expect(nextCorner).toBe(2)
		-- from inside it goes out the shortest way (the long sides are nearer here)
		point = ChaseTest.onRing(BOX, 6, 101, 52)
		T.expect(point.z).toBeNear(61)
	end)

	T.it("walks once around and back to the start, every corner on the ring", function()
		local loop = ChaseTest.loop(BOX, 6, 140, 52)
		T.expect(#loop).toBe(6)
		T.expect(loop[1].x).toBeNear(loop[6].x)
		T.expect(loop[1].z).toBeNear(loop[6].z)
		-- from the right edge up to (+x, +z), then along the top to (-x, +z)
		T.expect(loop[2].x).toBeNear(116)
		T.expect(loop[2].z).toBeNear(61)
		T.expect(loop[3].x).toBeNear(84)
		T.expect(loop[3].z).toBeNear(61)
	end)

	T.it("finds the point straight across the building", function()
		local across = ChaseTest.across(BOX, 6, 140, 52)
		T.expect(across.x).toBeNear(84)
		T.expect(across.z).toBeNear(48)
	end)

	T.it("moves a walker along the route at its speed and stops at the end", function()
		local points = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 } }
		local at, done = ChaseTest.walk(points, 5, 1)
		T.expect(at.x).toBeNear(5)
		T.expect(done).toBe(false)
		at = ChaseTest.walk(points, 5, 3)
		T.expect(at.x).toBeNear(10)
		T.expect(at.z).toBeNear(5)
		at, done = ChaseTest.walk(points, 5, 100)
		T.expect(at.z).toBeNear(10)
		T.expect(done).toBe(true)
	end)
end)

T.describe("ChaseTest measures and verdicts (S162e)", function()
	T.it("counts the longest run of pressed ticks", function()
		local press = ChaseTest.newPress()
		for _, pressed in { true, true, false, true, true, true, false } do
			ChaseTest.press(press, pressed)
		end
		T.expect(press.max).toBe(3)
		T.expect(press.total).toBe(5)
		T.expect(press.run).toBe(0)
	end)

	T.it("a fresh probe has counted nothing and keeps the monster immortal", function()
		local probe = ChaseTest.newProbe(true)
		T.expect(probe.immortal).toBe(true)
		T.expect(probe.pathAsks + probe.pathOk + probe.pathFails + probe.pathDenied + probe.repaths).toBe(0)
		T.expect(probe.evadeAt).toBeNil()
		T.expect(probe.homeTeleport).toBe(false)
	end)

	-- Studio 2026-10-31: "path 19.07s" next to "caught 5.92s" was the first path FOUND after two answers with no way
	T.it("keeps the first ask, the first path found and every answer apart", function()
		local probe = ChaseTest.newProbe(true)
		probe.firstAskAt = 100.2
		ChaseTest.noteAnswer(probe, 100.2, 0, 1.65, false)
		ChaseTest.noteAnswer(probe, 101.9, 0.02, 0.04, false, true)
		ChaseTest.noteAnswer(probe, 119.0, 0, 0.03, true, true)
		T.expect(probe.pathFails).toBe(2)
		T.expect(probe.pathTight).toBe(1) -- a path found is never "tight"
		T.expect(probe.pathOk).toBe(1)
		T.expect(probe.firstOkAt).toBeNear(119.03)
		T.expect(probe.slowest).toBeNear(1.65)
		-- Studio 2026-11-01: t = no way with an end against a part (off the navmesh), f = no way in the open
		T.expect(ChaseTest.answerLine(probe.answers, 100)).toBe("f@0.20+0.00/1650 t@1.90+0.02/40 o@19.00+0.00/30")
		for i = 1, 20 do
			ChaseTest.noteAnswer(probe, 120 + i, 0, 0.01, true)
		end
		T.expect(#probe.answers).toBe(ChaseTest.ANSWERS_KEPT)
		local line = ChaseTest.summary(
			result({ askAt = 0.2, okAt = 19.03, answers = "f@0.20+0.00/1650", hbAt = 0.21, hbAfterPath = true }),
			cfg
		)
		T.expect(string.find(line, "path ask 0.20s found 19.03s", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "fail 0 tight 0 denied", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "@0.21s after a path call", 1, true) ~= nil).toBe(true)
	end)

	T.it("allows a press only as long as the repath takes", function()
		T.expect(ChaseTest.pressLimit(cfg)).toBe(math.ceil(cfg.pursuitRepath * cfg.aiTickRate) + 1)
		local ok = ChaseTest.verdict(result({ pressMax = ChaseTest.pressLimit(cfg) }), cfg)
		T.expect(ok).toBe(true)
		local bad, why = ChaseTest.verdict(result({ pressMax = ChaseTest.pressLimit(cfg) + 1 }), cfg)
		T.expect(bad).toBe(false)
		T.expect(why[1]).toBe("pressed")
		-- under a perch it may press until it evades
		T.expect(ChaseTest.pressLimit(cfg, "perch")).toBe(math.ceil(cfg.pursuitEvade * cfg.aiTickRate) + 1)
		T.expect(ChaseTest.pressLimit(cfg, "perch") > ChaseTest.pressLimit(cfg, "corner")).toBe(true)
	end)

	T.it("corner: caught and never evaded", function()
		T.expect((ChaseTest.verdict(result({}), cfg))).toBe(true)
		T.expect((ChaseTest.verdict(result({}, { "caughtAt" }), cfg))).toBe(false)
		T.expect((ChaseTest.verdict(result({ evades = 1 }), cfg))).toBe(false)
	end)

	T.it("perch: evaded at full HP, home, and calm for evadeCalm", function()
		local good = result({
			scenario = "perch",
			evades = 1,
			evadeAt = 4.1,
			hpBefore = 50,
			hpAfter = 100,
			homeAt = 5,
			calmFor = cfg.evadeCalm + 0.1,
		}, { "caughtAt" })
		T.expect((ChaseTest.verdict(good, cfg))).toBe(true)
		local early = table.clone(good :: any)
		early.calmFor = 2
		T.expect((ChaseTest.verdict(early, cfg))).toBe(false)
		local hurt = table.clone(good :: any)
		hurt.hpAfter = 60
		T.expect((ChaseTest.verdict(hurt, cfg))).toBe(false)
		T.expect((ChaseTest.verdict(result({ scenario = "perch" }, { "caughtAt" }), cfg))).toBe(false)
		-- nobody came near its home while watched: no re-aggro is fine
		local quiet = table.clone(good :: any)
		quiet.calmFor = nil
		quiet.calmWatched = 9
		T.expect((ChaseTest.verdict(quiet, cfg))).toBe(true)
	end)

	T.it("los: no shot without a clear line", function()
		T.expect((ChaseTest.verdict(result({ scenario = "los", ranged = true, shots = 4 }), cfg))).toBe(true)
		T.expect((ChaseTest.verdict(result({ scenario = "los", ranged = true, shots = 4, blind = 1 }), cfg)))
			.toBe(false)
		T.expect((ChaseTest.verdict(result({ scenario = "los", ranged = true }), cfg))).toBe(false)
		T.expect((ChaseTest.verdict(result({ scenario = "los", ranged = true, evades = 1 }), cfg))).toBe(true)
	end)

	T.it("writes one line with the verdict, no long dashes", function()
		local line = ChaseTest.summary(
			result({
				scenario = "perch",
				evades = 1,
				evadeAt = 4.1,
				hpBefore = 50,
				hpAfter = 100,
				homeAt = 5.25,
				calmFor = 6.4,
				askAt = 0.2,
				okAt = 0.4,
			}, { "caughtAt" }),
			cfg
		)
		T.expect(string.find(line, "perch wolf L5", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "hp 50%->100%", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "re-aggro 6.40s", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "PASS", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "\u{2014}", 1, true)).toBeNil()
		local failed = ChaseTest.summary(result({ notes = { "test block" } }, { "caughtAt" }), cfg)
		T.expect(string.find(failed, "FAIL never caught", 1, true) ~= nil).toBe(true)
		T.expect(string.find(failed, "test block", 1, true) ~= nil).toBe(true)
	end)

	T.it("the admin command offers exactly the scenarios", function()
		local def = AdminCommands.get("chasetest")
		T.expect(def ~= nil).toBe(true)
		local scenario = (def :: any).args[2]
		T.expect(table.concat(scenario.options, ",")).toBe(table.concat(ChaseTest.SCENARIOS, ","))
		T.expect(scenario.default).toBe("corner")
	end)

	-- Studio 2026-11-01: started in the city it ran and said "never caught" (monsters fight nobody in a safe zone)
	T.it("refuses to start in a safe zone or on a map that is not built", function()
		local run = fs.readFile("src/server/Admin/ChaseRun.luau")
		local start = string.find(run, "function ChaseRun.Start(", 1, true)
		local safe = string.find(run, 'reply(player, "admin.chasetest.safe"', 1, true)
		local built = string.find(run, 'reply(player, "admin.maps.notBuilt"', 1, true)
		local first = string.find(run, "current = run", 1, true)
		T.expect(start ~= nil and safe ~= nil and built ~= nil and first ~= nil).toBe(true)
		-- both before the run takes the target (god mode, anchoring) or spawns anything
		T.expect(safe > (start :: number) and safe < (first :: number)).toBe(true)
		T.expect(built > (start :: number) and built < (first :: number)).toBe(true)
		T.expect(string.find(run, 'zone.pvp == "green"', 1, true) ~= nil).toBe(true)
		local strings = { (pl :: any)["admin.chasetest.safe"], (en :: any)["admin.chasetest.safe"] }
		for _, text in strings do
			T.expect(type(text)).toBe("string")
			T.expect(string.find(text, "{map}", 1, true) ~= nil).toBe(true)
			T.expect(string.find(text, "/tp meadows", 1, true) ~= nil).toBe(true)
		end
	end)
end)
