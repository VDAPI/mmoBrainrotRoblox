--!strict
-- Global constants and switches. Balance numbers for game systems live in Data/*; this file holds
-- engine-level settings shared by server and client.

local Config = {
	GameName = "Vaelthorn",

	MaxLevel = 100,
	MaxCharacters = 5,
	-- S121: slots above FreeCharacters need the slot passes (Data/Products.SLOT_PASSES) to create a character; an
	-- existing character there stays playable (DESIGN-17 §2)
	FreeCharacters = 3,

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
	-- S127: global arena queue and arena servers (DESIGN-17 §6). Technical timings and store names, not balance (not in
	-- CONFIG_KEYS). The rating window, the brackets, the accept time and the decline penalty stay in Data/Arena.
	ArenaNet = {
		pollMin = 3, -- s between two queue polls of this server (random in pollMin..pollMax, Logic/Rng)
		pollMax = 5,
		entryTtl = 120, -- s a queue entry lives in MemoryStore without a refresh (DESIGN-17 §6)
		refreshEvery = 30, -- s between refreshes of a waiting entry by its own server
		claimHold = 20, -- s a claim lives before its offer exists (organizer died -> the entry is free again)
		acceptGrace = 10, -- s after the accept time before a server cancels an offer nobody finished
		matchTtl = 600, -- s a match record lives (ArenaMatch_<id>, DESIGN-17 §6: 10 min)
		registryTtl = 900, -- s a ReservedServers entry lives (the mode of a reserved server)
		globalWait = 45, -- s without a global opponent before the local offer (DESIGN-17 §6)
		rangeCount = 50, -- entries read by one GetRangeAsync
		arriveTimeout = 60, -- s the arena server waits for both fighters
		returnDelay = 8, -- s on the arena server after the result before the way back
		teleportRetries = 3, -- attempts per teleport target
		teleportRetryGap = 2, -- s between two attempts
		modeWait = 15, -- s a reserved server waits at boot for its registry entry / the first join data
		offlineAfterErrors = 3, -- consecutive store errors -> "this server only" for offlineFor s
		offlineFor = 60,
		queuePrefix = "ArenaQueue", -- SortedMap ArenaQueue_<mode>_<bracket>
		matchMap = "ArenaMatches", -- HashMap, keys ArenaMatch_<id>
		registryMap = "ReservedServers", -- HashMap, key = PrivateServerId -> { mode, ref }
		penaltyMap = "ArenaPenalty", -- HashMap, key = the entry key "<userId>_<slot>" -> until (unix s)
		topic = "ArenaMatch", -- MessagingService topic (DESIGN-17 §6)
	},
	-- S128: the arena Hall of Fame and the season rewards between servers (DESIGN-17 §0.4, §6). Technical, not balance
	-- (not in CONFIG_KEYS); the rewards themselves are in Data/Arena.
	Arena = {
		hofStore = "ArenaHallOfFame", -- DataStore, key = the season "YYYYMM" -> the top of each arena board
		hofCheck = 600, -- s between two checks whether the last season's record exists (with a random spread)
		hofDelay = 900, -- s after the start of a season before the record is built (the last results arrive)
		hofSize = 10, -- the top of each board kept (DESIGN-17 §6: top 10)
		rewardRetry = 300, -- s between two attempts to mail a pending season reward
	},
	-- S130: Champion's Tournament plumbing (DESIGN-17 §0.4/§8). Store names, TTLs and polling; technical, not balance (not
	-- in CONFIG_KEYS); the game numbers are in Data/Arena.TOURNEY.
	Tourney = {
		signupMap = "Tourney", -- MemoryStore SortedMap "<signupMap>_<id>_<bracket>"
		serverMap = "TourneyServers", -- MemoryStore HashMap: organizer lock and tournament server records
		hallStore = "TourneyHall", -- DataStore (KeyStore) with the last champions per bracket
		topic = "Tourney", -- MessagingService topic { op, id, b, s } (<= 1 KB, never player lists)
		signupTtl = 6 * 3600,
		recordTtl = 3 * 3600,
		lockTtl = 3600,
		infoCache = 30, -- seconds a server keeps the signup count of a bracket
		signupCooldown = 3, -- seconds between signup/unsign calls of one player
		recheck = { 20, 60 }, -- seconds after `organize` when a world server reads the records itself (lost messages)
		hallRefresh = 300,
		returnDelay = 60, -- seconds after the final before everyone is sent back
		maxMinutes = 150, -- safety stop of a tournament server
		startWait = 45, -- seconds after the start a tournament server waits for the invited players to arrive
		callWait = 90, -- seconds a called fighter of a local tournament may stay busy (fight, dungeon) before a walkover
		emptyClose = 300, -- seconds a tournament server without anyone in the bracket waits before sending all home
		probeRetry = 5, -- seconds before the second store probe when a tournament's mode is decided
		forceMinutes = 20, -- S131: default start of /tourney force (minutes from now; signups open at once)
	},
	-- Mail and auction house (S13).
	MailStoreName = "Vaelthorn_Mail_v1",
	AuctionStoreName = "Vaelthorn_Auction_v1",
	-- S133: letters between players (Logic/Social.letter*). Not in CONFIG_KEYS: the fee is a small gold sink outside the
	-- economy model (docs/DECYZJE.md S133).
	PlayerMail = {
		subjectMax = 40, -- characters
		bodyMax = 300, -- characters
		maxItems = 3, -- backpack items per letter (whole stacks, unbound, not locked)
		feeBase = 10, -- gold per letter
		feePerItem = 10, -- gold per attached item
		perDay = 20, -- letters per character and UTC day
		minLevel = 5, -- sender's level (spam accounts)
	},
	-- S133: friends, ignored players, presence across servers and whispers (Logic/Social, SocialService).
	Social = {
		maxFriends = 50,
		maxIgnored = 100,
		storeName = "Vaelthorn_Social_v1", -- DataStore "Social_<userId>": ignore mirror and pending unfriends
		presenceMap = "Vaelthorn_Presence_v1", -- MemoryStore HashMap: userId -> { j, m, l, c, n, t }
		presenceTtl = 120, -- s: an entry without a refresh counts as offline
		presenceRefresh = 60, -- s: how often a server rewrites its players' entries
		statusRefresh = 30, -- s: the friends window asks again; the server caches a read for as long
		inviteSeconds = 30, -- friend request popup
		holdSeconds = 0.5, -- touch: holding a player this long opens the player menu
		holdMove = 14, -- px: a finger moving further cancels the hold (camera drag)
		followRefresh = 0.5, -- s: "Follow player" re-reads the target position
	},
	-- Leaderboards (S124, DESIGN-17 §5): store names and request limits; boards in Data/Leaderboards.
	Leaderboard = {
		refresh = 300, -- s: one server reads the top of one board at most this often (DESIGN-17 §0.4)
		writeGap = 60, -- s: one entry key is written at most this often (and once more on leave)
		top = 100, -- entries kept per board read
		townTop = 10, -- rows on the town board
		minLevel = 5, -- characters below this level are not written (saves requests for brand-new characters)
		excludeAdmins = true, -- characters of Config.AdminUserIds are never written and are filtered out on read
		orderedPrefix = "Vaelthorn_LB_v1_", -- + board instance id: OrderedDataStore per permanent board
		sortedPrefix = "Vaelthorn_LBMap_v1_", -- + board instance id: MemoryStore SortedMap per periodic board
		metaStore = "Vaelthorn_LBMeta_v1", -- DataStore: entry key -> { n, c, g?, l, u, t } (name, class, guild tag, level)
		listStore = "Vaelthorn_LBLists_v1", -- DataStore: list board instance id -> { entries } (Hall of Fame)
		metaTtl = 1800, -- s a cached name / class / guild tag is trusted before it is read again
		metaReadsPerRefresh = 40, -- DataStore reads of missing metadata per board refresh (the rest waits a refresh)
		budgetFloor = 20, -- skip optional reads while the GetAsync budget is below this (profiles come first)
		firstWait = 5, -- s a LeaderboardGet call waits for the very first read of a board
		clientPoll = 60, -- s between LeaderboardGet calls of an open Rankings window
		flushWait = 8, -- s BindToClose waits for queued writes
		idleBoard = 900, -- s: a board nobody opened for this long is no longer refreshed (town boards always are)
		adminRefreshGap = 60, -- s between forced refreshes (/lb refresh) on one server
		deleteTries = 3, -- attempts to remove the entries of a deleted character
		enterDelay = 10, -- s after entering the world before the entry write (the guild record loads in the meantime)
		retryFailed = 60, -- s before a failed board read is tried again
		-- S125: weekly EXP and the guild board (one write per key every writeGap s, like every board)
		weekTtl = 8 * 86400, -- s: weekly SortedMap entries outlive the week, so the next week can pay it out
		payoutGrace = 300, -- s after the week ends before any server tries to pay (the last writes land)
		payoutCheck = 300, -- s between payout checks (with ±payoutJitter)
		payoutJitter = 60,
		payoutLockStale = 900, -- s after which a claimed but unfinished payout may be taken over by another server
		payoutStore = "Vaelthorn_LBPayouts_v1", -- DataStore: "paid_<week>" -> payout record (lock, sent, winners)
		guildTop = 10, -- highest member levels summed for the guild score
	},
	-- S129 (DESIGN-17 §7, §0.4): Blood Moon technical limits (not in CONFIG_KEYS). Rules and rewards:
	-- Data/ScheduledEvents.bloodMoon. MemoryStore retries: Leaderboard/Stores (Market/Retry).
	BloodMoon = {
		writeEvery = 60, -- seconds between two writes of one character's score to the region board (and on leave / end)
		writeRetry = 10, -- seconds before a failed score write is tried again
		writeTries = 3, -- attempts of the last write (on leave / at the end) before the settlement
		readEvery = 30, -- seconds between two reads of the regions' top 10 on one server (live window)
		rankTop = 100, -- ranks read at the end (rewards: top 100 / 10 / 1)
		boardTop = 10, -- rows of the live window
		ttl = 172800, -- 2 days: SortedMap entries (DESIGN-17 §7)
		settleDelay = 90, -- seconds after the end before reading the final ranks (last writes of other servers)
		settleRetry = 60, -- seconds before the settlement reads a region board again after a failed read
		settleTries = 3, -- settlement attempts on one server; then the rest waits for the character's next entry
		resultsFor = 7200, -- the window and the menu entry keep the results this long after the end
	},
	-- S131: cross-server announcements (AnnounceService.Global): one MessagingService publish per `globalGap` s per
	-- server; announcements within the gap wait in a queue of at most `queueMax` (the oldest is dropped beyond it).
	Announce = { globalGap = 10, queueMax = 6 },
	-- S131: shop and VIP analytics funnels (Logic/ShopFunnel): a funnel session ends after this many s without a step.
	ShopFunnel = { sessionTimeout = 1800 },

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
	BuildSetCooldown = 5, -- S58: seconds between build set switches (ROZWOJ 2.9)
	-- Resource regeneration tick (s). Replication is throttled to whole-number changes.
	ResourceTick = 0.25,

	-- Death (DESIGN §3.4): respawn delay = RespawnBase + RespawnPerLevel x level.
	RespawnBase = 5,
	RespawnPerLevel = 0.3,
	FastRespawnMultiplier = 0.5, -- "Fast Return" gamepass
	RespawnNowCost = 10, -- Dragon Shards
	-- VIP (DESIGN-17 §2, S121): comfort and looks only, never EXP, gold, drops or stats (tests/paywall.spec).
	-- MonetizationService.HasVip = an active VIP subscription or the "vip" pass ("VIP forever").
	Vip = {
		dailyShards = 15, -- Dragon Shards on the first VIP moment of a UTC day (account.vip.shardDay)
		auctionExtraListings = 5, -- on top of Data/Market Auction.maxListings
		auctionFeeMul = 0.5, -- sale fee multiplier, fixed on the listing when it is listed (deposit unchanged)
		freeRecallCooldown = 600, -- seconds between free returns to the city (the Stone of Return channel)
		freeRespawnsPerDay = 1, -- instant respawns for free per UTC day (account.vip.respawnDay / respawnN)
		statusRefresh = 1800, -- seconds: safety re-check of the subscription status while in game
	},
	-- S22: after the countdown the player picks "city" or "here"; no pick in this many seconds = the city.
	DeathChoiceTimeout = 60,
	-- S22: respawn protection (1 HP, no damage, monsters ignore, no PvP; ends early on any attack).
	RespawnShieldSeconds = 10,
	-- S22: a blocked death spot (water, inside a wall) looks for a free spot this far around it.
	RespawnSearchRadius = 20,
	-- FIX 2026-10-15 (owner): "respawn here" costs gold, the city stays free: max(min, level x perLevel) (about five
	-- kills of the player's level, Combat.goldPerLevel 3). Dungeons (entrance) and unusable spots stay free.
	RespawnHereGoldPerLevel = 15,
	RespawnHereGoldMin = 10,

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
	-- S122 (DESIGN-17 §3): Elixir of Wholeness (potion_full): own cooldown, uses per character and UTC day. Where it
	-- does not work: Logic/UseBlocks.LISTS.fullElixir.
	FullElixir = { cooldown = 180, dailyLimit = 10 },
	-- S122 (DESIGN-17 §3): Cloak of Luring (account.lure). Every `interval` s ordinary idle monsters within `radius`
	-- studs and `levelGap` levels are pulled onto the player, at most `maxPulled` fighting the player at once;
	-- `pullThreat` = threat of the pull (any real hit outweighs it); `tick` = LureService loop step.
	Lure = { interval = 8, radius = 25, levelGap = 10, maxPulled = 6, pullThreat = 1, tick = 1 },
	-- S134d: Auto Potions (account.autoPotion, Logic/AutoPotion): the HP / class resource thresholds the player may set
	-- (% of the maximum, `step` apart; 0 switches a threshold off), the default thresholds, the AutoPotionService loop
	-- step and how often "no potion" may be said per kind (s). Where it does not work: Logic/UseBlocks.LISTS.autoPotion.
	AutoPotion = { minPct = 10, maxPct = 90, step = 5, hp = 50, res = 30, tick = 0.25, noneEvery = 60 },
	-- S134d: Auto Hunt (account.autoGrind, Logic/AutoGrind). The banked time runs only while hunting, at most
	-- `dailySeconds` per UTC day; `scrollSeconds` = one Scroll of the Hunt. AutoGrindService: loop step `tick`, the bank
	-- saved every `saveEvery` s; stops: no kill for `stuckSeconds`, `leaveMargin` studs outside the hunting ground,
	-- an Elite II / boss within `bossRadius`, HP under `stopHpPct` % without Auto Potions, fewer than `minFreeSlots`
	-- free slots with the autoLoot pass. Targets: ordinary monsters of the ground within `levelGap` levels, looked for
	-- `seekRadius` studs around the player (further: the next group of the ground).
	AutoGrind = {
		dailySeconds = 3 * 3600,
		scrollSeconds = 1800,
		tick = 1,
		saveEvery = 60,
		stuckSeconds = 180,
		leaveMargin = 40,
		bossRadius = 90,
		levelGap = 10,
		seekRadius = 60,
		arrive = 12, -- studs from a group's centre that count as "visited" on the round of the ground
		stopHpPct = 30,
		minFreeSlots = 1,
	},
	-- S132 (DESIGN-17 §9a): class looks; looks only, not balance (not in CONFIG_KEYS). maxPieces = procedural parts
	-- one character may wear (outfit + hairstyle + the S122 lure cape, Logic/CharacterLook.resolve); avatarScale =
	-- the Roblox avatar's scales allowed in "Show my Roblox avatar" (Logic/CharacterLook.clampScales: standard R15
	-- height +-5%, never wider or deeper than standard, no Rthro body type or proportions).
	CharacterLook = {
		maxPieces = 28,
		avatarScale = {
			height = { 0.95, 1.05 },
			width = { 0.9, 1.0 },
			depth = { 0.9, 1.0 },
			head = { 0.95, 1.0 },
			bodyType = { 0, 0 },
			proportion = { 0, 0 },
		},
	},
	-- S132: the paid look change at the barber (after the one free change of every character):
	-- max(goldMin, goldPerLevel x character level) gold (Logic/CharacterLook.changeCost): 2-15% of a level's income
	-- on 20 / 45 / 70 / 100 (tests/balance.spec "S132 look change"); goldMin covers levels 1-20.
	LookChange = { goldPerLevel = 15, goldMin = 300 },
	LootLifetime = 120, -- seconds a loot bag stays
	LootPickupRange = 12, -- studs (+ lag tolerance in LootService)
	DefaultCapacity = 20, -- inventory slots without a backpack item

	-- Live monsters allowed on one server (spawners stop when reached).
	-- S19: groups near players only (sleeping groups despawn after 90 s). S134i: 600 -> 700 (every region map full at
	-- once holds 644 monsters with the Elite II hideouts' Elite IIs and guards, tests/areaprofiles.spec)
	MaxActiveMonsters = 700,

	-- How often (s) the server flushes batched state diffs. 0 = every Heartbeat.
	StateFlushInterval = 0,
	-- Sprint (S18, DESIGN §24): walk speed multiplier while the sprint key is held.
	SprintMultiplier = 1.35,
	-- Mounts (S96, docs/DESIGN-15.md §2): from character level `minLevel`. Riding walk speed =
	-- Stats.Formula.walkSpeed x mul, mul rising linearly from baseMul (mount level 1) to maxMul (mount level
	-- maxLevel), one cap for every mount, times (1 + gear moveSpeed / 100) with the usual 30 cap; skill / path
	-- speed buffs and sprint do not apply, slows do (S63 speed factor). Mounting takes mountTime seconds standing
	-- still (mountTimeFast from mount level fastFromLevel); moving more than moveLimit studs, taking damage or using
	-- a skill interrupts it. Levels are raised in S97.
	Mount = {
		minLevel = 20,
		baseMul = 1.6,
		maxMul = 2.0,
		maxLevel = 10,
		mountTime = 1.5,
		mountTimeFast = 1.0,
		fastFromLevel = 5,
		moveLimit = 2.5,
	},
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
	-- S46: lights of the region's lava (and later of the caves) on at once, nearest to the camera first, per
	-- "World detail" setting (Controllers/RegionLightController).
	RegionLights = { low = 4, mid = 8, high = 12 },
	-- S48: lights on at once in a cave, crypt or boss chamber (nearest the camera; RegionLightController)
	-- S134h: low 8 -> 12 (a phone with low graphics sees more rooms); `player` = the soft light the local player carries
	-- underground (RegionLightController; looks only, outside the lamps' count)
	CaveLights = {
		low = 12,
		mid = 16,
		high = 24,
		player = { range = 26, brightness = 0.8, color = "#FFD9A8" },
	},
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
		-- S117 (DESIGN-16 §8, looks only; the server's windups, areas and corpse time stay): the push of a hit on a
		-- generated monster away from its attacker (body lean in rad, shift in studs at scale 1; Logic/Gait.hitLean),
		-- bosses lean less (x bossHitScale), one flinch per model at most every hitEvery s; a summoned boss helper
		-- climbs out of the ground in summonRise s, the first summonFxMax of a wave with dust and cracks; a dead boss
		-- leaves a clone of its look that breaks up in light over bossDeathSeconds (Data/BossMotions death.seconds may
		-- override it); Grimrok's leap flies the last leapArc s of its windup; the death of a generated monster lasts
		-- deathSeconds (inside CorpseSeconds); the phase roar lasts roarSeconds unless Data/BossMotions says otherwise
		-- and its aura flashes phaseLight s.
		hitLean = 0.18,
		hitPush = 0.25,
		bossHitScale = 0.35,
		hitEvery = 0.1,
		summonRise = 0.8,
		summonFxMax = 4,
		bossDeathSeconds = 4,
		leapArc = 0.35,
		deathSeconds = 0.8,
		roarSeconds = 1.2,
		phaseLight = 0.4,
	},
	-- Monster telegraphs 2.0 (S117, Logic/Telegraph): the area fills from the edge to the centre over the windup,
	-- the rim pulses faster towards the end, the area flashes at the blow and fades. Telegraphs over maxActive use
	-- the simple version (outline + moving front only). Segments: circle / ring band pieces (low quality: segmentsLow).
	Telegraph = {
		maxActive = 16,
		segments = 24,
		segmentsLow = 12,
		rimWidth = 0.35, -- studs: the bright rim
		underRim = 0.25, -- studs: a dark rim under / outside it (contrast on snow)
		fillFrom = 0.8, -- transparency of the filled band at the start of the windup
		fillTo = 0.45, -- ... and at its end
		areaAlpha = 0.85, -- transparency of the whole area from the first frame (where the blow will land)
		pulseSlow = 0.5, -- seconds per rim pulse at the start
		pulseFast = 0.12, -- ... and at the end
		flashSeconds = 0.08, -- the whole area brighter and whiter at the blow
		fadeSeconds = 0.2, -- then it fades
		safePulse = 0.3, -- seconds before the blow the safe centre of a ring pulses
		shakeRange = 60, -- studs: players farther feel no boss shake
		lift = 0.12, -- studs above the ground
		-- S134 (bosses 2.0): a big blow to dodge keeps its colour with a thicker rim; the party mechanics have their own
		-- colours (split: the golden circle to stand in together, mark: the purple circle on the marked player)
		rimWidthAvoid = 0.7,
		mechanicColors = { split = "#F2C14E", mark = "#A35BFF" },
		markRange = 60, -- studs: the marked player's glow shows for players this close (and the marked one)
		tagHeight = 4, -- studs above the split circle of its "Together" label
		-- S134e: a lethal blow (an Elite II's Crushing Blow): dark crimson (not an element's colour, not the golden
		-- split), the thick rim of a big blow and a faster pulse at the end (seconds per pulse instead of pulseFast)
		lethalColor = "#8B0A1E",
		pulseLethal = 0.07,
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
	-- Quest marks (S98, DESIGN-15 §3.1): an offer more than `greyGap` levels under the character shows a grey "!"
	-- instead of a gold one.
	Quest = {
		greyGap = 6,
		contractBacklog = 3, -- S99: levels of backlog an existing character keeps at the first load after S99
		trackerContracts = 3, -- S134k: hunting contracts on the HUD tracker (then "+N hunting contracts (J)")
	},
	-- Quest dialogue (S101b, DESIGN-15 §3.5): the only items an answer may give (`item` effect of Logic/Dialogue),
	-- id -> at most this many in one gift, once per character and quest. Small consumables only: no equipment, no
	-- currency (better gear stays in the drops).
	Dialogue = {
		gifts = {
			potion_hp_1 = 3,
			potion_mana_1 = 3,
			-- S103: chapter II of the story (Duskwood, 20-45): the potions of its level, below the quest rewards
			potion_hp_3 = 2,
			potion_hp_4 = 2,
			potion_mana_3 = 2,
			-- S104: chapter III (the Ashen Wastes, 45-70): one fire resistance elixir before the Wyvern Lair
			elixir_resFire = 1,
			-- S105: chapter IV and the finale (the Frost Peaks, 70-100): the great potions before the Grotto and the rite
			potion_hp_5 = 2,
			potion_mana_5 = 2,
		},
	},
	-- NPC comments during quests (S101b, Logic/Barks + BarkController; client only, no effect on play). Seconds
	-- between any two comments (`gap`) and between the same quest + event (`sameEvent`), at most `perMinute` in a
	-- 60 s window; "near the objective" within `nearRadius` studs; the hint after `stuckAfter` seconds of play
	-- without progress (never in town), repeated every `stuckRepeat`; a comment on death at most every
	-- `deathRepeat`; the bubble over the speaker within `bubbleRange` studs (else the portrait box at the screen's
	-- edge), shown `bubbleSeconds` / `toastSeconds`; a comment held while the speaker's dialog is open waits at
	-- most `holdSeconds`.
	Barks = {
		gap = 20,
		sameEvent = 90,
		perMinute = 3,
		nearRadius = 35,
		stuckAfter = 480,
		stuckRepeat = 900,
		deathRepeat = 300,
		bubbleRange = 60,
		bubbleSeconds = 5,
		toastSeconds = 5,
		holdSeconds = 15,
	},
	-- Quest companion (S101b, Logic/Companion + CompanionService; studs and seconds): stands `followDist` from the
	-- player and walks once they are farther than `walkFrom`; teleports next to them past `catchUp` or after
	-- `stuckSeconds` without moving while walking; a leading companion waits once the player is farther than
	-- `waitDist` and walks on under `resumeDist` (a following one hurries past `waitDist`); lost = the player farther
	-- than `failDist` for `failSeconds` (back to the start, rejoined within `rejoin` of it); stays `arriveLinger`
	-- seconds after arriving; path legs at most `legMax` long; walk speeds `speedFollow` (at least the player's 16
	-- on foot, at most 2x: riding and sprinting players are caught up by teleport) and `speedLead`; the server loop
	-- ticks every `tick` seconds; companion lines at most every `lineGap` seconds; a leading companion aims
	-- `lookAhead` studs ahead along its route; a following one recomputes its path at most every `pathEvery` seconds.
	Companion = {
		followDist = 6,
		walkFrom = 10,
		catchUp = 90,
		stuckSeconds = 4,
		waitDist = 28,
		resumeDist = 16,
		failDist = 150,
		failSeconds = 20,
		rejoin = 20,
		arriveLinger = 6,
		legMax = 220,
		speedFollow = 18,
		speedLead = 13,
		tick = 0.25,
		lineGap = 30,
		lookAhead = 8,
		pathEvery = 1,
	},
	-- Story cutscenes (S102, Data/Cutscenes + Logic/Cutscenes + CutsceneController; client timing, not balance):
	-- fades last `fade` s, a chapter title stays `titleSeconds`, a line `lineMin`..`lineMax` s at `lineCharsPerSecond`
	-- characters per second; a far shot waits at most `streamWait` s for streaming; the controller checks for a queued
	-- scene every `idlePoll` s; default focus height `lift`, eye distance `dist` and height `height` (studs); the card
	-- mode (no shot possible) dims the view by `cardDim`.
	Cutscene = {
		fade = 0.6,
		titleSeconds = 4,
		lineMin = 3,
		lineCharsPerSecond = 16,
		lineMax = 8,
		streamWait = 2,
		idlePoll = 0.5,
		lift = 4,
		dist = 22,
		height = 8,
		cardDim = 0.55,
	},
	-- Skills (S28, DESIGN §14): `breakpoints` turns the rank 5 / 10 breakpoints on (off = numbers only).
	Skills = {
		breakpoints = true,
		-- Seconds a skill pressed during the global cooldown / the cast waits to fire (client queue).
		queueWindow = 0.4,
		-- studs a channel / beam / aim may drift from where it started (SkillService, Logic/Channel)
		channelMoveLimit = 2.5,
	},
	-- Skill visuals (S28): at most `maxActive` effects at once on a client; effects of other players farther than
	-- `simpleBeyond` studs use the simple version; low graphics quality halves particles and drops weapon trails.
	Vfx = {
		maxActive = 40,
		simpleBeyond = 60,
		lowParticles = 0.5,
		-- S112: textures (Data/VfxTextures; false = the old look everywhere), limits of live holders per device (a
		-- phone is touch without a keyboard), free holders kept per kind and key, particles of one Emit (after
		-- lowParticles), seconds a ground decal / glowing circle takes to fade out, default turn of a magic circle (rad/s)
		textures = true,
		holdersPerKey = 12,
		maxEmitters = { desktop = 48, touch = 24 },
		maxBeams = { desktop = 20, touch = 10 },
		maxDecals = { desktop = 24, touch = 12 },
		maxLights = { desktop = 12, touch = 6 },
		maxBurst = { desktop = 40, touch = 20 },
		decalFade = 0.35,
		spinStep = 0.6,
		-- S114 (DESIGN-16 §2.8): what one cast's impact may hold at once at its peak (holders and lights of
		-- Vfx/Library, tests/SkillLooks.PIECE_COST); a skill over it loses trail pieces first, never its core
		perCast = { emitters = 6, beams = 3, lights = 2, decals = 3 },
		-- S115 (Hunter and Mage, looks only): Thunderstorm's cloud height over the ground (its bolts start there), the
		-- lob of a thrown snare, how long an arrow of Arrow Rain stays stuck in the ground and its fall speed (studs/s),
		-- the cap of a projectile skill's flight (server/Skills/Types/Offense: 90 studs/s up to 0.6 s), the fall of a
		-- storm meteor after its event (the server's points are random: the rock falls after the damage)
		cloudHeight = 14,
		tossArc = 2.5,
		rainStick = 0.6,
		rainSpeed = 180,
		shotMaxTime = 0.6,
		stormFall = 0.15,
	},
	-- Sound effects (S111, DESIGN-16 §3, Data/Sfx, SfxController): positional voices at once (a phone is touch without a
	-- keyboard), 2D interface voices, the same key again within `repeatWindow` s is dropped, nothing positional
	-- farther than `maxDistance` studs from the camera (= EffectRadius); volume factor by who caused the sound and an
	-- extra factor for others' sounds on low quality (DESIGN-16 §0.2.4). Looks, not balance.
	Sfx = {
		maxVoices = { desktop = 16, touch = 10 },
		uiVoices = 4,
		repeatWindow = 0.05,
		maxDistance = 150,
		priorityVolume = { own = 1, party = 0.85, other = 0.6 } :: { [string]: number },
		lowQualityOther = 0.5,
		previewWait = 3, -- seconds AnimLab `sfx` / `sfx try` waits for a sound to load before it answers
		allEvery = 1.5, -- seconds between two keys of AnimLab `sfx all`
	},
	-- S110 AnimLab (docs/ANIMACJE.md, Studio + admin only): the stage floats `layout.height` studs above the admin;
	-- offsets in studs from its centre C (the actor stands in C facing -Z). Limits of the /animlab arguments.
	AnimLab = {
		layout = {
			height = 250,
			floor = {
				size = { 48, 1, 32 },
				color = "#8A8A8F",
				line = "#5A5A60",
				major = "#3E3E44",
				step = 1,
				majorEvery = 5,
			},
			backdrop = { color = "#6E6E73", height = 20 }, -- three walls: back (+Z), left, right
			actor = { 0, 0, 0 },
			target = { 0, 0, -6 }, -- dummy / monster facing the actor
			row = { from = { -20, 0, 10 }, gap = 2.2 }, -- the idle row of weapon mannequins behind the actor
			cameras = {
				front = { pos = { 0, 3, -14 }, look = { 0, 2.5, 0 } },
				side = { pos = { 14, 3, 0 }, look = { 0, 2.5, 0 } },
				threequarter = { pos = { 10, 5, -10 }, look = { 0, 2.5, 0 } },
				top = { pos = { 0, 22, 0.01 }, look = { 0, 0, 0 } },
				game = { pos = { 0, 9, 16 }, look = { 0, 2, -6 } }, -- behind and above, like the default game camera
			},
		},
		freezeMax = 10, -- seconds: freeze <t> accepts 0..freezeMax
		stepMax = 1, -- seconds: step <dt> accepts -stepMax..stepMax (not 0)
		stressMax = 30, -- mannequins of stress <n>
		stressEvery = 1.5, -- seconds between two skills of one stress mannequin
		loopGap = 0.6, -- seconds between the end of a looped motion and its next start
		freezeWait = 12, -- seconds AnimLabCall waits for a freeze before it answers
		settle = 2, -- seconds a replay waits at most for the effects of the previous one to end
		castWindup = 1.2, -- seconds of the windup of `mob <id> cast` (AnimationController: windup > 1 is a cast)
		comboGap = 0.6, -- S113: seconds between the steps of `attack <type> combo` (inside AttackMotions.COMBO_WINDOW)
		hitShow = 0.6, -- S113: seconds a `hit` / `flinch` motion lasts (freeze, loop, keys)
		stressRadius = 10, -- studs: the circle of the stress mannequins around the actor
		cameraPart = 0.4, -- studs: the invisible AnimLabCam_* parts
		lineWidth = 0.06, -- studs: grid lines (major lines twice as wide)
		wallThickness = 1,
		dummyColor = "#9A9AA0", -- the target mannequin
		vfxEvery = 1.5, -- S112: seconds between two pieces of `vfx all` (and a looped `vfx <piece>`)
		-- S117: `floor <name>`: the stage floor as light grass, snow or a dark cave (telegraph readability)
		floors = {
			grass = { material = "Grass", color = "#6E9A48" },
			snow = { material = "Snow", color = "#EEF2F6" },
			cave = { material = "Slate", color = "#2C2A28" },
		} :: { [string]: { material: string, color: string } },
	},
	-- Bosses (S30, DESIGN §16): every character may kill one boss `dailyRuns` times per UTC day.
	-- S134f: ready check at the dungeon gate (Logic/ReadyCheck): answers within `readyTimeout` s, then a
	-- `readyCountdown` s 3-2-1 before the party is moved in (not balance, outside the ledger).
	Boss = {
		dailyRuns = 3,
		readyTimeout = 20,
		readyCountdown = 3,
	},
	-- S134f: party finder board (Logic/PartyFinder, PartyFinderService): level bands per target kind (the leader
	-- may only narrow them), listing lifetime (s), per-server cap, publish throttle (s). Not balance.
	PartyFinder = {
		bossAbove = 10,
		eliteBelow = 12,
		eliteAbove = 5,
		groundBelow = 3,
		groundAbove = 5,
		invasionBand = 10,
		listingSeconds = 600,
		maxListings = 30,
		maxWant = 4,
		maxMembers = 5,
		publishEvery = 1,
	},
	-- S134f: after-fight meter (Logic/FightStats, FightLogService, FightLogController): shortest fight with a
	-- summary (s), summaries kept on the client, seconds the small card stays. Not balance.
	FightLog = {
		minSeconds = 5,
		keep = 5,
		cardSeconds = 12,
	},
	-- S134f: low health warning (Logic/LowHp, Hud/LowHpVignette): on below onPct, off above offPct (hysteresis),
	-- full strength at fullPct; heartbeat interval from beatSlow to beatFast (s); vignette alpha cap. Not balance.
	LowHp = {
		onPct = 25,
		offPct = 28,
		fullPct = 5,
		beatSlow = 1.4,
		beatFast = 0.7,
		maxAlpha = 0.55,
	},
	-- Boss personal loot (S30, DESIGN §16): a personal Legendary is usable by the winner's class with chance
	-- `legendaryClassShare`; a personal Mythic is one of the boss's named items with chance `mythicNamedShare`
	-- (only those the winner's class can use), otherwise a rolled Mythic of a base usable by the winner's class.
	-- S87: a Mythic always fits the winner's class (no usable named item -> a rolled one, Loot.pickUsable).
	BossLoot = {
		legendaryClassShare = 0.8,
		mythicNamedShare = 0.5,
	},
	-- Upgrade gold (S32, Logic/Upgrade, DESIGN §6): round(ilvl x perIlvl(ilvl) x (N+1)^goldExponent), perIlvl =
	-- goldLow up to ilvl goldLowUntil, then rising linearly to goldHigh at ilvl 100 (before S32: 40 everywhere,
	-- +1 on a level 10 item cost more than all gold from level 10). +1..+3 on the weapon fits a level's income.
	-- S87 (balance plan C3, G9): goldHigh 40 -> 20 (+1..+3 was 1.7 levels of income at 100); 1-20 unchanged.
	-- S87 (balance plan C4): Legendary and Mythic items need a Legend Core from +legendCoreFrom (was +7).
	Upgrade = {
		goldLow = 4,
		goldLowUntil = 20,
		goldHigh = 20,
		goldExponent = 1.6,
		legendCoreFrom = 8,
	},
	-- W01: graphics levels (settings.quality "low" / "medium" / "high"; docs/WYGLAD.md §1: a separate low mode for weak
	-- phones). bloom multiplies Data/MapLooks bloom intensity; sunRays / clouds / farBlur switch those effects (far blur
	-- also needs a keyboard and mouse device); particles multiplies emitter rates (low keeps the S14 third).
	Graphics = {
		default = "high",
		levels = {
			low = { bloom = 0, sunRays = false, clouds = false, farBlur = false, particles = 1 / 3 },
			medium = { bloom = 0.6, sunRays = true, clouds = true, farBlur = false, particles = 0.7 },
			high = { bloom = 1, sunRays = true, clouds = true, farBlur = true, particles = 1 },
		},
		-- Seconds the post effects tween when the map or the level changes.
		fade = 1.5,
	},
	-- W01: the "from above" camera (settings.cameraMode "top"): pitch below the horizon (degrees), the zoom range
	-- (studs from the character) and, underground (caves, crypts, boss chambers), a shorter reach and a flatter pitch.
	Camera = {
		topPitch = 55,
		topMin = 22,
		topMax = 70,
		topDefault = 42,
		underPitch = 42,
		underMax = 34,
		-- Studs kept between the camera and a wall it would pass through.
		wallMargin = 1.5,
	},
	-- W02: the asset kit (Data/Kit, ReplicatedStorage.Assets.Kit): models in place of the generators' trees, rocks and
	-- bushes. `enabled = false` (or the map in `skipMaps`) builds the old pieces, for comparing; the admin command /kit
	-- switches it for the running server and rebuilds the current map.
	Kit = {
		enabled = true,
		skipMaps = {} :: { [string]: boolean },
	},
	-- S134j (docs/DESIGN.md §6a, Logic/Reroll): bonus reroll at the smith. Essence of one attempt by rarity, gold
	-- ilvl x Upgrade.goldPerIlvl(ilvl) x goldMul (the upgrade gold curve), each earlier attempt on the item adds `growth`
	-- to the multiplier, at most `growthCap` (gold rounded, essence rounded up). The Stone of Transmutation pays the
	-- essence of one attempt, never the gold. S134j model (tests/Balance.targetsS134j): essence dust only (1 / 1 / 2 / 3
	-- dust Unique / Heroic / Legendary / Mythic; shards or crystals put 10 attempts at 8-60 h of the level's grinding
	-- essence, the sink at 5-15x the band's essence and one stone above 10% of 2 h; docs/DECYZJE.md S134j), goldMul 1.8;
	-- growthCap 3 and Mythic 3 dust keep a stone used on a capped attempt (9 dust) under 10% of 2 h of grinding.
	Reroll = {
		essence = {
			unique = { id = "essence_dust", n = 1 },
			heroic = { id = "essence_dust", n = 1 },
			legendary = { id = "essence_dust", n = 2 },
			mythic = { id = "essence_dust", n = 3 },
		},
		goldMul = 1.8,
		growth = 0.25,
		growthCap = 3,
	},
	-- Streaming (S20, decision in docs/DECYZJE.md): also set in default.project.json (Workspace properties).
	StreamingTargetRadius = 512,
	StreamingMinRadius = 128,
}

return table.freeze(Config)
