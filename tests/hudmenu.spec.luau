--!strict
-- UI plan phase 1 (owner 2026-10-31, "too much information and too many options on one screen"): Logic/HudMenu, the six
-- buttons of the HUD bar and the tiles at the top of the game menu. Nothing becomes unreachable: every window key of
-- Data/Keybinds belongs to a button or a tile and keeps its key, everything the HUD menu, the old game menu rows and
-- the buttons by the portrait opened has a place, the tutorial's backpack button stays on the bar, a tile's "!" lights
-- the ☰ and every tile's name fits the tile in both languages.
-- Owner 2026-11-10 ("you merged things so the backpack also holds skills; separate them like before"): the window hubs
-- of UI plan phase 3 are gone, so these six are the bar again and every button opens its own window.

local fs = require("@lune/fs")

local HudMenu = require("../src/shared/Logic/HudMenu")
local KeybindData = require("../src/shared/Data/Keybinds")
local T = require("./Test")
local Tutorial = require("../src/shared/Logic/Tutorial")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = T.describe, T.it, T.expect

-- tests/uifit's generous width estimate (Builder Sans): a letter or digit LETTER of the text size, a space SPACE, a
-- symbol beyond Latin a full em.
local LETTER = 0.56
local SPACE = 0.3
local SYMBOL = 1.0
local function width(text: string, size: number): number
	local em = 0
	for _, code in utf8.codes(text) do
		em += if code == 32 then SPACE elseif code >= 0x2000 then SYMBOL else LETTER
	end
	return em * size
end

-- Theme.TextSize.Small (the tile's name).
local function smallText(): number
	local source = fs.readFile("src/client/UI/Theme.luau")
	local start = assert(string.find(source, "Theme.TextSize = {", 1, true))
	local value = string.match(source, "Small = (%d+)", start)
	return tonumber(value) :: number
end

describe("HUD bar and game menu tiles (UI plan phase 1)", function()
	it("the bar holds six buttons: the backpack first, the menu last", function()
		expect(HudMenu.BAR).toEqual({ "inventory", "skills", "map", "quests", "premium", "menu" })
		-- S155: the tutorial's "backpack" step points at the bar's backpack button (UI/HudAnchors; UI plan package A:
		-- the names live in Logic/Tutorial.ANCHOR_NAMES, and in the phone's closed drawer it points at the drawer's button)
		local backpack = Tutorial.ANCHOR_NAMES.backpackButton
		expect({ backpack.pc, backpack.touch, backpack.drawer }).toEqual({ "inventory", "inventory", true })
		local anchors = fs.readFile("src/client/UI/HudAnchors.luau")
		expect(string.find(anchors, "HudAnchors.NAMES = Tutorial.ANCHOR_NAMES", 1, true) ~= nil).toBe(true)
		expect(HudMenu.onBar("inventory")).toBe(true)
	end)

	it("UI plan package A: the bar keeps 6 buttons, the ☰ 15 tiles, the phone's drawer the bar's six", function()
		expect(#HudMenu.BAR).toBe(6)
		expect(#HudMenu.TILES).toBe(15)
		-- the drawer builds the same buttons as the bar (Hud/init menuButtons from the one MENU list), plus the login
		-- reward and the season pass while a reward waits
		local hud = fs.readFile("src/client/UI/Screens/Hud/init.luau")
		expect(string.find(hud, "local buttons = menuButtons(scope, props)", 1, true) ~= nil).toBe(true)
		local start = assert(string.find(hud, "local function drawer(", 1, true))
		local stop = assert(string.find(hud, "\nend\n", start, true))
		local body = string.sub(hud, start, stop)
		expect(string.find(body, "menuButtons(scope, props, close)", 1, true) ~= nil).toBe(true)
		expect(string.find(body, 'Name = "MenuToggle"', 1, true) ~= nil).toBe(true)
		expect(Tutorial.DRAWER).toBe("MenuToggle")
	end)

	it("no window is on the bar and a tile at once, and none twice", function()
		local seen: { [string]: boolean } = {}
		for _, list in { HudMenu.BAR, HudMenu.TILES } do
			for _, id in list do
				if seen[id] then
					error(`{id} twice`)
				end
				seen[id] = true
			end
		end
		for _, id in HudMenu.TILES do
			expect(HudMenu.isTile(id)).toBe(true)
			expect(HudMenu.onBar(id)).toBe(false)
		end
	end)

	it("every window key of Data/Keybinds opens a button of the bar or a tile, and that one shows it", function()
		for _, action in KeybindData.actions do
			local id = string.match(action.id, "^win_(.+)$")
			if not id then
				continue
			end
			if not (HudMenu.onBar(id) or HudMenu.isTile(id)) then
				error(`{action.id}: no button and no tile`)
			end
			expect(HudMenu.KEYS[id]).toBe(action.id)
		end
		-- T opens the emote wheel, its tile shows the key
		expect(HudMenu.KEYS.emotes).toBe("emote_wheel")
		for id, action in HudMenu.KEYS do
			if not KeybindData.get(action) then
				error(`{id}: unknown key action {action}`)
			end
			expect(HudMenu.onBar(id) or HudMenu.isTile(id)).toBe(true)
		end
	end)

	it("everything the HUD and the game menu opened before has a button or a tile", function()
		local before = {
			-- the 14 buttons of the HUD menu (and the Blood Moon one around its event)
			"inventory",
			"skills",
			"map",
			"quests",
			"guild",
			"party",
			"friends",
			"mounts",
			"rankings",
			"arena",
			"bloodmoon",
			"achievements",
			"wardrobe",
			"premium",
			"menu",
			-- the buttons by the portrait, the game menu's rows and the action bar's emote slot
			"login",
			"season",
			"whatsnew",
			"vip",
			"emotes",
		}
		for _, id in before do
			if not (HudMenu.onBar(id) or HudMenu.isTile(id)) then
				error(`{id} has no place`)
			end
		end
	end)

	it("the ☰ shows a tile's \"!\", not the bar's own", function()
		expect(HudMenu.attention({})).toBe(false)
		expect(HudMenu.attention({ mail = true })).toBe(true)
		expect(HudMenu.attention({ achievements = false, login = true })).toBe(true)
		expect(HudMenu.attention({ achievements = false, season = false })).toBe(false)
		-- stat points (the backpack) and new skill points have their own "!" on the bar
		expect(HudMenu.attention({ inventory = true, skills = true })).toBe(false)
	end)

	it("every tile has a short name in both languages that fits the tile in two lines", function()
		local size = smallText()
		local room = HudMenu.TILE.label
		for _, id in HudMenu.TILES do
			for lang, strings in { pl = pl, en = en } do
				local text = (strings :: any)[`menu.tile.{id}`]
				if type(text) ~= "string" or text == "" then
					error(`{lang} menu.tile.{id} missing`)
				end
				if string.find(text, "—", 1, true) then
					error(`{lang} menu.tile.{id}: an em-dash`)
				end
				-- greedy wrap: no word wider than a line, two lines at most
				local lines, line = 1, ""
				for word in string.gmatch(text, "%S+") do
					if width(word, size) > room then
						error(`{lang} menu.tile.{id}: "{word}" is wider than the tile`)
					end
					local joined = if line == "" then word else `{line} {word}`
					if width(joined, size) > room then
						lines += 1
						line = word
					else
						line = joined
					end
				end
				if lines > 2 then
					error(`{lang} menu.tile.{id}: "{text}" needs {lines} lines`)
				end
			end
		end
	end)

	it("no window hubs: every bar button opens its own window, a window has no tabs in its title bar", function()
		expect(fs.isFile("src/shared/Data/UiHubs.luau")).toBe(false)
		local manager = fs.readFile("src/client/Controllers/WindowManager.luau")
		expect(string.find(manager, "Hub", 1, true)).toBeNil()
		expect(string.find(manager, "FocusHint", 1, true)).toBeNil()
		local window = fs.readFile("src/client/UI/Components/Window.luau")
		expect(string.find(window, "Tab", 1, true)).toBeNil()
		local hud = fs.readFile("src/client/UI/Screens/Hud/init.luau")
		expect(string.find(hud, "props.OpenWindow(entry.id)", 1, true) ~= nil).toBe(true)
		for _, id in { "inventory", "skills", "map", "quests", "shop", "menu" } do
			expect(type((pl :: any)[`hud.menu.{id}`])).toBe("string")
			expect(type((en :: any)[`hud.menu.{id}`])).toBe("string")
		end
	end)

	it("the client lays out exactly these: the bar's entries and a tile for every id", function()
		local screen = fs.readFile("src/client/Controllers/ScreenController.luau")
		local menuStart = assert(string.find(screen, "local MENU: { Hud.MenuEntry } = {", 1, true))
		local menuEnd = assert(string.find(screen, "\n}", menuStart, true))
		local bar = {}
		for id in string.gmatch(string.sub(screen, menuStart, menuEnd), 'id = "([%w_]+)"') do
			table.insert(bar, id)
		end
		expect(bar).toEqual(HudMenu.BAR)
		local tilesStart = assert(string.find(screen, "local TILE_DEFS", 1, true))
		local tilesEnd = assert(string.find(screen, "\n}", tilesStart, true))
		local defs = string.sub(screen, tilesStart, tilesEnd)
		for _, id in HudMenu.TILES do
			if not string.find(defs, `id = "{id}"`, 1, true) then
				error(`ScreenController: no tile {id}`)
			end
			if not string.find(defs, `labelKey = "menu.tile.{id}"`, 1, true) then
				error(`ScreenController: tile {id} without its name menu.tile.{id}`)
			end
		end
	end)
end)

return nil
