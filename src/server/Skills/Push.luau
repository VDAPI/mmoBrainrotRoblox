--!strict
-- Knockback and pull of skills (S28): moves a monster (or a player in PvP, half the distance) along the ground over a
-- short moment. Bosses do not move. A ray along the path stops the move before walls (Logic/Knockback gets the free
-- fraction); the body is put back on the ground at the end and the monster's AI walks on from there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knockback = require(ReplicatedStorage.Shared.Logic.Knockback)

local Push = {}

local SECONDS = 0.22
local moving: { [Model]: boolean } = {}

local function blockers(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, name in { "Monsters", "Vaelthorn_Effects", "Vaelthorn_Loot", "Vaelthorn_CombatFx" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	return params
end

local function modelOf(entity: any): (Model?, BasePart?, string)
	if entity.kind == "monster" and entity.monster then
		local monster = entity.monster
		return monster.model, monster.root, if monster.isBoss then "boss" else "monster"
	end
	if entity.kind == "player" and entity.player then
		local model = entity.player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		return model, root, "player"
	end
	return nil, nil, "boss"
end

-- Moves `entity` horizontally to `goal` (already shortened before walls).
local function slide(entity: any, model: Model, root: BasePart, goal: Vector3)
	if moving[model] then
		return
	end
	moving[model] = true
	local start = root.Position
	local offset = model:GetPivot().Position - start
	local params = blockers()
	local below = Workspace:Raycast(start + Vector3.new(0, 1, 0), Vector3.new(0, -30, 0), params)
	local height = if below then start.Y - below.Position.Y else nil
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if not model.Parent or not root.Parent then
			connection:Disconnect()
			moving[model] = nil
			return
		end
		local u = math.min(1, elapsed / SECONDS)
		local at = start:Lerp(Vector3.new(goal.X, start.Y, goal.Z), Knockback.progress(u))
		model:PivotTo(CFrame.new(at + offset) * model:GetPivot().Rotation)
		if u >= 1 then
			connection:Disconnect()
			moving[model] = nil
			-- back on the ground (the slope may have changed under the path)
			local hit = Workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
			if hit and height then
				local ground = Vector3.new(at.X, hit.Position.Y + height, at.Z)
				model:PivotTo(CFrame.new(ground + offset) * model:GetPivot().Rotation)
			end
			if entity.kind == "monster" and entity.monster and entity.monster.humanoid then
				entity.monster.humanoid:MoveTo(root.Position)
			end
		end
	end)
end

local function freeFraction(from: Vector3, direction: Vector3, distance: number): number
	if distance <= 0 then
		return 0
	end
	local origin = from + Vector3.new(0, 1.5, 0)
	local hit = Workspace:Raycast(origin, direction.Unit * (distance + Knockback.WALL_GAP), blockers())
	if not hit then
		return 1
	end
	return math.clamp((hit.Position - origin).Magnitude / distance, 0, 1)
end

-- Pushes `entity` `distance` studs away from `source` (position). Returns true when it moved.
function Push.knockback(entity: any, source: Vector3, distance: number): boolean
	local model, root, kind = modelOf(entity)
	if not model or not root then
		return false
	end
	local d = Knockback.scaled(distance, kind)
	if d <= 0 then
		return false
	end
	local p = root.Position
	local back = -root.CFrame.LookVector
	local dx, dz = Knockback.direction(p.X, p.Z, source.X, source.Z, back.X, back.Z)
	local direction = Vector3.new(dx, 0, dz)
	local gx, gz = Knockback.destination(p.X, p.Z, dx, dz, d, freeFraction(p, direction, d))
	slide(entity, model, root, Vector3.new(gx, p.Y, gz))
	return true
end

-- Pulls `entity` towards `to` (stops a little short).
function Push.pull(entity: any, to: Vector3): boolean
	local model, root, kind = modelOf(entity)
	if not model or not root then
		return false
	end
	local p = root.Position
	local d = Knockback.scaled(Knockback.pullDistance(p.X, p.Z, to.X, to.Z), kind)
	if d <= 0.5 then
		return false
	end
	local dx, dz = Knockback.direction(to.X, to.Z, p.X, p.Z)
	local direction = Vector3.new(dx, 0, dz)
	local gx, gz = Knockback.destination(p.X, p.Z, dx, dz, d, freeFraction(p, direction, d))
	slide(entity, model, root, Vector3.new(gx, p.Y, gz))
	return true
end

return Push
