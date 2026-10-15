--!strict
-- VIP benefits (DESIGN-17 §2, S121), pure: the account's VIP state (account.vip), the daily Dragon Shards, the
-- cosmetic of the month, the free instant respawn and the free return to the city. Every function takes the state and
-- `now` from outside (Util/Clock) and returns new tables, never changing its input. Whether the player has VIP is the
-- server's call (MonetizationService.HasVip); nothing here gives EXP, gold, drops or stats (tests/paywall.spec).

local Config = require("../Config")
local Cosmetics = require("../Data/Cosmetics")
local Market = require("../Data/Market")
local Recipes = require("../Data/Recipes")
local Time = require("./Time")
local Types = require("../Types")

type VipState = Types.VipState

local Vip = {}

local function num(value: any): number
	return if type(value) == "number" and value == value then value else 0
end

-- A full, valid state from whatever was saved (missing or wrong fields get their defaults; months keep only
-- "YYYYMM" keys set to true).
function Vip.sanitize(state: any): VipState
	local s = if type(state) == "table" then state else {}
	local months: { [string]: boolean } = {}
	if type(s.months) == "table" then
		for key, value in s.months do
			if type(key) == "string" and value == true and string.match(key, "^%d%d%d%d%d%d$") then
				months[key] = true
			end
		end
	end
	return {
		shardDay = num(s.shardDay),
		respawnDay = num(s.respawnDay),
		respawnN = num(s.respawnN),
		recallAt = num(s.recallAt),
		months = months,
	}
end

-- Whether today's shards are still to be given (the first VIP moment of a UTC day).
function Vip.dailyDue(state: any, now: number): boolean
	return Vip.sanitize(state).shardDay ~= Time.dayNumber(now)
end

-- The state after today's shards.
function Vip.claimDaily(state: any, now: number): VipState
	local out = Vip.sanitize(state)
	out.shardDay = Time.dayNumber(now)
	return out
end

-- The VIP cosmetic of the month `monthKey` ("YYYYMM"): the first cosmetic of `list` (default Data/Cosmetics) with
-- obtain.vipMonth == monthKey, or nil.
function Vip.monthCosmetic(monthKey: string, list: { Cosmetics.Def }?): string?
	for _, def in list or Cosmetics.list do
		local obtain = def.obtain
		if obtain and obtain.vipMonth == monthKey then
			return def.id
		end
	end
	return nil
end

-- The cosmetic to give now: the month has one, it was not given yet and the account does not own it. An owned one
-- (e.g. from /cosmetic all) returns nil; the server still marks the month as done.
function Vip.monthDue(state: any, monthKey: string, owned: { [string]: boolean }, list: { Cosmetics.Def }?): string?
	local id = Vip.monthCosmetic(monthKey, list)
	if id == nil or Vip.sanitize(state).months[monthKey] == true or owned[id] == true then
		return nil
	end
	return id
end

-- The state with `monthKey` marked as done.
function Vip.markMonth(state: any, monthKey: string): VipState
	local out = Vip.sanitize(state)
	out.months[monthKey] = true
	return out
end

-- Free instant respawns left today.
function Vip.respawnLeft(state: any, now: number): number
	local s = Vip.sanitize(state)
	local used = if s.respawnDay == Time.dayNumber(now) then s.respawnN else 0
	return math.max(0, Config.Vip.freeRespawnsPerDay - used)
end

-- The state after one free respawn today.
function Vip.useRespawn(state: any, now: number): VipState
	local out = Vip.sanitize(state)
	local day = Time.dayNumber(now)
	out.respawnN = (if out.respawnDay == day then out.respawnN else 0) + 1
	out.respawnDay = day
	return out
end

-- Seconds until the next free return to the city (0 = available).
function Vip.recallLeft(state: any, now: number): number
	local s = Vip.sanitize(state)
	if s.recallAt <= 0 then
		return 0
	end
	return math.max(0, s.recallAt + Config.Vip.freeRecallCooldown - now)
end

-- The state after a successful free return at `now`.
function Vip.useRecall(state: any, now: number): VipState
	local out = Vip.sanitize(state)
	out.recallAt = now
	return out
end

-- The state with today's benefits reset (admin /vip reset): the months stay.
function Vip.reset(state: any): VipState
	local out = Vip.sanitize(state)
	out.shardDay = 0
	out.respawnDay = 0
	out.respawnN = 0
	out.recallAt = 0
	return out
end

export type Benefit = { key: string, icon: string, args: { [string]: any }? }

-- The rows of the VIP window (texts vip.benefit.<key>), with their numbers from Config.Vip, so the window and the
-- test read the same. `pct` and `base` are percents (the window formats them with the language's decimal mark).
Vip.BENEFITS = table.freeze({
	{ key = "shards", icon = "◆", args = { n = Config.Vip.dailyShards } },
	{ key = "title", icon = "★" },
	{ key = "alchemy", icon = "⚗", args = { n = Recipes.QUEUE_SLOTS_VIP - Recipes.QUEUE_SLOTS } },
	{
		key = "auction",
		icon = "⚖",
		args = {
			n = Config.Vip.auctionExtraListings,
			pct = Market.Auction.feePct * Config.Vip.auctionFeeMul, -- the same as Logic/Auction.feePctFor(true)
			base = Market.Auction.feePct,
		},
	},
	{ key = "recall", icon = "↩", args = { min = Config.Vip.freeRecallCooldown // 60 } },
	{ key = "respawn", icon = "✚", args = { n = Config.Vip.freeRespawnsPerDay } },
	{ key = "month", icon = "✦" },
} :: { Benefit })

return Vip
