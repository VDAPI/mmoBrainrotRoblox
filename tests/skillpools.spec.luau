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

	-- S145: every class fills the ladder (the transitional state ended with the Cleric's pools)
	T.it("the shared ladder (DESIGN-18 §5): every class fills every rung once", function()
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
			local def = PoolData.get(classId) :: PoolData.ClassPools
			T.expect({ classId, (def :: any).transitional }).toEqual({ classId, nil })
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

-- S140 (DESIGN-18 §5, §6.1): the Mage's fire pool and common skills on the shared ladder; S142: Fire Bolt is the fire
-- pool's S1 (no longer common and adaptive)
T.describe("Skill pools: the Mage's fire pool and common skills (S140)", function()
	T.it("the fire pool holds S1..U at the ladder's levels, the common skills C1..C4", function()
		local want = {
			S1 = "firebolt",
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
		-- S142: Fire Bolt is the fire pool's S1, of fire, not adaptive (it was the common S1 of every element)
		local bolt = SkillData.get("firebolt") :: any
		T.expect({ bolt.pool, bolt.adaptive, bolt.role, bolt.element }).toEqual({ "fire", nil, "S1", "fire" })
		T.expect((PoolData.get("Mage") :: any).transitional).toBeNil()
		-- S141: 3 -> 4; S142: 4 -> 5
		T.expect(PoolData.get("Mage") and (PoolData.get("Mage") :: any).version).toBe(5)
	end)
end)

-- S141 (DESIGN-18 §5, §6.1): the Mage's ice pool on the shared ladder, S1 included (Ice Shard); S142: Fire Bolt left the
-- common skills and the Mage is no longer transitional
T.describe("Skill pools: the Mage's ice pool (S141)", function()
	T.it("the ice pool holds every LADDER code at its level, in the plan's ladder order", function()
		local want = {
			S1 = "iceShard",
			A1 = "hailstorm",
			K1 = "frostNova",
			O1 = "iceBarrier",
			S2 = "glacialSpike",
			P1 = "wintersGrip",
			A2 = "frozenOrb",
			K2 = "deepFreeze",
			S3 = "shatter",
			P2 = "iceBlood",
			U = "blizzard",
		}
		local seen = 0
		for _, rung in PoolData.LADDER do
			local found = {}
			for _, skill in SkillData.byClass.Mage do
				if skill.path == nil and skill.pool == "ice" and skill.role == rung.code then
					table.insert(found, skill.id)
				end
			end
			local expected = want[rung.code]
			T.expect({ rung.code, found }).toEqual({ rung.code, { expected } })
			local skill = SkillData.get(expected) :: any
			T.expect({ expected, skill.unlock, skill.type == "passive", skill.element or "ice" }).toEqual({
				expected,
				rung.level,
				rung.passive == true,
				"ice",
			})
			if skill.type == "passive" then
				T.expect({ expected, skill.maxLevel }).toEqual({ expected, 5 })
			end
			T.expect(SkillPools.ladderOf(skill)).toEqual(rung)
			T.expect(SkillPools.inPool("Mage", "ice", expected)).toBe(true)
			T.expect(SkillPools.inPool("Mage", "fire", expected)).toBe(false)
			T.expect(SkillPools.inPool("Mage", "lightning", expected)).toBe(false)
			seen += 1
		end
		T.expect(seen).toBe(#PoolData.LADDER)
		-- the plan: every ice and common skill once, actives before passives
		local mage = PoolData.get("Mage") :: any
		local plan: { string } = {}
		for _, p in mage.pools do
			if p.id == "ice" then
				plan = p.plan
			end
		end
		local members: { [string]: boolean } = {}
		for _, skill in SkillData.byClass.Mage do
			if skill.path == nil and (skill.pool == "ice" or skill.pool == "common") then
				members[skill.id] = true
			end
		end
		local passive = false
		for _, id in plan do
			T.expect({ id, members[id] }).toEqual({ id, true })
			members[id] = nil
			local def = SkillData.get(id) :: any
			if def.type == "passive" then
				passive = true
			else
				T.expect({ id, passive }).toEqual({ id, false })
			end
		end
		T.expect(next(members)).toBe(nil)
		T.expect((PoolData.get("Mage") :: any).transitional).toBeNil() -- S142 (S145: the field is gone)
	end)
end)

-- S142 (DESIGN-18 §5, §6.1): the end of the Mage's transitional state. Three full pools of one element each on the shared
-- ladder (the same role at the same level in every pool), the common skills on COMMON_LADDER, no Mage skill without a
-- pool or a path, no spell of another element in a pool.
T.describe("Skill pools: the Mage's three pools on one ladder (S142)", function()
	local WANT: { [string]: { [string]: string } } = {
		fire = {
			S1 = "firebolt",
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
		},
		ice = {
			S1 = "iceShard",
			A1 = "hailstorm",
			K1 = "frostNova",
			O1 = "iceBarrier",
			S2 = "glacialSpike",
			P1 = "wintersGrip",
			A2 = "frozenOrb",
			K2 = "deepFreeze",
			S3 = "shatter",
			P2 = "iceBlood",
			U = "blizzard",
		},
		lightning = {
			S1 = "lightningBolt",
			A1 = "chainLightning",
			K1 = "staticShock",
			O1 = "stormArmor",
			S2 = "thunderStrike",
			P1 = "overcharge",
			A2 = "firewall",
			K2 = "ballLightning",
			S3 = "lightningLance",
			P2 = "conductor",
			U = "tempest",
		},
	}

	T.it("every pool holds exactly one skill of its element per LADDER code, at the code's level", function()
		T.expect((PoolData.get("Mage") :: any).transitional).toBeNil()
		T.expect(SkillPools.ids("Mage")).toEqual({ "fire", "ice", "lightning" })
		for poolId, want in WANT do
			for _, rung in PoolData.LADDER do
				local found = {}
				for _, skill in SkillData.byClass.Mage do
					if skill.path == nil and skill.pool == poolId and skill.role == rung.code then
						table.insert(found, skill.id)
					end
				end
				local expected = want[rung.code]
				T.expect({ poolId, rung.code, found }).toEqual({ poolId, rung.code, { expected } })
				local skill = SkillData.get(expected) :: any
				T.expect({ expected, skill.unlock, skill.type == "passive", skill.element or poolId }).toEqual({
					expected,
					rung.level,
					rung.passive == true,
					poolId,
				})
				if skill.type == "passive" then
					T.expect({ expected, skill.maxLevel }).toEqual({ expected, 5 })
				end
				for _, other in SkillPools.ids("Mage") do
					T.expect({ expected, other, SkillPools.inPool("Mage", other, expected) })
						.toEqual({ expected, other, other == poolId })
				end
			end
		end
	end)

	T.it(
		"every Mage skill has a pool or a path; no pool holds a spell of another element; no adaptive base skill",
		function()
			for _, skill in SkillData.byClass.Mage do
				T.expect({ skill.id, skill.pool ~= nil or skill.path ~= nil }).toEqual({ skill.id, true })
				if skill.path == nil then
					T.expect({ skill.id, skill.adaptive }).toEqual({ skill.id, nil })
					T.expect({ skill.id, skill.role ~= nil }).toEqual({ skill.id, true })
				end
				if skill.pool and skill.pool ~= "common" and skill.element then
					T.expect({ skill.id, skill.element }).toEqual({ skill.id, skill.pool })
				end
				if skill.pool == "common" then
					T.expect({ skill.id, skill.element }).toEqual({ skill.id, nil })
				end
			end
			for _, poolId in SkillPools.ids("Mage") do
				for _, id in SkillPools.members("Mage", poolId) do
					local def = SkillData.get(id) :: any
					T.expect({ poolId, id, def.element == nil or def.element == poolId or def.adaptive == true })
						.toEqual({ poolId, id, true })
				end
			end
		end
	)

	T.it("the plans: every pool's and common skill once, in ladder order, actives before passives", function()
		local mage = PoolData.get("Mage") :: any
		T.expect(mage.commonPlan).toEqual({ "blink", "manaShield", "evocation", "focus" })
		for _, p in mage.pools do
			local members: { [string]: boolean } = {}
			for _, skill in SkillData.byClass.Mage do
				if skill.path == nil and (skill.pool == p.id or skill.pool == "common") then
					members[skill.id] = true
				end
			end
			local passive = false
			local lastLevel = 0
			for _, id in p.plan do
				T.expect({ p.id, id, members[id] }).toEqual({ p.id, id, true })
				members[id] = nil
				local def = SkillData.get(id) :: any
				if def.type == "passive" then
					passive = true
				else
					T.expect({ p.id, id, passive }).toEqual({ p.id, id, false })
					T.expect({ p.id, id, def.unlock >= lastLevel }).toEqual({ p.id, id, true })
					lastLevel = def.unlock
				end
			end
			T.expect({ p.id, next(members) }).toEqual({ p.id, nil })
		end
	end)
end)

-- S143 (DESIGN-18 §5, §6.2): the Warrior's two pools on the shared ladder, the common skills on COMMON_LADDER, the end
-- of the Warrior's transitional state.
T.describe("Skill pools: the Warrior's two pools (S143)", function()
	local WANT: { [string]: { [string]: string } } = {
		onehand = {
			S1 = "mightyStrike",
			A1 = "shieldSweep",
			K1 = "shieldBash",
			O1 = "intercept",
			S2 = "crushingBlow",
			P1 = "fortitude",
			A2 = "earthquake",
			K2 = "warBanner",
			S3 = "vindicate",
			P2 = "riposte",
			U = "shieldWall",
		},
		twohand = {
			S1 = "brutalStrike",
			A1 = "cleave",
			K1 = "sunder",
			O1 = "bloodlust",
			S2 = "rend",
			P1 = "rage",
			A2 = "bladeWhirl",
			K2 = "warStomp",
			S3 = "execute",
			P2 = "unstoppable",
			U = "titansWrath",
		},
	}

	T.it("every pool holds exactly one skill per LADDER code at the code's level; C1-C4 common", function()
		T.expect((PoolData.get("Warrior") :: any).transitional).toBeNil()
		T.expect(SkillPools.ids("Warrior")).toEqual({ "onehand", "twohand" })
		for poolId, want in WANT do
			for _, rung in PoolData.LADDER do
				local found = {}
				for _, skill in SkillData.byClass.Warrior do
					if skill.path == nil and skill.pool == poolId and skill.role == rung.code then
						table.insert(found, skill.id)
					end
				end
				local expected = want[rung.code]
				T.expect({ poolId, rung.code, found }).toEqual({ poolId, rung.code, { expected } })
				local skill = SkillData.get(expected) :: any
				T.expect({ expected, skill.unlock, skill.type == "passive" }).toEqual({
					expected,
					rung.level,
					rung.passive == true,
				})
				if skill.type == "passive" then
					T.expect({ expected, skill.maxLevel }).toEqual({ expected, 5 })
				else
					T.expect({ expected, skill.delivery }).toEqual({ expected, "melee" })
				end
				for _, other in SkillPools.ids("Warrior") do
					T.expect({ expected, other, SkillPools.inPool("Warrior", other, expected) })
						.toEqual({ expected, other, other == poolId })
				end
			end
		end
		local common = { C1 = "charge", C2 = "taunt", C3 = "battleCry", C4 = "steelSkin" }
		for _, rung in PoolData.COMMON_LADDER do
			local skill = SkillData.get(common[rung.code]) :: any
			T.expect({ skill.id, skill.pool, skill.role, skill.unlock, skill.path })
				.toEqual({ skill.id, "common", rung.code, rung.level, nil })
			for _, poolId in SkillPools.ids("Warrior") do
				T.expect(SkillPools.inPool("Warrior", poolId, skill.id)).toBe(true)
			end
		end
		-- S143: 2 -> 3 (a free reset)
		T.expect((PoolData.get("Warrior") :: any).version).toBe(3)
	end)

	T.it("every Warrior skill has a pool or a path; the directions keep only their capstones", function()
		local onPath: { [string]: string } = {}
		for _, skill in SkillData.byClass.Warrior do
			T.expect({ skill.id, skill.pool ~= nil or skill.path ~= nil }).toEqual({ skill.id, true })
			if skill.path == nil then
				T.expect({ skill.id, skill.role ~= nil }).toEqual({ skill.id, true })
			else
				onPath[skill.id] = skill.path
			end
		end
		T.expect(onPath).toEqual({ lastBastion = "guardian", carnage = "berserker", advanceOrder = "standard" })
		-- Shield Bash needs a shield (SkillDef.weapon); no other pool skill has a weapon of its own
		for _, skill in SkillData.byClass.Warrior do
			local def: any = skill
			T.expect({ skill.id, def.weapon ~= nil }).toEqual({ skill.id, skill.id == "shieldBash" })
		end
	end)

	T.it("the plans: every pool's and common skill once, in ladder order, actives before passives", function()
		local warrior = PoolData.get("Warrior") :: any
		T.expect(warrior.commonPlan).toEqual({ "charge", "taunt", "battleCry", "steelSkin" })
		for _, p in warrior.pools do
			local members: { [string]: boolean } = {}
			for _, skill in SkillData.byClass.Warrior do
				if skill.path == nil and (skill.pool == p.id or skill.pool == "common") then
					members[skill.id] = true
				end
			end
			local passive = false
			local lastLevel = 0
			for _, id in p.plan do
				T.expect({ p.id, id, members[id] }).toEqual({ p.id, id, true })
				members[id] = nil
				local def = SkillData.get(id) :: any
				if def.type == "passive" then
					passive = true
				else
					T.expect({ p.id, id, passive }).toEqual({ p.id, id, false })
					T.expect({ p.id, id, def.unlock >= lastLevel }).toEqual({ p.id, id, true })
					lastLevel = def.unlock
				end
			end
			T.expect({ p.id, next(members) }).toEqual({ p.id, nil })
		end
	end)
end)

-- S144 (DESIGN-18 §5, §6.3): the Hunter's two pools on the shared ladder, the common skills on COMMON_LADDER, the end of
-- the Hunter's transitional state.
T.describe("Skill pools: the Hunter's two pools (S144)", function()
	local WANT: { [string]: { [string]: string } } = {
		bow = {
			S1 = "aimedShot",
			A1 = "arrowRain",
			K1 = "pinningShot",
			O1 = "windstep",
			S2 = "doubleShot",
			P1 = "hawkEye",
			A2 = "volley",
			K2 = "falcon",
			S3 = "heartseeker",
			P2 = "agility",
			U = "stormArrow",
		},
		crossbow = {
			S1 = "heavyBolt",
			A1 = "piercingArrow",
			K1 = "frostTrap",
			O1 = "camouflage",
			S2 = "venomArrow",
			P1 = "toxicTips",
			A2 = "venomSnare",
			K2 = "netShot",
			S3 = "deadlyBolt",
			P2 = "quickReload",
			U = "snarefield",
		},
	}

	T.it("every pool holds exactly one skill per LADDER code at the code's level; C1-C4 common", function()
		T.expect((PoolData.get("Hunter") :: any).transitional).toBeNil()
		T.expect(SkillPools.ids("Hunter")).toEqual({ "bow", "crossbow" })
		for poolId, want in WANT do
			for _, rung in PoolData.LADDER do
				local found = {}
				for _, skill in SkillData.byClass.Hunter do
					if skill.path == nil and skill.pool == poolId and skill.role == rung.code then
						table.insert(found, skill.id)
					end
				end
				local expected = want[rung.code]
				T.expect({ poolId, rung.code, found }).toEqual({ poolId, rung.code, { expected } })
				local skill = SkillData.get(expected) :: any
				T.expect({ expected, skill.unlock, skill.type == "passive" }).toEqual({
					expected,
					rung.level,
					rung.passive == true,
				})
				if skill.type == "passive" then
					T.expect({ expected, skill.maxLevel }).toEqual({ expected, 5 })
				else
					T.expect({ expected, skill.delivery }).toEqual({ expected, "ranged" })
				end
				for _, other in SkillPools.ids("Hunter") do
					T.expect({ expected, other, SkillPools.inPool("Hunter", other, expected) })
						.toEqual({ expected, other, other == poolId })
				end
			end
		end
		local common = { C1 = "disengage", C2 = "huntersMark", C3 = "drawBead", C4 = "predatorInstinct" }
		for _, rung in PoolData.COMMON_LADDER do
			local skill = SkillData.get(common[rung.code]) :: any
			T.expect({ skill.id, skill.pool, skill.role, skill.unlock, skill.path })
				.toEqual({ skill.id, "common", rung.code, rung.level, nil })
			for _, poolId in SkillPools.ids("Hunter") do
				T.expect(SkillPools.inPool("Hunter", poolId, skill.id)).toBe(true)
			end
		end
		-- S144: 2 -> 3 (a free reset)
		T.expect((PoolData.get("Hunter") :: any).version).toBe(3)
	end)

	T.it(
		"every Hunter skill has a pool or a path; the directions keep only the Drive; no skill has its own weapon",
		function()
			local onPath: { [string]: string } = {}
			for _, skill in SkillData.byClass.Hunter do
				T.expect({ skill.id, skill.pool ~= nil or skill.path ~= nil }).toEqual({ skill.id, true })
				if skill.path == nil then
					T.expect({ skill.id, skill.role ~= nil }).toEqual({ skill.id, true })
				else
					onPath[skill.id] = skill.path
				end
				local def: any = skill
				T.expect({ skill.id, def.weapon }).toEqual({ skill.id, nil })
			end
			T.expect(onPath).toEqual({ drive = "scout" })
		end
	)

	T.it("the weapon picks the pool: bows the Bow, crossbows the Crossbow, the quiver nothing", function()
		for _, main in { "shortbow", "bow", "longbow" } do
			T.expect({ main, SkillPools.poolOf("Hunter", { main = main, offhand = "quiver" }, nil) })
				.toEqual({ main, "bow" })
		end
		for _, main in { "crossbow", "heavycrossbow" } do
			T.expect({ main, SkillPools.poolOf("Hunter", { main = main, offhand = "quiver" }, nil) })
				.toEqual({ main, "crossbow" })
			T.expect({ main, SkillPools.poolOf("Hunter", { main = main }, nil) }).toEqual({ main, "crossbow" })
		end
		T.expect(SkillPools.poolOf("Hunter", { offhand = "quiver" }, nil)).toBe("bow")
	end)

	T.it("the plans: every pool's and common skill once, in ladder order, actives before passives", function()
		local hunter = PoolData.get("Hunter") :: any
		T.expect(hunter.commonPlan).toEqual({ "disengage", "huntersMark", "drawBead", "predatorInstinct" })
		for _, p in hunter.pools do
			local members: { [string]: boolean } = {}
			for _, skill in SkillData.byClass.Hunter do
				if skill.path == nil and (skill.pool == p.id or skill.pool == "common") then
					members[skill.id] = true
				end
			end
			local passive = false
			local lastLevel = 0
			for _, id in p.plan do
				T.expect({ p.id, id, members[id] }).toEqual({ p.id, id, true })
				members[id] = nil
				local def = SkillData.get(id) :: any
				if def.type == "passive" then
					passive = true
				else
					T.expect({ p.id, id, passive }).toEqual({ p.id, id, false })
					T.expect({ p.id, id, def.unlock >= lastLevel }).toEqual({ p.id, id, true })
					lastLevel = def.unlock
				end
			end
			T.expect({ p.id, next(members) }).toEqual({ p.id, nil })
		end
	end)
end)

-- S145 (DESIGN-18 §5, §6.4): the Cleric's two pools on the shared ladder, the common skills on COMMON_LADDER, the end of
-- the transitional state of every class.
T.describe("Skill pools: the Cleric's two pools (S145)", function()
	local WANT: { [string]: { [string]: string } } = {
		light = {
			S1 = "lightRay",
			A1 = "radiance",
			K1 = "blindingLight",
			O1 = "shieldOfFaith",
			S2 = "renew",
			P1 = "grace",
			A2 = "sanctuary",
			K2 = "purify",
			S3 = "miracle",
			P2 = "guidingLight",
			U = "guardianAngel",
		},
		hammer = {
			S1 = "holyStrike",
			A1 = "consecrate",
			K1 = "holyChains",
			O1 = "auraOfEndurance",
			S2 = "brandOfLight",
			P1 = "divineWrath",
			A2 = "holyNova",
			K2 = "rebuke",
			S3 = "judgement",
			P2 = "zeal",
			U = "hammerOfHeaven",
		},
	}

	T.it("every pool holds exactly one skill per LADDER code at the code's level; C1-C4 common", function()
		T.expect((PoolData.get("Cleric") :: any).transitional).toBeNil()
		T.expect(SkillPools.ids("Cleric")).toEqual({ "light", "hammer" })
		for poolId, want in WANT do
			for _, rung in PoolData.LADDER do
				local found = {}
				for _, skill in SkillData.byClass.Cleric do
					if skill.path == nil and skill.pool == poolId and skill.role == rung.code then
						table.insert(found, skill.id)
					end
				end
				local expected = want[rung.code]
				T.expect({ poolId, rung.code, found }).toEqual({ poolId, rung.code, { expected } })
				local skill = SkillData.get(expected) :: any
				T.expect({ expected, skill.unlock, skill.type == "passive" }).toEqual({
					expected,
					rung.level,
					rung.passive == true,
				})
				if skill.type == "passive" then
					T.expect({ expected, skill.maxLevel }).toEqual({ expected, 5 })
				else
					T.expect({ expected, skill.delivery ~= nil }).toEqual({ expected, true })
				end
				for _, other in SkillPools.ids("Cleric") do
					T.expect({ expected, other, SkillPools.inPool("Cleric", other, expected) })
						.toEqual({ expected, other, other == poolId })
				end
			end
		end
		local common = { C1 = "heal", C2 = "circleOfLight", C3 = "resurrection", C4 = "devotion" }
		for _, rung in PoolData.COMMON_LADDER do
			local skill = SkillData.get(common[rung.code]) :: any
			T.expect({ skill.id, skill.pool, skill.role, skill.unlock, skill.path })
				.toEqual({ skill.id, "common", rung.code, rung.level, nil })
			for _, poolId in SkillPools.ids("Cleric") do
				T.expect(SkillPools.inPool("Cleric", poolId, skill.id)).toBe(true)
			end
		end
		-- S145: 2 -> 3 (a free reset)
		T.expect((PoolData.get("Cleric") :: any).version).toBe(3)
	end)

	T.it(
		"every Cleric skill has a pool or a path; the directions keep four skills, none with its own weapon",
		function()
			local onPath: { [string]: string } = {}
			for _, skill in SkillData.byClass.Cleric do
				T.expect({ skill.id, skill.pool ~= nil or skill.path ~= nil }).toEqual({ skill.id, true })
				if skill.path == nil then
					T.expect({ skill.id, skill.role ~= nil }).toEqual({ skill.id, true })
				else
					onPath[skill.id] = skill.path
				end
				local def: any = skill
				T.expect({ skill.id, def.weapon }).toEqual({ skill.id, nil })
			end
			T.expect(onPath).toEqual({
				prayer = "healer",
				divineIntervention = "healer",
				fortuneDice = "fortune",
				wheelOfFortune = "fortune",
			})
		end
	)

	T.it(
		"the weapon picks the pool: scepters and staves the light, maces and flails the hammer, the off hand nothing",
		function()
			for _, main in { "scepter", "holystaff" } do
				for _, off in { "shield", "relic" } do
					T.expect({ main, off, SkillPools.poolOf("Cleric", { main = main, offhand = off }, nil) })
						.toEqual({ main, off, "light" })
				end
			end
			for _, main in { "mace1h", "flail1h" } do
				for _, off in { "shield", "relic" } do
					T.expect({ main, off, SkillPools.poolOf("Cleric", { main = main, offhand = off }, nil) })
						.toEqual({ main, off, "hammer" })
				end
			end
			T.expect(SkillPools.poolOf("Cleric", { offhand = "relic" }, nil)).toBe("hammer")
		end
	)

	T.it("the plans: every pool's and common skill once, in ladder order, actives before passives", function()
		local cleric = PoolData.get("Cleric") :: any
		T.expect(cleric.commonPlan).toEqual({ "heal", "circleOfLight", "resurrection", "devotion" })
		for _, p in cleric.pools do
			local members: { [string]: boolean } = {}
			for _, skill in SkillData.byClass.Cleric do
				if skill.path == nil and (skill.pool == p.id or skill.pool == "common") then
					members[skill.id] = true
				end
			end
			local passive = false
			local lastLevel = 0
			for _, id in p.plan do
				T.expect({ p.id, id, members[id] }).toEqual({ p.id, id, true })
				members[id] = nil
				local def = SkillData.get(id) :: any
				if def.type == "passive" then
					passive = true
				else
					T.expect({ p.id, id, passive }).toEqual({ p.id, id, false })
					T.expect({ p.id, id, def.unlock >= lastLevel }).toEqual({ p.id, id, true })
					lastLevel = def.unlock
				end
			end
			T.expect({ p.id, next(members) }).toEqual({ p.id, nil })
		end
	end)
end)

-- S145 (DESIGN-18 §5, §13): the end of the transitional state: every class has two (Mage: three) pools of 11 on the
-- ladder and 4 common skills, every pool skill a role, every active skill A and B at ranks 5 and 10, a short text, a
-- motion, a look, a sound key and a server timing row; every modify node names an existing skill.
T.describe("Skill pools: every class on the full ladder (S145)", function()
	local Sfx = require("../src/shared/Data/Sfx")
	local Skills = require("../src/shared/Logic/Skills")
	local SkillMotions = require("../src/shared/Data/SkillMotions")
	local SkillVfx = require("../src/shared/Data/SkillVfx")
	local Timing = require("./fixtures/skill_timing")
	local PathData = require("../src/shared/Data/Paths")
	local pl = require("../src/shared/Data/Localization/pl")
	local en = require("../src/shared/Data/Localization/en")

	T.it("the full ladder of every pool and the common skills of every class", function()
		for _, classId in Classes.order do
			local def = PoolData.get(classId) :: PoolData.ClassPools
			T.expect({ classId, (def :: any).transitional }).toEqual({ classId, nil })
			for _, pool in def.pools do
				local roles: { [string]: number } = {}
				for _, skill in SkillData.byClass[classId] do
					if skill.path == nil and skill.pool == pool.id then
						roles[skill.role :: string] = (roles[skill.role :: string] or 0) + 1
					end
				end
				for _, rung in PoolData.LADDER do
					T.expect({ classId, pool.id, rung.code, roles[rung.code] })
						.toEqual({ classId, pool.id, rung.code, 1 })
					roles[rung.code] = nil
				end
				T.expect({ classId, pool.id, next(roles) }).toEqual({ classId, pool.id, nil })
			end
			local common: { [string]: number } = {}
			for _, skill in SkillData.byClass[classId] do
				if skill.path == nil and skill.pool == PoolData.COMMON then
					common[skill.role :: string] = (common[skill.role :: string] or 0) + 1
				end
			end
			for _, rung in PoolData.COMMON_LADDER do
				T.expect({ classId, rung.code, common[rung.code] }).toEqual({ classId, rung.code, 1 })
			end
		end
	end)

	T.it(
		"every skill: a pool or a path, a role in a pool; every active: A and B, short, motion, look, sound, timing",
		function()
			for _, skill in SkillData.byId do
				T.expect({ skill.id, skill.pool ~= nil or skill.path ~= nil }).toEqual({ skill.id, true })
				if skill.path == nil then
					T.expect({ skill.id, SkillPools.ladderOf(skill) ~= nil }).toEqual({ skill.id, true })
				end
				local short = `skill.{skill.id}.short`
				T.expect({ short, (pl :: any)[short] ~= nil, (en :: any)[short] ~= nil }).toEqual({ short, true, true })
				if skill.type ~= "passive" then
					for _, at in Skills.BREAKPOINT_LEVELS do
						local pair = skill.breakpoints and (skill.breakpoints :: any)[at]
						T.expect({ skill.id, at, pair ~= nil and pair.a ~= nil, pair ~= nil and pair.b ~= nil })
							.toEqual({ skill.id, at, true, true })
					end
					T.expect({
						skill.id,
						SkillMotions.get(skill.id) ~= nil,
						SkillVfx[skill.id] ~= nil,
						Sfx.has(`skill.{skill.id}`),
						Timing.skills[skill.id] ~= nil,
					}).toEqual({ skill.id, true, true, true, true })
				end
			end
		end
	)

	T.it("every modify node names an existing skill of its class", function()
		for _, path in PathData.list do
			for _, row in path.rows do
				for _, node in row.nodes do
					local modify = (node :: any).modify
					if modify then
						local skill = SkillData.get(modify.skill)
						T.expect({ node.id, skill ~= nil and skill.class == path.class }).toEqual({ node.id, true })
					end
				end
			end
		end
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
		T.expect(table.find(ice, "firebolt")).toBeNil() -- S142: Fire Bolt is fire only
		T.expect(table.find(ice, "blink") ~= nil).toBe(true)
		T.expect(table.find(ice, "fireball")).toBeNil()
		T.expect(table.find(ice, "elementalVortex") ~= nil).toBe(true) -- a path skill works in every pool
		T.expect(SkillPools.inPool("Mage", "fire", "meteor")).toBe(true)
		T.expect(SkillPools.inPool("Mage", "lightning", "meteor")).toBe(false)
		T.expect(SkillPools.inPool("Mage", "fire", "mightyStrike")).toBe(false)
		T.expect(SkillPools.inPool("Warrior", "onehand", "mightyStrike")).toBe(true) -- S143: the one-handed S1
		T.expect(SkillPools.inPool("Warrior", "twohand", "mightyStrike")).toBe(false)
		T.expect(SkillPools.inPool("Warrior", "twohand", "charge")).toBe(true) -- common
		T.expect(SkillPools.inPool("Hunter", "crossbow", "venomArrow")).toBe(true) -- S144: the Crossbow's S2
		T.expect(SkillPools.inPool("Hunter", "bow", "venomArrow")).toBe(false)
		T.expect(SkillPools.inPool("Hunter", "crossbow", "drive")).toBe(true) -- the Scout's capstone, every pool
		T.expect(SkillPools.valid("Mage", "ice")).toBe(true)
		T.expect(SkillPools.valid("Mage", "onehand")).toBe(false)
		T.expect(SkillPools.valid("Mage", 5)).toBe(false)
		T.expect(SkillPools.members("Mage", "nope")).toEqual({})
	end)
end)
