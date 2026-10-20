--!strict
-- Help for returning players (S153, docs/DESIGN.md §11): the bonus after a long absence and the "What has changed"
-- letter (Logic/Returning, Data/Changelog, Config.Returning).
-- Order on every profile load (PlayerStateService.Ready): Returning.check with the previous account.stats.lastSeen,
-- then lastSeen = now. lastSeen is also written every LAST_SEEN_EVERY seconds (a crashed server loses at most that) and
-- when the profile is released. An account without lastSeen (the first load after S153, a new account) only gets the
-- timestamp and `seen` = the newest changelog entry: no bonus on the day this ships, no history for a new player.
-- The bonus is its own modifier source "returning" (+Config.Returning.expBonus points of expBonus, added to the
-- blessing of Fortune; never a blessing, so it never replaces one). Its time counts down only while a character is in
-- the world on a world server (TICK seconds; written to account.returning at most every WRITE_EVERY seconds, when the
-- character leaves and when the profile is released). The client reads account.returning (HUD icon, letter window);
-- ChangelogSeen(id) marks the letter read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Changelog = require(Shared.Data.Changelog)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Returning = require(Shared.Logic.Returning)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local StatCalc = require(Shared.Logic.StatCalc)
local Types = require(Shared.Types)

local log = Log.new("ReturningService")

type State = Returning.State

local ReturningService = {
	Name = "ReturningService",
	Deps = { "DataService", "PlayerStateService", "StatService", "CharacterService" },
}

local TICK = 5 -- seconds between two countdown steps (not a balance number)
local WRITE_EVERY = 30 -- seconds between two writes of the countdown (not a balance number)
local LAST_SEEN_EVERY = 300 -- seconds between two writes of lastSeen (not a balance number)
local DAY = 86400

local DataService: any
local PlayerStateService: any
local StatService: any

-- The live state of each loaded player (the countdown runs here, written every WRITE_EVERY seconds).
local live: { [Player]: State } = {}
local lastWrite: { [Player]: number } = {}
-- A bonus granted on this load whose toast waits for the character to enter the world.
local announce: { [Player]: boolean } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

local function maxLevel(data: Types.AccountData): number
	local top = 0
	for _, character in data.characters do
		if type(character) == "table" and type(character.level) == "number" then
			top = math.max(top, character.level)
		end
	end
	return top
end

local function inWorld(player: Player): boolean
	return ServerMode.isWorld()
		and PlayerStateService.GetPhase(player) == "playing"
		and PlayerStateService.GetCharacter(player) ~= nil
end

local function write(player: Player)
	local state = live[player]
	if state and PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "account", "returning" }, table.clone(state))
	end
	lastWrite[player] = os.clock()
end

local function setLastSeen(player: Player, t: number)
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "account", "stats", "lastSeen" }, t)
	end
end

local function toastGranted(player: Player)
	local state = live[player]
	if state and state.left > 0 then
		Net.Fire(player, "Toast", "returning.granted", { min = Returning.minutes(state) }, "success")
	end
	announce[player] = nil
end

-- Sets the live state; a change of the bonus recomputes the stats.
local function set(player: Player, state: State)
	local before = live[player]
	live[player] = state
	write(player)
	if before == nil or Returning.bonus(before) ~= Returning.bonus(state) then
		StatService.Invalidate(player)
	end
end

local function grant(player: Player)
	if inWorld(player) then
		toastGranted(player)
	else
		announce[player] = true
	end
end

local function onReady(player: Player)
	local data = account(player)
	if not data then
		return
	end
	local now = Clock.now()
	-- also after a state reset (/wipe): the saved state of the (new) profile data
	local state = Returning.sanitize(data.returning)
	local lastSeen = if type(data.stats.lastSeen) == "number" then data.stats.lastSeen else 0
	local granted = false
	if lastSeen <= 0 then
		state.seen = math.max(state.seen, Changelog.maxId())
	else
		state, granted = Returning.check(state, lastSeen, now, maxLevel(data))
	end
	set(player, state)
	setLastSeen(player, now)
	if granted then
		log:info("%s is back after %.1f days: returning bonus", player.Name, (now - lastSeen) / DAY)
		grant(player)
	end
end

local function modifierSource(player: Player, _character: Types.CharacterData): StatCalc.Source?
	local state = live[player]
	local bonus = if state then Returning.bonus(state) else 0
	if bonus <= 0 then
		return nil
	end
	return { key = "source.returning", flat = { expBonus = bonus } }
end

local function step(dt: number)
	local clock = os.clock()
	for player, state in live do
		if state.left > 0 then
			local after = Returning.tick(state, dt, inWorld(player))
			if after.left <= 0 then
				set(player, after)
				Net.Fire(player, "Toast", "returning.ended", nil, "info")
			elseif after.left ~= state.left then
				live[player] = after
				if clock - (lastWrite[player] or 0) >= WRITE_EVERY then
					write(player)
				end
			end
		end
	end
end

-- Last chance before the profile ends: the countdown and lastSeen straight into the profile data.
local function release(player: Player)
	local data = account(player)
	local state = live[player]
	if data then
		if state then
			data.returning = table.clone(state)
		end
		data.stats.lastSeen = Clock.now()
	end
end

local function onSeen(player: Player, upTo: number)
	local state = live[player]
	if not state or upTo <= state.seen then
		return
	end
	local read = Returning.readUpTo(Changelog.ENTRIES, upTo)
	if not read then
		return
	end
	set(player, Returning.markSeen(state, read))
end

-- Admin /returning info: the live state, lastSeen and the bonus now (nil without a profile).
function ReturningService.Info(player: Player): { [string]: number }?
	local data = account(player)
	local state = live[player]
	if not data or not state then
		return nil
	end
	return {
		left = state.left,
		at = state.at,
		seen = state.seen,
		lastSeen = data.stats.lastSeen,
		bonus = Returning.bonus(state),
		maxLevel = maxLevel(data),
	}
end

-- Admin /returning grant [seconds]: the bonus now (at most Config.Returning.seconds), `at` = now.
function ReturningService.Grant(player: Player, seconds: number?): boolean
	local state = live[player]
	if not state then
		return false
	end
	local s = table.clone(state)
	s.left = math.min(seconds or Config.Returning.seconds, Config.Returning.seconds)
	s.at = Clock.now()
	set(player, Returning.sanitize(s))
	grant(player)
	return true
end

-- Admin /returning clear: no bonus and no cooldown (`at` = 0).
function ReturningService.Clear(player: Player): boolean
	local state = live[player]
	if not state then
		return false
	end
	local s = table.clone(state)
	s.left = 0
	s.at = 0
	set(player, s)
	announce[player] = nil
	return true
end

-- Admin /returning away <days>: the check now as if the last visit was `days` ago (the cooldown and minLevel apply;
-- the real lastSeen is rewritten by the next save anyway). Returns whether the bonus was granted.
function ReturningService.Away(player: Player, days: number): boolean?
	local data = account(player)
	local state = live[player]
	if not data or not state then
		return nil
	end
	local now = Clock.now()
	local after, granted = Returning.check(state, now - days * DAY, now, maxLevel(data))
	set(player, after)
	setLastSeen(player, now)
	if granted then
		grant(player)
	end
	return granted
end

-- Admin /returning letter: the letter from the start again (seen = 0; it opens on the next entry to the world).
function ReturningService.ResetLetter(player: Player): boolean
	local state = live[player]
	if not state then
		return false
	end
	local s = table.clone(state)
	s.seen = 0
	set(player, s)
	return true
end

function ReturningService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	StatService = registry.Get("StatService")
	local CharacterService = registry.Get("CharacterService")
	StatService.RegisterModifierSource("returning", modifierSource)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		if announce[player] then
			toastGranted(player)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		if live[player] then
			write(player)
		end
	end)
end

function ReturningService.Start()
	PlayerStateService.Ready:Connect(onReady)
	DataService.ProfileReleasing:Connect(release)
	Net.On("ChangelogSeen", onSeen)
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			live[player] = nil
			lastWrite[player] = nil
			announce[player] = nil
		end)
	end)
	task.spawn(function()
		local last = os.clock()
		local sinceSeen = 0
		while true do
			task.wait(TICK)
			local clock = os.clock()
			local dt = clock - last
			last = clock
			step(dt)
			sinceSeen += dt
			if sinceSeen >= LAST_SEEN_EVERY then
				sinceSeen = 0
				local now = Clock.now()
				for player in live do
					setLastSeen(player, now)
				end
			end
		end
	end)
end

return ReturningService
