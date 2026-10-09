--!strict
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
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

local function character(classId: string, level: number, points: number): any
	local c = AccountSchema.characterTemplate()
	c.class = classId :: any
	c.level = level
	c.skillPoints = points
	return c
end

T.describe("Data: Skills", function()
	T.it("14 skills per class, 56 in total", function()
		local total = 0
		for _, classId in Classes.order do
			local list = SkillData.byClass[classId]
			T.expect(#list).toBe(14)
			total += #list
		end
		T.expect(total).toBe(56)
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
			for _, requirement in skill.requires or {} do
				local other = SkillData.get(requirement.skill)
				check(other ~= nil, `requires unknown {requirement.skill}`)
				check((other :: any).class == skill.class, "requires another class")
				check((other :: any).unlock < skill.unlock, "requires a later skill")
				check(requirement.level <= (other :: any).maxLevel, "requirement above max level")
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

T.describe("Skills logic", function()
	T.it("level requirement = unlock + 3·(n−1)", function()
		local cleave = SkillData.get("cleave") :: any
		T.expect(Skills.levelRequirement(cleave, 1)).toBe(18)
		T.expect(Skills.levelRequirement(cleave, 10)).toBe(45)
	end)

	T.it("every skill reaches its max level by the max character level", function()
		for _, skill in SkillData.byId do
			local need = Skills.levelRequirement(skill, skill.maxLevel)
			if need > Config.MaxLevel then
				error(`{skill.id}: level {skill.maxLevel} needs {need}`)
			end
		end
		T.expect(Skills.levelRequirement(SkillData.get("meteorStorm") :: any, 10)).toBe(93)
	end)

	T.it("canLearn checks points, class, level and max level", function()
		local c = character("Warrior", 1, 1)
		T.expect((Skills.canLearn(c, "mightyStrike"))).toBe(true)
		T.expect(select(2, Skills.canLearn(c, "firebolt"))).toBe("wrongClass")
		T.expect(select(2, Skills.canLearn(c, "battleCry"))).toBe("level")
		T.expect(select(2, Skills.canLearn(c, "nope"))).toBe("unknown")
		c.skillPoints = 0
		T.expect(select(2, Skills.canLearn(c, "mightyStrike"))).toBe("noPoints")
		c.skillPoints = 5
		c.skills.mightyStrike = 1
		-- level 2 of an unlock-1 skill needs character level 4
		T.expect(select(2, Skills.canLearn(c, "mightyStrike"))).toBe("level")
		c.level = 100
		c.skills.mightyStrike = 10
		T.expect(select(2, Skills.canLearn(c, "mightyStrike"))).toBe("maxLevel")
	end)

	T.it("chained requirements", function()
		local c = character("Warrior", 100, 99)
		T.expect(select(2, Skills.canLearn(c, "cleave"))).toBe("requires")
		c.skills.bladeWhirl = 3
		T.expect((Skills.canLearn(c, "cleave"))).toBe(true)
		T.expect(select(2, Skills.canLearn(c, "earthquake"))).toBe("requires")
		c.skills.cleave = 3
		T.expect((Skills.canLearn(c, "earthquake"))).toBe(true)
		T.expect(select(2, Skills.canLearn(c, "titansWrath"))).toBe("requires")
	end)

	T.it("refundAll returns every point and clears the hotbar", function()
		local c = character("Mage", 50, 2)
		c.skills = { firebolt = 5, iceShard = 3 }
		c.hotbar = { ["1"] = "firebolt" }
		T.expect(Skills.refundAll(c)).toBe(8)
		T.expect(c.skillPoints).toBe(10)
		T.expect(next(c.skills)).toBeNil()
		T.expect(next(c.hotbar)).toBeNil()
	end)

	T.it("hotbar accepts only learned active skills of the class", function()
		local c = character("Hunter", 30, 0)
		c.skills = { aimedShot = 2, hawkEye = 1 }
		T.expect(Skills.validHotbar(c, 1, "aimedShot")).toBe(true)
		T.expect(Skills.validHotbar(c, 10, nil)).toBe(true)
		T.expect(Skills.validHotbar(c, 11, "aimedShot")).toBe(false)
		T.expect(Skills.validHotbar(c, 2, "hawkEye")).toBe(false) -- passive
		T.expect(Skills.validHotbar(c, 2, "doubleShot")).toBe(false) -- not learned
		T.expect(Skills.validHotbar(c, 2, "firebolt")).toBe(false) -- other class
	end)

	T.it("passive totals", function()
		local c = character("Warrior", 50, 0)
		c.skills = { steelSkin = 5, fortitude = 1, riposte = 3 }
		local totals = Skills.passiveTotals(c)
		T.expect(totals.pct.armor).toBe(25)
		T.expect(totals.pct.maxHp).toBe(4)
		T.expect(totals.hooks.riposte).toBe(8)
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

	T.it("each element has two own skills plus the two adaptive ones", function()
		local counts = { fire = 0, ice = 0, lightning = 0 }
		local adaptive = 0
		for _, skill in SkillData.byId do
			if skill.class == "Mage" then
				local element = Skills.requiredElement(skill)
				if element then
					counts[element] += 1
				end
				if skill.adaptive then
					adaptive += 1
				end
			end
		end
		T.expect(counts).toEqual({ fire = 2, ice = 2, lightning = 2 })
		T.expect(adaptive).toBe(2)
	end)
end)

return nil
