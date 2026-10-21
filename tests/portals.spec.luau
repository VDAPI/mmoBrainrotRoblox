--!strict
-- W28 (owner: "the purple is not in the portal's frame", "more entrances are broken", "E" at the boss gate at the
-- wrong distance): every portal, cave mouth, cave exit and dungeon gate of Data/Portals against the dressing of its
-- map (Logic/WorldGen): nothing reaches into the arch or the gate, every frame stands in its portal's own frame, the
-- field fits the arch, the "E" prompt and the server's range share one point and one distance, landings are walkable.

local fs = require("@lune/fs")

local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local PortalClearance = require("./PortalClearance")
local Portals = require("../src/shared/Data/Portals")
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
				"Portals.GATE.hornLean",
			}
		do
			if not string.find(prefabs, needle, 1, true) then
				error(`Prefabs.luau: missing {needle}`)
			end
		end
		-- the old sparkles flew up out of the arch (EmissionDirection Top, 3 studs a second for 2 s)
		expect(string.find(prefabs, "sparkles.Speed = NumberRange.new(1, 3)", 1, true)).toBe(nil)
	end)

	it("keeps the dungeon gate's red door out of its leaning horns", function()
		local gate = Portals.GATE
		local door = gate.door
		local r = math.rad(gate.hornLean)
		for _, side in { -1, 1 } do
			-- the horn turned about z by -side * lean (CFrame.Angles(0, 0, a): columns are the turned axes)
			local a = -side * r
			local c, s = math.cos(a), math.sin(a)
			local rot = { c, -s, 0, s, c, 0, 0, 0, 1 }
			local hit = PortalClearance.overlaps(
				{ side * gate.hornX, 8, 0 },
				rot,
				{ 1.5, 9, 1.5 },
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
