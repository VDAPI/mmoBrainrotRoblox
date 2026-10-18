--!strict
-- S143 (DESIGN-18 §6.2): the Warrior's shield school: Logic/Block (Vindicate's block counter, Shield Sweep's shield),
-- the skill's own weapon (SkillDef.weapon, Logic/Paths.skillUsable / skillWeaponError) and the model's mirror.

local Block = require("../src/shared/Logic/Block")
local Items = require("../src/shared/Data/Items")
local Paths = require("../src/shared/Logic/Paths")
local PathView = require("../src/shared/Logic/PathView")
local SkillData = require("../src/shared/Data/Skills")
local SkillModel = require("./SkillModel")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local RULES = SkillData.BLOCK

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

local function warrior(level: number, offhand: string?, ranks: { [string]: number }): any
	return {
		class = "Warrior",
		level = level,
		path = { nodes = {}, bp = {} },
		hotbar = {},
		equipment = {
			weapon = { id = itemOf("sword1h") },
			offhand = if offhand then { id = itemOf(offhand) } else nil,
		},
		ranks = { onehand = ranks },
		bars = {},
		barPool = "onehand",
	}
end

T.describe("Block: Vindicate's counter (S143)", function()
	T.it("record keeps the blocks inside the window and adds the new one", function()
		local times = Block.record({}, 1, RULES.window)
		T.expect(times).toEqual({ 1 })
		times = Block.record(times, 3, RULES.window)
		times = Block.record(times, 1 + RULES.window, RULES.window) -- the first block falls out of the window
		T.expect(times).toEqual({ 3, 1 + RULES.window })
		local frozen = table.freeze({ 1, 2 })
		Block.record(frozen, 3, RULES.window)
		T.expect(frozen).toEqual({ 1, 2 })
	end)

	T.it("count: inside the window, at most max", function()
		T.expect(Block.count(nil, 10, RULES.window, RULES.max)).toBe(0)
		T.expect(Block.count({ 5 }, 10, RULES.window, RULES.max)).toBe(1)
		T.expect(Block.count({ 4 }, 10, RULES.window, RULES.max)).toBe(0) -- exactly window seconds old
		T.expect(Block.count({ 5, 6, 7, 8, 9 }, 10, RULES.window, RULES.max)).toBe(RULES.max)
		T.expect(Block.count({ 11 }, 10, RULES.window, RULES.max)).toBe(0) -- a future time never counts
	end)

	T.it("Vindicate's multiplier and Shield Sweep's shield", function()
		T.expect(Block.vindicateMul(0, 15)).toBe(1)
		T.expect(Block.vindicateMul(3, 15)).toBeNear(1.45, 1e-12)
		T.expect(Block.vindicateMul(-1, 15)).toBe(1)
		T.expect(Block.hasShield("shield")).toBe(true)
		T.expect(Block.hasShield("orb")).toBe(false)
		T.expect(Block.hasShield(nil)).toBe(false)
		T.expect(Block.shieldMul(true, 20)).toBeNear(1.2, 1e-12)
		T.expect(Block.shieldMul(false, 20)).toBe(1)
	end)

	T.it("data: Vindicate per block, Shield Sweep with a shield, the window and the limit", function()
		T.expect(RULES.window > 0 and RULES.max >= 1).toBe(true)
		local vindicate = SkillData.get("vindicate") :: any
		T.expect({ vindicate.pool, vindicate.role, vindicate.values.perBlock ~= nil })
			.toEqual({ "onehand", "S3", true })
		local sweep = SkillData.get("shieldSweep") :: any
		T.expect({ sweep.pool, sweep.role, sweep.type, sweep.values.shieldDmg ~= nil, sweep.knockback ~= nil })
			.toEqual({
				"onehand",
				"A1",
				"cone",
				true,
				true,
			})
		-- Fortitude (the one-handed P1) and the Guardian's Block nodes give the block Vindicate counts
		local fortitude = SkillData.get("fortitude") :: any
		T.expect({ fortitude.role, fortitude.passive.hooks.block }).toEqual({ "P1", "block" })
		local args = Skills.descriptionArgs(vindicate, 1)
		T.expect({ args.blockWindow, args.blockMax }).toEqual({ RULES.window, RULES.max })
	end)

	T.it("the model mirrors the counter (expected blocks inside the window, capped)", function()
		local state: any = { t = 10, blocks = { { t = 3, n = 1 }, { t = 5, n = 0.5 }, { t = 9, n = 0.25 } } }
		T.expect(SkillModel.recentBlocks(state)).toBeNear(0.75, 1e-12)
		state.blocks = { { t = 6, n = 2 }, { t = 7, n = 2 } }
		T.expect(SkillModel.recentBlocks(state)).toBe(RULES.max)
		T.expect(SkillModel.recentBlocks({ t = 0 })).toBe(0)
	end)
end)

T.describe("Block: a skill that needs a shield (S143)", function()
	T.it("Shield Bash: SkillDef.weapon, the rule of node.weapon; the error names the shield", function()
		local bash = SkillData.get("shieldBash") :: any
		T.expect(bash.weapon).toEqual({ offhand = { "shield" } })
		T.expect(Paths.skillWeaponError(bash, { main = "sword1h", offhand = "shield" })).toBeNil()
		T.expect(Paths.skillWeaponError(bash, { main = "sword1h" })).toBe("cast.error.needShield")
		T.expect(Paths.skillWeaponError(bash, { main = "sword1h", offhand = "orb" })).toBe("cast.error.needShield")
		T.expect(Paths.skillWeaponError(SkillData.get("mightyStrike") :: any, { main = "sword1h" })).toBeNil()
		local other: any = table.clone(bash)
		other.weapon = { main = { "axe1h" } }
		T.expect(Paths.skillWeaponError(other, { main = "sword1h" })).toBe("cast.error.pathWeapon")
	end)

	T.it("skillUsable: bought and in the pool, but grey without a shield", function()
		local withShield = warrior(20, "shield", { shieldBash = 1 })
		T.expect({ Paths.skillUsable(withShield, "shieldBash", { main = "sword1h", offhand = "shield" }) }).toEqual({
			true,
			nil,
		})
		local bare = warrior(20, nil, { shieldBash = 1 })
		T.expect({ Paths.skillUsable(bare, "shieldBash", { main = "sword1h" }) }).toEqual({
			false,
			"cast.error.needShield",
		})
		-- the one-handed pool stays without a shield (DESIGN-18 §4.2): the other skills work
		T.expect({ Paths.skillUsable(warrior(20, nil, { mightyStrike = 1 }), "mightyStrike", { main = "sword1h" }) })
			.toEqual({ true, nil })
	end)

	T.it("the pool view greys the tile with the reason", function()
		local bare = warrior(20, nil, { shieldBash = 1 })
		local found: any = nil
		for _, row in (PathView.poolView(bare, "onehand", nil) :: any).rows do
			for _, tile in row.tiles do
				if tile.skillId == "shieldBash" then
					found = tile
				end
			end
		end
		T.expect(found ~= nil).toBe(true)
		T.expect({ found.weaponOk, found.weaponError }).toEqual({ false, "cast.error.needShield" })
		local shielded = warrior(20, "shield", { shieldBash = 1 })
		for _, row in (PathView.poolView(shielded, "onehand", nil) :: any).rows do
			for _, tile in row.tiles do
				T.expect({ tile.skillId, tile.weaponOk }).toEqual({ tile.skillId, true })
			end
		end
	end)
end)
