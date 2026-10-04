--!strict
-- A DataStore with an in-memory fallback (Studio without API access), retries and the UpdateAsync pattern
-- used by mail and the auction: `mutate(copy)` returns (newValue?, errorKey?), nil cancels the write.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Retry = require(script.Parent.Retry)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

export type KeyStore = {
	get: (self: KeyStore, key: string) -> (boolean, any?),
	update: (self: KeyStore, key: string, mutate: (current: any?) -> (any?, string?)) -> (boolean, any?, string?),
	isMock: (self: KeyStore) -> boolean,
}

local KeyStore = {}

function KeyStore.new(name: string, hasAccess: () -> boolean): KeyStore
	local store: DataStore? = nil
	local mock: { [string]: any } = {}

	local function real(): DataStore
		if not store then
			store = DataStoreService:GetDataStore(name)
		end
		return store :: DataStore
	end

	local self = {}

	function self.isMock(_self: KeyStore): boolean
		return not hasAccess()
	end

	-- Returns (ok, value?) — ok = false only when the store failed.
	function self.get(this: KeyStore, key: string): (boolean, any?)
		if this:isMock() then
			return true, TableUtil.deepCopy(mock[key])
		end
		Retry.waitBudget(Enum.DataStoreRequestType.GetAsync)
		local ok, result = Retry.call(`{name}.Get {key}`, function()
			return real():GetAsync(key)
		end)
		return ok, if ok then result else nil
	end

	-- Returns (ok, newValue?, errorKey?).
	function self.update(
		this: KeyStore,
		key: string,
		mutate: (current: any?) -> (any?, string?)
	): (boolean, any?, string?)
		local errKey: string? = nil
		local written: any? = nil
		local function callback(current: any?): any?
			errKey = nil
			local value, err = mutate(TableUtil.deepCopy(current))
			if value == nil then
				errKey = err or "error.internal"
				written = nil
				return nil
			end
			written = value
			return value
		end
		if this:isMock() then
			callback(mock[key])
			if written ~= nil then
				mock[key] = TableUtil.deepCopy(written)
			end
		else
			Retry.waitBudget(Enum.DataStoreRequestType.UpdateAsync)
			local ok = Retry.call(`{name}.Update {key}`, function()
				real():UpdateAsync(key, callback)
			end)
			if not ok then
				return false, nil, "market.error.store"
			end
		end
		if written == nil then
			return false, nil, errKey
		end
		return true, TableUtil.deepCopy(written), nil
	end

	return (self :: any) :: KeyStore
end

return KeyStore
