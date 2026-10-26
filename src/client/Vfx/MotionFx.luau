--!strict
-- Template animation (owner 2026-10-26: "wyvern ... bierze wdech nie wypuszcza ognia", "iceElemental burst ... na
-- koniec lodowe kolce"): the effects a template action releases, drawn on the rig as the action plays, in the game
-- (Controllers/AnimationController) and in /animlab (Controllers/AnimLabController) alike. Data/MotionFx says which
-- piece, at which anchor and when; Logic/ActionFx times it on the action's keyed timeline (the server's hit W is the
-- strike's end) and gives the element and the reach of the action's ability.
--   streams    breath (a flame / frost / venom stream from the mouth, following the head as it sweeps: the stream,
--              a white-hot core, embers or ice glints, smoke or mist rolling off its end, a faint warm haze, a
--              flickering light), charge (the element gathering in the throat or the hand, its light growing), arc
--              (lightning crackling between the wing tips), smolder (smoke trickling from the mouth after a fire breath)
--              trail (a streak behind the weapon through a heavy swing), held (the rock or orb in the hand until the throw)
--   one-shots  spit, bolt, flare, nova (by element: ice shards flung out of the body on ballistic arcs and ice spikes
--              erupting from the ground in two rings, then shattering; embers and flame columns in a ring; a violet ring
--              with bone or void shards; a green ring with leaves or venom; arcs), shatter (a body bursting into ice
--              shards), slam, dust, screech (rings of force running out of the mouth), wisps, feathers, splinters,
--              leaves, snow
-- Anchors (Data/MotionFx.ANCHORS) are resolved once per rig: a point in a bone's rest frame (it follows the animated
-- bone through TransformedWorldCFrame), or in a part's frame for the rigid models (their PrimaryPart moves whole).
-- Budget (phones too): nothing beyond CULL studs from the camera, the simple version beyond Config.Vfx.simpleBeyond or on
-- low quality; stream rates x the graphics level's particle share (a phone x TOUCH_SHARE, no haze and no smoke layer),
-- every layer on pooled holders within the device limits (Vfx/Pool) and lights within the light budget; no tables
-- are made per frame (one per action start and per piece). Everything runs on the effect clock (AnimLab freezes it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActionFx = require(ReplicatedStorage.Shared.Logic.ActionFx)
local BipedRigs = require(ReplicatedStorage.Shared.Data.BipedRigs)
local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local FlyerMotion = require(ReplicatedStorage.Shared.Logic.FlyerMotion)
local FlyerRigs = require(ReplicatedStorage.Shared.Data.FlyerRigs)
local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local Library = require(script.Parent.Library)
local LmKit = require(script.Parent.LmKit)
local MonsterRelease = require(ReplicatedStorage.Shared.Data.MonsterRelease)
local MotionFxData = require(ReplicatedStorage.Shared.Data.MotionFx)
local Pool = require(script.Parent.Pool)
local QuadRigs = require(ReplicatedStorage.Shared.Data.QuadRigs)
local RigidRigs = require(ReplicatedStorage.Shared.Data.RigidRigs)
local State = require(script.Parent.Parent.UI.State)
local Textures = require(script.Parent.Textures)

local kit = Library.kit
local kp = kit.kp
local tween = kit.tween
local rng = LmKit.rng

local MotionFx = {}

local CULL = { desktop = 110, touch = 70 } -- studs from the camera past which nothing is drawn
local TOUCH_SHARE = 0.7 -- a phone's stream rates
local BREATH_DIP = 0.2 -- sine of the steepest downward angle of a breath stream
local BREATH_SHARE = 0.8 -- the least rate share of a breath stream (low quality, far, phone)
local MAN = 5 -- studs: the drawn height of a man (size 1)
local CLAIM_FRESH = 0.5 -- s: an owner stepped this recently is being animated (claims)
local HIT_FRESH = 0.25 -- s: a flinch first seen this late shows no puff
local WHITE = Color3.new(1, 1, 1)
local ICE_PART = Color3.fromHex("#BFEFFF")
local ICE_SPIKE = Color3.fromHex("#7FCBF5")
local EARTH = Color3.fromHex("#7A5F45")
local EARTH_DARK = Color3.fromHex("#4E3B2B")
local DUST_FLASH = Color3.fromHex("#F2E2C4")
local DUST_RING = Color3.fromHex("#D9C3A0")
local WOOD = Color3.fromHex("#6B4E32")
local BARK = Color3.fromHex("#3B2A1C")
local SNOW = Color3.fromHex("#EEF6FF")
local LEAF = Color3.fromHex("#6F7F3A")
local LEAF_DRY = Color3.fromHex("#8A6A3A")
local ROCK = Color3.fromHex("#6E655A")
local BONE = Color3.fromHex("#E6DCC0")
local VOID = Color3.fromHex("#6A4FC0")
local STEEL = Color3.fromHex("#DCE6F0")
local TRAIL_LIFE = 0.16 -- s: a weapon streak's tail
local FEATHERS: { [string]: Color3 } = {
	crow = Color3.fromHex("#26262C"),
	vulture = Color3.fromHex("#4A3B30"),
	harpy = Color3.fromHex("#8C7A64"),
}
local FEATHER = Color3.fromHex("#4A4038")

-- The colours of an element: the white-hot core, the body of the effect, its dying end, its smoke.
type Palette = { core: Color3, main: Color3, deep: Color3, smoke: Color3 }
local function palette(core: string, main: string, deep: string, smoke: string): Palette
	return {
		core = Color3.fromHex(core),
		main = Color3.fromHex(main),
		deep = Color3.fromHex(deep),
		smoke = Color3.fromHex(smoke),
	}
end
local PALETTES: { [string]: Palette } = {
	fire = palette("#FFF1B8", "#FF8A2A", "#8A1A06", "#2E2826"),
	ice = palette("#F4FCFF", "#9EDCFF", "#3A7FB8", "#DDF3FF"),
	poison = palette("#E8FFA0", "#7ACB3A", "#2E5A12", "#4A6A2A"),
	lightning = palette("#FFFFFF", "#E8E25A", "#8A7A20", "#6A6A80"),
	shadow = palette("#EFE6FF", "#8F7BFF", "#2E1A5C", "#231C30"),
	nature = palette("#F2FFD6", "#7CCB4A", "#2F5A1A", "#3E5A2E"),
	none = palette("#FFFFFF", "#D8D2F0", "#5A5470", "#6A625C"),
}

-- An anchor: a point (and a forward direction) in a bone's rest frame, followed through its TransformedWorldCFrame, or
-- in a part's frame; `bone2` makes it the middle of two bones (the wing tips); `dirPart` takes the direction from a
-- part instead (the look's root); `flyer` reads the flyer's solved muzzle (root space) each frame; `at2` is a second
-- point on the same bone (the weapon's hilt: a trail runs from it to `at`).
type Anchor = {
	bone: Bone?,
	bone2: Bone?,
	part: BasePart?,
	at: Vector3,
	at2: Vector3?,
	fwd: Vector3,
	dirPart: BasePart?,
	flyer: boolean?,
}

type Layer = { holder: BasePart, e: ParticleEmitter, rate: number, life: number }
type Stream = {
	kind: string,
	anchor: Anchor,
	layers: { Layer },
	light: PointLight?,
	glow: Layer?, -- the layer whose brightness follows the build-up
	lightBase: number,
	t0: number,
	t1: number,
	palette: Palette,
	size: number,
	nextArc: number,
	seed: number,
	trail: Trail?, -- a weapon streak between the hilt (a0) and the tip (a1) of a beam holder
	trailHolder: BasePart?,
	a0: Attachment?,
	a1: Attachment?,
	prop: BasePart?, -- the rock or orb held until the throw
	propTurn: CFrame,
}

type Owner = {
	model: Model,
	look: Model,
	rig: any,
	style: any,
	styleId: string,
	kindId: string?,
	assetModel: string?,
	root: BasePart, -- the look's root part (its rest frame at attach is `space`)
	space: CFrame,
	lo: Vector3, -- the visible mesh's box in `space` at rest
	hi: Vector3,
	height: number,
	size: number,
	anchors: { [string]: Anchor | false },
	runName: string?,
	runStart: number,
	list: { MotionFxData.Fx }?,
	action: any,
	hit: number,
	bound: ActionFx.Bound?,
	last: number?,
	fired: { [number]: boolean },
	streams: { [number]: Stream },
	hitAt: number?,
	steppedAt: number,
	culled: boolean,
}

local owners: { [Model]: Owner } = {}

---------------------------------------------------------------- budget

local function quality(): any
	return State.Get({ "account", "settings", "quality" })
end

-- The rate share of a stream layer: the graphics level's particle share, halved simple, lower on a phone.
local function share(simple: boolean): number
	local s = GraphicsLevel.get(quality()).particles * (if simple then 0.5 else 1)
	return if Pool.isTouch() then s * TOUCH_SHARE else s
end

local function cullDistance(): number
	return if Pool.isTouch() then CULL.touch else CULL.desktop
end

local function paletteOf(element: string?): Palette
	return PALETTES[element or "none"] or PALETTES.none
end

---------------------------------------------------------------- anchors

local function visibleBox(look: Model, space: CFrame): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	local any = false
	for _, item in look:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 0.99 then
			any = true
			local rel = space:ToObjectSpace(item.CFrame)
			local half = item.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = rel * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	if not any then
		return Vector3.new(-1, 0, -1), Vector3.new(1, 2, 1)
	end
	return lo, hi
end

-- An anchor on `bone` at the world point `point` of its rest pose, facing the model's front.
local function onBone(o: Owner, bone: Bone, point: Vector3): Anchor
	local rest = bone.WorldCFrame
	return {
		bone = bone,
		at = rest:PointToObjectSpace(point),
		fwd = rest:VectorToObjectSpace(o.space.LookVector),
	}
end

-- An anchor between two bones (their joints), facing along the look's root.
local function between(o: Owner, a: Bone, b: Bone): Anchor
	return { bone = a, bone2 = b, at = Vector3.zero, fwd = Vector3.new(0, 0, -1), dirPart = o.root }
end

-- An anchor at a point of the look's rest space on part `part` (the rigid PrimaryPart or the root).
local function onPart(o: Owner, part: BasePart, local_: Vector3): Anchor
	local world = o.space:PointToWorldSpace(local_)
	return {
		part = part,
		at = part.CFrame:PointToObjectSpace(world),
		fwd = part.CFrame:VectorToObjectSpace(o.space.LookVector),
	}
end

-- The mouth in front of a head bone at rest (look space): a little ahead of and below the head's joint, not past the
-- front of the mesh for a long-snouted kind.
local function mouthPoint(o: Owner, head: Bone, ahead: number, clampFront: boolean): Vector3
	local p = o.space:PointToObjectSpace(head.WorldCFrame.Position)
	local h = o.height
	local z = p.Z - ahead * h
	if clampFront then
		z = math.min(z, o.lo.Z + 0.04 * (o.hi.Z - o.lo.Z))
	end
	return o.space:PointToWorldSpace(Vector3.new(p.X, p.Y - 0.03 * h, z))
end

local function lastBone(o: Owner, names: { string }?): Bone?
	if not names or #names == 0 then
		return nil
	end
	return o.rig.bones[names[#names]]
end

local function legEnd(o: Owner, map: any, leg: string): Bone?
	local rows = map.legs and map.legs[leg]
	if not rows or #rows == 0 then
		return nil
	end
	return o.rig.bones[rows[#rows].bone]
end

-- How far a ray from `from` along `dir` (world, at rest) runs inside the look's box.
local function boxReach(o: Owner, from: Vector3, dir: Vector3): number
	local p = o.space:PointToObjectSpace(from)
	local d = o.space:VectorToObjectSpace(dir)
	local best = math.huge
	local function slab(pv: number, dv: number, lo: number, hi: number)
		if math.abs(dv) > 1e-4 then
			best = math.min(best, ((if dv > 0 then hi else lo) - pv) / dv)
		end
	end
	slab(p.X, d.X, o.lo.X, o.hi.X)
	slab(p.Y, d.Y, o.lo.Y, o.hi.Y)
	slab(p.Z, d.Z, o.lo.Z, o.hi.Z)
	return if best == math.huge then 0 else math.max(0, best)
end

-- The weapon in the right hand: along `grip` (the blade's rest direction in the look's root space, Data/MonsterAssets
-- or the style: Logic/BipedMotion keeps it) its tip where the blade leaves the look's box (a staff's head, a sword's
-- point; held within 0.12..0.7 of the height), the streak's inner end 0.55 of the way out; no weapon (a brute, a ghost): the
-- knuckles a little past the hand along the forearm.
local function weaponAnchor(o: Owner, hand: Bone, fore: Bone?): Anchor
	local rest = hand.WorldCFrame
	local motion = o.rig.motion
	local grip: { number }? = if motion then motion.grip else nil
	local h = o.height
	local front = o.space.LookVector
	local dir: Vector3
	local reach: number
	if grip then
		dir = LmKit.unitOr(o.space:VectorToWorldSpace(Vector3.new(grip[1], grip[2], grip[3])), front)
		-- studio review 2026-10-26: up to 0.7 of the height (a knight's long sword, a staff over the head); 0.32 cut
		-- the streak to the first third of the blade
		reach = math.clamp(boxReach(o, rest.Position, dir) * 0.95, 0.12 * h, 0.7 * h)
	else
		dir = if fore then LmKit.unitOr(rest.Position - fore.WorldCFrame.Position, front) else front
		reach = 0.07 * h
	end
	return {
		bone = hand,
		at = rest:PointToObjectSpace(rest.Position + dir * reach),
		-- the streak's inner end well out along the blade, so it never sweeps through the body
		at2 = rest:PointToObjectSpace(rest.Position + dir * (if grip then reach * 0.55 else 0)),
		fwd = rest:VectorToObjectSpace(front),
	}
end

local function bipedAnchor(o: Owner, name: string): Anchor?
	local rig = o.rig
	local b: { [string]: Bone } = rig.bones
	local spec = if o.assetModel then BipedRigs.get(o.assetModel) else nil
	local muzzleKey = spec and spec.muzzle and spec.muzzle.key
	local chest = b.Spine2 or b.Spine1 or b.Spine or b.Hips
	if name == "mouth" or name == "head" then
		if name == "mouth" and rig.muzzleBone and rig.muzzleAt and muzzleKey == "Head" then
			return onBone(o, rig.muzzleBone, rig.muzzleBone.WorldCFrame:PointToWorldSpace(rig.muzzleAt))
		end
		local head = b.Head
		if head then
			if name == "head" then
				return onBone(o, head, head.WorldCFrame.Position)
			end
			local dragon = o.kindId ~= nil and MonsterRelease.planOf(o.kindId) == "dragon"
			return onBone(o, head, mouthPoint(o, head, if dragon then 0.12 else 0.05, false))
		end
		if chest then
			return onBone(o, chest, chest.WorldCFrame.Position + o.space.UpVector * (0.15 * o.height))
		end
	elseif name == "handR" or name == "handL" or name == "wingR" or name == "wingL" then
		local right = name == "handR" or name == "wingR"
		if right and rig.muzzleBone and rig.muzzleAt and muzzleKey == "RightHand" then
			return onBone(o, rig.muzzleBone, rig.muzzleBone.WorldCFrame:PointToWorldSpace(rig.muzzleAt))
		end
		local hand = if right then b.RightHand else b.LeftHand
		if hand then
			return onBone(o, hand, hand.WorldCFrame.Position)
		end
	elseif name == "wings" then
		if b.LeftHand and b.RightHand then
			return between(o, b.LeftHand, b.RightHand)
		end
	elseif name == "weapon" then
		if b.RightHand then
			return weaponAnchor(o, b.RightHand, b.RightForeArm)
		end
	elseif name == "chest" or name == "top" then
		if chest then
			return onBone(o, chest, chest.WorldCFrame.Position)
		end
	elseif name == "feet" or name == "front" then
		if b.LeftFoot and b.RightFoot then
			return between(o, b.LeftFoot, b.RightFoot)
		end
	elseif name == "body" or name == "tail" then
		local hips = b.Hips or chest
		if hips then
			return onBone(o, hips, hips.WorldCFrame.Position)
		end
	end
	return nil
end

local function quadAnchor(o: Owner, name: string): Anchor?
	local map = if o.assetModel then QuadRigs.get(o.assetModel) else nil
	if not map then
		return nil
	end
	local b: { [string]: Bone } = o.rig.bones
	local head = b[map.head]
	local spine = map.spine
	local mid = if spine and #spine > 0 then b[spine[math.ceil(#spine / 2)].bone] else nil
	if name == "mouth" and head then
		return onBone(o, head, mouthPoint(o, head, 0.08, true))
	elseif name == "head" and head then
		return onBone(o, head, head.WorldCFrame.Position)
	elseif name == "chest" then
		local chest = if spine and #spine > 0 then b[spine[#spine].bone] else nil
		if chest then
			return onBone(o, chest, chest.WorldCFrame.Position)
		end
	elseif name == "front" or name == "handL" or name == "handR" then
		local fl, fr = legEnd(o, map, "FL"), legEnd(o, map, "FR")
		if name == "handL" and fl then
			return onBone(o, fl, fl.WorldCFrame.Position)
		elseif name == "handR" and fr then
			return onBone(o, fr, fr.WorldCFrame.Position)
		elseif fl and fr then
			return between(o, fl, fr)
		end
	elseif name == "feet" then
		local body = b[map.body]
		if body then
			return onBone(o, body, body.WorldCFrame.Position)
		end
	elseif name == "trunk" then
		local tip = lastBone(o, map.trunk)
		if tip then
			return onBone(o, tip, tip.WorldCFrame.Position)
		end
	elseif name == "tail" then
		local tip = lastBone(o, map.tail)
		if tip then
			return onBone(o, tip, tip.WorldCFrame.Position)
		end
	elseif (name == "body" or name == "top") and mid then
		local up = if name == "top" then o.space.UpVector * (0.3 * o.height) else Vector3.zero
		return onBone(o, mid, mid.WorldCFrame.Position + up)
	end
	return nil
end

local function flyerAnchor(o: Owner, name: string): Anchor?
	local map = if o.assetModel then FlyerRigs.get(o.assetModel) else nil
	if not map then
		return nil
	end
	local b: { [string]: Bone } = o.rig.bones
	local function tip(side: string): Bone?
		local wing = map.wings and map.wings[side]
		if not wing then
			return nil
		end
		return b[wing.tip or wing.hand]
	end
	if name == "mouth" then
		return { flyer = true, at = Vector3.zero, fwd = Vector3.new(0, 0, -1), dirPart = o.root }
	elseif name == "head" then
		local head = b[map.head]
		if head then
			return onBone(o, head, head.WorldCFrame.Position)
		end
	elseif name == "wingL" or name == "wingR" then
		local bone = tip(if name == "wingL" then "L" else "R")
		if bone then
			return onBone(o, bone, bone.WorldCFrame.Position)
		end
	elseif name == "wings" then
		local l, r = tip("L"), tip("R")
		if l and r then
			return between(o, l, r)
		end
	end
	local centre = map.centre and b[map.centre[1]]
	if centre then
		return onBone(o, centre, centre.WorldCFrame.Position)
	end
	return nil
end

local function rigidAnchor(o: Owner, name: string): Anchor?
	local rig = o.rig
	local primary: BasePart = rig.primary
	local body = rig.motion and rig.motion.body
	if not body then
		return nil
	end
	local h, B, W, x0, z0 = body.h, body.B, body.W, body.x0, body.z0
	local lift = body.lift or 0
	local release = MonsterRelease.of(o.kindId or "")
	local front = z0 - 0.47 * B
	-- a rigid kind with bones (frostWyrm): the head chain's last bone carries the mouth
	local map = if o.assetModel then RigidRigs.get(o.assetModel) else nil
	local head = lastBone(o, map and map.head)
	if (name == "mouth" or name == "head") and head then
		-- the frame of the primary part is the rest frame here (the look's space may be its root)
		return onBone(o, head, mouthPoint(o, head, if name == "mouth" then 0.08 else 0, true))
	end
	local function at(x: number, y: number, z: number): Anchor
		local world = primary.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
		return {
			part = primary,
			at = primary.CFrame:PointToObjectSpace(world),
			fwd = Vector3.new(0, 0, -1),
		}
	end
	if name == "mouth" or name == "trunk" then
		return at(x0, release.up * h, front)
	elseif name == "head" then
		return at(x0, release.up * h, z0 - 0.4 * B)
	elseif name == "top" then
		return at(x0, h, z0)
	elseif name == "tail" then
		return at(x0, h, z0 - 0.15 * B)
	elseif name == "feet" then
		return at(x0, lift, z0)
	elseif name == "front" then
		return at(x0, lift, z0 - 0.35 * B)
	elseif name == "handR" or name == "handL" then
		return at(x0 + (if name == "handR" then 0.3 else -0.3) * W, 0.6 * h, z0 - 0.35 * B)
	elseif name == "wingR" or name == "wingL" then
		return at(x0 + (if name == "wingR" then 0.45 else -0.45) * W, 0.6 * h, z0)
	end
	return at(x0, lift + (h - lift) * 0.5, z0)
end

local function resolve(o: Owner, name: string): Anchor
	local cached = o.anchors[name]
	if cached ~= nil and cached ~= false then
		return cached :: Anchor
	end
	local kind = o.rig.kind
	local found: Anchor? = nil
	if cached == nil then
		local ok, result = pcall(function(): Anchor?
			if kind == "quad" then
				return quadAnchor(o, name)
			elseif kind == "flyer" then
				return flyerAnchor(o, name)
			elseif kind == "rigid" then
				return rigidAnchor(o, name)
			end
			return bipedAnchor(o, name)
		end)
		found = if ok then result else nil
		o.anchors[name] = found or false
	end
	if found then
		return found
	end
	if name ~= "body" then
		return resolve(o, "body")
	end
	-- the last resort: the middle of the look's box on its root
	local mid = Vector3.new((o.lo.X + o.hi.X) / 2, (o.lo.Y + o.hi.Y) / 2, (o.lo.Z + o.hi.Z) / 2)
	local fallback = onPart(o, o.root, mid)
	o.anchors.body = fallback
	return fallback
end

-- Where an anchor is now and which way it faces.
local function place(o: Owner, a: Anchor): (Vector3, Vector3)
	local pos: Vector3
	local dir: Vector3
	if a.flyer then
		-- (Logic/FlyerMotion's muzzle is in the space of the rig's root)
		local rigRoot: BasePart = o.rig.root or o.root
		local root = rigRoot.CFrame
		local muzzle = FlyerMotion.muzzle(o.rig.motion)
		pos = if muzzle
			then root:PointToWorldSpace(Vector3.new(muzzle[1], muzzle[2], muzzle[3]))
			else root:PointToWorldSpace(Vector3.new(0, o.height * 0.6, -o.height * 0.3))
		return pos, root.LookVector
	end
	local bone = a.bone
	local cf = if bone then bone.TransformedWorldCFrame elseif a.part then a.part.CFrame else o.root.CFrame
	pos = cf:PointToWorldSpace(a.at)
	local bone2 = a.bone2
	if bone2 then
		pos = (pos + bone2.TransformedWorldCFrame.Position) * 0.5
	end
	local dirPart = a.dirPart
	dir = if dirPart then dirPart.CFrame:VectorToWorldSpace(a.fwd) else cf:VectorToWorldSpace(a.fwd)
	return pos, LmKit.unitOr(dir, o.root.CFrame.LookVector)
end

-- The two ends of a paired anchor (the wing tips; the weapon's hilt and tip), else a short span across the anchor.
local function ends(o: Owner, a: Anchor): (Vector3, Vector3)
	local bone, bone2 = a.bone, a.bone2
	if bone and bone2 then
		return bone.TransformedWorldCFrame.Position, bone2.TransformedWorldCFrame.Position
	end
	local at2 = a.at2
	if bone and at2 then
		local cf = bone.TransformedWorldCFrame
		return cf:PointToWorldSpace(at2), cf:PointToWorldSpace(a.at)
	end
	local pos = place(o, a)
	local side = o.root.CFrame.RightVector * (0.4 * o.height)
	return pos - side, pos + side
end

---------------------------------------------------------------- stream layers

type LayerSpec = {
	key: string,
	rate: number,
	life: { number },
	speed: { number },
	spread: number,
	drag: number?,
	accel: Vector3?,
	size: NumberSequence,
	alpha: NumberSequence,
	color: ColorSequence,
	emission: number?,
	spin: number?, -- random rotation and this spin, deg/s
	parallel: boolean?,
	locked: boolean?,
	brightness: number?,
}

local function colors(a: Color3, b: Color3, c: Color3?): ColorSequence
	if c then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, a),
			ColorSequenceKeypoint.new(0.35, b),
			ColorSequenceKeypoint.new(1, c),
		})
	end
	return ColorSequence.new(a, b)
end

local function addLayer(stream: Stream, spec: LayerSpec, frame: CFrame, rateShare: number): Layer?
	local holder = Pool.holder("emitter", spec.key)
	if not holder then
		return nil
	end
	local e = Pool.child(holder)
	if not e or not e:IsA("ParticleEmitter") then
		Pool.releaseHolder(holder)
		return nil
	end
	holder.Size = Vector3.one * 0.2
	holder.CFrame = frame
	e.Rate = 0
	e.Color = spec.color
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	e.Acceleration = spec.accel or Vector3.zero
	e.Drag = spec.drag or 0
	e.Size = spec.size
	e.Transparency = spec.alpha
	e.EmissionDirection = Enum.NormalId.Front
	e.Orientation = if spec.parallel
		then Enum.ParticleOrientation.VelocityParallel
		else Enum.ParticleOrientation.FacingCamera
	e.Squash = NumberSequence.new(0)
	local spin = spec.spin
	e.Rotation = if spin then NumberRange.new(0, 360) else NumberRange.new(0)
	e.RotSpeed = if spin then NumberRange.new(-spin, spin) else NumberRange.new(0)
	e.ZOffset = 0
	e.Brightness = spec.brightness or 1
	e.LockedToPart = spec.locked == true
	e.TimeScale = if Clock.frozen() then 0 else 1
	if not Textures.particle(e, spec.key, spec.emission) then
		Textures.plainParticle(e)
		e.LightEmission = spec.emission or 0.8
	end
	local rate = spec.rate * rateShare
	-- the rate already carries the graphics level (share): SettingsController must not scale it again (studio review
	-- 2026-10-26: on low quality the breath ran at a ninth of its rate and showed no flame)
	e:SetAttribute("OwnRate", true)
	e:SetAttribute("VaelthornOriginalRate", nil)
	e.Rate = rate
	local layer: Layer = { holder = holder, e = e, rate = rate, life = spec.life[2] }
	table.insert(stream.layers, layer)
	return layer
end

local function addLight(stream: Stream, holder: BasePart, color: Color3, range: number, brightness: number)
	if kit.lowQuality() or not Pool.takeLight() then
		return
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = holder
	stream.light = l
	stream.lightBase = brightness
end

-- How fast a particle must leave to travel `length` studs in `life` seconds under `drag`.
local function launch(length: number, life: number, drag: number): number
	return length * drag / math.max(0.2, 1 - math.exp(-drag * life))
end

local function breathLayers(stream: Stream, frame: CFrame, element: string?, length: number, s: number, simple: boolean)
	local p = stream.palette
	-- the breath is the fight's signature: never thinner than BREATH_SHARE of its rates, whatever the graphics level
	local r = math.max(share(simple), BREATH_SHARE)
	local touch = Pool.isTouch()
	local v = launch(length, 0.6, 2.5)
	local first: Layer? = nil
	if element == "fire" then
		first = addLayer(stream, {
			key = "fire",
			rate = 130,
			life = { 0.45, 0.65 },
			speed = { v * 0.85, v * 1.1 },
			spread = 10,
			drag = 2.5,
			accel = Vector3.new(0, 5, 0),
			size = NumberSequence.new({ kp(0, 0.35 * s), kp(0.3, 0.2 * length), kp(1, 0.36 * length) }),
			alpha = NumberSequence.new({ kp(0, 0.3), kp(0.12, 0.02), kp(0.8, 0.3), kp(1, 1) }),
			-- studio review 2026-10-26: orange from the mouth on (a white-hot core over the whole stream washed it out on
			-- a bright day)
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, p.core),
				ColorSequenceKeypoint.new(0.12, p.main),
				ColorSequenceKeypoint.new(0.7, p.main:Lerp(p.deep, 0.5)),
				ColorSequenceKeypoint.new(1, p.deep),
			}),
			-- a low light emission keeps the flame's own orange on a bright day (additive light washed it white)
			emission = 0.35,
			spin = 120,
			brightness = 1.6,
		}, frame, r)
		addLayer(stream, {
			key = "spark",
			rate = 22,
			life = { 0.5, 0.9 },
			speed = { v * 0.6, v * 1.0 },
			spread = 18,
			drag = 1.5,
			accel = Vector3.new(0, -14, 0),
			size = NumberSequence.new({ kp(0, 0.22), kp(1, 0.05) }),
			alpha = NumberSequence.new({ kp(0, 0), kp(0.8, 0.2), kp(1, 1) }),
			color = colors(p.core, p.main),
			emission = 1,
			parallel = true,
		}, frame, r)
	else
		local mist = element == "ice"
		-- studio review 2026-10-26: denser and in its own colour (a pale additive mist vanished against a bright sky)
		first = addLayer(stream, {
			key = "smoke",
			rate = 130,
			life = { 0.5, 0.7 },
			speed = { v * 0.85, v * 1.1 },
			spread = 11,
			drag = 2.5,
			accel = Vector3.new(0, if mist then -1 else 1, 0),
			size = NumberSequence.new({ kp(0, 0.4 * s), kp(0.3, 0.19 * length), kp(1, 0.34 * length) }),
			alpha = NumberSequence.new({ kp(0, 0.3), kp(0.15, 0.05), kp(0.82, 0.3), kp(1, 1) }),
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, p.core),
				ColorSequenceKeypoint.new(0.15, p.main),
				ColorSequenceKeypoint.new(1, p.main:Lerp(p.deep, 0.6)),
			}),
			emission = 0.15,
			spin = 90,
			brightness = 1.4,
		}, frame, r)
		addLayer(stream, {
			key = if mist then "iceShard" else "poisonBubble",
			rate = 18,
			life = { 0.4, 0.7 },
			speed = { v * 0.5, v * 0.9 },
			spread = 16,
			drag = 2,
			accel = Vector3.new(0, -18, 0),
			size = NumberSequence.new({ kp(0, 0.3 * s), kp(1, 0.15 * s) }),
			alpha = NumberSequence.new({ kp(0, 0), kp(0.75, 0.2), kp(1, 1) }),
			color = colors(p.core, p.main),
			emission = 0.6,
			spin = 300,
		}, frame, r)
	end
	-- the white-hot core at the mouth
	addLayer(stream, {
		key = "glow",
		rate = 30,
		life = { 0.12, 0.18 },
		speed = { length * 1.2, length * 1.6 },
		spread = 6,
		drag = 4,
		size = NumberSequence.new({ kp(0, 0.9 * s), kp(1, 1.6 * s) }),
		alpha = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
		color = colors(p.core, p.main),
		emission = 1,
		brightness = 1.5,
	}, frame, r)
	if not simple and not touch then
		-- smoke (fire) or a cold mist (frost) rolling off the stream's end
		addLayer(stream, {
			key = "smoke",
			rate = 10,
			life = { 1.0, 1.5 },
			speed = { v * 0.55, v * 0.75 },
			spread = 14,
			drag = 2.8,
			accel = Vector3.new(0, if element == "fire" then 4 else -0.5, 0),
			size = NumberSequence.new({ kp(0, 0.12 * length), kp(1, 0.4 * length) }),
			alpha = NumberSequence.new({ kp(0, 1), kp(0.25, if element == "fire" then 0.55 else 0.65), kp(1, 1) }),
			color = colors(p.smoke, p.smoke:Lerp(WHITE, 0.3)),
			emission = if element == "fire" then 0 else 0.2,
			spin = 40,
		}, frame, r)
		if element == "fire" then
			-- a faint warm haze around the stream (no refraction in Roblox: a wide, nearly clear glow)
			addLayer(stream, {
				key = "glow",
				rate = 6,
				life = { 0.6, 0.8 },
				speed = { v * 0.45, v * 0.55 },
				spread = 12,
				drag = 2.5,
				size = NumberSequence.new({ kp(0, 0.2 * length), kp(1, 0.45 * length) }),
				alpha = NumberSequence.new({ kp(0, 0.93), kp(0.5, 0.88), kp(1, 1) }),
				color = colors(p.main, p.deep),
				emission = 0.3,
			}, frame, r)
		end
	end
	if first and not simple then
		addLight(stream, first.holder, p.main, math.clamp(10 + length * 0.6, 10, 26), 2.5)
	end
end

local function chargeLayers(stream: Stream, frame: CFrame, element: string?, s: number, simple: boolean)
	local p = stream.palette
	local r = share(simple)
	stream.glow = addLayer(stream, {
		key = "glow",
		rate = 14,
		life = { 0.15, 0.25 },
		speed = { 0, 0 },
		spread = 0,
		size = NumberSequence.new({ kp(0, 0.8 * s), kp(1, 1.4 * s) }),
		alpha = NumberSequence.new({ kp(0, 0.3), kp(1, 1) }),
		color = colors(p.core, p.main),
		emission = 1,
		locked = true,
		brightness = 0.3,
	}, frame, r)
	local key = if element == "ice"
		then "iceShard"
		elseif element == "poison" then "poisonBubble"
		elseif element == "nature" then "leaf"
		elseif element == "fire" or element == "lightning" then "spark"
		else "glow"
	local crackle = element == "lightning"
	addLayer(stream, {
		key = key,
		rate = if crackle then 18 else 9,
		life = if crackle then { 0.08, 0.18 } else { 0.4, 0.7 },
		speed = if crackle then { 4, 8 } else { 1, 3 },
		spread = if crackle then 180 else 60,
		drag = 1,
		accel = Vector3.new(0, if element == "fire" then 3 else 0.5, 0),
		size = NumberSequence.new({ kp(0, 0.18 * s), kp(1, 0.05 * s) }),
		alpha = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }),
		color = colors(p.core, p.main),
		emission = if key == "leaf" then 0.2 else 1,
		parallel = crackle,
		spin = if key == "iceShard" or key == "leaf" then 200 else nil,
	}, frame, r)
	local glow = stream.glow
	if glow and not simple then
		addLight(stream, glow.holder, p.main, 4 + 6 * s, 0)
		stream.lightBase = 2.2
	end
end

local function smolderLayers(stream: Stream, frame: CFrame, element: string?, s: number, simple: boolean)
	local p = stream.palette
	local r = share(simple)
	local fire = element == "fire"
	addLayer(stream, {
		key = "smoke",
		rate = 7,
		life = { 0.9, 1.4 },
		speed = { 1, 2.5 },
		spread = 25,
		drag = 1,
		accel = Vector3.new(0, if fire then 3 else 0.3, 0),
		size = NumberSequence.new({ kp(0, 0.4 * s), kp(1, 1.6 * s) }),
		alpha = NumberSequence.new({ kp(0, 1), kp(0.3, if fire then 0.6 else 0.7), kp(1, 1) }),
		color = colors(if fire then p.smoke else p.core, if fire then p.smoke:Lerp(WHITE, 0.3) else p.main),
		emission = if fire then 0 else 0.3,
		spin = 40,
	}, frame, r)
	if fire then
		addLayer(stream, {
			key = "spark",
			rate = 4,
			life = { 0.4, 0.8 },
			speed = { 1.5, 4 },
			spread = 30,
			drag = 1,
			accel = Vector3.new(0, 4, 0),
			size = NumberSequence.new({ kp(0, 0.15), kp(1, 0.03) }),
			alpha = NumberSequence.new({ kp(0, 0), kp(1, 1) }),
			color = colors(p.core, p.main),
			emission = 1,
		}, frame, r)
	end
end

local function arcLayers(stream: Stream, frame: CFrame, s: number, simple: boolean)
	local p = stream.palette
	stream.glow = addLayer(stream, {
		key = "spark",
		rate = 20,
		life = { 0.08, 0.18 },
		speed = { 3, 8 },
		spread = 180,
		drag = 2,
		size = NumberSequence.new({ kp(0, 0.2 * s), kp(1, 0.04) }),
		alpha = NumberSequence.new({ kp(0, 0), kp(1, 1) }),
		color = colors(p.core, p.main),
		emission = 1,
		parallel = true,
	}, frame, share(simple))
	local glow = stream.glow
	if glow and not simple then
		addLight(stream, glow.holder, p.main, 6 + 6 * s, 0)
		stream.lightBase = 2.5
	end
end

-- A streak behind the weapon: a Trail between two attachments of a pooled beam holder, moved onto the hilt and the
-- tip every frame (the beam itself stays hidden); the element's colours, else steel.
local function trailStart(o: Owner, stream: Stream, element: string?, size: number)
	local holder = Pool.holder("beam", "trailStreak")
	if not holder then
		return
	end
	local a0 = holder:FindFirstChild("A0")
	local a1 = holder:FindFirstChild("A1")
	if not a0 or not a1 or not a0:IsA("Attachment") or not a1:IsA("Attachment") then
		Pool.releaseHolder(holder)
		return
	end
	local hilt, tip = ends(o, stream.anchor)
	holder.CFrame = CFrame.new(tip)
	a0.WorldPosition = hilt
	a1.WorldPosition = tip
	local p = stream.palette
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.FaceCamera = false
	t.MinLength = 0.05
	t.Lifetime = TRAIL_LIFE * math.clamp(size, 0.7, 1.4)
	-- studio review 2026-10-26: a bright, glowing streak that fades fast (a dimly lit one read as a dark smear)
	t.LightEmission = 1
	t.Brightness = 2
	t.Color = if element then colors(p.core, p.main) else colors(WHITE, STEEL)
	t.Transparency = NumberSequence.new({ kp(0, if element then 0.15 else 0.25), kp(0.5, 0.7), kp(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.2)
	if not Textures.trail(t, "trailStreak") then
		t.Texture = ""
	end
	t.LightInfluence = 0
	t.Enabled = false
	t.Parent = holder
	Clock.track(t)
	t:Clear()
	t.Enabled = true
	stream.trail, stream.trailHolder, stream.a0, stream.a1 = t, holder, a0, a1
end

-- The rock (an orb of the element, violet without one, for a magic kind) in the throwing hand.
local function heldStart(o: Owner, stream: Stream, frame: CFrame, element: string?, s: number, simple: boolean)
	local bound = o.bound
	local magic = bound ~= nil and bound.magic == true
	local size = 0.5 * s
	local prop: BasePart
	if magic then
		local p = if element then stream.palette else PALETTES.shadow
		prop = LmKit.part("Ball", p.main, Vector3.one * size, Enum.Material.Neon, 0.15)
		addLayer(stream, {
			key = "glow",
			rate = 10,
			life = { 0.2, 0.35 },
			speed = { 0, 0.5 },
			spread = 180,
			size = NumberSequence.new({ kp(0, size * 1.6), kp(1, size * 2.4) }),
			alpha = NumberSequence.new({ kp(0, 0.4), kp(1, 1) }),
			color = colors(p.core, p.main),
			emission = 1,
		}, frame, share(simple))
	else
		prop = LmKit.part("Block", ROCK, Vector3.new(1.1, 0.9, 1) * size, Enum.Material.Slate, 0)
		stream.propTurn = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0)
	end
	prop.CFrame = CFrame.new(frame.Position) * stream.propTurn
	stream.prop = prop
end

local function stopStream(o: Owner, index: number)
	local stream = o.streams[index]
	if not stream then
		return
	end
	o.streams[index] = nil
	for _, layer in stream.layers do
		layer.e.Rate = 0
		-- back to the shared pool: other users of the emitter are scaled by SettingsController again
		layer.e:SetAttribute("OwnRate", nil)
		Pool.holderLater(layer.holder, layer.life + 0.1)
	end
	local l = stream.light
	if l then
		l:Destroy()
		Pool.dropLight()
		stream.light = nil
	end
	local trail, holder = stream.trail, stream.trailHolder
	if trail and holder then
		trail.Enabled = false
		Pool.holderLater(holder, trail.Lifetime + 0.1)
		stream.trail = nil
	end
	local prop = stream.prop
	if prop then
		Pool.release(prop)
		stream.prop = nil
	end
end

local function stopAll(o: Owner)
	for index in o.streams do
		stopStream(o, index)
	end
end

-- The size of a piece: the monster's (its drawn height over a man's) x the entry's own.
local function sizeOf(o: Owner, fx: MotionFxData.Fx): number
	return math.clamp(o.size, 0.5, 3) * (fx.size or 1)
end

local function elementOf(o: Owner, fx: MotionFxData.Fx): string?
	if fx.element then
		return fx.element
	end
	local bound = o.bound
	return bound and bound.element
end

-- A breath's direction: the head's, but never steeper down than BREATH_DIP (studio review 2026-10-26: the head bows
-- into the sweep and the stream went into the ground, where it is hidden, so the flame looked a few studs long).
local function streamDir(kind: string, dir: Vector3): Vector3
	if kind ~= "breath" or dir.Y >= -BREATH_DIP then
		return dir
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return dir
	end
	return (flat.Unit * math.sqrt(1 - BREATH_DIP * BREATH_DIP) - Vector3.new(0, BREATH_DIP, 0)).Unit
end

local function startStream(o: Owner, fx: MotionFxData.Fx, t0: number, t1: number, simple: boolean): Stream?
	local anchor = resolve(o, fx.at)
	local pos, dir = place(o, anchor)
	local frame = kit.facingFrame(pos, streamDir(fx.kind, dir))
	local element = elementOf(o, fx)
	if fx.kind == "breath" and not element then
		element = "fire"
	end
	local s = sizeOf(o, fx)
	local stream: Stream = {
		kind = fx.kind,
		anchor = anchor,
		layers = {},
		light = nil,
		glow = nil,
		lightBase = 0,
		t0 = t0,
		t1 = t1,
		palette = paletteOf(element),
		size = s,
		nextArc = t0,
		seed = rng:NextNumber(0, 100),
		trail = nil,
		trailHolder = nil,
		a0 = nil,
		a1 = nil,
		prop = nil,
		propTurn = CFrame.identity,
	}
	if fx.kind == "breath" then
		local bound = o.bound
		local radius = (bound and bound.radius) or 12
		-- at least as long as the body is big (a giant's breath reaches far past its own head)
		local length = math.min(36, math.max(math.clamp(radius * 0.8, 6, 24), 6 * s))
			* math.clamp(fx.size or 1, 0.5, 1.5)
		breathLayers(stream, frame, element, length, s, simple)
	elseif fx.kind == "charge" then
		chargeLayers(stream, frame, element, s, simple)
	elseif fx.kind == "smolder" then
		smolderLayers(stream, frame, element, s, simple)
	elseif fx.kind == "arc" then
		arcLayers(stream, frame, s, simple)
	elseif fx.kind == "trail" then
		trailStart(o, stream, element, fx.size or 1)
	elseif fx.kind == "held" then
		heldStart(o, stream, frame, element, s, simple)
	end
	if #stream.layers == 0 and fx.kind ~= "arc" and not stream.trail and not stream.prop then
		return nil
	end
	return stream
end

-- One frame of a running stream: its layers follow the anchor, the build-up and the flicker.
local function updateStream(o: Owner, stream: Stream, t: number, simple: boolean)
	local a0, a1 = stream.a0, stream.a1
	if a0 and a1 then
		local hilt, tip = ends(o, stream.anchor)
		a0.WorldPosition = hilt
		a1.WorldPosition = tip
		return
	end
	local pos, dir = place(o, stream.anchor)
	local prop = stream.prop
	if prop then
		prop.CFrame = CFrame.new(pos) * stream.propTurn
	end
	local frame = kit.facingFrame(pos, streamDir(stream.kind, dir))
	for _, layer in stream.layers do
		layer.holder.CFrame = frame
	end
	local span = stream.t1 - stream.t0
	local u = if span > 0 then math.clamp((t - stream.t0) / span, 0, 1) else 1
	local kind = stream.kind
	local l = stream.light
	if kind == "charge" or kind == "arc" then
		local glow = stream.glow
		if glow then
			glow.e.Brightness = 0.3 + 1.5 * u
			glow.e.Rate = glow.rate * (0.4 + 0.6 * u)
		end
		if l then
			l.Brightness = stream.lightBase * u * (0.85 + 0.3 * math.noise(t * 9, stream.seed))
		end
		if kind == "arc" and t >= stream.nextArc and not Clock.frozen() then
			local a, b = ends(o, stream.anchor)
			LmKit.forkBolt(a, b, stream.palette.core:Lerp(stream.palette.main, 0.4), 0.1 * stream.size, true, 1)
			stream.nextArc = t + rng:NextNumber(0.08, 0.16) * (1.3 - 0.6 * u) * (if simple then 2 else 1)
		end
	elseif kind == "breath" then
		if l then
			l.Brightness = stream.lightBase * (0.8 + 0.5 * math.noise(t * 12, stream.seed))
		end
	elseif kind == "smolder" then
		for _, layer in stream.layers do
			layer.e.Rate = layer.rate * (1 - 0.7 * u)
		end
	end
end

---------------------------------------------------------------- one-shots

-- A burst from a textured holder at `frame` (Library.kit.burstFrom: the device cap, the low-quality halving).
local function burst(key: string, frame: CFrame, color: Color3, count: number, o: { [string]: any })
	local holder = kit.textured(key, frame)
	if holder then
		kit.burstFrom(holder, key, color, count, o)
	end
end

local function spit(pos: Vector3, dir: Vector3, element: string?, s: number, simple: boolean)
	local p = paletteOf(element)
	local frame = kit.facingFrame(pos, dir)
	Library.impactFlash(pos, 1.2 * s, p.main, { simple = simple })
	if element == "fire" then
		burst("fire", frame, p.core:Lerp(p.main, 0.4), 10, {
			simple = simple,
			to = p.deep,
			direction = Enum.NormalId.Front,
			spread = 18,
			speedMin = 14,
			speedMax = 26,
			drag = 5,
			accel = Vector3.new(0, 4, 0),
			lifeMin = 0.25,
			lifeMax = 0.45,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-120, 120),
			sizeSeq = NumberSequence.new({ kp(0, 0.5 * s), kp(0.35, 1.6 * s), kp(1, 2.2 * s) }),
			transparency = NumberSequence.new({ kp(0, 0.1), kp(0.6, 0.35), kp(1, 1) }),
			emission = 1,
		})
		burst("spark", frame, p.core, 10, {
			simple = simple,
			to = p.main,
			direction = Enum.NormalId.Front,
			spread = 25,
			speedMin = 16,
			speedMax = 30,
			drag = 1.5,
			accel = Vector3.new(0, -30, 0),
			lifeMin = 0.3,
			lifeMax = 0.6,
			orient = "parallel",
			sizeSeq = NumberSequence.new({ kp(0, 0.2), kp(1, 0.05) }),
		})
		if not simple then
			Library.smokePuff(pos, 0.6 * s, p.smoke, { count = 3 })
		end
		return
	end
	-- venom, frost and the rest: a spray of droplets or chips along the aim, a small puff
	local drops = if element == "ice" then "iceShard" elseif element == "poison" then "poisonBubble" else "glow"
	burst(drops, frame, p.core:Lerp(p.main, 0.5), 12, {
		simple = simple,
		to = p.deep,
		direction = Enum.NormalId.Front,
		spread = 20,
		speedMin = 12,
		speedMax = 24,
		drag = 1.2,
		accel = Vector3.new(0, -32, 0),
		lifeMin = 0.35,
		lifeMax = 0.65,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-200, 200),
		sizeSeq = NumberSequence.new({ kp(0, 0.35 * s), kp(1, 0.2 * s) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0.2), kp(1, 1) }),
		emission = 0.5,
	})
	burst("smoke", frame, p.main:Lerp(WHITE, 0.3), 3, {
		simple = simple,
		to = p.deep,
		direction = Enum.NormalId.Front,
		spread = 25,
		speedMin = 3,
		speedMax = 7,
		drag = 3,
		lifeMin = 0.5,
		lifeMax = 0.8,
		rotation = NumberRange.new(0, 360),
		sizeSeq = NumberSequence.new({ kp(0, 0.5 * s), kp(1, 1.6 * s) }),
		transparency = NumberSequence.new({ kp(0, 0.5), kp(1, 1) }),
		emission = 0.3,
	})
end

local function bolt(pos: Vector3, dir: Vector3, element: string?, s: number, simple: boolean)
	local p = paletteOf(element)
	Library.impactFlash(pos, 1.4 * s, p.main, { simple = simple })
	Library.sparks(pos, p.core:Lerp(p.main, 0.4), {
		simple = simple,
		key = if element == "ice"
			then "iceShard"
			elseif element == "poison" then "poisonBubble"
			elseif element == "nature" then "leaf"
			elseif element == "shadow" then "darkSpark"
			else "spark",
		dir = dir,
		count = 8,
		speed = { 6, 14 },
		gravity = 8,
	})
	if element == "shadow" and not simple then
		Library.smokePuff(pos, 0.5 * s, p.deep, { count = 2 })
	end
end

local function flare(o: Owner, anchor: Anchor, element: string?, s: number, simple: boolean)
	local p = paletteOf(element)
	local a, b = ends(o, anchor)
	local mid = (a + b) * 0.5
	LmKit.forkBolt(a, b, p.core:Lerp(p.main, 0.3), 0.16 * s, simple, 2)
	Library.impactFlash(mid, 2.2 * s, p.main, { simple = simple })
	Library.arcBurst(mid, 0.8 * s, p.main, { simple = simple })
end

-- Rings of force running out of `pos` along `dir`, growing and fading, one after another.
local function screech(pos: Vector3, dir: Vector3, element: string?, s: number, simple: boolean)
	local p = paletteOf(element)
	local color = p.main:Lerp(WHITE, 0.35)
	local count = if simple then 2 else 3
	for i = 1, count do
		Clock.after((i - 1) * 0.08, function()
			local disc = LmKit.part("Cylinder", color, Vector3.new(0.12, 0.8 * s, 0.8 * s), LmKit.FIELD, 0)
			disc.CFrame = LmKit.facingDisc(pos + dir * (0.3 * s), dir)
			local travel = (2.5 + i) * s
			LmKit.fadeOut(disc, 0.45, {
				Size = Vector3.new(0.12, (4 + i) * s, (4 + i) * s),
				CFrame = LmKit.facingDisc(pos + dir * travel, dir),
			}, Enum.EasingStyle.Quad)
		end)
	end
	if element == "lightning" and not simple then
		Library.sparks(pos, p.core, { dir = dir, count = 8, speed = { 8, 18 }, gravity = 10 })
	end
end

local function wisps(pos: Vector3, element: string?, s: number, simple: boolean)
	local p = paletteOf(element)
	local tint = p.core:Lerp(p.main, 0.35)
	burst("smoke", CFrame.new(pos), tint, 5, {
		simple = simple,
		to = p.main,
		spread = 180,
		speedMin = 1.5 * s,
		speedMax = 4 * s,
		drag = 1.5,
		accel = Vector3.new(0, 2.5, 0),
		lifeMin = 0.9,
		lifeMax = 1.4,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-60, 60),
		sizeSeq = NumberSequence.new({ kp(0, 0.6 * s), kp(1, 2 * s) }),
		transparency = NumberSequence.new({ kp(0, 1), kp(0.25, 0.55), kp(1, 1) }),
		emission = 0.6,
	})
	burst("glow", CFrame.new(pos), WHITE, 8, {
		simple = simple,
		to = p.main,
		spread = 180,
		speedMin = 2 * s,
		speedMax = 5 * s,
		drag = 2,
		accel = Vector3.new(0, 3, 0),
		lifeMin = 0.6,
		lifeMax = 1.1,
		sizeSeq = NumberSequence.new({ kp(0, 0.35 * s), kp(1, 0) }),
		transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
		emission = 1,
	})
end

local function feathers(pos: Vector3, tint: Color3, s: number, simple: boolean)
	burst("feather", CFrame.new(pos), tint:Lerp(WHITE, 0.15), math.max(3, math.floor(8 * s)), {
		simple = simple,
		to = tint,
		spread = 180,
		speedMin = 3,
		speedMax = 8,
		drag = 2.5,
		accel = Vector3.new(0, -5, 0),
		lifeMin = 1.2,
		lifeMax = 2,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-220, 220),
		sizeSeq = NumberSequence.new({ kp(0, 0.5 * s, 0.15 * s), kp(1, 0.45 * s, 0.1 * s) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0), kp(1, 1) }),
		area = Vector3.one * (0.8 * s),
		emission = 0,
	})
end

local function splinters(pos: Vector3, s: number, simple: boolean)
	burst("debris", CFrame.new(pos), WOOD, math.max(3, math.floor(10 * s)), {
		simple = simple,
		to = BARK,
		spread = 70,
		speedMin = 7,
		speedMax = 16,
		drag = 0.8,
		accel = Vector3.new(0, -45, 0),
		lifeMin = 0.5,
		lifeMax = 0.9,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-400, 400),
		sizeSeq = NumberSequence.new({ kp(0, 0.4 * s, 0.15 * s), kp(1, 0.3 * s, 0.1 * s) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0), kp(1, 1) }),
		area = Vector3.one * (0.6 * s),
		emission = 0,
	})
end

local function leaves(pos: Vector3, s: number, simple: boolean)
	burst("leaf", CFrame.new(pos), LEAF, math.max(3, math.floor(10 * s)), {
		simple = simple,
		to = LEAF_DRY,
		spread = 180,
		speedMin = 2,
		speedMax = 6,
		drag = 2,
		accel = Vector3.new(0, -4, 0),
		lifeMin = 1.5,
		lifeMax = 2.4,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-260, 260),
		sizeSeq = NumberSequence.new({ kp(0, 0.45 * s, 0.12 * s), kp(1, 0.4 * s, 0.12 * s) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.85, 0), kp(1, 1) }),
		area = Vector3.new(2 * s, 0.6 * s, 2 * s),
		emission = 0,
	})
end

local function snow(pos: Vector3, s: number, simple: boolean)
	Library.smokePuff(pos, 0.8 * s, SNOW, { simple = simple, count = 3 })
	burst("iceShard", CFrame.new(pos), WHITE, math.max(3, math.floor(8 * s)), {
		simple = simple,
		to = ICE_PART,
		spread = 70,
		speedMin = 6,
		speedMax = 13,
		drag = 1,
		accel = Vector3.new(0, -35, 0),
		lifeMin = 0.4,
		lifeMax = 0.7,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-300, 300),
		sizeSeq = NumberSequence.new({ kp(0, 0.3 * s), kp(1, 0.15 * s) }),
		emission = 0.4,
	})
end

-- Chunks of earth kicked up by a ground impact: brown blocks on ballistic arcs that bounce and fade.
local function clods(base: Vector3, count: number, s: number, reach: number)
	local floor = base.Y
	local bodies: { LmKit.Body } = {}
	local turn0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn0 + (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local size = rng:NextNumber(0.35, 0.75) * math.clamp(s, 0.6, 2.2)
		local p = LmKit.part(
			"Block",
			EARTH:Lerp(EARTH_DARK, rng:NextNumber(0, 1)),
			Vector3.new(size, size * rng:NextNumber(0.6, 1), size * rng:NextNumber(0.8, 1.3)),
			Enum.Material.Slate,
			0
		)
		local start = base + out * rng:NextNumber(0.3, 0.8) * reach * 0.4 + Vector3.new(0, size, 0)
		local vel = out * rng:NextNumber(6, 12) * math.sqrt(reach / 3)
			+ Vector3.new(0, rng:NextNumber(12, 22) * math.clamp(math.sqrt(s), 0.8, 1.4), 0)
		local rot = CFrame.lookAt(Vector3.zero, vel).Rotation
		p.CFrame = CFrame.new(start) * rot
		table.insert(bodies, {
			p = p,
			pos = start,
			vel = vel,
			rot = rot,
			spin = LmKit.spinVec(7),
			floor = floor + size * 0.5,
			life = rng:NextNumber(0.9, 1.3),
			bounce = 0.2,
		})
	end
	LmKit.ballistic(bodies, 60)
end

-- A heavy blow into the ground (studio review 2026-10-26: it has to read from the camera's distance): a flash of dust
-- at the contact, a fast dust ring out to the blow's area, chunks of earth kicked up, cracks that fade over about a
-- second, the rock spray and a rolling cloud. `area`: the ability's radius (studs), else by the monster's size.
local function slam(pos: Vector3, s: number, area: number?, simple: boolean)
	local base = kit.ground(pos)
	local reach = math.clamp(area or 3.5 * s, 2.5, 16)
	Library.impactFlash(base + Vector3.new(0, 0.6 * math.min(s, 2), 0), 1.3 * s, DUST_FLASH, { simple = simple })
	-- the ring always (low quality too): it is where the blow lands
	Library.shockwave(base, reach, DUST_RING, 0.4, simple, true)
	Library.rockBurst(base, reach * 0.8, math.clamp(0.9 * s, 0.6, 2.2), kit.DUST_COLOR, { simple = simple })
	Library.cracks(base, math.clamp(reach * 0.55, 1.5, 8), Library.crackTint(kit.DUST_COLOR), 1.1, simple)
	Library.dust(base, math.clamp(1.4 * s, 0.8, 3.5), simple)
	clods(base, math.clamp(math.floor((if simple then 4 else 6) + 3 * s), 6, 14), s, reach)
end

-- Shards flung out of `pos` on ballistic arcs: plain pooled blocks that tumble, hit the ground and fade (`look`: ice
-- glass, bones, violet void glass).
local function shards(
	pos: Vector3,
	count: number,
	s: number,
	power: number,
	life: { number },
	spread: number,
	look: string?
)
	local floor = kit.ground(pos).Y
	local bodies: { LmKit.Body } = {}
	local turn0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn0 + (i / count) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = rng:NextNumber(0.7, 1.5) * s
		local width = length * rng:NextNumber(0.22, 0.32)
		local p = if look == "bone"
			then LmKit.part(
				"Block",
				BONE:Lerp(WHITE, rng:NextNumber(0, 0.2)),
				Vector3.new(width, width, length),
				Enum.Material.SmoothPlastic,
				0
			)
			elseif look == "void" then LmKit.part(
				"Block",
				VOID:Lerp(WHITE, rng:NextNumber(0, 0.25)),
				Vector3.new(width, width, length),
				Enum.Material.Glass,
				0.2
			)
			else LmKit.part(
				"Block",
				ICE_PART:Lerp(WHITE, rng:NextNumber(0, 0.4)),
				Vector3.new(width, width, length),
				Enum.Material.Glass,
				0.15
			)
		local start = pos + out * (rng:NextNumber(0.2, spread) * s) + Vector3.new(0, rng:NextNumber(-0.4, 0.6) * s, 0)
		local vel = out * rng:NextNumber(14, 24) * power + Vector3.new(0, rng:NextNumber(6, 14) * power, 0)
		local rot = CFrame.lookAt(Vector3.zero, vel).Rotation
		p.CFrame = CFrame.new(start) * rot
		table.insert(bodies, {
			p = p,
			pos = start,
			vel = vel,
			rot = rot,
			spin = LmKit.spinVec(9),
			floor = floor + width * 0.5,
			life = rng:NextNumber(life[1], life[2]),
			bounce = 0.25,
		})
	end
	LmKit.ballistic(bodies, 55)
end

-- Ice spikes erupting from the ground on a ring of `radius` round `base`: two glass wedges back to back (a thin
-- crystal blade, pointed, its flat side toward the centre) thrust up and leaning out in 0.09 s, held, then shattering
-- into chips and shrinking away.
local function iceRing(base: Vector3, radius: number, count: number, height: number, delay: number, simple: boolean)
	Clock.after(delay, function()
		local turn0 = rng:NextNumber(0, math.pi * 2)
		for i = 1, count do
			local a = turn0 + (i / count) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local h = height * rng:NextNumber(0.75, 1.2)
			local w = h * rng:NextNumber(0.42, 0.58)
			local spot = kit.ground(base + out * radius * rng:NextNumber(0.9, 1.1))
			-- the blade's profile lies along the ring (local Z the tangent, local -X outwards); a turn about Z leans it out
			local tangent = Vector3.new(-out.Z, 0, out.X)
			local frame = CFrame.lookAt(spot, spot + tangent) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(10, 24)))
			local tint = ICE_SPIKE:Lerp(WHITE, rng:NextNumber(0, 0.25))
			local pieces: { BasePart } = {}
			for side = 0, 1 do
				local turn = CFrame.Angles(0, side * math.pi, 0)
				local p = LmKit.part("Wedge", tint, Vector3.new(w * 0.45, h, w * 0.5), Enum.Material.Ice, 0.1)
				local rest = frame * turn * CFrame.new(0, 0, -w * 0.25)
				p.CFrame = rest * CFrame.new(0, -h * 0.6, 0)
				tween(
					p,
					0.09,
					{ CFrame = rest * CFrame.new(0, h * 0.4, 0) },
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
				)
				table.insert(pieces, p)
			end
			Clock.after(0.85 + rng:NextNumber(0, 0.2), function()
				if not simple then
					local mid = spot + Vector3.new(0, h * 0.5, 0)
					burst("iceShard", CFrame.new(mid), WHITE, 4, {
						simple = simple,
						to = ICE_PART,
						spread = 180,
						speedMin = 4,
						speedMax = 10,
						accel = Vector3.new(0, -30, 0),
						lifeMin = 0.3,
						lifeMax = 0.6,
						rotation = NumberRange.new(0, 360),
						rotSpeed = NumberRange.new(-300, 300),
						sizeSeq = NumberSequence.new({ kp(0, 0.35), kp(1, 0.15) }),
						emission = 0.5,
					})
				end
				for _, p in pieces do
					if p.Parent then
						LmKit.fadeOut(p, 0.25, { Size = p.Size * 0.35 })
					end
				end
			end)
		end
	end)
end

-- The ice elemental's frost nova (owner 2026-10-26): a flash and a cold light, crystal shards flung out of the body,
-- the frost blast's spray and mist, and ice spikes erupting from the ground in two rings, then shattering.
local function nova(pos: Vector3, reach: number, s: number, simple: boolean)
	local p = PALETTES.ice
	Library.impactFlash(pos, 2.4 * s, p.main, { simple = simple })
	shards(pos, LmKit.amount(14, simple), s, math.sqrt(s), { 0.9, 1.3 }, 0.4)
	Library.frostBlast(pos, 1.1 * s, p.main, { simple = simple })
	local base = kit.ground(pos)
	local inner = math.clamp(reach * 0.35, 2.5, 6)
	local outer = math.clamp(reach * 0.65, 4, 10)
	-- studio review 2026-10-26: tall, thick blades the owner can read from the camera's distance
	local height = math.clamp(2.6 * s, 2.5, 6)
	-- the owner's ask: the spikes are the attack, so the rings keep most of their blades when simple
	iceRing(base, inner, if simple then 6 else 8, height, 0, simple)
	iceRing(base, outer, if simple then 9 else 12, height * 1.35, 0.08, simple)
end

-- An ember nova (the golems, the imp): a flash and a fire blast at the feet, a ring of flame columns bursting up round
-- them, embers thrown out and the shock running over the ground.
local function fireNova(pos: Vector3, reach: number, s: number, simple: boolean)
	local p = PALETTES.fire
	local base = kit.ground(pos)
	Library.impactFlash(base + Vector3.new(0, 0.8 * s, 0), 2.2 * s, p.main, { simple = simple })
	Library.fireBlast(base + Vector3.new(0, 0.5 * s, 0), 1.1 * s, p.main, { simple = simple })
	Library.shockwave(base, math.clamp(reach * 0.8, 4, 14), p.main, 0.45, simple)
	local ring = math.clamp(reach * 0.5, 2.5, 8)
	local count = LmKit.amount(8, simple)
	local turn0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn0 + (i / count) * math.pi * 2
		local spot = kit.ground(base + Vector3.new(math.cos(a), 0, math.sin(a)) * ring)
		Clock.after(0.03 + 0.05 * (i % 2), function()
			burst("fire", kit.facingFrame(spot, Vector3.yAxis), p.core:Lerp(p.main, 0.4), 6, {
				simple = simple,
				to = p.deep,
				direction = Enum.NormalId.Front,
				spread = 12,
				speedMin = 6 * s,
				speedMax = 11 * s,
				drag = 3,
				accel = Vector3.new(0, 4, 0),
				lifeMin = 0.35,
				lifeMax = 0.6,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-120, 120),
				sizeSeq = NumberSequence.new({ kp(0, 0.6 * s), kp(0.4, 1.5 * s), kp(1, 1.9 * s) }),
				transparency = NumberSequence.new({ kp(0, 0.1), kp(0.6, 0.35), kp(1, 1) }),
				emission = 1,
			})
		end)
	end
	burst("spark", kit.facingFrame(base + Vector3.new(0, 0.5, 0), Vector3.yAxis), p.core, 14, {
		simple = simple,
		to = p.main,
		direction = Enum.NormalId.Front,
		spread = 70,
		speedMin = 10,
		speedMax = 22,
		drag = 1,
		accel = Vector3.new(0, -30, 0),
		lifeMin = 0.5,
		lifeMax = 0.9,
		orient = "parallel",
		sizeSeq = NumberSequence.new({ kp(0, 0.22), kp(1, 0.05) }),
	})
end

-- A dark nova (the bone nova, the void): a violet flash and ring, dark smoke rolling out low, bones (or void glass)
-- flung out, pale motes rising.
local function shadowNova(pos: Vector3, reach: number, s: number, bones: boolean, simple: boolean)
	local p = PALETTES.shadow
	local base = kit.ground(pos)
	Library.impactFlash(base + Vector3.new(0, 0.8 * s, 0), 2 * s, p.main, { simple = simple })
	Library.ringWave(base, math.clamp(reach * 0.8, 4, 14), p.main, { simple = simple })
	burst("smoke", kit.facingFrame(base + Vector3.new(0, 0.3, 0), Vector3.yAxis), p.main, 10, {
		simple = simple,
		to = p.smoke,
		direction = Enum.NormalId.Front,
		spread = 80,
		speedMin = 6 * s,
		speedMax = 12 * s,
		drag = 3,
		accel = Vector3.new(0, 1, 0),
		lifeMin = 0.7,
		lifeMax = 1.1,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-60, 60),
		sizeSeq = NumberSequence.new({ kp(0, 0.8 * s), kp(1, 2.6 * s) }),
		transparency = NumberSequence.new({ kp(0, 0.4), kp(1, 1) }),
		emission = 0.4,
	})
	shards(
		base + Vector3.new(0, 0.6 * s, 0),
		LmKit.amount(10, simple),
		s * 0.8,
		0.8,
		{ 0.8, 1.2 },
		0.5,
		if bones then "bone" else "void"
	)
	if not simple then
		wisps(base + Vector3.new(0, 0.8 * s, 0), "shadow", s, simple)
	end
end

-- A green nova (venom, nature): the ring, a low cloud rolling out, bubbles or leaves thrown up.
local function greenNova(pos: Vector3, reach: number, s: number, element: string, simple: boolean)
	local p = paletteOf(element)
	local base = kit.ground(pos)
	Library.impactFlash(base + Vector3.new(0, 0.8 * s, 0), 1.8 * s, p.main, { simple = simple })
	Library.ringWave(base, math.clamp(reach * 0.8, 4, 14), p.main, { simple = simple })
	burst("smoke", kit.facingFrame(base + Vector3.new(0, 0.3, 0), Vector3.yAxis), p.main:Lerp(WHITE, 0.2), 9, {
		simple = simple,
		to = p.deep,
		direction = Enum.NormalId.Front,
		spread = 80,
		speedMin = 5 * s,
		speedMax = 10 * s,
		drag = 3,
		lifeMin = 0.8,
		lifeMax = 1.2,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-60, 60),
		sizeSeq = NumberSequence.new({ kp(0, 0.8 * s), kp(1, 2.4 * s) }),
		transparency = NumberSequence.new({ kp(0, 0.45), kp(1, 1) }),
		emission = 0.3,
	})
	if element == "nature" then
		Library.leafBurst(base, 1.2 * s, p.main, { simple = simple })
	else
		burst("poisonBubble", kit.facingFrame(base + Vector3.new(0, 0.4, 0), Vector3.yAxis), p.core, 12, {
			simple = simple,
			to = p.main,
			direction = Enum.NormalId.Front,
			spread = 60,
			speedMin = 6,
			speedMax = 12,
			drag = 1.5,
			accel = Vector3.new(0, -12, 0),
			lifeMin = 0.6,
			lifeMax = 1,
			sizeSeq = NumberSequence.new({ kp(0, 0.35 * s), kp(1, 0.2 * s) }),
			emission = 0.5,
		})
	end
end

-- A storm nova: arcs running out over the ground from the body, the ring, the crackle.
local function stormNova(pos: Vector3, reach: number, s: number, simple: boolean)
	local p = PALETTES.lightning
	local base = kit.ground(pos)
	Library.arcBurst(pos, 1.2 * s, p.main, { simple = simple })
	Library.ringWave(base, math.clamp(reach * 0.8, 4, 14), p.main, { simple = simple })
	local count = if simple then 2 else 4
	local turn0 = rng:NextNumber(0, math.pi * 2)
	for i = 1, count do
		local a = turn0 + (i / count) * math.pi * 2
		local to = kit.ground(base + Vector3.new(math.cos(a), 0, math.sin(a)) * math.clamp(reach * 0.6, 3, 10))
		LmKit.forkBolt(pos, to, p.core:Lerp(p.main, 0.3), 0.12 * s, simple, 1)
	end
end

-- The nova of an element (the ice elemental's and the frost casters' spikes; nothing without an element: the slam
-- that goes with it shows the blow).
local function novaOf(o: Owner, pos: Vector3, element: string?, s: number, simple: boolean)
	local bound = o.bound
	local reach = (bound and bound.radius) or 10
	if element == "ice" then
		nova(pos, reach, s, simple)
	elseif element == "fire" then
		fireNova(pos, reach, s, simple)
	elseif element == "shadow" then
		shadowNova(pos, reach, s, bound ~= nil and bound.ability == "boneNova", simple)
	elseif element == "poison" or element == "nature" then
		greenNova(pos, reach, s, element, simple)
	elseif element == "lightning" then
		stormNova(pos, reach, s, simple)
	end
end

-- The ice elemental's death: the body bursts into ice shards (more, bigger, longer), mist and glints.
local function shatter(pos: Vector3, s: number, simple: boolean)
	local p = PALETTES.ice
	Library.impactFlash(pos, 3 * s, p.main, { simple = simple })
	shards(pos, LmKit.amount(22, simple), s * 1.2, 0.8, { 1.3, 1.9 }, 0.6)
	Library.frostBlast(pos, 1.6 * s, p.main, { simple = simple })
end

local function fireOnce(o: Owner, fx: MotionFxData.Fx, simple: boolean)
	local anchor = resolve(o, fx.at)
	local pos, dir = place(o, anchor)
	local element = elementOf(o, fx)
	local s = sizeOf(o, fx)
	local kind = fx.kind
	if kind == "spit" then
		spit(pos, dir, element, s, simple)
	elseif kind == "bolt" then
		bolt(pos, dir, element, s, simple)
	elseif kind == "flare" then
		flare(o, anchor, element, s, simple)
	elseif kind == "nova" then
		novaOf(o, pos, element, s, simple)
	elseif kind == "shatter" then
		shatter(pos, s, simple)
	elseif kind == "slam" then
		local bound = o.bound
		slam(pos, s, bound and bound.radius, simple)
	elseif kind == "dust" then
		Library.dust(pos, math.clamp(s, 0.4, 3), simple)
	elseif kind == "screech" then
		screech(pos, dir, element, s, simple)
	elseif kind == "wisps" then
		wisps(pos, element, s, simple)
	elseif kind == "feathers" then
		feathers(pos, FEATHERS[o.styleId] or FEATHER, s, simple)
	elseif kind == "splinters" then
		splinters(pos, s, simple)
	elseif kind == "leaves" then
		leaves(pos, s, simple)
	elseif kind == "snow" then
		snow(pos, s, simple)
	end
end

---------------------------------------------------------------- the owners

-- Starts drawing the actions of `rig` (client/Anim BipedRig, QuadRig, RigidRig or FlyerRig of `look`) for `model`
-- (the server's monster or the AnimLab subject; the key of step / detach / claims). `assetModel` is the look's
-- Data/MonsterAssets model (the rig maps), `kindId` the monster kind or boss (elements, the release point).
function MotionFx.attach(model: Model, look: Model, rig: any, styleId: string, assetModel: string?, kindId: string?)
	MotionFx.detach(model)
	if not rig or not MotionFxData.STYLES[styleId] then
		return
	end
	local root = look:FindFirstChild("HumanoidRootPart")
	local rootPart: BasePart? = if root and root:IsA("BasePart") then root else look.PrimaryPart
	if not rootPart then
		return
	end
	local space = rootPart.CFrame
	local lo, hi = visibleBox(look, space)
	local height = math.max(0.5, hi.Y - lo.Y)
	owners[model] = {
		model = model,
		look = look,
		rig = rig,
		style = rig.motion.style,
		styleId = styleId,
		kindId = kindId,
		assetModel = assetModel,
		root = rootPart,
		space = space,
		lo = lo,
		hi = hi,
		height = height,
		size = height / MAN,
		anchors = {},
		runName = nil,
		runStart = 0,
		list = nil,
		action = nil,
		hit = 0,
		bound = nil,
		last = nil,
		fired = {},
		streams = {},
		hitAt = nil,
		steppedAt = 0,
		culled = false,
	}
end

-- Stops everything a model shows (it left, its look was rebuilt, the AnimLab subject changed).
function MotionFx.detach(model: Model)
	local o = owners[model]
	if not o then
		return
	end
	stopAll(o)
	owners[model] = nil
end

-- A model that is not animated this frame (beyond the nearest animated ones): its streams stop where they are.
function MotionFx.pause(model: Model)
	local o = owners[model]
	if o and next(o.streams) ~= nil then
		stopAll(o)
	end
end

-- One frame of a model's action `run` ({ name, start, hit, ability? } on the clock of `now`; nil: none) and its last
-- flinch `hitAt` (same clock).
function MotionFx.step(model: Model, run: any?, now: number, hitAt: number?)
	local o = owners[model]
	if not o then
		return
	end
	if not o.root.Parent then
		MotionFx.detach(model)
		return
	end
	o.steppedAt = os.clock()
	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - o.root.Position).Magnitude else 0
	local culled = distance > cullDistance()
	o.culled = culled
	local simple = distance > Config.Vfx.simpleBeyond or kit.lowQuality()
	-- the puff a hit knocks off
	if hitAt and hitAt ~= o.hitAt then
		o.hitAt = hitAt
		local puff = MotionFxData.HIT[o.styleId]
		if puff and not culled and now >= hitAt and now - hitAt < HIT_FRESH then
			fireOnce(o, puff, simple)
		end
	end
	-- a new action (by name and start: AnimLab's fight builds a new run table each frame)
	local name = if run then run.name else nil
	local start = if run then run.start else 0
	if name ~= o.runName or start ~= o.runStart then
		stopAll(o)
		table.clear(o.fired)
		o.runName, o.runStart, o.last = name, start, nil
		o.list = if name then MotionFxData.get(o.styleId, name) else nil
		o.action = if name then o.style.actions[name] else nil
		o.hit = if run then run.hit else 0
		o.bound = if o.list and name
			then ActionFx.bound(o.kindId, o.style.abilities or {}, name, run and run.ability)
			else nil
	end
	local list, action = o.list, o.action
	if not run or not list or not action then
		return
	end
	local t = now - start
	local last = o.last
	if last and last > o.hit + action.follow + action.recover and t >= last and next(o.streams) == nil then
		return -- long over (the run stays until the next action)
	end
	if last and t < last - 1e-3 then
		-- back in time (an AnimLab scrub): everything starts over
		stopAll(o)
		table.clear(o.fired)
		last = nil
	end
	o.last = t
	for i, fx in list do
		local t0, t1 = ActionFx.window(action, o.hit, fx)
		if fx.to then
			local stream: Stream? = o.streams[i]
			if ActionFx.running(t0, t1, t) and not culled then
				if not stream and not o.fired[i] then
					o.fired[i] = true
					stream = startStream(o, fx, t0, t1, simple)
					if stream then
						o.streams[i] = stream
					end
				end
				if stream then
					updateStream(o, stream, t, simple)
				end
			elseif stream then
				stopStream(o, i)
			end
		elseif not o.fired[i] and ActionFx.due(t0, last, t) then
			o.fired[i] = true
			if not culled then
				fireOnce(o, fx, simple)
			end
		end
	end
end

-- Whether the animation of `model` draws attack `attackId`'s gather and its release itself (it is being animated,
-- near enough, and its style has them): Controllers/CombatFxController then leaves out the generic charge glow and the
-- generic burst at the caster.
function MotionFx.claims(model: Model?, attackId: string?): (boolean, boolean)
	local o = if model then owners[model] else nil
	if not o or o.culled or os.clock() - o.steppedAt > CLAIM_FRESH then
		return false, false
	end
	return ActionFx.claims(o.styleId, o.style.abilities or {}, attackId)
end

-- Owners drawn now (AnimLab `vfx stats`).
function MotionFx.count(): number
	local n = 0
	for _ in owners do
		n += 1
	end
	return n
end

return MotionFx
