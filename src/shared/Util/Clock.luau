--!strict
-- Real-time clock for systems that count wall-clock time also while offline (alchemy, blessings, elixirs,
-- daily resets). `/time +s` shifts it for tests: the server stores the offset as a ReplicatedStorage
-- attribute so the client's countdowns use the same clock. Outside Roblox (Lune tests) it is os.time().

local Clock = {}

local ATTRIBUTE = "ClockOffset"

local storage: Instance? = nil
local okGame = pcall(function()
	storage = (game :: any):GetService("ReplicatedStorage")
end)

local function serverNow(): number
	if okGame then
		return (workspace :: any):GetServerTimeNow()
	end
	return os.time()
end

function Clock.offset(): number
	local value = storage and storage:GetAttribute(ATTRIBUTE)
	return if type(value) == "number" then value else 0
end

-- Unix seconds (float) shifted by the test offset.
function Clock.now(): number
	return serverNow() + Clock.offset()
end

-- Server only: moves the clock forward (or back) by `seconds`.
function Clock.shift(seconds: number)
	if storage then
		storage:SetAttribute(ATTRIBUTE, Clock.offset() + seconds)
	end
end

return Clock
