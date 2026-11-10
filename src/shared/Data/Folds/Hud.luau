--!strict
-- Fold defaults of the HUD (Data/Folds, Logic/SectionFold): section id -> open by default, true / false or
-- { pc = ..., phone = ... }. Empty until package A of the UI plan (owner 2026-11-10, the HUD) folds the event panels
-- (world boss, world event, Blood Moon, tourney, arena) to one line here; the quest tracker's groups keep their own
-- setting (Logic/TrackerFold).
return table.freeze({} :: { [string]: boolean | { pc: boolean, phone: boolean } })
