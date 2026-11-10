--!strict
-- Skill juice (owner 2026-11-10, Data/SkillJuice): the pure choices behind Vfx/Juice. For every active skill: its style
-- (class and element), weight (light / medium / heavy), whether its blow helps (support: the punch lifts), where its
-- flare shows (a hand or the weapon's tip) and when (the cast's start, or the release of a gathered spell), our own
-- camera kick; how many particles a layer gets on this device and graphics level, whether a light may show, how much a
-- blow shakes a camera at a distance, and whether the cast voice (Data/Sfx skill.<id>.voice) plays.

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

-- Particles of a layer: `base` (the count on high) x the graphics level's particle share (W29), half when `simple` (far
-- away or low graphics), x othersShare for another player's skill, x touchShare on a phone; at least 1 when base > 0,
-- at most maxParticles and `cap` (the device's Config.Vfx.maxBurst).
function SkillJuice.count(
	base: number,
	quality: any,
	simple: boolean,
	own: boolean,
	touch: boolean,
	cap: number?
): number
	if base <= 0 then
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
