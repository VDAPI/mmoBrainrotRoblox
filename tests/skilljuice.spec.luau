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

-- Owner 2026-11-10 (DECYZJE: fewer particles on lower graphics, on a phone and for other players; in group fights on a
-- phone the juice took the shared effect pools, so skill pieces, hit sparks and boss breaths were dropped).
describe("The juice gives way (owner 2026-11-10)", function()
	local SkillLooks = require("./SkillLooks")

	local function view(own: boolean, simple: boolean): SkillJuice.View
		return { quality = "high", simple = simple, own = own, touch = false }
	end
	local OWN, OWN_FAR = view(true, false), view(true, true)
	local OTHERS, OTHERS_FAR = view(false, false), view(false, true)

	local function occurrences(text: string, needle: string): number
		local n, from = 0, 1
		while true do
			local at = string.find(text, needle, from, true)
			if not at then
				return n
			end
			n += 1
			from = at + #needle
		end
	end

	it("motes, puff and chips only for our own skills near the camera, no spray for others' far ones", function()
		-- a layer the cast goes without counts 0, so it takes no holder at all
		expect(SkillJuice.count(10, "high", false, true, false, nil, "motes")).toBe(10)
		expect(SkillJuice.count(10, "high", true, true, false, nil, "motes")).toBe(0) -- our own far / low
		expect(SkillJuice.count(10, "high", false, false, false, nil, "motes")).toBe(0) -- someone else's
		for _, layer in { "puff", "chips" } do
			expect({ layer, SkillJuice.count(9, "low", false, true, true, nil, layer) > 0 }).toEqual({ layer, true })
			expect({ layer, SkillJuice.count(9, "high", true, true, false, nil, layer) }).toEqual({ layer, 0 })
			expect({ layer, SkillJuice.count(9, "high", false, false, false, nil, layer) }).toEqual({ layer, 0 })
		end
		expect(SkillJuice.count(16, "low", true, true, true, nil, "burst") > 0).toBe(true) -- our own far: the spray
		expect(SkillJuice.count(16, "high", false, false, false, nil, "burst") > 0).toBe(true) -- others' near
		expect(SkillJuice.count(16, "high", true, false, false, nil, "burst")).toBe(0) -- others' far: none
		-- a count without a layer and the cores (no optional layer) always play
		expect(SkillJuice.count(16, "high", true, false, false) > 0).toBe(true)
		expect(SkillJuice.layerOn(nil, true, false)).toBe(true)
		expect(SkillJuice.layerOn("rays", true, false)).toBe(true)
	end)

	it("a flare: its core always, motes and a light for our own cast near the camera", function()
		local own = SkillJuice.flareLayers("medium", OWN)
		expect(own.motes > 0 and own.light).toBe(true)
		local others = SkillJuice.flareLayers("medium", OTHERS)
		expect({ others.motes, others.light }).toEqual({ 0, false })
		expect(SkillJuice.flareLayers("heavy", OTHERS).light).toBe(true) -- others' heavy casts still light up
		local far = SkillJuice.flareLayers("heavy", OWN_FAR)
		expect({ far.motes, far.light }).toEqual({ 0, false })
	end)

	it("a punch: everything for our own blow near the camera, the core, spray and ring for others'", function()
		local own = SkillJuice.punchLayers("steel", "heavy", OWN, false, false)
		expect({ own.spray > 0, own.puff > 0, own.chips > 0, own.ring, own.light, own.arcs, own.rays }).toEqual({
			true,
			true,
			true,
			true,
			true,
			0,
			false,
		})
		local others = SkillJuice.punchLayers("steel", "heavy", OTHERS, false, false)
		expect({ others.spray > 0, others.puff, others.chips, others.ring, others.light }).toEqual({
			true,
			0,
			0,
			true,
			true,
		})
		local far = SkillJuice.punchLayers("lightning", "heavy", OTHERS_FAR, false, false)
		expect({ far.spray, far.arcs, far.rays, far.light, far.ring }).toEqual({ 0, 0, false, false, true })
		expect(SkillJuice.punchLayers("lightning", "heavy", OWN, false, false).arcs).toBe(2)
		expect(SkillJuice.punchLayers("lightning", "medium", OTHERS, false, false).arcs).toBe(1)
		expect(SkillJuice.punchLayers("lightning", "light", OWN, false, false).arcs).toBe(0)
		expect(SkillJuice.punchLayers("lightning", "heavy", OWN, true, false).arcs).toBe(0) -- a helping blow
		local holy = SkillJuice.punchLayers("holy", "medium", OWN, false, false)
		expect({ holy.rays, holy.puff, holy.chips }).toEqual({ true, 0, 0 })
		expect(SkillJuice.punchLayers("holy", "medium", OWN_FAR, false, false).rays).toBe(false)
	end)

	it("a later wave, strike or shot of the same cast flashes only its core and ring", function()
		for style, s in SkillJuiceData.STYLES do
			for weight in SkillJuiceData.WEIGHTS do
				for _, v in { OWN, OWN_FAR, OTHERS, OTHERS_FAR } do
					for _, support in { false, true } do
						local cost = SkillLooks.juiceOf(nil, SkillJuice.punchLayers(style, weight, v, support, true))
						expect({ style, weight, cost }).toEqual({
							style,
							weight,
							{ emitters = 1, beams = 0, lights = 0, decals = if s.ring then 1 else 0 },
						})
					end
				end
			end
		end
	end)

	it("one cast's juice at its peak stays within Config.Vfx.juice.perCast (every style, weight and view)", function()
		local budget = Config.Vfx.juice.perCast
		local worst = { emitters = 0, beams = 0, lights = 0, decals = 0 }
		local cases = 0
		for style in SkillJuiceData.STYLES do
			for weight in SkillJuiceData.WEIGHTS do
				for _, quality in { "low", "medium", "high" } do
					for _, touch in { false, true } do
						for _, own in { true, false } do
							for _, simple in { false, true } do
								for _, support in { false, true } do
									local v: SkillJuice.View = {
										quality = quality,
										simple = simple,
										own = own,
										touch = touch,
										cap = if touch then Config.Vfx.maxBurst.touch else Config.Vfx.maxBurst.desktop,
									}
									local cost = SkillLooks.juiceOf(
										SkillJuice.flareLayers(weight, v),
										SkillJuice.punchLayers(style, weight, v, support, false)
									)
									worst.emitters = math.max(worst.emitters, cost.emitters)
									worst.beams = math.max(worst.beams, cost.beams)
									worst.lights = math.max(worst.lights, cost.lights)
									worst.decals = math.max(worst.decals, cost.decals)
									cases += 1
								end
							end
						end
					end
				end
			end
		end
		expect(cases > 100).toBe(true)
		expect({
			worst.emitters <= budget.emitters,
			worst.beams <= budget.beams,
			worst.lights <= budget.lights,
			worst.decals <= budget.decals,
		}).toEqual({ true, true, true, true })
		-- another player's far cast: the flare's and the punch's cores and the ring, nothing else
		local far = SkillLooks.juiceCost(skill("mightyStrike"), SkillVfx.mightyStrike, false, OTHERS_FAR)
		expect(far).toEqual({ emitters = 2, beams = 0, lights = 0, decals = 1 })
	end)

	it("the juice keeps a reserve of every device limit for the skills' own pieces", function()
		-- the reserve rounds up; room stops short of it
		expect(SkillJuice.reserve(24, 0.4)).toBe(10)
		expect(SkillJuice.reserve(48, 0.4)).toBe(20)
		expect(SkillJuice.reserve(10, 0.5)).toBe(5)
		expect(SkillJuice.reserve(6, 0.5)).toBe(3)
		expect(SkillJuice.reserve(7, 0)).toBe(0)
		expect(SkillJuice.reserve(7, 1.5)).toBe(7)
		expect(SkillJuice.reserve(0, 0.5)).toBe(0)
		expect(SkillJuice.room(13, 24, 0.4)).toBe(true)
		expect(SkillJuice.room(14, 24, 0.4)).toBe(false)
		expect(SkillJuice.room(30, 24, 0.4)).toBe(false)
		expect(SkillJuice.room(0, 0, 0.5)).toBe(false)
		expect(SkillJuice.room(5, 6, 0)).toBe(true)
		-- on every device the reserve holds one cast's own pieces (Config.Vfx.perCast) and the rest one cast's juice
		-- (Config.Vfx.juice.perCast; its ground ring is a ground image, on the beam limit)
		local reserve = Config.Vfx.juice.reserve
		local pieces, juice = Config.Vfx.perCast, Config.Vfx.juice.perCast
		for _, device in { "desktop", "touch" } do
			local rows = {
				{ "emitters", Config.Vfx.maxEmitters[device], pieces.emitters, juice.emitters },
				{ "beams", Config.Vfx.maxBeams[device], pieces.beams, juice.beams + juice.decals },
				{ "lights", Config.Vfx.maxLights[device], pieces.lights, juice.lights },
			}
			for _, row in rows do
				local name, limit, piecesNeed, juiceNeed = row[1], row[2], row[3], row[4]
				local kept = SkillJuice.reserve(limit, reserve[name])
				expect({ device, name, kept >= piecesNeed, limit - kept >= juiceNeed }).toEqual({
					device,
					name,
					true,
					true,
				})
			end
		end
	end)

	it("the client asks before every layer and cuts a cast short on a fizzle or the caster's death", function()
		local juice = fs.readFile("src/client/Vfx/Juice.luau")
		expect(occurrences(juice, 'room("emitters")')).toBe(2) -- every core (flash) and particle layer (layer)
		expect(occurrences(juice, 'room("lights")')).toBe(1) -- fadingLight
		expect(occurrences(juice, 'room("beams")')).toBe(2) -- the ring and every arc
		expect(occurrences(juice, "SkillJuice.flareLayers(")).toBe(1)
		expect(occurrences(juice, "SkillJuice.punchLayers(")).toBe(1)
		local pool = fs.readFile("src/client/Vfx/Pool.luau")
		expect(string.find(pool, "function Pool.used(", 1, true) ~= nil).toBe(true)
		local vfx = fs.readFile("src/client/Controllers/VfxController.luau")
		-- the definition, a fizzle, a death: aimEnd cuts nothing (a shot that leaves sends it too)
		expect(occurrences(vfx, "cutShort(")).toBe(3)
		expect(string.find(vfx, "cutShort(casterKey(data))", 1, true) ~= nil).toBe(true)
		expect(string.find(vfx, "HealthChanged", 1, true) ~= nil).toBe(true)
		expect(string.find(vfx, "if cutOff() or", 1, true) ~= nil).toBe(true) -- the release flare
		expect(string.find(vfx, "cancelled = cutOff", 1, true) ~= nil).toBe(true) -- the gathering's pop
		local hunterMage = fs.readFile("src/client/Vfx/LmHunterMage.luau")
		expect(string.find(hunterMage, "ctx.cancelled", 1, true) ~= nil).toBe(true)
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
