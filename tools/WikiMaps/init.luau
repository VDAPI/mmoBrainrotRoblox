--!strict
-- Wiki map SVGs (S37, docs/WIKI.md): build(opts) -> { files = { [name]: svg }, stats } for the city, the four
-- regions, the twelve caves and the world overview, drawn from the same shared data as the game's map (Data/Areas,
-- Data/Maps, Data/Portals, Data/Npcs, Data/Spawns, Logic/TownSketch, Logic/CaveGen, Logic/AreaSpawns). Pure: the CLI
-- tools/wikimap.luau writes the files, tests/wikimap.spec.luau checks them.
--
-- Every file: viewBox in map studs (x right, z down = north up like the game), layers <g id="layer-…"> in a fixed
-- order, interactive elements with id + data-id (area-, cave-, portal-, npc-, group-, boss-, node-, link-), label
-- pairs <text lang="pl|en"> with level-of-detail classes lod-1..3, markers in screen pixels scaled by --k.

local Areas = require("../src/shared/Data/Areas")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Bosses = require("../src/shared/Data/Bosses")
local CaveGen = require("../src/shared/Logic/CaveGen")
local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local Clean = require("./WikiData/Clean")
local WorldGen = require("../src/shared/Logic/WorldGen")
local Monsters = require("../src/shared/Data/Monsters")
local Names = require("./WikiData/Names")
local Npcs = require("../src/shared/Data/Npcs")
local Places = require("./WikiData/Places")
local Portals = require("../src/shared/Data/Portals")
local Svg = require("@self/Svg")
local TownSketch = require("../src/shared/Logic/TownSketch")
local Visibility = require("./WikiData/Visibility")
local World = require("./WikiData/World")

local WikiMap = {}

WikiMap.OUT_DIR = "wiki/public/img/maps"
WikiMap.WORLD = { w = 1600, h = 950, margin = 0.08 }
-- Size budgets in bytes (docs/WIKI.md, S37).
WikiMap.BUDGET = { region = 120000, city = 150000, cave = 60000, world = 60000 }
-- Default on-screen width the --k fallback assumes (a file opened on its own).
WikiMap.VIEW_PX = 900

local FALLBACK_BG = "#3A3A3A"

export type Opts = { readText: ((path: string) -> string?)?, only: { string }? }

type Ctx = {
	maps: { [string]: any },
	colors: { [string]: string },
	placements: { [string]: { any } },
	groups: { [string]: { any } },
	areaNames: { [string]: any },
	profiles: { [string]: string },
	warnings: { string },
}

local function color(ctx: Ctx, token: string): string
	return `var(--vw-map-{token},{ctx.colors[token] or FALLBACK_BG})`
end

local function header(w: number, h: number, x0: number, z0: number, id: string, k: number, title: any): { string }
	return {
		`<svg xmlns="http://www.w3.org/2000/svg" viewBox="{Svg.n(x0)} {Svg.n(z0)} {Svg.n(w)} {Svg.n(h)}" `
			.. `data-map="{Svg.esc(id)}" class="vw-mapsvg" role="img">`,
		Svg.el("title", nil, `{title.pl} / {title.en}`),
		Svg.style(k),
	}
end

local function layer(name: string, children: { string }, cls: string?): string
	return Svg.group({ { "id", `layer-{name}` }, { "class", cls } }, children)
end

local function nameOf(key: string): any
	return Names.of(key)
end

local function levels(min: number, max: number): string
	return if min == max then tostring(min) else `{min}–{max}`
end

-- Shared parts ---------------------------------------------------------------------------------------------------

local function background(ctx: Ctx, map: any): string
	local sx, sz = map.size.x, map.size.z
	return layer("bg", {
		Svg.el("rect", {
			{ "class", "m-bg" },
			{ "x", Svg.n(-sx / 2) },
			{ "y", Svg.n(-sz / 2) },
			{ "width", Svg.n(sx) },
			{ "height", Svg.n(sz) },
			{ "style", `fill:{color(ctx, "bg-" .. map.biome)}` },
		}),
	})
end

local function shade(map: any): string
	local sx, sz = map.size.x, map.size.z
	return Svg.el("rect", {
		{ "class", "m-shade" },
		{ "x", Svg.n(-sx / 2) },
		{ "y", Svg.n(-sz / 2) },
		{ "width", Svg.n(sx) },
		{ "height", Svg.n(sz) },
	})
end

local function portalShape(kind: string): (string, number)
	if kind == "portal" then
		return "arch", 7
	elseif kind == "gate" then
		return "square", 6
	elseif kind == "dungeon" then
		return "diamond", 8
	end
	return "square", 5
end

local function portalMarkers(ctx: Ctx, mapId: string): { string }
	local out = {}
	for _, p in Portals.list do
		if p.map == mapId and p.kind ~= "cave" and ctx.maps[p.target] then
			local shape, r = portalShape(p.kind)
			table.insert(
				out,
				Svg.marker({
					id = `portal-{p.id}`,
					dataId = p.id,
					x = p.x,
					z = p.z,
					cls = `m-{p.kind}`,
					shape = shape,
					r = r,
					name = ctx.maps[p.target].name,
					labelCls = "lod-2",
					extra = { { "data-kind", p.kind }, { "data-target", p.target } },
				})
			)
		end
	end
	return out
end

local function npcMarkers(mapId: string): { string }
	local out = {}
	for _, n in Npcs.list do
		if n.map == mapId and not n.decoration then
			table.insert(
				out,
				Svg.marker({
					id = `npc-{n.id}`,
					dataId = n.id,
					x = n.position.x,
					z = n.position.z,
					cls = "m-npc",
					shape = "circle",
					r = 7,
					glyph = if n.icon ~= "" then n.icon else nil,
					name = nameOf(n.nameKey),
					labelCls = "lod-3",
				})
			)
		end
	end
	return out
end

local function groupMarkers(ctx: Ctx, mapId: string): { string }
	local out = {}
	for _, g in ctx.groups[mapId] or {} do
		local cls, shape, r, lod = "m-group", "circle", 3, "lod-3"
		if g.variant == "elite" then
			cls, shape, r, lod = "m-elite", "diamond", 6, "lod-2"
		elseif g.variant == "elite2" then
			cls, shape, r, lod = "m-elite2", "diamond", 9, "lod-1"
		end
		table.insert(
			out,
			Svg.marker({
				id = `group-{g.id}`,
				dataId = g.id,
				x = g.x,
				z = g.z,
				cls = `{cls} {lod}`,
				shape = shape,
				r = r,
				extra = { { "data-variant", g.variant }, { "data-area", g.area } },
			})
		)
	end
	return out
end

-- Region map --------------------------------------------------------------------------------------------------------

-- Forest patches of a generated region (S26 Meadows, S45 every map of Logic/WorldGen): 80-stud cells holding 3+ big
-- trees (like the game's map, S20).
local function forestPatches(gen: WorldGen.Generator): { string }
	local cells: { [string]: { x: number, z: number, n: number } } = {}
	for _, t in gen.trees() do
		local cx, cz = math.floor(t.x / 80), math.floor(t.z / 80)
		local key = `{cx},{cz}`
		local c = cells[key] or { x = 0, z = 0, n = 0 }
		c.x += t.x
		c.z += t.z
		c.n += 1
		cells[key] = c
	end
	local parts = {}
	for _, key in Clean.keys(cells) do
		local c = cells[key]
		if c.n >= 3 then
			table.insert(parts, Svg.circlePath(c.x / c.n, c.z / c.n, 34 + math.min(c.n, 12) * 2))
		end
	end
	return parts
end

-- Shapes of a sketch (TownSketch / MeadowsGen.sketch): one <path> per kind (fill) or kind and width (lines), in
-- the order each kind first appears.
local function sketchShapes(ctx: Ctx, shapes: { { [string]: any } }): { string }
	local order: { string } = {}
	local fills: { [string]: { string } } = {}
	local lines: { [string]: { string } } = {}
	for _, s in shapes do
		local kind = string.lower((string.gsub(string.gsub(s.c, "[:_]", "-"), "(%l)(%u)", "%1-%2")))
		if s.t == "line" then
			local key = `{kind}|{Svg.n(s.w)}`
			if not lines[key] then
				lines[key] = {}
				table.insert(order, "L" .. key)
			end
			table.insert(lines[key], Svg.polyline(s.p))
		else
			if not fills[kind] then
				fills[kind] = {}
				table.insert(order, "F" .. kind)
			end
			if s.t == "circle" then
				table.insert(fills[kind], Svg.circlePath(s.x, s.z, s.r))
			else
				table.insert(fills[kind], Svg.rectPath(s.x, s.z, s.w, s.h, s.r))
			end
		end
	end
	local out = {}
	for _, entry in order do
		local tag, key = string.sub(entry, 1, 1), string.sub(entry, 2)
		if tag == "F" then
			table.insert(
				out,
				Svg.el("path", {
					{ "class", `m-s m-s-{key}` },
					{ "d", table.concat(fills[key]) },
					{ "style", `fill:{color(ctx, key)}` },
				})
			)
		else
			local kind, w = string.match(key, "^(.-)|(.*)$")
			table.insert(
				out,
				Svg.el("path", {
					{ "class", `m-s m-s-{kind}` },
					{ "d", table.concat(lines[key]) },
					{
						"style",
						`fill:none;stroke:{color(ctx, kind :: string)};stroke-width:{w};stroke-linecap:round;stroke-linejoin:round`,
					},
				})
			)
		end
	end
	return out
end

local function gatherLayer(ctx: Ctx, mapId: string): { string }
	local out = {}
	local points: { [string]: { string } } = {}
	for i, p in ctx.placements[mapId] or {} do
		local family = string.match(p.kind, "^(%a+)_") or "vein"
		if p.rect then
			local r = p.rect
			table.insert(
				out,
				Svg.el("rect", {
					{ "class", `m-gather m-gather-rect m-{family} lod-2` },
					{ "x", Svg.n(math.min(r[1], r[3])) },
					{ "y", Svg.n(math.min(r[2], r[4])) },
					{ "width", Svg.n(math.abs(r[3] - r[1])) },
					{ "height", Svg.n(math.abs(r[4] - r[2])) },
					{ "data-kind", p.kind },
					{ "data-n", p.n },
					{ "data-i", i },
				})
			)
		elseif p.x and p.z then
			points[family] = points[family] or {}
			table.insert(points[family], Svg.circlePath(p.x, p.z, if family == "fishing" then 9 else 6))
		end
	end
	for _, family in Clean.keys(points) do
		table.insert(
			out,
			Svg.el("path", {
				{ "class", `m-gather-pt m-{family}` },
				{ "d", table.concat(points[family]) },
				{ "data-kind", family },
			})
		)
	end
	return out
end

-- Sketch kinds drawn under the water and the roads (terrain shapes of the generators).
local UNDER: { [string]: boolean } = {
	marsh = true,
	basin = true,
	ravine = true,
	ravineWall = true,
	plateau = true,
	cliff = true,
	-- S46
	drylake = true,
	["ground:Sand"] = true,
	dune = true,
	mesa = true,
}

local function region(ctx: Ctx, mapId: string): string
	local map = ctx.maps[mapId]
	local data = Areas.byMap[mapId]
	local sx, sz = map.size.x, map.size.z
	local out = header(sx, sz, -sx / 2, -sz / 2, mapId, sx / WikiMap.VIEW_PX, map.name)
	table.insert(out, background(ctx, map))
	-- forest and the generator's sketch (S26 Meadows, S45 every region of Logic/WorldGen); water and roads come from
	-- the data below, the terrain shapes of the sketch (marshes, hollows, gorges, cliffs) lie under them
	local gen = WorldGen.get(mapId)
	local under: { { [string]: any } } = {}
	local over: { { [string]: any } } = {}
	if gen then
		for _, s in gen.sketch() do
			if s.c == "water" or s.c == "path" then
				continue
			end
			table.insert(if UNDER[s.c] then under else over, s)
		end
	end
	if gen then
		local patches = forestPatches(gen)
		if #patches > 0 then
			table.insert(
				out,
				layer("forest", {
					Svg.el(
						"path",
						{
							{ "class", "m-s m-s-forest" },
							{ "d", table.concat(patches) },
							{ "style", `fill:{color(ctx, "forest")}` },
						}
					),
				})
			)
		end
	end
	if #under > 0 then
		table.insert(out, layer("terrain", sketchShapes(ctx, under)))
	end
	-- water
	local water = {}
	local lakes = {}
	for _, l in data.lakes do
		table.insert(lakes, Svg.circlePath(l.x, l.z, l.r))
	end
	if #lakes > 0 then
		table.insert(water, Svg.el("path", { { "class", "m-water" }, { "d", table.concat(lakes) } }))
	end
	for _, st in data.streams or {} do
		local total = 0
		for _, w in st.widths do
			total += w
		end
		table.insert(
			water,
			Svg.el("path", {
				{ "class", "m-stream" },
				{ "d", Svg.polyline(st.points) },
				{ "style", `stroke-width:{Svg.n(total / math.max(1, #st.widths))}` },
			})
		)
	end
	table.insert(out, layer("water", water))
	-- roads (one path per width)
	local byWidth: { [number]: { string } } = {}
	for _, r in data.roads do
		byWidth[r.width] = byWidth[r.width] or {}
		table.insert(byWidth[r.width], Svg.polyline(r.points))
	end
	local roads = {}
	for _, w in Clean.keys(byWidth) do
		table.insert(
			roads,
			Svg.el(
				"path",
				{ { "class", "m-road" }, { "d", table.concat(byWidth[w]) }, { "style", `stroke-width:{Svg.n(w)}` } }
			)
		)
	end
	table.insert(out, layer("roads", roads))
	if gen then
		table.insert(out, layer("sketch", sketchShapes(ctx, over)))
	end
	table.insert(out, shade(map))
	-- areas
	local areas, labels = {}, {}
	for _, a in data.areas do
		local r = a.rect
		local x1, z1 = math.min(r[1], r[3]) + 3, math.min(r[2], r[4]) + 3
		local w, h = math.abs(r[3] - r[1]) - 6, math.abs(r[4] - r[2]) - 6
		table.insert(
			areas,
			Svg.el("rect", {
				{ "id", `area-{a.id}` },
				{ "data-id", a.id },
				{ "class", "m-area" },
				{ "x", Svg.n(x1) },
				{ "y", Svg.n(z1) },
				{ "width", Svg.n(w) },
				{ "height", Svg.n(h) },
				{ "rx", "10" },
				{ "data-lv", `{a.lv[1]}-{a.lv[2]}` },
				{ "data-profile", a.profile },
			})
		)
		local profile = a.profile and ctx.profiles[a.profile]
		local lv = levels(a.lv[1], a.lv[2])
		table.insert(
			labels,
			Svg.group({
				{ "class", "m-al lod-1" },
				{ "data-for", `area-{a.id}` },
				{ "transform", `translate({Svg.n(x1 + w / 2)} {Svg.n(z1 + h / 2)})` },
			}, {
				Svg.group({ { "class", "k" } }, {
					Svg.label(ctx.areaNames[a.id], "m-alabel", 0, -3),
					Svg.el(
						"text",
						{ { "class", "m-alabel m-alv" }, { "y", "13" } },
						(if profile then profile .. " " else "") .. lv
					),
				}),
			})
		)
	end
	table.insert(out, layer("areas", areas))
	table.insert(out, layer("groups", groupMarkers(ctx, mapId)))
	table.insert(out, layer("gather", gatherLayer(ctx, mapId)))
	table.insert(out, layer("portals", portalMarkers(ctx, mapId)))
	local caves = {}
	for _, e in data.caves do
		local cave = Areas.caves.get(e.cave)
		if cave and ctx.maps[e.cave] then
			table.insert(
				caves,
				Svg.marker({
					id = `cave-{e.cave}`,
					dataId = e.cave,
					x = e.x,
					z = e.z,
					cls = "m-cave",
					shape = "diamond",
					r = 8,
					rot = e.rot,
					name = ctx.maps[e.cave].name,
					labelCls = "lod-2",
					extra = { { "data-target", e.cave } },
				})
			)
		end
	end
	table.insert(out, layer("caves", caves))
	table.insert(out, layer("npcs", npcMarkers(mapId)))
	table.insert(out, layer("bosses", {}))
	table.insert(out, layer("labels", labels))
	table.insert(out, "</svg>")
	return table.concat(out)
end

-- City ------------------------------------------------------------------------------------------------------------

local function city(ctx: Ctx): string
	local map = ctx.maps.city
	local sx, sz = map.size.x, map.size.z
	local out = header(sx, sz, -sx / 2, -sz / 2, "city", sx / WikiMap.VIEW_PX, map.name)
	table.insert(out, background(ctx, map))
	table.insert(out, layer("sketch", sketchShapes(ctx, TownSketch.shapes())))
	table.insert(out, shade(map))
	table.insert(out, layer("areas", {}))
	table.insert(out, layer("portals", portalMarkers(ctx, "city")))
	table.insert(out, layer("npcs", npcMarkers("city")))
	table.insert(out, layer("labels", {}))
	table.insert(out, "</svg>")
	return table.concat(out)
end

-- Caves -----------------------------------------------------------------------------------------------------------

-- Corridors of a hand-made boss cave are only in its server layout: join the rooms by a minimum spanning tree of
-- their centres (a schematic, docs/WIKI.md "Decyzje").
local function spanningTree(rooms: { any }): { any }
	local inTree = { [1] = true }
	local out = {}
	for _ = 2, #rooms do
		local best, bi, bj = math.huge, 0, 0
		for i in inTree do
			for j, b in rooms do
				if not inTree[j] then
					local a = rooms[i]
					local d = (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2
					if d < best then
						best, bi, bj = d, i, j
					end
				end
			end
		end
		if bj == 0 then
			break
		end
		inTree[bj] = true
		table.insert(out, { ax = rooms[bi].x, az = rooms[bi].z, bx = rooms[bj].x, bz = rooms[bj].z, w = 16 })
	end
	return out
end

local function cave(ctx: Ctx, caveId: string): string
	local map = ctx.maps[caveId]
	local def = Areas.caves.get(caveId) :: any
	local sx, sz = map.size.x, map.size.z
	local out = header(sx, sz, -sx / 2, -sz / 2, caveId, sx / 600, map.name)
	table.insert(out, background(ctx, map))
	local rooms = AreaSpawns.caveRooms(def)
	local corridors = if def.rooms or not def.seed then spanningTree(rooms) else CaveGen.generate(def.seed).corridors
	local floor = {}
	local byWidth: { [number]: { string } } = {}
	for _, c in corridors do
		byWidth[c.w] = byWidth[c.w] or {}
		table.insert(byWidth[c.w], Svg.polyline({ c.ax, c.az, c.bx, c.bz }))
	end
	for _, w in Clean.keys(byWidth) do
		table.insert(
			floor,
			Svg.el(
				"path",
				{ { "class", "m-corr" }, { "d", table.concat(byWidth[w]) }, { "style", `stroke-width:{Svg.n(w)}` } }
			)
		)
	end
	local water = {}
	local engine = CaveTerrain.get(caveId)
	if engine then
		-- S48: the real floor of a cave on the cave engine (merged cells of the outline) and its liquids
		floor = {}
		local d = {}
		for _, rect in engine.outline(8) do
			table.insert(
				d,
				`M{Svg.n(rect.x - rect.w / 2)} {Svg.n(rect.z - rect.d / 2)}h{Svg.n(rect.w)}v{Svg.n(rect.d)}h{Svg.n(-rect.w)}z`
			)
		end
		table.insert(floor, Svg.el("path", { { "class", "m-floor" }, { "d", table.concat(d) } }))
		local wd = {}
		for _, f in engine.shape.features do
			if f.kind == "pool" then
				table.insert(wd, Svg.circlePath(f.x, f.z, f.r))
			end
		end
		if #wd > 0 then
			table.insert(water, Svg.el("path", { { "class", "m-water" }, { "d", table.concat(wd) } }))
		end
	else
		local circles = {}
		for _, r in rooms do
			table.insert(circles, Svg.circlePath(r.x, r.z, r.r))
		end
		table.insert(floor, Svg.el("path", { { "class", "m-floor" }, { "d", table.concat(circles) } }))
	end
	table.insert(out, layer("water", water))
	table.insert(out, layer("roads", floor))
	table.insert(out, shade(map))
	local roomEls = {}
	for i, r in rooms do
		local kind = if i == 1 then "entrance" elseif def.boss and i == #rooms then "antechamber" else "room"
		table.insert(
			roomEls,
			Svg.el("circle", {
				{ "id", `room-{caveId}-{i}` },
				{ "class", `m-room m-room-{kind}` },
				{ "cx", Svg.n(r.x) },
				{ "cy", Svg.n(r.z) },
				{ "r", Svg.n(r.r) },
			})
		)
	end
	table.insert(out, layer("rooms", roomEls))
	table.insert(out, layer("groups", groupMarkers(ctx, caveId)))
	table.insert(out, layer("portals", portalMarkers(ctx, caveId)))
	local bosses = {}
	if def.boss then
		local boss = Bosses.forRegion(def.region)
		local gate = Portals.get(`dungeon_{def.region}`)
		if boss and gate then
			table.insert(
				bosses,
				Svg.marker({
					id = `boss-{boss.id}`,
					dataId = boss.id,
					x = gate.x - 24,
					z = gate.z + 40,
					cls = "m-boss",
					shape = "diamond",
					r = 11,
					glyph = "☠",
					name = Names.of(boss.nameKey),
					labelCls = "lod-1",
					extra = { { "data-target", `dungeon_{def.region}` } },
				})
			)
		end
	end
	table.insert(out, layer("npcs", {}))
	table.insert(out, layer("bosses", bosses))
	table.insert(out, layer("labels", {}))
	table.insert(out, "</svg>")
	return table.concat(out)
end

-- World -----------------------------------------------------------------------------------------------------------

-- Bounds of the world map positions (Maps.worldMap, 0..1); the overview stretches them to the whole canvas
-- (docs/WIKI.md "Decyzje", S37: the game's positions only use the middle of the square).
local bounds: { x1: number, y1: number, x2: number, y2: number }? = nil

function WikiMap.setBounds(maps: { [string]: any })
	local b = { x1 = math.huge, y1 = math.huge, x2 = -math.huge, y2 = -math.huge }
	for _, m in maps do
		local p = m.worldMap
		if p.x ~= 0 or p.y ~= 0 then
			b.x1, b.y1 = math.min(b.x1, p.x), math.min(b.y1, p.y)
			b.x2, b.y2 = math.max(b.x2, p.x), math.max(b.y2, p.y)
		end
	end
	bounds = b
end

function WikiMap.worldPos(pos: { x: number, y: number }): (number, number)
	local W = WikiMap.WORLD
	local b = bounds or { x1 = 0, y1 = 0, x2 = 1, y2 = 1 }
	local u = (pos.x - b.x1) / math.max(1e-6, b.x2 - b.x1)
	local v = (pos.y - b.y1) / math.max(1e-6, b.y2 - b.y1)
	return W.w * W.margin + u * W.w * (1 - 2 * W.margin), W.h * W.margin + v * W.h * (1 - 2 * W.margin)
end

local ZONE_GLOW = { green = "#5FCF6B", yellow = "#E8C25A", red = "#E0503F" }

local function world(ctx: Ctx): string
	local W = WikiMap.WORLD
	WikiMap.setBounds(ctx.maps)
	local out = header(W.w, W.h, 0, 0, "world", 1, { pl = "Mapa świata", en = "World map" })
	local defs = {}
	for _, zone in { "green", "yellow", "red" } do
		table.insert(
			defs,
			Svg.el("radialGradient", { { "id", `glow-{zone}` } }, {
				Svg.el("stop", { { "offset", "0" }, { "stop-color", ZONE_GLOW[zone] }, { "stop-opacity", ".32" } }),
				Svg.el("stop", { { "offset", "1" }, { "stop-color", ZONE_GLOW[zone] }, { "stop-opacity", "0" } }),
			})
		)
	end
	table.insert(out, Svg.el("defs", nil, defs))
	table.insert(
		out,
		layer("bg", {
			Svg.el(
				"rect",
				{ { "class", "m-wbg" }, { "x", "0" }, { "y", "0" }, { "width", Svg.n(W.w) }, { "height", Svg.n(W.h) } }
			),
		})
	)
	local ids = {}
	for _, id in Clean.keys(ctx.maps) do
		local m = ctx.maps[id]
		if m.worldMap.x ~= 0 or m.worldMap.y ~= 0 then
			table.insert(ids, id)
		end
	end
	-- zone glows
	local glows = {}
	for _, id in ids do
		local m = ctx.maps[id]
		local x, y = WikiMap.worldPos(m.worldMap)
		local r = if m.kind == "cave" then 60 else 170
		table.insert(
			glows,
			Svg.el("circle", {
				{ "class", `m-glow m-glow-{m.zone}` },
				{ "data-for", `node-{id}` },
				{ "cx", Svg.n(x) },
				{ "cy", Svg.n(y) },
				{ "r", Svg.n(r) },
				{ "fill", `url(#glow-{m.zone})` },
			})
		)
	end
	table.insert(out, layer("zones", glows))
	-- links (each pair once)
	local links, seen = {}, {}
	for _, id in ids do
		for _, other in ctx.maps[id].links do
			local a, b = if id < other then id else other, if id < other then other else id
			local key = `{a}--{b}`
			local ma, mb = ctx.maps[a], ctx.maps[b]
			if not seen[key] and ma and mb and table.find(ids, a) and table.find(ids, b) then
				seen[key] = true
				local ax, ay = WikiMap.worldPos(ma.worldMap)
				local bx, by = WikiMap.worldPos(mb.worldMap)
				table.insert(
					links,
					Svg.el("path", {
						{ "id", `link-{key}` },
						{ "data-id", key },
						{ "class", "m-link" },
						{ "d", `M{Svg.n(ax)} {Svg.n(ay)}L{Svg.n(bx)} {Svg.n(by)}` },
					})
				)
			end
		end
	end
	table.insert(out, layer("links", links))
	-- nodes: regions and the city as plates, caves as diamonds on top of them; bosses next to the cave with the gate
	local nodes, bosses = {}, {}
	local ordered = table.clone(ids)
	table.sort(ordered, function(a, b)
		local ca, cb = ctx.maps[a].kind == "cave", ctx.maps[b].kind == "cave"
		if ca ~= cb then
			return cb
		end
		return a < b
	end)
	for _, id in ordered do
		local m = ctx.maps[id]
		local x, y = WikiMap.worldPos(m.worldMap)
		local lv = levels(m.minLevel, m.maxLevel)
		if m.kind == "cave" then
			table.insert(
				nodes,
				Svg.marker({
					id = `node-{id}`,
					dataId = id,
					x = x,
					z = y,
					cls = "m-node m-cavenode",
					shape = "diamond",
					r = 7,
					name = m.name,
					labelCls = "lod-2",
					extra = { { "data-kind", m.kind }, { "data-zone", m.zone } },
				})
			)
			local def = Areas.caves.get(id)
			if def and def.boss then
				local boss = Bosses.forRegion(def.region)
				if boss then
					table.insert(
						bosses,
						Svg.marker({
							id = `boss-{boss.id}`,
							dataId = boss.id,
							x = x,
							z = y + 34,
							cls = "m-boss",
							shape = "diamond",
							r = 9,
							glyph = "☠",
							name = Names.of(boss.nameKey),
							labelCls = "lod-2",
							extra = { { "data-target", `dungeon_{def.region}` } },
						})
					)
				end
			end
		else
			local name = m.name
			local width = math.max(utf8.len(name.pl) or 10, utf8.len(name.en) or 10) * 11 + 34
			table.insert(
				nodes,
				Svg.group({
					{ "id", `node-{id}` },
					{ "data-id", id },
					{ "class", `mk m-node m-{m.kind}node` },
					{ "data-kind", m.kind },
					{ "data-zone", m.zone },
					{ "transform", `translate({Svg.n(x)} {Svg.n(y)})` },
				}, {
					Svg.group({ { "class", "k" } }, {
						Svg.el("rect", {
							{ "class", "m-plate" },
							{ "x", Svg.f(-width / 2) },
							{ "y", "-22" },
							{ "width", Svg.f(width) },
							{ "height", "46" },
						}),
						Svg.label(name, "m-node-name", 0, 2),
						Svg.label({ pl = `◆ Poz. {lv}`, en = `◆ Lv. {lv}` }, "m-node-lv", 0, 17),
					}),
				})
			)
		end
	end
	table.insert(out, layer("nodes", nodes))
	table.insert(out, layer("bosses", bosses))
	table.insert(out, "</svg>")
	return table.concat(out)
end

-- Build -----------------------------------------------------------------------------------------------------------

function WikiMap.context(opts: Opts?): Ctx
	local o: Opts = opts or {}
	local warnings = {}
	local hidden = Visibility.collect()
	local maps = {}
	for _, m in World.mapsData(hidden) do
		maps[m.id] = m
	end
	local colors = {}
	local sketchText = if o.readText then o.readText("src/client/UI/MapSketch.luau") else nil
	for _, c in Places.sketchColors(sketchText, warnings) do
		colors[c.name] = c.hex
	end
	local areaNames = {}
	for _, data in Areas.byMap do
		for _, a in data.areas do
			areaNames[a.id] = Names.of(a.nameKey)
		end
	end
	local profiles = {}
	local okProfiles, AreaProfiles = pcall(function()
		return require("../src/shared/Data/AreaProfiles")
	end)
	if okProfiles and AreaProfiles then
		for id, p in (AreaProfiles :: any).byId or {} do
			profiles[id] = p.icon
		end
	end
	local ctx: any = {
		maps = maps,
		colors = colors,
		placements = Places.gather(o.readText, warnings),
		groups = Places.groups(),
		areaNames = areaNames,
		profiles = profiles,
		warnings = warnings,
	}
	return ctx
end

-- Every file name (without .svg) and its builder.
function WikiMap.names(ctx: Ctx): { string }
	local names = { "world", "city" }
	for _, id in Places.REGION_MAPS do
		if ctx.maps[id] then
			table.insert(names, id)
		end
	end
	for _, c in Areas.caves.list do
		if ctx.maps[c.id] then
			table.insert(names, c.id)
		end
	end
	return names
end

function WikiMap.kindOf(name: string): string
	if name == "world" or name == "city" then
		return name
	end
	return if Areas.byMap[name] then "region" else "cave"
end

function WikiMap.build(opts: Opts?): { files: { [string]: string }, warnings: { string }, ctx: any }
	local o: Opts = opts or {}
	local ctx = WikiMap.context(o)
	local files = {}
	for _, name in WikiMap.names(ctx) do
		if not o.only or table.find(o.only, name) then
			local kind = WikiMap.kindOf(name)
			local svg
			if kind == "world" then
				svg = world(ctx)
			elseif kind == "city" then
				svg = city(ctx)
			elseif kind == "region" then
				svg = region(ctx, name)
			else
				svg = cave(ctx, name)
			end
			files[name] = svg .. "\n"
		end
	end
	return { files = files, warnings = ctx.warnings, ctx = ctx }
end

-- Monster names of a map's groups, for tests and the CLI table.
function WikiMap.monsterName(kind: string): any
	local def = Monsters.get(kind)
	return if def then Names.of(def.nameKeys.normal) else nil
end

return WikiMap
