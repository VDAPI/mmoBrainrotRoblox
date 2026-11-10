--!strict
-- Text scan (owner 2026-11-10: "bardzo dużo napisów, niektóre rzeczy zasłaniają inne, zbyt szczegółowe opisy"): where
-- the game shows each localization key, read from the code, so tests/textcaps.spec can hold every key to the cap of
-- its surface (Logic/TextCaps) and hand each long text to the package of the UI plan that owns it. Not a spec
-- (tests/run.luau runs *.spec.luau only).
--
-- One pass over every source file, cached. A small tokenizer skips comments and strings and keeps a stack of
-- brackets: calls with their callee and argument, tables with their field, `templates` with their holes, function
-- bodies (to their `end`, by the indentation StyLua keeps). When a string literal or a template names a key it walks
-- out through the stack to the first call or field that shows it (SITES, FIELDS), passing Text lookups, wrappers
-- such as string.format and the `return` of a callback (scope:Computed); a key in a file of FILES that reached no site
-- takes that file's surface (the HUD, the cards, the prompts). `return false, "key"` is an error a toast shows. Within
-- a file, a key kept in a local (`local message = Text.now(...)`, `table.insert(lines, ...)`, `local key = if ...`)
-- takes the surfaces the local reaches, and a function that passes a parameter on to a site (DungeonService's
-- fail(run, key) -> announce) is a site itself. Every bracket and body must close in every file (`health`), so a
-- tokenizer that lost its place fails the spec instead of missing keys quietly.
--
-- Owner of a key: the first package, in the order A B C D E, with a file that reads it (OWNERS, the path tables of
-- the UI plan, new files included); B also reads every key at a toast, banner, alert, prompt or card site, since its
-- message band shows them wherever the call is; else the first package whose fixture rule matches the key; else E.

local fs = require("@lune/fs")

local TextCaps = require("../src/shared/Logic/TextCaps")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local TextScan = {}

TextScan.PACKAGES = { "A", "B", "C", "D", "E" }

-- Scanned for keys: the client, the server and the shared code; of the shared data only the folds and the keybind
-- names (the rest of Data holds the texts' ids for items, quests and monsters, not the places that show them).
TextScan.ROOTS = { "src/client", "src/server", "src/shared" }
TextScan.SKIP = { "src/shared/Data/" }
TextScan.KEEP = { "src/shared/Data/Folds/", "src/shared/Data/Keybinds.luau" }

-- Developer tools: parsed, but their keys show nowhere a player looks.
TextScan.DEV_FILES = {
	"src/server/Admin/",
	"src/server/Services/AdminService.luau",
	"src/client/Controllers/AnimLabController.luau",
	"src/client/Controllers/DevController.luau",
	"src/client/Controllers/UiDevController.luau",
	"src/client/UI/Screens/DevWindow/",
	"src/shared/Logic/AdminArgs.luau",
	"src/shared/Logic/AnimLab.luau",
	"src/shared/Logic/DevPreset.luau",
}
TextScan.DEV_KEYS = { "admin.", "dev.", "animlab." }

local HUD = "src/client/UI/Screens/Hud/"

-- The calls that read a key: callee -> the argument that holds it.
TextScan.LOOKUPS = table.freeze({
	["Text.now"] = 1,
	["Text.T"] = 2,
	["Text.get"] = 2,
	["Locale.T"] = 1,
} :: { [string]: number })

-- Calls a text passes through on its way to a site (by the callee's last name).
TextScan.WRAPPERS = table.freeze({
	format = true,
	upper = true,
	lower = true,
	tostring = true,
	concat = true,
	Computed = true,
	compose = true,
} :: { [string]: boolean })

export type Site = {
	surface: string, -- "" for an argument that is shown elsewhere without a cap (a tooltip's Alt details)
	call: string, -- the callee, matched on its last names (`self.services.announce` is `announce`)
	arg: number?, -- the argument with the key or the text; nil for any argument
	channel: number?, -- the argument with the remote's name, for Net.Fire* ...
	value: string?, -- ... and that name
	under: string?, -- only in files under this path
}

local function remote(surface: string, name: string): { Site }
	return {
		{ surface = surface, call = "Net.Fire", arg = 3, channel = 2, value = name },
		{ surface = surface, call = "Net.FireList", arg = 3, channel = 2, value = name },
		{ surface = surface, call = "Net.FireAll", arg = 2, channel = 1, value = name },
	}
end

-- Calls that show a key (verified against the code on 2026-11-10).
TextScan.SITES = {} :: { Site }
for _, list in
	{
		-- toasts: Toast.push on the client, the "Toast" remote and the services' toast(player, key, args?, kind?)
		{
			{ surface = "toast", call = "Toast.push", arg = 1 },
			{ surface = "toast", call = "NotificationController.Show", arg = 1 },
			{ surface = "toast", call = "toast", arg = 2, under = "src/server/" },
			{ surface = "toast", call = "Toast", arg = 2, under = "src/server/" },
			-- back from an arena server: Transfer.home toasts its reason (ArenaHost wraps it in home / homeAll)
			{ surface = "toast", call = "Transfer.home", arg = 3 },
			{ surface = "toast", call = "Transfer.homeAll", arg = 1 },
			{ surface = "toast", call = "home", arg = 2, under = "src/server/Arena/ArenaHost.luau" },
			{ surface = "toast", call = "homeAll", arg = 1, under = "src/server/Arena/ArenaHost.luau" },
		},
		remote("toast", "Toast"),
		-- banners: the "Announce" remote (AnnounceService, the tourney's announceAt), Announcement on the client
		{
			{ surface = "banner", call = "AnnounceService.Server", arg = 1 },
			{ surface = "banner", call = "AnnounceService.Global" },
			{ surface = "banner", call = "announceAt", arg = 1, under = "src/server/Services/TourneyService.luau" },
			{ surface = "banner", call = "Announcement.push", arg = 1 },
		},
		remote("banner", "Announce"),
		-- alerts: the "BossAnnounce" remote and the helpers that send it (dungeon, boss, world boss, arena, duel), shown
		-- by DungeonController's announcer
		{
			{ surface = "alert", call = "announce", under = "src/server/" },
			{ surface = "alert", call = "announceTo", under = "src/server/" },
			{ surface = "alert", call = "both", under = "src/server/Services/DuelService.luau" },
			{ surface = "alert", call = "showAnnouncement", arg = 1 },
		},
		remote("alert", "BossAnnounce"),
		-- the tooltip of a HUD element; its Alt details have no cap of their own
		{
			{ surface = "hudTip", call = "Tooltip.attach", arg = 3, under = HUD },
			{ surface = "", call = "Tooltip.attach", arg = 4, under = HUD },
		},
	} :: { { Site } }
do
	for _, site in list do
		table.insert(TextScan.SITES, site)
	end
end
table.freeze(TextScan.SITES)

export type Field = {
	surface: string,
	field: string,
	call: string?, -- the table is argument `arg` of this call (any table without)
	arg: number?,
	under: string?,
	tabs: boolean?, -- only in files that require Components.Tabs or SideTabs (their items are { id, label })
	key: string?, -- only for keys that match this pattern
}

-- Table fields that show a key.
TextScan.FIELDS = {} :: { Field }
for _, call in { "ShowModal", "showModal" } do
	table.insert(TextScan.FIELDS, { surface = "modalTitle", field = "Title", call = call, arg = 1 })
	table.insert(TextScan.FIELDS, { surface = "modalBody", field = "Message", call = call, arg = 1 })
	table.insert(TextScan.FIELDS, { surface = "modalDetails", field = "Details", call = call, arg = 1 })
	table.insert(TextScan.FIELDS, { surface = "modalButton", field = "ConfirmText", call = call, arg = 1 })
	table.insert(TextScan.FIELDS, { surface = "modalButton", field = "CancelText", call = call, arg = 1 })
end
for _, field in
	{
		{ surface = "sectionTitle", field = "Title", call = "Section.new", arg = 2 },
		{ surface = "sectionSummary", field = "Summary", call = "Section.new", arg = 2 },
		{ surface = "infoTip", field = "Text", call = "InfoTip.new", arg = 2 },
		{ surface = "line", field = "Text", call = "InfoLine.new", arg = 2 },
		-- the player's answers in a quest dialogue are buttons with a reply's cap
		{ surface = "reply", field = "Text", call = "Button", arg = 2, key = "^quest%.[%w_]+%.say%.[%w_]+$" },
		{ surface = "button", field = "Text", call = "Button", arg = 2 },
		{ surface = "infoTip", field = "Info" },
		-- the (i) of a card spec: PremiumShop/Cards, WorldMap/DetailCard and QuestBoard pass it to InfoTip
		{ surface = "infoTip", field = "info", under = "src/client/UI/" },
		{ surface = "windowTitle", field = "titleKey" },
		-- the names in the keybind list (Settings > Keys)
		{ surface = "keyName", field = "labelKey", under = "src/shared/Data/Keybinds.luau" },
		{ surface = "tab", field = "label", tabs = true },
		{ surface = "hudTip", field = "Tooltip", under = HUD },
		{ surface = "hudTip", field = "Tip", under = HUD },
	} :: { Field }
do
	table.insert(TextScan.FIELDS, field)
end
table.freeze(TextScan.FIELDS)

-- Files whose every key that reached no site is shown on one surface ("any key read in Screens/Hud").
TextScan.FILES = table.freeze({
	{ surface = "hudLine", under = HUD },
	{ surface = "card", under = "src/client/UI/Screens/FightCard.luau" },
	{ surface = "card", under = "src/client/UI/Screens/BossReward.luau" },
	{ surface = "card", under = "src/client/UI/Screens/LegendReveal.luau" },
	{ surface = "prompt", under = "src/client/UI/Screens/ArenaOffer.luau" },
	{ surface = "prompt", under = "src/client/UI/Screens/ReadyCheck.luau" },
	{ surface = "prompt", under = "src/client/UI/Components/Prompt.luau" },
	-- the boss cast bar: the blow's name and its warning
	{ surface = "alert", under = "src/client/Vfx/BossCastBar.luau" },
	{ surface = "alert", under = "src/shared/Logic/BossCast.luau" },
} :: { { surface: string, under: string } })

-- Message surfaces: B's band shows them, wherever the call is (T4 holds every literal key there to a surface).
TextScan.MESSAGES = table.freeze({ toast = true, banner = true, alert = true, prompt = true, card = true })

-- Error keys (`return false, "key"`) the client does not toast: it shows them on a surface of its own, mapped at that
-- call site. SocialController.failed offers a letter in a modal when a whisper's target is on another server.
TextScan.NOT_TOASTED = table.freeze({ ["social.whisper.otherServer"] = true } :: { [string]: boolean })

local function expandOwners(dir: string, names: { string }): { string }
	local out = {}
	for _, name in names do
		table.insert(out, `{dir}{name}.luau`)
	end
	return out
end

local function concat(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, path in list do
			table.insert(out, path)
		end
	end
	return out
end

-- The UI plan's path table (2026-11-10), new files included. A path ending in "/" is a folder.
TextScan.OWNERS = table.freeze({
	A = concat(
		expandOwners("src/shared/Logic/", {
			"HudZones",
			"PhoneHud",
			"HudStack",
			"HudLayout",
			"HudMenu",
			"HudReveal",
			"TrackerFold",
			"QuestRows",
			"UiScale",
			"Tutorial",
			"TutorialTile",
		}),
		{ "src/shared/Data/Folds/Hud.luau" },
		expandOwners("src/client/UI/", {
			"Scale",
			"PhoneLayout",
			"HudSlots",
			"HudAnchors",
			"HudDrag",
			"HudGate",
			"MenuAttention",
			"PvpSwitch",
			"QuestTrack",
		}),
		expandOwners("src/client/UI/Components/", { "PortraitFrame", "PvpDot", "ChannelBar" }),
		expandOwners(HUD, {
			"init",
			"TargetFrame",
			"CastBar",
			"PoolLabel",
			"NavBar",
			"Minimap",
			"MobileSkills",
			"SkillBar",
			"AttackButton",
			"PotionBar",
			"SprintButton",
			"MountButton",
			"MailButton",
			"PvpToggle",
			"AutoGroup",
			"AutoGrindButton",
			"AutoPotionButton",
			"LureButton",
			"EffectIcons",
			"BlessingBadge",
			"BlessingIcon",
			"WaitingRow",
			"LoginButton",
			"SeasonButton",
			"ChatDock",
			"DeathScreen",
			"LowHpVignette",
			"TutorialHint",
			"QuestTracker",
			"WorldBossPanel",
			"WorldEventPanel",
			"BloodMoonPanel",
			"TourneyPanel",
			"Elite2Timer",
			"ArenaPanel",
			"ArenaTeams",
			"PanelHeader",
			"StackChip",
		}),
		{ "src/client/UI/Screens/PartyFrames.luau" },
		expandOwners(
			"src/client/Controllers/",
			{ "ScreenController", "TutorialController", "UIController", "CombatFxController" }
		)
	),
	B = concat(
		expandOwners("src/shared/Logic/", { "TopBand", "NoticeQueue" }),
		expandOwners("src/client/UI/", { "Notify", "TopBandState", "HudCover", "FightView" }),
		expandOwners("src/client/UI/Components/", { "Toast", "Announcement", "FightTable", "FightLoot", "Prompt" }),
		expandOwners(HUD, { "AchievementToast", "AreaBanner", "ZoneBanner", "BarkToast" }),
		expandOwners(
			"src/client/UI/Screens/",
			{ "FightCard", "ArenaOffer", "BossReward", "LegendReveal", "ReadyCheck" }
		),
		{ "src/client/Vfx/BossCastBar.luau" },
		expandOwners("src/client/Controllers/", {
			"NotificationController",
			"DungeonController",
			"LootComfortController",
			"LootController",
			"PartyController",
			"SocialController",
			"ArenaController",
			"BarkController",
			"AchievementController",
			"AreaController",
			"FightLogController",
		})
	),
	C = concat(
		expandOwners("src/client/UI/Components/", {
			"Window",
			"Modal",
			"Tooltip",
			"ItemTooltip",
			"InfoTip",
			"Details",
			"Section",
			"Button",
			"IconButton",
			"TextInput",
			"NumberInput",
			"Tabs",
			"SideTabs",
			"ListRow",
			"InfoLine",
			"SectionLabel",
			"Select",
			"Toggle",
			"ActionMenu",
			"LanguageToggle",
			"Bar",
		}),
		{ "src/client/UI/Theme.luau" },
		expandOwners("src/shared/Logic/", { "WindowFrame", "Popover", "WindowRules", "TipText" }),
		expandOwners("src/client/Controllers/", { "WindowManager", "ItemController", "ReworkController" })
	),
	D = concat(
		{
			"src/client/UI/Screens/CharacterWindow/",
			"src/client/UI/Screens/SkillsWindow/",
			"src/client/UI/Screens/BlacksmithWindow/",
			"src/client/UI/Screens/AuctionWindow/",
			"src/client/UI/Screens/PremiumShop/",
		},
		expandOwners("src/client/UI/Screens/", {
			"BackpackPanel",
			"BackpackShop",
			"MountWindow",
			"LookWindow",
			"Wardrobe",
			"WardrobeTransmog",
			"AlchemyWindow",
			"ShopWindow",
			"DepositWindow",
			"PortalShopWindow",
			"HuntShopWindow",
			"WanderingMerchantWindow",
			"VipWindow",
			"StonePicker",
			"UnbindPicker",
			"TradeWindow",
		}),
		expandOwners("src/client/UI/Components/", {
			"ItemSlot",
			"SelectableSlot",
			"BuildSetSwitch",
			"LookPicker",
			"LookPreview",
			"ItemIcon",
			"RarityFrame",
			"CostBadge",
			"CurrencyIcon",
			"PathBadge",
		}),
		expandOwners("src/client/UI/", {
			"SkillInfo",
			"SkillsTab",
			"SkillsAttention",
			"PremiumConfirm",
			"SeasonPassBuy",
			"ItemText",
			"DragDrop",
			"WardrobeStart",
		}),
		expandOwners(
			"src/client/Controllers/",
			{ "MarketController", "PremiumController", "MountController", "GatherController" }
		),
		expandOwners("src/shared/Logic/", { "CharacterSections", "NodeText", "TooltipModel", "GearLayout" }),
		{ "src/shared/Data/Folds/Gear.luau" }
	),
	E = concat(
		{
			"src/client/UI/Screens/WorldMap/",
			"src/client/UI/Screens/AchievementsWindow/",
			"src/client/UI/Screens/ArenaWindow/",
			"src/client/UI/Screens/GuildWindow/",
			"src/client/UI/Screens/CharacterSelect/",
		},
		expandOwners("src/client/UI/Screens/", {
			"QuestJournal",
			"QuestBoard",
			"QuestDialog",
			"NpcDialog",
			"AreaPicker",
			"RankingsWindow",
			"SeasonPass",
			"BloodMoonWindow",
			"DungeonWindow",
			"FightLogWindow",
			"LootLog",
			"LoginReward",
			"WhatsNew",
			"ComingSoon",
			"GameMenu",
			"PartyWindow",
			"PartyFinder",
			"FriendsWindow",
			"GuildFound",
			"MailWindow",
			"MailCompose",
			"ProfileWindow",
			"PlayerMenu",
			"EmoteWheel",
			"FishingGame",
			"Cutscene",
		}),
		expandOwners(
			"src/client/UI/",
			{ "QuestText", "NpcQuests", "AreaProfileText", "BloodMoonView", "ContractActions", "MailDraft" }
		),
		expandOwners("src/client/UI/Components/", { "QuestRewards", "QuestItemIcons" }),
		expandOwners("src/client/Controllers/", {
			"NpcController",
			"QuestController",
			"SeasonController",
			"RankingsController",
			"BloodMoonController",
			"ReturningController",
			"LoginRewardController",
			"GuildController",
			"WorldController",
		}),
		expandOwners("src/shared/Logic/", { "Dialogue", "WorldLayout" }),
		expandOwners("src/shared/Data/Folds/", { "World", "Menu" })
	),
} :: { [string]: { string } })

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

local function under(path: string, list: { string }): boolean
	for _, prefix in list do
		if startsWith(path, prefix) then
			return true
		end
	end
	return false
end

-- The package that owns a file (nil for a file of no package).
local fileOwners: { [string]: string } = {}
local folderOwners: { { prefix: string, package: string } } = {}
for _, package in TextScan.PACKAGES do
	for _, path in TextScan.OWNERS[package] do
		if string.sub(path, -1) == "/" then
			table.insert(folderOwners, { prefix = path, package = package })
		else
			assert(fileOwners[path] == nil, `TextScan: {path} is in two packages`)
			fileOwners[path] = package
		end
	end
end

function TextScan.ownerOfFile(path: string): string?
	local package = fileOwners[path]
	if package then
		return package
	end
	for _, folder in folderOwners do
		if startsWith(path, folder.prefix) then
			return folder.package
		end
	end
	return nil
end

export type Rule = { pattern: string, surface: string }
export type Known = { surface: string, chars: number, reason: string }
export type Fixture = { rules: { Rule }, known: { [string]: Known } }

local fixtureCache: { [string]: Fixture }? = nil

-- tests/fixtures/textcaps/<package>.luau of every package.
function TextScan.fixtures(): { [string]: Fixture }
	if fixtureCache then
		return fixtureCache
	end
	local out: { [string]: Fixture } = {}
	for _, package in TextScan.PACKAGES do
		out[package] = (require :: any)(`./fixtures/textcaps/{package}`)
	end
	fixtureCache = out
	return out
end

-- Every key of the game (pl), sorted.
local KEYS: { string } = {}
for key in pl :: { [string]: string } do
	table.insert(KEYS, key)
end
table.sort(KEYS)
TextScan.KEYS = KEYS

-- The keys `pattern` matches among those that start with `prefix` (binary search on the sorted keys).
local matchCache: { [string]: { string } } = {}
local function keysMatching(prefix: string, pattern: string): { string }
	local cached = matchCache[pattern]
	if cached then
		return cached
	end
	local low, high = 1, #KEYS + 1
	while low < high do
		local mid = (low + high) // 2
		if KEYS[mid] < prefix then
			low = mid + 1
		else
			high = mid
		end
	end
	local out = {}
	for i = low, #KEYS do
		local key = KEYS[i]
		if not startsWith(key, prefix) then
			break
		end
		if string.find(key, pattern) then
			table.insert(out, key)
		end
	end
	matchCache[pattern] = out
	return out
end

local function escape(text: string): string
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Byte classes.
local IDENT: { [number]: boolean } = {}
for b = 0, 255 do
	local c = string.char(b)
	IDENT[b] = string.match(c, "[%w_]") ~= nil
end
local CHAIN: { [number]: boolean } = table.clone(IDENT)
CHAIN[46] = true -- .
CHAIN[58] = true -- :
local SPACE: { [number]: boolean } = { [32] = true, [9] = true, [10] = true, [13] = true }

local KEYWORDS = {
	["and"] = true,
	["break"] = true,
	["do"] = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	["false"] = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	["in"] = true,
	["local"] = true,
	["nil"] = true,
	["not"] = true,
	["or"] = true,
	["repeat"] = true,
	["return"] = true,
	["then"] = true,
	["true"] = true,
	["until"] = true,
	["while"] = true,
	["continue"] = true,
}

type Frame = {
	-- "(" a call or a grouping, "fn" a function's parameters, "body" its body (up to its `end`, found by the
	-- indentation StyLua keeps), "{" a table, "[" an index, "`" a template, "hole" a template's {expression}
	kind: string,
	at: number, -- where the callee (or the bracket) starts
	callee: string?,
	arg: number,
	start: number, -- where the current argument or field value starts
	field: string?,
	lits: { [number]: string },
	lookup: number?,
	sites: { Site }?,
	assign: string?,
	into: string?,
	wrapper: boolean,
	parts: { string }?,
	holes: number,
	segment: number,
	name: string?, -- "fn" and "body": the function's name
	indent: string?, -- "fn": the indentation of the line it starts on
	params: { string }?, -- "body": the function's parameters
	stop: number?, -- "body": where its `end` is
	last: string?, -- "body": the local the latest statement-level assignment set
	id: number,
}

-- Where a key ended: at a site (surface; "" when shown without a cap of its own), in a local or a function's return
-- value (bind, declared in body `body`), or in argument `arg` of a call that a helper of the file may turn into a
-- site (call).
type Occurrence = {
	keys: { string },
	surface: string?,
	bind: string?,
	body: number,
	call: string?,
	arg: number?,
}

-- A local that reaches a site, with the bodies around that site (innermost first); `anywhere` for a local a callback
-- returns (its own body is closed by the time the site is read).
type IdentSite = {
	name: string,
	surface: string?,
	call: string?,
	arg: number?,
	bodies: { Frame },
	anywhere: boolean,
}

export type Scan = {
	files: number,
	-- key -> its surfaces (sites, fields, files, fixture rules)
	surfaces: { [string]: { [string]: boolean } },
	-- key -> the packages with a file that reads it
	readers: { [string]: { [string]: boolean } },
	-- literal keys at a message site: key -> surface (keys missing from pl included)
	messages: { [string]: string },
	-- message calls parsed: "toast client", "toast server", "banner", "alert", "hudTip"
	calls: { [string]: number },
	-- files where a bracket or a function body did not close
	health: { string },
}

local function lastName(chain: string): string
	return string.match(chain, "([%w_]+)$") or ""
end

local function calleeIs(callee: string, call: string): boolean
	if callee == call then
		return true
	end
	local n = #call
	if #callee <= n then
		return false
	end
	local cut = string.byte(callee, #callee - n)
	return (cut == 46 or cut == 58) and string.sub(callee, -n) == call
end

local FIELDS_BY_NAME: { [string]: { Field } } = {}
for _, field in TextScan.FIELDS do
	FIELDS_BY_NAME[field.field] = FIELDS_BY_NAME[field.field] or {}
	table.insert(FIELDS_BY_NAME[field.field], field)
end

local function add(map: { [string]: { [string]: boolean } }, key: string, surface: string)
	local set = map[key]
	if set == nil then
		set = {}
		map[key] = set
	end
	set[surface] = true
end

-- Scans one file into `out`.
local function scanFile(path: string, src: string, out: Scan, keySet: { [string]: string })
	local dev = under(path, TextScan.DEV_FILES)
	local package = TextScan.ownerOfFile(path)
	local tabs = string.find(src, "%.Tabs%)") ~= nil or string.find(src, "%.SideTabs%)") ~= nil
	local fallback: string? = nil
	for _, rule in TextScan.FILES do
		if startsWith(path, rule.under) then
			fallback = rule.surface
			break
		end
	end
	local server = startsWith(path, "src/server/")
	local sitesByLast: { [string]: { Site } } = {}
	for _, site in TextScan.SITES do
		if site.under == nil or startsWith(path, site.under) then
			local last = lastName(site.call)
			sitesByLast[last] = sitesByLast[last] or {}
			table.insert(sitesByLast[last], site)
		end
	end

	local stack: { Frame } = {}
	local occurrences: { Occurrence } = {}
	local identSites: { IdentSite } = {}
	-- function name -> parameter -> the surfaces it reaches (directly or through another helper)
	local helpers: { [string]: { [number]: { [string]: boolean } } } = {}
	local forwards: { { from: string, param: number, to: string, arg: number } } = {}
	local moduleLast: string? = nil
	local bodies = 0
	local byte, sub, find, match = string.byte, string.sub, string.find, string.match
	local n = #src
	local broken = false

	local function lineBefore(at: number): string
		local j = at - 1
		while j > 0 and byte(src, j) ~= 10 do
			j -= 1
		end
		return sub(src, j + 1, at - 1)
	end

	-- The identifier chain right before position `at` (spaces skipped) and where it starts.
	local function chainBefore(at: number): (string?, number)
		local j = at - 1
		while j > 0 and SPACE[byte(src, j)] do
			j -= 1
		end
		local e = j
		while j > 0 and CHAIN[byte(src, j)] do
			j -= 1
		end
		if j == e then
			return nil, e + 1
		end
		return sub(src, j + 1, e), j + 1
	end

	-- The local a statement-level `=` at `eq` assigns (`local name: T =`, `name =`, `name ..=`).
	local function assignedAt(eq: number): string?
		local line = lineBefore(eq)
		local name = match(line, "^%s*local%s+([%a_][%w_]*)") or match(line, "^%s*([%a_][%w_]*)%s*%.?%.?$")
		return if name and not KEYWORDS[name] then name else nil
	end

	-- The local assigned by an `=` right before position `at` (nil for a comparison or a compound operator).
	local function assignedTo(at: number): string?
		local j = at - 1
		while j > 0 and SPACE[byte(src, j)] do
			j -= 1
		end
		if byte(src, j) ~= 61 then
			return nil
		end
		local b = byte(src, j - 1)
		if b == 61 or b == 126 or b == 60 or b == 62 or b == 43 or b == 45 or b == 42 or b == 47 then
			return nil
		end
		return assignedAt(j)
	end

	local function precededByFunction(at: number): boolean
		local j = at - 1
		while j > 0 and SPACE[byte(src, j)] do
			j -= 1
		end
		return j >= 8 and sub(src, j - 7, j) == "function" and not IDENT[byte(src, j - 8) or 32]
	end

	local function push(kind: string, at: number, start: number): Frame
		local frame: Frame = {
			kind = kind,
			at = at,
			callee = nil,
			arg = 1,
			start = start,
			field = nil,
			lits = {},
			lookup = nil,
			sites = nil,
			assign = nil,
			into = nil,
			wrapper = false,
			parts = nil,
			holes = 0,
			segment = start,
			name = nil,
			indent = nil,
			params = nil,
			stop = nil,
			last = nil,
			id = 0,
		}
		table.insert(stack, frame)
		return frame
	end

	-- The bodies around the top of the stack, innermost first.
	local function openBodies(): { Frame }
		local list = {}
		for d = #stack, 1, -1 do
			if stack[d].kind == "body" then
				table.insert(list, stack[d])
			end
		end
		return list
	end

	local function innermostBody(): Frame?
		for d = #stack, 1, -1 do
			if stack[d].kind == "body" then
				return stack[d]
			end
		end
		return nil
	end

	-- The surface of the field the table at depth `d` is at, for `key` when known (nil when none).
	local function fieldSurface(d: number, key: string?): string?
		local frame = stack[d]
		local name = frame.field
		if name == nil then
			return nil
		end
		local rules = FIELDS_BY_NAME[name]
		if rules == nil then
			return nil
		end
		local callee, arg = frame.callee, 1
		if callee == nil then
			local outer = stack[d - 1]
			if outer and outer.kind == "(" then
				callee, arg = outer.callee, outer.arg
			end
		end
		for _, rule in rules do
			if
				(rule.call == nil or (callee ~= nil and calleeIs(callee, rule.call) and rule.arg == arg))
				and (rule.under == nil or startsWith(path, rule.under))
				and (rule.tabs == nil or tabs)
				and (rule.key == nil or (key ~= nil and find(key, rule.key) ~= nil))
			then
				return rule.surface
			end
		end
		return nil
	end

	-- The site the current argument of a call is at (nil when none).
	local function callSurface(frame: Frame): string?
		local sites = frame.sites
		if sites == nil then
			return nil
		end
		for _, site in sites do
			if
				(site.arg == nil or site.arg == frame.arg)
				and (site.channel == nil or frame.lits[site.channel] == site.value)
			then
				return site.surface
			end
		end
		return nil
	end

	local function isReturn(at: number): boolean
		return find(lineBefore(at), "%f[%w_]return%f[^%w_]") ~= nil
	end

	-- Frames lo..hi of the stack are grouping parentheses, `(if b then "y" else "z")`: no callee, nothing kept.
	local function grouping(lo: number, hi: number): boolean
		for k = lo, hi do
			local frame = stack[k]
			if frame.kind ~= "(" or frame.callee ~= nil or frame.assign ~= nil then
				return false
			end
		end
		return true
	end

	-- Walks out from depth `from`: the surface the value there reaches, or the local (or function) it is kept in,
	-- or the call (last name) and argument it is passed to.
	local function walk(at: number, from: number, key: string?): (string?, string?, string?, number?)
		local d = from
		while d >= 1 do
			local frame = stack[d]
			local kind = frame.kind
			if kind == "(" then
				if frame.lookup then
					if frame.arg ~= frame.lookup then
						return nil, nil, nil, nil
					end
					if frame.assign then
						return nil, frame.assign, nil, nil
					end
				elseif frame.sites then
					return callSurface(frame), nil, nil, nil
				elseif frame.into then
					return nil, if frame.arg == 2 then frame.into else nil, nil, nil
				elseif frame.callee == nil or frame.wrapper then
					if frame.assign then
						return nil, frame.assign, nil, nil
					end
				else
					return nil, nil, lastName(frame.callee :: string), frame.arg
				end
			elseif kind == "{" then
				local surface = fieldSurface(d, key)
				if surface == nil and frame.field == nil and frame.assign then
					return nil, frame.assign, nil, nil -- local lines = { Text.get(...) }
				end
				return surface, nil, nil, nil
			elseif kind == "body" then
				local first = stack[d + 1]
				if isReturn(if first then first.at else at) then
					if frame.name then
						return nil, frame.name, nil, nil -- what a named function returns goes where its calls go
					end
					-- an anonymous callback's value goes where the callback goes: scope:Computed(function ... end)
				elseif first == nil or grouping(d + 1, from) then
					-- local key = if ... then "a" else "b", also with a branch in parentheses:
					-- if n == 1 then (if soon then "a" else "b") else ...
					return nil, frame.last, nil, nil
				else
					return nil, nil, nil, nil
				end
			elseif kind == "[" or kind == "fn" then
				return nil, nil, nil, nil
			end
			d -= 1
		end
		if stack[1] == nil then
			return nil, moduleLast, nil, nil
		end
		return nil, nil, nil, nil
	end

	-- `return false, <here>` or `return nil, <here>` on this line: an error the client shows as a toast.
	local function isErrorReturn(at: number): boolean
		local line = lineBefore(at)
		local between = match(line, "return%s+false%s*,(.*)$") or match(line, "return%s+nil%s*,(.*)$")
		if between == nil then
			return false
		end
		local depth = 0
		for k = 1, #between do
			local b = byte(between, k)
			if b == 40 or b == 123 or b == 91 then
				depth += 1
			elseif b == 41 or b == 125 or b == 93 then
				depth -= 1
			elseif b == 44 and depth == 0 then
				return false
			end
		end
		return depth == 0
	end

	local function record(keys: { string }, at: number)
		if #keys == 0 then
			return
		end
		if package then
			for _, key in keys do
				add(out.readers, key, package)
			end
		end
		if dev then
			return
		end
		local surface, bind, call, arg = walk(at, #stack, keys[1])
		if surface == nil and isErrorReturn(at) and not (#keys == 1 and TextScan.NOT_TOASTED[keys[1]]) then
			surface, bind, call = "toast", nil, nil
		end
		local body = innermostBody()
		local scope = if body then body.id else 0
		if bind and body and bind == body.name then
			scope = -1 -- a function's return value: its name is declared outside it
		end
		table.insert(occurrences, {
			keys = keys,
			surface = surface,
			bind = bind,
			body = scope,
			call = call,
			arg = arg,
		})
	end

	-- A key-like literal that is not a key: kept when it sits at a message site (T4 wants it to exist).
	local function recordMissing(value: string, at: number)
		if dev then
			return
		end
		local surface = walk(at, #stack, value)
		if surface and TextScan.MESSAGES[surface] then
			out.messages[value] = surface
		end
	end

	local function onLiteral(value: string, at: number, after: number)
		local top = stack[#stack]
		if top and top.kind == "(" and top.lits[top.arg] == nil then
			top.lits[top.arg] = value
		end
		if keySet[value] then
			record({ value }, at)
		elseif string.sub(value, -1) == "." and match(src, "^%s*%.%.[^%.]", after + 1) then
			if #value >= 3 then -- "stat." .. id
				record(keysMatching(value, "^" .. escape(value) .. "[%w_]+$"), at)
			end
		elseif match(value, "^[%a_][%w_]*%.[%w_%.]*[%w_]$") then
			recordMissing(value, at)
		end
	end

	local function onTemplate(frame: Frame)
		local parts = frame.parts :: { string }
		local at = frame.at
		if frame.holes == 0 then
			onLiteral(table.concat(parts), at, at)
			return
		end
		local prefix = parts[1]
		if #prefix < 3 or not find(prefix, ".", 1, true) or not match(table.concat(parts, "x"), "^[%w_%.]+$") then
			return
		end
		local pattern = {}
		for k, part in parts do
			table.insert(pattern, escape(part))
			if k < #parts then
				table.insert(pattern, "[%w_]+")
			end
		end
		record(keysMatching(prefix, "^" .. table.concat(pattern) .. "$"), at)
	end

	-- Reads template text from `j` to the next hole or the closing backtick; returns where code resumes.
	local function scanTemplate(frame: Frame, j: number): number
		while true do
			local k = find(src, "[`{\\]", j)
			if k == nil then
				broken = true
				return n + 1
			end
			local b = byte(src, k)
			if b == 92 then
				j = k + 2
			elseif b == 123 then
				table.insert(frame.parts :: { string }, sub(src, frame.segment, k - 1))
				frame.holes += 1
				push("hole", k, k + 1)
				return k + 1
			else
				table.insert(frame.parts :: { string }, sub(src, frame.segment, k - 1))
				table.remove(stack)
				onTemplate(frame)
				return k + 1
			end
		end
	end

	local function noteIdent(name: string, surface: string?, call: string?, arg: number?, anywhere: boolean?)
		if KEYWORDS[name] then
			return
		end
		local around = openBodies()
		table.insert(
			identSites,
			{ name = name, surface = surface, call = call, arg = arg, bodies = around, anywhere = anywhere == true }
		)
		-- a parameter passed on: its function is a helper of the file
		local body = around[1]
		if body and body.name and body.params then
			local index = table.find(body.params, name)
			if index then
				if surface then
					helpers[body.name] = helpers[body.name] or {}
					local byParam = helpers[body.name] :: { [number]: { [string]: boolean } }
					byParam[index] = byParam[index] or {}
					byParam[index][surface] = true
				elseif call and arg then
					table.insert(forwards, { from = body.name, param = index, to = call, arg = arg })
				end
			end
		end
	end

	-- A site's argument or field value names a local: a bare local, table.concat(local), a local function's call,
	-- or what a callback returns (scope:Computed(function(use) ... return lines end), matched in any body).
	local function noteValue(value: string, surface: string)
		local name = match(value, "^%s*([%a_][%w_]*)%s*$")
			or match(value, "^%s*table%.concat%(%s*([%a_][%w_]*)")
			or match(value, "^%s*([%a_][%w_]*)%s*%(")
		if name then
			noteIdent(name, surface, nil, nil, false)
		end
		if find(value, "function", 1, true) then
			for returned in string.gmatch(value, "return%s+([%a_][%w_]*)%s*[\n;]") do
				noteIdent(returned, surface, nil, nil, true)
			end
			for returned in string.gmatch(value, "return%s+table%.concat%(%s*([%a_][%w_]*)") do
				noteIdent(returned, surface, nil, nil, true)
			end
		end
	end

	-- A call argument or a table field ends at `at` (its frame on top of the stack).
	local function finishValue(frame: Frame, at: number)
		if dev then
			return
		end
		if frame.kind == "(" then
			if frame.sites then
				local surface = callSurface(frame)
				if surface and surface ~= "" then
					noteValue(sub(src, frame.start, at - 1), surface)
				end
			elseif frame.lookup then
				if frame.arg == frame.lookup then
					local name = match(sub(src, frame.start, at - 1), "^%s*([%a_][%w_]*)%s*$")
					if name then
						-- Text.now(key): the local takes the surface the looked-up text reaches
						local surface, _, call, arg = walk(at, #stack, nil)
						if (surface and surface ~= "") or call then
							noteIdent(name, if surface ~= "" then surface else nil, call, arg)
						end
					end
				end
			elseif frame.callee and not frame.wrapper and not frame.into then
				local name = match(sub(src, frame.start, at - 1), "^%s*([%a_][%w_]*)%s*$")
				if name then
					noteIdent(name, nil, lastName(frame.callee), frame.arg)
				end
			end
		elseif frame.kind == "{" and frame.field and FIELDS_BY_NAME[frame.field] then
			local surface = fieldSurface(#stack)
			if surface and surface ~= "" then
				noteValue(sub(src, frame.start, at - 1), surface)
			end
		end
	end

	local function countCall(frame: Frame)
		local sites = frame.sites
		if sites == nil then
			return
		end
		for _, site in sites do
			if site.surface ~= "" and (site.channel == nil or frame.lits[site.channel] == site.value) then
				local name = if site.surface == "toast"
					then (if server then "toast server" else "toast client")
					else site.surface
				out.calls[name] = (out.calls[name] or 0) + 1
				return
			end
		end
	end

	local function close(kind: string)
		local top = stack[#stack]
		if top and top.kind == kind then
			table.remove(stack)
			return
		end
		broken = true
		for d = #stack, 1, -1 do -- recover: drop frames down to the nearest one of this kind
			if stack[d].kind == kind then
				for _ = #stack, d, -1 do
					table.remove(stack)
				end
				return
			end
		end
	end

	-- A function's parameters closed at `p`: its body runs to the first `end` at the indentation of the line the
	-- function starts on (or to an `end` on this same line).
	local function openBody(fn: Frame, p: number)
		local text = sub(src, fn.start, p - 1)
		text = string.gsub(text, "%b{}", "")
		text = string.gsub(text, "%b()", "")
		text = string.gsub(text, "%b<>", "")
		local params = {}
		for part in string.gmatch(text, "[^,]+") do
			table.insert(params, match(part, "^%s*([%a_][%w_]*)") or "")
		end
		local lineEnd = find(src, "\n", p, true) or n
		local stop: number? = nil
		local same = find(sub(src, p + 1, lineEnd), "%f[%w_]end%f[^%w_]")
		if same then
			stop = p + same
		else
			local s = find(src, "\n" .. (fn.indent :: string) .. "end", lineEnd, true)
			if s and not IDENT[byte(src, s + #(fn.indent :: string) + 4) or 32] then
				stop = s + #(fn.indent :: string) + 1
			end
		end
		if stop == nil then
			broken = true
			return
		end
		bodies += 1
		local body = push("body", p, p + 1)
		body.name = fn.name
		body.params = params
		body.stop = stop
		body.id = bodies
	end

	local i = 1
	while true do
		local p = find(src, "[%-\"'`%[%]{}%(%),;=]", i)
		if p == nil then
			break
		end
		-- leave the function bodies that ended before here
		while true do
			local top = stack[#stack]
			if top and top.kind == "body" and (top.stop :: number) < p then
				table.remove(stack)
			else
				break
			end
		end
		local c = byte(src, p)
		if c == 45 then -- -
			if byte(src, p + 1) == 45 then
				local level = match(src, "^%-%-%[(=*)%[", p)
				local e: number?
				if level then
					local _, close = find(src, "]" .. level .. "]", p, true)
					e = close
				else
					e = find(src, "\n", p, true)
				end
				i = if e then e + 1 else n + 1
			else
				i = p + 1
			end
		elseif c == 34 or c == 39 then -- " '
			local j = p + 1
			local e = n
			while true do
				local k = find(src, if c == 34 then '[\\"\n]' else "[\\'\n]", j)
				if k == nil then
					broken = true
					break
				end
				local b = byte(src, k)
				if b == 92 then
					j = k + 2
				else
					if b == 10 then
						broken = true
					end
					e = k - 1
					break
				end
			end
			onLiteral(sub(src, p + 1, e), p, e + 1)
			i = e + 2
		elseif c == 96 then -- `
			local frame = push("`", p, p + 1)
			frame.parts = {}
			i = scanTemplate(frame, p + 1)
		elseif c == 91 then -- [
			local level = match(src, "^%[(=*)%[", p)
			if level then
				local _, e = find(src, "]" .. level .. "]", p, true)
				i = if e then e + 1 else n + 1
			else
				push("[", p, p + 1)
				i = p + 1
			end
		elseif c == 93 then -- ]
			close("[")
			i = p + 1
		elseif c == 123 then -- {
			local chain, chainStart = chainBefore(p)
			local outer = stack[#stack]
			local frame = push("{", if chain then chainStart else p, p + 1)
			if chain and not KEYWORDS[chain] and not match(chain, "^[%d%.:]") then
				frame.callee = chain -- f { ... }
			elseif chain == nil and (outer == nil or outer.kind ~= "{") then
				frame.assign = assignedTo(p)
			end
			i = p + 1
		elseif c == 125 then -- }
			local top = stack[#stack]
			if top and top.kind == "hole" then
				table.remove(stack)
				local template = stack[#stack]
				if template and template.kind == "`" then
					template.segment = p + 1
					i = scanTemplate(template, p + 1)
				else
					broken = true
					i = p + 1
				end
			else
				if top and top.kind == "{" then
					finishValue(top, p)
				end
				close("{")
				i = p + 1
			end
		elseif c == 40 then -- (
			local chain, chainStart = chainBefore(p)
			local outer = stack[#stack]
			local frame = push("(", if chain then chainStart else p, p + 1)
			if chain then
				if chain == "function" or precededByFunction(chainStart) then
					frame.kind = "fn"
					local line = lineBefore(chainStart)
					frame.indent = match(line, "^[ \t]*") or ""
					if chain ~= "function" then
						frame.name = lastName(chain)
					elseif outer and outer.kind == "{" then
						frame.name = outer.field -- toast = function(player, key) ... end
					else
						frame.name = assignedTo(chainStart) -- local toast = function(player, key) ... end
					end
				elseif not KEYWORDS[chain] then
					frame.callee = chain
					local last = lastName(chain)
					frame.lookup = TextScan.LOOKUPS[chain]
					frame.wrapper = TextScan.WRAPPERS[last] == true
					local candidates = sitesByLast[last]
					if candidates and frame.lookup == nil then
						local sites = {}
						for _, site in candidates do
							if calleeIs(chain, site.call) then
								table.insert(sites, site)
							end
						end
						if #sites > 0 then
							frame.sites = sites
						end
					end
					if chain == "table.insert" then
						frame.into = match(src, "^%s*([%a_][%w_]*)%s*,", p + 1)
					end
				end
			end
			if frame.kind == "(" and (outer == nil or outer.kind ~= "{") then
				frame.assign = assignedTo(if chain then chainStart else p)
			end
			i = p + 1
		elseif c == 41 then -- )
			local top = stack[#stack]
			if top and top.kind == "fn" then
				table.remove(stack)
				openBody(top, p)
			else
				if top and top.kind == "(" then
					finishValue(top, p)
					countCall(top)
				end
				close("(")
			end
			i = p + 1
		elseif c == 44 or c == 59 then -- , ;
			local top = stack[#stack]
			if top and (top.kind == "(" or top.kind == "{") then
				finishValue(top, p)
				top.arg += 1
				top.field = nil
				top.start = p + 1
			end
			i = p + 1
		else -- =
			local top = stack[#stack]
			local nextByte = byte(src, p + 1)
			if nextByte == 61 then
				i = p + 2
			else
				local prev = byte(src, p - 1)
				local compare = prev == 126 or prev == 60 or prev == 62 or prev == 61
				if top and top.kind == "{" and not compare then
					local j = p - 1
					while j > 0 and SPACE[byte(src, j)] do
						j -= 1
					end
					local e = j
					while j > 0 and IDENT[byte(src, j)] do
						j -= 1
					end
					top.field = if e > j then sub(src, j + 1, e) else nil
					top.start = p + 1
				elseif (top == nil or top.kind == "body") and not compare then
					local name = assignedAt(p)
					if top then
						top.last = name
					else
						moduleLast = name
					end
				end
				i = p + 1
			end
		end
	end
	while stack[#stack] and stack[#stack].kind == "body" do
		table.remove(stack)
	end
	if broken or #stack > 0 then
		table.insert(out.health, path)
	end

	-- Helpers that pass a parameter on to another helper reach what that one reaches.
	local changed = true
	while changed do
		changed = false
		for _, edge in forwards do
			local target = helpers[edge.to] and helpers[edge.to][edge.arg]
			if target then
				helpers[edge.from] = helpers[edge.from] or {}
				local byParam = helpers[edge.from]
				byParam[edge.param] = byParam[edge.param] or {}
				for surface in target do
					if not byParam[edge.param][surface] then
						byParam[edge.param][surface] = true
						changed = true
					end
				end
			end
		end
	end

	-- The surfaces a local declared in body `body` reaches (a site in that body or one inside it that does not
	-- declare a parameter of the same name).
	local function localSurfaces(name: string, body: number): { [string]: boolean }
		local found = {}
		for _, site in identSites do
			if site.name == name then
				local visible = body == 0 or body == -1 or site.anywhere
				for _, around in if visible then {} else site.bodies do
					if around.id == body then
						visible = true
						break
					end
					if around.params and table.find(around.params, name) then
						visible = false
						break
					end
				end
				if visible then
					if site.surface then
						found[site.surface] = true
					elseif site.call and site.arg then
						local target = helpers[site.call] and helpers[site.call][site.arg]
						for surface in target or {} do
							found[surface] = true
						end
					end
				end
			end
		end
		return found
	end

	for _, occurrence in occurrences do
		local surfaces: { [string]: boolean } = {}
		local reached = false
		if occurrence.surface then
			reached = true
			if occurrence.surface ~= "" then
				surfaces[occurrence.surface] = true
			end
		elseif occurrence.call and occurrence.arg then
			local target = helpers[occurrence.call] and helpers[occurrence.call][occurrence.arg]
			for surface in target or {} do
				reached = true
				surfaces[surface] = true
			end
		elseif occurrence.bind then
			for surface in localSurfaces(occurrence.bind, occurrence.body) do
				reached = true
				surfaces[surface] = true
			end
		end
		if not reached and fallback then
			surfaces[fallback] = true
		end
		for surface in surfaces do
			for _, key in occurrence.keys do
				if not under(key, TextScan.DEV_KEYS) then
					add(out.surfaces, key, surface)
					if TextScan.MESSAGES[surface] then
						add(out.readers, key, "B")
						if #occurrence.keys == 1 then
							out.messages[key] = surface
						end
					end
				end
			end
		end
	end
end

local function listFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			listFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

local cache: Scan? = nil

-- The scan of the whole code (once per run): surfaces and readers of every key, with the fixtures' rules applied.
function TextScan.scan(): Scan
	if cache then
		return cache
	end
	local files: { string } = {}
	for _, root in TextScan.ROOTS do
		listFiles(root, files)
	end
	table.sort(files)
	local out: Scan = { files = 0, surfaces = {}, readers = {}, messages = {}, calls = {}, health = {} }
	for _, path in files do
		if not under(path, TextScan.SKIP) or under(path, TextScan.KEEP) then
			out.files += 1
			scanFile(path, fs.readFile(path), out, pl :: any)
		end
	end
	local fixtures = TextScan.fixtures()
	for _, package in TextScan.PACKAGES do
		for _, rule in fixtures[package].rules do
			for _, key in KEYS do
				if string.find(key, rule.pattern) and not under(key, TextScan.DEV_KEYS) then
					local set = out.surfaces[key] or {}
					out.surfaces[key] = set
					set[rule.surface] = true
				end
			end
		end
	end
	cache = out
	return out
end

-- The package that owns `key`: the first with a file that reads it, else the first whose rule matches it, else E.
function TextScan.owner(key: string): string
	local readers = TextScan.scan().readers[key]
	if readers then
		for _, package in TextScan.PACKAGES do
			if readers[package] then
				return package
			end
		end
	end
	local fixtures = TextScan.fixtures()
	for _, package in TextScan.PACKAGES do
		for _, rule in fixtures[package].rules do
			if string.find(key, rule.pattern) then
				return package
			end
		end
	end
	return "E"
end

-- The surfaces of `key`, strictest (fewest characters) first.
function TextScan.surfaces(key: string): { string }
	local list = {}
	for surface in TextScan.scan().surfaces[key] or {} do
		table.insert(list, surface)
	end
	table.sort(list, function(a: string, b: string): boolean
		local ca, cb = TextCaps.SURFACES[a].chars, TextCaps.SURFACES[b].chars
		if ca ~= cb then
			return ca < cb
		end
		return a < b
	end)
	return list
end

-- T2: surfaces that must not teach the controls (no control words, no "(K)" key hints).
TextScan.PLAIN = table.freeze({
	toast = true,
	banner = true,
	alert = true,
	prompt = true,
	hudLine = true,
	hudTip = true,
})
TextScan.CONTROL_WORDS = table.freeze({ "kliknij", "najedź", "przeciągnij", "prawy klik" })
TextScan.CONTROL_PATTERNS =
	table.freeze({ "%f[%a]click", "%f[%a]hover", "%f[%a]drag%f[^%a]", "%f[%a]drags%f[^%a]", "%f[%a]dragg" })
TextScan.KEY_HINTS = table.freeze({
	"%(%u%)",
	"%(F%d%d?%)",
	"%({key}%)",
	"%(Tab%)",
	"%(Esc%)",
	"%(Alt%)",
	"%(Shift%)",
	"%(Ctrl%)",
	"%(Enter%)",
	"%(Spacja%)",
	"%(Space%)",
})

-- The control word or key hint in `text` (nil when none).
function TextScan.control(text: string): string?
	local lower = string.lower(text)
	for _, word in TextScan.CONTROL_WORDS do
		if string.find(lower, word, 1, true) then
			return word
		end
	end
	for _, pattern in TextScan.CONTROL_PATTERNS do
		local found = string.match(lower, pattern .. "%a*")
		if found then
			return found
		end
	end
	for _, pattern in TextScan.KEY_HINTS do
		local found = string.match(text, pattern)
		if found then
			return found
		end
	end
	return nil
end

TextScan.EM_DASH = "—"

export type Violation = { owner: string, surface: string, chars: number, reason: string }

-- Every key whose pl or en text breaks a cap of its surfaces (T1) or a universal rule (T2), with its owner.
function TextScan.violations(): { [string]: Violation }
	local out: { [string]: Violation } = {}
	local texts: { [string]: { [string]: string } } = { pl = pl :: any, en = en :: any }
	for _, key in KEYS do
		local reasons: { string } = {}
		local failed: string? = nil
		local chars = 0
		for _, lang in { "pl", "en" } do
			local text = texts[lang][key]
			if text then
				chars = math.max(chars, TextCaps.chars(TextCaps.expand(text)))
			end
		end
		local dash = false
		for _, lang in { "pl", "en" } do
			local text = texts[lang][key]
			if text and string.find(text, TextScan.EM_DASH, 1, true) then
				dash = true
			end
		end
		local surfaces = TextScan.surfaces(key)
		for _, surface in surfaces do
			for _, lang in { "pl", "en" } do
				local text = texts[lang][key]
				if text then
					local ok, why = TextCaps.check(surface, TextCaps.expand(text))
					if not ok then
						failed = failed or surface
						table.insert(reasons, `{surface} {lang} {why}`)
						break
					end
				end
			end
			if TextScan.PLAIN[surface] then
				for _, lang in { "pl", "en" } do
					local text = texts[lang][key]
					local word = text and TextScan.control(text)
					if word then
						failed = failed or surface
						table.insert(reasons, `{surface} {lang} control {word}`)
						break
					end
				end
			end
		end
		if dash then
			table.insert(reasons, "em dash")
		end
		if #reasons > 0 then
			out[key] = {
				owner = TextScan.owner(key),
				surface = failed or surfaces[1] or "-",
				chars = chars,
				reason = table.concat(reasons, "; "),
			}
		end
	end
	return out
end

return TextScan
