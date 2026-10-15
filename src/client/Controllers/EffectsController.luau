--!strict
-- World effects drawn locally: level-up pillar of light (DESIGN §4.6); the golden glow of the respawn
-- protection (S22) on every character whose "Effects" attribute lists "respawnShield" (not on low quality).
-- S59 (ROZWOJ 4): after the local level-up toast, toasts for path points, skill ranks and new breakpoints to choose
-- (Logic/PathView.rankUps / newBreakpoints between LevelUp's fromLevel and the new level).
-- S65: the lasting rune of a glowing Runic Seal ("runeSeal" in "Effects") under every such character.
-- S123: the level-up effect follows the player's CosmeticLevelUp attribute (five styles, levelUpFx); PlayLevelUp is
-- the wardrobe's local preview. LevelService is unchanged: the LevelUp event already names the player.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Clock = require(script.Parent.Parent.Vfx.Clock)
local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Net = require(ReplicatedStorage.Shared.Net)
local PathView = require(ReplicatedStorage.Shared.Logic.PathView)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local State = require(script.Parent.Parent.UI.State)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Library = require(script.Parent.Parent.Vfx.Library)

local EffectsController = {
	Name = "EffectsController",
	Deps = { "UIController", "SfxController" },
}

local SfxController: any

local PILLAR_HEIGHT = 80
local PILLAR_SECONDS = 2.2

local folder: Folder

-- S123: the level-up pillar of S22 in the colours of the style (the default style is the old gold pillar).
local function pillar(model: Model, look: CosmeticRules.LevelUpLook)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)
	local main = Color3.fromHex(look.color)
	local second = Color3.fromHex(look.color2)

	local beam = Instance.new("Part")
	beam.Name = "LevelUpPillar"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = main
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(PILLAR_HEIGHT, 1, 1)
	beam.CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Transparency = 0.15
	beam.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = main
	light.Range = 24
	light.Brightness = 3
	light.Parent = beam

	local ring = Instance.new("Part")
	ring.Name = "LevelUpRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = second
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 4, 4)
	ring.CFrame = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = folder

	local info = TweenInfo.new(PILLAR_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(beam, info, { Size = Vector3.new(PILLAR_HEIGHT, 7, 7), Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	TweenService:Create(ring, info, { Size = Vector3.new(0.3, 26, 26), Transparency = 1 }):Play()
	Debris:AddItem(beam, PILLAR_SECONDS + 0.2)
	Debris:AddItem(ring, PILLAR_SECONDS + 0.2)
end

-- S123 (DESIGN-17 §4): the level-up effect of a style (Logic/CosmeticRules.levelUpStyle of the player's attribute
-- CosmeticLevelUp): pillar (the S22 pillar and ring in its colours), rings (three rings one after another), runes (a
-- rune circle on the ground and the pillar), embers (the pillar, sparks rising, smoke), frost (rings and frost
-- shards). The extra pieces come from Vfx/Library (S112: textures, pooled holders, the low quality and phone limits);
-- every style keeps the pillar's cost class (no per-frame instances).
local function levelUpFx(model: Model, look: CosmeticRules.LevelUpLook)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	local main = Color3.fromHex(look.color)
	local second = Color3.fromHex(look.color2)
	local function rings()
		for i = 0, 2 do
			Clock.after(i * 0.35, function()
				Library.ringWave(feet, 5 + i * 2, if i % 2 == 0 then main else second, { seconds = 0.7 })
			end)
		end
	end
	if look.style == "rings" then
		rings()
		return
	elseif look.style == "frost" then
		rings()
		Library.sparks(feet + Vector3.new(0, 1, 0), second, {
			key = "iceShard",
			count = 14,
			speed = { 8, 16 },
			life = { 0.6, 1.1 },
			gravity = 18,
		})
		return
	end
	pillar(model, look)
	if look.style == "runes" then
		Library.magicCircle(feet, 6, main, PILLAR_SECONDS)
	elseif look.style == "embers" then
		Library.sparks(feet + Vector3.new(0, 1, 0), second, {
			count = 18,
			speed = { 6, 14 },
			life = { 0.8, 1.4 },
			gravity = -4,
		})
		Library.smokePuff(feet, 2, main)
	end
end

-- S123: the level-up effect on `model` (the wardrobe's preview plays it on the own character, only here).
function EffectsController.PlayLevelUp(model: Model, look: CosmeticRules.LevelUpLook)
	levelUpFx(model, look)
end

-- S123: the look of a player's level-up (their attribute CosmeticLevelUp; the gold pillar without one).
local function lookOf(player: Player): CosmeticRules.LevelUpLook
	local id = player:GetAttribute("CosmeticLevelUp")
	return CosmeticRules.levelUpStyle(if type(id) == "string" then Cosmetics.get(id) else nil)
end

function EffectsController.Init(registry: any)
	SfxController = registry.Get("SfxController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Effects"
	folder.Parent = Workspace
end

-- Respawn protection glow (S22) ------------------------------------------------------------------------------

local GLOW = "VaelthornRespawnGlow"

local function hasEffect(model: Model, kind: string): boolean
	for _, entry in EffectStack.decode(model:GetAttribute("Effects"), Workspace:GetServerTimeNow()) do
		if entry.kind == kind then
			return true
		end
	end
	return false
end

local function hasShield(model: Model): boolean
	for _, entry in EffectStack.decode(model:GetAttribute("Effects"), Workspace:GetServerTimeNow()) do
		if entry.kind == "respawnShield" then
			return true
		end
	end
	return false
end

local function addGlow(model: Model, root: BasePart)
	local glow = Instance.new("Part")
	glow.Name = GLOW
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * 7
	glow.Color = Color3.fromHex("#FFD86E")
	glow.Material = Enum.Material.ForceField
	glow.Transparency = 0.2
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	glow.Massless = true
	glow.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = glow
	weld.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = glow
	glow.Parent = model
	TweenService:Create(
		glow,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.55 }
	):Play()
end

-- S65: Runic Seal runes by character model (cleanup of Library.sealRune).
local SEAL_COLOR = Color3.fromHex("#8FB8FF")
local seals: { [Model]: () -> () } = {}

local function refreshSeals(low: boolean)
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local model = player.Character
		if model and model.Parent and hasEffect(model, "runeSeal") then
			seen[model] = true
			if not seals[model] then
				seals[model] = Library.sealRune(model, SEAL_COLOR, low)
			end
		end
	end
	for model, cleanup in seals do
		if not seen[model] then
			cleanup()
			seals[model] = nil
		end
	end
end

local function refreshGlows()
	local low = State.Get({ "account", "settings", "quality" }) == "low"
	refreshSeals(low)
	for _, player in Players:GetPlayers() do
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if model and root then
			local glow = model:FindFirstChild(GLOW)
			local wanted = not low and hasShield(model)
			if wanted and not glow then
				addGlow(model, root)
			elseif not wanted and glow then
				glow:Destroy()
			end
		end
	end
end

local MAX_RANK_TOASTS = 3
local MAX_BP_TOASTS = 2

local function skillName(skillId: string): string
	local skill = SkillData.get(skillId)
	return if skill then Text.now(skill.nameKey) else skillId
end

-- Path points, rank-ups and new breakpoints of a local level-up (the event comes before the state diff, so the
-- character is the class and path from State with the new level).
local function progressToasts(from: number, to: number, pathPoints: number?)
	local class = State.Get({ "character", "class" })
	if type(class) ~= "string" or class == "" then
		return
	end
	local points = if type(pathPoints) == "number" then pathPoints else 0
	if points > 0 then
		local soon = not Paths.classHasPaths(class)
		local key = if points == 1
			then (if soon then "paths.toast.pointSoon" else "paths.toast.point")
			else (if soon then "paths.toast.pointsSoon" else "paths.toast.points")
		Toast.push(Text.now(key, { n = points }), "success", 4)
	end
	local character = { class = class, level = to, path = State.Get({ "character", "path" }) }
	local ranks = PathView.rankUps(character, from, to)
	if #ranks > MAX_RANK_TOASTS then
		Toast.push(Text.now("skills.toast.ranks", { n = #ranks }), "info")
	else
		for _, up in ranks do
			Toast.push(Text.now("skills.toast.rank", { skill = skillName(up.skillId), rank = up.rank }), "info")
		end
	end
	local fresh = PathView.newBreakpoints(character, from, to)
	if #fresh > MAX_BP_TOASTS then
		Toast.push(Text.now("bp.toast.many", { n = #fresh }), "warning")
	else
		for _, bp in fresh do
			Toast.push(Text.now("bp.toast.new", { skill = skillName(bp.skillId), rank = bp.at }), "warning")
		end
	end
end

function EffectsController.Start()
	local glowCheck = 0
	RunService.Heartbeat:Connect(function(dt: number)
		glowCheck += dt
		if glowCheck >= 0.25 then
			glowCheck = 0
			refreshGlows()
		end
	end)
	Net.On(
		"LevelUp",
		function(player: Player, level: number, statPoints: number, pathPoints: number?, fromLevel: number?)
			if typeof(player) ~= "Instance" or not player:IsA("Player") then
				return
			end
			local model = player.Character
			if model then
				levelUpFx(model, lookOf(player))
			end
			if player == Players.LocalPlayer then
				-- S111: ui.levelup, the old placeholder while it has no sound
				if not SfxController.Ui("ui.levelup") then
					Sounds.play("levelUp")
				end
				Toast.push(Text.now("toast.levelUp", { level = level, stat = statPoints }), "success", 5)
				progressToasts(if type(fromLevel) == "number" then fromLevel else level - 1, level, pathPoints)
			end
		end
	)
end

return EffectsController
