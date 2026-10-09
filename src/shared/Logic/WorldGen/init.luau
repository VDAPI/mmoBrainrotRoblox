--!strict
-- Registry of the region generators (S45): `WorldGen.get(mapId)` returns the generator of a shaped map
-- ({ all, trees, life, sketch, nodes, counts }) or nil. The Whispering Meadows wrap Logic/MeadowsGen (their Builds
-- are unchanged), Duskwood registers Logic/DuskwoodGen; S46/S47 add their regions here. Read by the server layout
-- (World/RegionLayout), the client (TownDetailController, WorldLifeController, DecorController), the tools and the
-- wiki. (Logic/WorldGen/Kit and Flora do not require this module.)

local AshenGen = require("./AshenGen")
local DuskwoodGen = require("./DuskwoodGen")
local FrostpeakGen = require("./FrostpeakGen")
local MeadowsGen = require("./MeadowsGen")

local WorldGen = {}

export type Build = {
	name: string,
	bp: any,
	at: { x: number, y: number, z: number, rot: number },
	tag: string,
}
export type Life = { kind: string, x: number, y: number, z: number, r: number? }
export type TreeInfo = { x: number, z: number, kind: string }
export type NodePlacement = { kind: string, x: number, z: number }
export type Counts = { shell: number, detail: number, fine: number, builds: number, lights: number }

export type Generator = {
	all: () -> { Build },
	trees: () -> { TreeInfo },
	life: () -> { Life },
	sketch: () -> { { [string]: any } },
	nodes: () -> { NodePlacement },
	counts: () -> Counts,
	radius: (build: Build) -> number,
}

local REGISTRY: { [string]: Generator } = {
	meadows = MeadowsGen :: any,
	duskwood = DuskwoodGen :: any,
	ashen = AshenGen :: any, -- S46
	frostpeak = FrostpeakGen :: any, -- S47
}

-- Generator of a map (nil for maps without one).
function WorldGen.get(mapId: string): Generator?
	return REGISTRY[mapId]
end

-- Map ids with a generator, sorted.
function WorldGen.maps(): { string }
	local ids = {}
	for id in REGISTRY do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return WorldGen
