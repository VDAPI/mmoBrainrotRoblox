--!strict
-- Owner 2026-10-21 (too many detailed descriptions, the game unreadable), group 3 (character, skills, quests, menu,
-- tutorial): the visible texts stay one short line in both languages with the same placeholders, the long ones they
-- replace still exist (they moved behind an "i" or "More"), and no em dash.

local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

-- One visible line: at most this many characters (placeholders as written).
local LINE = 60
-- A confirmation modal or a toast: one or two short sentences.
local MODAL = 120

-- the visible line -> the longer text kept behind the "i" / "More" (nil: a label shortened in place)
local LINES: { [string]: string | false } = {
	["tracker.title"] = false,
	["tracker.group.quests"] = false,
	["tracker.group.contracts"] = false,
	["tracker.group.daily"] = false,
	["tracker.group.weekly"] = false,
	["tracker.contracts.more"] = false,
	["tracker.contracts.toTake"] = false,
	["contract.whereTurnIn.short"] = "contract.whereTurnIn",
	["quest.bossContract.text.short"] = "quest.bossContract.text",
	["quest.side.none"] = false,
	["quest.set.bonusHint"] = false,
	["quest.set.shardsLevel"] = false,
	["quest.set.shardsTaken"] = false,
	["quest.set.shardsTakenWeek"] = false,
	["menu.section.sound"] = false,
	["menu.section.graphics"] = false,
	["menu.section.combat"] = false,
	["menu.section.interface"] = false,
	["menu.section.loot"] = false,
	["menu.section.social"] = false,
	["keys.hint"] = "keys.hint.info",
	["menu.hudLayout"] = "menu.hudLayout.info",
	["menu.achToasts"] = "menu.achToasts.info",
	["menu.lowHpWarn"] = "menu.lowHpWarn.info",
	["menu.fightCard"] = "menu.fightCard.info",
	["menu.appearOffline"] = "menu.appearOffline.info",
	["menu.shake"] = "menu.shake.info",
	["menu.quickCast"] = "menu.quickCast.info",
	["menu.autoTarget"] = "menu.autoTarget.info",
	["menu.robloxAvatar"] = "menu.robloxAvatar.hint",
	["stat.str.short"] = "stat.str.desc",
	["stat.dex.short"] = "stat.dex.desc",
	["stat.int.short"] = "stat.int.desc",
	["stat.vit.short"] = "stat.vit.desc",
	["class.Warrior.short"] = "class.Warrior.desc",
	["class.Mage.short"] = "class.Mage.desc",
	["class.Hunter.short"] = "class.Hunter.desc",
	["class.Cleric.short"] = "class.Cleric.desc",
	["charSelect.create.lookHint"] = false,
	["skills.pool.preview.short"] = "skills.pool.preview",
	["bp.rule.short"] = "bp.rule",
	["paths.soon.body.short"] = "paths.soon.body",
	["quest.reroll.hint"] = false,
	["fish.hint"] = false,
	["quest.lowLevel"] = false,
	["quest.say.later"] = false,
}

-- modals, toasts and the tutorial tile: one or two short sentences
local SENTENCES: { string } = {
	"skills.reset.confirm",
	"buildset.copy.message",
	"paths.confirm.reset.paid",
	"paths.confirm.refund.message",
	"tutorial.quest.pc",
	"tutorial.quest.touch",
	"tutorial.attack.travel",
	"tutorial.move.pc",
	"tutorial.backpack.touch",
	"unlock.dungeon",
	"rework2.mage",
	"npc.fence.greeting",
	"npc.portalmaster.greeting",
	"npc.huntmaster.greeting",
	"npc.wanderer.greeting",
}

local function placeholders(text: string): { string }
	local out: { string } = {}
	for name in string.gmatch(text, "{(%w+)}") do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local function check(key: string, limit: number)
	for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
		local text = texts[key]
		T.expect(text ~= nil).toBe(true)
		if text then
			local length = utf8.len(text) or #text
			if length > limit then
				error(`{lang} {key}: {length} > {limit} characters`)
			end
			if string.find(text, "—", 1, true) then
				error(`{lang} {key}: em dash`)
			end
		end
	end
	T.expect(table.concat(placeholders(pl[key] or ""), ",")).toBe(table.concat(placeholders(en[key] or ""), ","))
end

T.describe("Short texts, group 3 (owner 2026-10-21)", function()
	T.it(`every visible line has at most {LINE} characters in both languages`, function()
		for key in LINES do
			check(key, LINE)
		end
	end)

	T.it("the longer text behind the i or More still exists with the same placeholders as its line", function()
		for key, long in LINES do
			if long then
				T.expect(pl[long] ~= nil and en[long] ~= nil).toBe(true)
				-- a short line never needs an argument its long text lacks
				local have: { [string]: boolean } = {}
				for _, name in placeholders(pl[long]) do
					have[name] = true
				end
				for _, name in placeholders(pl[key]) do
					if not have[name] then
						error(`{key}: {"{"}{name}{"}"} is not in {long}`)
					end
				end
			end
		end
	end)

	T.it(`modals, toasts, greetings and the tutorial tile stay within {MODAL} characters`, function()
		for _, key in SENTENCES do
			check(key, MODAL)
		end
	end)
end)
