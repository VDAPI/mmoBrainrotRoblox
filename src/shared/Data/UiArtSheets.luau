--!strict
-- Asset ids of the interface pictures (S119): one row per file of art/ui (atlases ui_<atlas>_<NN>.png and the single
-- pictures single/<folder>__<name>.jpg), key = file name. Filled in after the upload (MCP upload_image or the owner's
-- Bulk Import, docs/ANIMACJE.md "Grafiki interfejsu (S119)"). tools/icons/import_ui.py writes "" for every new or
-- changed file and keeps the other rows; an empty id = not uploaded yet, so the UI keeps its glyphs for that file.

local SHEETS: { [string]: string } = {
	["bossowie__boss_azgor.jpg"] = "rbxassetid://100153793287241",
	["bossowie__boss_grimrok.jpg"] = "rbxassetid://75784782133691",
	["bossowie__boss_morvane.jpg"] = "rbxassetid://92273319961219",
	["bossowie__boss_vaelgrath.jpg"] = "rbxassetid://83143604621579",
	["klasy__portrait_cleric.jpg"] = "rbxassetid://135065757764109",
	["klasy__portrait_hunter.jpg"] = "rbxassetid://118313261387277",
	["klasy__portrait_mage.jpg"] = "rbxassetid://78971674861142",
	["klasy__portrait_warrior.jpg"] = "rbxassetid://74869214071320",
	["lochy__dungeon_azgor.jpg"] = "rbxassetid://134673841190467",
	["lochy__dungeon_grimrok.jpg"] = "rbxassetid://84950642299826",
	["lochy__dungeon_morvane.jpg"] = "rbxassetid://77918825474039",
	["lochy__dungeon_vaelgrath.jpg"] = "rbxassetid://105603693494876",
	["mapy__ashen.jpg"] = "",
	["mapy__ashen_cave.jpg"] = "",
	["mapy__ashen_lair.jpg"] = "",
	["mapy__ashen_mine.jpg"] = "",
	["mapy__city.jpg"] = "",
	["mapy__duskwood.jpg"] = "",
	["mapy__duskwood_barrow.jpg"] = "",
	["mapy__duskwood_cave.jpg"] = "",
	["mapy__duskwood_den.jpg"] = "",
	["mapy__frostpeak.jpg"] = "",
	["mapy__frostpeak_cave.jpg"] = "",
	["mapy__frostpeak_grotto.jpg"] = "",
	["mapy__frostpeak_hold.jpg"] = "",
	["mapy__meadows.jpg"] = "",
	["mapy__meadows_burrow.jpg"] = "",
	["mapy__meadows_cave.jpg"] = "",
	["mapy__meadows_hideout.jpg"] = "",
	["mapy__world.jpg"] = "",
	["ui_emblems_01.png"] = "rbxassetid://90219814652043",
	["ui_hud_01.png"] = "rbxassetid://137020428772073",
	["ui_map_01.png"] = "rbxassetid://128368350205709",
	["ui_shop_01.png"] = "rbxassetid://106308221751331",
	["ui_skills_01.png"] = "rbxassetid://98255153969390",
	["ui_status_01.png"] = "rbxassetid://127300661693271",
}

return table.freeze(SHEETS)
