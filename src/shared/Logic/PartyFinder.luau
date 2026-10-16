--!strict
-- Party finder board (S134f, DESIGN §17): "looking for a party for a boss / an Elite II / the Invasion / a hunting
-- ground" with a Join button, one board per server. A listing is never free text (moderation): the target, a level
-- band and the wanted classes. The band comes from the data (`bandFor`); the leader may only narrow it (`clampBand`),
-- never widen it below a boss's entry level. Pure: PartyFinderService (server) and the board (UI/Screens/PartyFinder)
-- call the same `canPost` / `canJoin`.

local BossScaling = require("./BossScaling")
local Areas = require("../Data/Areas")
local Bosses = require("../Data/Bosses")
local Classes = require("../Data/Classes")
local Config = require("../Config")
local Maps = require("../Data/Maps")
local Spawns = require("../Data/Spawns")

local PartyFinder = {}

export type Kind = "boss" | "elite2" | "invasion" | "ground"

-- Where "Guide" leads (map-relative, like NavTarget).
export type Place = { map: string, x: number, z: number }

export type Listing = {
	id: number,
	leaderId: number,
	leaderName: string,
	leaderClass: string,
	leaderLevel: number,
	kind: Kind,
	target: string,
	nameKey: string,
	level: number, -- the target's level (a boss, an Elite II, the event; a ground: its lowest level)
	minLevel: number,
	maxLevel: number,
	want: { string }, -- class ids; empty = any class
	size: number, -- the party now (1 = the leader alone)
	createdAt: number,
	expiresAt: number,
	at: Place?,
}

-- A target the board offers (static ones from the data; the Invasion comes from the running event).
export type Target = { kind: Kind, id: string, nameKey: string, level: number, top: number, at: Place? }

-- What canPost needs about the server and the leader.
export type PostState = { listings: { Listing }, maxListings: number }
export type Poster = {
	id: number,
	level: number,
	inParty: boolean,
	isLeader: boolean,
	partySize: number,
	minLevel: number,
	maxLevel: number,
}
export type Joiner = { id: number, level: number, class: string, inParty: boolean }

local CFG = Config.PartyFinder

PartyFinder.KINDS = table.freeze({ "boss", "elite2", "invasion", "ground" } :: { Kind })

local function clampLevel(level: number): number
	return math.clamp(math.floor(level), 1, Config.MaxLevel)
end

-- The level band of a target: boss = from the entry level (BossScaling.requiredLevel) to level + bossAbove; Elite II =
-- level - eliteBelow .. + eliteAbove; ground = lowest - groundBelow .. highest (`top`) + groundAbove; Invasion =
-- level +- invasionBand.
function PartyFinder.bandFor(kind: Kind, level: number, top: number?): (number, number)
	local lo, hi
	if kind == "boss" then
		lo, hi = BossScaling.requiredLevel(level), level + CFG.bossAbove
	elseif kind == "elite2" then
		lo, hi = level - CFG.eliteBelow, level + CFG.eliteAbove
	elseif kind == "ground" then
		lo, hi = level - CFG.groundBelow, (top or level) + CFG.groundAbove
	else
		lo, hi = level - CFG.invasionBand, level + CFG.invasionBand
	end
	return clampLevel(lo), clampLevel(hi)
end

-- The leader's wish narrowed into the base band (never wider; min <= max).
function PartyFinder.clampBand(baseMin: number, baseMax: number, wantMin: number?, wantMax: number?): (number, number)
	local lo = math.clamp(math.floor(wantMin or baseMin), baseMin, baseMax)
	local hi = math.clamp(math.floor(wantMax or baseMax), lo, baseMax)
	return lo, hi
end

-- Wanted classes: known class ids, each once, at most CFG.maxWant (nil = a bad list).
function PartyFinder.validWant(want: any): { string }?
	if type(want) ~= "table" then
		return nil
	end
	local out: { string } = {}
	local count = 0
	for _, id in want do
		count += 1
		if count > CFG.maxWant or type(id) ~= "string" or Classes.get(id) == nil or table.find(out, id) then
			return nil
		end
		table.insert(out, id)
	end
	return out
end

-- Static targets ---------------------------------------------------------------------------------------------

local catalog: { [string]: { Target } } = {}

local function build(kind: Kind): { Target }
	local list: { Target } = {}
	if kind == "boss" then
		for _, def in Bosses.list do
			local at: Place? = nil
			for _, map in Maps.byId do
				local e = map.dungeonEntrance
				if map.dungeonRegion == def.region and e then
					at = { map = map.id, x = e.x, z = e.z }
				end
			end
			table.insert(
				list,
				{ kind = kind, id = def.region, nameKey = def.nameKey, level = def.level, top = def.level, at = at }
			)
		end
	elseif kind == "ground" then
		for mapId, data in Areas.byMap do
			for _, area in data.areas do
				local spot = area.arrive or area.landmark
				local x = if spot then spot.x else (area.rect[1] + area.rect[3]) / 2
				local z = if spot then spot.z else (area.rect[2] + area.rect[4]) / 2
				table.insert(list, {
					kind = kind,
					id = `{mapId}:{area.id}`,
					nameKey = area.nameKey,
					level = area.lv[1],
					top = area.lv[2],
					at = { map = mapId, x = x, z = z },
				})
			end
		end
	elseif kind == "elite2" then
		for mapId, spawners in Spawns.byMap do
			local map = Maps.get(mapId)
			for _, spawner in spawners do
				if spawner.variant == "elite2" and map then
					table.insert(list, {
						kind = kind,
						id = `{mapId}:{spawner.id}`,
						nameKey = map.nameKey,
						level = spawner.level.max,
						top = spawner.level.max,
						at = { map = mapId, x = spawner.position.x, z = spawner.position.z },
					})
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return a.id < b.id
	end)
	return list
end

-- Targets of a kind sorted by level (the Invasion has none here: it is the running event).
function PartyFinder.targets(kind: Kind): { Target }
	local list = catalog[kind]
	if not list then
		list = if kind == "invasion" then {} else build(kind)
		catalog[kind] = list
	end
	return list
end

function PartyFinder.target(kind: Kind, id: string): Target?
	for _, target in PartyFinder.targets(kind) do
		if target.id == id then
			return target
		end
	end
	return nil
end

-- The target of `kind` closest to the level (the board's default pick).
function PartyFinder.nearest(kind: Kind, level: number): Target?
	local best: Target? = nil
	local bestGap = math.huge
	for _, target in PartyFinder.targets(kind) do
		local lo, hi = PartyFinder.bandFor(kind, target.level, target.top)
		local gap = if level < lo then lo - level elseif level > hi then level - hi else 0
		if gap < bestGap then
			best, bestGap = target, gap
		end
	end
	return best
end

-- Rules ------------------------------------------------------------------------------------------------------

function PartyFinder.canPost(state: PostState, leader: Poster): (boolean, string?)
	if leader.inParty and not leader.isLeader then
		return false, "finder.error.notLeader"
	end
	if leader.partySize >= CFG.maxMembers then
		return false, "finder.error.full"
	end
	local others = 0
	for _, listing in state.listings do
		if listing.leaderId ~= leader.id then
			others += 1
		end
	end
	if others >= state.maxListings then
		return false, "finder.error.limit"
	end
	if leader.level < leader.minLevel or leader.level > leader.maxLevel then
		return false, "finder.error.level"
	end
	return true, nil
end

function PartyFinder.canJoin(listing: Listing, joiner: Joiner, now: number): (boolean, string?)
	if now >= listing.expiresAt then
		return false, "finder.error.expired"
	end
	if joiner.id == listing.leaderId then
		return false, "finder.error.own"
	end
	if joiner.inParty then
		return false, "finder.error.inParty"
	end
	if joiner.level < listing.minLevel or joiner.level > listing.maxLevel then
		return false, "finder.error.level"
	end
	if listing.size >= CFG.maxMembers then
		return false, "finder.error.full"
	end
	if #listing.want > 0 and not table.find(listing.want, joiner.class) then
		return false, "finder.error.class"
	end
	return true, nil
end

-- Puts `listing` on the board; the leader's older listing goes (one per leader).
function PartyFinder.post(listings: { Listing }, listing: Listing): { Listing }
	local out = {}
	for _, other in listings do
		if other.leaderId ~= listing.leaderId then
			table.insert(out, other)
		end
	end
	table.insert(out, listing)
	return out
end

-- What the viewer sees: no expired listings; the ones his level fits first, then the newest. The others stay (greyed
-- out with canJoin's reason on the board).
function PartyFinder.visible(listings: { Listing }, viewerLevel: number, now: number): { Listing }
	local out = {}
	for _, listing in listings do
		if now < listing.expiresAt then
			table.insert(out, listing)
		end
	end
	local function fits(listing: Listing): boolean
		return viewerLevel >= listing.minLevel and viewerLevel <= listing.maxLevel
	end
	table.sort(out, function(a, b)
		local fa, fb = fits(a), fits(b)
		if fa ~= fb then
			return fa
		end
		if a.createdAt ~= b.createdAt then
			return a.createdAt > b.createdAt
		end
		return a.id > b.id
	end)
	return out
end

-- Drops expired listings and those whose leader no longer leads a party that may be joined (`alive`).
function PartyFinder.prune(listings: { Listing }, now: number, alive: (listing: Listing) -> boolean): { Listing }
	local out = {}
	for _, listing in listings do
		if now < listing.expiresAt and listing.size < CFG.maxMembers and alive(listing) then
			table.insert(out, listing)
		end
	end
	return out
end

return PartyFinder
