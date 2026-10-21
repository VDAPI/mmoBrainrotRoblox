--!strict
-- S160k (owner 2026-10-21, docs/DESIGN.md §13a): the Portal Master's shop in the capital. Every teleport stone of the
-- game for Dragon Shards: by the piece (`piece`, the ordinary consumable stone, at most MAX_PIECES in one purchase) or
-- forever (`perm`, once per account: account.portalStones[itemId]; every character takes its everlasting copy
-- `permId` from him for free, the copy is never used up, Data/Items/Consumables). Convenience only: the same stones
-- are bought for gold from the alchemist and the merchants (tests/paywall.spec 2e). Rules: Logic/PortalShop.

export type Entry = {
	itemId: string, -- the consumable stone sold by the piece
	permId: string, -- its everlasting copy
	piece: number, -- Dragon Shards for one stone
	perm: number, -- Dragon Shards for the everlasting stone (once per account)
}

local LIST: { Entry } = {
	{ itemId = "stone_return", permId = "stone_return_perm", piece = 5, perm = 300 },
	{ itemId = "stone_map", permId = "stone_map_perm", piece = 10, perm = 600 },
	{ itemId = "stone_dungeon", permId = "stone_dungeon_perm", piece = 15, perm = 600 },
	{ itemId = "stone_dungeon_meadows", permId = "stone_dungeon_meadows_perm", piece = 10, perm = 250 },
	{ itemId = "stone_dungeon_duskwood", permId = "stone_dungeon_duskwood_perm", piece = 10, perm = 250 },
	{ itemId = "stone_dungeon_ashen", permId = "stone_dungeon_ashen_perm", piece = 10, perm = 250 },
	{ itemId = "stone_dungeon_frostpeak", permId = "stone_dungeon_frostpeak_perm", piece = 10, perm = 250 },
}

local byItem: { [string]: Entry } = {}
for _, entry in LIST do
	byItem[entry.itemId] = entry
end

return table.freeze({
	list = LIST,
	byItem = byItem,
	get = function(itemId: string): Entry?
		return byItem[itemId]
	end,
	NPC = "portalmaster", -- the Portal Master (Data/Npcs, service "portalshop")
	MAX_PIECES = 50, -- stones in one purchase by the piece
})
