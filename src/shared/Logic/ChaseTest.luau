--!strict
-- S162e follow-up (Studio test 2026-10-31): the pure half of the admin chase test /chasetest (src/server/Admin/ChaseRun).
-- A test monster carries a Probe (Entities/Monster counts its paths, stalls, the evade, the way home, aggro and every
-- blow or throw it lands); the runner moves the target along a scripted route around a building, measures the wall
-- presses and the server's heartbeat and turns it all into one compact line with a verdict. Pure: geometry in the flat
-- (x, z) plane, no Roblox types.

local ChaseTest = {}

export type Scenario = "corner" | "perch" | "los" | "load"

ChaseTest.SCENARIOS = { "corner", "perch", "los", "load" } :: { Scenario }

-- One path answer: when it was asked (os.clock), seconds queued, seconds computed, whether a path was found.
export type PathAnswer = { at: number, waited: number, seconds: number, ok: boolean }

ChaseTest.ANSWERS_KEPT = 8

-- What Entities/Monster records on a monster under test (nil on every other monster).
export type Probe = {
	immortal: boolean, -- TakeDamage removes nothing, debuffs do not land (the test's target cannot kill it)
	pathAsks: number, -- paths asked (within the server's budget)
	pathOk: number,
	pathFails: number, -- answers with no way
	pathDenied: number, -- asks the server's budget refused (tried again on a later tick)
	repaths: number, -- new paths after a stall (Pursuit "repath")
	-- Studio 2026-10-31 ("path 19.07s" next to "caught 5.92s" was the first path FOUND, after two answers with no way):
	-- the first ask, the first path found and every answer (the first ANSWERS_KEPT) are kept apart
	firstAskAt: number?, -- os.clock of the first ask
	firstOkAt: number?, -- os.clock of the first path found
	answers: { PathAnswer },
	slowest: number, -- seconds, the slowest answer
	engagedAt: number?, -- os.clock of the last time it started a fight
	evadeAt: number?,
	hpAtEvade: number?,
	hpAfterEvade: number?,
	homeAt: number?, -- os.clock when an evade's way home ended
	homeTeleport: boolean, -- the way home ended with the timeout's teleport
	attack: ((monster: any, target: any, kind: string) -> ())?, -- a blow or a throw leaves now
}

function ChaseTest.newProbe(immortal: boolean): Probe
	return {
		immortal = immortal,
		pathAsks = 0,
		pathOk = 0,
		pathFails = 0,
		pathDenied = 0,
		repaths = 0,
		firstAskAt = nil,
		firstOkAt = nil,
		answers = {},
		slowest = 0,
		engagedAt = nil,
		evadeAt = nil,
		hpAtEvade = nil,
		hpAfterEvade = nil,
		homeAt = nil,
		homeTeleport = false,
		attack = nil,
	}
end

-- Books a path answer on the probe (Entities/Monster, from the path worker's callback).
function ChaseTest.noteAnswer(probe: Probe, at: number, waited: number, seconds: number, ok: boolean)
	if ok then
		probe.pathOk += 1
		local now = at + waited + seconds
		probe.firstOkAt = if probe.firstOkAt then math.min(probe.firstOkAt, now) else now
	else
		probe.pathFails += 1
	end
	probe.slowest = math.max(probe.slowest, seconds)
	if #probe.answers < ChaseTest.ANSWERS_KEPT then
		table.insert(probe.answers, { at = at, waited = waited, seconds = seconds, ok = ok })
	end
end

-- The answers as "o@1.20+0/35" (o found, f no way; @ asked at s from `start`; + s queued; / ms computed), in ask order.
function ChaseTest.answerLine(answers: { PathAnswer }, start: number): string
	local sorted = table.clone(answers)
	table.sort(sorted, function(a, b)
		return a.at < b.at
	end)
	local parts = {}
	for _, answer in sorted do
		table.insert(
			parts,
			string.format(
				"%s@%.2f+%.2f/%d",
				if answer.ok then "o" else "f",
				answer.at - start,
				answer.waited,
				math.floor(answer.seconds * 1000 + 0.5)
			)
		)
	end
	return table.concat(parts, " ")
end

-- A building's footprint: centre, the unit vector of its local x axis (flat) and half sizes along local x and z.
export type Box = { cx: number, cz: number, ux: number, uz: number, hx: number, hz: number }
export type Point = { x: number, z: number }

local function toWorld(box: Box, lx: number, lz: number): Point
	-- local z is the x axis turned a quarter to the left: (-uz, ux)
	return { x = box.cx + box.ux * lx - box.uz * lz, z = box.cz + box.uz * lx + box.ux * lz }
end

local function toLocal(box: Box, x: number, z: number): (number, number)
	local dx, dz = x - box.cx, z - box.cz
	return dx * box.ux + dz * box.uz, -dx * box.uz + dz * box.ux
end

-- The four corners of the footprint grown by `margin`, counter-clockwise from local (+x, +z).
function ChaseTest.ring(box: Box, margin: number): { Point }
	local ex, ez = box.hx + margin, box.hz + margin
	return {
		toWorld(box, ex, ez),
		toWorld(box, -ex, ez),
		toWorld(box, -ex, -ez),
		toWorld(box, ex, -ez),
	}
end

-- The point of the grown footprint's edge nearest to (x, z), and the index of the ring corner that follows it going
-- counter-clockwise.
function ChaseTest.onRing(box: Box, margin: number, x: number, z: number): (Point, number)
	local ex, ez = box.hx + margin, box.hz + margin
	local lx, lz = toLocal(box, x, z)
	lx, lz = math.clamp(lx, -ex, ex), math.clamp(lz, -ez, ez)
	-- push to the nearest edge (a point inside goes out the shortest way)
	local toX, toZ = ex - math.abs(lx), ez - math.abs(lz)
	if toX <= toZ then
		lx = if lx >= 0 then ex else -ex
	else
		lz = if lz >= 0 then ez else -ez
	end
	-- the next corner counter-clockwise: right edge (+x) goes to corner 1 (+x,+z), top (+z) to 2, left to 3, bottom to 4
	local nextCorner
	if lx >= ex and lz < ez then
		nextCorner = 1
	elseif lz >= ez and lx > -ex then
		nextCorner = 2
	elseif lx <= -ex and lz > -ez then
		nextCorner = 3
	else
		nextCorner = 4
	end
	return toWorld(box, lx, lz), nextCorner
end

-- A walk once around the grown footprint from the edge point nearest to (x, z), back to it: 6 points.
function ChaseTest.loop(box: Box, margin: number, x: number, z: number): { Point }
	local start, nextCorner = ChaseTest.onRing(box, margin, x, z)
	local corners = ChaseTest.ring(box, margin)
	local points = { start }
	for i = 0, 3 do
		table.insert(points, corners[(nextCorner - 1 + i) % 4 + 1])
	end
	table.insert(points, start)
	return points
end

-- The edge point straight across the footprint from (x, z) (through the centre), grown by `margin`.
function ChaseTest.across(box: Box, margin: number, x: number, z: number): Point
	local point = ChaseTest.onRing(box, margin, x, z)
	local lx, lz = toLocal(box, point.x, point.z)
	return toWorld(box, -lx, -lz)
end

-- Where a walker at `speed` studs/s is after `t` seconds along `points`, and whether it reached the end.
function ChaseTest.walk(points: { Point }, speed: number, t: number): (Point, boolean)
	local left = math.max(0, speed * t)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if left <= length and length > 0 then
			local share = left / length
			return { x = a.x + (b.x - a.x) * share, z = a.z + (b.z - a.z) * share }, false
		end
		left -= length
	end
	local last = points[#points]
	return { x = last.x, z = last.z }, true
end

-- Consecutive AI ticks pressed against a wall: `run` grows while `pressed`, the longest run is kept.
export type Press = { run: number, max: number, total: number }

function ChaseTest.newPress(): Press
	return { run = 0, max = 0, total = 0 }
end

function ChaseTest.press(state: Press, pressed: boolean)
	if pressed then
		state.run += 1
		state.total += 1
		state.max = math.max(state.max, state.run)
	else
		state.run = 0
	end
end

-- What one run measured (seconds from the start unless said otherwise; nil = never happened).
export type Result = {
	scenario: Scenario,
	monster: string,
	level: number,
	count: number, -- monsters under test
	ranged: boolean,
	askAt: number?, -- the first path asked
	okAt: number?, -- the first path found
	slowest: number, -- ms, the slowest path answer
	answers: string, -- ChaseTest.answerLine
	asks: number,
	ok: number,
	fails: number,
	denied: number,
	repaths: number,
	pressMax: number, -- AI ticks in a row
	pressTotal: number,
	caughtAt: number?, -- first within reach of the target
	evades: number,
	evadeAt: number?,
	hpBefore: number?, -- % of max HP when it evaded
	hpAfter: number?, -- % right after
	homeAt: number?, -- s from the evade to home
	homeTeleport: boolean,
	calmFor: number?, -- s from home to its next fight (nil = none while watched)
	calmWatched: number?, -- s watched after home
	aggressive: boolean, -- would it start a fight by sight with this target at all
	shots: number, -- ranged blows and throws
	blind: number, -- of them without a clear line to the target
	losAt: number?, -- first AI tick with a clear line
	hbMax: number, -- ms, the longest server frame
	hbAt: number?, -- when it was
	hbAfterPath: boolean, -- a path call started in the frame before it
	hbAvg: number, -- ms
	notes: { string },
}

export type Config = { aiTickRate: number, pursuitRepath: number, pursuitEvade: number, evadeCalm: number }

-- The longest acceptable press in AI ticks: a stall is answered with a new path after pursuitRepath (one tick more for
-- the answer). Under a perch there is no way at all: it may press until it evades (pursuitEvade at the latest).
function ChaseTest.pressLimit(cfg: Config, scenario: Scenario?): number
	local seconds = if scenario == "perch" then cfg.pursuitEvade else cfg.pursuitRepath
	return math.ceil(seconds * cfg.aiTickRate) + 1
end

-- Whether the run shows the pursuit working, and why not.
function ChaseTest.verdict(r: Result, cfg: Config): (boolean, { string })
	local fails: { string } = {}
	if r.pressMax > ChaseTest.pressLimit(cfg, r.scenario) then
		table.insert(fails, "pressed")
	end
	if r.scenario == "corner" then
		if r.caughtAt == nil then
			table.insert(fails, "never caught")
		end
		if r.evades > 0 then
			table.insert(fails, "evaded")
		end
	elseif r.scenario == "perch" then
		if r.evadeAt == nil then
			table.insert(fails, "no evade")
		else
			if r.hpAfter == nil or r.hpAfter < 100 then
				table.insert(fails, "hp not restored")
			end
			if r.homeAt == nil then
				table.insert(fails, "not home")
			elseif r.calmFor ~= nil and r.calmFor < cfg.evadeCalm - 0.3 then
				table.insert(fails, "re-aggro early")
			end
		end
	elseif r.scenario == "los" then
		if r.blind > 0 then
			table.insert(fails, "shot blind")
		end
		if r.ranged and r.shots == 0 and r.evades == 0 then
			table.insert(fails, "never shot")
		end
	elseif r.scenario == "load" then
		if r.caughtAt == nil and r.evades == 0 then
			table.insert(fails, "never caught")
		end
	end
	return #fails == 0, fails
end

local function seconds(value: number?): string
	return if value then string.format("%.2fs", value) else "-"
end

-- One line for the server log and the admin's chat.
function ChaseTest.summary(r: Result, cfg: Config): string
	local ok, fails = ChaseTest.verdict(r, cfg)
	local parts = {
		`{r.scenario} {r.monster} L{r.level}` .. (if r.count > 1 then ` x{r.count}` else ""),
		`path ask {seconds(r.askAt)} found {seconds(r.okAt)} asks {r.asks} ok {r.ok} fail {r.fails} denied {r.denied} `
			.. `repath {r.repaths} slowest {math.floor(r.slowest + 0.5)}ms`
			.. (if r.answers ~= "" then ` [{r.answers}]` else ""),
		`press max {r.pressMax}t total {r.pressTotal}t`,
		`caught {seconds(r.caughtAt)}`,
	}
	if r.scenario == "perch" or r.evades > 0 then
		local hp = if r.hpBefore and r.hpAfter
			then string.format(" hp %d%%->%d%%", math.floor(r.hpBefore + 0.5), math.floor(r.hpAfter + 0.5))
			else ""
		table.insert(parts, `evade {seconds(r.evadeAt)} x{r.evades}{hp}`)
		local home = seconds(r.homeAt) .. (if r.homeTeleport then " (teleport)" else "")
		local calm = if r.calmFor
			then seconds(r.calmFor)
			elseif r.calmWatched then `none in {seconds(r.calmWatched)}`
			else "-"
		table.insert(parts, `home {home} re-aggro {calm}` .. (if r.aggressive then "" else " (not aggressive)"))
	end
	if r.scenario == "los" or r.shots > 0 then
		table.insert(parts, `shots {r.shots} blind {r.blind} los {seconds(r.losAt)}`)
	end
	local at = if r.hbAt then string.format(" @%.2fs", r.hbAt) else ""
	local after = if r.hbAfterPath then " after a path call" else ""
	table.insert(
		parts,
		string.format("hb max %dms%s%s avg %dms", math.floor(r.hbMax + 0.5), at, after, math.floor(r.hbAvg + 0.5))
	)
	table.insert(parts, if ok then "PASS" else "FAIL " .. table.concat(fails, ", "))
	for _, note in r.notes do
		table.insert(parts, note)
	end
	return table.concat(parts, " | ")
end

return ChaseTest
