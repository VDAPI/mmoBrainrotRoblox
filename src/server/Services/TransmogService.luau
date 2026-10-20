--!strict
-- The collection of item looks (S154, docs/DESIGN.md §6b, Logic/Transmog). A look unlocks for the account when an item
-- with it enters the backpack or the equipment of a character (InventoryService.Changed / EquipmentService.Changed:
-- loot, mail, trade, auctions, rewards, the smith and the deposit all go through the backpack), with a toast (a boss
-- look stands out). Once per account (account.transmog.scanned false: the first load after S154) the items in the
-- backpacks, equipment and deposit of every character are scanned without toasts (no mail, no auctions). A look stays
-- after the item is sold or dismantled. Only new keys are written (account.transmog.looks[key] = true). Putting a look
-- on is BlacksmithService.Transmog.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Transmog = require(Shared.Logic.Transmog)
local Types = require(Shared.Types)

local log = Log.new("TransmogService")

type ItemInstance = Types.ItemInstance

local TransmogService = {
	Name = "TransmogService",
	Deps = { "DataService", "PlayerStateService", "InventoryService", "EquipmentService", "CharacterService" },
}

-- Single toasts after one change at most; the rest in one summary line (a big loot bag).
local TOAST_MAX = 3

local DataService: any
local PlayerStateService: any
local InventoryService: any
local EquipmentService: any
local CharacterService: any

-- Players with a check already queued for the end of this frame (many slot changes, one check).
local pending: { [Player]: boolean } = {}

local function looksOf(player: Player): { [string]: boolean }?
	local state = PlayerStateService.Get(player, { "account", "transmog" })
	if type(state) ~= "table" or type(state.looks) ~= "table" then
		return nil
	end
	return state.looks
end

-- Writes the new keys of `keys` and returns them (already owned ones skipped).
local function unlock(player: Player, keys: { string }): { string }
	if not PlayerStateService.HasState(player) then
		return {}
	end
	local looks = looksOf(player)
	if not looks then
		PlayerStateService.Set(player, { "account", "transmog" }, { looks = {}, scanned = false })
		looks = looksOf(player)
	end
	local added: { string } = {}
	for _, key in keys do
		if (looks :: { [string]: boolean })[key] ~= true and Transmog.lookType(key) ~= nil then
			PlayerStateService.Set(player, { "account", "transmog", "looks", key }, true)
			table.insert(added, key)
		end
	end
	return added
end

local function toast(player: Player, added: { string })
	-- boss looks first: they are the rare ones
	table.sort(added, function(a: string, b: string): boolean
		local ba, bb = Transmog.isBoss(a), Transmog.isBoss(b)
		if ba ~= bb then
			return ba
		end
		return a < b
	end)
	for i, key in added do
		if i > TOAST_MAX then
			Net.Fire(player, "Toast", "transmog.unlockedMore", { n = #added - TOAST_MAX }, "info")
			break
		end
		local def = Transmog.lookDef(key)
		local name = `#item:{if def then def.id else key}:0`
		if Transmog.isBoss(key) then
			Net.Fire(player, "Toast", "transmog.unlockedBoss", { name = name }, "success")
		else
			Net.Fire(player, "Toast", "transmog.unlocked", { name = name }, "info")
		end
	end
end

-- The held items of a character's backpack and equipment.
local function itemsOf(char: any): { ItemInstance }
	local out: { ItemInstance } = {}
	if type(char) ~= "table" then
		return out
	end
	for _, branch in { char.inventory, char.equipment } do
		if type(branch) == "table" then
			for _, item in branch do
				if type(item) == "table" then
					table.insert(out, item)
				end
			end
		end
	end
	return out
end

local function check(player: Player)
	local char = PlayerStateService.GetCharacter(player)
	if not char then
		return
	end
	local added = unlock(player, Transmog.unlocks(itemsOf(char)))
	if #added > 0 then
		toast(player, added)
	end
end

local function schedule(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent then
			check(player)
		end
	end)
end

-- The one-time scan of the whole account (every character and the deposit), without toasts.
local function scan(player: Player)
	local data = DataService.GetData(player)
	if type(data) ~= "table" or not PlayerStateService.HasState(player) then
		return
	end
	if Transmog.sanitize(data.transmog).scanned then
		return
	end
	local items: { ItemInstance } = {}
	for _, char in data.characters or {} do
		for _, item in itemsOf(char) do
			table.insert(items, item)
		end
	end
	local deposit = type(data.deposit) == "table" and data.deposit.items or nil
	if type(deposit) == "table" then
		for _, item in deposit do
			if type(item) == "table" then
				table.insert(items, item)
			end
		end
	end
	local added = unlock(player, Transmog.unlocks(items))
	PlayerStateService.Set(player, { "account", "transmog", "scanned" }, true)
	log:info("%s: transmog scan, %d looks", player.Name, #added)
end

-- Admin (/transmoglooks): every look ("all") or none ("clear"); returns the number of looks owned after it.
function TransmogService.AdminSet(player: Player, mode: "all" | "clear"): number
	if mode == "clear" then
		PlayerStateService.Set(player, { "account", "transmog", "looks" }, {})
		return 0
	end
	local keys: { string } = {}
	for _, entry in Transmog.catalogue() do
		for _, list in { entry.base, entry.boss } do
			for _, key in list do
				table.insert(keys, key)
			end
		end
	end
	unlock(player, keys)
	local n = 0
	for _ in Transmog.sanitize(PlayerStateService.Get(player, { "account", "transmog" })).looks do
		n += 1
	end
	return n
end

function TransmogService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	EquipmentService = registry.Get("EquipmentService")
	CharacterService = registry.Get("CharacterService")
end

function TransmogService.Start()
	PlayerStateService.Ready:Connect(scan)
	InventoryService.Changed:Connect(schedule)
	EquipmentService.Changed:Connect(function(player: Player)
		schedule(player)
	end)
	-- a new character's starting gear and anything given while no character was active
	CharacterService.CharacterEntered:Connect(schedule)
end

return TransmogService
