--!strict
-- W26: bone clips of imported monster models (Data/MonsterAssets rig "bones"), played by client/Anim/BoneClips.
-- Every module `<id>.luau` holds `bones` (Mixamo names without "mixamorig:"), `frames` and `data`: base64 of
-- little-endian int16 values, frame after frame at FPS; per frame each bone's rotation (x, y, z of a unit quaternion
-- with w >= 0, times 32767), then the Hips offset (x, y, z, times 100, in the model's import units: multiply by the
-- model's scale). Decoding: Logic/BoneClip. All models share one clip layout (SLOTS: first and last frame, rate).

export type Slot = { from: number, to: number, rate: number, hit: number? } -- hit: seconds to the blow (rate 1)
export type Clip = { bones: { string }, frames: number, data: string, base: number?, slots: { [string]: Slot }? }

local MonsterClips = {}

MonsterClips.FPS = 15

local SLOTS: { [string]: Slot } = {
	idle = { from = 0, to = 29, rate = 1 },
	walk = { from = 35, to = 50, rate = 1 },
	run = { from = 55, to = 64, rate = 1 },
	attack1 = { from = 70, to = 109, rate = 2 }, -- the authored swing is slow: twice as fast fits the monster's attack
	death = { from = 114, to = 159, rate = 1 },
}

MonsterClips.SLOTS = SLOTS

local ALL: { [string]: any } = { -- the modules are plain tables (their slot tables differ in keys)
	ashOrc = require("@self/ashOrc"),
	azgor = require("@self/azgor"),
	bandit = require("@self/bandit"),
	crystalGuardian = require("@self/crystalGuardian"),
	darkCultist = require("@self/darkCultist"),
	desertMummy = require("@self/desertMummy"),
	dragonspawn = require("@self/dragonspawn"),
	fireGolem = require("@self/fireGolem"),
	fireImp = require("@self/fireImp"),
	flameSmith = require("@self/flameSmith"),
	forestWraith = require("@self/forestWraith"),
	frostGiant = require("@self/frostGiant"),
	frozenKnight = require("@self/frozenKnight"),
	goblinScout = require("@self/goblinScout"),
	goblinShaman = require("@self/goblinShaman"),
	grimrok = require("@self/grimrok"),
	hrimvald = require("@self/hrimvald"),
	koboldMiner = require("@self/koboldMiner"),
	magmaGolem = require("@self/magmaGolem"),
	marshWitch = require("@self/marshWitch"),
	morvane = require("@self/morvane"),
	necromancer = require("@self/necromancer"),
	renegadeDwarf = require("@self/renegadeDwarf"),
	skeletonGuard = require("@self/skeletonGuard"),
	swampTroll = require("@self/swampTroll"),
	werewolf = require("@self/werewolf"),
	yeti = require("@self/yeti"),
}

function MonsterClips.get(id: string): Clip?
	return ALL[id]
end

-- W26 (owner's Mixamo clips): the shared slots with the clip's own (weapon attacks, the spell, the hit reaction)
-- laid over them.
function MonsterClips.slotsFor(id: string): { [string]: Slot }
	local out: { [string]: Slot } = table.clone(SLOTS)
	local clip = ALL[id]
	if clip and clip.slots then
		for name, slot in clip.slots do
			out[name] = slot
		end
	end
	return out
end

function MonsterClips.ids(): { string }
	local out = {}
	for id in ALL do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return MonsterClips
