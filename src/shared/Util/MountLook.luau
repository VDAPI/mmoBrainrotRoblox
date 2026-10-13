--!strict
-- Builds the model of a mount (S96, Data/Mounts) on the server: a real model from ReplicatedStorage.Assets.Mounts
-- when Data/Mounts.assets names one (docs/ASSETS.md "Wierzchowce"), otherwise the procedural look (Logic/Anatomy
-- plan "horse" through LookBuild, Gait_* joints for the client's walk cycle). The model is named VaelthornMount,
-- every part is massless and never collides, touches or takes rays (it is welded to the rider's root), and it
-- carries the attributes MountId, LookScale, MountRig ("gait" | "animator" | "static"), MountWalkSpeed and the
-- CollectionService tag "VaelthornMount" (AnimationController animates by the tag). Returns the seat too: the
-- rider's HipHeight and the LookRoot / pivot offset from the rider's root (Logic/Mounts.seat).
-- S97: the account's mount skin (Data/Cosmetics kind "mountskin") goes over the procedural look through
-- Logic/Mounts.lookWith and the model gets the attribute MountSkin. A real model only takes the skin's colours on parts
-- named like a colour role (Base, Accent, Detail, Cloth, Trim). preview() builds a still copy for the wardrobe and the
-- mounts window (no tag: the AnimationController leaves it alone).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Anatomy = require("../Logic/Anatomy")
local Cosmetics = require("../Data/Cosmetics")
local LookBuild = require("./LookBuild")
local MountData = require("../Data/Mounts")
local Mounts = require("../Logic/Mounts")

local MountLook = {}

MountLook.NAME = "VaelthornMount"
MountLook.TAG = "VaelthornMount"

export type Options = {
	skin: string?, -- S97: a mountskin cosmetic id (Logic/Mounts.lookWith; attribute MountSkin)
	still: boolean?, -- S97: a preview copy: no CollectionService tag (the AnimationController never walks it)
}

local warned: { [string]: boolean } = {}

-- Part names of a real model that take a skin colour (role -> colour of Data/Cosmetics skin.colors).
local ROLE_PARTS: { [string]: string } = {
	Base = "base",
	Accent = "accent",
	Detail = "detail",
	Cloth = "cloth",
	Trim = "trim",
}

local function skinOf(id: string?): Cosmetics.Def?
	local def = if id then Cosmetics.get(id) else nil
	return if def and def.kind == "mountskin" then def else nil
end

-- A real model keeps its look; only parts named like a colour role take the skin's colour.
local function paintAsset(model: Model, skin: Cosmetics.Def)
	local colors = skin.skin and skin.skin.colors
	if not colors then
		return
	end
	for _, item in model:GetDescendants() do
		local role = ROLE_PARTS[item.Name]
		local hex = role and colors[role]
		if hex and item:IsA("BasePart") then
			item.Color = Color3.fromHex(hex)
		end
	end
end

-- Parts of a mount never weigh, collide, touch or take rays; a real model casts no shadows either.
local function quiet(model: Model, shadows: boolean)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = true
			if not shadows then
				item.CastShadow = false
			end
		end
	end
end

-- Real model of `id` (nil without an entry or a model; warns once per id when the entry names a missing model).
local function fromAsset(id: string, rootHalf: number): (Model?, Mounts.Seat?)
	local asset = MountData.assets[id]
	if not asset then
		return nil, nil
	end
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local mounts = folder and folder:FindFirstChild("Mounts")
	local template = mounts and mounts:FindFirstChild(asset.model)
	if not template or not template:IsA("Model") then
		if not warned[id] then
			warned[id] = true
			warn(`[MountLook] Assets.Mounts.{asset.model} not found; {id} uses its procedural look`)
		end
		return nil, nil
	end
	local clone = template:Clone()
	if LookBuild.stripScripts(clone) > 0 then
		warn(`[MountLook] removed scripts from Assets.Mounts.{asset.model}`)
	end
	quiet(clone, false)
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	if not clone.PrimaryPart then
		clone:Destroy()
		return nil, nil
	end
	clone:SetAttribute("MountRig", asset.rig)
	if asset.walkSpeed then
		clone:SetAttribute("MountWalkSpeed", asset.walkSpeed)
	end
	-- The pivot is on the ground: the saddle is given from it.
	return clone, Mounts.seatAt(0, asset.saddle, rootHalf)
end

-- Model and seat of mount `id` for a rider whose HumanoidRootPart is `rootHalf` studs above its bottom (R6: plus
-- the legs). Not parented. nil for an unknown id.
function MountLook.build(id: string, rootHalf: number, opts: Options?): (Model?, Mounts.Seat?)
	local def = MountData.get(id)
	if not def then
		return nil, nil
	end
	local scale = def.scale or 1
	local skin = skinOf(opts and opts.skin)
	local model, seat = fromAsset(id, rootHalf)
	if model and skin then
		paintAsset(model, skin)
	end
	if not model then
		-- Data/Mounts.Look is the same shape as Anatomy.Look without the monster-only fields
		local look = Mounts.lookWith(def.look, skin)
		local rig = Anatomy.build(look :: any, { id = def.id, variant = "mount", scale = scale })
		local built = LookBuild.build(rig :: any, { name = MountLook.NAME, scale = scale, shadows = true })
		quiet(built, true)
		built:SetAttribute("MountRig", "gait")
		model = built
		seat = Mounts.seat(rig, rootHalf)
	end
	local out = model :: Model
	out.Name = MountLook.NAME
	out:SetAttribute("MountId", id)
	out:SetAttribute("LookScale", scale)
	if skin then
		out:SetAttribute("MountSkin", skin.id)
	end
	if not (opts and opts.still) then
		CollectionService:AddTag(out, MountLook.TAG)
	end
	return out, seat
end

-- A still, anchored copy of mount `id` with `skin` for a ViewportFrame (wardrobe, mounts window): untagged, its
-- pivot moved so the hooves stand at y = 0 under the origin. nil for an unknown id.
function MountLook.preview(id: string, skin: string?): Model?
	local model, seat = MountLook.build(id, 1, { skin = skin, still = true })
	if not model or not seat then
		return nil
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	-- The rider's root at (0, 1 + hipHeight, 0) puts the mount's hooves on the ground (Logic/Mounts.seat).
	local riderRoot = CFrame.new(0, 1 + seat.hipHeight, 0)
	model:PivotTo(riderRoot * CFrame.new(seat.offset[1], seat.offset[2], seat.offset[3]))
	return model
end

-- A still copy of a rider (wardrobe / skill preview) stands on foot: no mount model, no Mount attribute, so the
-- AnimationController neither walks a cloned horse nor poses the copy astride.
function MountLook.strip(copy: Model)
	local mount = copy:FindFirstChild(MountLook.NAME)
	if mount then
		mount:Destroy()
	end
	copy:SetAttribute("Mount", nil)
end

return MountLook
