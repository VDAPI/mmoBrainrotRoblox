--!strict
-- Character slots: create / delete / play / switch, and spawning the Roblox character for the active one.
-- Session phases: "select" (character selection screen) <-> "playing".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local CharacterFactory = require(Shared.Logic.CharacterFactory)
local Classes = require(Shared.Data.Classes)
local Log = require(Shared.Util.Log)
local NameRules = require(Shared.Logic.NameRules)
local Net = require(Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("CharacterService")

local CharacterService = {
	Name = "CharacterService",
	Deps = { "DataService", "PlayerStateService", "NameService", "WorldService" },
	-- (player, characterData) after the player entered the world with a character.
	CharacterEntered = Signal.new(),
	-- (player, characterData) before the player leaves the world (switch, leave, wipe).
	CharacterLeaving = Signal.new(),
	-- (player, characterData) after a character was deleted (guild membership cleanup).
	CharacterDeleted = Signal.new(),
	-- (player, model) every time a Roblox character model is spawned for the active character.
	ModelSpawned = Signal.new(),
}

local DataService: any
local PlayerStateService: any
local NameService: any
local WorldService: any

type Runtime = {
	busy: boolean,
	spawnToken: number,
	playStartedAt: number?,
}

local runtimes: { [Player]: Runtime } = {}

local function runtime(player: Player): Runtime
	local rt = runtimes[player]
	if not rt then
		rt = { busy = false, spawnToken = 0, playStartedAt = nil }
		runtimes[player] = rt
	end
	return rt
end

-- Runs fn while holding the per-player lock so two requests can never interleave across yields.
local function withLock(player: Player, fn: () -> (boolean, string?)): (boolean, string?)
	local rt = runtime(player)
	if rt.busy then
		return false, "error.busy"
	end
	rt.busy = true
	local ok, result, errKey = pcall(fn)
	rt.busy = false
	if not ok then
		log:error("request failed for %s: %s", player.Name, tostring(result))
		return false, "error.internal"
	end
	return result, errKey
end

local function newId(): string
	return HttpService:GenerateGUID(false)
end

local function refreshSlot(player: Player, slotKey: string)
	local data = DataService.GetData(player)
	local character = data and data.characters[slotKey]
	PlayerStateService.Set(player, { "slots", slotKey }, if character then CharacterFactory.summary(character) else nil)
end

local function setNameplate(model: Model, character: Types.CharacterData)
	model:SetAttribute("CharName", character.name)
	model:SetAttribute("Level", character.level)
	model:SetAttribute("ClassId", character.class)
	-- Clients draw their own localized nameplate (NameplateController).
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- Writes runtime-only values (position, playtime) back into the character data.
local function saveRuntime(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	local rt = runtime(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and WorldService.IsInsideMap(character.location.map, root.Position) then
		local p = root.Position
		character.location = {
			map = character.location.map,
			x = math.floor(p.X * 10) / 10,
			y = math.floor(p.Y * 10) / 10,
			z = math.floor(p.Z * 10) / 10,
		}
	end
	if rt.playStartedAt then
		local elapsed = math.floor(os.clock() - rt.playStartedAt)
		character.playtime += elapsed
		local data: Types.AccountData? = DataService.GetData(player)
		if data then
			data.stats.playtime += elapsed
		end
		rt.playStartedAt = os.clock()
	end
end

local function despawn(player: Player)
	local rt = runtime(player)
	rt.spawnToken += 1 -- invalidates pending respawns
	local model = player.Character
	if model then
		player.Character = nil
		model:Destroy()
	end
end

local function spawnModel(player: Player, at: CFrame?)
	local rt = runtime(player)
	rt.spawnToken += 1
	local token = rt.spawnToken

	local character = PlayerStateService.GetCharacter(player)
	if not character or player.Parent ~= Players then
		return
	end

	player:LoadCharacterAsync()
	if rt.spawnToken ~= token or player.Parent ~= Players then
		return -- switched or left while loading
	end
	local model = player.Character
	if not model then
		return
	end

	local loc = character.location
	local cframe = at or WorldService.ResolveLocation(loc.map, loc.x, loc.y, loc.z)
	model:PivotTo(cframe)
	setNameplate(model, character)

	CharacterService.ModelSpawned:Fire(player, model)
end

-- Spawns a fresh model for the active character (death respawn, /tp fallback). Yields.
function CharacterService.Respawn(player: Player, at: CFrame?)
	if PlayerStateService.GetPhase(player) == "playing" then
		spawnModel(player, at)
	end
end

-- Leaves the world back to the selection screen. Safe to call in any phase.
function CharacterService.ReturnToSelect(player: Player)
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return
	end
	local character = PlayerStateService.GetCharacter(player)
	saveRuntime(player)
	if character then
		CharacterService.CharacterLeaving:Fire(player, character)
	end
	despawn(player)
	runtime(player).playStartedAt = nil

	local slot = PlayerStateService.Get(player, { "session", "slot" })
	PlayerStateService.Set(player, { "character" }, nil)
	PlayerStateService.Set(player, { "session", "phase" }, "select")
	PlayerStateService.Set(player, { "session", "slot" }, nil)
	if slot then
		refreshSlot(player, tostring(slot))
	end
end

function CharacterService.GetActive(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

-- Handlers ---------------------------------------------------------------------------------------

local function checkName(_player: Player, name: string): (boolean, string?)
	local ok, reason = NameRules.validate(name)
	if not ok then
		return false, NameRules.errorKey(reason :: string)
	end
	return NameService.IsAvailable(name, nil)
end

local function createCharacter(player: Player, slot: number, classId: string, name: string): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "select" then
		return false, "error.wrongPhase"
	end
	local slotKey = CharacterFactory.slotKey(slot)
	if not slotKey then
		return false, "error.badRequest"
	end
	local data = DataService.GetData(player)
	if not data then
		return false, "error.notLoaded"
	end
	if data.characters[slotKey] then
		return false, "error.slotTaken"
	end
	local class = Classes.get(classId)
	if not class then
		return false, "error.badRequest"
	end

	local validName, nameErr = NameService.Validate(player, name)
	if not validName then
		return false, nameErr
	end

	local characterId = newId()
	local ownerKey = NameService.OwnerKey(player.UserId, characterId)
	local reserved, reserveErr = NameService.Reserve(name, ownerKey)
	if not reserved then
		return false, reserveErr
	end

	-- The profile may have been released while we yielded.
	data = DataService.GetData(player)
	if not data or data.characters[slotKey] then
		NameService.Release(name, ownerKey)
		return false, if data then "error.slotTaken" else "error.notLoaded"
	end

	local first = true
	local character = CharacterFactory.create(class.id, name, {
		newId = function()
			if first then
				first = false
				return characterId
			end
			return newId()
		end,
		now = os.time(),
	})
	data.characters[slotKey] = character
	refreshSlot(player, slotKey)
	log:info("%s created %s '%s' in slot %s", player.Name, class.id, name, slotKey)
	return true, nil
end

local function deleteCharacter(player: Player, slot: number, confirmName: string): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "select" then
		return false, "error.wrongPhase"
	end
	local slotKey = CharacterFactory.slotKey(slot)
	local data = DataService.GetData(player)
	if not slotKey or not data then
		return false, "error.badRequest"
	end
	local character = data.characters[slotKey]
	if not character then
		return false, "error.slotEmpty"
	end
	if confirmName ~= character.name then
		return false, "error.confirmMismatch"
	end

	data.characters[slotKey] = nil
	if data.lastCharacter == slot then
		data.lastCharacter = nil
		PlayerStateService.Set(player, { "account", "lastCharacter" }, nil)
	end
	refreshSlot(player, slotKey)
	NameService.Release(character.name, NameService.OwnerKey(player.UserId, character.id))
	CharacterService.CharacterDeleted:Fire(player, character)
	log:info("%s deleted '%s' from slot %s", player.Name, character.name, slotKey)
	return true, nil
end

local function playCharacter(player: Player, slot: number): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "select" then
		return false, "error.wrongPhase"
	end
	local slotKey = CharacterFactory.slotKey(slot)
	local data = DataService.GetData(player)
	if not slotKey or not data then
		return false, "error.badRequest"
	end
	local character = data.characters[slotKey]
	if not character then
		return false, "error.slotEmpty"
	end

	data.lastCharacter = slot
	PlayerStateService.Set(player, { "account", "lastCharacter" }, slot)
	PlayerStateService.Set(player, { "character" }, character)
	PlayerStateService.Set(player, { "session", "slot" }, slot)
	PlayerStateService.Set(player, { "session", "phase" }, "playing")
	PlayerStateService.Flush(player)

	runtime(player).playStartedAt = os.clock()
	task.spawn(spawnModel, player, nil)
	CharacterService.CharacterEntered:Fire(player, character)
	log:info("%s entered the world as '%s'", player.Name, character.name)
	return true, nil
end

local function switchCharacter(player: Player): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return false, "error.wrongPhase"
	end
	CharacterService.ReturnToSelect(player)
	DataService.Save(player)
	return true, nil
end

function CharacterService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	NameService = registry.Get("NameService")
	WorldService = registry.Get("WorldService")
end

function CharacterService.Start()
	Net.Handle("CheckName", function(player: Player, name: string)
		return checkName(player, name)
	end)
	Net.Handle("CreateCharacter", function(player: Player, slot: number, classId: string, name: string)
		return withLock(player, function()
			return createCharacter(player, slot, classId, name)
		end)
	end)
	Net.Handle("DeleteCharacter", function(player: Player, slot: number, confirmName: string)
		return withLock(player, function()
			return deleteCharacter(player, slot, confirmName)
		end)
	end)
	Net.Handle("PlayCharacter", function(player: Player, slot: number)
		return withLock(player, function()
			return playCharacter(player, slot)
		end)
	end)
	Net.Handle("SwitchCharacter", function(player: Player)
		return withLock(player, function()
			return switchCharacter(player)
		end)
	end)

	DataService.ProfileReleasing:Connect(function(player: Player)
		saveRuntime(player)
		local character = PlayerStateService.GetCharacter(player)
		if character then
			CharacterService.CharacterLeaving:Fire(player, character)
		end
	end)

	-- Position and playtime are written into the save every 30 s (DESIGN: login on the saved map).
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				if PlayerStateService.GetPhase(player) == "playing" then
					saveRuntime(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Deferred: ProfileReleasing (also on PlayerRemoving) still needs the runtime for playtime.
		task.defer(function()
			runtimes[player] = nil
		end)
	end)
end

return CharacterService
