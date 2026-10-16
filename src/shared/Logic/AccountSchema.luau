--!strict
-- Persistent data templates and migrations (pure). DataService feeds these to ProfileStore.
-- When the shape changes: bump CURRENT, add MIGRATIONS[CURRENT], extend the templates.

local ArenaRules = require("./ArenaRules")
local CharacterLook = require("./CharacterLook")
local ClassLooks = require("../Data/ClassLooks")
local Classes = require("../Data/Classes")
local Cosmetics = require("../Data/Cosmetics")
local Config = require("../Config")
local Contracts = require("../Data/Quests/Contracts")
local Exp = require("./Exp")
local ItemEffects = require("./ItemEffects")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Skills = require("./Skills")
local Time = require("./Time")
local Types = require("../Types")
local StarterGear = require("./StarterGear")
local StoryProgress = require("./StoryProgress")
local TableUtil = require("../Util/TableUtil")

type AccountData = Types.AccountData
type CharacterData = Types.CharacterData

local AccountSchema = {}

AccountSchema.CURRENT = 10

function AccountSchema.accountTemplate(): AccountData
	return {
		schema = AccountSchema.CURRENT,
		characters = {},
		lastCharacter = nil,
		dragonShards = 0,
		deposit = { size = 60, items = {} },
		-- S132: classOutfits = the worn outfit per class (migration 9 moved equipped.outfit here)
		cosmetics = { owned = {}, equipped = {}, classOutfits = {} },
		pets = { owned = {}, equipped = nil },
		settings = {
			lang = "",
			volume = 0.8,
			dmgNumbers = true,
			bindConfirm = true,
			quickCast = false,
			musicVolume = 0.6,
			ambientVolume = 0.7,
			quality = "high",
			minimapRotate = false,
			cameraSens = 1,
			shake = 1,
			sellConfirm = true,
			autoTarget = true,
			groupRings = true,
			betterItem = true,
			lootHideBelow = 0,
			lootAutoFrom = 0,
			decor = "mid",
			keys = {},
			devPins = {},
			mapCloseOnWalk = true,
			barks = true, -- S101b: NPC comments during quests (reconcile adds it to old accounts)
			robloxAvatar = false, -- S132: "Show my Roblox avatar" (reconcile adds it to old accounts)
			whispers = "all", -- S133: whispers from everyone or only friends and guild mates (reconcile)
			friendAlerts = true, -- S133: "<name> is in the game" toast (reconcile)
			lowHpWarn = true, -- S134f: red vignette and heartbeat below 25 % HP (reconcile)
			fightCard = true, -- S134f: the small after-fight card for Elite II and Invasion (reconcile)
		},
		purchases = {},
		dailyLimits = { day = 0, protectScrolls = 0 },
		-- S120: premium shop counters per entry (Logic/Premium.limitsOf); dailyLimits above is the pre-S120 counter, read
		-- once, never written
		shopLimits = { day = 0, week = 0, daily = {}, weekly = {} },
		-- S100: login reward streak (Logic/LoginReward): last claimed day 0..7 and its UTC day
		login = { day = 0, last = 0 },
		-- S121: VIP state (Logic/Vip): UTC day of the last daily shards, free respawns used on respawnDay,
		-- last free recall (Clock seconds), months whose VIP cosmetic was given ("YYYYMM" -> true).
		vip = { shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = {} },
		-- S121: saved looks (Garderoba+): { equipped = { [kind] = id }, pet = id? }, index 1..Products.OUTFITS_PLUS.
		outfits = {},
		-- S122: Cloak of Luring (Logic/Lure): real-time end (os.time) and the switch; no migration (reconcile)
		lure = { untilTs = 0, on = false },
		-- S134d: Auto Potions (Logic/AutoPotion) and the Auto Hunt time bank (Logic/AutoGrind); no migration (reconcile)
		autoPotion = {
			untilTs = 0,
			permanent = false,
			on = false,
			hp = Config.AutoPotion.hp,
			res = Config.AutoPotion.res,
		},
		autoGrind = { bank = 0, day = 0, used = 0 },
		-- S123: starter packs bought once per account; passes granted by a pack, honoured by HasPass (no migration)
		packs = {},
		grantedPasses = {},
		stats = { createdAt = 0, playtime = 0 },
		redeemed = {},
		-- S133: friends and ignored players (Logic/Social), keys tostring(userId); reconcile adds it, no migration
		social = { friends = {}, ignored = {} },
		legendRework = false, -- S134g: migration 10 converted a Legendary / Mythic (one toast, EquipmentService clears it)
	}
end

-- Default values for every character field; used to reconcile characters saved by older versions.
function AccountSchema.characterTemplate(): CharacterData
	return {
		id = "",
		name = "",
		class = "Warrior",
		level = 1,
		exp = 0,
		stats = { str = 0, dex = 0, int = 0, vit = 0 },
		statPoints = 0,
		-- stays empty: reconcile would copy a template skill into every empty slot 1; CharacterFactory fills it
		hotbar = {},
		path = { nodes = {}, bp = {}, freeUsed = false },
		buildSlot = 1,
		reworkNotice = false,
		potionBar = {},
		equipment = {},
		inventory = {},
		gold = 0,
		location = { map = Config.StartingMap, x = 0, y = 0, z = 0 },
		hp = 0,
		mana = 0,
		energy = 0,
		blessing = nil,
		bossRuns = {},
		bossPity = {},
		alchemy = {},
		quests = {
			main = nil,
			mainDone = 0,
			daily = { day = 0, list = {}, rerolls = 0 },
			weekly = { week = 0, list = {}, rerolls = 0 }, -- S98 (reconcile adds it to old characters)
			contract = { done = 0 }, -- S98; S99: hunting contracts (Logic/Contracts), migration 7
			side = { active = {}, done = {} },
			said = {}, -- S101b: dialogue answers (reconcile adds it to old characters, no migration)
			scenes = {}, -- S102: story cutscenes (false = queued, true = watched); mainLast has no default (nil)
		},
		guildId = nil,
		-- S132 (DESIGN-17 §9a): the creator's face, skin and hair; every character (old ones through reconcile, new ones
		-- from CharacterFactory) has one free look change
		look = {
			face = ClassLooks.DEFAULT_LOOK.face,
			skin = ClassLooks.DEFAULT_LOOK.skin,
			hair = ClassLooks.DEFAULT_LOOK.hair,
		},
		lookFree = true,
		reached100At = nil, -- S124: set by LevelService at Config.MaxLevel (no migration)
		lbHidden = nil, -- S124: /lb hide (no migration)
		expWeek = { week = 0, exp = 0, b = 0 }, -- S125: weekly EXP ranking (no migration, reconcile)
		timedTitles = {}, -- S125: timed titles, title id -> until (no migration, reconcile)
		-- S129: the last Blood Moon (Logic/BloodMoon.newState); no migration, reconcile adds it to older characters
		bloodMoon = { id = "", points = 0, kills = {}, regions = {}, at = 0, paid = false },
		-- S130: the Champion's Tournament (Logic/Tourney); no migration, reconcile adds it to older characters
		tourney = { played = 0, won = 0, best = 0 },
		auctions = {},
		guideDone = true, -- existing characters skip the guide; CharacterFactory sets false for new ones
		playerMenuHint = false, -- S133: the one-time "Actions" hint (reconcile: old characters see it once too)
		mailSent = { day = 0, n = 0 }, -- S133: letters to players today (Logic/Social.countSent)
		pvpEnabled = false,
		elixirs = {},
		-- S122: Elixir of Wholeness counter (Logic/FullElixir); no migration (reconcile)
		fullElixir = { day = 0, used = 0, readyAt = 0 },
		pvp = { kills = 0, deaths = 0, duelsWon = 0, duelsLost = 0 },
		-- S126: the ranked arena (Data/Arena.ELO.start); no migration, reconcile adds it to older characters
		arena = ArenaRules.emptyState(),
		visitedMaps = { [Config.StartingMap] = true },
		mapMarks = {},
		-- S96: no migration; reconcile adds owned = {} and riding = false to older characters
		mounts = { owned = {}, active = nil, riding = false },
		createdAt = 0,
		playtime = 0,
	}
end

-- schema N -> N+1 upgrade functions. MIGRATIONS[2] upgrades data saved with schema 1, etc.
-- `newId` creates item uids (GUIDs on the server, counters in tests).
local MIGRATIONS: { [number]: (data: any, newId: () -> string) -> () } = {}

-- 2 (S04): items exist now; give characters from S01–S03 their starting gear and potions.
MIGRATIONS[2] = function(data, newId)
	for _, character in data.characters do
		TableUtil.reconcile(character, AccountSchema.characterTemplate())
		StarterGear.apply(character, newId)
	end
end

-- 3 (S25): own map marks on every character (reconcile would add the empty list too; explicit for clarity and
-- so a broken value from an old test build becomes a list).
MIGRATIONS[3] = function(data, _newId)
	for _, character in data.characters do
		if type(character) == "table" and type(character.mapMarks) ~= "table" then
			character.mapMarks = {}
		end
	end
end

-- 4 (S27): side quests. Reconcile adds `quests.side` too; explicit so a broken value becomes empty tables.
MIGRATIONS[4] = function(data, _newId)
	for _, character in data.characters do
		if type(character) == "table" and type(character.quests) == "table" then
			local side = character.quests.side
			if type(side) ~= "table" then
				character.quests.side = { active = {}, done = {} }
			else
				if type(side.active) ~= "table" then
					side.active = {}
				end
				if type(side.done) ~= "table" then
					side.done = {}
				end
			end
		end
	end
end

-- Clock for migrations that depend on the day (tests may replace it).
AccountSchema.now = function(): number
	return os.time()
end

local function upgradeItems(list: any)
	if type(list) ~= "table" then
		return
	end
	for _, item in list do
		if type(item) == "table" and type(item.id) == "string" then
			Rarities.upgradeItem(item, Items.get(item.id))
		end
	end
end

-- Legacy rarity setting (0 = off) -> the new ladder.
local function upgradeSetting(value: any): number
	local n = math.floor(tonumber(value) or 0)
	if n <= 0 then
		return 0
	end
	return Rarities.fromLegacy[n] or Rarities.MAX
end

-- 5 (S30): the new rarity ladder (Data/Rarities.fromLegacy) on every saved item (equipment, inventory, side
-- quest reward choices, deposit), the loot log and the loot filter settings; `bossLockouts` (one kill per day)
-- becomes `bossRuns` (today's lockout = the daily limit used up), and empty `bossPity`.
MIGRATIONS[5] = function(data, _newId)
	local today = Time.dayNumber(AccountSchema.now())
	for _, character in data.characters do
		if type(character) ~= "table" then
			continue
		end
		upgradeItems(character.equipment)
		upgradeItems(character.inventory)
		local quests = character.quests
		if type(quests) == "table" and type(quests.side) == "table" and type(quests.side.active) == "table" then
			for _, entry in quests.side.active do
				if type(entry) == "table" then
					upgradeItems(entry.choice)
				end
			end
		end
		if type(character.lootLog) == "table" then
			for _, entry in character.lootLog do
				if type(entry) == "table" then
					entry.rarity = Rarities.fromLegacy[tonumber(entry.rarity) or 1] or Rarities.COMMON
				end
			end
		end
		local runs = {}
		if type(character.bossLockouts) == "table" then
			for bossId, day in character.bossLockouts do
				local lockedDay = tonumber(day)
				if type(bossId) == "string" and lockedDay ~= nil and lockedDay >= today then
					runs[bossId] = { day = today, n = Config.Boss.dailyRuns }
				end
			end
		end
		character.bossLockouts = nil
		if type(character.bossRuns) ~= "table" then
			character.bossRuns = runs
		end
		if type(character.bossPity) ~= "table" then
			character.bossPity = {}
		end
	end
	if type(data.deposit) == "table" then
		upgradeItems(data.deposit.items)
	end
	if type(data.settings) == "table" then
		data.settings.lootHideBelow = upgradeSetting(data.settings.lootHideBelow)
		data.settings.lootAutoFrom = upgradeSetting(data.settings.lootAutoFrom)
	end
end

-- 6 (S56, ROZWOJ 5): ranks come from the character level and skill points are gone. Every character drops
-- `skills` / `skillPoints`, gets the class start stats back with every stat point to spend again
-- (5 x (level - 1)), an empty path state (S57), build slot 1, a hotbar rebuilt from the actives unlocked at
-- its level and the one-time notice. Idempotent.
MIGRATIONS[6] = function(data, _newId)
	if type(data.characters) ~= "table" then
		return
	end
	for _, character in data.characters do
		if type(character) ~= "table" then
			continue
		end
		character.skills = nil
		character.skillPoints = nil
		local level = math.clamp(math.floor(tonumber(character.level) or 1), 1, Config.MaxLevel)
		-- a save without a class reconciles to the template's "Warrior" right after the migrations
		local classId = if type(character.class) == "string" then character.class else "Warrior"
		local class = Classes.get(classId)
		if class then
			character.stats = table.clone(class.startStats)
			character.statPoints = Exp.pointsForLevels(1, level)
			character.hotbar = Skills.startHotbar(classId, level)
		else
			character.hotbar = {} -- unknown class: stats untouched, nothing on the bar
		end
		character.path = { nodes = {}, bp = {}, freeUsed = false }
		character.buildSlot = 1
		character.buildOther = nil
		character.reworkNotice = true
	end
end

-- 7 (S99): hunting contracts (DESIGN-15 §3.3): existing characters skip the contracts far below their level, without
-- rewards (done = max(done, level - 3)); new characters start at contract 1. Idempotent.
MIGRATIONS[7] = function(data, _newId)
	if type(data.characters) ~= "table" then
		return
	end
	for _, character in data.characters do
		if type(character) ~= "table" or type(character.quests) ~= "table" then
			-- no quests: the reconcile after the migrations adds the template's { done = 0 }
			continue
		end
		local contract = character.quests.contract
		if type(contract) ~= "table" then
			contract = { done = 0 }
			character.quests.contract = contract
		end
		local level = math.clamp(math.floor(tonumber(character.level) or 1), 1, Config.MaxLevel)
		local done = math.clamp(
			math.max(math.floor(tonumber(contract.done) or 0), level - Config.Quest.contractBacklog),
			0,
			Contracts.MAX_LEVEL
		)
		contract.done = done
		local active = contract.active
		if type(active) ~= "table" or active.level ~= done + 1 then
			contract.active = nil
		end
	end
end

-- 8 (S102, docs/FABULA.md §2.1): story insertions. mainDone counted the 32 quests of LEGACY_ORDER; mainLast = the id of
-- the last one handed in, so Logic/StoryProgress can recount mainDone in the new Main.list (inserted quests before that
-- point count as done, without rewards). Idempotent.
MIGRATIONS[8] = function(data, _newId)
	if type(data.characters) ~= "table" then
		return
	end
	for _, character in data.characters do
		if type(character) ~= "table" or type(character.quests) ~= "table" then
			continue
		end
		local quests = character.quests
		if type(quests.mainLast) ~= "string" then
			quests.mainLast = StoryProgress.legacyId(quests.mainDone)
		end
		if type(quests.scenes) ~= "table" then
			quests.scenes = {}
		end
		if type(quests.said) ~= "table" then
			quests.said = {}
		end
		if type(quests.main) ~= "table" then
			quests.main = nil
		elseif quests.main.used ~= nil and type(quests.main.used) ~= "table" then
			quests.main.used = nil
		end
	end
end

-- 9 (S132, DESIGN-17 §9a): the account-wide outfit becomes one outfit per class. A known outfit in
-- cosmetics.equipped.outfit goes to cosmetics.classOutfits[class] for every class of Data/Classes that may wear it,
-- then equipped.outfit is removed (an unknown id is dropped). Saved looks (account.outfits) stay: Logic/Premium.applySet
-- reads their outfit. Idempotent.
MIGRATIONS[9] = function(data, _newId)
	local cosmetics = data.cosmetics
	if type(cosmetics) ~= "table" then
		-- a broken value: reconcile keeps anything that is not nil, so the template goes in here
		data.cosmetics = { owned = {}, equipped = {}, classOutfits = {} }
		return
	end
	if type(cosmetics.classOutfits) ~= "table" then
		cosmetics.classOutfits = {}
	end
	local equipped = cosmetics.equipped
	if type(equipped) ~= "table" then
		return
	end
	local id = equipped.outfit
	local def = if type(id) == "string" then Cosmetics.get(id) else nil
	if def then
		for _, classId in Classes.order do
			if CharacterLook.allowed(def, classId) and cosmetics.classOutfits[classId] == nil then
				cosmetics.classOutfits[classId] = def.id
			end
		end
	end
	equipped.outfit = nil
end

-- S134g: Logic/ItemEffects.migrateItem on every item of a list (type-safe); true when any changed.
local function legendItems(list: any, classHint: string?): boolean
	if type(list) ~= "table" then
		return false
	end
	local changed = false
	for _, item in list do
		if type(item) == "table" and type(item.id) == "string" then
			if ItemEffects.migrateItem(item, Items.get(item.id), classHint) then
				changed = true
			end
		end
	end
	return changed
end

-- 10 (S134g, docs/STATY.md 12): Legendary and Mythic items carry skill effects instead of the legendary / mythic lines.
-- Every Legendary / Mythic of every character (equipment, backpack, side quest reward choices) and of the deposit
-- loses those lines, keeps its regular lines and gets its effects (Logic/ItemEffects.migrateItem: seed from the uid,
-- the character's class when the item fits it). Rarities.RV stays 2. A converted item sets account.legendRework (the
-- one-time toast). Idempotent.
MIGRATIONS[10] = function(data, _newId)
	local changed = false
	if type(data.characters) == "table" then
		for _, character in data.characters do
			if type(character) ~= "table" then
				continue
			end
			local classId = if type(character.class) == "string" then character.class else nil
			changed = legendItems(character.equipment, classId) or changed
			changed = legendItems(character.inventory, classId) or changed
			local quests = character.quests
			if type(quests) == "table" and type(quests.side) == "table" and type(quests.side.active) == "table" then
				for _, entry in quests.side.active do
					if type(entry) == "table" then
						changed = legendItems(entry.choice, classId) or changed
					end
				end
			end
		end
	end
	if type(data.deposit) == "table" then
		changed = legendItems(data.deposit.items, nil) or changed
	end
	if changed then
		data.legendRework = true
	end
end

-- Upgrades and reconciles account data in place. Returns the list of applied migration numbers.
function AccountSchema.migrate(data: any, newId: (() -> string)?): { number }
	local counter = 0
	local makeId = newId or function(): string
		counter += 1
		return `migrated-{counter}`
	end
	local applied = {}
	local schema = tonumber(data.schema) or 1
	while schema < AccountSchema.CURRENT do
		schema += 1
		local migration = MIGRATIONS[schema]
		if migration then
			migration(data, makeId)
		end
		table.insert(applied, schema)
	end
	data.schema = AccountSchema.CURRENT

	TableUtil.reconcile(data, AccountSchema.accountTemplate())
	local template = AccountSchema.characterTemplate()
	for _, character in data.characters do
		if type(character) == "table" then
			TableUtil.reconcile(character, template)
			-- S102: every load recounts the story from mainLast / the active quest, so inserted story quests need no
			-- migration (Logic/StoryProgress)
			StoryProgress.apply(character.quests)
		end
	end
	return applied
end

-- Exposed for tests.
AccountSchema._migrations = MIGRATIONS

return AccountSchema
