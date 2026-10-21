--!strict
-- Owner 2026-10-21 (too many detailed descriptions, the game unreadable), group 3 (character, skills, quests, menu,
-- tutorial): the visible texts stay one short line in both languages with the same placeholders, the long ones they
-- replace still exist (they moved behind an "i" or "More"), and no em dash.

local NodeText = require("../src/shared/Logic/NodeText")
local PathData = require("../src/shared/Data/Paths")
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
	-- SkillsWindow/Details (the path card, the hints)
	["skills.tree.leadingHint.short"] = "skills.tree.leadingHint",
	["skill.adaptive.short"] = "skill.adaptive",
	["paths.tree.hint"] = false,
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

-- every description of a direction node (not the skill nodes, they show the skill's own text)
local function nodeDescKeys(): { string }
	local out: { string } = {}
	for _, path in PathData.list do
		for _, row in path.rows do
			for _, node in row.nodes do
				if string.sub(node.descKey, 1, 5) == "path." and pl[node.descKey] then
					table.insert(out, node.descKey)
				end
			end
		end
	end
	table.sort(out)
	return out
end

-- a line as the player reads it: every placeholder as a two-digit number
local function shown(text: string): number
	local filled = string.gsub(text, "{%w+}", "10")
	return utf8.len(filled) or #filled
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

	T.it("every long direction node has a short line in both languages, one line with its numbers", function()
		local keys = nodeDescKeys()
		T.expect(#keys > 100).toBe(true)
		local long = 0
		for _, descKey in keys do
			if (utf8.len(pl[descKey]) or 0) > NodeText.LONG then
				long += 1
				local short = NodeText.shortKey(descKey, "pl")
				if not short or NodeText.shortKey(descKey, "en") ~= short then
					error(`{descKey}: no short line in both languages`)
				end
				local have: { [string]: boolean } = {}
				for _, name in placeholders(pl[descKey]) do
					have[name] = true
				end
				for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
					local text = texts[short]
					if shown(text) > LINE then
						error(`{lang} {short}: {shown(text)} > {LINE} characters`)
					end
					if string.find(text, "—", 1, true) then
						error(`{lang} {short}: em dash`)
					end
					for _, name in placeholders(text) do
						if not have[name] then
							error(`{short}: {"{"}{name}{"}"} is not in {descKey}`)
						end
					end
				end
				T.expect(table.concat(placeholders(pl[short]), ",")).toBe(table.concat(placeholders(en[short]), ","))
			end
		end
		T.expect(long >= 40).toBe(true)
	end)

	T.it("NodeText.plan: the next rank, the current one at the limit, rank 1 before buying", function()
		local before = NodeText.plan(0, 3)
		T.expect(before.rank).toBe(1)
		T.expect(before.now).toBeNil()
		T.expect(before.label).toBe("atRank")
		local mid = NodeText.plan(1, 3)
		T.expect(mid.rank).toBe(2)
		T.expect(mid.now).toBe(1)
		T.expect(mid.label).toBe("atRank")
		local full = NodeText.plan(3, 3)
		T.expect(full.rank).toBe(3)
		T.expect(full.now).toBeNil()
		T.expect(full.label).toBe("now")
	end)

	T.it("NodeText.shortKey: only an existing .short of a .desc", function()
		T.expect(NodeText.shortKey("path.scout.royalFalcon.desc", "pl")).toBe("path.scout.royalFalcon.short")
		T.expect(NodeText.shortKey("path.scout.royalFalcon.desc", "en")).toBe("path.scout.royalFalcon.short")
		T.expect(NodeText.shortKey("path.scout.royalFalcon.name", "pl")).toBeNil()
		T.expect(NodeText.shortKey("path.nope.nothing.desc", "pl")).toBeNil()
	end)

	T.it("the parts cut from shortened texts are kept behind the i or More (nothing removed)", function()
		-- the shortened text -> where its cut part lives (NpcDialog "i", Modal `Details`)
		local kept: { [string]: string } = {
			["npc.huntmaster.greeting"] = "npc.huntmaster.greeting.info",
			["npc.fence.greeting"] = "npc.fence.greeting.info",
			["npc.portalmaster.greeting"] = "npc.portalmaster.greeting.info",
			["npc.wanderer.greeting"] = "npc.wanderer.greeting.info",
			["buildset.copy.message"] = "buildset.copy.message.info",
			["rework2.body"] = "rework2.body.info",
			["rework2.mage"] = "rework2.mage.info",
			["skills.reset.confirm"] = "skills.reset.confirm.info",
			["paths.confirm.reset.paid"] = "paths.confirm.reset.paid.info",
			["paths.confirm.refund.message"] = "paths.confirm.refund.message.info",
		}
		for short, info in kept do
			for lang, texts in { pl = pl, en = en } :: { [string]: { [string]: string } } do
				if not texts[info] then
					error(`{lang} {info}: missing`)
				end
				if string.find(texts[info], "—", 1, true) then
					error(`{lang} {info}: em dash`)
				end
			end
			T.expect(table.concat(placeholders(pl[info]), ",")).toBe(table.concat(placeholders(en[info]), ","))
			-- the dialog passes the same arguments to both
			local have: { [string]: boolean } = {}
			for _, name in placeholders(pl[short]) do
				have[name] = true
			end
			if short == "rework2.body" then
				have.slots, have.level = true, true
			end
			for _, name in placeholders(pl[info]) do
				if not have[name] then
					error(`{info}: {"{"}{name}{"}"} is not passed with {short}`)
				end
			end
		end
		-- the four bits the coordinator named
		T.expect(string.find(pl["quest.set.shardsTaken"], "na tym koncie", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["quest.set.shardsTakenWeek"], "na tym koncie", 1, true) ~= nil).toBe(true)
		T.expect(string.find(en["quest.set.shardsTaken"], "on this account", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["npc.huntmaster.greeting.info"], "Znak", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["buildset.copy.message.info"], "Darmowy reset", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["rework2.body.info"], "{slots}", 1, true) ~= nil).toBe(true)
		T.expect(string.find(pl["rework2.body.info"], "{level}", 1, true) ~= nil).toBe(true)
	end)

	T.it(`modals, toasts, greetings and the tutorial tile stay within {MODAL} characters`, function()
		for _, key in SENTENCES do
			check(key, MODAL)
		end
	end)
end)
