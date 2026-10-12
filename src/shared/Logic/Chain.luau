--!strict
-- S79 (ROZWOJ 12.3, 14.4): the jump path of a chain spell, decided before the first hit, so the hit count (areaHits)
-- is known up front. Plain numbers, no Roblox.

local Chain = {}

export type Point = { x: number, z: number }

local function distanceSq(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return dx * dx + dz * dz
end

-- Indices into `points`: `first`, then each time the nearest not yet hit point within `radius` (flat distance,
-- ties to the lower index) of the last one, at most `jumps` entries in total.
function Chain.path(points: { Point }, first: number, radius: number, jumps: number): { number }
	local order: { number } = {}
	if points[first] == nil then
		return order
	end
	local limit = math.max(1, math.floor(jumps))
	local hit: { [number]: boolean } = { [first] = true }
	local current = first
	table.insert(order, first)
	local reach = radius * radius
	while #order < limit do
		local best: number? = nil
		local bestDistance = math.huge
		for i, point in points do
			if not hit[i] then
				local d = distanceSq(points[current], point)
				if d <= reach and d < bestDistance then
					best, bestDistance = i, d
				end
			end
		end
		if best == nil then
			break
		end
		hit[best] = true
		table.insert(order, best)
		current = best
	end
	return order
end

return Chain
