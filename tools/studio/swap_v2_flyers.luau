--!strict
-- Studio helper (2026-10-31): puts the new Tripo exports of the vulture, the crow and the bat (imported raw at the
-- Workspace top level: a Model > MeshPart with its bones + AnimationController + InitialPoses, front -Z, two copies of
-- each) into the game's monster asset format, and Teodor's (portalmaster, Mixamo) into the NPC asset format. Run in
-- Edit mode (Command Bar or the Studio MCP's execute_luau). The old model of each id and the second copy go to
-- ServerStorage.SwapV2Backup; nothing is deleted. Data/MonsterAssets stays as it is: the hitbox and the hip height are
-- the generator's, and the client takes the size from the model (client/Anim/FlyerRig: the bones' distances,
-- Data/FlyerRigs `measure` / `hover`).
-- * A monster (Assets.Monsters.<id>, built like wolf and peakHarpy): a 1x1x1 HumanoidRootPart (unanchored, CanCollide
--   false, CanQuery / CanTouch true, not massless) with the mesh's bottom HOVER studs above its centre, the mesh
--   (unanchored, CanCollide / CanQuery / CanTouch true) welded to it by a WeldConstraint, the root the PrimaryPart and
--   the pivot, the attribute Hover; no AnimationController and no InitialPoses (MonsterViewController adds its own).
-- * An NPC (Assets.Npcs.<id>, built like guard and banker): the import as it is, its AnimationController and
--   InitialPoses kept, the mesh anchored and not colliding (NpcService fits it to its figure's height and welds it,
--   Logic/NpcAssetFit).
-- Safe to run again: an id without a raw import in the Workspace is left alone, and a model already built (one with a
-- HumanoidRootPart) is never scaled or rebuilt a second time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- The raw import's scale factor (Model:ScaleTo) to the old model's size (Data/FlyerRigs `measure` of each new map).
-- Sizes after the swap (X x Y x Z studs): ashVulture 4.19 x 1.58 x 2.08, carrionCrow 3.19 x 1.86 x 1.43, bloodBat
-- 3.39 x 2.58 x 2.33.
local MONSTERS: { [string]: number } = { ashVulture = 0.042, carrionCrow = 0.032, bloodBat = 0.034 }
local NPCS = { "portalmaster" }
local HOVER = 2.5

local function folder(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local backup = folder(ServerStorage, "SwapV2Backup")

-- The raw import of `id` at the Workspace top level (the first copy; the others go to the backup): a model with a
-- mesh and no HumanoidRootPart. A model of that name already built is left where it is.
local function raw(id: string): (Model?, MeshPart?)
	local found: Model? = nil
	for _, item in workspace:GetChildren() do
		if item.Name ~= id or not item:IsA("Model") or not item:FindFirstChildWhichIsA("MeshPart") then
			continue
		end
		if item:FindFirstChild("HumanoidRootPart") then
			warn(`[swap] Workspace.{id} is already built: left alone`)
		elseif found then
			item.Parent = backup
		else
			found = item
		end
	end
	if not found then
		warn(`[swap] no raw import Workspace.{id}: skipped`)
		return nil, nil
	end
	return found, found:FindFirstChildWhichIsA("MeshPart") :: MeshPart
end

-- Moves the old model of `id` out of `into` and puts `model` there under that name.
local function replace(into: Instance, id: string, model: Model)
	local old = into:FindFirstChild(id)
	if old then
		print(`[swap] old {into.Name}.{id} attributes:`, old:GetAttributes())
		old.Name = `{id}_{into.Name}_old`
		old.Parent = backup
	end
	model.Name = id
	model.Parent = into
end

local assets = folder(ReplicatedStorage, "Assets")
for id, k in MONSTERS do
	local model, mesh = raw(id)
	if not model or not mesh then
		continue
	end
	for _, item in model:GetChildren() do
		if item:IsA("AnimationController") or item.Name == "InitialPoses" then
			item:Destroy()
		end
	end
	model.PrimaryPart = mesh
	model:ScaleTo(model:GetScale() * k) -- about its pivot, the bones with it; facing -Z already: no turn
	mesh.Anchored = false
	mesh.CanCollide = true
	mesh.CanQuery = true
	mesh.CanTouch = true
	local frame, size = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = false
	root.CanQuery = true
	root.CanTouch = true
	root.Massless = false
	root.CFrame = CFrame.new(frame.Position - Vector3.new(0, size.Y / 2 + HOVER, 0))
	root.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = mesh
	weld.Parent = root
	model.PrimaryPart = root
	model.WorldPivot = root.CFrame
	model:SetAttribute("Hover", HOVER)
	replace(folder(assets, "Monsters"), id, model)
	local bottom = frame.Position.Y - size.Y / 2 - root.Position.Y
	print(
		`[swap] Assets.Monsters.{id}: {string.format("%.2f x %.2f x %.2f", size.X, size.Y, size.Z)} studs, the mesh's`
			.. ` bottom {string.format("%.2f", bottom)} above the root`
	)
end
for _, id in NPCS do
	local model, mesh = raw(id)
	if not model or not mesh then
		continue
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	model.PrimaryPart = mesh
	replace(folder(assets, "Npcs"), id, model)
	print(`[swap] Assets.Npcs.{id} (AnimationController and InitialPoses kept)`)
end
