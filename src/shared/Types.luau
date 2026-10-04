--!strict
-- Shared data types. Persistent tables use string keys only (DataStore JSON and RemoteEvent
-- serialization both break on sparse numeric arrays), see PROGRESS "Decisions" S01.

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
	rarity: number, -- 1 Common .. 5 Legendary, 6 Unique
	ilvl: number,
	bonuses: { Bonus },
	up: number, -- upgrade level 0..9
	bound: boolean,
	n: number, -- stack size (1 for non-stackables)
}

export type Stats = { str: number, dex: number, int: number, vit: number }

export type Location = { map: string, x: number, y: number, z: number }

export type PotionBar = { hp: string?, mana: string?, energy: string? }

export type CharacterData = {
	id: string,
	name: string,
	class: ClassId,
	level: number,
	exp: number,
	stats: Stats,
	statPoints: number,
	skills: { [string]: number },
	skillPoints: number,
	hotbar: { [string]: string }, -- "1".."10" -> skillId
	potionBar: PotionBar,
	equipment: { [string]: ItemInstance }, -- Slot -> item
	inventory: { [string]: ItemInstance }, -- "1".."N" -> item
	gold: number,
	location: Location,
	hp: number,
	mana: number,
	energy: number,
	blessing: { id: string, expiresAt: number }?,
	bossLockouts: { [string]: number },
	alchemy: { { recipeId: string, readyAt: number } },
	-- S11: main = the accepted story quest, mainDone = completed story quests (in order), daily = contracts.
	quests: {
		main: { id: string, progress: { number } }?,
		mainDone: number,
		daily: { day: number, list: { any }, rerolls: number },
	},
	guildId: string?,
	auctions: { [string]: boolean }, -- S13: ids of this character's auction listings
	guideDone: boolean, -- S14: the HUD guide was shown (or skipped)
	pvpEnabled: boolean,
	elixirs: { [string]: number }, -- resistance stat -> expiresAt (Clock time)
	pvp: { kills: number, deaths: number, duelsWon: number, duelsLost: number },
	visitedMaps: { [string]: boolean },
	createdAt: number,
	playtime: number,
}

export type Settings = {
	lang: string, -- "" = not chosen yet (client picks from Roblox locale)
	volume: number,
	dmgNumbers: boolean,
	bindConfirm: boolean, -- ask before an item binds on equip
	quickCast: boolean, -- area skills cast on key press instead of on release
	-- S14 options window
	musicVolume: number,
	quality: string, -- "high" | "low" (fewer particles)
	minimapRotate: boolean,
	cameraSens: number, -- mouse/touch camera sensitivity multiplier
	sellConfirm: boolean, -- ask before selling valuable items
}

export type AccountData = {
	schema: number,
	characters: { [string]: CharacterData }, -- "1".."3" -> character
	lastCharacter: number?,
	dragonShards: number,
	deposit: { size: number, items: { [string]: ItemInstance } },
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	pets: { owned: { [string]: boolean }, equipped: string? },
	settings: Settings,
	purchases: { [string]: number },
	dailyLimits: { day: number, protectScrolls: number },
	stats: { createdAt: number, playtime: number },
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
export type DeathState = { diedAt: number, respawnAt: number, cost: number }

export type PvpState = { pendingTarget: boolean?, switchAt: number?, lockedUntil: number? }

export type ClientState = {
	account: AccountData?,
	slots: { [string]: SlotSummary },
	character: CharacterData?,
	session: { phase: SessionPhase, slot: number?, dataMock: boolean },
	derived: DerivedState?,
	zone: ZoneState?,
	death: DeathState?,
	pvp: PvpState?,
}

export type PathKey = string | number
export type Path = { PathKey }

export type DiffOp = "set" | "insert" | "remove"
export type Diff = { op: DiffOp, path: Path, value: any?, index: number? }

return nil
