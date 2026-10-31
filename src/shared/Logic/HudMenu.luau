--!strict
-- UI plan phase 1 (owner 2026-10-31: "the UI is hard to read, too much information and too many options on one
-- screen"): the HUD keeps six buttons in one row over the minimap (the backpack, skills, the world map, quests, the
-- Dragon Shop and the game menu ☰); every other window is a tile at the top of the game menu (Esc / ☰) with its key
-- on the tile, and every key stays. A "!" on a tile lights the ☰ (on a phone in landscape also the drawer button; the
-- drawer holds the same six, the login reward and the season pass only while a reward waits). Pure (Lune):
-- tests/hudmenu.spec.
-- UI plan phase 3 (Data/UiHubs): the bar holds the five hubs (Character, World, Community, Rivalry, Shop and rewards)
-- and the ☰; a hub's window shows its siblings as tabs. The tiles stay (another way in); the ☰'s "!" now comes only
-- from the tiles outside the hubs (a hub's button shows its windows' own).

local UiHubs = require("../Data/UiHubs")

local HudMenu = {}

-- The HUD bar, left to right (Controllers/ScreenController, Hud `menu`); the tutorial points at "inventory" (the
-- Character hub's button).
HudMenu.BAR = table.freeze({ "inventory", "world", "social", "rivalry", "premium", "menu" })

-- The game menu's tiles in order, four to a row (UI/Screens/GameMenu): people, competition, the character, rewards and
-- news (a hidden tile, the mounts below their level, leaves no hole).
HudMenu.TILES = table.freeze({
	"guild",
	"party",
	"friends",
	"mail",
	"arena",
	"rankings",
	"bloodmoon",
	"achievements",
	"mounts",
	"wardrobe",
	"emotes",
	"season",
	"login",
	"vip",
	"whatsnew",
})

-- The key action (Data/Keybinds) whose key a button or tile shows; the others have no key.
HudMenu.KEYS = table.freeze({
	inventory = "win_inventory",
	skills = "win_skills",
	map = "win_map",
	quests = "win_quests",
	guild = "win_guild",
	party = "win_party",
	friends = "win_friends",
	mounts = "win_mounts",
	arena = "win_arena",
	rankings = "win_rankings",
	achievements = "win_achievements",
	season = "win_season",
	emotes = "emote_wheel",
	-- UI plan phase 3: a hub's button shows the key of its first tab
	world = "win_map",
	social = "win_party",
	rivalry = "win_arena",
} :: { [string]: string })

-- A tile: `perRow` to a row, `h` tall, `gap` apart; its name gets at least `label` px a line, on two lines at most.
HudMenu.TILE = table.freeze({ perRow = 4, h = 80, gap = 8, label = 120 })

local ON_BAR: { [string]: boolean } = {}
for _, id in HudMenu.BAR do
	ON_BAR[id] = true
end
local IS_TILE: { [string]: boolean } = {}
for _, id in HudMenu.TILES do
	IS_TILE[id] = true
end

function HudMenu.onBar(id: string): boolean
	return ON_BAR[id] == true
end

function HudMenu.isTile(id: string): boolean
	return IS_TILE[id] == true
end

-- Whether the ☰ shows "!": the "!" of a tile outside the hubs is lit (`lit`: id -> its badge now); the hubs' buttons
-- show their windows' own.
function HudMenu.attention(lit: { [string]: boolean }): boolean
	for id, on in lit do
		if on and IS_TILE[id] and UiHubs.hubOf(id) == nil then
			return true
		end
	end
	return false
end

return HudMenu
