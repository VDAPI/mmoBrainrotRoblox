--!strict
-- Dragon Shop, "Passes" tab (S120): Gamepasses (Logic/Premium.shownPasses: a pass switched off is shown only to its
-- owners), owned ones as "Owned", the rest for Robux through the native prompt ("Soon" without an id on a live server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

type Scope = Fusion.Scope<typeof(Fusion)>

local Passes = {}

local function ownedOf(value: any): { [string]: boolean }
	return if type(value) == "table" then value else {}
end

function Passes.build(scope: Scope, _ctx: Cards.Ctx): { any }
	local passes = State.Value({ "passes" })
	-- S121: VIP subscription card goes first (DESIGN-17 §2).
	local list: { any } = { Cards.note(scope, 1, "premium.passes.note") }
	-- Rebuilt when the owned passes change (rare): a switched-off pass shows only to its owners.
	table.insert(
		list,
		scope:Computed(function(use, s: Scope): { Instance }
			local owned = ownedOf(use(passes))
			local cards = {}
			for i, pass in Premium.shownPasses(owned) do
				local isOwned = owned[pass.key] == true
				table.insert(
					cards,
					Cards.card(s, {
						order = 100 + i,
						glyph = pass.icon,
						art = UiArt.shop(pass.key),
						title = Text.T(s, `premium.pass.{pass.key}`),
						subtitle = Text.T(s, `premium.pass.{pass.key}.desc`),
						button = Cards.robuxButton(s, pass.passId, `R$ {pass.robux}`, function()
							Cards.invoke("BuyPass", pass.key)
						end, isOwned),
					})
				)
			end
			return cards
		end)
	)
	return list
end

return Passes
