--!strict
-- Gamepasses and developer products (DESIGN §21).
--   Products : ProcessReceipt is idempotent through account.purchases[receiptId]; it answers NotProcessedYet
--              while the profile is not loaded, grants (Dragon Shards, or a product handler such as the
--              instant respawn), records the receipt and saves the profile before PurchaseGranted.
--   Passes   : ownership checked once per join (UserOwnsGamePassAsync) and on PromptGamePassPurchaseFinished,
--              cached; replicated as state branch `passes` and the player attribute "Vip".
-- Ids in Data/Products are placeholders (0). In Studio BuyProduct/BuyPass simulate the purchase on the
-- server so everything is testable without Robux; on live servers id 0 is refused. Admins grant passes with /premium grant.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local Products = require(Shared.Data.Products)
local Signal = require(ReplicatedStorage.Packages.Signal)

local log = Log.new("MonetizationService")

local MonetizationService = {
	Name = "MonetizationService",
	Deps = { "DataService", "PlayerStateService" },
	-- (player, passKey, owned) when a pass is bought or granted.
	PassChanged = Signal.new(),
}

export type PassId = "fastRespawn" | "autoLoot" | "vault" | "vip"

local RECEIPT_KEEP = 90 * 86400

local DataService: any
local PlayerStateService: any

local owned: { [Player]: { [string]: boolean } } = {}
-- Product kinds other than shard packs: "respawn" -> handler(player) -> granted?
local productHandlers: { [string]: (player: Player) -> boolean } = {}

-- Simulated purchases exist only in Studio. On live servers an unconfigured id (0) is refused, never free.
local function simulated(): boolean
	return RunService:IsStudio()
end

local function publish(player: Player)
	local passes: { [string]: boolean } = owned[player] or {}
	player:SetAttribute("Vip", passes.vip == true)
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "passes" }, table.clone(passes))
	end
end

function MonetizationService.HasPass(player: Player, passId: PassId): boolean
	local passes = owned[player]
	return passes ~= nil and passes[passId] == true
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

local function keyOfProduct(productId: number): string?
	for _, pack in Products.shardPacks do
		if pack.productId == productId and productId ~= 0 then
			return pack.key
		end
	end
	if Products.respawn.productId == productId and productId ~= 0 then
		return Products.respawn.key
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
	log:info("receipt %s: %s granted %s", receiptId, player.Name, key)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function buyProduct(player: Player, key: string): (boolean, string?)
	local productId = if Products.getPack(key)
		then (Products.getPack(key) :: any).productId
		elseif key == Products.respawn.key then Products.respawn.productId
		else nil
	if productId == nil then
		return false, "error.badRequest"
	end
	if simulated() then
		-- Test mode: no Robux, same grant path (receipt ids are not needed without MarketplaceService).
		local ok = grant(player, key)
		if ok then
			DataService.Save(player)
			log:info("simulated purchase of %s by %s", key, player.Name)
		end
		return ok, if ok then nil else "premium.error.notNow"
	end
	if productId == 0 then
		return false, "premium.error.notConfigured"
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true, "premium.prompted"
end

local function buyPass(player: Player, key: string): (boolean, string?)
	local pass = Products.getPass(key)
	if not pass then
		return false, "error.badRequest"
	end
	if MonetizationService.HasPass(player, key :: PassId) then
		return false, "premium.error.owned"
	end
	if simulated() then
		setPass(player, key, true)
		Net.Fire(player, "Toast", "premium.passGranted", { pass = `@premium.pass.{key}` }, "success")
		return true, nil
	end
	if pass.passId == 0 then
		return false, "premium.error.notConfigured"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.passId)
	return true, "premium.prompted"
end

local function loadPasses(player: Player)
	for _, pass in Products.passes do
		if pass.passId ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.passId)
			end)
			if ok and has and player.Parent == Players then
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
					setPass(player, pass.key, true)
					Net.Fire(player, "Toast", "premium.passGranted", { pass = `@premium.pass.{pass.key}` }, "success")
				end
			end
		end
	)
	Net.Handle("BuyProduct", buyProduct)
	Net.Handle("BuyPass", buyPass)

	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerAdded:Connect(loadPasses)
	PlayerStateService.Ready:Connect(publish)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return MonetizationService
