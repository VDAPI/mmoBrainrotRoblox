--!strict
-- UI plan phase 3 (`wyglad/UI-PLAN.md` §5): the hubs of windows (Data/UiHubs). Five hubs on the HUD bar next to the ☰;
-- a hub's windows show each other as tabs in the title bar; every tab is a registered window with a short name in both
-- languages; the backpack window is the "inventory" tab and the hub button opens the first shown tab.
local fs = require("@lune/fs")

local T = require("./Test")
local HudMenu = require("../src/shared/Logic/HudMenu")
local UiHubs = require("../src/shared/Data/UiHubs")
local WindowRules = require("../src/shared/Logic/WindowRules")
local en = require("../src/shared/Data/Localization/en") :: any
local pl = require("../src/shared/Data/Localization/pl") :: any

-- The window ids the client registers (WindowManager.Register({ id = ... })).
local function registered(): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local function walk(dir: string)
		for _, name in fs.readDir(dir) do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				walk(path)
			elseif string.sub(name, -5) == ".luau" then
				local src = fs.readFile(path)
				for id in string.gmatch(src, 'WindowManager%.Register%(%{%s*id = "([%w_]+)"') do
					out[id] = true
				end
			end
		end
	end
	walk("src/client")
	return out
end

T.describe("Window hubs (UI plan phase 3)", function()
	T.it("five hubs, their buttons on the HUD bar in its order before the menu", function()
		T.expect(#UiHubs.HUBS).toBe(5)
		local buttons = {}
		for _, hub in UiHubs.HUBS do
			table.insert(buttons, hub.button)
			T.expect(#hub.tabs >= 3).toBe(true)
		end
		table.insert(buttons, "menu")
		T.expect(buttons).toEqual(HudMenu.BAR)
		-- the tutorial's anchor stays the Character hub's button
		T.expect((UiHubs.get("character") :: UiHubs.Hub).button).toBe("inventory")
	end)

	T.it("every tab is a registered window, in one hub only, with a short name in both languages", function()
		local ids = registered()
		local seen: { [string]: boolean } = {}
		for _, hub in UiHubs.HUBS do
			for _, tab in hub.tabs do
				T.expect(ids[tab] == true).toBe(true)
				T.expect(seen[tab] == nil).toBe(true)
				seen[tab] = true
				local key = UiHubs.tabLabel(tab)
				for lang, strings in { pl = pl, en = en } do
					local text = strings[key]
					if type(text) ~= "string" or #text == 0 or #text > 24 or string.find(text, "—", 1, true) then
						error(`{lang} {key}: missing, long or with an em-dash`)
					end
				end
			end
			for lang, strings in { pl = pl, en = en } do
				if type(strings[hub.labelKey]) ~= "string" then
					error(`{lang} {hub.labelKey} missing`)
				end
			end
		end
		T.expect(ids.settings).toBe(true) -- the settings in their own window
	end)

	T.it("the backpack window is the backpack's tab; NPC services stay outside the hubs", function()
		T.expect(UiHubs.tabOf(WindowRules.MAIN)).toBe(WindowRules.INVENTORY)
		T.expect((UiHubs.hubOf("character") :: UiHubs.Hub).id).toBe("character")
		for _, id in { "shop", "blacksmith", "deposit", "auction", "alchemy", "trade", "npc", "menu", "settings" } do
			T.expect(UiHubs.hubOf(id)).toBe(nil)
		end
	end)

	T.it("a hub opens on its first shown tab, nothing when none shows", function()
		local world = UiHubs.get("world") :: UiHubs.Hub
		T.expect(UiHubs.entry(world, function()
			return true
		end)).toBe("map")
		-- an arena server: no map, no journal
		T.expect(UiHubs.entry(world, function(tab)
			return tab == "achievements"
		end)).toBe("achievements")
		T.expect(UiHubs.entry(world, function()
			return false
		end)).toBe(nil)
		T.expect(UiHubs.visibleTabs(world, function(tab)
			return tab ~= "quests"
		end)).toEqual({ "map", "achievements" })
	end)

	T.it("the window and the bar use the hubs", function()
		local manager = fs.readFile("src/client/Controllers/WindowManager.luau")
		T.expect(string.find(manager, "UiHubs.hubOf(id)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(manager, "function WindowManager.ToggleHub", 1, true) ~= nil).toBe(true)
		local window = fs.readFile("src/client/UI/Components/Window.luau")
		T.expect(string.find(window, '"HubTabs"', 1, true) ~= nil).toBe(true)
	end)
end)

return nil
