--!strict
-- Season pass rules (S152, docs/DESIGN.md §21b), pure: the state of account.season, points for ordinary play with the
-- daily monster limit, the growing weekly cap (a missed week is caught up later) and the catch-up multiplier below the
-- line, tiers, claiming the free and the premium track, buying the premium track. Every function takes `now` from the
-- outside (Util/Clock on the server) and returns new tables, never changing its input. Points come from play only:
-- nothing here reads a purchase, and the premium track never changes how many points a source gives
-- (tests/paywall.spec "12."). The server is the authority (SeasonService); the window (S152b) calls the same functions
-- for its preview.

local Items = require("../Data/Items")
local Market = require("../Data/Market")
local Seasons = require("../Data/Seasons")
local Time = require("./Time")
local Types = require("../Types")

type SeasonState = Types.SeasonState
type SeasonDef = Seasons.SeasonDef
type Reward = Seasons.Reward

export type Claim = { tier: number, track: Seasons.Track }
export type ItemCount = { id: string, n: number }

local Season = {}

local function num(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return value
end

local function whole(value: any): number
	return math.max(0, math.floor(num(value)))
end

-- tostring(tier) keys of 1..maxTier set to true (numeric keys of an old or hand-made state are accepted).
local function tiersMap(value: any, maxTier: number): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return out
	end
	for key, flag in value do
		local tier = if type(key) == "number" then key elseif type(key) == "string" then tonumber(key) else nil
		if flag == true and tier and tier == math.floor(tier) and tier >= 1 and tier <= maxTier then
			out[tostring(tier)] = true
		end
	end
	return out
end

local function maxTierOf(id: string): number
	local def = Seasons.get(id)
	if def then
		return def.tiers
	end
	local most = 0
	for _, d in Seasons.list do
		most = math.max(most, d.tiers)
	end
	return most
end

local function copy(state: SeasonState): SeasonState
	return {
		id = state.id,
		points = state.points,
		day = state.day,
		dayKill = state.dayKill,
		premium = state.premium,
		free = table.clone(state.free),
		prem = table.clone(state.prem),
		mailed = table.clone(state.mailed),
	}
end

-- A full, valid state from whatever was saved: missing or wrong fields get their defaults, points are whole and
-- >= 0, the claimed maps keep only tiers 1..tiers of the season set to true, `mailed` only string ids set to true.
function Season.sanitize(state: any): SeasonState
	local s = if type(state) == "table" then state else {}
	local id = if type(s.id) == "string" then s.id else ""
	local maxTier = maxTierOf(id)
	local mailed: { [string]: boolean } = {}
	if type(s.mailed) == "table" then
		for key, flag in s.mailed do
			if type(key) == "string" and key ~= "" and flag == true then
				mailed[key] = true
			end
		end
	end
	return {
		id = id,
		points = whole(s.points),
		day = whole(s.day),
		dayKill = whole(s.dayKill),
		premium = s.premium == true,
		free = tiersMap(s.free, maxTier),
		prem = tiersMap(s.prem, maxTier),
		mailed = mailed,
	}
end

-- A clean state of season `id` ("" = no season) keeping the mailed seasons of `from`.
function Season.fresh(id: string, from: any?): SeasonState
	local out = Season.sanitize(nil)
	out.id = id
	if from ~= nil then
		out.mailed = Season.sanitize(from).mailed
	end
	return out
end

-- The state for the season running at `now`: the same state while its id is that season's, otherwise a clean one of
-- the running season (id "" without one). The old state is the caller's to settle first (Season.unclaimed).
function Season.roll(state: any, now: number): SeasonState
	local s = Season.sanitize(state)
	local def = Seasons.at(now)
	local id = if def then def.id else ""
	if s.id == id then
		return s
	end
	return Season.fresh(id, s)
end

-- The week of the season at `now`: 1..weeks while it runs, 0 before the start, `weeks` after the end.
function Season.week(def: SeasonDef, now: number): number
	if now < def.start then
		return 0
	end
	return math.min(def.weeks, math.floor((now - def.start) / Seasons.WEEK) + 1)
end

-- The first second after the season (rewards are still claimed GRACE_DAYS more).
function Season.ends(def: SeasonDef): number
	return Seasons.endsAt(def)
end

-- The last second rewards of the season may be claimed in the window.
function Season.claimUntil(def: SeasonDef): number
	return Seasons.endsAt(def) + Seasons.GRACE_DAYS * 86400
end

-- Whether the season runs at `now`.
function Season.running(def: SeasonDef, now: number): boolean
	return now >= def.start and now < Seasons.endsAt(def)
end

function Season.tierOf(points: number, def: SeasonDef): number
	return math.clamp(math.floor(whole(points) / Seasons.TIER_POINTS), 0, def.tiers)
end

-- Points inside the current tier (0..TIER_POINTS - 1).
function Season.progress(points: number): number
	return whole(points) % Seasons.TIER_POINTS
end

-- The points an account may hold at `now`: weekCap x the week of the season, never above the last tier.
function Season.capAt(def: SeasonDef, now: number): number
	return math.min(Seasons.LIMITS.weekCap * Season.week(def, now), def.tiers * Seasons.TIER_POINTS)
end

-- The catch-up line at `now` in points: behind x tiers x the elapsed share of the season (it grows every second, so
-- nobody is behind at the start).
function Season.lineAt(def: SeasonDef, now: number): number
	local length = def.weeks * Seasons.WEEK
	local share = math.clamp((now - def.start) / length, 0, 1)
	return math.floor(Seasons.CATCHUP.behind * def.tiers * Seasons.TIER_POINTS * share)
end

-- Adds the points of `n` (default 1) events of `source`. Order: the base points, the catch-up bonus up to the line,
-- the daily monster limit (kill and elite), the growing cap. Returns the new state, the points gained and why fewer
-- than the source's points were gained ("cap", "killCap", "noSeason", "unknown"), nil when nothing was cut.
function Season.add(
	state: any,
	def: SeasonDef?,
	source: string,
	now: number,
	n: number?
): (SeasonState, number, string?)
	local s = Season.sanitize(state)
	local base = Seasons.POINTS[source]
	if base == nil then
		return s, 0, "unknown"
	end
	if def == nil or s.id ~= def.id or not Season.running(def, now) then
		return s, 0, "noSeason"
	end
	local count = math.max(1, math.floor(num(n or 1)))
	local raw = base * count
	local gain = raw
	local below = Season.lineAt(def, now) - s.points
	if below > 0 then
		gain = raw + math.min(math.floor(raw * Seasons.CATCHUP.mul) - raw, below)
	end
	local reason: string? = nil
	local out = copy(s)
	local today = Time.dayNumber(now)
	if out.day ~= today then
		out.day = today
		out.dayKill = 0
	end
	if Seasons.KILL_SOURCES[source] then
		local room = math.max(0, Seasons.LIMITS.killPerDay - out.dayKill)
		if gain > room then
			gain = room
			reason = "killCap"
		end
	end
	local room = math.max(0, Season.capAt(def, now) - out.points)
	if gain > room then
		gain = room
		reason = "cap"
	end
	if Seasons.KILL_SOURCES[source] then
		out.dayKill += gain
	end
	out.points += gain
	return out, gain, reason
end

-- The reward of `tier` on `track`, or nil.
function Season.rewardOf(def: SeasonDef, tier: number, track: string): Reward?
	if track == "free" then
		return def.rewards.free[tier]
	elseif track == "premium" then
		return def.rewards.premium[tier]
	end
	return nil
end

local function mapOf(state: SeasonState, track: string): { [string]: boolean }
	return if track == "premium" then state.prem else state.free
end

-- Whether `tier` of `track` may be claimed at `now`: the state is of this season, the claim window is open (the season
-- and GRACE_DAYS after it), the reward exists, it was not claimed, the premium track is bought and the tier reached.
-- Error keys: season.error.noSeason, .ended, .noReward, .claimed, .noPremium, .tier.
function Season.canClaim(state: any, def: SeasonDef, tier: number, track: string, now: number): (boolean, string?)
	local s = Season.sanitize(state)
	if s.id ~= def.id or now < def.start then
		return false, "season.error.noSeason"
	end
	if now > Season.claimUntil(def) then
		return false, "season.error.ended"
	end
	if type(tier) ~= "number" or tier ~= math.floor(tier) or Season.rewardOf(def, tier, track) == nil then
		return false, "season.error.noReward"
	end
	if mapOf(s, track)[tostring(tier)] == true then
		return false, "season.error.claimed"
	end
	if track == "premium" and not s.premium then
		return false, "season.error.noPremium"
	end
	if tier > Season.tierOf(s.points, def) then
		return false, "season.error.tier"
	end
	return true, nil
end

-- The state with `tier` of `track` claimed (the caller checked canClaim).
function Season.claim(state: any, tier: number, track: string): SeasonState
	local out = Season.sanitize(state)
	if track == "premium" then
		out.prem[tostring(tier)] = true
	else
		out.free[tostring(tier)] = true
	end
	return out
end

-- Every reached, unclaimed reward (premium only when bought), by tier, free before premium on the same tier.
function Season.claimable(state: any, def: SeasonDef): { Claim }
	local s = Season.sanitize(state)
	local out: { Claim } = {}
	if s.id ~= def.id then
		return out
	end
	for tier = 1, Season.tierOf(s.points, def) do
		if def.rewards.free[tier] and not s.free[tostring(tier)] then
			table.insert(out, { tier = tier, track = "free" })
		end
		if s.premium and def.rewards.premium[tier] and not s.prem[tostring(tier)] then
			table.insert(out, { tier = tier, track = "premium" })
		end
	end
	return out
end

-- The rewards still to give for a season after its grace days (they go by mail once).
function Season.unclaimed(state: any, def: SeasonDef): { Reward }
	local out: { Reward } = {}
	for _, c in Season.claimable(state, def) do
		local reward = Season.rewardOf(def, c.tier, c.track)
		if reward then
			table.insert(out, reward)
		end
	end
	return out
end

-- Item counts merged by id (first-seen order), split at the item's stack size, in parcels of at most `perParcel`
-- stacks (default Market.Mail.maxItemsPerParcel): the season's items by mail never break the parcel limit.
function Season.pack(counts: { ItemCount }, perParcel: number?): { { ItemCount } }
	local limit = math.max(1, perParcel or Market.Mail.maxItemsPerParcel)
	local order: { string } = {}
	local total: { [string]: number } = {}
	for _, c in counts do
		local n = math.floor(c.n)
		if n > 0 then
			if total[c.id] == nil then
				table.insert(order, c.id)
				total[c.id] = 0
			end
			total[c.id] += n
		end
	end
	local parcels: { { ItemCount } } = {}
	local current: { ItemCount } = {}
	for _, id in order do
		local def = Items.get(id)
		local size = if def and def.maxStack and def.maxStack > 0 then def.maxStack else 1
		local left = total[id]
		while left > 0 do
			if #current >= limit then
				table.insert(parcels, current)
				current = {}
			end
			local n = math.min(left, size)
			table.insert(current, { id = id, n = n })
			left -= n
		end
	end
	if #current > 0 then
		table.insert(parcels, current)
	end
	return parcels
end

-- Whether the premium track of `def` may be bought at `now`: the season runs (to its last second; every reached
-- premium tier is claimed afterwards) and this account has not bought it. Errors: season.error.noSeason, .owned.
function Season.canBuy(state: any, def: SeasonDef?, now: number): (boolean, string?)
	local s = Season.sanitize(state)
	if def == nil or s.id ~= def.id or not Season.running(def, now) then
		return false, "season.error.noSeason"
	end
	if s.premium then
		return false, "season.error.owned"
	end
	return true, nil
end

-- The state with the premium track bought.
function Season.buy(state: any): SeasonState
	local out = Season.sanitize(state)
	out.premium = true
	return out
end

return Season
