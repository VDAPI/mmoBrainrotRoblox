--!strict
-- Mount rules (S96, docs/DESIGN-15.md §2). Pure: riding speed, mounting time, where riding is allowed, who may
-- mount, granting a mount and where the rider sits on the procedural horse. MountService (server), StatService
-- (walk speed), the HUD and tests/mounts.spec use it. S97: upgrades at the stablemaster (upgradeCost, canUpgrade),
-- the personal boss roll (rollBossDrop), what the mounts window lists (isObtainable) and the look with a skin
-- (lookWith). 2026-11-01: the tint a skin lays over a textured real model (coatTint).

local Config = require("../Config")
local Cosmetics = require("../Data/Cosmetics")
local Maps = require("../Data/Maps")
local MountData = require("../Data/Mounts")
local Rng = require("./Rng")
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
-- on the ground, h0 = 0); `seatLift`: a mount's own (Logic/RiderPose.rider), default RIDER's.
function Mounts.seatAt(h0: number, s: { number }, rootHalf: number, seatLift: number?): Seat
	local hr = h0 + s[2] + (seatLift or MountData.RIDER.seatLift)
	return { hipHeight = hr - rootHalf, offset = { -s[1], h0 - hr, -s[3] } }
end

-- Upgrades (S97) ---------------------------------------------------------------------------------------------------

-- The step that raises a mount to `toLevel` (2..maxLevel), nil outside.
function Mounts.upgradeCost(toLevel: number): MountData.UpgradeStep?
	if toLevel < 2 or toLevel > M.maxLevel then
		return nil
	end
	return MountData.UPGRADE[toLevel]
end

export type UpgradeCharacter = { level: number, gold: number, mounts: MountState? }

-- Whether the character can raise `mountId` by one level now. `inv` = pieces of each material in the backpack (the
-- server counts them through InventoryService.Count). Errors (Locale keys) in this order: notOwned, maxLevel,
-- upgradeLevel, gold, materials. On success: true, nil, the step.
function Mounts.canUpgrade(
	character: UpgradeCharacter,
	mountId: string,
	inv: { [string]: number }
): (boolean, string?, MountData.UpgradeStep?)
	local state = character.mounts
	local entry = state and state.owned and state.owned[mountId]
	if not entry or not MountData.get(mountId) then
		return false, "mount.error.notOwned", nil
	end
	local lvl = clampLevel(entry.lvl)
	if lvl >= M.maxLevel then
		return false, "mount.error.maxLevel", nil
	end
	local step = Mounts.upgradeCost(lvl + 1)
	if not step then
		return false, "mount.error.maxLevel", nil
	end
	if character.level < step.level then
		return false, "mount.error.upgradeLevel", step
	end
	if character.gold < step.gold then
		return false, "mount.error.gold", step
	end
	for _, m in step.materials do
		if (inv[m.id] or 0) < m.n then
			return false, "mount.error.materials", step
		end
	end
	return true, nil, step
end

-- Boss mounts (S97) -------------------------------------------------------------------------------------------------

export type BossRoll = { mount: string?, skin: string? }

-- The personal roll of one winner of a kill of `bossId` (Data/Mounts.BOSS_DROPS): one chance for the boss's mount
-- unless the character owns it, then one for its skin unless the account owns it. An owned one is not rolled at all
-- (the rng stays untouched). No luck and no kills-today ladder: apart from the item rolls of Logic/Loot.
function Mounts.rollBossDrop(
	bossId: string,
	ownedMounts: { [string]: any },
	ownedSkins: { [string]: boolean },
	rng: Rng.Rng
): BossRoll
	local drop = MountData.BOSS_DROPS[bossId]
	local out: BossRoll = {}
	if not drop then
		return out
	end
	if drop.mount and drop.mountChance and ownedMounts[drop.mount] == nil then
		if rng:chance(drop.mountChance) then
			out.mount = drop.mount
		end
	end
	if drop.skin and drop.skinChance and not ownedSkins[drop.skin] then
		if rng:chance(drop.skinChance) then
			out.skin = drop.skin
		end
	end
	return out
end

-- The mount a boss drops (nil when none).
function Mounts.bossMountOf(bossId: string): string?
	local drop = MountData.BOSS_DROPS[bossId]
	return if drop then drop.mount else nil
end

-- Kills on average for one drop of chance `chance`.
function Mounts.expectedKills(chance: number): number
	return if chance > 0 then 1 / chance else math.huge
end

-- Whether a mount is something a player can get now (the mounts window's "To obtain"): quest, boss and event mounts
-- always, a premium one only while its product is on sale.
function Mounts.isObtainable(def: MountData.MountDef, premiumEnabled: (id: string) -> boolean): boolean
	if def.source == "premium" then
		return premiumEnabled(def.id)
	end
	return true
end

-- Skins (S97) -------------------------------------------------------------------------------------------------------

-- The look of a mount with a mount skin: a shallow copy with new colour and material tables (the skin's values win),
-- the mount's parts plus the skin's (no duplicates) and the skin's glow. Never changes the input (Data is frozen). A
-- nil skin or a cosmetic of another kind gives an unchanged copy.
function Mounts.lookWith(look: any, skin: Cosmetics.Def?): any
	local out = table.clone(look)
	out.colors = table.clone(look.colors or {})
	out.materials = if look.materials then table.clone(look.materials) else nil
	out.parts = if look.parts then table.clone(look.parts) else nil
	if not skin or skin.kind ~= "mountskin" or not skin.skin then
		return out
	end
	local over = skin.skin
	for role, color in (over.colors or {}) :: { [string]: string } do
		out.colors[role] = color
	end
	if over.materials then
		local materials = out.materials or {}
		for role, material in over.materials do
			materials[role] = material
		end
		out.materials = materials
	end
	if over.parts then
		local parts = out.parts or {}
		for _, part in over.parts do
			if not table.find(parts, part) then
				table.insert(parts, part)
			end
		end
		out.parts = parts
	end
	if over.glow then
		out.glow = over.glow
	end
	return out
end

-- "#RRGGBB" -> { r, g, b } in 0..255 (nil for anything else).
local function channels(hex: string?): { number }?
	if type(hex) ~= "string" then
		return nil
	end
	local r, g, b = string.match(hex, "^#?(%x%x)(%x%x)(%x%x)$")
	if not r then
		return nil
	end
	return { tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number }
end

-- Tints below this on every channel leave the coat as it is (a skin as light as the coat or lighter).
Mounts.TINT_FLOOR = 0.97

-- 2026-11-01 (real mount models): the colour a mount skin multiplies a textured real model by (Util/LookBuild.recolor,
-- the tint of Data/MonsterAssetVariants). `coat` is the base colour of the mount's own look (Data/Mounts look.colors
-- .base, what its texture shows); each channel is min(1, skin / coat), so the coat darkens toward the skin's base
-- colour and never past it. A multiply cannot lighten: a skin lighter than the coat (or one without a base colour, a
-- cosmetic of another kind, no skin) gives nil and the texture stays as it is.
function Mounts.coatTint(coat: string?, skin: Cosmetics.Def?): string?
	local over = if skin and skin.kind == "mountskin" then skin.skin else nil
	local want = channels(over and over.colors and over.colors.base)
	local have = channels(coat)
	if not want or not have then
		return nil
	end
	local tint = {}
	local darker = false
	for i = 1, 3 do
		local k = if have[i] <= 0 then 1 else math.min(1, want[i] / have[i])
		darker = darker or k < Mounts.TINT_FLOOR
		tint[i] = math.floor(k * 255 + 0.5)
	end
	if not darker then
		return nil
	end
	return string.format("#%02X%02X%02X", tint[1], tint[2], tint[3])
end

return Mounts
