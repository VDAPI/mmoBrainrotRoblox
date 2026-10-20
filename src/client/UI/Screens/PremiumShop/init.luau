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
local RunService = game:GetService("RunService")

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
local Net = require(ReplicatedStorage.Shared.Net)
local Passes = require(script.Passes)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local SideTabs = require(script.Parent.Parent.Components.SideTabs)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	OpenWardrobe: (start: { kind: string?, try: string? }?) -> (),
	Select: ((tab: string) -> ())?,
	OpenVip: (() -> ())?, -- S121
	OpenSeason: (() -> ())?, -- S152b
	BuySeason: (() -> ())?, -- S152b
}

local HEADER = 52
local TOP_UP = 120
local STUDIO_BUTTON = 150
-- W28: the right part of the header (balance up to 170, the Studio button, "Top up"); the title gets the rest
local HEADER_RIGHT = 170 + TOP_UP + 16 + (if RunService:IsStudio() then STUDIO_BUTTON + 8 else 0)
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

-- W28 (owner's Studio tests): +1000 Dragon Shards through the admin command /shards. Only in Studio, where every
-- player is an admin (AdminService.IsAdmin); a live server never shows the button and refuses non-admins anyway.
local STUDIO_SHARDS = 1000

local function studioShards()
	task.spawn(function()
		local ok, err = Net.Invoke("AdminRun", "shards", { tostring(STUDIO_SHARDS) })
		if ok then
			Sounds.play("coin")
		else
			Sounds.play("error")
			Toast.push(Text.now(err or "error.internal"), "error")
		end
	end)
end

local function header(scope: Scope, selected: Fusion.Value<string>): Instance
	local shards = State.Value({ "account", "dragonShards" })
	local studio = RunService:IsStudio()
	return scope:New("Frame")({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundTransparency = 1,
		[Children] = {
			-- On a phone the tab strip right under the header names the tab.
			scope:New("TextLabel")({
				Name = "Title",
				Size = UDim2.new(1, -HEADER_RIGHT, 1, 0),
				BackgroundTransparency = 1,
				Visible = scope:Computed(function(use): boolean
					return not use(Device.Touch)
				end),
				Text = scope:Computed(function(use): string
					return Text.get(use, `premium.tab.{use(selected)}`)
				end),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Large,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			-- W28: balance, the Studio button and "Top up" in one right-aligned row (no fixed offsets to collide).
			scope:New("Frame")({
				Name = "Right",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0, HEADER_RIGHT, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("Frame")({
						Name = "Balance",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(0, 36),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = Theme.Paper.Surface,
						BackgroundTransparency = 0.1,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Theme.Paper.Rule,
								Thickness = Theme.Stroke.Thin,
							}),
							scope:New("UIPadding")({
								PaddingLeft = UDim.new(0, 8),
								PaddingRight = UDim.new(0, 12),
							}),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							CurrencyIcon(scope, {
								Currency = "dragon",
								LayoutOrder = 1,
								Size = UDim2.fromOffset(24, 24),
							}),
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
								TextColor3 = Theme.Paper.Link,
							}),
						},
					}),
					(if studio
						then Button(scope, {
							Name = "StudioShards",
							LayoutOrder = 2,
							Size = UDim2.fromOffset(STUDIO_BUTTON, Theme.Size.MinTouch),
							Variant = "secondary",
							TextSize = Theme.TextSize.Small,
							Text = Text.T(scope, "premium.studioShards", { n = Format.number(STUDIO_SHARDS) }),
							OnClick = studioShards,
						})
						else nil) :: any,
					-- Disabled (not hidden) on the currency tab, so the header never jumps.
					Button(scope, {
						LayoutOrder = 3,
						Size = UDim2.fromOffset(TOP_UP, Theme.Size.MinTouch),
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
		OpenVip = props.OpenVip,
		OpenSeason = props.OpenSeason,
		BuySeason = props.BuySeason,
	}
	-- Depends only on the tab: the cards read their own branches (balance, limits, passes, cosmetics).
	-- S131: the shop funnel (Logic/ShopFunnel): the window opened, then the first change of tab
	Net.Send("PremiumFunnel", "shop", "open")
	local sentTab = false
	scope:Observer(selected):onChange(function()
		if not sentTab then
			sentTab = true
			Net.Send("PremiumFunnel", "shop", "tab")
		end
	end)
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
				scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
				-- W28: room for the card strokes at the edges and for the scroll bar on the right
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 2),
					PaddingRight = UDim.new(0, 12),
				}),
				content :: any,
			},
		}),
	}
end

return PremiumShop
