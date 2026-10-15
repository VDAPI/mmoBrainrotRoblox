--!strict
-- Placeholder visuals of cosmetics (Data/Cosmetics), built from parts and particles. Used by the server
-- (CosmeticService, on real characters) and by the wardrobe preview (on a cloned model in a ViewportFrame).
-- Every apply* call first removes what it added before, so it can be called again at any time.
-- S132 (DESIGN-17 §9a): outfits and the dye are drawn by Util/AvatarBuild from Logic/CharacterLook.resolve (the class
-- look); applyOutfit / applyDye / applyAll stay with their names and signatures as a compatibility path (an outfit over
-- the model as it is, avatar mode). CosmeticService and the wardrobe use AvatarBuild directly.

local Anatomy = require("../Logic/Anatomy")
local AvatarBuild = require("./AvatarBuild")
local CharacterLook = require("../Logic/CharacterLook")
local CosmeticRules = require("../Logic/CosmeticRules")
local Cosmetics = require("../Data/Cosmetics")
local LookBuild = require("./LookBuild")

local CosmeticLook = {}

local OUTFIT_FOLDER = "VaelthornOutfit"
local AURA = "VaelthornAura"
local TRAIL = "VaelthornTrail"
local WEAPON_FX = "VaelthornWeaponFx"
-- S122: the Cloak of Luring cape (applyLure) and the outfit cape it covers. S132 (class looks) keeps this contract:
-- the outfit cape part is named OUTFIT_CAPE and the model attribute LureCape says the lure cape is on.
local LURE_FOLDER = "VaelthornLureCape"
local OUTFIT_CAPE = "OutfitCape"
local LURE_ATTRIBUTE = "LureCape"

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

local function clear(model: Model, name: string)
	for _, child in model:GetDescendants() do
		if child.Name == name then
			child:Destroy()
		end
	end
end

-- Compatibility (S132): the outfit `id` over the model as it is (Util/AvatarBuild in avatar mode, the dye with
-- `dyeId`). A class outfit is drawn for any model here; the game checks the class before (Logic/Premium.canEquip).
function CosmeticLook.applyOutfit(model: Model, id: string?, dyeId: string?)
	local old = model:FindFirstChild(OUTFIT_FOLDER) -- an outfit drawn before S132
	if old then
		old:Destroy()
	end
	local def = if id then Cosmetics.get(id) else nil
	if not def or def.kind ~= "outfit" then
		AvatarBuild.clearProcedural(model)
		return
	end
	AvatarBuild.applyProcedural(
		model,
		CharacterLook.resolve({
			classId = def.class or "",
			look = nil,
			outfitId = def.id,
			dye = dyeId,
			robloxAvatar = true,
		}),
		true
	)
end

-- Whether `color` is the hex colour `hex` (part colours are stored with 8 bits per channel).
local function sameColor(color: Color3, hex: string?): boolean
	if hex == nil then
		return false
	end
	local want = Color3.fromHex(hex)
	return math.abs(color.R - want.R) < 0.003
		and math.abs(color.G - want.G) < 0.003
		and math.abs(color.B - want.B) < 0.003
end

-- S123: recolours the worn outfit with a dye (Logic/CosmeticRules.dyed): the body parts the outfit coloured (their
-- original colour is in the VaelthornColor attribute; BODY_MAIN gets the main colour, BODY_SECOND the second one) and
-- the outfit's accessories of the outfit's main / second colour (Neon and Metal ones too). Nothing without an outfit
-- or a dye; never the Cloak of Luring cape, the aura, the trail or the weapon effect. Taking the dye off is a new
-- applyAll (applyOutfit restores and rebuilds everything).
-- S132 (DESIGN-17 §9a): compatibility only. The game puts the dye into Logic/CharacterLook.resolve (the outfit's colours
-- before drawing); calling this after Util/AvatarBuild would paint the body a second time.
function CosmeticLook.applyDye(model: Model, dyeId: string?, outfitId: string?)
	local outfit = if outfitId then Cosmetics.get(outfitId) else nil
	local dye = if dyeId then Cosmetics.get(dyeId) else nil
	local mainHex, secondHex = CosmeticRules.dyed(outfit, dye)
	if not outfit or not mainHex then
		return
	end
	local main = Color3.fromHex(mainHex)
	local second = Color3.fromHex(secondHex or mainHex)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and typeof(part:GetAttribute("VaelthornColor")) == "Color3" then
			if BODY_MAIN[part.Name] then
				part.Color = main
			elseif BODY_SECOND[part.Name] then
				part.Color = second
			end
		end
	end
	local folder = model:FindFirstChild(OUTFIT_FOLDER) or model:FindFirstChild("VaelthornClassLook")
	if not folder then
		return
	end
	local outfitSecond = outfit.color2 or outfit.color
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			-- the second colour first: an outfit without color2 paints everything in its main colour
			if sameColor(part.Color, outfitSecond) and outfit.color2 ~= nil then
				part.Color = second
			elseif sameColor(part.Color, outfit.color) then
				part.Color = main
			end
		end
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

-- S122 (DESIGN-17 §3): the Cloak of Luring, a dark red cape with a faint smoke, seen by everyone. Not a cosmetic
-- slot and nothing saved: LureService calls it while the cloak is on and has time. While on it hides the outfit cape
-- (OutfitCape parts), so the order of CosmeticService.applyLook and LureService does not matter.
function CosmeticLook.applyLure(model: Model, on: boolean)
	local old = model:FindFirstChild(LURE_FOLDER)
	if old then
		old:Destroy()
	end
	model:SetAttribute(LURE_ATTRIBUTE, on)
	for _, part in model:GetDescendants() do
		if part.Name == OUTFIT_CAPE and part:IsA("BasePart") then
			part.Transparency = if on then 1 else 0
		end
	end
	if not on then
		return
	end
	local body = torso(model)
	if not body then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = LURE_FOLDER
	folder.Parent = model
	local offset = CFrame.new(0, -0.7, 0.66) * CFrame.Angles(0.14, 0, 0)
	local cape =
		piece(folder, body, Vector3.new(2.0, 2.9, 0.14), offset, Color3.fromHex("#5E1218"), nil, Enum.Material.Fabric)
	-- a darker hem along the bottom edge
	piece(
		folder,
		body,
		Vector3.new(2.04, 0.18, 0.16),
		offset * CFrame.new(0, -1.36, 0),
		Color3.fromHex("#3B0A0F"),
		nil,
		Enum.Material.Fabric
	)
	if cape then
		local smoke = emitter(Color3.fromHex("#3A2A2A"), 4, 0.35, 0.6)
		smoke.Name = "LureSmoke"
		smoke.LightEmission = 0
		smoke.SpreadAngle = Vector2.new(25, 25)
		smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Acceleration = Vector3.new(0, 0.8, 0)
		smoke.Parent = cape
	end
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

-- Ids of everything this module draws (used to apply all equipped cosmetics at once). S132: compatibility; the dye goes
-- into the outfit's colours (applyOutfit), the game applies the class look through Util/AvatarBuild and applyEffects.
function CosmeticLook.applyAll(model: Model, equipped: { [string]: string })
	CosmeticLook.applyOutfit(model, equipped.outfit, equipped.dye)
	CosmeticLook.applyEffects(model, equipped)
end

-- S132: everything but the outfit and the dye (aura, trail, weapon effect), after the class look.
function CosmeticLook.applyEffects(model: Model, equipped: { [string]: string })
	CosmeticLook.applyAura(model, equipped.aura)
	CosmeticLook.applyTrail(model, equipped.trail)
	CosmeticLook.applyWeapon(model, equipped.weapon)
end

return CosmeticLook
