--!strict
-- Round minimap (DESIGN §23, top right), north up: the current map's sketch (paths, water, buildings),
-- the player arrow (camera heading), nearby monsters (bigger dots for elites), NPCs with their service
-- glyph, portals, dungeon gates and gathering nodes. Map name and zone colour below, zoom + / −.
-- S22: monster areas filled stronger in the band colour relative to the player (redrawn after a level-up),
-- level ranges written on them at the closest zoom, the current area's name in its band colour.
-- S25: a click / tap opens the world map centred on the player; quest marks (! / ?) over NPCs, own map marks,
-- the guide target and, when it is out of view (or on another map), an arrow on the edge towards it (or towards
-- the portal on the way). Moving markers come from pools (no instances created while playing).
-- S78 Scout's Eye (ROZWOJ 11.5): Elites are shown MONSTER_RANGE + bonus studs away (own minimapEliteBonus hook or the
-- scoutRange of a party member nearby, Logic/ScoutRange); those beyond the disc get markers pinned to its edge.
-- Without the node (bonus 0) nothing changes. Only monsters the client has streamed in can be shown.
-- S134i: the Elite II hideouts of the map as a fixed skull (ICONS.lair) from the data, never from a monster's state.
-- S101: the world event of this map (its glyph and colour, faded during the warning) while inside the disc (like
-- the quest star, no edge marker).
-- S149b: the world boss's barrow as a fixed crown (ICONS.worldBoss) on its map; while the boss wakes, fights or has just
-- fallen (Logic/WorldBoss.markerOf) a brighter crown, or an arrow on the edge towards it when it is out of the disc.
-- S119: the owner's silhouettes on the markers and icons (UiArtState.decorate / retarget: pooled labels only change
-- properties) and the painted map instead of the drawn sketch once its picture is loaded (same frame as the world map).
-- Owner 2026-10-20 "Mapa": the world map's symbol language here too: every fixed symbol is a dark plate in its
-- category's shape and colour (UI/MapSymbol, Logic/MapMarkers), no text over them. Overlapping symbols are nudged
-- apart (up to MapMarkers.NUDGE_MAX), a bigger crowd shows only its most important symbol (spread at the closest
-- zoom). The level ranges at the closest zoom take a free spot or hide. The world map's filter (account setting
-- `mapHide`) hides the same categories here (monster dots always stay). Party, own marks, the quest star and the event
-- sit on round plates too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AreaProfileText = require(script.Parent.Parent.Parent.AreaProfileText)
local AreaState = require(script.Parent.Parent.Parent.AreaState)
local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local ArtIcon = require(script.Parent.Parent.Parent.Components.ArtIcon)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GroupColors = require(script.Parent.Parent.Parent.GroupColors)
local IconState = require(script.Parent.Parent.Parent.IconState)
local MapSketch = require(script.Parent.Parent.Parent.MapSketch)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MapMarks = require(ReplicatedStorage.Shared.Data.MapMarks)
local MapMarkers = require(ReplicatedStorage.Shared.Logic.MapMarkers)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSymbol = require(script.Parent.Parent.Parent.MapSymbol)
local NavTarget = require(script.Parent.Parent.Parent.NavTarget)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local NpcMarkState = require(script.Parent.Parent.Parent.NpcMarkState)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local PhoneHud = require(ReplicatedStorage.Shared.Logic.PhoneHud)
local QuestTrack = require(script.Parent.Parent.Parent.QuestTrack)
local State = require(script.Parent.Parent.Parent.State)
local ScoutRange = require(ReplicatedStorage.Shared.Logic.ScoutRange)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local UiArtState = require(script.Parent.Parent.Parent.UiArtState)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)
local WanderingMerchant = require(ReplicatedStorage.Shared.Logic.WanderingMerchant)
local WorldBoss = require(ReplicatedStorage.Shared.Logic.WorldBoss)
local WorldEvents = require(ReplicatedStorage.Shared.Logic.WorldEvents)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local SIZE = 220
-- W29: the mail envelope on a phone in landscape (x MINIMAP_SCALE = MinTouch)
local MAIL_PHONE = math.ceil(Theme.Size.MinTouch / PhoneHud.MINIMAP_SCALE)
local ZOOMS = { 0.25, 0.4, 0.6, 0.9 }
local MONSTER_RANGE = 140
local MONSTER_DOTS = 60
local MAX_MARKS = 8
local EDGE = SIZE / 2 - 14 -- pixels from the centre where the edge arrow sits
local ELITE_PINS = 8 -- S78: edge markers of Elites beyond the disc (Scout's Eye)
local ZONE_COLORS = {
	green = Theme.Zone.Green,
	yellow = Theme.Zone.Yellow,
	red = Theme.Zone.Red,
}
-- S136: the drawing keeps its colours (Data/UiPalette.map)
local MAP = UiPalette.map
local ICONS: { [string]: { glyph: string, color: string } } = {
	portal = { glyph = "◎", color = MAP.portal },
	cave = { glyph = "⛰", color = MAP.cave },
	dungeon = { glyph = "☠", color = MAP.dungeon },
	node = { glyph = "•", color = MAP.node },
	spawn = { glyph = "", color = MAP.spawn },
	lair = { glyph = "☠", color = MAP.lair }, -- S134i: an Elite II hideout (a fixed marker, like a cave)
	worldBoss = { glyph = "♛", color = MAP.worldBoss }, -- S149b: the world boss's barrow (fixed) and the live boss
}

local PLAYER_ART = UiArt.mapIcon("player")
local SYMBOL = 20 -- plate of a fixed symbol (pixels; also the spacing of the declutter)
local NODE_SYMBOL = 13
local SYMBOL_ART = 15
local NODE_ART = 10
local MARKER = 18 -- round plate of the moving markers (party, own marks, quest star, event)
-- sketch icon type -> symbol category (Logic/MapMarkers)
local SKETCH_CATEGORY: { [string]: string } = { portal = "travel", cave = "cave", dungeon = "dungeon", node = "node" }
local PRIORITY: { [string]: number } = {
	travel = 40,
	cave = 40,
	worldboss = 35,
	dungeon = 30,
	lair = 30,
	npc = 20,
	node = 10,
}

-- A fixed symbol before the declutter (owner 2026-10-20 "Mapa").
type Candidate = {
	key: string,
	category: string,
	glyph: string,
	art: string?,
	color: Color3?,
	p: Vector2,
	priority: number,
	mark: any,
	faded: boolean?,
}

-- A moving marker's label on a round dark plate ringed in its colour (the world map's look).
local function onPlate(label: TextLabel, color: Color3)
	label.BackgroundColor3 = MapSymbol.PLATE_COLOR
	label.BackgroundTransparency = 0.08
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Ring"
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.PaddingLeft = UDim.new(0, 3)
	padding.PaddingRight = UDim.new(0, 3)
	padding.Parent = label
end

local function ringOf(label: TextLabel, color: Color3)
	local ring = label:FindFirstChild("Ring") :: UIStroke?
	if ring then
		ring.Color = color
	end
end

-- W28: the colour of a monster's dot: its family (Data/Families), so a glance tells beasts from undead from people;
-- unknown kinds keep the old group-size colour.
local FAMILY_COLORS: { [string]: Color3 } = {
	animal = Theme.tint(MAP.famAnimal),
	humanoid = Theme.tint(MAP.famHumanoid),
	undead = Theme.tint(MAP.famUndead),
	beast = Theme.tint(MAP.famBeast),
	elemental = Theme.tint(MAP.famElemental),
	dragon = Theme.tint(MAP.famDragon),
}
local DOT_OUTLINE = Theme.tint(MAP.dotOutline)
local function familyColor(model: Instance): Color3?
	local id = model:GetAttribute("MonsterId")
	local def = if type(id) == "string" then Monsters.get(id) else nil
	local family = def and (def :: any).family
	return if type(family) == "string" then FAMILY_COLORS[family] else nil
end

local function glyph(parent: Instance, text: string, color: string, position: Vector2, size: number, z: number?)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(size, size)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.BodyBold
	label.TextColor3 = Theme.tint(color)
	label.TextStrokeTransparency = 0.3
	label.ZIndex = z or 3
	label.Parent = parent
	return label
end

export type Props = { ShowWindow: (id: string) -> () }

local function Minimap(scope: Scope, props: Props): Instance
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
	-- Rotating mode (option "minimapRotate", S14) turns this holder so the camera direction points up.
	local holder = scope:New("Frame")({
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1,
	}) :: Frame
	canvas.Parent = holder
	local rotating = State.Value({ "account", "settings", "minimapRotate" })
	local northPosition = scope:Value(UDim2.new(0.5, 0, 0, 12))
	local dynamic = scope:New("Frame")({
		Name = "Dynamic",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = canvas,
	}) :: Frame

	-- Pools of the moving markers (S25): created once, only moved and shown / hidden.
	local questStar = glyph(dynamic, "★", MAP.quest, Vector2.zero, MARKER, 6)
	questStar.Visible = false
	onPlate(questStar, Theme.tint(MAP.quest))
	UiArtState.decorate(questStar, UiArt.mapIcon("quest"), { size = SYMBOL_ART })
	local navGlyph = glyph(dynamic, "◆", MAP.guide, Vector2.zero, 18, 7)
	navGlyph.Visible = false
	UiArtState.decorate(navGlyph, UiArt.mapIcon("guide"))
	local navArrow = glyph(dynamic, "▲", MAP.guide, Vector2.zero, 20, 8)
	navArrow.TextStrokeTransparency = 0
	navArrow.Visible = false
	local markPool: { TextLabel } = {}
	for i = 1, MAX_MARKS do
		markPool[i] = glyph(dynamic, "⚑", MAP.flag, Vector2.zero, MARKER, 6)
		markPool[i].Visible = false
		onPlate(markPool[i], Theme.tint(MAP.flag))
		UiArtState.decorate(markPool[i], nil, { size = SYMBOL_ART })
	end
	-- S134d: the Invasion zone's circle (radius from the state); the disc's CanvasGroup clips it
	local eventZone = Instance.new("Frame")
	eventZone.Name = "EventZone"
	eventZone.AnchorPoint = Vector2.new(0.5, 0.5)
	eventZone.BackgroundTransparency = 0.82
	eventZone.BorderSizePixel = 0
	eventZone.ZIndex = 2
	eventZone.Visible = false
	eventZone.Parent = dynamic
	local eventZoneCorner = Instance.new("UICorner")
	eventZoneCorner.CornerRadius = UDim.new(0.5, 0)
	eventZoneCorner.Parent = eventZone
	local eventZoneStroke = Instance.new("UIStroke")
	eventZoneStroke.Thickness = 1.5
	eventZoneStroke.Parent = eventZone
	local eventGlyph = glyph(dynamic, "⚔", MAP.event, Vector2.zero, MARKER + 2, 6)
	eventGlyph.Visible = false
	onPlate(eventGlyph, Theme.tint(MAP.event))
	-- S149b: the live world boss (in the disc) and the arrow towards it (out of the disc)
	local bossGlyph = glyph(dynamic, ICONS.worldBoss.glyph, ICONS.worldBoss.color, Vector2.zero, 22, 7)
	bossGlyph.Visible = false
	UiArtState.decorate(bossGlyph, UiArt.mapIcon("worldboss"), { size = 22 })
	local bossArrow = glyph(dynamic, "▲", ICONS.worldBoss.color, Vector2.zero, 16, 8)
	bossArrow.TextStrokeTransparency = 0
	bossArrow.Visible = false
	-- S159w: the wandering merchant's caravan while a visit runs on this map (an arrow on the edge when it is off the disc)
	local merchantGlyph = glyph(dynamic, "⚖", WanderingMerchant.Data.look.canvas, Vector2.zero, 18, 7)
	merchantGlyph.Visible = false
	local merchantArrow = glyph(dynamic, "▲", WanderingMerchant.Data.look.canvas, Vector2.zero, 14, 8)
	merchantArrow.TextStrokeTransparency = 0
	merchantArrow.Visible = false
	local partyPool: { TextLabel } = {}
	for i = 1, 4 do
		partyPool[i] = glyph(dynamic, "●", MAP.party, Vector2.zero, MARKER - 2, 5)
		partyPool[i].Visible = false
		onPlate(partyPool[i], Theme.tint(MAP.party))
		UiArtState.decorate(partyPool[i], UiArt.mapIcon("party"), { size = NODE_ART + 2 })
	end
	-- S78: Elites beyond the disc (Scout's Eye), nearest first.
	local elitePins: { TextLabel } = {}
	for i = 1, ELITE_PINS do
		local pin = glyph(dynamic, "▲", MAP.label, Vector2.zero, 14, 7)
		pin.TextColor3 = Theme.Brass.Bright
		pin.TextStrokeTransparency = 0.3
		pin.Visible = false
		elitePins[i] = pin
	end
	local dotPool: { Frame } = {}
	for i = 1, MONSTER_DOTS do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.ZIndex = 4
		dot.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = dot
		-- W28: a dark rim so the dot reads on light and dark ground alike
		local rim = Instance.new("UIStroke")
		rim.Name = "Rim"
		rim.Color = DOT_OUTLINE
		rim.Thickness = 1.5
		rim.Transparency = 0.15
		rim.Parent = dot
		dot.Parent = dynamic
		dotPool[i] = dot
	end

	local current: MapSketch.Sketch? = nil
	-- Owner 2026-10-20 "Mapa": the world map's filter (hidden categories) applies here too.
	local hideSetting = State.Value({ "account", "settings", "mapHide" })
	local hidden = scope:Computed(function(use): { [string]: boolean }
		return MapMarkers.hiddenSet(use(hideSetting))
	end)
	local redrawNow: () -> ()
	local currentScale = 0
	local currentMap = ""
	local currentLevel = 0
	local paintedShown = false -- S119: whether the disc shows the painted map (repaint only when this flips)
	local level = State.Value({ "character", "level" })
	-- S78: own Scout's Eye from narrow branches only (`character` changes with every HP change, as UI/GroupLuck).
	local pathState = State.Value({ "character", "path" })
	local equipment = State.Value({ "character", "equipment" })
	local classId = State.Value({ "character", "class" })
	local ownBonus = scope:Computed(function(use): number
		local class, lv = use(classId), use(level)
		if type(class) ~= "string" or type(lv) ~= "number" then
			return 0
		end
		local char = { class = class, level = lv, path = use(pathState) }
		local hooks = Paths.passiveTotals(char, Paths.weaponTypesOf(use(equipment))).hooks
		return math.floor((hooks.minimapEliteBonus or 0) + 0.5)
	end)

	local function redraw(force: boolean?)
		local id = Fusion.peek(mapId) or ""
		local s = Fusion.peek(scale)
		local playerLevel = Fusion.peek(level) or 1
		if not force and id == currentMap and s == currentScale and playerLevel == currentLevel and current then
			return
		end
		currentLevel = playerLevel
		for _, child in canvas:GetChildren() do
			if child ~= dynamic then
				child:Destroy()
			end
		end
		currentMap, currentScale = id, s
		paintedShown = false
		current = MapSketch.get(id)
		local sketch = current
		if not sketch then
			return
		end
		canvas.Size = UDim2.fromOffset(sketch.size.x * s, sketch.size.z * s)
		-- S119: the painted map in the sketch's place once loaded (same frame as the world map), else the sketch.
		local frame = UiArt.mapFrame(id)
		local paintedKey = UiArt.map(id)
		UiArtState.ensureKey(if frame then paintedKey else nil)
		local look = if frame then UiArtState.lookNow(paintedKey) else nil
		paintedShown = frame ~= nil and look ~= nil
		if frame and look then
			local corner = MapSketch.toPixel(sketch, s, frame.x0, frame.z0)
			local image = Instance.new("ImageLabel")
			image.Name = "Painted"
			image.Position = UDim2.fromOffset(corner.X, corner.Y)
			image.Size = UDim2.fromOffset(frame.size * s, frame.size * s)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Stretch
			image.ZIndex = 1
			UiArtState.apply(image, look)
			image.Parent = canvas
		else
			MapSketch.draw(canvas, sketch, s)
		end
		-- Monster areas tinted by level difference (S20; S22: band of the nearest end of the range, ~30% fill,
		-- level ranges at the closest zoom), under the icons.
		local data = Areas.byMap[id]
		local closest = s >= ZOOMS[#ZOOMS]
		local hide = Fusion.peek(hidden)
		local levelLabels: { { area: Areas.Area, a1: Vector2, a2: Vector2, color: Color3 } } = {}
		for _, area in (if data and not hide.area then data.areas else {}) :: { Areas.Area } do
			local r = area.rect
			local a1 = MapSketch.toPixel(sketch, s, r[1], r[2])
			local a2 = MapSketch.toPixel(sketch, s, r[3], r[4])
			local color = Theme.tint(LevelBand.COLORS[AreaAdvice.bandOf(area, playerLevel)])
			local f = Instance.new("Frame")
			f.Name = "Area"
			f.Position = UDim2.fromOffset(a1.X + 1, a1.Y + 1)
			f.Size = UDim2.fromOffset(a2.X - a1.X - 2, a2.Y - a1.Y - 2)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = 0.7
			f.BorderSizePixel = 0
			f.ZIndex = 1
			f.Parent = canvas
			if closest then
				table.insert(levelLabels, { area = area, a1 = a1, a2 = a2, color = color })
			end
		end
		-- Fixed symbols: one candidate per thing, decluttered like the world map (Logic/MapMarkers.layout).
		local marks = Fusion.peek(NpcMarkState.Marks)
		local candidates: { [string]: Candidate } = {}
		local points: { MapMarkers.Point } = {}
		local function add(c: Candidate)
			if hide[c.category] then
				return
			end
			candidates[c.key] = c
			table.insert(points, { key = c.key, x = c.p.X, y = c.p.Y, priority = c.priority })
		end
		for i, icon in sketch.icons do
			local category = SKETCH_CATEGORY[icon.t]
			if category and (category ~= "node" or s >= ZOOMS[2]) then
				local family = if icon.id then string.match(icon.id, "^(%a+)_") else nil
				add({
					key = `{icon.t}:{i}`,
					category = category,
					glyph = (ICONS[icon.t] or ICONS.node).glyph,
					art = UiArt.mapIcon(icon.t, family),
					color = if category == "node"
						then Theme.tint(
							if family == "bush" then MAP.bush elseif family == "fishing" then MAP.fishing else MAP.vein
						)
						else nil,
					p = MapSketch.toPixel(sketch, s, icon.x, icon.z),
					priority = PRIORITY[category],
				})
			end
		end
		-- S134i: the Elite II hideouts from the data (the living Elites nearby get their markers as before)
		for _, lair in (if data then data.lairs or {} else {}) :: { Areas.Lair } do
			add({
				key = `lair:{lair.id}`,
				category = "lair",
				glyph = ICONS.lair.glyph,
				art = UiArt.mapIcon("lair"),
				p = MapSketch.toPixel(sketch, s, lair.x, lair.z),
				priority = PRIORITY.lair,
			})
		end
		for _, npc in Npcs.list do
			-- S104: NPCs the character does not see yet are left out
			if npc.map == id and not npc.decoration and not NpcMarkState.isHidden(npc.id) then
				local mark = marks[npc.id]
				add({
					key = `npc:{npc.id}`,
					category = MapMarkers.npcCategory(npc.services :: any, mark ~= nil),
					glyph = npc.icon,
					art = UiArt.serviceOfNpc(npc),
					p = MapSketch.toPixel(sketch, s, npc.position.x, npc.position.z),
					priority = PRIORITY.npc + (if mark then 12 else 0),
					mark = mark,
				})
			end
		end
		-- S149b: the world boss's barrow (fixed, faded: the live boss has its own marker)
		if id == WorldBoss.Data.map then
			local arena = WorldBoss.spot()
			add({
				key = "worldboss",
				category = "worldboss",
				glyph = ICONS.worldBoss.glyph,
				art = UiArt.mapIcon("worldboss"),
				p = MapSketch.toPixel(sketch, s, arena.x, arena.z),
				priority = PRIORITY.worldboss,
				faded = true,
			})
		end
		local function symbol(c: Candidate, at: Vector2)
			local small = c.category == "node"
			local side = if small then NODE_SYMBOL else SYMBOL
			local color = c.color or MapSymbol.color(c.category)
			local holderFrame = Instance.new("Frame")
			holderFrame.Name = c.key
			holderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			holderFrame.Position = UDim2.fromOffset(at.X, at.Y)
			holderFrame.Size = UDim2.fromOffset(side, side)
			holderFrame.BackgroundTransparency = 1
			holderFrame.ZIndex = 2
			holderFrame.Parent = canvas
			local def = MapMarkers.byId[c.category]
			local plate = MapSymbol.plate(holderFrame, if def then def.shape else "round", side, color, 2)
			if c.faded then
				plate.BackgroundTransparency = 0.4
			end
			local label = glyph(holderFrame, c.glyph, MAP.npc, Vector2.new(side / 2, side / 2), side - 4, 3)
			label.TextColor3 = color
			if c.faded then
				label.TextTransparency = 0.35
			end
			UiArtState.decorate(label, c.art, { tint = color, size = if small then NODE_ART else SYMBOL_ART })
			local style = NpcMarkState.style(c.mark)
			if style then
				-- the quest mark as a badge on the plate's upper right (S25)
				local badge = glyph(holderFrame, style.text, MAP.quest, Vector2.new(side - 1, 1), 13, 4)
				badge.TextColor3 = style.color
				badge.FontFace = Theme.Fonts.Display
				badge.TextStrokeTransparency = 0
			end
		end
		local layout = MapMarkers.layout(points, 1, { size = SYMBOL, spread = closest })
		local obstacles: { { x: number, y: number } } = {}
		for key, at in layout.placed do
			symbol(candidates[key], Vector2.new(at.x, at.y))
			table.insert(obstacles, at)
		end
		-- a crowd shows its most important symbol at its centre (no room on the disc for a count badge)
		for _, group in layout.clusters do
			symbol(candidates[group.members[1]], Vector2.new(group.x, group.y))
			table.insert(obstacles, { x = group.x, y = group.y })
		end
		-- level ranges (closest zoom) only where they cover no symbol
		for _, entry in levelLabels do
			local text = `{entry.area.lv[1]}–{entry.area.lv[2]}`
			local w = MapMarkers.textWidth(text, Theme.TextSize.Caption) + 4
			local rect = { x0 = entry.a1.X, y0 = entry.a1.Y, x1 = entry.a2.X, y1 = entry.a2.Y }
			local spot, cx, cy = MapMarkers.placeLabel(rect, w, Theme.TextSize.Caption, 1, obstacles, SYMBOL)
			if spot and cx and cy then
				local levels = glyph(canvas, text, MAP.label, Vector2.new(cx, cy), 16, 2)
				levels.TextScaled = false
				levels.TextSize = Theme.TextSize.Caption
				levels.Size = UDim2.fromOffset(w, Theme.TextSize.Caption + 2)
				levels.TextColor3 = entry.color
				levels.TextStrokeTransparency = 0.1
			end
		end
	end
	redrawNow = function()
		redraw(true)
	end
	scope:Observer(NpcMarkState.Marks):onChange(redrawNow) -- quest marks change categories and priorities
	scope:Observer(NpcMarkState.Hidden):onChange(redrawNow)
	scope:Observer(hidden):onChange(redrawNow)

	scope:Observer(mapId):onChange(redraw)
	scope:Observer(scale):onChange(redraw)
	scope:Observer(level):onChange(redraw)
	-- S119: redraw only when this map's painted picture appears or goes (its file loaded, /icons glyph | art);
	-- other pictures loading (portraits, banners) leave the disc alone, the decorated icons refresh themselves.
	local function repaint()
		local shown = UiArt.mapFrame(currentMap) ~= nil and UiArtState.lookNow(UiArt.map(currentMap)) ~= nil
		if shown ~= paintedShown then
			currentMap = ""
			redraw()
		end
	end
	scope:Observer(UiArtState.Loaded):onChange(repaint)
	scope:Observer(IconState.Mode):onChange(repaint)

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
				local heading = math.deg(math.atan2(look.X, -look.Z))
				-- The arrow shows where the character faces (S19), not the camera.
				local facing = root.CFrame.LookVector
				local characterHeading = math.deg(math.atan2(facing.X, -facing.Z))
				if Fusion.peek(rotating) == true then
					holder.Rotation = -heading
					arrowRotation:set(characterHeading - heading)
					local angle = math.rad(-heading)
					local r = SIZE / 2 - 12
					northPosition:set(UDim2.new(0.5, math.sin(angle) * r, 0.5, -math.cos(angle) * r))
				else
					holder.Rotation = 0
					arrowRotation:set(characterHeading)
					northPosition:set(UDim2.new(0.5, 0, 0, 12))
				end
			end
			accumulator += dt
			if accumulator < 0.4 then
				return
			end
			accumulator = 0
			local offset = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
			local function at(x: number, z: number): Vector2
				return MapSketch.toPixel(sketch, currentScale, x, z)
			end
			-- Quest target (S11)
			local target = Fusion.peek(QuestTrack.Target)
			local hide = Fusion.peek(hidden)
			local showQuest = not hide.objective
				and target ~= nil
				and target.map == currentMap
				and target.x ~= nil
				and target.z ~= nil
				and Fusion.peek(QuestTrack.Tracked) == true
			questStar.Visible = showQuest
			if showQuest and target and target.x and target.z then
				local p = at(target.x, target.z)
				questStar.Position = UDim2.fromOffset(p.X, p.Y)
			end
			-- Guide target (S25): the target itself, or an arrow on the edge when it is out of view / elsewhere.
			local nav = Fusion.peek(NavTarget.Target)
			local navPoint: Vector2? = nil
			if nav then
				if nav.map == currentMap then
					navPoint = at(nav.x, nav.z)
				else
					local exit = MapRoute.nextExit(currentMap, nav.map, MapSketch.isBuilt)
					if exit then
						navPoint = at(exit.x, exit.z)
					end
				end
			end
			local inView = navPoint ~= nil and (navPoint - pixel).Magnitude <= EDGE
			navGlyph.Visible = navPoint ~= nil and nav ~= nil and nav.map == currentMap and inView
			navArrow.Visible = navPoint ~= nil and not navGlyph.Visible
			if navPoint then
				if navGlyph.Visible then
					navGlyph.Position = UDim2.fromOffset(navPoint.X, navPoint.Y)
				else
					local direction = navPoint - pixel
					if direction.Magnitude > 0.01 then
						local unit = direction.Unit
						local edge = pixel + unit * math.min(EDGE, direction.Magnitude)
						navArrow.Position = UDim2.fromOffset(edge.X, edge.Y)
						navArrow.Rotation = math.deg(math.atan2(unit.X, -unit.Y))
					end
				end
			end
			-- Own marks (S25)
			local marks = State.Get({ "character", "mapMarks" })
			local usedMarks = 0
			if type(marks) == "table" and not hide.mark then
				for _, mark in marks do
					if mark.map == currentMap and usedMarks < MAX_MARKS then
						usedMarks += 1
						local label = markPool[usedMarks]
						local icon = MapMarks.get(mark.icon)
						label.Text = if icon then icon.glyph else "⚑"
						label.TextColor3 = if icon then Theme.tint(icon.color) else Theme.Brass.Bright
						UiArtState.retarget(label, if icon then UiArt.mark(icon.id) else nil, label.TextColor3)
						ringOf(label, label.TextColor3)
						local p = at(mark.x, mark.z)
						label.Position = UDim2.fromOffset(p.X, p.Y)
						label.Visible = true
					end
				end
			end
			for i = usedMarks + 1, MAX_MARKS do
				markPool[i].Visible = false
			end
			-- Party members (blue dots)
			local party = State.Get({ "party" })
			local usedParty = 0
			if type(party) == "table" and not hide.party then
				for _, member in party.members do
					if
						member.id ~= Players.LocalPlayer.UserId
						and member.map == currentMap
						and usedParty < #partyPool
					then
						usedParty += 1
						local p = at(member.x - map.offset.x, member.z - map.offset.z)
						partyPool[usedParty].Position = UDim2.fromOffset(p.X, p.Y)
						partyPool[usedParty].Visible = true
					end
				end
			end
			for i = usedParty + 1, #partyPool do
				partyPool[i].Visible = false
			end
			-- S101: the world event
			local event = State.Get({ "worldEvent" })
			local eventDef = if not hide.event
					and type(event) == "table"
					and event.map == currentMap
				then WorldEvents.kindOf(event.kind)
				else nil
			local eventPoint = if eventDef and type(event) == "table" then at(event.x, event.z) else nil
			eventGlyph.Visible = eventPoint ~= nil and (eventPoint - pixel).Magnitude <= EDGE
			local zone = if eventPoint and type(event) == "table" then tonumber(event.zone) else nil
			eventZone.Visible = zone ~= nil
			if eventDef and eventPoint and zone and type(event) == "table" then
				local size = math.max(6, (at(event.x + zone, event.z) - eventPoint).Magnitude * 2)
				local tint = Theme.tint(eventDef.color)
				eventZone.Position = UDim2.fromOffset(eventPoint.X, eventPoint.Y)
				eventZone.Size = UDim2.fromOffset(size, size)
				eventZone.BackgroundColor3 = tint
				eventZoneStroke.Color = tint
				eventZoneStroke.Transparency = if event.phase == "warn" then 0.5 else 0.1
			end
			if eventDef and eventPoint and type(event) == "table" then
				eventGlyph.Position = UDim2.fromOffset(eventPoint.X, eventPoint.Y)
				eventGlyph.Text = eventDef.glyph
				eventGlyph.TextColor3 = Theme.tint(eventDef.color)
				ringOf(eventGlyph, eventGlyph.TextColor3)
				eventGlyph.TextTransparency = if event.phase == "warn" then 0.4 else 0
			end
			-- S149b: the world boss while it wakes, fights or has just fallen
			local boss = WorldBoss.markerOf(State.Get({ "worldBoss" }), Clock.now())
			local bossPoint = if WorldBoss.markerLive(boss) and boss.map == currentMap then at(boss.x, boss.z) else nil
			local bossIn = bossPoint ~= nil and (bossPoint - pixel).Magnitude <= EDGE
			bossGlyph.Visible = bossIn
			bossArrow.Visible = bossPoint ~= nil and not bossIn
			if bossPoint then
				local fade = if boss.state == "active" then 0 elseif boss.state == "warn" then 0.35 else 0.55
				if bossIn then
					bossGlyph.Position = UDim2.fromOffset(bossPoint.X, bossPoint.Y)
					bossGlyph.TextTransparency = fade
				else
					local direction = bossPoint - pixel
					if direction.Magnitude > 0.01 then
						local unit = direction.Unit
						local edge = pixel + unit * EDGE
						bossArrow.Position = UDim2.fromOffset(edge.X, edge.Y)
						bossArrow.Rotation = math.deg(math.atan2(unit.X, -unit.Y))
						bossArrow.TextTransparency = fade
					end
				end
			end
			-- S159w: the wandering merchant
			local visit = WanderingMerchant.current(Clock.now())
			local merchantPoint = if visit
					and not hide.shop
					and visit.spot.map == currentMap
				then at(visit.spot.x, visit.spot.z)
				else nil
			local merchantIn = merchantPoint ~= nil and (merchantPoint - pixel).Magnitude <= EDGE
			merchantGlyph.Visible = merchantIn
			merchantArrow.Visible = merchantPoint ~= nil and not merchantIn
			if merchantPoint then
				if merchantIn then
					merchantGlyph.Position = UDim2.fromOffset(merchantPoint.X, merchantPoint.Y)
				else
					local direction = merchantPoint - pixel
					if direction.Magnitude > 0.01 then
						local unit = direction.Unit
						local edge = pixel + unit * EDGE
						merchantArrow.Position = UDim2.fromOffset(edge.X, edge.Y)
						merchantArrow.Rotation = math.deg(math.atan2(unit.X, -unit.Y))
					end
				end
			end
			-- Monsters nearby (S19: normal ones in the colour of their group size, elites gold).
			-- S78: Elites up to MONSTER_RANGE + the Scout's Eye bonus; beyond the disc they get edge markers.
			local eliteBonus = ScoutRange.bonus(
				Fusion.peek(ownBonus),
				if type(party) == "table" then party.members else nil,
				Players.LocalPlayer.UserId,
				currentMap,
				root.Position.X,
				root.Position.Z,
				PathData.HOOK_RULES.scoutEye.shareRange
			)
			local usedDots = 0
			local pins: { { distance: number, unit: Vector2, size: number } } = {}
			local monsters = Workspace:FindFirstChild("Monsters")
			if monsters then
				for _, model in monsters:GetChildren() do
					if usedDots >= MONSTER_DOTS then
						break
					end
					if model:IsA("Model") and model:GetAttribute("Dead") ~= true then
						local pivot = model:GetPivot().Position
						local variant = model:GetAttribute("Variant")
						local elite = variant == "elite" or variant == "elite2"
						local distance = (pivot - root.Position).Magnitude
						if distance <= MONSTER_RANGE + (if elite then eliteBonus else 0) then
							local local_ = pivot - offset
							local p = at(local_.X, local_.Z)
							local direction = p - pixel
							if elite and eliteBonus > 0 and direction.Magnitude > EDGE then
								table.insert(pins, {
									distance = distance,
									unit = direction.Unit,
									size = if variant == "elite2" then 17 else 14,
								})
							else
								usedDots += 1
								-- W28: bigger dots (were 6 / 9 / 12) in the family's colour, elites ringed in gold
								local size = if variant == "elite2" then 16 elseif variant == "elite" then 12 else 9
								local dot = dotPool[usedDots]
								dot.Position = UDim2.fromOffset(p.X, p.Y)
								dot.Size = UDim2.fromOffset(size, size)
								dot.BackgroundColor3 = familyColor(model)
									or GroupColors.of(model:GetAttribute("GroupSize") :: number?)
								local rim = dot:FindFirstChild("Rim") :: UIStroke?
								if rim then
									local elite = variant == "elite" or variant == "elite2"
									rim.Color = if elite then Theme.Iron.Selected else DOT_OUTLINE
									rim.Thickness = if variant == "elite2" then 3 elseif elite then 2.5 else 1.5
								end
								dot.Visible = true
							end
						end
					end
				end
			end
			for i = usedDots + 1, MONSTER_DOTS do
				dotPool[i].Visible = false
			end
			table.sort(pins, function(a, b): boolean
				return a.distance < b.distance
			end)
			for i, pin in elitePins do
				local entry = pins[i]
				pin.Visible = entry ~= nil
				if entry then
					local edge = pixel + entry.unit * EDGE
					pin.Position = UDim2.fromOffset(edge.X, edge.Y)
					pin.Size = UDim2.fromOffset(entry.size, entry.size)
					pin.Rotation = math.deg(math.atan2(entry.unit.X, -entry.unit.Y))
				end
			end
		end)
	)

	local mailCount = scope:Computed(function(use): number
		local mail = use(State.Value({ "mail" }))
		return if type(mail) == "table" then mail.count or 0 else 0
	end)
	local function mailButton(): Instance
		local art = UiArt.hud("mail")
		local artShown = ArtIcon.Shown(scope, art)
		return scope:New("TextButton")({
			Name = "MailEnvelope",
			Position = UDim2.fromOffset(0, 0),
			-- W29: the minimap is scaled to MINIMAP_SCALE on a phone in landscape; the envelope grows so it stays a
			-- MinTouch target there
			Size = PhoneLayout.Pick(
				scope,
				UDim2.fromOffset(MAIL_PHONE, MAIL_PHONE),
				UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch)
			),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			Visible = scope:Computed(function(use): boolean
				return use(mailCount) > 0
			end),
			Text = scope:Computed(function(use): string
				return if use(artShown) then "" else "✉"
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Brass.Bright,
			[OnEvent("Activated")] = function()
				props.ShowWindow("mail")
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				ArtIcon.Image(scope, {
					Key = art,
					Tint = Theme.Brass.Bright,
					Size = UDim2.fromOffset(28, 28),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
				}),
				scope:New("TextLabel")({
					Name = "Count",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(22, 22),
					BackgroundColor3 = Theme.Iron.Danger,
					Text = scope:Computed(function(use): string
						local n = use(mailCount)
						return if n > 9 then "9+" else tostring(n)
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }) },
				}),
			},
		})
	end

	local function zoomButton(text: string, delta: number, order: number): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.fromOffset(Theme.Size.MinTouch, Theme.Size.MinTouch),
			BackgroundColor3 = Theme.Iron.Surface,
			BackgroundTransparency = Theme.HudAlpha,
			Text = text,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Iron.Text,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				scope:New("UIStroke")({ Color = Theme.Brass.Line, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
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
			PhoneLayout.UIScale(scope, "minimap"), -- W29
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
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					holder,
					-- S25: click / tap = the world map, centred on the player.
					scope:New("TextButton")({
						Name = "OpenMap",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 9,
						[OnEvent("Activated")] = function()
							NavTarget.MapFocus:set({ zoom = 2 })
							props.ShowWindow("map")
						end,
					}),
					scope:New("TextLabel")({
						Name = "Player",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(22, 22),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return if UiArtState.ready(use, PLAYER_ART) then "" else "▲"
						end),
						TextScaled = true,
						TextColor3 = Theme.Iron.Link,
						TextStrokeTransparency = 0,
						Rotation = arrowRotation,
						ZIndex = 10,
						-- S119: the player silhouette (turns with the label) once loaded.
						[Children] = ArtIcon.Image(scope, { Key = PLAYER_ART, Tint = Theme.Iron.Link, ZIndex = 10 }),
					}),
					scope:New("TextLabel")({
						Name = "North",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = northPosition,
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						Text = "N",
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Iron.Heading,
						ZIndex = 10,
					}),
				},
			}),
			-- S136: the brass frame around the disc
			scope:New("Frame")({
				Name = "Frame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -SIZE / 2, 0, SIZE / 2),
				Size = UDim2.fromOffset(SIZE + 6, SIZE + 6),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({ Thickness = Theme.Size.FrameOuter, Color = Theme.Brass.Frame }),
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
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
					scope:New("UIStroke")({
						Thickness = Theme.Stroke.Thick,
						Color = scope:Computed(function(use): Color3
							local z = use(zone)
							return if type(z) == "table"
								then ZONE_COLORS[z.pvp] or Theme.Iron.Heading
								else Theme.Iron.Heading
						end),
					}),
				},
			}),
			-- S156 (owner: the envelope floated in the middle of the top edge): unread parcels as a round button in the
			-- free corner left of the disc, above the zoom buttons
			mailButton(),
			scope:New("Frame")({
				Name = "Zoom",
				-- W29: no zoom buttons on a phone in landscape (scaled they would be under MinTouch; the map window zooms)
				Visible = PhoneLayout.Pick(scope, false, true),
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, SIZE - 2 * Theme.Size.MinTouch - 6),
				Size = UDim2.fromOffset(Theme.Size.MinTouch, 2 * Theme.Size.MinTouch + 6),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					zoomButton("+", 1, 1),
					zoomButton("−", -1, 2),
				},
			}),
			-- Current monster area under the map name (S20), S33: with its profile's icon.
			scope:New("TextLabel")({
				Name = "AreaName",
				RichText = true,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 1, 2),
				Size = UDim2.fromOffset(SIZE + 30, 22),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return use(AreaState.Current) ~= nil
				end),
				Text = scope:Computed(function(use): string
					local area = use(AreaState.Current)
					if not area then
						return ""
					end
					return AreaProfileText.escape(
						Text.get(
							use,
							"area.label",
							{ name = Text.get(use, area.nameKey), min = area.lv[1], max = area.lv[2] }
						)
					) .. AreaProfileText.iconRich(area.profile, " ", "iron")
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local area = use(AreaState.Current)
					if not area then
						return Theme.Iron.Text
					end
					return Theme.readable(LevelBand.COLORS[AreaAdvice.bandOf(area, use(level) or 1)], "iron")
				end),
				TextStrokeTransparency = 0.2,
			}),
			scope:New("TextLabel")({
				Name = "MapName",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromOffset(SIZE + 30, 36),
				BackgroundColor3 = Theme.Iron.Surface,
				BackgroundTransparency = Theme.HudAlpha,
				Text = scope:Computed(function(use): string
					local z = use(zone)
					local map = Maps.get(use(mapId) or "")
					if type(z) == "table" and z.nameKey then
						return Text.get(use, AreaState.zoneNameKey(z, if map then map.nameKey else nil))
					end
					return if map then Text.get(use, map.nameKey) else ""
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Thin,
						Color = Theme.Brass.Line,
					}),
				},
			}),
		},
	})
end

return Minimap
