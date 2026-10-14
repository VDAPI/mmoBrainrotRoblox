--!strict
-- UI sound effects. S111: every name first asks the router (SfxController: click -> ui.click, error -> ui.error,
-- open -> ui.click quieter, levelUp -> ui.levelup, S120: coin -> ui.coin); a key with a sound plays from Data/Sfx, otherwise the old
-- placeholder below plays. Every Sound goes through the "Effects" sound group (setGroup), whose volume is the
-- settings.volume option (SettingsController), so nothing here scales by the option any more.

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- Only files shipped with the Roblox client (content/sounds) are used, varied by pitch.
local DEFS: { [string]: { id: string, volume: number, speed: number? } } = {
	click = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.35 },
	open = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.25, speed = 0.8 },
	error = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.45, speed = 0.55 },
	levelUp = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.7, speed = 0.6 },
	-- S120: purchases for Dragon Currency (routed to ui.coin; this placeholder only without the router's sound).
	coin = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.6, speed = 0.9 },
	-- Gathering and the smith's upgrade ticks (not routed: no Data/Sfx key).
	hit = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.3, speed = 1.7 },
}

local master = 1
local group: SoundGroup? = nil
local router: ((name: string) -> boolean)? = nil
local instances: { [string]: Sound } = {}

local function muted(): boolean
	local g = group
	return master <= 0 or (g ~= nil and g.Volume <= 0)
end

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
	sound.SoundGroup = group
	sound.Parent = SoundService
	instances[name] = sound
	return sound
end

-- S111: the "Effects" sound group (SettingsController.SfxGroup) every sound here plays through.
function Sounds.setGroup(soundGroup: SoundGroup)
	group = soundGroup
	for _, sound in instances do
		sound.SoundGroup = soundGroup
	end
end

-- S111: `fn(name)` returns true when it played the name itself (Data/Sfx through SfxController).
function Sounds.setRouter(fn: (name: string) -> boolean)
	router = fn
end

-- Kept for compatibility (S14); the group volume (settings.volume) does the scaling since S111.
function Sounds.setVolume(volume: number)
	master = math.clamp(volume, 0, 1)
end

-- Plays a sound at a custom pitch (upgrade tension, combos). Uses a fresh Sound so overlapping plays work.
function Sounds.playPitched(name: string, speed: number)
	local def = DEFS[name]
	if not def or muted() then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = def.volume * master
	sound.PlaybackSpeed = speed
	sound.SoundGroup = group
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- S28: a sound by asset id, 2D. Empty ids do nothing. S111: unused by the game (skills play Data/Sfx keys through
-- SfxController); kept for compatibility.
function Sounds.playId(id: string, volume: number?)
	if id == "" or muted() then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (volume or 0.6) * master
	sound.SoundGroup = group
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function Sounds.play(name: string)
	local route = router
	if route and route(name) then
		return
	end
	local def = DEFS[name]
	if not def or muted() then
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
