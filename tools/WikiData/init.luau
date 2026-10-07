--!strict
-- Wiki data exporter (S34, docs/WIKI.md §5): build(opts) -> { files = { [path]: text }, stats }. Pure: no file
-- system here (the CLI tools/wikidump.luau reads and writes, tests call build directly). Paths are relative to the
-- repository root: wiki/src/data/<file>.json, wiki/src/data/types.ts, wiki/src/styles/tokens.data.css,
-- docs/PRZEDMIOTY.md.
--
-- opts.rolls     Monte Carlo rolls per monster variant (loot) and per pool and rarity (bonus frequency)
-- opts.only      { file names }: build only these JSON files (+ what they need), no derived files
-- opts.exists    path -> boolean (feature detection), opts.themeText (src/client/UI/Theme.luau as text)
-- opts.git       { commit, date } of the data (the CLI asks git; "unknown" without it)

local Basics = require("@self/Basics")
local Bosses = require("@self/Bosses")
local Clean = require("@self/Clean")
local Crafting = require("@self/Crafting")
local Features = require("@self/Features")
local Items = require("@self/Items")
local ItemsMd = require("@self/ItemsMd")
local Json = require("@self/Json")
local Leak = require("@self/Leak")
local Monsters = require("@self/Monsters")
local Names = require("@self/Names")
local Quests = require("@self/Quests")
local Schema = require("@self/Schema")
local Search = require("@self/Search")
local Skills = require("@self/Skills")
local TokensCss = require("@self/TokensCss")
local TypesTs = require("@self/TypesTs")
local Upgrade = require("@self/Upgrade")
local Visibility = require("@self/Visibility")
local World = require("@self/World")

local WikiDump = {}

Schema.file(
	"meta",
	Schema.rec("MetaFile", {
		schemaVersion = "int",
		dataCommit = "string",
		dataDate = "string",
		dataHash = "string",
		features = Schema.map("bool"),
		counts = Schema.map("int"),
		rolls = "int",
	})
)

WikiDump.SCHEMA_VERSION = 1
WikiDump.DEFAULT_ROLLS = 100000
WikiDump.DATA_DIR = "wiki/src/data"
WikiDump.TYPES_PATH = "wiki/src/data/types.ts"
WikiDump.TOKENS_PATH = "wiki/src/styles/tokens.data.css"
WikiDump.ITEMS_MD_PATH = "docs/PRZEDMIOTY.md"

export type Opts = {
	rolls: number?,
	only: { string }?,
	exists: ((path: string) -> boolean)?,
	themeText: string?,
	git: { commit: string, date: string }?,
}

export type Result = {
	files: { [string]: string },
	stats: { { file: string, bytes: number, records: number } },
	missing: { string },
	warnings: { string },
	data: { [string]: any },
}

-- Builders in dependency order: monsters and bosses fill ctx.drops / ctx.bossDrops before items.
local ORDER: { { name: string, fn: (ctx: any) -> any } } = {
	{ name = "rarities", fn = Basics.rarities },
	{ name = "elements", fn = Basics.elements },
	{ name = "classes", fn = Basics.classes },
	{ name = "stats", fn = Basics.stats },
	{ name = "progression", fn = Basics.progression },
	{ name = "mechanics", fn = Basics.mechanics },
	{ name = "titles", fn = Basics.titles },
	{ name = "blessings", fn = Basics.blessings },
	{ name = "cosmetics", fn = Basics.cosmetics },
	{ name = "fish", fn = Basics.fish },
	{ name = "gather", fn = Basics.gather },
	{ name = "recipes", fn = Basics.recipes },
	{ name = "monsters", fn = Monsters.build },
	{ name = "bosses", fn = Bosses.build },
	{ name = "maps", fn = World.maps },
	{ name = "areas", fn = World.areas },
	{ name = "caves", fn = World.caves },
	{ name = "portals", fn = World.portals },
	{ name = "npcs", fn = World.npcs },
	{ name = "shops", fn = World.shops },
	{ name = "quests", fn = Quests.build },
	{ name = "skills", fn = Skills.build },
	{ name = "upgrade", fn = Upgrade.build },
	{ name = "crafting", fn = Crafting.build },
	{ name = "bonuses", fn = Items.bonuses },
	{ name = "items", fn = Items.build },
	{ name = "icons", fn = Items.icons },
	{ name = "search", fn = Search.build },
}

-- Files a file needs built first (for opts.only).
local NEEDS: { [string]: { string } } = {
	items = { "monsters", "bosses", "shops", "quests", "crafting" },
	search = { "items", "monsters", "bosses", "maps", "areas", "caves", "npcs", "quests", "skills", "classes" },
}

local function recordsOf(v: any): number
	if type(v) ~= "table" then
		return 0
	end
	local best = 0
	for _, value in v do
		if type(value) == "table" then
			local n = #value
			if n == 0 then
				for _ in value do
					n += 1
				end
			end
			best = math.max(best, n)
		end
	end
	return best
end

-- FNV-1a 32-bit of a text as 8 hex digits (deterministic fingerprint, not security).
function WikiDump.hash(text: string): string
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		-- h x 16777619 (= 2^24 + 403) mod 2^32 without losing precision.
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return string.format("%08x", h)
end

-- meta.json without the commit and date (what --check compares: the commit of the data cannot be in itself).
function WikiDump.comparable(path: string, text: string): string
	if string.sub(path, -9) ~= "meta.json" then
		return text
	end
	local out = string.gsub(text, '"dataCommit": "[^"]*"', '"dataCommit": ""')
	out = string.gsub(out, '"dataDate": "[^"]*"', '"dataDate": ""')
	return out
end

function WikiDump.build(opts: Opts?): Result
	local o: Opts = opts or {}
	Names.reset()
	Basics.registerEnums()
	Items.registerEnums()
	local features = Features.detect(o.exists or function(_path: string): boolean
		return false
	end)
	local ctx: any = {
		rolls = o.rolls or WikiDump.DEFAULT_ROLLS,
		features = features,
		themeText = o.themeText,
		warnings = {},
		data = {},
		drops = {},
		bossDrops = {},
	}
	ctx.hidden = Visibility.collect()

	local wanted: { [string]: boolean }? = nil
	if o.only then
		local set: { [string]: boolean } = {}
		local function want(name: string)
			if set[name] then
				return
			end
			set[name] = true
			for _, dep in NEEDS[name] or {} do
				want(dep)
			end
		end
		for _, name in o.only do
			want(name)
		end
		wanted = set
	end

	for _, step in ORDER do
		if not wanted or wanted[step.name] then
			local value = step.fn(ctx)
			if value ~= nil then
				ctx.data[step.name] = Clean.clean(value, step.name)
			end
		end
	end

	-- meta.json: commit of the data, features, counts. No "now" timestamp (two runs give the same bytes).
	local counts = {}
	for name, value in ctx.data do
		counts[name] = recordsOf(value)
	end
	local featureNames = {}
	for _, name in Clean.keys(features) do
		featureNames[name] = features[name]
	end
	-- Fingerprint of every other data file (the commit cannot name itself: see docs/WIKI.md "Decyzje").
	local hashInput = {}
	for _, name in Clean.keys(ctx.data) do
		table.insert(hashInput, name .. "\n" .. Json.file(Clean.clean(ctx.data[name], name)))
	end
	ctx.data.meta = {
		schemaVersion = WikiDump.SCHEMA_VERSION,
		dataHash = WikiDump.hash(table.concat(hashInput, "\n")),
		dataCommit = if o.git then o.git.commit else "unknown",
		dataDate = if o.git then o.git.date else "unknown",
		features = featureNames,
		counts = counts,
		rolls = ctx.rolls,
	}

	local files: { [string]: string } = {}
	local stats = {}
	local errors = {}
	for _, name in Clean.keys(ctx.data) do
		local root = Schema.files[name]
		assert(root, `WikiDump: no schema for {name}`)
		for _, e in Schema.check(ctx.data[name], root, name) do
			table.insert(errors, e)
		end
		local path = `{WikiDump.DATA_DIR}/{name}.json`
		files[path] = Json.file(ctx.data[name])
		table.insert(stats, { file = path, bytes = #files[path], records = counts[name] or 1 })
	end
	if #errors > 0 then
		error("WikiDump: output does not match the schema:\n  " .. table.concat(errors, "\n  "), 0)
	end
	local leaks = Leak.scanKeys(files)
	if #leaks > 0 then
		error("WikiDump: forbidden keys in the output:\n  " .. table.concat(leaks, "\n  "), 0)
	end

	if not o.only then
		files[WikiDump.TYPES_PATH] = TypesTs.generate()
		files[WikiDump.TOKENS_PATH] = TokensCss.generate(ctx)
		files[WikiDump.ITEMS_MD_PATH] = ItemsMd.generate(ctx)
		for _, path in { WikiDump.TYPES_PATH, WikiDump.TOKENS_PATH, WikiDump.ITEMS_MD_PATH } do
			table.insert(stats, { file = path, bytes = #files[path], records = 0 })
		end
	end
	table.sort(stats, function(a, b)
		return a.file < b.file
	end)
	return { files = files, stats = stats, missing = Names.missingList(), warnings = ctx.warnings, data = ctx.data }
end

return WikiDump
