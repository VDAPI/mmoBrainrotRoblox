--!strict
-- S134g: skill effects of Legendary and Mythic items (Data/ItemEffects, Logic/ItemEffects). Data contract for the whole
-- skills 2.0 series S137-S148 (docs/DESIGN-18.md §0.9, D1-D4): every effect stands on an existing skill of its class,
-- a DESIGN-18 role and pool, a behaviour key with a receiver for the skill's type that the skill's own breakpoints do
-- not use; at most 2 effects per skill, at least 6 legendary and 3 mythic per class; a retired effect names a
-- successor. Rules: rolling, the effects of the equipment, Paths.effectiveFor, the save migration (item, account,
-- mail).

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Bonuses = require("../src/shared/Data/Bonuses")
local EffectData = require("../src/shared/Data/ItemEffects")
local ItemEffects = require("../src/shared/Logic/ItemEffects")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Mail = require("../src/shared/Logic/Mail")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local SkillData = require("../src/shared/Data/Skills")
local SkillPools = require("../src/shared/Logic/SkillPools")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")

-- DESIGN-18 §5 (Data/SkillPools.LADDER / COMMON_LADDER) and §4.2 (pools of the classes) until S137 adds the module.
local LADDER = { "S1", "A1", "K1", "O1", "S2", "P1", "A2", "K2", "S3", "P2", "U" }
local COMMON_LADDER = { "C1", "C2", "C3", "C4" }
local POOLS: { [string]: { string } } = {
	Mage = { "fire", "ice", "lightning" },
	Warrior = { "onehand", "twohand" },
	Hunter = { "bow", "crossbow" },
	Cleric = { "light", "hammer" },
}

-- Keys every breakpoint source may carry (summed or listed by Logic/Skills.effective, never "later wins").
local FREE: { [string]: boolean } =
	{ add = true, mul = true, values = true, effect = true, selfEffect = true, allyEffect = true }
-- Receivers of every skill type: Skills/Context.damage (lifesteal, knockback, execute, critCdr) and the end of a cast
-- in SkillService (selfHeal).
local GENERIC: { [string]: boolean } =
	{ lifesteal = true, knockback = true, execute = true, critCdr = true, selfHeal = true }
-- Receivers in Skills/Context.applyEffect on an effect of this kind of the skill.
local EFFECT_BOUND: { [string]: string } = { poisonSpread = "poison", markJump = "vulnerability" }
-- Receivers written in S134g for an item effect (Types/Offense cone echo, Types/Support groupHeal overhealShield).
local HANDLER: { [string]: { [string]: boolean } } = {
	cone = { echo = true },
	groupHeal = { overhealShield = true },
}

local function breakpointSources(skill: any): { any }
	local out: { any } = {}
	for _, pair in skill.breakpoints or {} do
		table.insert(out, pair.a)
		if pair.b then
			table.insert(out, pair.b)
		end
	end
	return out
end

-- Behaviour keys found in the breakpoints and modify nodes of every skill of a type except `except`.
local function receiversOf(skillType: string, except: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local function take(bp: any)
		for key in bp do
			out[key] = true
		end
	end
	for id, skill in SkillData.byId do
		if skill.type == skillType and id ~= except then
			for _, bp in breakpointSources(skill) do
				take(bp)
			end
		end
	end
	for _, path in PathData.list do
		for _, row in path.rows do
			for _, node in row.nodes do
				local modify = (node :: any).modify
				local skill = modify and SkillData.get(modify.skill)
				if skill and skill.type == skillType and skill.id ~= except then
					take(modify.bp)
				end
			end
		end
	end
	return out
end

local function hasKind(skill: any, kind: string): boolean
	for _, effect in skill.effects or {} do
		if effect.kind == kind then
			return true
		end
	end
	for _, bp in breakpointSources(skill) do
		if bp.effect and bp.effect.kind == kind then
			return true
		end
	end
	return false
end

-- Every effect the skill already puts on a side (its own list and its breakpoints).
local function ownEffects(skill: any, field: string): { any }
	local out: { any } = {}
	if field == "effect" then
		for _, effect in skill.effects or {} do
			table.insert(out, effect)
		end
	end
	for _, bp in breakpointSources(skill) do
		if bp[field] then
			table.insert(out, bp[field])
		end
	end
	return out
end

local function sample(defId: string, rarity: number, seed: number, forClass: string?): any
	return ItemRoll.rollItem(defId, 50, rarity, Rng.new(seed), `s{seed}`, forClass)
end

local function made(defId: string, rarity: number, bonuses: { any }, uid: string): any
	return {
		uid = uid,
		id = defId,
		rarity = rarity,
		ilvl = 50,
		bonuses = bonuses,
		up = 0,
		bound = false,
		n = 1,
		rv = Rarities.RV,
	}
end

T.describe("Item effects: data (S134g D1, B2)", function()
	T.it("every effect stands on an existing skill of its class, a DESIGN-18 role and pool", function()
		local count = 0
		for _, def in EffectData.list do
			count += 1
			local skill = SkillData.get(def.skill)
			T.expect({ def.id, skill ~= nil }).toEqual({ def.id, true })
			T.expect({ def.id, (skill :: any).class }).toEqual({ def.id, def.class })
			T.expect({ def.id, skill and skill.type ~= "passive" }).toEqual({ def.id, true })
			local isCommon = table.find(COMMON_LADDER, def.role) ~= nil
			T.expect({ def.id, isCommon or table.find(LADDER, def.role) ~= nil }).toEqual({ def.id, true })
			if isCommon then
				T.expect({ def.id, def.pool }).toEqual({ def.id, "common" })
			else
				T.expect({ def.id, table.find(POOLS[def.class], def.pool) ~= nil }).toEqual({ def.id, true })
			end
			T.expect({ def.id, def.tier == "legendary" or def.tier == "mythic" }).toEqual({ def.id, true })
			T.expect({ def.id, def.score.pct > 0, def.score.axis ~= nil }).toEqual({ def.id, true, true })
			T.expect({ def.id, string.sub(def.id, 1, #def.skill + 1) }).toEqual({ def.id, def.skill .. "_" })
		end
		T.expect(count >= 36).toBe(true)
		-- S134g: activates with S137 (Data/SkillPools and SkillDef.pool / role). S145: every class is on the ladder
		-- (no transitional pools), so every effect's skill has exactly the effect's pool and role
		for _, def in EffectData.list do
			local skill = SkillData.get(def.skill) :: any
			T.expect({ def.id, skill.pool, skill.role }).toEqual({ def.id, def.pool, def.role })
		end
	end)

	T.it(
		"rule of the receiver: a behaviour key the skill's breakpoints do not use, with a receiver for its type",
		function()
			for _, def in EffectData.list do
				local skill = SkillData.get(def.skill) :: any
				-- the skill's own breakpoints and the path nodes that modify it: an item key there would replace theirs
				local own: { [string]: boolean } = {}
				for _, bp in breakpointSources(skill) do
					for key in bp do
						own[key] = true
					end
				end
				for _, path in PathData.list do
					for _, row in path.rows do
						for _, node in row.nodes do
							local modify = (node :: any).modify
							if modify and modify.skill == skill.id then
								for key in modify.bp do
									own[key] = true
								end
							end
						end
					end
				end
				local receivers = receiversOf(skill.type, skill.id)
				local handler = HANDLER[skill.type] or {}
				for key in def.bp :: any do
					if not FREE[key] then
						T.expect({ def.id, key, "own breakpoint", own[key] == true })
							.toEqual({ def.id, key, "own breakpoint", false })
						local bound = EFFECT_BOUND[key]
						local received = receivers[key] == true
							or GENERIC[key] == true
							or handler[key] == true
							or (bound ~= nil and hasKind(skill, bound))
						T.expect({ def.id, key, "receiver", received }).toEqual({ def.id, key, "receiver", true })
					end
				end
				-- an extra effect never repeats a category (or, without one, a kind) the skill already applies (S53)
				for _, field in { "effect", "selfEffect", "allyEffect" } do
					local extra = (def.bp :: any)[field]
					if extra then
						for _, present in ownEffects(skill, field) do
							local clash = if extra.category ~= nil
								then extra.category ~= "own" and extra.category == present.category
								else present.category == nil and present.kind == extra.kind
							T.expect({ def.id, field, clash }).toEqual({ def.id, field, false })
						end
					end
				end
			end
		end
	)

	T.it("at most 2 effects a skill, at least 6 legendary and 3 mythic a class on the wiki", function()
		local perSkill: { [string]: number } = {}
		local perClass: { [string]: { legendary: number, mythic: number } } = {}
		for _, def in EffectData.list do
			if def.replacedBy == nil then
				perSkill[def.skill] = (perSkill[def.skill] or 0) + 1
				if def.wiki then
					local c = perClass[def.class] or { legendary = 0, mythic = 0 }
					perClass[def.class] = c;
					(c :: any)[def.tier] += 1
				end
			end
		end
		for skill, n in perSkill do
			T.expect({ skill, n <= 2 }).toEqual({ skill, true })
		end
		for _, classId in { "Warrior", "Hunter", "Mage", "Cleric" } do
			local c = perClass[classId] or { legendary = 0, mythic = 0 }
			T.expect({ classId, c.legendary >= 6, c.mythic >= 3 }).toEqual({ classId, true, true })
		end
	end)

	-- S144: a named weapon's fixed effects work with it in hand (common or the pool its type selects; Mage staves pick
	-- the pool by element, outside this check)
	T.it("a named weapon's fixed effects are common or in the pool of its type", function()
		for _, item in Items.uniques do
			local fixed: any = item.fx
			if item.weapon and not item.elemental and fixed and fixed[1] ~= nil then
				for _, id in fixed do
					local def = EffectData.get(id) :: any
					local pool = SkillPools.poolOf(def.class, { main = item.type })
					T.expect({ item.id, id, def.pool == "common" or def.pool == pool }).toEqual({ item.id, id, true })
				end
			end
		end
	end)

	T.it("a retired effect names an existing successor of the same class and tier", function()
		for _, def in EffectData.list do
			if def.replacedBy then
				local next = EffectData.get(def.replacedBy)
				T.expect({ def.id, next ~= nil }).toEqual({ def.id, true })
				T.expect({ def.id, (next :: any).class, (next :: any).tier }).toEqual({ def.id, def.class, def.tier })
			end
			T.expect((ItemEffects.resolve(def.id) :: any).replacedBy).toBeNil()
		end
		T.expect(ItemEffects.resolve("nope")).toBeNil()
		T.expect(ItemEffects.resolve(5)).toBeNil()
	end)

	T.it("texts: a name and a finished line in both languages with the skill's name", function()
		for _, def in EffectData.list do
			for _, lang in { "pl", "en" } do
				T.expect({ def.id, lang, Locale.has(def.nameKey, lang), Locale.has(def.lineKey, lang) })
					.toEqual({ def.id, lang, true, true })
				local line = ItemEffects.line(def, lang)
				T.expect({ def.id, lang, string.find(line, "{", 1, true) }).toEqual({ def.id, lang, nil })
				local skillName = Locale.T(`skill.{def.skill}.name`, nil, lang)
				T.expect({ def.id, lang, string.find(line, skillName, 1, true) ~= nil }).toEqual({ def.id, lang, true })
			end
		end
		T.expect(ItemEffects.lineArgs(EffectData.get("frostNova_deepcold") :: any, "pl").freezeDuration).toBe("0,5")
		T.expect(ItemEffects.lineArgs(EffectData.get("frostNova_deepcold") :: any, "en").freezeDuration).toBe("0.5")
	end)
end)

T.describe("Item effects: rolling (S134g C1)", function()
	T.it("Legendary 1, Mythic 1 legendary + 1 mythic, no repeats, the class of forClass", function()
		for seed = 1, 300 do
			local rng = Rng.new(seed)
			local legendary = ItemEffects.roll("ring_50", Rarities.LEGENDARY, rng, "Hunter")
			T.expect(#legendary).toBe(1)
			T.expect((ItemEffects.resolve(legendary[1]) :: any).class).toBe("Hunter")
			local mythic = ItemEffects.roll("sword1h_50", Rarities.MYTHIC, rng, "Mage")
			T.expect(#mythic).toBe(2)
			local a, b = ItemEffects.resolve(mythic[1]) :: any, ItemEffects.resolve(mythic[2]) :: any
			T.expect({ a.tier, b.tier, a.class, b.class }).toEqual({ "legendary", "mythic", "Warrior", "Warrior" })
			T.expect(#ItemEffects.roll("sword1h_50", Rarities.HEROIC, rng, "Warrior")).toBe(0)
			T.expect(#ItemEffects.roll("potion_hp_2", Rarities.MYTHIC, rng, "Warrior")).toBe(0)
		end
	end)

	T.it("a Mage weapon prefers its element's pool and the common skills", function()
		for _, element in { "fire", "ice", "lightning" } do
			for seed = 1, 100 do
				for _, id in ItemEffects.roll("wand_50", Rarities.MYTHIC, Rng.new(seed), "Mage", element) do
					local def = ItemEffects.resolve(id) :: any
					T.expect({ id, def.pool == element or def.pool == "common" }).toEqual({ id, true })
				end
			end
		end
		-- the rolled item: element first, then its effects
		for seed = 1, 100 do
			local wand = ItemRoll.rollItem("wand_50", 50, Rarities.LEGENDARY, Rng.new(seed), `w{seed}`)
			local def = ItemEffects.resolve((wand.fx :: { string })[1]) :: any
			T.expect({ wand.el, def.pool == wand.el or def.pool == "common" }).toEqual({ wand.el, true })
		end
	end)
end)

T.describe("Item effects: the equipment (S134g B4, B5)", function()
	T.it("active: the character's class only, one id once, slot order, legendary before mythic", function()
		local ring1 = made("ring_50", Rarities.MYTHIC, {}, "r1")
		ring1.fx = { "meteor_shards", "fireball_afterblast" }
		local ring2 = made("ring_50", Rarities.LEGENDARY, {}, "r2")
		ring2.fx = { "fireball_afterblast" }
		local helmet = made("helmet_light_50", Rarities.LEGENDARY, {}, "h")
		helmet.fx = { "charge_stagger" } -- a Warrior effect on a Mage: does nothing
		local weapon = made("wand_50", Rarities.LEGENDARY, {}, "w")
		weapon.fx = { "iceShard_shatter", "ghost_effect" }
		local mage = {
			class = "Mage",
			level = 60,
			equipment = { ring1 = ring1, ring2 = ring2, helmet = helmet, weapon = weapon },
		}
		local ids: { string } = {}
		for _, def in ItemEffects.list(mage) do
			table.insert(ids, def.id)
		end
		T.expect(ids).toEqual({ "iceShard_shatter", "fireball_afterblast", "meteor_shards" })
		local active = ItemEffects.active(mage)
		T.expect(#active.fireball).toBe(1)
		T.expect(active.charge).toBeNil()
		T.expect(#ItemEffects.mods(mage, "meteor")).toBe(1)
		T.expect(#ItemEffects.mods(mage, "firebolt")).toBe(0)
		T.expect(#ItemEffects.list({ class = "Mage" })).toBe(0)
		T.expect(#ItemEffects.list(nil)).toBe(0)
	end)

	T.it("Paths.effectiveFor: Meteor splits, Charge stuns longer, other skills unchanged", function()
		local wand = made("wand_50", Rarities.MYTHIC, {}, "w")
		wand.fx = { "fireball_afterblast", "meteor_shards" }
		local mage: any = { class = "Mage", level = 60, equipment = { weapon = wand } }
		local weapons = Paths.weaponTypesOf(mage.equipment)
		local _, meteor = Paths.effectiveFor(mage, "meteor", weapons, 10)
		T.expect((meteor :: any).split).toEqual({ count = 3, pct = 35, radius = 7 })
		local _, fireball = Paths.effectiveFor(mage, "fireball", weapons, 4)
		T.expect((fireball :: any).echo).toEqual({ delay = 1, pct = 30 })
		local bare: any = { class = "Mage", level = 60, equipment = {} }
		local plain, plainBehaviour = Paths.effectiveFor(mage, "iceShard", weapons, 4)
		local before = Paths.effectiveFor(bare, "iceShard", weapons, 4)
		T.expect(TableUtil.deepEqual(plain, before)).toBe(true)
		T.expect((plainBehaviour :: any).echo).toBeNil()

		local sword = made("sword1h_50", Rarities.LEGENDARY, {}, "s")
		sword.fx = { "charge_stagger" }
		local warrior: any = { class = "Warrior", level = 60, equipment = { weapon = sword } }
		local charge = Paths.effectiveFor(warrior, "charge", Paths.weaponTypesOf(warrior.equipment), 1)
		local stun = nil
		for _, effect in charge.effects or {} do
			if effect.kind == "stun" then
				stun = effect.duration
			end
		end
		T.expect(stun).toBeNear(0.8 + 0.7, 1e-9)
		-- the same item on a Mage changes nothing of the Warrior's skill (another class)
		local wrong: any = { class = "Mage", level = 60, equipment = { weapon = sword } }
		T.expect(#ItemEffects.mods(wrong, "charge")).toBe(0)
	end)
end)

T.describe("Item effects: migration (S134g C2)", function()
	T.it("a Legendary loses its legendary line, keeps the regular ones and gets one effect; idempotent", function()
		local item = made("sword1h_50", Rarities.LEGENDARY, {
			{ stat = "physAtk", v = 3.1 },
			{ stat = "leg_critDmg", v = 25 },
			{ stat = "critChance", v = 1.2 },
		}, "uid-legend-1")
		T.expect(ItemEffects.migrateItem(item, nil, "Warrior")).toBe(true)
		T.expect(item.bonuses).toEqual({ { stat = "physAtk", v = 3.1 }, { stat = "critChance", v = 1.2 } })
		T.expect(#item.fx).toBe(1)
		local def = ItemEffects.resolve(item.fx[1]) :: any
		T.expect({ def.tier, def.class }).toEqual({ "legendary", "Warrior" })
		local copy = TableUtil.deepCopy(item)
		T.expect(ItemEffects.migrateItem(item, nil, "Warrior")).toBe(false)
		T.expect(item).toEqual(copy)
		-- the same uid gives the same effect wherever it is converted first
		local twin = made("sword1h_50", Rarities.LEGENDARY, { { stat = "leg_thorns", v = 8 } }, "uid-legend-1")
		ItemEffects.migrateItem(twin, nil, "Warrior")
		T.expect(twin.fx).toEqual(item.fx)
	end)

	T.it("a Mythic gets two effects (legendary + mythic); Heroic and named items stay untouched", function()
		local mythic = made("ring_50", Rarities.MYTHIC, {
			{ stat = "str", v = 3 },
			{ stat = "leg_bossDamage", v = 8 },
			{ stat = "leg_killHeal", v = 3 },
			{ stat = "myth_physAtk", v = 10 },
		}, "uid-myth-1")
		T.expect(ItemEffects.migrateItem(mythic, nil, "Hunter")).toBe(true)
		T.expect(mythic.bonuses).toEqual({ { stat = "str", v = 3 } })
		local tiers: { string } = {}
		for _, id in mythic.fx do
			local def = ItemEffects.resolve(id) :: any
			T.expect(def.class).toBe("Hunter")
			table.insert(tiers, def.tier)
		end
		T.expect(tiers).toEqual({ "legendary", "mythic" })
		local heroic = made("ring_50", Rarities.HEROIC, { { stat = "str", v = 3 } }, "uid-h")
		T.expect(ItemEffects.migrateItem(heroic, nil, "Hunter")).toBe(false)
		T.expect(heroic.fx).toBeNil()
		local named: any = ItemRoll.rollItem("unique_grimrok_cleaver", 20, Rarities.MYTHIC, Rng.new(1), "uid-n")
		local before = TableUtil.deepCopy(named)
		T.expect(ItemEffects.migrateItem(named, nil, "Warrior")).toBe(false)
		T.expect(named).toEqual(before)
	end)

	T.it("junk in the fields: type-safe, unknown effect ids dropped, a weapon's class from its definition", function()
		local junk: any = made("bow_50", Rarities.LEGENDARY, {}, "uid-j")
		junk.bonuses = "x"
		junk.fx = 5
		T.expect(ItemEffects.migrateItem(junk, nil, "Mage")).toBe(true)
		T.expect(junk.bonuses).toEqual({})
		T.expect((ItemEffects.resolve(junk.fx[1]) :: any).class).toBe("Hunter") -- a bow fits only the Hunter
		local unknown: any = made("bow_50", Rarities.LEGENDARY, {}, "uid-u")
		unknown.fx = { "ghost_effect", 7 }
		T.expect(ItemEffects.migrateItem(unknown, nil, "Hunter")).toBe(true)
		T.expect(#unknown.fx).toBe(1)
		T.expect(ItemEffects.migrateItem(nil, nil, nil)).toBe(false)
		T.expect(ItemEffects.migrateItem({ id = 5 }, nil, nil)).toBe(false)
		T.expect(ItemEffects.migrateItem({ id = "sword1h_50", rarity = "x" }, nil, nil)).toBe(false)
		-- a freshly rolled Legendary is already complete
		local fresh = sample("sword1h_50", Rarities.LEGENDARY, 9)
		T.expect(ItemEffects.migrateItem(fresh, nil, "Warrior")).toBe(false)
		-- no legendary line can be rolled any more
		for _, bonus in sample("ring_50", Rarities.MYTHIC, 11, "Cleric").bonuses do
			T.expect((Bonuses.get(bonus.stat) :: any).tier).toBe("regular")
		end
	end)

	T.it("schema 10: equipment, backpack, side quest choices and the deposit convert once; the toast flag", function()
		local function legend(uid: string): any
			return made("sword1h_50", Rarities.LEGENDARY, { { stat = "leg_critDmg", v = 25 } }, uid)
		end
		local data: any = {
			schema = 9,
			characters = {
				["1"] = {
					name = "A",
					class = "Warrior",
					equipment = { weapon = legend("e1") },
					inventory = { ["3"] = legend("i1"), ["4"] = "junk" },
					quests = { side = { active = { q = { choice = { legend("c1") } } }, done = {} } },
				},
				["2"] = "broken",
			},
			deposit = { size = 60, items = { ["1"] = legend("d1") } },
		}
		local applied = AccountSchema.migrate(data)
		T.expect(applied).toEqual({ 10, 11, 12 }) -- S134k: 11 = contracts; S137: 12 = skill points
		local char = data.characters["1"]
		for _, item in
			{ char.equipment.weapon, char.inventory["3"], char.quests.side.active.q.choice[1], data.deposit.items["1"] }
		do
			T.expect({ item.uid, #item.bonuses, #item.fx }).toEqual({ item.uid, 0, 1 })
		end
		T.expect((ItemEffects.resolve(char.equipment.weapon.fx[1]) :: any).class).toBe("Warrior")
		T.expect(data.legendRework).toBe(true)
		local copy = TableUtil.deepCopy(data)
		T.expect(#AccountSchema.migrate(data)).toBe(0)
		AccountSchema._migrations[10](data, function(): string
			return "x"
		end)
		T.expect(data).toEqual(copy)
		-- a new account: no notice
		T.expect(AccountSchema.accountTemplate().legendRework).toBe(false)
		local clean: any = { schema = 9, characters = {} }
		AccountSchema.migrate(clean)
		T.expect(clean.legendRework).toBe(false)
	end)

	T.it("mail converts on reading with the addressee's class (the same function)", function()
		local box = Mail.box({
			parcels = {
				p = {
					id = "p",
					items = { made("ring_50", Rarities.LEGENDARY, { { stat = "leg_thorns", v = 8 } }, "mail-1") },
					charId = "c",
				},
			},
		}, function(charId: string?): string?
			return if charId == "c" then "Cleric" else nil
		end)
		local item = box.parcels.p.items[1] :: any
		T.expect(#item.bonuses).toBe(0)
		T.expect((ItemEffects.resolve(item.fx[1]) :: any).class).toBe("Cleric")
		T.expect(Items.get(item.id) ~= nil).toBe(true)
	end)
end)

-- Owner 2026-10-20: a weapon rolls (and keeps) only effects of its own skill pool and of the class's common skills.
T.describe("Item effects follow the weapon (owner 2026-10-20)", function()
	T.it("every generated weapon of every tier rolls only its pool's effects", function()
		for _, def in Items.byId do
			if def.category ~= "equipment" or def.slot ~= "weapon" or def.fixedBonuses ~= nil then
				continue
			end
			for _, classId in def.classes or {} do
				local own = ItemEffects.weaponPool(classId, def.type)
				if own == nil then
					continue
				end
				for seed = 1, 6 do
					for _, id in ItemEffects.roll(def.id, Rarities.MYTHIC, Rng.new(seed), classId, nil) do
						local fx = assert(EffectData.byId[id], id)
						if not def.elemental then
							T.expect({ def.id, id, fx.pool == own or fx.pool == "common" })
								.toEqual({ def.id, id, true })
						end
					end
				end
			end
		end
	end)

	T.it("a bow's crossbow effect is redrawn from the bow's pool on load", function()
		local bow = Items.get("bow_1") :: any
		local own = assert(ItemEffects.weaponPool("Hunter", bow.type))
		local wrong: string? = nil
		for _, fx in EffectData.list do
			if
				fx.class == "Hunter"
				and fx.tier == "mythic"
				and fx.pool ~= own
				and fx.pool ~= "common"
				and fx.replacedBy == nil
			then
				wrong = fx.id
				break
			end
		end
		if wrong == nil then
			return
		end
		local item: any = { id = "bow_1", uid = "u-bow", rarity = Rarities.MYTHIC, bonuses = {}, fx = { wrong } }
		ItemEffects.migrateItem(item, bow, "Hunter")
		for _, id in item.fx or {} do
			local fx = EffectData.byId[id]
			T.expect({ id, fx.pool == own or fx.pool == "common" }).toEqual({ id, true })
		end
	end)
end)

return nil
