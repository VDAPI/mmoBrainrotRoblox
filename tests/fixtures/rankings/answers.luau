--!strict
-- Open Cloud answers for tests/rankingsfetch.spec (S125), already decoded from JSON. Scores are encoded like the game:
-- level 63 at half of the level = 63 x 10^10 + 5 x 10^8; level 100 reached at 1791763200 = 100 x 10^10 + (10^10 - 1 -
-- 1791763200); guild score 300 founded at 1700000000 = 300 x 10^10 + (10^10 - 1 - 1700000000).

return {
	ordered = {
		level = {
			orderedDataStoreEntries = {
				{ id = "111_1", value = 1008208236799, path = "x" },
				{ id = "222_2", value = 630500000000, path = "x" },
				{ id = "333_1", value = 500000000000, path = "x" }, -- no metadata: dropped
				{ id = "444_1", value = 400000000000, path = "x" }, -- deleted marker: dropped
			},
		},
		guild = {
			orderedDataStoreEntries = {
				{ id = "g_abc", value = 3008299999999, path = "x" },
			},
		},
	},
	meta = {
		["111_1"] = { value = { n = "Aria", c = "Mage", g = "ORD", l = 100, u = 111, t = 5 } },
		["222_2"] = { value = { n = "Borin", c = "Warrior", l = 63, u = 222, t = 5 } },
		["444_1"] = { value = { n = "", t = 5, d = true } },
		["g_abc"] = { value = { n = "Order", g = "ORD", l = 100, m = 12, t = 5 } },
	},
	-- weekly bracket 3 (levels 45-69)
	sorted3 = {
		memoryStoreSortedMapItems = {
			{
				id = "222_2",
				value = { s = 5400, m = { n = "Borin", c = "Warrior", l = 63, u = 222, t = 5 }, cid = "c2" },
			},
			{
				id = "555_1",
				value = { s = 7000, m = { n = "Cyra", c = "Hunter", g = "ORD", l = 50, u = 555, t = 5 }, cid = "c5" },
			},
			{ id = "666_1", value = { s = 100, cid = "c6" } }, -- no metadata: dropped
		},
	},
	hofMage = {
		value = { entries = { { k = "111_1", n = "Aria", c = "Mage", u = 111, at = 1791763200 + 3700, cid = "c1" } } },
	},
}
