-- Diagnostic skill engine (not game code): expected-value, time-stepped fight with REAL skills from
-- Data/Skills + Logic/Skills (ranks, breakpoints, passives), the player from tests/Balance gear + StatCalc,
-- monsters from Logic/MonsterStats / FightSim. Mirrors the server rules read in src/server/Skills/* and
-- Services/{CombatService,SkillService,StatusEffectService}:
--   * basic attacks keep running while skills are cast (SkillService never touches CombatService.nextAttack)
--   * GCD 0.5 s, per-skill cooldowns, flat costs from the class resource pool, regen from StatCalc
--   * skill hit = attack x pct x (1 - Damage.reduction(def, L)) x expected crit x elemental/holy passive x vuln
--   * bleed / poison / burn ticks bypass armour (StatusEffectService -> Monster:TakeDamage)
--   * breakpoints via Logic/Skills.effective (splash, pierce, lingering, echo, split, execute, nextShot, ...)
-- Not modelled: stuns / slows / freezes / taunt (no attack-timer pause), movement, hit-delay of motions,
-- projectile travel, armorPen (FightSim ignores it too), camouflage threat drop, mana shield.

local B = require("../tests/Balance")
local Classes = require("../src/shared/Data/Classes")
local Damage = require("../src/shared/Logic/Damage")
local FightSim = require("../src/shared/Logic/FightSim")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")

local E = {}

E.DT = 0.05
E.GCD = SkillData.GCD
-- DIAG (lowca review): skill hits and bleed / poison ticks use attack x weapon speed (basic attacks unchanged)
E.SPEED_NORM = false
E.SPEED_REF = 1 -- Combat.skillSpeedRef (global G); wojownik.md measured with 0.8 (two-handed axe unchanged)

-- Gear source of tests/Balance (expected bonuses), cached.
local gearCache = {}
function E.gear(classId, L, opts)
	local key = classId .. ":" .. L .. ":" .. tostring(opts and opts.rarity or 1) .. ":" .. tostring(opts and opts.weapon) .. ":" .. tostring(opts and opts.offhand)
	if gearCache[key] then
		return gearCache[key]
	end
	local items = B.gear(classId, L, opts)
	local flat, pct, hooks, weapon = {}, {}, {}, nil
	for _, item in items do
		local s = ItemRoll.itemStats(item)
		for id, v in s.flat do
			flat[id] = (flat[id] or 0) + v
		end
		for id, v in s.pct do
			pct[id] = (pct[id] or 0) + v
		end
		for id, v in s.hooks do
			hooks[id] = (hooks[id] or 0) + v
		end
		if s.weapon then
			weapon = s.weapon
		end
	end
	local g = { flat = flat, pct = pct, hooks = hooks, weapon = weapon }
	gearCache[key] = g
	return g
end

-- Player with gear + learned passives (+ an optional extra source: buffs, blessings).
function E.player(classId, L, ranks, extra, gearOpts)
	local g = E.gear(classId, L, gearOpts)
	local class = Classes.get(classId)
	local pas = Skills.passiveTotals({ skills = ranks or {} } :: any)
	local sources = {
		{ key = "gear", flat = g.flat, pct = g.pct },
		{ key = "passive", flat = pas.flat, pct = pas.pct },
	}
	if extra then
		for _, s in (if extra.key then { extra } else extra) do
			table.insert(sources, s)
		end
	end
	local w = g.weapon
	local r = StatCalc.compute({
		level = L,
		stats = B.statsFor(classId, L),
		sources = sources,
		weapon = { dmg = w.dmg, mdmg = w.mdmg, speed = w.speed, ranged = w.ranged },
	})
	local hooks = table.clone(g.hooks)
	for id, v in pas.hooks do
		hooks[id] = (hooks[id] or 0) + v
	end
	return {
		classId = classId,
		level = L,
		values = r.values,
		primary = r.primary,
		hooks = hooks,
		magic = class.basicAttack.kind == "magic",
		weaponSpeed = w.speed,
	}
end

-- Highest rank the character level allows (Logic/Skills.levelRequirement), ignoring points.
function E.rankCap(skill, L)
	if L < skill.unlock then
		return 0
	end
	local r = 0
	for n = 1, skill.maxLevel do
		if Skills.levelRequirement(skill, n) <= L then
			r = n
		end
	end
	return r
end

-- Greedy build: one point per level from 2 (Data/Progression), spent on the first plan entry that
-- Logic/Skills.canLearn accepts. Returns ranks and unspent points.
function E.build(classId, L, plan)
	local character = { class = classId, level = 1, skills = {}, skillPoints = 0 }
	for lvl = 2, L do
		character.level = lvl
		character.skillPoints += 1
		local progress = true
		while character.skillPoints > 0 and progress do
			progress = false
			for _, entry in plan do
				local id, target = entry[1], entry[2]
				local current = character.skills[id] or 0
				if current < target and Skills.canLearn(character :: any, id) then
					character.skills[id] = current + 1
					character.skillPoints -= 1
					progress = true
					break
				end
			end
		end
	end
	return character.skills, character.skillPoints
end

-- Buffs that change StatCalc values, as extra sources.
local function buffSource(state)
	local flat, pct = {}, {}
	local any = false
	for id, b in state.buffs do
		if state.t < b.untilT then
			any = true
			for stat, v in b.flat or {} do
				flat[stat] = (flat[stat] or 0) + v
			end
			for stat, v in b.pct or {} do
				pct[stat] = (pct[stat] or 0) + v
			end
		end
	end
	if not any then
		return nil
	end
	return { key = "buffs", flat = flat, pct = pct }
end

local function currentPlayer(state)
	local key = {}
	for id, b in state.buffs do
		if state.t < b.untilT then
			table.insert(key, id)
		end
	end
	table.sort(key)
	local k = table.concat(key, ",")
	local p = state.cache[k]
	if not p then
		p = E.player(state.classId, state.L, state.ranks, buffSource(state), state.gearOpts)
		state.cache[k] = p
	end
	return p
end

local function aliveTargets(state)
	local out = {}
	for _, tg in state.targets do
		if tg.hp > 0 then
			table.insert(out, tg)
		end
	end
	return out
end

local function schedule(state, at, fn)
	table.insert(state.events, { t = at, fn = fn })
end

local function healSelf(state, amount, source)
	if amount <= 0 then
		return
	end
	local p = currentPlayer(state)
	local missing = state.lost
	local healed = math.min(missing, amount)
	state.lost -= healed
	state.healed += healed
	state.healBy[source] = (state.healBy[source] or 0) + amount
end

-- One expected hit. o: magic, elemMul, consume (default true), plain, skill, forceCrit, primary
local function hit(state, tg, pct, o)
	if tg.hp <= 0 then
		return 0
	end
	local p = currentPlayer(state)
	local v = p.values
	local magic = o.magic
	local attack = if magic then v.magAtk else v.physAtk
	if E.SPEED_NORM and o.skill then
		attack *= (p.weaponSpeed or 1) / E.SPEED_REF
	end
	local def
	if magic then
		def = tg.m.mres
	else
		local ab = if state.t < tg.abUntil then tg.ab else 0
		def = tg.m.armor * (1 - math.clamp(ab, 0, 90) / 100)
	end
	local red = Damage.reduction(def, p.level)
	local extra = o.elemMul or 1
	local forceCrit = o.forceCrit
	if o.consume ~= false then
		if state.guaranteedCrit and state.t < state.guaranteedCrit then
			forceCrit = true
			state.guaranteedCrit = nil
		end
		if state.nextShot and state.t < state.nextShot.untilT then
			extra *= 1 + state.nextShot.bonus / 100
			state.nextShot = nil
		end
	end
	if state.t < tg.vulnUntil then
		extra *= 1 + tg.vuln / 100
	end
	local critMul = math.max(1, v.critDmg / 100)
	local cf = if forceCrit then critMul else 1 + math.min(v.critChance, 100) / 100 * (critMul - 1)
	local amount = attack * pct / 100 * (1 - red) * cf * extra
	tg.hp -= amount
	state.dealt += amount
	local bucket = o.skill or "basic"
	state.by[bucket] = (state.by[bucket] or 0) + amount
	-- lifesteal (Damage.computeDamage, capped 15 %)
	local ls = math.clamp(v.lifesteal or 0, 0, 15)
	if ls > 0 then
		healSelf(state, amount * ls / 100, "lifesteal")
	end
	return amount
end

-- Damage over time: total `total` over `duration` s, ticks every second, bypasses armour.
local function dot(state, tg, total, duration, skill, stacksKey, maxStacks)
	local ticks = math.max(1, math.floor(duration))
	local stacks = 1
	local gen = 0
	if stacksKey then
		local cur = tg.dots[stacksKey]
		if maxStacks and maxStacks > 1 and cur and cur.untilT > state.t then
			stacks = math.min(maxStacks, cur.stacks + 1)
		end
		gen = (cur and cur.gen or 0) + 1
		tg.dots[stacksKey] = { untilT = state.t + duration, stacks = stacks, gen = gen }
		state.maxStacks[stacksKey] = math.max(state.maxStacks[stacksKey] or 0, stacks)
	end
	local per = total / math.max(1, duration) * stacks
	for i = 1, ticks do
		schedule(state, state.t + i, function()
			-- re-applying the same effect replaces it (StatusEffectService.Apply): older ticks stop
			if stacksKey and tg.dots[stacksKey].gen ~= gen then
				return
			end
			if tg.hp > 0 then
				tg.hp -= per
				state.dealt += per
				state.by[skill] = (state.by[skill] or 0) + per
			end
		end)
	end
end

local function others(list, tg)
	local out = {}
	for _, x in list do
		if x ~= tg then
			table.insert(out, x)
		end
	end
	return out
end

-- Expected fraction of the time a target is below `pct` % HP (dummies: execute share).
local function belowFraction(state, tg, pct)
	if tg.dummy then
		return pct / 100
	end
	return if tg.hp / tg.maxHp * 100 < pct then 1 else 0
end

-- The cast of `id` at `rank` (handlers of src/server/Skills/Types/*).
local function cast(state, id, rank)
	local base = SkillData.get(id)
	local def, bp = Skills.effective(base, rank)
	local function val(f)
		return Skills.valueAt(def, f, rank)
	end
	local p = currentPlayer(state)
	local hooks = p.hooks
	local magic = def.damageKind == "magic"
	local element = if def.adaptive then state.weaponElement else def.element
	local elemMul = 1
	if element then
		elemMul += (hooks.elementDamage or 0) / 100
	end
	if def.holy then
		elemMul += (hooks.holyDamage or 0) / 100
	end
	local alive = aliveTargets(state)
	local focus = alive[1]
	local t0 = state.t
	local healBonus = (hooks.healBonus or 0) / 100

	-- ctx.damage + onHit (Context.luau)
	local function dmg(tg, pct, o)
		o = o or {}
		local opts = {
			magic = magic,
			elemMul = elemMul,
			consume = o.consume,
			skill = id,
		}
		local amount
		if bp.execute and not o.plain then
			-- S28 execute: guaranteed crit below the threshold (expected share of hits)
			local f = belowFraction(state, tg, bp.execute)
			amount = hit(state, tg, pct * (1 - f), opts)
			if f > 0 then
				opts.consume = false
				opts.forceCrit = true
				amount += hit(state, tg, pct * f, opts)
			end
		else
			amount = hit(state, tg, pct, opts)
		end
		if element and def.adaptive and not o.noAdaptive and amount > 0 then
			if element == "fire" then
				dot(state, tg, amount * 0.3, 4, id .. ":burn")
			elseif element == "lightning" then
				local near = others(aliveTargets(state), tg)[1]
				if near then
					dmg(near, pct * 0.4, { noAdaptive = true, consume = false })
				end
			end
		end
		if not o.plain and amount > 0 then
			if bp.lifesteal then
				healSelf(state, amount * bp.lifesteal / 100, id)
			end
			if o.primary and bp.splash then
				for _, other in others(aliveTargets(state), tg) do
					dmg(other, pct * bp.splash.pct / 100, { plain = true, consume = false })
				end
			end
		end
		return amount
	end

	local function applyEnemyEffects(tg, extraEffect)
		local effects = table.clone(def.effects or {})
		for _, effect in effects do
			local side = effect.target or (if def.type == "buff" or def.type == "groupBuff" then "self" else "enemy")
			if side == "enemy" then
				local duration = Skills.scaled(def, effect.duration, rank)
				local value = if type(effect.value) == "string"
					then val(effect.value)
					elseif type(effect.value) == "number" then effect.value
					else 0
				if effect.kind == "bleed" or effect.kind == "poison" then
					local attack = if magic then p.values.magAtk else p.values.physAtk
					if E.SPEED_NORM then
						attack *= (p.weaponSpeed or 1) / E.SPEED_REF
					end
					local dotMul = if effect.kind == "poison" then 1 + (hooks.poisonDamage or 0) / 100 else 1
					dot(state, tg, attack * value / 100 * dotMul, duration, id .. ":" .. effect.kind, id .. ":" .. effect.kind, if effect.kind == "bleed" then bp.bleedStacks elseif effect.kind == "poison" then (bp.poisonStacks or def.poisonStacks) else nil)
				elseif effect.kind == "armorBreak" then
					tg.ab = value
					tg.abUntil = state.t + duration
				elseif effect.kind == "vulnerability" then
					tg.vuln = math.max(if state.t < tg.vulnUntil then tg.vuln else 0, value)
					tg.vulnUntil = state.t + duration
				end
			end
		end
		if bp.effect and bp.effect.kind == "vulnerability" then
			tg.vuln = math.max(if state.t < tg.vulnUntil then tg.vuln else 0, bp.effect.value)
			tg.vulnUntil = state.t + Skills.scaled(def, bp.effect.duration, rank)
		end
	end

	local function lingering(pct, list)
		local spec = bp.lingering or def.lingering
		if not spec then
			return
		end
		for s = 1, math.floor(spec.duration) do
			schedule(state, state.t + s, function()
				for _, tg in aliveTargets(state) do
					if table.find(list, tg) then
						dmg(tg, pct * spec.pct / 100, { plain = true, consume = false })
					end
				end
			end)
		end
	end

	local typ = def.type
	if typ == "target" or typ == "charge" then
		if not focus then
			return false
		end
		local amount = dmg(focus, val("dmg"), { primary = true })
		applyEnemyEffects(focus)
		if id == "holyStrike" and amount > 0 and (hooks.holyStrikeHeal or 0) > 0 then
			healSelf(state, amount * hooks.holyStrikeHeal / 100 * (1 + healBonus), "holyStrikeHeal")
		end
	elseif typ == "projectile" then
		if not focus then
			return false
		end
		local hits = def.hits or 1
		local interval = def.interval or 0.15
		for shot = 1, hits do
			local function fire()
				if focus.hp <= 0 then
					return
				end
				local pct = val("dmg")
				dmg(focus, pct, { consume = shot == 1, primary = shot == 1 })
				applyEnemyEffects(focus)
				if shot == 1 and bp.pierce then
					local nxt = others(aliveTargets(state), focus)[1]
					if nxt then
						dmg(nxt, pct * bp.pierce / 100, { consume = false })
					end
				end
				if def.values.splash and def.radius then
					for _, other in others(aliveTargets(state), focus) do
						dmg(other, val("splash"), {})
					end
				end
			end
			if shot == 1 then
				fire()
			else
				schedule(state, t0 + (shot - 1) * interval, fire)
			end
		end
	elseif typ == "cone" then
		if #alive == 0 then
			return false
		end
		if def.hits then
			for i = 1, def.hits do
				local tg = alive[(i - 1) % #alive + 1]
				schedule(state, t0 + i * 0.06, function()
					if tg.hp > 0 then
						dmg(tg, val("dmg"), { consume = i == 1 })
					end
				end)
			end
		else
			for _, tg in alive do
				dmg(tg, val("dmg"), {})
				applyEnemyEffects(tg)
			end
		end
	elseif typ == "circleSelf" or typ == "circleTarget" then
		local hasDamage = def.values.dmg ~= nil
		if not hasDamage then
			return true
		end
		if typ == "circleTarget" and not focus then
			return false
		end
		local hits = def.hits or 1
		local interval = def.interval or (if typ == "circleSelf" then 0.4 else 0.5)
		local delay = if typ == "circleTarget" then (def.delay or 0) else 0
		local storm = typ == "circleTarget" and hits > 1 and (def.delay or 0) > 0
		local radius = def.radius or 8
		local impactRadius = if storm then math.max(4, radius / 3) else radius
		-- storm impacts: distance uniform in [0, radius - impactRadius] from the aim point; enemies at the point
		local stormP = if storm then math.min(1, (impactRadius + 1.5) / math.max(0.01, radius - impactRadius)) else 1
		state.stormP = stormP
		for wave = 1, hits do
			schedule(state, t0 + delay + (wave - 1) * interval, function()
				local list = aliveTargets(state)
				if def.randomTarget then
					-- one random enemy per wave: expected share on each
					for _, tg in list do
						dmg(tg, val("dmg") / #list, { consume = wave == 1 })
					end
					return
				end
				for _, tg in list do
					dmg(tg, val("dmg") * stormP, { consume = wave == 1 })
					if wave == 1 then
						applyEnemyEffects(tg)
					end
				end
				if wave == 1 then
					if id == "radiance" then
						local amount = p.values.magAtk * val("dmg") / 100 * val("heal") / 100
						healSelf(state, amount * (1 + healBonus), "radiance")
					end
					lingering(val("dmg"), list)
					if bp.split and #list > 1 then
						-- small blasts 7 studs around the point: assume each hits one clustered enemy half the time
						for _ = 1, bp.split.count do
							local tg = list[math.random(1, #list)]
							dmg(tg, val("dmg") * bp.split.pct / 100 * 0.5, { plain = true, consume = false })
						end
					end
				end
			end)
		end
		if bp.echo then
			schedule(state, t0 + delay + (hits - 1) * interval + bp.echo.delay, function()
				for _, tg in aliveTargets(state) do
					dmg(tg, val("dmg") * bp.echo.pct / 100, { consume = false })
				end
			end)
		end
	elseif typ == "line" then
		for _, tg in alive do
			dmg(tg, val("dmg"), {})
			applyEnemyEffects(tg)
		end
	elseif typ == "chain" then
		if not focus then
			return false
		end
		local jumps = math.floor(val("jumps") + 0.5)
		for j = 1, math.min(jumps, #alive) do
			dmg(alive[j], val("dmg") * (1 - 0.1 * (j - 1)), { consume = j == 1, primary = j == 1 })
		end
	elseif typ == "companion" then
		local duration = Skills.scaled(def, def.duration, rank)
		local interval = def.interval or 2
		for k = 1, math.floor(duration / interval) do
			schedule(state, t0 + k * interval, function()
				local a = aliveTargets(state)[1]
				if a then
					dmg(a, val("dmg"), { consume = false, primary = true })
				end
			end)
		end
	elseif typ == "debuff" then
		if not focus then
			return false
		end
		applyEnemyEffects(focus)
	elseif typ == "buff" then
		local b = { untilT = t0 + Skills.scaled(def, def.duration, rank), flat = {}, pct = {} }
		for _, effect in def.effects or {} do
			if effect.kind == "statBuff" then
				local target = if effect.pct then b.pct else b.flat
				for stat, field in effect.stats or {} do
					target[stat] = (target[stat] or 0) + val(field)
				end
				b.untilT = t0 + Skills.scaled(def, effect.duration, rank)
			elseif effect.kind == "guaranteedCrit" then
				state.guaranteedCrit = t0 + Skills.scaled(def, effect.duration, rank)
			end
		end
		if bp.selfEffect and bp.selfEffect.kind == "statBuff" then
			local target = if bp.selfEffect.pct then b.pct else b.flat
			for stat, field in bp.selfEffect.stats or {} do
				target[stat] = (target[stat] or 0) + val(field)
			end
		end
		state.buffs[id] = b
	elseif typ == "blink" then
		for _, effect in def.effects or {} do
			if effect.kind == "nextShot" then
				state.nextShot = { bonus = val(effect.value), untilT = t0 + Skills.scaled(def, effect.duration, rank) }
			end
		end
	elseif typ == "heal" then
		local amount = p.values.magAtk * val("heal") / 100 * (1 + healBonus)
		healSelf(state, amount, id)
	elseif typ == "hot" then
		local duration = Skills.scaled(def, def.duration, rank)
		local total = p.values.magAtk * val("heal") / 100 * (1 + healBonus)
		for s = 1, math.floor(duration) do
			schedule(state, t0 + s, function()
				healSelf(state, total / math.max(1, duration), id)
			end)
		end
	elseif typ == "groupHeal" then
		healSelf(state, p.values.magAtk * val("heal") / 100 * (1 + healBonus), id)
	else
		return false
	end
	return true
end

-- Static potency of a damage skill (sort key for the rotation): total pct on `n` clustered targets.
function E.potency(id, rank, n)
	local base = SkillData.get(id)
	local def, bp = Skills.effective(base, rank)
	local dmg = def.values.dmg and Skills.valueAt(def, "dmg", rank) or 0
	local hits = def.hits or 1
	local typ = def.type
	local aoe = typ == "cone" or typ == "circleSelf" or typ == "circleTarget" or typ == "line"
	local targets = if aoe and not def.randomTarget and not (typ == "cone" and def.hits) then n else 1
	local total = dmg * hits * targets
	if typ == "chain" then
		local jumps = math.floor(Skills.valueAt(def, "jumps", rank) + 0.5)
		total = 0
		for j = 1, math.min(jumps, n) do
			total += dmg * (1 - 0.1 * (j - 1))
		end
	end
	if bp.lingering then
		total += dmg * bp.lingering.pct / 100 * bp.lingering.duration * targets
	end
	if bp.echo then
		total += dmg * bp.echo.pct / 100 * targets
	end
	if bp.splash then
		total += dmg * bp.splash.pct / 100 * (n - 1)
	end
	if bp.pierce and n > 1 then
		total += dmg * bp.pierce / 100
	end
	if def.values.splash then
		total += Skills.valueAt(def, "splash", rank) * (n - 1)
	end
	for _, effect in def.effects or {} do
		if effect.kind == "bleed" or effect.kind == "poison" then
			total += Skills.valueAt(def, effect.value, rank) * targets * 1.5 -- unreduced
		end
	end
	return total
end

E.BUFFS = { battleCry = true, bloodlust = true, huntersMark = true, disengage = true, camouflage = true }
E.HEALS = { heal = true, renew = true, circleOfLight = true, purify = true }
-- Defensive / utility skills left out of damage rotations.
E.SKIP = {
	taunt = true,
	lastBastion = true,
	frostTrap = true,
	blink = true,
	manaShield = true,
	evocation = true,
	prayer = true,
	resurrection = true,
	divineIntervention = true,
	auraOfEndurance = true,
	shieldOfFaith = true,
	iceShard = false,
}

-- Runs a fight. opts:
--   classId, L, ranks, targets = { MonsterStats } (dummy = huge HP when opts.dummy), seconds (max),
--   skills = true/false, weaponElement, healAt (self-heal threshold of HP lost, Cleric), regen (true: monsters hit)
--   startPool = fraction of the resource pool at the start (default 1)
function E.fight(opts)
	local state = {
		classId = opts.classId,
		L = opts.L,
		ranks = opts.ranks or {},
		gearOpts = opts.gearOpts,
		buffs = {},
		cache = {},
		t = 0,
		events = {},
		targets = {},
		dealt = 0,
		by = {},
		lost = 0,
		maxLost = 0,
		healed = 0,
		healBy = {},
		casts = {},
		maxStacks = {},
		weaponElement = opts.weaponElement,
	}
	for _, m in opts.targets do
		table.insert(state.targets, {
			m = m,
			hp = if opts.dummy then 1e12 else m.maxHp,
			maxHp = if opts.dummy then 1e12 else m.maxHp,
			dummy = opts.dummy,
			ab = 0,
			abUntil = -1,
			vuln = 0,
			vulnUntil = -1,
			dots = {},
			nextSwing = 0,
		})
	end
	local p0 = currentPlayer(state)
	local resource = Classes.get(opts.classId).resource
	local poolMax = if resource == "mana" then p0.values.maxMana else p0.values.maxEnergy
	local pool = poolMax * (opts.startPool or 1)
	local spent = 0
	local cds = {}
	for id, left in opts.cds or {} do
		cds[id] = left
	end
	local gcd = 0
	local nextBasic = 0
	local seconds = opts.seconds or 120
	-- rotation list: learned actives with a handler, ordered by potency
	local list = {}
	if opts.skills ~= false then
		for id, rank in state.ranks do
			local s = SkillData.get(id)
			if rank > 0 and s.type ~= "passive" and (opts.use == nil or opts.use[id]) then
				if
					(opts.exclude and opts.exclude[id])
					or E.SKIP[id]
					or not Skills.elementAllowed(s, opts.weaponElement)
				then
					continue
				end
				table.insert(list, { id = id, rank = rank, pot = E.potency(id, rank, #opts.targets) })
			end
		end
	end
	table.sort(list, function(a, b)
		local ba = if E.BUFFS[a.id] then 1 else 0
		local bb = if E.BUFFS[b.id] then 1 else 0
		if ba ~= bb then
			return ba > bb
		end
		return a.pot > b.pot
	end)
	local hpMax = p0.values.maxHp
	local endT = seconds
	local done = false
	while state.t < seconds do
		local p = currentPlayer(state)
		-- events due
		table.sort(state.events, function(a, b)
			return a.t < b.t
		end)
		while #state.events > 0 and state.events[1].t <= state.t + 1e-9 do
			local ev = table.remove(state.events, 1)
			ev.fn()
		end
		-- monsters swing (expected), first swing at t = 0
		if opts.monstersHit then
			for _, tg in state.targets do
				if tg.hp > 0 and state.t >= tg.nextSwing then
					state.lost += FightSim.hit(tg.m, p)
					tg.nextSwing += tg.m.attackInterval
				end
			end
			state.maxLost = math.max(state.maxLost, state.lost)
		end
		-- player basic attack
		local alive = aliveTargets(state)
		if #alive == 0 then
			endT = state.t
			done = true
			break
		end
		if state.t >= nextBasic then
			local double = 1 + (p.hooks.doubleAttack or 0) / 100
			hit(state, alive[1], 100 * double, { magic = p.magic })
			nextBasic += 1 / math.max(0.2, p.values.atkSpeed)
		end
		-- skills
		if state.t >= gcd and #list > 0 then
			local chosen = nil
			local needHeal = opts.healAt and state.lost / hpMax >= opts.healAt
			-- DIAG (lowca): keep energy for a stronger skill (2x the potency per energy) that is ready within 3 s
			local reserve = 0
			for _, s in list do
				local skill = SkillData.get(s.id)
				local def = Skills.effective(skill, s.rank)
				local cost = Skills.scaled(def, def.cost, s.rank) * (opts.costMul or 1)
				local ready = (cds[s.id] or 0) <= state.t and cost <= pool
				if opts.reserve and not ready and not E.BUFFS[s.id] and (cds[s.id] or 0) <= state.t + 3 then
					reserve = math.max(reserve, cost)
					s.reservePot = s.pot / math.max(1, cost)
				else
					s.reservePot = nil
				end
				if ready and opts.reserve and reserve > 0 and not E.BUFFS[s.id] and pool - cost < reserve then
					local best = 0
					for _, o in list do
						if o.reservePot then
							best = math.max(best, o.reservePot)
						end
					end
					if s.pot / math.max(1, cost) * 2 < best then
						continue
					end
				end
				if ready then
					if E.HEALS[s.id] then
						if needHeal then
							chosen = s
							break
						end
					elseif s.id == "huntersMark" then
						if alive[1].vulnUntil <= state.t then
							chosen = s
							break
						end
					elseif chosen == nil then
						chosen = s
						if not needHeal then
							break
						end
					end
				end
			end
			if chosen then
				local skill = SkillData.get(chosen.id)
				local def = Skills.effective(skill, chosen.rank)
				local cost = Skills.scaled(def, def.cost, chosen.rank) * (opts.costMul or 1)
				if cast(state, chosen.id, chosen.rank) then
					if def.castTime then
						nextBasic = math.max(nextBasic, state.t + def.castTime)
					end
					pool -= cost
					spent += cost
					cds[chosen.id] = state.t + Skills.scaled(def, def.cooldown, chosen.rank)
					gcd = state.t + E.GCD + (def.castTime or 0)
					state.casts[chosen.id] = (state.casts[chosen.id] or 0) + 1
				end
			end
		end
		-- regen
		local regen = if resource == "mana" then p.values.manaRegen else p.values.energyRegen
		pool = math.min(poolMax, pool + regen * E.DT)
		if opts.monstersHit then
			state.lost = math.max(0, state.lost - (p.values.hpRegenCombat or 0) * E.DT)
		end
		state.t += E.DT
	end
	if not done then
		endT = seconds
	end
	local cdsOut = {}
	for id, readyAt in cds do
		cdsOut[id] = math.max(0, readyAt - endT)
	end
	return {
		cds = cdsOut,
		seconds = endT,
		dealt = state.dealt,
		dps = state.dealt / math.max(E.DT, endT),
		by = state.by,
		casts = state.casts,
		hpLost = state.maxLost / hpMax,
		endLost = state.lost / hpMax,
		healed = state.healed,
		healBy = state.healBy,
		spent = spent,
		poolMax = poolMax,
		poolEnd = pool,
		maxStacks = state.maxStacks,
		killed = done,
		p = p0,
	}
end

return E
