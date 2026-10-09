--!strict
-- The guide (S25, DESIGN §23): one navigation target at a time (UI/NavTarget). "Guide" draws a path on the
-- ground to it and keeps the HUD bar up to date; "Walk" makes the character follow that path by itself (same
-- map only), like a click on the map in Margonem. A target on another map leads to the next portal on the route
-- (Logic/MapRoute) and recomputes itself after the teleport.
--   * Path: PathfindingService on the client (agent from the character), simplified by Logic/NavPath. The
--     client only knows the streamed world, so a far goal gets a partial path of at most Config.Nav.pathRange
--     studs towards it. Recomputed at the start, when the goal moves, when the player leaves the path (more than
--     Config.Nav.deviate studs) or reaches the end of a partial path, never more than once every
--     Config.Nav.recompute seconds and never every frame. Without a path: a straight line to the goal.
--   * Markers: a pool of Config.Nav.pool anchored, non-colliding, non-queryable parts every Config.Nav.spacing
--     studs on the first Config.Nav.ahead studs of the path, moved only when the player advances, plus a beacon
--     over the goal when it is close.
--   * Walk: Humanoid:MoveTo from waypoint to waypoint (jumps where the path jumps). Stopped by WASD / the
--     joystick, a jump, picking an attack target, opening a service window, death and teleports. Walking does
--     not leave combat: nothing changes on the server, it is ordinary movement.
--   * Arriving (Config.Nav.arrive, NPCs Config.Nav.arriveNpc) clears the target; a walk to an NPC ends facing
--     them with the "Talk [E]" hint.
-- /nav and /navdebug (admin) arrive through AdminClient.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.UI.MapSketch)
local MapTerrain = require(ReplicatedStorage.Shared.Logic.MapTerrain)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NavPath = require(ReplicatedStorage.Shared.Logic.NavPath)
local NavTarget = require(script.Parent.Parent.UI.NavTarget)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local NavController = {
	Name = "NavController",
	Deps = { "TargetController" },
}

local NAV = Config.Nav
local TICK = 0.1
local NPC_STAND = 5 -- studs in front of an NPC where the guide ends
local PORTAL_NEAR = 12 -- studs from a portal on the way that show the "Travel [E]" hint
local MOVE_TO_REFRESH = 1 -- seconds between MoveTo calls to the same waypoint (MoveTo gives up after 8 s)
local DEBUG_POOL = 80

local scope = Fusion.scoped(Fusion)
local TargetController: any
local player = Players.LocalPlayer

type Point = NavPath.Point

-- Guide state of the current target.
local points: { Point } = {}
local partial = false -- the path ends short of the goal (pathRange or no path found)
local straight = false -- no path: a straight line
local segment = 1
local goalKey = ""
local goalWorld: Vector3? = nil
local finalGoal = false
local lastCompute = -math.huge
local computing = false
local token = 0
local lastAlong = -math.huge
local markersDirty = true
local hinted = ""
local recomputes: { number } = {}
local debugOn = false
local rawPoints: { Vector3 } = {}

-- Walking state.
local walkIndex = 2
local walkIssuedAt = -math.huge
local walkIssuedIndex = 0

local folder: Folder? = nil
local pool: { BasePart } = {}
local beacon: BasePart? = nil
local debugPool: { BasePart } = {}

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function currentMap(): string?
	return State.Get({ "character", "location", "map" })
end

local function offsetOf(mapId: string): Vector3
	local map = Maps.get(mapId)
	return if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else Vector3.zero
end

local function isOpen(mapId: string): boolean
	return MapSketch.isBuilt(mapId)
end

local function toPoint(v: Vector3, jump: boolean?): Point
	return { x = v.X, y = v.Y, z = v.Z, jump = jump }
end

local function toVector(p: Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function worldFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "VaelthornNav"
	created.Parent = Workspace
	folder = created
	return created
end

local function newMarker(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = worldFolder()
	return part
end

local function ensurePool()
	if #pool > 0 and pool[1].Parent then
		return
	end
	table.clear(pool)
	for i = 1, NAV.pool do
		table.insert(pool, newMarker(`Step{i}`, Vector3.new(1.1, 0.15, 1.1), Color3.fromHex("#E8C25A")))
	end
	beacon = newMarker("Beacon", Vector3.new(10, 0.7, 0.7), Color3.fromHex("#F2E28A"), Enum.PartType.Cylinder)
end

local function hideMarkers()
	for _, part in pool do
		part.Transparency = 1
	end
	if beacon then
		beacon.Transparency = 1
	end
end

-- Ground height at a world XZ, or nil without ground. The terrain first (portal arches, roofs and NPCs would
-- lift the point), the rest of the world when no terrain is there. Indoors (caves, dungeons) the ray starts just
-- above `refY` so it does not hit the ceiling. Water is reported as such (Resolve skips it).
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.IgnoreWater = false
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.IgnoreWater = false
local function indoors(): boolean
	local map = Maps.get(currentMap() or "")
	return map ~= nil and (map.biome == "cave" or map.biome == "crypt" or map.biome == "dungeon")
end
local function ground(x: number, z: number, refY: number): (number?, Enum.Material?)
	local inside = indoors()
	local from = if inside then refY + 5 else refY + 200
	-- S48: caves on the engine know their floor (a ramp higher than 5 studs would start the ray in rock)
	local mapId = currentMap()
	local map = Maps.get(mapId or "")
	if inside and map and mapId then
		local floor = MapTerrain.height(mapId, x - map.offset.x, z - map.offset.z)
		if floor then
			from = map.offset.y + floor + 5
		end
	end
	local length = if inside then 40 else 420
	terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -length, 0), terrainParams)
	if not hit then
		local ignore: { Instance } = { worldFolder() }
		if player.Character then
			table.insert(ignore, player.Character)
		end
		local monsters = Workspace:FindFirstChild("Monsters")
		if monsters then
			table.insert(ignore, monsters)
		end
		worldParams.FilterDescendantsInstances = ignore
		hit = Workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -length, 0), worldParams)
	end
	if not hit then
		return nil, nil
	end
	return hit.Position.Y, hit.Material
end

local function placeMarkers(rootPosition: Vector3)
	ensurePool()
	local progress = NavPath.progress(points, toPoint(rootPosition), segment)
	local markers = NavPath.markers(points, progress.along, NAV.spacing, NAV.ahead, #pool)
	for i, part in pool do
		local marker = markers[i]
		if marker then
			local y = marker.y
			if straight then
				y = ground(marker.x, marker.z, rootPosition.Y) or (rootPosition.Y - 2.5)
			end
			local yaw = math.atan2(-marker.dx, -marker.dz)
			part.CFrame = CFrame.new(marker.x, y + 0.2, marker.z) * CFrame.Angles(0, yaw + math.rad(45), 0)
			part.Transparency = 0.15
		else
			part.Transparency = 1
		end
	end
	local goal = goalWorld
	if beacon then
		if goal and finalGoal and flat(goal, rootPosition) <= NAV.ahead then
			local y = ground(goal.X, goal.Z, goal.Y) or goal.Y
			beacon.CFrame = CFrame.new(goal.X, y + 5, goal.Z) * CFrame.Angles(0, 0, math.rad(90))
			beacon.Transparency = 0.35
		else
			beacon.Transparency = 1
		end
	end
	lastAlong = progress.along
	markersDirty = false
end

local function showDebug()
	for i, part in debugPool do
		local at = rawPoints[i]
		if debugOn and at then
			part.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0))
			part.Transparency = 0.2
		else
			part.Transparency = 1
		end
	end
end

-- Forgets the path and drops a pathfinding call still running (its result belongs to an old goal).
local function resetPath()
	token += 1
	computing = false
	table.clear(points)
	table.clear(rawPoints)
	segment = 1
	partial = false
	straight = false
	lastAlong = -math.huge
	markersDirty = true
	walkIndex = 2
	walkIssuedIndex = 0
	showDebug()
end

-- Stops walking (keeps the target). `quiet` = no movement reset (the player is moving themselves).
function NavController.StopWalk(quiet: boolean?)
	if not Fusion.peek(NavTarget.Walking) then
		return
	end
	NavTarget.Walking:set(false)
	if not quiet then
		local h, r = humanoid(), root()
		if h and r then
			h:MoveTo(r.Position)
		end
	end
end

function NavController.Clear()
	NavController.StopWalk()
	NavTarget.Target:set(nil)
	NavTarget.Distance:set(nil)
	NavTarget.Via:set(nil)
	goalKey = ""
	goalWorld = nil
	hinted = ""
	resetPath()
	hideMarkers()
end

-- Shows the path to `target` (map-relative, any map).
function NavController.Guide(target: NavTarget.Target)
	NavController.StopWalk()
	NavTarget.Target:set(target)
	goalKey = ""
	hinted = ""
	lastCompute = -math.huge
	resetPath()
end

-- Walks to `target` (only on the current map); returns false when it is elsewhere.
function NavController.Walk(target: NavTarget.Target): boolean
	if target.map ~= currentMap() then
		Toast.push(Text.now("nav.walkOtherMap"), "info", 3)
		return false
	end
	NavController.Guide(target)
	-- Leave a fight's approach and auto-attack (like WASD would); the target stays selected.
	TargetController.Stop()
	NavTarget.Walking:set(true)
	return true
end

-- Nearest reachable point around a map-relative position on the current map (not water, not a wall), or nil.
function NavController.Resolve(mapId: string, x: number, z: number): (number?, number?)
	if mapId ~= currentMap() then
		return x, z
	end
	local offset = offsetOf(mapId)
	local r = root()
	local refY = if r then r.Position.Y else offset.Y
	local function ok(px: number, pz: number): boolean
		local y, material = ground(offset.X + px, offset.Z + pz, refY)
		return y ~= nil and material ~= Enum.Material.Water
	end
	if ok(x, z) then
		return x, z
	end
	for _, radius in { 6, 12, 20, 30, 45 } do
		for i = 0, 7 do
			local angle = i * math.pi / 4
			local px, pz = x + math.cos(angle) * radius, z + math.sin(angle) * radius
			if ok(px, pz) then
				return px, pz
			end
		end
	end
	return nil, nil
end

-- Where the guide ends for an NPC: a few studs in front of them (their model when streamed, else the data).
local function npcStand(npcId: string): (Vector3?, Vector3?)
	local def = Npcs.get(npcId)
	if not def then
		return nil, nil
	end
	local world = Workspace:FindFirstChild("World")
	local folderNpcs = world and world:FindFirstChild("Npcs")
	local model = folderNpcs and folderNpcs:FindFirstChild(npcId)
	local offset = offsetOf(def.map)
	local position = if model and model:IsA("Model")
		then model:GetPivot().Position
		else offset + Vector3.new(def.position.x, 0, def.position.z)
	local front = CFrame.Angles(0, math.rad(def.facing), 0).LookVector
	return position + Vector3.new(front.X, 0, front.Z) * NPC_STAND, position
end

local function recordRecompute()
	local now = os.clock()
	table.insert(recomputes, now)
	while recomputes[1] and now - recomputes[1] > 10 do
		table.remove(recomputes, 1)
	end
end

-- Computes the path from the character to `goal` (yields inside a task, guarded by `token`).
local function compute(from: Vector3, goal: Vector3)
	if computing then
		return
	end
	computing = true
	lastCompute = os.clock()
	recordRecompute()
	token += 1
	local myToken = token
	task.spawn(function()
		local target = goal
		local isPartial = false
		local distance = flat(from, goal)
		if distance > NAV.pathRange then
			local direction = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z).Unit
			target = from + direction * NAV.pathRange
			isPartial = true
		end
		local h = humanoid()
		local r = root()
		local radius = if r then math.max(r.Size.X, r.Size.Z) / 2 + 0.5 else 2
		local height = if h and r then h.HipHeight + r.Size.Y + 1.5 else 5
		local path = PathfindingService:CreatePath({
			AgentRadius = radius,
			AgentHeight = height,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
			Costs = { Water = 20 },
		})
		local raw: { Point } = {}
		local function attempt(to: Vector3): boolean
			local ok = pcall(function()
				path:ComputeAsync(from, to)
			end)
			if not ok or path.Status ~= Enum.PathStatus.Success then
				return false
			end
			for _, waypoint in path:GetWaypoints() do
				table.insert(raw, toPoint(waypoint.Position, waypoint.Action == Enum.PathWaypointAction.Jump))
			end
			return true
		end
		-- A partial goal may land in a hill or a lake: try a closer one before the straight line.
		if not attempt(target) and isPartial and myToken == token then
			attempt(from + (target - from) * 0.45)
		end
		if myToken ~= token then
			return
		end
		computing = false
		table.clear(rawPoints)
		if #raw >= 2 then
			for i = 1, math.min(#raw, DEBUG_POOL) do
				table.insert(rawPoints, toVector(raw[i]))
			end
			points = NavPath.simplify(raw)
			straight = false
			partial = isPartial
		else
			points = { toPoint(from), toPoint(Vector3.new(goal.X, from.Y, goal.Z)) }
			straight = true
			partial = false
		end
		segment = 1
		walkIndex = 2
		walkIssuedIndex = 0
		markersDirty = true
		showDebug()
	end)
end

local function arrived(target: NavTarget.Target, npcPosition: Vector3?)
	local wasWalking = Fusion.peek(NavTarget.Walking)
	local label = if target.label then target.label elseif target.labelKey then Text.now(target.labelKey) else ""
	NavController.Clear()
	if wasWalking and target.npc and npcPosition then
		local r = root()
		if r then
			local look = Vector3.new(npcPosition.X, r.Position.Y, npcPosition.Z)
			if (look - r.Position).Magnitude > 0.5 then
				r.CFrame = CFrame.lookAt(r.Position, look)
			end
		end
		Toast.push(Text.now("nav.talkHint", { key = Keybinds.label("interact") }), "info", 4)
	else
		Toast.push(Text.now("nav.arrived", { name = label }), "success", 3)
	end
end

-- Party member targets follow the member (state branch `party`).
local function follow(target: NavTarget.Target): NavTarget.Target?
	if not target.follow then
		return target
	end
	local party = State.Get({ "party" })
	if type(party) ~= "table" then
		return nil
	end
	for _, member in party.members do
		if member.id == target.follow then
			local map = Maps.get(member.map or "")
			if not map then
				return nil
			end
			local moved = table.clone(target)
			moved.map = map.id
			moved.x = member.x - map.offset.x
			moved.z = member.z - map.offset.z
			return moved
		end
	end
	return nil
end

local function walkStep(r: BasePart, h: Humanoid)
	if #points < 2 then
		return
	end
	walkIndex = math.max(walkIndex, segment + 1)
	local waypoint = points[walkIndex]
	while waypoint and flat(r.Position, toVector(waypoint)) < NAV.waypointReach and walkIndex < #points do
		walkIndex += 1
		waypoint = points[walkIndex]
	end
	if not waypoint then
		return
	end
	local now = os.clock()
	if walkIndex ~= walkIssuedIndex or now - walkIssuedAt > MOVE_TO_REFRESH then
		walkIssuedIndex = walkIndex
		walkIssuedAt = now
		h:MoveTo(toVector(waypoint))
	end
	if waypoint.jump and flat(r.Position, toVector(waypoint)) < 6 then
		h.Jump = true
	end
end

local function step()
	local wanted = Fusion.peek(NavTarget.Target)
	if not wanted then
		return
	end
	local target = follow(wanted)
	if not target then
		Toast.push(Text.now("nav.lost"), "info", 3)
		NavController.Clear()
		return
	end
	local r, h = root(), humanoid()
	local mapId = currentMap()
	if not r or not h or not mapId or State.Get({ "session", "phase" }) ~= "playing" then
		return
	end
	if State.Get({ "death" }) ~= nil or h.Health <= 0 then
		NavController.StopWalk(true)
		return
	end
	local offset = offsetOf(mapId)
	local goal: Vector3
	local npcPosition: Vector3? = nil
	local exit: MapRoute.Exit? = nil
	if target.map == mapId then
		finalGoal = true
		if target.npc then
			local stand, position = npcStand(target.npc)
			npcPosition = position
			goal = stand or (offset + Vector3.new(target.x, 0, target.z))
		else
			goal = offset + Vector3.new(target.x, 0, target.z)
		end
		NavTarget.Via:set(nil)
	else
		finalGoal = false
		exit = MapRoute.nextExit(mapId, target.map, isOpen)
		if not exit then
			Toast.push(Text.now("nav.noRoute"), "warning", 4)
			NavController.Clear()
			return
		end
		goal = offset + Vector3.new(exit.x, 0, exit.z)
		NavTarget.Via:set(exit.target)
		if Fusion.peek(NavTarget.Walking) then
			NavController.StopWalk()
		end
	end
	-- Goal height: the ground there when it is known, else the character's.
	local y = ground(goal.X, goal.Z, r.Position.Y)
	goal = Vector3.new(goal.X, y or r.Position.Y, goal.Z)
	goalWorld = goal

	local distance = flat(r.Position, goal)
	NavTarget.Distance:set(distance)

	if finalGoal then
		-- NPCs: close to the NPC itself or at the spot in front of them (both inside the "Talk" prompt range).
		local near = distance <= NAV.arrive
			or (target.npc ~= nil and npcPosition ~= nil and flat(r.Position, npcPosition) <= NAV.arriveNpc)
		if near then
			arrived(target, npcPosition)
			return
		end
	elseif exit and distance <= PORTAL_NEAR and hinted ~= exit.id then
		hinted = exit.id
		local key = if exit.kind == "dungeon" then "nav.atDungeon" else "nav.atPortal"
		local next = Maps.get(exit.target)
		Toast.push(
			Text.now(key, { key = Keybinds.label("interact"), map = if next then Text.now(next.nameKey) else "" }),
			"info",
			5
		)
	end

	local key = `{mapId}:{math.floor(goal.X / 4)}:{math.floor(goal.Z / 4)}`
	local now = os.clock()
	local rootPoint = toPoint(r.Position)
	if key ~= goalKey and (#points < 2 or now - lastCompute >= NAV.recompute) then
		-- A new goal (or a moving one, like a party member: at most once every Config.Nav.recompute s).
		goalKey = key
		resetPath()
		compute(r.Position, goal)
	elseif key == goalKey and #points >= 2 and now - lastCompute >= NAV.recompute then
		local progress = NavPath.progress(points, rootPoint, segment)
		local offPath = progress.distance > NAV.deviate
		local endOfPartial = partial and progress.remaining < 40
		local endOfStraight = straight and now - lastCompute >= NAV.recompute * 3
		if offPath or endOfPartial or endOfStraight then
			compute(r.Position, goal)
		end
	end
	if #points >= 2 then
		local progress = NavPath.progress(points, rootPoint, segment)
		segment = progress.segment
		if markersDirty or math.abs(progress.along - lastAlong) >= NAV.spacing / 2 then
			placeMarkers(r.Position)
		end
		if Fusion.peek(NavTarget.Walking) and finalGoal then
			walkStep(r, h)
		end
	end
	if debugOn then
		local perSecond = #recomputes / 10
		NavTarget.Debug:set(Text.now("nav.debug", {
			points = #points,
			raw = #rawPoints,
			rate = string.format("%.1f", perSecond),
			mode = if straight then "line" elseif partial then "partial" else "path",
		}))
	end
end

function NavController.ToggleDebug()
	debugOn = not debugOn
	if debugOn and #debugPool == 0 then
		for i = 1, DEBUG_POOL do
			table.insert(
				debugPool,
				newMarker(`Raw{i}`, Vector3.new(0.6, 0.6, 0.6), Color3.fromHex("#E0564A"), Enum.PartType.Ball)
			)
		end
	end
	NavTarget.Debug:set(if debugOn then "" else nil)
	showDebug()
end

-- /nav from the dev panel or the chat: { kind = "npc" | "map" | "point" | "clear", id?, x?, z? }.
local function fromAdmin(spec: any)
	if type(spec) ~= "table" then
		return
	end
	if spec.kind == "clear" then
		NavController.Clear()
	elseif spec.kind == "npc" then
		local def = Npcs.get(spec.id)
		if def then
			NavController.Guide({
				map = def.map,
				x = def.position.x,
				z = def.position.z,
				npc = def.id,
				kind = "npc",
				id = def.id,
				labelKey = def.nameKey,
			})
		end
	elseif spec.kind == "map" then
		local map = Maps.get(spec.id)
		if map then
			NavController.Guide({ map = map.id, x = map.spawn.x, z = map.spawn.z, labelKey = map.nameKey })
		end
	elseif spec.kind == "point" and type(spec.x) == "number" and type(spec.z) == "number" then
		local mapId = currentMap()
		if mapId then
			NavController.Guide({ map = mapId, x = spec.x, z = spec.z, label = `{spec.x}, {spec.z}` })
		end
	end
end

function NavController.Init(registry)
	TargetController = registry.Get("TargetController")
end

function NavController.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		-- Manual movement takes over at once (every frame, cheap).
		if Fusion.peek(NavTarget.Walking) and TargetController.MoveInput().Magnitude > 0.1 then
			NavController.StopWalk(true)
		end
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		local ok, err = pcall(step :: any)
		if not ok then
			warn("[Nav] " .. tostring(err))
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		NavController.StopWalk(true)
	end)
	-- Picking an attack target ends the walk.
	scope:Observer(TargetController.Target):onChange(function()
		if Fusion.peek(TargetController.Target) ~= nil then
			NavController.StopWalk(true)
		end
	end)
	-- Teleports (map change) and death stop the walk; the guide recomputes on the new map.
	scope:Observer(State.Value({ "character", "location", "map" })):onChange(function()
		NavController.StopWalk(true)
		goalKey = ""
		hinted = ""
	end)
	State.Changed:Connect(function()
		if State.Get({ "death" }) ~= nil then
			NavController.StopWalk(true)
		end
		if State.Get({ "session", "phase" }) ~= "playing" and Fusion.peek(NavTarget.Target) then
			NavController.Clear()
		end
	end)
	player.CharacterAdded:Connect(function()
		NavController.StopWalk(true)
		goalKey = ""
		hideMarkers()
	end)
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "nav" then
			fromAdmin(arg)
		elseif action == "navdebug" then
			NavController.ToggleDebug()
			Toast.push(Text.now(if debugOn then "nav.debugOn" else "nav.debugOff"), "info", 3)
		end
	end)
end

return NavController
