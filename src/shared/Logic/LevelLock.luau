--!strict
-- Owner 2026-10-20: a character that out-levels an Elite, an Elite II or a dungeon boss by Config.LevelLock.gap or more
-- cannot hurt it, so the players of its level band get to fight it (no farming of low elites and bosses by high
-- characters). Ordinary monsters and the world boss are never locked. Pure.
-- S157 (the Margonem rule, the rest of it): a dungeon boss's helpers share its lock, world event monsters are never
-- locked; the server keeps the highest allowed level on the monster (`capLevel`, model attribute `CapLevel`, from
-- LevelLock.capOf), so damage of every kind, threat, kill credit, the dungeon gate and the client's grey target read
-- the same number. Healing and buffs on allies stay free.

local Config = require("../Config")

local LevelLock = {}

local LOCKED: { [string]: boolean } = { elite = true, elite2 = true, boss = true }

-- Whether a character of `playerLevel` is locked out of a monster of `variant` and `monsterLevel` (`worldBoss`: the
-- world boss, never locked).
function LevelLock.blocked(playerLevel: number, monsterLevel: number, variant: string?, worldBoss: boolean?): boolean
	if worldBoss or not variant or not LOCKED[variant] then
		return false
	end
	return playerLevel - monsterLevel >= Config.LevelLock.gap
end

-- S157: what the rule needs to know about a monster.
export type Kind = {
	variant: string, -- "normal" | "elite" | "elite2" | "boss"
	dungeonBoss: boolean?, -- a dungeon boss or a helper it summoned
	worldEvent: boolean?, -- a world event monster (never locked)
	worldBoss: boolean?, -- the world boss or its helpers (never locked)
}

-- S157: whether the lock covers this monster.
function LevelLock.applies(kind: Kind): boolean
	if kind.worldEvent or kind.worldBoss then
		return false
	end
	return kind.dungeonBoss == true or (kind.variant ~= "boss" and LOCKED[kind.variant] == true)
end

-- S157: the highest character level that may still fight a monster of `monsterLevel` (one below the gap).
function LevelLock.maxLevel(monsterLevel: number): number
	return monsterLevel + Config.LevelLock.gap - 1
end

-- S157: the highest allowed level of a monster (nil = no lock).
function LevelLock.capOf(kind: Kind, monsterLevel: number): number?
	return if LevelLock.applies(kind) then LevelLock.maxLevel(monsterLevel) else nil
end

-- S157: whether a character of `playerLevel` is over `cap` (nil = no lock). Exactly the cap is still allowed.
function LevelLock.over(playerLevel: number, cap: number?): boolean
	return cap ~= nil and playerLevel > cap
end

-- S157: the targets a character of `playerLevel` may hit, in their order (an area attack drops the locked ones).
function LevelLock.filter<T>(targets: { T }, playerLevel: number, capOf: (T) -> number?): { T }
	local out: { T } = {}
	for _, target in targets do
		if not LevelLock.over(playerLevel, capOf(target)) then
			table.insert(out, target)
		end
	end
	return out
end

-- S157: why a character of `playerLevel` cannot enter the dungeon of a boss of `bossLevel` (nil = may enter).
function LevelLock.bossEntry(playerLevel: number, bossLevel: number): string?
	return if LevelLock.over(playerLevel, LevelLock.maxLevel(bossLevel)) then "dungeon.reason.overLevel" else nil
end

return LevelLock
