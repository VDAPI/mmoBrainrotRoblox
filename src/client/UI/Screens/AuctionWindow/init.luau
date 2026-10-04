--!strict
-- Auction house window at the Auctioneer (DESIGN §18, §23): Browse / Sell / My listings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Browse = require(script.Browse)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Mine = require(script.Mine)
local Sell = require(script.Sell)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	ShowModal: (spec: any) -> (),
	Tab: Fusion.Value<string>,
}

local function AuctionWindow(scope: Scope, props: Props): Fusion.Child
	local content = scope:Computed(function(use, s: Scope): Instance
		local tab = use(props.Tab)
		if tab == "sell" then
			return Sell(s)
		elseif tab == "mine" then
			return Mine(s, props.ShowModal)
		end
		return Browse(s, props.ShowModal)
	end)
	return {
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
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			BackgroundTransparency = 1,
			[Children] = content :: any,
		}),
	}
end

return AuctionWindow
