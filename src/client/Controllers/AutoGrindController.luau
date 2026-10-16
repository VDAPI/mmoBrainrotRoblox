--!strict
-- Auto Hunt on the client (S134d). The server (AutoGrindService) picks the target and the next group and tells the
-- client through the state branch `autoGrind` (Types.AutoGrindRuntime); this controller only walks there:
--   * a target: walks into attack range of it (the server attacks whenever it is in reach; TargetController shows it
--     and turns the character towards it, SetServerDriven / ShowServerTarget), never sends SetTarget itself;
--   * no target: walks to the next group's centre on a PathfindingService path simplified by Logic/NavPath (the same
--     agent and simplification as the guide, NavController), recomputed when the goal moves or every PATH_AGE s.
-- WASD / the joystick, a jump, a click on a target, a skill, Tab, the mobile attack button and talking to an NPC are
-- the player taking over: AutoGrind(false) (the server would stop it on the client's own SetTarget too).
-- AFK: only while hunting, Players.LocalPlayer.Idled answers with one VirtualUser click, so paid or earned time is not
-- lost to Roblox's 20 minute idle kick; disconnected at every stop (the hunt itself ends at the daily cap).

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Combat = require(ReplicatedStorage.Shared.Data.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NavPath = require(ReplicatedStorage.Shared.Logic.NavPath)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local AutoGrindController = {
	Name = "AutoGrindController",
	Deps = { "TargetController", "NavController", "NpcController" },
}

local TICK = 0.15
local PATH_AGE = 3 -- seconds before a path to the same goal is computed again
local GOAL_MOVED = 8 -- studs: a goal (a walking target) that moved this far gets a new path
local STRAIGHT = 20 -- studs: closer than this the character walks straight
local MOVE_TO_REFRESH = 1

local scope = Fusion.scoped(Fusion)
local player = Players.LocalPlayer
local TargetController: any
local NavController: any
local NpcController: any

local active = false
local stopping = false
local idleConnection: RBXScriptConnection? = nil

-- path state
local points: { NavPath.Point } = {}
local pathGoal: Vector3? = nil
local pathAt = -math.huge
local computing = false
local token = 0
local walkIndex = 2
local issuedIndex = 0
local issuedAt = -math.huge

local function root(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function toVector(p: NavPath.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function attackRange(): number
	local derived = State.Get({ "derived" })
	local class = Classes.get(State.Get({ "character", "class" }) or "")
	local ranged = if derived and derived.weapon
		then derived.weapon.ranged
		elseif class then class.basicAttack.ranged
		else false
	return if ranged then Combat.rangedRange else Combat.meleeRange
end

local function resetPath()
	token += 1
	computing = false
	table.clear(points)
	pathGoal = nil
	pathAt = -math.huge
	walkIndex = 2
	issuedIndex = 0
end

local function halt()
	resetPath()
	local h, r = humanoid(), root()
	if h and r then
		h:MoveTo(r.Position)
	end
end

local function compute(from: Vector3, goal: Vector3)
	if computing then
		return
	end
	computing = true
	pathAt = os.clock()
	pathGoal = goal
	token += 1
	local myToken = token
	task.spawn(function()
		local h, r = humanoid(), root()
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
		local raw: { NavPath.Point } = {}
		local ok = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, waypoint in path:GetWaypoints() do
				local p = waypoint.Position
				table.insert(raw, { x = p.X, y = p.Y, z = p.Z, jump = waypoint.Action == Enum.PathWaypointAction.Jump })
			end
		end
		if myToken ~= token then
			return
		end
		computing = false
		if #raw >= 2 then
			points = NavPath.simplify(raw)
		else
			-- no path: a straight line (the character may still get there, the server stops it when stuck)
			points = { { x = from.X, y = from.Y, z = from.Z }, { x = goal.X, y = goal.Y, z = goal.Z } }
		end
		walkIndex = 2
		issuedIndex = 0
	end)
end

-- Walks towards `goal` until within `reach` studs (flat).
local function walkTo(goal: Vector3, reach: number)
	local h, r = humanoid(), root()
	if not h or not r or h.Health <= 0 or h.Sit then
		return
	end
	local distance = flat(r.Position, goal)
	if distance <= reach then
		if h.MoveDirection.Magnitude > 0.1 then
			h:MoveTo(r.Position)
		end
		resetPath()
		return
	end
	if distance <= STRAIGHT then
		resetPath()
		local direction = Vector3.new(goal.X - r.Position.X, 0, goal.Z - r.Position.Z).Unit
		h:MoveTo(goal - direction * math.max(1, reach - 1.5))
		return
	end
	local now = os.clock()
	local moved = pathGoal == nil or flat(pathGoal :: Vector3, goal) > GOAL_MOVED
	if not computing and (moved or now - pathAt > PATH_AGE or #points < 2) then
		compute(r.Position, goal)
	end
	if #points < 2 then
		return
	end
	local waypoint = points[walkIndex]
	while waypoint and flat(r.Position, toVector(waypoint)) < Config.Nav.waypointReach and walkIndex < #points do
		walkIndex += 1
		waypoint = points[walkIndex]
	end
	if not waypoint then
		return
	end
	if walkIndex ~= issuedIndex or now - issuedAt > MOVE_TO_REFRESH then
		issuedIndex = walkIndex
		issuedAt = now
		h:MoveTo(toVector(waypoint))
	end
	if waypoint.jump and flat(r.Position, toVector(waypoint)) < 6 then
		h.Jump = true
	end
end

local function monsterById(entityId: string): Model?
	local folder = Workspace:FindFirstChild("Monsters")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("EntityId") == entityId then
			return child
		end
	end
	return nil
end

-- The player takes over: ask the server to stop (it answers with the toast and the cleared state branch).
local function stopByPlayer()
	if not active or stopping then
		return
	end
	stopping = true
	halt()
	TargetController.SetServerDriven(false)
	task.spawn(function()
		local ok, err = Net.Invoke("AutoGrind", false)
		if not ok and err then
			Toast.push(Text.now(err), "error")
		end
	end)
end

local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	stopping = false
	if on then
		NavController.StopWalk(true)
		TargetController.SetServerDriven(true, stopByPlayer)
		if not idleConnection then
			idleConnection = player.Idled:Connect(function()
				pcall(function()
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.zero)
				end)
			end)
		end
	else
		local connection = idleConnection
		if connection then
			connection:Disconnect()
			idleConnection = nil
		end
		TargetController.SetServerDriven(false)
		halt()
	end
end

local function step()
	local runtime = State.Get({ "autoGrind" })
	local on = type(runtime) == "table" and runtime.active == true
	setActive(on)
	if not on or stopping then
		return
	end
	local model = if type(runtime.target) == "string" then monsterById(runtime.target) else nil
	TargetController.ShowServerTarget(model)
	if model then
		local reach = attackRange() + Combat.rangeTolerance * 0.5
		walkTo(model:GetPivot().Position, math.max(2, reach - 1))
		return
	end
	local goal = runtime.goal
	if type(goal) == "table" then
		walkTo(Vector3.new(goal.x, goal.y or 0, goal.z), Config.AutoGrind.arrive * 0.5)
	end
end

-- Whether Auto Hunt runs for this player (the HUD).
function AutoGrindController.IsActive(): boolean
	return active
end

function AutoGrindController.Init(registry)
	TargetController = registry.Get("TargetController")
	NavController = registry.Get("NavController")
	NpcController = registry.Get("NpcController")
end

function AutoGrindController.Start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		if active and TargetController.MoveInput().Magnitude > 0.1 then
			stopByPlayer()
		end
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		local ok, err = pcall(step :: any)
		if not ok then
			warn("[AutoGrind] " .. tostring(err))
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		stopByPlayer()
	end)
	-- talking to an NPC (its service windows) is the player taking over
	scope:Observer(NpcController.Current):onChange(function()
		if Fusion.peek(NpcController.Current) ~= nil then
			stopByPlayer()
		end
	end)
	player.CharacterAdded:Connect(function()
		resetPath()
	end)
end

return AutoGrindController
