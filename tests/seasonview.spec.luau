--!strict
-- S152b: what the season pass window, its HUD button and the shop card show (Logic/SeasonView over Logic/Season):
-- the mode around the season and its grace days, the cells of both tracks, the badge, the focus tier, the header
-- numbers, the sources list.

local Season = require("../src/shared/Logic/Season")
local SeasonView = require("../src/shared/Logic/SeasonView")
local Seasons = require("../src/shared/Data/Seasons")
local T = require("./Test")

local def = Seasons.get("s1") :: Seasons.SeasonDef
local DAY = 86400
local START = def.start
local ENDS = Season.ends(def)
local TP = Seasons.TIER_POINTS

local function at(points: number, premium: boolean?): any
	local s = Season.fresh("s1")
	s.points = points
	s.premium = premium == true
	return s
end

T.describe("Season view (S152b)", function()
	T.it("before the first season: soon with the next season, no button", function()
		local v = SeasonView.of(nil, nil, START - DAY)
		T.expect({ v.mode, v.def == nil, (v.next :: any).id }).toEqual({ "soon", true, "s1" })
		T.expect(SeasonView.shown(v)).toBe(false)
		T.expect(SeasonView.claimCount(v)).toBe(0)
		T.expect(SeasonView.canBuy(v, START - DAY)).toBe(false)
	end)

	T.it("a running season: a clean state until the server rolls, the header numbers from Logic/Season", function()
		local v = SeasonView.of({ id = "" }, nil, START + 3600)
		T.expect({ v.mode, (v.def :: any).id, v.state.id, v.tier, v.progress }).toEqual({ "running", "s1", "s1", 0, 0 })
		T.expect(SeasonView.shown(v)).toBe(true)
		local t = START + 2 * Seasons.WEEK + DAY
		local w = SeasonView.of(at(4 * TP + 250), nil, t)
		T.expect({ w.tier, w.progress, w.cap, w.maxed }).toEqual({ 4, 250, Season.capAt(def, t), false })
		T.expect(w.catchup).toBe(4 * TP + 250 < Season.lineAt(def, t))
		T.expect(w.endsIn).toBe(ENDS - t)
		T.expect({ SeasonView.daysHours(w.endsIn) }).toEqual({ (ENDS - t) // DAY, ((ENDS - t) % DAY) // 3600 })
	end)

	T.it("capped at the growing cap, maxed at the last tier (a full bar)", function()
		local t = START + 3600
		local cap = Season.capAt(def, t)
		local v = SeasonView.of(at(cap), nil, t)
		T.expect({ v.capped, v.maxed }).toEqual({ true, false })
		local last = SeasonView.of(at(def.tiers * TP), nil, ENDS - 1)
		T.expect({ last.tier, last.maxed, last.capped, last.progress }).toEqual({ def.tiers, true, false, TP })
	end)

	T.it("cells: empty, locked, claimable, claimed and the premium lock", function()
		local t = START + 3600
		local v = SeasonView.of(at(6 * TP), nil, t)
		T.expect(SeasonView.cell(v, 1, "free")).toBe("empty") -- free rewards every 2 tiers
		T.expect(SeasonView.cell(v, 2, "free")).toBe("claimable")
		T.expect(SeasonView.cell(v, 8, "free")).toBe("locked")
		T.expect(SeasonView.cell(v, 1, "premium")).toBe("noPremium")
		local claimed = Season.claim(at(6 * TP, true), 2, "free")
		local p = SeasonView.of(claimed, nil, t)
		T.expect(SeasonView.cell(p, 2, "free")).toBe("claimed")
		T.expect(SeasonView.cell(p, 1, "premium")).toBe("claimable")
		T.expect(SeasonView.cell(p, 7, "premium")).toBe("locked")
		-- the claimable cells are exactly Season.claimable
		local n = 0
		for tier = 1, def.tiers do
			for _, track in { "free", "premium" } do
				if SeasonView.cell(p, tier, track) == "claimable" then
					n += 1
				end
			end
		end
		T.expect(n).toBe(#Season.claimable(claimed, def))
		T.expect(SeasonView.claimCount(p)).toBe(n)
		T.expect(SeasonView.focusTier(p)).toBe(1)
		T.expect(SeasonView.focusTier(SeasonView.of(at(3 * TP + 10), nil, t))).toBe(2)
		T.expect(SeasonView.focusTier(SeasonView.of(at(0), nil, t))).toBe(1)
	end)

	T.it("claim all: over one reward of the shown season, or any of the previous one in grace", function()
		local t = START + 3600
		local none = SeasonView.of(at(0), nil, t)
		T.expect(SeasonView.claimAllShown(none)).toBe(false)
		local one = SeasonView.of(at(2 * TP), nil, t)
		T.expect({ #one.claimable, SeasonView.claimAllShown(one) }).toEqual({ 1, false })
		T.expect(SeasonView.claimAllShown(SeasonView.of(at(6 * TP), nil, t))).toBe(true)
		-- one leftover of the previous season (only s1 exists yet: the count SeasonView.of puts in `extra`)
		local prev = table.clone(none)
		prev.extra = 1
		T.expect({ SeasonView.claimCount(prev), SeasonView.claimAllShown(prev) }).toEqual({ 1, true })
	end)

	T.it("buying: only while the season runs and the track is not bought", function()
		local t = START + 3600
		T.expect(SeasonView.canBuy(SeasonView.of(at(0), nil, t), t)).toBe(true)
		T.expect(SeasonView.canBuy(SeasonView.of(at(0, true), nil, t), t)).toBe(false)
		T.expect(SeasonView.canBuy(SeasonView.of(at(0), nil, ENDS + 1), ENDS + 1)).toBe(false)
	end)

	T.it("after the season: grace days with the unclaimed rewards (before and after the roll), then soon", function()
		local s = at(10 * TP)
		local after = ENDS + DAY
		-- not rolled yet: the ended season is still account.season
		local a = SeasonView.of(s, nil, after)
		T.expect({ a.mode, (a.def :: any).id, a.claimUntil }).toEqual({ "grace", "s1", Season.claimUntil(def) })
		T.expect(SeasonView.claimCount(a)).toBe(#Season.claimable(s, def))
		T.expect(SeasonView.shown(a)).toBe(true)
		-- rolled: account.season is clean, the ended one is account.seasonPrev
		local b = SeasonView.of(Season.fresh(""), s, after)
		T.expect({ b.mode, b.state.points }).toEqual({ "grace", 10 * TP })
		-- everything claimed: still the grace view, but no button
		local done = s
		for _, c in Season.claimable(s, def) do
			done = Season.claim(done, c.tier, c.track)
		end
		local d = SeasonView.of(Season.fresh(""), done, after)
		T.expect({ d.mode, SeasonView.shown(d) }).toEqual({ "grace", false })
		-- past the grace days: soon (no season after the last one)
		local e = SeasonView.of(Season.fresh(""), s, Season.claimUntil(def) + 1)
		T.expect({ e.mode, e.next == nil }).toEqual({ "soon", true })
	end)

	T.it("the sources list holds every source of points once", function()
		local seen: { [string]: boolean } = {}
		for _, source in SeasonView.SOURCES do
			T.expect({ source, Seasons.POINTS[source] ~= nil, seen[source] == nil }).toEqual({ source, true, true })
			seen[source] = true
		end
		for source in Seasons.POINTS do
			T.expect({ source, seen[source] == true }).toEqual({ source, true })
		end
	end)
end)

return nil
