--!strict
-- City building generator (S21): plan data in, Blueprints out. Pure and deterministic. See docs/miasto/MIASTO.md.

local Blueprint = require("@self/Blueprint")
local Fill = require("@self/Fill")
local Gardens = require("@self/Gardens")
local Houses = require("@self/Houses")
local Outside = require("@self/Outside")
local Palette = require("@self/Palette")
local Parts = require("@self/Parts")
local Props = require("@self/Props")
local Specials = require("@self/Specials")
local Structures = require("@self/Structures")

local TownGen = {}

TownGen.Blueprint = Blueprint
TownGen.Fill = Fill
TownGen.Gardens = Gardens
TownGen.Houses = Houses
TownGen.Outside = Outside
TownGen.Palette = Palette
TownGen.Parts = Parts
TownGen.Props = Props
TownGen.Specials = Specials
TownGen.Structures = Structures

export type Blueprint = Blueprint.Blueprint
export type Piece = Blueprint.Piece
export type Placement = Houses.Placement
export type Build = Structures.Build
export type Ground = Structures.Ground

-- Every Build of the city in a fixed order: houses, walls (with towers and gatehouses), retaining walls, ramps,
-- bridges, lamps, special buildings, props, gardens, outside. Server and client call it with the same plan and
-- TownTerrain.heightAt and get identical lists (same names, same pieces), so the client can build the detail
-- levels of what the server built as shell.
function TownGen.all(city: any, ground: Ground): { Build }
	local out: { any } = {}
	for _, lot in city.lots do
		local bp, at = Houses.build(lot, ground)
		table.insert(out, { name = lot.id, tag = "house", bp = bp, at = at })
	end
	for _, key in { "walls", "retaining", "ramps", "bridges", "lamps" } do
		for _, b in (Structures :: any)[key](city, ground) do
			table.insert(out, b)
		end
	end
	for _, mod in { Specials, Props, Gardens, Outside } :: { any } do
		for _, b in mod.all(city, ground) do
			table.insert(out, b)
		end
	end
	return out :: any
end

-- Horizontal reach of a Build from its `at` point: the farthest piece centre plus half its largest side. The
-- client uses it with at.x/at.z to decide which Builds are inside the detail radius.
function TownGen.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

return TownGen
