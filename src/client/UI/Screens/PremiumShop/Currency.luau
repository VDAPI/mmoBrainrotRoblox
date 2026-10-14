--!strict
-- Dragon Shop, "Currency" tab (S120): Dragon Currency packs for Robux with the bonus over the smallest pack
-- (Logic/Premium.packBonus) and one line on what the currency buys. Robux purchases go through the native prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Text = require(script.Parent.Parent.Parent.Text)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

type Scope = Fusion.Scope<typeof(Fusion)>

local Currency = {}

function Currency.build(scope: Scope, _ctx: Cards.Ctx): { any }
	local list: { any } = {}
	for i, pack in Products.shardPacks do
		local bonus = Premium.packBonus(pack)
		table.insert(
			list,
			Cards.card(scope, {
				order = i,
				glyph = "◆",
				art = UiArt.shop(pack.key),
				title = Text.T(scope, "premium.pack", { n = Format.number(pack.shards) }),
				subtitle = Text.T(scope, "premium.pack.desc"),
				badge = if bonus > 0 then Text.T(scope, "premium.pack.bonus", { n = bonus }) else nil,
				button = Cards.robuxButton(scope, pack.productId, `R$ {pack.robux}`, function()
					Cards.invoke("BuyProduct", pack.key)
				end),
			})
		)
	end
	table.insert(list, Cards.note(scope, 100, "premium.currency.note"))
	return list
end

return Currency
