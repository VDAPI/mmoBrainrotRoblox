--!strict
-- Applies the options (S14) on the client: effects quality (low = particle rates cut to a third on every
-- ParticleEmitter in the world, original rate remembered in an attribute; W01: medium = Config.Graphics factor), music volume (SoundGroup
-- "Music", used by the map music), ambience volume (S26, SoundGroup of AmbienceController's loops), camera
-- sensitivity (UserInputService.MouseDeltaSensitivity), effects volume (S111: SoundGroup "Effects" of every combat,
-- monster and interface sound, SfxController and UI/Sounds; the existing settings.volume row "Effects volume").
-- Damage numbers, quick cast and confirmations are read where they are used.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.UI.State)

local SettingsController = {
	Name = "SettingsController",
}

local scope = Fusion.scoped(Fusion)
local musicGroup: SoundGroup
local ambientGroup: SoundGroup
local sfxGroup: SoundGroup

-- Sound group the map music plays through (WorldController).
function SettingsController.MusicGroup(): SoundGroup
	return musicGroup
end

-- Sound group of the area ambience loops (S26, AmbienceController).
function SettingsController.AmbientGroup(): SoundGroup
	return ambientGroup
end

-- S111: sound group of the sound effects (SfxController, UI/Sounds), volume settings.volume.
function SettingsController.SfxGroup(): SoundGroup
	return sfxGroup
end

-- Particle rate factor of the graphics level (W01: low 1/3 as in S14, medium in between, high 1).
local function particleFactor(): number
	local quality = State.Get({ "account", "settings", "quality" })
	local levels = (Config.Graphics.levels :: any) :: { [string]: { particles: number } }
	local level = if type(quality) == "string" then levels[quality] else nil
	return if level then level.particles else 1
end

local function adjust(emitter: ParticleEmitter)
	local base = emitter:GetAttribute("VaelthornOriginalRate")
	if type(base) ~= "number" then
		base = emitter.Rate
		emitter:SetAttribute("VaelthornOriginalRate", base)
	end
	emitter.Rate = (base :: number) * particleFactor()
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
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "VaelthornSfxGroup"
	sfxGroup.Volume = 0.8
	sfxGroup.Parent = SoundService
end

function SettingsController.Start()
	scope:Observer(State.Value({ "account", "settings", "quality" })):onBind(adjustAll)
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ParticleEmitter") and particleFactor() < 1 then
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
	scope:Observer(State.Value({ "account", "settings", "volume" })):onBind(function()
		local value = State.Get({ "account", "settings", "volume" })
		sfxGroup.Volume = if type(value) == "number" then value else 0.8
	end)
	scope:Observer(State.Value({ "account", "settings", "cameraSens" })):onBind(function()
		local value = State.Get({ "account", "settings", "cameraSens" })
		UserInputService.MouseDeltaSensitivity = if type(value) == "number" then value else 1
	end)
end

return SettingsController
