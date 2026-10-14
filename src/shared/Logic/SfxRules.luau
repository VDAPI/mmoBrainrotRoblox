--!strict
-- Sound effect rules (S111, DESIGN-16 §3): which Data/Sfx key an event plays and how the client mixes them. Pure
-- (Lune): random numbers come in as u in [0, 1) from the caller (SfxController uses client randomness, not Logic/Rng),
-- times as seconds, the config as Config.Sfx.

local Sfx = require("../Data/Sfx")
local SkillTypes = require("../Data/Skills/Types")

local SfxRules = {}

export type Who = "own" | "party" | "other"
-- One positional voice of the pool (SfxController keeps its Sound beside it).
export type Voice = { busy: boolean, priority: number, startedAt: number }
export type AttackKeys = { draw: string?, swing: string?, release: string? }
-- A skill as far as its sound goes (Data/Skills SkillDef fits).
export type SkillLike = { id: string, type: SkillTypes.SkillType, delivery: ("melee" | "ranged")? }
-- The part of Config.Sfx the volume reads.
export type MixConfig = { priorityVolume: { [string]: number }, lowQualityOther: number }

-- Priority of a sound by who caused it: our own beats the party's, the party's beats everyone else's.
SfxRules.PRIORITY = table.freeze({ own = 3, party = 2, other = 1 }) :: { [string]: number }

-- Basic attack motion (Data/AttackMotions) -> its keys: `draw` at 0, `swing` at the start of the blow (windup end),
-- `release` when the arrow / bolt / spell leaves (the hit time).
local ATTACK_KEYS: { [string]: AttackKeys } = {
	slash1h = { swing = "swing.light" },
	unarmed = { swing = "swing.light" },
	slash2h = { swing = "swing.heavy" },
	smash = { swing = "swing.blunt" },
	thrust = { swing = "swing.thrust" },
	bow = { draw = "bow.draw", release = "bow.release" },
	crossbow = { release = "crossbow.release" },
	wand = { release = "wand.cast" },
	staff = { release = "wand.cast" },
}

function SfxRules.attackKeys(motion: string): AttackKeys
	local keys = ATTACK_KEYS[motion] or ATTACK_KEYS.unarmed
	return { draw = keys.draw, swing = keys.swing, release = keys.release }
end

-- Material of a monster hit: the look's hitSound, else the family's, else "flesh".
function SfxRules.material(familyId: string?, hitSound: string?): string
	if hitSound and table.find(Sfx.MATERIALS, hitSound) then
		return hitSound
	end
	local byFamily = if familyId then Sfx.FAMILY_MATERIAL[familyId] else nil
	return byFamily or "flesh"
end

-- The hit key of a material: hit.<material> when it has a sound, else hit.flesh (a silent material still sounds like a
-- hit). `playable` is Sfx.playable (injected for tests).
function SfxRules.hitKey(material: string, playable: (string) -> boolean): string
	local key = "hit." .. material
	return if playable(key) then key else "hit.flesh"
end

-- Default sound of every skill kind (Data/Skills/Types SkillType); `passive` has none. `target` and `charge` depend on
-- the delivery (kindDefault).
SfxRules.KIND_DEFAULT = table.freeze({
	target = "skill.default.strike",
	charge = "skill.default.strike",
	projectile = "skill.default.cast",
	chain = "skill.default.cast",
	beam = "skill.default.cast",
	debuff = "skill.default.cast",
	circleSelf = "skill.default.blast",
	circleTarget = "skill.default.blast",
	cone = "skill.default.blast",
	line = "skill.default.blast",
	heal = "skill.default.heal",
	groupHeal = "skill.default.heal",
	hot = "skill.default.heal",
	healZone = "skill.default.heal",
	resurrect = "skill.default.heal",
	buff = "skill.default.buff",
	shield = "skill.default.buff",
	groupBuff = "skill.default.buff",
	shout = "skill.default.buff",
	guard = "skill.default.buff",
	banner = "skill.default.buff",
	channel = "skill.default.buff",
	blink = "skill.default.dash",
	trap = "skill.default.trap",
	companion = "skill.default.call",
}) :: { [string]: string }

local UNKNOWN_KIND = "skill.default.cast"

-- The default key of a skill's kind; nil for passives. A ranged single-target hit is a cast, a charge that is not a
-- melee blow is a dash.
function SfxRules.kindDefault(skill: SkillLike): string?
	if skill.type == "passive" then
		return nil
	end
	if skill.type == "target" and skill.delivery ~= "melee" then
		return "skill.default.cast"
	end
	if skill.type == "charge" and skill.delivery ~= "melee" then
		return "skill.default.dash"
	end
	return SfxRules.KIND_DEFAULT[skill.type] or UNKNOWN_KIND
end

-- The key a skill impact plays: SkillVfx.sound when it is a playable key, else "skill.<id>" when playable, else the
-- default of the skill's kind; nil for passives. `playable` is Sfx.playable (injected for tests). The default may
-- itself be silent (empty ids): then nothing plays.
function SfxRules.skillKey(skill: SkillLike, vfxSound: string?, playable: (string) -> boolean): string?
	if skill.type == "passive" then
		return nil
	end
	if vfxSound and vfxSound ~= "" and playable(vfxSound) then
		return vfxSound
	end
	local own = "skill." .. skill.id
	if playable(own) then
		return own
	end
	return SfxRules.kindDefault(skill)
end

-- Index of the voice to use: a free one, else the one easiest to lose (lowest priority, then oldest) when its
-- priority is <= the new one's; nil = drop the new sound. The pool never grows.
function SfxRules.pickVoice(voices: { Voice }, priority: number): number?
	local best: number? = nil
	for i, voice in voices do
		if not voice.busy then
			return i
		end
		if voice.priority <= priority then
			local current = if best then voices[best] else nil
			if
				current == nil
				or voice.priority < current.priority
				or (voice.priority == current.priority and voice.startedAt < current.startedAt)
			then
				best = i
			end
		end
	end
	return best
end

-- Key of the per-source cooldown record of `key` (lastBySource).
function SfxRules.sourceKey(key: string, source: string): string
	return source .. "|" .. key
end

-- Whether `key` may play now: not within `window` seconds of the same key, and (keys with a cooldown) not within the
-- cooldown of the same key from the same source. The caller records the times (lastByKey[key],
-- lastBySource[sourceKey(key, source)]) when the sound plays.
function SfxRules.allowed(
	lastByKey: { [string]: number },
	lastBySource: { [string]: number },
	key: string,
	source: string?,
	now: number,
	def: Sfx.Def,
	window: number
): boolean
	local last = lastByKey[key]
	if last and now - last < window then
		return false
	end
	local cooldown = def.cooldown
	if cooldown and source then
		local lastFrom = lastBySource[SfxRules.sourceKey(key, source)]
		if lastFrom and now - lastFrom < cooldown then
			return false
		end
	end
	return true
end

-- PlaybackSpeed for u in [0, 1): min + (max - min) * u.
function SfxRules.pitch(def: Sfx.Def, u: number): number
	local low, high = def.pitch[1], def.pitch[2]
	return low + (high - low) * math.clamp(u, 0, 1)
end

-- Variant index 1..#ids for u in [0, 1), nil when there are no ids.
function SfxRules.variant(def: Sfx.Def, u: number): number?
	local n = #def.ids
	if n == 0 then
		return nil
	end
	return math.clamp(math.floor(u * n) + 1, 1, n)
end

-- Final volume: def.volume * priorityVolume[who] (* lowQualityOther for "other" on low quality).
function SfxRules.volume(def: Sfx.Def, who: Who, lowQuality: boolean, cfg: MixConfig): number
	local factor = cfg.priorityVolume[who] or cfg.priorityVolume.other
	if who == "other" and lowQuality then
		factor *= cfg.lowQualityOther
	end
	return def.volume * factor
end

-- The higher of two priorities (a hit on us is ours even when someone else struck it).
function SfxRules.higher(a: Who, b: Who): Who
	return if (SfxRules.PRIORITY[a] or 1) >= (SfxRules.PRIORITY[b] or 1) then a else b
end

return SfxRules
