--!strict
-- Purchase confirmation for Dragon Currency (S120, DESIGN-17 §1): every purchase for shards (premium shop items and
-- cosmetics, wardrobe) asks first with the name, what it gives, the price and the balance after the purchase. The
-- card tooltips use the same text (`describe`). Robux purchases go through the native Roblox prompt instead.
--   PremiumConfirm.setShowModal(fn)  WindowManager.ShowModal (PremiumController.Init)
--   PremiumConfirm.describe(spec, mode?)  "confirm" (default): price, balance, after; "tooltip": price, after
--   PremiumConfirm.ask(spec)  the dialog; confirming sends `spec.remote(spec.arg)` and keeps an error in the dialog

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local Sounds = require(script.Parent.Sounds)
local Text = require(script.Parent.Text)
local Toast = require(script.Parent.Components.Toast)

local log = Log.new("PremiumConfirm")

local PremiumConfirm = {}

-- Texts are already translated by the caller (Text.now).
export type Spec = {
	name: string,
	desc: string?,
	price: number,
	shards: number, -- the balance now
	remote: string, -- PremiumBuy / PremiumBuyCosmetic
	arg: string,
	onDone: (() -> ())?,
}

local showModal: ((spec: any) -> ())? = nil

function PremiumConfirm.setShowModal(fn: (spec: any) -> ())
	showModal = fn
end

-- The text of the dialog ("confirm") or of a card tooltip ("tooltip"; a negative balance shows the error instead).
function PremiumConfirm.describe(spec: Spec, mode: ("confirm" | "tooltip")?): string
	local lines = { spec.name, "" }
	if spec.desc and spec.desc ~= "" then
		table.insert(lines, spec.desc)
	end
	local after = Premium.balanceAfter(spec.shards, spec.price)
	if mode == "tooltip" then
		table.insert(lines, Text.now("premium.tooltip.price", { price = Format.number(spec.price) }))
		table.insert(
			lines,
			if after < 0
				then Text.now("premium.error.shards")
				else Text.now("premium.tooltip.after", { after = Format.number(after) })
		)
	else
		table.insert(lines, Text.now("premium.confirm.price", { price = Format.number(spec.price) }))
		table.insert(lines, Text.now("premium.confirm.balance", { shards = Format.number(spec.shards) }))
		table.insert(lines, Text.now("premium.confirm.after", { after = Format.number(after) }))
	end
	return table.concat(lines, "\n")
end

-- Sends the purchase; returns (ok, localized error).
local function send(spec: Spec): (boolean, string?)
	local ok, err = Net.Invoke(spec.remote, spec.arg)
	if not ok then
		Sounds.play("error")
		return false, Text.now(err or "error.internal")
	end
	Sounds.play("coin")
	Toast.push(Text.now("premium.bought", { name = spec.name }), "success")
	if spec.onDone then
		spec.onDone()
	end
	return true, nil
end

function PremiumConfirm.ask(spec: Spec)
	local show = showModal
	if not show then
		-- Never a dead button: without the dialog the purchase goes straight to the server.
		log:warn("no modal for the purchase confirmation, buying %s directly", spec.arg)
		task.spawn(function()
			local ok, err = send(spec)
			if not ok then
				Toast.push(err or Text.now("error.internal"), "error")
			end
		end)
		return
	end
	show({
		Title = Text.now("premium.confirm.title"),
		Message = PremiumConfirm.describe(spec, "confirm"),
		ConfirmText = Text.now("premium.confirm.buy", { price = Format.number(spec.price) }),
		CancelText = Text.now("common.cancel"),
		OnConfirm = function(_text: string): (boolean, string?)
			return send(spec)
		end,
	})
end

return PremiumConfirm
