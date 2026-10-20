--!strict
-- S151c (docs/DESIGN.md §20c): the bestiary: the entries of every monster kind and boss, the tiers and what they reveal,
-- the drops seen, the points inside the achievement summary, the family bonus and its cap, the complete regions (the
-- achievement bestiary_<region> with its title, also from the catch-up of old progress) and the save without migration.
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local AchData = require("../src/shared/Data/Achievements")
local AchievementView = require("../src/shared/Logic/AchievementView")
local Achievements = require("../src/shared/Logic/Achievements")
local Bestiary = require("../src/shared/Logic/Bestiary")
local BestiaryData = require("../src/shared/Data/Bestiary")
local Bosses = require("../src/shared/Data/Bosses")
local Items = require("../src/shared/Data/Items")
local Monsters = require("../src/shared/Data/Monsters")
local T = require("./Test")
local TitleData = require("../src/shared/Data/Titles")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function fresh(): (any, any, Achievements.State)
	local account: any = AccountSchema.accountTemplate()
	local character: any = AccountSchema.characterTemplate()
	character.id = "c1"
	account.characters["1"] = character
	return account, character, Achievements.state(account, character)
end

-- Every entry of `region` at its last tier.
local function master(branch: any, region: string)
	for _, entry in BestiaryData.forRegion(region) do
		Bestiary.addKill(branch, entry.id, entry.tiers[#entry.tiers])
	end
end

T.describe("Bestiary data (S151c)", function()
	T.it("every monster kind and every boss is one entry of a known region with tiers, points and drops", function()
		T.expect(#BestiaryData.list).toBe(#Monsters.list + #Bosses.all)
		for _, def in Monsters.list do
			local entry = BestiaryData.get(def.id) :: any
			T.expect({ def.id, entry ~= nil and not entry.boss }).toEqual({ def.id, true })
			T.expect({ def.id, entry.region }).toEqual({ def.id, BestiaryData.REGIONS[def.region] })
		end
		for _, def in Bosses.all do
			local entry = BestiaryData.get(def.id) :: any
			T.expect({ def.id, entry ~= nil and entry.boss }).toEqual({ def.id, true })
			T.expect({ def.id, entry.tiers }).toEqual({ def.id, { 1, 10, 50 } })
		end
		for _, entry in BestiaryData.list do
			T.expect({ entry.id, table.find(BestiaryData.REGIONS, entry.region) ~= nil }).toEqual({ entry.id, true })
			T.expect({ entry.id, #entry.tiers, #entry.points }).toEqual({ entry.id, 3, 3 })
			for i = 2, #entry.tiers do
				T.expect({ entry.id, entry.tiers[i] > entry.tiers[i - 1] }).toEqual({ entry.id, true })
			end
			T.expect({ entry.id, #entry.drops > 0 }).toEqual({ entry.id, true })
			for _, itemId in entry.drops do
				T.expect({ entry.id, itemId, Items.get(itemId) ~= nil }).toEqual({ entry.id, itemId, true })
			end
			T.expect({ entry.nameKey, pl[entry.nameKey] ~= nil, en[entry.nameKey] ~= nil })
				.toEqual({ entry.nameKey, true, true })
		end
		T.expect(BestiaryData.get("wolf") and (BestiaryData.get("wolf") :: any).tiers).toEqual({ 10, 100, 1000 })
	end)

	T.it("every region has entries and a title achievement of its own", function()
		for _, region in BestiaryData.REGIONS do
			T.expect({ region, #BestiaryData.forRegion(region) > 0 }).toEqual({ region, true })
			local def = AchData.get(`bestiary_{region}`) :: any
			T.expect({ region, def ~= nil and def.counter == "bestiaryRegions" and def.key == region })
				.toEqual({ region, true })
			local title = TitleData.get(def.reward.title) :: any
			T.expect({ region, title ~= nil and title.req.kind == "achievement" and title.req.id == def.id })
				.toEqual({ region, true })
		end
	end)

	T.it("the texts of the tab exist in both languages", function()
		for _, key in
			{
				"best.tab",
				"best.toast.reveal1",
				"best.toast.reveal2",
				"best.toast.reveal3",
				"best.reveal1",
				"best.reveal2",
				"best.reveal3",
				"best.attack.melee",
				"best.attack.ranged",
				"best.damage.phys",
				"best.damage.magic",
				"hud.achButton",
			}
		do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
		for _, entry in BestiaryData.list do
			for _, line in Bestiary.weaknesses(entry) do
				T.expect({ line.key, pl[line.key] ~= nil, en[line.key] ~= nil }).toEqual({ line.key, true, true })
			end
		end
	end)
end)

T.describe("Bestiary rules (S151c)", function()
	T.it("kills cross the tiers one by one and an unknown id or a bad count changes nothing", function()
		local _, character = fresh()
		local branch = character.ach
		T.expect(Bestiary.addKill(branch, "nobody", 1)).toBeNil()
		T.expect(Bestiary.addKill(branch, "wolf", -3)).toBeNil()
		local kill = Bestiary.addKill(branch, "wolf", 9) :: any
		T.expect({ kill.kills, kill.from, kill.to }).toEqual({ 9, 0, 0 })
		kill = Bestiary.addKill(branch, "wolf") :: any
		T.expect({ kill.kills, kill.from, kill.to }).toEqual({ 10, 0, 1 })
		kill = Bestiary.addKill(branch, "wolf", 990) :: any
		T.expect({ kill.from, kill.to }).toEqual({ 1, 3 })
		T.expect(Bestiary.tier(branch, "wolf")).toBe(3)
		-- a boss: the first win is tier I
		kill = Bestiary.addKill(branch, "grimrok") :: any
		T.expect(kill.to).toBe(1)
	end)

	T.it("the view reveals more with every tier", function()
		local _, character = fresh()
		local branch = character.ach
		local view = Bestiary.view(branch, "wolf") :: any
		T.expect({ view.known, view.nameKey, view.family, view.levels, view.drops, view.weak })
			.toEqual({ false, nil, nil, nil, nil, nil })
		Bestiary.addKill(branch, "wolf", 1)
		view = Bestiary.view(branch, "wolf") :: any
		T.expect({ view.known, view.nameKey, view.family, view.levels })
			.toEqual({ true, "monster.wolf.normal", "animal", nil })
		Bestiary.addKill(branch, "wolf", 9)
		view = Bestiary.view(branch, "wolf") :: any
		T.expect({ view.levels ~= nil, view.attack ~= nil, view.drops }).toEqual({ true, true, nil })
		Bestiary.addKill(branch, "wolf", 90)
		view = Bestiary.view(branch, "wolf") :: any
		T.expect({ view.drops ~= nil, view.weak }).toEqual({ true, nil })
		Bestiary.addKill(branch, "wolf", 900)
		view = Bestiary.view(branch, "wolf") :: any
		T.expect({ view.weak ~= nil, view.mastered, view.pct }).toEqual({ true, true, 1 })
	end)

	T.it("only the entry's own drops count as seen, once", function()
		local _, character = fresh()
		local branch = character.ach
		local own = (BestiaryData.get("wolf") :: any).drops[1]
		T.expect(Bestiary.addDrops(branch, "wolf", { own, "sword1h_1", own, 5 })).toEqual({ own })
		T.expect(Bestiary.addDrops(branch, "wolf", { own })).toEqual({})
		Bestiary.addKill(branch, "wolf", 100)
		local view = Bestiary.view(branch, "wolf") :: any
		T.expect(view.drops[1]).toEqual({ id = own, seen = true })
		for i = 2, #view.drops do
			T.expect(view.drops[i].seen).toBe(false)
		end
		T.expect(Bestiary.addDrops(branch, "nobody", { own })).toEqual({})
	end)

	T.it("weaknesses follow the numbers: armour, magic resistance, dodge and the element of the blows", function()
		local function keys(id: string): { [string]: boolean }
			local out: { [string]: boolean } = {}
			for _, line in Bestiary.weaknesses(BestiaryData.get(id) :: any) do
				out[line.key] = true
			end
			return out
		end
		-- armored (defMul only) -> magic; warded (mresMul only) -> weapons; agile -> skills
		local armored, warded, agile
		for _, def in Monsters.list do
			if def.defence == "armored" then
				armored = def.id
			elseif def.defence == "warded" then
				warded = def.id
			elseif def.defence == "agile" then
				agile = def.id
			end
		end
		T.expect(keys(armored)["best.weak.magic"]).toBe(true)
		T.expect(keys(warded)["best.weak.phys"]).toBe(true)
		T.expect(keys(agile)["best.weak.skills"]).toBe(true)
		T.expect(keys("rabbit")["best.weak.none"]).toBe(true)
	end)

	T.it("the family bonus: +FAMILY_PCT per mastered entry, never above FAMILY_CAP", function()
		local _, character = fresh()
		local branch = character.ach
		T.expect(Bestiary.familyBonus(branch)).toEqual({})
		Bestiary.addKill(branch, "wolf", 999)
		T.expect(Bestiary.familyBonus(branch)).toEqual({})
		Bestiary.addKill(branch, "wolf", 1)
		T.expect(Bestiary.familyBonus(branch)).toEqual({ animal = BestiaryData.FAMILY_PCT })
		for _, entry in BestiaryData.list do
			if entry.family == "animal" then
				Bestiary.addKill(branch, entry.id, 1000)
			end
		end
		T.expect(Bestiary.familyBonus(branch)).toEqual({ animal = BestiaryData.FAMILY_CAP })
	end)

	T.it("points: each reached tier; inside the character's achievement summary, not the account's", function()
		local _, character, st = fresh()
		Bestiary.addKill(st.chr, "wolf", 100)
		local wolf = BestiaryData.get("wolf") :: any
		T.expect(Bestiary.points(st.chr)).toBe(wolf.points[1] + wolf.points[2])
		T.expect(AchievementView.summary(st, "character").bestiary.points).toBe(wolf.points[1] + wolf.points[2])
		T.expect(AchievementView.summary(st, "account").bestiary.points).toBe(0)
		T.expect(AchievementView.summary(st, "all").points).toBe(wolf.points[1] + wolf.points[2])
		-- the client's read-only state sees the same
		local view = AchievementView.read(nil, character)
		T.expect(Bestiary.points(view.chr)).toBe(wolf.points[1] + wolf.points[2])
	end)

	T.it("regions: progress in tiers, complete with every entry mastered", function()
		local _, _, st = fresh()
		local done, max = Bestiary.regionProgress(st.chr, "meadows")
		T.expect(done).toBe(0)
		T.expect(max).toBe(#BestiaryData.forRegion("meadows") * 3)
		master(st.chr, "meadows")
		T.expect(Bestiary.regionComplete(st.chr, "meadows")).toBe(true)
		T.expect(Bestiary.completeRegions(st.chr)).toEqual({ "meadows" })
		local rows = Bestiary.regions(st.chr)
		T.expect({ rows[1].complete, rows[1].pct, rows[2].complete }).toEqual({ true, 1, false })
	end)

	T.it("a complete region grants its achievement (event and catch-up), the title follows", function()
		local account, character, st = fresh()
		local entries = Achievements.entriesFor("bestiary", { region = "meadows" })
		T.expect(#entries).toBe(1)
		Achievements.applyAll(st, entries)
		T.expect(table.find(Achievements.allPending(st), "bestiary_meadows") ~= nil).toBe(true)
		-- the catch-up proves it from the save
		local account2, character2, st2 = fresh()
		master(st2.chr, "duskwood")
		local pending = Achievements.applyAll(st2, Achievements.backfill(account2, character2))
		T.expect(table.find(pending, "bestiary_duskwood") ~= nil).toBe(true)
		T.expect(table.find(pending, "bestiary_meadows")).toBeNil()
		local _ = account
		local _ = character
	end)

	T.it("the drop event feeds no counter; garbage branches are repaired", function()
		T.expect(Achievements.entriesFor("drop", { monsterId = "wolf", ids = { "wolf_pelt" } })).toEqual({})
		T.expect(Achievements.entriesFor("bestiary", { region = "" })).toEqual({})
		local account: any = AccountSchema.accountTemplate()
		local character: any = AccountSchema.characterTemplate()
		character.ach = { b = { wolf = -4, boar = "x" }, bd = { wolf = 3 } }
		local st = Achievements.state(account, character)
		T.expect(st.chr.b).toEqual({ wolf = 0, boar = 0 })
		T.expect(st.chr.bd).toEqual({ wolf = {} })
	end)

	T.it("the save template has the bestiary tables (no migration)", function()
		local character: any = AccountSchema.characterTemplate()
		T.expect(character.ach.b).toEqual({})
		T.expect(character.ach.bd).toEqual({})
	end)
end)
