--!strict
-- Fold defaults of the game menu and the settings (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Empty until package E of the UI plan (owner 2026-11-10) turns the settings
-- groups, folded today for the session only (Components/Details), into sections saved on the account.
return table.freeze({} :: { [string]: boolean | { pc: boolean, phone: boolean } })
