--!strict
-- Part pool of the skill visuals (S28): neon / glass parts of the three shapes are reused instead of created per
-- effect, ParticleEmitters live on pooled anchor parts and only Emit bursts. `budget` caps how many effects run at
-- once (Config.Vfx.maxActive): past it, optional pieces are skipped.
-- S112: holders: invisible anchored parts with one prepared child (a textured ParticleEmitter, a Beam between two
-- attachments, a Decal on top) that survive their return, so textured layers are not built per effect. Each kind has
-- a live limit per device (Config.Vfx.maxEmitters / maxBeams / maxDecals; touch without a keyboard = phone), and so
-- do the PointLights of the new pieces (maxLights): past a limit the optional layer is skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)

local Pool = {}

local folder: Folder? = nil
-- S28: effects of the skill window preview go into its viewport's WorldModel while it plays.
local override: Instance? = nil
local free: { [string]: { BasePart } } = { Block = {}, Ball = {}, Cylinder = {}, Wedge = {} } -- S77: Wedge (falcon)
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

-- S112: true while pieces go into a preview WorldModel (a ViewportFrame draws no particles, beams or trails).
function Pool.inViewport(): boolean
	return override ~= nil and override.Parent ~= nil
end

-- A clean anchored part of the shape (Block / Ball / Cylinder / Wedge), parented and visible.
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

-- Returns a part to the pool (children such as lights and emitters are destroyed; a holder goes to releaseHolder).
function Pool.release(p: BasePart)
	if not p.Parent then
		return
	end
	if p:GetAttribute("VfxHolder") ~= nil then
		Pool.releaseHolder(p)
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

-- Releases after `seconds` (S110: on the effect clock, so a frozen effect stays).
function Pool.later(p: BasePart, seconds: number)
	Clock.after(seconds, Pool.release, p)
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
		Clock.after(seconds, function()
			active = math.max(0, active - 1)
		end)
	else
		active = math.max(0, active - 1)
	end
end

function Pool.activeCount(): number
	return active
end

-- Holders (S112) ----------------------------------------------------------------------------------------------------

-- HolderKind: "emitter" | "beam" | "decal" | "surface"; LimitName: "emitters" | "beams" | "decals" | "lights"
-- (plain strings: the type checker loses the literal unions through the lookups below).
export type HolderKind = string
export type LimitName = string

-- "surface" (a glowing image lying on the ground: magic circles, rings) counts towards the beam limit.
local KINDS: { HolderKind } = { "emitter", "beam", "decal", "surface" }
local holdersFree: { [string]: { BasePart } } = {}
local holdersUsed: { [string]: number } = { emitter = 0, beam = 0, decal = 0, surface = 0 }

local function limitOf(kind: HolderKind): LimitName
	if kind == "emitter" then
		return "emitters"
	elseif kind == "decal" then
		return "decals"
	end
	return "beams"
end

local function childName(kind: HolderKind): string
	if kind == "emitter" then
		return "VfxEmitter"
	elseif kind == "beam" then
		return "VfxBeam"
	elseif kind == "decal" then
		return "VfxDecal"
	end
	return "VfxSurface"
end
local lightsUsed = 0

-- Puts the texture of `key` on a holder's child (or clears it); set by Vfx/Textures when it loads.
Pool.dress = function(_kind: HolderKind, _child: Instance, _key: string) end :: (HolderKind, Instance, string) -> ()

-- A phone: touch without a keyboard (the same rule as AnimationController). AnimLab may replace it in Play.
function Pool.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Config.Vfx.max<Name> for this device.
function Pool.limit(name: LimitName): number
	local pair: { desktop: number, touch: number } = if name == "emitters"
		then Config.Vfx.maxEmitters
		elseif name == "beams" then Config.Vfx.maxBeams
		elseif name == "decals" then Config.Vfx.maxDecals
		else Config.Vfx.maxLights
	return if Pool.isTouch() then pair.touch else pair.desktop
end

local function kindOf(tag: string): HolderKind?
	local kind = string.match(tag, "^(%a+):")
	for _, known in KINDS do
		if kind == known then
			return known
		end
	end
	return nil
end

local function newHolder(kind: HolderKind): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "emitter" then
		local e = Instance.new("ParticleEmitter")
		e.Name = childName("emitter")
		e.Rate = 0
		e.Enabled = true
		e.Parent = p
	elseif kind == "beam" then
		local a0 = Instance.new("Attachment")
		a0.Name = "A0"
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Name = "A1"
		a1.Parent = p
		local b = Instance.new("Beam")
		b.Name = childName("beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Transparency = NumberSequence.new(1)
		b.Parent = p
	elseif kind == "decal" then
		local d = Instance.new("Decal")
		d.Name = childName("decal")
		d.Face = Enum.NormalId.Top
		d.Transparency = 1
		d.Parent = p
	else
		-- an unlit image on the top face (a ground circle seen from above; any turn of a round image looks right)
		local gui = Instance.new("SurfaceGui")
		gui.Name = childName("surface")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0
		gui.Brightness = 1.6
		gui.ClipsDescendants = true
		gui.ResetOnSpawn = false
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.ImageTransparency = 1
		image.Parent = gui
		gui.Parent = p
	end
	return p
end

-- An invisible anchored part with one prepared child: "VfxEmitter" (ParticleEmitter, Rate 0), "VfxBeam" (Beam
-- between attachments "A0" and "A1"), "VfxDecal" (Decal on Top) or "VfxSurface" (SurfaceGui on Top with an unlit
-- ImageLabel "Image"), dressed with the texture of `key` (Vfx/Textures;
-- no texture = the plain child). Nil when the device limit of the kind is reached: the caller skips that layer.
function Pool.holder(kind: HolderKind, key: string): BasePart?
	local limitName = limitOf(kind)
	local live = 0
	for _, other in KINDS do
		if limitOf(other) == limitName then
			live += holdersUsed[other]
		end
	end
	if live >= Pool.limit(limitName) then
		return nil
	end
	local tag = kind .. ":" .. key
	local list = holdersFree[tag]
	local p: BasePart? = if list then table.remove(list) else nil
	if not p then
		local created = newHolder(kind)
		created:SetAttribute("VfxHolder", tag)
		p = created
	end
	local holder = p :: BasePart
	local child = holder:FindFirstChild(childName(kind))
	if child then
		-- dressed on every take: textures may have been switched off, or one failed to load (Textures.check)
		Pool.dress(kind, child, key)
		if child:IsA("ParticleEmitter") then
			Clock.track(child)
		end
	end
	holdersUsed[kind] += 1
	holder.Parent = container()
	return holder
end

-- The prepared child of a holder (VfxEmitter / VfxBeam / VfxDecal).
function Pool.child(p: BasePart): Instance?
	local tag = p:GetAttribute("VfxHolder")
	local kind = if type(tag) == "string" then kindOf(tag) else nil
	return if kind then p:FindFirstChild(childName(kind)) else nil
end

-- Back to the pool: particles cleared, beam / decal hidden, attachments reset; the child stays. At most
-- Config.Vfx.holdersPerKey free holders per kind and key, the rest are destroyed.
function Pool.releaseHolder(p: BasePart)
	if not p.Parent then
		return
	end
	local tag = p:GetAttribute("VfxHolder")
	local kind = if type(tag) == "string" then kindOf(tag) else nil
	if not kind or type(tag) ~= "string" then
		p:SetAttribute("VfxHolder", nil)
		Pool.release(p)
		return
	end
	holdersUsed[kind] = math.max(0, holdersUsed[kind] - 1)
	p.Parent = nil
	local child = p:FindFirstChild(childName(kind))
	if child and child:IsA("ParticleEmitter") then
		child:Clear()
	elseif child and child:IsA("Beam") then
		child.Transparency = NumberSequence.new(1)
		for _, name in { "A0", "A1" } do
			local a = p:FindFirstChild(name)
			if a and a:IsA("Attachment") then
				a.CFrame = CFrame.identity
			end
		end
	elseif child and child:IsA("Decal") then
		child.Transparency = 1
	elseif child and child:IsA("SurfaceGui") then
		local image = child:FindFirstChild("Image")
		if image and image:IsA("ImageLabel") then
			image.ImageTransparency = 1
		end
	end
	-- anything a piece added (a light) goes
	for _, extra in p:GetChildren() do
		if extra ~= child and extra.Name ~= "A0" and extra.Name ~= "A1" then
			extra:Destroy()
		end
	end
	local list = holdersFree[tag]
	if not list then
		list = {}
		holdersFree[tag] = list
	end
	if child and #list < Config.Vfx.holdersPerKey then
		table.insert(list, p)
	else
		p:Destroy()
	end
end

-- Releases a holder after `seconds` on the effect clock (a frozen effect stays).
function Pool.holderLater(p: BasePart, seconds: number)
	Clock.after(seconds, Pool.releaseHolder, p)
end

-- Holders of a kind in use (limits, /animlab vfx stats).
function Pool.holderCount(kind: HolderKind): number
	return holdersUsed[kind]
end

-- PointLights of the new pieces: true when one more may live (call dropLight when it goes).
function Pool.takeLight(): boolean
	if lightsUsed >= Pool.limit("lights") then
		return false
	end
	lightsUsed += 1
	return true
end

function Pool.dropLight()
	lightsUsed = math.max(0, lightsUsed - 1)
end

function Pool.lightCount(): number
	return lightsUsed
end

return Pool
