--!strict
-- Auction house window at the Auctioneer (DESIGN §18, §23): Browse / Sell / My listings.
-- Adoption stage (UI package D after C, 2026-11-10; owner 2026-11-10: "too much text, things covering each other,
-- nothing folds"): each tab's main actions stand in the window's Footer, pinned under the content outside its scroll
-- ("Szukaj" and the pager, "Wystaw przedmiot", "Odśwież"), so on a phone they never sit under a form taller than the
-- window. A tab gives its view and its footer row (View); the content starts under the tab strip
-- (Logic/GearLayout.tabsTop: Components/Tabs' height, not a number of its own).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Browse = require(script.Browse)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local Mine = require(script.Mine)
local Sell = require(script.Sell)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Window = require(script.Parent.Parent.Components.Window)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	Tab: Fusion.Value<string>,
}

-- A tab's view and the row it puts in the window's footer.
export type View = { View: Instance, Footer: Fusion.Child }

local function AuctionWindow(scope: Scope, props: Props): Window.Parts
	local view = scope:Computed(function(use, s: Scope): View
		local tab = use(props.Tab)
		if tab == "sell" then
			return Sell(s)
		elseif tab == "mine" then
			return Mine(s, props.ShowModal)
		end
		return Browse(s, props.ShowModal)
	end)
	local top = GearLayout.tabsTop()
	return {
		Content = {
			Tabs(scope, {
				Selected = props.Tab,
				Tabs = {
					{ id = "browse", label = Text.T(scope, "auction.tab.browse") },
					{ id = "sell", label = Text.T(scope, "auction.tab.sell") },
					{ id = "mine", label = Text.T(scope, "auction.tab.mine") },
				},
			}),
			scope:New("Frame")({
				Name = "Content",
				Position = UDim2.fromOffset(0, top),
				Size = UDim2.new(1, 0, 1, -top),
				BackgroundTransparency = 1,
				[Children] = scope:Computed(function(use): Instance
					return use(view).View
				end),
			}),
		},
		Footer = scope:Computed(function(use): Fusion.Child
			return use(view).Footer
		end),
	}
end

return AuctionWindow
