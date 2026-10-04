--!strict
-- Equipping (DESIGN §5.1, §5.6, §5.7). Validates level and class, handles rings (ring1/ring2), two-handed
-- weapons (they push the off-hand back into the backpack), backpack swaps (only when everything fits) and
-- binding on equip. Plugs equipment into StatService (modifier source + weapon provider), exposes legendary
-- effect totals (hooks) and shows the weapon in the character's hand (placeholder parts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Rarities = require(Shared.Data.Rarities)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

type ItemInstance = Types.ItemInstance

local EquipmentService = {
	Name = "EquipmentService",
	Deps = { "PlayerStateService", "CharacterService", "InventoryService", "StatService" },
	-- (player, slot) after an equipment slot changed.
	Changed = Signal.new(),
}

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local StatService: any

local hookCache: { [Player]: { [string]: number } } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

-- Sum of legendary effects from equipped items, e.g. { bossDamage = 8, doubleAttack = 5 }.
function EquipmentService.GetHooks(player: Player): { [string]: number }
	local cached = hookCache[player]
	if cached then
		return cached
	end
	local hooks: { [string]: number } = {}
	local char = character(player)
	if char then
		for slot, item in char.equipment do
			if slot ~= "backpack" then
				for hook, value in ItemRoll.itemStats(item).hooks do
					hooks[hook] = (hooks[hook] or 0) + value
				end
			end
		end
	end
	hookCache[player] = hooks
	return hooks
end

function EquipmentService.GetHook(player: Player, hook: string): number
	return EquipmentService.GetHooks(player)[hook] or 0
end

-- Weapon visuals ------------------------------------------------------------------------------------------

local WEAPON_SHAPES: { [string]: { size: Vector3, color: Color3, material: Enum.Material, leftHand: boolean? } } = {
	sword1h = { size = Vector3.new(0.25, 0.4, 3.2), color = Color3.fromHex("#C9CED6"), material = Enum.Material.Metal },
	axe1h = { size = Vector3.new(0.3, 1.2, 2.6), color = Color3.fromHex("#8E8E93"), material = Enum.Material.Metal },
	mace1h = { size = Vector3.new(0.6, 0.6, 2.6), color = Color3.fromHex("#8E8E93"), material = Enum.Material.Metal },
	sword2h = { size = Vector3.new(0.3, 0.5, 4.6), color = Color3.fromHex("#C9CED6"), material = Enum.Material.Metal },
	axe2h = { size = Vector3.new(0.35, 1.6, 4), color = Color3.fromHex("#8E8E93"), material = Enum.Material.Metal },
	hammer2h = { size = Vector3.new(1.1, 1.1, 4), color = Color3.fromHex("#6F6F75"), material = Enum.Material.Metal },
	bow = {
		size = Vector3.new(0.2, 4, 0.3),
		color = Color3.fromHex("#8A6B4A"),
		material = Enum.Material.Wood,
		leftHand = true,
	},
	crossbow = {
		size = Vector3.new(1.6, 0.4, 2.2),
		color = Color3.fromHex("#5A4632"),
		material = Enum.Material.Wood,
		leftHand = true,
	},
	wand = { size = Vector3.new(0.2, 0.2, 1.8), color = Color3.fromHex("#4A8FE7"), material = Enum.Material.Neon },
	staff = { size = Vector3.new(0.3, 0.3, 5), color = Color3.fromHex("#6B4A2B"), material = Enum.Material.Wood },
	scepter = { size = Vector3.new(0.3, 0.3, 2.4), color = Color3.fromHex("#E8C25A"), material = Enum.Material.Metal },
}

local function rarityColor(item: ItemInstance): Color3
	local rarity = Rarities.get(item.rarity)
	return Color3.fromHex(if rarity then rarity.color else "#C9CED6")
end

local function updateWeaponModel(player: Player)
	local model = player.Character
	if not model then
		return
	end
	local old = model:FindFirstChild("VaelthornWeapon")
	if old then
		old:Destroy()
	end
	local char = character(player)
	local item = char and char.equipment.weapon
	local def = item and Items.get(item.id)
	if not item or not def then
		return
	end
	local shape = WEAPON_SHAPES[def.type]
	if not shape then
		return
	end
	local hand = model:FindFirstChild(if shape.leftHand then "LeftHand" else "RightHand")
		or model:FindFirstChild(if shape.leftHand then "Left Arm" else "Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local part = Instance.new("Part")
	part.Name = "VaelthornWeapon"
	part.Size = shape.size
	part.Color = shape.color
	part.Material = shape.material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -shape.size.Z / 2 + 0.3)
	if item.rarity >= Rarities.EPIC then
		local light = Instance.new("PointLight")
		light.Color = rarityColor(item)
		light.Range = 6
		light.Brightness = 1
		light.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

-- Equip / unequip -----------------------------------------------------------------------------------------

local function changed(player: Player, slots: { string })
	local char = character(player)
	if not char then
		return
	end
	for _, slot in slots do
		PlayerStateService.Set(player, { "character", "equipment", slot }, char.equipment[slot])
		EquipmentService.Changed:Fire(player, slot)
	end
	hookCache[player] = nil
	StatService.Invalidate(player)
	if table.find(slots, "weapon") then
		updateWeaponModel(player)
	end
end

local function canUse(char: Types.CharacterData, def: Items.ItemDef): (boolean, string?)
	if char.level < def.level then
		return false, "equip.error.level"
	end
	if def.classes and not table.find(def.classes, char.class) then
		return false, "equip.error.class"
	end
	return true, nil
end

local function resolveSlot(char: Types.CharacterData, def: Items.ItemDef, requested: string?): string?
	local group = def.slot
	if not group then
		return nil
	end
	if group == "ring" then
		if requested == "ring1" or requested == "ring2" then
			return requested
		end
		if char.equipment.ring1 == nil then
			return "ring1"
		elseif char.equipment.ring2 == nil then
			return "ring2"
		end
		return "ring1"
	end
	if requested ~= nil and requested ~= group then
		return nil
	end
	return group
end

function EquipmentService.Equip(player: Player, index: number, requested: string?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local key = tostring(index)
	local item = char.inventory[key]
	local def = item and Items.get(item.id)
	if not item or not def or not def.slot then
		return false, "equip.error.slot"
	end
	local ok, err = canUse(char, def)
	if not ok then
		return false, err
	end
	local slot = resolveSlot(char, def, requested)
	if not slot then
		return false, "equip.error.slot"
	end
	local equipment = char.equipment
	local inventory = char.inventory
	local capacity = InventoryService.CapacityOf(char)

	-- Off-hand is blocked by a two-handed weapon.
	if slot == "offhand" then
		local weapon = equipment.weapon
		local weaponDef = weapon and Items.get(weapon.id)
		if weaponDef and weaponDef.weapon and weaponDef.weapon.twoHanded then
			return false, "equip.error.twoHanded"
		end
	end

	-- Backpacks: the current contents (plus the old backpack) must fit the new capacity.
	if slot == "backpack" then
		local newCapacity = def.capacity or capacity
		local used = Inventory.used(inventory) -- the new backpack leaves, the old one takes its place
		if used > newCapacity then
			return false, "equip.error.backpackFit"
		end
		local old = equipment.backpack
		inventory[key] = nil
		equipment.backpack = item
		item.bound = true
		if old then
			inventory[key] = old
		end
		if newCapacity < capacity then
			Inventory.compact(inventory, newCapacity)
		end
		InventoryService.SyncAll(player)
		changed(player, { "backpack" })
		return true, nil
	end

	-- A two-handed weapon pushes the off-hand into the backpack.
	local touched = { slot }
	local offhandToStore: ItemInstance? = nil
	if slot == "weapon" and def.weapon and def.weapon.twoHanded and equipment.offhand then
		offhandToStore = equipment.offhand
	end

	local previous = equipment[slot]
	inventory[key] = previous -- swap (nil when the slot was empty)
	if offhandToStore then
		local free = if inventory[key] == nil then index else Inventory.firstFree(inventory, capacity)
		if not free then
			inventory[key] = item -- undo
			return false, "equip.error.full"
		end
		inventory[tostring(free)] = offhandToStore :: ItemInstance
		(equipment :: any).offhand = nil
		table.insert(touched, "offhand")
		InventoryService.SetSlot(player, free, offhandToStore)
	end
	item.bound = true
	equipment[slot] = item
	InventoryService.SetSlot(player, index, inventory[key])
	changed(player, touched)
	return true, nil
end

function EquipmentService.Unequip(player: Player, slot: string, targetIndex: number?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if slot == "backpack" then
		return false, "equip.error.backpackSlot"
	end
	local item = char.equipment[slot]
	if not item then
		return false, "error.badRequest"
	end
	local capacity = InventoryService.CapacityOf(char)
	local index: number? = nil
	if
		targetIndex
		and targetIndex >= 1
		and targetIndex <= capacity
		and char.inventory[tostring(targetIndex)] == nil
	then
		index = targetIndex
	else
		index = Inventory.firstFree(char.inventory, capacity)
	end
	if not index then
		return false, "equip.error.full"
	end
	char.equipment[slot] = nil
	InventoryService.SetSlot(player, index, item)
	changed(player, { slot })
	return true, nil
end

-- StatService plug-ins ------------------------------------------------------------------------------------

local function modifierSource(_player: Player, char: Types.CharacterData)
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	for slot, item in char.equipment do
		if slot ~= "backpack" then
			local stats = ItemRoll.itemStats(item)
			for stat, value in stats.flat do
				flat[stat] = (flat[stat] or 0) + value
			end
			for stat, value in stats.pct do
				pct[stat] = (pct[stat] or 0) + value
			end
		end
	end
	return { key = "source.gear", flat = flat, pct = pct }
end

local function weaponProvider(
	_player: Player,
	char: Types.CharacterData
): { dmg: number, mdmg: number, speed: number, ranged: boolean }?
	local item = char.equipment.weapon
	if not item then
		return nil
	end
	local weapon = ItemRoll.itemStats(item).weapon
	if not weapon then
		return nil
	end
	return { dmg = weapon.dmg, mdmg = weapon.mdmg, speed = weapon.speed, ranged = weapon.ranged }
end

function EquipmentService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	StatService = registry.Get("StatService")
	StatService.RegisterModifierSource("equipment", modifierSource)
	StatService.SetWeaponProvider(weaponProvider)
end

function EquipmentService.Start()
	Net.Handle("EquipItem", function(player: Player, index: number, slot: string?)
		return EquipmentService.Equip(player, index, slot)
	end)
	Net.Handle("UnequipItem", function(player: Player, slot: string, index: number?)
		return EquipmentService.Unequip(player, slot, index)
	end)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		updateWeaponModel(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		hookCache[player] = nil
	end)
end

return EquipmentService
