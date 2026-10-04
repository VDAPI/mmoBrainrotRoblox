--!strict
-- Materials (DESIGN §6–§12): essences for upgrades, ores, herbs, fish and monster parts. Stack to 999.

local Types = require("./Types")

local LIST: { Types.ItemDef } = {}

local function material(id: string, kind: string, level: number, price: number, glyph: string, color: string)
	table.insert(LIST, {
		id = id,
		category = "material",
		type = kind,
		level = 1,
		tier = level,
		stackable = true,
		maxStack = 999,
		nameKey = `item.{id}.name`,
		descKey = `item.{id}.desc`,
		icon = { glyph = glyph, color = color },
		price = price,
	})
end

-- Upgrade essences (DESIGN §6–§7)
material("essence_dust", "essence", 1, 8, "✶", "#9FB6C9")
material("essence_shard", "essence", 20, 60, "✷", "#4A8FE7")
material("essence_crystal", "essence", 45, 300, "✸", "#B455FF")
material("legend_core", "essence", 60, 2500, "✹", "#FF9F1C")

-- Ores (DESIGN §12): Copper .. Adamantite by zone
material("ore_copper", "ore", 1, 6, "⬢", "#B87333")
material("ore_iron", "ore", 20, 15, "⬢", "#8E8E93")
material("ore_silver", "ore", 45, 35, "⬢", "#D8D8E0")
material("ore_mithril", "ore", 70, 80, "⬢", "#7FD4E8")
material("ore_adamantite", "ore", 90, 160, "⬢", "#5A3F7A")

-- Herbs
material("herb_meadowsweet", "herb", 1, 5, "❀", "#E8E4B0")
material("herb_nightshade", "herb", 20, 12, "❀", "#6B4A9A")
material("herb_firebloom", "herb", 45, 28, "❀", "#FF7A1A")
material("herb_frostleaf", "herb", 70, 60, "❀", "#9FE0FF")
material("herb_moonpetal", "herb", 30, 120, "❀", "#E8E8FF")

-- Fish
material("fish_carp", "fish", 1, 6, "≈", "#B89B5A")
material("fish_pike", "fish", 10, 14, "≈", "#6F8F5A")
material("fish_eel", "fish", 20, 24, "≈", "#4A5A3A")
material("fish_magmafin", "fish", 45, 55, "≈", "#D6542A")
material("fish_icefin", "fish", 70, 110, "≈", "#9FD0F0")
material("fish_goldfin", "fish", 30, 300, "≈", "#E8C25A")

-- Monster parts (1–2 per region and more for flavour)
material("wolf_pelt", "part", 1, 4, "✾", "#8E8E8E")
material("boar_tusk", "part", 5, 7, "✾", "#E8DCC8")
material("spider_silk", "part", 14, 12, "✾", "#D8D2E8")
material("goblin_ear", "part", 13, 10, "✾", "#5E8C3A")
material("werewolf_claw", "part", 20, 22, "✾", "#5A4636")
material("ectoplasm", "part", 35, 30, "✾", "#9FE0C9")
material("salamander_scale", "part", 45, 45, "✾", "#D6542A")
material("magma_shard", "part", 60, 60, "✾", "#FF5A1A")
material("yeti_fur", "part", 70, 80, "✾", "#EEF3F7")
material("frost_scale", "part", 90, 120, "✾", "#7FD4E8")

return LIST
