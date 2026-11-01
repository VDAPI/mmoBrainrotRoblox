--!strict
-- UI plan phase 4 (`wyglad/UI-PLAN.md` §5 "Nowy gracz"): the HUD grows with the tutorial and the level
-- (Logic/HudReveal). A new character sees the ☰ and the story quests; the Character hub comes with the tutorial's
-- "backpack" step, the other hubs and the tracker's other groups at its end (or skip), the Rivalry hub with the arena's
-- level (Logic/Unlocks). Characters without a tutorial save see everything, a hidden hub's "!" lights the ☰ and every
-- key still opens its window.
local fs = require("@lune/fs")

local T = require("./Test")
local Arena = require("../src/shared/Data/Arena")
local HudMenu = require("../src/shared/Logic/HudMenu")
local HudReveal = require("../src/shared/Logic/HudReveal")
local Tutorial = require("../src/shared/Logic/Tutorial")
local UiHubs = require("../src/shared/Data/UiHubs")
local Unlocks = require("../src/shared/Logic/Unlocks")
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

local function hubs(stage: HudReveal.Stage, level: number): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, hub in UiHubs.HUBS do
		out[hub.id] = HudReveal.hub(hub.id, stage, level)
	end
	return out
end

describe("HudReveal: the tutorial's stage", function()
	it("starts small, the Character hub at the backpack step, everything at the end", function()
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

describe("HudReveal: the hubs and the tracker", function()
	it("a new character has no hub button, the backpack step shows Character only", function()
		local start = hubs("start", 1)
		for id, shown in start do
			expect({ id, shown }).toEqual({ id, false })
		end
		local backpack = hubs("backpack", 1)
		for id, shown in backpack do
			expect({ id, shown }).toEqual({ id, id == "character" })
		end
	end)

	it("the end of the tutorial shows every hub but Rivalry, which comes with the arena", function()
		local below = hubs("full", Arena.MIN_LEVEL - 1)
		for id, shown in below do
			expect({ id, shown }).toEqual({ id, id ~= "rivalry" })
		end
		expect(HudReveal.hub("rivalry", "full", Arena.MIN_LEVEL)).toBe(true)
		-- the level is Logic/Unlocks' (one source), not the hub's own
		expect(Unlocks.hubLevel("rivalry")).toBe(Arena.MIN_LEVEL)
		expect(Unlocks.hubLevel("world")).toBeNil()
		-- a high level never shows a hub before the tutorial's end
		expect(HudReveal.hub("rivalry", "backpack", 100)).toBe(false)
	end)

	it("only the story quests in the tracker during the tutorial", function()
		for _, id in { "contracts", "daily", "weekly", "ach", "e2" } do
			expect({ id, HudReveal.trackerGroup(id, "backpack") }).toEqual({ id, false })
			expect({ id, HudReveal.trackerGroup(id, "full") }).toEqual({ id, true })
		end
		expect(HudReveal.trackerGroup("quests", "start")).toBe(true)
	end)

	it("a tile of a hidden hub lights the ☰, a shown hub keeps its own", function()
		local function shown(hubId: string): boolean
			return hubId ~= "shop"
		end
		-- the season pass is the Shop hub's tab and a tile
		expect(HudMenu.attention({ season = true })).toBe(false)
		expect(HudMenu.attention({ season = true }, shown)).toBe(true)
		expect(HudMenu.attention({ arena = true }, shown)).toBe(false)
	end)

	it("the ☰ stays from the start and the HUD wires the reveal", function()
		-- the ☰ holds the settings and the language: it is no hub and never waits
		expect(UiHubs.byButton("menu")).toBeNil()
		local screen = fs.readFile("src/client/Controllers/ScreenController.luau")
		expect(string.find(screen, "HudReveal.hub(hubId, HudReveal.stage(", 1, true) ~= nil).toBe(true)
		expect(string.find(screen, "WindowManager.SetTabBadge(tab, badge)", 1, true) ~= nil).toBe(true)
		local tracker = fs.readFile("src/client/UI/Screens/Hud/QuestTracker.luau")
		expect(string.find(tracker, "HudReveal.trackerGroup(id, stage)", 1, true) ~= nil).toBe(true)
		-- the arena's unlock toast names the new button in both languages
		expect(string.find(pl["unlock.arena"], "Rywalizacja", 1, true) ~= nil).toBe(true)
		expect(string.find(en["unlock.arena"], "Rivalry", 1, true) ~= nil).toBe(true)
	end)
end)

return nil
