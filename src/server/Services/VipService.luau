--!strict
-- VIP benefits (DESIGN-17 §2, S121). Whether the player has VIP is MonetizationService.HasVip (the subscription or
-- the "vip" pass); the rules are Logic/Vip and the numbers Config.Vip. Only looks and comfort: Dragon Shards once per
-- UTC day, the cosmetic of the month for good, the free return to the city (the Stone of Return's channel without a
-- stone) and one free instant respawn per UTC day. The VIP title (TitleService), the alchemist's queue
-- (AlchemyService), the auction limit and fee (AuctionService) and the gold star (attribute "Vip") read HasVip
-- themselves. Nothing here touches EXP, character gold, drops or stats (tests/paywall.spec).
-- Refresh is idempotent and runs on VipChanged, profile ready, entering the world and every minute for VIP players, so
-- a UTC midnight and a new month work without joining again. No other service depends on this one (AdminService only).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)
local Vip = require(Shared.Logic.Vip)

local VipService = {
	Name = "VipService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"MonetizationService",
		"TravelService",
		"DeathService",
		"CosmeticService",
	},
}

local REFRESH_EVERY = 60 -- seconds: midnight UTC and a new month while in game (not a balance number)

local DataService: any
local PlayerStateService: any
local CharacterService: any
local MonetizationService: any
local TravelService: any
local DeathService: any
local CosmeticService: any

local busy: { [Player]: boolean } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

local function stateOf(data: Types.AccountData): Types.VipState
	return Vip.sanitize(data.vip)
end

local function writeState(player: Player, state: Types.VipState)
	PlayerStateService.Set(player, { "account", "vip" }, state)
end

-- Gives the month's cosmetic (when it has one and the account lacks it) and marks the month. Returns the given id.
local function grantMonth(player: Player, data: Types.AccountData, monthKey: string): string?
	if Vip.monthCosmetic(monthKey) == nil then
		return nil
	end
	local id = Vip.monthDue(stateOf(data), monthKey, data.cosmetics.owned)
	writeState(player, Vip.markMonth(stateOf(data), monthKey))
	local given: string? = nil
	if id and CosmeticService.Grant(player, id, "vip.monthGot") then
		given = id
		Analytics.custom(player, "VipMonthCosmetic", 1)
	end
	DataService.Save(player)
	return given
end

-- Daily shards and the cosmetic of the month for a player with VIP (nothing without VIP or a profile).
function VipService.Refresh(player: Player)
	local data = account(player)
	-- the status may arrive before the profile's state (VipChanged on join): PlayerStateService.Ready runs it again
	if not data or not PlayerStateService.HasState(player) or not MonetizationService.HasVip(player) then
		return
	end
	local now = Clock.now()
	-- Daily shards: the day is written first, then the shards, without a yield in between.
	if Vip.dailyDue(stateOf(data), now) then
		writeState(player, Vip.claimDaily(stateOf(data), now))
		local amount = Config.Vip.dailyShards
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
			return shards + amount
		end)
		Analytics.shards(player, amount, total, "vip_daily")
		Net.Fire(player, "Toast", "vip.shards", { n = amount }, "success")
		DataService.Save(player)
	end
	local monthKey = Time.monthKey(now)
	if stateOf(data).months[monthKey] ~= true then
		grantMonth(player, data, monthKey)
	end
end

-- The free return to the city (remote VipRecall).
function VipService.Recall(player: Player): (boolean, string?, { [string]: any }?)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local data = account(player)
	if not char or not data then
		return false, "error.wrongPhase", nil
	end
	if not MonetizationService.HasVip(player) then
		return false, "vip.error.notVip", nil
	end
	local left = Vip.recallLeft(stateOf(data), Clock.now())
	if left > 0 then
		return false, "vip.error.recallCooldown", { time = Time.format(left) }
	end
	if char.location.map == Config.StartingMap then
		return false, "vip.error.inCity", nil
	end
	local ok, err = TravelService.FreeRecall(player, function()
		-- the cooldown starts at a successful return (an interrupted channel costs nothing, like the stone)
		local current = account(player)
		if current then
			writeState(player, Vip.useRecall(stateOf(current), Clock.now()))
		end
		Analytics.custom(player, "VipRecall", 1)
	end)
	return ok, err, nil
end

-- The free instant respawn, once per UTC day (remote VipRespawn).
function VipService.Respawn(player: Player): (boolean, string?)
	local data = account(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if not MonetizationService.HasVip(player) then
		return false, "vip.error.notVip"
	end
	local now = Clock.now()
	if Vip.respawnLeft(stateOf(data), now) <= 0 then
		return false, "vip.error.respawnUsed"
	end
	local ok, err = DeathService.SkipCountdown(player)
	if not ok then
		return false, err
	end
	writeState(player, Vip.useRespawn(stateOf(data), now))
	Analytics.custom(player, "VipRespawn", 1)
	return true, nil
end

-- Admin: today's benefits again (the months stay).
function VipService.Reset(player: Player): boolean
	local data = account(player)
	if not data then
		return false
	end
	writeState(player, Vip.reset(stateOf(data)))
	return true
end

-- Admin: the cosmetic of `monthKey` as if VIP were active then (no HasVip check). Nil when the month has none or the
-- account already owns it.
function VipService.GrantMonth(player: Player, monthKey: string): string?
	local data = account(player)
	if not data then
		return nil
	end
	return grantMonth(player, data, monthKey)
end

export type Status = {
	active: boolean,
	sub: boolean,
	pass: boolean,
	shardsToday: boolean,
	respawns: number,
	recall: number,
	months: { string },
}

-- Admin: what /vip status prints.
function VipService.Status(player: Player): Status?
	local data = account(player)
	if not data then
		return nil
	end
	local now = Clock.now()
	local state = stateOf(data)
	local months = {}
	for key in state.months do
		table.insert(months, key)
	end
	table.sort(months)
	return {
		active = MonetizationService.HasVip(player),
		sub = MonetizationService.HasSubscription(player, "vip"),
		pass = MonetizationService.HasPass(player, "vip"),
		shardsToday = not Vip.dailyDue(state, now),
		respawns = Vip.respawnLeft(state, now),
		recall = Vip.recallLeft(state, now),
		months = months,
	}
end

-- Remotes guard against double clicks (both yield-free today, but the channel and the respawn must not overlap).
local function guarded(fn: (Player) -> ...any): (Player) -> ...any
	return function(player: Player): ...any
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local results = table.pack(pcall(fn, player))
		busy[player] = nil
		if not results[1] then
			error(results[2], 0)
		end
		return table.unpack(results, 2, results.n)
	end
end

function VipService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	MonetizationService = registry.Get("MonetizationService")
	TravelService = registry.Get("TravelService")
	DeathService = registry.Get("DeathService")
	CosmeticService = registry.Get("CosmeticService")
end

function VipService.Start()
	Net.Handle("VipRecall", guarded(VipService.Recall))
	Net.Handle("VipRespawn", guarded(VipService.Respawn))
	MonetizationService.VipChanged:Connect(function(player: Player, active: boolean)
		if active then
			VipService.Refresh(player)
		end
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		VipService.Refresh(player)
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		VipService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		busy[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH_EVERY)
			for _, player in Players:GetPlayers() do
				if MonetizationService.HasVip(player) then
					task.spawn(VipService.Refresh, player)
				end
			end
		end
	end)
end

return VipService
