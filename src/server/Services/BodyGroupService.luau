--!strict
-- The collision groups of the bodies (Data/BodyGroups): registered at Init, before any service starts (a part may
-- only join a registered group), then every part of a player character joins "Players" and every part under
-- Workspace.Monsters "Monsters" (a monster's blocker "MonsterBlockers"), parts added later too (accessories, tools, a
-- new spawn). A player bumps into a monster's blocker, never into its root (owner 2026-11-10: a monster running into
-- the player lifted him onto its root); CompanionService puts its figures in "Companions".

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BodyGroups = require(ReplicatedStorage.Shared.Data.BodyGroups)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("BodyGroupService")

local BodyGroupService = {
	Name = "BodyGroupService",
	Deps = {},
}

-- Puts every part under `root` into the group `groupOf` names for it, now and as parts arrive.
local function keep(root: Instance, groupOf: (name: string) -> string)
	for _, item in root:GetDescendants() do
		if item:IsA("BasePart") then
			item.CollisionGroup = groupOf(item.Name)
		end
	end
	root.DescendantAdded:Connect(function(item)
		if item:IsA("BasePart") then
			item.CollisionGroup = groupOf(item.Name)
		end
	end)
end

local function playerPart(_name: string): string
	return BodyGroups.PLAYERS
end

local function register()
	for _, name in BodyGroups.ALL do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	for _, pair in BodyGroups.APART do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
	end
end

function BodyGroupService.Init(_registry)
	local ok, err = pcall(register :: any)
	if not ok then
		log:warn("collision groups: %s", tostring(err))
	end
end

function BodyGroupService.Start()
	local function watch(player: Player)
		if player.Character then
			keep(player.Character, playerPart)
		end
		player.CharacterAdded:Connect(function(character: Model)
			keep(character, playerPart)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	task.spawn(function()
		local monsters = Workspace:WaitForChild("Monsters", 600)
		if monsters then
			keep(monsters, BodyGroups.monsterPart)
		end
	end)
end

return BodyGroupService
