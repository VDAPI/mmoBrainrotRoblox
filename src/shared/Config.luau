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
	-- Guilds (S12): records keyed "Guild_<id>", unique names/tags, presence across servers.
	GuildStoreName = "Vaelthorn_Guilds_v1",
	GuildNamesStoreName = "Vaelthorn_GuildNames_v1",
	GuildPresenceMap = "Vaelthorn_GuildPresence_v1",
	GuildPresenceTtl = 120, -- seconds an online entry stays without a refresh
	GuildPresenceRefresh = 45, -- how often a server refreshes its members' presence
	GuildCacheRefresh = 90, -- safety re-read of cached guilds (MessagingService is best effort)
	GuildChatMaxLength = 200,
	-- Mail and auction house (S13).
	MailStoreName = "Vaelthorn_Mail_v1",
	AuctionStoreName = "Vaelthorn_Auction_v1",

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
	-- S22: after the countdown the player picks "city" or "here"; no pick in this many seconds = the city.
	DeathChoiceTimeout = 60,
	-- S22: respawn protection (1 HP, no damage, monsters ignore, no PvP; ends early on any attack).
	RespawnShieldSeconds = 10,
	-- S22: a blocked death spot (water, inside a wall) looks for a free spot this far around it.
	RespawnSearchRadius = 20,

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

	-- World generation (S08): warn when a generated map exceeds this many parts (a map may set a stricter
	-- `maxParts`, S21).
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
	MaxActiveMonsters = 600, -- S19: groups near players only (sleeping groups despawn after 90 s)

	-- How often (s) the server flushes batched state diffs. 0 = every Heartbeat.
	StateFlushInterval = 0,
	-- Sprint (S18, DESIGN §24): walk speed multiplier while the sprint key is held.
	SprintMultiplier = 1.35,
	-- Client decorations (S20, DESIGN §3.7): chunk size and radius per "World detail" setting (studs).
	DecorChunk = 128,
	DecorRadius = { low = 250, mid = 400, high = 600 },
	-- Starting city (S21, docs/miasto/MIASTO.md §5): the client builds the "detail" level of buildings within
	-- TownDetailRadius and the "fine" level within TownFineRadius of the camera (per "World detail" setting);
	-- a building leaves when it is TownDetailHysteresis studs past the radius. At most TownDetailPartsPerFrame
	-- parts are created per frame.
	TownDetailRadius = { low = 120, mid = 220, high = 400 },
	TownFineRadius = { low = 60, mid = 90, high = 120 },
	TownDetailHysteresis = 40,
	TownDetailPartsPerFrame = 400,
	-- Day and night on maps with `dayNight` (S21): one full day in real seconds; night (19:00-6:00) takes
	-- DayNightShare of it.
	DayLength = 2400,
	DayNightShare = 0.25,
	-- Monster looks (S24): the server waits CorpseSeconds before removing a dead monster; clients fade the look
	-- over the same time. Clients build the full look within fullIn studs of the camera (lowQuality: graphics
	-- quality "low"), hide it past fullOut (a 2-3 part silhouette stays) and destroy it past drop; at most
	-- partsPerFrame parts are created per frame, and at most maxAnimated looks (the nearest) are animated.
	CorpseSeconds = 1.6,
	MonsterLook = {
		fullIn = 160,
		fullOut = 180,
		fullInLow = 110,
		fullOutLow = 130,
		drop = 320,
		partsPerFrame = 300,
		checkEvery = 0.25,
		maxAnimated = { touch = 25, desktop = 60 },
	},
	-- Streaming (S20, decision in PROGRESS): also set in default.project.json (Workspace properties).
	StreamingTargetRadius = 512,
	StreamingMinRadius = 128,
}

return table.freeze(Config)
