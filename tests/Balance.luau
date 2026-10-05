--!strict
-- Fight model used by balance.spec (DESIGN §15.1 target: a player with gear of their level kills a normal
-- monster of their level in about 6-10 s and loses 15-30% HP). Expected values, no randomness.

local Bases = require("../src/shared/Data/Items/Bases")
local Classes = require("../src/shared/Data/Classes")
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local StatCalc = require("../src/shared/Logic/StatCalc")

local Balance = {}

-- Main weapon and armour weight per class.
Balance.LOADOUT = {
	Warrior = { weapon = "sword1h", weight = "heavy" },
	Hunter = { weapon = "bow", weight = "medium" },
	Mage = { weapon = "wand", weight = "light" },
	Cleric = { weapon = "mace1h", weight = "heavy" },
}

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

export type Fight = { killSeconds: number, hpLost: number, playerHp: number, monsterHp: number }

-- One player of `classId` with common gear of `level` against a normal monster of the same level.
function Balance.fight(classId: string, level: number): Fight
	local loadout = Balance.LOADOUT[classId]
	local class = Classes.get(classId) :: Classes.ClassDef
	local base = Bases.byType[loadout.weapon]
	local weapon = (base.weapon :: any)(level)
	local flat: { [string]: number } = {}
	for _, slot in { "helmet", "armor", "gloves", "boots" } do
		local piece = Bases.byType[`{slot}_{loadout.weight}`]
		for id, v in (piece.stats :: any)(level) do
			flat[id] = (flat[id] or 0) + v
		end
	end
	local result = StatCalc.compute({
		level = level,
		stats = Balance.statsFor(classId, level),
		sources = { { key = "gear", flat = flat } },
		weapon = { dmg = weapon.dmg, mdmg = weapon.mdmg, speed = weapon.speed, ranged = weapon.ranged },
	})
	local v = result.values
	local monster = MonsterStats.compute({ hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }, level)

	local magic = class.basicAttack.kind == "magic"
	local attack = if magic then v.magAtk else v.physAtk
	local defense = if magic then monster.mres else monster.armor
	local critFactor = 1 + math.min(v.critChance, 100) / 100 * ((v.critDmg or 150) / 100 - 1)
	local perHit = attack * (1 - Damage.reduction(defense, level)) * critFactor
	local dps = perHit * v.atkSpeed
	local killSeconds = monster.maxHp / dps

	local monsterHit = monster.attack
		* (1 - Damage.reduction(v.armor, monster.level))
		* (1 + Combat.monsterCritChance / 100 * (Combat.monsterCritDmg / 100 - 1))
		* (1 - math.min(v.dodge or 0, Combat.dodgeCap) / 100)
	-- The monster swings once right away, then every attackInterval.
	local swings = 1 + math.floor(killSeconds / monster.attackInterval)
	local lost = swings * monsterHit
	return { killSeconds = killSeconds, hpLost = lost / v.maxHp, playerHp = v.maxHp, monsterHp = monster.maxHp }
end

return Balance
