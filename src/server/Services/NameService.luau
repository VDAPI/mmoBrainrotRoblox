--!strict
-- Globally unique character names. A name is reserved in a DataStore keyed by its normalized form;
-- the value is the owner key "<userId>:<characterId>". Uses an in-memory table when DataStores are
-- unavailable (Studio without API access), matching DataService's mock mode.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local NameRules = require(Shared.Logic.NameRules)

local log = Log.new("NameService")

local NameService = {
	Name = "NameService",
	Deps = { "DataService" },
}

local DataService: any
local store: DataStore? = nil
local mock: { [string]: string } = {}

local function useMock(): boolean
	return not DataService.HasDataStoreAccess()
end

local function getStore(): DataStore
	if store == nil then
		store = DataStoreService:GetDataStore(Config.NameStoreName)
	end
	return store :: DataStore
end

function NameService.OwnerKey(userId: number, characterId: string): string
	return `{userId}:{characterId}`
end

-- Shape check + Roblox text filter. Yields. Returns (ok, errorKey?).
function NameService.Validate(player: Player, name: string): (boolean, string?)
	local ok, reason = NameRules.validate(name)
	if not ok then
		return false, NameRules.errorKey(reason :: string)
	end
	local filterOk, filtered = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not filterOk then
		log:warn("text filter failed: %s", tostring(filtered))
		return false, "error.name.filterFailed"
	end
	if filtered ~= name then
		return false, "error.name.filtered"
	end
	return true, nil
end

-- Yields. Returns (available, errorKey?). `ownerKey` treats the caller's own reservation as available.
function NameService.IsAvailable(name: string, ownerKey: string?): (boolean, string?)
	local key = NameRules.normalize(name)
	if useMock() then
		local owner = mock[key]
		return owner == nil or owner == ownerKey, if owner == nil or owner == ownerKey then nil else "error.name.taken"
	end
	local ok, owner = pcall(function()
		return getStore():GetAsync(key)
	end)
	if not ok then
		log:warn("GetAsync failed: %s", tostring(owner))
		return false, "error.name.storeFailed"
	end
	if owner == nil or owner == ownerKey then
		return true, nil
	end
	return false, "error.name.taken"
end

-- Atomically reserves the name. Yields. Returns (ok, errorKey?).
function NameService.Reserve(name: string, ownerKey: string): (boolean, string?)
	local key = NameRules.normalize(name)
	if useMock() then
		local owner = mock[key]
		if owner ~= nil and owner ~= ownerKey then
			return false, "error.name.taken"
		end
		mock[key] = ownerKey
		return true, nil
	end
	local granted = false
	local ok, err = pcall(function()
		getStore():UpdateAsync(key, function(owner: string?)
			if owner == nil or owner == ownerKey then
				granted = true
				return ownerKey
			end
			granted = false
			return nil -- cancel: taken by someone else
		end)
	end)
	if not ok then
		log:warn("UpdateAsync failed: %s", tostring(err))
		return false, "error.name.storeFailed"
	end
	return granted, if granted then nil else "error.name.taken"
end

-- Frees the name if (and only if) it is still owned by ownerKey. Yields. Never throws.
function NameService.Release(name: string, ownerKey: string): boolean
	local key = NameRules.normalize(name)
	if useMock() then
		if mock[key] == ownerKey then
			mock[key] = nil
		end
		return true
	end
	local ok, err = pcall(function()
		local owner = getStore():GetAsync(key)
		if owner == ownerKey then
			getStore():RemoveAsync(key)
		end
	end)
	if not ok then
		log:warn("release of '%s' failed: %s", name, tostring(err))
	end
	return ok
end

function NameService.Init(registry)
	DataService = registry.Get("DataService")
end

return NameService
