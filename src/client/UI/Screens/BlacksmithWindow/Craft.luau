--!strict
-- Forge → Crafting (DESIGN §8): filter by class (mine / all), slot and level tier; each recipe shows the item
-- (tooltip with its fixed stats), gold and materials owned / needed (red when missing) and "Forge".
-- Adoption stage (UI package D after C, 2026-11-10; owner 2026-11-10: "things covering each other"): the class and
-- level filters stand in the window's Footer (the view gives them to BlacksmithWindow), so the recipes take the rest
-- of the body under the slot tabs (Logic/GearLayout.tabsTop) on a phone too.
-- Review 2026-11-11 (UI plan L10: two rows of a list on a phone): a list lower than two 70-px rows (a phone under
-- Roblox's 58-px top bar showed 1.8) takes compact 58-px rows, a 44-px item and a 44-px "Wykuj"
-- (Logic/GearLayout.smithCraft from the view's measured size, UI/ViewSize). The gold stands left of "Wykuj" on the
-- name's line (red when short, like a missing material), so the materials keep one line on a 667-px phone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bases = require(ReplicatedStorage.Shared.Data.Items.Bases)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Crafting = require(ReplicatedStorage.Shared.Data.Crafting)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local ItemSlot = require(script.Parent.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)
local ViewSize = require(script.Parent.Parent.Parent.ViewSize)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

-- the smith's view on PC (under its tabs, above its footer) until it is measured
local AREA_PC = { w = 816, h = 448 }

local SLOT_GROUPS: { { id: string, slots: { [string]: boolean } } } = {
	{ id = "weapon", slots = { weapon = true } },
	{ id = "offhand", slots = { offhand = true } },
	{ id = "armor", slots = { helmet = true, armor = true, gloves = true, boots = true } },
	{ id = "jewelry", slots = { necklace = true, ring = true, talisman = true } },
}

local function count(inv: any, itemId: string): number
	local n = 0
	for _, item in inv or {} do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

local function Craft(scope: Scope): { View: Instance, Footer: Fusion.Child }
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local inventory = State.Value({ "character", "inventory" })
	local gold = State.Value({ "character", "gold" })
	local mine = scope:Value(true)
	local group = scope:Value("weapon")
	local tierIndex = scope:Value(1)

	-- Start at the highest tier the character can use.
	do
		local current = Fusion.peek(level) or 1
		local best = 1
		for i, tier in Bases.tiers do
			if tier <= current then
				best = i
			end
		end
		tierIndex:set(best)
	end

	local tier = scope:Computed(function(use): number
		return Bases.tiers[use(tierIndex)] or 1
	end)

	-- the rows' height from the view's own size (GearLayout.smithCraft): compact while the list is low
	local view = ViewSize.new(scope)
	local layout = scope:Computed(function(use): GearLayout.SmithCraft
		return GearLayout.smithCraft(use(view.size) or AREA_PC)
	end)

	local rows = scope:Computed(function(use, s: Scope): { Instance }
		-- one row: the item `pad` in from the row's edges; from L.x the name with the gold at its end and under them
		-- the materials, up to "Wykuj" (`right` from the row's right end)
		local C = GearLayout.CRAFT
		local L = use(layout)
		local pad = (L.row - L.icon) / 2
		local right = C.forge + 2 * C.edge
		local top = if L.compact then 3 else 6
		local slots: { [string]: boolean } = {}
		for _, g in SLOT_GROUPS do
			if g.id == use(group) then
				slots = g.slots
			end
		end
		local list = {}
		local order = 0
		for _, recipe in Crafting.list do
			local fits = recipe.level == use(tier) and slots[recipe.slot] == true
			if fits and use(mine) and recipe.classes then
				fits = table.find(recipe.classes, use(classId) or "") ~= nil
			end
			if fits then
				order += 1
				local preview: Types.ItemInstance = {
					uid = `craft:{recipe.id}`,
					id = recipe.item,
					rarity = 1,
					ilvl = recipe.level,
					bonuses = {},
					up = 0,
					bound = false,
					n = 1,
					el = recipe.el,
				}
				local parts: { string } = {}
				local poor = (use(gold) or 0) < recipe.gold
				local missing = poor
				local inv = use(inventory)
				for _, material in recipe.materials do
					local have = count(inv, material.id)
					if have < material.n then
						missing = true
					end
					local color = if have >= material.n
						then Theme.hex(Theme.Paper.Success)
						else Theme.hex(Theme.Paper.Danger)
					table.insert(
						parts,
						`<font color="{color}">{ItemText.get(use, material.id)} {have}/{material.n}</font>`
					)
				end
				table.insert(
					list,
					s:New("Frame")({
						Name = recipe.id,
						LayoutOrder = order,
						Size = UDim2.new(1, 0, 0, L.row),
						BackgroundColor3 = Theme.Paper.Raised,
						BackgroundTransparency = 0.4,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							ItemSlot(s, {
								SlotId = `view:craft:{recipe.id}`,
								Item = preview,
								Size = L.icon,
								Position = UDim2.fromOffset(pad, pad),
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(L.x, top),
								Size = UDim2.new(1, -(L.x + right + C.gold + C.edge), 0, 26),
								BackgroundTransparency = 1,
								Text = ItemText.get(use, recipe.item, nil, recipe.el),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Paper.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("TextLabel")({
								Name = "Gold",
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, -right, 0, top),
								Size = UDim2.fromOffset(C.gold, 26),
								BackgroundTransparency = 1,
								Text = `◉ {Format.number(recipe.gold)}`,
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = if poor then Theme.Paper.Danger else Theme.Paper.Heading,
								TextXAlignment = Enum.TextXAlignment.Right,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(L.x, top + 28),
								Size = UDim2.new(1, -(L.x + right), 0, L.row - 2 * top - 28),
								BackgroundTransparency = 1,
								RichText = true,
								TextWrapped = true,
								Text = table.concat(parts, "  "),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Paper.Heading,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							Button(s, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -C.edge, 0.5, 0),
								Size = UDim2.fromOffset(C.forge, if L.compact then GearLayout.TOUCH else C.button),
								Variant = "primary",
								Text = Text.T(s, "smith.craft"),
								Disabled = missing,
								OnClick = function()
									task.spawn(function()
										local ok, err = Net.Invoke("Craft", recipe.id)
										if ok then
											Sounds.play("levelUp")
											Toast.push(
												Text.now(
													"smith.crafted",
													{ name = ItemText.name(recipe.item, nil, recipe.el) }
												),
												"success"
											)
										else
											Sounds.play("error")
											Toast.push(Text.now(err or "error.internal"), "error")
										end
									end)
								end,
							}),
						},
					})
				)
			end
		end
		return list
	end)

	local root = scope:New("Frame")({
		Name = "Craft",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			view.ruler,
			Tabs(scope, {
				Selected = group,
				Tabs = {
					{ id = "weapon", label = Text.T(scope, "slot.weapon") },
					{ id = "offhand", label = Text.T(scope, "slot.offhand") },
					{ id = "armor", label = Text.T(scope, "slot.armor") },
					{ id = "jewelry", label = Text.T(scope, "slot.necklace") },
				},
			}),
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, GearLayout.tabsTop()),
				Size = UDim2.new(1, 0, 1, -GearLayout.tabsTop()),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Paper.Rule,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, GearLayout.CRAFT.gap),
					}),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, GearLayout.CRAFT.inset) }),
					rows :: any,
				},
			}),
		},
	})
	view.watch(root)
	return {
		View = root,
		-- the footer's row: the filters, from its left end
		Footer = scope:New("Frame")({
			Name = "Filters",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				Button(scope, {
					LayoutOrder = 1,
					Size = UDim2.new(0, 150, 1, 0),
					TextSize = Theme.TextSize.Small,
					Variant = scope:Computed(function(use): any
						return if use(mine) then "primary" else "secondary"
					end),
					Text = scope:Computed(function(use): string
						return Text.get(use, if use(mine) then "smith.filter.mine" else "smith.filter.all")
					end),
					OnClick = function()
						mine:set(not Fusion.peek(mine))
					end,
				}),
				Button(scope, {
					LayoutOrder = 2,
					Size = UDim2.new(0, GearLayout.TOUCH, 1, 0),
					Text = "−",
					OnClick = function()
						tierIndex:set(math.max(1, Fusion.peek(tierIndex) - 1))
					end,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 3,
					Size = UDim2.new(0, 110, 1, 0),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "smith.tier", { level = use(tier) })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
				}),
				Button(scope, {
					LayoutOrder = 4,
					Size = UDim2.new(0, GearLayout.TOUCH, 1, 0),
					Text = "+",
					OnClick = function()
						tierIndex:set(math.min(#Bases.tiers, Fusion.peek(tierIndex) + 1))
					end,
				}),
			},
		}),
	}
end

return Craft
