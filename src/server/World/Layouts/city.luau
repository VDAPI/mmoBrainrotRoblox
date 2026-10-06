--!strict
-- Vaelthorn, the starting city (S21, docs/miasto/MIASTO.md). Everything comes from the city plan (Data/Town)
-- and the pure generators:
--   * terrain: TownTerrainWriter (hills, terraces, ramps, the river and the moat, painted materials),
--   * buildings: the "shell" level of every TownGen Build (the client adds "detail" and "fine" near the camera,
--     TownDetailController), in Town/<tag> folders,
--   * the four gates are the only exits: their portal fields become Portal_<id> models (same attributes and tag
--     as Prefabs.portal); an invisible barrier in every gate passage keeps players inside the walls,
--   * zones (green map, yellow Ristalle), the spawn point on the market and the map sketch (TownSketch).
-- NPC positions come from the same plan (Data/Npcs, NpcService); the arena from Town.city.arena (DuelService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)
local TownTerrainWriter = require(script.Parent.Parent.TownTerrainWriter)

local Shared = ReplicatedStorage.Shared
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local Log = require(Shared.Util.Log)
local Town = require(Shared.Data.Town)
local TownGen = require(Shared.Logic.TownGen)
local TownGeom = require(Shared.Logic.TownGeom)
local TownSigns = require(Shared.Logic.TownSigns)
local TownSketch = require(Shared.Logic.TownSketch)
local TownTerrain = require(Shared.Logic.TownTerrain)

local log = Log.new("CityLayout")

-- Moves the portal field of a gatehouse into its own Portal_<id> model directly in the map folder, where
-- WorldBuilder.collect registers it. The rest of the gatehouse stays a normal (non-atomic) building model.
local function gatePortal(ctx: Build.Context, build: any, result: BlueprintBuild.Result)
	local gate = build.gate
	local fields = result.tagged.portal
	local field = fields and fields[1]
	if not gate or not field then
		log:warn("gate %s has no portal field", build.name)
		return
	end
	local model = Instance.new("Model")
	model.Name = `Portal_{gate.portal}`
	field.Name = "Field"
	field.Parent = model
	model.Parent = ctx.folder
	Prefabs.makePortal(ctx, model, field, gate.portal, gate.target, gate.x, gate.z, nil)
end

return function(ctx: Build.Context)
	local city = Town.city
	local half = city.size / 2

	-- Terrain. The world is built from WorldService.Init, which must not yield: write without pauses.
	local started = os.clock()
	local blocks = TownTerrainWriter.write(ctx.origin, half, false)
	log:info("terrain: %d blocks in %.2f s", blocks, os.clock() - started)

	-- Building shells, grouped by tag (house, wall, tower, gate, special, ...).
	started = os.clock()
	local town = Instance.new("Folder")
	town.Name = "Town"
	town.Parent = ctx.folder
	local folders: { [string]: Folder } = {}
	local function folderFor(tag: string): Folder
		local folder = folders[tag]
		if not folder then
			local created = Instance.new("Folder")
			created.Name = tag
			created.Parent = town
			folders[tag] = created
			folder = created
		end
		return folder :: Folder
	end
	local builds = TownGen.all(city, TownTerrain.heightAt)
	local parts = 0
	for _, build in builds do
		local result = BlueprintBuild.build(build :: any, ctx.origin, { shell = true }, folderFor(build.tag or "misc"))
		parts += result.parts
		if build.tag == "gate" then
			gatePortal(ctx, build, result)
		end
	end
	ctx.parts += parts
	log:info("shell: %d builds, %d parts in %.2f s", #builds, parts, os.clock() - started)

	-- Zones: the whole map is green, the sand of the Ristalle yellow (duels; the stands stay green).
	Build.zone(ctx, "green", nil, -half, -half, half, half)
	local arena = city.arena
	Build.zone(
		ctx,
		"yellow",
		"zone.arena",
		arena.x - arena.half,
		arena.z - arena.half,
		arena.x + arena.half,
		arena.z + arena.half
	)

	-- Spawn on the market by the fountain, facing along the plan's `facing`.
	local spawn = city.spawn
	local fx, fz = TownGeom.front(spawn.facing)
	Build.spawnPoint(ctx, spawn.x, spawn.z, spawn.x + fx * 10, spawn.z + fz * 10)

	-- Service signs beside the NPCs (apothecary, forge, guild hall, ...), written by the client (SignController).
	for _, sign in TownSigns.list() do
		Prefabs.signpost(ctx, sign.x, sign.z, sign.rot, sign.key)
	end

	-- Invisible walls on the map edge; the terrain writer already continues the hills past it.
	Build.boundary(ctx)

	-- Map sketch: fields, forest, water, gardens, squares, streets, buildings and walls (~910 shapes).
	for _, shape in TownSketch.shapes() do
		table.insert(ctx.sketch.shapes, shape :: any)
	end
end
