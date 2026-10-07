--!strict
-- Persistent data templates and migrations (pure). DataService feeds these to ProfileStore.
-- When the shape changes: bump CURRENT, add MIGRATIONS[CURRENT], extend the templates.

local Config = require("../Config")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Time = require("./Time")
local Types = require("../Types")
local StarterGear = require("./StarterGear")
local TableUtil = require("../Util/TableUtil")

type AccountData = Types.AccountData
type CharacterData = Types.CharacterData

local AccountSchema = {}

AccountSchema.CURRENT = 5

function AccountSchema.accountTemplate(): AccountData
	return {
		schema = AccountSchema.CURRENT,
		characters = {},
		lastCharacter = nil,
		dragonShards = 0,
		deposit = { size = 60, items = {} },
		cosmetics = { owned = {}, equipped = {} },
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
		},
		purchases = {},
		dailyLimits = { day = 0, protectScrolls = 0 },
		stats = { createdAt = 0, playtime = 0 },
		redeemed = {},
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
		skills = {},
		skillPoints = 0,
		hotbar = {},
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
			side = { active = {}, done = {} },
		},
		guildId = nil,
		auctions = {},
		guideDone = true, -- existing characters skip the guide; CharacterFactory sets false for new ones
		pvpEnabled = false,
		elixirs = {},
		pvp = { kills = 0, deaths = 0, duelsWon = 0, duelsLost = 0 },
		visitedMaps = { [Config.StartingMap] = true },
		mapMarks = {},
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
		TableUtil.reconcile(character, template)
	end
	return applied
end

-- Exposed for tests.
AccountSchema._migrations = MIGRATIONS

return AccountSchema
