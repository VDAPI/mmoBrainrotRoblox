--!strict
-- Boss tuning constants outside Data/Bosses (S87, balance plan D3). Data only; read by Entities/Boss,
-- BossScripts and the balance model. Not exported to the wiki: the scripts' "local NAME = number" lines stay
-- the wiki's source (tools/WikiData/Bosses.scriptConsts).

return table.freeze({
	-- Seconds between two attacks of any kind (Entities/Boss.Step).
	globalGap = 2.2,
	-- Scripted hazards by boss and hazard id: damage as a multiple of the boss attack, like any attack.
	hazards = table.freeze({
		azgor = table.freeze({ lava = 0.7 }),
		vaelgrath = table.freeze({ freezingStorm = 1.4 }),
	}),
})
