--!strict
-- Skill visuals (S05, rebuilt in S28). The server sends "SkillFx" to players within 120 studs of the caster:
--   v = "cast"  when the skill starts: every client plays the caster's animation (Data/SkillMotions) and the cast
--               pieces (weapon trail, glowing hands); the local caster also holds still for `lock` motions
--   no `v`      the impact (after the motion's hit time): pieces from Data/SkillVfx sized by the event
--               { s, c, t?, p?, cf?, r?, a?, l?, w?, d?, n?, path?, from? }
--   v = arc / lightningBurst / meteorImpact / trapSet / trapTrigger / lingering / pierce / splitImpact / echo /
--       splash / stunBurst / pull / fizzle  — extras of adaptive skills and breakpoints
-- Pieces come from client/Vfx/Library (pooled parts, Config.Vfx.maxActive at once); effects of other players far
-- away and low graphics quality use the simple versions. Melee impacts freeze both animations for a moment
-- (hitstop) and big skills shake the camera of players nearby (setting "Camera shake").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Parent.Vfx.Library)
local Net = require(ReplicatedStorage.Shared.Net)
local Pool = require(script.Parent.Parent.Vfx.Pool)
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

-- Camera shake handler (CombatFxController.Shake), set in Init.
local shakeCamera: ((strength: number) -> ())? = nil
-- Local movement lock while our own `lock` motion plays (released by the motion's end).
local lockToken = 0

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

local function onCast(data: { [string]: any }, skill: SkillData.SkillDef, caster: Model)
	local entry = SkillVfx[skill.id]
	local color = colorOf(skill, entry, data.el)
	local loopUntil = if skill.type == "channel" then tonumber(data.d) else nil
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
		-- Projectile skills: the shot leaves the hand at the motion's release.
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
	end
	-- Our own motion that holds the character still (unless a breakpoint lets it move).
	if caster == player.Character and motion and motion.lock then
		local move = tonumber(data.mv)
		local humanoid = caster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			lockToken += 1
			local token = lockToken
			local speed = humanoid.WalkSpeed
			humanoid.WalkSpeed = if move then speed * move / 100 else 0
			local seconds = (motion.keys[#motion.keys].t + motion.recover * 0.5)
				+ (if loopUntil and motion.loop then math.max(0, loopUntil - motion.loop.to) else 0)
			task.delay(seconds, function()
				if lockToken == token and humanoid.Parent then
					humanoid.WalkSpeed = speed
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
	-- Projectiles fly to the target; the pieces play on arrival.
	if kind == "projectile" and caster and target then
		local from = centre(caster) + Vector3.new(0, 0.8, 0)
		Library.projectile(from, target, entry.projectile or "orb", color, {
			size = entry.size,
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
	-- Circle waves of the same cast: only the first plays the full set (later waves: the ring).
	local wave = tonumber(data.n) or 1
	for _, name in entry.impact do
		if wave == 1 or name == "shockwave" or name == "whirl" or name == "cracks" or name == "pillar" then
			piece(name, skill, entry, data, color, caster, target, simple)
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
	if v == "fizzle" then
		if caster then
			AnimationController.StopSkill(caster)
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
	elseif not at then
		return
	elseif v == "lightningBurst" then
		Library.lightning(at + Vector3.new(0, 28, 0), at, ELEMENT_COLORS.lightning, 0.5, simple)
		Library.shockwave(at, radius, ELEMENT_COLORS.lightning, 0.35, simple)
	elseif v == "meteorImpact" then
		Library.meteor(at, radius, 0.5, color, simple)
		shakeNear(at, 0.3)
	elseif v == "trapSet" then
		Library.rune(at, radius, color, math.min(tonumber(data.d) or 8, 30), simple)
	elseif v == "trapTrigger" then
		Library.shockwave(at, radius, color, 0.5, simple)
		Library.burst(at, 6, color)
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
	local level = State.Get({ "character", "skills", skillId }) or 1
	local def = Skills.effective(skill, level)
	local motion = SkillMotions.get(skillId)
	onCast({ s = skillId, c = id, p = front, d = if skill.type == "channel" then 2.5 else nil }, skill, model)
	local delay = if motion then math.min(motion.hit or motion.release or 0, SkillMotions.MAX_HIT) else 0
	task.delay(delay, function()
		local data: { [string]: any } =
			{ s = skillId, c = id, r = def.radius, a = def.angle, l = def.length, w = def.width }
		if skill.type == "circleTarget" or skill.type == "trap" then
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
		end
		onImpact(data, skill, model)
	end)
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
