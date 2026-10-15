--!strict
-- Shared data types. Persistent tables use string keys only (DataStore JSON and RemoteEvent
-- serialization both break on sparse numeric arrays), see docs/DECYZJE.md S01.

export type ClassId = "Warrior" | "Hunter" | "Mage" | "Cleric"
export type StatId = "str" | "dex" | "int" | "vit"
export type ResourceId = "mana" | "energy"
export type Slot =
	"weapon"
	| "offhand"
	| "helmet"
	| "armor"
	| "gloves"
	| "boots"
	| "necklace"
	| "ring1"
	| "ring2"
	| "talisman"
	| "backpack"

export type Bonus = { stat: string, v: number }

export type ItemInstance = {
	uid: string,
	id: string,
	rarity: number, -- S30: 1 Common, 2 Unique, 3 Heroic, 4 Legendary, 5 Mythic (Data/Rarities)
	ilvl: number,
	bonuses: { Bonus },
	up: number, -- upgrade level 0..9
	bound: boolean,
	n: number, -- stack size (1 for non-stackables)
	el: string?, -- element of a mage weapon ("fire" | "ice" | "lightning"), S18
	locked: boolean?, -- protected from selling and dismantling (S20)
	rv: number?, -- S30: rarity format version (2 = new ladder; Rarities.upgradeItem)
}

export type Stats = { str: number, dex: number, int: number, vit: number }

-- S68: where the cap of an item line or trait is enforced (TooltipModel.capValue): "stat" = Data/Stats cap,
-- "combat" = Data/Combat[key], "category" = Data/BuffCategories.caps[key], "luck" = Data/Luck[key].
export type CapRef = { source: "stat" | "combat" | "category" | "luck", key: string }

export type Location = { map: string, x: number, y: number, z: number }

export type PotionBar = { hp: string?, mana: string?, energy: string? }

-- S27: an active side quest in the save. `progress` per objective (dense list), `used` anchors already counted by
-- `use` objectives, `choice` the rolled reward items (rolled once, when the quest is complete).
export type SideEntry = {
	progress: { number },
	used: { string },
	choice: { ItemInstance }?,
}

-- S56 (ROZWOJ 3.2): the active build set's path state (filled from S57 on).
export type PathState = {
	main: string?,
	nodes: { [string]: number }, -- nodeId -> rank
	bp: { [string]: "a" | "b" }, -- "<skillId>:<5|10>" -> option; same shape as Logic/Skills.Choices
	freeUsed: boolean,
}
export type BuildSet = { path: PathState, stats: Stats, statPoints: number, hotbar: { [string]: string } }
-- S96: mounts of a character (Data/Mounts ids; lvl 1..Config.Mount.maxLevel).
export type MountState = { owned: { [string]: { lvl: number } }, active: string?, riding: boolean }

-- S125: the character's weekly EXP (Logic/Leaderboard.addWeekly).
export type ExpWeek = { week: number, exp: number, b: number }

export type CharacterData = {
	id: string,
	name: string,
	class: ClassId,
	level: number,
	exp: number,
	stats: Stats,
	statPoints: number,
	hotbar: { [string]: string }, -- "1".."10" -> skillId
	path: PathState,
	buildSlot: number, -- 1 | 2 (S58)
	buildOther: BuildSet?,
	reworkNotice: boolean, -- S56: show "Rozwój postaci się zmienił" once
	potionBar: PotionBar,
	equipment: { [string]: ItemInstance }, -- Slot -> item
	inventory: { [string]: ItemInstance }, -- "1".."N" -> item
	gold: number,
	location: Location,
	hp: number,
	mana: number,
	energy: number,
	blessing: { id: string, expiresAt: number }?,
	-- S30: boss kills today (UTC day `day`, `n` kills) and pity counters (kills without a Legendary / Mythic).
	bossRuns: { [string]: BossRun },
	bossPity: { [string]: BossPity },
	alchemy: { { recipeId: string, readyAt: number } },
	-- S11: main = the accepted story quest, daily = contracts.
	quests: {
		-- S102: `used` = anchors already counted by the `use` objectives of the active story quest (nil = none)
		main: { id: string, progress: { number }, used: { string }? }?,
		-- number of story quests before the next one in `Main.list` order; derived from `mainLast` / `main` on load
		-- (S102)
		mainDone: number,
		-- S102: id of the last story quest handed in; mainDone is recomputed from it on every load (Logic/StoryProgress),
		-- so story insertions (S103–S105) need no migration
		mainLast: string?,
		-- S102: story cutscenes (Data/Cutscenes): false = queued to watch, true = watched or skipped; no key = never
		-- triggered
		scenes: { [string]: boolean },
		daily: { day: number, list: { any }, rerolls: number },
		-- S98: weekly contracts (week = Logic/Time.weekNumber, list like daily) and the week's boss contract (nil = no
		-- boss open to the character or the week not rolled yet).
		weekly: {
			week: number,
			list: { any },
			rerolls: number,
			boss: { boss: string, progress: number, claimed: boolean }?,
		},
		-- S99: hunting contracts in order (Data/Quests/Contracts); done = handed in, active = the one in progress (one
		-- at a time)
		contract: { done: number, active: { level: number, progress: { number } }? },
		-- S27: side quests. active[id] = progress per objective, anchors already used, the rolled reward choice;
		-- done[id] = true once handed in.
		-- S98: every quest taken at an NPC (side arcs incl. the S96 stable arc, boss) keyed by id; Data/Quests.npcQuest
		-- resolves it
		side: {
			active: { [string]: SideEntry },
			done: { [string]: boolean },
		},
		-- S101b: dialogue answers, kept for good (Logic/Dialogue, recall): quest id -> answer id
		said: { [string]: string },
	},
	guildId: string?,
	reached100At: number?, -- S124: os.time() when the character reached Config.MaxLevel (leaderboard tie-break, Hall of Fame)
	lbHidden: boolean?, -- S124: test / staff character left out of every leaderboard (/lb hide)
	-- S125: EXP gained in the UTC week `week` (Logic/Time.weekNumber) from Data/Leaderboards.WEEK_SOURCES; `b` = bracket
	-- index of the last ranking write, 0 = never written
	expWeek: ExpWeek,
	-- S125: timed titles, title id -> unix time until which it is unlocked (weekly ranking; S129 Blood Moon, S130
	-- tournament). Expired entries are removed on entering the world.
	timedTitles: { [string]: number },
	auctions: { [string]: boolean }, -- S13: ids of this character's auction listings
	guideDone: boolean, -- S14: the HUD guide was shown (or skipped)
	title: string?, -- S16 chosen title id; S59: nil = never chose (the main path title shows), Data/Titles.NONE = hidden
	pvpEnabled: boolean,
	elixirs: { [string]: number }, -- resistance stat -> expiresAt (Clock time)
	-- S122: Elixir of Wholeness uses on UTC `day` (Time.dayNumber) and the os.time when the next one is allowed
	fullElixir: { day: number, used: number, readyAt: number },
	pvp: { kills: number, deaths: number, duelsWon: number, duelsLost: number },
	-- S126: the ranked arena (Logic/ArenaRules; no migration, reconcile)
	arena: ArenaState,
	visitedMaps: { [string]: boolean },
	mapMarks: { MapMark }, -- S25: own map marks (Data/MapMarks icons, max Config.Nav.maxMarks)
	-- S96: owned mounts (lvl 1..Config.Mount.maxLevel), the chosen one and whether riding now (never survives a
	-- logout; MountService clears it)
	mounts: MountState,
	createdAt: number,
	playtime: number,
	-- S20: last items picked up (newest first, max 50) and Elite II respawn timers.
	lootLog: { LootLogEntry }?,
	e2timers: { Elite2Timer }?,
}

-- S126 (DESIGN-17 §6): the ranked arena of a character. `history` and `last` go beyond the contract (DECYZJE S126).
export type ArenaHistoryEntry = {
	t: number, -- unix time (Clock) of the end
	mode: string,
	opp: string, -- opponent's character name (3v3: the first of the other side, S128 may add more)
	oppClass: string,
	oppRating: number,
	score: number, -- 1 win, 0.5 draw, 0 loss
	rounds: string, -- "2:1" (own:opponent)
	delta: number, -- rating change (0 when unrated)
	rated: boolean,
}
export type ArenaSeasonSummary = {
	season: string,
	rating: number,
	peak: number,
	wins: number,
	losses: number,
	played: number,
	rewarded: boolean,
	-- S128: the 3v3 numbers of the closed season (nil in a summary written before S128)
	rating3: number?,
	peak3: number?,
	wins3: number?,
	losses3: number?,
	played3: number?,
}
export type ArenaState = {
	season: string, -- "YYYYMM" (UTC) of the numbers below; "" = never played
	rating: number,
	wins: number,
	losses: number,
	peak: number,
	played: number, -- rated matches this season (K = kNew below ELO.newGames)
	tokens: number, -- S128 (Arena Tokens); S126 only keeps it at 0
	daily: { day: number, n: number }, -- matches today (UTC day), S128 doubles tokens of the first 3
	vs: { [string]: number }, -- "<userId>_<slot>" -> matches today against them; key "day" holds the day number
	history: { ArenaHistoryEntry }, -- newest first, at most Data/Arena.LIMITS.history
	last: ArenaSeasonSummary?, -- the season closed by the last soft reset (S128 pays rewards from it)
	-- S128 (DESIGN-17 §6): team rating, tokens week, season titles and rewards.
	rating3: number,
	peak3: number,
	wins3: number,
	losses3: number,
	played3: number,
	vs3: { [string]: number }, -- 3v3 matches today against an opponent (same rule as vs)
	tokensWeek: { week: number, n: number }, -- tokens earned in UTC week `week` (Logic/Time.weekNumber)
	titles: { [string]: string }, -- [tier] = season id of the latest finished season at this tier (Data/Titles)
	pendingReward: { season: string, tier: string, shards: number }?, -- the season mail still to send
}
-- S126: the runtime arena branch `arenaLive` (ArenaService; never saved): the queue, the offer, the match.
export type ArenaLive = {
	-- S127: scope "global" | "local"; window = the rating window now (+-N); waitingLocal = past the global wait
	queue: {
		mode: string,
		bracket: string,
		since: number,
		scope: string,
		waiting: number?,
		window: number?,
		waitingLocal: boolean?,
		members: { { name: string, class: string, level: number } }?, -- S128: a party team in the 3v3 queue
	}?,
	penaltyUntil: number?,
	-- S127: scope = where the match is played ("global": an arena server, "local": this server); fallback = a local
	-- offer after the global wait (declining it costs nothing)
	offer: {
		id: string,
		expiresAt: number,
		accepted: boolean,
		mode: string,
		unrated: boolean,
		vs: number, -- matches against this opponent today (the warning of an unrated offer)
		opp: { name: string, class: string, level: number, rating: number },
		scope: ("global" | "local")?,
		fallback: boolean?,
		combat: boolean?, -- S127: the player is in a fight now (Accept waits; no answer then costs nothing)
		-- S128 (3v3): the names of the own team and of the opponents (opp = the first opponent)
		mine: { string }?,
		them: { string }?,
	}?,
	match: {
		id: string,
		mode: string,
		phase: "waiting" | "countdown" | "fight" | "between" | "done",
		round: number,
		maxRounds: number,
		score: { number },
		side: number,
		endsAt: number?,
		potionsLeft: number,
		names: { { string } },
		queued: number?, -- "waiting": the place in the line for the sand
		-- S128 (3v3): the fighters of each side (hp at most 4 updates a second) and the own side
		teams: { { { name: string, class: string, out: boolean, hp: number, maxHp: number } } }?,
		myTeam: number?,
		tokens: number?, -- S128: the Arena Tokens this match gave (the result screen)
		tokensReason: string?,
		winner: number?, -- S128: the winning side once the match is decided (0 = none)
	}?,
	transfer: ("toArena" | "home")?, -- S127: a teleport between servers is on its way (the client's overlay)
	returnAt: number?, -- S127: on the arena server, the server time the way back starts
}

export type BossRun = { day: number, n: number, k: number? } -- n = attempts, k = kills
export type BossPity = { leg: number, myth: number }

export type LootLogEntry = {
	id: string,
	rarity: number,
	ilvl: number,
	el: string?,
	at: number,
	src: string?,
	map: string?,
}

-- Own map mark (S25): map-relative position and an icon id from Data/MapMarks.
export type MapMark = { map: string, x: number, z: number, icon: string }

-- Elite II respawn window after a kill (S20, DESIGN §15.3): server time from / to, on server `job`.
export type Elite2Timer = { spawner: string, kind: string, map: string, from: number, to: number, job: string }

export type Settings = {
	lang: string, -- "" = not chosen yet (client picks from Roblox locale)
	volume: number,
	dmgNumbers: boolean, -- before S29; kept for old saves (see dmgMode)
	-- S29: "all" | "mine" (mine and received) | "off"; unset on old saves (DamageText.mode reads dmgNumbers then)
	dmgMode: string?,
	bindConfirm: boolean, -- ask before an item binds on equip
	quickCast: boolean, -- area skills cast on key press instead of on release
	-- S14 options window
	musicVolume: number,
	ambientVolume: number, -- S26: area ambience loops (birds, wind, frogs, the waterfall)
	quality: string, -- "high" | "low" (fewer particles)
	minimapRotate: boolean,
	cameraSens: number, -- mouse/touch camera sensitivity multiplier
	sellConfirm: boolean, -- ask before selling valuable items
	autoTarget: boolean, -- S16: after a kill, target the next monster fighting us
	-- S20: loot comfort and world detail
	betterItem: boolean, -- "Better item!" card
	lootHideBelow: number, -- hide equipment bags below this rarity (0 = off)
	lootAutoFrom: number, -- Auto-loot picks up equipment from this rarity (0 = all)
	decor: string, -- "low" | "mid" | "high": client decoration radius
	groupRings: boolean, -- S19: coloured rings under monster groups
	keys: { [string]: string }, -- S17: rebound keys, action -> Enum.KeyCode name (Data/Keybinds)
	devPins: { string }, -- S23: dev panel favourites (admins)
	mapCloseOnWalk: boolean, -- S25: the world map closes after "Walk"
	barks: boolean, -- S101b: NPC comments during quests (BarkController)
}

-- S121 (DESIGN-17 §2): UTC day of the last daily shards, free respawns used on respawnDay, the last free recall
-- (Clock seconds) and the months whose VIP cosmetic was given ("YYYYMM" -> true).
export type VipState = {
	shardDay: number,
	respawnDay: number,
	respawnN: number,
	recallAt: number,
	months: { [string]: boolean },
}

-- S121: a saved look: the equipped cosmetic per kind (without "pet") and the pet.
export type Outfit = { equipped: { [string]: string }, pet: string? }

export type AccountData = {
	schema: number,
	characters: { [string]: CharacterData }, -- "1".."5" -> character (S121: slots 4-5 need passes to create)
	lastCharacter: number?,
	dragonShards: number,
	deposit: { size: number, items: { [string]: ItemInstance } },
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	pets: { owned: { [string]: boolean }, equipped: string? },
	settings: Settings,
	purchases: { [string]: number },
	dailyLimits: { day: number, protectScrolls: number }, -- pre-S120, read-only (Logic/Premium.limitsOf)
	-- S120: Logic/Premium.ShopLimits
	shopLimits: { day: number, week: number, daily: { [string]: number }, weekly: { [string]: number } },
	login: { day: number, last: number }, -- S100: login reward streak (account-wide, UTC days)
	vip: VipState, -- S121: VIP benefits (Logic/Vip)
	outfits: { Outfit }, -- S121: saved looks (Garderoba+), 1..Products.OUTFITS_PLUS without holes
	-- S122 Cloak of Luring: real-time end (os.time) and the player's switch; active = on and untilTs > now
	lure: { untilTs: number, on: boolean },
	packs: { [string]: boolean }, -- S123: starter packs bought (key -> true), once per account
	grantedPasses: { [string]: boolean }, -- S123: passes granted by a starter pack (MonetizationService.HasPass)
	stats: { createdAt: number, playtime: number },
	redeemed: { [string]: number }, -- S17: reward code -> os.time() of redemption
}

-- Character summary shown on the selection screen.
export type SlotSummary = {
	name: string,
	class: ClassId,
	level: number,
	map: string,
}

export type SessionPhase = "loading" | "select" | "playing"

-- Root of the replicated per-player state tree (what the client sees).
-- `account` is replicated without `characters`; the active character lives in `character`.
-- Replicated result of StatService (values/breakdown from Logic/StatCalc).
export type DerivedState = {
	primary: Stats,
	values: { [string]: number },
	breakdown: { [string]: { { key: string, value: number, pct: boolean? } } },
	-- Merged modifier totals and weapon, so the client can preview stat allocation.
	mods: { key: string, flat: { [string]: number }?, pct: { [string]: number }? },
	weapon: { dmg: number, mdmg: number, speed: number, ranged: boolean }?,
}

export type PvpZone = "green" | "yellow" | "red"

export type ZoneState = { map: string, pvp: PvpZone, nameKey: string }

-- Server time (workspace:GetServerTimeNow()) based timers.
-- S22: `respawnAt` opens the choice ("city" / "here"), `deadline` defaults to the city; `dungeon` = "here" means
-- the dungeon entrance.
export type DeathState = {
	diedAt: number,
	respawnAt: number,
	deadline: number,
	cost: number,
	dungeon: boolean?,
	hereCost: number?, -- FIX 2026-10-15: gold for "respawn here" (0 or nil: free)
}

export type PvpState = { pendingTarget: boolean?, switchAt: number?, lockedUntil: number? }

-- S122: the Cloak of Luring at runtime (LureService; only while it has time and is on): the Locale key of the block
-- that pauses it (Logic/UseBlocks.key) and how many monsters the last pulse drew.
export type LureRuntime = { blocked: string?, pulled: number? }

export type ClientState = {
	account: AccountData?,
	slots: { [string]: SlotSummary },
	character: CharacterData?,
	session: { phase: SessionPhase, slot: number?, dataMock: boolean },
	derived: DerivedState?,
	zone: ZoneState?,
	death: DeathState?,
	pvp: PvpState?,
	-- S101: the running world event (Logic/WorldEvents.Public + `mine = { points, ok }`), WorldEventService
	worldEvent: { [string]: any }?,
	-- S101b: the quest companion (CompanionService; never saved): whose figure, for which quest, the phase of
	-- Logic/Companion ("join" | "follow" | "lead" | "wait" | "arrived" | "back")
	companion: CompanionState?,
	lure: LureRuntime?, -- S122
	arenaLive: ArenaLive?, -- S126
}

export type CompanionState = { npc: string, quest: string, mode: "follow" | "lead", phase: string }

export type PathKey = string | number
export type Path = { PathKey }

export type DiffOp = "set" | "insert" | "remove"
export type Diff = { op: DiffOp, path: Path, value: any?, index: number? }

return nil
