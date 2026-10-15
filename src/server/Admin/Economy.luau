--!strict
-- Admin commands: economy (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared

local Blessings = require(Shared.Data.Blessings)
local Clock = require(Shared.Util.Clock)
local Cosmetics = require(Shared.Data.Cosmetics)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local LoginReward = require(Shared.Logic.LoginReward)
local Lure = require(Shared.Logic.Lure)
local Premium = require(Shared.Logic.Premium)
local Products = require(Shared.Data.Products)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local Time = require(Shared.Logic.Time)
local Vip = require(Shared.Logic.Vip)
local WeeklyOffer = require(Shared.Logic.WeeklyOffer)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount

local PlayerStateService = Context.services.PlayerStateService
local MonetizationService = Context.services.MonetizationService
local InventoryService = Context.services.InventoryService
local BlessingService = Context.services.BlessingService
local TradeService = Context.services.TradeService
local MailService = Context.services.MailService
local AuctionService = Context.services.AuctionService
local CosmeticService = Context.services.CosmeticService
local LoginRewardService = Context.services.LoginRewardService
local VipService = Context.services.VipService
local LureService = Context.services.LureService
local PremiumShopService = Context.services.PremiumShopService -- S123: /pack
local ArenaService = Context.services.ArenaService -- S131: /weekreset tokens

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.gold = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil then
		reply(player, "admin.usage.gold")
		return
	end
	if PlayerStateService.GetCharacter(player) == nil then
		reply(player, "admin.needCharacter")
		return
	end
	local total = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return math.max(0, gold + amount)
	end)
	reply(player, "admin.gold.ok", { amount = amount, total = total })
end

commands.shards = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil then
		reply(player, "admin.usage.shards")
		return
	end
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return math.max(0, shards + amount)
	end)
	reply(player, "admin.shards.ok", { amount = amount, total = total })
end

commands.pass = function(player, args)
	local passId = args[1]
	if passId == nil or (args[2] ~= "on" and args[2] ~= "off") then
		reply(player, "admin.usage.pass")
		return
	end
	MonetizationService.SetTestPass(player, passId, args[2] == "on")
	reply(player, "admin.pass.ok", { pass = passId, state = args[2] })
end

commands.bless = function(player, args)
	local id = args[1]
	if not id then
		local ids = {}
		for _, blessing in Blessings.list do
			table.insert(ids, blessing.id)
		end
		reply(player, "admin.bless.list", { list = table.concat(ids, ", ") })
		return
	end
	withCharacter(player, function()
		if BlessingService.Grant(player, id) then
			reply(player, "admin.bless.ok", { id = id })
		else
			reply(player, "admin.usage.bless")
		end
	end)
end

commands.blessing = function(player, args)
	local tier = tonumber(args[2])
	local blessing = if args[1] and tier then Blessings.of(args[1], tier) else nil
	local seconds = tonumber(args[3])
	if not blessing or (seconds ~= nil and (seconds < 1 or seconds > Blessings.DURATION)) then
		reply(player, "admin.usage.blessing")
		return
	end
	withCharacter(player, function()
		if BlessingService.Grant(player, blessing.id, if seconds then math.floor(seconds) else nil) then
			reply(
				player,
				"admin.blessing.ok",
				{ id = blessing.id, seconds = math.floor(seconds or Blessings.DURATION) }
			)
		else
			reply(player, "admin.usage.blessing")
		end
	end)
end

-- The sources of a pass in a short admin text ("roblox+granted", "-").
local function sourceText(passKey: string, player: Player): string
	local source = MonetizationService.PassSource(player, passKey)
	local parts: { string } = {}
	if source.roblox then
		table.insert(parts, "roblox")
	end
	if source.granted then
		table.insert(parts, "granted")
	end
	if source.cache and not source.roblox and not source.granted then
		table.insert(parts, "test")
	end
	return if #parts > 0 then table.concat(parts, "+") else "-"
end

-- S131: passes saved in the caller's account (account.grantedPasses, MonetizationService.GrantProfilePass, the starter
-- pack path): grant / take for good, list with sources. A pass bought on Roblox cannot be taken (only its grant goes).
-- /pass on|off stays the session-only test.
commands.premium = function(player, args)
	local action = args[1]
	if action == "list" then
		local rows: { string } = {}
		for _, pass in Products.passes do
			table.insert(rows, `{pass.key}: {sourceText(pass.key, player)}`)
		end
		reply(player, "admin.premium.list", { list = table.concat(rows, ", ") })
		return
	end
	local key = args[2]
	if (action ~= "grant" and action ~= "take") or not key then
		reply(player, "admin.usage.premium")
		return
	end
	local pass = Products.getPass(key)
	if not pass then
		reply(player, "admin.premium.unknown", { key = key })
		return
	end
	if PlayerStateService.Get(player, { "account" }) == nil then
		reply(player, "admin.usage.premium")
		return
	end
	if action == "grant" then
		MonetizationService.GrantProfilePass(player, pass.key)
		reply(player, "admin.premium.granted", { pass = pass.key })
	elseif MonetizationService.PassSource(player, pass.key).roblox then
		PlayerStateService.Set(player, { "account", "grantedPasses", pass.key }, nil)
		reply(player, "admin.premium.ownedOnRoblox", { pass = pass.key })
	else
		MonetizationService.RevokeProfilePass(player, pass.key)
		reply(player, "admin.premium.taken", { pass = pass.key })
	end
end

-- S121: VIP test. on/off = a session-only subscription (also on live servers for admins; never saved).
commands.vip = function(player, args)
	local action = args[1]
	if action == "on" or action == "off" then
		-- VipChanged runs VipService.Refresh (daily shards, cosmetic of the month) when it turns on
		MonetizationService.SetTestSubscription(player, "vip", action == "on")
		reply(player, if action == "on" then "admin.vip.on" else "admin.vip.off")
	elseif action == "grant" or action == "take" then
		-- S131: the VIP for good = the "vip" pass saved in the account (HasVip = subscription or pass)
		if PlayerStateService.Get(player, { "account" }) == nil then
			reply(player, "admin.usage.vip")
			return
		end
		if action == "grant" then
			MonetizationService.GrantProfilePass(player, "vip")
			reply(player, "admin.vip.granted")
		elseif MonetizationService.PassSource(player, "vip").roblox then
			PlayerStateService.Set(player, { "account", "grantedPasses", "vip" }, nil)
			reply(player, "admin.premium.ownedOnRoblox", { pass = "vip" })
		else
			MonetizationService.RevokeProfilePass(player, "vip")
			reply(player, "admin.vip.taken")
		end
	elseif action == "status" then
		local status = VipService.Status(player)
		if not status then
			reply(player, "admin.usage.vip")
			return
		end
		reply(player, "admin.vip.status", {
			active = tostring(status.active),
			sub = tostring(status.sub),
			pass = `{tostring(status.pass)} ({sourceText("vip", player)})`,
			shards = if status.shardsToday then "@admin.vip.shardsDone" else "@admin.vip.shardsWait",
			respawns = status.respawns,
			recall = Time.format(status.recall),
			months = if #status.months > 0 then table.concat(status.months, ", ") else "-",
		})
	elseif action == "reset" then
		VipService.Reset(player)
		reply(player, "admin.vip.reset")
	elseif action == "month" then
		local month = args[2]
		if type(month) ~= "string" or Time.monthLabel(month) == nil then
			reply(player, "admin.usage.vip")
			return
		end
		local cosmetic = Vip.monthCosmetic(month)
		if cosmetic == nil then
			reply(player, "admin.vip.noMonth", { month = month })
			return
		end
		local id = VipService.GrantMonth(player, month)
		if id then
			reply(player, "admin.vip.month", { id = id })
		else
			-- the month was already marked or the account owns its cosmetic
			reply(player, "admin.vip.monthOwned", { id = cosmetic, month = month })
		end
	else
		reply(player, "admin.usage.vip")
	end
end

-- S122: Cloak of Luring of the caller's account: time without shards, clear, the switch, a pull now.
commands.lure = function(player, args)
	local action = args[1]
	local acc = PlayerStateService.Get(player, { "account" })
	if type(acc) ~= "table" then
		reply(player, "admin.usage.lure")
		return
	end
	local now = os.time()
	if action == "add" then
		local minutes = math.clamp(math.floor(tonumber(args[2]) or 60), 1, 20160)
		local fresh = Lure.extend(acc.lure, minutes * 60, now)
		PlayerStateService.Set(player, { "account", "lure" }, fresh)
		reply(player, "admin.lure.added", { minutes = minutes, left = Lure.left(fresh, now) })
	elseif action == "clear" then
		PlayerStateService.Set(player, { "account", "lure" }, { untilTs = 0, on = false })
		reply(player, "admin.lure.cleared")
	elseif action == "on" or action == "off" then
		local ok, err = LureService.Toggle(player, action == "on")
		if not ok then
			reply(player, err or "error.internal")
			return
		end
		reply(player, "admin.lure.state", { state = action })
	elseif action == "pulse" then
		local n, blocked = LureService.Step(player, true)
		reply(player, "admin.lure.pulse", { n = n, reason = if blocked then `@{blocked}` else "-" })
	else
		reply(player, "admin.usage.lure")
	end
end

-- S131: the caller's weekly counters back to zero (tests of the week): the weekly shop limits (the daily ones stay),
-- the Arena Tokens of the week (/arena week) or the weekly EXP of the character (its ranking entry keeps the highest
-- score sent; /rankweek reset clears the in-memory boards).
commands.weekreset = function(player, args)
	local what = args[1]
	if what == "limits" then
		local acc = PlayerStateService.Get(player, { "account" })
		if type(acc) ~= "table" then
			reply(player, "admin.usage.weekreset")
			return
		end
		local limits = Premium.limitsOf(acc, os.time())
		limits.weekly = {}
		PlayerStateService.Set(player, { "account", "shopLimits" }, limits)
	elseif what == "tokens" then
		if not (ArenaService and ArenaService.AdminWeek(player)) then
			reply(player, "admin.needCharacter")
			return
		end
	elseif what == "expweek" then
		local char = PlayerStateService.GetCharacter(player)
		if not char then
			reply(player, "admin.needCharacter")
			return
		end
		local old = char.expWeek
		PlayerStateService.Set(
			player,
			{ "character", "expWeek" },
			{ week = Time.weekNumber(Clock.now()), exp = 0, b = if old then old.b else 0 }
		)
	else
		reply(player, "admin.usage.weekreset")
		return
	end
	reply(player, "admin.weekreset.done", { what = what })
end

-- S120: premium shop limit counters of the caller's account.
commands.shoplimits = function(player, args)
	local acc = PlayerStateService.Get(player, { "account" })
	if args[1] == "reset" then
		PlayerStateService.Set(player, { "account", "shopLimits" }, Premium.emptyLimits())
		-- the pre-S120 counter too, so Premium.limitsOf does not bring it back today
		PlayerStateService.Set(player, { "account", "dailyLimits" }, { day = 0, protectScrolls = 0 })
		reply(player, "admin.shoplimits.reset")
		return
	end
	if args[1] ~= "show" or type(acc) ~= "table" then
		reply(player, "admin.usage.shoplimits")
		return
	end
	local now = os.time()
	local any = false
	for _, entry in Products.shop do
		if entry.dailyLimit or entry.weeklyLimit then
			any = true
			local day, week = Premium.usedOf(entry, acc, now)
			reply(player, "admin.shoplimits.row", {
				key = entry.key,
				day = day,
				dayMax = if entry.dailyLimit then tostring(entry.dailyLimit) else "-",
				week = week,
				weekMax = if entry.weeklyLimit then tostring(entry.weeklyLimit) else "-",
			})
		end
	end
	if not any then
		reply(player, "admin.shoplimits.none")
	end
end

commands.cosmetic = function(player, args)
	local action = args[1]
	if action == "all" then
		CosmeticService.GrantAll(player)
		reply(player, "admin.cosmetic.all")
		return
	end
	local id = args[2]
	if (action ~= "give" and action ~= "take") or not id then
		reply(player, "admin.usage.cosmetic")
		return
	end
	if not Cosmetics.get(id) then
		reply(player, "admin.cosmetic.unknown", { id = id })
		return
	end
	-- S123: give = CosmeticService.Grant (owned already: nothing); take = off the account, off the slot when worn
	-- (not owned or free: nothing); nothing changed answers so
	local changed = if action == "give" then CosmeticService.Grant(player, id) else CosmeticService.Take(player, id)
	if not changed then
		reply(player, "admin.cosmetic.unchanged", { id = id })
	else
		reply(player, if action == "give" then "admin.cosmetic.given" else "admin.cosmetic.taken", { id = id })
	end
end

-- S123: a starter pack without Robux (the pack's own handler) or its purchase forgotten (granted passes off; the
-- cosmetics and shards stay).
commands.pack = function(player, args)
	local key = args[2]
	if (args[1] ~= "grant" and args[1] ~= "reset") or not key then
		reply(player, "admin.usage.pack")
		return
	end
	if not Products.getStarterPack(key) then
		reply(player, "admin.pack.unknown", { key = key })
		return
	end
	if args[1] == "grant" then
		if PremiumShopService.GrantPack(player, key) then
			reply(player, "admin.pack.granted", { key = key })
		else
			reply(player, "admin.usage.pack")
		end
	elseif PremiumShopService.ResetPack(player, key) then
		reply(player, "admin.pack.reset", { key = key })
	end
end

-- S123: the offer of the week (Logic/WeeklyOffer): names, the discounted one with its price, the end (UTC).
commands.weeklyoffer = function(player, args)
	local now = Clock.now()
	local week = if args[1] then tonumber(args[1]) else nil
	local offer = if week then WeeklyOffer.forWeek(week) else WeeklyOffer.at(now)
	local discounted = Cosmetics.get(offer.discounted)
	local ends = Time.weekStart(offer.week + 1)
	local year, month, day = Time.civil(ends)
	reply(player, "admin.weekly.offer", {
		week = offer.week,
		items = table.concat(offer.items, ", "),
		discounted = offer.discounted,
		price = if discounted then WeeklyOffer.discountedPrice(discounted.price) else 0,
		ends = string.format("%04d-%02d-%02d 00:00 UTC", year, month, day),
	})
end

commands.mail = function(player, args)
	withCharacter(player, function()
		local char = PlayerStateService.GetCharacter(player)
		local outgoing: any = { from = "admin", subjectKey = "mail.subject.admin", charId = nil }
		if args[1] == "gold" and parseAmount(args[2]) then
			outgoing.gold = math.max(1, parseAmount(args[2]) :: number)
		elseif args[1] == "item" and args[2] and Items.get(args[2]) then
			local def = Items.get(args[2]) :: any
			local n = math.clamp(parseAmount(args[3]) or 1, 1, def.maxStack)
			local item = if def.category == "equipment"
				then ItemRoll.rollItem(
					args[2],
					def.level,
					Rarities.parse(args[4]) or def.rarity or Rarities.COMMON,
					Rng.new(),
					InventoryService.NewUid()
				)
				else ItemRoll.makeStack(args[2], n, InventoryService.NewUid())
			outgoing.items = { item }
		else
			reply(player, "admin.usage.mail")
			return
		end
		outgoing.charId = if char then char.id else nil
		local ok, err = MailService.Send(player.UserId, outgoing)
		reply(player, if ok then "admin.mail.sent" else (err or "error.internal"))
	end)
end

-- S133: /mailcap reset [player]: the daily letter limit of the character (the caller's without a player).
commands.mailcap = function(player, args)
	local target = if args[2] then Context.services.AdminService.FindPlayer(args[2]) else player
	if not target then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	if args[1] ~= "reset" or PlayerStateService.GetCharacter(target) == nil then
		reply(player, if args[1] ~= "reset" then "admin.usage.mailcap" else "admin.needCharacter")
		return false, "admin.usage.mailcap"
	end
	PlayerStateService.Set(target, { "character", "mailSent" }, { day = 0, n = 0 })
	reply(player, "admin.mailcap.reset", { name = target.Name })
	return true
end

commands.auction = function(player, args)
	if args[1] == "list" then
		local parts = {}
		for category, n in AuctionService.AdminStats() do
			table.insert(parts, `{category} {n}`)
		end
		table.sort(parts)
		reply(player, "admin.auction.list", {
			list = table.concat(parts, ", "),
			mode = if AuctionService.IndexIsLocal() then "local" else "global",
		})
	elseif args[1] == "expireall" then
		if not RunService:IsStudio() then
			reply(player, "admin.studioOnly")
			return
		end
		reply(player, "admin.auction.expired", { n = AuctionService.AdminExpireAll() })
	else
		reply(player, "admin.usage.auction")
	end
end

commands.tradetest = function(player)
	if not game:GetService("RunService"):IsStudio() then
		reply(player, "admin.studioOnly")
		return
	end
	withCharacter(player, function()
		if TradeService.Preview(player) then
			reply(player, "admin.tradetest.ok")
		end
	end)
end

-- S23: exact values.
commands.setgold = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil or amount < 0 then
		reply(player, "admin.usage.setgold")
		return
	end
	withCharacter(player, function()
		PlayerStateService.Set(player, { "character", "gold" }, amount)
		reply(player, "admin.setgold.ok", { total = amount })
	end)
end

commands.setshards = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil or amount < 0 then
		reply(player, "admin.usage.setshards")
		return
	end
	PlayerStateService.Set(player, { "account", "dragonShards" }, amount)
	reply(player, "admin.setshards.ok", { total = amount })
end

-- S100: the login reward streak of the caller's account -------------------------------------------------------------

-- "today" / "yesterday" / "n days ago" / "never" for the last claim (a { key, args } argument, localized by the
-- client).
local function agoText(last: number, today: number): any
	if last == 0 then
		return { key = "admin.login.ago.never" }
	elseif last == today then
		return { key = "admin.login.ago.today" }
	elseif last == today - 1 then
		return { key = "admin.login.ago.yesterday" }
	end
	return { key = "admin.login.ago.days", args = { n = today - last } }
end

local function statusText(status: LoginReward.Status): any
	if status.claimedToday then
		return { key = "admin.login.status.claimed" }
	elseif status.resets then
		return { key = "admin.login.status.reset" }
	end
	return { key = "admin.login.status.claimable", args = { day = status.day } }
end

commands.login = function(player, _args)
	withCharacter(player, function()
		local state = LoginRewardService.State(player)
		if not state then
			return
		end
		local today = LoginRewardService.Today()
		reply(player, "admin.login.state", {
			day = state.day,
			last = state.last,
			ago = agoText(state.last, today),
			today = today,
			status = statusText(LoginReward.status(state, today)),
		})
		local char = PlayerStateService.GetCharacter(player)
		local gold, items = 0, 0
		for _, day in LoginReward.week(char.level, char.class) do
			gold += day.gold
			items += #day.items
		end
		reply(player, "admin.login.week", { level = char.level, gold = gold, items = items })
	end)
end

commands.loginset = function(player, args)
	local day = tonumber(args[1])
	local gap = tonumber(args[2] or "0")
	if day == nil or gap == nil or day ~= math.floor(day) or day < 0 or day > 7 or gap < 0 or gap > 30 then
		reply(player, "admin.usage.loginset")
		return
	end
	withCharacter(player, function()
		local today = LoginRewardService.Today()
		local state = if day == 0 then { day = 0, last = 0 } else { day = day, last = today - 1 - math.floor(gap) }
		LoginRewardService.SetState(player, state)
		local saved = LoginRewardService.State(player) :: LoginReward.State
		reply(player, "admin.login.set", {
			day = saved.day,
			last = saved.last,
			status = statusText(LoginReward.status(saved, today)),
		})
	end)
end

commands.loginnext = function(player, args)
	local days = tonumber(args[1] or "1")
	if days == nil or days ~= math.floor(days) or days < 1 or days > 30 then
		reply(player, "admin.usage.loginnext")
		return
	end
	withCharacter(player, function()
		local state = LoginRewardService.State(player)
		if not state then
			return
		end
		if state.last == 0 then
			reply(player, "admin.login.never")
			return
		end
		LoginRewardService.SetState(player, { day = state.day, last = math.max(0, state.last - days) })
		local saved = LoginRewardService.State(player) :: LoginReward.State
		reply(player, "admin.login.set", {
			day = saved.day,
			last = saved.last,
			status = statusText(LoginReward.status(saved, LoginRewardService.Today())),
		})
	end)
end

return commands
