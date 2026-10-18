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
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local Inventory = require(Shared.Logic.Inventory)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Log = require(Shared.Util.Log)
local Mail = require(Shared.Logic.Mail)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Market.Notify)
local Social = require(Shared.Logic.Social)
local Types = require(Shared.Types)

local log = Log.new("MailService")

type ItemInstance = Types.ItemInstance

local MailService = {
	Name = "MailService",
	-- S133: NameService (recipient by character name) and SocialService (ignored senders)
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"InventoryService",
		"NpcService",
		"NameService",
		"SocialService",
	},
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
	-- S133: a letter from a player (from = "player"): filtered subject and body, the sender's account and character
	subject: string?,
	body: string?,
	fromId: number?,
	fromChar: string?,
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
local NameService: any
local SocialService: any

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

-- S134g: the class Logic/Mail.box converts a parcel's Legendary / Mythic items for: the active character's when the
-- parcel is addressed to it (or to the whole account), else nil (the item's own classes).
local function classOf(player: Player): (charId: string?) -> string?
	return function(charId: string?): string?
		local char = character(player)
		if char and (charId == nil or charId == char.id) then
			return char.class
		end
		return nil
	end
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
		boxes[player] = Mail.box(value, classOf(player))
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
		subject = outgoing.subject,
		body = outgoing.body,
		fromId = outgoing.fromId,
		fromChar = outgoing.fromChar,
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
	-- S133: a letter from a player names its sender in the notice ("New letter from <name>")
	Notify.send(userId, "mail", if parcel.from == "player" then { name = parcel.fromName } else nil)
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
	local cached = box.parcels[id]
	if not cached then
		return false, "mail.error.gone"
	end
	-- S133: a letter with nothing to take (text only) is read and thrown away anywhere
	if not Mail.isEmpty(cached) and not NpcService.NearService(player, "mail") then
		return false, "mail.error.tooFar"
	end
	if
		#cached.items > 0
		and not Inventory.canFit(char.inventory, InventoryService.CapacityOf(char, player), cached.items)
	then
		return false, "inventory.full"
	end
	local taken: Mail.Parcel? = nil
	local ok, newBox, err = store:update(key(player.UserId), function(current: any?)
		local b = Mail.box(current, classOf(player))
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
	boxes[player] = Mail.box(newBox, classOf(player))
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

-- S133: letters between players ---------------------------------------------------------------------------------

-- The Roblox filter for text from `fromId` to `toId` (private context): the recipient's own view when they are on this
-- server, else the broadcast version (the strictest). Yields. Returns the filtered text or nil when the filter failed.
local function filterText(text: string, fromId: number, toId: number): string?
	if text == "" then
		return ""
	end
	local ok, result = pcall(function(): string
		local filtered = TextService:FilterStringAsync(text, fromId, Enum.TextFilterContext.PrivateChat)
		if Players:GetPlayerByUserId(toId) then
			return filtered:GetNonChatStringForUserAsync(toId)
		end
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		log:warn("text filter failed for a letter from %d: %s", fromId, tostring(result))
		return nil
	end
	return result
end

local function isWhole(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

-- Backpack slots of the letter's items, checked: distinct, takeable, mailable. Returns (uids by slot?, errorKey?).
local function letterItems(player: Player, slots: { number }): ({ [number]: string }?, string?)
	local uids: { [number]: string } = {}
	for _, slot in slots do
		if uids[slot] or not InventoryService.ValidTakeIndex(player, slot) then
			return nil, "error.badRequest"
		end
		local item = InventoryService.Get(player, slot)
		local ok, err = Social.mailableItem(item)
		if not ok or not item then
			return nil, err
		end
		uids[slot] = item.uid
	end
	return uids, nil
end

-- Sends a letter to a character by name. Order: checks, recipient (NameService), ignore, filter (all yield), checks
-- again, then gold, postage and items leave the character before the parcel is written; a failed write gives them
-- back. Returns (ok, errorKey?).
local function sendLetter(player: Player, letter: any): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local rules = Config.PlayerMail
	if
		type(letter) ~= "table"
		or type(letter.to) ~= "string"
		or #letter.to > 64
		or type(letter.subject) ~= "string"
		or #letter.subject > rules.subjectMax * 4
		or type(letter.body) ~= "string"
		or #letter.body > rules.bodyMax * 4
		or not isWhole(letter.gold, 0, 1e12)
		or type(letter.items) ~= "table"
		or #letter.items > rules.maxItems
	then
		return false, "error.badRequest"
	end
	local slots: { number } = {}
	for i, slot in letter.items do
		if i ~= #slots + 1 or not isWhole(slot, 1, 10000) then
			return false, "error.badRequest"
		end
		table.insert(slots, slot)
	end
	local to: string = letter.to
	local gold: number = letter.gold
	local subject = Social.cleanText(letter.subject, false)
	local body = Social.cleanText(letter.body, true)
	if char.level < rules.minLevel then
		return false, "mail.error.level"
	end
	local valid, invalid = Social.validateLetter({ subject = subject, body = body, gold = gold, itemCount = #slots })
	if not valid then
		return false, invalid
	end
	local canSend, limitErr = Social.canSendToday(char.mailSent, os.time())
	if not canSend then
		return false, limitErr
	end
	if Social.needsMailbox(gold, #slots) and not NpcService.NearService(player, "mail") then
		return false, "mail.error.sendAtMailbox"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "mail.error.trading"
	end
	local fee = Social.letterFee(#slots)
	if char.gold < gold + fee then
		return false, "mail.error.gold"
	end
	local uids, itemErr = letterItems(player, slots)
	if not uids then
		return false, itemErr
	end

	-- Recipient, ignore and filter (yields)
	local found, userId, charId = NameService.Lookup(to)
	if not found then
		return false, "mail.error.store"
	end
	if not userId or not charId then
		return false, "mail.error.noRecipient"
	end
	if userId == player.UserId and charId == char.id then
		return false, "mail.error.self"
	end
	if SocialService.IgnoresUser(player, userId) then
		return false, "social.error.youIgnore"
	end
	local readOk, ignored = SocialService.Ignores(userId, player.UserId)
	if not readOk then
		return false, "mail.error.store"
	end
	if ignored then
		return false, "mail.error.unavailable"
	end
	local cleanSubject = filterText(subject, player.UserId, userId)
	local cleanBody = filterText(body, player.UserId, userId)
	if cleanSubject == nil or cleanBody == nil then
		return false, "mail.error.filter"
	end

	-- The world may have moved while we waited: same character, same items, enough gold.
	if character(player) ~= char or player.Parent ~= Players then
		return false, "error.wrongPhase"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "mail.error.trading"
	end
	if char.gold < gold + fee then
		return false, "mail.error.gold"
	end
	for slot, uid in uids do
		local item = InventoryService.Get(player, slot)
		if not item or item.uid ~= uid or not Social.mailableItem(item) then
			return false, "mail.error.changed"
		end
	end

	-- Take first, then write; a failed write gives everything back.
	local items: { ItemInstance } = {}
	for _, slot in slots do
		local item = InventoryService.Get(player, slot) :: ItemInstance
		table.insert(items, table.clone(item))
		InventoryService.SetSlot(player, slot, nil)
	end
	PlayerStateService.Update(player, { "character", "gold" }, function(g: number)
		return g - gold - fee
	end)
	local sent, err = MailService.Send(userId, {
		from = "player",
		fromName = char.name,
		fromId = player.UserId,
		fromChar = char.id,
		subjectKey = "mail.player.subject",
		args = { name = char.name },
		subject = cleanSubject,
		body = cleanBody,
		gold = gold,
		items = items,
		charId = charId,
	})
	if not sent then
		PlayerStateService.Update(player, { "character", "gold" }, function(g: number)
			return g + gold + fee
		end)
		local back: { ItemInstance } = {}
		for _, item in items do
			local rest = InventoryService.AddItem(player, item)
			if rest > 0 then
				local copy = table.clone(item)
				copy.n = rest
				table.insert(back, copy)
			end
		end
		if #back > 0 then
			MailService.Send(player.UserId, {
				from = "system",
				subjectKey = "mail.subject.returned",
				items = back,
				charId = char.id,
			})
		end
		return false, if err == "mail.error.full" then "mail.error.recipientFull" else (err or "mail.error.store")
	end
	PlayerStateService.Set(player, { "character", "mailSent" }, Social.countSent(char.mailSent, os.time()))
	QuestEvents.fire(player, "mail", nil) -- S151: a letter to a player (achievements)
	DataService.Save(player)
	log:info("%s sent a letter to %s (%d): %d gold, %d items, fee %d", player.Name, to, userId, gold, #items, fee)
	return true, nil
end

-- Sends a letter from a player with gold or items back to its sender (no postage). Yields. Returns (ok, errorKey?).
local function sendBack(player: Player, id: string): (boolean, string?)
	local char = character(player)
	local box = boxes[player]
	if not char or not box then
		return false, "error.wrongPhase"
	end
	local cached = box.parcels[id]
	if not cached then
		return false, "mail.error.gone"
	end
	if not Mail.returnable(cached) then
		return false, "mail.error.notReturnable"
	end
	local taken: Mail.Parcel? = nil
	local ok, newBox, err = store:update(key(player.UserId), function(current: any?)
		local b = Mail.box(current, classOf(player))
		local parcel = b.parcels[id]
		if not parcel or not Mail.returnable(parcel) then
			return nil, "mail.error.gone"
		end
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
	boxes[player] = Mail.box(newBox, classOf(player))
	local parcel = taken :: Mail.Parcel
	local sent = MailService.Send(parcel.fromId :: number, {
		from = "system",
		subjectKey = "mail.subject.bounced",
		args = { name = char.name },
		gold = parcel.gold,
		items = parcel.items,
		charId = parcel.fromChar,
	})
	if not sent then
		-- the sender's mailbox refused it: the letter goes back where it was
		store:update(key(player.UserId), function(current: any?)
			local b = Mail.box(current, classOf(player))
			local added, reason = Mail.add(b, parcel, os.time())
			if not added then
				return nil, reason
			end
			return b, nil
		end)
		MailService.Refresh(player)
		return false, "mail.error.returnFailed"
	end
	publish(player)
	return true, nil
end

function MailService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	NameService = registry.Get("NameService")
	SocialService = registry.Get("SocialService")
	store = KeyStore.new(Config.MailStoreName, DataService.HasDataStoreAccess)
end

function MailService.Start()
	task.spawn(Notify.start)
	Notify.on("mail", function(player: Player, args: { [string]: any })
		if character(player) then
			MailService.Refresh(player)
			-- S133: a letter from a player names its sender
			if type(args) == "table" and type(args.name) == "string" then
				Net.Fire(player, "Toast", "mail.arrivedFrom", { name = args.name }, "info")
			else
				Net.Fire(player, "Toast", "mail.arrived", nil, "info")
			end
		end
	end)
	-- S133: letters between players and sending one back
	Net.Handle("MailSend", function(player: Player, letter: any)
		return withLock(player, function()
			return sendLetter(player, letter)
		end)
	end)
	Net.Handle("MailReturn", function(player: Player, id: string)
		return withLock(player, function()
			return sendBack(player, id)
		end)
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
