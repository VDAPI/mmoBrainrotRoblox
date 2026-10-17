--!strict
-- Admin commands (S23): one entry per command with its category (dev panel tab), usage text key and argument
-- schema. AdminService validates every call (chat or panel) against it with Logic/AdminArgs before the command
-- module (src/server/Admin/<Category>) runs, and the dev panel builds a generic row from it for commands without
-- a dedicated view. Adding a command: an entry here, the implementation in its category module and the
-- `admin.usage.<name>` text in both languages; the panel shows it by itself.

export type ArgKind =
	"integer"
	| "number"
	| "string"
	| "enum"
	| "item"
	| "monster"
	| "map"
	| "area"
	| "npc"
	| "boss"
	| "quest"
	| "blessing"
	| "pass"
	| "player"

export type Arg = {
	name: string,
	kind: ArgKind,
	min: number?,
	max: number?,
	options: { string }?,
	optional: boolean?,
	default: string?,
}

export type Category =
	"character"
	| "items"
	| "world"
	| "monsters"
	| "combat"
	| "quests"
	| "economy"
	| "guild"
	| "perf"
	| "data"

export type Command = {
	name: string,
	category: Category,
	usageKey: string,
	args: { Arg },
	danger: boolean?, -- the panel asks before running it
	dangerActions: { string }?, -- only these first-argument values are dangerous
	studioOnly: boolean?,
}

local Blessings = require("./Blessings")
local ClassLooks = require("./ClassLooks")
local BuffCategories = require("./BuffCategories")
local TerrainShapes = require("./Terrain")
local CaveShapes = require("./CaveShapes")
local Families = require("./Families")

local MAX_LEVEL = 100
local BIG = 1e12

local CATEGORIES: { Category } =
	{ "character", "items", "world", "monsters", "combat", "quests", "economy", "guild", "perf", "data" }

local function int(name: string, min: number, max: number, optional: boolean?, default: string?): Arg
	return { name = name, kind = "integer", min = min, max = max, optional = optional, default = default }
end

local function enum(name: string, options: { string }, optional: boolean?, default: string?): Arg
	return { name = name, kind = "enum", options = options, optional = optional, default = default }
end

local function str(name: string, optional: boolean?): Arg
	return { name = name, kind = "string", optional = optional }
end

local function ref(name: string, kind: ArgKind, optional: boolean?): Arg
	return { name = name, kind = kind, optional = optional }
end

local VARIANT = enum("variant", { "0", "1", "2" }, true, "0")
-- S30: rarities by name (or 1-5 typed in the chat; the panel offers the names).
local RARITY_NAMES = { "common", "unique", "heroic", "legendary", "mythic" }
local FAMILY_ARGS = table.clone(Families.ids :: any) :: { string }
table.insert(FAMILY_ARGS, "random")

local list: { Command } = {}

local function cmd(
	category: Category,
	name: string,
	args: { Arg },
	extra: { danger: boolean?, dangerActions: { string }?, studioOnly: boolean? }?
)
	local e: any = extra or {}
	table.insert(list, {
		name = name,
		category = category,
		usageKey = `admin.usage.{name}`,
		args = args,
		danger = e.danger,
		dangerActions = e.dangerActions,
		studioOnly = e.studioOnly,
	})
end

-- Character
cmd("character", "lvl", { int("level", 1, MAX_LEVEL) })
cmd("character", "exp", { int("amount", 1, BIG) })
cmd("character", "stats", { enum("action", { "reset" }) })
cmd("character", "statpoints", { int("n", 0, 100000) })
cmd("character", "heal", {})
-- S122: the Elixir of Wholeness counter of the character and what blocks the elixir / the cloak now (Logic/UseBlocks)
cmd("character", "elixir", { enum("action", { "info", "reset" }) })
cmd("character", "useblocks", {})
cmd("character", "god", {})
cmd("character", "cd", { enum("mode", { "off", "on" }) })
cmd("character", "res", { enum("mode", { "inf", "off" }) })
cmd("character", "sprint", {})
cmd("character", "speed", { str("value") })
-- S96: mounts of the character (MountService): ride skips the channel, the level and combat, not the place
cmd("character", "mount", { enum("action", { "info", "give", "take", "lvl", "ride", "off" }), str("arg", true) })
-- S97: every mount of Data/Mounts at its start level (premium too, for tests)
cmd("character", "mountall", {})
-- S132: the character's look without a cost (or "reset" = the default look), the free change back, the avatar switch
local LOOK_FACES: { string } = { "reset" }
for _, f in ClassLooks.FACES do
	table.insert(LOOK_FACES, f.id)
end
local LOOK_SKINS: { string } = {}
for _, sk in ClassLooks.SKINS do
	table.insert(LOOK_SKINS, sk.id)
end
local LOOK_HAIRS: { string } = {}
for _, h in ClassLooks.HAIRS do
	table.insert(LOOK_HAIRS, h.id)
end
cmd(
	"character",
	"charlook",
	{ enum("face", LOOK_FACES), enum("skin", LOOK_SKINS, true), enum("hair", LOOK_HAIRS, true) }
)
cmd("character", "lookfree", {})
cmd("character", "avatarmode", { enum("mode", { "on", "off" }) })
cmd("character", "preset", { int("level", 1, MAX_LEVEL), int("rarity", 1, 5), int("up", 0, 9, true, "0") })
-- S28: skill tools (S56: ranks come from the level; /lvl sets them)
cmd("character", "nocd", { enum("mode", { "on", "off" }, true, "on") })
-- S57: class paths (PathService admin helpers: no place, combat or scroll rules)
cmd("character", "path", { str("pathId") })
cmd("character", "node", { str("nodeId"), int("rank", 0, 3, true) })
cmd("character", "pathmax", { str("pathId", true) })
cmd("character", "bp", { str("skillId"), enum("rank", { "5", "10" }), enum("option", { "a", "b" }) })
cmd("character", "resetskills", {})
-- S137 (DESIGN-18 §11): skill points and weapon pools (PathService admin helpers; the pool defaults to the active one)
cmd("character", "skillrank", { str("skillId"), int("rank", 0, 10), str("pool", true) })
cmd("character", "skillmax", { str("pool", true) })
cmd("character", "skillreset", {})
cmd("character", "pool", {})
cmd("character", "respecfree", { enum("mode", { "on", "off" }, true, "on") })
cmd("character", "luck", {})
-- S58: build sets (ROZWOJ 3.3): anywhere; copy overwrites the other set, so the panel asks first
cmd("character", "buildset", { enum("action", { "1", "2", "copy" }) }, { dangerActions = { "copy" } })
-- S125: timed titles (TitleService.GrantTimed; 0 days takes the title away)
cmd("character", "timedtitle", { str("id"), int("days", 0, 365, true, "7") })
cmd("combat", "skillpreview", { str("id") })
cmd("combat", "dummy", { int("level", 1, MAX_LEVEL, true) })
-- S29: every kind of damage number in turn (look check).
cmd("combat", "dmgtest", {})
-- S32: balance checks with the player's real stats (Logic/FightSim, targets of DESIGN §15.1).
cmd("combat", "simfight", {
	ref("monster", "monster"),
	int("level", 1, MAX_LEVEL),
	int("n", 1, 4, true, "1"),
	enum("variant", { "normal", "elite", "elite2" }, true, "normal"),
})
cmd("combat", "balance", {})
-- S54: level curves (Data/LevelCurves) at a level.
cmd("combat", "curves", { int("level", 1, MAX_LEVEL, true) })

-- Items
cmd(
	"items",
	"give",
	{ ref("item", "item"), str("rarity", true), int("ilvl", 1, MAX_LEVEL, true), int("n", 1, 999, true) }
)
cmd(
	"items",
	"item",
	{ ref("item", "item"), enum("rarity", RARITY_NAMES, true), int("ilvl", 1, MAX_LEVEL, true), int("n", 1, 999, true) }
)
cmd("items", "givex", {
	ref("item", "item"),
	str("rarity", true),
	int("ilvl", 1, MAX_LEVEL, true),
	int("up", 0, 9, true, "0"),
	enum("el", { "none", "fire", "ice", "lightning" }, true, "none"),
	int("n", 1, 999, true, "1"),
	enum("equip", { "no", "yes" }, true, "no"),
})
cmd("items", "legend", { enum("rarity", { "legendary", "mythic" }, true, "legendary") })
cmd("items", "lootsim", {
	ref("monster", "monster"),
	enum("variant", { "0", "1", "2", "normal", "elite", "elite2" }, true, "0"),
	int("n", 1, 100000, true),
	ref("area", "area", true), -- S33: with the hunting ground's profile
})
cmd("items", "rarities", {})
-- S35: item icon atlases (client preview, glyph / picture switch).
-- S119: "ui" = the interface pictures (counts per category on the server, the state of every file on the client);
-- /icongrid ui <atlas> = every key of one interface atlas.
cmd("items", "icons", { enum("mode", { "status", "glyph", "art", "ui" }, true, "status") })
cmd(
	"items",
	"icongrid",
	{ enum("group", { "eq", "uniq", "mat", "pot", "misc", "art", "tiers", "ui" }, true, "eq"), str("type", true) }
)
-- S52: real art (weapon models, picture icons): coverage and a look in the hand without an item.
cmd("items", "artcoverage", {})
cmd("items", "weaponpreview", { str("what"), int("tier", 1, MAX_LEVEL, true) })
cmd("items", "clearinv", {}, { danger = true })
cmd("items", "bag", { enum("capacity", { "20", "30", "45", "60", "80", "100", "130", "160", "200" }) })
cmd("items", "up", { str("where"), int("level", 0, 9) })
cmd("items", "mats", { int("n", 1, 999, true) })
-- S97: gold and parts for the active mount's next upgrade
cmd("items", "mountmats", {})
cmd("items", "scrolls", { int("n", 1, 999, true) })
cmd("items", "ilvl", { int("level", 1, MAX_LEVEL) })
cmd("items", "element", { enum("element", { "fire", "ice", "lightning" }) })
cmd("items", "partyloot", { int("n", 1, 5, true) })
cmd("items", "gearbag", {}) -- S29: drag-to-equip test set in the backpack
-- S32: equips the class's full set (weapon, off-hand, armour, jewellery) of item level `level` at `rarity`.
cmd("items", "gearset", { int("level", 1, MAX_LEVEL), enum("rarity", RARITY_NAMES, true, "common") })
-- S31: item value / buy / sell price and the tooltip lines of any item.
cmd("items", "value", {
	ref("item", "item"),
	int("ilvl", 1, MAX_LEVEL, true),
	enum("rarity", RARITY_NAMES, true),
	int("up", 0, 9, true, "0"),
})
cmd("items", "tooltip", {
	ref("item", "item"),
	enum("lang", { "pl", "en" }, true, "pl"),
	enum("rarity", RARITY_NAMES, true, "common"),
	enum("mode", { "lines", "details" }, true, "lines"),
})
-- S67: equipment rolled like loot of a monster of that family; "Better item!" score and family / class lines.
cmd("items", "givefam", {
	ref("item", "item"),
	enum("family", FAMILY_ARGS),
	enum("rarity", RARITY_NAMES, true, "heroic"),
	int("ilvl", 1, MAX_LEVEL, true),
})
cmd("items", "itemscore", {})
-- S134j: bonus reroll of an equipped (slot) or backpack (index) item without the smith's distance: pays like the
-- smith ("pay"), with a Stone of Transmutation ("stone") or nothing ("free"); /rerollstate shows `rr` and the next cost.
cmd("items", "reroll", { str("where"), int("line", 1, 9), enum("mode", { "pay", "stone", "free" }, true, "pay") })
cmd("items", "rerollstate", { str("where") })

-- World
cmd("world", "tp", { str("target"), str("a", true), str("b", true) })
-- S125: the weekly EXP ranking (LeaderboardService): state, write now, payout of a week (default the previous one),
-- clearing the in-memory week, EXP added to the character's week only
cmd(
	"world",
	"rankweek",
	{ enum("action", { "info", "flush", "pay", "reset", "add" }), int("value", 0, 100000000, true) },
	{ dangerActions = { "pay", "reset" } }
)
cmd("world", "npc", { ref("id", "npc", true) })
cmd("world", "time", { str("seconds") })
cmd("world", "daytime", { str("hour") })
cmd("world", "nodes", { enum("action", { "respawn", "count" }) })
cmd("world", "fish", { enum("action", { "auto" }) })
cmd("world", "maps", {})
cmd("world", "rebuild", { ref("map", "map") }, { danger = true })
cmd("world", "nearby", { int("radius", 10, 2000, true) })
cmd("world", "area", {})
cmd("world", "decor", { enum("level", { "low", "mid", "high" }) })
cmd("world", "mapcache", { enum("action", { "clear" }) })
cmd("world", "town", { enum("action", { "info", "lod", "tp" }), str("value", true) })
cmd("world", "portalpick", { ref("map", "map") })
cmd("world", "arrive", { ref("map", "map"), ref("area", "area") })
-- S33: hunting ground profiles (Data/AreaProfiles, Logic/AreaRates).
cmd("world", "areainfo", {})
cmd("world", "areasim", { ref("area", "area"), int("minutes", 1, 600, true, "60") })
cmd("world", "nav", { str("target"), str("z", true) })
cmd("world", "navdebug", {})
cmd("world", "marks", { enum("action", { "list", "clear" }) }, { dangerActions = { "clear" } })
cmd("world", "goto", { ref("player", "player") })
-- S101: world events (WorldEventService): a = kind (invasion / champion / random) or the hunting ground, b = ground
cmd(
	"world",
	"event",
	{ enum("action", { "info", "start", "warn", "stop", "next" }), str("a", true), str("b", true) },
	{ dangerActions = { "stop" } }
)
-- S129: the Blood Moon on this server (BloodMoonService): n = minutes for start, points for points
cmd(
	"world",
	"bloodmoon",
	{ enum("action", { "info", "start", "stop", "settle", "points" }), int("n", 1, 120, true, "30") },
	{ dangerActions = { "start", "stop" } }
)
-- S130: the Champion's Tournament (TourneyService): info, and a local test tournament on this server (open [s] ...
-- win <name>); a = seconds for open, the player's name for win. S131: force [min] = a real tournament on every server
-- (signups at once, the start `min` minutes from now)
cmd(
	"world",
	"tourney",
	{ enum("action", { "info", "open", "close", "start", "cancel", "win", "force" }), str("a", true) },
	{ dangerActions = { "cancel", "force" } }
)
-- S131: the next occurrence of every scheduled event (UTC) and what is forced on this server
cmd("world", "sched", {})
cmd("world", "bring", { ref("player", "player") })
-- S26: shaped terrains (Admin/Terrain)
cmd("world", "tparea", { str("target") })
cmd("world", "ambience", { str("mood") })
-- S45: every map with a height function (the city, the Meadows and the shaped regions of Data/Terrain)
local TERRAIN_MAPS = { "city", "meadows" }
for mapId in TerrainShapes.byMap do
	table.insert(TERRAIN_MAPS, mapId)
end
table.sort(TERRAIN_MAPS)
local REGION_MAPS = { "meadows" }
for mapId in TerrainShapes.byMap do
	table.insert(REGION_MAPS, mapId)
end
table.sort(REGION_MAPS)
-- S48: caves on the cave engine
local CAVE_MAPS = {}
for mapId in CaveShapes.byMap do
	table.insert(CAVE_MAPS, mapId)
	table.insert(TERRAIN_MAPS, mapId)
end
table.sort(CAVE_MAPS)
cmd("world", "terrainrebuild", { enum("map", TERRAIN_MAPS) }, { danger = true })
cmd("world", "tpcave", { enum("cave", CAVE_MAPS), str("room", true) })
cmd("world", "caveinfo", {})
local CAVE_STATS = table.clone(CAVE_MAPS)
table.insert(CAVE_STATS, "all") -- S51: every cave and chamber on the engine
cmd("world", "cavestats", { enum("cave", CAVE_STATS, true) })
cmd("world", "lights", { str("count") })
-- S46: the ground under the caller and the client's world effects
cmd("world", "terraininfo", {})
cmd("world", "worldfx", {
	enum("effect", {
		"ash",
		"embers",
		"haze",
		"smoke",
		"vultures",
		"devils",
		"lavaglow",
		"snow",
		"drift",
		"aurora",
		"plume",
		"eagles",
		"avalanche",
		"glow",
		"sparks", -- S50: forge sparks in the caves
	}),
	enum("mode", { "on", "off", "auto" }),
})
-- S105: the city's season on the caller's client (Logic/CitySeason; auto = from the story)
cmd("world", "season", { enum("season", { "auto", "summer", "snow", "spring" }) })
-- S134f: the party finder board of this server (list, or remove every listing)
cmd("world", "finder", { enum("action", { "list", "clear" }) })

-- Monsters
cmd("monsters", "spawn", { ref("monster", "monster"), VARIANT, int("level", 1, MAX_LEVEL, true) })
cmd("monsters", "killall", { int("radius", 1, 2000, true) }, { danger = true })
cmd("monsters", "monsters", {})
cmd("monsters", "groups", {})
cmd("monsters", "mstats", { int("level", 1, MAX_LEVEL, true) })
cmd("monsters", "mobdef", { ref("monster", "monster"), VARIANT, int("level", 1, MAX_LEVEL, true) }) -- S66
-- S134h: /e2 spawn [kind]: both Elite IIs of the cave or the one of that kind
cmd("monsters", "e2", { enum("action", { "spawn" }), ref("kind", "monster", true) })
cmd("monsters", "e2timer", {})
cmd("monsters", "boss", { enum("action", { "reset", "spawn" }), ref("boss", "boss", true) })
-- S134f: the ready check at a dungeon gate (the leader's pending check: everyone "yes" at once)
cmd("monsters", "readycheck", { enum("action", { "skip" }) })
cmd("monsters", "phase", { int("phase", 1, 3) })
-- S30: boss grind (personal roll pity counters, daily runs, simulation)
cmd("monsters", "bosspity", { ref("boss", "boss", true), int("kills", 0, 100, true) })
cmd("monsters", "bossruns", { enum("action", { "reset" }), ref("boss", "boss", true) })
cmd("monsters", "bosssim", { ref("boss", "boss"), int("n", 1, 100000, true, "1000") })
-- S97: the personal mount / mount skin roll of a boss on a fresh character (Logic/Mounts.rollBossDrop)
cmd("monsters", "mountsim", { ref("boss", "boss"), int("n", 1, 100000, true, "1000") })
cmd("monsters", "leash", {})
-- S24: looks. mobviz: <monster|boss|pet id | 1-4 (region) | bosses | pets | all | clear> [normal|elite|elite2] [anim]
cmd("monsters", "mobviz", { str("target"), str("option", true), str("option2", true) })
cmd("monsters", "look", { str("id") })
cmd("monsters", "lookstats", {})

-- Combat
cmd("combat", "target", { enum("action", { "info" }) })
cmd("combat", "dmg", { str("amount") })
cmd("combat", "hurt", { int("amount", 1, BIG) })
cmd("combat", "kill", { str("who", true) })
cmd("combat", "pvp", { str("a"), str("b", true), str("c", true) })
-- S126: the ranked arena (ArenaService): the own state, rating, a fresh state, a new season now, the queue of this
-- server, a rated test match against a player of this server, stopping a match without a rating
cmd(
	"combat",
	"arena",
	-- S128: tokens <n>, rating3 <n>, week, hof, queue3
	{
		enum("action", {
			"info",
			"rating",
			"reset",
			"season",
			"queue",
			"match",
			"stop",
			"tokens",
			"rating3",
			"week",
			"hof",
			"queue3",
		}),
		str("value", true),
	},
	{ dangerActions = { "reset" } }
)
-- S127: the global arena queue and arena servers: state, the in-memory store on / off, a preview of the arena map,
-- everybody home from an arena server
cmd("combat", "arenanet", { enum("op", { "status", "offline", "online", "pit", "home" }) })
cmd("combat", "die", {})
cmd("combat", "shield", { int("seconds", 1, 600, true) })
cmd("combat", "anim", { str("kind") })
-- S110: AnimLab (docs/ANIMACJE.md): the motion lab of the Studio review series (DESIGN-16 §1).
cmd(
	"combat",
	"animlab",
	{ str("action", true), str("a", true), str("b", true), str("c", true), str("d", true) },
	{ studioOnly = true }
)
-- S61: the party effect engine before any class has nodes or skills that use it.
cmd("combat", "intercept", { int("share", 1, 100, true, "30"), int("seconds", 1, 600, true, "10") })
cmd("combat", "misfortune", { int("value", 1, 100, true, "15"), int("seconds", 1, 600, true, "10") })
local auraCategories: { string } = { "off" }
for _, category in BuffCategories.list do
	if category.side == "ally" then
		table.insert(auraCategories, category.id)
	end
end
cmd("combat", "aura", {
	enum("category", auraCategories),
	int("value", 1, 100, true, "10"),
	enum("shape", { "circle", "behind" }, true, "circle"),
	int("radius", 1, 40, true),
})
-- S72: a temporary extra combat hook value on yourself (path-node hooks before the nodes exist).
cmd("combat", "hook", { str("id"), str("value", true) })

-- Quests
-- S102: `info` = the place in the story (mainDone, mainLast, the active quest, the chapter)
cmd("quests", "quest", { enum("action", { "set", "complete", "info" }), ref("id", "quest", true) })
-- S102: story cutscenes of the caller (play = queue again, list, reset = forget all)
cmd(
	"quests",
	"scene",
	{ enum("action", { "play", "list", "reset" }), str("id", true) },
	{ dangerActions = { "reset" } }
)
cmd("quests", "daily", { enum("action", { "reroll" }) })
cmd("quests", "questmarks", {})
-- S98: weekly contracts and the boss contract; the quest EXP budget multiplier of a level (own level by default)
cmd("quests", "weekly", { enum("action", { "reroll", "complete" }) })
cmd("quests", "questbudget", { int("level", 1, 100, true) })
-- S27: side quests of the caller's character; `arc <id>` hands in everything before the quest in its arc; S108: with
-- `list` the second argument filters the arcs by the prefix of their id (`/side list fp_`).
cmd(
	"quests",
	"side",
	{ enum("action", { "list", "give", "complete", "reset", "arc" }), str("id", true) },
	{ dangerActions = { "reset" } }
)
cmd("quests", "anchor", { str("id", true) })
-- S101b: the quest companion of the caller (or of a named player): what it is, or send it back to its start
cmd("quests", "companion", { enum("action", { "info", "reset" }), ref("player", "player", true) })
-- S99: hunting contracts of the caller's character (`set <level>` = that contract active, the ones before done). S134k:
-- `all` takes every contract up to the level, `finish [level]` fills one (no level: every active one)
cmd(
	"quests",
	"contract",
	{ enum("action", { "info", "set", "all", "finish", "complete", "reset" }), int("level", 1, 99, true) },
	{ dangerActions = { "reset" } }
)
-- S134k: Hunter's Marks of the caller's character (negative takes, never below 0)
cmd("quests", "huntmarks", { int("amount", -BIG, BIG) })

-- Economy and community
cmd("economy", "gold", { int("amount", -BIG, BIG) })
cmd("economy", "shards", { int("amount", -BIG, BIG) })
cmd("economy", "setgold", { int("amount", 0, BIG) })
cmd("economy", "setshards", { int("amount", 0, BIG) })
cmd("economy", "pass", { ref("pass", "pass"), enum("mode", { "on", "off" }) })
-- S131: grant / take = a pass saved in the account (account.grantedPasses, like a starter pack); list = every pass and
-- where it comes from. /pass on|off stays the session-only test.
cmd(
	"economy",
	"premium",
	{ enum("action", { "grant", "take", "list" }), str("key", true) },
	{ dangerActions = { "take" } }
)
-- S121: VIP test (a session-only subscription), its state, today's benefits again, a month's cosmetic
-- S131: grant / take = the VIP for good through the "vip" pass saved in the account (account.grantedPasses)
cmd(
	"economy",
	"vip",
	{ enum("action", { "on", "off", "status", "reset", "month", "grant", "take" }), str("month", true) },
	{ dangerActions = { "take" } }
)
-- S131: the caller's weekly counters back to zero: shop limits, Arena Tokens of the week, weekly EXP
cmd("economy", "weekreset", { enum("what", { "limits", "tokens", "expweek" }) })
-- S120: the caller's premium shop limit counters (account.shopLimits)
cmd("economy", "shoplimits", { enum("action", { "show", "reset" }) })
-- S122: Cloak of Luring time of the caller's account (no shards), the switch and a pull now
cmd(
	"economy",
	"lure",
	{ enum("action", { "add", "clear", "on", "off", "pulse" }), int("minutes", 1, 20160, true, "60") }
)
-- S134d: Auto Hunt bank of the caller's account (no shards), stop and state; Auto Potions without shards
cmd(
	"economy",
	"autogrind",
	{ enum("action", { "add", "clear", "stop", "status" }), int("minutes", 1, 1440, true, "60") }
)
cmd("economy", "autopotion", { enum("action", { "grant", "perm", "clear", "status" }), int("days", 1, 365, true, "1") })
cmd("economy", "bless", { ref("id", "blessing", true) })
-- S100: the login reward streak of the caller's account (state, set, simulate days passing)
cmd("economy", "login", {})
cmd("economy", "loginset", { int("day", 0, 7), int("gap", 0, 30, true, "0") })
cmd("economy", "loginnext", { int("days", 1, 30, true, "1") })
-- S29: a blessing by line and tier, optionally with only `seconds` left (to see the last minute).
cmd(
	"economy",
	"blessing",
	{ enum("line", Blessings.lines), int("tier", 1, 5), int("seconds", 1, Blessings.DURATION, true) }
)
-- S123: one cosmetic given (CosmeticService.Grant) or taken (off when worn), or everything
cmd("economy", "cosmetic", { enum("action", { "all", "give", "take" }), str("id", true) })
-- S123: a starter pack without Robux (handler of the pack) or the purchase forgotten (its granted passes off)
cmd("economy", "pack", { enum("action", { "grant", "reset" }), str("key") }, { dangerActions = { "reset" } })
-- S123: the offer of the week now (or of week number `week`); /weekly is the weekly quests' command (S98)
cmd("economy", "weeklyoffer", { int("week", 0, 100000, true) })
cmd("economy", "mail", { enum("kind", { "gold", "item" }), str("a"), str("b", true), str("c", true) })
cmd("economy", "auction", { enum("action", { "list", "expireall" }) }, { dangerActions = { "expireall" } })
cmd("economy", "tradetest", {}, { studioOnly = true })
cmd(
	"guild",
	"guild",
	{ enum("action", { "info", "treasury", "skills", "bots", "disband" }), str("value", true) },
	{ dangerActions = { "disband" } }
)
-- S125: the guild board entry of the player's guild (score, place; push = write now)
cmd("guild", "rankguild", { enum("action", { "info", "push" }) })
-- S133: the friends and ignored players of a player on this server; the daily letter limit of a character reset
cmd("guild", "social", { ref("player", "player") })
cmd("economy", "mailcap", { enum("action", { "reset" }), ref("player", "player", true) })

-- Performance and logs
cmd("perf", "perf", {})
cmd("perf", "adminlog", { int("n", 1, 200, true) })
cmd("perf", "meadowsstats", {})
cmd("perf", "regionstats", { enum("map", REGION_MAPS) })

-- Data
cmd("data", "help", {})
cmd("data", "wipe", { enum("confirm", { "confirm" }, true) }, { danger = true })
cmd("data", "resetcodes", {})
-- S124: leaderboards (LeaderboardService): mode and cache, forced read, own write, test flag, one entry, test
-- characters and Hall of Fame clearing on the in-memory boards (Studio without API access)
cmd(
	"data",
	"lb",
	{ enum("action", { "info", "refresh", "submit", "hide", "show", "remove", "fake", "hofclear" }), str("arg", true) },
	{ dangerActions = { "remove", "hofclear" } }
)

local byName: { [string]: Command } = {}
for _, def in list do
	byName[def.name] = def
end

local AdminCommands = {}

AdminCommands.list = list
AdminCommands.byName = byName
AdminCommands.CATEGORIES = CATEGORIES
AdminCommands.KINDS = {
	"integer",
	"number",
	"string",
	"enum",
	"item",
	"monster",
	"map",
	"area",
	"npc",
	"boss",
	"quest",
	"blessing",
	"pass",
	"player",
} :: { ArgKind }

function AdminCommands.get(name: string): Command?
	return byName[name]
end

-- Commands sorted by name (/help, the console's hints).
function AdminCommands.sorted(): { Command }
	local out = table.clone(list)
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Commands of one category, in definition order.
function AdminCommands.inCategory(category: Category): { Command }
	local out = {}
	for _, def in list do
		if def.category == category then
			table.insert(out, def)
		end
	end
	return out
end

-- Whether running `def` with these arguments needs a confirmation in the panel.
function AdminCommands.isDangerous(def: Command, args: { string }): boolean
	if def.danger then
		return true
	end
	return def.dangerActions ~= nil and table.find(def.dangerActions, args[1] or "") ~= nil
end

return AdminCommands
