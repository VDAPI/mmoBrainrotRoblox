--!strict
-- Duels on the city arena (S10). A player challenges another (context menu); the other accepts within 30 s.
-- One duel at a time: later pairs wait in a queue. Both fighters are teleported to opposite sides of the
-- arena, a 3-2-1 countdown runs, then only they can hit each other (PvpService duel rule; others are kept
-- off the arena). A blow that would kill leaves 1 HP and ends the duel; leaving the arena forfeits; after
-- Config.DuelTimeLimit seconds it is a draw. Both are fully restored afterwards; the result is announced
-- on the server and counted in the characters' PvP statistics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Types = require(Shared.Types)

local log = Log.new("DuelService")

local DuelService = {
	Name = "DuelService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ResourceService",
		"PvpService",
		"ZoneService",
		"WorldService",
		"TravelService",
		"AnnounceService",
	},
}

-- City arena (World/Layouts/city: centre 160, 175; half size 52).
local ARENA = { map = "city", x = 160, z = 175, half = 52 }
local EXIT = { x = 160, z = 108 }

type Duel = { a: Player, b: Player, phase: "countdown" | "fight" | "done", startedAt: number }

local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local PvpService: any
local ZoneService: any
local WorldService: any
local TravelService: any
local AnnounceService: any

local invites: { [Player]: { from: Player, expiresAt: number } } = {}
local queue: { { a: Player, b: Player } } = {}
local current: Duel? = nil

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function nameOf(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

local function inDuel(player: Player): boolean
	local duel = current
	return duel ~= nil and duel.phase ~= "done" and (duel.a == player or duel.b == player)
end

function DuelService.InDuel(player: Player): boolean
	return inDuel(player)
end

local function opponent(player: Player): Player?
	local duel = current
	if not duel then
		return nil
	end
	return if duel.a == player then duel.b elseif duel.b == player then duel.a else nil
end

local function onArena(player: Player): boolean
	local zone = ZoneService.GetZone(player)
	return zone ~= nil and zone.nameKey == "zone.arena"
end

local function both(duel: Duel, key: string, args: { [string]: any }?)
	for _, player in { duel.a, duel.b } do
		if player.Parent then
			Net.Fire(player, "BossAnnounce", key, args)
		end
	end
end

local function restore(player: Player)
	if player.Parent and PlayerStateService.HasState(player) then
		if ResourceService.IsDead(player) then
			ResourceService.Revive(player)
		end
		ResourceService.Restore(player)
	end
end

local startNext: () -> ()

local function finish(duel: Duel, winner: Player?, reason: string)
	if duel.phase == "done" then
		return
	end
	duel.phase = "done"
	local loser = if winner == duel.a then duel.b elseif winner == duel.b then duel.a else nil
	for _, fighter in { duel.a, duel.b } do
		if fighter.Parent then
			QuestEvents.fire(fighter, "duel", { won = fighter == winner })
		end
	end
	if winner and loser then
		PvpService.CountDuel(winner, loser)
		AnnounceService.Server("duel.result", { winner = nameOf(winner), loser = nameOf(loser) })
		both(duel, "duel.won", { name = nameOf(winner) })
	else
		both(duel, "duel.draw", nil)
	end
	log:info("duel %s vs %s ended (%s)", duel.a.Name, duel.b.Name, reason)
	task.delay(1.5, function()
		restore(duel.a)
		restore(duel.b)
		if current == duel then
			current = nil
		end
		startNext()
	end)
end

local function start(a: Player, b: Player)
	local duel: Duel = { a = a, b = b, phase = "countdown", startedAt = os.clock() }
	current = duel
	restore(a)
	restore(b)
	local spots = {
		WorldService.GroundCFrame(ARENA.map, ARENA.x - 25, ARENA.z),
		WorldService.GroundCFrame(ARENA.map, ARENA.x + 25, ARENA.z),
	}
	for i, player in { a, b } do
		local spot = spots[i].Position
		local face = Vector3.new(ARENA.x, 0, ARENA.z) + Vector3.new(0, spot.Y, 0)
		task.spawn(TravelService.TeleportToMap, player, ARENA.map, CFrame.lookAt(spot, face))
	end
	task.spawn(function()
		task.wait(1.5)
		for n = Config.DuelCountdown, 1, -1 do
			if current ~= duel or duel.phase == "done" then
				return
			end
			both(duel, "duel.count", { n = n })
			task.wait(1)
		end
		if current == duel and duel.phase == "countdown" then
			duel.phase = "fight"
			duel.startedAt = os.clock()
			both(duel, "duel.fight", nil)
		end
	end)
end

-- A duel heals and teleports, so it must not rescue anyone from a fight or a dungeon (S14 security pass).
local function blockedReason(player: Player): string?
	local char = character(player)
	if not char or ResourceService.IsDead(player) then
		return "duel.error.state"
	end
	if ResourceService.InCombat(player) then
		return "duel.error.combat"
	end
	local map = Maps.get(char.location.map)
	if map and map.biome == "dungeon" then
		return "duel.error.state"
	end
	return nil
end

startNext = function()
	if current then
		return
	end
	while #queue > 0 do
		local pair = table.remove(queue, 1) :: { a: Player, b: Player }
		if pair.a.Parent and pair.b.Parent and character(pair.a) and character(pair.b) then
			local reason = blockedReason(pair.a) or blockedReason(pair.b)
			if reason then
				for _, p in { pair.a, pair.b } do
					Net.Fire(p, "Toast", reason, nil, "warning")
				end
			else
				start(pair.a, pair.b)
				return
			end
		end
	end
end

local function challenge(player: Player, userId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player or PlayerStateService.GetPhase(target) ~= "playing" then
		return false, "party.error.notFound"
	end
	if inDuel(player) or inDuel(target) then
		return false, "duel.error.busy"
	end
	local pending = invites[target]
	if pending and pending.expiresAt > os.clock() then
		return false, "party.error.pending"
	end
	invites[target] = { from = player, expiresAt = os.clock() + Config.DuelInviteSeconds }
	Net.Fire(target, "DuelInvited", nameOf(player), Config.DuelInviteSeconds)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local pending = invites[player]
	invites[player] = nil
	if not pending or pending.expiresAt < os.clock() or pending.from.Parent == nil then
		return false, "party.error.expired"
	end
	local challenger = pending.from
	if not accept then
		Net.Fire(challenger, "Toast", "duel.declined", { name = nameOf(player) }, "info")
		return true, nil
	end
	if inDuel(player) or inDuel(challenger) then
		return false, "duel.error.busy"
	end
	local blocked = blockedReason(player) or blockedReason(challenger)
	if blocked then
		return false, blocked
	end
	table.insert(queue, { a = challenger, b = player })
	if current then
		for _, p in { challenger, player } do
			Net.Fire(p, "Toast", "duel.queued", { n = #queue }, "info")
		end
	end
	startNext()
	return true, nil
end

-- Keeps the duel alive: forfeits, timeout and clearing the arena of spectators.
local function watch()
	local duel = current
	if not duel or duel.phase == "done" then
		return
	end
	for _, player in { duel.a, duel.b } do
		if player.Parent == nil or not character(player) then
			finish(duel, opponent(player), "left")
			return
		end
	end
	if duel.phase == "fight" then
		for _, player in { duel.a, duel.b } do
			if not onArena(player) then
				finish(duel, opponent(player), "forfeit")
				return
			end
		end
		if os.clock() - duel.startedAt > Config.DuelTimeLimit then
			finish(duel, nil, "timeout")
			return
		end
	end
	-- Spectators off the sand while a duel runs.
	for _, player in Players:GetPlayers() do
		if player ~= duel.a and player ~= duel.b and onArena(player) and character(player) then
			task.spawn(
				TravelService.TeleportToMap,
				player,
				ARENA.map,
				WorldService.GroundCFrame(ARENA.map, EXIT.x, EXIT.z)
			)
			Net.Fire(player, "Toast", "duel.arenaBusy", nil, "warning")
		end
	end
end

function DuelService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	PvpService = registry.Get("PvpService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
	TravelService = registry.Get("TravelService")
	AnnounceService = registry.Get("AnnounceService")

	-- Duelists may only hit each other (and only once the fight started); nobody else may hit them.
	PvpService.SetDuelRule(function(attacker: Player, target: Player): string?
		local duel = current
		if not duel or duel.phase == "done" then
			return nil
		end
		local attackerIn = attacker == duel.a or attacker == duel.b
		local targetIn = target == duel.a or target == duel.b
		if attackerIn and targetIn then
			return if duel.phase == "fight" then "allow" else "deny"
		end
		if attackerIn or targetIn then
			return "deny"
		end
		return nil
	end)

	-- A blow that would kill a duelist leaves 1 HP and ends the duel.
	ResourceService.SetDamageFilter(function(player: Player, amount: number, _source: string): number
		local duel = current
		if not duel or duel.phase ~= "fight" or (player ~= duel.a and player ~= duel.b) then
			return amount
		end
		local hp = ResourceService.Get(player)
		if amount >= hp then
			finish(duel, opponent(player), "knockout")
			return math.max(0, hp - 1)
		end
		return amount
	end)
end

function DuelService.Start()
	Net.Handle("DuelChallenge", challenge)
	Net.Handle("DuelRespond", respond)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				watch()
			end)
			if not ok then
				log:error("duel watch failed: %s", tostring(err))
			end
		end
	end)
end

return DuelService
