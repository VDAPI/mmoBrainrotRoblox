--!strict
-- Owner 2026-11-10 (skill juice): every active skill of the four classes flares at the cast, punches where it lands
-- and has a sound at the cast and at the blow (Data/SkillJuice, Logic/SkillJuice, Data/Sfx skill.<id>.voice); the
-- camera kick (Logic/CameraShake) and the particle / light budgets by graphics level, device and caster.

local fs = require("@lune/fs")

local CameraShake = require("../src/shared/Logic/CameraShake")
local Config = require("../src/shared/Config")
local GraphicsLevel = require("../src/shared/Logic/GraphicsLevel")
local Sfx = require("../src/shared/Data/Sfx")
local SfxRules = require("../src/shared/Logic/SfxRules")
local SkillData = require("../src/shared/Data/Skills")
local SkillJuice = require("../src/shared/Logic/SkillJuice")
local SkillJuiceData = require("../src/shared/Data/SkillJuice")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Test = require("./Test")
local VfxTextures = require("../src/shared/Data/VfxTextures")

local describe, it, expect = Test.describe, Test.it, Test.expect

local CLASSES = { "Warrior", "Cleric", "Hunter", "Mage" }
-- What each class may look like (the owner's identity: steel, holy light, the wood and its poisons, the elements).
local CLASS_STYLES: { [string]: { [string]: boolean } } = {
	Warrior = { steel = true },
	Cleric = { holy = true, heal = true },
	Hunter = { hunt = true, venom = true, ice = true, lightning = true },
	Mage = { fire = true, ice = true, lightning = true, arcane = true },
}

local function actives(class: string): { SkillData.SkillDef }
	local out = {}
	for _, skill in SkillData.byClass[class] do
		if skill.type ~= "passive" then
			table.insert(out, skill)
		end
	end
	return out
end

local function skill(id: string): SkillData.SkillDef
	return SkillData.get(id) :: SkillData.SkillDef
end

local function plan(id: string): SkillJuice.Plan
	return SkillJuice.plan(skill(id), SkillVfx[id], nil)
end

describe("Skill juice data (owner 2026-11-10)", function()
	it("every style's textures are uploaded effect textures and its motions exist", function()
		for name, style in SkillJuiceData.STYLES do
			local keys = { style.core, style.motes, style.burst, style.puff, style.ring }
			for _, key in keys do
				expect({ name, key, VfxTextures.idOf(key) ~= nil }).toEqual({ name, key, true })
			end
			for _, motion in { style.moteMotion, style.burstMotion } do
				expect({ name, motion, SkillJuiceData.MOTIONS[motion] ~= nil }).toEqual({ name, motion, true })
			end
			expect({ name, style.white >= 0 and style.white <= 1 }).toEqual({ name, true })
			expect({ name, style.share >= 0 and style.share <= 1 }).toEqual({ name, true })
			expect({ name, string.match(style.glow, "^#%x%x%x%x%x%x$") ~= nil }).toEqual({ name, true })
			if style.puffColor then
				expect({ name, string.match(style.puffColor, "^#%x%x%x%x%x%x$") ~= nil }).toEqual({ name, true })
			end
		end
		-- the layers the punch adds by name
		for _, key in { "rays", "debris", "glow" } do
			expect({ key, VfxTextures.idOf(key) ~= nil }).toEqual({ key, true })
		end
		expect(SkillJuiceData.MOTIONS.cloud ~= nil and SkillJuiceData.MOTIONS.chips ~= nil).toBe(true)
	end)

	it("motions are sane: ranges in order, short lives, spreads within a half sphere", function()
		for name, m in SkillJuiceData.MOTIONS do
			expect({ name, m.speed[1] >= 0 and m.speed[1] <= m.speed[2] }).toEqual({ name, true })
			expect({ name, m.life[1] > 0 and m.life[1] <= m.life[2] and m.life[2] <= 1.5 }).toEqual({ name, true })
			expect({ name, #m.accel, m.size[1] > 0, m.size[2] >= 0 }).toEqual({ name, 3, true, true })
			expect({ name, m.spread > 0 and m.spread <= 180, m.drag >= 0 }).toEqual({ name, true, true })
		end
	end)

	it("weights grow from light to heavy; only heavy blows throw chips and kick by themselves", function()
		local light, medium, heavy =
			SkillJuiceData.WEIGHTS.light, SkillJuiceData.WEIGHTS.medium, SkillJuiceData.WEIGHTS.heavy
		for _, field in { "flare", "punch", "motes", "burst", "puff", "ring", "light" } do
			local l, m, h = (light :: any)[field], (medium :: any)[field], (heavy :: any)[field]
			expect({ field, l <= m and m < h }).toEqual({ field, true })
		end
		expect({ light.chips, medium.chips, heavy.chips > 0 }).toEqual({ 0, 0, true })
		expect({ light.shake, medium.shake, heavy.shake > 0 }).toEqual({ 0, 0, true })
		-- the heaviest layer stays within one Emit of a phone (Config.Vfx.maxBurst.touch) after the phone's share
		expect(heavy.burst * Config.Vfx.juice.touchShare <= Config.Vfx.maxBurst.touch).toBe(true)
		expect(heavy.burst <= Config.Vfx.juice.maxParticles).toBe(true)
	end)

	it("the named heavy and light skills exist and are active", function()
		for _, list in { SkillJuiceData.HEAVY, SkillJuiceData.LIGHT } do
			for id in list do
				local def = SkillData.get(id)
				expect({ id, def ~= nil and def.type ~= "passive" }).toEqual({ id, true })
				expect({ id, SkillJuiceData.HEAVY[id] == true and SkillJuiceData.LIGHT[id] == true }).toEqual({
					id,
					false,
				})
			end
		end
	end)
end)

describe("Skill juice of every class (owner 2026-11-10)", function()
	it(
		"every active skill: the class's look, a weight, a flare point, a punch and sounds at the cast and the blow",
		function()
			local total = 0
			for _, class in CLASSES do
				for _, def in actives(class) do
					total += 1
					local p = SkillJuice.plan(def, SkillVfx[def.id], nil)
					expect({ def.id, CLASS_STYLES[class][p.style] == true }).toEqual({ def.id, true })
					expect({ def.id, SkillJuiceData.WEIGHTS[p.weight] ~= nil }).toEqual({ def.id, true })
					local anchors = { l = true, r = true, both = true, weapon = true }
					expect({ def.id, anchors[p.anchor] == true }).toEqual({ def.id, true })
					expect({ def.id, p.flareAt == "start" or p.flareAt == "release" }).toEqual({ def.id, true })
					-- a sound when the cast starts (its own wind-up or the juice voice) and at the blow
					local castSound = Sfx.playable(`skill.{def.id}.cast`) or Sfx.playable(`skill.{def.id}.voice`)
					local blowSound = SfxRules.skillKey(def, SkillVfx[def.id].sound, Sfx.playable)
					expect({ def.id, castSound, blowSound ~= nil and Sfx.playable(blowSound :: string) }).toEqual({
						def.id,
						true,
						true,
					})
				end
			end
			expect(total >= 100).toBe(true)
		end
	)

	it(
		"each class keeps its identity: steel for the Warrior, light for the Cleric, the elements for the Mage",
		function()
			expect(plan("mightyStrike").style).toBe("steel")
			expect(plan("holyStrike").style).toBe("holy")
			expect(plan("heal").style).toBe("heal")
			expect(plan("aimedShot").style).toBe("hunt")
			expect(plan("venomArrow").style).toBe("venom")
			expect(plan("stormArrow").style).toBe("lightning")
			expect(plan("fireball").style).toBe("fire")
			expect(plan("iceShard").style).toBe("ice")
			expect(plan("chainLightning").style).toBe("lightning")
			expect(plan("arcaneDischarge").style).toBe("arcane")
			-- an adaptive look takes the weapon's element (the event's `el`)
			expect(SkillJuice.plan(skill("arcaneDischarge"), SkillVfx.arcaneDischarge, "fire").style).toBe("fire")
			expect(SkillJuice.plan(skill("mightyStrike"), SkillVfx.mightyStrike, "fire").style).toBe("steel")
		end
	)

	it("weights: finishers and strong shakes are heavy, helping skills light, other blows medium", function()
		expect(plan("execute").weight).toBe("heavy") -- a finisher
		expect(plan("heartseeker").weight).toBe("heavy") -- a finisher
		expect(plan("earthquake").weight).toBe("heavy") -- shake 0.6
		expect(plan("meteor").weight).toBe("heavy")
		expect(plan("pyroblast").weight).toBe("heavy") -- named
		expect(plan("mightyStrike").weight).toBe("medium")
		expect(plan("firebolt").weight).toBe("medium")
		expect(plan("heal").weight).toBe("light")
		expect(plan("manaShield").weight).toBe("light")
		expect(plan("huntersMark").weight).toBe("light") -- named
		expect(plan("frostTrap").weight).toBe("light") -- a quiet kind
		expect(SkillJuice.lighter("heavy")).toBe("medium")
		expect(SkillJuice.lighter("medium")).toBe("light")
		expect(SkillJuice.lighter("light")).toBe("light")
		-- every heavy blow that harms kicks our camera; helping blows only by their own shake
		for _, class in CLASSES do
			for _, def in actives(class) do
				local p = SkillJuice.plan(def, SkillVfx[def.id], nil)
				if p.weight == "heavy" and not p.support then
					expect({ def.id, p.shake >= SkillJuiceData.WEIGHTS.heavy.shake }).toEqual({ def.id, true })
				end
				if p.support then
					expect({ def.id, p.shake }).toEqual({ def.id, SkillVfx[def.id].shake or 0 })
				end
			end
		end
	end)

	it("the flare shows at the hand or the weapon; a gathered spell flares when it is let go", function()
		expect(plan("mightyStrike").anchor).toBe("weapon")
		expect(plan("aimedShot").anchor).toBe("l") -- the bow hand
		expect(plan("frostTrap").anchor).toBe("r") -- the throwing hand
		expect(plan("heal").anchor).toBe("l")
		expect(plan("fireball").anchor).toBe("both") -- SkillVfx launch
		expect(plan("aimedShot").flareAt).toBe("release") -- lmCharge gathers first
		expect(plan("mightyStrike").flareAt).toBe("start")
	end)
end)

describe("Skill juice sounds (owner 2026-11-10)", function()
	it("every active skill has its own cast voice; no two skills of a class share one", function()
		for _, class in CLASSES do
			local seen: { [string]: string } = {}
			for _, def in actives(class) do
				local key = `skill.{def.id}.voice`
				local d = Sfx.get(key)
				expect({ key, d ~= nil and #d.ids == 1 }).toEqual({ key, true })
				if d then
					local voice = `{d.ids[1]}@{d.pitch[1]}`
					expect({ key, seen[voice] }).toEqual({ key, nil })
					seen[voice] = def.id
					expect({ key, d.volume < 0.65 }).toEqual({ key, true }) -- under the blow's own sound
				end
			end
		end
	end)

	it("voices use only sound files already checked in docs/ASSETS.md", function()
		local assets = fs.readFile("docs/ASSETS.md")
		local used: { [string]: boolean } = {}
		for _, key in Sfx.keys("skill.") do
			if string.match(key, "%.voice$") or string.sub(key, 1, 13) == "skill.impact." then
				for _, id in Sfx.defs[key].ids do
					used[id] = true
				end
			end
		end
		for name, id in Sfx.VOICE_IDS do
			expect({ name, string.find(assets, id, 1, true) ~= nil }).toEqual({ name, true })
		end
		for id in used do
			expect({ id, string.find(assets, id, 1, true) ~= nil }).toEqual({ id, true })
		end
		for style, voice in SkillJuiceData.VOICES do
			for _, name in voice.ids do
				expect({ style, name, Sfx.VOICE_IDS[name] ~= nil }).toEqual({ style, name, true })
			end
		end
	end)

	it(
		"the cast voice plays without a wind-up of the skill's own and only when the blow does not follow at once",
		function()
			local playable = function(key: string): boolean
				return key == "skill.a.voice" or key == "skill.b.voice" or key == "skill.b.cast"
			end
			local gap = Config.Vfx.juice.voiceGap
			expect(SkillJuice.voiced("a", gap, playable)).toBe(true)
			expect(SkillJuice.voiced("a", gap * 0.5, playable)).toBe(false) -- the blow's own sound says it
			expect(SkillJuice.voiced("a", nil, playable)).toBe(false)
			expect(SkillJuice.voiced("b", 1, playable)).toBe(false) -- its own wind-up plays instead
			expect(SkillJuice.voiced("c", 1, playable)).toBe(false) -- no voice
			expect(SkillJuice.voiced("mightyStrike", 0.3, Sfx.playable)).toBe(true)
			expect(SkillJuice.voiced("earthquake", 0.48, Sfx.playable)).toBe(false) -- skill.earthquake.cast
		end
	)

	it("spells sound where their projectile lands; arrows and steel keep the hit material", function()
		for _, style in { "fire", "ice", "lightning", "arcane", "holy", "venom" } do
			expect({ style, SkillJuice.impactKey(style, Sfx.playable) }).toEqual({ style, `skill.impact.{style}` })
		end
		expect(SkillJuice.impactKey("hunt", Sfx.playable)).toBeNil()
		expect(SkillJuice.impactKey("steel", Sfx.playable)).toBeNil()
	end)
end)

describe("Skill juice budgets (owner 2026-11-10)", function()
	it("particles scale with the graphics level, far away, another player's skill and a phone", function()
		local high = SkillJuice.count(20, "high", false, true, false)
		local medium = SkillJuice.count(20, "medium", false, true, false)
		local low = SkillJuice.count(20, "low", false, true, false)
		expect(high).toBe(20)
		expect(medium).toBe(math.floor(20 * GraphicsLevel.get("medium").particles + 0.5))
		expect(low < medium and medium < high).toBe(true)
		expect(SkillJuice.count(20, "high", true, true, false)).toBe(10) -- far away / simple
		expect(SkillJuice.count(20, "high", false, false, false) < high).toBe(true) -- someone else's
		expect(SkillJuice.count(20, "high", false, true, true) < high).toBe(true) -- a phone
		expect(SkillJuice.count(20, "high", false, true, false, 12)).toBe(12) -- the device's cap
		expect(SkillJuice.count(500, "high", false, true, false)).toBe(Config.Vfx.juice.maxParticles)
		expect(SkillJuice.count(0, "high", false, true, false)).toBe(0)
		expect(SkillJuice.count(2, "low", true, false, true)).toBe(1) -- never nothing when asked for some
	end)

	it("lights: near, never on low; our own skills, others' only heavy", function()
		expect(SkillJuice.lightOn("high", false, true, "light")).toBe(true)
		expect(SkillJuice.lightOn("high", false, false, "medium")).toBe(false)
		expect(SkillJuice.lightOn("high", false, false, "heavy")).toBe(true)
		expect(SkillJuice.lightOn("high", true, true, "heavy")).toBe(false)
		expect(SkillJuice.lightOn("low", false, true, "heavy")).toBe(false)
	end)

	it("a blow shakes cameras near it: others' half and fading, our own wherever it lands", function()
		local range = Config.Vfx.juice.shakeRange
		expect(SkillJuice.shakeAt(0.4, 0, false)).toBeNear(0.4 * Config.Vfx.juice.othersShake, 1e-9)
		expect(SkillJuice.shakeAt(0.4, range, false)).toBe(0)
		expect(SkillJuice.shakeAt(0.4, range * 2, false)).toBe(0)
		expect(SkillJuice.shakeAt(0.4, 0, true)).toBeNear(0.4, 1e-9)
		expect(SkillJuice.shakeAt(0.4, range * 2, true)).toBeNear(0.4 * Config.Vfx.juice.ownFloor, 1e-9)
		expect(SkillJuice.shakeAt(nil, 0, true)).toBe(0)
		expect(SkillJuice.shakeAt(0, 0, true)).toBe(0)
	end)
end)

describe("Camera kick (owner 2026-11-10)", function()
	local function kick(amp: number, start: number, seconds: number, seed: number): CameraShake.Kick
		return { amp = amp, start = start, seconds = seconds, seed = seed }
	end

	it("the size follows the strength, the Hit feel option and the graphics level", function()
		local full = CameraShake.amp(0.5, 1, "high")
		expect(full).toBeNear(0.5 * Config.Vfx.shake.studs, 1e-9)
		expect(CameraShake.amp(0.5, nil, "high")).toBeNear(full, 1e-9)
		expect(CameraShake.amp(0.5, 0, "high")).toBe(0) -- the option off
		expect(CameraShake.amp(0.5, 0.5, "high")).toBeNear(full * 0.5, 1e-9)
		local low, medium = CameraShake.amp(0.5, 1, "low"), CameraShake.amp(0.5, 1, "medium")
		expect(low < medium and medium < full).toBe(true)
		expect(CameraShake.amp(0.5, 1, "unknown")).toBeNear(full, 1e-9)
		expect(CameraShake.amp(9, 1, "high")).toBeNear(Config.Vfx.shake.maxStrength * Config.Vfx.shake.studs, 1e-9)
		expect(CameraShake.amp(-1, 1, "high")).toBe(0)
		expect(CameraShake.seconds(1) > CameraShake.seconds(0.2)).toBe(true)
		expect(CameraShake.seconds(1) <= 0.6).toBe(true) -- a kick, not a sway
	end)

	it("a kick fades from its start to its end and never moves the camera past the cap", function()
		local k = kick(1, 10, 0.3, 1.3)
		expect(CameraShake.envelope(k, 0)).toBe(1)
		expect(CameraShake.envelope(k, 0.15) < 1 and CameraShake.envelope(k, 0.15) > 0).toBe(true)
		expect(CameraShake.envelope(k, 0.3)).toBe(0)
		expect(CameraShake.envelope(k, -0.1)).toBe(0)
		local x, y = CameraShake.offset({}, 10)
		expect({ x, y }).toEqual({ 0, 0 })
		local many = {}
		for i = 1, 12 do
			table.insert(many, kick(2, 0, 0.5, i))
		end
		local moved = false
		for t = 0, 0.5, 0.01 do
			local ox, oy = CameraShake.offset(many, t)
			expect(math.abs(ox) <= Config.Vfx.shake.maxStuds and math.abs(oy) <= Config.Vfx.shake.maxStuds).toBe(true)
			if math.abs(ox) > 0.05 or math.abs(oy) > 0.05 then
				moved = true
			end
		end
		expect(moved).toBe(true)
		-- the same kicks at the same moment give the same offset (no hidden randomness)
		local ax, ay = CameraShake.offset({ kick(0.5, 0, 0.3, 2) }, 0.07)
		local bx, by = CameraShake.offset({ kick(0.5, 0, 0.3, 2) }, 0.07)
		expect({ ax, ay }).toEqual({ bx, by })
	end)

	it("prune drops the kicks that ended", function()
		local list = { kick(1, 0, 0.2, 1), kick(1, 0, 0.5, 2), kick(1, 0.3, 0.2, 3) }
		expect(CameraShake.prune(list, 0.25)).toBe(2)
		expect(CameraShake.prune(list, 0.6)).toBe(0)
		expect(#list).toBe(0)
	end)
end)
