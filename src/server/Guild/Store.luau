--!strict
-- Guild persistence (DESIGN §19, ARCHITECTURE §5): records in the `Guilds` DataStore under "Guild_<id>",
-- unique names and tags in `GuildNames` ("n:<normalized name>" / "t:<TAG>" -> guild id). Every change
-- goes through UpdateAsync with the validation inside the callback (Logic/Guild), so concurrent edits from
-- different servers can never overwrite each other. In-memory tables replace both stores when DataStores
-- are unavailable (Studio without API access), like NameService.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local TableUtil = require(Shared.Util.TableUtil)

local log = Log.new("GuildStore")

local Store = {}

local hasAccess: () -> boolean = function()
	return false
end
local guildStore: DataStore? = nil
local nameStore: DataStore? = nil
local mockGuilds: { [string]: any } = {}
local mockNames: { [string]: string } = {}

local function guilds(): DataStore
	if not guildStore then
		guildStore = DataStoreService:GetDataStore(Config.GuildStoreName)
	end
	return guildStore :: DataStore
end

local function names(): DataStore
	if not nameStore then
		nameStore = DataStoreService:GetDataStore(Config.GuildNamesStoreName)
	end
	return nameStore :: DataStore
end

local function key(id: string): string
	return `Guild_{id}`
end

function Store.init(accessCheck: () -> boolean)
	hasAccess = accessCheck
end

function Store.IsMock(): boolean
	return not hasAccess()
end

-- Yields. Returns (ok, data?) — ok = false only when the store failed.
function Store.get(id: string): (boolean, any?)
	if Store.IsMock() then
		return true, TableUtil.deepCopy(mockGuilds[id])
	end
	local ok, result = pcall(function()
		return guilds():GetAsync(key(id))
	end)
	if not ok then
		log:warn("GetAsync %s failed: %s", id, tostring(result))
		return false, nil
	end
	return true, result
end

-- Yields. `mutate(current)` returns (newValue?, errorKey?): nil cancels the write. It may run several
-- times (UpdateAsync retries), so it must not have side effects. Returns (ok, newValue?, errorKey?).
function Store.update(id: string, mutate: (current: any?) -> (any?, string?)): (boolean, any?, string?)
	local errKey: string? = nil
	local written: any? = nil
	local function callback(current: any?): any?
		errKey = nil
		local copy = TableUtil.deepCopy(current)
		local value, err = mutate(copy)
		if value == nil then
			errKey = err or "guild.error.failed"
			written = nil
			return nil
		end
		written = value
		return value
	end
	if Store.IsMock() then
		callback(mockGuilds[id])
		if written ~= nil then
			mockGuilds[id] = TableUtil.deepCopy(written)
		end
	else
		local ok, err = pcall(function()
			guilds():UpdateAsync(key(id), callback)
		end)
		if not ok then
			log:warn("UpdateAsync %s failed: %s", id, tostring(err))
			return false, nil, "guild.error.store"
		end
	end
	if written == nil then
		return false, nil, errKey
	end
	return true, TableUtil.deepCopy(written), nil
end

local function claim(nameKey: string, id: string): (boolean, string?)
	if Store.IsMock() then
		local owner = mockNames[nameKey]
		if owner ~= nil and owner ~= id then
			return false, "taken"
		end
		mockNames[nameKey] = id
		return true, nil
	end
	local granted = false
	local ok, err = pcall(function()
		names():UpdateAsync(nameKey, function(owner: string?)
			granted = owner == nil or owner == "" or owner == id
			return if granted then id else nil
		end)
	end)
	if not ok then
		log:warn("name claim %s failed: %s", nameKey, tostring(err))
		return false, "store"
	end
	return granted, if granted then nil else "taken"
end

local function release(nameKey: string, id: string)
	if Store.IsMock() then
		if mockNames[nameKey] == id then
			mockNames[nameKey] = nil
		end
		return
	end
	local ok, err = pcall(function()
		names():UpdateAsync(nameKey, function(owner: string?)
			return if owner == id then "" else nil -- "" = free (RemoveAsync cannot be conditional)
		end)
	end)
	if not ok then
		log:warn("name release %s failed: %s", nameKey, tostring(err))
	end
end

-- Reserves both the name and the tag for `id`. Yields. Returns (ok, errorKey?).
function Store.reserveNames(nameKey: string, tagKey: string, id: string): (boolean, string?)
	local ok, reason = claim(nameKey, id)
	if not ok then
		return false, if reason == "taken" then "guild.error.nameTaken" else "guild.error.store"
	end
	ok, reason = claim(tagKey, id)
	if not ok then
		release(nameKey, id)
		return false, if reason == "taken" then "guild.error.tagTaken" else "guild.error.store"
	end
	return true, nil
end

function Store.releaseNames(nameKey: string, tagKey: string, id: string)
	release(nameKey, id)
	release(tagKey, id)
end

return Store
