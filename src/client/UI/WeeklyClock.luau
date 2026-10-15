--!strict
-- The clock of the offer of the week (S123): `Now` (Util/Clock seconds) ticking every TICK seconds, so the shop's
-- countdown, the wardrobe's prices and the offer follow the Monday 00:00 UTC change by themselves (Logic/WeeklyOffer
-- reads the time it is given). One loop for every window. Lists and prices read `WeekStart` (the start of the current
-- week, Logic/Time), which changes once a week, so they do not rebuild on every tick; only a countdown reads `Now`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Time = require(ReplicatedStorage.Shared.Logic.Time)

local TICK = 20

local scope = Fusion.scoped(Fusion)

local now = scope:Value(Clock.now())

local WeeklyClock = {
	Now = now,
	WeekStart = scope:Computed(function(use): number
		return Time.weekStart(Time.weekNumber(use(now)))
	end),
}

-- Now, at once (a purchase refused with premium.error.priceChanged: the new week's prices show).
function WeeklyClock.refresh()
	WeeklyClock.Now:set(Clock.now())
end

task.spawn(function()
	while true do
		task.wait(TICK)
		WeeklyClock.Now:set(Clock.now())
	end
end)

return WeeklyClock
