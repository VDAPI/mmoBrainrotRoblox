--!strict
-- S159 (owner 2026-10-21): draws the server's dodgeable hazards (HazardService "hz" events; Logic/Hazards,
-- Data/HazardPatterns). The client expands the same pattern from the same seed and steps the same kinematics on the
-- server clock (Workspace:GetServerTimeNow), so what flies here is where the server tests the hits; a homing bolt
-- steers to its target's model here (a few studs of lag at most). "hzx" drops a bolt that hit, "hzc" a whole cast.
--   bolt   an orb with a glow, a trail and a light (soul, frost, fire, magma, magic bolt), a spinning axe, an arrow,
--          a rock, a rolling snowball or an icicle; while it waits for its launch it hovers at its start and its lane
--          shows on the ground (a thin line filling up), homing ones without a lane
--   lob    an arc (a bomb, a boulder) or a fall from the sky (a meteor, an ice shard) onto a GroundTelegraph circle that
--          fills for the whole warning, an impact with debris, dust and the element's blast where it lands; S159a: a
--          thrown one is held over the caster's head until Logic/HazardGesture.flight s before it lands (the caster's
--          gesture releases it then)
--   wave   its lane fills on the ground for the warning, then the front runs: cracks with rock spikes, a wall of fire,
--          ice spikes, or a glacier wall rising at the edge and sliding across with its gap
--   ring   a low ring of earth and dust growing from the stomp (jump over it), gaps left open
--   sweep  the cone at its starting side fills, then the breath turns across: a spray of frost and the cone on the
--          ground following it
-- Pooled parts (Vfx/Pool), lights within Pool.takeLight, emitters only on medium / high quality; low quality and far
-- away keep the bodies and the lanes (what must be dodged) and drop trails, lights and debris.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local GroundTelegraph = require(script.Parent.GroundTelegraph)
local HazardGesture = require(ReplicatedStorage.Shared.Logic.HazardGesture)
local HazardPatterns = require(ReplicatedStorage.Shared.Data.HazardPatterns)
local Hazards = require(ReplicatedStorage.Shared.Logic.Hazards)
local Library = require(script.Parent.Library)
local Pool = require(script.Parent.Pool)
local Textures = require(script.Parent.Textures)

local HazardFx = {}

export type Context = {
	findModel: (entityId: string?) -> Model?,
	low: () -> boolean, -- low graphics quality
	play: (key: string, at: Vector3) -> (), -- a positional sound (SfxController)
	near: (at: Vector3) -> boolean, -- close enough to the camera for the full look
}

type Piece = {
	parts: { BasePart },
	light: PointLight?,
	emitter: ParticleEmitter?,
	trail: Trail?,
	lane: BasePart?,
	spin: number,
	stopTele: (() -> ())?,
	lastRow: number, -- waves: the front of the last row of spikes
	lastBreath: number, -- sweeps: the last ground cone
}

type Live = {
	id: number,
	pattern: Hazards.Pattern,
	insts: { Hazards.Inst },
	states: { Hazards.State },
	pieces: { [number]: Piece },
	started: { [number]: boolean },
	t0: number,
	color: Color3,
	targets: { Model? },
	arena: { x: number, z: number, r: number }?,
	ends: number,
	full: boolean,
	low: boolean,
}

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromHex("#2A2420")
local MAX_CASTS = 60 -- casts drawn at once (the rest are simulated by the server only)
local LANE_ALPHA = 0.55
local LOB_HEIGHT = 0.35 -- arc height per stud of distance
local SKY_HEIGHT = 46 -- studs a falling shard / meteor starts above its landing
local ROW_STEP = 3 -- studs between two rows of spikes of a wave
local BOLT_Y = Hazards.BOLT_HEIGHT

local ctx: Context? = nil
local casts: { [number]: Live } = {}
local count = 0
local connection: RBXScriptConnection? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

-- The CFrame at (x, y, z) facing Hazards angle `a` (forward -Z).
local function facing(x: number, y: number, z: number, a: number): CFrame
	return CFrame.lookAt(v3(x, y, z), v3(x + math.cos(a), y, z + math.sin(a)))
end

local function part(shape: string, color: Color3, size: Vector3, material: Enum.Material?, alpha: number?): BasePart
	local p = Pool.part(shape, color, size, material, alpha or 0)
	p.CastShadow = false
	return p
end

local function addLight(piece: Piece, holder: BasePart, color: Color3, range: number, live: Live)
	if live.low or not live.full or not Pool.takeLight() then
		return
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1.6
	l.Shadows = false
	l.Parent = holder
	piece.light = l
end

local function addGlow(piece: Piece, holder: BasePart, color: Color3, size: number, live: Live, key: string?)
	if live.low or not live.full then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.3), color)
	e.LightEmission = 1
	e.Rate = 30
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	if not Textures.particle(e, key or "glow") then
		Textures.plainParticle(e)
	end
	e.Parent = holder
	piece.emitter = e
end

local function addTrail(piece: Piece, holder: BasePart, color: Color3, width: number, live: Live)
	if live.low or not live.full then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = v3(0, width / 2, 0)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Position = v3(0, -width / 2, 0)
	a1.Parent = holder
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.3
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	Textures.trail(trail, "trailSoft")
	trail.Parent = holder
	piece.trail = trail
end

local function newPiece(): Piece
	return { parts = {}, spin = 0, lastRow = -1, lastBreath = -1 }
end

-- The body of a bolt by its look.
local function boltBody(inst: Hazards.Inst, live: Live): Piece
	local piece = newPiece()
	local color = live.color
	local r = inst.radius
	local look = inst.look
	if look == "axe" then
		local handle = part("Block", Color3.fromHex("#5A3E26"), v3(0.35, 0.35, 2.6), Enum.Material.Wood)
		local blade = part("Wedge", color, v3(0.18, 1.6, 1.2), Enum.Material.Metal)
		table.insert(piece.parts, handle)
		table.insert(piece.parts, blade)
		piece.spin = 14
		addTrail(piece, blade, Color3.fromHex("#E8E4D8"), 1.2, live)
	elseif look == "arrow" then
		local shaft = part("Block", Color3.fromHex("#8A6B4A"), v3(0.12, 0.12, 2.4), Enum.Material.Wood)
		local head = part("Block", color, v3(0.22, 0.22, 0.45), Enum.Material.Metal)
		table.insert(piece.parts, shaft)
		table.insert(piece.parts, head)
		addTrail(piece, shaft, WHITE, 0.15, live)
	elseif look == "rock" or look == "snowball" then
		local snow = look == "snowball"
		local ball = part(
			"Ball",
			if snow then Color3.fromHex("#EEF6FF") else Color3.fromHex("#6E655A"),
			Vector3.one * (r * (if snow then 2 else 1.4)),
			if snow then Enum.Material.Snow else Enum.Material.Slate
		)
		table.insert(piece.parts, ball)
		piece.spin = if snow then 6 else 9
	elseif look == "icicle" then
		local spike = part("Block", color, v3(0.5, 0.5, 3.2), Enum.Material.Glass, 0.15)
		table.insert(piece.parts, spike)
		addTrail(piece, spike, color, 0.5, live)
		addLight(piece, spike, color, 6, live)
	else
		-- orbs: soul, frost, fire, magma, a magic bolt
		local core = part("Ball", color:Lerp(WHITE, 0.35), Vector3.one * math.max(0.6, r * 0.9), Enum.Material.Neon)
		table.insert(piece.parts, core)
		local key = if look == "fireball" or look == "magma" then "flame" else "glow"
		if not Textures.id(key) then
			key = "glow"
		end
		addGlow(piece, core, color, r * 1.6, live, key)
		addTrail(piece, core, color, r * 1.2, live)
		addLight(piece, core, color, 8 + r * 2, live)
	end
	return piece
end

-- Places a bolt's body at (x, z) heading `a`.
local function placeBolt(piece: Piece, inst: Hazards.Inst, x: number, z: number, a: number, t: number)
	local y = inst.y + BOLT_Y
	local base = facing(x, y, z, a)
	local look = inst.look
	if look == "axe" then
		local spin = CFrame.Angles(t * piece.spin, 0, 0)
		local frame = base * CFrame.Angles(0, math.pi / 2, 0) * spin
		piece.parts[1].CFrame = frame
		piece.parts[2].CFrame = frame * CFrame.new(0, 0.5, -1.1)
	elseif look == "arrow" then
		piece.parts[1].CFrame = base
		piece.parts[2].CFrame = base * CFrame.new(0, 0, -1.4)
	elseif look == "rock" or look == "snowball" then
		local lift = if look == "snowball" then inst.radius - BOLT_Y else 0
		piece.parts[1].CFrame = (base + v3(0, lift, 0)) * CFrame.Angles(-t * piece.spin, 0, 0)
	else
		piece.parts[1].CFrame = base
	end
end

-- The lane of a straight bolt during its warning: a thin line along its path, filling up.
local function laneFor(inst: Hazards.Inst, live: Live): BasePart?
	if inst.homing > 0 or inst.delay < Hazards.MIN_WARN then
		return nil
	end
	local length = math.min(inst.range, inst.speed * inst.life, 60)
	local lane = part("Block", live.color, v3(inst.radius * 1.4, 0.08, length), Enum.Material.Neon, 1)
	lane.CFrame = facing(inst.x, inst.y + 0.15, inst.z, inst.a) * CFrame.new(0, 0, -length / 2)
	return lane
end

local function release(piece: Piece)
	for _, p in piece.parts do
		Pool.release(p)
	end
	table.clear(piece.parts)
	if piece.light then
		Pool.dropLight()
		piece.light = nil
	end
	if piece.lane then
		Pool.release(piece.lane)
		piece.lane = nil
	end
	if piece.stopTele then
		piece.stopTele = nil
	end
end

-- The impact of a hazard where it lands or hits: debris and dust for a body, the element's blast for a spell.
local function impact(live: Live, at: Vector3, size: number)
	local c = ctx
	local simple = live.low or not live.full
	local color = live.color
	Library.impactFlash(at + v3(0, 1, 0), math.clamp(size, 1.5, 6), color, { simple = simple })
	if simple then
		return
	end
	local look = live.pattern.look
	local lib = Library :: any
	if look == "meteor" or look == "fireball" or look == "magma" or look == "bomb" then
		if lib.fireBlast then
			lib.fireBlast(at + v3(0, 1, 0), size, color, {})
		end
	elseif look == "iceShard" or look == "frostOrb" or look == "icicle" or look == "snowball" then
		if lib.frostBlast then
			lib.frostBlast(at + v3(0, 1, 0), size, color, {})
		end
	elseif look == "boulder" or look == "rock" then
		if lib.rockBurst then
			lib.rockBurst(at, math.min(size * 2, 8), math.clamp(size / 3, 0.6, 1.8), color, {})
		end
	else
		Library.sparks(at + v3(0, 1, 0), color, { count = 8 })
	end
	if c and live.pattern.impactSound then
		c.play(live.pattern.impactSound, at)
	end
end

-- Starts the visuals of one instance at its `at` (its warning).
local function begin(live: Live, i: number, inst: Hazards.Inst, t: number)
	local piece = newPiece()
	local color = live.color
	local left = math.max(0.05, Hazards.liveFrom(inst) - t)
	if inst.kind == "bolt" then
		piece = boltBody(inst, live)
		placeBolt(piece, inst, inst.x, inst.z, inst.a, t)
		piece.lane = laneFor(inst, live)
	elseif inst.kind == "lob" then
		local look = inst.look
		local body = if look == "bomb"
			then part("Ball", Color3.fromHex("#2A2A2E"), Vector3.one * 1.6, Enum.Material.Metal)
			elseif look == "boulder" then part(
				"Ball",
				Color3.fromHex("#7C858F"),
				Vector3.one * 4,
				Enum.Material.Slate
			)
			elseif look == "meteor" then part(
				"Ball",
				Color3.fromHex("#4A2A1A"),
				Vector3.one * 3.4,
				Enum.Material.Basalt
			)
			else part("Block", color, v3(1.2, 4.5, 1.2), Enum.Material.Glass, 0.1)
		table.insert(piece.parts, body)
		if look == "meteor" or look == "bomb" then
			addGlow(piece, body, Color3.fromHex("#FF8A2A"), if look == "bomb" then 0.8 else 2.4, live, "flame")
		end
		if look ~= "bomb" then
			addTrail(piece, body, color, if look == "boulder" then 2 else 1.2, live)
		end
		local area = CFrame.new(inst.tx, inst.ty, inst.tz)
		GroundTelegraph.start({
			shape = "circle",
			dims = { r = inst.radius },
			area = area,
			windup = left,
			color = color,
			magic = false,
			low = live.low,
			rimWidth = if live.pattern.big then Config.Telegraph.rimWidthAvoid else nil,
		})
		if live.full and not live.low then
			Library.dangerMotes(area.Position, inst.radius, color, left, false)
		end
	elseif inst.kind == "wave" then
		if inst.width <= 30 then
			local area = facing(inst.x, inst.y, inst.z, inst.a)
			-- GroundTelegraph lines run along -Z of their frame: the same frame as the wave's
			GroundTelegraph.start({
				shape = "line",
				dims = { l = inst.length, w = inst.width },
				area = area,
				windup = left,
				color = color,
				magic = false,
				low = live.low,
				rimWidth = if live.pattern.big then Config.Telegraph.rimWidthAvoid else nil,
			})
		else
			-- a wall: blocks across its width (its gap left open) rise at its start during the warning
			local step = if live.low then 10 else 6
			local half = inst.width / 2
			local x = -half
			while x < half do
				local mid = x + step / 2
				if inst.gap <= 0 or math.abs(mid - inst.gapAt) > inst.gap / 2 + step / 2 then
					local block = part("Block", color, v3(step, 0.2, inst.thick), Enum.Material.Ice, 0.25)
					table.insert(piece.parts, block)
				end
				x += step
			end
		end
	elseif inst.kind == "ring" then
		local n = if live.low then 14 else 28
		for _ = 1, n do
			table.insert(piece.parts, part("Block", color:Lerp(DARK, 0.3), v3(1, 1.2, 1), Enum.Material.Slate))
		end
		if live.full and not live.low then
			Library.dangerMotes(v3(inst.x, inst.y, inst.z), 4, color, left, false)
		end
	elseif inst.kind == "sweep" then
		local start = inst.a + inst.from
		local frame = facing(inst.x, inst.y, inst.z, start)
		GroundTelegraph.start({
			shape = "cone",
			dims = { r = inst.radius, an = math.deg(inst.cone) },
			area = frame,
			windup = left,
			color = color,
			magic = true,
			low = live.low,
			rimWidth = Config.Telegraph.rimWidthAvoid,
		})
	end
	live.pieces[i] = piece
end

-- One frame of one instance; returns false when its visuals are over.
local function draw(live: Live, i: number, inst: Hazards.Inst, st: Hazards.State, t: number): boolean
	local piece = live.pieces[i]
	if not piece then
		return false
	end
	local start = Hazards.liveFrom(inst)
	local color = live.color
	local warming = t < start
	if inst.kind == "bolt" then
		if warming then
			-- hovering at its start, a gentle bob; the lane fills
			local k = 1 - (start - t) / math.max(0.05, inst.delay)
			placeBolt(piece, inst, inst.x, inst.z, inst.a, t)
			for _, p in piece.parts do
				p.CFrame += v3(0, math.sin(t * 6 + i) * 0.15, 0)
			end
			if piece.lane then
				piece.lane.Transparency = 1 - LANE_ALPHA * k
			end
			return true
		end
		if piece.lane then
			Pool.release(piece.lane)
			piece.lane = nil
		end
		placeBolt(piece, inst, st.x, st.z, st.a, t)
		return not st.done
	elseif inst.kind == "lob" then
		local k = math.clamp(1 - (start - t) / math.max(0.05, inst.delay), 0, 1)
		local body = piece.parts[1]
		local to = v3(inst.tx, inst.ty + 0.8, inst.tz)
		local look = inst.look
		local at
		if look == "meteor" or look == "iceShard" then
			local from = to + v3(-SKY_HEIGHT * 0.25, SKY_HEIGHT, -SKY_HEIGHT * 0.25)
			at = from:Lerp(to, k * k)
			body.CFrame = CFrame.lookAt(at, at + (to - from).Unit)
		else
			-- S159a: held over the caster until its flight, then the arc (the gesture throws it then)
			local from = v3(inst.x, inst.y + 6, inst.z)
			local flight = HazardGesture.flight(inst.delay)
			local f = math.clamp(1 - (start - t) / flight, 0, 1)
			local d = (to - from).Magnitude
			at = from:Lerp(to, f) + v3(0, 4 * LOB_HEIGHT * d * f * (1 - f), 0)
			if f <= 0 then
				at += v3(0, math.sin(t * 7 + i) * 0.12, 0)
			end
			body.CFrame = CFrame.new(at) * CFrame.Angles(t * 5 * f, t * 3 * f, 0)
		end
		if t >= start then
			impact(live, to, inst.radius * 0.6)
			if not live.low then
				Library.shockwave(to, inst.radius, color, 0.4, not live.full)
				if live.full then
					Library.dust(to, inst.radius * 0.4, false)
				end
			end
			return false
		end
		return true
	elseif inst.kind == "wave" then
		if warming then
			if inst.width > 30 then
				-- the wall rises during its warning
				local k = 1 - (start - t) / math.max(0.05, inst.delay)
				local step = if live.low then 10 else 6
				local h = 1 + 9 * k
				local base = facing(inst.x, inst.y, inst.z, inst.a)
				local x = -inst.width / 2
				local n = 0
				while x < inst.width / 2 do
					local mid = x + step / 2
					if inst.gap <= 0 or math.abs(mid - inst.gapAt) > inst.gap / 2 + step / 2 then
						n += 1
						local p = piece.parts[n]
						if p then
							p.Size = v3(step, h, inst.thick)
							-- the wave's side axis is the frame's -X (Logic/Hazards: side = -dx*sin + dz*cos)
							p.CFrame = base * CFrame.new(-mid, h / 2, 0)
						end
					end
					x += step
				end
			end
			return true
		end
		local tau = t - start
		local front = Hazards.frontAt(inst, tau)
		local base = facing(inst.x, inst.y, inst.z, inst.a)
		if inst.width > 30 then
			local n = 0
			local step = if live.low then 10 else 6
			local x = -inst.width / 2
			while x < inst.width / 2 do
				local mid = x + step / 2
				if inst.gap <= 0 or math.abs(mid - inst.gapAt) > inst.gap / 2 + step / 2 then
					n += 1
					local p = piece.parts[n]
					if p then
						p.CFrame = base * CFrame.new(-mid, p.Size.Y / 2, -front)
					end
				end
				x += step
			end
		else
			-- rows of spikes / flames popping up behind the front
			while piece.lastRow + ROW_STEP <= front do
				piece.lastRow = if piece.lastRow < 0 then 0 else piece.lastRow + ROW_STEP
				local across = math.max(1, math.floor(inst.width / (if live.low then 4 else 2.2)))
				for j = 1, across do
					local side = (j - 0.5) / across * inst.width - inst.width / 2
					local look = inst.look
					local spike = if look == "flameWall"
						then part("Block", color, v3(1.6, 0.4, 1.6), Enum.Material.Neon, 0.15)
						elseif look == "spikeWave" then part(
							"Wedge",
							color,
							v3(1.2, 0.4, 1.4),
							Enum.Material.Glass,
							0.1
						)
						else part("Wedge", Color3.fromHex("#6A5A48"), v3(1.4, 0.4, 1.6), Enum.Material.Slate)
					local height = if look == "flameWall" then 4.5 else 3.2
					local frame = base * CFrame.new(-side, 0, -piece.lastRow)
					spike.CFrame = frame
					Clock.tween(spike, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
						Size = v3(spike.Size.X, height, spike.Size.Z),
						CFrame = frame * CFrame.new(0, height / 2, 0),
					})
					Clock.after(0.45, function()
						Clock.tween(spike, TweenInfo.new(0.25), { Transparency = 1, CFrame = frame })
					end)
					Pool.later(spike, 0.75)
				end
				if live.full and not live.low then
					Library.dust((base * CFrame.new(0, 0, -piece.lastRow)).Position, 1.2, false)
				end
			end
		end
		return not st.done
	elseif inst.kind == "ring" then
		if warming then
			return true
		end
		local r = Hazards.frontAt(inst, t - start)
		local n = #piece.parts
		local fade = math.clamp(r / math.max(1, inst.maxRadius), 0, 1)
		for j, p in piece.parts do
			local a = (j - 0.5) / n * 2 * math.pi
			if Hazards.inRingGap(inst, a) then
				p.Transparency = 1
			else
				local arc = 2 * math.pi * math.max(r, 1) / n
				p.Size = v3(math.min(arc + 0.2, 6), 1.2 * (1 - 0.5 * fade) + 0.2, inst.thick * 0.6)
				p.CFrame = CFrame.new(inst.x + math.cos(a) * r, inst.y + p.Size.Y / 2, inst.z + math.sin(a) * r)
					* CFrame.Angles(0, -a + math.pi / 2, 0)
				p.Transparency = 0.1 + 0.6 * fade
			end
		end
		return not st.done
	end
	-- sweep
	if warming then
		return true
	end
	local tau = t - start
	if tau > inst.seconds then
		return false
	end
	local angle = Hazards.sweepAngle(inst, tau)
	if t - piece.lastBreath >= (if live.low then 0.4 else 0.2) then
		piece.lastBreath = t
		local frame = facing(inst.x, inst.y + 0.2, inst.z, angle)
		Library.cone(frame, inst.radius, math.deg(inst.cone), color, live.low or not live.full)
		if live.full and not live.low then
			local mouth = v3(inst.x, inst.y + 9, inst.z) + v3(math.cos(angle), 0, math.sin(angle)) * 4
			Library.sparks(mouth, color, {
				key = "iceShard",
				dir = v3(math.cos(angle), -0.25, math.sin(angle)),
				count = 10,
				speed = { 30, 46 },
				life = { 0.4, 0.8 },
				gravity = 6,
			})
		end
	end
	return true
end

local function stopCast(id: number)
	local live = casts[id]
	if not live then
		return
	end
	for _, piece in live.pieces do
		release(piece)
	end
	casts[id] = nil
	count -= 1
end

local function step()
	local t0 = now()
	for id, live in casts do
		local t = t0 - live.t0
		local aim = function(target: number): (number?, number?)
			local model = live.targets[target]
			local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				return root.Position.X, root.Position.Z
			end
			return nil, nil
		end
		local anyLeft = false
		for i, inst in live.insts do
			local st = live.states[i]
			if t < inst.at then
				anyLeft = true
				continue
			end
			if not live.started[i] then
				live.started[i] = true
				if not st.done then
					local ok, err = pcall(function()
						begin(live, i, inst, t)
						return true
					end)
					if not ok then
						warn(`[HazardFx] {err}`)
					end
				end
			end
			local piece = live.pieces[i]
			if not piece then
				continue
			end
			Hazards.advance(inst, st, t, aim, live.arena)
			local ok, alive = pcall(draw, live, i, inst, st, t)
			if not ok or not alive then
				if inst.kind == "bolt" and ok and st.done and (inst.bounce > 0 or inst.homing > 0) then
					-- a bolt that fades out where it ends (no hit): a small puff
					Library.impactFlash(v3(st.x, inst.y + BOLT_Y, st.z), 1.2, live.color, { simple = true })
				end
				release(piece)
				live.pieces[i] = nil
			else
				anyLeft = true
			end
		end
		if not anyLeft or t > live.ends + 2 then
			stopCast(id)
		end
	end
	if count <= 0 and connection then
		connection:Disconnect()
		connection = nil
		count = 0
	end
end

function HazardFx.init(context: Context)
	ctx = context
end

local function pointOf(v: any): Hazards.Point?
	if typeof(v) == "Vector3" then
		return { x = v.X, y = v.Y, z = v.Z }
	end
	return nil
end

-- A "hz" event: expands the cast and draws it until it ends.
-- S159a: returns the cast's instances (the caster's gesture turns with a breath), nil when it is not drawn.
function HazardFx.spawn(event: { [string]: any }): { Hazards.Inst }?
	local c = ctx
	local id = tonumber(event.g)
	local pattern = if type(event.p) == "string" then HazardPatterns.get(event.p) else nil
	local origin = pointOf(event.o)
	if not c or not id or not pattern or not origin or casts[id] then
		return nil
	end
	if count >= MAX_CASTS then
		return nil
	end
	local points: { Hazards.Point } = {}
	for _, v in (if type(event.tg) == "table" then event.tg else {}) :: { any } do
		local p = pointOf(v)
		if p then
			table.insert(points, p)
		end
	end
	local arena = nil
	if typeof(event.ar) == "Vector3" then
		arena = { x = event.ar.X, z = event.ar.Z, r = event.ar.Y }
	end
	local hz: Hazards.Cast = {
		seed = tonumber(event.sd) or 1,
		origin = origin,
		yaw = tonumber(event.y) or 0,
		targets = points,
		arena = arena,
		delay = tonumber(event.d),
	}
	local insts = Hazards.expand(pattern, hz)
	local states = {}
	for _, inst in insts do
		table.insert(states, Hazards.newState(inst))
	end
	local targets: { Model? } = {}
	for i, entityId in (if type(event.te) == "table" then event.te else {}) :: { any } do
		targets[i] = c.findModel(if type(entityId) == "string" and entityId ~= "" then entityId else nil)
	end
	local at = v3(origin.x, origin.y, origin.z)
	local live: Live = {
		id = id,
		pattern = pattern,
		insts = insts,
		states = states,
		pieces = {},
		started = {},
		t0 = tonumber(event.t0) or now(),
		color = Color3.fromHex(pattern.color),
		targets = targets,
		arena = arena,
		ends = Hazards.castEnds(insts),
		full = c.near(at),
		low = c.low(),
	}
	casts[id] = live
	count += 1
	if pattern.sound then
		c.play(pattern.sound, at)
	end
	if not connection then
		connection = RunService.Heartbeat:Connect(function()
			local ok, err = pcall(function()
				step()
				return true
			end)
			if not ok then
				warn(`[HazardFx] {err}`)
			end
		end)
	end
	return insts
end

-- "hzx": a bolt that hit someone: it bursts where it is.
function HazardFx.hit(event: { [string]: any })
	local live = casts[tonumber(event.g) or -1]
	local i = tonumber(event.i)
	if not live or not i then
		return
	end
	local st = live.states[i]
	local inst = live.insts[i]
	if st and inst then
		st.done = true
		impact(live, v3(st.x, inst.y + BOLT_Y - 1, st.z), inst.radius * 1.5)
	end
	local piece = live.pieces[i]
	if piece then
		release(piece)
		live.pieces[i] = nil
	end
end

-- "hzc": the caster died; its hazards vanish in a puff.
function HazardFx.clear(event: { [string]: any })
	local id = tonumber(event.g)
	local live = id and casts[id]
	if not live or not id then
		return
	end
	for i, piece in live.pieces do
		local p = piece.parts[1]
		if p then
			Library.impactFlash(p.Position, 1, live.color, { simple = true })
		end
		release(piece)
		live.pieces[i] = nil
	end
	stopCast(id)
end

-- Casts drawn now (AnimLab stats).
function HazardFx.activeCount(): number
	return count
end

return HazardFx
