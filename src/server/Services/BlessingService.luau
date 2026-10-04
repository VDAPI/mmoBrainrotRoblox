--!strict
-- Blessings (DESIGN §11) and resistance elixirs (§10): real-time buffs that also tick while offline
-- (expiry is a Util/Clock timestamp). One blessing at a time; replacing an active one needs the client's
-- confirmation (remote UseBlessing). Stats plug into StatService as modifier source "blessing"; the
-- EXP/gold/drop bonuses are ordinary stats read by Combat/Level/Loot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Blessings = require(Shared.Data.Blessings)
local Clock = require(Shared.Util.Clock)
local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local StatCalc = require(Shared.Logic.StatCalc)
local Types = require(Shared.Types)

local BlessingService = {
	Name = "BlessingService",
	Deps = { "PlayerStateService", "InventoryService", "StatService", "CharacterService" },
}

local CHECK_INTERVAL = 5

local PlayerStateService: any
local InventoryService: any
local StatService: any
local CharacterService: any

local function activeBlessing(char: Types.CharacterData, now: number): Blessings.BlessingDef?
	local blessing = char.blessing
	if not blessing or blessing.expiresAt <= now then
		return nil
	end
	return Blessings.get(blessing.id)
end

local function modifierSource(_player: Player, char: Types.CharacterData): StatCalc.Source?
	local now = Clock.now()
	local flat: { [string]: number } = {}
	local any = false
	local blessing = activeBlessing(char, now)
	if blessing then
		for stat, value in blessing.stats do
			flat[stat] = (flat[stat] or 0) + value
		end
		any = true
	end
	local elixirs: { [string]: number } = char.elixirs or {}
	for stat, expiresAt in elixirs do
		if expiresAt > now then
			flat[stat] = (flat[stat] or 0) + Blessings.ELIXIR_VALUE
			any = true
		end
	end
	if not any then
		return nil
	end
	return { key = "source.blessing", flat = flat }
end

local function apply(player: Player, index: number, item: Types.ItemInstance, replace: boolean): (boolean, string?)
	local char = PlayerStateService.GetCharacter(player)
	local def = Items.get(item.id)
	local target = def and def.use and def.use.target
	local blessing = target and Blessings.get(target)
	if not char or not blessing then
		return false, "error.badRequest"
	end
	local now = Clock.now()
	if activeBlessing(char, now) and not replace then
		return false, "blessing.confirmReplace"
	end
	if InventoryService.ConsumeAt(player, index) == nil then
		return false, "error.badRequest"
	end
	PlayerStateService.Set(player, { "character", "blessing" }, {
		id = blessing.id,
		expiresAt = now + Blessings.DURATION,
	})
	StatService.Invalidate(player)
	return true, nil
end

local function useElixir(player: Player, index: number, item: Types.ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	local stat = def and def.use and def.use.target
	if not stat or not table.find(Blessings.ELIXIRS, stat) then
		return false, "error.badRequest"
	end
	if InventoryService.ConsumeAt(player, index) == nil then
		return false, "error.badRequest"
	end
	PlayerStateService.Set(player, { "character", "elixirs", stat }, Clock.now() + Blessings.ELIXIR_DURATION)
	StatService.Invalidate(player)
	Net.Fire(player, "Toast", "elixir.used", { stat = `@stat.{stat}` }, "success")
	return true, nil
end

-- Removes expired buffs from the save and tells the player. Returns true when something changed.
local function expire(player: Player): boolean
	local char = PlayerStateService.GetCharacter(player)
	if not char then
		return false
	end
	local now = Clock.now()
	local changed = false
	if char.blessing and char.blessing.expiresAt <= now then
		PlayerStateService.Set(player, { "character", "blessing" }, nil)
		Net.Fire(player, "Toast", "blessing.expired", nil, "info")
		changed = true
	end
	local elixirs: { [string]: number } = char.elixirs or {}
	for stat, expiresAt in elixirs do
		if expiresAt <= now then
			PlayerStateService.Set(player, { "character", "elixirs", stat }, nil)
			changed = true
		end
	end
	if changed then
		StatService.Invalidate(player)
	end
	return changed
end

-- Admin /bless: grants a blessing directly.
function BlessingService.Grant(player: Player, blessingId: string): boolean
	local blessing = Blessings.get(blessingId)
	if not blessing or not PlayerStateService.GetCharacter(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "blessing" }, {
		id = blessing.id,
		expiresAt = Clock.now() + Blessings.DURATION,
	})
	StatService.Invalidate(player)
	return true
end

-- After /time: re-check every online player right away.
function BlessingService.CheckAll()
	for _, player in Players:GetPlayers() do
		if PlayerStateService.HasState(player) then
			expire(player)
		end
	end
end

function BlessingService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	StatService = registry.Get("StatService")
	CharacterService = registry.Get("CharacterService")
	StatService.RegisterModifierSource("blessing", modifierSource)
	InventoryService.UseHandlers.blessing = function(player, index, item)
		return apply(player, index, item, false)
	end
	InventoryService.UseHandlers.elixir = useElixir
end

function BlessingService.Start()
	Net.Handle("UseBlessing", function(player: Player, index: number): (boolean, string?)
		local item = InventoryService.Get(player, index)
		local def = item and Items.get(item.id)
		if not item or not def or not def.use or def.use.kind ~= "blessing" then
			return false, "error.badRequest"
		end
		return apply(player, index, item, true)
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		expire(player)
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			BlessingService.CheckAll()
		end
	end)
end

return BlessingService
