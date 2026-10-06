--!strict
-- S23: admin command metadata (Data/AdminCommands), argument validation (Logic/AdminArgs) and the test gear set
-- (Logic/DevPreset).

local AdminArgs = require("../src/shared/Logic/AdminArgs")
local AdminCommands = require("../src/shared/Data/AdminCommands")
local DevPreset = require("../src/shared/Logic/DevPreset")
local Items = require("../src/shared/Data/Items")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local SPEC: { AdminArgs.Arg } = {
	{ name = "level", kind = "integer", min = 1, max = 100 },
	{ name = "mode", kind = "enum", options = { "on", "off" }, optional = true, default = "on" },
	{ name = "item", kind = "item", optional = true },
}

local function resolver(kind: string, value: string): boolean
	return kind == "item" and Items.get(value) ~= nil
end

describe("AdminArgs", function()
	it("accepts valid arguments and fills defaults", function()
		local ok, values = AdminArgs.validate(SPEC, { "50" }, resolver)
		expect(ok).toBe(true)
		expect(values).toEqual({ "50", "on" })
		ok, values = AdminArgs.validate(SPEC, { "1", "off", "sword1h_1" }, resolver)
		expect(ok).toBe(true)
		expect(values).toEqual({ "1", "off", "sword1h_1" })
	end)

	it("rejects bad numbers, ranges and options", function()
		local cases: { { args: { string }, key: string } } = {
			{ args = { "abc" }, key = "admin.args.number" },
			{ args = { "2.5" }, key = "admin.args.integer" },
			{ args = { "0" }, key = "admin.args.range" },
			{ args = { "101" }, key = "admin.args.range" },
			{ args = { "nan" }, key = "admin.args.number" },
			{ args = { "inf" }, key = "admin.args.number" },
			{ args = { "5", "maybe" }, key = "admin.args.option" },
			{ args = {}, key = "admin.args.missing" },
			{ args = { "5", "on", "sword1h_1", "x" }, key = "admin.args.tooMany" },
			{ args = { "5", "on", "no_such_item" }, key = "admin.args.unknown" },
			{ args = { string.rep("9", 65) }, key = "admin.args.tooLong" },
		}
		for _, case in cases do
			local ok, _, key = AdminArgs.validate(SPEC, case.args, resolver)
			expect(ok).toBe(false)
			expect(key).toBe(case.key)
		end
	end)

	it("sanitizes remote arguments", function()
		expect(AdminArgs.sanitize({ "a", 5, "c" })).toEqual({ "a", "5", "c" })
		expect(AdminArgs.sanitize("nope")).toBeNil()
		expect(AdminArgs.sanitize({ 1, 2, 3, 4, 5, 6, 7, 8, 9 })).toBeNil()
		expect(AdminArgs.sanitize({ { "nested" } })).toBeNil()
		expect(AdminArgs.sanitize({ string.rep("x", 65) })).toBeNil()
		expect(AdminArgs.sanitize({ [2] = "gap" })).toBeNil()
		expect(AdminArgs.sanitize({ 0 / 0 })).toBeNil()
	end)

	it("parses console lines", function()
		local name, args = AdminArgs.parseLine("/LVL  50 ")
		expect(name).toBe("lvl")
		expect(args).toEqual({ "50" })
		name, args = AdminArgs.parseLine("give sword1h_1 3")
		expect(name).toBe("give")
		expect(args).toEqual({ "sword1h_1", "3" })
		expect((AdminArgs.parseLine("   "))).toBeNil()
	end)
end)

describe("AdminCommands", function()
	it("have unique names, known categories and usage texts in both languages", function()
		local seen: { [string]: boolean } = {}
		for _, def in AdminCommands.list do
			expect(seen[def.name]).toBeNil()
			seen[def.name] = true
			expect(table.find(AdminCommands.CATEGORIES, def.category) ~= nil).toBe(true)
			expect(def.usageKey).toBe(`admin.usage.{def.name}`)
			expect(type((pl :: any)[def.usageKey])).toBe("string")
			expect(type((en :: any)[def.usageKey])).toBe("string")
		end
	end)

	it("have well-formed argument schemas", function()
		for _, def in AdminCommands.list do
			local optionalSeen = false
			expect(#def.args <= AdminArgs.MAX_ARGS).toBe(true)
			for _, arg in def.args do
				expect(table.find(AdminCommands.KINDS, arg.kind) ~= nil).toBe(true)
				if arg.kind == "enum" then
					expect(arg.options ~= nil and #(arg.options :: { string }) > 0).toBe(true)
					if arg.default then
						expect(table.find(arg.options :: { string }, arg.default) ~= nil).toBe(true)
					end
				end
				if arg.min and arg.max then
					expect(arg.min <= arg.max).toBe(true)
				end
				-- required arguments never follow optional ones
				if arg.optional or arg.default then
					optionalSeen = true
				else
					expect(optionalSeen).toBe(false)
				end
			end
		end
	end)

	it("mark destructive commands as dangerous", function()
		for _, name in { "wipe", "killall", "rebuild" } do
			expect(assert(AdminCommands.get(name), name).danger).toBe(true)
		end
		local guild = assert(AdminCommands.get("guild"), "guild")
		expect(AdminCommands.isDangerous(guild, { "disband" })).toBe(true)
		expect(AdminCommands.isDangerous(guild, { "info" })).toBe(false)
		local auction = assert(AdminCommands.get("auction"), "auction")
		expect(AdminCommands.isDangerous(auction, { "expireall" })).toBe(true)
		expect(AdminCommands.isDangerous(auction, { "list" })).toBe(false)
	end)

	it("keep every command of the old chat list", function()
		for _, name in
			{
				"help",
				"gold",
				"shards",
				"wipe",
				"lvl",
				"exp",
				"give",
				"tp",
				"spawn",
				"quest",
				"guild",
				"perf",
				"town",
				"daytime",
				"leash",
				"die",
				"arrive",
				"anim",
			}
		do
			expect(AdminCommands.get(name) ~= nil).toBe(true)
		end
	end)
end)

describe("DevPreset", function()
	it("gives every class a full usable set at several levels", function()
		for _, class in { "Warrior", "Hunter", "Mage", "Cleric" } do
			for _, level in { 1, 7, 50, 100 } do
				local set = DevPreset.pick(class, level)
				local slots: { [string]: boolean } = {}
				for _, piece in set do
					local def = assert(Items.get(piece.id), piece.id)
					expect(def.level <= level).toBe(true)
					expect(def.classes == nil or table.find(def.classes, class) ~= nil).toBe(true)
					slots[piece.slot] = true
				end
				for _, slot in { "weapon", "helmet", "armor", "gloves", "boots", "necklace", "ring1", "ring2" } do
					expect(slots[slot]).toBe(true)
				end
			end
		end
	end)
end)
