--!strict
-- World effects drawn locally: level-up pillar of light (DESIGN §4.6). Later sessions add hit sparks,
-- damage numbers and the legendary drop beam here.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local EffectsController = {
	Name = "EffectsController",
	Deps = { "UIController" },
}

local PILLAR_HEIGHT = 80
local PILLAR_SECONDS = 2.2

local folder: Folder

local function pillar(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)

	local beam = Instance.new("Part")
	beam.Name = "LevelUpPillar"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Theme.Colors.GoldBright
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(PILLAR_HEIGHT, 1, 1)
	beam.CFrame = CFrame.new(base + Vector3.new(0, PILLAR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Transparency = 0.15
	beam.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = Theme.Colors.GoldBright
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
	ring.Color = Theme.Colors.Gold
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

function EffectsController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Effects"
	folder.Parent = Workspace
end

function EffectsController.Start()
	Net.On("LevelUp", function(player: Player, level: number, statPoints: number, skillPoints: number)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		local model = player.Character
		if model then
			pillar(model)
		end
		if player == Players.LocalPlayer then
			Sounds.play("levelUp")
			local key = if skillPoints > 0 then "toast.levelUp" else "toast.levelUpNoSkill"
			Toast.push(Text.now(key, { level = level, stat = statPoints, skill = skillPoints }), "success", 5)
		end
	end)
end

return EffectsController
