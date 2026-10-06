--!strict
-- Helpers for the guide path on the ground (S25): simplify the waypoints of the pathfinding (drop almost
-- collinear points, keep the ends and the jumps), the length, where the player is along the path, whether they
-- left it (farther than Config.Nav.deviate from it) and marker points every few studs ahead. Plain tables
-- instead of Vector3, so the module runs in Lune; the client converts.

local NavPath = {}

export type Point = { x: number, y: number, z: number, jump: boolean? }

-- Where a position projects on the path: segment i (points[i] -> points[i + 1]), fraction t on it, the flat
-- distance from the path, how far along the path (studs) and how much is left.
export type Progress = { segment: number, t: number, distance: number, along: number, remaining: number }

local function flatDistanceToSegment(px: number, pz: number, a: Point, b: Point): (number, number) -- distance, t (0..1)
	local dx, dz = b.x - a.x, b.z - a.z
	local lengthSq = dx * dx + dz * dz
	local t = 0
	if lengthSq > 1e-9 then
		t = math.clamp(((px - a.x) * dx + (pz - a.z) * dz) / lengthSq, 0, 1)
	end
	local cx, cz = a.x + dx * t, a.z + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2), t
end

local function segmentLength(a: Point, b: Point): number
	return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
end

-- Drops points that lie within `tolerance` studs (flat) of the line between their neighbours and change the
-- height by less than `heightTolerance`. The first and last points and jump points always stay.
function NavPath.simplify(points: { Point }, tolerance: number?, heightTolerance: number?): { Point }
	local limit = tolerance or 0.75
	local heightLimit = heightTolerance or 1.5
	if #points <= 2 then
		return table.clone(points)
	end
	local out: { Point } = { points[1] }
	for i = 2, #points - 1 do
		local anchor = out[#out]
		local point, nextPoint = points[i], points[i + 1]
		local keep = point.jump == true
		if not keep then
			local distance, t = flatDistanceToSegment(point.x, point.z, anchor, nextPoint)
			local expectedY = anchor.y + (nextPoint.y - anchor.y) * t
			keep = distance > limit or math.abs(point.y - expectedY) > heightLimit
		end
		if keep then
			table.insert(out, point)
		end
	end
	table.insert(out, points[#points])
	return out
end

-- Length of the path in studs.
function NavPath.length(points: { Point }): number
	local total = 0
	for i = 1, #points - 1 do
		total += segmentLength(points[i], points[i + 1])
	end
	return total
end

-- Where `position` is along the path. Segments before `fromSegment - 1` are skipped, so a path that loops
-- back never jumps the player to an earlier part.
function NavPath.progress(points: { Point }, position: Point, fromSegment: number?): Progress
	if #points == 0 then
		return { segment = 1, t = 0, distance = 0, along = 0, remaining = 0 }
	end
	if #points == 1 then
		local only = points[1]
		local distance = math.sqrt((position.x - only.x) ^ 2 + (position.z - only.z) ^ 2)
		return { segment = 1, t = 1, distance = distance, along = 0, remaining = distance }
	end
	local first = math.max(1, (fromSegment or 1) - 1)
	local best, bestT, bestDistance = first, 0, math.huge
	for i = first, #points - 1 do
		local distance, t = flatDistanceToSegment(position.x, position.z, points[i], points[i + 1])
		if distance < bestDistance - 1e-6 then
			best, bestT, bestDistance = i, t, distance
		end
	end
	local along = 0
	for i = 1, best - 1 do
		along += segmentLength(points[i], points[i + 1])
	end
	local current = segmentLength(points[best], points[best + 1])
	along += current * bestT
	local total = NavPath.length(points)
	return { segment = best, t = bestT, distance = bestDistance, along = along, remaining = math.max(0, total - along) }
end

-- True when `position` is farther than `limit` studs (flat) from the path.
function NavPath.deviated(points: { Point }, position: Point, limit: number, fromSegment: number?): boolean
	if #points < 2 then
		return false
	end
	return NavPath.progress(points, position, fromSegment).distance > limit
end

-- The point `distance` studs along the path (clamped to the ends) and the flat direction there.
function NavPath.at(points: { Point }, distance: number): (Point, number, number)
	if #points == 0 then
		return { x = 0, y = 0, z = 0 }, 0, -1
	end
	local left = math.max(0, distance)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = segmentLength(a, b)
		local fx, fz = b.x - a.x, b.z - a.z
		local flat = math.sqrt(fx * fx + fz * fz)
		local dx, dz = if flat > 1e-6 then fx / flat else 0, if flat > 1e-6 then fz / flat else -1
		if left <= length or i == #points - 1 then
			local t = if length > 1e-6 then math.clamp(left / length, 0, 1) else 1
			return { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t }, dx, dz
		end
		left -= length
	end
	local last = points[#points]
	return { x = last.x, y = last.y, z = last.z }, 0, -1
end

export type Marker = { x: number, y: number, z: number, dx: number, dz: number }

-- Marker positions every `spacing` studs of path distance, from just ahead of `along` up to `ahead` studs
-- further, at most `maxCount`. They sit at fixed path distances, so they do not slide while the player walks.
function NavPath.markers(points: { Point }, along: number, spacing: number, ahead: number, maxCount: number): { Marker }
	local out: { Marker } = {}
	if #points < 2 or spacing <= 0 then
		return out
	end
	local total = NavPath.length(points)
	local first = (math.floor(along / spacing) + 1) * spacing
	local distance = first
	while distance <= math.min(total, along + ahead) and #out < maxCount do
		local point, dx, dz = NavPath.at(points, distance)
		table.insert(out, { x = point.x, y = point.y, z = point.z, dx = dx, dz = dz })
		distance += spacing
	end
	return out
end

return NavPath
