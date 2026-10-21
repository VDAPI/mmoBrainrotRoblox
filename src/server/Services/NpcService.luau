--!strict
-- City NPCs (Data/Npcs). Builds an R15 figure per NPC (W31: dressed by role, below), its root anchored in place.
-- Clients add the localized nameplate and the "Talk [E]" prompt
-- (NpcController); every service call on the server checks the distance with NpcService.Near.
-- S21: in the city NPCs stand on the plan's terrain (TownTerrain.heightAt); `body = "board"` NPCs (the quest
-- board) get no figure, only an invisible anchored Head over the board model the city already has.
-- S29: feet on the ground. The ground ray ignores NPCs and characters and stops on the top surface of the map's
-- own geometry (porch, stairs, paving; WorldService.FloorAt); after placing, the figure's real lowest corner
-- (Logic/Footing) is moved onto that ground and HipHeight is set to match.
-- W30: an owner's model at ReplicatedStorage.Assets.Npcs.<id> (docs/wyglad TRIPO-NPC.md) replaces the drawn figure: it
-- is fitted to the figure (Logic/NpcAssetFit), welded to the root part and the R15 body under it is hidden (it keeps the
-- Humanoid, the Head for the nameplate and the feet for Footing).
-- W31 (owner 2026-10-21: "about 60 NPCs stand as bare default avatars, frozen"): an NPC without the owner's model
-- wears the player's body and its role's outfit (Logic/NpcLook, Util/AvatarBuild; the Roblox hairstyles once
-- CosmeticService has loaded them), the smith holds a hammer, and only the root part is anchored: the limbs hang on
-- their Motor6Ds (the body's AnimationConstraints turned into them, Util/RigJoints), which every client poses
-- (NpcAnimController: breathing, looks, talk gestures). No Animator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local AvatarBuild = require(Shared.Util.AvatarBuild)
local BodyLooks = require(Shared.Data.BodyLooks)
local CharacterLook = require(Shared.Logic.CharacterLook)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Npcs = require(Shared.Data.Npcs)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Footing = require(Shared.Logic.Footing)
local LookBuild = require(Shared.Util.LookBuild)
local NpcAssetFit = require(Shared.Logic.NpcAssetFit)
local NpcLook = require(Shared.Logic.NpcLook)
local RigJoints = require(Shared.Util.RigJoints)
local MapTerrain = require(Shared.Logic.MapTerrain)

local log = Log.new("NpcService")

local NpcService = {
	Name = "NpcService",
	Deps = { "WorldService" },
}

local TOLERANCE = 4
-- The ground ray starts this far over the plan height: over a porch or stairs, under stall awnings and roofs.
local RAY_OVER_PLAN = 6
-- Lifts larger than this are reported once in the log (diagnostics for the owner).
local REPORT_LIFT = 0.3

local WorldService: any = nil

local positions: { [string]: Vector3 } = {}
-- S159w: the World.Npcs folder (Start) and the figures placed at run time (PlaceAt), by NPC id
local npcFolder: Folder? = nil
local placed: { [string]: Model } = {}
-- W31: the placed figures in an outfit and its look, dressed again once the Roblox hairstyles have loaded
local dressed: { [Model]: CharacterLook.LookSpec } = setmetatable({}, { __mode = "k" }) :: any

-- S103: the look of a ghost NPC (NpcDef.ghost; looks, not balance): every visible part half-transparent, smooth and
-- without a shadow, and a cold light in the chest, the same "wraith" colour as the Tomb of Morvane (CaveDress/Tomb).
-- On the Figure, so a companion clone and the world map preview look the same.
local GHOST_TRANSPARENCY = 0.45
local GHOST_LIGHT = Color3.fromHex("#9FE0C9")
local GHOST_RANGE = 10
local GHOST_BRIGHTNESS = 0.8

local function ghostLook(npc: Model)
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			part.Transparency = math.max(part.Transparency, GHOST_TRANSPARENCY)
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	local chest = (npc:FindFirstChild("UpperTorso") or npc:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if chest and not chest:FindFirstChild("GhostLight") then
		local light = Instance.new("PointLight")
		light.Name = "GhostLight"
		light.Color = GHOST_LIGHT
		light.Range = GHOST_RANGE
		light.Brightness = GHOST_BRIGHTNESS
		light.Shadows = false
		light.Parent = chest
	end
end

-- W30: the owner's model of the NPC (ReplicatedStorage.Assets.Npcs.<id>, numbered NPCs like guard1 / guard2 also share
-- Assets.Npcs.guard), or nil. No warning when it is missing: most NPCs have no model yet and keep the figure.
local function assetTemplate(id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	local source = folder:FindFirstChild(id) or folder:FindFirstChild((string.gsub(id, "%d+$", "")))
	return if source and source:IsA("Model") then source else nil
end

-- Puts the owner's model on the figure: the figure's height and facing, its bottom on the figure's feet, welded to the
-- root part without collision; the R15 parts under it go invisible. False (nothing changed) without a usable model.
local function dressAsset(npc: Model, def: Npcs.NpcDef): boolean
	local template = assetTemplate(def.id)
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not template or not root then
		return false
	end
	local clone = template:Clone()
	if LookBuild.stripScripts(clone) > 0 then
		log:warn("removed scripts from Assets.Npcs.%s", def.id)
	end
	local figureFrame, figureSize = npc:GetBoundingBox()
	clone:PivotTo(
		CFrame.new(clone:GetPivot().Position)
			* root.CFrame.Rotation
			* CFrame.Angles(0, NpcAssetFit.yaw(clone:GetAttribute("Yaw")), 0)
	)
	local _, modelSize = clone:GetBoundingBox()
	local factor = NpcAssetFit.scale(modelSize.Y, figureSize.Y, clone:GetAttribute("Scale"))
	if not factor then
		log:warn("Assets.Npcs.%s has no height: the figure stays", def.id)
		clone:Destroy()
		return false
	end
	clone:ScaleTo(clone:GetScale() * factor)
	local modelFrame, scaledSize = clone:GetBoundingBox()
	local feet = Vector3.new(root.Position.X, figureFrame.Position.Y - figureSize.Y / 2, root.Position.Z)
	local bottom = modelFrame.Position - Vector3.new(0, scaledSize.Y / 2, 0)
	clone:PivotTo(clone:GetPivot() + (feet - bottom))
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
		if part:IsA("Decal") then
			part.Transparency = 1 -- the face on the hidden head
		end
	end
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	clone.Name = "Asset"
	clone.Parent = npc
	npc:SetAttribute("NpcAsset", true)
	return true
end

-- Ground point under the NPC (the world is built in WorldService.Init, before Start): the top surface of the
-- terrain or the map's geometry under a ray from just over the plan height (Logic/MapTerrain: the city, S26 the
-- Meadows; y = 0 elsewhere). S29: NPCs and characters are ignored (WorldService.FloorAt), so a figure never
-- stands on another one.
local function worldPosition(def: Npcs.NpcDef): Vector3
	local map = Maps.get(def.map)
	if not map then
		return Vector3.new(def.position.x, 0, def.position.z)
	end
	local planned = MapTerrain.height(def.map, def.position.x, def.position.z)
	local fromY = if planned then planned + RAY_OVER_PLAN else nil
	return WorldService.FloorAt(def.map, def.position.x, def.position.z, fromY)
end

-- Every part that shapes the figure's silhouette, as Footing boxes: not the root part (it hangs at hip
-- height) and not accessory handles.
local function bodyBoxes(model: Model): { Footing.Box }
	local out: { Footing.Box } = {}
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then
			continue
		end
		if part.Parent and part.Parent:IsA("Accessory") then
			continue
		end
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
		local p, size = part.Position, part.Size
		table.insert(out, {
			p = { p.X, p.Y, p.Z },
			r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			size = { size.X, size.Y, size.Z },
		})
	end
	return out
end

-- Moves the placed figure so its lowest corner rests on groundY and makes HipHeight agree.
local function settle(npc: Model, def: Npcs.NpcDef, groundY: number)
	local dy = Footing.liftFor(bodyBoxes(npc), groundY)
	npc:PivotTo(npc:GetPivot() + Vector3.new(0, dy, 0))
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root then
		humanoid.HipHeight = Footing.hipHeight(root.Position.Y, root.Size.Y, groundY)
	end
	if math.abs(dy) > REPORT_LIFT then
		print(`[Npc] lift {def.id} {string.format("%.2f", dy)}`)
	end
end

-- Quest board (S21): an invisible anchored Head (nameplate, prompt and quest marker hang on it) about 5 studs
-- over the ground, inside the board model built by the city layout. No Humanoid.
local function buildBoard(def: Npcs.NpcDef, parent: Instance)
	local position = worldPosition(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(4, 3, 1)
	head.Transparency = 1
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(def.facing), 0)
	head.Parent = model
	model.PrimaryPart = head
	model:SetAttribute("NpcId", def.id)
	-- S25: always on every client (the world map clones NPCs for its 3D preview).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	positions[def.id] = position
end

-- The plain R15 figure in the NPC's colours (W30: under the owner's model, which hides it; W31: the fallback when the
-- dressed body cannot be built). Nil when Roblox could not build it.
local function plainFigure(def: Npcs.NpcDef): Model?
	local description = Instance.new("HumanoidDescription")
	local body = Color3.fromHex(def.colors.body)
	local skin = Color3.fromHex("#C9A27E")
	description.HeadColor = skin
	description.LeftArmColor = body
	description.RightArmColor = body
	description.TorsoColor = body
	description.LeftLegColor = Color3.fromHex("#2F2F35")
	description.RightLegColor = Color3.fromHex("#2F2F35")
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		log:warn("could not build NPC %s: %s", def.id, tostring(model))
		return nil
	end
	return model :: Model
end

-- W31: the player's body (Data/BodyLooks) with the NPC's face and build (Logic/NpcLook), nil when Roblox could not
-- build it (the plain figure takes its place, the outfit is drawn over that).
local function dressedFigure(def: Npcs.NpcDef, spec: CharacterLook.LookSpec): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(AvatarBuild.description(spec, nil), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		log:warn("could not dress NPC %s (%s): the plain figure in its outfit", def.id, tostring(model))
		return nil
	end
	return model :: Model
end

-- W31: the smith's hammer in the right hand, so the hammering of NpcAnimController reads as work (the handle forward
-- out of the fist, the head at its end).
local HAMMER_WOOD = Color3.fromHex("#6B4A2B")
local HAMMER_IRON = Color3.fromHex("#5E6670")

local function holdHammer(npc: Model)
	local hand = npc:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "NpcTool"
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
		part.Parent = folder
	end
	piece("Handle", Vector3.new(0.2, 0.2, 1.5), CFrame.new(0, -0.05, -0.45), HAMMER_WOOD, Enum.Material.Wood)
	piece("Head", Vector3.new(0.42, 0.75, 0.42), CFrame.new(0, -0.05, -1.15), HAMMER_IRON, Enum.Material.Metal)
	folder.Parent = npc
end

-- Whether the NPC works at the anvil (NpcAnimController hammers for the same rule).
local function works(def: Npcs.NpcDef): boolean
	return table.find(def.services, "blacksmith" :: any) ~= nil
end

-- The NPC's figure and, for one in an outfit (W31), its look; unparented, without NpcId, plate or placement.
local function figure(def: Npcs.NpcDef): (Model?, CharacterLook.LookSpec?)
	local asset = assetTemplate(def.id) ~= nil
	local spec = NpcLook.resolve(def)
	local npc = if spec and not asset then dressedFigure(def, spec) else nil
	npc = npc or plainFigure(def)
	if not npc then
		return nil, nil
	end
	npc.Name = def.id
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	if asset and dressAsset(npc, def) then
		spec = nil
	elseif spec then
		-- the lashes are a layered accessory per NPC for a detail nobody sees at that distance
		for _, child in npc:GetChildren() do
			if child:IsA("Accessory") and child.AccessoryType == Enum.AccessoryType.Eyelash then
				child:Destroy()
			end
		end
		AvatarBuild.solveJoints(npc)
		AvatarBuild.applyProcedural(npc, spec)
		if works(def) then
			holdHammer(npc)
		end
	end
	if def.ghost then
		ghostLook(npc)
	end
	return npc, spec
end

-- S101b: shared by CompanionService. The NPC's figure (W31: in its outfit, or the owner's model over the plain one),
-- unparented and unanchored, without NpcId, plate or placement; nil when Roblox could not build it. Yields.
function NpcService.Figure(def: Npcs.NpcDef): Model?
	return (figure(def))
end

local function build(def: Npcs.NpcDef, parent: Instance)
	-- W31: the place first: the dressed body yields while its parts load, and the services ask Near meanwhile
	local position = worldPosition(def)
	positions[def.id] = position
	local npc, spec = figure(def)
	if not npc then
		return
	end
	LookBuild.stripScripts(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- W31: the client poses the joints itself (NpcAnimController); an Animator would write over them
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	-- W31 (Studio check: the dressed NPCs still stood like statues): the dressed body's joints are AnimationConstraints
	-- (the avatar joint upgrade), which hold the limbs physically, not as one body with the anchored root, so the
	-- limbs were anchored below as loose parts and NpcRig found no Motor6D; each becomes the Motor6D it stands for
	RigJoints.motorize(npc, Instance.new)
	-- W31: only the root part is anchored, the limbs hang on their joints so the clients can move them
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = root == nil or part == root
		end
	end
	local height = if root and humanoid then humanoid.HipHeight + root.Size.Y / 2 else 3
	npc:PivotTo(CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, math.rad(def.facing), 0))
	npc:SetAttribute("NpcId", def.id)
	-- S25: Persistent (~15 light models) so the world map can clone any NPC for its 3D preview, even one on
	-- another map or out of the streaming radius.
	npc.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	npc.Parent = parent
	if root then
		-- a part no rigid joint holds to the root would fall: it stays where it is
		local held: { [BasePart]: boolean } = { [root] = true }
		for _, part in root:GetConnectedParts(true) do
			held[part] = true
		end
		for _, part in npc:GetDescendants() do
			if part:IsA("BasePart") and not held[part] then
				part.Anchored = true
			end
		end
	end
	settle(npc, def, position.Y)
	if spec then
		dressed[npc] = spec
	end
end

-- W31: once CosmeticService has loaded the Roblox hairstyles (ReplicatedStorage.VaelthornLookParts), the NPCs dressed
-- before that get them in place of the procedural hair.
local function redress()
	if not ReplicatedStorage:WaitForChild(BodyLooks.PARTS_FOLDER, 900) then
		return
	end
	for npc, spec in dressed do
		if npc.Parent then
			AvatarBuild.applyProcedural(npc, spec)
			local id = npc:GetAttribute("NpcId")
			local def = if type(id) == "string" then Npcs.get(id) else nil
			if def and def.ghost then
				ghostLook(npc)
			end
		end
	end
end

-- S159w: places the figure of an NPC that has no fixed place (Data/Npcs.WANDERER) at the map-relative (x, z) of `map`,
-- facing `facing` degrees, like a fixed one (feet on the ground, Persistent, NpcId); a figure placed before under the
-- same id goes first. Returns the model and its ground point (world), or nil when it could not be built.
function NpcService.PlaceAt(def: Npcs.NpcDef, map: string, x: number, z: number, facing: number): (Model?, Vector3?)
	NpcService.Remove(def.id)
	if not npcFolder then
		return nil, nil
	end
	local at = table.clone(def)
	at.map = map
	at.position = { x = x, z = z }
	at.facing = facing
	build(at, npcFolder)
	local model = npcFolder:FindFirstChild(def.id)
	if model and model:IsA("Model") then
		placed[def.id] = model
		return model, positions[def.id]
	end
	positions[def.id] = nil -- no figure: nobody stands there
	return nil, nil
end

-- S159w: removes a figure placed by PlaceAt (nothing for a fixed NPC); NpcService.Near is false for it afterwards.
function NpcService.Remove(npcId: string)
	local model = placed[npcId]
	if not model then
		return
	end
	placed[npcId] = nil
	positions[npcId] = nil
	model:Destroy()
end

-- Whether the player stands close enough to the NPC to use it.
function NpcService.Near(player: Player, npcId: string): boolean
	local position = positions[npcId]
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not position or not root then
		return false
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= Npcs.INTERACT_RANGE + TOLERANCE
end

-- NPC id the player is near that offers `service` (and, for shops, `shopId`), or nil.
function NpcService.NearService(player: Player, service: string, shopId: string?): string?
	for _, def in Npcs.list do
		if
			table.find(def.services, service :: any)
			and (shopId == nil or def.shop == shopId)
			and NpcService.Near(player, def.id)
		then
			return def.id
		end
	end
	return nil
end

function NpcService.Position(npcId: string): Vector3?
	return positions[npcId]
end

function NpcService.Init(registry: any)
	WorldService = registry.Get("WorldService")
end

function NpcService.Start()
	local world = Workspace:WaitForChild("World")
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = world
	npcFolder = folder
	if not ServerMode.isWorld() then
		return -- S127: no NPCs on arena/tournament servers (the empty folder: clients wait for it)
	end
	local function place(def: Npcs.NpcDef)
		if def.body == "board" then
			buildBoard(def, folder)
		else
			build(def, folder)
		end
	end
	-- FIX 2026-10-09: maps built in the background (S45 `buildLate`) have no terrain yet here, so the floor ray
	-- missed and their NPCs stood under the ground. Those wait for their map.
	-- W31: every figure in its own thread (the dressed body yields while its parts load); its place is set first
	local late = 0
	for _, def in Npcs.list do
		if WorldService.IsBuilding(def.map) then
			late += 1
			task.spawn(function()
				if not WorldService.WaitBuilt(def.map, 900) then
					log:warn("map %s not built, placing %s anyway", def.map, def.id)
				end
				place(def)
			end)
		else
			task.spawn(place, def)
		end
	end
	log:info("%d NPCs placing, %d wait for their map", #Npcs.list - late, late)
	task.spawn(redress)
end

return NpcService
