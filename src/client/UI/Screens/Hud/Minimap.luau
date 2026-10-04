--!strict
-- Round minimap (DESIGN §23, top right), north up: the current map's sketch (paths, water, buildings),
-- the player arrow (camera heading), nearby monsters (bigger dots for elites), NPCs with their service
-- glyph, portals, dungeon gates and gathering nodes. Map name and zone colour below, zoom + / −.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 220
local ZOOMS = { 0.25, 0.4, 0.6, 0.9 }
local MONSTER_RANGE = 140
local ZONE_COLORS = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}
local ICONS: { [string]: { glyph: string, color: string } } = {
	portal = { glyph = "◎", color = "#B9A8FF" },
	dungeon = { glyph = "☠", color = "#D64A3E" },
	node = { glyph = "•", color = "#E8C25A" },
	spawn = { glyph = "", color = "#C9A45C" },
}

local function glyph(parent: Instance, text: string, color: string, position: Vector2, size: number, z: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.BodyBold
	label.TextColor3 = Color3.fromHex(color)
	label.TextStrokeTransparency = 0.3
	label.ZIndex = z or 3
	label.Parent = parent
	return label
end

local function Minimap(scope: Scope): Instance
	local zone = State.Value({ "zone" })
	local mapId = State.Value({ "character", "location", "map" })
	local zoomIndex = scope:Value(2)
	local scale = scope:Computed(function(use): number
		return ZOOMS[use(zoomIndex)]
	end)

	local canvas = scope:New("Frame")({
		Name = "Canvas",
		BackgroundTransparency = 1,
	}) :: Frame
	local dynamic = scope:New("Frame")({
		Name = "Dynamic",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = canvas,
	}) :: Frame

	local current: MapSketch.Sketch? = nil
	local currentScale = 0
	local currentMap = ""

	local function redraw()
		local id = Fusion.peek(mapId) or ""
		local s = Fusion.peek(scale)
		if id == currentMap and s == currentScale and current then
			return
		end
		for _, child in canvas:GetChildren() do
			if child ~= dynamic then
				child:Destroy()
			end
		end
		currentMap, currentScale = id, s
		current = MapSketch.get(id)
		local sketch = current
		if not sketch then
			return
		end
		canvas.Size = UDim2.fromOffset(sketch.size.x * s, sketch.size.z * s)
		MapSketch.draw(canvas, sketch, s)
		for _, icon in sketch.icons do
			local style = ICONS[icon.t]
			if style and style.glyph ~= "" then
				glyph(
					canvas,
					style.glyph,
					style.color,
					MapSketch.toPixel(sketch, s, icon.x, icon.z),
					if icon.t == "node" then 10 else 18,
					2
				)
			end
		end
		for _, npc in Npcs.list do
			if npc.map == id and not npc.decoration then
				glyph(canvas, npc.icon, "#F2E8C9", MapSketch.toPixel(sketch, s, npc.position.x, npc.position.z), 18, 2)
			end
		end
	end

	scope:Observer(mapId):onChange(redraw)
	scope:Observer(scale):onChange(redraw)

	local arrowRotation = scope:Value(0)
	local accumulator = 0
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt)
			if not current then
				redraw()
			end
			local sketch = current
			local map = Maps.get(currentMap)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not sketch or not map or not root then
				return
			end
			local relative = root.Position - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
			local pixel = MapSketch.toPixel(sketch, currentScale, relative.X, relative.Z)
			canvas.Position = UDim2.new(0.5, -pixel.X, 0.5, -pixel.Y)
			local camera = Workspace.CurrentCamera
			if camera then
				local look = camera.CFrame.LookVector
				arrowRotation:set(math.deg(math.atan2(look.X, -look.Z)))
			end
			accumulator += dt
			if accumulator < 0.4 then
				return
			end
			accumulator = 0
			dynamic:ClearAllChildren()
			local monsters = Workspace:FindFirstChild("Monsters")
			if monsters then
				for _, model in monsters:GetChildren() do
					if model:IsA("Model") and model:GetAttribute("Dead") ~= true then
						local pivot = model:GetPivot().Position
						if (pivot - root.Position).Magnitude <= MONSTER_RANGE then
							local local_ = pivot - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
							local variant = model:GetAttribute("Variant")
							local size = if variant == "elite2" then 12 elseif variant == "elite" then 9 else 6
							local dot = Instance.new("Frame")
							dot.AnchorPoint = Vector2.new(0.5, 0.5)
							local p = MapSketch.toPixel(sketch, currentScale, local_.X, local_.Z)
							dot.Position = UDim2.fromOffset(p.X, p.Y)
							dot.Size = UDim2.fromOffset(size, size)
							dot.BackgroundColor3 = if variant == "normal" or variant == nil
								then Theme.Colors.DangerHover
								else Theme.Colors.GoldBright
							dot.BorderSizePixel = 0
							dot.ZIndex = 4
							local corner = Instance.new("UICorner")
							corner.CornerRadius = UDim.new(0.5, 0)
							corner.Parent = dot
							dot.Parent = dynamic
						end
					end
				end
			end
		end)
	)

	local function zoomButton(text: string, delta: number, order: number): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.1,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 22,
			TextColor3 = Theme.Colors.Parchment,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			},
			[OnEvent("Activated")] = function()
				zoomIndex:set(math.clamp(Fusion.peek(zoomIndex) + delta, 1, #ZOOMS))
			end,
		})
	end

	return scope:New("Frame")({
		Name = "Minimap",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(SIZE + 44, SIZE + 46),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("CanvasGroup")({
				Name = "Disc",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(SIZE, SIZE),
				BackgroundColor3 = scope:Computed(function(use): Color3
					local map = Maps.get(use(mapId) or "")
					return MapSketch.background(if map then map.biome else "grass")
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					canvas,
					scope:New("TextLabel")({
						Name = "Player",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(22, 22),
						BackgroundTransparency = 1,
						Text = "▲",
						TextScaled = true,
						TextColor3 = Theme.Colors.Accent,
						TextStrokeTransparency = 0,
						Rotation = arrowRotation,
						ZIndex = 10,
					}),
					scope:New("TextLabel")({
						Name = "North",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 4),
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Text = "N",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = 14,
						TextColor3 = Theme.Colors.Gold,
						ZIndex = 10,
					}),
				},
			}),
			-- Ring with the zone colour
			scope:New("Frame")({
				Name = "Ring",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(SIZE, SIZE),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({
						Thickness = 3,
						Color = scope:Computed(function(use): Color3
							local z = use(zone)
							return if type(z) == "table"
								then ZONE_COLORS[z.pvp] or Theme.Colors.Gold
								else Theme.Colors.Gold
						end),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Zoom",
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, SIZE - 80),
				Size = UDim2.fromOffset(36, 80),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					zoomButton("+", 1, 1),
					zoomButton("−", -1, 2),
				},
			}),
			scope:New("TextLabel")({
				Name = "MapName",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(SIZE + 30, 36),
				BackgroundColor3 = Theme.Colors.Panel,
				BackgroundTransparency = 0.15,
				Text = scope:Computed(function(use): string
					local z = use(zone)
					if type(z) == "table" and z.nameKey then
						return Text.get(use, z.nameKey)
					end
					local map = Maps.get(use(mapId) or "")
					return if map then Text.get(use, map.nameKey) else ""
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Parchment,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Normal,
						Color = scope:Computed(function(use): Color3
							local z = use(zone)
							return if type(z) == "table"
								then ZONE_COLORS[z.pvp] or Theme.Colors.Border
								else Theme.Colors.Border
						end),
					}),
				},
			}),
		},
	})
end

return Minimap
