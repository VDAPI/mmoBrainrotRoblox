--!strict
-- Daily login reward (DESIGN-15 §5, S100): the 7-day streak of an account in UTC days and the contents of each day.
-- The streak counts at the claim: account.login = { day = last claimed streak day 0..7, last = UTC day of that
-- claim (0 = never) }. A missed full day resets a running streak to day 1; after day 7 the streak starts over. A
-- clock moved back (last > today) never gives a second reward. Pure: LoginRewardService, the window, the admin
-- commands and the balance model (tests/Balance.loginWeek) all read the streak and the contents from here.

local Classes = require("../Data/Classes")
local Config = require("../Config")
local Data = require("../Data/LoginReward")
local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Loot = require("./Loot")
local LootTables = require("../Data/LootTables")
local Potions = require("./Potions")
local Rng = require("./Rng")

export type State = { day: number, last: number } -- day: last claimed streak day 0..7; last: UTC day of that claim
export type Status = {
	claimable: boolean, -- a reward waits today
	day: number, -- the day claimable today, or the day claimed today
	claimedToday: boolean,
	resets: boolean, -- a missed day reset a running streak (the claimable day is 1 because of a break)
	nextDay: number, -- the streak day of the next UTC day if the player keeps the streak
}
export type Entry = { id: string, n: number }
export type Contents = { exp: number, gold: number, items: { Entry }, chest: boolean }

local LoginReward = {}

LoginReward.DAYS = Data.DAYS

local function clampLevel(level: number): number
	return math.clamp(math.floor(level), 1, Config.MaxLevel)
end

-- A valid state from whatever the save holds (a broken or hand-edited save never breaks the window).
function LoginReward.sanitize(raw: any): State
	if type(raw) ~= "table" or type(raw.day) ~= "number" or type(raw.last) ~= "number" then
		return { day = 0, last = 0 }
	end
	if raw.day ~= raw.day or raw.last ~= raw.last then -- NaN
		return { day = 0, last = 0 }
	end
	return { day = math.clamp(math.floor(raw.day), 0, Data.DAYS), last = math.max(0, math.floor(raw.last)) }
end

function LoginReward.status(state: State, today: number): Status
	local day, claimedToday, resets
	if state.last == 0 then
		day, claimedToday, resets = 1, false, false
	elseif state.last >= today then
		-- claimed today, or the clock went back: nothing to claim until a later day
		day, claimedToday, resets = math.max(1, state.day), true, false
	elseif state.last == today - 1 then
		day, claimedToday, resets = state.day % Data.DAYS + 1, false, false
	else
		-- a missed full day: a running streak resets; after a full week it starts over anyway
		day, claimedToday, resets = 1, false, state.day >= 1 and state.day < Data.DAYS
	end
	return {
		claimable = not claimedToday,
		day = day,
		claimedToday = claimedToday,
		resets = resets,
		nextDay = day % Data.DAYS + 1,
	}
end

-- The state after claiming today and the claimed day; nil when nothing waits.
function LoginReward.claim(state: State, today: number): (State?, number?)
	local status = LoginReward.status(state, today)
	if not status.claimable then
		return nil, nil
	end
	return { day = status.day, last = today }, status.day
end

local function dayDef(day: number): Data.DayDef
	local def = Data.days[day]
	assert(def, `LoginReward: no day {day}`)
	return def
end

-- Gold of a streak day at a character level (0 when the day gives none).
function LoginReward.goldAt(day: number, level: number): number
	local mul = dayDef(day).gold
	if not mul then
		return 0
	end
	local unit = Data.gold.base + Data.gold.perLevel * clampLevel(level)
	local round = Data.gold.round
	return math.floor(mul * unit / round + 0.5) * round
end

local function potionBand(level: number): Data.PotionBand
	local L = clampLevel(level)
	local best = Data.potionBands[1]
	for _, band in Data.potionBands do
		if band.from <= L and Potions.canDrink(Items.get(`potion_hp_{band.quality}`), L) then
			best = band
		end
	end
	return best
end

-- Potion quality (1..5) of the reward at a character level: never a potion the level may not drink (S87).
function LoginReward.potionQuality(level: number): number
	return potionBand(level).quality
end

-- The essence band of a level (Data/LoginReward.essenceBands): dust up to 19, shards from 20 (two from 45), no crystals.
function LoginReward.essenceAt(level: number): Data.EssenceBand
	local L = clampLevel(level)
	local best = Data.essenceBands[1]
	for _, band in Data.essenceBands do
		if band.from <= L then
			best = band
		end
	end
	return best
end

local function count(base: number, mul: number): number
	return math.max(1, math.floor(base * mul + 0.5))
end

-- The blessing line of a class (Data.classLine; an unknown class gets the guardian line).
function LoginReward.lineOf(classId: string): string
	return (Data.classLine :: { [string]: string })[classId] or "guardian"
end

-- The reward of a streak day for a character of `level` and `classId`, in a fixed order: gold; HP and class
-- resource potions; essence; Return Stones; the class blessing. The day 7 chest item is not in `items` (the server
-- rolls it on claim, LoginReward.rollChest). No EXP ever (DESIGN-15 §3.2).
function LoginReward.contents(day: number, level: number, classId: string): Contents
	local def = dayDef(day)
	local items: { Entry } = {}
	if def.potions then
		local band = potionBand(level)
		local n = count(band.n, def.potions)
		table.insert(items, { id = `potion_hp_{band.quality}`, n = n })
		local class = Classes.get(classId)
		if class then
			table.insert(items, { id = `potion_{class.resource}_{band.quality}`, n = n })
		end
	end
	if def.essence then
		local band = LoginReward.essenceAt(level)
		table.insert(items, { id = band.item, n = count(band.n, def.essence) })
	end
	if def.stones then
		table.insert(items, { id = "stone_return", n = def.stones })
	end
	if def.blessing then
		table.insert(items, { id = `blessing_{LoginReward.lineOf(classId)}_{def.blessing}`, n = 1 })
	end
	return { exp = 0, gold = LoginReward.goldAt(day, level), items = items, chest = def.chest == true }
end

-- Days 1..7 at a level (the window's preview and the balance model).
function LoginReward.week(level: number, classId: string): { Contents }
	local out = {}
	for day = 1, Data.DAYS do
		table.insert(out, LoginReward.contents(day, level, classId))
	end
	return out
end

-- The chest item: a Unique / Heroic item of a drop level for the character's level, of a base the class can wear
-- (Loot.pickUsable, the boss-slot weights: weapons first), like the Unique / Heroic branch of a boss. nil only when
-- the tier has no equipment at all (the server then gives the band's essence twice).
function LoginReward.rollChest(level: number, classId: string, rng: Rng.Rng): Loot.ItemDrop?
	local L = clampLevel(level)
	local ilvl = ItemRoll.dropLevel(L, rng)
	local defId = Loot.pickUsable(LootTables.bossSlots, ilvl, classId, rng)
	if not defId then
		return nil
	end
	local rarity = rng:weighted(Data.chest.rarity :: { [number]: number })
	return { defId = defId, ilvl = ilvl, rarity = rarity, forClass = classId }
end

-- What the server gives instead of a chest item when rollChest finds nothing: the band's essence twice.
function LoginReward.chestFallback(level: number): Entry
	local band = LoginReward.essenceAt(level)
	return { id = band.item, n = band.n * 2 }
end

return LoginReward
