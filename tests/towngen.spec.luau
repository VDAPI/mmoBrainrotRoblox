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
	fame = { 60, 200, 80 }, -- S124: the Hall of Fame board and four plinths with statues
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
		-- S124: the Hall of Fame writing surfaces, built on the server (shell) so World/Layouts/city can tag them
		T.expect(names.FameHall).toBe(true)
		T.expect(tags.fameBoard).toBe(1)
		T.expect(tags.famePlinth).toBe(#Town.fame.plinths)
		for _, b in all do
			if b.name == "FameHall" then
				for _, p in b.bp.pieces do
					if p.tag == "fameBoard" or p.tag == "famePlinth" then
						T.expect(p.lod).toBe("shell")
					end
				end
			end
		end
	end)

	T.it("builds the hunters' lodge and the mages' tower (S95)", function()
		local byName: { [string]: Item } = {}
		for _, b in all do
			byName[b.name] = b
		end
		-- the round top of a door leaf (Parts.door): a 0.3-thick plank cylinder
		local function hasDoor(bp: any): boolean
			for _, p in bp.pieces do
				if p.s == "cyl" and math.abs(p.size[1] - 0.3) < 1e-6 and p.m == "WoodPlanks" then
					return true
				end
			end
			return false
		end
		local kinds: { [string]: string } = {}
		for _, sp in city.specials do
			kinds[sp.id] = sp.kind
		end
		T.expect(kinds.loza).toBe("hunterLodge")
		T.expect(kinds.wieza).toBe("mageTower")
		local lodge, tower = byName.loza, byName.wieza
		T.expect(lodge ~= nil and tower ~= nil).toBe(true)
		local flag = false
		for _, p in lodge.bp.pieces do
			flag = flag or p.tag == "flag"
		end
		T.expect(flag).toBe(true)
		local crystal, topY = false, -math.huge
		for _, p in tower.bp.pieces do
			crystal = crystal or (p.m == "Neon" and p.tag == "glow")
			topY = math.max(topY, p.p[2] + p.size[2] / 2)
		end
		T.expect(crystal).toBe(true)
		local light = false
		for _, l in tower.bp.lights do
			light = light or l.tag == "glow"
		end
		T.expect(light).toBe(true)
		-- local y = 0 is the floor (at.y), on the plateau's ground
		T.expect(topY >= 25).toBe(true)
		T.expect(hasDoor(lodge.bp) and hasDoor(tower.bp)).toBe(true)
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

	-- W28: the Ristalle is a stone colosseum on its own floor: nothing else (gardens, trees, tufts, props) is drawn
	-- in its square plus the paved forecourt, the floor lies over the ground everywhere, the sand covers the yellow
	-- zone, both gates carry a server-built "Arena" sign and the 12-stud passages stay free of anything solid.
	T.it("W28: builds the Ristalle as a colosseum with nothing else in its footprint", function()
		local a = city.arena
		local R = a.half + a.stands
		local margin = TownTerrain.ARENA_MARGIN
		local arena: Item? = nil
		for _, b in all do
			if b.name == "arena" then
				arena = b
				continue
			end
			local r = math.rad(b.at.rot)
			local c, s = math.cos(r), math.sin(r)
			for _, p in b.bp.pieces do
				local x = b.at.x + p.p[1] * c + p.p[3] * s
				local z = b.at.z - p.p[1] * s + p.p[3] * c
				-- the town wall passes 4 studs off the south-east corner: only scenery is kept off the forecourt
				local m = if b.tag == "wall" or b.tag == "tower" then 0 else margin
				if TownTerrain.inArena(x, z, m) then
					error(`{b.name} ({b.tag}) draws a piece at {x}, {z} on the Ristalle`)
				end
			end
		end
		T.expect(arena ~= nil).toBe(true)
		local bp = (arena :: Item).bp
		local at = (arena :: Item).at
		T.expect(at.x).toBe(a.x)
		T.expect(at.z).toBe(a.z)
		for x = -R, R, 6 do
			for z = -R, R, 6 do
				T.expect(at.y > TownTerrain.heightAt(a.x + x, a.z + z)).toBe(true)
			end
		end
		local signs, sand = 0, false
		for _, p in bp.pieces do
			if p.tag == "arenaSign" then
				signs += 1
				T.expect(p.lod).toBe("shell")
			end
			if p.m == "Sand" and p.lod == "shell" and p.size[1] >= 2 * a.half and p.size[3] >= 2 * a.half then
				sand = true
			end
			local x, z = p.p[1], p.p[3]
			-- inside the square of half + stands (a hair over for the outer face's trim, banners and torches)
			T.expect(math.abs(x) <= R + 1.5 and math.abs(z) <= R + 1.5).toBe(true)
			-- the gate passages (z-axis sides, |x| < 6) hold no colliding piece above the floor
			if p.col and p.p[2] > 0.5 and math.abs(z) > a.half + 0.5 and math.abs(z) < R then
				T.expect(math.abs(x) - p.size[1] / 2 >= 5.9 or math.abs(p.p[2]) > 7).toBe(true)
			end
		end
		T.expect(signs).toBe(2)
		T.expect(sand).toBe(true)
		T.expect(#bp.lights >= 8).toBe(true)
		for x = -R - margin, R + margin, 4 do
			for z = -R - margin, R + margin, 4 do
				local m = TownTerrain.materialAt(a.x + x, a.z + z, TownTerrain.heightAt(a.x + x, a.z + z), 0)
				if m == "Grass" or m == "LeafyGrass" then
					error(`grass at {a.x + x}, {a.z + z} under the Ristalle`)
				end
			end
		end
	end)
end)
