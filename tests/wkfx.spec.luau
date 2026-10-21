--!strict
-- walka-wk: the Warrior and Cleric pieces (client/Vfx/WkFx): every `wk` piece a SkillVfx entry names exists in the
-- module, has a layer and a cost (tests/SkillLooks), and every piece of the module is used; every active skill of both
-- classes has a motion and a look and at least one wk piece; the falling pieces only on skills whose blow lands later.

local fs = require("@lune/fs")

local SkillData = require("../src/shared/Data/Skills")
local SkillLooks = require("./SkillLooks")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local SOURCE = fs.readFile("src/client/Vfx/WkFx.luau")

-- The piece names the module defines (`pieces.<name> = function`).
local function defined(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for name in string.gmatch(SOURCE, "\npieces%.(wk%w+) = function") do
		out[name] = true
	end
	return out
end

local function wkPiecesOf(entry: SkillVfx.Entry): { string }
	local out: { string } = {}
	for _, name in SkillLooks.pieces(entry) do
		if string.sub(name, 1, 2) == "wk" then
			table.insert(out, name)
		end
	end
	return out
end

describe("Warrior and Cleric wk pieces (walka-wk)", function()
	it("every wk piece of the data is in Vfx/WkFx with a layer and a cost", function()
		local have = defined()
		for id, entry in SkillVfx do
			for _, name in wkPiecesOf(entry) do
				expect({ id, name, have[name] == true }).toEqual({ id, name, true })
				expect({ name, SkillLooks.PIECE_LAYER[name] ~= nil }).toEqual({ name, true })
				expect({ name, SkillLooks.PIECE_COST[name] ~= nil }).toEqual({ name, true })
			end
		end
	end)

	it("every piece of Vfx/WkFx is used by a skill and listed in SkillLooks", function()
		local used: { [string]: boolean } = {}
		for _, entry in SkillVfx do
			for _, name in wkPiecesOf(entry) do
				used[name] = true
			end
		end
		local count = 0
		for name in defined() do
			count += 1
			expect({ name, used[name] == true, SkillLooks.PIECE_LAYER[name] ~= nil }).toEqual({ name, true, true })
		end
		expect(count >= 20).toBe(true)
		for name in SkillLooks.PIECE_LAYER do
			if string.sub(name, 1, 2) == "wk" then
				expect({ name, defined()[name] == true }).toEqual({ name, true })
			end
		end
	end)

	it("every active Warrior and Cleric skill has a motion, a look and a wk piece", function()
		for _, class in { "Warrior", "Cleric" } do
			for _, skill in SkillData.byClass[class] do
				if skill.type ~= "passive" then
					local entry = SkillVfx[skill.id]
					expect({ skill.id, SkillMotions.get(skill.id) ~= nil, entry ~= nil }).toEqual({
						skill.id,
						true,
						true,
					})
					if entry then
						expect({ skill.id, #wkPiecesOf(entry) > 0 }).toEqual({ skill.id, true })
					end
				end
			end
		end
	end)

	it("buff loops only on skills that last (their event carries a duration)", function()
		local lasting: { [string]: boolean } = {
			buff = true,
			hot = true,
			shield = true,
			groupBuff = true,
			channel = true,
			healZone = true,
		}
		for id, entry in SkillVfx do
			for _, name in entry.impact do
				if name == "wkRageLoop" or name == "wkHolyLoop" or name == "wkGuardLoop" or name == "wkGroundGlow" then
					local skill = SkillData.get(id)
					expect({ id, name, skill ~= nil and lasting[skill.type] == true }).toEqual({ id, name, true })
				end
			end
		end
	end)

	it("the falling hammer only where the blow lands later; the charge trail only on dashes", function()
		for id, entry in SkillVfx do
			for _, name in entry.impact do
				if name == "wkSkyHammer" then
					expect({ id, entry.landsAfter == true }).toEqual({ id, true })
				elseif name == "wkChargeTrail" then
					local skill = SkillData.get(id)
					expect({ id, skill ~= nil and (skill.type == "charge" or skill.type == "guard") }).toEqual({
						id,
						true,
					})
				end
			end
		end
	end)
end)
