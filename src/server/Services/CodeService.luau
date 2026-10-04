--!strict
-- Reward codes (S17): Data/Codes, checked by Logic/Codes, once per account (account.redeemed). The code is
-- marked first and the reward mailed to the active character; when the mail fails the mark is undone so
-- the player can try again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Analytics = require(script.Parent.Parent.Analytics)
local Codes = require(Shared.Logic.Codes)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local log = Log.new("CodeService")

local CodeService = {
	Name = "CodeService",
	Deps = { "PlayerStateService", "MailService", "InventoryService", "DataService" },
}

local PlayerStateService: any
local MailService: any
local InventoryService: any
local DataService: any

local busy: { [Player]: boolean } = {}

local function redeem(player: Player, text: string): (boolean, string?)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local account = PlayerStateService.Get(player, { "account" })
	if not char or not account or busy[player] then
		return false, "error.internal"
	end
	local def, err = Codes.check(text, account.redeemed, os.time())
	if not def then
		return false, err
	end
	busy[player] = true
	PlayerStateService.Set(player, { "account", "redeemed", def.code }, os.time())

	local items = {}
	for _, entry in def.items or ({} :: { { id: string, n: number } }) do
		table.insert(items, ItemRoll.makeStack(entry.id, entry.n, InventoryService.NewUid()))
	end
	local ok = true
	if (def.gold or 0) > 0 or #items > 0 then
		local sent, sendErr = MailService.Send(player.UserId, {
			from = "system",
			subjectKey = "mail.subject.code",
			args = { code = def.code },
			gold = def.gold,
			items = items,
			charId = char.id,
		})
		if not sent then
			ok = false
			log:warn("code %s for %s not mailed: %s", def.code, player.Name, tostring(sendErr))
		end
	end
	if not ok then
		busy[player] = nil
		if player.Parent ~= nil and PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "account", "redeemed", def.code }, nil)
		end
		return false, "codes.error.mail"
	end
	if (def.shards or 0) > 0 then
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
			return shards + (def.shards :: number)
		end)
		Analytics.shards(player, def.shards :: number, total, "code")
	end
	Analytics.custom(player, "RedeemCode", nil)
	DataService.Save(player)
	busy[player] = nil
	MailService.Refresh(player)
	return true
end

function CodeService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	MailService = registry.Get("MailService")
	InventoryService = registry.Get("InventoryService")
	DataService = registry.Get("DataService")
end

function CodeService.Start()
	Net.Handle("RedeemCode", redeem)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return CodeService
