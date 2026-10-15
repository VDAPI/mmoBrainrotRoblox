--!strict
-- Roblox AnalyticsService wrapper (S14). Never throws and never yields the caller.
--   gold / shards : economy sources and sinks (LogEconomyEvent)
--   onboarding    : tutorial funnel steps (LogOnboardingFunnelStepEvent)
--   progression   : levels and bosses (LogProgressionCompleteEvent)
--   custom        : legendary drops, +7..+9 upgrades, premium purchases (LogCustomEvent); event names must be a
--                   bounded set (Roblox counts unique names): never an item or cosmetic id in the name (S131)
--   funnel        : the shop and VIP funnels (LogFunnelStepEvent, S131; src/server/PremiumFunnel.luau)
-- A module, not a service, so any service can report without a dependency.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local service: any = AnalyticsService

local function call(fn: () -> ())
	task.spawn(function()
		pcall(fn)
	end)
end

-- The transaction type: `shop` (a premium shop spend, S131) or the reason "shop"/"premium" is Shop, Robux shards
-- ("shards_<n>") and starter packs ("starter_<name>") are IAP, the rest Gameplay.
local function economy(player: Player, currency: string, delta: number, balance: number, reason: string, shop: boolean?)
	if delta == 0 then
		return
	end
	local source = delta > 0
	local iap = string.sub(reason, 1, 7) == "shards_" or string.sub(reason, 1, 8) == "starter_"
	local isShop = shop or reason == "shop" or reason == "premium"
	local transaction = if isShop
		then Enum.AnalyticsEconomyTransactionType.Shop.Name
		elseif iap then Enum.AnalyticsEconomyTransactionType.IAP.Name
		else Enum.AnalyticsEconomyTransactionType.Gameplay.Name
	call(function()
		service:LogEconomyEvent(
			player,
			if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			math.abs(delta),
			balance,
			transaction,
			reason
		)
	end)
end

-- Gold gained (delta > 0) or spent (delta < 0); `reason` becomes the item SKU ("monster", "upgrade", ...).
function Analytics.gold(player: Player, delta: number, balance: number, reason: string)
	economy(player, "Gold", delta, balance, reason)
end

-- Dragon Shards gained or spent; `shop` marks a premium shop spend (`reason` = the entry key or cosmetic id as SKU).
function Analytics.shards(player: Player, delta: number, balance: number, reason: string, shop: boolean?)
	economy(player, "DragonShards", delta, balance, reason, shop)
end

function Analytics.onboarding(player: Player, step: number, name: string)
	call(function()
		service:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.progression(player: Player, path: string, level: number, name: string?)
	call(function()
		service:LogProgressionCompleteEvent(player, path, level, name)
	end)
end

-- S131: one step of a funnel. AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelSessionId?, step?,
-- stepName?, customFields?) as documented on create.roblox.com (AnalyticsService page); the call is in pcall like every
-- other, so a different signature on Roblox's side never breaks the game.
function Analytics.funnel(player: Player, funnel: string, sessionId: string, step: number, stepName: string)
	call(function()
		service:LogFunnelStepEvent(player, funnel, sessionId, step, stepName)
	end)
end

function Analytics.custom(player: Player, name: string, value: number?)
	call(function()
		service:LogCustomEvent(player, name, value or 1)
	end)
end

return Analytics
