--!strict
-- PvP toggle and attack permission (DESIGN §3.3). The toggle switches after Config.PvpToggleDelay seconds
-- (countdown shown on the client) and cannot be turned off for Config.PvpCombatLock seconds after PvP
-- combat. It can only be changed in yellow zones (green: never PvP, red: always PvP).
-- Actual PvP combat arrives in S10; it must call PvpService.CanAttack and PvpService.MarkPvpCombat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PvpRules = require(Shared.Logic.PvpRules)
local Types = require(Shared.Types)

local PvpService = {
	Name = "PvpService",
	Deps = { "PlayerStateService", "CharacterService", "ZoneService", "PartyService" },
}

local PlayerStateService: any
local CharacterService: any
local ZoneService: any
local PartyService: any

type Runtime = { token: number, pendingTarget: boolean?, lastPvpCombat: number? }

local runtimes: { [Player]: Runtime } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function runtime(player: Player): Runtime
	local rt = runtimes[player]
	if not rt then
		rt = { token = 0 }
		runtimes[player] = rt
	end
	return rt
end

local function publish(player: Player, switchAt: number?)
	local rt = runtime(player)
	local lockedUntil = if rt.lastPvpCombat then rt.lastPvpCombat + Config.PvpCombatLock else nil
	PlayerStateService.Set(player, { "pvp" }, {
		pendingTarget = rt.pendingTarget,
		switchAt = switchAt,
		lockedUntil = if lockedUntil and lockedUntil > now() then lockedUntil else nil,
	})
end

local function applyAttribute(player: Player, enabled: boolean)
	local model = player.Character
	if model then
		model:SetAttribute("PvpEnabled", enabled)
	end
end

function PvpService.IsEnabled(player: Player): boolean
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	return character ~= nil and character.pvpEnabled
end

-- Switches immediately (admin, internal).
function PvpService.Force(player: Player, enabled: boolean)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	local rt = runtime(player)
	rt.token += 1
	rt.pendingTarget = nil
	PlayerStateService.Set(player, { "character", "pvpEnabled" }, enabled)
	applyAttribute(player, enabled)
	publish(player, nil)
end

local function cancelPending(player: Player)
	local rt = runtime(player)
	if rt.pendingTarget ~= nil then
		rt.token += 1
		rt.pendingTarget = nil
		publish(player, nil)
	end
end

-- Call when the player deals or receives PvP damage (S10).
function PvpService.MarkPvpCombat(player: Player)
	local rt = runtime(player)
	rt.lastPvpCombat = now()
	if rt.pendingTarget == false then
		rt.token += 1
		rt.pendingTarget = nil
	end
	publish(player, nil)
end

-- Whether `attacker` may hit `target` right now (zone of the target). Party/guild arrive in S09/S12.
function PvpService.CanAttack(attacker: Player, target: Player): (boolean, string?)
	if attacker == target then
		return false, "pvp.deny.self"
	end
	return PvpRules.canAttack(
		{ pvpEnabled = PvpService.IsEnabled(attacker) },
		{ pvpEnabled = PvpService.IsEnabled(target) },
		{
			zone = ZoneService.GetPvpZone(target),
			sameParty = PartyService.SameParty(attacker, target),
			sameGuild = false,
		}
	)
end

local function request(player: Player, enabled: boolean): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	local rt = runtime(player)
	if character.pvpEnabled == enabled then
		cancelPending(player) -- clicking again cancels a running countdown
		return true, nil
	end
	if rt.pendingTarget == enabled then
		return true, nil
	end
	local ok, err =
		PvpRules.canToggle(ZoneService.GetPvpZone(player), enabled, now(), rt.lastPvpCombat, Config.PvpCombatLock)
	if not ok then
		return false, err
	end
	rt.token += 1
	local token = rt.token
	rt.pendingTarget = enabled
	publish(player, now() + Config.PvpToggleDelay)
	task.delay(Config.PvpToggleDelay, function()
		if rt.token ~= token or runtimes[player] ~= rt then
			return
		end
		local allowed =
			PvpRules.canToggle(ZoneService.GetPvpZone(player), enabled, now(), rt.lastPvpCombat, Config.PvpCombatLock)
		if allowed then
			PvpService.Force(player, enabled)
		else
			cancelPending(player)
		end
	end)
	return true, nil
end

function PvpService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ZoneService = registry.Get("ZoneService")
	PartyService = registry.Get("PartyService")
end

function PvpService.Start()
	Net.Handle("SetPvp", request)

	CharacterService.ModelSpawned:Connect(function(player: Player)
		applyAttribute(player, PvpService.IsEnabled(player))
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		publish(player, nil)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		local rt = runtimes[player]
		if rt then
			rt.token += 1
			rt.pendingTarget = nil
		end
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "pvp" }, nil)
		end
	end)
	-- Leaving the yellow zone cancels a countdown.
	ZoneService.ZoneChanged:Connect(function(player: Player, zone: Types.ZoneState)
		if zone.pvp ~= "yellow" then
			cancelPending(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			runtimes[player] = nil
		end)
	end)
end

return PvpService
