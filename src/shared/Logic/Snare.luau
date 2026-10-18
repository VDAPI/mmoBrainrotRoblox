--!strict
-- S144 (DESIGN-18 §6.3): a root of the Hunter (Pinning Shot, Net Shot; SkillEffect.bossSlow) on a boss or an Elite II.
-- Pure. Such targets never stand still: the root becomes a slow of the effect's bossSlow % (category enemySlow) for the
-- same time; any other target is rooted. A player in PvP gets the root with the crowd-control rule of every root
-- (Config.PvpCcMultiplier in StatusEffectService).

local Snare = {}

Snare.SLOW_CATEGORY = "enemySlow"

-- The kind an effect lands as: "slow" for a root with bossSlow on a boss-like target, else its own kind.
function Snare.kindOn(kind: string, bossLike: boolean, bossSlow: number?): string
	if kind == "root" and bossLike and bossSlow ~= nil and bossSlow > 0 then
		return "slow"
	end
	return kind
end

return table.freeze(Snare)
