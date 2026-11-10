--!strict
-- Collision groups of the bodies in the world (Services/BodyGroupService registers them and puts every part in its
-- group). Owner 2026-11-10 ("monsters run into me and I climb on them"; then "they may block, but no climbing"): a
-- monster's root box (Entities/RigBuilder, standing at its hip height) lifted a player who walked into it or whom it
-- ran into. Now the root never touches a player; a player bumps into the monster's "Blocker" instead: an invisible
-- column from the root's bottom to at least BLOCK_TOP studs over the feet, higher than a jump reaches, that collides
-- with player characters only (never with the world, so the monster walks as before). A monster blocks the way like a
-- wall and nobody stands on one. Monsters still bump into monsters (a pack does not melt into one spot), players into
-- players, and both stand on the world. Quest companions (S101b, CompanionService) touch no body at all. Pure (Lune):
-- tests/bodygroups.spec.

local BodyGroups = {}

BodyGroups.PLAYERS = "Players" -- player characters (everything under the character model)
BodyGroups.MONSTERS = "Monsters" -- everything under Workspace.Monsters (bosses included)
BodyGroups.COMPANIONS = "Companions" -- the quest companions' figures
BodyGroups.BLOCKERS = "MonsterBlockers" -- the monsters' blockers: they touch player characters only

-- The name of a monster's blocker part (under its model, welded to the root).
BodyGroups.BLOCKER = "Blocker"
-- Studs over the feet a blocker reaches at least: over a jump (Roblox's default jump lifts the feet 7.2 studs), so a
-- player can neither step nor jump onto a monster.
BodyGroups.BLOCK_TOP = 9.5

-- Every group this game registers (Roblox allows 32 in all, "Default" included).
BodyGroups.ALL = table.freeze({ BodyGroups.PLAYERS, BodyGroups.MONSTERS, BodyGroups.COMPANIONS, BodyGroups.BLOCKERS })

-- The pairs that never collide; every other pair collides as Roblox's default does.
BodyGroups.APART = table.freeze({
	table.freeze({ BodyGroups.PLAYERS, BodyGroups.MONSTERS }),
	table.freeze({ BodyGroups.COMPANIONS, BodyGroups.PLAYERS }),
	table.freeze({ BodyGroups.COMPANIONS, BodyGroups.MONSTERS }),
	table.freeze({ BodyGroups.COMPANIONS, BodyGroups.COMPANIONS }),
	table.freeze({ BodyGroups.BLOCKERS, "Default" }),
	table.freeze({ BodyGroups.BLOCKERS, BodyGroups.MONSTERS }),
	table.freeze({ BodyGroups.BLOCKERS, BodyGroups.BLOCKERS }),
	table.freeze({ BodyGroups.BLOCKERS, BodyGroups.COMPANIONS }),
})

-- The group of a part under Workspace.Monsters: a blocker keeps its own, everything else is the monster's.
function BodyGroups.monsterPart(name: string): string
	return if name == BodyGroups.BLOCKER then BodyGroups.BLOCKERS else BodyGroups.MONSTERS
end

-- A monster's blocker in its root's frame (y up): from the root box's bottom (the root stands `hipHeight` over the
-- feet, `rootSize` = { x, y, z }) to BLOCK_TOP over the feet, or to the drawn top (`drawn`) of a taller monster or the
-- root's own top, whichever is highest; as wide and deep as the root. Returns its size and its centre's height over
-- the root's centre.
function BodyGroups.blocker(rootSize: { number }, hipHeight: number, drawn: number): ({ number }, number)
	local feet = -(hipHeight + rootSize[2] / 2) -- the feet under the root's centre
	local bottom = -rootSize[2] / 2
	local top = math.max(feet + BodyGroups.BLOCK_TOP, feet + drawn, rootSize[2] / 2)
	return { rootSize[1], top - bottom, rootSize[3] }, (top + bottom) / 2
end

-- Whether parts of group `a` and of group `b` collide.
function BodyGroups.collide(a: string, b: string): boolean
	for _, pair in BodyGroups.APART do
		if (pair[1] == a and pair[2] == b) or (pair[1] == b and pair[2] == a) then
			return false
		end
	end
	return true
end

return BodyGroups
