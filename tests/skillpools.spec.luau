--!strict
-- Weapon pools (S137, DESIGN-18 §4, §5, §9): Data/SkillPools and Logic/SkillPools.

local Classes = require("../src/shared/Data/Classes")
local Elements = require("../src/shared/Data/Elements")
local Items = require("../src/shared/Data/Items")
local PoolData = require("../src/shared/Data/SkillPools")
local SkillData = require("../src/shared/Data/Skills")
local SkillPools = require("../src/shared/Logic/SkillPools")
local T = require("./Test")

-- An item id of a base type (the lowest id), for equipment in the tests.
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

T.describe("Skill pools: data (S137)", function()
	T.it("every class has pools, a default pool among them, a version and a buying plan of its base members", function()
		for _, classId in Classes.order do
			local def = PoolData.get(classId) :: PoolData.ClassPools
			T.expect({ classId, def ~= nil }).toEqual({ classId, true })
			T.expect({ classId, def.version >= 1 }).toEqual({ classId, true })
			T.expect({ classId, SkillPools.def(classId, def.defaultPool) ~= nil }).toEqual({ classId, true })
			for _, pool in def.pools do
				T.expect(pool.nameKey).toBe(`skills.pool.{pool.id}`)
				-- the plan holds exactly the base members of the pool, actives before passives
				local members: { [string]: boolean } = {}
				for _, skill in SkillData.byClass[classId] do
					if skill.path == nil and SkillPools.memberDef(classId, pool.id, skill) then
						members[skill.id] = true
					end
				end
				local inPlan: { [string]: boolean } = {}
				local passiveSeen = false
				for _, id in pool.plan do
					local skill = SkillData.get(id) :: any
					T.expect({ pool.id, id, members[id] == true }).toEqual({ pool.id, id, true })
					inPlan[id] = true
					if skill.type == "passive" then
						passiveSeen = true
					else
						T.expect({ pool.id, id, passiveSeen }).toEqual({ pool.id, id, false })
					end
				end
				for id in members do
					T.expect({ pool.id, id, inPlan[id] == true }).toEqual({ pool.id, id, true })
				end
			end
			for _, id in def.commonPlan do
				T.expect({ classId, id, (SkillData.get(id) :: any).pool }).toEqual({ classId, id, "common" })
			end
		end
	end)

	T.it("every base skill has a pool of its class; path skills have none", function()
		for _, classId in Classes.order do
			for _, skill in SkillData.byClass[classId] do
				if skill.path == nil then
					local ok = skill.pool == "common" or SkillPools.def(classId, skill.pool or "") ~= nil
					T.expect({ skill.id, ok }).toEqual({ skill.id, true })
				else
					T.expect({ skill.id, skill.pool, skill.role }).toEqual({ skill.id, nil, nil })
				end
			end
		end
	end)

	T.it(
		"the Mage's pools do not mix elements: an element spell is in its element's pool, adaptive ones common",
		function()
			for _, skill in SkillData.byClass.Mage do
				if skill.path == nil then
					if skill.type == "passive" and skill.pool ~= "common" then
						-- S140: a school's passive (Kindling, Phoenix Heart) has no element, only its pool
						T.expect({ skill.id, table.find(Elements.WEAPON, skill.pool or "") ~= nil })
							.toEqual({ skill.id, true })
					elseif skill.adaptive or skill.element == nil then
						T.expect({ skill.id, skill.pool }).toEqual({ skill.id, "common" })
					else
						T.expect({ skill.id, skill.pool }).toEqual({ skill.id, skill.element })
					end
				end
			end
			for _, element in Elements.WEAPON do
				for _, id in SkillPools.members("Mage", element) do
					local skill = SkillData.get(id) :: any
					local foreign = skill.path == nil
						and not skill.adaptive
						and skill.element ~= nil
						and skill.element ~= element
					T.expect({ element, id, foreign }).toEqual({ element, id, false })
				end
			end
		end
	)

	T.it("the shared ladder (DESIGN-18 §5): a class past its transitional pools fills every rung once", function()
		T.expect(#PoolData.LADDER).toBe(11)
		T.expect(#PoolData.COMMON_LADDER).toBe(4)
		local levels: { [string]: number } = {}
		for _, rung in PoolData.LADDER do
			levels[rung.code] = rung.level
		end
		for _, rung in PoolData.COMMON_LADDER do
			levels[rung.code] = rung.level
		end
		T.expect(levels).toEqual({
			S1 = 1,
			A1 = 3,
			K1 = 6,
			O1 = 10,
			S2 = 15,
			P1 = 20,
			A2 = 26,
			K2 = 33,
			S3 = 40,
			P2 = 50,
			U = 60,
			C1 = 4,
			C2 = 12,
			C3 = 30,
			C4 = 45,
		})
		for _, classId in Classes.order do
			if SkillPools.isTransitional(classId) then
				continue -- S137: the old base split into pools; S140-S145 end it
			end
			local def = PoolData.get(classId) :: PoolData.ClassPools
			local function check(poolId: string, ladder: { PoolData.Rung })
				for _, rung in ladder do
					local found = {}
					for _, skill in SkillData.byClass[classId] do
						if skill.path == nil and skill.pool == poolId and skill.role == rung.code then
							table.insert(found, skill)
						end
					end
					T.expect({ classId, poolId, rung.code, #found }).toEqual({ classId, poolId, rung.code, 1 })
					local skill = found[1]
					if skill then
						T.expect({ skill.id, skill.unlock }).toEqual({ skill.id, rung.level })
						T.expect({ skill.id, skill.type == "passive" }).toEqual({ skill.id, rung.passive == true })
						if rung.passive then
							T.expect({ skill.id, skill.maxLevel }).toEqual({ skill.id, 5 })
						end
						T.expect(SkillPools.ladderOf(skill)).toEqual(rung)
					end
				end
			end
			for _, pool in def.pools do
				check(pool.id, PoolData.LADDER)
			end
			check("common", PoolData.COMMON_LADDER)
		end
	end)
end)

-- S140 (DESIGN-18 §5, §6.1): the Mage's fire pool and common skills on the shared ladder; S1 (Magic Bolt) and the ice
-- and lightning pools follow in S141 / S142 (the Mage stays transitional until then)
T.describe("Skill pools: the Mage's fire pool and common skills (S140)", function()
	T.it("the fire pool holds A1..U at the ladder's levels, the common skills C1..C4", function()
		local want = {
			A1 = "fireball",
			K1 = "flameWave",
			O1 = "emberShield",
			S2 = "pyroblast",
			P1 = "kindling",
			A2 = "meteor",
			K2 = "combustion",
			S3 = "immolate",
			P2 = "phoenixHeart",
			U = "meteorStorm",
		}
		for _, rung in PoolData.LADDER do
			local found = {}
			for _, skill in SkillData.byClass.Mage do
				if skill.path == nil and skill.pool == "fire" and skill.role == rung.code then
					table.insert(found, skill.id)
				end
			end
			local expected = want[rung.code]
			T.expect({ rung.code, found }).toEqual({ rung.code, if expected then { expected } else {} })
			if expected then
				local skill = SkillData.get(expected) :: any
				T.expect({ expected, skill.unlock, skill.type == "passive" }).toEqual({
					expected,
					rung.level,
					rung.passive == true,
				})
				T.expect(SkillPools.ladderOf(skill)).toEqual(rung)
				T.expect(SkillPools.inPool("Mage", "fire", expected)).toBe(true)
				T.expect(SkillPools.inPool("Mage", "ice", expected)).toBe(false)
			end
		end
		local common = { C1 = "blink", C2 = "manaShield", C3 = "evocation", C4 = "focus" }
		for _, rung in PoolData.COMMON_LADDER do
			local skill = SkillData.get(common[rung.code]) :: any
			T.expect({ skill.id, skill.pool, skill.role, skill.unlock, skill.path })
				.toEqual({ skill.id, "common", rung.code, rung.level, nil })
			for _, poolId in SkillPools.ids("Mage") do
				T.expect(SkillPools.inPool("Mage", poolId, skill.id)).toBe(true)
			end
		end
		-- Magic Bolt stays the common, adaptive S1 of every element until S142
		local bolt = SkillData.get("firebolt") :: any
		T.expect({ bolt.pool, bolt.adaptive, bolt.role }).toEqual({ "common", true, nil })
		T.expect(SkillPools.isTransitional("Mage")).toBe(true)
		T.expect(PoolData.get("Mage") and (PoolData.get("Mage") :: any).version).toBe(3)
	end)
end)

T.describe("Skill pools: the weapon picks the pool (S137)", function()
	T.it("poolOf: every weapon type of every class lands in exactly one pool; no weapon = the default pool", function()
		for _, classId in Classes.order do
			local class = Classes.get(classId) :: any
			local def = PoolData.get(classId) :: PoolData.ClassPools
			T.expect(SkillPools.poolOf(classId, {}, nil)).toBe(def.defaultPool)
			T.expect(SkillPools.poolOf(classId, nil, nil)).toBe(def.defaultPool)
			T.expect(SkillPools.poolOf(classId, { main = "notAWeapon" }, nil)).toBe(def.defaultPool)
			for _, weaponType in class.weaponTypes do
				-- "-" = no element (a class without element pools)
				local elements: { string } = if classId == "Mage" then table.clone(Elements.WEAPON) :: any else { "-" }
				for _, name in elements do
					local element: string? = if name == "-" then nil else name
					local count = 0
					for _, pool in def.pools do
						if
							table.find(pool.weapon.main, weaponType)
							and (pool.weapon.element == nil or pool.weapon.element == element)
						then
							count += 1
						end
					end
					T.expect({ classId, weaponType, name, count }).toEqual({ classId, weaponType, name, 1 })
					T.expect(SkillPools.poolOf(classId, { main = weaponType }, element) ~= nil).toBe(true)
				end
			end
		end
		T.expect(SkillPools.poolOf("Mage", { main = "wand" }, "ice")).toBe("ice")
		T.expect(SkillPools.poolOf("Mage", { main = "staff" }, "lightning")).toBe("lightning")
		T.expect(SkillPools.poolOf("Mage", { main = "runestaff" }, "fire")).toBe("fire")
		T.expect(SkillPools.poolOf("Warrior", { main = "axe2h" }, nil)).toBe("twohand")
		T.expect(SkillPools.poolOf("Warrior", { main = "mace1h", offhand = "shield" }, nil)).toBe("onehand")
		T.expect(SkillPools.poolOf("Hunter", { main = "heavycrossbow" }, nil)).toBe("crossbow")
		T.expect(SkillPools.poolOf("Cleric", { main = "holystaff" }, nil)).toBe("light")
		T.expect(SkillPools.poolOf("Cleric", { main = "flail1h" }, nil)).toBe("hammer")
		T.expect(SkillPools.poolOf("Nobody", { main = "wand" }, nil)).toBeNil()
	end)

	T.it("activePool reads the equipped weapon and its element (weapons from before S18 count as fire)", function()
		local wand = itemOf("wand")
		T.expect(SkillPools.activePool({ class = "Mage", equipment = { weapon = { id = wand, el = "lightning" } } }))
			.toBe("lightning")
		T.expect(SkillPools.activePool({ class = "Mage", equipment = { weapon = { id = wand } } })).toBe("fire")
		T.expect(SkillPools.activePool({ class = "Mage", equipment = {} })).toBe("fire")
		T.expect(SkillPools.activePool({ class = "Mage" })).toBe("fire")
		local bow = itemOf("crossbow")
		T.expect(SkillPools.activePool({ class = "Hunter", equipment = { weapon = { id = bow } } })).toBe("crossbow")
		T.expect(SkillPools.activePool({ class = "Hunter", equipment = { weapon = { id = "gone" } } })).toBe("bow")
	end)

	T.it("members: the school, the common skills and the class's path skills; inPool and valid", function()
		local ice = SkillPools.members("Mage", "ice")
		T.expect(table.find(ice, "iceShard") ~= nil).toBe(true)
		T.expect(table.find(ice, "firebolt") ~= nil).toBe(true)
		T.expect(table.find(ice, "blink") ~= nil).toBe(true)
		T.expect(table.find(ice, "fireball")).toBeNil()
		T.expect(table.find(ice, "elementalVortex") ~= nil).toBe(true) -- a path skill works in every pool
		T.expect(SkillPools.inPool("Mage", "fire", "meteor")).toBe(true)
		T.expect(SkillPools.inPool("Mage", "lightning", "meteor")).toBe(false)
		T.expect(SkillPools.inPool("Mage", "fire", "mightyStrike")).toBe(false)
		T.expect(SkillPools.inPool("Warrior", "twohand", "mightyStrike")).toBe(true)
		T.expect(SkillPools.valid("Mage", "ice")).toBe(true)
		T.expect(SkillPools.valid("Mage", "onehand")).toBe(false)
		T.expect(SkillPools.valid("Mage", 5)).toBe(false)
		T.expect(SkillPools.members("Mage", "nope")).toEqual({})
	end)
end)
