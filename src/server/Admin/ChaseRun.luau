--!strict
-- S162e follow-up (Studio test 2026-10-31): the runner of /chasetest <monster|stop> [corner|perch|los|load] [level]
-- (Admin/Monsters). A chase the Studio session can run without mouse input: the admin's character is the target,
-- anchored and moved by the server along a scripted route (no client movement code can hold it; god mode, so it
-- takes no damage), and the test monster carries a Logic/ChaseTest probe (it cannot be hurt and ignores debuffs, so
-- neither the target's auto attack nor anything else kills or slows it). Around the nearest building within SEARCH
-- studs (a grey test block in front of the admin when none stands there):
--   corner: the monster starts across the building from the target, which stands HOLD s, then walks once around it
--           (as far out as leaves room for the monster's path agent: MARGINS);
--   perch : the target stands on the roof, the monster (at half HP) below: it should evade, heal, go home and ignore
--           the target standing next to its home for Combat.evadeCalm s;
--   los   : the monster (a ranged one is the point) across a wall (a thin one, a palisade or a fence, when there is
--           one): no shot without a clear line;
--   load  : LOAD_COUNT monsters across the building, the target walks around it LOAD_LAPS times.
-- The result is one line (Logic/ChaseTest.summary) in the server log ("[ChaseTest] ..."), in the admin's chat and in
-- the Workspace attribute "ChaseTest" ("running ..." while it runs). One run per server; /chasetest stop ends it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local ChaseTest = require(Shared.Logic.ChaseTest)
local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Pursuit = require(Shared.Logic.Pursuit)

local Monsters = require(Shared.Data.Monsters)
local PathWorker = require(script.Parent.Parent.Entities.PathWorker)
local RigBuilder = require(script.Parent.Parent.Entities.RigBuilder)

local Context = require(script.Parent.Context)

local log = Log.new("ChaseTest")
local reply = Context.reply

local MonsterService = Context.services.MonsterService
local ResourceService = Context.services.ResourceService
local PlayerStateService = Context.services.PlayerStateService
local WorldService = Context.services.WorldService
local ZoneService = Context.services.ZoneService

local SEARCH = 90 -- studs around the admin searched for a building
local MAX_SIZE = 60 -- a building's longest side at most (anything longer is a cliff or the map itself)
local MARGIN = 6 -- perch: the target's start distance from the building
-- corner / load: the route's distance from the building's bounds, the widest with room for the monster's path agent
-- all round (Studio 2026-11-01: 6 studs out from the meadows barn's eaves the route ran along the yard fence and outside
-- it, and the monsters started on the fence line; "no way" to and from there is by design)
local MARGINS = { 6, 5, 4, 3, 2 }
local ROOM_STEP = 2 -- studs between the route's points checked for room
local PASS_NAME = "ChaseTestPass" -- the PathfindingModifiers that keep the anchored target out of the navmesh
local WALL_MARGIN = 3 -- los: the target's and the monster's distance from the wall
local HOLD = 4 -- corner / load: seconds the target stands across the building before it walks
local PERCH_WAIT = 15 -- perch: seconds to wait for the evade
local HOME_WAIT = 25 -- perch: seconds to wait for the way home
local CALM_WATCH = Combat.evadeCalm + 3 -- perch: seconds the target stands next to the home after it
local CALM_STEP = 6 -- perch: the target's distance from the monster's home then (inside every aggro range)
local LOS_TIME = 20
local LOAD_COUNT = 5
local LOAD_LAPS = 2
local TAIL = 3 -- seconds watched after the target's walk ends
local PRESS_ADVANCE = 0.3 -- studs towards its walk goal per AI tick below which a monster at a wall is pressing
local ATTRIBUTE = "ChaseTest"

type Found = { box: ChaseTest.Box, instance: Instance, name: string, roof: Vector3? }

type Subject = {
	monster: any,
	probe: ChaseTest.Probe,
	press: ChaseTest.Press,
	lastStep: number,
	lastPos: Vector3,
	caughtAt: number?,
	losAt: number?,
	shots: number,
	blind: number,
}

type Run = {
	player: Player,
	scenario: ChaseTest.Scenario,
	monsterId: string,
	level: number,
	cancelled: boolean,
	subjects: { Subject },
	block: BasePart?,
	wasGod: boolean,
	heartbeat: RBXScriptConnection?,
	measuring: boolean, -- frame times count from the engage on (not the search, not the spawn)
	hbMax: number,
	hbAt: number?, -- s from the start to the longest frame
	hbAfterPath: boolean, -- a path call started in the frame before it
	pathCalls: number, -- PathWorker.stats.started at the last frame
	hbSum: number,
	hbCount: number,
	top: number, -- the last resort start of a ground ray
	groundY: number, -- the ground the target last stood on: ground rays start a little over it (not on a tree crown)
	startedAt: number,
	notes: { string },
	-- perch: seconds from home to the next fight (nil = none while watched), how long it was watched, and whether
	-- the monster starts fights by sight with this target at all
	calm: { calmFor: number?, watched: number, aggressive: boolean }?,
	home: CFrame, -- where the admin stood: put back there at the end (not left on a roof)
}

local current: Run? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true

-- Rays see only the world: no monster, no character (and no `extra`).
local function refreshFilter(extra: Instance?)
	local ignore: { Instance } = {}
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	if extra then
		table.insert(ignore, extra)
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function groundAt(x: number, z: number, top: number): Vector3?
	local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -500, 0), rayParams)
	return if hit then hit.Position else nil
end

-- The terrain under (x, z) when there is some within 200 studs below `fromY` (an admin standing on a roof or a rock
-- still gets the real ground: Studio 2026-10-31 a run started on the barn's roof put its test block in the air), else
-- the first surface.
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
terrainParams.IgnoreWater = true
local function realGround(x: number, z: number, fromY: number): Vector3?
	local hit = Workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -200, 0), terrainParams)
	return if hit then hit.Position else groundAt(x, z, fromY)
end

-- The ground at (x, z) near the run's ground level: a ray from GROUND_UP studs over it (under roofs and tree crowns
-- around), from high above when it starts inside a hill.
local GROUND_UP = 10
local function groundNear(run: Run, x: number, z: number): Vector3?
	return groundAt(x, z, run.groundY + GROUND_UP) or groundAt(x, z, run.top)
end

local function rootOf(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, root, humanoid
end

-- Buildings ----------------------------------------------------------------------------------------------------

-- The building a part belongs to: its highest ancestor model no longer than MAX_SIZE (the part itself without one).
-- `widths` keeps each model's longest side (a search measures every model once).
local function buildingOf(part: BasePart, widths: { [Instance]: number }): Instance
	local best: Instance = part
	local node: Instance? = part.Parent
	while node and node:IsA("Model") do
		local width = widths[node]
		if width == nil then
			local _, size = node:GetBoundingBox()
			width = math.max(size.X, size.Z)
			widths[node] = width
		end
		if (width :: number) > MAX_SIZE then
			break
		end
		best = node
		node = node.Parent
	end
	return best
end

-- Footprint, top and bottom of an upright building (nil when tilted).
local function shapeOf(instance: Instance): (ChaseTest.Box?, number, number)
	local cf: CFrame, size: Vector3
	if instance:IsA("Model") then
		cf, size = instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		cf, size = instance.CFrame, instance.Size
	else
		return nil, 0, 0
	end
	if cf.UpVector.Y < 0.95 then
		return nil, 0, 0
	end
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit
	local up = math.abs(cf.RightVector.Y) * size.X / 2
		+ math.abs(cf.UpVector.Y) * size.Y / 2
		+ math.abs(cf.LookVector.Y) * size.Z / 2
	local box = { cx = cf.Position.X, cz = cf.Position.Z, ux = right.X, uz = right.Z, hx = size.X / 2, hz = size.Z / 2 }
	return box, cf.Position.Y + up, cf.Position.Y - up
end

-- Flat distance from (x, z) to the footprint (0 inside).
local function distanceTo(box: ChaseTest.Box, x: number, z: number): number
	local dx, dz = x - box.cx, z - box.cz
	local lx, lz = dx * box.ux + dz * box.uz, -dx * box.uz + dz * box.ux
	local ox, oz = math.max(math.abs(lx) - box.hx, 0), math.max(math.abs(lz) - box.hz, 0)
	return math.sqrt(ox * ox + oz * oz)
end

-- The nearest building around `origin` of `kind` ("wall": thin and long; "house": both sides 6+ studs); `roof` = it
-- must have a walkable top 5+ studs over the ground (the perch).
local function findBuilding(origin: Vector3, ground: number, kind: string, roof: boolean): Found?
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = rayParams.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	overlap.MaxParts = 4000
	local seen: { [Instance]: boolean } = {}
	local widths: { [Instance]: number } = {}
	local candidates: { { found: Found, distance: number } } = {}
	for _, part in Workspace:GetPartBoundsInRadius(origin, SEARCH, overlap) do
		if part:IsA("Terrain") or not part.Anchored then
			continue
		end
		local building = buildingOf(part, widths)
		if seen[building] then
			continue
		end
		seen[building] = true
		local box, top, bottom = shapeOf(building)
		if not box then
			continue
		end
		local short, long = math.min(box.hx, box.hz) * 2, math.max(box.hx, box.hz) * 2
		local fits = bottom <= ground + 3 and top - ground >= 6 and long <= MAX_SIZE
		if kind == "wall" then
			fits = fits and short <= 4 and long >= 10
		else
			fits = fits and short >= 6
		end
		local distance = distanceTo(box, origin.X, origin.Z)
		if fits and distance > 0 then
			table.insert(candidates, {
				found = { box = box, instance = building, name = building.Name, roof = nil },
				distance = distance,
			})
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for _, candidate in candidates do
		local found = candidate.found
		if not roof then
			return found
		end
		local box = found.box
		local _, top = shapeOf(found.instance)
		local hit =
			Workspace:Raycast(Vector3.new(box.cx, top + 5, box.cz), Vector3.new(0, -(top + 5 - ground), 0), rayParams)
		if
			hit
			and hit.Normal.Y > 0.5
			and hit.Position.Y >= ground + 5
			and (hit.Instance == found.instance or hit.Instance:IsDescendantOf(found.instance))
		then
			found.roof = hit.Position
			return found
		end
	end
	return nil
end

-- A grey test block 24 studs in front of the admin (no building around): a house-sized box, or a wall across the way.
local function makeBlock(run: Run, origin: Vector3, look: Vector3, groundY: number, kind: string): Found
	local size = if kind == "wall" then Vector3.new(24, 10, 1) else Vector3.new(16, 12, 16)
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.1 then flatLook.Unit else Vector3.new(0, 0, -1)
	local at = origin + flatLook * 24
	local under = realGround(at.X, at.Z, groundY + 20)
	local ground = if under then under.Y else groundY
	local block = Instance.new("Part")
	block.Name = "ChaseTestBlock"
	block.Anchored = true
	block.Size = size
	block.Material = Enum.Material.Slate
	block.Color = Color3.fromRGB(120, 120, 120)
	local centre = Vector3.new(at.X, ground + size.Y / 2, at.Z)
	block.CFrame = CFrame.lookAt(centre, centre + flatLook)
	block.Parent = Workspace
	run.block = block
	local box = shapeOf(block)
	return {
		box = box :: ChaseTest.Box,
		instance = block,
		name = block.Name,
		roof = centre + Vector3.new(0, size.Y / 2, 0),
	}
end

-- Target and monsters ------------------------------------------------------------------------------------------

-- Stands the (anchored) target on the ground at (x, z), facing (fx, fz). `y` = a fixed ground height (the roof).
local function placeTarget(run: Run, x: number, z: number, fx: number, fz: number, y: number?): boolean
	local character, root, humanoid = rootOf(run.player)
	if not character or not root or not humanoid then
		return false
	end
	local groundY: number
	if y then
		groundY = y
	else
		local ground = groundNear(run, x, z)
		groundY = if ground then ground.Y else run.groundY
		run.groundY = groundY
	end
	local at = Vector3.new(x, groundY + humanoid.HipHeight + root.Size.Y / 2, z)
	local look = Vector3.new(fx, at.Y, fz)
	character:PivotTo(if (look - at).Magnitude > 0.1 then CFrame.lookAt(at, look) else CFrame.new(at))
	return true
end

local function targetPosition(run: Run): Vector3?
	local _, root = rootOf(run.player)
	return if root then root.Position else nil
end

-- Whether nothing solid stands between the monster's mouth and the target's root (its own check, apart from the
-- monster's: this is what the test holds the monster to).
local function clearLine(monster: any, to: Vector3): boolean
	local root: BasePart = monster.root
	local muzzle = root:FindFirstChild("Muzzle")
	local y = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition.Y else root.Position.Y
	local from = Vector3.new(root.Position.X, y, root.Position.Z)
	return Workspace:Raycast(from, to - from, rayParams) == nil
end

local function spawnSubject(run: Run, x: number, z: number, hpShare: number?): Subject?
	local ground = groundNear(run, x, z)
	local at = if ground then ground else Vector3.new(x, run.groundY, z)
	local monster: any = MonsterService.SpawnAt(run.monsterId, "normal", run.level, CFrame.new(at))
	if not monster then
		return nil
	end
	local probe = ChaseTest.newProbe(true)
	monster.probe = probe
	if hpShare then
		monster.hp = monster.stats.maxHp * hpShare
		monster.model:SetAttribute("Hp", math.ceil(monster.hp))
	end
	local subject: Subject = {
		monster = monster,
		probe = probe,
		press = ChaseTest.newPress(),
		lastStep = monster.lastStep,
		lastPos = monster.root.Position,
		caughtAt = nil,
		losAt = nil,
		shots = 0,
		blind = 0,
	}
	local ranged = monster.def.attack == "ranged"
	probe.attack = function(_, _, kind: string)
		if not ranged and kind ~= "throw" then
			return
		end
		subject.shots += 1
		local to = targetPosition(run)
		if to and not clearLine(monster, to) then
			subject.blind += 1
		end
	end
	table.insert(run.subjects, subject)
	return subject
end

-- One AI tick of a subject (sampled on the frame after it): wall press, first catch, first clear line.
local function sample(run: Run, subject: Subject, now: number)
	local monster = subject.monster
	if monster.lastStep == subject.lastStep or monster.state == "dead" then
		return
	end
	subject.lastStep = monster.lastStep
	local position: Vector3 = monster.root.Position
	local last = subject.lastPos
	subject.lastPos = position
	local to = targetPosition(run)
	if not to then
		return
	end
	-- Studio 2026-10-31: "caught" = its blow or shot really reaches (the height counts), as the monster itself decides
	local reachable = monster:CanReach(to)
	if reachable and subject.caughtAt == nil and monster.state == "chase" then
		subject.caughtAt = now - run.startedAt
	end
	if subject.losAt == nil and monster.state == "chase" and clearLine(monster, to) then
		subject.losAt = now - run.startedAt
	end
	local pressed = false
	local goal: Vector3? = monster.walkGoal
	if monster.state == "chase" and goal and not reachable then
		local way = Vector3.new(goal.X - last.X, 0, goal.Z - last.Z)
		if way.Magnitude > 1 then
			local direction = way.Unit
			local advance = Vector3.new(position.X - last.X, 0, position.Z - last.Z):Dot(direction)
			if advance < PRESS_ADVANCE then
				local hip = monster.humanoid.HipHeight
				local feet = position.Y - monster.root.Size.Y / 2 - hip
				local ahead = direction * (monster.root.Size.Z / 2 + 1.5)
				for _, y in { feet + Pursuit.stepHeight(hip), position.Y } do
					local hit = Workspace:Raycast(Vector3.new(position.X, y, position.Z), ahead, rayParams)
					if hit and hit.Normal.Y < 0.6 then
						pressed = true
						break
					end
				end
			end
		end
	end
	ChaseTest.press(subject.press, pressed)
end

-- Waits `seconds` (or until `done` says so), sampling every subject each frame; `each(t)` runs every frame with the
-- seconds since this wait began. False when the run was cancelled.
local function watch(run: Run, seconds: number, each: ((t: number) -> ())?, done: (() -> boolean)?): boolean
	local began = os.clock()
	while not run.cancelled do
		local now = os.clock()
		local t = now - began
		if t >= seconds or (done and done()) then
			return true
		end
		if each then
			each(t)
		end
		for _, subject in run.subjects do
			sample(run, subject, now)
		end
		if not rootOf(run.player) then
			run.cancelled = true
			table.insert(run.notes, "target left")
		end
		task.wait()
	end
	return false
end

-- Walks the target along `points` at `speed` (then stops), sampling meanwhile.
local function walkRoute(run: Run, points: { ChaseTest.Point }, speed: number): boolean
	local length = 0
	for i = 1, #points - 1 do
		length += math.sqrt((points[i + 1].x - points[i].x) ^ 2 + (points[i + 1].z - points[i].z) ^ 2)
	end
	return watch(run, length / speed + 0.1, function(t)
		local here = ChaseTest.walk(points, speed, t)
		local ahead = ChaseTest.walk(points, speed, t + 0.25)
		placeTarget(run, here.x, here.z, ahead.x, ahead.z)
	end)
end

-- Starts the fight (and the clock and the frame times).
local function engageAll(run: Run)
	run.startedAt = os.clock()
	run.measuring = true
	for _, subject in run.subjects do
		subject.monster:AddThreat(run.player, 1)
	end
end

-- Results ------------------------------------------------------------------------------------------------------

local function collect(run: Run): ChaseTest.Result
	local r: ChaseTest.Result = {
		scenario = run.scenario,
		monster = run.monsterId,
		level = run.level,
		count = #run.subjects,
		ranged = false,
		askAt = nil,
		okAt = nil,
		slowest = 0,
		answers = "",
		asks = 0,
		ok = 0,
		fails = 0,
		tight = 0,
		denied = 0,
		repaths = 0,
		pressMax = 0,
		pressTotal = 0,
		caughtAt = nil,
		evades = 0,
		evadeAt = nil,
		hpBefore = nil,
		hpAfter = nil,
		homeAt = nil,
		homeTeleport = false,
		calmFor = nil,
		calmWatched = nil,
		aggressive = true,
		shots = 0,
		blind = 0,
		losAt = nil,
		hbMax = run.hbMax,
		hbAt = run.hbAt,
		hbAfterPath = run.hbAfterPath,
		hbAvg = if run.hbCount > 0 then run.hbSum / run.hbCount else 0,
		notes = run.notes,
	}
	local function earliest(a: number?, b: number?): number?
		if a == nil then
			return b
		end
		return if b == nil then a else math.min(a, b)
	end
	local first = run.subjects[1]
	if first then
		r.answers = ChaseTest.answerLine(first.probe.answers, run.startedAt) -- the first monster's (a group's would not fit)
	end
	for _, subject in run.subjects do
		local probe = subject.probe
		local monster = subject.monster
		r.ranged = r.ranged or monster.def.attack == "ranged"
		r.asks += probe.pathAsks
		r.ok += probe.pathOk
		r.fails += probe.pathFails
		r.tight += probe.pathTight
		r.denied += probe.pathDenied
		r.repaths += probe.repaths
		r.pressMax = math.max(r.pressMax, subject.press.max)
		r.pressTotal += subject.press.total
		r.askAt = earliest(r.askAt, if probe.firstAskAt then probe.firstAskAt - run.startedAt else nil)
		r.okAt = earliest(r.okAt, if probe.firstOkAt then probe.firstOkAt - run.startedAt else nil)
		r.slowest = math.max(r.slowest, probe.slowest * 1000)
		r.caughtAt = earliest(r.caughtAt, subject.caughtAt)
		r.losAt = earliest(r.losAt, subject.losAt)
		r.shots += subject.shots
		r.blind += subject.blind
		local evadeAt = probe.evadeAt
		if evadeAt then
			r.evades += 1
			if r.evadeAt == nil then
				r.evadeAt = evadeAt - run.startedAt
				local max = monster.stats.maxHp
				r.hpBefore = if probe.hpAtEvade then probe.hpAtEvade / max * 100 else nil
				r.hpAfter = if probe.hpAfterEvade then probe.hpAfterEvade / max * 100 else nil
				r.homeAt = if probe.homeAt then probe.homeAt - evadeAt else nil
				r.homeTeleport = probe.homeTeleport
			end
		end
	end
	return r
end

local function finish(run: Run, line: string?)
	if run.heartbeat then
		run.heartbeat:Disconnect()
		run.heartbeat = nil
	end
	for _, subject in run.subjects do
		local monster = subject.monster
		if monster.state ~= "dead" then
			pcall(MonsterService.Despawn, monster)
		end
	end
	if run.block then
		run.block:Destroy()
		run.block = nil
	end
	local character, root = rootOf(run.player)
	if character and root then
		character:PivotTo(run.home)
		root.Anchored = false
		for _, pass in character:GetDescendants() do
			if pass:IsA("PathfindingModifier") and pass.Name == PASS_NAME then
				pass:Destroy()
			end
		end
	end
	if run.player.Parent then
		ResourceService.SetGod(run.player, run.wasGod)
	end
	if current == run then
		current = nil
	end
	local text = line or `{run.scenario} {run.monsterId} | stopped`
	log:info("%s", text)
	Workspace:SetAttribute(ATTRIBUTE, text)
	if run.player.Parent then
		reply(run.player, "admin.chasetest.result", { line = text })
	end
end

-- Scenarios ----------------------------------------------------------------------------------------------------

local function chaseSpeed(subject: Subject): number
	return math.clamp(subject.monster.humanoid.WalkSpeed * 0.8, 6, 14)
end

-- Where `count` monsters start across the building from the target's start (a group spreads along the edge).
local function starts(box: ChaseTest.Box, margin: number, origin: Vector3, count: number): { ChaseTest.Point }
	local start = ChaseTest.onRing(box, margin, origin.X, origin.Z)
	local across = ChaseTest.across(box, margin, origin.X, origin.Z)
	local tx, tz = start.x - box.cx, start.z - box.cz
	local side = Vector3.new(-tz, 0, tx)
	side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(1, 0, 0)
	local points: { ChaseTest.Point } = {}
	for i = 1, count do
		local shift = (i - (count + 1) / 2) * 4
		table.insert(points, { x = across.x + side.X * shift, z = across.z + side.Z * shift })
	end
	return points
end

-- The path agent radius of the monster under test (Logic/Pursuit.agent of its normal body).
local function agentRadius(monsterId: string): number
	local def = Monsters.get(monsterId)
	if not def then
		return Pursuit.RADII[1]
	end
	local body = RigBuilder.body(def.id, "normal", def.size, if def.region > 0 then def.region else nil)
	local size = body.rootSize
	return (Pursuit.agent(size.X, size.Y, size.Z, body.hipHeight))
end

-- Route points (each ROOM_STEP studs along the loop, and the monsters' starts) with a part within the agent's radius
-- (Entities/PathWorker.tight: off the navmesh, no path to or from there).
local function tightPoints(run: Run, loop: { ChaseTest.Point }, extra: { ChaseTest.Point }, radius: number): number
	refreshFilter()
	local ignore = rayParams.FilterDescendantsInstances
	local points: { ChaseTest.Point } = table.clone(extra)
	for i = 1, #loop - 1 do
		local a, b = loop[i], loop[i + 1]
		local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local steps = math.max(1, math.ceil(length / ROOM_STEP))
		for k = 0, steps - 1 do
			local t = k / steps
			table.insert(points, { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t })
		end
	end
	local tight = 0
	for _, point in points do
		local ground = groundNear(run, point.x, point.z)
		if ground and PathWorker.tight(ground, radius, ignore) then
			tight += 1
		end
	end
	return tight
end

-- The widest of MARGINS whose route and starts all have room for the agent; with none, the one with the fewest
-- tight points (and a note in the result).
local function routeMargin(run: Run, box: ChaseTest.Box, origin: Vector3, count: number): number
	local radius = agentRadius(run.monsterId)
	local best, fewest = MARGINS[1], math.huge
	for _, margin in MARGINS do
		local tight = tightPoints(
			run,
			ChaseTest.loop(box, margin, origin.X, origin.Z),
			starts(box, margin, origin, count),
			radius
		)
		if tight == 0 then
			if margin ~= MARGINS[1] then
				table.insert(run.notes, `margin {margin}`)
			end
			return margin
		end
		if tight < fewest then
			best, fewest = margin, tight
		end
	end
	table.insert(run.notes, `route tight at {fewest} points (margin {best}, agent radius {radius})`)
	return best
end

local function corner(run: Run, found: Found, origin: Vector3, count: number, laps: number)
	local box = found.box
	local margin = routeMargin(run, box, origin, count)
	local loop = ChaseTest.loop(box, margin, origin.X, origin.Z)
	local start = loop[1]
	placeTarget(run, start.x, start.z, box.cx, box.cz)
	for _, point in starts(box, margin, origin, count) do
		if not spawnSubject(run, point.x, point.z) then
			table.insert(run.notes, "spawn failed")
			return
		end
	end
	engageAll(run)
	if not watch(run, HOLD) then
		return
	end
	local route: { ChaseTest.Point } = {}
	for lap = 1, laps do
		for i, point in loop do
			if lap == 1 or i > 1 then
				table.insert(route, point)
			end
		end
	end
	if not walkRoute(run, route, chaseSpeed(run.subjects[1])) then
		return
	end
	watch(run, TAIL)
end

local function perch(run: Run, found: Found, origin: Vector3)
	local box = found.box
	local roof = found.roof :: Vector3
	local start = ChaseTest.onRing(box, MARGIN, origin.X, origin.Z)
	placeTarget(run, roof.X, roof.Z, start.x, start.z, roof.Y)
	if math.min(box.hx, box.hz) < 6 then
		table.insert(run.notes, "small roof: a melee blow may reach it")
	end
	local subject = spawnSubject(run, start.x, start.z, 0.5)
	if not subject then
		table.insert(run.notes, "spawn failed")
		return
	end
	local monster = subject.monster
	local probe = subject.probe
	engageAll(run)
	if not watch(run, PERCH_WAIT, nil, function()
		return probe.evadeAt ~= nil
	end) then
		return
	end
	if not probe.evadeAt then
		return
	end
	if not watch(run, HOME_WAIT, nil, function()
		return probe.homeAt ~= nil
	end) then
		return
	end
	local homeAt = probe.homeAt
	if not homeAt then
		return
	end
	-- next to its home, on the ground: it should not start a fight by sight for Combat.evadeCalm seconds
	local home: Vector3 = monster.spawnCFrame.Position
	local out = Vector3.new(home.X - box.cx, 0, home.Z - box.cz)
	out = if out.Magnitude > 0.1 then out.Unit else Vector3.new(1, 0, 0)
	local spot = home + out * CALM_STEP
	run.groundY = home.Y
	placeTarget(run, spot.X, spot.Z, home.X, home.Z)
	local character = PlayerStateService.GetCharacter(run.player)
	local aggressive = not monster.def.passive
		and MonsterStats.isAggressiveTowards(monster.stats.level, if character then character.level else 1)
	local engagedBefore = probe.engagedAt
	local watched = os.clock()
	watch(run, CALM_WATCH, nil, function()
		return probe.engagedAt ~= engagedBefore
	end)
	local engaged = probe.engagedAt
	run.calm = {
		calmFor = if engaged and engaged ~= engagedBefore then engaged - homeAt else nil,
		watched = os.clock() - watched,
		aggressive = aggressive,
	}
end

local function los(run: Run, found: Found, origin: Vector3)
	local box = found.box
	local start = ChaseTest.onRing(box, WALL_MARGIN, origin.X, origin.Z)
	local across = ChaseTest.across(box, WALL_MARGIN, origin.X, origin.Z)
	placeTarget(run, start.x, start.z, across.x, across.z)
	if not spawnSubject(run, across.x, across.z) then
		table.insert(run.notes, "spawn failed")
		return
	end
	if run.subjects[1].monster.def.attack ~= "ranged" then
		table.insert(run.notes, "melee monster: blows need no line")
	end
	engageAll(run)
	watch(run, LOS_TIME)
end

-- API ----------------------------------------------------------------------------------------------------------

local ChaseRun = {}

function ChaseRun.Stop(player: Player)
	local run = current
	if not run then
		reply(player, "admin.chasetest.none")
		return
	end
	run.cancelled = true
	reply(player, "admin.chasetest.stopped")
end

function ChaseRun.Start(player: Player, monsterId: string, scenario: string, level: number?)
	if current then
		reply(player, "admin.chasetest.busy")
		return
	end
	local character, root, humanoid = rootOf(player)
	local data = PlayerStateService.GetCharacter(player)
	if not character or not root or not humanoid or not data then
		reply(player, "admin.needCharacter")
		return
	end
	-- Studio 2026-11-01: started in the city it ran on and said "never caught": monsters fight nobody in a safe zone,
	-- and a map that is not built has no buildings, ground or navmesh to test against
	local zone = ZoneService.ZoneAt(root.Position, Config.StartingMap)
	if zone.pvp == "green" then
		reply(player, "admin.chasetest.safe", { map = zone.map })
		return
	end
	if not WorldService.IsBuilt(zone.map) then
		reply(player, "admin.maps.notBuilt", { map = zone.map })
		return
	end
	refreshFilter()
	local origin = root.Position
	local ground = realGround(origin.X, origin.Z, origin.Y + 2)
	local groundY = if ground then ground.Y else origin.Y - 3
	local run: Run = {
		player = player,
		scenario = scenario :: ChaseTest.Scenario,
		monsterId = monsterId,
		level = math.clamp(level or data.level, 1, Config.MaxLevel),
		cancelled = false,
		subjects = {},
		block = nil,
		wasGod = ResourceService.IsGod(player),
		heartbeat = nil,
		measuring = false,
		hbMax = 0,
		hbAt = nil,
		hbAfterPath = false,
		pathCalls = PathWorker.stats.started,
		hbSum = 0,
		hbCount = 0,
		top = root.Position.Y + 150,
		groundY = groundY,
		startedAt = os.clock(),
		notes = {},
		calm = nil,
		home = root.CFrame,
	}
	current = run
	-- the target: immortal and held by the server (the clients' movement code cannot stop or move it). Anchored, its
	-- body would be still geometry to the navmesh, a hole round the paths' end (Studio 2026-11-01): PassThrough
	-- modifiers keep it out, as a door is kept out
	ResourceService.SetGod(player, true)
	root.Anchored = true
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			local pass = Instance.new("PathfindingModifier")
			pass.Name = PASS_NAME
			pass.PassThrough = true
			pass.Parent = part
		end
	end
	run.heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		-- a path call started since the last frame (its engine work, if any, is in this frame's time)
		local calls = PathWorker.stats.started
		local afterPath = calls ~= run.pathCalls
		run.pathCalls = calls
		if not run.measuring then
			return
		end
		local ms = dt * 1000
		if ms > run.hbMax then
			run.hbAt = os.clock() - run.startedAt
			run.hbAfterPath = afterPath
		end
		run.hbMax = math.max(run.hbMax, ms)
		run.hbSum += ms
		run.hbCount += 1
	end)
	local leaving = Players.PlayerRemoving:Connect(function(who: Player)
		if who == player then
			run.cancelled = true
		end
	end)
	Workspace:SetAttribute(ATTRIBUTE, `running {scenario} {monsterId}`)
	task.spawn(function()
		local ok, err = pcall(function()
			local kind = if scenario == "los" then "wall" else "house"
			local found = findBuilding(origin, groundY, kind, scenario == "perch")
			if not found and scenario == "los" then
				found = findBuilding(origin, groundY, "house", false)
			end
			if not found then
				found = makeBlock(run, origin, root.CFrame.LookVector, groundY, kind)
				table.insert(run.notes, "test block")
				refreshFilter()
				task.wait(2) -- the navmesh learns the new block
			end
			local spot = found :: Found
			reply(player, "admin.chasetest.start", {
				scenario = scenario,
				monster = monsterId,
				level = run.level,
				spot = spot.name,
			})
			if scenario == "corner" then
				corner(run, spot, origin, 1, 1)
			elseif scenario == "perch" then
				perch(run, spot, origin)
			elseif scenario == "los" then
				los(run, spot, origin)
			else
				corner(run, spot, origin, LOAD_COUNT, LOAD_LAPS)
			end
		end)
		leaving:Disconnect()
		if not ok then
			table.insert(run.notes, `error: {err}`)
			log:warn("chase test failed: %s", tostring(err))
		end
		if #run.subjects > 0 and run.subjects[1].probe.engagedAt == nil then
			table.insert(run.notes, "never engaged (a safe zone, or not a valid target)")
		end
		local result = collect(run)
		local calm = run.calm
		if calm then
			result.calmFor = calm.calmFor
			result.calmWatched = calm.watched
			result.aggressive = calm.aggressive
		end
		if run.cancelled then
			table.insert(result.notes, "cancelled")
		end
		finish(run, ChaseTest.summary(result, Combat :: any))
	end)
end

return ChaseRun
