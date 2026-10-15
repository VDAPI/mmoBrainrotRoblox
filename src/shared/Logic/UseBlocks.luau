--!strict
-- Where the premium consumables refuse to work (DESIGN-17 §3, S122). One list per feature, checked in order; the
-- first active reason wins and its text is `<prefix>.block.<reason>`. WHO decides whether a reason is active lives
-- on the server (src/server/UseGuards.luau): every owning service registers one check in its Start. A reason with
-- no check yet is never active (PENDING: the session that builds the feature registers it and removes the entry).

export type Feature = "fullElixir" | "lure"
export type Reason =
	"dead"
	| "duel"
	| "arena"
	| "dungeon"
	| "pvpLock"
	| "city"
	| "underground"
	| "redZone"
	| "mounted"
	| "bloodMoon"
	| "tourney"

local UseBlocks = {}

UseBlocks.LISTS = table.freeze({
	-- DESIGN-17 §3: duel and arena (DuelService / ArenaService), boss dungeon, the 15 s PvP lock, Blood Moon, tournament
	fullElixir = table.freeze({ "dead", "duel", "arena", "dungeon", "pvpLock", "bloodMoon", "tourney" }),
	-- DESIGN-17 §3: city, caves and dungeons, red zone, arena, Blood Moon, on a mount, dead
	lure = table.freeze({ "dead", "city", "underground", "redZone", "arena", "bloodMoon", "mounted" }),
})
UseBlocks.PREFIX = table.freeze({ fullElixir = "fullElixir", lure = "lure" })
-- Reasons whose check a later session registers (no check = never blocks until then). S129 registered bloodMoon
-- (BloodMoonService).
local PENDING: { [string]: string } = { tourney = "S130" }
UseBlocks.PENDING = table.freeze(PENDING)
-- Reasons that have a check now and get one more later (documentation for S126/S127). S127 registered the arena
-- server (UseGuards "arena", owner "ServerMode"): nothing left.
local LATER: { [string]: string } = {}
UseBlocks.LATER = table.freeze(LATER)
-- Map biomes that count as "underground" for the lure (DESIGN-17 §3: cave / crypt / dungeon).
local UNDERGROUND: { [string]: boolean } = { cave = true, crypt = true, dungeon = true }
UseBlocks.UNDERGROUND = table.freeze(UNDERGROUND)

-- The Locale key of a block: "<prefix>.block.<reason>".
function UseBlocks.key(feature: Feature, reason: string): string
	return `{UseBlocks.PREFIX[feature]}.block.{reason}`
end

-- The first reason of the feature's list that is active (list order); reasons outside the list are ignored.
function UseBlocks.first(feature: Feature, active: { [string]: boolean }): string?
	for _, reason in UseBlocks.LISTS[feature] do
		if active[reason] == true then
			return reason
		end
	end
	return nil
end

-- Every reason of every list, once, sorted (tests, /useblocks).
function UseBlocks.reasons(): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, list in { UseBlocks.LISTS.fullElixir, UseBlocks.LISTS.lure } do
		for _, reason in list do
			if not seen[reason] then
				seen[reason] = true
				table.insert(out, reason)
			end
		end
	end
	table.sort(out)
	return out
end

return UseBlocks
