--!strict
-- What the season pass window, its HUD button and the shop card show (S152b, docs/DESIGN.md §21b). Pure: reads the
-- replicated account.season and account.seasonPrev with the client's clock and asks Logic/Season for every rule (no
-- rule of its own; the server stays the authority). Modes:
--   running  a season runs: its state (a clean one while the server has not rolled the account yet)
--   grace    no season runs, an ended one is in its grace days (claims until Season.claimUntil)
--   soon     neither: "the next season soon" (`next` = the next SEASONS entry, nil after the last one)
-- `extra` counts the reached, unclaimed rewards of a previous season still in its grace days while another runs
-- (SeasonClaimAll takes both).

local Season = require("./Season")
local Seasons = require("../Data/Seasons")
local Time = require("./Time")
local Types = require("../Types")

type SeasonDef = Seasons.SeasonDef
type SeasonState = Types.SeasonState

export type Mode = "running" | "grace" | "soon"
export type Cell = "empty" | "locked" | "noPremium" | "claimable" | "claimed"

export type View = {
	mode: Mode,
	def: SeasonDef?, -- the season shown (running or in grace)
	state: SeasonState, -- its state (sanitized)
	tier: number,
	progress: number, -- points inside the current tier
	cap: number, -- the growing cap at `now` (running), 0 otherwise
	capped: boolean, -- the cap is reached before the last tier (running)
	catchup: boolean, -- below the catch-up line: every source gives x CATCHUP.mul (running)
	maxed: boolean, -- the last tier is reached
	kill: number, -- monster points today (the daily limit)
	endsIn: number, -- seconds to the end of the running season
	claimUntil: number, -- the last second of claims (running and grace)
	claimable: { Season.Claim }, -- of the shown season
	extra: number, -- reached, unclaimed rewards of a previous season in its grace days while another runs
	next: SeasonDef?, -- soon: the next season, if one is planned
}

local SeasonView = {}

-- The sources of points in the order the window lists them (every key of Data/Seasons.POINTS; tests/season.spec).
SeasonView.SOURCES = table.freeze({
	"kill",
	"elite",
	"elite2",
	"boss",
	"worldBoss",
	"quest",
	"side",
	"contract",
	"daily",
	"weekly",
	"worldEvent",
	"bloodMoon",
	"arena",
	"achievement",
})

local function inGrace(def: SeasonDef, now: number): boolean
	return now >= Season.ends(def) and now <= Season.claimUntil(def)
end

-- The saved states (account.season, then account.seasonPrev) of seasons in their grace days at `now`, sanitized.
local function graceStates(season: any, prev: any, now: number): { SeasonState }
	local out: { SeasonState } = {}
	for _, raw in { season, prev } do
		if type(raw) == "table" then
			local s = Season.sanitize(raw)
			local def = Seasons.get(s.id)
			if def and inGrace(def, now) then
				table.insert(out, s)
			end
		end
	end
	return out
end

function SeasonView.of(season: any, prev: any, now: number): View
	local running = Seasons.at(now)
	local def: SeasonDef? = nil
	local state: SeasonState = Season.fresh("")
	local mode: Mode = "soon"
	local extra = 0
	if running then
		def, mode = running, "running"
		local s = Season.sanitize(season)
		state = if s.id == running.id then s else Season.fresh(running.id, s)
		for _, g in graceStates(season, prev, now) do
			local gDef = Seasons.get(g.id) :: SeasonDef
			extra += #Season.claimable(g, gDef)
		end
	else
		-- the ended season with something to claim first, else the one that ended last
		local best: SeasonState? = nil
		local bestLeft = -1
		for _, g in graceStates(season, prev, now) do
			local left = #Season.claimable(g, Seasons.get(g.id) :: SeasonDef)
			if best == nil or (left > 0 and bestLeft == 0) then
				best, bestLeft = g, left
			end
		end
		if best then
			state, mode = best, "grace"
			def = Seasons.get(best.id)
		end
	end
	local tier, progress, cap, kill = 0, 0, 0, 0
	local capped, catchup, maxed = false, false, false
	local endsIn, claimUntil = 0, 0
	local claimable: { Season.Claim } = {}
	if def then
		tier = Season.tierOf(state.points, def)
		progress = if tier >= def.tiers then Seasons.TIER_POINTS else Season.progress(state.points)
		maxed = tier >= def.tiers
		claimable = Season.claimable(state, def)
		claimUntil = Season.claimUntil(def)
		if mode == "running" then
			cap = Season.capAt(def, now)
			capped = not maxed and state.points >= cap
			catchup = not maxed and state.points < Season.lineAt(def, now)
			endsIn = math.max(0, Season.ends(def) - now)
			kill = if state.day == Time.dayNumber(now) then state.dayKill else 0
		end
	end
	return {
		mode = mode,
		def = def,
		state = state,
		tier = tier,
		progress = progress,
		cap = cap,
		capped = capped,
		catchup = catchup,
		maxed = maxed,
		kill = kill,
		endsIn = endsIn,
		claimUntil = claimUntil,
		claimable = claimable,
		extra = extra,
		next = if mode == "soon" then Seasons.next(now) else nil,
	}
end

-- What a cell of the reward strip shows: empty (no reward on that tier and track), claimed, noPremium (the premium
-- track is not bought), locked (the tier is not reached) or claimable.
function SeasonView.cell(view: View, tier: number, track: string): Cell
	local def = view.def
	if not def or Season.rewardOf(def, tier, track) == nil then
		return "empty"
	end
	local map = if track == "premium" then view.state.prem else view.state.free
	if map[tostring(tier)] == true then
		return "claimed"
	end
	if track == "premium" and not view.state.premium then
		return "noPremium"
	end
	if tier > view.tier then
		return "locked"
	end
	return "claimable"
end

-- Everything there is to claim now (the shown season and a previous one in its grace days).
function SeasonView.claimCount(view: View): number
	return #view.claimable + view.extra
end

-- "Claim all" shows for more than one reward of the shown season, or for any reward of a previous season in its grace
-- days (the strip has no cell for those, so SeasonClaimAll is the only way to them).
function SeasonView.claimAllShown(view: View): boolean
	return #view.claimable > 1 or view.extra > 0
end

-- The HUD button shows while a season runs or an ended one still has rewards to claim.
function SeasonView.shown(view: View): boolean
	return view.mode == "running" or SeasonView.claimCount(view) > 0
end

-- The tier the strip scrolls to when the window opens: the first one with a reward to claim, else the current tier
-- (at least 1).
function SeasonView.focusTier(view: View): number
	local first = view.claimable[1]
	if first then
		return first.tier
	end
	return math.max(1, view.tier)
end

-- Whether the premium track of the shown season can be bought now (Season.canBuy).
function SeasonView.canBuy(view: View, now: number): boolean
	return view.mode == "running" and (Season.canBuy(view.state, view.def, now))
end

-- Whole days and hours of `seconds` (the "ends in" line).
function SeasonView.daysHours(seconds: number): (number, number)
	local s = math.max(0, math.floor(seconds))
	return s // 86400, (s % 86400) // 3600
end

return SeasonView
