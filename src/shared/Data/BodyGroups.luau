--!strict
-- Collision groups of the bodies in the world (Services/BodyGroupService registers them and puts every part in its
-- group). Owner 2026-11-10 ("monsters run into me and I climb on them"; then "they may block, but no climbing"): a
-- monster's root box (Entities/RigBuilder, standing at its hip height) lifted a player who walked into it or whom it
-- ran into. Now the root never touches a player; a player bumps into the monster's "Blocker" instead: an invisible
-- column from the root's bottom to at least BLOCK_TOP studs over the feet, over the highest a player's body gets
-- beside a monster (a rider's seat, a jump and a slope), that collides with player characters only (never with the
-- world, so the monster walks as before). A monster blocks the way like a wall: nobody steps, jumps or rides onto one.
-- The column is finite, so a player can still come down on it from above (a ledge, a cliff, a jump off a rock); the
-- client slides its character off then (Logic/BlockerGuard, MovementController). Monsters still bump into monsters (a
-- pack does not melt into one spot), players into players, and both stand on the world. Quest companions (S101b,
-- CompanionService) touch no body at all. Pure (Lune): tests/bodygroups.spec.

local BodyGroups = {}

BodyGroups.PLAYERS = "Players" -- player characters (everything under the character model)
BodyGroups.MONSTERS = "Monsters" -- everything under Workspace.Monsters (bosses included)
BodyGroups.COMPANIONS = "Companions" -- the quest companions' figures
BodyGroups.BLOCKERS = "MonsterBlockers" -- the monsters' blockers: they touch player characters only

-- The name of a monster's blocker part (under its model, welded to the root).
BodyGroups.BLOCKER = "Blocker"
-- How high a player's body gets beside a monster: a Humanoid stands on its root's bottom, HipHeight over the ground (2
-- on foot; a rider's seat, Logic/Mounts.seatAt, raises it to ~4.4 on the procedural boss horses), a jump lifts it
-- JUMP_RISE more (Roblox's default JumpHeight: nothing in the code or the project sets JumpHeight or JumpPower, and the
-- legacy JumpPower 50 lifts less, 6.4) and the ground it jumps from may stand SLOPE over the monster's feet (a slope, a
-- rock, a step).
BodyGroups.JUMP_RISE = 7.2
BodyGroups.SLOPE = 2
-- Studs over the feet a blocker reaches at least: over all of that (review 2026-11-10: at 9.5 a rider hopped onto a
-- wolf's column and rode the wolf). tests/bodygroups.spec keeps it over every mount's seat + JUMP_RISE + SLOPE, so a
-- taller mount breaks a test, not the game; the column ignores the world, so its height costs nothing there.
BodyGroups.BLOCK_TOP = 16

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

-- A monster's body without its blocker, before the client builds its look (client/Util/MonsterBox): its root extended
-- down to the feet. In the root's frame like `blocker`: its size and its centre's height over the root's centre.
function BodyGroups.bodyBox(rootSize: { number }, hipHeight: number): ({ number }, number)
	return { rootSize[1], rootSize[2] + hipHeight, rootSize[3] }, -hipHeight / 2
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
