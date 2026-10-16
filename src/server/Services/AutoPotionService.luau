--!strict
-- Auto Potions (S134d, comfort for Dragon Shards): while the account owns the service (forever or with time,
-- Logic/AutoPotion) and it is switched on, every Config.AutoPotion.tick s the character drinks the potion of its bar
-- slot when HP or the class resource (mana / energy) is at or under the player's threshold. The drinking is
-- PotionService.DrinkKind: the same bar, level, arena guards (S126), cooldown and "not needed" as the key; never the
-- Elixir of Wholeness. Where it does not work is the one list Logic/UseBlocks.LISTS.autoPotion asked through
-- src/server/UseGuards (everywhere players fight players); the state branch `autoPotion` = { blocked = Locale key? }
-- tells the HUD. Without the potion in the backpack: one toast per kind every Config.AutoPotion.noneEvery s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local AutoPotion = require(Shared.Logic.AutoPotion)
local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("AutoPotionService")

local AutoPotionService = {
	Name = "AutoPotionService",
	Deps = { "DataService", "PlayerStateService", "PotionService", "ResourceService" },
}

local DataService: any
local PlayerStateService: any
local PotionService: any
local ResourceService: any

local published: { [Player]: string } = {}
local noneSaidAt: { [Player]: { [string]: number } } = {}
local wasOwned: { [Player]: boolean } = {}

local function stateOf(player: Player): AutoPotion.State?
	local data: Types.AccountData? = DataService.GetData(player)
	return if data then data.autoPotion else nil
end

local function forget(player: Player)
	published[player] = nil
	noneSaidAt[player] = nil
	wasOwned[player] = nil
end

local function publish(player: Player, value: Types.AutoPotionRuntime?)
	local sig = if value then value.blocked or "" else "-"
	if published[player] == sig then
		return
	end
	published[player] = sig
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "autoPotion" }, value)
	end
end

-- Fill of a resource in % (current / maximum); a pool without a maximum counts as full.
local function pct(current: number, missing: number): number
	local max = current + missing
	return if max > 0 then current / max * 100 else 100
end

local function sayNone(player: Player, kind: string)
	local said = noneSaidAt[player] or {}
	noneSaidAt[player] = said
	local t = os.clock()
	if t - (said[kind] or -math.huge) >= Config.AutoPotion.noneEvery then
		said[kind] = t
		Net.Fire(player, "Toast", if kind == "hp" then "autoPotion.none.hp" else "autoPotion.none.res", nil, "info")
	end
end

-- One step for `player`: returns the block key, if any.
local function step(player: Player): string?
	if PlayerStateService.GetPhase(player) ~= "playing" or not PlayerStateService.GetCharacter(player) then
		publish(player, nil)
		return nil
	end
	local state = stateOf(player)
	local now = os.time()
	local owned = AutoPotion.owned(state, now)
	if wasOwned[player] and not owned and state and state.on then
		Net.Fire(player, "Toast", "autoPotion.expired", nil, "info")
	end
	wasOwned[player] = owned
	if not AutoPotion.active(state, now) then
		publish(player, nil)
		return nil
	end
	local reason = UseGuards.first(player, UseBlocks.LISTS.autoPotion)
	local blocked = if reason then UseBlocks.key("autoPotion", reason) else nil
	publish(player, { blocked = blocked })
	if blocked then
		return blocked
	end
	local character: Types.CharacterData = PlayerStateService.GetCharacter(player)
	local class = Classes.get(character.class)
	local resource: "mana" | "energy" = if class and class.resource == "energy" then "energy" else "mana"
	local hp, mana, energy = ResourceService.Get(player)
	local res = if resource == "mana" then mana else energy
	local hpPct = pct(hp, ResourceService.Missing(player, "hp"))
	local resPct = pct(res, ResourceService.Missing(player, resource))
	for _, kind in AutoPotion.wants(state, hpPct, resPct) do
		local ok, err = PotionService.DrinkKind(player, kind)
		if not ok and err == "potion.none" then
			sayNone(player, kind)
		end
	end
	return nil
end

local function set(player: Player, on: boolean, hp: number, res: number): (boolean, string?)
	local data: Types.AccountData? = DataService.GetData(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if not AutoPotion.owned(data.autoPotion, os.time()) then
		return false, "autoPotion.error.none"
	end
	local before = data.autoPotion
	local fresh: AutoPotion.State = {
		untilTs = before.untilTs or 0,
		permanent = before.permanent == true,
		on = on,
		hp = AutoPotion.clampThreshold(hp),
		res = AutoPotion.clampThreshold(res),
	}
	PlayerStateService.Set(player, { "account", "autoPotion" }, fresh)
	if (before.on == true) ~= on then
		Net.Fire(player, "Toast", if on then "autoPotion.on" else "autoPotion.off", nil, "info")
	end
	step(player)
	return true, nil
end

-- Seconds of timed service left (admin); -1 when owned forever.
function AutoPotionService.Left(player: Player): number
	local state = stateOf(player)
	if state and state.permanent then
		return -1
	end
	return AutoPotion.left(state, os.time())
end

-- Whether Auto Potions drink HP potions for the player right now (AutoGrindService: "no potions" stop).
function AutoPotionService.DrinksHp(player: Player): boolean
	local state = stateOf(player)
	return AutoPotion.active(state, os.time()) and AutoPotion.clampThreshold(state and state.hp) > 0
end

-- The switch and the thresholds (AutoPotionSet, admin).
function AutoPotionService.Set(player: Player, on: boolean, hp: number, res: number): (boolean, string?)
	return set(player, on, hp, res)
end

function AutoPotionService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	PotionService = registry.Get("PotionService")
	ResourceService = registry.Get("ResourceService")
end

function AutoPotionService.Start()
	Net.Handle("AutoPotionSet", function(player: Player, on: boolean, hp: number, res: number)
		return set(player, on == true, hp, res)
	end)
	Players.PlayerRemoving:Connect(forget)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(step, player)
				if not ok then
					log:error("auto potion step failed for %s: %s", player.Name, tostring(err))
				end
			end
			task.wait(Config.AutoPotion.tick)
		end
	end)
end

return AutoPotionService
