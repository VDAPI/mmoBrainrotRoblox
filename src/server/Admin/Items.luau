--!strict
-- Admin commands: items (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local AreaProfiles = require(Shared.Data.AreaProfiles)
local Bonuses = require(Shared.Data.Bonuses)
local Classes = require(Shared.Data.Classes)
local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local DevPreset = require(Shared.Logic.DevPreset)
local Elements = require(Shared.Data.Elements)
local Families = require(Shared.Data.Families)
local Inventory = require(Shared.Logic.Inventory)
local ItemIcons = require(Shared.Logic.ItemIcons)
local ItemRoll = require(Shared.Logic.ItemRoll)
local ItemScore = require(Shared.Logic.ItemScore)
local ItemValue = require(Shared.Logic.ItemValue)
local Items = require(Shared.Data.Items)
local Loot = require(Shared.Logic.Loot)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local Shops = require(Shared.Data.Shops)
local TooltipModel = require(Shared.Logic.TooltipModel)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount
local VARIANTS = Context.VARIANTS

local PlayerStateService = Context.services.PlayerStateService
local InventoryService = Context.services.InventoryService
local EquipmentService = Context.services.EquipmentService
local LootService = Context.services.LootService
local StatService = Context.services.StatService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

-- Changes the equipped weapon with `edit` and recomputes stats.
local function editWeapon(player: Player, edit: (item: any) -> ()): boolean
	local character = PlayerStateService.GetCharacter(player)
	local item = character and character.equipment.weapon
	if not item then
		reply(player, "admin.weapon.none")
		return false
	end
	local copy = table.clone(item)
	edit(copy)
	PlayerStateService.Set(player, { "character", "equipment", "weapon" }, copy)
	StatService.Invalidate(player)
	return true
end

commands.give = function(player, args)
	local itemId = args[1]
	if not itemId then
		reply(player, "admin.usage.give")
		return
	end
	local def = Items.get(itemId)
	if not def then
		reply(player, "admin.give.unknown", { id = itemId })
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		-- S30: common|unique|heroic|legendary|mythic or 1-5; named boss items are always Mythic.
		local rarity = Rarities.parse(args[2]) or def.rarity or Rarities.COMMON
		local ilvl = math.clamp(parseAmount(args[3]) or math.max(def.level, character.level), 1, Config.MaxLevel)
		local n = math.clamp(parseAmount(args[4]) or 1, 1, 999)
		local given = 0
		if def.stackable then
			given = n - InventoryService.GiveNew(player, itemId, n)
		else
			for _ = 1, math.min(n, 50) do
				local leftover = InventoryService.GiveNew(player, itemId, 1, rarity, ilvl)
				if leftover > 0 then
					break
				end
				given += 1
			end
		end
		if given == 0 then
			reply(player, "inventory.full")
		else
			reply(player, "admin.give.ok", { name = `#item:{itemId}:0`, n = given })
		end
	end)
end

-- S30: /item = /give with rarity names.
commands.item = commands.give

commands.legend = function(player, args)
	withCharacter(player, function()
		if LootService.DropLegendary(player, Rarities.parse(args[1])) then
			reply(player, "admin.legend.ok")
		end
	end)
end

commands.lootsim = function(player, args)
	local monsterId = args[1]
	local def = monsterId and Monsters.get(monsterId)
	if not def then
		reply(player, "admin.usage.lootsim")
		return
	end
	local variant = VARIANTS[tonumber(args[2]) or -1]
		or (if Rarities.dropWeights[args[2] or ""] then args[2] else "normal")
	local n = math.clamp(parseAmount(args[3]) or 1000, 1, 100000)
	-- S33: optional hunting ground (its profile changes items, rarity, materials and gold).
	local areaId = args[4]
	local profile = AreaProfiles.ofArea(areaId)
	local character = PlayerStateService.GetCharacter(player)
	local counts, items, mats, gold =
		LootService.Simulate(monsterId, variant, def.levels.max, n, if character then character.class else nil, areaId)
	reply(player, "admin.lootsim.result", {
		n = n,
		variant = if profile then `{variant}, {profile.icon} {areaId}` else variant,
		items = items,
		c1 = counts[1],
		c2 = counts[2],
		c3 = counts[3],
		c4 = counts[4],
		c5 = counts[5],
		mats = mats,
		gold = gold,
	})
end

-- S35: /icons [status|glyph|art]: the atlas state (server side: ids, items without an icon) and the client's own
-- preload result; glyph / art switches the client (not saved).
commands.icons = function(player, args)
	local mode = args[1] or "status"
	local missing = 0
	for _, def in Items.byId do
		if not ItemIcons.resolve(def) then
			missing += 1
		end
	end
	reply(player, "admin.icons.info", { ready = tostring(ItemIcons.ready()), missing = missing })
	Net.Fire(player, "AdminClient", "icons", mode)
end

-- S35: /icongrid [eq|uniq|mat|pot|misc|tiers <type>]: preview window of a group of icons on the client.
commands.icongrid = function(player, args)
	local group = args[1] or "eq"
	if group == "tiers" and not Items.bases.byType[args[2] or ""] then
		reply(player, "admin.usage.icongrid")
		return
	end
	Net.Fire(player, "AdminClient", "icongrid", { group, args[2] })
end

commands.clearinv = function(player)
	withCharacter(player, function()
		InventoryService.Clear(player)
		reply(player, "admin.clearinv.ok")
	end)
end

commands.bag = function(player, args)
	local capacity = parseAmount(args[1])
	local id = if capacity then `backpack_{capacity}` else ""
	if not Items.get(id) then
		reply(player, "admin.bag.unknown", { capacity = args[1] or "?" })
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		if not Inventory.compact(character.inventory, capacity :: number) then
			reply(player, "equip.error.backpackFit")
			return
		end
		local backpack = ItemRoll.makeStack(id, 1, InventoryService.NewUid())
		backpack.bound = true
		PlayerStateService.Set(player, { "character", "equipment", "backpack" }, backpack)
		InventoryService.SyncAll(player)
		StatService.Invalidate(player)
		reply(player, "admin.bag.ok", { capacity = capacity })
	end)
end

commands.up = function(player, args)
	local where, level = args[1], parseAmount(args[2])
	if not where or level == nil then
		reply(player, "admin.usage.up")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local up = math.clamp(level, 0, 9)
		local index = tonumber(where)
		if index then
			local item = InventoryService.Get(player, index)
			if not item then
				reply(player, "admin.up.none")
				return
			end
			item.up = up
			InventoryService.SetSlot(player, index, item)
		else
			local item = character.equipment[where]
			if not item then
				reply(player, "admin.up.none")
				return
			end
			item.up = up
			PlayerStateService.Set(player, { "character", "equipment", where }, item)
			StatService.Invalidate(player)
		end
		reply(player, "admin.up.ok", { up = up })
	end)
end

commands.mats = function(player, args)
	local n = math.clamp(parseAmount(args[1]) or 50, 1, 999)
	withCharacter(player, function()
		for id, def in Items.byId do
			if def.category == "material" then
				InventoryService.GiveNew(player, id, n)
			end
		end
		reply(player, "admin.mats.ok")
	end)
end

commands.scrolls = function(player, args)
	local n = math.clamp(parseAmount(args[1]) or 5, 1, 999)
	withCharacter(player, function()
		for id, def in Items.byId do
			if def.category == "scroll" or def.category == "stone" then
				InventoryService.GiveNew(player, id, n)
			end
		end
		reply(player, "admin.scrolls.ok")
	end)
end

commands.ilvl = function(player, args)
	local ilvl = parseAmount(args[1])
	if ilvl == nil or ilvl < 1 or ilvl > Config.MaxLevel then
		reply(player, "admin.usage.ilvl")
		return
	end
	withCharacter(player, function()
		if editWeapon(player, function(item)
			item.ilvl = ilvl
		end) then
			reply(player, "admin.ilvl.ok", { ilvl = ilvl })
		end
	end)
end

commands.element = function(player, args)
	local element = args[1]
	if not Elements.isWeaponElement(element) then
		reply(player, "admin.usage.element")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local item = character and character.equipment.weapon
		local def = item and Items.get(item.id)
		if def and not def.elemental then
			reply(player, "admin.element.notMage")
			return
		end
		if editWeapon(player, function(weapon)
			weapon.el = element
		end) then
			reply(player, "admin.element.ok", { element = element })
		end
	end)
end

commands.partyloot = function(player, args)
	local n = math.clamp(tonumber(args[1]) or 4, 1, 5)
	local classes = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
	local candidates = {}
	for i = 1, n do
		table.insert(candidates, { id = i, classId = classes[i] })
	end
	local rng = Rng.new()
	local loot = Loot.rollBossLoot("grimrok", n, rng, {})
	local items = {}
	for i, drop in loot.items do
		local def = Items.get(drop.defId)
		table.insert(items, { uid = tostring(i), classes = if def then def.classes else nil, id = drop.defId })
	end
	local assigned = PartyLoot.distribute(items :: any, candidates, rng)
	local lines = {}
	for _, item in items do
		local owner = assigned[item.uid]
		table.insert(lines, `{item.id} -> #{owner or 0} {classes[owner or 1]}`)
	end
	reply(player, "admin.partyloot.result", { list = table.concat(lines, "; ") })
end

-- S23: /givex id rarity ilvl up el n equip
commands.givex = function(player, args)
	local itemId = args[1]
	local def = itemId and Items.get(itemId)
	if not def then
		reply(player, "admin.usage.givex")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local rarity = Rarities.parse(args[2]) or def.rarity or Rarities.COMMON
		local ilvl = math.clamp(parseAmount(args[3]) or math.max(def.level, character.level), 1, Config.MaxLevel)
		local up = math.clamp(parseAmount(args[4]) or 0, 0, 9)
		local element = args[5]
		local n = math.clamp(parseAmount(args[6]) or 1, 1, 999)
		local equip = args[7] == "yes"
		if def.stackable then
			local given = n - InventoryService.GiveNew(player, itemId, n)
			reply(
				player,
				if given > 0 then "admin.give.ok" else "inventory.full",
				{ name = `#item:{itemId}:0`, n = given }
			)
			return
		end
		local given = 0
		local lastIndex: number? = nil
		for _ = 1, math.min(n, 50) do
			local leftover, item = InventoryService.GiveNew(player, itemId, 1, rarity, ilvl)
			if leftover > 0 or not item then
				break
			end
			item.up = up
			if def.elemental and element and Elements.isWeaponElement(element) then
				item.el = element
			end
			local index = InventoryService.IndexOf(player, item.uid)
			if index then
				InventoryService.SetSlot(player, index, item)
				lastIndex = index
			end
			given += 1
		end
		if given == 0 then
			reply(player, "inventory.full")
			return
		end
		reply(player, "admin.give.ok", { name = `#item:{itemId}:0`, n = given })
		if equip and lastIndex and def.slot then
			local ok, err = EquipmentService.Equip(player, lastIndex)
			if not ok then
				reply(player, err or "equip.error.slot")
			end
		end
	end)
end

-- S29: test set for the character window's drag & drop: the class gear of the character's level in the
-- backpack (not equipped; two rings for the ring swap), a helmet 10 levels too high (red slot "requires
-- level") and a weapon of another class (red slot "class").
commands.gearbag = function(player, _args)
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local level = character.level
		local tier = Items.generate.tierFor(level)
		local given = 0
		local function give(id: string, ilvl: number): boolean
			local leftover = InventoryService.GiveNew(player, id, 1, 2, ilvl)
			if leftover > 0 then
				return false
			end
			given += 1
			return true
		end
		local pieces = DevPreset.pick(character.class, level)
		local full = false
		for _, piece in pieces do
			if not give(piece.id, tier) then
				full = true
				break
			end
		end
		if not full and level + 10 <= Config.MaxLevel then
			for _, piece in pieces do
				if piece.slot == "helmet" then
					full = not give(piece.id, level + 10)
					break
				end
			end
		end
		if not full then
			for class, gear in Items.startingGear do
				if class ~= character.class then
					full = not give(gear[1], level)
					break
				end
			end
		end
		if full then
			reply(player, "inventory.full")
		end
		reply(player, "admin.gearbag.ok", { n = given })
	end)
end

-- S32: /gearset <level> [rarity]: the class's full set (Logic/DevPreset types) of item level `level`, rolled at
-- `rarity` (bonuses for the class), equipped through the normal Equip path (old pieces go to the backpack;
-- pieces above the character's level stay in the backpack).
commands.gearset = function(player, args)
	local level = parseAmount(args[1])
	local rarity = Rarities.parse(args[2] or "common")
	if not level or not rarity then
		reply(player, "admin.usage.gearset")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local ilvl = math.clamp(level, 1, Config.MaxLevel)
		local equipped = 0
		for _, piece in DevPreset.pick(character.class, ilvl) do
			local leftover, item =
				InventoryService.GiveNew(player, piece.id, 1, rarity, ilvl, character.class :: string)
			if leftover > 0 or not item then
				reply(player, "inventory.full")
				break
			end
			local def = Items.get(piece.id)
			if def and def.elemental and item.el == nil then
				item.el = Elements.DEFAULT
			end
			local index = InventoryService.IndexOf(player, item.uid)
			if index then
				InventoryService.SetSlot(player, index, item)
				if EquipmentService.Equip(player, index, piece.slot) then
					equipped += 1
				end
			end
		end
		reply(player, "admin.gearset.ok", { ilvl = ilvl, rarity = `@rarity.{Rarities.get(rarity).key}`, n = equipped })
	end)
end

-- S30: /rarities: the rarity ladder in the panel console.
commands.rarities = function(player)
	for _, rarity in Rarities.list do
		reply(player, "admin.rarities.line", {
			id = rarity.id,
			name = `@{rarity.nameKey}`,
			color = rarity.hex,
			bonuses = if rarity.bonusMin == rarity.bonusMax
				then tostring(rarity.bonusMin)
				else `{rarity.bonusMin}-{rarity.bonusMax}`,
			legendary = rarity.legendaryLines,
			base = rarity.baseMul,
			range = rarity.rangeMul,
			sell = rarity.sellMul,
		})
	end
	local caps = {}
	for source, cap in Rarities.cap do
		table.insert(caps, `{source} {cap}`)
	end
	table.sort(caps)
	reply(player, "admin.rarities.caps", { list = table.concat(caps, ", ") })
end

-- S31: an item instance for /value and /tooltip: Common +0 at the definition level unless given.
local function sampleItem(def: Items.ItemDef, ilvl: number?, rarity: number?, up: number?): any
	local item: any =
		ItemRoll.rollItem(def.id, ilvl or def.level, rarity or def.rarity or Rarities.COMMON, Rng.new(1), "admin")
	if def.category == "equipment" then
		item.ilvl = math.clamp(ilvl or def.level, 1, Config.MaxLevel)
		item.up = math.clamp(up or 0, 0, 9)
	end
	return item
end

-- S31: /value <id> [ilvl] [rarity] [up]: value, NPC buy price (value x buyMul) and sell price.
commands.value = function(player, args)
	local def = Items.get(args[1] or "")
	if not def then
		reply(player, "admin.usage.value")
		return
	end
	local item = sampleItem(def, parseAmount(args[2]), Rarities.parse(args[3]), parseAmount(args[4]))
	local entry: Shops.Entry = { item = def.id, ilvl = if def.category == "equipment" then item.ilvl else nil }
	reply(player, "admin.value.result", {
		item = `#item:{def.id}:{item.up}`,
		ilvl = item.ilvl,
		rarity = `@{Rarities.get(item.rarity).nameKey}`,
		value = ItemValue.value(item),
		buy = ItemValue.buyPrice(
			entry,
			nil,
			PlayerStateService.GetCharacter(player) and PlayerStateService.GetCharacter(player).level or 1
		),
		sell = ItemValue.sellPrice(item),
	})
end

-- S31: /tooltip <id> [lang]: the TooltipModel lines (rich text removed) in the panel console.
commands.tooltip = function(player, args)
	local def = Items.get(args[1] or "")
	if not def then
		reply(player, "admin.usage.tooltip")
		return
	end
	local character = PlayerStateService.GetCharacter(player)
	local lang = if args[2] == "en" then "en" else "pl"
	local model = TooltipModel.build(sampleItem(def), def, {
		lang = lang,
		level = if character then character.level else nil,
		class = if character then character.class else nil,
		merchantOpen = true,
	})
	for _, line in model.lines do
		reply(player, "admin.tooltip.line", { role = line.role, text = TooltipModel.plain(line.text) })
	end
	local short = TooltipModel.statLine(sampleItem(def), def, lang)
	if short then
		reply(player, "admin.tooltip.line", { role = "statLine", text = short })
	end
end

local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

-- S67: "vs_undead 6.2, res_mage 3" of the family and class lines of one item; nil without any.
local function paramLines(item: any): string?
	local parts: { string } = {}
	for _, bonus in item.bonuses or {} do
		local def = Bonuses.get(bonus.stat)
		if def and def.param then
			table.insert(parts, `{bonus.stat} {bonus.v}`)
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else nil
end

-- S67: /givefam <item> <family|random> [rarity] [ilvl]: equipment rolled like loot of a monster of that family.
commands.givefam = function(player, args)
	local def = Items.get(args[1] or "")
	local familyArg = args[2]
	local family = if familyArg == "random" then nil else familyArg
	if
		not def
		or def.category ~= "equipment"
		or def.fixedBonuses
		or not familyArg
		or (family and not Families.get(family))
	then
		reply(player, "admin.usage.givefam")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local rarity = Rarities.parse(args[3]) or Rarities.HEROIC
		local ilvl = math.clamp(parseAmount(args[4]) or character.level, 1, Config.MaxLevel)
		local item = ItemRoll.rollItem(
			def.id,
			ilvl,
			rarity,
			Rng.new(),
			InventoryService.NewUid(),
			character.class :: string,
			{ family = family }
		)
		if InventoryService.AddItem(player, item) > 0 then
			reply(player, "inventory.full")
			return
		end
		reply(player, "admin.givefam.ok", {
			item = `#item:{def.id}:0`,
			lines = paramLines(item) or "@admin.itemscore.none",
		})
	end)
end

-- S67: sums of hooks with `prefix` per family / class after their caps ("undead 6/4").
local function lineSums(hooks: { [string]: number }, over: "family" | "class"): string
	local parts: { string } = {}
	local ids: { string } = if over == "family" then Families.ids :: any else Classes.order :: any
	for _, id in ids do
		local vsId = if over == "family" then Bonuses.familyLine("vs_", id) else Bonuses.classLine("vs_", id)
		local resId = if over == "family" then Bonuses.familyLine("res_", id) else Bonuses.classLine("res_", id)
		local vs, res = hooks[vsId] or 0, hooks[resId] or 0
		if over == "class" then
			vs = math.min(vs, Combat.classLineCap)
		end
		res = math.min(res, if over == "family" then Combat.familyResCap else Combat.classLineCap)
		if vs > 0 or res > 0 then
			table.insert(parts, `{id} +{round1(vs)}/-{round1(res)}`)
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else "@admin.itemscore.none"
end

-- S67: /itemscore: "Better item!" score of the worn items (by axis), family and class lines after their caps, and
-- up to 5 better items from the backpack.
commands.itemscore = function(player, _args)
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local path = character.path
		local mainPath = if path and type(path.main) == "string" then path.main else nil
		local ctx: ItemScore.Context =
			{ classId = character.class :: string, level = character.level, pathId = mainPath }
		local hooks = EquipmentService.GetHooks(player)
		reply(player, "admin.itemscore.head", {
			path = if mainPath then `@path.{mainPath}.name` else "@admin.itemscore.none",
			families = lineSums(hooks, "family"),
			classes = lineSums(hooks, "class"),
		})
		for _, slot in Items.equipmentSlots do
			local item = character.equipment[slot]
			if item then
				local b = ItemScore.breakdown(item, ctx)
				reply(player, "admin.itemscore.slot", {
					slot = `@slot.{slot}`,
					item = `#item:{item.id}:{item.up or 0}`,
					total = round1(b.total),
					dmg = round1(b.dmg),
					surv = round1(b.surv),
					support = round1(b.support),
					util = round1(b.util),
				})
			end
		end
		local better: { { item: any, gain: number } } = {}
		for _, item in character.inventory do
			local def = Items.get(item.id)
			if def and def.slot and def.category == "equipment" then
				local current: any
				if def.slot == "ring" then
					local a, b = character.equipment.ring1, character.equipment.ring2
					current = if a and b
						then (if ItemScore.score(a, ctx) <= ItemScore.score(b, ctx) then a else b)
						else nil
				else
					current = character.equipment[def.slot]
				end
				if ItemScore.isUpgrade(item, current, ctx, character.level) then
					local gain = ItemScore.score(item, ctx) - (if current then ItemScore.score(current, ctx) else 0)
					table.insert(better, { item = item, gain = gain })
				end
			end
		end
		table.sort(better, function(a, b)
			return a.gain > b.gain
		end)
		for i = 1, math.min(5, #better) do
			local entry = better[i]
			reply(player, "admin.itemscore.better", {
				item = `#item:{entry.item.id}:{entry.item.up or 0}`,
				gain = round1(entry.gain),
			})
		end
	end)
end

return commands
