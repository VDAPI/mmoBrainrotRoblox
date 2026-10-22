--!strict
-- W28 (owner: "the purple is not in the portal's frame", "more entrances are broken", "E" at the boss gate at the
-- wrong distance): every portal, cave mouth, cave exit and dungeon gate of Data/Portals against the dressing of its
-- map (Logic/WorldGen): nothing reaches into the arch or the gate, every frame stands in its portal's own frame, the
-- field fits the arch, the "E" prompt and the server's range share one point and one distance, landings are walkable.

local fs = require("@lune/fs")

local Areas = require("../src/shared/Data/Areas")
local ArchFit = require("../src/shared/Logic/ArchFit")
local CaveMouth = require("../src/shared/Data/CaveMouth")
local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local PortalClearance = require("./PortalClearance")
local Portals = require("../src/shared/Data/Portals")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Test = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- Frames the owner's reports were about (W28): they must keep standing in their portal's frame.
local FRAMED = {
	"duskwood_cave_exit", -- CryptGate (Crypt of the Forgotten)
	"dungeon_duskwood", -- SealLintel
	"duskwood_den_exit",
	"duskwood_barrow_exit",
	"ashen_mine_exit",
	"frostpeak_grotto_exit",
	"frostpeak_hold_exit",
	"dungeon_frostpeak",
	"dungeon_meadows",
	"duskwood_duskwood_cave", -- the facade over the Crypt on Duskwood
	"duskwood_duskwood_den",
	"duskwood_duskwood_barrow",
	"ashen_ashen_mine",
	"ashen_ashen_lair",
	"ashen_ashen_cave",
	"frostpeak_frostpeak_grotto",
	"frostpeak_frostpeak_hold",
	"frostpeak_frostpeak_cave",
	"meadows_meadows_cave",
}

local function read(path: string): string
	return fs.readFile(path)
end

describe("Portals: frames and fields (W28)", function()
	it("keeps every dressing piece of every map out of its portals' arches and gates", function()
		local bad = {}
		for _, mapId in WorldGen.maps() do
			for _, h in PortalClearance.hits(mapId) do
				table.insert(
					bad,
					string.format(
						"%s: %s piece %d (%.1f x %.1f x %.1f) at %.1f, %.1f, %.1f in the portal's frame",
						h.portal,
						h.build,
						h.piece,
						h.size[1],
						h.size[2],
						h.size[3],
						h.at[1],
						h.at[2],
						h.at[3]
					)
				)
			end
		end
		if #bad > 0 then
			error(table.concat(bad, "\n"))
		end
	end)

	it("stands every frame in its portal's own frame (same yaw, the portal on its axis)", function()
		local found: { [string]: boolean } = {}
		for _, mapId in WorldGen.maps() do
			local gen = assert(WorldGen.get(mapId))
			for _, b in gen.all() do
				local id = b.frames
				if id then
					local p = Portals.get(id)
					if not p or p.map ~= mapId then
						error(`{mapId} {b.name}: frames {id}, not a portal of this map`)
					end
					local r = math.rad(p.rot)
					local dx, dz = b.at.x - p.x, b.at.z - p.z
					-- the build's origin in the portal's frame: across (x) and along its axis (z)
					local across = math.cos(r) * dx - math.sin(r) * dz
					local along = math.sin(r) * dx + math.cos(r) * dz
					if math.abs(across) > 0.05 or along < -0.05 or along > 25 then
						error(`{mapId} {b.name}: {across}, {along} off the portal {id}`)
					end
					expect((b.at.rot - p.rot) % 360).toBe(0)
					found[id] = true
				end
			end
		end
		for _, id in FRAMED do
			if not found[id] then
				error(`no frame round the portal {id}`)
			end
		end
	end)

	it("fits the purple field between the arch's pillars and under its top, the red door between the horns", function()
		local arch, gate = Portals.ARCH, Portals.GATE
		expect(arch.field.w / 2 <= arch.pillarX - 1.25).toBe(true)
		expect(arch.field.y + arch.field.h / 2 < arch.height).toBe(true)
		expect(arch.field.y - arch.field.h / 2 > 0).toBe(true)
		expect(gate.door.w / 2 < gate.hornX - 1.5).toBe(true)
		expect(gate.door.y + gate.door.h / 2 <= gate.height).toBe(true)
		for _, kind in { "portal", "cave", "exit" } do
			local box = assert(Portals.clearance(kind :: any))
			expect(box.half[1] >= arch.pillarX + 1.25).toBe(true)
			expect(box.center[2] + box.half[2] >= arch.height).toBe(true)
		end
		local prefabs = read("src/server/World/Prefabs.luau")
		expect(string.find(prefabs, "fitModel(painted, base, field)", 1, true) ~= nil).toBe(true)
		expect(string.find(prefabs, "Portals.GATE.door.w", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Portals: the E prompt and the server (W28)", function()
	it("lets the server accept every press the prompt allows, from the same part", function()
		expect(Portals.SERVER_RANGE >= Portals.PROMPT_RANGE + 6).toBe(true)
		expect(Portals.PROMPT_RANGE >= 8 and Portals.PROMPT_RANGE <= 14).toBe(true)
		local world = read("src/client/Controllers/WorldController.luau")
		local dungeon = read("src/client/Controllers/DungeonController.luau")
		local travel = read("src/server/Services/TravelService.luau")
		local service = read("src/server/Services/DungeonService.luau")
		expect(string.find(world, "MaxActivationDistance = Portals.PROMPT_RANGE", 1, true) ~= nil).toBe(true)
		expect(string.find(dungeon, "MaxActivationDistance = Portals.PROMPT_RANGE", 1, true) ~= nil).toBe(true)
		expect(string.find(travel, "local PORTAL_RANGE = Portals.SERVER_RANGE", 1, true) ~= nil).toBe(true)
		-- the gate's range from the door the prompt hangs on (the PrimaryPart of the tagged gate)
		expect(string.find(service, "local function gatePosition", 1, true) ~= nil).toBe(true)
		expect(string.find(service, "(range or Portals.SERVER_RANGE)", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Portals: landings (W28)", function()
	it("lands travellers out of a cave or a portal on walkable ground of the target map", function()
		for _, p in Portals.list do
			local target = p.target
			local at = p.arrive -- cave exits: Data/Areas.arrivalOf, boss chambers: before the gate
			if at and MapTerrain.has(target) and MapTerrain.height(target, at.x, at.z) ~= nil then
				if not MapTerrain.walkable(target, at.x, at.z, 4) then
					error(`{p.id}: lands on {target} at {at.x}, {at.z}, not walkable`)
				end
			end
		end
	end)
end)

-- W30 (owner 2026-10-21: "nadal portale są zepsute wyglądowo") -----------------------------------------------------

-- The portal frame's local point (a across, b along its axis) on its map, map-relative x, z.
local function onMap(p: Portals.Portal, a: number, b: number): (number, number)
	local r = math.rad(p.rot)
	return p.x + a * math.cos(r) + b * math.sin(r), p.z - a * math.sin(r) + b * math.cos(r)
end

-- Every field a portal's look is drawn in: the arch's (Prefabs.portal; with the painted model it only shrinks) and
-- each city gate's (the "portal" piece of its gatehouse, TownGen).
local function gateFields(): { { name: string, w: number, h: number, piece: any, build: any } }
	local out = {}
	for _, b in TownGen.all(Town.city, TownTerrain.heightAt) :: any do
		for _, piece in b.bp.pieces do
			if piece.tag == "portal" then
				table.insert(out, { name = b.name, w = piece.size[1], h = piece.size[2], piece = piece, build = b })
			end
		end
	end
	return out
end

describe("Portals: the look stays inside the frame (W30)", function()
	it("draws the veil and the core as ellipses inside the field, the core inside the veil", function()
		local fields = { { name = "arch", w = Portals.ARCH.field.w, h = Portals.ARCH.field.h } }
		for _, g in gateFields() do
			table.insert(fields, { name = g.name, w = g.w, h = g.h })
		end
		expect(#fields).toBe(5)
		for _, f in fields do
			local look = Portals.look(f.w, f.h)
			if look.veil.w > f.w or look.veil.h > f.h then
				error(`{f.name}: the veil {look.veil.w} x {look.veil.h} is larger than its field {f.w} x {f.h}`)
			end
			-- the core's box corners inside the veil's ellipse (the core and its sparkles' source)
			local ex = (look.core.w / look.veil.w) ^ 2 + (look.core.h / look.veil.h) ^ 2
			if ex > 1 then
				error(`{f.name}: the core's corners stand outside the veil ({ex})`)
			end
			-- a sparkle from anywhere in the core's box never leaves the field
			if look.core.w / 2 + look.sparkleReach > f.w / 2 or look.core.h / 2 + look.sparkleReach > f.h / 2 then
				error(`{f.name}: sparkles reach {look.sparkleReach} past the core, out of the field`)
			end
			-- the swirl (a round image in a square particle) within the core's width and height
			expect(look.swirl <= math.min(look.core.w, look.core.h)).toBe(true)
		end
		-- the core and the veil never in one plane (no flicker)
		expect(Portals.LOOK.gap > Portals.LOOK.thick).toBe(true)
	end)

	it("keeps the arch's veil between the pillars, under the lintel and above the ground", function()
		local arch = Portals.ARCH
		local look = Portals.look(arch.field.w, arch.field.h)
		expect(look.veil.w / 2 <= arch.pillarX - 1.25 - 0.4).toBe(true)
		expect(arch.field.y + look.veil.h / 2 <= 16 - 1.25 - 0.4).toBe(true) -- the lintel is 2.5 thick at 16
		expect(arch.field.y - look.veil.h / 2 >= 0.4).toBe(true)
	end)

	it(
		"keeps each city gate's veil out of its gatehouse's stones (passage walls, corner stones, portcullis)",
		function()
			for _, g in gateFields() do
				local look = Portals.look(g.w, g.h)
				local field = g.piece
				for _, other in g.build.bp.pieces do
					-- the gatehouse's solid stones (the barrier is invisible, lights and the field itself are not stones)
					if other ~= field and other.tag ~= "barrier" and other.tag ~= "portal" and (other.t or 0) < 1 then
						local inv = {
							other.r[1],
							other.r[4],
							other.r[7],
							other.r[2],
							other.r[5],
							other.r[8],
							other.r[3],
							other.r[6],
							other.r[9],
						}
						for i = 0, 35 do
							local ang = i * math.pi / 18
							for _, k in { 1, 0.7, 0.4 } do
								-- a point of the veil in the field's own frame, then in the build and in the stone's frame
								local lx = math.cos(ang) * look.veil.w / 2 * k
								local ly = math.sin(ang) * look.veil.h / 2 * k
								local fr = field.r
								local bx = field.p[1] + fr[1] * lx + fr[2] * ly
								local by = field.p[2] + fr[4] * lx + fr[5] * ly
								local bz = field.p[3] + fr[7] * lx + fr[8] * ly
								local d = { bx - other.p[1], by - other.p[2], bz - other.p[3] }
								local q = {
									inv[1] * d[1] + inv[2] * d[2] + inv[3] * d[3],
									inv[4] * d[1] + inv[5] * d[2] + inv[6] * d[3],
									inv[7] * d[1] + inv[8] * d[2] + inv[9] * d[3],
								}
								local inBox = math.abs(q[1]) < other.size[1] / 2 - 0.05
									and math.abs(q[2]) < other.size[2] / 2 - 0.05
									and math.abs(q[3]) < other.size[3] / 2 - 0.05
								-- a wedge fills the half of its box under the slope from its top back edge to its bottom front
								if inBox and other.s == "wedge" then
									inBox = q[2] / other.size[2] < q[3] / other.size[3] - 0.01
								end
								if inBox then
									error(
										string.format(
											"%s: the veil runs through a %s piece at %.1f, %.1f",
											g.name,
											other.m,
											lx,
											ly
										)
									)
								end
							end
						end
					end
				end
			end
		end
	)

	it("builds the look from Data/Portals: invisible trigger field, ellipses, swirl in the field's plane", function()
		local prefabs = read("src/server/World/Prefabs.luau")
		for _, needle in
			{
				"portalLook(ctx, model, field)",
				"field.Transparency = 1",
				"mesh.MeshType = Enum.MeshType.Sphere",
				"Enum.ParticleOrientation.VelocityPerpendicular",
				'VfxTextures.idOf("swirl")',
				"sparkles.Parent = core",
				"Portals.GATE.lintel",
			}
		do
			if not string.find(prefabs, needle, 1, true) then
				error(`Prefabs.luau: missing {needle}`)
			end
		end
		-- the old sparkles flew up out of the arch (EmissionDirection Top, 3 studs a second for 2 s)
		expect(string.find(prefabs, "sparkles.Speed = NumberRange.new(1, 3)", 1, true)).toBe(nil)
	end)

	it("keeps the dungeon gate's red door out of its horns (W31: upright, 0.2 studs off the door)", function()
		local gate = Portals.GATE
		local door = gate.door
		local top = gate.lintel.y + gate.lintel.h / 2
		for _, side in { -1, 1 } do
			local hit = PortalClearance.overlaps(
				{ side * gate.hornX, (top - 1) / 2, 0 },
				{ 1, 0, 0, 0, 1, 0, 0, 0, 1 },
				{ gate.horn / 2, (top + 1) / 2, gate.horn / 2 },
				{ 0, door.y, 0 },
				{ door.w / 2, door.h / 2, door.d / 2 }
			)
			expect(hit).toBe(false)
		end
	end)
end)

describe("Portals: frames on the ground, not in the rock (W30)", function()
	it("stands every portal of a map with a height function on level ground: no terrain in the arch", function()
		local bad = {}
		for _, p in Portals.list do
			local h0 = MapTerrain.has(p.map) and MapTerrain.height(p.map, p.x, p.z)
			if h0 then
				local half = if p.kind == "dungeon" then Portals.GATE.hornX + 1.5 else Portals.ARCH.pillarX + 1.25
				local worst = 0
				for a = -half, half, 0.5 do
					for b = -1.5, 1.5, 0.5 do
						local x, z = onMap(p, a, b)
						local h = MapTerrain.height(p.map, x, z)
						if h then
							worst = math.max(worst, math.abs(h - h0))
						end
					end
				end
				if worst > 0.75 then
					table.insert(
						bad,
						string.format("%s on %s: the ground under the arch differs by %.1f", p.id, p.map, worst)
					)
				end
			end
		end
		if #bad > 0 then
			error(table.concat(bad, "\n"))
		end
	end)

	it("gives every portal in a cave open air under the whole arch", function()
		for _, p in Portals.list do
			local cave = CaveTerrain.get(p.map)
			if cave then
				local half = if p.kind == "dungeon" then Portals.GATE.hornX + 1.5 else Portals.ARCH.pillarX + 1.25
				local h0 = cave.floor(p.x, p.z) or 0
				for a = -half, half, 0.5 do
					for b = -1.5, 1.5, 0.5 do
						local x, z = onMap(p, a, b)
						local floor, ceiling = cave.floor(x, z), cave.ceiling(x, z)
						if not floor or not ceiling then
							error(`{p.id}: rock in the arch at {a}, {b}`)
						end
						if ceiling - h0 < Portals.ARCH.height + 2 then
							error(`{p.id}: the ceiling {ceiling - h0} over the arch at {a}, {b}`)
						end
					end
				end
			end
		end
	end)
end)

-- W31 (Studio review 2026-10-21 on main 79328cbb: painted pillars inside the cave frames' slabs, dark holes off the
-- veil, a lava backdrop behind the purple, arches facing the void, unframed boss doors) -------------------------------

-- The mouths dressed by another session (the Moss Cave's water curtain, Logic/MeadowsGen/Water) stay out of the
-- strict check; the generic mouth they stand in (Prefabs.caveMouth, Data/CaveMouth) has its own tests/cavemouth.spec.
local OWN_DRESSING = { meadows_meadows_cave = true, meadows_cave_exit = true }

local function dark(hex: string): boolean
	local r, g, b =
		tonumber(string.sub(hex, 2, 3), 16), tonumber(string.sub(hex, 4, 5), 16), tonumber(string.sub(hex, 6, 7), 16)
	return (r or 255) < 24 and (g or 255) < 24 and (b or 255) < 24
end

-- What a frame round a cave mouth or a cave exit (`kind`) keeps free: every placed piece against the boxes of
-- Data/Portals.frameKeepOut (an exit has no hole: no "opening" box), the hole excepted.
local function keepOutHits(placed: { PortalClearance.Placed }, kind: string, hole: PortalClearance.Placed?): { string }
	local bad = {}
	for _, box in Portals.frameKeepOut() do
		if box.name ~= "opening" or kind == "cave" then
			for _, q in placed do
				if q ~= hole and PortalClearance.inBox(q, box.center, box.half) then
					table.insert(
						bad,
						string.format(
							"%s #%d (%s %.1f x %.1f x %.1f) at %.1f, %.1f, %.1f in the %s",
							q.build,
							q.piece,
							q.shape,
							q.h[1] * 2,
							q.h[2] * 2,
							q.h[3] * 2,
							q.c[1],
							q.c[2],
							q.c[3],
							box.name
						)
					)
				end
			end
		end
	end
	return bad
end

-- The hole of a cave mouth: the dark piece nearest behind the arch that covers the veil's centre.
local function holeOf(placed: { PortalClearance.Placed }): PortalClearance.Placed?
	local veilY = Portals.ARCH.field.y
	local best: PortalClearance.Placed?, bestZ = nil, math.huge
	for _, q in placed do
		if dark(q.color) then
			local x0, x1 = PortalClearance.extent(q, 1)
			local y0, y1 = PortalClearance.extent(q, 2)
			local z0 = PortalClearance.extent(q, 3)
			if x0 <= 0 and x1 >= 0 and y0 <= veilY and y1 >= veilY and z0 >= 0 and z0 < bestZ then
				best, bestZ = q, z0
			end
		end
	end
	return best
end

local function holeProblems(id: string, hole: PortalClearance.Placed?): { string }
	if not hole then
		return { `{id}: no dark hole behind the arch` }
	end
	local H, m = Portals.HOLE, Portals.ARCH.model
	local x0, x1 = PortalClearance.extent(hole, 1)
	local y0, y1 = PortalClearance.extent(hole, 2)
	local z0 = PortalClearance.extent(hole, 3)
	local out = {}
	local cx, cy = (x0 + x1) / 2, (math.max(y0, 0) + y1) / 2
	if math.abs(cx) > H.tolerance.x then
		table.insert(out, string.format("%s: the hole's centre %.2f across the axis", id, cx))
	end
	if math.abs(cy - Portals.ARCH.field.y) > H.tolerance.y then
		table.insert(
			out,
			string.format("%s: the hole's visible centre at %.2f, the veil's at %.2f", id, cy, Portals.ARCH.field.y)
		)
	end
	if x1 - x0 < H.w - 0.01 or y0 > 0 or y1 < H.top - 0.01 then
		table.insert(
			out,
			string.format("%s: the hole %.1f x %.1f..%.1f does not fill the arch's opening", id, x1 - x0, y0, y1)
		)
	end
	if z0 < m.d / 2 + Portals.VIEW.margin or z0 > H.z + 0.5 then
		table.insert(
			out,
			string.format("%s: the hole's face %.2f behind the portal (straight behind the arch: %.2f)", id, z0, H.z)
		)
	end
	return out
end

describe("Portals: cave mouths round the painted arch (W31)", function()
	it("keeps every piece out of the painted arch, its view from the path and the opening before the hole", function()
		local bad = {}
		local seen = 0
		for _, p in Portals.list do
			if (p.kind == "cave" or p.kind == "exit") and not OWN_DRESSING[p.id] and WorldGen.get(p.map) then
				seen += 1
				local placed = PortalClearance.around(p.map, p.id, 40)
				local hole = if p.kind == "cave" then holeOf(placed) else nil
				for _, line in keepOutHits(placed, p.kind, hole) do
					table.insert(bad, `{p.id}: {line}`)
				end
			end
		end
		expect(seen >= 20).toBe(true)
		if #bad > 0 then
			error(table.concat(bad, "\n"))
		end
	end)

	it(
		"puts a dark hole straight behind every dressed cave mouth's arch, centred on the veil and filling the opening",
		function()
			local bad = {}
			for _, p in Portals.list do
				if p.kind == "cave" and not OWN_DRESSING[p.id] and WorldGen.get(p.map) then
					local frames = false
					for _, b in assert(WorldGen.get(p.map)).all() do
						frames = frames or b.frames == p.id
					end
					if frames then
						for _, line in holeProblems(p.id, holeOf(PortalClearance.around(p.map, p.id, 40))) do
							table.insert(bad, line)
						end
					end
				end
			end
			if #bad > 0 then
				error(table.concat(bad, "\n"))
			end
		end
	)

	it(
		"keeps the terrain out of the way to every cave mouth's hole (W31, Studio: the lair's hill, the Moss Cave)",
		function()
			local bad = {}
			for _, p in Portals.list do
				local h0 = p.kind == "cave" and MapTerrain.has(p.map) and MapTerrain.height(p.map, p.x, p.z)
				if h0 then
					local worst = 0
					for a = -Portals.HOLE.w / 2, Portals.HOLE.w / 2, 0.5 do
						-- to a stud past the hole's back (Studio: the Moss Cave's voxels 1 stud before its face)
						for b = 0, Portals.HOLE.z + Portals.HOLE.d + 1, 0.5 do
							local x, z = onMap(p, a, b)
							local h = MapTerrain.height(p.map, x, z)
							if h then
								worst = math.max(worst, h - h0)
							end
						end
					end
					if worst > 0.5 then
						table.insert(
							bad,
							string.format("%s on %s: terrain rises %.1f in front of the hole", p.id, p.map, worst)
						)
					end
				end
			end
			if #bad > 0 then
				error(table.concat(bad, "\n"))
			end
		end
	)

	it("keeps the painted arch at full size and its veil in the opening down to the ground (W31 regression)", function()
		-- the box of common_portal_02 measured in Studio at 18 studs tall: 16 across, 20.9 deep with its base slab,
		-- the slab sunk 1.5 studs (the arch stood at a third of its size when it was fitted into 16 x 18 x 6)
		local lo, hi = { -8, -1.5, -10.45 }, { 8, 16.5, 10.45 }
		local fit = ArchFit.fit(lo, hi)
		expect(fit.turn).toBe(true)
		expect(math.abs(fit.scale - 1) < 1e-6).toBe(true)
		local f = fit.field
		local spec = Portals.ARCH.field
		expect(math.abs(f.w - spec.w) < 1e-6).toBe(true) -- 9.5 (the veil 8.55)
		expect(math.abs(f.h - spec.h) < 1e-6).toBe(true) -- 13.5 (the veil 12.7)
		local bottom = f.y - f.h / 2
		expect(bottom <= 0 and bottom >= -1.5).toBe(true) -- down to the ground, not floating
		expect(math.abs(f.x) < 1e-6 and math.abs(f.z) < 1e-6).toBe(true)
		-- the veil's ellipse in that field
		local look = Portals.look(f.w, f.h)
		expect(look.veil.w >= 8.5 and look.veil.h >= 12.5).toBe(true)
		-- a model already across the portal is not turned; its field follows its foot
		local across = ArchFit.fit({ -10.45, 0, -8 }, { 10.45, 18, 8 })
		expect(across.turn).toBe(false)
		expect(math.abs(across.field.y - across.field.h / 2 - ArchFit.FOOT) < 1e-6).toBe(true)
		local prefabs = read("src/server/World/Prefabs.luau")
		for _, needle in { "ArchFit.fit(", "local function fitModel", "Portals.palette(ctx.map.id)" } do
			if not string.find(prefabs, needle, 1, true) then
				error(`Prefabs.luau: missing {needle}`)
			end
		end
		-- nothing scales the painted model by a box any more
		local from = assert(string.find(prefabs, "local function fitModel(", 1, true))
		local body = string.sub(prefabs, from, (string.find(prefabs, "\nend\n", from, true)))
		expect(string.find(body, "ARCH.model", 1, true)).toBe(nil)
		expect(string.find(body, "fit.scale", 1, true) ~= nil).toBe(true)
	end)

	it("frames the cave exits too (light themed frames round the arch)", function()
		local found: { [string]: boolean } = {}
		for _, mapId in WorldGen.maps() do
			for _, b in assert(WorldGen.get(mapId)).all() do
				if b.frames then
					found[b.frames] = true
				end
			end
		end
		for _, p in Portals.list do
			if p.kind == "exit" and Areas.caves.get(p.map) and not OWN_DRESSING[p.id] and not found[p.id] then
				error(`no frame round the exit {p.id}`)
			end
		end
	end)
end)

describe("Portals: every arch faces its way in (W31)", function()
	it("turns the arches of the region maps to the map's middle and the cave portals to the open room", function()
		local bad = {}
		for _, p in Portals.list do
			local r = math.rad(p.rot)
			local fx, fz = -math.sin(r), -math.cos(r) -- the face (local -z)
			local cave = CaveTerrain.get(p.map)
			if cave then
				local function rockAt(sign: number): number
					for d = 1, 80 do
						local x, z = p.x + fx * d * sign, p.z + fz * d * sign
						if not cave.floor(x, z) then
							return d
						end
					end
					return 99
				end
				local front, back = rockAt(1), rockAt(-1)
				if front < 12 or front < back then
					table.insert(bad, `{p.id}: rock {front} studs before its face, {back} behind it`)
				end
			elseif p.kind ~= "gate" and MapTerrain.has(p.map) then
				local d = math.sqrt(p.x * p.x + p.z * p.z)
				local dot = (fx * -p.x + fz * -p.z) / d
				if dot < 0.5 then
					table.insert(bad, string.format("%s: faces %.2f away from the map's middle", p.id, dot))
				end
			end
		end
		if #bad > 0 then
			error(table.concat(bad, "\n"))
		end
	end)
end)

describe("Portals: the boss door and the labels (W31)", function()
	it("frames the red door with upright horns and a lintel", function()
		local g = Portals.GATE
		local inner = g.hornX - g.horn / 2
		expect(inner > g.door.w / 2).toBe(true)
		expect(inner - g.door.w / 2 <= 0.5).toBe(true)
		expect(g.lintel.y - g.lintel.h / 2 >= g.door.y + g.door.h / 2).toBe(true)
		expect(g.lintel.w / 2 <= g.hornX + g.horn / 2).toBe(true)
		expect(g.lintel.w / 2 >= inner + 1).toBe(true)
		local prefabs = read("src/server/World/Prefabs.luau")
		for _, needle in { "Portals.GATE.lintel", "Portals.GATE.hornX", '"Rune"' } do
			if not string.find(prefabs, needle, 1, true) then
				error(`Prefabs.luau: missing {needle}`)
			end
		end
	end)

	it(
		"stands the door on a sill just over the boss caves' voxel floor and lights the horns' edges (W31, Studio)",
		function()
			local g = Portals.GATE
			local sillTop = g.sill.y + g.sill.h / 2
			local doorBottom = g.door.y - g.door.h / 2
			-- the door stands on the sill, not in the floor; the sill reaches deep enough that no lower floor shows a gap
			expect(doorBottom >= sillTop - 0.2 and doorBottom <= sillTop).toBe(true)
			expect(sillTop - (g.sill.y - g.sill.h / 2) >= g.rise + 2).toBe(true)
			expect(g.sill.w / 2 <= g.hornX + g.horn / 2).toBe(true)
			expect(g.rise > 0 and g.rise <= 0.3).toBe(true)
			-- Studio 2026-10-22: in every boss cave the floor is flat under the gate (data), the voxel floor 2 studs over it
			-- and the sill's top `rise` over that, from data (no rays: they missed the floor or hit something else)
			local caves = 0
			for _, p in Portals.list do
				if p.kind == "dungeon" then
					caves += 1
					local cave = assert(CaveTerrain.get(p.map), p.map)
					local floor = assert(cave.floor(p.x, p.z), `{p.id}: no floor under the gate`)
					for a = -g.sill.w / 2, g.sill.w / 2, 1 do
						for b = -3, 3, 1 do
							local x, z = onMap(p, a, b)
							local f = cave.floor(x, z)
							if f == nil or math.abs(f - floor) > 0.1 then
								error(`{p.id}: the floor under the gate is not flat at ({a}, {b})`)
							end
						end
					end
					local base = Portals.gateBase(floor)
					local ground = floor + g.ground
					expect(math.abs(base + sillTop - (ground + g.rise)) < 1e-6).toBe(true)
					expect(math.abs(base + doorBottom - ground) <= g.rise).toBe(true)
				end
			end
			expect(caves).toBe(4)
			-- a faint rim, a short-range light
			expect(g.rim.t > 0 and g.rim.t < 1).toBe(true)
			expect(g.rim.w <= 0.3 and g.rim.light <= 16).toBe(true)
			local prefabs = read("src/server/World/Prefabs.luau")
			for _, needle in
				{
					'"HornRim"',
					'"HornRune"',
					"Portals.GATE.rim",
					"Portals.GATE.sill",
					"local base = seatedBase(ctx, x, z, rot)",
					"Portals.gateBase(Build.groundY(ctx, x, z))",
					"Size = Vector3.new(G.horn, top + 3, G.horn)",
				}
			do
				if not string.find(prefabs, needle, 1, true) then
					error(`Prefabs.luau: missing {needle}`)
				end
			end
			local from = assert(string.find(prefabs, "local function seatedBase(", 1, true))
			local body = string.sub(prefabs, from, (string.find(prefabs, "\nend\n", from, true)))
			expect(string.find(body, "Raycast", 1, true)).toBe(nil)
		end
	)

	it("draws the zone labels over portals and gates on a dark plate, always on top, over the arch", function()
		local world = read("src/client/Controllers/WorldController.luau")
		local dungeon = read("src/client/Controllers/DungeonController.luau")
		local label = read("src/client/UI/WorldLabel.luau")
		expect(string.find(label, "AlwaysOnTop = true", 1, true) ~= nil).toBe(true)
		expect(string.find(label, "Theme.Iron.Surface", 1, true) ~= nil).toBe(true)
		expect(string.find(world, "WorldLabel.new(", 1, true) ~= nil).toBe(true)
		expect(string.find(dungeon, "WorldLabel.new(", 1, true) ~= nil).toBe(true)
		expect(string.find(read("src/server/World/Prefabs.luau"), '"LabelHeight"', 1, true) ~= nil).toBe(true)
	end)

	it("keeps the server's rocks off every arch, the cave mouth's own rocks out of that ring (W31, Studio)", function()
		local prefabs = read("src/server/World/Prefabs.luau")
		local from = assert(string.find(prefabs, "function Prefabs.rock(", 1, true))
		local body = string.sub(prefabs, from, (string.find(prefabs, "\nend\n", from, true)))
		expect(string.find(body, "rockNearPortal(ctx, x, z", 1, true) ~= nil).toBe(true)
		local m = Portals.ARCH.model
		local ring = math.sqrt((m.w / 2) ^ 2 + (m.d / 2) ^ 2) + CaveMouth.ROCKS.reach
		for _, at in CaveMouth.ROCKS.at do
			expect(math.sqrt(at[1] ^ 2 + at[2] ^ 2) >= ring).toBe(true)
		end
	end)

	it("keeps the client's pebbles and tufts out of every portal", function()
		local decor = read("src/client/Controllers/DecorController.luau")
		expect(string.find(decor, "Portals.onMap(map.id)", 1, true) ~= nil).toBe(true)
		-- clear of the corners of the painted arch's real footprint, with room for a leaning tuft
		local keep = tonumber(string.match(decor, "local PORTAL_KEEP = ([%d%.]+)"))
		local m = Portals.ARCH.model
		expect(keep ~= nil and keep >= math.sqrt((m.w / 2) ^ 2 + (m.d / 2) ^ 2) + 2).toBe(true)
	end)

	it("grows no decoration grass round the portals of the height-function maps (W31, Studio: the Hideout)", function()
		local m = Portals.ARCH.model
		expect(TerrainLayers.PORTAL_CLEAR >= math.sqrt((m.w / 2) ^ 2 + (m.d / 2) ^ 2) + 4).toBe(true)
		local bad = {}
		for _, p in Portals.list do
			local material: ((number, number) -> string)? = nil
			if p.map == "meadows" then
				material = MeadowsTerrain.material
			elseif RegionTerrain.has(p.map) then
				local T = assert(RegionTerrain.get(p.map))
				material = T.material
			end
			if material then
				local r = TerrainLayers.PORTAL_CLEAR - 1
				for a = -r, r, 2 do
					for b = -r, r, 2 do
						if a * a + b * b <= r * r and material(p.x + a, p.z + b) == "Grass" then
							table.insert(bad, string.format("%s: Grass at (%d, %d)", p.id, a, b))
						end
					end
				end
			end
		end
		if #bad > 0 then
			error(table.concat(bad, "\n"))
		end
	end)
end)
