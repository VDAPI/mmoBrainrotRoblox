--!strict
-- Dragon Shop, "Mounts" tab (S97 section moved here in S120): every premium mount on sale (Logic/Premium.mountOffers)
-- for Robux through the native prompt, the same speed cap as every mount. The tab exists only while one is on sale
-- (Premium.visibleTabs); today none is (Data/Products.mounts enabled = false), so the player does not see it.
-- 2026-10-21: the note is one short line, the rest (looks, starting level) behind its "i".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Text = require(script.Parent.Parent.Parent.Text)

type Scope = Fusion.Scope<typeof(Fusion)>

local Mounts = {}

function Mounts.build(scope: Scope, _ctx: Cards.Ctx): { any }
	local list: { any } = { Cards.note(scope, 1, "premium.mounts.short", "premium.mounts.desc") }
	for i, offer in Premium.mountOffers() do
		local def = MountData.get(offer.mount)
		if def then
			table.insert(
				list,
				Cards.card(scope, {
					order = 10 + i,
					glyph = "♞",
					title = scope:Computed(function(use): string
						return Text.get(use, def.nameKey)
					end),
					subtitle = scope:Computed(function(use): string
						return Text.get(use, "mount.level", { lvl = def.startLevel, max = Config.Mount.maxLevel })
					end),
					button = Cards.robuxButton(scope, offer.productId, `R$ {offer.robux}`, function()
						Cards.invoke("BuyProduct", offer.key)
					end),
				})
			)
		end
	end
	return list
end

return Mounts
