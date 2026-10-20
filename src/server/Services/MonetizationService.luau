--!strict
-- Gamepasses and developer products (DESIGN §21).
--   Products : ProcessReceipt is idempotent through account.purchases[receiptId]; it answers NotProcessedYet
--              while the profile is not loaded, grants (Dragon Shards, or a product handler such as the
--              instant respawn), records the receipt and saves the profile before PurchaseGranted.
--   Passes   : ownership checked once per join (UserOwnsGamePassAsync) and on PromptGamePassPurchaseFinished,
--              cached; replicated as state branch `passes` and the player attribute "Vip".
-- Ids in Data/Products are placeholders (0). In Studio BuyProduct/BuyPass simulate the purchase on the
-- server so everything is testable without Robux; on live servers id 0 is refused. Admins grant passes with /premium grant.
-- S97: premium mounts (Data/Products.mounts, handlers registered by MountService) are sold only while enabled
-- (Logic/Premium.canBuyMount), even in Studio; today none is.
--   Subscriptions (S121, DESIGN-17 §2): the VIP is an Experience Subscription (Data/Products.subscriptions). Its status
--              is read from MarketplaceService:GetUserSubscriptionStatusAsync (always in pcall; an error keeps the last
--              known value and retries on the next check) on join, on Players.UserSubscriptionStatusChanged, on
--              PromptSubscriptionPurchaseFinished and every Config.Vip.statusRefresh seconds. Roblox issues no receipts
--              for subscriptions (no ProcessReceipt). HasVip = an active VIP subscription or the "vip" pass ("VIP
--              forever", switched off in Data/Products until the owner decides). Replicated as the player attribute
--              "Vip" and the state branch `vip` = { active, sub, pass, renewing?, endsAt? }; VipChanged fires on change.
--              An empty subscriptionId is simulated in Studio and refused (premium.error.notConfigured) on live servers;
--              /vip on|off (admin) sets a session-only test subscription.
--   Starter packs (S123, DESIGN-17 §4): Developer Products once per account (Logic/Premium.canBuyPack before the prompt,
--              also in Studio); PremiumShopService registers their grant handlers. A pass granted by a pack is saved in
--              account.grantedPasses (GrantProfilePass) and merged into the pass cache when the profile is ready, so
--              HasPass honours it everywhere. Taking it away needs /pack reset (/pass <key> off only clears the cache
--              until the next join).
--   Funnels (S131, DESIGN-17 §9): src/server/PremiumFunnel (Logic/ShopFunnel) logs the shop funnel (open, tab, item from
--              the client through the PremiumFunnel remote; prompt and granted here and in PremiumShopService) and the
--              VIP funnel (open from the client; prompt and active here). "VipActiveJoin" once per player and server
--              session when the VIP is active. Admin grants (/premium grant, /vip grant) are account.grantedPasses
--              (GrantProfilePass), the same path as a starter pack.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local PremiumFunnel = require(script.Parent.Parent.PremiumFunnel)
local Products = require(Shared.Data.Products)
local ShopPayload = require(Shared.Logic.ShopPayload)
local Signal = require(ReplicatedStorage.Packages.Signal)

local log = Log.new("MonetizationService")

local MonetizationService = {
	Name = "MonetizationService",
	Deps = { "DataService", "PlayerStateService" },
	-- (player, passKey, owned) when a pass is bought or granted.
	PassChanged = Signal.new(),
	-- (player, active) when HasVip changes (subscription or the "vip" pass), S121.
	VipChanged = Signal.new(),
}

export type PassId = "fastRespawn" | "autoLoot" | "vault" | "vip" | "pockets" | "slot4" | "slot5" | "wardrobePlus"

local RECEIPT_KEEP = 90 * 86400

local DataService: any
local PlayerStateService: any

local owned: { [Player]: { [string]: boolean } } = {}
-- S131: passes Roblox says the player owns (UserOwnsGamePassAsync / a finished prompt); an admin cannot take these.
local robloxOwned: { [Player]: { [string]: boolean } } = {}
-- S121: subscription status from the API (key -> status) and the session-only test subscriptions (admin, Studio).
type SubStatus = { active: boolean, renewing: boolean?, endsAt: number? }
local subs: { [Player]: { [string]: SubStatus } } = {}
local testSubs: { [Player]: { [string]: boolean } } = {}
-- The last published HasVip per player (VipChanged fires only on a change).
local vipNow: { [Player]: boolean } = {}
-- S131: players whose active VIP was reported to analytics in this server session ("VipActiveJoin").
local vipLogged: { [Player]: boolean } = {}
-- Product kinds other than shard packs: starter packs (PremiumShopService) -> handler(player) -> granted?
local productHandlers: { [string]: (player: Player) -> boolean } = {}

-- Simulated purchases exist only in Studio. On live servers an unconfigured id (0) is refused, never free.
local function simulated(): boolean
	return RunService:IsStudio()
end

function MonetizationService.HasPass(player: Player, passId: PassId): boolean
	local passes = owned[player]
	return passes ~= nil and passes[passId] == true
end

-- S121: a copy of the owned passes (Logic/Premium rules that take the whole set: slots, looks).
function MonetizationService.Passes(player: Player): { [string]: boolean }
	return table.clone(owned[player] or {})
end

-- S121: an active subscription `key` (a test one, or the API status).
function MonetizationService.HasSubscription(player: Player, key: string): boolean
	local test = testSubs[player]
	if test and test[key] == true then
		return true
	end
	local mine = subs[player]
	local status = if mine then mine[key] else nil
	return status ~= nil and status.active == true
end

-- S121 (DESIGN-17 §2): VIP = the subscription or the "vip" pass.
function MonetizationService.HasVip(player: Player): boolean
	return MonetizationService.HasSubscription(player, "vip") or MonetizationService.HasPass(player, "vip")
end

local function publish(player: Player)
	local passes: { [string]: boolean } = owned[player] or {}
	local vip = MonetizationService.HasVip(player)
	player:SetAttribute("Vip", vip)
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "passes" }, table.clone(passes))
		local test = testSubs[player]
		local testOn = test ~= nil and test.vip == true
		local mine = subs[player]
		local status: SubStatus? = if mine and not testOn then mine.vip else nil
		PlayerStateService.Set(player, { "vip" }, {
			active = vip,
			sub = MonetizationService.HasSubscription(player, "vip"),
			pass = MonetizationService.HasPass(player, "vip"),
			renewing = if status and status.active then status.renewing else nil,
			endsAt = if status and status.active then status.endsAt else nil,
		})
	end
	if player.Parent == Players and (vipNow[player] == true) ~= vip then
		vipNow[player] = vip
		MonetizationService.VipChanged:Fire(player, vip)
	end
	if vip and player.Parent == Players and not vipLogged[player] then
		vipLogged[player] = true
		Analytics.custom(player, "VipActiveJoin", 1)
	end
end

local function setPass(player: Player, passKey: string, value: boolean)
	local passes = owned[player] or {}
	passes[passKey] = if value then true else nil
	owned[player] = passes
	publish(player)
	MonetizationService.PassChanged:Fire(player, passKey, value)
end

-- Test helper for admin commands (/pass, /premium grant).
function MonetizationService.SetTestPass(player: Player, passId: string, value: boolean)
	setPass(player, passId, value)
end

-- S121: a session-only test subscription (admin /vip on|off; the simulated purchase in Studio). Never saved.
function MonetizationService.SetTestSubscription(player: Player, key: string, value: boolean)
	local test = testSubs[player] or {}
	test[key] = if value then true else nil
	testSubs[player] = test
	publish(player)
end

function MonetizationService.RegisterProduct(kind: string, handler: (player: Player) -> boolean)
	productHandlers[kind] = handler
end

local function addShards(player: Player, amount: number, reason: string)
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return shards + amount
	end)
	Analytics.shards(player, amount, total, reason)
end

-- Grants a product by key. Returns true when granted.
local function grant(player: Player, key: string): boolean
	local pack = Products.getPack(key)
	if pack then
		addShards(player, pack.shards, key)
		Net.Fire(player, "Toast", "premium.shardsAdded", { n = pack.shards }, "success")
		return true
	end
	local handler = productHandlers[key]
	return handler ~= nil and handler(player)
end

-- S123: a pass granted in the profile (a starter pack): saved for good and cached at once (PassChanged refreshes the
-- backpack capacity of Merchant's Pockets).
function MonetizationService.GrantProfilePass(player: Player, passKey: string)
	PlayerStateService.Set(player, { "account", "grantedPasses", passKey }, true)
	setPass(player, passKey, true)
end

-- S123 (admin /pack reset): the pass is no longer granted in the profile; the cache drops it too.
function MonetizationService.RevokeProfilePass(player: Player, passKey: string)
	PlayerStateService.Set(player, { "account", "grantedPasses", passKey }, nil)
	setPass(player, passKey, false)
end

-- S131 (admin /premium list, /vip status): where each pass of the player comes from. `roblox` = bought on Roblox,
-- `granted` = account.grantedPasses (a starter pack or an admin grant), `cache` = in the session cache (also test
-- passes of /pass on and simulated Studio purchases).
export type PassSource = { roblox: boolean, granted: boolean, cache: boolean }
function MonetizationService.PassSource(player: Player, passKey: string): PassSource
	local data = DataService.GetData(player)
	local granted = data and data.grantedPasses
	local mine = robloxOwned[player]
	local cache = owned[player]
	return {
		roblox = mine ~= nil and mine[passKey] == true,
		granted = type(granted) == "table" and granted[passKey] == true,
		cache = cache ~= nil and cache[passKey] == true,
	}
end

-- S123: when the profile is ready, the passes granted in it join the cache (no toast), then everything is published.
local function onReady(player: Player)
	local data = DataService.GetData(player)
	local granted = data and data.grantedPasses
	if type(granted) == "table" then
		local passes = owned[player] or {}
		for key, on in granted do
			if on == true and Products.getPass(key) then
				passes[key] = true
			end
		end
		owned[player] = passes
	end
	publish(player)
end

local function keyOfProduct(productId: number): string?
	for _, pack in Products.shardPacks do
		if pack.productId == productId and productId ~= 0 then
			return pack.key
		end
	end
	for _, entry in Products.mounts do
		if entry.productId == productId and productId ~= 0 then
			return entry.key
		end
	end
	for _, pack in Products.starterPacks do
		if pack.productId == productId and productId ~= 0 then
			return pack.key
		end
	end
	return nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and DataService.GetData(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	if Premium.alreadyGranted(data.purchases, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = keyOfProduct(info.ProductId)
	if not key then
		log:warn("unknown product %s bought by %s", tostring(info.ProductId), player.Name)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not grant(player, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.purchases[receiptId] = os.time()
	Premium.pruneReceipts(data.purchases, os.time(), RECEIPT_KEEP)
	DataService.Save(player)
	Analytics.custom(player, "PremiumPurchase", info.CurrencySpent or 0)
	PremiumFunnel.step(player, "shop", "granted")
	log:info("receipt %s: %s granted %s", receiptId, player.Name, key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function buyProduct(player: Player, key: string): (boolean, string?)
	local mount = Products.getMount(key)
	if mount then
		local ok, err = Premium.canBuyMount(key, PlayerStateService.GetCharacter(player))
		if not ok then
			return false, err
		end
	end
	-- S123: a starter pack is bought once per account (refused before the prompt, also in Studio)
	local starter = Products.getStarterPack(key)
	if starter then
		local data = DataService.GetData(player)
		if not data then
			return false, "error.wrongPhase"
		end
		local ok, err = Premium.canBuyPack(key, data)
		if not ok then
			return false, err
		end
	end
	local productId = ShopPayload.productIdOf(key)
	if productId == nil then
		return false, "error.badRequest"
	end
	-- W28: every Robux product is a shop purchase now (the death screen's respawn costs Dragon Shards)
	local shop = true
	if simulated() then
		-- Test mode: no Robux, same grant path (receipt ids are not needed without MarketplaceService).
		if shop then
			PremiumFunnel.step(player, "shop", "prompt")
		end
		local ok = grant(player, key)
		if ok then
			DataService.Save(player)
			if shop then
				PremiumFunnel.step(player, "shop", "granted")
			end
			log:info("simulated purchase of %s by %s", key, player.Name)
		end
		return ok, if ok then nil else "premium.error.notNow"
	end
	if productId == 0 then
		return false, "premium.error.notConfigured"
	end
	if shop then
		PremiumFunnel.step(player, "shop", "prompt")
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true, "premium.prompted"
end

-- Errors may carry toast arguments as a third value (premium.error.requires names the pass to buy first).
local function buyPass(player: Player, key: string): (boolean, string?, { [string]: any }?)
	local pass = Products.getPass(key)
	if not pass then
		return false, "error.badRequest", nil
	end
	-- S121: a switched-off pass (VIP forever) is refused even in Studio; slot 5 needs slot 4 first.
	local ok, err = Premium.canBuyPass(key, owned[player] or {})
	if not ok then
		local args = if err == "premium.error.requires" and pass.requires
			then { pass = `@premium.pass.{pass.requires}` }
			else nil
		return false, err, args
	end
	if simulated() then
		PremiumFunnel.step(player, "shop", "prompt")
		setPass(player, key, true)
		PremiumFunnel.step(player, "shop", "granted")
		Net.Fire(player, "Toast", "premium.passGranted", { pass = `@premium.pass.{key}` }, "success")
		return true, nil
	end
	if pass.passId == 0 then
		return false, "premium.error.notConfigured"
	end
	PremiumFunnel.step(player, "shop", "prompt")
	MarketplaceService:PromptGamePassPurchase(player, pass.passId)
	return true, "premium.prompted"
end

-- S121: the VIP subscription prompt (or the simulated purchase in Studio).
local function buySubscription(player: Player, key: string): (boolean, string?)
	local sub = Products.getSubscription(key)
	local ok, err = Premium.canBuySubscription(key, MonetizationService.HasSubscription(player, key))
	if not ok or not sub then
		return false, err or "error.badRequest"
	end
	if simulated() then
		PremiumFunnel.step(player, "vip", "prompt")
		MonetizationService.SetTestSubscription(player, key, true)
		PremiumFunnel.step(player, "vip", "active")
		Net.Fire(player, "Toast", "premium.subGranted", { name = `@premium.sub.{key}` }, "success")
		log:info("simulated subscription %s for %s", key, player.Name)
		return true, nil
	end
	if sub.subscriptionId == "" then
		return false, "premium.error.notConfigured"
	end
	PremiumFunnel.step(player, "vip", "prompt")
	local prompted = pcall(function()
		-- typed as any: the subscription API may be missing from the analyzer's type definitions
		(MarketplaceService :: any):PromptSubscriptionPurchase(player, sub.subscriptionId)
	end)
	if not prompted then
		return false, "premium.error.notNow"
	end
	return true, "premium.prompted"
end

-- S121: the subscription status from the API. Names checked on create.roblox.com (MarketplaceService page, 2026-10):
-- GetUserSubscriptionStatusAsync(player, id) -> { IsSubscribed, IsRenewing }, GetUserSubscriptionPaymentHistoryAsync
-- (player, id) -> { { PaymentStatus, CycleStartTime: DateTime, CycleEndTime: DateTime } }. Every call is in pcall: an
-- error keeps the last known value (first time: none) and the next check tries again.
local function loadSubscriptions(player: Player)
	for _, sub in Products.subscriptions do
		if not sub.enabled or sub.subscriptionId == "" then
			continue
		end
		local ok, result = pcall(function(): any
			return (MarketplaceService :: any):GetUserSubscriptionStatusAsync(player, sub.subscriptionId)
		end)
		if player.Parent ~= Players then
			return
		end
		if not ok or type(result) ~= "table" then
			log:warn("subscription status %s for %s failed: %s", sub.key, player.Name, tostring(result))
			continue
		end
		local status: SubStatus = { active = result.IsSubscribed == true, renewing = result.IsRenewing == true }
		if status.active then
			local okHistory, history = pcall(function(): any
				return (MarketplaceService :: any):GetUserSubscriptionPaymentHistoryAsync(player, sub.subscriptionId)
			end)
			if okHistory and type(history) == "table" then
				local latest = 0
				for _, entry in history do
					local cycleEnd = if type(entry) == "table" then entry.CycleEndTime else nil
					if typeof(cycleEnd) == "DateTime" then
						latest = math.max(latest, (cycleEnd :: DateTime).UnixTimestamp)
					end
				end
				status.endsAt = if latest > 0 then latest else nil
			end
		end
		if player.Parent ~= Players then
			return
		end
		local mine = subs[player] or {}
		local before = mine[sub.key]
		mine[sub.key] = status
		subs[player] = mine
		-- S131: a known inactive status that turns active is a conversion of the VIP funnel (not the first read on join)
		if sub.key == "vip" and status.active and before ~= nil and not before.active then
			PremiumFunnel.step(player, "vip", "active")
		end
	end
	if player.Parent == Players then
		publish(player)
	end
end

local function loadPasses(player: Player)
	for _, pass in Products.passes do
		if pass.passId ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.passId)
			end)
			if ok and has and player.Parent == Players then
				local mine = robloxOwned[player] or {}
				mine[pass.key] = true
				robloxOwned[player] = mine
				setPass(player, pass.key, true)
			end
		end
	end
end

function MonetizationService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for _, pass in Products.passes do
				if pass.passId == passId and passId ~= 0 then
					local mine = robloxOwned[player] or {}
					mine[pass.key] = true
					robloxOwned[player] = mine
					setPass(player, pass.key, true)
					PremiumFunnel.step(player, "shop", "granted")
					Net.Fire(player, "Toast", "premium.passGranted", { pass = `@premium.pass.{pass.key}` }, "success")
				end
			end
		end
	)
	Net.Handle("BuyProduct", buyProduct)
	Net.Handle("BuyPass", buyPass)
	Net.Handle("BuySubscription", buySubscription)
	-- S131: funnel steps from the shop and VIP windows (Logic/ShopFunnel.CLIENT_STEPS; anything else is ignored)
	Net.On("PremiumFunnel", function(player: Player, funnel: string, stepName: string)
		PremiumFunnel.fromClient(player, funnel, stepName)
	end)

	-- S121: subscription events (connected in pcall: an older API may lack them).
	local okChanged, errChanged = pcall(function()
		(Players :: any).UserSubscriptionStatusChanged:Connect(function(player: Player, _subscriptionId: string)
			task.spawn(loadSubscriptions, player)
		end)
	end)
	if not okChanged then
		log:warn("UserSubscriptionStatusChanged unavailable: %s", tostring(errChanged))
	end
	local okFinished, errFinished = pcall(function()
		(MarketplaceService :: any).PromptSubscriptionPurchaseFinished:Connect(
			function(player: Player, _subscriptionId: string, _didTry: boolean)
				task.spawn(loadSubscriptions, player)
			end
		)
	end)
	if not okFinished then
		log:warn("PromptSubscriptionPurchaseFinished unavailable: %s", tostring(errFinished))
	end

	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
		task.spawn(loadSubscriptions, player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(loadSubscriptions, player)
		loadPasses(player)
	end)
	PlayerStateService.Ready:Connect(onReady) -- S123: merges account.grantedPasses, then publishes
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		robloxOwned[player] = nil
		subs[player] = nil
		testSubs[player] = nil
		vipNow[player] = nil
		vipLogged[player] = nil
		PremiumFunnel.clear(player)
	end)
	-- S121: safety re-check of the subscription status while in game (spread around the interval; not a game roll).
	task.spawn(function()
		while true do
			task.wait(Config.Vip.statusRefresh * (0.9 + 0.2 * math.random()))
			for _, player in Players:GetPlayers() do
				task.spawn(loadSubscriptions, player)
			end
		end
	end)
end

return MonetizationService
