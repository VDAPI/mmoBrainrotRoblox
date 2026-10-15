--!strict
-- The arena server map (S127, DESIGN-17 §6): flat ground with the Ristalle sand and stands for every field of the
-- server mode's layout (Data/ArenaPit; S130's tournament layout has four fields, every one built the same way). Built
-- only on arena and tournament servers (Data/Maps.serverModes, WorldBuilder.build(mode)); a world server builds it only
-- for the admin preview (/arenanet pit). The sand is a yellow zone named "zone.arena" like the city's Ristalle (no
-- mounts there, S96), the rest green; a spawn point stands at each way out (DeathService). No portals, NPCs or nodes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Parent.Parent.Build)

local Shared = ReplicatedStorage.Shared
local ArenaPit = require(Shared.Data.ArenaPit)
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local TownGen = require(Shared.Logic.TownGen)

local RIM = 70 -- ground past the map edge, under the hills around it

return function(ctx: Build.Context)
	local mode = Workspace:GetAttribute("ServerMode")
	local layout = ArenaPit.layout(if type(mode) == "string" then mode else "arena")
	local half = layout.size / 2
	-- the ground is flat at y = 0: read it from here, not by rays (voxels written in this frame do not take rays yet)
	ctx.height = function(_x: number, _z: number): number
		return 0
	end

	-- Terrain: one flat plate, sand under every field, low hills past the edge so the horizon is not empty.
	Build.paint(ctx, 0, 0, layout.size + RIM * 2, layout.size + RIM * 2, 0, Enum.Material.Ground)
	for i = 0, 11 do
		local angle = i * math.pi / 6
		local r = half + 45
		Build.hill(ctx, math.cos(angle) * r, math.sin(angle) * r, 48, 18 + (i % 3) * 6, Enum.Material.Rock)
	end

	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = ctx.folder
	for _, field in layout.fields do
		Build.paint(ctx, field.x, field.z, field.half * 2, field.half * 2, 0, Enum.Material.Sand)
		-- the Ristalle stands from the city generator, with all detail (a small map: the server builds every level)
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
		local build = TownGen.Specials.arena({ id = `arena_{field.id}` }, plan, function(_x: number, _z: number): number
			return 0
		end)
		local result =
			BlueprintBuild.build(build :: any, ctx.origin, { shell = true, detail = true, fine = true }, folder)
		ctx.parts += result.parts
		Build.zone(
			ctx,
			"yellow",
			"zone.arena",
			field.x - field.half,
			field.z - field.half,
			field.x + field.half,
			field.z + field.half
		)
		Build.spawnPoint(ctx, field.x + field.exit[1], field.z + field.exit[2], field.x, field.z)
		Build.rect(ctx, field.x, field.z, field.half * 2, field.half * 2, "ground:Sand")
	end
	Build.zone(ctx, "green", nil, -half, -half, half, half)
	Build.boundary(ctx)
end
