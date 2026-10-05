--!strict
-- Ground rings under monsters in the colour of their group size (S19, DESIGN §15.1): 1 grey-white, 2 green,
-- 3 orange, 4 red, from the GroupSize attribute (living members). Option "Monster group rings".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupColors = require(script.Parent.Parent.UI.GroupColors)
local State = require(script.Parent.Parent.UI.State)

local GroupRingController = {
	Name = "GroupRingController",
}

local folder: Folder
local rings: { [Model]: CylinderHandleAdornment } = {}
local scope = Fusion.scoped(Fusion)
local enabled = State.Value({ "account", "settings", "groupRings" })

local function shown(): boolean
	return Fusion.peek(enabled) ~= false
end

local function refresh(model: Model)
	local ring = rings[model]
	if not ring then
		return
	end
	local size = model:GetAttribute("GroupSize")
	ring.Color3 = GroupColors.of(if type(size) == "number" then size else 1)
	ring.Visible = shown() and model:GetAttribute("Dead") ~= true and type(size) == "number"
end

local function track(model: Instance)
	if not model:IsA("Model") or rings[model] or model:GetAttribute("GroupId") == nil then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") then
		return
	end
	local radius = math.max(root.Size.X, root.Size.Z) / 2 + 1.2
	local drop = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 0) - 0.15
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Name = "GroupRing"
	ring.Adornee = root
	ring.Radius = radius
	ring.InnerRadius = radius - 0.45
	ring.Height = 0.12
	ring.Transparency = 0.25
	ring.AlwaysOnTop = false
	ring.ZIndex = 1
	ring.CFrame = CFrame.new(0, -drop, 0) * CFrame.Angles(math.rad(90), 0, 0)
	ring.Parent = folder
	rings[model] = ring
	refresh(model)
	model:GetAttributeChangedSignal("GroupSize"):Connect(function()
		refresh(model)
	end)
	model:GetAttributeChangedSignal("Dead"):Connect(function()
		refresh(model)
	end)
	model.Destroying:Connect(function()
		ring:Destroy()
		rings[model] = nil
	end)
end

function GroupRingController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_GroupRings"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function GroupRingController.Start()
	scope:Observer(enabled):onChange(function()
		for model in rings do
			refresh(model)
		end
	end)
	local monsters = Workspace:WaitForChild("Monsters", 60)
	if not monsters then
		return
	end
	for _, child in monsters:GetChildren() do
		track(child)
	end
	monsters.ChildAdded:Connect(function(child)
		task.defer(track, child)
	end)
	monsters.ChildRemoved:Connect(function(child)
		local ring = rings[child :: Model]
		if ring then
			ring:Destroy()
			rings[child :: Model] = nil
		end
	end)
end

return GroupRingController
