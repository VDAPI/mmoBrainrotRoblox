--!strict
-- Look preview (S132, DESIGN-17 §9a): a rotating figure in a ViewportFrame (the camera orbit of the wardrobe) wearing a
-- class look: a clone of the server's mannequin (Util/AvatarBuild.previewFigure; the block figure without it) with the
-- procedural look of Logic/CharacterLook.resolve for the given class, face / skin / hair, outfit, dye and mode.
-- Catalog pieces show their procedural garment here (a description can only be applied on the server).
-- W10: dragging (mouse or finger) turns the figure, it turns slowly by itself after a pause; `Focus` = "face" brings the
-- camera to the head (the creator's Face and Paint tabs); warm key light over a cool fill.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AvatarBuild = require(ReplicatedStorage.Shared.Util.AvatarBuild)
local CharacterLook = require(ReplicatedStorage.Shared.Logic.CharacterLook)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	ClassId: UsedAs<string?>,
	Look: UsedAs<any>,
	OutfitId: UsedAs<string?>?,
	Dye: UsedAs<string?>?,
	Avatar: UsedAs<boolean>?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: number?,
	Visible: UsedAs<boolean>?,
	Focus: UsedAs<string?>?, -- W10: "face" = close on the head, else the whole figure
}

local ORBIT = 11
local FACE_ORBIT = 3.6 -- W10: the camera close on the head
local DRAG = 0.012 -- radians per pixel dragged
local IDLE = 3 -- seconds after a drag before the figure turns by itself

local function LookPreview(scope: Scope, props: Props): Instance
	local viewport = scope:New("ViewportFrame")({
		Name = "LookPreview",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.fromOffset(330, 370),
		Visible = props.Visible,
		BackgroundColor3 = Theme.Iron.Sunken,
		Active = true, -- W10: a drag on the preview turns the figure, not the camera
		Ambient = Color3.fromRGB(140, 146, 160),
		LightColor = Color3.fromRGB(255, 226, 190),
		LightDirection = Vector3.new(-0.8, -0.6, -1),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Iron.Rule }),
		},
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	table.insert(scope, camera)

	local figure = AvatarBuild.previewFigure()
	figure.Parent = viewport
	table.insert(scope, figure)

	local spec = scope:Computed(function(use): CharacterLook.LookSpec?
		local classId = use(props.ClassId)
		if type(classId) ~= "string" then
			return nil
		end
		return CharacterLook.resolve({
			classId = classId,
			look = use(props.Look),
			outfitId = use(props.OutfitId),
			dye = use(props.Dye),
			robloxAvatar = use(props.Avatar) == true,
		})
	end)
	local function redraw()
		local s = Fusion.peek(spec)
		if s then
			AvatarBuild.applyProcedural(figure, s, true)
		else
			AvatarBuild.clearProcedural(figure)
		end
	end
	redraw()
	scope:Observer(spec):onChange(redraw)

	-- W10: turn by dragging; after IDLE seconds without a drag the figure turns slowly again
	local angle = math.pi
	local dragging: InputObject? = nil
	local lastX = 0
	local idle = IDLE
	local zoom = 0 -- 0 = whole figure, 1 = the face
	table.insert(
		scope,
		viewport.InputBegan:Connect(function(input: InputObject)
			local t = input.UserInputType
			if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
				dragging = input
				lastX = input.Position.X
				idle = 0
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local d = dragging
			if not d then
				return
			end
			local moved = input.UserInputType == Enum.UserInputType.MouseMovement
				or (input.UserInputType == Enum.UserInputType.Touch and input == d)
			if moved then
				angle -= (input.Position.X - lastX) * DRAG
				lastX = input.Position.X
				idle = 0
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = nil
			end
		end)
	)
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			if not viewport.Visible then
				return
			end
			if not dragging then
				idle += dt
				if idle > IDLE then
					angle += dt * 0.4
				end
			end
			local want = if Fusion.peek(props.Focus :: any) == "face" then 1 else 0
			zoom += (want - zoom) * math.min(1, dt * 6)
			local head = figure:FindFirstChild("Head")
			local headY = if head and head:IsA("BasePart") then head.Position.Y else 1.6
			local radius = ORBIT + (FACE_ORBIT - ORBIT) * zoom
			local targetY = 0.2 + (headY - 0.2) * zoom
			local eyeY = 1.5 + (headY + 0.15 - 1.5) * zoom
			camera.CFrame = CFrame.new(
				Vector3.new(math.sin(angle) * radius, eyeY, math.cos(angle) * radius),
				Vector3.new(0, targetY, 0)
			)
		end)
	)
	return viewport
end

return LookPreview
