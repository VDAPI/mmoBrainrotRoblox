--!strict
-- The hands-on tutorial (S155, docs/DESIGN.md §20 "Samouczek"): steps and their order, counting ahead, skipping, the
-- client whitelist, PC / phone texts, key labels from the player's bindings, the onboarding funnel and the level reward
-- (Logic/Tutorial, Data/Tutorial). UI plan package A (owner 2026-11-10, "things covering each other"; the plan's L9):
-- the frozen anchor names (Tutorial.ANCHOR_NAMES) that Screens/Hud still builds, the tile's place (Logic/TutorialTile)
-- inside the layer and off its element, the message zone and the phone's skill arc on every screen, and the texts per
-- device (the phone's own `.phone` text where one exists).
local fs = require("@lune/fs")

local AdminCommands = require("../src/shared/Data/AdminCommands")
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local CharacterFactory = require("../src/shared/Logic/CharacterFactory")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local HudMenu = require("../src/shared/Logic/HudMenu")
local HudStack = require("../src/shared/Logic/HudStack")
local HudZones = require("../src/shared/Logic/HudZones")
local Items = require("../src/shared/Data/Items")
local Keybinds = require("../src/shared/Data/Keybinds")
local Npcs = require("../src/shared/Data/Npcs")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local Premium = require("../src/shared/Logic/Premium")
local Quests = require("../src/shared/Data/Quests")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")
local Titles = require("../src/shared/Data/Titles")
local Tutorial = require("../src/shared/Logic/Tutorial")
local TutorialData = require("../src/shared/Data/Tutorial")
local TutorialTile = require("../src/shared/Logic/TutorialTile")
local fixtureA = require("./fixtures/textcaps/A") :: any
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local ORDER = { "move", "quest", "backpack", "potion", "attack", "skill", "done" }

local function fresh(): Tutorial.State
	return Tutorial.newState()
end

-- Feeds events in order; returns the final state.
local function feed(state: Tutorial.State, events: { string }): Tutorial.State
	for _, e in events do
		state = Tutorial.advance(state, e)
	end
	return state
end

T.describe("Tutorial: steps", function()
	T.it("six action steps in a fixed order, then done", function()
		local ids = {}
		for _, s in Tutorial.STEPS do
			table.insert(ids, s.id)
		end
		T.expect(ids).toEqual(ORDER)
		T.expect(Tutorial.ACTIONS).toBe(6)
	end)

	T.it("only move and backpack are client steps; every step has a known anchor and real key actions", function()
		local anchors = {
			joystick = true,
			questTracker = true,
			backpackButton = true,
			potionBar = true,
			attackButton = true,
			skillBar = true,
		}
		for _, s in Tutorial.STEPS do
			local client = s.id == "move" or s.id == "backpack"
			T.expect({ s.id, s.kind }).toEqual({ s.id, if client then "client" else "server" })
			T.expect({ s.id, s.textKey }).toEqual({ s.id, `tutorial.{s.id}` })
			if s.anchor then
				T.expect({ s.id, anchors[s.anchor] == true }).toEqual({ s.id, true })
			end
			for _, action in s.keys do
				T.expect({ s.id, action, Keybinds.get(action) ~= nil }).toEqual({ s.id, action, true })
			end
		end
	end)

	T.it("a new character starts at step 1 with the reward waiting; older characters have it all done", function()
		local made = CharacterFactory.create("Warrior", "Test", {
			newId = function()
				return "x"
			end,
			now = 0,
		})
		T.expect(Tutorial.sanitize(made.tutorial))
			.toEqual({ step = 1, done = false, skipped = false, reward = false, drop = false })
		local old = Tutorial.sanitize(AccountSchema.characterTemplate().tutorial)
		T.expect(old.done).toBe(true)
		T.expect(old.reward).toBe(true)
		T.expect(Tutorial.current(old)).toBeNil()
		T.expect(Tutorial.finale(old)).toBeNil()
		T.expect(Tutorial.rewardDue(old, 50)).toBe(false)
		-- a missing or broken save reads as finished with the reward taken
		T.expect(Tutorial.sanitize(nil)).toEqual({ step = 1, done = true, skipped = false, reward = true, drop = true })
		T.expect(Tutorial.sanitize({ step = 99, pending = { nope = true, done = true, skill = true } })).toEqual({
			step = 7,
			done = false,
			skipped = false,
			reward = true,
			drop = true,
			pending = { skill = true },
		})
	end)
end)

T.describe("Tutorial: advance", function()
	T.it("the current step moves on; all six in order finish it", function()
		local s, changed = Tutorial.advance(fresh(), "move")
		T.expect(changed).toBe(true)
		T.expect(s.step).toBe(2)
		T.expect((Tutorial.current(s) :: Tutorial.Step).id).toBe("quest")
		s = feed(s, { "quest", "backpack", "potion", "attack" })
		T.expect(s.done).toBe(false)
		T.expect((Tutorial.current(s) :: Tutorial.Step).id).toBe("skill")
		s = Tutorial.advance(s, "skill")
		T.expect(s).toEqual({ step = 7, done = true, skipped = false, reward = false, drop = false })
		T.expect(Tutorial.current(s)).toBeNil()
		T.expect((Tutorial.finale(s) :: Tutorial.Step).id).toBe("done")
	end)

	T.it("a later step counts ahead and is not asked again", function()
		local s = feed(fresh(), { "move", "potion" }) -- drank before opening the backpack
		T.expect(s.step).toBe(2)
		T.expect(s.pending).toEqual({ potion = true })
		local again, changed = Tutorial.advance(s, "potion")
		T.expect(changed).toBe(false)
		T.expect(again).toBe(s)
		s = feed(s, { "quest", "backpack" })
		T.expect((Tutorial.current(s) :: Tutorial.Step).id).toBe("attack") -- potion skipped over
		T.expect(s.pending).toBeNil()
		-- everything ahead, then the first step: done in one go
		local all = feed(fresh(), { "skill", "attack", "potion", "backpack", "quest" })
		T.expect(all.step).toBe(1)
		all = Tutorial.advance(all, "move")
		T.expect(all).toEqual({ step = 7, done = true, skipped = false, reward = false, drop = false })
	end)

	T.it("an earlier step, an unknown name, done and anything after the end change nothing", function()
		local s = feed(fresh(), { "move", "quest" })
		for _, e in { "move", "quest", "nope", "done", "" } do
			local after, changed = Tutorial.advance(s, e)
			T.expect({ e, changed }).toEqual({ e, false })
			T.expect(after).toBe(s)
		end
		local finished = feed(fresh(), { "move", "quest", "backpack", "potion", "attack", "skill" })
		local _, changed = Tutorial.advance(finished, "move")
		T.expect(changed).toBe(false)
	end)

	T.it("advance never changes the state it was given", function()
		local s = fresh()
		local _ = Tutorial.advance(s, "move")
		local _ = Tutorial.advance(s, "skill")
		T.expect(s).toEqual({ step = 1, done = false, skipped = false, reward = false, drop = false })
	end)
end)

T.describe("Tutorial: skip and the client", function()
	T.it("skip at any step ends it without the closing hint; a finished one stays", function()
		for i = 1, Tutorial.ACTIONS do
			local s = fresh()
			for k = 1, i - 1 do
				s = Tutorial.advance(s, ORDER[k])
			end
			local skipped = Tutorial.skip(s)
			T.expect({ i, skipped.done, skipped.skipped, skipped.step }).toEqual({ i, true, true, i })
			T.expect(Tutorial.current(skipped)).toBeNil()
			T.expect(Tutorial.finale(skipped)).toBeNil()
		end
		local finished = feed(fresh(), { "move", "quest", "backpack", "potion", "attack", "skill" })
		T.expect(Tutorial.skip(finished)).toBe(finished)
	end)

	T.it("the client may report only move and backpack", function()
		for _, id in ORDER do
			T.expect({ id, Tutorial.clientAllowed(id) }).toEqual({ id, id == "move" or id == "backpack" })
		end
		T.expect(Tutorial.clientAllowed("nope")).toBe(false)
		T.expect(Tutorial.clientAllowed("")).toBe(false)
	end)

	T.it("move needs MOVE_STUDS walked while steering", function()
		local d = TutorialData.MOVE_STUDS
		T.expect(Tutorial.moved(d - 0.01)).toBe(false)
		T.expect(Tutorial.moved(d)).toBe(true)
		local walked = 0
		walked = Tutorial.walk(walked, 3, 4, true) -- 5 studs
		walked = Tutorial.walk(walked, 0, 3, false) -- pushed, not steering
		T.expect(walked).toBe(5)
		walked = Tutorial.walk(walked, TutorialData.MAX_STEP + 1, 0, true) -- the spawn pivot or a teleport
		T.expect(walked).toBe(5)
		walked = Tutorial.walk(walked, 0, -3, true)
		T.expect(Tutorial.moved(walked)).toBe(true)
		T.expect(Tutorial.walk(0, TutorialData.MAX_STEP, 0, true)).toBe(TutorialData.MAX_STEP)
	end)
end)

T.describe("Tutorial: texts", function()
	T.it("every step has a PC and a phone text in both languages; travel texts exist", function()
		for _, s in Tutorial.STEPS do
			for _, touch in { false, true } do
				local key = Tutorial.text(s, touch)
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
			if s.travel then
				local key = Tutorial.text(s, false, true)
				T.expect(key).toBe(`{s.textKey}.travel`)
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
				T.expect(Tutorial.anchorOf(s, true)).toBe(nil)
			else
				T.expect(Tutorial.text(s, true, true)).toBe(`{s.textKey}.touch`)
				T.expect(Tutorial.anchorOf(s, true)).toBe(s.anchor)
			end
		end
		for _, key in
			{
				"tutorial.title",
				"tutorial.caption",
				"tutorial.skip",
				"tutorial.skipConfirm",
				"tutorial.skipYes",
				"tutorial.reward",
				"tutorial.rewardMailed",
				"mail.subject.tutorial",
				"wardrobe.obtain.tutorial",
				"admin.usage.tutorial",
			}
		do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("every placeholder of a PC text is a key of the step, phone texts name no key", function()
		for _, s in Tutorial.STEPS do
			for _, lang in { pl, en } do
				for placeholder in string.gmatch(lang[Tutorial.text(s, false)], "{([%w_]+)}") do
					T.expect({ s.id, placeholder, s.keys[placeholder] ~= nil }).toEqual({ s.id, placeholder, true })
				end
				T.expect({ s.id, string.find(lang[Tutorial.text(s, true)], "{", 1, true) }).toEqual({ s.id, nil })
			end
		end
	end)

	T.it("key labels come from the player's bindings", function()
		local potion = Tutorial.STEPS[Tutorial.indexOf.potion]
		T.expect(Tutorial.keyArgs(potion, nil)).toEqual({ key = "Z" })
		T.expect(Tutorial.keyArgs(potion, { potion_hp = "G" })).toEqual({ key = "G" })
		local skill = Tutorial.STEPS[Tutorial.indexOf.skill]
		T.expect(Tutorial.keyArgs(skill, nil)).toEqual({ key = "1" })
		T.expect(Tutorial.keyArgs(skill, { skill_1 = "F2" })).toEqual({ key = "F2" })
		local quest = Tutorial.STEPS[Tutorial.indexOf.quest]
		T.expect(Tutorial.keyArgs(quest, { interact = "Nope" })).toEqual({ interact = "E" }) -- an invalid binding: default
		T.expect(Tutorial.keyArgs(Tutorial.STEPS[1], nil)).toEqual({})
	end)

	T.it("the admin command knows every step", function()
		local cmd = AdminCommands.get("tutorial")
		T.expect(cmd ~= nil).toBe(true)
		local options = (cmd :: any).args[2].options
		T.expect(options).toEqual(ORDER)
	end)
end)

T.describe("Tutorial: the onboarding funnel", function()
	T.it("steps 1-6 the tutorial, 7-16 the first ten story quests in order, 17 level 5; no gaps", function()
		T.expect(#Tutorial.FUNNEL).toBe(17)
		for i = 1, 6 do
			T.expect(Tutorial.FUNNEL[i]).toEqual({ kind = "tutorial", key = ORDER[i] })
			T.expect(Tutorial.funnelStep("tutorial", ORDER[i])).toBe(i)
		end
		for i = 1, 10 do
			local id = Quests.Main.list[i].id
			T.expect(Tutorial.FUNNEL[6 + i]).toEqual({ kind = "quest", key = id })
			T.expect(Tutorial.funnelStep("quest", id)).toBe(6 + i)
		end
		T.expect(Tutorial.FUNNEL[17]).toEqual({ kind = "level", key = "level5" })
		T.expect(Tutorial.funnelStep("level", Tutorial.LEVEL_KEY)).toBe(17)
		T.expect(Tutorial.LEVEL_KEY).toBe(`level{TutorialData.REWARD_LEVEL}`)
		T.expect(Tutorial.funnelStep("tutorial", "done")).toBeNil()
		T.expect(Tutorial.funnelStep("quest", Quests.Main.list[11].id)).toBeNil()
		T.expect(Tutorial.funnelStep("quest", "move")).toBeNil()
	end)
end)

T.describe("Tutorial: the level reward", function()
	T.it("due from REWARD_LEVEL until taken, skipped or not", function()
		local s = fresh()
		T.expect(TutorialData.REWARD_LEVEL).toBe(5)
		T.expect(Tutorial.rewardDue(s, 4)).toBe(false)
		T.expect(Tutorial.rewardDue(s, 5)).toBe(true)
		T.expect(Tutorial.rewardDue(s, 30)).toBe(true)
		T.expect(Tutorial.rewardDue(Tutorial.skip(s), 5)).toBe(true)
		local taken = table.clone(s)
		taken.reward = true
		T.expect(Tutorial.rewardDue(taken, 5)).toBe(false)
	end)

	T.it("no EXP and no gold: a never-sold title and bound comfort items", function()
		local reward = TutorialData.REWARD :: any
		local fields = {}
		for k in reward do
			table.insert(fields, k)
		end
		table.sort(fields)
		T.expect(fields).toEqual({ "items", "title" })
		for _, entry in reward.items do
			local def = Items.get(entry.id)
			T.expect({ entry.id, def ~= nil }).toEqual({ entry.id, true })
			T.expect({ entry.id, entry.n >= 1 and entry.n <= (def :: any).maxStack }).toEqual({ entry.id, true })
		end
		local ids = {}
		for _, entry in reward.items do
			table.insert(ids, entry.id)
		end
		T.expect(ids).toEqual({ "stone_return", "potion_hp_1" })
		local title = Cosmetics.get(reward.title)
		T.expect(title ~= nil).toBe(true)
		local def = title :: Cosmetics.Def
		T.expect(def.kind).toBe("title")
		T.expect(def.price).toBe(0)
		T.expect(def.obtain).toEqual({ tutorial = true })
		T.expect(def.weekly == true).toBe(false)
		T.expect({ Premium.canBuyCosmetic(def.id, {}, 999999) }).toEqual({ false, "premium.error.notForSale" })
		local entry = Titles.get(def.title :: string)
		T.expect(entry ~= nil).toBe(true)
		T.expect((entry :: any).req).toEqual({ kind = "cosmetic", id = def.id })
		T.expect({ pl["title.firststeps"] ~= nil, en["title.firststeps"] ~= nil }).toEqual({ true, true })
	end)
end)

T.describe("Tutorial: world guide targets (W28)", function()
	local function guide(id: string, away: boolean?, mainTaken: boolean?): any
		return Tutorial.guide(Tutorial.STEPS[Tutorial.indexOf[id]], away, mainTaken)
	end
	T.it("the quest step leads to the captain, or to the quest once one is taken", function()
		T.expect(guide("quest")).toEqual({ kind = "npc", id = Tutorial.CAPTAIN })
		T.expect(guide("quest", false, true)).toEqual({ kind = "quest" })
		T.expect(Npcs.get(Tutorial.CAPTAIN) ~= nil).toBe(true)
	end)
	T.it("the attack step follows the quest from the city and points at a monster on a hunting ground", function()
		T.expect(guide("attack", true)).toEqual({ kind = "quest" })
		T.expect(guide("attack", false)).toEqual({ kind = "monster" })
	end)
	T.it("HUD steps and no step have no world target", function()
		for _, id in { "move", "backpack", "potion", "skill", "done" } do
			T.expect({ id, guide(id, true, true) }).toEqual({ id, nil })
			T.expect({ id, guide(id) }).toEqual({ id, nil })
		end
		T.expect(Tutorial.guide(nil)).toBe(nil)
	end)
	T.it("every text that mentions an arrow belongs to a step with a world guide", function()
		for _, s in Tutorial.STEPS do
			for _, key in { `{s.textKey}.pc`, `{s.textKey}.touch`, `{s.textKey}.travel` } do
				local text = pl[key]
				if text and string.find(string.lower(text), "strzałk") then
					local away = string.sub(key, -7) == ".travel"
					T.expect({ key, Tutorial.guide(s, away) ~= nil }).toEqual({ key, true })
				end
			end
		end
	end)
end)

-- UI plan package A: the element of `anchor` on a w x h layer as UI/HudAnchors measures it, from the zone map
-- (Logic/HudZones on PC and a tablet, Logic/PhoneHud on a phone); nil: none on that device.
local function anchorRect(anchor: string, device: string, w: number, h: number): TutorialTile.Anchor?
	local function of(r: HudStack.Rect): TutorialTile.Anchor
		return { x = r.left, y = r.top, w = r.right - r.left, h = r.bottom - r.top }
	end
	if anchor == "joystick" then
		return if device == "pc" then nil else of(HudZones.thumb(w, h))
	end
	if device == "phone" then
		local places = PhoneHud.places(w, h)
		local name = ({
			questTracker = "stack",
			backpackButton = "menuToggle", -- the drawer is closed: its button (Tutorial.DRAWER)
			potionBar = "potions",
			attackButton = "attack",
			skillBar = "skill1",
		})[anchor]
		return if name then of(PhoneHud.rect(places[name], w, h)) else nil
	end
	local touch = device == "tablet"
	local zones = HudZones.pc(w, h, { touch = touch, target = "monster", column = { 260 } })
	local bar = zones.actionBar
	local b = HudZones.ACTION_BAR
	if anchor == "questTracker" then
		local stack = assert(zones.stack, "the column")
		return of(assert(stack.tracker, "the tracker"))
	elseif anchor == "backpackButton" then
		-- the backpack step's bar: the backpack, the skills and the ☰, right-aligned
		local n = 3
		local left = zones.menuBar.right - n * HudStack.ICON - (n - 1) * HudStack.GAP
		return { x = left, y = zones.menuBar.top, w = HudStack.ICON, h = HudStack.ICON }
	elseif anchor == "potionBar" then
		local left = bar.left + b.slots * b.slot + (b.slots - 1) * b.gap + 2 * b.gap + HudStack.MARGIN
		return { x = left, y = bar.top, w = b.slot * b.potions + 12, h = b.slot }
	elseif anchor == "attackButton" then
		return if touch then of(zones.corner.attack) else nil
	elseif anchor == "skillBar" then
		return if touch then of(zones.corner.skill1) else { x = bar.left, y = bar.top, w = b.slot, h = b.slot }
	end
	return nil
end

-- The menu over the minimap as UI/HudSlots.Menu measures it (PC and a tablet).
local function menuRect(w: number, h: number, touch: boolean): HudStack.Rect
	local zones = HudZones.pc(w, h, { touch = touch })
	return {
		left = math.min(zones.menuBar.left, zones.minimap.left),
		top = zones.menuBar.top,
		right = zones.menuBar.right,
		bottom = zones.minimap.bottom,
	}
end

local function meets(a: HudStack.Rect, b: HudStack.Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- Every HUD layer of the plan: PC and tablets from Logic/UiScale (top bar 0, 36, 58), the phones of PhoneHud.DEVICES.
local function layers(): { { name: string, device: string, w: number, h: number } }
	local out = {}
	for _, set in
		{
			{ device = "pc", touch = false, sizes = { { 1920, 1080 }, { 1366, 768 }, { 1280, 720 }, { 1024, 600 } } },
			{ device = "tablet", touch = true, sizes = { { 1280, 720 }, { 1024, 768 }, { 1366, 1024 } } },
		}
	do
		for _, size in set.sizes do
			for _, bar in { 0, 36, 58 } do
				local w, h = HudZones.layer(size[1], size[2], set.touch, bar)
				table.insert(
					out,
					{ name = `{set.device} {size[1]}x{size[2]} bar {bar}`, device = set.device, w = w, h = h }
				)
			end
		end
	end
	for _, phone in PhoneHud.DEVICES do
		for _, bar in { 0, 36, 58 } do
			local w, h = PhoneHud.area(phone, bar)
			table.insert(out, { name = `phone {phone.name} bar {bar}`, device = "phone", w = w, h = h })
		end
	end
	return out
end

T.describe("Tutorial: pointers (UI plan package A)", function()
	T.it("the anchors' names are frozen and Screens/Hud builds every one of them", function()
		T.expect(Tutorial.ANCHOR_NAMES).toEqual({
			questTracker = { pc = "QuestTracker", touch = "QuestTracker" },
			backpackButton = { pc = "inventory", touch = "inventory", drawer = true },
			potionBar = { pc = "PotionBar", touch = "PotionBar" },
			attackButton = { touch = "AttackButton" },
			skillBar = { pc = "Skill1", touch = "MobileSkill1" },
		})
		T.expect(Tutorial.DRAWER).toBe("MenuToggle")
		local hud = ""
		for _, file in fs.readDir("src/client/UI/Screens/Hud") do
			if string.sub(file, -5) == ".luau" then
				hud ..= fs.readFile(`src/client/UI/Screens/Hud/{file}`)
			end
		end
		local function built(name: string): boolean
			if string.find(hud, `Name = "{name}"`, 1, true) then
				return true
			end
			-- a numbered element from its template (Skill{index}, MobileSkill{i}); a menu button from the bar's ids
			local prefix = string.match(name, "^(%a+)%d+$")
			if prefix and string.find(hud, `Name = \`{prefix}\{`, 1, true) then
				return true
			end
			return HudMenu.onBar(name) and string.find(hud, "Name = entry.id", 1, true) ~= nil
		end
		for _, s in Tutorial.STEPS do
			local anchor = s.anchor
			if anchor and anchor ~= "joystick" then
				local names = Tutorial.ANCHOR_NAMES[anchor]
				T.expect({ s.id, names ~= nil }).toEqual({ s.id, true })
				for _, name in { names.pc, names.touch, if names.drawer then Tutorial.DRAWER else nil } do
					T.expect({ s.id, name, built(name) }).toEqual({ s.id, name, true })
				end
			end
		end
		-- UI/HudAnchors reads them and points the move step at the thumb zone of the zone map
		local anchors = fs.readFile("src/client/UI/HudAnchors.luau")
		T.expect(string.find(anchors, "HudAnchors.NAMES = Tutorial.ANCHOR_NAMES", 1, true) ~= nil).toBe(true)
		T.expect(string.find(anchors, "HudZones.thumb(size.X, size.Y)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(anchors, "FindFirstChild(Tutorial.DRAWER, true)", 1, true) ~= nil).toBe(true)
	end)

	T.it("the tile stays inside the layer, off its element, the message zone and the skill arc", function()
		for _, layer in layers() do
			local touch = layer.device ~= "pc"
			local compact = layer.device == "phone"
			local avoid = TutorialTile.avoid(layer.w, layer.h, touch, compact)
			local menu = if compact then nil else menuRect(layer.w, layer.h, touch)
			local width = TutorialTile.width(touch, compact)
			-- a short hint and the longest (80 characters in three or four lines, the skip button under them)
			for _, tall in { 120, if touch then 210 else 180 } do
				local tile = { w = width, h = tall, tall = tall }
				local cases: { { name: string, anchor: TutorialTile.Anchor? } } = { { name = "default" } }
				for _, s in Tutorial.STEPS do
					local anchor = s.anchor
					if anchor then
						local rect = anchorRect(anchor, layer.device, layer.w, layer.h)
						if rect then
							table.insert(cases, { name = s.id, anchor = rect })
						end
					end
				end
				for _, case in cases do
					local where = `{layer.name}, {case.name}, {tall} tall`
					local x, y, arrow =
						TutorialTile.place(case.anchor, tile, { w = layer.w, h = layer.h }, touch, menu, avoid)
					local box = { left = x, top = y, right = x + width, bottom = y + tall }
					local inside = x >= 0 and y >= 0 and box.right <= layer.w + 1e-6 and box.bottom <= layer.h + 1e-6
					T.expect({ where, "inside", inside }).toEqual({ where, "inside", true })
					for _, r in avoid do
						T.expect({ where, "clear", meets(box, r) }).toEqual({ where, "clear", false })
					end
					local a = case.anchor
					if a then
						local own = { left = a.x, top = a.y, right = a.x + a.w, bottom = a.y + a.h }
						T.expect({ where, "off its element", meets(box, own) })
							.toEqual({ where, "off its element", false })
						-- the arrow points at the element: its centre lies along the element's side
						if arrow then
							local along = (arrow.x >= a.x - 1 and arrow.x <= a.x + a.w + 1)
								or (arrow.y >= a.y - 1 and arrow.y <= a.y + a.h + 1)
							T.expect({ where, "arrow", along }).toEqual({ where, "arrow", true })
						end
					end
				end
			end
		end
		-- the controller only measures and draws: the place is TutorialTile's
		local controller = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(controller, "TutorialTile.place(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(controller, "TutorialTile.avoid(size.X, size.Y, touch, compact)", 1, true) ~= nil)
			.toBe(true)
		T.expect(string.find(controller, "local function place(", 1, true)).toBeNil()
	end)

	T.it("each device reads its own text, within the tile's cap", function()
		local cap = TextCaps.SURFACES.tutorialTile.chars
		local known = fixtureA.known
		local function has(key: string): boolean
			return pl[key] ~= nil and en[key] ~= nil
		end
		for _, s in Tutorial.STEPS do
			for _, touch in { false, true } do
				for _, phone in { false, true } do
					local key = Tutorial.text(s, touch, false, phone, has)
					T.expect({ key, has(key) }).toEqual({ key, true })
					-- a PC never reads the phone's text; a phone reads it where it exists, else the touch one
					if not touch then
						T.expect(key).toBe(`{s.textKey}.pc`)
					elseif phone and has(`{s.textKey}.phone`) then
						T.expect(key).toBe(`{s.textKey}.phone`)
					else
						T.expect(key).toBe(`{s.textKey}.touch`)
					end
					-- package A's text part shortens the ones its fixture still lists
					if not known[key] then
						for _, lang in { pl, en } do
							local n = TextCaps.chars(TextCaps.expand(lang[key]))
							T.expect({ key, n <= cap }).toEqual({ key, true })
						end
					end
				end
			end
		end
		-- the backpack sits in the phone's drawer behind "Menu"; its phone text names no key, like a touch text
		T.expect(Tutorial.text(Tutorial.STEPS[Tutorial.indexOf.backpack], true, false, true, has))
			.toBe("tutorial.backpack.phone")
		for _, lang in { pl, en } do
			T.expect(string.find(lang["tutorial.backpack.phone"], "{", 1, true)).toBeNil()
		end
		-- the controller asks for it on a phone in landscape
		local controller = fs.readFile("src/client/Controllers/TutorialController.luau")
		T.expect(string.find(controller, "Tutorial.text(step, touch, away, compact, hasText)", 1, true) ~= nil)
			.toBe(true)
	end)
end)
