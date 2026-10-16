--!strict
-- Monster telegraphs 2.0 on the ground (S117, DESIGN-16 §8, Logic/Telegraph, docs/ANIMACJE.md "Potwory i bossowie w
-- walce"). Layers from the bottom: the whole area faintly from the first frame (Config.Telegraph.areaAlpha: where the
-- blow will land), the band filling from the edge to the centre (a ring to its safe centre, a cone from its arc to its
-- tip, a line from both long sides to its axis), a thin bright front on its inner edge, a dark under-rim (contrast on
-- snow) and the bright rim pulsing faster towards the blow, the green safe centre of a ring (pulsing in its last
-- safePulse s). At the end of the windup the area flashes white for flashSeconds (`onBlow` runs once: the effect and the
-- sound of the attack), then fades over fadeSeconds. Circles and rings draw their rim, front, area and safe centre on
-- one SurfaceGui (exact circles); the band, and every layer of cones and lines, are pooled parts (Vfx/Pool: blocks and
-- wedges, a trapezoid = a block between two wedges). One Heartbeat loop moves every active telegraph on the effect clock
-- (Vfx/Clock: AnimLab freeze stops them with the monster's gather). Over Config.Telegraph.maxActive, on `simple`, the
-- band and the area are left out; low quality uses segmentsLow pieces and no texture. A magic area (Elite II and boss
-- spells) carries a turning magic circle, a physical round one dark cracks (S112 textures; none without their ids or
-- over the beam / decal limits).
-- S134 (bosses 2.0): `follow` keeps a circle under a character (a boss mark: moved every frame from its root, no
-- texture layer), `rimWidth` thickens the rim of a big blow to dodge, `key` + GroundTelegraph.cancel drop a mark that
-- will not blast. S134e: `pulseFast` speeds up the end of the rim pulse (a lethal blow).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Library)
local Pool = require(script.Parent.Pool)
local Telegraph = require(ReplicatedStorage.Shared.Logic.Telegraph)
local Textures = require(script.Parent.Textures)

local GroundTelegraph = {}

local CFG = Config.Telegraph
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromHex("#140C0A")
local SAFE = Color3.fromHex("#5BD66B")
local BAND_THICK = 0.08
local EDGE_THICK = 0.1
local FRONT_WIDTH = 0.14 -- studs: the moving front line
local MAX_CANVAS = 1024 -- pixels across a circle's SurfaceGui
local SURFACE_KEEP = 8 -- free circle surfaces kept for reuse

export type Spec = {
	shape: Telegraph.Shape,
	dims: Telegraph.Dims,
	area: CFrame, -- the server's area frame (ground level, forward -Z)
	windup: number,
	color: Color3,
	magic: boolean, -- a spell: the magic circle texture (round areas)
	low: boolean, -- low graphics quality: segmentsLow, no texture
	simple: boolean?, -- outline and front only (also forced over maxActive)
	onBlow: (() -> ())?, -- once, in the frame of the flash (the server's hit)
	follow: Model?, -- S134: a circle that follows this character (its HumanoidRootPart, on the area's ground plane)
	rimWidth: number?, -- S134: studs of the bright rim (default Config.Telegraph.rimWidth)
	key: string?, -- S134: what GroundTelegraph.cancel matches (a boss mark)
	pulseFast: number?, -- S134e: seconds per rim pulse at the end (a lethal blow: Config.Telegraph.pulseLethal)
}

type Trapezoid = { block: BasePart, left: BasePart, right: BasePart }

type Surface = {
	part: BasePart,
	gui: SurfaceGui,
	area: Frame,
	under: Frame,
	underStroke: UIStroke,
	rim: Frame,
	rimStroke: UIStroke,
	front: Frame,
	frontStroke: UIStroke,
	safe: Frame,
	safeStroke: UIStroke,
}

type Active = {
	spec: Spec,
	area: CFrame, -- S134: spec.area, moved with spec.follow
	start: number,
	windup: number,
	simple: boolean,
	segments: number,
	pieces: { Telegraph.Piece }, -- reused by Telegraph.band
	band: { Trapezoid },
	areaParts: { BasePart },
	rimParts: { BasePart },
	underParts: { BasePart },
	frontParts: { BasePart },
	surface: Surface?,
	ppu: number,
	stopTexture: (() -> ())?,
	blown: boolean,
	pulseCfg: Telegraph.Cfg, -- S134e: CFG, or a copy with the spec's pulseFast
}

local active: { Active } = {}
local freeSurfaces: { Surface } = {}
local connection: RBXScriptConnection? = nil

-- Parts -----------------------------------------------------------------------------------------------------------

local function flat(shape: string, color: Color3, transparency: number): BasePart
	local p = Pool.part(shape, color, Vector3.new(0.1, 0.1, 0.1), Enum.Material.SmoothPlastic, transparency)
	p.CastShadow = false
	return p
end

local function neon(color: Color3, transparency: number): BasePart
	return Pool.part("Block", color, Vector3.new(0.1, 0.1, 0.1), Enum.Material.Neon, transparency)
end

local function newTrapezoid(color: Color3, transparency: number): Trapezoid
	return {
		block = flat("Block", color, transparency),
		left = flat("Wedge", color, transparency),
		right = flat("Wedge", color, transparency),
	}
end

-- A trapezoid of `piece` (Logic/Telegraph) in the area frame `area` at `height` above the ground: a block of the near
-- width between two wedges that widen it to the far width. A Wedge's slope runs from its top back edge (+Y, +Z) to its
-- bottom front edge; turned on its side (Z roll) and flipped (X half turn) it lies flat as a right triangle whose right
-- angle sits at the far edge next to the block.
local function placeTrapezoid(t: Trapezoid, area: CFrame, piece: Telegraph.Piece, height: number, thick: number)
	local w, d = piece.size[1], piece.size[2]
	local near = w * piece.taper
	if d < 0.02 or w < 0.02 then
		t.block.Size = Vector3.new(0.05, 0.05, 0.05)
		t.block.CFrame = area * CFrame.new(0, -5, 0)
		t.left.CFrame = t.block.CFrame
		t.right.CFrame = t.block.CFrame
		return
	end
	local frame = area * CFrame.new(piece.pos[1], height, piece.pos[2]) * CFrame.Angles(0, piece.yaw, 0)
	t.block.Size = Vector3.new(math.max(0.02, near), thick, d)
	t.block.CFrame = frame
	local a = (w - near) / 2
	if a < 0.02 then
		t.left.Size = Vector3.new(0.05, 0.05, 0.05)
		t.right.Size = t.left.Size
		t.left.CFrame = area * CFrame.new(0, -5, 0)
		t.right.CFrame = t.left.CFrame
		return
	end
	local x = near / 2 + a / 2
	t.right.Size = Vector3.new(thick, a, d)
	t.right.CFrame = frame * CFrame.new(x, 0, 0) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
	t.left.Size = Vector3.new(thick, a, d)
	t.left.CFrame = frame * CFrame.new(-x, 0, 0) * CFrame.Angles(math.pi, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
end

local function releaseAll(list: { BasePart })
	for _, p in list do
		Pool.release(p)
	end
	table.clear(list)
end

-- A straight edge from a to b (area frame, x / z) of `width`, `height` above the ground.
local function placeEdge(
	p: BasePart,
	area: CFrame,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	width: number,
	height: number
)
	local dx, dz = bx - ax, bz - az
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-3 then
		p.Size = Vector3.new(0.05, 0.05, 0.05)
		p.CFrame = area * CFrame.new(0, -5, 0)
		return
	end
	local yaw = math.atan2(-dx, -dz)
	p.Size = Vector3.new(width, EDGE_THICK, length + width)
	p.CFrame = area * CFrame.new((ax + bx) / 2, height, (az + bz) / 2) * CFrame.Angles(0, yaw, 0)
end

-- Circle surfaces ------------------------------------------------------------------------------------------------

local function ringFrame(parent: Instance, name: string, z: number): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = frame
	frame.Parent = parent
	return frame, stroke
end

local function takeSurface(): Surface
	local free = table.remove(freeSurfaces)
	if free then
		free.part.Parent = Pool.folder()
		return free
	end
	local part = Instance.new("Part")
	part.Name = "TelegraphSurface"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = false
	gui.ResetOnSpawn = false
	gui.Parent = part
	local area = ringFrame(gui, "Area", 1)
	local under, underStroke = ringFrame(gui, "Under", 2)
	local safe, safeStroke = ringFrame(gui, "Safe", 3)
	local front, frontStroke = ringFrame(gui, "Front", 4)
	local rim, rimStroke = ringFrame(gui, "Rim", 5)
	local areaStroke = area:FindFirstChildOfClass("UIStroke")
	if areaStroke then
		areaStroke:Destroy()
	end
	part.Parent = Pool.folder()
	return {
		part = part,
		gui = gui,
		area = area,
		under = under,
		underStroke = underStroke,
		rim = rim,
		rimStroke = rimStroke,
		front = front,
		frontStroke = frontStroke,
		safe = safe,
		safeStroke = safeStroke,
	}
end

local function releaseSurface(surface: Surface)
	if #freeSurfaces < SURFACE_KEEP and surface.part.Parent then
		surface.part.Parent = nil
		table.insert(freeSurfaces, surface)
	else
		surface.part:Destroy()
	end
end

local function px(frame: Frame, size: number)
	frame.Size = UDim2.fromOffset(size, size)
end

-- Builds the layers of a new telegraph.
local function build(a: Active)
	local spec = a.spec
	local color = spec.color
	local rimWidth = spec.rimWidth or CFG.rimWidth
	local shape = spec.shape
	local dims = spec.dims
	if shape == "circle" or shape == "ring" then
		local r = Telegraph.radius(spec.shape, dims)
		local outer = r + CFG.underRim + 0.5
		local ppu = math.clamp(MAX_CANVAS / (2 * outer), 4, 24)
		a.ppu = ppu
		local surface = takeSurface()
		a.surface = surface
		surface.part.Size = Vector3.new(outer * 2, 0.05, outer * 2)
		surface.part.CFrame = spec.area * CFrame.new(0, CFG.lift + 0.1, 0)
		surface.gui.PixelsPerStud = ppu
		px(surface.area, 2 * r * ppu)
		surface.area.BackgroundColor3 = color
		surface.area.BackgroundTransparency = if a.simple then 1 else CFG.areaAlpha
		px(surface.under, 2 * r * ppu)
		surface.underStroke.Color = DARK
		surface.underStroke.Thickness = CFG.underRim * ppu
		surface.underStroke.Transparency = 0.5
		px(surface.rim, 2 * (r - rimWidth) * ppu)
		surface.rimStroke.Color = color:Lerp(WHITE, 0.15)
		surface.rimStroke.Thickness = rimWidth * ppu
		surface.rimStroke.Transparency = 0.2
		surface.frontStroke.Color = color:Lerp(WHITE, 0.55)
		surface.frontStroke.Thickness = math.max(1.5, FRONT_WIDTH * ppu)
		surface.frontStroke.Transparency = 0.2
		px(surface.front, 2 * r * ppu)
		if shape == "ring" then
			local ir = math.min(Telegraph.inner(dims), r)
			px(surface.safe, 2 * ir * ppu)
			surface.safe.Visible = true
			surface.safe.BackgroundColor3 = SAFE
			surface.safe.BackgroundTransparency = 0.45
			surface.safeStroke.Color = SAFE
			surface.safeStroke.Thickness = math.max(1.5, 0.2 * ppu)
			surface.safeStroke.Transparency = 0.1
		else
			surface.safe.Visible = false
		end
		surface.gui.Enabled = true
	elseif shape == "cone" then
		local r = Telegraph.radius(spec.shape, dims)
		local angle = math.rad(Telegraph.angle(dims))
		local count = math.max(1, math.floor(a.segments / 2))
		local slice = angle / count
		-- the area: slices as wide as their arc (they overlap a little towards the tip, like before S117)
		if not a.simple then
			for i = 0, count - 1 do
				local yaw = -angle / 2 + slice * (i + 0.5)
				local p = flat("Block", color, CFG.areaAlpha)
				p.Size = Vector3.new(2 * r * math.tan(slice / 2) + 0.05, BAND_THICK, r)
				p.CFrame = spec.area * CFrame.Angles(0, yaw, 0) * CFrame.new(0, CFG.lift, -r / 2)
				table.insert(a.areaParts, p)
			end
		end
		-- the under-rim and the rim: the arc and both sides
		for _, list in { a.underParts, a.rimParts } do
			local isRim = list == a.rimParts
			local width = if isRim then rimWidth else rimWidth + 2 * CFG.underRim
			local height = CFG.lift + (if isRim then 0.07 else 0.05)
			for i = 0, count - 1 do
				local y0, y1 = -angle / 2 + slice * i, -angle / 2 + slice * (i + 1)
				local p = if isRim then neon(color, 0.2) else flat("Block", DARK, 0.5)
				placeEdge(
					p,
					spec.area,
					-math.sin(y0) * r,
					-math.cos(y0) * r,
					-math.sin(y1) * r,
					-math.cos(y1) * r,
					width,
					height
				)
				table.insert(list, p)
			end
			for _, y in { -angle / 2, angle / 2 } do
				local p = if isRim then neon(color, 0.2) else flat("Block", DARK, 0.5)
				placeEdge(p, spec.area, 0, 0, -math.sin(y) * r, -math.cos(y) * r, width, height)
				table.insert(list, p)
			end
		end
		for _ = 1, count do
			table.insert(a.frontParts, neon(color:Lerp(WHITE, 0.55), 0.2))
		end
	else
		local l, w = Telegraph.length(dims), Telegraph.width(dims)
		if not a.simple then
			local p = flat("Block", color, CFG.areaAlpha)
			p.Size = Vector3.new(w, BAND_THICK, l)
			p.CFrame = spec.area * CFrame.new(0, CFG.lift, -l / 2)
			table.insert(a.areaParts, p)
		end
		local corners = { { -w / 2, 0 }, { w / 2, 0 }, { w / 2, -l }, { -w / 2, -l } }
		for _, list in { a.underParts, a.rimParts } do
			local isRim = list == a.rimParts
			local width = if isRim then rimWidth else rimWidth + 2 * CFG.underRim
			local height = CFG.lift + (if isRim then 0.07 else 0.05)
			for i = 1, 4 do
				local c0, c1 = corners[i], corners[i % 4 + 1]
				local p = if isRim then neon(color, 0.2) else flat("Block", DARK, 0.5)
				placeEdge(p, spec.area, c0[1], c0[2], c1[1], c1[2], width, height)
				table.insert(list, p)
			end
		end
		for _ = 1, 2 do
			table.insert(a.frontParts, neon(color:Lerp(WHITE, 0.55), 0.2))
		end
	end
	if not a.simple then
		local count = #Telegraph.band(spec.shape, 0, dims, a.segments, a.pieces)
		for _ = 1, count do
			table.insert(a.band, newTrapezoid(color, CFG.fillFrom))
		end
	end
end

local function finish(a: Active)
	for _, t in a.band do
		Pool.release(t.block)
		Pool.release(t.left)
		Pool.release(t.right)
	end
	table.clear(a.band)
	releaseAll(a.areaParts)
	releaseAll(a.rimParts)
	releaseAll(a.underParts)
	releaseAll(a.frontParts)
	if a.surface then
		releaseSurface(a.surface)
		a.surface = nil
	end
	if a.stopTexture then
		a.stopTexture()
		a.stopTexture = nil
	end
end

-- S134: the area under a followed character (its root on the area's ground plane); the last one when it is gone.
local function followArea(a: Active): CFrame
	local model = a.spec.follow
	local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local p = root.Position
		return CFrame.new(p.X, a.area.Position.Y, p.Z)
	end
	return a.area
end

-- One frame of one telegraph; false when it is over.
local function update(a: Active, now: number): boolean
	local spec = a.spec
	if spec.follow then
		a.area = followArea(a)
		if a.surface then
			a.surface.part.CFrame = a.area * CFrame.new(0, CFG.lift + 0.1, 0)
		end
	end
	local area = a.area
	local elapsed = now - a.start
	local w = a.windup
	if elapsed >= Telegraph.duration(w, CFG) then
		finish(a)
		return false
	end
	local p = Telegraph.progress(elapsed, w)
	local flash = Telegraph.flashing(elapsed, w, CFG)
	local fade = Telegraph.fade(elapsed, w, CFG)
	if elapsed >= w and not a.blown then
		a.blown = true
		if spec.onBlow then
			task.spawn(spec.onBlow)
		end
	end
	local color = spec.color
	local lit = color:Lerp(WHITE, 0.7 * flash)
	local rim = Telegraph.rimPulse(elapsed, w, a.pulseCfg)
	local function faded(t: number): number
		return t + (1 - t) * fade
	end
	local shape = spec.shape
	local front = Telegraph.front(spec.shape, p, spec.dims)
	-- the band
	if #a.band > 0 then
		local pieces = Telegraph.band(spec.shape, p, spec.dims, a.segments, a.pieces)
		local fill = faded(Telegraph.fillAlpha(p, CFG) * (1 - 0.6 * flash))
		for i, t in a.band do
			local piece = pieces[i]
			if piece then
				placeTrapezoid(t, area, piece, CFG.lift + 0.02, BAND_THICK)
			end
			t.block.Color, t.left.Color, t.right.Color = lit, lit, lit
			t.block.Transparency, t.left.Transparency, t.right.Transparency = fill, fill, fill
		end
	end
	for _, part in a.areaParts do
		part.Color = lit
		part.Transparency = faded(CFG.areaAlpha * (1 - 0.5 * flash))
	end
	for _, part in a.rimParts do
		part.Color = color:Lerp(WHITE, 0.15 + 0.6 * flash)
		part.Transparency = faded(rim)
	end
	for _, part in a.underParts do
		part.Transparency = faded(0.5)
	end
	-- the front
	local surface = a.surface
	if surface then
		local ppu = a.ppu
		surface.rimStroke.Transparency = faded(rim)
		surface.rimStroke.Color = color:Lerp(WHITE, 0.15 + 0.6 * flash)
		surface.underStroke.Transparency = faded(0.5)
		if not a.simple then
			surface.area.BackgroundColor3 = lit
			surface.area.BackgroundTransparency = faded(CFG.areaAlpha * (1 - 0.5 * flash))
		end
		local inner = if shape == "ring" then Telegraph.inner(spec.dims) else 0
		surface.front.Visible = front > inner + 0.05 and elapsed < w
		px(surface.front, 2 * front * ppu)
		if shape == "ring" then
			local left = w - elapsed
			local pulse = if left > 0 and left < CFG.safePulse then 0.5 + 0.5 * math.cos(left * 30) else 0
			surface.safe.BackgroundTransparency = faded(0.45 - 0.25 * pulse)
			surface.safeStroke.Transparency = faded(0.1)
		end
	elseif #a.frontParts > 0 then
		local show = elapsed < w and front > 0.05
		if shape == "cone" then
			local angle = math.rad(Telegraph.angle(spec.dims))
			local count = #a.frontParts
			local slice = angle / count
			for i, part in a.frontParts do
				local y0, y1 = -angle / 2 + slice * (i - 1), -angle / 2 + slice * i
				if show then
					placeEdge(
						part,
						area,
						-math.sin(y0) * front,
						-math.cos(y0) * front,
						-math.sin(y1) * front,
						-math.cos(y1) * front,
						FRONT_WIDTH,
						CFG.lift + 0.06
					)
				else
					part.CFrame = area * CFrame.new(0, -5, 0)
				end
			end
		else
			local l = Telegraph.length(spec.dims)
			for i, part in a.frontParts do
				local x = (if i == 1 then -1 else 1) * front
				if show then
					placeEdge(part, area, x, 0, x, -l, FRONT_WIDTH, CFG.lift + 0.06)
				else
					part.CFrame = area * CFrame.new(0, -5, 0)
				end
			end
		end
	end
	return true
end

local function step()
	local now = Clock.now()
	for i = #active, 1, -1 do
		local ok, alive = pcall(update, active[i], now)
		if not ok then
			warn(`[GroundTelegraph] {tostring(alive)}`)
			pcall(finish, active[i])
			table.remove(active, i)
		elseif not alive then
			table.remove(active, i)
		end
	end
	if #active == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- Starts a telegraph (CombatFxController for "tele" events, AnimLab through PreviewTelegraph).
function GroundTelegraph.start(spec: Spec)
	local windup = Telegraph.windup(spec.windup)
	local a: Active = {
		spec = spec,
		area = spec.area,
		start = Clock.now(),
		windup = windup,
		simple = spec.simple == true or #active >= CFG.maxActive,
		segments = if spec.low then CFG.segmentsLow else CFG.segments,
		pieces = {},
		band = {},
		areaParts = {},
		rimParts = {},
		underParts = {},
		frontParts = {},
		surface = nil,
		ppu = 1,
		stopTexture = nil,
		blown = false,
		pulseCfg = CFG,
	}
	if spec.pulseFast then
		local cfg = table.clone(CFG) :: any
		cfg.pulseFast = spec.pulseFast
		a.pulseCfg = cfg
	end
	build(a)
	-- S112 texture layer: a turning magic circle for spells, dark cracks under a physical round area
	local round = spec.shape == "circle" or spec.shape == "ring"
	if round and not a.simple and not spec.low and Config.Vfx.textures and not spec.follow then
		local r = Telegraph.radius(spec.shape, spec.dims)
		local seconds = windup + CFG.flashSeconds
		if spec.magic and Textures.id("magicCircle") then
			local live = Pool.holderCount("beam") + Pool.holderCount("surface")
			if live < Pool.limit("beams") then
				a.stopTexture = Library.magicCircle(spec.area.Position, r * 0.92, spec.color, seconds, { spin = 0.6 })
			end
		elseif not spec.magic and spec.shape == "circle" and Textures.id("cracks") then
			if Pool.holderCount("decal") < Pool.limit("decals") then
				a.stopTexture = Library.groundDecal(
					spec.area.Position,
					r * 0.85,
					"cracks",
					Library.crackTint(spec.color),
					seconds + CFG.fadeSeconds
				)
			end
		end
	end
	table.insert(active, a)
	update(a, a.start)
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- S134: removes the telegraphs with `key` that have not blown yet, without their `onBlow` (a cancelled boss mark).
function GroundTelegraph.cancel(key: string)
	for i = #active, 1, -1 do
		local a = active[i]
		if a.spec.key == key and not a.blown then
			pcall(finish, a)
			table.remove(active, i)
		end
	end
end

-- Telegraphs on the ground now (AnimLab state, the cost measure).
function GroundTelegraph.activeCount(): number
	return #active
end

return GroundTelegraph
