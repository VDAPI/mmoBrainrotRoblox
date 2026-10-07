--!strict
-- Game features the exporter adapts to (S34): sessions S26-S35 add modules and fields; a missing one leaves its
-- wiki field out instead of failing. `exists(path)` is passed in (the CLI and the tests use @lune/fs), so this
-- module stays pure. Present modules are then required normally: an error inside one stays loud.

local Features = {}

export type Set = { [string]: boolean }

-- Feature -> file that proves it.
Features.FILES = {
	sideQuests = "src/shared/Data/Quests/Side.luau", -- S27
	skillMotions = "src/shared/Data/SkillMotions.luau", -- S28 (breakpoints in SkillDef)
	itemValue = "src/shared/Logic/ItemValue.luau", -- S31
	tooltipModel = "src/shared/Logic/TooltipModel.luau", -- S31
	areaProfiles = "src/shared/Data/AreaProfiles.luau", -- S33
	itemIcons = "src/shared/Logic/ItemIcons.luau", -- S35
	itemIconAtlas = "src/shared/Data/ItemIconAtlas.luau", -- S35
	fightSim = "src/shared/Logic/FightSim.luau", -- S32
}

function Features.detect(exists: (path: string) -> boolean): Set
	local set: Set = {}
	for name, path in Features.FILES do
		set[name] = exists(path)
	end
	return set
end

return Features
