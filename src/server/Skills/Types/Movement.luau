--!strict
-- Movement and placement skill types: charge (dash to the target), blink (teleport; Disengage jumps back),
-- trap (object on the ground that roots the first enemies to step in).
-- The server moves the character itself (PivotTo) after raycasting for walls, so clients cannot teleport.

local Workspace = game:GetService("Workspace")

local Context = require(script.Parent.Parent.Context)

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Movement: { [string]: Handler } = {}

local TRAP_CHECK = 0.25

-- Furthest safe point from `from` toward `to` (stops before walls).
local function clearPath(ctx: Ctx, from: Vector3, to: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, name in { "Monsters", "Vaelthorn_Effects", "Vaelthorn_Loot", "Vaelthorn_CombatFx" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	local model = ctx.player.Character
	if model then
		table.insert(exclude, model)
	end
	params.FilterDescendantsInstances = exclude
	local direction = to - from
	local hit = Workspace:Raycast(from, direction, params)
	if hit then
		local back = if direction.Magnitude > 0 then direction.Unit * 2 else Vector3.zero
		return hit.Position - back
	end
	return to
end

local function moveTo(ctx: Ctx, destination: Vector3, lookAt: Vector3?)
	local model = ctx.player.Character
	if not model then
		return
	end
	local face = lookAt or (destination + ctx.root.CFrame.LookVector)
	local flatFace = Vector3.new(face.X, destination.Y, face.Z)
	if (flatFace - destination).Magnitude < 0.1 then
		flatFace = destination + ctx.root.CFrame.LookVector
	end
	model:PivotTo(CFrame.lookAt(destination, flatFace))
end

Movement.charge = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	local position = ctx.services.Entity.Position(target)
	if not position then
		return false, "cast.error.noTarget"
	end
	local from = ctx.root.Position
	local offset = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
	local stopAt = if offset.Magnitude > 3 then position - offset.Unit * 3 else from
	local destination = clearPath(ctx, from, Vector3.new(stopAt.X, from.Y, stopAt.Z))
	ctx.fx({ t = target.id, p = destination, from = from })
	moveTo(ctx, destination, position)
	task.delay(0.15, function()
		local result = ctx.damage(target, ctx.value("dmg"))
		if result and not result.dodged then
			ctx.applyEffects(target, "enemy")
		end
	end)
	return true, nil
end

Movement.blink = function(ctx)
	local from = ctx.root.Position
	local length = ctx.skill.length or 15
	local direction: Vector3
	if ctx.skill.id == "disengage" then
		-- Jump back, away from where the hunter is facing.
		direction = -ctx.root.CFrame.LookVector
	elseif ctx.point then
		direction = ctx.point - from
	else
		direction = ctx.root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		direction = ctx.root.CFrame.LookVector
	end
	local destination = clearPath(ctx, from, from + direction.Unit * length)
	ctx.fx({ p = destination, from = from })
	local lookAt = if ctx.skill.id == "disengage" then from else destination + direction.Unit
	moveTo(ctx, destination, lookAt)
	ctx.applyEffects(ctx.caster, "self")
	return true, nil
end

Movement.trap = function(ctx)
	local at = ctx.ground(ctx.point or ctx.root.Position)
	local radius = ctx.skill.radius or 6
	local lifetime = ctx.scaled(ctx.skill.duration)
	ctx.fx({ p = at, r = radius, d = lifetime })
	local expires = os.clock() + lifetime
	task.spawn(function()
		while os.clock() < expires do
			task.wait(TRAP_CHECK)
			local caught = ctx.enemiesInCircle(at, radius)
			if #caught > 0 then
				for _, entity in caught do
					ctx.applyEffects(entity, "enemy")
				end
				ctx.fx({ v = "trapTrigger", p = at, r = radius })
				return
			end
		end
	end)
	return true, nil
end

return Movement
