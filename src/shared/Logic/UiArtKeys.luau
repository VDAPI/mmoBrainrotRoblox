--!strict
-- Game ids of every interface picture category (S119): what tools/icons/ids.luau exports for the importer
-- (tools/icons/import_ui.py checks each file name against these lists), what tests/uiart.spec checks the registry
-- against and what /icons ui counts. Pure (Lune).

local AreaProfiles = require("../Data/AreaProfiles")
local Bosses = require("../Data/Bosses")
local Classes = require("../Data/Classes")
local Cosmetics = require("../Data/Cosmetics")
local Elements = require("../Data/Elements")
local GuildSkills = require("../Data/GuildSkills")
local Items = require("../Data/Items")
local MapMarks = require("../Data/MapMarks")
local Maps = require("../Data/Maps")
local Npcs = require("../Data/Npcs")
local Pl = require("../Data/Localization/pl")
local Products = require("../Data/Products")
local Skills = require("../Data/Skills")
local Titles = require("../Data/Titles")
local UiArt = require("./UiArt")

export type Ids = {
	skills: { [string]: string }, -- skill id -> class in lower case (folder umiejetnosci/<class>)
	effects: { string },
	elements: { string },
	profiles: { string },
	guildSkills: { string },
	classes: { string }, -- lower case
	titles: { string },
	slots: { string },
	menus: { string },
	maps: { string }, -- Maps.byId + "world"
	marks: { string },
	services: { string },
	cosmetics: { string },
	shop: { string }, -- names in sklep/: shards_<n>, pass_<key>, respawn, rename, wardrobe, service kinds (lure, ...)
	bosses: { string }, -- every boss (portrait boss_<id>); dungeon banners only for the dungeon bosses
	dungeonBosses: { string },
	fixed: { hud: { string }, map: { string } },
}

-- Text keys effect.<x> that are not an effect kind (EffectKind is only a type, so kinds come from the texts).
local NOT_EFFECTS: { [string]: boolean } = { withValue = true }

local function sorted(set: { [string]: boolean }): { string }
	local out = {}
	for k in set do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

local function listOf(t: { string }): { string }
	local out = table.clone(t)
	table.sort(out)
	return out
end

local UiArtKeys = {}

function UiArtKeys.ids(): Ids
	local skills: { [string]: string } = {}
	for id, def in Skills.byId do
		skills[id] = string.lower(def.class)
	end
	local effects: { [string]: boolean } = {}
	for key in Pl :: any do
		local kind = string.match(key, "^effect%.(%w+)$")
		if kind and not NOT_EFFECTS[kind] then
			effects[kind] = true
		end
	end
	local elements: { [string]: boolean } = {}
	for el in Elements.COLORS do
		elements[el] = true
	end
	local profiles: { [string]: boolean } = {}
	for id in AreaProfiles.byId do
		profiles[id] = true
	end
	local guild: { [string]: boolean } = {}
	for _, def in GuildSkills.list do
		guild[def.id] = true
	end
	local classes: { [string]: boolean } = {}
	for id in Classes.byId :: any do
		classes[string.lower(id)] = true
	end
	local titles: { [string]: boolean } = {}
	for _, def in Titles.list do
		titles[def.id] = true
	end
	local slots: { [string]: boolean } = {}
	for _, group in Items.slotGroup do
		slots[group] = true
	end
	local maps: { [string]: boolean } = { world = true }
	for id in Maps.byId do
		maps[id] = true
	end
	local marks: { [string]: boolean } = {}
	for _, icon in MapMarks.list do
		marks[icon.id] = true
	end
	local services: { [string]: boolean } = {}
	for _, npc in Npcs.list do
		for _, service in npc.services do
			if service ~= "talk" then
				services[service] = true
			end
		end
	end
	local cosmetics: { [string]: boolean } = {}
	for _, def in Cosmetics.list do
		cosmetics[def.id] = true
	end
	local shop: { [string]: boolean } = { [Products.respawn.key] = true, rename = true, wardrobe = true }
	for _, pack in Products.shardPacks do
		shop[pack.key] = true
	end
	for _, pass in Products.passes do
		shop[`pass_{pass.key}`] = true
	end
	-- Service cards of the premium shop (UI/Screens/PremiumShop/Items) show one tile per kind: UiArt.shop(kind).
	for _, entry in Products.shop do
		if entry.kind == "lure" or entry.kind == "autoPotion" or entry.kind == "autoGrind" then
			shop[entry.kind] = true
		end
	end
	local bosses: { [string]: boolean } = {}
	local dungeonBosses: { [string]: boolean } = {}
	for _, boss in Bosses.all do
		bosses[boss.id] = true
		if not boss.world then
			dungeonBosses[boss.id] = true
		end
	end
	return {
		skills = skills,
		effects = sorted(effects),
		elements = sorted(elements),
		profiles = sorted(profiles),
		guildSkills = sorted(guild),
		classes = sorted(classes),
		titles = sorted(titles),
		slots = sorted(slots),
		menus = listOf(UiArt.MENUS),
		maps = sorted(maps),
		marks = sorted(marks),
		services = sorted(services),
		cosmetics = sorted(cosmetics),
		shop = sorted(shop),
		bosses = sorted(bosses),
		dungeonBosses = sorted(dungeonBosses),
		fixed = { hud = listOf(UiArt.FIXED.hud), map = listOf(UiArt.FIXED.map) },
	}
end

-- Every registry key the game can ask for, by atlas / single kind ("skills", "status", "emblems", "hud", "map",
-- "shop", "portrait", "boss", "dungeon", "painted").
function UiArtKeys.byCategory(): { [string]: { string } }
	local ids = UiArtKeys.ids()
	local out: { [string]: { string } } = {
		skills = {},
		status = {},
		emblems = {},
		hud = {},
		map = {},
		shop = {},
		portrait = {},
		boss = {},
		dungeon = {},
		painted = {},
	}
	local function add(cat: string, key: string)
		table.insert(out[cat], key)
	end
	for id in ids.skills do
		add("skills", UiArt.skill(id))
	end
	for _, k in ids.effects do
		add("status", UiArt.effect(k))
	end
	for _, k in ids.elements do
		add("status", UiArt.element(k))
	end
	for _, k in ids.profiles do
		add("status", UiArt.profile(k))
	end
	for _, k in ids.guildSkills do
		add("status", UiArt.guildSkill(k))
	end
	for _, k in ids.classes do
		add("emblems", UiArt.classEmblem(k))
		add("portrait", UiArt.classPortrait(k))
	end
	for _, k in ids.titles do
		add("emblems", UiArt.title(k))
	end
	for _, k in ids.menus do
		add("hud", UiArt.menu(k))
	end
	for _, k in ids.fixed.hud do
		add("hud", UiArt.hud(k))
	end
	for _, k in ids.slots do
		add("hud", `hud/slot_{k}`)
	end
	for _, k in ids.fixed.map do
		add("map", `mapa/map_{k}`)
	end
	for _, k in ids.services do
		add("map", UiArt.service(k))
	end
	for _, k in ids.marks do
		add("map", UiArt.mark(k))
	end
	for _, k in ids.shop do
		add("shop", `sklep/{k}`)
	end
	for _, k in ids.cosmetics do
		add("shop", UiArt.cosmetic(k))
	end
	for _, k in ids.bosses do
		add("boss", UiArt.boss(k))
	end
	for _, k in ids.dungeonBosses do
		add("dungeon", UiArt.dungeon(k))
	end
	for _, k in ids.maps do
		add("painted", UiArt.map(k))
	end
	for _, list in out do
		table.sort(list)
	end
	return out
end

-- Set of every valid key (tests: each registry key is one of these).
function UiArtKeys.all(): { [string]: string }
	local out: { [string]: string } = {}
	for cat, keys in UiArtKeys.byCategory() do
		for _, key in keys do
			out[key] = cat
		end
	end
	return out
end

return table.freeze(UiArtKeys)
