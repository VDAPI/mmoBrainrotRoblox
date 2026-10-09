--!strict
-- Item rarities and drop chances (DESIGN §5.2, §5.5). Data only.
-- S30 ladder: Common (grey) · Unique (yellow) · Heroic (blue) · Legendary (orange) · Mythic (red).
-- Code asks the rarity for its capabilities (`valuable`, `announce`, `reveal`, `legendCore`, `quickSell`,
-- `dismantle`) instead of comparing ids.

export type FrameStyle = {
	thickness: number, -- border thickness in px (before UI scale)
	gradient: { Color3 }?, -- { c1, c2 } for a gradient border
	glow: boolean,
	spin: boolean, -- rotate the gradient
}

export type DismantleDrop = { id: string, min: number, max: number, chance: number? }

export type RarityDef = {
	id: number,
	key: string, -- "common" | "unique" | "heroic" | "legendary" | "mythic"
	nameKey: string, -- "rarity.<key>"
	shortKey: string, -- "rarity.short.<key>" (filters)
	hex: string, -- frame colour as hex (pure code / tests)
	textHex: string,
	color: Color3, -- frame colour (only a real Color3 inside Roblox; in Lune it is the hex string)
	textColor: Color3, -- readable name colour on the tooltip parchment
	bonusMin: number,
	bonusMax: number,
	baseMul: number, -- base stat multiplier of rolled items
	rangeMul: number, -- multiplier of random bonus values
	legendaryLines: number, -- distinct lines from the legendary bonus pool
	mythicLines: number, -- distinct lines from the mythic bonus pool (FIX 2026-10-09)
	sellMul: number, -- "mnożnik rzadkości" in the sell price formula (DESIGN §18)
	frame: FrameStyle,
	valuable: boolean, -- confirm before selling/dismantling, light at the weapon
	announce: ("legendary" | "mythic")?, -- server-wide announcement on drop
	reveal: boolean, -- reveal animation on pickup
	legendCore: boolean, -- upgrading from +7 needs a Legend Core
	quickSell: boolean, -- included in "sell all"
	bindOnPickup: boolean, -- equipment of this rarity binds when picked up (Mythic: the grind stays personal)
	dismantle: { DismantleDrop },
}

-- Color3 exists only inside Roblox; Lune tests see the hex string instead.
local C3: any = Color3 :: any
local function color(hex: string): Color3
	if C3 ~= nil then
		return C3.fromHex(hex)
	end
	return (hex :: any) :: Color3
end

local function def(spec: {
	id: number,
	key: string,
	hex: string,
	textHex: string,
	bonusMin: number,
	bonusMax: number,
	baseMul: number,
	rangeMul: number,
	legendaryLines: number,
	mythicLines: number?,
	sellMul: number,
	thickness: number,
	gradient: { string }?,
	glow: boolean,
	spin: boolean,
	valuable: boolean,
	announce: ("legendary" | "mythic")?,
	reveal: boolean,
	legendCore: boolean,
	quickSell: boolean,
	bindOnPickup: boolean?,
	dismantle: { DismantleDrop },
}): RarityDef
	local gradient: { Color3 }? = nil
	if spec.gradient then
		gradient = { color(spec.gradient[1]), color(spec.gradient[2]) }
	end
	return table.freeze({
		id = spec.id,
		key = spec.key,
		nameKey = `rarity.{spec.key}`,
		shortKey = `rarity.short.{spec.key}`,
		hex = spec.hex,
		textHex = spec.textHex,
		color = color(spec.hex),
		textColor = color(spec.textHex),
		bonusMin = spec.bonusMin,
		bonusMax = spec.bonusMax,
		baseMul = spec.baseMul,
		rangeMul = spec.rangeMul,
		legendaryLines = spec.legendaryLines,
		mythicLines = spec.mythicLines or 0,
		sellMul = spec.sellMul,
		frame = table.freeze({ thickness = spec.thickness, gradient = gradient, glow = spec.glow, spin = spec.spin }),
		valuable = spec.valuable,
		announce = spec.announce,
		reveal = spec.reveal,
		legendCore = spec.legendCore,
		quickSell = spec.quickSell,
		bindOnPickup = spec.bindOnPickup == true,
		dismantle = spec.dismantle,
	}) :: RarityDef
end

local LIST: { RarityDef } = {
	def({
		id = 1,
		key = "common",
		hex = "#9DA3AB",
		textHex = "#565C64",
		bonusMin = 0,
		bonusMax = 0,
		baseMul = 1.0,
		rangeMul = 1.0,
		legendaryLines = 0,
		sellMul = 1.0,
		thickness = 1.5,
		glow = false,
		spin = false,
		valuable = false,
		reveal = false,
		legendCore = false,
		quickSell = true,
		dismantle = { { id = "essence_dust", min = 1, max = 2 } },
	}),
	def({
		id = 2,
		key = "unique",
		hex = "#F2D33A",
		textHex = "#8C6D00",
		bonusMin = 2,
		bonusMax = 2,
		baseMul = 1.05,
		rangeMul = 1.0,
		legendaryLines = 0,
		sellMul = 1.12,
		thickness = 2,
		glow = false,
		spin = false,
		valuable = false,
		reveal = false,
		legendCore = false,
		quickSell = true,
		dismantle = {
			{ id = "essence_dust", min = 2, max = 4 },
			{ id = "essence_shard", min = 1, max = 1, chance = 0.25 },
		},
	}),
	def({
		id = 3,
		key = "heroic",
		hex = "#3D8BFF",
		textHex = "#1F5BC2",
		bonusMin = 3,
		bonusMax = 3,
		baseMul = 1.12,
		rangeMul = 1.0, -- FIX 2026-10-09: 3 bonuses always (was 2-3), so no extra range
		legendaryLines = 0,
		sellMul = 1.25,
		thickness = 2.5,
		glow = true,
		spin = false,
		valuable = true,
		reveal = false,
		legendCore = false,
		quickSell = false,
		dismantle = {
			{ id = "essence_shard", min = 1, max = 3 },
			{ id = "essence_crystal", min = 1, max = 1, chance = 0.2 },
		},
	}),
	def({
		id = 4,
		key = "legendary",
		hex = "#FF9F1C",
		textHex = "#C26A00",
		bonusMin = 3,
		bonusMax = 3,
		baseMul = 1.16,
		rangeMul = 1.1,
		legendaryLines = 1,
		sellMul = 1.45,
		thickness = 2.5,
		gradient = { "#FF9F1C", "#FFE08A" },
		glow = true,
		spin = true,
		valuable = true,
		announce = "legendary",
		reveal = true,
		legendCore = true,
		quickSell = false,
		dismantle = {
			{ id = "essence_crystal", min = 1, max = 2 },
			{ id = "legend_core", min = 1, max = 1 },
		},
	}),
	def({
		id = 5,
		key = "mythic",
		hex = "#E5302A",
		textHex = "#B01E19",
		bonusMin = 3,
		bonusMax = 3,
		baseMul = 1.22,
		rangeMul = 1.2,
		legendaryLines = 2,
		mythicLines = 1,
		sellMul = 1.70,
		thickness = 3,
		gradient = { "#E5302A", "#FF8FB1" },
		glow = true,
		spin = true,
		valuable = true,
		announce = "mythic",
		reveal = true,
		legendCore = true,
		quickSell = false,
		bindOnPickup = true,
		dismantle = {
			{ id = "essence_crystal", min = 2, max = 3 },
			{ id = "legend_core", min = 2, max = 2 },
		},
	}),
}

local COMMON, UNIQUE, HEROIC, LEGENDARY, MYTHIC = 1, 2, 3, 4, 5
local MAX = #LIST

-- Rarity weights per drop source (DESIGN §5.5). Weights, not percentages. Never above `CAP[source]`.
-- Boss: the rarity of a winner's item when it is not Legendary / Mythic (FIX 2026-10-09, Loot.rollBossItem).
local DROP_WEIGHTS: { [string]: { [number]: number } } = {
	-- S32 (docs/BALANS.md): a Unique for the player's class about every 1-2 levels (was 15: one per ~3 levels), a
	-- Heroic about every 1-2 h of cave Elites (was 15: ~2.5 per hour).
	normal = { [COMMON] = 70, [UNIQUE] = 30 },
	elite = { [COMMON] = 45, [UNIQUE] = 49, [HEROIC] = 6 },
	elite2 = { [UNIQUE] = 45, [HEROIC] = 50, [LEGENDARY] = 5 },
	boss = { [UNIQUE] = 35, [HEROIC] = 65 },
}

-- Highest rarity each source can ever give (boss: Legendary / Mythic through Loot.rollBossItem's own chances).
local CAP: { [string]: number } = { normal = UNIQUE, elite = HEROIC, elite2 = LEGENDARY, boss = MYTHIC }

-- Chance that a kill drops an item at all, and how many (DESIGN §5.5). Drop bonus multiplies `chance`.
-- Raised after the S17 tests: normal 20 %, elite 75 % (+25 % for a second), Elite II 2-3 items.
local ITEM_DROPS: { [string]: { chance: number, min: number, max: number, extra: number? } } = {
	normal = { chance = 0.20, min = 1, max = 1 },
	elite = { chance = 0.75, min = 1, max = 1, extra = 0.25 },
	elite2 = { chance = 1.0, min = 2, max = 3 },
	boss = { chance = 1.0, min = 1, max = 1 }, -- FIX 2026-10-09: one item per winner (was 3-4 shared)
}

-- Pre-S30 rarity ids (1 common, 2 uncommon, 3 rare, 4 epic, 5 legendary, 6 boss unique) → new ids.
local FROM_LEGACY: { [number]: number } = { [1] = 1, [2] = 2, [3] = 3, [4] = 3, [5] = 4, [6] = 5 }

-- Current item format version (ItemInstance.rv).
local RV = 2

local function get(id: number): RarityDef
	return LIST[math.clamp(math.floor(tonumber(id) or 1), 1, MAX)]
end

-- Brings an item saved before S30 to the new ladder. Idempotent (`rv == 2` returns at once); mutates and
-- returns the item. Equipment maps through FROM_LEGACY; other items take their definition's rarity
-- (blessing tiers 1–5 map 1:1).
local function upgradeItem<T>(item: T, itemDef: any?): T
	local it = item :: any
	if type(it) ~= "table" or it.rv == RV then
		return item
	end
	if itemDef ~= nil and itemDef.category ~= "equipment" then
		it.rarity = itemDef.rarity or COMMON
	else
		it.rarity = FROM_LEGACY[tonumber(it.rarity) or 1] or COMMON
	end
	it.rv = RV
	return item
end

-- Admin input: "common" | "unique" | "heroic" | "legendary" | "mythic" (or a prefix) or 1..MAX. nil otherwise.
local function parse(text: string?): number?
	if text == nil or text == "" then
		return nil
	end
	local n = tonumber(text)
	if n then
		n = math.floor(n)
		return if n >= 1 and n <= MAX then n else nil
	end
	local lower = string.lower(text)
	for _, rarity in LIST do
		if rarity.key == lower or (#lower >= 3 and string.sub(rarity.key, 1, #lower) == lower) then
			return rarity.id
		end
	end
	return nil
end

return table.freeze({
	list = LIST,
	parse = parse,
	get = get,
	COMMON = COMMON,
	UNIQUE = UNIQUE,
	HEROIC = HEROIC,
	LEGENDARY = LEGENDARY,
	MYTHIC = MYTHIC,
	MAX = MAX,
	RV = RV,
	dropWeights = DROP_WEIGHTS,
	cap = CAP,
	itemDrops = ITEM_DROPS,
	fromLegacy = FROM_LEGACY,
	upgradeItem = upgradeItem,
	-- Each upgrade level adds this share of the item's base stats (DESIGN §6: +6 % per level, +9 = +54 %).
	upgradeStatPerLevel = 0.06,
})
