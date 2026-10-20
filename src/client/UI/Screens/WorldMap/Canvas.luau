--!strict
-- Static layer of one map in the world map window (S20, reworked in S25), built once per map and cached:
-- the sketch (terrain, roads, water, buildings), monster areas (buttons with a name and level plate) and the
-- symbols: NPCs (with the quest mark), portals, cave mouths, dungeon gates (Data/Portals), Elite II hideouts, the world
-- boss's barrow and gathering nodes (from the sketch).
-- Owner 2026-10-20 "Mapa" (labels overlapped): no text stays on the map. Every symbol is a dark plate with a ring and
-- glyph in its category's colour and shape (Logic/MapMarkers: round = people, diamond = ways, square = danger) that
-- keeps one screen size at every zoom (a UIScale of 1 / zoom); the name shows on hover (PC) and the card on a click /
-- tap (WorldMap/init). `applyLayout` places the symbols for the zoom and the filter: overlapping ones are nudged apart,
-- crowds fold into a cluster badge with a count (a click zooms in), and at the closest zoom everything is spread.
-- Area plates (name and levels) take a free spot inside their area, shrink to the levels, or hide.
-- The window wires one set of connections for the shown map (WorldMap/init); cluster badges are pooled here and call
-- the window's `cached.onCluster`.
-- S119: symbols get the owner's silhouettes (UiArtState.decorate, glyph colour) once the map atlas is loaded; a map with
-- a painted picture (Logic/UiArt.map, frame from the wiki SVG viewBox) shows it instead of the sketch's terrain once
-- loaded (the sketch is not drawn when the picture is already there; otherwise it hides when the picture arrives).
-- S134i: Elite II hideouts, S149b: the world boss's barrow (WorldMap/Overlay adds the boss's live state).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaProfileText = require(script.Parent.Parent.Parent.AreaProfileText)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local IconState = require(script.Parent.Parent.Parent.IconState)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local MapMarkers = require(ReplicatedStorage.Shared.Logic.MapMarkers)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local NpcMarkState = require(script.Parent.Parent.Parent.NpcMarkState)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)

local Canvas = {}

Canvas.SIZE = 760 -- base canvas size in pixels (zoom 1)
Canvas.ZOOMS = { 1, 1.6, 2.5, 4 }
Canvas.DETAIL_ZOOM = 2 -- gathering nodes from this zoom index
Canvas.HIT = 40 -- symbol hit area (and spacing) in screen pixels at every zoom (UI scale 1), PC
Canvas.HIT_TOUCH = 46 -- the same on touch (>= 44 px tap targets)
Canvas.PLATE = 34 -- the dark plate of a symbol
local NODE_PLATE = 24
local CLUSTER_PLATE = 40
local ART = 22 -- silhouette size on a plate
local NODE_ART = 16

export type IconKind = "npc" | "portal" | "cave" | "dungeon" | "node" | "lair" | "worldboss"

export type Icon = {
	kind: IconKind,
	id: string, -- NPC id, portal id, cave map id, dungeon region, node kind, hideout id (S134i)
	x: number,
	z: number,
	pixel: Vector2, -- canvas pixel at zoom 1 (the true place)
	shown: Vector2, -- canvas pixel where the symbol is drawn now (nudged by the layout)
	button: TextButton,
	glyph: TextLabel,
	plate: Frame,
	stroke: UIStroke,
	scale: UIScale,
	mark: TextLabel?,
	color: Color3,
	category: string, -- Logic/MapMarkers category (NPCs: by services, "quest" while marked)
	base: number, -- importance without quest marks
	priority: number,
	target: string?, -- portals: map they lead to
	hidden: boolean?, -- S104: an NPC the character does not see yet (NpcMarkState.Hidden)
	services: { string }?, -- NPCs
	art: string?,
}

export type AreaEntry = {
	frame: TextButton,
	area: Areas.Area,
	stroke: UIStroke,
	pill: Frame,
	pillScale: UIScale,
	name: TextLabel,
	levels: TextLabel,
	star: ImageLabel, -- S119: "recommended" badge in the area's corner (the ★ leaves the name while it shows)
	nameWidth: number, -- estimated screen width of the name line (set by refresh)
}

export type Cluster = { x: number, y: number, members: { Icon } }

export type Cached = {
	mapId: string,
	canvas: Frame,
	scale: number,
	sketch: MapSketch.Sketch,
	areas: { AreaEntry },
	layers: { [string]: Frame },
	icons: { Icon },
	npcIcons: { [string]: Icon },
	painted: ImageLabel?, -- S119
	sketchLayer: Frame?, -- S119: the drawn terrain (nil when the painted map replaced it at build time)
	clusters: { Cluster }, -- shown cluster badges (index = pooled button)
	clusterButtons: { TextButton },
	-- set by the open window: "tap" | "enter" | "leave" on the cluster badge `index`
	onCluster: ((event: string, index: number, input: InputObject?) -> ())?,
}

local PRIORITY: { [IconKind]: number } =
	{ portal = 40, cave = 40, worldboss = 35, dungeon = 30, lair = 30, npc = 20, node = 10 }
local MAP = UiPalette.map
local PLATE_COLOR = Theme.tint(MAP.plate)
local CLUSTER_COLOR = Theme.tint(MAP.cluster)
local NODE_COLORS: { [string]: string } = { vein = MAP.vein, bush = MAP.bush, fishing = MAP.fishing }

local cache: { [string]: Cached } = {}
local artScope = Fusion.scoped(Fusion)
local paint: (cached: Cached) -> ()

local function layer(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

-- Colour of a category (Data/UiPalette.map through Logic/MapMarkers).
function Canvas.categoryColor(id: string): Color3
	local category = MapMarkers.byId[id]
	local hex = if category then (MAP :: any)[category.color] else nil
	return Theme.tint(if type(hex) == "string" then hex else MAP.npc)
end

-- The dark plate of a symbol in its shape, with a ring of `color`. Shared with WorldMap/Overlay and the filter chips.
function Canvas.plate(
	parent: Instance,
	shape: MapMarkers.Shape,
	side: number,
	color: Color3,
	z: number
): (Frame, UIStroke)
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	local s = if shape == "diamond" then math.floor(side * 0.78) else side
	plate.Size = UDim2.fromOffset(s, s)
	plate.Rotation = if shape == "diamond" then 45 else 0
	plate.BackgroundColor3 = PLATE_COLOR
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.ZIndex = z
	plate.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if shape == "round" then UDim.new(0.5, 0) else UDim.new(0, 6)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = plate
	plate.Parent = parent
	return plate, stroke
end

local function glyphLabel(parent: Instance, value: string, color: Color3, size: number, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "Glyph"
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.Size = UDim2.fromOffset(size + 8, size + 6)
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.FontFace = Theme.Fonts.BodyBold
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.ZIndex = z
	l.Active = false
	l.Parent = parent
	return l
end

-- One symbol: a transparent button (the hit area, constant on screen) holding the plate, the glyph and a quest mark.
local function icon(
	cached: Cached,
	parent: Frame,
	kind: IconKind,
	id: string,
	x: number,
	z: number,
	glyph: string,
	category: string,
	art: string?, -- S119: interface picture key (silhouette tinted with the category colour)
	color: Color3?
): Icon
	local pixel = MapSketch.toPixel(cached.sketch, cached.scale, x, z)
	local tint = color or Canvas.categoryColor(category)
	local small = kind == "node"
	local button = Instance.new("TextButton")
	button.Name = `{kind}:{id}`
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromOffset(pixel.X, pixel.Y)
	button.Size = UDim2.fromOffset(Canvas.HIT, Canvas.HIT)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = parent.ZIndex + 1
	button.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local def = MapMarkers.byId[category]
	local plate, stroke = Canvas.plate(
		button,
		if def then def.shape else "round",
		if small then NODE_PLATE else Canvas.PLATE,
		tint,
		parent.ZIndex + 1
	)
	if small then
		stroke.Thickness = 1.5
	end
	local label = glyphLabel(
		button,
		glyph,
		tint,
		if small then Theme.TextSize.Caption else Theme.TextSize.Body,
		parent.ZIndex + 2
	)
	if art then
		UiArtState.decorate(label, art, { tint = tint, size = if small then NODE_ART else ART })
	end
	local entry: Icon = {
		kind = kind,
		id = id,
		x = x,
		z = z,
		pixel = pixel,
		shown = pixel,
		button = button,
		glyph = label,
		plate = plate,
		stroke = stroke,
		scale = scale,
		mark = nil,
		color = tint,
		category = category,
		base = PRIORITY[kind],
		priority = PRIORITY[kind],
		target = nil,
		art = art,
	}
	table.insert(cached.icons, entry)
	return entry
end

local function portalIcons(cached: Cached, layers: { [string]: Frame })
	for _, portal in Portals.onMap(cached.mapId) do
		local target = Maps.get(portal.target)
		if not target then
			continue
		end
		if portal.kind == "cave" then
			local entry = icon(
				cached,
				layers.icons,
				"cave",
				portal.target,
				portal.x,
				portal.z,
				"⛰",
				"cave",
				UiArt.mapIcon("cave")
			)
			entry.target = portal.target
		elseif portal.kind == "dungeon" then
			local region = string.match(portal.target, "^dungeon_(.+)$") or ""
			local entry = icon(
				cached,
				layers.icons,
				"dungeon",
				region,
				portal.x,
				portal.z,
				"☠",
				"dungeon",
				UiArt.mapIcon("dungeon")
			)
			entry.target = portal.target
		else
			local entry = icon(
				cached,
				layers.icons,
				"portal",
				portal.id,
				portal.x,
				portal.z,
				"◎",
				"travel",
				UiArt.mapIcon("portal")
			)
			entry.target = portal.target
		end
	end
end

-- S134i: the Elite II hideouts of the map (Data/Areas lairs), from the data alone (never whether the Elite II lives).
local function lairIcons(cached: Cached, layers: { [string]: Frame })
	local data = Areas.byMap[cached.mapId]
	for _, lair in (if data then data.lairs or {} else {}) :: { Areas.Lair } do
		icon(cached, layers.icons, "lair", lair.id, lair.x, lair.z, "☠", "lair", UiArt.mapIcon("lair"))
	end
end

-- S149b: the world boss's barrow on its map; the live state (warning, fight, the time of the next one) is drawn over it
-- by WorldMap/Overlay.
local function worldBossIcon(cached: Cached, layers: { [string]: Frame })
	if cached.mapId ~= WorldBoss.Data.map then
		return
	end
	local spot = WorldBoss.spot()
	icon(cached, layers.icons, "worldboss", spot.id, spot.x, spot.z, "♛", "worldboss", UiArt.mapIcon("worldboss"))
end

local function npcIcons(cached: Cached, layers: { [string]: Frame })
	for _, npc in Npcs.list do
		if npc.map == cached.mapId and not npc.decoration then
			local entry = icon(
				cached,
				layers.npcs,
				"npc",
				npc.id,
				npc.position.x,
				npc.position.z,
				npc.icon,
				MapMarkers.npcCategory(npc.services :: any),
				UiArt.serviceOfNpc(npc)
			)
			entry.services = npc.services :: any
			-- the quest mark (! / ?) as a small badge on the plate's upper right
			local mark = Instance.new("TextLabel")
			mark.Name = "Mark"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.new(0.5, Canvas.PLATE / 2 - 3, 0.5, -Canvas.PLATE / 2 + 3)
			mark.Size = UDim2.fromOffset(20, 20)
			mark.BackgroundColor3 = PLATE_COLOR
			mark.Text = ""
			mark.TextSize = Theme.TextSize.Small
			mark.FontFace = Theme.Fonts.Display
			mark.TextColor3 = Theme.Brass.Bright
			mark.ZIndex = entry.button.ZIndex + 3
			mark.Visible = false
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = mark
			mark.Parent = entry.button
			entry.mark = mark
			cached.npcIcons[npc.id] = entry
		end
	end
end

local function nodeIcons(cached: Cached, layers: { [string]: Frame })
	for _, item in cached.sketch.icons do
		if item.t == "node" and item.id then
			local family = string.match(item.id, "^(%a+)_") or "vein"
			local color = Theme.tint(NODE_COLORS[family] or MAP.node)
			icon(
				cached,
				layers.nodes,
				"node",
				item.id,
				item.x,
				item.z,
				"●",
				"node",
				UiArt.mapIcon("node", family),
				color
			)
		end
	end
end

local function areaFrames(cached: Cached, layers: { [string]: Frame })
	local data = Areas.byMap[cached.mapId]
	for _, area in (if data then data.areas else {}) :: { Areas.Area } do
		local r = area.rect
		local a = MapSketch.toPixel(cached.sketch, cached.scale, r[1], r[2])
		local b = MapSketch.toPixel(cached.sketch, cached.scale, r[3], r[4])
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
		pill.BackgroundColor3 = PLATE_COLOR
		pill.BackgroundTransparency = 0.15
		pill.ZIndex = 3
		local pillScale = Instance.new("UIScale")
		pillScale.Parent = pill
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
		local name = line(1, Theme.TextSize.Caption, Theme.Fonts.BodyBold)
		name.RichText = true -- S33: the profile icon in its colour
		local levels = line(2, Theme.TextSize.Small, Theme.Fonts.Display)
		pill.Parent = f
		local star = Instance.new("ImageLabel")
		star.Name = "Recommended"
		star.AnchorPoint = Vector2.new(1, 0)
		star.Position = UDim2.new(1, -4, 0, 4)
		star.Size = UDim2.fromOffset(18, 18)
		star.BackgroundTransparency = 1
		star.ImageColor3 = Theme.Brass.Bright
		star.ZIndex = 4
		star.Visible = false
		star.Parent = f
		table.insert(cached.areas, {
			frame = f,
			area = area,
			stroke = stroke,
			pill = pill,
			pillScale = pillScale,
			name = name,
			levels = levels,
			star = star,
			nameWidth = 0,
		})
	end
end

-- One pooled cluster badge (a ringed plate with the count); its events go to the window through `cached.onCluster`.
local function clusterButton(cached: Cached, index: number): TextButton
	local existing = cached.clusterButtons[index]
	if existing then
		return existing
	end
	local parent = cached.layers.clusters
	local button = Instance.new("TextButton")
	button.Name = `cluster:{index}`
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Size = UDim2.fromOffset(Canvas.HIT, Canvas.HIT)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = parent.ZIndex + 1
	button.Visible = false
	button.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local _, stroke = Canvas.plate(button, "round", CLUSTER_PLATE, CLUSTER_COLOR, parent.ZIndex + 1)
	stroke.Thickness = 3
	local count = glyphLabel(button, "", Theme.Plain, Theme.TextSize.Body, parent.ZIndex + 2)
	count.Name = "Count"
	count.FontFace = Theme.Fonts.Display
	button.Activated:Connect(function(input: InputObject)
		local handler = cached.onCluster
		if handler then
			handler("tap", index, input)
		end
	end)
	button.MouseEnter:Connect(function()
		local handler = cached.onCluster
		if handler then
			handler("enter", index, nil)
		end
	end)
	button.MouseLeave:Connect(function()
		local handler = cached.onCluster
		if handler then
			handler("leave", index, nil)
		end
	end)
	cached.clusterButtons[index] = button
	return button
end

-- Quest marks on the NPC symbols: the badge, the importance and the category (a marked NPC is a "quest" one).
function Canvas.applyMarks(cached: Cached, marks: { [string]: NpcMarks.Mark })
	for npcId, entry in cached.npcIcons do
		entry.hidden = NpcMarkState.isHidden(npcId) -- S104 (applyLayout hides the symbol)
		local mark: any = marks[npcId]
		local style = NpcMarkState.style(mark)
		if entry.mark then
			entry.mark.Visible = style ~= nil
			if style then
				entry.mark.Text = style.text
				entry.mark.TextColor3 = style.color
			end
		end
		entry.priority = entry.base + NpcMarks.priority(mark) * 12
		local category = MapMarkers.npcCategory(entry.services or {}, mark ~= nil)
		if category ~= entry.category then
			entry.category = category
			entry.color = Canvas.categoryColor(category)
			entry.stroke.Color = entry.color
			entry.glyph.TextColor3 = entry.color
			UiArtState.retarget(entry.glyph, entry.art, entry.color)
		end
	end
end

-- Symbols per category on this map (NPCs the character sees, areas), for the filter chips.
function Canvas.counts(cached: Cached): { [string]: number }
	local out: { [string]: number } = {}
	for _, entry in cached.icons do
		if not entry.hidden then
			out[entry.category] = (out[entry.category] or 0) + 1
		end
	end
	if #cached.areas > 0 then
		out.area = #cached.areas
	end
	return out
end

-- Places everything for a zoom and a filter (hidden categories): symbol visibility and nudged positions, cluster
-- badges, the constant screen size of symbols and plates, and the area plates' spots. Cheap (a few hundred symbols at
-- most); runs on zoom, filter, quest mark and map changes, never per frame.
function Canvas.applyLayout(cached: Cached, zoomIndex: number, hidden: { [string]: boolean }, touch: boolean)
	local zoom = Canvas.ZOOMS[zoomIndex]
	local hit = if touch then Canvas.HIT_TOUCH else Canvas.HIT
	local detail = zoomIndex >= Canvas.DETAIL_ZOOM
	cached.layers.areas.Visible = not hidden.area
	local points: { MapMarkers.Point } = {}
	local byKey: { [string]: Icon } = {}
	for _, entry in cached.icons do
		local visible = not entry.hidden and not hidden[entry.category] and (entry.kind ~= "node" or detail)
		entry.button.Visible = false
		entry.button.Size = UDim2.fromOffset(hit, hit)
		entry.scale.Scale = 1 / zoom
		if visible then
			local key = entry.button.Name
			byKey[key] = entry
			table.insert(points, { key = key, x = entry.pixel.X, y = entry.pixel.Y, priority = entry.priority })
		end
	end
	local layout = MapMarkers.layout(points, zoom, { size = hit, spread = zoomIndex >= #Canvas.ZOOMS })
	local obstacles: { { x: number, y: number } } = {}
	for key, at in layout.placed do
		local entry = byKey[key]
		entry.shown = Vector2.new(at.x, at.y)
		entry.button.Position = UDim2.fromOffset(at.x, at.y)
		entry.button.Visible = true
		table.insert(obstacles, at)
	end
	table.clear(cached.clusters)
	for i, group in layout.clusters do
		local members: { Icon } = {}
		for _, key in group.members do
			local entry = byKey[key]
			entry.shown = Vector2.new(group.x, group.y)
			table.insert(members, entry)
		end
		cached.clusters[i] = { x = group.x, y = group.y, members = members }
		local button = clusterButton(cached, i)
		button.Position = UDim2.fromOffset(group.x, group.y)
		button.Size = UDim2.fromOffset(hit, hit)
		local scale = button:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1 / zoom
		end
		local plate = button:FindFirstChild("Plate")
		local stroke = plate and plate:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = members[1].color -- the ring of the most important symbol inside
		end
		local count = button:FindFirstChild("Count") :: TextLabel?
		if count then
			count.Text = tostring(#members)
		end
		button.Visible = true
		table.insert(obstacles, { x = group.x, y = group.y })
	end
	for i = #layout.clusters + 1, #cached.clusterButtons do
		cached.clusterButtons[i].Visible = false
	end
	-- Area plates: name and levels, else the levels alone, else nothing (room comes with the zoom).
	local nameSize, levelSize = Theme.TextSize.Caption, Theme.TextSize.Small
	for _, entry in cached.areas do
		local f = entry.frame
		local x0, y0 = f.Position.X.Offset, f.Position.Y.Offset
		local rect = { x0 = x0, y0 = y0, x1 = x0 + f.Size.X.Offset, y1 = y0 + f.Size.Y.Offset }
		local levelsWidth = MapMarkers.textWidth(entry.levels.Text, levelSize) + 14
		local fullW = math.max(entry.nameWidth, levelsWidth) + 14
		local fullH = nameSize + levelSize + 10
		local spot, cx, cy = MapMarkers.placeLabel(rect, fullW, fullH, zoom, obstacles, hit)
		local withName = spot ~= nil
		if not spot then
			spot, cx, cy = MapMarkers.placeLabel(rect, levelsWidth, levelSize + 8, zoom, obstacles, hit)
		end
		entry.pill.Visible = spot ~= nil
		entry.name.Visible = withName
		entry.pillScale.Scale = 1 / zoom
		if spot and cx and cy then
			entry.pill.Position = UDim2.fromOffset(cx - x0, cy - y0)
		end
	end
end

-- `profiles` (S33): hunting ground profile icons before the area names.
export type View = { onlyRecommended: boolean, highlight: string?, profiles: boolean? }

-- Localized plate texts and area colours (cheap: a few dozen objects), refreshed on language / level / view
-- change (S22: band of the nearest end of the range, "★" on recommended areas, dimmed others when only the
-- recommended ones are wanted, a gold outline on the highlighted area). The plates' spots come from applyLayout.
function Canvas.refresh(cached: Cached, level: number, view: View)
	for _, entry in cached.areas do
		local area = entry.area
		local color = Theme.tint(LevelBand.COLORS[AreaAdvice.bandOf(area, level)])
		local recommended = AreaAdvice.isRecommended(area, level)
		local dim = view.onlyRecommended and not recommended
		local highlighted = view.highlight == area.id
		entry.frame.BackgroundColor3 = color
		entry.frame.BackgroundTransparency = if dim then 0.9 else 0.55
		entry.stroke.Color = if highlighted then Theme.Brass.Bright else color:Lerp(Theme.Shade, 0.45)
		entry.stroke.Thickness = if highlighted then 4 else 2
		entry.stroke.Transparency = if dim then 0.7 else 0
		entry.pill.BackgroundTransparency = if dim then 0.75 else 0.15
		local icon = if view.profiles ~= false then AreaProfileText.iconRich(area.profile, nil, "iron") else ""
		local starLook = if recommended then UiArtState.lookNow(UiArt.mapIcon("recommended")) else nil
		entry.star.Visible = starLook ~= nil
		if starLook then
			UiArtState.apply(entry.star, starLook)
			entry.star.ImageTransparency = if dim then 0.6 else 0
		end
		local plain = Text.now(area.nameKey)
		entry.name.Text = (if icon ~= "" then icon .. " " else "")
			.. (if recommended and not starLook then "★ " else "")
			.. AreaProfileText.escape(plain)
		entry.nameWidth = MapMarkers.textWidth(plain, Theme.TextSize.Caption)
			+ (if icon ~= "" then Theme.TextSize.Caption + 4 else 0)
			+ (if recommended and not starLook then Theme.TextSize.Caption else 0)
		entry.name.TextColor3 = color
		entry.name.TextTransparency = if dim then 0.6 else 0
		entry.levels.Text = `{area.lv[1]}–{area.lv[2]}`
		entry.levels.TextColor3 = color
		entry.levels.TextTransparency = if dim then 0.6 else 0
	end
end

-- S119: painted picture or sketch, by the load state of the picture (the sketch is drawn late only if the picture
-- disappears again: /icons glyph after a build with the picture).
function paint(cached: Cached)
	local image = cached.painted
	if not image then
		return
	end
	local look = UiArtState.lookNow(UiArt.map(cached.mapId))
	if look then
		UiArtState.apply(image, look)
	end
	image.Visible = look ~= nil
	if not look and not cached.sketchLayer then
		local sketchLayer = layer(cached.canvas:FindFirstChild("Terrain") :: Frame, "Sketch", 1)
		MapSketch.draw(sketchLayer, cached.sketch, cached.scale)
		cached.sketchLayer = sketchLayer
	end
	if cached.sketchLayer then
		cached.sketchLayer.Visible = look == nil
	end
end

local function paintAll()
	for _, cached in cache do
		paint(cached)
	end
end
artScope:Observer(UiArtState.Loaded):onChange(paintAll)
artScope:Observer(IconState.Mode):onChange(paintAll)

-- Static layer of a map (cached), or nil when the map has no sketch yet.
function Canvas.get(mapId: string): Cached?
	local existing = cache[mapId]
	if existing then
		return existing
	end
	local map = Maps.get(mapId)
	local sketch = MapSketch.get(mapId)
	if not map or not sketch then
		return nil
	end
	local started = os.clock()
	local scale = Canvas.SIZE / math.max(sketch.size.x, sketch.size.z)
	local canvas = Instance.new("Frame")
	canvas.Name = `Map_{mapId}`
	canvas.Size = UDim2.fromOffset(sketch.size.x * scale, sketch.size.z * scale)
	canvas.BackgroundColor3 = MapSketch.background(map.biome)
	canvas.BorderSizePixel = 0
	local terrain = layer(canvas, "Terrain", 1)
	terrain.ClipsDescendants = true
	-- S119: the painted map (if the owner made one) instead of the drawn terrain.
	local frame = UiArt.mapFrame(mapId)
	local paintedKey = UiArt.map(mapId)
	local painted: ImageLabel? = nil
	local sketchLayer: Frame? = nil
	if frame then
		UiArtState.ensureKey(paintedKey)
		local corner = MapSketch.toPixel(sketch, scale, frame.x0, frame.z0)
		local image = Instance.new("ImageLabel")
		image.Name = "Painted"
		image.Position = UDim2.fromOffset(corner.X, corner.Y)
		image.Size = UDim2.fromOffset(frame.size * scale, frame.size * scale)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Stretch
		image.ZIndex = 1
		image.Visible = false
		image.Parent = terrain
		painted = image
	end
	if not (frame and UiArtState.lookNow(paintedKey)) then
		sketchLayer = layer(terrain, "Sketch", 1)
		MapSketch.draw(sketchLayer :: Frame, sketch, scale)
	end
	local layers = {
		areas = layer(canvas, "Areas", 2),
		nodes = layer(canvas, "Nodes", 4),
		icons = layer(canvas, "Icons", 5),
		npcs = layer(canvas, "Npcs", 5),
		clusters = layer(canvas, "Clusters", 6),
	}
	local cached: Cached = {
		mapId = mapId,
		canvas = canvas,
		scale = scale,
		sketch = sketch,
		areas = {},
		layers = layers,
		icons = {},
		npcIcons = {},
		painted = painted,
		sketchLayer = sketchLayer,
		clusters = {},
		clusterButtons = {},
		onCluster = nil,
	}
	paint(cached)
	areaFrames(cached, layers)
	portalIcons(cached, layers)
	lairIcons(cached, layers) -- S134i
	worldBossIcon(cached, layers) -- S149b
	npcIcons(cached, layers)
	nodeIcons(cached, layers)
	local count = #canvas:GetDescendants()
	print(`[WorldMap] {mapId}: static layer built in {math.floor((os.clock() - started) * 1000)} ms, {count} objects`)
	cache[mapId] = cached
	return cached
end

-- Map-relative position -> canvas pixel (zoom 1).
function Canvas.toPixel(cached: Cached, x: number, z: number): Vector2
	return MapSketch.toPixel(cached.sketch, cached.scale, x, z)
end

-- Drops the cached static layers (admin /mapcache clear, a rebuilt map).
function Canvas.clearCache()
	for id, cached in cache do
		cached.canvas:Destroy()
		cache[id] = nil
	end
	MapSketch.clearCache()
end

return Canvas
