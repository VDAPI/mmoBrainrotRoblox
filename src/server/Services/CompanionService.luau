--!strict
-- Quest companions (S101b, DESIGN-15 §3.5; rules in Logic/Companion). While an objective of a quest's `companion`
-- `during` is the current one, a clone of the NPC's figure (NpcService.Figure; the NPC itself keeps standing for
-- everyone else) walks with the player on the companion's map: `follow` stays next to them, `lead` walks the route of
-- the `escort` objective and fires QuestEvents "escort" when both arrive. At most one per player (the story first).
-- The figure is server-driven (Humanoid:MoveTo, PathfindingService on the legs of the route and towards the player,
-- NavPath.simplify, Logic/Steer around obstacles), never an entity (no combat, no targeting, cannot die) and never
-- collides with players or monsters (collision group "Companions" against "Bodies"). State only in the runtime branch
-- { "companion" } = { npc, quest, mode, phase } (never saved). QuestService and SideQuestService call Refresh after
-- every change of the active quests; the loop also reconciles once a second. Without a figure (Roblox could not build
-- one) the quest goes on: the escort counts when the player reaches the goal alone.

local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Combat = require(Shared.Data.Combat)
local Companion = require(Shared.Logic.Companion)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local NavPath = require(Shared.Logic.NavPath)
local Npcs = require(Shared.Data.Npcs)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Quests = require(Shared.Data.Quests)
local SideQuests = require(Shared.Logic.SideQuests)
local Steer = require(Shared.Logic.Steer)
local Types = require(Shared.Types)

local log = Log.new("CompanionService")

local CompanionService = {
	Name = "CompanionService",
	Deps = { "PlayerStateService", "CharacterService", "NpcService", "ResourceService", "ZoneService", "WorldService" },
}

local PlayerStateService: any
local CharacterService: any
local NpcService: any
local ResourceService: any
local ZoneService: any
local WorldService: any

local C = Config.Companion
local GROUP = "Companions"
local BODIES = "Bodies" -- player characters and monsters: they never touch a companion
local RECONCILE = 1 -- seconds between the loop's checks of Companion.want
local WAYPOINT_REACH = 3.5
local FALL_DEPTH = 60 -- studs under the player at which a fallen figure is put back

type Entry = {
	quest: string,
	kind: Companion.Kind,
	def: Quests.CompanionDef,
	state: Companion.State,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	lastPos: Vector3?,
	published: string?,
	-- follow: the pathfound way towards the walk target
	path: { Vector3 }?,
	pathIndex: number,
	pathAt: number,
	pathTarget: Vector3?,
	computing: boolean,
	detourSide: number?,
	detourUntil: number,
	token: number,
}

local entries: { [Player]: Entry } = {}
local started = false
local folder: Folder? = nil
local tokens = 0

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function questOf(id: string): any
	return Quests.Main.get(id) or Quests.npcQuest(id)
end

-- Whether the quest is still active for the character (handed in or abandoned = gone).
local function questActive(char: Types.CharacterData, id: string): boolean
	local main = char.quests.main
	if main and main.id == id then
		return true
	end
	return SideQuests.isActive(char.quests, id)
end

local function progressOf(char: Types.CharacterData, id: string): { number }?
	local main = char.quests.main
	if main and main.id == id then
		return main.progress
	end
	local entry = SideQuests.activeOf(char.quests)[id]
	return if type(entry) == "table" then entry.progress else nil
end

local function mapOf(player: Player, char: Types.CharacterData): string
	local zone = ZoneService.GetZone(player)
	return if zone then zone.map else char.location.map
end

local function playerRoot(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function offsetOf(mapId: string): Vector3
	local map = Maps.get(mapId)
	return if map then Vector3.new(map.offset.x, 0, map.offset.z) else Vector3.zero
end

local function toFlat(position: Vector3, mapId: string): Companion.Flat
	local offset = offsetOf(mapId)
	return { x = position.X - offset.X, z = position.Z - offset.Z }
end

-- World position of a map-relative point on the floor.
local function toWorld(point: { x: number, z: number }, mapId: string): Vector3
	return WorldService.FloorAt(mapId, point.x, point.z)
end

local function publish(player: Player, entry: Entry?)
	if not PlayerStateService.HasState(player) then
		return
	end
	if not entry then
		PlayerStateService.Set(player, { "companion" }, nil)
		return
	end
	entry.published = entry.state.phase
	PlayerStateService.Set(player, { "companion" }, {
		npc = entry.def.npc,
		quest = entry.quest,
		mode = entry.def.mode,
		phase = entry.state.phase,
	})
end

-- Figure ----------------------------------------------------------------------------------------------------------------

local function setBodies(model: Instance)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = BODIES
		end
	end
	model.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = BODIES
		end
	end)
end

local function removeFigure(entry: Entry)
	entry.token += 1
	if entry.model then
		entry.model:Destroy()
	end
	entry.model, entry.humanoid, entry.root = nil, nil, nil
	entry.path, entry.pathTarget, entry.lastPos = nil, nil, nil
	entry.computing = false
end

-- Pathfinding from `from` to `to` (world); the waypoints or nil.
local function findPath(from: Vector3, to: Vector3): { Vector3 }?
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		Costs = { Water = 20 },
	})
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	local out: { Vector3 } = {}
	for _, waypoint in path:GetWaypoints() do
		table.insert(out, waypoint.Position)
	end
	return out
end

-- A leading companion's route over the ground: every leg pathfound (straight when that fails), simplified.
local function buildRoute(player: Player, entry: Entry)
	local route = entry.state.route
	if #route < 2 then
		return
	end
	local token = entry.token
	local mapId = entry.def.map
	task.spawn(function()
		local points: { NavPath.Point } = {}
		local offset = offsetOf(mapId)
		for i = 1, #route - 1 do
			local a, b = toWorld(route[i], mapId), toWorld(route[i + 1], mapId)
			local found = findPath(a + Vector3.new(0, 3, 0), b + Vector3.new(0, 3, 0))
			local waypoints: { Vector3 } = if found then found else { a, b }
			for j, position in waypoints do
				if not (i > 1 and j == 1) then
					table.insert(points, { x = position.X - offset.X, y = position.Y, z = position.Z - offset.Z })
				end
			end
		end
		local current = entries[player]
		if current == entry and entry.token == token and #points >= 2 then
			local state = table.clone(entry.state)
			state.route = NavPath.simplify(points)
			state.segment = 1
			entry.state = state
		end
	end)
end

local function spawnFigure(player: Player, entry: Entry, point: { x: number, z: number })
	removeFigure(entry)
	local token = entry.token
	local def = Npcs.get(entry.def.npc)
	local model = def and NpcService.Figure(def) -- yields (avatar build)
	if not model then
		-- the quest goes on without a figure (Logic/Companion: the escort counts at the goal)
		return
	end
	if entries[player] ~= entry or entry.token ~= token then
		-- dropped or rebuilt while the figure was being built
		model:Destroy()
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or not folder then
		model:Destroy()
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = part == root -- the root stands on the ground; group: never on players or monsters
			part.CanTouch = false
			part.CanQuery = false
			part.Massless = part ~= root
			part.CollisionGroup = GROUP
		end
	end
	humanoid.WalkSpeed = if entry.def.mode == "lead" then C.speedLead else C.speedFollow
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.BreakJointsOnDeath = false
	model.Name = `Companion_{player.UserId}`
	model:SetAttribute("CompanionOf", player.UserId)
	model:SetAttribute("CompanionNpc", entry.def.npc)
	model:SetAttribute("CompanionQuest", entry.quest)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local ground = toWorld(point, entry.def.map)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.2, 0)))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	entry.model, entry.humanoid, entry.root = model, humanoid, root
	entry.lastPos = root.Position
	if entry.def.mode == "lead" then
		buildRoute(player, entry)
	end
end

local function teleport(entry: Entry, point: { x: number, z: number })
	local root, humanoid, model = entry.root, entry.humanoid, entry.model
	if not root or not humanoid or not model then
		return
	end
	local ground = toWorld(point, entry.def.map)
	model:PivotTo(CFrame.new(ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.2, 0)))
	entry.path, entry.pathTarget = nil, nil
	entry.lastPos = root.Position
end

-- Movement ------------------------------------------------------------------------------------------------------------

local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.RespectCanCollide = true
probeParams.IgnoreWater = true
local probeRefresh = 0

local function refreshProbe()
	local now = os.clock()
	if now - probeRefresh < 2 then
		return
	end
	probeRefresh = now
	local ignore: { Instance } = {}
	if folder then
		table.insert(ignore, folder)
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	probeParams.FilterDescendantsInstances = ignore
end

local function blocked(root: BasePart, humanoid: Humanoid, dx: number, dz: number, reach: number): boolean
	local direction = Vector3.new(dx, 0, dz) * reach
	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	for _, y in { feet + 1.5, root.Position.Y } do
		local hit = Workspace:Raycast(Vector3.new(root.Position.X, y, root.Position.Z), direction, probeParams)
		if hit and hit.Normal.Y < 0.6 then
			return true
		end
	end
	return false
end

-- Walks towards `goal` around obstacles (Logic/Steer, like Entities/Monster.steerTo).
local function steerTo(entry: Entry, goal: Vector3)
	local root, humanoid = entry.root, entry.humanoid
	if not root or not humanoid then
		return
	end
	local from = root.Position
	local offset = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	local dist = offset.Magnitude
	local reach = math.min(dist, Combat.steerLookAhead + root.Size.Z / 2)
	if dist < 2 or reach < 1 then
		humanoid:MoveTo(goal)
		return
	end
	refreshProbe()
	local now = os.clock()
	local prefer = if now < entry.detourUntil then entry.detourSide else nil
	local dx, dz, side = Steer.choose(offset.X, offset.Z, function(x, z)
		return blocked(root, humanoid, x, z, reach)
	end, prefer)
	if side == 0 then
		humanoid:MoveTo(goal)
		return
	end
	entry.detourSide = side
	entry.detourUntil = now + Combat.steerHold
	humanoid:MoveTo(from + Vector3.new(dx, 0, dz) * (reach + 2))
end

-- Follow: a path towards the target point (recomputed at most every pathEvery seconds), then the waypoints.
local function followTo(entry: Entry, target: Vector3)
	local root = entry.root
	if not root then
		return
	end
	local now = os.clock()
	local moved = entry.pathTarget == nil or (entry.pathTarget :: Vector3 - target).Magnitude > 4
	if moved and not entry.computing and now - entry.pathAt >= C.pathEvery then
		entry.computing = true
		entry.pathAt = now
		local token = entry.token
		local from = root.Position
		task.spawn(function()
			local waypoints = findPath(from, target)
			if entry.token ~= token then
				return
			end
			entry.computing = false
			entry.path = waypoints
			entry.pathIndex = 2
			entry.pathTarget = target
		end)
	end
	local path = entry.path
	if path then
		while entry.pathIndex <= #path do
			local waypoint = path[entry.pathIndex]
			local flatGap = Vector3.new(waypoint.X - root.Position.X, 0, waypoint.Z - root.Position.Z).Magnitude
			if flatGap > WAYPOINT_REACH then
				break
			end
			entry.pathIndex += 1
		end
		local waypoint = path[entry.pathIndex]
		if waypoint then
			if entry.humanoid and waypoint.Y > root.Position.Y + 1.5 then
				entry.humanoid.Jump = true
			end
			steerTo(entry, waypoint)
			return
		end
	end
	steerTo(entry, target)
end

local function stand(entry: Entry)
	local root, humanoid = entry.root, entry.humanoid
	if root and humanoid then
		humanoid:MoveTo(root.Position)
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------------------------

local function remove(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	removeFigure(entry)
	entries[player] = nil
	publish(player, nil)
end

local function create(player: Player, char: Types.CharacterData, want: Companion.Want)
	local def = want.def
	local from = Companion.fromOf(def)
	if not from then
		return
	end
	local quest = questOf(want.quest)
	local objective = if def.mode == "lead" and quest then Companion.escortOf(quest) else nil
	tokens += 1
	local entry: Entry = {
		quest = want.quest,
		kind = want.kind,
		def = def,
		state = Companion.newState(def, from, objective),
		pathIndex = 1,
		pathAt = 0,
		computing = false,
		detourUntil = 0,
		token = tokens * 1000,
	}
	entries[player] = entry
	local root = playerRoot(player)
	if mapOf(player, char) == def.map and root then
		spawnFigure(player, entry, Companion.spawnPoint(entry.state, toFlat(root.Position, def.map)))
		if entries[player] ~= entry then
			return
		end
	else
		local state = table.clone(entry.state)
		state.phase = "back"
		entry.state = state
	end
	publish(player, entry)
	log:debug("%s: %s with %s (%s)", player.Name, def.npc, want.quest, def.mode)
end

-- Makes the companion match the character's active quests (Logic/Companion.want): creates, swaps or removes it.
-- When the companion's objectives are done while its quest still runs, it stays a moment (phase "arrived").
function CompanionService.Refresh(player: Player)
	if not started then
		return
	end
	local char = PlayerStateService.HasState(player) and character(player)
	if not char then
		remove(player)
		return
	end
	local want = Companion.want(char.quests, char.level)
	local entry = entries[player]
	if entry and want and entry.quest == want.quest and entry.def == want.def then
		return
	end
	if entry then
		if not want and questActive(char, entry.quest) and entry.model then
			if entry.state.phase ~= "arrived" then
				local state = table.clone(entry.state)
				state.phase = "arrived"
				state.arrivedAt = os.clock()
				entry.state = state
				publish(player, entry)
			end
			return
		end
		remove(player)
	end
	if want then
		create(player, char, want)
	end
end

local function apply(player: Player, entry: Entry, action: Companion.Action)
	local kind = action.kind
	local point = action.to
	if kind == "walk" and point then
		local target = toWorld(point, entry.def.map)
		if entry.def.mode == "follow" or entry.state.phase == "arrived" then
			followTo(entry, target)
		else
			steerTo(entry, target)
		end
	elseif kind == "teleport" and point then
		teleport(entry, point)
	elseif kind == "spawn" and point then
		spawnFigure(player, entry, point)
	elseif kind == "arrived" then
		stand(entry)
		QuestEvents.fire(player, "escort", { npc = entry.def.npc, quest = entry.quest })
	elseif kind == "reset" then
		removeFigure(entry)
	elseif kind == "despawn" then
		removeFigure(entry)
		if entry.state.phase == "arrived" then
			entries[player] = nil
			publish(player, nil)
		end
	else
		stand(entry)
	end
end

local function tick(player: Player, entry: Entry, now: number)
	local char = PlayerStateService.HasState(player) and character(player)
	if not char or not questActive(char, entry.quest) then
		remove(player)
		return
	end
	local mapId = mapOf(player, char)
	local root = playerRoot(player)
	-- a figure removed from the world or fallen through it: put it back next to the player
	if entry.model and (not entry.model.Parent or not entry.root or not entry.root.Parent) then
		removeFigure(entry)
		if entry.state.phase ~= "arrived" then
			-- gone: a following one comes back next to the player, a leading one waits at its start
			local lost = table.clone(entry.state)
			lost.phase = "back"
			lost.segment = 1
			lost.walking = false
			entry.state = lost
		end
	end
	if entry.root and root and entry.root.Position.Y < root.Position.Y - FALL_DEPTH then
		teleport(entry, Companion.toward(toFlat(root.Position, entry.def.map), entry.state.from, C.followDist))
	end
	local figureRoot = entry.root
	local moved = 1
	if figureRoot and entry.lastPos then
		local delta = figureRoot.Position - (entry.lastPos :: Vector3)
		moved = Vector3.new(delta.X, 0, delta.Z).Magnitude
	end
	if figureRoot then
		entry.lastPos = figureRoot.Position
	end
	local quest = questOf(entry.quest)
	local progress = progressOf(char, entry.quest)
	local finished = quest ~= nil
		and entry.def.mode == "follow"
		and Companion.duringDone(entry.def, quest.objectives, progress)
	local state, action = Companion.step(entry.state, {
		figure = if figureRoot then toFlat(figureRoot.Position, entry.def.map) else nil,
		player = if root then toFlat(root.Position, entry.def.map) else { x = 0, z = 0 },
		alive = root ~= nil and not ResourceService.IsDead(player),
		sameMap = mapId == entry.def.map,
		moved = moved,
		inCombat = ResourceService.InCombat(player),
		now = now,
		finished = finished,
	})
	entry.state = state
	-- without a figure (none could be built) movement does nothing; the quest goes on
	apply(player, entry, action)
	if entries[player] == entry and entry.published ~= entry.state.phase then
		publish(player, entry)
	end
end

-- Admin -----------------------------------------------------------------------------------------------------------------

-- /companion info: the companion of a player ({ npc, quest, phase, mode }) or nil.
function CompanionService.Info(player: Player): { npc: string, quest: string, phase: string, mode: string }?
	local entry = entries[player]
	if not entry then
		return nil
	end
	return {
		npc = entry.def.npc,
		quest = entry.quest,
		phase = entry.state.phase :: string,
		mode = entry.def.mode :: string,
	}
end

-- /companion reset: sends the companion back (a leading one waits at its start, a following one rejoins next to the
-- player). False without a companion.
function CompanionService.Reset(player: Player): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	removeFigure(entry)
	local state = table.clone(entry.state)
	state.phase = "back"
	state.segment = 1
	state.walking = false
	state.stillFor = 0
	state.farFor = 0
	state.waitingDead = false
	state.arrivedAt = nil
	entry.state = state
	publish(player, entry)
	return true
end

function CompanionService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	NpcService = registry.Get("NpcService")
	ResourceService = registry.Get("ResourceService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
end

local function registerGroups()
	for _, name in { GROUP, BODIES } do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP, BODIES, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
end

function CompanionService.Start()
	local ok, err = pcall(registerGroups :: any)
	if not ok then
		log:warn("collision groups: %s", tostring(err))
	end
	local world = Workspace:WaitForChild("World")
	local created = Instance.new("Folder")
	created.Name = "Companions"
	created.Parent = world
	folder = created
	started = true

	-- players and monsters never collide with a companion
	local function watchPlayer(player: Player)
		if player.Character then
			setBodies(player.Character)
		end
		player.CharacterAdded:Connect(setBodies)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	task.spawn(function()
		local monsters = Workspace:WaitForChild("Monsters", 600)
		if monsters then
			setBodies(monsters)
		end
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		CompanionService.Refresh(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		remove(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			removeFigure(entry)
			entries[player] = nil
		end
	end)
	ZoneService.ZoneChanged:Connect(function(player: Player)
		CompanionService.Refresh(player)
	end)

	task.spawn(function()
		local lastReconcile = 0
		while true do
			task.wait(C.tick)
			local now = os.clock()
			if now - lastReconcile >= RECONCILE then
				lastReconcile = now
				for _, player in Players:GetPlayers() do
					if PlayerStateService.HasState(player) then
						local okRefresh, refreshErr = pcall(CompanionService.Refresh :: any, player)
						if not okRefresh then
							log:warn("refresh %s: %s", player.Name, tostring(refreshErr))
						end
					end
				end
			end
			-- a snapshot: building a figure yields, and other threads may add or drop entries meanwhile
			for player, entry in table.clone(entries) do
				if entries[player] == entry then
					local okTick, tickErr = pcall(tick :: any, player, entry, now)
					if not okTick then
						log:warn("tick %s: %s", player.Name, tostring(tickErr))
					end
				end
			end
		end
	end)
end

return CompanionService
