--!strict
-- Admin commands: world (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Areas = require(Shared.Data.Areas)
local Bosses = require(Shared.Data.Bosses)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local DayCycle = require(Shared.Logic.DayCycle)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Town = require(Shared.Data.Town)
local TownGen = require(Shared.Logic.TownGen)
local TownPlaces = require(Shared.Logic.TownPlaces)
local TownTerrain = require(Shared.Logic.TownTerrain)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter

local PlayerStateService = Context.services.PlayerStateService
local MonsterService = Context.services.MonsterService
local NpcService = Context.services.NpcService
local AlchemyService = Context.services.AlchemyService
local BlessingService = Context.services.BlessingService
local GatherService = Context.services.GatherService
local FishingService = Context.services.FishingService
local WorldService = Context.services.WorldService
local TravelService = Context.services.TravelService
local AdminService = Context.services.AdminService
local MapMarkService = Context.services.MapMarkService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

-- City Builds with their part counts per level, generated on the first /town info (same list as the layout).
local townBuilds: { { name: string, tag: string, x: number, z: number, shell: number, detail: number, fine: number } }? =
	nil

local function cityBuilds()
	if not townBuilds then
		local list = {}
		for _, build in TownGen.all(Town.city, TownTerrain.heightAt) do
			local counts = { shell = 0, detail = 0, fine = 0 }
			for _, piece in build.bp.pieces do
				counts[piece.lod] += 1
			end
			table.insert(list, {
				name = build.name,
				tag = build.tag or "?",
				x = build.at.x,
				z = build.at.z,
				shell = counts.shell,
				detail = counts.detail,
				fine = counts.fine,
			})
		end
		townBuilds = list
	end
	return townBuilds :: any
end

-- S29: standing CFrame for a map-relative point, checked by WorldService.SafeSpot (ground under the feet,
-- nothing in the body or over the head), facing `look` (map-relative x, z) when given.
local function safeAt(mapId: string, x: number, z: number, lookX: number?, lookZ: number?): CFrame
	local map = Maps.get(mapId)
	if map and lookX and lookZ then
		return (WorldService.SafeSpotFacing(mapId, x, z, Vector3.new(map.offset.x + lookX, 0, map.offset.z + lookZ)))
	end
	return (WorldService.SafeSpot(mapId, x, z))
end

-- City place or city NPC (Logic/TownPlaces: a free point off every building) as a standing CFrame, or nil.
local function cityPlace(id: string): CFrame?
	local spot = TownPlaces.resolve(id)
	if not spot then
		return nil
	end
	return safeAt("city", spot.x, spot.z, spot.lookX, spot.lookZ)
end

-- Teleports to an area's arrival point (the same place a portal brings you to), honouring the level lock.
local function travelArea(player: Player, mapId: string, areaId: string): (boolean, string?)
	if not WorldService.IsBuilt(mapId) or not PlayerStateService.GetCharacter(player) then
		return false, "portal.closed"
	end
	local at, err = TravelService.AreaArrival(player, mapId, areaId)
	if err then
		return false, err
	end
	if not at then
		return false, "error.badRequest"
	end
	task.spawn(TravelService.TeleportToMap, player, mapId, at)
	return true, nil
end

commands.tp = function(player, args)
	local mapId = args[1]
	if mapId == "cave" and args[2] then
		-- /tp cave <id>: in front of the cave mouth on its region map (S19).
		local cave = Areas.caves.get(args[2])
		local arrival = Areas.arrivalOf(args[2])
		if not cave or not arrival or not WorldService.IsBuilt(cave.region) then
			reply(player, "admin.usage.tp")
			return
		end
		withCharacter(player, function()
			task.spawn(TravelService.TeleportToMap, player, cave.region, safeAt(cave.region, arrival.x, arrival.z))
			reply(player, "admin.tp.map", { map = cave.region })
		end)
		return
	end
	if mapId == "boss" and args[2] then
		-- /tp boss <id>: in front of that boss's dungeon gate.
		local def = Bosses.get(args[2])
		local cave = nil
		for _, map in Maps.byId do
			if def and map.dungeonRegion == def.region and map.dungeonEntrance then
				cave = map
			end
		end
		if not cave or not cave.dungeonEntrance or not WorldService.IsBuilt(cave.id) then
			reply(player, "admin.usage.tp")
			return
		end
		local e = cave.dungeonEntrance
		withCharacter(player, function()
			task.spawn(TravelService.TeleportToMap, player, cave.id, safeAt(cave.id, e.x - 22, e.z, e.x, e.z))
			reply(player, "admin.tp.map", { map = cave.id })
		end)
		return
	end
	if mapId and Maps.get(mapId) then
		if not WorldService.IsBuilt(mapId) then
			reply(player, "admin.maps.notBuilt", { map = mapId })
			return
		end
		withCharacter(player, function()
			local px, pz = tonumber(args[2]), tonumber(args[3])
			local at = if px and pz then safeAt(mapId, px, pz) else nil
			task.spawn(TravelService.TeleportToMap, player, mapId, at)
			reply(player, "admin.tp.map", { map = mapId })
		end)
		return
	end
	local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
	if x == nil or y == nil or z == nil then
		reply(player, "admin.usage.tp")
		return
	end
	withCharacter(player, function()
		local model = player.Character
		if model then
			model:PivotTo(CFrame.new(x :: number, y :: number, z :: number))
			reply(player, "admin.tp.ok", { x = x, y = y, z = z })
		end
	end)
end

commands.npc = function(player, args)
	local id = args[1]
	if not id then
		local names = {}
		for _, def in Npcs.list do
			if not def.decoration then
				table.insert(names, def.id)
			end
		end
		reply(player, "admin.npc.list", { list = table.concat(names, ", ") })
		return
	end
	local position = NpcService.Position(id)
	local def = Npcs.get(id)
	withCharacter(player, function()
		local model = player.Character
		if model and position and def then
			-- S27: NPCs on other maps (the Meadows) go through the map change (zone, location, loading screen).
			-- S29: a checked free spot in front of the NPC (in the city off every building, Logic/TownPlaces).
			local at = if def.map == "city" then cityPlace(id) else nil
			if not at then
				local map = Maps.get(def.map)
				local ox, oz = if map then map.offset.x else 0, if map then map.offset.z else 0
				local a = math.rad(def.facing)
				local lx, lz = position.X - ox, position.Z - oz
				at = safeAt(def.map, lx - math.sin(a) * 5, lz - math.cos(a) * 5, lx, lz)
			end
			task.spawn(TravelService.TeleportToMap, player, def.map, at)
			reply(player, "admin.npc.tp", { npc = "@" .. def.nameKey })
		else
			reply(player, "admin.usage.npc")
		end
	end)
end

commands.time = function(player, args)
	local text = args[1]
	local seconds = text and tonumber((string.gsub(text, "^%+", "")))
	if not seconds then
		reply(player, "admin.usage.time")
		return
	end
	Clock.shift(seconds)
	AlchemyService.CheckAll()
	BlessingService.CheckAll()
	reply(player, "admin.time.ok", { seconds = seconds, offset = Clock.offset() })
end

commands.nodes = function(player, args)
	if args[1] == "count" then
		-- Gathering nodes per kind on the current map (S19).
		local character = PlayerStateService.GetCharacter(player)
		local mapId = character and character.location.map or ""
		local counts: { [string]: number } = {}
		for _, placement in WorldService.GetNodePlacements() do
			if placement.map == mapId then
				counts[placement.kind] = (counts[placement.kind] or 0) + 1
			end
		end
		local parts = {}
		for kind, n in counts do
			table.insert(parts, `{kind} {n}`)
		end
		table.sort(parts)
		reply(player, "admin.nodes.count", { map = mapId, list = table.concat(parts, ", ") })
		return
	end
	if args[1] ~= "respawn" then
		reply(player, "admin.usage.nodes")
		return
	end
	reply(player, "admin.nodes.ok", { n = GatherService.RespawnAll() })
end

commands.fish = function(player, args)
	if args[1] ~= "auto" then
		reply(player, "admin.usage.fish")
		return
	end
	local enabled = not FishingService.IsAuto(player)
	FishingService.SetAuto(player, enabled)
	reply(player, if enabled then "admin.fish.on" else "admin.fish.off")
end

commands.maps = function(player)
	local ids = {}
	for id in Maps.byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for _, id in ids do
		table.insert(parts, if WorldService.IsBuilt(id) then `{id} ✔` else id)
	end
	reply(player, "admin.maps.list", { list = table.concat(parts, ", ") })
end

commands.rebuild = function(player, args)
	local mapId = args[1]
	if not mapId or not Maps.get(mapId) then
		reply(player, "admin.usage.rebuild")
		return
	end
	local started = os.clock()
	if WorldService.Rebuild(mapId) then
		reply(player, "admin.rebuild.ok", { map = mapId, seconds = math.floor((os.clock() - started) * 10) / 10 })
	else
		reply(player, "admin.maps.notBuilt", { map = mapId })
	end
end

commands.nearby = function(player, args)
	local radius = math.clamp(tonumber(args[1]) or 150, 10, 2000)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local lines = {}
	for i, s in MonsterService.SpawnersNear(root.Position, radius) do
		if i > 12 then
			break
		end
		table.insert(lines, `{s.id} ({s.monster} {s.variant}) {s.alive}/{s.count} · {s.distance}`)
	end
	if #lines == 0 then
		reply(player, "admin.nearby.none")
	else
		reply(player, "admin.nearby.list", { list = table.concat(lines, "; ") })
	end
end

commands.area = function(player)
	local character = PlayerStateService.GetCharacter(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = character and Maps.get(character.location.map)
	if not root or not map then
		reply(player, "admin.needCharacter")
		return
	end
	local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local area = Areas.areaAt(map.id, x, z)
	if not area then
		reply(player, "admin.area.none", { map = map.id, x = math.floor(x), z = math.floor(z) })
		return
	end
	reply(player, "admin.area.info", {
		id = area.id,
		min = area.lv[1],
		max = area.lv[2],
		kinds = table.concat(area.kinds, ", "),
		groups = area.groups,
	})
end

commands.decor = function(player, args)
	local level = args[1]
	if level ~= "low" and level ~= "mid" and level ~= "high" then
		reply(player, "admin.usage.decor")
		return
	end
	PlayerStateService.Set(player, { "account", "settings", "decor" }, level)
	reply(player, "admin.decor.ok", { level = level })
end

commands.mapcache = function(player, args)
	if args[1] ~= "clear" then
		reply(player, "admin.usage.mapcache")
		return
	end
	Net.Fire(player, "AdminClient", "mapcache")
	reply(player, "admin.mapcache.ok")
end

commands.town = function(player, args)
	local action = args[1]
	if action == "lod" then
		local level = args[2]
		if level ~= "low" and level ~= "mid" and level ~= "high" then
			reply(player, "admin.usage.town")
			return
		end
		PlayerStateService.Set(player, { "account", "settings", "decor" }, level)
		reply(player, "admin.decor.ok", { level = level })
	elseif action == "tp" then
		if not WorldService.IsBuilt("city") then
			reply(player, "admin.maps.notBuilt", { map = "city" })
			return
		end
		local at = cityPlace(args[2] or "")
		if not at then
			local names = {}
			for _, place in TownPlaces.list() do
				table.insert(names, place.id)
			end
			reply(player, "admin.town.places", { list = table.concat(names, ", ") })
			return
		end
		withCharacter(player, function()
			task.spawn(TravelService.TeleportToMap, player, "city", at)
			reply(player, "admin.tp.map", { map = "city" })
		end)
	elseif action == "info" then
		local character = PlayerStateService.GetCharacter(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local map = Maps.get("city")
		if not root or not map or not character or character.location.map ~= "city" then
			reply(player, "admin.town.notInCity")
			return
		end
		local x, z = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
		local best, bestDistance = nil, math.huge
		for _, build in cityBuilds() do
			local d = math.sqrt((build.x - x) ^ 2 + (build.z - z) ^ 2)
			if d < bestDistance then
				best, bestDistance = build, d
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local hit = workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
		reply(player, "admin.town.info", {
			x = math.floor(x),
			z = math.floor(z),
			height = string.format("%.1f", TownTerrain.heightAt(x, z)),
			material = if hit then hit.Material.Name else "-",
			open = tostring(TownTerrain.isOpen(x, z)),
			name = if best then best.name else "-",
			tag = if best then best.tag else "-",
			distance = math.floor(bestDistance),
			shell = if best then best.shell else 0,
			detail = if best then best.detail else 0,
			fine = if best then best.fine else 0,
		})
		Net.Fire(player, "AdminClient", "town")
	else
		reply(player, "admin.usage.town")
	end
end

commands.daytime = function(player, args)
	local text = args[1]
	if text == "auto" then
		workspace:SetAttribute("DayOffset", nil)
		reply(player, "admin.daytime.auto")
		return
	end
	local hour = tonumber(text)
	if not hour or hour < 0 or hour > 24 then
		reply(player, "admin.usage.daytime")
		return
	end
	local offset = DayCycle.offsetFor(workspace:GetServerTimeNow(), hour % 24, Config.DayLength, Config.DayNightShare)
	workspace:SetAttribute("DayOffset", offset)
	reply(player, "admin.daytime.ok", { hour = hour })
end

commands.portalpick = function(player, args)
	local mapId = args[1]
	if not mapId or not Areas.byMap[mapId] then
		reply(player, "admin.usage.portalpick")
		return
	end
	Net.Fire(player, "AdminClient", "portalpick", mapId)
end

commands.arrive = function(player, args)
	local mapId, areaId = args[1], args[2]
	if not mapId or not areaId then
		reply(player, "admin.usage.arrive")
		return
	end
	if not PlayerStateService.GetCharacter(player) then
		reply(player, "admin.needCharacter")
		return false, "admin.needCharacter"
	end
	local ok, err = travelArea(player, mapId, areaId)
	reply(player, if ok then "admin.tp.map" else (err or "admin.usage.arrive"), { map = mapId })
	-- The area picker of /portalpick reads the failure (S22).
	return ok, err
end

-- S23: teleport to another player / bring them here (same map: in place; another map: through the loading
-- screen).
local function moveTo(who: Player, target: Player): boolean
	local targetChar = PlayerStateService.GetCharacter(target)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetChar or not root or not PlayerStateService.GetCharacter(who) then
		return false
	end
	local at = root.CFrame * CFrame.new(3, 0, 3)
	task.spawn(TravelService.TeleportToMap, who, targetChar.location.map, at)
	return true
end

-- S25: guide target for the caller (an NPC id, a map id, "x z" on the current map, or "clear"); the client
-- draws the path and the HUD bar like after "Guide" on the world map.
commands.nav = function(player, args)
	local target = args[1] or ""
	local spec: { [string]: any }? = nil
	if target == "clear" or target == "off" then
		spec = { kind = "clear" }
	elseif Npcs.get(target) then
		spec = { kind = "npc", id = target }
	elseif Maps.get(target) then
		spec = { kind = "map", id = target }
	else
		local x, z = tonumber(target), tonumber(args[2])
		if x and z and x == x and z == z then
			spec = { kind = "point", x = x, z = z }
		end
	end
	if not spec then
		reply(player, "admin.usage.nav")
		return false, "admin.nav.bad"
	end
	Net.Fire(player, "AdminClient", "nav", spec)
	reply(player, "admin.nav.ok", { target = if spec.kind == "point" then `{args[1]} {args[2]}` else target })
	return true
end

commands.navdebug = function(player)
	Net.Fire(player, "AdminClient", "navdebug")
	reply(player, "admin.navdebug.ok")
end

-- S25: own map marks of the caller's character.
commands.marks = function(player, args)
	withCharacter(player, function()
		if args[1] == "clear" then
			reply(player, "admin.marks.cleared", { n = MapMarkService.Clear(player) })
			return
		end
		local marks = MapMarkService.List(player)
		reply(player, "admin.marks.count", { n = #marks, max = Config.Nav.maxMarks })
		for i, mark in marks do
			reply(player, "admin.marks.line", { i = i, icon = mark.icon, map = mark.map, x = mark.x, z = mark.z })
		end
	end)
end

commands["goto"] = function(player, args)
	local target = AdminService.FindPlayer(args[1] or "")
	if not target or target == player or not moveTo(player, target) then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	reply(player, "admin.goto.ok", { name = target.Name })
	return true
end

commands.bring = function(player, args)
	local target = AdminService.FindPlayer(args[1] or "")
	if not target or target == player or not moveTo(target, player) then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	reply(player, "admin.bring.ok", { name = target.Name })
	return true
end

return commands
