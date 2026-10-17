--!strict
-- S135: the checklist of the "Parchment and iron" migration (DESIGN §23). Every window registered with
-- WindowManager.Register has an entry: `files` are its screen files (paths under src/client, a folder means every file
-- in it), `paper` says the window already uses the parchment look (WindowManager passes it to Window; its files use
-- only the roles of Theme.Paper / Theme.Iron / Theme.Brass), `session` the session that moves it. tests/uitheme.spec
-- checks the registrations, the files and that no colour or text-size literal is left in a paper window.
-- S136 moves the rest and removes the legacy Theme.Colors.

export type Entry = { files: { string }, paper: boolean, session: string }

local function win(session: string, paper: boolean, files: { string }): Entry
	return table.freeze({ files = table.freeze(files), paper = paper, session = session })
end

local UiWindows = {}

UiWindows.list = table.freeze({
	-- S135: parchment
	skills = win("S135", true, { "UI/Screens/SkillsWindow" }),
	character = win("S135", true, { "UI/Screens/CharacterWindow", "UI/Screens/BackpackPanel.luau" }),
	inventory = win("S135", true, { "UI/Screens/BackpackPanel.luau" }),
	menu = win("S135", true, { "UI/Screens/GameMenu.luau" }),
	npc = win("S135", true, { "UI/Screens/NpcDialog.luau" }),
	shop = win("S135", true, { "UI/Screens/ShopWindow.luau" }),
	questnpc = win("S135", true, { "UI/Screens/QuestDialog.luau" }),
	quests = win("S135", true, { "UI/Screens/QuestJournal.luau" }),
	trade = win("S135", true, { "UI/Screens/TradeWindow.luau" }),
	mail = win("S135", true, { "UI/Screens/MailWindow.luau" }),
	mailCompose = win("S135", true, { "UI/Screens/MailCompose.luau" }),
	profile = win("S135", true, { "UI/Screens/ProfileWindow.luau" }),
	party = win("S135", true, { "UI/Screens/PartyWindow.luau", "UI/Screens/PartyFinder.luau" }),
	-- S136: still the legacy dark look
	deposit = win("S136", false, { "UI/Screens/DepositWindow.luau" }),
	blacksmith = win("S136", false, { "UI/Screens/BlacksmithWindow" }),
	alchemy = win("S136", false, { "UI/Screens/AlchemyWindow.luau" }),
	backpacks = win("S136", false, { "UI/Screens/BackpackShop.luau" }),
	unbind = win("S136", false, { "UI/Screens/UnbindPicker.luau" }),
	huntshop = win("S136", false, { "UI/Screens/HuntShopWindow.luau" }),
	auction = win("S136", false, { "UI/Screens/AuctionWindow" }),
	questboard = win("S136", false, { "UI/Screens/QuestBoard.luau" }),
	guild = win("S136", false, { "UI/Screens/GuildWindow" }),
	guildfound = win("S136", false, { "UI/Screens/GuildFound.luau" }),
	map = win("S136", false, { "UI/Screens/WorldMap" }),
	areapicker = win("S136", false, { "UI/Screens/AreaPicker.luau" }),
	mounts = win("S136", false, { "UI/Screens/MountWindow.luau" }),
	rankings = win("S136", false, { "UI/Screens/RankingsWindow.luau" }),
	arena = win("S136", false, { "UI/Screens/ArenaWindow" }),
	bloodmoon = win("S136", false, { "UI/Screens/BloodMoonWindow.luau" }),
	dungeon = win("S136", false, { "UI/Screens/DungeonWindow.luau" }),
	login = win("S136", false, { "UI/Screens/LoginReward.luau" }),
	lootlog = win("S136", false, { "Controllers/LootComfortController.luau" }),
	stonepicker = win("S136", false, { "UI/Screens/StonePicker.luau" }),
	premium = win("S136", false, { "UI/Screens/PremiumShop" }),
	vip = win("S136", false, { "UI/Screens/VipWindow.luau" }),
	wardrobe = win("S136", false, { "UI/Screens/Wardrobe.luau" }),
	look = win("S136", false, { "UI/Screens/LookWindow.luau" }),
	dev = win("S136", false, { "UI/Screens/DevWindow" }),
	fightlog = win("S136", false, { "UI/Screens/FightLogWindow.luau" }),
	friends = win("S136", false, { "UI/Screens/FriendsWindow.luau" }),
} :: { [string]: Entry })

-- S136 screens outside windows (HUD and full-screen overlays), for the record; they draw on iron.
UiWindows.SCREENS = table.freeze({
	"UI/Screens/Hud",
	"UI/Screens/PartyFrames.luau",
	"UI/Screens/CharacterSelect",
	"UI/Screens/Cutscene.luau",
	"UI/Screens/BossReward.luau",
	"UI/Screens/LegendReveal.luau",
	"UI/Screens/ArenaOffer.luau",
	"UI/Screens/EmoteWheel.luau",
	"UI/Screens/FishingGame.luau",
	"UI/Screens/ComingSoon.luau",
	"UI/Screens/ReadyCheck.luau",
	"UI/Screens/FightCard.luau",
	"UI/Screens/PlayerMenu.luau",
})

-- Whether a window draws the parchment look (unknown ids: the legacy look).
function UiWindows.isPaper(id: string): boolean
	local entry = UiWindows.list[id]
	return entry ~= nil and entry.paper
end

return UiWindows
