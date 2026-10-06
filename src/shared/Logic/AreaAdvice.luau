--!strict
-- Which monster areas suit a player (S22, DESIGN §3.6): the colour band of an area relative to the player's
-- level, "Recommended", "locked until level X" (portal choice: an area opens at its minimum level) and the
-- area to point a quest at. Pure; used by the portal window, the map, the minimap and the quest star.

local Areas = require("../Data/Areas")
local LevelBand = require("./LevelBand")

local AreaAdvice = {}

type Area = Areas.Area

-- Band of an area for a player: white when the level is inside the area's range, otherwise the band of the
-- nearest end of the range (so a level-1 player sees the 3-7 hills as fine and the 8-12 field as dangerous).
function AreaAdvice.bandOf(area: Area, level: number): LevelBand.Band
	local min, max = area.lv[1], area.lv[2]
	if level < min then
		return LevelBand.of(min, level)
	elseif level > max then
		return LevelBand.of(max, level)
	end
	return "white"
end

-- Recommended: the player's level lies in [min - 1, max].
function AreaAdvice.isRecommended(area: Area, level: number): boolean
	return level >= area.lv[1] - 1 and level <= area.lv[2]
end

-- Locked for the portal choice: the player is below the area's minimum level.
function AreaAdvice.locked(area: Area, level: number): boolean
	return level < area.lv[1]
end

-- Areas of a map sorted by minimum level (then maximum level, then id).
function AreaAdvice.sorted(mapId: string): { Area }
	local data = Areas.byMap[mapId]
	local list: { Area } = if data then table.clone(data.areas) else {}
	table.sort(list, function(a, b)
		if a.lv[1] ~= b.lv[1] then
			return a.lv[1] < b.lv[1]
		elseif a.lv[2] ~= b.lv[2] then
			return a.lv[2] < b.lv[2]
		end
		return a.id < b.id
	end)
	return list
end

-- Recommended areas of a map for a level (sorted by level).
function AreaAdvice.recommended(level: number, mapId: string): { Area }
	local out = {}
	for _, area in AreaAdvice.sorted(mapId) do
		if AreaAdvice.isRecommended(area, level) then
			table.insert(out, area)
		end
	end
	return out
end

-- The single best area of a map for a level: the recommended one whose range middle is nearest to the level
-- (the higher one on a tie); without any, the lowest area for players below the map and the highest above it.
function AreaAdvice.best(level: number, mapId: string): Area?
	local list = AreaAdvice.sorted(mapId)
	if #list == 0 then
		return nil
	end
	local best: Area? = nil
	local bestScore = math.huge
	for _, area in list do
		if AreaAdvice.isRecommended(area, level) then
			local score = math.abs((area.lv[1] + area.lv[2]) / 2 - level)
			if score <= bestScore then
				best, bestScore = area, score
			end
		end
	end
	if best then
		return best
	end
	return if level < list[1].lv[1] then list[1] else list[#list]
end

-- Default area for the portal choice: the lowest area of the map (S22, owner's decision).
function AreaAdvice.default(mapId: string): Area?
	return AreaAdvice.sorted(mapId)[1]
end

-- Area to send a quest for monster `kind` to: on the given maps (all region maps when nil), the area with that
-- kind whose range covers the level, the lowest such area otherwise. Returns the map id too.
function AreaAdvice.forKind(kind: string, level: number, mapIds: { string }?): (Area?, string?)
	local maps: { string } = mapIds or { "meadows", "duskwood", "ashen", "frostpeak" }
	local covering: Area?, coveringMap: string? = nil, nil
	local lowest: Area?, lowestMap: string? = nil, nil
	for _, mapId in maps do
		for _, area in AreaAdvice.sorted(mapId) do
			if table.find(area.kinds, kind) then
				if level >= area.lv[1] and level <= area.lv[2] and not covering then
					covering, coveringMap = area, mapId
				end
				if not lowest or area.lv[1] < (lowest :: Area).lv[1] then
					lowest, lowestMap = area, mapId
				end
			end
		end
	end
	if covering then
		return covering, coveringMap
	end
	return lowest, lowestMap
end

-- Cave whose elites (or Elite II) include monster `kind`, the lowest by level (quest targets for elite
-- kills): the cave id and the point in front of its mouth on the region map.
function AreaAdvice.caveFor(kind: string): (Areas.Cave?, { x: number, z: number }?)
	local best: Areas.Cave? = nil
	for _, cave in Areas.caves.list do
		if table.find(cave.elites, kind) or table.find(cave.elite2, kind) or table.find(cave.normal, kind) then
			if not best or cave.levels[1] < (best :: Areas.Cave).levels[1] then
				best = cave
			end
		end
	end
	if not best then
		return nil, nil
	end
	return best, Areas.arrivalOf(best.id)
end

-- Centre of an area's rectangle (map-relative).
function AreaAdvice.centre(area: Area): (number, number)
	local r = area.rect
	return (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
end

return AreaAdvice
