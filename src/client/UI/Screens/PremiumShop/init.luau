--!strict
-- Dragon Shop (DESIGN §21, DESIGN-17 §1, S120): a header with the tab title, the Dragon Currency balance and "Top up",
-- five tabs (Logic/Premium.visibleTabs: Currency, Passes, Items, Cosmetics, Mounts only while a mount is on sale) as a
-- column on the left on PC and a scrolling strip under the header on a phone, and the content of the selected tab.
-- Each tab is its own module (Currency, Passes, Items, Cosmetics, Mounts: `build(scope, ctx)`); later sessions add to
-- their tab, not here. Nothing here sells power: no EXP, stats or items with bonuses (tests/paywall.spec.luau).
--   PremiumShop.build(scope, props)  the window (PremiumController)
--   PremiumShop.Selected            the selected tab, kept for the client session
--   PremiumShop.select(tab)         selects a visible tab (PremiumController.OpenShop)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Cards = require(script.Cards)
local Cosmetics = require(script.Cosmetics)
local Currency = require(script.Currency)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Device = require(script.Parent.Parent.Device)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Items = require(script.Items)
local Mounts = require(script.Mounts)
local Passes = require(script.Passes)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local SideTabs = require(script.Parent.Parent.Components.SideTabs)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	OpenWardrobe: (start: { kind: string?, try: string? }?) -> (),
	Select: ((tab: string) -> ())?,
}

local HEADER = 52
local SIDE = 190
local STRIP = Theme.Size.ButtonHeightSmall + 8

local BUILDERS: { [string]: (scope: Scope, ctx: Cards.Ctx) -> { any } } = {
	currency = Currency.build,
	passes = Passes.build,
	items = Items.build,
	cosmetics = Cosmetics.build,
	mounts = Mounts.build,
}

local moduleScope = Fusion.scoped(Fusion)

local PremiumShop = {}

PremiumShop.Selected = moduleScope:Value("currency") :: Fusion.Value<string>

local function visible(): { string }
	return Premium.visibleTabs(#Premium.mountOffers())
end

function PremiumShop.select(tab: string)
	if table.find(visible(), tab) then
		PremiumShop.Selected:set(tab)
	end
end

local function header(scope: Scope, selected: Fusion.Value<string>): Instance
	local shards = State.Value({ "account", "dragonShards" })
	return scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundTransparency = 1,
		[Children] = {
			-- On a phone the tab strip right under the header names the tab.
			scope:New("TextLabel")({
				Size = UDim2.new(1, -380, 1, 0),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(Device.Touch)
				end),
				Text = scope:Computed(function(use): string
					return Text.get(use, `premium.tab.{use(selected)}`)
				end),
				FontFace = Theme.Fonts.Heading,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Colors.Gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -132, 0.5, 0),
				Size = UDim2.fromOffset(240, 32),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					CurrencyIcon(scope, { Currency = "dragon", LayoutOrder = 1, Size = UDim2.fromOffset(24, 24) }),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.fromOffset(0, 32),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Text = scope:Computed(function(use): string
							return Format.number(use(shards) or 0)
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Large,
						TextColor3 = Theme.Colors.Accent,
					}),
				},
			}),
			-- Disabled (not hidden) on the currency tab, so the header never jumps.
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(120, Theme.Size.MinTouch),
				Variant = "primary",
				TextSize = Theme.TextSize.Small,
				Text = Text.T(scope, "premium.topUp"),
				Disabled = scope:Computed(function(use): boolean
					return use(selected) == "currency"
				end),
				OnClick = function()
					PremiumShop.select("currency")
				end,
			}),
		},
	})
end

function PremiumShop.build(scope: Scope, props: Props): Fusion.Child
	local selected = PremiumShop.Selected
	local tabIds = visible()
	-- A remembered tab that is gone (no mount on sale any more) falls back to the currency tab.
	if not table.find(tabIds, Fusion.peek(selected)) then
		selected:set("currency")
	end
	local tabs = {}
	for _, id in tabIds do
		table.insert(tabs, { id = id, label = Text.T(scope, `premium.tab.{id}`) })
	end
	local ctx: Cards.Ctx = {
		ShowModal = props.ShowModal,
		OpenWardrobe = props.OpenWardrobe,
		Select = props.Select or PremiumShop.select,
	}
	-- Depends only on the tab: the cards read their own branches (balance, limits, passes, cosmetics).
	local content = scope:Computed(function(use, s: Scope): { any }
		local id = use(selected)
		local builder = BUILDERS[id] or BUILDERS.currency
		return builder(s, ctx)
	end)
	local touch = Device.Touch
	return {
		header(scope, selected),
		-- PC: the tab column on the left.
		scope:New("Frame")({
			Name = "SideTabsHolder",
			Position = UDim2.fromOffset(0, HEADER + 8),
			Size = UDim2.new(0, SIDE, 1, -(HEADER + 8)),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return not use(touch)
			end),
			[Children] = {
				SideTabs(scope, { Tabs = tabs, Selected = selected, Size = UDim2.fromScale(1, 1) }),
			},
		}),
		-- Phone: a horizontal strip that scrolls instead of cutting tabs off.
		scope:New("Frame")({
			Name = "TabStripHolder",
			Position = UDim2.fromOffset(0, HEADER + 4),
			Size = UDim2.new(1, 0, 0, STRIP),
			BackgroundTransparency = 1,
			Visible = touch,
			[Children] = {
				Tabs(scope, { Tabs = tabs, Selected = selected, Scroll = true, Size = UDim2.fromScale(1, 1) }),
			},
		}),
		scope:New("ScrollingFrame")({
			Name = "Content",
			Position = scope:Computed(function(use): UDim2
				return if use(touch)
					then UDim2.fromOffset(0, HEADER + STRIP + 12)
					else UDim2.fromOffset(SIDE + 12, HEADER + 8)
			end),
			Size = scope:Computed(function(use): UDim2
				return if use(touch)
					then UDim2.new(1, 0, 1, -(HEADER + STRIP + 12))
					else UDim2.new(1, -(SIDE + 12), 1, -(HEADER + 8))
			end),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			[Children] = {
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
				content :: any,
			},
		}),
	}
end

return PremiumShop
