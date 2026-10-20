--!strict
-- The arena server map (S127, DESIGN-17 §6): flat ground with the Ristalle sand and stands for every field of the
-- server mode's layout (Data/ArenaPit; S130's tournament layout has four fields, every one built the same way). Built
-- only on arena and tournament servers (Data/Maps.serverModes, WorldBuilder.build(mode)); a world server builds it only
-- for the admin preview (/arenanet pit). The sand is a yellow zone named "zone.arena" like the city's Ristalle (no
-- mounts there, S96), the rest green; a spawn point stands at each way out (DeathService). No portals, NPCs or nodes.
-- S130: the tournament layout's lobby: a low stone platform between the four fields with stone benches, where the
-- players appear and wait (green: no PvP), and the number of each field on a board over its way out ("1".."4").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Parent.Parent.Build)
local Prefabs = require(script.Parent.Parent.Prefabs)

local Shared = ReplicatedStorage.Shared
local ArenaPit = require(Shared.Data.ArenaPit)
local BlueprintBuild = require(Shared.Util.BlueprintBuild)
local TownGen = require(Shared.Logic.TownGen)

local RIM = 70 -- ground past the map edge, under the hills around it
local STONE = Color3.fromHex("#8A857C")
local DARK = Color3.fromHex("#5E5A54")

local function block(
	ctx: Build.Context,
	folder: Instance,
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(ctx.origin + at)
	p.Color = color
	p.Material = Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	ctx.parts += 1
	return p
end

-- S130: the lobby platform with four benches facing the fields.
local function lobby(ctx: Build.Context, folder: Instance, l: ArenaPit.Lobby)
	local side = l.half * 2
	block(ctx, folder, "Lobby", Vector3.new(side, l.height, side), Vector3.new(l.x, l.height / 2, l.z), STONE)
	-- a step all around (the platform is low enough to walk up; the step makes it read as a stage)
	block(
		ctx,
		folder,
		"LobbyStep",
		Vector3.new(side + 4, l.height / 2, side + 4),
		Vector3.new(l.x, l.height / 4, l.z),
		DARK
	)
	for _, d in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		local bx, bz = l.x + d[1] * (l.half - 3), l.z + d[2] * (l.half - 3)
		block(ctx, folder, "LobbyBench", Vector3.new(6, 1, 2), Vector3.new(bx, l.height + 0.5, bz), DARK)
	end
end

-- S130: the field number on a board over the way out (a SurfaceGui with a digit, the same in every language).
local function fieldSign(ctx: Build.Context, folder: Instance, n: number, x: number, z: number, faceZ: number)
	local board = block(ctx, folder, `FieldSign{n}`, Vector3.new(6, 6, 0.6), Vector3.new(x, 11, z), DARK)
	local gui = Instance.new("SurfaceGui")
	gui.Face = if faceZ > 0 then Enum.NormalId.Back else Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(n)
	label.TextScaled = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromHex("#F2C14E")
	label.Parent = gui
	gui.Parent = board
	for _, px in { -2.4, 2.4 } do
		block(ctx, folder, "FieldSignPost", Vector3.new(0.6, 9, 0.6), Vector3.new(x + px, 4.5, z), DARK)
	end
end

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
		Prefabs.signBoards(result.tagged.arenaSign, "town.sign.arena") -- W28: the gate signs, as in the city
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
	-- S130: a tournament server: the lobby and the field numbers (players appear in the lobby: TourneyService)
	local l = layout.lobby
	if l then
		lobby(ctx, folder, l)
		Build.spawnPoint(ctx, l.x, l.z + l.half - 4, l.x, l.z)
		for i, f in layout.fields do
			local ex, ez = f.x + f.exit[1], f.z + f.exit[2]
			-- the board stands over the gate (between the way out and the stands), facing the lobby
			local towards = if f.exit[2] > 0 then 1 else -1
			fieldSign(ctx, folder, i, ex, ez - towards * 10, towards)
		end
	end
	Build.zone(ctx, "green", nil, -half, -half, half, half)
	Build.boundary(ctx)
end
