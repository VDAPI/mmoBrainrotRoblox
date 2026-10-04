--!strict
-- Billboard above every monster (DESIGN §15): name in the variant colour, level, and an HP bar that shows
-- once the monster is hurt or selected. Built client-side from model attributes so names are localized.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local MonsterPlateController = {
	Name = "MonsterPlateController",
	Deps = { "TargetController" },
}

-- Name colours per variant (DESIGN §15.1: elite red, Elite II purple).
local VARIANT_COLORS: { [string]: Color3 } = {
	normal = Color3.fromHex("#E8E4DA"),
	elite = Color3.fromHex("#E05A4A"),
	elite2 = Color3.fromHex("#C77BFF"),
}

MonsterPlateController.VariantColors = VARIANT_COLORS

local TargetController: any
local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder

local function attribute(scope: Scope, model: Model, name: string): Fusion.Value<any>
	local value = scope:Value(model:GetAttribute(name))
	table.insert(
		scope,
		model:GetAttributeChangedSignal(name):Connect(function()
			value:set(model:GetAttribute(name))
		end)
	)
	return value
end

local function build(model: Model)
	if not model:IsA("Model") then
		return
	end
	local monsterId = model:GetAttribute("MonsterId")
	if type(monsterId) ~= "string" then
		return
	end
	local def = Monsters.get(monsterId)
	local scope = rootScope:innerScope()
	table.insert(
		scope,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				Fusion.doCleanup(scope)
			end
		end)
	)

	local variant = attribute(scope, model, "Variant")
	local level = attribute(scope, model, "Level")
	local hp = attribute(scope, model, "Hp")
	local maxHp = attribute(scope, model, "MaxHp")
	local dead = attribute(scope, model, "Dead")

	local targeted = scope:Computed(function(use): boolean
		return use(TargetController.Target) == model
	end)
	local ratio = scope:Computed(function(use): number
		local m = use(maxHp)
		return if type(m) == "number" and m > 0 then math.clamp((use(hp) or 0) / m, 0, 1) else 1
	end)
	local showBar = scope:Computed(function(use): boolean
		return use(targeted) or use(ratio) < 1
	end)

	local _, size = model:GetBoundingBox()
	scope:New("BillboardGui")({
		Name = `Plate_{model:GetAttribute("EntityId")}`,
		Parent = folder,
		Adornee = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 90,
		Size = UDim2.fromOffset(200, 48),
		StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.6, 0),
		Enabled = scope:Computed(function(use): boolean
			return use(dead) ~= true
		end),
		[Children] = {
			scope:New("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				Text = scope:Computed(function(use): string
					local v = use(variant) or "normal"
					local name = if def then Text.get(use, def.nameKeys[v] or def.nameKeys.normal) else monsterId
					return Text.get(use, "monsterPlate.label", { name = name, level = use(level) or 1 })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 18,
				TextColor3 = scope:Computed(function(use): Color3
					return VARIANT_COLORS[use(variant) or "normal"] or VARIANT_COLORS.normal
				end),
				TextStrokeTransparency = 0.35,
			}),
			scope:New("Frame")({
				Name = "HpBar",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 28),
				Size = UDim2.fromOffset(120, 8),
				BackgroundColor3 = Theme.Colors.Background,
				Visible = showBar,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Background, Thickness = 1 }),
					scope:New("Frame")({
						Name = "Fill",
						BackgroundColor3 = Theme.Colors.Hp,
						Size = scope:Computed(function(use): UDim2
							return UDim2.fromScale(use(ratio), 1)
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
						},
					}),
				},
			}),
		},
	})
end

function MonsterPlateController.Init(registry)
	TargetController = registry.Get("TargetController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_MonsterPlates"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function MonsterPlateController.Start()
	local monsters = Workspace:WaitForChild("Monsters")
	for _, child in monsters:GetChildren() do
		task.spawn(build, child :: any)
	end
	monsters.ChildAdded:Connect(function(child)
		-- Attributes replicate with the instance; wait a frame for streaming to settle.
		task.defer(build, child :: any)
	end)
end

return MonsterPlateController
