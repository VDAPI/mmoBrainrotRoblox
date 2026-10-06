--!strict
-- Dev panel, "Items" tab (S23): live catalogue search with filters (category / slot, class, level range), a
-- text list of at most 80 results, the details of the chosen item (rarity, item level, upgrade, element,
-- amount, "Give" / "Give and equip") and quick actions (materials, scrolls, random legendary, empty the
-- backpack, upgrade an equipped slot, loot simulation).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

local MAX_RESULTS = 80

-- Catalogue sorted by level then id (built once).
local catalogue: { Items.ItemDef }? = nil
local function allItems(): { Items.ItemDef }
	if not catalogue then
		local list = {}
		for _, def in Items.byId do
			table.insert(list, def)
		end
		table.sort(list, function(a, b)
			if a.level ~= b.level then
				return a.level < b.level
			end
			return a.id < b.id
		end)
		catalogue = list
	end
	return catalogue :: { Items.ItemDef }
end

local function ItemsTab(s: Dev.Scope): Instance
	local query = s:Value("")
	local kind = s:Value("all" :: string?)
	local class = s:Value("all" :: string?)
	local minLevel = s:Value(1)
	local maxLevel = s:Value(100)
	local chosen = s:Value(nil :: string?)
	local rarity = s:Value("4" :: string?)
	local ilvl = s:Value(0)
	local up = s:Value(0)
	local element = s:Value("none" :: string?)
	local count = s:Value(1)
	local mats = s:Value(50)
	local upSlot = s:Value("weapon" :: string?)
	local upLevel = s:Value(7)
	local simMonster = s:Value(nil :: string?)
	local simVariant = s:Value("0" :: string?)
	local simCount = s:Value(1000)

	local kinds = { { value = "all", label = Text.now("dev.items.all") } }
	for _, category in { "material", "consumable", "scroll", "stone", "backpack", "tool" } do
		table.insert(kinds, { value = `cat:{category}`, label = Text.now("dev.items.category", { name = category }) })
	end
	for _, slot in { "weapon", "offhand", "helmet", "armor", "gloves", "boots", "necklace", "ring", "talisman" } do
		table.insert(kinds, { value = `slot:{slot}`, label = Text.now("dev.items.slot", { name = slot }) })
	end
	local classOptions: { { value: string, label: string } } =
		{ { value = "all", label = Text.now("dev.items.anyClass") } }
	for _, id in Classes.order do
		local def = Classes.get(id)
		if def then
			table.insert(classOptions, { value = def.id :: string, label = Text.now(def.nameKey) })
		end
	end
	local rarityOptions = {}
	for r = 1, 5 do
		local rdef = Rarities.get(r)
		table.insert(rarityOptions, {
			value = tostring(r),
			label = if rdef then Text.now(rdef.nameKey) else tostring(r),
			color = ItemText.rarityColor(r),
		})
	end
	local elementOptions = {}
	for _, el in { "none", "fire", "ice", "lightning" } do
		table.insert(elementOptions, { value = el, label = if el == "none" then "—" else Text.now(`element.{el}`) })
	end
	local slotOptions = {}
	for _, slot in Items.equipmentSlots do
		table.insert(slotOptions, { value = slot, label = slot })
	end
	local monsterOptions = {}
	for _, def in Monsters.list do
		table.insert(
			monsterOptions,
			{ value = def.id, label = `{Text.now(def.nameKeys.normal)} ({def.levels.min}–{def.levels.max})` }
		)
	end
	local variantOptions = {
		{ value = "0", label = Text.now("dev.variant.normal") },
		{ value = "1", label = Text.now("dev.variant.elite") },
		{ value = "2", label = Text.now("dev.variant.elite2") },
	}

	local results = s:Computed(function(use): { Items.ItemDef }
		local q = string.lower(use(query))
		local k = use(kind) or "all"
		local c = use(class) or "all"
		local lo, hi = use(minLevel), use(maxLevel)
		use(Text.Lang)
		local out = {}
		for _, def in allItems() do
			if def.level < lo or def.level > hi then
				continue
			end
			if string.sub(k, 1, 4) == "cat:" and def.category ~= string.sub(k, 5) then
				continue
			end
			if string.sub(k, 1, 5) == "slot:" and def.slot ~= string.sub(k, 6) then
				continue
			end
			if c ~= "all" and def.classes and not table.find(def.classes, c) then
				continue
			end
			if q ~= "" then
				local name = string.lower(ItemText.name(def.id))
				if not string.find(name, q, 1, true) and not string.find(def.id, q, 1, true) then
					continue
				end
			end
			table.insert(out, def)
		end
		return out
	end)

	local rows = s:Computed(function(use, inner: Dev.Scope): { Instance }
		local list = use(results)
		local out = {}
		for i, def in list do
			if i > MAX_RESULTS then
				break
			end
			local color = ItemText.rarityColor(def.rarity or (if def.bossId then 6 else 1))
			table.insert(
				out,
				inner:New("TextButton")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 30),
					AutoButtonColor = true,
					BackgroundColor3 = if use(chosen) == def.id then Theme.Colors.PanelHover else Theme.Colors.Panel,
					Text = `{ItemText.name(def.id)}   ·   {def.type}   ·   {Text.now(
						"dev.items.level",
						{ level = def.level }
					)}`,
					FontFace = Theme.Fonts.Body,
					TextSize = 14,
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					[OnEvent("Activated")] = function()
						chosen:set(def.id)
						ilvl:set(def.level)
					end,
					[Children] = inner:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }),
				})
			)
		end
		if #list > MAX_RESULTS then
			table.insert(
				out,
				inner:New("TextLabel")({
					LayoutOrder = MAX_RESULTS + 1,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = Text.get(use, "dev.items.more", { n = #list - MAX_RESULTS }),
					FontFace = Theme.Fonts.Body,
					TextSize = 13,
					TextColor3 = Theme.Colors.TextMuted,
				})
			)
		end
		return out
	end)

	local function giveArgs(equip: boolean): { string }
		local id = Fusion.peek(chosen) or ""
		return {
			id,
			Fusion.peek(rarity) or "1",
			tostring(math.max(1, Fusion.peek(ilvl))),
			tostring(Fusion.peek(up)),
			Fusion.peek(element) or "none",
			tostring(Fusion.peek(count)),
			if equip then "yes" else "no",
		}
	end

	return Dev.column(s, {
		Dev.header(s, 1, "dev.items.search"),
		Dev.row(s, 2, nil, {
			Dev.textBox(s, query, Text.now("dev.items.searchHint"), 220),
			Select(s, { Options = kinds, Selected = kind, Width = 170 }),
			Select(s, { Options = classOptions :: any, Selected = class, Width = 150 }),
		}),
		Dev.row(s, 3, Text.T(s, "dev.items.levels"), {
			NumberInput(s, { Value = minLevel, Min = 1, Max = 100, Step = 5 }),
			NumberInput(s, { Value = maxLevel, Min = 1, Max = 100, Step = 5 }),
		}),
		s:New("Frame")({
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 240),
			BackgroundColor3 = Theme.Colors.Background,
			[Children] = {
				s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				s:New("ScrollingFrame")({
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 6,
					[Children] = {
						s:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
						rows :: any,
					},
				}),
			},
		}),
		s:New("TextLabel")({
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = s:Computed(function(use): string
				local id = use(chosen)
				use(Text.Lang)
				return if id then `▸ {ItemText.name(id)} ({id})` else Text.get(use, "dev.items.pick")
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Dev.row(s, 6, nil, {
			Select(s, { Options = rarityOptions, Selected = rarity, Width = 150, ListHeight = 180 }),
			NumberInput(s, { Value = ilvl, Min = 1, Max = 100, Step = 5 }),
			NumberInput(s, { Value = up, Min = 0, Max = 9, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Select(s, { Options = elementOptions, Selected = element, Width = 130, ListHeight = 160 }),
			NumberInput(s, { Value = count, Min = 1, Max = 999, Size = UDim2.fromOffset(140, Theme.Size.MinTouch) }),
		}),
		s:New("TextLabel")({
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = Text.T(s, "dev.items.detailHint"),
			FontFace = Theme.Fonts.Body,
			TextSize = 13,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Dev.row(s, 8, nil, {
			Dev.button(s, Text.T(s, "dev.give"), function()
				if Fusion.peek(chosen) then
					Dev.run("givex", giveArgs(false))
				end
			end, 150),
			Dev.button(s, Text.T(s, "dev.items.giveEquip"), function()
				if Fusion.peek(chosen) then
					Dev.run("givex", giveArgs(true))
				end
			end, 170),
		}),
		Dev.header(s, 9, "dev.items.quick"),
		Dev.row(s, 10, nil, {
			NumberInput(s, { Value = mats, Min = 1, Max = 999, Step = 10 }),
			Dev.button(s, Text.T(s, "dev.items.mats"), function()
				Dev.run("mats", { tostring(Fusion.peek(mats)) })
			end, 140),
			Dev.button(s, Text.T(s, "dev.items.scrolls"), function()
				Dev.run("scrolls", { tostring(math.min(99, Fusion.peek(mats))) })
			end, 140),
			Dev.button(s, Text.T(s, "dev.items.legend"), function()
				Dev.run("legend")
			end, 160),
			Dev.button(s, Text.T(s, "dev.items.clear"), function()
				Dev.run("clearinv")
			end, 160, true),
		}),
		Dev.row(s, 11, Text.T(s, "dev.items.upgrade"), {
			Select(s, { Options = slotOptions, Selected = upSlot, Width = 150 }),
			NumberInput(s, { Value = upLevel, Min = 0, Max = 9, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("up", { Fusion.peek(upSlot) or "weapon", tostring(Fusion.peek(upLevel)) })
			end),
		}),
		Dev.row(s, 12, Text.T(s, "dev.items.lootsim"), {
			Select(s, { Options = monsterOptions, Selected = simMonster, Width = 220 }),
			Select(s, { Options = variantOptions, Selected = simVariant, Width = 140, ListHeight = 120 }),
			NumberInput(s, { Value = simCount, Min = 1, Max = 100000, Step = 100 }),
			Dev.button(s, "▶", function()
				local monster = Fusion.peek(simMonster)
				if monster then
					Dev.run("lootsim", { monster, Fusion.peek(simVariant) or "0", tostring(Fusion.peek(simCount)) })
				end
			end, 60),
		}),
		Dev.header(s, 13, "dev.allCommands"),
		Dev.commandRows(s, 14, { "items" }) :: any,
	})
end

return ItemsTab
