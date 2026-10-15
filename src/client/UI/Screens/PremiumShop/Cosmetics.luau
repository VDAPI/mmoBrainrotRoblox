--!strict
-- Dragon Shop, "Cosmetics" tab (S120): the wardrobe card on top, then every cosmetic on sale the account does not own
-- yet (price > 0, not earned in the game), by kind in Data/Cosmetics.kinds order, then by price. "Try on" opens the
-- wardrobe on the cosmetic's tab with it tried on; buying asks first (UI/PremiumConfirm). A bought row disappears.
-- S123 (DESIGN-17 §4): the offer of the week above the wardrobe card (Logic/WeeklyOffer.at: four cards, 2 x 2 on a
-- phone, the discounted one with "−30%" and the old price struck through, "Owned" instead of a button, "Try on",
-- the countdown to Monday 00:00 UTC; UI/WeeklyClock ticks, so a new week shows by itself). Every price here is
-- WeeklyOffer.priceOf and goes with the purchase (the server refuses another one: premium.error.priceChanged).
-- S132: a class outfit stays on sale for every account and says which class wears it ("Only for: {class}").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Cards = require(script.Parent.Cards)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local CosmeticData = require(ReplicatedStorage.Shared.Data.Cosmetics)
local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Device = require(script.Parent.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PremiumConfirm = require(script.Parent.Parent.Parent.PremiumConfirm)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local WeeklyClock = require(script.Parent.Parent.Parent.WeeklyClock)
local WeeklyOffer = require(ReplicatedStorage.Shared.Logic.WeeklyOffer)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Cosmetics = {}

local BUTTONS_WIDTH = 290
local OFFER_CARD_HEIGHT = 214

local function ownedOf(value: any): { [string]: boolean }
	return if type(value) == "table" then value else {}
end

local function owns(def: CosmeticData.Def, owned: { [string]: boolean }, pets: { [string]: boolean }): boolean
	return CosmeticRules.ownsIn(def, if def.kind == "pet" then pets else owned)
end

-- Cosmetics on sale the account does not own, sorted by kind then price.
local function forSale(owned: { [string]: boolean }, pets: { [string]: boolean }): { CosmeticData.Def }
	local list: { CosmeticData.Def } = {}
	for _, def in CosmeticData.list do
		if def.price > 0 and def.obtain == nil and not owns(def, owned, pets) then
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

local function spec(def: CosmeticData.Def, price: number, balance: number): PremiumConfirm.Spec
	return {
		name = Text.now(def.nameKey),
		desc = Text.now(`wardrobe.kind.{def.kind}`),
		price = price,
		shards = balance,
		remote = "PremiumBuyCosmetic",
		arg = def.id,
		arg2 = price, -- S123: the server refuses another price (a new week)
	}
end

-- "◆ 175 <s>250</s>" for the discounted one, "◆ 250" otherwise (rich text).
-- The kind of a cosmetic, with the class of a class outfit (S132).
local function kindText(use: Fusion.Use, def: CosmeticData.Def): string
	local kind = Text.get(use, `wardrobe.kind.{def.kind}`)
	local class = if def.class then Classes.get(def.class) else nil
	if class then
		return `{kind} · {Text.get(use, "wardrobe.onlyFor", { class = Text.get(use, class.nameKey) })}`
	end
	return kind
end

local function priceText(def: CosmeticData.Def, price: number): string
	if price < def.price then
		return `◆ {Format.number(price)}  <s>{Format.number(def.price)}</s>`
	end
	return `◆ {Format.number(price)}`
end

local function row(
	scope: Scope,
	ctx: Cards.Ctx,
	def: CosmeticData.Def,
	order: number,
	shards: Fusion.Value<any>,
	price: number
): Instance
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
				Text = `◆ {Format.number(price)}`,
				Disabled = scope:Computed(function(use): boolean
					return (use(shards) or 0) < price
				end),
				OnClick = function()
					PremiumConfirm.ask(spec(def, price, Fusion.peek(shards) or 0))
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
		subtitle = if price < def.price
			then scope:Computed(function(use): string
				local kind = kindText(use, def)
				return `{kind} · {Text.get(use, "wardrobe.weekly")} · <s>◆ {Format.number(def.price)}</s>`
			end)
			else scope:Computed(function(use): string
				return kindText(use, def)
			end),
		rich = price < def.price,
		badge = if price < def.price
			then Text.T(
				scope,
				"premium.weekly.discount",
				{ pct = math.floor(CosmeticData.weekly.discount * 100 + 0.5) }
			)
			else nil,
		button = buttons,
		buttonWidth = BUTTONS_WIDTH,
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			return PremiumConfirm.describe(spec(def, price, use(shards) or 0), "tooltip")
		end),
	})
end

-- One card of the offer of the week.
local function offerCard(
	scope: Scope,
	ctx: Cards.Ctx,
	def: CosmeticData.Def,
	order: number,
	price: number,
	isOwned: boolean,
	shards: Fusion.Value<any>
): Instance
	local discounted = price < def.price
	return scope:New("Frame")({
		LayoutOrder = order,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = if discounted then Theme.Colors.GoldBright else Theme.Colors.Border,
				Thickness = if discounted then Theme.Stroke.Normal else Theme.Stroke.Thin,
			}),
			scope:New("TextLabel")({
				Name = "Tile",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(52, 52),
				BackgroundColor3 = Color3.fromHex(def.color),
				Text = def.icon,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.4,
				[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) },
			}),
			-- "−30%" on the discounted one
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(56, 22),
				Visible = discounted,
				BackgroundColor3 = Theme.Colors.Accent,
				Text = Text.T(scope, "premium.weekly.discount", {
					pct = math.floor(CosmeticData.weekly.discount * 100 + 0.5),
				}),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Background,
				[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) },
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(6, 64),
				Size = UDim2.new(1, -12, 0, 24),
				BackgroundTransparency = 1,
				Text = Text.T(scope, def.nameKey),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(6, 88),
				Size = UDim2.new(1, -12, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return kindText(use, def)
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.TextMuted,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(6, 108),
				Size = UDim2.new(1, -12, 0, 22),
				BackgroundTransparency = 1,
				RichText = true,
				Text = if isOwned then Text.T(scope, "premium.owned") else priceText(def, price),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if isOwned then Theme.Colors.Success else Theme.Colors.Accent,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8 - Theme.Size.MinTouch - 6),
				Size = UDim2.new(1, -16, 0, Theme.Size.MinTouch),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.tryOn"),
				OnClick = function()
					ctx.OpenWardrobe({ kind = def.kind :: string, try = def.id })
				end,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0, Theme.Size.MinTouch),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = if isOwned then Text.T(scope, "premium.owned") else `◆ {Format.number(price)}`,
				Disabled = scope:Computed(function(use): boolean
					return isOwned or (use(shards) or 0) < price
				end),
				OnClick = function()
					if not isOwned then
						PremiumConfirm.ask(spec(def, price, Fusion.peek(shards) or 0))
					end
				end,
			}),
		},
	})
end

-- S123: the offer of the week: the header, the countdown and the four cards.
local function weekly(scope: Scope, ctx: Cards.Ctx, shards: Fusion.Value<any>, owned: any, pets: any): { any }
	local countdown = scope:Computed(function(use): string
		local now = use(WeeklyClock.Now)
		local d, h, m = Time.split(WeeklyOffer.endsAt(now) - now)
		return Text.get(use, "premium.weekly.ends", { d = d, h = h, m = m })
	end)
	local cards = scope:Computed(function(use, s: Scope): { Instance }
		local now = use(WeeklyClock.WeekStart)
		local mine, myPets = ownedOf(use(owned)), ownedOf(use(pets))
		local out: { Instance } = {}
		for i, id in WeeklyOffer.at(now).items do
			local def = CosmeticData.get(id)
			if def then
				local price = WeeklyOffer.priceOf(id, now) or def.price
				table.insert(out, offerCard(s, ctx, def, i, price, owns(def, mine, myPets), shards))
			end
		end
		return out
	end)
	return {
		Cards.sectionHeader(scope, 1, "premium.weekly.title"),
		scope:New("TextLabel")({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = countdown,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("Frame")({
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIGridLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					CellPadding = UDim2.fromOffset(8, 8),
					-- PC: four in a row; phone: 2 x 2
					CellSize = scope:Computed(function(use): UDim2
						return if use(Device.Touch)
							then UDim2.new(0.5, -4, 0, OFFER_CARD_HEIGHT)
							else UDim2.new(0.25, -6, 0, OFFER_CARD_HEIGHT)
					end),
				}),
				cards :: any,
			},
		}),
	}
end

function Cosmetics.build(scope: Scope, ctx: Cards.Ctx): { any }
	local shards = State.Value({ "account", "dragonShards" })
	local owned = State.Value({ "account", "cosmetics", "owned" })
	local pets = State.Value({ "account", "pets", "owned" })
	local list: { any } = weekly(scope, ctx, shards, owned, pets)
	table.insert(
		list,
		Cards.card(scope, {
			order = 10,
			glyph = "♛",
			art = UiArt.shop("wardrobe"),
			title = Text.T(scope, "window.wardrobe.title"),
			subtitle = Text.T(scope, "premium.wardrobe.desc"),
			button = Cards.buyButton(scope, Text.T(scope, "premium.openWardrobe"), nil, function()
				ctx.OpenWardrobe(nil)
			end),
		})
	)
	table.insert(list, Cards.sectionHeader(scope, 20, "premium.cosmetics.forSale"))
	-- Rebuilt when the owned lists or the week change (after a purchase the row disappears).
	table.insert(
		list,
		scope:Computed(function(use, s: Scope): { Instance }
			local now = use(WeeklyClock.WeekStart)
			local defs = forSale(ownedOf(use(owned)), ownedOf(use(pets)))
			if #defs == 0 then
				return { Cards.note(s, 30, "premium.cosmetics.allOwned") }
			end
			local rows = {}
			for i, def in defs do
				table.insert(rows, row(s, ctx, def, 30 + i, shards, WeeklyOffer.priceOf(def.id, now) or def.price))
			end
			return rows
		end)
	)
	return list
end

return Cosmetics
