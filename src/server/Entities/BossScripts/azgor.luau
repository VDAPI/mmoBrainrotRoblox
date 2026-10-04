--!strict
-- Azgor, Lord of Flames (boss 70). Data (Data/Bosses): fire waves along a line at a random player, flame
-- cleave, meteors under every player; phase 2 (70 %) fire golems every 30 s; phase 3 (35 %) inferno ring.
-- The script adds the lava field of phase 3: the floor beyond a safe circle turns to lava and the safe
-- circle shrinks from 50 to 20 studs over two minutes; standing on lava burns every second.

local Azgor = {}

local LAVA_RADIUS = 64
local SAFE_START = 50
local SAFE_END = 20
local SHRINK_SECONDS = 120
local TICK = 1

local function makeDisc(name: string, radius: number, centre: CFrame, color: string, height: number): Part
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = Color3.fromHex(color)
	disc.Size = Vector3.new(0.3, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(centre.Position + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = workspace
	return disc
end

function Azgor.onPhase(boss: any, phase: number)
	if phase ~= 3 or boss.lava then
		return
	end
	local centre = boss.centre :: CFrame
	local lava = makeDisc("AzgorLava", LAVA_RADIUS, centre, "#E8541A", 0.15)
	lava.Transparency = 0.15
	local safe = makeDisc("AzgorSafe", SAFE_START, centre, "#3A2A22", 0.25)
	safe.Material = Enum.Material.Basalt
	boss.lava = { lava = lava, safe = safe, started = os.clock(), nextTick = os.clock() + TICK }
end

function Azgor.onTick(boss: any, now: number)
	local state = boss.lava
	if not state then
		return
	end
	local t = math.clamp((now - state.started) / SHRINK_SECONDS, 0, 1)
	local radius = SAFE_START + (SAFE_END - SAFE_START) * t
	state.safe.Size = Vector3.new(0.3, radius * 2, radius * 2)
	if now < state.nextTick then
		return
	end
	state.nextTick = now + TICK
	boss:Hazard({
		id = "lava",
		shape = "ring",
		origin = "self",
		radius = LAVA_RADIUS + 10,
		inner = radius,
		windup = 0,
		damage = 0.7,
		cooldown = TICK,
		element = "fire",
		damageKind = "magic",
	}, CFrame.new(boss.centre.Position))
end

function Azgor.onDestroy(boss: any)
	local state = boss.lava
	if state then
		state.lava:Destroy()
		state.safe:Destroy()
		boss.lava = nil
	end
end

return Azgor
