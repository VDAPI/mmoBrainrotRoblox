--!strict
-- World map v2 (M), S20, DESIGN §23: a list of maps on the left (region -> map -> caves) and a detailed map
-- on the right drawn from the server sketch (terrain patches, forests, water, roads, buildings) with layers:
-- monster areas (coloured by level difference, "Name · 9–14", hover / tap for the monster card), portals and
-- cave entrances with names, NPCs, gathering nodes, party members, the tracked quest and the player (moving
-- and turning). Zoom with the wheel / pinch / buttons, drag to pan, "Centre on me", layer toggles.
-- Performance: the static layer of every map is built once and cached (zoom is a UIScale, panning moves
-- one frame); per frame only the player, party and quest markers move. No Instance.new in RenderStepped.
-- S22 (readable levels): areas filled ~45% in the band colour relative to the player (Logic/AreaAdvice), a
-- darker 2 px outline, a 3 px gap between neighbours and a dark pill with the name and a big "9–14"; a legend
-- (your level, the five bands, "Show only recommended"); map rows coloured by band with their areas listed
-- under the selected map (click: zoom to the area and outline it); the map opens on the player with the
-- recommended area outlined; the area card hides when the mouse leaves the area.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local AreaSpawns = require(ReplicatedStorage.Shared.Logic.AreaSpawns)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local MapSketch = require(script.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestTrack = require(script.Parent.Parent.QuestTrack)
local Spawns = require(ReplicatedStorage.Shared.Data.Spawns)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local LIST_WIDTH = 230
local CANVAS = 760 -- base canvas size in pixels (zoom 1)
local ZOOMS = { 1, 1.6, 2.5, 4 }
local DETAIL_ZOOM = 2 -- nodes and NPC names from this zoom index

local ZONE_COLORS = {
	green = Theme.Colors.ZoneGreen,
	yellow = Theme.Colors.ZoneYellow,
	red = Theme.Colors.ZoneRed,
}

local REGIONS = {
	{ "city" },
	{ "meadows", "meadows_hideout", "meadows_burrow", "meadows_cave" },
	{ "duskwood", "duskwood_den", "duskwood_barrow", "duskwood_cave" },
	{ "ashen", "ashen_mine", "ashen_lair", "ashen_cave" },
	{ "frostpeak", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" },
}

local NODE_COLORS: { [string]: string } = { vein = "#E8C25A", bush = "#6FCF5A", fishing = "#5AA8E8" }

-- Static layers ---------------------------------------------------------------------------------------------

type AreaEntry = {
	frame: TextButton,
	area: Areas.Area,
	stroke: UIStroke,
	pill: Frame,
	name: TextLabel,
	levels: TextLabel,
}

type Cached = {
	canvas: Frame,
	scale: number,
	sketch: MapSketch.Sketch,
	areas: { AreaEntry },
	layers: { [string]: Frame },
	npcNames: { TextLabel },
}

local cache: { [string]: Cached } = {}

local function layer(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function label(
	parent: Instance,
	text: string,
	color: Color3,
	position: Vector2,
	size: number,
	z: number?
): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromOffset(position.X, position.Y)
	l.Size = UDim2.fromOffset(220, size + 4)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = Theme.Fonts.BodyBold
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.25
	l.ZIndex = z or 5
	l.Parent = parent
	return l
end

local function bossOf(region: string?): string?
	for _, boss in Bosses.list do
		if boss.region == region then
			return boss.nameKey
		end
	end
	return nil
end

local function build(mapId: string): Cached?
	local map = Maps.get(mapId)
	local sketch = MapSketch.get(mapId)
	if not map or not sketch then
		return nil
	end
	local started = os.clock()
	local scale = CANVAS / math.max(sketch.size.x, sketch.size.z)
	local canvas = Instance.new("Frame")
	canvas.Name = `Map_{mapId}`
	canvas.Size = UDim2.fromOffset(sketch.size.x * scale, sketch.size.z * scale)
	canvas.BackgroundColor3 = MapSketch.background(map.biome)
	canvas.BorderSizePixel = 0
	local terrain = layer(canvas, "Terrain", 1)
	MapSketch.draw(terrain, sketch, scale)
	local layers = {
		areas = layer(canvas, "Areas", 2),
		icons = layer(canvas, "Icons", 4),
		npcs = layer(canvas, "Npcs", 4),
		nodes = layer(canvas, "Nodes", 3),
	}
	local function px(x: number, z: number): Vector2
		return MapSketch.toPixel(sketch, scale, x, z)
	end

	-- Monster areas (S22: inset by 3 px so neighbours keep a light gap; a dark pill with the name and levels)
	local areaFrames: { AreaEntry } = {}
	local data = Areas.byMap[mapId]
	for _, area in (if data then data.areas else {}) :: { Areas.Area } do
		local r = area.rect
		local a, b = px(r[1], r[2]), px(r[3], r[4])
		local f = Instance.new("TextButton")
		f.Name = area.id
		f.AutoButtonColor = false
		f.Text = ""
		f.Position = UDim2.fromOffset(a.X + 3, a.Y + 3)
		f.Size = UDim2.fromOffset(b.X - a.X - 6, b.Y - a.Y - 6)
		f.BackgroundTransparency = 0.55
		f.BorderSizePixel = 0
		f.ZIndex = 2
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = f
		f.Parent = layers.areas
		local pill = Instance.new("Frame")
		pill.Name = "Pill"
		pill.AnchorPoint = Vector2.new(0.5, 0.5)
		pill.Position = UDim2.fromScale(0.5, 0.5)
		pill.AutomaticSize = Enum.AutomaticSize.XY
		pill.Size = UDim2.fromOffset(0, 0)
		pill.BackgroundColor3 = Theme.Colors.Background
		pill.BackgroundTransparency = 0.2
		pill.ZIndex = 3
		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(0, 6)
		pillCorner.Parent = pill
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 2)
		padding.PaddingBottom = UDim.new(0, 2)
		padding.Parent = pill
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = pill
		local function line(order: number, size: number, font: Font): TextLabel
			local l = Instance.new("TextLabel")
			l.LayoutOrder = order
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.fromOffset(0, size + 2)
			l.BackgroundTransparency = 1
			l.FontFace = font
			l.TextSize = size
			l.TextStrokeTransparency = 0.5
			l.ZIndex = 4
			l.Parent = pill
			return l
		end
		local name = line(1, 12, Theme.Fonts.BodyBold)
		local levels = line(2, 17, Theme.Fonts.Heading)
		pill.Parent = f
		table.insert(areaFrames, { frame = f, area = area, stroke = stroke, pill = pill, name = name, levels = levels })
	end

	-- Icons: portals with their target, caves, boss dungeons
	for _, icon in sketch.icons do
		local p = px(icon.x, icon.z)
		if icon.t == "portal" and icon.id then
			local target = Maps.get(icon.id)
			if target and target.biome ~= "cave" and target.biome ~= "crypt" then
				label(layers.icons, "◎", Color3.fromHex("#B9A8FF"), p, 18)
				local levels = if target.id == "city" then "" else ` {target.minLevel}–{target.maxLevel}`
				local caption = label(layers.icons, "", Color3.fromHex("#D8CCFF"), p + Vector2.new(0, 14), 11)
				caption:SetAttribute("Key", target.nameKey)
				caption:SetAttribute("Suffix", levels)
			end
		elseif icon.t == "cave" then
			label(layers.icons, "⛰", Theme.Colors.ZoneRed, p, 20)
		elseif icon.t == "dungeon" then
			label(layers.icons, "☠", Theme.Colors.Danger, p, 20)
			local key = bossOf(icon.id)
			if key then
				local caption = label(layers.icons, "", Theme.Colors.DangerHover, p + Vector2.new(0, 15), 11)
				caption:SetAttribute("Key", key)
			end
		elseif icon.t == "node" and icon.id then
			local kind = string.match(icon.id, "^(%a+)_") or "vein"
			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromOffset(p.X, p.Y)
			dot.Size = UDim2.fromOffset(5, 5)
			dot.BackgroundColor3 = Color3.fromHex(NODE_COLORS[kind] or "#E8C25A")
			dot.BorderSizePixel = 0
			dot.ZIndex = 3
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = dot
			dot.Parent = layers.nodes
		end
	end
	-- Cave entrances with their names (from the shared area data)
	for _, entrance in (if data then data.caves else {}) :: { Areas.CaveEntrance } do
		local cave = Areas.caves.get(entrance.cave)
		if cave then
			local caption =
				label(layers.icons, "", Color3.fromHex("#F2B8A8"), px(entrance.x, entrance.z) + Vector2.new(0, 16), 11)
			caption:SetAttribute("Key", cave.nameKey)
			caption:SetAttribute("Suffix", ` {cave.levels[1]}–{cave.levels[2]}`)
		end
	end
	-- NPCs (city)
	local npcNames = {}
	for _, npc in Npcs.list do
		if npc.map == mapId and not npc.decoration then
			local p = px(npc.position.x, npc.position.z)
			label(layers.npcs, npc.icon, Theme.Colors.Parchment, p, 15)
			local caption = label(layers.npcs, "", Theme.Colors.Parchment, p + Vector2.new(0, 13), 10)
			caption:SetAttribute("Key", npc.nameKey)
			table.insert(npcNames, caption)
		end
	end
	local count = #canvas:GetDescendants()
	print(`[WorldMap] {mapId}: static layer built in {math.floor((os.clock() - started) * 1000)} ms, {count} objects`)
	local cached: Cached = {
		canvas = canvas,
		scale = scale,
		sketch = sketch,
		areas = areaFrames,
		layers = layers,
		npcNames = npcNames,
	}
	cache[mapId] = cached
	return cached
end

type View = { onlyRecommended: boolean, highlight: string? }

-- Localized captions and area colours (cheap: a few dozen objects), refreshed on language / level / view
-- change (S22: band of the nearest end of the range, "★" on recommended areas, dimmed others when only the
-- recommended ones are wanted, a gold outline on the highlighted area).
local function refresh(cached: Cached, level: number, view: View)
	for _, entry in cached.areas do
		local area = entry.area
		local color = Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, level)])
		local recommended = AreaAdvice.isRecommended(area, level)
		local dim = view.onlyRecommended and not recommended
		local highlighted = view.highlight == area.id
		entry.frame.BackgroundColor3 = color
		entry.frame.BackgroundTransparency = if dim then 0.9 else 0.55
		entry.stroke.Color = if highlighted then Theme.Colors.GoldBright else color:Lerp(Color3.new(0, 0, 0), 0.45)
		entry.stroke.Thickness = if highlighted then 4 else 2
		entry.stroke.Transparency = if dim then 0.7 else 0
		entry.pill.BackgroundTransparency = if dim then 0.75 else 0.2
		entry.name.Text = (if recommended then "★ " else "") .. Text.now(area.nameKey)
		entry.name.TextColor3 = color
		entry.name.TextTransparency = if dim then 0.6 else 0
		entry.levels.Text = `{area.lv[1]}–{area.lv[2]}`
		entry.levels.TextColor3 = color
		entry.levels.TextTransparency = if dim then 0.6 else 0
	end
	for _, object in cached.canvas:GetDescendants() do
		local key = object:GetAttribute("Key")
		if type(key) == "string" and object:IsA("TextLabel") then
			local suffix = object:GetAttribute("Suffix")
			object.Text = Text.now(key) .. (if type(suffix) == "string" then suffix else "")
		end
	end
end

-- Monster card --------------------------------------------------------------------------------------------

type CardLine = { text: string, color: Color3? }

local function kindLine(id: string, lv: { number }?, suffix: string?): CardLine
	local def = Monsters.get(id)
	local name = if def then Text.now(def.nameKeys.normal) else id
	local levels = if def and lv
		then ` {math.max(lv[1], def.levels.min)}–{math.min(lv[2], def.levels.max)}`
		elseif def then ` {def.levels.min}–{def.levels.max}`
		else ""
	return { text = `• {name}{levels}{suffix or ""}` }
end

local function areaCard(area: Areas.Area, mapId: string): { CardLine }
	local lines: { CardLine } = {
		{
			text = Text.now("area.label", { name = Text.now(area.nameKey), min = area.lv[1], max = area.lv[2] }),
			color = Theme.Colors.GoldBright,
		},
	}
	for _, kind in area.kinds do
		table.insert(lines, kindLine(kind, area.lv))
	end
	local groups = 0
	for _, spawner in (Spawns.byMap[mapId] or {}) :: { Spawns.Spawner } do
		if spawner.areaId == area.id then
			groups += 1
		end
	end
	table.insert(lines, { text = Text.now("worldmap.groups", { n = groups }), color = Theme.Colors.TextMuted })
	return lines
end

local function caveCard(cave: Areas.Cave): { CardLine }
	local lines: { CardLine } = {
		{
			text = Text.now("area.label", {
				name = Text.now(cave.nameKey),
				min = cave.levels[1],
				max = cave.levels[2],
			}),
			color = Theme.Colors.GoldBright,
		},
	}
	for _, kind in cave.normal do
		table.insert(lines, kindLine(kind, cave.levels))
	end
	table.insert(lines, { text = Text.now("worldmap.elites"), color = Theme.Colors.DangerHover })
	for _, kind in cave.elites do
		local def = Monsters.get(kind)
		table.insert(lines, { text = `• {if def then Text.now(def.nameKeys.elite) else kind}` })
	end
	table.insert(lines, { text = Text.now("worldmap.elite2"), color = Color3.fromHex("#C77BFF") })
	local now = workspace:GetServerTimeNow()
	for _, kind in cave.elite2 do
		local def = Monsters.get(kind)
		table.insert(lines, { text = `• {if def then Text.now(def.nameKeys.elite2) else kind}` })
	end
	for _, timer in State.Get({ "character", "e2timers" }) or {} do
		if timer.map == cave.id and timer.job == game.JobId then
			local state = if now < timer.from
				then Text.now("e2timer.window", {
					from = math.ceil((timer.from - now) / 60) .. " min",
					to = math.ceil((timer.to - now) / 60) .. " min",
				})
				else Text.now("e2timer.any")
			table.insert(lines, { text = `⏱ {state}`, color = Theme.Colors.TextMuted })
		end
	end
	local rooms = #AreaSpawns.caveRooms(cave)
	table.insert(lines, { text = Text.now("worldmap.rooms", { n = rooms }), color = Theme.Colors.TextMuted })
	return lines
end

-- Window ----------------------------------------------------------------------------------------------------

local function WorldMapWindow(scope: Scope): Fusion.Child
	local mapId = State.Value({ "character", "location", "map" })
	local level = State.Value({ "character", "level" })
	local selected = scope:Value(Fusion.peek(mapId) or "city")
	local zoomIndex = scope:Value(1)
	local center = scope:Value(Vector2.new(CANVAS / 2, CANVAS / 2)) -- canvas pixel in the middle of the view
	local card = scope:Value(nil :: { CardLine }?)
	local onlyRecommended = scope:Value(false)
	local highlight = scope:Value(nil :: string?)
	local toggles = {
		areas = scope:Value(true),
		nodes = scope:Value(true),
		npcs = scope:Value(true),
		icons = scope:Value(true),
		quest = scope:Value(true),
	}

	-- Map list (S22: map names and levels in the band colour relative to the player, the PvP zone as a small
	-- dot; under the selected region map its areas, click = zoom to the area).
	local focusArea: (area: Areas.Area) -> () = function() end
	local listChildren = {}
	local order = 0
	for _, region in REGIONS do
		for i, id in region do
			local map = Maps.get(id)
			if map then
				order += 1
				local zoneHex = (ZONE_COLORS[map.zone] or Theme.Colors.Text):ToHex()
				table.insert(
					listChildren,
					scope:New("TextButton")({
						LayoutOrder = order,
						Size = UDim2.new(1, -8, 0, if i == 1 then 34 else 28),
						AutoButtonColor = false,
						BackgroundColor3 = scope:Computed(function(use): Color3
							return if use(selected) == id then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
						end),
						BackgroundTransparency = if i == 1 then 0.1 else 0.4,
						RichText = true,
						Text = scope:Computed(function(use): string
							local here = if use(mapId) == id then " ▲" else ""
							local levels = if id == "city" then "" else ` · {map.minLevel}–{map.maxLevel}`
							local indent = if i == 1 then "" else "   "
							return `{indent}<font color="#{zoneHex}">●</font> {Text.get(use, map.nameKey)}{levels}{here}`
						end),
						FontFace = if i == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
						TextSize = if i == 1 then 16 else 14,
						TextColor3 = scope:Computed(function(use): Color3
							if id == "city" then
								return Theme.Colors.Parchment
							end
							local range = { lv = { map.minLevel, map.maxLevel } } :: any
							return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(range, use(level) or 1)])
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						[OnEvent("Activated")] = function()
							selected:set(id)
						end,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
						},
					})
				)
				for _, area in AreaAdvice.sorted(id) do
					order += 1
					table.insert(
						listChildren,
						scope:New("TextButton")({
							LayoutOrder = order,
							Visible = scope:Computed(function(use): boolean
								return use(selected) == id
							end),
							Size = UDim2.new(1, -8, 0, 24),
							AutoButtonColor = false,
							BackgroundColor3 = scope:Computed(function(use): Color3
								return if use(highlight) == area.id then Theme.Colors.PanelHover else Theme.Colors.Panel
							end),
							BackgroundTransparency = 0.2,
							Text = scope:Computed(function(use): string
								local star = if AreaAdvice.isRecommended(area, use(level) or 1) then "★ " else ""
								return `      {star}{Text.get(use, area.nameKey)} · {area.lv[1]}–{area.lv[2]}`
							end),
							FontFace = Theme.Fonts.Body,
							TextSize = 13,
							TextColor3 = scope:Computed(function(use): Color3
								return Color3.fromHex(LevelBand.COLORS[AreaAdvice.bandOf(area, use(level) or 1)])
							end),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							[OnEvent("Activated")] = function()
								focusArea(area)
							end,
							[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						})
					)
				end
			end
		end
	end

	-- Map view
	local view = scope:New("Frame")({
		Name = "View",
		Position = UDim2.fromOffset(LIST_WIDTH + 12, 0),
		Size = UDim2.new(1, -(LIST_WIDTH + 12), 1, -48),
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
	}) :: Frame
	local holder = scope:New("Frame")({
		Name = "Holder",
		Parent = view,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}) :: Frame
	local uiScale = Instance.new("UIScale")
	local dynamic = Instance.new("Frame")
	dynamic.Name = "Dynamic"
	dynamic.Size = UDim2.fromScale(1, 1)
	dynamic.BackgroundTransparency = 1
	dynamic.ZIndex = 8
	local marker = label(dynamic, "▲", Theme.Colors.Accent, Vector2.zero, 20, 9)
	local questMarker = label(dynamic, "★", Theme.Colors.GoldBright, Vector2.zero, 18, 9)
	local partyMarkers: { TextLabel } = {}
	for i = 1, 4 do
		partyMarkers[i] = label(dynamic, "●", Color3.fromHex("#4A8FE7"), Vector2.zero, 14, 9)
	end
	table.insert(scope, dynamic)
	table.insert(scope, uiScale)

	local current: Cached? = nil
	local emptyLabel = scope:New("TextLabel")({
		Parent = view,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Text = Text.T(scope, "worldmap.soon"),
		FontFace = Theme.Fonts.Heading,
		TextSize = 28,
		TextColor3 = Theme.Colors.Parchment,
	}) :: TextLabel

	-- Cached canvases outlive the window: detach them before the window is destroyed.
	table.insert(scope, function()
		if current then
			current.canvas.Parent = nil
			uiScale.Parent = nil
			dynamic.Parent = nil
		end
	end)

	local function applyToggles()
		if not current then
			return
		end
		local zoom = Fusion.peek(zoomIndex)
		current.layers.areas.Visible = Fusion.peek(toggles.areas)
		current.layers.icons.Visible = Fusion.peek(toggles.icons)
		current.layers.npcs.Visible = Fusion.peek(toggles.npcs)
		current.layers.nodes.Visible = Fusion.peek(toggles.nodes) and zoom >= DETAIL_ZOOM
		for _, name in current.npcNames do
			name.Visible = zoom >= DETAIL_ZOOM
		end
	end

	local function place()
		if not current then
			return
		end
		local zoom = ZOOMS[Fusion.peek(zoomIndex)]
		uiScale.Scale = zoom
		local size = view.AbsoluteSize
		local c = Fusion.peek(center)
		current.canvas.Position = UDim2.fromOffset(size.X / 2 - c.X * zoom, size.Y / 2 - c.Y * zoom)
	end

	local myPixel: () -> Vector2?

	local function show(id: string)
		if current then
			current.canvas.Parent = nil
		end
		current = cache[id] or build(id)
		emptyLabel.Visible = current == nil
		local cave = Areas.caves.get(id)
		card:set(if cave then caveCard(cave) else nil)
		if not current then
			return
		end
		-- S22: open on the player (their own map) with the recommended area outlined.
		local playerLevel = Fusion.peek(level) or 1
		local best = if Areas.byMap[id] then AreaAdvice.best(playerLevel, id) else nil
		highlight:set(if best then best.id else nil)
		refresh(
			current,
			playerLevel,
			{ onlyRecommended = Fusion.peek(onlyRecommended), highlight = Fusion.peek(highlight) }
		)
		uiScale.Parent = current.canvas
		dynamic.Parent = current.canvas
		current.canvas.Parent = holder
		center:set(Vector2.new(current.canvas.Size.X.Offset / 2, current.canvas.Size.Y.Offset / 2))
		if id == Fusion.peek(mapId) then
			local me = myPixel()
			if me then
				center:set(me)
			end
		end
		applyToggles()
		place()
	end

	-- Area cards: one set of connections per window (areas of the shown map).
	local connections: { RBXScriptConnection } = {}
	local function wireAreas()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		if not current then
			return
		end
		local id = Fusion.peek(selected)
		for _, entry in current.areas do
			local frame = entry.frame :: any
			table.insert(
				connections,
				frame.MouseEnter:Connect(function()
					card:set(areaCard(entry.area, id))
				end)
			)
			table.insert(
				connections,
				frame.Activated:Connect(function()
					card:set(areaCard(entry.area, id))
				end)
			)
			table.insert(
				connections,
				frame.MouseLeave:Connect(function()
					card:set(nil)
				end)
			)
		end
	end
	table.insert(scope, function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	scope:Observer(selected):onBind(function()
		show(Fusion.peek(selected))
		wireAreas()
	end)
	scope:Observer(zoomIndex):onChange(function()
		applyToggles()
		place()
	end)
	scope:Observer(center):onChange(place)
	for _, toggle in toggles do
		scope:Observer(toggle):onChange(applyToggles)
	end
	local function refreshView()
		if current then
			refresh(
				current,
				Fusion.peek(level) or 1,
				{ onlyRecommended = Fusion.peek(onlyRecommended), highlight = Fusion.peek(highlight) }
			)
		end
	end
	scope:Observer(level):onChange(refreshView)
	scope:Observer(Text.Lang):onChange(refreshView)
	scope:Observer(onlyRecommended):onChange(refreshView)
	scope:Observer(highlight):onChange(refreshView)
	-- Area rows in the list: zoom in on the area and outline it.
	focusArea = function(area: Areas.Area)
		if not current then
			return
		end
		local cx, cz = AreaAdvice.centre(area)
		highlight:set(area.id)
		zoomIndex:set(math.max(Fusion.peek(zoomIndex), 2))
		center:set(MapSketch.toPixel(current.sketch, current.scale, cx, cz))
		card:set(areaCard(area, Fusion.peek(selected)))
	end
	table.insert(scope, view:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))

	function myPixel(): Vector2?
		local map = Maps.get(Fusion.peek(selected))
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not current or not map or not root or Fusion.peek(mapId) ~= map.id then
			return nil
		end
		local relative = root.Position - Vector3.new(map.offset.x, map.offset.y, map.offset.z)
		return MapSketch.toPixel(current.sketch, current.scale, relative.X, relative.Z)
	end

	local function zoomBy(delta: number)
		zoomIndex:set(math.clamp(Fusion.peek(zoomIndex) + delta, 1, #ZOOMS))
	end

	-- Dragging, wheel and pinch
	local dragging = false
	local lastPosition = Vector2.zero
	table.insert(
		scope,
		view.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				lastPosition = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
	)
	table.insert(
		scope,
		view.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				zoomBy(if input.Position.Z > 0 then 1 else -1)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local position = Vector2.new(input.Position.X, input.Position.Y)
				local delta = position - lastPosition
				lastPosition = position
				local zoom = ZOOMS[Fusion.peek(zoomIndex)]
				center:set(Fusion.peek(center) - delta / zoom)
			end
		end)
	)
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = false
			end
		end)
	)
	local pinchStart = 1
	table.insert(
		scope,
		UserInputService.TouchPinch:Connect(function(_, scaleFactor, _, state)
			if state == Enum.UserInputState.Begin then
				pinchStart = Fusion.peek(zoomIndex)
			elseif state == Enum.UserInputState.Change then
				local target = if scaleFactor > 1.3
					then pinchStart + 1
					elseif scaleFactor < 0.75 then pinchStart - 1
					else pinchStart
				zoomIndex:set(math.clamp(target, 1, #ZOOMS))
			end
		end)
	)

	-- Moving markers (positions only)
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function()
			if not current then
				return
			end
			local me = myPixel()
			marker.Visible = me ~= nil
			if me then
				marker.Position = UDim2.fromOffset(me.X, me.Y)
				local character = Players.LocalPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local look = root.CFrame.LookVector
					marker.Rotation = math.deg(math.atan2(look.X, -look.Z))
				end
			end
			local target = Fusion.peek(QuestTrack.Target)
			local showQuest = Fusion.peek(toggles.quest)
				and target ~= nil
				and target.map == Fusion.peek(selected)
				and target.x ~= nil
				and target.z ~= nil
				and Fusion.peek(QuestTrack.Tracked)
			questMarker.Visible = showQuest == true
			if showQuest and target and target.x and target.z then
				local p = MapSketch.toPixel(current.sketch, current.scale, target.x, target.z)
				questMarker.Position = UDim2.fromOffset(p.X, p.Y)
			end
			local party = State.Get({ "party" })
			local shown = 0
			local map = Maps.get(Fusion.peek(selected))
			if type(party) == "table" and map then
				for _, member in party.members do
					if member.id ~= Players.LocalPlayer.UserId and member.map == map.id and shown < #partyMarkers then
						shown += 1
						local p = MapSketch.toPixel(
							current.sketch,
							current.scale,
							member.x - map.offset.x,
							member.z - map.offset.z
						)
						partyMarkers[shown].Position = UDim2.fromOffset(p.X, p.Y)
					end
				end
			end
			for i, dot in partyMarkers do
				dot.Visible = i <= shown
			end
		end)
	)

	local function toggleButton(order: number, key: string, value: Fusion.Value<boolean>): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(110, 34),
			AutoButtonColor = false,
			BackgroundColor3 = scope:Computed(function(use): Color3
				return if use(value) then Theme.Colors.PanelHover else Theme.Colors.Panel
			end),
			Text = scope:Computed(function(use): string
				return `{if use(value) then "☑" else "☐"} {Text.get(use, key)}`
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = 14,
			TextColor3 = Theme.Colors.Parchment,
			[OnEvent("Activated")] = function()
				value:set(not Fusion.peek(value))
			end,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	local function smallButton(order: number, text: Fusion.UsedAs<string>, onClick: () -> ()): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(if type(text) == "string" and #text <= 3 then 34 else 140, 34),
			BackgroundColor3 = Theme.Colors.PanelRaised,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = 15,
			TextColor3 = Theme.Colors.Parchment,
			[OnEvent("Activated")] = onClick,
			[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
		})
	end

	return {
		scope:New("ScrollingFrame")({
			Name = "MapList",
			Size = UDim2.new(0, LIST_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
				listChildren :: any,
			},
		}),
		view,
		-- Band legend (S22, top left of the view)
		scope:New("Frame")({
			Name = "Bands",
			Position = UDim2.fromOffset(LIST_WIDTH + 22, 10),
			Size = UDim2.fromOffset(196, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.12,
			ZIndex = 20,
			Visible = scope:Computed(function(use): boolean
				return Areas.byMap[use(selected)] ~= nil
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
				scope:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "worldmap.yourLevel", { level = use(level) or 1 })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = 14,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 21,
				}),
				(function(): { Instance }
					local rows = {}
					for i, band in { "grey", "green", "white", "yellow", "red" } do
						table.insert(
							rows,
							scope:New("Frame")({
								LayoutOrder = i,
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								ZIndex = 21,
								[Children] = {
									scope:New("Frame")({
										AnchorPoint = Vector2.new(0, 0.5),
										Position = UDim2.fromScale(0, 0.5),
										Size = UDim2.fromOffset(12, 12),
										BackgroundColor3 = Color3.fromHex((LevelBand.COLORS :: any)[band]),
										ZIndex = 22,
										[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
									}),
									scope:New("TextLabel")({
										Position = UDim2.fromOffset(18, 0),
										Size = UDim2.new(1, -18, 1, 0),
										BackgroundTransparency = 1,
										Text = Text.T(scope, `worldmap.band.{band}`),
										FontFace = Theme.Fonts.Body,
										TextSize = 12,
										TextColor3 = Theme.Colors.Text,
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTruncate = Enum.TextTruncate.AtEnd,
										ZIndex = 22,
									}),
								},
							})
						)
					end
					return rows
				end)() :: any,
				scope:New("TextButton")({
					LayoutOrder = 9,
					Size = UDim2.new(1, 0, 0, 28),
					AutoButtonColor = false,
					BackgroundColor3 = scope:Computed(function(use): Color3
						return if use(onlyRecommended) then Theme.Colors.PanelHover else Theme.Colors.PanelRaised
					end),
					Text = scope:Computed(function(use): string
						return `{if use(onlyRecommended) then "☑" else "☐"} {Text.get(
							use,
							"worldmap.onlyRecommended"
						)}`
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = 13,
					TextColor3 = Theme.Colors.Parchment,
					ZIndex = 21,
					[OnEvent("Activated")] = function()
						onlyRecommended:set(not Fusion.peek(onlyRecommended))
					end,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				}),
			},
		}),
		-- Monster card (top right of the view)
		scope:New("Frame")({
			Name = "Card",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(250, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.Colors.Panel,
			BackgroundTransparency = 0.08,
			ZIndex = 20,
			Visible = scope:Computed(function(use): boolean
				return use(card) ~= nil
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIStroke")({ Color = Theme.Colors.GoldDim }),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
				scope:Computed(function(use, s: Scope): { Instance }
					local lines: { CardLine } = use(card) or {}
					use(Text.Lang)
					local out = {}
					for i, entry in lines do
						table.insert(
							out,
							s:New("TextLabel")({
								LayoutOrder = i,
								Size = UDim2.new(1, 0, 0, 18),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Text = entry.text,
								TextWrapped = true,
								FontFace = if i == 1 then Theme.Fonts.BodyBold else Theme.Fonts.Body,
								TextSize = if i == 1 then 15 else 13,
								TextColor3 = entry.color or Theme.Colors.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 21,
							})
						)
					end
					return out
				end) :: any,
			},
		}),
		-- Legend: layer toggles, zoom, centre on me
		scope:New("Frame")({
			Name = "Legend",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, LIST_WIDTH + 12, 1, 0),
			Size = UDim2.new(1, -(LIST_WIDTH + 12), 0, 40),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 6),
				}),
				toggleButton(1, "worldmap.layer.areas", toggles.areas),
				toggleButton(2, "worldmap.layer.icons", toggles.icons),
				toggleButton(3, "worldmap.layer.npcs", toggles.npcs),
				toggleButton(4, "worldmap.layer.nodes", toggles.nodes),
				toggleButton(5, "worldmap.layer.quest", toggles.quest),
				smallButton(6, "+", function()
					zoomBy(1)
				end),
				smallButton(7, "−", function()
					zoomBy(-1)
				end),
				smallButton(8, Text.T(scope, "worldmap.center"), function()
					if Fusion.peek(selected) ~= Fusion.peek(mapId) then
						selected:set(Fusion.peek(mapId) or "city")
					end
					local me = myPixel()
					if me then
						center:set(me)
					end
				end),
			},
		}),
	}
end

-- Drops the cached static layers (admin /mapcache clear, a rebuilt map).
local function clearCache()
	for id, cached in cache do
		cached.canvas:Destroy()
		cache[id] = nil
	end
	MapSketch.clearCache()
end

return setmetatable({ clearCache = clearCache }, {
	__call = function(_, scope: Scope): Fusion.Child
		return WorldMapWindow(scope)
	end,
}) :: any
