--!strict
-- World files (S34): maps.json (Data/Maps without lighting and music), areas.json (Data/Areas: named areas with the
-- spawn totals of Data/Spawns, roads, lakes, streams, cave entrances, NPC spots and quest anchors), caves.json,
-- portals.json, npcs.json, shops.json (prices in gold through ItemValue.buyPrice, key `gold`). World.mapsData() and
-- World.areasData() are plain functions so tools/wikimap.luau (S37) can reuse them.

local Areas = require("../../src/shared/Data/Areas")
local Clean = require("./Clean")
local ItemValue = require("../../src/shared/Logic/ItemValue")
local Json = require("./Json")
local Maps = require("../../src/shared/Data/Maps")
local Names = require("./Names")
local Npcs = require("../../src/shared/Data/Npcs")
local Portals = require("../../src/shared/Data/Portals")
local Rarities = require("../../src/shared/Data/Rarities")
local Schema = require("./Schema")
local Shops = require("../../src/shared/Data/Shops")
local Spawns = require("../../src/shared/Data/Spawns")

local S = Schema
local arr, map, rec = S.arr, S.map, S.rec

local World = {}

local Point = rec("Point", { x = "number", z = "number" })
local Point3 = rec("Point3", { x = "number", y = "number", z = "number" })
local Range = rec("LevelRange", { min = "int", max = "int" })

S.file(
	"maps",
	rec("MapsFile", {
		maps = arr(rec("MapInfo", {
			id = "string",
			name = "name",
			zone = "string",
			minLevel = "int",
			maxLevel = "int",
			size = Point,
			spawn = Point3,
			offset = Point3,
			biome = "string",
			worldMap = rec("WorldMapPos", { x = "number", y = "number" }),
			links = arr("ref:maps"),
			["dungeonRegion?"] = "string",
			["dungeonEntrance?"] = Point3,
			kind = "string", -- city, region, cave, dungeon, other
		})),
	})
)

local Area = rec("Area", {
	id = "string",
	map = "ref:maps",
	name = "name",
	levelMin = "int",
	levelMax = "int",
	kinds = arr("ref:monsters"),
	rect = arr("number"),
	groups = "int",
	monsters = "int",
	respawnMin = "number",
	respawnMax = "number",
	["landmark?"] = Point,
	["arrive?"] = Point,
	["decor?"] = "string",
	["profile?"] = "string",
})

S.file(
	"areas",
	rec("AreasFile", {
		areas = arr(Area),
		maps = map(rec("MapFeatures", {
			roads = arr(rec("Road", { points = arr("number"), width = "number", material = "string" })),
			lakes = arr(rec("Lake", { x = "number", z = "number", r = "number" })),
			streams = arr(
				rec("StreamInfo", { id = "string", points = arr("number"), widths = arr("number"), into = "string" })
			),
			caves = arr(rec("CaveEntranceInfo", { cave = "ref:caves", x = "number", z = "number", rot = "number" })),
			npcSpots = map(rec("NpcSpotInfo", { x = "number", z = "number", facing = "number" })),
			questAnchors = arr(rec("QuestAnchorInfo", { id = "string", x = "number", z = "number" })),
		})),
	})
)

S.file(
	"caves",
	rec("CavesFile", {
		caves = arr(rec("Cave", {
			id = "string",
			name = "name",
			region = "ref:maps",
			levelMin = "int",
			levelMax = "int",
			normal = arr("ref:monsters"),
			elites = arr("ref:monsters"),
			elite2 = arr("ref:monsters"),
			eliteGroups = "int",
			ores = arr("string"),
			oreCount = "int",
			boss = "bool",
			groups = "int",
			monsters = "int",
			["entrance?"] = rec("CaveEntrance", { x = "number", z = "number", rot = "number" }),
			["arrival?"] = Point,
			["profile?"] = "string",
		})),
	})
)

S.file(
	"portals",
	rec("PortalsFile", {
		portals = arr(rec("PortalInfo", {
			id = "string",
			map = "ref:maps",
			target = "ref:maps",
			kind = "string",
			x = "number",
			z = "number",
			rot = "number",
			["arrive?"] = Point,
		})),
	})
)

S.file(
	"npcs",
	rec("NpcsFile", {
		npcs = arr(rec("Npc", {
			id = "string",
			name = "name",
			["greeting?"] = "name",
			map = "ref:maps",
			x = "number",
			z = "number",
			facing = "number",
			services = arr("string"),
			["shop?"] = "ref:shops",
			icon = "string",
			colors = rec("NpcColors", { body = "color", accent = "color" }),
			decoration = "bool",
		})),
	})
)

S.file(
	"shops",
	rec("ShopsFile", {
		shops = arr(rec("Shop", {
			id = "string",
			npcs = arr("ref:npcs"),
			classTabs = "bool",
			entries = arr(rec("ShopEntry", {
				item = "ref:items",
				gold = "int",
				["goldPerLevel?"] = "int",
				["ilvl?"] = "int",
				rarity = "string",
				["el?"] = "string",
				["level?"] = "int",
				["classes?"] = arr("string"),
				["key?"] = "string",
			})),
		})),
		weaponsmithTiers = arr("int"),
	})
)

function World.mapKind(map: any): string
	if map.id == "city" then
		return "city"
	elseif Areas.byMap[map.id] then
		return "region"
	elseif Areas.caves.get(map.id) then
		return "cave"
	elseif map.dungeonRegion or string.sub(map.id, 1, 8) == "dungeon_" then
		return "dungeon"
	end
	return "other"
end

function World.mapsData(hidden: { [string]: boolean }): { any }
	local list = {}
	for _, id in Clean.keys(Maps.byId) do
		local m = Maps.byId[id]
		if not hidden[id] then
			table.insert(list, {
				id = id,
				name = Names.of(m.nameKey),
				zone = m.zone,
				minLevel = m.minLevel,
				maxLevel = m.maxLevel,
				size = { x = m.size.x, z = m.size.z },
				spawn = Clean.clean(m.spawn),
				offset = Clean.clean(m.offset),
				biome = m.biome,
				worldMap = Clean.clean(m.worldMap),
				links = Clean.dropRefs(Clean.clean(m.links), hidden),
				dungeonRegion = m.dungeonRegion,
				dungeonEntrance = if m.dungeonEntrance then Clean.clean(m.dungeonEntrance) else nil,
				kind = World.mapKind(m),
			})
		end
	end
	return list
end

function World.maps(ctx: any): any
	return { maps = World.mapsData(ctx.hidden) }
end

-- Spawn totals of an area / cave id over every map: groups, monsters, respawn range.
local function spawnTotals(): { [string]: any }
	local out: { [string]: any } = {}
	for _, mapId in Clean.keys(Spawns.byMap) do
		for _, s in Spawns.byMap[mapId] do
			if s.areaId then
				local t = out[s.areaId]
				if not t then
					t = { groups = 0, monsters = 0, respawnMin = s.respawn.min, respawnMax = s.respawn.max }
					out[s.areaId] = t
				end
				t.groups += 1
				t.monsters += s.count
				t.respawnMin = math.min(t.respawnMin, s.respawn.min)
				t.respawnMax = math.max(t.respawnMax, s.respawn.max)
			end
		end
	end
	return out
end

function World.areasData(): any
	local totals = spawnTotals()
	local areas = {}
	local features = {}
	for _, mapId in Clean.keys(Areas.byMap) do
		local data = Areas.byMap[mapId]
		for _, a in data.areas do
			local t = totals[a.id] or { groups = 0, monsters = 0, respawnMin = 0, respawnMax = 0 }
			table.insert(areas, {
				id = a.id,
				map = mapId,
				name = Names.of(a.nameKey),
				levelMin = a.lv[1],
				levelMax = a.lv[2],
				kinds = Clean.clean(a.kinds),
				rect = Clean.clean(a.rect),
				groups = t.groups,
				monsters = t.monsters,
				respawnMin = t.respawnMin,
				respawnMax = t.respawnMax,
				landmark = if a.landmark then { x = a.landmark.x, z = a.landmark.z } else nil,
				arrive = if a.arrive then { x = a.arrive.x, z = a.arrive.z } else nil,
				decor = a.decor,
				profile = (a :: any).profile,
			})
		end
		local streams = {}
		for _, st in data.streams or {} do
			table.insert(
				streams,
				{ id = st.id, points = Clean.clean(st.points), widths = Clean.clean(st.widths), into = st.into }
			)
		end
		local anchors = {}
		for _, q in data.questAnchors or {} do
			table.insert(anchors, { id = q.id, x = q.x, z = q.z })
		end
		local spots = Json.object({})
		for _, key in Clean.keys(data.npcSpots or {}) do
			local spot = (data.npcSpots :: any)[key]
			spots[key] = { x = spot.x, z = spot.z, facing = spot.facing }
		end
		local roads = {}
		for _, r in data.roads do
			table.insert(roads, { points = Clean.clean(r.points), width = r.width, material = r.material })
		end
		features[mapId] = {
			roads = roads,
			lakes = Clean.clean(data.lakes),
			streams = streams,
			caves = Clean.clean(data.caves),
			npcSpots = spots,
			questAnchors = anchors,
		}
	end
	return { areas = areas, maps = features }
end

function World.areas(_ctx: any): any
	return World.areasData()
end

function World.caves(_ctx: any): any
	local totals = spawnTotals()
	local list = {}
	for _, cave in Areas.caves.list do
		local t = totals[cave.id] or { groups = 0, monsters = 0 }
		local entrance = Areas.entranceOf(cave.id)
		table.insert(list, {
			id = cave.id,
			name = Names.of(cave.nameKey),
			region = cave.region,
			levelMin = cave.levels[1],
			levelMax = cave.levels[2],
			normal = Clean.clean(cave.normal),
			elites = Clean.clean(cave.elites),
			elite2 = Clean.clean(cave.elite2),
			eliteGroups = cave.eliteGroups,
			ores = Clean.clean(cave.ores),
			oreCount = cave.oreCount,
			boss = cave.boss,
			groups = t.groups,
			monsters = t.monsters,
			entrance = if entrance then { x = entrance.x, z = entrance.z, rot = entrance.rot } else nil,
			arrival = Areas.arrivalOf(cave.id),
			profile = (cave :: any).profile,
		})
	end
	return { caves = list }
end

function World.portals(ctx: any): any
	local list = {}
	for _, p in Portals.list do
		if not ctx.hidden[p.map] and not ctx.hidden[p.target] then
			table.insert(list, {
				id = p.id,
				map = p.map,
				target = p.target,
				kind = p.kind,
				x = p.x,
				z = p.z,
				rot = p.rot,
				arrive = if p.arrive then { x = p.arrive.x, z = p.arrive.z } else nil,
			})
		end
	end
	return { portals = list }
end

function World.npcs(ctx: any): any
	local list = {}
	for _, n in Npcs.list do
		if not ctx.hidden[n.id] then
			table.insert(list, {
				id = n.id,
				name = Names.of(n.nameKey),
				greeting = Names.opt(n.greetingKey),
				map = n.map,
				x = n.position.x,
				z = n.position.z,
				facing = n.facing,
				services = Clean.clean(n.services),
				shop = n.shop,
				icon = n.icon,
				colors = { body = n.colors.body, accent = n.colors.accent },
				decoration = n.decoration == true,
			})
		end
	end
	return { npcs = list }
end

function World.shops(ctx: any): any
	local npcsOf: { [string]: { string } } = {}
	for _, n in Npcs.list do
		if n.shop and not ctx.hidden[n.id] then
			npcsOf[n.shop] = npcsOf[n.shop] or {}
			table.insert(npcsOf[n.shop], n.id)
		end
	end
	local list = {}
	ctx.shopItems = {}
	for _, id in Clean.keys(Shops.byId) do
		local shop = Shops.byId[id]
		local entries = {}
		for _, e in shop.entries do
			if not ctx.hidden[e.item] then
				local item = ItemValue.entryItem(e)
				local entry = {
					item = e.item,
					gold = ItemValue.buyPrice(e, shop, 1),
					goldPerLevel = e.pricePerLevel,
					ilvl = e.ilvl,
					rarity = Rarities.get(item.rarity).key,
					el = e.el,
					level = e.level,
					classes = if e.classes then Clean.clean(e.classes) else nil,
					key = e.key,
				}
				table.insert(entries, entry)
				ctx.shopItems[e.item] = ctx.shopItems[e.item] or {}
				table.insert(ctx.shopItems[e.item], { shop = id, gold = entry.gold, ilvl = e.ilvl })
			end
		end
		table.insert(list, { id = id, npcs = npcsOf[id] or {}, classTabs = shop.classTabs == true, entries = entries })
	end
	return { shops = list, weaponsmithTiers = Clean.clean(Shops.WEAPONSMITH_TIERS) }
end

return World
