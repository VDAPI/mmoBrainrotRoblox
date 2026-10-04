--!strict
-- Guild runtime on one server (S12): the cache of guilds with members online here, the state branch
-- `guild`, guild tags, the guild TextChannel, presence and the MessagingService handler. GuildService runs
-- the operations on top of it; every change goes through Runtime.mutate (one UpdateAsync + notice).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local Bus = require(script.Parent.Bus)
local Guild = require(Shared.Logic.Guild)
local Net = require(Shared.Net)
local Store = require(script.Parent.Store)
local Types = require(Shared.Types)

type GuildData = Guild.GuildData

export type Cache = {
	data: GuildData,
	online: { [Player]: string }, -- player -> member key
	presence: { [string]: string }, -- member key -> job id (any server)
	channel: TextChannel?,
}

local Runtime = {}

-- Players leaving on their own (no "you were removed" toast when the record drops them).
local leaving: { [Player]: boolean } = {}

local PlayerStateService: any
local StatService: any

local cache: { [string]: Cache } = {}
local guildOf: { [Player]: string } = {}
Runtime.cache = cache
Runtime.guildOf = guildOf

function Runtime.init(playerState: any, stats: any)
	PlayerStateService = playerState
	StatService = stats
end

function Runtime.character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

function Runtime.memberKey(player: Player): string?
	local char = Runtime.character(player)
	return if char then Guild.memberKey(player.UserId, char.id) else nil
end

function Runtime.setGuildId(player: Player, id: string?)
	if PlayerStateService.HasState(player) and Runtime.character(player) then
		PlayerStateService.Set(player, { "character", "guildId" }, id)
	end
end

function Runtime.applyTag(player: Player)
	local model = player.Character
	if not model then
		return
	end
	local entry = guildOf[player] and cache[guildOf[player]]
	model:SetAttribute("GuildTag", if entry then entry.data.tag else nil)
end

-- Text channel ------------------------------------------------------------------------------------

local function channelFor(entry: Cache): TextChannel?
	if entry.channel then
		return entry.channel
	end
	local ok, channel = pcall(function()
		local c = Instance.new("TextChannel")
		-- The name is the chat tab label; clients find the channel by the GuildId attribute.
		c.Name = `⚑ {entry.data.tag}`
		c:SetAttribute("GuildId", entry.data.id)
		c:SetAttribute("VaelthornChannel", "guild")
		c.Parent = TextChatService
		return c
	end)
	entry.channel = if ok then channel else nil
	return entry.channel
end

local function joinChannel(entry: Cache, player: Player)
	local channel = channelFor(entry)
	if channel then
		task.spawn(function()
			pcall(function()
				channel:AddUserAsync(player.UserId)
			end)
		end)
	end
end

local function leaveChannel(entry: Cache, player: Player)
	local channel = entry.channel
	if not channel then
		return
	end
	for _, source in channel:GetChildren() do
		if source:IsA("TextSource") and source.UserId == player.UserId then
			source:Destroy()
		end
	end
end

-- Replication -------------------------------------------------------------------------------------

local function stateFor(entry: Cache, player: Player): any
	local data = entry.data
	local myKey = entry.online[player]
	local members = {}
	for _, key in Guild.sortedKeys(data) do
		local member = data.members[key]
		local job = entry.presence[key]
		local here = false
		for _, onlineKey in entry.online do
			if onlineKey == key then
				here = true
			end
		end
		table.insert(members, {
			key = key,
			userId = member.userId,
			name = member.name,
			class = member.class,
			level = member.level,
			rank = member.rank,
			contributed = member.contributed or 0,
			joinedAt = member.joinedAt,
			online = here or job ~= nil,
			server = if here then "here" elseif job then string.sub(job, 1, 8) else nil,
		})
	end
	local me = myKey and data.members[myKey]
	return {
		id = data.id,
		name = data.name,
		tag = data.tag,
		motd = data.motd,
		treasury = data.treasury,
		skills = data.skills,
		settings = data.settings,
		createdAt = data.createdAt,
		leader = data.leaderCharId,
		myKey = myKey,
		myRank = if me then me.rank else "member",
		limit = Guild.memberLimit(data.skills),
		members = members,
	}
end

function Runtime.publish(entry: Cache)
	for player in entry.online do
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "guild" }, stateFor(entry, player))
		end
	end
end

-- Cache -------------------------------------------------------------------------------------------

local function dropCache(guildId: string)
	local entry = cache[guildId]
	if not entry then
		return
	end
	cache[guildId] = nil
	Bus.unsubscribe(guildId)
	if entry.channel then
		entry.channel:Destroy()
	end
end

function Runtime.detach(player: Player)
	local guildId = guildOf[player]
	guildOf[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "guild" }, nil)
	end
	Runtime.applyTag(player)
	StatService.Invalidate(player)
	local entry = guildId and cache[guildId]
	if not entry then
		return
	end
	local key = entry.online[player]
	entry.online[player] = nil
	leaveChannel(entry, player)
	if key then
		entry.presence[key] = nil
		task.spawn(Bus.setPresence, entry.data.id, { [key] = false })
		Bus.publish(entry.data.id, { op = "presence", k = key })
	end
	if next(entry.online) == nil then
		dropCache(entry.data.id)
	else
		Runtime.publish(entry)
	end
end

-- Marks a voluntary leave in progress (suppresses the removal toast).
function Runtime.setLeaving(player: Player, value: boolean)
	(leaving :: any)[player] = if value then true else nil
end

-- Applies a newer record: drops members that are gone, refreshes bonuses, tags and state.
function Runtime.setData(guildId: string, data: GuildData?)
	local entry = cache[guildId]
	if not entry or not data then
		return
	end
	if (data.version or 0) < (entry.data.version or 0) then
		return
	end
	entry.data = data
	for player, key in table.clone(entry.online) do
		if data.disbanded or not data.members[key] then
			Runtime.detach(player)
			Runtime.setGuildId(player, nil)
			if not leaving[player] then
				Net.Fire(
					player,
					"Toast",
					if data.disbanded then "guild.disbandedToast" else "guild.removedToast",
					nil,
					"warning"
				)
			end
		else
			StatService.Invalidate(player)
			Runtime.applyTag(player)
		end
	end
	if cache[guildId] then
		Runtime.publish(entry)
	end
end

function Runtime.attach(player: Player, data: GuildData)
	local key = Runtime.memberKey(player)
	if not key then
		return
	end
	if guildOf[player] and guildOf[player] ~= data.id then
		Runtime.detach(player)
	end
	local entry = cache[data.id]
	if not entry then
		local created: Cache = { data = data, online = {}, presence = {}, channel = nil }
		entry = created
		cache[data.id] = created
		task.spawn(Bus.subscribe, data.id)
		task.spawn(function()
			local presence = Bus.readPresence(data.id)
			if presence and cache[data.id] == created then
				for k, job in presence do
					created.presence[k] = job
				end
				Runtime.publish(created)
			end
		end)
	elseif (data.version or 0) > (entry.data.version or 0) then
		entry.data = data
	end
	assert(entry, "guild cache")
	entry.online[player] = key
	entry.presence[key] = Bus.JobId
	guildOf[player] = data.id
	joinChannel(entry, player)
	Runtime.applyTag(player)
	StatService.Invalidate(player)
	task.spawn(Bus.setPresence, data.id, { [key] = true })
	Bus.publish(data.id, { op = "presence", k = key, j = Bus.JobId })
	Runtime.setData(data.id, entry.data)
end

-- One UpdateAsync with a Logic/Guild mutation; then cache + notice to the other servers.
function Runtime.mutate(guildId: string, fn: (guild: GuildData?) -> (boolean, string?)): (boolean, string?, GuildData?)
	local ok, data, err = Store.update(guildId, function(current: any?)
		local changed, reason = fn(current)
		if not changed then
			return nil, reason
		end
		return current, nil
	end)
	if not ok or not data then
		return false, err, nil
	end
	Runtime.setData(guildId, data)
	Bus.publish(guildId, { op = "changed", v = data.version })
	return true, nil, data
end

-- System line in the guild channel on every server.
function Runtime.notify(guildId: string, key: string, args: { [string]: any }?)
	Bus.publish(guildId, { op = "sys", k = key, a = args })
end

function Runtime.onMessage(guildId: string, message: Bus.Message)
	local entry = cache[guildId]
	if not entry then
		return
	end
	local players = {}
	for player in entry.online do
		table.insert(players, player)
	end
	if message.op == "changed" then
		if (tonumber(message.v) or 0) > (entry.data.version or 0) then
			local ok, data = Store.get(guildId)
			if ok and data then
				Runtime.setData(guildId, data)
			end
		end
	elseif message.op == "chat" then
		-- Local players already saw it through the TextChannel.
		if message.s ~= Bus.ServerId and type(message.t) == "string" then
			Net.FireList(players, "GuildChatLine", tostring(message.n), message.t, nil)
		end
	elseif message.op == "sys" and type(message.k) == "string" then
		Net.FireList(players, "GuildChatLine", nil, message.k, message.a)
	elseif message.op == "presence" and type(message.k) == "string" then
		local presence: { [string]: string? } = entry.presence :: any
		presence[message.k] = if type(message.j) == "string" then message.j else nil
		Runtime.publish(entry)
	end
end

-- Public API --------------------------------------------------------------------------------------

return Runtime
