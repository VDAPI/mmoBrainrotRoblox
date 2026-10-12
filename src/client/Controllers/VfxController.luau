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
-- away and low graphics quality use the simple versions. Melee impacts freeze both animations for a moment
-- (hitstop) and big skills shake the camera of players nearby (setting "Camera shake").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Library = require(script.Parent.Parent.Vfx.Library)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local WeaponLooks = require(ReplicatedStorage.Shared.Data.WeaponLooks)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillMotions = require(ReplicatedStorage.Shared.Data.SkillMotions)
local SkillVfx = require(ReplicatedStorage.Shared.Data.SkillVfx)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)

local VfxController = {
	Name = "VfxController",
	Deps = { "AnimationController" },
}

local AnimationController: any
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
local CHARGE_COLOR = Color3.fromHex("#B07CFF")

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

local function playSound(entry: SkillVfx.Entry?, caster: Model?)
	if entry and entry.sound ~= "" then
		Sounds.playId(entry.sound)
	elseif caster == player.Character then
		Sounds.play("click")
	end
end

-- Cast ---------------------------------------------------------------------------------------------------------

local function casterKey(data: { [string]: any }): string?
	return if type(data.c) == "string" then data.c else nil
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
	local motion = AnimationController.Skill(caster, skill.id, loopUntil)
	local simple = simpleAt(centre(caster), caster)
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
			task.delay(motion.land, function()
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
			task.delay(release, function()
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
			task.delay(release, function()
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

local function piece(
	name: string,
	skill: SkillData.SkillDef,
	entry: SkillVfx.Entry,
	data: { [string]: any },
	color: Color3,
	caster: Model?,
	target: Model?,
	simple: boolean
)
	local at = impactPoint(data, caster, target)
	local scale = entry.size or 1
	local radius = tonumber(data.r) or skill.radius or (6 * scale)
	local seconds = tonumber(data.d) or 1
	if name == "burst" then
		if at then
			Library.burst(at, 5 * scale, color)
		end
	elseif name == "shockwave" then
		if at then
			Library.shockwave(at, radius, color, 0.45, simple)
		end
	elseif name == "cracks" then
		if at and not simple then
			Library.cracks(at, math.max(3, radius * 0.8 * (if data.r then 1 else scale)), color, 1.4, simple)
		end
	elseif name == "dust" then
		if at then
			Library.dust(at, scale, simple)
		end
	elseif name == "pillar" then
		local where = if target then centre(target) else at
		if where then
			Library.pillar(where, 1.5 * scale, 14 * scale, color, 0.7)
		end
	elseif name == "sparkle" then
		local model = target or caster
		if model then
			Library.sparkle(model, color, simple)
		end
	elseif name == "aura" then
		local model = target or caster
		if model then
			Library.aura(model, color, seconds, simple)
		end
	elseif name == "shield" then
		local model = target or caster
		if model then
			Library.shield(model, color, seconds)
		end
	elseif name == "beam" then
		if caster and target and caster ~= target then
			Library.beam(centre(caster), centre(target), color, 0.35, 0.35)
		end
	elseif name == "dash" then
		if typeof(data.from) == "Vector3" then
			local to = if typeof(data.p) == "Vector3" then data.p else at
			if to then
				Library.dash(data.from, to, color, simple)
			end
		end
	elseif name == "rune" then
		local where = at or (if caster then centre(caster) else nil)
		if where then
			Library.rune(where, radius, color, math.max(0.8, seconds), simple)
		end
	elseif name == "slash" or name == "whirl" then
		local frame = facing(caster, target, data)
		if frame then
			local spec = entry.slash
			if name == "whirl" then
				Library.slash(frame, radius, 180, -180, color, 0, simple)
			else
				local angle = tonumber(data.a)
				local half = if angle then angle / 2 else nil
				local from = if half then half else (spec and spec.from or 60)
				local to = if half then -half else (spec and spec.to or -60)
				Library.slash(frame, (spec and spec.radius) or radius, from, to, color, spec and spec.tilt, simple)
			end
		end
	elseif name == "arrowRain" then
		if at then
			local waves = skill.hits or 1
			local random = Random.new()
			for wave = 1, waves do
				task.delay((wave - 1) * (skill.interval or 0.5), function()
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
				local from = frame.Position + Vector3.new(0, 1, 0)
				task.delay(i * 0.04, function()
					Library.projectile(from, from + dir * radius, "arrow", color, { speed = 110, simple = simple })
				end)
			end
		end
	elseif name == "lineBeam" then
		if typeof(data.cf) == "CFrame" then
			local length = tonumber(data.l) or skill.length or 20
			local from = data.cf.Position + Vector3.new(0, 1, 0)
			local to = from + data.cf.LookVector * length
			Library.beam(from, to, color, math.max(0.6, (tonumber(data.w) or 4) * 0.3), 0.45)
			Library.projectile(from, to, "arrow", color, { speed = 160, size = 1.6, simple = simple })
		end
	elseif name == "skyBolt" then
		local where = if target then centre(target) else at
		if where then
			Library.lightning(where + Vector3.new(0, 30, 0), where, color, 0.5, simple)
			Library.burst(where, 4, color)
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
			Library.tether(caster, target, color, seconds)
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
				playSound(entry, caster)
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
		playSound(entry, caster)
		return
	end
	if kind == "chain" then
		local path = data.path
		if type(path) == "table" then
			for i = 1, #path - 1 do
				local a, b = findModel(path[i]), findModel(path[i + 1])
				if a and b then
					task.delay((i - 1) * 0.06, function()
						Library.lightning(centre(a), centre(b), color, 0.3, simple)
						Library.burst(centre(b), 3, color)
					end)
				end
			end
		end
		playSound(entry, caster)
		return
	end
	-- Circle waves of the same cast: only the first plays the full set (later waves: the ring). S77: `n` of a trap
	-- is the snare's index (S76), so every snare plays the full set.
	local wave = if kind == "trap" then 1 else tonumber(data.n) or 1
	local everyWave = entry.everyWave -- S80: the entry's own pieces of later waves
	for _, name in entry.impact do
		local again = if everyWave
			then table.find(everyWave, name) ~= nil
			else name == "shockwave" or name == "whirl" or name == "cracks" or name == "pillar"
		if wave == 1 or again then
			piece(name, skill, entry, data, color, caster, target, simple)
		end
	end
	-- S74: pieces on the allies the skill covered (guard, shout)
	local allies = entry.allies
	if allies and wave == 1 and type(data.al) == "table" then
		local allyColor = if entry.allyColor then Color3.fromHex(entry.allyColor) else color
		for _, id in data.al do
			local model = findModel(id)
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
	-- Hitstop on melee blows and camera shake for big ones.
	if entry.hitstop and caster then
		AnimationController.Hitstop(caster, entry.hitstop)
		if target then
			AnimationController.Hitstop(target, entry.hitstop)
		end
	end
	shakeNear(at, entry.shake)
	if wave == 1 then
		playSound(entry, caster)
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
			task.delay((tonumber(data.d) or 1.5) + 0.5, function()
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
			Library.aura(model, color, 0.6, simpleAt(centre(model), model))
			Library.burst(centre(model), 4, color)
		end
	elseif v == "falconStrike" or v == "falconDive" then
		-- S77: the bird flies to the target and back (a dive starts high above it)
		local falcon = falconOf(casterKey(data), caster, color, simple, tonumber(data.d) or 4)
		if falcon then
			falcon.strike(findModel(data.t), v == "falconDive")
		else
			local target = findModel(data.t)
			if target then
				Library.burst(centre(target), 3, color)
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
		-- S70: Guardian Angel saved this ally from death
		Library.burst(at, 6, HOLY)
		Library.pillar(at, 3, 12, HOLY, 0.8)
	elseif v == "lightningBurst" then
		Library.lightning(at + Vector3.new(0, 28, 0), at, ELEMENT_COLORS.lightning, 0.5, simple)
		Library.shockwave(at, radius, ELEMENT_COLORS.lightning, 0.35, simple)
	elseif v == "meteorImpact" then
		Library.meteor(at, radius, 0.5, color, simple)
		shakeNear(at, 0.3)
	elseif v == "trapSet" then
		Library.rune(at, radius, color, math.min(tonumber(data.d) or 8, 30), simple)
	elseif v == "trapTrigger" then
		local trigger = entry and entry.trigger
		if entry and trigger then
			-- S77: the trap's own pieces (Venom Snare's cloud, Snarefield's cracks)
			for _, name in trigger do
				piece(name, skill, entry, data, color, caster, nil, simple)
			end
		else
			Library.shockwave(at, radius, color, 0.5, simple)
			Library.burst(at, 6, color)
		end
	elseif v == "lingering" then
		Library.lingering(at, radius, tostring(data.k or "burn"), color, tonumber(data.d) or 3, simple)
	elseif v == "splitImpact" then
		Library.burst(at, 4, color)
		Library.shockwave(at, radius, color, 0.3, true)
	elseif v == "echo" then
		Library.shockwave(at, radius, color, 0.5, simple)
		Library.cracks(at, radius * 0.6, color, 0.9, true)
		shakeNear(at, 0.3)
	elseif v == "splash" then
		Library.shockwave(at, radius, color, 0.3, true)
	elseif v == "stunBurst" then
		Library.shockwave(at, radius, Color3.fromHex("#F2E85A"), 0.35, simple)
		Library.burst(at, 3, Color3.fromHex("#F2E85A"))
	elseif v == "pull" then
		Library.shockwave(at, radius, color, 0.35, simple)
		Library.rune(at, radius * 0.5, color, 0.5, true)
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
function VfxController.Preview(model: Model, skillId: string)
	local skill = SkillData.get(skillId)
	if not skill or skill.type == "passive" then
		return
	end
	local entity = model:GetAttribute("EntityId")
	local id = if type(entity) == "string" then entity else nil
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local front = if root then root.Position + root.CFrame.LookVector * math.min(skill.range or 10, 12) else nil
	-- S56: the character's rank (base from the level, path skills from their node; a locked skill previews at rank 1);
	-- always option A, no nodes (ROZWOJ 2.7)
	local rank = math.max(
		1,
		Paths.skillRank({
			class = State.Get({ "character", "class" }) or "",
			level = State.Get({ "character", "level" }) or 1,
			path = State.Get({ "character", "path" }),
			hotbar = State.Get({ "character", "hotbar" }),
			equipment = State.Get({ "character", "equipment" }),
		}, skillId)
	)
	local def = Skills.effective(skill, rank, nil, nil)
	local motion = SkillMotions.get(skillId)
	-- S80: a beam loops its motion for 2 s with three rays from the weapon's tip to a point 10 studs ahead
	if skill.type == "beam" then
		onCast({ s = skillId, c = id, d = 2 }, skill, model)
		local entry = SkillVfx[skill.id]
		local color = colorOf(skill, entry, nil)
		for i = 1, 3 do
			task.delay((i - 1) * 0.5 + (if motion then motion.hit or 0 else 0), function()
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
	onCast(
		{ s = skillId, c = id, p = front, d = if skill.type == "channel" then 2.5 else nil, ct = castTime },
		skill,
		model
	)
	local delay = if castTime
		then castTime
		elseif motion then math.min(motion.hit or motion.release or 0, SkillMotions.MAX_HIT)
		else 0
	task.delay(delay, function()
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
