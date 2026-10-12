--!strict
-- Equipping (DESIGN §5.1, §5.6, §5.7). Validates level and class, handles rings (ring1/ring2), two-handed
-- weapons (they push the off-hand back into the backpack), backpack swaps (only when everything fits) and
-- binding on equip. Plugs equipment into StatService (modifier source + weapon provider), exposes legendary
-- effect totals (hooks) and shows the weapon and off-hand on the character (placeholder parts, Data/WeaponLooks, or
-- the owner's real models from ReplicatedStorage.Assets.Weapons, S52).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local ArtTiers = require(Shared.Logic.ArtTiers)
local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local LookBuild = require(Shared.Util.LookBuild)
local Net = require(Shared.Net)
local Paths = require(Shared.Logic.Paths)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Rarities = require(Shared.Data.Rarities)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)
local WeaponLooks = require(Shared.Data.WeaponLooks)
local WeaponMount = require(Shared.Logic.WeaponMount)

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
	if not char then
		return hooks -- not cached: a late read (DoT tick after leaving) must not pin the player or a stale {}
	end
	for slot, item in char.equipment do
		if slot ~= "backpack" then
			for hook, value in ItemRoll.itemStats(item).hooks do
				hooks[hook] = (hooks[hook] or 0) + value
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

-- Real weapon models (S52) ------------------------------------------------------------------------------------

local warnedAssets: { [string]: boolean } = {}

local function weaponsFolder(): Instance?
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Weapons")
end

-- The MeshPart named `model` anywhere in Assets.Weapons (a single file or a saved pack), or the first part of a
-- Model of that name.
local function findModel(model: string): BasePart?
	local folder = weaponsFolder()
	local source = folder and folder:FindFirstChild(model, true)
	if source and source:IsA("BasePart") then
		return source
	elseif source then
		return source:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- One warning per missing model of an item's own entry; a single one while Assets.Weapons has no model at all.
local function warnMissing(defId: string, model: string)
	local folder = weaponsFolder()
	local any = folder ~= nil and folder:FindFirstChildWhichIsA("BasePart", true) ~= nil
	local key = if any then model else "*"
	if warnedAssets[key] then
		return
	end
	warnedAssets[key] = true
	if any then
		warn(`[Equipment] Assets.Weapons.{model} not found; {defId} uses a lower tier or its Part look`)
	else
		warn("[Equipment] ReplicatedStorage.Assets.Weapons has no weapon models yet; items use their Part looks")
	end
end

-- Which real model an item shows (Logic/ArtTiers over WeaponLooks.assets and the models present) and its source
-- part, or nil (Part look).
function EquipmentService.ModelFor(def: Items.ItemDef): (string?, BasePart?)
	local own = WeaponLooks.assets[def.id]
	if own and not findModel(own.model) then
		warnMissing(def.id, own.model)
	end
	local id = ArtTiers.modelId(def, function(candidate: string): boolean
		local asset = WeaponLooks.assets[candidate]
		return asset ~= nil and findModel(asset.model) ~= nil
	end)
	if not id then
		return nil, nil
	end
	return id, findModel(WeaponLooks.assets[id].model)
end

local function axis(name: string): Vector3
	local v = WeaponMount.axis(name) or { 0, 0, -1 }
	return Vector3.new(v[1], v[2], v[3])
end

-- Grip frame of a type in the hand frame (WeaponLooks.MOUNTS, the same maths as Logic/WeaponMount.toHand).
local function mountFrame(itemType: string): CFrame
	local mount = WeaponLooks.MOUNTS[itemType] or WeaponLooks.MOUNTS.sword1h
	local at = mount.at or { 0, 0, 0 }
	local tilt = mount.tilt or { 0, 0, 0 }
	local x, y = axis(mount.x), axis(mount.y)
	return CFrame.new(at[1], at[2], at[3])
		* CFrame.Angles(math.rad(tilt[1]), math.rad(tilt[2]), math.rad(tilt[3]))
		* CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- Copy of a model scaled to the item's length and placed on the mount of its type, with the palm (VaelthornGrip)
-- and the far end (VaelthornTip). Only the mesh look survives (SurfaceAppearance / SpecialMesh): scripts, sounds,
-- decals and any other child are dropped, also when nested under a kept look (one warning per model).
local function buildFromModel(
	source: BasePart,
	asset: WeaponLooks.Asset,
	itemType: string,
	anchor: BasePart,
	grip: CFrame,
	name: string
): BasePart
	local part = source:Clone()
	for _, child in part:GetChildren() do
		if not child:IsA("SurfaceAppearance") and not child:IsA("SpecialMesh") then
			child:Destroy()
		end
	end
	local removed = LookBuild.stripScripts(part)
	for _, item in part:GetDescendants() do
		if item:IsA("Sound") then
			item:Destroy()
			removed += 1
		end
	end
	if removed > 0 and not warnedAssets[`strip:{asset.model}`] then
		warnedAssets[`strip:{asset.model}`] = true
		warn(`[Equipment] removed scripts / sounds from Assets.Weapons.{asset.model}`)
	end
	-- The mesh in the Grip frame: the import switch and an optional per-model turn (a mesh made in Studio).
	local t = asset.turn or { 0, 0, 0 }
	local turn = CFrame.Angles(0, math.rad(WeaponLooks.IMPORT_YAW), 0)
		* CFrame.Angles(math.rad(t[1]), math.rad(t[2]), math.rad(t[3]))
	local up = turn:VectorToObjectSpace(Vector3.yAxis)
	local size = part.Size
	local along = math.abs(up.X) * size.X + math.abs(up.Y) * size.Y + math.abs(up.Z) * size.Z
	part.Size = size * (asset.length / math.max(0.01, along))
	local hold = asset.hold or { 0, 0 }
	local centre = CFrame.new(-hold[1] * asset.length, (0.5 - asset.grip) * asset.length, -hold[2] * asset.length)
	local offset = grip * mountFrame(itemType) * centre * turn
	part.Name = name
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = anchor.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	local palm = Instance.new("Attachment")
	palm.Name = "VaelthornGrip"
	palm.CFrame = offset:Inverse() * grip
	palm.Parent = part
	local tip = Instance.new("Attachment")
	tip.Name = "VaelthornTip"
	tip.CFrame = turn:Inverse() * CFrame.new(0, asset.length / 2, 0)
	tip.Parent = part
	return part
end

-- The look built from Parts (S17b): the first piece is the main part (named after the slot), the others are
-- welded to it and parented under it; the main part carries the palm and the farthest point as attachments.
local function buildFromParts(
	look: WeaponLooks.Look,
	accent: Color3,
	anchor: BasePart,
	grip: CFrame,
	name: string
): BasePart
	local main: BasePart? = nil
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
	return held
end

-- S52 /weaponpreview: a look shown in the hand without an item, until the next equipment change or respawn.
local previews: { [Player]: { slot: string, def: Items.ItemDef } } = {}

-- Builds the held model of `slot`. S22: the main part carries Attachments "VaelthornGrip" (the palm) and
-- "VaelthornTip" (the farthest point) and the attribute "WeaponType" for the client's attack animation (trail
-- between them, arrows from the grip of a bow, bolts from the tip of a wand). S52: a real model of the item (or of
-- the nearest lower tier of its type) replaces the Part look; names, attributes and the glow stay the same.
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
	local rarity = item and item.rarity
	local preview = previews[player]
	if preview and preview.slot == slot then
		def, rarity = preview.def, Rarities.COMMON
	end
	local look = def and WeaponLooks.get(def.type)
	if not def or not look or not rarity then
		return
	end
	local anchor, grip = anchorFor(model, look.hand)
	if not anchor then
		return
	end
	local accent = Color3.fromHex(Rarities.get(rarity).hex)
	local modelId, source = EquipmentService.ModelFor(def)
	local held = if modelId and source
		then buildFromModel(source, WeaponLooks.assets[modelId], def.type, anchor, grip, name)
		else buildFromParts(look, accent, anchor, grip, name)
	held:SetAttribute("WeaponType", def.type)
	held:SetAttribute("Accent", accent) -- rarity colour (trail)
	if Rarities.get(rarity).valuable then
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

-- S52 /weaponpreview: shows the look of `def` (a held type) in the right slot of the hand without an item. Returns
-- the slot and the real model it uses (nil = Part look); nil slot when the type is not held.
function EquipmentService.Preview(player: Player, def: Items.ItemDef): (string?, string?)
	if not WeaponLooks.get(def.type) then
		return nil, nil
	end
	local slot: "weapon" | "offhand" = if def.slot == "offhand" then "offhand" else "weapon"
	previews[player] = { slot = slot, def = def }
	updateHeldModel(player, slot)
	return slot, (EquipmentService.ModelFor(def))
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
	-- Any equipment change ends a /weaponpreview (S52).
	local hadPreview = previews[player] ~= nil
	previews[player] = nil
	if hadPreview or table.find(slots, "weapon") or table.find(slots, "offhand") then
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

-- S57 (ROZWOJ 2.8): base types in the weapon and off-hand slots, for the path weapon rules (Logic/Paths.weaponOk).
function EquipmentService.WeaponTypes(player: Player): Paths.WeaponTypes
	local char = character(player)
	if not char then
		return {}
	end
	return Paths.weaponTypesOf(char.equipment)
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
		previews[player] = nil
		updateWeaponModel(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		hookCache[player] = nil
		previews[player] = nil
	end)
end

return EquipmentService
