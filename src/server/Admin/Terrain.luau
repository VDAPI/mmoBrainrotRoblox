--!strict
-- Admin commands: height-function terrains (S26). Metadata in Shared.Data.AdminCommands; AdminService runs them
-- for the chat and the dev panel. Required from AdminService.Init, after Context has the services.
--   /tparea <target>          teleport to a monster area's middle, an NPC place, a quest anchor or a building site
--   /ambience <area|off|auto> force an area's mood on the caller's client
--   /terrainrebuild <map>     rewrite the terrain of a map with a height function (city, Meadows, S45 the regions)
--   /meadowsstats             server parts, build times, Builds, nodes and monster groups of the Meadows
--   /regionstats <map>        the same for any region of Logic/WorldGen, with the background build time (S45)
--   /terraininfo              the ground under the caller: height, material, theme, water / lava, slope (S46)
--   /worldfx <effect> <mode>  switch a world effect on the caller's client (S46; S47 snow, drift, aurora, plume, eagles,
--                             avalanche, glow)
--   /tpcave <cave> [room]     teleport into a cave on the cave engine, to a room by index or role (S48)
--   /cavestats [cave|all]    S51: `all` lists every cave and chamber on the engine
--   /caveinfo                 the cave under the caller: room, role, floor, ceiling, liquid, mood, lights (S48), the
--                             distance to the nearest lava (S50)
--   /cavestats [cave]         terrain and shell timings, blocks, parts vs maxParts, Builds, lights, nodes (S48)
--   /lights <n|auto>          force the number of cave lights on the caller's client (S48)

local Shared = game:GetService("ReplicatedStorage").Shared

local Ambience = require(Shared.Data.Ambience)
local AreaSpawns = require(Shared.Logic.AreaSpawns)
local Areas = require(Shared.Data.Areas)
local CaveShapes = require(Shared.Data.CaveShapes)
local CaveTerrain = require(Shared.Logic.CaveTerrain)
local MapTerrain = require(Shared.Logic.MapTerrain)
local Maps = require(Shared.Data.Maps)
local MeadowsGen = require(Shared.Logic.MeadowsGen)
local MeadowsTerrain = require(Shared.Logic.MeadowsTerrain)
local Net = require(Shared.Net)
local RegionTerrain = require(Shared.Logic.RegionTerrain)
local Spawns = require(Shared.Data.Spawns)
local WorldGen = require(Shared.Logic.WorldGen)

local BuildStats = require(script.Parent.Parent.World.BuildStats)
local CaveTerrainWriter = require(script.Parent.Parent.World.CaveTerrainWriter)
local Context = require(script.Parent.Context)
local TerrainWriter = require(script.Parent.Parent.World.TerrainWriter)
local TownTerrainWriter = require(script.Parent.Parent.World.TownTerrainWriter)

local reply = Context.reply
local withCharacter = Context.withCharacter

local WorldService = Context.services.WorldService
local TravelService = Context.services.TravelService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

-- Nearest walkable point to (x, z) on a spiral (the middle of an area may be water or a cliff).
local function standable(mapId: string, x: number, z: number): (number, number)
	for ring = 0, 30 do
		local r = ring * 6
		local steps = math.max(1, ring * 6)
		for k = 0, steps - 1 do
			local a = k / steps * math.pi * 2
			local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
			if MapTerrain.walkable(mapId, px, pz) then
				return px, pz
			end
		end
	end
	return x, z
end

-- Map and point of a target name: an area id, an NPC place ("farmer" or "npc:farmer"), a quest anchor id or a
-- building site of a map with sites.
local function resolve(target: string): (string?, number?, number?)
	local name = string.gsub(target, "^npc:", "")
	for mapId, data in Areas.byMap do
		for _, area in data.areas do
			if area.id == target then
				local r = area.rect
				local x, z = standable(mapId, (r[1] + r[3]) / 2, (r[2] + r[4]) / 2)
				return mapId, x, z
			end
		end
		local spot = data.npcSpots and data.npcSpots[name]
		if spot then
			-- three studs in front of the place
			local a = math.rad(spot.facing)
			return mapId, spot.x - math.sin(a) * 3, spot.z - math.cos(a) * 3
		end
		for _, anchor in (data.questAnchors or {}) :: { Areas.QuestAnchor } do
			if anchor.id == target then
				local x, z = standable(mapId, anchor.x + 3, anchor.z + 3)
				return mapId, x, z
			end
		end
		local site = data.sites and data.sites[target]
		if site then
			local x, z = standable(mapId, site.x, site.z + 12)
			return mapId, x, z
		end
	end
	return nil, nil, nil
end

commands.tparea = function(player, args)
	local target = args[1] or ""
	local mapId, x, z = resolve(target)
	if not mapId or not x or not z then
		-- S45: the targets of every map
		local names = {}
		for _, data in Areas.byMap do
			for _, area in data.areas do
				table.insert(names, area.id)
			end
			for name in (data.npcSpots or {}) :: { [string]: Areas.NpcSpot } do
				table.insert(names, `npc:{name}`)
			end
			for _, anchor in (data.questAnchors or {}) :: { Areas.QuestAnchor } do
				table.insert(names, anchor.id)
			end
			for name in (data.sites or {}) :: { [string]: Areas.Site } do
				table.insert(names, name)
			end
		end
		table.sort(names)
		reply(player, "admin.tparea.list", { list = table.concat(names, ", ") })
		return false, "admin.tparea.none"
	end
	if not WorldService.IsBuilt(mapId) then
		reply(player, "admin.maps.notBuilt", { map = mapId })
		return false, "portal.closed"
	end
	withCharacter(player, function()
		-- S29: a checked free spot (ground under the feet, nothing in the body or over the head).
		task.spawn(TravelService.TeleportToMap, player, mapId, (WorldService.SafeSpot(mapId, x, z)))
		reply(player, "admin.tparea.ok", { target = target, map = mapId, x = math.floor(x), z = math.floor(z) })
	end)
	return true
end

commands.ambience = function(player, args)
	local value = args[1] or ""
	local caveId, roomText = string.match(value, "^([%w_]+):(%d+)$")
	if caveId and CaveTerrain.has(caveId) and Ambience.roomMood(caveId, tonumber(roomText)) then
		Net.Fire(player, "AdminClient", "ambience", value)
		reply(player, "admin.ambience.ok", { mood = value })
		return true
	end
	if value ~= "off" and value ~= "auto" then
		local known = false
		for _, data in Areas.byMap do
			for _, area in data.areas do
				if area.id == value then
					known = true
				end
			end
		end
		if not known then
			reply(player, "admin.usage.ambience")
			return false, "admin.ambience.bad"
		end
	end
	Net.Fire(player, "AdminClient", "ambience", value)
	reply(player, if value == "auto" then "admin.ambience.auto" else "admin.ambience.ok", { mood = value })
	return true
end

commands.terrainrebuild = function(player, args)
	local mapId = args[1]
	local map = mapId and Maps.get(mapId)
	if
		not map
		or (mapId ~= "meadows" and mapId ~= "city" and not RegionTerrain.has(mapId) and not CaveTerrain.has(mapId))
	then
		reply(player, "admin.usage.terrainrebuild")
		return false, "admin.terrainrebuild.bad"
	end
	if not WorldService.IsBuilt(map.id) then
		reply(player, "admin.maps.notBuilt", { map = map.id })
		return false, "portal.closed"
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	local started = os.clock()
	task.spawn(function()
		-- only the map square (the mountains past the edge stay); pauses between blocks keep the server responsive
		local region = RegionTerrain.get(map.id)
		if CaveTerrain.has(map.id) then
			-- S48: a cave on the engine (the whole square with its rock margin, pausing between blocks)
			CaveTerrainWriter.write(map.id, origin, { yields = true })
		elseif map.id == "meadows" then
			TerrainWriter.write(origin, map.size.x / 2, MeadowsTerrain.voxels, MeadowsTerrain.MATERIALS, {
				bottom = -24,
				top = 48,
				margin = 0,
				yields = true,
			})
		elseif region then
			TerrainWriter.write(origin, map.size.x / 2, region.voxels, region.MATERIALS, {
				bottom = region.shape.writer.bottom,
				top = region.shape.writer.top,
				margin = 0,
				yields = true,
			})
		else
			TownTerrainWriter.write(origin, map.size.x / 2, true)
		end
		reply(
			player,
			"admin.terrainrebuild.ok",
			{ map = map.id, seconds = math.floor((os.clock() - started) * 10) / 10 }
		)
	end)
	return true
end

commands.meadowsstats = function(player)
	local stats = BuildStats.meadows
	local counts = MeadowsGen.counts()
	local nodes: { [string]: number } = {}
	for _, node in MeadowsGen.nodes() do
		nodes[node.kind] = (nodes[node.kind] or 0) + 1
	end
	local list = {}
	for kind, n in nodes do
		table.insert(list, `{kind} {n}`)
	end
	table.sort(list)
	reply(player, "admin.meadowsstats.build", {
		parts = if stats then stats.parts else WorldService.PartCounts().meadows or 0,
		ms = if stats then math.floor(stats.ms) else 0,
		terrain = if stats then math.floor(stats.terrainMs) else 0,
		write = if stats then math.floor(stats.writeMs) else 0,
		blocks = if stats then stats.blocks else 0,
		shell = if stats then math.floor(stats.shellMs) else 0,
	})
	reply(player, "admin.meadowsstats.gen", {
		builds = counts.builds,
		shell = counts.shell,
		detail = counts.detail,
		fine = counts.fine,
		trees = #MeadowsGen.trees(),
		groups = #(Spawns.byMap.meadows or {}),
	})
	reply(player, "admin.meadowsstats.nodes", { list = table.concat(list, ", ") })
	return true
end

-- S45: build numbers of any region of Logic/WorldGen.
commands.regionstats = function(player, args)
	local mapId = args[1] or ""
	local gen = WorldGen.get(mapId)
	if not gen then
		reply(player, "admin.usage.regionstats")
		return false, "admin.usage.regionstats"
	end
	local stats = BuildStats[mapId]
	local counts = gen.counts()
	local nodes: { [string]: number } = {}
	for _, node in gen.nodes() do
		nodes[node.kind] = (nodes[node.kind] or 0) + 1
	end
	local list = {}
	for kind, n in nodes do
		table.insert(list, `{kind} {n}`)
	end
	table.sort(list)
	local background = WorldService.BackgroundSeconds(mapId)
	reply(player, "admin.regionstats.build", {
		map = mapId,
		parts = if stats then stats.parts else WorldService.PartCounts()[mapId] or 0,
		ms = if stats then math.floor(stats.ms) else 0,
		terrain = if stats then math.floor(stats.terrainMs) else 0,
		write = if stats then math.floor(stats.writeMs) else 0,
		blocks = if stats then stats.blocks else 0,
		shell = if stats then math.floor(stats.shellMs) else 0,
		background = if background then `{math.floor(background * 10) / 10} s` else "—",
	})
	reply(player, "admin.regionstats.gen", {
		builds = counts.builds,
		shell = counts.shell,
		detail = counts.detail,
		fine = counts.fine,
		trees = #gen.trees(),
		lights = counts.lights,
		groups = #(Spawns.byMap[mapId] or {}),
	})
	reply(player, "admin.regionstats.nodes", { list = table.concat(list, ", ") })
	return true
end

-- S46: the ground under the caller (shaped regions: RegionTerrain; the Meadows and the city: MapTerrain only).
commands.terraininfo = function(player)
	local character = Context.services.PlayerStateService.GetCharacter(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = character and Maps.get(character.location.map)
	if not root or not map then
		reply(player, "admin.needCharacter")
		return false
	end
	local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local h = MapTerrain.height(map.id, x, z)
	if not h then
		reply(player, "admin.terraininfo.none", { map = map.id })
		return false
	end
	local region = RegionTerrain.get(map.id)
	local water = MapTerrain.water(map.id, x, z)
	local lava = if region then region.lava(x, z) else nil
	local lavaDistance = if region then region.lavaDistance(x, z) else math.huge
	local slope = if region
		then region.slope(x, z, 2)
		elseif map.id == "meadows" then MeadowsTerrain.slope(x, z, 2)
		else 0
	local round = function(v: number): number
		return math.floor(v * 10 + 0.5) / 10
	end
	reply(player, "admin.terraininfo.ok", {
		map = map.id,
		x = math.floor(x),
		z = math.floor(z),
		h = round(h),
		material = if region
			then region.material(x, z)
			elseif map.id == "meadows" then MeadowsTerrain.material(x, z)
			else "—",
		theme = if region
			then region.themeAt(x, z)
			elseif map.id == "meadows" then MeadowsTerrain.themeAt(x, z)
			else "—",
		water = if water then tostring(round(water)) else "—",
		lava = if lava then tostring(round(lava)) else "—",
		lavaDistance = if lavaDistance < 1e6 then tostring(round(lavaDistance)) else "—",
		slope = round(math.deg(math.atan(slope))),
		walkable = tostring(MapTerrain.walkable(map.id, x, z, 10)),
	})
	-- S47: ice, crevasses, wind and mountains (maps with wind zones)
	if region and region.shape.winds then
		local ice = region.ice(x, z)
		local crevasse = region.crevasseDistance(x, z)
		local dir, strength = region.windAt(x, z)
		reply(player, "admin.terraininfo.frost", {
			ice = if ice then tostring(round(ice)) else "—",
			crevasse = if crevasse < 1e6 then tostring(round(crevasse)) else "—",
			wind = math.floor(dir + 0.5),
			strength = round(strength),
			mountain = tostring(region.mountainAt(x, z)),
			glacier = tostring(region.glacierAt(x, z)),
		})
	end
	return true
end

commands.worldfx = function(player, args)
	local effect, mode = args[1] or "", args[2] or ""
	Net.Fire(player, "AdminClient", "worldfx", { name = effect, mode = mode })
	reply(player, "admin.worldfx.ok", { effect = effect, mode = mode })
	return true
end

-- S48: caves on the cave engine ----------------------------------------------------------------------------------

commands.tpcave = function(player, args)
	local caveId = args[1] or ""
	local roomArg: string? = args[2]
	local T = CaveTerrain.get(caveId)
	local map = Maps.get(caveId)
	if not T or not map then
		reply(player, "admin.usage.tpcave")
		return false, "admin.usage.tpcave"
	end
	local x, z = map.spawn.x, map.spawn.z
	-- S50: the bridges over the River of Fire (`bridge-n` = the northern one, `bridge-s` = the southern one)
	if roomArg == "bridge-n" or roomArg == "bridge-s" then
		local best: { [string]: any }? = nil
		for _, f in T.shape.features do
			if f.kind == "bridge" then
				local mz = (f.az + f.bz) / 2
				local bz = if best then (best.az + best.bz) / 2 else nil
				if not bz or (roomArg == "bridge-n" and mz < bz) or (roomArg == "bridge-s" and mz > bz) then
					best = f
				end
			end
		end
		if not best then
			reply(player, "admin.usage.tpcave")
			return false, "admin.usage.tpcave"
		end
		x, z = best.ax, best.az
		roomArg = nil
	end
	if roomArg then
		local index = tonumber(roomArg)
		if not index then
			for i, r in T.rooms do
				if r.role == roomArg then
					index = i
					break
				end
			end
		end
		local room = index and T.rooms[index]
		if not room then
			reply(player, "admin.usage.tpcave")
			return false, "admin.usage.tpcave"
		end
		x, z = room.x, room.z
	end
	if not WorldService.IsBuilt(caveId) then
		reply(player, "admin.maps.notBuilt", { map = caveId })
		return false, "portal.closed"
	end
	withCharacter(player, function()
		task.spawn(TravelService.TeleportToMap, player, caveId, (WorldService.SafeSpot(caveId, x, z)))
		reply(
			player,
			"admin.tpcave.ok",
			{ map = caveId, room = roomArg or "—", x = math.floor(x), z = math.floor(z) }
		)
	end)
	return true
end

commands.caveinfo = function(player)
	local character = Context.services.PlayerStateService.GetCharacter(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = character and Maps.get(character.location.map)
	if not root or not map then
		reply(player, "admin.needCharacter")
		return false
	end
	local T = CaveTerrain.get(map.id)
	if not T then
		reply(player, "admin.caveinfo.none", { map = map.id })
		return false
	end
	local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local c = T.column(x, z)
	local index = T.roomAt(x, z)
	local room = index and T.rooms[index]
	local round = function(v: number): number
		return math.floor(v * 10 + 0.5) / 10
	end
	reply(player, "admin.caveinfo.ok", {
		map = map.id,
		x = math.floor(x),
		z = math.floor(z),
		room = if index then tostring(index) else "—",
		role = if room then room.role else "—",
		floor = if c.open then tostring(round(c.floor)) else "—",
		ceiling = if c.open then tostring(round(math.min(c.ceiling, 999))) else "—",
		liquid = if c.liquid then `{c.liquid.kind} {round(c.liquid.level)}` else "—",
		-- S50: lava under the caller or the distance to the nearest
		lava = if c.liquid and c.liquid.kind == "lava"
			then "0"
			elseif T.lavaDistance(x, z) < 1e6 then tostring(round(T.lavaDistance(x, z)))
			else "—",
		mood = if Ambience.roomMood(map.id, index) then `{map.id}:{index}` else map.id,
	})
	return true
end

-- One cave's numbers (false when the map is not on the cave engine).
local function caveStats(player: Player, caveId: string): boolean
	local T = CaveTerrain.get(caveId)
	local gen = WorldGen.get(caveId)
	local map = Maps.get(caveId)
	if not T or not gen or not map then
		return false
	end
	local stats = BuildStats[caveId]
	local counts = gen.counts()
	local cave = Areas.caves.get(caveId)
	reply(player, "admin.cavestats.ok", {
		map = caveId,
		parts = if stats then stats.parts else WorldService.PartCounts()[caveId] or 0,
		max = map.maxParts or 0,
		terrain = if stats then math.floor(stats.terrainMs) else 0,
		write = if stats then math.floor(stats.writeMs) else 0,
		blocks = if stats then stats.blocks else 0,
		shell = if stats then math.floor(stats.shellMs) else 0,
		builds = counts.builds,
		detail = counts.detail,
		fine = counts.fine,
		lights = counts.lights,
		nodes = #gen.nodes(),
		spawners = if cave then #AreaSpawns.cave(cave) else 0,
	})
	return true
end

commands.cavestats = function(player, args)
	local character = Context.services.PlayerStateService.GetCharacter(player)
	local caveId = args[1] or (character and character.location.map) or ""
	-- S51: `all` = every cave and chamber on the engine (the review of the series)
	if caveId == "all" then
		local list = {}
		for id in CaveShapes.byMap do
			table.insert(list, id)
		end
		table.sort(list)
		for _, id in list do
			caveStats(player, id)
		end
		return true
	end
	if not caveStats(player, caveId) then
		reply(player, "admin.usage.cavestats")
		return false, "admin.usage.cavestats"
	end
	return true
end

commands.lights = function(player, args)
	local value = args[1] or ""
	local n = tonumber(value)
	if value ~= "auto" and not (n and n >= 0 and n <= 64) then
		reply(player, "admin.usage.lights")
		return false, "admin.usage.lights"
	end
	Net.Fire(player, "AdminClient", "lights", if n then math.floor(n) else "auto")
	reply(player, "admin.lights.ok", { value = value })
	return true
end

return commands
