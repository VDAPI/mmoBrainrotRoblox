--!strict
-- Character slots: create / delete / play / switch, and spawning the Roblox character for the active one.
-- Session phases: "select" (character selection screen) <-> "playing".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local CharacterFactory = require(Shared.Logic.CharacterFactory)
local Classes = require(Shared.Data.Classes)
local Log = require(Shared.Util.Log)
local MapTerrain = require(Shared.Logic.MapTerrain)
local Maps = require(Shared.Data.Maps)
local NameRules = require(Shared.Logic.NameRules)
local Net = require(Shared.Net)
local Placement = require(script.Parent.Parent.Placement)
local Premium = require(Shared.Logic.Premium)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("CharacterService")

-- Fall rescue: a character this far under its map's ground (map-relative studs; maps without a height function
-- measure from y = 0) is put back on the ground instead of falling to its death.
local FALL_RESCUE_DEPTH = 45

local CharacterService = {
	Name = "CharacterService",
	-- S121: MonetizationService (character slots 4-5) depends on none of these
	Deps = { "DataService", "PlayerStateService", "NameService", "WorldService", "MonetizationService" },
	-- (player, characterData) after the player entered the world with a character.
	CharacterEntered = Signal.new(),
	-- (player, characterData) before the player leaves the world (switch, leave, wipe).
	CharacterLeaving = Signal.new(),
	-- (player, characterData, slotKey) after a character was deleted (guild membership cleanup; S124: slotKey "1".."5"
	-- for the leaderboard entry "<userId>_<slot>").
	CharacterDeleted = Signal.new(),
	-- (player, model, described) every time a Roblox character model is spawned for the active character (S132:
	-- described = the model was loaded from the look's HumanoidDescription, false for the plain fallback).
	ModelSpawned = Signal.new(),
}

local DataService: any
local PlayerStateService: any
local NameService: any
local WorldService: any
local MonetizationService: any

-- S121 (DESIGN-17 §2): slots above Config.FreeCharacters need the slot passes to CREATE a character there; playing and
-- deleting one never do.
local function slotOpen(player: Player, slot: number): boolean
	return Premium.slotOpen(slot, MonetizationService.Passes(player))
end

type Runtime = {
	busy: boolean,
	spawnToken: number,
	playStartedAt: number?,
	-- S127: on an arena server, the saved location the character came from. The location in memory is the pit; this
	-- one goes back into the profile before the session ends (ProfileReleasing), so the save never keeps the pit.
	home: Types.Location?,
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
	-- S127: on a temporary map (the arena server) only the playtime is written, never the position
	if rt.home == nil and root and WorldService.IsInsideMap(character.location.map, root.Position) then
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

-- Spawns the model at `at` (or the saved location) on `mapId` (or the saved map). S18: the target area is
-- streamed in first and the root stays anchored until the pivot sticks; before, the client (network owner
-- of the fresh model in the city) could overwrite the pivot thousands of studs away, so every respawn
-- ended in the city. The client shows the map loading screen meanwhile.
-- S127: set by ArenaHost on an arena server: where a fresh model of `player` stands (start point, map).
local spawnOverride: ((player: Player) -> (CFrame?, string?))? = nil

-- S132 (DESIGN-17 §9a): set by CosmeticService: the HumanoidDescription of the active character (class look or the
-- player's avatar in standard R15 proportions). A provider and not a dependency: CosmeticService depends on this
-- service. May yield (the avatar's description from Roblox).
local descriptionProvider: ((player: Player, character: Types.CharacterData) -> HumanoidDescription?)? = nil

function CharacterService.SetDescriptionProvider(provider: (
	player: Player,
	character: Types.CharacterData
) -> HumanoidDescription?)
	descriptionProvider = provider
end

-- A Roblox method by its new name (…Async) or its old one; nil when neither exists. Verify the Async variant in the
-- Roblox documentation (the old names are deprecated, not removed).
local function method(object: Instance, asyncName: string, oldName: string): ((...any) -> ...any)?
	for _, name in { asyncName, oldName } do
		local ok, fn = pcall(function()
			return (object :: any)[name]
		end)
		if ok and type(fn) == "function" then
			return fn
		end
	end
	return nil
end

-- Loads the character from the description (S132); false when there is none or Roblox refused it (the caller then
-- loads the plain character).
local function loadWithDescription(player: Player, description: HumanoidDescription?): boolean
	if not description then
		return false
	end
	local load = method(player, "LoadCharacterWithHumanoidDescriptionAsync", "LoadCharacterWithHumanoidDescription")
	if not load then
		log:warn("no LoadCharacterWithHumanoidDescription: plain character for %s", player.Name)
		return false
	end
	local ok, err = pcall(load, player, description)
	if not ok then
		log:warn("loading %s with the class look failed: %s", player.Name, tostring(err))
	end
	return ok
end

local warnedRig = false

local function spawnModel(player: Player, at: CFrame?, mapId: string?)
	local rt = runtime(player)
	rt.spawnToken += 1
	local token = rt.spawnToken

	local character = PlayerStateService.GetCharacter(player)
	if not character or player.Parent ~= Players then
		return
	end
	local loc = character.location
	local map = mapId or loc.map
	if not at and WorldService.IsBuilding(map) then
		-- S45: saved in a region still building in the background: wait for it (the loading screen is up)
		Net.Fire(player, "MapTransition", map)
		WorldService.WaitBuilt(map, 45)
		if rt.spawnToken ~= token or player.Parent ~= Players then
			return
		end
	end
	if not at and not ServerMode.isWorld() and spawnOverride then
		-- S127: an arena server puts a fresh model on the player's start point (ArenaHost)
		local overAt, overMap = spawnOverride(player)
		if overAt then
			at, map = overAt, overMap or map
		end
	end
	if not at and not WorldService.IsBuilt(map) then
		map = ServerMode.homeMap() -- ResolveLocation sends a character on an unbuilt map to the capital (S127: the pit)
	end
	local cframe = at or WorldService.ResolveLocation(map, loc.x, loc.y, loc.z)
	if map ~= loc.map then
		PlayerStateService.Set(player, { "character", "location", "map" }, map)
	end

	Net.Fire(player, "MapTransition", map)
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 8)
	end)
	if rt.spawnToken ~= token or player.Parent ~= Players then
		return
	end

	-- S132: the class look (or the avatar in standard proportions) from CosmeticService; the provider may yield
	local description: HumanoidDescription? = nil
	if descriptionProvider then
		local ok, result = pcall(descriptionProvider, player, character)
		if ok then
			description = result
		else
			log:warn("description for %s failed: %s", player.Name, tostring(result))
		end
		if rt.spawnToken ~= token or player.Parent ~= Players then
			return
		end
	end
	local described = loadWithDescription(player, description)
	if not described then
		if rt.spawnToken ~= token or player.Parent ~= Players then
			return
		end
		player:LoadCharacterAsync()
	end
	if rt.spawnToken ~= token or player.Parent ~= Players then
		return -- switched or left while loading
	end
	local model = player.Character
	if not model then
		return
	end
	-- S132: the game's motions (S110-S117) and the saddle (S96) assume R15; R6 from the game settings still plays
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		if not warnedRig then
			warnedRig = true
			log:warn("characters spawn as %s: set Avatar Type R15 in the game settings", tostring(humanoid.RigType))
		end
		Analytics.custom(player, "RigNotR15", 1)
	end

	setNameplate(model, character)
	-- Anchored at the target until the client has streamed the ground under it (Placement).
	local placement = Placement.place(player, model, cframe)
	CharacterService.ModelSpawned:Fire(player, model, described)
	Placement.release(player, model, cframe, placement)
	if rt.spawnToken ~= token or player.Parent ~= Players then
		return
	end
	log:info("spawned %s on %s at %s", player.Name, map, tostring(cframe.Position))
	task.delay(0.3, function()
		if player.Parent then
			Net.Fire(player, "MapTransition", nil)
		end
	end)
end

-- Spawns a fresh model for the active character (death respawn, /tp fallback) at `at` on `mapId`. Yields.
function CharacterService.Respawn(player: Player, at: CFrame?, mapId: string?)
	if PlayerStateService.GetPhase(player) == "playing" then
		spawnModel(player, at, mapId)
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
	CharacterService.RestoreHome(player)
	runtime(player).home = nil
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

local function checkName(player: Player, name: string): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "select" then
		return false, "error.wrongPhase"
	end
	local ok, reason = NameRules.validate(name)
	if not ok then
		return false, NameRules.errorKey(reason :: string)
	end
	return NameService.IsAvailable(name, nil)
end

-- S132: `look` = the creator's look (W10: every field of ClassLooks.Look; unknown ids fall back to the default ones in
-- the factory).
local function createCharacter(
	player: Player,
	slot: number,
	classId: string,
	name: string,
	look: { [string]: string? }?
): (boolean, string?)
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
	if not slotOpen(player, slot) then
		return false, "charSelect.error.slotLocked"
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
	if not slotOpen(player, slot) then
		NameService.Release(name, ownerKey)
		return false, "charSelect.error.slotLocked"
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
	}, look)
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
	CharacterService.CharacterDeleted:Fire(player, character, slotKey)
	log:info("%s deleted '%s' from slot %s", player.Name, character.name, slotKey)
	return true, nil
end

-- `spawn` (S127, an arena server): the character enters on that map and point; the saved location is kept aside
-- (Runtime.home) and goes back into the profile before the session ends.
local function playCharacter(player: Player, slot: number, spawn: { map: string, at: CFrame }?): (boolean, string?)
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
	local rt = runtime(player)
	rt.home = nil
	if spawn then
		rt.home = table.clone(character.location)
		local p = spawn.at.Position
		PlayerStateService.Set(player, { "character", "location" }, { map = spawn.map, x = p.X, y = p.Y, z = p.Z })
	end
	PlayerStateService.Flush(player)

	rt.playStartedAt = os.clock()
	if spawn then
		task.spawn(spawnModel, player, spawn.at, spawn.map)
	else
		task.spawn(spawnModel, player, nil)
	end
	CharacterService.CharacterEntered:Fire(player, character)
	log:info("%s entered the world as '%s'", player.Name, character.name)
	return true, nil
end

-- Set by ResourceService: refuses switching while dead or in combat (no escaping a fight, S14).
local switchGuard: ((player: Player) -> string?)? = nil

function CharacterService.SetSwitchGuard(guard: (player: Player) -> string?)
	switchGuard = guard
end

local function switchCharacter(player: Player): (boolean, string?)
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return false, "error.wrongPhase"
	end
	if not ServerMode.isWorld() then
		return false, "arena.net.error.notHere" -- S127: no character selection on an arena server
	end
	local blocked = switchGuard and switchGuard(player)
	if blocked then
		return false, blocked
	end
	CharacterService.ReturnToSelect(player)
	DataService.Save(player)
	return true, nil
end

-- S127: enters the world with the character of `slot` (the PlayCharacter path, under the request lock). With `spawn`
-- (an arena server) on that map and point, the saved location kept aside; without it on the saved location (a world
-- server after the arena: TeleportData.arenaReturn).
function CharacterService.Play(player: Player, slot: number, spawn: { map: string, at: CFrame }?): (boolean, string?)
	return withLock(player, function()
		return playCharacter(player, slot, spawn)
	end)
end

-- S127: the position and playtime into the character data now (before a teleport between servers).
function CharacterService.SaveRuntime(player: Player)
	saveRuntime(player)
end

-- S127: the location saved before the arena server goes back into the character data (before the profile is saved for
-- the last time). Nothing without one.
function CharacterService.RestoreHome(player: Player)
	local rt = runtimes[player]
	local character = PlayerStateService.GetCharacter(player)
	if rt and rt.home and character then
		character.location = table.clone(rt.home)
	end
end

-- S127: one override (ArenaHost on an arena server) for where a fresh model stands; nil on a world server.
function CharacterService.SetSpawnOverride(fn: ((player: Player) -> (CFrame?, string?))?)
	spawnOverride = fn
end

-- S127: the start point of `player` on this arena server (DeathService's "city" choice off a world server).
function CharacterService.SpawnOverride(player: Player): (CFrame?, string?)
	if spawnOverride then
		return spawnOverride(player)
	end
	return nil, nil
end

function CharacterService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	NameService = registry.Get("NameService")
	WorldService = registry.Get("WorldService")
	MonetizationService = registry.Get("MonetizationService")
end

function CharacterService.Start()
	Net.Handle("CheckName", function(player: Player, name: string)
		return checkName(player, name)
	end)
	-- S132: face, skin and hair are optional (an old client sends none: the default look)
	Net.Handle(
		"CreateCharacter",
		function(
			player: Player,
			slot: number,
			classId: string,
			name: string,
			face: string?,
			skin: string?,
			hair: string?,
			hairColor: string?,
			brows: string?,
			beard: string?,
			build: string?,
			paint: string?,
			paintColor: string?
		)
			if not ServerMode.isWorld() then
				return false, "arena.net.error.notHere" -- S127: the arena server picks the character itself
			end
			local look = {
				face = face,
				skin = skin,
				hair = hair,
				hairColor = hairColor,
				brows = brows,
				beard = beard,
				build = build,
				paint = paint,
				paintColor = paintColor,
			}
			return withLock(player, function()
				return createCharacter(player, slot, classId, name, look)
			end)
		end
	)
	Net.Handle("DeleteCharacter", function(player: Player, slot: number, confirmName: string)
		if not ServerMode.isWorld() then
			return false, "arena.net.error.notHere"
		end
		return withLock(player, function()
			return deleteCharacter(player, slot, confirmName)
		end)
	end)
	Net.Handle("PlayCharacter", function(player: Player, slot: number)
		if not ServerMode.isWorld() then
			return false, "arena.net.error.notHere"
		end
		return withLock(player, function()
			return playCharacter(player, slot)
		end)
	end)
	Net.Handle("SwitchCharacter", function(player: Player)
		return withLock(player, function()
			return switchCharacter(player)
		end)
	end)

	Net.On("GroundReady", Placement.OnReady)
	Players.PlayerRemoving:Connect(Placement.Forget)

	-- Fall rescue: whatever let a character through the ground (a hole in the terrain, a stream that arrived too
	-- late), it is put back on the ground at the same spot (or the map's spawn) instead of dying in the void.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local character = PlayerStateService.GetCharacter(player)
				local model = player.Character
				local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
				local map = character and Maps.get(character.location.map)
				if character and model and root and map and not root.Anchored and not Placement.IsPlacing(player) then
					local lx, lz = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
					local ground = MapTerrain.height(map.id, lx, lz) or 0
					if root.Position.Y - map.offset.y < ground - FALL_RESCUE_DEPTH then
						local inside = math.abs(lx) <= map.size.x / 2 and math.abs(lz) <= map.size.z / 2
						local target = if inside
							then WorldService.GroundCFrame(map.id, lx, lz)
							else WorldService.GetSpawnCFrame(map.id)
						log:warn("%s fell under %s at %s, rescued", player.Name, map.id, tostring(root.Position))
						task.spawn(Placement.hold, player, model, target)
					end
				end
			end
		end
	end)

	DataService.ProfileReleasing:Connect(function(player: Player)
		saveRuntime(player)
		local character = PlayerStateService.GetCharacter(player)
		if character then
			CharacterService.CharacterLeaving:Fire(player, character)
		end
		-- S127: after the arena wrote the result (CharacterLeaving), the location before the arena server goes back into
		-- the profile, right before EndSession saves it. A ProfileStore auto-save during the match may store the pit;
		-- harmless: a map that is not built sends the next login to the capital (WorldService.ResolveLocation).
		local rt = runtimes[player]
		if rt and rt.home and character then
			character.location = table.clone(rt.home)
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
