--!strict
-- Shop and VIP funnels (S131, DESIGN-17 §9): a module like Analytics (not a service), so MonetizationService and
-- PremiumShopService report steps without a dependency. Per player the pure state of Logic/ShopFunnel; a step to log
-- goes to Analytics.funnel with the session id "<userId>_<n>". MonetizationService clears a player on leave and
-- handles the PremiumFunnel remote (client steps only from ShopFunnel.CLIENT_STEPS).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Analytics)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local ShopFunnel = require(Shared.Logic.ShopFunnel)

local PremiumFunnel = {}

local states: { [Player]: ShopFunnel.State } = {}

-- Logs `stepName` of `funnel` for the player when it is new in the current funnel session.
function PremiumFunnel.step(player: Player, funnel: string, stepName: string)
	local step, nextState = ShopFunnel.track(
		states[player] or ShopFunnel.empty(),
		funnel,
		stepName,
		Clock.now(),
		Config.ShopFunnel.sessionTimeout
	)
	if step == nil then
		return
	end
	states[player] = nextState
	Analytics.funnel(player, funnel, `{player.UserId}_{ShopFunnel.sessionId(nextState, funnel)}`, step, stepName)
end

-- A step reported by the client (the PremiumFunnel remote): only the allowed ones, the rest is ignored.
function PremiumFunnel.fromClient(player: Player, funnel: string, stepName: string)
	if ShopFunnel.clientAllowed(funnel, stepName) then
		PremiumFunnel.step(player, funnel, stepName)
	end
end

function PremiumFunnel.clear(player: Player)
	states[player] = nil
end

return PremiumFunnel
