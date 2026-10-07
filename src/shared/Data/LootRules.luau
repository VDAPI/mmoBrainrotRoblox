--!strict
-- Drop rules shared by Logic/ItemRoll and Logic/Loot (S32, DESIGN §5.5). Data only.

return table.freeze({
	-- Item level of a drop = base level - 0..dropLevelBelow (never above the monster's own level, so drops at the
	-- player's level can always be worn).
	dropLevelBelow = 2,
})
