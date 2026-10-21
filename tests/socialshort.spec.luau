--!strict
-- 2026-10-21 (owner: too many detailed descriptions): the short lines of the social, PvP and season windows (guild,
-- party, friends, arena, tournament, Blood Moon, rankings, season pass, death screen, bestiary, map cards). Each short
-- line fits one row (at most 60 characters with its placeholders, no dash) in both languages, and the full text it
-- replaces still exists (it moved behind an "i" or under "More", nothing is removed).
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local MAX = 60

-- New visible short lines; the full text stays under the key without ".short".
local SHORT = {
	"guild.goals.intro.short",
	"guild.rally.active.short",
	"guild.rally.hint.short",
	"guild.banner.hint.short",
	"guild.banner.hintMember.short",
	"guild.rights.hint.short",
	"guild.settings.chatHint.short",
	"guild.settings.leaderHint.short",
	"guild.bank.hint.short",
	"guild.noneInfo.short",
	"party.none.short",
	"social.ignored.hint.short",
	"arena.rules.1v1.short",
	"arena.rules.3v3.short",
	"arena.net.waitingLocal.short",
	"arena.season.yourTier.short",
	"tourney.desc.short",
	"tourney.rewards.champion.short",
	"bloodmoon.desc.short",
	"bloodmoon.window.localOnly.short",
	"leaderboard.week.rewards.short",
	"season.how.limits.short",
	"season.soon.desc.short",
	"best.bonus.short",
	"worldboss.card.every.short",
	"worldmap.card.group.short",
}

-- Texts shortened in place (what was cut went behind an "i" as `<key>.info`, or is said by the "i" of the section).
local SHORTENED = {
	"guild.goals.mine",
	"guild.goal.progress",
	"guild.found.intro",
	"party.pool",
	"party.poolNone",
	"party.variety",
	"party.varietyNone",
	"social.friends.empty",
	"tourney.overflow",
	"bloodmoon.rules.top1",
	"bloodmoon.rules.blocked",
	"death.protectionNote",
	"death.error.noShards",
	"death.bloodMoonHint",
	"death.nothingLost",
	"worldboss.card.sleeps",
}

-- The cut part of a shortened text, shown by the "i".
local INFO = { "guild.found.intro.info", "death.protectionNote.info" }

local function placeholders(text: string): { string }
	local out = {}
	for name in string.gmatch(text, "{([%w_]+)}") do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- Every line of a text fits a row (a placeholder counts as its written form, e.g. "{n}" as 3 characters).
local function longestLine(text: string): number
	local longest = 0
	for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
		longest = math.max(longest, utf8.len(line) or #line)
	end
	return longest
end

T.describe("Short lines of the social, PvP and season windows", function()
	T.it("exist in both languages with the same placeholders", function()
		local all = table.clone(SHORT)
		table.move(SHORTENED, 1, #SHORTENED, #all + 1, all)
		table.move(INFO, 1, #INFO, #all + 1, all)
		for _, key in all do
			T.expect({ key = key, pl = type(pl[key]), en = type(en[key]) }).toEqual({
				key = key,
				pl = "string",
				en = "string",
			})
			T.expect({ key = key, args = placeholders(pl[key]) }).toEqual({ key = key, args = placeholders(en[key]) })
		end
	end)

	T.it("fit one row: at most 60 characters a line, no dash", function()
		local all = table.clone(SHORT)
		table.move(SHORTENED, 1, #SHORTENED, #all + 1, all)
		for _, key in all do
			for lang, texts in { pl = pl, en = en } do
				local text = texts[key]
				T.expect({ key = key, lang = lang, long = longestLine(text) > MAX }).toEqual({
					key = key,
					lang = lang,
					long = false,
				})
				T.expect({ key = key, lang = lang, dash = string.find(text, "—", 1, true) ~= nil }).toEqual({
					key = key,
					lang = lang,
					dash = false,
				})
			end
		end
	end)

	T.it("keep the full text they replace (moved behind an i or under More)", function()
		for _, key in SHORT do
			local full = string.sub(key, 1, #key - #".short")
			T.expect({ key = full, pl = type(pl[full]), en = type(en[full]) }).toEqual({
				key = full,
				pl = "string",
				en = "string",
			})
			-- the full text says more than the short line
			T.expect({ key = key, longer = utf8.len(pl[full]) > utf8.len(pl[key]) }).toEqual({
				key = key,
				longer = true,
			})
		end
		for _, key in INFO do
			local base = string.sub(key, 1, #key - #".info")
			T.expect({ key = base, pl = type(pl[base]), en = type(en[base]) }).toEqual({
				key = base,
				pl = "string",
				en = "string",
			})
		end
	end)
end)
