--!strict
-- Fold defaults of the game menu and the settings (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Owner 2026-11-10 (UI plan package E): the settings groups, folded until
-- then for the session only (Components/Details), are sections saved on the account (UI/Screens/GameMenu).
return table.freeze({
	-- what is changed often stands open
	setSound = true,
	setGraphics = true,
	setCombat = true,
	setUi = true,
	-- the rare ones folded (the hotkeys are not shown on touch at all)
	setLoot = false,
	setSocial = false,
	setKeys = false,
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
