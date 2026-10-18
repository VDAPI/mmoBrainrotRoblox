--!strict
-- S135/S136 "Parchment and iron" (DESIGN §23): every window registered with WindowManager.Register has an entry here
-- and every file under UI/Screens belongs to a window or to SCREENS. `files` are paths under src/client (a folder
-- means every file in it); `surface` is the surface the window or screen draws on:
--   paper  windows, cards and sheets (parchment body, iron frame and title bar; WindowManager passes it to Window)
--   iron   HUD, overlays over the game world and the admin panel (dark iron tiles with a brass edge)
-- `session` is the session that moved it. tests/uitheme.spec checks the registrations, the files and that no legacy
-- token, colour literal or text-size literal is left in any of them.

export type SurfaceName = string -- "paper" | "iron"
export type Entry = { files: { string }, surface: SurfaceName, session: string, why: string? }

local function win(session: string, surface: SurfaceName, files: { string }, why: string?): Entry
	return table.freeze({ files = table.freeze(files), surface = surface, session = session, why = why })
end

local UiWindows = {}

UiWindows.list = table.freeze({
	-- S135
	skills = win("S135", "paper", { "UI/Screens/SkillsWindow" }),
	character = win("S135", "paper", { "UI/Screens/CharacterWindow", "UI/Screens/BackpackPanel.luau" }),
	inventory = win("S135", "paper", { "UI/Screens/BackpackPanel.luau" }),
	menu = win("S135", "paper", { "UI/Screens/GameMenu.luau" }),
	npc = win("S135", "paper", { "UI/Screens/NpcDialog.luau" }),
	shop = win("S135", "paper", { "UI/Screens/ShopWindow.luau" }),
	questnpc = win("S135", "paper", { "UI/Screens/QuestDialog.luau" }),
	quests = win("S135", "paper", { "UI/Screens/QuestJournal.luau" }),
	trade = win("S135", "paper", { "UI/Screens/TradeWindow.luau" }),
	mail = win("S135", "paper", { "UI/Screens/MailWindow.luau" }),
	mailCompose = win("S135", "paper", { "UI/Screens/MailCompose.luau" }),
	profile = win("S135", "paper", { "UI/Screens/ProfileWindow.luau" }),
	party = win("S135", "paper", { "UI/Screens/PartyWindow.luau", "UI/Screens/PartyFinder.luau" }),
	-- S136
	deposit = win("S136", "paper", { "UI/Screens/DepositWindow.luau" }),
	blacksmith = win("S136", "paper", { "UI/Screens/BlacksmithWindow" }),
	alchemy = win("S136", "paper", { "UI/Screens/AlchemyWindow.luau" }),
	backpacks = win("S136", "paper", { "UI/Screens/BackpackShop.luau" }),
	unbind = win("S136", "paper", { "UI/Screens/UnbindPicker.luau" }),
	huntshop = win("S136", "paper", { "UI/Screens/HuntShopWindow.luau" }),
	auction = win("S136", "paper", { "UI/Screens/AuctionWindow" }),
	questboard = win("S136", "paper", { "UI/Screens/QuestBoard.luau" }),
	guild = win("S136", "paper", { "UI/Screens/GuildWindow" }),
	guildfound = win("S136", "paper", { "UI/Screens/GuildFound.luau" }),
	map = win("S136", "paper", { "UI/Screens/WorldMap" }),
	areapicker = win("S136", "paper", { "UI/Screens/AreaPicker.luau" }),
	mounts = win("S136", "paper", { "UI/Screens/MountWindow.luau" }),
	rankings = win("S136", "paper", { "UI/Screens/RankingsWindow.luau" }),
	arena = win("S136", "paper", { "UI/Screens/ArenaWindow" }),
	bloodmoon = win("S136", "paper", { "UI/Screens/BloodMoonWindow.luau" }),
	dungeon = win("S136", "paper", { "UI/Screens/DungeonWindow.luau" }),
	login = win("S136", "paper", { "UI/Screens/LoginReward.luau" }),
	lootlog = win("S136", "paper", { "UI/Screens/LootLog.luau" }),
	stonepicker = win("S136", "paper", { "UI/Screens/StonePicker.luau" }),
	premium = win("S136", "paper", { "UI/Screens/PremiumShop" }),
	vip = win("S136", "paper", { "UI/Screens/VipWindow.luau" }),
	wardrobe = win("S136", "paper", { "UI/Screens/Wardrobe.luau" }),
	look = win("S136", "paper", { "UI/Screens/LookWindow.luau" }),
	fightlog = win("S136", "paper", { "UI/Screens/FightLogWindow.luau" }),
	friends = win("S136", "paper", { "UI/Screens/FriendsWindow.luau" }),
	dev = win("S136", "iron", { "UI/Screens/DevWindow" }, "admin overlay on iron at the right edge"),
	-- S151b
	achievements = win("S151b", "paper", { "UI/Screens/AchievementsWindow" }),
} :: { [string]: Entry })

-- S136: screens outside windows (HUD, overlays, full-screen screens, cards) and their surface.
UiWindows.SCREENS = table.freeze({
	["UI/Screens/Hud"] = "iron",
	["UI/Screens/Hud/WorldBossPanel.luau"] = "iron", -- S149b: the world boss panel (also under Hud; named for the list)
	["UI/Screens/Hud/AchievementToast.luau"] = "iron", -- S151: the achievement toast (also under Hud; named for the list)
	["UI/Screens/PartyFrames.luau"] = "iron",
	["UI/Screens/Cutscene.luau"] = "iron",
	["UI/Screens/EmoteWheel.luau"] = "iron",
	["UI/Screens/FishingGame.luau"] = "iron",
	["UI/Screens/FightCard.luau"] = "iron",
	["UI/Screens/CharacterSelect/init.luau"] = "iron", -- the veil over the world
	["UI/Screens/CharacterSelect/SlotCard.luau"] = "paper",
	["UI/Screens/CharacterSelect/Creator.luau"] = "paper",
	["UI/Screens/BossReward.luau"] = "paper",
	["UI/Screens/LegendReveal.luau"] = "paper",
	["UI/Screens/ArenaOffer.luau"] = "paper",
	["UI/Screens/ComingSoon.luau"] = "paper",
	["UI/Screens/ReadyCheck.luau"] = "paper",
	["UI/Screens/PlayerMenu.luau"] = "paper",
} :: { [string]: SurfaceName })

-- The surface a window draws on (unknown ids: parchment).
function UiWindows.surface(id: string): SurfaceName
	local entry = UiWindows.list[id]
	return if entry then entry.surface else "paper"
end

return UiWindows
