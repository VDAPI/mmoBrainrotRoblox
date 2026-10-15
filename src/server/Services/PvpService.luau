--!strict
-- PvP toggle and attack permission (DESIGN §3.3). The toggle switches after Config.PvpToggleDelay seconds
-- (countdown shown on the client) and cannot be turned off for Config.PvpCombatLock seconds after PvP
-- combat. It can only be changed in yellow zones (green: never PvP, red: always PvP).
-- S10: combat calls CanAttack / MarkPvpCombat / RecordHit; a death within Config.PvpKillCredit seconds of a
-- player's hit is a PvP kill (no losses for the victim, kill/death counters, map-local kill feed). Standing
-- on the city arena counts as PvP enabled. DuelService installs a rule that overrides everything for duelists.
-- S126: fight rules are a list (AddFightRule): duels (DuelService) and ranked matches (ArenaService); the first verdict
-- that is not nil wins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PvpRules = require(Shared.Logic.PvpRules)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)

local PvpService = {
	Name = "PvpService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ZoneService",
		"PartyService",
		"ResourceService",
		"GuildService",
		"StatusEffectService",
	},
	-- (killer: Player, victim: Player, mapId: string?) after a player defeated another (S129: Blood Moon points)
	PlayerKilled = Signal.new(),
}

local PlayerStateService: any
local CharacterService: any
local ZoneService: any
local PartyService: any
local ResourceService: any
local StatusEffectService: any
local GuildService: any

local ARENA_ZONE = "zone.arena"

-- Last player hit per victim (kill credit).
local lastHit: { [Player]: { attacker: Player, at: number } } = {}
-- Fight rules (S126; S10 had one duel rule): "allow" / "deny" / nil (no opinion) for an attacker-target pair.
local fightRules: { (attacker: Player, target: Player) -> string? } = {}

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

-- Whether the player stands on the city arena (fights there need no toggle).
function PvpService.InArena(player: Player): boolean
	local zone = ZoneService.GetZone(player)
	return zone ~= nil and zone.nameKey == ARENA_ZONE
end

-- S122: the toggle's lock after PvP damage dealt or taken (DESIGN-17 §3 Elixir of Wholeness): the same counter as
-- the `pvp.lockedUntil` branch (Config.PvpCombatLock), not the shorter InPvpCombat window of the healing penalty.
function PvpService.InCombatLock(player: Player): boolean
	local rt = runtimes[player]
	local last = rt and rt.lastPvpCombat
	return last ~= nil and last + Config.PvpCombatLock > now()
end

function PvpService.IsEnabled(player: Player): boolean
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	return character ~= nil and (character.pvpEnabled or PvpService.InArena(player))
end

-- S126: adds a fight rule (duels, ranked matches); the first rule with a verdict decides.
function PvpService.AddFightRule(rule: (attacker: Player, target: Player) -> string?)
	table.insert(fightRules, rule)
end

-- S10 name, kept for DuelService: a fight rule like any other.
function PvpService.SetDuelRule(rule: (attacker: Player, target: Player) -> string?)
	PvpService.AddFightRule(rule)
end

-- Records a hit for kill credit (CombatService, damaging skills).
function PvpService.RecordHit(attacker: Player, target: Player)
	if attacker ~= target then
		lastHit[target] = { attacker = attacker, at = os.clock() }
	end
end

function PvpService.LastAttacker(target: Player): Player?
	local hit = lastHit[target]
	if hit and os.clock() - hit.at <= Config.PvpKillCredit and hit.attacker.Parent ~= nil then
		return hit.attacker
	end
	return nil
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

-- S61 (ROZWOJ 7.6): in PvP combat (Combat.pvp.combatWindow s after the last player hit, duels too), heals, heal
-- over time and absorb shields on the player are weaker.
function PvpService.InPvpCombat(player: Player): boolean
	local rt = runtimes[player]
	return rt ~= nil and PvpRules.inPvpCombat(now(), rt.lastPvpCombat, Combat.pvp.combatWindow)
end

-- S63 (STATY 5): Rending Gash cuts heals and shields on top (strongest cut, no sum; with x0.7 together x0.56).
local function healCut(player: Player): number
	return 1 - StatusEffectService.HealCut(player) / 100
end

function PvpService.HealScale(player: Player): number
	return (if PvpService.InPvpCombat(player) then Combat.pvp.heal else 1) * healCut(player)
end

function PvpService.ShieldScale(player: Player): number
	return (if PvpService.InPvpCombat(player) then Combat.pvp.shield else 1) * healCut(player)
end

-- Whether `attacker` may hit `target` right now (zone of the target, party and guild protection).
function PvpService.CanAttack(attacker: Player, target: Player): (boolean, string?)
	if attacker == target then
		return false, "pvp.deny.self"
	end
	-- Respawn protection (S22): nobody can attack a freshly respawned player, not even in a duel.
	if StatusEffectService.PlayerHas(target, "respawnShield") then
		return false, "pvp.deny.protected"
	end
	for _, rule in fightRules do
		local verdict = rule(attacker, target)
		if verdict == "allow" then
			return true, nil
		elseif verdict == "deny" then
			return false, "pvp.deny.duel"
		end
	end
	return PvpRules.canAttack(
		{ pvpEnabled = PvpService.IsEnabled(attacker) },
		{ pvpEnabled = PvpService.IsEnabled(target) },
		{
			zone = ZoneService.GetPvpZone(target),
			sameParty = PartyService.SameParty(attacker, target),
			sameGuild = GuildService.SameGuild(attacker, target),
			guildProtection = GuildService.Protection(attacker),
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
	ResourceService = registry.Get("ResourceService")
	GuildService = registry.Get("GuildService")
	StatusEffectService = registry.Get("StatusEffectService")
	StatusEffectService.SetPvpScales(PvpService.HealScale, PvpService.ShieldScale)
end

local function nameOf(player: Player): string
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	return if character then character.name else player.DisplayName
end

local function bump(player: Player, field: string)
	if PlayerStateService.HasState(player) and PlayerStateService.GetCharacter(player) then
		PlayerStateService.Update(player, { "character", "pvp", field }, function(value: number?)
			return (value or 0) + 1
		end)
	end
end

-- Duels count their own wins and losses.
function PvpService.CountDuel(winner: Player, loser: Player)
	bump(winner, "duelsWon")
	bump(loser, "duelsLost")
end

local function onDied(victim: Player)
	local killer = PvpService.LastAttacker(victim)
	lastHit[victim] = nil
	if not killer or killer == victim then
		return
	end
	bump(killer, "kills")
	bump(victim, "deaths")
	local killerName, victimName = nameOf(killer), nameOf(victim)
	Net.Fire(victim, "Toast", "pvp.killedBy", { name = killerName }, "error")
	Net.Fire(killer, "Toast", "pvp.youKilled", { name = victimName }, "success")
	local zone = ZoneService.GetZone(victim)
	local mapId = if zone then zone.map else nil
	for _, player in Players:GetPlayers() do
		local other = ZoneService.GetZone(player)
		if other and other.map == mapId then
			Net.Fire(player, "KillFeed", killerName, victimName)
		end
	end
	PvpService.PlayerKilled:Fire(killer, victim, mapId)
end

function PvpService.Start()
	UseGuards.register("arena", PvpService.InArena, "PvpService") -- S122 Logic/UseBlocks (Ristalle sand)
	UseGuards.register("pvpLock", PvpService.InCombatLock, "PvpService") -- S122 Logic/UseBlocks
	Net.Handle("SetPvp", request)

	CharacterService.ModelSpawned:Connect(function(player: Player)
		applyAttribute(player, PvpService.IsEnabled(player))
	end)
	-- The arena switches the nameplate colour too.
	ZoneService.ZoneChanged:Connect(function(player: Player)
		applyAttribute(player, PvpService.IsEnabled(player))
	end)
	ResourceService.Died:Connect(onDied)
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
		lastHit[player] = nil
		task.defer(function()
			runtimes[player] = nil
		end)
	end)
end

return PvpService
