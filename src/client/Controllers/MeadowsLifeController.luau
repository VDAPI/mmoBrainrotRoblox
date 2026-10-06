--!strict
-- Life of the Whispering Meadows on the client (S26). Nothing here is replicated, collides or can be clicked.
--   * weather around the player (emitters in a box that follows the character): pollen over the glades by day,
--     mist near water in the morning and at night, fireflies at night in the marsh, the forest and the ravine,
--     falling leaves in the forest,
--   * butterflies over the glades (by the shrine and the farm, and around the player on the meadow),
--   * decorative animals from MeadowsGen.life(): crows on scarecrows, dead trees and the burnt mill (they fly off
--     when the player comes close and come back later), sheep grazing in the farm's pen, ducks on Toad Pond,
--   * birds taking off from a tree when the player runs past it.
-- Cheap: animals only within LIFE_RADIUS, a few parts each, updated at most 30 times a second; with the "World
-- detail" option on low there are no animals and the emitters run at half rate. Smoke, fires and the waterfall
-- come from TownFxController (part tags).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local DayCycle = require(ReplicatedStorage.Shared.Logic.DayCycle)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MeadowsGen = require(ReplicatedStorage.Shared.Logic.MeadowsGen)
local MeadowsTerrain = require(ReplicatedStorage.Shared.Logic.MeadowsTerrain)
local State = require(script.Parent.Parent.UI.State)

local MeadowsLifeController = {
	Name = "MeadowsLifeController",
	Deps = { "WorldController" },
}

local WorldController: any

local MAP = "meadows"
local LIFE_RADIUS = 140
local FLEE_RADIUS = 16
local RETURN_AFTER = 45
local BIRD_COOLDOWN = 50

local folder: Folder
local rng = Random.new()

-- Helpers ---------------------------------------------------------------------------------------------------------

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function lowDetail(): boolean
	return State.Get({ "account", "settings", "decor" }) == "low"
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

-- Weather emitters ------------------------------------------------------------------------------------------------

type Weather = { holder: BasePart, emitters: { [string]: ParticleEmitter }, base: { [string]: number } }
local weather: Weather? = nil

local function emitter(holder: BasePart, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = holder
	return e
end

local function buildWeather(): Weather
	local holder = part({ Name = "MeadowsWeather", Size = Vector3.new(90, 14, 90), Transparency = 1 })
	holder.Parent = folder
	local emitters: { [string]: ParticleEmitter } = {
		pollen = emitter(holder, "Pollen", {
			Color = ColorSequence.new(Color3.fromHex("#FFF2B0")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.3),
				NumberSequenceKeypoint.new(0.8, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.15),
			Lifetime = NumberRange.new(5, 8),
			Speed = NumberRange.new(0.2, 0.8),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0.4, 0.05, 0.2),
			LightEmission = 0.4,
			Rate = 14,
		}),
		mist = emitter(holder, "Mist", {
			Color = ColorSequence.new(Color3.fromHex("#DCE6EA")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.86),
				NumberSequenceKeypoint.new(0.7, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(12, 18),
			Lifetime = NumberRange.new(9, 13),
			Speed = NumberRange.new(0.3, 0.9),
			SpreadAngle = Vector2.new(180, 10),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-4, 4),
			LightInfluence = 1,
			Rate = 4,
		}),
		fireflies = emitter(holder, "Fireflies", {
			Color = ColorSequence.new(Color3.fromHex("#D8FF7A")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(0.3, 0.8),
				NumberSequenceKeypoint.new(0.45, 0),
				NumberSequenceKeypoint.new(0.7, 0.9),
				NumberSequenceKeypoint.new(0.85, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.28),
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.3, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			LightInfluence = 0,
			Rate = 9,
		}),
		leaves = emitter(holder, "Leaves", {
			Color = ColorSequence.new(Color3.fromHex("#A06A2A"), Color3.fromHex("#6E7A2E")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.1, 0),
				NumberSequenceKeypoint.new(0.85, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.45),
			Lifetime = NumberRange.new(6, 9),
			Speed = NumberRange.new(0.5, 1),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0.5, -1.6, 0.3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 5,
		}),
	}
	local base: { [string]: number } = {}
	for name, e in emitters do
		base[name] = e.Rate
	end
	return { holder = holder, emitters = emitters, base = base }
end

local function updateWeather(at: Vector3, theme: string, night: boolean, clock: number)
	local w = weather
	if not w then
		w = buildWeather()
		weather = w
	end
	assert(w, "weather")
	local map = Maps.get(MAP)
	local mx, mz = at.X - (if map then map.offset.x else 0), at.Z - (if map then map.offset.z else 0)
	local nearWater = MeadowsTerrain.streamDistance(mx, mz) < 40
		or MeadowsTerrain.lakeDistance(mx, mz) < 60
		or MeadowsTerrain.marshWeight(mx, mz) > 0.2
	local morning = clock >= 4.5 and clock < 8.5
	local want = {
		pollen = not night and (theme == "meadow" or theme == "road" or theme == "wet" or theme == "hills"),
		mist = nearWater and (night or morning),
		fireflies = night and (theme == "marsh" or theme == "wet" or theme == "forest" or theme == "ravine"),
		leaves = theme == "forest",
	}
	-- half with low world detail; a third with low effects quality (as SettingsController does for every emitter)
	local factor = (if lowDetail() then 0.5 else 1)
		* (if State.Get({ "account", "settings", "quality" }) == "low" then 1 / 3 else 1)
	for name, e in w.emitters do
		local on = (want :: any)[name] == true
		e.Rate = w.base[name] * factor
		if e.Enabled ~= on then
			e.Enabled = on
		end
	end
	-- the box hangs around the player; mist lies low, leaves fall from above
	w.holder.CFrame = CFrame.new(at + Vector3.new(0, 4, 0))
end

-- Animals ---------------------------------------------------------------------------------------------------------

type Animal = {
	kind: string,
	model: Model,
	parts: { BasePart },
	home: Vector3, -- perch / centre of the pen / patch of water (world)
	radius: number,
	pos: Vector3,
	target: Vector3,
	phase: number,
	state: string, -- "rest" | "walk" | "fly" | "away"
	timer: number,
	from: Vector3?,
}

local animals: { Animal } = {}

local function model(kind: string): (Model, { BasePart })
	local m = Instance.new("Model")
	m.Name = kind
	local list: { BasePart } = {}
	local function add(props: { [string]: any }): BasePart
		local p = part(props)
		p.Parent = m
		table.insert(list, p)
		return p
	end
	if kind == "crow" or kind == "bird" then
		local dark = if kind == "crow" then Color3.fromHex("#16161A") else Color3.fromHex("#5A4A3A")
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = dark })
		add({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = dark })
		add({ Name = "WingL", Size = Vector3.new(1, 0.08, 0.5), Color = dark })
		add({ Name = "WingR", Size = Vector3.new(1, 0.08, 0.5), Color = dark })
	elseif kind == "sheep" then
		add({
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			Color = Color3.fromHex("#E6E0D2"),
			Material = Enum.Material.Fabric,
		})
		add({ Name = "Head", Size = Vector3.new(0.9, 1, 1.2), Color = Color3.fromHex("#2A2622") })
		add({ Name = "Legs", Size = Vector3.new(1.4, 1.1, 1.8), Color = Color3.fromHex("#2A2622") })
	else -- duck
		add({
			Name = "Body",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			Color = Color3.fromHex("#6E5A3E"),
		})
		add({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.55),
			Color = Color3.fromHex("#2E5A3A"),
		})
		add({ Name = "Beak", Size = Vector3.new(0.18, 0.12, 0.35), Color = Color3.fromHex("#D8A040") })
	end
	m.Parent = folder
	return m, list
end

local function spawnAnimals()
	local map = Maps.get(MAP)
	if not map then
		return
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	for _, p in MeadowsGen.life() do
		local home = origin + Vector3.new(p.x, p.y, p.z)
		local function add(kind: string, at: Vector3, radius: number)
			local m, list = model(kind)
			table.insert(animals, {
				kind = kind,
				model = m,
				parts = list,
				home = at,
				radius = radius,
				pos = at,
				target = at,
				phase = rng:NextNumber() * 10,
				state = "rest",
				timer = rng:NextNumber() * 4,
			})
		end
		if p.kind == "perch" then
			add("crow", home, 0)
		elseif p.kind == "sheep" then
			for _ = 1, 4 do
				add("sheep", home + Vector3.new(rng:NextNumber() * 8 - 4, 0, rng:NextNumber() * 8 - 4), p.r or 8)
			end
		elseif p.kind == "ducks" then
			for _ = 1, 3 do
				add("duck", home + Vector3.new(rng:NextNumber() * 10 - 5, 0, rng:NextNumber() * 10 - 5), p.r or 20)
			end
		end
	end
end

local function clearAnimals()
	for _, a in animals do
		a.model:Destroy()
	end
	table.clear(animals)
end

local function groundY(world: Vector3): number
	local map = Maps.get(MAP)
	if not map then
		return world.Y
	end
	return map.offset.y + MeadowsTerrain.height(world.X - map.offset.x, world.Z - map.offset.z)
end

local function pose(a: Animal, now: number)
	local p = a.pos
	local list = a.parts
	if a.kind == "crow" or a.kind == "bird" then
		local dir = a.target - (a.from or a.target)
		local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else a.phase
		local frame = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		list[1].CFrame = frame
		list[2].CFrame = frame * CFrame.new(0, 0.35, -0.45)
		local flap = if a.state == "fly" or a.state == "away" then math.sin(now * 22 + a.phase) * 0.9 else 0.15
		list[3].CFrame = frame * CFrame.new(-0.45, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.4, 0, 0)
		list[4].CFrame = frame * CFrame.new(0.45, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.4, 0, 0)
	elseif a.kind == "sheep" then
		local dir = a.target - p
		local yaw = if dir.Magnitude > 0.2 then math.atan2(-dir.X, -dir.Z) else a.phase
		local frame = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		local graze = if a.state == "rest" then -0.6 + 0.1 * math.sin(now * 2 + a.phase) else 0
		list[1].CFrame = frame * CFrame.new(0, 1.9, 0)
		list[2].CFrame = frame * CFrame.new(0, 2.3 + graze, -1.6) * CFrame.Angles(graze * 0.6, 0, 0)
		list[3].CFrame = frame * CFrame.new(0, 0.55, 0)
	else -- duck
		local bob = math.sin(now * 1.6 + a.phase) * 0.08
		local dir = a.target - p
		local yaw = if dir.Magnitude > 0.2 then math.atan2(-dir.X, -dir.Z) else a.phase
		local frame = CFrame.new(p + Vector3.new(0, 0.35 + bob, 0)) * CFrame.Angles(0, yaw, 0)
		list[1].CFrame = frame
		list[2].CFrame = frame * CFrame.new(0, 0.5, -0.45)
		list[3].CFrame = frame * CFrame.new(0, 0.45, -0.8)
	end
end

local function stepAnimal(a: Animal, dt: number, now: number, player: Vector3, visible: boolean)
	a.model.Parent = if visible then folder else nil
	if not visible then
		return
	end
	if a.kind == "crow" then
		local d = (player - a.home).Magnitude
		if a.state == "rest" and d < FLEE_RADIUS then
			-- take off: up and away from the player
			local away = (a.home - player) * Vector3.new(1, 0, 1)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
			a.state, a.timer, a.from = "fly", 0, a.pos
			a.target = a.home + away * 60 + Vector3.new(0, 30, 0)
		elseif a.state == "fly" then
			a.timer += dt
			local t = math.clamp(a.timer / 3, 0, 1)
			a.pos = (a.from :: Vector3):Lerp(a.target, t * t * (3 - 2 * t))
			if t >= 1 then
				a.state, a.timer = "away", 0
				a.model.Parent = nil
			end
		elseif a.state == "away" then
			a.timer += dt
			a.model.Parent = nil
			if a.timer > RETURN_AFTER and d > LIFE_RADIUS * 0.5 then
				a.state, a.pos, a.timer = "rest", a.home, 0
			end
			return
		end
	elseif a.kind == "bird" then
		a.timer += dt
		local t = math.clamp(a.timer / 2.6, 0, 1)
		a.pos = (a.from :: Vector3):Lerp(a.target, t)
		if t >= 1 then
			a.model:Destroy()
			a.state = "gone"
			return
		end
	else
		-- sheep and ducks wander slowly inside their circle
		a.timer -= dt
		if a.timer <= 0 then
			if a.state == "rest" then
				local angle = rng:NextNumber() * math.pi * 2
				local r = math.sqrt(rng:NextNumber()) * a.radius
				local goal = a.home + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
				if a.kind == "duck" then
					local map = Maps.get(MAP)
					local ok = map ~= nil and MeadowsTerrain.isWater(goal.X - map.offset.x, goal.Z - map.offset.z)
					goal = if ok then goal else a.pos
				end
				a.target, a.state, a.timer = goal, "walk", 4 + rng:NextNumber() * 4
			else
				a.state, a.timer = "rest", 3 + rng:NextNumber() * 6
			end
		end
		if a.state == "walk" then
			local dir = (a.target - a.pos) * Vector3.new(1, 0, 1)
			local speed = if a.kind == "duck" then 1.2 else 1.6
			if dir.Magnitude > 0.3 then
				a.pos += dir.Unit * math.min(dir.Magnitude, speed * dt)
			end
		end
		local y = if a.kind == "duck" then a.home.Y else groundY(a.pos)
		a.pos = Vector3.new(a.pos.X, y, a.pos.Z)
	end
	pose(a, now)
end

-- Birds from trees when running past --------------------------------------------------------------------------

local treeCells: { [number]: { { number } } } = {}
local treeCooldown: { [number]: number } = {}

local function indexTrees()
	table.clear(treeCells)
	for i, t in MeadowsGen.trees() do
		local key = math.floor(t.x / 32) * 1000 + math.floor(t.z / 32)
		local list = treeCells[key]
		if not list then
			list = {}
			treeCells[key] = list
		end
		table.insert(list, { t.x, t.z, i })
	end
end

local function scareBirds(world: Vector3, speed: number, now: number)
	if speed < 15 or lowDetail() then
		return
	end
	local map = Maps.get(MAP)
	if not map then
		return
	end
	local x, z = world.X - map.offset.x, world.Z - map.offset.z
	local cx, cz = math.floor(x / 32), math.floor(z / 32)
	for dx = -1, 1 do
		for dz = -1, 1 do
			for _, t in (treeCells[(cx + dx) * 1000 + (cz + dz)] or {}) :: { { number } } do
				local d = math.sqrt((t[1] - x) ^ 2 + (t[2] - z) ^ 2)
				if d < 12 and now - (treeCooldown[t[3]] or -math.huge) > BIRD_COOLDOWN and rng:NextNumber() < 0.5 then
					treeCooldown[t[3]] = now
					local top = map.offset.y + MeadowsTerrain.height(t[1], t[2]) + 11
					local start = Vector3.new(map.offset.x + t[1], top, map.offset.z + t[2])
					for _ = 1, rng:NextInteger(3, 5) do
						local m, list = model("bird")
						local away = Vector3.new(rng:NextNumber() - 0.5, 0, rng:NextNumber() - 0.5)
						away = if away.Magnitude > 0.05 then away.Unit else Vector3.new(1, 0, 0)
						local from = start
							+ Vector3.new(rng:NextNumber() * 4 - 2, rng:NextNumber() * 2, rng:NextNumber() * 4 - 2)
						table.insert(animals, {
							kind = "bird",
							model = m,
							parts = list,
							home = from,
							radius = 0,
							pos = from,
							target = from + away * 50 + Vector3.new(0, 22 + rng:NextNumber() * 10, 0),
							phase = rng:NextNumber() * 10,
							state = "fly",
							timer = 0,
							from = from,
						})
					end
					return
				end
			end
		end
	end
end

-- Butterflies -------------------------------------------------------------------------------------------------------

type Butterfly = { wings: { BasePart }, centre: Vector3, phase: number }
local butterflies: { Butterfly } = {}

local function buildButterflies()
	local colours = { "#F2C84A", "#F2F0E8", "#E8884A", "#8AB8F0" }
	for i = 1, 6 do
		local c = Color3.fromHex(colours[(i - 1) % #colours + 1])
		local wings = {}
		for _ = 1, 2 do
			local w = part({ Size = Vector3.new(0.5, 0.05, 0.4), Color = c, Material = Enum.Material.SmoothPlastic })
			w.Parent = nil
			table.insert(wings, w)
		end
		table.insert(butterflies, { wings = wings, centre = Vector3.zero, phase = rng:NextNumber() * 20 })
	end
end

local function updateButterflies(player: Vector3, on: boolean, now: number)
	for i, b in butterflies do
		if not on then
			for _, w in b.wings do
				w.Parent = nil
			end
			continue
		end
		if (b.centre - player).Magnitude > 50 then
			local a = i * 1.05 + now * 0.01
			b.centre = player + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		end
		local t = now * 0.6 + b.phase
		local pos = b.centre
			+ Vector3.new(math.sin(t) * 5 + math.sin(t * 2.3) * 2, 0, math.cos(t * 0.8) * 5 + math.cos(t * 1.9) * 2)
		local map = Maps.get(MAP)
		local ground = if map
			then map.offset.y + MeadowsTerrain.height(pos.X - map.offset.x, pos.Z - map.offset.z)
			else pos.Y
		pos = Vector3.new(pos.X, ground + 2 + math.sin(t * 3.1) * 0.8, pos.Z)
		local flap = math.sin(now * 28 + b.phase) * 1.1
		local frame = CFrame.new(pos) * CFrame.Angles(0, t, 0)
		b.wings[1].CFrame = frame * CFrame.Angles(0, 0, flap) * CFrame.new(-0.25, 0, 0)
		b.wings[2].CFrame = frame * CFrame.Angles(0, 0, -flap) * CFrame.new(0.25, 0, 0)
		for _, w in b.wings do
			if w.Parent ~= folder then
				w.Parent = folder
			end
		end
	end
end

-- Loop ----------------------------------------------------------------------------------------------------------

local active = false

local function leave()
	active = false
	clearAnimals()
	if weather then
		weather.holder:Destroy()
		weather = nil
	end
	updateButterflies(Vector3.zero, false, 0)
end

local function enter()
	active = true
	spawnAnimals()
	indexTrees()
end

local function step(dt: number)
	local mapId = State.Get({ "character", "location", "map" })
	if mapId ~= MAP or State.Get({ "session", "phase" }) ~= "playing" then
		if active then
			leave()
		end
		return
	end
	if not active then
		enter()
	end
	local at = rootPosition()
	if not at then
		return
	end
	local map = Maps.get(MAP)
	local mx, mz = at.X - (if map then map.offset.x else 0), at.Z - (if map then map.offset.z else 0)
	local area = Areas.areaAt(MAP, mx, mz)
	local theme = if area and area.decor then area.decor else MeadowsTerrain.themeAt(mx, mz)
	local clock, nightness = WorldController.TimeOfDay()
	local night = nightness > 0.5 or DayCycle.isNight(clock)
	updateWeather(at, theme, night, clock)
	local now = os.clock()
	local glade = not night and (theme == "meadow" or theme == "road")
	updateButterflies(at, glade and not lowDetail(), now)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	scareBirds(at, speed, now)
	local show = not lowDetail()
	for i = #animals, 1, -1 do
		local a = animals[i]
		local visible = show and ((a.home - at).Magnitude < LIFE_RADIUS or a.kind == "bird")
		stepAnimal(a, dt, now, at, visible)
		if a.state == "gone" then
			table.remove(animals, i)
		end
	end
end

function MeadowsLifeController.Init(registry)
	WorldController = registry.Get("WorldController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_MeadowsLife"
	folder.Parent = Workspace
	buildButterflies()
end

function MeadowsLifeController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local ok, err = pcall(function()
			step(elapsed)
		end)
		if not ok then
			warn(`[MeadowsLifeController] {err}`)
		end
	end)
end

return MeadowsLifeController
