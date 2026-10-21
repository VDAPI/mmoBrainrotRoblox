--!strict
-- S160k (owner 2026-10-21): the Portal Master (Data/PortalShop, Logic/PortalShop). Every teleport stone of the game is
-- sold by the piece and forever; the everlasting copy keeps its stone's target and is never used up; the purchase rule
-- refuses bad amounts, a second "forever", a claim without the purchase or while holding a copy, and too few shards.

local Data = require("../src/shared/Data/PortalShop")
local Items = require("../src/shared/Data/Items")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Npcs = require("../src/shared/Data/Npcs")
local PortalShop = require("../src/shared/Logic/PortalShop")
local T = require("./Test")

local function account(shards: number, owned: { [string]: boolean }?): PortalShop.Account
	return { dragonShards = shards, portalStones = owned or {} }
end

T.describe("Portal Master (S160k)", function()
	T.it("sells every teleport stone of the game, each with an everlasting copy of the same target", function()
		local sold: { [string]: boolean } = {}
		for _, entry in Data.list do
			sold[entry.itemId] = true
			local stone = Items.get(entry.itemId) :: any
			local perm = Items.get(entry.permId) :: any
			T.expect({ entry.itemId, stone.use.kind, perm.use.kind }).toEqual({ entry.itemId, "teleport", "teleport" })
			T.expect({ entry.itemId, perm.use.target }).toEqual({ entry.itemId, stone.use.target })
			T.expect({ entry.permId, perm.use.keep, stone.use.keep }).toEqual({ entry.permId, true, nil })
			T.expect({ entry.permId, perm.bindOnPickup, perm.noSell }).toEqual({ entry.permId, true, true })
			T.expect(ItemRoll.makeStack(entry.permId, 1, "p").bound).toBe(true)
			T.expect(ItemValue.canSell(ItemRoll.makeStack(entry.permId, 1, "p"), perm)).toBe(false)
			T.expect(entry.piece > 0 and entry.perm > entry.piece).toBe(true)
		end
		for id, def in Items.byId do
			local use = (def :: any).use
			if use and use.kind == "teleport" and not use.keep then
				T.expect({ id, sold[id] }).toEqual({ id, true })
			end
		end
	end)

	T.it("stands in the capital and offers the shop", function()
		local npc = Npcs.get(Data.NPC) :: any
		T.expect(npc ~= nil).toBe(true)
		T.expect(npc.map).toBe("city")
		T.expect(table.find(npc.services, "portalshop") ~= nil).toBe(true)
	end)

	T.it("checks amounts, ownership and shards", function()
		local entry = Data.list[1]
		T.expect({ PortalShop.canBuy(nil, "piece", 1, account(1000)) }).toEqual({ false, "error.badRequest" })
		T.expect({ PortalShop.canBuy(entry, "piece", 0, account(1000)) }).toEqual({ false, "error.badRequest" })
		T.expect({ PortalShop.canBuy(entry, "piece", 1.5, account(1000)) }).toEqual({ false, "error.badRequest" })
		T.expect({ PortalShop.canBuy(entry, "piece", Data.MAX_PIECES + 1, account(100000)) }).toEqual({
			false,
			"error.badRequest",
		})
		T.expect({ PortalShop.canBuy(entry, "gift", 1, account(1000)) }).toEqual({ false, "error.badRequest" })
		T.expect({ PortalShop.canBuy(entry, "piece", 10, account(entry.piece * 10)) }).toEqual({ true, nil })
		T.expect({ PortalShop.canBuy(entry, "piece", 10, account(entry.piece * 10 - 1)) }).toEqual({
			false,
			"premium.error.shards",
		})
		T.expect({ PortalShop.canBuy(entry, "perm", 1, account(entry.perm)) }).toEqual({ true, nil })
		T.expect({ PortalShop.canBuy(entry, "perm", 1, account(entry.perm - 1)) }).toEqual({
			false,
			"premium.error.shards",
		})
		local owner = account(100000, { [entry.itemId] = true })
		T.expect({ PortalShop.canBuy(entry, "perm", 1, owner) }).toEqual({ false, "portalshop.error.owned" })
		T.expect({ PortalShop.canBuy(entry, "claim", 1, account(0)) }).toEqual({ false, "portalshop.error.notOwned" })
		T.expect({ PortalShop.canBuy(entry, "claim", 1, account(0, { [entry.itemId] = true }), 0) }).toEqual({
			true,
			nil,
		})
		T.expect({ PortalShop.canBuy(entry, "claim", 1, owner, 1) }).toEqual({ false, "portalshop.error.have" })
		-- buying by the piece stays open to an owner (a spare for another character's backpack)
		T.expect({ PortalShop.canBuy(entry, "piece", 1, owner) }).toEqual({ true, nil })
		T.expect(PortalShop.price(entry, "piece", 3)).toBe(entry.piece * 3)
		T.expect(PortalShop.price(entry, "claim", 1)).toBe(0)
		T.expect(PortalShop.owned({ portalStones = "junk" }, entry.itemId)).toBe(false)
	end)
end)
