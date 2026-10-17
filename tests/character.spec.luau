--!strict
-- Character creation, account schema and migrations.
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local ClassLooks = require("../src/shared/Data/ClassLooks")
local Classes = require("../src/shared/Data/Classes")
local Config = require("../src/shared/Config")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")

local START_SKILL = { Warrior = "mightyStrike", Hunter = "aimedShot", Mage = "firebolt", Cleric = "holyStrike" }

local function ids()
	local n = 0
	return {
		newId = function(): string
			n += 1
			return `id{n}`
		end,
		now = 1000,
	}
end

T.describe("CharacterFactory", function()
	T.it("creates a level 1 character with class start stats", function()
		for _, classId in Classes.order do
			local character = CharacterFactory.create(classId, "Aria", ids())
			local class = Classes.get(classId) :: Classes.ClassDef
			T.expect(character.class).toBe(classId)
			T.expect(character.level).toBe(1)
			T.expect(character.exp).toBe(0)
			T.expect(character.statPoints).toBe(0)
			T.expect((character :: any).skills).toBeNil()
			T.expect((character :: any).skillPoints).toBeNil()
			T.expect(character.hotbar).toEqual({ ["1"] = START_SKILL[classId] })
			T.expect(character.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
			T.expect(character.buildSlot).toBe(1)
			T.expect(character.buildOther).toBeNil()
			T.expect(character.reworkNotice).toBe(false)
			T.expect(character.stats).toEqual(class.startStats)
			T.expect(character.stats == class.startStats).toBe(false) -- copied, not shared
		end
	end)

	T.it("starts with gold, the city, a cloth backpack, class gear and potions", function()
		local character = CharacterFactory.create("Mage", "Aria", ids())
		T.expect(character.gold).toBe(Config.StartingGold)
		T.expect(character.location.map).toBe(Config.StartingMap)
		T.expect(character.equipment.backpack.id).toBe("backpack_20")
		T.expect(character.equipment.backpack.n).toBe(1)
		T.expect(character.equipment.weapon.id).toBe("wand_1")
		T.expect(character.equipment.weapon.bound).toBe(true)
		T.expect(character.equipment.armor.id).toBe("armor_light_1")
		T.expect(character.inventory["1"].id).toBe("potion_hp_1")
		T.expect(character.inventory["1"].n).toBe(10)
		T.expect(character.potionBar.hp).toBe("potion_hp_1")
		T.expect(character.id).toBe("id1")
		T.expect(character.createdAt).toBe(1000)
		-- every item got its own uid
		local uids = {}
		for _, item in character.equipment do
			T.expect(uids[item.uid]).toBeNil()
			uids[item.uid] = true
		end
	end)

	T.it("schema 2 migration gives old characters their starting gear without replacing items", function()
		local old = CharacterFactory.create("Warrior", "Old", ids())
		old.equipment = { backpack = old.equipment.backpack }
		old.inventory = {
			["1"] = { uid = "keep", id = "ore_iron", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 3 },
		}
		old.potionBar = {}
		local data: any = AccountSchema.accountTemplate()
		data.schema = 1
		data.characters["1"] = old
		AccountSchema.migrate(data)
		T.expect(old.equipment.weapon.id).toBe("sword1h_1")
		T.expect(old.inventory["1"].uid).toBe("keep")
		T.expect(old.inventory["2"].id).toBe("potion_hp_1")
		T.expect(old.potionBar.hp).toBe("potion_hp_1")
	end)

	T.it("rejects unknown classes", function()
		T.expect(function()
			CharacterFactory.create("Bard" :: any, "Aria", ids())
		end).toThrow("unknown class")
	end)

	T.it("summarizes characters for the selection screen", function()
		local character = CharacterFactory.create("Hunter", "Kira", ids())
		character.level = 12
		T.expect(CharacterFactory.summary(character)).toEqual({
			name = "Kira",
			class = "Hunter",
			level = 12,
			map = "city",
		})
		local summaries = CharacterFactory.summaries({ ["2"] = character })
		T.expect(summaries["2"].name).toBe("Kira")
	end)

	T.it("validates slot numbers", function()
		T.expect(CharacterFactory.slotKey(1)).toBe("1")
		T.expect(CharacterFactory.slotKey(Config.MaxCharacters)).toBe(tostring(Config.MaxCharacters))
		T.expect(CharacterFactory.slotKey(0)).toBeNil()
		T.expect(CharacterFactory.slotKey(Config.MaxCharacters + 1)).toBeNil()
		T.expect(CharacterFactory.slotKey(1.5)).toBeNil()
		T.expect(CharacterFactory.slotKey("1")).toBeNil()
	end)
end)

T.describe("AccountSchema", function()
	T.it("template is at the current schema", function()
		local data = AccountSchema.accountTemplate()
		T.expect(data.schema).toBe(AccountSchema.CURRENT)
		T.expect(data.characters).toEqual({})
		T.expect(data.settings.lang).toBe("")
	end)

	T.it("templates are fresh tables every call", function()
		local a, b = AccountSchema.accountTemplate(), AccountSchema.accountTemplate()
		T.expect(a.settings == b.settings).toBe(false)
	end)

	T.it("migrate reconciles missing fields on accounts and characters", function()
		local data: any = {
			schema = AccountSchema.CURRENT,
			characters = { ["1"] = { id = "x", name = "Old", class = "Warrior", level = 7 } },
			dragonShards = 42,
		}
		AccountSchema.migrate(data)
		T.expect(data.dragonShards).toBe(42)
		T.expect(data.settings.volume).toBe(0.8)
		T.expect(data.characters["1"].level).toBe(7)
		T.expect(data.characters["1"].gold).toBe(0)
		T.expect(data.characters["1"].quests.daily.list).toEqual({})
	end)

	T.it("S121: vip and outfits come from the template without a migration, nothing saved is overwritten", function()
		T.expect(AccountSchema.CURRENT).toBe(11) -- S132: 9 = class outfits; S134g: 10 = item effects; S134k: 11 = contracts
		local template = AccountSchema.accountTemplate()
		T.expect(template.vip).toEqual({ shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = {} })
		T.expect(template.outfits).toEqual({})
		local old: any = { schema = AccountSchema.CURRENT, characters = {}, dragonShards = 5 }
		AccountSchema.migrate(old)
		T.expect(old.vip).toEqual({ shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = {} })
		T.expect(old.outfits).toEqual({})
		local look = { equipped = { aura = "aura_gold" }, pet = "pet_wolf" }
		local saved: any = {
			schema = AccountSchema.CURRENT,
			characters = {},
			vip = { shardDay = 20000, respawnDay = 0, respawnN = 0, recallAt = 0, months = { ["202611"] = true } },
			outfits = { look },
		}
		AccountSchema.migrate(saved)
		T.expect(saved.vip.months).toEqual({ ["202611"] = true })
		T.expect(saved.vip.shardDay).toBe(20000)
		T.expect(saved.outfits).toEqual({ { equipped = { aura = "aura_gold" }, pet = "pet_wolf" } })
		T.expect(CharacterFactory.slotKey(5)).toBe("5")
		T.expect(CharacterFactory.slotKey(6)).toBeNil()
	end)

	T.it(
		"S133: social lists, whisper and alert settings, the mail counter and the hint flag come from reconcile",
		function()
			T.expect(AccountSchema.CURRENT).toBe(11) -- S133: no migration; S134g: 10 = item effects; S134k: 11 = contracts
			local friend = { name = "Borys", class = "Hunter", since = 100 }
			local old: any = {
				schema = AccountSchema.CURRENT,
				characters = { ["1"] = { id = "x", name = "Old", class = "Warrior", level = 12 } },
				settings = { lang = "pl", volume = 0.5 },
			}
			AccountSchema.migrate(old)
			T.expect(old.social).toEqual({ friends = {}, ignored = {} })
			T.expect(old.settings.whispers).toBe("all")
			T.expect(old.settings.friendAlerts).toBe(true)
			T.expect(old.settings.volume).toBe(0.5)
			T.expect(old.characters["1"].mailSent).toEqual({ day = 0, n = 0 })
			T.expect(old.characters["1"].playerMenuHint).toBe(false)
			local saved: any = {
				schema = AccountSchema.CURRENT,
				characters = {},
				social = { friends = { ["42"] = friend }, ignored = {} },
			}
			AccountSchema.migrate(saved)
			T.expect(saved.social.friends["42"]).toEqual(friend)
		end
	)

	T.it("S98: old characters get the weekly and contract branches, side quests untouched", function()
		local side = { active = { side_granary = { progress = { 1 }, used = {} } }, done = { side_fence = true } }
		local data: any = {
			schema = AccountSchema.CURRENT,
			characters = {
				["1"] = {
					id = "x",
					name = "Old",
					class = "Warrior",
					level = 30,
					quests = { mainDone = 3, daily = { day = 1, list = {}, rerolls = 0 }, side = side },
				},
			},
		}
		AccountSchema.migrate(data)
		local quests = data.characters["1"].quests
		T.expect(quests.weekly).toEqual({ week = 0, list = {}, rerolls = 0 })
		-- S134k: the shape of migration 11 (several active contracts, marks)
		T.expect(quests.contract).toEqual({
			done = 0,
			extra = {},
			active = {},
			marks = 0,
			auto = false,
			shopWeek = { week = 0, counts = {} },
		})
		T.expect(quests.side).toEqual({
			active = { side_granary = { progress = { 1 }, used = {} } },
			done = { side_fence = true },
		})
		T.expect(quests.mainDone).toBe(3)
	end)

	T.it("S101b: dialogue answers and the comments switch come from the templates, without a migration", function()
		T.expect(AccountSchema.CURRENT).toBe(11) -- S102: 8 = story progress (mainLast), S132: 9 = class outfits; S134g: 10 = item effects; S134k: 11 = contracts
		T.expect(AccountSchema.characterTemplate().quests.said).toEqual({})
		-- S102: cutscenes start empty, the story anchor has no default
		T.expect(AccountSchema.characterTemplate().quests.scenes).toEqual({})
		T.expect(AccountSchema.characterTemplate().quests.mainLast).toBeNil()
		T.expect(AccountSchema.characterTemplate().quests.mainDone).toBe(0)
		T.expect(AccountSchema.accountTemplate().settings.barks).toBe(true)
		local old: any = AccountSchema.accountTemplate()
		old.settings.barks = nil
		old.characters["1"] = AccountSchema.characterTemplate()
		old.characters["1"].quests.said = nil
		T.expect(AccountSchema.migrate(old)).toEqual({})
		T.expect(old.settings.barks).toBe(true)
		T.expect(old.characters["1"].quests.said).toEqual({})
		-- an answer and a switched-off setting stay
		local kept: any = AccountSchema.accountTemplate()
		kept.settings.barks = false
		kept.characters["1"] = AccountSchema.characterTemplate()
		kept.characters["1"].quests.said = { side_bears = "quiet" }
		AccountSchema.migrate(kept)
		T.expect(kept.settings.barks).toBe(false)
		T.expect(kept.characters["1"].quests.said).toEqual({ side_bears = "quiet" })
	end)

	T.it("S129: the Blood Moon state comes from the template, without a migration", function()
		local fresh = AccountSchema.characterTemplate()
		T.expect(fresh.bloodMoon).toEqual({ id = "", points = 0, kills = {}, regions = {}, at = 0, paid = false })
		local old: any = AccountSchema.accountTemplate()
		old.characters["1"] = AccountSchema.characterTemplate()
		old.characters["1"].bloodMoon = nil
		T.expect(AccountSchema.migrate(old)).toEqual({})
		T.expect(old.characters["1"].bloodMoon.id).toBe("")
		T.expect(old.characters["1"].bloodMoon.paid).toBe(false)
		local kept: any = AccountSchema.accountTemplate()
		kept.characters["1"] = AccountSchema.characterTemplate()
		kept.characters["1"].bloodMoon =
			{ id = "20261013", points = 25, kills = { ["5_1"] = 2 }, regions = { ashen = 25 }, at = 9, paid = true }
		AccountSchema.migrate(kept)
		T.expect(kept.characters["1"].bloodMoon.points).toBe(25)
		T.expect(kept.characters["1"].bloodMoon.kills).toEqual({ ["5_1"] = 2 })
	end)

	T.it("S100: the login streak comes from the template, without a migration", function()
		T.expect(AccountSchema.accountTemplate().login).toEqual({ day = 0, last = 0 })
		local old: any = AccountSchema.accountTemplate()
		old.login = nil
		local applied = AccountSchema.migrate(old)
		T.expect(applied).toEqual({})
		T.expect(old.schema).toBe(AccountSchema.CURRENT)
		T.expect(old.login).toEqual({ day = 0, last = 0 })
		local kept: any = AccountSchema.accountTemplate()
		kept.login = { day = 4, last = 123 }
		AccountSchema.migrate(kept)
		T.expect(kept.login).toEqual({ day = 4, last = 123 })
		-- a save of schema 6 (before S99) runs only migration 7 and gets the field too
		local older: any = AccountSchema.accountTemplate()
		older.schema = 6
		older.login = nil
		T.expect(AccountSchema.migrate(older)).toEqual({ 7, 8, 9, 10, 11 }) -- S134g: 10 = item effects; S134k: 11 = contracts
		T.expect(older.login).toEqual({ day = 0, last = 0 })
	end)

	T.it("template keeps an empty hotbar (reconcile)", function()
		T.expect(AccountSchema.characterTemplate().hotbar).toEqual({})
		local mage = CharacterFactory.create("Mage", "Empty", ids())
		mage.hotbar = {}
		local data: any = AccountSchema.accountTemplate()
		data.characters["1"] = mage
		AccountSchema.migrate(data)
		T.expect(mage.hotbar).toEqual({})
	end)

	T.it("migrate runs pending migrations in order", function()
		local migrations = AccountSchema._migrations
		local saved = AccountSchema.CURRENT
		local order = {}
		AccountSchema.CURRENT = saved + 2
		migrations[saved + 1] = function(d)
			table.insert(order, saved + 1)
			d.marker = "a"
		end
		migrations[saved + 2] = function(d)
			table.insert(order, saved + 2)
			d.marker ..= "b"
		end
		local data: any = AccountSchema.accountTemplate()
		data.schema = saved
		local ok, err = pcall(AccountSchema.migrate, data)
		AccountSchema.CURRENT = saved
		migrations[saved + 1] = nil
		migrations[saved + 2] = nil
		assert(ok, err)
		T.expect(order).toEqual({ saved + 1, saved + 2 })
		T.expect(data.marker).toBe("ab")
		T.expect(data.schema).toBe(saved + 2)
	end)
end)

-- Saves of schema 5: a character from the factory with the new fields cleared and the old ones put back.
local function oldSave(classId: string, level: number, extra: { [string]: any }?): (any, any)
	local character: any = CharacterFactory.create(classId :: any, "Old", ids())
	character.level = level
	character.path = nil
	character.buildSlot = nil
	character.reworkNotice = nil
	character.skills = {}
	character.skillPoints = 0
	for key, value in extra or {} do
		character[key] = value
	end
	local data: any = AccountSchema.accountTemplate()
	data.schema = 5
	data.characters["1"] = character
	return data, character
end

local function newId(): string
	return "x"
end

T.describe("Migration 6 (S56)", function()
	T.it("level 1 Warrior", function()
		local data, c = oldSave("Warrior", 1, { skills = { mightyStrike = 1 }, skillPoints = 0 })
		T.expect(AccountSchema.migrate(data)).toEqual({ 6, 7, 8, 9, 10, 11 }) -- S99: 7 = hunting contracts, S102: 8 = story progress, S132: 9, S134g: 10, S134k: 11
		T.expect(data.schema).toBe(AccountSchema.CURRENT)
		T.expect(c.skills).toBeNil()
		T.expect(c.skillPoints).toBeNil()
		T.expect(c.stats).toEqual((Classes.get("Warrior") :: any).startStats)
		T.expect(c.statPoints).toBe(0)
		T.expect(c.hotbar).toEqual({ ["1"] = "mightyStrike" })
		T.expect(c.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
		T.expect(c.buildSlot).toBe(1)
		T.expect(c.buildOther).toBeNil()
		T.expect(c.reworkNotice).toBe(true)
	end)

	T.it("level 20 Hunter gets every stat point back and a rebuilt bar", function()
		local start = (Classes.get("Hunter") :: any).startStats
		local stats = table.clone(start)
		stats.dex += 95
		local data, c = oldSave("Hunter", 20, {
			stats = stats,
			statPoints = 0,
			skillPoints = 3,
			hotbar = { ["1"] = "aimedShot", ["5"] = "frostTrap" },
		})
		AccountSchema.migrate(data)
		T.expect(c.stats).toEqual(start)
		T.expect(c.statPoints).toBe(95)
		T.expect(c.hotbar).toEqual({
			["1"] = "aimedShot",
			["2"] = "doubleShot",
			["3"] = "disengage",
			["4"] = "arrowRain",
			["5"] = "venomArrow",
		})
	end)

	T.it("level 100 Cleric", function()
		local data, c = oldSave("Cleric", 100)
		AccountSchema.migrate(data)
		T.expect(c.statPoints).toBe(495)
		-- S71: the Cleric has paths, so the new bar holds only the 6 base actives (path skills come with their nodes)
		T.expect(c.hotbar).toEqual({
			["1"] = "holyStrike",
			["2"] = "heal",
			["3"] = "radiance",
			["4"] = "circleOfLight",
			["5"] = "shieldOfFaith",
			["6"] = "judgement",
		})
	end)

	T.it("odd saves", function()
		local migration = AccountSchema._migrations[6]
		-- not a table
		local data: any = { characters = { ["1"] = "oops" } }
		migration(data, newId)
		T.expect(data.characters["1"]).toBe("oops")
		-- no class: counted as the template's Warrior
		local noClass: any = { level = 12, stats = { str = 1, dex = 1, int = 1, vit = 1 }, statPoints = 3 }
		migration({ characters = { ["1"] = noClass } }, newId)
		T.expect(noClass.stats).toEqual((Classes.get("Warrior") :: any).startStats)
		T.expect(noClass.statPoints).toBe(55)
		T.expect(noClass.hotbar).toEqual({
			["1"] = "mightyStrike",
			["2"] = "charge",
			["3"] = "bladeWhirl",
			["4"] = "taunt",
		})
		-- unknown class: stats kept, empty bar, new fields
		local bard: any = { class = "Bard", level = 30, stats = { str = 9, dex = 9, int = 9, vit = 9 }, statPoints = 7 }
		migration({ characters = { ["1"] = bard } }, newId)
		T.expect(bard.stats).toEqual({ str = 9, dex = 9, int = 9, vit = 9 })
		T.expect(bard.statPoints).toBe(7)
		T.expect(bard.hotbar).toEqual({})
		T.expect(bard.path).toEqual({ nodes = {}, bp = {}, freeUsed = false })
		T.expect(bard.buildSlot).toBe(1)
		T.expect(bard.reworkNotice).toBe(true)
		-- broken levels
		local abc: any = { class = "Mage", level = "abc" }
		migration({ characters = { ["1"] = abc } }, newId)
		T.expect(abc.statPoints).toBe(0)
		local high: any = { class = "Mage", level = 250 }
		migration({ characters = { ["1"] = high } }, newId)
		T.expect(high.statPoints).toBe(495)
	end)

	T.it("is idempotent", function()
		local data, c = oldSave("Mage", 40)
		AccountSchema.migrate(data)
		local copy = TableUtil.deepCopy(c)
		AccountSchema._migrations[6](data, newId)
		T.expect(data.characters["1"]).toEqual(copy)
	end)
end)

-- S132 (DESIGN-17 §9a): the creator's look and migration 9 (one outfit per class).
T.describe("Class looks: creation and migration 9 (S132)", function()
	local DEFAULT = {
		face = ClassLooks.DEFAULT_LOOK.face,
		skin = ClassLooks.DEFAULT_LOOK.skin,
		hair = ClassLooks.DEFAULT_LOOK.hair,
	}

	T.it("a new character keeps the creator's look and has one free change", function()
		local look = { face = "face_stern", skin = "skin_7", hair = "hair_braid_grey" }
		local c = CharacterFactory.create("Mage", "Imie", ids(), look)
		T.expect(c.look).toEqual(look)
		T.expect(c.look == look).toBe(false)
		T.expect(c.lookFree).toBe(true)
		T.expect(CharacterFactory.create("Mage", "Imie", ids()).look).toEqual(DEFAULT)
		local odd = CharacterFactory.create("Hunter", "Imie", ids(), { face = "nope", skin = "skin_2", hair = 5 })
		T.expect(odd.look).toEqual({ face = DEFAULT.face, skin = "skin_2", hair = DEFAULT.hair })
	end)

	local function account(cosmetics: any): any
		return {
			schema = 8,
			cosmetics = cosmetics,
			characters = { ["1"] = { id = "a", name = "Old", class = "Warrior", level = 30 } },
		}
	end

	T.it("moves a known outfit to every class, drops an unknown one, keeps the rest", function()
		local data = account({
			owned = { outfit_ranger = true },
			equipped = { outfit = "outfit_ranger", aura = "aura_gold", dye = "dye_crimson" },
		})
		T.expect(AccountSchema.migrate(data)).toEqual({ 9, 10, 11 }) -- S134g: 10 = item effects; S134k: 11 = contracts
		local want = {}
		for _, classId in Classes.order do
			want[classId] = "outfit_ranger"
		end
		T.expect(data.cosmetics.classOutfits).toEqual(want)
		T.expect(data.cosmetics.equipped).toEqual({ aura = "aura_gold", dye = "dye_crimson" })
		T.expect(data.characters["1"].look).toEqual(DEFAULT)
		T.expect(data.characters["1"].lookFree).toBe(true)
		T.expect(data.settings.robloxAvatar).toBe(false)
		-- idempotent: the migration again changes nothing
		local copy = TableUtil.deepCopy(data)
		AccountSchema._migrations[9](data, function(): string
			return "x"
		end)
		T.expect(data).toEqual(copy)

		local unknown = account({ owned = {}, equipped = { outfit = "outfit_gone" } })
		AccountSchema.migrate(unknown)
		T.expect(unknown.cosmetics.classOutfits).toEqual({})
		T.expect(unknown.cosmetics.equipped.outfit).toBeNil()
	end)

	T.it("broken cosmetics become the template, saved looks stay", function()
		local broken = account("broken")
		broken.outfits = { { equipped = { outfit = "outfit_ranger" } } }
		AccountSchema.migrate(broken)
		T.expect(broken.cosmetics).toEqual({ owned = {}, equipped = {}, classOutfits = {} })
		T.expect(broken.outfits).toEqual({ { equipped = { outfit = "outfit_ranger" } } })
		local noEquipped = account({ owned = {} })
		AccountSchema.migrate(noEquipped)
		T.expect(noEquipped.cosmetics).toEqual({ owned = {}, equipped = {}, classOutfits = {} })
	end)
end)

return nil
