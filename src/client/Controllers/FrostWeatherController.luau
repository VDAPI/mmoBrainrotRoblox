--!strict
-- Weather of the maps with wind zones (S47: the Frost Peaks; Data/Terrain/<map> `winds`, RegionTerrain.windAt):
--   * snowfall in a box round the camera: its direction, slant, flake size and density follow the wind zone under the
--     player, blended smoothly, with slow gusts (big calm flakes in the valley, slanting snow in the pass, a dense
--     blizzard on the Wyrm Spire that still leaves sight for a fight, sparse snow over the lake and the temple),
--   * ground drifts: fast streaks of snow just over the ground where the wind is strong (the tundra, the pass),
--   * the aurora at night: a few untextured beams (colour and transparency only, LightEmission 1) high over the
--     northern horizon, moving with the camera like the sky (closer than the night fog), green-cyan-violet, slowly
--     waving, fading in and out with the night (Logic/DayCycle via WorldController); 6 beams, 2 on low detail.
-- "World detail" low: half the particles, 2 aurora beams. Admin /worldfx snow|drift|aurora <on|off|auto> (through
-- WorldLifeController.SetFx). Nothing here collides, is clicked or replicated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local RegionTerrain = require(ReplicatedStorage.Shared.Logic.RegionTerrain)
local State = require(script.Parent.Parent.UI.State)

local FrostWeatherController = {
	Name = "FrostWeatherController",
	Deps = { "WorldController" },
}

local WorldController: any

local AURORA_COLORS = { Color3.fromHex("#6BFFB0"), Color3.fromHex("#6BE0FF"), Color3.fromHex("#B08BFF") }
local AURORA_BEAMS = 6
local AURORA_LOW = 2

local fxMode: { [string]: boolean? } = {}
local folder: Folder
local snowHolder: BasePart? = nil
local snowEmitter: ParticleEmitter? = nil
local driftHolder: BasePart? = nil
local driftEmitter: ParticleEmitter? = nil
local auroraAnchor: BasePart? = nil
local beams: { Beam } = {}
local active: string? = nil
-- smoothed wind (x, z vector of strength) and gustiness
local windX, windZ, windGust = 0, 0, 0

local function fxOn(name: string): boolean
	local forced = fxMode[name]
	return if forced == nil then true else forced
end

local function lowDetail(): boolean
	return State.Get({ "account", "settings", "decor" }) == "low"
end

local function particleFactor(): number
	return (if lowDetail() then 0.5 else 1)
		* (if State.Get({ "account", "settings", "quality" }) == "low" then 1 / 3 else 1)
end

local function part(name: string, size: Vector3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = folder
	return p
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

local function build()
	local snow = part("Snowfall", Vector3.new(140, 8, 140))
	snowHolder = snow
	snowEmitter = emitter(snow, {
		Color = ColorSequence.new(Color3.fromHex("#FFFFFF")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(25, 25),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		LightInfluence = 1,
		EmissionDirection = Enum.NormalId.Bottom,
		Rate = 60,
	})
	local drift = part("GroundDrift", Vector3.new(90, 1.5, 90))
	driftHolder = drift
	driftEmitter = emitter(drift, {
		Color = ColorSequence.new(Color3.fromHex("#F4F8FC")),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(0.8, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Size = NumberSequence.new(1.6, 3.4),
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(0, 1),
		LightInfluence = 1,
		Rate = 30,
	})
	local anchor = part("Aurora", Vector3.one)
	auroraAnchor = anchor
	for i = 1, AURORA_BEAMS do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		-- spread west to east over the northern sky, at different heights and depths
		local x0 = -420 + (i - 1) * 150
		local z = -360 - (i % 3) * 50
		local y = 170 + (i % 2) * 50
		a0.Position = Vector3.new(x0, y, z)
		a1.Position = Vector3.new(x0 + 260, y + 20, z - 40)
		a0.Parent = anchor
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 70
		beam.Width1 = 90
		beam.Segments = 24
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		local c1 = AURORA_COLORS[(i - 1) % 3 + 1]
		local c2 = AURORA_COLORS[i % 3 + 1]
		beam.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.5, AURORA_COLORS[2]),
			ColorSequenceKeypoint.new(1, c2),
		})
		beam.Enabled = false
		beam.Parent = anchor
		table.insert(beams, beam)
	end
end

local function clear()
	folder:ClearAllChildren()
	snowHolder, snowEmitter, driftHolder, driftEmitter, auroraAnchor = nil, nil, nil, nil, nil
	table.clear(beams)
end

local function tick(dt: number)
	local mapId = State.Get({ "character", "location", "map" })
	local playing = State.Get({ "session", "phase" }) == "playing"
	local region = if type(mapId) == "string" then RegionTerrain.get(mapId) else nil
	local windy = playing and region ~= nil and region.shape.winds ~= nil
	if not windy then
		if active then
			clear()
			active = nil
		end
		return
	end
	local id = mapId :: string
	local terrain = region :: RegionTerrain.Terrain
	if active ~= id then
		clear()
		build()
		active = id
	end
	local camera = Workspace.CurrentCamera
	local map = Maps.get(id)
	if not camera or not map then
		return
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	local at = camera.Focus.Position
	local mx, mz = at.X - origin.X, at.Z - origin.Z
	local dir, strength, gust = terrain.windAt(mx, mz)
	local b = math.rad(dir)
	local k = math.clamp(dt * 0.6, 0, 1) -- the zones blend over a couple of seconds
	windX += (math.sin(b) * strength - windX) * k
	windZ += (-math.cos(b) * strength - windZ) * k
	windGust += (gust - windGust) * k
	local now = os.clock()
	-- slow gusts: a sum of two slow waves scaled by the zone's gustiness
	local surge = 1 + windGust * 0.45 * (math.sin(now * 0.35) + 0.6 * math.sin(now * 0.91 + 1.3))
	local w = math.sqrt(windX * windX + windZ * windZ) * surge
	local factor = particleFactor()
	local ground = terrain.height(mx, mz) + origin.Y

	-- snowfall
	local snow, se = snowHolder :: BasePart, snowEmitter :: ParticleEmitter
	snow.CFrame = CFrame.new(at.X - windX * 30, math.max(at.Y, ground) + 28, at.Z - windZ * 30)
	se.Acceleration = Vector3.new(windX * 22 * surge, -3 - w * 2, windZ * 22 * surge)
	se.Size = NumberSequence.new(0.5 - 0.3 * math.clamp(w, 0, 1))
	se.Rate = (35 + 110 * math.clamp(w, 0, 1.2)) * factor
	se.Lifetime = NumberRange.new(5 - 2 * math.clamp(w, 0, 1), 8 - 3 * math.clamp(w, 0, 1))
	se.Enabled = fxOn("snow")

	-- ground drifts where the wind is strong
	local drift, de = driftHolder :: BasePart, driftEmitter :: ParticleEmitter
	drift.CFrame = CFrame.new(at.X, ground + 0.8, at.Z)
	de.Acceleration = Vector3.new(windX * 60, 0, windZ * 60)
	de.Rate = 40 * math.clamp((w - 0.55) / 0.45, 0, 1) * factor
	de.Enabled = fxOn("drift") and w > 0.55

	-- the aurora at night
	local _, nightness = WorldController.TimeOfDay()
	local anchor = auroraAnchor :: BasePart
	anchor.CFrame = CFrame.new(at.X, origin.Y, at.Z)
	local count = if lowDetail() then AURORA_LOW else AURORA_BEAMS
	local show = fxOn("aurora") and (nightness > 0.05 or fxMode.aurora == true)
	local fade = if fxMode.aurora == true then 1 else math.clamp((nightness - 0.05) / 0.5, 0, 1)
	for i, beam in beams do
		local on = show and i <= count
		if beam.Enabled ~= on then
			beam.Enabled = on
		end
		if on then
			local phase = now * 0.12 + i * 1.7
			beam.CurveSize0 = 60 * math.sin(phase)
			beam.CurveSize1 = -50 * math.cos(phase * 0.8)
			local base = 1 - 0.55 * fade * (0.75 + 0.25 * math.sin(now * 0.3 + i))
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, base),
				NumberSequenceKeypoint.new(0.75, base),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end
end

-- /worldfx snow|drift|aurora: "on" / "off" force it on this client, "auto" gives it back.
function FrostWeatherController.SetFx(name: string, mode: string)
	fxMode[name] = if mode == "on" then true elseif mode == "off" then false else nil
end

function FrostWeatherController.Init(registry)
	WorldController = registry.Get("WorldController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Weather"
	folder.Parent = Workspace
end

function FrostWeatherController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local ok, err = pcall(function()
			tick(elapsed)
		end)
		if not ok then
			warn(`[FrostWeatherController] {err}`)
		end
	end)
end

return FrostWeatherController
