--!strict
-- Potion interval (S54, ROZWOJ 8, owner answer 28): Config.PotionCooldown x the "potionCooldown" level curve, so
-- 1.5 s up to level 20, 6 s at 45 and ~10 s from 70. The only source of the interval for PotionService, the potion
-- bar and the wiki. Pure.

local Config = require("../Config")
local LevelCurves = require("./LevelCurves")

local Potions = {}

-- Seconds between two potions of the same kind at character level `level`.
function Potions.interval(level: number): number
	return Config.PotionCooldown * LevelCurves.at("potionCooldown", level)
end

return Potions
