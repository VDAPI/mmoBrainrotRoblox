--!strict
-- S96: mounts 1 (docs/DESIGN-15.md §2): data (Data/Mounts, Config.Mount), the horse look (Logic/Anatomy plan "horse"),
-- riding speed, places, who may mount, granting, the seat, the rider pose and the save template. S97: the upgrade
-- curve, canUpgrade, boss and premium mounts, the boss roll, skins over the look and the quest skins.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Anatomy = require("../src/shared/Logic/Anatomy")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local LootTables = require("../src/shared/Data/LootTables")
local Maps = require("../src/shared/Data/Maps")
local MountData = require("../src/shared/Data/Mounts")
local Mounts = require("../src/shared/Logic/Mounts")
local Products = require("../src/shared/Data/Products")
local Quests = require("../src/shared/Data/Quests")
local RiderPose = require("../src/shared/Logic/RiderPose")
local Rng = require("../src/shared/Logic/Rng")
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
		expect(h.wiki).toBe(nil) -- S97: on the wiki
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
		-- S96 added no schema; the next ones are S99 (7, hunting contracts), S102 (8, story progress), S132 (9, class
		-- outfits), S134g (10, item effects), S134k (11, hunting contracts)
		expect(AccountSchema.CURRENT).toBe(SCHEMA_BEFORE_S96 + 5)
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

-- S97: mounts 2 ------------------------------------------------------------------------------------------------------

local function upgradeCharacter(level: number, gold: number, lvl: number?): Mounts.UpgradeCharacter
	return {
		level = level,
		gold = gold,
		mounts = { owned = { mount_horse = { lvl = lvl or 1 } }, active = "mount_horse", riding = false },
	}
end

local function stepInv(step: MountData.UpgradeStep): { [string]: number }
	local inv: { [string]: number } = {}
	for _, m in step.materials do
		inv[m.id] = (inv[m.id] or 0) + m.n
	end
	return inv
end

describe("S97 upgrade curve", function()
	it("has steps 2..maxLevel with rising levels and gold and monster parts only", function()
		local M = Config.Mount
		local keys = 0
		for k in MountData.UPGRADE do
			keys += 1
			expect(k >= 2 and k <= M.maxLevel and k == math.floor(k)).toBe(true)
		end
		expect(keys).toBe(M.maxLevel - 1)
		expect(MountData.UPGRADE[2].level).toBe(M.minLevel)
		expect(MountData.UPGRADE[M.maxLevel].level <= 95).toBe(true)
		local lastLevel, lastGold = 0, 0
		for n = 2, M.maxLevel do
			local step = MountData.UPGRADE[n]
			expect(step.level >= lastLevel).toBe(true)
			expect(step.gold > lastGold and step.gold > 0).toBe(true)
			lastLevel, lastGold = step.level, step.gold
			expect(#step.materials > 0).toBe(true)
			for _, m in step.materials do
				local item = Items.get(m.id)
				expect(item ~= nil and item.category == "material").toBe(true)
				expect(m.n > 0).toBe(true)
				expect(string.find(m.id, "^essence_") == nil and m.id ~= "legend_core").toBe(true)
				expect(string.find(m.id, "^scroll_") == nil).toBe(true)
			end
			expect(Mounts.upgradeCost(n)).toBe(step)
		end
		expect(Mounts.upgradeCost(1)).toBe(nil)
		expect(Mounts.upgradeCost(M.maxLevel + 1)).toBe(nil)
	end)

	it("speeds depend on the mount level only (no pay2win) and mounting gets faster at fastFromLevel", function()
		local M = Config.Mount
		expect(Mounts.mountTime(M.fastFromLevel - 1)).toBe(M.mountTime)
		expect(Mounts.mountTime(M.fastFromLevel)).toBe(M.mountTimeFast)
		expect(Mounts.speedMul(M.maxLevel)).toBeNear(M.maxMul, 1e-9)
		for lvl = 1, M.maxLevel do
			local speeds: { [number]: boolean } = {}
			for _, def in MountData.list do
				if def.startLevel <= lvl then
					-- the same rule for every mount: only the level enters the formula
					local speed = Mounts.walkSpeed({
						riding = true,
						lvl = lvl,
						walk = 16,
						gearMove = 0,
						sprint = false,
						factor = 1,
					})
					expect(speed <= 16 * M.maxMul + 1e-9).toBe(true)
					speeds[math.floor(speed * 1000 + 0.5)] = true
				end
			end
			local n = 0
			for _ in speeds do
				n += 1
			end
			expect(n).toBe(1)
		end
		-- DESIGN-15 §2: gear moveSpeed counts in the saddle, sprint does not, slows do
		local base: Mounts.SpeedInput = { riding = true, lvl = 1, walk = 16, gearMove = 30, sprint = false, factor = 1 }
		expect(Mounts.walkSpeed(base)).toBeNear(33.28, 1e-9)
		local sprinting = table.clone(base)
		sprinting.sprint = true
		expect(Mounts.walkSpeed(sprinting)).toBeNear(33.28, 1e-9)
		local slowed = table.clone(base)
		slowed.factor = 0.5
		expect(Mounts.walkSpeed(slowed)).toBeNear(16.64, 1e-9)
	end)
end)

describe("S97 canUpgrade", function()
	local step2 = MountData.UPGRADE[2]
	local step3 = MountData.UPGRADE[3]

	it("upgrades a horse with enough level, gold and parts", function()
		local ok, err, step = Mounts.canUpgrade(upgradeCharacter(25, 50000), "mount_horse", stepInv(step2))
		expect(ok).toBe(true)
		expect(err).toBe(nil)
		expect(step).toBe(step2)
	end)

	it("reports the reasons in order", function()
		local inv = stepInv(step2)
		local function reason(c: Mounts.UpgradeCharacter, id: string, have: { [string]: number }): string?
			local _, err = Mounts.canUpgrade(c, id, have)
			return err
		end
		expect(reason(upgradeCharacter(25, 50000), "mount_grimrok", inv)).toBe("mount.error.notOwned")
		expect(reason(upgradeCharacter(99, 1e9, Config.Mount.maxLevel), "mount_horse", inv)).toBe(
			"mount.error.maxLevel"
		)
		expect(reason(upgradeCharacter(24, 50000, 2), "mount_horse", stepInv(step3))).toBe("mount.error.upgradeLevel")
		expect(reason(upgradeCharacter(25, step2.gold - 1), "mount_horse", inv)).toBe("mount.error.gold")
		local short = table.clone(inv)
		local first = step2.materials[1]
		short[first.id] = first.n - 1
		expect(reason(upgradeCharacter(25, 50000), "mount_horse", short)).toBe("mount.error.materials")
		-- a low level and too little gold: the level first
		expect(reason(upgradeCharacter(24, 0, 2), "mount_horse", {})).toBe("mount.error.upgradeLevel")
		local noState: Mounts.UpgradeCharacter = { level = 50, gold = 1e9, mounts = nil }
		expect(reason(noState, "mount_horse", inv)).toBe("mount.error.notOwned")
	end)
end)

describe("S97 boss and premium mounts", function()
	local START: { [string]: number } = { grimrok = 3, morvane = 4, azgor = 5, vaelgrath = 6 }

	it("gives every region boss one mount with its start level", function()
		local maxBoss = 0
		for _, bossId in LootTables.regionBoss do
			local found: { MountData.MountDef } = {}
			for _, def in MountData.list do
				if def.source == "boss" and def.boss == bossId then
					table.insert(found, def)
				end
			end
			expect(#found).toBe(1)
			expect(found[1].startLevel).toBe(START[bossId])
			expect(Mounts.bossMountOf(bossId)).toBe(found[1].id)
			expect(hasKey(`mount.{found[1].id}.desc`)).toBe(true)
			maxBoss = math.max(maxBoss, found[1].startLevel)
		end
		for _, def in MountData.list do
			if def.source == "premium" then
				expect(def.startLevel <= maxBoss).toBe(true)
				expect(def.product ~= nil and Products.getMount(def.product :: string) ~= nil).toBe(true)
				expect(def.wiki).toBe(false)
			end
		end
		for _, entry in Products.mounts do
			-- turning one on is the owner's decision and a change of this test
			expect(entry.enabled).toBe(false)
			expect(MountData.get(entry.mount) ~= nil).toBe(true)
		end
	end)

	it("drops boss mounts and skins at flat, rare chances", function()
		local last = math.huge
		for _, bossId in LootTables.regionBoss do
			local drop = MountData.BOSS_DROPS[bossId]
			expect(drop ~= nil).toBe(true)
			local mount = MountData.get(drop.mount :: string)
			expect(mount ~= nil and mount.source == "boss" and mount.boss == bossId).toBe(true)
			local chance = drop.mountChance :: number
			expect(chance >= 0.005 and chance <= 0.03).toBe(true)
			expect(chance <= last).toBe(true)
			last = chance
			local kills = Mounts.expectedKills(chance)
			expect(kills >= 30 and kills <= 200).toBe(true)
			if drop.skin then
				local skin = Cosmetics.get(drop.skin)
				expect(skin ~= nil and skin.kind == "mountskin").toBe(true)
				local obtain = skin and skin.obtain
				expect(obtain and obtain.boss).toBe(bossId)
			end
		end
		for _, def in Cosmetics.list do
			local obtain = def.obtain
			if obtain and obtain.boss then
				local drop = MountData.BOSS_DROPS[obtain.boss]
				expect(drop ~= nil and drop.skin == def.id).toBe(true)
			end
		end
	end)
end)

describe("S97 rollBossDrop", function()
	it("rolls the mount and the skin at their chances", function()
		local N = 200000
		local rng = Rng.new(97)
		local mounts, skins = 0, 0
		for _ = 1, N do
			local r = Mounts.rollBossDrop("grimrok", {}, {}, rng)
			mounts += if r.mount then 1 else 0
			skins += if r.skin then 1 else 0
		end
		local grimrok = MountData.BOSS_DROPS.grimrok
		local mountChance = grimrok.mountChance :: number
		expect(mounts / N).toBeNear(mountChance, mountChance * 0.1)
		expect(skins).toBe(0)
		local morvane = MountData.BOSS_DROPS.morvane
		local skinChance = morvane.skinChance :: number
		skins = 0
		for _ = 1, N do
			skins += if Mounts.rollBossDrop("morvane", {}, {}, rng).skin then 1 else 0
		end
		expect(skins / N).toBeNear(skinChance, skinChance * 0.1)
	end)

	it("skips owned drops and unknown bosses without touching the rng", function()
		local morvane = MountData.BOSS_DROPS.morvane
		local rng = Rng.new(5)
		local copy = Rng.new(5)
		local owned: { [string]: any } = { [morvane.mount :: string] = { lvl = 4 } }
		local skins: { [string]: boolean } = { [morvane.skin :: string] = true }
		expect(Mounts.rollBossDrop("morvane", owned, skins, rng)).toEqual({})
		expect(Mounts.rollBossDrop("nobody", {}, {}, rng)).toEqual({})
		expect(rng:next()).toBe(copy:next())
		-- the same seed, the same sequence
		local a, b = Rng.new(11), Rng.new(11)
		for _ = 1, 500 do
			expect(Mounts.rollBossDrop("azgor", {}, {}, a)).toEqual(Mounts.rollBossDrop("azgor", {}, {}, b))
		end
	end)
end)

describe("S97 lookWith", function()
	it("puts a skin over a mount without touching the data", function()
		local def = assert(MountData.get("mount_azgor"))
		local skin = assert(Cosmetics.get("mountskin_meadow"))
		local before = table.clone(def.look.colors)
		local out = Mounts.lookWith(def.look, skin)
		local over = skin.skin :: Cosmetics.Skin
		for role, color in over.colors :: { [string]: string } do
			expect(out.colors[role]).toBe(color)
		end
		local seen: { [string]: number } = {}
		for _, part in out.parts do
			seen[part] = (seen[part] or 0) + 1
		end
		for _, part in def.look.parts :: { string } do
			expect(seen[part]).toBe(1)
		end
		for _, part in over.parts :: { string } do
			expect(seen[part]).toBe(1)
		end
		expect(table.isfrozen(def)).toBe(true)
		expect(def.look.colors).toEqual(before)
		local cinder = assert(Cosmetics.get("mountskin_cinder"))
		expect(Mounts.lookWith(def.look, cinder).glow).toBe((cinder.skin :: Cosmetics.Skin).glow)
		-- nil and another kind: an unchanged copy
		expect(Mounts.lookWith(def.look, nil).colors).toEqual(def.look.colors)
		expect(Mounts.lookWith(def.look, Cosmetics.get("outfit_ranger")).parts).toEqual(def.look.parts)
	end)

	it("builds every mount with every skin within the budget, with a saddle", function()
		local skins: { Cosmetics.Def } = {}
		for _, c in Cosmetics.list do
			if c.kind == "mountskin" then
				table.insert(skins, c)
			end
		end
		expect(#skins >= 8).toBe(true)
		for _, def in MountData.list do
			for i = 0, #skins do
				local skin = if i == 0 then nil else skins[i]
				local rig = Anatomy.build(
					Mounts.lookWith(def.look, skin),
					{ id = def.id, variant = "mount", scale = def.scale or 1 }
				)
				expect(#rig.pieces <= Anatomy.BUDGET.mount).toBe(true)
				expect(rig.sockets.Saddle ~= nil).toBe(true)
			end
		end
	end)
end)

describe("S97 quest skins", function()
	local function questOf(id: string): any
		-- S134k: the last hunting contract gives a title (Reward.cosmetic)
		return Quests.Main.get(id) or Quests.Side.get(id) or Quests.Contracts.get(id)
	end

	it("ties quest skins and Reward.cosmetic both ways, without touching EXP and gold", function()
		for _, c in Cosmetics.list do
			local obtain = c.obtain
			-- S132: class outfits of a quest are given by CosmeticService.GrantQuestOutfits, not Reward.cosmetic
			if obtain and obtain.quest and c.class == nil then
				local quest = questOf(obtain.quest)
				expect(quest ~= nil).toBe(true)
				expect(quest.reward.cosmetic).toBe(c.id)
				expect(c.price).toBe(0)
			end
		end
		local lists: { { any } } = { Quests.Main.list :: any, Quests.Side.list :: any, Quests.Contracts.list :: any } -- S134k
		for _, list in lists do
			for _, quest in list do
				local id = quest.reward.cosmetic
				if id then
					local c = Cosmetics.get(id)
					local obtain = c and c.obtain
					expect(obtain ~= nil and obtain.quest == quest.id).toBe(true)
				end
			end
		end
		local ride = questOf("side_stable_ride")
		expect(ride.reward.exp).toBe(math.floor(Exp.expToNext(22) * 0.1))
		expect(ride.reward.gold).toBe(math.floor((60 + 22 * 45) * 0.5))
		local vaelgrath = questOf("vaelgrath")
		expect(vaelgrath.reward.exp).toBe(math.floor(Exp.expToNext(99) * 1.5))
		expect(vaelgrath.reward.gold).toBe((60 + 100 * 45) * 5)
	end)
end)

return nil
