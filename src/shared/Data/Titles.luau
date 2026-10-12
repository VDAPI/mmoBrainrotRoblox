--!strict
-- Character titles (S16): shown above the name on the nameplate. Each one unlocks from a milestone the
-- character data already tracks. Names: title.<id> (Localization). Order = display order in the picker.
-- S59 (ROZWOJ 3.1, 16.7): path titles have the id path_<pathId> (= PathDef.titleId), the name key title.path_<pathId>
-- and req = { kind = "mainPath", path = "<pathId>" }; a class session adds them together with its PathDef, at the
-- end of the list, e.g. id path_healer, req { kind = "mainPath", path = "healer" }, color "#8FE0B8". Unpublished
-- paths hide them on the wiki (tools/WikiData/Visibility).

export type Requirement =
	{ kind: "level", value: number }
	| { kind: "pvpKills", value: number }
	| { kind: "duelsWon", value: number }
	| { kind: "mainDone", value: number }
	| { kind: "mainPath", path: string } -- S59: unlocked while the active set's main path is this path id

export type TitleDef = {
	id: string,
	nameKey: string,
	req: Requirement,
	color: string, -- hex, how the title is drawn on the nameplate
}

local list: { TitleDef } = {
	{ id = "wanderer", nameKey = "title.wanderer", req = { kind = "level", value = 10 }, color = "#CFC6B0" },
	{ id = "adventurer", nameKey = "title.adventurer", req = { kind = "level", value = 25 }, color = "#9FD18B" },
	{ id = "veteran", nameKey = "title.veteran", req = { kind = "level", value = 50 }, color = "#7FB8FF" },
	{ id = "champion", nameKey = "title.champion", req = { kind = "level", value = 75 }, color = "#C77BFF" },
	{ id = "legend", nameKey = "title.legend", req = { kind = "level", value = 100 }, color = "#FF9F1C" },
	{ id = "sentinel", nameKey = "title.sentinel", req = { kind = "mainDone", value = 10 }, color = "#E8D9A8" },
	{ id = "dragonbane", nameKey = "title.dragonbane", req = { kind = "mainDone", value = 32 }, color = "#FF6B4A" },
	{ id = "duelist", nameKey = "title.duelist", req = { kind = "duelsWon", value = 10 }, color = "#E8E25A" },
	{ id = "gladiator", nameKey = "title.gladiator", req = { kind = "duelsWon", value = 50 }, color = "#FFD36B" },
	{ id = "bloodied", nameKey = "title.bloodied", req = { kind = "pvpKills", value = 10 }, color = "#E05A4A" },
	{ id = "warlord", nameKey = "title.warlord", req = { kind = "pvpKills", value = 100 }, color = "#B8322A" },
	-- S71: Cleric paths
	{
		id = "path_healer",
		nameKey = "title.path_healer",
		req = { kind = "mainPath", path = "healer" },
		color = "#8FE0B8",
	},
	{
		id = "path_fortune",
		nameKey = "title.path_fortune",
		req = { kind = "mainPath", path = "fortune" },
		color = "#E8C25A",
	},
	{
		id = "path_inquisitor",
		nameKey = "title.path_inquisitor",
		req = { kind = "mainPath", path = "inquisitor" },
		color = "#D8E6F3",
	},
	-- S75: Warrior paths
	{
		id = "path_guardian",
		nameKey = "title.path_guardian",
		req = { kind = "mainPath", path = "guardian" },
		color = "#A9B8C6",
	},
	{
		id = "path_berserker",
		nameKey = "title.path_berserker",
		req = { kind = "mainPath", path = "berserker" },
		color = "#C8463A",
	},
	{
		id = "path_standard",
		nameKey = "title.path_standard",
		req = { kind = "mainPath", path = "standard" },
		color = "#D9A441",
	},
	-- S78: Hunter paths
	{
		id = "path_marksman",
		nameKey = "title.path_marksman",
		req = { kind = "mainPath", path = "marksman" },
		color = "#E2483A",
	},
	{
		id = "path_trapper",
		nameKey = "title.path_trapper",
		req = { kind = "mainPath", path = "trapper" },
		color = "#7FA650",
	},
	{
		id = "path_scout",
		nameKey = "title.path_scout",
		req = { kind = "mainPath", path = "scout" },
		color = "#7EC4E0",
	},
}

-- S59: character.title when the player hid the title; nil = never chose, the main path title shows
local NONE = "none"

local byId: { [string]: TitleDef } = {}
for _, def in list do
	assert(def.id ~= NONE, `Titles: "{NONE}" is reserved`)
	assert(byId[def.id] == nil, `Titles: duplicate id {def.id}`)
	byId[def.id] = def
end

return table.freeze({
	NONE = NONE,
	list = list,
	get = function(id: string): TitleDef?
		return byId[id]
	end,
})
