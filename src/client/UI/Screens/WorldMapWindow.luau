--!strict
-- World map (M): left — every map as a node of a graph with its connections, levels and zone colour
-- ("You are here" on the current one); right — the selected map enlarged from its sketch with NPC,
-- portal and dungeon icons. Maps that are not built yet are shown dimmed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MapSketch = require(script.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local GRAPH_WIDTH = 440
local DETAIL = 470
local ZONE_COLORS = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}

local function graphMaps(): { Maps.MapDef }
	local list = {}
	for _, map in Maps.byId do
		if map.biome ~= "dungeon" then
			table.insert(list, map)
		end
	end
	table.sort(list, function(a, b)
		return a.minLevel < b.minLevel
	end)
	return list
end

local function line(parent: Instance, a: Vector2, b: Vector2)
	local delta = b - a
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(delta.Magnitude, 3)
	f.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	f.BackgroundColor3 = Theme.Colors.GoldDim
	f.BackgroundTransparency = 0.3
	f.BorderSizePixel = 0
	f.Parent = parent
end

local function WorldMapWindow(scope: Scope): Fusion.Child
	local mapId = State.Value({ "character", "location", "map" })
	local selected = scope:Value(Fusion.peek(mapId) or "city")
	local maps = graphMaps()

	-- Graph -----------------------------------------------------------------------------------------
	local graph = scope:New("Frame")({
		Name = "Graph",
		Size = UDim2.fromOffset(GRAPH_WIDTH, DETAIL),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.2,
		[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
	}) :: Frame
	local function nodePos(map: Maps.MapDef): Vector2
		return Vector2.new(30 + map.worldMap.x * (GRAPH_WIDTH - 60), 30 + map.worldMap.y * (DETAIL - 60))
	end
	local drawn: { [string]: boolean } = {}
	for _, map in maps do
		for _, link in map.links do
			local other = Maps.get(link)
			local key = if map.id < link then `{map.id}|{link}` else `{link}|{map.id}`
			if other and other.biome ~= "dungeon" and not drawn[key] then
				drawn[key] = true
				line(graph, nodePos(map), nodePos(other))
			end
		end
	end
	for _, map in maps do
		local built = MapSketch.isBuilt(map.id)
		local pos = nodePos(map)
		scope:New("TextButton")({
			Name = map.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(pos.X, pos.Y),
			Size = UDim2.fromOffset(120, 52),
			BackgroundColor3 = scope:Computed(function(use): Color3
				return if use(selected) == map.id then Theme.Colors.PanelRaised else Theme.Colors.Panel
			end),
			BackgroundTransparency = if built then 0 else 0.45,
			AutoButtonColor = true,
			Text = "",
			ZIndex = 2,
			Parent = graph,
			[OnEvent("Activated")] = function()
				selected:set(map.id)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Thickness = scope:Computed(function(use): number
						return if use(mapId) == map.id then 3 else 1.5
					end),
					Color = ZONE_COLORS[map.zone],
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -8, 0, 28),
					Position = UDim2.fromOffset(4, 2),
					BackgroundTransparency = 1,
					Text = Text.T(scope, map.nameKey),
					TextWrapped = true,
					TextScaled = true,
					FontFace = Theme.Fonts.BodyBold,
					TextColor3 = if built then Theme.Colors.Text else Theme.Colors.TextMuted,
					ZIndex = 3,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 18),
					Position = UDim2.fromOffset(0, 30),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						if use(mapId) == map.id then
							return Text.get(use, "worldmap.here")
						end
						if not built then
							return Text.get(use, "worldmap.soon")
						end
						return if map.id == "city" then "" else `{map.minLevel}–{map.maxLevel}`
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = 14,
					TextColor3 = scope:Computed(function(use): Color3
						return if use(mapId) == map.id then Theme.Colors.Accent else Theme.Colors.Parchment
					end),
					ZIndex = 3,
				}),
			},
		})
	end

	-- Detail ----------------------------------------------------------------------------------------
	local detail = scope:New("Frame")({
		Name = "Detail",
		Position = UDim2.fromOffset(GRAPH_WIDTH + 16, 0),
		Size = UDim2.fromOffset(DETAIL, DETAIL),
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
	}) :: Frame

	local function drawDetail()
		for _, child in detail:GetChildren() do
			if not child:IsA("UICorner") then
				child:Destroy()
			end
		end
		local id = Fusion.peek(selected)
		local map = Maps.get(id)
		local sketch = MapSketch.get(id)
		if not map then
			return
		end
		detail.BackgroundColor3 = MapSketch.background(map.biome)
		if not sketch then
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = Text.now("worldmap.soon")
			label.FontFace = Theme.Fonts.Heading
			label.TextSize = 28
			label.TextColor3 = Theme.Colors.Parchment
			label.Parent = detail
			return
		end
		local scale = (DETAIL - 20) / math.max(sketch.size.x, sketch.size.z)
		local canvas = Instance.new("Frame")
		canvas.AnchorPoint = Vector2.new(0.5, 0.5)
		canvas.Position = UDim2.fromScale(0.5, 0.5)
		canvas.Size = UDim2.fromOffset(sketch.size.x * scale, sketch.size.z * scale)
		canvas.BackgroundTransparency = 1
		canvas.Parent = detail
		MapSketch.draw(canvas, sketch, scale)
		local function icon(text: string, color: Color3, x: number, z: number, size: number)
			local p = MapSketch.toPixel(sketch, scale, x, z)
			local label = Instance.new("TextLabel")
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromOffset(p.X, p.Y)
			label.Size = UDim2.fromOffset(size, size)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextScaled = true
			label.FontFace = Theme.Fonts.BodyBold
			label.TextColor3 = color
			label.TextStrokeTransparency = 0.2
			label.ZIndex = 4
			label.Parent = canvas
		end
		for _, i in sketch.icons do
			if i.t == "portal" then
				icon("◎", Color3.fromHex("#B9A8FF"), i.x, i.z, 20)
			elseif i.t == "dungeon" then
				icon("☠", Theme.Colors.Danger, i.x, i.z, 20)
			end
		end
		for _, npc in Npcs.list do
			if npc.map == id and not npc.decoration then
				icon(npc.icon, Theme.Colors.Parchment, npc.position.x, npc.position.z, 18)
			end
		end
		if id == Fusion.peek(mapId) then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local relative = root.Position - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
				icon("▲", Theme.Colors.Accent, relative.X, relative.Z, 22)
			end
		end
	end
	drawDetail()
	scope:Observer(selected):onChange(drawDetail)

	return {
		graph :: any,
		detail :: any,
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(GRAPH_WIDTH + 16, DETAIL + 6),
			Size = UDim2.fromOffset(DETAIL, 30),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local map = Maps.get(use(selected))
				if not map then
					return ""
				end
				local zone = Text.get(use, `zone.{map.zone}`)
				local levels = if map.id == "city" then "" else ` · {map.minLevel}–{map.maxLevel}`
				return `{Text.get(use, map.nameKey)}{levels} · {zone}`
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	}
end

return WorldMapWindow
