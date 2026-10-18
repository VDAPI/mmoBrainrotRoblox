--!strict
-- Season pass (S152, docs/DESIGN.md §21b): points for ordinary play on account.season (Logic/Season with the data of
-- Data/Seasons), the premium track bought once per season for Dragon Shards (Data/Products.seasonPass), claiming the
-- rewards of both tracks and the end of a season (the previous season's state in account.seasonPrev for GRACE_DAYS,
-- then its unclaimed rewards by mail once, key season_<id>_<userId>, parcel k > 1 with _<k>).
-- Sources: SeasonService.Add(player, source, n?) called by the services that know the fact (QuestService,
-- SideQuestService, ContractService, DungeonService, WorldEventService, WorldBossService, BloodMoonService,
-- ArenaService, AchievementService) plus CombatService.MonsterKilled for the credited players (kill / elite / elite2;
-- bosses and summoned helpers are counted elsewhere or not at all). Never through LevelService.ExpGained: a level 100
-- character and quests without EXP count too.
-- Hot path: monster points change the in-memory state at once and are written at most once per FLUSH_EVERY seconds
-- (and before the profile is released); every other source, a purchase and a claim write at once. The purchase never
-- adds points (tests/paywall.spec "12."), and nothing here yields between a check and its write.
-- The client reads account.season (replicated with the account); there is no remote of its own for the state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Clock = require(Shared.Util.Clock)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Lure = require(Shared.Logic.Lure)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Season = require(Shared.Logic.Season)
local Seasons = require(Shared.Data.Seasons)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

local log = Log.new("SeasonService")

type SeasonState = Types.SeasonState
type SeasonDef = Seasons.SeasonDef
type Reward = Seasons.Reward

local SeasonService = {
	Name = "SeasonService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"InventoryService",
		"CosmeticService",
		"MailService",
		"CombatService",
	},
}

local FLUSH_EVERY = 1 -- seconds between two writes of monster points (not a balance number)
local ROLL_EVERY = 600 -- seconds: the end of a season and of its grace days while in game (not a balance number)

local DataService: any
local PlayerStateService: any
local InventoryService: any
local CosmeticService: any
local MailService: any
local CombatService: any

-- The in-memory state of a player whose monster points are not written yet.
local pending: { [Player]: SeasonState } = {}
-- The week of the season whose weekly cap toast this player saw on this server.
local capToast: { [Player]: number } = {}
local settling: { [Player]: boolean } = {}
local settle: (player: Player) -> ()
-- Studio only (/seasonpass week): seconds added to the season clock of this server.
local clockOffset = 0

local KILL_VARIANTS: { [string]: string } = { normal = "kill", elite = "elite", elite2 = "elite2" }

local function now(): number
	return Clock.now() + clockOffset
end

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

-- Writes `state` to account.season (the pending monster points with it).
local function write(player: Player, state: SeasonState)
	pending[player] = nil
	PlayerStateService.Set(player, { "account", "season" }, state)
end

local function flush(player: Player)
	local state = pending[player]
	if state and PlayerStateService.HasState(player) then
		write(player, state)
	end
	pending[player] = nil
end

-- The player's state for the season running now (rolled; the old one moved to seasonPrev first), or nil without a
-- profile. Writes only when the season changed.
local function current(player: Player): SeasonState?
	local data = account(player)
	if not data or not PlayerStateService.HasState(player) then
		return nil
	end
	local t = now()
	local state = pending[player] or Season.sanitize(data.season)
	local rolled = Season.roll(state, t)
	if rolled.id ~= state.id then
		if state.id ~= "" and Seasons.get(state.id) then
			local older = if data.seasonPrev ~= nil then Season.sanitize(data.seasonPrev) else nil
			if older and older.id ~= state.id and older.id ~= "" then
				-- an older previous season still to mail (always past its grace days by now): settle it first, roll
				-- on the next call (the ended season gives no points meanwhile)
				task.spawn(settle, player)
				return state
			end
			-- the previous season waits for its grace days in seasonPrev
			PlayerStateService.Set(player, { "account", "seasonPrev" }, state)
		end
		write(player, rolled)
	end
	return rolled
end

local function tierToast(player: Player, def: SeasonDef, before: number, after: number)
	local from, to = Season.tierOf(before, def), Season.tierOf(after, def)
	if to > from then
		Net.Fire(player, "Toast", "season.tierUp", { tier = to }, "success")
	end
end

local function capReached(player: Player, def: SeasonDef, t: number)
	local week = Season.week(def, t)
	if capToast[player] ~= week then
		capToast[player] = week
		Net.Fire(player, "Toast", "season.toast.cap", nil, "info")
	end
end

-- Adds the points of `n` (default 1) events of `source` to the player's season (Logic/Season.add: the daily monster
-- limit, the growing cap, the catch-up). Returns the points gained. Called by the services that know the fact.
function SeasonService.Add(player: Player, source: string, n: number?): number
	local state = current(player)
	if not state then
		return 0
	end
	local t = now()
	local def = Seasons.at(t)
	if not def then
		return 0
	end
	local new, gained, why = Season.add(state, def, source, t, n)
	if why == "unknown" then
		log:warn("unknown season source %s", source)
	end
	if why == "cap" then
		capReached(player, def, t)
	end
	if gained <= 0 and new.day == state.day then
		return 0
	end
	if Seasons.KILL_SOURCES[source] or source == "elite2" then
		pending[player] = new
	else
		write(player, new)
	end
	tierToast(player, def, state.points, new.points)
	return gained
end

local function stackOf(count: Season.ItemCount): Types.ItemInstance
	local stack = ItemRoll.makeStack(count.id, count.n, InventoryService.NewUid())
	stack.bound = true -- a reward never turns into gold through trade or the auction house
	stack.ns = true -- nor through the merchant
	return stack
end

-- The stacks of `counts` in parcels of at most Market.Mail.maxItemsPerParcel (merged by id, Logic/Season.pack).
local function parcelsOf(counts: { Season.ItemCount }): { { Types.ItemInstance } }
	local out: { { Types.ItemInstance } } = {}
	for _, parcel in Season.pack(counts) do
		local stacks: { Types.ItemInstance } = {}
		for _, count in parcel do
			table.insert(stacks, stackOf(count))
		end
		table.insert(out, stacks)
	end
	return out
end

-- Items of the rewards (bound, never sold, merged by id) into the backpack; whatever does not fit goes by mail (a
-- spawned thread, as many parcels as the parcel limit needs).
local function giveItems(player: Player, counts: { Season.ItemCount }, def: SeasonDef)
	if #counts == 0 then
		return
	end
	local leftovers: { Season.ItemCount } = {}
	local locked = InventoryService.IsTradeLocked(player)
	for _, parcel in Season.pack(counts, math.huge) do
		for _, count in parcel do
			local left = if locked then count.n else InventoryService.AddItem(player, stackOf(count))
			if left > 0 then
				table.insert(leftovers, { id = count.id, n = left })
			end
		end
	end
	if #leftovers == 0 then
		return
	end
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local parcels = parcelsOf(leftovers)
	task.spawn(function()
		local mailed = false
		for _, items in parcels do
			local sent, err = MailService.Send(player.UserId, {
				from = "system",
				subjectKey = "mail.subject.season",
				args = { season = `@{def.nameKey}` },
				items = items,
				charId = if char then char.id else nil,
			})
			if sent then
				mailed = true
			else
				log:warn("season items of %s not mailed: %s", player.Name, tostring(err))
			end
		end
		if mailed and player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "season.toast.mailed", { season = `@{def.nameKey}` }, "info")
		end
	end)
end

-- Cloak of Luring time on the account (like the lure_1h shop entry).
local function giveLure(player: Player, seconds: number)
	local data = account(player)
	if not data or seconds <= 0 then
		return
	end
	local t = Clock.now()
	local fresh = Lure.extend(data.lure, seconds, t)
	PlayerStateService.Set(player, { "account", "lure" }, fresh)
	local addedKey, addedArgs = Lure.timeKey(seconds)
	local leftKey, leftArgs = Lure.timeKey(Lure.left(fresh, t))
	Net.Fire(player, "Toast", "lure.added", {
		time = { key = addedKey, args = addedArgs },
		left = { key = leftKey, args = leftArgs },
	}, "success")
end

-- Gives claimed rewards (the claims are written already). Cosmetics: an owned one gives nothing, the reward is
-- claimed all the same.
local function give(player: Player, rewards: { Reward }, def: SeasonDef)
	local counts: { Season.ItemCount } = {}
	for _, reward in rewards do
		if reward.kind == "cosmetic" and reward.id then
			CosmeticService.Grant(player, reward.id, "season.toast.cosmetic")
		elseif reward.kind == "item" and reward.id then
			local n = reward.n or 1
			table.insert(counts, { id = reward.id, n = n })
			Net.Fire(player, "Toast", "season.toast.item", { item = `@item.{reward.id}.name`, n = n }, "success")
		elseif reward.kind == "lure" then
			giveLure(player, reward.seconds or 0)
		end
	end
	giveItems(player, counts, def)
end

-- The season and state a claim targets: the running season (`id` nil or its id) or the previous one in its grace days.
local function target(player: Player, id: string?): (SeasonDef?, SeasonState?, boolean)
	local state = current(player)
	local data = account(player)
	if not state or not data then
		return nil, nil, false
	end
	if id == nil or id == state.id then
		return Seasons.get(state.id), state, false
	end
	local prev = if data.seasonPrev then Season.sanitize(data.seasonPrev) else nil
	if prev and prev.id == id then
		return Seasons.get(prev.id), prev, true
	end
	return nil, nil, false
end

local function store(player: Player, state: SeasonState, isPrev: boolean)
	if isPrev then
		PlayerStateService.Set(player, { "account", "seasonPrev" }, state)
	else
		write(player, state)
	end
end

-- SeasonClaim (tier, "free" | "premium", seasonId?): one reward; checked, marked claimed, then given.
local function claim(player: Player, tier: number, track: string, id: string?): (boolean, string?, any)
	if not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	local def, state, isPrev = target(player, id)
	if not def or not state then
		return false, "season.error.noSeason"
	end
	local ok, err = Season.canClaim(state, def, tier, track, now())
	if not ok then
		return false, err
	end
	local reward = Season.rewardOf(def, tier, track) :: Reward
	store(player, Season.claim(state, tier, track), isPrev)
	give(player, { reward }, def)
	DataService.Save(player)
	return true, nil, { granted = { reward } }
end

-- SeasonClaimAll: every reached, unclaimed reward of the running season and of the previous one in its grace days.
local function claimAll(player: Player): (boolean, string?, any)
	if not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	local data = account(player)
	local state = current(player)
	if not data or not state then
		return false, "season.error.noSeason"
	end
	local t = now()
	local granted: { Reward } = {}
	local ids: { string } = { state.id }
	if data.seasonPrev then
		table.insert(ids, Season.sanitize(data.seasonPrev).id)
	end
	for _, id in ids do
		local def, st, isPrev = target(player, id)
		if def and st then
			local changed = st
			local mine: { Reward } = {}
			for _, c in Season.claimable(st, def) do
				if Season.canClaim(changed, def, c.tier, c.track, t) then
					changed = Season.claim(changed, c.tier, c.track)
					local reward = Season.rewardOf(def, c.tier, c.track) :: Reward
					table.insert(mine, reward)
					table.insert(granted, reward)
				end
			end
			if #mine > 0 then
				store(player, changed, isPrev)
				give(player, mine, def)
			end
		end
	end
	if #granted == 0 then
		return false, "season.error.noReward"
	end
	DataService.Save(player)
	return true, nil, { granted = granted }
end

-- SeasonBuy: the premium track of the running season for Dragon Shards, once. Checked, paid and marked in one step
-- without a yield; it adds no points (tests/paywall.spec "12.").
local function buy(player: Player): (boolean, string?)
	local data = account(player)
	local state = current(player)
	if not data or not state then
		return false, "error.wrongPhase"
	end
	local t = now()
	local def = Seasons.at(t)
	local ok, err = Season.canBuy(state, def, t)
	if not ok or not def then
		return false, err
	end
	local price = Products.seasonPass.price
	if data.dragonShards < price then
		return false, "premium.error.shards"
	end
	local balance = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return shards - price
	end)
	write(player, Season.buy(state))
	Analytics.shards(player, -price, balance, Products.seasonPass.key, true)
	Analytics.custom(player, "SeasonPass", Season.tierOf(state.points, def))
	DataService.Save(player)
	Net.Fire(player, "Toast", "season.toast.bought", { season = `@{def.nameKey}` }, "success")
	return true, nil
end

-- The previous season after its grace days: its unclaimed rewards by mail once (cosmetics and items; Cloak of Luring
-- time straight onto the account), then seasonPrev is cleared and the season marked mailed. Yields (mail).
function settle(player: Player)
	if settling[player] or not PlayerStateService.HasState(player) then
		return
	end
	local data = account(player)
	if not data or not data.seasonPrev then
		return
	end
	local prev = Season.sanitize(data.seasonPrev)
	local def = Seasons.get(prev.id)
	if def and now() <= Season.claimUntil(def) then
		return -- still in the grace days: the window claims them
	end
	local function mark()
		local fresh = account(player)
		if fresh then
			local marked = Season.sanitize(pending[player] or fresh.season)
			marked.mailed[prev.id] = true
			write(player, marked)
		end
		PlayerStateService.Set(player, { "account", "seasonPrev" }, nil)
		DataService.Save(player)
	end
	local mailed = Season.sanitize(pending[player] or data.season).mailed
	local rewards: { Reward } = {}
	if def and not mailed[prev.id] then
		rewards = Season.unclaimed(prev, def)
	end
	if #rewards == 0 then
		mark()
		return
	end
	settling[player] = true
	local cosmetics: { string } = {}
	local counts: { Season.ItemCount } = {}
	local lureSeconds = 0
	for _, reward in rewards do
		if reward.kind == "cosmetic" and reward.id then
			table.insert(cosmetics, reward.id)
		elseif reward.kind == "item" and reward.id then
			table.insert(counts, { id = reward.id, n = reward.n or 1 })
		elseif reward.kind == "lure" then
			lureSeconds += reward.seconds or 0
		end
	end
	local defName = `@{(def :: SeasonDef).nameKey}`
	-- parcel 1 carries the cosmetics; each parcel has its own once key, so a retry after a failed one sends only the
	-- missing ones (the same rewards always pack the same way)
	local parcels = parcelsOf(counts)
	if #parcels == 0 then
		parcels = { {} }
	end
	for k, items in parcels do
		local sent, err = MailService.Send(player.UserId, {
			from = "system",
			subjectKey = "mail.subject.season",
			args = { season = defName },
			items = items,
			cosmetics = if k == 1 then cosmetics else nil,
			once = if k == 1 then `season_{prev.id}_{player.UserId}` else `season_{prev.id}_{player.UserId}_{k}`,
		})
		if not sent then
			settling[player] = nil
			log:warn("season %s rewards of %s not mailed: %s", prev.id, player.Name, tostring(err))
			return
		end
	end
	settling[player] = nil
	if player.Parent == nil or not PlayerStateService.HasState(player) then
		return
	end
	-- the parcel exists (once): the account is marked even if the lure below were lost to a closing server
	mark()
	giveLure(player, lureSeconds)
	MailService.Refresh(player)
	Net.Fire(player, "Toast", "season.toast.mailed", { season = defName }, "info")
end

local function refresh(player: Player)
	if not PlayerStateService.HasState(player) then
		return
	end
	current(player)
	task.spawn(settle, player)
end

-- Admin (S23, /seasonpass) ---------------------------------------------------------------------------------------------

export type Info = {
	season: string,
	week: number,
	points: number,
	tier: number,
	premium: boolean,
	cap: number,
	kill: number,
	line: number,
	claimable: number,
}

-- The running season's numbers of the player (nil without a season or a profile).
function SeasonService.Info(player: Player): Info?
	local state = current(player)
	local t = now()
	local def = Seasons.at(t)
	if not state or not def then
		return nil
	end
	return {
		season = def.id,
		week = Season.week(def, t),
		points = state.points,
		tier = Season.tierOf(state.points, def),
		premium = state.premium,
		cap = Season.capAt(def, t),
		kill = if state.day == Time.dayNumber(t) then state.dayKill else 0,
		line = Season.lineAt(def, t),
		claimable = #Season.claimable(state, def),
	}
end

-- The next season's id ("-" without one).
function SeasonService.NextId(): string
	local def = Seasons.next(now())
	return if def then def.id else "-"
end

-- Sets the points of the running season without limits (admin). False without a season.
function SeasonService.SetPoints(player: Player, points: number): boolean
	local state = current(player)
	local def = Seasons.at(now())
	if not state or not def then
		return false
	end
	local out = Season.sanitize(state)
	out.points = math.clamp(math.floor(points), 0, def.tiers * Seasons.TIER_POINTS)
	tierToast(player, def, state.points, out.points)
	write(player, out)
	return true
end

-- Sets or clears the premium track (admin, no shards). False without a season.
function SeasonService.SetPremium(player: Player, on: boolean): boolean
	local state = current(player)
	if not state or not Seasons.at(now()) then
		return false
	end
	local out = Season.sanitize(state)
	out.premium = on
	write(player, out)
	return true
end

-- A clean state of the running season (the mailed seasons stay). False without a profile.
function SeasonService.Reset(player: Player): boolean
	local state = current(player)
	if not state then
		return false
	end
	write(player, Season.fresh(state.id, state))
	return true
end

-- Studio only: moves this server's season clock into week `week` of the running or next season (0 = the real clock).
-- Returns the season id, nil when there is none or outside Studio.
function SeasonService.SetWeek(week: number): string?
	if not RunService:IsStudio() then
		return nil
	end
	if week <= 0 then
		clockOffset = 0
		return "-"
	end
	local real = Clock.now()
	local def = Seasons.at(real) or Seasons.next(real)
	if not def then
		return nil
	end
	local w = math.clamp(math.floor(week), 1, def.weeks)
	clockOffset = def.start + (w - 1) * Seasons.WEEK + 3600 - real
	for _, player in Players:GetPlayers() do
		refresh(player)
	end
	return def.id
end

function SeasonService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	CosmeticService = registry.Get("CosmeticService")
	MailService = registry.Get("MailService")
	CombatService = registry.Get("CombatService")
end

function SeasonService.Start()
	Net.Handle("SeasonBuy", buy)
	Net.Handle("SeasonClaim", claim)
	Net.Handle("SeasonClaimAll", claimAll)
	CombatService.MonsterKilled:Connect(function(info: any, credit: { Player })
		-- dungeon bosses are DungeonService's ("boss"), summoned helpers and the world boss's helpers give nothing
		if info.boss or info.noLoot then
			return
		end
		local source = KILL_VARIANTS[info.variant]
		if not source then
			return
		end
		for _, player in credit do
			SeasonService.Add(player, source)
		end
	end)
	PlayerStateService.Ready:Connect(refresh)
	DataService.ProfileReleasing:Connect(flush)
	Players.PlayerRemoving:Connect(function(player: Player)
		capToast[player] = nil
		settling[player] = nil
		task.defer(function()
			pending[player] = nil
		end)
	end)
	task.spawn(function()
		local sinceRoll = 0
		while true do
			task.wait(FLUSH_EVERY)
			for player in pending do
				flush(player)
			end
			sinceRoll += FLUSH_EVERY
			if sinceRoll >= ROLL_EVERY then
				sinceRoll = 0
				for _, player in Players:GetPlayers() do
					refresh(player)
				end
			end
		end
	end)
end

return SeasonService
