--!strict
-- Balance model (S32, DESIGN §15.1): expected values from the game's own modules, no randomness.
-- Used by balance.spec (targets of DESIGN §15.1) and tools/balance_report.luau (docs/BALANS.md).
--
--   gear(classId, level, opts)      -> the items a player wears (weapon, off-hand, 4 armour pieces, jewellery)
--   player(classId, level, opts)    -> StatCalc values of that player + the weapon
--   duel / groupFight / expectedGroup / elite / elite2 / grimrok -> fight length and HP lost
--   power(...)                      -> "character power" = sqrt(DPS x effective HP), for rarity value
--   pace(...) / economy(...)        -> kills per level, EXP/h, gold/h and the 1-20 gold budget
--
-- Fights use basic attacks plus `SKILL_DPS` (1-2 skills on cooldown) and no potions. Monsters swing once at the
-- start and then every interval; the player regenerates its in-combat regen.

local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Bases = require("../src/shared/Data/Items/Bases")
local Bonuses = require("../src/shared/Data/Bonuses")
local Bosses = require("../src/shared/Data/Bosses")
local BossScaling = require("../src/shared/Logic/BossScaling")
local Classes = require("../src/shared/Data/Classes")
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
local Quests = require("../src/shared/Data/Quests")
local Rarities = require("../src/shared/Data/Rarities")
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

-- Expected bonus lines of one item: every pool entry gets count / #pool of its middle value.
local function expectedBonuses(defId: string, ilvl: number, rarity: number, classId: string?): { any }
	local rarityDef = Rarities.get(rarity)
	local out = {}
	local pool = poolFor(defId, classId)
	local count = (rarityDef.bonusMin + rarityDef.bonusMax) / 2
	if count > 0 and #pool > 0 then
		local share = math.min(1, count / #pool)
		for _, id in pool do
			table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
		end
	end
	local legendary = Bonuses.pools.legendary
	if rarityDef.legendaryLines > 0 then
		local share = rarityDef.legendaryLines / #legendary
		for _, id in legendary do
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

Balance.GENERIC = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }

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

-- Backwards-compatible single fight (S18 spec): common weapon + 4 armour pieces of `level`, no off-hand,
-- no jewellery, no skills.
function Balance.fight(
	classId: string,
	level: number
): { killSeconds: number, hpLost: number, playerHp: number, monsterHp: number }
	local skill = Balance.SKILL_DPS
	Balance.SKILL_DPS = 1
	local p = Balance.player(classId, level, { ilvl = level, offhand = false, jewellery = false, bonuses = false })
	local m = Balance.monster(Balance.GENERIC, level)
	local fight = Balance.duel(p, m)
	Balance.SKILL_DPS = skill
	return { killSeconds = fight.seconds, hpLost = fight.hpLost, playerHp = fight.playerHp, monsterHp = m.maxHp }
end

return Balance
