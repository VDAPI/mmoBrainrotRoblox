--!strict
-- Life of the shaped regions on the client (S45; the Whispering Meadows keep their MeadowsLifeController). Works on
-- every map of the Logic/WorldGen registry but the Meadows, from the generator's life points (`life()`) and a
-- registry of kinds (S46/S47 add theirs to EMITTERS or the animal kinds). Nothing here is replicated, collides or can be clicked.
--   * perch: crows on black dead trees, the gallows and the witch's hut; they fly off when the player comes close
--     and come back later,
--   * batRoost: bats hanging under the overhangs of the Blood Cliffs; at dusk and at night they swarm out around
--     the roost, a running player scatters them,
--   * bats: swarms circling over the cliffs at night (and a lone bat over the forest near the player),
--   * wisp: will-o'-the-wisps over the bog, the Heart's pools and the graves at night, drifting and backing away
--     from the player,
--   * mist (banks lying in hollows, denser in the morning and at night), moths (round lanterns at night),
--     fireflies (the swamp's edge at night), spores (the Heart of the Forest): emitters at their points,
--   * falling dead leaves around the player in the forest.
-- S46 (Ashen Wastes):
--   * falling ash around the player (thick on the plain, in the warcamp and the ruins, none on the dunes and in the
--     necropolis), embers rising from cracks, lava and forges, heat haze over the lava, steam over the hot pools,
--     smoke and big smoke columns seen from afar (the crater, the forge, the bell tower, Deepforge), bubbles and
--     sparks on the lava pools,
--   * vultures: circling high over carrion (seen from ~300 studs) and perched on dead trees, palms and bones (they
--     take off when the player comes close, circle and come back),
--   * dust devils: wandering columns of dust by day on the dunes, the old road, the plain and the dry oasis (at most
--     two at a time, none on low detail).
-- S47 (Frost Peaks; snowfall, ground drifts and the aurora: Controllers/FrostWeatherController):
--   * snow plumes torn off the horn's summit and the ridges' crests downwind (seen from ~480 studs), now and then a
--     powder avalanche sliding down the Yeti Slopes' gully (particles only, it hurts nobody), dust falling from the
--     icicles at the Frozen Falls, the gates and the Grotto, yellow glints of harpies' eyes in the clefts at night,
--   * eagles circling high over the Harpy Rocks and the Wyrm Spire (not harpies: nothing to click).
-- Admin /worldfx <ash|embers|haze|smoke|vultures|devils|lavaglow|snow|drift|aurora|plume|eagles|avalanche|glow>
-- <on|off|auto> switches an effect on the caller's client (AdminClient "worldfx").
-- Only within LIFE_RADIUS; with "World detail" on low there are no animals, half the particles and half the wisps.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DayCycle = require(ReplicatedStorage.Shared.Logic.DayCycle)
local Net = require(ReplicatedStorage.Shared.Net)
local MapTerrain = require(ReplicatedStorage.Shared.Logic.MapTerrain)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local RegionTerrain = require(ReplicatedStorage.Shared.Logic.RegionTerrain)
local State = require(script.Parent.Parent.UI.State)
local WorldGen = require(ReplicatedStorage.Shared.Logic.WorldGen)

local WorldLifeController = {
	Name = "WorldLifeController",
	Deps = { "WorldController", "RegionLightController", "FrostWeatherController" },
}

local WorldController: any
local RegionLightController: any
local FrostWeatherController: any

local LIFE_RADIUS = 160
local FLEE_RADIUS = 16
local RETURN_AFTER = 45
-- Maps with their own life controller.
local SKIP: { [string]: boolean } = { meadows = true }
-- Forest themes where dead leaves fall around the player.
local LEAFY: { [string]: boolean } = { thicket = true, hollow = true, ruins = true, rot = true, forest = true }
-- S46: how thick the ash falls on the Ashen Wastes' themes (0..1).
local ASH: { [string]: number } = {
	ash = 1,
	warcamp = 1,
	burnt = 1,
	lavafield = 0.6,
	royalroad = 0.5,
	saltflat = 0.3,
	crags = 0.3,
	dunes = 0,
	necropolis = 0,
}
-- Maps where a lone bat flies over the player at night.
local BATS: { [string]: boolean } = { duskwood = true }
local VULTURE_RADIUS = 300
local FAR_RADIUS = 480
-- /worldfx overrides (nil = auto).
local fxMode: { [string]: boolean? } = {}

local function fxOn(name: string): boolean
	local forced = fxMode[name]
	return if forced == nil then true else forced
end

local folder: Folder
local rng = Random.new()

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

local function particleFactor(): number
	return (if lowDetail() then 0.5 else 1)
		* (if State.Get({ "account", "settings", "quality" }) == "low" then 1 / 3 else 1)
end

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function emitter(holder: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = holder
	return e
end

-- Time of day: the real clock (not the dusk clock of the sky) and how dark it is.
type Time = { clock: number, night: boolean, dusk: boolean, morning: boolean }

local function timeNow(): Time
	local clock, nightness = WorldController.TimeOfDay()
	local night = nightness > 0.5 or DayCycle.isNight(clock)
	return {
		clock = clock,
		night = night,
		dusk = night or clock >= 17,
		morning = clock >= 4.5 and clock < 8.5,
	}
end

-- Emitter kinds (point emitters) ----------------------------------------------------------------------------------

type EmitterKind = {
	size: (r: number) -> Vector3,
	props: { [string]: any },
	on: (t: Time) -> boolean,
	rate: (t: Time) -> number, -- multiplier of props.Rate
	far: boolean?, -- S46: seen from FAR_RADIUS (smoke columns)
	fx: string?, -- S46: /worldfx switch
}

local function always(_t: Time): boolean
	return true
end

local function same(_t: Time): number
	return 1
end

local EMITTERS: { [string]: EmitterKind } = {
	-- S46: sparks rising from cracks, lava, forges and fumaroles
	embers = {
		size = function(r)
			return Vector3.new(r * 2, 1, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#FFD27A"), Color3.fromHex("#FF4A10")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.18, 0.06),
			Lifetime = NumberRange.new(2, 4),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0.6, 1.2, 0.3),
			LightEmission = 1,
			LightInfluence = 0,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 6,
		},
		on = always,
		rate = function(t)
			return if t.night then 1.5 else 1
		end,
		fx = "embers",
	},
	-- shimmering air over the lava (barely visible, rising)
	haze = {
		size = function(r)
			return Vector3.new(r * 2, 1, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#FFE2C8")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 0.93),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(4, 9),
			Lifetime = NumberRange.new(2.5, 4),
			Speed = NumberRange.new(2, 3.5),
			SpreadAngle = Vector2.new(10, 10),
			RotSpeed = NumberRange.new(-20, 20),
			Rotation = NumberRange.new(0, 360),
			LightInfluence = 0.2,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 4,
		},
		on = always,
		rate = same,
		fx = "haze",
	},
	steam = {
		size = function(r)
			return Vector3.new(r * 2, 1, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#F0EEE8")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(3, 8),
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(1, 2),
			SpreadAngle = Vector2.new(12, 12),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-10, 10),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 4,
		},
		on = always,
		rate = function(t)
			return if t.morning or t.night then 1.5 else 1
		end,
		fx = "haze",
	},
	smoke = {
		size = function(r)
			return Vector3.new(r * 2, 1, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#3A3634"), Color3.fromHex("#7A7470")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.6, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(2, 7),
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(2, 3.5),
			SpreadAngle = Vector2.new(10, 10),
			Acceleration = Vector3.new(0.8, 0.2, 0.3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-12, 12),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 2,
		},
		on = always,
		rate = same,
		fx = "smoke",
	},
	-- big dark columns seen from afar (the crater, the forge, the bell tower, Deepforge)
	smokeColumn = {
		size = function(r)
			return Vector3.new(r * 2, 2, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#2A2624"), Color3.fromHex("#5A5450")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.7, 0.65),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(8, 22),
			Lifetime = NumberRange.new(14, 20),
			Speed = NumberRange.new(4, 6),
			SpreadAngle = Vector2.new(8, 8),
			Acceleration = Vector3.new(1.2, 0.3, 0.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-6, 6),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 2.5,
		},
		on = always,
		rate = same,
		far = true,
		fx = "smoke",
	},
	lavaBubbles = {
		size = function(r)
			return Vector3.new(r * 2, 0.5, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#FFB040"), Color3.fromHex("#FF4A10")),
			Transparency = NumberSequence.new(0, 1),
			Size = NumberSequence.new(0.8, 0.2),
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(3, 7),
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -20, 0),
			LightEmission = 1,
			LightInfluence = 0,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 5,
		},
		on = always,
		rate = same,
		fx = "embers",
	},
	mist = {
		size = function(r)
			return Vector3.new(r * 2, 3, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#C8CCD4")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.84),
				NumberSequenceKeypoint.new(0.7, 0.86),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(14, 22),
			Lifetime = NumberRange.new(10, 15),
			Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 6),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-3, 3),
			LightInfluence = 1,
			Rate = 3,
		},
		on = function(_t)
			return true
		end,
		rate = function(t)
			return if t.night or t.morning then 1.6 else 0.8
		end,
	},
	moths = {
		size = function(r)
			return Vector3.new(r * 2, r * 1.4, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#E8E0C8")),
			Transparency = NumberSequence.new(0.2, 0.6),
			Size = NumberSequence.new(0.18),
			Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.4, 0),
			LightInfluence = 0.4,
			Rate = 4,
		},
		on = function(t)
			return t.night
		end,
		rate = function(_t)
			return 1
		end,
	},
	fireflies = {
		size = function(r)
			return Vector3.new(r * 2, 6, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#C8FF7A")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0),
				NumberSequenceKeypoint.new(0.3, 0.8),
				NumberSequenceKeypoint.new(0.45, 0),
				NumberSequenceKeypoint.new(0.7, 0.9),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.28),
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.3, 1.2),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			LightInfluence = 0,
			Rate = 8,
		},
		on = function(t)
			return t.night
		end,
		rate = function(_t)
			return 1
		end,
	},
	spores = {
		size = function(r)
			return Vector3.new(r * 2, 12, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#B8E89A")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.4),
				NumberSequenceKeypoint.new(0.8, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.2),
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(0.1, 0.5),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0.2, 0.12, 0.1),
			LightEmission = 0.6,
			Rate = 10,
		},
		on = function(_t)
			return true
		end,
		rate = function(t)
			return if t.night then 1.4 else 1
		end,
	},
	-- S47: snow torn off a summit or a crest by the wind (blowing east, the Peaks' wind), seen from afar
	snowPlume = {
		size = function(r)
			return Vector3.new(6 * r, 4, 6 * r)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#F4F8FC")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.45),
				NumberSequenceKeypoint.new(0.7, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(6, 22),
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(30, 20),
			Acceleration = Vector3.new(16, 1.5, 3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 14,
		},
		on = always,
		rate = same,
		far = true,
		fx = "plume",
	},
	-- S47: a powder avalanche sliding down the gully for ~6 s every ~50 s
	avalanche = {
		size = function(r)
			return Vector3.new(r, 8, r * 1.6)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#EEF3F7")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(5, 14),
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(10, 18),
			SpreadAngle = Vector2.new(25, 10),
			Acceleration = Vector3.new(0, -6, 0),
			Rotation = NumberRange.new(0, 360),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Back,
			Rate = 40,
		},
		on = function(_t)
			return os.clock() % 50 < 6
		end,
		rate = same,
		far = true,
		fx = "avalanche",
	},
	-- S47: glittering dust falling from icicles
	icicleDust = {
		size = function(r)
			return Vector3.new(r * 2, 2, r * 2)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#E4F6FF")),
			Transparency = NumberSequence.new(0.2, 0.9),
			Size = NumberSequence.new(0.18),
			Lifetime = NumberRange.new(2, 3.5),
			Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0.3, -2.4, 0),
			LightEmission = 0.8,
			LightInfluence = 0.6,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 10,
		},
		on = always,
		rate = same,
		fx = "glow",
	},
	-- S47: yellow glints of harpies' eyes in the clefts at night
	harpyGlint = {
		size = function(_r)
			return Vector3.new(14, 10, 14)
		end,
		props = {
			Color = ColorSequence.new(Color3.fromHex("#E8E25A")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.35),
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(0, 0),
			LightEmission = 1,
			LightInfluence = 0,
			Rate = 1.5,
		},
		on = function(t)
			return t.night
		end,
		rate = same,
		fx = "glow",
	},
}

type Holder = { part: BasePart, emitter: ParticleEmitter, kind: EmitterKind }

-- Animals: crows, bats, wisps --------------------------------------------------------------------------------------

type Animal = {
	kind: string,
	model: Model,
	parts: { BasePart },
	home: Vector3,
	radius: number,
	pos: Vector3,
	target: Vector3,
	phase: number,
	state: string, -- "rest" | "fly" | "away" | "swarm" | "drift"
	timer: number,
	from: Vector3?,
}

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
	if kind == "crow" then
		local dark = Color3.fromHex("#16161A")
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = dark })
		add({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = dark })
		add({ Name = "WingL", Size = Vector3.new(1, 0.08, 0.5), Color = dark })
		add({ Name = "WingR", Size = Vector3.new(1, 0.08, 0.5), Color = dark })
	elseif kind == "vulture" then
		local brown = Color3.fromHex("#4A3A3A")
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.2, 2), Color = brown })
		add({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.7),
			Color = Color3.fromHex("#B08070"),
		})
		add({ Name = "WingL", Size = Vector3.new(3, 0.1, 1.1), Color = brown })
		add({ Name = "WingR", Size = Vector3.new(3, 0.1, 1.1), Color = brown })
	elseif kind == "eagle" then
		local brown = Color3.fromHex("#3A2E26")
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1, 1.8), Color = brown })
		add({
			Name = "Head",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.55, 0.55, 0.65),
			Color = Color3.fromHex("#E8E4DA"),
		})
		add({ Name = "WingL", Size = Vector3.new(3.4, 0.1, 1), Color = brown })
		add({ Name = "WingR", Size = Vector3.new(3.4, 0.1, 1), Color = brown })
	elseif kind == "bat" then
		local dark = Color3.fromHex("#1E1A1E")
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.7, 0.5), Color = dark })
		add({ Name = "WingL", Size = Vector3.new(1.1, 0.06, 0.6), Color = dark })
		add({ Name = "WingR", Size = Vector3.new(1.1, 0.06, 0.6), Color = dark })
	else -- wisp
		local glow = add({
			Name = "Glow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			Color = Color3.fromHex("#9FE8FF"),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromHex("#9FE8FF")
		light.Range = 8
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = glow
	end
	return m, list
end

local animals: { Animal } = {}
local holders: { [number]: Holder } = {}
local points: { WorldGen.Life } = {}
local activeMap: string? = nil
local leafHolder: BasePart? = nil
local leafEmitter: ParticleEmitter? = nil
local ashHolder: BasePart? = nil
local ashEmitter: ParticleEmitter? = nil
type Devil = { part: BasePart, velocity: Vector3, age: number, life: number }
local devils: { Devil } = {}
local loneBat: Animal? = nil

local function newAnimal(kind: string, home: Vector3, radius: number, state: string): Animal
	local m, list = model(kind)
	m.Parent = nil
	local a: Animal = {
		kind = kind,
		model = m,
		parts = list,
		home = home,
		radius = radius,
		pos = home,
		target = home,
		phase = rng:NextNumber() * 10,
		state = state,
		timer = rng:NextNumber() * 4,
	}
	table.insert(animals, a)
	return a
end

local function spawnAnimals(origin: Vector3)
	for _, p in points do
		local home = origin + Vector3.new(p.x, p.y, p.z)
		if p.kind == "perch" then
			newAnimal("crow", home, 0, "rest")
		elseif p.kind == "batRoost" then
			for _ = 1, 2 do
				newAnimal(
					"bat",
					home + Vector3.new(rng:NextNumber() * 2 - 1, 0, rng:NextNumber() * 2 - 1),
					p.r or 3,
					"rest"
				)
			end
		elseif p.kind == "bats" then
			for _ = 1, 6 do
				newAnimal("bat", home, p.r or 40, "swarm")
			end
		elseif p.kind == "wisp" then
			newAnimal("wisp", home, p.r or 10, "drift")
		elseif p.kind == "vulturePerch" then
			newAnimal("vulture", home, 0, "rest")
		elseif p.kind == "vultures" then
			for _ = 1, 3 + math.floor(rng:NextNumber() * 3) do
				newAnimal("vulture", home + Vector3.new(0, rng:NextNumber() * 10, 0), p.r or 20, "circle")
			end
		elseif p.kind == "eagles" then
			for _ = 1, 2 do
				newAnimal("eagle", home + Vector3.new(0, rng:NextNumber() * 14, 0), p.r or 40, "circle")
			end
		end
	end
end

local function clearAll()
	for _, a in animals do
		a.model:Destroy()
	end
	table.clear(animals)
	for key, h in holders do
		h.part:Destroy()
		holders[key] = nil
	end
	if leafHolder then
		leafHolder:Destroy()
		leafHolder = nil
		leafEmitter = nil
	end
	if ashHolder then
		ashHolder:Destroy()
		ashHolder = nil
		ashEmitter = nil
	end
	for _, d in devils do
		d.part:Destroy()
	end
	table.clear(devils)
	loneBat = nil
end

local function pose(a: Animal, now: number)
	local p = a.pos
	local list = a.parts
	if a.kind == "vulture" or a.kind == "eagle" then
		local dir = if a.state == "circle" or a.state == "away"
			then Vector3.new(-math.sin(a.timer), 0, math.cos(a.timer))
			else a.target - (a.from or a.target)
		local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else a.phase
		local bank = if a.state == "circle" or a.state == "away" then 0.35 else 0
		local frame = CFrame.new(p) * CFrame.Angles(0, yaw, bank)
		list[1].CFrame = frame
		list[2].CFrame = frame * CFrame.new(0, 0.5, -1.2)
		local flying = a.state ~= "rest"
		-- a long glide with a rare slow flap; folded wings at rest
		local flap = if flying then math.max(0, math.sin(now * 1.3 + a.phase)) ^ 8 * 0.8 + 0.05 else 1.2
		list[3].CFrame = frame * CFrame.new(-0.6, 0.2, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-1.4, 0, 0)
		list[4].CFrame = frame * CFrame.new(0.6, 0.2, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(1.4, 0, 0)
	elseif a.kind == "crow" then
		local dir = a.target - (a.from or a.target)
		local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else a.phase
		local frame = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		list[1].CFrame = frame
		list[2].CFrame = frame * CFrame.new(0, 0.35, -0.45)
		local flap = if a.state == "fly" then math.sin(now * 22 + a.phase) * 0.9 else 0.15
		list[3].CFrame = frame * CFrame.new(-0.45, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.4, 0, 0)
		list[4].CFrame = frame * CFrame.new(0.45, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.4, 0, 0)
	elseif a.kind == "bat" then
		if a.state == "rest" then
			-- hanging head down, wings folded
			local frame = CFrame.new(p) * CFrame.Angles(math.pi, a.phase, 0)
			list[1].CFrame = frame
			list[2].CFrame = frame * CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, 0, 1.3)
			list[3].CFrame = frame * CFrame.new(0.25, 0, 0) * CFrame.Angles(0, 0, -1.3)
		else
			local dir = a.target - p
			local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else a.phase
			local frame = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
			local flap = math.sin(now * 30 + a.phase) * 1
			list[1].CFrame = frame
			list[2].CFrame = frame * CFrame.new(-0.2, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(-0.5, 0, 0)
			list[3].CFrame = frame * CFrame.new(0.2, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(0.5, 0, 0)
		end
	else
		list[1].CFrame = CFrame.new(p)
		list[1].Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(now * 2.4 + a.phase))
	end
end

local function step(a: Animal, dt: number, now: number, player: Vector3, speed: number, t: Time): boolean
	local near = (a.home - player).Magnitude < LIFE_RADIUS
	if a.kind == "vulture" or a.kind == "eagle" then
		if not fxOn(if a.kind == "eagle" then "eagles" else "vultures") then
			return false
		end
		local d = (player - a.home).Magnitude
		if a.state == "rest" then
			if d < FLEE_RADIUS * 1.4 then
				a.state, a.timer, a.from = "away", 0, a.pos
			end
			a.pos = a.home
			return near
		end
		-- circling: a wide slow ring (perched birds circle over their perch until they come back)
		local r = if a.state == "away" then 18 else math.max(a.radius, 12)
		local centre = if a.state == "away" then a.home + Vector3.new(0, 22, 0) else a.home
		a.timer += dt * (0.22 + a.phase * 0.006) * (if a.radius > 30 then 0.8 else 1)
		local w = a.timer + a.phase
		a.target = centre + Vector3.new(math.cos(w) * r, math.sin(w * 0.5) * 2, math.sin(w) * r)
		a.pos = a.pos:Lerp(a.target, math.clamp(dt * 2, 0, 1))
		if a.state == "away" and a.timer > RETURN_AFTER * 0.25 and d > FLEE_RADIUS * 3 then
			a.state, a.timer, a.pos = "rest", 0, a.home
		end
		return d < VULTURE_RADIUS
	elseif a.kind == "crow" then
		local d = (player - a.home).Magnitude
		if a.state == "rest" and d < FLEE_RADIUS then
			local away = (a.home - player) * Vector3.new(1, 0, 1)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
			a.state, a.timer, a.from = "fly", 0, a.pos
			a.target = a.home + away * 60 + Vector3.new(0, 30, 0)
		elseif a.state == "fly" then
			a.timer += dt
			local k = math.clamp(a.timer / 3, 0, 1)
			a.pos = (a.from :: Vector3):Lerp(a.target, k * k * (3 - 2 * k))
			if k >= 1 then
				a.state, a.timer = "away", 0
			end
		elseif a.state == "away" then
			a.timer += dt
			if a.timer > RETURN_AFTER and d > LIFE_RADIUS * 0.5 then
				a.state, a.pos, a.timer = "rest", a.home, 0
			end
			return false
		end
		return near
	elseif a.kind == "bat" then
		local roost = a.radius <= 6
		if roost then
			-- under the overhang by day, out around the roost at dusk and night; a runner close by scatters them
			local scared = speed > 15 and (player - a.home).Magnitude < 24
			if t.dusk or scared then
				a.state = "swarm"
			elseif a.state == "swarm" then
				a.timer += dt
				if a.timer > 20 then
					a.state, a.timer, a.pos = "rest", 0, a.home
				end
			end
			if a.state == "rest" then
				a.pos = a.home
				return near
			end
		elseif not t.dusk then
			return false
		end
		local r = if roost then 14 else a.radius
		local w = now * (0.9 + a.phase * 0.05) + a.phase
		local centre = if roost then a.home + Vector3.new(-8, 4, 0) else a.home
		a.target = centre
			+ Vector3.new(math.cos(w) * r, math.sin(w * 2.3) * 3 + math.sin(w * 0.7) * 2, math.sin(w * 1.3) * r)
		a.pos = a.pos:Lerp(a.target, math.clamp(dt * 3, 0, 1))
		return near
	else -- wisp
		if not t.night then
			return false
		end
		local w = now * 0.25 + a.phase
		local drift = a.home
			+ Vector3.new(math.cos(w) * a.radius * 0.6, 0.8 * math.sin(w * 1.7), math.sin(w * 0.8) * a.radius * 0.6)
		local away = drift - player
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude < 10 and flat.Magnitude > 0.01 then
			drift += flat.Unit * (10 - flat.Magnitude)
		end
		a.pos = a.pos:Lerp(drift, math.clamp(dt * 1.5, 0, 1))
		return near
	end
end

local function updateEmitters(origin: Vector3, player: Vector3, t: Time)
	local factor = particleFactor()
	for i, p in points do
		local kind = EMITTERS[p.kind]
		if kind then
			local world = origin + Vector3.new(p.x, p.y, p.z)
			local reach = if kind.far then FAR_RADIUS else LIFE_RADIUS
			local inRange = (world - player).Magnitude < reach + (p.r or 0) and fxOn(kind.fx or p.kind)
			local h: Holder? = holders[i]
			if inRange and not h then
				local holder = part({ Name = p.kind, Size = kind.size(p.r or 10), Transparency = 1 })
				holder.CFrame = CFrame.new(world + Vector3.new(0, 1.5, 0))
				holder.Parent = folder
				local e = emitter(holder, kind.props)
				h = { part = holder, emitter = e, kind = kind }
				holders[i] = h
			elseif not inRange and h then
				h.part:Destroy()
				holders[i] = nil
				h = nil
			end
			if h then
				local on = kind.on(t)
				h.emitter.Rate = (kind.props.Rate :: number) * kind.rate(t) * factor
				if h.emitter.Enabled ~= on then
					h.emitter.Enabled = on
				end
			end
		end
	end
end

local function updateLeaves(at: Vector3, theme: string)
	if not leafHolder then
		local holder = part({ Name = "DeadLeaves", Size = Vector3.new(80, 10, 80), Transparency = 1 })
		holder.Parent = folder
		leafHolder = holder
		leafEmitter = emitter(holder, {
			Color = ColorSequence.new(Color3.fromHex("#6A4A2A"), Color3.fromHex("#4A4A2A")),
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
			Acceleration = Vector3.new(0.4, -1.5, 0.3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-120, 120),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 4,
		})
	end
	local holder = leafHolder :: BasePart
	holder.CFrame = CFrame.new(at + Vector3.new(0, 14, 0))
	local e = leafEmitter :: ParticleEmitter
	e.Rate = 4 * particleFactor()
	e.Enabled = LEAFY[theme] == true
end

-- S46: ash falling around the player on the Ashen Wastes (thickness by the surface theme).

local function updateAsh(at: Vector3, theme: string)
	local density = ASH[theme] or 0
	if density <= 0 and not ashHolder then
		return
	end
	if not ashHolder then
		local holder = part({ Name = "Ash", Size = Vector3.new(90, 12, 90), Transparency = 1 })
		holder.Parent = folder
		ashHolder = holder
		ashEmitter = emitter(holder, {
			Color = ColorSequence.new(Color3.fromHex("#8A8480"), Color3.fromHex("#CFCAC4")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.25),
				NumberSequenceKeypoint.new(0.85, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(0.22),
			Lifetime = NumberRange.new(8, 12),
			Speed = NumberRange.new(0.4, 0.9),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0.6, -0.9, 0.3),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-60, 60),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Bottom,
			Rate = 18,
		})
	end
	local holder = ashHolder :: BasePart
	holder.CFrame = CFrame.new(at + Vector3.new(0, 16, 0))
	local e = ashEmitter :: ParticleEmitter
	e.Rate = 18 * density * particleFactor()
	e.Enabled = density > 0 and fxOn("ash")
end

-- S46: dust devils (at most DEVILS, by day, on open dusty ground), wandering slowly near the player.
local DEVILS = 2
local DEVIL_THEMES: { [string]: boolean } = { dunes = true, royalroad = true, ash = true, saltflat = true }

local function updateDevils(dt: number, at: Vector3, origin: Vector3, mapId: string, theme: string, t: Time)
	local allowed = DEVIL_THEMES[theme] == true and not t.night and not lowDetail() and fxOn("devils")
	for i = #devils, 1, -1 do
		local d = devils[i]
		d.age += dt
		local p = d.part.Position + d.velocity * dt
		local ground = MapTerrain.height(mapId, p.X - origin.X, p.Z - origin.Z) or (p.Y - 14 - origin.Y)
		d.part.Position = Vector3.new(p.X, origin.Y + ground + 14, p.Z)
		if d.age > d.life or (p - at).Magnitude > 170 or not allowed then
			d.part:Destroy()
			table.remove(devils, i)
		end
	end
	if allowed and #devils < DEVILS and rng:NextNumber() < dt * 0.05 then
		local a = rng:NextNumber() * math.pi * 2
		local r = 60 + rng:NextNumber() * 60
		local x, z = at.X + math.cos(a) * r, at.Z + math.sin(a) * r
		local ground = MapTerrain.height(mapId, x - origin.X, z - origin.Z) or (at.Y - origin.Y)
		local holder = part({ Name = "DustDevil", Size = Vector3.new(5, 28, 5), Transparency = 1 })
		holder.Position = Vector3.new(x, origin.Y + ground + 14, z)
		holder.Parent = folder
		local e = emitter(holder, {
			Color = ColorSequence.new(Color3.fromHex("#C8A878"), Color3.fromHex("#9A8A70")),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.6),
				NumberSequenceKeypoint.new(0.8, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Size = NumberSequence.new(2, 6),
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 4, 0),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(180, 360),
			LightInfluence = 1,
			EmissionDirection = Enum.NormalId.Top,
			Rate = 30 * particleFactor(),
		})
		e.Shape = Enum.ParticleEmitterShape.Cylinder
		local heading = rng:NextNumber() * math.pi * 2
		table.insert(devils, {
			part = holder,
			velocity = Vector3.new(math.cos(heading), 0, math.sin(heading)) * (3 + rng:NextNumber() * 3),
			age = 0,
			life = 30 + rng:NextNumber() * 30,
		})
	end
end

-- Loop ------------------------------------------------------------------------------------------------------------

local function enter(mapId: string)
	clearAll()
	activeMap = mapId
	local gen = WorldGen.get(mapId)
	points = if gen then gen.life() else {}
	local map = Maps.get(mapId)
	if map then
		spawnAnimals(Vector3.new(map.offset.x, map.offset.y, map.offset.z))
	end
end

local function leave()
	clearAll()
	activeMap = nil
	points = {}
end

local function tick(dt: number)
	local mapId = State.Get({ "character", "location", "map" })
	local playing = State.Get({ "session", "phase" }) == "playing"
	if type(mapId) ~= "string" or not playing or SKIP[mapId] or not WorldGen.get(mapId) then
		if activeMap then
			leave()
		end
		return
	end
	if activeMap ~= mapId then
		enter(mapId)
	end
	local at = rootPosition()
	local map = Maps.get(mapId)
	if not at or not map then
		return
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	local t = timeNow()
	updateEmitters(origin, at, t)
	local region = RegionTerrain.get(mapId)
	local mx, mz = at.X - origin.X, at.Z - origin.Z
	local theme = if region then region.themeAt(mx, mz) else ""
	updateLeaves(at, theme)
	updateAsh(at, theme)
	updateDevils(dt, at, origin, mapId, theme, t)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = if root then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	local now = os.clock()
	local show = not lowDetail()
	-- a lone bat over the forest near the player at night
	if show and t.night and not loneBat and BATS[mapId] then
		local ground = MapTerrain.height(mapId, mx, mz) or 0
		loneBat = newAnimal("bat", origin + Vector3.new(mx, ground + 16, mz), 24, "swarm")
	end
	if loneBat then
		local bat = loneBat :: Animal
		if (bat.home - at).Magnitude > 120 then
			local ground = MapTerrain.height(mapId, mx, mz) or 0
			bat.home = origin + Vector3.new(mx, ground + 16, mz)
		end
	end
	for _, a in animals do
		local animal = a.kind ~= "wisp"
		local visible = step(a, dt, now, at, speed, t)
		if animal and not show then
			visible = false
		end
		-- low detail keeps every other wisp
		if a.kind == "wisp" and lowDetail() and math.floor(a.phase * 10) % 2 == 1 then
			visible = false
		end
		if visible then
			pose(a, now)
		end
		local parent = if visible then folder else nil
		if a.model.Parent ~= parent then
			a.model.Parent = parent
		end
	end
end

-- /worldfx: "on" / "off" force an effect on this client, "auto" gives it back.
function WorldLifeController.SetFx(name: string, mode: string)
	fxMode[name] = if mode == "on" then true elseif mode == "off" then false else nil
	if name == "lavaglow" or name == "glow" then
		if RegionLightController then
			RegionLightController.SetEnabled(mode ~= "off")
		end
	end
	if FrostWeatherController and (name == "snow" or name == "drift" or name == "aurora") then
		FrostWeatherController.SetFx(name, mode)
		return
	end
	if name == "vultures" or name == "lavaglow" or name == "eagles" then
		return
	end
	-- emitters re-create themselves with the new switch
	for key, h in holders do
		h.part:Destroy()
		holders[key] = nil
	end
end

function WorldLifeController.Init(registry)
	WorldController = registry.Get("WorldController")
	RegionLightController = registry.Get("RegionLightController")
	FrostWeatherController = registry.Get("FrostWeatherController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_WorldLife"
	folder.Parent = Workspace
end

function WorldLifeController.Start()
	Net.On("AdminClient", function(action: any, arg: any)
		if
			action == "worldfx"
			and type(arg) == "table"
			and type(arg.name) == "string"
			and type(arg.mode) == "string"
		then
			WorldLifeController.SetFx(arg.name, arg.mode)
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local ok, err = pcall(function()
			tick(elapsed)
		end)
		if not ok then
			warn(`[WorldLifeController] {err}`)
		end
	end)
end

return WorldLifeController
