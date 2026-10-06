--!strict
-- Own map marks (S25, DESIGN §23): up to Config.Nav.maxMarks per character in `character.mapMarks`
-- ({ map, x, z, icon }, map-relative studs). No text of their own: an icon from Data/MapMarks, the client names
-- the mark after the nearest NPC or monster area. Remotes MapMarkAdd(map, x, z, icon) and MapMarkRemove(index)
-- check the map, the bounds of the map, the icon and the limit (types and rate in Net/Definitions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local MapMarks = require(Shared.Data.MapMarks)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local MapMarkService = {
	Name = "MapMarkService",
	Deps = { "PlayerStateService" },
}

-- Two marks closer than this (studs) on one map are the same place.
local SAME_PLACE = 4

local PlayerStateService: any

local function marksOf(player: Player): { Types.MapMark }?
	local char = PlayerStateService.GetCharacter(player)
	if not char then
		return nil
	end
	if type(char.mapMarks) ~= "table" then
		PlayerStateService.Set(player, { "character", "mapMarks" }, {})
	end
	return char.mapMarks
end

local function round(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- Adds a mark; returns (ok, errorKey?).
function MapMarkService.Add(player: Player, mapId: string, x: number, z: number, icon: string): (boolean, string?)
	local map = Maps.get(mapId)
	if not map or map.biome == "dungeon" or not MapMarks.get(icon) then
		return false, "error.badRequest"
	end
	if math.abs(x) > map.size.x / 2 or math.abs(z) > map.size.z / 2 then
		return false, "worldmap.mark.outside"
	end
	local marks = marksOf(player)
	if not marks then
		return false, "error.wrongPhase"
	end
	if #marks >= Config.Nav.maxMarks then
		return false, "worldmap.mark.full"
	end
	for _, mark in marks do
		if mark.map == mapId and math.sqrt((mark.x - x) ^ 2 + (mark.z - z) ^ 2) < SAME_PLACE then
			return false, "worldmap.mark.exists"
		end
	end
	PlayerStateService.ArrayInsert(
		player,
		{ "character", "mapMarks" },
		{ map = mapId, x = round(x), z = round(z), icon = icon }
	)
	return true, nil
end

-- Removes the mark at `index` (1-based).
function MapMarkService.Remove(player: Player, index: number): (boolean, string?)
	local marks = marksOf(player)
	if not marks then
		return false, "error.wrongPhase"
	end
	if index < 1 or index > #marks then
		return false, "error.badRequest"
	end
	PlayerStateService.ArrayRemove(player, { "character", "mapMarks" }, index)
	return true, nil
end

function MapMarkService.List(player: Player): { Types.MapMark }
	return marksOf(player) or {}
end

function MapMarkService.Clear(player: Player): number
	local marks = marksOf(player)
	if not marks then
		return 0
	end
	local count = #marks
	PlayerStateService.Set(player, { "character", "mapMarks" }, {})
	return count
end

function MapMarkService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
end

function MapMarkService.Start()
	Net.Handle("MapMarkAdd", function(player: Player, mapId: string, x: number, z: number, icon: string)
		return MapMarkService.Add(player, mapId, x, z, icon)
	end)
	Net.Handle("MapMarkRemove", function(player: Player, index: number)
		return MapMarkService.Remove(player, index)
	end)
end

return MapMarkService
