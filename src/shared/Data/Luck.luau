--!strict
-- Luck fields and caps (docs/ROZWOJ.md 6.3). Path nodes give these fields (PathNode.luck = { [field] = valueKey },
-- the value in node.values); Logic/Luck caps every field and takes the best value in the group.
export type FieldDef = { cap: number, scope: string } -- scope: "monster" | "boss"

return table.freeze({
	-- One cap for every source of item chance on monsters: items, blessing, guild (dropBonus) and Fortune, in %.
	monsterItemCap = 100,
	fields = table.freeze({
		monsterItem = { cap = 100, scope = "monster" }, -- % item chance, inside monsterItemCap with dropBonus
		elite2 = { cap = 20, scope = "monster" }, -- % of the Legendary weight of Elite II (5 -> 6)
		gold = { cap = 15, scope = "monster" }, -- % monster gold, added to goldBonus (outside monsterItemCap)
		bossLegendary = { cap = 13, scope = "boss" }, -- points of the Legendary multiplier: 13 = x1.13
		bossUpgrade = { cap = 50, scope = "boss" }, -- % chance that a winner's Unique boss item becomes Heroic
		bossExtra = { cap = 25, scope = "boss" }, -- % chance of a second Unique / Heroic boss item
	}) :: { [string]: FieldDef },
	order = table.freeze({ "monsterItem", "elite2", "gold", "bossLegendary", "bossUpgrade", "bossExtra" }),
})
