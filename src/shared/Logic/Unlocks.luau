--!strict
-- S155b: what a level up unlocks (pure). A level up that crosses an entry's level shows a toast naming the feature
-- (UnlockController) and, for an entry with a `window`, a "!" on that HUD menu button until the window is first opened
-- (UI/FreshUnlocks). The levels come from the systems themselves, so the list never disagrees with the game.

local Arena = require("../Data/Arena")
local Bosses = require("../Data/Bosses")
local Config = require("../Config")

local Unlocks = {}

export type Entry = {
	id: string,
	level: number,
	window: string?, -- the HUD menu entry / window id that gets the "!" (nil: a toast only)
	textKey: string, -- unlock.<id>
}

local function entry(id: string, level: number, window: string?): Entry
	return table.freeze({ id = id, level = level, window = window, textKey = `unlock.{id}` })
end

-- The lowest entry level of a dungeon (the first boss of Data/Bosses.list).
local function firstDungeon(): number
	local lowest = math.huge
	for _, boss in Bosses.list do
		lowest = math.min(lowest, boss.level - Bosses.ENTRY_GAP)
	end
	return if lowest == math.huge then 0 else lowest
end

Unlocks.LIST = table.freeze({
	entry("dungeon", firstDungeon()),
	entry("mounts", Config.Mount.minLevel, "mounts"),
	entry("arena", Arena.MIN_LEVEL, "arena"),
} :: { Entry })

-- The entries a level up from `from` to `to` unlocks (from < level <= to), in LIST order.
function Unlocks.crossed(from: number, to: number): { Entry }
	local out: { Entry } = {}
	for _, e in Unlocks.LIST do
		if e.level > 0 and from < e.level and e.level <= to then
			table.insert(out, e)
		end
	end
	return out
end

return Unlocks
