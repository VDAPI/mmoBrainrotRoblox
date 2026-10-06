--!strict
-- Shared state of the admin command modules (S23): the services (filled by AdminService.Init before the
-- modules are required), reply capture for the dev panel and small helpers every module uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local Context = {}

-- Service name -> service, set by AdminService.Init.
Context.services = {} :: { [string]: any }
Context.log = Log.new("AdminService")
Context.MAX_AMOUNT = 1e12
-- Monster variant by number in commands (/spawn, /lootsim).
Context.VARIANTS = { [0] = "normal", [1] = "elite", [2] = "elite2" }

export type Line = { key: string, args: { [string]: any }? }

-- While a panel call runs, its replies are collected here instead of going to the chat.
local capture: { [Player]: { Line }? } = {}

-- Reply to the caller: a system chat line, or a result line of the dev panel call that is running.
function Context.reply(player: Player, key: string, args: { [string]: any }?)
	local lines = capture[player]
	if lines then
		table.insert(lines, { key = key, args = args })
		return
	end
	Net.Fire(player, "SystemMessage", key, args)
end

-- Starts / stops collecting replies of `player` (AdminService.Run for the panel).
function Context.capture(player: Player, lines: { Line }?)
	capture[player] = lines
end

-- Whole number from a chat argument within +-MAX_AMOUNT, or nil.
function Context.parseAmount(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) > Context.MAX_AMOUNT then
		return nil
	end
	return math.floor(n)
end

-- Runs `fn` only when the caller is in the world with a character.
function Context.withCharacter(player: Player, fn: () -> ())
	if Context.services.PlayerStateService.GetCharacter(player) == nil then
		Context.reply(player, "admin.needCharacter")
		return
	end
	fn()
end

-- Admin check (AdminService.IsAdmin), set by AdminService.Init.
Context.isAdmin = function(_player: Player): boolean
	return false
end

return Context
