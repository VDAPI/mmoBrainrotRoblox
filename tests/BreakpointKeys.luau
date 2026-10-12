--!strict
-- Known breakpoint keys (Data/Skills/Types Breakpoint), a helper of tests/skillmotion.spec (skill breakpoints) and
-- tests/paths.spec (modify.bp of path nodes, S71). Not a spec itself.

local KEYS: { [string]: boolean } = {}
for _, key in
	{
		"add",
		"mul",
		"values",
		"pull",
		"knockback",
		"castMove",
		"stunNear",
		"bleedStacks",
		"lingering",
		"echo",
		"pierce",
		"execute",
		"trap",
		"split",
		"stunLast",
		"splash",
		"secondTarget",
		"overhealShield",
		"cleanse",
		"lifesteal",
		"selfHeal",
		"healWounded",
		"chainHeal",
		"healZone",
		"roll", -- S70
		"rollDouble",
		"steadfast",
		"burst",
		"stunSplash", -- S71
		"shieldBurst",
		"tauntNear", -- S73
		"shieldPerHit",
		"extendOnKill",
		"behindEffect",
		"allyHeal",
		"allyShield",
		"poisonStacks", -- S76
		"critCdr",
		"finisher",
		"poisonSpread",
		"markJump",
		"firstWave",
		"effect",
		"selfEffect",
		"allyEffect",
	}
do
	KEYS[key] = true
end

return KEYS
