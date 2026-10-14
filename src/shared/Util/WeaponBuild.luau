--!strict
-- Held weapon models (S110, moved out of EquipmentService): the Part look of a type (Data/WeaponLooks pieces) or the
-- owner's real model (S52, ReplicatedStorage.Assets.Weapons through Logic/ArtTiers), welded to the hand (or the back)
-- with the palm ("VaelthornGrip") and the far end ("VaelthornTip") as attachments and the attributes "WeaponType" and
-- "Accent" (S22 trails and projectile origins). Used by EquipmentService on characters and by AnimLab on mannequins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtTiers = require("../Logic/ArtTiers")
local Items = require("../Data/Items")
local LookBuild = require("./LookBuild")
local WeaponLooks = require("../Data/WeaponLooks")
local WeaponMount = require("../Logic/WeaponMount")

local WeaponBuild = {}

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Grip frame of a look (WeaponLooks): palm of the hand, or the centre of the upper torso for "back".
local function anchorFor(model: Model, hand: string): (BasePart?, CFrame)
	if hand == "back" then
		local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
		return if torso and torso:IsA("BasePart") then torso else nil, CFrame.identity
	end
	local side = if hand == "left" then "Left" else "Right"
	local part = model:FindFirstChild(`{side}Hand`) or model:FindFirstChild(`{side} Arm`)
	if not part or not part:IsA("BasePart") then
		return nil, CFrame.identity
	end
	return part, CFrame.new(0, -part.Size.Y / 2, 0)
end

-- Farthest point of a look from the palm (studs, weapon frame): the blade tip / staff head (S22 trails and
-- projectile origins).
local function tipOf(look: WeaponLooks.Look): Vector3
	local best, bestDistance = Vector3.zero, -1
	for _, piece in look.pieces do
		local rot = piece.rot or { 0, 0, 0 }
		local frame = CFrame.new(vector(piece.pos))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		local half = vector(piece.size) / 2
		for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
			for _, sign in { -1, 1 } do
				local point = frame * (axis * half * sign)
				if point.Magnitude > bestDistance then
					best, bestDistance = point, point.Magnitude
				end
			end
		end
	end
	return best
end

-- Real weapon models (S52) ------------------------------------------------------------------------------------

local warnedAssets: { [string]: boolean } = {}

local function weaponsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Weapons")
end

-- The MeshPart named `model` anywhere in Assets.Weapons (a single file or a saved pack), or the first part of a
-- Model of that name.
local function findModel(model: string): BasePart?
	local folder = weaponsFolder()
	local source = folder and folder:FindFirstChild(model, true)
	if source and source:IsA("BasePart") then
		return source
	elseif source then
		return source:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- One warning per missing model of an item's own entry; a single one while Assets.Weapons has no model at all.
local function warnMissing(defId: string, model: string)
	local folder = weaponsFolder()
	local any = folder ~= nil and folder:FindFirstChildWhichIsA("BasePart", true) ~= nil
	local key = if any then model else "*"
	if warnedAssets[key] then
		return
	end
	warnedAssets[key] = true
	if any then
		warn(`[Equipment] Assets.Weapons.{model} not found; {defId} uses a lower tier or its Part look`)
	else
		warn("[Equipment] ReplicatedStorage.Assets.Weapons has no weapon models yet; items use their Part looks")
	end
end

-- Which real model an item shows (Logic/ArtTiers over WeaponLooks.assets and the models present) and its source
-- part, or nil (Part look).
function WeaponBuild.modelFor(def: Items.ItemDef): (string?, BasePart?)
	local own = WeaponLooks.assets[def.id]
	if own and not findModel(own.model) then
		warnMissing(def.id, own.model)
	end
	local id = ArtTiers.modelId(def, function(candidate: string): boolean
		local asset = WeaponLooks.assets[candidate]
		return asset ~= nil and findModel(asset.model) ~= nil
	end)
	if not id then
		return nil, nil
	end
	return id, findModel(WeaponLooks.assets[id].model)
end

local function axis(name: string): Vector3
	local v = WeaponMount.axis(name) or { 0, 0, -1 }
	return Vector3.new(v[1], v[2], v[3])
end

-- Grip frame of a type in the hand frame (WeaponLooks.MOUNTS, the same maths as Logic/WeaponMount.toHand).
local function mountFrame(itemType: string): CFrame
	local mount = WeaponLooks.MOUNTS[itemType] or WeaponLooks.MOUNTS.sword1h
	local at = mount.at or { 0, 0, 0 }
	local tilt = mount.tilt or { 0, 0, 0 }
	local x, y = axis(mount.x), axis(mount.y)
	return CFrame.new(at[1], at[2], at[3])
		* CFrame.Angles(math.rad(tilt[1]), math.rad(tilt[2]), math.rad(tilt[3]))
		* CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- Copy of a model scaled to the item's length and placed on the mount of its type, with the palm (VaelthornGrip)
-- and the far end (VaelthornTip). Only the mesh look survives (SurfaceAppearance / SpecialMesh): scripts, sounds,
-- decals and any other child are dropped, also when nested under a kept look (one warning per model).
local function buildFromModel(
	source: BasePart,
	asset: WeaponLooks.Asset,
	itemType: string,
	anchor: BasePart,
	grip: CFrame,
	name: string
): BasePart
	local part = source:Clone()
	for _, child in part:GetChildren() do
		if not child:IsA("SurfaceAppearance") and not child:IsA("SpecialMesh") then
			child:Destroy()
		end
	end
	local removed = LookBuild.stripScripts(part)
	for _, item in part:GetDescendants() do
		if item:IsA("Sound") then
			item:Destroy()
			removed += 1
		end
	end
	if removed > 0 and not warnedAssets[`strip:{asset.model}`] then
		warnedAssets[`strip:{asset.model}`] = true
		warn(`[Equipment] removed scripts / sounds from Assets.Weapons.{asset.model}`)
	end
	-- The mesh in the Grip frame: the import switch and an optional per-model turn (a mesh made in Studio).
	local t = asset.turn or { 0, 0, 0 }
	local turn = CFrame.Angles(0, math.rad(WeaponLooks.IMPORT_YAW), 0)
		* CFrame.Angles(math.rad(t[1]), math.rad(t[2]), math.rad(t[3]))
	local up = turn:VectorToObjectSpace(Vector3.yAxis)
	local size = part.Size
	local along = math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z
	part.Size = size * (asset.length / math.max(0.01, along))
	local hold = asset.hold or { 0, 0 }
	local centre = CFrame.new(-hold[1] * asset.length, (0.5 - asset.grip) * asset.length, -hold[2] * asset.length)
	local offset = grip * mountFrame(itemType) * centre * turn
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	local palm = Instance.new("Attachment")
	palm.Name = "VaelthornGrip"
	palm.CFrame = offset:Inverse() * grip
	palm.Parent = part
	local tip = Instance.new("Attachment")
	tip.Name = "VaelthornTip"
	tip.CFrame = turn:Inverse() * CFrame.new(0, asset.length / 2, 0)
	tip.Parent = part
	return part
end

-- The look built from Parts (S17b): the first piece is the main part (named after the slot), the others are
-- welded to it and parented under it; the main part carries the palm and the farthest point as attachments.
local function buildFromParts(
	look: WeaponLooks.Look,
	accent: Color3,
	anchor: BasePart,
	grip: CFrame,
	name: string
): BasePart
	local main: BasePart? = nil
	for _, piece in look.pieces do
		local part = Instance.new("Part")
		part.Name = if main then piece.name else name
		part.Size = vector(piece.size)
		part.Color = if piece.color == "rarity" then accent else Color3.fromHex(piece.color)
		part.Material = material(piece.material)
		part.Transparency = piece.transparency or 0
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		local rot = piece.rot or { 0, 0, 0 }
		local offset = grip
			* CFrame.new(vector(piece.pos))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		part.CFrame = anchor.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		if main then
			part.Parent = main
		else
			main = part
		end
	end
	local held = main :: BasePart
	local first = look.pieces[1]
	local firstRot = first.rot or { 0, 0, 0 }
	local firstOffset = CFrame.new(vector(first.pos))
		* CFrame.Angles(math.rad(firstRot[1]), math.rad(firstRot[2]), math.rad(firstRot[3]))
	local palm = Instance.new("Attachment")
	palm.Name = "VaelthornGrip"
	palm.CFrame = firstOffset:Inverse()
	palm.Parent = held
	local tip = Instance.new("Attachment")
	tip.Name = "VaelthornTip"
	tip.CFrame = firstOffset:Inverse() * CFrame.new(tipOf(look))
	tip.Parent = held
	return held
end

-- Builds the held model of `weaponType` (a WeaponLooks type) named `name` on `model` and parents it there: the real
-- model of `def` (or the nearest lower tier of its type) when `def` is given and present, else the Part look with
-- `accent` on its "rarity" pieces. Returns nil when the type has no look or the model has no hand / torso for it.
function WeaponBuild.attach(
	model: Model,
	weaponType: string,
	accent: Color3,
	name: string,
	def: Items.ItemDef?
): BasePart?
	local look = WeaponLooks.get(weaponType)
	if not look then
		return nil
	end
	local anchor, grip = anchorFor(model, look.hand)
	if not anchor then
		return nil
	end
	local modelId, source = nil, nil
	if def then
		modelId, source = WeaponBuild.modelFor(def)
	end
	local held = if modelId and source
		then buildFromModel(source, WeaponLooks.assets[modelId], weaponType, anchor, grip, name)
		else buildFromParts(look, accent, anchor, grip, name)
	held:SetAttribute("WeaponType", weaponType)
	held:SetAttribute("Accent", accent) -- rarity colour (trail)
	held.Parent = model
	return held
end

return WeaponBuild
