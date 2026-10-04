--!strict
-- Potions (DESIGN §9), teleport stones and scrolls (§13), gathering tools (§12).
-- Potions work since S04; stones and scrolls are defined now and become usable in S06–S07.

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
-- Scrolls (S06–S07)
other("scroll_protection", "scroll", "scroll", "📜", "#4FD16B", 200, nil, { kind = "scroll", target = "protection" })
other("scroll_oblivion", "scroll", "scroll", "📜", "#C9A45C", 1, nil, { kind = "scroll", target = "oblivion" })
other("scroll_skillreset", "scroll", "scroll", "📜", "#4A8FE7", 1, nil, { kind = "scroll", target = "skillreset" })
other("scroll_unbind", "scroll", "scroll", "📜", "#E8C25A", 500, nil, { kind = "scroll", target = "unbind" })
-- Gathering tools (S07)
other("pickaxe", "tool", "tool", "⛏", "#8E8E93", 25, 100, { kind = "none" }, false)
other("fishing_rod", "tool", "tool", "🎣", "#8A6B4A", 25, 100, { kind = "none" }, false)

return LIST
