--!strict
-- Placeholder props built from Parts (S08). Every prefab takes the build context and a map-relative
-- position on the ground and returns a Model, so real assets can replace them one by one later
-- (buildMode = "asset"). Decorations are anchored, not queryable and small ones cast no shadow.

local CollectionService = game:GetService("CollectionService")

local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Portals = require(game:GetService("ReplicatedStorage").Shared.Data.Portals)
local Build = require(script.Parent.Build)

local Prefabs = {}

type Context = Build.Context

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- Creates an anchored part in `model`. `props` may set any Part property.
local function part(ctx: Context, model: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanQuery = false
	p.CanTouch = false -- S20: decorations never fire touch events
	for key, value in props do
		(p :: any)[key] = value
	end
	if p.Size.Magnitude < 6 then
		p.CastShadow = false
	end
	p.Parent = model
	ctx.parts += 1
	return p
end

local function wedge(ctx: Context, model: Instance, props: { [string]: any }): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanQuery = false
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	ctx.parts += 1
	return p
end

local function newModel(ctx: Context, name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent or ctx.decor
	return model
end

local function light(parentPart: BasePart, color: string, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = hex(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parentPart
end

-- Base CFrame on the ground at x/z, rotated by `rot` degrees.
local function baseAt(ctx: Context, x: number, z: number, rot: number?): CFrame
	return CFrame.new(Build.ground(ctx, x, z)) * CFrame.Angles(0, math.rad(rot or 0), 0)
end

-- Nature -----------------------------------------------------------------------------------------

export type TreeKind = "oak" | "pine" | "birch" | "dead" | "dark" | "willow"

function Prefabs.tree(ctx: Context, x: number, z: number, kind: TreeKind?, scale: number?): Model
	local k = kind or "oak"
	local s = (scale or 1) * ctx.rng:float(0.8, 1.25)
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, `Tree_{k}`)
	table.insert(ctx.trees, { x, z })
	local trunkColor = if k == "birch" then "#D8D2C2" elseif k == "dead" or k == "dark" then "#3A3028" else "#5A4632"
	local height = (if k == "pine" then 14 elseif k == "dead" then 12 else 10) * s
	part(ctx, model, {
		Name = "Trunk",
		Size = Vector3.new(1.8 * s, height, 1.8 * s),
		CFrame = base * CFrame.new(0, height / 2, 0),
		Color = hex(trunkColor),
		Material = Enum.Material.Wood,
		CanQuery = true,
	})
	if k == "pine" then
		for i = 0, 2 do
			local w = (10 - i * 2.8) * s
			part(ctx, model, {
				Name = "Needles",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(w, w * 0.8, w),
				CFrame = base * CFrame.new(0, height * (0.45 + i * 0.22), 0),
				Color = hex("#2F4F2A"),
				Material = Enum.Material.Grass,
			})
		end
	elseif k == "dead" then
		for i = 1, 3 do
			part(ctx, model, {
				Name = "Branch",
				Size = Vector3.new(0.7 * s, 5 * s, 0.7 * s),
				CFrame = base * CFrame.new(0, height * (0.55 + i * 0.12), 0) * CFrame.Angles(0, i * 2.1, math.rad(50)),
				Color = hex("#3A3028"),
				Material = Enum.Material.Wood,
			})
		end
	else
		local crown = if k == "birch"
			then "#8FAF4A"
			elseif k == "dark" then "#26331F"
			elseif k == "willow" then "#5F7D3A"
			else "#3F6B2E"
		local size = (if k == "dark" then 15 else 12) * s
		part(ctx, model, {
			Name = "Crown",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.85, size),
			CFrame = base * CFrame.new(0, height + size * 0.25, 0),
			Color = hex(crown),
			Material = Enum.Material.Grass,
		})
		part(ctx, model, {
			Name = "Crown2",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size * 0.7, size * 0.6, size * 0.7),
			CFrame = base * CFrame.new(size * 0.3, height + size * 0.05, size * 0.15),
			Color = hex(crown),
			Material = Enum.Material.Grass,
		})
	end
	return model
end

function Prefabs.rock(ctx: Context, x: number, z: number, scale: number?, color: string?): Model
	local s = (scale or 1) * ctx.rng:float(0.7, 1.4)
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, "Rock")
	for i = 1, ctx.rng:int(1, 3) do
		local size = Vector3.new(ctx.rng:float(3, 7), ctx.rng:float(2, 5), ctx.rng:float(3, 6)) * s
		part(ctx, model, {
			Name = "Stone",
			Size = size,
			CFrame = base
				* CFrame.new((i - 1) * 2.5 * s, size.Y * 0.35, (i % 2) * 2 * s)
				* CFrame.Angles(ctx.rng:float(-0.3, 0.3), ctx.rng:float(0, 6), ctx.rng:float(-0.3, 0.3)),
			Color = hex(color or "#6B6660"),
			Material = Enum.Material.Slate,
			CanQuery = true,
		})
	end
	return model
end

function Prefabs.bush(ctx: Context, x: number, z: number, color: string?): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Bush")
	local s = ctx.rng:float(0.7, 1.3)
	part(ctx, model, {
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 3, 4) * s,
		CFrame = base * CFrame.new(0, 1 * s, 0),
		Color = hex(color or "#4A7A35"),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	return model
end

-- Buildings --------------------------------------------------------------------------------------

export type HouseOptions = {
	w: number?,
	d: number?,
	h: number?,
	wall: string?,
	roof: string?,
	rot: number?,
	name: string?,
}

function Prefabs.house(ctx: Context, x: number, z: number, o: HouseOptions?): Model
	local opts: HouseOptions = o or {}
	local w, d, h = opts.w or 22, opts.d or 18, opts.h or 12
	local base = baseAt(ctx, x, z, opts.rot)
	local model = newModel(ctx, opts.name or "House", ctx.folder)
	local wall = hex(opts.wall or "#9C8A72")
	local roof = hex(opts.roof or "#6B2F2A")
	part(ctx, model, {
		Name = "Foundation",
		Size = Vector3.new(w + 2, 2, d + 2),
		CFrame = base * CFrame.new(0, 0, 0),
		Color = hex("#6E675C"),
		Material = Enum.Material.Cobblestone,
		CanQuery = true,
	})
	part(ctx, model, {
		Name = "Walls",
		Size = Vector3.new(w, h, d),
		CFrame = base * CFrame.new(0, h / 2 + 1, 0),
		Color = wall,
		Material = Enum.Material.Plaster,
		CanQuery = true,
	})
	-- Timber frame strips
	for _, sx in { -1, 1 } do
		part(ctx, model, {
			Name = "Beam",
			Size = Vector3.new(1, h, d + 0.4),
			CFrame = base * CFrame.new(sx * (w / 2 - 0.4), h / 2 + 1, 0),
			Color = hex("#4A3828"),
			Material = Enum.Material.Wood,
		})
	end
	-- Gable roof from two wedges
	local roofH = h * 0.6
	for _, side in { -1, 1 } do
		wedge(ctx, model, {
			Name = "Roof",
			Size = Vector3.new(w + 3, roofH, d / 2 + 1.5),
			CFrame = base
				* CFrame.new(0, h + 1 + roofH / 2, side * (d / 4 + 0.75))
				* CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Color = roof,
			Material = Enum.Material.Slate,
		})
	end
	-- Door and windows on the front (-Z) side
	part(ctx, model, {
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = base * CFrame.new(0, 4.5, -d / 2 - 0.2),
		Color = hex("#3E2A1E"),
		Material = Enum.Material.Wood,
	})
	for _, sx in { -1, 1 } do
		local window = part(ctx, model, {
			Name = "Window",
			Size = Vector3.new(3, 3, 0.3),
			CFrame = base * CFrame.new(sx * w / 4, h * 0.6 + 1, -d / 2 - 0.2),
			Color = hex("#F2C46B"),
			Material = Enum.Material.Neon,
			Transparency = 0.2,
		})
		if sx == 1 then
			light(window, "#F2C46B", 14, 0.6)
		end
	end
	Build.rect(ctx, x, z, w, d, "building", opts.rot)
	return model
end

function Prefabs.tower(ctx: Context, x: number, z: number, radius: number?, height: number?, color: string?): Model
	local r, h = radius or 6, height or 28
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Tower", ctx.folder)
	part(ctx, model, {
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, r * 2, r * 2),
		CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex(color or "#8A8278"),
		Material = Enum.Material.Cobblestone,
		CanQuery = true,
	})
	part(ctx, model, {
		Name = "Top",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, r * 2 + 3, r * 2 + 3),
		CFrame = base * CFrame.new(0, h + 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex("#6E675C"),
		Material = Enum.Material.Cobblestone,
	})
	Build.rect(ctx, x, z, r * 2, r * 2, "building")
	return model
end

function Prefabs.tent(ctx: Context, x: number, z: number, color: string?, rot: number?): Model
	local base = baseAt(ctx, x, z, rot or ctx.rng:float(0, 360))
	local model = newModel(ctx, "Tent", ctx.folder)
	for _, side in { -1, 1 } do
		wedge(ctx, model, {
			Name = "Cloth",
			Size = Vector3.new(10, 7, 5),
			CFrame = base * CFrame.new(0, 3.5, side * 2.5) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			Color = hex(color or "#8A6B4A"),
			Material = Enum.Material.Fabric,
			CanQuery = true,
		})
	end
	Build.rect(ctx, x, z, 10, 10, "building")
	return model
end

function Prefabs.ruins(ctx: Context, x: number, z: number, color: string?): Model
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, "Ruins", ctx.folder)
	local c = hex(color or "#7A7468")
	for i = 1, 5 do
		local h = ctx.rng:float(3, 14)
		part(ctx, model, {
			Name = "Pillar",
			Size = Vector3.new(3, h, 3),
			CFrame = base
				* CFrame.new(math.cos(i * 1.25) * 12, h / 2, math.sin(i * 1.25) * 12)
				* CFrame.Angles(ctx.rng:float(-0.1, 0.1), 0, ctx.rng:float(-0.12, 0.12)),
			Color = c,
			Material = Enum.Material.Cobblestone,
			CanQuery = true,
		})
	end
	part(ctx, model, {
		Name = "BrokenWall",
		Size = Vector3.new(16, 6, 2.5),
		CFrame = base * CFrame.new(0, 3, -12),
		Color = c,
		Material = Enum.Material.Cobblestone,
		CanQuery = true,
	})
	Build.rect(ctx, x, z, 26, 26, "ruins")
	return model
end

function Prefabs.palisade(ctx: Context, ax: number, az: number, bx: number, bz: number): Model
	local model = newModel(ctx, "Palisade", ctx.folder)
	local dx, dz = bx - ax, bz - az
	local length = math.sqrt(dx * dx + dz * dz)
	local n = math.floor(length / 2.2)
	for i = 0, n do
		local t = i / math.max(1, n)
		local px, pz = ax + dx * t, az + dz * t
		local h = 9 + (i % 3)
		part(ctx, model, {
			Name = "Log",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 2, 2),
			CFrame = CFrame.new(Build.ground(ctx, px, pz) + Vector3.new(0, h / 2 - 0.5, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = hex("#5A4632"),
			Material = Enum.Material.Wood,
			CanQuery = true,
		})
	end
	table.insert(ctx.sketch.shapes, { t = "line", p = { ax, az, bx, bz }, w = 2, c = "wall" })
	return model
end

function Prefabs.bridge(ctx: Context, x: number, z: number, length: number, rot: number?): Model
	local base = CFrame.new(Build.at(ctx, x, 0.6, z)) * CFrame.Angles(0, math.rad(rot or 0), 0)
	local model = newModel(ctx, "Bridge", ctx.folder)
	part(ctx, model, {
		Name = "Deck",
		Size = Vector3.new(length, 1, 10),
		CFrame = base,
		Color = hex("#7A5A3E"),
		Material = Enum.Material.WoodPlanks,
		CanQuery = true,
	})
	for _, side in { -1, 1 } do
		part(ctx, model, {
			Name = "Rail",
			Size = Vector3.new(length, 0.6, 0.6),
			CFrame = base * CFrame.new(0, 3, side * 4.7),
			Color = hex("#5A4632"),
			Material = Enum.Material.Wood,
		})
	end
	return model
end

function Prefabs.jetty(ctx: Context, x: number, z: number, rot: number?): Model
	local base = CFrame.new(Build.at(ctx, x, 0.4, z)) * CFrame.Angles(0, math.rad(rot or 0), 0)
	local model = newModel(ctx, "Jetty", ctx.folder)
	part(ctx, model, {
		Name = "Deck",
		Size = Vector3.new(5, 0.8, 18),
		CFrame = base,
		Color = hex("#8A6B4A"),
		Material = Enum.Material.WoodPlanks,
		CanQuery = true,
	})
	return model
end

function Prefabs.lantern(ctx: Context, x: number, z: number, color: string?): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Lantern")
	part(ctx, model, {
		Name = "Post",
		Size = Vector3.new(0.6, 9, 0.6),
		CFrame = base * CFrame.new(0, 4.5, 0),
		Color = hex("#2E2E32"),
		Material = Enum.Material.Metal,
	})
	local lamp = part(ctx, model, {
		Name = "Lamp",
		Size = Vector3.new(1.4, 1.6, 1.4),
		CFrame = base * CFrame.new(0, 9.4, 0),
		Color = hex(color or "#FFD27A"),
		Material = Enum.Material.Neon,
	})
	light(lamp, color or "#FFD27A", 22, 1.2)
	return model
end

function Prefabs.torch(ctx: Context, x: number, z: number, color: string?): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Torch")
	part(ctx, model, {
		Name = "Stick",
		Size = Vector3.new(0.5, 5, 0.5),
		CFrame = base * CFrame.new(0, 2.5, 0),
		Color = hex("#4A3828"),
		Material = Enum.Material.Wood,
	})
	local flame = part(ctx, model, {
		Name = "Flame",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = base * CFrame.new(0, 5.4, 0),
		Color = hex(color or "#FF9A3A"),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	light(flame, color or "#FF9A3A", 26, 1.6)
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 4
	fire.Parent = flame
	return model
end

function Prefabs.campfire(ctx: Context, x: number, z: number): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Campfire")
	for i = 1, 3 do
		part(ctx, model, {
			Name = "Log",
			Size = Vector3.new(4, 0.8, 0.8),
			CFrame = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, i * 1.05, 0),
			Color = hex("#4A3828"),
			Material = Enum.Material.Wood,
		})
	end
	local core = part(ctx, model, {
		Name = "Embers",
		Size = Vector3.new(1.5, 0.5, 1.5),
		CFrame = base * CFrame.new(0, 0.7, 0),
		Color = hex("#FF6A1A"),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	light(core, "#FF8A3A", 24, 1.5)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Parent = core
	return model
end

function Prefabs.crystal(ctx: Context, x: number, z: number, color: string, scale: number?): Model
	local s = (scale or 1) * ctx.rng:float(0.7, 1.3)
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, "Crystal")
	for i = 1, 3 do
		local h = ctx.rng:float(3, 7) * s
		local p = part(ctx, model, {
			Name = "Shard",
			Size = Vector3.new(1.4 * s, h, 1.4 * s),
			CFrame = base
				* CFrame.new(i - 2, h / 2 - 0.5, (i % 2) - 0.5)
				* CFrame.Angles(ctx.rng:float(-0.4, 0.4), 0, ctx.rng:float(-0.4, 0.4)),
			Color = hex(color),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		if i == 2 then
			light(p, color, 20, 1)
		end
	end
	return model
end

function Prefabs.column(ctx: Context, x: number, z: number, height: number, color: string?): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Column", ctx.folder)
	part(ctx, model, {
		Name = "Shaft",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 4, 4),
		CFrame = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex(color or "#6E6878"),
		Material = Enum.Material.Cobblestone,
		CanQuery = true,
	})
	return model
end

function Prefabs.tombstone(ctx: Context, x: number, z: number): Model
	local base = baseAt(ctx, x, z, ctx.rng:float(-15, 15))
	local model = newModel(ctx, "Tombstone")
	part(ctx, model, {
		Name = "Stone",
		Size = Vector3.new(2.6, 3.6, 0.8),
		CFrame = base * CFrame.new(0, 1.6, 0) * CFrame.Angles(ctx.rng:float(-0.15, 0.15), 0, ctx.rng:float(-0.1, 0.1)),
		Color = hex("#5E5A64"),
		Material = Enum.Material.Slate,
	})
	return model
end

function Prefabs.flag(ctx: Context, x: number, z: number, color: string): Model
	local base = baseAt(ctx, x, z)
	local model = newModel(ctx, "Flag")
	part(ctx, model, {
		Name = "Pole",
		Size = Vector3.new(0.5, 16, 0.5),
		CFrame = base * CFrame.new(0, 8, 0),
		Color = hex("#C9A45C"),
		Material = Enum.Material.Metal,
	})
	local cloth = part(ctx, model, {
		Name = "Cloth",
		Size = Vector3.new(5, 3.2, 0.2),
		CFrame = base * CFrame.new(2.7, 14, 0),
		Color = hex(color),
		Material = Enum.Material.Fabric,
	})
	cloth.CanCollide = false
	return model
end

-- Portals and gates -------------------------------------------------------------------------------

-- Turns `model` into a portal with `field` as its clickable part (S21: shared by the portal arches and the
-- city gates): sparkles, PrimaryPart, the PortalId / TargetMap / ArriveX / ArriveZ attributes read by
-- WorldBuilder.collect, the "Portal" tag (WorldController adds the prompt) and the map icon at x/z.
function Prefabs.makePortal(
	ctx: Context,
	model: Model,
	field: BasePart,
	id: string,
	target: string,
	x: number,
	z: number,
	arrive: { x: number, z: number }?
)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(hex("#B9A8FF"))
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Rate = 18
	sparkles.LightEmission = 1
	sparkles.Parent = field
	-- Atomic: WorldController.decoratePortal needs the PrimaryPart when the tag arrives on the client.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.PrimaryPart = field
	model:SetAttribute("PortalId", id)
	model:SetAttribute("TargetMap", target)
	if arrive then
		model:SetAttribute("ArriveX", arrive.x)
		model:SetAttribute("ArriveZ", arrive.z)
	end
	CollectionService:AddTag(model, "Portal")
	Build.icon(ctx, "portal", x, z, target)
end

-- Portal arch (tag "Portal", attributes PortalId, TargetMap, ArriveX/ArriveZ = arrival point on the
-- target map, map-relative; defaults to the target map's spawn).
function Prefabs.portal(
	ctx: Context,
	id: string,
	target: string,
	x: number,
	z: number,
	rot: number?,
	arrive: { x: number, z: number }?
): Model
	if ctx.rayFrom > 20 then
		-- Outdoors: flat ground under the portal (S19); caves are carved flat already.
		Build.flatten(ctx, x, z, 14)
	end
	local base = baseAt(ctx, x, z, rot)
	local model = newModel(ctx, `Portal_{id}`, ctx.folder)
	local stone = hex("#5E5A64")
	for _, side in { -1, 1 } do
		part(ctx, model, {
			Name = "Pillar",
			Size = Vector3.new(2.5, 15, 2.5),
			CFrame = base * CFrame.new(side * 6, 7.5, 0),
			Color = stone,
			Material = Enum.Material.Slate,
			CanQuery = true,
		})
	end
	part(ctx, model, {
		Name = "Lintel",
		Size = Vector3.new(15, 2.5, 3),
		CFrame = base * CFrame.new(0, 16, 0),
		Color = stone,
		Material = Enum.Material.Slate,
	})
	local field = part(ctx, model, {
		Name = "Field",
		Size = Vector3.new(9.5, 13.5, 0.4),
		CFrame = base * CFrame.new(0, 7.5, 0),
		Color = hex("#7A5CFF"),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	field.CanQuery = true
	light(field, "#8A6CFF", 20, 1.2)
	Prefabs.makePortal(ctx, model, field, id, target, x, z, arrive)
	return model
end

-- Portal arch from Data/Portals (S25: one source of truth with the route between maps and the world map).
function Prefabs.portalFrom(ctx: Context, id: string): Model?
	local portal = Portals.get(id)
	if not portal or portal.map ~= ctx.map.id then
		warn(`[Prefabs] no portal {id} on {ctx.map.id} in Data/Portals`)
		return nil
	end
	return Prefabs.portal(ctx, portal.id, portal.target, portal.x, portal.z, portal.rot, portal.arrive)
end

-- Signpost (S19): a post with a board; clients write the localized name and levels on it (tag "Signpost",
-- attributes NameKey, LvMin, LvMax).
function Prefabs.signpost(
	ctx: Context,
	x: number,
	z: number,
	rot: number?,
	nameKey: string,
	lvMin: number?,
	lvMax: number?
): Model
	local base = baseAt(ctx, x, z, rot)
	local model = newModel(ctx, "Signpost", ctx.folder)
	part(ctx, model, {
		Name = "Post",
		Size = Vector3.new(0.6, 7, 0.6),
		CFrame = base * CFrame.new(0, 3.5, 0),
		Color = hex("#5A4632"),
		Material = Enum.Material.Wood,
	})
	local board = part(ctx, model, {
		Name = "Board",
		Size = Vector3.new(7, 2.6, 0.3),
		CFrame = base * CFrame.new(0, 6, -0.4),
		Color = hex("#8A6B4A"),
		Material = Enum.Material.Wood,
	})
	model.PrimaryPart = board
	model:SetAttribute("NameKey", nameKey)
	if lvMin and lvMax then
		model:SetAttribute("LvMin", lvMin)
		model:SetAttribute("LvMax", lvMax)
	end
	CollectionService:AddTag(model, "Signpost")
	return model
end

-- Cave mouth (S19): a rock arch around a dark opening with torches and a sign. The opening looks towards
-- `rot` (0 = -Z). The portal into the cave stands in the opening (placed by the caller).
function Prefabs.caveMouth(
	ctx: Context,
	x: number,
	z: number,
	rot: number,
	nameKey: string,
	lvMin: number,
	lvMax: number,
	rockColor: string?
): Model
	Build.flatten(ctx, x, z, 26)
	local base = baseAt(ctx, x, z, rot)
	local model = newModel(ctx, "CaveMouth", ctx.folder)
	local rock = hex(rockColor or "#5A5650")
	-- Back wall of rock and the dark hole
	part(ctx, model, {
		Name = "Back",
		Size = Vector3.new(30, 24, 10),
		CFrame = base * CFrame.new(0, 10, 8),
		Color = rock,
		Material = Enum.Material.Slate,
		CanQuery = true,
	})
	part(ctx, model, {
		Name = "Hole",
		Size = Vector3.new(14, 15, 0.4),
		CFrame = base * CFrame.new(0, 7.5, 2.9),
		Color = hex("#050506"),
		Material = Enum.Material.SmoothPlastic,
	})
	-- Arch: two pillars of stacked boulders and a lintel
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			part(ctx, model, {
				Name = "Boulder",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (7 - i),
				CFrame = base * CFrame.new(side * (9 + i * 0.6), 3 + i * 5.5, 1),
				Color = rock,
				Material = Enum.Material.Slate,
				CanQuery = true,
			})
		end
	end
	part(ctx, model, {
		Name = "Lintel",
		Size = Vector3.new(24, 4, 6),
		CFrame = base * CFrame.new(0, 17, 1) * CFrame.Angles(0, 0, math.rad(4)),
		Color = rock,
		Material = Enum.Material.Slate,
	})
	-- Rocks around the mouth
	for _, offset in { { -16, 6 }, { 16, 5 }, { -14, -4 }, { 15, -3 } } do
		local p = base * CFrame.new(offset[1], 0, offset[2])
		Prefabs.rock(ctx, p.Position.X - ctx.origin.X, p.Position.Z - ctx.origin.Z, 1.6, rockColor)
	end
	-- Torches and the sign in front
	for _, side in { -1, 1 } do
		local p = base * CFrame.new(side * 9, 0, -6)
		Prefabs.torch(ctx, p.Position.X - ctx.origin.X, p.Position.Z - ctx.origin.Z)
	end
	local sign = base * CFrame.new(-13, 0, -14)
	Prefabs.signpost(
		ctx,
		sign.Position.X - ctx.origin.X,
		sign.Position.Z - ctx.origin.Z,
		rot + 180,
		nameKey,
		lvMin,
		lvMax
	)
	Build.icon(ctx, "cave", x, z)
	return model
end

-- Small props (S20) -----------------------------------------------------------------------------------

function Prefabs.barrel(ctx: Context, x: number, z: number): Model
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, "Barrel")
	part(ctx, model, {
		Name = "Body",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 2.4, 2.4),
		CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = hex("#7A5A3A"),
		Material = Enum.Material.Wood,
	})
	return model
end

function Prefabs.crate(ctx: Context, x: number, z: number): Model
	local s = ctx.rng:float(1.8, 2.6)
	local base = baseAt(ctx, x, z, ctx.rng:float(0, 360))
	local model = newModel(ctx, "Crate")
	part(ctx, model, {
		Name = "Box",
		Size = Vector3.new(s, s, s),
		CFrame = base * CFrame.new(0, s / 2, 0),
		Color = hex("#9A7A4A"),
		Material = Enum.Material.WoodPlanks,
	})
	return model
end

function Prefabs.wagon(ctx: Context, x: number, z: number, rot: number?): Model
	local base = baseAt(ctx, x, z, rot or ctx.rng:float(0, 360))
	local model = newModel(ctx, "Wagon")
	part(ctx, model, {
		Name = "Bed",
		Size = Vector3.new(5, 1.4, 9),
		CFrame = base * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(8)),
		Color = hex("#6B4A2B"),
		Material = Enum.Material.WoodPlanks,
		CanQuery = true,
	})
	for _, wheel in { { -2.8, -3 }, { 2.8, -3 }, { -2.8, 3 } } do
		part(ctx, model, {
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 3, 3),
			CFrame = base * CFrame.new(wheel[1], 1.5, wheel[2]),
			Color = hex("#3A2E24"),
			Material = Enum.Material.Wood,
		})
	end
	return model
end

-- Landmark of a monster area (S20, DESIGN §3.6): camp, ruins, watchtower, stone circle, wagon wreck,
-- nest, mine shaft or graveyard.
function Prefabs.landmark(ctx: Context, kind: string, x: number, z: number, color: string?)
	if kind == "camp" then
		Prefabs.tent(ctx, x - 8, z - 4, color or "#6B4A2B")
		Prefabs.tent(ctx, x + 8, z - 6, color or "#6B4A2B")
		Prefabs.campfire(ctx, x, z + 4)
		Prefabs.barrel(ctx, x + 12, z + 6)
		Prefabs.crate(ctx, x - 12, z + 7)
	elseif kind == "ruins" then
		Prefabs.ruins(ctx, x, z, color)
	elseif kind == "watchtower" then
		Prefabs.tower(ctx, x, z, 5, 22, color or "#6A5A48")
		Prefabs.crate(ctx, x + 7, z + 2)
	elseif kind == "stonecircle" then
		for i = 1, 7 do
			local angle = i * math.pi * 2 / 7
			Prefabs.column(ctx, x + math.cos(angle) * 10, z + math.sin(angle) * 10, 7 + (i % 3) * 2, color or "#8A8478")
		end
	elseif kind == "wagon" then
		Prefabs.wagon(ctx, x, z)
		Prefabs.barrel(ctx, x + 5, z + 6)
		Prefabs.crate(ctx, x - 5, z + 7)
	elseif kind == "nest" then
		for i = 1, 9 do
			local angle = i * math.pi * 2 / 9
			Prefabs.rock(ctx, x + math.cos(angle) * 6, z + math.sin(angle) * 6, 0.7, color or "#6B5A40")
		end
		Prefabs.bush(ctx, x, z, "#5A4A30")
	elseif kind == "mineshaft" then
		Prefabs.column(ctx, x - 5, z, 9, "#6B4A2B")
		Prefabs.column(ctx, x + 5, z, 9, "#6B4A2B")
		local base = baseAt(ctx, x, z)
		local model = newModel(ctx, "MineShaft")
		part(ctx, model, {
			Name = "Beam",
			Size = Vector3.new(12, 1.2, 1.2),
			CFrame = base * CFrame.new(0, 9, 0),
			Color = hex("#6B4A2B"),
			Material = Enum.Material.Wood,
		})
		part(ctx, model, {
			Name = "Hole",
			Size = Vector3.new(8, 8, 0.4),
			CFrame = base * CFrame.new(0, 4, 0.6),
			Color = hex("#0A0A0C"),
			Material = Enum.Material.SmoothPlastic,
		})
		Prefabs.wagon(ctx, x + 10, z + 8, 90)
	elseif kind == "graveyard" then
		for i = 0, 7 do
			Prefabs.tombstone(ctx, x - 12 + (i % 4) * 8, z - 4 + math.floor(i / 4) * 8)
		end
	end
	Build.icon(ctx, "landmark", x, z, kind)
end

-- Landmark kind for an area without one: from its main monster kind.
local LANDMARK_BY_KIND: { [string]: string } = {
	rabbit = "stonecircle",
	wolf = "nest",
	lynx = "nest",
	swampToad = "wagon",
	boar = "nest",
	carrionCrow = "stonecircle",
	bandit = "camp",
	koboldMiner = "mineshaft",
	goblinScout = "camp",
	brownBear = "nest",
	werewolf = "nest",
	blackBear = "nest",
	forestWraith = "graveyard",
	ghoul = "graveyard",
	rotEnt = "stonecircle",
	darkCultist = "stonecircle",
	bogSerpent = "wagon",
	swampTroll = "camp",
	marshWitch = "stonecircle",
	bloodBat = "ruins",
	salamander = "nest",
	wasteHyena = "wagon",
	ashOrc = "camp",
	ashVulture = "nest",
	fireGolem = "ruins",
	fireImp = "ruins",
	desertScorpion = "wagon",
	desertMummy = "graveyard",
	wyvern = "nest",
	basilisk = "ruins",
	iceWolf = "nest",
	snowLeopard = "nest",
	yeti = "camp",
	peakHarpy = "nest",
	frostGiant = "ruins",
	iceElemental = "stonecircle",
	iceMammoth = "camp",
	dragonspawn = "ruins",
	frozenKnight = "watchtower",
	frostWyrm = "ruins",
}

-- Signposts where roads enter monster areas, a landmark in every area without one, lanterns along the
-- roads (S20, DESIGN §3.6–§3.7). S45: `options.lanterns = false` leaves the road lanterns to the map's generator.
function Prefabs.areaFeatures(ctx: Context, data: Areas.MapAreas, color: string?, options: { lanterns: boolean? }?)
	local clear = Build.clearOf(data, 4)
	local signs: { { number } } = {}
	local function farFromSigns(x: number, z: number): boolean
		for _, other in signs do
			if (x - other[1]) ^ 2 + (z - other[2]) ^ 2 < 60 * 60 then
				return false
			end
		end
		return true
	end
	for _, area in data.areas do
		local r = area.rect
		local placed = 0
		for _, road in data.roads do
			local p = road.points
			for i = 1, #p - 3, 2 do
				local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
				local aInside = ax >= r[1] and ax <= r[3] and az >= r[2] and az <= r[4]
				local bInside = bx >= r[1] and bx <= r[3] and bz >= r[2] and bz <= r[4]
				if aInside ~= bInside and placed < 2 then
					-- Walk along the segment to the edge, then 12 studs inside, beside the road.
					local fromX, fromZ = if aInside then bx else ax, if aInside then bz else az
					local toX, toZ = if aInside then ax else bx, if aInside then az else bz
					local length = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
					local dx, dz = (toX - fromX) / length, (toZ - fromZ) / length
					local x, z = fromX, fromZ
					for step = 0, math.floor(length) do
						x, z = fromX + dx * step, fromZ + dz * step
						if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
							break
						end
					end
					x, z = x + dx * 12 - dz * (road.width / 2 + 4), z + dz * 12 + dx * (road.width / 2 + 4)
					if farFromSigns(x, z) and not (ctx.wet and ctx.wet(x, z)) then
						local facing = math.deg(math.atan2(dx, dz)) + 180
						Prefabs.signpost(ctx, x, z, facing, area.nameKey, area.lv[1], area.lv[2])
						table.insert(signs, { x, z })
						placed += 1
					end
				end
			end
		end
		if not area.landmark then
			local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			for attempt = 0, 30 do
				local angle = attempt * 2.4
				local distance = attempt * 8
				local x, z = cx + math.cos(angle) * distance, cz + math.sin(angle) * distance
				if x > r[1] + 20 and x < r[3] - 20 and z > r[2] + 20 and z < r[4] - 20 and clear(x, z) then
					Prefabs.landmark(ctx, LANDMARK_BY_KIND[area.kinds[1]] or "stonecircle", x, z, color)
					break
				end
			end
		end
	end
	-- Lanterns along the roads, alternating sides.
	if options and options.lanterns == false then
		return
	end
	for _, road in data.roads do
		local p = road.points
		local carried = 0
		local side = 1
		for i = 1, #p - 3, 2 do
			local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
			local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local dx, dz = (bx - ax) / length, (bz - az) / length
			local t = 140 - carried
			while t < length do
				local offset = road.width / 2 + 3
				local x, z = ax + dx * t - dz * offset * side, az + dz * t + dx * offset * side
				local dry = not (ctx.wet and ctx.wet(x, z))
				if dry and math.abs(x) < ctx.map.size.x / 2 - 30 and math.abs(z) < ctx.map.size.z / 2 - 30 then
					Prefabs.lantern(ctx, x, z)
				end
				side = -side
				t += 140
			end
			carried = length - (t - 140)
		end
	end
end

-- Cave mouth, sign and portal for every cave entrance of a region map (S19, Data/Areas). S45: with
-- `options.mouth = false` the generic rock arch is left out (the map's generator dresses the mouth); the portal,
-- the sign and the map icon stay.
function Prefabs.caveEntrances(ctx: Context, data: Areas.MapAreas, rockColor: string?, options: { mouth: boolean? }?)
	for _, entrance in data.caves do
		local cave = Areas.caves.get(entrance.cave)
		if cave and options and options.mouth == false then
			local base = baseAt(ctx, entrance.x, entrance.z, entrance.rot)
			local sign = base * CFrame.new(-13, 0, -14)
			Prefabs.signpost(
				ctx,
				sign.Position.X - ctx.origin.X,
				sign.Position.Z - ctx.origin.Z,
				entrance.rot + 180,
				cave.nameKey,
				cave.levels[1],
				cave.levels[2]
			)
			Build.icon(ctx, "cave", entrance.x, entrance.z)
			Prefabs.portal(ctx, `{ctx.map.id}_{entrance.cave}`, entrance.cave, entrance.x, entrance.z, entrance.rot)
		elseif cave then
			Prefabs.caveMouth(
				ctx,
				entrance.x,
				entrance.z,
				entrance.rot,
				cave.nameKey,
				cave.levels[1],
				cave.levels[2],
				rockColor
			)
			Prefabs.portal(ctx, `{ctx.map.id}_{entrance.cave}`, entrance.cave, entrance.x, entrance.z, entrance.rot)
		end
	end
end

-- Dungeon gate of a region from Data/Portals (S25).
function Prefabs.dungeonGateFrom(ctx: Context, region: string): Model?
	local gate = Portals.get(`dungeon_{region}`)
	if not gate or gate.map ~= ctx.map.id then
		warn(`[Prefabs] no dungeon gate for {region} on {ctx.map.id} in Data/Portals`)
		return nil
	end
	return Prefabs.dungeonGate(ctx, region, gate.x, gate.z, gate.rot)
end

-- Boss dungeon entrance (S09 handles entering; tag "DungeonEntrance", attribute DungeonRegion).
function Prefabs.dungeonGate(ctx: Context, region: string, x: number, z: number, rot: number?): Model
	local base = baseAt(ctx, x, z, rot)
	local model = newModel(ctx, `Dungeon_{region}`, ctx.folder)
	for _, side in { -1, 1 } do
		local horn = part(ctx, model, {
			Name = "Horn",
			Size = Vector3.new(3, 18, 3),
			CFrame = base * CFrame.new(side * 8, 8, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)),
			Color = hex("#2A2428"),
			Material = Enum.Material.Basalt,
			CanQuery = true,
		})
		local _ = horn
	end
	local door = part(ctx, model, {
		Name = "Door",
		Size = Vector3.new(12, 15, 0.6),
		CFrame = base * CFrame.new(0, 7.5, 0),
		Color = hex("#D64A3E"),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = true,
	})
	door.CanQuery = true
	light(door, "#D64A3E", 26, 1.6)
	model.PrimaryPart = door
	model:SetAttribute("DungeonRegion", region)
	CollectionService:AddTag(model, "DungeonEntrance")
	Build.icon(ctx, "dungeon", x, z, region)
	return model
end

return Prefabs
