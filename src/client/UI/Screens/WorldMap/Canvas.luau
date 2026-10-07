--!strict
-- Static layer of one map in the world map window (S20, reworked in S25), built once per map and cached:
-- the sketch (terrain, roads, water, buildings), monster areas (buttons with a name and level pill) and the
-- icons: NPCs (with the quest mark), portals, city gates, cave mouths, exits, dungeon gates (Data/Portals) and
-- gathering nodes (from the sketch). Every icon is a light transparent TextButton whose hit area stays
-- Canvas.HIT pixels wide at every zoom (its size is divided by the zoom); the glyph and caption inside grow
-- with the zoom like the rest of the drawing. At the smallest zoom overlapping icons keep only the most
-- important one (NPC with a quest > portal > dungeon > NPC > node); the hidden ones stay reachable by search.
-- The window wires one set of connections for the shown map (WorldMap/init).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaProfileText = require(script.Parent.Parent.Parent.AreaProfileText)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local NpcMarkState = require(script.Parent.Parent.Parent.NpcMarkState)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Portals = require(ReplicatedStorage.Shared.Data.Portals)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Canvas = {}

Canvas.SIZE = 760 -- base canvas size in pixels (zoom 1)
Canvas.ZOOMS = { 1, 1.6, 2.5, 4 }
Canvas.DETAIL_ZOOM = 2 -- nodes and NPC names from this zoom index
Canvas.HIT = 36 -- icon hit area in pixels at every zoom (UI scale 1)
local CROWD = 22 -- icons closer than this at zoom 1 overlap

export type IconKind = "npc" | "portal" | "cave" | "dungeon" | "node"

export type Icon = {
	kind: IconKind,
	id: string, -- NPC id, portal id, cave map id, dungeon region, node kind
	x: number,
	z: number,
	pixel: Vector2, -- canvas pixel at zoom 1
	button: TextButton,
	glyph: TextLabel,
	caption: TextLabel?,
	mark: TextLabel?,
	color: Color3,
	base: number, -- importance without quest marks
	priority: number,
	crowded: boolean,
	target: string?, -- portals: map they lead to
}

export type AreaEntry = {
	frame: TextButton,
	area: Areas.Area,
	stroke: UIStroke,
	pill: Frame,
	name: TextLabel,
	levels: TextLabel,
}

export type Cached = {
	mapId: string,
	canvas: Frame,
	scale: number,
	sketch: MapSketch.Sketch,
	areas: { AreaEntry },
	layers: { [string]: Frame },
	icons: { Icon },
	npcIcons: { [string]: Icon },
	captions: { TextLabel },
}

local PRIORITY: { [IconKind]: number } = { portal = 40, cave = 40, dungeon = 30, npc = 20, node = 10 }
local NODE_COLORS: { [string]: string } = { vein = "#E8C25A", bush = "#6FCF5A", fishing = "#5AA8E8" }

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

local function text(parent: Instance, value: string, color: Color3, size: number, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.Size = UDim2.fromOffset(220, size + 4)
	l.BackgroundTransparency = 1
	l.Text = value
	l.TextSize = size
	l.FontFace = Theme.Fonts.BodyBold
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.25
	l.ZIndex = z
	l.Active = false
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

-- One icon: a transparent button (hit area) with the glyph, an optional caption under it and a quest mark.
local function icon(
	cached: Cached,
	parent: Frame,
	kind: IconKind,
	id: string,
	x: number,
	z: number,
	glyph: string,
	color: Color3,
	size: number
): Icon
	local pixel = MapSketch.toPixel(cached.sketch, cached.scale, x, z)
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
	local label = text(button, glyph, color, size, parent.ZIndex + 2)
	label.Size = UDim2.fromOffset(size + 8, size + 6)
	local entry: Icon = {
		kind = kind,
		id = id,
		x = x,
		z = z,
		pixel = pixel,
		button = button,
		glyph = label,
		caption = nil,
		mark = nil,
		color = color,
		base = PRIORITY[kind],
		priority = PRIORITY[kind],
		crowded = false,
		target = nil,
	}
	table.insert(cached.icons, entry)
	return entry
end

local function caption(
	cached: Cached,
	entry: Icon,
	key: string,
	suffix: string?,
	color: Color3,
	size: number,
	dy: number
)
	local l = text(entry.button, "", color, size, entry.button.ZIndex + 1)
	l.Position = UDim2.new(0.5, 0, 0.5, dy)
	l:SetAttribute("Key", key)
	if suffix then
		l:SetAttribute("Suffix", suffix)
	end
	entry.caption = l
	table.insert(cached.captions, l)
end

local function portalIcons(cached: Cached, layers: { [string]: Frame })
	for _, portal in Portals.onMap(cached.mapId) do
		local target = Maps.get(portal.target)
		if not target then
			continue
		end
		local levels = if target.id == "city" then "" else ` {target.minLevel}–{target.maxLevel}`
		if portal.kind == "cave" then
			local cave = Areas.caves.get(portal.target)
			local entry =
				icon(cached, layers.icons, "cave", portal.target, portal.x, portal.z, "⛰", Theme.Colors.ZoneRed, 20)
			entry.target = portal.target
			caption(
				cached,
				entry,
				if cave then cave.nameKey else target.nameKey,
				if cave then ` {cave.levels[1]}–{cave.levels[2]}` else levels,
				Color3.fromHex("#F2B8A8"),
				11,
				16
			)
		elseif portal.kind == "dungeon" then
			local region = string.match(portal.target, "^dungeon_(.+)$") or ""
			local entry =
				icon(cached, layers.icons, "dungeon", region, portal.x, portal.z, "☠", Theme.Colors.Danger, 20)
			entry.target = portal.target
			local key = bossOf(region)
			if key then
				caption(cached, entry, key, nil, Theme.Colors.DangerHover, 11, 15)
			end
		else
			local entry = icon(
				cached,
				layers.icons,
				"portal",
				portal.id,
				portal.x,
				portal.z,
				"◎",
				Color3.fromHex("#B9A8FF"),
				18
			)
			entry.target = portal.target
			caption(cached, entry, target.nameKey, levels, Color3.fromHex("#D8CCFF"), 11, 14)
		end
	end
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
				Theme.Colors.Parchment,
				15
			)
			caption(cached, entry, npc.nameKey, nil, Theme.Colors.Parchment, 10, 13)
			local mark = text(entry.button, "", Theme.Colors.GoldBright, 17, entry.button.ZIndex + 2)
			mark.FontFace = Theme.Fonts.Heading
			mark.Position = UDim2.new(0.5, 0, 0.5, -15)
			mark.Size = UDim2.fromOffset(20, 20)
			mark.TextStrokeTransparency = 0.1
			mark.Visible = false
			entry.mark = mark
			cached.npcIcons[npc.id] = entry
		end
	end
end

local function nodeIcons(cached: Cached, layers: { [string]: Frame })
	for _, item in cached.sketch.icons do
		if item.t == "node" and item.id then
			local family = string.match(item.id, "^(%a+)_") or "vein"
			local color = Color3.fromHex(NODE_COLORS[family] or "#E8C25A")
			local entry = icon(cached, layers.nodes, "node", item.id, item.x, item.z, "●", color, 7)
			entry.glyph.TextStrokeTransparency = 0.6
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
		name.RichText = true -- S33: the profile icon in its colour
		local levels = line(2, 17, Theme.Fonts.Heading)
		pill.Parent = f
		table.insert(
			cached.areas,
			{ frame = f, area = area, stroke = stroke, pill = pill, name = name, levels = levels }
		)
	end
end

-- Recomputes which icons overlap at the smallest zoom (the more important one stays).
function Canvas.declutter(cached: Cached)
	local order = table.clone(cached.icons)
	table.sort(order, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.button.Name < b.button.Name
	end)
	local kept: { Icon } = {}
	for _, entry in order do
		entry.crowded = false
		if entry.kind ~= "node" then
			for _, other in kept do
				if (other.pixel - entry.pixel).Magnitude < CROWD then
					entry.crowded = true
					break
				end
			end
			if not entry.crowded then
				table.insert(kept, entry)
			end
		end
	end
end

-- Quest marks over the NPC icons (and their importance on the map).
function Canvas.applyMarks(cached: Cached, marks: { [string]: NpcMarks.Mark })
	for npcId, entry in cached.npcIcons do
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
	end
	Canvas.declutter(cached)
end

-- Service chips (S25): matching NPCs stay bright, the others fade (transparency only).
function Canvas.applyFilter(cached: Cached, services: { [string]: boolean }?)
	for npcId, entry in cached.npcIcons do
		local def = Npcs.get(npcId)
		local match = true
		if services and next(services) ~= nil then
			match = false
			for _, service in (if def then def.services else {}) :: { string } do
				if services[service] then
					match = true
				end
			end
		end
		local filtering = services ~= nil and next(services) ~= nil
		entry.glyph.TextTransparency = if match then 0 else 0.75
		entry.glyph.TextStrokeTransparency = if match then 0.25 else 0.85
		entry.glyph.TextColor3 = if filtering and match then Theme.Colors.GoldBright else entry.color
		if entry.caption then
			entry.caption.TextTransparency = if match then 0 else 0.8
			entry.caption.TextStrokeTransparency = if match then 0.25 else 0.9
		end
	end
end

export type Toggles = { areas: boolean, icons: boolean, npcs: boolean, nodes: boolean }

-- Layer switches, crowding at the smallest zoom and hit areas that keep their size at every zoom.
function Canvas.applyZoom(cached: Cached, zoomIndex: number, toggles: Toggles)
	local zoom = Canvas.ZOOMS[zoomIndex]
	local detail = zoomIndex >= Canvas.DETAIL_ZOOM
	cached.layers.areas.Visible = toggles.areas
	cached.layers.icons.Visible = toggles.icons
	cached.layers.npcs.Visible = toggles.npcs
	cached.layers.nodes.Visible = toggles.nodes and detail
	local hit = Canvas.HIT / zoom
	for _, entry in cached.icons do
		entry.button.Size = UDim2.fromOffset(hit, hit)
		entry.button.Visible = not (zoomIndex == 1 and entry.crowded)
		if entry.kind == "npc" and entry.caption then
			entry.caption.Visible = detail
		end
	end
end

-- `profiles` (S33): hunting ground profile icons before the area names.
export type View = { onlyRecommended: boolean, highlight: string?, profiles: boolean? }

-- Localized captions and area colours (cheap: a few dozen objects), refreshed on language / level / view
-- change (S22: band of the nearest end of the range, "★" on recommended areas, dimmed others when only the
-- recommended ones are wanted, a gold outline on the highlighted area).
function Canvas.refresh(cached: Cached, level: number, view: View)
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
		local icon = if view.profiles ~= false then AreaProfileText.iconRich(area.profile, nil) else ""
		entry.name.Text = (if icon ~= "" then icon .. " " else "")
			.. (if recommended then "★ " else "")
			.. AreaProfileText.escape(Text.now(area.nameKey))
		entry.name.TextColor3 = color
		entry.name.TextTransparency = if dim then 0.6 else 0
		entry.levels.Text = `{area.lv[1]}–{area.lv[2]}`
		entry.levels.TextColor3 = color
		entry.levels.TextTransparency = if dim then 0.6 else 0
	end
	for _, label in cached.captions do
		local key = label:GetAttribute("Key")
		if type(key) == "string" then
			local suffix = label:GetAttribute("Suffix")
			label.Text = Text.now(key) .. (if type(suffix) == "string" then suffix else "")
		end
	end
end

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
	MapSketch.draw(terrain, sketch, scale)
	local layers = {
		areas = layer(canvas, "Areas", 2),
		nodes = layer(canvas, "Nodes", 4),
		icons = layer(canvas, "Icons", 5),
		npcs = layer(canvas, "Npcs", 5),
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
		captions = {},
	}
	areaFrames(cached, layers)
	portalIcons(cached, layers)
	npcIcons(cached, layers)
	nodeIcons(cached, layers)
	Canvas.declutter(cached)
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
