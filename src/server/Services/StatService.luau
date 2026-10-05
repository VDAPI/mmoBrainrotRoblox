--!strict
-- Derived statistics of the active character (Logic/StatCalc). Keeps the result in memory, replicates it
-- as state branch `derived`, applies WalkSpeed, and handles stat point allocation.
--
-- Later systems plug in without touching this file:
--   StatService.RegisterModifierSource("gear", function(player, character) return { key = "source.gear",
--       flat = {...}, pct = {...} } end)     -- S04 items, S05 passives, S07 blessings, S12 guild
--   StatService.SetWeaponProvider(function(player, character) return { dmg, mdmg, speed, ranged } end)
-- and call StatService.Invalidate(player) whenever their contribution changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Signal = require(ReplicatedStorage.Packages.Signal)
local StatCalc = require(Shared.Logic.StatCalc)
local Stats = require(Shared.Data.Stats)
local Types = require(Shared.Types)

local log = Log.new("StatService")

type Provider = (player: Player, character: Types.CharacterData) -> StatCalc.Source?
type WeaponProvider = (player: Player, character: Types.CharacterData) -> StatCalc.Weapon?

local StatService = {
	Name = "StatService",
	Deps = { "PlayerStateService", "CharacterService" },
	-- (player, result: StatCalc.Result) after every recompute.
	Changed = Signal.new(),
}

local PlayerStateService: any
local CharacterService: any

local providers: { [string]: Provider } = {}
local weaponProvider: WeaponProvider? = nil
local results: { [Player]: StatCalc.Result } = {}
local dirty: { [Player]: boolean } = {}

function StatService.RegisterModifierSource(name: string, provider: Provider)
	assert(providers[name] == nil, `StatService: modifier source '{name}' registered twice`)
	providers[name] = provider
end

function StatService.SetWeaponProvider(provider: WeaponProvider)
	weaponProvider = provider
end

function StatService.Get(player: Player): StatCalc.Result?
	return results[player]
end

function StatService.GetValue(player: Player, id: string): number
	local result = results[player]
	return if result then result.values[id] or 0 else 0
end

-- Players holding the sprint key (S18): walk speed x Config.SprintMultiplier.
local sprinting: { [Player]: boolean? } = {}

local function applyWalkSpeed(player: Player)
	local result = results[player]
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if result and humanoid then
		local sprint = sprinting[player] == true and humanoid.Health > 0
		humanoid.WalkSpeed = result.walkSpeed * (if sprint then Config.SprintMultiplier else 1)
	end
end

function StatService.SetSprint(player: Player, on: boolean)
	if (sprinting[player] == true) == on then
		return
	end
	sprinting[player] = if on then true else nil
	applyWalkSpeed(player)
end

function StatService.IsSprinting(player: Player): boolean
	return sprinting[player] == true
end

local function collectSources(player: Player, character: Types.CharacterData): { StatCalc.Source }
	local names = {}
	for name in providers do
		table.insert(names, name)
	end
	table.sort(names)
	local list = {}
	for _, name in names do
		local ok, source = pcall(providers[name], player, character)
		if not ok then
			log:error("modifier source '%s' failed: %s", name, tostring(source))
		elseif source then
			source.key = source.key or `source.{name}`
			table.insert(list, source)
		end
	end
	return list
end

-- Recomputes immediately. Returns the result (nil when no character is active).
function StatService.Recompute(player: Player): StatCalc.Result?
	dirty[player] = nil
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		results[player] = nil
		return nil
	end
	local sources = collectSources(player, character)
	local weapon: StatCalc.Weapon? = nil
	if weaponProvider then
		local ok, value = pcall(weaponProvider, player, character)
		weapon = if ok then value else nil
	end
	if not weapon then
		-- Bare hands, but ranged classes still scale their basic attack with DEX.
		local class = Classes.get(character.class)
		local unarmed = Stats.Formula.unarmed
		weapon = {
			dmg = unarmed.dmg,
			mdmg = unarmed.mdmg,
			speed = unarmed.speed,
			ranged = if class then class.basicAttack.ranged else false,
		}
	end
	local result = StatCalc.compute({
		level = character.level,
		stats = character.stats,
		sources = sources,
		weapon = weapon,
	})
	results[player] = result
	PlayerStateService.Set(player, { "derived" }, {
		primary = result.primary,
		values = result.values,
		breakdown = result.breakdown,
		mods = StatCalc.merge(sources, "source.total"),
		weapon = weapon,
	})
	applyWalkSpeed(player)
	StatService.Changed:Fire(player, result)
	return result
end

-- Schedules a recompute on the next frame (coalesces bursts, e.g. equipping several items).
function StatService.Invalidate(player: Player)
	dirty[player] = true
end

-- AllocateStats({ str = 2, vit = 3 }): spends unallocated points. Validated against statPoints.
local function allocate(player: Player, request: { [any]: any }): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	local total = 0
	local adds: { [string]: number } = {}
	for key, value in request do
		if type(key) ~= "string" or not table.find(Stats.primary, key) then
			return false, "error.badRequest"
		end
		if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value > 10000 then
			return false, "error.badRequest"
		end
		adds[key] = value
		total += value
	end
	if total <= 0 then
		return false, "error.badRequest"
	end
	if total > character.statPoints then
		return false, "error.notEnoughPoints"
	end
	-- Single step, no yields: check and write together (ARCHITECTURE §10).
	for id, value in adds do
		PlayerStateService.Update(player, { "character", "stats", id }, function(current: number)
			return current + value
		end)
	end
	PlayerStateService.Set(player, { "character", "statPoints" }, character.statPoints - total)
	StatService.Recompute(player)
	QuestEvents.fire(player, "stats", nil)
	return true, nil
end

function StatService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
end

function StatService.Start()
	Net.Handle("AllocateStats", allocate)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		StatService.Recompute(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		results[player] = nil
		dirty[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "derived" }, nil)
		end
	end)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		sprinting[player] = nil
		applyWalkSpeed(player)
	end)
	Net.On("SetSprint", function(player: Player, on: boolean)
		StatService.SetSprint(player, on)
	end)

	RunService.Heartbeat:Connect(function()
		for player in dirty do
			StatService.Recompute(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			results[player] = nil
			dirty[player] = nil
			sprinting[player] = nil
		end)
	end)
end

return StatService
