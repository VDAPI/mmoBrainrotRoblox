--!strict
-- Global constants and switches. Balance numbers for game systems live in Data/*; this file holds
-- engine-level settings shared by server and client.

local Config = {
	GameName = "Vaelthorn",

	MaxLevel = 100,
	MaxCharacters = 3,

	-- Roblox UserIds with admin commands in live servers. Everyone is admin in Studio.
	-- To add yourself: open your Roblox profile, the number in the URL (roblox.com/users/<id>/profile)
	-- is your UserId. Example: AdminUserIds = { 123456789 },
	AdminUserIds = {} :: { number },

	-- DataStore names. Bump the profile store suffix only together with a migration plan.
	ProfileStoreName = "Vaelthorn_v1",
	NameStoreName = "Vaelthorn_Names_v1",

	CharacterName = {
		MinLength = 3,
		MaxLength = 16,
	},

	-- Gold given to a freshly created character.
	StartingGold = 50,
	StartingMap = "city",

	-- Languages supported by Locale. First one is the fallback.
	Languages = { "en", "pl" },
	DefaultLanguage = "en",

	Debug = {
		-- Verbose service start timings and state diff logging.
		VerboseLogs = true,
		LogStateDiffs = false,
	},

	-- Combat state: seconds after the last damage dealt/taken (DESIGN §4.4 regen, §3.3 PvP lock).
	CombatTimeout = 5,
	-- Resource regeneration tick (s). Replication is throttled to whole-number changes.
	ResourceTick = 0.25,

	-- Death (DESIGN §3.4): respawn delay = RespawnBase + RespawnPerLevel x level.
	RespawnBase = 5,
	RespawnPerLevel = 0.3,
	FastRespawnMultiplier = 0.5, -- "Fast Return" gamepass
	RespawnNowCost = 10, -- Dragon Shards

	-- PvP toggle (DESIGN §3.3).
	PvpToggleDelay = 10,
	PvpCombatLock = 15,
	-- Crowd control from players lasts this fraction on players (DESIGN §3.3, S10).
	PvpCcMultiplier = 0.5,
	-- A kill counts for the last player who hit the victim within this many seconds.
	PvpKillCredit = 10,
	-- Duels on the city arena (S10).
	DuelCountdown = 3,
	DuelTimeLimit = 180,
	DuelInviteSeconds = 30,
	-- Trading (DESIGN §18, S10).
	TradeRange = 20,
	TradeConfirmDelay = 3,
	TradeInviteSeconds = 30,

	-- World generation (S08): warn when a generated map exceeds this many parts.
	MaxPartsPerMap = 8000,

	-- Zone detection interval (s).
	ZoneCheckInterval = 0.5,
	-- Players within this radius see someone's level-up effect.
	EffectRadius = 150,

	-- Items (DESIGN §5.5, §9).
	PotionCooldown = 1.5, -- seconds, per potion kind
	LootLifetime = 120, -- seconds a loot bag stays
	LootPickupRange = 12, -- studs (+ lag tolerance in LootService)
	DefaultCapacity = 20, -- inventory slots without a backpack item

	-- Live monsters allowed on one server (spawners stop when reached).
	MaxActiveMonsters = 400,

	-- How often (s) the server flushes batched state diffs. 0 = every Heartbeat.
	StateFlushInterval = 0,
}

return table.freeze(Config)
