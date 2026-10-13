--!strict
-- S96: mounts 1 (docs/DESIGN-15.md §2): data (Data/Mounts, Config.Mount), the horse look (Logic/Anatomy plan "horse"),
-- riding speed, places, who may mount, granting, the seat, the rider pose and the save template.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Anatomy = require("../src/shared/Logic/Anatomy")
local Config = require("../src/shared/Config")
local Maps = require("../src/shared/Data/Maps")
local MountData = require("../src/shared/Data/Mounts")
local Mounts = require("../src/shared/Logic/Mounts")
local Quests = require("../src/shared/Data/Quests")
local RiderPose = require("../src/shared/Logic/RiderPose")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Test = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- The save schema before S96; mounts come through the template and reconcile, never a migration.
local SCHEMA_BEFORE_S96 = 6

local SOURCES = { quest = true, boss = true, premium = true, event = true }
local RIGS = { animator = true, gait = true, static = true }
local BIOMES = { "city", "grass", "forest", "desert", "snow", "cave", "crypt", "dungeon" }

local function hasKey(key: string): boolean
	return (pl :: any)[key] ~= nil and (en :: any)[key] ~= nil
end

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function rigOf(def: MountData.MountDef, lod: ("far" | nil)?): Anatomy.Rig
	return Anatomy.build(def.look, { id = def.id, variant = "mount", scale = def.scale or 1, lod = lod })
end

local function horse(): MountData.MountDef
	return assert(MountData.get("mount_horse"))
end

local function input(over: { [string]: any }?): Mounts.CheckInput
	local base: { [string]: any } = {
		level = 20,
		mounts = { owned = { mount_horse = { lvl = 1 } }, active = "mount_horse", riding = false },
		dead = false,
		inCombat = false,
		mapId = "meadows",
		zoneKey = nil,
		busy = false,
	}
	for k, v in over or {} do
		base[k] = v
	end
	return base :: any
end

describe("Mounts: data", function()
	it("lists mounts with unique mount_ ids, start levels, sources and names", function()
		expect(#MountData.list > 0).toBe(true)
		local seen: { [string]: boolean } = {}
		for _, def in MountData.list do
			expect(seen[def.id]).toBe(nil)
			seen[def.id] = true
			expect(string.sub(def.id, 1, 6)).toBe("mount_")
			expect(def.startLevel == math.floor(def.startLevel)).toBe(true)
			expect(def.startLevel >= 1 and def.startLevel <= Config.Mount.maxLevel).toBe(true)
			expect(SOURCES[def.source]).toBe(true)
			expect(def.nameKey).toBe(`mount.{def.id}.name`)
			expect(hasKey(def.nameKey)).toBe(true)
			expect(MountData.get(def.id)).toBe(def)
		end
		local h = horse()
		expect(h.source).toBe("quest")
		expect(h.startLevel).toBe(1)
		expect(h.wiki).toBe(false)
	end)

	it("has valid real model entries and riding rules", function()
		for id, asset in MountData.assets do
			expect(MountData.get(id) ~= nil).toBe(true)
			expect(type(asset.model) == "string" and asset.model ~= "").toBe(true)
			expect(#asset.saddle).toBe(3)
			for _, n in asset.saddle do
				expect(finite(n)).toBe(true)
			end
			expect(RIGS[asset.rig]).toBe(true)
		end
		for _, biome in MountData.RULES.noBiomes do
			expect(table.find(BIOMES, biome) ~= nil).toBe(true)
		end
		expect(table.find(MountData.RULES.noZones, "zone.arena") ~= nil).toBe(true)
	end)
end)

describe("Mounts: look", function()
	it("builds every mount within budget with a saddle, four legs, head, tail and body joints", function()
		local materials: { [string]: boolean } = {}
		for _, m in Anatomy.MATERIALS do
			materials[m] = true
		end
		for _, def in MountData.list do
			local rig = rigOf(def)
			expect(#rig.pieces <= Anatomy.BUDGET.mount).toBe(true)
			expect(rig.sockets.Saddle ~= nil and rig.sockets.Head ~= nil and rig.sockets.Back ~= nil).toBe(true)
			local legs = { [-1] = 0, [1] = 0 }
			local roles: { [string]: boolean } = {}
			local names: { [string]: boolean } = {}
			local half = rig.root.size[2] / 2
			local lowest = math.huge
			for _, piece in rig.pieces do
				expect(names[piece.name]).toBe(nil)
				names[piece.name] = true
				expect(materials[piece.material]).toBe(true)
				if piece.joint then
					roles[piece.joint.role] = true
					if piece.joint.role == "leg" then
						legs[piece.joint.side] = (legs[piece.joint.side] or 0) + 1
					end
				end
				local e = Anatomy.extents(piece.size, piece.rot)
				lowest = math.min(lowest, piece.pos[2] - e[2])
			end
			expect(legs[-1]).toBe(2)
			expect(legs[1]).toBe(2)
			expect(roles.head and roles.tail and roles.body).toBe(true)
			-- the hooves stand on the ground: ground = hipHeight + half the root below the root centre
			expect(lowest).toBeNear(-(rig.hipHeight + half), 0.05)
		end
	end)

	it("is deterministic, has no chibi parts and keeps a far silhouette of at most 3 pieces", function()
		for _, def in MountData.list do
			local a = rigOf(def)
			local b = rigOf(def)
			expect(#a.pieces).toBe(#b.pieces)
			for i, piece in a.pieces do
				expect(piece.name).toBe(b.pieces[i].name)
				expect(piece.pos).toEqual(b.pieces[i].pos)
			end
			local far = rigOf(def, "far")
			expect(#far.pieces >= 1 and #far.pieces <= Anatomy.BUDGET.far).toBe(true)
		end
	end)

	it("fits the fringes of a feathered horse in the budget", function()
		local look = table.clone(horse().look)
		look.build = { mane = 1, tail = 1, feathering = 1 }
		local rig = Anatomy.build(look, { id = "mount_test", variant = "mount" })
		expect(#rig.pieces <= Anatomy.BUDGET.mount).toBe(true)
		expect(#rig.pieces > #rigOf(horse()).pieces).toBe(true)
	end)
end)

describe("Mounts: config", function()
	it("matches the DESIGN-15 contract", function()
		local M = Config.Mount
		expect(M.minLevel).toBe(20)
		expect(M.baseMul).toBe(1.6)
		expect(M.maxMul).toBe(2.0)
		expect(M.maxLevel).toBe(10)
		expect(M.mountTime).toBe(1.5)
		expect(M.mountTimeFast).toBe(1.0)
		expect(M.fastFromLevel).toBe(5)
		expect(Quests.Side.STABLE_MIN).toBe(M.minLevel)
	end)
end)

describe("Mounts: speed", function()
	it("rises linearly from x1.6 to x2.0 and never above", function()
		expect(Mounts.speedMul(1)).toBeNear(1.6, 1e-9)
		expect(Mounts.speedMul(10)).toBeNear(2.0, 1e-9)
		expect(Mounts.speedMul(5)).toBeNear(1.7778, 1e-4)
		expect(Mounts.speedMul(nil)).toBeNear(1.6, 1e-9)
		expect(Mounts.speedMul(0)).toBeNear(1.6, 1e-9)
		expect(Mounts.speedMul(14)).toBeNear(2.0, 1e-9)
		for lvl = 2, 10 do
			expect(Mounts.speedMul(lvl) > Mounts.speedMul(lvl - 1)).toBe(true)
		end
		for lvl = 1, 4 do
			expect(Mounts.mountTime(lvl)).toBe(1.5)
		end
		for lvl = 5, 10 do
			expect(Mounts.mountTime(lvl)).toBe(1.0)
		end
	end)

	it("riding ignores buffs and sprint, keeps gear (cap 30) and slows", function()
		local function ride(lvl: number, gear: number, factor: number?, walk: number?, sprint: boolean?): number
			return Mounts.walkSpeed({
				riding = true,
				lvl = lvl,
				walk = walk or 16,
				gearMove = gear,
				sprint = sprint == true,
				factor = factor or 1,
			})
		end
		expect(ride(1, 0, 1, 20.8, true)).toBeNear(25.6, 1e-9)
		expect(ride(1, 30)).toBeNear(33.28, 1e-9)
		expect(ride(1, 45)).toBeNear(33.28, 1e-9)
		expect(ride(10, 0)).toBeNear(32, 1e-9)
		expect(ride(10, 30)).toBeNear(41.6, 1e-9)
		expect(ride(1, 0, 0.5)).toBeNear(12.8, 1e-9)
		expect(ride(1, 0, 0)).toBe(0)
		for _, g in { 0, 10, 20, 30 } do
			local walk = 16 * (1 + g / 100)
			local foot = Mounts.walkSpeed({ riding = false, walk = walk, gearMove = g, sprint = true, factor = 1 })
			expect(ride(1, g) > foot).toBe(true)
		end
		expect(Mounts.walkSpeed({ riding = false, walk = 16, gearMove = 0, sprint = true, factor = 1 })).toBeNear(
			21.6,
			1e-9
		)
		expect(Mounts.walkSpeed({ riding = false, walk = 16, gearMove = 0, sprint = false, factor = 0.7 })).toBeNear(
			11.2,
			1e-9
		)
		expect(Mounts.walkSpeed({ riding = false, walk = 16, gearMove = 0, sprint = true, factor = 0.7 })).toBeNear(
			15.12,
			1e-9
		)
	end)

	it("counts only equipment moveSpeed", function()
		local G = Mounts.GEAR_SOURCE
		expect(Mounts.gearMove({
			{ key = G, value = 12 },
			{ key = "source.effects", value = 30 },
			{ key = "source.passives", value = 9 },
			{ key = G, value = 25 },
		})).toBe(30)
		expect(Mounts.gearMove({ { key = "source.effects", value = 30 } })).toBe(0)
		expect(Mounts.gearMove(nil)).toBe(0)
		expect(Mounts.gearMove({ { key = G, value = 10, pct = true } })).toBe(0)
		local result = StatCalc.compute({
			level = 20,
			stats = { str = 0, dex = 0, int = 0, vit = 0 },
			sources = { { key = "source.gear", flat = { moveSpeed = 10 } } },
		})
		local parts = result.breakdown.moveSpeed
		expect(parts[#parts].key).toBe(G)
		expect(Mounts.gearMove(parts)).toBe(10)
	end)
end)

describe("Mounts: places", function()
	it("rides in the city and on open regions, never in caves, crypts, dungeons or the arena", function()
		for id, map in Maps.byId do
			expect(Mounts.allowedAt(id, nil)).toBe(table.find(MountData.RULES.noBiomes, map.biome) == nil)
		end
		for _, id in { "city", "meadows", "duskwood", "ashen", "frostpeak" } do
			expect(Mounts.allowedAt(id, nil)).toBe(true)
		end
		for _, id in
			{
				"meadows_cave",
				"meadows_hideout",
				"duskwood_barrow",
				"frostpeak_hold",
				"dungeon_meadows",
				"dungeon_frostpeak",
			}
		do
			expect(Mounts.allowedAt(id, nil)).toBe(false)
		end
		expect(Mounts.allowedAt("city", "zone.arena")).toBe(false)
		expect(Mounts.allowedAt("nowhere", nil)).toBe(false)
	end)
end)

describe("Mounts: who may mount", function()
	it("checks death, level, ownership, riding, combat, place and busy in that order", function()
		expect(Mounts.canMount(input({ dead = true, level = 1, inCombat = true }))).toBe("dead")
		expect(Mounts.canMount(input({ level = 19 }))).toBe("level")
		expect(Mounts.canMount(input({ mounts = { owned = {}, riding = false } }))).toBe("none")
		local noState = input()
		noState.mounts = nil
		expect(Mounts.canMount(noState)).toBe("none")
		expect(Mounts.canMount(input({
			mounts = { owned = { mount_horse = { lvl = 1 } }, active = "mount_horse", riding = true },
		}))).toBe("riding")
		expect(Mounts.canMount(input({ inCombat = true }))).toBe("combat")
		expect(Mounts.canMount(input({ mapId = "meadows_cave" }))).toBe("place")
		expect(Mounts.canMount(input({ mapId = "city", zoneKey = "zone.arena" }))).toBe("place")
		expect(Mounts.canMount(input({ busy = true }))).toBe("busy")
		expect(Mounts.canMount(input())).toBe(nil)
	end)

	it("falls back to the first owned mount and clamps its level", function()
		local id, lvl =
			Mounts.activeOf({ owned = { mount_horse = { lvl = 0 } }, active = "mount_gone", riding = false })
		expect(id).toBe("mount_horse")
		expect(lvl).toBe(1)
		local _, high =
			Mounts.activeOf({ owned = { mount_horse = { lvl = 99 } }, active = "mount_horse", riding = false })
		expect(high).toBe(Config.Mount.maxLevel)
		local none, zero = Mounts.activeOf(nil)
		expect(none).toBe(nil)
		expect(zero).toBe(0)
	end)
end)

describe("Mounts: grant", function()
	it("adds a mount once at its start level and keeps the level on a second grant", function()
		local state: Mounts.MountState = { owned = {}, active = nil, riding = false }
		expect(Mounts.grant(state, "mount_horse")).toBe(true)
		expect(state.owned.mount_horse.lvl).toBe(1)
		expect(state.active).toBe("mount_horse")
		state.owned.mount_horse.lvl = 4
		expect(Mounts.grant(state, "mount_horse")).toBe(false)
		expect(state.owned.mount_horse.lvl).toBe(4)
		expect(Mounts.grant(state, "mount_unknown")).toBe(false)
		local other: Mounts.MountState = { owned = { mount_old = { lvl = 2 } }, active = "mount_old", riding = false }
		expect(Mounts.grant(other, "mount_horse")).toBe(true)
		expect(other.active).toBe("mount_old")
	end)
end)

describe("Mounts: seat, rider pose and save", function()
	it("puts the rider above the saddle and the hooves on the ground", function()
		local rig = rigOf(horse())
		local seat = Mounts.seat(rig, 1)
		expect(seat.hipHeight > 2 and seat.hipHeight < 6).toBe(true)
		expect(seat.offset[2] < 0).toBe(true)
		local h0 = rig.hipHeight + rig.root.size[2] / 2
		local hr = seat.hipHeight + 1
		local saddle = h0 + rig.sockets.Saddle.pos[2]
		expect(hr - saddle >= MountData.RIDER.seatLift - 1e-9).toBe(true)
		-- the LookRoot centre is h0 above the ground: rider root + offset
		expect(hr + seat.offset[2]).toBeNear(h0, 1e-9)
	end)

	it("poses the legs astride and lifts the body only while moving", function()
		for _, c in { 0, 0.7, 2.1, 4.4 } do
			local still = RiderPose.sample(c, 0)
			expect(still.root[4]).toBe(0)
			local moving = RiderPose.sample(c, 1)
			expect(math.abs(moving.root[4]) <= MountData.RIDER.bob + 1e-9).toBe(true)
			local keys: { string } = {}
			for key, values in moving do
				table.insert(keys, key)
				for _, n in values do
					expect(finite(n)).toBe(true)
				end
			end
			table.sort(keys)
			local expected = table.clone(RiderPose.JOINTS) :: { string }
			table.sort(expected)
			expect(keys).toEqual(expected)
		end
	end)

	it("adds mounts through the template and reconcile, without a new schema", function()
		expect(AccountSchema.CURRENT).toBe(SCHEMA_BEFORE_S96)
		local template = AccountSchema.characterTemplate().mounts
		expect(template).toEqual({ owned = {}, riding = false })
		local data: any = {
			schema = AccountSchema.CURRENT,
			characters = { ["1"] = { id = "a", name = "Old", level = 30 } },
		}
		AccountSchema.migrate(data)
		expect(data.characters["1"].mounts.owned).toEqual({})
		expect(data.characters["1"].mounts.riding).toBe(false)
	end)
end)

return nil
