--!strict
-- UI sound effects. Placeholders until real sounds are uploaded (swap ids here only).

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- Only files shipped with the Roblox client (content/sounds) are used, varied by pitch.
local DEFS: { [string]: { id: string, volume: number, speed: number? } } = {
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35 },
	open = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.25, speed = 0.8 },
	error = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.45, speed = 0.55 },
	levelUp = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.7, speed = 0.6 },
	-- Hit sound for basic attacks; swap per weapon type once real sounds exist.
	hit = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.3, speed = 1.7 },
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
	sound.PlaybackSpeed = def.speed or 1
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
