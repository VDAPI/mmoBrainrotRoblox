local Bosses = require("../src/shared/Data/Bosses")
local function run(def, cds, order)
	local attacks = {}
	for _, a in def.attacks do local c = table.clone(a); c.cooldown = cds[a.id] or a.cooldown; table.insert(attacks, c) end
	if order then table.sort(attacks, function(x, y) return (table.find(order, x.id) or 99) < (table.find(order, y.id) or 99) end) end
	local next, counts = {}, {}
	for _, a in attacks do next[a.id] = 5; counts[a.id] = 0 end
	local global, t = 4, 0
	while t < 1200 do
		if t >= global then
			for _, a in attacks do
				if table.find(a.phases, 3) and t >= next[a.id] then
					next[a.id] = t + a.cooldown; global = t + a.windup + 2.2; counts[a.id] += 1; break
				end
			end
		end
		t += 0.05
	end
	local parts = {}
	for _, a in attacks do table.insert(parts, string.format("%s %.1f/min (max %.1f)", a.id, counts[a.id] / 20, 60 / a.cooldown)) end
	return table.concat(parts, ", ")
end
local az = Bosses.byId.azgor
print("current:", run(az, {}))
print("fireWave 9, meteor 12:", run(az, { fireWave = 9, meteor = 12 }))
print("fireWave 10, flameCleave 11, meteor 14:", run(az, { fireWave = 10, flameCleave = 11, meteor = 14 }))
print("inferno first:", run(az, {}, { "inferno", "fireWave", "flameCleave", "meteor" }))
local vg = Bosses.byId.vaelgrath
print("vaelgrath current:", run(vg, {}))
print("vaelgrath glacialRing first:", run(vg, {}, { "glacialRing", "frostBreath", "wingBuffet", "tailSwipe", "blizzard" }))
