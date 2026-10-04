--!strict
-- Parties (DESIGN §17). S05 only needs the ally checks used by healing and buffs: until S09 builds real
-- parties, every player is only allied with themselves. S09 replaces the internals, not the API.

local PartyService = {
	Name = "PartyService",
}

function PartyService.AreAllies(a: Player, b: Player): boolean
	return a == b
end

-- Party members including `player` (just the player until S09).
function PartyService.Members(player: Player): { Player }
	return { player }
end

function PartyService.SameParty(a: Player, b: Player): boolean
	return a == b
end

return PartyService
