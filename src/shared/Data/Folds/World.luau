--!strict
-- Fold defaults of the world and social windows (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Empty until package E of the UI plan (owner 2026-11-10: the journal, the
-- map, the guild, the quest board, the rankings, the bestiary) adds its sections here.
return table.freeze({} :: { [string]: boolean | { pc: boolean, phone: boolean } })
