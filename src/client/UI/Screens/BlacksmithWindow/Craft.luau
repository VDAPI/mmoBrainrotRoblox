--!strict
-- Forge → Crafting (DESIGN §8): filter by class (mine / all), slot and level tier; each recipe shows the item
-- (tooltip with its fixed stats), gold and materials owned / needed (red when missing) and "Forge".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bases = require(ReplicatedStorage.Shared.Data.Items.Bases)
local Button = require(script.Parent.Parent.Parent.Components.Button)
local Crafting = require(ReplicatedStorage.Shared.Data.Crafting)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

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

local function Craft(scope: Scope): Instance
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

	local rows = scope:Computed(function(use, s: Scope): { Instance }
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
				}
				local parts = { `◉ {Format.number(recipe.gold)}` }
				local missing = (use(gold) or 0) < recipe.gold
				local inv = use(inventory)
				for _, material in recipe.materials do
					local have = count(inv, material.id)
					if have < material.n then
						missing = true
					end
					local color = if have >= material.n then "#4FD16B" else "#CC5248"
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
						Size = UDim2.new(1, 0, 0, 70),
						BackgroundColor3 = Theme.Colors.PanelRaised,
						BackgroundTransparency = 0.4,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							ItemSlot(s, {
								SlotId = `view:craft:{recipe.id}`,
								Item = preview,
								Size = 56,
								Position = UDim2.fromOffset(7, 7),
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(74, 6),
								Size = UDim2.new(1, -220, 0, 26),
								BackgroundTransparency = 1,
								Text = ItemText.get(use, recipe.item),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = Theme.Colors.Text,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(74, 34),
								Size = UDim2.new(1, -220, 0, 30),
								BackgroundTransparency = 1,
								RichText = true,
								TextWrapped = true,
								Text = table.concat(parts, "  "),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Colors.GoldBright,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							Button(s, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -8, 0.5, 0),
								Size = UDim2.fromOffset(130, 48),
								Variant = "primary",
								Text = Text.T(s, "smith.craft"),
								Disabled = missing,
								OnClick = function()
									task.spawn(function()
										local ok, err = Net.Invoke("Craft", recipe.id)
										if ok then
											Sounds.play("levelUp")
											Toast.push(
												Text.now("smith.crafted", { name = ItemText.name(recipe.item) }),
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

	return scope:New("Frame")({
		Name = "Craft",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = {
			Tabs(scope, {
				Selected = group,
				Tabs = {
					{ id = "weapon", label = Text.T(scope, "slot.weapon") },
					{ id = "offhand", label = Text.T(scope, "slot.offhand") },
					{ id = "armor", label = Text.T(scope, "slot.armor") },
					{ id = "jewelry", label = Text.T(scope, "slot.necklace") },
				},
			}),
			scope:New("Frame")({
				Name = "Filters",
				Position = UDim2.fromOffset(0, 48),
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Size = UDim2.fromOffset(150, 40),
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
						Size = UDim2.fromOffset(44, 40),
						Text = "−",
						OnClick = function()
							tierIndex:set(math.max(1, Fusion.peek(tierIndex) - 1))
						end,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.fromOffset(110, 40),
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return Text.get(use, "smith.tier", { level = use(tier) })
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.Parchment,
					}),
					Button(scope, {
						LayoutOrder = 4,
						Size = UDim2.fromOffset(44, 40),
						Text = "+",
						OnClick = function()
							tierIndex:set(math.min(#Bases.tiers, Fusion.peek(tierIndex) + 1))
						end,
					}),
				},
			}),
			scope:New("ScrollingFrame")({
				Position = UDim2.fromOffset(0, 100),
				Size = UDim2.new(1, 0, 1, -100),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.GoldDim,
				[Children] = {
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
					scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
					rows :: any,
				},
			}),
		},
	})
end

return Craft
