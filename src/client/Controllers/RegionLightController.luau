--!strict
-- Level of detail of the regions' glow lights (S46): the lava of the Ashen Wastes has a PointLight every ~40 studs
-- (Logic/AshenGen, light tag "lava", built with the client detail), far more than a scene can afford. Twice a second
-- this controller turns on only the Config.RegionLights[setting] lights nearest to the camera (4 low, 8 mid, 12 high
-- "World detail") and turns the others off; it is the only owner of their `Enabled`. Caves (S48) can register their
-- own tags in TAGS.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.UI.State)

local RegionLightController = {
	Name = "RegionLightController",
}

-- Light holder tags (attribute Fx of the "Light" part) managed here.
local TAGS: { [string]: boolean } = { lava = true }
local EVERY = 0.5

local lights: { [BasePart]: PointLight } = {}
local enabled = true -- admin /worldfx lavaglow off: every managed light stays off

local function limit(): number
	local value = State.Get({ "account", "settings", "decor" })
	local key = if value == "low" or value == "high" then value else "mid"
	return (Config.RegionLights :: any)[key] or 8
end

local function onAdded(instance: Instance)
	if not instance:IsA("BasePart") or instance.Name ~= "Light" then
		return
	end
	local fx = instance:GetAttribute("Fx")
	if type(fx) ~= "string" or not TAGS[fx] then
		return
	end
	local light = instance:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = false
		lights[instance] = light
	end
end

local function onRemoved(instance: Instance)
	if instance:IsA("BasePart") then
		lights[instance] = nil
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local at = camera.Focus.Position
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

function RegionLightController.Init(_registry) end

function RegionLightController.Start()
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
