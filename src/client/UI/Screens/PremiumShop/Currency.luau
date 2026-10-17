--!strict
-- Dragon Shop, "Currency" tab (S120): Dragon Currency packs for Robux with the bonus over the smallest pack
-- (Logic/Premium.packBonus) and one line on what the currency buys. Robux purchases go through the native prompt.
-- S123 (DESIGN-17 §4): the starter packs above them, once per account (Logic/Premium.packVisible: a bought one is
-- gone, the section with it when both are): the shards, the cosmetics only found there, the pass granted for good
-- (with a note when the player owns it already), "R$ n" or "Soon" without a product id on a live server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cards = require(script.Parent.Cards)
local CosmeticData = require(ReplicatedStorage.Shared.Data.Cosmetics)
local CurrencyIcon = require(script.Parent.Parent.Parent.Components.CurrencyIcon)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local Currency = {}

local PACK_BUTTON = 190

-- One "content" chip of a starter pack: a coloured tile with a glyph and a name.
local function chip(scope: Scope, order: number, glyph: string, color: Color3, label: string, icon: Instance?): Instance
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }),
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			icon or scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = color,
				Text = glyph,
				TextScaled = true,
				FontFace = Theme.Fonts.BodyBold,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.4,
				[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }) },
			}),
			scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = label,
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Text,
			}),
		},
	})
end

local function packCard(
	scope: Scope,
	pack: Products.StarterPack,
	order: number,
	passes: { [string]: boolean }
): Instance
	local chips: { Instance } = {
		chip(
			scope,
			1,
			"◆",
			Theme.Colors.Accent,
			Text.now("premium.pack", { n = Format.number(pack.shards) }),
			CurrencyIcon(
				scope,
				{ Currency = "dragon", LayoutOrder = 1, Size = UDim2.fromOffset(24, 24), Surface = "iron" }
			)
		),
	}
	for i, id in pack.cosmetics do
		local def = CosmeticData.get(id)
		if def then
			table.insert(chips, chip(scope, 1 + i, def.icon, Color3.fromHex(def.color), Text.now(def.nameKey)))
		end
	end
	local ownsPass = false
	for i, key in pack.passes do
		local pass = Products.getPass(key)
		ownsPass = ownsPass or passes[key] == true
		table.insert(
			chips,
			chip(scope, 10 + i, if pass then pass.icon else "▣", Theme.Colors.GoldDim, Text.now(`premium.pass.{key}`))
		)
	end
	return scope:New("Frame")({
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.2,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Theme.Colors.GoldDim,
				Thickness = Theme.Stroke.Thin,
			}),
			scope:New("Frame")({
				Size = UDim2.new(1, -(PACK_BUTTON + 20), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 8),
						PaddingBottom = UDim.new(0, 10),
					}),
					scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundTransparency = 1,
						Text = Text.T(scope, `premium.pack.{pack.key}`),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = Text.T(scope, `premium.pack.{pack.key}.desc`),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("Frame")({
						LayoutOrder = 3,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Wraps = true,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							chips :: any,
						},
					}),
					scope:New("TextLabel")({
						LayoutOrder = 4,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Visible = ownsPass,
						Text = Text.T(scope, "premium.pack.passOwned"),
						TextWrapped = true,
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Colors.Warning,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			Cards.robuxButton(scope, pack.productId, `R$ {pack.robux}`, function()
				Cards.invoke("BuyProduct", pack.key)
			end),
		},
	})
end

function Currency.build(scope: Scope, _ctx: Cards.Ctx): { any }
	local list: { any } = {}
	-- S123: starter packs (rebuilt when one is bought or a pass changes)
	local packs = State.Value({ "account", "packs" })
	local passes = State.Value({ "passes" })
	table.insert(
		list,
		scope:Computed(function(use, s: Scope): { Instance }
			local bought = use(packs)
			local account = { packs = if type(bought) == "table" then bought else {} }
			local owned = use(passes)
			local out: { Instance } = {}
			for i, pack in Products.starterPacks do
				if Premium.packVisible(pack.key, account) then
					table.insert(out, packCard(s, pack, 2 + i, if type(owned) == "table" then owned else {}))
				end
			end
			if #out > 0 then
				table.insert(out, 1, Cards.sectionHeader(s, 1, "premium.pack.title"))
				table.insert(out, 2, Cards.note(s, 2, "premium.pack.once"))
			end
			return out
		end)
	)
	for i, pack in Products.shardPacks do
		local bonus = Premium.packBonus(pack)
		table.insert(
			list,
			Cards.card(scope, {
				order = 20 + i,
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
