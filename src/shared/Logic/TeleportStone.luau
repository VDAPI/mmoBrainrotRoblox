--!strict
-- Owner 2026-11-01 (docs/DESIGN.md §13a): the rules of the everlasting teleport stones (`use.keep`, Data/PortalShop),
-- pure, so TravelService, the backpack, the stone picker, the tooltip and tests/teleportstone.spec read one rule.
--   rest   an everlasting stone rests COOLDOWN seconds after a successful teleport, each stone its own: `cd` on the
--          item (os.time seconds when it is ready; Roblox server time on the client), so it runs over a logout too
--   set    the Everlasting Map Stone and the Everlasting Dungeon Stone are set for good to the place picked on their
--          first use (`at`: a map id or a dungeon region); a stone bought before is set at its next use
--   places the Map Stone: every map the character visited but boss dungeons and server-mode maps (region maps, caves,
--          crypts, the capital); the Dungeon Stone: every boss dungeon entrance
-- Single-use stones keep the picker on every use and never rest.

local Items = require("../Data/Items")
local Maps = require("../Data/Maps")
local PortalShop = require("../Data/PortalShop")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef

local TeleportStone = {}

TeleportStone.COOLDOWN = PortalShop.COOLDOWN

-- Whether the definition is an everlasting teleport stone.
function TeleportStone.everlasting(def: ItemDef?): boolean
	local use = if def then def.use else nil
	return use ~= nil and use.kind == "teleport" and use.keep == true
end

-- Whether the stone is set for good on its first use (the everlasting Map and Dungeon Stone).
function TeleportStone.sets(def: ItemDef?): boolean
	local use = if def then def.use else nil
	return TeleportStone.everlasting(def) and use ~= nil and (use.target == "map" or use.target == "dungeon")
end

-- Seconds until the stone works again (0 = ready).
function TeleportStone.restLeft(item: ItemInstance, now: number): number
	local cd = item.cd
	return if type(cd) == "number" then math.max(0, cd - now) else 0
end

-- Whole minutes left, rounded up (the refusal toast and the tooltip).
function TeleportStone.minutesLeft(item: ItemInstance, now: number): number
	return math.ceil(TeleportStone.restLeft(item, now) / 60)
end

-- The stone after a successful teleport at `now` (a new table).
function TeleportStone.rested(item: ItemInstance, now: number): ItemInstance
	local copy = table.clone(item)
	copy.cd = now + TeleportStone.COOLDOWN
	return copy
end

-- Whether `mapId` is a Map Stone place for a character that visited `visited` (character.visitedMaps).
function TeleportStone.isMapPlace(mapId: string, visited: { [string]: boolean }?): boolean
	local map = Maps.get(mapId)
	if not map or map.biome == "dungeon" or map.serverModes ~= nil then
		return false
	end
	return type(visited) == "table" and visited[mapId] == true
end

-- Every Map Stone place of `visited`, sorted by id (the picker sorts by name).
function TeleportStone.mapPlaces(visited: { [string]: boolean }?): { string }
	local list: { string } = {}
	for mapId in (if type(visited) == "table" then visited else {}) :: { [string]: boolean } do
		if type(mapId) == "string" and TeleportStone.isMapPlace(mapId, visited) then
			table.insert(list, mapId)
		end
	end
	table.sort(list)
	return list
end

-- The cave map holding the entrance of the boss dungeon of `region`, if it exists.
function TeleportStone.dungeonMap(region: string): Maps.MapDef?
	for _, map in Maps.byId do
		if map.dungeonRegion == region and map.dungeonEntrance then
			return map
		end
	end
	return nil
end

-- Why the stone cannot be set to `target` now (nil = it can): "error.badRequest" (not such a stone), "teleport.bound"
-- (set already), "teleport.notVisited" (not a Map Stone place of the character), "teleport.soon" (no such dungeon).
function TeleportStone.setRefusal(
	item: ItemInstance,
	def: ItemDef?,
	target: string,
	visited: { [string]: boolean }?
): string?
	if not def or not TeleportStone.sets(def) or type(target) ~= "string" then
		return "error.badRequest"
	end
	if item.at ~= nil then
		return "teleport.bound"
	end
	if (def.use :: any).target == "map" then
		return if TeleportStone.isMapPlace(target, visited) then nil else "teleport.notVisited"
	end
	return if TeleportStone.dungeonMap(target) then nil else "teleport.soon"
end

-- Locale key of the place a stone is set to: the map's name, or the dungeon's ("dungeon.<region>").
function TeleportStone.placeKey(def: ItemDef?, at: string): string?
	if def and def.use and def.use.target == "dungeon" then
		return `dungeon.{at}`
	end
	local map = Maps.get(at)
	return if map then map.nameKey else nil
end

return TeleportStone
