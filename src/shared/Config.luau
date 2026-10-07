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
	-- Interactive map and the guide (S25, DESIGN §23): a target counts as reached within `arrive` studs
	-- (`arriveNpc` for NPCs, who stand behind their counter); the path is recomputed when the player is more than
	-- `deviate` studs off it, at most once every `recompute` seconds; markers every `spacing` studs up to `ahead`
	-- studs in front of the player from a pool of `pool` parts. Pathfinding goes at most `pathRange` studs at once
	-- (the client only knows the streamed world); farther goals get a partial path towards them. `maxMarks`
	-- own map marks per character.
	Nav = {
		arrive = 6,
		arriveNpc = 9,
		deviate = 10,
		recompute = 2,
		spacing = 6,
		ahead = 120,
		pool = 40,
		pathRange = 400,
		waypointReach = 3.5,
		maxMarks = 8,
	},
	-- Side quests (S27, DESIGN §20): at most `maxActive` at once, taken from `levelSlack` levels under the quest's
	-- level; the arc's last quest lets the player pick 1 of `choiceCount` items for their class (weapon + armour
	-- pieces, item level = quest level) of rarity `choiceRarity` (S30: 2 Unique, 3 Heroic for the arc's end). `use`
	-- interactions need the player within `useRange` studs of the anchor and break when moving more than
	-- `useMoveLimit` studs or taking damage (like gathering).
	SideQuest = {
		maxActive = 10,
		levelSlack = 2,
		choiceCount = 3,
		choiceRarity = { normal = 2, final = 3 },
		useRange = 10,
		useMoveLimit = 3,
	},
	-- Skills (S28, DESIGN §14): `breakpoints` turns the level 5 / 10 breakpoints on (off = numbers only).
	Skills = {
		breakpoints = true,
		-- Seconds a skill pressed during the global cooldown / the cast waits to fire (client queue).
		queueWindow = 0.4,
	},
	-- Skill visuals (S28): at most `maxActive` effects at once on a client; effects of other players farther than
	-- `simpleBeyond` studs use the simple version; low graphics quality halves particles and drops weapon trails.
	Vfx = {
		maxActive = 40,
		simpleBeyond = 60,
		lowParticles = 0.5,
	},
	-- Bosses (S30, DESIGN §16): every character may kill one boss `dailyRuns` times per UTC day.
	Boss = {
		dailyRuns = 3,
	},
	-- Boss personal loot (S30, DESIGN §16): a personal Legendary is usable by the winner's class with chance
	-- `legendaryClassShare`; a personal Mythic is one of the boss's named items with chance `mythicNamedShare`
	-- (class-usable first), otherwise a rolled Mythic of a base usable by the winner's class.
	BossLoot = {
		legendaryClassShare = 0.8,
		mythicNamedShare = 0.5,
	},
	-- Streaming (S20, decision in PROGRESS): also set in default.project.json (Workspace properties).
	StreamingTargetRadius = 512,
	StreamingMinRadius = 128,
}

return table.freeze(Config)
