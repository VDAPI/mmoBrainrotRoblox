--!strict
-- Owner 2026-10-20: a character that out-levels an Elite, an Elite II or a dungeon boss by Config.LevelLock.gap or more
-- cannot hurt it, so the players of its level band get to fight it (no farming of low elites and bosses by high
-- characters). Ordinary monsters and the world boss are never locked. Pure.

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

return LevelLock
