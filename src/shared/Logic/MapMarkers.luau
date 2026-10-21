--!strict
-- Map markers (owner 2026-10-20 "Mapa"): the categories of the world map's symbols (shape, glyph, colour, filter chip),
-- the player's hidden categories (account setting `mapHide`) and the declutter layout of the symbols on screen: icons
-- that would overlap are nudged apart on a small ring (up to NUDGE_MAX together, or any number at the closest zoom)
-- or folded into one cluster badge with a count that zooms in on a click. Area name plates take a free spot inside
-- their area (centre, top, bottom) or hide. Pure: points are plain { x, y } tables in canvas pixels at zoom 1, sizes
-- in screen pixels (an icon keeps its screen size at every zoom). Used by UI/Screens/WorldMap (Canvas, Panels,
-- Overlay, Search) and the server's setting validator.

local MapMarkers = {}

export type Shape = "round" | "diamond" | "square"

export type Category = {
	id: string,
	glyph: string,
	color: string, -- key in Data/UiPalette.map
	shape: Shape,
	overlay: boolean?, -- a moving marker of the map's live layer (party, own marks, quest target, world event)
}

-- Filter chip order. Shapes: round = people, diamond = ways (portals, caves), square = danger (dungeons, lairs, bosses).
MapMarkers.CATEGORIES = {
	{ id = "quest", glyph = "!", color = "catQuest", shape = "round" },
	{ id = "shop", glyph = "⚖", color = "catShop", shape = "round" },
	{ id = "smith", glyph = "⚒", color = "catSmith", shape = "round" },
	{ id = "bank", glyph = "⛃", color = "catBank", shape = "round" },
	{ id = "npc", glyph = "☺", color = "catNpc", shape = "round" },
	{ id = "travel", glyph = "◎", color = "catTravel", shape = "diamond" },
	{ id = "cave", glyph = "⛰", color = "catCave", shape = "diamond" },
	{ id = "dungeon", glyph = "☠", color = "catDungeon", shape = "square" },
	{ id = "lair", glyph = "☠", color = "catLair", shape = "square" },
	{ id = "worldboss", glyph = "♛", color = "worldBoss", shape = "square" },
	{ id = "area", glyph = "⚔", color = "catArea", shape = "square" },
	{ id = "node", glyph = "●", color = "node", shape = "round" },
	{ id = "party", glyph = "●", color = "party", shape = "round", overlay = true },
	{ id = "mark", glyph = "⚑", color = "flag", shape = "round", overlay = true },
	{ id = "objective", glyph = "★", color = "quest", shape = "round", overlay = true },
	{ id = "event", glyph = "⚔", color = "event", shape = "round", overlay = true },
} :: { Category }

MapMarkers.byId = {} :: { [string]: Category }
for _, category in MapMarkers.CATEGORIES do
	MapMarkers.byId[category.id] = category
end

-- NPC services -> category (the first service that has one wins; story tellers and quest boards are "quest").
local SERVICE_CATEGORY: { [string]: string } = {
	story = "quest",
	quests = "quest",
	shop = "shop",
	alchemy = "shop",
	vendors = "shop",
	backpacks = "shop",
	mounts = "shop",
	arenashop = "shop",
	huntshop = "shop",
	portalshop = "shop", -- S160k: the Portal Master
	look = "shop",
	blacksmith = "smith",
	deposit = "bank",
	mail = "bank",
	auction = "bank",
}
MapMarkers.SERVICE_CATEGORY = SERVICE_CATEGORY

-- Category of an NPC: "quest" while it has a quest mark (! or ?), else by its services, else "npc".
function MapMarkers.npcCategory(services: { string }, marked: boolean?): string
	if marked then
		return "quest"
	end
	for _, service in services do
		local category = SERVICE_CATEGORY[service]
		if category then
			return category
		end
	end
	return "npc"
end

-- Category of a map icon or a search result kind (NPCs go through npcCategory).
local KIND_CATEGORY: { [string]: string } = {
	portal = "travel",
	map = "travel",
	cave = "cave",
	dungeon = "dungeon",
	boss = "dungeon",
	lair = "lair",
	worldboss = "worldboss",
	node = "node",
	area = "area",
	monster = "area",
	npc = "npc",
}
function MapMarkers.kindCategory(kind: string): string
	return KIND_CATEGORY[kind] or "npc"
end

-- Hidden categories: the saved list (account.settings.mapHide) <-> a set. Unknown ids are dropped.
function MapMarkers.hiddenSet(list: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(list) == "table" then
		for _, id in list do
			if type(id) == "string" and MapMarkers.byId[id] then
				set[id] = true
			end
		end
	end
	return set
end

function MapMarkers.hiddenList(set: { [string]: boolean }): { string }
	local out: { string } = {}
	for _, category in MapMarkers.CATEGORIES do
		if set[category.id] then
			table.insert(out, category.id)
		end
	end
	return out
end

-- Server validator of the setting: an array of distinct known category ids.
function MapMarkers.validHidden(value: any): boolean
	if type(value) ~= "table" or #value > #MapMarkers.CATEGORIES then
		return false
	end
	local seen: { [string]: boolean } = {}
	local n = 0
	for key, id in value do
		n += 1
		if type(key) ~= "number" or type(id) ~= "string" or not MapMarkers.byId[id] or seen[id] then
			return false
		end
		seen[id] = true
	end
	return n == #value
end

-- Flips one category; returns a new set.
function MapMarkers.toggle(set: { [string]: boolean }, id: string): { [string]: boolean }
	local out = table.clone(set)
	if out[id] then
		out[id] = nil
	else
		out[id] = true
	end
	return out
end

-- Every category hidden (`none`) or none hidden (`all`); returns a new set.
function MapMarkers.setAll(show: boolean): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if not show then
		for _, category in MapMarkers.CATEGORIES do
			out[category.id] = true
		end
	end
	return out
end

-- Layout --------------------------------------------------------------------------------------------------------

MapMarkers.NUDGE_MAX = 3 -- up to this many overlapping icons are spread on a ring, more become a cluster

export type Point = { key: string, x: number, y: number, priority: number }
export type Placed = { x: number, y: number }
export type Cluster = { x: number, y: number, members: { string } }
export type Layout = { placed: { [string]: Placed }, clusters: { Cluster } }
export type LayoutOptions = {
	size: number, -- screen pixels one icon needs (centre to centre)
	spread: boolean?, -- never cluster (the closest zoom): every group goes on a ring
}

local function byPriority(a: Point, b: Point): boolean
	if a.priority ~= b.priority then
		return a.priority > b.priority
	end
	return a.key < b.key
end

-- Places the points for one zoom. Groups: each point joins the first group (by priority) whose anchor is closer than
-- `size` on screen, else starts its own. A group of one stays; a small group (or any group with `spread`) is spread on
-- a ring around its centre (members keep their order around it, neighbours exactly `size` apart); a bigger group
-- becomes a cluster at its centre. Returns positions in canvas pixels (zoom 1).
function MapMarkers.layout(points: { Point }, zoom: number, options: LayoutOptions): Layout
	local order = table.clone(points)
	table.sort(order, byPriority)
	local reach = options.size / math.max(zoom, 1e-3) -- canvas pixels
	local groups: { { Point } } = {}
	for _, point in order do
		local joined = false
		for _, group in groups do
			local anchor = group[1]
			local dx, dy = point.x - anchor.x, point.y - anchor.y
			if dx * dx + dy * dy < reach * reach then
				table.insert(group, point)
				joined = true
				break
			end
		end
		if not joined then
			table.insert(groups, { point })
		end
	end
	local placed: { [string]: Placed } = {}
	local clusters: { Cluster } = {}
	for _, group in groups do
		local n = #group
		if n == 1 then
			placed[group[1].key] = { x = group[1].x, y = group[1].y }
			continue
		end
		local cx, cy = 0, 0
		for _, point in group do
			cx += point.x
			cy += point.y
		end
		cx /= n
		cy /= n
		if n > MapMarkers.NUDGE_MAX and not options.spread then
			local members: { string } = {}
			for _, point in group do
				table.insert(members, point.key)
			end
			table.insert(clusters, { x = cx, y = cy, members = members })
			continue
		end
		-- Ring: neighbours one icon apart (chord = size), members in their own order around the centre.
		local radius = reach / (2 * math.sin(math.pi / n))
		local around = table.clone(group)
		local angles: { [string]: number } = {}
		for i, point in around do
			local dx, dy = point.x - cx, point.y - cy
			-- coincident points: their priority order, starting at the top
			angles[point.key] = if dx * dx + dy * dy < 1e-6
				then -math.pi / 2 + (i - 1) * 2 * math.pi / n
				else math.atan2(dy, dx)
		end
		table.sort(around, function(a, b)
			if angles[a.key] ~= angles[b.key] then
				return angles[a.key] < angles[b.key]
			end
			return a.key < b.key
		end)
		local start = angles[around[1].key]
		for i, point in around do
			local angle = start + (i - 1) * 2 * math.pi / n
			placed[point.key] = { x = cx + math.cos(angle) * radius, y = cy + math.sin(angle) * radius }
		end
	end
	return { placed = placed, clusters = clusters }
end

-- Zoom index a click on a cluster goes to: the first closer zoom at which its members form no cluster any more (the
-- closest zoom otherwise, where everything is spread).
function MapMarkers.splitZoom(points: { Point }, zooms: { number }, index: number, size: number): number
	for i = index + 1, #zooms do
		if #MapMarkers.layout(points, zooms[i], { size = size }).clusters == 0 then
			return i
		end
	end
	return #zooms
end

-- Rough width in pixels of a one-line text (UTF-8 aware; good enough to decide whether a plate fits).
function MapMarkers.textWidth(text: string, size: number): number
	local length = utf8.len(text) or #text
	return length * size * 0.56
end

export type Rect = { x0: number, y0: number, x1: number, y1: number }
export type Spot = "centre" | "top" | "bottom"

local SPOTS: { Spot } = { "centre" :: Spot, "top" :: Spot, "bottom" :: Spot }
local MARGIN = 4 -- screen pixels between a plate and its area's edge

-- Where a plate of w x h screen pixels goes inside `rect` (canvas pixels) at `zoom` without touching an obstacle
-- (icon centres in canvas pixels, `obstacle` screen pixels wide): the first free spot of centre, top, bottom, or nil
-- (the plate hides). Returns the spot and the plate's centre in canvas pixels.
function MapMarkers.placeLabel(
	rect: Rect,
	w: number,
	h: number,
	zoom: number,
	obstacles: { { x: number, y: number } },
	obstacle: number
): (Spot?, number?, number?)
	local z = math.max(zoom, 1e-3)
	local width = (rect.x1 - rect.x0) * z
	local height = (rect.y1 - rect.y0) * z
	if w + 2 * MARGIN > width or h + 2 * MARGIN > height then
		return nil, nil, nil
	end
	local cx = (rect.x0 + rect.x1) / 2
	local half = obstacle / 2
	for _, spot in SPOTS do
		local cy = if spot == "centre"
			then (rect.y0 + rect.y1) / 2
			elseif spot == "top" then rect.y0 + (MARGIN + h / 2) / z
			else rect.y1 - (MARGIN + h / 2) / z
		local free = true
		for _, o in obstacles do
			-- screen-space overlap of the plate and the obstacle's square
			local dx = math.abs(o.x - cx) * z
			local dy = math.abs(o.y - cy) * z
			if dx < w / 2 + half and dy < h / 2 + half then
				free = false
				break
			end
		end
		if free then
			return spot :: Spot, cx, cy
		end
	end
	return nil, nil, nil
end

return MapMarkers
