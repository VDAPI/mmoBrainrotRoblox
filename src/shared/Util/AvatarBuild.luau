--!strict
-- Class looks on a model (DESIGN-17 §9a, S132): the HumanoidDescription of a character (server: standard R15 body and
-- scales, no avatar animations, catalog clothing and accessories) and the procedural look drawn from parts over it
-- (body colours, garments, hairstyle, face) from a Logic/CharacterLook.LookSpec. Used by the server (CosmeticService on
-- the real character, the mannequin) and the client previews (creator, wardrobe, look window: a clone of the mannequin
-- or of the own character). Every apply first removes what it added before, so it can be called again at any time.
-- Contract with S122 (Util/CosmeticLook.applyLure): every cape part of an outfit is named OutfitCape and is invisible
-- while the model's attribute LureCape is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BodyLooks = require("../Data/BodyLooks")
local CharacterLook = require("../Logic/CharacterLook")
local ClassLooks = require("../Data/ClassLooks")
local HairTint = require("../Logic/HairTint")
local LookBuild = require("./LookBuild")

local AvatarBuild = {}

-- ReplicatedStorage child the server builds (a standard R15 figure, anchored, no scripts) for the client previews.
AvatarBuild.MANNEQUIN = "VaelthornMannequin"

local FOLDER = "VaelthornClassLook"
local HIDDEN = "VaelthornHiddenClothes"
local COLOR_ATTRIBUTE = "VaelthornColor"
local ASSET_ATTRIBUTE = "VaelthornClassLook" -- an owner's accessory put on through Humanoid:AddAccessory
local OUTFIT_CAPE = "OutfitCape"
local LURE_ATTRIBUTE = "LureCape"
local QUIVER_GARMENTS = { quiver_back = true, ember_arrows = true }
-- W10: the face accessories of the dynamic heads by name (description: Eyebrows / Lashes, loaded asset: Brows / Lashes)
local FACE_ACCESSORY: { [string]: string } = { Eyebrows = "brows", Brows = "brows", Lashes = "lashes" }

-- R6 parts take the colour of their R15 counterpart (a game set to R6 still shows the outfit).
local R6_PART: { [string]: string } = {
	Torso = "UpperTorso",
	["Left Arm"] = "LeftUpperArm",
	["Right Arm"] = "RightUpperArm",
	["Left Leg"] = "LeftUpperLeg",
	["Right Leg"] = "RightUpperLeg",
}

-- Animation fields of a description: the game plays its own motions (S110-S117), never the avatar's.
local ANIMATIONS = {
	"IdleAnimation",
	"WalkAnimation",
	"RunAnimation",
	"JumpAnimation",
	"FallAnimation",
	"ClimbAnimation",
	"SwimAnimation",
	"MoodAnimation",
}
-- Rigid accessory fields of a description (comma-separated catalog ids).
local ACCESSORY_FIELDS = {
	"HatAccessory",
	"HairAccessory",
	"FaceAccessory",
	"NeckAccessory",
	"ShouldersAccessory",
	"FrontAccessory",
	"BackAccessory",
	"WaistAccessory",
}
local BODY_FIELDS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local COLOR_FIELDS = { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" }

local warned: { [string]: boolean } = {}
local function warnOnce(key: string, text: string)
	if not warned[key] then
		warned[key] = true
		warn(`[AvatarBuild] {text}`)
	end
end

-- Description ---------------------------------------------------------------------------------------

-- The description of a character (server; the client never applies descriptions). Class mode: a standard R15 body in
-- the skin colour, the catalog face, clothing and accessories of the spec and nothing else. Avatar mode: a copy of
-- `base` (the player's own description) with the outfit's catalog clothing over it. Both: the game's body (W09,
-- Data/BodyLooks: one base body with a dynamic head for everybody), scales of that body / clamped (Logic/CharacterLook),
-- no animations.
function AvatarBuild.description(spec: CharacterLook.LookSpec, base: HumanoidDescription?): HumanoidDescription
	local desc: any = if base and spec.mode == "avatar" then base:Clone() else Instance.new("HumanoidDescription")
	local scales: { [string]: number } = BodyLooks.scales :: any
	if spec.mode == "avatar" and base then
		scales = CharacterLook.clampScales({
			height = base.HeightScale,
			width = base.WidthScale,
			depth = base.DepthScale,
			head = base.HeadScale,
			bodyType = base.BodyTypeScale,
			proportion = base.ProportionScale,
		})
		scales = table.clone(scales)
		scales.height *= BodyLooks.scales.height
	end
	desc.HeightScale = scales.height
	desc.WidthScale = scales.width * spec.build.width
	desc.DepthScale = scales.depth * spec.build.depth
	desc.HeadScale = scales.head
	desc.BodyTypeScale = scales.bodyType
	desc.ProportionScale = scales.proportion
	for _, field in BODY_FIELDS do
		desc[field] = BodyLooks.parts[field] or 0
	end
	if spec.mode == "class" and spec.face then
		desc.Head = spec.face.head -- W10: the face is a dynamic head
	end
	for _, field in ANIMATIONS do
		desc[field] = 0
	end
	if spec.mode == "class" then
		local skin = Color3.fromHex(spec.skin or ClassLooks.skinById[ClassLooks.DEFAULT_LOOK.skin].color)
		for _, field in COLOR_FIELDS do
			desc[field] = skin
		end
		desc.Face = 0 -- a dynamic head draws its own face (a face decal would not show on it)
		desc.Shirt = spec.shirt
		desc.Pants = spec.pants
		desc.GraphicTShirt = 0
		for _, field in ACCESSORY_FIELDS do
			desc[field] = ""
		end
		pcall(function()
			-- layered clothing of a copied description never in the class look; the face's brows and lashes (W10)
			local list = {}
			local face = spec.face
			if face and face.browsId ~= 0 then
				table.insert(
					list,
					{ AssetId = face.browsId, AccessoryType = Enum.AccessoryType.Eyebrow, IsLayered = true, Order = 1 }
				)
			end
			if face then
				table.insert(
					list,
					{ AssetId = face.lashes, AccessoryType = Enum.AccessoryType.Eyelash, IsLayered = true, Order = 2 }
				)
			end
			desc:SetAccessories(list, true)
		end)
	else
		if spec.shirt ~= 0 then
			desc.Shirt = spec.shirt
		end
		if spec.pants ~= 0 then
			desc.Pants = spec.pants
		end
	end
	if #spec.accessories > 0 then
		-- every catalog piece as a rigid hat entry; the accessory's own attachment decides where it sits
		local ok = pcall(function()
			local list = desc:GetAccessories(true)
			for _, id in spec.accessories do
				table.insert(list, { AssetId = id, AccessoryType = Enum.AccessoryType.Hat, IsLayered = false })
			end
			desc:SetAccessories(list, true)
		end)
		if not ok then
			local ids = {}
			for _, id in spec.accessories do
				table.insert(ids, tostring(id))
			end
			local hats = desc.HatAccessory
			desc.HatAccessory = if hats ~= "" then `{hats},{table.concat(ids, ",")}` else table.concat(ids, ",")
		end
	end
	return desc :: HumanoidDescription
end

-- Procedural look -----------------------------------------------------------------------------------

type Ctx = {
	model: Model,
	folder: Folder,
	color: Color3,
	head: BasePart?,
	torso: BasePart?,
	lower: BasePart?,
	part: (name: string) -> BasePart?,
}

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function piece(
	ctx: Ctx,
	to: BasePart?,
	size: Vector3,
	offset: CFrame,
	color: Color3?,
	material: Enum.Material?,
	shape: Enum.PartType?
): BasePart?
	if not to then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "Piece"
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	part.Shape = shape or Enum.PartType.Block
	part.Color = color or ctx.color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	weld(part, to, offset)
	part.Parent = ctx.folder
	return part
end

-- Size and offset relative to a part's size (so pieces fit clamped avatar scales too).
local function rel(to: BasePart?, x: number, y: number, z: number): Vector3
	if not to then
		return Vector3.zero
	end
	return Vector3.new(to.Size.X * x, to.Size.Y * y, to.Size.Z * z)
end

local function at(to: BasePart?, x: number, y: number, z: number): CFrame
	if not to then
		return CFrame.identity
	end
	return CFrame.new(to.Size.X * x, to.Size.Y * y, to.Size.Z * z)
end

local function lighter(color: Color3, t: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), t)
end

-- Both sides of the body: f(part, side) with side -1 = left, 1 = right.
local function pair(ctx: Ctx, left: string, right: string, fn: (part: BasePart?, side: number) -> ())
	fn(ctx.part(left), -1)
	fn(ctx.part(right), 1)
end

-- Owner 2026-10-21 ("the looks of our characters are awful"): garments that cover the body are drawn as shells, a copy
-- of the body part's own mesh a little larger in the garment's colour and material, so cloth and plate follow the
-- Dawson body (W09) instead of standing off it as blocks. `k` scales the part's size, `offset` is in its space. A body
-- without meshes (the block figure, R6) gets a block of the same size.
local function shell(
	ctx: Ctx,
	body: BasePart?,
	k: Vector3,
	offset: CFrame?,
	color: Color3?,
	material: Enum.Material?
): BasePart?
	if not body then
		return nil
	end
	local size = body.Size * k
	if not body:IsA("MeshPart") then
		return piece(ctx, body, size, offset or CFrame.identity, color, material)
	end
	local archivable = body.Archivable
	body.Archivable = true
	local part = body:Clone()
	body.Archivable = archivable
	if not part then
		return piece(ctx, body, size, offset or CFrame.identity, color, material)
	end
	part:ClearAllChildren()
	part.Name = "Piece"
	part.Size = size
	part.TextureID = ""
	part.Color = color or ctx.color
	part.Material = material or Enum.Material.Fabric
	part.Transparency = 0
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	weld(part, body, offset or CFrame.identity)
	part.Parent = ctx.folder
	return part
end

-- A round piece (a ball with a stretched sphere mesh), for pauldrons, hoods and collars.
local function blob(ctx: Ctx, to: BasePart?, size: Vector3, offset: CFrame, color: Color3?, material: Enum.Material?)
	local part = piece(ctx, to, Vector3.one * math.max(size.X, size.Y, size.Z), offset, color, material)
	if part then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size / part.Size.X
		mesh.Parent = part
	end
	return part
end

-- A flared skirt from the waist to the ankles: `n` cloth panels round the hips, leaning outwards to the hem.
local function skirt(ctx: Ctx, n: number, material: Enum.Material?)
	local l = ctx.lower
	if not l then
		return
	end
	local upper = ctx.part("LeftUpperLeg")
	local lowerLeg = ctx.part("LeftLowerLeg")
	local length = ((if upper then upper.Size.Y else 1.2) + (if lowerLeg then lowerLeg.Size.Y else 1.2)) * 0.92
	local rx, rz = l.Size.X * 0.5, l.Size.Z * 0.62
	local flare = math.rad(9)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local x, z = math.sin(a) * rx, math.cos(a) * rz
		local width = 2 * math.pi * math.max(rx, rz) / n * 1.18
		-- the panel hangs from the hip ring, turned to face out and leaning out at the hem
		local cf = CFrame.new(x, l.Size.Y * 0.2, z)
			* CFrame.Angles(0, a, 0)
			* CFrame.Angles(flare, 0, 0)
			* CFrame.new(0, -length / 2, 0)
		piece(ctx, l, Vector3.new(width, length, 0.07), cf, nil, material or Enum.Material.Fabric)
	end
end

local function cape(ctx: Ctx)
	local t = ctx.torso
	local part = piece(
		ctx,
		t,
		rel(t, 0.95, 1.65, 0.12),
		at(t, 0, -0.38, 0.6) * CFrame.Angles(0.12, 0, 0),
		nil,
		Enum.Material.Fabric
	)
	if part then
		part.Name = OUTFIT_CAPE
		if ctx.model:GetAttribute(LURE_ATTRIBUTE) == true then
			part.Transparency = 1
		end
	end
end

local function belt(ctx: Ctx)
	local l = ctx.lower
	shell(ctx, l, Vector3.new(1.07, 0.42, 1.12), at(l, 0, 0.22, 0), nil, Enum.Material.Leather)
end

local function cap(ctx: Ctx, height: number)
	local h = ctx.head
	piece(ctx, h, rel(h, 1.06, height, 1.06), at(h, 0, 0.5 - height / 2 + 0.02, 0.05), nil, Enum.Material.Fabric)
end

-- One drawing per procedural garment of Logic/CharacterLook.GARMENTS (tests/classlooks.spec checks the names; the
-- number of parts drawn matches GARMENTS[g].pieces).
local DRAW: { [string]: (ctx: Ctx) -> () } = {
	-- a round hood over the back and the top of the head (the face stays free) and its tail down the neck
	hood = function(ctx)
		local h = ctx.head
		if not h then
			return
		end
		blob(ctx, h, rel(h, 1.2, 0.98, 1.14), at(h, 0, 0.1, 0.17), nil, Enum.Material.Fabric)
		piece(
			ctx,
			h,
			rel(h, 0.62, 0.55, 0.1),
			at(h, 0, -0.42, 0.42) * CFrame.Angles(-0.35, 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end,
	crown = function(ctx)
		local h = ctx.head
		piece(
			ctx,
			h,
			Vector3.new(0.18, (h and h.Size.X or 1) * 0.92, (h and h.Size.Z or 1) * 0.92),
			at(h, 0, 0.42, 0.03) * CFrame.Angles(0, 0, math.rad(90)),
			nil,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	end,
	halo = function(ctx)
		local h = ctx.head
		piece(
			ctx,
			h,
			Vector3.new(0.1, (h and h.Size.X or 1) * 1.15, (h and h.Size.Z or 1) * 1.15),
			at(h, 0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
			nil,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	end,
	horns = function(ctx)
		local h = ctx.head
		for _, side in { -1, 1 } do
			blob(ctx, h, rel(h, 0.16, 0.5, 0.16), at(h, 0.36 * side, 0.45, 0.05) * CFrame.Angles(0, 0, -0.45 * side))
		end
	end,
	mask = function(ctx)
		local h = ctx.head
		blob(ctx, h, rel(h, 0.8, 0.3, 0.3), at(h, 0, -0.18, -0.38), nil, Enum.Material.Fabric)
	end,
	cape = cape,
	pauldrons = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			blob(ctx, t, rel(t, 0.42, 0.34, 1.0), at(t, 0.52 * side, 0.42, 0), nil, Enum.Material.Fabric)
		end
	end,
	-- plate over the chest and the hips
	breastplate = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.07, 1.03, 1.12), nil, nil, Enum.Material.Metal)
		shell(
			ctx,
			ctx.lower,
			Vector3.new(1.09, 1.1, 1.14),
			nil,
			ctx.color:Lerp(Color3.new(), 0.15),
			Enum.Material.Metal
		)
	end,
	plate_pauldrons = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			blob(
				ctx,
				t,
				rel(t, 0.5, 0.36, 1.08),
				at(t, 0.56 * side, 0.42, 0) * CFrame.Angles(0, 0, -0.2 * side),
				nil,
				Enum.Material.Metal
			)
		end
	end,
	gauntlets = function(ctx)
		pair(ctx, "LeftLowerArm", "RightLowerArm", function(arm)
			shell(ctx, arm, Vector3.new(1.16, 0.62, 1.16), at(arm, 0, -0.2, 0), nil, Enum.Material.Metal)
		end)
	end,
	greaves = function(ctx)
		pair(ctx, "LeftLowerLeg", "RightLowerLeg", function(leg)
			shell(ctx, leg, Vector3.new(1.12, 0.85, 1.14), at(leg, 0, -0.04, 0), nil, Enum.Material.Metal)
		end)
	end,
	belt = belt,
	-- the robe falls from the hips as a flared skirt of panels (the legs under it are in the robe's colour)
	robe_skirt = function(ctx)
		skirt(ctx, 8, Enum.Material.Fabric)
	end,
	holy_symbol = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.07, 0.38, 0.08), at(t, 0, 0.08, -0.56), nil, Enum.Material.Metal)
		piece(ctx, t, rel(t, 0.2, 0.06, 0.08), at(t, 0, 0.16, -0.56), nil, Enum.Material.Metal)
	end,
	-- a sash round the waist
	sash = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.08, 0.2, 1.13), at(ctx.torso, 0, -0.38, 0), nil, Enum.Material.Fabric)
	end,
	stole = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			piece(ctx, t, rel(t, 0.12, 1.05, 0.06), at(t, 0.2 * side, -0.08, -0.55), nil, Enum.Material.Fabric)
		end
	end,
	leather_vest = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.06, 1.0, 1.1), nil, nil, Enum.Material.Leather)
	end,
	quiver_back = function(ctx)
		local t = ctx.torso
		local tilt = CFrame.Angles(0, 0, math.rad(90 - 25))
		local d = (t and t.Size.Z or 1) * 0.36
		piece(
			ctx,
			t,
			Vector3.new((t and t.Size.Y or 1.6) * 1.0, d, d),
			at(t, 0.18, 0.08, 0.64) * tilt,
			nil,
			Enum.Material.Leather,
			Enum.PartType.Cylinder
		)
		piece(
			ctx,
			t,
			Vector3.new(0.22, d * 0.8, d * 0.8),
			at(t, 0.38, 0.55, 0.64) * tilt,
			lighter(ctx.color, 0.55),
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
	end,
	bracers = function(ctx)
		pair(ctx, "LeftLowerArm", "RightLowerArm", function(arm)
			shell(ctx, arm, Vector3.new(1.14, 0.55, 1.14), at(arm, 0, -0.18, 0), nil, Enum.Material.Leather)
		end)
	end,
	boots = function(ctx)
		pair(ctx, "LeftFoot", "RightFoot", function(foot)
			shell(ctx, foot, Vector3.new(1.12, 1.25, 1.08), at(foot, 0, 0.1, 0), nil, Enum.Material.Leather)
		end)
	end,
	high_collar = function(ctx)
		local t = ctx.torso
		blob(ctx, t, rel(t, 0.7, 0.36, 0.8), at(t, 0, 0.5, 0.08), nil, Enum.Material.Fabric)
	end,
	belt_book = function(ctx)
		belt(ctx)
		local l = ctx.lower
		piece(ctx, l, rel(l, 0.22, 1.1, 0.42), at(l, 0.6, -0.3, -0.1), nil, Enum.Material.Fabric)
	end,
	-- a short cape over the shoulders, shaped like the chest
	shoulder_mantle = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.12, 0.42, 1.16), at(ctx.torso, 0, 0.33, 0), nil, Enum.Material.Fabric)
	end,
	helm_crest = function(ctx)
		local h = ctx.head
		blob(ctx, h, rel(h, 1.12, 0.72, 1.14), at(h, 0, 0.2, 0.06), nil, Enum.Material.Metal)
		piece(ctx, h, rel(h, 0.1, 0.32, 0.86), at(h, 0, 0.56, 0.06), lighter(ctx.color, 0.15), Enum.Material.Metal)
	end,
	fur_mantle = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.16, 0.45, 1.2), at(ctx.torso, 0, 0.32, 0.02), nil, Enum.Material.Fabric)
	end,
	fur_collar = function(ctx)
		local t = ctx.torso
		blob(ctx, t, rel(t, 0.78, 0.26, 1.08), at(t, 0, 0.5, 0), nil, Enum.Material.Fabric)
	end,
	spectacles = function(ctx)
		local h = ctx.head
		for _, side in { -1, 1 } do
			piece(
				ctx,
				h,
				Vector3.new(0.04, (h and h.Size.Y or 1.2) * 0.2, (h and h.Size.Y or 1.2) * 0.2),
				at(h, 0.2 * side, 0.06, -0.51) * CFrame.Angles(0, math.rad(90), 0),
				nil,
				Enum.Material.Glass,
				Enum.PartType.Cylinder
			)
		end
	end,
	wreath = function(ctx)
		local h = ctx.head
		piece(
			ctx,
			h,
			Vector3.new(0.12, (h and h.Size.X or 1.2) * 1.02, (h and h.Size.Z or 1.2) * 1.02),
			at(h, 0, 0.3, 0.02) * CFrame.Angles(0, 0, math.rad(90)),
			nil,
			Enum.Material.Grass,
			Enum.PartType.Cylinder
		)
	end,
	frost_crystals = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			piece(
				ctx,
				t,
				rel(t, 0.2, 0.36, 0.2),
				at(t, 0.55 * side, 0.62, 0) * CFrame.Angles(0, math.rad(45), 0.3 * side),
				nil,
				Enum.Material.Ice
			)
		end
	end,
	glow_seams = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.05, 0.86, 0.04), at(t, 0, 0, -0.56), nil, Enum.Material.Neon)
		piece(ctx, t, rel(t, 0.9, 0.05, 0.04), at(t, 0, -0.22, -0.56), nil, Enum.Material.Neon)
	end,
	ember_arrows = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.12, 0.14, 0.24), at(t, 0.42, 0.66, 0.64), nil, Enum.Material.Neon)
	end,
	amulet = function(ctx)
		local t = ctx.torso
		local d = (t and t.Size.X or 2) * 0.09
		piece(ctx, t, Vector3.new(d, d, d), at(t, 0, 0.18, -0.56), nil, Enum.Material.Neon, Enum.PartType.Ball)
	end,
	tabard = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.55, 1.45, 0.06), at(t, 0, -0.3, -0.57), nil, Enum.Material.Fabric)
	end,
	chain_mail = function(ctx)
		shell(ctx, ctx.torso, Vector3.new(1.05, 1.06, 1.1), at(ctx.torso, 0, -0.03, 0), nil, Enum.Material.DiamondPlate)
	end,
	hair_short = function(ctx)
		cap(ctx, 0.38)
	end,
	hair_long = function(ctx)
		cap(ctx, 0.38)
		local h = ctx.head
		piece(ctx, h, rel(h, 1.0, 1.1, 0.3), at(h, 0, -0.2, 0.45), nil, Enum.Material.Fabric)
	end,
	hair_ponytail = function(ctx)
		cap(ctx, 0.38)
		local h = ctx.head
		piece(
			ctx,
			h,
			rel(h, 0.22, 0.72, 0.2),
			at(h, 0, -0.12, 0.62) * CFrame.Angles(-0.3, 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end,
	hair_braid = function(ctx)
		cap(ctx, 0.38)
		local h = ctx.head
		piece(ctx, h, rel(h, 0.18, 0.95, 0.18), at(h, 0, -0.35, 0.56), nil, Enum.Material.Fabric)
	end,
	hair_topknot = function(ctx)
		cap(ctx, 0.38)
		local h = ctx.head
		local d = (h and h.Size.X or 1.2) * 0.4
		piece(ctx, h, Vector3.new(d, d, d), at(h, 0, 0.6, 0.1), nil, Enum.Material.Fabric, Enum.PartType.Ball)
	end,
	hair_curly = function(ctx)
		local h = ctx.head
		piece(ctx, h, rel(h, 1.14, 0.5, 1.14), at(h, 0, 0.3, 0.05), nil, Enum.Material.Fabric)
		piece(ctx, h, rel(h, 1.1, 0.5, 0.4), at(h, 0, 0.05, 0.42), nil, Enum.Material.Fabric)
	end,
	hair_swept = function(ctx)
		cap(ctx, 0.38)
		local h = ctx.head
		piece(
			ctx,
			h,
			rel(h, 1.05, 0.2, 0.42),
			at(h, 0, 0.48, -0.28) * CFrame.Angles(0.4, 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end,
	hair_shaved = function(ctx)
		local h = ctx.head
		if h and h:IsA("MeshPart") then
			return -- W09: the dynamic head is bare (a shadow box over a sculpted scalp looks like a cap)
		end
		local part = piece(ctx, h, rel(h, 1.01, 0.3, 1.01), at(h, 0, 0.36, 0.02), nil, Enum.Material.SmoothPlastic)
		if part then
			part.Transparency = 0.35
		end
	end,
}
AvatarBuild.DRAW = DRAW

-- Face ----------------------------------------------------------------------------------------------

-- W10: facial hair from parts in the hair colour, placed from the face's front attachment (FaceFrontAttachment: the
-- nose tip; +Y up, -Z out of the face): { width, height, depth, x, y, z, shape } in head widths.
local BEARDS: { [string]: { { any } } } = {
	beard_moustache = {
		{ 0.34, 0.07, 0.12, 0, -0.15, 0.02, "block" },
	},
	beard_goatee = {
		{ 0.3, 0.07, 0.1, 0, -0.15, 0.02, "block" },
		{ 0.18, 0.2, 0.14, 0, -0.33, 0.04, "ball" },
	},
	beard_short = {
		{ 0.34, 0.07, 0.12, 0, -0.15, 0.02, "block" },
		{ 0.6, 0.24, 0.3, 0, -0.32, 0.17, "ball" },
	},
	beard_full = {
		{ 0.36, 0.08, 0.12, 0, -0.15, 0.02, "block" },
		{ 0.74, 0.32, 0.4, 0, -0.32, 0.22, "ball" },
		{ 0.5, 0.26, 0.26, 0, -0.44, 0.12, "ball" },
	},
	beard_long = {
		{ 0.36, 0.08, 0.12, 0, -0.15, 0.02, "block" },
		{ 0.72, 0.3, 0.38, 0, -0.32, 0.21, "ball" },
		{ 0.38, 0.55, 0.22, 0, -0.62, 0.12, "ball" },
	},
}
AvatarBuild.BEARDS = BEARDS

-- The beard and the face paint of the look on a dynamic head (its eyes, nose and mouth are its own).
local function drawFace(ctx: Ctx, face: CharacterLook.FaceSpec)
	local head = ctx.head
	local front = head and head:FindFirstChild("FaceFrontAttachment")
	if not head or not front or not front:IsA("Attachment") then
		return
	end
	local w = head.Size.X
	local hair = Color3.fromHex(face.hair)
	local beard: { { any } } = BEARDS[face.beard] or {}
	for _, p in beard do
		local part = piece(
			ctx,
			head,
			Vector3.new(p[1] * w, p[2] * w, p[3] * w),
			front.CFrame * CFrame.new(p[4] * w, p[5] * w, p[6] * w),
			hair,
			Enum.Material.Fabric,
			if p[7] == "ball" then Enum.PartType.Ball else Enum.PartType.Block
		)
		if part then
			part.Name = "FacePiece"
		end
	end
	local image = BodyLooks.paints[face.paint]
	if image and image ~= 0 then
		local decal = Instance.new("Decal")
		decal.Name = "FacePaint"
		decal.Face = Enum.NormalId.Front
		decal.Texture = `rbxassetid://{image}`
		decal.Color3 = Color3.fromHex(face.paintColor)
		decal.Transparency = 0.1
		decal.Parent = head
		-- the folder is destroyed on clear; the decal lives on the head, so a value in the folder points at it
		local ref = Instance.new("ObjectValue")
		ref.Name = "FacePaintRef"
		ref.Value = decal
		ref.Parent = ctx.folder
	end
end

-- W10: a look part the server loaded into ReplicatedStorage (Data/BodyLooks.PARTS_FOLDER).
local function lookPart(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild(BodyLooks.PARTS_FOLDER)
	return folder and folder:FindFirstChild(name)
end

-- W10: where a layered accessory (WrapLayer) sits on the head in a preview, in head sizes (x, y, z): a ViewportFrame
-- does not fit layered clothing to the body, so the raw mesh is placed and scaled like the fitted one on a live
-- character (measured in Studio on the base body: hair around the head's centre, brows and lashes on the face).
local LAYERED_AT: { [string]: Vector3 } = {
	hair = Vector3.new(0, 0, 0),
	brows = Vector3.new(0, 0.111, -0.21),
	lashes = Vector3.new(0, 0.058, -0.205),
}

-- Puts an accessory on: the handle on the matching attachment of the model first (a preview or the anchored mannequin
-- solves no weld outside the Workspace), then Humanoid:AddAccessory. Marked so clearProcedural removes it. `layered` =
-- the LAYERED_AT kind when a preview shows a layered accessory.
local function wear(ctx: Ctx, accessory: Accessory, layered: string?): boolean
	local humanoid = ctx.model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		accessory:Destroy()
		return false
	end
	accessory:SetAttribute(ASSET_ATTRIBUTE, true)
	local handle = accessory:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CanCollide = false
		handle.CanQuery = false
		handle.CanTouch = false
		handle.Massless = true
		local head = ctx.head
		local at = if layered and handle:FindFirstChildOfClass("WrapLayer") then LAYERED_AT[layered] else nil
		if at and head then
			-- the raw mesh at the size the fitted one has: the head's scale against its own original size
			local original = head:FindFirstChild("OriginalSize")
			local k = if original
					and original:IsA("Vector3Value")
					and original.Value.Y > 0
				then head.Size.Y / original.Value.Y
				else 1
			handle.Size *= k
			handle.CFrame = head.CFrame * CFrame.new(at * head.Size)
		end
		for _, att in (if at then {} else handle:GetChildren()) :: { Instance } do
			if att:IsA("Attachment") then
				local target: Instance? = nil
				for _, p in ctx.model:GetChildren() do
					if p:IsA("BasePart") and p ~= handle then
						target = p:FindFirstChild(att.Name)
						if target then
							break
						end
					end
				end
				if target and target:IsA("Attachment") then
					handle.CFrame = target.WorldCFrame * att.CFrame:Inverse()
					break
				end
			end
		end
	end
	local ok = pcall(function()
		humanoid:AddAccessory(accessory)
	end)
	if not ok then
		accessory:Destroy()
	end
	return ok
end

-- Tints the textures of an accessory with a hair colour (Logic/HairTint): SurfaceAppearance.Color on a light texture,
-- the plain colour for a light colour on a black one; a classic SpecialMesh takes the colour as its vertex colour.
local function tint(accessory: Instance, hex: string, light: boolean)
	local mode, rgb = HairTint.plan(hex, light)
	local color = Color3.new(rgb[1], rgb[2], rgb[3])
	for _, item in accessory:GetDescendants() do
		if item:IsA("SurfaceAppearance") then
			if mode == "flat" then
				item:Destroy()
			else
				pcall(function()
					(item :: any).Color = color
				end)
			end
		elseif item:IsA("MeshPart") and mode == "flat" then
			item.TextureID = ""
			item.Color = color
			item.Material = Enum.Material.SmoothPlastic
		elseif item:IsA("SpecialMesh") then
			item.VertexColor = Vector3.new(rgb[1], rgb[2], rgb[3])
		end
	end
end

-- W10, previews only (the server swaps the head through the description): the dynamic head of `faceId` in place of the
-- figure's head, scaled like the head it replaces (its OriginalSize against its size) and set on the neck.
local function swapHead(model: Model, faceId: string)
	local old = model:FindFirstChild("Head")
	local template = lookPart(`head_{faceId}`)
	if not old or not old:IsA("BasePart") or old:GetAttribute("VaelthornFace") == faceId then
		return
	end
	if not template or not template:IsA("MeshPart") then
		return
	end
	local oldOriginal = old:FindFirstChild("OriginalSize")
	local newOriginal = template:FindFirstChild("OriginalSize")
	local factor = Vector3.one
	if oldOriginal and oldOriginal:IsA("Vector3Value") and oldOriginal.Value.Magnitude > 0 then
		factor = old.Size / oldOriginal.Value
	end
	local head = template:Clone()
	local base = if newOriginal and newOriginal:IsA("Vector3Value") then newOriginal.Value else head.Size
	head.Size = base * factor
	for _, att in head:GetChildren() do
		if att:IsA("Attachment") then
			att.Position *= factor
		end
	end
	local oldNeck = old:FindFirstChild("NeckRigAttachment")
	local newNeck = head:FindFirstChild("NeckRigAttachment")
	if oldNeck and oldNeck:IsA("Attachment") and newNeck and newNeck:IsA("Attachment") then
		head.CFrame = oldNeck.WorldCFrame * newNeck.CFrame:Inverse()
	else
		head.CFrame = old.CFrame
	end
	head.Anchored = old.Anchored
	head.CanCollide = false
	head.Color = old.Color
	head.Name = "Head"
	head:SetAttribute("VaelthornFace", faceId)
	head.Parent = model
	old:Destroy()
end

-- W10, previews only: the build's width and depth on the body parts (the server scales the real body through the
-- description). Each part keeps its size and its place against the root at scale 1 in attributes.
local function scaleBuild(model: Model, build: { width: number, depth: number })
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local k = Vector3.new(build.width, 1, build.depth)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local size = p:GetAttribute("VaelthornSize")
			local at = p:GetAttribute("VaelthornAt")
			if typeof(size) ~= "Vector3" or typeof(at) ~= "CFrame" then
				size, at = p.Size, root.CFrame:ToObjectSpace(p.CFrame)
				p:SetAttribute("VaelthornSize", size)
				p:SetAttribute("VaelthornAt", at)
			end
			local where = at :: CFrame
			p.Size = (size :: Vector3) * k
			p.CFrame = root.CFrame * (CFrame.new(where.Position * k) * where.Rotation)
		end
	end
end

-- Owner's models (Data/ClassLooks.assets) ----------------------------------------------------------

local function assetTemplate(key: string): Instance?
	local def = ClassLooks.assets[key]
	if not def then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("ClassLooks")
	return folder and folder:FindFirstChild(def.model)
end

-- Puts the owner's model of `key` on; false when there is none (the procedural garment is drawn instead).
local function placeAsset(ctx: Ctx, key: string, color: Color3): boolean
	local template = assetTemplate(key)
	local def = ClassLooks.assets[key]
	if not template or not def then
		warnOnce(`asset:{key}`, `no model Assets.ClassLooks.{def and def.model or key}: procedural look instead`)
		return false
	end
	local clone = template:Clone()
	if LookBuild.stripScripts(clone) > 0 then
		warnOnce(`scripts:{key}`, `removed scripts from Assets.ClassLooks.{def.model}`)
	end
	local humanoid = ctx.model:FindFirstChildOfClass("Humanoid")
	if clone:IsA("Accessory") then
		clone:SetAttribute(ASSET_ATTRIBUTE, true)
		if not humanoid then
			clone:Destroy()
			return false
		end
		local ok = pcall(function()
			humanoid:AddAccessory(clone)
		end)
		if not ok then
			clone:Destroy()
			return false
		end
		return true
	end
	local to = ctx.part(def.attach or "UpperTorso")
	if not to then
		clone:Destroy()
		return false
	end
	local offset = def.offset or { 0, 0, 0 }
	local placed = CFrame.new(offset[1] or 0, offset[2] or 0, offset[3] or 0)
	if clone:IsA("Model") then
		if def.scale then
			clone:ScaleTo(def.scale)
		end
		clone:PivotTo(to.CFrame * placed)
	elseif clone:IsA("BasePart") then
		clone.CFrame = to.CFrame * placed
	end
	for _, item in (if clone:IsA("BasePart") then { clone } else clone:GetDescendants()) :: { Instance } do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = to
			w.Part1 = item
			w.Parent = item
			if item:GetAttribute("Tint") == true then
				item.Color = color -- an owner's part marked Tint takes the garment's colour
			end
		end
	end
	clone.Parent = ctx.folder
	return true
end

-- The Roblox hairstyle of the look (Data/BodyLooks.hairs, loaded by the server), tinted with the hair colour; false
-- when there is none (the procedural hairstyle is drawn instead).
local function placeHair(ctx: Ctx, hairId: string, hex: string, preview: boolean?): boolean
	local def = BodyLooks.hairs[hairId]
	local template = lookPart(`hair_{hairId}`)
	if not def or not template or not template:IsA("Accessory") then
		return false
	end
	local clone = template:Clone()
	LookBuild.stripScripts(clone)
	tint(clone, hex, def.light)
	return wear(ctx, clone, if preview then "hair" else nil)
end

-- Apply / clear -------------------------------------------------------------------------------------

local function hasQuiver(model: Model): boolean
	for _, child in model:GetDescendants() do
		if child.Name == "VaelthornOffhand" and child:GetAttribute("WeaponType") == "quiver" then
			return true
		end
	end
	return false
end

-- Removes everything applyProcedural added: colours (VaelthornColor), parked clothing and face decal, the parts folder
-- and the owner's accessories.
function AvatarBuild.clearProcedural(model: Model)
	local folder = model:FindFirstChild(FOLDER)
	if folder then
		for _, item in folder:GetChildren() do
			if item:IsA("ObjectValue") and item.Value then
				item.Value:Destroy() -- W10: the face paint decal on the head
			end
		end
		folder:Destroy()
	end
	for _, child in model:GetChildren() do
		if child:GetAttribute(ASSET_ATTRIBUTE) == true then
			child:Destroy()
		elseif child:IsA("BasePart") then
			local original = child:GetAttribute(COLOR_ATTRIBUTE)
			if typeof(original) == "Color3" then
				child.Color = original
				child:SetAttribute(COLOR_ATTRIBUTE, nil)
			end
		end
	end
	local hidden = model:FindFirstChild(HIDDEN)
	if hidden then
		local head = model:FindFirstChild("Head")
		for _, item in hidden:GetChildren() do
			item.Parent = if item:IsA("Decal") and head then head else model
		end
		hidden:Destroy()
	end
end

local function park(model: Model, item: Instance)
	local hidden = model:FindFirstChild(HIDDEN)
	if not hidden then
		local folder = Instance.new("Folder")
		folder.Name = HIDDEN
		folder.Parent = model
		hidden = folder
	end
	item.Parent = hidden
end

-- Draws the look `spec` (Logic/CharacterLook.resolve) on `model`: body colours, the procedural garments (or the
-- owner's models), the hairstyle and the face. Catalog pieces come from the description (server), so a preview shows
-- the procedural garment for them.
function AvatarBuild.applyProcedural(model: Model, spec: CharacterLook.LookSpec, preview: boolean?)
	AvatarBuild.clearProcedural(model)
	if preview == true and spec.mode == "class" then
		if spec.face then
			swapHead(model, spec.face.id)
		end
		scaleBuild(model, spec.build)
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = model
	local parts: { [string]: BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			parts[child.Name] = child
		end
	end
	local function part(name: string): BasePart?
		return parts[name]
	end
	-- (a) body colours
	for name, p in parts do
		local hex = spec.body[name] or spec.body[R6_PART[name] or ""]
		if hex then
			p:SetAttribute(COLOR_ATTRIBUTE, p.Color)
			p.Color = Color3.fromHex(hex)
		end
	end
	-- (b) clothing textures would cover the colours: parked while the look paints the body (restored on clear)
	local painted = next(spec.body) ~= nil
	if spec.mode == "class" or painted then
		for _, child in model:GetChildren() do
			local hideShirt = child:IsA("Shirt") and spec.shirt == 0
			local hidePants = child:IsA("Pants") and spec.pants == 0
			if hideShirt or hidePants or child:IsA("ShirtGraphic") then
				park(model, child)
			end
		end
	end
	local ctx: Ctx = {
		model = model,
		folder = folder,
		color = Color3.new(1, 1, 1),
		head = part("Head"),
		torso = part("UpperTorso") or part("Torso"),
		lower = part("LowerTorso") or part("Torso"),
		part = part,
	}
	-- (c, d) garments; the quiver from the equipment replaces the procedural one
	local quiver = hasQuiver(model)
	for _, item in spec.garments do
		local draw = DRAW[item.g]
		if (item.catalog == 0 or preview == true) and draw and not (quiver and QUIVER_GARMENTS[item.g]) then
			ctx.color = Color3.fromHex(item.color)
			if not (item.asset and placeAsset(ctx, item.asset, ctx.color)) then
				draw(ctx)
			end
		end
	end
	-- (f) hairstyle
	local hair = spec.hair
	if hair and (hair.catalog == 0 or preview == true) then
		ctx.color = Color3.fromHex(hair.color)
		local draw = DRAW[`hair_{hair.style}`]
		local placed = (hair.asset ~= nil and placeAsset(ctx, hair.asset, ctx.color))
			or (ctx.head ~= nil and ctx.head:IsA("MeshPart") and placeHair(ctx, hair.id, hair.color, preview))
		if draw and not placed then
			draw(ctx)
		end
	end
	-- (e) face (W10): brows and lashes (a preview puts on the chosen ones, the server has them from the description),
	-- the brows in the hair colour, the beard and the face paint
	local face = spec.face
	local head = ctx.head
	if face and head then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") and child.Name == "face" then
				park(model, child)
			end
		end
		if preview == true then
			for _, child in model:GetChildren() do
				if child:IsA("Accessory") and FACE_ACCESSORY[child.Name] then
					park(model, child)
				end
			end
			local brows = lookPart(`brows_{face.brows}`)
			if brows and brows:IsA("Accessory") then
				wear(ctx, brows:Clone(), "brows")
			end
			local lashes = lookPart(`lashes_{face.id}`)
			if lashes and lashes:IsA("Accessory") then
				wear(ctx, lashes:Clone(), "lashes")
			end
		end
		for _, child in model:GetChildren() do
			if child:IsA("Accessory") and FACE_ACCESSORY[child.Name] == "brows" then
				tint(child, face.hair, false)
			end
		end
		drawFace(ctx, face)
	end
end

-- Mannequin -----------------------------------------------------------------------------------------

local BLOCK_PARTS: { { name: string, size: Vector3, at: Vector3 } } = {
	{ name = "Head", size = Vector3.new(1.2, 1.2, 1.2), at = Vector3.new(0, 1.85, 0) },
	{ name = "UpperTorso", size = Vector3.new(2, 1.6, 1), at = Vector3.new(0, 0.45, 0) },
	{ name = "LowerTorso", size = Vector3.new(2, 0.4, 1), at = Vector3.new(0, -0.55, 0) },
	{ name = "LeftUpperArm", size = Vector3.new(1, 1.17, 1), at = Vector3.new(-1.5, 0.66, 0) },
	{ name = "RightUpperArm", size = Vector3.new(1, 1.17, 1), at = Vector3.new(1.5, 0.66, 0) },
	{ name = "LeftLowerArm", size = Vector3.new(1, 1.05, 1), at = Vector3.new(-1.5, -0.45, 0) },
	{ name = "RightLowerArm", size = Vector3.new(1, 1.05, 1), at = Vector3.new(1.5, -0.45, 0) },
	{ name = "LeftHand", size = Vector3.new(1, 0.3, 1), at = Vector3.new(-1.5, -1.12, 0) },
	{ name = "RightHand", size = Vector3.new(1, 0.3, 1), at = Vector3.new(1.5, -1.12, 0) },
	{ name = "LeftUpperLeg", size = Vector3.new(1, 1.2, 1), at = Vector3.new(-0.5, -1.35, 0) },
	{ name = "RightUpperLeg", size = Vector3.new(1, 1.2, 1), at = Vector3.new(0.5, -1.35, 0) },
	{ name = "LeftLowerLeg", size = Vector3.new(1, 1.2, 1), at = Vector3.new(-0.5, -2.55, 0) },
	{ name = "RightLowerLeg", size = Vector3.new(1, 1.2, 1), at = Vector3.new(0.5, -2.55, 0) },
	{ name = "LeftFoot", size = Vector3.new(1, 0.3, 1), at = Vector3.new(-0.5, -3.3, 0) },
	{ name = "RightFoot", size = Vector3.new(1, 0.3, 1), at = Vector3.new(0.5, -3.3, 0) },
}

-- A standard R15 figure of blocks named like R15 parts (root at the origin), anchored, without physics: the preview
-- fallback when the server's mannequin is missing.
function AvatarBuild.blockFigure(): Model
	local model = Instance.new("Model")
	model.Name = AvatarBuild.MANNEQUIN
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root
	local skin = Color3.fromHex(ClassLooks.skinById[ClassLooks.DEFAULT_LOOK.skin].color)
	for _, def in BLOCK_PARTS do
		local p = Instance.new("Part")
		p.Name = def.name
		p.Size = def.size
		p.CFrame = CFrame.new(def.at)
		p.Color = skin
		p.Anchored = true
		p.CanCollide = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	return model
end

-- A preview figure: a clone of the server's mannequin (anchored, at the origin), or the block figure.
function AvatarBuild.previewFigure(): Model
	local mannequin = ReplicatedStorage:FindFirstChild(AvatarBuild.MANNEQUIN)
	if mannequin and mannequin:IsA("Model") then
		local archivable = mannequin.Archivable
		mannequin.Archivable = true
		local clone = mannequin:Clone()
		mannequin.Archivable = archivable
		for _, item in clone:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		clone:PivotTo(CFrame.new())
		return clone
	end
	return AvatarBuild.blockFigure()
end

return AvatarBuild
