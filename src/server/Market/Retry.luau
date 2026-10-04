--!strict
-- DataStore / MemoryStore calls with a request budget check and retries (exponential backoff), so a busy
-- moment answers "try again" instead of failing a purchase halfway.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("Retry")

local Retry = {}

local BACKOFF = { 0.5, 1, 2 }

-- Waits (up to `maxWait` s) until the DataStore budget for this request type is positive.
function Retry.waitBudget(requestType: Enum.DataStoreRequestType, maxWait: number?)
	local deadline = os.clock() + (maxWait or 3)
	while os.clock() < deadline do
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(requestType)
		end)
		if not ok or budget > 0 then
			return
		end
		task.wait(0.25)
	end
end

-- Calls fn up to #BACKOFF + 1 times. Returns (ok, result | error).
function Retry.call(label: string, fn: () -> ...any): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, #BACKOFF + 1 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt <= #BACKOFF then
			task.wait(BACKOFF[attempt])
		end
	end
	log:warn("%s failed after retries: %s", label, tostring(lastErr))
	return false, lastErr
end

return Retry
