--!strict
-- Map sketches published by the server's WorldBuilder (ReplicatedStorage.MapSketches.<mapId>, JSON):
-- { size = {x, z}, shapes = { rect | circle | line }, icons = { {t, x, z, id} } } in map-relative studs.
-- `draw` renders a sketch into a Frame of size (size.x * scale, size.z * scale); north (-Z) is up.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapSketch = {}

export type Shape = {
	t: string,
	x: number?,
	z: number?,
	w: number?,
	h: number?,
	r: number?,
	p: { number }?,
	c: string,
}
export type Icon = { t: string, x: number, z: number, id: string? }
export type Sketch = { size: { x: number, z: number }, shapes: { Shape }, icons: { Icon } }

local cache: { [string]: Sketch } = {}

local COLORS: { [string]: { color: string, transparency: number } } = {
	path = { color = "#9A8A68", transparency = 0.15 },
	water = { color = "#3A6FA8", transparency = 0.05 },
	building = { color = "#B5A488", transparency = 0 },
	plaza = { color = "#8A8070", transparency = 0.2 },
	wall = { color = "#4A4744", transparency = 0 },
	hill = { color = "#3E5A30", transparency = 0.55 },
	arena = { color = "#C2A878", transparency = 0.1 },
	ruins = { color = "#7A7468", transparency = 0.2 },
	floor = { color = "#5A5650", transparency = 0 },
	lava = { color = "#E8541A", transparency = 0 },
}

local BACKGROUND: { [string]: string } = {
	city = "#4F6A35",
	grass = "#56743A",
	forest = "#2E3B26",
	desert = "#B08A5A",
	snow = "#C9D6E3",
	cave = "#1E1C1A",
	crypt = "#16141C",
	dungeon = "#1E1C1A",
}

function MapSketch.background(biome: string): Color3
	return Color3.fromHex(BACKGROUND[biome] or "#3A3A3A")
end

function MapSketch.isBuilt(mapId: string): boolean
	local folder = ReplicatedStorage:FindFirstChild("MapSketches")
	return folder ~= nil and folder:FindFirstChild(mapId) ~= nil
end

function MapSketch.get(mapId: string): Sketch?
	local cached = cache[mapId]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:FindFirstChild("MapSketches")
	local value = folder and folder:FindFirstChild(mapId)
	if not value or not value:IsA("StringValue") or value.Value == "" then
		return nil
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(value.Value)
	end)
	if not ok or type(decoded) ~= "table" then
		return nil
	end
	cache[mapId] = decoded :: Sketch
	return decoded :: Sketch
end

local function frame(
	parent: Instance,
	kind: string,
	position: Vector2,
	size: Vector2,
	rotation: number?,
	round: boolean
)
	local style = COLORS[kind] or COLORS.floor
	local f = Instance.new("Frame")
	f.Name = kind
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(position.X, position.Y)
	f.Size = UDim2.fromOffset(math.max(1, size.X), math.max(1, size.Y))
	f.Rotation = rotation or 0
	f.BackgroundColor3 = Color3.fromHex(style.color)
	f.BackgroundTransparency = style.transparency
	f.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	f.Parent = parent
end

-- Draws the static shapes of `sketch` into `parent` (already sized size * scale).
function MapSketch.draw(parent: Instance, sketch: Sketch, scale: number)
	local half = Vector2.new(sketch.size.x / 2, sketch.size.z / 2)
	local function point(x: number, z: number): Vector2
		return (Vector2.new(x, z) + half) * scale
	end
	-- Order: hills and floors first, then water, paths, buildings and walls on top.
	local order = { hill = 1, floor = 1, water = 2, plaza = 3, path = 3, arena = 4, ruins = 4, building = 5, wall = 6 }
	local shapes = table.clone(sketch.shapes)
	table.sort(shapes, function(a, b)
		return (order[a.c] or 3) < (order[b.c] or 3)
	end)
	for _, shape in shapes do
		if shape.t == "rect" and shape.x and shape.z and shape.w and shape.h then
			frame(
				parent,
				shape.c,
				point(shape.x, shape.z),
				Vector2.new(shape.w, shape.h) * scale,
				shape.r and -shape.r,
				false
			)
		elseif shape.t == "circle" and shape.x and shape.z and shape.r then
			local d = shape.r * 2 * scale
			frame(parent, shape.c, point(shape.x, shape.z), Vector2.new(d, d), 0, true)
		elseif shape.t == "line" and shape.p then
			local p = shape.p
			local width = math.max(2, (shape.w or 4) * scale)
			for i = 1, #p - 3, 2 do
				local a, b = point(p[i], p[i + 1]), point(p[i + 2], p[i + 3])
				local delta = b - a
				frame(
					parent,
					shape.c,
					(a + b) / 2,
					Vector2.new(delta.Magnitude + width, width),
					math.deg(math.atan2(delta.Y, delta.X)),
					false
				)
			end
		end
	end
end

-- Map-relative position -> pixel inside a drawn sketch.
function MapSketch.toPixel(sketch: Sketch, scale: number, x: number, z: number): Vector2
	return (Vector2.new(x, z) + Vector2.new(sketch.size.x / 2, sketch.size.z / 2)) * scale
end

return MapSketch
