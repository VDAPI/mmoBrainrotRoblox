--!strict
-- Arena venues in the world (S126): Data/Arena.VENUES plus the world (WorldService ground rays, the map offset).
-- A venue answers where a fighter starts, where a spectator sits, where the way out is and whether a player stands on
-- the sand. For Ristalle `contains` matches the zone "zone.arena" of the city; it is geometry, not ZoneService,
-- because the S127 arena server map (`arena_pit`) has no city zones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)

export type Venue = {
	id: string,
	map: string,
	def: Arena.Venue,
	spawnCFrame: (self: Venue, side: number, index: number) -> CFrame,
	standCFrame: (self: Venue, i: number) -> CFrame,
	exitCFrame: (self: Venue) -> CFrame,
	contains: (self: Venue, player: Player) -> boolean,
}

export type World = {
	ground: (mapId: string, x: number, z: number) -> CFrame, -- WorldService.GroundCFrame
	mapOf: (player: Player) -> string?, -- the map the player is on now (ZoneService)
}

local Venues = {}

local world: World? = nil
local cache: { [string]: Venue } = {}

-- ArenaService.Init hands in the world functions.
function Venues.init(w: World)
	world = w
end

local function origin(mapId: string): Vector3
	local map = Maps.get(mapId)
	return if map then Vector3.new(map.offset.x, map.offset.y, map.offset.z) else Vector3.zero
end

local function need(): World
	local w = world
	if not w then
		error("Arena/Venues: init first")
	end
	return w
end

-- Faces the centre of the sand from a ground point.
local function facing(def: Arena.Venue, at: CFrame): CFrame
	local o = origin(def.map)
	local p = at.Position
	local centre = Vector3.new(o.X + def.center[1], p.Y, o.Z + def.center[2])
	if (centre - p).Magnitude < 0.1 then
		return at
	end
	return CFrame.lookAt(p, centre)
end

function Venues.get(id: string): Venue
	local cached = cache[id]
	if cached then
		return cached
	end
	local def = Arena.venue(id)
	if not def then
		error(`Arena/Venues: unknown venue {id}`)
	end
	local venue = {} :: any
	venue.id = id
	venue.map = def.map
	venue.def = def

	function venue.spawnCFrame(_self: Venue, side: number, index: number): CFrame
		local x, z = ArenaRules.spot(def, side, index)
		return facing(def, need().ground(def.map, x, z))
	end

	function venue.standCFrame(_self: Venue, i: number): CFrame
		local x, z = ArenaRules.standSpot(def, i)
		-- the ground ray hits the stand (WorldService.GroundCFrame looks for geometry over the terrain)
		return facing(def, need().ground(def.map, x, z))
	end

	function venue.exitCFrame(_self: Venue): CFrame
		return need().ground(def.map, def.exit[1], def.exit[2])
	end

	function venue.contains(_self: Venue, player: Player): boolean
		if need().mapOf(player) ~= def.map then
			return false
		end
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local rel = root.Position - origin(def.map)
		-- one stud of slack outwards: standing at the fence still counts as on the sand
		return ArenaRules.inside(def, rel.X, rel.Z, -1)
	end

	cache[id] = venue :: Venue
	return venue :: Venue
end

return Venues
