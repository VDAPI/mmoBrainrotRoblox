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
	BuildSetCooldown = 5, -- S58: seconds between build set switches (ROZWOJ 2.9)
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
	LootLifetime = 120, -- seconds a loot bag stays
	LootPickupRange = 12, -- studs (+ lag tolerance in LootService)
	DefaultCapacity = 20, -- inventory slots without a backpack item

	-- Live monsters allowed on one server (spawners stop when reached).
	MaxActiveMonsters = 600, -- S19: groups near players only (sleeping groups despawn after 90 s)

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
	CaveLights = { low = 8, mid = 16, high = 24 },
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
	Boss = {
		dailyRuns = 3,
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
	-- Streaming (S20, decision in docs/DECYZJE.md): also set in default.project.json (Workspace properties).
	StreamingTargetRadius = 512,
	StreamingMinRadius = 128,
}

return table.freeze(Config)
