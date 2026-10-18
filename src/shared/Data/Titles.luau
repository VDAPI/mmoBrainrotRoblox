--!strict
-- Character titles (S16): shown above the name on the nameplate. Each one unlocks from a milestone the
-- character data already tracks. Names: title.<id> (Localization). Order = display order in the picker.
-- S59 (ROZWOJ 3.1, 16.7): path titles have the id path_<pathId> (= PathDef.titleId), the name key title.path_<pathId>
-- and req = { kind = "mainPath", path = "<pathId>" }; a class session adds them together with its PathDef, at the
-- end of the list, e.g. id path_healer, req { kind = "mainPath", path = "healer" }, color "#8FE0B8". Unpublished
-- paths hide them on the wiki (tools/WikiData/Visibility).

local Main = require("./Quests/Main")

export type Requirement =
	{ kind: "level", value: number }
	| { kind: "pvpKills", value: number }
	| { kind: "duelsWon", value: number }
	| { kind: "mainDone", value: number }
	| { kind: "mainPath", path: string } -- S59: unlocked while the active set's main path is this path id
	-- S121: shown while the account has VIP (MonetizationService.HasVip); needs the context argument of Logic/Titles
	| { kind: "vip" }
	-- S123: owned cosmetic of kind title; the account owns it, every character may show it (needs the context argument
	-- of Logic/Titles with `owned`)
	| { kind: "cosmetic", id: string }
	-- S125: unlocked while character.timedTitles[id] is in the future (rankings, events); granted by
	-- TitleService.GrantTimed or a mail parcel (Logic/Mail `timedTitle`)
	| { kind: "timed" }
	-- S128: earned once in any finished arena season at this tier; character.arena.titles[tier] = season id
	-- (Logic/Titles)
	| { kind: "arenaSeason", tier: string }
	-- S151: the achievement `id` is done (Data/Achievements; a character achievement in character.ach.done, an account one
	-- in the context's `ach`, so every character of the account shows an account achievement's title)
	| { kind: "achievement", id: string }

export type TitleDef = {
	id: string,
	nameKey: string,
	req: Requirement,
	color: string, -- hex, how the title is drawn on the nameplate
	wiki: boolean?, -- S105: false = left out of the wiki (tools/WikiData/Visibility) until published
	-- S128: the name key has a {season} placeholder filled from character.arena.titles[tier] (Titles.argsOf); the
	-- key "<nameKey>.plain" is the name without it
	seasonArg: boolean?,
}

local list: { TitleDef } = {
	{ id = "wanderer", nameKey = "title.wanderer", req = { kind = "level", value = 10 }, color = "#CFC6B0" },
	{ id = "adventurer", nameKey = "title.adventurer", req = { kind = "level", value = 25 }, color = "#9FD18B" },
	{ id = "veteran", nameKey = "title.veteran", req = { kind = "level", value = 50 }, color = "#7FB8FF" },
	{ id = "champion", nameKey = "title.champion", req = { kind = "level", value = 75 }, color = "#C77BFF" },
	{ id = "legend", nameKey = "title.legend", req = { kind = "level", value = 100 }, color = "#FF9F1C" },
	-- S102: story titles follow the quest positions (Main.indexOf), so story insertions never move their meaning
	{
		id = "sentinel",
		nameKey = "title.sentinel",
		req = { kind = "mainDone", value = Main.indexOf.herbs },
		color = "#E8D9A8",
	},
	{
		id = "dragonbane",
		nameKey = "title.dragonbane",
		req = { kind = "mainDone", value = Main.indexOf.vaelgrath },
		color = "#FF6B4A",
	},
	-- S105: the end of the story (the Thorn of Vael in the Heart of Winter and the first spring)
	{
		id = "thornbearer",
		nameKey = "title.thornbearer",
		req = { kind = "mainDone", value = Main.indexOf.firstSpring },
		color = "#B8E07A",
	},
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
	-- S81: Mage paths
	{
		id = "path_destroyer",
		nameKey = "title.path_destroyer",
		req = { kind = "mainPath", path = "destroyer" },
		color = "#E0743C",
	},
	{
		id = "path_arcanist",
		nameKey = "title.path_arcanist",
		req = { kind = "mainPath", path = "arcanist" },
		color = "#A884FF",
	},
	-- S121: published on the wiki together with the VIP article (S131)
	{ id = "vip", nameKey = "title.vip", req = { kind = "vip" }, color = "#F2C94C" },
	-- S123 (DESIGN-17 §4): bought titles (Data/Cosmetics kind "title"); names unlike the ranking and arena titles of
	-- S124-S130, so a purchase never poses as an achievement. Kept out of titles.json (cosmetics.json lists them).
	{ id = "pilgrim", nameKey = "title.pilgrim", req = { kind = "cosmetic", id = "title_pilgrim" }, color = "#CDBB94" },
	{
		id = "lorekeeper",
		nameKey = "title.lorekeeper",
		req = { kind = "cosmetic", id = "title_lorekeeper" },
		color = "#9FC3E8",
	},
	{
		id = "oathbound",
		nameKey = "title.oathbound",
		req = { kind = "cosmetic", id = "title_oathbound" },
		color = "#D8C27A",
	},
	{
		id = "nightwatch",
		nameKey = "title.nightwatch",
		req = { kind = "cosmetic", id = "title_nightwatch" },
		color = "#7F8FB8",
	},
	{
		id = "highborn",
		nameKey = "title.highborn",
		req = { kind = "cosmetic", id = "title_highborn" },
		color = "#E0B0D8",
	},
	-- S125 (DESIGN-17 §5): the top 3 of each weekly EXP bracket, 7 days; published on the wiki with the Rankings article
	-- (S131). S129 / S130 add their timed titles here.
	{
		id = "weekly_diligent",
		nameKey = "title.weekly_diligent",
		req = { kind = "timed" },
		color = "#F0D27A",
	},
	-- S129 (DESIGN-17 §7): the top 100 of a Blood Moon region, 7 days from the end of the event (mail `timedTitle`);
	-- not "bloodied" (10 PvP kills). Published on the wiki with the Blood Moon article (S131).
	{
		id = "bloodmoon",
		nameKey = "title.bloodmoon",
		req = { kind = "timed" },
		color = "#C0262D",
	},
	-- S130 (DESIGN-17 §8): the Champion of Vaelthorn, the winner of a Champion's Tournament bracket, 7 days from the
	-- mail (`timedTitle`); not "champion" (level 75). Published on the wiki with the tournament article (S131).
	{
		id = "tourney_champion",
		nameKey = "title.tourney_champion",
		req = { kind = "timed" },
		color = "#F2C14E",
	},
	-- S128 (DESIGN-17 §6): arena titles, published on the wiki with the arena article (S131). Bought with Arena Tokens
	-- (Data/Cosmetics kind "title", obtain.arena = "shop"; kept out of titles.json like every bought title, their
	-- cosmetics are in cosmetics.json since S131):
	{
		id = "ironwill",
		nameKey = "title.ironwill",
		req = { kind = "cosmetic", id = "title_ironwill" },
		color = "#B8B2A6",
	},
	{
		id = "sandveteran",
		nameKey = "title.sandveteran",
		req = { kind = "cosmetic", id = "title_sandveteran" },
		color = "#D9B26A",
	},
	-- S134k (DESIGN-15 §3.3): the hunting contracts' titles (Data/Cosmetics kind "title"): bought with Hunter's Marks at
	-- the Huntmaster (obtain.hunt) and the reward of the 99th contract
	{
		id = "bountyhunter",
		nameKey = "title.bountyhunter",
		req = { kind = "cosmetic", id = "title_bountyhunter" },
		color = "#A8743A",
	},
	{
		id = "huntlord",
		nameKey = "title.huntlord",
		req = { kind = "cosmetic", id = "title_huntlord" },
		color = "#7FA04A",
	},
	-- the season titles of each tier (Data/Arena.SEASON_REWARDS), carrying the season of the latest one
	{
		id = "arena_bronze",
		nameKey = "title.arena_bronze",
		req = { kind = "arenaSeason", tier = "bronze" },
		color = "#B07A4A",
		seasonArg = true,
	},
	{
		id = "arena_silver",
		nameKey = "title.arena_silver",
		req = { kind = "arenaSeason", tier = "silver" },
		color = "#C9D1D9",
		seasonArg = true,
	},
	{
		id = "arena_gold",
		nameKey = "title.arena_gold",
		req = { kind = "arenaSeason", tier = "gold" },
		color = "#E8C25A",
		seasonArg = true,
	},
	{
		id = "arena_diamond",
		nameKey = "title.arena_diamond",
		req = { kind = "arenaSeason", tier = "diamond" },
		color = "#8FD8FF",
		seasonArg = true,
	},
	{
		id = "arena_master",
		nameKey = "title.arena_master",
		req = { kind = "arenaSeason", tier = "master" },
		color = "#FF9F1C",
		seasonArg = true,
	},
	-- S152 (docs/DESIGN.md §21b): season pass 1 titles, cosmetics with obtain.season (the free track's tier 40 and a
	-- premium tier); off the wiki with their cosmetics until S152b
	{
		id = "s1_veteran",
		nameKey = "title.s1_veteran",
		req = { kind = "cosmetic", id = "title_s1_veteran" },
		color = "#B8D4EC",
	},
	{
		id = "s1_frostwarden",
		nameKey = "title.s1_frostwarden",
		req = { kind = "cosmetic", id = "title_s1_frostwarden" },
		color = "#8FC8F0",
	},
	-- S151 (docs/DESIGN.md §20b): achievement titles (Data/Achievements reward.title); off the wiki until S151b
	{
		id = "ach_butcher",
		nameKey = "title.ach_butcher",
		req = { kind = "achievement", id = "slayer4" },
		color = "#C8463A",
		wiki = false,
	},
	{
		id = "ach_elusive",
		nameKey = "title.ach_elusive",
		req = { kind = "achievement", id = "dodge3" },
		color = "#7EC4E0",
		wiki = false,
	},
	{
		id = "ach_fourslayer",
		nameKey = "title.ach_fourslayer",
		req = { kind = "achievement", id = "bossAll" },
		color = "#FF9F1C",
		wiki = false,
	},
	{
		id = "ach_ancestorbane",
		nameKey = "title.ach_ancestorbane",
		req = { kind = "achievement", id = "worldBoss1" },
		color = "#8FD8FF",
		wiki = false,
	},
	{
		id = "ach_cartographer",
		nameKey = "title.ach_cartographer",
		req = { kind = "achievement", id = "maps2" },
		color = "#E8D9A8",
		wiki = false,
	},
	{
		id = "ach_lairtracker",
		nameKey = "title.ach_lairtracker",
		req = { kind = "achievement", id = "lairs2" },
		color = "#7FA650",
		wiki = false,
	},
	{
		id = "ach_forgemaster",
		nameKey = "title.ach_forgemaster",
		req = { kind = "achievement", id = "upgrade9" },
		color = "#E8C25A",
		wiki = false,
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
