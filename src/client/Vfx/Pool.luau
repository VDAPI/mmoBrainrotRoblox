--!strict
-- Part pool of the skill visuals (S28): neon / glass parts of the three shapes are reused instead of created per
-- effect, ParticleEmitters live on pooled anchor parts and only Emit bursts. `budget` caps how many effects run at
-- once (Config.Vfx.maxActive): past it, optional pieces are skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Pool = {}

local folder: Folder? = nil
-- S28: effects of the skill window preview go into its viewport's WorldModel while it plays.
local override: Instance? = nil
local free: { [string]: { BasePart } } = { Block = {}, Ball = {}, Cylinder = {} }
local active = 0
local MAX_FREE = 120

local function container(): Instance
	if override and override.Parent then
		return override
	end
	local f = folder
	if f and f.Parent then
		return f
	end
	local created = Instance.new("Folder")
	created.Name = "Vaelthorn_SkillFx"
	created.Parent = Workspace
	folder = created
	return created
end

Pool.folder = container

-- Sends new pieces into `target` (a WorldModel) instead of the workspace; nil goes back.
function Pool.setOverride(target: Instance?)
	override = target
end

-- A clean anchored part of the shape (Block / Ball / Cylinder), parented and visible.
function Pool.part(
	shape: string?,
	color: Color3,
	size: Vector3,
	material: Enum.Material?,
	transparency: number?
): BasePart
	local key = shape or "Block"
	local list = free[key]
	local p: BasePart = table.remove(list) :: BasePart
	if not p then
		local created = Instance.new("Part")
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.CastShadow = false
		created.TopSurface = Enum.SurfaceType.Smooth
		created.BottomSurface = Enum.SurfaceType.Smooth
		if key ~= "Block" then
			created.Shape = (Enum.PartType :: any)[key]
		end
		p = created
	end
	p.Color = color
	p.Size = size
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0.2
	p.Parent = container()
	return p
end

-- Returns a part to the pool (children such as lights and emitters are destroyed).
function Pool.release(p: BasePart)
	if not p.Parent then
		return
	end
	p:ClearAllChildren()
	p.Parent = nil
	p.Anchored = true
	p.Massless = false
	local key = if p:IsA("Part") then p.Shape.Name else "Block"
	local list = free[key]
	if list and #list < MAX_FREE then
		table.insert(list, p)
	else
		p:Destroy()
	end
end

-- Releases after `seconds`.
function Pool.later(p: BasePart, seconds: number)
	task.delay(seconds, Pool.release, p)
end

-- Effect budget: true when one more effect may start (call done() when it ends).
function Pool.take(): boolean
	if active >= Config.Vfx.maxActive then
		return false
	end
	active += 1
	return true
end

function Pool.done(seconds: number?)
	if seconds and seconds > 0 then
		task.delay(seconds, function()
			active = math.max(0, active - 1)
		end)
	else
		active = math.max(0, active - 1)
	end
end

function Pool.activeCount(): number
	return active
end

return Pool
