--!strict
-- After-fight meter (S134f, DESIGN §16 / §17, Logic/FightStats): books damage dealt and taken, healing, shields,
-- intercepted blows, deaths and dodged telegraphed blows of the fights with a boss (DungeonService), an Elite II
-- (begun here on the first blow either way) and an Invasion (WorldEventService). Nothing is sent during the fight; at
-- the end every participant gets `FightSummary` with the table of HIS party only (strangers at the same Elite II are
-- not shown and do not count in the damage share). New numbers come through signals (CombatService.MonsterDamaged /
-- TelegraphResolved, ResourceService.Damaged / Healed / Died, StatusEffectService.Intercepted), never a copied formula.
--
-- A player takes part when he dealt damage to the fight's monster, took damage from it, healed / shielded / guarded a
-- participant or stood in one of its telegraphed areas. An Elite II walking home (leash) or despawned without a
-- wipe is dropped without a summary; a boss walking home starts its numbers over (Reset, like S60).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local FightStats = require(Shared.Logic.FightStats)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Rarities = require(Shared.Data.Rarities)
local Types = require(Shared.Types)

local log = Log.new("FightLogService")

local FightLogService = {
	Name = "FightLogService",
	Deps = { "PlayerStateService", "PartyService", "CombatService", "ResourceService", "StatusEffectService" },
}

local CFG = Config.FightLog
local MAX_AGE = 3600 -- a fight nobody ended is dropped after an hour (safety net)

export type DropItem = FightStats.DropItem
-- S149b: `points` = the world boss's contribution points of every participant (its place on the summary)
export type Extras = { drops: { [Player]: { DropItem } }?, points: { [Player]: number }? }

type Entry = {
	id: number,
	fight: FightStats.Fight,
	nameKey: string,
	players: { [number]: Player }, -- participants by user id
	names: { [number]: string },
	classes: { [number]: string },
	monster: any?, -- an Elite II fight's monster (leash / despawn check)
	entityId: string?,
}

local PlayerStateService: any
local PartyService: any
local CombatService: any
local ResourceService: any
local StatusEffectService: any

local nextId = 0
local fights: { [number]: Entry } = {}
local primary: { [any]: number } = {} -- monster -> its own fight (boss, Elite II, Invasion commander)
local eventOf: { [any]: number } = {} -- monster -> the Invasion it belongs to (wave monsters)
local byEntity: { [string]: number } = {} -- Elite II entity id -> fight (MonsterKilled)

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function isMonster(value: any): boolean
	return type(value) == "table" and type(value.damageBy) == "table" and value.def ~= nil
end

local function active(id: number?): Entry?
	local entry = if id then fights[id] else nil
	return if entry and entry.fight.endedAt == nil then entry else nil
end

local function join(entry: Entry, player: Player)
	local userId = player.UserId
	if (entry.players :: any)[userId] == nil then
		entry.players[userId] = player
		local char = character(player)
		entry.names[userId] = if char then char.name else player.DisplayName
		entry.classes[userId] = if char then char.class :: string else nil :: any
	end
	FightStats.join(entry.fight, userId)
end

local function add(entry: Entry, player: Player, field: FightStats.Field, amount: number)
	join(entry, player)
	FightStats.add(entry.fight, player.UserId, field, amount)
end

local function forget(entry: Entry)
	fights[entry.id] = nil
	for monster, id in primary do
		if id == entry.id then
			primary[monster] = nil
		end
	end
	for monster, id in eventOf do
		if id == entry.id then
			eventOf[monster] = nil
		end
	end
	if entry.entityId then
		byEntity[entry.entityId] = nil
	end
end

-- Active fights `player` takes part in.
local function fightsOf(player: Player): { Entry }
	local out = {}
	for _, entry in fights do
		if entry.fight.endedAt == nil and (entry.players :: any)[player.UserId] ~= nil then
			table.insert(out, entry)
		end
	end
	return out
end

-- User ids of `player`'s party members who took part (always the player).
local function partyIdsOf(entry: Entry, player: Player): { number }
	local ids = { player.UserId }
	for _, member in PartyService.Members(player) do
		if member ~= player and (entry.players :: any)[member.UserId] ~= nil then
			table.insert(ids, member.UserId)
		end
	end
	return ids
end

-- Begins a fight; `members` join at once (a boss run's party).
function FightLogService.Begin(kind: FightStats.Kind, key: string, members: { Player }?, nameKey: string?): number
	nextId += 1
	local entry: Entry = {
		id = nextId,
		fight = FightStats.new(kind, key, os.clock()),
		nameKey = nameKey or "",
		players = {},
		names = {},
		classes = {},
	}
	fights[entry.id] = entry
	local list: { Player } = members or {}
	for _, member in list do
		join(entry, member)
	end
	return entry.id
end

function FightLogService.Join(id: number, player: Player)
	local entry = active(id)
	if entry then
		join(entry, player)
	end
end

-- The monster's own fight (a boss, the Invasion commander).
function FightLogService.Bind(id: number, monster: any)
	if active(id) then
		primary[monster] = id
	end
end

-- A monster of an Invasion (its damage also counts there; an Elite II of a wave still gets its own fight).
function FightLogService.BindEvent(id: number, monster: any)
	if active(id) then
		eventOf[monster] = id
	end
end

-- The newest active fight the player takes part in.
function FightLogService.OfPlayer(player: Player): number?
	local best: number? = nil
	for _, entry in fightsOf(player) do
		if best == nil or entry.id > best then
			best = entry.id
		end
	end
	return best
end

function FightLogService.OfMonster(monster: any): number?
	return if active(primary[monster])
		then primary[monster]
		else if active(eventOf[monster]) then eventOf[monster] else nil
end

-- A boss walking home after a leash: its numbers start over (deaths stay).
function FightLogService.Reset(id: number)
	local entry = active(id)
	if entry then
		FightStats.reset(entry.fight)
	end
end

-- Ends a fight without any summary (an Elite II reset, a cancelled event, an admin reset).
function FightLogService.Drop(id: number)
	local entry = fights[id]
	if entry then
		forget(entry)
	end
end

-- The player's numbers in a fight (S134b party loot: who was active), or nil.
function FightLogService.Stat(id: number, player: Player): FightStats.Stat?
	local entry = fights[id]
	return if entry then entry.fight.stats[player.UserId] else nil
end

-- The table of `player`'s party right now (the boss reward card is built before the fight ends).
function FightLogService.Snapshot(id: number, player: Player): any?
	local entry = fights[id]
	if not entry then
		return nil
	end
	local ids = partyIdsOf(entry, player)
	local summary = FightStats.summary(entry.fight, ids, os.clock())
	return {
		rows = FightStats.rows(entry.fight, ids, entry.names, entry.classes),
		time = summary.time,
		deaths = summary.deaths,
		dodged = summary.dodged,
		aimed = summary.aimed,
	}
end

-- What `player` sees under "Party loot": his own items, the others' from Legendary up (name + item), the rest counted.
local function dropFor(entry: Entry, player: Player, drops: { [Player]: { DropItem } }): FightStats.DropView
	local others = {}
	for _, userId in partyIdsOf(entry, player) do
		local member = entry.players[userId]
		if member and member ~= player and drops[member] then
			table.insert(others, { n = entry.names[userId] or member.DisplayName, items = drops[member] })
		end
	end
	return FightStats.dropView(drops[player], others, Rarities.LEGENDARY)
end

-- Ends a fight and sends every participant still in the game the table of his party (when worth it).
function FightLogService.End(id: number, outcome: FightStats.Outcome, extras: Extras?)
	local entry = fights[id]
	if not entry then
		return
	end
	local fight = entry.fight
	FightStats.finish(fight, os.clock(), outcome)
	local drops = if extras then extras.drops else nil
	local points: { [number]: number }? = nil
	if extras and extras.points then
		local byId: { [number]: number } = {}
		for player, value in extras.points do
			byId[player.UserId] = value
		end
		points = byId
	end
	for _, player in entry.players do
		if player.Parent == nil then
			continue
		end
		local ids = partyIdsOf(entry, player)
		if not FightStats.worthSending(fight, ids, CFG.minSeconds) then
			continue
		end
		local standing = if points then { points = points, userId = player.UserId } else nil
		local summary = FightStats.summary(fight, ids, nil, standing)
		Net.Fire(player, "FightSummary", {
			kind = fight.kind,
			key = fight.key,
			nameKey = entry.nameKey,
			outcome = outcome,
			time = summary.time,
			rows = FightStats.rows(fight, ids, entry.names, entry.classes),
			deaths = summary.deaths,
			dodged = summary.dodged,
			aimed = summary.aimed,
			drop = if drops then dropFor(entry, player, drops) else nil,
			place = summary.place, -- S149b: a world boss fight's place in the contribution
		})
	end
	forget(entry)
end

-- Fights a blow of / on `monster` counts in: its own (an Elite II begins one now), its Invasion, else (a boss's
-- summons) the boss fight `player` takes part in.
local function fightsOfMonster(monster: any, player: Player?): { Entry }
	local out: { Entry } = {}
	local own = active(primary[monster])
	if not own and monster.variant == "elite2" and monster.state ~= "dead" then
		local entityId = if monster.entity then monster.entity.id else nil
		local id = FightLogService.Begin("elite2", entityId or "elite2", nil, monster:Name())
		primary[monster] = id
		own = fights[id]
		if own then
			own.monster = monster
			own.entityId = entityId
			if entityId then
				byEntity[entityId] = id
			end
		end
	end
	if own then
		table.insert(out, own)
	end
	local event = active(eventOf[monster])
	if event and event ~= own then
		table.insert(out, event)
	end
	if #out == 0 and player then
		for _, entry in fightsOf(player) do
			if entry.fight.kind == "boss" then
				table.insert(out, entry)
			end
		end
	end
	return out
end

local function allDown(entry: Entry): boolean
	for _, player in entry.players do
		if player.Parent ~= nil and not ResourceService.IsDead(player) then
			return false
		end
	end
	return true
end

-- Elite II fights: a leash return, a despawn or everyone gone ends them without a summary.
local function step()
	local now = os.clock()
	for _, entry in table.clone(fights) do
		if now - entry.fight.startedAt > MAX_AGE then
			forget(entry)
			continue
		end
		local monster = entry.monster
		if entry.fight.kind == "elite2" and monster then
			local gone = monster.state == "return" or monster.state == "dead" or monster.model.Parent == nil
			if gone then
				forget(entry)
			end
		end
	end
end

function FightLogService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	PartyService = registry.Get("PartyService")
	CombatService = registry.Get("CombatService")
	ResourceService = registry.Get("ResourceService")
	StatusEffectService = registry.Get("StatusEffectService")
end

function FightLogService.Start()
	CombatService.MonsterDamaged:Connect(function(monster: any, player: Player, dealt: number)
		for _, entry in fightsOfMonster(monster, player) do
			add(entry, player, "dmg", dealt)
		end
	end)
	ResourceService.Damaged:Connect(function(player: Player, amount: number, source: string, attacker: any?)
		if source == "pvp" or source == "admin" then
			return
		end
		local list: { Entry } = if isMonster(attacker) then fightsOfMonster(attacker, player) else fightsOf(player)
		for _, entry in list do
			add(entry, player, "taken", amount)
		end
	end)
	ResourceService.Healed:Connect(function(target: Player, amount: number, source: Player?, kind: string)
		if not source then
			return
		end
		for _, entry in fightsOf(target) do
			add(entry, source, if kind == "shield" then "shield" else "heal", amount)
		end
	end)
	StatusEffectService.Intercepted:Connect(function(guard: Player, target: Player, moved: number)
		for _, entry in fightsOf(target) do
			add(entry, guard, "intercept", moved)
		end
	end)
	ResourceService.Died:Connect(function(player: Player)
		local char = character(player)
		local name = if char then char.name else player.DisplayName
		for _, entry in fightsOf(player) do
			FightStats.death(entry.fight, player.UserId, name, os.clock())
			if entry.fight.kind == "elite2" and allDown(entry) then
				FightLogService.End(entry.id, "wipe")
			end
		end
	end)
	CombatService.TelegraphResolved:Connect(
		function(monster: any, _abilityId: string, aimed: { Player }, hit: { Player })
			local list = fightsOfMonster(monster, nil)
			for _, entry in list do
				for _, player in aimed do
					add(entry, player, "aimed", 1)
					if not table.find(hit, player) then
						add(entry, player, "dodged", 1)
					end
				end
			end
		end
	)
	CombatService.MonsterKilled:Connect(function(info: any)
		local id = byEntity[info.entityId]
		if id and active(id) and info.variant == "elite2" then
			FightLogService.End(id, "win")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				step()
			end)
			if not ok then
				log:error("fight log step failed: %s", tostring(err))
			end
		end
	end)
end

return FightLogService
