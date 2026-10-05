--!strict
-- Rebindable keys (S17). Key names are Enum.KeyCode names, so this table works in Lune too. The player's
-- overrides live in account.settings.keys (action -> key name); Logic/Keybinds resolves and validates them.

export type Action = {
	id: string,
	default: string,
	labelKey: string,
	group: "windows" | "combat" | "world",
}

local actions: { Action } = {
	{ id = "win_character", default = "C", labelKey = "hud.menu.character", group = "windows" },
	{ id = "win_inventory", default = "B", labelKey = "hud.menu.inventory", group = "windows" },
	{ id = "win_skills", default = "K", labelKey = "hud.menu.skills", group = "windows" },
	{ id = "win_map", default = "M", labelKey = "hud.menu.map", group = "windows" },
	{ id = "win_quests", default = "L", labelKey = "hud.menu.quests", group = "windows" },
	{ id = "win_guild", default = "G", labelKey = "hud.menu.guild", group = "windows" },
	{ id = "win_party", default = "P", labelKey = "hud.menu.party", group = "windows" },
	{ id = "skill_1", default = "One", labelKey = "keys.skill.1", group = "combat" },
	{ id = "skill_2", default = "Two", labelKey = "keys.skill.2", group = "combat" },
	{ id = "skill_3", default = "Three", labelKey = "keys.skill.3", group = "combat" },
	{ id = "skill_4", default = "Four", labelKey = "keys.skill.4", group = "combat" },
	{ id = "skill_5", default = "Five", labelKey = "keys.skill.5", group = "combat" },
	{ id = "skill_6", default = "Six", labelKey = "keys.skill.6", group = "combat" },
	{ id = "skill_7", default = "Seven", labelKey = "keys.skill.7", group = "combat" },
	{ id = "skill_8", default = "Eight", labelKey = "keys.skill.8", group = "combat" },
	{ id = "skill_9", default = "Nine", labelKey = "keys.skill.9", group = "combat" },
	{ id = "skill_10", default = "Zero", labelKey = "keys.skill.10", group = "combat" },
	{ id = "potion_hp", default = "Z", labelKey = "keys.potion.hp", group = "combat" },
	{ id = "potion_mana", default = "X", labelKey = "keys.potion.mana", group = "combat" },
	{ id = "potion_energy", default = "V", labelKey = "keys.potion.energy", group = "combat" },
	{ id = "target_next", default = "Tab", labelKey = "menu.keys.target", group = "combat" },
	{ id = "target_clear", default = "Q", labelKey = "keys.target.clear", group = "combat" },
	{ id = "sprint", default = "LeftControl", labelKey = "keys.sprint", group = "world" },
	{ id = "interact", default = "E", labelKey = "keys.interact", group = "world" },
	{ id = "pickup", default = "F", labelKey = "keys.pickup", group = "world" },
}

-- Keys a player may bind. Movement (WASD, arrows, Space), camera (I/O, Shift), chat (/), Esc and the
-- Roblox function keys (F9 console, F11 full screen, F12) stay reserved.
local allowed: { [string]: string } = {} -- key name -> short label
for _, letter in string.split("BCEFGHJKLMNPQRTUVXYZ", "") do
	allowed[letter] = letter
end
local digits = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
for i, name in digits do
	allowed[name] = tostring(i - 1)
	allowed[`Keypad{name}`] = `Num{i - 1}`
end
for i = 1, 8 do
	allowed[`F{i}`] = `F{i}`
end
allowed.F10 = "F10"
local symbols: { [string]: string } = {
	Tab = "Tab",
	Minus = "-",
	Equals = "=",
	LeftBracket = "[",
	RightBracket = "]",
	Semicolon = ";",
	Quote = "'",
	Comma = ",",
	Period = ".",
	BackSlash = "\\",
	CapsLock = "Caps",
	LeftControl = "Ctrl",
	LeftAlt = "Alt",
	Backquote = "`",
}
for name, label in symbols do
	allowed[name] = label
end

local byId: { [string]: Action } = {}
for _, action in actions do
	byId[action.id] = action
end

return table.freeze({
	actions = actions,
	allowed = allowed,
	get = function(id: string): Action?
		return byId[id]
	end,
})
