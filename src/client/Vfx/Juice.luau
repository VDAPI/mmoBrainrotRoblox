--!strict
-- Skill juice (owner 2026-11-10: "umiejętności mają mieć większą dynamikę: dźwięk, wybuch, partikle"): the two shared
-- building blocks every active skill gets on top of its own pieces, driven by data (Data/SkillJuice styles, motions and
-- weights; Logic/SkillJuice picks them per skill):
--   flare(at, o)   the cast: a bright core flashing at the hand or the weapon's tip, particles of the style thrown
--                  out (steel glints, holy motes, leaves, flames, ice shards, sparks, arcane stars) and a short light
--   punch(at, o)   the blow: a bigger core (holy: rays), a spray of the style's particles (steel sparks away from the
--                  caster, embers, shards, crackling sparks, bubbles; helping blows lift motes instead), a puff (dust,
--                  smoke, mist), a ground ring, chips of rock thrown on heavy blows, short lightning arcs (lightning) and
--                  a light that fades
-- Everything from Vfx/Library.kit (pooled emitter and ground-image holders within the device limits, the effect clock,
-- the textures with their fallbacks): a layer whose texture is missing, off or over the limit is skipped, the skills
-- window preview (a ViewportFrame) shows none of it. Particle counts come from Logic/SkillJuice.count (graphics level,
-- far away / low, another player's skill, a phone); lights only near, not on low, for our own skills or heavy ones.
-- At its peak a flare holds 2 emitters and a light, a punch at most 5 emitters (core, rays, spray, puff, chips), one
-- ground image, a light and 2 lightning beams; the skill's own pieces play first, so under the device limits
-- (Config.Vfx.max*) the juice is what gives way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Library)
local Pool = require(script.Parent.Pool)
local SkillJuice = require(ReplicatedStorage.Shared.Logic.SkillJuice)
local SkillJuiceData = require(ReplicatedStorage.Shared.Data.SkillJuice)
local State = require(script.Parent.Parent.UI.State)

local kit = Library.kit
local kp = kit.kp

local Juice = {}

export type Opts = {
	style: string, -- Data/SkillJuice.STYLES key
	weight: string, -- Data/SkillJuice.WEIGHTS key
	color: Color3, -- the skill's colour (VfxController.colorOf)
	simple: boolean, -- far away or low graphics
	own: boolean, -- our own skill (full particles, a light)
	support: boolean?, -- the blow helps: motes rise, no puff, chips or arcs
	radius: number?, -- the skill's own radius: the ground ring is never wider
	dir: Vector3?, -- punch: from the caster to the blow (steel sparks fly on away from the caster)
}

local WHITE = Color3.new(1, 1, 1)
local ROCK = Color3.fromHex("#6E6256")
local WOOD = Color3.fromHex("#8A6B4A")
local FLARE_CORE = 2.4 -- studs of the flare's core at weight 1
local PUNCH_CORE = 3.2 -- studs of the punch's core at weight 1
local RING_GROW = 2.2 -- Library's ring texture ends RING_GROW x its radius wide (kit.ringSurface)

local rng = Random.new()

local function quality(): any
	return State.Get({ "account", "settings", "quality" })
end

local function styleOf(o: Opts): SkillJuiceData.Style
	return SkillJuiceData.STYLES[o.style] or SkillJuiceData.STYLES.arcane
end

local function weightOf(o: Opts): SkillJuiceData.Weight
	return SkillJuiceData.WEIGHTS[o.weight] or SkillJuiceData.WEIGHTS.medium
end

-- Particles of a layer of `base` on high for this device, level and caster.
local function count(base: number, o: Opts): number
	local touch = Pool.isTouch()
	local cap = if touch then Config.Vfx.maxBurst.touch else Config.Vfx.maxBurst.desktop
	return SkillJuice.count(base, quality(), o.simple, o.own, touch, cap)
end

-- One bright particle of `key` at `at`: grows from a third to `size` and fades in `seconds` (the core of a flash).
local function flash(at: Vector3, key: string, color: Color3, size: number, seconds: number, spin: number?)
	local holder = kit.textured(key, CFrame.new(at))
	if not holder then
		return
	end
	kit.burstFrom(holder, key, color, 1, {
		exact = true,
		lifeMin = seconds,
		lifeMax = seconds,
		sizeSeq = NumberSequence.new({ kp(0, size * 0.35), kp(0.35, size), kp(1, size * 0.75) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.5, 0.2), kp(1, 1) }),
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-(spin or 120), spin or 120),
		zOffset = 1,
		emission = 1,
	})
end

-- A burst of `n` particles of `key` moving by the motion `motionName` (Data/SkillJuice.MOTIONS), `scale` x its speed
-- and partly its size; `dir` aims a streak spray (65 degrees round it) instead of every way.
local function layer(
	at: Vector3,
	key: string,
	motionName: string,
	color: Color3,
	to: Color3,
	n: number,
	scale: number,
	dir: Vector3?
)
	if n <= 0 then
		return
	end
	local m = SkillJuiceData.MOTIONS[motionName] or SkillJuiceData.MOTIONS.drift
	local aimed = dir ~= nil and dir.Magnitude > 0.01 and m.parallel == true and not m.up
	local frame = if aimed and dir then kit.facingFrame(at, dir) else CFrame.new(at)
	local holder = kit.textured(key, frame)
	if not holder then
		return
	end
	local sizeScale = 0.6 + 0.4 * scale
	kit.burstFrom(holder, key, color, n, {
		exact = true,
		to = to,
		direction = if aimed then Enum.NormalId.Front else Enum.NormalId.Top,
		spread = if aimed then 65 else m.spread,
		speedMin = m.speed[1] * scale,
		speedMax = m.speed[2] * scale,
		drag = m.drag,
		accel = Vector3.new(m.accel[1], m.accel[2], m.accel[3]),
		lifeMin = m.life[1],
		lifeMax = m.life[2],
		sizeSeq = NumberSequence.new({ kp(0, m.size[1] * sizeScale), kp(1, m.size[2] * sizeScale) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.7, 0.25), kp(1, 1) }),
		orient = if m.parallel then "parallel" else nil,
		rotation = if m.spin then NumberRange.new(0, 360) else nil,
		rotSpeed = if m.spin then NumberRange.new(-m.spin, m.spin) else nil,
		area = Vector3.one * 0.5 * scale,
	})
end

-- A PointLight at `at` flaring to `brightness` and fading out over `seconds` (within the device's light budget).
local function fadingLight(at: Vector3, color: Color3, range: number, brightness: number, seconds: number)
	if range <= 0 or not Pool.takeLight() then
		return
	end
	local holder = Pool.part("Ball", color, Vector3.one * 0.2, Enum.Material.SmoothPlastic, 1)
	holder.CFrame = CFrame.new(at)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = holder
	kit.tween(light, seconds, { Brightness = 0, Range = range * 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Clock.after(seconds + 0.03, function()
		Pool.release(holder) -- the light goes with the holder's children
		Pool.dropLight()
	end)
end

-- The colour of the style's particles, ring and light: the style's own (steel glints, holy gold) taking `share` of
-- the skill's colour (the class, the element, the weapon's element).
local function tintOf(style: SkillJuiceData.Style, color: Color3): Color3
	return Color3.fromHex(style.glow):Lerp(color, style.share)
end

-- The cast's flare at `at` (the hand or the weapon's tip).
function Juice.flare(at: Vector3, o: Opts)
	if Pool.inViewport() then
		return
	end
	local style = styleOf(o)
	local w = weightOf(o)
	local tint = tintOf(style, o.color)
	local core = tint:Lerp(WHITE, style.white)
	flash(at, style.core, core, FLARE_CORE * w.flare, 0.16)
	layer(at, style.motes, style.moteMotion, core, tint, count(w.motes, o), 0.6 * w.flare, nil)
	if SkillJuice.lightOn(quality(), o.simple, o.own, o.weight) then
		local cfg = Config.Vfx.juice
		fadingLight(at, tint, w.light * 0.6, cfg.lightBrightness * 0.6, cfg.lightTime * 0.6)
	end
end

-- The blow's punch at `at`.
function Juice.punch(at: Vector3, o: Opts)
	if Pool.inViewport() then
		return
	end
	local style = styleOf(o)
	local w = weightOf(o)
	local scale = w.punch
	local tint = tintOf(style, o.color)
	local core = tint:Lerp(WHITE, style.white)
	local support = o.support == true
	flash(at, style.core, core, PUNCH_CORE * scale, 0.18)
	if style.rays and not o.simple then
		flash(at, "rays", core, PUNCH_CORE * 2 * scale, 0.4, 40)
	end
	-- the spray: the style's own motion, or rising motes for a helping blow
	local motion = if support then "rise" else style.burstMotion
	layer(at, style.burst, motion, core, tint, count(w.burst, o), scale, if support then nil else o.dir)
	local floor = kit.ground(at)
	if style.puff and not support then
		local smoke = if style.puffColor then Color3.fromHex(style.puffColor) else tint:Lerp(Color3.new(0, 0, 0), 0.5)
		layer(floor + Vector3.new(0, 0.5, 0), style.puff, "cloud", smoke, smoke, count(w.puff, o), scale, nil)
	end
	if style.ring then
		local radius = math.min(w.ring, o.radius or w.ring)
		-- a dust ring keeps the colour of dust (a touch of the skill's), a ring of light the skill's colour
		local ringTint = if style.ring == "dustRing" and style.puffColor
			then Color3.fromHex(style.puffColor):Lerp(o.color, 0.15)
			else tint
		kit.ringSurface(floor, radius / (RING_GROW / 2), ringTint, 0.3 + 0.08 * scale, style.ring)
	end
	if style.chips and not support and w.chips > 0 then
		local chip = if o.style == "hunt" then WOOD else ROCK
		layer(floor + Vector3.new(0, 0.4, 0), "debris", "chips", chip, chip, count(w.chips, o), 1, nil)
	end
	if style.arcs and not support and not o.simple and o.weight ~= "light" then
		local arcs = if o.weight == "heavy" then 2 else 1
		for i = 1, arcs do
			local angle = (i / arcs) * math.pi * 2 + rng:NextNumber(0, 1.2)
			local reach = 2.5 + rng:NextNumber(0, 2) * scale
			local to = floor + Vector3.new(math.cos(angle) * reach, 0.1, math.sin(angle) * reach)
			Library.lightning(at, to, core, 0.12 * scale, o.simple)
		end
	end
	if SkillJuice.lightOn(quality(), o.simple, o.own, o.weight) then
		local cfg = Config.Vfx.juice
		fadingLight(at + Vector3.new(0, 1, 0), tint, w.light, cfg.lightBrightness, cfg.lightTime)
	end
end

return Juice
