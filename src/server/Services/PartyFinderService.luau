--!strict
-- Party finder board (S134f, DESIGN §17, Logic/PartyFinder): one board per server, in memory only (a restart clears
-- it). A leader (or a solo player) posts "looking for a party" for a boss, an Elite II, the running Invasion or a
-- hunting ground: the server works out the target's name, level and band from the data (the client sends only the
-- kind, the target id, a narrower band and the wanted classes, never free text). "Join" puts the player into the
-- leader's party at once through PartyService.AddMember (no leader consent; the leader is told and may kick as
-- usual). A listing disappears when the party is full, the leader left the game or the party, stopped leading,
-- entered a dungeon, the target is gone (the Invasion ended) or it expired (the leader may renew it).
-- Players with the board open (FinderWatch) get the runtime branch `finder` = { listings, mine? } at most once per
-- Config.PartyFinder.publishEvery and only when it changed.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local PartyFinder = require(Shared.Logic.PartyFinder)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("PartyFinderService")

local PartyFinderService = {
	Name = "PartyFinderService",
	Deps = { "PlayerStateService", "PartyService", "CharacterService", "DungeonService", "WorldEventService" },
}

type Listing = PartyFinder.Listing

local CFG = Config.PartyFinder

local PlayerStateService: any
local PartyService: any
local CharacterService: any
local DungeonService: any
local WorldEventService: any

local listings: { Listing } = {}
local nextId = 0
local watchers: { [Player]: boolean } = {}
local lastSent: { [Player]: string } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

-- The running (or announced) Invasion as a board target, or nil.
local function invasionTarget(): PartyFinder.Target?
	local e = WorldEventService.Current()
	if not e or e.kind ~= "invasion" then
		return nil
	end
	return {
		kind = "invasion",
		id = e.id,
		nameKey = e.area.nameKey,
		level = e.level,
		top = e.level,
		at = { map = e.map, x = e.centre.X - e.offset.X, z = e.centre.Z - e.offset.Z },
	}
end

local function targetOf(kind: PartyFinder.Kind, id: string): PartyFinder.Target?
	if kind == "invasion" then
		local current = invasionTarget()
		return if current and (id == current.id or id == "current") then current else nil
	end
	return PartyFinder.target(kind, id)
end

-- Whether the listing may still be joined: the leader online, leading (or solo), not in a dungeon run, the target there.
local function alive(listing: Listing): boolean
	local leader = Players:GetPlayerByUserId(listing.leaderId)
	if not leader or not character(leader) or not PartyService.IsLeader(leader) or DungeonService.InRun(leader) then
		return false
	end
	if listing.kind == "invasion" then
		local current = invasionTarget()
		return current ~= nil and current.id == listing.target
	end
	return true
end

-- Refreshes the size and the leader's level, then drops what may no longer be joined.
local function prune()
	for _, listing in listings do
		local leader = Players:GetPlayerByUserId(listing.leaderId)
		if leader then
			listing.size = #PartyService.Members(leader)
			local char = character(leader)
			if char then
				listing.leaderLevel = char.level
			end
		end
	end
	listings = PartyFinder.prune(listings, now(), alive)
end

local function payloadFor(player: Player): any
	local char = character(player)
	local level = if char then char.level else 1
	local mine: number? = nil
	for _, listing in listings do
		if listing.leaderId == player.UserId then
			mine = listing.id
		end
	end
	return { listings = PartyFinder.visible(listings, level, now()), mine = mine }
end

local function publish(player: Player)
	if not watchers[player] or not PlayerStateService.HasState(player) then
		return
	end
	local value = payloadFor(player)
	local key = HttpService:JSONEncode(value)
	if lastSent[player] == key then
		return
	end
	lastSent[player] = key
	PlayerStateService.Set(player, { "finder" }, value)
end

local function post(
	player: Player,
	kind: string,
	targetId: string,
	minLevel: number,
	maxLevel: number,
	want: any
): (boolean, string?)
	if not table.find(PartyFinder.KINDS, kind :: any) then
		return false, "error.badRequest"
	end
	local classes = PartyFinder.validWant(want)
	if not classes then
		return false, "error.badRequest"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local target = targetOf(kind :: PartyFinder.Kind, targetId)
	if not target then
		return false, "finder.error.target"
	end
	local baseMin, baseMax = PartyFinder.bandFor(target.kind, target.level, target.top)
	local lo, hi = PartyFinder.clampBand(baseMin, baseMax, minLevel, maxLevel)
	prune()
	local ok, err = PartyFinder.canPost({ listings = listings, maxListings = CFG.maxListings }, {
		id = player.UserId,
		level = char.level,
		inParty = PartyService.Get(player) ~= nil,
		isLeader = PartyService.IsLeader(player),
		partySize = #PartyService.Members(player),
		minLevel = lo,
		maxLevel = hi,
	})
	if not ok then
		return false, err
	end
	nextId += 1
	local t = now()
	listings = PartyFinder.post(listings, {
		id = nextId,
		leaderId = player.UserId,
		leaderName = char.name,
		leaderClass = char.class :: string,
		leaderLevel = char.level,
		kind = target.kind,
		target = target.id,
		nameKey = target.nameKey,
		level = target.level,
		minLevel = lo,
		maxLevel = hi,
		want = classes,
		size = #PartyService.Members(player),
		createdAt = t,
		expiresAt = t + CFG.listingSeconds,
		at = target.at,
	})
	log:info("%s posted %s %s (%d-%d)", player.Name, target.kind, target.id, lo, hi)
	return true, nil
end

local function cancel(player: Player): (boolean, string?)
	local before = #listings
	local kept = {}
	for _, listing in listings do
		if listing.leaderId ~= player.UserId then
			table.insert(kept, listing)
		end
	end
	listings = kept
	return #kept < before, if #kept < before then nil else "finder.error.none"
end

local function join(player: Player, id: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	prune()
	local listing: Listing? = nil
	for _, candidate in listings do
		if candidate.id == id then
			listing = candidate
		end
	end
	if not listing then
		return false, "finder.error.expired"
	end
	local ok, err = PartyFinder.canJoin(listing, {
		id = player.UserId,
		level = char.level,
		class = char.class :: string,
		inParty = PartyService.Get(player) ~= nil,
	}, now())
	if not ok then
		return false, err
	end
	local blocked = UseGuards.first(player, UseBlocks.LISTS.finder)
	if blocked then
		return false, UseBlocks.key("finder", blocked)
	end
	local leader = Players:GetPlayerByUserId(listing.leaderId)
	if not leader or not alive(listing) then
		return false, "finder.error.expired"
	end
	if UseGuards.first(leader, UseBlocks.LISTS.finder) then
		return false, "finder.error.leaderBusy"
	end
	local added, why = PartyService.AddMember(leader, player)
	if not added then
		return false, why
	end
	Net.Fire(leader, "Toast", "finder.joined", { name = char.name }, "info")
	prune()
	return true, nil
end

-- /finder list: the board as text lines.
function PartyFinderService.List(): { string }
	prune()
	local out = {}
	for _, listing in listings do
		table.insert(
			out,
			`#{listing.id} {listing.leaderName} {listing.kind}:{listing.target} {listing.minLevel}-{listing.maxLevel} {listing.size}/{CFG.maxMembers}`
		)
	end
	return out
end

-- /finder clear: empties the board. Returns how many listings went.
function PartyFinderService.Clear(): number
	local n = #listings
	listings = {}
	return n
end

function PartyFinderService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	PartyService = registry.Get("PartyService")
	CharacterService = registry.Get("CharacterService")
	DungeonService = registry.Get("DungeonService")
	WorldEventService = registry.Get("WorldEventService")
end

function PartyFinderService.Start()
	Net.Handle("FinderPost", post)
	Net.Handle("FinderCancel", cancel)
	Net.Handle("FinderJoin", join)
	Net.On("FinderWatch", function(player: Player, on: boolean)
		if on then
			watchers[player] = true
			lastSent[player] = nil
			prune()
			publish(player)
		else
			watchers[player] = nil
			lastSent[player] = nil
			if PlayerStateService.HasState(player) then
				PlayerStateService.Set(player, { "finder" }, nil)
			end
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		watchers[player] = nil
		lastSent[player] = nil
		cancel(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		watchers[player] = nil
		lastSent[player] = nil
		cancel(player)
	end)
	task.spawn(function()
		while true do
			task.wait(CFG.publishEvery)
			local ok, err = pcall(function()
				prune()
				for player in watchers do
					publish(player)
				end
			end)
			if not ok then
				log:error("finder step failed: %s", tostring(err))
			end
		end
	end)
end

return PartyFinderService
