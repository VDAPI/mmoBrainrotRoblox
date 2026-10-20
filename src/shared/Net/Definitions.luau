--!strict
-- Every remote in the game. Add new remotes here only; Net creates the instances on the server.
--
-- kind: "event" (RemoteEvent) | "function" (RemoteFunction, client -> server only)
-- dir:  "c2s" client -> server, "s2c" server -> client, "both"
-- rate: allowed calls per second per player (c2s only; burst = 2x rate)
-- args: argument spec checked by Net before the handler runs (c2s only), see Net.Check

export type Definition = {
	kind: "event" | "function",
	dir: "c2s" | "s2c" | "both",
	rate: number?,
	args: { string }?,
}

local Definitions: { [string]: Definition } = {
	-- State replication (server -> owner)
	StateSnapshot = { kind = "event", dir = "s2c" },
	StateDiff = { kind = "event", dir = "s2c" },
	RequestSnapshot = { kind = "event", dir = "c2s", rate = 0.5, args = {} },

	-- Notifications
	Toast = { kind = "event", dir = "s2c" }, -- (key, args?, kind?)
	SystemMessage = { kind = "event", dir = "s2c" }, -- (key, args?) shown in the chat system channel

	-- Character selection
	CheckName = { kind = "function", dir = "c2s", rate = 1, args = { "string" } },
	-- (slot, classId, name, face?, skin?, hair?), S132 look; W10: (..., hairColor?, brows?, beard?, build?, paint?,
	-- paintColor?)
	CreateCharacter = {
		kind = "function",
		dir = "c2s",
		rate = 0.5,
		args = {
			"integer",
			"string",
			"string",
			"string?",
			"string?",
			"string?",
			"string?",
			"string?",
			"string?",
			"string?",
			"string?",
			"string?",
		},
	},
	DeleteCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer", "string" } },
	PlayCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer" } },
	SwitchCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = {} },
	-- Safe placement (Placement): the server holds the character anchored at a spawn / teleport target until the
	-- client has the ground under it streamed in. (token, target position) / (token)
	GroundCheck = { kind = "event", dir = "s2c" },
	GroundReady = { kind = "event", dir = "c2s", rate = 4, args = { "integer" } },

	-- Settings
	SetLanguage = { kind = "event", dir = "c2s", rate = 1, args = { "string" } },
	SetSetting = { kind = "event", dir = "c2s", rate = 2, args = { "string", "any" } }, -- (name, value), whitelisted
	RedeemCode = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (code), S17
	ClaimLoginReward = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- S100: () -> (ok, errKey?, result?)
	SetKeybind = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (action | "*", key?), S17

	-- Stats and progression
	AllocateStats = { kind = "function", dir = "c2s", rate = 2, args = { "table", "integer?" } }, -- ({ str, dex, int, vit }, buildSlot?)
	LevelUp = { kind = "event", dir = "s2c" }, -- (player, newLevel, statPoints, pathPoints, fromLevel, skillPoints) to nearby players; S59 adds fromLevel, S137 skillPoints

	-- Combat
	-- (entityId or nil to clear, attack: false keeps the target but stops the auto-attack; S18)
	SetTarget = { kind = "event", dir = "c2s", rate = 12, args = { "string?", "boolean?" } },
	SetSprint = { kind = "event", dir = "c2s", rate = 10, args = { "boolean" } }, -- S18
	SetMounted = { kind = "function", dir = "c2s", rate = 4, args = { "boolean" } }, -- S96: (true = mount, false = dismount) -> (ok, errKey?)
	MountUpgrade = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (mount id) at the stablemaster, S97
	MountSetActive = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (mount id), S97
	-- S20: quick sell (npcId, max rarity 1..2), item lock (backpack index)
	SellAll = { kind = "function", dir = "c2s", rate = 2, args = { "string", "integer" } },
	ToggleLock = { kind = "function", dir = "c2s", rate = 6, args = { "integer" } },
	AdminClient = { kind = "event", dir = "s2c" }, -- (action, arg?) client-side admin helpers: "mapcache", "perf" (S20), "town" (S21), "portalpick", "anim" (S22), "nav", "navdebug" (S25)
	AdminRun = { kind = "function", dir = "c2s", rate = 6, args = { "string", "table" } }, -- (command, args) dev panel, admins only (S23)
	MobViz = { kind = "event", dir = "s2c" }, -- ("show", {target, variant, anim}) | ("clear") | ("stats"): admin look preview (S24)
	AttackRejected = { kind = "event", dir = "s2c" }, -- (reason locale key), at most one per 2 s (S18)
	SetTitle = { kind = "function", dir = "c2s", rate = 2, args = { "string?" } }, -- (titleId or nil = no title), S16; S59 stores Data/Titles.NONE
	CombatFx = { kind = "event", dir = "s2c" }, -- batched { k = "dmg" | "heal" | "atk" | "tele" | "teleCancel" | "blow" | "reward", ... }

	-- Items (S04). Functions answer (ok, errorKey?).
	MoveItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer" } }, -- (from, to)
	SplitStack = { kind = "function", dir = "c2s", rate = 4, args = { "integer", "integer" } }, -- (from, amount)
	SortInventory = { kind = "function", dir = "c2s", rate = 1, args = {} },
	DestroyItem = { kind = "function", dir = "c2s", rate = 4, args = { "integer" } },
	UseItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer" } },
	EquipItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer", "string?" } }, -- (index, slot?)
	UnequipItem = { kind = "function", dir = "c2s", rate = 6, args = { "string", "integer?" } }, -- (slot, index?)
	SwapRings = { kind = "function", dir = "c2s", rate = 4, args = {} }, -- S29: ring1 <-> ring2
	SetPotionSlot = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (hp|mana|energy, itemId?)
	UsePotion = { kind = "function", dir = "c2s", rate = 6, args = { "string" } },
	PickupLoot = { kind = "function", dir = "c2s", rate = 10, args = { "string" } },
	LootSpawn = { kind = "event", dir = "s2c" }, -- (bag) only to the owner
	LootUpdate = { kind = "event", dir = "s2c" }, -- (bagId, items)
	LootRemove = { kind = "event", dir = "s2c" }, -- (bagId)
	LootPicked = { kind = "event", dir = "s2c" }, -- (items) what went into the backpack (legendary reveal)
	Announce = { kind = "event", dir = "s2c" }, -- (key, args) banner + system chat for everyone

	-- Skills (S05)
	SetHotbar = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "string?" } }, -- (slot 1..8, skillId?) the active pool's bar
	PutOnBar = { kind = "function", dir = "c2s", rate = 6, args = { "string", "integer?" } }, -- (skillId, slot 1..8?) S56
	AckRework = { kind = "event", dir = "c2s", rate = 0.5, args = {} }, -- S56: the rework notice was seen
	-- Skill points and weapon pools (S137, DESIGN-18 §11; PathService); every handler returns (ok, errKey?)
	AllocateSkills = { kind = "function", dir = "c2s", rate = 2, args = { "string", "table" } }, -- (poolId, { [skillId] = +n })
	RefundSkillRank = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string" } }, -- (poolId, skillId)
	ResetSkills = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- S138: the full reset (ranks and nodes; scroll)
	SetPoolBar = { kind = "function", dir = "c2s", rate = 10, args = { "string", "integer", "string?" } }, -- (poolId, slot 1..8, skillId?)
	-- Class paths (S57, PathService; S138: directions, no main path); every handler returns (ok, errKey?)
	BuyNode = { kind = "function", dir = "c2s", rate = 8, args = { "string" } }, -- (nodeId)
	RefundNode = { kind = "function", dir = "c2s", rate = 8, args = { "string" } }, -- (nodeId)
	ResetPaths = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- refund every node (S138: gold from L20)
	ChooseBreakpoint = { kind = "function", dir = "c2s", rate = 2, args = { "string", "integer", "string" } }, -- (skillId, 5|10, "a"|"b")
	SwitchBuildSet = { kind = "function", dir = "c2s", rate = 1, args = {} }, -- S58: build set 1 <-> 2 (ROZWOJ 2.9)
	CopyBuildSet = { kind = "function", dir = "c2s", rate = 1, args = {} }, -- S58: copy the active set onto the other one
	CastSkill = { kind = "function", dir = "c2s", rate = 8, args = { "string", "string?", "any?" } }, -- (skillId, targetId?, aim: Vector3?)
	SkillFx = { kind = "event", dir = "s2c" }, -- skill visuals for players nearby

	-- City (S06). All validate the distance to the NPC on the server.
	Buy = { kind = "function", dir = "c2s", rate = 6, args = { "string", "string", "integer" } }, -- (npcId, itemId, n)
	Sell = { kind = "function", dir = "c2s", rate = 8, args = { "string", "table" } }, -- (npcId, { index }); S134f: 4 → 8
	Buyback = { kind = "function", dir = "c2s", rate = 4, args = { "string", "integer" } }, -- (npcId, buyback index)
	HealMe = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	BuyBackpack = { kind = "function", dir = "c2s", rate = 2, args = { "string", "string" } }, -- (npcId, itemId)
	DepositItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer?" } }, -- (inv index, vault index?)
	WithdrawItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer?" } }, -- (vault index, inv index?)
	MoveDeposit = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer" } },
	SortDeposit = { kind = "function", dir = "c2s", rate = 1, args = {} },
	Craft = { kind = "function", dir = "c2s", rate = 4, args = { "string" } }, -- (recipeId)
	UpgradeItem = { kind = "function", dir = "c2s", rate = 3, args = { "string", "string", "boolean" } }, -- ("inv"|"eq", key, protect)
	Dismantle = { kind = "function", dir = "c2s", rate = 3, args = { "table" } }, -- ({ index })
	DismantleAll = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (max rarity)
	UnbindItem = { kind = "function", dir = "c2s", rate = 2, args = { "string", "string" } }, -- ("inv"|"eq", key)
	-- S134j: ("inv"|"eq", key, line index, expected stat of that line, use stone) -> (ok, err, { index, old, new, n })
	RerollBonus = {
		kind = "function",
		dir = "c2s",
		rate = 2,
		args = { "string", "string", "integer", "string", "boolean" },
	},
	-- S156: ("inv"|"eq", key, the item's line signature Reroll.signature) -> (ok, err, { changes, n })
	RerollAll = { kind = "function", dir = "c2s", rate = 2, args = { "string", "string", "string" } },
	-- S154: ("inv"|"eq", key, look key or "" to remove, expected item uid) -> (ok, err, { look })
	TransmogApply = {
		kind = "function",
		dir = "c2s",
		rate = 2,
		args = { "string", "string", "string", "string" },
	},

	-- Alchemy, blessings, gathering, fishing, stones (S07)
	StartRecipe = { kind = "function", dir = "c2s", rate = 3, args = { "string", "string" } }, -- (npcId, recipeId)
	CollectAlchemy = { kind = "function", dir = "c2s", rate = 3, args = { "string" } }, -- (npcId) -> collected count
	UseBlessing = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (inv index), replaces active
	StartGather = { kind = "function", dir = "c2s", rate = 3, args = { "string" } }, -- (node uid) -> (ok, err, seconds)
	CancelGather = { kind = "event", dir = "c2s", rate = 4, args = {} },
	StartFishing = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (node uid) -> (ok, err, sessionId)
	FishingBite = { kind = "event", dir = "s2c" }, -- (sessionId, { zone, speed, hits, timeLimit })
	FishingResult = { kind = "function", dir = "c2s", rate = 2, args = { "string", "integer" } }, -- (sessionId, hits)
	CancelFishing = { kind = "event", dir = "c2s", rate = 2, args = {} },
	UsePortal = { kind = "function", dir = "c2s", rate = 1, args = { "string", "string?" } }, -- (portal id, area id?) S22
	MapTransition = { kind = "event", dir = "s2c" }, -- (mapId) shows the loading screen, (nil) hides it
	-- Own map marks (S25): (map, x, z, icon id) map-relative studs / (index); answer (ok, errorKey?)
	MapMarkAdd = { kind = "function", dir = "c2s", rate = 2, args = { "string", "number", "number", "string" } },
	MapMarkRemove = { kind = "function", dir = "c2s", rate = 4, args = { "integer" } },
	UseMapStone = { kind = "function", dir = "c2s", rate = 1, args = { "integer", "string", "string?" } }, -- (inv index, target id, area id?) S22

	-- Parties and dungeons (S09)
	PartyInvite = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (character or player name)
	PartyInviteUser = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId)
	PartyInvited = { kind = "event", dir = "s2c" }, -- (fromName, seconds)
	PartyRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	PartyLeave = { kind = "function", dir = "c2s", rate = 1, args = {} },
	PartyKick = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } },
	PartyPromote = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } },
	DungeonInfo = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (region) -> info
	EnterDungeon = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (region)
	BossAnnounce = { kind = "event", dir = "s2c" }, -- (key, args) big centred message (boss fights, duels)
	-- S134f: the ready check at the dungeon gate (the asked member's answer: true = ready) -> (ok, errKey?)
	DungeonReady = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	-- S134f: after a boss / Elite II / Invasion fight, the party's table (FightLogService) { kind, key, nameKey,
	-- outcome, time, rows, deaths, dodged, aimed, drop? }
	FightSummary = { kind = "event", dir = "s2c" },
	-- S149b: the world boss reward card ({ boss, exp?, gold?, items? = { { id, r, up?, n? } }, reason?, level? }): the
	-- winner's loot, or the reason he got none ("level" | "share" | "claimed"); the client checks every field
	WorldBossReward = { kind = "event", dir = "s2c" },
	-- S151: an achievement done ({ id, reward = { title?, cosmetic?, shards?, gold? } }) or the catch-up of old progress
	-- ({ backfill = n }); AchievementController shows the toast (or a system chat line with the setting off)
	AchievementDone = { kind = "event", dir = "s2c" },
	-- S151b: follow (true) or stop following (false) an achievement in the HUD tracker: (achId, on) -> (ok, errKey?)
	AchievementTrack = { kind = "function", dir = "c2s", rate = 2, args = { "string", "boolean" } },
	-- S134f: the party finder board (PartyFinderService): (kind, target, minLevel, maxLevel, { classId }) -> (ok, errKey?)
	FinderPost = {
		kind = "function",
		dir = "c2s",
		rate = 1,
		args = { "string", "string", "integer", "integer", "table" },
	},
	FinderCancel = { kind = "function", dir = "c2s", rate = 2, args = {} },
	FinderJoin = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (listing id) -> (ok, errKey?)
	FinderWatch = { kind = "event", dir = "c2s", rate = 2, args = { "boolean" } }, -- the board is open (state `finder`)

	-- Quests (S11)
	QuestTalk = { kind = "function", dir = "c2s", rate = 4, args = { "string" } }, -- (npcId) counts "talk" objectives
	QuestAccept = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (npcId)
	QuestTurnIn = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (npcId)
	DailyClaim = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (contract index)
	-- S98: weekly contracts and the week's boss contract, collected at the board
	WeeklyClaim = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (weekly contract index)
	BossContractClaim = { kind = "function", dir = "c2s", rate = 2, args = {} }, -- () the week's boss contract
	QuestCompleted = { kind = "event", dir = "s2c" }, -- (titleKey, args?) big message + sound
	-- S101b: (questId, choiceId) the player's answer on a quest page (Logic/Dialogue.canSay, quests.said)
	QuestSay = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string" } },
	-- S102: (sceneId) the client finished or skipped a queued story cutscene
	CutsceneDone = { kind = "function", dir = "c2s", rate = 4, args = { "string" } },
	-- Hunting contracts (S99): (npcId) the contract board or the scout of the contract's region. S134k: also the
	-- Huntmaster; ContractAccept takes every contract that NPC gives (-> ok, err, count), ContractTurnIn hands in every
	-- finished one it takes (-> ok, err, sums); (npcId, level) one contract; (level) drops an active one
	ContractAccept = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	ContractTurnIn = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	ContractAcceptOne = { kind = "function", dir = "c2s", rate = 4, args = { "string", "integer" } },
	ContractAbandon = { kind = "function", dir = "c2s", rate = 4, args = { "integer" } },
	-- S134k: (npcId, entry key of Data/HuntShop, amount) a purchase at the Huntmaster for Hunter's Marks
	HuntShopBuy = { kind = "function", dir = "c2s", rate = 3, args = { "string", "string", "integer" } },
	-- Side quests (S27): (questId) / (questId, reward choice 1..3) / (questId) / (quest anchor id) / ()
	SideAccept = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	SideTurnIn = { kind = "function", dir = "c2s", rate = 2, args = { "string", "integer?" } },
	SideAbandon = { kind = "function", dir = "c2s", rate = 1, args = { "string" } },
	QuestUse = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	CancelQuestUse = { kind = "event", dir = "c2s", rate = 4, args = {} },

	-- PvP, duels and trade (S10)
	KillFeed = { kind = "event", dir = "s2c" }, -- (killerName, victimName)
	DuelChallenge = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId)
	DuelInvited = { kind = "event", dir = "s2c" }, -- (fromName, seconds)
	DuelRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	-- Arena (S126): the ranked queue of this server, the ready check of a match offer, watching from the stands and the
	-- window's status (-> { scope, waiting = { [bracket] = n }, busy = { kind, names }?, pending })
	ArenaJoin = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (mode)
	ArenaLeave = { kind = "function", dir = "c2s", rate = 1, args = {} },
	ArenaRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } }, -- (accept)
	ArenaSpectate = { kind = "function", dir = "c2s", rate = 0.5, args = {} },
	ArenaStatus = { kind = "function", dir = "c2s", rate = 1, args = {} },
	-- S127: leave the arena server now (after the result); ArenaRespond also answers a global offer (same arguments)
	ArenaReturnNow = { kind = "function", dir = "c2s", rate = 0.5, args = {} },
	-- S128: the arena shop at the Arena Master (Data/Arena.SHOP key); 3v3 joins with ArenaJoin("3v3")
	ArenaShopBuy = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },
	-- S130: the Champion's Tournament (TourneyService); the state goes through the runtime branch `tourney`
	TourneySignup = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } }, -- (true = sign up, false = withdraw)
	TourneyRespond = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } }, -- (accept the invitation)
	TourneyLeave = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- back to the world from a tournament server
	TourneyInfo = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- signup count, mode, hall
	TradeRequest = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId)
	TradeInvited = { kind = "event", dir = "s2c" }, -- (fromName, seconds)
	TradeRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	TradeAddItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer" } }, -- (inventory index)
	TradeRemoveItem = { kind = "function", dir = "c2s", rate = 10, args = { "string" } }, -- (item uid)
	TradeSetGold = { kind = "function", dir = "c2s", rate = 6, args = { "number" } },
	TradeAccept = { kind = "function", dir = "c2s", rate = 4, args = { "boolean" } },
	TradeConfirm = { kind = "function", dir = "c2s", rate = 2, args = {} },
	TradeCancel = { kind = "event", dir = "c2s", rate = 2, args = {} },

	-- Guilds (S12). Member keys are "<userId>:<characterId>".
	GuildCreate = { kind = "function", dir = "c2s", rate = 0.5, args = { "string", "string" } }, -- (name, tag) at the guild master
	GuildInvite = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId)
	GuildInviteName = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (character name)
	GuildInvited = { kind = "event", dir = "s2c" }, -- (guildName, tag, fromName, seconds)
	GuildRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	GuildLeave = { kind = "function", dir = "c2s", rate = 0.5, args = {} },
	GuildKick = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (member key)
	GuildSetRank = { kind = "function", dir = "c2s", rate = 1, args = { "string", "string" } }, -- (member key, "officer"|"member")
	GuildTransfer = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (member key)
	GuildDisband = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (guild name as confirmation)
	GuildDeposit = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (gold)
	GuildUpgrade = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (skillId)
	GuildSetMotd = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } },
	GuildSetting = { kind = "function", dir = "c2s", rate = 1, args = { "string", "any" } }, -- (name, value), whitelisted
	GuildChatSend = { kind = "event", dir = "c2s", rate = 1, args = { "string" } }, -- relay of a guild channel line
	GuildChatLine = { kind = "event", dir = "s2c" }, -- (name?, text | key, args?) from other servers / system

	-- Mail and auction house (S13)
	MailClaim = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (parcel id) at the mailbox
	MailClaimAll = { kind = "function", dir = "c2s", rate = 0.5, args = {} }, -- -> (ok, err, count)
	MailRefresh = { kind = "function", dir = "c2s", rate = 0.2, args = {} },
	-- S133: a letter to a character by name ({ to, subject, body, gold, items = { backpack slot } }; the body can be
	-- longer than a string argument, so the letter is one table checked by MailService) and sending a letter back
	MailSend = { kind = "function", dir = "c2s", rate = 0.5, args = { "table" } },
	MailReturn = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (parcel id)

	-- Friends, ignored players and whispers (S133, SocialService)
	FriendInvite = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId) same server
	FriendInvited = { kind = "event", dir = "s2c" }, -- (fromName, seconds)
	FriendRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
	FriendRemove = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (userId)
	IgnoreAdd = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (userId)
	IgnoreName = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (character name)
	IgnoreRemove = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (userId)
	WhisperOpen = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId) -> (ok, err, channel, name)
	WhisperReady = { kind = "event", dir = "s2c" }, -- (channel name, character name, text to send) after "/w"
	WhisperFailed = { kind = "event", dir = "s2c" }, -- (error key, name) after "/w"
	SocialHintSeen = { kind = "event", dir = "c2s", rate = 0.5, args = {} }, -- the one-time player menu hint
	-- S150: friends 2.0 (FriendService). The window gets the runtime branch `friends` while it is open (FriendsWatch);
	-- (friend userId) -> (ok, errKey?) for a join and a party invitation to another server
	FriendJoin = { kind = "function", dir = "c2s", rate = 0.2, args = { "integer" } },
	FriendPartyInvite = { kind = "function", dir = "c2s", rate = 0.2, args = { "integer" } },
	FriendPartyInvited = { kind = "event", dir = "s2c" }, -- (fromName, level, classId, seconds)
	FriendPartyRespond = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } },
	FriendsWatch = { kind = "event", dir = "c2s", rate = 2, args = { "boolean" } },
	-- user ids of Roblox friends the client sees in this game (Player:GetFriendsOnlineAsync), checked by the server
	FriendsRobloxHint = { kind = "event", dir = "c2s", rate = 0.1, args = { "table" } },
	AuctionSearch = { kind = "function", dir = "c2s", rate = 2, args = { "table", "integer", "boolean" } }, -- (filter, page, descending)
	AuctionDetails = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (listing id) -> full item
	AuctionList = { kind = "function", dir = "c2s", rate = 1, args = { "integer", "integer", "integer" } }, -- (inv index, price, hours)
	AuctionBuy = { kind = "function", dir = "c2s", rate = 1, args = { "string", "integer" } }, -- (listing id, expected price)
	AuctionCancel = { kind = "function", dir = "c2s", rate = 1, args = { "string" } },
	AuctionMine = { kind = "function", dir = "c2s", rate = 0.5, args = {} },
	AuctionPrice = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (item id) -> average unit price?

	-- Monetisation, premium shop, cosmetics (S14)
	BuyProduct = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (product key) prompt or simulated grant
	BuyPass = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (pass key)
	PremiumBuy = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (shop key) for Dragon Shards
	LureToggle = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } }, -- (on) Cloak of Luring switch, S122
	-- (on, hp %, class resource %) S134d: Auto Potions switch and thresholds (Logic/AutoPotion.clampThreshold)
	AutoPotionSet = { kind = "function", dir = "c2s", rate = 4, args = { "boolean", "number", "number" } },
	AutoGrind = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } }, -- (on) S134d: Auto Hunt start / stop
	-- (cosmetic id, expected price) S123: the weekly price can change at Monday 00:00 UTC
	PremiumBuyCosmetic = { kind = "function", dir = "c2s", rate = 2, args = { "string", "number?" } },
	PremiumRename = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (new character name)
	CosmeticEquip = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (kind, id | nil)
	-- (face, skin, hair), S132: free once, then gold at the barber (CosmeticService, Logic/CharacterLook.canChange)
	-- W10: (face, skin, hair, hairColor?, brows?, beard?, build?, paint?, paintColor?): a missing field keeps its value
	SetCharacterLook = {
		kind = "function",
		dir = "c2s",
		rate = 1,
		args = { "string", "string", "string", "string?", "string?", "string?", "string?", "string?", "string?" },
	},
	PlayEmote = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (emote cosmetic id) S123
	-- S155: the hands-on tutorial (TutorialService): a client step (Tutorial.clientAllowed: move, backpack; the server
	-- sees the rest itself) and skipping the rest (the S14 GuideDone is gone)
	TutorialEvent = { kind = "event", dir = "c2s", rate = 2, args = { "string" } }, -- client steps only (Tutorial.clientAllowed)
	TutorialSkip = { kind = "event", dir = "c2s", rate = 0.5, args = {} },
	BuySubscription = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (subscription key) prompt or simulated, S121
	VipRecall = { kind = "function", dir = "c2s", rate = 1, args = {} }, -- free return to the city (VIP), S121
	PremiumFunnel = { kind = "event", dir = "c2s", rate = 2, args = { "string", "string" } }, -- (funnel, step) S131: shop/VIP window funnel steps from the client
	VipRespawn = { kind = "function", dir = "c2s", rate = 1, args = {} }, -- free instant respawn once a day (VIP), S121
	OutfitSave = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (outfit index) saves the current look, S121
	OutfitWear = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (outfit index), S121

	-- Season pass (S152, SeasonService; the state is account.season): the premium track of the running season for
	-- Dragon Shards; one reward (tier, "free" | "premium", season id: nil = the running one, or the previous one in its
	-- grace days) -> (ok, errorKey?, { granted = { Reward } }); every reached reward of both seasons -> the same
	SeasonBuy = { kind = "function", dir = "c2s", rate = 1, args = {} },
	SeasonClaim = { kind = "function", dir = "c2s", rate = 6, args = { "integer", "string", "string?" } },
	SeasonClaimAll = { kind = "function", dir = "c2s", rate = 1, args = {} },

	-- Returning players (S153, ReturningService; the state is account.returning): the "What has changed" letter was read
	-- up to this Data/Changelog id (an id of the log above the saved one; anything else is ignored)
	ChangelogSeen = { kind = "event", dir = "c2s", rate = 0.5, args = { "integer" } }, -- (highest id read)

	-- Leaderboards (S124): (board instance id) -> (true, Logic/Leaderboard.Snapshot) | (false, errorKey)
	LeaderboardGet = { kind = "function", dir = "c2s", rate = 2, args = { "string" } },

	-- Profiles (S15)
	PlayerProfile = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (userId) same server

	-- PvP and death
	SetPvp = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } },
	RespawnNow = { kind = "function", dir = "c2s", rate = 1, args = {} },
	RespawnChoice = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- ("city" | "here"), S22
}

return table.freeze(Definitions)
