--!strict
-- Dragon Shop, "Items" tab (S120): one section per Data/Products.shopCats category with entries (Logic/Premium
-- .shopSections, empty sections have no header). Every button state comes from Logic/Premium.canBuy (the server's
-- rule): affordable -> confirmation (UI/PremiumConfirm) -> PremiumBuy; no shards / limit / "Soon" -> disabled with the
-- reason in the card tooltip. Renaming keeps its own dialog with the name field and the balance after the purchase.
-- S122 (DESIGN-17 §3): item packs (`n`, Elixir of Wholeness: title premium.<item>.pack) and the Cloak of Luring: a
-- service card with the time left and the switch (LureToggle; only while there is time), then one buy card per
-- `lure` entry. The time refreshes once a second while this tab is open.
-- S134d: Auto Potions (autopotion_*: the time left or "forever", every entry "Owned" once bought forever) and Auto
-- Hunt (hunt_*: the hours in the bank and left today): a service card before the first entry of each, then the buy
-- cards (the same purchase rule, Logic/Premium.canBuy with the account's autoPotion branch).
-- 2026-10-21 (owner: too many detailed descriptions): a card shows the short line premium.shop.<key>.short (with the
-- limits used today when the entry has them) and the full premium.shop.<key>.desc behind an "i" after the title; the
-- service cards (Cloak, Auto Potions, Auto Hunt) put their rules there too (the card tooltip stays for the mouse).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Button = require(script.Parent.Parent.Parent.Components.Button)
local Cards = require(script.Parent.Cards)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemText = require(script.Parent.Parent.Parent.ItemText)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local AutoGrind = require(ReplicatedStorage.Shared.Logic.AutoGrind)
local AutoPotion = require(ReplicatedStorage.Shared.Logic.AutoPotion)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Lure = require(ReplicatedStorage.Shared.Logic.Lure)
local Net = require(ReplicatedStorage.Shared.Net)
local Premium = require(ReplicatedStorage.Shared.Logic.Premium)
local PremiumConfirm = require(script.Parent.Parent.Parent.PremiumConfirm)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Parent.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

type Scope = Fusion.Scope<typeof(Fusion)>

local Items = {}

-- S122: arguments of the card descriptions (premium.shop.potion_full_*.desc reads the elixir rules from Config).
local DESC_ARGS = { min = Config.FullElixir.cooldown // 60, n = Config.FullElixir.dailyLimit }

-- The account branches the purchase rule reads (the window replicates them separately).
type Branches = {
	shards: Fusion.Value<any>,
	limits: Fusion.Value<any>,
	old: Fusion.Value<any>,
	autoPotion: Fusion.Value<any>, -- S134d: owned forever = no more Auto Potions entries
}

local function accountOf(use: Fusion.Use, b: Branches): Premium.ShopAccount
	local limits = use(b.limits)
	local old = use(b.old)
	return {
		dragonShards = use(b.shards) or 0,
		shopLimits = if type(limits) == "table" then limits else nil,
		dailyLimits = if type(old) == "table" then old else nil,
		autoPotion = if type(use(b.autoPotion)) == "table" then use(b.autoPotion) else nil,
	}
end

-- The text of a disabled button and the reason line of the tooltip for a canBuy error.
local function buttonText(use: Fusion.Use, entry: Products.ShopEntry, err: string?): string
	if err == "premium.error.dailyLimit" or err == "premium.error.weeklyLimit" then
		return Text.get(use, "premium.limitReached")
	elseif err == "premium.error.soon" then
		return Text.get(use, "premium.soon")
	elseif err == "premium.error.owned" then
		return Text.get(use, "premium.owned") -- S134d: Auto Potions forever
	end
	return `◆ {Format.number(entry.price)}`
end

local function reasonOf(use: Fusion.Use, err: string?): string?
	if err == nil or err == "premium.error.shards" then
		return nil -- the tooltip already says the balance is too low
	elseif err == "premium.error.soon" then
		return Text.get(use, "premium.soon.hint")
	end
	return Text.get(use, err)
end

local function descKey(entry: Products.ShopEntry): string
	return `premium.shop.{entry.key}.desc`
end

-- 2026-10-21: the short line of an entry (premium.shop.<key>.short), nil when the description is short already.
local function shortKey(entry: Products.ShopEntry): string?
	local key = `premium.shop.{entry.key}.short`
	return if Locale.has(key) then key else nil
end

-- The "i" text of a card with a short line: the full description (nil without a short line).
local function infoOf(scope: Scope, entry: Products.ShopEntry): Fusion.UsedAs<string>?
	return if shortKey(entry) then Text.T(scope, descKey(entry), DESC_ARGS) else nil
end

-- S122: the card title of an item entry: a pack of n (premium.<item>.pack) or the item name.
local function itemTitle(use: Fusion.Use, entry: Products.ShopEntry, itemId: string): string
	if (entry.n or 1) > 1 then
		return Text.get(use, `premium.{itemId}.pack`, { n = entry.n })
	end
	return ItemText.get(use, itemId)
end

-- The card subtitle: what the entry gives (the short line when there is one), then the limits used today / this week.
local function subtitle(use: Fusion.Use, entry: Products.ShopEntry, b: Branches): string
	local short = shortKey(entry)
	if not entry.dailyLimit and not entry.weeklyLimit then
		return Text.get(use, short or descKey(entry), DESC_ARGS)
	end
	local today, week = Premium.usedOf(entry, accountOf(use, b), os.time())
	local parts = {}
	if short then
		table.insert(parts, Text.get(use, short))
	end
	if entry.dailyLimit then
		table.insert(parts, Text.get(use, "premium.service.limit", { used = today, max = entry.dailyLimit }))
	end
	if entry.weeklyLimit then
		table.insert(parts, Text.get(use, "premium.service.limitWeek", { used = week, max = entry.weeklyLimit }))
	end
	return table.concat(parts, " · ")
end

local function itemCard(scope: Scope, entry: Products.ShopEntry, itemId: string, order: number, b: Branches): Instance
	local def = ItemData.get(itemId)
	local err = scope:Computed(function(use): string?
		local ok, e = Premium.canBuy(entry, accountOf(use, b), os.time())
		return if ok then nil else e
	end)
	local function spec(shards: number): PremiumConfirm.Spec
		local packed = (entry.n or 1) > 1
		return {
			name = if packed then Text.now(`premium.{itemId}.pack`, { n = entry.n }) else ItemText.name(itemId),
			desc = Text.now(descKey(entry), DESC_ARGS),
			price = entry.price,
			shards = shards,
			remote = "PremiumBuy",
			arg = entry.key,
		}
	end
	return Cards.card(scope, {
		order = order,
		glyph = if def then def.icon.glyph else "📜",
		item = def,
		title = scope:Computed(function(use): string
			return itemTitle(use, entry, itemId)
		end),
		subtitle = scope:Computed(function(use): string
			return subtitle(use, entry, b)
		end),
		info = infoOf(scope, entry),
		button = Cards.buyButton(
			scope,
			scope:Computed(function(use): string
				return buttonText(use, entry, use(err))
			end),
			scope:Computed(function(use): boolean
				return use(err) ~= nil
			end),
			function()
				PremiumConfirm.ask(spec(Fusion.peek(b.shards) or 0))
			end
		),
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			local text = PremiumConfirm.describe(spec(use(b.shards) or 0), "tooltip")
			local reason = reasonOf(use, use(err))
			return if reason then `{text}\n\n{reason}` else text
		end),
	})
end

local function renameCard(scope: Scope, ctx: Cards.Ctx, entry: Products.ShopEntry, order: number, b: Branches): Instance
	local err = scope:Computed(function(use): string?
		local ok, e = Premium.canBuy(entry, accountOf(use, b), os.time())
		return if ok then nil else e
	end)
	return Cards.card(scope, {
		order = order,
		glyph = "✎",
		art = UiArt.shop("rename"),
		title = Text.T(scope, "premium.rename"),
		subtitle = Text.T(scope, "premium.rename.desc"),
		button = Cards.buyButton(
			scope,
			scope:Computed(function(use): string
				return buttonText(use, entry, use(err))
			end),
			scope:Computed(function(use): boolean
				return use(err) ~= nil
			end),
			function()
				local shards = Fusion.peek(b.shards) or 0
				ctx.ShowModal({
					Title = Text.now("premium.rename"),
					Message = Text.now("premium.rename.confirm2", {
						price = Format.number(entry.price),
						after = Format.number(Premium.balanceAfter(shards, entry.price)),
					}),
					ConfirmText = Text.now("common.confirm"),
					CancelText = Text.now("common.cancel"),
					Input = { Placeholder = Text.now("premium.rename.placeholder"), MaxLength = 16 },
					OnConfirm = function(text: string): (boolean, string?)
						local ok, e = Net.Invoke("PremiumRename", text)
						if not ok then
							Sounds.play("error")
							return false, Text.now(e or "error.internal")
						end
						Sounds.play("coin")
						Toast.push(Text.now("premium.renamed", { name = text }), "success")
						return true, nil
					end,
				})
			end
		),
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			local text = PremiumConfirm.describe({
				name = Text.get(use, "premium.rename"),
				desc = Text.get(use, descKey(entry)),
				price = entry.price,
				shards = use(b.shards) or 0,
				remote = "PremiumRename",
				arg = "",
			}, "tooltip")
			local reason = reasonOf(use, use(err))
			return if reason then `{text}\n\n{reason}` else text
		end),
	})
end

-- S122: the time text of the Cloak of Luring ("6 d 23 h", "59 min", ...).
local function lureTime(use: Fusion.Use, seconds: number): string
	local key, args = Lure.timeKey(seconds)
	return Text.get(use, key, args)
end

-- S122: the Cloak of Luring service: time left and the switch (no switch without time: never a dead button).
local function lureCard(scope: Scope, order: number, lure: Fusion.Value<any>, now: Fusion.Value<number>): Instance
	local left = scope:Computed(function(use): number
		local state = use(lure)
		return Lure.left(if type(state) == "table" then state else nil, use(now))
	end)
	local on = scope:Computed(function(use): boolean
		local state = use(lure)
		return type(state) == "table" and state.on == true
	end)
	return Cards.card(scope, {
		order = order,
		glyph = "❂",
		art = UiArt.shop("lure"),
		title = Text.T(scope, "lure.name"),
		subtitle = scope:Computed(function(use): string
			local seconds = use(left)
			if seconds <= 0 then
				return Text.get(use, "premium.lure.none")
			end
			return Text.get(use, "premium.lure.left", { time = lureTime(use, seconds) })
		end),
		button = Button(scope, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(180, 48),
			Variant = "secondary",
			TextSize = Theme.TextSize.Small,
			Visible = scope:Computed(function(use): boolean
				return use(left) > 0
			end),
			Text = scope:Computed(function(use): string
				return Text.get(use, if use(on) then "premium.lure.toggleOff" else "premium.lure.toggleOn")
			end),
			OnClick = function()
				local wanted = not Fusion.peek(on)
				task.spawn(function()
					local ok, err = Net.Invoke("LureToggle", wanted)
					if ok then
						Sounds.play("levelUp")
					else
						Sounds.play("error")
						Toast.push(Text.now(err or "error.internal"), "error")
					end
				end)
			end,
		}),
		info = Text.T(scope, "lure.desc"),
		tooltip = Text.T(scope, "lure.desc"),
	})
end

-- S134d: Auto Potions: time left or "forever", no switch here (the HUD's "A" button holds the switch and thresholds).
local function autoPotionCard(scope: Scope, order: number, b: Branches, now: Fusion.Value<number>): Instance
	return Cards.card(scope, {
		order = order,
		glyph = "⚗",
		art = UiArt.shop("autoPotion"),
		title = Text.T(scope, "autoPotion.name"),
		subtitle = scope:Computed(function(use): string
			local state = use(b.autoPotion)
			local s = if type(state) == "table" then state else nil
			if s and s.permanent then
				return Text.get(use, "autoPotion.forever")
			end
			local seconds = AutoPotion.left(s, use(now))
			if seconds <= 0 then
				return Text.get(use, "premium.autoPotion.none")
			end
			return Text.get(use, "premium.lure.left", { time = lureTime(use, seconds) })
		end),
		info = Text.T(scope, "autoPotion.desc"),
		tooltip = Text.T(scope, "autoPotion.desc"),
	})
end

-- S134d: Auto Hunt: the time in the bank and left today (the daily cap); started from the HUD on a hunting ground.
local function autoGrindCard(scope: Scope, order: number, now: Fusion.Value<number>): Instance
	local bank = State.Value({ "account", "autoGrind" })
	return Cards.card(scope, {
		order = order,
		glyph = "⚔",
		art = UiArt.shop("autoGrind"),
		title = Text.T(scope, "autoGrind.name"),
		subtitle = scope:Computed(function(use): string
			local state = use(bank)
			local s = if type(state) == "table" then state else nil
			local t = use(now)
			return Text.get(use, "premium.autoGrind.left", {
				bank = lureTime(use, AutoGrind.rollDay(s, t).bank),
				today = lureTime(use, AutoGrind.todayLeft(s, t)),
			})
		end),
		info = Text.T(scope, "autoGrind.desc", AutoGrind.descArgs()),
		tooltip = scope:Computed(function(use): string
			return Text.get(use, "autoGrind.desc", AutoGrind.descArgs())
		end),
	})
end

-- S122: one Cloak of Luring time entry (lure_1h / lure_7d): the same purchase rule and confirmation as items.
-- S134d: also every Auto Potions and Auto Hunt entry (the same card: name premium.<key>, desc premium.shop.<key>.desc).
local function lureBuyCard(scope: Scope, entry: Products.ShopEntry, order: number, b: Branches): Instance
	local err = scope:Computed(function(use): string?
		local ok, e = Premium.canBuy(entry, accountOf(use, b), os.time())
		return if ok then nil else e
	end)
	local function spec(shards: number): PremiumConfirm.Spec
		return {
			name = Text.now(`premium.{entry.key}`),
			desc = Text.now(descKey(entry)),
			price = entry.price,
			shards = shards,
			remote = "PremiumBuy",
			arg = entry.key,
		}
	end
	return Cards.card(scope, {
		order = order,
		glyph = if entry.kind == "autoPotion" then "⚗" elseif entry.kind == "autoGrind" then "⚔" else "❂",
		art = UiArt.shop(entry.key),
		title = Text.T(scope, `premium.{entry.key}`),
		subtitle = Text.T(scope, shortKey(entry) or descKey(entry)),
		info = infoOf(scope, entry),
		button = Cards.buyButton(
			scope,
			scope:Computed(function(use): string
				return buttonText(use, entry, use(err))
			end),
			scope:Computed(function(use): boolean
				return use(err) ~= nil
			end),
			function()
				PremiumConfirm.ask(spec(Fusion.peek(b.shards) or 0))
			end
		),
		tooltip = scope:Computed(function(use): string
			use(Text.Lang)
			local text = PremiumConfirm.describe(spec(use(b.shards) or 0), "tooltip")
			local reason = reasonOf(use, use(err))
			return if reason then `{text}\n\n{reason}` else text
		end),
	})
end

-- An entry this window cannot sell yet: a card without a buy button ("Soon"), never an error.
local function soonCard(scope: Scope, entry: Products.ShopEntry, order: number): Instance
	return Cards.card(scope, {
		order = order,
		glyph = "◆",
		art = UiArt.shop(entry.key),
		title = if entry.itemId
			then scope:Computed(function(use): string
				return ItemText.get(use, entry.itemId :: string)
			end)
			else Text.T(scope, descKey(entry)),
		subtitle = Text.T(scope, "premium.soon.hint"),
		button = Cards.buyButton(scope, Text.T(scope, "premium.soon"), true, function() end),
	})
end

function Items.build(scope: Scope, ctx: Cards.Ctx): { any }
	local b: Branches = {
		shards = State.Value({ "account", "dragonShards" }),
		limits = State.Value({ "account", "shopLimits" }),
		old = State.Value({ "account", "dailyLimits" }),
		autoPotion = State.Value({ "account", "autoPotion" }),
	}
	-- S122: the Cloak of Luring state and a clock ticking once a second while this tab is built (switching tabs
	-- cleans the scope and stops it)
	local lure = State.Value({ "account", "lure" })
	local now = scope:Value(Workspace:GetServerTimeNow())
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				now:set(Workspace:GetServerTimeNow())
			end
		end
	end)
	local list: { any } = {}
	for s, section in Premium.shopSections() do
		local base = s * 100
		local lureShown = false
		local autoPotionShown, autoGrindShown = false, false -- S134d
		table.insert(list, Cards.sectionHeader(scope, base, `premium.cat.{section.cat}`))
		for i, entry in section.entries do
			local order = base + i * 2
			-- S122: other kinds render here (the Cloak of Luring: the service card before its first time entry)
			if entry.kind == "lure" then
				if not lureShown then
					lureShown = true
					table.insert(list, lureCard(scope, order - 1, lure, now))
				end
				table.insert(list, lureBuyCard(scope, entry, order, b))
			elseif entry.kind == "autoPotion" then
				if not autoPotionShown then
					autoPotionShown = true
					table.insert(list, autoPotionCard(scope, order - 1, b, now))
				end
				table.insert(list, lureBuyCard(scope, entry, order, b))
			elseif entry.kind == "autoGrind" then
				if not autoGrindShown then
					autoGrindShown = true
					table.insert(list, autoGrindCard(scope, order - 1, now))
				end
				table.insert(list, lureBuyCard(scope, entry, order, b))
			elseif entry.kind == "item" and entry.itemId then
				table.insert(list, itemCard(scope, entry, entry.itemId, order, b))
			elseif entry.kind == "rename" then
				table.insert(list, renameCard(scope, ctx, entry, order, b))
			else
				table.insert(list, soonCard(scope, entry, order))
			end
		end
	end
	return list
end

return Items
