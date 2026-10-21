--!strict
-- Signposts (World/Prefabs.signpost, S19) as pure data: where every map puts one and the footprint of its board, so the
-- layouts and the tests read one source (owner 2026-10-21: the forge's "Kuźnia" board stood 0.4 studs in front of the
-- smith and hid him). The region maps put a sign by every cave entrance, where a road enters an area (`areaSigns`,
-- World/Prefabs.areaFeatures) and the map's name by its gate (`nameSign`, World/Layouts); the city's service signs are
-- Logic/TownSigns (which keeps its boards off the NPCs with `covers`). tests/signspots.spec keeps every board of every
-- map off every NPC. Pure.

local Areas = require("../Data/Areas")

local SignSpots = {}

export type Spot = { x: number, z: number, rot: number }
export type AreaSign = Spot & { nameKey: string, lv: { number } }

-- World/Prefabs.signpost: the post (0.6 x 7 x 0.6) and the board (7 wide, 2.6 high, 0.3 thick) 6 studs up and
-- 0.4 studs in front of the post (its local -Z).
SignSpots.POST = 0.6
SignSpots.BOARD_W = 7
SignSpots.BOARD_H = 2.6
SignSpots.BOARD_D = 0.3
SignSpots.BOARD_Y = 6
SignSpots.BOARD_AHEAD = 0.4
-- An NPC's footprint (studs from its spot): the R15 figure with its outfit (shoulders, a skirt, a cape) and some air,
-- so a board never stands in front of a face either.
SignSpots.NPC_RADIUS = 2

-- The cave entrance's sign in the entrance's frame (World/Prefabs.caveMouth and caveEntrances).
SignSpots.CAVE_SIGN = table.freeze({ x = -13, z = -14 })

-- The name sign of a region map by its entrance (the site, the offset and the facing; World/Layouts).
local NAME_SIGNS: { [string]: { site: string, dx: number, dz: number, rot: number } } = {
	meadows = { site = "gate", dx = 8, dz = -13, rot = 90 },
	duskwood = { site = "duskGate", dx = -8, dz = -14, rot = 90 },
	ashen = { site = "ribcage", dx = -30, dz = -16, rot = 90 },
	frostpeak = { site = "entryCairn", dx = 4, dz = 14, rot = 90 },
}

-- (lx, lz) in the frame of a prop at (x, z) turned `rot` degrees (World/Prefabs baseAt: CFrame.Angles(0, rad(rot), 0),
-- front = local -Z = (-sin rot, -cos rot)), as map coordinates.
function SignSpots.offset(x: number, z: number, rot: number, lx: number, lz: number): (number, number)
	local r = math.rad(rot)
	local c, s = math.cos(r), math.sin(r)
	return x + lx * c + lz * s, z - lx * s + lz * c
end

-- The sign of a cave entrance (its spot and facing as in Data/Areas caves).
function SignSpots.caveSign(entrance: { x: number, z: number, rot: number }): Spot
	local x, z = SignSpots.offset(entrance.x, entrance.z, entrance.rot, SignSpots.CAVE_SIGN.x, SignSpots.CAVE_SIGN.z)
	return { x = x, z = z, rot = entrance.rot + 180 }
end

-- The map's name sign by its entrance, nil for a map without one.
function SignSpots.nameSign(mapId: string): Spot?
	local def = NAME_SIGNS[mapId]
	local data = Areas.byMap[mapId]
	local site = if def and data and data.sites then data.sites[def.site] else nil
	if not def or not site then
		return nil
	end
	return { x = site.x + def.dx, z = site.z + def.dz, rot = def.rot }
end

-- The signs where roads enter the monster areas (S20): at most two per area, 12 studs inside beside the road, 60 studs
-- apart, never where `wet(x, z)` (water, streams, lava). The order and the rules of World/Prefabs.areaFeatures.
function SignSpots.areaSigns(data: Areas.MapAreas, wet: ((x: number, z: number) -> boolean)?): { AreaSign }
	local out: { AreaSign } = {}
	local function farFromSigns(x: number, z: number): boolean
		for _, other in out do
			if (x - other.x) ^ 2 + (z - other.z) ^ 2 < 60 * 60 then
				return false
			end
		end
		return true
	end
	for _, area in data.areas do
		local r = area.rect
		local placed = 0
		for _, road in data.roads do
			local p = road.points
			for i = 1, #p - 3, 2 do
				local ax, az, bx, bz = p[i], p[i + 1], p[i + 2], p[i + 3]
				local aInside = ax >= r[1] and ax <= r[3] and az >= r[2] and az <= r[4]
				local bInside = bx >= r[1] and bx <= r[3] and bz >= r[2] and bz <= r[4]
				if aInside ~= bInside and placed < 2 then
					-- Walk along the segment to the edge, then 12 studs inside, beside the road.
					local fromX, fromZ = if aInside then bx else ax, if aInside then bz else az
					local toX, toZ = if aInside then ax else bx, if aInside then az else bz
					local length = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
					local dx, dz = (toX - fromX) / length, (toZ - fromZ) / length
					local x, z = fromX, fromZ
					for step = 0, math.floor(length) do
						x, z = fromX + dx * step, fromZ + dz * step
						if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
							break
						end
					end
					x, z = x + dx * 12 - dz * (road.width / 2 + 4), z + dz * 12 + dx * (road.width / 2 + 4)
					if farFromSigns(x, z) and not (wet and wet(x, z)) then
						local facing = math.deg(math.atan2(dx, dz)) + 180
						table.insert(out, { x = x, z = z, rot = facing, nameKey = area.nameKey, lv = area.lv })
						placed += 1
					end
				end
			end
		end
	end
	return out
end

-- Every signpost of a region map (Data/Areas; the city's are Logic/TownSigns.list); `wet` as for areaSigns.
function SignSpots.forMap(mapId: string, wet: ((x: number, z: number) -> boolean)?): { Spot }
	local out: { Spot } = {}
	local data = Areas.byMap[mapId]
	if not data then
		return out
	end
	for _, entrance in data.caves do
		table.insert(out, SignSpots.caveSign(entrance))
	end
	for _, sign in SignSpots.areaSigns(data, wet) do
		table.insert(out, { x = sign.x, z = sign.z, rot = sign.rot })
	end
	local name = SignSpots.nameSign(mapId)
	if name then
		table.insert(out, name)
	end
	return out
end

-- The distance from (px, pz) to the signpost's footprint: its board (a 7 x 0.3 rectangle in front of the post) or its
-- post, whichever is nearer.
function SignSpots.distance(sign: Spot, px: number, pz: number): number
	local cx, cz = SignSpots.offset(sign.x, sign.z, sign.rot, 0, -SignSpots.BOARD_AHEAD)
	local r = math.rad(sign.rot)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = px - cx, pz - cz
	-- into the board's frame (the inverse of `offset`)
	local lx, lz = dx * c - dz * s, dx * s + dz * c
	local ex = math.max(0, math.abs(lx) - SignSpots.BOARD_W / 2)
	local ez = math.max(0, math.abs(lz) - SignSpots.BOARD_D / 2)
	local board = math.sqrt(ex * ex + ez * ez)
	local post = math.max(0, math.sqrt((px - sign.x) ^ 2 + (pz - sign.z) ^ 2) - SignSpots.POST / 2)
	return math.min(board, post)
end

-- Whether the signpost stands on the footprint of an NPC at (px, pz).
function SignSpots.covers(sign: Spot, px: number, pz: number): boolean
	return SignSpots.distance(sign, px, pz) < SignSpots.NPC_RADIUS
end

return SignSpots
