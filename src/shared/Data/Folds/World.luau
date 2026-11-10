--!strict
-- Fold defaults of the world and social windows (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Owner 2026-11-10 ("bardzo dużo napisów, niektóre rzeczy zasłaniają inne,
-- nic się nie zwija"), UI plan package E: what a phone needs room for folds there, what is history folds everywhere.
return table.freeze({
	-- the rankings' podium of the first three (RankingsWindow): a phone keeps its rows
	rankPodium = { pc = true, phone = false },
	-- the bestiary's regions (AchievementsWindow/BestiaryTab): folded, the header names the chosen region
	bestiaryRegions = { pc = true, phone = false },
	-- the hunting contracts' block over the board's tabs (QuestBoard)
	boardHunt = { pc = true, phone = false },
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
