--!strict
-- Cloak of Luring (DESIGN-17 §3, S122): account time bought for Dragon Shards (account.lure = { untilTs, on }, real
-- time, runs offline too; Logic/Lure). While it is on and has time:
--   * the dark red cape (Util/CosmeticLook.applyLure) is on the character for everyone, also where it is paused;
--   * every Config.Lure.interval s ordinary idle monsters near the player are pulled onto them (Logic/Lure.pick:
--     never Elites, Elites II, bosses, boss helpers or world event monsters; whole groups, at most maxPulled
--     fighting the player at once) through Monster.AddThreat (the taunt path: engage pulls the group);
--   * where it does not work is the one list Logic/UseBlocks.LISTS.lure asked through src/server/UseGuards; the
--     state branch `lure` = { blocked = Locale key?, pulled = last pulse } tells the HUD.
-- No stats and no rewards: a pulled monster dies through CombatService like any other (credit from damage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local CosmeticLook = require(Shared.Util.CosmeticLook)
local Log = require(Shared.Util.Log)
local Lure = require(Shared.Logic.Lure)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("LureService")

local LureService = {
	Name = "LureService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"MonsterService",
		"ZoneService",
		"ResourceService",
	},
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local MonsterService: any

local nextPulse: { [Player]: number } = {}
local published: { [Player]: string } = {}
local capeOn: { [Player]: boolean } = {}
local wasActive: { [Player]: boolean } = {}
local lastPulled: { [Player]: number } = {}

local function lureOf(player: Player): Lure.State?
	local data: Types.AccountData? = DataService.GetData(player)
	return if data then data.lure else nil
end

local function forget(player: Player)
	nextPulse[player] = nil
	published[player] = nil
	capeOn[player] = nil
	wasActive[player] = nil
	lastPulled[player] = nil
end

local function publish(player: Player, value: Types.LureRuntime?)
	local sig = if value then `{value.blocked or ""}|{value.pulled or 0}` else ""
	if published[player] == sig then
		return
	end
	published[player] = sig
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "lure" }, value)
	end
end

local function setCape(player: Player, on: boolean)
	local model = player.Character
	if capeOn[player] == on or not model then
		return
	end
	capeOn[player] = on
	CosmeticLook.applyLure(model, on)
end

local function rootPosition(player: Player): Vector3?
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function busy(monster: any): boolean
	return monster.state == "chase" or monster.state == "cast"
end

-- One pulse: pulls the chosen candidates and returns how many monsters joined the fight (whole groups).
local function pull(player: Player): number
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local position = rootPosition(player)
	if not character or not position then
		return 0
	end
	local fighting = 0
	for _, monster in MonsterService.Near(position, Config.Lure.radius * 3) do
		if busy(monster) and monster.threat[player] ~= nil then
			fighting += 1
		end
	end
	local candidates: { Lure.Candidate } = {}
	for _, monster in MonsterService.Near(position, Config.Lure.radius) do
		local cost = 0
		for _, member in MonsterService.GroupOf(monster) do
			if member.threat[player] == nil then
				cost += 1
			end
		end
		table.insert(candidates, {
			ref = monster,
			group = monster.spawnerId,
			variant = monster.variant,
			boss = monster.isBoss == true,
			summoned = monster.summoned == true,
			fromSpawner = monster.spawnerId ~= nil,
			passive = monster.def.passive == true,
			idle = monster.state == "idle" and next(monster.threat) == nil,
			targetable = MonsterService.CanTarget(monster, player),
			level = monster.stats.level,
			distance = (monster:Position() - position).Magnitude,
			cost = cost,
		})
	end
	local pulled = 0
	for _, c in Lure.pick(candidates, character.level, fighting) do
		c.ref:AddThreat(player, Config.Lure.pullThreat)
		pulled += math.max(1, c.cost)
	end
	if pulled > 0 then
		Analytics.custom(player, "LurePulled", pulled)
	end
	return pulled
end

-- One loop step for `player` (also right after toggling and from /lure pulse with `force`, which skips the
-- interval). Returns the monsters pulled now and the block key, if any.
local function step(player: Player, force: boolean?): (number, string?)
	local character = PlayerStateService.GetCharacter(player)
	if PlayerStateService.GetPhase(player) ~= "playing" or not character then
		publish(player, nil)
		return 0, nil
	end
	local state = lureOf(player)
	local active = Lure.active(state, os.time())
	setCape(player, active)
	if wasActive[player] and not active and state and state.on then
		Net.Fire(player, "Toast", "lure.expired", nil, "info")
	end
	wasActive[player] = active
	if not active then
		lastPulled[player] = nil
		publish(player, nil)
		return 0, nil
	end
	local reason = UseGuards.first(player, UseBlocks.LISTS.lure)
	local blocked = if reason then UseBlocks.key("lure", reason) else nil
	publish(player, { blocked = blocked, pulled = lastPulled[player] })
	if blocked then
		return 0, blocked
	end
	local t = os.clock()
	if not force and t < (nextPulse[player] or 0) then
		return 0, nil
	end
	nextPulse[player] = t + Config.Lure.interval
	local n = pull(player)
	lastPulled[player] = n
	publish(player, { blocked = nil, pulled = n })
	return n, nil
end

local function toggle(player: Player, on: boolean): (boolean, string?)
	local data: Types.AccountData? = DataService.GetData(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if on and Lure.left(data.lure, os.time()) <= 0 then
		return false, "lure.error.none"
	end
	PlayerStateService.Set(player, { "account", "lure", "on" }, on)
	Net.Fire(player, "Toast", if on then "lure.on" else "lure.off", nil, "info")
	step(player)
	return true, nil
end

-- Seconds of cloak time the player has (admin).
function LureService.Left(player: Player): number
	return Lure.left(lureOf(player), os.time())
end

-- One step now; `force` pulls without waiting for the interval (admin /lure pulse).
function LureService.Step(player: Player, force: boolean?): (number, string?)
	return step(player, force)
end

-- The switch (LureToggle, admin /lure on|off).
function LureService.Toggle(player: Player, on: boolean): (boolean, string?)
	return toggle(player, on)
end

function LureService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	MonsterService = registry.Get("MonsterService")
end

function LureService.Start()
	Net.Handle("LureToggle", function(player: Player, on: boolean)
		return toggle(player, on == true)
	end)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		-- a new model has no cape yet: the next step puts it back (after CosmeticService; applyLure works either way)
		capeOn[player] = nil
		task.defer(step, player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		forget(player)
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "lure" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(forget)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					step(player)
				end)
				if not ok then
					log:error("lure step failed for %s: %s", player.Name, tostring(err))
				end
			end
			task.wait(Config.Lure.tick)
		end
	end)
end

return LureService
