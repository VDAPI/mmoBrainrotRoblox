--!strict
-- The remote host (S127, DESIGN-17 §6): a Host of kind "remote" (Arena/Types) that plays a match on a reserved arena
-- server. `start` only sends the players of THIS server there (Arena/Transfer.toReserved with the record's access
-- code); the other side's server does the same for its player, and the arena server runs the match itself
-- (Arena/ArenaHost -> ArenaService.RunMatch(spec, "pit")). The Matchmaker hands in where the code of a match is and
-- what to do when the teleport fails (`resolve`). Nothing here reads purchases (tests/paywall.spec).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Transfer = require(script.Parent.Transfer)
local Types = require(script.Parent.Types)

export type Ticket = {
	code: string, -- ReservedServerAccessCode
	data: { [string]: any }, -- TeleportData for each player (Matchmaker: serverMode, arenaMatch, returnJob, slot)
	onFail: (player: Player, reason: string) -> (),
}

local RemoteHost = {}

function RemoteHost.new(resolve: (spec: ArenaRules.MatchSpec, player: Player) -> Ticket?): Types.Host
	local host = {} :: any
	host.kind = "remote"

	function host.start(
		_self: Types.Host,
		spec: ArenaRules.MatchSpec,
		players: { [string]: Player }
	): (boolean, string?)
		local any = false
		for _, player in players do
			local ticket = resolve(spec, player)
			if ticket then
				any = true
				local t = ticket :: Ticket
				task.spawn(Transfer.toReserved, player, t.code, t.data, function(reason: string)
					t.onFail(player, reason)
				end)
			end
		end
		return any, if any then nil else "arena.cancelled"
	end

	function host.pending(_self: Types.Host): number
		return 0 -- an arena server is never busy: every match gets its own
	end

	return host :: Types.Host
end

return RemoteHost
