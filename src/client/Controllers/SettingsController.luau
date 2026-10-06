--!strict
-- Applies the options (S14) on the client: effects quality (low = particle rates cut to a third on every
-- ParticleEmitter in the world, original rate remembered in an attribute), music volume (SoundGroup
-- "Music", used by the map music), ambience volume (S26, SoundGroup of AmbienceController's loops), camera
-- sensitivity (UserInputService.MouseDeltaSensitivity).
-- Effects volume, damage numbers, quick cast and confirmations are read where they are used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.UI.State)

local SettingsController = {
	Name = "SettingsController",
}

local LOW_FACTOR = 1 / 3

local scope = Fusion.scoped(Fusion)
local musicGroup: SoundGroup
local ambientGroup: SoundGroup

-- Sound group the map music plays through (WorldController).
function SettingsController.MusicGroup(): SoundGroup
	return musicGroup
end

-- Sound group of the area ambience loops (S26, AmbienceController).
function SettingsController.AmbientGroup(): SoundGroup
	return ambientGroup
end

local function lowQuality(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

local function adjust(emitter: ParticleEmitter)
	local base = emitter:GetAttribute("VaelthornOriginalRate")
	if type(base) ~= "number" then
		base = emitter.Rate
		emitter:SetAttribute("VaelthornOriginalRate", base)
	end
	emitter.Rate = if lowQuality() then (base :: number) * LOW_FACTOR else base :: number
end

local function adjustAll()
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			adjust(descendant)
		end
	end
end

function SettingsController.Init()
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "VaelthornMusicGroup"
	musicGroup.Volume = 0.6
	musicGroup.Parent = SoundService
	ambientGroup = Instance.new("SoundGroup")
	ambientGroup.Name = "VaelthornAmbientGroup"
	ambientGroup.Volume = 0.7
	ambientGroup.Parent = SoundService
end

function SettingsController.Start()
	scope:Observer(State.Value({ "account", "settings", "quality" })):onBind(adjustAll)
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ParticleEmitter") and lowQuality() then
			task.defer(adjust, descendant)
		end
	end)
	scope:Observer(State.Value({ "account", "settings", "musicVolume" })):onBind(function()
		local value = State.Get({ "account", "settings", "musicVolume" })
		musicGroup.Volume = if type(value) == "number" then value else 0.6
	end)
	scope:Observer(State.Value({ "account", "settings", "ambientVolume" })):onBind(function()
		local value = State.Get({ "account", "settings", "ambientVolume" })
		ambientGroup.Volume = if type(value) == "number" then value else 0.7
	end)
	scope:Observer(State.Value({ "account", "settings", "cameraSens" })):onBind(function()
		local value = State.Get({ "account", "settings", "cameraSens" })
		UserInputService.MouseDeltaSensitivity = if type(value) == "number" then value else 1
	end)
end

return SettingsController
