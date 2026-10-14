--!strict
-- Dragon Shop, "Items" tab (S120): one section per Data/Products.shopCats category with entries (Logic/Premium
-- .shopSections, empty sections have no header). Every button state comes from Logic/Premium.canBuy (the server's
-- rule): affordable -> confirmation (UI/PremiumConfirm) -> PremiumBuy; no shards / limit / "Soon" -> disabled with the
-- reason in the card tooltip. Renaming keeps its own dialog with the name field and the balance after the purchase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local PremiumConfirm = require(script.Parent.Parent.Parent.PremiumConfirm)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

type Scope = Fusion.Scope<typeof(Fusion)>

local Items = {}

-- The account branches the purchase rule reads (the window replicates them separately).
type Branches = {
	shards: Fusion.Value<any>,
	limits: Fusion.Value<any>,
	old: Fusion.Value<any>,
}

local function accountOf(use: Fusion.Use, b: Branches): Premium.ShopAccount
	local limits = use(b.limits)
	local old = use(b.old)
	return {
		dragonShards = use(b.shards) or 0,
		shopLimits = if type(limits) == "table" then limits else nil,
		dailyLimits = if type(old) == "table" then old else nil,
	}
end

-- The text of a disabled button and the reason line of the tooltip for a canBuy error.
local function buttonText(use: Fusion.Use, entry: Products.ShopEntry, err: string?): string
	if err == "premium.error.dailyLimit" or err == "premium.error.weeklyLimit" then
		return Text.get(use, "premium.limitReached")
	elseif err == "premium.error.soon" then
		return Text.get(use, "premium.soon")
	end
	return `◆ {Format.number(entry.price)}`
end

local function reasonOf(use: Fusion.Use, err: string?): string?
	if err == nil or err == "premium.error.shards" then
		return nil -- the tooltip already says the balance is too low
	elseif err == "premium.error.soon" then
		return Text.get(use, "premium.soon.hint")
	end
	return Text.get(use, err)
end

local function descKey(entry: Products.ShopEntry): string
	return `premium.shop.{entry.key}.desc`
end

-- The card subtitle: limits used today / this week, otherwise what the entry gives.
local function subtitle(use: Fusion.Use, entry: Products.ShopEntry, b: Branches): string
	if not entry.dailyLimit and not entry.weeklyLimit then
		return Text.get(use, descKey(entry))
	end
	local today, week = Premium.usedOf(entry, accountOf(use, b), os.time())
	local parts = {}
	if entry.dailyLimit then
		table.insert(parts, Text.get(use, "premium.service.limit", { used = today, max = entry.dailyLimit }))
	end
	if entry.weeklyLimit then
		table.insert(parts, Text.get(use, "premium.service.limitWeek", { used = week, max = entry.weeklyLimit }))
	end
	return table.concat(parts, " · ")
end

local function itemCard(scope: Scope, entry: Products.ShopEntry, itemId: string, order: number, b: Branches): Instance
	local def = ItemData.get(itemId)
	local err = scope:Computed(function(use): string?
		local ok, e = Premium.canBuy(entry, accountOf(use, b), os.time())
		return if ok then nil else e
	end)
	local function spec(shards: number): PremiumConfirm.Spec
		return {
			name = ItemText.name(itemId),
			desc = Text.now(descKey(entry)),
			price = entry.price,
			shards = shards,
			remote = "PremiumBuy",
			arg = entry.key,
		}
	end
	return Cards.card(scope, {
		order = order,
		glyph = if def then def.icon.glyph else "📜",
		item = def,
		title = scope:Computed(function(use): string
			return ItemText.get(use, itemId)
		end),
		subtitle = scope:Computed(function(use): string
			return subtitle(use, entry, b)
		end),
		button = Cards.buyButton(
			scope,
			scope:Computed(function(use): string
				return buttonText(use, entry, use(err))
			end),
			scope:Computed(function(use): boolean
				return use(err) ~= nil
			end),
			function()
				PremiumConfirm.ask(spec(Fusion.peek(b.shards) or 0))
			end
		),
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			local text = PremiumConfirm.describe(spec(use(b.shards) or 0), "tooltip")
			local reason = reasonOf(use, use(err))
			return if reason then `{text}\n\n{reason}` else text
		end),
	})
end

local function renameCard(scope: Scope, ctx: Cards.Ctx, entry: Products.ShopEntry, order: number, b: Branches): Instance
	local err = scope:Computed(function(use): string?
		local ok, e = Premium.canBuy(entry, accountOf(use, b), os.time())
		return if ok then nil else e
	end)
	return Cards.card(scope, {
		order = order,
		glyph = "✎",
		art = UiArt.shop("rename"),
		title = Text.T(scope, "premium.rename"),
		subtitle = Text.T(scope, "premium.rename.desc"),
		button = Cards.buyButton(
			scope,
			scope:Computed(function(use): string
				return buttonText(use, entry, use(err))
			end),
			scope:Computed(function(use): boolean
				return use(err) ~= nil
			end),
			function()
				local shards = Fusion.peek(b.shards) or 0
				ctx.ShowModal({
					Title = Text.now("premium.rename"),
					Message = Text.now("premium.rename.confirm2", {
						price = Format.number(entry.price),
						after = Format.number(Premium.balanceAfter(shards, entry.price)),
					}),
					ConfirmText = Text.now("common.confirm"),
					CancelText = Text.now("common.cancel"),
					Input = { Placeholder = Text.now("premium.rename.placeholder"), MaxLength = 16 },
					OnConfirm = function(text: string): (boolean, string?)
						local ok, e = Net.Invoke("PremiumRename", text)
						if not ok then
							Sounds.play("error")
							return false, Text.now(e or "error.internal")
						end
						Sounds.play("coin")
						Toast.push(Text.now("premium.renamed", { name = text }), "success")
						return true, nil
					end,
				})
			end
		),
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			local text = PremiumConfirm.describe({
				name = Text.get(use, "premium.rename"),
				desc = Text.get(use, descKey(entry)),
				price = entry.price,
				shards = use(b.shards) or 0,
				remote = "PremiumRename",
				arg = "",
			}, "tooltip")
			local reason = reasonOf(use, use(err))
			return if reason then `{text}\n\n{reason}` else text
		end),
	})
end

-- An entry this window cannot sell yet: a card without a buy button ("Soon"), never an error.
local function soonCard(scope: Scope, entry: Products.ShopEntry, order: number): Instance
	return Cards.card(scope, {
		order = order,
		glyph = "◆",
		art = UiArt.shop(entry.key),
		title = if entry.itemId
			then scope:Computed(function(use): string
				return ItemText.get(use, entry.itemId :: string)
			end)
			else Text.T(scope, descKey(entry)),
		subtitle = Text.T(scope, "premium.soon.hint"),
		button = Cards.buyButton(scope, Text.T(scope, "premium.soon"), true, function() end),
	})
end

function Items.build(scope: Scope, ctx: Cards.Ctx): { any }
	local b: Branches = {
		shards = State.Value({ "account", "dragonShards" }),
		limits = State.Value({ "account", "shopLimits" }),
		old = State.Value({ "account", "dailyLimits" }),
	}
	local list: { any } = {}
	for s, section in Premium.shopSections() do
		local base = s * 100
		table.insert(list, Cards.sectionHeader(scope, base, `premium.cat.{section.cat}`))
		for i, entry in section.entries do
			local order = base + i
			-- S122: other kinds (lure service) render here
			if entry.kind == "item" and entry.itemId then
				table.insert(list, itemCard(scope, entry, entry.itemId, order, b))
			elseif entry.kind == "rename" then
				table.insert(list, renameCard(scope, ctx, entry, order, b))
			else
				table.insert(list, soonCard(scope, entry, order))
			end
		end
	end
	return list
end

return Items
