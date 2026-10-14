--!strict
-- S105: the season of Vaelthorn for this character (Logic/CitySeason; /season forces it, UI/CitySeasonState). In the
-- city only, per player, on the client:
--   * "spring" (the finale handed in): the Builds of Logic/TownGen/Spring (flowers in the gardens, the wreath round the
--     fountain, the maypole on the market square) built locally into Workspace.Vaelthorn_CitySeason (the maypole and
--     the wreath in the first frame, the gardens paced over the next ones) and emitters of pink and white petals over
--     the orchards and the square,
--   * "snow" (the dragon beaten, the finale not yet): calm large flakes round the camera (like the valley of the
--     Frost Peaks in FrostWeatherController), half at low world detail; no drifts, the terrain stays,
--   * "summer": nothing.
-- A season change or leaving the city removes everything (rebuilt in a fraction of a second). Nothing collides, is
-- clicked or replicated; the city's mood follows in AmbienceController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local CitySeasonState = require(script.Parent.Parent.UI.CitySeasonState)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Spring = require(ReplicatedStorage.Shared.Logic.TownGen.Spring)
local State = require(script.Parent.Parent.UI.State)
local Town = require(ReplicatedStorage.Shared.Data.Town)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local CitySeasonController = {
	Name = "CitySeasonController",
	Deps = { "WorldController" },
}

local WorldController: any

local CHECK = 0.5 -- seconds between season checks
local FOLLOW = 0.1 -- seconds between moves of the snow box
local SNOW_RATE = 60
local SNOW_RATE_LOW = 30
local PETAL_COLORS = { Color3.fromHex("#F6C6D4"), Color3.fromHex("#FFFFFF") }
local ALL_LODS: BlueprintBuild.Lods = { shell = true, detail = true, fine = true }

local folder: Folder
local shown: string? = nil -- "<season>|<low>" being shown, nil = nothing
local token = 0
local snowHolder: BasePart? = nil

local function lowDetail(): boolean
	return State.Get({ "account", "settings", "decor" }) == "low"
end

local function origin(): Vector3?
	local map = Maps.get("city")
	return if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else nil
end

local function holder(name: string, size: Vector3, cframe: CFrame): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = cframe
	p.Parent = folder
	return p
end

local function clear()
	token += 1
	folder:ClearAllChildren()
	snowHolder = nil
	shown = nil
end

local function buildSpring(at: Vector3, low: boolean)
	local myToken = token
	local builds = Spring.all(Town.city, TownTerrain.heightAt, low)
	-- the first frame: the maypole and the wreath (Spring.all puts them first)
	for i = 1, math.min(2, #builds) do
		BlueprintBuild.build(builds[i] :: any, at, ALL_LODS, folder)
	end
	for _, p in Spring.petals(Town.city, TownTerrain.heightAt, low) do
		local h = holder("Petals", Vector3.new(14, 1, 14), CFrame.new(at + Vector3.new(p.x, p.y, p.z)))
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Color = ColorSequence.new(PETAL_COLORS[1], PETAL_COLORS[2])
		e.Size = NumberSequence.new(0.22)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(5, 7)
		e.Rate = 3
		e.Speed = NumberRange.new(0.3, 1)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0.5, -0.8, 0.3)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.LightEmission = 0
		e.LightInfluence = 1
		e.Parent = h
	end
	-- the gardens over the next frames
	task.spawn(function()
		local pacer: BlueprintBuild.Pacer = { every = 150, left = 150 }
		for i = 3, #builds do
			if token ~= myToken then
				return
			end
			local result = BlueprintBuild.build(builds[i] :: any, at, ALL_LODS, folder, pacer)
			-- a clear during the paced build: the model was parented after ClearAllChildren
			if token ~= myToken then
				if result.model then
					result.model:Destroy()
				end
				return
			end
		end
	end)
end

local function buildSnow(low: boolean)
	local box = holder("CitySnow", Vector3.new(140, 8, 140), CFrame.new(0, -1000, 0))
	snowHolder = box
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new(Color3.fromHex("#FFFFFF"))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.1),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new(0.5)
	e.Lifetime = NumberRange.new(7, 9)
	e.Speed = NumberRange.new(2, 3)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Acceleration = Vector3.new(0.4, -2.5, 0.2)
	e.LightInfluence = 1
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = if low then SNOW_RATE_LOW else SNOW_RATE
	e.Parent = box
end

-- Season checks: what should show, rebuilt on a change.
local function check()
	local map = State.Get({ "character", "location", "map" })
	local playing = State.Get({ "session", "phase" }) == "playing"
	local at = origin()
	if map ~= "city" or not playing or not at or WorldController.IsLoading() then
		if shown then
			clear()
		end
		return
	end
	local season = CitySeasonState.current()
	local low = lowDetail()
	local key = `{season}|{low}`
	if key == shown then
		return
	end
	clear()
	shown = key
	if season == "spring" then
		buildSpring(at, low)
	elseif season == "snow" then
		buildSnow(low)
	end
end

-- The snow box follows the camera.
local function follow()
	local box = snowHolder
	local camera = Workspace.CurrentCamera
	if not box or not camera then
		return
	end
	local p = camera.Focus.Position
	local at = origin() or Vector3.zero
	local ground = TownTerrain.heightAt(p.X - at.X, p.Z - at.Z) + at.Y
	box.CFrame = CFrame.new(p.X, math.max(p.Y, ground) + 28, p.Z)
end

function CitySeasonController.Init(registry)
	WorldController = registry.Get("WorldController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_CitySeason"
	folder.Parent = Workspace
end

function CitySeasonController.Start()
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "season" then
			CitySeasonState.force(arg)
		end
	end)
	local sinceCheck, sinceFollow = CHECK, 0
	RunService.Heartbeat:Connect(function(dt: number)
		sinceCheck += dt
		sinceFollow += dt
		if sinceCheck >= CHECK then
			sinceCheck = 0
			local ok, err = pcall(function()
				check()
			end)
			if not ok then
				warn(`[CitySeasonController] {err}`)
			end
		end
		if sinceFollow >= FOLLOW then
			sinceFollow = 0
			follow()
		end
	end)
end

return CitySeasonController
