--!strict
-- S78 (ROZWOJ 11.5): Scout's Eye on the minimap. Pure.

local ScoutRange = {}

-- Scout's Eye (ROZWOJ 11.5): the Elite range bonus a player sees on the minimap. Own node value, or the
-- best scoutRange of a living party member on the same map within shareRange studs (x/z of the party branch).
function ScoutRange.bonus(
	own: number,
	members: { any }?,
	selfId: number,
	map: string,
	x: number,
	z: number,
	shareRange: number
): number
	local best = own
	if type(members) ~= "table" then
		return best
	end
	for _, m in members do
		if type(m) ~= "table" or m.id == selfId or m.map ~= map or m.dead == true then
			continue
		end
		local range = m.scoutRange
		if type(range) ~= "number" or range <= 0 or range <= best then
			continue
		end
		local mx, mz = m.x, m.z
		if type(mx) ~= "number" or type(mz) ~= "number" then
			continue
		end
		local dx, dz = mx - x, mz - z
		if math.sqrt(dx * dx + dz * dz) <= shareRange then
			best = range
		end
	end
	return best
end

return ScoutRange
