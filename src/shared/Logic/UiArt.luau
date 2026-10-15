--!strict
-- Interface pictures (S119): the one place that knows the keys of the owner's interface art (the BRAKI-GRAFIK path of
-- the file without tylko_2d/ and .png, e.g. "umiejetnosci/skill_charge", "hud/menu_map", "mapy/meadows") and finds
-- them in the generated registry (Data/UiArt) and the id file (Data/UiArtSheets). Pure: no Roblox API (Lune tests).
-- A key without a cell / single, or a file without an id, means "draw today's glyph" (UI/UiArtState, ArtIcon).

local Items = require("../Data/Items")
local Products = require("../Data/Products")
local Registry = require("../Data/UiArt")
local Sheets = require("../Data/UiArtSheets")

export type Cell = Registry.Cell
export type Single = Registry.Single
export type Frame = Registry.Frame

local UiArt = {}

UiArt.CELL = Registry.CELL

-- Pictures without a game id of their own (hud/<name>, mapa/map_<kind>). tools/icons/ids.luau exports these lists.
UiArt.FIXED = table.freeze({
	hud = table.freeze({
		"pvp",
		"lock",
		"bound",
		"potion_empty",
		"attack",
		"sprint",
		"party_leader",
		"dead",
		"mail",
		"vip",
	}),
	map = table.freeze({
		"portal",
		"cave",
		"dungeon",
		"vein",
		"herb",
		"fishing",
		"player",
		"quest",
		"guide",
		"party",
		"recommended",
		"monster",
		"elite",
		"boss",
		"area",
		"npc",
	}),
})

-- Ids of the HUD menu (Controllers/ScreenController MENU; tests/uiart.spec checks they match).
UiArt.MENUS = table.freeze({
	"inventory",
	"skills",
	"map",
	"quests",
	"guild",
	"party",
	"mounts",
	"rankings", -- S124: no picture yet (glyph ♔)
	"arena", -- S126: no picture yet (glyph ⚔)
	"wardrobe",
	"premium",
	"menu",
})

-- Atlas styles: silhouettes (white on transparent) are tinted with the colour of the glyph they replace.
UiArt.STYLE = table.freeze({
	skills = table.freeze({ tint = false }),
	status = table.freeze({ tint = false }),
	emblems = table.freeze({ tint = false }),
	hud = table.freeze({ tint = true }),
	map = table.freeze({ tint = true }),
	shop = table.freeze({ tint = false }),
})

-- Gathering node family of the map sketches -> map icon name.
local NODE_ICON: { [string]: string } = { vein = "vein", bush = "herb", fishing = "fishing" }

local passKeys: { [string]: boolean } = {}
for _, pass in Products.passes do
	passKeys[pass.key] = true
end

-- ------------------------------------------------------------------------------------------------ keys

function UiArt.skill(id: string): string
	return `umiejetnosci/skill_{id}`
end

function UiArt.effect(kind: string): string
	return `efekty/effect_{kind}`
end

function UiArt.element(element: string): string
	return `zywioly/element_{element}`
end

function UiArt.profile(id: string): string
	return `profile/profile_{id}`
end

function UiArt.guildSkill(id: string): string
	return `gildia/guild_{id}`
end

function UiArt.classEmblem(classId: string): string
	return `klasy/class_{string.lower(classId)}`
end

function UiArt.classPortrait(classId: string): string
	return `klasy/portrait_{string.lower(classId)}`
end

function UiArt.title(id: string): string
	return `tytuly/title_{id}`
end

function UiArt.menu(id: string): string
	return `hud/menu_{id}`
end

function UiArt.hud(name: string): string
	return `hud/{name}`
end

-- Equipment slot id (ring1 / ring2 share "ring") -> empty slot silhouette.
function UiArt.slot(slotId: string): string
	return `hud/slot_{Items.slotGroup[slotId] or slotId}`
end

-- Map / minimap icon; `family` only for "node" (vein | bush | fishing from the sketch icon id).
function UiArt.mapIcon(kind: string, family: string?): string
	if kind == "node" then
		return `mapa/map_{NODE_ICON[family or "vein"] or "vein"}`
	end
	return `mapa/map_{kind}`
end

function UiArt.service(name: string): string
	return `mapa/service_{name}`
end

-- Icon of an NPC on the maps and over its head: its first service besides "talk" ("story" for the story tellers);
-- an NPC with no service but talk is a plain "map_npc".
function UiArt.serviceOfNpc(npc: any): string -- an NpcDef (Data/Npcs), or any { services = { ... } }
	for _, service: string in npc.services do
		if service ~= "talk" then
			return UiArt.service(service)
		end
	end
	return UiArt.mapIcon("npc")
end

function UiArt.mark(id: string): string
	return `mapa/mark_{id}`
end

function UiArt.map(mapId: string): string
	return `mapy/{mapId}`
end

-- Premium shop entry: a Gamepass key -> "sklep/pass_<key>", anything else (shards_<n>, respawn, rename, wardrobe)
-- -> "sklep/<key>".
function UiArt.shop(key: string): string
	if passKeys[key] then
		return `sklep/pass_{key}`
	end
	return `sklep/{key}`
end

function UiArt.cosmetic(id: string): string
	return `kosmetyki/{id}`
end

function UiArt.boss(id: string): string
	return `bossowie/boss_{id}`
end

function UiArt.dungeon(bossId: string): string
	return `lochy/dungeon_{bossId}`
end

-- ------------------------------------------------------------------------------------------------ registry

function UiArt.cell(key: string?): Cell?
	return if key then Registry.ICONS[key] else nil
end

function UiArt.single(key: string?): Single?
	return if key then Registry.SINGLES[key] else nil
end

-- Painted map square in map-relative studs (from the wiki SVG viewBox), nil without a painted map.
function UiArt.mapFrame(mapId: string): Frame?
	return Registry.MAP_FRAMES[mapId]
end

-- File of a key: its atlas sheet or its single picture.
function UiArt.fileOf(key: string?): string?
	local cell = UiArt.cell(key)
	if cell then
		local files = Registry.ATLASES[cell.atlas]
		return if files then files[cell.s] else nil
	end
	local single = UiArt.single(key)
	return if single then single.file else nil
end

-- Asset id of a file ("rbxassetid://..."), nil when it is not uploaded yet. `ids` replaces Data/UiArtSheets (tests).
function UiArt.idOf(file: string?, ids: { [string]: string }?): string?
	if not file then
		return nil
	end
	local id = (ids or Sheets)[file]
	return if id and id ~= "" then id else nil
end

-- Atlas name of a key (nil for singles and unknown keys).
function UiArt.atlasOf(key: string?): string?
	local cell = UiArt.cell(key)
	return if cell then cell.atlas else nil
end

-- Silhouette atlas: the picture takes the colour of the glyph.
function UiArt.tinted(key: string?): boolean
	local atlas = UiArt.atlasOf(key)
	local style = if atlas then (UiArt.STYLE :: any)[atlas] else nil
	return style ~= nil and style.tint == true
end

-- Every atlas file in order (atlas name, then sheet), and every single picture file.
function UiArt.atlasFiles(): { string }
	local out = {}
	local names = {}
	for name in Registry.ATLASES do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		for _, file in Registry.ATLASES[name] do
			table.insert(out, file)
		end
	end
	return out
end

function UiArt.singleFiles(): { string }
	local out = {}
	for _, single in Registry.SINGLES do
		table.insert(out, single.file)
	end
	table.sort(out)
	return out
end

-- Keys of one atlas, sorted (admin /icongrid ui <atlas>).
function UiArt.keysOf(atlas: string): { string }
	local out = {}
	for key, cell in Registry.ICONS do
		if cell.atlas == atlas then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

UiArt.ATLAS_NAMES = table.freeze({ "skills", "status", "emblems", "hud", "map", "shop" })

return table.freeze(UiArt)
