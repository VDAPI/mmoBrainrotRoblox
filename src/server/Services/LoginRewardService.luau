--!strict
-- Daily login reward (S100, docs/DESIGN-15.md §5): a 7-day streak per account in UTC days (account.login, read by
-- the client to show the window). The character in the world claims the day (ClaimLoginReward) and gets it scaled
-- by its level; day 7 adds a Unique / Heroic item for its level and class, bound to it. A full backpack never
-- blocks the claim: the whole reward goes as one parcel to that character (the mark is written first and undone
-- when the mail fails, like CodeService). The streak, the day and the contents come from Logic/LoginReward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Analytics = require(script.Parent.Parent.Analytics)
local Clock = require(Shared.Util.Clock)
local Data = require(Shared.Data.LoginReward)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local LoginReward = require(Shared.Logic.LoginReward)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

type ItemInstance = Types.ItemInstance

local log = Log.new("LoginRewardService")

local LoginRewardService = {
	Name = "LoginRewardService",
	Deps = { "DataService", "PlayerStateService", "InventoryService", "MailService" },
}

export type Result = { day: number, gold: number, items: { ItemInstance }, mailed: boolean }

local DataService: any
local PlayerStateService: any
local InventoryService: any
local MailService: any

local rng = Rng.new()
local busy: { [Player]: boolean } = {}

-- Today's UTC day (the /time offset included, like the daily contracts).
function LoginRewardService.Today(): number
	return Time.dayNumber(Clock.now())
end

local function stateOf(player: Player): LoginReward.State?
	local account = PlayerStateService.Get(player, { "account" })
	if not account then
		return nil
	end
	return LoginReward.sanitize(account.login)
end

function LoginRewardService.State(player: Player): LoginReward.State?
	return stateOf(player)
end

function LoginRewardService.Status(player: Player): LoginReward.Status?
	local state = stateOf(player)
	return if state then LoginReward.status(state, LoginRewardService.Today()) else nil
end

-- Admin (/loginset, /loginnext): writes a sanitized streak.
function LoginRewardService.SetState(player: Player, state: LoginReward.State)
	PlayerStateService.Set(player, { "account", "login" }, LoginReward.sanitize(state))
end

-- The reward of `day` for `char` as item instances (stacks, the rolled chest item bound to the character).
local function build(char: Types.CharacterData, day: number): (number, { ItemInstance })
	local contents = LoginReward.contents(day, char.level, char.class)
	local items: { ItemInstance } = {}
	for _, entry in contents.items do
		table.insert(items, ItemRoll.makeStack(entry.id, entry.n, InventoryService.NewUid()))
	end
	if contents.chest then
		local drop = LoginReward.rollChest(char.level, char.class, rng)
		if drop then
			local item =
				ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, InventoryService.NewUid(), drop.forClass)
			item.bound = Data.chest.bound
			table.insert(items, item)
		else
			local fallback = LoginReward.chestFallback(char.level)
			log:warn(
				"no chest item at level %d for %s: %s x%d instead",
				char.level,
				char.class,
				fallback.id,
				fallback.n
			)
			table.insert(items, ItemRoll.makeStack(fallback.id, fallback.n, InventoryService.NewUid()))
		end
	end
	return contents.gold, items
end

local function giveNow(player: Player, gold: number, items: { ItemInstance })
	if gold > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
			return current + gold
		end)
		Analytics.gold(player, gold, balance, "login")
	end
	for _, item in items do
		local leftover = InventoryService.AddItem(player, item)
		if leftover > 0 then
			log:warn("%s: %d x %s did not fit after CanFit", player.Name, leftover, item.id)
		end
	end
end

-- The mailed path (full backpack): mark first, mail, undo the mark when the mail fails. Yields.
local function giveByMail(
	player: Player,
	char: Types.CharacterData,
	before: LoginReward.State,
	after: LoginReward.State,
	day: number,
	gold: number,
	items: { ItemInstance }
): (boolean, string?)
	PlayerStateService.Set(player, { "account", "login" }, after)
	local sent, err = MailService.Send(player.UserId, {
		from = "system",
		subjectKey = "mail.subject.login",
		args = { day = day },
		gold = gold,
		items = items,
		charId = char.id,
	})
	if not sent then
		log:warn("login reward day %d for %s not mailed: %s", day, player.Name, tostring(err))
		if player.Parent ~= nil and PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "account", "login" }, before)
		end
		return false, "login.error.mail"
	end
	return true, nil
end

function LoginRewardService.Claim(player: Player): (boolean, string?, Result?)
	if busy[player] then
		return false, "login.error.busy"
	end
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not char or PlayerStateService.GetPhase(player) ~= "playing" then
		return false, "error.internal"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local before = stateOf(player)
	if not before then
		return false, "error.internal"
	end
	local after, day = LoginReward.claim(before, LoginRewardService.Today())
	if not after or not day then
		return false, "login.error.claimed"
	end
	local gold, items = build(char, day)
	local mailed = false
	if InventoryService.CanFit(player, items) then
		PlayerStateService.Set(player, { "account", "login" }, after)
		giveNow(player, gold, items)
	else
		busy[player] = true
		local ok, err = giveByMail(player, char, before, after, day, gold, items)
		busy[player] = nil
		if not ok then
			return false, err
		end
		mailed = true
		if player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "login.mailed", nil, "info")
		end
	end
	if player.Parent ~= nil then
		DataService.Save(player)
		Analytics.custom(player, "LoginReward", day)
	end
	return true, nil, { day = day, gold = gold, items = items, mailed = mailed }
end

function LoginRewardService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	MailService = registry.Get("MailService")
end

function LoginRewardService.Start()
	Net.Handle("ClaimLoginReward", function(player: Player)
		return LoginRewardService.Claim(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return LoginRewardService
