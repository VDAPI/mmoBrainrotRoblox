--!strict
-- The PvP switch request (S18, DESIGN §3.3), shared by the toggle button (Hud/PvpToggle, touch screens) and the
-- clickable dot on the portrait (UI plan phase 2: PC). Only in a yellow zone; a second click while it counts down
-- turns the switch back. The server answers on the state branches `pvp` and `character.pvpEnabled`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)
local Toast = require(script.Parent.Components.Toast)

local PvpSwitch = {}

local busy = false

function PvpSwitch.request()
	local zone = State.Get({ "zone" })
	local zoneType = if type(zone) == "table" then zone.pvp else "green"
	if busy or zoneType ~= "yellow" then
		Sounds.play("error")
		Toast.push(Text.now("pvp.error.zone"), "warning")
		return
	end
	local state = State.Get({ "pvp" })
	local target = if type(state) == "table" and state.pendingTarget ~= nil
		then not state.pendingTarget
		else not (State.Get({ "character", "pvpEnabled" }) == true)
	busy = true
	Sounds.play("click")
	task.spawn(function()
		local ok, err = Net.Invoke("SetPvp", target)
		busy = false
		if not ok then
			Toast.push(Text.now(err or "error.internal", { seconds = Config.PvpCombatLock }), "error")
		end
	end)
end

return PvpSwitch
