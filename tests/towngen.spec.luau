--!strict
-- City building generator (S21): every Build is finite, deterministic and inside its part budget, and the special
-- hooks the client animates (portal, wheel, sails) exist. Budgets: docs/miasto/MIASTO.md §5.

local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")

local city = Town.city

local function ground(x: number, z: number): number
	return TownTerrain.heightAt(x, z)
end

type Item = { name: string, tag: string, bp: any, at: { x: number, y: number, z: number, rot: number } }

local function everything(): { Item }
	return TownGen.all(city, ground) :: any
end

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Upper limits per Build kind: { shell, detail, fine }.
local BUDGET: { [string]: { number } } = {
	house = { 24, 260, 90 },
	special = { 80, 340, 140 },
	garden = { 0, 120, 40 },
	stall = { 14, 40, 12 },
	field = { 60, 20, 0 },
	forest = { 140, 0, 0 },
	outside = { 80, 260, 120 },
	cemetery = { 40, 200, 160 },
}

T.describe("Town generator", function()
	local all = everything()

	T.it("produces finite pieces with a positive size", function()
		for _, b in all do
			T.expect(finite(b.at.x) and finite(b.at.y) and finite(b.at.z) and finite(b.at.rot)).toBe(true)
			for _, p in b.bp.pieces do
				for k = 1, 3 do
					if not (finite(p.p[k]) and finite(p.size[k]) and p.size[k] > 0) then
						error(`{b.name}: bad piece {p.s} {p.c}`)
					end
				end
				for k = 1, 9 do
					T.expect(finite(p.r[k])).toBe(true)
				end
			end
		end
	end)

	T.it("is deterministic", function()
		local again = everything()
		T.expect(#again).toBe(#all)
		for i, b in all do
			local a = again[i]
			T.expect(a.name).toBe(b.name)
			T.expect(#a.bp.pieces).toBe(#b.bp.pieces)
			local p, q = a.bp.pieces[#a.bp.pieces], b.bp.pieces[#b.bp.pieces]
			if p then
				T.expect(p.p[1]).toBe(q.p[1])
				T.expect(p.c).toBe(q.c)
			end
		end
	end)

	T.it("stays within the part budgets", function()
		local total = { shell = 0, detail = 0, fine = 0 }
		for _, b in all do
			local bp = b.bp
			total.shell += bp.shell
			total.detail += bp.detail
			total.fine += bp.fine
			local limit = BUDGET[b.tag]
			if limit then
				if bp.shell > limit[1] or bp.detail > limit[2] or bp.fine > limit[3] then
					error(
						`{b.name} ({b.tag}) has {bp.shell}/{bp.detail}/{bp.fine} parts, limit {table.concat(limit, "/")}`
					)
				end
			end
		end
		-- the server builds every shell part; a client near the busiest spot builds most of the detail
		T.expect(total.shell <= 6500).toBe(true)
		T.expect(total.detail <= 32000).toBe(true)
		T.expect(total.fine <= 9000).toBe(true)
	end)

	T.it("builds every special building and the animated hooks", function()
		local names = {}
		local tags: { [string]: number } = {}
		for _, b in all do
			names[b.name] = true
			for _, p in b.bp.pieces do
				if p.tag then
					tags[p.tag] = (tags[p.tag] or 0) + 1
				end
			end
		end
		for _, sp in city.specials do
			T.expect(names[sp.id]).toBe(true)
		end
		T.expect(tags.portal).toBe(#city.gates)
		T.expect(tags.barrier).toBe(#city.gates)
		T.expect(tags.wheelAxle).toBe(1)
		T.expect((tags.wheel or 0) > 8).toBe(true)
		T.expect(tags.sailAxle).toBe(1)
		T.expect((tags.sail or 0) >= 8).toBe(true)
		T.expect((tags.smoke or 0) > 20).toBe(true)
		T.expect((tags.window or 0) > 500).toBe(true)
	end)

	T.it("keeps the pillory on the market square, clear of buildings", function()
		local P = TownGen.Props.PILLORY
		local rynek
		for _, q in city.squares do
			if q.id == "rynek" then
				rynek = q
			end
		end
		T.expect(rynek ~= nil).toBe(true)
		T.expect(TownGeom.inPoly((rynek :: any).poly, P.x, P.z)).toBe(true)
		for _, lot in city.lots do
			T.expect(TownGeom.edgeDist(TownGeom.rect(lot.x, lot.z, lot.w, lot.d, lot.rot), P.x, P.z) > 8).toBe(true)
		end
		for _, sp in city.specials do
			local poly = TownGeom.rect(sp.x, sp.z, sp.w, sp.d, sp.rot)
			T.expect(TownGeom.inPoly(poly, P.x, P.z)).toBe(false)
			T.expect(TownGeom.edgeDist(poly, P.x, P.z) > 8).toBe(true)
		end
		T.expect(math.sqrt((P.x - city.fountain[1]) ^ 2 + (P.z - city.fountain[2]) ^ 2) > 20).toBe(true)
	end)

	T.it("reports a reach for every build", function()
		for _, b in all do
			local r = TownGen.radius(b :: any)
			T.expect(r > 0 and r < 400).toBe(true)
		end
	end)

	T.it("keeps scenery outside the walls from colliding", function()
		for _, b in all do
			if b.tag == "forest" or b.tag == "field" then
				for _, p in b.bp.pieces do
					T.expect(p.col).toBe(false)
				end
			end
		end
	end)
end)
