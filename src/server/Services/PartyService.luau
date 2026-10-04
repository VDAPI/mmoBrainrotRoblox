--!strict
-- Parties (DESIGN §17): up to 5 players on one server. Invites expire after 30 s; the leader can kick and
-- promote; when the leader leaves, the next member leads; a party of one dissolves. Every member gets the
-- state branch `party` = { leader, members = { { id, name, class, level, hp, maxHp, mana, maxMana, map,
-- x, z, dead } } } refreshed twice a second, and a private TextChannel for party chat.
-- Other systems use AreAllies / SameParty / Members / MembersInRange.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("PartyService")

local PartyService = {
	Name = "PartyService",
	Deps = { "PlayerStateService", "CharacterService", "ResourceService", "StatService" },
	-- (party) after members or the leader changed.
	Changed = Signal.new(),
}

local MAX_MEMBERS = 5
local INVITE_SECONDS = 30
local REFRESH = 0.5

export type Party = { id: number, leader: Player, members: { Player }, channel: TextChannel? }

local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local StatService: any

local nextId = 0
local partyOf: { [Player]: Party } = {}
local parties: { [number]: Party } = {}
local invites: { [Player]: { from: Player, expiresAt: number } } = {}
local lastSent: { [Player]: string } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function displayName(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

function PartyService.Get(player: Player): Party?
	return partyOf[player]
end

function PartyService.SameParty(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local party = partyOf[a]
	return party ~= nil and partyOf[b] == party
end

function PartyService.AreAllies(a: Player, b: Player): boolean
	return PartyService.SameParty(a, b)
end

-- Party members including `player` (just the player when solo).
function PartyService.Members(player: Player): { Player }
	local party = partyOf[player]
	return if party then table.clone(party.members) else { player }
end

function PartyService.IsLeader(player: Player): boolean
	local party = partyOf[player]
	return party == nil or party.leader == player
end

-- Living members (incl. `player`) whose character stands within `range` studs of `position`.
function PartyService.MembersInRange(player: Player, position: Vector3, range: number): { Player }
	local result = {}
	for _, member in PartyService.Members(player) do
		local model = member.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not ResourceService.IsDead(member) and (root.Position - position).Magnitude <= range then
			table.insert(result, member)
		end
	end
	return result
end

-- Sends a system chat line to every member.
function PartyService.Notify(party: Party, key: string, args: { [string]: any }?)
	for _, member in party.members do
		Net.Fire(member, "SystemMessage", key, args)
	end
end

local function publish(party: Party?, player: Player)
	if not PlayerStateService.HasState(player) then
		return
	end
	if not party then
		lastSent[player] = nil
		PlayerStateService.Set(player, { "party" }, nil)
		return
	end
	local members = {}
	for _, member in party.members do
		local char = character(member)
		local model = member.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		table.insert(members, {
			id = member.UserId,
			name = displayName(member),
			class = if char then char.class else "Warrior",
			level = if char then char.level else 1,
			hp = if char then math.floor(char.hp) else 0,
			maxHp = math.floor(StatService.GetValue(member, "maxHp")),
			mana = if char then math.floor(char.mana) else 0,
			maxMana = math.floor(StatService.GetValue(member, "maxMana")),
			map = if char then char.location.map else "",
			x = if root then math.floor(root.Position.X) else 0,
			z = if root then math.floor(root.Position.Z) else 0,
			dead = ResourceService.IsDead(member),
		})
	end
	local value = { leader = party.leader.UserId, members = members }
	-- Skip identical updates (positions change often, so this mainly saves idle parties).
	local key = game:GetService("HttpService"):JSONEncode(value)
	if lastSent[player] == key then
		return
	end
	lastSent[player] = key
	PlayerStateService.Set(player, { "party" }, value)
end

local function publishAll(party: Party)
	for _, member in party.members do
		publish(party, member)
	end
end

local function ensureChannel(party: Party)
	if party.channel then
		return
	end
	local ok, channel = pcall(function()
		local c = Instance.new("TextChannel")
		c.Name = `VaelthornParty_{party.id}`
		c.Parent = TextChatService
		return c
	end)
	if ok then
		party.channel = channel
	end
end

local function addToChannel(party: Party, player: Player)
	local channel = party.channel
	if channel then
		task.spawn(function()
			pcall(function()
				channel:AddUserAsync(player.UserId)
			end)
		end)
	end
end

local function removeFromChannel(party: Party, player: Player)
	local channel = party.channel
	if not channel then
		return
	end
	for _, source in channel:GetChildren() do
		if source:IsA("TextSource") and source.UserId == player.UserId then
			source:Destroy()
		end
	end
end

local function dissolve(party: Party)
	for _, member in party.members do
		partyOf[member] = nil
		publish(nil, member)
	end
	parties[party.id] = nil
	if party.channel then
		party.channel:Destroy()
	end
	PartyService.Changed:Fire(party)
end

local function removeMember(player: Player, key: string?)
	local party = partyOf[player]
	if not party then
		return
	end
	local index = table.find(party.members, player)
	if index then
		table.remove(party.members, index)
	end
	partyOf[player] = nil
	removeFromChannel(party, player)
	publish(nil, player)
	if #party.members <= 1 then
		if key then
			Net.Fire(player, "Toast", key, nil, "info")
		end
		dissolve(party)
		return
	end
	if party.leader == player then
		party.leader = party.members[1]
		PartyService.Notify(party, "party.newLeader", { name = displayName(party.leader) })
	end
	PartyService.Notify(party, "party.left", { name = displayName(player) })
	publishAll(party)
	PartyService.Changed:Fire(party)
end

local function findByName(name: string): Player?
	local wanted = string.lower(name)
	for _, player in Players:GetPlayers() do
		local char = character(player)
		if
			(char and string.lower(char.name) == wanted)
			or string.lower(player.Name) == wanted
			or string.lower(player.DisplayName) == wanted
		then
			return player
		end
	end
	return nil
end

local function invite(player: Player, target: Player): (boolean, string?)
	if target == player then
		return false, "party.error.self"
	end
	if PlayerStateService.GetPhase(target) ~= "playing" or not character(player) then
		return false, "party.error.notFound"
	end
	local party = partyOf[player]
	if party and party.leader ~= player then
		return false, "party.error.notLeader"
	end
	if party and #party.members >= MAX_MEMBERS then
		return false, "party.error.full"
	end
	if partyOf[target] then
		return false, "party.error.inParty"
	end
	local pending = invites[target]
	if pending and pending.expiresAt > os.clock() then
		return false, "party.error.pending"
	end
	invites[target] = { from = player, expiresAt = os.clock() + INVITE_SECONDS }
	Net.Fire(target, "PartyInvited", displayName(player), INVITE_SECONDS)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local pending = invites[player]
	invites[player] = nil
	if not pending or pending.expiresAt < os.clock() or pending.from.Parent == nil then
		return false, "party.error.expired"
	end
	local inviter = pending.from
	if not accept then
		Net.Fire(inviter, "Toast", "party.declined", { name = displayName(player) }, "info")
		return true, nil
	end
	if partyOf[player] then
		return false, "party.error.inParty"
	end
	local party = partyOf[inviter]
	if party and party.leader ~= inviter then
		return false, "party.error.expired"
	end
	if not party then
		nextId += 1
		local created: Party = { id = nextId, leader = inviter, members = { inviter }, channel = nil }
		party = created
		parties[created.id] = created
		partyOf[inviter] = created
		ensureChannel(created)
		addToChannel(created, inviter)
	end
	assert(party, "party")
	if #party.members >= MAX_MEMBERS then
		return false, "party.error.full"
	end
	table.insert(party.members, player)
	partyOf[player] = party
	addToChannel(party, player)
	PartyService.Notify(party, "party.joined", { name = displayName(player) })
	publishAll(party)
	PartyService.Changed:Fire(party)
	log:info("%s joined party %d", player.Name, party.id)
	return true, nil
end

local function memberByUserId(party: Party, userId: number): Player?
	for _, member in party.members do
		if member.UserId == userId then
			return member
		end
	end
	return nil
end

function PartyService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	StatService = registry.Get("StatService")
end

function PartyService.Start()
	Net.Handle("PartyInvite", function(player: Player, name: string)
		local target = findByName(name)
		if not target then
			return false, "party.error.notFound"
		end
		return invite(player, target)
	end)
	Net.Handle("PartyInviteUser", function(player: Player, userId: number)
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return false, "party.error.notFound"
		end
		return invite(player, target)
	end)
	Net.Handle("PartyRespond", respond)
	Net.Handle("PartyLeave", function(player: Player)
		removeMember(player, "party.youLeft")
		return true, nil
	end)
	Net.Handle("PartyKick", function(player: Player, userId: number)
		local party = partyOf[player]
		if not party or party.leader ~= player then
			return false, "party.error.notLeader"
		end
		local target = memberByUserId(party, userId)
		if not target or target == player then
			return false, "error.badRequest"
		end
		Net.Fire(target, "Toast", "party.kicked", nil, "warning")
		removeMember(target, nil)
		return true, nil
	end)
	Net.Handle("PartyPromote", function(player: Player, userId: number)
		local party = partyOf[player]
		if not party or party.leader ~= player then
			return false, "party.error.notLeader"
		end
		local target = memberByUserId(party, userId)
		if not target then
			return false, "error.badRequest"
		end
		party.leader = target
		PartyService.Notify(party, "party.newLeader", { name = displayName(target) })
		publishAll(party)
		PartyService.Changed:Fire(party)
		return true, nil
	end)

	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
		removeMember(player, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		removeMember(player, nil)
		lastSent[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(REFRESH)
			for _, party in parties do
				publishAll(party)
			end
		end
	end)
end

return PartyService
