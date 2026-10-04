--!strict
-- 1-on-1 trade (DESIGN §18, S10). A player invites another within Config.TradeRange studs (both alive, not
-- in combat, not trading). Each side puts up to 12 unbound items and gold on the table; every change resets
-- both acceptances. When both accept, a 3 s countdown starts and then both must press Confirm. The exchange
-- itself is Logic/Trade.exchange on copies of both backpacks — all checks first, then both backpacks and
-- gold are swapped in without yielding, then both profiles are saved. Walking away, dying, leaving or
-- closing the window cancels. While a trade is open, items cannot leave the backpack (InventoryService
-- trade lock). State branch `trade` = { partner, mine = { items, gold, accepted, confirmed }, theirs = …,
-- phase = "edit" | "countdown" | "confirm", confirmAt }.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Trade = require(Shared.Logic.Trade)
local Types = require(Shared.Types)

local log = Log.new("TradeService")

local TradeService = {
	Name = "TradeService",
	Deps = { "PlayerStateService", "CharacterService", "ResourceService", "InventoryService", "DataService" },
}

type ItemInstance = Types.ItemInstance

type Offer = { uids: { string }, gold: number, accepted: boolean, confirmed: boolean }

type Session = {
	a: Player,
	b: Player?, -- nil = preview (admin /tradetest)
	offers: { [Player]: Offer },
	phase: "edit" | "countdown" | "confirm",
	confirmAt: number?,
	token: number,
}

local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local InventoryService: any
local DataService: any

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { from: Player, expiresAt: number } } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function nameOf(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function close(player: Player): boolean
	return rootOf(player) ~= nil
end

local function inRange(a: Player, b: Player): boolean
	local ra, rb = rootOf(a), rootOf(b)
	return ra ~= nil and rb ~= nil and (ra.Position - rb.Position).Magnitude <= Config.TradeRange
end

local function partnerOf(session: Session, player: Player): Player?
	return if session.a == player then session.b else session.a
end

-- Items of an offer as instances (for the UI), dropping uids that left the backpack.
local function itemsOf(player: Player, offer: Offer): { ItemInstance }
	local char = character(player)
	local list = {}
	if not char then
		return list
	end
	local kept = {}
	for _, uid in offer.uids do
		for _, item in char.inventory do
			if item.uid == uid then
				table.insert(list, item)
				table.insert(kept, uid)
				break
			end
		end
	end
	offer.uids = kept
	return list
end

local function publish(session: Session)
	local players: { Player } = { session.a }
	if session.b then
		table.insert(players, session.b)
	end
	for _, player in players do
		local partner = partnerOf(session, player)
		local mine = session.offers[player]
		local theirs = if partner then session.offers[partner] else nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "trade" }, {
				partner = if partner then nameOf(partner) else "—",
				preview = session.b == nil,
				phase = session.phase,
				confirmAt = session.confirmAt,
				mine = {
					items = itemsOf(player, mine),
					gold = mine.gold,
					accepted = mine.accepted,
					confirmed = mine.confirmed,
				},
				theirs = if partner and theirs
					then {
						items = itemsOf(partner, theirs),
						gold = theirs.gold,
						accepted = theirs.accepted,
						confirmed = theirs.confirmed,
					}
					else { items = {}, gold = 0, accepted = false, confirmed = false },
			})
		end
	end
end

local function endSession(session: Session, key: string?)
	session.token += 1
	local players: { Player } = { session.a }
	if session.b then
		table.insert(players, session.b)
	end
	for _, player in players do
		do
			sessions[player] = nil
			InventoryService.SetTradeLock(player, false)
			if PlayerStateService.HasState(player) then
				PlayerStateService.Set(player, { "trade" }, nil)
			end
			if key and player.Parent then
				Net.Fire(player, "Toast", key, nil, if key == "trade.done" then "success" else "warning")
			end
		end
	end
end

local function resetAccepts(session: Session)
	session.phase = "edit"
	session.confirmAt = nil
	session.token += 1
	for _, offer in session.offers do
		offer.accepted = false
		offer.confirmed = false
	end
end

local function newOffer(): Offer
	return { uids = {}, gold = 0, accepted = false, confirmed = false }
end

local function begin(a: Player, b: Player?)
	local session: Session = { a = a, b = b, offers = { [a] = newOffer() }, phase = "edit", token = 0 }
	if b then
		session.offers[b] = newOffer()
		sessions[b] = session
		InventoryService.SetTradeLock(b, true)
	end
	sessions[a] = session
	InventoryService.SetTradeLock(a, true)
	publish(session)
end

-- Why `player` cannot trade right now (nil = ok).
local function blocker(player: Player): string?
	if PlayerStateService.GetPhase(player) ~= "playing" or not character(player) then
		return "party.error.notFound"
	end
	if ResourceService.IsDead(player) then
		return "trade.error.dead"
	end
	if ResourceService.InCombat(player) then
		return "trade.error.combat"
	end
	if sessions[player] then
		return "trade.error.busy"
	end
	return nil
end

local function request(player: Player, userId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, "party.error.notFound"
	end
	local why = blocker(player) or blocker(target)
	if why then
		return false, why
	end
	if not inRange(player, target) then
		return false, "trade.error.far"
	end
	local pending = invites[target]
	if pending and pending.expiresAt > os.clock() then
		return false, "party.error.pending"
	end
	invites[target] = { from = player, expiresAt = os.clock() + Config.TradeInviteSeconds }
	Net.Fire(target, "TradeInvited", nameOf(player), Config.TradeInviteSeconds)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local pending = invites[player]
	invites[player] = nil
	if not pending or pending.expiresAt < os.clock() or pending.from.Parent == nil then
		return false, "party.error.expired"
	end
	local from = pending.from
	if not accept then
		Net.Fire(from, "Toast", "trade.declined", { name = nameOf(player) }, "info")
		return true, nil
	end
	local why = blocker(player) or blocker(from)
	if why then
		return false, why
	end
	if not inRange(player, from) then
		return false, "trade.error.far"
	end
	begin(from, player)
	return true, nil
end

local function editable(player: Player): (Session?, string?)
	local session = sessions[player]
	if not session then
		return nil, "trade.error.none"
	end
	return session, nil
end

local function addItem(player: Player, index: number): (boolean, string?)
	local session, err = editable(player)
	if not session then
		return false, err
	end
	local item = InventoryService.Get(player, index)
	local ok, why = Trade.canOffer(item)
	if not ok or not item then
		return false, why
	end
	local offer = session.offers[player]
	if table.find(offer.uids, item.uid) then
		return true, nil
	end
	if #offer.uids >= Trade.MAX_ITEMS then
		return false, "trade.error.tooMany"
	end
	table.insert(offer.uids, item.uid)
	resetAccepts(session)
	publish(session)
	return true, nil
end

local function removeItem(player: Player, uid: string): (boolean, string?)
	local session, err = editable(player)
	if not session then
		return false, err
	end
	local offer = session.offers[player]
	local index = table.find(offer.uids, uid)
	if index then
		table.remove(offer.uids, index)
		resetAccepts(session)
		publish(session)
	end
	return true, nil
end

local function setGold(player: Player, amount: number): (boolean, string?)
	local session, err = editable(player)
	if not session then
		return false, err
	end
	local char = character(player)
	if not char or amount ~= amount or amount < 0 or amount > char.gold then
		return false, "trade.error.gold"
	end
	session.offers[player].gold = math.floor(amount)
	resetAccepts(session)
	publish(session)
	return true, nil
end

local function execute(session: Session): (boolean, string?)
	local a, b = session.a, session.b
	if not b then
		return false, "trade.error.preview"
	end
	local charA, charB = character(a), character(b)
	if not charA or not charB then
		return false, "trade.error.changed"
	end
	local offerA, offerB = session.offers[a], session.offers[b]
	-- No yields from here until both sides are written.
	local result, err = Trade.exchange({
		inventory = charA.inventory,
		capacity = InventoryService.CapacityOf(charA),
		gold = charA.gold,
		offerUids = offerA.uids,
		offerGold = offerA.gold,
	}, {
		inventory = charB.inventory,
		capacity = InventoryService.CapacityOf(charB),
		gold = charB.gold,
		offerUids = offerB.uids,
		offerGold = offerB.gold,
	}, function(): string
		return HttpService:GenerateGUID(false)
	end)
	if not result then
		return false, err
	end
	PlayerStateService.Set(a, { "character", "inventory" }, result.inventoryA)
	PlayerStateService.Set(b, { "character", "inventory" }, result.inventoryB)
	PlayerStateService.Set(a, { "character", "gold" }, result.goldA)
	PlayerStateService.Set(b, { "character", "gold" }, result.goldB)
	InventoryService.SyncAll(a)
	InventoryService.SyncAll(b)
	log:info(
		"trade %s -> %s: %d item(s) + %d gold; %s -> %s: %d item(s) + %d gold",
		a.Name,
		b.Name,
		#result.movedA,
		offerA.gold,
		b.Name,
		a.Name,
		#result.movedB,
		offerB.gold
	)
	task.spawn(DataService.Save, a)
	task.spawn(DataService.Save, b)
	return true, nil
end

local function accept(player: Player, value: boolean): (boolean, string?)
	local session, err = editable(player)
	if not session then
		return false, err
	end
	if session.phase ~= "edit" and not value then
		resetAccepts(session)
		publish(session)
		return true, nil
	end
	session.offers[player].accepted = value
	local partner = partnerOf(session, player)
	if value and partner and session.offers[partner].accepted then
		session.phase = "countdown"
		session.confirmAt = Workspace:GetServerTimeNow() + Config.TradeConfirmDelay
		session.token += 1
		local token = session.token
		task.delay(Config.TradeConfirmDelay, function()
			if session.token == token and session.phase == "countdown" then
				session.phase = "confirm"
				publish(session)
			end
		end)
	end
	publish(session)
	return true, nil
end

local function confirm(player: Player): (boolean, string?)
	local session, err = editable(player)
	if not session then
		return false, err
	end
	if session.phase ~= "confirm" then
		return false, "trade.error.notReady"
	end
	session.offers[player].confirmed = true
	local partner = partnerOf(session, player)
	if partner and session.offers[partner].confirmed then
		if session.b and not inRange(session.a, session.b) then
			endSession(session, "trade.cancelled")
			return false, "trade.error.far"
		end
		local ok, why = execute(session)
		if ok then
			endSession(session, "trade.done")
			return true, nil
		end
		endSession(session, "trade.cancelled")
		return false, why
	end
	publish(session)
	return true, nil
end

local function cancel(player: Player, key: string?)
	local session = sessions[player]
	if session then
		endSession(session, key)
	end
end

-- Admin /tradetest: opens the window with an empty partner side (no exchange possible).
function TradeService.Preview(player: Player): boolean
	if sessions[player] then
		return false
	end
	begin(player, nil)
	return true
end

function TradeService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	InventoryService = registry.Get("InventoryService")
	DataService = registry.Get("DataService")
end

function TradeService.Start()
	Net.Handle("TradeRequest", request)
	Net.Handle("TradeRespond", respond)
	Net.Handle("TradeAddItem", addItem)
	Net.Handle("TradeRemoveItem", removeItem)
	Net.Handle("TradeSetGold", setGold)
	Net.Handle("TradeAccept", accept)
	Net.Handle("TradeConfirm", confirm)
	Net.On("TradeCancel", function(player: Player)
		cancel(player, "trade.cancelled")
	end)

	ResourceService.Died:Connect(function(player: Player)
		cancel(player, "trade.cancelled")
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
		cancel(player, "trade.cancelled")
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		cancel(player, "trade.cancelled")
	end)

	-- Walking away cancels.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, session in sessions do
				if session.a == player and session.b then
					local b = session.b :: Player
					if not close(player) or not close(b) or not inRange(player, b) then
						endSession(session, "trade.cancelledFar")
					end
				end
			end
		end
	end)
end

return TradeService
