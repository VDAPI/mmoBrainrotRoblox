--!strict
-- Derived statistics (DESIGN §4.4). Pure: compute(input) -> { primary, values, breakdown, walkSpeed }.
--
-- Modifier sources (gear, blessing, passives, guild, ...) each contribute `flat` and `pct` tables keyed by
-- stat id (Data/Stats ids plus "str"/"dex"/"int"/"vit"/"hp"/"mana"/"energy"). pct values are percent
-- points that sum additively, then multiply: final = (base + flat) x (1 + pct/100), then the cap.
-- "hp"/"mana"/"energy" are accepted as aliases of maxHp/maxMana/maxEnergy (item bonus naming).

local Stats = require("../Data/Stats")
local Types = require("../Types")

local F = Stats.Formula

export type Source = {
	key: string, -- localization key shown in the breakdown tooltip, e.g. "source.gear"
	flat: { [string]: number }?,
	pct: { [string]: number }?,
}

export type Weapon = { dmg: number, mdmg: number, speed: number, ranged: boolean, element: string? }

export type Input = {
	level: number,
	stats: Types.Stats, -- allocated primary stats (class start + points)
	sources: { Source }?,
	weapon: Weapon?,
}

-- One line of a "where does this value come from" tooltip.
export type Part = { key: string, value: number, pct: boolean? }

export type Result = {
	primary: Types.Stats,
	values: { [string]: number },
	breakdown: { [string]: { Part } },
	walkSpeed: number,
}

local ALIASES = { hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }

local StatCalc = {}

local function canonical(id: string): string
	return ALIASES[id] or id
end

local EMPTY: { [string]: number } = table.freeze({})

local function entries(values: { [string]: number }?): { [string]: number }
	return values or EMPTY
end

function StatCalc.compute(input: Input): Result
	local sources: { Source } = input.sources or {}
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	for _, source in sources do
		for id, v in entries(source.flat) do
			local key = canonical(id)
			flat[key] = (flat[key] or 0) + v
		end
		for id, v in entries(source.pct) do
			local key = canonical(id)
			pct[key] = (pct[key] or 0) + v
		end
	end

	local values: { [string]: number } = {}
	local breakdown: { [string]: { Part } } = {}

	-- Appends per-source flat/pct parts for `id`.
	local function sourceParts(id: string, parts: { Part }, withFlat: boolean, withPct: boolean)
		for _, source in sources do
			if withFlat then
				local f = 0
				for sid, v in entries(source.flat) do
					if canonical(sid) == id then
						f += v
					end
				end
				if f ~= 0 then
					table.insert(parts, { key = source.key, value = f })
				end
			end
			if withPct then
				local p = 0
				for sid, v in entries(source.pct) do
					if canonical(sid) == id then
						p += v
					end
				end
				if p ~= 0 then
					table.insert(parts, { key = source.key, value = p, pct = true })
				end
			end
		end
	end

	-- final = (base + flat) x (1 + pct/100), capped.
	local function finish(id: string, base: number, parts: { Part }, integer: boolean?): number
		sourceParts(id, parts, true, true)
		local value = (base + (flat[id] or 0)) * (1 + (pct[id] or 0) / 100)
		local def = Stats.get(id)
		if def and def.cap then
			value = math.min(value, def.cap)
		end
		value = math.max(0, value)
		if integer then
			value = math.floor(value)
		end
		values[id] = value
		breakdown[id] = parts
		return value
	end

	-- Primary stats
	local primary = {} :: any
	for _, id in Stats.primary do
		local allocated = (input.stats :: any)[id] or 0
		local parts = { { key = "breakdown.allocated", value = allocated } }
		sourceParts(id, parts, true, true)
		local value = math.floor((allocated + (flat[id] or 0)) * (1 + (pct[id] or 0) / 100))
		primary[id] = math.max(0, value)
		breakdown[id] = parts
	end
	local L = input.level
	local STR, DEX, INT, VIT = primary.str, primary.dex, primary.int, primary.vit
	local weapon = input.weapon or F.unarmed

	-- Resources
	finish("maxHp", F.hpBase + F.hpPerLevel * L + F.hpPerVit * VIT, {
		{ key = "breakdown.base", value = F.hpBase },
		{ key = "breakdown.level", value = F.hpPerLevel * L },
		{ key = "breakdown.vit", value = F.hpPerVit * VIT },
	}, true)
	finish("maxMana", F.manaBase + F.manaPerLevel * L + F.manaPerInt * INT, {
		{ key = "breakdown.base", value = F.manaBase },
		{ key = "breakdown.level", value = F.manaPerLevel * L },
		{ key = "breakdown.int", value = F.manaPerInt * INT },
	}, true)
	finish("maxEnergy", F.energyBase + F.energyPerLevel * L, {
		{ key = "breakdown.base", value = F.energyBase },
		{ key = "breakdown.level", value = F.energyPerLevel * L },
	}, true)

	-- Offense
	local scaling = if weapon.ranged then DEX else STR
	local physScale = weapon.dmg * F.physPerStat * scaling
	finish("physAtk", weapon.dmg + physScale, {
		{ key = "breakdown.weapon", value = weapon.dmg },
		{ key = if weapon.ranged then "breakdown.dex" else "breakdown.str", value = physScale },
	})
	local magScale = weapon.mdmg * F.magPerInt * INT
	finish("magAtk", weapon.mdmg + magScale, {
		{ key = "breakdown.weapon", value = weapon.mdmg },
		{ key = "breakdown.int", value = magScale },
	})
	finish("critChance", F.critBase + F.critPerDex * DEX, {
		{ key = "breakdown.base", value = F.critBase },
		{ key = "breakdown.dex", value = F.critPerDex * DEX },
	})
	finish("critDmg", F.critDmgBase, { { key = "breakdown.base", value = F.critDmgBase } })

	-- Attack speed: gear atkSpeed is a percentage inside the multiplier, not a flat addition.
	do
		local parts: { Part } = {
			{ key = "breakdown.weapon", value = weapon.speed },
			{ key = "breakdown.dex", value = F.atkSpeedPerDex * DEX * 100, pct = true },
		}
		sourceParts("atkSpeed", parts, true, false)
		local multiplier = 1 + F.atkSpeedPerDex * DEX + (flat.atkSpeed or 0) / 100 + (pct.atkSpeed or 0) / 100
		local value = weapon.speed * multiplier
		local def = Stats.get("atkSpeed")
		values.atkSpeed = math.max(0, math.min(value, if def and def.cap then def.cap else math.huge))
		breakdown.atkSpeed = parts
	end

	finish("accuracy", 0, {})
	finish("armorPen", 0, {})
	finish("lifesteal", 0, {})

	-- Defense
	finish("armor", F.armorPerVit * VIT + F.armorPerStr * STR, {
		{ key = "breakdown.vit", value = F.armorPerVit * VIT },
		{ key = "breakdown.str", value = F.armorPerStr * STR },
	})
	finish("mres", F.mresPerInt * INT + F.mresPerVit * VIT, {
		{ key = "breakdown.int", value = F.mresPerInt * INT },
		{ key = "breakdown.vit", value = F.mresPerVit * VIT },
	})
	finish("dodge", F.dodgePerDex * DEX, { { key = "breakdown.dex", value = F.dodgePerDex * DEX } })
	for _, id in { "resFire", "resIce", "resLightning", "resPoison" } do
		finish(id, 0, {})
	end

	-- Regeneration (per second)
	local maxHp, maxMana = values.maxHp, values.maxMana
	finish(
		"hpRegen",
		maxHp * F.hpRegenPct / 100,
		{ { key = "breakdown.maxHpPct", value = maxHp * F.hpRegenPct / 100 } }
	)
	do
		-- In-combat regen shares the gear hpRegen bonus.
		local base = maxHp * F.hpRegenCombatPct / 100
		local parts: { Part } = { { key = "breakdown.maxHpPct", value = base } }
		sourceParts("hpRegen", parts, true, false)
		values.hpRegenCombat = base + (flat.hpRegen or 0)
		breakdown.hpRegenCombat = parts
	end
	finish(
		"manaRegen",
		maxMana * F.manaRegenPct / 100,
		{ { key = "breakdown.maxManaPct", value = maxMana * F.manaRegenPct / 100 } }
	)
	finish("energyRegen", F.energyRegenBase, { { key = "breakdown.base", value = F.energyRegenBase } })

	-- Other
	finish("moveSpeed", 0, {})
	finish("expBonus", 0, {})
	finish("dropBonus", 0, {})
	finish("goldBonus", 0, {})
	finish("potionDiscount", 0, {})

	return {
		primary = primary,
		values = values,
		breakdown = breakdown,
		walkSpeed = F.walkSpeed * (1 + values.moveSpeed / 100),
	}
end

-- Sums sources into single flat/pct tables (sent to the client so it can preview stat allocation).
function StatCalc.merge(sources: { Source }, key: string): Source
	local merged: Source = { key = key, flat = {}, pct = {} }
	for _, source in sources do
		for id, v in entries(source.flat) do
			(merged.flat :: any)[id] = ((merged.flat :: any)[id] or 0) + v
		end
		for id, v in entries(source.pct) do
			(merged.pct :: any)[id] = ((merged.pct :: any)[id] or 0) + v
		end
	end
	return merged
end

return StatCalc
