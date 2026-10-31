--!strict
-- How kit models meet the ground Roblox draws (Studio re-measure 2026-11-01). Pure.
--   * `drawn`: the drawn ground is the height function at the 4-stud columns' centres, bilinear between them
--     (Logic/TerrainLayers writes each column's surface at its centre's height), so on a steep slope it is not the
--     function at the point,
--   * `seat`: a small prop's base (a street lamp's post, a well) stands at most BURY studs in the drawn ground and its
--     low side at most GAP over it; a base on uneven ground gets a level spot first (Logic/LotPads spots, so in the
--     city the ground under every base is even),
--   * `cliff` / `prune`: a rock or a tree that cannot stand on its spot is left out of the generator's Builds (the
--     same on the server and every client): a rock on a ravine's lip (Util/KitAssets would sink it to the ravine's
--     foot), a tree whose crown would reach into a wall above it, and (Studio 2026-11-01: a ravine pine 12.6 studs
--     deep, a rock at a cliff's foot 7.9) anything whose footprint's ground rises more than DEEP over its model's foot.

local Kit = require("../Data/Kit")
local TerrainLayers = require("./TerrainLayers")

local KitSeat = {}

-- the most a small prop's base stands in the ground, and its low side over it
KitSeat.BURY = 0.5
KitSeat.GAP = 0.05
-- radius of a street lamp's post base and of a well's stones (the city's props, Logic/TownGen)
KitSeat.LAMP = 1
KitSeat.WELL = 3
-- a rock is left out where the drawn ground under its base (ROCK of its width round it) varies by more than RISE of
-- its width (and 1.5 studs)
KitSeat.ROCK = 0.4
KitSeat.RISE = 0.6
-- a tree is left out where the drawn ground within CROWN of its height rises more than WALL of its height over its foot
KitSeat.CROWN = 0.4
KitSeat.WALL = 0.35
-- the part of a model's width round its foot whose lowest ground it sinks to (Util/KitAssets: a rock's base, a
-- trunk), and a tree model's width against its height (the assets' crowns, Studio 2026-11-01)
KitSeat.BASE = { rock = 0.5, tree = 0.1 } :: { [string]: number }
KitSeat.TREE_WIDTH = 0.6
-- a rock's footprint reaches FOOTPRINT of its width from its middle (a turned box's corners), a tree's CROWN of its
-- height; nothing stands where the drawn ground under it rises more than DEEP over its model's foot
KitSeat.FOOTPRINT = 0.7
KitSeat.DEEP = 4.5

export type Height = (x: number, z: number) -> number

-- The drawn ground at (x, z): the heights at the 4-stud columns' centres round it, bilinear.
function KitSeat.drawn(height: Height, x: number, z: number): number
	local V = TerrainLayers.VOXEL
	local fx, fz = (x - V / 2) / V, (z - V / 2) / V
	local i, k = math.floor(fx), math.floor(fz)
	local tx, tz = fx - i, fz - k
	local x0, z0 = V * i + V / 2, V * k + V / 2
	local a, b = height(x0, z0), height(x0 + V, z0)
	local c, d = height(x0, z0 + V), height(x0 + V, z0 + V)
	return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz
end

-- The lowest and the highest drawn ground under a round base of radius `r` at (x, z): its middle, half way out and
-- its edge.
function KitSeat.range(height: Height, x: number, z: number, r: number): (number, number)
	local g = KitSeat.drawn(height, x, z)
	local lo, hi = g, g
	for ring = 1, 2 do
		for i = 0, 11 do
			local a = i * math.pi / 6
			local e = KitSeat.drawn(height, x + math.cos(a) * r * ring / 2, z + math.sin(a) * r * ring / 2)
			lo, hi = math.min(lo, e), math.max(hi, e)
		end
	end
	return lo, hi
end

-- The foot (map-relative y) of a small prop whose base of radius `r` stands at (x, z) on the ground `height`.
function KitSeat.seat(height: Height, x: number, z: number, r: number): number
	local lo, hi = KitSeat.range(height, x, z, r)
	return math.max(lo - KitSeat.GAP, hi - KitSeat.BURY)
end

-- Whether the kit slot `key` (scale `s`, Data/Kit) with its foot at (x, y, z) cannot stand there: a rock on a cliff's
-- lip, a tree with a wall in its crown, either deeper than DEEP under its footprint. Other slots always can. `columns`
-- (optional) is `height` at the columns' centres only, cached (KitSeat.prune).
function KitSeat.cliff(
	height: Height,
	key: string,
	s: number,
	x: number,
	y: number,
	z: number,
	columns: Height?
): boolean
	local kind = if key == "rock" then "rock" elseif string.sub(key, 1, 5) == "tree:" then "tree" else nil
	local entry = kind and Kit.slots[key]
	if not entry then
		return false
	end
	local rock = kind == "rock"
	local size = entry.size * s
	local r = size * (if rock then KitSeat.ROCK else KitSeat.CROWN)
	local reach = if rock then size * KitSeat.FOOTPRINT else r
	local limit = if rock then math.max(1.5, size * KitSeat.RISE) else size * KitSeat.WALL
	-- a first look at the function itself four ways round the footprint: most spots are nowhere near a cliff (the
	-- model's foot is never under the lowest of them)
	local lo, hi = y, y
	for i = 0, 3 do
		local a = i * math.pi / 2
		local g = height(x + math.cos(a) * reach, z + math.sin(a) * reach)
		lo, hi = math.min(lo, g), math.max(hi, g)
	end
	if (if rock then hi - lo else hi - y) < limit / 2 and hi - lo < KitSeat.DEEP / 2 then
		return false
	end
	local ground = columns or height
	lo, hi = KitSeat.range(ground, x, z, r)
	if (if rock then hi - lo else hi - y) > limit then
		return true
	end
	-- the model's own foot: the lowest ground on a ring round it (Util/KitAssets), then the deepest it stands
	local ring = if rock then size * KitSeat.BASE.rock else size * KitSeat.BASE.tree * KitSeat.TREE_WIDTH
	local foot = y
	for i = 0, 6 do
		local a = i * math.pi / 3
		local m = math.min(i, 1)
		foot = math.min(foot, height(x + math.cos(a) * ring * m, z + math.sin(a) * ring * m) - 0.1)
	end
	local _, top = KitSeat.range(ground, x, z, reach)
	return top - foot > KitSeat.DEEP
end

-- Leaves out of `builds` (a height-field map's, map-relative) the rock and tree slots that cannot stand on the ground
-- `height` (their pieces too, Blueprint.dropKit), and their entries in `trees` (the generator's tree list). Returns
-- how many it left out.
function KitSeat.prune(builds: { any }, height: Height, trees: { any }?): number
	-- the columns' heights, once each
	local columns: { [number]: number } = {}
	local function cached(x: number, z: number): number
		local id = math.floor(x) * 65536 + math.floor(z)
		local h = columns[id]
		if not h then
			h = height(x, z)
			columns[id] = h
		end
		return h :: number
	end
	local gone = 0
	for _, b in builds do
		local bp = b.bp
		local kits = bp and bp.kits
		if kits and #kits > 0 then
			local r = math.rad(b.at.rot or 0)
			local c, s = math.cos(r), math.sin(r)
			for i = #kits, 1, -1 do
				local slot = kits[i]
				local lx, lz = slot.p[1], slot.p[3]
				local x, z = b.at.x + lx * c + lz * s, b.at.z - lx * s + lz * c
				if KitSeat.cliff(height, slot.key, slot.s, x, b.at.y + slot.p[2], z, cached) then
					bp:dropKit(i)
					gone += 1
					if trees then
						for k = #trees, 1, -1 do
							local t = trees[k]
							if math.abs(t.x - x) < 0.5 and math.abs(t.z - z) < 0.5 then
								table.remove(trees, k)
							end
						end
					end
				end
			end
		end
	end
	return gone
end

return KitSeat
