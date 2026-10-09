--!strict
-- Equipping (DESIGN §5.1, §5.6, §5.7). Validates level and class, handles rings (ring1/ring2), two-handed
-- weapons (they push the off-hand back into the backpack), backpack swaps (only when everything fits) and
-- binding on equip. Plugs equipment into StatService (modifier source + weapon provider), exposes legendary
-- effect totals (hooks) and shows the weapon and off-hand on the character (placeholder parts, Data/WeaponLooks).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Rarities = require(Shared.Data.Rarities)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)
local WeaponLooks = require(Shared.Data.WeaponLooks)

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

local HELD_NAMES = { weapon = "VaelthornWeapon", offhand = "VaelthornOffhand" }

local function rarityColor(item: ItemInstance): Color3
	return Color3.fromHex(Rarities.get(item.rarity).hex)
end

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

local function vector(values: { number }): Vector3
	return Vector3.new(values[1], values[2], values[3])
end

-- Grip frame of a look (WeaponLooks): palm of the hand, or the centre of the upper torso for "back".
local function anchorFor(model: Model, hand: string): (BasePart?, CFrame)
	if hand == "back" then
		local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
		return if torso and torso:IsA("BasePart") then torso else nil, CFrame.identity
	end
	local side = if hand == "left" then "Left" else "Right"
	local part = model:FindFirstChild(`{side}Hand`) or model:FindFirstChild(`{side} Arm`)
	if not part or not part:IsA("BasePart") then
		return nil, CFrame.identity
	end
	return part, CFrame.new(0, -part.Size.Y / 2, 0)
end

-- Farthest point of a look from the palm (studs, weapon frame): the blade tip / staff head (S22 trails and
-- projectile origins).
local function tipOf(look: WeaponLooks.Look): Vector3
	local best, bestDistance = Vector3.zero, -1
	for _, piece in look.pieces do
		local rot = piece.rot or { 0, 0, 0 }
		local frame = CFrame.new(vector(piece.pos))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		local half = vector(piece.size) / 2
		for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
			for _, sign in { -1, 1 } do
				local point = frame * (axis * half * sign)
				if point.Magnitude > bestDistance then
					best, bestDistance = point, point.Magnitude
				end
			end
		end
	end
	return best
end

-- Real model of an item (WeaponLooks.assets) from ReplicatedStorage.Assets.Weapons, as one part standing up the
-- weapon frame, or nil (no entry / no model: the Part look is used; a missing model warns once).
local warnedAssets: { [string]: boolean } = {}
local function assetPart(defId: string): (BasePart?, WeaponLooks.Asset?)
	local asset = WeaponLooks.assets[defId]
	if not asset then
		return nil, nil
	end
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weapons")
	local source = folder and folder:FindFirstChild(asset.model)
	local part: BasePart? = nil
	if source and source:IsA("BasePart") then
		part = source:Clone()
	elseif source then
		local first = source:FindFirstChildWhichIsA("BasePart", true)
		part = if first then first:Clone() else nil
	end
	if not part then
		if not warnedAssets[asset.model] then
			warnedAssets[asset.model] = true
			warn(`[Equipment] Assets.Weapons.{asset.model} not found; {defId} uses its Part look`)
		end
		return nil, nil
	end
	for _, child in part:GetChildren() do
		if not child:IsA("SurfaceAppearance") and not child:IsA("SpecialMesh") then
			child:Destroy()
		end
	end
	local size = part.Size
	part.Size = size * (asset.length / math.max(0.01, size.Y))
	return part, asset
end

-- Builds the held model of `slot` from its look: the first piece is the main part (named after the slot),
-- the others are welded to it and parented under it. S22: the main part carries Attachments "VaelthornGrip"
-- (the palm) and "VaelthornTip" (the farthest point) and the attribute "WeaponType" for the client's attack
-- animation (trail between them, arrows from the grip of a bow, bolts from the tip of a wand).
local function updateHeldModel(player: Player, slot: "weapon" | "offhand")
	local model = player.Character
	if not model then
		return
	end
	local name = HELD_NAMES[slot]
	local old = model:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local char = character(player)
	local item = char and (char.equipment :: any)[slot] :: ItemInstance?
	local def = item and Items.get(item.id)
	local look = def and WeaponLooks.get(def.type)
	if not item or not look then
		return
	end
	local anchor, grip = anchorFor(model, look.hand)
	if not anchor then
		return
	end
	local accent = rarityColor(item)
	local main: BasePart? = nil
	local real, asset = assetPart((def :: any).id)
	if real and asset then
		-- Upright mesh (+Y) turned to point forward (-Z), the hand `grip` of the way up from the pommel.
		local offset = grip * CFrame.new(0, 0, -(0.5 - asset.grip) * asset.length) * CFrame.Angles(math.rad(-90), 0, 0)
		real.Name = name
		real.Anchored = false
		real.CanCollide = false
		real.CanTouch = false
		real.CanQuery = false
		real.Massless = true
		real.CastShadow = false
		real.CFrame = anchor.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = real
		weld.C0 = offset
		weld.Parent = real
		local palm = Instance.new("Attachment")
		palm.Name = "VaelthornGrip"
		palm.CFrame = (grip:Inverse() * offset):Inverse()
		palm.Parent = real
		local tip = Instance.new("Attachment")
		tip.Name = "VaelthornTip"
		tip.CFrame = palm.CFrame * CFrame.new(0, 0, -(1 - asset.grip) * asset.length)
		tip.Parent = real
		real:SetAttribute("WeaponType", (def :: any).type)
		real:SetAttribute("Accent", accent)
		real.Parent = model
		return
	end
	for _, piece in look.pieces do
		local part = Instance.new("Part")
		part.Name = if main then piece.name else name
		part.Size = vector(piece.size)
		part.Color = if piece.color == "rarity" then accent else Color3.fromHex(piece.color)
		part.Material = material(piece.material)
		part.Transparency = piece.transparency or 0
		if piece.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif piece.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		local rot = piece.rot or { 0, 0, 0 }
		local offset = grip
			* CFrame.new(vector(piece.pos))
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		part.CFrame = anchor.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		if main then
			part.Parent = main
		else
			main = part
		end
	end
	local held = main :: BasePart
	local first = look.pieces[1]
	local firstRot = first.rot or { 0, 0, 0 }
	local firstOffset = CFrame.new(vector(first.pos))
		* CFrame.Angles(math.rad(firstRot[1]), math.rad(firstRot[2]), math.rad(firstRot[3]))
	local palm = Instance.new("Attachment")
	palm.Name = "VaelthornGrip"
	palm.CFrame = firstOffset:Inverse()
	palm.Parent = held
	local tip = Instance.new("Attachment")
	tip.Name = "VaelthornTip"
	tip.CFrame = firstOffset:Inverse() * CFrame.new(tipOf(look))
	tip.Parent = held
	held:SetAttribute("WeaponType", (def :: any).type)
	held:SetAttribute("Accent", accent) -- rarity colour (trail)
	if Rarities.get(item.rarity).valuable then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 6
		light.Brightness = 1
		light.Parent = held
	end
	held.Parent = model
end

local function updateWeaponModel(player: Player)
	updateHeldModel(player, "weapon")
	updateHeldModel(player, "offhand")
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
	if table.find(slots, "weapon") or table.find(slots, "offhand") then
		updateWeaponModel(player)
	end
end

local function canUse(char: Types.CharacterData, def: Items.ItemDef, item: ItemInstance): (boolean, string?)
	if char.level < ItemRoll.requiredLevel(item) then
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
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
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
	local ok, err = canUse(char, def, item)
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
	QuestEvents.fire(player, "equip", { rarity = item.rarity })
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

-- Swaps the two ring slots (S29: dragging a ring onto the other ring slot). Either may be empty.
function EquipmentService.SwapRings(player: Player): (boolean, string?)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local equipment = char.equipment :: any
	if equipment.ring1 == nil and equipment.ring2 == nil then
		return false, "error.badRequest"
	end
	equipment.ring1, equipment.ring2 = equipment.ring2, equipment.ring1
	changed(player, { "ring1", "ring2" })
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
): { dmg: number, mdmg: number, speed: number, ranged: boolean, element: string? }?
	local item = char.equipment.weapon
	if not item then
		return nil
	end
	local weapon = ItemRoll.itemStats(item).weapon
	if not weapon then
		return nil
	end
	return {
		dmg = weapon.dmg,
		mdmg = weapon.mdmg,
		speed = weapon.speed,
		ranged = weapon.ranged,
		element = weapon.element,
	}
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
	Net.Handle("SwapRings", function(player: Player)
		return EquipmentService.SwapRings(player)
	end)
	CharacterService.ModelSpawned:Connect(function(player: Player)
		updateWeaponModel(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		hookCache[player] = nil
	end)
end

return EquipmentService
