--!strict
-- Season pass (S152, docs/DESIGN.md §21b): seasons of `weeks` weeks from a Monday 00:00 UTC, points for ordinary play
-- (POINTS per source, the server calls SeasonService.Add), `tiers` tiers of TIER_POINTS each, a free track (every
-- account) and a premium track (bought once per season for Dragon Shards; the price lives with the shop's products,
-- never here: tests/paywall.spec "12."). Rewards are looks and the allowed comfort only (tests/paywall.spec "11."):
-- cosmetics with obtain.season, bound Stones of Return and Cloak of Luring time. Rules in Logic/Season; this module
-- holds the data and the pace numbers only (no Roblox API).
-- A new season = a new SEASONS entry with its own cosmetics (owner's decision); no entry after the last one = "the next
-- season soon".

local Time = require("../Logic/Time")

export type RewardKind = "cosmetic" | "item" | "lure"
-- cosmetic: `id` in Data/Cosmetics (obtain.season = the season id); item: `n` of item `id` (only stone_return, bound);
-- lure: `seconds` of Cloak of Luring time on the account (like the lure_1h shop entry).
export type Reward = { kind: RewardKind, id: string?, n: number?, seconds: number? }
export type Track = "free" | "premium"
export type SeasonDef = {
	id: string,
	nameKey: string,
	start: number, -- Monday 00:00 UTC (seconds)
	weeks: number,
	tiers: number,
	rewards: { free: { [number]: Reward }, premium: { [number]: Reward } },
}

local WEEK = 7 * 86400

local function cosmetic(id: string): Reward
	return { kind = "cosmetic", id = id }
end

local function item(id: string, n: number): Reward
	return { kind = "item", id = id, n = n }
end

local function lure(seconds: number): Reward
	return { kind = "lure", seconds = seconds }
end

local function monday(year: number, month: number, day: number): number
	return Time.fromCivil(year, month, day) * 86400
end

-- Season 1 "Season of Frost": cold blues, silver and navy. The free track every 2 tiers (5 cosmetics), the premium
-- track on every tier (12 cosmetics); the rest are bound Stones of Return and one hour of the Cloak of Luring.
local S1_FREE: { [number]: Reward } = {}
local S1_PREMIUM: { [number]: Reward } = {}
do
	local freeLooks: { [number]: string } = {
		[6] = "emote_s1_breath",
		[12] = "dye_s1_glacier",
		[20] = "frame_s1_rime",
		[30] = "levelup_s1_hoarfrost",
		[40] = "title_s1_veteran",
	}
	local premiumLooks: { [number]: string } = {
		[1] = "frame_s1_hoarfrost",
		[5] = "emote_s1_brushfrost",
		[8] = "chatframe_s1_rime",
		[11] = "dye_s1_midnight",
		[14] = "trail_s1_snowdrift",
		[17] = "title_s1_frostwarden",
		[20] = "outfit_s1_frostwarden",
		[23] = "weapon_s1_rime",
		[27] = "mountskin_s1_frost",
		[31] = "pet_s1_snowfox",
		[35] = "levelup_s1_aurora",
		[40] = "aura_s1_winterheart",
	}
	local filler = 0
	for tier = 2, 40, 2 do
		local look = freeLooks[tier]
		if look then
			S1_FREE[tier] = cosmetic(look)
		else
			filler += 1
			S1_FREE[tier] = if filler % 2 == 1 then item("stone_return", 3) else lure(3600)
		end
	end
	filler = 0
	for tier = 1, 40 do
		local look = premiumLooks[tier]
		if look then
			S1_PREMIUM[tier] = cosmetic(look)
		else
			filler += 1
			S1_PREMIUM[tier] = if filler % 2 == 1 then item("stone_return", 5) else lure(3600)
		end
	end
end

local SEASONS: { SeasonDef } = {
	{
		id = "s1",
		nameKey = "season.s1.name",
		start = monday(2026, 11, 2),
		weeks = 8,
		tiers = 40,
		rewards = { free = S1_FREE, premium = S1_PREMIUM },
	},
}

-- Points per source (Logic/Season.add; the server's SeasonService.Add). kill / elite / elite2 = a credited monster of
-- that variant; boss = a won dungeon boss; worldBoss = a rewarded world boss fight; quest / side / contract = a story,
-- side or hunting contract hand-in; daily / weekly = a collected daily or weekly contract (the boss contract too);
-- worldEvent / bloodMoon = a rewarded participation; arena = a played arena match; achievement = an achievement earned.
local POINTS: { [string]: number } = {
	kill = 2,
	elite = 10,
	elite2 = 40,
	boss = 150,
	worldBoss = 200,
	quest = 60,
	side = 40,
	contract = 40,
	daily = 80,
	weekly = 250,
	worldEvent = 120,
	bloodMoon = 150,
	arena = 20,
	achievement = 50,
}

-- The sources the daily monster limit counts (LIMITS.killPerDay; an Elite II is not limited).
local KILL_SOURCES: { [string]: boolean } = { kill = true, elite = true }

local byId: { [string]: SeasonDef } = {}
for _, def in SEASONS do
	assert(byId[def.id] == nil, `Data/Seasons: duplicate season {def.id}`)
	byId[def.id] = def
end

-- cosmetic id -> the track whose reward it is (a cosmetic is on one track of one season)
local trackOfCosmetic: { [string]: Track } = {}
local function indexTrack(rewards: { [number]: Reward }, track: Track)
	for _, reward in rewards do
		if reward.kind == "cosmetic" and reward.id then
			assert(trackOfCosmetic[reward.id] == nil, `Data/Seasons: cosmetic {reward.id} on two tracks`)
			trackOfCosmetic[reward.id] = track
		end
	end
end
for _, def in SEASONS do
	indexTrack(def.rewards.free, "free")
	indexTrack(def.rewards.premium, "premium")
end

local function endsAt(def: SeasonDef): number
	return def.start + def.weeks * WEEK
end

return table.freeze({
	SEASONS = SEASONS,
	POINTS = table.freeze(POINTS),
	KILL_SOURCES = table.freeze(KILL_SOURCES),
	TIER_POINTS = 1000, -- every tier the same
	-- killPerDay: points of kill + elite a UTC day; weekCap: the points an account may hold at the end of week w of
	-- the season are weekCap x w (a week missed is caught up later)
	LIMITS = table.freeze({ killPerDay = 400, weekCap = 6500 }),
	-- below behind x tiers x (elapsed / length) tiers every source gives x mul (rounded down) up to that line
	CATCHUP = table.freeze({ mul = 1.5, behind = 0.6 }),
	GRACE_DAYS = 14, -- after the end: the rewards are still claimed in the window, then they come by mail once
	WEEK = WEEK,
	list = SEASONS,
	get = function(id: string): SeasonDef?
		return byId[id]
	end,
	endsAt = endsAt,
	-- The track of a season cosmetic ("free" | "premium"), nil when no season gives it.
	trackOf = function(cosmeticId: string): Track?
		return trackOfCosmetic[cosmeticId]
	end,
	-- The running season at `now` (start <= now < end), or nil.
	at = function(now: number): SeasonDef?
		for _, def in SEASONS do
			if now >= def.start and now < endsAt(def) then
				return def
			end
		end
		return nil
	end,
	-- The first season starting after `now`, or nil.
	next = function(now: number): SeasonDef?
		local best: SeasonDef? = nil
		for _, def in SEASONS do
			if def.start > now and (best == nil or def.start < (best :: SeasonDef).start) then
				best = def
			end
		end
		return best
	end,
	-- The last season that ended at or before `now`, or nil.
	lastEnded = function(now: number): SeasonDef?
		local best: SeasonDef? = nil
		for _, def in SEASONS do
			if endsAt(def) <= now and (best == nil or endsAt(def) > endsAt(best :: SeasonDef)) then
				best = def
			end
		end
		return best
	end,
})
