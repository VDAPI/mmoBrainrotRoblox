--!strict
local BuffCategories = require("../src/shared/Data/BuffCategories")
local EffectStack = require("../src/shared/Logic/EffectStack")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local Stats = require("../src/shared/Data/Stats")
local T = require("./Test")

type Entry = EffectStack.Entry

T.describe("EffectStack: damage reduction", function()
	T.it("multiplies categories and own entries with the 75 % cap", function()
		T.expect(EffectStack.reduction({
			{ category = "own", value = 60, at = 0 },
			{ category = "allyGuard", value = 15, at = 0 },
		})).toBeNear(66)
		local three: { Entry } = {
			{ category = "own", value = 60, at = 0 },
			{ category = "own", value = 30, at = 0 },
			{ category = "allyGuard", value = 15, at = 0 },
		}
		T.expect(EffectStack.reduction(three)).toBe(75)
		T.expect(EffectStack.combine({ 60, 30, 15 }, 100)).toBeNear(76.2)
	end)

	T.it("takes only the strongest entry of a category", function()
		local entries: { Entry } = {
			{ category = "own", value = 60, at = 0 },
			{ category = "allyGuard", value = 15, at = 1 },
			{ category = "allyGuard", value = 25, at = 0 },
		}
		T.expect(EffectStack.reduction(entries)).toBeNear(70)
	end)

	T.it("counts an entry without category as own; empty is 0; inputs are clamped", function()
		T.expect(EffectStack.reduction({ { value = 60, at = 0 }, { value = 30, at = 0 } })).toBeNear(72)
		T.expect(EffectStack.reduction({})).toBe(0)
		T.expect(EffectStack.reduction({ { category = "own", value = 100, at = 0 } })).toBe(75)
		T.expect(EffectStack.reduction({ { category = "own", value = -20, at = 0 } })).toBe(0)
	end)
end)

T.describe("EffectStack: strength and selection", function()
	T.it("compares the category's declared stats only", function()
		local a: Entry = { category = "allyVigor", stats = { maxHp = 15, armor = 10 }, pct = true, at = 0 }
		local b: Entry = { category = "allyVigor", stats = { maxHp = 20 }, pct = true, at = 1 }
		T.expect(EffectStack.select({ a, b })[1]).toBe(a)
		local c: Entry = { category = "allyVigor", stats = { maxHp = 10, physAtk = 100 }, pct = true, at = 0 }
		local d: Entry = { category = "allyVigor", stats = { maxHp = 12 }, pct = true, at = 0 }
		T.expect(EffectStack.strength(c)).toBe(10)
		T.expect(EffectStack.select({ c, d })[1]).toBe(d)
	end)

	T.it("breaks a tie by the newer entry, then by list order", function()
		local older: Entry = { category = "allyGuard", value = 15, at = 1 }
		local newer: Entry = { category = "allyGuard", value = 15, at = 2 }
		T.expect(EffectStack.select({ newer, older })[1]).toBe(newer)
		T.expect(EffectStack.select({ older, newer })[1]).toBe(newer)
		local same: Entry = { category = "allyGuard", value = 15, at = 1 }
		T.expect(EffectStack.select({ older, same })[1]).toBe(older)
	end)

	T.it("ranks value categories by value and keeps every own entry", function()
		local weak: Entry = { category = "enemySlow", value = 25, at = 5 }
		local strong: Entry = { category = "enemySlow", value = 40, at = 0 }
		local own1: Entry = { category = "own", value = 10, at = 0 }
		local own2: Entry = { value = 5, at = 0 }
		local chosen = EffectStack.select({ weak, own1, strong, own2 })
		T.expect(#chosen).toBe(3)
		T.expect(chosen[1]).toBe(own1)
		T.expect(chosen[2]).toBe(strong)
		T.expect(chosen[3]).toBe(own2)
		T.expect(EffectStack.isOwn("noSuchCategory")).toBe(true)
	end)
end)

T.describe("EffectStack: own and party copies", function()
	T.it("adds own buffs to the strongest party buff of each category", function()
		local flat, pct = EffectStack.stats({
			{ category = "own", stats = { physAtk = 28 }, pct = true, at = 0 },
			{ category = "allyAttack", stats = { physAtk = 3 }, pct = true, at = 0 },
			{ category = "allyAttack", stats = { physAtk = 2 }, pct = true, at = 1 },
		})
		T.expect(pct.physAtk).toBe(31)
		T.expect(next(flat)).toBeNil()
	end)

	T.it("keeps flat and pct apart", function()
		local flat, pct = EffectStack.stats({
			{ category = "own", stats = { atkSpeed = 20 }, at = 0 },
			{ category = "allyHaste", stats = { atkSpeed = 10 }, pct = true, at = 0 },
		})
		T.expect(flat.atkSpeed).toBe(20)
		T.expect(pct.atkSpeed).toBe(10)
	end)

	T.it("caps a category's share but never own entries", function()
		local flat = EffectStack.stats({
			{ category = "allyMove", stats = { moveSpeed = 40 }, at = 0 },
			{ category = "own", stats = { moveSpeed = 30 }, at = 0 },
			{ category = "allyCrit", stats = { critChance = 8 }, at = 0 },
		})
		T.expect(flat.moveSpeed).toBe(60)
		T.expect(flat.critChance).toBe(8)
	end)
end)

T.describe("EffectStack: statBuff merge", function()
	T.it("merges stats of the same key and keeps the later end", function()
		local cry = { stats = { physAtk = 28 }, pct = true, expiresAt = 20 }
		local stats, ends = EffectStack.merge(nil, cry, 0)
		T.expect(stats).toEqual({ physAtk = 28 })
		T.expect(ends).toBe(20)
		local armor = { stats = { armor = 12 }, pct = true, expiresAt = 20 }
		local merged, mergedEnd = EffectStack.merge({ stats = stats, pct = true, expiresAt = ends }, armor, 0)
		T.expect(merged).toEqual({ physAtk = 28, armor = 12 })
		T.expect(mergedEnd).toBe(20)
		local again, againEnd = EffectStack.merge(
			{ stats = merged, pct = true, expiresAt = 20 },
			{ stats = { physAtk = 30 }, pct = true, expiresAt = 15 },
			5
		)
		T.expect(again).toEqual({ physAtk = 30, armor = 12 })
		T.expect(againEnd).toBe(20)
		T.expect(merged).toEqual({ physAtk = 28, armor = 12 })
	end)

	T.it("replaces an expired one or one of another pct mode", function()
		local old = { stats = { armor = 12 }, pct = true, expiresAt = 4 }
		local new = { stats = { physAtk = 30 }, pct = true, expiresAt = 15 }
		local stats, ends = EffectStack.merge(old, new, 5)
		T.expect(stats).toEqual({ physAtk = 30 })
		T.expect(ends).toBe(15)
		local flatNew = { stats = { physAtk = 30 }, expiresAt = 15 }
		local other = EffectStack.merge({ stats = { armor = 12 }, pct = true, expiresAt = 20 }, flatNew, 5)
		T.expect(other).toEqual({ physAtk = 30 })
		T.expect(old.stats).toEqual({ armor = 12 })
		T.expect(new.stats).toEqual({ physAtk = 30 })
	end)
end)

T.describe("EffectStack: Effects attribute", function()
	T.it("sends one entry per kind with the latest end and strongest value", function()
		local raw = EffectStack.encode({
			{ kind = "slow", expiresAt = 10, value = 25 },
			{ kind = "slow", expiresAt = 14, value = 40 },
			{ kind = "slow", expiresAt = 12, value = 30 },
			{ kind = "statBuff", expiresAt = 20, value = 0 },
			{ kind = "shield", expiresAt = 9, value = 500 },
			{ kind = "bleed", expiresAt = 3, value = 10 },
		}, 5)
		T.expect(raw).toBe("shield:9;slow:14:40;statBuff:20")
		local decoded = EffectStack.decode(raw, 5)
		T.expect(decoded).toEqual({
			{ kind = "shield", left = 4 },
			{ kind = "slow", left = 9, value = 40 },
			{ kind = "statBuff", left = 15 },
		})
	end)

	T.it("reads the old format and skips expired entries and junk", function()
		T.expect(EffectStack.decode("slow:12.5", 10)).toEqual({ { kind = "slow", left = 2.5 } })
		T.expect(EffectStack.decode("x;;slow:abc;:1;stun:4;root:20:15", 10))
			.toEqual({ { kind = "root", left = 10, value = 15 } })
		T.expect(EffectStack.decode("stun:12;slow:20;slow:15:30", 10)).toEqual({
			{ kind = "slow", left = 10, value = 30 },
			{ kind = "stun", left = 2 },
		})
		T.expect(EffectStack.encode({}, 0)).toBeNil()
		T.expect(EffectStack.decode(nil, 0)).toEqual({})
	end)
end)

T.describe("EffectStack: categories with a skill / item split (S63)", function()
	local function e(category: string, value: number, item: boolean?): Entry
		return { category = category, value = value, at = 0, item = item }
	end

	T.it("adds the strongest skill and the strongest item, with caps", function()
		T.expect(EffectStack.value({ e("enemyArmor", 30), e("enemyArmor", 25, true) }, "enemyArmor")).toBe(50)
		T.expect(EffectStack.value({
			e("enemyArmor", 30),
			e("enemyArmor", 20),
			e("enemyArmor", 15, true),
		}, "enemyArmor")).toBe(45)
		T.expect(EffectStack.value({ e("enemyArmor", 25, true), e("enemyArmor", 10, true) }, "enemyArmor")).toBe(25)
		T.expect(EffectStack.value({ e("enemyArmor", 47, true) }, "enemyArmor")).toBe(40)
		T.expect(EffectStack.value({ e("enemyArmor", 30), e("enemyArmor", 40, true) }, "enemyArmor")).toBe(50)
		T.expect(EffectStack.value({ e("enemyDamageDown", 10), e("enemyDamageDown", 11.3, true) }, "enemyDamageDown"))
			.toBe(15)
		T.expect(EffectStack.value({ e("enemyDamageDown", 6, true) }, "enemyDamageDown")).toBe(6)
	end)

	T.it("takes the strongest entry of a category without a split", function()
		T.expect(
			EffectStack.value({ e("enemyAttackSlow", 20, true), e("enemyAttackSlow", 10, true) }, "enemyAttackSlow")
		)
			.toBe(20)
		T.expect(EffectStack.value({ e("enemyAttackSlow", 30, true) }, "enemyAttackSlow")).toBe(20)
		T.expect(EffectStack.value({ e("enemySlow", 40), e("enemySlow", 25, true) }, "enemySlow")).toBe(40)
		T.expect(EffectStack.value({ e("enemySlow", -5) }, "enemySlow")).toBe(0)
	end)

	T.it("keeps item effects apart from skill effects", function()
		local skill = { kind = "bleed", sourceKey = "p1", skillId = "cleave" }
		T.expect(EffectStack.sameKey(skill, "bleed", "p1", EffectStack.ITEM, nil)).toBe(false)
		T.expect(EffectStack.sameKey(skill, "bleed", "p1", "cleave", nil)).toBe(true)
		local item = { kind = "bleed", sourceKey = "p1", skillId = EffectStack.ITEM }
		T.expect(EffectStack.sameKey(item, "bleed", "p1", "item", nil)).toBe(true)
		T.expect(EffectStack.sameKey(item, "bleed", "p1", "cleave", nil)).toBe(false)
		T.expect(EffectStack.sameKey(item, "bleed", "p1", "item", "enemyArmor")).toBe(false)
	end)
end)

T.describe("EffectStack: stacks and publication (S63)", function()
	T.it("stacks without ticks share one end", function()
		local function spec(now: number): EffectStack.StackSpec
			return { unit = 5, maxStacks = 5, duration = 6, now = now, tickInterval = 1 }
		end
		local first = EffectStack.restack(nil, spec(0))
		T.expect(first.stacks).toBe(1)
		T.expect(first.value).toBe(5)
		T.expect(first.nextTick).toBeNil()
		local second = EffectStack.restack(first, spec(1.5))
		T.expect(second.stacks).toBe(2)
		T.expect(second.value).toBe(10)
		T.expect(second.expiresAt).toBe(7.5)
		local state = second
		for i = 1, 5 do
			state = EffectStack.restack(state, spec(1.5 + i))
		end
		T.expect(state.stacks).toBe(5)
		T.expect(state.value).toBe(25)
		local late = EffectStack.restack(state, spec(state.expiresAt + 1))
		T.expect(late.stacks).toBe(1)
	end)

	T.it("stacks with ticks keep the tick", function()
		local function spec(now: number, maxStacks: number?): EffectStack.StackSpec
			return { unit = 0, tickUnit = 100, maxStacks = maxStacks, duration = 4, now = now, tickInterval = 1 }
		end
		local first = EffectStack.restack(nil, spec(10, 3))
		T.expect(first.tickAmount).toBe(100)
		T.expect(first.nextTick).toBe(11)
		local second = EffectStack.restack(first, spec(11.5, 3))
		T.expect(second.stacks).toBe(2)
		T.expect(second.tickAmount).toBe(200)
		T.expect(second.nextTick).toBe(11)
		local fourth = EffectStack.restack(EffectStack.restack(second, spec(12, 3)), spec(12.5, 3))
		T.expect(fourth.stacks).toBe(3)
		T.expect(fourth.tickAmount).toBe(300)
		T.expect(first.stacks).toBe(1)
		T.expect(first.tickAmount).toBe(100)
		local single = EffectStack.restack(EffectStack.restack(nil, spec(10)), spec(11.5))
		T.expect(single.stacks).toBe(1)
		T.expect(single.nextTick).toBe(11) -- S73: a running effect keeps its tick
	end)

	T.it("a running ticking effect keeps nextTick", function()
		local old: EffectStack.Stack = { stacks = 1, value = 0, tickAmount = 10, expiresAt = 5, nextTick = 3 }
		local function spec(now: number, tickUnit: number?): EffectStack.StackSpec
			return { unit = 0, tickUnit = tickUnit, maxStacks = nil, duration = 4, now = now, tickInterval = 1 }
		end
		local refreshed = EffectStack.restack(old, spec(2.6, 10))
		T.expect(refreshed.nextTick).toBe(3)
		T.expect(refreshed.expiresAt).toBeNear(6.6)
		local expired = EffectStack.restack(old, spec(6, 10))
		T.expect(expired.nextTick).toBe(7)
		T.expect(EffectStack.restack(old, spec(2.6, nil)).nextTick).toBeNil()
	end)

	T.it("keepLonger never ends a running effect sooner", function()
		local old: EffectStack.Stack = { stacks = 1, value = 6, expiresAt = 3 }
		local function spec(now: number, duration: number, keep: boolean?): EffectStack.StackSpec
			return { unit = 6, duration = duration, now = now, tickInterval = 1, keepLonger = keep }
		end
		T.expect(EffectStack.restack(old, spec(0.2, 2, true)).expiresAt).toBe(3)
		T.expect(EffectStack.restack(old, spec(0.2, 2)).expiresAt).toBeNear(2.2)
		T.expect(EffectStack.restack(old, spec(2, 2, true)).expiresAt).toBe(4)
		T.expect(EffectStack.restack(old, spec(5, 2, true)).expiresAt).toBe(7)
	end)

	T.it("publishes a refresh at most once per interval", function()
		T.expect(EffectStack.publishDue(true, 0.5, 1, 1)).toBe(true)
		T.expect(EffectStack.publishDue(false, 0.5, 1, 1)).toBe(false)
		T.expect(EffectStack.publishDue(false, 0, 1, 1)).toBe(true)
		T.expect(EffectStack.publishDue(false, nil, 1, 1)).toBe(true)
	end)
end)

T.describe("Data: BuffCategories", function()
	T.it("declares the 13 categories with kinds, stats and caps", function()
		T.expect(#BuffCategories.list).toBe(13)
		local seen: { [string]: boolean } = {}
		for _, category in BuffCategories.list do
			T.expect(seen[category.id]).toBeNil()
			seen[category.id] = true
			if category.id ~= BuffCategories.OWN then
				T.expect(category.kind ~= nil).toBe(true)
				T.expect(category.side == "ally" or category.side == "enemy").toBe(true)
			end
			if category.kind == "statBuff" then
				T.expect(category.stats ~= nil).toBe(true)
				for _, stat in category.stats or {} do
					T.expect(Stats.get(stat) ~= nil).toBe(true)
				end
			end
		end
		T.expect(seen[BuffCategories.OWN]).toBe(true)
		T.expect(table.clone(BuffCategories.caps)).toEqual({
			damageReduction = 75,
			enemyMiss = 15,
			allyMove = 30,
			intercept = 30,
			interceptPerSecond = 25,
			enemyArmor = 50,
			enemyArmorItem = 40,
			enemyDamageDown = 15,
			enemyAttackSlow = 20,
		})
		T.expect((BuffCategories.get("enemyDamageDown") :: any).kind).toBe("weaken")
		T.expect((BuffCategories.get("enemyAttackSlow") :: any).kind).toBe("attackSlow")
		T.expect((BuffCategories.get("enemyArmor") :: any).split).toBe(true)
		T.expect((BuffCategories.get("enemyDamageDown") :: any).split).toBe(true)
		T.expect((BuffCategories.get("enemyAttackSlow") :: any).split).toBeNil()
	end)
end)

-- Kinds that a party / enemy effect must categorise.
local CATEGORISED = { statBuff = true, damageReduction = true, vulnerability = true, armorBreak = true, slow = true }

-- Category problems of a skill's effects and breakpoint effects (ROZWOJ 3.4, 7.1).
local function problems(skill: any): { string }
	local out: { string } = {}
	local seenPct: { [string]: boolean } = {}
	local function check(effect: any, side: string, where: string)
		local name = `{skill.id} {where} {effect.kind}`
		local id = effect.category
		local category = BuffCategories.get(id)
		if side == "self" and id ~= "own" then
			table.insert(out, `{name}: self effect without own`)
		end
		if id == "own" and side ~= "self" then
			table.insert(out, `{name}: own outside self`)
		end
		if id ~= nil and category == nil then
			table.insert(out, `{name}: unknown category {id}`)
		end
		if category and category.id ~= "own" then
			if category.side == "ally" and side ~= "allies" then
				table.insert(out, `{name}: ally category on {side}`)
			elseif category.side == "enemy" and side ~= "enemy" then
				table.insert(out, `{name}: enemy category on {side}`)
			end
			if category.kind ~= effect.kind then
				table.insert(out, `{name}: kind differs from {category.id}`)
			end
			if category.stats then
				for stat in effect.stats or {} do
					if not table.find(category.stats, stat) then
						table.insert(out, `{name}: stat {stat} outside {category.id}`)
					end
				end
			end
			if category.mode == "points" and effect.pct == true then
				table.insert(out, `{name}: pct in points category`)
			elseif category.mode == "pct" and effect.pct ~= true then
				table.insert(out, `{name}: no pct in pct category`)
			end
		end
		if (side == "allies" or side == "enemy") and CATEGORISED[effect.kind] and id == nil then
			table.insert(out, `{name}: missing category`)
		end
		if id then
			local key = `{effect.kind}/{id}`
			local pct = effect.pct == true
			if seenPct[key] ~= nil and seenPct[key] ~= pct then
				table.insert(out, `{name}: mixed pct in {key}`)
			end
			seenPct[key] = pct
		end
	end
	for _, effect in skill.effects or {} do
		check(effect, Skills.effectSide(skill, effect), "effects")
	end
	for _, level in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[level]
		for _, option in { "a", "b" } do
			local bp = pair and (pair :: any)[option]
			if bp then
				local where = `bp{level}{option}`
				if bp.effect then
					check(bp.effect, Skills.effectSide(skill, bp.effect), where)
				end
				if bp.selfEffect then
					check(bp.selfEffect, "self", where)
				end
				if bp.allyEffect then
					check(bp.allyEffect, "allies", where)
				end
				if bp.behindEffect then -- S73 (Party Bastion, S75)
					check(bp.behindEffect, "allies", where)
				end
			end
		end
	end
	return out
end

T.describe("Data: skill effect categories", function()
	T.it("tags every party effect and enemy debuff consistently", function()
		local all: { string } = {}
		for _, skill in SkillData.byId do
			for _, problem in problems(skill) do
				table.insert(all, problem)
			end
		end
		T.expect(all).toEqual({})
	end)

	T.it("uses the expected categories", function()
		local byId: any = SkillData.byId
		T.expect(byId.battleCry.effects[1].category).toBe("own")
		T.expect(byId.auraOfEndurance.effects[1].category).toBe("allyVigor")
		T.expect(byId.auraOfEndurance.breakpoints[10].a.allyEffect.category).toBe("allyVigor")
		T.expect(byId.circleOfLight.breakpoints[10].a.allyEffect.category).toBe("allyGuard")
		T.expect(byId.crushingBlow.effects[1].category).toBe("enemyArmor")
		T.expect(byId.huntersMark.effects[1].category).toBe("enemyWeak")
		T.expect(byId.earthquake.effects[1].category).toBe("enemySlow")
	end)

	T.it("catches an own copy and a party copy tagged alike", function()
		local selfTagged = {
			id = "fakeSelf",
			type = "buff",
			effects = {
				{ kind = "statBuff", duration = 10, stats = { physAtk = "a" }, pct = true, category = "allyAttack" },
			},
		}
		local flatParty = {
			id = "fakeParty",
			type = "groupBuff",
			effects = {
				{
					kind = "statBuff",
					duration = 10,
					stats = { physAtk = "a" },
					pct = false,
					target = "allies",
					category = "allyAttack",
				},
			},
		}
		T.expect(#problems(selfTagged) > 0).toBe(true)
		T.expect(#problems(flatParty) > 0).toBe(true)
	end)
end)

T.describe("EffectStack: accumulate (S65, ROZWOJ 7.2, 14.4)", function()
	T.it("counts the ticks a schedule still deals", function()
		T.expect(EffectStack.ticksBetween(1, 4, 1)).toBe(3)
		T.expect(EffectStack.ticksBetween(2, 4, 1)).toBe(2)
		T.expect(EffectStack.ticksBetween(4, 4, 1)).toBe(0)
		T.expect(EffectStack.ticksBetween(1, 2.5, 1)).toBe(2)
		T.expect(EffectStack.ticksBetween(5, 4, 1)).toBe(0)
	end)

	T.it("starts a new schedule", function()
		local tick, nextTick = EffectStack.accumulate(nil, { total = 100, duration = 4, now = 0, interval = 1 })
		T.expect(tick).toBeNear(100 / 3, 0.01)
		T.expect(nextTick).toBe(1)
	end)

	-- Ticks like StatusEffectService.tickEntity: the effect ends before a tick on its end, then one tick per call.
	type Dot = { tickAmount: number, nextTick: number, expiresAt: number }
	local function apply(dot: Dot?, total: number, duration: number, now: number, limit: number?): Dot
		local running = if dot and dot.expiresAt > now then dot else nil
		local tick, nextTick = EffectStack.accumulate(
			running,
			{ total = total, limit = limit, duration = duration, now = now, interval = 1 }
		)
		return { tickAmount = tick, nextTick = nextTick, expiresAt = now + duration }
	end
	local function run(dot: Dot, from: number, to: number): number
		local dealt = 0
		local t = from
		while t <= to + 1e-9 do
			if dot.expiresAt <= t then
				break
			end
			if t >= dot.nextTick - 1e-9 then
				dealt += dot.tickAmount
				dot.nextTick += 1
			end
			t += 0.5
		end
		return dealt
	end

	T.it("a refresh adds the unpaid rest and keeps nextTick", function()
		local dot = apply(nil, 100, 4, 0)
		local dealt = run(dot, 0, 1)
		dot = apply(dot, 100, 4, 1)
		T.expect(dot.nextTick).toBe(2)
		dealt += run(dot, 1.5, 10)
		T.expect(dealt).toBeNear(200, 0.01)
	end)

	T.it("the limit caps the pending sum", function()
		local dot: Dot? = nil
		for _ = 1, 4 do
			dot = apply(dot, 100, 4, 0, 3)
		end
		T.expect(run(dot :: Dot, 0, 10)).toBeNear(300, 0.01)
	end)

	T.it("a short burn refreshed before its tick", function()
		local dot = apply(nil, 30, 2, 0)
		dot = apply(dot, 30, 2, 0.5)
		T.expect(dot.nextTick).toBe(1)
		T.expect(run(dot, 0.5, 10)).toBeNear(60, 0.01)
	end)

	T.it("a due tick not dealt yet belongs to the rest", function()
		local dot = apply(nil, 90, 4, 0)
		-- at t = 1 the loop has not ticked yet: 3 ticks of 30 are unpaid
		dot = apply(dot, 90, 4, 1)
		T.expect(dot.nextTick).toBe(1)
		T.expect(run(dot, 1, 10)).toBeNear(180, 0.01)
	end)
end)

T.describe("Guardian reductions (S72, ROZWOJ 14.2)", function()
	local function own(values: { number }): { Entry }
		local out: { Entry } = {}
		for _, value in values do
			table.insert(out, { category = "own", value = value, at = 0 })
		end
		return out
	end

	T.it("every Guardian entry together stays under the 75 % cap", function()
		-- Last Bastion 68 (60 + 5B), Shield Wall 30, Sacrifice 15, lastStand 45, Front Line 3.5 (one enemy).
		T.expect(EffectStack.reduction(own({ 68, 30, 15, 45, 3.5 }))).toBeNear(75, 1e-9)
		T.expect(EffectStack.reduction(own({ 68, 30, 15, 30, 15, 3.5 }))).toBeNear(75, 1e-9)
		T.expect(EffectStack.combine({ 68, 30, 15, 45, 3.5 }, 100)).toBeNear(89.89, 0.01)
	end)

	T.it("below the cap the entries multiply", function()
		T.expect(EffectStack.reduction(own({ 60, 17.5 }))).toBeNear(67, 1e-9)
	end)
end)

T.describe("EffectStack: stacks in the attribute (S76)", function()
	T.it("encodes stacks above 1 and still reads the old format", function()
		local text = EffectStack.encode({ { kind = "poison", expiresAt = 12.5, stacks = 3 } }, 10)
		T.expect(text).toBe("poison:12.5::3")
		local shown = EffectStack.decode(text, 10)
		T.expect(shown[1].stacks).toBe(3)
		T.expect(shown[1].value).toBeNil()
		local old = EffectStack.decode("slow:12.5:30", 10)
		T.expect(old[1].value).toBe(30)
		T.expect(old[1].stacks).toBeNil()
	end)

	T.it("a moved poison keeps the larger stacks and the later end", function()
		local fresh = EffectStack.restack(
			nil,
			{ unit = 2, tickUnit = 5, maxStacks = 3, duration = 4, now = 0, tickInterval = 1, stacks = 3 }
		)
		T.expect(fresh.stacks).toBe(3)
		T.expect(fresh.tickAmount).toBe(15)
		local running = { stacks = 1, value = 2, tickAmount = 5, expiresAt = 8, nextTick = 1 }
		local merged = EffectStack.restack(
			running,
			{ unit = 2, tickUnit = 5, maxStacks = 2, duration = 4, now = 0, tickInterval = 1, stacks = 2 }
		)
		T.expect(merged.stacks).toBe(2)
		T.expect(merged.expiresAt).toBe(8)
	end)
end)
