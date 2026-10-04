--!strict
-- Roblox AnalyticsService wrapper (S14). Never throws and never yields the caller.
--   gold / shards : economy sources and sinks (LogEconomyEvent)
--   onboarding    : tutorial funnel steps (LogOnboardingFunnelStepEvent)
--   progression   : levels and bosses (LogProgressionCompleteEvent)
--   custom        : legendary drops, +7..+9 upgrades, premium purchases (LogCustomEvent)
-- A module, not a service, so any service can report without a dependency.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local service: any = AnalyticsService

local function call(fn: () -> ())
	task.spawn(function()
		pcall(fn)
	end)
end

local function economy(player: Player, currency: string, delta: number, balance: number, reason: string)
	if delta == 0 then
		return
	end
	local source = delta > 0
	local transaction = if reason == "shop" or reason == "premium"
		then Enum.AnalyticsEconomyTransactionType.Shop.Name
		elseif string.sub(reason, 1, 7) == "shards_" then Enum.AnalyticsEconomyTransactionType.IAP.Name
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

function Analytics.shards(player: Player, delta: number, balance: number, reason: string)
	economy(player, "DragonShards", delta, balance, reason)
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

function Analytics.custom(player: Player, name: string, value: number?)
	call(function()
		service:LogCustomEvent(player, name, value or 1)
	end)
end

return Analytics
