--!strict
-- Billboard above every monster (DESIGN §15): name in the variant colour, level, and an HP bar that shows
-- once the monster is hurt or selected. Built client-side from model attributes so names are localized.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupColors = require(script.Parent.Parent.UI.GroupColors)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local MonsterPlateController = {
	Name = "MonsterPlateController",
	Deps = { "TargetController", "MonsterViewController" },
}

-- Name colours per variant (DESIGN §15.1: elite red, Elite II purple).
local VARIANT_COLORS: { [string]: Color3 } = {
	normal = Color3.fromHex("#E8E4DA"),
	elite = Color3.fromHex("#E05A4A"),
	elite2 = Color3.fromHex("#C77BFF"),
	boss = Color3.fromHex("#FF9F1C"),
}

MonsterPlateController.VariantColors = VARIANT_COLORS

function MonsterPlateController.GroupColor(size: number): Color3
	return GroupColors.of(size)
end

local TargetController: any
local MonsterView: any
local rootScope: Scope = Fusion.scoped(Fusion)
local folder: Folder
local playerLevel = State.Value({ "character", "level" })

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
	-- S22: a monster going home keeps fighting when hit; its name fades a little and gets a "↩".
	local returning = attribute(scope, model, "Returning")

	local targeted = scope:Computed(function(use): boolean
		return use(TargetController.Target) == model
	end)
	local ratio = scope:Computed(function(use): number
		local m = use(maxHp)
		return if type(m) == "number" and m > 0 then math.clamp((use(hp) or 0) / m, 0, 1) else 1
	end)
	-- The white "trail" lags behind the red fill, so every hit reads as a chunk of HP going away.
	local trail =
		scope:Tween(ratio, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.15))
	local hpText = scope:Computed(function(use): string
		return `{math.max(0, math.ceil(use(hp) or 0))} / {use(maxHp) or 0}`
	end)

	-- Plate height from the top of the look (S24: MonsterView.top, from the rig the look is built from; the
	-- bounding box only until the view knows the model), so big monsters never cover their bar.
	local adornee = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local function plateOffset(): number
		local box, size = model:GetBoundingBox()
		local base = if adornee and adornee:IsA("BasePart") then adornee.Position.Y else box.Position.Y
		local top = MonsterView.top(model) or (box.Position.Y + size.Y / 2)
		return top - base + 1.4
	end
	local offset = scope:Value(plateOffset())
	table.insert(
		scope,
		MonsterView.Changed:Connect(function(changed: Model)
			if changed == model then
				offset:set(plateOffset())
			end
		end)
	)
	task.defer(function()
		if model.Parent then
			offset:set(plateOffset())
		end
	end)
	local groupSize = attribute(scope, model, "GroupSize")
	local band = scope:Computed(function(use): LevelBand.Band
		local mine = use(playerLevel)
		return LevelBand.of(use(level) or 1, if type(mine) == "number" then mine else 1)
	end)

	scope:New("BillboardGui")({
		Name = `Plate_{model:GetAttribute("EntityId")}`,
		Parent = folder,
		Adornee = adornee,
		-- Always on top (S18): plates used to hide behind the model and trees.
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 130,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(230, 52),
		StudsOffsetWorldSpace = scope:Computed(function(use): Vector3
			return Vector3.new(0, use(offset), 0)
		end),
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
					local key = model:GetAttribute("NameKey")
					local name = if type(key) == "string"
						then Text.get(use, key)
						elseif def then Text.get(use, def.nameKeys[v] or def.nameKeys.normal)
						else monsterId
					return if use(returning) == true then `↩ {name}` else name
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = 19,
				TextTransparency = scope:Computed(function(use): number
					return if use(returning) == true then 0.35 else 0
				end),
				TextColor3 = scope:Computed(function(use): Color3
					return VARIANT_COLORS[use(variant) or "normal"] or VARIANT_COLORS.normal
				end),
				TextStrokeTransparency = 0.2,
			}),
			scope:New("Frame")({
				Name = "Row",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 26),
				Size = UDim2.new(1, 0, 0, 18),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					-- Level badge in the level difference colour (grey / green / white / yellow / red).
					scope:New("TextLabel")({
						Name = "Level",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(30, 16),
						BackgroundColor3 = Theme.Colors.Background,
						BackgroundTransparency = 0.1,
						Text = scope:Computed(function(use): string
							return tostring(use(level) or 1)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 13,
						TextColor3 = scope:Computed(function(use): Color3
							return Color3.fromHex((LevelBand.COLORS :: any)[use(band)])
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = 1,
								Color = scope:Computed(function(use): Color3
									return Color3.fromHex((LevelBand.COLORS :: any)[use(band)])
								end),
							}),
						},
					}),
					-- Group size badge (monster groups, S19): "xN" in the group colour.
					scope:New("TextLabel")({
						Name = "Group",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(24, 16),
						Visible = scope:Computed(function(use): boolean
							local n = use(groupSize)
							return type(n) == "number" and n > 1
						end),
						BackgroundColor3 = Theme.Colors.Background,
						BackgroundTransparency = 0.1,
						Text = scope:Computed(function(use): string
							return `×{use(groupSize) or 1}`
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 12,
						TextColor3 = scope:Computed(function(use): Color3
							local n = use(groupSize)
							return MonsterPlateController.GroupColor(if type(n) == "number" then n else 1)
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
						},
					}),
					scope:New("Frame")({
						Name = "HpBar",
						LayoutOrder = 3,
						Size = scope:Computed(function(use): UDim2
							return if use(targeted) then UDim2.fromOffset(160, 16) else UDim2.fromOffset(140, 12)
						end),
						BackgroundColor3 = Theme.Colors.Background,
						BackgroundTransparency = 0.1,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
							scope:New("UIStroke")({
								Color = scope:Computed(function(use): Color3
									return if use(targeted) then Theme.Colors.GoldBright else Theme.Colors.Background
								end),
								Thickness = 1,
							}),
							scope:New("Frame")({
								Name = "Trail",
								BackgroundColor3 = Color3.fromHex("#F2E6C9"),
								Size = scope:Computed(function(use): UDim2
									return UDim2.fromScale(math.max(use(trail), use(ratio)), 1)
								end),
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
								},
							}),
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
							scope:New("TextLabel")({
								Name = "HpText",
								BackgroundTransparency = 1,
								Size = UDim2.fromScale(1, 1),
								ZIndex = 2,
								Visible = targeted,
								Text = hpText,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = 13,
								TextColor3 = Color3.new(1, 1, 1),
								TextStrokeTransparency = 0.3,
							}),
						},
					}),
				},
			}),
		},
	})
end

function MonsterPlateController.Init(registry)
	TargetController = registry.Get("TargetController")
	MonsterView = registry.Get("MonsterViewController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_MonsterPlates"
	folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function safeBuild(model: Instance)
	local ok, err = pcall(function()
		build(model :: any)
	end)
	if not ok then
		warn(`[MonsterPlateController] plate for {model:GetFullName()} failed: {err}`)
	end
end

function MonsterPlateController.Start()
	local monsters = Workspace:WaitForChild("Monsters")
	for _, child in monsters:GetChildren() do
		task.spawn(safeBuild, child)
	end
	monsters.ChildAdded:Connect(function(child)
		-- Attributes replicate with the instance; wait a frame for streaming to settle.
		task.defer(safeBuild, child)
	end)
end

return MonsterPlateController
