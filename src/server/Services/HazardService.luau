--!strict
-- S159 (owner 2026-10-21): the server's dodgeable hazards (Logic/Hazards, Data/HazardPatterns): boss projectiles,
-- lobbed rocks, waves, walls, rings and breaths, and the monsters' regular arrows and bolts. A cast expands its pattern
-- from a seed, steps every instance each Heartbeat and tests the players near it; the server alone decides a hit. The
-- clients get one "hz" event per cast (pattern, seed, origin, aim, targets) through CombatService's fx batch and run the
-- same expansion and kinematics to draw it (Vfx/HazardFx); "hzx" removes a bolt that hit, "hzc" a whole cast whose
-- caster died. CombatService plugs in the damage, the fx batch and who may be hit (SetHandlers), so this service has
-- no dependency on it (CombatService depends on this one).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HazardPatterns = require(ReplicatedStorage.Shared.Data.HazardPatterns)
local Hazards = require(ReplicatedStorage.Shared.Logic.Hazards)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("HazardService")

local HazardService = {
	Name = "HazardService",
	Deps = {},
}

-- What a cast carries besides its pattern.
export type CastOpts = {
	origin: Vector3, -- the ground point it starts from
	yaw: number?, -- Hazards angle the cast faces (default: towards the first target)
	targets: { Player }?, -- aimed players (homing follows them; their position now is their point)
	points: { Vector3 }?, -- fixed points instead (or for) the targets, in the same order
	damage: number, -- x the caster's attack per hit (x the emitter's share)
	element: string?,
	damageKind: string?,
	delivery: string?,
	delay: number?, -- the least warning of every instance (a boss attack's windup)
	arena: { x: number, z: number, r: number }?, -- the bounce circle
	attackId: string?, -- the client's pose and sound (a boss attack or a pattern id)
	windup: number?, -- seconds the caster poses (default the delay)
	only: Player?, -- only this player can be hit (regular shots)
	fxRadius: number?, -- studs round the origin whose players see it (default from the pattern's reach)
	params: any?, -- regular shots: the Damage.Params of the blow (CombatService)
}

export type Cast = {
	id: number,
	caster: any,
	patternId: string,
	pattern: Hazards.Pattern,
	opts: CastOpts,
	insts: { Hazards.Inst },
	states: { Hazards.State },
	targets: { Player },
	started: number, -- os.clock()
	ends: number, -- cast seconds after which nothing of it is left
	reach: number,
	origin: Vector3,
	taken: { [Player]: number },
	lastAt: { [Player]: number },
	hitList: { Player },
}

export type Handlers = {
	-- a hit of `inst` of `cast` on `player` (the damage, the dmg event)
	hit: (cast: Cast, inst: Hazards.Inst, player: Player) -> (),
	-- whether `player` may be hit now (alive, playing, not in a safe zone)
	canHit: (player: Player) -> boolean,
	-- the fx batch (CombatService.QueueFx with a radius)
	fx: (position: Vector3, event: { [string]: any }, radius: number?) -> (),
	-- the caster's entity id for the clients (nil = none)
	entityId: (caster: any) -> string?,
	-- a player's entity id (homing targets on the clients)
	playerEntityId: (player: Player) -> string?,
	-- a boss pattern ended: who was aimed at and who was hit (the fight meter's dodges)
	resolved: ((cast: Cast, aimed: { Player }, hit: { Player }) -> ())?,
}

local handlers: Handlers? = nil
local casts: { Cast } = {}
local nextId = 0
local random = Random.new()

-- Casts at most at once (a runaway pattern never floods the server); a new one past it is dropped.
local MAX_CASTS = 400
-- Extra studs of fx radius past the pattern's reach.
local FX_MARGIN = 30

function HazardService.SetHandlers(h: Handlers)
	handlers = h
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function point(v: Vector3): Hazards.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Starts a cast of `patternId` by `caster`; its id, or nil (unknown pattern, no handlers, too many casts).
function HazardService.Cast(caster: any, patternId: string, opts: CastOpts): number?
	local pattern = HazardPatterns.get(patternId)
	local h = handlers
	if not pattern or not h or #casts >= MAX_CASTS then
		if not pattern then
			log:warn("unknown pattern %s", patternId)
		end
		return nil
	end
	nextId = (nextId % 1000000) + 1
	local id = nextId
	local seed = random:NextInteger(1, 2147483646)
	-- the aimed points as the clients will get them (Vector3 over the wire)
	local targets: { Player } = {}
	local aimPoints: { Vector3 } = {}
	local aimed: { Player } = opts.targets or {}
	for i, player in aimed do
		local p: Vector3? = opts.points and opts.points[i]
		if not p then
			local root = rootOf(player)
			p = if root then root.Position - Vector3.new(0, Hazards.ROOT_HEIGHT, 0) else nil
		end
		if p then
			table.insert(targets, player)
			table.insert(aimPoints, p)
		end
	end
	if not opts.targets and opts.points then
		for _, p in opts.points do
			table.insert(aimPoints, p)
		end
	end
	local origin = opts.origin
	local yaw = opts.yaw
	if yaw == nil then
		local first = aimPoints[1]
		yaw = if first then Hazards.angleTo(origin.X, origin.Z, first.X, first.Z) else 0
	end
	local castPoints: { Hazards.Point } = {}
	for _, p in aimPoints do
		table.insert(castPoints, point(p))
	end
	local hz: Hazards.Cast = {
		seed = seed,
		origin = point(origin),
		yaw = yaw :: number,
		targets = castPoints,
		arena = opts.arena,
		delay = opts.delay,
	}
	local insts = Hazards.expand(pattern, hz)
	if #insts == 0 then
		return nil
	end
	local states = {}
	for _, inst in insts do
		table.insert(states, Hazards.newState(inst))
	end
	local reach = Hazards.reach(insts, hz.origin)
	local cast: Cast = {
		id = id,
		caster = caster,
		patternId = patternId,
		pattern = pattern,
		opts = opts,
		insts = insts,
		states = states,
		targets = targets,
		started = os.clock(),
		ends = Hazards.castEnds(insts),
		reach = reach,
		origin = origin,
		taken = {},
		lastAt = {},
		hitList = {},
	}
	table.insert(casts, cast)
	local entityIds = {}
	for _, player in targets do
		table.insert(entityIds, h.playerEntityId(player) or "")
	end
	h.fx(origin, {
		k = "hz",
		g = id,
		p = patternId,
		e = h.entityId(caster),
		t0 = Workspace:GetServerTimeNow(),
		o = origin,
		y = yaw,
		tg = aimPoints,
		te = entityIds,
		sd = seed,
		ar = if opts.arena then Vector3.new(opts.arena.x, opts.arena.r, opts.arena.z) else nil,
		d = opts.delay,
		a = opts.attackId,
		w = opts.windup,
		el = opts.element,
	}, opts.fxRadius or (reach + FX_MARGIN))
	return id
end

-- Drops every cast of `caster` (it died or was removed); the clients drop their pieces.
function HazardService.ClearCaster(caster: any)
	local h = handlers
	for i = #casts, 1, -1 do
		local cast = casts[i]
		if cast.caster == caster then
			table.remove(casts, i)
			if h then
				h.fx(cast.origin, { k = "hzc", g = cast.id }, cast.reach + FX_MARGIN)
			end
		end
	end
end

-- Casts in flight (admin stats, tests of the wiring).
function HazardService.ActiveCount(): number
	return #casts
end

local function casterAlive(caster: any): boolean
	if type(caster) ~= "table" then
		return false
	end
	local alive = caster.IsAlive
	return type(alive) ~= "function" or alive(caster) == true
end

local function finish(cast: Cast)
	local h = handlers
	if h and h.resolved and not cast.pattern.regular and #cast.targets > 0 then
		h.resolved(cast, cast.targets, cast.hitList)
	end
end

-- The players' root positions of this Heartbeat, read once for every cast (a world boss fight runs dozens of casts
-- next to the regular shots of the hunting grounds: no GetPlayers / FindFirstChild per cast and frame).
local framePlayers: { Player } = {}
local framePos: { [Player]: Vector3 } = {}

local function snapshot()
	table.clear(framePlayers)
	table.clear(framePos)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			table.insert(framePlayers, player)
			framePos[player] = root.Position
		end
	end
end

-- Candidates of a cast this tick: players near its origin (or only its target).
local function candidates(cast: Cast): { Player }
	local only = cast.opts.only
	if only then
		return if only.Parent and framePos[only] then { only } else {}
	end
	local list = {}
	for _, player in framePlayers do
		if (framePos[player] - cast.origin).Magnitude <= cast.reach then
			table.insert(list, player)
		end
	end
	return list
end

local function step(cast: Cast, h: Handlers): boolean
	if not casterAlive(cast.caster) then
		h.fx(cast.origin, { k = "hzc", g = cast.id }, cast.reach + FX_MARGIN)
		return false
	end
	local t = os.clock() - cast.started
	local function aim(target: number): (number?, number?)
		local player = cast.targets[target]
		local at = player and framePos[player]
		if at then
			return at.X, at.Z
		end
		return nil, nil
	end
	local players = candidates(cast)
	local positions: { Vector3 } = {}
	local usable: { Player } = {}
	for _, player in players do
		local at = framePos[player]
		if at and h.canHit(player) then
			table.insert(usable, player)
			table.insert(positions, at)
		end
	end
	local alive = false
	for i, inst in cast.insts do
		local st = cast.states[i]
		if st.done then
			continue
		end
		Hazards.advance(inst, st, t, aim, cast.opts.arena)
		for k, player in usable do
			if not Hazards.mayHit(cast.pattern, cast.taken[player] or 0, cast.lastAt[player], t) then
				continue
			end
			local p = positions[k]
			if Hazards.hits(inst, st, p.X, p.Y, p.Z, inst.y) then
				cast.taken[player] = (cast.taken[player] or 0) + 1
				cast.lastAt[player] = t
				if not table.find(cast.hitList, player) then
					table.insert(cast.hitList, player)
				end
				h.hit(cast, inst, player)
				if inst.kind == "bolt" then
					st.done = true
					h.fx(p, { k = "hzx", g = cast.id, i = inst.index }, cast.reach + FX_MARGIN)
					break
				end
			end
		end
		if not st.done then
			alive = true
		end
	end
	return alive and t <= cast.ends + 1
end

function HazardService.Init(_registry: any) end

function HazardService.Start()
	RunService.Heartbeat:Connect(function()
		local h = handlers
		if not h or #casts == 0 then
			return
		end
		snapshot()
		for i = #casts, 1, -1 do
			local cast = casts[i]
			local ok, alive = pcall(step, cast, h)
			if not ok then
				log:error("cast %s failed: %s", cast.patternId, tostring(alive))
			end
			if not ok or not alive then
				table.remove(casts, i)
				if ok then
					finish(cast)
				end
			end
		end
		-- no Player kept past the frame (a player who left is not held until the next cast)
		table.clear(framePlayers)
		table.clear(framePos)
	end)
end

return HazardService
