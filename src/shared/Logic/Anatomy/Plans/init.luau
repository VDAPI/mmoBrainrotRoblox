--!strict
-- Body plans of the procedural looks (S24): plan name -> builder function, plus which plans float.

local Builder = require("./Builder")
local Creatures = require("@self/Creatures")
local Humanoids = require("@self/Humanoids")
local Quadrupeds = require("@self/Quadrupeds")
local Spirits = require("@self/Spirits")

export type Plan = (b: Builder.Builder) -> ()

local PLANS: { [string]: Plan } = {
	hare = Quadrupeds.hare,
	canine = Quadrupeds.canine,
	bear = Quadrupeds.bear,
	boar = Quadrupeds.boar,
	toad = Quadrupeds.toad,
	lizard = Quadrupeds.lizard,
	mammoth = Quadrupeds.mammoth,
	serpent = Creatures.serpent,
	spider = Creatures.spider,
	scorpion = Creatures.scorpion,
	bird = Creatures.bird,
	bat = Creatures.bat,
	dragon = Creatures.dragon,
	humanoid = Humanoids.humanoid,
	beast = Humanoids.beast,
	golem = Spirits.golem,
	treant = Spirits.treant,
	ghost = Spirits.ghost,
	elemental = Spirits.elemental,
}

-- Plans that hover above the ground (Anatomy adds the hover height to hipHeight and height).
local HOVER: { [string]: boolean } = { bird = true, bat = true, ghost = true, elemental = true }

return table.freeze({
	list = PLANS,
	get = function(name: string): Plan?
		return PLANS[name]
	end,
	hovers = function(name: string): boolean
		return HOVER[name] == true
	end,
})
