--!strict
-- Look preview (S132, DESIGN-17 §9a): a rotating figure in a ViewportFrame (the camera orbit of the wardrobe) wearing a
-- class look: a clone of the server's mannequin (Util/AvatarBuild.previewFigure; the block figure without it) with the
-- procedural look of Logic/CharacterLook.resolve for the given class, face / skin / hair, outfit, dye and mode.
-- Catalog pieces show their procedural garment here (a description can only be applied on the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
}

local ORBIT = 11

local function LookPreview(scope: Scope, props: Props): Instance
	local viewport = scope:New("ViewportFrame")({
		Name = "LookPreview",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.fromOffset(330, 370),
		Visible = props.Visible,
		BackgroundColor3 = Theme.Iron.Sunken,
		Ambient = Color3.fromRGB(160, 150, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -1),
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

	local angle = math.pi
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			if not viewport.Visible then
				return
			end
			angle += dt * 0.6
			camera.CFrame =
				CFrame.new(Vector3.new(math.sin(angle) * ORBIT, 1.5, math.cos(angle) * ORBIT), Vector3.new(0, 0.2, 0))
		end)
	)
	return viewport
end

return LookPreview
