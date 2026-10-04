--!strict
-- UI sound effects. Ids are built-in Studio assets until real sounds are uploaded (swap ids here only).

local SoundService = game:GetService("SoundService")

local Sounds = {}

local DEFS: { [string]: { id: string, volume: number } } = {
	click = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25 },
	open = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.15 },
	error = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 },
}

local master = 0.8
local instances: { [string]: Sound } = {}

local function getSound(name: string): Sound?
	local existing = instances[name]
	if existing then
		return existing
	end
	local def = DEFS[name]
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = `UI_{name}`
	sound.SoundId = def.id
	sound.Parent = SoundService
	instances[name] = sound
	return sound
end

function Sounds.setVolume(volume: number)
	master = math.clamp(volume, 0, 1)
end

function Sounds.play(name: string)
	local def = DEFS[name]
	if not def or master <= 0 then
		return
	end
	local sound = getSound(name)
	if sound then
		sound.Volume = def.volume * master
		sound.TimePosition = 0
		sound:Play()
	end
end

return Sounds
