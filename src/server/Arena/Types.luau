--!strict
-- Server-side arena types (S126, DESIGN-17 §6): the three exchangeable pieces ArenaService joins together.
--   * PairSource: where pairs come from. S126 Arena/LocalQueue (this server); S127 a Matchmaker (MemoryStore, all
--     servers) added in front with ArenaService.AddSource.
--   * Host: where a match is played. S126 "local" (Arena/LocalHost: the Ristalle sand of this server through
--     Arena/Sand); S127 "remote" (a reserved arena server: ReserveServer + teleport; the arena server then calls
--     ArenaService.RunMatch itself) set with ArenaService.SetHost.
--   * Arena/Match: one match, from the spec, a venue (Arena/Venues) and the services; it never knows the source or the
--     host. S128 3v3 and S130 tournaments run through the same Match.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)

export type PairSource = {
	kind: string, -- "local" | "global"
	join: (self: PairSource, ticket: ArenaRules.Ticket) -> (boolean, string?),
	leave: (self: PairSource, key: string) -> (),
	has: (self: PairSource, key: string) -> boolean,
	requeue: (self: PairSource, ticket: ArenaRules.Ticket) -> (), -- back in its old place (ready check failed by the other)
	take: (self: PairSource, now: number) -> { ArenaRules.Pairing }, -- pairs this server may start now
	waiting: (self: PairSource, mode: string, bracket: string) -> number?, -- nil = unknown (global)
	tickets: (self: PairSource) -> { ArenaRules.Ticket }, -- the tickets this server knows (admin /arena queue)
}

export type Host = {
	kind: string,
	start: (self: Host, spec: ArenaRules.MatchSpec, players: { [string]: Player }) -> (boolean, string?),
	pending: (self: Host) -> number, -- matches waiting for a free venue
}

return nil
