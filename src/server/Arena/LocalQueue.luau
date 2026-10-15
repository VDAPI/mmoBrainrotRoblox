--!strict
-- The queue of this server (S126, DESIGN-17 §6): a PairSource of kind "local". Tickets in memory, pairing through
-- Logic/ArenaRules.pair for every mode; no Roblox services. A ticket never holds a Player (only entrant.userId):
-- ArenaService finds the player by user id, as it will for a ticket from MemoryStore (S127).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Types = require(script.Parent.Types)

local LocalQueue = {}

function LocalQueue.new(): Types.PairSource
	local tickets: { ArenaRules.Ticket } = {}

	local function indexOf(key: string): number?
		for i, t in tickets do
			if t.entrant.key == key then
				return i
			end
		end
		return nil
	end

	local source = {} :: any
	source.kind = "local"

	function source.join(_self: Types.PairSource, ticket: ArenaRules.Ticket): (boolean, string?)
		if indexOf(ticket.entrant.key) then
			return false, "arena.error.queued"
		end
		table.insert(tickets, ticket)
		return true, nil
	end

	function source.leave(_self: Types.PairSource, key: string)
		local i = indexOf(key)
		if i then
			table.remove(tickets, i)
		end
	end

	function source.has(_self: Types.PairSource, key: string): boolean
		return indexOf(key) ~= nil
	end

	-- Back in the queue with its old joinedAt: the pairing sorts by it, so the ticket keeps its place.
	function source.requeue(_self: Types.PairSource, ticket: ArenaRules.Ticket)
		if not indexOf(ticket.entrant.key) then
			table.insert(tickets, ticket)
		end
	end

	function source.take(_self: Types.PairSource, now: number): { ArenaRules.Pairing }
		local out: { ArenaRules.Pairing } = {}
		for _, id in Arena.MODE_ORDER do
			local mode = Arena.MODES[id]
			if not mode or not mode.enabled then
				continue
			end
			-- S128: teams (teamSize 3) through the team branch of ArenaRules.pair (a party team is one ticket)
			local mine = {}
			for _, t in tickets do
				if t.mode == id then
					table.insert(mine, t)
				end
			end
			local pairs = ArenaRules.pair(mine, now, mode.teamSize)
			for _, pairing in pairs do
				for _, side in pairing.sides do
					for _, t in side do
						local i = indexOf(t.entrant.key)
						if i then
							table.remove(tickets, i)
						end
					end
				end
				table.insert(out, pairing)
			end
		end
		return out
	end

	function source.waiting(_self: Types.PairSource, mode: string, bracket: string): number?
		local n = 0
		for _, t in tickets do
			if t.mode == mode and t.bracket == bracket then
				n += ArenaRules.size(t) -- S128: a party team counts its three fighters
			end
		end
		return n
	end

	function source.tickets(_self: Types.PairSource): { ArenaRules.Ticket }
		return table.clone(tickets)
	end

	return source :: Types.PairSource
end

return LocalQueue
