--!strict
-- Admin commands: economy (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared

local Blessings = require(Shared.Data.Blessings)
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

commands.premium = function(player, args)
	local pass = args[2] and Products.getPass(args[2])
	if args[1] ~= "grant" or not pass then
		reply(player, "admin.usage.premium")
		return
	end
	MonetizationService.SetTestPass(player, pass.key, true)
	reply(player, "admin.pass.ok", { pass = pass.key, state = "on" })
end

-- S121: VIP test. on/off = a session-only subscription (also on live servers for admins; never saved).
commands.vip = function(player, args)
	local action = args[1]
	if action == "on" or action == "off" then
		-- VipChanged runs VipService.Refresh (daily shards, cosmetic of the month) when it turns on
		MonetizationService.SetTestSubscription(player, "vip", action == "on")
		reply(player, if action == "on" then "admin.vip.on" else "admin.vip.off")
	elseif action == "status" then
		local status = VipService.Status(player)
		if not status then
			reply(player, "admin.usage.vip")
			return
		end
		reply(player, "admin.vip.status", {
			active = tostring(status.active),
			sub = tostring(status.sub),
			pass = tostring(status.pass),
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
	if args[1] ~= "all" then
		reply(player, "admin.usage.cosmetic")
		return
	end
	CosmeticService.GrantAll(player)
	reply(player, "admin.cosmetic.all")
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
