--!strict
-- Dragon Shop, "Passes" tab (S120): Gamepasses (Logic/Premium.shownPasses: a pass switched off is shown only to its
-- owners), owned ones as "Owned", the rest for Robux through the native prompt ("Soon" without an id on a live server).
-- S121: the VIP subscription card first (gold frame, "Subscribe" / "Soon" and "Details" -> the VIP window); a pass
-- that needs another one first (Character Slot 5) says which instead of the price.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Cards = require(script.Parent.Cards)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
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
		order = 2,
		glyph = "★",
		art = UiArt.shop("vip"),
		title = Text.T(scope, "premium.sub.vip"),
		subtitle = scope:Computed(function(use): string
			local branch = use(vip)
			if type(branch) == "table" and branch.active == true then
				return VipWindow.statusText(use, branch)
			end
			return Text.get(use, "premium.sub.vip.desc")
		end),
		button = buttons,
		buttonWidth = 330,
	})
	scope:New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Theme.Colors.GoldBright,
		Thickness = Theme.Stroke.Normal,
		Parent = card,
	})
	return card
end

function Passes.build(scope: Scope, ctx: Cards.Ctx): { any }
	local passes = State.Value({ "passes" })
	-- S121: VIP subscription card goes first (DESIGN-17 §2).
	local list: { any } = { Cards.note(scope, 1, "premium.passes.note"), vipCard(scope, ctx) }
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
				table.insert(
					cards,
					Cards.card(s, {
						order = 100 + i,
						glyph = pass.icon,
						art = UiArt.shop(pass.key),
						title = Text.T(s, `premium.pass.{pass.key}`),
						subtitle = Text.T(s, `premium.pass.{pass.key}.desc`),
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
