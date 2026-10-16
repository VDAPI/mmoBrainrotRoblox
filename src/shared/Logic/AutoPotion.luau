--!strict
-- Auto Potions rules (S134d), pure: the account state (account.autoPotion), whether the service works, which potion
-- kinds to drink at the player's thresholds and the purchase rule of its shop entries. Bought for Dragon Shards
-- forever (`permanent`) or for real time (`untilTs`, runs offline too, like the Cloak of Luring). The drinking itself
-- is PotionService's (AutoPotionService calls PotionService.DrinkKind: the same bar, level, guards and cooldown as the
-- key); where it does not work: Logic/UseBlocks.LISTS.autoPotion.

local Config = require("../Config")
local Products = require("../Data/Products")

local AutoPotion = {}

-- hp / res: thresholds in % of the maximum (0 = that threshold is off); res = the class resource (mana or energy).
export type State = { untilTs: number, permanent: boolean, on: boolean, hp: number, res: number }
export type Kind = "hp" | "res"

function AutoPotion.default(): State
	return {
		untilTs = 0,
		permanent = false,
		on = false,
		hp = Config.AutoPotion.hp,
		res = Config.AutoPotion.res,
	}
end

local function stateOf(state: State?): State
	if type(state) ~= "table" then
		return AutoPotion.default()
	end
	return state
end

-- Seconds of timed service left at `now` (a permanent service has none: see `owned`).
function AutoPotion.left(state: State?, now: number): number
	return math.max(0, (stateOf(state).untilTs or 0) - now)
end

-- Bought forever, or with time left.
function AutoPotion.owned(state: State?, now: number): boolean
	return stateOf(state).permanent == true or AutoPotion.left(state, now) > 0
end

-- Owned and switched on.
function AutoPotion.active(state: State?, now: number): boolean
	return stateOf(state).on == true and AutoPotion.owned(state, now)
end

-- The state after buying (a new table): a timed entry adds `seconds` from now or from the current end, a permanent
-- one marks the account; buying switches the service on and keeps the thresholds.
function AutoPotion.extend(state: State?, seconds: number, now: number, permanent: boolean?): State
	local s = stateOf(state)
	return {
		untilTs = if permanent then s.untilTs or 0 else math.max(s.untilTs or 0, now) + math.max(0, seconds),
		permanent = s.permanent == true or permanent == true,
		on = true,
		hp = AutoPotion.clampThreshold(s.hp),
		res = AutoPotion.clampThreshold(s.res),
	}
end

-- A threshold the player may set: 0 (off) or minPct..maxPct in steps of `step` (rounded to the nearest step).
function AutoPotion.clampThreshold(pct: any): number
	local c = Config.AutoPotion
	if type(pct) ~= "number" or pct ~= pct or pct <= 0 then
		return 0
	end
	local stepped = math.floor(pct / c.step + 0.5) * c.step
	return math.clamp(stepped, c.minPct, c.maxPct)
end

-- The kinds to drink now (HP first): a kind whose threshold is on and whose fill (%) is at or under it.
function AutoPotion.wants(state: State?, hpPct: number, resPct: number): { Kind }
	local s = stateOf(state)
	local out: { Kind } = {}
	local hp = AutoPotion.clampThreshold(s.hp)
	local res = AutoPotion.clampThreshold(s.res)
	if hp > 0 and hpPct <= hp then
		table.insert(out, "hp")
	end
	if res > 0 and resPct <= res then
		table.insert(out, "res")
	end
	return out
end

-- The service's own purchase rule (on top of Logic/Premium.canBuy's price and limits): nothing more once it is owned
-- forever; timed entries add up.
function AutoPotion.canBuy(entry: Products.ShopEntry, state: State?, _now: number): (boolean, string?)
	if entry.kind ~= "autoPotion" then
		return true, nil
	end
	if stateOf(state).permanent == true then
		return false, "premium.error.owned"
	end
	if entry.permanent ~= true and (entry.seconds or 0) <= 0 then
		return false, "error.badRequest"
	end
	return true, nil
end

return AutoPotion
