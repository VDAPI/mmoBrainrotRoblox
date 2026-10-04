--!strict
-- Registry of combat entities (players and monsters) with stable `entityId`s (ARCHITECTURE §7).
-- The id is also set as the "EntityId" attribute on the model so clients can target it.
-- Monsters live in a spatial hash grid for fast radius queries; players (<= 50) are scanned directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local EntityService = {
	Name = "EntityService",
	Deps = { "CharacterService" },
	-- (entity) / (entity)
	Registered = Signal.new() :: any,
	Unregistered = Signal.new() :: any,
}

-- Minimal shape shared by every entity. Monsters (Entities/Monster) carry many more fields.
export type Entity = {
	id: string,
	kind: "player" | "monster",
	model: Model?,
	player: Player?, -- kind == "player"
	monster: any?, -- kind == "monster" (Entities/Monster object)
}

local CELL = 32

local CharacterService: any

local entities: { [string]: Entity } = {}
local playerEntities: { [Player]: Entity } = {}
local monsterCounter = 0

-- Spatial grid of monster entities: cell key -> set of entities.
local grid: { [string]: { [Entity]: boolean } } = {}
local cellOf: { [Entity]: string } = {}

local function cellKey(x: number, z: number): string
	return `{x // CELL},{z // CELL}`
end

function EntityService.Get(id: string): Entity?
	return entities[id]
end

function EntityService.GetPlayerEntity(player: Player): Entity?
	return playerEntities[player]
end

function EntityService.Position(entity: Entity): Vector3?
	local model = entity.model
	if not model or not model.Parent then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

-- Monsters --------------------------------------------------------------------------------------------

function EntityService.RegisterMonster(monster: any, model: Model): Entity
	monsterCounter += 1
	local entity: Entity = { id = `m{monsterCounter}`, kind = "monster" :: "monster", model = model, monster = monster }
	entities[entity.id] = entity
	model:SetAttribute("EntityId", entity.id)
	EntityService.UpdatePosition(entity)
	EntityService.Registered:Fire(entity)
	return entity
end

function EntityService.Unregister(entity: Entity)
	if entities[entity.id] ~= entity then
		return
	end
	entities[entity.id] = nil
	local key = cellOf[entity]
	if key then
		local cell = grid[key]
		if cell then
			cell[entity] = nil
			if next(cell) == nil then
				grid[key] = nil
			end
		end
		cellOf[entity] = nil
	end
	EntityService.Unregistered:Fire(entity)
end

-- Moves a monster entity to its current grid cell (call after it moved).
function EntityService.UpdatePosition(entity: Entity)
	if entity.kind ~= "monster" then
		return
	end
	local position = EntityService.Position(entity)
	if not position then
		return
	end
	local key = cellKey(position.X, position.Z)
	local old = cellOf[entity]
	if old == key then
		return
	end
	if old then
		local cell = grid[old]
		if cell then
			cell[entity] = nil
			if next(cell) == nil then
				grid[old] = nil
			end
		end
	end
	local cell = grid[key]
	if not cell then
		cell = {}
		grid[key] = cell
	end
	cell[entity] = true
	cellOf[entity] = key
end

-- Monster entities within `radius` of `position`.
function EntityService.QueryMonsters(position: Vector3, radius: number): { Entity }
	local result = {}
	local minX, maxX = (position.X - radius) // CELL, (position.X + radius) // CELL
	local minZ, maxZ = (position.Z - radius) // CELL, (position.Z + radius) // CELL
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local cell = grid[`{cx},{cz}`]
			if cell then
				for entity in cell do
					local p = EntityService.Position(entity)
					if p and (p - position).Magnitude <= radius then
						table.insert(result, entity)
					end
				end
			end
		end
	end
	return result
end

-- Player entities (with a spawned model) within `radius`.
function EntityService.QueryPlayers(position: Vector3, radius: number): { Entity }
	local result = {}
	for _, entity in playerEntities do
		local p = EntityService.Position(entity)
		if p and (p - position).Magnitude <= radius then
			table.insert(result, entity)
		end
	end
	return result
end

-- Players within `radius` (convenience for effects).
function EntityService.PlayersNear(position: Vector3, radius: number): { Player }
	local list = {}
	for _, entity in EntityService.QueryPlayers(position, radius) do
		table.insert(list, entity.player :: Player)
	end
	return list
end

function EntityService.CountMonsters(): number
	local n = 0
	for _, entity in entities do
		if entity.kind == "monster" then
			n += 1
		end
	end
	return n
end

-- Players -----------------------------------------------------------------------------------------------

local function registerPlayerModel(player: Player, model: Model)
	local existing = playerEntities[player]
	if existing then
		existing.model = model
		model:SetAttribute("EntityId", existing.id)
		return
	end
	local entity: Entity = { id = `p{player.UserId}`, kind = "player", player = player, model = model }
	playerEntities[player] = entity
	entities[entity.id] = entity
	model:SetAttribute("EntityId", entity.id)
	EntityService.Registered:Fire(entity)
end

local function unregisterPlayer(player: Player)
	local entity = playerEntities[player]
	if entity then
		playerEntities[player] = nil
		EntityService.Unregister(entity)
	end
end

function EntityService.Init(registry)
	CharacterService = registry.Get("CharacterService")
end

function EntityService.Start()
	CharacterService.ModelSpawned:Connect(registerPlayerModel)
	CharacterService.CharacterLeaving:Connect(unregisterPlayer)
	Players.PlayerRemoving:Connect(unregisterPlayer)
end

return EntityService
