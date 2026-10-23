--!strict
-- Shared state of the admin command modules (S23): the services (filled by AdminService.Init before the
-- modules are required), reply capture for the dev panel and small helpers every module uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Classes = require(Shared.Data.Classes)
local DevPreset = require(Shared.Logic.DevPreset)
local ItemBest = require(Shared.Logic.ItemBest)
local ItemRoll = require(Shared.Logic.ItemRoll)
local ItemScore = require(Shared.Logic.ItemScore)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local Context = {}

-- Service name -> service, set by AdminService.Init.
Context.services = {} :: { [string]: any }
Context.log = Log.new("AdminService")
Context.MAX_AMOUNT = 1e12
-- Monster variant by number in commands (/spawn, /lootsim).
Context.VARIANTS = { [0] = "normal", [1] = "elite", [2] = "elite2" }

export type Line = { key: string, args: { [string]: any }? }

-- While a panel call runs, its replies are collected here instead of going to the chat.
local capture: { [Player]: { Line }? } = {}

-- Reply to the caller: a system chat line, or a result line of the dev panel call that is running.
function Context.reply(player: Player, key: string, args: { [string]: any }?)
	local lines = capture[player]
	if lines then
		table.insert(lines, { key = key, args = args })
		return
	end
	Net.Fire(player, "SystemMessage", key, args)
end

-- Starts / stops collecting replies of `player` (AdminService.Run for the panel).
function Context.capture(player: Player, lines: { Line }?)
	capture[player] = lines
end

-- Whole number from a chat argument within +-MAX_AMOUNT, or nil.
function Context.parseAmount(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) > Context.MAX_AMOUNT then
		return nil
	end
	return math.floor(n)
end

-- Runs `fn` only when the caller is in the world with a character.
function Context.withCharacter(player: Player, fn: () -> ())
	if Context.services.PlayerStateService.GetCharacter(player) == nil then
		Context.reply(player, "admin.needCharacter")
		return
	end
	fn()
end

-- S32: the player as Logic/FightSim sees them (current stats, legendary effects, class attack kind).
function Context.simPlayer(player: Player, character: any): any
	local values = (Context.services.StatService.Get(player) or { values = {} }).values
	local class = Classes.get(character.class)
	return {
		level = character.level,
		values = values,
		hooks = Context.services.EquipmentService.GetHooks(player),
		magic = class ~= nil and class.basicAttack.kind == "magic",
	}
end

-- Owner 2026-10-23: dev grants roll the best item for the character's class (Logic/ItemBest). The element of a Mage
-- weapon: `element` when valid, else the equipped weapon's.
local function elementFor(character: any, element: string?): string?
	if element and element ~= "none" then
		return element
	end
	local weapon = character.equipment and character.equipment.weapon
	return if weapon then ItemRoll.elementOf(weapon) else nil
end

function Context.bestItem(
	character: any,
	defId: string,
	ilvl: number,
	rarity: number,
	up: number,
	element: string?
): any
	return ItemBest.roll(
		defId,
		ilvl,
		rarity,
		Context.services.InventoryService.NewUid(),
		ItemScore.contextFor(character),
		{ up = up, element = elementFor(character, element) }
	)
end

-- The class's full set at `ilvl` (Logic/DevPreset, keeping the weapon and off-hand types the character uses) rolled
-- best, added to the backpack and equipped through the normal Equip path (old pieces go to the backpack; pieces above
-- the character's level stay there). Returns the number equipped and whether the backpack ran out of room.
function Context.giveBestSet(player: Player, ilvl: number, rarity: number, up: number): (number, boolean)
	local services = Context.services
	local character = services.PlayerStateService.GetCharacter(player)
	local equipment = character.equipment or {}
	local function typeOf(item: any): string?
		local def = if item then Items.get(item.id) else nil
		return if def then def.type else nil
	end
	local pieces = DevPreset.pick(
		character.class,
		ilvl,
		{ weapon = typeOf(equipment.weapon), offhand = typeOf(equipment.offhand) }
	)
	local items = ItemBest.set(
		pieces,
		ilvl,
		rarity,
		ItemScore.contextFor(character),
		services.InventoryService.NewUid,
		{ up = up, element = elementFor(character, nil) }
	)
	local equipped = 0
	for i, item in items do
		if services.InventoryService.AddItem(player, item) > 0 then
			return equipped, true
		end
		local index = services.InventoryService.IndexOf(player, item.uid)
		if index and services.EquipmentService.Equip(player, index, pieces[i].slot) then
			equipped += 1
		end
	end
	return equipped, false
end

-- Admin check (AdminService.IsAdmin), set by AdminService.Init.
Context.isAdmin = function(_player: Player): boolean
	return false
end

return Context
