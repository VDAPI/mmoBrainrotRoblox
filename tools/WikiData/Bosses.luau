--!strict
-- bosses.json (S34): Data/Bosses with HP and attack (MonsterStats.compute on the kind the server's Entities/Boss
-- builds: hpMul = BossScaling.hpMultiplier() x def.hpMul; S134: one HP for every party, `stats` instead of the list for
-- 1-5 players), attacks with damage min-max like an
-- Elite II ability, summons, phases, enrage, the loot (FIX 2026-10-09: one item per winner, Monte Carlo of
-- Loot.rollBossItem; Legendary / Mythic chances by kills that day, Loot.bossChances) and the dungeon. Fills ctx.bossDrops for items.json.

local Areas = require("../../src/shared/Data/Areas")
local BossData = require("../../src/shared/Data/Bosses")
local BossScaling = require("../../src/shared/Logic/BossScaling")
local Clean = require("./Clean")
local Config = require("../../src/shared/Config")
local Exp = require("../../src/shared/Logic/Exp")
local Loot = require("../../src/shared/Logic/Loot")
local LevelLock = require("../../src/shared/Logic/LevelLock")
local LootTables = require("../../src/shared/Data/LootTables")
local MonsterStats = require("../../src/shared/Logic/MonsterStats")
local Monsters = require("./Monsters")
local Names = require("./Names")
local Rarities = require("../../src/shared/Data/Rarities")
local Rng = require("../../src/shared/Logic/Rng")
local Schema = require("./Schema")
local StubRng = require("./StubRng")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Bosses = {}

local PityLine = rec("PityLine", {
	chance = "number",
	step = "number",
	hard = "int",
	byMisses = arr("number"),
	expectedKills = "number",
})

S.file(
	"bosses",
	rec("BossesFile", {
		bosses = arr(rec("Boss", {
			id = "string",
			name = "name",
			region = "string",
			level = "int",
			requiredLevel = "int",
			-- S157 (Logic/LevelLock): above this level a player cannot enter nor fight the boss
			maxLevel = "int",
			dungeon = "ref:maps",
			["gateCave?"] = "ref:caves",
			attack = "string",
			damageKind = "string",
			range = "number",
			moveSpeed = "number",
			aura = "color",
			size = "number",
			phases = arr("number"),
			phaseTexts = arr("name"),
			["enrageText?"] = "name",
			-- S134: one HP for every party (bosses never scale with the party)
			stats = rec("BossStats", {
				hp = "int",
				armor = "number",
				mres = "number",
				dmgMin = "int",
				dmgMax = "int",
			}),
			attacks = arr(rec("BossAttack", {
				id = "string",
				["name?"] = "name",
				shape = "string",
				target = "string",
				["radius?"] = "number",
				["inner?"] = "number",
				["angle?"] = "number",
				["length?"] = "number",
				["width?"] = "number",
				windup = "number",
				damage = "number",
				cooldown = "number",
				["count?"] = "int",
				phases = arr("int"),
				["element?"] = enum("ElementId"),
				["damageKind?"] = "string",
				["leap?"] = "bool",
				-- S134: a big blow to dodge and the party mechanics (text from Locale boss.mechanic.<kind>.about)
				["avoid?"] = "bool",
				["mechanic?"] = "string",
				["mechanicText?"] = "name",
				["split?"] = rec("BossSplit", { missAll = "number" }),
				["mark?"] = rec("BossMark", { seconds = "number", self = "number" }),
				["channel?"] = rec("BossChannel", { seconds = "number", breakPct = "number", stagger = "number" }),
				dmgMin = "int",
				dmgMax = "int",
			})),
			summons = arr(rec("BossSummon", {
				phase = "int",
				monster = "ref:monsters",
				level = "int",
				count = "int",
				["every?"] = "number",
				["shield?"] = "bool",
			})),
			["haste?"] = map("number"),
			enrageAfter = "number",
			enrageDamage = "number",
			timeLimit = "number",
			scriptConsts = map("number"),
			exp = "int",
			goldMin = "int",
			goldMax = "int",
			loot = rec("BossLoot", {
				itemMin = "int",
				itemMax = "int",
				rarities = map("number"),
				items = arr(rec("BossItemChance", { id = "ref:items", chance = "number" })),
				materials = arr(rec("BossMaterial", { id = "ref:items", chance = "number", min = "int", max = "int" })),
				named = arr("ref:items"),
				legendaryBlessingChance = "number",
				rolls = "int",
			}),
			personal = rec("BossPersonal", { legendary = PityLine, mythic = PityLine }),
		})),
		dailyRuns = "int",
		entryRange = "number",
		countdown = "number",
		releaseAfter = "number",
	})
)

-- Numeric constants of the server boss script (S39), read as text (never required): lines "local NAME = 12.5".
function Bosses.scriptConsts(text: string?): { [string]: number }
	local out = {}
	for line in string.gmatch(text or "", "[^\r\n]+") do
		local key, value = string.match(line, "^local ([A-Z_]+) = ([%d%.]+)$")
		if key and value and tonumber(value) then
			out[key] = tonumber(value) :: number
		end
	end
	return out
end

local function kindFor(def: BossData.BossDef): any
	return {
		hpMul = BossScaling.hpMultiplier() * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul, -- S66: magic resistance like in the game
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
		range = def.range,
	}
end

-- Chance by the kills of that boss earlier the same day (Loot.bossChances; field names kept from the S30 pity:
-- `byMisses` = by kills today, `hard` = the daily limit) and the expected kills until a hit at the daily limit.
local function dayLine(bossId: string, base: number, step: number, field: string): any
	local runs = (Config :: any).Boss and (Config :: any).Boss.dailyRuns or 1
	local chances = {}
	local sum = 0
	for kills = 0, runs - 1 do
		local c = (Loot.bossChances(bossId, kills) :: any)[field]
		table.insert(chances, c)
		sum += c
	end
	local mean = sum / runs
	return {
		chance = base,
		step = step,
		hard = runs,
		byMisses = chances,
		expectedKills = if mean > 0 then 1 / mean else 0,
	}
end

function Bosses.build(ctx: any): any
	ctx.bossDrops = ctx.bossDrops or {}
	local list = {}
	for _, def in BossData.list do
		if not ctx.hidden[def.id] then
			local tableDef = LootTables.bosses[def.id]
			local stats = MonsterStats.compute(kindFor(def), def.level, "boss")
			local low, high = Monsters.damageRange(stats, nil, nil)
			local attacks = {}
			for _, a in def.attacks do
				local entry = Clean.clean(a)
				entry.name = Names.opt(`boss.{def.id}.attack.{a.id}`)
				local kind = a.mechanic or (if a.avoid then "avoid" else nil)
				entry.mechanicText = if kind then Names.opt(`boss.mechanic.{kind}.about`) else nil
				entry.dmgMin, entry.dmgMax =
					Monsters.damageRange(stats, a.damage, a.element, a.damageKind or stats.damageKind)
				table.insert(attacks, entry)
			end
			-- The winner's item: Monte Carlo of the first kill of the day (Unique / Heroic bases; Legendary / Mythic
			-- are shown by their chances).
			local rng = Rng.new(StubRng.seedOf(`boss:{def.id}`))
			local rolls = math.max(1, math.floor(ctx.rolls / 10))
			local kills: { [string]: number } = {}
			for _ = 1, rolls do
				local drop = if tableDef then Loot.rollBossItem(tableDef, 0, nil, rng) else nil
				if drop and drop.rarity < Rarities.LEGENDARY then
					kills[drop.defId] = (kills[drop.defId] or 0) + 1
				end
			end
			local items = {}
			for _, id in Clean.keys(kills) do
				if not ctx.hidden[id] then
					table.insert(items, { id = id, chance = kills[id] / rolls })
					ctx.bossDrops[id] = ctx.bossDrops[id] or {}
					table.insert(ctx.bossDrops[id], { boss = def.id, chance = kills[id] / rolls, personal = false })
				end
			end
			local named = Clean.dropRefs(tableDef and tableDef.named or {}, ctx.hidden)
			for _, id in named do
				ctx.bossDrops[id] = ctx.bossDrops[id] or {}
				table.insert(ctx.bossDrops[id], { boss = def.id, chance = 0, personal = true })
			end
			local weights = Rarities.dropWeights.boss
			local wTotal = 0
			for _, w in weights do
				wTotal += w
			end
			local shares = {}
			for rarity, w in weights do
				shares[Rarities.get(rarity).key] = w / wTotal
			end
			local drops = Rarities.itemDrops.boss
			local materials = {}
			for _, m in tableDef and tableDef.materials or {} do
				table.insert(materials, { id = m.id, chance = m.chance, min = m.min, max = m.max })
			end
			local gate = nil
			for _, cave in Areas.caves.list do
				if cave.boss and cave.region == def.region then
					gate = cave.id
				end
			end
			local phaseTexts = {}
			for phase = 1, #def.phases + 1 do
				local key = `boss.{def.id}.phase{phase}`
				if Names.has(key) then
					table.insert(phaseTexts, Names.of(key))
				end
			end
			table.insert(list, {
				id = def.id,
				name = Names.of(def.nameKey),
				region = def.region,
				level = def.level,
				requiredLevel = BossScaling.requiredLevel(def.level),
				maxLevel = LevelLock.maxLevel(def.level),
				dungeon = `dungeon_{def.region}`,
				gateCave = gate,
				attack = def.attack,
				damageKind = def.damageKind,
				range = stats.range,
				moveSpeed = def.moveSpeed,
				aura = def.look.aura,
				size = def.look.size,
				phases = Clean.clean(def.phases),
				phaseTexts = phaseTexts,
				enrageText = Names.opt(`boss.{def.id}.enrage`),
				stats = {
					hp = stats.maxHp,
					armor = stats.armor,
					mres = stats.mres,
					dmgMin = low,
					dmgMax = high,
				},
				attacks = attacks,
				summons = Clean.clean(def.summons),
				haste = if def.haste then Clean.clean(def.haste) else nil,
				enrageAfter = def.enrageAfter,
				enrageDamage = def.enrageDamage,
				timeLimit = def.timeLimit,
				scriptConsts = Bosses.scriptConsts(
					if ctx.readText then ctx.readText(`src/server/Entities/BossScripts/{def.id}.luau`) else nil
				),
				exp = math.floor(Exp.monsterExp(def.level, "boss") + 0.5),
				goldMin = MonsterStats.gold(def.level, "boss", 0),
				goldMax = MonsterStats.gold(def.level, "boss", 1),
				loot = {
					itemMin = drops.min,
					itemMax = drops.max,
					rarities = shares,
					items = items,
					materials = Clean.dropRefs(materials, ctx.hidden, "id"),
					named = named,
					legendaryBlessingChance = BossData.LEGENDARY_BLESSING_CHANCE,
					rolls = rolls,
				},
				personal = {
					legendary = dayLine(def.id, tableDef.legendaryChance, tableDef.perKill, "legendary"),
					mythic = dayLine(def.id, tableDef.mythicChance, tableDef.perKill, "mythic"),
				},
			})
		end
	end
	return {
		bosses = list,
		dailyRuns = (Config :: any).Boss and (Config :: any).Boss.dailyRuns or 1,
		entryRange = BossData.ENTRY_RANGE,
		countdown = BossData.COUNTDOWN,
		releaseAfter = BossData.RELEASE_AFTER,
	}
end

return Bosses
