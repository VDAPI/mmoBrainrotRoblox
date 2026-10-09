--!strict
-- Generated cave layout (S19, DESIGN §3.5; each generated cave has a one-line module in World/Layouts that calls this
-- with its map id). Since S51 every cave is on the cave engine (World/CaveLayout: terrain from Logic/CaveTerrain, the
-- dressing and the ore veins of Logic/CaveDress); this adds the exit portal, the sign with the name and levels, the red
-- zone and the respawn point. The plan (rooms and corridors) comes from Logic/CaveGen, the same that
-- Logic/AreaSpawns fills with monster groups.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Build = require(script.Parent.Parent.Build)
local CaveLayout = require(script.Parent.Parent.CaveLayout)
local CaveGen = require(ReplicatedStorage.Shared.Logic.CaveGen)
local Prefabs = require(script.Parent.Parent.Prefabs)

return function(caveId: string)
	return function(ctx: Build.Context)
		local cave = Areas.caves.get(caveId)
		assert(cave, `CaveTemplate: unknown cave {caveId}`)
		assert(CaveLayout.has(caveId), `CaveTemplate: {caveId} has no shape in Data/CaveShapes`)
		local plan = CaveGen.generate(cave.seed or 1)
		CaveLayout.build(ctx)
		local entrance = plan.rooms[1]
		Prefabs.portalFrom(ctx, `{caveId}_exit`)
		Prefabs.signpost(
			ctx,
			entrance.x + 6,
			entrance.z - entrance.r + 12,
			0,
			cave.nameKey,
			cave.levels[1],
			cave.levels[2]
		)
		local half = CaveGen.SIZE / 2
		Build.zone(ctx, "red", nil, -half, -half, half, half)
		Build.spawnPoint(ctx, entrance.x + 8, entrance.z, entrance.x + 40, entrance.z)
	end
end
