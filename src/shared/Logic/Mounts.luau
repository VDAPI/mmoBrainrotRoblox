--!strict
-- Mount rules (S96, docs/DESIGN-15.md §2). Pure: riding speed, mounting time, where riding is allowed, who may
-- mount, granting a mount and where the rider sits on the procedural horse. MountService (server), StatService
-- (walk speed), the HUD and tests/mounts.spec use it; S97 (upgrades, boss mounts, skins) builds on it.

local Config = require("../Config")
local Maps = require("../Data/Maps")
local MountData = require("../Data/Mounts")
local Stats = require("../Data/Stats")

local Mounts = {}

export type Owned = { [string]: { lvl: number } }
export type MountState = { owned: Owned, active: string?, riding: boolean }
export type Reason = "dead" | "level" | "none" | "riding" | "combat" | "place" | "busy"
export type CheckInput = {
	level: number, -- character level
	mounts: MountState?,
	dead: boolean,
	inCombat: boolean,
	mapId: string,
	zoneKey: string?, -- ZoneService nameKey
	busy: boolean, -- travel / gather / fishing / quest use / skill channel running
}
export type Seat = { hipHeight: number, offset: { number } } -- offset: LookRoot centre from the rider's root centre
export type Part = { key: string, value: number, pct: boolean? }
export type SpeedInput = {
	riding: boolean,
	lvl: number?, -- mount level (riding)
	walk: number, -- StatCalc result.walkSpeed (gear, passives and effects; used on foot)
	gearMove: number, -- moveSpeed points from equipment only (Mounts.gearMove)
	sprint: boolean,
	factor: number, -- S63 slow factor 0..1
}
export type SeatRig = {
	root: { size: { number } },
	hipHeight: number,
	sockets: { [string]: { pos: { number }, parent: string? } },
}

-- StatCalc source key of equipment (EquipmentService modifier source "gear"); item traits go through it too.
Mounts.GEAR_SOURCE = "source.gear"

local M = Config.Mount

local function clampLevel(lvl: number?): number
	return math.clamp(math.floor(lvl or 1), 1, M.maxLevel)
end

-- Speed multiplier of a mount level: baseMul at 1 rising linearly to maxMul at maxLevel (one cap for every mount).
function Mounts.speedMul(lvl: number?): number
	local l = clampLevel(lvl)
	return M.baseMul + (M.maxMul - M.baseMul) * (l - 1) / (M.maxLevel - 1)
end

-- Seconds of standing still to mount.
function Mounts.mountTime(lvl: number?): number
	return if (lvl or 1) >= M.fastFromLevel then M.mountTimeFast else M.mountTime
end

-- moveSpeed points from equipment in a StatCalc breakdown (result.breakdown.moveSpeed), 0..cap. Effects
-- (Camouflage, allyMove, Vigilance) and passives (Hunter agility, March) do not count on a mount.
function Mounts.gearMove(parts: { Part }?): number
	local total = 0
	if parts then
		for _, part in parts do
			if part.key == Mounts.GEAR_SOURCE and not part.pct then
				total += part.value
			end
		end
	end
	local def = Stats.get("moveSpeed")
	local cap = if def and def.cap then def.cap else math.huge
	return math.clamp(total, 0, cap)
end

-- The one walk speed rule of a player character. Riding: base walk x mount multiplier x (1 + gear moveSpeed /
-- 100) x slow factor (no buffs, no passives, no sprint). On foot: result.walkSpeed x sprint x slow factor (S63).
function Mounts.walkSpeed(input: SpeedInput): number
	if input.riding then
		local def = Stats.get("moveSpeed")
		local cap = if def and def.cap then def.cap else math.huge
		local gear = math.clamp(input.gearMove, 0, cap)
		return Stats.Formula.walkSpeed * Mounts.speedMul(input.lvl) * (1 + gear / 100) * input.factor
	end
	return input.walk * (if input.sprint then Config.SprintMultiplier else 1) * input.factor
end

-- Riding is allowed in the city and on open region maps: not in caves, crypts, boss dungeons or the arena.
function Mounts.allowedAt(mapId: string, zoneKey: string?): boolean
	local map = Maps.get(mapId)
	if not map then
		return false
	end
	if table.find(MountData.RULES.noBiomes, map.biome) then
		return false
	end
	if zoneKey and table.find(MountData.RULES.noZones, zoneKey) then
		return false
	end
	return true
end

-- The mount in use: `active` when owned, otherwise the first owned one by id. Returns its id and level (1..maxLevel),
-- or nil, 0 without a known mount.
function Mounts.activeOf(state: MountState?): (string?, number)
	if not state or not state.owned then
		return nil, 0
	end
	local id: string? = nil
	if state.active and state.owned[state.active] and MountData.get(state.active) then
		id = state.active
	else
		local ids: { string } = {}
		for owned in state.owned do
			if MountData.get(owned) then
				table.insert(ids, owned)
			end
		end
		table.sort(ids)
		id = ids[1]
	end
	if not id then
		return nil, 0
	end
	local entry = state.owned[id]
	return id, clampLevel(if entry then entry.lvl else 1)
end

-- Why the character cannot start mounting now (nil = it can). Message: mount.error.<reason> (not for "riding").
function Mounts.canMount(input: CheckInput): Reason?
	if input.dead then
		return "dead"
	end
	if input.level < M.minLevel then
		return "level"
	end
	if Mounts.activeOf(input.mounts) == nil then
		return "none"
	end
	if input.mounts and input.mounts.riding then
		return "riding"
	end
	if input.inCombat then
		return "combat"
	end
	if not Mounts.allowedAt(input.mapId, input.zoneKey) then
		return "place"
	end
	if input.busy then
		return "busy"
	end
	return nil
end

-- Adds a mount at its start level (the first one also becomes active). False for an unknown or owned id: a second
-- grant never resets the level.
function Mounts.grant(state: MountState, id: string): boolean
	local def = MountData.get(id)
	if not def or state.owned[id] then
		return false
	end
	state.owned[id] = { lvl = clampLevel(def.startLevel) }
	state.active = state.active or id
	return true
end

-- Where the rider sits on a procedural mount rig. The LookRoot centre is H0 = hipHeight + root height / 2 above the
-- ground; the saddle socket (relative to it) at H0 + s.y; the rider's root centre Hr = H0 + s.y + RIDER.seatLift.
-- `rootHalf` = half the rider's HumanoidRootPart height. Returns the rider's HipHeight and the LookRoot offset from
-- the rider's root (the horse moved so the saddle is under the rider and the hooves on the ground).
function Mounts.seat(rig: SeatRig, rootHalf: number): Seat
	local h0 = rig.hipHeight + rig.root.size[2] / 2
	local socket = rig.sockets.Saddle
	local s = if socket then socket.pos else { 0, rig.root.size[2] / 2, 0 }
	return Mounts.seatAt(h0, s, rootHalf)
end

-- The same for a model whose saddle `s` is given from a point `h0` studs above the ground (a real model: its pivot
-- on the ground, h0 = 0).
function Mounts.seatAt(h0: number, s: { number }, rootHalf: number): Seat
	local hr = h0 + s[2] + MountData.RIDER.seatLift
	return { hipHeight = hr - rootHalf, offset = { -s[1], h0 - hr, -s[3] } }
end

return Mounts
