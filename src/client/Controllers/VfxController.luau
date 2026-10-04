--!strict
-- Skill visuals (S05): placeholder effects built from neon parts, tweens and particles for every skill type,
-- coloured by element / class. The server sends "SkillFx" to players within 120 studs of the caster:
-- { s = skillId, v = vfx id, c = caster entity, t = target entity?, p = point?, cf = CFrame?, r = radius?,
--   a = angle?, l = length?, w = width?, d = duration?, n = hit index?, path = { entity ids }?, from = point? }
-- Real effects can replace these per vfx id later without touching the server.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Net = require(ReplicatedStorage.Shared.Net)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Sounds = require(script.Parent.Parent.UI.Sounds)

local VfxController = {
	Name = "VfxController",
}

local ELEMENT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#9FE0FF"),
	lightning = Color3.fromHex("#F2E85A"),
	poison = Color3.fromHex("#7ACB3A"),
}
local HOLY = Color3.fromHex("#FFE7A0")
local HEAL = Color3.fromHex("#4FD16B")

local folder: Folder

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

local function centre(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

local function part(size: Vector3, color: Color3, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = transparency or 0.2
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function fadeAway(p: BasePart, seconds: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(p, seconds + 0.05)
end

local function ring(at: Vector3, radius: number, color: Color3, seconds: number?)
	local disc = part(Vector3.new(0.3, 1, 1), color, Enum.PartType.Cylinder, 0.25)
	disc.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	fadeAway(disc, seconds or 0.45, Vector3.new(0.3, radius * 2, radius * 2))
end

local function burst(at: Vector3, size: number, color: Color3)
	local ball = part(Vector3.new(1, 1, 1), color, Enum.PartType.Ball, 0.15)
	ball.CFrame = CFrame.new(at)
	fadeAway(ball, 0.35, Vector3.new(size, size, size))
end

local function projectile(from: Vector3, to: Vector3, color: Color3, isArrow: boolean)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local p = if isArrow
		then part(Vector3.new(0.15, 0.15, 2.4), color)
		else part(Vector3.new(1.1, 1.1, 1.1), color, Enum.PartType.Ball, 0.1)
	p.CFrame = CFrame.lookAt(from, to)
	if not isArrow then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 10
		light.Parent = p
	end
	local seconds = math.clamp(distance / 90, 0.05, 0.6)
	TweenService
		:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) })
		:Play()
	Debris:AddItem(p, seconds + 0.05)
	task.delay(seconds, function()
		burst(to, 3, color)
	end)
end

local function beam(from: Vector3, to: Vector3, color: Color3, width: number?)
	local distance = (to - from).Magnitude
	local p = part(Vector3.new(width or 0.35, width or 0.35, distance), color, nil, 0.1)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	fadeAway(p, 0.3)
end

local function cone(origin: CFrame, radius: number, angle: number, color: Color3)
	local slices = 7
	local rad = math.rad(angle)
	for i = 0, slices - 1 do
		local yaw = -rad / 2 + rad * (i + 0.5) / slices
		local width = 2 * radius * math.tan(rad / slices / 2) + 0.2
		local slice = part(Vector3.new(width, 0.2, 0.2), color, nil, 0.3)
		local base = origin * CFrame.Angles(0, -yaw, 0)
		slice.CFrame = base * CFrame.new(0, -1.8, -1)
		TweenService:Create(slice, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(width, 0.2, radius),
			CFrame = base * CFrame.new(0, -1.8, -radius / 2),
			Transparency = 1,
		}):Play()
		Debris:AddItem(slice, 0.3)
	end
end

local function lineArea(origin: CFrame, length: number, width: number, color: Color3, seconds: number)
	local rect = part(Vector3.new(width, 0.3, length), color, nil, 0.35)
	rect.CFrame = origin * CFrame.new(0, -2.5, -length / 2)
	if seconds > 0.5 then
		-- Lasting area (Firewall): flickering wall.
		rect.Size = Vector3.new(width, 4, length)
		rect.CFrame = origin * CFrame.new(0, -0.5, -length / 2)
		local fire = Instance.new("ParticleEmitter")
		fire.Color = ColorSequence.new(color)
		fire.LightEmission = 1
		fire.Rate = 40
		fire.Lifetime = NumberRange.new(0.5, 1)
		fire.Speed = NumberRange.new(2, 5)
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		fire.Parent = rect
		task.delay(seconds, function()
			fire.Enabled = false
			fadeAway(rect, 0.4)
		end)
	else
		fadeAway(rect, 0.35)
	end
end

local function aura(model: Model, color: Color3, seconds: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local sphere = part(Vector3.new(7, 7, 7), color, Enum.PartType.Ball, 0.75)
	sphere.Anchored = false
	sphere.Massless = true
	sphere.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = sphere
	weld.Parent = sphere
	task.delay(math.max(0.3, seconds), function()
		if sphere.Parent then
			fadeAway(sphere, 0.3)
		end
	end)
end

local function sparkle(model: Model, color: Color3)
	local at = centre(model)
	for i = 1, 6 do
		local spark = part(Vector3.new(0.4, 0.4, 0.4), color, Enum.PartType.Ball, 0.1)
		local angle = i / 6 * math.pi * 2
		spark.CFrame = CFrame.new(at + Vector3.new(math.cos(angle) * 1.5, -1.5, math.sin(angle) * 1.5))
		TweenService:Create(spark, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = spark.CFrame + Vector3.new(0, 4, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(spark, 0.75)
	end
end

local function meteor(at: Vector3, radius: number, delay: number, color: Color3)
	local rock = part(Vector3.new(3, 3, 3), color, Enum.PartType.Ball, 0)
	rock.Material = Enum.Material.Basalt
	local start = at + Vector3.new(-18, 45, -10)
	rock.CFrame = CFrame.new(start)
	local fire = Instance.new("ParticleEmitter")
	fire.Color = ColorSequence.new(color)
	fire.LightEmission = 1
	fire.Rate = 60
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	fire.Parent = rock
	TweenService:Create(rock, TweenInfo.new(math.max(0.2, delay), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = CFrame.new(at),
	}):Play()
	Debris:AddItem(rock, delay + 0.05)
	task.delay(delay, function()
		ring(at, radius, color, 0.5)
		burst(at, radius, color)
	end)
end

-- Dispatcher --------------------------------------------------------------------------------------------------

local function skillColor(skill: SkillData.SkillDef): Color3
	if skill.element then
		return ELEMENT_COLORS[skill.element]
	end
	if skill.holy then
		return HOLY
	end
	local class = Classes.get(skill.class)
	return if class then Color3.fromHex(class.color) else Color3.new(1, 1, 1)
end

local function handle(data: { [string]: any })
	local skill = SkillData.get(data.s or "")
	if not skill then
		return
	end
	local color = skillColor(skill)
	local caster = findModel(data.c)
	local target = findModel(data.t)
	local vfx = data.v

	if vfx == "lightningBurst" then
		ring(data.p, data.r or 8, ELEMENT_COLORS.lightning, 0.35)
		return
	elseif vfx == "meteorImpact" then
		meteor(data.p, data.r or 5, 0.5, color)
		return
	elseif vfx == "trapTrigger" then
		ring(data.p, data.r or 6, ELEMENT_COLORS.ice, 0.6)
		burst(data.p, 6, ELEMENT_COLORS.ice)
		return
	end

	local kind = skill.type
	if kind == "target" or kind == "debuff" then
		if caster and target then
			beam(centre(caster), centre(target), color, 0.25)
			burst(centre(target), if kind == "target" then 5 else 3, color)
		end
	elseif kind == "projectile" then
		if caster and target then
			projectile(centre(caster) + Vector3.new(0, 0.8, 0), centre(target), color, skill.vfx == "arrow")
		end
	elseif kind == "charge" then
		if data.from and data.p then
			beam(data.from, data.p, color, 1.2)
		end
		if target then
			burst(centre(target), 5, color)
		end
	elseif kind == "cone" then
		if typeof(data.cf) == "CFrame" then
			cone(data.cf, data.r or 10, data.a or 90, color)
		end
	elseif kind == "circleSelf" then
		ring(data.p or (if caster then centre(caster) else Vector3.zero), data.r or 8, color)
	elseif kind == "circleTarget" then
		local delay = tonumber(data.d) or 0
		if skill.delay and skill.delay > 0 and (skill.hits or 1) == 1 then
			meteor(data.p, data.r or 8, skill.delay, color)
		elseif skill.hits and skill.hits > 1 and not skill.delay then
			for wave = 1, skill.hits do
				task.delay((wave - 1) * (skill.interval or 0.5), function()
					ring(data.p, data.r or 8, color, 0.35)
				end)
			end
		else
			ring(data.p, data.r or 8, color, math.max(0.4, delay))
		end
	elseif kind == "line" then
		if typeof(data.cf) == "CFrame" then
			lineArea(data.cf, data.l or 20, data.w or 4, color, tonumber(data.d) or 0)
		end
	elseif kind == "chain" then
		local path = data.path
		if type(path) == "table" then
			for i = 1, #path - 1 do
				local a, b = findModel(path[i]), findModel(path[i + 1])
				if a and b then
					beam(centre(a), centre(b), ELEMENT_COLORS.lightning, 0.3)
				end
			end
		end
	elseif kind == "blink" then
		if data.from then
			burst(data.from, 4, color)
		end
		if data.p then
			burst(data.p, 4, color)
		end
	elseif kind == "trap" then
		local disc = part(
			Vector3.new(0.2, (data.r or 6) * 2, (data.r or 6) * 2),
			ELEMENT_COLORS.ice,
			Enum.PartType.Cylinder,
			0.6
		)
		disc.CFrame = CFrame.new(data.p + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		Debris:AddItem(disc, tonumber(data.d) or 20)
	elseif kind == "buff" or kind == "channel" or kind == "shield" then
		local model = target or caster
		if model then
			aura(model, if kind == "shield" then HOLY else color, tonumber(data.d) or 1)
		end
	elseif kind == "heal" or kind == "hot" or kind == "resurrect" then
		local model = target or caster
		if model then
			sparkle(model, HEAL)
		end
	elseif kind == "groupHeal" or kind == "groupBuff" then
		ring(
			data.p or (if caster then centre(caster) else Vector3.zero),
			data.r or 14,
			if kind == "groupHeal" then HEAL else HOLY
		)
	end
	if caster == Players.LocalPlayer.Character then
		Sounds.play("click")
	end
end

function VfxController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_SkillFx"
	folder.Parent = Workspace
end

function VfxController.Start()
	Net.On("SkillFx", function(data: any)
		if type(data) == "table" then
			local ok = pcall(handle, data)
			if not ok then
				return
			end
		end
	end)
end

return VfxController
