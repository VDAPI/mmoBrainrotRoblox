--!strict
-- Potions (DESIGN §9), teleport stones and scrolls (§13), gathering tools (§12).
-- Potions work since S04; stones and scrolls are defined now and become usable in S06–S07.

local Blessings = require("../Blessings")
local Types = require("./Types")

local LIST: { Types.ItemDef } = {}

-- Five qualities: Small, Medium, Large, Great, Mighty.
local HP_MANA = { 150, 500, 1500, 4000, 10000 }
-- S158: Small energy 30 -> 40 (40 % of the level-1 pool of 101); the others already give 50 % or more of the pool
-- where their tier starts (Medium ~115, Large ~130, Great 145 at 45, Mighty 170 at 70)
local ENERGY = { 40, 60, 100, 150, 250 }
-- S93: the Great potion 900 -> 700 (gold per HP 0.175 between the Large 0.167 and the Mighty 0.30). S94: the Mighty
-- 3000 -> 1800 (0.18 per HP, just above the Great: chain potions 71-99 as low as the price order allows)
local PRICES = { 10, 60, 250, 700, 1800 }
-- S87 (balance plan D3): Great from 45, Mighty from 70 (HP, mana and energy alike; Logic/Potions.requiredLevel).
local LEVELS = { 1, 1, 1, 45, 70 }

local POTIONS: { { resource: "hp" | "mana" | "energy", color: string, amounts: { number } } } = {
	{ resource = "hp", color = "#C2352E", amounts = HP_MANA },
	{ resource = "mana", color = "#3D6FD6", amounts = HP_MANA },
	{ resource = "energy", color = "#D9B23A", amounts = ENERGY },
}

for _, potion in POTIONS do
	for quality = 1, 5 do
		local id = `potion_{potion.resource}_{quality}`
		table.insert(LIST, {
			id = id,
			category = "consumable",
			type = `potion_{potion.resource}`,
			level = LEVELS[quality],
			tier = quality,
			stackable = true,
			maxStack = 999,
			nameKey = `item.{id}.name`,
			icon = { glyph = "⚗", color = potion.color },
			price = math.max(1, math.floor(PRICES[quality] / 4)),
			buyPrice = PRICES[quality],
			use = { kind = "potion", resource = potion.resource, amount = potion.amounts[quality] },
		})
	end
end

-- S122 (DESIGN-17 §3): Elixir of Wholeness, sold only in the premium shop (Data/Products potion_full_5 / _20).
-- Account-bound from the moment it is created (ItemRoll.makeStack binds `bindOnPickup` stacks), never sold, traded
-- or listed. Rules: Config.FullElixir, Logic/FullElixir, Logic/UseBlocks.
table.insert(LIST, {
	id = "potion_full",
	category = "consumable",
	type = "potion_full", -- icon pot/<tier> through Logic/ItemIcons (S118: own PNG when the owner adds one)
	level = 1,
	tier = 5,
	stackable = true,
	maxStack = 999,
	nameKey = "item.potion_full.name",
	descKey = "item.potion_full.desc",
	icon = { glyph = "⚗", color = "#E8C25A" },
	price = 1,
	bindOnPickup = true,
	noSell = true,
	use = { kind = "fullElixir" },
})

local function other(
	id: string,
	category: Types.Category,
	kind: string,
	glyph: string,
	color: string,
	price: number,
	buyPrice: number?,
	use: Types.UseEffect?,
	stackable: boolean?
)
	table.insert(LIST, {
		id = id,
		category = category,
		type = kind,
		level = 1,
		stackable = stackable ~= false,
		maxStack = if stackable == false then 1 else 999,
		nameKey = `item.{id}.name`,
		descKey = `item.{id}.desc`,
		icon = { glyph = glyph, color = color },
		price = price,
		buyPrice = buyPrice,
		use = use,
	})
end

-- Teleport stones (S07)
other("stone_return", "stone", "stone", "◈", "#4A8FE7", 5, 20, { kind = "teleport", target = "city" })
other("stone_map", "stone", "stone", "◈", "#B455FF", 50, 200, { kind = "teleport", target = "map" })
other("stone_dungeon", "stone", "stone", "◈", "#D64A3E", 150, 600, { kind = "teleport", target = "dungeon" })
-- One stone per boss dungeon (alchemist, S07): teleports in front of that dungeon's entrance.
for _, region in { "meadows", "duskwood", "ashen", "frostpeak" } do
	other(`stone_dungeon_{region}`, "stone", "stone", "◈", "#D64A3E", 150, nil, {
		kind = "teleport",
		target = `dungeon:{region}`,
	})
end
-- Scrolls (S06–S07)
other("scroll_protection", "scroll", "scroll", "📜", "#4FD16B", 200, nil, { kind = "scroll", target = "protection" })
-- S31: the reset scrolls are worth 100 (bought for 500 / 400 x level, so selling never pays off).
other("scroll_oblivion", "scroll", "scroll", "📜", "#C9A45C", 100, nil, { kind = "scroll", target = "oblivion" })
other("scroll_skillreset", "scroll", "scroll", "📜", "#4A8FE7", 100, nil, { kind = "scroll", target = "skillreset" })
other("scroll_unbind", "scroll", "scroll", "📜", "#E8C25A", 500, nil, { kind = "scroll", target = "unbind" })
-- S134d: Scroll of the Hunt, only from bosses (Data/LootTables.BOSSES): Auto Hunt time into the bank. Bound from
-- creation and never sold (nobody buys hunting time for gold or sells it), in no shop (tests/paywall.spec).
other("scroll_hunt", "scroll", "scroll", "📜", "#B5452E", 1, nil, { kind = "autoGrind" })
do
	local hunt = LIST[#LIST] :: any
	hunt.bindOnPickup = true
	hunt.noSell = true
end
-- S134j: Stone of Transmutation, sold only in the premium shop (Data/Products reroll_stone, 1 a day): the blacksmith
-- takes it instead of the essence of one bonus reroll (gold always, Logic/Reroll.costWithStone). Account-bound from
-- creation (ItemRoll.makeStack binds `bindOnPickup` stacks), never sold, traded, mailed or listed; no material (no
-- dismantling, transmutation or upgrade use). Using it from the backpack only explains it (ScrollService).
other("reroll_stone", "scroll", "scroll", "◈", "#E8C25A", 1, nil, { kind = "scroll", target = "transmute" })
do
	local stone = LIST[#LIST] :: any
	stone.bindOnPickup = true
	stone.noSell = true
end
-- S156 (owner 2026-10-20): Scroll of Transformation, sold only in the premium shop (Data/Products transmute_scroll, 1 a
-- day): the blacksmith rerolls every regular line of one item at once with it (Logic/Reroll.rollAll, gold x
-- Config.Reroll.allGoldMul, no essence). Bound and never sold like the stone; no material.
other("transmute_scroll", "scroll", "scroll", "📜", "#B07CFF", 1, nil, { kind = "scroll", target = "transmuteAll" })
do
	local scroll = LIST[#LIST] :: any
	scroll.bindOnPickup = true
	scroll.noSell = true
end
-- Gathering tools (S07)
other("pickaxe", "tool", "tool", "⛏", "#8E8E93", 25, 100, { kind = "none" }, false)
other("fishing_rod", "tool", "tool", "🎣", "#8A6B4A", 25, 100, { kind = "none" }, false)

-- Blessings (DESIGN §11): one item per line and rarity; using it starts the 1 h blessing.
local BLESSING_COLORS: { [string]: string } = {
	warrior = "#C0503C",
	hunter = "#4FA35A",
	sage = "#4A8FE7",
	guardian = "#8E96A3",
	fortune = "#E8C25A",
}
for _, blessing in Blessings.list do
	table.insert(LIST, {
		id = blessing.itemId,
		category = "consumable",
		type = "blessing",
		level = 1,
		tier = blessing.rarity,
		rarity = blessing.rarity,
		stackable = true,
		maxStack = 999,
		nameKey = blessing.nameKey,
		icon = { glyph = "✶", color = BLESSING_COLORS[blessing.line] or "#E8C25A" },
		price = 20 * blessing.rarity * blessing.rarity,
		use = { kind = "blessing", target = blessing.id },
	})
end

-- Resistance elixirs (DESIGN §10): 1 h, +15 % resistance to one element.
local ELIXIR_COLORS = { resFire = "#FF7A1A", resIce = "#9FE0FF", resLightning = "#F2E85A", resPoison = "#7ACB3A" }
for _, stat in Blessings.ELIXIRS do
	local id = `elixir_{stat}`
	table.insert(LIST, {
		id = id,
		category = "consumable",
		type = "elixir",
		level = 1,
		stackable = true,
		maxStack = 999,
		nameKey = `item.{id}.name`,
		icon = { glyph = "⚱", color = ELIXIR_COLORS[stat] },
		price = 60,
		use = { kind = "elixir", target = stat },
	})
end

return LIST
