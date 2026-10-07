--!strict
-- S25: data behind the interactive world map (NPC icons and services, own marks, Config.Nav) and the schema
-- migration that adds `mapMarks`.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Config = require("../src/shared/Config")
local MapMarks = require("../src/shared/Data/MapMarks")
local Npcs = require("../src/shared/Data/Npcs")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("World map data", function()
	it("every NPC on the map has an icon and a service (or is a board)", function()
		local bad = {}
		for _, npc in Npcs.list do
			if not npc.decoration then
				local ok = npc.icon ~= "" and (#npc.services > 0 or npc.body == "board")
				if not ok then
					table.insert(bad, npc.id)
				end
			end
		end
		expect(bad).toEqual({})
	end)

	it("every NPC on the map has a role and its services have search words in both languages", function()
		local missing = {}
		for _, npc in Npcs.list do
			if not npc.decoration then
				local keys = { `npc.{npc.id}.role` }
				for _, service in npc.services do
					table.insert(keys, `npc.service.{service}`)
					table.insert(keys, `worldmap.search.{service}`)
				end
				for _, key in keys do
					if pl[key] == nil or en[key] == nil then
						table.insert(missing, key)
					end
				end
			end
		end
		expect(missing).toEqual({})
	end)

	it("Config.Nav numbers are positive", function()
		local bad = {}
		for key, value in Config.Nav :: { [string]: number } do
			if type(value) ~= "number" or value <= 0 then
				table.insert(bad, key)
			end
		end
		expect(bad).toEqual({})
		expect(Config.Nav.arrive < Config.Nav.deviate).toBe(true)
		expect(Config.Nav.spacing < Config.Nav.ahead).toBe(true)
		expect(Config.Nav.ahead / Config.Nav.spacing <= Config.Nav.pool).toBe(true)
	end)

	it("own mark icons are six, unique and named", function()
		expect(#MapMarks.list).toBe(6)
		local seen = {}
		for _, icon in MapMarks.list do
			expect(seen[icon.id]).toBeNil()
			seen[icon.id] = true
			expect(MapMarks.get(icon.id)).toBe(icon)
			expect(pl[icon.nameKey] ~= nil and en[icon.nameKey] ~= nil).toBe(true)
		end
	end)
end)

describe("AccountSchema S25", function()
	it("new characters have no marks and the walk option is on", function()
		expect(AccountSchema.characterTemplate().mapMarks).toEqual({})
		expect(AccountSchema.accountTemplate().settings.mapCloseOnWalk).toBe(true)
	end)

	it("the migration adds mapMarks and keeps old saves intact", function()
		local data: any = {
			schema = 2,
			characters = {
				["1"] = {
					id = "a",
					name = "Old",
					level = 12,
					gold = 345,
					visitedMaps = { city = true, meadows = true },
				},
				["2"] = { id = "b", name = "Broken", level = 3, mapMarks = "oops" },
			},
			settings = { lang = "pl", devPins = { "heal" } },
		}
		local applied = AccountSchema.migrate(data)
		expect(applied).toEqual({ 3, 4 })
		expect(data.schema).toBe(AccountSchema.CURRENT)
		expect(data.characters["1"].mapMarks).toEqual({})
		expect(data.characters["2"].mapMarks).toEqual({})
		expect(data.characters["1"].level).toBe(12)
		expect(data.characters["1"].gold).toBe(345)
		expect(data.characters["1"].visitedMaps).toEqual({ city = true, meadows = true })
		expect(data.settings.lang).toBe("pl")
		expect(data.settings.devPins).toEqual({ "heal" })
		expect(data.settings.mapCloseOnWalk).toBe(true)
	end)

	it("existing marks survive the migration", function()
		local mark = { map = "meadows", x = 10, z = -20, icon = "pick" }
		local data: any = { schema = 2, characters = { ["1"] = { id = "a", mapMarks = { mark } } } }
		AccountSchema.migrate(data)
		expect(data.characters["1"].mapMarks).toEqual({ mark })
	end)
end)

return nil
