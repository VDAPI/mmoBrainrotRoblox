--!strict
-- What item slot interactions mean (UI/DragDrop ids):
--   "inv:N"    backpack slot N
--   "eq:<slot>" equipment slot (weapon, ring1, backpack, ...)
--   "pot:<kind>" potion bar slot (hp / mana / energy)
-- inv→inv moves, inv→eq equips (with the bind confirmation), eq→inv unequips, inv→pot assigns a potion.
-- Double-click / tap-again activates: equip, use, unequip, drink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local DragDrop = require(script.Parent.Parent.UI.DragDrop)
local ItemText = require(script.Parent.Parent.UI.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

type ItemInstance = Types.ItemInstance

local ItemController = {
	Name = "ItemController",
	Deps = { "WindowManager", "UIController", "NpcController", "GatherController" },
}

local WindowManager: any
local NpcController: any
local GatherController: any

local function parse(slotId: string): (string, string)
	local kind, rest = string.match(slotId, "^(%a+):(.+)$")
	return kind or "", rest or ""
end

function ItemController.ItemAt(slotId: string): ItemInstance?
	local kind, rest = parse(slotId)
	if kind == "inv" then
		return State.Get({ "character", "inventory", rest })
	elseif kind == "eq" then
		return State.Get({ "character", "equipment", rest })
	elseif kind == "dep" then
		return State.Get({ "account", "deposit", "items", rest })
	elseif kind == "pot" then
		local id = State.Get({ "character", "potionBar", rest })
		if not id then
			return nil
		end
		for _, item in State.Get({ "character", "inventory" }) or {} do
			if item.id == id then
				return item
			end
		end
	end
	return nil
end

local function report(ok: any, err: any)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(if type(err) == "string" then err else "error.internal"), "error")
	end
end

local function invoke(name: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		report(Net.Invoke(name, table.unpack(args, 1, args.n)))
	end)
end

-- Equip with the "this item will bind" confirmation (DESIGN §5.6) unless disabled in the menu.
function ItemController.Equip(index: number, slot: string?)
	local item = State.Get({ "character", "inventory", tostring(index) })
	if not item then
		return
	end
	local def = Items.get(item.id)
	local ask = State.Get({ "account", "settings", "bindConfirm" }) ~= false
	if item.bound or not ask or (def and def.category == "backpack") then
		invoke("EquipItem", index, slot)
		return
	end
	WindowManager.ShowModal({
		Title = Text.now("equip.bind.title"),
		Message = Text.now("equip.bind.message", { name = ItemText.name(item.id, item.up, item.el) }),
		ConfirmText = Text.now("equip.bind.confirm"),
		CancelText = Text.now("common.cancel"),
		OnConfirm = function(): (boolean, string?)
			local ok, err = Net.Invoke("EquipItem", index, slot)
			if ok then
				return true, nil
			end
			return false, Text.now(err or "error.internal")
		end,
	})
end

function ItemController.Unequip(slot: string, index: number?)
	invoke("UnequipItem", slot, index)
end

function ItemController.Use(index: number)
	local item = State.Get({ "character", "inventory", tostring(index) })
	if item and item.id == "scroll_unbind" then
		-- The scroll needs a target: pick a bound item first.
		NpcController.OpenUnbind()
		return
	end
	local def = item and Items.get(item.id)
	local use = def and def.use
	if use and use.kind == "teleport" and (use.target == "map" or use.target == "dungeon") then
		GatherController.OpenStonePicker(index, use.target)
		return
	end
	local blessing = State.Get({ "character", "blessing" })
	if use and use.kind == "blessing" and type(blessing) == "table" and blessing.expiresAt > Clock.now() then
		-- One blessing at a time (DESIGN §11): ask before replacing the active one.
		WindowManager.ShowModal({
			Title = Text.now("blessing.replace.title"),
			Message = Text.now("blessing.replace.message"),
			ConfirmText = Text.now("blessing.replace.confirm"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(): (boolean, string?)
				local ok, err = Net.Invoke("UseBlessing", index)
				return ok, if ok then nil else Text.now(err or "error.internal")
			end,
		})
		return
	end
	invoke("UseItem", index)
end

function ItemController.Destroy(index: number)
	local item = State.Get({ "character", "inventory", tostring(index) })
	if not item then
		return
	end
	local name = ItemText.name(item.id, item.up, item.el)
	WindowManager.ShowModal({
		Title = Text.now("inventory.drop.title"),
		Message = Text.now("inventory.drop.message", { name = name }),
		ConfirmText = Text.now("inventory.drop.confirm"),
		CancelText = Text.now("common.cancel"),
		Variant = "danger",
		OnConfirm = function(): (boolean, string?)
			local ok, err = Net.Invoke("DestroyItem", index)
			if ok then
				Toast.push(Text.now("inventory.dropped", { name = name }), "info")
				return true, nil
			end
			return false, Text.now(err or "error.internal")
		end,
	})
end

function ItemController.Split(index: number)
	local item = State.Get({ "character", "inventory", tostring(index) })
	if not item or item.n < 2 then
		return
	end
	WindowManager.ShowModal({
		Title = Text.now("inventory.split.title"),
		Message = Text.now("inventory.split.message", { name = ItemText.name(item.id) }),
		ConfirmText = Text.now("inventory.split.confirm"),
		CancelText = Text.now("common.cancel"),
		Input = { Placeholder = tostring(math.floor(item.n / 2)), MaxLength = 3 },
		OnConfirm = function(text: string): (boolean, string?)
			local amount = tonumber(text) or math.floor(item.n / 2)
			local ok, err = Net.Invoke("SplitStack", index, math.floor(amount))
			if ok then
				return true, nil
			end
			return false, Text.now(err or "error.internal")
		end,
	})
end

function ItemController.SetPotion(kind: string, itemId: string?)
	invoke("SetPotionSlot", kind, itemId)
end

function ItemController.UsePotion(kind: string)
	task.spawn(function()
		local ok, err = Net.Invoke("UsePotion", kind)
		if not ok and err ~= "potion.cooldown" then
			report(ok, err)
		end
	end)
end

-- Primary action of a slot (double click / tap again).
function ItemController.Activate(slotId: string)
	local kind, rest = parse(slotId)
	if kind == "inv" then
		local index = tonumber(rest) :: number
		local item = ItemController.ItemAt(slotId)
		local def = item and Items.get(item.id)
		if not def then
			return
		end
		if State.Get({ "trade" }) ~= nil then
			-- While trading, double-click puts the item on the table.
			invoke("TradeAddItem", index)
			return
		end
		if def.slot then
			ItemController.Equip(index, nil)
		else
			ItemController.Use(index)
		end
	elseif kind == "eq" then
		ItemController.Unequip(rest, nil)
	elseif kind == "pot" then
		ItemController.UsePotion(rest)
	elseif kind == "dep" then
		invoke("WithdrawItem", tonumber(rest), nil)
	end
end

local function onDrop(from: string, to: string)
	local fromKind, fromRest = parse(from)
	local toKind, toRest = parse(to)
	if fromKind == "inv" and toKind == "inv" then
		invoke("MoveItem", tonumber(fromRest), tonumber(toRest))
	elseif fromKind == "inv" and toKind == "eq" then
		ItemController.Equip(tonumber(fromRest) :: number, toRest)
	elseif fromKind == "eq" and toKind == "inv" then
		ItemController.Unequip(fromRest, tonumber(toRest))
	elseif fromKind == "inv" and toKind == "dep" then
		invoke("DepositItem", tonumber(fromRest), tonumber(toRest))
	elseif fromKind == "dep" and toKind == "inv" then
		invoke("WithdrawItem", tonumber(fromRest), tonumber(toRest))
	elseif fromKind == "dep" and toKind == "dep" then
		invoke("MoveDeposit", tonumber(fromRest), tonumber(toRest))
	elseif fromKind == "inv" and toKind == "shopsell" then
		local sell = DragDrop.SellHandler
		if sell then
			sell(tonumber(fromRest) :: number)
		end
	elseif fromKind == "inv" and toKind == "trade" then
		invoke("TradeAddItem", tonumber(fromRest))
	elseif (fromKind == "inv" or fromKind == "eq") and toKind == "smith" then
		NpcController.SetUpgradeTarget(fromKind, fromRest)
	elseif fromKind == "inv" and toKind == "pot" then
		local item = ItemController.ItemAt(from)
		local def = item and Items.get(item.id)
		if def and def.use and def.use.kind == "potion" and def.use.resource == toRest then
			ItemController.SetPotion(toRest, def.id)
		else
			report(false, "error.badRequest")
		end
	end
end

function ItemController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	NpcController = registry.Get("NpcController")
	GatherController = registry.Get("GatherController")
	local UIController = registry.Get("UIController")
	UIController.AddDragVisual(function(slotId: string): (string?, string?)
		local item = ItemController.ItemAt(slotId)
		local def = item and Items.get(item.id)
		if def then
			return def.icon.glyph, def.icon.color
		end
		return nil, nil
	end)
	DragDrop.AddHandlers({
		owns = function(slotId: string): boolean
			local kind = parse(slotId)
			return kind == "inv" or kind == "eq" or kind == "pot" or kind == "dep" or kind == "smith" or kind == "trade"
		end,
		drop = onDrop,
		activate = ItemController.Activate,
		hasItem = function(slotId: string): boolean
			local kind = parse(slotId)
			return kind ~= "pot" and kind ~= "smith" and kind ~= "trade" and ItemController.ItemAt(slotId) ~= nil
		end,
	})
end

-- Potion hotkeys (DESIGN §9 uses Z/X/C; C opens the character window, so energy is on V). Rebindable (S17).
local POTION_ACTIONS: { [string]: string } = {
	potion_hp = "hp",
	potion_mana = "mana",
	potion_energy = "energy",
}

function ItemController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.Get({ "session", "phase" }) ~= "playing" then
			return
		end
		local action = Keybinds.actionFor(input.KeyCode)
		local kind = if action then POTION_ACTIONS[action] else nil
		if kind then
			ItemController.UsePotion(kind)
		end
	end)
end

return ItemController
