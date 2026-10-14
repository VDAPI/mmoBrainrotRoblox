--!strict
-- Skill visuals (S05, rebuilt in S28). The server sends "SkillFx" to players within 120 studs of the caster:
--   v = "cast"  when the skill starts: every client plays the caster's animation (Data/SkillMotions) and the cast
--               pieces (weapon trail, glowing hands); the local caster also holds still for `lock` motions
--   no `v`      the impact (after the motion's hit time): pieces from Data/SkillVfx sized by the event
--               { s, c, t?, p?, cf?, r?, a?, l?, w?, d?, n?, path?, from? }
--   v = arc / lightningBurst / meteorImpact / trapSet / trapTrigger / lingering / pierce / splitImpact / echo /
--       splash / stunBurst / pull / fizzle  — extras of adaptive skills and breakpoints
--   v = aim / aimEnd (S76)  the red aiming line of castTime from the caster to the target / point, and its end
--   v = dieFace (S70)  a face of Fortune's dice on an ally (aura in the face's colour); angelSave (S70) the Guardian
--       Angel's save; Roll of the Dice throws two small golden dice from the hand at the motion's release
--   v = falconStrike / falconDive / falconCircle / falconEnd (S77)  the Scout's falcon (one bird per caster id, kept
--       `d` seconds after each event); traps with a `trigger` list play it when they spring (S77)
--   v = furyConsume (S74)  a red aura on the Warrior who spent Fury; impact events with `al` play the entry's `allies`
--       pieces on those allies (guard, shout); War Banner objects (Workspace.Vaelthorn_Banners) are drawn here
--   S80 (ROZWOJ 12.4, 12.5): a beam (Arcane Torrent) loops its motion for the cast event's `d`; each tick (impact with
--       `n`) draws a ray from the weapon's tip, wider every tick; v = beamEnd stops the loop and gives our walk back
--       (channelEnd the same for a channel cut short, fizzle also gives the walk back).
--       `ch` (Arcane Charges spent) grows Arcane Discharge's bolt by the entry's chargeSize; SkillVfx `everyWave`
--       picks the pieces of later waves, `waves` (Cataclysm) gets one event per wave; a pull raises dust. Arcane
--       Charges circle every player who has them (orbs from the "Effects" attribute).
-- Pieces come from client/Vfx/Library (pooled parts, Config.Vfx.maxActive at once); effects of other players far
-- away and low graphics quality use the simple versions. Melee impacts freeze both animations for a moment (hitstop)
-- and big skills shake the camera of players nearby (setting "Camera shake"). S110: every delay of an effect runs on
-- the effect clock (Vfx/Clock, AnimLab freezes it); only the local movement lock stays on task.delay.
-- S111: the impact (the first wave / tick; a projectile when it leaves) plays the skill's Data/Sfx key through
-- SfxController (Logic/SfxRules.skillKey: SkillVfx.sound, skill.<id>, then the default of the skill's kind).
-- S112: the new pieces impactFlash, sparks, groundDecal, smokePuff, magicCircle, ringWave (Vfx/Library) and the texture
-- keys of SkillVfx (decal, circle, sparks); a rune shows the circle of the skill's class (Data/VfxTextures).
-- S114: what `n` of an impact means comes from Logic/SkillFxWave (a wave only for circleSelf and per-wave
-- circleTarget; the waves of a one-event circleTarget; the target of anything else, so a heal's second target and the
-- chain of Heal 10B play the full set, the chain's ray running from the previous target); SkillVfx.tex picks the
-- texture of a piece, coreDelay holds the core (and the sound) back, landsAfter waits the event's `d` (Hammer of
-- Heaven); the cast event's `w` (waves) and `mv` (walking) and the caster's weapon pick a motion variant
-- (AnimationController.Skill, SkillPose.pick); the cast plays skill.<id>.cast when it has a sound. New pieces
-- shieldArc (Shield Wall) and wings (Guardian Angel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Library = require(script.Parent.Parent.Vfx.Library)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local WeaponLooks = require(ReplicatedStorage.Shared.Data.WeaponLooks)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillMotions = require(ReplicatedStorage.Shared.Data.SkillMotions)
local Sfx = require(ReplicatedStorage.Shared.Data.Sfx)
local SfxRules = require(ReplicatedStorage.Shared.Logic.SfxRules)
local SkillVfx = require(ReplicatedStorage.Shared.Data.SkillVfx)
local SkillFxWave = require(ReplicatedStorage.Shared.Logic.SkillFxWave)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local State = require(script.Parent.Parent.UI.State)
local VfxTextures = require(ReplicatedStorage.Shared.Data.VfxTextures)

local VfxController = {
	Name = "VfxController",
	Deps = { "AnimationController", "SfxController" },
}

local AnimationController: any
local SfxController: any
local player = Players.LocalPlayer

local ELEMENT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#9FE0FF"),
	lightning = Color3.fromHex("#F2E85A"),
	poison = Color3.fromHex("#7ACB3A"),
}
local HOLY = Color3.fromHex("#FFE7A0")
local HEAL = Color3.fromHex("#4FD16B")
-- S70: colours of Fortune's dice faces (looks only; the faces are effects in Data/Skills/Cleric).
local FACE_COLORS: { [string]: Color3 } = {
	blade = Color3.fromHex("#E2483A"),
	wind = Color3.fromHex("#9FE0FF"),
	spring = HEAL,
}

-- S76 (ROZWOJ 11.3): the aiming line (red, like the Mark), one per caster id; a new one takes the old one down.
local AIM_COLOR = Color3.fromHex("#E2483A")
local aimLines: { [string]: () -> () } = {}
-- S77: the Scout's falcon, one per caster id; it flies away by itself when events stop coming.
local falcons: { [string]: Library.Falcon } = {}
local PREVIEW_FALCON = "preview" -- falcon key of a preview model without an EntityId (skills window)

-- Camera shake handler (CombatFxController.Shake), set in Init.
local shakeCamera: ((strength: number) -> ())? = nil
-- Local movement lock while our own `lock` motion plays (released by the motion's end).
local lockToken = 0
-- S80: the running lock (humanoid, speed before it, speed it set), so beamEnd can give the walk back at once.
local lockHumanoid: Humanoid? = nil
local lockSpeed = 0
local lockLocked = 0

-- S80: the beam's ray (looks only): width of the first tick and growth per tick; the Arcane Charge orbs' colour.
local BEAM_WIDTH = 0.25
local BEAM_WIDTH_STEP = 0.06
-- Preview (S28/S80): how long a beam / channel preview loops its motion.
local PREVIEW_BEAM_SECONDS = 2
local PREVIEW_CHANNEL_SECONDS = 2.5
local CHARGE_COLOR = Color3.fromHex("#B07CFF")
-- S114: the core layer (DESIGN-16 §2.6) that SkillVfx.coreDelay holds back; pieces that show at once when the blow
-- lands after the event's `d` (SkillVfx.landsAfter: the mark on the ground before the blow).
local CORE: { [string]: boolean } = { impactFlash = true, burst = true }
local MARKS: { [string]: boolean } = { magicCircle = true, rune = true }
-- S114: a chained heal's ray runs from the previous target of the same cast: the last target per caster, kept this long
-- (then dropped, so no destroyed model stays referenced).
local CHAIN_MEMORY = 0.5
local CHAIN_STEP = 0.06 -- seconds between two links of a chain (looks only)
local lastTargets: { [string]: { model: Model, at: number } } = {}

-- Helpers ---------------------------------------------------------------------------------------------------

local function findModel(entityId: string?): Model?
	if not entityId then
		return nil
	end
	if string.sub(entityId, 1, 1) == "p" then
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character and character:GetAttribute("EntityId") == entityId then
				return character
			end
		end
		return nil
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:GetAttribute("EntityId") == entityId then
				return child :: Model
			end
		end
	end
	return nil
end

local centre = Library.centre

-- S80: the tip of a model's weapon (VaelthornTip, EquipmentService), else half a stud above its centre.
local function weaponTip(model: Model): Vector3
	local weapon = model:FindFirstChild("VaelthornWeapon")
	local tip = weapon and weapon:FindFirstChild("VaelthornTip")
	if tip and tip:IsA("Attachment") then
		return tip.WorldPosition
	end
	return centre(model) + Vector3.new(0, 0.5, 0)
end

-- The last walk speed the server set (StatService.applyWalkSpeed), else `fallback`.
local function serverSpeed(humanoid: Humanoid, fallback: number): number
	local value = humanoid:GetAttribute("ServerWalkSpeed")
	return if type(value) == "number" then value else fallback
end

-- S80: gives our walk back now (a beam ended early); a server change of the speed meanwhile is kept.
local function releaseLock()
	local humanoid = lockHumanoid
	lockToken += 1
	lockHumanoid = nil
	if humanoid and humanoid.Parent then
		humanoid.WalkSpeed = serverSpeed(humanoid, lockSpeed)
	end
end

local function colorOf(skill: SkillData.SkillDef, entry: SkillVfx.Entry?, element: any): Color3
	local kind = if entry then entry.color else "class"
	if kind == "element" then
		local el = if type(element) == "string" then element else skill.element
		if el and ELEMENT_COLORS[el] then
			return ELEMENT_COLORS[el]
		end
	elseif kind == "holy" then
		return HOLY
	elseif kind == "heal" then
		return HEAL
	elseif string.sub(kind, 1, 1) == "#" then
		return Color3.fromHex(kind)
	end
	if type(element) == "string" and ELEMENT_COLORS[element] then
		return ELEMENT_COLORS[element]
	end
	local class = Classes.get(skill.class)
	return if class then Color3.fromHex(class.color) else Color3.new(1, 1, 1)
end

-- Simple version: low graphics, or another player's effect far from the camera.
local function simpleAt(at: Vector3?, caster: Model?): boolean
	if State.Get({ "account", "settings", "quality" }) == "low" then
		return true
	end
	if caster == player.Character then
		return false
	end
	local camera = Workspace.CurrentCamera
	if not camera or not at then
		return false
	end
	return (camera.CFrame.Position - at).Magnitude > Config.Vfx.simpleBeyond
end

local function shakeNear(at: Vector3?, strength: number?)
	if not strength or strength <= 0 or not shakeCamera or not at then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local distance = (root.Position - at).Magnitude
	if distance < 40 then
		(shakeCamera :: (number) -> ())(strength * (1 - distance / 40))
	end
end

-- Cast ---------------------------------------------------------------------------------------------------------

local function casterKey(data: { [string]: any }): string?
	return if type(data.c) == "string" then data.c else nil
end

-- S111: the skill's sound (Data/Sfx key: SkillVfx.sound, else skill.<id>, else the default of its kind, Logic/SfxRules)
-- at the impact point, or at the caster when there is none. A caster outside Workspace (the skills-window preview)
-- is silent: its points are viewport coordinates, not world ones.
local function playSound(
	skill: SkillData.SkillDef,
	entry: SkillVfx.Entry?,
	at: Vector3?,
	caster: Model?,
	data: { [string]: any }
)
	if caster and not caster:IsDescendantOf(Workspace) then
		return
	end
	local key = SfxRules.skillKey(skill, if entry then entry.sound else nil, Sfx.playable)
	local where: (Vector3 | Model)? = at or caster
	if key and where then
		SfxController.Play(key, where, SfxController.WhoOf(caster), casterKey(data))
	end
end

-- S77: the falcon of `casterId` kept for `seconds` (created when missing, e.g. a player who came later).
local function falconOf(
	casterId: string?,
	caster: Model?,
	color: Color3,
	simple: boolean,
	seconds: number
): Library.Falcon?
	if not casterId or not caster then
		return nil
	end
	local falcon: Library.Falcon? = falcons[casterId]
	if not falcon or not falcon.alive() then
		falcon = Library.falcon(caster, color, simple)
		falcons[casterId] = falcon :: any
	end
	if falcon then
		falcon.keep(seconds)
	end
	return falcon
end

local function onCast(data: { [string]: any }, skill: SkillData.SkillDef, caster: Model)
	local entry = SkillVfx[skill.id]
	local color = colorOf(skill, entry, data.el)
	-- S77: the aim of castTime (S76 `ct`) holds the draw loop as long as the aim lasts (Heartseeker); S80: a beam
	-- loops for its whole time (beamEnd stops it early)
	local loopUntil = if skill.type == "channel" or skill.type == "beam" then tonumber(data.d) else tonumber(data.ct)
	local motion = AnimationController.Skill(
		caster,
		skill.id,
		loopUntil,
		{ hits = tonumber(data.w), move = tonumber(data.mv) ~= nil }
	)
	local simple = simpleAt(centre(caster), caster)
	-- S114: the wind-up sound of a skill that has one (skill.<id>.cast), at the caster
	if caster:IsDescendantOf(Workspace) then
		local castKey = `skill.{skill.id}.cast`
		if Sfx.playable(castKey) then
			SfxController.Play(castKey, caster, SfxController.WhoOf(caster), casterKey(data))
		end
	end
	if not Pool.take() then
		return
	end
	Pool.done(1.5)
	if entry and motion then
		if entry.trail and motion.trail and not simple then
			Library.weaponTrail(caster, color, motion.trail.from, motion.trail.to)
		end
		if entry.glow then
			Library.glow(caster, entry.glow.hand, color, entry.glow.dur, simple)
		end
		if entry.land and motion.land then
			Clock.after(motion.land, function()
				local land: { string } = entry.land or {}
				for _, piece in land do
					if piece == "dust" then
						Library.dust(centre(caster), 1, simple)
					end
				end
			end)
		end
		-- Projectile skills: the shot leaves the hand at the motion's release (speed 140 and the 0.8 s cap match
		-- server/Skills/Types/Offense CIRCLE_PROJECTILE_*: the damage lands when the orb arrives).
		if entry.projectile and skill.type == "circleTarget" and typeof(data.p) == "Vector3" then
			local release = math.max(0, (motion.release or motion.hit or 0) - 0.05)
			Clock.after(release, function()
				local from = centre(caster) + Vector3.new(0, 1, 0)
				Library.projectile(
					from,
					data.p,
					entry.projectile :: any,
					color,
					{ size = 1.2, speed = 140, simple = simple }
				)
			end)
		end
		-- S70 Roll of the Dice: two small golden dice thrown to the ground in front (one in the simple mode)
		if entry.projectile and skill.type == "groupBuff" then
			local release = math.max(0, (motion.release or motion.hit or 0) - 0.05)
			Clock.after(release, function()
				local root = caster:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					return
				end
				local from = centre(caster) + Vector3.new(0, 0.5, 0)
				local ahead = root.Position + root.CFrame.LookVector * 6 - Vector3.new(0, 2.5, 0)
				for i = 1, if simple then 1 else 2 do
					local side = root.CFrame.RightVector * (if i == 1 then -0.8 else 0.8)
					Library.projectile(
						from,
						ahead + side,
						entry.projectile :: any,
						color,
						{ size = 0.35, speed = 40, simple = simple }
					)
				end
			end)
		end
	end
	-- Our own motion that holds the character still (unless a breakpoint lets it move).
	if caster == player.Character and motion and motion.lock then
		local move = tonumber(data.mv)
		local humanoid = caster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lockToken += 1
			local token = lockToken
			-- S80: a lock still running (a beam cast on top) keeps the speed from before it
			local speed = serverSpeed(
				humanoid,
				if lockHumanoid == humanoid and humanoid.WalkSpeed == lockLocked then lockSpeed else humanoid.WalkSpeed
			)
			local locked = if move then speed * move / 100 else 0
			humanoid.WalkSpeed = locked
			lockHumanoid = humanoid
			lockSpeed = speed
			lockLocked = locked
			local seconds = (motion.keys[#motion.keys].t + motion.recover * 0.5)
				+ (if loopUntil and motion.loop then math.max(0, loopUntil - motion.loop.to) else 0)
			-- S110: the movement lock stays on real time (it is gameplay, not an effect)
			task.delay(seconds, function()
				-- S63: the server may have changed the speed meanwhile (a slow, stun or root started or ended): restore
				-- the server's last value, not a comparison with `locked` (a stun's 0 equals a full lock's 0).
				if lockToken == token and humanoid.Parent then
					humanoid.WalkSpeed = serverSpeed(humanoid, speed)
				end
				if lockToken == token then
					lockHumanoid = nil
				end
			end)
		end
	end
end

-- Impact pieces ------------------------------------------------------------------------------------------------

local function impactPoint(data: { [string]: any }, caster: Model?, target: Model?): Vector3?
	if typeof(data.p) == "Vector3" then
		return data.p
	end
	if target then
		return centre(target)
	end
	if typeof(data.cf) == "CFrame" then
		-- S114: a cone's blow lands in front of the caster (halfway out), a line's at its start
		local radius = tonumber(data.r)
		if radius and data.a then
			return data.cf.Position + data.cf.LookVector * radius * 0.5
		end
		return data.cf.Position
	end
	return if caster then centre(caster) else nil
end

local function facing(caster: Model?, target: Model?, data: { [string]: any }): CFrame?
	if typeof(data.cf) == "CFrame" then
		return data.cf
	end
	if caster then
		local from = centre(caster)
		local to = if target then centre(target) else from + caster:GetPivot().LookVector
		local flat = Vector3.new(to.X, from.Y, to.Z)
		if (flat - from).Magnitude < 0.1 then
			flat = from + caster:GetPivot().LookVector
		end
		return CFrame.lookAt(from, flat)
	end
	return nil
end

-- S112: the circle texture of a skill: SkillVfx.circle, else the rune of its class, else magicCircle.
local function circleOf(skill: SkillData.SkillDef, entry: SkillVfx.Entry?): string
	return if entry and entry.circle then entry.circle else VfxTextures.runeOf(skill.class)
end

local function piece(
	name: string,
	skill: SkillData.SkillDef,
	entry: SkillVfx.Entry,
	data: { [string]: any },
	color: Color3,
	caster: Model?,
	target: Model?,
	simple: boolean,
	from: Model?
)
	local at = impactPoint(data, caster, target)
	local scale = entry.size or 1
	local radius = tonumber(data.r) or skill.radius or (6 * scale)
	local seconds = tonumber(data.d) or 1
	-- S114: a local mark (the pole, the shield) keeps its own size instead of the area's radius
	local markRadius = entry.markRadius
	-- S114: the texture of this piece (SkillVfx.tex), else the piece's own default
	local tex = if entry.tex then entry.tex[name] else nil
	if name == "burst" then
		if at then
			Library.burst(at, 5 * scale, color, nil, simple)
		end
	elseif name == "shockwave" then
		if at then
			Library.shockwave(at, radius, color, 0.45, simple)
		end
	elseif name == "cracks" then
		if at and not simple then
			local size = if markRadius then markRadius else math.max(3, radius * 0.8 * (if data.r then 1 else scale))
			Library.cracks(at, size, color, 1.4, simple)
		end
	elseif name == "dust" then
		if at then
			Library.dust(at, scale, simple)
		end
	elseif name == "pillar" then
		local where = if target then centre(target) else at
		local spec = entry.pillar
		if where then
			Library.pillar(
				where,
				if spec then spec.radius else 1.5 * scale,
				if spec then spec.height else 14 * scale,
				color,
				0.7
			)
		end
	elseif name == "sparkle" then
		local model = target or caster
		if model then
			Library.sparkle(model, color, simple)
		end
	elseif name == "aura" then
		local model = target or caster
		if model then
			Library.aura(model, color, seconds, simple, tex)
		end
	elseif name == "shield" then
		local model = target or caster
		if model then
			Library.shield(model, color, seconds)
		end
	elseif name == "beam" then
		-- S114: a chained target's ray starts at the previous target of the cast (`from`)
		local source = from or caster
		if source and target and source ~= target then
			Library.beam(centre(source), centre(target), color, 0.35, 0.35, if tex then { key = tex } else nil)
		end
	elseif name == "dash" then
		if typeof(data.from) == "Vector3" then
			local to = if typeof(data.p) == "Vector3" then data.p else at
			if to then
				Library.dash(data.from, to, color, simple, tex)
			end
		end
	elseif name == "rune" then
		local where = at or (if caster then centre(caster) else nil)
		if where then
			Library.rune(where, radius, color, math.max(0.8, seconds), simple, tex or circleOf(skill, entry))
		end
	elseif name == "impactFlash" then
		if at then
			Library.impactFlash(at, entry.flash or 3 * scale, color, { simple = simple, key = tex })
		end
	elseif name == "sparks" then
		if at then
			local origin = if caster then centre(caster) else nil
			local away = if origin and (at - origin).Magnitude > 0.1
				then (at - origin).Unit + Vector3.new(0, 0.6, 0)
				else nil
			Library.sparks(at, color, { simple = simple, key = tex or entry.sparks, dir = away })
		end
	elseif name == "groundDecal" then
		if at then
			local mark = tex or entry.decal or "cracks"
			local tint = if mark == "cracks" then Library.crackTint(color) else color
			Library.groundDecal(at, markRadius or math.max(3, radius * 0.8), mark, tint, 1.4, { simple = simple })
		end
	elseif name == "smokePuff" then
		if at then
			Library.smokePuff(at, scale, color, { simple = simple, key = tex })
		end
	elseif name == "magicCircle" then
		local where = at or (if caster then centre(caster) else nil)
		if where then
			Library.magicCircle(
				where,
				radius,
				color,
				math.max(0.8, seconds),
				{ simple = simple, key = tex or circleOf(skill, entry) }
			)
		end
	elseif name == "ringWave" then
		if at then
			Library.ringWave(at, radius, color, { simple = simple, key = tex })
		end
	elseif name == "shieldArc" then
		local frame = facing(caster, target, data)
		if frame then
			Library.shieldArc(frame, radius, color, simple)
		end
	elseif name == "wings" then
		local model = target or caster
		if model then
			Library.wings(model, color, 1, simple)
		end
	elseif name == "slash" or name == "whirl" then
		local frame = facing(caster, target, data)
		if frame then
			local spec = entry.slash
			if name == "whirl" then
				Library.slash(frame, radius, 180, -180, color, 0, simple, tex)
			else
				local angle = tonumber(data.a)
				local half = if angle then angle / 2 else nil
				local sweepFrom = if half then half else (spec and spec.from or 60)
				local sweepTo = if half then -half else (spec and spec.to or -60)
				Library.slash(
					frame,
					(spec and spec.radius) or radius,
					sweepFrom,
					sweepTo,
					color,
					spec and spec.tilt,
					simple,
					tex
				)
			end
		end
	elseif name == "arrowRain" then
		if at then
			-- S114: the waves of the one event come with it (`n`), breakpoints included
			local waves = SkillFxWave.of(skill.type, entry.waves, tonumber(data.n)).count or skill.hits or 1
			local random = Random.new()
			for wave = 1, waves do
				Clock.after((wave - 1) * (skill.interval or 0.5), function()
					for _ = 1, if simple then 4 else 9 do
						local a = random:NextNumber() * math.pi * 2
						local d = math.sqrt(random:NextNumber()) * radius
						local spot = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
						local ground = Library.ground(spot)
						Library.projectile(
							ground + Vector3.new(random:NextNumber(-3, 3), 26, random:NextNumber(-3, 3)),
							ground,
							"arrow",
							color,
							{ speed = 120, simple = true }
						)
					end
				end)
			end
		end
	elseif name == "fan" then
		local frame = facing(caster, target, data)
		if frame then
			local angle = tonumber(data.a) or skill.angle or 60
			local count = if simple then 3 else (skill.hits or 5)
			for i = 1, count do
				local yaw = math.rad(-angle / 2 + angle * (i - 0.5) / count)
				local dir = (frame * CFrame.Angles(0, yaw, 0)).LookVector
				local start = frame.Position + Vector3.new(0, 1, 0)
				Clock.after(i * 0.04, function()
					Library.projectile(start, start + dir * radius, "arrow", color, { speed = 110, simple = simple })
				end)
			end
		end
	elseif name == "lineBeam" then
		if typeof(data.cf) == "CFrame" then
			local length = tonumber(data.l) or skill.length or 20
			local start = data.cf.Position + Vector3.new(0, 1, 0)
			local finish = start + data.cf.LookVector * length
			Library.beam(start, finish, color, math.max(0.6, (tonumber(data.w) or 4) * 0.3), 0.45)
			Library.projectile(start, finish, "arrow", color, { speed = 160, size = 1.6, simple = simple })
		end
	elseif name == "skyBolt" then
		local where = if target then centre(target) else at
		if where then
			if tex then
				-- S114: a straight, thick ray of the texture from the sky (light, not lightning)
				Library.beam(where + Vector3.new(0, 30, 0), where, color, 1.1 * scale + 0.4, 0.45, { key = tex })
			else
				Library.lightning(where + Vector3.new(0, 30, 0), where, color, 0.5, simple)
			end
			Library.burst(where, 4, color, nil, simple)
		end
	elseif name == "meteor" then
		if at then
			Library.meteor(at, radius, math.max(0.2, seconds), color, simple)
		end
	elseif name == "smoke" then
		local model = target or caster
		if model then
			Library.dust(centre(model), 1.6, simple)
		end
	elseif name == "cloud" then
		if at then
			Library.lingering(at, 4, "poison", color, 1.2, simple)
		end
	elseif name == "tether" then
		if caster and target and caster ~= target then
			Library.tether(caster, target, color, seconds, tex)
		end
	elseif name == "falcon" then
		falconOf(casterKey(data), caster, color, simple, seconds)
	end
end

local TELEGRAPH_SECONDS = 0.5

local function onImpact(data: { [string]: any }, skill: SkillData.SkillDef, caster: Model?)
	local entry = SkillVfx[skill.id]
	if not entry then
		return
	end
	local color = colorOf(skill, entry, data.el)
	local target = findModel(data.t)
	local at = impactPoint(data, caster, target)
	local simple = simpleAt(at, caster)
	if not Pool.take() then
		return
	end
	Pool.done(TELEGRAPH_SECONDS + 1)
	local kind = skill.type
	-- S80: a beam tick, a ray from the weapon's tip, wider every tick; every piece lives one tick
	if kind == "beam" then
		if caster and target then
			local n = tonumber(data.n) or 1
			local interval = skill.interval or 0.5
			Library.beam(
				weaponTip(caster),
				centre(target),
				color,
				BEAM_WIDTH + BEAM_WIDTH_STEP * (n - 1),
				interval + 0.05
			)
			Library.sparkle(target, color, simple)
			Library.aura(caster, color, interval + 0.1, simple)
			if n == 1 then
				playSound(skill, entry, at, caster, data)
			end
		end
		return
	end
	-- Projectiles fly to the target; the pieces play on arrival.
	if kind == "projectile" and caster and target then
		local from = centre(caster) + Vector3.new(0, 0.8, 0)
		-- S80: Arcane Discharge grows with the charges it spent
		local size = (entry.size or 1) + (entry.chargeSize or 0) * (tonumber(data.ch) or 0)
		Library.projectile(from, target, entry.projectile or "orb", color, {
			size = size,
			simple = simple,
			onArrive = function()
				for _, name in entry.impact do
					piece(name, skill, entry, data, color, caster, target, simple)
				end
			end,
		})
		-- the cast sound at the caster when the projectile leaves (the hit's material comes with its dmg event)
		playSound(skill, entry, nil, caster, data)
		return
	end
	if kind == "chain" then
		local path = data.path
		if type(path) == "table" then
			for i = 1, #path - 1 do
				local a, b = findModel(path[i]), findModel(path[i + 1])
				if a and b then
					Clock.after((i - 1) * 0.06, function()
						Library.lightning(centre(a), centre(b), color, 0.3, simple)
						Library.burst(centre(b), 3, color, nil, simple)
					end)
				end
			end
		end
		playSound(skill, entry, at, caster, data)
		return
	end
	-- S114 (Logic/SkillFxWave): `n` is a wave only for circleSelf and per-wave circleTarget; for the rest it counts
	-- the waves of one event or the cast's targets, and every target plays the full set.
	local info = SkillFxWave.of(kind, entry.waves, tonumber(data.n))
	local wave = info.wave
	-- S114: the ray of a chained target starts at the previous target of the same cast (known for CHAIN_MEMORY s)
	local id = casterKey(data)
	local previous: Model? = nil
	if id and target then
		local last = lastTargets[id]
		if info.target > 1 and last and Clock.now() - last.at <= CHAIN_MEMORY and last.model ~= target then
			previous = last.model
		end
		local mark = { model = target, at = Clock.now() }
		lastTargets[id] = mark
		Clock.after(CHAIN_MEMORY, function()
			if lastTargets[id] == mark then
				lastTargets[id] = nil
			end
		end)
	end
	local linkDelay = (info.target - 1) * CHAIN_STEP
	-- S114: the blow lands `d` s after the event (landsAfter: only the mark shows at once); the core waits coreDelay
	local landDelay = if entry.landsAfter then math.max(0, tonumber(data.d) or 0) else 0
	local coreDelay = entry.coreDelay or 0
	local everyWave = entry.everyWave -- S80: the entry's own pieces of later waves
	for _, name in entry.impact do
		local again = if everyWave
			then table.find(everyWave, name) ~= nil
			else name == "shockwave"
				or name == "ringWave"
				or name == "whirl"
				or name == "cracks"
				or name == "groundDecal"
				or name == "pillar"
		if wave == 1 or again then
			local wait = linkDelay + (if MARKS[name] then 0 else landDelay) + (if CORE[name] then coreDelay else 0)
			if wait > 0 then
				Clock.after(wait, piece, name, skill, entry, data, color, caster, target, simple, previous)
			else
				piece(name, skill, entry, data, color, caster, target, simple, previous)
			end
		end
	end
	-- S74: pieces on the allies the skill covered (guard, shout, buff)
	local allies = entry.allies
	if allies and wave == 1 and type(data.al) == "table" then
		local allyColor = if entry.allyColor then Color3.fromHex(entry.allyColor) else color
		for _, ally in data.al do
			local model = findModel(ally)
			if model then
				for _, name in allies do
					piece(name, skill, entry, data, allyColor, caster, model, simple)
				end
			end
		end
	end
	-- Area outline where the blow lands.
	if entry.telegraph and wave == 1 and at then
		if entry.telegraph == "circle" and data.r then
			Library.telegraph("circle", CFrame.new(at), tonumber(data.r) :: number, nil, color)
		elseif entry.telegraph == "cone" and typeof(data.cf) == "CFrame" then
			Library.telegraph("cone", data.cf, tonumber(data.r) or 10, tonumber(data.a) or 90, color)
		elseif entry.telegraph == "line" and typeof(data.cf) == "CFrame" then
			Library.telegraph("line", data.cf, tonumber(data.l) or 20, tonumber(data.w) or 4, color)
		end
	end
	-- Hitstop on melee blows (with the core: S114 coreDelay) and camera shake for big ones (when the blow lands).
	local hitstop = entry.hitstop
	if hitstop and caster then
		local function stop()
			AnimationController.Hitstop(caster, hitstop)
			if target then
				AnimationController.Hitstop(target, hitstop)
			end
		end
		if coreDelay > 0 then
			Clock.after(coreDelay, stop)
		else
			stop()
		end
	end
	if landDelay > 0 then
		Clock.after(landDelay, shakeNear, at, entry.shake)
	else
		shakeNear(at, entry.shake)
	end
	if wave == 1 and info.target == 1 then
		local soundDelay = landDelay + coreDelay
		if soundDelay > 0 then
			Clock.after(soundDelay, playSound, skill, entry, at, caster, data)
		else
			playSound(skill, entry, at, caster, data)
		end
	end
end

-- Extras (adaptive skills, breakpoints) ---------------------------------------------------------------------------

local function onExtra(data: { [string]: any }, skill: SkillData.SkillDef, caster: Model?)
	local v = data.v
	local entry = SkillVfx[skill.id]
	local color = colorOf(skill, entry, data.el)
	local at = if typeof(data.p) == "Vector3" then data.p else nil
	local simple = simpleAt(at, caster)
	local radius = tonumber(data.r) or 6
	if v == "fizzle" or v == "beamEnd" or v == "channelEnd" then
		-- S80: stop the motion's loop and give our walk back: a beam's ray and aura go out by themselves within a
		-- tick (beamEnd), Evocation / Prayer cut short (channelEnd), a refused beam already locked us (fizzle)
		if caster then
			AnimationController.StopSkill(caster)
			if caster == player.Character then
				releaseLock()
			end
		end
	elseif v == "arc" or v == "pierce" then
		local path = data.path
		if type(path) == "table" then
			local a, b = findModel(path[1]), findModel(path[2])
			if a and b then
				if v == "arc" then
					Library.lightning(centre(a), centre(b), ELEMENT_COLORS.lightning, 0.3, simple)
				else
					Library.projectile(
						centre(a),
						b,
						if entry then entry.projectile or "arrow" else "arrow",
						color,
						{ simple = simple }
					)
				end
			end
		end
	elseif v == "dieFace" then
		-- S70: the face an ally got from Fortune's dice
		local model = findModel(data.t)
		if model then
			local faceColor = FACE_COLORS[tostring(data.k)] or color
			Library.aura(model, faceColor, math.min(tonumber(data.d) or 10, 20), simpleAt(centre(model), model))
			Library.sparkle(model, faceColor, simpleAt(centre(model), model))
		end
	elseif v == "aim" then
		-- S76: everyone nearby sees the line (the target in PvP too: time to step away)
		local id = tostring(data.c)
		local old = aimLines[id]
		if old then
			old()
			aimLines[id] = nil
		end
		if caster then
			local stop = Library.aimLine(caster, findModel(data.t), at, AIM_COLOR, tonumber(data.d) or 1.5)
			aimLines[id] = stop
			Clock.after((tonumber(data.d) or 1.5) + 0.5, function()
				if aimLines[id] == stop then
					aimLines[id] = nil
				end
			end)
		end
	elseif v == "aimEnd" then
		local id = tostring(data.c)
		local stop = aimLines[id]
		if stop then
			stop()
			aimLines[id] = nil
		end
	elseif v == "furyConsume" then
		-- S74 (ROZWOJ 10.4): the Fury spent by Rend / Carnage
		local model = findModel(data.t) or caster
		if model then
			local far = simpleAt(centre(model), model)
			Library.aura(model, color, 0.6, far)
			-- S114 (E7): the more stacks spent, the bigger the core
			local stacks = math.clamp((tonumber(data.n) or 1) - 1, 0, 9)
			Library.burst(centre(model), 4 + stacks * 0.4, color, nil, far)
		end
	elseif v == "falconStrike" or v == "falconDive" then
		-- S77: the bird flies to the target and back (a dive starts high above it)
		local falcon = falconOf(casterKey(data), caster, color, simple, tonumber(data.d) or 4)
		if falcon then
			falcon.strike(findModel(data.t), v == "falconDive")
		else
			local target = findModel(data.t)
			if target then
				Library.burst(centre(target), 3, color, nil, simple)
			end
		end
	elseif v == "falconCircle" then
		falconOf(casterKey(data), caster, color, simple, tonumber(data.d) or 4)
	elseif v == "falconEnd" then
		local id = casterKey(data)
		local falcon = if id then falcons[id] else nil
		if id and falcon then
			falcons[id] = nil
			falcon.stop()
		end
	elseif not at then
		return
	elseif v == "angelSave" then
		-- S70: Guardian Angel saved this ally from death. S114: wings on the saved one, a stronger pillar, its own sound
		Library.burst(at, 6, HOLY, nil, simple)
		Library.pillar(at, 3, 16, HOLY, 0.9)
		local saved = findModel(data.t)
		if saved then
			Library.wings(saved, HOLY, 1.5, simple)
		end
		if Sfx.playable("skill.guardianAngel.save") and (not caster or caster:IsDescendantOf(Workspace)) then
			SfxController.Play("skill.guardianAngel.save", at, SfxController.WhoOf(caster), casterKey(data))
		end
	elseif v == "lightningBurst" then
		Library.lightning(at + Vector3.new(0, 28, 0), at, ELEMENT_COLORS.lightning, 0.5, simple)
		Library.shockwave(at, radius, ELEMENT_COLORS.lightning, 0.35, simple)
	elseif v == "meteorImpact" then
		Library.meteor(at, radius, 0.5, color, simple)
		shakeNear(at, 0.3)
	elseif v == "trapSet" then
		Library.rune(at, radius, color, math.min(tonumber(data.d) or 8, 30), simple, circleOf(skill, entry))
	elseif v == "trapTrigger" then
		local trigger = entry and entry.trigger
		if entry and trigger then
			-- S77: the trap's own pieces (Venom Snare's cloud, Snarefield's cracks)
			for _, name in trigger do
				piece(name, skill, entry, data, color, caster, nil, simple)
			end
		else
			Library.shockwave(at, radius, color, 0.5, simple)
			Library.burst(at, 6, color, nil, simple)
		end
	elseif v == "lingering" then
		Library.lingering(at, radius, tostring(data.k or "burn"), color, tonumber(data.d) or 3, simple)
	elseif v == "splitImpact" then
		Library.burst(at, 4, color, nil, simple)
		Library.shockwave(at, radius, color, 0.3, true)
	elseif v == "echo" then
		Library.shockwave(at, radius, color, 0.5, simple)
		Library.cracks(at, radius * 0.6, color, 0.9, true)
		shakeNear(at, 0.3)
	elseif v == "splash" then
		Library.shockwave(at, radius, color, 0.3, true)
	elseif v == "stunBurst" then
		Library.shockwave(at, radius, Color3.fromHex("#F2E85A"), 0.35, simple)
		Library.burst(at, 3, Color3.fromHex("#F2E85A"), nil, simple)
	elseif v == "pull" then
		Library.shockwave(at, radius, color, 0.35, simple)
		Library.rune(at, radius * 0.5, color, 0.5, true, circleOf(skill, entry))
		Library.dust(at, 1, simple) -- S80 (ROZWOJ 12.4): dust of the dragged enemies
	end
end

local function handle(data: { [string]: any })
	local skill = SkillData.get(data.s or "")
	if not skill then
		return
	end
	local caster = findModel(data.c)
	local v = data.v
	if v == "cast" then
		if caster then
			onCast(data, skill, caster)
		end
	elseif v == nil or v == skill.vfx then
		onImpact(data, skill, caster)
	else
		onExtra(data, skill, caster)
	end
end

-- Admin /skillpreview and the skill window preview (S28): the animation and the impact of a skill on a model,
-- without a server event (a self-centred impact for area skills, a point in front for the rest).
-- The def a preview plays. S56: the character's rank (base from the level, path skills from their node; a locked
-- skill previews at rank 1); always option A, no nodes (ROZWOJ 2.7)
local function previewDef(skill: SkillData.SkillDef): SkillData.SkillDef
	local rank = math.max(
		1,
		Paths.skillRank({
			class = State.Get({ "character", "class" }) or "",
			level = State.Get({ "character", "level" }) or 1,
			path = State.Get({ "character", "path" }),
			hotbar = State.Get({ "character", "hotbar" }),
			equipment = State.Get({ "character", "equipment" }),
		}, skill.id)
	)
	return (Skills.effective(skill, rank, nil, nil))
end

-- The loopUntil a preview's onCast hands AnimationController.Skill (beam / channel time, otherwise castTime).
local function previewLoop(skill: SkillData.SkillDef, def: SkillData.SkillDef): number?
	if skill.type == "beam" then
		return PREVIEW_BEAM_SECONDS
	elseif skill.type == "channel" then
		return PREVIEW_CHANNEL_SECONDS
	end
	return if (def.castTime or 0) > 0 then def.castTime else nil
end

-- AnimLab (S110): the loopUntil Preview plays the skill's motion with, for its control frames.
function VfxController.PreviewLoopUntil(skillId: string): number?
	local skill = SkillData.get(skillId)
	if not skill or skill.type == "passive" then
		return nil
	end
	return previewLoop(skill, previewDef(skill))
end

function VfxController.Preview(model: Model, skillId: string)
	local skill = SkillData.get(skillId)
	if not skill or skill.type == "passive" then
		return
	end
	local entity = model:GetAttribute("EntityId")
	local id = if type(entity) == "string" then entity else nil
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local front = if root then root.Position + root.CFrame.LookVector * math.min(skill.range or 10, 12) else nil
	local def = previewDef(skill)
	local loopUntil = previewLoop(skill, def)
	local motion = SkillMotions.get(skillId)
	-- S80: a beam loops its motion for 2 s with three rays from the weapon's tip to a point 10 studs ahead
	if skill.type == "beam" then
		onCast({ s = skillId, c = id, d = loopUntil }, skill, model)
		local entry = SkillVfx[skill.id]
		local color = colorOf(skill, entry, nil)
		for i = 1, 3 do
			Clock.after((i - 1) * 0.5 + (if motion then motion.hit or 0 else 0), function()
				local base = model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if base then
					local ahead = base.Position + base.CFrame.LookVector * 10
					Library.beam(weaponTip(model), ahead, color, BEAM_WIDTH + BEAM_WIDTH_STEP * (i - 1), 0.55)
				end
			end)
		end
		return
	end
	-- S77: an aimed skill loops its draw for castTime and lands after it
	local castTime = if (def.castTime or 0) > 0 then def.castTime else nil
	onCast({
		s = skillId,
		c = id,
		p = front,
		d = if skill.type == "channel" then loopUntil else nil,
		ct = castTime,
		w = def.hits, -- S114: the motion's variant for the previewed rank
	}, skill, model)
	local delay = if castTime
		then castTime
		elseif motion then math.min(motion.hit or motion.release or 0, SkillMotions.MAX_HIT)
		else 0
	Clock.after(delay, function()
		local data: { [string]: any } =
			{ s = skillId, c = id, r = def.radius, a = def.angle, l = def.length, w = def.width }
		if skill.type == "circleTarget" or skill.type == "trap" or skill.type == "healZone" then
			data.p = front
			data.d = def.delay
		elseif skill.type == "cone" or skill.type == "line" then
			data.cf = if root then root.CFrame else nil
		elseif skill.type == "circleSelf" or skill.type == "groupHeal" or skill.type == "groupBuff" then
			data.p = if root then root.Position else nil
		elseif skill.type == "blink" or skill.type == "charge" then
			data.from = if root then root.Position else nil
			data.p = front
		elseif skill.type == "buff" or skill.type == "shield" or skill.type == "hot" or skill.type == "channel" then
			data.t = id
			data.d = 2
		elseif skill.type == "guard" then
			data.t = id
			data.from = if root then root.Position else nil
			data.p = front
			data.d = 2
		elseif skill.type == "shout" then
			data.p = if root then root.Position else nil
			data.r = def.hitRadius or def.radius
			data.d = 2
		elseif skill.type == "banner" then
			data.p = front -- no object: the preview never plants one
			data.r = def.radius
		elseif skill.type == "companion" then
			data.t = id -- S77: the falcon circles over the model for a while
			data.d = 4
			if not id then
				-- the skills window's copy has no EntityId: one falcon under a preview key, the previous one leaves
				local previous = falcons[PREVIEW_FALCON]
				if previous then
					falcons[PREVIEW_FALCON] = nil
					previous.stop()
				end
				data.c = PREVIEW_FALCON
			end
		end
		onImpact(data, skill, model)
	end)
end

-- S74 War Banner objects: draw each banner model (also ones planted before we came or streamed in later) until it
-- leaves the folder.
local function watchBanner(model: Instance)
	if not model:IsA("Model") then
		return
	end
	task.spawn(function()
		local anchor = model:WaitForChild("Anchor", 5)
		if not anchor or not anchor:IsA("BasePart") or not model.Parent then
			return
		end
		local skillId = model:GetAttribute("SkillId")
		local skill = SkillData.get(if type(skillId) == "string" then skillId else "")
		local radius = tonumber(model:GetAttribute("Radius")) or 15
		local color = if skill then colorOf(skill, SkillVfx[skill.id], nil) else Color3.new(1, 1, 1)
		local stop = Library.banner(anchor, WeaponLooks.BANNER, radius, color, simpleAt(anchor.Position, nil))
		local connection: RBXScriptConnection
		connection = model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				connection:Disconnect()
				stop()
			end
		end)
		if not model.Parent then
			connection:Disconnect()
			stop()
		end
	end)
end

-- S80 (ROZWOJ 12.5, 14.4): Arcane Charge orbs around every character with charges (the "Effects" attribute); none far
-- away or on low graphics.
local orbits: { [Model]: { count: number, stop: () -> () } } = {}

local function refreshOrbit(model: Model)
	local count = EffectStack.stacksOf(model:GetAttribute("Effects"), "arcaneCharge", Workspace:GetServerTimeNow())
	if model.Parent == nil then
		count = 0
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if count > 0 and simpleAt(if root then root.Position else nil, model) then
		count = 0
	end
	local current = orbits[model]
	if current and current.count == count then
		return
	end
	if current then
		current.stop()
		orbits[model] = nil
	end
	if count > 0 then
		orbits[model] = { count = count, stop = Library.orbit(model, count, CHARGE_COLOR, false) }
	end
end

local function watchCharacter(model: Model)
	refreshOrbit(model)
	model:GetAttributeChangedSignal("Effects"):Connect(function()
		refreshOrbit(model)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			local current = orbits[model]
			if current then
				current.stop()
				orbits[model] = nil
			end
		end
	end)
end

local function watchPlayer(other: Player)
	if other.Character then
		watchCharacter(other.Character)
	end
	other.CharacterAdded:Connect(watchCharacter)
end

-- Hooked by CombatFxController (camera shake with the setting applied).
function VfxController.SetShake(fn: (strength: number) -> ())
	shakeCamera = fn
end

function VfxController.Init(registry)
	AnimationController = registry.Get("AnimationController")
	SfxController = registry.Get("SfxController")
end

function VfxController.Start()
	-- Admin /skillpreview <id> (S28): the skill on our own character.
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "skillpreview" and type(arg) == "string" and player.Character then
			VfxController.Preview(player.Character, arg)
		end
	end)
	-- S80: Arcane Charge orbs
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	task.spawn(function()
		local folder = Workspace:WaitForChild("Vaelthorn_Banners")
		folder.ChildAdded:Connect(watchBanner)
		for _, child in folder:GetChildren() do
			watchBanner(child)
		end
	end)
	Net.On("SkillFx", function(data: any)
		if type(data) == "table" then
			local ok, err = pcall(handle :: any, data)
			if not ok then
				warn(`[VfxController] {tostring(err)}`)
			end
		end
	end)
end

return VfxController
