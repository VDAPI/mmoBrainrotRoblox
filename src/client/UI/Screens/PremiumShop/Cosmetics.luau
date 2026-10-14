--!strict
-- Dragon Shop, "Cosmetics" tab (S120): the wardrobe card on top, then every cosmetic on sale the account does not own
-- yet (price > 0, not earned in the game), by kind in Data/Cosmetics.kinds order, then by price. "Try on" opens the
-- wardrobe on the cosmetic's tab with it tried on; buying asks first (UI/PremiumConfirm). A bought row disappears.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Cards = require(script.Parent.Cards)
local CosmeticData = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PremiumConfirm = require(script.Parent.Parent.Parent.PremiumConfirm)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Cosmetics = {}

local BUTTONS_WIDTH = 290

local function ownedOf(value: any): { [string]: boolean }
	return if type(value) == "table" then value else {}
end

-- Cosmetics on sale the account does not own, sorted by kind then price.
local function forSale(owned: { [string]: boolean }, pets: { [string]: boolean }): { CosmeticData.Def }
	local list: { CosmeticData.Def } = {}
	for _, def in CosmeticData.list do
		local mine = if def.kind == "pet" then pets[def.id] else owned[def.id]
		if def.price > 0 and def.obtain == nil and mine ~= true then
			table.insert(list, def)
		end
	end
	local rank: { [string]: number } = {}
	for i, kind in CosmeticData.kinds do
		rank[kind] = i
	end
	table.sort(list, function(a, b)
		local ra, rb = rank[a.kind] or 99, rank[b.kind] or 99
		if ra ~= rb then
			return ra < rb
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
	return list
end

local function row(
	scope: Scope,
	ctx: Cards.Ctx,
	def: CosmeticData.Def,
	order: number,
	shards: Fusion.Value<any>
): Instance
	local function spec(balance: number): PremiumConfirm.Spec
		return {
			name = Text.now(def.nameKey),
			desc = Text.now(`wardrobe.kind.{def.kind}`),
			price = def.price,
			shards = balance,
			remote = "PremiumBuyCosmetic",
			arg = def.id,
		}
	end
	local buttons = scope:New("Frame")({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(BUTTONS_WIDTH - 10, Theme.Size.MinTouch),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Button(scope, {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(120, Theme.Size.MinTouch),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.tryOn"),
				OnClick = function()
					ctx.OpenWardrobe({ kind = def.kind :: string, try = def.id })
				end,
			}),
			Button(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(150, Theme.Size.MinTouch),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = `◆ {Format.number(def.price)}`,
				Disabled = scope:Computed(function(use): boolean
					return (use(shards) or 0) < def.price
				end),
				OnClick = function()
					PremiumConfirm.ask(spec(Fusion.peek(shards) or 0))
				end,
			}),
		},
	})
	return Cards.card(scope, {
		order = order,
		glyph = def.icon,
		art = UiArt.cosmetic(def.id),
		tileColor = Color3.fromHex(def.color),
		title = Text.T(scope, def.nameKey),
		subtitle = Text.T(scope, `wardrobe.kind.{def.kind}`),
		button = buttons,
		buttonWidth = BUTTONS_WIDTH,
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			return PremiumConfirm.describe(spec(use(shards) or 0), "tooltip")
		end),
	})
end

function Cosmetics.build(scope: Scope, ctx: Cards.Ctx): { any }
	local shards = State.Value({ "account", "dragonShards" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local pets = State.Value({ "account", "pets", "owned" })
	-- S123: the weekly offer goes above this card (DESIGN-17 §4).
	local list: { any } = {
		Cards.card(scope, {
			order = 10,
			glyph = "♛",
			art = UiArt.shop("wardrobe"),
			title = Text.T(scope, "window.wardrobe.title"),
			subtitle = Text.T(scope, "premium.wardrobe.desc"),
			button = Cards.buyButton(scope, Text.T(scope, "premium.openWardrobe"), nil, function()
				ctx.OpenWardrobe(nil)
			end),
		}),
		Cards.sectionHeader(scope, 20, "premium.cosmetics.forSale"),
	}
	-- Rebuilt when the owned lists change (after a purchase the row disappears).
	table.insert(
		list,
		scope:Computed(function(use, s: Scope): { Instance }
			local defs = forSale(ownedOf(use(owned)), ownedOf(use(pets)))
			if #defs == 0 then
				return { Cards.note(s, 30, "premium.cosmetics.allOwned") }
			end
			local rows = {}
			for i, def in defs do
				table.insert(rows, row(s, ctx, def, 30 + i, shards))
			end
			return rows
		end)
	)
	return list
end

return Cosmetics
