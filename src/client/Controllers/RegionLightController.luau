--!strict
-- Level of detail of the regions' glow lights (S46): the lava of the Ashen Wastes has a PointLight every ~40 studs
-- (Logic/AshenGen, light tag "lava", built with the client detail), far more than a scene can afford. Twice a second
-- this controller turns on only the Config.RegionLights[setting] lights nearest to the camera (4 low, 8 mid, 12 high
-- "World detail") and turns the others off; it is the only owner of their `Enabled`. S47: the Frost Peaks' crystals,
-- rune stones and the Ice Watch's loopholes (tag "crystal"). S48: on a cave, crypt or boss chamber map it owns every
-- light of that map (fires, lamps, candles, crystals: any light with an Fx tag) and keeps Config.CaveLights of them on
-- (S134h: 12 low, 16 mid, 24 high; hysteresis of 10 studs, every 0.3 s; admin /lights forces a number). S134h: underground
-- the local player carries one soft warm PointLight (Config.CaveLights.player, no shadows, outside that count), taken
-- off on the surface. W29: on the surface every other light of a Build shares the graphics level's light budget
-- (Config.Graphics.levels[*].lights nearest the camera, Util/LightBudget; low 12); low quality caps "World detail".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local Config = require(ReplicatedStorage.Shared.Config)
local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local LightBudget = require(script.Parent.Parent.Util.LightBudget)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local RegionLightController = {
	Name = "RegionLightController",
}

-- Light holder tags (attribute Fx of the "Light" part) managed here.
local TAGS: { [string]: boolean } = { lava = true, crystal = true } -- S47: crystals, runes, loopholes of the Peaks
local EVERY = 0.3

local lights: { [BasePart]: PointLight } = {}
-- S48: every light holder (fires, lamps, candles, crystals...) for the caves: there this controller owns all the
-- lights of the current map (Config.CaveLights nearest the camera, with hysteresis)
local anyLights: { [BasePart]: PointLight } = {}
local UNDERGROUND: { [string]: boolean } = { cave = true, crypt = true, dungeon = true }
local forced: number? = nil -- admin /lights <n>
local enabled = true -- admin /worldfx lavaglow off: every managed light stays off

-- "World detail" (settings.decor) capped by the graphics level (W29).
local function detailKey(): string
	return GraphicsLevel.detail(
		State.Get({ "account", "settings", "quality" }),
		State.Get({ "account", "settings", "decor" })
	)
end

local function limit(): number
	return (Config.RegionLights :: any)[detailKey()] or 8
end

local function onAdded(instance: Instance)
	if not instance:IsA("BasePart") or instance.Name ~= "Light" then
		return
	end
	local fx = instance:GetAttribute("Fx")
	if type(fx) ~= "string" then
		return
	end
	local light = instance:FindFirstChildOfClass("PointLight")
	if not light then
		return
	end
	anyLights[instance] = light
	if TAGS[fx] then
		light.Enabled = false
		lights[instance] = light
	end
end

local budgetOn: { [BasePart]: boolean } = {}

local function onRemoved(instance: Instance)
	if instance:IsA("BasePart") then
		lights[instance] = nil
		local light = anyLights[instance]
		if light then
			LightBudget.Forget(light)
		end
		anyLights[instance] = nil
		budgetOn[instance] = nil
	end
end

-- W29: on the surface every light the region LOD above does not own (city and road lamps, fires, candles, glows)
-- shares the graphics level's budget (Config.Graphics.levels[*].lights): only the nearest of the wanted ones (a lamp
-- is wanted at night) shine, with 10 studs of hysteresis.
local function updateBudget(at: Vector3)
	local cap = GraphicsLevel.get(State.Get({ "account", "settings", "quality" })).lights
	local list: { GraphicsLevel.Candidate } = {}
	local parts: { BasePart } = {}
	for part, light in anyLights do
		if lights[part] then
			continue
		end
		if not part.Parent then
			anyLights[part] = nil
			budgetOn[part] = nil
			continue
		end
		if not LightBudget.Wanted(light) then
			if budgetOn[part] then
				budgetOn[part] = nil
			end
			LightBudget.SetCapped(light, false)
			continue
		end
		table.insert(parts, part)
		table.insert(list, { d = (part.Position - at).Magnitude, on = budgetOn[part] })
	end
	local keep = GraphicsLevel.nearest(list, cap, 10)
	for i, part in parts do
		local on = keep[i] == true
		budgetOn[part] = on
		local light = anyLights[part]
		if light then
			LightBudget.SetCapped(light, not on)
		end
	end
end

-- The underground map the player is on (cave, crypt, boss chamber), else nil.
local function caveMap(): Maps.MapDef?
	local mapId = State.Get({ "character", "location", "map" })
	local map = if type(mapId) == "string" then Maps.get(mapId) else nil
	return if map and UNDERGROUND[map.biome] then map else nil
end

local caveOn: { [BasePart]: boolean } = {}

-- S134h: the soft light of the local player underground (on the root part; rebuilt after a respawn).
local TORCH = "CaveTorch"
local function setTorch(on: boolean)
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local light = root:FindFirstChild(TORCH) :: PointLight?
	if on and not light then
		local spec = (Config.CaveLights :: any).player
		local created = Instance.new("PointLight")
		created.Name = TORCH
		created.Range = spec.range
		created.Brightness = spec.brightness
		created.Color = Color3.fromHex(spec.color)
		created.Shadows = false
		created.Parent = root
	elseif not on and light then
		light:Destroy()
	end
end

-- Caves: the N lights of the current map nearest the camera, hysteresis of 10 studs for the last few.
local function updateCave(map: Maps.MapDef, at: Vector3)
	local n = forced or (Config.CaveLights :: any)[detailKey()] or 16
	local o = map.offset
	local half = map.size.x / 2 + 40
	local list: { { part: BasePart, d: number } } = {}
	for part in anyLights do
		if not part.Parent then
			anyLights[part] = nil
			caveOn[part] = nil
		else
			local p = part.Position
			if math.abs(p.X - o.x) < half and math.abs(p.Z - o.z) < half then
				local d = (p - at).Magnitude - (if caveOn[part] then 10 else 0)
				table.insert(list, { part = part, d = d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	for i, entry in list do
		local on = i <= n and enabled
		caveOn[entry.part] = on
		local light = anyLights[entry.part]
		if light and light.Enabled ~= on then
			light.Enabled = on
		end
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.Focus.Position
	local cave = caveMap()
	setTorch(cave ~= nil)
	if cave then
		updateCave(cave, at)
		return
	end
	updateBudget(at)
	local list: { { part: BasePart, d: number } } = {}
	for part in lights do
		if part.Parent then
			table.insert(list, { part = part, d = (part.Position - at).Magnitude })
		else
			lights[part] = nil
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	local n = if enabled then limit() else 0
	for i, entry in list do
		local light = lights[entry.part]
		local on = i <= n
		if light and light.Enabled ~= on then
			light.Enabled = on
		end
	end
end

-- Number of managed lights and how many are on (admin /regionstats on the client, tests of the scene).
function RegionLightController.Stats(): (number, number)
	local total, on = 0, 0
	for _, light in lights do
		total += 1
		if light.Enabled then
			on += 1
		end
	end
	return total, on
end

-- Admin /worldfx lavaglow: false keeps every managed light off (to compare the frame rate).
function RegionLightController.SetEnabled(on: boolean)
	enabled = on
end

-- Admin /lights <n|auto> (S48): force the number of cave lights on this client (nil = the setting).
function RegionLightController.ForceLights(n: number?)
	forced = n
end

-- Cave lights of the current map: total and on (admin /caveinfo, /lights).
function RegionLightController.CaveStats(): (number, number)
	local total, on = 0, 0
	for part, isOn in caveOn do
		if part.Parent then
			total += 1
			if isOn then
				on += 1
			end
		end
	end
	return total, on
end

function RegionLightController.Init(_registry) end

function RegionLightController.Start()
	-- S48: admin /lights <n|auto> (cave lights forced on this client)
	Net.On("AdminClient", function(action: any, arg: any)
		if action == "lights" then
			RegionLightController.ForceLights(if type(arg) == "number" then arg else nil)
		end
	end)
	for _, instance in CollectionService:GetTagged(BlueprintBuild.FX_TAG) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(BlueprintBuild.FX_TAG):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(BlueprintBuild.FX_TAG):Connect(onRemoved)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < EVERY then
			return
		end
		elapsed = 0
		local ok, err = pcall(function()
			update()
		end)
		if not ok then
			warn(`[RegionLightController] {err}`)
		end
	end)
end

return RegionLightController
