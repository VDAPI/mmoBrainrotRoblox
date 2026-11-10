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
	-- the quest journal (QuestJournal): the story so far (up to 70 rows) and the finished side arcs
	journalHistory = false,
	journalArcsDone = false,
	-- the world map (WorldMap): the band legend over the map (a phone's map keeps its room: folded, it is one
	-- "Legenda" line) and an NPC card's shop list
	mapLegend = { pc = true, phone = false },
	mapShop = false,
	-- the guild window (GuildWindow): the guild's chronicle, the banner pickers and the ranks' rights table
	guildLog = false,
	guildBanner = false,
	guildRights = false,
	-- UI package C's adoption: how guild EXP is earned (GuildWindow/Goals) and the Blood Moon's rules and rewards
	-- (BloodMoonWindow), titled parts that were folded for the session only (Components/Details)
	guildSources = false,
	bloodMoonRules = false,
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
