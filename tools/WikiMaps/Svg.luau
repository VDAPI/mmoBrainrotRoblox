--!strict
-- Small SVG writer for the wiki maps (S37): escaped text, attributes in the given order, numbers rounded to one
-- stud (or 0.1 with `fine`), shared styles and marker shapes. Pure.

local Svg = {}

export type Attrs = { { any } } -- ordered { name, value } pairs; nil values are skipped

function Svg.esc(text: string): string
	local out = string.gsub(text, "&", "&amp;")
	out = string.gsub(out, "<", "&lt;")
	out = string.gsub(out, ">", "&gt;")
	out = string.gsub(out, '"', "&quot;")
	return out
end

-- Integer studs ("-0" never appears).
function Svg.n(v: number): string
	local r = math.floor(v + 0.5)
	if r == 0 then
		return "0"
	end
	return string.format("%d", r)
end

-- One decimal (marker shapes in screen units).
function Svg.f(v: number): string
	local r = math.floor(v * 10 + 0.5) / 10
	if r == math.floor(r) then
		return Svg.n(r)
	end
	return string.format("%.1f", r)
end

local function attrs(list: Attrs?): string
	if not list then
		return ""
	end
	local parts = {}
	for _, pair in list do
		local value = pair[2]
		if value ~= nil then
			table.insert(parts, ` {pair[1]}="{Svg.esc(tostring(value))}"`)
		end
	end
	return table.concat(parts)
end

function Svg.el(tag: string, a: Attrs?, children: { string }? | string?): string
	if children == nil then
		return `<{tag}{attrs(a)}/>`
	end
	local body = if type(children) == "table" then table.concat(children :: { string }) else Svg.esc(children :: string)
	return `<{tag}{attrs(a)}>{body}</{tag}>`
end

-- Raw (already built) children.
function Svg.group(a: Attrs?, children: { string }): string
	return `<g{attrs(a)}>{table.concat(children)}</g>`
end

-- Path data "M x z L x z ..." of a flat list { x1, z1, x2, z2, ... }.
function Svg.polyline(points: { number }, closed: boolean?): string
	local parts = {}
	for i = 1, #points - 1, 2 do
		table.insert(parts, (if i == 1 then "M" else "L") .. Svg.n(points[i]) .. " " .. Svg.n(points[i + 1]))
	end
	if closed then
		table.insert(parts, "Z")
	end
	return table.concat(parts)
end

-- Corners of a rectangle centred on (x, z), w by h, rotated `rot` degrees (Roblox yaw: clockwise seen from above
-- with -Z up is a counter-clockwise turn of the drawing; MapSketch draws Frame.Rotation = rot, same here).
function Svg.rectPath(x: number, z: number, w: number, h: number, rot: number?): string
	local a = math.rad(rot or 0)
	local c, s = math.cos(a), math.sin(a)
	local pts = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local dx, dz = corner[1] * w / 2, corner[2] * h / 2
		table.insert(pts, x + dx * c - dz * s)
		table.insert(pts, z + dx * s + dz * c)
	end
	return Svg.polyline(pts, true)
end

-- Circle as path data (two arcs), so many circles of one kind can share one <path>.
function Svg.circlePath(x: number, z: number, r: number): string
	local rr = Svg.n(r)
	return `M{Svg.n(x - r)} {Svg.n(z)}a{rr} {rr} 0 1 0 {Svg.n(2 * r)} 0a{rr} {rr} 0 1 0 {Svg.n(-2 * r)} 0Z`
end

-- A pair of labels (Polish and English). `cls` adds level-of-detail and kind classes.
function Svg.label(name: { pl: string, en: string }, cls: string, x: number?, y: number?, extra: string?): string
	local out = {}
	for _, lang in { "pl", "en" } do
		local text = name[lang] .. (extra or "")
		table.insert(
			out,
			Svg.el("text", {
				{ "lang", lang },
				{ "class", cls },
				{ "x", if x then Svg.f(x) else nil },
				{ "y", if y then Svg.f(y) else nil },
			}, text)
		)
	end
	return table.concat(out)
end

-- Marker shapes in screen pixels around (0, 0); the wrapper scales them by --k.
Svg.SHAPES = {
	diamond = function(r: number): string
		return `M0 {Svg.f(-r)}L{Svg.f(r)} 0L0 {Svg.f(r)}L{Svg.f(-r)} 0Z`
	end,
	square = function(r: number): string
		return `M{Svg.f(-r)} {Svg.f(-r)}H{Svg.f(r)}V{Svg.f(r)}H{Svg.f(-r)}Z`
	end,
	circle = function(r: number): string
		return `M{Svg.f(-r)} 0a{Svg.f(r)} {Svg.f(r)} 0 1 0 {Svg.f(2 * r)} 0a{Svg.f(r)} {Svg.f(r)} 0 1 0 {Svg.f(-2 * r)} 0Z`
	end,
	arch = function(r: number): string
		-- portal arch: a rounded top over two legs
		return `M{Svg.f(-r)} {Svg.f(r)}V0a{Svg.f(r)} {Svg.f(r)} 0 0 1 {Svg.f(2 * r)} 0V{Svg.f(r)}Z`
	end,
}

-- A marker: <g transform="translate(x z)" id=… data-id=…><g class="k">shape, glyph, label</g></g>. Everything inside
-- the inner group is in screen pixels (scaled by var(--k)).
function Svg.marker(opts: {
	id: string,
	dataId: string,
	x: number,
	z: number,
	cls: string,
	shape: string,
	r: number,
	glyph: string?,
	name: { pl: string, en: string }?,
	labelCls: string?,
	extra: Attrs?,
	rot: number?,
}): string
	local inner = {}
	if opts.rot then
		-- arrow showing where a cave mouth opens (rot 0 = towards -Z, up)
		local a = math.rad(opts.rot)
		local dx, dz = -math.sin(a), -math.cos(a)
		local tip = opts.r * 2.1
		table.insert(
			inner,
			Svg.el("path", {
				{ "class", "m-arrow" },
				{ "d", `M{Svg.f(dx * opts.r)} {Svg.f(dz * opts.r)}L{Svg.f(dx * tip)} {Svg.f(dz * tip)}` },
			})
		)
	end
	table.insert(inner, Svg.el("path", { { "class", "m-shape" }, { "d", Svg.SHAPES[opts.shape](opts.r) } }))
	if opts.glyph then
		table.insert(inner, Svg.el("text", { { "class", "m-glyph" }, { "y", "0.5" } }, opts.glyph))
	end
	if opts.name then
		table.insert(inner, Svg.label(opts.name, "m-label " .. (opts.labelCls or "lod-2"), 0, opts.r + 13))
	end
	local a: Attrs = {
		{ "id", opts.id },
		{ "data-id", opts.dataId },
		{ "class", "mk " .. opts.cls },
		{ "transform", `translate({Svg.n(opts.x)} {Svg.n(opts.z)})` },
	}
	for _, pair in opts.extra or {} do
		table.insert(a, pair)
	end
	return Svg.group(a, { Svg.group({ { "class", "k" } }, inner) })
end

-- Shared style: colours through the wiki tokens (tokens.data.css / map.css) with the game's colours as fallbacks,
-- so a file opened on its own looks right too. English labels hidden unless the page is English.
function Svg.style(k: number): string
	return table.concat({
		"<style>",
		'svg{font-family:"Alegreya Sans",system-ui,sans-serif}',
		`.k\{transform:scale(var(--k,{Svg.f(k)}))\}`,
		'text[lang="en"]{display:none}',
		".m-shade{fill:var(--vw-map-shade,#14161B);opacity:var(--vw-map-shade-o,.42)}",
		".m-water{fill:var(--vw-map-water,#3A6FA8)}",
		".m-stream{fill:none;stroke:var(--vw-map-water,#3A6FA8);stroke-linecap:round;stroke-linejoin:round}",
		".m-road{fill:none;stroke:var(--vw-map-path,#9A8A68);stroke-linecap:round;stroke-linejoin:round;opacity:.85}",
		".m-floor{fill:var(--vw-map-floor,#5A5650)}",
		".m-corr{fill:none;stroke:var(--vw-map-floor,#5A5650);stroke-linecap:round}",
		".m-area{fill:var(--vw-map-area,rgba(240,236,226,.07));stroke:var(--vw-map-area-line,rgba(240,236,226,.5));stroke-width:1.5px;vector-effect:non-scaling-stroke;stroke-dasharray:6 4}",
		".m-room{fill:none;stroke:rgba(240,236,226,.25);stroke-width:1px;vector-effect:non-scaling-stroke}",
		".m-gather{fill:none;stroke-width:1px;vector-effect:non-scaling-stroke;stroke-dasharray:3 5;opacity:.7}",
		".m-vein{stroke:#E8C25A;fill:#E8C25A}.m-bush{stroke:#6FCF5A;fill:#6FCF5A}.m-fishing{stroke:#5AA8E8;fill:#5AA8E8}",
		".m-gather-rect{fill-opacity:.06}",
		".m-shape{stroke:#14161B;stroke-width:1.5px}",
		".m-arrow{stroke:#F0ECE2;stroke-width:2px;stroke-linecap:round}",
		".m-glyph{font-size:10px;text-anchor:middle;dominant-baseline:central;fill:#14161B;font-weight:800}",
		".m-label,.m-alabel,.m-node-name,.m-node-lv{text-anchor:middle;paint-order:stroke;stroke:#101216;stroke-width:3.5px;stroke-linejoin:round;fill:#F0ECE2}",
		".m-label{font-size:12px;font-weight:800}",
		".m-alabel{font-size:14px;font-weight:800}.m-alv{font-size:12px;font-weight:700;fill:#E8C25A}",
		".m-portal .m-shape{fill:#4A8BE8}.m-gate .m-shape{fill:#4A8BE8}.m-exit .m-shape{fill:#9AA4B4}",
		".m-cave .m-shape{fill:#E0503F}.m-dungeon .m-shape{fill:#E0503F}",
		".m-npc .m-shape{fill:#E8C25A}.m-boss .m-shape{fill:#E0503F}",
		".m-group .m-shape{fill:#F0ECE2}.m-elite .m-shape{fill:#E8C25A}.m-elite2 .m-shape{fill:#FF9F1C}",
		".m-link{stroke:rgba(232,194,90,.45);stroke-width:2px;vector-effect:non-scaling-stroke;stroke-dasharray:2 6;stroke-linecap:round}",
		".m-node .m-plate{fill:#1B1D23;stroke:rgba(232,194,90,.55);stroke-width:1px;vector-effect:non-scaling-stroke}",
		".m-node-name{font-family:'Grenze Gotisch',serif;font-size:22px;font-weight:700}",
		".m-node-lv{font-size:12px;font-weight:800;fill:#C9C2B0}",
		".m-wbg{fill:var(--vw-map-world,#15171C)}",
		".m-cavenode .m-shape{fill:#E0503F}.m-citynode .m-shape{fill:#5FCF6B}",
		"</style>",
	})
end

return Svg
