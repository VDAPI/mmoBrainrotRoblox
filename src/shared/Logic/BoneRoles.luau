--!strict
-- W26: roles of the bones of an imported rig without clips (Tripo auto-rigs of animals, dragons, birds), found from
-- the rest skeleton alone, so client/Anim/BoneGait can walk, flap and wag them with Logic/Gait's motion. Positions are
-- in the model's frame (feet at y = 0, front towards -Z).
--   leg  : the chain to a leaf near the ground; its top bone (the first one away from the centre line) swings, the
--          next one bends; front (z < middle) or hind, left (x < 0) or right
--   wing : the chain to a leaf far out to the side and high; its first bone off the centre line flaps
--   tail : bones named *Tail*: the first one wags, the rest follow
--   head : the first bone named *Head*: nods and looks round
--   spine: the first bone named *Spine*: bends with the step

local BoneRoles = {}

export type BoneIn = { name: string, parent: number?, pos: { number } } -- parent: index in the same list
export type Role = {
	bone: number,
	role: "leg" | "knee" | "wing" | "tail" | "head" | "spine",
	side: number, -- -1 left, 1 right, 0 centre
	front: number, -- 1 front, -1 hind, 0 centre
	phase: number, -- 0..1 in the walk cycle
	depth: number, -- position along a tail (0 = root)
}

local GROUND = 0.15 -- leaf height (share of the model height) that counts as a foot
local CENTRE = 0.12 -- |x| (share of the model's width) still on the centre line
local WING_OUT = 0.3 -- a wing tip is this far out (share of the width) ...
local WING_UP = 0.35 -- ... and this high (share of the height)

function BoneRoles.classify(bones: { BoneIn }, height: number, width: number, depthMid: number): { Role }
	local children: { [number]: number } = {}
	for _, b in bones do
		if b.parent then
			children[b.parent] = (children[b.parent] or 0) + 1
		end
	end
	local taken: { [number]: boolean } = {}
	local out: { Role } = {}
	local function offCentre(i: number): boolean
		return math.abs(bones[i].pos[1]) > CENTRE * width
	end
	-- the first bone of the chain from the root to `leaf` that leaves the centre line, and the one after it
	local function chainTop(leaf: number): (number?, number?)
		local chain: { number } = {}
		local cur: number? = leaf
		while cur do
			table.insert(chain, 1, cur)
			cur = bones[cur].parent
		end
		for k, i in chain do
			if offCentre(i) then
				return i, chain[k + 1]
			end
		end
		return nil, nil
	end
	local legs: { { top: number, knee: number?, x: number, z: number } } = {}
	for i, b in bones do
		if children[i] then
			continue
		end
		local y = b.pos[2]
		if y < GROUND * height then
			local top, knee = chainTop(i)
			if top and not taken[top] then
				taken[top] = true
				table.insert(legs, { top = top, knee = knee, x = bones[top].pos[1], z = bones[top].pos[3] })
			end
		elseif math.abs(b.pos[1]) > WING_OUT * width and y > WING_UP * height then
			local top = chainTop(i)
			if top and not taken[top] then
				taken[top] = true
				local side = if bones[top].pos[1] < 0 then -1 else 1
				table.insert(out, { bone = top, role = "wing", side = side, front = 0, phase = 0, depth = 0 })
			end
		end
	end
	local quadruped = #legs >= 4
	for _, leg in legs do
		local side = if leg.x < 0 then -1 else 1
		local front = if leg.z < depthMid then 1 else -1
		-- a trot: front-left with hind-right; two legs alternate
		local phase = if quadruped
			then (if front == 1 then 0 else 0.5) + (if side < 0 then 0 else 0.5)
			else (if side < 0 then 0 else 0.5)
		table.insert(out, { bone = leg.top, role = "leg", side = side, front = front, phase = phase % 1, depth = 0 })
		if leg.knee and not taken[leg.knee] then
			taken[leg.knee] = true
			table.insert(
				out,
				{ bone = leg.knee, role = "knee", side = side, front = front, phase = phase % 1, depth = 0 }
			)
		end
	end
	local headDone, spineDone = false, false
	local tailDepth = 0
	for i, b in bones do
		if taken[i] then
			continue
		end
		local name = string.lower(b.name)
		if string.find(name, "tail", 1, true) then
			table.insert(out, { bone = i, role = "tail", side = 0, front = 0, phase = 0, depth = tailDepth })
			tailDepth += 1
		elseif not headDone and string.find(name, "head", 1, true) then
			headDone = true
			table.insert(out, { bone = i, role = "head", side = 0, front = 0, phase = 0, depth = 0 })
		elseif not spineDone and string.find(name, "spine", 1, true) then
			spineDone = true
			table.insert(out, { bone = i, role = "spine", side = 0, front = 0, phase = 0, depth = 0 })
		end
	end
	return out
end

-- Rotation (radians) of a role about its axis for Logic/Gait's motion numbers; the axis is the model's side axis (X)
-- for legs, knees, heads and spines, the forward axis (Z) for wings and the up axis (Y) for tails.
function BoneRoles.angle(
	r: Role,
	cycle: number,
	move: number,
	time: number,
	raise: number,
	strike: number,
	hit: number,
	flying: number
): number
	local swing = math.sin(cycle + r.phase * 2 * math.pi)
	local idle = 1 - move
	if r.role == "leg" then
		local attack = if r.front == 1 then raise * 0.5 - strike * 0.3 else 0
		return swing * 0.5 * move + attack - flying * 0.4
	elseif r.role == "knee" then
		-- the foot lifts on the way forward: front knees fold back, hind hocks forward
		local lift = math.max(0, math.cos(cycle + r.phase * 2 * math.pi)) * 0.6 * move
		return (if r.front == 1 then -lift else lift) + flying * 0.5 * r.front
	elseif r.role == "wing" then
		local busy = math.max(move, raise, flying)
		local speed = 3 + 5 * busy
		local width = 0.2 + 0.35 * busy
		return r.side * (0.1 + math.sin(time * speed) * width)
	elseif r.role == "tail" then
		local wag = math.sin(time * 2.2 - r.depth * 0.7) * 0.18 + math.sin(cycle) * 0.12 * move
		return wag
	elseif r.role == "head" then
		local nod = math.sin(cycle * 2) * 0.06 * move + math.sin(time * 0.8) * 0.05 * idle
		return nod + raise * 0.3 - strike * 0.45 + hit * 0.15
	elseif r.role == "spine" then
		return math.sin(cycle * 2) * 0.04 * move + raise * 0.08 - strike * 0.1
	end
	return 0
end

return BoneRoles
