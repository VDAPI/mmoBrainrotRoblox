--!strict
-- Auction house across servers (DESIGN §18). Listings live in the Auction DataStore ("Listing_<id>") with
-- the full item; the search index is a MemoryStore SortedMap per category (Market/Index). Rules and the
-- listing state machine are in Logic/Auction.
--   List   : the item and the 1 % deposit leave the character first (no yield), then the listing is written;
--            on failure both come back. The id is kept in `character.auctions` ("My listings").
--   Buy    : the buyer's gold is taken first, then UpdateAsync flips active -> sold only if the listing is still
--            active, unexpired and at the expected price (two buyers can never both win); on failure the
--            gold comes back. Item -> backpack (or mail when full), payment minus 5 % + deposit -> seller's mail.
--   Cancel : active -> cancelled, the item goes to the seller's mail (the deposit is kept).
--   Expire : every server sweeps the index every 5 min; active -> expired happens once (UpdateAsync), and
--            only the server that made the transition mails the item back.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Auction = require(Shared.Logic.Auction)
local Config = require(Shared.Config)
local Index = require(script.Parent.Parent.Market.Index)
local ItemName = require(Shared.Logic.ItemName)
local Items = require(Shared.Data.Items)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)
local Log = require(Shared.Util.Log)
local Market = require(Shared.Data.Market)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Market.Notify)
local Types = require(Shared.Types)

local log = Log.new("AuctionService")

type ItemInstance = Types.ItemInstance
type Listing = Auction.Listing

local AuctionService = {
	Name = "AuctionService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"InventoryService",
		"NpcService",
		"MailService",
	},
}

local Rules = Market.Auction

local DataService: any
local PlayerStateService: any
local InventoryService: any
local NpcService: any
local MailService: any

local store: KeyStore.KeyStore
local busy: { [Player]: boolean } = {}
-- (category .. direction) -> { at, entries }
local searchCache: { [string]: { at: number, entries: { Auction.Summary } } } = {}

local function key(id: string): string
	return `Listing_{id}`
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function withLock(player: Player, fn: () -> (boolean, string?)): (boolean, string?)
	if busy[player] then
		return false, "error.busy"
	end
	busy[player] = true
	local ok, result, err = pcall(fn)
	busy[player] = nil
	if not ok then
		log:error("auction request failed for %s: %s", player.Name, tostring(result))
		return false, "error.internal"
	end
	return result, err
end

local function addGold(player: Player, delta: number)
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return math.max(0, gold + delta)
	end)
end

local function setOwnListing(player: Player, id: string, present: boolean)
	local char = character(player)
	if char then
		PlayerStateService.Set(player, { "character", "auctions", id }, if present then true else nil)
	end
end

local function activeCount(char: Types.CharacterData): number
	local n = 0
	for _ in (char.auctions or {}) :: { [string]: boolean } do
		n += 1
	end
	return n
end

local function dropFromIndex(listing: Listing)
	Index.remove(listing.category, Auction.indexKey(listing.price, listing.id))
	searchCache[listing.category .. "a"] = nil
	searchCache[listing.category .. "d"] = nil
end

local function itemArg(item: ItemInstance): string
	return `#item:{item.id}:{item.up or 0}`
end

-- List ---------------------------------------------------------------------------------------------

local function list(player: Player, index: number, price: number, hours: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "auction") then
		return false, "npc.error.tooFar"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local item = InventoryService.Get(player, index)
	local def = item and Items.get(item.id)
	local ok, err = Auction.validateListing(item, def, price, hours, activeCount(char), char.gold)
	if not ok then
		return false, err
	end
	local listed = item :: ItemInstance
	local deposit = Auction.deposit(price)
	local now = os.time()
	local listing: Listing = {
		id = string.gsub(HttpService:GenerateGUID(false), "-", ""),
		sellerUserId = player.UserId,
		sellerCharId = char.id,
		sellerName = char.name,
		item = listed,
		price = price,
		deposit = deposit,
		category = Auction.categoryOf(def :: any),
		createdAt = now,
		expiresAt = now + hours * 3600,
		status = "active",
	}
	-- Item and deposit leave before the yield; they come back if the write fails.
	InventoryService.SetSlot(player, index, nil)
	addGold(player, -deposit)
	local written, _, writeErr = store:update(key(listing.id), function(current: any?)
		if current ~= nil then
			return nil, "market.error.store"
		end
		return listing, nil
	end)
	if not written then
		addGold(player, deposit)
		if InventoryService.Get(player, index) == nil and character(player) == char then
			InventoryService.SetSlot(player, index, listed)
		elseif InventoryService.AddItem(player, listed) > 0 then
			MailService.Send(player.UserId, {
				from = "system",
				subjectKey = "mail.subject.returned",
				items = { listed },
				charId = char.id,
			})
		end
		return false, writeErr or "market.error.store"
	end
	setOwnListing(player, listing.id, true)
	DataService.Save(player)
	local summary = Auction.summary(listing, def :: any, ItemName.searchText(listed.id))
	if not Index.set(listing.category, Auction.indexKey(price, listing.id), summary, hours * 3600 + 3600) then
		log:warn("listing %s written but not indexed", listing.id)
	end
	searchCache[listing.category .. "a"] = nil
	searchCache[listing.category .. "d"] = nil
	log:info("%s listed %s x%d for %d (%s)", player.Name, listed.id, listed.n, price, listing.id)
	return true, nil
end

-- Search -------------------------------------------------------------------------------------------

local function entriesFor(category: string, descending: boolean): { Auction.Summary }
	local cacheKey = category .. (if descending then "d" else "a")
	local cached = searchCache[cacheKey]
	if cached and os.clock() - cached.at < Rules.searchCacheSeconds then
		return cached.entries
	end
	local ok, range = Index.range(category, descending, Rules.scanLimit)
	local entries = {}
	if ok then
		for _, entry in range do
			if type(entry.value) == "table" then
				table.insert(entries, entry.value)
			end
		end
	end
	searchCache[cacheKey] = { at = os.clock(), entries = entries }
	return entries
end

local function readFilter(raw: { [any]: any }): (Auction.Filter?, string?)
	local category = raw.category
	if category ~= nil and (type(category) ~= "string" or not Market.getCategory(category)) then
		return nil, nil
	end
	local function num(v: any): number?
		return if type(v) == "number" and v == v and v >= 0 and v <= 1000 then math.floor(v) else nil
	end
	local text = if type(raw.text) == "string" then string.sub(raw.text, 1, 40) else nil
	return {
		class = if type(raw.class) == "string" and #raw.class <= 16 then raw.class else nil,
		minLevel = num(raw.minLevel),
		maxLevel = num(raw.maxLevel),
		rarity = num(raw.rarity),
		text = if text and text ~= "" then ItemName.fold(text) else nil,
	},
		category
end

local function search(player: Player, raw: { [any]: any }, page: number, descending: boolean): (boolean, any)
	local filter, category = readFilter(raw)
	if not filter then
		return false, "error.badRequest"
	end
	local now = os.time()
	local found: { Auction.Summary } = {}
	local categories: { string } = {}
	if category then
		table.insert(categories, category)
	else
		for _, c in Market.categories do
			table.insert(categories, c.id)
		end
	end
	for _, c in categories do
		for _, summary in entriesFor(c, descending) do
			if Auction.matches(summary, filter, now) then
				table.insert(found, summary)
			end
		end
	end
	Auction.sort(found, descending)
	local pages = math.max(1, math.ceil(#found / Rules.pageSize))
	local current = math.clamp(page, 1, pages)
	local results = {}
	for i = (current - 1) * Rules.pageSize + 1, math.min(#found, current * Rules.pageSize) do
		local s = found[i]
		table.insert(results, {
			id = s.id,
			item = { uid = s.id, id = s.i, rarity = s.r, ilvl = s.il, up = s.u, n = s.n, bonuses = {}, bound = false },
			price = s.p,
			level = s.l,
			expiresAt = s.e,
			seller = s.sn,
			own = s.su == player.UserId,
		})
	end
	return true, { results = results, page = current, pages = pages, total = #found }
end

-- Full listing for the tooltip (bonuses are not in the index).
local detailCache: { [string]: { at: number, item: any } } = {}

local function details(player: Player, id: string): (boolean, any)
	if not NpcService.NearService(player, "auction") then
		return false, "npc.error.tooFar"
	end
	local cached = detailCache[id]
	if cached and os.clock() - cached.at < 30 then
		return true, cached.item
	end
	local ok, listing = store:get(key(id))
	if not ok then
		return false, "market.error.store"
	end
	if not listing or listing.status ~= "active" then
		return false, "auction.error.gone"
	end
	detailCache[id] = { at = os.clock(), item = listing.item }
	return true, listing.item
end

-- Buy ----------------------------------------------------------------------------------------------

local function buy(player: Player, id: string, expectedPrice: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "auction") then
		return false, "npc.error.tooFar"
	end
	if char.gold < expectedPrice or expectedPrice < 1 then
		return false, "shop.error.gold"
	end
	-- Gold is reserved first and refunded on any failure.
	addGold(player, -expectedPrice)
	local ok, written, err = store:update(key(id), function(current: any?)
		if current and current.price ~= expectedPrice then
			return nil, "auction.error.priceChanged"
		end
		local bought, reason = Auction.buy(current, player.UserId, char.name, os.time())
		if not bought then
			return nil, reason
		end
		return current, nil
	end)
	if not ok or not written then
		addGold(player, expectedPrice)
		return false, err
	end
	local listing = written :: Listing
	local item = listing.item
	-- Item to the buyer (backpack, or mail when it does not fit / the character switched meanwhile).
	local fits = character(player) == char and InventoryService.CanFit(player, { item })
	if fits then
		InventoryService.AddItem(player, item)
	else
		MailService.Send(player.UserId, {
			from = "auction",
			subjectKey = "mail.subject.bought",
			args = { item = itemArg(item) },
			items = { item },
			charId = char.id,
		})
	end
	DataService.Save(player)
	-- Payment to the seller.
	local payout = Auction.payout(listing.price, listing.deposit)
	MailService.Send(listing.sellerUserId, {
		from = "auction",
		subjectKey = "mail.subject.sold",
		args = { item = itemArg(item), price = listing.price, fee = Auction.fee(listing.price), buyer = char.name },
		gold = payout,
		charId = listing.sellerCharId,
	})
	Notify.send(listing.sellerUserId, "sold", { id = listing.id, item = itemArg(item), price = listing.price })
	dropFromIndex(listing)
	task.spawn(Index.pushHistory, item.id, math.floor(listing.price / math.max(1, item.n)))
	log:info("%s bought %s for %d from %s", player.Name, listing.id, listing.price, listing.sellerName)
	return true, if fits then nil else "auction.boughtToMail"
end

-- Cancel / expire ----------------------------------------------------------------------------------

local function cancel(player: Player, id: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not char.auctions[id] then
		return false, "auction.error.notYours"
	end
	local ok, written, err = store:update(key(id), function(current: any?)
		local cancelled, reason = Auction.cancel(current, player.UserId, char.id, os.time())
		if not cancelled then
			return nil, reason
		end
		return current, nil
	end)
	if not ok or not written then
		if err == "auction.error.sold" or err == "auction.error.gone" then
			setOwnListing(player, id, false)
		end
		return false, err
	end
	local listing = written :: Listing
	setOwnListing(player, id, false)
	dropFromIndex(listing)
	MailService.Send(player.UserId, {
		from = "auction",
		subjectKey = "mail.subject.cancelled",
		args = { item = itemArg(listing.item) },
		items = { listing.item },
		charId = listing.sellerCharId,
	})
	return true, nil
end

-- Expires one listing if due. Only the server whose UpdateAsync made the transition mails the item.
local function expireListing(id: string): boolean
	local ok, written = store:update(key(id), function(current: any?)
		local expired, reason = Auction.expire(current, os.time())
		if not expired then
			return nil, reason
		end
		return current, nil
	end)
	if not ok or not written then
		return false
	end
	local listing = written :: Listing
	dropFromIndex(listing)
	MailService.Send(listing.sellerUserId, {
		from = "auction",
		subjectKey = "mail.subject.expired",
		args = { item = itemArg(listing.item) },
		items = { listing.item },
		charId = listing.sellerCharId,
	})
	Notify.send(listing.sellerUserId, "expired", { id = listing.id })
	return true
end

local function sweep(): number
	local now = os.time()
	local expired = 0
	for _, category in Market.categories do
		local ok, range = Index.range(category.id, false, Rules.scanLimit)
		if ok then
			for _, entry in range do
				local summary = entry.value
				if type(summary) == "table" and type(summary.e) == "number" and summary.e <= now then
					if expireListing(summary.id) then
						expired += 1
					else
						-- Already sold/cancelled/expired elsewhere: just drop the stale index entry.
						Index.remove(category.id, entry.key)
					end
				end
			end
		end
	end
	return expired
end

-- My listings ------------------------------------------------------------------------------------------

local function mine(player: Player): (boolean, any)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local result = {}
	for id in table.clone(char.auctions) do
		local ok, listing = store:get(key(id))
		if ok and listing then
			if listing.status == "active" and listing.expiresAt <= os.time() then
				expireListing(id)
				listing.status = "expired"
			end
			table.insert(result, {
				id = id,
				item = listing.item,
				price = listing.price,
				expiresAt = listing.expiresAt,
				status = listing.status,
				buyer = listing.buyerName,
			})
			if listing.status ~= "active" then
				setOwnListing(player, id, false) -- closed listings are settled by mail
			end
		elseif ok then
			setOwnListing(player, id, false)
		end
	end
	table.sort(result, function(a, b)
		return a.expiresAt > b.expiresAt
	end)
	return true, result
end

local function priceInfo(_player: Player, itemId: string): (boolean, any)
	if not Items.get(itemId) then
		return false, "error.badRequest"
	end
	return true, Auction.average(Index.history(itemId))
end

-- Admin --------------------------------------------------------------------------------------------

function AuctionService.AdminStats(): { [string]: number }
	local stats = {}
	for _, category in Market.categories do
		local ok, range = Index.range(category.id, false, Rules.scanLimit)
		stats[category.id] = if ok then #range else -1
	end
	return stats
end

-- Studio: makes every indexed listing expire now, then sweeps. Returns the number expired.
function AuctionService.AdminExpireAll(): number
	for _, category in Market.categories do
		local ok, range = Index.range(category.id, false, Rules.scanLimit)
		if ok then
			for _, entry in range do
				local summary = entry.value
				if type(summary) == "table" then
					store:update(key(summary.id), function(current: any?)
						if not current or current.status ~= "active" then
							return nil, "auction.error.gone"
						end
						current.expiresAt = os.time() - 1
						return current, nil
					end)
					summary.e = os.time() - 1
					Index.set(category.id, entry.key, summary, 600)
				end
			end
		end
	end
	return sweep()
end

function AuctionService.IndexIsLocal(): boolean
	return Index.isMock() or store:isMock()
end

function AuctionService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	MailService = registry.Get("MailService")
	store = KeyStore.new(Config.AuctionStoreName, DataService.HasDataStoreAccess)
end

function AuctionService.Start()
	Net.Handle("AuctionList", function(player: Player, index: number, price: number, hours: number)
		return withLock(player, function()
			return list(player, index, price, hours)
		end)
	end)
	Net.Handle("AuctionSearch", function(player: Player, filter: { [any]: any }, page: number, descending: boolean)
		return search(player, filter, page, descending)
	end)
	Net.Handle("AuctionDetails", details)
	Net.Handle("AuctionBuy", function(player: Player, id: string, price: number)
		return withLock(player, function()
			return buy(player, id, price)
		end)
	end)
	Net.Handle("AuctionCancel", function(player: Player, id: string)
		return withLock(player, function()
			return cancel(player, id)
		end)
	end)
	Net.Handle("AuctionMine", function(player: Player)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, data = pcall(mine, player)
		busy[player] = nil
		if not ok then
			log:error("my listings failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, data
	end)
	Net.Handle("AuctionPrice", priceInfo)

	Notify.on("sold", function(player: Player, args: { [string]: any })
		local id = args.id
		local char = character(player)
		if type(id) == "string" and char and char.auctions[id] then
			setOwnListing(player, id, false)
		end
		Net.Fire(player, "Toast", "auction.soldToast", { item = args.item, price = args.price }, "success")
	end)
	Notify.on("expired", function(player: Player, args: { [string]: any })
		local id = args.id
		local char = character(player)
		if type(id) == "string" and char and char.auctions[id] then
			setOwnListing(player, id, false)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)

	-- Expiry sweep with a random offset so servers do not all sweep at once.
	task.spawn(function()
		task.wait(math.random(30, Rules.expireSweepSeconds))
		while true do
			local ok, result = pcall(sweep)
			if not ok then
				log:warn("sweep failed: %s", tostring(result))
			elseif result > 0 then
				log:info("expired %d listings", result)
			end
			task.wait(Rules.expireSweepSeconds)
		end
	end)
end

return AuctionService
