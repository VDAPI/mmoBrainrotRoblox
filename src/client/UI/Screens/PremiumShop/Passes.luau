--!strict
-- Dragon Shop, "Passes" tab (S120): Gamepasses (Logic/Premium.shownPasses: a pass switched off is shown only to its
-- owners), owned ones as "Owned", the rest for Robux through the native prompt ("Soon" without an id on a live server).
-- S121: the VIP subscription card first (gold frame, "Subscribe" / "Soon" and "Details" -> the VIP window); a pass
-- that needs another one first (Character Slot 5) says which instead of the price.
-- S152b: the season pass card over the VIP card (not bought / bought ✓ with the tier / no season; "See rewards" opens
-- the season pass window, "Unlock" the same purchase dialog as the window, UI/SeasonPassBuy) and under both the one
-- sentence of how they differ (premium.passVsVip).
-- 2026-10-21 (owner: too many detailed descriptions): that sentence moved behind the "i" of the season pass card; the
-- VIP card says premium.sub.vip.short, a pass with premium.pass.<key>.short shows it with the full .desc behind its "i"
-- (the .desc texts stay: the wiki and docs/SKLEP-ID.md read them).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Cards = require(script.Parent.Cards)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local SeasonState = require(script.Parent.Parent.Parent.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
local VipWindow = require(script.Parent.Parent.VipWindow)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Passes = {}

local function ownedOf(value: any): { [string]: boolean }
	return if type(value) == "table" then value else {}
end

-- S121: the VIP subscription card.
local function vipCard(scope: Scope, ctx: Cards.Ctx): Instance
	local vip = State.Value({ "vip" })
	local buttons = scope:New("Frame")({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(320, 48),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			VipWindow.subscribeButton(scope, vip, { LayoutOrder = 1, Size = UDim2.fromOffset(180, 48) }),
			Button(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(130, 48),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.details"),
				Visible = ctx.OpenVip ~= nil,
				OnClick = function()
					if ctx.OpenVip then
						ctx.OpenVip()
					end
				end,
			}),
		},
	})
	local card = Cards.card(scope, {
		order = 3,
		glyph = "★",
		art = UiArt.shop("vip"),
		title = Text.T(scope, "premium.sub.vip"),
		subtitle = scope:Computed(function(use): string
			local branch = use(vip)
			if type(branch) == "table" and branch.active == true then
				return VipWindow.statusText(use, branch)
			end
			return Text.get(use, "premium.sub.vip.short")
		end),
		button = buttons,
		buttonWidth = 330,
		highlight = true, -- W28: the gold frame (one UIStroke per card)
	})
	return card
end

-- S152b: the season pass card (a view of SeasonState; the rules stay in Logic/Season).
local function seasonCard(scope: Scope, ctx: Cards.Ctx): Instance
	local view = SeasonState.View
	local canBuy = scope:Computed(function(use): boolean
		return SeasonView.canBuy(use(view), use(SeasonState.Now))
	end)
	local buttons = scope:New("Frame")({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(320, 48),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Button(scope, {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(150, 48),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.season.unlock", { price = Format.number(Products.seasonPass.price) }),
				Visible = scope:Computed(function(use): boolean
					return use(canBuy) and ctx.BuySeason ~= nil
				end),
				OnClick = function()
					if ctx.BuySeason then
						ctx.BuySeason()
					end
				end,
			}),
			Button(scope, {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(160, 48),
				Variant = "secondary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.season.view"),
				Visible = ctx.OpenSeason ~= nil,
				OnClick = function()
					if ctx.OpenSeason then
						ctx.OpenSeason()
					end
				end,
			}),
		},
	})
	return Cards.card(scope, {
		order = 2,
		glyph = "❖",
		art = UiArt.hud("season"),
		title = scope:Computed(function(use): string
			local def = use(view).def
			if not def then
				return Text.get(use, "premium.season.title")
			end
			return Text.get(use, "premium.season.titleOf", { season = Text.get(use, def.nameKey) })
		end),
		subtitle = scope:Computed(function(use): string
			local v = use(view)
			if v.mode == "soon" or not v.def then
				return Text.get(use, "premium.season.none")
			elseif v.state.premium then
				return Text.get(use, "premium.season.owned", { tier = v.tier, tiers = v.def.tiers })
			elseif v.mode == "grace" then
				return Text.get(use, "premium.season.ended")
			end
			return Text.get(use, "premium.season.desc")
		end),
		info = Text.T(scope, "premium.passVsVip"),
		button = buttons,
		buttonWidth = 330,
	})
end

function Passes.build(scope: Scope, ctx: Cards.Ctx): { any }
	local passes = State.Value({ "passes" })
	-- S121: VIP subscription card goes first (DESIGN-17 §2). S152b: the season pass card over it (the "and VIP?"
	-- sentence behind its "i" since 2026-10-21).
	-- (the Gamepass note "stays on the account forever" moves down to the Gamepasses: the season pass does not stay)
	local list: { any } = {
		seasonCard(scope, ctx),
		vipCard(scope, ctx),
		Cards.note(scope, 5, "premium.passes.note"),
	}
	-- Rebuilt when the owned passes change (rare): a switched-off pass shows only to its owners.
	table.insert(
		list,
		scope:Computed(function(use, s: Scope): { Instance }
			local owned = ownedOf(use(passes))
			local cards = {}
			for i, pass in Premium.shownPasses(owned) do
				local isOwned = owned[pass.key] == true
				local needs = pass.requires
				local button = if needs ~= nil
						and not isOwned
						and owned[needs] ~= true
					then Cards.buyButton(
						s,
						Text.T(s, "premium.requires", { pass = Text.T(s, `premium.pass.{needs}`) }),
						true,
						function() end
					)
					else Cards.robuxButton(s, pass.passId, `R$ {pass.robux}`, function()
						Cards.invoke("BuyPass", pass.key)
					end, isOwned)
				local desc = `premium.pass.{pass.key}.desc`
				local short = `premium.pass.{pass.key}.short`
				local hasShort = Locale.has(short)
				table.insert(
					cards,
					Cards.card(s, {
						order = 100 + i,
						glyph = pass.icon,
						art = UiArt.shop(pass.key),
						title = Text.T(s, `premium.pass.{pass.key}`),
						subtitle = Text.T(s, if hasShort then short else desc),
						info = if hasShort then Text.T(s, desc) else nil,
						button = button,
					})
				)
			end
			return cards
		end)
	)
	return list
end

return Passes
