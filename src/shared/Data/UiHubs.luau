--!strict
-- Window groups (UI plan phase 3, `wyglad/UI-PLAN.md` §5): five hubs on the HUD bar next to the ☰. A hub is a row of
-- existing windows shown as tabs in the window's title bar (Components/Window); a tab opens the next window in the same
-- place (one window at a time stays, Logic/WindowRules). Every window key still opens its own window, so its hub opens
-- on that tab. The NPC service windows (shop, smith, vault, auction...) stay outside: an NPC opens them, not the HUD.
-- Pure (Lune): tests/uihubs.spec.

local UiHubs = {}

export type Hub = {
	id: string,
	button: string, -- the HUD bar button's id (Logic/HudMenu.BAR; "inventory" keeps the tutorial's anchor)
	icon: string, -- the glyph while there is no picture
	labelKey: string, -- the button's tooltip
	tabs: { string }, -- window ids, in tab order; the first is where the hub opens the first time
}

UiHubs.HUBS = table.freeze({
	{
		id = "character",
		button = "inventory",
		icon = "▣",
		labelKey = "hud.hub.character",
		tabs = { "inventory", "skills", "mounts", "wardrobe" },
	},
	{
		id = "world",
		button = "world",
		icon = "⌖",
		labelKey = "hud.hub.world",
		tabs = { "map", "quests", "achievements" },
	},
	{
		id = "social",
		button = "social",
		icon = "☍",
		labelKey = "hud.hub.social",
		tabs = { "party", "guild", "friends", "mail" },
	},
	{
		id = "rivalry",
		button = "rivalry",
		icon = "⚔",
		labelKey = "hud.hub.rivalry",
		tabs = { "arena", "rankings", "bloodmoon" },
	},
	{
		id = "shop",
		button = "premium",
		icon = "◆",
		labelKey = "hud.hub.shop",
		tabs = { "premium", "season", "vip", "login" },
	},
} :: { Hub })

-- Windows that are another window's tab: the backpack window ("character") is the "inventory" tab (WindowRules: B
-- without a service opens it).
UiHubs.ALIAS = table.freeze({ character = "inventory" } :: { [string]: string })

-- The tabs whose label is not their game menu tile's (`menu.tile.<id>`): the HUD bar's old buttons.
local OWN_LABEL: { [string]: boolean } = { inventory = true, skills = true, map = true, quests = true, premium = true }

local BY_TAB: { [string]: Hub } = {}
local BY_ID: { [string]: Hub } = {}
local BY_BUTTON: { [string]: Hub } = {}
for _, hub in UiHubs.HUBS do
	BY_ID[hub.id] = hub
	BY_BUTTON[hub.button] = hub
	for _, tab in hub.tabs do
		assert(BY_TAB[tab] == nil, `window {tab} in two hubs`)
		BY_TAB[tab] = hub
	end
end

-- The tab id of a window (its alias, else itself).
function UiHubs.tabOf(windowId: string): string
	return UiHubs.ALIAS[windowId] or windowId
end

-- The hub a window belongs to, nil for the windows outside the hubs.
function UiHubs.hubOf(windowId: string): Hub?
	return BY_TAB[UiHubs.tabOf(windowId)]
end

function UiHubs.get(hubId: string): Hub?
	return BY_ID[hubId]
end

-- The hub behind a HUD bar button, nil for the ☰.
function UiHubs.byButton(buttonId: string): Hub?
	return BY_BUTTON[buttonId]
end

-- The label key of a tab.
function UiHubs.tabLabel(tab: string): string
	return if OWN_LABEL[tab] then `hub.tab.{tab}` else `menu.tile.{tab}`
end

-- The tabs that show: `shown(tab)` says whether one is there now (registered, unlocked, on this server).
function UiHubs.visibleTabs(hub: Hub, shown: (tab: string) -> boolean): { string }
	local out = {}
	for _, tab in hub.tabs do
		if shown(tab) then
			table.insert(out, tab)
		end
	end
	return out
end

-- Where a hub's button opens it: its first shown tab (always the same, so the tutorial's "backpack" step still meets
-- the backpack); nil when none shows.
function UiHubs.entry(hub: Hub, shown: (tab: string) -> boolean): string?
	return UiHubs.visibleTabs(hub, shown)[1]
end

return UiHubs
