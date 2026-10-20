--!strict
-- Turns TownGen Blueprints into Parts (S21). Shared by both sides: the server builds the "shell" level of every
-- city Build when the map is built; the client builds "detail" and "fine" near the camera. The pieces and their
-- order are deterministic, so both sides agree without sending anything over the network.
--
-- Piece format: src/shared/Logic/TownGen/Blueprint.luau. World frame of a piece:
--   CFrame.new(origin + at) * CFrame.Angles(0, rad(at.rot), 0) * CFrame.new(p, r[1..9])
-- Uneven balls (ellipsoids: tree crowns, bushes, haystacks) are Blocks with a Sphere SpecialMesh, because a Part
-- with Shape = Ball is always a sphere.

local CollectionService = game:GetService("CollectionService")

local KitAssets = require(script.Parent.KitAssets)

local BlueprintBuild = {}

-- CollectionService tag on every piece with a client behaviour; the behaviour name is in the "Fx" attribute
-- ("window", "lamp", "fire", "smoke", "flag", "wheel", "wheelAxle", "sail", "sailAxle", "water", "portal") and the
-- Build name in the "Build" attribute (rotating parts find their axle by it: the windmill's sails are split
-- between the server shell and the client detail models).
BlueprintBuild.FX_TAG = "TownFx"

export type Lods = { shell: boolean?, detail: boolean?, fine: boolean? }

export type Build = {
	name: string,
	bp: any, -- TownGen Blueprint: { pieces, lights, shell, detail, fine }
	at: { x: number, y: number, z: number, rot: number },
	tag: string?,
	gate: any?,
}

export type Result = {
	model: Model?,
	parts: number,
	tagged: { [string]: { BasePart } },
}

-- Yields with task.wait() after every `every` parts (shared across calls); nil never yields.
export type Pacer = { every: number, left: number }

local colors: { [string]: Color3 } = {}
local materials: { [string]: Enum.Material } = {}

local function colorOf(hex: string): Color3
	local c = colors[hex]
	if not c then
		c = Color3.fromHex(hex)
		colors[hex] = c
	end
	return c
end

local function materialOf(name: string): Enum.Material
	local m = materials[name]
	if not m then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		m = if ok and typeof(value) == "EnumItem" then value :: Enum.Material else Enum.Material.SmoothPlastic
		materials[name] = m
	end
	return m :: Enum.Material
end

-- Building frame (map offset + at) for a Build.
function BlueprintBuild.frame(build: Build, origin: Vector3): CFrame
	local at = build.at
	return CFrame.new(origin.X + at.x, origin.Y + at.y, origin.Z + at.z) * CFrame.Angles(0, math.rad(at.rot), 0)
end

local function makePart(piece: any): BasePart
	local s = piece.s
	local size = piece.size
	local part: BasePart
	if s == "wedge" then
		part = Instance.new("WedgePart")
	elseif s == "corner" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if s == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif s == "ball" then
			if math.abs(size[1] - size[2]) < 0.01 and math.abs(size[1] - size[3]) < 0.01 then
				p.Shape = Enum.PartType.Ball
			else
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		part = p
	end
	part.Size = Vector3.new(size[1], size[2], size[3])
	return part
end

-- Builds the pieces of `build` whose LOD is enabled in `lods` into a new Model named after the Build, parented to
-- `parent`. Lights come with the "detail" level, except portal lights, which come with "shell". Returns the model
-- (nil when nothing matched), the number of parts and the parts with a behaviour tag, grouped by tag.
-- W02: with a `kit` resolver (Util/KitAssets.resolver), every kit slot of the Blueprint that has a model gets that
-- model on the slot's level instead of its pieces; the slot's colliding shell pieces stay as invisible collision.
-- W29: `drop(slot, foot)` (foot = the slot's world position) true leaves a kit slot out entirely (its model and its
-- pieces): the client thins its filler trees and undergrowth at a low graphics level (Logic/GraphicsLevel.keepSlot).
function BlueprintBuild.build(
	build: Build,
	origin: Vector3,
	lods: Lods,
	parent: Instance,
	pacer: Pacer?,
	kit: KitAssets.Resolver?,
	drop: ((slot: any, foot: Vector3) -> boolean)?
): Result
	local result: Result = { model = nil, parts = 0, tagged = {} }
	local bp = build.bp
	local model: Model? = nil
	local base = BlueprintBuild.frame(build, origin)
	-- W02: the slots that get a kit model (index -> placement)
	local placed: { [number]: KitAssets.Placement } = {}
	local slots = bp.kits
	-- W29: the slots left out at this graphics level
	local dropped: { [number]: boolean } = {}
	if drop and slots then
		for i, slot in slots do
			if slot.lod ~= "shell" and drop(slot, base * Vector3.new(slot.p[1], slot.p[2], slot.p[3])) then
				dropped[i] = true
			end
		end
	end
	if kit and slots then
		for i, slot in slots do
			if dropped[i] then
				continue
			end
			local placement = kit(slot, base)
			if placement then
				placed[i] = placement
			end
		end
	end
	local function ensureModel(): Model
		if not model then
			local m = Instance.new("Model")
			m.Name = build.name
			model = m
		end
		return model :: Model
	end
	for _, piece in bp.pieces do
		if not (lods :: any)[piece.lod] then
			continue
		end
		if piece.k ~= nil and dropped[piece.k] then
			continue
		end
		local hidden = piece.k ~= nil and placed[piece.k] ~= nil
		if hidden and not (piece.col and piece.lod == "shell") then
			continue -- W02: drawn by the kit model
		end
		local part = makePart(piece)
		local p, r = piece.p, piece.r
		part.CFrame = base * CFrame.new(p[1], p[2], p[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
		part.Color = colorOf(piece.c)
		part.Material = materialOf(piece.m)
		part.Anchored = true
		part.CanCollide = piece.col
		-- CanQuery only matters for non-colliding parts; keep clicks and camera rays off decorations
		part.CanQuery = piece.col or piece.q
		part.CanTouch = false
		part.Locked = true
		local t = if hidden then 1 else piece.t or 0
		part.Transparency = t
		local size = piece.size
		part.CastShadow = t < 0.5 and math.max(size[1], size[2], size[3]) >= 2
		if hidden then
			part.CanQuery = false -- W02: the kit model's collision, never clicked
		end
		if piece.tag and piece.tag ~= "barrier" then
			part:SetAttribute("Fx", piece.tag)
			part:SetAttribute("Build", build.name)
			if piece.fxColor then
				-- S45: violet ritual fire, cold blue flames and lamps (TownFxController reads it)
				part:SetAttribute("FxColor", colorOf(piece.fxColor))
			end
			CollectionService:AddTag(part, BlueprintBuild.FX_TAG)
			local list = result.tagged[piece.tag]
			if not list then
				list = {}
				result.tagged[piece.tag] = list
			end
			table.insert(list, part)
		end
		part.Parent = ensureModel()
		result.parts += 1
		if pacer then
			pacer.left -= 1
			if pacer.left <= 0 then
				pacer.left = pacer.every
				task.wait()
			end
		end
	end
	-- W02: the kit models of the slots built on this level
	for i, placement in placed do
		if (lods :: any)[(slots :: any)[i].lod] then
			local placedModel = KitAssets.place(placement, ensureModel())
			result.parts += #placedModel:GetChildren()
		end
	end
	for _, light in bp.lights do
		local wanted = if light.tag == "portal" then lods.shell else lods.detail
		if not wanted then
			continue
		end
		local holder = Instance.new("Part")
		holder.Name = "Light"
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Locked = true
		holder.CFrame = base * CFrame.new(light.p[1], light.p[2], light.p[3])
		local point = Instance.new("PointLight")
		point.Color = colorOf(light.color)
		point.Range = light.range
		point.Brightness = light.brightness
		point.Shadows = false
		point.Parent = holder
		-- W29: every light holder is tagged (an untagged light is "light"), so the light budgets
		-- (RegionLightController) see all of them
		holder:SetAttribute("Fx", light.tag or "light")
		holder:SetAttribute("Build", build.name)
		CollectionService:AddTag(holder, BlueprintBuild.FX_TAG)
		holder.Parent = ensureModel()
	end
	if model then
		(model :: Model).Parent = parent
	end
	result.model = model
	return result
end

return BlueprintBuild
