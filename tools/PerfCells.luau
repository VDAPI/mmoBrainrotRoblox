--!strict
-- W29: the cost of every generated map per 128-stud streaming cell, from the same pure generators the server and the
-- client build from (TownGen for the city, Logic/WorldGen for the regions, caves and boss chambers, TownGen.Specials
-- for the arena server's pits). Counts per cell: parts by level (shell = server, replicated by streaming; detail and
-- fine = the client near the camera), PointLights, ParticleEmitters the client adds for the pieces' Fx tags
-- (Controllers/TownFxController) and kit slots (models in place of the pieces). Also the worst number of lights a
-- player sees within the client's detail radius (Config.TownDetailRadius) and which of them nothing limits.
-- Used by tools/perf_report.luau (the table) and tests/perf.spec.luau (the budgets). Pure (Lune).

local Config = require("../src/shared/Config")
local Maps = require("../src/shared/Data/Maps")
local Town = require("../src/shared/Data/Town")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local WorldGen = require("../src/shared/Logic/WorldGen")
local ArenaPit = require("../src/shared/Data/ArenaPit")
local GraphicsLevel = require("../src/shared/Logic/GraphicsLevel")

local PerfCells = {}

PerfCells.CELL = 128
-- StreamingTargetRadius of default.project.json: the server's shell parts a client holds around itself
PerfCells.STREAM_RADIUS = 512

-- ParticleEmitters TownFxController adds to a piece with this Fx tag (light holders add none).
PerfCells.EMITTERS = {
	smoke = 1,
	fire = 1,
	water = 1,
	waterfall = 1,
	foam = 2,
	bubbles = 1,
	lavafall = 2,
	ember = 1,
	vent = 3,
	forge = 1,
} :: { [string]: number }

-- Light tags whose number on at once is already limited by RegionLightController (the nearest few).
PerfCells.MANAGED = { lava = true, crystal = true } :: { [string]: boolean }

export type Cell = {
	cx: number,
	cz: number,
	shell: number,
	detail: number,
	fine: number,
	lights: number,
	emitters: number,
	kits: number,
}

export type Summary = {
	x: number,
	z: number,
	reach: number,
	shell: number,
	detail: number,
	fine: number,
	slotTree: number,
	slotUnder: number,
}

export type LightPoint = { x: number, z: number, tag: string?, range: number }

export type Report = {
	map: string,
	builds: number,
	cells: { [string]: Cell },
	totals: Cell,
	worst: { shell: Cell, client: Cell, lights: Cell, emitters: Cell },
	lights: { LightPoint },
	byTag: { [string]: { parts: number, lights: number } },
	underground: boolean,
	-- per Build: centre, reach and parts per level (slotTree / slotUnder = detail pieces of the filler trees and the
	-- undergrowth: kit slots "tree:*" / "under:*" of the detail level)
	summary: { Summary },
}

local function emptyCell(cx: number, cz: number): Cell
	return { cx = cx, cz = cz, shell = 0, detail = 0, fine = 0, lights = 0, emitters = 0, kits = 0 }
end

-- Map-relative x, z of a Build-local point (BlueprintBuild.frame: CFrame.new(at) * Angles(0, rot, 0)).
local function place(at: any, p: { number }): (number, number)
	local a = math.rad(at.rot or 0)
	local c, s = math.cos(a), math.sin(a)
	return at.x + p[1] * c + p[3] * s, at.z - p[1] * s + p[3] * c
end

local function emittersOf(piece: any): number
	local tag = piece.tag
	if not tag then
		return 0
	end
	if tag == "candle" then
		return if piece.fxColor then 1 else 0
	end
	if tag == "lava" then
		local size = piece.size
		return if size[1] * size[3] > 40 then 1 else 0
	end
	return PerfCells.EMITTERS[tag] or 0
end

-- Analyses a list of Builds of map `mapId`.
function PerfCells.analyse(mapId: string, builds: { any }): Report
	local size = PerfCells.CELL
	local cells: { [string]: Cell } = {}
	local totals = emptyCell(0, 0)
	local lights: { LightPoint } = {}
	local byTag: { [string]: { parts: number, lights: number } } = {}
	local summary: { Summary } = {}
	local function cellAt(x: number, z: number): Cell
		local cx, cz = math.floor(x / size), math.floor(z / size)
		local key = `{cx}:{cz}`
		local cell = cells[key]
		if not cell then
			cell = emptyCell(cx, cz)
			cells[key] = cell
		end
		return cell :: Cell
	end
	for _, build in builds do
		local tag = build.tag or "misc"
		local entry = byTag[tag]
		if not entry then
			entry = { parts = 0, lights = 0 }
			byTag[tag] = entry
		end
		local bp = build.bp
		local sum = {
			x = build.at.x,
			z = build.at.z,
			reach = TownGen.radius(build),
			shell = 0,
			detail = 0,
			fine = 0,
			slotTree = 0,
			slotUnder = 0,
		}
		table.insert(summary, sum)
		for _, piece in bp.pieces do
			local lodKey = piece.lod :: string
			if lodKey == "shell" or lodKey == "detail" or lodKey == "fine" then
				(sum :: any)[lodKey] += 1
			end
			local slot = if lodKey == "detail" and piece.k then bp.kits[piece.k] else nil
			if slot and slot.lod == "detail" then
				if string.sub(slot.key, 1, 5) == "tree:" then
					sum.slotTree += 1
				elseif string.sub(slot.key, 1, 6) == "under:" then
					sum.slotUnder += 1
				end
			end
			local x, z = place(build.at, piece.p)
			local cell = cellAt(x, z)
			local lod = piece.lod :: string
			if lod == "shell" then
				cell.shell += 1
				totals.shell += 1
			elseif lod == "detail" then
				cell.detail += 1
				totals.detail += 1
			else
				cell.fine += 1
				totals.fine += 1
			end
			local e = emittersOf(piece)
			cell.emitters += e
			totals.emitters += e
			entry.parts += 1
		end
		for _, light in bp.lights do
			local x, z = place(build.at, light.p)
			local cell = cellAt(x, z)
			cell.lights += 1
			totals.lights += 1
			entry.lights += 1
			table.insert(lights, { x = x, z = z, tag = light.tag, range = light.range })
		end
		for _, slot in bp.kits or {} do
			local x, z = place(build.at, slot.p)
			local cell = cellAt(x, z)
			cell.kits += 1
			totals.kits += 1
		end
	end
	local worst = {
		shell = emptyCell(0, 0),
		client = emptyCell(0, 0),
		lights = emptyCell(0, 0),
		emitters = emptyCell(0, 0),
	}
	for _, cell in cells do
		if cell.shell > worst.shell.shell then
			worst.shell = cell
		end
		if cell.shell + cell.detail + cell.fine > worst.client.shell + worst.client.detail + worst.client.fine then
			worst.client = cell
		end
		if cell.lights > worst.lights.lights then
			worst.lights = cell
		end
		if cell.emitters > worst.emitters.emitters then
			worst.emitters = cell
		end
	end
	local map = Maps.get(mapId)
	local biome = if map then map.biome else ""
	return {
		map = mapId,
		builds = #builds,
		cells = cells,
		totals = totals,
		worst = worst,
		lights = lights,
		byTag = byTag,
		underground = biome == "cave" or biome == "crypt" or biome == "dungeon",
		summary = summary,
	}
end

-- The most of `f(all, free, managed)` over points every half cell, where the three are the lights within `radius`:
-- all of them, those nothing limits (on the surface every light except lava and crystal ones) and the limited ones.
local function overPoints(report: Report, radius: number, f: (number, number, number) -> number): number
	if #report.lights == 0 then
		return 0
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, l in report.lights do
		minX, maxX = math.min(minX, l.x), math.max(maxX, l.x)
		minZ, maxZ = math.min(minZ, l.z), math.max(maxZ, l.z)
	end
	local step = PerfCells.CELL / 2
	local r2 = radius * radius
	local best = 0
	local x = minX
	while x <= maxX + step do
		local z = minZ
		while z <= maxZ + step do
			local all, free = 0, 0
			for _, l in report.lights do
				if (l.x - x) ^ 2 + (l.z - z) ^ 2 <= r2 then
					all += 1
					if not report.underground and not PerfCells.MANAGED[l.tag or ""] then
						free += 1
					end
				end
			end
			best = math.max(best, f(all, free, all - free))
			z += step
		end
		x += step
	end
	return best
end

-- The most lights within `radius` studs of one point and how many of them nothing limits.
function PerfCells.lightsInRadius(report: Report, radius: number): (number, number)
	local all = overPoints(report, radius, function(a: number): number
		return a
	end)
	local free = overPoints(report, radius, function(_a: number, f: number): number
		return f
	end)
	return all, free
end

-- The most lights shining at once around one spot (at night) at graphics level `quality` with "World detail"
-- `decor`: lights exist within the detail radius; underground the nearest Config.CaveLights, on the surface the
-- nearest Config.RegionLights of the lava and crystals plus the graphics level's budget of every other light (W29).
function PerfCells.lightsOn(report: Report, quality: string, decor: string): number
	local level = GraphicsLevel.detail(quality, decor)
	local radius = PerfCells.detailRadius(level)
	local cap = GraphicsLevel.get(quality).lights or math.huge
	local caveCap = (Config.CaveLights :: any)[level] :: number
	local regionCap = (Config.RegionLights :: any)[level] :: number
	return overPoints(report, radius, function(all: number, free: number, managed: number): number
		if report.underground then
			return math.min(all, caveCap)
		end
		return math.min(free, cap) + math.min(managed, regionCap)
	end)
end

-- The same before W29 (no light budget, no detail cap): every free light within the radius shone.
function PerfCells.lightsBefore(report: Report, decor: string): number
	local level = if decor == "low" or decor == "high" then decor else "mid"
	local radius = PerfCells.detailRadius(level)
	local caveCap = (Config.CaveLights :: any)[level] :: number
	local regionCap = (Config.RegionLights :: any)[level] :: number
	return overPoints(report, radius, function(all: number, free: number, managed: number): number
		if report.underground then
			return math.min(all, caveCap)
		end
		return free + math.min(managed, regionCap)
	end)
end

-- The most parts the client holds around one point (every 64 studs over the map) at a "World detail" level, the way
-- the game loads them: the shell of the Builds within the streaming radius (default.project.json, 512), the detail
-- level of those within Config.TownDetailRadius and the fine level within Config.TownFineRadius (TownDetailController:
-- distance to the Build's centre minus its reach), for a graphics level `quality` and a "World detail" setting `decor`
-- (Logic/GraphicsLevel: the level's detail cap and the share of filler trees and undergrowth it keeps).
function PerfCells.clientParts(report: Report, quality: string, decor: string): number
	local level = GraphicsLevel.detail(quality, decor)
	local detailR = (Config.TownDetailRadius :: any)[level] :: number
	local fineR = (Config.TownFineRadius :: any)[level] :: number
	local stream = PerfCells.STREAM_RADIUS
	local g = GraphicsLevel.get(quality)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, b in report.summary do
		minX, maxX = math.min(minX, b.x), math.max(maxX, b.x)
		minZ, maxZ = math.min(minZ, b.z), math.max(maxZ, b.z)
	end
	local best = 0
	local x = minX
	while x <= maxX do
		local z = minZ
		while z <= maxZ do
			local n = 0
			for _, b in report.summary do
				local d = math.sqrt((b.x - x) ^ 2 + (b.z - z) ^ 2) - b.reach
				if d < stream then
					n += b.shell
				end
				if d < detailR then
					n += b.detail - b.slotTree - b.slotUnder + b.slotTree * g.fill + b.slotUnder * g.under
				end
				if d < fineR then
					n += b.fine
				end
			end
			best = math.max(best, n)
			z += 64
		end
		x += 64
	end
	return math.floor(best + 0.5)
end

-- Builds of every generated map: the city, each Logic/WorldGen map (regions, caves, boss chambers) and the arena
-- server's layouts ("arena_pit:<mode>").
function PerfCells.maps(): { { id: string, builds: () -> { any } } }
	local list: { { id: string, builds: () -> { any } } } = {}
	table.insert(list, {
		id = "city",
		builds = function()
			return TownGen.all(Town.city, TownTerrain.heightAt) :: any
		end,
	})
	for _, mapId in WorldGen.maps() do
		local gen = WorldGen.get(mapId)
		if gen then
			table.insert(list, {
				id = mapId,
				builds = function()
					return gen.all() :: any
				end,
			})
		end
	end
	for _, mode in { "arena", "tournament" } do
		table.insert(list, {
			id = `arena_pit:{mode}`,
			builds = function()
				local out = {}
				for _, field in ArenaPit.layout(mode).fields do
					local plan = {
						arena = {
							x = field.x,
							z = field.z,
							half = field.half,
							stands = field.stands,
							exit = { field.x + field.exit[1], field.z + field.exit[2] },
							duel = {
								{ field.x + field.starts[1][1], field.z + field.starts[1][2] },
								{ field.x + field.starts[2][1], field.z + field.starts[2][2] },
							},
						},
					}
					local build = TownGen.Specials.arena({ id = `arena_{field.id}` }, plan, function(): number
						return 0
					end)
					table.insert(out, build)
				end
				return out
			end,
		})
	end
	return list
end

-- Analyses a map by its id in PerfCells.maps().
function PerfCells.report(id: string): Report
	for _, entry in PerfCells.maps() do
		if entry.id == id then
			local mapId = string.match(id, "^([^:]+)") or id
			return PerfCells.analyse(mapId, entry.builds())
		end
	end
	error(`no generated map {id}`)
end

-- The detail radius of a "World detail" level (what the client builds around the camera).
function PerfCells.detailRadius(level: string): number
	return (Config.TownDetailRadius :: any)[level] or Config.TownDetailRadius.mid
end

-- W29: the Invasion camp (server/World/InvasionCamp, built from Parts when an Invasion starts): parts, lights and
-- emitters (ParticleEmitter, Smoke, Fire) of one camp, read from the constants at the top of its source.
function PerfCells.invasionCamp(source: string): { parts: number, lights: number, emitters: number }
	local ring = tonumber(string.match(source, "local RING_SEGMENTS = (%d+)")) or 0
	local braziers = tonumber(string.match(source, "local BRAZIERS = (%d+)")) or 0
	local banners = tonumber(string.match(source, "local BANNERS = (%d+)")) or 0
	-- rift: 8 stones + tear + halo + pool; brazier: foot, bowl, coals; banner: pole, bar, two strips of cloth
	return {
		parts = 11 + ring + braziers * 3 + banners * 4,
		lights = 1 + braziers,
		emitters = 2 + braziers,
	}
end

return PerfCells
