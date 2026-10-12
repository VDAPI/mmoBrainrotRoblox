--!strict
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Bases = require("../src/shared/Data/Items/Bases")
local Classes = require("../src/shared/Data/Classes")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
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
	passive = true,
}

local function character(classId: string, level: number): any
	local c = AccountSchema.characterTemplate()
	c.class = classId :: any
	c.level = level
	return c
end

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
		T.expect(Skills.valueAt(mighty, "dmg", 1)).toBe(160)
		T.expect(Skills.valueAt(mighty, "dmg", 10)).toBe(295)
		T.expect(Skills.valueAt(mighty, "dmg", 5)).toBeNear(160 + 135 * 4 / 9)
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

	T.it("rankFor and rankOf", function()
		local cleave = SkillData.get("cleave") :: any
		T.expect(Skills.rankFor("Warrior", 17, cleave)).toBe(0)
		T.expect(Skills.rankFor("Warrior", 18, cleave)).toBe(1)
		T.expect(Skills.rankFor("Warrior", 54, cleave)).toBe(10)
		T.expect(Skills.rankFor("Mage", 54, cleave)).toBe(0)
		T.expect(Skills.rankOf(character("Warrior", 54), "nope")).toBe(0)
		T.expect(Skills.rankOf(character("Warrior", 54), "cleave")).toBe(10)
	end)

	T.it("transitional ladder (ROZWOJ 2.6): every class skill, 19 ranks at level 20", function()
		for _, classId in Classes.order do
			local unlocked = Skills.unlocked(classId, 100)
			T.expect(#unlocked).toBe(#SkillData.byClass[classId])
			local total = 0
			for _, skill in SkillData.byClass[classId] do
				total += Skills.rankFor(classId, 20, skill)
			end
			T.expect(total).toBe(19)
		end
	end)

	T.it("starting skill and start hotbar", function()
		for _, classId in Classes.order do
			local start = Skills.startingSkill(classId) :: string
			local def = SkillData.get(start) :: any
			T.expect(def.unlock).toBe(1)
			T.expect(def.type ~= "passive").toBe(true)
			local bar = Skills.startHotbar(classId, 100)
			local n = 0
			for slot = 1, 10 do
				local skill = SkillData.get(bar[tostring(slot)]) :: any
				T.expect(skill.type ~= "passive").toBe(true)
				n += 1
			end
			T.expect(n).toBe(10)
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
		T.expect(ids(Skills.newlyUnlocked("Warrior", 2, 6))).toEqual({ "battleCry", "charge" })
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

	T.it("cleanHotbar", function()
		local bar, changed = Skills.cleanHotbar("Hunter", 20, {
			["1"] = "aimedShot",
			["2"] = "hawkEye",
			["3"] = "frostTrap",
			["4"] = "firebolt",
			["5"] = "aimedShot",
			["6"] = "nope",
			["7"] = "doubleShot",
			["11"] = "disengage",
		})
		T.expect(bar).toEqual({ ["1"] = "aimedShot", ["7"] = "doubleShot" })
		T.expect(changed).toBe(true)
		local good = { ["1"] = "aimedShot", ["3"] = "doubleShot" }
		local same, changed2 = Skills.cleanHotbar("Hunter", 20, good)
		T.expect(same).toEqual(good)
		T.expect(changed2).toBe(false)
		local empty, changed3 = Skills.cleanHotbar("Hunter", 20, "oops")
		T.expect(empty).toEqual({})
		T.expect(changed3).toBe(true)
	end)

	T.it("validHotbar: unlocked actives of the class", function()
		local c = character("Hunter", 30)
		T.expect(Skills.validHotbar(c, 1, "aimedShot")).toBe(true)
		T.expect(Skills.validHotbar(c, 10, nil)).toBe(true)
		T.expect(Skills.validHotbar(c, 11, "aimedShot")).toBe(false)
		T.expect(Skills.validHotbar(c, 2, "hawkEye")).toBe(false) -- passive
		T.expect(Skills.validHotbar(c, 2, "piercingArrow")).toBe(false) -- unlocks at 34
		T.expect(Skills.validHotbar(c, 2, "firebolt")).toBe(false) -- other class
	end)

	T.it("passive totals from the level", function()
		local at50 = Skills.passiveTotals(character("Warrior", 50))
		T.expect(at50.pct.armor).toBe(25)
		T.expect(at50.pct.maxHp).toBe(12)
		T.expect(at50.hooks.riposte).toBe(4)
		T.expect(Skills.passiveTotals(character("Warrior", 47)).hooks.riposte).toBeNil()
		local at13 = Skills.passiveTotals(character("Warrior", 13))
		T.expect(at13).toEqual({ flat = {}, pct = {}, hooks = {} })
		local at100 = Skills.passiveTotals(character("Warrior", 100))
		T.expect(at100.pct.armor).toBe(25)
		T.expect(at100.pct.maxHp).toBe(20)
		T.expect(at100.hooks.riposte).toBe(12)
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
		T.expect(Skills.cost(firebolt, 1, 45, "Mage")).toBeNear(1.4 * Skills.cost(firebolt, 1, 20, "Mage"))
		T.expect(Skills.cost(firebolt, 1, 45, "Mage")).toBeNear(16.8)
		T.expect(Skills.cost(firebolt, 1, 100, "Mage")).toBeNear(30)
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
		for _, id in { "heal", "renew", "circleOfLight", "purify", "radiance" } do
			T.expect({ id = id, fields = Skills.healFields(skill(id)) }).toEqual({ id = id, fields = { "heal" } })
		end
		T.expect(Skills.healFields(skill("shieldOfFaith"))).toEqual({ "shield" })
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
					for _, field in { "heal", "shield" } do
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
			table.insert(cleaveLevels, Skills.rankLevel(skill("cleave"), r))
		end
		T.expect(cleaveLevels).toEqual({ 18, 22, 26, 30, 34, 38, 42, 46, 50, 54 })
		T.expect(Skills.rankLevel(skill("mightyStrike"), 2)).toBe(5)
		T.expect({ Skills.rankLevel(skill("meteorStorm"), 5), Skills.rankLevel(skill("meteorStorm"), 10) }).toEqual({
			84,
			95,
		})
		T.expect({ Skills.rankLevel(skill("evocation"), 5), Skills.rankLevel(skill("evocation"), 10) }).toEqual({
			78,
			95,
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
		local cleave = skill("cleave")
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
		T.expect(active[1]).toBe(bps[5].a)
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
	T.it("neutral on today's data", function()
		for id, def in SkillData.byId do
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

return nil
