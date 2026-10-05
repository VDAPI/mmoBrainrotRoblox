--!strict
-- Local player's PvP indicator (S18) from replicated state: character.pvpEnabled, zone.pvp and the pvp
-- branch (pendingTarget, lockedUntil). Logic in Logic/PvpRules.indicator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PvpRules = require(ReplicatedStorage.Shared.Logic.PvpRules)
local State = require(script.Parent.State)

local PvpState = {}

function PvpState.indicator(scope: Fusion.Scope<typeof(Fusion)>): Fusion.Computed<string>
	local enabled = State.Value({ "character", "pvpEnabled" })
	local zone = State.Value({ "zone" })
	local pvp = State.Value({ "pvp" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local accumulator = 0
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= 0.5 then
				accumulator = 0
				now:set(Workspace:GetServerTimeNow())
			end
		end)
	)
	return scope:Computed(function(use): string
		local z = use(zone)
		local state = use(pvp)
		return PvpRules.indicator(
			use(enabled) == true,
			if type(z) == "table" then z.pvp else nil,
			if type(state) == "table" then state.pendingTarget else nil,
			if type(state) == "table" then state.lockedUntil else nil,
			use(now)
		)
	end)
end

return PvpState
