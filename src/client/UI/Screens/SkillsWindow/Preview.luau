--!strict
-- 3D preview of a skill (S28, moved in S59): a still copy of the local character in a viewport plays the skill's
-- animation and effect (VfxController.Preview), always without choices or nodes (ROZWOJ 2.7). Preview.new returns the
-- viewport and `play`; the copy and the Pool override are cleaned with the scope.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MountLook = require(ReplicatedStorage.Shared.Util.MountLook)
local Pool = require(script.Parent.Parent.Parent.Parent.Vfx.Pool)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Preview = {}

-- A still copy of the local character for the preview viewport (scripts and plates removed, root anchored).
local function mannequin(): Model?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = was
	if not copy then
		return nil
	end
	MountLook.strip(copy)
	for _, item in copy:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("BillboardGui")
			or item:IsA("ProximityPrompt")
			or item:IsA("Sound")
			or item:IsA("ForceField")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = item.Name == "HumanoidRootPart"
			item.CanCollide = false
		end
	end
	copy:SetAttribute("VaelthornPreview", true)
	copy:SetAttribute("EntityId", nil)
	copy:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(180), 0))
	return copy
end

-- `skillId`: the active skill to play (nil = nothing). `height` nil = fill the parent. `withButton`: the "Preview"
-- button in the corner (PC; the phone sheet has its own).
function Preview.new(
	scope: Scope,
	preview: ((model: Model, skillId: string) -> ())?,
	skillId: Fusion.UsedAs<string?>,
	height: number?,
	withButton: boolean
): (Instance, () -> ())
	local world = scope:New("WorldModel")({}) :: WorldModel
	local camera = scope:New("Camera")({
		FieldOfView = 40,
		CFrame = CFrame.lookAt(Vector3.new(7, 5, -11), Vector3.new(0, 3, 0)),
	}) :: Camera
	local copy: Model? = nil
	local function play()
		local id = Fusion.peek(skillId)
		if not id or not preview then
			return
		end
		if copy then
			copy:Destroy()
		end
		copy = mannequin()
		local model = copy
		if not model then
			return
		end
		model.Parent = world
		Pool.setOverride(world)
		preview(model, id)
		task.delay(2.5, function()
			Pool.setOverride(nil)
		end)
	end
	table.insert(scope, function()
		Pool.setOverride(nil)
		if copy then
			copy:Destroy()
		end
	end)
	local frame = scope:New("ViewportFrame")({
		Name = "Preview",
		Size = if height then UDim2.new(1, 0, 0, height) else UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Iron.Surface, -- S135: effects read better on iron than on parchment
		Ambient = Color3.fromRGB(150, 145, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.2, -0.8),
		CurrentCamera = camera,
		[Children] = {
			world :: any,
			camera :: any,
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) :: any,
			if withButton
				then Button(scope, {
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -6, 1, -6),
					Size = UDim2.fromOffset(120, 36),
					Variant = "secondary",
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "skills.preview"),
					Disabled = scope:Computed(function(use): boolean
						return use(skillId) == nil
					end),
					OnClick = play,
				}) :: any
				else nil,
		},
	})
	return frame, play
end

return Preview
