--!strict
-- Party auras (S61, ROZWOJ 7.3). Every AURA.tick seconds each owner of an aura (path nodes through Logic/Paths.auras,
-- or SetExtra: /aura) who is alive and in combat refreshes a short buff (AURA.duration) on every party member who is
-- alive, in combat and inside the aura (Logic/Paths.inAura). The buff is a StatusEffectService effect of the aura's
-- category with skillId = the node id, so different categories add up, one category keeps its strongest effect
-- (Logic/EffectStack) and the same aura of two owners counts once. A circle aura covers its owner (solo too), a behind
-- aura only the allies behind them.
-- S74 (ROZWOJ 7.3, 10.5): ground zones (the War Banner) pulse on the same loop after the auras: AddZone with a pulse
-- closure from the skill handler; a zone ends at endsAt, when its owner dies or leaves, or when the owner plants a new
-- one with the same key. Zones need no combat and are not auras (no group rule): two banners give two entries and
-- Logic/EffectStack keeps the strongest per category.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local BuffCategories = require(Shared.Data.BuffCategories)
local EffectStack = require(Shared.Logic.EffectStack)
local Log = require(Shared.Util.Log)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local Types = require(Shared.Types)

local log = Log.new("PartyAura")

local AURA = PathData.AURA

local PartyAuraService = {
	Name = "PartyAuraService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"PartyService",
		"ResourceService",
		"StatusEffectService",
		"EntityService",
		"CombatService",
		"EquipmentService",
		"PathService",
	},
}

local PlayerStateService: any
local CharacterService: any
local PartyService: any
local ResourceService: any
local StatusEffectService: any
local EntityService: any
local CombatService: any
local EquipmentService: any

-- Auras of the path nodes per player (nil = not computed yet) and extra auras by key (/aura: "admin").
local nodeAuras: { [Player]: { Paths.Aura } } = {}
local extras: { [Player]: { [string]: Paths.Aura } } = {}
-- (receiver, nodeId) -> owner who gave it in the last pass: a tie keeps that owner (no flicker).
local lastOwner: { [Player]: { [string]: Player } } = {}

export type Zone = {
	key: string, -- one per owner and skill: "<skillId>:<UserId>"
	owner: Player,
	center: Vector3,
	radius: number,
	endsAt: number, -- os.clock()
	pulse: () -> (), -- one pass over the circle (closure of the skill handler)
	onEnd: (() -> ())?, -- removes the replicated model
}

local zones: { [string]: Zone } = {}

local function flat(position: Vector3): Paths.Flat
	return { x = position.X, z = position.Z }
end

local function aurasOf(player: Player): { Paths.Aura }
	local cached = nodeAuras[player]
	if cached == nil then
		local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		cached = if character then Paths.auras(character, EquipmentService.WeaponTypes(player)) else {}
		nodeAuras[player] = cached
	end
	local extra = extras[player]
	if extra == nil or next(extra) == nil then
		return cached :: { Paths.Aura }
	end
	local all = table.clone(cached :: { Paths.Aura })
	for _, aura in extra do
		table.insert(all, aura)
	end
	return all
end

local function forget(player: Player)
	nodeAuras[player] = nil
end

-- Adds (aura) or removes (nil) an aura that does not come from path nodes.
function PartyAuraService.SetExtra(player: Player, key: string, aura: Paths.Aura?)
	local own = extras[player]
	if aura == nil then
		if own then
			own[key] = nil
		end
		return
	end
	if not own then
		own = {}
		extras[player] = own
	end
	own[key] = aura
end

-- The anchor of a "behind" aura of `owner` (S73's behindEffect uses it too): the position of the owner's target when
-- it is a living monster; without one, the positions of living monsters within AURA.fallbackRange that fight the
-- owner. A player target never counts, so the cover needs a monster.
function PartyAuraService.BehindAnchor(owner: Player): (Paths.Flat?, { Paths.Flat })
	local target = CombatService.GetTarget(owner)
	if target and target.kind == "monster" and target.monster and target.monster:IsAlive() then
		local position = EntityService.Position(target)
		if position then
			return flat(position), {}
		end
	end
	local monsters: { Paths.Flat } = {}
	local ownerEntity = EntityService.GetPlayerEntity(owner)
	local ownerPosition = ownerEntity and EntityService.Position(ownerEntity)
	if not ownerPosition then
		return nil, monsters
	end
	for _, entity in EntityService.QueryMonsters(ownerPosition, AURA.fallbackRange) do
		local monster = entity.monster
		if monster and monster:IsAlive() and monster.threat[owner] ~= nil then
			local position = EntityService.Position(entity)
			if position then
				table.insert(monsters, flat(position))
			end
		end
	end
	return nil, monsters
end

type Member = { player: Player, entity: any, at: Paths.Flat, alive: boolean, fighting: boolean }
type Grant = { owner: Player, aura: Paths.Aura, strength: number }

local function alive(player: Player): boolean
	return PlayerStateService.GetPhase(player) == "playing"
		and player.Character ~= nil
		and not ResourceService.IsDead(player)
end

local function strengthOf(aura: Paths.Aura): number
	return EffectStack.strength({ category = aura.category, stats = aura.stats, value = aura.stats.value, at = 0 })
end

local function apply(receiver: Member, grant: Grant)
	local aura = grant.aura
	local category = BuffCategories.get(aura.category)
	if not category or category.side ~= "ally" or not category.kind then
		return
	end
	local options: { [string]: any } = {
		duration = AURA.duration,
		source = grant.owner,
		skillId = aura.nodeId,
		category = aura.category,
	}
	if category.kind == "statBuff" then
		options.stats = aura.stats
		options.pct = category.mode == "pct"
	else
		options.value = aura.stats.value or 0
	end
	StatusEffectService.Apply(receiver.entity, category.kind, options :: any)
end

local warned: { [string]: boolean } = {}

-- One pass over one group (a party or a lone player).
local function passGroup(players: { Player })
	local owners: { { player: Player, auras: { Paths.Aura } } } = {}
	for _, player in players do
		local list = aurasOf(player)
		if #list > 0 then
			table.insert(owners, { player = player, auras = list })
		end
	end
	if #owners == 0 then
		return
	end
	local members: { Member } = {}
	local byPlayer: { [Player]: Member } = {}
	for _, player in players do
		local entity = EntityService.GetPlayerEntity(player)
		local position = entity and EntityService.Position(entity)
		if entity and position then
			local member: Member = {
				player = player,
				entity = entity,
				at = flat(position),
				alive = alive(player),
				fighting = ResourceService.InCombat(player),
			}
			table.insert(members, member)
			byPlayer[player] = member
		end
	end
	-- receiver -> nodeId -> the strongest grant
	local best: { [Player]: { [string]: Grant } } = {}
	for _, owner in owners do
		local ownerMember = byPlayer[owner.player]
		if not ownerMember or not ownerMember.alive or not ownerMember.fighting then
			continue
		end
		local threat: Paths.Flat? = nil
		local monsters: { Paths.Flat }? = nil
		local anchored = false
		for _, aura in owner.auras do
			local category = BuffCategories.get(aura.category)
			if not category or category.side ~= "ally" then
				if not warned[aura.category] then
					warned[aura.category] = true
					log:warn("aura %s has no ally category (%s)", aura.nodeId, aura.category)
				end
				continue
			end
			if aura.shape == "behind" and not anchored then
				anchored = true
				threat, monsters = PartyAuraService.BehindAnchor(owner.player)
			end
			local strength = strengthOf(aura)
			for _, receiver in members do
				if not receiver.alive or not receiver.fighting then
					continue
				end
				if receiver.player == owner.player then
					if aura.shape == "behind" then
						continue
					end
				elseif not Paths.inAura(aura, ownerMember.at, receiver.at, threat, monsters) then
					continue
				end
				local mine = best[receiver.player]
				if not mine then
					mine = {}
					best[receiver.player] = mine
				end
				local current = mine[aura.nodeId]
				local previous = lastOwner[receiver.player] and lastOwner[receiver.player][aura.nodeId]
				if
					current == nil
					or strength > current.strength
					or (strength == current.strength and owner.player == previous)
				then
					mine[aura.nodeId] = { owner = owner.player, aura = aura, strength = strength }
				end
			end
		end
	end
	for _, member in members do
		local grants = best[member.player]
		local given: { [string]: Player } = {}
		if grants then
			for nodeId, grant in grants do
				apply(member, grant)
				given[nodeId] = grant.owner
			end
		end
		lastOwner[member.player] = given
	end
end

local function endZone(zone: Zone)
	if zones[zone.key] == zone then
		zones[zone.key] = nil
	end
	local onEnd = zone.onEnd
	if onEnd then
		local ok, err = pcall(function()
			onEnd()
		end)
		if not ok then
			log:error("zone %s end failed: %s", zone.key, tostring(err))
		end
	end
end

local function pulseZone(zone: Zone)
	local ok, err = pcall(function()
		zone.pulse()
	end)
	if not ok then
		log:error("zone %s pulse failed: %s", zone.key, tostring(err))
	end
end

-- Adds a ground zone; one with the same key ends first (its onEnd runs). The zone pulses at once.
function PartyAuraService.AddZone(zone: Zone)
	local old = zones[zone.key]
	if old then
		endZone(old)
	end
	zones[zone.key] = zone
	pulseZone(zone)
end

function PartyAuraService.RemoveZone(key: string)
	local zone = zones[key]
	if zone then
		endZone(zone)
	end
end

function PartyAuraService.RemoveZonesOf(owner: Player)
	local list: { Zone } = {}
	for _, zone in zones do
		if zone.owner == owner then
			table.insert(list, zone)
		end
	end
	for _, zone in list do
		endZone(zone)
	end
end

local function passZones()
	local t = os.clock()
	local list: { Zone } = {}
	for _, zone in zones do
		table.insert(list, zone)
	end
	for _, zone in list do
		local owner = zone.owner
		if t >= zone.endsAt or owner.Parent == nil or ResourceService.IsDead(owner) then
			endZone(zone)
		else
			pulseZone(zone)
		end
	end
end

local function pass()
	local done: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local party = PartyService.Get(player)
		if party then
			if done[party.id] then
				continue
			end
			done[party.id] = true
		end
		local ok, err = pcall(function()
			passGroup(PartyService.Members(player))
		end)
		if not ok then
			log:error("aura pass failed for %s: %s", player.Name, tostring(err))
		end
	end
	passZones()
end

function PartyAuraService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	PartyService = registry.Get("PartyService")
	ResourceService = registry.Get("ResourceService")
	StatusEffectService = registry.Get("StatusEffectService")
	EntityService = registry.Get("EntityService")
	CombatService = registry.Get("CombatService")
	EquipmentService = registry.Get("EquipmentService")
	local PathService = registry.Get("PathService")
	PathService.Changed:Connect(forget)
	EquipmentService.Changed:Connect(function(player: Player)
		forget(player)
	end)
end

function PartyAuraService.Start()
	local function leave(player: Player)
		nodeAuras[player] = nil
		extras[player] = nil
		lastOwner[player] = nil
		PartyAuraService.RemoveZonesOf(player)
	end
	CharacterService.CharacterLeaving:Connect(leave)
	Players.PlayerRemoving:Connect(leave)
	-- S74 (ROZWOJ 10.5): the banner falls at once when its owner dies
	ResourceService.Died:Connect(function(player: Player)
		PartyAuraService.RemoveZonesOf(player)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < AURA.tick then
			return
		end
		accumulator = 0
		pass()
	end)
end

return PartyAuraService
