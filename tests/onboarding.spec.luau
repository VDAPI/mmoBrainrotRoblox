--!strict
-- S155b: the first minutes after S155: the first valuable drop (Logic/Tutorial.firstDrop, Data/Tutorial.FIRST_DROP),
-- the "I know the game" skip of a veteran account, the unlocks a level up announces (Logic/Unlocks) and the pace of the
-- first three levels (the city quests and five rabbits).
local Arena = require("../src/shared/Data/Arena")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local Config = require("../src/shared/Config")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local Quests = require("../src/shared/Data/Quests")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local SkillPools = require("../src/shared/Logic/SkillPools")
local T = require("./Test")
local Tutorial = require("../src/shared/Logic/Tutorial")
local TutorialData = require("../src/shared/Data/Tutorial")
local Unlocks = require("../src/shared/Logic/Unlocks")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local CLASSES = { "Warrior", "Hunter", "Mage", "Cleric" }

local function make(classId: string): any
	local n = 0
	return CharacterFactory.create(classId :: any, "Test", {
		newId = function()
			n += 1
			return `id{n}`
		end,
		now = 0,
	})
end

T.describe("Onboarding: the first valuable drop", function()
	T.it("a new character has it due; older saves only while the level reward still waits", function()
		T.expect(Tutorial.firstDropDue(Tutorial.sanitize(make("Warrior").tutorial))).toBe(true)
		-- a character of S155 below level 5 (no `drop` yet) still gets it, an older one does not
		T.expect(Tutorial.firstDropDue(Tutorial.sanitize({ step = 3, done = false, reward = false }))).toBe(true)
		T.expect(Tutorial.firstDropDue(Tutorial.sanitize({ step = 7, done = true, reward = true }))).toBe(false)
		T.expect(Tutorial.firstDropDue(Tutorial.sanitize(nil))).toBe(false)
		local given = Tutorial.withDrop(Tutorial.newState())
		T.expect(Tutorial.firstDropDue(given)).toBe(false)
		T.expect(Tutorial.firstDropDue(Tutorial.sanitize(given))).toBe(false)
		-- audit 2026-10-21: marked on pickup; while the bag lies on the ground no second one, a lost bag comes again
		local fresh = Tutorial.sanitize(make("Warrior").tutorial)
		T.expect(Tutorial.firstDropDue(fresh, true)).toBe(false)
		T.expect(Tutorial.firstDropDue(fresh, false)).toBe(true)
		T.expect(Tutorial.firstDropDue(given, false)).toBe(false)
		-- counting steps and skipping keep it
		T.expect(Tutorial.advance(given, "move").drop).toBe(true)
		T.expect(Tutorial.skip(given).drop).toBe(true)
	end)

	T.it("a Heroic, bound copy of the wielded weapon: the same kind, element and skill pool", function()
		T.expect(Rarities.get(TutorialData.FIRST_DROP.rarity).key).toBe("heroic")
		T.expect(Rarities.get(TutorialData.FIRST_DROP.rarity).announce).toBeNil()
		for _, classId in CLASSES do
			local char = make(classId)
			local weapon = char.equipment.weapon
			local item = Tutorial.firstDrop(classId, 2, weapon, Rng.new(7), "uid") :: any
			T.expect({ classId, item ~= nil }).toEqual({ classId, true })
			T.expect({ classId, item.id, item.rarity, item.bound }).toEqual({
				classId,
				weapon.id,
				TutorialData.FIRST_DROP.rarity,
				true,
			})
			T.expect({ classId, item.el }).toEqual({ classId, weapon.el })
			-- the pool of the skills does not change when it is equipped
			local after = table.clone(char.equipment)
			after.weapon = item
			T.expect({ classId, SkillPools.activePool({ class = classId, equipment = after }) }).toEqual({
				classId,
				SkillPools.activePool(char),
			})
			T.expect({ classId, #item.bonuses >= Rarities.get(item.rarity).bonusMin }).toEqual({ classId, true })
		end
	end)

	T.it("a Mage keeps the element of the wand in hand; no weapon falls back to the starting one", function()
		local char = make("Mage")
		local wand = table.clone(char.equipment.weapon)
		wand.el = "frost"
		local item = Tutorial.firstDrop("Mage", 1, wand, Rng.new(1), "u") :: any
		T.expect(item.el).toBe("frost")
		local bare = Tutorial.firstDrop("Warrior", 1, nil, Rng.new(1), "u") :: any
		T.expect(bare.id).toBe(Items.startingGear.Warrior[1])
	end)
end)

T.describe("Onboarding: veterans", function()
	T.it("an account with a character at the reward level knows the game", function()
		T.expect(Tutorial.veteran(nil)).toBe(false)
		T.expect(Tutorial.veteran({ ["1"] = { level = 1 } })).toBe(false)
		T.expect(Tutorial.veteran({ ["1"] = { level = 1 }, ["2"] = { level = TutorialData.REWARD_LEVEL } })).toBe(true)
		T.expect({ pl["tutorial.skipVeteran"] ~= nil, en["tutorial.skipVeteran"] ~= nil }).toEqual({ true, true })
	end)
end)

T.describe("Onboarding: unlocks on a level up", function()
	T.it("levels come from the systems; each entry has a text in both languages", function()
		local byId: { [string]: Unlocks.Entry } = {}
		for _, e in Unlocks.LIST do
			byId[e.id] = e
			T.expect({ e.id, pl[e.textKey] ~= nil, en[e.textKey] ~= nil }).toEqual({ e.id, true, true })
			T.expect({ e.id, e.level > 1 }).toEqual({ e.id, true })
		end
		T.expect(byId.mounts.level).toBe(Config.Mount.minLevel)
		T.expect(byId.arena.level).toBe(Arena.MIN_LEVEL)
	end)

	T.it("a level up names exactly the entries it crosses", function()
		local mounts = Config.Mount.minLevel
		local function ids(list: { Unlocks.Entry }): { [string]: boolean }
			local out = {}
			for _, e in list do
				out[e.id] = true
			end
			return out
		end
		T.expect(ids(Unlocks.crossed(mounts - 1, mounts)).mounts).toBe(true)
		T.expect(ids(Unlocks.crossed(mounts, mounts + 1)).mounts).toBeNil()
		T.expect(ids(Unlocks.crossed(1, 100)).mounts).toBe(true)
		T.expect(#Unlocks.crossed(5, 5)).toBe(0)
	end)
end)

T.describe("Onboarding: the pace of the first levels", function()
	-- The city quests (arrival, healer, smith, portal) and the first hunt with five rabbits of level 1-2 at level 1-2.
	T.it("level 2 in the city, level 3 by the end of the first hunt", function()
		local level, exp = 1, 0
		local function give(n: number)
			level, exp = Exp.applyExp(level, exp, n, Config.MaxLevel)
		end
		local byId: { [string]: any } = {}
		for _, q in Quests.Main.list do
			byId[q.id] = q
		end
		for _, id in { "arrival", "healer", "smith" } do
			give(byId[id].reward.exp)
		end
		T.expect(level).toBe(2)
		give(byId.portal.reward.exp)
		for _ = 1, 5 do
			give(Exp.monsterExp(1) * Exp.levelDiffMultiplier(level, 1))
		end
		give(byId.firstHunt.reward.exp)
		T.expect(level >= 3).toBe(true)
	end)
end)
