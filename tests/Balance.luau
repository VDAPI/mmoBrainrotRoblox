--!strict
-- Balance model (S32, DESIGN §15.1): expected values from the game's own modules, no randomness.
-- Used by balance.spec (targets of DESIGN §15.1) and tools/balance_report.luau (docs/BALANS.md).
--
--   gear(classId, level, opts)      -> the items a player wears (weapon, off-hand, 4 armour pieces, jewellery)
--   player(classId, level, opts)    -> StatCalc values of that player + the weapon
--   duel / groupFight / expectedGroup / elite / elite2 / grimrok -> fight length and HP lost
--   power(...)                      -> "character power" = sqrt(DPS x effective HP), for rarity value
--   pace(...) / economy(...)        -> kills per level, EXP/h, gold/h and the 1-20 gold budget
-- S83 (balance plan, world model 1-100; the S32 functions above stay as they are and build the 1-20 tables):
--   regionAt / kindAtRegion / kindRates          -> the usual kind of a level, kinds of a region vs GENERIC
--   questsAt / paceAt / paceBand / economyAt     -> quests on their own level, pace with carried EXP, gold per hour
--   potionsAt / potionHps                        -> potions on the S54 interval (Logic/Potions)
--   caveElites / team / bossCadence / bossFight  -> cave Elites from the real spawners, the bosses' schedule
--   targets1_20 / targetsGlobal / targetsRegion  -> target rows for balance.spec and the report (TUNED, REGION_TARGETS)
--   dataDump / rankDump / ledger                 -> the balance ledger (tools/balance_reasons.luau)
--
-- Fights use basic attacks plus `SKILL_DPS` (1-2 skills on cooldown) and no potions. Monsters swing once at the
-- start and then every interval; the player regenerates its in-combat regen.

local fs = require("@lune/fs")

local AreaRates = require("../src/shared/Logic/AreaRates")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local Bases = require("../src/shared/Data/Items/Bases")
local Bonuses = require("../src/shared/Data/Bonuses")
local Bosses = require("../src/shared/Data/Bosses")
local BossScaling = require("../src/shared/Logic/BossScaling")
local Classes = require("../src/shared/Data/Classes")
local Families = require("../src/shared/Data/Families")
local Combat = require("../src/shared/Data/Combat")
local Exp = require("../src/shared/Logic/Exp")
local FightSim = require("../src/shared/Logic/FightSim")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local PartyBonus = require("../src/shared/Logic/PartyBonus")
local Potions = require("../src/shared/Logic/Potions")
local Quests = require("../src/shared/Data/Quests")
local Rarities = require("../src/shared/Data/Rarities")
local Shops = require("../src/shared/Data/Shops")
local SkillData = require("../src/shared/Data/Skills")
local Spawns = require("../src/shared/Data/Spawns")
local Skills = require("../src/shared/Logic/Skills")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Stats = require("../src/shared/Data/Stats")
local Upgrade = require("../src/shared/Logic/Upgrade")

local Balance = {}

Balance.CLASSES = { "Warrior", "Hunter", "Mage", "Cleric" }

-- Main weapon, off-hand and armour weight per class (the most common choice).
Balance.LOADOUT = {
	Warrior = { weapon = "sword1h", offhand = "shield", weight = "heavy" },
	Hunter = { weapon = "bow", offhand = "quiver", weight = "medium" },
	Mage = { weapon = "wand", offhand = "orb", weight = "light" },
	Cleric = { weapon = "mace1h", offhand = "shield", weight = "heavy" },
} :: { [string]: { weapon: string, offhand: string?, weight: string } }

-- Damage share of 1-2 skills used on cooldown on top of basic attacks (single target).
Balance.SKILL_DPS = FightSim.SKILL_DPS
-- Share of a boss fight the players spend hitting (the rest: moving out of telegraphs).
Balance.BOSS_UPTIME = 0.75
-- Share of Elite II / boss special attacks that still hit (most telegraphs are dodged).
Balance.SPECIAL_HIT = FightSim.SPECIAL_HIT
-- Gear "at level": item level = player level - GEAR_GAP (what drops give on average).
Balance.GEAR_GAP = 2
-- Seconds between two fights (walking to the next group) and out-of-combat regeneration (% max HP / s).
Balance.BREAK = 1
Balance.WALK = 6

Balance.ARMOR_SLOTS = { "helmet", "armor", "gloves", "boots" }
Balance.JEWELLERY = { "necklace", "ring", "ring", "talisman" }

export type GearOpts = {
	ilvl: number?, -- default level - GEAR_GAP
	weaponIlvl: number?, -- weapon and off-hand (shop tiers), default ilvl
	rarity: number?,
	up: number?,
	weapon: string?, -- base type
	offhand: (string | false)?, -- base type, false = none (two-handed weapons never have one)
	jewellery: boolean?, -- default true
	armor: boolean?, -- default true
	bonuses: boolean?, -- expected random bonuses (default true)
}

local function tierId(baseType: string, ilvl: number): string
	return `{baseType}_{Items.generate.tierFor(math.max(1, ilvl))}`
end

-- Bonus pool an item of `defId` rolls from for `classId` (ItemRoll.bonusPool since S32, raw pool before).
local function poolFor(defId: string, classId: string?): { string }
	local roll: any = ItemRoll
	if roll.bonusPool then
		return roll.bonusPool(defId, classId)
	end
	local def = Items.get(defId) :: any
	return Bonuses.pools[def.bonusGroup or ""] or {}
end

-- S67: a family line works on the matching family in half of the fights (STATY 10: situational lines count half).
local FAMILY_MATCH = 0.5

-- Expected lines of one pool entry with chance `share`. S67: a family marker spreads half its middle value over each
-- family's variant (the model reads only the line of the monster's family); a class marker is worth 0 in PvE but
-- keeps its place in the pool.
local function expectedLines(out: { any }, id: string, ilvl: number, rarity: number, share: number)
	local param = Bonuses.params[id]
	if not param then
		table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
	elseif param.over == "family" then
		for _, family in Families.ids do
			local variant = Bonuses.familyLine(param.prefix, family)
			local v = ItemRoll.rollBonusValue(variant, ilvl, rarity, 0.5) * share * FAMILY_MATCH
			table.insert(out, { stat = variant, v = v })
		end
	end
end

-- Expected bonus lines of one item: every pool entry gets its chance to be rolled x its middle value. S62: the chance
-- is ItemRoll.inclusion of the type-weighted pool, averaged over bonusMin..bonusMax (rng:int); before, count / #pool.
local function expectedBonuses(defId: string, ilvl: number, rarity: number, classId: string?): { any }
	local rarityDef = Rarities.get(rarity)
	local out = {}
	local roll: any = ItemRoll
	if roll.poolWeights and rarityDef.bonusMax > 0 then
		local weights = roll.poolWeights(defId, classId)
		local share: { [string]: number } = {}
		local n = rarityDef.bonusMax - rarityDef.bonusMin + 1
		for k = rarityDef.bonusMin, rarityDef.bonusMax do
			for id, p in roll.inclusion(weights, k) do
				share[id] = (share[id] or 0) + p / n
			end
		end
		for _, id in poolFor(defId, classId) do
			expectedLines(out, id, ilvl, rarity, share[id] or 0)
		end
	else
		local pool = poolFor(defId, classId)
		local count = (rarityDef.bonusMin + rarityDef.bonusMax) / 2
		if count > 0 and #pool > 0 then
			local share = math.min(1, count / #pool)
			for _, id in pool do
				expectedLines(out, id, ilvl, rarity, share)
			end
		end
	end
	local legendary = Bonuses.pools.legendary
	if rarityDef.legendaryLines > 0 then
		local share = rarityDef.legendaryLines / #legendary
		for _, id in legendary do
			table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
		end
	end
	local mythic = Bonuses.pools.mythic
	if rarityDef.mythicLines > 0 then
		local share = rarityDef.mythicLines / #mythic
		for _, id in mythic do
			table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
		end
	end
	return out
end

local function makeItem(defId: string, ilvl: number, rarity: number, up: number, bonuses: { any }): any
	return {
		uid = "model",
		id = defId,
		rarity = rarity,
		ilvl = ilvl,
		bonuses = bonuses,
		up = up,
		bound = false,
		n = 1,
		rv = Rarities.RV,
	}
end

-- Item instances of a full set for `classId`.
function Balance.gear(classId: string, level: number, opts: GearOpts?): { any }
	local o: GearOpts = opts or {}
	local loadout = Balance.LOADOUT[classId]
	local ilvl = math.max(1, math.floor(o.ilvl or (level - Balance.GEAR_GAP)))
	local rarity = o.rarity or Rarities.COMMON
	local up = o.up or 0
	local withBonuses = o.bonuses ~= false
	local items = {}
	local function add(defId: string, level: number?)
		local l = level or ilvl
		local bonuses = if withBonuses then expectedBonuses(defId, l, rarity, classId) else {}
		table.insert(items, makeItem(defId, l, rarity, up, bonuses))
	end
	local weaponIlvl = math.max(1, math.floor(o.weaponIlvl or ilvl))
	local weaponType = o.weapon or loadout.weapon
	add(tierId(weaponType, weaponIlvl), weaponIlvl)
	local weaponBase = Bases.byType[weaponType] :: any
	local twoHanded = weaponBase.weapon(1).twoHanded
	local offhand = if o.offhand == false then nil else (o.offhand or loadout.offhand)
	if offhand and not twoHanded then
		add(tierId(offhand :: string, weaponIlvl), weaponIlvl)
	end
	if o.armor ~= false then
		for _, slot in Balance.ARMOR_SLOTS do
			add(tierId(`{slot}_{loadout.weight}`, ilvl))
		end
	end
	if o.jewellery ~= false then
		for _, slot in Balance.JEWELLERY do
			add(tierId(slot, ilvl))
		end
	end
	return items
end

-- Allocated stats: class start + every point into the main stat(s).
function Balance.statsFor(classId: string, level: number): any
	local class = Classes.get(classId) :: Classes.ClassDef
	local stats = table.clone(class.startStats) :: any
	local mains = class.mainStats
	for i = 1, (level - 1) * 5 do
		local id = mains[(i - 1) % #mains + 1]
		stats[id] += 1
	end
	return stats
end

export type Player = {
	classId: string,
	level: number,
	values: { [string]: number },
	hooks: { [string]: number },
	magic: boolean,
}

function Balance.playerFromItems(classId: string, level: number, items: { any }): Player
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	local hooks: { [string]: number } = {}
	local weapon: any = nil
	for _, item in items do
		local stats = ItemRoll.itemStats(item)
		for id, v in stats.flat do
			flat[id] = (flat[id] or 0) + v
		end
		for id, v in stats.pct do
			pct[id] = (pct[id] or 0) + v
		end
		for id, v in stats.hooks do
			hooks[id] = (hooks[id] or 0) + v
		end
		if stats.weapon then
			weapon = stats.weapon
		end
	end
	local class = Classes.get(classId) :: Classes.ClassDef
	if not weapon then
		local unarmed = Stats.Formula.unarmed
		weapon = { dmg = unarmed.dmg, mdmg = unarmed.mdmg, speed = unarmed.speed, ranged = class.basicAttack.ranged }
	end
	local result = StatCalc.compute({
		level = level,
		stats = Balance.statsFor(classId, level),
		sources = { { key = "gear", flat = flat, pct = pct } },
		weapon = { dmg = weapon.dmg, mdmg = weapon.mdmg, speed = weapon.speed, ranged = weapon.ranged },
	})
	return {
		classId = classId,
		level = level,
		values = result.values,
		hooks = hooks,
		magic = class.basicAttack.kind == "magic",
	}
end

function Balance.player(classId: string, level: number, opts: GearOpts?): Player
	return Balance.playerFromItems(classId, level, Balance.gear(classId, level, opts))
end

-- Monsters ------------------------------------------------------------------------------------------------

Balance.FAMILY_MATCH = FAMILY_MATCH
-- S67: a family so family lines count; in the model every family gives the same (FAMILY_MATCH spreads the lines).
Balance.GENERIC = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee", family = Families.ids[1] }

-- Stats of a monster kind (Data/Monsters id or a kind table) at spawner level `level`.
function Balance.monster(kind: any, level: number, variant: string?, groupSize: number?): any
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	assert(def, `Balance: unknown monster {kind}`)
	return (MonsterStats.compute :: any)(def, level, variant or "normal", groupSize)
end

-- Damage of the player's basic attacks + skills against a monster, per second (Logic/FightSim).
function Balance.dps(p: Player, m: any): number
	return FightSim.dps(p :: any, m, Balance.SKILL_DPS)
end

-- Damage of one monster attack (multiplier `mul`) against the player, expected, after armour / resistance.
function Balance.hit(m: any, p: Player, mul: number?, kind: string?, canDodge: boolean?): number
	return FightSim.hit(m, p :: any, mul, kind, canDodge)
end

export type Fight = FightSim.Fight

-- One player against members killed one by one; every living member attacks.
function Balance.groupFight(p: Player, members: { any }): Fight
	return FightSim.groupFight(p :: any, members, Balance.SKILL_DPS)
end

function Balance.duel(p: Player, m: any): Fight
	return Balance.groupFight(p, { m })
end

-- Group weights of Logic/AreaSpawns (1-4 members).
function Balance.groupWeights(): { [number]: number }
	return AreaSpawns.GROUP_SIZE_WEIGHTS
end

-- A group of `n` monsters of `kind` at `level`.
function Balance.group(kind: any, level: number, n: number): { any }
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	return FightSim.group(def, level, n)
end

-- Expected fight over group sizes (weights of AreaSpawns): HP lost and seconds per fight, members per fight.
function Balance.expectedGroup(
	p: Player,
	kind: any,
	level: number
): { hpLost: number, seconds: number, members: number, bySize: { Fight } }
	local def = if type(kind) == "string" then Monsters.get(kind) else kind
	return FightSim.expectedGroup(p :: any, def, level, Balance.SKILL_DPS)
end

-- Elite (cave, spawner level = player level, variant adds its levels).
function Balance.elite(p: Player, kind: any, level: number): Fight
	return Balance.duel(p, Balance.monster(kind, level, "elite"))
end

-- Elite II with its ability, against `players` copies of the team (damage on the first one, the tank).
function Balance.elite2(team: { Player }, kind: string, level: number): Fight
	local def = Monsters.get(kind) :: any
	local m = table.clone(Balance.monster(def, level, "elite2"))
	m.ability = if def.ability then MonsterAbilities.get(def.ability) else nil
	local tank = team[1]
	local dps = 0
	for _, p in team do
		dps += Balance.dps(p, m)
	end
	local seconds = m.maxHp / dps
	local lost = Balance.hit(m, tank) * (1 + seconds / m.attackInterval)
	if m.ability then
		lost += Balance.hit(m, tank, m.ability.damage, m.ability.damageKind, false) * Balance.SPECIAL_HIT * seconds / m.ability.cooldown
	end
	lost -= (tank.values.hpRegenCombat or 0) * seconds
	return { seconds = seconds, hpLost = math.max(0, lost) / tank.values.maxHp, playerHp = tank.values.maxHp }
end

-- Grimrok (or another boss): fight length for `team`, the biggest single hit on each team member and the tank's
-- HP lost per minute from basic attacks + the threat attacks.
function Balance.boss(bossId: string, team: { Player }): any
	local def = Bosses.byId[bossId] :: any
	local kind = {
		hpMul = BossScaling.hpMultiplier(#team) * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul, -- S66
		family = def.family, -- S66
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}
	local m = Balance.monster(kind, def.level, "boss")
	local dps = 0
	for _, p in team do
		dps += Balance.dps(p, m) * Balance.BOSS_UPTIME
	end
	local seconds = m.maxHp / dps
	local biggest = {}
	local biggestMul = 1
	for _, attack in def.attacks do
		biggestMul = math.max(biggestMul, attack.damage)
	end
	for i, p in team do
		biggest[i] = {
			classId = p.classId,
			hit = Balance.hit(m, p, biggestMul, nil, false) * Combat.randomMax,
			share = Balance.hit(m, p, biggestMul, nil, false) * Combat.randomMax / p.values.maxHp,
			basic = Balance.hit(m, p) / p.values.maxHp,
		}
	end
	local tank = team[1]
	local tankPerSecond = Balance.hit(m, tank) / m.attackInterval
	for _, attack in def.attacks do
		if attack.target == "threat" then
			tankPerSecond += Balance.hit(m, tank, attack.damage, nil, false) * Balance.SPECIAL_HIT / attack.cooldown
		end
	end
	return {
		hp = m.maxHp,
		attack = m.attack,
		seconds = seconds,
		biggest = biggest,
		biggestMul = biggestMul,
		tankHpPerMinute = tankPerSecond * 60 / tank.values.maxHp,
	}
end

-- Character power: sqrt(DPS x effective HP) against a generic monster of the player's level.
function Balance.power(p: Player, level: number?): number
	local m = Balance.monster(Balance.GENERIC, level or p.level)
	local hit = Balance.hit(m, p)
	local ehp = p.values.maxHp / math.max(hit, 1e-6)
	return math.sqrt(Balance.dps(p, m) * ehp)
end

-- Power of a full set of `rarity` relative to Common (same ilvl): 0.12 = +12 %.
function Balance.rarityGain(classId: string, level: number, rarity: number): number
	local base = Balance.power(Balance.player(classId, level))
	local better = Balance.power(Balance.player(classId, level, { rarity = rarity }))
	return better / base - 1
end

-- DPS x survivability of a weapon choice relative to the class's default loadout.
function Balance.weaponScore(classId: string, level: number, weapon: string, offhand: (string | false)?): number
	local p = Balance.player(classId, level, { weapon = weapon, offhand = offhand })
	return Balance.power(p)
end

-- Reward of one kill ---------------------------------------------------------------------------------------

-- Kind factor for EXP and gold (MonsterStats.kindReward since S32, 1 before).
function Balance.kindReward(kind: any): number
	local stats: any = MonsterStats
	if stats.kindReward then
		return stats.kindReward(if type(kind) == "string" then Monsters.get(kind) else kind)
	end
	return 1
end

function Balance.killExp(playerLevel: number, kind: any, monsterLevel: number, variant: string?): number
	local base = Exp.monsterExp(monsterLevel, (variant or "normal") :: any)
	local mul = if (variant or "normal") == "boss" then 1 else Balance.kindReward(kind)
	return base * mul * Exp.levelDiffMultiplier(playerLevel, monsterLevel)
end

function Balance.killGold(playerLevel: number, kind: any, monsterLevel: number, variant: string?): number
	local stats: any = MonsterStats
	local v = variant or "normal"
	local gold = MonsterStats.gold(monsterLevel, v, 0.5)
	if stats.goldLevelMultiplier then
		gold *= stats.goldLevelMultiplier(playerLevel, monsterLevel)
	end
	if v ~= "boss" then
		gold *= Balance.kindReward(kind)
	end
	return gold
end

-- Expected merchant value of the items and materials of one kill (normal / elite / elite2).
function Balance.dropValue(monsterLevel: number, variant: string, partId: string?): number
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local count = drops.chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	local slots = LootTables.byId.wolf.slotWeights
	local wTotal, slotTotal = 0, 0
	for _, w in weights do
		wTotal += w
	end
	for _, w in slots do
		slotTotal += w
	end
	local ilvl = Balance.dropIlvl(monsterLevel, variant)
	local value = 0
	for rarity, w in weights do
		for slot, sw in slots do
			local def = Items.get(
				tierId(
					if slot == "weapon"
						then "sword1h"
						elseif slot == "offhand" then "shield"
						elseif slot == "ring" or slot == "necklace" or slot == "talisman" then slot
						else `{slot}_heavy`,
					ilvl
				)
			) :: any
			value += (w / wTotal) * (sw / slotTotal) * ItemValue.equipment(def, ilvl, rarity, 0)
		end
	end
	local materials = 0
	local tableDef = LootTables.byId[partId or "wolf"] or LootTables.byId.wolf
	local list = table.clone(tableDef.materials)
	for _, mat in tableDef.variantMaterials[variant] or {} do
		table.insert(list, mat)
	end
	for _, mat in list do
		local def = Items.get(mat.id) :: any
		if def then
			materials += mat.chance * (mat.min + mat.max) / 2 * def.price
		end
	end
	return count * value + materials, count
end

-- Average item level of a drop (ItemRoll.dropLevelRange since S32: level - 0..2; before: level +-2).
function Balance.dropIlvl(monsterLevel: number, variant: string?): number
	local roll: any = ItemRoll
	if roll.dropLevelRange then
		local low, high = roll.dropLevelRange(monsterLevel, variant)
		return (low + high) / 2
	end
	local add = if variant == "elite" then 2 elseif variant == "elite2" then 4 else 0
	return monsterLevel + add
end

-- Share of normal drops a player of `level` can wear (monster level = player level).
function Balance.wearableShare(level: number): number
	local roll: any = ItemRoll
	if roll.dropLevelRange then
		local low, high = roll.dropLevelRange(level, "normal")
		local ok = 0
		for l = low, high do
			ok += if l <= level then 1 else 0
		end
		return ok / (high - low + 1)
	end
	local ok = 0
	for d = -2, 2 do
		ok += if math.max(1, level + d) <= level then 1 else 0
	end
	return ok / 5
end

-- Pace and economy -----------------------------------------------------------------------------------------

-- Share of the side quests a player does on the way (the main story counts in full).
Balance.SIDE_SHARE = 0.5

-- Quest EXP and gold of levels 1..19 (main story + SIDE_SHARE of the Meadows side quests), spread over the levels
-- in proportion to the EXP each level needs (quests are done along the way, not all at their own level).
function Balance.questRewards(level: number): (number, number)
	local exp, gold, need = 0, 0, 0
	for _, entry in { { Quests.Main.list, 1 }, { Quests.Side.list, Balance.SIDE_SHARE } } do
		for _, q in entry[1] :: any do
			if q.level < 20 then
				exp += (q.reward.exp or 0) * entry[2]
				gold += (q.reward.gold or 0) * entry[2]
			end
		end
	end
	for l = 1, 19 do
		need += Exp.expToNext(l)
	end
	local share = Exp.expToNext(level) / need
	return exp * share, gold * share
end

-- Monsters killed for quest objectives at `level` (main story + SIDE_SHARE of side quests), spread like the EXP.
function Balance.questKills(level: number): number
	local kills, need = 0, 0
	for _, entry in { { Quests.Main.list, 1 }, { Quests.Side.list, Balance.SIDE_SHARE } } do
		for _, q in entry[1] :: any do
			if q.level < 20 then
				for _, o in q.objectives do
					if o.type == "kill" then
						kills += o.n * entry[2]
					end
				end
			end
		end
	end
	for l = 1, 19 do
		need += Exp.expToNext(l)
	end
	return kills * Exp.expToNext(level) / need
end

-- Expected items of `rarity` per kill of `variant` that the killer's class can use (class bias of LootTables,
-- jewellery counts for everyone).
function Balance.itemsPerKill(variant: string, rarity: number): number
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local count = drops.chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	local total = 0
	for _, w in weights do
		total += w
	end
	local bias = LootTables.byId.wolf.classBias
	return count * (weights[rarity] or 0) / total * (bias + (1 - bias) * 0.25)
end

-- Seconds per Elite kill in a cave at `level` (fight + rest + walk), for `classId`.
function Balance.eliteCadence(classId: string, level: number): number
	local p = Balance.player(classId, level)
	local f = Balance.elite(p, Balance.GENERIC, level)
	return f.seconds + f.hpLost / (Stats.Formula.hpRegenPct / 100) + Balance.BREAK + Balance.WALK
end

-- The usual monster kind of a level on the Meadows (for EXP, gold and parts).
function Balance.kindAt(level: number): string
	local best, bestMid = "wolf", math.huge
	for _, def in Monsters.list do
		if def.region == 1 and not def.passive then
			if level >= def.levels.min and level <= def.levels.max then
				local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
				if mid < bestMid then
					best, bestMid = def.id, mid
				end
			end
		end
	end
	return best
end

export type Pace = {
	level: number,
	kind: string,
	expPerKill: number,
	goldPerKill: number,
	dropPerKill: number,
	secondsPerKill: number,
	kills: number,
	hours: number,
	expPerHour: number,
	goldPerHour: number,
	questGold: number,
	questExp: number,
	hpLostPerFight: number,
	restShare: number,
}

-- Grinding groups of the level's kind at the player's level (classId's fight), with rests.
function Balance.pace(classId: string, level: number): Pace
	local kind = Balance.kindAt(level)
	local p = Balance.player(classId, level)
	local fight = Balance.expectedGroup(p, kind, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local rest = fight.hpLost / regen
	local perFight = fight.seconds + rest + Balance.BREAK + Balance.WALK
	local secondsPerKill = perFight / fight.members
	local expPerKill = Balance.killExp(level, kind, level)
	local goldPerKill = Balance.killGold(level, kind, level)
	local dropPerKill = Balance.dropValue(level, "normal", kind)
	local questExp, questGold = Balance.questRewards(level)
	local need = math.max(0, Exp.expToNext(level) - questExp)
	local kills = need / expPerKill
	local hours = kills * secondsPerKill / 3600
	return {
		level = level,
		kind = kind,
		expPerKill = expPerKill,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		secondsPerKill = secondsPerKill,
		kills = kills,
		hours = hours,
		expPerHour = expPerKill * 3600 / secondsPerKill,
		goldPerHour = goldPerKill * 3600 / secondsPerKill,
		questGold = questGold,
		questExp = questExp,
		hpLostPerFight = fight.hpLost,
		restShare = rest / perFight,
	}
end

-- Expected gold of upgrading an item of `ilvl` from +0 to +`to` (one success per step, failures repeat the step
-- with the item kept by a protection scroll counted as the same attempt).
function Balance.upgradeGold(ilvl: number, to: number): number
	local item = makeItem("sword1h_1", ilvl, Rarities.COMMON, 0, {})
	local total = 0
	for n = 1, to do
		total += Upgrade.cost(item, n).gold / (Upgrade.chance(n) / 100)
	end
	return total
end

-- Potion gold per kill: the HP lost above REST_LIMIT of a fight is healed with the cheapest fitting potion.
Balance.POTION_ABOVE = 0.6
function Balance.potionGold(classId: string, level: number): number
	local kind = Balance.kindAt(level)
	local p = Balance.player(classId, level)
	local fight = Balance.expectedGroup(p, kind, level)
	local weights = Balance.groupWeights()
	local total, gold = 0, 0
	local potions = {}
	for q = 1, 5 do
		local def = Items.get(`potion_hp_{q}`) :: any
		table.insert(potions, { heal = def.use.amount, price = def.buyPrice })
	end
	for n, w in weights do
		local over = math.max(0, fight.bySize[n].hpLost - Balance.POTION_ABOVE) * p.values.maxHp
		local cost = 0
		if over > 0 then
			local best = math.huge
			for _, potion in potions do
				best = math.min(best, math.ceil(over / potion.heal) * potion.price)
			end
			cost = best
		end
		total += w
		gold += w * cost
	end
	return gold / total / fight.members
end

export type Economy = {
	rows: { any },
	killGold: number,
	dropGold: number,
	questGold: number,
	potionGold: number,
	upgradeGold: number,
}

-- Gold budget from level 1 to 20 for `classId`.
function Balance.economy(classId: string, toLevel: number?): Economy
	local rows = {}
	local killGold, dropGold, questGold, potionGold, upgradeGold = 0, 0, 0, 0, 0
	for level = 1, (toLevel or 20) - 1 do
		local pace = Balance.pace(classId, level)
		local kills = pace.kills
		local income = kills * (pace.goldPerKill + pace.dropPerKill) + pace.questGold
		local potions = kills * Balance.potionGold(classId, level)
		local ilvl = math.max(1, level - Balance.GEAR_GAP)
		local up3 = Balance.upgradeGold(ilvl, 3)
		killGold += kills * pace.goldPerKill
		dropGold += kills * pace.dropPerKill
		questGold += pace.questGold
		potionGold += potions
		upgradeGold += up3
		table.insert(rows, {
			level = level,
			pace = pace,
			income = income,
			kills = kills * pace.goldPerKill,
			drops = kills * pace.dropPerKill,
			potions = potions,
			up1 = Balance.upgradeGold(ilvl, 1),
			up3 = up3,
			up9 = Balance.upgradeGold(ilvl, 9),
		})
	end
	return {
		rows = rows,
		killGold = killGold,
		dropGold = dropGold,
		questGold = questGold,
		potionGold = potionGold,
		upgradeGold = upgradeGold,
	}
end

-- Hunting ground profiles (S33) ----------------------------------------------------------------------------

-- An hour in a hunting ground of `profileId` (nil = none) at the player's level against `kind` (default: the
-- level's usual Meadows kind), Logic/AreaRates.
function Balance.areaRates(classId: string, level: number, profileId: string?, kind: any?): AreaRates.Rates
	local def = if kind == nil
		then Monsters.get(Balance.kindAt(level))
		elseif type(kind) == "string" then Monsters.get(kind)
		else kind
	return AreaRates.rates(Balance.player(classId, level) :: any, def, level, profileId, Balance.SKILL_DPS)
end

-- World model 1-100 (S83) ----------------------------------------------------------------------------------------
-- Next to the S32 functions (which keep computing the 1-20 tables and the fixture): regions, quests on their own
-- level, pace with carried EXP, potions on the S54 interval, the class variety bonus, economy, cave Elites from the
-- real spawners and the bosses with their real attack schedule. Expected values, no randomness.

Balance.REGION_IDS = { "meadows", "duskwood", "ashen", "frostpeak" }
Balance.BANDS = { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 } }

-- Region (1-4) of a character level: below 20 the Meadows, below 45 Duskwood, below 70 the Ashen Wastes.
function Balance.regionAt(level: number): number
	return if level < 20 then 1 elseif level < 45 then 2 elseif level < 70 then 3 else 4
end

local playerCache: { [string]: Player } = {}
-- Balance.player with the default gear, cached (the world model asks for the same players hundreds of times).
function Balance.cachedPlayer(classId: string, level: number): Player
	local key = `{classId}:{level}`
	local p = playerCache[key]
	if not p then
		p = Balance.player(classId, level)
		playerCache[key] = p
	end
	return p
end

local function kindDef(kind: any): any
	return if type(kind) == "string" then Monsters.get(kind) else kind
end

local outdoorCache: { [number]: { string } } = {}
-- Kinds of the hunting grounds of region r (Areas.byMap, no passive kinds), in area order.
function Balance.outdoorKinds(r: number): { string }
	local cached = outdoorCache[r]
	if cached then
		return cached
	end
	local out: { string } = {}
	for _, area in Areas.byMap[Balance.REGION_IDS[r]].areas do
		for _, id in area.kinds do
			local def = Monsters.get(id)
			if def and not def.passive and def.region == r and not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	outdoorCache[r] = out
	return out
end

-- The usual kind of a level: Balance.kindAt (S32) below 20; above, the hunting-ground kind of regionAt(level)
-- whose level range holds the level with its middle closest (diag_economy kindAt); none holds it -> the nearest range.
function Balance.kindAtRegion(level: number): string
	if level < 20 then
		return Balance.kindAt(level)
	end
	local best, bestGap, bestMid = "", math.huge, math.huge
	for _, id in Balance.outdoorKinds(Balance.regionAt(level)) do
		local def = Monsters.get(id) :: any
		local gap = math.max(def.levels.min - level, level - def.levels.max, 0)
		local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
		if gap < bestGap or (gap == bestGap and mid < bestMid) then
			best, bestGap, bestMid = id, gap, mid
		end
	end
	return best
end

export type KindRate = {
	kind: string,
	level: number,
	expPerSecond: number, -- EXP per second of fighting vs GENERIC (Warrior 1 on 1, middle level of the kind)
	hpPerExp: number, -- (HP lost / EXP per kill) / the same of GENERIC at that level, relative to the region mean
	caster: boolean, -- ranged magic attacker
	passive: boolean,
}

-- Every kind of the region (also the cave-only ones), Warrior 1 on 1 at the kind's middle level, no rest.
-- `includePassive` keeps passive kinds (the S32 Meadows check had the rabbit).
function Balance.kindRates(mapId: string, includePassive: boolean?): { KindRate }
	local r = table.find(Balance.REGION_IDS, mapId)
	local out: { KindRate } = {}
	local raw: { number } = {}
	for _, def in Monsters.list do
		if def.region == r and (includePassive or not def.passive) then
			local level = math.floor((def.levels.min + def.levels.max) / 2)
			local p = Balance.cachedPlayer("Warrior", level)
			local own = Balance.duel(p, Balance.monster(def, level))
			local generic = Balance.duel(p, Balance.monster(Balance.GENERIC, level))
			local exp = Balance.killExp(level, def, level)
			local ratio = (exp / own.seconds) / (Balance.killExp(level, Balance.GENERIC, level) / generic.seconds)
			-- HP per EXP against the generic kind of the same level first (EXP grows with the level), then the region mean
			local genericExp = Balance.killExp(level, Balance.GENERIC, level)
			table.insert(raw, (own.hpLost / exp) / math.max(1e-9, generic.hpLost / genericExp))
			table.insert(out, {
				kind = def.id,
				level = level,
				expPerSecond = ratio,
				hpPerExp = 0,
				caster = def.attack == "ranged" and def.damageKind == "magic",
				passive = def.passive == true,
			})
		end
	end
	local sum = 0
	for _, v in raw do
		sum += v
	end
	local mean = sum / math.max(1, #raw)
	for i, row in out do
		row.hpPerExp = raw[i] / mean
	end
	return out
end

-- Quests --------------------------------------------------------------------------------------------------------

export type QuestOpts = { bosses: boolean? }
export type QuestsAt = {
	exp: number, -- main + SIDE_SHARE x side (+ boss quests with opts.bosses)
	gold: number,
	main: number, -- EXP of the main quests without a boss objective
	side: number, -- SIDE_SHARE x EXP of the side quests
	boss: number, -- EXP of the main quests with a boss objective (in `exp` only with opts.bosses)
	bossGold: number,
	daily: number, -- PER_DAY x Daily.reward EXP per day (report only)
	dailyGold: number,
}

local function hasBoss(q: any): boolean
	for _, o in q.objectives do
		if o.type == "boss" then
			return true
		end
	end
	return false
end

-- Quest rewards at their own level (balance plan 4 B3): no spreading over a band, no extrapolation.
function Balance.questsAt(level: number, opts: QuestOpts?): QuestsAt
	local o: QuestOpts = opts or {}
	local main, mainGold, side, sideGold, boss, bossGold = 0, 0, 0, 0, 0, 0
	for _, q in Quests.Main.list :: { any } do
		if q.level == level then
			if hasBoss(q) then
				boss += q.reward.exp or 0
				bossGold += q.reward.gold or 0
			else
				main += q.reward.exp or 0
				mainGold += q.reward.gold or 0
			end
		end
	end
	for _, q in Quests.Side.list :: { any } do
		if q.level == level then
			side += (q.reward.exp or 0) * Balance.SIDE_SHARE
			sideGold += (q.reward.gold or 0) * Balance.SIDE_SHARE
		end
	end
	local daily = Quests.Daily.reward(level)
	local exp, gold = main + side, mainGold + sideGold
	if o.bosses then
		exp += boss
		gold += bossGold
	end
	return {
		exp = exp,
		gold = gold,
		main = main,
		side = side,
		boss = boss,
		bossGold = bossGold,
		daily = Quests.Daily.PER_DAY * (daily.exp or 0),
		dailyGold = Quests.Daily.PER_DAY * (daily.gold or 0),
	}
end

-- Potions -------------------------------------------------------------------------------------------------------

export type Potion = { quality: number, heal: number, price: number, level: number }

local defaultPotions: { Potion }? = nil
-- potion_hp_1..5 (Items): amount, buy price and level.
function Balance.hpPotions(): { Potion }
	if defaultPotions then
		return defaultPotions
	end
	local out: { Potion } = {}
	for q = 1, 5 do
		local def = Items.get(`potion_hp_{q}`) :: any
		table.insert(out, { quality = q, heal = def.use.amount, price = def.buyPrice, level = def.level or 1 })
	end
	defaultPotions = out
	return out
end

local function allowedPotions(level: number, potions: { Potion }?): { Potion }
	local out: { Potion } = {}
	for _, p in potions or Balance.hpPotions() do
		if (p.level or 1) <= level then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.heal < b.heal
	end)
	return out
end

export type PotionUse = { quality: number, drinks: number, gold: number, wait: number }

-- Healing `hpLost` (share of max HP) with potions in `freeSeconds`: out-of-combat regeneration first, then the
-- cheapest allowed quality whose drinks fit (first drink at once, then every Potions.interval), else the biggest
-- with the extra wait (diag_economy potionFight, with the S54 interval and the potion levels).
function Balance.potionsAt(
	classId: string,
	level: number,
	hpLost: number,
	freeSeconds: number,
	potions: { Potion }?
): PotionUse
	local p = Balance.cachedPlayer(classId, level)
	local maxHp = p.values.maxHp
	local need = hpLost * maxHp - Stats.Formula.hpRegenPct / 100 * maxHp * freeSeconds
	local list = allowedPotions(level, potions)
	if need <= 0 or #list == 0 then
		return { quality = 0, drinks = 0, gold = 0, wait = 0 }
	end
	local interval = Potions.interval(level)
	local fits = math.floor(freeSeconds / interval) + 1
	for _, potion in list do
		local drinks = math.ceil(need / potion.heal)
		if drinks <= fits then
			return { quality = potion.quality, drinks = drinks, gold = drinks * potion.price, wait = 0 }
		end
	end
	local big = list[#list]
	local drinks = math.ceil(need / big.heal)
	return { quality = big.quality, drinks = drinks, gold = drinks * big.price, wait = (drinks - fits) * interval }
end

-- HP per second of the best allowed potion at the S54 interval (for the boss model).
function Balance.potionHps(level: number, potions: { Potion }?): number
	local list = allowedPotions(level, potions)
	if #list == 0 then
		return 0
	end
	return list[#list].heal / Potions.interval(level)
end

-- Pace ----------------------------------------------------------------------------------------------------------

export type PaceOpts = {
	kind: any?, -- a Data/Monsters id or a kind table (default kindAtRegion)
	area: "best"?, -- the region's hunting ground with the most EXP/h (Logic/AreaRates with its profile)
	potions: "chain"?, -- potions instead of the rest
	party: { string }?, -- class ids: same ground, credit split, no synergy, x PartyBonus.expMul
	bosses: boolean?, -- boss quests count
	carry: number?, -- EXP carried in from the level before
}

export type PaceAt = {
	kind: string,
	area: string?,
	profile: string?,
	secondsPerKill: number,
	expPerKill: number,
	expPerHour: number,
	kills: number,
	hours: number,
	questExp: number,
	carryOut: number,
	restShare: number,
	potions: PotionUse?, -- per fight (chain)
	goldPerKill: number,
	dropPerKill: number,
	potionGoldPerKill: number,
	hpLostPerFight: number,
	expMul: number,
}

local function areasCovering(level: number): { any }
	local out = {}
	for _, area in Areas.byMap[Balance.REGION_IDS[Balance.regionAt(level)]].areas do
		if level >= area.lv[1] and level <= area.lv[2] then
			table.insert(out, area)
		end
	end
	return out
end

-- An hour in `area` (kinds averaged with equal weight, each at the level clamped to its range in the area).
function Balance.areaHour(classId: string, level: number, area: any): any
	local p = Balance.cachedPlayer(classId, level)
	local n, spk, exp, coin, drop, hp = 0, 0, 0, 0, 0, 0
	for _, id in area.kinds do
		local def = Monsters.get(id) :: any
		local low, high = math.max(area.lv[1], def.levels.min), math.min(area.lv[2], def.levels.max)
		if low > high then
			low, high = area.lv[1], area.lv[2]
		end
		local r = AreaRates.rates(p :: any, def, math.clamp(level, low, high), area.profile, Balance.SKILL_DPS)
		n += 1
		spk += r.secondsPerKill
		exp += r.expPerKill
		coin += r.coinGoldPerHour / r.killsPerHour
		drop += r.dropGoldPerHour / r.killsPerHour
		hp += r.hpLostPerFight
	end
	spk /= n
	return {
		id = area.id,
		profile = area.profile,
		secondsPerKill = spk,
		expPerKill = exp / n,
		expPerHour = exp / n * 3600 / spk,
		coinPerKill = coin / n,
		dropPerKill = drop / n,
		hpLost = hp / n,
	}
end

-- Pace of one level: kills of the level's kind (expected group, rest from regeneration, BREAK + WALK), quests at
-- their own level, the EXP above the level's need carried to the next (opts.carry in, carryOut out).
function Balance.paceAt(classId: string, level: number, opts: PaceOpts?): PaceAt
	local o: PaceOpts = opts or {}
	local kindArg = o.kind or Balance.kindAtRegion(level)
	local def = kindDef(kindArg)
	local kindName = if type(kindArg) == "string" then kindArg else "generic"
	local p = Balance.cachedPlayer(classId, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local free = Balance.BREAK + Balance.WALK
	local fight = Balance.expectedGroup(p, def, level)
	local secondsPerKill, restShare, potionUse, potionGoldPerKill = 0, 0, nil, 0
	if o.potions == "chain" then
		local wait, gold, drinks, quality = 0, 0, 0, 0
		local total = 0
		for n, w in Balance.groupWeights() do
			local use = Balance.potionsAt(classId, level, fight.bySize[n].hpLost, free)
			total += w
			wait += w * use.wait
			gold += w * use.gold
			drinks += w * use.drinks
			quality = math.max(quality, use.quality)
		end
		wait, gold, drinks = wait / total, gold / total, drinks / total
		local perFight = fight.seconds + free + wait
		secondsPerKill = perFight / fight.members
		restShare = wait / perFight
		potionUse = { quality = quality, drinks = drinks, gold = gold, wait = wait }
		potionGoldPerKill = gold / fight.members
	else
		local rest = fight.hpLost / regen
		local perFight = fight.seconds + rest + free
		secondsPerKill = perFight / fight.members
		restShare = rest / perFight
	end
	local expPerKill = Balance.killExp(level, def, level)
	local goldPerKill = Balance.killGold(level, def, level)
	local dropPerKill = Balance.dropValue(level, "normal", if type(kindArg) == "string" then kindArg else nil)
	local areaId, profile = nil, nil
	if o.area == "best" then
		local best = nil
		for _, area in areasCovering(level) do
			local h = Balance.areaHour(classId, level, area)
			if not best or h.expPerHour > best.expPerHour then
				best = h
			end
		end
		if best then
			areaId, profile = best.id, best.profile
			secondsPerKill = best.secondsPerKill
			expPerKill = best.expPerKill
			goldPerKill = best.coinPerKill
			dropPerKill = best.dropPerKill
			local perFight = secondsPerKill * fight.members
			restShare = math.min(1, best.hpLost / regen / perFight)
		end
	end
	local expPerHour = expPerKill * 3600 / secondsPerKill
	local expMul = 1
	if o.party and #o.party > 0 then
		-- same ground, each member kills on its own and the credit is shared: the mean of the solo rates
		local sum = 0
		for _, c in o.party do
			local solo = if c == classId
				then expPerHour
				else Balance.paceAt(c, level, { kind = o.kind, area = o.area }).expPerHour
			sum += solo
		end
		expMul = PartyBonus.expMul(o.party)
		expPerHour = sum / #o.party * expMul
		expPerKill = expPerHour * secondsPerKill / 3600
	end
	local q = Balance.questsAt(level, { bosses = o.bosses })
	local questExp = q.exp + (o.carry or 0)
	local need = Exp.expToNext(level) - questExp
	local carryOut = math.max(0, -need)
	local kills = math.max(0, need) / expPerKill
	return {
		kind = kindName,
		area = areaId,
		profile = profile,
		secondsPerKill = secondsPerKill,
		expPerKill = expPerKill,
		expPerHour = expPerHour,
		kills = kills,
		hours = kills * secondsPerKill / 3600,
		questExp = q.exp,
		carryOut = carryOut,
		restShare = restShare,
		potions = potionUse,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		potionGoldPerKill = potionGoldPerKill,
		hpLostPerFight = fight.hpLost,
		expMul = expMul,
	}
end

-- Levels lo .. hi - 1 one after the other, the quest EXP above a level's need carried to the next.
function Balance.paceBand(
	classId: string,
	lo: number,
	hi: number,
	opts: PaceOpts?
): { hours: number, levels: { PaceAt } }
	local carry = 0
	local hours = 0
	local levels: { PaceAt } = {}
	for level = lo, hi - 1 do
		local o: any = table.clone(opts or {})
		o.carry = carry
		local pace = Balance.paceAt(classId, level, o)
		carry = pace.carryOut
		hours += pace.hours
		table.insert(levels, pace)
	end
	return { hours = hours, levels = levels }
end

-- Economy -------------------------------------------------------------------------------------------------------

-- Potion gold per kill of the S32 rest model (HP lost above POTION_ABOVE healed with the cheapest fitting potion)
-- for any kind and the potions allowed at the level.
function Balance.potionGoldFor(classId: string, level: number, kind: any): number
	local def = kindDef(kind)
	local p = Balance.cachedPlayer(classId, level)
	local fight = Balance.expectedGroup(p, def, level)
	local list = allowedPotions(level)
	local total, gold = 0, 0
	for n, w in Balance.groupWeights() do
		local over = math.max(0, fight.bySize[n].hpLost - Balance.POTION_ABOVE) * p.values.maxHp
		local cost = 0
		if over > 0 then
			local best = math.huge
			for _, potion in list do
				best = math.min(best, math.ceil(over / potion.heal) * potion.price)
			end
			cost = best
		end
		total += w
		gold += w * cost
	end
	return gold / total / fight.members
end

export type EconomyAt = {
	killGold: number, -- per hour
	dropGold: number, -- per hour (merchant value of the drop)
	questGold: number, -- gold of the quests at this level (per level, not per hour: a quest can carry a whole level)
	potionGold: number, -- per hour
	incomePerHour: number, -- kill gold + drop sales per hour
	potionShare: number, -- potion gold / income per hour
	dropToKill: number,
	pace: PaceAt,
}

-- Gold per hour of grinding at the paceAt pace and the quest gold of the level (no upgrades or materials: S84, G9).
function Balance.economyAt(classId: string, level: number, opts: PaceOpts?): EconomyAt
	local o: PaceOpts = opts or {}
	local pace = Balance.paceAt(classId, level, o)
	local perHour = 3600 / pace.secondsPerKill
	local killGold = pace.goldPerKill * perHour
	local dropGold = pace.dropPerKill * perHour
	local questGold = Balance.questsAt(level, { bosses = o.bosses }).gold
	local potionPerKill = if o.potions == "chain"
		then pace.potionGoldPerKill
		else Balance.potionGoldFor(classId, level, o.kind or Balance.kindAtRegion(level))
	local potionGold = potionPerKill * perHour
	local income = killGold + dropGold
	return {
		killGold = killGold,
		dropGold = dropGold,
		questGold = questGold,
		potionGold = potionGold,
		incomePerHour = income,
		potionShare = potionGold / math.max(1e-9, income),
		dropToKill = dropGold / math.max(1e-9, killGold),
		pace = pace,
	}
end

-- Cave Elites ---------------------------------------------------------------------------------------------------

export type EliteFight = {
	level: number,
	classId: string,
	single: Fight,
	pair: Fight,
	encounter: number, -- (1 - q) x single + q x pair HP lost
	pairRatio: number,
}
export type EliteKind = { kind: string, min: number, max: number, fights: { EliteFight } }
export type Elite2Fight = { kind: string, spawner: number, playerLevel: number, byTeam: { Fight } }
export type CaveElites = {
	id: string,
	levels: { number },
	pairShare: number, -- q: Elite spawners with two members / all Elite spawners of the cave (real spawners)
	kinds: { EliteKind },
	elite2: { Elite2Fight },
}

-- The caves of a region from the real spawners (Data/Spawns): single and paired Elites for the four classes at the
-- spawner's min, middle and max level, Elite II for 1-4 players (Balance.team) at min(100, spawner + 2).
function Balance.caveElites(mapId: string): { CaveElites }
	local out: { CaveElites } = {}
	for _, cave in Areas.caves.list do
		if cave.region == mapId then
			local spawners = Spawns.byMap[cave.id] or {}
			local groups, paired = 0, 0
			local rangeOf: { [string]: { min: number, max: number } } = {}
			local elite2Spawner: any = nil
			for _, s in spawners do
				if s.variant == "elite" then
					groups += 1
					paired += if s.count >= 2 then 1 else 0
					rangeOf[s.monster] = rangeOf[s.monster] or s.level
				elseif s.variant == "elite2" then
					elite2Spawner = s
				end
			end
			local q = if groups > 0 then paired / groups else 0
			local kinds: { EliteKind } = {}
			for _, kind in cave.elites do
				local range = rangeOf[kind]
				if range then
					local def = Monsters.get(kind) :: any
					local fights: { EliteFight } = {}
					local levels = { range.min, math.floor((range.min + range.max) / 2), range.max }
					for i, L in levels do
						if i == 1 or L ~= levels[i - 1] then
							for _, c in Balance.CLASSES do
								local p = Balance.cachedPlayer(c, math.min(100, L))
								local single = Balance.elite(p, def, L)
								local pair = Balance.groupFight(p, FightSim.group(def, L, 2, "elite"))
								table.insert(fights, {
									level = L,
									classId = c,
									single = single,
									pair = pair,
									encounter = (1 - q) * single.hpLost + q * pair.hpLost,
									pairRatio = pair.hpLost / math.max(1e-9, single.hpLost),
								})
							end
						end
					end
					table.insert(kinds, { kind = kind, min = range.min, max = range.max, fights = fights })
				end
			end
			local elite2: { Elite2Fight } = {}
			if elite2Spawner then
				for _, kind in elite2Spawner.choices or { elite2Spawner.monster } do
					for _, L in { elite2Spawner.level.min, elite2Spawner.level.max } do
						local pl = math.min(100, L + 2)
						local byTeam: { Fight } = {}
						for n = 1, 4 do
							local team = {}
							for i = 1, n do
								table.insert(team, Balance.cachedPlayer(Balance.ORDER[i], pl))
							end
							byTeam[n] = Balance.elite2(team, kind, L)
						end
						table.insert(elite2, { kind = kind, spawner = L, playerLevel = pl, byTeam = byTeam })
					end
				end
			end
			table.insert(out, { id = cave.id, levels = cave.levels, pairShare = q, kinds = kinds, elite2 = elite2 })
		end
	end
	return out
end

-- Boss model (S83) ----------------------------------------------------------------------------------------------

-- Mirror of `local GLOBAL_GAP` in src/server/Entities/Boss.luau (seconds after an attack's windup before the next
-- attack of any kind); balancemodel.spec checks the server text.
Balance.BOSS_GLOBAL_GAP = 2.2

-- Scripted boss hazards (server BossScripts, multiplier of the boss attack like CombatService): Azgor's lava
-- outside the shrinking safe circle, Vaelgrath's storm away from the braziers. Checked as text by balancemodel.spec.
Balance.HAZARDS = {
	azgor = { phase = 3, damage = 0.7, every = 1, damageKind = "magic" },
	vaelgrath = { phase = 3, damage = 1.4, every = 3, damageKind = "magic" },
} :: { [string]: { phase: number, damage: number, every: number, damageKind: string } }

-- Numeric "local NAME = 12.5" lines of a server boss script, read as text (the scripts need Roblox; same rule as
-- tools/WikiData/Bosses.scriptConsts).
function Balance.bossScriptConsts(bossId: string): { [string]: number }
	local out: { [string]: number } = {}
	local path = `src/server/Entities/BossScripts/{bossId}.luau`
	if not fs.isFile(path) then
		return out
	end
	for line in string.gmatch(fs.readFile(path), "[^\r\n]+") do
		local key, value = string.match(line, "^local ([A-Z_]+) = ([%d%.]+)$")
		if key and value and tonumber(value) then
			out[key] = tonumber(value) :: number
		end
	end
	return out
end

export type CadenceState = { nextAttack: { [string]: number }, nextGlobal: number, phase: number }
export type CadenceOpts = {
	step: number?, -- 0.05 s
	seconds: number?, -- 600 s in one phase
	globalStart: number?, -- 4 s (Boss.new: nextGlobal = now + 4)
	firstUse: number?, -- 5 s (mean of 3 + U(0, 4))
	gap: number?, -- BOSS_GLOBAL_GAP
	pick: ((ready: { any }, t: number, state: CadenceState) -> any?)?, -- default: first ready in list order
}
export type Cadence = { perMinute: { [string]: number }, rateShare: { [string]: number }, casting: number }

-- Attack schedule of `def` in `phase` (Entities/Boss.Step at a fixed step): when t >= nextGlobal, the first attack
-- of the phase whose cooldown is over (list order), or opts.pick's choice among the ready ones (S87 plugs
-- Logic/BossSchedule in here); then nextAttack = t + cooldown and nextGlobal = t + windup + gap.
-- rateShare = uses per minute / (60 / cooldown); casting = time spent winding up / time.
function Balance.bossCadence(def: any, phase: number, opts: CadenceOpts?): Cadence
	local o: CadenceOpts = opts or {}
	local step = o.step or 0.05
	local seconds = o.seconds or 600
	local gap = o.gap or Balance.BOSS_GLOBAL_GAP
	local attacks = {}
	local state: CadenceState = { nextAttack = {}, nextGlobal = o.globalStart or 4, phase = phase }
	local counts: { [string]: number } = {}
	for _, attack in def.attacks do
		if table.find(attack.phases, phase) then
			table.insert(attacks, attack)
			state.nextAttack[attack.id] = o.firstUse or 5
			counts[attack.id] = 0
		end
	end
	local casting = 0
	local steps = math.floor(seconds / step + 0.5)
	for i = 0, steps - 1 do
		local t = i * step
		if t >= state.nextGlobal then
			local chosen = nil
			if o.pick then
				local ready = {}
				for _, attack in attacks do
					if t >= state.nextAttack[attack.id] then
						table.insert(ready, attack)
					end
				end
				if #ready > 0 then
					chosen = o.pick(ready, t, state)
				end
			else
				for _, attack in attacks do
					if t >= state.nextAttack[attack.id] then
						chosen = attack
						break
					end
				end
			end
			if chosen then
				state.nextAttack[chosen.id] = t + chosen.cooldown
				state.nextGlobal = t + chosen.windup + gap
				counts[chosen.id] += 1
				casting += chosen.windup
			end
		end
	end
	local perMinute: { [string]: number } = {}
	local rateShare: { [string]: number } = {}
	for _, attack in attacks do
		perMinute[attack.id] = counts[attack.id] / (seconds / 60)
		rateShare[attack.id] = perMinute[attack.id] / (60 / attack.cooldown)
	end
	return { perMinute = perMinute, rateShare = rateShare, casting = math.min(1, casting / seconds) }
end

-- Kind table of a boss for a party of `players` (Entities/Boss kindFor).
function Balance.bossKind(def: any, players: number): any
	return {
		hpMul = BossScaling.hpMultiplier(players) * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul,
		family = def.family,
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}
end

-- Melee classes stand next to the boss (in a ring attack's safe centre, under a self circle); the others stand off.
Balance.MELEE = { Warrior = true, Cleric = true } :: { [string]: boolean }

export type BossPhase = {
	share: number, -- share of the boss HP
	seconds: number, -- boss vulnerable and fighting
	shieldSeconds: number, -- shield waves (boss invulnerable, holds still, no attacks)
	flightSeconds: number, -- extra invulnerable seconds while attacking (Vaelgrath phase 2)
	casts: number, -- special attacks cast
	tankDps: number, -- boss damage per second on the tank (basic + specials, enrage)
	raidDps: number, -- boss damage per second on the other players together
}
export type BossOpts = {
	specialHit: number?, -- share of telegraphed attacks that land (SPECIAL_HIT)
	hazardShare: number?, -- share of the hazard ticks taken (0: players stand safe)
	cadence: CadenceOpts?,
}
export type BossFight = {
	hp: number,
	dps: number, -- team damage per second on the boss (x BOSS_UPTIME)
	seconds: number,
	phases: { BossPhase },
	enraged: boolean,
	enrageAt: number?,
	biggestHit: { [string]: number }, -- biggest single hit (x Combat.randomMax) / max HP of the class
	tankDps: number,
	potionHps: number,
	shieldTankHp: number, -- HP the tank loses to the helpers of all shield waves (share of max HP)
	hazards: { phase: number, perTick: { [string]: number }, hps: { [string]: number }, every: number }?,
}

-- Boss fight of `team` (team[1] is the tank): HP and armour as Balance.boss, phases by HP (def.phases), the real
-- schedule per phase (bossCadence), damage per attack and kind on its targets (threat / nearest -> tank, self
-- circle -> melee, self ring -> ranged, random -> min(count, n) / n each, all -> everyone) x specialHit, the basic
-- attack on the tank every attackInterval / haste outside the casting share, enrage after enrageAfter (x
-- enrageDamage on everything), shield waves (count + SUMMON_PER_PLAYER x (n - 1) helpers killed by the team while
-- they hit the tank), Vaelgrath's flight in phase 2 and the scripted hazards.
function Balance.bossFight(bossId: string, team: { Player }, opts: BossOpts?): BossFight
	local o: BossOpts = opts or {}
	local def = Bosses.byId[bossId] :: any
	local n = #team
	local specialHit = o.specialHit or Balance.SPECIAL_HIT
	local m = Balance.monster(Balance.bossKind(def, n), def.level, "boss")
	local dps = 0
	for _, p in team do
		dps += Balance.dps(p, m) * Balance.BOSS_UPTIME
	end
	local tank = team[1]
	local thresholds = { 1 }
	for _, t in def.phases do
		table.insert(thresholds, t)
	end
	table.insert(thresholds, 0)
	local flight = if bossId == "vaelgrath" then Balance.bossScriptConsts("vaelgrath").FLIGHT_SECONDS or 0 else 0
	local elapsed = 0
	local enrageAt: number? = nil
	local phases: { BossPhase } = {}
	local tankTotal, fightingTotal, shieldTankHp = 0, 0, 0
	local biggest: { [string]: number } = {}
	for phase = 1, #thresholds - 1 do
		local share = thresholds[phase] - thresholds[phase + 1]
		-- shield waves at the phase start (and every `every` s of the phase)
		local fighting = share * m.maxHp / dps
		local shieldSeconds = 0
		for _, summon in def.summons do
			if summon.phase == phase and summon.shield then
				local count = summon.count + Bosses.SUMMON_PER_PLAYER * (n - 1)
				local waves = 1 + (if summon.every then math.floor(fighting / summon.every) else 0)
				local helperDef = Monsters.get(summon.monster) :: any
				local members = FightSim.group(helperDef, summon.level, count)
				local lost = 0
				for k, member in members do
					local teamDps = 0
					for _, p in team do
						teamDps += Balance.dps(p, member)
					end
					local duration = member.maxHp / math.max(1e-6, teamDps)
					shieldSeconds += duration * waves
					for j = k, #members do
						lost += Balance.hit(members[j], tank) * duration / members[j].attackInterval
					end
				end
				shieldTankHp += lost * waves / tank.values.maxHp
			end
		end
		-- Vaelgrath (phase 2): FLIGHT_SECONDS invulnerable from the phase start, overlapping the shield wave; past
		-- the wave it attacks while nobody can hit it
		local flightSeconds = if phase == 2 then math.max(0, flight - shieldSeconds) else 0
		local active = fighting + flightSeconds
		local cad = Balance.bossCadence(def, phase, o.cadence)
		local haste = (def.haste or {})[phase] or 1
		local startActive = elapsed + shieldSeconds
		-- enrage: the share of this phase's active time past enrageAfter
		local enragedShare = 0
		if startActive + active > def.enrageAfter then
			enragedShare = math.clamp((startActive + active - def.enrageAfter) / active, 0, 1)
			enrageAt = enrageAt or def.enrageAfter
		end
		local dmgMul = 1 + (def.enrageDamage - 1) * enragedShare
		local tankPerSecond = Balance.hit(m, tank) * haste / m.attackInterval * (1 - cad.casting)
		local raidPerSecond = 0
		local casts = 0
		for _, attack in def.attacks do
			local perMinute = cad.perMinute[attack.id]
			if perMinute and perMinute > 0 then
				casts += perMinute * active / 60
				local kind = attack.damageKind or def.damageKind
				for i, p in team do
					local share: number = 0
					if attack.target == "threat" or attack.target == "nearest" then
						share = if i == 1 then 1 else 0
					elseif attack.target == "self" then
						local melee = Balance.MELEE[p.classId] == true
						share = if attack.shape == "ring" then (if melee then 0 else 1) else (if melee then 1 else 0)
					elseif attack.target == "random" then
						share = math.min(attack.count or 1, n) / n
					else -- all
						share = 1
					end
					if share > 0 then
						local hit = Balance.hit(m, p, attack.damage, kind, false)
						local perSecond = hit * specialHit * share * perMinute / 60
						if i == 1 then
							tankPerSecond += perSecond
						else
							raidPerSecond += perSecond
						end
						local top = hit * Combat.randomMax / p.values.maxHp
						biggest[p.classId] = math.max(biggest[p.classId] or 0, top)
					end
				end
			end
		end
		tankPerSecond *= dmgMul
		raidPerSecond *= dmgMul
		tankTotal += tankPerSecond * active
		fightingTotal += active
		elapsed += shieldSeconds + active
		table.insert(phases, {
			share = share,
			seconds = active,
			shieldSeconds = shieldSeconds,
			flightSeconds = flightSeconds,
			casts = casts,
			tankDps = tankPerSecond,
			raidDps = raidPerSecond,
		})
	end
	local hazards = nil
	local hazard = Balance.HAZARDS[bossId]
	if hazard then
		local perTick: { [string]: number } = {}
		local hps: { [string]: number } = {}
		for _, p in team do
			local hit = Balance.hit(m, p, hazard.damage, hazard.damageKind, false)
			perTick[p.classId] = hit / p.values.maxHp
			hps[p.classId] = hit / hazard.every
		end
		hazards = { phase = hazard.phase, perTick = perTick, hps = hps, every = hazard.every }
		local share = o.hazardShare or 0
		if share > 0 then
			local ph = phases[hazard.phase]
			local extra = Balance.hit(m, tank, hazard.damage, hazard.damageKind, false) / hazard.every * share
			ph.tankDps += extra
			tankTotal += extra * ph.seconds
			for i = 2, n do
				local p = team[i]
				ph.raidDps += Balance.hit(m, p, hazard.damage, hazard.damageKind, false) / hazard.every * share
			end
		end
	end
	return {
		hp = m.maxHp,
		dps = dps,
		seconds = elapsed,
		phases = phases,
		enraged = enrageAt ~= nil,
		enrageAt = enrageAt,
		biggestHit = biggest,
		tankDps = tankTotal / math.max(1e-9, fightingTotal),
		potionHps = Balance.potionHps(def.level),
		shieldTankHp = shieldTankHp,
		hazards = hazards,
	}
end

-- A party of `n` players of `level` in the order of the S32 Grimrok check (diag_hard `team`).
Balance.ORDER = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
function Balance.team(n: number, level: number): { Player }
	local out = {}
	for i = 1, n do
		table.insert(out, Balance.player(Balance.ORDER[(i - 1) % #Balance.ORDER + 1], level))
	end
	return out
end

-- S32 targets in one place (S83) ---------------------------------------------------------------------------------

-- One measured number against its band (`low` / `high` missing = a one-sided target; both inclusive).
export type TargetRow = {
	id: string,
	group: string,
	label: string,
	value: number,
	low: number?,
	high: number?,
	classId: string?,
	level: number?,
	report: string?, -- the session that asserts it (a row with `report` never asserts in its block)
}

function Balance.inBand(row: TargetRow): boolean
	local v = row.value
	if v ~= v then
		return false
	end
	return (row.low == nil or v >= row.low) and (row.high == nil or v <= row.high)
end

-- Highest weapon merchant tier at or below `level` (the starting weapon below the first tier).
function Balance.shopTier(level: number): number
	local best = 1
	for _, tier in Shops.WEAPONSMITH_TIERS do
		if tier <= level then
			best = tier
		end
	end
	return best
end

Balance.LEVELS_1_20 = { 1, 2, 5, 10, 15, 18, 20 }
Balance.MAIN = { "Warrior", "Hunter", "Mage" }
-- S32 Elite II checks: kind and spawner level (the top of its cave, as S32 took it).
Balance.ELITE2_1_20 = { { "bandit", 12 }, { "goblinScout", 16 }, { "caveSpider", 18 }, { "goblinShaman", 18 } }

local function target(
	rows: { TargetRow },
	id: string,
	group: string,
	label: string,
	value: number,
	low: number?,
	high: number?,
	classId: string?,
	level: number?
)
	table.insert(rows, {
		id = id,
		group = group,
		label = label,
		value = value,
		low = low,
		high = high,
		classId = classId,
		level = level,
	})
end

-- The numeric targets of the S32 blocks of balance.spec (thresholds as of the start of S83, incl. S64 / S66).
function Balance.targets1_20(): { TargetRow }
	local rows: { TargetRow } = {}
	-- One monster and groups
	for _, c in Balance.CLASSES do
		for _, L in Balance.LEVELS_1_20 do
			local f = Balance.duel(Balance.player(c, L), Balance.monster(Balance.GENERIC, L))
			local id = `S32.duel.{c}.{L}`
			if L >= 2 then
				-- Clerics fight slower but take less damage (S18 band); S66: the Mage's level 2 duel ~5.49 s.
				local slow = if c == "Cleric" then 11 else 10
				local low = if c == "Cleric" then 0.09 else 0.1
				local fast = if c == "Mage" and L == 2 then 5.4 else 5.5
				target(rows, `{id}.seconds`, "duel", `{c} {L}: 1 na 1 s`, f.seconds, fast, slow, c, L)
				target(rows, `{id}.hp`, "duel", `{c} {L}: 1 na 1 HP`, f.hpLost, low, 0.25, c, L)
			else
				-- Level 1 is a gentle start (S32: below 15 %).
				target(rows, `{id}.hp`, "duel", `{c} 1: łagodny start HP`, f.hpLost, nil, 0.15 - 1e-9, c, L)
			end
			local g = Balance.expectedGroup(Balance.player(c, L), Balance.GENERIC, L)
			local gid = `S32.group.{c}.{L}`
			if L >= 5 then
				local high = if c == "Mage" then 0.7 else 0.6
				local low = if c == "Cleric" then 0.3 else 0.35
				target(rows, `{gid}.hp`, "group", `{c} {L}: grupa średnio HP`, g.hpLost, low, high, c, L)
			end
			target(rows, `{gid}.size4`, "group", `{c} {L}: grupa 4 HP`, g.bySize[4].hpLost, nil, 1.1, c, L)
		end
	end
	do
		local skill = Balance.SKILL_DPS
		Balance.SKILL_DPS = 1
		for _, c in Balance.CLASSES do
			for _, L in { 3, 5, 6 } do
				local f = Balance.groupFight(Balance.player(c, L), Balance.group("wolf", L, 3))
				target(rows, `S32.wolves.{c}.{L}`, "wolves", `{c} {L}: trzy wilki HP`, f.hpLost, 0.4, 0.95, c, L)
			end
		end
		Balance.SKILL_DPS = skill
	end
	for _, c in Balance.CLASSES do
		for L = 2, 20 do
			local p = Balance.player(c, L, { ilvl = Items.generate.tierFor(L), weaponIlvl = Balance.shopTier(L) })
			local f = Balance.duel(p, Balance.monster(Balance.GENERIC, L))
			-- Clerics are slow on purpose (and lose the least HP).
			local slow = if c == "Cleric" then 20 else 15.5
			target(rows, `S32.shop.{c}.{L}.seconds`, "shop", `{c} {L}: sprzęt ze sklepu s`, f.seconds, nil, slow, c, L)
			target(rows, `S32.shop.{c}.{L}.hp`, "shop", `{c} {L}: sprzęt ze sklepu HP`, f.hpLost, nil, 0.36, c, L)
		end
	end
	-- Elites, Elite II, Grimrok
	for _, c in Balance.MAIN do
		for _, L in { 10, 15, 18, 20 } do
			local f = Balance.elite(Balance.player(c, L), Balance.GENERIC, L)
			target(rows, `S32.elite.{c}.{L}.seconds`, "elite", `{c} {L}: Elita s`, f.seconds, 20, 36, c, L)
			target(rows, `S32.elite.{c}.{L}.hp`, "elite", `{c} {L}: Elita HP`, f.hpLost, 0.55, 0.95, c, L)
		end
	end
	for _, spec in Balance.ELITE2_1_20 do
		local kind, spawner = spec[1] :: string, spec[2] :: number
		local L = math.min(20, spawner + 2)
		local w, m, h = Balance.player("Warrior", L), Balance.player("Mage", L), Balance.player("Hunter", L)
		local id = `S32.elite2.{kind}.{spawner}`
		local label = `{kind} {spawner}`
		target(
			rows,
			`{id}.solo`,
			"elite2",
			`{label}: solo HP`,
			Balance.elite2({ w }, kind, spawner).hpLost,
			1.5 + 1e-9,
			nil,
			nil,
			L
		)
		local duo = Balance.elite2({ w, m }, kind, spawner).hpLost
		target(rows, `{id}.duo`, "elite2", `{label}: 2 graczy HP`, duo, nil, 1.5, nil, L)
		local trio = Balance.elite2({ w, m, h }, kind, spawner).hpLost
		target(rows, `{id}.trio`, "elite2", `{label}: 3 graczy HP`, trio, nil, 1.0, nil, L)
	end
	for n = 3, 5 do
		local minutes = Balance.boss("grimrok", Balance.team(n, 19)).seconds / 60
		target(rows, `S32.grimrok.team{n}.minutes`, "grimrok", `Grimrok, {n} graczy L19: min`, minutes, 4, 6, nil, 19)
	end
	do
		local mage = Balance.boss("grimrok", { Balance.player("Mage", 20) }).biggest[1].share
		target(
			rows,
			"S32.grimrok.mage20.biggest",
			"grimrok",
			"Grimrok: największy cios / HP Maga L20",
			mage,
			nil,
			0.7,
			"Mage",
			20
		)
		-- A level 18 Mage survives one hit too (S32: below 1).
		local mage18 = Balance.boss("grimrok", { Balance.player("Mage", 18) }).biggest[1].share
		target(
			rows,
			"S32.grimrok.mage18.biggest",
			"grimrok",
			"Grimrok: największy cios / HP Maga L18",
			mage18,
			nil,
			1 - 1e-9,
			"Mage",
			18
		)
	end
	-- Items
	for _, c in Balance.CLASSES do
		for _, L in { 5, 10, 20 } do
			local id = `S32.rarity.{c}.{L}`
			local legendary = Balance.rarityGain(c, L, Rarities.LEGENDARY)
			local unique = Balance.rarityGain(c, L, Rarities.UNIQUE)
			local heroic = Balance.rarityGain(c, L, Rarities.HEROIC)
			local mythic = Balance.rarityGain(c, L, Rarities.MYTHIC)
			target(rows, `{id}.unique`, "rarity", `{c} {L}: Unikatowy`, unique, 0.07, 0.15, c, L)
			-- FIX 2026-10-09: Heroic always rolls 3 bonuses (was 2-3), up to ~25.1 %
			target(rows, `{id}.heroic`, "rarity", `{c} {L}: Heroiczny`, heroic, 0.15, 0.26, c, L)
			target(rows, `{id}.legendary`, "rarity", `{c} {L}: Legendarny`, legendary, 0.25, 0.42, c, L)
			-- Mythic beats Legendary: Mythic - Legendary strictly above 0.
			target(
				rows,
				`{id}.mythic`,
				"rarity",
				`{c} {L}: Mityczny − Legendarny`,
				mythic - legendary,
				1e-9,
				nil,
				c,
				L
			)
		end
	end
	local twoHanded = {
		{ "Warrior", { "sword2h", "axe2h", "hammer2h", "spear2h" } },
		{ "Mage", { "staff", "runestaff" } },
		{ "Cleric", { "holystaff" } },
	}
	for _, case in twoHanded do
		local c = case[1] :: string
		for _, L in { 5, 10, 20 } do
			local base = Balance.power(Balance.player(c, L)) ^ 2
			for _, weapon in case[2] :: { string } do
				local score = Balance.power(Balance.player(c, L, { weapon = weapon, offhand = false })) ^ 2
				-- S64: the shield's Parry and the protection lines pull 1H + shield ahead (lower bound 0.97 -> 0.93).
				local id = `S32.twohand.{c}.{weapon}.{L}`
				target(rows, id, "twohand", `{c} {weapon} {L}: moc² / 1H`, score / base, 0.93, 1.035, c, L)
			end
		end
	end
	do
		local cleaver = Balance.playerFromItems("Warrior", 20, {
			{
				uid = "c",
				id = "unique_grimrok_cleaver",
				rarity = 5,
				ilvl = 20,
				bonuses = {},
				up = 0,
				bound = false,
				n = 1,
			},
		})
		local legendary = Balance.player("Warrior", 20, {
			ilvl = 20,
			weapon = "axe1h",
			rarity = Rarities.LEGENDARY,
			offhand = false,
			armor = false,
			jewellery = false,
		})
		local m = Balance.monster(Balance.GENERIC, 20)
		-- Grimrok's Mythic cleaver beats a Legendary axe of level 20 (ratio strictly above 1).
		local ratio = Balance.dps(cleaver, m) / Balance.dps(legendary, m)
		target(
			rows,
			"S32.cleaver.dps",
			"cleaver",
			"Tasak Grimroka / Legendarny topór L20 (DPS)",
			ratio,
			1 + 1e-9,
			nil,
			"Warrior",
			20
		)
	end
	do
		local armour = (Items.bases.byType.armor_light.stats :: any)(20)
		local talisman = (Items.bases.byType.talisman.stats :: any)(20)
		target(rows, "S32.jewellery.lightArmourHp", "jewellery", "Lekka zbroja L20: HP", armour.hp, 1e-9, nil, nil, 20)
		target(rows, "S32.jewellery.talismanHp", "jewellery", "Talizman L20: HP", talisman.hp, 1e-9, nil, nil, 20)
		target(
			rows,
			"S32.jewellery.talismanArmor",
			"jewellery",
			"Talizman L20: pancerz",
			talisman.armor,
			1e-9,
			nil,
			nil,
			20
		)
		for _, c in Balance.CLASSES do
			local with = Balance.power(Balance.player(c, 20))
			local without = Balance.power(Balance.player(c, 20, { jewellery = false }))
			target(
				rows,
				`S32.jewellery.{c}`,
				"jewellery",
				`{c} 20: biżuteria (moc)`,
				with / without - 1,
				0.08,
				0.3,
				c,
				20
			)
		end
	end
	-- Drops, rewards, gold
	for _, L in { 10, 15, 18 } do
		local pace = Balance.pace("Warrior", L)
		local uniques = (pace.kills + Balance.questKills(L)) * Balance.itemsPerKill("normal", Rarities.UNIQUE)
		local heroic = 3600 / Balance.eliteCadence("Warrior", L) * Balance.itemsPerKill("elite", Rarities.HEROIC)
		target(
			rows,
			`S32.drops.unique.{L}`,
			"drops",
			`{L}: Unikatowe do klasy na poziom`,
			uniques,
			0.5,
			1.6,
			"Warrior",
			L
		)
		target(
			rows,
			`S32.drops.heroic.{L}`,
			"drops",
			`{L}: Heroiczne do klasy na godzinę`,
			heroic,
			0.5,
			1.5,
			"Warrior",
			L
		)
	end
	do
		local bear = MonsterStats.kindReward(Monsters.get("brownBear") :: any)
		local rabbit = MonsterStats.kindReward(Monsters.get("rabbit") :: any)
		target(
			rows,
			"S32.kinds.brownBear",
			"kinds",
			"Niedźwiedź brunatny: mnożnik nagrody (> 1,1)",
			bear,
			1.1 + 1e-9
		)
		target(rows, "S32.kinds.rabbit", "kinds", "Królik: mnożnik nagrody (< 0,7)", rabbit, nil, 0.7 - 1e-9)
	end
	for _, def in Monsters.list do
		if def.region == 1 then
			local L = math.floor((def.levels.min + def.levels.max) / 2)
			local p = Balance.player("Warrior", L)
			local own = Balance.killExp(L, def, L) / Balance.duel(p, Balance.monster(def, L)).seconds
			local generic = Balance.killExp(L, Balance.GENERIC, L)
				/ Balance.duel(p, Balance.monster(Balance.GENERIC, L)).seconds
			target(
				rows,
				`S32.kinds.{def.id}`,
				"kinds",
				`{def.id}: EXP/s ÷ zwykły`,
				own / generic,
				0.85,
				1.2,
				"Warrior",
				L
			)
		end
	end
	for _, c in Balance.CLASSES do
		local eco = Balance.economy(c, 20)
		for _, r in eco.rows do
			if r.level >= 4 then
				local id = `S32.economy.{c}.{r.level}.up3`
				target(
					rows,
					id,
					"economy",
					`{c} {r.level}: +1…+3 broni / dochód poziomu`,
					r.up3 / r.income,
					nil,
					1.05,
					c,
					r.level
				)
			end
		end
		local income = eco.killGold + eco.dropGold + eco.questGold
		target(
			rows,
			`S32.economy.{c}.potions`,
			"economy",
			`{c}: mikstury / dochód 1→20`,
			eco.potionGold / income,
			nil,
			0.15,
			c
		)
		local drops = eco.dropGold / eco.killGold
		target(rows, `S32.economy.{c}.drops`, "economy", `{c}: sprzedaż dropu / złoto z zabić`, drops, 0.3, 0.55, c)
	end
	return rows
end

-- Targets 20-100 (S83, balance plan 2.5) ------------------------------------------------------------------------

Balance.GLOBAL_LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
-- D4 (preliminary, the owner's decision is open): hours of the bands 20-45 / 45-70 / 70-100, tolerance +-25 %.
Balance.BAND_HOURS = { { 20, 45, 14 }, { 45, 70, 25 }, { 70, 100, 41 } }
Balance.BAND_HOURS_TOLERANCE = 0.25

local function shopPlayer(classId: string, level: number): Player
	return Balance.player(
		classId,
		level,
		{ ilvl = Items.generate.tierFor(level), weaponIlvl = Balance.shopTier(level) }
	)
end

-- Rows G1-G6 and G11-G13 in the S32 convention (G7-G9 come with S84, G10 with S85-S86). Asserted by balance.spec
-- from S87 (GLOBAL_ASSERT); rows with `report` stay a report (G12 until S91: balance1_20.spec asserts the fixture).
function Balance.targetsGlobal(): { TargetRow }
	local rows: { TargetRow } = {}
	local function add(id: string, label: string, value: number, low: number?, high: number?, c: string?, L: number?)
		table.insert(rows, {
			id = id,
			group = string.match(id, "^(G%d+)") or id,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = c,
			level = L,
		})
	end
	for _, L in Balance.GLOBAL_LEVELS do
		local duelSeconds: { number } = {}
		for _, c in Balance.CLASSES do
			local p = Balance.cachedPlayer(c, L)
			local generic = Balance.monster(Balance.GENERIC, L)
			-- G1: one monster of the level 6-10 s (test 5.5-10), Cleric up to 12 s; 12-25 % HP (test from 10 %), Cleric from 9 %
			local duel = Balance.duel(p, generic)
			table.insert(duelSeconds, duel.seconds)
			add("G1.s", `{c} {L}: 1 na 1 s`, duel.seconds, 5.5, if c == "Cleric" then 12 else 10, c, L)
			add("G1.hp", `{c} {L}: 1 na 1 HP`, duel.hpLost, if c == "Cleric" then 0.09 else 0.1, 0.25, c, L)
			-- G2: an average group 35-60 % (Mage up to 70 %, Cleric from 30 %), a group of 4 up to 110 %
			local g = Balance.expectedGroup(p, Balance.GENERIC, L)
			add(
				"G2.avg",
				`{c} {L}: grupa średnio HP`,
				g.hpLost,
				if c == "Cleric" then 0.3 else 0.35,
				if c == "Mage" then 0.7 else 0.6,
				c,
				L
			)
			add("G2.size4", `{c} {L}: grupa 4 HP`, g.bySize[4].hpLost, nil, 1.1, c, L)
			-- G3: three monsters of the level without skills 40-95 %
			local skill = Balance.SKILL_DPS
			Balance.SKILL_DPS = 1
			local three = Balance.groupFight(p, Balance.group(Balance.GENERIC, L, 3))
			Balance.SKILL_DPS = skill
			add("G3", `{c} {L}: trzy potwory bez umiejętności HP`, three.hpLost, 0.4, 0.95, c, L)
			-- G4: shop gear (up to 9 levels too low): up to 15.5 s (Cleric 20), up to 36 % HP
			local shop = Balance.duel(shopPlayer(c, L), generic)
			add("G4.s", `{c} {L}: sprzęt ze sklepu s`, shop.seconds, nil, if c == "Cleric" then 20 else 15.5, c, L)
			add("G4.hp", `{c} {L}: sprzęt ze sklepu HP`, shop.hpLost, nil, 0.36, c, L)
		end
		-- G5: Hunter / Warrior DPS 1.15-1.35, power 0.95-1.10
		local w, h = Balance.cachedPlayer("Warrior", L), Balance.cachedPlayer("Hunter", L)
		local m = Balance.monster(Balance.GENERIC, L)
		add("G5.dps", `{L}: DPS Łowca / Wojownik`, Balance.dps(h, m) / Balance.dps(w, m), 1.15, 1.35, "Hunter", L)
		add("G5.power", `{L}: moc Łowca / Wojownik`, Balance.power(h) / Balance.power(w), 0.95, 1.1, "Hunter", L)
		-- G6: slowest / fastest class 1 on 1 up to 2.2
		local lo, hi = math.huge, 0
		for _, s in duelSeconds do
			lo, hi = math.min(lo, s), math.max(hi, s)
		end
		add("G6", `{L}: rozrzut czasu 1 na 1 (najwolniejsza / najszybsza)`, hi / lo, nil, 2.2, nil, L)
	end
	-- G11: every attack of every phase of the four bosses at least 50 % of its cooldown rate
	for _, def in Bosses.list do
		for phase = 1, #def.phases + 1 do
			local cad = Balance.bossCadence(def, phase)
			for _, attack in def.attacks do
				local share = cad.rateShare[attack.id]
				if share then
					add(
						"G11",
						`{def.id} faza {phase}: {attack.id} (tempo / odnowienie)`,
						share,
						0.5,
						nil,
						nil,
						def.level
					)
				end
			end
		end
	end
	-- G12: the 1-20 fixture (report until S91; balance1_20.spec asserts it with its allowed list)
	do
		local fixture = require("./BalanceTables").fixtureDiff()
		table.insert(rows, {
			id = "G12",
			group = "G12",
			label = "1–20: różnice wobec fixture (bez listy dozwolonych)",
			value = #fixture.diffs + #fixture.missing,
			high = 0,
			report = "S91",
		})
	end
	-- G13 (preliminary): grind hours per level of the generic kind (without quests: a main quest can pay the whole
	-- level) rise over 25-100; band hours (with quests and carry) within D4 +-25 %
	do
		local falls, last = 0, -math.huge
		for L = 25, 99 do
			local pace = Balance.paceAt("Warrior", L, { kind = Balance.GENERIC })
			local hours = Exp.expToNext(L) / pace.expPerKill * pace.secondsPerKill / 3600
			if hours < last then
				falls += 1
			end
			last = hours
		end
		add("G13.rise", "25–99: spadki h/poziom rodzaju ogólnego bez zadań (Wojownik)", falls, nil, 0)
		for _, band in Balance.BAND_HOURS do
			local hours = Balance.paceBand("Warrior", band[1], band[2]).hours
			local t = Balance.BAND_HOURS_TOLERANCE
			add(
				`G13.band`,
				`{band[1]}–{band[2]}: godzin (cel D4 {band[3]} h)`,
				hours,
				band[3] * (1 - t),
				band[3] * (1 + t),
				"Warrior",
				band[1]
			)
		end
	end
	return rows
end

-- Regions (S83): TUNED[mapId] = true once its region session asserts it (S91 Meadows 1-20 in full, S92-S94 the
-- rest); read by balance.spec ("Balance 20-100: regions") and the report. Starting thresholds of the balance plan;
-- region sessions may tune them with a line in DECYZJE.
Balance.TUNED = { meadows = true, duskwood = false, ashen = false, frostpeak = false } :: { [string]: boolean }
Balance.REGION_TARGETS = {
	eliteSingle = { seconds = { 20, 36 }, hp = { 0.55, 0.95 }, shareInBand = 26 / 36, hpFloor = 0.45, hpCeil = 1.10 },
	eliteEncounter = { Warrior = 1.10, Mage = 1.25 }, -- (1 - q) * single + q * pair, q from caveElites
	-- solo at least, duo at most, trio within (the S32 reading: solo dies, two struggle, three win)
	elite2 = { solo = 1.80, duo = 1.50, trio = { 0.60, 1.00 } },
	kinds = { expPerSecond = { 0.85, 1.20 }, casterHpPerExp = 1.25 }, -- caster HP per EXP vs the region average
	bossCadence = 0.5,
}

-- Rows of one region (group = eliteSingle / eliteEncounter / elite2 / kinds / bossCadence). The Meadows use the S32
-- kind set (passive rabbit included) and the S32 band 0.85-1.20.
function Balance.targetsRegion(mapId: string, targets: any?): { TargetRow }
	local T = targets or Balance.REGION_TARGETS
	local rows: { TargetRow } = {}
	local function add(
		group: string,
		id: string,
		label: string,
		value: number,
		low: number?,
		high: number?,
		c: string?,
		L: number?
	)
		table.insert(rows, {
			id = `R.{mapId}.{id}`,
			group = group,
			label = label,
			value = value,
			low = low,
			high = high,
			classId = c,
			level = L,
		})
	end
	local single, inBand = 0, 0
	for _, cave in Balance.caveElites(mapId) do
		for _, kind in cave.kinds do
			for _, f in kind.fights do
				local key = `{cave.id}.{kind.kind}.{f.level}.{f.classId}`
				local s, hp = T.eliteSingle.seconds, T.eliteSingle.hp
				single += 1
				if
					f.single.seconds >= s[1]
					and f.single.seconds <= s[2]
					and f.single.hpLost >= hp[1]
					and f.single.hpLost <= hp[2]
				then
					inBand += 1
				end
				add(
					"eliteSingle",
					`eliteSingle.{key}.hp`,
					`{cave.id} {kind.kind} {f.level} {f.classId}: Elita HP`,
					f.single.hpLost,
					T.eliteSingle.hpFloor,
					T.eliteSingle.hpCeil,
					f.classId,
					f.level
				)
				local cap = T.eliteEncounter[f.classId]
				if cap then
					add(
						"eliteEncounter",
						`eliteEncounter.{key}`,
						`{cave.id} {kind.kind} {f.level} {f.classId}: spotkanie Elit (q = {string.format(
							"%.2f",
							cave.pairShare
						)})`,
						f.encounter,
						nil,
						cap,
						f.classId,
						f.level
					)
				end
			end
		end
		for _, e in cave.elite2 do
			local key = `{cave.id}.{e.kind}.{e.spawner}`
			local label = `{cave.id} {e.kind} {e.spawner}`
			add(
				"elite2",
				`elite2.{key}.solo`,
				`{label}: Elita II solo HP`,
				e.byTeam[1].hpLost,
				T.elite2.solo,
				nil,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.duo`,
				`{label}: Elita II 2 graczy HP`,
				e.byTeam[2].hpLost,
				nil,
				T.elite2.duo,
				nil,
				e.playerLevel
			)
			add(
				"elite2",
				`elite2.{key}.trio`,
				`{label}: Elita II 3 graczy HP`,
				e.byTeam[3].hpLost,
				T.elite2.trio[1],
				T.elite2.trio[2],
				nil,
				e.playerLevel
			)
		end
	end
	if single > 0 then
		add(
			"eliteSingle",
			"eliteSingle.share",
			"Elity solo: udział walk w paśmie czasu i HP",
			inBand / single,
			T.eliteSingle.shareInBand
		)
	end
	local meadows = mapId == "meadows"
	for _, k in Balance.kindRates(mapId, meadows) do
		local band = T.kinds.expPerSecond
		add(
			"kinds",
			`kinds.{k.kind}.exp`,
			`{k.kind} {k.level}: EXP/s ÷ zwykły`,
			k.expPerSecond,
			band[1],
			band[2],
			"Warrior",
			k.level
		)
		if k.caster and not meadows then
			add(
				"kinds",
				`kinds.{k.kind}.casterHp`,
				`{k.kind} {k.level}: HP/EXP rzucającego ÷ średnia regionu`,
				k.hpPerExp,
				nil,
				T.kinds.casterHpPerExp,
				"Warrior",
				k.level
			)
		end
	end
	local def = Bosses.forRegion(mapId) :: any
	if def then
		for phase = 1, #def.phases + 1 do
			local cad = Balance.bossCadence(def, phase)
			for _, attack in def.attacks do
				local share = cad.rateShare[attack.id]
				if share then
					add(
						"bossCadence",
						`boss.{phase}.{attack.id}`,
						`{def.id} faza {phase}: {attack.id}`,
						share,
						T.bossCadence,
						nil,
						nil,
						def.level
					)
				end
			end
		end
	end
	return rows
end

-- Balance ledger (S83, balance plan 2.6) ------------------------------------------------------------------------

Balance.LEDGER_LEVELS = { 1, 20, 45, 70, 100 }

export type LedgerReasons = {
	BALANCE_MODULES: { { path: string, pick: { string }?, omit: { string }? } },
	CONFIG_KEYS: { string },
	NOT_BALANCE: { [string]: string },
	reasons: { [string]: { { session: string, why: string } } },
}

-- A module of src/shared by its ledger path ("Data/Skills/init" is the directory module).
function Balance.requireShared(path: string): any
	local file = string.gsub(path, "/init$", "")
	return (require :: any)(`../src/shared/{file}`)
end

local function sortedKeys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then
			return ta < tb -- numbers before strings
		end
		return a < b
	end)
	return keys
end

local function segment(parent: { [any]: any }, key: any): string
	if type(key) == "number" then
		local v = parent[key]
		if type(v) == "table" and type(v.id) == "string" then
			return `[{v.id}]`
		end
		return `[{key}]`
	end
	return `.{key}`
end

-- Function results skipped by the last dataDump (for the report section "Księga: pominięte funkcje").
Balance.skippedFunctions = {} :: { string }

-- Every finite number of the BALANCE_MODULES (and Config.CONFIG_KEYS) as "<module>:<path>" (module without the
-- "Data/" prefix). Segments: ".field", "[id]" for an array element with a text id, "[n]" otherwise, ".f(L)" for the
-- result of a function called with L in LEDGER_LEVELS (pcall; a failing call or a result that is neither a number
-- nor a table is skipped). Every table is dumped once (under its first path in sorted order).
function Balance.dataDump(reasonsModule: LedgerReasons): { [string]: number }
	local out: { [string]: number } = {}
	local skipped: { string } = {}
	local seen: { [any]: boolean } = {}
	local function walk(v: any, path: string, picked: boolean, entry: any)
		local t = type(v)
		if t == "number" then
			if picked and v == v and v ~= math.huge and v ~= -math.huge then
				out[path] = v
			end
		elseif t == "table" then
			if seen[v] then
				return
			end
			seen[v] = true
			for _, k in sortedKeys(v) do
				local name = if type(k) == "string" then k else nil
				if not (name and entry.omit and table.find(entry.omit, name)) then
					local isPicked = picked
						or (name ~= nil and entry.pick ~= nil and table.find(entry.pick, name) ~= nil)
					walk(v[k], path .. segment(v, k), isPicked, entry)
				end
			end
		elseif t == "function" then
			local any = false
			for _, L in Balance.LEDGER_LEVELS do
				local ok, result = pcall(v, L)
				if ok and (type(result) == "number" or type(result) == "table") then
					any = true
					walk(result, `{path}.f({L})`, picked, entry)
				end
			end
			if not any then
				table.insert(skipped, (string.gsub(path, ":%.", ":", 1)))
			end
		end
	end
	for _, entry in reasonsModule.BALANCE_MODULES do
		seen = {} -- per module: a record shared by two modules shows in both
		local module = Balance.requireShared(entry.path)
		local name = string.gsub(entry.path, "^Data/", "")
		walk(module, `{name}:`, entry.pick == nil, entry)
	end
	local config = Balance.requireShared("Config")
	for _, key in reasonsModule.CONFIG_KEYS do
		if key ~= "AdminUserIds" then
			walk(config[key], `Config:{key}`, true, {})
		end
	end
	-- the root path "<module>:" + ".field" reads "<module>:.field"; drop the dot after the colon
	local clean: { [string]: number } = {}
	for k, v in out do
		clean[(string.gsub(k, ":%.", ":", 1))] = v
	end
	table.sort(skipped)
	Balance.skippedFunctions = skipped
	return clean
end

-- Values of every skill's { rank 1, max rank } value pairs at every rank (Skills.valueAt, so knots of
-- Data/SkillCurves count): "Rangi:<skillId>.<field>@<r>". Derived numbers: they show a knot or a changed pair with
-- the rank band (Skills.rankLevel) and need no reason of their own.
function Balance.rankDump(): { [string]: number }
	local out: { [string]: number } = {}
	for id, skill in SkillData.byId do
		for field, value in skill.values do
			if type(value) == "table" then
				for r = 1, skill.maxLevel do
					out[`Rangi:{id}.{field}@{r}`] = Skills.valueAt(skill, field, r)
				end
			end
		end
	end
	return out
end

-- Session number of "S<n>" (nil for anything else).
function Balance.sessionNumber(session: string?): number?
	local n = session and string.match(session, "^S(%d+)$")
	return if n then tonumber(n) else nil
end

-- The reasons of `key`: its own entries and those of the longest matching prefix ending in "*" (a newer bulk shift
-- of the whole table explains a key that has an older entry of its own).
function Balance.reasonsFor(reasons: { [string]: { any } }, key: string): { any }?
	local own = reasons[key]
	local best, bestLen = nil, -1
	for pattern, list in reasons do
		if string.sub(pattern, -1) == "*" then
			local prefix = string.sub(pattern, 1, -2)
			if string.sub(key, 1, #prefix) == prefix and #prefix > bestLen then
				best, bestLen = list, #prefix
			end
		end
	end
	if own and best then
		local merged = table.clone(own)
		table.move(best, 1, #best, #merged + 1, merged)
		return merged
	end
	return own or best
end

-- Equal up to the JSON round trip of the snapshot (serde keeps ~15 significant digits).
function Balance.sameNumber(a: number, b: number): boolean
	return a == b or math.abs(a - b) <= 1e-9 * math.max(math.abs(a), math.abs(b), 1e-9)
end

export type LedgerLine = { key: string, before: number?, after: number?, reason: { session: string, why: string }? }
export type Ledger =
	{ changed: { LedgerLine }, added: { LedgerLine }, removed: { LedgerLine }, unexplained: { string } }

-- Changes of the data dump (dataDump + rankDump, the "data" part of a snapshot) since the snapshot of
-- `snapshotSession`. A changed, added or removed number (but `Rangi:`) is explained by a reason (own key or longest
-- `*` prefix) of the snapshot's session or later; `reason` is the latest entry.
function Balance.ledger(
	before: { [string]: number },
	now: { [string]: number },
	reasons: { [string]: { any } },
	snapshotSession: string?
): Ledger
	local from = Balance.sessionNumber(snapshotSession) or 0
	local result: Ledger = { changed = {}, added = {}, removed = {}, unexplained = {} }
	local function explain(key: string): any
		local list = Balance.reasonsFor(reasons, key)
		local latest, latestN = nil, -1
		for _, entry in list or {} do
			local n = Balance.sessionNumber(entry.session)
			if n and n >= from and n >= latestN then
				latest, latestN = entry, n
			end
		end
		if latest == nil and string.sub(key, 1, 6) ~= "Rangi:" then
			table.insert(result.unexplained, key)
		end
		return latest
	end
	for key, a in now do
		local b = before[key]
		if b == nil then
			table.insert(result.added, { key = key, after = a, reason = explain(key) })
		elseif not Balance.sameNumber(a, b) then
			table.insert(result.changed, { key = key, before = b, after = a, reason = explain(key) })
		end
	end
	for key, b in before do
		if now[key] == nil then
			table.insert(result.removed, { key = key, before = b, reason = explain(key) })
		end
	end
	local function byKey(x: LedgerLine, y: LedgerLine): boolean
		return x.key < y.key
	end
	table.sort(result.changed, byKey)
	table.sort(result.added, byKey)
	table.sort(result.removed, byKey)
	table.sort(result.unexplained)
	return result
end

-- dataDump + rankDump: the "data" part of a snapshot.
function Balance.ledgerData(reasonsModule: LedgerReasons): { [string]: number }
	local out = Balance.dataDump(reasonsModule)
	for k, v in Balance.rankDump() do
		out[k] = v
	end
	return out
end

return Balance
