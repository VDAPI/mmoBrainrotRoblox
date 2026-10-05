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
	CreateCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer", "string", "string" } },
	DeleteCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer", "string" } },
	PlayCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = { "integer" } },
	SwitchCharacter = { kind = "function", dir = "c2s", rate = 0.5, args = {} },

	-- Settings
	SetLanguage = { kind = "event", dir = "c2s", rate = 1, args = { "string" } },
	SetSetting = { kind = "event", dir = "c2s", rate = 2, args = { "string", "any" } }, -- (name, value), whitelisted
	RedeemCode = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (code), S17
	SetKeybind = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (action | "*", key?), S17

	-- Stats and progression
	AllocateStats = { kind = "function", dir = "c2s", rate = 2, args = { "table" } }, -- ({ str, dex, int, vit })
	LevelUp = { kind = "event", dir = "s2c" }, -- (player, newLevel, statPoints, skillPoints) to nearby players

	-- Combat
	-- (entityId or nil to clear, attack: false keeps the target but stops the auto-attack; S18)
	SetTarget = { kind = "event", dir = "c2s", rate = 12, args = { "string?", "boolean?" } },
	SetSprint = { kind = "event", dir = "c2s", rate = 10, args = { "boolean" } }, -- S18
	-- S20: quick sell (npcId, max rarity 1..2), item lock (backpack index)
	SellAll = { kind = "function", dir = "c2s", rate = 2, args = { "string", "integer" } },
	ToggleLock = { kind = "function", dir = "c2s", rate = 6, args = { "integer" } },
	AdminClient = { kind = "event", dir = "s2c" }, -- (action) client-side admin helpers: "mapcache", "perf" (S20)
	AttackRejected = { kind = "event", dir = "s2c" }, -- (reason locale key), at most one per 2 s (S18)
	SetTitle = { kind = "function", dir = "c2s", rate = 2, args = { "string?" } }, -- (titleId or nil), S16
	CombatFx = { kind = "event", dir = "s2c" }, -- batched { k = "dmg" | "heal" | "atk" | "tele" | "reward", ... }

	-- Items (S04). Functions answer (ok, errorKey?).
	MoveItem = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "integer" } }, -- (from, to)
	SplitStack = { kind = "function", dir = "c2s", rate = 4, args = { "integer", "integer" } }, -- (from, amount)
	SortInventory = { kind = "function", dir = "c2s", rate = 1, args = {} },
	DestroyItem = { kind = "function", dir = "c2s", rate = 4, args = { "integer" } },
	UseItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer" } },
	EquipItem = { kind = "function", dir = "c2s", rate = 6, args = { "integer", "string?" } }, -- (index, slot?)
	UnequipItem = { kind = "function", dir = "c2s", rate = 6, args = { "string", "integer?" } }, -- (slot, index?)
	SetPotionSlot = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (hp|mana|energy, itemId?)
	UsePotion = { kind = "function", dir = "c2s", rate = 6, args = { "string" } },
	PickupLoot = { kind = "function", dir = "c2s", rate = 10, args = { "string" } },
	LootSpawn = { kind = "event", dir = "s2c" }, -- (bag) only to the owner
	LootUpdate = { kind = "event", dir = "s2c" }, -- (bagId, items)
	LootRemove = { kind = "event", dir = "s2c" }, -- (bagId)
	LootPicked = { kind = "event", dir = "s2c" }, -- (items) what went into the backpack (legendary reveal)
	Announce = { kind = "event", dir = "s2c" }, -- (key, args) banner + system chat for everyone

	-- Skills (S05)
	LearnSkill = { kind = "function", dir = "c2s", rate = 6, args = { "string" } },
	SetHotbar = { kind = "function", dir = "c2s", rate = 10, args = { "integer", "string?" } }, -- (slot 1..10, skillId?)
	ResetSkills = { kind = "function", dir = "c2s", rate = 1, args = {} },
	CastSkill = { kind = "function", dir = "c2s", rate = 8, args = { "string", "string?", "any" } }, -- (skillId, targetId?, aim: Vector3?)
	SkillFx = { kind = "event", dir = "s2c" }, -- skill visuals for players nearby

	-- City (S06). All validate the distance to the NPC on the server.
	Buy = { kind = "function", dir = "c2s", rate = 6, args = { "string", "string", "integer" } }, -- (npcId, itemId, n)
	Sell = { kind = "function", dir = "c2s", rate = 4, args = { "string", "table" } }, -- (npcId, { index })
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
	UsePortal = { kind = "function", dir = "c2s", rate = 1, args = { "string" } }, -- (portal id)
	MapTransition = { kind = "event", dir = "s2c" }, -- (mapId) shows the loading screen, (nil) hides it
	UseMapStone = { kind = "function", dir = "c2s", rate = 1, args = { "integer", "string" } }, -- (inv index, target id)

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

	-- Quests (S11)
	QuestTalk = { kind = "function", dir = "c2s", rate = 4, args = { "string" } }, -- (npcId) counts "talk" objectives
	QuestAccept = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (npcId)
	QuestTurnIn = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (npcId)
	DailyClaim = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (contract index)
	QuestCompleted = { kind = "event", dir = "s2c" }, -- (titleKey) big message + sound

	-- PvP, duels and trade (S10)
	KillFeed = { kind = "event", dir = "s2c" }, -- (killerName, victimName)
	DuelChallenge = { kind = "function", dir = "c2s", rate = 1, args = { "integer" } }, -- (userId)
	DuelInvited = { kind = "event", dir = "s2c" }, -- (fromName, seconds)
	DuelRespond = { kind = "function", dir = "c2s", rate = 2, args = { "boolean" } },
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
	PremiumBuyCosmetic = { kind = "function", dir = "c2s", rate = 2, args = { "string" } }, -- (cosmetic id)
	PremiumRename = { kind = "function", dir = "c2s", rate = 0.5, args = { "string" } }, -- (new character name)
	CosmeticEquip = { kind = "function", dir = "c2s", rate = 4, args = { "string", "string?" } }, -- (kind, id | nil)
	GuideDone = { kind = "event", dir = "c2s", rate = 0.5, args = {} },

	-- Profiles (S15)
	PlayerProfile = { kind = "function", dir = "c2s", rate = 2, args = { "integer" } }, -- (userId) same server

	-- PvP and death
	SetPvp = { kind = "function", dir = "c2s", rate = 1, args = { "boolean" } },
	RespawnNow = { kind = "function", dir = "c2s", rate = 1, args = {} },
}

return table.freeze(Definitions)
