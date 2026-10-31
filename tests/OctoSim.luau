--!strict
-- Test helper (template animation, docs/ANIM-WZORCE.md §6.6): the rigged caveSpider from its rig dump
-- (tools/anim/rigs/caveSpider_v2.json, FBX units scaled to the look in the game) walked by Logic/RigidMotion and
-- Logic/OctoMotion frame by frame, the root's move integrated in the world, so the specs can see where the feet really
-- are without Studio.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local OctoMotion = require("../src/shared/Logic/OctoMotion")
local OctoPose = require("../src/shared/Logic/OctoPose")
local OctoRigs = require("../src/shared/Data/OctoRigs")
local RigidMotion = require("../src/shared/Logic/RigidMotion")

local OctoSim = {}

-- Studs per FBX unit of the look in the game (the asset 5.06 studs wide x the kind's look scale, as tests/rigidmotion).
OctoSim.SCALE = 7.3

export type Dump = { bones: { [string]: OctoPose.Bone }, names: { string }, h: number, B: number, W: number }

-- The dump of `file` (tools/anim/rigs/<file>.json): bone heads scaled, identity rest frames (OctoPose reads positions).
function OctoSim.load(file: string, scale: number?): Dump
	local k = scale or OctoSim.SCALE
	local raw = serde.decode("json", fs.readFile(`tools/anim/rigs/{file}.json`))
	local bones: { [string]: OctoPose.Bone } = {}
	local names: { string } = {}
	for _, b in raw.bones do
		local p = b.head or b.pos or b.position
		local pos = if p then { p[1] * k, p[2] * k, p[3] * k } else { 0, 0, 0 }
		bones[b.name] = { rest = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, pos = pos, parent = b.parent }
		table.insert(names, b.name)
	end
	local size = raw.size or { 1, 1, 1 }
	return { bones = bones, names = names, W = size[1] * k, h = size[2] * k, B = size[3] * k }
end

function OctoSim.skeleton(dump: Dump): OctoPose.Skeleton
	local rig = OctoRigs.find("caveSpider", function(name: string): boolean
		return dump.bones[name] ~= nil
	end)
	assert(rig, "no caveSpider map matches the dump")
	return assert(OctoPose.skeleton(dump.bones, rig, 0), "no skeleton")
end

export type Sim = {
	rigid: RigidMotion.Instance,
	octo: OctoMotion.Instance,
	skel: OctoPose.Skeleton,
	posed: RigidMotion.Posed?,
	-- the root in the world (x, z, yaw: + left)
	x: number,
	z: number,
	yaw: number,
	now: number,
}

function OctoSim.new(seed: number?): Sim
	local dump = OctoSim.load("caveSpider_v2")
	local skel = OctoSim.skeleton(dump)
	local body: RigidMotion.Body = { h = dump.h, lift = 0, B = dump.B, W = dump.W, x0 = 0, z0 = 0, squash = false }
	local rigid = assert(RigidMotion.new(body, "spider", seed or 7.3))
	local octo = OctoMotion.new(skel, seed or 7.3)
	body.folds = OctoMotion.folds(octo, body)
	return { rigid = rigid, octo = octo, skel = skel, posed = nil, x = 0, z = 0, yaw = 0, now = 0 }
end

-- A point of the ground frame (the root's) in the world.
function OctoSim.world(sim: Sim, x: number, z: number): (number, number)
	local c, s = math.cos(sim.yaw), math.sin(sim.yaw)
	return sim.x + x * c + z * s, sim.z - x * s + z * c
end

-- One frame `dt` long: `input` RigidMotion's (now and dt are set here), the root moving at `speed` straight ahead and
-- turning at `yawRate` (the game's way, `game`), or the look standing while the ground runs under it (AnimLab's).
function OctoSim.step(sim: Sim, dt: number, input: { [string]: any }, game: boolean?): RigidMotion.Posed
	sim.now += dt
	local i: { [string]: any } = { now = sim.now, dt = dt, speed = 0, yawRate = 0, combat = false }
	for k, v in input do
		i[k] = v
	end
	local octoIn: OctoMotion.Input = {}
	if game then
		local dz = -(i.speed :: number) * dt
		local dyaw = (i.yawRate :: number) * dt
		octoIn.dx, octoIn.dz, octoIn.dyaw = 0, dz, dyaw
		i.yawDelta = dyaw
		-- the root moves in its frame before the turn
		local c, s = math.cos(sim.yaw), math.sin(sim.yaw)
		sim.x += dz * s
		sim.z += dz * c
		sim.yaw += dyaw
	end
	local posed = RigidMotion.step(sim.rigid, i :: any)
	OctoMotion.step(sim.octo, sim.rigid, i :: any, posed, octoIn)
	sim.posed = posed
	return posed
end

-- Where the drawn foot of leg `i` is (ground frame): its turns through the body's transform.
function OctoSim.foot(sim: Sim, i: number): (number, number, number)
	local leg = sim.skel.legs[i]
	local f = sim.octo.feet[i]
	local x, y, z = OctoPose.foot(leg, f.psi, f.c)
	local m = (sim.posed :: RigidMotion.Posed).m
	return m[1] * x + m[2] * y + m[3] * z + m[10],
		m[4] * x + m[5] * y + m[6] * z + m[11],
		m[7] * x + m[8] * y + m[9] * z + m[12]
end

-- Every joint of leg `i` (ground frame).
function OctoSim.joints(sim: Sim, i: number): { { number } }
	local leg = sim.skel.legs[i]
	local f = sim.octo.feet[i]
	local pts = OctoPose.joints(leg, f.psi, f.c, {})
	local m = (sim.posed :: RigidMotion.Posed).m
	local out = {}
	for j, p in pts do
		local x, y, z = p[1], p[2], p[3]
		out[j] = {
			m[1] * x + m[2] * y + m[3] * z + m[10],
			m[4] * x + m[5] * y + m[6] * z + m[11],
			m[7] * x + m[8] * y + m[9] * z + m[12],
		}
	end
	return out
end

return OctoSim
