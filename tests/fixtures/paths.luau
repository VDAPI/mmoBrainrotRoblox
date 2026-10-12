--!strict
-- Test class paths (S57): the shape every class session copies (Data/Paths/<Class>). Never in the game or on the
-- wiki: only tests/paths.spec reads it, through Paths.withSource(Fixture.source).
-- Class "Mage" with two paths, so rows 2, 5 and 10 carry the twoPathExtra node. fxStorm is written out and shows
-- every node kind; fxRune is generated with the same layout, mostly passives.
-- Ranks: 49 per path (rows 1-2: 13), so 49 + 13 = 62 for the class and pointsAt(100) = 50 covers ~81%.

local Build = require("../../src/shared/Data/Skills/Build")
local Paths = require("../../src/shared/Logic/Paths")

local skills = Build.class("Mage", "mana", "magic", {
	-- fxStorm
	{
		id = "fxSpark",
		path = "fxStorm",
		unlock = 10,
		maxLevel = 10,
		type = "projectile",
		cost = 10,
		cooldown = 4,
		range = 30,
		values = { dmg = { 100, 200 } },
		breakpoints = Build.bp2({ a = { pierce = 20 }, b = { add = { hits = 1 } } }, { a = { pierce = 40 } }),
		glyph = "*",
	},
	{
		id = "fxBolt",
		path = "fxStorm",
		unlock = 26,
		maxLevel = 10,
		type = "projectile",
		cost = 12,
		cooldown = 5,
		range = 30,
		values = { dmg = { 150, 250 } },
		glyph = "*",
	},
	{
		id = "fxNova",
		path = "fxStorm",
		unlock = 48,
		maxLevel = 10,
		type = "circleSelf",
		cost = 20,
		cooldown = 10,
		radius = 10,
		values = { dmg = { 120, 220 } },
		glyph = "*",
	},
	{
		id = "fxCataclysm",
		path = "fxStorm",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		cost = 40,
		cooldown = 30,
		range = 30,
		radius = 12,
		values = { dmg = { 300, 500 } },
		glyph = "*",
	},
	{
		id = "fxComet",
		path = "fxStorm",
		unlock = 80,
		maxLevel = 10,
		type = "projectile",
		cost = 30,
		cooldown = 12,
		range = 35,
		values = { dmg = { 250, 350 } },
		glyph = "*",
	},
	-- fxRune
	{
		id = "fxGlyph",
		path = "fxRune",
		unlock = 10,
		maxLevel = 5,
		type = "passive",
		values = { int = { 2, 10 } },
		passive = { flat = { int = "int" } },
		glyph = "*",
	},
	{
		id = "fxRuneBolt",
		path = "fxRune",
		unlock = 26,
		maxLevel = 10,
		type = "projectile",
		cost = 12,
		cooldown = 5,
		range = 30,
		values = { dmg = { 150, 250 } },
		glyph = "*",
	},
	{
		id = "fxSeal",
		path = "fxRune",
		unlock = 48,
		maxLevel = 10,
		type = "debuff",
		cost = 15,
		cooldown = 12,
		range = 30,
		duration = 5,
		values = { weak = 10 },
		glyph = "*",
	},
	{
		id = "fxRuneStorm",
		path = "fxRune",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		cost = 40,
		cooldown = 30,
		range = 30,
		radius = 12,
		values = { dmg = { 300, 500 } },
		glyph = "*",
	},
	{
		id = "fxRuneComet",
		path = "fxRune",
		unlock = 80,
		maxLevel = 10,
		type = "projectile",
		cost = 30,
		cooldown = 12,
		range = 35,
		values = { dmg = { 250, 350 } },
		glyph = "*",
	},
	-- a skill of a path without a PathDef: unreachable in the game, hidden on the wiki
	{
		id = "fxOrphan",
		path = "fxGone",
		unlock = 10,
		maxLevel = 10,
		type = "target",
		cost = 5,
		cooldown = 3,
		range = 20,
		values = { dmg = { 100, 150 } },
		glyph = "*",
	},
})

local function node(pathId: string, name: string, kind: string, maxRank: number, fields: { [string]: any }?): any
	local out: { [string]: any } = {
		id = `{pathId}_{name}`,
		kind = kind,
		maxRank = maxRank,
		glyph = "*",
		nameKey = `path.{pathId}.{name}.name`,
		descKey = `path.{pathId}.{name}.desc`,
	}
	for key, value in fields or {} do
		out[key] = value
	end
	return out
end

local function skillNode(pathId: string, skillId: string): any
	return {
		id = `{pathId}_{skillId}`,
		kind = "skill",
		maxRank = 1,
		skill = skillId,
		glyph = "*",
		nameKey = `skill.{skillId}.name`,
		descKey = `skill.{skillId}.desc`,
	}
end

local function passive(pathId: string, name: string, kind: "flat" | "pct" | "hooks", stat: string, extra: any?): any
	local fields: { [string]: any } = { values = { v = { 1, 3 } }, passive = { [kind] = { [stat] = "v" } } }
	for key, value in extra or {} do
		fields[key] = value
	end
	return node(pathId, name, "passive", 3, fields)
end

local S = "fxStorm"
local storm = {
	id = S,
	class = "Mage",
	order = 1,
	role = "damage",
	nameKey = "path.fxStorm.name",
	descKey = "path.fxStorm.desc",
	titleId = "path_fxStorm",
	weapon = { main = { "staff", "wand" }, offhand = { "orb" } },
	rows = {
		{
			choice = false,
			nodes = {
				skillNode(S, "fxSpark"),
				node(S, "focus", "passive", 3, { values = { int = { 2, 6 } }, passive = { flat = { int = "int" } } }),
			},
		},
		{
			choice = false,
			nodes = {
				node(S, "beacon", "aura", 3, {
					values = { atk = { 2, 6 } },
					aura = { category = "allyAttack", stats = { magAtk = "atk" } },
				}),
				node(S, "hex", "modify", 3, {
					values = { guard = { 3, 9 } },
					modify = {
						skill = "fxSpark",
						bp = {
							values = { hexGuard = { ref = "guard" } },
							allyEffect = {
								kind = "damageReduction",
								category = "allyGuard",
								value = "hexGuard",
								duration = 4,
								target = "allies",
							},
						},
					},
				}),
				passive(S, "ward", "pct", "maxHp", { extra = true, dipScale = 0.5 }),
			},
		},
		{
			choice = true,
			nodes = {
				node(S, "surge", "modify", 3, {
					values = { cd = { 0.9, 0.7 } },
					modify = { skill = "fxSpark", bp = { mul = { cooldown = { ref = "cd" } } } },
				}),
				node(S, "echo", "modify", 3, {
					values = { range = { 2, 6 } },
					modify = { skill = "fxSpark", option = "b", at = 5, bp = { add = { range = { ref = "range" } } } },
				}),
			},
		},
		{
			choice = false,
			nodes = { skillNode(S, "fxBolt"), passive(S, "power", "pct", "magAtk") },
		},
		{
			choice = false,
			nodes = {
				passive(S, "overload", "hooks", "overload"),
				node(S, "reach", "modify", 3, {
					values = { range = { 2, 6 } },
					modify = { skill = "fxBolt", bp = { add = { range = { ref = "range" } } } },
				}),
				passive(S, "grit", "flat", "vit", { extra = true }),
			},
		},
		{
			choice = true,
			nodes = { passive(S, "calm", "pct", "maxMana"), passive(S, "rage", "flat", "int") },
		},
		{
			choice = false,
			nodes = {
				skillNode(S, "fxNova"),
				node(S, "static", "modify", 3, {
					values = { dmg = { 10, 30 } },
					modify = { skill = "fxSpark", bp = { values = { dmg = { ref = "dmg" } } } },
				}),
			},
		},
		{ choice = false, nodes = { skillNode(S, "fxCataclysm") } },
		{
			choice = true,
			nodes = {
				node(S, "fury", "modify", 3, {
					values = { dmg = { 20, 60 } },
					modify = { skill = "fxSpark", bp = { values = { dmg = { ref = "dmg" } } } },
				}),
				passive(S, "poise", "flat", "int"),
			},
		},
		{
			choice = false,
			nodes = {
				skillNode(S, "fxComet"),
				passive(S, "tempest", "pct", "magAtk"),
				passive(S, "squall", "flat", "int", { extra = true }),
			},
		},
		{
			choice = false,
			nodes = {
				node(S, "cataclysmPlus", "modify", 2, {
					values = { radius = { 1, 2 } },
					modify = { skill = "fxCataclysm", bp = { add = { radius = { ref = "radius" } } } },
				}),
			},
		},
	},
	reference = {},
	wiki = false,
}

local R = "fxRune"
local rune = {
	id = R,
	class = "Mage",
	order = 2,
	role = "damage",
	nameKey = "path.fxRune.name",
	descKey = "path.fxRune.desc",
	titleId = "path_fxRune",
	weapon = { main = { "runestaff", "wand" }, offhand = { "tome" } },
	rows = {
		{
			choice = false,
			nodes = {
				skillNode(R, "fxGlyph"),
				-- an ally effect without a category (invulnerability) is not a team effect: full strength anywhere
				node(R, "mend", "modify", 3, {
					modify = {
						skill = "fxRuneBolt",
						bp = { allyEffect = { kind = "invuln", duration = 2, target = "allies" } },
					},
				}),
			},
		},
		{
			choice = false,
			nodes = {
				passive(R, "r2a", "flat", "int"),
				passive(R, "r2b", "pct", "maxMana"),
				passive(R, "r2x", "flat", "vit", { extra = true }),
			},
		},
		{ choice = true, nodes = { passive(R, "r3a", "flat", "int"), passive(R, "r3b", "flat", "vit") } },
		{ choice = false, nodes = { skillNode(R, "fxRuneBolt"), passive(R, "r4", "pct", "magAtk") } },
		{
			choice = false,
			nodes = {
				passive(R, "r5a", "flat", "int"),
				passive(R, "r5b", "pct", "maxHp"),
				passive(R, "r5x", "flat", "vit", { extra = true }),
			},
		},
		{ choice = true, nodes = { passive(R, "r6a", "flat", "int"), passive(R, "r6b", "flat", "vit") } },
		{ choice = false, nodes = { skillNode(R, "fxSeal"), passive(R, "r7", "pct", "magAtk") } },
		{ choice = false, nodes = { skillNode(R, "fxRuneStorm") } },
		{ choice = true, nodes = { passive(R, "r9a", "flat", "int"), passive(R, "r9b", "flat", "vit") } },
		{
			choice = false,
			nodes = {
				skillNode(R, "fxRuneComet"),
				passive(R, "r10", "pct", "magAtk"),
				passive(R, "r10x", "flat", "int", { extra = true }),
			},
		},
		{
			choice = false,
			nodes = {
				node(
					R,
					"runeStormPlus",
					"passive",
					2,
					{ values = { v = { 2, 4 } }, passive = { pct = { magAtk = "v" } } }
				),
			},
		},
	},
	reference = {},
	wiki = false,
}

-- A model build: every rank of the path (first node of each choice row) plus the row-1 skill of the other path.
local function fullBuild(path: any, other: any, weapon: any, bp: any?): any
	local nodes = {}
	for _, row in path.rows do
		for _, n in row.nodes do
			table.insert(nodes, { n.id, n.maxRank })
			if row.choice then
				break
			end
		end
	end
	table.insert(nodes, { other.rows[1].nodes[1].id, 1 })
	return { id = `{path.id}_ref`, weapon = weapon, nodes = nodes, bp = bp }
end

storm.reference = { fullBuild(storm, rune, { main = "staff" }, { ["fxSpark:5"] = "b" }) }
rune.reference = { fullBuild(rune, storm, { main = "runestaff" }, nil) }

local paths = { storm, rune } :: { any }

return {
	skills = skills,
	paths = paths,
	source = Paths.sourceOf(paths, skills),
}
