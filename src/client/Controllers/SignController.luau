--!strict
-- Writes on signposts (S19): every model tagged "Signpost" (World/Prefabs.signpost) gets a localized name
-- and, when it has LvMin / LvMax, the level range, on both sides of its board.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local SignController = {
	Name = "SignController",
}

local rootScope = Fusion.scoped(Fusion)

local function write(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local board = model:FindFirstChild("Board")
	local nameKey = model:GetAttribute("NameKey")
	if not board or not board:IsA("BasePart") or type(nameKey) ~= "string" or board:FindFirstChild("SignText") then
		return
	end
	local scope = rootScope:innerScope()
	model.Destroying:Connect(function()
		Fusion.doCleanup(scope)
	end)
	local lvMin, lvMax = model:GetAttribute("LvMin"), model:GetAttribute("LvMax")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		scope:New("SurfaceGui")({
			Name = "SignText",
			Face = face,
			Adornee = board,
			Parent = board,
			LightInfluence = 0.4,
			PixelsPerStud = 40,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			MaxDistance = 120,
			[Fusion.Children] = scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = scope:Computed(function(use): string
					local name = Text.get(use, nameKey)
					if type(lvMin) == "number" and type(lvMax) == "number" then
						return `{name}\n{Text.get(use, "sign.levels", { min = lvMin, max = lvMax })}`
					end
					return name
				end),
				TextScaled = true,
				FontFace = Theme.Fonts.Heading,
				TextColor3 = Color3.fromHex("#F2E6C9"),
				TextStrokeTransparency = 0.4,
			}),
		})
	end
end

function SignController.Start()
	for _, model in CollectionService:GetTagged("Signpost") do
		task.spawn(write, model)
	end
	CollectionService:GetInstanceAddedSignal("Signpost"):Connect(function(model)
		task.defer(write, model)
	end)
end

return SignController
