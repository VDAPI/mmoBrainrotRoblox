--!strict
-- 2026-10-21 (owner: too many detailed descriptions), group 2: shops, blacksmith, premium, mail, rewards. A window shows
-- one short line and keeps the full text behind an "i" (Components/InfoTip):
--   every short line is at most VISIBLE characters (placeholders counted as written), one line, no dash, in both
--   languages; a short line uses only placeholders its full text has (the window passes the same arguments);
--   a confirmation shortened in place keeps at most two lines of at most MODAL characters;
--   every Dragon Shop entry and pass whose description is longer than VISIBLE has its short line.

local Products = require("../src/shared/Data/Products")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = T.describe, T.it, T.expect

local VISIBLE = 60
local MODAL = 80

-- short line -> the full text behind its "i" (the old key, unchanged)
local SHORT: { [string]: string } = {
	["premium.sub.vip.short"] = "premium.sub.vip.desc",
	["premium.pass.pockets.short"] = "premium.pass.pockets.desc",
	["premium.mounts.short"] = "premium.mounts.desc",
	["smith.effect.intro.short"] = "smith.effect.intro",
	["smith.reroll.all.hint.short"] = "smith.reroll.all.hint",
	["smith.transmog.note.short"] = "smith.transmog.note",
	["portalshop.intro.short"] = "portalshop.intro",
	["shop.vendor.otherClass.short"] = "shop.vendor.otherClass",
	["auction.sell.rules.short"] = "auction.sell.rules",
	["login.claimFor.short"] = "login.claimFor",
	["login.chest.short"] = "login.chest",
	["worldboss.rewardCard.share.short"] = "worldboss.rewardCard.share",
	["wardrobe.hint.short"] = "wardrobe.hint",
	["wardrobe.transmog.hint.short"] = "wardrobe.transmog.hint",
	["look.avatarOn.short"] = "look.avatarOn",
}

-- one-line texts shortened in place or new (the cut part, where it matters, is a new .info key)
local LINES = {
	"premium.season.desc",
	"premium.currency.note",
	"vip.noPower",
	"vip.noPower.info",
	"smith.effect.pick",
	"shop.pick",
	"shop.sellHint",
	"shop.markedNone",
	"auction.sell.costs",
	"auction.sell.pick",
	"auction.sell.pick.info",
	"mail.compose.intro",
	"mail.compose.items",
	"mail.compose.items.info",
	"dungeon.reward.none",
	"wardrobe.hint.info",
}

-- confirmations shortened in place (and the gear line the wandering merchant adds under its question)
local MODALS = {
	"smith.reroll.all.confirm",
	"portalshop.permConfirm",
	"wanderer.confirm",
	"wanderer.confirmMarks",
	"wanderer.confirmGear",
}

local LANGS: { [string]: { [string]: string } } = { pl = pl, en = en }

local function placeholders(text: string): { string }
	local found = {}
	for name in string.gmatch(text, "{([%w_]+)}") do
		if not table.find(found, name) then
			table.insert(found, name)
		end
	end
	table.sort(found)
	return found
end

-- "lang key: why" for a line that is missing, too long, wraps or has a dash.
local function lineProblems(key: string, max: number, lines: number): { string }
	local out = {}
	for lang, texts in LANGS do
		local text = texts[key]
		if text == nil then
			table.insert(out, `{lang} {key}: missing`)
			continue
		end
		local parts = string.split(text, "\n")
		if #parts > lines then
			table.insert(out, `{lang} {key}: {#parts} lines`)
		end
		for _, part in parts do
			local length = utf8.len(part) or #part
			if length > max then
				table.insert(out, `{lang} {key}: {length} characters`)
			end
		end
		if string.find(text, "—", 1, true) then
			table.insert(out, `{lang} {key}: a dash`)
		end
	end
	return out
end

describe("Short lines of shops, blacksmith, premium, mail and rewards (2026-10-21)", function()
	it("short lines fit one line in both languages", function()
		local problems = {}
		for key in SHORT do
			table.move(lineProblems(key, VISIBLE, 1), 1, -1, #problems + 1, problems)
		end
		for _, key in LINES do
			table.move(lineProblems(key, VISIBLE, 1), 1, -1, #problems + 1, problems)
		end
		table.sort(problems)
		expect(problems).toEqual({})
	end)

	it("confirmations keep at most two short lines", function()
		local problems = {}
		for _, key in MODALS do
			table.move(lineProblems(key, MODAL, 2), 1, -1, #problems + 1, problems)
		end
		table.sort(problems)
		expect(problems).toEqual({})
	end)

	it("every short line keeps its full text with the placeholders it uses", function()
		local problems = {}
		for short, full in SHORT do
			for lang, texts in LANGS do
				local fullText = texts[full]
				if fullText == nil then
					table.insert(problems, `{lang} {full}: missing`)
					continue
				end
				local have = placeholders(fullText)
				for _, name in placeholders(texts[short] or "") do
					if not table.find(have, name) then
						table.insert(problems, `{lang} {short}: \{{name}} not in {full}`)
					end
				end
			end
		end
		table.sort(problems)
		expect(problems).toEqual({})
	end)

	it("every Dragon Shop entry and pass with a long description has a short line", function()
		local missing = {}
		local function check(base: string)
			local desc = pl[`{base}.desc`]
			if desc and (utf8.len(desc) or #desc) > VISIBLE then
				for lang, texts in LANGS do
					local short = texts[`{base}.short`]
					if short == nil then
						table.insert(missing, `{lang} {base}.short: missing`)
					elseif (utf8.len(short) or #short) > VISIBLE then
						table.insert(missing, `{lang} {base}.short: too long`)
					end
				end
			end
		end
		for _, entry in Products.shop do
			check(`premium.shop.{entry.key}`)
		end
		for _, pass in Products.passes do
			check(`premium.pass.{pass.key}`)
		end
		table.sort(missing)
		expect(missing).toEqual({})
	end)
end)
