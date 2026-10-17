--!strict
-- S144 (DESIGN-18 §6.3): the Hunter's pools: Logic/Crossbow (Toxic Tips' stacks and gap, the Executioner's Bolt on the
-- poison stacks, Quick Reload for the Crossbow's skills only, Master Trapper's traps), Logic/Snare (a root on a boss is a
-- slow), Logic/DeadEye (the Marksman's keystone), the data and texts that read them and the model's mirror.

local B = require("./Balance")
local Crossbow = require("../src/shared/Logic/Crossbow")
local DeadEye = require("../src/shared/Logic/DeadEye")
local Items = require("../src/shared/Data/Items")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local SkillData = require("../src/shared/Data/Skills")
local SkillModel = require("./SkillModel")
local Skills = require("../src/shared/Logic/Skills")
local Snare = require("../src/shared/Logic/Snare")
local T = require("./Test")

local RULES = SkillData.CROSSBOW

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

local function hunter(level: number, weapon: string, ranks: { [string]: number }, nodes: { [string]: number }?): any
	local pool = if weapon == "crossbow" or weapon == "heavycrossbow" then "crossbow" else "bow"
	return {
		class = "Hunter",
		level = level,
		path = { nodes = nodes or {}, bp = {} },
		hotbar = {},
		equipment = { weapon = { id = itemOf(weapon) } },
		ranks = { [pool] = ranks },
		bars = {},
		barPool = pool,
	}
end

T.describe("Crossbow: Toxic Tips (S144)", function()
	T.it("one stack per target at most once per tipGap s; the stacks grow up to tipStacks", function()
		T.expect(Crossbow.tipReady(nil, 10, RULES.tipGap)).toBe(true)
		T.expect(Crossbow.tipReady(10, 10 + RULES.tipGap - 0.01, RULES.tipGap)).toBe(false)
		T.expect(Crossbow.tipReady(10, 10 + RULES.tipGap, RULES.tipGap)).toBe(true)
		local stacks = 0
		for _ = 1, RULES.tipStacks + 3 do
			stacks = Crossbow.tipStacks(stacks, RULES.tipStacks)
		end
		T.expect(stacks).toBe(RULES.tipStacks)
		T.expect(Crossbow.tipStacks(0, RULES.tipStacks)).toBe(1)
		-- the times of other targets stay, old ones go, the input is untouched
		local times = { a = 1, b = 9.5 }
		local out = Crossbow.tipRecord(times, "c", 10, RULES.tipGap)
		T.expect(out).toEqual({ b = 9.5, c = 10 })
		T.expect(times).toEqual({ a = 1, b = 9.5 })
		-- a burst of hits a tenth of a second apart on one target: one stack per gap
		local last: number? = nil
		local landed = 0
		for i = 0, 29 do
			local now = i * 0.1
			if Crossbow.tipReady(last, now, RULES.tipGap) then
				last = now
				landed += 1
			end
		end
		T.expect(landed).toBe(math.ceil(3 / RULES.tipGap))
	end)

	T.it("tipFor: the Crossbow's skills only; Master Trapper's traps the larger without the gap", function()
		T.expect({ Crossbow.tipFor("crossbow", "projectile", 12, 0) }).toEqual({ 12, false })
		T.expect({ Crossbow.tipFor("bow", "projectile", 12, 0) }).toEqual({ 0, false })
		T.expect({ Crossbow.tipFor("common", "debuff", 12, 0) }).toEqual({ 0, false })
		T.expect({ Crossbow.tipFor(nil, "circleTarget", 12, 15) }).toEqual({ 0, false }) -- the Drive (no pool)
		T.expect({ Crossbow.tipFor("crossbow", "trap", 12, 15) }).toEqual({ 15, true })
		T.expect({ Crossbow.tipFor("crossbow", "trap", 20, 15) }).toEqual({ 20, true })
		T.expect({ Crossbow.tipFor("crossbow", "trap", 0, 15) }).toEqual({ 15, true }) -- without Toxic Tips
		T.expect({ Crossbow.tipFor("crossbow", "trap", 12, 0) }).toEqual({ 12, false })
	end)

	T.it("data: Toxic Tips is the Crossbow's P1 with the toxicTips hook; its texts read the rules", function()
		local tips = SkillData.get("toxicTips") :: any
		T.expect({ tips.pool, tips.role, tips.type, tips.unlock }).toEqual({ "crossbow", "P1", "passive", 20 })
		T.expect(tips.passive.hooks.toxicTips).toBe("tip")
		local args = Skills.descriptionArgs(tips, 5)
		T.expect({ args.tipStacks, args.tipDuration, args.tipGap })
			.toEqual({ RULES.tipStacks, RULES.tipDuration, RULES.tipGap })
		-- the hook counts only while the crossbow is in the hands (the pool of the passive)
		local ranks = { toxicTips = 1 }
		local withCrossbow = Paths.passiveTotals(hunter(30, "crossbow", ranks), { main = "crossbow" }).hooks
		T.expect((withCrossbow.toxicTips or 0) > 0).toBe(true)
		local withBow = Paths.passiveTotals(hunter(30, "bow", {}), { main = "bow" }).hooks
		T.expect(withBow.toxicTips).toBeNil()
	end)
end)

T.describe("Crossbow: the Executioner's Bolt and Quick Reload (S144)", function()
	T.it("venomMul: x(1 + pct) from the needed stacks on", function()
		T.expect(Crossbow.venomMul(0, 3, 50)).toBe(1)
		T.expect(Crossbow.venomMul(2, 3, 50)).toBe(1)
		T.expect(Crossbow.venomMul(3, 3, 50)).toBeNear(1.5, 1e-9)
		T.expect(Crossbow.venomMul(7, 3, 85)).toBeNear(1.85, 1e-9)
		T.expect(Crossbow.venomMul(1, 0, 50)).toBeNear(1.5, 1e-9) -- at least one stack
		T.expect(Crossbow.venomMul(0, 0, 50)).toBe(1)
		local bolt = SkillData.get("deadlyBolt") :: any
		T.expect({ bolt.pool, bolt.role, bolt.unlock }).toEqual({ "crossbow", "S3", 40 })
		local a10 = Skills.effective(bolt, 10, { ["deadlyBolt:5"] = "a", ["deadlyBolt:10"] = "a" }, nil, true)
		T.expect(Skills.valueAt(a10, "venomMul", 10)).toBeNear(50 + 20 + 35, 1e-9)
		T.expect(Skills.valueAt(a10, "venomStacks", 10)).toBe(3)
	end)

	T.it("cdrFor: Quick Reload shortens the Crossbow's skills only, under the common cap", function()
		T.expect(Crossbow.cdrFor("crossbow", 6, 12)).toBe(18)
		T.expect(Crossbow.cdrFor("bow", 6, 12)).toBe(6)
		T.expect(Crossbow.cdrFor("common", 0, 12)).toBe(0)
		T.expect(Crossbow.cdrFor(nil, nil, 12)).toBe(0)
		T.expect(Crossbow.cdrFor("crossbow", nil, -5)).toBe(0)
		local bolt = SkillData.get("heavyBolt") :: any
		local base = Skills.cooldown(bolt, 1, 0)
		T.expect(Skills.cooldown(bolt, 1, Crossbow.cdrFor(bolt.pool, 0, 12))).toBeNear(base * 0.88, 1e-9)
		-- the description reads the quickReload hook for a Crossbow skill and ignores it for a Bow one
		local hooks = { quickReload = 12 }
		T.expect(Skills.descriptionArgs(bolt, 1, { hooks = hooks }).cooldown).toBeNear(base * 0.88, 0.05) -- rounded
		local aimed = SkillData.get("aimedShot") :: any
		T.expect(Skills.descriptionArgs(aimed, 1, { hooks = hooks }).cooldown).toBe(Skills.cooldown(aimed, 1, 0))
		local reload = SkillData.get("quickReload") :: any
		T.expect({ reload.pool, reload.role, reload.passive.hooks.quickReload }).toEqual({ "crossbow", "P2", "reload" })
	end)
end)

T.describe("Snare and Dead Eye (S144)", function()
	T.it("a root with bossSlow lands as a slow on bosses and Elite IIs only", function()
		T.expect(Snare.kindOn("root", true, 40)).toBe("slow")
		T.expect(Snare.kindOn("root", false, 40)).toBe("root")
		T.expect(Snare.kindOn("root", true, nil)).toBe("root")
		T.expect(Snare.kindOn("root", true, 0)).toBe("root")
		T.expect(Snare.kindOn("stun", true, 40)).toBe("stun")
		for _, id in { "pinningShot", "netShot" } do
			local def = SkillData.get(id) :: any
			local effect = def.effects[1]
			T.expect({ id, effect.kind, effect.bossSlow, effect.notBoss }).toEqual({ id, "root", "slow", nil })
			T.expect({ id, Skills.valueAt(def, "slow", 1) > 0 }).toEqual({ id, true })
		end
	end)

	T.it("Dead Eye: a sure crit on a one-target main hit from the threshold up", function()
		T.expect(DeadEye.sure(80, "projectile", true, 80)).toBe(true)
		T.expect(DeadEye.sure(80, "projectile", true, 79.9)).toBe(false)
		T.expect(DeadEye.sure(80, "target", true, 100)).toBe(true)
		T.expect(DeadEye.sure(80, "projectile", false, 100)).toBe(false) -- a splash, pierce or zone tick
		T.expect(DeadEye.sure(80, "trap", true, 100)).toBe(false)
		T.expect(DeadEye.sure(80, "circleTarget", true, 100)).toBe(false)
		T.expect(DeadEye.sure(0, "projectile", true, 100)).toBe(false)
		T.expect(DeadEye.sure(80, "projectile", true, nil)).toBe(false)
		local node = Paths.findNode("marksman_deadEye") :: any
		T.expect({ node.kind, node.maxRank, node.passive.hooks.deadEye }).toEqual({ "keystone", 1, "deadEye" })
		local trap = Paths.findNode("trapper_masterTrapper") :: any
		T.expect({ trap.kind, trap.passive.hooks.masterTrapper }).toEqual({ "keystone", "masterTip" })
		-- the keystones sit in the capstone row (8) of their direction
		for _, path in PathData.byClass.Hunter do
			local row = path.rows[8]
			T.expect({ path.id, #row.nodes }).toEqual({ path.id, 1 })
		end
	end)
end)

T.describe("Hunter pools: the model's mirror (S144)", function()
	T.it("Toxic Tips: the tip poison in the Crossbow's fight, none with the bow", function()
		local poacher = SkillModel.build("trapper.poacher", "Hunter") :: any
		local one = { B.monster(B.GENERIC, 45) }
		local crossbowFight = SkillModel.fight(SkillModel.player(poacher, 45), { targets = one, unlimited = true })
		T.expect((crossbowFight.by[RULES.tipKey] or 0) > 0).toBe(true)
		local bow = SkillModel.withWeapon(poacher, "bow", "quiver")
		local bowFight = SkillModel.fight(SkillModel.player(bow, 45), { targets = one, unlimited = true })
		T.expect(bowFight.by[RULES.tipKey]).toBeNil()
	end)

	T.it("Dead Eye and the Executioner's Bolt raise the damage they promise", function()
		local kingslayer = SkillModel.build("marksman.kingslayer", "Hunter") :: any
		-- the build buys its keystone late (row 8 after the rows 1-7 of three directions): measured at 100
		local without = SkillModel.withoutNodes(kingslayer, { "marksman_deadEye" })
		T.expect(SkillModel.metrics(kingslayer, 100).single60 > SkillModel.metrics(without, 100).single60).toBe(true)
		-- the Executioner's Bolt in the Trapper's rotation hits poisoned targets: its option of the bonus has a value
		local gain =
			SkillModel.optionGain(SkillModel.build("trapper.poacher", "Hunter") :: any, "deadlyBolt", 10, "a", 100)
		T.expect(gain ~= nil and gain > 0.1).toBe(true)
	end)
end)

return nil
