--!strict
-- Pure geometry of Hunter skills (S76): trap layouts and the poison / mark spread targets. Flat x, z numbers only
-- (works in Lune), like Logic/Knockback.

local SkillGeom = {}

export type Point = { x: number, z: number }
export type Candidate = { id: string, x: number, z: number }

-- `count` points: the first at (x, z), the next ones alternately right and left of the line (fromX, fromZ) -> (x, z),
-- perpendicular to it, offset x ceil((i - 1) / 2) away (2nd +offset right, 3rd offset left, 4th 2 x offset right...).
-- A caster standing on the point faces (0, -1), as Knockback.direction's default.
function SkillGeom.sidePoints(
	fromX: number,
	fromZ: number,
	x: number,
	z: number,
	count: number,
	offset: number
): { Point }
	local dx, dz = x - fromX, z - fromZ
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.05 then
		dx, dz = 0, -1
	else
		dx, dz = dx / length, dz / length
	end
	-- right of the direction (dx, dz) on the ground plane
	local rx, rz = -dz, dx
	local out: { Point } = {}
	for i = 1, math.max(0, count) do
		local step = math.ceil((i - 1) / 2) * offset
		local side = if i % 2 == 0 then 1 else -1
		table.insert(out, { x = x + rx * step * side, z = z + rz * step * side })
	end
	return out
end

-- `count` points on the circle of `radius` around (x, z), 2 pi / count apart, the first at `startAngle` (radians,
-- measured from +x toward +z).
function SkillGeom.ringPoints(x: number, z: number, radius: number, count: number, startAngle: number): { Point }
	local out: { Point } = {}
	local n = math.max(0, count)
	for i = 1, n do
		local angle = startAngle + (i - 1) * 2 * math.pi / n
		table.insert(out, { x = x + math.cos(angle) * radius, z = z + math.sin(angle) * radius })
	end
	return out
end

-- Angle (radians, as ringPoints) of the direction (fromX, fromZ) -> (x, z); (0, -1) when they meet.
function SkillGeom.angle(fromX: number, fromZ: number, x: number, z: number): number
	local dx, dz = x - fromX, z - fromZ
	if dx * dx + dz * dz < 0.0025 then
		dx, dz = 0, -1
	end
	return math.atan2(dz, dx)
end

-- Ids of the nearest candidates within `radius` (flat) of (fromX, fromZ), nearest first (a tie by id), at most
-- `count`; count <= 0 gives none.
function SkillGeom.spreadTargets(
	fromX: number,
	fromZ: number,
	candidates: { Candidate },
	count: number,
	radius: number
): { string }
	if count <= 0 then
		return {}
	end
	local near: { { id: string, d: number } } = {}
	for _, c in candidates do
		local dx, dz = c.x - fromX, c.z - fromZ
		local d = math.sqrt(dx * dx + dz * dz)
		if d <= radius then
			table.insert(near, { id = c.id, d = d })
		end
	end
	table.sort(near, function(a, b)
		if math.abs(a.d - b.d) > 1e-9 then
			return a.d < b.d
		end
		return a.id < b.id
	end)
	local out: { string } = {}
	for i = 1, math.min(count, #near) do
		table.insert(out, near[i].id)
	end
	return out
end

return SkillGeom
