--!strict
-- Receives the replicated player state (snapshot + batched diffs) and feeds UI/State.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local log = Log.new("StateController")

local StateController = {
	Name = "StateController",
}

-- If no snapshot arrived by then (e.g. it was fired before we listened), ask again.
local SNAPSHOT_RETRY_SECONDS = 5

function StateController.Start()
	Net.On("StateSnapshot", function(snapshot: any)
		State.ApplySnapshot(snapshot)
		log:debug("snapshot received (phase %s)", tostring(State.Get({ "session", "phase" })))
	end)
	Net.On("StateDiff", function(diffs: any)
		if not State.HasSnapshot() then
			return -- diffs before the first snapshot are meaningless; the snapshot carries them
		end
		local ok, err = pcall(function()
			State.ApplyDiffs(diffs)
		end)
		if not ok then
			log:warn("failed to apply diffs (%s), requesting a snapshot", tostring(err))
			Net.Send("RequestSnapshot")
		end
	end)

	task.delay(SNAPSHOT_RETRY_SECONDS, function()
		if not State.HasSnapshot() then
			Net.Send("RequestSnapshot")
		end
	end)
end

return StateController
