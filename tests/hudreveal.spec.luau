--!strict
-- UI plan phase 4 (`wyglad/UI-PLAN.md` §5 "Nowy gracz"): the HUD grows with the tutorial (Logic/HudReveal). A new
-- character sees the ☰ and the story quests; owner 2026-11-10 (the window hubs are gone): the backpack and the skills
-- come with the tutorial's "backpack" step, the world map, the quests, the Dragon Shop and the tracker's other groups
-- at its end (or skip). Characters without a tutorial save see everything, the ☰ never waits and every key still opens
-- its window.
local fs = require("@lune/fs")

local T = require("./Test")
local HudMenu = require("../src/shared/Logic/HudMenu")
local HudReveal = require("../src/shared/Logic/HudReveal")
local Tutorial = require("../src/shared/Logic/Tutorial")
local en = require("../src/shared/Data/Localization/en") :: any
local pl = require("../src/shared/Data/Localization/pl") :: any

local describe, it, expect = T.describe, T.it, T.expect

local function at(step: string, extra: { [string]: any }?): { [string]: any }
	local state: { [string]: any } = Tutorial.newState() :: any
	state.step = Tutorial.indexOf[step]
	for k, v in extra or {} do
		state[k] = v
	end
	return state
end

local function bar(stage: HudReveal.Stage): { string }
	local out: { string } = {}
	for _, id in HudMenu.BAR do
		if HudReveal.button(id, stage) then
			table.insert(out, id)
		end
	end
	return out
end

describe("HudReveal: the tutorial's stage", function()
	it("starts small, the backpack step in the middle, everything at the end", function()
		expect(HudReveal.stage(at("move"))).toBe("start")
		expect(HudReveal.stage(at("quest"))).toBe("start")
		expect(HudReveal.stage(at("backpack"))).toBe("backpack")
		expect(HudReveal.stage(at("skill"))).toBe("backpack")
		expect(HudReveal.stage(at("done", { done = true }))).toBe("full")
	end)

	it("a backpack opened ahead counts, a skip and an old character see everything", function()
		expect(HudReveal.stage(at("quest", { pending = { backpack = true } }))).toBe("backpack")
		expect(HudReveal.stage(at("move", { done = true, skipped = true }))).toBe("full")
		expect(HudReveal.stage(nil)).toBe("full")
		expect(HudReveal.stage("broken")).toBe("full")
	end)
end)

describe("HudReveal: the bar's buttons and the tracker", function()
	it("a new character has the ☰ only, the backpack step adds the backpack and the skills", function()
		expect(bar("start")).toEqual({ "menu" })
		expect(bar("backpack")).toEqual({ "inventory", "skills", "menu" })
		expect(bar("full")).toEqual(HudMenu.BAR)
		-- every stage named is a button of the bar
		for id in HudReveal.BUTTON_STAGE do
			expect({ id, HudMenu.onBar(id) }).toEqual({ id, true })
		end
		-- the tutorial's "backpack" step points at a button that is there by then
		expect(HudReveal.button("inventory", HudReveal.stage(at("backpack")))).toBe(true)
	end)

	it("only the story quests in the tracker during the tutorial", function()
		for _, id in { "contracts", "daily", "weekly", "ach", "e2" } do
			expect({ id, HudReveal.trackerGroup(id, "backpack") }).toEqual({ id, false })
			expect({ id, HudReveal.trackerGroup(id, "full") }).toEqual({ id, true })
		end
		expect(HudReveal.trackerGroup("quests", "start")).toBe(true)
	end)

	it("the HUD wires the reveal per button, the ☰ never waits", function()
		local screen = fs.readFile("src/client/Controllers/ScreenController.luau")
		expect(string.find(screen, "HudReveal.button(id, HudReveal.stage(", 1, true) ~= nil).toBe(true)
		local menuStart = assert(string.find(screen, "local MENU: { Hud.MenuEntry } = {", 1, true))
		local menuEnd = assert(string.find(screen, "\n}", menuStart, true))
		local menu = string.sub(screen, menuStart, menuEnd)
		for _, id in HudMenu.BAR do
			if id ~= "menu" then
				expect({ id, string.find(menu, 'revealed%a*%("' .. id .. '"%)') ~= nil }).toEqual({ id, true })
			end
		end
		local hamburger = assert(string.match(menu, '{ id = "menu",[^\n]*'))
		expect(string.find(hamburger, "visible", 1, true)).toBeNil()
		local tracker = fs.readFile("src/client/UI/Screens/Hud/QuestTracker.luau")
		expect(string.find(tracker, "HudReveal.trackerGroup(id, stage)", 1, true) ~= nil).toBe(true)
	end)

	it("the unlock toasts of tiles name the ☰ in both languages", function()
		for _, key in { "unlock.mounts", "unlock.arena" } do
			expect(string.find(pl[key], "☰", 1, true) ~= nil).toBe(true)
			expect(string.find(en[key], "☰", 1, true) ~= nil).toBe(true)
		end
	end)
end)

return nil
