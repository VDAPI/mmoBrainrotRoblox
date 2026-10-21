--!strict
-- W30 (walka-lm): the Hunter's and the Mage's own skill pieces (Data/LmVfxPieces, client/Vfx/LmHunterMage) and their
-- use in Data/SkillVfx (castFx, releaseFx, flight, lmOpts, lm pieces in the impact lists): every described piece is
-- written in the client module and the other way round, every list holds pieces of its phase, every option belongs to
-- a piece the entry uses, and every active skill of both classes has at least one piece of its own.

local fs = require("@lune/fs")

local LmVfxPieces = require("../src/shared/Data/LmVfxPieces")
local SkillData = require("../src/shared/Data/Skills")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local CLIENT = "src/client/Vfx/LmHunterMage.luau"
local LAYERS = { core = true, body = true, trail = true }
local PHASES = { impact = true, cast = true, release = true, flight = true }

-- The names the client module writes: `pieces.<name> = function` and `flights.<name> = function`.
local function written(): ({ [string]: boolean }, { [string]: boolean })
	local source = fs.readFile(CLIENT)
	local pieces, flights = {}, {}
	for name in string.gmatch(source, "\npieces%.(lm%w+) = function") do
		pieces[name] = true
	end
	for name in string.gmatch(source, "\nflights%.(lm%w+) = function") do
		flights[name] = true
	end
	return pieces, flights
end

local function isLm(name: string): boolean
	return string.sub(name, 1, 2) == "lm"
end

-- Every lm piece an entry uses, with the phase of the list it is in.
local function usesOf(entry: SkillVfx.Entry): { { name: string, phase: string } }
	local out = {}
	for _, list in { entry.impact, entry.trigger or {}, entry.strike or {}, entry.allies or {}, entry.everyWave or {} } do
		for _, name in list do
			if isLm(name) then
				table.insert(out, { name = name, phase = "impact" })
			end
		end
	end
	for _, name in entry.castFx or {} do
		table.insert(out, { name = name, phase = "cast" })
	end
	for _, name in entry.releaseFx or {} do
		table.insert(out, { name = name, phase = "release" })
	end
	if entry.flight then
		table.insert(out, { name = entry.flight, phase = "flight" })
	end
	return out
end

local function activesOf(class: string): { SkillData.SkillDef }
	local out = {}
	for _, skill in SkillData.byClass[class] do
		if skill.type ~= "passive" then
			table.insert(out, skill)
		end
	end
	return out
end

describe("Hunter and Mage lm pieces (W30)", function()
	it("every described piece has a known layer, phase and a cost", function()
		for name, spec in LmVfxPieces do
			expect({ name, isLm(name) }).toEqual({ name, true })
			expect({ name, LAYERS[spec.layer] == true, PHASES[spec.phase] == true }).toEqual({ name, true, true })
			local cost = spec.cost
			for _, key in { "emitters", "beams", "lights", "decals" } do
				local v = (cost :: any)[key]
				expect({ name, key, type(v) == "number" and v >= 0 and v <= 3 }).toEqual({ name, key, true })
			end
			expect({ name, spec.immediate == nil or spec.phase == "impact" }).toEqual({ name, true })
		end
	end)

	it("the client module writes exactly the described pieces and flights", function()
		local pieces, flights = written()
		for name, spec in LmVfxPieces do
			local found = if spec.phase == "flight" then flights[name] else pieces[name]
			expect({ name, found == true }).toEqual({ name, true })
		end
		for name in pieces do
			local spec = LmVfxPieces[name]
			expect({ name, spec ~= nil and spec.phase ~= "flight" }).toEqual({ name, true })
		end
		for name in flights do
			local spec = LmVfxPieces[name]
			expect({ name, spec ~= nil and spec.phase == "flight" }).toEqual({ name, true })
		end
	end)

	it("SkillVfx lists lm pieces only in the lists of their phase; options only for used pieces", function()
		for id, entry in SkillVfx do
			local used: { [string]: boolean } = {}
			for _, use in usesOf(entry) do
				local spec = LmVfxPieces[use.name]
				expect({ id, use.name, spec ~= nil }).toEqual({ id, use.name, true })
				if spec then
					expect({ id, use.name, spec.phase }).toEqual({ id, use.name, use.phase })
				end
				used[use.name] = true
			end
			for name, opts in entry.lmOpts or {} do
				expect({ id, name, used[name] == true, type(opts) == "table" }).toEqual({ id, name, true, true })
				for key, value in opts do
					local t = type(value)
					expect({ id, name, key, t == "number" or t == "boolean" or t == "string" }).toEqual({
						id,
						name,
						key,
						true,
					})
				end
			end
			-- a later wave replays only what the first one has
			for _, name in entry.everyWave or {} do
				expect({ id, name, table.find(entry.impact, name) ~= nil }).toEqual({ id, name, true })
			end
		end
	end)

	it("every active skill of the Hunter and the Mage has a piece of its own", function()
		for _, class in { "Hunter", "Mage" } do
			for _, skill in activesOf(class) do
				local entry = SkillVfx[skill.id]
				expect({ skill.id, entry ~= nil }).toEqual({ skill.id, true })
				if entry then
					expect({ skill.id, #usesOf(entry) > 0 }).toEqual({ skill.id, true })
				end
			end
		end
	end)

	it("cast pieces only on skills whose motion gathers, flights only on projectiles", function()
		for id, entry in SkillVfx do
			local skill = SkillData.get(id)
			if skill then
				if entry.flight then
					local projectile = skill.type == "projectile"
						or (skill.type == "circleTarget" and entry.projectile ~= nil)
					expect({ id, projectile }).toEqual({ id, true })
				end
				if entry.castFx then
					expect({ id, skill.type ~= "channel" and skill.type ~= "beam" }).toEqual({ id, true })
				end
			end
		end
	end)
end)
