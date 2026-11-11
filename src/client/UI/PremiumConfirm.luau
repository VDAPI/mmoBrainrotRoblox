--!strict
-- Purchase confirmation for Dragon Currency (S120, DESIGN-17 §1): every purchase for shards (premium shop items and
-- cosmetics, wardrobe) asks first with the name, what it gives, the price and the balance after the purchase. The
-- card tooltips use the same text (`describe`). Robux purchases go through the native Roblox prompt instead.
-- Owner 2026-11-10 ("bardzo dużo napisów, zbyt szczegółowe opisy"; UI plan, one home per thing): the dialog's body is
-- the question (at most 60 characters) and one price line, at most 90 in all; what the purchase gives (`desc`, up to
-- 220 characters for Auto Hunt) goes under "Więcej ▸" (the Modal's Details). A card's hover is only the price and the
-- balance after the purchase: the card shows the name and its (i) holds the description, so nothing is said twice.
-- Adoption stage (UI package D after C, 2026-11-10): the dialog's buttons stand in the Modal's pinned footer, and the
-- price lives on its confirm button ("Kup za ◆ 500"), so the body no longer repeats it: the question and the balance
-- after. The top-up dialog (its button says "Doładuj") keeps the price in the body.
--   PremiumConfirm.setShowModal(fn)  WindowManager.ShowModal (PremiumController.Init)
--   PremiumConfirm.describe(spec, mode?)  "confirm" (default): the question and the balance after; "topUp": the
--     question, the price and the balance; "tooltip": the price and the balance after (premium.error.shards instead
--     of a negative balance)
--   PremiumConfirm.ask(spec)  the dialog; confirming sends `spec.remote(spec.arg, spec.arg2)` and keeps an error in the
--     dialog (S123: arg2 = the price shown, PremiumBuyCosmetic refuses another one with premium.error.priceChanged)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local ShopPayload = require(ReplicatedStorage.Shared.Logic.ShopPayload)
local Sounds = require(script.Parent.Sounds)
local Text = require(script.Parent.Text)
local Toast = require(script.Parent.Components.Toast)
local WeeklyClock = require(script.Parent.WeeklyClock)

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
	arg2: any?, -- S123: a second remote argument (the cosmetic's price of the week)
	onDone: (() -> ())?,
}

local showModal: ((spec: any) -> ())? = nil

function PremiumConfirm.setShowModal(fn: (spec: any) -> ())
	showModal = fn
end

-- The body of the dialog ("confirm") or a card's hover ("tooltip"). Neither repeats the description: the dialog puts it
-- under "Więcej ▸" (PremiumConfirm.details), the card behind its (i).
function PremiumConfirm.describe(spec: Spec, mode: ("confirm" | "topUp" | "tooltip")?): string
	local after = Premium.balanceAfter(spec.shards, spec.price)
	local args = { price = Format.number(spec.price), after = Format.number(after) }
	if mode == "tooltip" then
		local balance = if after < 0 then Text.now("premium.error.shards") else Text.now("premium.tooltip.after", args)
		return `{Text.now("premium.tooltip.price", args)}\n{balance}`
	end
	local balance = if after < 0 then Text.now("premium.error.shards") else Text.now("premium.confirm.after", args)
	local question = Text.now("premium.confirm.question", { name = spec.name })
	if mode == "topUp" then
		return `{question}\n{Text.now("premium.confirm.price", args)} · {balance}`
	end
	return `{question}\n{balance}` -- the confirm button carries the price
end

-- What the purchase gives, for the dialog's "Więcej ▸" (nil without a description).
function PremiumConfirm.details(spec: Spec): string?
	return if spec.desc and spec.desc ~= "" then spec.desc else nil
end

-- Sends the purchase; returns (ok, localized error).
local function send(spec: Spec): (boolean, string?)
	-- W28: through ShopPayload (no trailing nil: PremiumBuy(key, nil) was refused as "error.badRequest")
	local call = ShopPayload.confirm(spec.remote, spec.arg, spec.arg2)
	local ok, err = Net.Invoke(call.remote, table.unpack(call.args, 1, call.n))
	if not ok then
		Sounds.play("error")
		if err == "premium.error.priceChanged" then
			WeeklyClock.refresh() -- S123: the windows show the new week's offer
		end
		return false, Text.now(err or "error.internal")
	end
	Sounds.play("coin")
	Toast.push(Text.now("premium.bought", { name = spec.name }), "success")
	if spec.onDone then
		spec.onDone()
	end
	return true, nil
end

-- S121: any other confirmation through the same dialog (the wardrobe's "overwrite look"); without the dialog the
-- action runs at once (never a dead button).
function PremiumConfirm.modal(spec: any)
	local show = showModal
	if show then
		show(spec)
	elseif spec.OnConfirm then
		task.spawn(spec.OnConfirm, "")
	end
end

function PremiumConfirm.ask(spec: Spec)
	Net.Send("PremiumFunnel", "shop", "item") -- S131: the shop funnel (a purchase for Dragon Shards was opened)
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
		Details = PremiumConfirm.details(spec),
		ConfirmText = Text.now("premium.confirm.buy", { price = Format.number(spec.price) }),
		CancelText = Text.now("common.cancel"),
		OnConfirm = function(_text: string): (boolean, string?)
			return send(spec)
		end,
	})
end

return PremiumConfirm
