--!strict
-- Potions (DESIGN §9), teleport stones and scrolls (§13), gathering tools (§12).
-- Potions work since S04; stones and scrolls are defined now and become usable in S06–S07.

local Blessings = require("../Blessings")
local Types = require("./Types")

local LIST: { Types.ItemDef } = {}

-- Five qualities: Small, Medium, Large, Great, Mighty.
local HP_MANA = { 150, 500, 1500, 4000, 10000 }
local ENERGY = { 30, 60, 100, 150, 250 }
local PRICES = { 10, 60, 250, 900, 3000 }

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
			level = 1,
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
