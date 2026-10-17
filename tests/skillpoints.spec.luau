--!strict
-- Skill points (S137, DESIGN-18 §3, §9, §10): Logic/SkillPoints, the rank rule of Logic/Paths, migration 12 and the
-- build sets with ranks and pool bars.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local Classes = require("../src/shared/Data/Classes")
local Items = require("../src/shared/Data/Items")
local Paths = require("../src/shared/Logic/Paths")
local PathView = require("../src/shared/Logic/PathView")
local PoolData = require("../src/shared/Data/SkillPools")
local Progression = require("../src/shared/Data/Progression")
local SkillData = require("../src/shared/Data/Skills")
local SkillPoints = require("../src/shared/Logic/SkillPoints")
local SkillPools = require("../src/shared/Logic/SkillPools")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")

local function itemOf(itemType: string): string
	local best: string? = nil
	for id, def in Items.byId do
		if def.type == itemType and (best == nil or id < best) then
			best = id
		end
	end
	assert(best, `no item of type {itemType}`)
	return best
end

local function char(classId: string, level: number, extra: { [string]: any }?): any
	local c: { [string]: any } = {
		class = classId,
		level = level,
		path = { nodes = {}, bp = {} },
		hotbar = {},
		equipment = {},
		ranks = {},
		bars = {},
		barPool = SkillPools.defaultPool(classId),
		respecFree = false,
		poolsVersion = SkillPools.version(classId),
	}
	for key, value in extra or {} do
		c[key] = value
	end
	return c
end

local function sum(ranks: { [string]: number }?): number
	local total = 0
	for _, n in ranks or {} do
		total += n
	end
	return total
end

local PLACE = {
	field = { inCombat = false, inTown = false, nearGate = false },
	combat = { inCombat = true, inTown = true, nearGate = false },
	town = { inCombat = false, inTown = true, nearGate = false },
	gate = { inCombat = false, inTown = false, nearGate = true },
}

T.describe("Skill points: points, limits and buying (S137)", function()
	T.it("pointsAt = level x perLevel + bonus, the same for every pool; cap = Skills.rankAt", function()
		local rule = Progression.skillPoints :: any
		for _, L in { 1, 10, 20, 100 } do
			T.expect(SkillPoints.pointsAt(L)).toBe(L * rule.perLevel + (rule.bonus or 0))
		end
		T.expect(SkillPoints.pointsAt(20) - SkillPoints.pointsAt(19)).toBe(rule.perLevel)
		for _, id in { "firebolt", "meteor", "steelSkin", "elementalVortex" } do
			local skill = SkillData.get(id) :: any
			for _, L in { 1, 20, 45, 100 } do
				T.expect(SkillPoints.cap(skill, L)).toBe(Skills.rankAt(skill, L))
			end
		end
	end)

	T.it("rank = the bought rank in the pool, at most the limit; another pool or none = 0", function()
		local c = char("Mage", 20, { ranks = { fire = { firebolt = 4, fireball = 99 }, ice = { iceShard = 2 } } })
		T.expect(SkillPoints.rank(c, "firebolt")).toBe(4)
		T.expect(SkillPoints.rank(c, "fireball")).toBe(Skills.rankAt(SkillData.get("fireball") :: any, 20))
		T.expect(SkillPoints.rank(c, "iceShard")).toBe(0) -- not of the fire pool
		T.expect(SkillPoints.rank(c, "iceShard", "ice")).toBe(2)
		T.expect(SkillPoints.rank(c, "firebolt", "ice")).toBe(0) -- common skills are bought per pool
		c.equipment = { weapon = { id = itemOf("wand"), el = "ice" } }
		T.expect(SkillPoints.rank(c, "iceShard")).toBe(2) -- the ice wand selects the ice pool
		T.expect(SkillPoints.rank(c, "firebolt")).toBe(0)
		T.expect(SkillPoints.spent(c, "fire")).toBe(103)
		T.expect(SkillPoints.free(c, "ice")).toBe(SkillPoints.pointsAt(20) - 2)
		T.expect(SkillPoints.rank(char("Warrior", 20, { ranks = { onehand = { firebolt = 3 } } }), "firebolt")).toBe(0)
	end)

	T.it("canBuy: points, the limit, the pool, a path skill's node", function()
		local c = char("Mage", 10)
		T.expect({ SkillPoints.canBuy(c, "fire", "firebolt") }).toEqual({ true })
		local limit = Skills.rankAt(SkillData.get("firebolt") :: any, 10)
		T.expect({ SkillPoints.canBuy(c, "fire", "firebolt", limit) }).toEqual({ true })
		T.expect({ SkillPoints.canBuy(c, "fire", "firebolt", limit + 1) }).toEqual({ false, "skills.error.limit" })
		T.expect({ SkillPoints.canBuy(c, "fire", "meteor") }).toEqual({ false, "skills.error.limit" }) -- unlock 26
		T.expect({ SkillPoints.canBuy(c, "fire", "iceShard") }).toEqual({ false, "skills.error.pool" })
		T.expect({ SkillPoints.canBuy(c, "onehand", "firebolt") }).toEqual({ false, "skills.error.pool" })
		-- S140: Elementalist is a passive node; a direction skill (row 4) needs its node
		local high = char("Mage", 30)
		T.expect({ SkillPoints.canBuy(high, "fire", "elementalVortex") }).toEqual({ false, "skills.error.locked" })
		high.path = { nodes = { destroyer_elementalVortex = 1 }, bp = {} }
		T.expect({ SkillPoints.canBuy(high, "fire", "elementalVortex") }).toEqual({ true })
		T.expect({ SkillPoints.canBuy(c, "fire", "mightyStrike") }).toEqual({ false, "error.badRequest" })
		T.expect({ SkillPoints.canBuy(c, "fire", "firebolt", 0) }).toEqual({ false, "error.badRequest" })
		T.expect({ SkillPoints.canBuy(c, "fire", "firebolt", 1.5) }).toEqual({ false, "error.badRequest" })
		-- every point spent
		local spentAll = char("Warrior", 3, { ranks = { onehand = { mightyStrike = SkillPoints.pointsAt(3) } } })
		T.expect({ SkillPoints.canBuy(spentAll, "onehand", "shieldSweep") }).toEqual({ false, "skills.error.points" })
	end)

	T.it("apply: the whole reservation or nothing; negative, fractional and unknown entries refused", function()
		local c = char("Warrior", 12)
		local before = TableUtil.deepCopy(c.ranks)
		local ok, err, ranks = SkillPoints.apply(c, "onehand", { mightyStrike = 3, charge = 2 })
		T.expect({ ok, err }).toEqual({ true, nil })
		T.expect(ranks).toEqual({ mightyStrike = 3, charge = 2 })
		T.expect(c.ranks).toEqual(before) -- apply never writes the character
		c.ranks.onehand = ranks
		local free = SkillPoints.free(c, "onehand")
		-- one entry over its limit: nothing is bought
		local ok2, err2, ranks2 = SkillPoints.apply(c, "onehand", { taunt = 1, charge = 50 })
		T.expect({ ok2, err2, ranks2 }).toEqual({ false, "skills.error.limit", nil })
		T.expect(SkillPoints.free(c, "onehand")).toBe(free)
		for _, plan in { { charge = -1 }, { charge = 0.5 }, { [1] = 1 }, {}, { charge = "1" } } :: { any } do
			T.expect({ SkillPoints.apply(c, "onehand", plan) }).toEqual({ false, "error.badRequest" })
		end
		T.expect({ SkillPoints.apply(c, "nope", { charge = 1 }) }).toEqual({ false, "skills.error.pool" })
		T.expect({ SkillPoints.apply(c, "onehand", "x") }).toEqual({ false, "error.badRequest" })
		-- more than the free points in total
		local poor = char("Warrior", 4)
		T.expect({ SkillPoints.apply(poor, "onehand", { mightyStrike = 1, charge = 1, shieldBash = 1 }) }).toEqual({
			false,
			"skills.error.limit",
		})
		local tight = char("Warrior", 40, { ranks = { onehand = { mightyStrike = SkillPoints.pointsAt(40) - 1 } } })
		T.expect({ SkillPoints.apply(tight, "onehand", { charge = 1, taunt = 1 }) }).toEqual({
			false,
			"skills.error.points",
		})
	end)

	T.it("canRefund: free below freeRespecLevel out of combat, from it in town or at a gate for gold", function()
		local low = char("Warrior", Progression.freeRespecLevel - 1, { ranks = { onehand = { mightyStrike = 2 } } })
		T.expect({ SkillPoints.canRefund(low, "onehand", "mightyStrike", PLACE.field) }).toEqual({ true, nil, 0 })
		T.expect({ SkillPoints.canRefund(low, "onehand", "mightyStrike", PLACE.combat) }).toEqual({
			false,
			"paths.error.combat",
			0,
		})
		T.expect({ SkillPoints.canRefund(low, "onehand", "charge", PLACE.field) }).toEqual({
			false,
			"skills.error.noRank",
			0,
		})
		local high = char("Warrior", 60, { ranks = { onehand = { mightyStrike = 2 } } })
		T.expect({ SkillPoints.canRefund(high, "onehand", "mightyStrike", PLACE.field) }).toEqual({
			false,
			"paths.error.place",
			0,
		})
		local cost = Progression.rankRefundGold * 60
		T.expect({ SkillPoints.canRefund(high, "onehand", "mightyStrike", PLACE.town) }).toEqual({ true, nil, cost })
		T.expect({ SkillPoints.canRefund(high, "onehand", "mightyStrike", PLACE.gate) }).toEqual({ true, nil, cost })
		T.expect(SkillPoints.refundCost(60, 3)).toBe(3 * cost)
		T.expect(SkillPoints.refundCost(Progression.freeRespecLevel - 1, 3)).toBe(0)
	end)

	T.it("canReset: free below freeRespecLevel or with respecFree, otherwise the scroll (S138)", function()
		T.expect({ SkillPoints.canReset(char("Hunter", 10), PLACE.field) }).toEqual({ true, nil, "level" })
		T.expect({ SkillPoints.canReset(char("Hunter", 10), PLACE.combat, 3) }).toEqual({ false, "paths.error.combat" })
		T.expect({ SkillPoints.canReset(char("Hunter", 50), PLACE.town) }).toEqual({
			false,
			"skills.error.resetNeedsScroll",
		})
		T.expect({ SkillPoints.canReset(char("Hunter", 50), PLACE.town, 0) }).toEqual({
			false,
			"skills.error.resetNeedsScroll",
		})
		-- the scroll pays anywhere out of combat; respecFree comes first, so the scroll is not used up
		T.expect({ SkillPoints.canReset(char("Hunter", 50), PLACE.field, 1) }).toEqual({ true, nil, "scroll" })
		local free = char("Hunter", 50, { respecFree = true })
		T.expect({ SkillPoints.canReset(free, PLACE.field) }).toEqual({ true, nil, "respec" })
		T.expect({ SkillPoints.canReset(free, PLACE.field, 2) }).toEqual({ true, nil, "respec" })
		T.expect({ SkillPoints.canReset(char("Hunter", 10), PLACE.field, 2) }).toEqual({ true, nil, "level" })
	end)

	T.it("the full reset: every pool's ranks and the nodes go, the breakpoint choices stay (S138)", function()
		local bp = { ["mightyStrike:5"] = "b", ["bladeWhirl:10"] = "a" }
		local c = char("Warrior", 60, {
			ranks = { onehand = { mightyStrike = 5 }, twohand = { mightyStrike = 4, bladeWhirl = 2 } },
			path = { nodes = { berserker_scars = 1, guardian_stalwart = 1 }, bp = bp },
		})
		local reset = SkillPoints.resetState(c)
		T.expect(reset).toEqual({ ranks = {}, path = { nodes = {}, bp = bp } })
		T.expect(reset.path.bp ~= c.path.bp).toBe(true) -- a copy
		for _, poolId in SkillPools.ids("Warrior") do
			T.expect(SkillPoints.free(Paths.setView(c, { path = reset.path, ranks = reset.ranks } :: any), poolId))
				.toBe(SkillPoints.pointsAt(60))
		end
	end)

	T.it("a node rank and a skill rank cost the same from freeRespecLevel (S138)", function()
		local L = Progression.freeRespecLevel
		local c =
			char("Warrior", L + 10, { path = { nodes = { berserker_scars = 1, guardian_stalwart = 1 }, bp = {} } })
		T.expect(SkillPoints.nodesRefundCost(c)).toBe(SkillPoints.refundCost(L + 10, 2))
		T.expect(SkillPoints.nodesRefundCost(c)).toBe(2 * Progression.rankRefundGold * (L + 10))
		local young = char("Warrior", L - 1, { path = { nodes = { berserker_scars = 1 }, bp = {} } })
		T.expect(SkillPoints.nodesRefundCost(young)).toBe(0)
		-- a node refund below the level works anywhere out of combat, from it in town or at a gate
		local function edit(level: number, place: any): any
			return {
				Paths.canEdit({
					action = "refund",
					inCombat = place.inCombat,
					inTown = place.inTown,
					nearGate = place.nearGate,
					level = level,
				}),
			}
		end
		T.expect(edit(L - 1, PLACE.field)).toEqual({ true })
		T.expect(edit(L, PLACE.field)).toEqual({ false, "paths.error.place" })
		T.expect(edit(L, PLACE.town)).toEqual({ true })
		T.expect(edit(L - 1, PLACE.combat)).toEqual({ false, "paths.error.combat" })
	end)

	T.it("a node refund also pays for the skill ranks it drops in every pool (S138)", function()
		-- S143: Carnage (the Berserker's capstone) is the Warrior's direction skill of the example
		local c = char("Warrior", 70, {
			path = { nodes = { berserker_carnage = 1, guardian_stalwart = 1 }, bp = {} },
			ranks = { onehand = { carnage = 3, mightyStrike = 2 }, twohand = { carnage = 4 } },
		})
		local kept = 0
		for _, ranks in (Paths.cleanRanks(c)) do
			kept += ranks.carnage or 0
		end
		T.expect(kept > 0).toBe(true)
		T.expect(SkillPoints.droppedRanks(c, { guardian_stalwart = 1 })).toBe(kept)
		T.expect(SkillPoints.nodeRefundCost(c, "berserker_carnage")).toBe(SkillPoints.refundCost(70, 1 + kept))
		T.expect(SkillPoints.nodeRefundCost(c, "guardian_stalwart")).toBe(SkillPoints.refundCost(70, 1))
		T.expect(SkillPoints.nodesRefundCost(c)).toBe(SkillPoints.refundCost(70, 2 + kept))
		local young = char("Warrior", Progression.freeRespecLevel - 1, { path = c.path, ranks = c.ranks })
		T.expect(SkillPoints.nodeRefundCost(young, "berserker_carnage")).toBe(0)
	end)

	T.it("the full reset keeps a path skill's breakpoint choice through validHotbar (S138)", function()
		local c = char("Warrior", 80, { -- S143: Carnage (rank 5 at 76)
			path = { nodes = { berserker_carnage = 1 }, bp = { ["carnage:5"] = "b" } },
			ranks = { onehand = { carnage = 5 } },
		})
		local _, before = Paths.validHotbar(c)
		T.expect(before).toEqual({ ["carnage:5"] = "b" })
		local reset = SkillPoints.resetState(c)
		c.ranks = reset.ranks
		c.path = reset.path
		local _, after = Paths.validHotbar(c)
		T.expect(after).toEqual({ ["carnage:5"] = "b" })
	end)

	T.it("suggest: the pool's order, each skill to its limit, never above the free points", function()
		for _, classId in Classes.order do
			for _, poolId in SkillPools.ids(classId) do
				for _, L in { 1, 9, 20, 45, 100 } do
					local c = char(classId, L)
					local plan = SkillPoints.suggest(c, poolId)
					T.expect(sum(plan) <= SkillPoints.free(c, poolId)).toBe(true)
					local ok, err = SkillPoints.apply(c, poolId, plan)
					T.expect({ classId, poolId, L, ok or next(plan) == nil, err }).toEqual({
						classId,
						poolId,
						L,
						true,
						if next(plan) == nil then "error.badRequest" else nil,
					})
					-- the order: a skill of the plan gets ranks only while every earlier one is at its limit
					local short = false
					for _, id in SkillPoints.order(classId, poolId) do
						local skill = SkillData.get(id) :: any
						if skill.path == nil then
							local got = plan[id] or 0
							if short then
								T.expect({ id, got }).toEqual({ id, 0 })
							elseif got < Skills.rankAt(skill, L) then
								short = true
							end
						end
					end
				end
			end
		end
		local some = char("Mage", 10, { ranks = { fire = { firebolt = 1 } } })
		local plan = SkillPoints.suggest(some, "fire")
		T.expect(plan.firebolt).toBe(Skills.rankAt(SkillData.get("firebolt") :: any, 10) - 1)
	end)
end)

T.describe("Skill points: legacy ranks, cleaning, bars (S137)", function()
	T.it("legacy: the old automatic ranks of the pool, the old bar first, then passives, then the rest", function()
		-- enough points: exactly the old curve of every base member (S141: level 10, the full ice pool needs more than the
		-- points of 20)
		local all = SkillPoints.legacy("Mage", 10, "ice", {}, nil)
		for _, id in SkillPools.members("Mage", "ice") do
			local skill = SkillData.get(id) :: any
			if skill.path == nil then
				local auto = Skills.rankAt(skill, 10)
				T.expect({ id, all[id] }).toEqual({ id, if auto > 0 then auto else nil })
			end
		end
		T.expect(all.fireball).toBeNil()
		-- a cut budget: the bar's skills and the passives keep their old ranks, the rest loses from the end
		local L = 45
		local bar = { ["1"] = "earthquake", ["2"] = "intercept" } -- S143: the one-handed pool
		local ranks = SkillPoints.legacy("Warrior", L, "onehand", bar, nil)
		T.expect(sum(ranks)).toBe(SkillPoints.pointsAt(L))
		for _, id in { "earthquake", "intercept", "steelSkin", "fortitude" } do
			T.expect({ id, ranks[id] }).toEqual({ id, Skills.rankAt(SkillData.get(id) :: any, L) })
		end
		local auto = 0
		for _, skill in SkillData.byClass.Warrior do
			if skill.path == nil then
				auto += Skills.rankAt(skill, L)
			end
		end
		T.expect(auto > SkillPoints.pointsAt(L)).toBe(true) -- the case really cuts
		-- a path skill only with its node (S143: Carnage on the old bar, so it comes before the cut)
		local path = { nodes = { berserker_carnage = 1 }, bp = {} }
		local onBar = { ["1"] = "carnage" }
		T.expect(SkillPoints.legacy("Warrior", 64, "twohand", onBar, path).carnage)
			.toBe(Skills.rankAt(SkillData.get("carnage") :: any, 64))
		T.expect(SkillPoints.legacy("Warrior", 64, "twohand", onBar, nil).carnage).toBeNil()
	end)

	T.it("clean: ranks outside the pool, without a node, above the limit or the points go back", function()
		local c = char("Mage", 20, {
			ranks = {
				fire = { firebolt = 99, iceShard = 3, elementalist = 2, ghost = 4, fireball = 2.7 },
				nope = { firebolt = 1 },
				ice = "broken",
			},
		})
		local ranks, changed = SkillPoints.clean(c)
		T.expect(changed).toBe(true)
		T.expect(ranks).toEqual({
			fire = { firebolt = Skills.rankAt(SkillData.get("firebolt") :: any, 20), fireball = 2 },
		})
		c.ranks = ranks
		local again, changedAgain = SkillPoints.clean(c)
		T.expect(changedAgain).toBe(false)
		T.expect(again).toEqual(ranks)
		-- above the points: from the end of the pool's order
		local over = char("Warrior", 20, { ranks = {} })
		local own: { [string]: number } = {}
		for _, skill in SkillData.byClass.Warrior do
			if skill.path == nil then
				own[skill.id] = Skills.rankAt(skill, 30)
			end
		end
		over.ranks.onehand = own
		local trimmed = SkillPoints.clean(over)
		T.expect(sum(trimmed.onehand) <= SkillPoints.pointsAt(20)).toBe(true)
		T.expect(trimmed.onehand.mightyStrike).toBe(Skills.rankAt(SkillData.get("mightyStrike") :: any, 20))
		T.expect(SkillPoints.needsRespec(over)).toBe(false)
		over.poolsVersion = 0
		T.expect(SkillPoints.needsRespec(over)).toBe(true)
	end)

	T.it("startBar, barOf and switchPool: each pool keeps its own 8-slot bar", function()
		local c = char("Mage", 40, {
			ranks = {
				fire = { firebolt = 5, fireball = 5, meteor = 2 },
				ice = { iceShard = 4, frostNova = 3 },
			},
			barPool = "fire",
			hotbar = { ["1"] = "meteor" },
			bars = {},
		})
		T.expect(SkillPoints.startBar(c, "fire")).toEqual({ ["1"] = "firebolt", ["2"] = "fireball", ["3"] = "meteor" })
		T.expect(SkillPoints.startBar(c, "ice")).toEqual({ ["1"] = "iceShard", ["2"] = "frostNova" })
		T.expect(SkillPoints.barOf(c, "fire")).toEqual({ ["1"] = "meteor" })
		T.expect(SkillPoints.barOf(c, "ice")).toEqual({})
		T.expect(SkillPoints.switchPool(c, "fire")).toBeNil()
		local toIce = SkillPoints.switchPool(c, "ice") :: any
		T.expect(toIce.barPool).toBe("ice")
		T.expect(toIce.hotbar).toEqual({ ["1"] = "iceShard", ["2"] = "frostNova" }) -- never had a bar: startBar
		T.expect(toIce.bars).toEqual({ fire = { ["1"] = "meteor" } })
		c.hotbar, c.bars, c.barPool = toIce.hotbar, toIce.bars, toIce.barPool
		c.hotbar = { ["3"] = "frostNova" }
		local back = SkillPoints.switchPool(c, "fire") :: any
		T.expect(back.hotbar).toEqual({ ["1"] = "meteor" })
		T.expect(back.bars).toEqual({ ice = { ["3"] = "frostNova" } })
		-- a template barPool (""): the hotbar becomes the pool's bar
		local fresh = char("Mage", 40, { ranks = c.ranks, barPool = "", hotbar = { ["2"] = "firebolt" } })
		T.expect((SkillPoints.switchPool(fresh, "fire") :: any).hotbar).toEqual({ ["2"] = "firebolt" })
		T.expect(SkillData.HOTBAR_SLOTS).toBe(8)
	end)

	T.it("the rank rule in Paths: a skill of another pool is refused with wrongPool, the bar keeps its pool", function()
		local c = char("Mage", 30, {
			ranks = { fire = { firebolt = 3, fireball = 3 }, lightning = { chainLightning = 3 } },
			equipment = { weapon = { id = itemOf("staff"), el = "lightning" } },
			barPool = "lightning",
			hotbar = { ["1"] = "chainLightning", ["2"] = "fireball", ["3"] = "firebolt" },
		})
		local weapons = Paths.weaponTypesOf(c.equipment)
		T.expect({ Paths.skillUsable(c, "fireball", weapons) }).toEqual({ false, "cast.error.wrongPool" })
		T.expect({ Paths.skillUsable(c, "chainLightning", weapons) }).toEqual({ true, nil })
		-- S142: Fire Bolt is the fire pool's S1 (it was common and adaptive: notLearned in the lightning pool)
		T.expect({ Paths.skillUsable(c, "firebolt", weapons) }).toEqual({ false, "cast.error.wrongPool" })
		local bar = Paths.validHotbar(c)
		T.expect(bar).toEqual({ ["1"] = "chainLightning" })
		T.expect((Paths.canPutOnBar(c, "fireball", "fire"))).toBe(true)
		T.expect((Paths.canPutOnBar(c, "fireball"))).toBe(false)
	end)

	T.it("the attention badge shows a free skill point with a rank to buy in the active pool", function()
		local c = char("Warrior", 3)
		T.expect(PathView.attention(c).skills).toBe(true)
		T.expect(PathView.attention(c).any).toBe(true)
		c.ranks = { onehand = { mightyStrike = 1, shieldSweep = 1 } } -- S143: the one-handed A1 at 3
		local limited = PathView.attention(c)
		T.expect(limited.skills).toBe(false) -- free points, but every limit reached
		c.ranks = { onehand = { mightyStrike = SkillPoints.pointsAt(3) } }
		T.expect(PathView.attention(c).skills).toBe(false)
	end)
end)

T.describe("Skill points: save (S137, migration 12)", function()
	local function oldAccount(classId: string, level: number, weapon: any?): any
		local hotbar = Skills.startHotbar(classId, level)
		hotbar["9"] = hotbar["9"] or hotbar["1"]
		return {
			schema = 11,
			characters = {
				["1"] = {
					id = "c1",
					name = "Old",
					class = classId,
					level = level,
					hotbar = hotbar,
					path = { nodes = {}, bp = {} },
					equipment = if weapon then { weapon = weapon } else {},
					buildOther = {
						path = { nodes = {}, bp = {} },
						stats = { str = 0, dex = 0, int = 0, vit = 0 },
						statPoints = 0,
						hotbar = { ["1"] = hotbar["1"] },
					},
				},
			},
		}
	end

	T.it(
		"every class at 1, 20, 60 and 100: ranks within the points, the bar of the weapon's pool, both sets",
		function()
			for _, classId in Classes.order do
				for _, L in { 1, 20, 60, 100 } do
					local data = oldAccount(classId, L)
					T.expect(AccountSchema.migrate(data)).toEqual({ 12 })
					local c = data.characters["1"]
					T.expect(c.reworkNotice).toBe(true)
					for _, set in { c, c.buildOther } do
						T.expect({ classId, L, set.respecFree, set.poolsVersion }).toEqual({
							classId,
							L,
							true,
							SkillPools.version(classId),
						})
						T.expect(set.barPool).toBe(SkillPools.defaultPool(classId))
						for poolId, own in set.ranks do
							T.expect({ classId, L, poolId, sum(own) <= SkillPoints.pointsAt(L) }).toEqual({
								classId,
								L,
								poolId,
								true,
							})
						end
						local count = 0
						for slot, id in set.hotbar do
							count += 1
							local n = tonumber(slot) :: number
							T.expect(n >= 1 and n <= SkillData.HOTBAR_SLOTS).toBe(true)
							local view = Paths.setView(c, set)
							T.expect({ classId, L, id, Paths.skillRank(view, id) > 0 })
								.toEqual({ classId, L, id, true })
						end
						T.expect(count <= SkillData.HOTBAR_SLOTS).toBe(true)
						for poolId, bar in set.bars do
							T.expect(poolId ~= set.barPool).toBe(true)
							for _, id in bar do
								T.expect(Paths.skillRank(Paths.setView(c, set), id, poolId) > 0).toBe(true)
							end
						end
					end
					-- the first skill keeps rank 1 and its slot at level 1
					if L == 1 then
						local first = Skills.startingSkill(classId) :: string
						T.expect(c.hotbar["1"]).toBe(first)
						T.expect(c.ranks[SkillPools.defaultPool(classId) :: string][first]).toBe(1)
					end
					-- idempotent
					local before = TableUtil.deepCopy(data)
					data.schema = 11
					T.expect(AccountSchema.migrate(data)).toEqual({ 12 })
					T.expect(data).toEqual(before)
				end
			end
		end
	)

	T.it("a Mage with an ice wand: the ice pool, no fire spell on the bar, fire ranks kept in their pool", function()
		local data = oldAccount("Mage", 40, { id = itemOf("wand"), el = "ice" })
		data.characters["1"].hotbar = {
			["1"] = "fireball",
			["2"] = "iceShard",
			["3"] = "meteor",
			["4"] = "firebolt",
			["5"] = "frostNova",
		}
		AccountSchema.migrate(data)
		local c = data.characters["1"]
		T.expect(c.barPool).toBe("ice")
		-- S140: the free slots of the ice bar fill in the plan's order (startBar). S141: the full ice pool spends the
		-- legacy points on Hailstorm and Blink first (the old bar, the passives, then the plan; 47 points at 40). S142:
		-- Fire Bolt is fire only, Ice Barrier takes its slot
		T.expect(c.hotbar).toEqual({
			["2"] = "iceShard",
			["5"] = "frostNova",
			["1"] = "hailstorm",
			["3"] = "blink",
			["4"] = "iceBarrier",
		})
		for _, id in c.hotbar do
			T.expect({ id, (SkillData.get(id) :: any).element ~= "fire" }).toEqual({ id, true })
		end
		T.expect(c.ranks.fire.fireball).toBe(Skills.rankAt(SkillData.get("fireball") :: any, 40))
		T.expect(c.ranks.ice.fireball).toBeNil()
		T.expect(c.bars.fire["1"]).toBe("firebolt")
		T.expect(c.bars.lightning ~= nil).toBe(true)
		T.expect(c.bars.ice).toBeNil()
	end)

	T.it("a schema 1 save: migration 2's reconcile does not mark the sets as migrated", function()
		local data = oldAccount("Warrior", 30)
		data.schema = 1
		AccountSchema.migrate(data)
		local c = data.characters["1"]
		T.expect(c.reworkNotice).toBe(true)
		T.expect({ c.respecFree, c.poolsVersion, c.barPool }).toEqual({
			true,
			SkillPools.version("Warrior"),
			SkillPools.defaultPool("Warrior"),
		})
		T.expect(sum(c.ranks[SkillPools.defaultPool("Warrior") :: string]) > 0).toBe(true)
		local view = Paths.setView(c, c)
		local count = 0
		for _, id in c.hotbar do
			count += 1
			T.expect({ id, Paths.skillRank(view, id) > 0 }).toEqual({ id, true })
		end
		T.expect(count > 0).toBe(true)
	end)

	T.it(
		"a new character: rank 1 of the first skill in the default pool, on slot 1; the template has the fields",
		function()
			for _, classId in Classes.order do
				local n = 0
				local c = CharacterFactory.create(classId :: any, "Tester", {
					newId = function(): string
						n += 1
						return `id{n}`
					end,
					now = 0,
				})
				local first = Skills.startingSkill(classId) :: string
				local pool = SkillPools.defaultPool(classId) :: string
				T.expect(c.ranks).toEqual({ [pool] = { [first] = 1 } })
				T.expect(c.hotbar).toEqual({ ["1"] = first })
				T.expect({ c.barPool, c.respecFree, c.poolsVersion })
					.toEqual({ pool, false, SkillPools.version(classId) })
				-- the starting weapon selects the default pool
				T.expect(SkillPools.activePool(c)).toBe(pool)
				T.expect(Paths.skillRank(c, first)).toBe(1)
				T.expect(SkillPoints.free(c, pool)).toBe(SkillPoints.pointsAt(1) - 1)
			end
			local template = AccountSchema.characterTemplate()
			T.expect({ template.ranks, template.bars, template.barPool, template.respecFree, template.poolsVersion })
				.toEqual({ {}, {}, "", false, 0 })
			T.expect(AccountSchema.CURRENT).toBe(12)
		end
	)

	T.it("build sets carry the ranks, the pool bars, barPool and the free reset", function()
		local c = char("Mage", 50, {
			ranks = { fire = { firebolt = 5 }, ice = { iceShard = 3 } },
			bars = { ice = { ["1"] = "iceShard" } },
			barPool = "fire",
			hotbar = { ["1"] = "firebolt" },
			respecFree = true,
			stats = { str = 3, dex = 5, int = 10, vit = 8 },
			statPoints = 0,
			buildSlot = 1,
		})
		local copy = Paths.copySet(c)
		T.expect(copy.ranks).toEqual(c.ranks)
		T.expect(copy.ranks ~= c.ranks).toBe(true)
		T.expect(copy.bars).toEqual(c.bars)
		T.expect(copy.barPool).toBe("fire")
		T.expect(copy.respecFree).toBe(false) -- a copy never gives the target a free reset
		local swap = Paths.swapSets(c)
		T.expect(swap.active.ranks).toEqual({})
		T.expect(swap.active.hotbar).toEqual({})
		T.expect(swap.other.ranks).toEqual(c.ranks)
		T.expect(swap.other.bars).toEqual(c.bars)
		T.expect(swap.other.respecFree).toBe(true)
		-- cleanSet at a lower level: ranks within the limits and points, bars of ranked skills only
		local cleaned = Paths.cleanSet(c, swap.other, 5)
		T.expect(cleaned.ranks.fire.firebolt).toBe(Skills.rankAt(SkillData.get("firebolt") :: any, 5))
		-- S141: Ice Shard unlocks at 1, so it keeps the rank of level 5 and its slot
		T.expect(cleaned.ranks.ice).toEqual({ iceShard = Skills.rankAt(SkillData.get("iceShard") :: any, 5) })
		T.expect(cleaned.bars).toEqual({ ice = { ["1"] = "iceShard" } })
	end)

	T.it("the pool data the migration reads is complete", function()
		for _, classId in Classes.order do
			T.expect(PoolData.get(classId) ~= nil).toBe(true)
		end
	end)
end)
