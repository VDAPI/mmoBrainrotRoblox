--!strict
-- Sound effects (S111, DESIGN-16 §3, docs/ANIMACJE.md §7): plays Data/Sfx keys for combat, monsters, bosses and the
-- interface through the "Effects" sound group (SettingsController.SfxGroup, option settings.volume).
--   Play(key, at, who?, source?, volumeMul?)   positional, at a point or on a model (follows its root while playing)
--   Ui(key, volumeMul?)                          2D interface sound
--   After(seconds, key, at, ...)                 Play on the effect clock (Vfx/Clock), for sounds timed to a motion
--   WhoOf(model)                                 own / party / other: priority and volume (Logic/SfxRules)
-- A pool of Config.Sfx.maxVoices anchored parts with one Sound each (desktop 16, phone 10) is made at Start; no
-- Sound is created per play. A full pool takes the voice of the lowest priority (then the oldest) or drops the new
-- sound; the same key within repeatWindow s is dropped, keys with a cooldown wait per source; nothing positional plays
-- farther than maxDistance from the camera. AnimLab freezing the effect clock pauses every playing voice.
-- Monsters (Workspace.Monsters): death, aggro on us and boss phases are heard here (attributes Dead, AggroUserId,
-- Phase); attacks and hits come from CombatFxController, skills from VfxController. UI/Sounds asks the router first
-- (click, error, open, levelUp), so a key without ids keeps the old placeholder. No remote, no saved field.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Sfx = require(ReplicatedStorage.Shared.Data.Sfx)
local SfxRules = require(ReplicatedStorage.Shared.Logic.SfxRules)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)

local SfxController = {
	Name = "SfxController",
	Deps = { "SettingsController" },
}

export type Who = SfxRules.Who
-- What a monster model sounds like: its family, the boss id (bosses) and the hit material.
export type MobInfo = { family: string, boss: string?, material: string }

local CFG = Config.Sfx
local GRACE = 0.25 -- seconds a voice may take to start before a silent one counts as free
local PRUNE_EVERY = 30 -- seconds between two clean-ups of the per-source cooldown records
local KEEP_SOURCE = 10 -- seconds a per-source record is kept
-- The server clears AggroUserId just before it sets Dead: a death this soon after the monster dropped us is ours.
local DEATH_AGGRO_WINDOW = 1

local player = Players.LocalPlayer
local settings: any = nil
local random = Random.new()

local group: SoundGroup? = nil
local voices: { SfxRules.Voice } = {}
local voiceSounds: { Sound } = {}
local voiceParts: { Part } = {}
local following: { [number]: Model } = {}
local uiSounds: { Sound } = {}
local uiStarted: { number } = {}
local previewPart: Part? = nil
local previewSound: Sound? = nil
local previewUi: Sound? = nil

local lastByKey: { [string]: number } = {}
local lastBySource: { [string]: number } = {}
local stats = { dropped = 0, played = 0, preloaded = 0, preloadTotal = 0 }
local wasFrozen = false
local prunedAt = 0

-- Router of UI/Sounds names: placeholder name -> key and volume factor.
local ROUTES: { [string]: { key: string, mul: number } } = {
	click = { key = "ui.click", mul = 1 },
	error = { key = "ui.error", mul = 1 },
	open = { key = "ui.click", mul = 0.6 },
	levelUp = { key = "ui.levelup", mul = 1 },
}

-- Helpers ---------------------------------------------------------------------------------------------------

local function lowQuality(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

local function isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function rootOf(model: Model): BasePart?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model:FindFirstChildWhichIsA("BasePart")
end

-- World position of a point or a model in the world (nil: a model outside Workspace, e.g. a window preview).
local function positionOf(at: Vector3 | Model): Vector3?
	if typeof(at) == "Vector3" then
		return at
	end
	local model = at :: Model
	if not model.Parent or not model:IsDescendantOf(Workspace) then
		return nil
	end
	local root = rootOf(model)
	return if root then root.Position else model:GetPivot().Position
end

local function inParty(userId: number): boolean
	local party = State.Get({ "party" })
	if type(party) ~= "table" or type(party.members) ~= "table" then
		return false
	end
	for _, member in party.members do
		if type(member) == "table" and member.id == userId then
			return true
		end
	end
	return false
end

local function sourceOf(model: Model): string
	local id = model:GetAttribute("EntityId")
	return if type(id) == "string" then id else model.Name
end

local function free(index: number)
	voices[index].busy = false
	following[index] = nil
end

-- Public: who and what -----------------------------------------------------------------------------------------

-- Who caused an event involving `model`: our character (and AnimLab / preview models) -> own; a party member, or a
-- monster fighting us -> party; anyone else -> other.
function SfxController.WhoOf(model: Model?): Who
	if not model then
		return "other"
	end
	if model == player.Character or model:GetAttribute("VaelthornPreview") == true then
		return "own"
	end
	local other = Players:GetPlayerFromCharacter(model)
	if other then
		return if inParty(other.UserId) then "party" else "other"
	end
	if model:GetAttribute("AggroUserId") == player.UserId then
		return "party"
	end
	return "other"
end

-- The higher of two priorities (a hit on us is ours whoever struck it).
SfxController.Higher = SfxRules.higher

local infoCache: { [Model]: MobInfo | false } = setmetatable({} :: any, { __mode = "k" })
local materialByLook: { [string]: string } = {}

-- Family, boss id and hit material of a monster model (nil: not a monster).
function SfxController.Mob(model: Model?): MobInfo?
	if not model then
		return nil
	end
	local cached = infoCache[model]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: MobInfo
	end
	-- AnimLab stage looks carry PreviewMonsterId (no MonsterId: they are not monsters of the world)
	local id = model:GetAttribute("MonsterId") or model:GetAttribute("PreviewMonsterId")
	if type(id) ~= "string" then
		return nil
	end
	local boss = Bosses.get(id)
	local monster = if boss then nil else Monsters.get(id)
	local family = if boss then boss.family elseif monster then monster.family else nil
	if not family then
		infoCache[model] = false
		return nil
	end
	local lookId = model:GetAttribute("Look")
	local look = if type(lookId) == "string" then lookId else id
	local material = materialByLook[look]
	if not material then
		local def = MonsterLooks.get(look)
		material = SfxRules.material(family, if def then def.hitSound else nil)
		materialByLook[look] = material
	end
	local info: MobInfo = { family = family, boss = if boss then id else nil, material = material :: string }
	infoCache[model] = info
	return info
end

-- The key `<suffix>` of a monster model: boss.<id>.<suffix> for bosses, mob.<family>.<suffix> otherwise.
function SfxController.MobKey(model: Model?, suffix: string): string?
	local info = SfxController.Mob(model)
	if not info then
		return nil
	end
	return if info.boss then `boss.{info.boss}.{suffix}` else `mob.{info.family}.{suffix}`
end

-- Playing ------------------------------------------------------------------------------------------------------

local function playUi(def: Sfx.Def, volumeMul: number?)
	if #uiSounds == 0 then
		return
	end
	local index = 1
	for i, sound in uiSounds do
		if not sound.IsPlaying then
			index = i
			break
		end
		if uiStarted[i] < uiStarted[index] then
			index = i
		end
	end
	local sound = uiSounds[index]
	local variant = SfxRules.variant(def, random:NextNumber()) :: number
	sound:Stop()
	sound.SoundId = def.ids[variant]
	sound.Volume = def.volume * (volumeMul or 1)
	sound.PlaybackSpeed = SfxRules.pitch(def, random:NextNumber())
	sound.TimePosition = 0
	sound:Play()
	uiStarted[index] = os.clock()
	stats.played += 1
end

-- 2D interface sound. Returns true when the key has a sound (played, or dropped as a repeat): the caller then does
-- not play a placeholder.
function SfxController.Ui(key: string, volumeMul: number?): boolean
	local def = Sfx.get(key)
	if not def or #def.ids == 0 then
		return false
	end
	local now = os.clock()
	if not SfxRules.allowed(lastByKey, lastBySource, key, nil, now, def, CFG.repeatWindow) then
		return true
	end
	lastByKey[key] = now
	playUi(def, volumeMul)
	return true
end

-- Positional sound at `at` (a point) or on `at` (a model, followed while playing). `who` decides priority and
-- volume; `source` (EntityId / model name) feeds the per-source cooldown; `volumeMul` scales this play (a quiet
-- block for absorbed hits). Unknown or silent keys do nothing; returns whether the sound started.
function SfxController.Play(key: string, at: Vector3 | Model, who: Who?, source: string?, volumeMul: number?): boolean
	local def = Sfx.get(key)
	if not def or #def.ids == 0 or Clock.frozen() then
		return false
	end
	if def.ui then
		return SfxController.Ui(key, volumeMul)
	end
	if #voices == 0 then
		return false
	end
	local position = positionOf(at)
	if not position then
		return false
	end
	local camera = Workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > CFG.maxDistance then
		return false
	end
	local now = os.clock()
	if not SfxRules.allowed(lastByKey, lastBySource, key, source, now, def, CFG.repeatWindow) then
		return false
	end
	local whoNow: Who = who or "other"
	local priority = SfxRules.PRIORITY[whoNow] or 1
	local index = SfxRules.pickVoice(voices, priority)
	if not index then
		stats.dropped += 1
		return false
	end
	lastByKey[key] = now
	if source and def.cooldown then
		lastBySource[SfxRules.sourceKey(key, source)] = now
	end
	local sound = voiceSounds[index]
	local part = voiceParts[index]
	local variant = SfxRules.variant(def, random:NextNumber()) :: number
	sound:Stop()
	sound.SoundId = def.ids[variant]
	sound.Volume = SfxRules.volume(def, whoNow, lowQuality(), CFG) * (volumeMul or 1)
	sound.PlaybackSpeed = SfxRules.pitch(def, random:NextNumber())
	sound.RollOffMaxDistance = def.roll
	sound.RollOffMinDistance = def.roll * 0.1
	part.CFrame = CFrame.new(position)
	if typeof(at) == "Instance" then
		following[index] = at :: Model
	else
		following[index] = nil
	end
	local voice = voices[index]
	voice.busy = true
	voice.priority = priority
	voice.startedAt = now
	sound.TimePosition = 0
	sound:Play()
	stats.played += 1
	return true
end

-- Play after `seconds` on the effect clock (AnimLab freezing it holds the sound too).
function SfxController.After(
	seconds: number,
	key: string,
	at: Vector3 | Model,
	who: Who?,
	source: string?,
	volumeMul: number?
)
	if not Sfx.playable(key) then
		return
	end
	if seconds <= 0 then
		SfxController.Play(key, at, who, source, volumeMul)
		return
	end
	Clock.after(seconds, function()
		SfxController.Play(key, at, who, source, volumeMul)
	end)
end

function SfxController.Stats(): { [string]: number }
	local busy = 0
	for _, voice in voices do
		if voice.busy then
			busy += 1
		end
	end
	return {
		voices = #voices,
		busy = busy,
		dropped = stats.dropped,
		played = stats.played,
		preloaded = stats.preloaded,
		preloadTotal = stats.preloadTotal,
	}
end

-- AnimLab --------------------------------------------------------------------------------------------------------

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

-- Plays `id` once on the preview sound (2D or at `at`) and waits up to Config.Sfx.previewWait s for it to load.
local function audition(id: string, def: Sfx.Def?, at: Vector3?): { [string]: any }
	local sound = if def and def.ui then previewUi elseif at then previewSound else previewUi
	local part = previewPart
	if not sound then
		return { ok = false, error = "not started" }
	end
	if at and part and sound == previewSound then
		part.CFrame = CFrame.new(at)
	end
	sound:Stop()
	sound.SoundId = id
	sound.Volume = if def then def.volume else 0.6
	sound.PlaybackSpeed = if def then SfxRules.pitch(def, random:NextNumber()) else 1
	if def then
		sound.RollOffMaxDistance = math.max(def.roll, 10)
		sound.RollOffMinDistance = math.max(def.roll, 10) * 0.1
	end
	sound.TimePosition = 0
	sound:Play()
	local deadline = os.clock() + CFG.previewWait
	while not sound.IsLoaded and os.clock() < deadline do
		task.wait()
	end
	return { ok = sound.IsLoaded, id = id, loaded = sound.IsLoaded, length = round(sound.TimeLength) }
end

-- AnimLab: plays a key (variant n or a random one) at `at` (interface keys 2D); returns { key, id, loaded, length,
-- voices } or { ok = false, error = "unknown" | "empty" }.
function SfxController.Preview(key: string, variant: number?, at: Vector3?): { [string]: any }
	local def = Sfx.get(key)
	if not def then
		return { ok = false, error = "unknown", key = key }
	end
	if #def.ids == 0 then
		return { ok = false, error = "empty", key = key, hint = def.hint }
	end
	local n = if variant then math.clamp(variant, 1, #def.ids) else SfxRules.variant(def, random:NextNumber()) :: number
	local result = audition(def.ids[n], def, if def.ui then nil else at)
	result.key = key
	result.n = n
	result.variants = #def.ids
	result.voices = #voices
	return result
end

-- AnimLab: plays a raw id once (D3 audition); returns { id, loaded, length }.
function SfxController.Audition(id: string, at: Vector3?): { [string]: any }
	return audition(id, nil, at)
end

-- Monsters -------------------------------------------------------------------------------------------------------

local watched: { [Model]: { RBXScriptConnection } } = {}
local roared: { [Model]: boolean } = setmetatable({} :: any, { __mode = "k" })

local function unwatch(model: Model)
	local connections = watched[model]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watched[model] = nil
	end
end

local function watch(child: Instance)
	if not child:IsA("Model") or watched[child] then
		return
	end
	local model = child :: Model
	if not SfxController.Mob(model) then
		return
	end
	local connections: { RBXScriptConnection } = {}
	local lastAggro = model:GetAttribute("AggroUserId")
	local droppedUsAt = -math.huge
	table.insert(
		connections,
		model:GetAttributeChangedSignal("Dead"):Connect(function()
			if model:GetAttribute("Dead") == true then
				local key = SfxController.MobKey(model, "death")
				if key then
					local who: Who = SfxController.WhoOf(model)
					if who == "other" and os.clock() - droppedUsAt < DEATH_AGGRO_WINDOW then
						who = "party"
					end
					SfxController.Play(key, model, who, sourceOf(model))
				end
			end
		end)
	)
	table.insert(
		connections,
		model:GetAttributeChangedSignal("AggroUserId"):Connect(function()
			local aggro = model:GetAttribute("AggroUserId")
			if aggro == nil and lastAggro == player.UserId then
				droppedUsAt = os.clock()
			end
			lastAggro = aggro
			if aggro ~= player.UserId or model:GetAttribute("Dead") == true then
				return
			end
			local info = SfxController.Mob(model)
			if not info then
				return
			end
			if info.boss then
				-- a boss roars once when it first turns on us; later phases roar again (Phase)
				if not roared[model] then
					roared[model] = true
					SfxController.Play(`boss.{info.boss}.roar`, model, "party", sourceOf(model))
				end
			else
				SfxController.Play(`mob.{info.family}.aggro`, model, "party", sourceOf(model))
			end
		end)
	)
	table.insert(
		connections,
		model:GetAttributeChangedSignal("Phase"):Connect(function()
			local phase = model:GetAttribute("Phase")
			local info = SfxController.Mob(model)
			if not info or not info.boss or type(phase) ~= "number" or phase <= 1 then
				return
			end
			local who: Who = SfxController.WhoOf(model)
			SfxController.Play(`boss.{info.boss}.roar`, model, who, sourceOf(model))
			SfxController.Play(`boss.{info.boss}.phase`, model, who, sourceOf(model))
		end)
	)
	table.insert(
		connections,
		model.Destroying:Connect(function()
			unwatch(model)
		end)
	)
	watched[model] = connections
end

local function watchMonsters()
	local monsters = Workspace:WaitForChild("Monsters", 60)
	if not monsters then
		return
	end
	for _, child in monsters:GetChildren() do
		watch(child)
	end
	monsters.ChildAdded:Connect(function(child)
		-- atomic streaming delivers the whole model; one frame lets its attributes settle
		task.defer(watch, child)
	end)
	monsters.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			unwatch(child)
		end
	end)
end

-- Frame loop -------------------------------------------------------------------------------------------------------

local function step()
	local frozen = Clock.frozen()
	if frozen ~= wasFrozen then
		wasFrozen = frozen
		for i, voice in voices do
			if voice.busy then
				if frozen then
					voiceSounds[i]:Pause()
				else
					voiceSounds[i]:Resume()
				end
			end
		end
	end
	if frozen then
		return
	end
	local now = os.clock()
	for i, voice in voices do
		if voice.busy then
			local sound = voiceSounds[i]
			if not sound.IsPlaying and now - voice.startedAt > GRACE then
				free(i)
			else
				local model = following[i]
				if model then
					local position = positionOf(model)
					if position then
						voiceParts[i].CFrame = CFrame.new(position)
					else
						following[i] = nil
					end
				end
			end
		end
	end
	if now - prunedAt > PRUNE_EVERY then
		prunedAt = now
		for key, at in lastBySource do
			if now - at > KEEP_SOURCE then
				lastBySource[key] = nil
			end
		end
	end
end

-- Setup ------------------------------------------------------------------------------------------------------------

local function anchor(name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one * 0.2
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local function voiceSound(parent: Instance): Sound
	local sound = Instance.new("Sound")
	sound.SoundGroup = group
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = parent
	return sound
end

local function preload()
	local seen: { [string]: boolean } = {}
	local list: { Instance } = {}
	for _, def in Sfx.defs do
		for _, id in def.ids do
			if not seen[id] then
				seen[id] = true
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(list, sound)
			end
		end
	end
	stats.preloadTotal = #list
	if #list == 0 then
		return
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(list, function(_assetId: string, status: Enum.AssetFetchStatus)
			if status == Enum.AssetFetchStatus.Success then
				stats.preloaded += 1
			end
		end)
	end)
	if not ok then
		warn(`[SfxController] preload: {tostring(err)}`)
	end
	for _, sound in list do
		sound:Destroy()
	end
end

function SfxController.Init(registry: any)
	settings = registry.Get("SettingsController")
end

function SfxController.Start()
	group = settings.SfxGroup()
	Sounds.setGroup(group :: SoundGroup)
	Sounds.setRouter(function(name: string): boolean
		local route = ROUTES[name]
		return route ~= nil and SfxController.Ui(route.key, route.mul)
	end)

	local root = Instance.new("Folder")
	root.Name = "Vaelthorn_Sfx"
	local count = if isTouch() then CFG.maxVoices.touch else CFG.maxVoices.desktop
	for i = 1, count do
		local part = anchor(`Voice{i}`)
		local sound = voiceSound(part)
		part.Parent = root
		table.insert(voiceParts, part)
		table.insert(voiceSounds, sound)
		table.insert(voices, { busy = false, priority = 0, startedAt = 0 })
	end
	local preview = anchor("Preview")
	previewSound = voiceSound(preview)
	preview.Parent = root
	previewPart = preview
	root.Parent = Workspace

	for i = 1, CFG.uiVoices do
		local sound = Instance.new("Sound")
		sound.Name = `VaelthornSfxUi{i}`
		sound.SoundGroup = group
		sound.Parent = SoundService
		table.insert(uiSounds, sound)
		table.insert(uiStarted, 0)
	end
	local ui = Instance.new("Sound")
	ui.Name = "VaelthornSfxPreview"
	ui.SoundGroup = group
	ui.Parent = SoundService
	previewUi = ui

	RunService.Heartbeat:Connect(step)
	task.spawn(preload)
	task.spawn(watchMonsters)
end

return SfxController
