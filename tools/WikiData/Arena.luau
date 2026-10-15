--!strict
-- arena.json (S131, DESIGN-17 §9): the ranked arena (S126-S128) and the PvP events on the clock: the Blood Moon (S129)
-- and the Champion's Tournament (S130), in one file (one group of topics, one data block). Every field is picked by
-- hand from Data/Arena and Data/ScheduledEvents (names from the Locale, cosmetic kinds from Data/Cosmetics, rarity keys
-- from Data/Rarities); never Data/Products, Logic/Premium or a service. No store names, keys, TTLs, polling intervals,
-- place or job ids and no amounts of Dragon Shards: a reward that gives them says `currency = true` (docs/WIKI.md §1).
-- Times are UTC (the page says so); signups are minutes before the start.

local Arena = require("../../src/shared/Data/Arena")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Names = require("./Names")
local Rarities = require("../../src/shared/Data/Rarities")
local ScheduledEvents = require("../../src/shared/Data/ScheduledEvents")
local Schema = require("./Schema")
local Titles = require("../../src/shared/Data/Titles")

local S = Schema
local arr, rec = S.arr, S.rec

local ArenaWiki = {}

local SLOT = rec("EventSlot", { weekday = "int", hour = "int", minute = "int" })
-- place: "participant" | "top" (with `top` = the last rank that gets it) | "1" | "2" | "3" (the tournament places)
local REWARD = rec("EventReward", {
	place = "string",
	["top?"] = "int",
	["tokens?"] = "int",
	["title?"] = "name",
	["titleDays?"] = "int",
	["frame?"] = "name",
	["aura?"] = "name",
	["blessing?"] = "name",
	currency = "bool",
})

S.file(
	"arena",
	rec("ArenaFile", {
		minLevel = "int",
		brackets = arr(rec("ArenaBracket", { min = "int", max = "int" })),
		rules = rec("ArenaRules", {
			roundsToWin = "int",
			roundTime = "int",
			potions = "int",
			sameOpponentDaily = "int",
			start = "int",
			k = "int",
			kNew = "int",
			kNewMatches = "int",
			teamTime = "int",
			acceptSec = "int",
			declinePenaltyMin = "int",
		}),
		tiers = arr(rec("ArenaTier", { id = "string", name = "name", min = "int" })),
		season = rec("ArenaSeason", { softReset = "number", minPlayed = "int" }),
		tokens = rec("ArenaTokens", {
			win = "int",
			loss = "int",
			win3 = "int",
			loss3 = "int",
			firstDaily = "int",
			firstMul = "number",
			weekCap = "int",
		}),
		shop = arr(rec("ArenaShopEntry", {
			id = "string",
			kind = "string",
			group = "string",
			["item?"] = "ref:items",
			["n?"] = "int",
			["cosmetic?"] = "string",
			name = "name",
			tokens = "int",
		})),
		seasonRewards = arr(rec("ArenaSeasonReward", {
			tier = "string",
			name = "name",
			["title?"] = "name",
			["frame?"] = "name",
			["aura?"] = "name",
			currency = "bool",
		})),
		bloodMoon = rec("BloodMoonInfo", {
			slots = arr(SLOT),
			durationMin = "int",
			warnMin = arr("int"),
			regions = arr("name"),
			points = rec("BloodMoonPoints", {
				player = "int",
				elite = "int",
				elite2 = "int",
				levelGap = "int",
				sameVictim = "int",
			}),
			minPoints = "int",
			eliteChance = "number",
			rewards = arr(REWARD),
		}),
		tourney = rec("TourneyInfo", {
			slot = SLOT,
			signupFromMin = "int",
			signupToMin = "int",
			cap = "int",
			minPlayers = "int",
			inviteSec = "int",
			fields = "int",
			hallWeeks = "int",
			rewards = arr(REWARD),
		}),
	})
)

local function cosmeticName(id: string): any
	return Names.of(`cosmetic.{id}`)
end

-- A season title carries the season in game ("{season}"): the wiki shows its plain name, as Basics.titles (S131).
local function seasonTitle(id: string): any
	local def = Titles.get(id)
	local key = if def then def.nameKey else `title.{id}`
	return if def and def.seasonArg then Names.of(`{key}.plain`) else Names.of(key)
end

-- Splits reward cosmetics into the frame and the aura fields (the only kinds the events and seasons give).
local function looks(ids: { string }?, out: { [string]: any })
	for _, id in ids or {} do
		local def = Cosmetics.get(id)
		if def and def.kind == "frame" then
			out.frame = cosmeticName(id)
		elseif def and def.kind == "aura" then
			out.aura = cosmeticName(id)
		end
	end
end

local function slotOf(slot: any): any
	return { weekday = slot.weekday, hour = slot.hour, minute = slot.minute }
end

local function minutes(seconds: number): number
	return math.floor(seconds / 60)
end

function ArenaWiki.build(ctx: any): any
	local one = Arena.MODES["1v1"]
	local three = Arena.MODES["3v3"]
	local brackets = {}
	for _, b in Arena.BRACKETS do
		table.insert(brackets, { min = b.min, max = b.max })
	end
	local tiers = {}
	for _, t in Arena.TIERS do
		table.insert(tiers, { id = t.id, name = Names.of(`arena.tier.{t.id}`), min = t.min })
	end
	local shop = {}
	for _, e in Arena.SHOP do
		if not ctx.hidden[e.id] then
			table.insert(shop, {
				id = e.key,
				kind = e.kind,
				group = e.group,
				item = if e.kind == "item" then e.id else nil,
				n = if e.kind == "item" and (e.n or 1) > 1 then e.n else nil,
				cosmetic = if e.kind == "cosmetic" then e.id else nil,
				name = if e.kind == "item" then Names.item(e.id) else cosmeticName(e.id),
				tokens = e.price,
			})
		end
	end
	local seasonRewards = {}
	for _, t in Arena.TIERS do
		local r = Arena.SEASON_REWARDS[t.id]
		if r then
			local row: { [string]: any } = {
				tier = t.id,
				name = Names.of(`arena.tier.{t.id}`),
				title = seasonTitle(r.title),
				currency = (r.shards or 0) > 0,
			}
			looks(r.cosmetics, row)
			table.insert(seasonRewards, row)
		end
	end

	local moonDef = ScheduledEvents.get("bloodmoon") :: ScheduledEvents.EventDef
	local moon = ScheduledEvents.bloodMoon
	local regions = {}
	for _, id in moon.regions do
		table.insert(regions, Names.of(`map.{id}.name`))
	end
	local warn = {}
	for _, s in moonDef.warn do
		table.insert(warn, minutes(s))
	end
	local slots = {}
	for _, s in moonDef.slots do
		table.insert(slots, slotOf(s))
	end
	local mr = moon.reward
	local moonRewards: { any } = {
		{
			place = "participant",
			tokens = mr.tokens,
			blessing = Names.of(`rarity.{Rarities.get(mr.blessingRarity).key}`),
			currency = false,
		},
		{
			place = "top",
			top = mr.titleTop,
			title = Names.of(`title.{mr.titleId}`),
			titleDays = mr.titleDays,
			currency = false,
		},
		{ place = "top", top = mr.frameTop, frame = cosmeticName(mr.frameId), currency = false },
		{ place = "top", top = mr.shardsTop, currency = mr.shards > 0 },
	}

	local cupDef = ScheduledEvents.get("tourney") :: ScheduledEvents.EventDef
	local cup = Arena.TOURNEY
	local cupRewards: { any } = {}
	for _, r in cup.rewards do
		local row: { [string]: any } = {
			place = tostring(r.place),
			title = if r.title then Names.of(`title.{r.title}`) else nil,
			titleDays = if r.title then r.titleDays else nil,
			currency = (r.shards or 0) > 0,
		}
		looks(r.cosmetics, row)
		table.insert(cupRewards, row)
	end
	table.insert(cupRewards, { place = "participant", tokens = cup.participantTokens, currency = false })

	return {
		minLevel = Arena.MIN_LEVEL,
		brackets = brackets,
		rules = {
			roundsToWin = one.winsNeeded,
			roundTime = one.roundTime,
			potions = one.potions,
			sameOpponentDaily = Arena.LIMITS.sameOpponentDaily,
			start = Arena.ELO.start,
			k = Arena.ELO.k,
			kNew = Arena.ELO.kNew,
			kNewMatches = Arena.ELO.newGames,
			teamTime = three.roundTime,
			acceptSec = Arena.QUEUE.acceptSeconds,
			declinePenaltyMin = minutes(Arena.QUEUE.declinePenalty),
		},
		tiers = tiers,
		season = { softReset = Arena.SEASON.keep, minPlayed = Arena.seasonMinPlayed },
		tokens = {
			win = Arena.TOKENS.win1v1,
			loss = Arena.TOKENS.loss1v1,
			win3 = Arena.TOKENS.win3v3,
			loss3 = Arena.TOKENS.loss3v3,
			firstDaily = Arena.TOKENS.firstMatches,
			firstMul = Arena.TOKENS.firstMul,
			weekCap = Arena.tokensWeekCap,
		},
		shop = shop,
		seasonRewards = seasonRewards,
		bloodMoon = {
			slots = slots,
			durationMin = minutes(moonDef.duration),
			warnMin = warn,
			regions = regions,
			points = {
				player = moon.points.player,
				elite = moon.points.elite,
				elite2 = moon.points.elite2,
				levelGap = moon.levelGap,
				sameVictim = moon.sameVictimMax,
			},
			minPoints = mr.minPoints,
			eliteChance = moon.eliteChance,
			rewards = moonRewards,
		},
		tourney = {
			slot = slotOf(cupDef.slots[1]),
			signupFromMin = minutes(-cup.window.open),
			signupToMin = minutes(-cup.window.close),
			cap = cup.cap,
			minPlayers = cup.minPlayers,
			inviteSec = cup.window.invite,
			fields = cup.fields,
			hallWeeks = cup.hallWeeks,
			rewards = cupRewards,
		},
	}
end

return ArenaWiki
