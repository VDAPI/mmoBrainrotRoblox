--!strict
-- The local host (S126): a Host of kind "local" that plays a match on the Ristalle sand of this server. The sand is
-- shared with friendly duels through Arena/Sand (one line, in the order of the requests). When the sand comes free the
-- host checks the fighters again (online, the same character, alive, not in a dungeon, out of combat); one who dropped
-- out cancels the match without a rating and the others go back to their place in the queue (ArenaService through
-- `cancelled`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Sand = require(script.Parent.Sand)
local Types = require(script.Parent.Types)

export type Callbacks = {
	-- whether `player` can still fight as entrant `key` (ArenaService: online, same character, alive, not in a dungeon,
	-- out of combat)
	ready: (player: Player, key: string) -> boolean,
	-- the sand is taken: the fighters wait (toast and the "waiting" panel), `place` in the line
	queued: (spec: ArenaRules.MatchSpec, players: { [string]: Player }, place: number) -> (),
	-- the sand is ours: run the match (ArenaService builds Arena/Match on the venue); `release` frees the sand
	run: (spec: ArenaRules.MatchSpec, players: { [string]: Player }, release: () -> ()) -> (),
	-- some fighter dropped out before the start: the match is off, nothing rated
	cancelled: (spec: ArenaRules.MatchSpec, players: { [string]: Player }, missing: { string }) -> (),
}

local LocalHost = {}

function LocalHost.new(callbacks: Callbacks): Types.Host
	local waiting = 0
	local host = {} :: any
	host.kind = "local"

	function host.start(
		_self: Types.Host,
		spec: ArenaRules.MatchSpec,
		players: { [string]: Player }
	): (boolean, string?)
		local granted = false
		waiting += 1
		local place = Sand.request("arena", spec.id, function()
			granted = true
			waiting -= 1
			local missing = {}
			for key, player in players do
				if not callbacks.ready(player, key) then
					table.insert(missing, key)
				end
			end
			if #missing > 0 then
				Sand.release("arena", spec.id)
				callbacks.cancelled(spec, players, missing)
				return
			end
			callbacks.run(spec, players, function()
				Sand.release("arena", spec.id)
			end)
		end)
		if not granted and place > 0 then
			callbacks.queued(spec, players, place)
		end
		return true, nil
	end

	function host.pending(_self: Types.Host): number
		return waiting
	end

	return host :: Types.Host
end

return LocalHost
