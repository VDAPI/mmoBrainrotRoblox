--!strict
-- monsters.json (S34): every monster kind with the variants that really spawn (Data/Spawns), stats on every level
-- of the spawn range (MonsterStats.compute, Damage.computeDamage with StubRng for min-max, Exp.monsterExp and
-- MonsterStats.gold with the kind reward like CombatService), loot per variant (item chance and rarity shares from
-- Data/Rarities, materials from Data/LootTables, the chance of every item from a Monte Carlo of Loot.rollMonsterLoot
-- with a fixed seed per kind and variant) and where it lives (areas and caves). Also fills ctx.drops (item ->
-- monsters with the chance) for items.json.

local Areas = require("../../src/shared/Data/Areas")
local Basics = require("./Basics")
local Clean = require("./Clean")
local Damage = require("../../src/shared/Logic/Damage")
local Exp = require("../../src/shared/Logic/Exp")
local ItemRoll = require("../../src/shared/Logic/ItemRoll")
local Items = require("../../src/shared/Data/Items")
local Json = require("./Json")
local Loot = require("../../src/shared/Logic/Loot")
local LootTables = require("../../src/shared/Data/LootTables")
local MonsterAbilities = require("../../src/shared/Data/MonsterAbilities")
local MonsterLooks = require("../../src/shared/Data/MonsterLooks")
local MonsterStats = require("../../src/shared/Logic/MonsterStats")
local MonsterData = require("../../src/shared/Data/Monsters")
local Names = require("./Names")
local Rarities = require("../../src/shared/Data/Rarities")
local Rng = require("../../src/shared/Logic/Rng")
local Schema = require("./Schema")
local Spawns = require("../../src/shared/Data/Spawns")
local StubRng = require("./StubRng")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Monsters = {}

Monsters.REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }
Monsters.TOP = 5

local Ability = rec("Ability", {
	id = "string",
	["name?"] = "name",
	shape = "string",
	origin = "string",
	["radius?"] = "number",
	["inner?"] = "number",
	["angle?"] = "number",
	["length?"] = "number",
	["width?"] = "number",
	windup = "number",
	damage = "number",
	cooldown = "number",
	["element?"] = enum("ElementId"),
	["damageKind?"] = "string",
})

local LevelStats = rec("MonsterLevel", {
	level = "int", -- spawner level
	finalLevel = "int", -- with the variant's levels
	hp = "int",
	armor = "number",
	mres = "number",
	attackInterval = "number",
	range = "number",
	aggroRange = "number",
	dmgMin = "int",
	dmgMax = "int",
	["abilityMin?"] = "int",
	["abilityMax?"] = "int",
	exp = "int",
	goldMin = "int",
	goldMax = "int",
})

local ItemChance = rec("ItemChance", { id = "ref:items", chance = "number" })

local Spawn = rec("MonsterSpawn", {
	map = "ref:maps",
	["area?"] = "ref:areas",
	["cave?"] = "ref:caves",
	["profile?"] = "string",
	groups = "int",
	count = "int", -- monsters of this kind in those groups
	levelMin = "int",
	levelMax = "int",
	respawnMin = "number",
	respawnMax = "number",
})

local VariantInfo = rec("MonsterVariant", {
	name = "name",
	levelMin = "int",
	levelMax = "int",
	levels = arr(LevelStats),
	spawns = arr(Spawn),
	loot = rec("MonsterLoot", {
		itemChance = "number",
		itemMin = "int",
		itemMax = "int",
		["itemExtra?"] = "number",
		itemMeasured = "number", -- share of kills with an item in the Monte Carlo (checks the tables)
		rarities = map("number"),
		materials = arr(rec("MaterialChance", {
			id = "ref:items",
			chance = "number",
			measured = "number",
			min = "int",
			max = "int",
		})),
		items = arr(ItemChance),
		groups = map(rec("LootGroup", { chance = "number", ilvlMin = "int", ilvlMax = "int", top = arr(ItemChance) })),
		rolls = "int",
	}),
})

S.file(
	"monsters",
	rec("MonstersFile", {
		monsters = arr(rec("Monster", {
			id = "string",
			name = "name",
			region = "int",
			regionMap = "ref:maps",
			cave = "bool",
			["element?"] = enum("ElementId"),
			attack = "string",
			damageKind = "string",
			range = "number",
			passive = "bool",
			elites = "bool",
			moveSpeed = "number",
			lootTable = "string",
			classBias = "number",
			["family?"] = "string",
			["ability?"] = Ability,
			hpMul = "number",
			atkMul = "number",
			defMul = "number",
			speed = "number",
			kindReward = "number",
			variants = map(VariantInfo),
		})),
	})
)

-- Spawners of a kind by variant, with the map they are on.
local function spawnersOf(id: string): { [string]: { { map: string, s: any } } }
	local out: { [string]: { { map: string, s: any } } } = {}
	for _, mapId in Clean.keys(Spawns.byMap) do
		for _, s in Spawns.byMap[mapId] do
			local kinds: { string } = s.choices or s.members or { s.monster }
			if table.find(kinds, id) then
				out[s.variant] = out[s.variant] or {}
				table.insert(out[s.variant], { map = mapId, s = s })
			end
		end
	end
	return out
end

local function areaIdSet(): { [string]: string }
	local out = {}
	for mapId, data in Areas.byMap do
		for _, area in data.areas do
			out[area.id] = mapId
		end
	end
	return out
end

-- One hit of `stats` (multiplier `mul`) on a defender without armour: min and max of the random factor.
function Monsters.damageRange(
	stats: MonsterStats.MonsterStats,
	mul: number?,
	element: string?,
	kind: string?
): (number, number)
	local attacker = MonsterStats.asAttacker(stats)
	local defender = { armor = 0, mres = 0, dodge = 0 }
	local params: any = {
		kind = kind or stats.damageKind,
		multiplier = mul,
		element = element,
		canCrit = false,
		canDodge = false,
	}
	local low = Damage.computeDamage(attacker, defender, params, StubRng.new("min")).amount
	local high = Damage.computeDamage(attacker, defender, params, StubRng.new("max")).amount
	return low, high
end

local function levelStats(def: any, level: number, variant: string, ability: any?): any
	local s = MonsterStats.compute(def, level, variant :: any)
	local low, high = Monsters.damageRange(s, nil, def.element)
	local kindReward = MonsterStats.kindReward(def)
	local goldLow = math.max(1, math.floor(MonsterStats.gold(s.level, variant, 0) * kindReward + 0.5))
	local goldHigh = math.max(1, math.floor(MonsterStats.gold(s.level, variant, 1) * kindReward + 0.5))
	local row: any = {
		level = level,
		finalLevel = s.level,
		hp = s.maxHp,
		armor = s.armor,
		mres = s.mres,
		attackInterval = s.attackInterval,
		range = s.range,
		aggroRange = s.aggroRange,
		dmgMin = low,
		dmgMax = high,
		exp = math.floor(Exp.monsterExp(s.level, variant :: any) * kindReward + 0.5),
		goldMin = goldLow,
		goldMax = goldHigh,
	}
	if ability then
		row.abilityMin, row.abilityMax =
			Monsters.damageRange(s, ability.damage, ability.element, ability.damageKind or s.damageKind)
	end
	return row
end

-- Monte Carlo of the loot of a variant over its spawn levels (equal share each), fixed seed per kind:variant.
local function rollLoot(def: any, variant: string, levels: { { level: number, cap: number } }, rolls: number): any
	local rng = Rng.new(StubRng.seedOf(`{def.id}:{variant}`))
	local itemKills: { [string]: number } = {}
	local slotKills: { [string]: number } = {}
	local anyItem = 0
	local materialKills: { [string]: number } = {}
	local perLevel = math.max(1, math.floor(rolls / #levels))
	local total = 0
	for _, entry in levels do
		local level = MonsterStats.compute(def, entry.level, variant :: any).level
		local mods = { dropLevel = Loot.dropBaseLevel(level, variant, entry.cap) }
		for _ = 1, perLevel do
			total += 1
			local loot = Loot.rollMonsterLoot(def.id, variant, level, rng, mods)
			if #loot.items > 0 then
				anyItem += 1
			end
			local seenMaterial: { [string]: boolean } = {}
			for _, m in loot.materials do
				if not seenMaterial[m.id] then
					seenMaterial[m.id] = true
					materialKills[m.id] = (materialKills[m.id] or 0) + 1
				end
			end
			local seenItem: { [string]: boolean } = {}
			local seenSlot: { [string]: boolean } = {}
			for _, drop in loot.items do
				if not seenItem[drop.defId] then
					seenItem[drop.defId] = true
					itemKills[drop.defId] = (itemKills[drop.defId] or 0) + 1
				end
				local item = Items.get(drop.defId)
				local slot = item and item.slot or "other"
				if not seenSlot[slot] then
					seenSlot[slot] = true
					slotKills[slot] = (slotKills[slot] or 0) + 1
				end
			end
		end
	end
	-- Item levels of the drops (ItemRoll.dropLevel with the extreme rolls) over every spawn level.
	local ilvlMin, ilvlMax = math.huge, -math.huge
	for _, entry in levels do
		local level = MonsterStats.compute(def, entry.level, variant :: any).level
		local base = Loot.dropBaseLevel(level, variant, entry.cap)
		ilvlMin = math.min(ilvlMin, ItemRoll.dropLevel(base, StubRng.new("min")))
		ilvlMax = math.max(ilvlMax, ItemRoll.dropLevel(base, StubRng.new("max")))
	end
	local items = {}
	local bySlot: { [string]: { any } } = {}
	for _, id in Clean.keys(itemKills) do
		local entry = { id = id, chance = itemKills[id] / total }
		table.insert(items, entry)
		local item = Items.get(id)
		local slot = item and item.slot or "other"
		bySlot[slot] = bySlot[slot] or {}
		table.insert(bySlot[slot], entry)
	end
	local groups = {}
	for _, slot in Clean.keys(slotKills) do
		local list = bySlot[slot] or {}
		table.sort(list, function(a, b)
			if a.chance ~= b.chance then
				return a.chance > b.chance
			end
			return a.id < b.id
		end)
		local top = {}
		for i = 1, math.min(Monsters.TOP, #list) do
			table.insert(top, list[i])
		end
		groups[slot] = { chance = slotKills[slot] / total, ilvlMin = ilvlMin, ilvlMax = ilvlMax, top = top }
	end
	local measured = { item = anyItem / total, materials = {} :: { [string]: number } }
	for id, n in materialKills do
		measured.materials[id] = n / total
	end
	return items, Json.object(groups), total, measured
end

function Monsters.build(ctx: any): any
	local areaMap = areaIdSet()
	ctx.drops = ctx.drops or {}
	local list = {}
	for _, def in MonsterData.list do
		if not ctx.hidden[def.id] then
			local tableDef = LootTables.get(def.lootTable)
			local abilityDef = if def.ability then MonsterAbilities.get(def.ability) else nil
			local look = MonsterLooks.get(def.id, def.region)
			local variants = {}
			for variant, spawners in spawnersOf(def.id) do
				-- Spawn levels with their spawner's highest level (drops never above it).
				local levelCaps: { [number]: number } = {}
				local spawnGroups: { [string]: any } = {}
				local low, high = math.huge, -math.huge
				for _, entry in spawners do
					local s = entry.s
					for l = s.level.min, s.level.max do
						levelCaps[l] = math.max(levelCaps[l] or 0, s.level.max)
					end
					low, high = math.min(low, s.level.min), math.max(high, s.level.max)
					local kinds: { string } = s.choices or s.members or { s.monster }
					local n = 0
					for _, k in kinds do
						n += if k == def.id then 1 else 0
					end
					if s.choices then
						n = 1
					end
					local isArea = s.areaId and areaMap[s.areaId] ~= nil
					local key = `{entry.map}|{s.areaId or ""}`
					local g = spawnGroups[key]
					if not g then
						g = {
							map = if isArea
								then entry.map
								else (Areas.caves.get(s.areaId or "") or {}).region or entry.map,
							area = if isArea then s.areaId else nil,
							cave = if not isArea and Areas.caves.get(s.areaId or "") then s.areaId else nil,
							profile = if isArea then (Areas.areaById(s.areaId) :: any).profile else nil,
							groups = 0,
							count = 0,
							levelMin = s.level.min,
							levelMax = s.level.max,
							respawnMin = s.respawn.min,
							respawnMax = s.respawn.max,
						}
						spawnGroups[key] = g
					end
					g.groups += 1
					g.count += n
					g.levelMin = math.min(g.levelMin, s.level.min)
					g.levelMax = math.max(g.levelMax, s.level.max)
					g.respawnMin = math.min(g.respawnMin, s.respawn.min)
					g.respawnMax = math.max(g.respawnMax, s.respawn.max)
				end
				local levelRows = {}
				local levelList = {}
				for l = low, high do
					if levelCaps[l] then
						table.insert(
							levelRows,
							levelStats(def, l, variant, if variant == "elite2" then abilityDef else nil)
						)
						table.insert(levelList, { level = l, cap = levelCaps[l] })
					end
				end
				local spawns = {}
				for _, key in Clean.keys(spawnGroups) do
					table.insert(spawns, spawnGroups[key])
				end
				local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
				local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
				local wTotal = 0
				for _, w in weights do
					wTotal += w
				end
				local shares = {}
				for rarity, w in weights do
					shares[Basics.rarityKey(rarity)] = w / wTotal
				end
				local materials = {}
				for _, m in tableDef and tableDef.materials or {} do
					table.insert(materials, { id = m.id, chance = m.chance, min = m.min, max = m.max })
				end
				for _, m in tableDef and tableDef.variantMaterials[variant] or {} do
					table.insert(materials, { id = m.id, chance = m.chance, min = m.min, max = m.max })
				end
				local items, groups, rolls, measured = rollLoot(def, variant, levelList, ctx.rolls)
				for _, m in materials do
					m.measured = measured.materials[m.id] or 0
				end
				local visibleItems = Clean.dropRefs(items, ctx.hidden, "id")
				for _, entry in visibleItems do
					ctx.drops[entry.id] = ctx.drops[entry.id] or {}
					table.insert(ctx.drops[entry.id], { monster = def.id, variant = variant, chance = entry.chance })
				end
				variants[variant] = {
					name = Names.of((def.nameKeys :: any)[variant] or def.nameKeys.normal),
					levelMin = low,
					levelMax = high,
					levels = levelRows,
					spawns = spawns,
					loot = {
						itemChance = drops.chance,
						itemMin = drops.min,
						itemMax = drops.max,
						itemExtra = drops.extra,
						itemMeasured = measured.item,
						rarities = shares,
						materials = Clean.dropRefs(materials, ctx.hidden, "id"),
						items = visibleItems,
						groups = groups,
						rolls = rolls,
					},
				}
			end
			local ability = nil
			if abilityDef then
				ability = Clean.clean(abilityDef)
				ability.name = Names.opt(`ability.{abilityDef.id}`)
			end
			table.insert(list, {
				id = def.id,
				name = Names.of(def.nameKeys.normal),
				region = def.region,
				regionMap = Monsters.REGION_MAPS[def.region] or "meadows",
				cave = def.cave,
				element = def.element,
				attack = def.attack,
				damageKind = def.damageKind,
				range = MonsterStats.compute(def, def.levels.min, "normal").range,
				passive = def.passive,
				elites = def.elites,
				moveSpeed = def.moveSpeed,
				lootTable = def.lootTable,
				classBias = if tableDef then tableDef.classBias else 0,
				family = if look then look.plan else nil,
				ability = ability,
				hpMul = def.hpMul,
				atkMul = def.atkMul,
				defMul = def.defMul,
				speed = def.speed,
				kindReward = MonsterStats.kindReward(def),
				variants = variants,
			})
		end
	end
	ctx.monsterCount = #list
	return { monsters = list }
end

return Monsters
