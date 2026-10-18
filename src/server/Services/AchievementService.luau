--!strict
-- Achievements (S151, docs/DESIGN.md §20b): counts game events into the account and character counters
-- (Logic/Achievements), marks achievements done and gives their rewards (a title, a cosmetic, Dragon Shards once per
-- account, a little gold), then tells the client (AchievementDone; AchievementController shows the toast).
-- Sources: QuestEvents (every service fires there; nothing calls this service) plus the two signals QuestService also
-- listens to, CombatService.MonsterKilled ("kill", with the hideout) and LevelService.LevelChanged ("level").
-- Entering the world applies Achievements.backfill (old progress the save proves; idempotent) with one summary toast
-- and at most Config.Achievements.backfillToastMax single ones.
-- Hot path: a kill arrives for every credited player. One pass of Logic per event without a yield, the branch tables
-- cached per character, achievements looked up by counter (Data/Achievements.byCounter), and only the changed leaves
-- written ({ "character", "ach", "c", "kills" } …), so the state diff of a kill stays a few numbers.
-- S151b: AchievementTrack follows / stops following an achievement in the HUD tracker (Logic/Achievements.canTrack,
-- character.ach.track); a done achievement leaves the tracker in grant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local AchData = require(Shared.Data.Achievements)
local Achievements = require(Shared.Logic.Achievements)
local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Types = require(Shared.Types)

local log = Log.new("AchievementService")

type State = Achievements.State
type Entry = Achievements.Entry
type AchDef = AchData.AchDef

local AchievementService = {
	Name = "AchievementService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"TitleService",
		"CosmeticService",
		"LevelService",
		"CombatService",
	},
}

local PlayerStateService: any
local CharacterService: any
local TitleService: any
local CosmeticService: any
local LevelService: any
local CombatService: any
local SeasonService: any -- S152: season pass points (registry.Get only, no Deps)

-- Seconds after entering the world before the catch-up toasts (the HUD is up by then).
local BACKFILL_TOAST_DELAY = 4

-- The live branches of the player's account and character (the save's own tables), rebuilt when the character changes.
local cache: { [Player]: { character: any, st: State } } = {}

local function rootOf(counter: string): string
	return if Achievements.scopeOf(counter) == "account" then "account" else "character"
end

local function stateOf(player: Player): State?
	if not PlayerStateService.HasState(player) then
		return nil
	end
	local character = PlayerStateService.GetCharacter(player)
	if not character then
		return nil
	end
	local cached = cache[player]
	if cached and cached.character == character then
		return cached.st
	end
	local st = Achievements.state(PlayerStateService.Get(player, { "account" }), character)
	cache[player] = { character = character, st = st }
	return st
end

export type Payload = { id: string, reward: { title: string?, cosmetic: string?, shards: number?, gold: number? } }

-- Marks `def` done and gives its reward. Done (and the shards' paid flag) are written before anything that could
-- yield, so the same achievement never pays twice. Nil when it was done already.
local function grant(player: Player, st: State, def: AchDef): Payload?
	local root = rootOf(def.counter)
	local branch = if root == "account" then st.acc else st.chr
	if branch.done[def.id] ~= nil then
		return nil
	end
	local now = os.time()
	branch.done[def.id] = now
	PlayerStateService.Set(player, { root, "ach", "done", def.id }, now)
	local paid = st.acc.paid or {}
	local r = Achievements.reward(def, paid)
	if r.shards > 0 then
		paid[def.id] = true
		st.acc.paid = paid
		PlayerStateService.Set(player, { "account", "ach", "paid", def.id }, true)
		if root == "character" then
			-- S151b: the window shows the amount only on the character that received it
			local here = st.chr.paidHere or {}
			here[def.id] = true
			st.chr.paidHere = here
			PlayerStateService.Set(player, { "character", "ach", "paidHere", def.id }, true)
		end
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(value: number?)
			return (value or 0) + r.shards
		end)
		Analytics.shards(player, r.shards, total, "achievement")
	end
	if r.gold > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(value: number?)
			return (value or 0) + r.gold
		end)
		Analytics.gold(player, r.gold, balance, "achievement")
	end
	-- S151b: a done achievement is not followed any more
	local _, _, untracked = Achievements.setTracked(st, def.id, false)
	if untracked then
		PlayerStateService.Set(player, { "character", "ach", "track" }, table.clone(Achievements.tracked(st)))
	end
	if r.title then
		TitleService.Refresh(player)
	end
	if r.cosmetic then
		-- quiet: the achievement's toast names it; an owned one (bought or earned before) is simply kept
		CosmeticService.Grant(player, r.cosmetic, nil, true)
	end
	log:info("%s: achievement %s (%d shards)", player.Name, def.id, r.shards)
	return {
		id = def.id,
		reward = {
			title = r.title,
			cosmetic = r.cosmetic,
			shards = if r.shards > 0 then r.shards else nil,
			gold = if r.gold > 0 then r.gold else nil,
		},
	}
end

-- Applies counter changes and writes the changed leaves; returns the achievements met and not done, in order.
local function applyEntries(player: Player, st: State, entries: { Entry }): { string }
	local newly: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, e in entries do
		local result = Achievements.apply(st, e.counter, e.mode, e.value, e.key)
		if result.changed then
			local root = rootOf(e.counter)
			local branch = if root == "account" then st.acc else st.chr
			PlayerStateService.Set(player, { root, "ach", "c", e.counter }, branch.c[e.counter])
			if e.mode == "set" and e.key then
				PlayerStateService.Set(player, { root, "ach", "s", e.counter, e.key }, true)
			end
		end
		for _, id in result.newly do
			if not seen[id] then
				seen[id] = true
				table.insert(newly, id)
			end
		end
	end
	return newly
end

local function grantAll(player: Player, st: State, ids: { string }): { Payload }
	local out: { Payload } = {}
	for _, id in ids do
		local def = AchData.get(id)
		if def then
			local payload = grant(player, st, def)
			if payload then
				table.insert(out, payload)
			end
		end
	end
	return out
end

local function handle(player: Player, kind: string, data: { [string]: any }?)
	local entries = Achievements.entriesFor(kind, data)
	if #entries == 0 then
		return
	end
	local st = stateOf(player)
	if not st then
		return
	end
	local newly = applyEntries(player, st, entries)
	if #newly == 0 then
		return
	end
	local granted = grantAll(player, st, newly)
	for _, payload in granted do
		Net.Fire(player, "AchievementDone", payload)
	end
	if #granted > 0 then
		-- S152: an achievement earned in play (never the catch-up of old progress on entering)
		SeasonService.Add(player, "achievement", #granted)
	end
end

-- The catch-up of old progress on entering the world (and /ach backfill): the whole branches are written once, every
-- achievement met and not done is granted; one summary toast, then the best few single ones.
local function catchUp(player: Player, delay: number?): number
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return 0
	end
	cache[player] = nil
	local account = PlayerStateService.Get(player, { "account" })
	local st = stateOf(player)
	if not st then
		return 0
	end
	local ids = Achievements.applyAll(st, Achievements.backfill(account, character))
	PlayerStateService.Set(player, { "account", "ach" }, st.acc)
	PlayerStateService.Set(player, { "character", "ach" }, st.chr)
	local granted = grantAll(player, st, ids)
	if #granted == 0 then
		return 0
	end
	table.sort(granted, function(a: Payload, b: Payload): boolean
		local da, db = AchData.get(a.id), AchData.get(b.id)
		local pa, pb = if da then da.points else 0, if db then db.points else 0
		if pa ~= pb then
			return pa > pb
		end
		return a.id < b.id
	end)
	local mine = character
	task.delay(delay or BACKFILL_TOAST_DELAY, function()
		if player.Parent == nil or PlayerStateService.GetCharacter(player) ~= mine then
			return
		end
		Net.Fire(player, "AchievementDone", { backfill = #granted })
		for i = 1, math.min(#granted, Config.Achievements.backfillToastMax) do
			Net.Fire(player, "AchievementDone", granted[i])
		end
	end)
	return #granted
end

-- Admin (S23, /ach) -----------------------------------------------------------------------------------------------------

-- Lines "id: value / goal [done]" of every achievement of the player's account and character (nil without one).
function AchievementService.List(player: Player): { string }?
	local st = stateOf(player)
	if not st then
		return nil
	end
	local lines: { string } = {}
	for _, def in AchData.list do
		local value, goal = Achievements.progress(st, def)
		local mark = if Achievements.isDone(st, def) then " ✓" else ""
		table.insert(lines, `{def.id}: {value}/{goal}{mark}`)
	end
	return lines
end

-- Grants `id` with its reward (shards only when not paid before). False for an unknown or done one.
function AchievementService.Give(player: Player, id: string): boolean
	local def = AchData.get(id)
	local st = stateOf(player)
	if not def or not st then
		return false
	end
	local payload = grant(player, st, def)
	if payload then
		Net.Fire(player, "AchievementDone", payload)
	end
	return payload ~= nil
end

-- Forgets `id` (or "all": every done achievement and every counter of the account and the character). The paid
-- shards stay paid. Returns how many achievements were forgotten (nil without a character or for an unknown id).
function AchievementService.Reset(player: Player, id: string): number?
	local st = stateOf(player)
	if not st then
		return nil
	end
	if id == "all" then
		local n = 0
		for _, branch in { st.acc, st.chr } do
			for _ in branch.done do
				n += 1
			end
			table.clear(branch.done)
			table.clear(branch.c)
			table.clear(branch.s)
		end
		PlayerStateService.Set(player, { "account", "ach" }, st.acc)
		PlayerStateService.Set(player, { "character", "ach" }, st.chr)
		return n
	end
	local def = AchData.get(id)
	if not def then
		return nil
	end
	local root = rootOf(def.counter)
	local branch = if root == "account" then st.acc else st.chr
	if branch.done[id] == nil then
		return 0
	end
	branch.done[id] = nil
	PlayerStateService.Set(player, { root, "ach", "done", id }, nil)
	return 1
end

-- Sets a counter (a set counter: 0 empties it) and grants what it reaches. False for an unknown counter.
function AchievementService.SetCounter(player: Player, counter: string, value: number): boolean
	local def = AchData.COUNTERS[counter]
	local st = stateOf(player)
	if not def or not st then
		return false
	end
	local root = rootOf(counter)
	local branch = if root == "account" then st.acc else st.chr
	if def.mode == "set" then
		if value > 0 then
			return false
		end
		branch.s[counter] = {}
		branch.c[counter] = 0
		PlayerStateService.Set(player, { root, "ach", "s", counter }, {})
	else
		branch.c[counter] = math.max(0, math.floor(value))
	end
	PlayerStateService.Set(player, { root, "ach", "c", counter }, branch.c[counter])
	for _, payload in grantAll(player, st, Achievements.pending(st, counter)) do
		Net.Fire(player, "AchievementDone", payload)
	end
	return true
end

-- Runs the catch-up of old progress now (toasts at once). Returns how many achievements it granted.
function AchievementService.Backfill(player: Player): number
	return catchUp(player, 0)
end

-- S151b: (achId, on) -> (ok, errKey?): the tracker list of the character (character.ach.track).
local function track(player: Player, id: string, on: boolean): (boolean, string?)
	local st = stateOf(player)
	if not st then
		return false, "error.internal"
	end
	local ok, err, changed = Achievements.setTracked(st, id, on)
	if not ok then
		return false, err
	end
	if changed then
		PlayerStateService.Set(player, { "character", "ach", "track" }, table.clone(Achievements.tracked(st)))
	end
	return true, nil
end

function AchievementService.Init(registry)
	SeasonService = registry.Get("SeasonService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	TitleService = registry.Get("TitleService")
	CosmeticService = registry.Get("CosmeticService")
	LevelService = registry.Get("LevelService")
	CombatService = registry.Get("CombatService")
end

function AchievementService.Start()
	Net.Handle("AchievementTrack", track)
	QuestEvents.Fired:Connect(function(player: Player, kind: string, data: { [string]: any })
		handle(player, kind, data)
	end)
	CombatService.MonsterKilled:Connect(function(info: any, credit: { Player })
		local data = { variant = info.variant, lair = info.lair }
		for _, player in credit do
			handle(player, "kill", data)
		end
	end)
	LevelService.LevelChanged:Connect(function(player: Player, level: number)
		handle(player, "level", { level = level })
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		catchUp(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		cache[player] = nil
	end)
end

return AchievementService
