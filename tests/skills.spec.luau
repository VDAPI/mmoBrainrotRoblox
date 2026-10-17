--!strict
local Bases = require("../src/shared/Data/Items/Bases")
local Build = require("../src/shared/Data/Skills/Build")
local Classes = require("../src/shared/Data/Classes")
local SkillData = require("../src/shared/Data/Skills")
local SkillGeom = require("../src/shared/Logic/SkillGeom")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
local RankFill = require("./RankFill")
local T = require("./Test")

local VALID_TYPES = {
	target = true,
	projectile = true,
	cone = true,
	circleSelf = true,
	circleTarget = true,
	line = true,
	chain = true,
	charge = true,
	blink = true,
	buff = true,
	debuff = true,
	heal = true,
	hot = true,
	shield = true,
	channel = true,
	trap = true,
	resurrect = true,
	groupBuff = true,
	groupHeal = true,
	healZone = true, -- S70
	guard = true, -- S74
	shout = true,
	banner = true,
	companion = true, -- S77
	beam = true, -- S80
	passive = true,
}

T.describe("Data: Skills", function()
	T.it("every class has skills of its own", function()
		for _, classId in Classes.order do
			local list = SkillData.byClass[classId]
			if not list or #list == 0 then
				error(`{classId}: no skills`)
			end
			for _, skill in list do
				T.expect({ id = skill.id, class = skill.class }).toEqual({ id = skill.id, class = classId })
			end
		end
	end)

	T.it("every skill is well formed", function()
		for id, skill in SkillData.byId do
			local function check(ok: boolean, what: string)
				if not ok then
					error(`{id}: {what}`)
				end
			end
			check(VALID_TYPES[skill.type] == true, `unknown type {skill.type}`)
			check(skill.maxLevel == (if skill.type == "passive" then 5 else 10), "maxLevel")
			check(skill.unlock >= 1 and skill.unlock <= 100, "unlock")
			if skill.type == "passive" then
				check(skill.passive ~= nil, "passive without modifiers")
			else
				check(skill.resource == "mana" or skill.resource == "energy", "resource")
			end
			if skill.type == "cone" then
				check((skill.radius or 0) > 0 and (skill.angle or 0) > 0, "cone needs radius and angle")
			elseif skill.type == "circleSelf" or skill.type == "circleTarget" or skill.type == "trap" then
				check((skill.radius or 0) > 0, "needs radius")
			elseif skill.type == "healZone" then
				check((skill.radius or 0) > 0 and (skill.range or 0) > 0, "healZone needs radius and range")
			elseif skill.type == "guard" then
				check((skill.range or 0) > 0, "guard needs range")
			elseif skill.type == "shout" then
				check((skill.radius or 0) > 0, "shout needs radius")
			elseif skill.type == "banner" then
				check(
					(skill.radius or 0) > 0 and (skill.range or 0) > 0 and skill.duration ~= nil,
					"banner needs radius, range and duration"
				)
			elseif skill.type == "companion" then
				check(
					skill.duration ~= nil
						and (skill.interval or 0) > 0
						and (skill.range or 0) > 0
						and (skill.radius or 0) > 0
						and skill.values.dmg ~= nil,
					"companion needs duration, interval, range, radius and values.dmg"
				)
			elseif skill.type == "beam" then
				check(
					(skill.range or 0) > 0
						and skill.duration ~= nil
						and (skill.interval or 0) > 0
						and skill.values.dmg ~= nil
						and skill.values.growth ~= nil
						and skill.values.drain ~= nil,
					"beam needs range, duration, interval and values.dmg, growth, drain"
				)
			elseif skill.type == "line" or skill.type == "blink" then
				check((skill.length or 0) > 0, "needs length")
			elseif
				skill.type == "target"
				or skill.type == "projectile"
				or skill.type == "charge"
				or skill.type == "debuff"
			then
				check((skill.range or 0) > 0, "needs range")
			end
			for _, effect in skill.effects or {} do
				if type(effect.value) == "string" then
					check(skill.values[effect.value] ~= nil, `effect value {effect.value} missing`)
				end
				for _, field in effect.stats or {} do
					check(skill.values[field] ~= nil, `stat field {field} missing`)
				end
			end
		end
	end)

	T.it("DESIGN control values", function()
		local mighty = SkillData.get("mightyStrike") :: any
		T.expect(Skills.valueAt(mighty, "dmg", 1)).toBe(136) -- S91: ranks <= 20 x0.85
		T.expect(Skills.valueAt(mighty, "dmg", 10)).toBe(222) -- S89 (rank 5 pinned by Data/SkillCurves)
		T.expect(Skills.valueAt(mighty, "dmg", 5)).toBeNear(187) -- S91 (rank 6 pinned at 220.4)
		T.expect(Skills.valueAt(mighty, "dmg", 6)).toBeNear(220.4)
		local steel = SkillData.get("steelSkin") :: any
		T.expect(Skills.valueAt(steel, "armor", 5)).toBe(25)
		local res = SkillData.get("resurrection") :: any
		T.expect(Skills.scaled(res, res.cooldown, 1)).toBe(120)
		T.expect(Skills.scaled(res, res.cooldown, 10)).toBe(60)
	end)

	T.it("descriptions resolve every placeholder in both languages", function()
		for id, skill in SkillData.byId do
			for _, lang in { "en", "pl" } do
				for _, level in { 1, skill.maxLevel } do
					local text = Skills.formatDescription(skill, level, lang)
					if string.find(text, "{", 1, true) or text == skill.descKey then
						error(`{id} ({lang}, lvl {level}): {text}`)
					end
				end
			end
		end
	end)
end)

T.describe("S56 ranks from the level and the bar", function()
	local function ids(list: { any }): { string }
		local out = {}
		for _, skill in list do
			table.insert(out, skill.id)
		end
		return out
	end

	T.it("rankFor (base only)", function()
		local bloodlust = SkillData.get("bloodlust") :: any
		T.expect(Skills.rankFor("Warrior", 17, bloodlust)).toBe(0)
		T.expect(Skills.rankFor("Warrior", 18, bloodlust)).toBe(1)
		T.expect(Skills.rankFor("Warrior", 54, bloodlust)).toBe(10)
		T.expect(Skills.rankFor("Mage", 54, bloodlust)).toBe(0)
		local onPath = table.clone(bloodlust)
		onPath.path = "somePath"
		T.expect(Skills.rankFor("Warrior", 54, onPath)).toBe(0) -- path skills: Logic/Paths.skillRank
		T.expect(Skills.validSlot(1)).toBe(true)
		-- S137 (DESIGN-18 §4.1): 8 slots per weapon pool; rankFor is the limit of a bought rank now
		T.expect(Skills.validSlot(8)).toBe(true)
		T.expect(Skills.validSlot(9)).toBe(false)
		T.expect(Skills.validSlot(1.5)).toBe(false)
	end)

	T.it("transitional ladder (ROZWOJ 2.6): every base skill, 19 ranks at level 20", function()
		-- Since S81 every class has paths, so the ladder runs on a fixture: each class's 14 skills of 05b859d (before
		-- S53) with today's unlocks, as base skills of a class id without a PathDef.
		local GamePaths = require("../src/shared/Logic/Paths")
		local UNLOCKS = { 1, 3, 6, 10, 14, 18, 23, 28, 34, 40, 48, 56, 65, 75 }
		local LADDER: { [string]: { string } } = {
			Warrior = {
				"mightyStrike",
				"battleCry",
				"charge",
				"bladeWhirl",
				"steelSkin",
				"cleave",
				"taunt",
				"fortitude",
				"earthquake",
				"bloodlust",
				"riposte",
				"crushingBlow",
				"lastBastion",
				"titansWrath",
			},
			Hunter = {
				"aimedShot",
				"doubleShot",
				"disengage",
				"arrowRain",
				"hawkEye",
				"venomArrow",
				"frostTrap",
				"agility",
				"piercingArrow",
				"huntersMark",
				"predatorInstinct",
				"volley",
				"camouflage",
				"stormArrow",
			},
			Mage = {
				"firebolt",
				"iceShard",
				"blink",
				"fireball",
				"focus",
				"chainLightning",
				"manaShield",
				"kindling", -- S140: passives in the old places of Elementalist and Arcane Mind (now path nodes)
				"frostNova",
				"meteor",
				"phoenixHeart",
				"firewall",
				"evocation",
				"meteorStorm",
			},
			Cleric = {
				"holyStrike",
				"heal",
				"renew",
				"radiance",
				"devotion",
				"circleOfLight",
				"purify",
				"auraOfEndurance",
				"resurrection",
				"shieldOfFaith",
				"divineWrath",
				"judgement",
				"prayer",
				"divineIntervention",
			},
		}
		local checked = 0
		for _, classId in Classes.order do
			T.expect({ classId, GamePaths.classHasPaths(classId) }).toEqual({ classId, true })
			local ids = LADDER[classId]
			T.expect({ classId, ids ~= nil }).toEqual({ classId, true })
			local fixtureClass = `Ladder{classId}`
			local base, total = 0, 0
			for i, id in ids do
				local real = SkillData.get(id)
				T.expect({ id, real ~= nil }).toEqual({ id, true })
				local skill = table.clone(real :: any)
				skill.class = fixtureClass
				skill.path = nil
				skill.unlock = UNLOCKS[i]
				base += if Skills.rankFor(fixtureClass, 100, skill) > 0 then 1 else 0
				total += Skills.rankFor(fixtureClass, 20, skill)
			end
			T.expect({ classId, base }).toEqual({ classId, #ids })
			T.expect({ classId, total }).toEqual({ classId, 19 })
			checked += 1
		end
		T.expect(checked).toBe(#Classes.order)
		T.expect(checked > 0).toBe(true)
	end)

	T.it("starting skill and start hotbar", function()
		for _, classId in Classes.order do
			local start = Skills.startingSkill(classId) :: string
			local def = SkillData.get(start) :: any
			T.expect(def.unlock).toBe(1)
			T.expect(def.type ~= "passive").toBe(true)
			local bar = Skills.startHotbar(classId, 100)
			local actives = 0
			for _, skill in SkillData.byClass[classId] do
				if skill.path == nil and skill.type ~= "passive" then
					actives += 1
				end
			end
			local n = 0
			for slot = 1, 10 do
				local skill = SkillData.get(bar[tostring(slot)] or "") :: any
				if skill then
					T.expect(skill.type ~= "passive").toBe(true)
					n += 1
				end
			end
			-- S71: a class with paths has fewer base actives than slots (Cleric 6); S140: the Mage more (8 slots, S137)
			T.expect(n).toBe(math.min(SkillData.HOTBAR_SLOTS, actives))
			for _, id in bar do
				T.expect(id ~= "titansWrath" and id ~= "stormArrow" and id ~= "meteorStorm").toBe(true)
				T.expect(id ~= "prayer" and id ~= "divineIntervention").toBe(true)
			end
		end
		T.expect(Skills.startHotbar("Warrior", 1)).toEqual({ ["1"] = "mightyStrike" })
		T.expect(Skills.startHotbar("Hunter", 20)).toEqual({
			["1"] = "aimedShot",
			["2"] = "doubleShot",
			["3"] = "disengage",
			["4"] = "arrowRain",
			["5"] = "venomArrow",
		})
	end)

	T.it("newlyUnlocked", function()
		T.expect(ids(Skills.newlyUnlocked("Warrior", 2, 6))).toEqual({ "charge", "bladeWhirl" })
		T.expect(ids(Skills.newlyUnlocked("Warrior", 13, 14))).toEqual({ "steelSkin" })
		T.expect(ids(Skills.newlyUnlocked("Warrior", 6, 6))).toEqual({})
	end)

	T.it("firstFreeSlot and placeOnBar", function()
		T.expect(Skills.firstFreeSlot({})).toBe(1)
		T.expect(Skills.firstFreeSlot({ ["1"] = "a", ["2"] = "b" })).toBe(3)
		local full = {}
		for slot = 1, 10 do
			full[tostring(slot)] = `s{slot}`
		end
		T.expect(Skills.firstFreeSlot(full)).toBeNil()
		local bar = { ["1"] = "mightyStrike" }
		local placed, left = Skills.placeOnBar(bar, { "battleCry", "mightyStrike" })
		T.expect(placed).toEqual({ { slot = 2, id = "battleCry" } })
		T.expect(left).toEqual({})
		T.expect(bar).toEqual({ ["1"] = "mightyStrike" })
		local placed2, left2 = Skills.placeOnBar(full, { "battleCry" })
		T.expect(placed2).toEqual({})
		T.expect(left2).toEqual({ "battleCry" })
	end)
end)

T.describe("Mage weapon elements (S18)", function()
	T.it("element skills need a matching weapon, adaptive ones do not", function()
		local iceShard = SkillData.get("iceShard") :: any
		T.expect(Skills.elementAllowed(iceShard, "ice")).toBe(true)
		T.expect(Skills.elementAllowed(iceShard, "fire")).toBe(false)
		T.expect(Skills.elementAllowed(iceShard, nil)).toBe(false)
		local arcane = SkillData.get("firebolt") :: any
		T.expect(arcane.adaptive).toBe(true)
		T.expect(Skills.elementAllowed(arcane, nil)).toBe(true)
		T.expect(Skills.elementAllowed(SkillData.get("blink") :: any, "ice")).toBe(true)
		T.expect(Skills.requiredElement(SkillData.get("firewall") :: any)).toBe("lightning")
		-- Other classes never depend on the weapon element.
		for _, skill in SkillData.byId do
			if skill.class ~= "Mage" then
				T.expect(Skills.requiredElement(skill)).toBeNil()
			end
		end
	end)
end)

T.describe("S54 formulas", function()
	local function skill(id: string): SkillData.SkillDef
		return SkillData.get(id) :: SkillData.SkillDef
	end
	-- Same rounding as the description placeholders (whole numbers, else one decimal).
	local function round(value: number): number
		if math.abs(value - math.floor(value + 0.5)) < 1e-6 then
			return math.floor(value + 0.5)
		end
		return math.floor(value * 10 + 0.5) / 10
	end

	T.it("Mage mana follows the level curve, Cleric and energy stay flat", function()
		local firebolt = skill("firebolt")
		T.expect(Skills.cost(firebolt, 1, 20, "Mage")).toBe(12)
		-- S87 (G10): manaCost.Mage 1.89 / 2.59 / 3.49 at 45 / 70 / 100 (was 1.4 / 1.9 / 2.5)
		T.expect(Skills.cost(firebolt, 1, 45, "Mage")).toBeNear(1.89 * Skills.cost(firebolt, 1, 20, "Mage"))
		T.expect(Skills.cost(firebolt, 1, 45, "Mage")).toBeNear(12 * 1.89)
		T.expect(Skills.cost(firebolt, 1, 100, "Mage")).toBeNear(12 * 3.49)
		for _, def in SkillData.byId do
			if def.class == "Mage" and def.type ~= "passive" then
				for _, rank in { 1, def.maxLevel } do
					local flat = Skills.scaled(def, def.cost, rank)
					for level = 1, 20 do
						T.expect(Skills.cost(def, rank, level, "Mage")).toBe(math.max(0, flat))
					end
				end
			end
		end
		local heal = skill("heal")
		local clericBase = Skills.cost(heal, 1, 20, "Cleric")
		T.expect(Skills.cost(heal, 1, 45, "Cleric")).toBe(clericBase)
		T.expect(Skills.cost(heal, 1, 100, "Cleric")).toBe(clericBase)
		local strike = skill("mightyStrike")
		T.expect(Skills.cost(strike, 1, 100, "Warrior")).toBe(Skills.cost(strike, 1, 1, "Warrior"))
		T.expect(Skills.cost(firebolt, 1, 20, "Mage", { costPct = -20 })).toBeNear(12 * 0.8)
		T.expect(Skills.cost(firebolt, 1, 20, "Mage", { costPct = -200 })).toBe(0)
	end)

	T.it("heal curve: identity up to 20 and only magic-attack heals", function()
		for level = 1, 20 do
			T.expect(Skills.healMul(level)).toBe(1)
		end
		-- S69: target-HP heals put only their magic part on the curve
		for _, id in { "heal", "renew", "circleOfLight", "purify" } do
			T.expect({ id = id, fields = Skills.healFields(skill(id)) }).toEqual({ id = id, fields = { "healMag" } })
		end
		T.expect(Skills.healFields(skill("radiance"))).toEqual({ "heal" })
		T.expect(Skills.healFields(skill("shieldOfFaith"))).toEqual({ "shieldMag" })
		for _, id in { "devotion", "divineIntervention", "holyStrike" } do
			T.expect({ id = id, fields = Skills.healFields(skill(id)) }).toEqual({ id = id, fields = {} })
		end
	end)

	T.it("descriptionArgs keep today's numbers up to level 20", function()
		for _, def in SkillData.byId do
			for _, rank in { 1, 5, 10 } do
				if rank <= def.maxLevel then
					local effective = Skills.effective(def, rank, nil, nil)
					local args = Skills.descriptionArgs(def, rank, { level = 20 })
					local plain = Skills.descriptionArgs(def, rank)
					T.expect({ id = def.id, rank = rank, cost = args.cost }).toEqual({
						id = def.id,
						rank = rank,
						cost = math.max(0, round(Skills.scaled(effective, effective.cost, rank))),
					})
					for _, field in { "heal", "shield", "healHp", "healMag", "shieldHp", "shieldMag" } do
						T.expect({ id = def.id, field = field, value = args[field] }).toEqual({
							id = def.id,
							field = field,
							value = if effective.values[field] ~= nil
								then round(Skills.valueAt(effective, field, rank))
								else nil,
						})
					end
					if def.class ~= "Mage" then
						T.expect({ id = def.id, cost = plain.cost }).toEqual({ id = def.id, cost = args.cost })
					end
				end
			end
		end
	end)

	T.it("skill damage is normalised to weapon speed", function()
		local stats = { str = 5, dex = 100, int = 3, vit = 8 }
		local function skillAttack(weaponType: string, level: number): number
			local w = (Bases.byType[weaponType].weapon :: any)(level)
			local result = StatCalc.compute({
				level = level,
				stats = stats,
				weapon = { dmg = w.dmg, mdmg = w.mdmg, speed = w.speed, ranged = w.ranged },
			})
			return result.values.physAtk * Skills.speedFactor(w.speed)
		end
		-- Below level 12 the rounding of weapon damage (round(curve x mul)) alone makes up to 3.8 % difference.
		for _, level in { 20, 45, 70, 100 } do
			local heavy, long = skillAttack("heavycrossbow", level), skillAttack("longbow", level)
			T.expect({ level = level, close = math.abs(heavy / long - 1) < 0.01 }).toEqual({
				level = level,
				close = true,
			})
		end
		T.expect(Skills.speedFactor(0.8)).toBe(1)
		T.expect(Skills.speedFactor(nil)).toBe(1.25)
	end)
end)

T.describe("S55 ranks (ROZWOJ 2.5)", function()
	local function skill(id: string): SkillData.SkillDef
		return SkillData.get(id) :: SkillData.SkillDef
	end

	T.it("RANKS are step 4 and cap 95", function()
		T.expect(SkillData.RANKS).toEqual({ step = 4, capLevel = 95 })
	end)

	T.it("rank levels follow the curve", function()
		-- unlock -> { rank 5, rank 10 } (ROZWOJ 2.5)
		local anchors = {
			{ 1, 17, 37 },
			{ 3, 19, 39 },
			{ 6, 22, 42 },
			{ 10, 26, 46 },
			{ 14, 30, 50 },
			{ 18, 34, 54 },
			{ 26, 42, 62 },
			{ 30, 46, 66 },
			{ 45, 61, 81 },
			{ 48, 64, 84 },
			{ 60, 76, 95 },
			{ 65, 78, 95 },
			{ 75, 84, 95 },
			{ 80, 87, 95 },
		}
		for _, row in anchors do
			local u = row[1]
			local def = ({ unlock = u, maxLevel = 10 } :: any) :: SkillData.SkillDef
			T.expect({ u, Skills.rankLevel(def, 5), Skills.rankLevel(def, 10) }).toEqual(row)
			T.expect(Skills.rankLevel(def, 1)).toBe(u)
			T.expect(Skills.rankLevel(def, 0)).toBe(u)
		end
		local passive = ({ unlock = 14, maxLevel = 5 } :: any) :: SkillData.SkillDef
		local passiveLevels = {}
		for r = 2, 5 do
			table.insert(passiveLevels, Skills.rankLevel(passive, r))
		end
		T.expect(passiveLevels).toEqual({ 23, 32, 41, 50 })
		local cleaveLevels = {}
		for r = 1, 10 do
			table.insert(cleaveLevels, Skills.rankLevel(skill("bloodlust"), r))
		end
		T.expect(cleaveLevels).toEqual({ 18, 22, 26, 30, 34, 38, 42, 46, 50, 54 })
		T.expect(Skills.rankLevel(skill("mightyStrike"), 2)).toBe(5)
		-- S81: row 7 of the Mage paths (ROZWOJ 12.4 / 12.5). S140: Rain of Meteors at 60 (span 35), Evocation at 30
		T.expect({ Skills.rankLevel(skill("meteorStorm"), 5), Skills.rankLevel(skill("meteorStorm"), 10) }).toEqual({
			76,
			95,
		})
		T.expect({ Skills.rankLevel(skill("evocation"), 5), Skills.rankLevel(skill("evocation"), 10) }).toEqual({
			46,
			66,
		})
	end)

	T.it("every skill is maxed by level 95", function()
		for id, def in SkillData.byId do
			T.expect({ id = id, first = Skills.rankLevel(def, 1) }).toEqual({ id = id, first = def.unlock })
			if Skills.rankLevel(def, def.maxLevel) > SkillData.RANKS.capLevel then
				error(`{id}: maxed after level {SkillData.RANKS.capLevel}`)
			end
			for r = 2, def.maxLevel do
				if Skills.rankLevel(def, r) <= Skills.rankLevel(def, r - 1) then
					error(`{id}: rank {r} does not come after rank {r - 1}`)
				end
			end
		end
	end)

	T.it("rankAt inverts rankLevel", function()
		for id, def in SkillData.byId do
			for r = 1, def.maxLevel do
				local at = Skills.rankLevel(def, r)
				T.expect({ id = id, r = r, rank = Skills.rankAt(def, at) }).toEqual({ id = id, r = r, rank = r })
				T.expect({ id = id, r = r, rank = Skills.rankAt(def, at - 1) })
					.toEqual({ id = id, r = r, rank = r - 1 })
			end
			T.expect(Skills.rankAt(def, 100)).toBe(def.maxLevel)
		end
		local cleave = skill("bloodlust")
		T.expect(Skills.rankAt(cleave, 17)).toBe(0)
		T.expect(Skills.rankAt(cleave, 33)).toBe(4)
		T.expect(Skills.rankAt(cleave, 34)).toBe(5)
	end)
end)

-- Skills.effective before S55 (copy of S54 Logic/Skills: effective + breakpointsAt reading option A, switch on).
-- Values of a breakpoint replaced the base value; only the last `effect` was added.
local LEGACY_NUMERIC = { "range", "radius", "angle", "length", "width", "hits", "delay" }
local function legacyEffective(skill: SkillData.SkillDef, level: number): (any, any)
	local active = {}
	for _, at in { 5, 10 } do
		local pair = skill.breakpoints and skill.breakpoints[at]
		if pair and level >= at then
			table.insert(active, pair.a)
		end
	end
	local behaviour: any = {}
	if #active == 0 then
		return skill, behaviour
	end
	local def: any = table.clone(skill)
	def.values = table.clone(skill.values)
	local effects: { SkillData.SkillEffect } = table.clone(skill.effects or {})
	local addDuration = 0
	local jumps = 0
	local none: { [string]: number } = {}
	for _, bp in active do
		for key, amount in bp.add or none do
			if key == "effectDuration" then
				addDuration += amount
			elseif key == "jumps" then
				jumps += amount
			elseif key == "duration" then
				def.duration = Skills.scaled(skill, def.duration, level) + amount
			elseif table.find(LEGACY_NUMERIC, key) then
				def[key] = (def[key] or 0) + amount
			end
		end
		for key, factor in bp.mul or none do
			if key == "cooldown" then
				def.cooldown = Skills.scaled(skill, def.cooldown, level) * factor
			elseif key == "cost" then
				def.cost = Skills.scaled(skill, def.cost, level) * factor
			elseif key == "delay" then
				def.delay = (def.delay or 0) * factor
			end
		end
		for field, amount in bp.values or none do
			def.values[field] = Skills.scaled(skill, skill.values[field], level) + amount
		end
		for key, v in bp :: any do
			if key ~= "add" and key ~= "mul" and key ~= "values" then
				behaviour[key] = v
			end
		end
	end
	if jumps ~= 0 then
		def.values.jumps = Skills.valueAt(skill, "jumps", level) + jumps
	end
	if behaviour.effect then
		table.insert(effects, behaviour.effect)
	end
	if addDuration ~= 0 then
		for i, effect in effects do
			local copy = table.clone(effect)
			copy.duration = math.max(0.5, Skills.scaled(skill, effect.duration, level) + addDuration)
			effects[i] = copy
		end
		-- S75 (DECYZJE): add.effectDuration lengthens the self and party copies too (intended change)
		for _, key in { "selfEffect", "allyEffect" } do
			local effect = behaviour[key]
			if effect then
				local copy = table.clone(effect)
				copy.duration = math.max(0.5, Skills.scaled(skill, effect.duration, level) + addDuration)
				behaviour[key] = copy
			end
		end
	end
	def.effects = effects
	return def, behaviour
end

local function round6(value: number): number
	return math.floor(value * 1e6 + 0.5) / 1e6
end

-- Comparable shape of an effective skill: scaled numbers, effect lists (old selfEffect / allyEffect behaviours moved
-- to the lists) and the remaining behaviours.
local function view(def: any, behaviour: any, rank: number): any
	local out: any = {
		cost = round6(Skills.scaled(def, def.cost, rank)),
		cooldown = round6(Skills.scaled(def, def.cooldown, rank)),
		duration = round6(Skills.scaled(def, def.duration, rank)),
		values = {},
		behaviour = {},
	}
	for _, field in LEGACY_NUMERIC do
		out[field] = def[field]
	end
	for field in def.values do
		out.values[field] = round6(Skills.valueAt(def, field, rank))
	end
	local function effectView(effect: SkillData.SkillEffect): any
		return {
			kind = effect.kind,
			duration = round6(Skills.scaled(def, effect.duration, rank)),
			value = effect.value,
			stats = effect.stats,
			pct = effect.pct,
			target = effect.target,
			category = effect.category,
		}
	end
	local function listView(list: { SkillData.SkillEffect }?): { any }
		local views = {}
		for _, effect in list or {} do
			table.insert(views, effectView(effect))
		end
		return views
	end
	out.effects = listView(def.effects)
	out.selfEffects = listView(def.selfEffects)
	out.allyEffects = listView(def.allyEffects)
	if behaviour.selfEffect then
		table.insert(out.selfEffects, effectView(behaviour.selfEffect))
	end
	if behaviour.allyEffect then
		table.insert(out.allyEffects, effectView(behaviour.allyEffect))
	end
	for key, v in behaviour do
		if key ~= "effect" and key ~= "selfEffect" and key ~= "allyEffect" then
			out.behaviour[key] = v
		end
	end
	return out
end

T.describe("S55 breakpoints and composition (ROZWOJ 2.7)", function()
	local function fakeSkill(): any
		return {
			id = "fakeBolt",
			class = "Warrior",
			order = 1,
			unlock = 1,
			maxLevel = 10,
			type = "target",
			target = "enemy",
			resource = "energy",
			cost = 10,
			cooldown = { 10, 6 },
			range = 20,
			radius = 5,
			values = { dmg = { 100, 190 } },
			effects = { { kind = "slow", duration = 2, value = 20 } },
			breakpoints = {
				[5] = {
					a = {
						values = { dmg = 10 },
						add = { radius = 1, effectDuration = 1 },
						knockback = 4,
						effect = { kind = "stun", duration = 1 },
						selfEffect = { kind = "damageReduction", duration = 2, value = 10, target = "self" },
					},
					b = { values = { dmg = 30 }, pull = 6 },
				},
				[10] = {
					a = {
						values = { dmg = 20 },
						add = { radius = 2 },
						mul = { cooldown = 0.5 },
						knockback = 8,
						allyEffect = { kind = "invuln", duration = 1, target = "allies" },
					},
				},
			},
			glyph = "x",
			vfx = "x",
			nameKey = "x",
			descKey = "x",
		}
	end

	T.it("A at ranks 5 and 10 for every active", function()
		for id, def in SkillData.byId do
			if def.type == "passive" then
				T.expect({ id = id, bps = def.breakpoints }).toEqual({ id = id })
			else
				local bps: any = def.breakpoints
				if not bps or not bps[5] or not bps[5].a or not bps[10] or not bps[10].a then
					error(`{id}: needs option A at ranks 5 and 10`)
				end
				for at, pair in bps do
					if at ~= 5 and at ~= 10 then
						error(`{id}: breakpoint at rank {at}`)
					end
					for option in pair do
						if option ~= "a" and option ~= "b" then
							error(`{id}: unknown option {option}`)
						end
					end
				end
			end
		end
	end)

	T.it("choices pick B only when chosen and defined", function()
		T.expect(Skills.choiceKey("cleave", 5)).toBe("cleave:5")
		local fake = fakeSkill()
		T.expect(Skills.chosen(fake, 5, { ["fakeBolt:5"] = "b" })).toBe("b")
		T.expect(Skills.chosen(fake, 5, nil)).toBe("a")
		T.expect(Skills.chosen(fake, 10, { ["fakeBolt:10"] = "b" })).toBe("a")
		local cleave = SkillData.get("cleave") :: SkillData.SkillDef
		local active = Skills.breakpointsAt(cleave, 10, { ["cleave:5"] = "b" }, true)
		T.expect(#active).toBe(2)
		local bps: any = cleave.breakpoints
		T.expect(active[1]).toBe(bps[5].b) -- S73: Cleave has option B
		T.expect(active[2]).toBe(bps[10].a)
		T.expect(Skills.breakpointKey("cleave", 5, "a")).toBe("skill.cleave.bp5")
		T.expect(Skills.breakpointKey("cleave", 10, "b")).toBe("skill.cleave.bp10b")
		local keys = {}
		for _, entry in Skills.breakpointKeys(fake) do
			table.insert(keys, `{entry.rank}{entry.option}`)
		end
		T.expect(keys).toEqual({ "5a", "5b", "10a" })
	end)

	T.it("composition on a synthetic skill", function()
		local fake = fakeSkill()
		local before, _ = Skills.effective(fake, 4, nil, nil, true)
		T.expect(before).toBe(fake)

		local d5 = Skills.effective(fake, 5, nil, nil, true) :: any
		T.expect(Skills.valueAt(d5, "dmg", 5)).toBeNear(150)
		T.expect(d5.radius).toBe(6)
		T.expect(#d5.effects).toBe(2)
		T.expect(d5.effects[1].kind).toBe("slow")
		T.expect(Skills.scaled(d5, d5.effects[1].duration, 5)).toBe(3)
		T.expect(d5.effects[2].kind).toBe("stun")
		T.expect(Skills.scaled(d5, d5.effects[2].duration, 5)).toBe(2)
		T.expect(#d5.selfEffects).toBe(1)
		T.expect(d5.allyEffects).toBeNil()
		local _, b5 = Skills.effective(fake, 5, nil, nil, true)
		T.expect(b5.knockback).toBe(4)

		-- ROZWOJ 2.7: both value changes add up (before S55 the later one replaced the first: 210)
		local d10, b10 = Skills.effective(fake, 10, nil, nil, true)
		local e10 = d10 :: any
		T.expect(Skills.valueAt(d10, "dmg", 10)).toBe(220)
		T.expect(e10.radius).toBe(8)
		T.expect(Skills.scaled(d10, d10.cooldown, 10)).toBe(3)
		T.expect(b10.knockback).toBe(8)
		T.expect(#e10.effects).toBe(2)
		T.expect(#e10.selfEffects).toBe(1)
		T.expect(#e10.allyEffects).toBe(1)

		local dB, bB = Skills.effective(fake, 10, { ["fakeBolt:5"] = "b" }, nil, true)
		local eB = dB :: any
		T.expect(Skills.valueAt(dB, "dmg", 10)).toBe(240)
		T.expect(bB.pull).toBe(6)
		T.expect(bB.knockback).toBe(8)
		T.expect(eB.radius).toBe(7)
		T.expect(#eB.effects).toBe(1)
		T.expect(Skills.scaled(dB, eB.effects[1].duration, 10)).toBe(2)
		T.expect(eB.selfEffects).toBeNil()

		local mods: { Skills.SkillMod } = {
			{
				values = { dmg = 5 },
				knockback = 10,
				selfEffect = { kind = "damageReduction", duration = 3, value = 5, target = "self" },
			},
		}
		local dM, bM = Skills.effective(fake, 10, nil, mods, true)
		T.expect(Skills.valueAt(dM, "dmg", 10)).toBe(225)
		T.expect(bM.knockback).toBe(10)
		T.expect(#(dM :: any).selfEffects).toBe(2)

		local off, _ = Skills.effective(fake, 10, nil, nil, false)
		T.expect(off).toBe(fake)
		local offMods, _ = Skills.effective(fake, 10, nil, mods, false)
		T.expect(Skills.valueAt(offMods, "dmg", 10)).toBe(195)

		-- the data is untouched
		T.expect(fake.values.dmg).toEqual({ 100, 190 })
		T.expect(fake.radius).toBe(5)
		T.expect(#fake.effects).toBe(1)
		T.expect(fake.effects[1].duration).toBe(2)

		T.expect(Skills.descriptionArgs(fake, 10, { level = 20, choices = { ["fakeBolt:5"] = "b" } }).dmg).toBe(240)
	end)

	-- Neutral only while no skill has two changes of the same field: when a class session adds such an A, it replaces
	-- this case with a direct test (ROZWOJ 2.7).
	-- S70: Roll of the Dice has values on both A (5A and 10A add to the faces); "S70 new Cleric actives" tests it.
	local TWO_CHANGES = { fortuneDice = true }
	T.it("neutral on today's data", function()
		for id, def in SkillData.byId do
			if TWO_CHANGES[id] then
				continue
			end
			for _, rank in { 1, 5, 10 } do
				local d1, b1 = Skills.effective(def, rank, nil, nil, true)
				local d0, b0 = legacyEffective(def, rank)
				T.expect({ id = id, rank = rank, view = view(d1, b1, rank) }).toEqual({
					id = id,
					rank = rank,
					view = view(d0, b0, rank),
				})
			end
		end
	end)
end)

T.describe("S64 cooldown reduction (STATY 2C, ROZWOJ 7.3)", function()
	local Combat = require("../src/shared/Data/Combat")

	local function synthetic(skillType: string, cooldown: number, effects: { any }?, duration: number?): any
		return {
			id = "fakeCd",
			class = "Warrior",
			order = 1,
			unlock = 1,
			maxLevel = 10,
			type = skillType,
			target = "self",
			cost = 0,
			cooldown = cooldown,
			duration = duration,
			values = {},
			effects = effects,
		}
	end

	T.it("caps the reduction", function()
		T.expect(Skills.cooldownReduction(25)).toBe(20)
		T.expect(Skills.cooldownReduction(-5)).toBe(0)
	end)

	T.it("shortens plain skills and keeps party buffs at their duration", function()
		local plain = synthetic("target", 40)
		T.expect(Skills.cooldown(plain, 1, 20)).toBeNear(32)
		T.expect(Skills.cooldown(plain, 1, 50)).toBeNear(32)
		T.expect(Skills.cooldown(plain, 1, 0)).toBe(40)
		local buff30 = { { kind = "statBuff", duration = 30, target = "allies" } }
		T.expect(Skills.cooldown(synthetic("groupBuff", 30, buff30), 1, 20)).toBe(30)
		T.expect(Skills.cooldown(synthetic("groupBuff", 60, buff30), 1, 20)).toBeNear(48)
		T.expect(Skills.cooldown(synthetic("groupBuff", 36, buff30), 1, 20)).toBe(30)
		local allies = { { kind = "damageReduction", duration = 20, value = 10, target = "allies" } }
		T.expect(Skills.cooldown(synthetic("buff", 22, allies), 1, 20)).toBe(20)
	end)

	T.it(
		"every active of every class: no reduction keeps the base, the cap never goes below the party floor",
		function()
			for id, skill in SkillData.byId do
				if skill.type == "passive" then
					continue
				end
				for _, rank in { 1, skill.maxLevel } do
					local def = Skills.effective(skill, rank)
					local base = Skills.scaled(def, def.cooldown, rank)
					T.expect({ id, rank, Skills.cooldown(def, rank, 0) }).toEqual({ id, rank, base })
					local capped = Skills.cooldown(def, rank, Combat.cdrCap)
					local floor = math.min(base, Skills.partyDuration(def, rank))
					T.expect({ id, rank, capped >= floor - 1e-9, capped <= base + 1e-9 })
						.toEqual({ id, rank, true, true })
				end
			end
		end
	)
end)

T.describe("S69 Cleric heals and B options", function()
	local pl = require("../src/shared/Data/Localization/pl")
	local en = require("../src/shared/Data/Localization/en")
	local function skill(id: string): SkillData.SkillDef
		return SkillData.byId[id]
	end

	T.it("12 actives: A on both ranks, B per ROZWOJ 9.2–9.5", function()
		local expected: { [string]: { [number]: string } } = {
			holyStrike = { [5] = "execute", [10] = "healWounded" },
			heal = { [5] = "selfHeal", [10] = "chainHeal" },
			renew = { [5] = "secondTarget", [10] = "values" },
			radiance = { [5] = "pull", [10] = "echo" },
			circleOfLight = { [5] = "add", [10] = "healZone" },
			purify = { [5] = "burst", [10] = "mul" },
			auraOfEndurance = { [5] = "allyEffect", [10] = "allyEffect" },
			resurrection = { [5] = "mul", [10] = "values" },
			shieldOfFaith = { [5] = "cleanse", [10] = "add" },
			judgement = { [5] = "stunNear", [10] = "values" },
			prayer = { [5] = "roll", [10] = "steadfast" },
			divineIntervention = { [5] = "cleanse", [10] = "allyEffect" },
		}
		for id, ranks in expected do
			local bps = skill(id).breakpoints :: SkillData.Breakpoints
			for _, at in { 5, 10 } do
				local pair = bps[at]
				T.expect({ id, at, pair.a ~= nil }).toEqual({ id, at, true })
				local key = ranks[at]
				if key then
					local b: any = pair.b
					T.expect({ id, at, b ~= nil and b[key] ~= nil }).toEqual({ id, at, true })
				else
					T.expect({ id, at, pair.b == nil }).toEqual({ id, at, true })
				end
				local textKey = `skill.{id}.bp{at}b`
				T.expect({ textKey, (pl :: any)[textKey] ~= nil, (en :: any)[textKey] ~= nil })
					.toEqual({ textKey, true, true })
			end
		end
		local function b(id: string, at: number): any
			return ((skill(id).breakpoints :: SkillData.Breakpoints)[at] :: any).b
		end
		local function a(id: string, at: number): any
			return ((skill(id).breakpoints :: SkillData.Breakpoints)[at] :: any).a
		end
		T.expect(b("holyStrike", 10).healWounded).toBe(30)
		T.expect(b("heal", 10).chainHeal).toEqual({ jumps = 2, pct = 60 })
		T.expect(b("circleOfLight", 10).healZone).toEqual({ duration = 4, pct = 6 }) -- S89 (R4)
		T.expect(b("auraOfEndurance", 5).allyEffect.category).toBe("allyVigor")
		T.expect(b("auraOfEndurance", 5).allyEffect.stats.mres ~= nil).toBe(true)
		T.expect(b("auraOfEndurance", 10).allyEffect.category).toBe("allyAttack")
		T.expect(b("auraOfEndurance", 10).values.atkBp).toBe(6)
		local guard = b("divineIntervention", 10).allyEffect
		T.expect({ guard.value, guard.duration, guard.category }).toEqual({ 25, 7, "allyGuard" })
		T.expect(a("shieldOfFaith", 5).values.shieldHp).toBe(3)
		for _, id in { "heal", "renew", "circleOfLight", "purify", "shieldOfFaith" } do
			local values = skill(id).values
			T.expect({ id, values.heal == nil, values.shield == nil }).toEqual({ id, true, true })
		end
	end)

	T.it("Shield of Faith 5A + 10B sums shieldHp", function()
		local sof = skill("shieldOfFaith")
		local def = Skills.effective(sof, 10, { ["shieldOfFaith:10"] = "b" }, nil, true)
		T.expect(Skills.valueAt(def, "shieldHp", 10)).toBeNear(28) -- S89: 10B +7 (R4)
		T.expect(Skills.scaled(def, def.duration, 10)).toBeNear(14)
		T.expect(Skills.valueAt(def, "shieldMag", 10)).toBeNear(15)
		T.expect(Skills.healAmount(def, 10, "shield", 3000, 900, 20)).toBeNear(3000 * 0.28 + 900 * 0.15)
		local bb, behaviourB =
			Skills.effective(sof, 10, { ["shieldOfFaith:5"] = "b", ["shieldOfFaith:10"] = "b" }, nil, true)
		T.expect(Skills.valueAt(bb, "shieldHp", 10)).toBeNear(25)
		T.expect(behaviourB.cleanse).toBe(true)
		local aa, behaviourA = Skills.effective(sof, 10, nil, nil, true)
		T.expect(Skills.valueAt(aa, "shieldHp", 10)).toBeNear(21)
		T.expect(behaviourA.secondTarget).toBe(50)
		T.expect(Skills.scaled(aa, aa.duration, 10)).toBeNear(8)
		local four = Skills.effective(sof, 4, nil, nil, true)
		T.expect(Skills.valueAt(four, "shieldHp", 4)).toBeNear(12 + 6 * 3 / 9)
	end)

	T.it("healAmount: target HP plus magic part, old data as before", function()
		local heal = skill("heal")
		T.expect(Skills.healAmount(heal, 1, "heal", 1000, 200, 20)).toBeNear(1000 * 0.16 + 200 * 0.08)
		local renew = Skills.effective(skill("renew"), 10, { ["renew:10"] = "b" }, nil, true)
		T.expect(Skills.valueAt(renew, "healHp", 10)).toBeNear(30)
		local old: any = table.clone(heal)
		old.values = { heal = { 120, 260 } }
		T.expect(Skills.healAmount(old, 10, "heal", 5000, 900, 20)).toBeNear(900 * 2.6)
		local args = Skills.descriptionArgs(heal, 1, { level = 20 })
		T.expect({ args.healHp, args.healMag }).toEqual({ 16, 8 })
	end)

	T.it("chainHeal order: most wounded first, each once, only wounded", function()
		T.expect(Skills.chainOrder({ 1, 0.4, 0.7, 0.4, 0.9 }, 2)).toEqual({ 2, 4 })
		T.expect(Skills.chainOrder({ 1, 0.4, 0.7, 0.4, 0.9 }, 5)).toEqual({ 2, 4, 3, 5 })
		T.expect(Skills.chainOrder({ 1, 1 }, 2)).toEqual({})
		T.expect(Skills.chainOrder({}, 2)).toEqual({})
		T.expect(Skills.chainShare(60, 1)).toBeNear(0.6)
		T.expect(Skills.chainShare(60, 2)).toBeNear(0.36)
	end)
end)

T.describe("S70 Guardian Angel", function()
	-- "Once" is the filter removing the effect and "after shields" its priority 90 (ResourceService.FilterPriority);
	-- both live on the server. This is the pure decision.
	T.it("a lethal monster blow leaves 1 HP, never PvP, DoT or admin", function()
		T.expect({ Skills.angelSave(500, 600, "monster", true) }).toEqual({ 499, true })
		T.expect({ Skills.angelSave(500, 400, "monster", true) }).toEqual({ 400, false })
		T.expect({ Skills.angelSave(500, 600, "intercept", true) }).toEqual({ 499, true })
		T.expect({ Skills.angelSave(500, 600, "pvp", true) }).toEqual({ 600, false })
		T.expect({ Skills.angelSave(500, 600, "poison", true) }).toEqual({ 600, false })
		T.expect({ Skills.angelSave(500, math.huge, "admin", true) }).toEqual({ math.huge, false })
		T.expect({ Skills.angelSave(500, 600, "monster", false) }).toEqual({ 600, false })
		T.expect({ Skills.angelSave(1, 50, "monster", true) }).toEqual({ 0, true })
	end)
end)

T.describe("S70 new Cleric actives", function()
	local GamePaths = require("../src/shared/Logic/Paths")
	local pl = require("../src/shared/Data/Localization/pl")
	local en = require("../src/shared/Data/Localization/en")
	local function skill(id: string): SkillData.SkillDef
		return SkillData.byId[id]
	end
	local PATHS = {
		sanctuary = "healer",
		guardianAngel = "healer",
		fortuneDice = "fortune",
		wheelOfFortune = "fortune",
		brandOfLight = "inquisitor",
		hammerOfHeaven = "inquisitor",
	}

	T.it("paths, delivery, ranks and breakpoints A and B per ROZWOJ 9.3–9.5", function()
		local keys: { [string]: { [number]: { string } } } = {
			sanctuary = { [5] = { "add", "cleanse" }, [10] = { "add", "allyEffect" } },
			guardianAngel = { [5] = { "add", "add" }, [10] = { "values", "mul" } },
			fortuneDice = { [5] = { "values", "add" }, [10] = { "values", "rollDouble" } },
			wheelOfFortune = { [5] = { "add", "add" }, [10] = { "mul", "values" } },
			brandOfLight = { [5] = { "values", "splash" }, [10] = { "lifesteal", "effect" } },
			hammerOfHeaven = { [5] = { "add", "lingering" }, [10] = { "add", "echo" } },
		}
		for id, path in PATHS do
			local def = skill(id)
			T.expect({ id, def.class, def.path, def.maxLevel, def.delivery ~= nil })
				.toEqual({ id, "Cleric", path, 10, true })
			for at, pair in keys[id] do
				local bp: any = (def.breakpoints :: SkillData.Breakpoints)[at]
				T.expect({ id, at, bp.a[pair[1]] ~= nil, bp.b ~= nil and bp.b[pair[2]] ~= nil })
					.toEqual({ id, at, true, true })
				for _, suffix in { "", "b" } do
					local textKey = `skill.{id}.bp{at}{suffix}`
					T.expect({ textKey, (pl :: any)[textKey] ~= nil, (en :: any)[textKey] ~= nil })
						.toEqual({ textKey, true, true })
				end
			end
		end
	end)

	T.it("control values", function()
		local sanctuary = skill("sanctuary")
		T.expect({ Skills.valueAt(sanctuary, "healHp", 1), Skills.valueAt(sanctuary, "healHp", 10) })
			.toEqual({ 2, 3.2 })
		T.expect(Skills.shape(sanctuary)).toBe("circle")
		T.expect(sanctuary.target).toBe("point")
		local angel = skill("guardianAngel")
		T.expect({ Skills.valueAt(angel, "saveHeal", 1), Skills.valueAt(angel, "saveHeal", 10) }).toEqual({ 15, 25 })
		local angelEffect = (angel.effects :: any)[1]
		T.expect({ Skills.scaled(angel, angelEffect.duration, 1), Skills.scaled(angel, angelEffect.duration, 10) })
			.toEqual({ 6, 8 })
		local angel5a = Skills.effective(angel, 10, nil, nil, true)
		T.expect(Skills.scaled(angel5a, (angel5a.effects :: any)[1].duration, 10)).toBe(10)
		T.expect(Skills.valueAt(angel5a, "saveHeal", 10)).toBe(40)
		local wheel = skill("wheelOfFortune")
		local wheelB = Skills.effective(wheel, 10, { ["wheelOfFortune:10"] = "b" }, nil, true)
		T.expect(Skills.valueAt(wheelB, "boost", 10)).toBe(100)
		for _, effect in wheelB.effects :: any do
			if effect.face then
				T.expect(Skills.scaled(wheelB, effect.duration, 10)).toBe(12)
			end
		end
		local brand = skill("brandOfLight")
		local burn = (brand.effects :: any)[1]
		T.expect({ burn.kind, burn.value, brand.holy }).toEqual({ "burn", "dot", true })
		local stun = (skill("hammerOfHeaven").effects :: any)[1]
		T.expect({ stun.kind, stun.notBoss }).toEqual({ "stun", true })
		T.expect((skill("judgement").effects :: any)[1].notBoss).toBeNil()
		-- Roll of the Dice: 5A and 10A both add to the faces (replaces the neutral case for it)
		local dice = Skills.effective(skill("fortuneDice"), 10, nil, nil, true)
		T.expect(Skills.valueAt(dice, "crit", 10)).toBeNear(11)
		T.expect(Skills.valueAt(dice, "haste", 10)).toBeNear(17)
		T.expect(Skills.valueAt(dice, "regen", 10)).toBeNear(2.6)
		local diceB = Skills.effective(skill("fortuneDice"), 10, { ["fortuneDice:10"] = "b" }, nil, true)
		local _, behaviour = Skills.effective(skill("fortuneDice"), 10, { ["fortuneDice:10"] = "b" }, nil, true)
		T.expect(behaviour.rollDouble).toBe(30)
		T.expect(Skills.valueAt(diceB, "crit", 10)).toBeNear(9)
	end)

	-- S71: the paths have their PathDef; a path skill comes with its node (S138: every row in any direction, no direction
	-- weapon).
	T.it("reachable through their nodes (S71)", function()
		local c: any = {
			class = "Cleric",
			level = 100,
			path = { nodes = { fortune_fortuneDice = 1 }, bp = {} },
			hotbar = { ["1"] = "fortuneDice", ["2"] = "sanctuary" },
			equipment = {},
			ranks = RankFill.auto("Cleric", 100), -- S137: the old automatic ranks as bought ranks
		}
		T.expect(GamePaths.skillRank(c, "fortuneDice")).toBe(10)
		T.expect(GamePaths.skillRank(c, "sanctuary")).toBe(0)
		T.expect(GamePaths.validHotbar(c)).toEqual({ ["1"] = "fortuneDice" })
		T.expect(GamePaths.skillUsable(c, "fortuneDice", { main = "mace1h", offhand = "relic" })).toBe(true)
		T.expect(GamePaths.skillUsable(c, "fortuneDice", { main = "mace1h", offhand = "shield" })).toBe(true) -- S138
	end)
end)

T.describe("S71 Cleric base and paths", function()
	local GamePaths = require("../src/shared/Logic/Paths")
	local function skill(id: string): SkillData.SkillDef
		return SkillData.byId[id]
	end
	-- A level 100 Cleric with these nodes and breakpoint choices (S138: the second argument names the direction meant,
	-- no main path); the skill at rank 10 with its node mods.
	local function eff(
		id: string,
		_main: string?,
		nodes: { [string]: number },
		weapons: any,
		bp: { [string]: any }?
	): (any, any)
		local c: any = {
			class = "Cleric",
			level = 100,
			path = { nodes = nodes, bp = bp or {} }, -- S138: no main path
			hotbar = {},
			equipment = {},
			ranks = RankFill.auto("Cleric", 100), -- S137: the old automatic ranks as bought ranks
		}
		return Skills.effective(skill(id), 10, bp or {}, GamePaths.skillMods(c, id, weapons), true)
	end
	local SCEPTER = { main = "scepter", offhand = "shield" }
	local RELIC = { main = "mace1h", offhand = "relic" }

	T.it("base 8 on levels 1-45, path skills on their rows, A and B everywhere", function()
		local unlocks, passives = {}, 0
		local actives = 0
		for _, def in SkillData.byClass.Cleric do
			if def.path == nil then
				table.insert(unlocks, def.unlock)
				if def.type == "passive" then
					passives += 1
				end
			else
				T.expect({ def.id, table.find({ 10, 26, 48, 60 }, def.unlock) ~= nil }).toEqual({ def.id, true })
			end
			if def.type ~= "passive" then
				actives += 1
				for _, at in Skills.BREAKPOINT_LEVELS do
					local pair = (def.breakpoints :: any)[at]
					T.expect({ def.id, at, pair.a ~= nil, pair.b ~= nil }).toEqual({ def.id, at, true, true })
				end
			end
		end
		table.sort(unlocks)
		T.expect(unlocks).toEqual({ 1, 3, 6, 10, 14, 18, 30, 45 })
		T.expect(passives <= 2).toBe(true)
		T.expect(actives).toBe(18)
	end)

	T.it("base damage (ROZWOJ 9.2) and the 15.2 defaults", function()
		-- S91: Holy Strike rank 1 190 -> 167 (ranks <= 20, rank 6 pinned)
		for id, pair in { holyStrike = { 167, 340 }, radiance = { 130, 240 }, judgement = { 320, 580 } } do
			T.expect({ id, Skills.valueAt(skill(id), "dmg", 1), Skills.valueAt(skill(id), "dmg", 10) })
				.toEqual({ id, pair[1], pair[2] })
		end
		local prayer = skill("prayer")
		T.expect(Skills.valueAt(Skills.effective(prayer, 10, nil, nil, true), "group", 10)).toBe(10)
		T.expect(Skills.valueAt(Skills.effective(prayer, 10, { ["prayer:10"] = "a" }, nil, true), "group", 10)).toBe(10)
		T.expect(Skills.valueAt(Skills.effective(prayer, 10, { ["prayer:10"] = "b" }, nil, true), "group", 10)).toBe(5)
		T.expect(Skills.effective(skill("divineIntervention"), 10, nil, nil, true).radius).toBe(40)
		T.expect((skill("judgement").effects :: any)[1].notBoss).toBeNil()
	end)

	T.it("Shield of Faith with Firm Faith, Bulwark and Shattering Shield", function()
		local bp = { ["shieldOfFaith:10"] = "b" }
		local nodes = { healer_faithShield = 3, healer_bulwark = 3 }
		local def = eff("shieldOfFaith", "healer", nodes, SCEPTER, bp)
		T.expect(Skills.valueAt(def, "shieldHp", 10)).toBeNear(40) -- S89: 10B +7
		T.expect(Skills.scaled(def, def.duration, 10)).toBeNear(17)
		T.expect(Skills.valueAt(def, "shieldMag", 10)).toBe(15)
		-- S138: no direction weapon: a relic keeps the row 3+ nodes too
		local noWeapon = eff("shieldOfFaith", "healer", nodes, RELIC, bp)
		T.expect(Skills.valueAt(noWeapon, "shieldHp", 10)).toBeNear(40)
		T.expect(Skills.scaled(noWeapon, noWeapon.duration, 10)).toBeNear(17)
		local shatter = { healer_faithShield = 3, healer_bulwark = 3, healer_shatter = 3 }
		local withBurst, b = eff("shieldOfFaith", "healer", shatter, SCEPTER, bp)
		T.expect(b.shieldBurst.radius).toBe(10)
		T.expect(Skills.valueAt(withBurst, "shieldBurst", 10)).toBeNear(45)
	end)

	T.it("Aura of Endurance 5B + 10B", function()
		local def = Skills.effective(
			skill("auraOfEndurance"),
			10,
			{ ["auraOfEndurance:5"] = "b", ["auraOfEndurance:10"] = "b" },
			nil,
			true
		)
		local categories = {}
		for _, effect in def.allyEffects :: any do
			categories[effect.category] = effect.stats
		end
		T.expect(categories.allyVigor.mres ~= nil).toBe(true)
		T.expect(categories.allyAttack.magAtk ~= nil).toBe(true)
		T.expect(Skills.valueAt(def, "mresBp", 10)).toBe(10)
		T.expect(Skills.valueAt(def, "atkBp", 10)).toBe(6)
		T.expect(Skills.valueAt(def, "hp", 10)).toBe(15)
		T.expect((def.effects :: any)[1].stats.maxHp).toBe("hp")
	end)

	T.it("Holy Strike with Evil Eye, Ill Omen and Heavy Hand", function()
		-- S138: Evil Eye (a team node of row 2) in full from TEAM_FULL_POINTS ranks in Fortune (Smile changes no skill)
		local def = eff("holyStrike", "fortune", { fortune_evilEye = 3, fortune_smile = 3 }, RELIC)
		local stun, misfortune
		for _, effect in def.effects :: any do
			if effect.kind == "stun" then
				stun = effect
			elseif effect.kind == "misfortune" then
				misfortune = effect
			end
		end
		T.expect(stun.duration).toBe(0.8)
		T.expect({ misfortune.duration, misfortune.category, misfortune.value })
			.toEqual({ 6, "enemyMiss", "misfortune" })
		T.expect(Skills.valueAt(def, "misfortune", 10)).toBe(6)
		local both = eff("holyStrike", "fortune", { fortune_evilEye = 3, fortune_omen = 3 }, RELIC)
		T.expect(Skills.valueAt(both, "misfortune", 10)).toBe(12)
		local heavy = eff("holyStrike", "fortune", { inquisitor_heavyHand = 3 }, RELIC)
		T.expect(Skills.valueAt(heavy, "dmg", 10)).toBe(380)
	end)

	T.it("Roll of the Dice and Guardian Angel with their nodes", function()
		local dice = eff("fortuneDice", "fortune", { fortune_quickDice = 3, fortune_streak = 3 }, RELIC)
		T.expect(Skills.scaled(dice, dice.cooldown, 10)).toBeNear(18)
		for _, effect in dice.effects :: any do
			T.expect(Skills.scaled(dice, effect.duration, 10)).toBeNear(18)
		end
		local bpB = { ["guardianAngel:10"] = "b" }
		local angel = eff("guardianAngel", "healer", { healer_choir = 2 }, SCEPTER, bpB)
		T.expect(Skills.scaled(angel, (angel.effects :: any)[1].duration, 10)).toBeNear(14)
		T.expect(Skills.valueAt(angel, "saveHeal", 10)).toBeNear(45)
		T.expect(Skills.scaled(angel, angel.cooldown, 10)).toBeNear(67.5)
		local angelA = eff("guardianAngel", "healer", { healer_choir = 2 }, SCEPTER)
		T.expect(Skills.valueAt(angelA, "saveHeal", 10)).toBeNear(60)
	end)

	T.it("Judgement with Final Verdict, Inquisition and Executor", function()
		local nodes = { inquisitor_finalVerdict = 3, inquisitor_inquisition = 3 }
		local c: any = { class = "Cleric", level = 100, path = { main = "inquisitor", nodes = nodes, bp = {} } }
		local weapons = { main = "mace1h" }
		local def, b = Skills.effective(skill("judgement"), 10, {}, GamePaths.skillMods(c, "judgement", weapons), true)
		T.expect(b.stunSplash.radius).toBe(6)
		T.expect(Skills.valueAt(def, "stunSplash", 10)).toBeNear(50)
		T.expect(Skills.scaled(def, def.cooldown, 10)).toBeNear(12)
		c.path.nodes = { inquisitor_finalVerdict = 3, inquisitor_executioner = 3 }
		local _, b2 = Skills.effective(skill("judgement"), 10, {}, GamePaths.skillMods(c, "judgement", weapons), true)
		T.expect(b2.execute).toBeNear(50)
	end)

	T.it("healBonusPct and healCritChance", function()
		local hooks = { healBonus = 25, allyHealBonus = 30, lowHpHealBonus = 0 }
		T.expect(Skills.healBonusPct(hooks, true, 1)).toBe(55)
		T.expect(Skills.healBonusPct(hooks, false, 1)).toBe(25)
		local low = { healBonus = 0, allyHealBonus = 0, lowHpHealBonus = 25 }
		T.expect(Skills.healBonusPct(low, false, 0.3)).toBe(25)
		T.expect(Skills.healBonusPct(low, false, 0.35)).toBe(0)
		T.expect(Skills.healCritChance(8, 100)).toBeNear(0.08)
		T.expect(Skills.healCritChance(9, 100 / 3)).toBeNear(0.03)
		T.expect(Skills.healCritChance(60, 0)).toBe(0)
		T.expect(Skills.healCritChance(200, 100)).toBe(1)
	end)
end)

T.describe("S73 Warrior B options and breakpoint kinds", function()
	local Build = require("../src/shared/Data/Skills/Build")
	local PartyBuffRules = require("./PartyBuffRules")
	local pl = require("../src/shared/Data/Localization/pl")
	local en = require("../src/shared/Data/Localization/en")

	local function skill(id: string): SkillData.SkillDef
		return SkillData.get(id) :: SkillData.SkillDef
	end
	-- choices in the shape of path.bp
	local function pick(id: string, five: string?, ten: string?): Skills.Choices
		local out: any = {}
		if five then
			out[Skills.choiceKey(id, 5)] = five
		end
		if ten then
			out[Skills.choiceKey(id, 10)] = ten
		end
		return out
	end
	local function at(id: string, rank: number, five: string?, ten: string?, mods: { any }?): (any, any)
		return Skills.effective(skill(id), rank, pick(id, five, ten), mods, true)
	end
	local function v(def: any, field: string): number
		return Skills.valueAt(def, field, 10)
	end
	local function cd(def: any, rank: number?): number
		return Skills.scaled(def, def.cooldown, rank or 10)
	end

	local B_KEYS: { [string]: { [number]: string } } = {
		mightyStrike = { [5] = "execute", [10] = "effect" },
		charge = { [5] = "mul", [10] = "splash" },
		bladeWhirl = { [5] = "lifesteal", [10] = "add" },
		taunt = { [5] = "selfHeal", [10] = "add" },
		bloodlust = { [5] = "add", [10] = "values" },
		earthquake = { [5] = "pull", [10] = "values" },
		lastBastion = { [5] = "values", [10] = "mul" },
		cleave = { [5] = "values", [10] = "lifesteal" },
		titansWrath = { [5] = "values", [10] = "add" },
		battleCry = { [5] = "values", [10] = "selfEffect" },
		crushingBlow = { [5] = "values", [10] = "mul" },
	}

	T.it("11 actives: A and B on both ranks", function()
		local count = 0
		for id, keys in B_KEYS do
			count += 1
			local bps: any = skill(id).breakpoints
			for _, rank in { 5, 10 } do
				T.expect({ id, rank, bps[rank].a ~= nil }).toEqual({ id, rank, true })
				local b = bps[rank].b
				T.expect({ id, rank, b ~= nil and b[keys[rank]] ~= nil }).toEqual({ id, rank, true })
				local key = Skills.breakpointKey(id, rank, "b")
				T.expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		T.expect(count).toBe(11)
	end)

	T.it("A fixes (R4)", function()
		local _, quake = at("earthquake", 10)
		T.expect(quake.lingering.pct).toBe(5)
		T.expect(quake.echo.pct).toBe(25)
		local cry = at("battleCry", 10)
		T.expect(cd(cry)).toBeNear(30)
	end)

	T.it("control values at rank 10", function()
		local d, b = at("earthquake", 10, "b", "b")
		T.expect(b.pull).toBe(10)
		T.expect(v(d, "dmg")).toBeNear(213) -- S89: 175 + 38
		T.expect(b.lingering).toBeNil()
		T.expect(b.echo).toBeNil()
		d, b = at("earthquake", 10, "a", "b")
		T.expect(b.lingering.pct).toBe(5)
		T.expect(v(d, "dmg")).toBeNear(213)

		d, b = at("titansWrath", 10, "a", "b")
		T.expect(d.radius).toBe(17)
		T.expect(d.hits).toBe(4)
		T.expect(v(d, "dmg")).toBeNear(135) -- S89: 150 - 15
		d, b = at("titansWrath", 10, "b", "a")
		T.expect(v(d, "dmg")).toBeNear(168) -- S89: 150 + 18
		T.expect(d.hits).toBe(3)
		T.expect(b.stunLast).toBe(1.2)

		d, b = at("bladeWhirl", 10, "b", "b")
		T.expect(d.hits).toBe(4)
		T.expect(v(d, "dmg")).toBeNear(48) -- S89: 52 - 4
		T.expect(b.lifesteal).toBe(8)
		d, b = at("bladeWhirl", 10, "a", "a")
		T.expect(d.hits).toBe(3)
		T.expect(b.castMove).toBe(60)
		T.expect(b.pull).toBe(12)

		d, b = at("taunt", 10, "a", "b")
		T.expect(d.radius).toBe(20)
		T.expect(#d.effects).toBe(2)
		for _, effect in d.effects do
			T.expect(Skills.scaled(d, effect.duration, 10)).toBeNear(9)
		end
		d, b = at("taunt", 10, "b", "a")
		T.expect(b.selfHeal).toBe(8)

		d, b = at("bloodlust", 10, "b", "b")
		T.expect(Skills.scaled(d, d.effects[1].duration, 10)).toBeNear(14)
		T.expect(v(d, "speed")).toBeNear(24) -- S89: 20 + 4
		T.expect(v(d, "lifesteal")).toBeNear(5)
		d, b = at("bloodlust", 10, "a", "a")
		T.expect(v(d, "lifesteal")).toBeNear(8)
		T.expect(#d.selfEffects).toBe(1)
		T.expect({ d.selfEffects[1].kind, d.selfEffects[1].value, d.selfEffects[1].category }).toEqual({
			"damageReduction",
			15,
			"own",
		})

		d, b = at("lastBastion", 10, "b", "b")
		T.expect(v(d, "reduction")).toBeNear(68)
		T.expect(cd(d)).toBeNear(67.5)
		T.expect(b.selfHeal).toBeNil()
		d, b = at("lastBastion", 10, "a", "a")
		T.expect(Skills.scaled(d, d.effects[1].duration, 10)).toBeNear(8)
		T.expect(b.selfHeal).toBe(15)
		T.expect(v(d, "reduction")).toBeNear(60)

		d, b = at("cleave", 10, "b", "b")
		T.expect(v(d, "bleed")).toBeNear(50)
		T.expect(b.lifesteal).toBe(12)
		T.expect(d.angle).toBe(90)
		T.expect(b.bleedStacks).toBeNil()

		d, b = at("crushingBlow", 10, "b", "b")
		T.expect(v(d, "dmg")).toBeNear(568) -- S89: 520 + 48
		T.expect(cd(d)).toBeNear(12.8)
		d, b = at("crushingBlow", 10, "a", "a")
		local kinds: { [string]: number } = {}
		for _, effect in d.effects do
			kinds[effect.kind] = Skills.scaled(d, effect.duration, 10)
		end
		T.expect(kinds.stun).toBeNear(0.7)
		T.expect(kinds.armorBreak ~= nil).toBe(true)
		T.expect(b.splash.radius).toBe(7)

		d, b = at("mightyStrike", 10, "b", "b")
		T.expect(b.execute).toBe(30)
		local bleed = d.effects[#d.effects]
		T.expect({ bleed.kind, bleed.value, bleed.duration }).toEqual({ "bleed", 45, 6 }) -- S89 (R1, R4)
		d, b = at("charge", 10, "b", "b")
		T.expect(cd(d)).toBeNear(10.56) -- S91: 5B x0.88 (R4)
		T.expect(b.splash.pct).toBe(60)
		T.expect(d.range).toBe(25)

		d, b = at("battleCry", 10, "b", "b")
		T.expect(v(d, "atk")).toBeNear(19) -- S89: 16 + 3
		T.expect(Skills.scaled(d, d.effects[1].duration, 10)).toBeNear(24)
		T.expect(#d.selfEffects).toBe(1)
		T.expect(d.selfEffects[1].stats.atkSpeed).toBe("speedBp")
		T.expect(v(d, "speedBp")).toBeNear(10)
		T.expect(cd(d)).toBeNear(40)
		d = at("battleCry", 10, "a", "b")
		T.expect(#d.selfEffects).toBe(2)
		d = at("battleCry", 5, "b")
		T.expect(Skills.valueAt(d, "atk", 5)).toBeNear(14 + 2 * 2 / 7 + 3) -- S89: knot 14 at rank 3, 16 at 10
	end)

	T.it("new kinds compose without nodes", function()
		local kill: any = { extendOnKill = { seconds = 1, max = "killTest" }, values = { killTest = 6 } }
		local d, b = at("bloodlust", 10, nil, nil, { kill })
		T.expect(b.extendOnKill.seconds).toBe(1)
		T.expect(Skills.resolve(d, b.extendOnKill.max, 10)).toBe(6)
		T.expect(Skills.resolve(d, 4, 10)).toBe(4)
		T.expect(Skills.resolve(d, nil, 10)).toBe(0)
		T.expect(Skills.resolve(d, "missing", 10)).toBe(0)

		local oath: any = { shieldPerHit = { hpPct = 8, max = 5, duration = 6 } }
		d, b = at("taunt", 10, nil, "b", { oath })
		T.expect(b.shieldPerHit.max).toBe(5)
		for _, effect in d.effects do
			T.expect(Skills.scaled(d, effect.duration, 10)).toBeNear(9)
		end

		local guard: any = {
			behindEffect = {
				kind = "damageReduction",
				duration = 10,
				value = 20,
				target = "allies",
				category = "allyGuard",
			},
		}
		d, b = at("lastBastion", 10, nil, nil, { guard })
		T.expect(b.behindEffect.category).toBe("allyGuard")
		T.expect(#d.effects).toBe(1)
		T.expect(d.allyEffects).toBeNil()
		T.expect(Skills.hasAllyPass(d, b)).toBe(false)

		d, b = at("battleCry", 10)
		T.expect(Skills.hasAllyPass(d, b)).toBe(false)
		local command: any = {
			allyEffect = {
				kind = "statBuff",
				duration = 20,
				stats = { physAtk = "cmd", magAtk = "cmd" },
				pct = true,
				target = "allies",
				category = "allyAttack",
			},
			values = { cmd = 3 },
		}
		local rally: any = { allyHeal = { hpPct = 9 } }
		d, b = at("battleCry", 10, nil, nil, { command, rally })
		T.expect(#d.allyEffects).toBe(1)
		T.expect(b.allyHeal.hpPct).toBe(9)
		T.expect(Skills.hasAllyPass(d, b)).toBe(true)
		T.expect(Skills.allyRadius(d)).toBe(30)
		local wider: any = { add = { allyRadius = 5 } }
		d = at("battleCry", 10, nil, nil, { command, rally, wider })
		T.expect(d.allyRadius).toBe(35)
		local widest: any = { add = { allyRadius = 20 } }
		d = at("battleCry", 10, nil, nil, { command, rally, widest })
		T.expect(Skills.allyRadius(d)).toBe(40)

		local near8: any = { tauntNear = { radius = 8, duration = 3 } }
		local near10: any = { tauntNear = { radius = 10, duration = 3 } }
		_, b = at("taunt", 10, nil, nil, { near8, near10 })
		T.expect(b.tauntNear.radius).toBe(10)

		local fake = Build.class("Warrior", "energy", "phys", {
			{
				id = "fakeShout",
				unlock = 1,
				maxLevel = 10,
				type = "buff",
				delivery = "melee",
				cost = 10,
				cooldown = 30,
				radius = 20,
				hitRadius = 10,
				allyRadius = 20,
				furyConsume = "furyDmg",
				values = { furyDmg = 5 },
				glyph = "x",
			},
		})[1]
		T.expect({ fake.hitRadius, fake.allyRadius, fake.furyConsume }).toEqual({ 10, 20, "furyDmg" })
		local louder: any = { add = { hitRadius = 5 } }
		local grown = Skills.effective(fake, 10, nil, { louder }, true)
		T.expect(grown.hitRadius).toBe(15)
		local args = Skills.descriptionArgs(fake, 10)
		T.expect({ args.hitRadius, args.allyRadius }).toEqual({ 10, 20 })
		local strike = Skills.descriptionArgs(skill("mightyStrike"), 10)
		T.expect({ strike.hitRadius, strike.allyRadius }).toEqual({})

		T.expect(Skills.furyMultiplier(8, 10)).toBeNear(1.8)
		T.expect(Skills.furyMultiplier(8, 0)).toBe(1)
	end)

	T.it("every Warrior choice combination stays sane", function()
		local function finite(x: number): boolean
			return x == x and x ~= math.huge and x ~= -math.huge
		end
		for id in B_KEYS do
			local base = skill(id)
			for _, rank in { 5, 10 } do
				local sets: { { string } } = if rank == 5
					then { { "a" }, { "b" } }
					else { { "a", "a" }, { "a", "b" }, { "b", "a" }, { "b", "b" } }
				for _, set in sets do
					local choices = pick(id, set[1], set[2])
					local def = Skills.effective(base, rank, choices, nil, true)
					local where = `{id} {rank} {table.concat(set)}`
					for field in def.values do
						local ok = finite(Skills.valueAt(def, field, rank))
						T.expect({ where, field, ok }).toEqual({ where, field, true })
					end
					T.expect({ where, cd(def, rank) > 0, (def.hits or 1) >= 1 }).toEqual({ where, true, true })
					for _, list in { def.effects or {}, def.selfEffects or {}, def.allyEffects or {} } do
						for _, effect in list do
							for _, field in effect.stats or {} do
								T.expect({ where, field, def.values[field] ~= nil }).toEqual({ where, field, true })
							end
						end
					end
					for _, lang in { "pl", "en" } do
						local text = Skills.formatDescription(base, rank, lang, { choices = choices })
						T.expect({ where, lang, string.find(text, "{", 1, true) }).toEqual({ where, lang })
					end
				end
			end
		end
	end)

	T.it("7.3 helper reads buff reach and behind", function()
		local function buff(spec: { [string]: any }): SkillData.SkillDef
			local base: { [string]: any } = {
				id = "fakeRally",
				unlock = 1,
				maxLevel = 10,
				type = "buff",
				delivery = "melee",
				cost = 10,
				duration = 10,
				values = {},
				glyph = "x",
			}
			for key, value in spec do
				base[key] = value
			end
			return Build.class("Warrior", "energy", "phys", { base })[1]
		end
		local attack: any = {
			allyEffect = {
				kind = "statBuff",
				duration = 20,
				stats = { physAtk = "cmd" },
				pct = true,
				target = "allies",
				category = "allyAttack",
			},
			values = { cmd = 3 },
		}
		local ok = PartyBuffRules.check(buff({ cooldown = 40, breakpoints = { [10] = { a = attack } } }))
		T.expect(ok).toEqual({})
		local far =
			PartyBuffRules.check(buff({ cooldown = 40, allyRadius = 45, breakpoints = { [10] = { a = attack } } }))
		T.expect(#far > 0).toBe(true)
		local guard: any = {
			behindEffect = {
				kind = "damageReduction",
				duration = 10,
				value = 20,
				target = "allies",
				category = "allyGuard",
			},
		}
		local short = PartyBuffRules.check(buff({ cooldown = 8, breakpoints = { [10] = { a = guard } } }))
		T.expect(#short > 0).toBe(true)
		local shield: any = { allyShield = { hpPct = 10, duration = 4 } }
		T.expect(PartyBuffRules.check(buff({ cooldown = 20, breakpoints = { [10] = { a = shield } } }))).toEqual({})
	end)

	-- add.effectDuration lengthens the effects, not `duration`: the texts show the effect's time
	T.it("descriptions show the lengthened effect time (Bloodlust 5B, Battle Cry 10B, Last Bastion 5A)", function()
		local bloodlust = Skills.descriptionArgs(skill("bloodlust"), 5, { choices = { ["bloodlust:5"] = "b" } })
		T.expect(bloodlust.statBuffDuration).toBe(14)
		local cry = Skills.descriptionArgs(skill("battleCry"), 10, { choices = { ["battleCry:10"] = "b" } })
		T.expect(cry.statBuffDuration).toBe(24)
		T.expect(Skills.descriptionArgs(skill("lastBastion"), 5).damageReductionDuration).toBe(8)
		for _, texts in { pl, en } do
			T.expect(string.find(texts["skill.bloodlust.desc"], "{statBuffDuration}", 1, true) ~= nil).toBe(true)
			T.expect(string.find(texts["skill.battleCry.desc"], "{statBuffDuration}", 1, true) ~= nil).toBe(true)
			T.expect(string.find(texts["skill.lastBastion.desc"], "{damageReductionDuration}", 1, true) ~= nil)
				.toBe(true)
		end
	end)
end)

T.describe("Warrior S74", function()
	local GuardTarget = require("../src/shared/Logic/GuardTarget")
	local GamePaths = require("../src/shared/Logic/Paths")
	local PartyBuffRules = require("./PartyBuffRules")

	local NEW: { [string]: string } = {
		intercept = "guardian",
		shieldWall = "guardian",
		rend = "berserker",
		carnage = "berserker",
		warBanner = "standard",
		advanceOrder = "standard",
	}
	local function skill(id: string): SkillData.SkillDef
		return SkillData.get(id) :: SkillData.SkillDef
	end
	local function c(key: string, hp: number, distance: number): GuardTarget.Candidate
		return { key = key, hpFraction = hp, distance = distance }
	end

	T.it("GuardTarget.pick: selected, red zone, wounded, self", function()
		local zone = { c("z1", 0.8, 10), c("z2", 0.5, 12) }
		T.expect({ GuardTarget.pick(c("sel", 1, 20), zone, c("w", 0.3, 5), 25) }).toEqual({ "sel", "selected" })
		-- selected out of range falls to the zone
		T.expect({ GuardTarget.pick(c("sel", 1, 26), zone, c("w", 0.3, 5), 25) }).toEqual({ "z2", "zone" })
		-- tie on health: the nearer one
		T.expect({ GuardTarget.pick(nil, { c("a", 0.5, 10), c("b", 0.5, 5) }, nil, 25) }).toEqual({ "b", "zone" })
		-- a zone candidate out of range is skipped
		T.expect({ GuardTarget.pick(nil, { c("far", 0.1, 30) }, c("w", 0.9, 8), 25) }).toEqual({ "w", "wounded" })
		-- full health is not wounded; nobody = self
		T.expect({ GuardTarget.pick(nil, {}, c("full", 1, 3), 25) }).toEqual({ nil, "self" })
		T.expect({ GuardTarget.pick(nil, {}, nil, 25) }).toEqual({ nil, "self" })
	end)

	T.it("Skills.offensive", function()
		for _, id in { "advanceOrder", "rend", "mightyStrike", "cleave", "bladeWhirl" } do
			T.expect({ id, Skills.offensive(skill(id)) }).toEqual({ id, true })
		end
		for _, id in { "shieldWall", "intercept", "warBanner", "carnage" } do
			T.expect({ id, Skills.offensive(skill(id)) }).toEqual({ id, false })
		end
	end)

	T.it("type entries, paths, unlocks and A/B on ranks 5 and 10", function()
		T.expect({
			skill("intercept").target,
			skill("shieldWall").target,
			skill("advanceOrder").target,
			skill("warBanner").target,
		}).toEqual({ "ally", "none", "none", "point" })
		T.expect({
			Skills.shape(skill("intercept")),
			Skills.shape(skill("shieldWall")),
			Skills.shape(skill("advanceOrder")),
			Skills.shape(skill("warBanner")),
		}).toEqual({ "target", "self", "self", "circle" })
		for id, path in NEW do
			local def = skill(id)
			T.expect({ id, def.class, def.path, def.delivery, def.unlock == 26 or def.unlock == 60 })
				.toEqual({ id, "Warrior", path, "melee", true })
			local bps: any = def.breakpoints
			for _, rank in { 5, 10 } do
				T.expect({ id, rank, bps[rank].a ~= nil, bps[rank].b ~= nil }).toEqual({ id, rank, true, true })
			end
		end
		T.expect({ skill("shieldWall").hitRadius, skill("advanceOrder").hitRadius }).toEqual({ 15, 10 })
		T.expect(skill("rend").furyConsume).toBe("furyDmg")
	end)

	T.it("7.3 rules: the six pass, the exceptions hold and planted errors are caught", function()
		for id in NEW do
			T.expect({ id, PartyBuffRules.check(skill(id)) }).toEqual({ id, {} })
		end
		-- the banner's circle effects count with the banner's time (12 s, 15 s with 10A), not the 1.5 s pulse
		local banner = Skills.effective(skill("warBanner"), 10, nil, nil, true)
		T.expect(Skills.partyDuration(banner, 10)).toBe(15)
		local function variant(id: string, change: { [string]: any }): SkillData.SkillDef
			local def: any = table.clone(skill(id))
			for key, value in change do
				def[key] = value
			end
			return def
		end
		local shield: any = { [10] = { a = { allyShield = { hpPct = 15, duration = 4 } } } }
		T.expect(PartyBuffRules.check(variant("intercept", { breakpoints = shield }))).toEqual({})
		-- a shield longer than the cooldown (12 s at rank 10) is the only thing that breaks the rule: it counts for guard
		local long: any = { [10] = { a = { allyShield = { hpPct = 15, duration = 20 } } } }
		local problems = PartyBuffRules.check(variant("intercept", { breakpoints = long }))
		T.expect(#problems > 0).toBe(true)
		for _, problem in problems do
			T.expect({ problem, string.find(problem, "of shield", 1, true) ~= nil }).toEqual({ problem, true })
		end
		T.expect(#PartyBuffRules.check(variant("warBanner", { duration = 8, breakpoints = nil })) > 0).toBe(true)
		T.expect(#PartyBuffRules.check(variant("warBanner", { cooldown = 10, breakpoints = nil })) > 0).toBe(true)
		local shortCrit = {
			{
				kind = "statBuff",
				duration = 6,
				stats = { critChance = "crit" },
				target = "allies",
				category = "allyCrit",
			},
		}
		T.expect(#PartyBuffRules.check(variant("advanceOrder", { effects = shortCrit, breakpoints = nil })) > 0)
			.toBe(true)
	end)

	-- S75: their paths are published; without the skill node the skills stay out of reach.
	T.it("unreachable without their skill node", function()
		local hotbar: { [string]: string } = {}
		local i = 0
		for id in NEW do
			i += 1
			hotbar[tostring(i)] = id
		end
		local char: any = {
			class = "Warrior",
			level = 100,
			path = { nodes = {}, bp = {}, freeUsed = false },
			hotbar = hotbar,
			equipment = {},
			ranks = RankFill.auto("Warrior", 100), -- S137: the old automatic ranks as bought ranks
		}
		local available = GamePaths.availableSkills(char)
		for id in NEW do
			T.expect({ id, table.find(available, id) == nil, GamePaths.skillRank(char, id) }).toEqual({ id, true, 0 })
		end
		T.expect(GamePaths.validHotbar(char)).toEqual({})
		for id in NEW do
			local def = SkillData.get(id) :: any
			char.path = { nodes = { [`{def.path}_{id}`] = 1 }, bp = {} }
			T.expect({ id, table.find(GamePaths.availableSkills(char), id) ~= nil }).toEqual({ id, true })
		end
	end)
end)

-- S75: the Warrior's base 8 and path skills (ROZWOJ 10.2-10.5).
T.describe("S75 Warrior base and path skills", function()
	T.it("base 8 at 1, 3, 6, 10, 14, 18, 30, 45; 12 path skills at their row level", function()
		local base, onPath = {}, {}
		local actives = 0
		for _, def in SkillData.byClass.Warrior do
			if def.path == nil then
				table.insert(base, `{def.id}:{def.unlock}`)
			else
				onPath[def.id] = `{def.path}:{def.unlock}`
			end
			if def.type ~= "passive" then
				actives += 1
				for _, at in { 5, 10 } do
					local pair = def.breakpoints and def.breakpoints[at]
					T.expect({ def.id, at, pair ~= nil and pair.a ~= nil and pair.b ~= nil })
						.toEqual({ def.id, at, true })
				end
			end
		end
		T.expect(base).toEqual({
			"mightyStrike:1",
			"charge:3",
			"bladeWhirl:6",
			"taunt:10",
			"steelSkin:14",
			"bloodlust:18",
			"earthquake:30",
			"riposte:45",
		})
		T.expect(onPath).toEqual({
			fortitude = "guardian:10",
			intercept = "guardian:26",
			lastBastion = "guardian:48",
			shieldWall = "guardian:60",
			cleave = "berserker:10",
			rend = "berserker:26",
			titansWrath = "berserker:48",
			carnage = "berserker:60",
			battleCry = "standard:10",
			warBanner = "standard:26",
			crushingBlow = "standard:48",
			advanceOrder = "standard:60",
		})
		T.expect(actives).toBe(17)
	end)

	T.it("Battle Cry works on the Warrior only (team copy comes from the Commander's Voice node)", function()
		local cry = SkillData.get("battleCry") :: any
		local function own(effect: any)
			T.expect(effect.category).toBe("own")
		end
		for _, e in cry.effects do
			own(e)
		end
		for _, at in { 5, 10 } do
			for _, option in { cry.breakpoints[at].a, cry.breakpoints[at].b } do
				T.expect(option.allyEffect).toBeNil()
				for _, key in { "effect", "selfEffect" } do
					if option[key] then
						own(option[key])
					end
				end
			end
		end
	end)
end)

T.describe("Hunter engine fields (S76)", function()
	T.it("B options add up; castTime and finisher merge through breakpoints", function()
		local base = SkillData.get("volley") :: any
		local volley = table.clone(base)
		volley.breakpoints = Build.bp2(
			{ a = { add = { hits = 3 } }, b = { values = { dmg = 15 } } },
			{ a = { add = { angle = 30 } }, b = { values = { dmg = 20 } } }
		)
		local def = Skills.effective(volley, 10, { ["volley:5"] = "b", ["volley:10"] = "b" }, nil, true)
		T.expect(Skills.valueAt(def, "dmg", 10)).toBeNear(Skills.valueAt(base, "dmg", 10) + 35)
		T.expect(def.hits).toBe(base.hits)
		T.expect(def.angle).toBe(base.angle)

		local aimed = table.clone(base)
		aimed.castTime = 1.5
		aimed.finisher = { hp = 20, mul = 2 }
		aimed.breakpoints = Build.bp2({ a = { add = { castTime = -0.6 } } }, { a = { finisher = { hp = 30 } } })
		local five = Skills.effective(aimed, 5, nil, nil, true)
		T.expect(five.castTime).toBeNear(0.9)
		T.expect(five.finisher).toEqual({ hp = 20, mul = 2 })
		local ten = Skills.effective(aimed, 10, nil, nil, true)
		T.expect(ten.finisher).toEqual({ hp = 30, mul = 2 })
		T.expect(aimed.finisher).toEqual({ hp = 20, mul = 2 }) -- the data is untouched
		aimed.breakpoints = Build.bp2({ a = { add = { castTime = -2 } } }, { a = {} })
		T.expect(Skills.effective(aimed, 5, nil, nil, true).castTime).toBe(0)
	end)

	T.it("trapCost makes only traps cheaper", function()
		local trap = SkillData.get("frostTrap") :: any
		local plain = Skills.cost(trap, 5, 30, trap.class, nil)
		local cheaper = Skills.cost(trap, 5, 30, trap.class, { hooks = { trapCost = 20 } })
		T.expect(cheaper).toBeNear(plain * 0.8)
		local volley = SkillData.get("volley") :: any
		T.expect(Skills.cost(volley, 5, 60, volley.class, { hooks = { trapCost = 20 } }))
			.toBeNear(Skills.cost(volley, 5, 60, volley.class, nil))
	end)

	T.it("SkillGeom.spreadTargets picks the nearest in range, ties by id", function()
		local candidates = {
			{ id = "a", x = 3, z = 0 },
			{ id = "c", x = 0, z = 5 },
			{ id = "b", x = -5, z = 0 },
			{ id = "d", x = 7.9, z = 0 },
			{ id = "e", x = 0, z = 9 },
		}
		T.expect(SkillGeom.spreadTargets(0, 0, candidates, 2, 8)).toEqual({ "a", "b" })
		T.expect(SkillGeom.spreadTargets(0, 0, candidates, 5, 8)).toEqual({ "a", "b", "c", "d" })
		T.expect(SkillGeom.spreadTargets(0, 0, candidates, 0, 8)).toEqual({})
	end)

	T.it("Frost Trap 10B lays two traps", function()
		local trap = SkillData.get("frostTrap") :: any
		T.expect(Skills.effective(trap, 10, nil, nil, true).hits or 1).toBe(1)
		T.expect(Skills.effective(trap, 10, { ["frostTrap:10"] = "b" }, nil, true).hits).toBe(2)
	end)

	T.it("SkillGeom.sidePoints puts the second trap to the side of the aim line", function()
		local points = SkillGeom.sidePoints(0, 0, 0, -10, 2, 4)
		T.expect(points[1]).toEqual({ x = 0, z = -10 })
		local dx, dz = points[2].x - points[1].x, points[2].z - points[1].z
		T.expect(math.sqrt(dx * dx + dz * dz)).toBeNear(4)
		T.expect(dx * 0 + dz * -1).toBeNear(0) -- perpendicular to the direction (0, -1)
	end)
end)

T.describe("Hunter S77", function()
	local GamePaths = require("../src/shared/Logic/Paths")
	local NEW = {
		drawBead = { path = "marksman", unlock = 26 },
		heartseeker = { path = "marksman", unlock = 60 },
		venomSnare = { path = "trapper", unlock = 26 },
		snarefield = { path = "trapper", unlock = 60 },
		falcon = { path = "scout", unlock = 26 },
		drive = { path = "scout", unlock = 80 },
	}

	T.it("six path skills: path, delivery, unlock, A and B on 5 and 10", function()
		for id, want in NEW do
			local skill = SkillData.get(id) :: any
			T.expect({ id, skill.class, skill.path, skill.unlock, skill.delivery }).toEqual({
				id,
				"Hunter",
				want.path,
				want.unlock,
				"ranged",
			})
			for _, at in { 5, 10 } do
				local pair = skill.breakpoints[at]
				T.expect({ id, at, pair.a ~= nil, pair.b ~= nil }).toEqual({ id, at, true, true })
			end
		end
	end)

	T.it("Falcon: no target, self shape, offensive, interval only for companions", function()
		local falcon = SkillData.get("falcon") :: any
		T.expect(falcon.target).toBe("none")
		T.expect(Skills.shape(falcon)).toBe("self")
		T.expect(Skills.offensive(falcon)).toBe(true)
		T.expect(Skills.descriptionArgs(falcon, 1).interval).toBe(2)
		T.expect(Skills.descriptionArgs(SkillData.get("doubleShot") :: any, 1).interval).toBeNil()
		T.expect((SkillData.get("venomSnare") :: any).target).toBe("point")
		T.expect((SkillData.get("snarefield") :: any).target).toBe("point")
	end)

	-- S78: their paths have a PathDef; the skills need their node (and the main path above row 2).
	T.it("reachable with their skill node from S78", function()
		local hotbar: { [string]: string } = {}
		local slot = 0
		for id in NEW do
			slot += 1
			hotbar[tostring(slot)] = id
		end
		local hunter: any = { class = "Hunter", level = 100, path = nil, hotbar = hotbar, equipment = {} }
		hunter.ranks = RankFill.auto("Hunter", 100) -- S137
		local available = GamePaths.availableSkills(hunter)
		for id in NEW do
			T.expect({ id, table.find(available, id) }).toEqual({ id, nil })
			T.expect({ id, GamePaths.skillRank(hunter, id) }).toEqual({ id, 0 })
		end
		T.expect((GamePaths.validHotbar(hunter))).toEqual({})
		hunter.path = { nodes = { scout_falcon = 1, scout_drive = 1 }, bp = {} }
		local withNodes = GamePaths.availableSkills(hunter)
		T.expect(table.find(withNodes, "falcon") ~= nil).toBe(true)
		T.expect(table.find(withNodes, "drive") ~= nil).toBe(true)
		T.expect(table.find(withNodes, "drawBead")).toBeNil()
		-- S138: a row-4 skill with its node in any direction mix
		hunter.path.nodes.marksman_steadyHand = 3
		T.expect(GamePaths.skillRank(hunter, "falcon") > 0).toBe(true)
	end)
end)

-- S78: the Hunter's base 8, B options and composition with path nodes (ROZWOJ 2.7, 11.2-11.5).
T.describe("S78 Hunter base, B options and nodes", function()
	local GamePaths = require("../src/shared/Logic/Paths")

	T.it("base 8 at 1, 3, 6, 10, 14, 18, 30, 45; 12 path skills at their row level; B on every active", function()
		local base, onPath = {}, {}
		local actives, passives = 0, 0
		for _, def in SkillData.byClass.Hunter do
			if def.path == nil then
				table.insert(base, `{def.id}:{def.unlock}`)
				passives += if def.type == "passive" then 1 else 0
			else
				onPath[def.id] = `{def.path}:{def.unlock}`
			end
			if def.type ~= "passive" then
				actives += 1
				for _, at in { 5, 10 } do
					local pair = def.breakpoints and def.breakpoints[at]
					T.expect({ def.id, at, pair ~= nil and pair.a ~= nil and pair.b ~= nil })
						.toEqual({ def.id, at, true })
				end
			end
		end
		T.expect(base).toEqual({
			"aimedShot:1",
			"doubleShot:3",
			"disengage:6",
			"arrowRain:10",
			"hawkEye:14",
			"venomArrow:18",
			"volley:30",
			"predatorInstinct:45",
		})
		T.expect(passives).toBe(2)
		T.expect(onPath).toEqual({
			piercingArrow = "marksman:10",
			drawBead = "marksman:26",
			stormArrow = "marksman:48",
			heartseeker = "marksman:60",
			frostTrap = "trapper:10",
			venomSnare = "trapper:26",
			camouflage = "trapper:48",
			snarefield = "trapper:60",
			agility = "scout:10",
			falcon = "scout:26",
			huntersMark = "scout:48",
			drive = "scout:80",
		})
		T.expect(actives).toBe(17)
	end)

	local function hunter(_main: string, nodes: { [string]: number }, bp: { [string]: string }): any
		return {
			class = "Hunter",
			level = 100,
			path = { nodes = nodes, bp = bp }, -- S138: no main path
			hotbar = {},
			equipment = {},
			ranks = RankFill.auto("Hunter", 100), -- S137: the old automatic ranks as bought ranks
		}
	end
	local function eff(
		skillId: string,
		main: string,
		nodes: { [string]: number },
		bp: { [string]: string },
		weapons: any
	): (any, any)
		local skill = SkillData.get(skillId) :: any
		local mods = GamePaths.skillMods(hunter(main, nodes, bp), skillId, weapons)
		return Skills.effective(skill, 10, bp :: any, mods, true)
	end
	local function effectsOf(list: { any }?, kind: string): { any }
		local out = {}
		for _, e in list or {} do
			if e.kind == kind then
				table.insert(out, e)
			end
		end
		return out
	end
	local LONGBOW = { main = "longbow", offhand = "quiver" }
	local HEAVY = { main = "heavycrossbow" }
	local CROSSBOW = { main = "crossbow" }
	local BOW = { main = "bow" }

	T.it("Marksman: Aimed Shot, Heartseeker, any weapon (S138)", function()
		local aimed = eff("aimedShot", "marksman", { marksman_longShot = 3 }, { ["aimedShot:5"] = "b" }, LONGBOW)
		T.expect(Skills.valueAt(aimed, "dmg", 10)).toBeNear(271, 1e-9)
		local _, rhythm = eff("aimedShot", "marksman", { marksman_rhythm = 3 }, {}, LONGBOW)
		T.expect(rhythm.critCdr).toBeNear(50, 1e-9)
		local heart = eff("heartseeker", "marksman", { marksman_heartseeker2 = 2 }, { ["heartseeker:5"] = "a" }, HEAVY)
		T.expect(Skills.valueAt(heart, "dmg", 10)).toBeNear(357, 1e-9)
		local tip = eff("heartseeker", "marksman", { marksman_deadlyTip = 3 }, {}, HEAVY)
		T.expect(tip.finisher.hp).toBeNear(36, 1e-9)
		T.expect(tip.finisher.mul).toBe(2)
		local sniper = eff("heartseeker", "marksman", { marksman_sniper = 3 }, {}, HEAVY)
		T.expect(sniper.castTime).toBeNear(0.9, 1e-9)
		-- S138: no direction weapon: Long Shot (row 5) works with a bow as with a longbow
		local bow = eff("aimedShot", "marksman", { marksman_longShot = 3 }, { ["aimedShot:5"] = "b" }, BOW)
		T.expect(Skills.valueAt(bow, "dmg", 10)).toBeNear(271, 1e-9)
	end)

	T.it("base B options: Venom Arrow, Volley, Hunter's Mark, Disengage", function()
		local venom = eff("venomArrow", "trapper", {}, { ["venomArrow:5"] = "a", ["venomArrow:10"] = "b" }, BOW)
		T.expect(Skills.valueAt(venom, "poison", 10)).toBeNear(131, 1e-9)
		local volley = eff("volley", "scout", {}, { ["volley:5"] = "b", ["volley:10"] = "b" }, BOW)
		T.expect(Skills.valueAt(volley, "dmg", 10)).toBeNear(48, 1e-9)
		local mark = SkillData.get("huntersMark") :: any
		T.expect(Skills.valueAt(mark, "vuln", 10)).toBeNear(8, 1e-9)
		local mark10 = eff("huntersMark", "scout", {}, { ["huntersMark:10"] = "b" }, BOW)
		T.expect(Skills.valueAt(mark10, "vuln", 10)).toBeNear(9, 1e-9)
		-- ROZWOJ 11.4: the Snarefield (with 5B) and the Drive never beat the Mark (one enemyWeak counts)
		local field = eff("snarefield", "trapper", {}, { ["snarefield:5"] = "b" }, CROSSBOW)
		T.expect(Skills.valueAt(field, "vuln", 10) <= Skills.valueAt(mark10, "vuln", 10)).toBe(true)
		local drive = eff("drive", "scout", {}, { ["drive:10"] = "b" }, BOW)
		T.expect(Skills.valueAt(drive, "vuln", 10) <= Skills.valueAt(mark10, "vuln", 10)).toBe(true)
		local mark5 = eff("huntersMark", "scout", {}, { ["huntersMark:5"] = "b" }, BOW)
		T.expect(mark5.radius).toBe(6)
		local leap = eff("disengage", "scout", {}, { ["disengage:10"] = "b" }, BOW)
		local buff = leap.selfEffects[1]
		T.expect({ buff.kind, buff.stats.dodge, buff.duration, buff.category })
			.toEqual({ "statBuff", "dodgeBp", 4, "own" })
		T.expect(Skills.valueAt(leap, "dodgeBp", 10)).toBeNear(20, 1e-9)
	end)

	T.it("Trapper: Frost Trap 5B + Blast Trap merge one poison, Virulence, Biting Rain", function()
		local trap = eff("frostTrap", "trapper", { trapper_blastTrap = 3 }, { ["frostTrap:5"] = "b" }, CROSSBOW)
		T.expect(Skills.valueAt(trap, "poison", 10)).toBeNear(34, 1e-9)
		T.expect(Skills.valueAt(trap, "dmg", 10)).toBeNear(38, 1e-9)
		T.expect(#effectsOf(trap.effects, "poison")).toBe(1)
		local arrow, behaviour = eff("venomArrow", "trapper", { trapper_virulence = 3 }, {}, CROSSBOW)
		T.expect(effectsOf(arrow.effects, "poison")[1].duration).toBeNear(12, 1e-9)
		T.expect(behaviour.poisonStacks).toBe(3)
		local _, rain = eff("arrowRain", "trapper", { trapper_bitingRain = 3 }, {}, CROSSBOW)
		T.expect(rain.firstWave).toBeNear(11, 1e-9)
		T.expect({ rain.lingering.kind, rain.lingering.duration }).toEqual({ "poison", 4 })
		T.expect(rain.lingering.pct).toBeNear(7.5, 1e-9)
	end)

	T.it("Scout: Falcon with Sharp Talons, the Drive with Seasoned Beater (root stays 1 s)", function()
		local falcon = eff("falcon", "scout", { scout_talons = 3 }, { ["falcon:10"] = "a" }, BOW)
		T.expect(Skills.valueAt(falcon, "dmg", 10)).toBeNear(87, 1e-9)
		local drive = eff("drive", "scout", { scout_beater = 3 }, { ["drive:10"] = "b" }, BOW)
		T.expect(effectsOf(drive.effects, "vulnerability")[1].duration).toBeNear(13.5, 1e-9)
		T.expect(effectsOf(drive.effects, "slow")[1].duration).toBeNear(8.5, 1e-9)
		T.expect(effectsOf(drive.effects, "root")[1].duration).toBeNear(1, 1e-9)
	end)

	T.it("identical effects from two sources merge (ROZWOJ 2.7)", function()
		local skill = table.clone(SkillData.get("frostTrap") :: any)
		local poison = { kind = "poison", duration = 6, value = "poison" }
		local mods = {
			{ values = { poison = 10 }, effect = table.clone(poison) },
			{ values = { poison = 5 }, effect = table.clone(poison) },
			{ effect = { kind = "poison", duration = 4, value = "poison" } },
		}
		local def = Skills.effective(skill, 10, {}, mods :: any, true)
		T.expect(#effectsOf(def.effects, "poison")).toBe(2)
		T.expect(Skills.valueAt(def, "poison", 10)).toBeNear(15, 1e-9)
	end)
end)

T.describe("S79 spell cost hooks", function()
	local firebolt = SkillData.byId.firebolt
	local meteor = SkillData.byId.meteor
	local blink = SkillData.byId.blink

	T.it("areaCost and spellCost raise the base cost, plus = dearer, before the item saving", function()
		local paid, base = Skills.cost(meteor, 1, 20, "Mage", { hooks = { areaCost = -12 } })
		T.expect(paid).toBeNear(63.36)
		T.expect(base).toBeNear(63.36)
		T.expect((Skills.cost(meteor, 1, 20, "Mage", { hooks = { areaCost = -12, spellCost = 30 } }))).toBeNear(84.96)
		T.expect((Skills.cost(firebolt, 1, 20, "Mage", { hooks = { spellCost = 30 } }))).toBeNear(15.6)
		T.expect((Skills.cost(firebolt, 1, 20, "Mage", { hooks = { areaCost = -12 } }))).toBeNear(12)
		T.expect((Skills.cost(blink, 1, 20, "Mage", { hooks = { spellCost = 30 } })))
			.toBe((Skills.cost(blink, 1, 20, "Mage")))
		paid, base = Skills.cost(meteor, 1, 20, "Mage", { hooks = { areaCost = -12 }, costReduce = 10 })
		T.expect(paid).toBeNear(57.024)
		T.expect(base).toBeNear(63.36)
		T.expect((Skills.cost(meteor, 1, 20, "Mage"))).toBe(72)
	end)

	T.it("Bolt has one shot in the data; hits and channelMove come through breakpoints", function()
		T.expect(firebolt.hits).toBe(1)
		local fake: any = table.clone(firebolt)
		fake.breakpoints = Build.bp2({ a = { add = { hits = 1 } } }, { a = { channelMove = 50 } })
		local def = Skills.effective(fake, 10, nil, nil, true)
		T.expect(def.hits).toBe(2)
		T.expect(def.channelMove).toBe(50)
		T.expect(firebolt.channelMove).toBeNil()
	end)
end)

-- S80 (ROZWOJ 12.4, 12.5): Arcane Charges, the beam and the four new Mage skills.
T.describe("Arcane Charges and beam (S80)", function()
	local GamePaths = require("../src/shared/Logic/Paths")
	local fireball = SkillData.byId.fireball
	local blink = SkillData.byId.blink
	local torrent = SkillData.byId.arcaneTorrent
	local NEW = {
		elementalVortex = { path = "destroyer", unlock = 26, delivery = "melee" },
		cataclysm = { path = "destroyer", unlock = 60, delivery = "ranged" },
		arcaneDischarge = { path = "arcanist", unlock = 26, delivery = "ranged" },
		arcaneTorrent = { path = "arcanist", unlock = 60, delivery = "ranged" },
	}

	T.it("charges raise the base cost of damaging spells, the saving applies after them", function()
		local paid0, base0 = Skills.cost(fireball, 10, 60, "Mage")
		local paid4, base4 = Skills.cost(fireball, 10, 60, "Mage", { charges = 4 })
		T.expect(base4).toBeNear(base0 * 1.172)
		T.expect(paid4).toBeNear(paid0 * 1.172)
		local _, cool = Skills.cost(fireball, 10, 60, "Mage", { charges = 4, hooks = { chargeCost = -2 } })
		T.expect(cool).toBeNear(base0 * 1.092)
		local paid, base = Skills.cost(fireball, 10, 60, "Mage", { charges = 4, costReduce = 20 })
		T.expect(paid / base).toBeNear(0.8)
		T.expect({ Skills.cost(blink, 10, 60, "Mage", { charges = 4 }) })
			.toEqual({ Skills.cost(blink, 10, 60, "Mage") })
		T.expect({ Skills.cost(fireball, 10, 60, "Mage", { charges = 0 }) }).toEqual({ paid0, base0 })
	end)

	T.it("damage factors, decay and the cap", function()
		T.expect(Skills.chargeDamageFactor(4, 0)).toBeNear(1.04)
		T.expect(Skills.chargeDamageFactor(4, 1.5)).toBeNear(1.1)
		T.expect(Skills.dischargeFactor(12, 4)).toBeNear(1.48)
		T.expect(Skills.dischargeFactor(27, 4)).toBeNear(2.08)
		T.expect(Skills.chargesNow(3, 110, 100, true)).toBe(3)
		T.expect(Skills.chargesNow(3, 110, 100, false)).toBe(0)
		T.expect(Skills.chargesNow(3, 90, 100, true)).toBe(0)
		T.expect(Skills.chargesAfterGain(3, 1)).toBe(4)
		T.expect(Skills.chargesAfterGain(4, 1)).toBe(4)
		T.expect(Skills.chargesAfterGain(1, 4)).toBe(4)
		T.expect(Skills.chargesAfterGain(0, 1)).toBe(1)
	end)

	T.it("damaging spells and the consumer", function()
		for id in NEW do
			T.expect({ id, Skills.isSpell(SkillData.byId[id]) }).toEqual({ id, true })
		end
		T.expect(Skills.consumesCharges(SkillData.byId.arcaneDischarge)).toBe(true)
		for _, id in { "firebolt", "arcaneTorrent", "evocation" } do
			T.expect({ id, Skills.consumesCharges(SkillData.byId[id]) }).toEqual({ id, false })
		end
	end)

	T.it("Arcane Torrent: ticks, growth and the drain without the mana curve", function()
		local def = Skills.effective(torrent, 1, nil, nil, true)
		T.expect(Skills.beamTicks(def)).toBe(8)
		local longer = Skills.effective(torrent, 1, nil, { { add = { duration = 1 } } }, true)
		T.expect(Skills.beamTicks(longer)).toBe(10)
		T.expect(Skills.beamTickPct(160, 2, 1)).toBeNear(160)
		T.expect(Skills.beamTickPct(160, 2, 8)).toBeNear(182.4)
		T.expect({ Skills.drain(torrent, 1, 1000, nil) }).toEqual({ 7.3, 7.3 })
		T.expect((Skills.drain(torrent, 1, 1000, { charges = 4 }))).toBeNear(7.3 * 1.172)
		local paid, base = Skills.drain(torrent, 1, 1000, { charges = 4, costReduce = 20 })
		T.expect(paid).toBeNear(7.3 * 1.172 * 0.8)
		T.expect(base).toBeNear(7.3 * 1.172)
		T.expect({ Skills.drain(torrent, 10, 1000, nil) }).toEqual({ Skills.drain(torrent, 1, 1000, nil) })
		T.expect(Skills.tag(torrent)).toBe("single")
	end)

	T.it("four path skills: path, delivery, unlock, A and B on 5 and 10", function()
		for id, want in NEW do
			local skill = SkillData.byId[id] :: any
			T.expect({ id, skill.class, skill.path, skill.unlock, skill.delivery }).toEqual({
				id,
				"Mage",
				want.path,
				want.unlock,
				want.delivery,
			})
			for _, at in { 5, 10 } do
				local pair = skill.breakpoints[at]
				T.expect({ id, at, pair.a ~= nil, pair.b ~= nil }).toEqual({ id, at, true, true })
			end
		end
		T.expect((SkillData.byId.cataclysm :: any).pull).toBe(true)
		T.expect(torrent.target).toBe("enemy")
		T.expect(Skills.descriptionArgs(torrent, 1).ticks).toBe(8)
		T.expect(Skills.descriptionArgs(fireball, 1).ticks).toBeNil()
	end)

	T.it("reachable with their skill node from S81", function()
		local hotbar: { [string]: string } = {}
		local slot = 0
		for id in NEW do
			slot += 1
			hotbar[tostring(slot)] = id
		end
		local mage: any = { class = "Mage", level = 100, path = nil, hotbar = hotbar, equipment = {} }
		mage.ranks = RankFill.auto("Mage", 100) -- S137
		local available = GamePaths.availableSkills(mage)
		for id in NEW do
			T.expect({ id, table.find(available, id) }).toEqual({ id, nil })
			T.expect({ id, GamePaths.skillRank(mage, id) }).toEqual({ id, 0 })
		end
		T.expect((GamePaths.skillUsable(mage, "arcaneDischarge", { main = "runestaff" }))).toBe(false)
		T.expect((GamePaths.validHotbar(mage))).toEqual({})
		mage.path = { nodes = { arcanist_arcaneDischarge = 1 }, bp = {} }
		local withNode = GamePaths.availableSkills(mage)
		T.expect(table.find(withNode, "arcaneDischarge") ~= nil).toBe(true)
		T.expect(table.find(withNode, "arcaneTorrent")).toBeNil()
		-- Arcane Discharge needs its node (S138: any Mage weapon, any direction mix)
		T.expect((GamePaths.skillUsable(mage, "arcaneDischarge", { main = "runestaff" }))).toBe(true)
		T.expect((GamePaths.skillUsable(mage, "arcaneDischarge", { main = "wand", offhand = "tome" }))).toBe(true)
		T.expect((GamePaths.skillUsable(mage, "arcaneDischarge", { main = "staff" }))).toBe(true)
		mage.path.nodes.destroyer_trace = 3
		T.expect(GamePaths.skillRank(mage, "arcaneDischarge") > 0).toBe(true)
	end)
end)

-- S81: the Mage's base 8, B options and composition with path nodes (ROZWOJ 2.7, 12.2-12.5).
T.describe("S81 Mage base, B options and nodes", function()
	local GamePaths = require("../src/shared/Logic/Paths")

	-- S140 (DESIGN-18 §6.1): the fire pool and the common skills joined the base; 4 skills stay on the directions.
	-- S141: the ice pool (Ice Shard 1, Frost Nova 6, nine new skills at the end of the list)
	T.it("the base (S141), 4 path skills at their row level; B on every active", function()
		local base, onPath = {}, {}
		local actives, passives = 0, 0
		for _, def in SkillData.byClass.Mage do
			if def.path == nil then
				table.insert(base, `{def.id}:{def.unlock}`)
				passives += if def.type == "passive" then 1 else 0
			else
				onPath[def.id] = `{def.path}:{def.unlock}`
			end
			if def.type ~= "passive" then
				actives += 1
				for _, at in { 5, 10 } do
					local pair = def.breakpoints and def.breakpoints[at]
					T.expect({ def.id, at, pair ~= nil and pair.a ~= nil and pair.b ~= nil })
						.toEqual({ def.id, at, true })
				end
			end
		end
		T.expect(base).toEqual({
			"firebolt:1",
			"fireball:3",
			"iceShard:1",
			"chainLightning:10",
			"blink:4",
			"frostNova:6",
			"meteor:26",
			"firewall:45",
			"flameWave:6",
			"emberShield:10",
			"pyroblast:15",
			"kindling:20",
			"combustion:33",
			"immolate:40",
			"phoenixHeart:50",
			"meteorStorm:60",
			"manaShield:12",
			"evocation:30",
			"focus:45",
			"hailstorm:3",
			"iceBarrier:10",
			"glacialSpike:15",
			"wintersGrip:20",
			"frozenOrb:26",
			"deepFreeze:33",
			"shatter:40",
			"iceBlood:50",
			"blizzard:60",
		})
		T.expect(passives).toBe(5)
		T.expect(onPath).toEqual({
			elementalVortex = "destroyer:26",
			cataclysm = "destroyer:60",
			arcaneDischarge = "arcanist:26",
			arcaneTorrent = "arcanist:60",
		})
		T.expect(actives).toBe(27)
		-- changed data (ROZWOJ 12.4, 12.5, 15.5.4)
		local function v(id: string, field: string, rank: number): number
			return Skills.valueAt(SkillData.get(id) :: any, field, rank)
		end
		T.expect({ v("meteorStorm", "dmg", 1), v("meteorStorm", "dmg", 10) }).toEqual({ 24, 24 })
		T.expect({ v("focus", "reserve", 1), v("focus", "reserve", 5) }).toEqual({ 3.1, 15.4 })
		T.expect((SkillData.get("focus") :: any).passive).toEqual({ pct = { manaReserve = "reserve" } })
		T.expect((SkillData.get("evocation") :: any).cooldown).toBe(120)
	end)

	local function mage(_main: string, nodes: { [string]: number }, bp: { [string]: string }): any
		return {
			class = "Mage",
			level = 100,
			path = { nodes = nodes, bp = bp }, -- S138: no main path
			hotbar = {},
			equipment = {},
			ranks = RankFill.auto("Mage", 100), -- S137: the old automatic ranks as bought ranks
		}
	end
	local function eff(
		skillId: string,
		main: string,
		nodes: { [string]: number },
		bp: { [string]: string },
		weapons: any
	): (any, any)
		local skill = SkillData.get(skillId) :: any
		local mods = GamePaths.skillMods(mage(main, nodes, bp), skillId, weapons)
		return Skills.effective(skill, 10, bp :: any, mods, true)
	end
	local STAFF = { main = "staff" }
	local RUNESTAFF = { main = "runestaff" }

	T.it("Meteor 5B + 10B and Magic Bolt 5B / 10B", function()
		local meteor = eff("meteor", "destroyer", {}, { ["meteor:5"] = "b", ["meteor:10"] = "b" }, STAFF)
		T.expect(Skills.valueAt(meteor, "dmg", 10)).toBeNear(239, 1e-9) -- S140: 5B +20 (was +23)
		local bolt = eff("firebolt", "destroyer", {}, { ["firebolt:5"] = "b", ["firebolt:10"] = "b" }, STAFF)
		T.expect(bolt.hits).toBe(2)
		T.expect(Skills.valueAt(bolt, "dmg", 10)).toBeNear(151.7, 1e-9)
		T.expect(Skills.cooldown(bolt, 10)).toBeNear(2.2, 1e-9)
	end)

	T.it("Arcane Discharge with Full Discharge, Elemental Vortex with Raging Vortex, any weapon (S138)", function()
		local discharge = eff(
			"arcaneDischarge",
			"arcanist",
			{ arcanist_arcaneDischarge = 1, arcanist_fullDischarge = 3 },
			{ ["arcaneDischarge:5"] = "a" },
			RUNESTAFF
		)
		T.expect(Skills.valueAt(discharge, "perCharge", 10)).toBeNear(19, 1e-9)
		local nodes = { destroyer_elementalVortex = 1, destroyer_raging = 3 }
		local bp = { ["elementalVortex:5"] = "b" }
		local vortex = eff("elementalVortex", "destroyer", nodes, bp, { main = "wand", offhand = "orb" })
		T.expect(Skills.valueAt(vortex, "dmg", 10)).toBeNear(10.97, 1e-9)
		-- S138: a tome in the Destroyer's off-hand: no direction weapon, rows 4 and 9 work as with the orb
		local plain = eff("elementalVortex", "destroyer", nodes, bp, { main = "wand", offhand = "tome" })
		T.expect(Skills.valueAt(plain, "dmg", 10)).toBeNear(10.97, 1e-9)
	end)

	T.it(
		"node behaviours compose: Storm's Wrath, Swift Cataclysm, Empowering Invocation, Archmage, the Torrent",
		function()
			-- S140: Storm's Wrath and Elemental Echo shape the Vortex (Wrath of Elements left for the fire pool)
			local _, wrath = eff(
				"elementalVortex",
				"destroyer",
				{ destroyer_elementalVortex = 1, destroyer_wrath = 3, destroyer_echo = 1 },
				{},
				STAFF
			)
			T.expect(wrath.cdrPerTarget.max).toBe(5)
			T.expect(wrath.cdrPerTarget.sec).toBeNear(0.9, 1e-9)
			T.expect(wrath.echo).toEqual({ delay = 0.4, pct = 100 })
			local cataclysm = eff(
				"cataclysm",
				"destroyer",
				{ destroyer_cataclysm = 1, destroyer_swift = 3, destroyer_cataclysm2 = 2 },
				{},
				STAFF
			)
			T.expect(Skills.cooldown(cataclysm, 10)).toBeNear(24.42, 1e-9)
			T.expect(cataclysm.hits).toBe(7)
			local nodes = { arcanist_quickening = 1, arcanist_invocation = 3, arcanist_archmage = 3 }
			local evocation, behaviour = eff("evocation", "arcanist", nodes, { ["evocation:5"] = "a" }, RUNESTAFF)
			T.expect(behaviour.empower).toEqual({ pct = 11.7, uses = 3 })
			T.expect(evocation.duration).toBeNear(1.69, 1e-9)
			T.expect(Skills.cooldown(evocation, 10)).toBeNear(90, 1e-9)
			local torrentNodes = { arcanist_arcaneTorrent = 1, arcanist_rending = 3, arcanist_torrent2 = 2 }
			local torrent = eff("arcaneTorrent", "arcanist", torrentNodes, { ["arcaneTorrent:5"] = "a" }, RUNESTAFF)
			T.expect(Skills.valueAt(torrent, "growth", 10)).toBeNear(8.52, 1e-9)
			T.expect(Skills.beamTicks(torrent)).toBe(10)
			local well = eff(
				"arcaneTorrent",
				"arcanist",
				{ arcanist_arcaneTorrent = 1, arcanist_well = 3 },
				{},
				RUNESTAFF
			)
			T.expect(Skills.valueAt(well, "drain", 10)).toBeNear(0.36, 1e-9)
		end
	)

	T.it("B options of the base and the moved skills", function()
		local function b(id: string, at: number): any
			local def = SkillData.get(id) :: any
			return (Skills.effective(def, 10, { [`{id}:{at}`] = "b" } :: any, nil, true))
		end
		T.expect(Skills.cooldown(b("iceShard", 10), 10)).toBeNear(5 * 0.84, 1e-9)
		T.expect(b("blink", 5).length).toBe(20)
		local _, trap = Skills.effective(SkillData.get("blink") :: any, 10, { ["blink:10"] = "b" } :: any, nil, true)
		T.expect(trap.trap).toEqual({ radius = 6, duration = 3, slow = 40 })
		local _, nova =
			Skills.effective(SkillData.get("frostNova") :: any, 10, { ["frostNova:10"] = "b" } :: any, nil, true)
		T.expect(nova.echo).toEqual({ delay = 1.5, pct = 19 })
		local _, shield =
			Skills.effective(SkillData.get("manaShield") :: any, 10, { ["manaShield:10"] = "b" } :: any, nil, true)
		T.expect(shield.selfHeal).toBe(10)
		local _, evocation = Skills.effective(
			SkillData.get("evocation") :: any,
			10,
			{ ["evocation:5"] = "b", ["evocation:10"] = "b" } :: any,
			nil,
			true
		)
		T.expect({ evocation.channelMove, evocation.grantCharges }).toEqual({ 50, 4 })
		T.expect(Skills.valueAt(b("meteorStorm", 10), "dmg", 10)).toBeNear(28.4, 1e-9)
		T.expect(Skills.cooldown(b("meteorStorm", 5), 10)).toBeNear(44, 1e-9)
	end)
end)

T.describe("Skill value knots (S83, Data/SkillCurves)", function()
	local SkillCurves = require("../src/shared/Data/SkillCurves")

	T.it("without knots valueAt is exactly Skills.scaled for every skill, field and rank", function()
		for id, skill in SkillData.byId do
			if SkillCurves.knots[id] == nil then
				for field, value in skill.values do
					for rank = 1, skill.maxLevel do
						T.expect(Skills.valueAt(skill, field, rank)).toBe(Skills.scaled(skill, value, rank))
					end
				end
			end
		end
	end)

	T.it("interpolate is linear between the points and clamped outside", function()
		local points = { { 1, 100 }, { 5, 150 }, { 10, 190 } }
		local expected = { [1] = 100, [3] = 125, [5] = 150, [7] = 166, [10] = 190, [0] = 100, [12] = 190 }
		for rank, value in expected do
			T.expect(Skills.interpolate(points, rank)).toBeNear(value, 1e-9)
		end
	end)

	T.it("every knot is on a { rank 1, max rank } pair of an existing skill, rank 2..max - 1, finite", function()
		for skillId, fields in SkillCurves.knots do
			local skill = SkillData.byId[skillId]
			T.expect(skill ~= nil).toBe(true)
			if skill then
				for field, knots in fields do
					local pair = skill.values[field]
					T.expect(type(pair) == "table" and #(pair :: any) == 2).toBe(true)
					for rank, value in knots do
						local ok = rank == math.floor(rank) and rank >= 2 and rank <= skill.maxLevel - 1
						T.expect(ok and value == value and math.abs(value) ~= math.huge).toBe(true)
					end
				end
			end
		end
	end)

	T.it("breakpoints change values exactly as before the knots (the pre-S83 arithmetic)", function()
		for _, skill in SkillData.byId do
			if skill.breakpoints then
				for _, option in { "a", "b" } do
					local choices: Skills.Choices = {}
					for _, at in Skills.BREAKPOINT_LEVELS do
						choices[Skills.choiceKey(skill.id, at)] = option :: any
					end
					for rank = 1, skill.maxLevel do
						local def = Skills.effective(skill, rank, choices, nil, true)
						local values: { [string]: any } = table.clone(skill.values) :: any
						local jumps = 0
						-- S89: the value at the rank goes through the Data/SkillCurves knots (Skills.valueAt), a number
						-- already changed by a breakpoint passes as it is
						local function at(field: string): number
							local v = values[field]
							return if type(v) == "number" then v else Skills.valueAt(skill, field, rank)
						end
						for _, bp in Skills.breakpointsAt(skill, rank, choices, true) do
							for field, amount in (bp.values or {}) :: { [string]: number } do
								values[field] = at(field) + amount
							end
							jumps += ((bp.add or {}) :: any).jumps or 0
						end
						if jumps ~= 0 then
							values.jumps = at("jumps") + jumps
						end
						for field, value in values do
							if type(value) == "number" then
								T.expect(def.values[field]).toBe(value)
							end
						end
					end
				end
			end
		end
	end)
end)

return nil
