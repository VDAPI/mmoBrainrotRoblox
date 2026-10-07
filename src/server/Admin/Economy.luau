--!strict
-- Admin commands: economy (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared

local Blessings = require(Shared.Data.Blessings)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Products = require(Shared.Data.Products)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)

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

return commands
