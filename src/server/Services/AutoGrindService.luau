--!strict
-- Auto Hunt (S134d, DESIGN-17 §0.2: the third explicit exception, "faster farming without strength"): the character
-- walks over its whole hunting ground and fights its ordinary monsters by itself. Time from the shop (hunt_*) or the
-- Scroll of the Hunt (boss loot) goes into account.autoGrind.bank and is spent only while hunting, at most
-- Config.AutoGrind.dailySeconds per UTC day (Logic/AutoGrind). The server decides everything:
--   * start (AutoGrind remote): time in the bank and today, no block of Logic/UseBlocks.LISTS.autoGrind, standing on a
--     hunting ground (a named area or a cave, Logic/AutoGrind.groundAt);
--   * every Config.AutoGrind.tick s: the time spent, the stops (Logic/AutoGrind.stopReason: a block, death, no time,
--     the daily cap, leaving the ground, a boss near, low HP, no potions, a full backpack, no kill for stuckSeconds, a
--     manual action), the target (Logic/AutoGrind.pickTarget among the ground's ordinary monsters, set through
--     CombatService.SetServerTarget) and otherwise the next group of the round (Logic/AutoGrind.nextGoal);
--   * the state branch `autoGrind` (Types.AutoGrindRuntime) tells the client where to walk; the client never picks.
-- Rewards: CombatService.reward asks IsActive (EXP and gold x0.7, the EXP source "autoGrind", outside the weekly
-- ranking). A target sent by the client while hunting is the player taking over: the hunt ends ("manual").
-- Registers the UseGuards reason "bossNear" (a living Elite II or boss within Config.AutoGrind.bossRadius) and the use
-- handler of the Scroll of the Hunt (use.kind "autoGrind").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local AutoGrind = require(Shared.Logic.AutoGrind)
local Config = require(Shared.Config)
local Inventory = require(Shared.Logic.Inventory)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Lure = require(Shared.Logic.Lure)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("AutoGrindService")

local AutoGrindService = {
	Name = "AutoGrindService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"CombatService",
		"MonsterService",
		"ResourceService",
		"InventoryService",
		"MonetizationService",
		"ZoneService",
		"PartyService",
		"PotionService",
		"AutoPotionService",
	},
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local CombatService: any
local MonsterService: any
local ResourceService: any
local InventoryService: any
local MonetizationService: any
local ZoneService: any
local PartyService: any
local PotionService: any
local AutoPotionService: any

type Run = {
	area: string,
	mapId: string,
	rect: { number },
	nameKey: string?,
	visited: { [string]: boolean },
	goal: AutoGrind.Group?,
	target: any?, -- the monster
	lastKill: number, -- os.clock()
	lastTick: number, -- os.clock()
	saveAt: number, -- os.clock()
	manual: boolean,
}

local runs: { [Player]: Run } = {}
local published: { [Player]: string } = {}

local function rootPosition(player: Player): Vector3?
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function stateOf(player: Player): AutoGrind.State?
	local data: Types.AccountData? = DataService.GetData(player)
	return if data then data.autoGrind else nil
end

local function timeArgs(seconds: number): { key: string, args: { [string]: any } }
	local key, args = Lure.timeKey(seconds)
	return { key = key, args = args }
end

local function publish(player: Player, value: Types.AutoGrindRuntime?)
	local sig = "-"
	if value then
		local goal = value.goal
		sig =
			`{value.area}|{value.target or ""}|{if goal then `{math.floor(goal.x)},{math.floor(goal.z)}` else ""}|{math.floor(
				value.left
			)}`
	end
	if published[player] == sig then
		return
	end
	published[player] = sig
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "autoGrind" }, value)
	end
end

-- S134d (UseGuards "bossNear"): a living Elite II, boss or world event commander / champion (Elites II) close by.
local function bossNear(player: Player): boolean
	local position = rootPosition(player)
	if not position then
		return false
	end
	for _, monster in MonsterService.Near(position, Config.AutoGrind.bossRadius) do
		if monster.isBoss == true or monster.variant == "elite2" or monster.variant == "boss" then
			return true
		end
	end
	return false
end

-- The ground's monsters around the player as Logic/AutoGrind candidates.
local function candidates(player: Player, position: Vector3): { AutoGrind.Candidate }
	local out: { AutoGrind.Candidate } = {}
	for _, monster in MonsterService.Near(position, Config.AutoGrind.seekRadius + 30) do
		local fightsOther = false
		for other in monster.threat do
			if other ~= player and not PartyService.SameParty(other, player) then
				fightsOther = true
				break
			end
		end
		table.insert(out, {
			ref = monster,
			variant = monster.variant,
			boss = monster.isBoss == true,
			summoned = monster.summoned == true,
			fromSpawner = monster.spawnerId ~= nil,
			area = MonsterService.AreaOf(monster),
			targetable = MonsterService.CanTarget(monster, player),
			level = monster.stats.level,
			distance = (monster:Position() - position).Magnitude,
			fightsOther = fightsOther,
			attacksMe = monster.target == player,
		})
	end
	return out
end

-- Ends the hunt of `player`: `stop` = the reason (a toast autoGrind.stop.<stop> / autoGrind.block.<reason>), nil = the
-- player switched it off.
local function finish(player: Player, stop: AutoGrind.StopReason?, blockReason: string?)
	local run = runs[player]
	if not run then
		return
	end
	runs[player] = nil
	if run.target ~= nil and player.Parent then
		CombatService.SetServerTarget(player, nil)
	end
	publish(player, nil)
	if player.Parent then
		DataService.Save(player)
		local key = if stop then AutoGrind.stopKey(stop, blockReason) else "autoGrind.off"
		Net.Fire(player, "Toast", key, nil, "info")
		Analytics.custom(player, `AutoGrindStop_{stop or "off"}`, 1)
	end
end

local function runtimeOf(run: Run, state: AutoGrind.State?, now: number): Types.AutoGrindRuntime
	local goal = run.goal
	local target = run.target
	return {
		active = true,
		area = run.area,
		goal = if goal and not target then { x = goal.x, y = goal.y or 0, z = goal.z } else nil,
		target = if target and target.entity then target.entity.id else nil,
		left = AutoGrind.left(state, now),
		todayLeft = AutoGrind.todayLeft(state, now),
	}
end

-- One hunting step of `player`.
local function step(player: Player)
	local run = runs[player]
	if not run then
		return
	end
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local position = rootPosition(player)
	if PlayerStateService.GetPhase(player) ~= "playing" or not character or not position then
		finish(player, "left")
		return
	end
	local clock = os.clock()
	local now = os.time()
	local dt = math.max(0, clock - run.lastTick)
	run.lastTick = clock
	local state = AutoGrind.spend(stateOf(player), dt, now)
	PlayerStateService.Set(player, { "account", "autoGrind" }, state)
	if clock >= run.saveAt then
		run.saveAt = clock + Config.AutoGrind.saveEvery
		DataService.Save(player)
	end

	-- the stops
	local zone = ZoneService.GetZone(player)
	local map = Maps.get(run.mapId)
	local outside = zone == nil or zone.map ~= run.mapId or map == nil
	if not outside and map then
		outside = not AutoGrind.inside(
			run.rect,
			position.X - map.offset.x,
			position.Z - map.offset.z,
			Config.AutoGrind.leaveMargin
		)
	end
	local hp = ResourceService.Get(player)
	local missing = ResourceService.Missing(player, "hp")
	local max = hp + missing
	local capacity = InventoryService.CapacityOf(character, player)
	local stop: AutoGrind.StopReason?, blockReason: string? = AutoGrind.stopReason({
		blocked = UseGuards.first(player, UseBlocks.LISTS.autoGrind),
		dead = ResourceService.IsDead(player),
		left = AutoGrind.left(state, now),
		todayLeft = AutoGrind.todayLeft(state, now),
		outside = outside,
		bossNear = false, -- the "bossNear" block of the list above
		hpPct = if max > 0 then hp / max * 100 else 100,
		autoPotionHp = AutoPotionService.DrinksHp(player),
		hasHpPotion = PotionService.HasPotion(player, "hp"),
		autoLoot = MonetizationService.HasPass(player, "autoLoot"),
		freeSlots = Inventory.freeSlots(character.inventory, capacity),
		sinceKill = clock - run.lastKill,
		manual = run.manual,
	})
	if stop then
		finish(player, stop, blockReason)
		return
	end

	-- the target: keep the current one unless someone else is hitting the player
	local list = candidates(player, position)
	local picked = AutoGrind.pickTarget(list, character.level, run.area)
	local current: AutoGrind.Candidate? = nil
	for _, c in list do
		if c.ref == run.target and AutoGrind.eligible(c, character.level, run.area) then
			current = c
			break
		end
	end
	local chosen = picked
	if current and (current.attacksMe or not (picked and picked.attacksMe)) then
		chosen = current
	end
	local monster = if chosen then chosen.ref else nil
	if monster ~= run.target then
		run.target = monster
		CombatService.SetServerTarget(player, if monster and monster.entity then monster.entity.id else nil)
	elseif monster and monster.entity then
		-- resend: the server drops a target out of range for long (the walk brings the character back)
		CombatService.SetServerTarget(player, monster.entity.id)
	end

	-- no target: the next group of the round over the whole ground
	if not monster then
		local here = { x = position.X, z = position.Z }
		local goal = run.goal
		if goal and AutoGrind.arrived(goal, here) then
			run.visited[goal.id] = true
			run.goal = nil
		end
		local groups = MonsterService.GroupsIn(run.area)
		local ready = false
		if run.goal then
			for _, g in groups do
				if g.id == (run.goal :: AutoGrind.Group).id and g.ready then
					ready = true
					break
				end
			end
		end
		if not ready then
			run.goal = AutoGrind.nextGoal(groups, run.visited, here, run.area)
		end
	end
	publish(player, runtimeOf(run, state, now))
end

local function start(player: Player): (boolean, string?)
	if runs[player] then
		return true, nil
	end
	local data: Types.AccountData? = DataService.GetData(player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local position = rootPosition(player)
	if not data or not character or not position or PlayerStateService.GetPhase(player) ~= "playing" then
		return false, "error.wrongPhase"
	end
	local now = os.time()
	local ok, err = AutoGrind.canStart(data.autoGrind, now)
	if not ok then
		return false, err
	end
	local reason = UseGuards.first(player, UseBlocks.LISTS.autoGrind)
	if reason then
		return false, UseBlocks.key("autoGrind", reason)
	end
	local zone = ZoneService.GetZone(player)
	local mapId = if zone then zone.map else character.location.map
	local area, rect, nameKey = AutoGrind.groundAt(mapId, position.X, position.Z)
	if not area or not rect then
		return false, "autoGrind.error.noArea"
	end
	local clock = os.clock()
	local run: Run = {
		area = area,
		mapId = mapId,
		rect = rect,
		nameKey = nameKey,
		visited = {},
		goal = nil,
		target = nil,
		lastKill = clock,
		lastTick = clock,
		saveAt = clock + Config.AutoGrind.saveEvery,
		manual = false,
	}
	runs[player] = run
	PlayerStateService.Set(player, { "account", "autoGrind" }, AutoGrind.rollDay(data.autoGrind, now))
	Net.Fire(player, "Toast", "autoGrind.on", {
		area = if nameKey then `@{nameKey}` else area,
		time = timeArgs(AutoGrind.left(data.autoGrind, now)),
	}, "success")
	Analytics.custom(player, "AutoGrindStart", 1)
	step(player)
	return true, nil
end

local function toggle(player: Player, on: boolean): (boolean, string?)
	if on then
		return start(player)
	end
	finish(player, nil)
	return true, nil
end

-- Whether `player` hunts right now (CombatService rewards, the client through the state branch).
function AutoGrindService.IsActive(player: Player): boolean
	return runs[player] ~= nil
end

-- Start / stop (AutoGrind remote, admin /autogrind stop).
function AutoGrindService.Toggle(player: Player, on: boolean): (boolean, string?)
	return toggle(player, on)
end

-- Seconds in the bank, possible now and left today (admin).
function AutoGrindService.Status(player: Player): (number, number, number)
	local state = stateOf(player)
	local now = os.time()
	return AutoGrind.rollDay(state, now).bank, AutoGrind.left(state, now), AutoGrind.todayLeft(state, now)
end

-- Adds `seconds` to the bank (admin, the scroll); returns the new bank.
function AutoGrindService.Add(player: Player, seconds: number): number
	local fresh = AutoGrind.add(stateOf(player), seconds)
	PlayerStateService.Set(player, { "account", "autoGrind" }, fresh)
	return fresh.bank
end

-- Empties the bank and today's counter (admin); a running hunt stops on its next step.
function AutoGrindService.Clear(player: Player)
	PlayerStateService.Set(player, { "account", "autoGrind" }, { bank = 0, day = 0, used = 0 })
end

-- The Scroll of the Hunt at `index`: Config.AutoGrind.scrollSeconds into the bank.
local function useScroll(player: Player, index: number): (boolean, string?)
	local item = InventoryService.Get(player, index)
	local def = item and Items.get(item.id)
	if not item or not def or not def.use or def.use.kind ~= "autoGrind" then
		return false, "inventory.cannotUse"
	end
	if not DataService.GetData(player) then
		return false, "error.wrongPhase"
	end
	InventoryService.ConsumeAt(player, index)
	local bank = AutoGrindService.Add(player, Config.AutoGrind.scrollSeconds)
	DataService.Save(player)
	Net.Fire(player, "Toast", "autoGrind.added", {
		time = timeArgs(Config.AutoGrind.scrollSeconds),
		left = timeArgs(bank),
	}, "success")
	Analytics.custom(player, "AutoGrindScroll", 1)
	return true, nil
end

function AutoGrindService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	CombatService = registry.Get("CombatService")
	MonsterService = registry.Get("MonsterService")
	ResourceService = registry.Get("ResourceService")
	InventoryService = registry.Get("InventoryService")
	MonetizationService = registry.Get("MonetizationService")
	ZoneService = registry.Get("ZoneService")
	PartyService = registry.Get("PartyService")
	PotionService = registry.Get("PotionService")
	AutoPotionService = registry.Get("AutoPotionService")
	InventoryService.UseHandlers.autoGrind = function(player: Player, index: number)
		return useScroll(player, index)
	end
	CombatService.SetAutoGrindHooks({
		active = AutoGrindService.IsActive,
		manual = function(player: Player)
			local run = runs[player]
			if run then
				run.manual = true
				finish(player, "manual")
			end
		end,
	})
end

function AutoGrindService.Start()
	UseGuards.register("bossNear", bossNear, "AutoGrindService") -- S134d Logic/UseBlocks
	Net.Handle("AutoGrind", function(player: Player, on: boolean)
		return toggle(player, on == true)
	end)
	CombatService.MonsterKilled:Connect(function(info: any, credit: { Player })
		local clock = os.clock()
		for _, player in credit do
			local run = runs[player]
			if run then
				run.lastKill = clock
			end
		end
		for _, run in runs do
			if run.target and run.target.entity and run.target.entity.id == info.entityId then
				run.target = nil
			end
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		finish(player, "left")
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		finish(player, "left")
		published[player] = nil
	end)
	task.spawn(function()
		while true do
			for player in table.clone(runs) do
				local ok, err = pcall(function()
					step(player)
				end)
				if not ok then
					log:error("auto hunt step failed for %s: %s", player.Name, tostring(err))
					pcall(function()
						finish(player, "stuck")
					end)
				end
			end
			task.wait(Config.AutoGrind.tick)
		end
	end)
end

return AutoGrindService
