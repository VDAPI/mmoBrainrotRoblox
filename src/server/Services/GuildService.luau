--!strict
-- Guilds across servers (DESIGN §19). The record lives in the Guilds DataStore (Guild/Store) and every
-- change is one UpdateAsync with the rules of Logic/Guild inside the callback; the server that made the
-- change updates its cache at once and tells the others through MessagingService (Guild/Bus), which then
-- re-read the record. Servers cache only guilds with members online on them.
--
-- Members see the state branch `guild` (record + member list with online/server), get the skill bonuses
-- through the "guild" modifier source (EXP, gold, drop, potion discount), the guild tag above their head
-- (model attribute GuildTag), a guild TextChannel whose lines are relayed to the other servers, and
-- system lines (joined, promoted, upgraded) in it. Characters keep `guildId`; when entering the world the
-- membership is checked against the record (kicked or disbanded while offline -> cleared).
--
-- S159g: guild EXP and weekly goals (Logic/GuildProgress): monster kills (CombatService.MonsterKilled) and QuestEvents of
-- members become activities; the guild EXP of a character is capped per UTC day (character.guildWork); each server
-- collects them per guild and writes them every Rules.flushSeconds (+ jitter) in one quiet UpdateAsync (no change
-- notice unless a level, a goal or the rally came of it). The bank (Logic/GuildBank): gold out of the treasury and the
-- item vault with rank rights and daily limits, the guild log, rank rights edited by the leader, the banner.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Bus = require(script.Parent.Parent.Guild.Bus)
local Runtime = require(script.Parent.Parent.Guild.Runtime)
local Ignores = require(script.Parent.Parent.Social.Ignores) -- S133
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Config = require(Shared.Config)
local Guild = require(Shared.Logic.Guild)
local GuildBank = require(Shared.Logic.GuildBank)
local GuildProgress = require(Shared.Logic.GuildProgress)
local GuildProgressData = require(Shared.Data.GuildProgress)
local GuildSkills = require(Shared.Data.GuildSkills)
local Time = require(Shared.Logic.Time)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Store = require(script.Parent.Parent.Guild.Store)
local Types = require(Shared.Types)

local log = Log.new("GuildService")

type GuildData = Guild.GuildData

local GuildService = {
	Name = "GuildService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"StatService",
		"LevelService",
		"NpcService",
		"InventoryService",
	},
}

local Rules = GuildSkills.Rules

local Registry: any
local LeaderboardService: any
local DataService: any
local PlayerStateService: any
local CharacterService: any
local StatService: any
local LevelService: any
local NpcService: any
local InventoryService: any

local cache = Runtime.cache
local guildOf = Runtime.guildOf
local character = Runtime.character
local memberKey = Runtime.memberKey
local setGuildId = Runtime.setGuildId
local attach = Runtime.attach
local detach = Runtime.detach
local notify = Runtime.notify

-- S125: the guild board, lazily (LeaderboardService takes this service lazily too; S60 pattern, never in Init).
local function leaderboard(): any
	if LeaderboardService == nil and Registry then
		local ok, service = pcall(Registry.Get, "LeaderboardService")
		LeaderboardService = if ok then service else false
	end
	return LeaderboardService or nil
end

-- S125: the guild board entry follows every record this server wrote (never Runtime.setData: the messages of other
-- servers would write the same entry from every server).
local function submitGuild(data: GuildData?)
	local lb = leaderboard()
	if lb and data then
		local ok, err = pcall(lb.SubmitGuild, data)
		if not ok then
			log:warn("guild board entry of %s failed: %s", data.id, tostring(err))
		end
	end
end

-- One UpdateAsync with a Logic/Guild mutation (Runtime.mutate), then the guild board entry (S125).
local function mutate(guildId: string, fn: (guild: GuildData?) -> (boolean, string?)): (boolean, string?, GuildData?)
	local ok, err, data = Runtime.mutate(guildId, fn)
	if ok and data then
		submitGuild(data)
	end
	return ok, err, data
end

local invites: { [Player]: { guildId: string, from: Player, expiresAt: number } } = {}
local busy: { [Player]: boolean } = {}

-- Helpers -----------------------------------------------------------------------------------------

local function memberInfo(player: Player, char: Types.CharacterData): Guild.Member
	return {
		userId = player.UserId,
		charId = char.id,
		name = char.name,
		class = char.class,
		level = char.level,
		rank = "member",
		joinedAt = os.time(),
		contributed = 0,
	}
end

local function nameOf(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

-- One request at a time per player (the store calls yield).
local function withLock(player: Player, fn: () -> (boolean, string?)): (boolean, string?)
	if busy[player] then
		return false, "error.busy"
	end
	busy[player] = true
	local ok, result, err = pcall(fn)
	busy[player] = nil
	if not ok then
		log:error("request failed for %s: %s", player.Name, tostring(result))
		return false, "error.internal"
	end
	return result, err
end

-- Roblox text filter for names, tags and the message of the day. Yields. Returns the filtered text or nil.
local function filter(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		log:warn("text filter failed: %s", tostring(result))
		return nil
	end
	return result
end

function GuildService.GuildOf(player: Player): string?
	return guildOf[player]
end

function GuildService.SameGuild(a: Player, b: Player): boolean
	local id = guildOf[a]
	return id ~= nil and guildOf[b] == id
end

-- Whether the guild of `player` protects its members from each other (default on).
function GuildService.Protection(player: Player): boolean
	local entry = guildOf[player] and cache[guildOf[player]]
	return not entry or entry.data.settings.guildPvpProtection ~= false
end

function GuildService.Data(player: Player): GuildData?
	local entry = guildOf[player] and cache[guildOf[player]]
	return if entry then entry.data else nil
end

-- Admin: runs a raw change on the player's guild record (no permission checks). Yields.
function GuildService.AdminMutate(player: Player, fn: (guild: GuildData) -> ()): boolean
	local guildId = guildOf[player]
	if not guildId then
		return false
	end
	return (
		mutate(guildId, function(guild: GuildData?)
			if not guild or guild.disbanded then
				return false, "guild.error.gone"
			end
			fn(guild)
			guild.version += 1
			return true, nil
		end)
	)
end

-- Operations --------------------------------------------------------------------------------------

local function myGuild(player: Player): (string?, string?)
	local guildId, key = guildOf[player], memberKey(player)
	if not guildId or not key or not cache[guildId] then
		return nil, nil
	end
	return guildId, key
end

local function create(player: Player, name: string, tag: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if char.guildId then
		return false, "guild.error.inGuild"
	end
	if not NpcService.NearService(player, "guild") then
		return false, "npc.error.tooFar"
	end
	tag = string.upper(tag)
	local ok, err = Guild.validateName(name)
	if not ok then
		return false, err
	end
	ok, err = Guild.validateTag(tag)
	if not ok then
		return false, err
	end
	if char.level < Rules.createLevel then
		return false, "guild.error.level"
	end
	if char.gold < Rules.createCost then
		return false, "shop.error.gold"
	end
	if filter(player, name) ~= name or filter(player, tag) ~= tag then
		return false, "guild.error.filtered"
	end
	local id = string.gsub(HttpService:GenerateGUID(false), "-", "")
	local nameKey, tagKey = Guild.nameKey(name), Guild.tagKey(tag)
	ok, err = Store.reserveNames(nameKey, tagKey, id)
	if not ok then
		return false, err
	end
	-- The checks above yielded: re-check before taking the gold.
	char = character(player)
	if not char or char.guildId or char.gold < Rules.createCost then
		Store.releaseNames(nameKey, tagKey, id)
		return false, "shop.error.gold"
	end
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold - Rules.createCost
	end)
	local record =
		Guild.create({ id = id, name = name, tag = tag, founder = memberInfo(player, char), now = os.time() })
	local written, data, writeErr = Store.update(id, function(current: any?)
		if current ~= nil then
			return nil, "guild.error.store"
		end
		return record, nil
	end)
	if not written or not data then
		PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold + Rules.createCost
		end)
		Store.releaseNames(nameKey, tagKey, id)
		return false, writeErr or "guild.error.store"
	end
	setGuildId(player, id)
	DataService.Save(player)
	attach(player, data)
	submitGuild(data)
	notify(id, "guild.sys.founded", { name = char.name, guild = name })
	log:info("%s founded guild '%s' [%s] (%s)", player.Name, name, tag, id)
	return true, nil
end

local function findByName(name: string): Player?
	local wanted = string.lower(name)
	for _, player in Players:GetPlayers() do
		local char = character(player)
		if (char and string.lower(char.name) == wanted) or string.lower(player.Name) == wanted then
			return player
		end
	end
	return nil
end

local function invite(player: Player, target: Player?): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local entry = cache[guildId]
	local rank = entry.data.members[key] and entry.data.members[key].rank
	if not Guild.can(rank, "invite") then
		return false, "guild.error.permission"
	end
	if not target or target == player or PlayerStateService.GetPhase(target) ~= "playing" then
		return false, "guild.error.notFound"
	end
	local ignored = Ignores.check(player, target) -- S133
	if ignored then
		return false, ignored
	end
	local targetChar = character(target)
	if not targetChar or targetChar.guildId then
		return false, "guild.error.targetInGuild"
	end
	if Guild.memberCount(entry.data) >= Guild.memberLimit(entry.data.skills) then
		return false, "guild.error.full"
	end
	local pending = invites[target]
	if pending and pending.expiresAt > os.clock() then
		return false, "party.error.pending"
	end
	invites[target] = { guildId = guildId, from = player, expiresAt = os.clock() + Rules.inviteSeconds }
	Net.Fire(target, "GuildInvited", entry.data.name, entry.data.tag, nameOf(player), Rules.inviteSeconds)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local pending = invites[player]
	invites[player] = nil
	if not pending or pending.expiresAt < os.clock() then
		return false, "party.error.expired"
	end
	if not accept then
		if pending.from.Parent then
			Net.Fire(pending.from, "Toast", "guild.declined", { name = nameOf(player) }, "info")
		end
		return true, nil
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if char.guildId then
		return false, "guild.error.inGuild"
	end
	local info = memberInfo(player, char)
	local ok, err, data = mutate(pending.guildId, function(guild)
		return Guild.join(guild, info, os.time())
	end)
	if not ok or not data then
		return false, err
	end
	setGuildId(player, data.id)
	DataService.Save(player)
	attach(player, data)
	notify(data.id, "guild.sys.joined", { name = char.name })
	return true, nil
end

local function leave(player: Player): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	Runtime.setLeaving(player, true)
	local ok, err = mutate(guildId, function(guild)
		return Guild.leave(guild, key)
	end)
	Runtime.setLeaving(player, false)
	if not ok then
		return false, err
	end
	detach(player)
	setGuildId(player, nil)
	notify(guildId, "guild.sys.left", { name = nameOf(player) })
	return true, nil
end

local function memberName(guildId: string, key: string): string
	local entry = cache[guildId]
	local member = entry and entry.data.members[key]
	return if member then member.name else "?"
end

local function kick(player: Player, targetKey: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local name = memberName(guildId, targetKey)
	local ok, err = mutate(guildId, function(guild)
		return Guild.kick(guild, key, targetKey)
	end)
	if ok then
		notify(guildId, "guild.sys.kicked", { name = name, by = nameOf(player) })
	end
	return ok, err
end

local function setRank(player: Player, targetKey: string, rank: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local ok, err = mutate(guildId, function(guild)
		return Guild.setRank(guild, key, targetKey, rank)
	end)
	if ok then
		-- S159g: four ranks, one line ("@" = localized by the viewer)
		notify(guildId, "guild.sys.rank", { name = memberName(guildId, targetKey), rank = `@guild.rank.{rank}` })
	end
	return ok, err
end

local function transfer(player: Player, targetKey: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local ok, err = mutate(guildId, function(guild)
		return Guild.transfer(guild, key, targetKey)
	end)
	if ok then
		notify(guildId, "guild.sys.leader", { name = memberName(guildId, targetKey) })
	end
	return ok, err
end

-- Marks the record disbanded and frees its name and tag.
local function disbandRecord(guildId: string, fn: (guild: GuildData?) -> (boolean, string?)): (boolean, string?)
	local entry = cache[guildId]
	local name, tag = if entry then entry.data.name else nil, if entry then entry.data.tag else nil
	if not name then
		local ok, data = Store.get(guildId)
		if ok and data then
			name, tag = data.name, data.tag
		end
	end
	local ok, err = mutate(guildId, fn)
	if not ok then
		return false, err
	end
	if name and tag then
		Store.releaseNames(Guild.nameKey(name), Guild.tagKey(tag), guildId)
	end
	log:info("guild %s (%s) disbanded", tostring(name), guildId)
	return true, nil
end

local function disband(player: Player, confirmName: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	if confirmName ~= cache[guildId].data.name then
		return false, "error.confirmMismatch"
	end
	return disbandRecord(guildId, function(guild)
		return Guild.disband(guild, key)
	end)
end

local function deposit(player: Player, amount: number): (boolean, string?)
	local guildId, key = myGuild(player)
	local char = character(player)
	if not guildId or not key or not char then
		return false, "guild.error.none"
	end
	if amount < 1 or amount > Rules.maxDeposit then
		return false, "guild.error.amount"
	end
	if char.gold < amount then
		return false, "shop.error.gold"
	end
	-- Gold leaves first (no yield between check and write); refunded if the guild write fails.
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold - amount
	end)
	local ok, err = mutate(guildId, function(guild)
		return Guild.deposit(guild, key, amount)
	end)
	if not ok then
		PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold + amount
		end)
		return false, err
	end
	DataService.Save(player)
	notify(guildId, "guild.sys.deposit", { name = char.name, amount = amount })
	return true, nil
end

local function upgrade(player: Player, skillId: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local ok, err, data = mutate(guildId, function(guild)
		return Guild.upgrade(guild, key, skillId)
	end)
	if ok and data then
		local def = GuildSkills.get(skillId)
		notify(guildId, "guild.sys.upgraded", {
			name = nameOf(player),
			skill = if def then "@" .. def.nameKey else skillId, -- "@" = localized by the viewer
			level = data.skills[skillId],
		})
	end
	return ok, err
end

local function setMotd(player: Player, text: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	local length = utf8.len(text)
	if not length or length > Rules.motdMax then
		return false, "guild.error.motd"
	end
	local filtered = if text == "" then "" else filter(player, text)
	if not filtered then
		return false, "error.name.filterFailed"
	end
	return mutate(guildId, function(guild)
		return Guild.setMotd(guild, key, filtered)
	end)
end

local function setSetting(player: Player, name: string, value: any): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	return mutate(guildId, function(guild)
		return Guild.setSetting(guild, key, name, value)
	end)
end

local function chat(player: Player, text: string)
	local guildId = guildOf[player]
	local length = utf8.len(text)
	if not guildId or not length or length == 0 or length > Config.GuildChatMaxLength then
		return
	end
	local filtered = filter(player, text)
	if filtered and filtered ~= "" and guildOf[player] == guildId then
		Bus.publish(guildId, { op = "chat", n = nameOf(player), t = filtered })
	end
end

-- S159g: bank, rights, banner, goals --------------------------------------------------------------------------------

local ProgressRules = GuildProgressData.Rules

local function lazy(name: string): any
	if not Registry then
		return nil
	end
	local ok, service = pcall(Registry.Get, name)
	return if ok then service else nil
end

local function today(): number
	return Time.dayNumber(os.time())
end

-- Gives an item back to the player: into `index` when it is still free, else anywhere in the backpack, else by mail
-- (nothing is lost when the backpack filled up while the guild record was written).
local function giveItem(player: Player, item: any, index: number?)
	local char = character(player)
	if
		char
		and index
		and InventoryService.ValidTakeIndex(player, index)
		and InventoryService.Get(player, index) == nil
	then
		InventoryService.SetSlot(player, index, item)
		return
	end
	local leftover = if char then InventoryService.AddItem(player, item) else item.n
	if leftover <= 0 then
		return
	end
	local rest = table.clone(item)
	rest.n = leftover
	local mail = lazy("MailService")
	if mail then
		task.spawn(mail.Send, player.UserId, {
			from = "system",
			subjectKey = "mail.subject.returned",
			items = { rest },
			charId = if char then char.id else nil,
		})
	end
	log:warn("guild vault item %s of %s went by mail (backpack full)", tostring(item.id), player.Name)
end

local function inCombat(player: Player): boolean
	local resources = lazy("ResourceService")
	return resources ~= nil and resources.InCombat(player)
end

local function withdrawGold(player: Player, amount: number): (boolean, string?)
	local guildId, key = myGuild(player)
	local char = character(player)
	if not guildId or not key or not char then
		return false, "guild.error.none"
	end
	local ok, err = mutate(guildId, function(guild)
		return GuildBank.withdrawGold(guild, key, amount, os.time(), today())
	end)
	if not ok then
		return false, err
	end
	local now = character(player)
	if not now or now.id ~= char.id then
		-- switched characters while the record was written: the gold goes back to the treasury
		mutate(guildId, function(guild)
			if not guild or guild.disbanded then
				return false, "guild.error.gone"
			end
			guild.treasury += amount
			guild.version += 1
			return true, nil
		end)
		return false, "error.wrongPhase"
	end
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold + amount
	end)
	Analytics.gold(player, amount, balance, "guildWithdraw")
	DataService.Save(player)
	notify(guildId, "guild.sys.withdraw", { name = char.name, amount = amount })
	return true, nil
end

local function putItem(player: Player, invIndex: number, slot: number?): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	if inCombat(player) then
		return false, "guild.error.combat"
	end
	local item = InventoryService.Get(player, invIndex)
	if not item then
		return false, "error.stale"
	end
	if item.bound then
		return false, "trade.error.bound"
	end
	local data = cache[guildId].data
	if not Guild.can(data.members[key] and data.members[key].rank, "putItem", data) then
		return false, "guild.error.permission"
	end
	-- The item leaves first (no yield between the check and the change); back if the guild write fails.
	InventoryService.SetSlot(player, invIndex, nil)
	local ok, err = mutate(guildId, function(guild)
		return GuildBank.putItem(guild, key, item, slot, os.time())
	end)
	if not ok then
		giveItem(player, item, invIndex)
		return false, err
	end
	DataService.Save(player)
	return true, nil
end

local function takeItem(player: Player, slot: number, invIndex: number?): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	if inCombat(player) then
		return false, "guild.error.combat"
	end
	local vault = cache[guildId].data.vault or {}
	local wanted = vault[tostring(slot)]
	if type(wanted) ~= "table" then
		return false, "error.stale"
	end
	if not InventoryService.CanFit(player, { wanted }) then
		return false, "inventory.full"
	end
	local taken: any = nil
	local ok, err = mutate(guildId, function(guild)
		local done, reason, item = GuildBank.takeItem(guild, key, slot, wanted.uid, os.time(), today())
		taken = item
		return done, reason
	end)
	if not ok or not taken then
		return false, err
	end
	giveItem(player, taken, invIndex)
	DataService.Save(player)
	return true, nil
end

local function moveVault(player: Player, from: number, to: number): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	return mutate(guildId, function(guild)
		return GuildBank.move(guild, key, from, to)
	end)
end

local function setPerm(player: Player, rank: string, action: string, value: any): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	return mutate(guildId, function(guild)
		return Guild.setPerm(guild, key, rank, action, value)
	end)
end

local function setLimit(player: Player, rank: string, kind: string, value: number): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	return mutate(guildId, function(guild)
		return Guild.setLimit(guild, key, rank, kind, value)
	end)
end

local function setBanner(player: Player, emblem: string, colour: string): (boolean, string?)
	local guildId, key = myGuild(player)
	if not guildId or not key then
		return false, "guild.error.none"
	end
	return mutate(guildId, function(guild)
		return Guild.setBanner(guild, key, emblem, colour)
	end)
end

-- The Dragon Shards of a weekly goal done (Logic/GuildProgress.canClaim; once per goal, week and character).
local function claimGoal(player: Player, index: number): (boolean, string?)
	local guildId, key = myGuild(player)
	local char = character(player)
	if not guildId or not key or not char then
		return false, "guild.error.none"
	end
	local data = cache[guildId].data
	local week = Time.weekNumber(os.time())
	local ok, err = GuildProgress.canClaim(data, key, index, week, char.guildWork)
	if not ok then
		return false, err
	end
	local goal = ((data.week :: any).goals :: { Guild.Goal })[index]
	PlayerStateService.Set(
		player,
		{ "character", "guildWork" },
		GuildProgress.markClaimed(char.guildWork, week, goal.id)
	)
	local shards = ProgressRules.claimShards
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(value: number?)
		return (value or 0) + shards
	end)
	Analytics.shards(player, shards, total, "guildGoal")
	DataService.Save(player)
	return true, nil
end

-- Activity -------------------------------------------------------------------------------------------------------------

-- guild id -> member key -> the guild EXP and activities of members on this server not written yet
local pending: { [string]: GuildProgress.Batch } = {}
local flushing: { [string]: boolean } = {}

local function record(player: Player, kind: string, data: { [string]: any }?)
	local guildId = guildOf[player]
	local key = memberKey(player)
	local char = character(player)
	if not guildId or not key or not char then
		return
	end
	local act, n = GuildProgress.activity(kind, data, char.level)
	if not act or n <= 0 then
		return
	end
	local granted, work = GuildProgress.earn(char.guildWork, today(), GuildProgress.points(act, n))
	if granted > 0 then
		PlayerStateService.Set(player, { "character", "guildWork" }, work)
	end
	local batch = pending[guildId] or {}
	pending[guildId] = batch
	local part = batch[key] or { exp = 0, acts = {} }
	batch[key] = part
	part.exp += granted
	part.acts[act] = (part.acts[act] or 0) + n
end

local function announce(guildId: string, notes: GuildProgress.Notes)
	for _, level in notes.levels do
		notify(guildId, "guild.sys.levelUp", { level = level })
	end
	for _, id in notes.goals do
		local def = GuildProgressData.goalById[id]
		notify(guildId, "guild.sys.goalDone", { goal = if def then "@" .. def.nameKey else id })
	end
	if notes.rally then
		notify(guildId, "guild.sys.rally", nil)
	end
end

-- Writes the pending activity of one guild (yields). A failed write keeps it for the next round.
local function flush(guildId: string)
	local batch = pending[guildId]
	if not batch or flushing[guildId] then
		return
	end
	pending[guildId] = nil
	flushing[guildId] = true
	local notes: GuildProgress.Notes? = nil
	local week, now = Time.weekNumber(os.time()), os.time()
	local ok, err, data = Runtime.mutate(guildId, function(guild: GuildData?)
		if not guild or guild.disbanded then
			return false, "guild.error.gone"
		end
		notes = GuildProgress.apply(guild, batch, week, now)
		return true, nil
	end, true)
	flushing[guildId] = nil
	if not ok then
		if err ~= "guild.error.gone" then
			local again = pending[guildId] or {}
			GuildProgress.merge(again, batch)
			pending[guildId] = again
		end
		return
	end
	local n = notes :: GuildProgress.Notes?
	if n and (#n.levels > 0 or #n.goals > 0 or n.rally) then
		-- something members should see on every server now: the usual change notice, chat lines, board entry
		Bus.publish(guildId, { op = "changed", v = if data then data.version else 0 })
		announce(guildId, n)
		submitGuild(data)
	end
end

local function flushAll()
	for guildId in table.clone(pending) do
		task.spawn(flush, guildId)
	end
end

-- Admin (S159g): writes the pending guild EXP of every guild now.
function GuildService.AdminFlush()
	flushAll()
end

-- Admin: disbands the player's guild without confirmation. Yields.
function GuildService.AdminDisband(player: Player): boolean
	local guildId = guildOf[player]
	if not guildId then
		return false
	end
	return (
		disbandRecord(guildId, function(guild: GuildData?)
			local key = guild and guild.leaderCharId
			return Guild.disband(guild, key or "", true)
		end)
	)
end

-- Lifecycle ---------------------------------------------------------------------------------------

-- Entering the world: verify the membership against the record and attach.
local function onEntered(player: Player, char: Types.CharacterData)
	local guildId = char.guildId
	if not guildId then
		return
	end
	local entry = cache[guildId]
	local data: GuildData? = if entry then entry.data else nil
	if not data then
		local ok, stored = Store.get(guildId)
		if not ok then
			return -- store down: keep guildId, try again next time
		end
		data = stored
	end
	if character(player) ~= char then
		return -- switched characters while loading
	end
	local key = Guild.memberKey(player.UserId, char.id)
	if not data or data.disbanded or not data.members[key] then
		setGuildId(player, nil)
		Net.Fire(
			player,
			"Toast",
			if data and data.disbanded then "guild.disbandedToast" else "guild.removedToast",
			nil,
			"warning"
		)
		return
	end
	attach(player, data)
	local member = data.members[key]
	if member.name ~= char.name or member.level ~= char.level or member.class ~= char.class then
		mutate(guildId, function(guild)
			return Guild.touchMember(guild, key, char.name, char.class, char.level)
		end)
	end
end

local function onDeleted(player: Player, char: Types.CharacterData)
	local guildId = char.guildId
	if not guildId then
		return
	end
	local key = Guild.memberKey(player.UserId, char.id)
	local emptied: GuildData? = nil
	local ok = mutate(guildId, function(guild)
		local removed, note = Guild.forceRemove(guild, key)
		emptied = nil
		if removed and note == "empty" then
			local g = guild :: GuildData
			g.disbanded = true
			emptied = g
		end
		return removed, note
	end)
	if not ok then
		return
	end
	local gone = emptied :: GuildData?
	if gone then
		Store.releaseNames(Guild.nameKey(gone.name), Guild.tagKey(gone.tag), guildId)
		log:info("guild %s disbanded (last member deleted)", guildId)
	else
		notify(guildId, "guild.sys.left", { name = char.name })
	end
end

function GuildService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	StatService = registry.Get("StatService")
	LevelService = registry.Get("LevelService")
	NpcService = registry.Get("NpcService")
	InventoryService = registry.Get("InventoryService")
	Store.init(DataService.HasDataStoreAccess)
	Runtime.init(PlayerStateService, StatService)
	Bus.init(Runtime.onMessage)
	StatService.RegisterModifierSource("guild", function(player: Player): any
		local entry = guildOf[player] and cache[guildOf[player]]
		if not entry then
			return nil
		end
		local flat = Guild.bonuses(entry.data.skills)
		-- S159g: the rally of a week with every goal done
		for stat, value in GuildProgress.rallyBonus(entry.data, Time.weekNumber(os.time())) do
			flat[stat] = (flat[stat] or 0) + value
		end
		return { key = "source.guild", flat = flat }
	end)
end

local function locked(handler: (Player, ...any) -> (boolean, string?)): (Player, ...any) -> (boolean, string?)
	return function(player: Player, ...: any)
		local args = table.pack(...)
		return withLock(player, function()
			return handler(player, table.unpack(args, 1, args.n))
		end)
	end
end

function GuildService.Start()
	Net.Handle("GuildCreate", locked(create))
	Net.Handle("GuildInvite", function(player: Player, userId: number)
		return invite(player, Players:GetPlayerByUserId(userId))
	end)
	Net.Handle("GuildInviteName", function(player: Player, name: string)
		return invite(player, findByName(name))
	end)
	Net.Handle("GuildRespond", locked(respond))
	Net.Handle("GuildLeave", locked(leave))
	Net.Handle("GuildKick", locked(kick))
	Net.Handle("GuildSetRank", locked(setRank))
	Net.Handle("GuildTransfer", locked(transfer))
	Net.Handle("GuildDisband", locked(disband))
	Net.Handle("GuildDeposit", locked(deposit))
	Net.Handle("GuildUpgrade", locked(upgrade))
	Net.Handle("GuildSetMotd", locked(setMotd))
	Net.Handle("GuildSetting", locked(setSetting))
	Net.On("GuildChatSend", chat)
	-- S159g
	Net.Handle("GuildWithdraw", locked(withdrawGold))
	Net.Handle("GuildPutItem", locked(putItem))
	Net.Handle("GuildTakeItem", locked(takeItem))
	Net.Handle("GuildMoveVault", locked(moveVault))
	Net.Handle("GuildSetPerm", locked(setPerm))
	Net.Handle("GuildSetLimit", locked(setLimit))
	Net.Handle("GuildSetBanner", locked(setBanner))
	Net.Handle("GuildClaimGoal", locked(claimGoal))

	-- S159g: guild EXP and goal progress from members' play
	QuestEvents.Fired:Connect(function(player: Player, kind: string, data: { [string]: any })
		if kind ~= "kill" then -- kills come from CombatService below (QuestEvents has no "kill" of its own)
			record(player, kind, data)
		end
	end)
	local combat = lazy("CombatService")
	if combat then
		combat.MonsterKilled:Connect(function(info: any, credit: { Player })
			for _, player in credit do
				record(player, "kill", info)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(ProgressRules.flushSeconds + math.random() * ProgressRules.flushJitter)
			flushAll()
		end
	end)
	game:BindToClose(function()
		flushAll()
		task.wait(2)
	end)

	-- Chat tabs (general / party / guild) in the default chat window.
	pcall(function()
		local tabs = TextChatService:FindFirstChildOfClass("ChannelTabsConfiguration")
		if tabs then
			tabs.Enabled = true
		end
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player, char: Types.CharacterData)
		task.spawn(onEntered, player, char)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
		detach(player)
	end)
	CharacterService.CharacterDeleted:Connect(onDeleted)
	CharacterService.ModelSpawned:Connect(Runtime.applyTag)
	LevelService.LeveledUp:Connect(function(player: Player)
		local guildId, key = myGuild(player)
		local char = character(player)
		if guildId and key and char then
			task.spawn(mutate, guildId, function(guild)
				return Guild.touchMember(guild, key, char.name, char.class, char.level)
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local guildId = guildOf[player]
		if guildId and pending[guildId] then
			task.spawn(flush, guildId) -- the last member here may be leaving: write before the cache goes
		end
		invites[player] = nil
		detach(player)
		busy[player] = nil
		Runtime.setLeaving(player, false)
	end)

	-- Presence refresh + safety re-read (MessagingService may drop messages).
	task.spawn(function()
		local sinceReload = 0
		while true do
			task.wait(Config.GuildPresenceRefresh)
			sinceReload += Config.GuildPresenceRefresh
			local reload = sinceReload >= Config.GuildCacheRefresh
			if reload then
				sinceReload = 0
			end
			for guildId, entry in table.clone(cache) do
				local mine = {}
				for _, key in entry.online do
					mine[key] = true
				end
				Bus.setPresence(guildId, mine)
				local presence = Bus.readPresence(guildId)
				if presence and cache[guildId] == entry then
					for key in mine do
						presence[key] = Bus.JobId
					end
					entry.presence = presence
				end
				if reload then
					local ok, data = Store.get(guildId)
					if ok and data then
						Runtime.setData(guildId, data)
					end
				end
				if cache[guildId] == entry then
					Runtime.publish(entry)
				end
			end
		end
	end)
end

return GuildService
