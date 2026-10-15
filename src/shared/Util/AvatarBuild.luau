--!strict
-- Class looks on a model (DESIGN-17 §9a, S132): the HumanoidDescription of a character (server: standard R15 body and
-- scales, no avatar animations, catalog clothing and accessories) and the procedural look drawn from parts over it
-- (body colours, garments, hairstyle, face) from a Logic/CharacterLook.LookSpec. Used by the server (CosmeticService on
-- the real character, the mannequin) and the client previews (creator, wardrobe, look window: a clone of the mannequin
-- or of the own character). Every apply first removes what it added before, so it can be called again at any time.
-- Contract with S122 (Util/CosmeticLook.applyLure): every cape part of an outfit is named OutfitCape and is invisible
-- while the model's attribute LureCape is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterLook = require("../Logic/CharacterLook")
local ClassLooks = require("../Data/ClassLooks")
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
-- `base` (the player's own description) with the outfit's catalog clothing over it. Both: standard body parts (no
-- Rthro or dynamic heads), scales standard / clamped (Logic/CharacterLook), no animations.
function AvatarBuild.description(spec: CharacterLook.LookSpec, base: HumanoidDescription?): HumanoidDescription
	local desc: any = if base and spec.mode == "avatar" then base:Clone() else Instance.new("HumanoidDescription")
	local scales: { [string]: number } = CharacterLook.STANDARD :: any
	if spec.mode == "avatar" and base then
		scales = CharacterLook.clampScales({
			height = base.HeightScale,
			width = base.WidthScale,
			depth = base.DepthScale,
			head = base.HeadScale,
			bodyType = base.BodyTypeScale,
			proportion = base.ProportionScale,
		})
	end
	desc.HeightScale = scales.height
	desc.WidthScale = scales.width
	desc.DepthScale = scales.depth
	desc.HeadScale = scales.head
	desc.BodyTypeScale = scales.bodyType
	desc.ProportionScale = scales.proportion
	for _, field in BODY_FIELDS do
		desc[field] = 0
	end
	for _, field in ANIMATIONS do
		desc[field] = 0
	end
	if spec.mode == "class" then
		local skin = Color3.fromHex(spec.skin or ClassLooks.skinById[ClassLooks.DEFAULT_LOOK.skin].color)
		for _, field in COLOR_FIELDS do
			desc[field] = skin
		end
		desc.Face = if spec.face then spec.face.catalog else 0
		desc.Shirt = spec.shirt
		desc.Pants = spec.pants
		desc.GraphicTShirt = 0
		for _, field in ACCESSORY_FIELDS do
			desc[field] = ""
		end
		pcall(function()
			desc:SetAccessories({}, true) -- layered clothing of a copied description, never in the class look
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
	piece(ctx, l, rel(l, 1.06, 0.7, 1.1), at(l, 0, 0.1, 0))
end

local function cap(ctx: Ctx, height: number)
	local h = ctx.head
	piece(ctx, h, rel(h, 1.06, height, 1.06), at(h, 0, 0.5 - height / 2 + 0.02, 0.05), nil, Enum.Material.Fabric)
end

-- One drawing per procedural garment of Logic/CharacterLook.GARMENTS (tests/classlooks.spec checks the names; the
-- number of parts drawn matches GARMENTS[g].pieces).
local DRAW: { [string]: (ctx: Ctx) -> () } = {
	hood = function(ctx)
		local h = ctx.head
		piece(ctx, h, rel(h, 1.18, 1.12, 1.18), at(h, 0, 0.07, 0.06), nil, Enum.Material.Fabric)
	end,
	crown = function(ctx)
		local h = ctx.head
		piece(ctx, h, rel(h, 0.96, 0.29, 0.96), at(h, 0, 0.62, 0), nil, Enum.Material.Neon)
	end,
	halo = function(ctx)
		local h = ctx.head
		piece(
			ctx,
			h,
			Vector3.new(0.1, (h and h.Size.X or 1) * 1.15, (h and h.Size.Z or 1) * 1.15),
			at(h, 0, 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
			nil,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
	end,
	horns = function(ctx)
		local h = ctx.head
		for _, side in { -1, 1 } do
			piece(ctx, h, rel(h, 0.2, 0.58, 0.2), at(h, 0.37 * side, 0.62, 0) * CFrame.Angles(0, 0, -0.4 * side))
		end
	end,
	mask = function(ctx)
		local h = ctx.head
		piece(ctx, h, rel(h, 0.88, 0.38, 0.17), at(h, 0, -0.12, -0.46), nil, Enum.Material.Fabric)
	end,
	cape = cape,
	pauldrons = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			piece(ctx, t, rel(t, 0.45, 0.31, 1.1), at(t, 0.575 * side, 0.47, 0), nil, Enum.Material.Metal)
		end
	end,
	breastplate = function(ctx)
		local t, l = ctx.torso, ctx.lower
		piece(ctx, t, rel(t, 1.06, 0.92, 1.14), at(t, 0, 0.04, 0), nil, Enum.Material.Metal)
		piece(
			ctx,
			l,
			rel(l, 1.1, 1.7, 1.16),
			at(l, 0, -0.25, 0),
			ctx.color:Lerp(Color3.new(), 0.15),
			Enum.Material.Metal
		)
	end,
	plate_pauldrons = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			piece(
				ctx,
				t,
				rel(t, 0.52, 0.36, 1.24),
				at(t, 0.6 * side, 0.45, 0) * CFrame.Angles(0, 0, -0.18 * side),
				nil,
				Enum.Material.Metal
			)
		end
	end,
	gauntlets = function(ctx)
		pair(ctx, "LeftHand", "RightHand", function(hand)
			piece(ctx, hand, rel(hand, 1.16, 1.7, 1.16), at(hand, 0, 0.3, 0), nil, Enum.Material.Metal)
		end)
	end,
	greaves = function(ctx)
		pair(ctx, "LeftLowerLeg", "RightLowerLeg", function(leg)
			piece(ctx, leg, rel(leg, 1.1, 0.9, 1.16), at(leg, 0, 0.02, -0.04), nil, Enum.Material.Metal)
		end)
	end,
	belt = belt,
	robe_skirt = function(ctx)
		local l = ctx.lower
		local upper = ctx.part("LeftUpperLeg")
		local lowerLeg = ctx.part("LeftLowerLeg")
		local length = (if upper then upper.Size.Y else 1.2) + (if lowerLeg then lowerLeg.Size.Y else 1.2)
		local lh = if l then l.Size.Y else 0.4
		piece(
			ctx,
			l,
			Vector3.new((l and l.Size.X or 2) * 1.08, length * 0.95, (l and l.Size.Z or 1) * 1.18),
			CFrame.new(0, -(lh / 2 + length * 0.95 / 2) + lh * 0.4, 0),
			nil,
			Enum.Material.Fabric
		)
	end,
	holy_symbol = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.07, 0.38, 0.08), at(t, 0, 0.08, -0.56), nil, Enum.Material.Metal)
		piece(ctx, t, rel(t, 0.2, 0.06, 0.08), at(t, 0, 0.16, -0.56), nil, Enum.Material.Metal)
	end,
	sash = function(ctx)
		local t = ctx.torso
		piece(
			ctx,
			t,
			rel(t, 1.14, 0.16, 1.12),
			at(t, 0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(32)),
			nil,
			Enum.Material.Fabric
		)
	end,
	stole = function(ctx)
		local t = ctx.torso
		for _, side in { -1, 1 } do
			piece(ctx, t, rel(t, 0.12, 1.05, 0.06), at(t, 0.2 * side, -0.08, -0.55), nil, Enum.Material.Fabric)
		end
	end,
	leather_vest = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 1.05, 0.94, 1.1), at(t, 0, -0.02, 0))
	end,
	quiver_back = function(ctx)
		local t = ctx.torso
		local tilt = CFrame.Angles(0, 0, math.rad(-25))
		piece(ctx, t, rel(t, 0.18, 1.0, 0.36), at(t, 0.18, 0.08, 0.64) * tilt)
		piece(
			ctx,
			t,
			rel(t, 0.16, 0.18, 0.3),
			at(t, 0.38, 0.55, 0.64) * tilt,
			lighter(ctx.color, 0.55),
			Enum.Material.Fabric
		)
	end,
	bracers = function(ctx)
		pair(ctx, "LeftLowerArm", "RightLowerArm", function(arm)
			piece(ctx, arm, rel(arm, 1.12, 0.62, 1.12), at(arm, 0, -0.12, 0))
		end)
	end,
	boots = function(ctx)
		pair(ctx, "LeftFoot", "RightFoot", function(foot)
			piece(ctx, foot, rel(foot, 1.1, 2.4, 1.12), at(foot, 0, 0.62, 0))
		end)
	end,
	high_collar = function(ctx)
		local t = ctx.torso
		piece(
			ctx,
			t,
			rel(t, 0.62, 0.42, 0.24),
			at(t, 0, 0.62, 0.42) * CFrame.Angles(-0.25, 0, 0),
			nil,
			Enum.Material.Fabric
		)
	end,
	belt_book = function(ctx)
		belt(ctx)
		local l = ctx.lower
		piece(ctx, l, rel(l, 0.22, 1.1, 0.42), at(l, 0.58, -0.35, -0.1), nil, Enum.Material.Fabric)
	end,
	shoulder_mantle = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 1.26, 0.26, 1.22), at(t, 0, 0.42, 0), nil, Enum.Material.Fabric)
	end,
	helm_crest = function(ctx)
		local h = ctx.head
		piece(ctx, h, rel(h, 1.12, 0.98, 1.12), at(h, 0, 0.09, 0), nil, Enum.Material.Metal)
		piece(ctx, h, rel(h, 0.12, 0.34, 0.92), at(h, 0, 0.66, 0.04), lighter(ctx.color, 0.15), Enum.Material.Metal)
	end,
	fur_mantle = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 1.3, 0.32, 1.3), at(t, 0, 0.45, 0.04), nil, Enum.Material.Fabric)
	end,
	fur_collar = function(ctx)
		local t = ctx.torso
		piece(ctx, t, rel(t, 0.72, 0.2, 1.2), at(t, 0, 0.55, 0), nil, Enum.Material.Fabric)
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
			Vector3.new(0.12, (h and h.Size.X or 1.2) * 1.08, (h and h.Size.Z or 1.2) * 1.08),
			at(h, 0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
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
				at(t, 0.55 * side, 0.66, 0) * CFrame.Angles(0, math.rad(45), 0.3 * side),
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
		local t = ctx.torso
		piece(ctx, t, rel(t, 1.06, 1.15, 1.1), at(t, 0, -0.12, 0), nil, Enum.Material.DiamondPlate)
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
		local part = piece(ctx, h, rel(h, 1.01, 0.3, 1.01), at(h, 0, 0.36, 0.02), nil, Enum.Material.SmoothPlastic)
		if part then
			part.Transparency = 0.35
		end
	end,
}
AvatarBuild.DRAW = DRAW

-- Face ----------------------------------------------------------------------------------------------

local DARK = Color3.fromHex("#1E1A18")

-- One feature of the face at (x, y) (0..1 of the head's front, as the viewer sees it), w x h of it, turned clockwise.
type Mark = (x: number, y: number, w: number, h: number, color: Color3, rotation: number?, round: boolean?) -> ()

-- Live character: Frames on a SurfaceGui on the head's front.
local function guiMarks(ctx: Ctx, head: BasePart): Mark
	local gui = Instance.new("SurfaceGui")
	gui.Name = "VaelthornFace"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.AlwaysOnTop = false
	gui.Adornee = head
	gui.Parent = ctx.folder
	return function(x, y, w, h, color, rotation, round)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Rotation = rotation or 0
		f.Parent = gui
		if round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.3, 0)
			corner.Parent = f
		end
	end
end

-- Preview (a ViewportFrame draws no SurfaceGui): thin parts on the head's front, each a little further out than the
-- one before (a later feature covers an earlier one). The front is -Z, the viewer's left is +X.
local function partMarks(ctx: Ctx, head: BasePart): Mark
	local layer = 0
	return function(x, y, w, h, color, rotation)
		layer += 1
		local size = head.Size
		local offset = CFrame.new((0.5 - x) * size.X, (0.5 - y) * size.Y, -size.Z * 0.5 - 0.004 * layer)
			* CFrame.Angles(0, 0, math.rad(rotation or 0))
		local part = piece(ctx, head, Vector3.new(size.X * w, size.Y * h, 0.05), offset, color)
		if part then
			part.Name = "FacePiece"
		end
	end
end

local EYE_HEIGHT: { [string]: number } = { calm = 0.06, narrow = 0.035, wide = 0.085, tired = 0.045 }

-- The procedural face on the front of the head (eyes, brows, mouth or beard, a scar or freckles): a SurfaceGui on a
-- live character, thin parts in a preview (S132 review).
local function drawFace(ctx: Ctx, face: CharacterLook.FaceSpec, skin: Color3, preview: boolean?)
	local head = ctx.head
	if not head then
		return
	end
	local frame = if preview == true then partMarks(ctx, head) else guiMarks(ctx, head)
	local hair = Color3.fromHex(face.hair)
	local brow = hair:Lerp(DARK, 0.4)
	-- eyes
	local eye = EYE_HEIGHT[face.eyes] or 0.06
	for _, x in { 0.33, 0.67 } do
		if face.eyes == "wide" then
			frame(x, 0.43, 0.14, eye + 0.02, Color3.fromHex("#F2EEE6"))
		end
		frame(x, 0.43, 0.09, eye, DARK)
		if face.eyes == "tired" then
			frame(x, 0.395, 0.12, 0.02, skin:Lerp(DARK, 0.35))
		end
	end
	-- brows
	local browY = if face.brows == "raised" then 0.28 else 0.32
	for i, x in { 0.33, 0.67 } do
		local side = if i == 1 then -1 else 1
		local rotation = if face.brows == "stern" then 14 * side else 0
		frame(x, browY, 0.17, 0.035, brow, rotation)
	end
	-- mouth or beard
	if face.mouth == "beard" then
		frame(0.5, 0.8, 0.62, 0.34, hair, nil, true)
		frame(0.5, 0.67, 0.22, 0.025, DARK)
	elseif face.mouth == "smile" then
		frame(0.5, 0.68, 0.2, 0.03, DARK)
		frame(0.39, 0.665, 0.05, 0.025, DARK, -25)
		frame(0.61, 0.665, 0.05, 0.025, DARK, 25)
	elseif face.mouth == "frown" then
		frame(0.5, 0.68, 0.18, 0.028, DARK)
		frame(0.39, 0.695, 0.05, 0.025, DARK, 25)
		frame(0.61, 0.695, 0.05, 0.025, DARK, -25)
	else
		frame(0.5, 0.68, 0.22, 0.025, DARK)
	end
	-- mark
	if face.mark == "scar" then
		frame(0.68, 0.42, 0.03, 0.3, Color3.fromHex("#8A4A3E"), 20)
	elseif face.mark == "freckles" then
		local dot = skin:Lerp(Color3.fromHex("#6B3E22"), 0.55)
		for _, p in { { 0.24, 0.55 }, { 0.3, 0.58 }, { 0.27, 0.62 }, { 0.7, 0.55 }, { 0.76, 0.58 }, { 0.73, 0.62 } } do
			frame(p[1], p[2], 0.025, 0.025, dot)
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
		if draw and not (hair.asset and placeAsset(ctx, hair.asset, ctx.color)) then
			draw(ctx)
		end
	end
	-- (e) face
	local face = spec.face
	local head = ctx.head
	if face and head and (face.catalog == 0 or preview == true) then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") and child.Name == "face" then
				park(model, child)
			end
		end
		drawFace(ctx, face, Color3.fromHex(spec.skin or "#D6A57C"), preview)
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
