--!strict
-- Item value constants (S31, DESIGN §5, §18). One "value" per item instance: merchants pay it, NPC shops sell
-- for value x buyMul. Formula lives in Logic/ItemValue; S32 balance may change these numbers, not the formula.

return table.freeze({
	-- Equipment: round(perLevel x ilvl x sellMul² x slotMul x (1 + upgradePerLevel x up)).
	-- A Common item of level L is worth about the gold of two kills at that level.
	perLevel = 6,
	upgradePerLevel = 0.1,
	slotMul = table.freeze({
		weapon = 1.0,
		offhand = 0.8,
		helmet = 0.8,
		armor = 0.8,
		gloves = 0.8,
		boots = 0.8,
		necklace = 0.7,
		ring = 0.7,
		talisman = 0.7,
	}) :: { [string]: number },
	defaultSlotMul = 0.8,
	-- Blacksmith crafting gold = the Common item's value x craftMul (S32; the player also brings the ore). Before:
	-- priceAt(tier) x 3, e.g. 6120 for a tier 55 weapon the weapon merchant sells for 1320.
	craftMul = 3,
	-- NPC shops sell at value x buyMul unless the entry has a fixed price (DESIGN §8a: about 4x).
	buyMul = 4,
	minValue = 1,
})
