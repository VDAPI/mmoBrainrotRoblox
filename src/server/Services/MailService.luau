--!strict
-- Mail (DESIGN §18): parcels with gold and items for an account, optionally for one character, kept in the
-- Mail DataStore ("Mail_<userId>") for 30 days, so they reach players who are offline or on another
-- server. Senders: the auction (payments, returned items), the system (refunds) and admins (/mail).
--
-- Claiming is atomic: the parcel is removed from the mailbox in UpdateAsync first, then put into the
-- character; whatever no longer fits is mailed back as a new parcel, so nothing is lost or duplicated.
-- Claiming happens at the mailbox (the Auctioneer); the list (state branch `mail`) is visible anywhere.
-- S125: system and admin parcels may carry Dragon Shards (account) and a timed title (character, TitleService.GrantTimed);
-- the weekly ranking sends them (LeaderboardService), S128-S130 too. TitleService is taken lazily (S60 pattern).
-- S129: they may also carry Arena Tokens (character, ArenaService.AddTokens outside the weekly cap) and cosmetics earned
-- in the game (account, CosmeticService.Grant); ArenaService depends on mail and CosmeticService is taken lazily too.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local Inventory = require(Shared.Logic.Inventory)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)
local Log = require(Shared.Util.Log)
local Mail = require(Shared.Logic.Mail)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Market.Notify)
local Types = require(Shared.Types)

local log = Log.new("MailService")

type ItemInstance = Types.ItemInstance

local MailService = {
	Name = "MailService",
	Deps = { "DataService", "PlayerStateService", "CharacterService", "InventoryService", "NpcService" },
}

export type Outgoing = {
	from: string,
	fromName: string?,
	subjectKey: string,
	args: { [string]: any }?,
	gold: number?,
	items: { ItemInstance }?,
	charId: string?,
	shards: number?, -- S125: Dragon Shards for the account (system / admin only, Logic/Mail.add)
	timedTitle: { id: string, untilTs: number }?, -- S125: a timed title for `charId`
	once: string?, -- S128: an idempotency key: sent once per mailbox, a repeated Send succeeds without a second parcel
	tokens: number?, -- S129: Arena Tokens for `charId` (system / admin only), outside the weekly cap
	cosmetics: { string }?, -- S129: cosmetics never sold (obtain), for the account (system / admin only)
}

local Registry: any
local TitleService: any
local ArenaService: any
local CosmeticService: any
local DataService: any
local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local NpcService: any

local store: KeyStore.KeyStore
local boxes: { [Player]: Mail.Box } = {}
local busy: { [Player]: boolean } = {}

-- S125: lazily (TitleService does not depend on mail; nothing here needs it at Init time).
local function titleService(): any
	if TitleService == nil and Registry then
		local ok, service = pcall(Registry.Get, "TitleService")
		TitleService = if ok then service else false
	end
	return TitleService or nil
end

-- S129: lazily as well (ArenaService lists MailService in its Deps; CosmeticService knows nothing about mail).
local function lazy(name: string, cached: any): any
	if cached == nil and Registry then
		local ok, service = pcall(Registry.Get, name)
		return if ok and service then service else false
	end
	return cached
end

local function arenaService(): any
	ArenaService = lazy("ArenaService", ArenaService)
	return ArenaService or nil
end

local function cosmeticService(): any
	CosmeticService = lazy("CosmeticService", CosmeticService)
	return CosmeticService or nil
end

local function key(userId: number): string
	return `Mail_{userId}`
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function publish(player: Player)
	if not PlayerStateService.HasState(player) then
		return
	end
	local char = character(player)
	local box = boxes[player]
	if not char or not box then
		PlayerStateService.Set(player, { "mail" }, nil)
		return
	end
	local list = Mail.visible(box, char.id, os.time())
	PlayerStateService.Set(player, { "mail" }, { list = list, count = #list })
end

-- Re-reads the player's mailbox. Yields.
function MailService.Refresh(player: Player)
	local ok, value = store:get(key(player.UserId))
	if ok and player.Parent == Players then
		boxes[player] = Mail.box(value)
		publish(player)
	end
end

-- Sends a parcel to an account (online or not, any server). Yields. Returns (ok, errorKey?).
function MailService.Send(userId: number, outgoing: Outgoing): (boolean, string?)
	local now = os.time()
	local parcel: Mail.Parcel = {
		id = string.gsub(HttpService:GenerateGUID(false), "-", ""),
		from = outgoing.from,
		fromName = outgoing.fromName,
		subjectKey = outgoing.subjectKey,
		args = outgoing.args,
		gold = math.max(0, math.floor(outgoing.gold or 0)),
		items = outgoing.items or {},
		createdAt = now,
		expiresAt = now + Mail.LIFETIME,
		charId = outgoing.charId,
		shards = if outgoing.shards and outgoing.shards > 0 then math.max(0, math.floor(outgoing.shards)) else nil,
		timedTitle = outgoing.timedTitle,
		once = outgoing.once,
		tokens = if outgoing.tokens and outgoing.tokens > 0 then math.floor(outgoing.tokens) else nil,
		cosmetics = if outgoing.cosmetics and #outgoing.cosmetics > 0 then outgoing.cosmetics else nil,
	}
	local ok, _, err = store:update(key(userId), function(current: any?)
		local box = Mail.box(current)
		local added, reason = Mail.add(box, parcel, now)
		if not added then
			return nil, reason
		end
		return box, nil
	end)
	if not ok then
		log:warn(
			"parcel to %d rejected (%s): %d gold, %d items, %d shards, subject %s",
			userId,
			tostring(err),
			parcel.gold,
			#parcel.items,
			parcel.shards or 0,
			parcel.subjectKey
		)
		return false, err
	end
	Notify.send(userId, "mail", nil)
	return true, nil
end

-- S131: readable economy reasons of the reward parcels that carry Dragon Shards (Analytics.shards); others stay
-- "mail_<from>".
local SHARD_REASONS: { [string]: string } = {
	["mail.subject.weeklyRank"] = "exp_week",
	["mail.subject.arenaSeason"] = "arena_season",
	["mail.subject.bloodMoon"] = "event_bloodmoon",
	["mail.subject.tourney"] = "event_tourney",
}

-- Puts a parcel's contents into the character; returns items that did not fit.
local function deliver(player: Player, parcel: Mail.Parcel): { ItemInstance }
	if parcel.gold > 0 then
		PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold + parcel.gold
		end)
	end
	-- S125: shards for the account (MonetizationService.addShards pattern) and a timed title (an expired term gives
	-- nothing; the parcel is still taken)
	local shards = parcel.shards
	if shards and shards > 0 then
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(n: number)
			return (n or 0) + shards
		end)
		Analytics.shards(player, shards, total, SHARD_REASONS[parcel.subjectKey] or `mail_{parcel.from}`)
	end
	local timed = parcel.timedTitle
	if timed then
		local titles = titleService()
		if titles then
			titles.GrantTimed(player, timed.id, timed.untilTs)
		end
	end
	-- S129: Arena Tokens (never counted to the weekly cap of matches) and cosmetics (an owned one gives nothing)
	local tokens = parcel.tokens
	if tokens and tokens > 0 then
		local arena = arenaService()
		if arena then
			arena.AddTokens(player, tokens, nil, { uncapped = true })
		end
	end
	if parcel.cosmetics then
		local cosmetics = cosmeticService()
		if cosmetics then
			for _, id in parcel.cosmetics do
				cosmetics.Grant(player, id)
			end
		end
	end
	local leftovers = {}
	for _, item in parcel.items do
		local rest = InventoryService.AddItem(player, item)
		if rest > 0 then
			local copy = table.clone(item)
			copy.n = rest
			table.insert(leftovers, copy)
		end
	end
	return leftovers
end

local function claim(player: Player, id: string): (boolean, string?)
	local char = character(player)
	local box = boxes[player]
	if not char or not box then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "mail") then
		return false, "mail.error.tooFar"
	end
	local cached = box.parcels[id]
	if not cached then
		return false, "mail.error.gone"
	end
	if
		#cached.items > 0
		and not Inventory.canFit(char.inventory, InventoryService.CapacityOf(char, player), cached.items)
	then
		return false, "inventory.full"
	end
	local taken: Mail.Parcel? = nil
	local ok, newBox, err = store:update(key(player.UserId), function(current: any?)
		local b = Mail.box(current)
		taken = Mail.take(b, id, char.id, os.time())
		if not taken then
			return nil, "mail.error.gone"
		end
		return b, nil
	end)
	if not ok or not taken then
		MailService.Refresh(player)
		return false, err
	end
	boxes[player] = Mail.box(newBox)
	local parcel = taken :: Mail.Parcel
	-- The character may have switched while the store yielded: deliver to whoever is active, else re-mail (S125: the
	-- shards and the title go back in the same parcel).
	local same = character(player) == char
	local leftovers = if same then deliver(player, parcel) else parcel.items
	local missedGold = if same then 0 else parcel.gold
	local missedShards = if same then nil else parcel.shards
	local missedTitle = if same then nil else parcel.timedTitle
	local missedTokens = if same then nil else parcel.tokens
	local missedCosmetics = if same then nil else parcel.cosmetics
	if
		#leftovers > 0
		or missedGold > 0
		or (missedShards or 0) > 0
		or missedTitle ~= nil
		or (missedTokens or 0) > 0
		or missedCosmetics ~= nil
	then
		MailService.Send(player.UserId, {
			from = "system",
			subjectKey = "mail.subject.returned",
			gold = missedGold,
			items = leftovers,
			charId = char.id,
			shards = missedShards,
			timedTitle = missedTitle,
			tokens = missedTokens,
			cosmetics = missedCosmetics,
		})
	end
	DataService.Save(player)
	publish(player)
	log:info(
		"%s claimed parcel %s (%d gold, %d items, %d shards)",
		player.Name,
		id,
		parcel.gold,
		#parcel.items,
		parcel.shards or 0
	)
	return true, nil
end

local function withLock(player: Player, fn: () -> (boolean, string?)): (boolean, string?)
	if busy[player] then
		return false, "error.busy"
	end
	busy[player] = true
	local ok, result, err = pcall(fn)
	busy[player] = nil
	if not ok then
		log:error("mail request failed for %s: %s", player.Name, tostring(result))
		return false, "error.internal"
	end
	return result, err
end

local function claimAll(player: Player): (boolean, string?, number?)
	local char = character(player)
	local box = boxes[player]
	if not char or not box then
		return false, "error.wrongPhase"
	end
	local claimed = 0
	local lastErr: string? = nil
	for _, parcel in Mail.visible(box, char.id, os.time()) do
		local ok, err = claim(player, parcel.id)
		if ok then
			claimed += 1
		else
			lastErr = err
			if err ~= "mail.error.gone" then
				break
			end
		end
	end
	if claimed == 0 then
		return false, lastErr or "mail.error.empty"
	end
	return true, nil, claimed
end

function MailService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	store = KeyStore.new(Config.MailStoreName, DataService.HasDataStoreAccess)
end

function MailService.Start()
	task.spawn(Notify.start)
	Notify.on("mail", function(player: Player)
		if character(player) then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "mail.arrived", nil, "info")
		end
	end)

	Net.Handle("MailClaim", function(player: Player, id: string)
		return withLock(player, function()
			return claim(player, id)
		end)
	end)
	Net.Handle("MailClaimAll", function(player: Player)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, err, count = pcall(claimAll, player)
		busy[player] = nil
		if not ok then
			log:error("claim all failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err, count
	end)
	Net.Handle("MailRefresh", function(player: Player)
		MailService.Refresh(player)
		return true, nil
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		task.spawn(MailService.Refresh, player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "mail" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		boxes[player] = nil
		busy[player] = nil
	end)
end

return MailService
