--!strict
-- Fishing (DESIGN §12). StartFishing(node) checks the rod and distance, then the server waits a random bite
-- delay and rolls the fish — the client never chooses it. On the bite the client gets the minigame
-- parameters (FishingBite) and answers FishingResult(sessionId, hits). The server accepts a catch only for
-- the current session, after at least MIN_DURATION and within TIME_LIMIT of the bite, with all hits.
-- State branch `fishing` = { sessionId, phase = "waiting" | "bite", spot } drives the client.
-- Moving away, damage or leaving cancels. Admin /fish auto makes the next bites succeed by themselves.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Fish = require(Shared.Data.Fish)
local GatherNodes = require(Shared.Data.GatherNodes)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Rng = require(Shared.Logic.Rng)

local log = Log.new("FishingService")

local FishingService = {
	Name = "FishingService",
	Deps = { "PlayerStateService", "InventoryService", "ResourceService", "CharacterService", "GatherService" },
}

type Session = {
	id: string,
	nodeUid: string,
	spot: string,
	fish: Fish.FishEntry,
	biteAt: number?, -- os.clock() of the bite
	start: Vector3,
}

local PlayerStateService: any
local InventoryService: any
local ResourceService: any
local CharacterService: any
local GatherService: any

local rng = Rng.new()
local sessions: { [Player]: Session } = {}
local autoSuccess: { [Player]: boolean } = {}

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function clear(player: Player, toastKey: string?)
	if not sessions[player] then
		return
	end
	sessions[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "fishing" }, nil)
	end
	if toastKey then
		Net.Fire(player, "Toast", toastKey, nil, "warning")
	end
end

local function catch(player: Player, session: Session): (boolean, string?, any)
	local char = PlayerStateService.GetCharacter(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local spot = Fish.get(session.spot)
	local drops: { { id: string, n: number } } = { { id = session.fish.id, n = 1 } }
	local chest = spot ~= nil and rng:chance(spot.chestChance)
	if chest then
		for _, entry in Fish.CHEST_LOOT do
			if rng:chance(entry.chance) then
				table.insert(drops, { id = entry.id, n = rng:int(entry.min, entry.max) })
			end
		end
	end
	local stacks = {}
	for _, drop in drops do
		table.insert(stacks, ItemRoll.makeStack(drop.id, drop.n, "check"))
	end
	if not InventoryService.CanFit(player, stacks) then
		return false, "inventory.full"
	end
	for _, drop in drops do
		InventoryService.GiveNew(player, drop.id, drop.n)
	end
	local gold = 0
	if chest then
		gold = char.level * Fish.CHEST_GOLD
		PlayerStateService.Update(player, { "character", "gold" }, function(value: number)
			return value + gold
		end)
	end
	log:info("%s caught %s%s", player.Name, session.fish.id, if chest then " + chest" else "")
	QuestEvents.fire(player, "fish", { fishId = session.fish.id })
	return true, nil, { fish = session.fish.id, rarity = session.fish.rarity, chest = chest, gold = gold }
end

local function startFishing(player: Player, uid: string): (boolean, string?, string?)
	local node = GatherService.Get(uid)
	if not node or node.kind.category ~= "fishing" or not node.kind.spot then
		return false, "error.badRequest"
	end
	if not PlayerStateService.GetCharacter(player) or ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	if sessions[player] or GatherService.Busy(player) then
		return false, "gather.already"
	end
	if not GatherService.InRange(player, node) then
		return false, "npc.error.tooFar"
	end
	if InventoryService.Count(player, node.kind.tool or "fishing_rod") < 1 then
		return false, "gather.needTool.fishing_rod"
	end
	local spot = Fish.get(node.kind.spot)
	local root = rootOf(player)
	if not spot or not root then
		return false, "error.badRequest"
	end
	local session: Session = {
		id = HttpService:GenerateGUID(false),
		nodeUid = uid,
		spot = node.kind.spot,
		fish = Fish.pick(spot, rng:next()),
		start = root.Position,
	}
	sessions[player] = session
	PlayerStateService.Set(player, { "fishing" }, { sessionId = session.id, phase = "waiting", node = uid })

	local delay = rng:float(Fish.BITE_MIN, Fish.BITE_MAX)
	task.spawn(function()
		local biteAt = os.clock() + delay
		while os.clock() < biteAt do
			task.wait(0.1)
			if sessions[player] ~= session then
				return
			end
			local now = rootOf(player)
			local moved = if now then (now.Position - session.start) * Vector3.new(1, 0, 1) else nil
			if not moved or moved.Magnitude > GatherNodes.MOVE_LIMIT then
				clear(player, "fish.cancelled")
				return
			end
		end
		session.biteAt = os.clock()
		PlayerStateService.Set(player, { "fishing", "phase" }, "bite")
		Net.Fire(player, "FishingBite", session.id, {
			zone = session.fish.zone,
			speed = session.fish.speed,
			hits = Fish.HITS,
			shrink = Fish.ZONE_SHRINK,
			speedUp = Fish.SPEED_UP,
			timeLimit = Fish.TIME_LIMIT,
			auto = autoSuccess[player] == true,
		})
		-- Expire the minigame if the client never answers.
		task.delay(Fish.TIME_LIMIT + 2, function()
			if sessions[player] == session then
				clear(player, "fish.escaped")
			end
		end)
	end)
	return true, nil, session.id
end

local function result(player: Player, sessionId: string, hits: number): (boolean, string?, any)
	local session = sessions[player]
	if not session or session.id ~= sessionId or not session.biteAt then
		return false, "error.badRequest"
	end
	local elapsed = os.clock() - session.biteAt
	sessions[player] = nil
	PlayerStateService.Set(player, { "fishing" }, nil)
	local auto = autoSuccess[player] == true
	if not auto and (hits < Fish.HITS or elapsed < Fish.MIN_DURATION or elapsed > Fish.TIME_LIMIT + 1) then
		if hits >= Fish.HITS then
			log:warn("%s fishing result rejected (%.2f s)", player.Name, elapsed)
		end
		return false, "fish.escaped"
	end
	return catch(player, session)
end

function FishingService.SetAuto(player: Player, enabled: boolean)
	(autoSuccess :: any)[player] = if enabled then true else nil
end

function FishingService.IsAuto(player: Player): boolean
	return autoSuccess[player] == true
end

function FishingService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	ResourceService = registry.Get("ResourceService")
	CharacterService = registry.Get("CharacterService")
	GatherService = registry.Get("GatherService")
end

function FishingService.Start()
	Net.Handle("StartFishing", startFishing)
	Net.Handle("FishingResult", result)
	Net.On("CancelFishing", function(player: Player)
		clear(player, nil)
	end)
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 and sessions[player] then
			clear(player, "fish.cancelled")
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		clear(player, nil)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		autoSuccess[player] = nil
	end)
end

return FishingService
