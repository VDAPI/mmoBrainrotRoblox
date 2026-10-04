--!strict
-- Gamepasses and developer products (DESIGN §21). S02 only needs the gamepass check API; real
-- MarketplaceService wiring (pass ids, ProcessReceipt, prompts) lands in S14. Until then no player owns
-- any pass, except when an admin grants one for testing with /pass <id> (in-memory, per server).

local MonetizationService = {
	Name = "MonetizationService",
}

export type PassId = "fastRespawn" | "autoLoot" | "vault" | "vip"

local granted: { [Player]: { [string]: boolean } } = {}

function MonetizationService.HasPass(player: Player, passId: PassId): boolean
	local passes = granted[player]
	return passes ~= nil and passes[passId] == true
end

-- Test helper for admin commands.
function MonetizationService.SetTestPass(player: Player, passId: string, owned: boolean)
	local passes = granted[player] or {}
	passes[passId] = if owned then true else nil
	granted[player] = passes
end

function MonetizationService.Start()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		granted[player] = nil
	end)
end

return MonetizationService
