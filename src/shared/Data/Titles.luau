--!strict
-- Character titles (S16): shown above the name on the nameplate. Each one unlocks from a milestone the
-- character data already tracks. Names: title.<id> (Localization). Order = display order in the picker.

export type Requirement =
	{ kind: "level", value: number }
	| { kind: "pvpKills", value: number }
	| { kind: "duelsWon", value: number }
	| { kind: "mainDone", value: number }

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
}

local byId: { [string]: TitleDef } = {}
for _, def in list do
	byId[def.id] = def
end

return table.freeze({
	list = list,
	get = function(id: string): TitleDef?
		return byId[id]
	end,
})
