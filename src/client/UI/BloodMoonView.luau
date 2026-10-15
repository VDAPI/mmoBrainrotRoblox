--!strict
-- The Blood Moon on the client (S129, DESIGN-17 §7): the ReplicatedStorage attributes BloodMoonService keeps (BloodMoon
-- = occurrence id or "", BloodMoonEndsAt, BloodMoonNext), a clock ticking every TICK s (Util/Clock, the server's time
-- with the /time offset) and the runtime branch `bloodMoonBoard`, shared by the HUD panel, the results window, the
-- menu entry and BloodMoonController. `Phase` (Logic/BloodMoon.phaseOf): "soon" (10 min before), "active", "ended"
-- (results still published), nil.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BloodMoon = require(ReplicatedStorage.Shared.Logic.BloodMoon)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)

local TICK = 0.5

local scope = Fusion.scoped(Fusion)

local function attribute(name: string): Fusion.Value<any>
	local value = scope:Value(ReplicatedStorage:GetAttribute(name))
	ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
		value:set(ReplicatedStorage:GetAttribute(name))
	end)
	return value
end

local id = attribute("BloodMoon")
local endsAt = attribute("BloodMoonEndsAt")
local nextAt = attribute("BloodMoonNext")
local now = scope:Value(Clock.now())
local board = State.Value({ "bloodMoonBoard" })

local BloodMoonView = {
	Id = id,
	EndsAt = endsAt,
	Next = nextAt,
	Now = now,
	Board = board,
	Phase = scope:Computed(function(use): BloodMoon.Phase?
		local b = use(board)
		return BloodMoon.phaseOf(use(now), use(id), use(endsAt), use(nextAt), type(b) == "table")
	end),
}

-- The HUD menu entry: from 10 min before the start until the results are no longer published.
function BloodMoonView.menuVisible(use: Fusion.Use): boolean
	return use(BloodMoonView.Phase) ~= nil
end

task.spawn(function()
	while true do
		task.wait(TICK)
		now:set(Clock.now())
	end
end)

return BloodMoonView
