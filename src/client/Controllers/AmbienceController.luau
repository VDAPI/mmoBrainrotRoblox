--!strict
-- Mood of the area the player stands in (S26, Data/Ambience): light and sound.
--   * light: the area's modulation (fog, tint, saturation, brightness, haze) blends from the previous one over
--     Ambience.BLEND seconds and goes to WorldController.SetModulation, which applies it on top of the map's light
--     and the day and night cycle (never replacing them),
--   * sound: the area's day or night loops (night from Logic/DayCycle on maps with the cycle), at most
--     Ambience.MAX_LOOPS at a time, crossfaded; positional loops of the map (waterfall, fires, drums) as 3D sounds.
--     All through the "VaelthornAmbientGroup" SoundGroup (the "Ambience" option). Entries without an id are skipped.
-- Admin /ambience <area|off> forces a mood (AdminClient "ambience").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ambience = require(ReplicatedStorage.Shared.Data.Ambience)
local AreaState = require(script.Parent.Parent.UI.AreaState)
local CaveTerrain = require(ReplicatedStorage.Shared.Logic.CaveTerrain)
local MapTerrain = require(ReplicatedStorage.Shared.Logic.MapTerrain)
local DayCycle = require(ReplicatedStorage.Shared.Logic.DayCycle)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local AmbienceController = {
	Name = "AmbienceController",
	Deps = { "WorldController", "SettingsController" },
}

local WorldController: any
local SettingsController: any

local FADE = 1.6
local WHITE = Color3.new(1, 1, 1)

type Mod = {
	fogScale: number,
	fogColor: Color3,
	fogMix: number,
	tint: Color3,
	tintMix: number,
	saturation: number,
	brightness: number,
	haze: number,
	density: number,
}

local function identity(): Mod
	return {
		fogScale = 1,
		fogColor = WHITE,
		fogMix = 0,
		tint = WHITE,
		tintMix = 0,
		saturation = 0,
		brightness = 1,
		haze = 0,
		density = 0,
	}
end

local function modOf(mood: Ambience.Mood?): Mod
	local m = identity()
	if mood then
		m.fogScale = mood.fogScale or 1
		m.fogColor = if mood.fogColor then Color3.fromHex(mood.fogColor) else WHITE
		m.fogMix = if mood.fogColor then mood.fogMix or 0.5 else 0
		m.tint = if mood.tint then Color3.fromHex(mood.tint) else WHITE
		m.tintMix = if mood.tint then mood.tintMix or 0.5 else 0
		m.saturation = mood.saturation or 0
		m.brightness = mood.brightness or 1
		m.haze = mood.haze or 0
		m.density = mood.density or 0
	end
	return m
end

local function lerpMod(a: Mod, b: Mod, t: number): Mod
	local function l(x: number, y: number): number
		return x + (y - x) * t
	end
	return {
		fogScale = l(a.fogScale, b.fogScale),
		-- a colour with no weight takes the other side's colour, so the blend never passes through white
		fogColor = (if a.fogMix <= 0 then b.fogColor else a.fogColor):Lerp(
			if b.fogMix <= 0 then a.fogColor else b.fogColor,
			t
		),
		fogMix = l(a.fogMix, b.fogMix),
		tint = (if a.tintMix <= 0 then b.tint else a.tint):Lerp(if b.tintMix <= 0 then a.tint else b.tint, t),
		tintMix = l(a.tintMix, b.tintMix),
		saturation = l(a.saturation, b.saturation),
		brightness = l(a.brightness, b.brightness),
		haze = l(a.haze, b.haze),
		density = l(a.density, b.density),
	}
end

local function close(a: Mod, b: Mod): boolean
	return math.abs(a.fogScale - b.fogScale) < 0.002
		and math.abs(a.fogMix - b.fogMix) < 0.002
		and math.abs(a.tintMix - b.tintMix) < 0.002
		and math.abs(a.saturation - b.saturation) < 0.002
		and math.abs(a.brightness - b.brightness) < 0.002
		and math.abs(a.haze - b.haze) < 0.005
		and math.abs(a.density - b.density) < 0.002
end

local current: Mod = identity()
local settled = true -- current equals the target and was handed to WorldController
local forced: string? = nil -- area id, "off", or nil (follow the player)
local group: SoundGroup

-- Loops ----------------------------------------------------------------------------------------------------------

type Loop = { sound: Sound, entry: Ambience.Sound, wanted: boolean }
local loops: { [string]: Loop } = {} -- by sound id

local function setLoops(entries: { Ambience.Sound })
	local wanted: { [string]: Ambience.Sound } = {}
	local n = 0
	for _, entry in entries do
		if entry.id ~= "" and not wanted[entry.id] and n < Ambience.MAX_LOOPS then
			wanted[entry.id] = entry
			n += 1
		end
	end
	for id, loop in loops do
		if not wanted[id] and loop.wanted then
			loop.wanted = false
			local tween = TweenService:Create(loop.sound, TweenInfo.new(FADE), { Volume = 0 })
			tween.Completed:Connect(function()
				if not loop.wanted then
					loop.sound:Destroy()
					if loops[id] == loop then
						loops[id] = nil
					end
				end
			end)
			tween:Play()
		end
	end
	for id, entry in wanted do
		local loop = loops[id]
		if not loop then
			local sound = Instance.new("Sound")
			sound.Name = "Ambience"
			sound.SoundId = id
			sound.Looped = true
			sound.Volume = 0
			sound.SoundGroup = group
			sound.Parent = SoundService
			sound:Play()
			loop = { sound = sound, entry = entry, wanted = true }
			loops[id] = loop
		end
		assert(loop, "loop")
		loop.wanted = true
		TweenService:Create(loop.sound, TweenInfo.new(FADE), { Volume = entry.volume }):Play()
	end
end

-- Positional loops of the current map.
local pointMap: string? = nil
local pointFolder: Folder? = nil
local pointSounds: { { sound: Sound, night: boolean?, volume: number } } = {}

local function buildPoints(mapId: string?)
	if pointMap == mapId then
		return
	end
	pointMap = mapId
	if pointFolder then
		pointFolder:Destroy()
		pointFolder = nil
	end
	table.clear(pointSounds)
	local map = mapId and Maps.get(mapId)
	local list = mapId and Ambience.points[mapId]
	if not map or not list then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_AmbiencePoints"
	folder.Parent = Workspace
	pointFolder = folder
	for _, p in list do
		if p.sound.id ~= "" then
			local holder = Instance.new("Part")
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.one
			-- S48: over the floor of a cave on the engine (or the point's own y)
			local floor = MapTerrain.height(map.id, p.x, p.z) or 0
			holder.Position = Vector3.new(map.offset.x + p.x, map.offset.y + (p.y or floor + 6), map.offset.z + p.z)
			holder.Parent = folder
			local sound = Instance.new("Sound")
			sound.SoundId = p.sound.id
			sound.Looped = true
			sound.Volume = p.sound.volume
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = p.radius * 0.25
			sound.RollOffMaxDistance = p.radius
			sound.SoundGroup = group
			sound.Parent = holder
			sound:Play()
			table.insert(pointSounds, { sound = sound, night = p.night, volume = p.sound.volume })
		end
	end
end

-- Tick -----------------------------------------------------------------------------------------------------------

local lastKey = ""

local function rootPart(): BasePart?
	local character = game:GetService("Players").LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isNight(): boolean
	if not WorldController.HasDayNight() then
		return false
	end
	local clock = WorldController.TimeOfDay()
	return DayCycle.isNight(clock)
end

local function step(dt: number)
	local mapId = State.Get({ "character", "location", "map" })
	local playing = State.Get({ "session", "phase" }) == "playing"
	local map = if type(mapId) == "string" and playing then mapId else nil
	buildPoints(map)
	local areaId: string? = nil
	if forced and forced ~= "off" then
		areaId = forced
	elseif not forced then
		local area = Fusion.peek(AreaState.Current)
		areaId = if area then area.id else nil
	end
	local mood = if map and forced ~= "off" then Ambience.moodOf(map, areaId) else nil
	-- S48: caves on the engine: the mood of the room under the player (tunnels: the map's), "/ambience <cave>:<room>"
	local roomIndex: number? = nil
	if map and CaveTerrain.has(map) and forced ~= "off" then
		local forcedRoom = if forced then tonumber(string.match(forced, ":(%d+)$")) else nil
		if forcedRoom then
			roomIndex = forcedRoom
		else
			local root = rootPart()
			local def = Maps.get(map)
			if root and def then
				roomIndex = CaveTerrain.roomAt(map, root.Position.X - def.offset.x, root.Position.Z - def.offset.z)
			end
		end
		mood = Ambience.roomMood(map, roomIndex) or Ambience.moodOf(map, nil)
	end
	-- light: approach the target (about 95 % after Ambience.BLEND seconds)
	local target = modOf(mood)
	if not close(current, target) then
		settled = false
		current = lerpMod(current, target, 1 - math.exp(-dt * 3 / Ambience.BLEND))
		WorldController.SetModulation(current)
	elseif not settled then
		-- arrived: snap to the target once (no modulation at all outside every mood)
		settled = true
		current = target
		WorldController.SetModulation(if mood then current else nil)
	end
	-- sound: change the set when the area or day/night changes
	local night = isNight()
	local key = `{map or ""}|{areaId or ""}|{roomIndex or ""}|{night}|{forced or ""}`
	if key ~= lastKey then
		lastKey = key
		setLoops(if mood then (if night then mood.sounds.night else mood.sounds.day) else {})
		for _, p in pointSounds do
			local on = p.night == nil or p.night == night
			TweenService:Create(p.sound, TweenInfo.new(FADE), { Volume = if on then p.volume else 0 }):Play()
		end
	end
end

function AmbienceController.Init(registry)
	WorldController = registry.Get("WorldController")
	SettingsController = registry.Get("SettingsController")
end

function AmbienceController.Start()
	group = SettingsController.AmbientGroup()
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "ambience" then
			forced = if arg == "auto" then nil elseif type(arg) == "string" then arg else nil
			lastKey = ""
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		local elapsed = accumulator
		accumulator = 0
		local ok, err = pcall(function()
			step(elapsed)
		end)
		if not ok then
			warn(`[AmbienceController] {err}`)
		end
	end)
end

return AmbienceController
