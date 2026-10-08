--!strict
-- Life of the starting city on the client (S21, docs/miasto/MIASTO.md §5 "Tagi części"). Works on every part
-- with the CollectionService tag "TownFx" (BlueprintBuild), from the server shell or the client detail, by its
-- "Fx" attribute and its Build name ("Build" attribute):
--   * flag: slow swing (±6°) around the top edge, phase from the position, within 150 studs;
--   * wheel + wheelAxle, sail + sailAxle: turning around the local X axis of the axle of the same Build
--     (the mill wheel ~20°/s, the windmill sails ~25°/s; the sails are split between shell and fine models);
--   * smoke: a slow grey smoke emitter on chimney tops; fire: flames, and flickering of the fire lights;
--   * water: the fountain's small jets and a gentle shimmer;
--   * waterfall (S26): streaks of falling water down the sheet and a shimmer; foam: mist rising from the pool and
--     splashes; candle: nothing extra (its light flickers with the "fire" lights), S45: a tiny flame when coloured;
--   * S45: the part attribute FxColor (Color3) colours the flames of "fire" and "candle" and the night glow of
--     "lamp" (violet ritual fire, cold blue flames and lanterns, green witch light); bubbles: bubbles rising and
--     popping on rot pools and cauldrons (in the FxColor);
--   * S46 (Ashen Wastes): lava (the Neon plates pulse between dark and bright orange, a rare bubble bursts in
--     sparks), lavaCrust (dark floes drifting with the flow), lavafall (falling drops, sparks), ember (flickering
--     coal, rare sparks), vent (heat shimmer, sparks and smoke: fumaroles, the crater), forge (flicker and bursts of
--     sparks), glow (slow "breathing" brightness of the part and of its lights: the Colossus' eyes, runes, the
--     pyramid's entrance); lava lights are switched by Controllers/RegionLightController;
--   * window / lamp: at night (Logic/DayCycle) ~60% of the windows glow warm (chosen by position) and lamps turn
--     to Neon with their PointLights on; by day both go back to their own colour and material and lamp lights
--     are off. Switching runs over several frames.
-- Parts are anchored: all motion is a local CFrame from the remembered base, nothing is replicated.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local DayCycle = require(ReplicatedStorage.Shared.Logic.DayCycle)

local TownFxController = {
	Name = "TownFxController",
	Deps = { "WorldController" },
}

local WorldController: any

local FLAG_RADIUS = 150
local FLAG_SWING = math.rad(6)
local SPIN_RADIUS = 400
local SPIN_SPEED = { wheel = math.rad(20), sail = math.rad(25) }
local NIGHT_PER_FRAME = 150
local WINDOW_GLOW = Color3.fromHex("#FFC46E")
local LAMP_DAY = Color3.fromHex("#5A4E3A")

type Original = { color: Color3, material: Enum.Material }

local flags: { [BasePart]: { base: CFrame, phase: number } } = {}
-- Rotating groups by Build name and kind ("wheel" / "sail"): axle base frame and member offsets from it.
type Spinner = { axle: BasePart?, axleBase: CFrame?, members: { [BasePart]: { base: CFrame, offset: CFrame? } } }
local spinners: { [string]: Spinner } = {}
local flickers: { [PointLight]: { base: number, phase: number } } = {}
local shimmers: { [BasePart]: number } = {}
local nightParts: { [BasePart]: string } = {} -- window / lamp parts
local lampLights: { [BasePart]: boolean } = {} -- "Light" holders with Fx = lamp
local originals: { [BasePart]: Original } = {}
local nightApplied: { [Instance]: boolean } = {}
local nightQueue: { Instance } = {}
local isNight = false
-- S46: pulsing lava, drifting crust, breathing glows, the forges' bursts of sparks
local LAVA_RADIUS = 260
local LAVA_DARK = Color3.fromHex("#FF5A1A")
local LAVA_BRIGHT = Color3.fromHex("#FFB040")
local pulses: { [BasePart]: number } = {}
local crusts: { [BasePart]: { base: CFrame, phase: number } } = {}
local breathers: { [BasePart]: { color: Color3, phase: number } } = {}
local breathLights: { [PointLight]: { base: number, phase: number } } = {}
local forges: { [ParticleEmitter]: number } = {}
local slowClock = 0

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function addSmoke(part: BasePart)
	if part:FindFirstChild("TownSmoke") then
		return
	end
	local e = emitter(part, {
		Name = "TownSmoke",
		Color = ColorSequence.new(Color3.fromHex("#8A8A8A"), Color3.fromHex("#BDBDBD")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(1, 4),
		Lifetime = NumberRange.new(6, 9),
		Rate = 1.5,
		Speed = NumberRange.new(1.5, 2.5),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0.6, 0.15, 0.3), -- light wind
		RotSpeed = NumberRange.new(-15, 15),
		Rotation = NumberRange.new(0, 360),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	e.Enabled = true
end

-- S45: the colour a part asks for (attribute FxColor), or nil.
local function fxColor(part: BasePart): Color3?
	local c = part:GetAttribute("FxColor")
	return if typeof(c) == "Color3" then c else nil
end

-- Flame colours: the warm default, or a lighter core fading into the FxColor.
local function flameColors(part: BasePart): ColorSequence
	local c = fxColor(part)
	if c then
		return ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.45), c)
	end
	return ColorSequence.new(Color3.fromHex("#FFD27A"), Color3.fromHex("#FF5A1A"))
end

local function addFire(part: BasePart)
	if part:FindFirstChild("TownFire") then
		return
	end
	emitter(part, {
		Name = "TownFire",
		Color = flameColors(part),
		Transparency = NumberSequence.new(0.2, 1),
		Size = NumberSequence.new(0.9, 0.1),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 14,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		LightEmission = 1,
		LightInfluence = 0,
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- S45: a tiny flame over a coloured candle.
local function addCandle(part: BasePart)
	if part:FindFirstChild("TownCandle") or not fxColor(part) then
		return
	end
	emitter(part, {
		Name = "TownCandle",
		Color = flameColors(part),
		Transparency = NumberSequence.new(0.1, 1),
		Size = NumberSequence.new(0.25, 0.05),
		Lifetime = NumberRange.new(0.3, 0.5),
		Rate = 8,
		Speed = NumberRange.new(0.8, 1.4),
		SpreadAngle = Vector2.new(5, 5),
		LightEmission = 1,
		LightInfluence = 0,
		EmissionDirection = Enum.NormalId.Top,
	})
end

-- S45: bubbles rising from a rot pool or a cauldron and popping at the surface.
local function addBubbles(part: BasePart)
	if part:FindFirstChild("TownBubbles") then
		return
	end
	local c = fxColor(part) or Color3.fromHex("#8A9A5A")
	emitter(part, {
		Name = "TownBubbles",
		Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.3), c),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.85, 0.6),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
		Lifetime = NumberRange.new(0.6, 1.2),
		Rate = 3,
		Speed = NumberRange.new(0.6, 1.2),
		SpreadAngle = Vector2.new(60, 60),
		LightInfluence = 0.6,
		EmissionDirection = Enum.NormalId.Top,
	})
end

local function addWater(part: BasePart)
	if part:FindFirstChild("TownWater") then
		return
	end
	emitter(part, {
		Name = "TownWater",
		Color = ColorSequence.new(Color3.fromHex("#CFE8FF")),
		Transparency = NumberSequence.new(0.3, 1),
		Size = NumberSequence.new(0.35, 0.15),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 22,
		Speed = NumberRange.new(5, 7),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, -24, 0),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	shimmers[part] = part.Transparency
end

local function addWaterfall(part: BasePart)
	if part:FindFirstChild("TownFall") then
		return
	end
	emitter(part, {
		Name = "TownFall",
		Color = ColorSequence.new(Color3.fromHex("#E8F4FA"), Color3.fromHex("#B8D8EA")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.7, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(1.4, 2.6),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 34,
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, -60, 0),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Bottom,
	})
	shimmers[part] = part.Transparency
end

local function addFoam(part: BasePart)
	if part:FindFirstChild("TownMist") then
		return
	end
	emitter(part, {
		Name = "TownMist",
		Color = ColorSequence.new(Color3.fromHex("#F2F7FA")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(4, 10),
		Lifetime = NumberRange.new(3, 5),
		Rate = 5,
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(40, 40),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-10, 10),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	emitter(part, {
		Name = "TownSplash",
		Color = ColorSequence.new(Color3.fromHex("#FFFFFF")),
		Transparency = NumberSequence.new(0.2, 1),
		Size = NumberSequence.new(0.5, 0.2),
		Lifetime = NumberRange.new(0.4, 0.8),
		Rate = 26,
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -36, 0),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
	shimmers[part] = part.Transparency
end

-- S46 effects -----------------------------------------------------------------------------------------------------

local function phaseOf(part: BasePart): number
	local p = part.Position
	return (p.X * 0.11 + p.Z * 0.07) % (math.pi * 2)
end

local function sparks(part: BasePart, name: string, rate: number, speed: number): ParticleEmitter
	return emitter(part, {
		Name = name,
		Color = ColorSequence.new(Color3.fromHex("#FFE08A"), Color3.fromHex("#FF5A1A")),
		Transparency = NumberSequence.new(0, 1),
		Size = NumberSequence.new(0.22, 0.05),
		Lifetime = NumberRange.new(0.6, 1.4),
		Rate = rate,
		Speed = NumberRange.new(speed * 0.6, speed),
		SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, -6, 0),
		LightEmission = 1,
		LightInfluence = 0,
		EmissionDirection = Enum.NormalId.Top,
	})
end

local function haze(part: BasePart, rate: number)
	emitter(part, {
		Name = "TownHaze",
		Color = ColorSequence.new(Color3.fromHex("#FFD8B0")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.94),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(3, 7),
		Lifetime = NumberRange.new(2, 3.5),
		Rate = rate,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
		LightInfluence = 0.3,
		EmissionDirection = Enum.NormalId.Top,
	})
end

local function addLava(part: BasePart)
	if pulses[part] then
		return
	end
	pulses[part] = phaseOf(part)
	if part.Size.X * part.Size.Z > 40 and not part:FindFirstChild("LavaPop") then
		-- a rare bubble bursting in sparks
		sparks(part, "LavaPop", 0.25, 9)
	end
end

local function addLavafall(part: BasePart)
	if part:FindFirstChild("TownLavaFall") then
		return
	end
	emitter(part, {
		Name = "TownLavaFall",
		Color = ColorSequence.new(LAVA_BRIGHT, LAVA_DARK),
		Transparency = NumberSequence.new(0.1, 0.8),
		Size = NumberSequence.new(1.2, 0.6),
		Lifetime = NumberRange.new(0.6, 1),
		Rate = 26,
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, -50, 0),
		LightEmission = 1,
		LightInfluence = 0,
		EmissionDirection = Enum.NormalId.Bottom,
	})
	sparks(part, "LavaSparks", 6, 12)
	pulses[part] = phaseOf(part)
end

local function addEmber(part: BasePart)
	if part:FindFirstChild("EmberSparks") then
		return
	end
	sparks(part, "EmberSparks", 0.6, 4)
	pulses[part] = phaseOf(part)
end

local function addVent(part: BasePart)
	if part:FindFirstChild("TownHaze") then
		return
	end
	haze(part, 3)
	sparks(part, "VentSparks", 4, 10)
	addSmoke(part)
	pulses[part] = phaseOf(part)
end

local function addForge(part: BasePart)
	if part:FindFirstChild("ForgeSparks") then
		return
	end
	local e = sparks(part, "ForgeSparks", 0, 14)
	forges[e] = 0
	breathers[part] = { color = part.Color, phase = phaseOf(part) }
end

local function addGlow(part: BasePart)
	if part.Name == "Light" then
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			breathLights[light] = { base = light.Brightness, phase = phaseOf(part) }
		end
		return
	end
	breathers[part] = { color = part.Color, phase = phaseOf(part) }
end

-- Lava pulses, crust drifts, glows breathe (15 times a second, near the camera).
local function animateLava(now: number, at: Vector3)
	for part, phase in pulses do
		if (part.Position - at).Magnitude < LAVA_RADIUS then
			local k = 0.5 + 0.5 * math.sin(now * 0.9 + phase)
			part.Color = LAVA_DARK:Lerp(LAVA_BRIGHT, math.clamp(k * 0.8 + 0.2 * math.noise(now * 0.7, phase), 0, 1))
		end
	end
	for part, crust in crusts do
		if (crust.base.Position - at).Magnitude < LAVA_RADIUS then
			local off = ((now * 0.7 + crust.phase * 3) % 8) - 4
			part.CFrame = crust.base * CFrame.new(0, 0, off)
		end
	end
	for part, b in breathers do
		if (part.Position - at).Magnitude < LAVA_RADIUS * 2 then
			local k = 0.55 + 0.45 * math.sin(now * 0.8 + b.phase)
			part.Color = b.color:Lerp(Color3.new(0, 0, 0), (1 - k) * 0.6)
		end
	end
	for light, b in breathLights do
		light.Brightness = b.base * (0.5 + 0.5 * math.sin(now * 0.8 + b.phase))
	end
	for e, nextAt in forges do
		if not e.Parent then
			forges[e] = nil
		elseif now >= nextAt then
			e:Emit(12)
			forges[e] = now + 1.5 + (math.noise(now, 0.3) + 0.5) * 2.5
		end
	end
end

local function spinnerKey(build: string, kind: string): string
	return `{kind}:{build}`
end

local function spinner(key: string): Spinner
	local s = spinners[key]
	if not s then
		s = { axle = nil, axleBase = nil, members = {} }
		spinners[key] = s
	end
	return s :: Spinner
end

-- Windows keep their own look by day and ~60% of them glow at night. Lamp glass is Neon in the plan: by day it
-- is dimmed to plain glass, at night it gets its own colour back.
local function setNightLook(part: BasePart, kind: string, night: boolean)
	local original = originals[part]
	if not original then
		original = { color = part.Color, material = part.Material }
		originals[part] = original
	end
	assert(original, "original")
	if kind == "lamp" then
		local glow = fxColor(part) or original.color
		part.Color = if night then glow else original.color:Lerp(LAMP_DAY, 0.6)
		part.Material = if night then original.material else Enum.Material.Glass
		return
	end
	local p = part.Position
	if night and DayCycle.windowLit(p.X, p.Y, p.Z) then
		part.Color = WINDOW_GLOW
		part.Material = Enum.Material.Neon
	else
		part.Color = original.color
		part.Material = original.material
	end
end

local function setLampLight(holder: BasePart, night: boolean)
	local light = holder:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = night
	end
end

local function applyNight(instance: Instance)
	if not instance.Parent then
		return
	end
	if instance:IsA("BasePart") then
		local kind = nightParts[instance]
		if kind then
			setNightLook(instance, kind, isNight)
		elseif lampLights[instance] then
			setLampLight(instance, isNight)
		end
	end
	nightApplied[instance] = isNight
end

local function onAdded(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance
	local fx = part:GetAttribute("Fx")
	local build = part:GetAttribute("Build")
	if type(fx) ~= "string" then
		return
	end
	local buildName = if type(build) == "string" then build else ""
	if fx == "flag" then
		local p = part.Position
		flags[part] = { base = part.CFrame, phase = (p.X * 0.37 + p.Z * 0.23) % (math.pi * 2) }
	elseif fx == "wheel" or fx == "sail" then
		spinner(spinnerKey(buildName, fx)).members[part] = { base = part.CFrame, offset = nil }
	elseif fx == "wheelAxle" or fx == "sailAxle" then
		local s = spinner(spinnerKey(buildName, if fx == "wheelAxle" then "wheel" else "sail"))
		s.axle = part
		s.axleBase = part.CFrame
		for _, member in s.members do
			member.offset = nil
		end
	elseif fx == "smoke" then
		addSmoke(part)
	elseif fx == "fire" then
		if part.Name == "Light" then
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				local p = part.Position
				flickers[light] = { base = light.Brightness, phase = (p.X + p.Z) * 0.13 }
			end
		else
			addFire(part)
		end
	elseif fx == "water" then
		addWater(part)
	elseif fx == "waterfall" then
		addWaterfall(part)
	elseif fx == "foam" then
		addFoam(part)
	elseif fx == "candle" then
		addCandle(part)
	elseif fx == "bubbles" then
		addBubbles(part)
	elseif fx == "lava" then
		if part.Name ~= "Light" then
			addLava(part)
		end
	elseif fx == "lavaCrust" then
		crusts[part] = { base = part.CFrame, phase = phaseOf(part) }
	elseif fx == "lavafall" then
		addLavafall(part)
	elseif fx == "ember" then
		addEmber(part)
	elseif fx == "vent" then
		addVent(part)
	elseif fx == "forge" then
		addForge(part)
	elseif fx == "glow" then
		addGlow(part)
	elseif fx == "window" then
		nightParts[part] = "window"
		applyNight(part)
	elseif fx == "lamp" then
		if part.Name == "Light" then
			lampLights[part] = true
		else
			nightParts[part] = "lamp"
		end
		applyNight(part)
	end
end

local function onRemoved(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance
	flags[part] = nil
	shimmers[part] = nil
	pulses[part] = nil
	crusts[part] = nil
	breathers[part] = nil
	nightParts[part] = nil
	lampLights[part] = nil
	originals[part] = nil
	nightApplied[part] = nil
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		flickers[light] = nil
		breathLights[light] = nil
	end
	for key, s in spinners do
		s.members[part] = nil
		if s.axle == part then
			s.axle = nil
			s.axleBase = nil
		end
		if not s.axle and next(s.members) == nil then
			spinners[key] = nil
		end
	end
end

local function focus(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera then camera.Focus.Position else Vector3.zero
end

local function animate(now: number)
	local at = focus()
	for part, flag in flags do
		local base = flag.base
		if (base.Position - at).Magnitude > FLAG_RADIUS then
			continue
		end
		local top = base * CFrame.new(0, part.Size.Y / 2, 0)
		local angle = math.sin(now * 0.9 + flag.phase) * FLAG_SWING
		part.CFrame = top * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -part.Size.Y / 2, 0)
	end
	for key, s in spinners do
		local axleBase = s.axleBase
		if not axleBase or (axleBase.Position - at).Magnitude > SPIN_RADIUS then
			continue
		end
		local speed = if string.sub(key, 1, 5) == "wheel" then SPIN_SPEED.wheel else SPIN_SPEED.sail
		local turn = axleBase * CFrame.Angles(now * speed, 0, 0)
		for part, member in s.members do
			local offset = member.offset
			if not offset then
				offset = axleBase:Inverse() * member.base
				member.offset = offset
			end
			part.CFrame = turn * (offset :: CFrame)
		end
	end
	for light, flicker in flickers do
		light.Brightness = flicker.base * (0.85 + 0.3 * math.noise(now * 3, flicker.phase, 0.5))
	end
	for part, base in shimmers do
		part.Transparency = math.clamp(base + 0.08 * math.sin(now * 2.2 + part.Position.X), 0, 1)
	end
	if now - slowClock >= 1 / 15 then
		slowClock = now
		animateLava(now, at)
	end
end

-- Day/night switch: queue every window and lamp, then apply a few per frame.
local function updateNight()
	local night = false
	if WorldController.HasDayNight() then
		local clock = WorldController.TimeOfDay()
		night = DayCycle.isNight(clock)
	end
	if night ~= isNight then
		isNight = night
		table.clear(nightQueue)
		for part in nightParts do
			table.insert(nightQueue, part)
		end
		for holder in lampLights do
			table.insert(nightQueue, holder)
		end
	end
	local n = 0
	while n < NIGHT_PER_FRAME and #nightQueue > 0 do
		local instance = table.remove(nightQueue) :: Instance
		if nightApplied[instance] ~= isNight then
			applyNight(instance)
			n += 1
		end
	end
end

function TownFxController.Init(registry)
	WorldController = registry.Get("WorldController")
end

function TownFxController.Start()
	for _, instance in CollectionService:GetTagged(BlueprintBuild.FX_TAG) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(BlueprintBuild.FX_TAG):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(BlueprintBuild.FX_TAG):Connect(onRemoved)
	local nightCheck = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		local ok, err = pcall(function()
			animate(now)
		end)
		if not ok then
			warn(`[TownFxController] {err}`)
		end
		nightCheck += dt
		if nightCheck >= 0.5 or #nightQueue > 0 then
			if nightCheck >= 0.5 then
				nightCheck = 0
			end
			local okNight, errNight = pcall(function()
				updateNight()
			end)
			if not okNight then
				warn(`[TownFxController] {errNight}`)
			end
		end
	end)
end

return TownFxController
