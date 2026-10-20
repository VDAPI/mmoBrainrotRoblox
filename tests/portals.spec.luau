--!strict
-- W28 (owner: "the purple is not in the portal's frame", "more entrances are broken", "E" at the boss gate at the
-- wrong distance): every portal, cave mouth, cave exit and dungeon gate of Data/Portals against the dressing of its
-- map (Logic/WorldGen): nothing reaches into the arch or the gate, every frame stands in its portal's own frame, the
-- field fits the arch, the "E" prompt and the server's range share one point and one distance, landings are walkable.

local fs = require("@lune/fs")

local MapTerrain = require("../src/shared/Logic/MapTerrain")
local PortalClearance = require("./PortalClearance")
local Portals = require("../src/shared/Data/Portals")
local Test = require("./Test")
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
