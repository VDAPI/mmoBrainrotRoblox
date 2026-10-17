--!strict
-- Class paths (ROZWOJ 2.2-2.4, 3.1, S57): the shared row layout and every path of every class. Rules in Logic/Paths.
-- S138 (DESIGN-18 §7): paths are mixable "directions": no main path and no path weapon; every row of every direction
-- opens with its level and the ranks in the lower rows of that direction; one capstone per build set.

local Classes = require("./Classes")
local Cleric = require("@self/Cleric")
local Hunter = require("@self/Hunter")
local Mage = require("@self/Mage")
local Types = require("@self/Types")
local Warrior = require("@self/Warrior")

export type Scaled = Types.Scaled
export type WeaponReq = Types.WeaponReq
export type NodeKind = Types.NodeKind
export type PathNode = Types.PathNode
export type PathRow = Types.PathRow
export type ReferenceBuild = Types.ReferenceBuild
export type Role = Types.Role
export type PathDef = Types.PathDef
export type RowKind = Types.RowKind
export type RowDef = Types.RowDef

-- ROZWOJ 2.2: row levels and the ranks needed in the lower rows of the same path. Rows 3, 6, 9 pick 1 of 2 nodes,
-- row 8 is the capstone (one node, rank 1; S138: CAPSTONES_MAX per set), row 11 its upgrade (one node, rank 2; only in
-- the direction with the capstone). In a class with two paths rows 2, 5 and 10 get one extra node (twoPathExtra).
local ROWS: { RowDef } = {
	{ level = 10, need = 0, kind = "normal" },
	{ level = 15, need = 2, kind = "normal", twoPathExtra = true },
	{ level = 20, need = 4, kind = "choice" },
	{ level = 26, need = 6, kind = "normal" },
	{ level = 33, need = 9, kind = "normal", twoPathExtra = true },
	{ level = 40, need = 12, kind = "choice" },
	{ level = 48, need = 15, kind = "normal" },
	{ level = 60, need = 18, kind = "capstone" },
	{ level = 70, need = 21, kind = "choice" },
	{ level = 80, need = 24, kind = "normal", twoPathExtra = true },
	{ level = 90, need = 28, kind = "upgrade" },
}

local byClassFile: { [string]: { PathDef } } = {
	Warrior = Warrior,
	Hunter = Hunter,
	Mage = Mage,
	Cleric = Cleric,
}

local list: { PathDef } = {}
local byId: { [string]: PathDef } = {}
local byClass: { [string]: { PathDef } } = {}
local nodeIds: { [string]: boolean } = {}

for _, classId in Classes.order do
	local own = table.clone(byClassFile[classId] or {})
	table.sort(own, function(a: PathDef, b: PathDef): boolean
		return a.order < b.order
	end)
	byClass[classId] = own
	for _, path in own do
		assert(byId[path.id] == nil, `Paths: duplicate id {path.id}`)
		assert(path.class == classId, `Paths: {path.id} is in the {classId} file but has class {path.class}`)
		assert(#path.rows == #ROWS, `Paths: {path.id} needs {#ROWS} rows`)
		byId[path.id] = path
		table.insert(list, path)
		for _, row in path.rows do
			for _, node in row.nodes do
				assert(nodeIds[node.id] == nil, `Paths: duplicate node id {node.id}`)
				nodeIds[node.id] = true
			end
		end
	end
end

return table.freeze({
	ROWS = ROWS,
	DIP_ROWS = 2, -- S138: rows whose team nodes work at DIP_SCALE in a direction with < TEAM_FULL_POINTS ranks
	DIP_SCALE = 1 / 3, -- team effect strength of those nodes (node.dipScale overrides it)
	-- S138 (DESIGN-18 §7): capstones (row kind "capstone") bought in at most this many directions of a set
	CAPSTONES_MAX = 1,
	-- the leading direction (Logic/Paths.mainOf: title, stat plan, item weights, party sign) needs this many ranks
	MAIN_MIN_POINTS = 12,
	-- from this many ranks in a direction its team nodes of rows 1..DIP_ROWS work in full
	TEAM_FULL_POINTS = 6,
	-- the target rows of "skill" nodes (at most one each per direction); tests/paths.spec asserts it only for classes
	-- whose pools are no longer transitional (Data/SkillPools.<Class>.transitional)
	SKILL_ROWS = table.freeze({ 4, 8 }),
	-- ROZWOJ 7.3: party auras from path nodes (PartyAuraService, Logic/Paths.inAura).
	AURA = table.freeze({
		radius = 30, -- "circle" default
		behindRadius = 15, -- "behind": receivers up to this far from the owner
		behindAngle = 120, -- cone behind the owner (60 degrees each side of the threat -> owner line)
		fallbackRange = 40, -- no target: nearest monster fighting the owner within this range
		tick = 1, -- s between PartyAuraService passes
		duration = 1.5, -- s of each refreshed buff
		maxRadius = 40, -- data rule (ROZWOJ 7.3)
	}),
	-- S72 (ROZWOJ 10.3, 10.4): fixed parts of the path hook rules. Hook values come from the nodes (Warrior: S75);
	-- these numbers are the rules around them. Not exported to the wiki (Data/Combat is exported whole, so they
	-- do not live there). Later class engines add their own entries to this table (Hunter: S77).
	HOOK_RULES = table.freeze({
		-- Fury of the Berserker: stacks up to the furyMax hook, never above maxStacks; +1 for each hit that deals
		-- damage (basic attack, skill hit or wave; DoT ticks, thorns and reflections do not count), at most one gain
		-- per gainInterval seconds; after decayAfter seconds without a hit it loses decayPerSecond stacks per
		-- second; out of combat it is gone. Stats from Fury recompute at most every statInterval seconds.
		fury = table.freeze({
			maxStacks = 10,
			gainInterval = 0.25,
			decayAfter = 4,
			decayPerSecond = 2,
			statInterval = 0.25,
		}),
		-- While Carnage lasts, Fury does not decay and grows by furyGain per hit; every killing blow of the player
		-- ends the cooldown of these skills.
		carnage = table.freeze({ furyGain = 2, resets = table.freeze({ "charge", "bladeWhirl" }) }),
		-- "Per enemy" hooks (guardPerEnemy, damagePerEnemy) count living monsters within `radius` studs of the
		-- player, at most `max` of them.
		perEnemy = table.freeze({ radius = 10, max = 5 }),
		-- Energy a block gives back once the character has block from path nodes (Block, Shield Master).
		blockEnergy = 5,
		-- S77 (ROZWOJ 11.3 / 11.5): Hunter path hooks. Hook values come from the nodes (S78); these are the fixed
		-- parts of the rules. Not exported to the wiki (the planner, S82, reads ROWS / DIP_* only).
		-- Vigilance / Warning: a red zone of a monster within monsterRange of the Scout gives the party within
		-- partyRange the bonus for the windup + extra seconds, each kind at most once per cooldown seconds.
		vigilance = table.freeze({ monsterRange = 30, partyRange = 40, extra = 0.5, cooldown = 8 }),
		-- Spotting: seconds of the vulnerability and the skills (besides basic attacks) whose hits spot. S144: the S1 of
		-- both pools (Aimed Shot of the Bow, Heavy Bolt of the Crossbow)
		spot = table.freeze({ duration = 5, skills = table.freeze({ aimedShot = true, heavyBolt = true }) }),
		weakSpotPerStack = 1, -- % damage per Weak Spot stack on the selected target
		-- Royal Falcon: dive % damage, stun seconds (not bosses, never players), seconds it stays after the fight,
		-- dive points per falconBond second, the shortest strike interval.
		royalFalcon = table.freeze({ dive = 150, stun = 1, linger = 5, bondDive = 10, minInterval = 0.5 }),
		scoutEye = table.freeze({ shareRange = 80 }), -- Scout's Eye (ROZWOJ 11.5): party members within this many studs share the Elite range on the minimap
	}),
	list = list,
	byId = byId,
	byClass = byClass,
	get = function(id: string): PathDef?
		return byId[id]
	end,
})
