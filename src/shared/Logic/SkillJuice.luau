--!strict
-- Skill juice (owner 2026-11-10, Data/SkillJuice): the pure choices behind Vfx/Juice. For every active skill: its style
-- (class and element), weight (light / medium / heavy), whether its blow helps (support: the punch lifts), where its
-- flare shows (a hand or the weapon's tip) and when (the cast's start, or the release of a gathered spell), our own
-- camera kick; how many particles a layer gets on this device and graphics level, whether a light may show, how much a
-- blow shakes a camera at a distance, and whether the cast voice (Data/Sfx skill.<id>.voice) plays.
-- Owner 2026-11-10 (DECYZJE: fewer particles on lower graphics, on a phone and for other players; in group fights on a
-- phone the juice took the shared effect pools, so skill pieces, hit sparks and boss breaths were dropped): which
-- layers a flare and a punch play (flareLayers / punchLayers: the extras only for our own skills near the camera, a
-- later wave of the same cast only its core and ring) and whether a layer may take one more of a pool (room: never the
-- reserve of the device's limit, Config.Vfx.juice.reserve).

local Config = require("../Config")
local GraphicsLevel = require("./GraphicsLevel")
local SkillJuiceData = require("../Data/SkillJuice")
local SkillTypes = require("../Data/Skills/Types")
local SkillVfx = require("../Data/SkillVfx")

local SkillJuice = {}

-- A skill (Data/Skills SkillDef) and its look (Data/SkillVfx entry); tests pass the real ones.
export type SkillLike = SkillTypes.SkillDef
export type EntryLike = SkillVfx.Entry

export type Plan = {
	style: string, -- Data/SkillJuice.STYLES key
	weight: string, -- Data/SkillJuice.WEIGHTS key
	support: boolean, -- the blow helps: the punch lifts (motes rise; no puff, chips or kick of its own)
	anchor: string, -- "l" | "r" | "both" | "weapon": where the flare shows
	flareAt: string, -- "start" (the cast event) | "release" (a gathered spell: when it is let go)
	shake: number, -- our own camera kick when the blow lands (0 = none)
}

-- Kinds that neither strike nor help much: a light punch unless the skill shakes or stops the blow.
local QUIET: { [string]: boolean } = { debuff = true, trap = true, blink = true, companion = true }
local LIGHTER: { [string]: string } = { heavy = "medium", medium = "light", light = "light" }

-- The weight of a skill: Data/SkillJuice.LIGHT / HEAVY by name; a finisher or a shake of at least heavyShake is heavy;
-- any other shake or a hitstop is medium; support and quiet kinds are light; every other blow is medium.
function SkillJuice.weightOf(skill: SkillLike, entry: EntryLike?): string
	if SkillJuiceData.LIGHT[skill.id] then
		return "light"
	end
	if SkillJuiceData.HEAVY[skill.id] or skill.finisher ~= nil then
		return "heavy"
	end
	local shake = if entry then entry.shake or 0 else 0
	if shake >= Config.Vfx.juice.heavyShake then
		return "heavy"
	end
	if shake > 0 or (entry ~= nil and entry.hitstop ~= nil) then
		return "medium"
	end
	if SkillJuiceData.SUPPORT[skill.type] or QUIET[skill.type] then
		return "light"
	end
	return "medium"
end

-- One step lighter (later waves, further targets, later links of a chain).
function SkillJuice.lighter(weight: string): string
	return LIGHTER[weight] or "light"
end

-- Where the flare shows: SkillVfx.launch, else the glowing hand, else by class (the Hunter's bow is in the left hand,
-- a trap leaves the right one; the Cleric heals from the left hand; everything else from the weapon's tip).
function SkillJuice.anchorOf(skill: SkillLike, entry: EntryLike?): string
	if entry then
		if entry.launch then
			return entry.launch
		end
		if entry.glow then
			return entry.glow.hand
		end
	end
	if skill.class == "Hunter" then
		return if skill.type == "trap" then "r" else "l"
	end
	if skill.class == "Cleric" and SkillJuiceData.HEALS[skill.type] then
		return "l"
	end
	return "weapon"
end

-- Our own camera kick of a skill: its SkillVfx.shake, at least the weight's (support blows: only their own).
function SkillJuice.ownShake(weight: string, support: boolean, entryShake: number?): number
	local own = entryShake or 0
	if support then
		return own
	end
	local w = SkillJuiceData.WEIGHTS[weight]
	return math.max(own, if w then w.shake else 0)
end

-- The whole juice of a skill whose look takes `element` (the event's weapon element of an adaptive skill, else nil =
-- the skill's own).
function SkillJuice.plan(skill: SkillLike, entry: EntryLike?, element: any): Plan
	local el = if type(element) == "string" then element else skill.element
	local weight = SkillJuice.weightOf(skill, entry)
	local support = SkillJuiceData.SUPPORT[skill.type] == true
	local castFx = if entry then entry.castFx else nil
	return {
		style = SkillJuiceData.styleOf(skill.class, skill.type, el),
		weight = weight,
		support = support,
		anchor = SkillJuice.anchorOf(skill, entry),
		flareAt = if castFx and #castFx > 0 then "release" else "start",
		shake = SkillJuice.ownShake(weight, support, if entry then entry.shake else nil),
	}
end

-- Particle layers a cast may go without (owner 2026-11-10, the juice gives way): the "extra" ones (the flare's motes,
-- the punch's puff and chips) play only for our own skills near the camera, the "spray" (the punch's burst) also for
-- others' skills near the camera and our own far / low ones; a far skill of another player shows its core and ring.
local OPTIONAL: { [string]: string } = { motes = "extra", puff = "extra", chips = "extra", burst = "spray" }

-- Whether the particle `layer` (a Data/SkillJuice weight field: motes, burst, puff, chips) plays for a cast that is
-- `simple` (far away or low graphics) and `own` (ours); nil and unknown layers always do.
function SkillJuice.layerOn(layer: string?, simple: boolean, own: boolean): boolean
	local kind = if layer then OPTIONAL[layer] else nil
	if kind == "extra" then
		return own and not simple
	elseif kind == "spray" then
		return own or not simple
	end
	return true
end

-- Particles of a layer: `base` (the count on high) x the graphics level's particle share (W29), half when `simple` (far
-- away or low graphics), x othersShare for another player's skill, x touchShare on a phone; at least 1 when base > 0,
-- at most maxParticles and `cap` (the device's Config.Vfx.maxBurst). A `layer` the cast goes without (layerOn) gets 0,
-- so it takes no holder at all.
function SkillJuice.count(
	base: number,
	quality: any,
	simple: boolean,
	own: boolean,
	touch: boolean,
	cap: number?,
	layer: string?
): number
	if base <= 0 or not SkillJuice.layerOn(layer, simple, own) then
		return 0
	end
	local cfg = Config.Vfx.juice
	local share = GraphicsLevel.get(quality).particles
	if simple then
		share *= 0.5
	end
	if not own then
		share *= cfg.othersShare
	end
	if touch then
		share *= cfg.touchShare
	end
	local limit = math.min(cfg.maxParticles, cap or cfg.maxParticles)
	return math.clamp(math.floor(base * share + 0.5), 1, limit)
end

-- Whether a juice light may show: never simple or on low graphics; our own skills always, others' only heavy ones.
function SkillJuice.lightOn(quality: any, simple: boolean, own: boolean, weight: string): boolean
	if simple or quality == "low" then
		return false
	end
	return own or weight == "heavy"
end

-- What a flare or a punch plays besides its core, which always plays (Vfx/Juice draws exactly this; tests/SkillLooks
-- counts the holders). A particle count of 0 is no layer.
export type Layers = {
	motes: number, -- the flare's particles
	rays: boolean, -- the punch's rays of light round the core (holy)
	spray: number, -- the punch's spray of the style's particles
	puff: number, -- the punch's puff of dust, smoke or mist
	ring: boolean, -- the punch's ring on the ground (a ground image)
	chips: number, -- the punch's chips of rock or wood (heavy blows)
	arcs: number, -- the punch's short lightning arcs (beams)
	light: boolean, -- the fading PointLight
}

-- How this client sees a block: settings.quality, far away or low graphics, our own skill, a phone and the device's
-- particles per Emit (Config.Vfx.maxBurst).
export type View = { quality: any, simple: boolean, own: boolean, touch: boolean, cap: number? }

local function noLayers(): Layers
	return { motes = 0, rays = false, spray = 0, puff = 0, ring = false, chips = 0, arcs = 0, light = false }
end

local function layerCount(base: number, view: View, layer: string): number
	return SkillJuice.count(base, view.quality, view.simple, view.own, view.touch, view.cap, layer)
end

-- The flare of a cast of `weight`: its core, the motes of our own skill near the camera, a light (lightOn).
function SkillJuice.flareLayers(weight: string, view: View): Layers
	local w = SkillJuiceData.WEIGHTS[weight] or SkillJuiceData.WEIGHTS.medium
	local out = noLayers()
	out.motes = layerCount(w.motes, view, "motes")
	out.light = SkillJuice.lightOn(view.quality, view.simple, view.own, weight)
	return out
end

-- The punch of a blow of `style` and `weight` (`support`: a helping blow, no puff, chips or arcs). Owner 2026-11-10
-- (the juice gives way): a `later` wave of the same cast (circleSelf and per-wave circleTarget waves, a storm's later
-- strikes, a second shot) keeps the beat with its core and ring only; the first one punches fully.
function SkillJuice.punchLayers(style: string, weight: string, view: View, support: boolean, later: boolean): Layers
	local s = SkillJuiceData.STYLES[style] or SkillJuiceData.STYLES.arcane
	local w = SkillJuiceData.WEIGHTS[weight] or SkillJuiceData.WEIGHTS.medium
	local out = noLayers()
	out.ring = s.ring ~= nil
	if later then
		return out
	end
	out.rays = s.rays == true and not view.simple
	out.spray = layerCount(w.burst, view, "burst")
	if not support then
		out.puff = if s.puff then layerCount(w.puff, view, "puff") else 0
		out.chips = if s.chips then layerCount(w.chips, view, "chips") else 0
		if s.arcs and not view.simple and weight ~= "light" then
			out.arcs = if weight == "heavy" then 2 else 1
		end
	end
	out.light = SkillJuice.lightOn(view.quality, view.simple, view.own, weight)
	return out
end

-- Holders or lights of a device `limit` the juice never takes: `share` of it, rounded up (Config.Vfx.juice.reserve).
function SkillJuice.reserve(limit: number, share: number): number
	return math.clamp(math.ceil(limit * share - 1e-9), 0, math.max(0, limit))
end

-- Whether a juice layer may take one more of a pool with `used` of `limit` live: only while the reserve stays free for
-- the skills' own pieces, hit sparks, boss breath layers and telegraph lights (the juice is what gives way).
function SkillJuice.room(used: number, limit: number, share: number): boolean
	return used < limit - SkillJuice.reserve(limit, share)
end

-- How hard a blow of `strength` landing `distance` studs away shakes our camera: fading to nothing at shakeRange;
-- others' skills x othersShake, our own at least ownFloor of the strength wherever they land.
function SkillJuice.shakeAt(strength: number?, distance: number, own: boolean): number
	local s = strength or 0
	if s <= 0 then
		return 0
	end
	local cfg = Config.Vfx.juice
	local k = math.max(0, 1 - distance / cfg.shakeRange)
	if own then
		return s * math.max(k, cfg.ownFloor)
	end
	return s * k * cfg.othersShake
end

-- Whether the cast voice skill.<id>.voice plays: it has an id, the skill has no wind-up sound of its own
-- (skill.<id>.cast with an id) and the first blow or shot comes at least voiceGap s after the cast (`firstAt`).
-- `playable` is Data/Sfx.playable (injected for tests).
function SkillJuice.voiced(skillId: string, firstAt: number?, playable: (string) -> boolean): boolean
	if playable(`skill.{skillId}.cast`) or not playable(`skill.{skillId}.voice`) then
		return false
	end
	return (firstAt or 0) >= Config.Vfx.juice.voiceGap
end

-- The sound of a projectile of `style` arriving (Data/Sfx skill.impact.<style>), nil when the style has none.
function SkillJuice.impactKey(style: string, playable: (string) -> boolean): string?
	local key = `skill.impact.{style}`
	return if playable(key) then key else nil
end

return SkillJuice
