--!strict
-- Item tooltip (DESIGN §23): name in the rarity colour, rarity and slot, item level, weapon / base stats
-- (with upgrades), bonuses with a roll-quality bar, requirements (red when unmet), comparison with the
-- equipped item (green ↑ / red ↓), binding, price and an action hint. Parchment panel that follows the
-- mouse; on touch it appears for the selected slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Bonuses = require(ReplicatedStorage.Shared.Data.Bonuses)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local State = require(script.Parent.Parent.State)
local Stats = require(ReplicatedStorage.Shared.Data.Stats)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type ItemInstance = Types.ItemInstance
type Scope = Fusion.Scope<typeof(Fusion)>

local ItemTooltip = {}

local WIDTH = 340
local OFFSET = Vector2.new(20, 20)
local DARK = Theme.Colors.TextDark
local MUTED = Color3.fromHex("#6B5E48")
local GOOD = Color3.fromHex("#2E8B3E")
local BAD = Color3.fromHex("#B8423A")

local moduleScope = Fusion.scoped(Fusion)
local shown = moduleScope:Value(nil :: ItemInstance?)
local emptyText = moduleScope:Value(nil :: string?)
local position = moduleScope:Value(Vector2.zero)
local owner: GuiObject? = nil
local getters: { [string]: () -> ItemInstance? } = {}

-- Stat display helpers -----------------------------------------------------------------------------------

local ALIASES: { [string]: string } = { hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }

local function statName(lang: string, id: string): string
	return Locale.T(`stat.{ALIASES[id] or id}`, nil, lang)
end

local function formatStat(id: string, value: number): string
	local def = Stats.get(ALIASES[id] or id)
	local decimals = if def then def.decimals else (if value % 1 == 0 then 0 else 1)
	local text = if decimals == 0 then Format.number(value) else string.format(`%.{decimals}f`, value)
	return if def and def.format == "pct" then text .. "%" else text
end

local function bonusText(lang: string, id: string, value: number): string
	local def = Bonuses.get(id)
	local decimals = if def then def.decimals else 0
	local v = if decimals == 0 then tostring(math.floor(value + 0.5)) else string.format(`%.{decimals}f`, value)
	return Locale.T(`bonus.{id}`, { v = v }, lang)
end

-- Equipped item to compare with (same slot group; rings compare with ring1).
local function equippedFor(def: Items.ItemDef): ItemInstance?
	if not def.slot or def.slot == "backpack" then
		return nil
	end
	local equipment = State.Get({ "character", "equipment" })
	if type(equipment) ~= "table" then
		return nil
	end
	if def.slot == "ring" then
		return equipment.ring1 or equipment.ring2
	end
	return equipment[def.slot]
end

-- Comparable numbers of an item: weapon damage + flat totals.
local function comparable(item: ItemInstance): { [string]: number }
	local stats = ItemRoll.itemStats(item)
	local values: { [string]: number } = {}
	if stats.weapon then
		values.weaponDmg = stats.weapon.dmg
		values.weaponMdmg = stats.weapon.mdmg
	end
	for stat, v in stats.flat do
		local key = ALIASES[stat] or stat
		values[key] = (values[key] or 0) + v
	end
	return values
end

-- Content ---------------------------------------------------------------------------------------------------

local function line(s: Scope, order: number, text: string, color: Color3, size: number?, font: Font?): Instance
	return s:New("TextLabel")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		RichText = true,
		TextWrapped = true,
		FontFace = font or Theme.Fonts.BodyMedium,
		TextSize = size or Theme.TextSize.Small,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function bonusRow(s: Scope, order: number, text: string, quality: number, legendary: boolean): Instance
	return s:New("Frame")({
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		[Children] = {
			s:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -54, 1, 0),
				Text = text,
				TextWrapped = true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if legendary then Color3.fromHex("#C26A00") else Color3.fromHex("#1F4E9A"),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Name = "Quality",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(46, 6),
				BackgroundColor3 = Color3.fromHex("#CDBF9C"),
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("Frame")({
						Size = UDim2.fromScale(math.clamp(quality, 0.05, 1), 1),
						BackgroundColor3 = if quality >= 0.9
							then Color3.fromHex("#C26A00")
							elseif quality >= 0.5 then GOOD
							else MUTED,
						[Children] = s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					}),
				},
			}),
		},
	})
end

local function build(s: Scope, item: ItemInstance, lang: string): { Instance }
	local def = Items.get(item.id)
	local out: { Instance } = {}
	local order = 0
	local function add(instance: Instance)
		order += 1
		table.insert(out, instance)
	end
	local function addLine(text: string, color: Color3?, size: number?, font: Font?)
		order += 1
		table.insert(out, line(s, order, text, color or DARK, size, font))
	end
	if not def then
		addLine(Locale.T("item.unknown", nil, lang))
		return out
	end

	local rarity = Rarities.get(item.rarity)
	local rarityColor = ItemText.rarityColor(item.rarity)
	-- Darker rarity colour for legibility on parchment.
	local nameColor = rarityColor:Lerp(Color3.new(0, 0, 0), 0.35)
	addLine(ItemText.nameIn(lang, item.id, item.up), nameColor, Theme.TextSize.Large, Theme.Fonts.Heading)

	local typeParts = {}
	if def.category == "equipment" and rarity then
		table.insert(typeParts, Locale.T(rarity.nameKey, nil, lang))
	end
	if def.slot then
		local slotKey = if def.slot == "ring" then "slot.ring1" else `slot.{def.slot}`
		table.insert(typeParts, Locale.T(slotKey, nil, lang))
	else
		table.insert(typeParts, Locale.T(`category.{def.category}`, nil, lang))
	end
	addLine(table.concat(typeParts, " · "), MUTED)
	if def.category == "equipment" then
		addLine(Locale.T("tooltip.ilvl", { ilvl = item.ilvl }, lang), MUTED)
	end

	-- Base stats
	local stats = ItemRoll.itemStats(item)
	if stats.weapon then
		local w = stats.weapon
		if w.dmg > 0 then
			addLine(Locale.T("tooltip.damage", { dmg = w.dmg }, lang), DARK, Theme.TextSize.Body, Theme.Fonts.BodyBold)
		end
		if w.mdmg > 0 then
			addLine(
				Locale.T("tooltip.magicDamage", { mdmg = w.mdmg }, lang),
				DARK,
				Theme.TextSize.Body,
				Theme.Fonts.BodyBold
			)
		end
		local tags = { Locale.T("tooltip.speed", { speed = string.format("%.2f", w.speed) }, lang) }
		if w.twoHanded then
			table.insert(tags, Locale.T("tooltip.twoHanded", nil, lang))
		end
		if w.ranged then
			table.insert(tags, Locale.T("tooltip.ranged", nil, lang))
		end
		addLine(table.concat(tags, " · "), MUTED)
	end
	local baseKeys = {}
	for stat in stats.base do
		table.insert(baseKeys, stat)
	end
	table.sort(baseKeys)
	for _, stat in baseKeys do
		addLine(`{statName(lang, stat)}: <b>{formatStat(stat, stats.base[stat])}</b>`, DARK)
	end
	if def.capacity then
		addLine(Locale.T("tooltip.capacity", { capacity = def.capacity }, lang), DARK, nil, Theme.Fonts.BodyBold)
	end
	if def.use and def.use.kind == "potion" and def.use.resource then
		addLine(
			Locale.T(`tooltip.restores.{def.use.resource}`, { amount = Format.number(def.use.amount or 0) }, lang),
			DARK
		)
	end

	-- Blessings list what they give while active (S15).
	if def.use and def.use.kind == "blessing" and def.use.target then
		local blessing = Blessings.get(def.use.target)
		if blessing then
			local ids = {}
			for stat in blessing.stats do
				table.insert(ids, stat)
			end
			table.sort(ids)
			for _, stat in ids do
				addLine(`{statName(lang, stat)}: <b>+{formatStat(stat, blessing.stats[stat])}</b>`, DARK)
			end
			addLine(Locale.T("tooltip.blessingDuration", { time = Format.timeLong(Blessings.DURATION) }, lang), MUTED)
		end
	end

	-- Bonuses with roll quality
	for _, bonus in stats.bonuses do
		local bonusDef = Bonuses.get(bonus.id)
		order += 1
		add(
			bonusRow(
				s,
				order,
				bonusText(lang, bonus.id, bonus.v),
				bonus.quality,
				bonusDef ~= nil and bonusDef.hook ~= nil or string.sub(bonus.id, 1, 4) == "leg_"
			)
		)
	end

	if def.descKey then
		addLine(`<i>{Locale.T(def.descKey, nil, lang)}</i>`, MUTED)
	end

	-- Requirements
	local level = State.Get({ "character", "level" }) or 1
	local classId = State.Get({ "character", "class" })
	if def.level > 1 then
		addLine(
			Locale.T("tooltip.requiresLevel", { level = def.level }, lang),
			if level >= def.level then DARK else BAD
		)
	end
	if def.classes then
		local names = {}
		for _, id in def.classes do
			local class = Classes.get(id)
			table.insert(names, if class then Locale.T(class.nameKey, nil, lang) else id)
		end
		local ok = classId == nil or table.find(def.classes, classId) ~= nil
		addLine(Locale.T("tooltip.classes", { classes = table.concat(names, ", ") }, lang), if ok then DARK else BAD)
	end

	-- Comparison with the equipped item
	local equipped = equippedFor(def)
	if equipped and equipped.uid ~= item.uid then
		local mine, theirs = comparable(item), comparable(equipped)
		local keys = {}
		for k in mine do
			keys[k] = true
		end
		for k in theirs do
			keys[k] = true
		end
		local lines = {}
		for k in keys do
			local diff = (mine[k] or 0) - (theirs[k] or 0)
			if math.abs(diff) >= 0.05 then
				local label = if k == "weaponDmg"
					then Locale.T("tooltip.damage", { dmg = "" }, lang)
					elseif k == "weaponMdmg" then Locale.T("tooltip.magicDamage", { mdmg = "" }, lang)
					else statName(lang, k)
				local arrow = if diff > 0 then "↑" else "↓"
				local color = if diff > 0 then "#2E8B3E" else "#B8423A"
				local sign = if diff > 0 then "+" else "−"
				table.insert(
					lines,
					`<font color="{color}">{arrow} {sign}{formatStat(k, math.abs(diff))} {label}</font>`
				)
			end
		end
		if #lines > 0 then
			table.sort(lines)
			addLine(Locale.T("tooltip.compare", nil, lang), MUTED)
			addLine(table.concat(lines, "\n"), DARK)
		end
	end

	-- Binding and price
	if def.category == "equipment" then
		if item.bound then
			addLine(Locale.T("tooltip.bound", nil, lang), BAD)
		elseif def.bindOnPickup then
			addLine(Locale.T("tooltip.bindOnPickup", nil, lang), MUTED)
		else
			addLine(Locale.T("tooltip.bindOnEquip", nil, lang), MUTED)
		end
	end
	if item.n > 1 then
		addLine(Locale.T("tooltip.stack", { n = item.n }, lang), MUTED)
	end
	addLine(Locale.T("tooltip.price", { price = Format.number(ItemRoll.sellPrice(item)) }, lang), MUTED)
	if def.slot then
		addLine(Locale.T("tooltip.hintEquip", nil, lang), MUTED)
	elseif def.use and def.use.kind ~= "none" then
		addLine(Locale.T("tooltip.hintUse", nil, lang), MUTED)
	end
	return out
end

-- Show / hide -----------------------------------------------------------------------------------------------

local function show(object: GuiObject, item: ItemInstance?, text: string?, at: Vector2)
	owner = object
	shown:set(item)
	emptyText:set(if item then nil else text)
	position:set(at)
end

local function hide(object: GuiObject?)
	if object == nil or owner == object then
		owner = nil
		shown:set(nil)
		emptyText:set(nil)
	end
end

function ItemTooltip.hide()
	hide(nil)
end

function ItemTooltip.attach(
	scope: Scope,
	object: GuiObject,
	getItem: () -> ItemInstance?,
	empty: Fusion.UsedAs<string>?,
	slotId: string
)
	table.insert(
		scope,
		object.MouseEnter:Connect(function(x, y)
			if UserInputService.MouseEnabled then
				local text = if empty then Fusion.peek(empty) else nil
				local item = getItem()
				if item or text then
					show(object, item, text, Scale.toVirtual(Vector2.new(x, y)))
				end
			end
		end)
	)
	table.insert(
		scope,
		object.MouseMoved:Connect(function(x, y)
			if owner == object then
				position:set(Scale.toVirtual(Vector2.new(x, y)))
			end
		end)
	)
	table.insert(
		scope,
		object.MouseLeave:Connect(function()
			hide(object)
		end)
	)
	table.insert(scope, function()
		hide(object)
	end)
	-- Touch: the selected slot shows its tooltip (DragDrop.Selected).
	getters[slotId] = getItem
	table.insert(scope, function()
		if getters[slotId] == getItem then
			getters[slotId] = nil
		end
	end)
	table.insert(
		scope,
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			if owner == object and Fusion.peek(Device.Touch) then
				local p = Scale.toVirtual(object.AbsolutePosition)
				position:set(p)
			end
		end)
	)
end

-- Builds the floating panel inside `parent` (Tooltip layer root).
function ItemTooltip.mount(scope: Scope, parent: Instance)
	scope:Observer(DragDrop.Selected):onChange(function()
		if not Fusion.peek(Device.Touch) then
			return
		end
		local selected = Fusion.peek(DragDrop.Selected)
		local getter = selected and getters[selected]
		local item = getter and getter()
		if item then
			local screen = Fusion.peek(Scale.VirtualSize)
			owner = nil
			shown:set(item)
			emptyText:set(nil)
			position:set(Vector2.new(screen.X / 2 - WIDTH / 2 - OFFSET.X, 70))
		else
			hide(nil)
		end
	end)

	scope:New("Frame")({
		Name = "ItemTooltip",
		Parent = parent,
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Parchment,
		Visible = scope:Computed(function(use): boolean
			return (use(shown) ~= nil or use(emptyText) ~= nil) and use(DragDrop.Dragging) == nil
		end),
		ZIndex = 200,
		Position = scope:Computed(function(use): UDim2
			local p: Vector2 = use(position)
			local screen: Vector2 = use(Scale.VirtualSize)
			local x = p.X + OFFSET.X
			if x + WIDTH > screen.X - 8 then
				x = p.X - OFFSET.X - WIDTH
			end
			return UDim2.fromOffset(math.max(8, x), math.max(8, math.min(p.Y + OFFSET.Y, screen.Y - 200)))
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Thickness = 2,
				Color = scope:Computed(function(use): Color3
					local item = use(shown)
					return if item then ItemText.rarityColor(item.rarity) else Theme.Colors.GoldDim
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 3),
			}),
			scope:Computed(function(use, s: Scope): { Instance }
				local item = use(shown)
				local lang = use(Text.Lang)
				if item then
					return build(s, item, lang)
				end
				local text = use(emptyText)
				return if text then { line(s, 1, text, DARK) } else {}
			end) :: any,
		},
	})
end

return ItemTooltip
