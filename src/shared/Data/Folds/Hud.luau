--!strict
-- Fold defaults of the HUD (Data/Folds, Logic/SectionFold): section id -> open by default, true / false or
-- { pc = ..., phone = ... }. Owner 2026-11-10 ("too much text, things covering each other, nothing folds"; UI plan
-- package A): the event panels fold to their header line (Hud/PanelHeader: the name and one key value); open on PC and
-- a tablet, folded on a phone, whose stack has one 52-px line for each. They replace the world boss panel's fold kept
-- for the session and the tourney panel's touch-only fold. A panel the column has no room for folds without these
-- (Logic/HudStack.place). The quest tracker's groups and the Elite II group keep their own setting (Logic/TrackerFold).
return table.freeze({
	hudWorldBoss = { pc = true, phone = false }, -- Hud/WorldBossPanel
	hudWorldEvent = { pc = true, phone = false }, -- Hud/WorldEventPanel
	hudBloodMoon = { pc = true, phone = false }, -- Hud/BloodMoonPanel
	hudTourney = { pc = true, phone = false }, -- Hud/TourneyPanel
	hudArena = { pc = true, phone = false }, -- Hud/ArenaPanel's queue pill and Hud/ArenaTeams
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
