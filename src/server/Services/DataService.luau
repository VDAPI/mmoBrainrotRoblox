--!strict
-- Player account persistence via ProfileStore (session locked). Falls back to ProfileStore's in-memory
-- mock automatically when DataStore access is unavailable (unpublished place / API access disabled).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Packages = ReplicatedStorage.Packages

local AccountSchema = require(Shared.Logic.AccountSchema)
local Config = require(Shared.Config)
local Locale = require(Shared.Util.Locale)
local Log = require(Shared.Util.Log)
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local Signal = require(Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("DataService")

type AccountData = Types.AccountData
-- ProfileStore's generic Profile<T> does not unify with our data type under the new solver.
type Profile = any

local DataService = {
	Name = "DataService",
	-- (player, data) after the profile is loaded, migrated and reconciled.
	ProfileLoaded = Signal.new(),
	-- (player) right before the session ends: last chance to write runtime state (location, playtime).
	ProfileReleasing = Signal.new(),
}

local store = ProfileStore.New(Config.ProfileStoreName, AccountSchema.accountTemplate())
local profiles: { [Player]: Profile } = {}
local mockWarned = false

local function kick(player: Player, key: string)
	player:Kick(Locale.T(key, nil, "en") .. " / " .. Locale.T(key, nil, "pl"))
end

-- True when profiles live in memory only (data will not persist).
function DataService.IsMock(): boolean
	return ProfileStore.DataStoreState ~= "Access"
end

function DataService.HasDataStoreAccess(): boolean
	return ProfileStore.DataStoreState == "Access"
end

function DataService.GetProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.GetData(player: Player): AccountData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Yields until the profile is loaded or the player leaves (then returns nil).
function DataService.WaitForData(player: Player): AccountData?
	while player.Parent == Players and profiles[player] == nil do
		task.wait(0.1)
	end
	return DataService.GetData(player)
end

-- Persists immediately (purchases, trades). Normal changes are auto-saved by ProfileStore.
function DataService.Save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	DataService.ProfileReleasing:Fire(player)
	profiles[player] = nil
	profile:EndSession()
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(
		`Player_{player.UserId}`,
		{
			Cancel = function()
				return player.Parent ~= Players
			end,
		} :: any
	)

	if profile == nil then
		if player.Parent == Players then
			log:warn("profile load failed for %s", player.Name)
			kick(player, "kick.loadFailed")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local applied = AccountSchema.migrate(profile.Data, function(): string
		return HttpService:GenerateGUID(false)
	end)
	if #applied > 0 then
		log:info("migrated %s through schema %s", player.Name, table.concat(applied, ", "))
	end
	if profile.Data.stats.createdAt == 0 then
		profile.Data.stats.createdAt = os.time()
	end

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			kick(player, "kick.sessionEnded")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	if DataService.IsMock() and not mockWarned then
		mockWarned = true
		log:warn(
			"DataStore unavailable (%s): using an in-memory mock, data will NOT persist after the test. "
				.. "Publish the place and enable Game Settings > Security > Studio Access to API Services.",
			ProfileStore.DataStoreState
		)
	end

	profiles[player] = profile
	log:info("profile loaded for %s (%d characters)", player.Name, #DataService.CharacterSlots(profile.Data))
	DataService.ProfileLoaded:Fire(player, profile.Data)
end

-- Sorted list of occupied slot numbers.
function DataService.CharacterSlots(data: AccountData): { number }
	local slots = {}
	for key in data.characters do
		local n = tonumber(key)
		if n then
			table.insert(slots, n)
		end
	end
	table.sort(slots)
	return slots
end

function DataService.Init() end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)

	-- ProfileStore also saves on shutdown; this makes sure services get ProfileReleasing first.
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			release(player)
		end
	end)
end

return DataService
