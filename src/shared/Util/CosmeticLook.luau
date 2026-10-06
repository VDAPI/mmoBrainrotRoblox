--!strict
-- Placeholder visuals of cosmetics (Data/Cosmetics), built from parts and particles. Used by the server
-- (CosmeticService, on real characters) and by the wardrobe preview (on a cloned model in a ViewportFrame).
-- Every apply* call first removes what it added before, so it can be called again at any time.

local Anatomy = require("../Logic/Anatomy")
local Cosmetics = require("../Data/Cosmetics")
local LookBuild = require("./LookBuild")

local CosmeticLook = {}

local OUTFIT_FOLDER = "VaelthornOutfit"
local HIDDEN_CLOTHES = "VaelthornHiddenClothes"
local AURA = "VaelthornAura"
local TRAIL = "VaelthornTrail"
local WEAPON_FX = "VaelthornWeaponFx"

local BODY_MAIN = {
	UpperTorso = true,
	LowerTorso = true,
	Torso = true,
	LeftUpperArm = true,
	RightUpperArm = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
}
local BODY_SECOND = {
	LeftLowerArm = true,
	RightLowerArm = true,
	LeftHand = true,
	RightHand = true,
	LeftUpperLeg = true,
	RightUpperLeg = true,
	LeftLowerLeg = true,
	RightLowerLeg = true,
	LeftFoot = true,
	RightFoot = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local function torso(model: Model): BasePart?
	return (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function piece(
	folder: Instance,
	to: BasePart?,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): BasePart?
	if not to then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "Piece"
	part.Size = size
	part.Shape = shape or Enum.PartType.Block
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	weld(part, to, offset)
	part.Parent = folder
	return part
end

local function accessory(model: Model, folder: Folder, name: string, main: Color3, second: Color3)
	local head = model:FindFirstChild("Head") :: BasePart?
	local body = torso(model)
	if name == "hood" then
		piece(folder, head, Vector3.new(1.4, 1.35, 1.4), CFrame.new(0, 0.12, 0.08), main)
	elseif name == "crown" then
		piece(folder, head, Vector3.new(1.15, 0.35, 1.15), CFrame.new(0, 0.75, 0), second, nil, Enum.Material.Neon)
	elseif name == "halo" then
		piece(
			folder,
			head,
			Vector3.new(0.12, 1.4, 1.4),
			CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			second,
			Enum.PartType.Cylinder,
			Enum.Material.Neon
		)
	elseif name == "horns" then
		piece(folder, head, Vector3.new(0.25, 0.7, 0.25), CFrame.new(-0.45, 0.75, 0) * CFrame.Angles(0, 0, 0.4), second)
		piece(folder, head, Vector3.new(0.25, 0.7, 0.25), CFrame.new(0.45, 0.75, 0) * CFrame.Angles(0, 0, -0.4), second)
	elseif name == "mask" then
		piece(folder, head, Vector3.new(1.05, 0.45, 0.2), CFrame.new(0, -0.15, -0.55), second)
	elseif name == "cape" then
		piece(folder, body, Vector3.new(1.9, 2.6, 0.12), CFrame.new(0, -0.6, 0.6) * CFrame.Angles(0.12, 0, 0), second)
	elseif name == "pauldrons" then
		piece(folder, body, Vector3.new(0.9, 0.5, 1.1), CFrame.new(-1.15, 0.75, 0), second, nil, Enum.Material.Metal)
		piece(folder, body, Vector3.new(0.9, 0.5, 1.1), CFrame.new(1.15, 0.75, 0), second, nil, Enum.Material.Metal)
	end
end

local function clear(model: Model, name: string)
	for _, child in model:GetDescendants() do
		if child.Name == name then
			child:Destroy()
		end
	end
end

function CosmeticLook.applyOutfit(model: Model, id: string?)
	-- Undo the previous outfit.
	local old = model:FindFirstChild(OUTFIT_FOLDER)
	if old then
		old:Destroy()
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local original = part:GetAttribute("VaelthornColor")
			if typeof(original) == "Color3" then
				part.Color = original
				part:SetAttribute("VaelthornColor", nil)
			end
		end
	end
	local hidden = model:FindFirstChild(HIDDEN_CLOTHES)
	if hidden then
		for _, clothing in hidden:GetChildren() do
			clothing.Parent = model
		end
		hidden:Destroy()
	end

	local def = id and Cosmetics.get(id)
	if not def or def.kind ~= "outfit" then
		return
	end
	local main = Color3.fromHex(def.color)
	local second = Color3.fromHex(def.color2 or def.color)
	-- Clothing textures would cover the colours: park them in a folder (restored on removal).
	local park = Instance.new("Folder")
	park.Name = HIDDEN_CLOTHES
	park.Parent = model
	for _, child in model:GetChildren() do
		if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
			(child :: Instance).Parent = park
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and (BODY_MAIN[part.Name] or BODY_SECOND[part.Name]) then
			part:SetAttribute("VaelthornColor", part.Color)
			part.Color = if BODY_MAIN[part.Name] then main else second
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = OUTFIT_FOLDER
	folder.Parent = model
	for _, name in (def.parts or {}) :: { string } do
		accessory(model, folder, name, main, second)
	end
end

local function emitter(color: Color3, rate: number, size: number, speed: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.7
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e:SetAttribute("VaelthornBaseRate", rate)
	return e
end

function CosmeticLook.applyAura(model: Model, id: string?)
	clear(model, AURA)
	local def = id and Cosmetics.get(id)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not def or def.kind ~= "aura" or not root then
		return
	end
	local e = emitter(Color3.fromHex(def.color), 14, 0.45, 1.5)
	e.Name = AURA
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Parent = root
end

function CosmeticLook.applyTrail(model: Model, id: string?)
	clear(model, TRAIL)
	local def = id and Cosmetics.get(id)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not def or def.kind ~= "trail" or not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	a0.Name = TRAIL
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	a1.Name = TRAIL
	local trail = Instance.new("Trail")
	trail.Name = TRAIL
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.fromHex(def.color), Color3.fromHex(def.color2 or def.color))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root
end

function CosmeticLook.applyWeapon(model: Model, id: string?)
	clear(model, WEAPON_FX)
	local def = id and Cosmetics.get(id)
	local weapon = model:FindFirstChild("VaelthornWeapon", true) :: BasePart?
	if not def or def.kind ~= "weapon" or not weapon or not weapon:IsA("BasePart") then
		return
	end
	local e = emitter(Color3.fromHex(def.color), 18, 0.3, 0.6)
	e.Name = WEAPON_FX
	e.Parent = weapon
end

-- Pets ---------------------------------------------------------------------------------------------

-- Builds an anchored, non-colliding pet model (clients move it) from the pet's look (S24, Logic/Anatomy at
-- Cosmetics.PET_SCALE). PrimaryPart "LookRoot"; attribute PetLift = height of the LookRoot centre above the
-- ground, Flies = whether the pet flies. A model in ReplicatedStorage.Assets.Pets.<id> replaces the
-- generated look (anchored, scripts removed).
function CosmeticLook.buildPet(id: string): Model?
	local def = Cosmetics.get(id)
	if not def or def.kind ~= "pet" then
		return nil
	end
	local model: Model? = nil
	local lift = 0.5
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Pets")
	local template = folder and folder:FindFirstChild(id)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		if LookBuild.stripScripts(clone) > 0 then
			warn(`[CosmeticLook] removed scripts from Assets.Pets.{id}`)
		end
		for _, item in clone:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CanTouch = false
				item.CanQuery = false
			end
		end
		local cf, size = clone:GetBoundingBox()
		if not clone.PrimaryPart then
			local first = clone:FindFirstChildWhichIsA("BasePart", true)
			clone.PrimaryPart = first
		end
		local pivot = clone:GetPivot()
		lift = size.Y / 2 + (pivot.Position.Y - cf.Position.Y)
		model = clone
	end
	if not model then
		if not def.look then
			return nil
		end
		local rig = Anatomy.build(def.look, { id = id, variant = "pet", scale = Cosmetics.PET_SCALE })
		model = LookBuild.build(rig :: any, { anchored = true, name = id, shadows = false })
		lift = rig.root.size[2] / 2 + rig.hipHeight
	end
	local out = model :: Model
	out.Name = id
	out:SetAttribute("PetLift", lift)
	out:SetAttribute("Flies", def.flies == true)
	return out
end

-- Ids of everything this module draws (used to apply all equipped cosmetics at once).
function CosmeticLook.applyAll(model: Model, equipped: { [string]: string })
	CosmeticLook.applyOutfit(model, equipped.outfit)
	CosmeticLook.applyAura(model, equipped.aura)
	CosmeticLook.applyTrail(model, equipped.trail)
	CosmeticLook.applyWeapon(model, equipped.weapon)
end

return CosmeticLook
