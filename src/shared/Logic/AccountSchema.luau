--!strict
-- Persistent data templates and migrations (pure). DataService feeds these to ProfileStore.
-- When the shape changes: bump CURRENT, add MIGRATIONS[CURRENT], extend the templates.

local Config = require("../Config")
local Types = require("../Types")
local StarterGear = require("./StarterGear")
local TableUtil = require("../Util/TableUtil")

type AccountData = Types.AccountData
type CharacterData = Types.CharacterData

local AccountSchema = {}

AccountSchema.CURRENT = 2

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
			quality = "high",
			minimapRotate = false,
			cameraSens = 1,
			sellConfirm = true,
		},
		purchases = {},
		dailyLimits = { day = 0, protectScrolls = 0 },
		stats = { createdAt = 0, playtime = 0 },
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
		bossLockouts = {},
		alchemy = {},
		quests = { main = nil, mainDone = 0, daily = { day = 0, list = {}, rerolls = 0 } },
		guildId = nil,
		auctions = {},
		guideDone = true, -- existing characters skip the guide; CharacterFactory sets false for new ones
		pvpEnabled = false,
		elixirs = {},
		pvp = { kills = 0, deaths = 0, duelsWon = 0, duelsLost = 0 },
		visitedMaps = { [Config.StartingMap] = true },
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
