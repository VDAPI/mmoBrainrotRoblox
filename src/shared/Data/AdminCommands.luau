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
cmd("character", "skillpoints", { int("n", 1, 1000) })
cmd("character", "skills", { enum("action", { "max", "reset" }) })
cmd("character", "heal", {})
cmd("character", "god", {})
cmd("character", "cd", { enum("mode", { "off", "on" }) })
cmd("character", "res", { enum("mode", { "inf", "off" }) })
cmd("character", "sprint", {})
cmd("character", "speed", { str("value") })
cmd("character", "preset", { int("level", 1, MAX_LEVEL), int("rarity", 1, 5), int("up", 0, 9, true, "0") })

-- Items
cmd(
	"items",
	"give",
	{ ref("item", "item"), str("rarity", true), int("ilvl", 1, MAX_LEVEL, true), int("n", 1, 999, true) }
)
cmd("items", "givex", {
	ref("item", "item"),
	int("rarity", 1, 5, true),
	int("ilvl", 1, MAX_LEVEL, true),
	int("up", 0, 9, true, "0"),
	enum("el", { "none", "fire", "ice", "lightning" }, true, "none"),
	int("n", 1, 999, true, "1"),
	enum("equip", { "no", "yes" }, true, "no"),
})
cmd("items", "legend", {})
cmd("items", "lootsim", { ref("monster", "monster"), VARIANT, int("n", 1, 100000, true) })
cmd("items", "clearinv", {}, { danger = true })
cmd("items", "bag", { enum("capacity", { "20", "30", "45", "60", "80", "100", "130", "160", "200" }) })
cmd("items", "up", { str("where"), int("level", 0, 9) })
cmd("items", "mats", { int("n", 1, 999, true) })
cmd("items", "scrolls", { int("n", 1, 999, true) })
cmd("items", "ilvl", { int("level", 1, MAX_LEVEL) })
cmd("items", "element", { enum("element", { "fire", "ice", "lightning" }) })
cmd("items", "partyloot", { int("n", 1, 5, true) })

-- World
cmd("world", "tp", { str("target"), str("a", true), str("b", true) })
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
cmd("world", "goto", { ref("player", "player") })
cmd("world", "bring", { ref("player", "player") })

-- Monsters
cmd("monsters", "spawn", { ref("monster", "monster"), VARIANT, int("level", 1, MAX_LEVEL, true) })
cmd("monsters", "killall", { int("radius", 1, 2000, true) }, { danger = true })
cmd("monsters", "monsters", {})
cmd("monsters", "groups", {})
cmd("monsters", "mstats", { int("level", 1, MAX_LEVEL, true) })
cmd("monsters", "e2", { enum("action", { "spawn" }) })
cmd("monsters", "e2timer", {})
cmd("monsters", "boss", { enum("action", { "reset", "spawn" }), ref("boss", "boss", true) })
cmd("monsters", "phase", { int("phase", 1, 3) })
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
cmd("combat", "die", {})
cmd("combat", "shield", { int("seconds", 1, 600, true) })
cmd("combat", "anim", { str("kind") })

-- Quests
cmd("quests", "quest", { enum("action", { "set", "complete" }), ref("id", "quest", true) })
cmd("quests", "daily", { enum("action", { "reroll" }) })

-- Economy and community
cmd("economy", "gold", { int("amount", -BIG, BIG) })
cmd("economy", "shards", { int("amount", -BIG, BIG) })
cmd("economy", "setgold", { int("amount", 0, BIG) })
cmd("economy", "setshards", { int("amount", 0, BIG) })
cmd("economy", "pass", { ref("pass", "pass"), enum("mode", { "on", "off" }) })
cmd("economy", "premium", { enum("action", { "grant" }), ref("pass", "pass") })
cmd("economy", "bless", { ref("id", "blessing", true) })
cmd("economy", "cosmetic", { enum("action", { "all" }) })
cmd("economy", "mail", { enum("kind", { "gold", "item" }), str("a"), str("b", true), str("c", true) })
cmd("economy", "auction", { enum("action", { "list", "expireall" }) }, { dangerActions = { "expireall" } })
cmd("economy", "tradetest", {}, { studioOnly = true })
cmd(
	"guild",
	"guild",
	{ enum("action", { "info", "treasury", "skills", "bots", "disband" }), str("value", true) },
	{ dangerActions = { "disband" } }
)

-- Performance and logs
cmd("perf", "perf", {})
cmd("perf", "adminlog", { int("n", 1, 200, true) })

-- Data
cmd("data", "help", {})
cmd("data", "wipe", { enum("confirm", { "confirm" }, true) }, { danger = true })
cmd("data", "resetcodes", {})

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
