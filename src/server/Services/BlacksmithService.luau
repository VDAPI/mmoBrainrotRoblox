--!strict
-- Blacksmith (DESIGN §6–§8): crafting fixed-stat Common items for gold + ore, upgrading +0..+9 (backpack or
-- equipped items, optional Scroll of Protection), dismantling into essences. Each operation checks the NPC
-- distance, the costs and changes data in one step. +7 and higher is announced on the server; +9 on a
-- legendary also across servers. S134j: bonus reroll (Logic/Reroll, docs/DESIGN.md §6a): one regular line, locked
-- after the first reroll, each attempt on the item dearer. S160k (owner 2026-10-21): gold, essence AND a Stone of Bonus
-- Transmutation together (Reroll.payment); "Change effect" (Logic/EffectReroll) replaces one skill effect of a
-- Legendary / Mythic item for gold, essence and a Stone of Effect Transmutation. S154: item looks (Logic/Transmog,
-- §6b): a look from the account's collection on a weapon or an off-hand for gold and essence.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Crafting = require(Shared.Data.Crafting)
local Dismantle = require(Shared.Logic.Dismantle)
local EffectReroll = require(Shared.Logic.EffectReroll)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Rarities = require(Shared.Data.Rarities)
local Reroll = require(Shared.Logic.Reroll)
local Rng = require(Shared.Logic.Rng)
local Transmog = require(Shared.Logic.Transmog)
local Types = require(Shared.Types)
local Upgrade = require(Shared.Logic.Upgrade)

local log = Log.new("BlacksmithService")

type ItemInstance = Types.ItemInstance

local BlacksmithService = {
	Name = "BlacksmithService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"NpcService",
		"StatService",
		"AnnounceService",
		"EquipmentService",
		"MailService",
	},
}

local PlayerStateService: any
local InventoryService: any
local NpcService: any
local MailService: any
local StatService: any
local AnnounceService: any
local EquipmentService: any

local rng = Rng.new()

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function nearSmith(player: Player): boolean
	return NpcService.NearService(player, "blacksmith") ~= nil
end

local function hasMaterials(player: Player, materials: { { id: string, n: number } }): boolean
	for _, material in materials do
		if InventoryService.Count(player, material.id) < material.n then
			return false
		end
	end
	return true
end

local function takeMaterials(player: Player, materials: { { id: string, n: number } })
	for _, material in materials do
		InventoryService.Remove(player, material.id, material.n)
	end
end

local function addGold(player: Player, delta: number)
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return math.max(0, gold + delta)
	end)
	Analytics.gold(player, delta, balance, "blacksmith")
end

-- Crafting ----------------------------------------------------------------------------------------------------

local function craft(player: Player, recipeId: string): (boolean, string?)
	local char = character(player)
	local recipe = Crafting.get(recipeId)
	if not char or not recipe then
		return false, "error.badRequest"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	if char.gold < recipe.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, recipe.materials) then
		return false, "smith.missing"
	end
	local item = ItemRoll.rollItem(recipe.item, recipe.level, Rarities.COMMON, rng, InventoryService.NewUid())
	item.el = recipe.el
	if not InventoryService.CanFit(player, { item }) then
		return false, "inventory.full"
	end
	addGold(player, -recipe.gold)
	takeMaterials(player, recipe.materials)
	InventoryService.AddItem(player, item)
	QuestEvents.fire(player, "craft", { recipeId = recipeId, n = 1 }) -- S151: achievements
	return true, nil
end

-- Upgrading --------------------------------------------------------------------------------------------------

local function locate(player: Player, location: string, key: string): (ItemInstance?, () -> ())
	local char = character(player)
	if not char then
		return nil, function() end
	end
	if location == "eq" then
		local item = char.equipment[key]
		if key == "backpack" then
			return nil, function() end
		end
		return item,
			function()
				PlayerStateService.Set(player, { "character", "equipment", key }, item)
				EquipmentService.InvalidateHooks(player) -- S134j: on-hit / vs_* lines are cached hooks
				StatService.Invalidate(player)
			end
	elseif location == "inv" then
		local index = tonumber(key)
		local item = if index then InventoryService.Get(player, index) else nil
		return item, function()
			InventoryService.SetSlot(player, index :: number, item)
		end
	end
	return nil, function() end
end

local function upgrade(player: Player, location: string, key: string, protect: boolean): (boolean, string?, any)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	local def = item and Items.get(item.id)
	if not item or not def or def.category ~= "equipment" then
		return false, "error.badRequest"
	end
	if not Upgrade.canUpgrade(item) then
		return false, "smith.upgrade.max"
	end
	local cost = Upgrade.cost(item, item.up + 1)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, cost.materials) then
		return false, "smith.missing"
	end
	local useProtection = protect and InventoryService.Count(player, "scroll_protection") > 0
	-- Pay, roll, write — no yields in between.
	addGold(player, -cost.gold)
	takeMaterials(player, cost.materials)
	if useProtection then
		InventoryService.Remove(player, "scroll_protection", 1)
	end
	local result = Upgrade.attempt(item, useProtection, rng)
	item.up = result.to
	commit()
	if result.success then
		QuestEvents.fire(player, "upgrade", { to = result.to })
	end
	if result.success and result.to >= 7 then
		Analytics.custom(player, `Upgrade+{result.to}`, item.rarity)
		local args = { player = char.name, item = `#item:{item.id}:0`, up = result.to }
		if result.to >= 9 and Rarities.get(item.rarity).announce ~= nil then
			AnnounceService.Global("announce.upgrade", "announce.upgradeGlobal", args)
		else
			AnnounceService.Server("announce.upgrade", args)
		end
	end
	log:info("%s upgrade %s +%d -> +%d", player.Name, item.id, result.from, result.to)
	return true, nil, { success = result.success, from = result.from, to = result.to, protected = result.protected }
end

-- Bonus reroll (S134j) -----------------------------------------------------------------------------------------

export type RerollOpts = {
	anywhere: boolean?, -- admin: no distance check
	free: boolean?, -- admin: no cost
}

-- Rerolls line `index` of an item (backpack or equipped). `expected` is the line's stat the client saw: a different
-- one (item changed in another window or by a trade) refuses before anything is paid. S160k: the gold, the essence and
-- a Stone of Bonus Transmutation together (Reroll.payment; no stone refuses with noStone before anything is paid).
-- Pay, roll and write without yields in between; the server's rng only.
function BlacksmithService.Reroll(
	player: Player,
	location: string,
	key: string,
	index: number,
	expected: string,
	opts: RerollOpts?
): (boolean, string?, any)
	local o: RerollOpts = opts or {}
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not o.anywhere and not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	if not item then
		return false, "error.badRequest"
	end
	local ok, err = Reroll.canLine(item, index)
	if not ok then
		return false, err
	end
	local current = item.bonuses[index]
	if current.stat ~= expected then
		return false, "smith.reroll.error.changed"
	end
	if next(Reroll.pool(item, index, char.class)) == nil then
		return false, "smith.reroll.error.empty"
	end
	if not o.free and InventoryService.Count(player, Reroll.STONE) < 1 then
		return false, "smith.reroll.error.noStone"
	end
	local cost = if o.free then { gold = 0, materials = {} } else Reroll.payment(item)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, cost.materials) then
		return false, "smith.missing"
	end
	-- Pay, roll, write — no yields in between (the stone is the payment's last material).
	if cost.gold > 0 then
		addGold(player, -cost.gold)
	end
	takeMaterials(player, cost.materials)
	local old = { stat = current.stat, v = current.v }
	local line = Reroll.roll(item, index, char.class, rng)
	Reroll.apply(item, index, line)
	commit()
	local n = Reroll.state(item).n
	Analytics.custom(player, "Reroll", item.rarity)
	QuestEvents.fire(player, "reroll", nil) -- S151: achievements
	log:info("%s reroll %s line %d %s -> %s (n=%d)", player.Name, item.id, index, old.stat, line.stat, n)
	return true, nil, { index = index, old = old, new = { stat = line.stat, v = line.v }, n = n }
end

-- S156: rerolls every regular line of an item with a Scroll of Transformation (Logic/Reroll.rollAll). `expected` is the
-- item's line signature the client saw (Reroll.signature). Pay, roll and write without yields in between.
function BlacksmithService.RerollAll(
	player: Player,
	location: string,
	key: string,
	expected: string,
	opts: RerollOpts?
): (boolean, string?, any)
	local o: RerollOpts = opts or {}
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not o.anywhere and not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	if not item then
		return false, "error.badRequest"
	end
	local ok, err = Reroll.eligible(item)
	if not ok then
		return false, err
	end
	if Reroll.signature(item) ~= expected then
		return false, "smith.reroll.error.changed"
	end
	if not o.free and InventoryService.Count(player, Reroll.SCROLL) < 1 then
		return false, "smith.reroll.error.noScroll"
	end
	local cost = if o.free then { gold = 0, materials = {} } else Reroll.costAll(item)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	-- Pay, roll, write — no yields in between.
	if cost.gold > 0 then
		addGold(player, -cost.gold)
	end
	if not o.free then
		InventoryService.Remove(player, Reroll.SCROLL, 1)
	end
	local bonuses, changes = Reroll.rollAll(item, char.class, rng)
	Reroll.applyAll(item, bonuses)
	commit()
	local n = Reroll.state(item).n
	Analytics.custom(player, "RerollAll", item.rarity)
	QuestEvents.fire(player, "reroll", nil)
	log:info("%s reroll all %s (%d lines, n=%d)", player.Name, item.id, #changes, n)
	return true, nil, { changes = changes, n = n }
end

local function rerollAll(player: Player, location: string, key: string, expected: string): (boolean, string?, any)
	return BlacksmithService.RerollAll(player, location, key, expected)
end

local function reroll(
	player: Player,
	location: string,
	key: string,
	index: number,
	expected: string
): (boolean, string?, any)
	return BlacksmithService.Reroll(player, location, key, index, expected)
end

-- S160k (owner 2026-10-21): replaces effect `index` of a Legendary / Mythic item with another effect of the same tier
-- (Logic/EffectReroll). `expected` is the effect id the client saw: another one refuses before anything is paid. The
-- gold, the essence and a Stone of Effect Transmutation together. Pay, roll and write without yields in between.
function BlacksmithService.RerollEffect(
	player: Player,
	location: string,
	key: string,
	index: number,
	expected: string,
	opts: RerollOpts?
): (boolean, string?, any)
	local o: RerollOpts = opts or {}
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not o.anywhere and not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	if not item then
		return false, "error.badRequest"
	end
	local ok, err = EffectReroll.canIndex(item, index)
	if not ok then
		return false, err
	end
	local old = ((item :: any).fx :: { string })[index]
	if old ~= expected then
		return false, "smith.reroll.error.changed"
	end
	if #EffectReroll.pool(item, index, char.class) == 0 then
		return false, "smith.effect.error.empty"
	end
	if not o.free and InventoryService.Count(player, EffectReroll.STONE) < 1 then
		return false, "smith.effect.error.noStone"
	end
	local cost = if o.free then { gold = 0, materials = {} } else EffectReroll.payment(item)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, cost.materials) then
		return false, "smith.missing"
	end
	-- Pay, roll, write — no yields in between (the stone is the payment's last material).
	if cost.gold > 0 then
		addGold(player, -cost.gold)
	end
	takeMaterials(player, cost.materials)
	local new = EffectReroll.roll(item, index, char.class, rng)
	EffectReroll.apply(item, index, new)
	commit()
	Analytics.custom(player, "RerollEffect", item.rarity)
	QuestEvents.fire(player, "reroll", nil)
	log:info("%s reroll effect %s #%d %s -> %s", player.Name, item.id, index, old, new)
	return true, nil, { index = index, old = old, new = new }
end

local function rerollEffect(
	player: Player,
	location: string,
	key: string,
	index: number,
	expected: string
): (boolean, string?, any)
	return BlacksmithService.RerollEffect(player, location, key, index, expected)
end

-- Item looks (S154) ----------------------------------------------------------------------------------------------

export type TransmogOpts = {
	anywhere: boolean?, -- admin: no distance check
	free: boolean?, -- admin: no cost
}

-- Puts the look `look` from the account's collection on a held item (backpack or equipped), or takes the worn look
-- off with "" (free). `expected` is the item's uid the client saw: another item in that place refuses before anything
-- is paid. Only `tm` changes (Logic/Transmog); pay and write without yields in between; an equipped item is drawn
-- again at once.
function BlacksmithService.Transmog(
	player: Player,
	location: string,
	key: string,
	look: string,
	expected: string,
	opts: TransmogOpts?
): (boolean, string?, any)
	local o: TransmogOpts = opts or {}
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not o.anywhere and not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	if not item then
		return false, "error.badRequest"
	end
	if item.uid ~= expected then
		return false, "transmog.error.changed"
	end
	local looks = Transmog.sanitize(PlayerStateService.Get(player, { "account", "transmog" })).looks
	local ok, err = Transmog.canApply(item, look, looks)
	if not ok then
		return false, err
	end
	local removing = look == ""
	local cost = if removing or o.free then { gold = 0, materials = {} } else Transmog.cost(item)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, cost.materials) then
		return false, "smith.missing"
	end
	-- Pay and write — no yields in between.
	if cost.gold > 0 then
		addGold(player, -cost.gold)
	end
	takeMaterials(player, cost.materials)
	item.tm = Transmog.apply(item, look).tm
	commit()
	if location == "eq" then
		EquipmentService.RefreshHeld(player)
	end
	if not removing then
		Analytics.custom(player, if Transmog.isBoss(look) then "TransmogBoss" else "Transmog", item.rarity)
	end
	log:info("%s transmog %s -> %s (gold %d)", player.Name, item.id, if removing then "own" else look, cost.gold)
	return true, nil, { look = look }
end

local function transmog(
	player: Player,
	location: string,
	key: string,
	look: string,
	expected: string
): (boolean, string?, any)
	return BlacksmithService.Transmog(player, location, key, look, expected)
end

-- Dismantling -------------------------------------------------------------------------------------------------

local function dismantleIndices(player: Player, indices: { number }): (boolean, string?, any)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local gained: { [string]: number } = {}
	local count = 0
	for _, index in indices do
		local item = InventoryService.Get(player, index)
		if item and Dismantle.canDismantle(item) then
			for _, material in Dismantle.roll(item, rng) do
				gained[material.id] = (gained[material.id] or 0) + material.n
			end
			InventoryService.SetSlot(player, index, nil)
			count += 1
		end
	end
	if count == 0 then
		return false, "shop.error.nothing"
	end
	QuestEvents.fire(player, "dismantle", { n = count }) -- S151: achievements
	local list = {}
	local overflow = {}
	for id, n in gained do
		local leftover, item = InventoryService.GiveNew(player, id, n)
		table.insert(list, { id = id, n = n })
		if leftover > 0 and item then
			-- Full backpack: the rest goes to the mail instead of disappearing.
			local rest = table.clone(item)
			rest.n = leftover
			rest.uid = InventoryService.NewUid()
			table.insert(overflow, rest)
		end
	end
	if #overflow > 0 then
		local char = character(player)
		task.spawn(MailService.Send, player.UserId, {
			from = "system",
			subjectKey = "mail.subject.returned",
			items = overflow,
			charId = if char then char.id else nil,
		})
		Net.Fire(player, "Toast", "smith.dismantle.mailed", nil, "info")
	end
	return true, nil, list
end

local function dismantle(player: Player, raw: { any }): (boolean, string?, any)
	if not character(player) then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local indices = {}
	local seen: { [number]: boolean } = {}
	for i, value in raw do
		local index = tonumber(value)
		if i > 200 then
			break
		end
		if index and index == math.floor(index) and not seen[index] then
			seen[index] = true
			table.insert(indices, index)
		end
	end
	return dismantleIndices(player, indices)
end

local function dismantleAll(player: Player, maxRarity: number): (boolean, string?, any)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	-- "Dismantle all": Common, or Common and Unique (never valuable rarities).
	local limit = math.clamp(maxRarity, Rarities.COMMON, Rarities.UNIQUE)
	local indices = {}
	for key, item in char.inventory do
		if item.rarity <= limit and not Rarities.get(item.rarity).valuable and Dismantle.canDismantle(item) then
			table.insert(indices, tonumber(key) :: number)
		end
	end
	return dismantleIndices(player, indices)
end

function BlacksmithService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	MailService = registry.Get("MailService")
	StatService = registry.Get("StatService")
	AnnounceService = registry.Get("AnnounceService")
	EquipmentService = registry.Get("EquipmentService")
end

function BlacksmithService.Start()
	Net.Handle("Craft", craft)
	Net.Handle("UpgradeItem", upgrade)
	Net.Handle("Dismantle", dismantle)
	Net.Handle("DismantleAll", dismantleAll)
	Net.Handle("RerollBonus", reroll)
	Net.Handle("RerollAll", rerollAll) -- S156
	Net.Handle("RerollEffect", rerollEffect) -- S160k
	Net.Handle("TransmogApply", transmog) -- S154
end

return BlacksmithService
