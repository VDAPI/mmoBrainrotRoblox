--!strict
-- S152b: the one purchase dialog of the season pass's premium track (the season pass window and the shop's card use
-- this, never a copy). The shop's confirmation (UI/PremiumConfirm): the name, what it gives, the price, the balance
-- and the balance after the purchase; without enough Dragon Shards the dialog offers "Top up" instead. Confirming
-- sends SeasonBuy (the server checks, pays and toasts season.toast.bought). The client funnel step "prompt" of the
-- `season` funnel (Logic/ShopFunnel) goes with the dialog.
--   SeasonPassBuy.ask(topUp)  topUp: opens the Dragon Shop on its currency tab

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local PremiumConfirm = require(script.Parent.PremiumConfirm)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local SeasonState = require(script.Parent.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local Sounds = require(script.Parent.Sounds)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)
local Toast = require(script.Parent.Components.Toast)

local SeasonPassBuy = {}

function SeasonPassBuy.ask(topUp: () -> ())
	local view = SeasonState.get()
	local def = view.def
	if not def or not SeasonView.canBuy(view, SeasonState.now()) then
		Toast.push(Text.now(if view.state.premium then "season.error.owned" else "season.error.noSeason"), "info")
		return
	end
	Net.Send("PremiumFunnel", "season", "prompt")
	local price = Products.seasonPass.price
	local raw = State.Get({ "account", "dragonShards" })
	local shards = if type(raw) == "number" then raw else 0
	local spec: PremiumConfirm.Spec = {
		name = Text.now("season.premium.name", { season = Text.now(def.nameKey) }),
		desc = Text.now("season.premium.gives"),
		price = price,
		shards = shards,
		remote = "SeasonBuy",
		arg = "",
	}
	if shards < price then
		PremiumConfirm.modal({
			Title = Text.now("premium.confirm.title"),
			-- the tooltip form: the price and premium.error.shards instead of a negative balance after the purchase
			Message = PremiumConfirm.describe(spec, "tooltip"),
			ConfirmText = Text.now("premium.topUp"),
			CancelText = Text.now("common.cancel"),
			OnConfirm = function(_text: string): (boolean, string?)
				topUp()
				return true, nil
			end,
		})
		return
	end
	PremiumConfirm.modal({
		Title = Text.now("premium.confirm.title"),
		Message = PremiumConfirm.describe(spec, "confirm"),
		ConfirmText = Text.now("premium.confirm.buy", { price = Format.number(price) }),
		CancelText = Text.now("common.cancel"),
		OnConfirm = function(_text: string): (boolean, string?)
			local ok, err = Net.Invoke("SeasonBuy")
			if not ok then
				Sounds.play("error")
				return false, Text.now(err or "error.internal")
			end
			Sounds.play("coin")
			return true, nil
		end,
	})
end

return SeasonPassBuy
