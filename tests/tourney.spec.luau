--!strict
-- Champion's Tournament (S130, DESIGN-17 §8): the bracket (Logic/Bracket, with a simulation of tournaments of bots),
-- the rules (Logic/Tourney: phases, signups, the full list, rewards), the data, the save field and the source text of
-- the server modules (no purchases, every Roblox service in pcall, the S127 registry only).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Arena = require("../src/shared/Data/Arena")
local ArenaRules = require("../src/shared/Logic/ArenaRules")
local Bracket = require("../src/shared/Logic/Bracket")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Rng = require("../src/shared/Logic/Rng")
local Schedule = require("../src/shared/Logic/Schedule")
local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
local T = require("./Test")
local Titles = require("../src/shared/Data/Titles")
local Tourney = require("../src/shared/Logic/Tourney")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local DAY = 86400
local TOURNEY = Arena.TOURNEY
local DEF = ScheduledEvents.get("tourney") :: ScheduledEvents.EventDef

local function keys(n: number): { string }
	local out = {}
	for i = 1, n do
		table.insert(out, `{i}_1`)
	end
	return out
end

local function sorted(list: { number }): { number }
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end

T.describe("Tourney T1: the bracket", function()
	T.it("size and the standard seeding", function()
		for n, size in { [2] = 2, [3] = 4, [4] = 4, [5] = 8, [8] = 8, [9] = 16, [17] = 32, [32] = 32 } do
			T.expect({ n, Bracket.size(n) }).toEqual({ n, size })
		end
		T.expect(Bracket.order(8)).toEqual({ 1, 8, 4, 5, 2, 7, 3, 6 })
		T.expect(Bracket.order(4)).toEqual({ 1, 4, 2, 3 })
		for _, size in { 2, 4, 8, 16, 32 } do
			local order = Bracket.order(size)
			local expected = {}
			for i = 1, size do
				expected[i] = i
			end
			T.expect(sorted(order)).toEqual(expected)
			for j = 1, size // 2 do
				T.expect(order[j * 2 - 1] + order[j * 2]).toBe(size + 1)
			end
		end
	end)

	T.it("byes go to the top seeds, are decided at once and move on; never a bye against a bye", function()
		for n = 4, 32 do
			local seeds = keys(n)
			local b = Bracket.new(seeds)
			local byes = 0
			local winners: { [string]: boolean } = {}
			for _, m in b.matches do
				if m.round == 1 then
					T.expect({ n, m.id, m.a ~= nil or m.b ~= nil }).toEqual({ n, m.id, true })
					if m.reason == "bye" then
						byes += 1
						winners[m.winner :: string] = true
					end
				end
			end
			T.expect({ n, byes }).toEqual({ n, b.size - n })
			for i = 1, b.size - n do
				T.expect({ n, i, winners[seeds[i]] == true }).toEqual({ n, i, true })
			end
			-- the winner of a bye stands in its round-2 match
			for key in winners do
				local found = false
				for _, m in b.matches do
					if m.round == 2 and (m.a == key or m.b == key) then
						found = true
					end
				end
				T.expect({ n, key, found }).toEqual({ n, key, true })
			end
		end
	end)

	T.it("ready and report: only full matches, the winner moves on, bad reports fail", function()
		local b = Bracket.new(keys(6))
		for _, m in Bracket.ready(b) do
			T.expect(m.a ~= nil and m.b ~= nil and m.winner == nil).toBe(true)
		end
		local first = Bracket.ready(b)[1]
		local id, winner = first.id, first.a :: string
		Bracket.report(b, id, winner, "win")
		for _, m in Bracket.ready(b) do
			T.expect(m.id ~= id).toBe(true)
		end
		local inNext = false
		for _, m in b.matches do
			if m.round == 2 and (m.a == winner or m.b == winner) then
				inNext = true
			end
		end
		T.expect(inNext).toBe(true)
		-- twice, a stranger, a match without a pair
		T.expect((pcall(Bracket.report, b, id, winner, "win"))).toBe(false)
		local other = Bracket.ready(b)[1]
		T.expect((pcall(Bracket.report, b, other.id, "nobody", "win"))).toBe(false)
		local final = b.matches[#b.matches]
		T.expect((pcall(Bracket.report, b, final.id, "1_1", "win"))).toBe(false)
	end)

	T.it("withdraw: walkovers now or once the opponent is known; two absent; an absent final winner", function()
		-- a known opponent
		local b = Bracket.new({ "A", "B", "C", "D" }) -- A-D, B-C
		Bracket.withdraw(b, "D")
		T.expect(b.matches[1].winner).toBe("A")
		T.expect(b.matches[1].reason).toBe("walkover")
		-- an unknown opponent: A won, then left; B wins the final by walkover once known
		local c = Bracket.new({ "A", "B", "C", "D" })
		Bracket.report(c, 1, "A", "win")
		Bracket.withdraw(c, "A")
		T.expect(Bracket.done(c)).toBe(false)
		Bracket.report(c, 2, "B", "win")
		T.expect(Bracket.done(c)).toBe(true)
		T.expect(c.matches[3].reason).toBe("walkover")
		T.expect(Bracket.champion(c)).toBe("B")
		-- both gone at once (the same tick): the higher seed goes on (absent) and loses the next by walkover
		local d = Bracket.new({ "A", "B", "C", "D" })
		d.absent.A = true
		Bracket.withdraw(d, "D")
		T.expect(d.matches[1].winner).toBe("A")
		T.expect(d.matches[1].reason).toBe("walkover")
		Bracket.report(d, 2, "C", "win")
		T.expect(Bracket.champion(d)).toBe("C")
		-- a final won by an absent player: no champion
		local e = Bracket.new({ "A", "B" })
		e.absent.A = true
		Bracket.withdraw(e, "B")
		T.expect(Bracket.done(e)).toBe(true)
		T.expect(Bracket.champion(e)).toBeNil()
		T.expect((pcall(Bracket.new, { "A" }))).toBe(false)
	end)

	T.it("places: champion 1, finalist 2, semifinals 3, quarterfinals 5, round of 32 17", function()
		local function play(n: number): Bracket.Bracket
			local b = Bracket.new(keys(n))
			while not Bracket.done(b) do
				local m = Bracket.ready(b)[1]
				Bracket.report(b, m.id, m.a :: string, "win") -- the higher seed always wins
			end
			return b
		end
		local b8 = play(8)
		T.expect(Bracket.placeOf(b8, "1_1")).toBe(1)
		T.expect(Bracket.placeOf(b8, "2_1")).toBe(2)
		T.expect(Bracket.placeOf(b8, "3_1")).toBe(3)
		T.expect(Bracket.placeOf(b8, "4_1")).toBe(3)
		for i = 5, 8 do
			T.expect(Bracket.placeOf(b8, `{i}_1`)).toBe(5)
		end
		local b32 = play(32)
		T.expect(Bracket.placeOf(b32, "32_1")).toBe(17)
		T.expect(Bracket.placeOf(b32, "9_1")).toBe(9)
		local running = Bracket.new(keys(8))
		T.expect(Bracket.placeOf(running, "1_1")).toBeNil()
		T.expect({ Bracket.placeRange(b8, 5) }).toEqual({ 5, 8 })
		T.expect({ Bracket.placeRange(b8, 17) }).toEqual({ 17, 32 })
		T.expect({ Bracket.placeRange(b8, 3) }).toEqual({ 3, 4 })
	end)

	T.it("bots: 200 tournaments for every size 4..32 end well, the same seed the same way", function()
		local function run(n: number, seed: number): (Bracket.Bracket, number)
			local rng = Rng.new(seed)
			local b = Bracket.new(keys(n))
			local steps = 0
			while not Bracket.done(b) do
				steps += 1
				if steps > n then
					error(`n={n} seed={seed}: more than {n} steps`)
				end
				local ready = Bracket.ready(b)
				if #ready == 0 then
					error(`n={n} seed={seed}: stuck`)
				end
				local m = ready[rng:int(1, #ready)]
				if rng:chance(0.05) then
					Bracket.withdraw(b, if rng:chance(0.5) then m.a :: string else m.b :: string)
				else
					Bracket.report(b, m.id, if rng:chance(0.5) then m.a :: string else m.b :: string, "win")
				end
			end
			return b, steps
		end
		for n = 4, 32 do
			for i = 1, 200 do
				local seed = n * 1000 + i
				local b = run(n, seed)
				local fought, byes = 0, 0
				local lost: { [string]: number } = {}
				for _, m in b.matches do
					T.expect(m.winner ~= nil).toBe(true)
					if m.reason == "bye" then
						byes += 1
					else
						fought += 1
						local loser = if m.winner == m.a then m.b else m.a
						lost[loser :: string] = (lost[loser :: string] or 0) + 1
					end
				end
				for key, count in lost do
					if count > 1 then
						error(`n={n} seed={seed}: {key} lost {count} times`)
					end
				end
				if fought ~= n - 1 or byes ~= b.size - n then
					error(`n={n} seed={seed}: {fought} fought, {byes} byes`)
				end
				local champion = Bracket.champion(b)
				local places: { [number]: number } = {}
				for _, key in keys(n) do
					local place = Bracket.placeOf(b, key)
					if place == nil then
						error(`n={n} seed={seed}: {key} has no place`)
					end
					places[place :: number] = (places[place :: number] or 0) + 1
				end
				if champion then
					if places[1] ~= 1 or places[2] ~= 1 or places[3] ~= 2 then
						error(`n={n} seed={seed}: places 1/2/3 = {places[1]}/{places[2]}/{places[3]}`)
					end
				elseif places[1] ~= nil or places[2] ~= 2 then
					error(`n={n} seed={seed}: no champion, places 1/2 = {places[1]}/{places[2]}`)
				end
			end
			-- determinism
			local a1 = run(n, n * 1000 + 7)
			local a2 = run(n, n * 1000 + 7)
			T.expect(Bracket.view(a1)).toEqual(Bracket.view(a2))
		end
	end)

	T.it("the view has no absent / eliminated maps and encodes to JSON", function()
		local b = Bracket.new(keys(11))
		Bracket.withdraw(b, "11_1")
		local view = Bracket.view(b)
		T.expect(view.absent).toBeNil()
		T.expect(view.eliminated).toBeNil()
		local ok = pcall(serde.encode, "json", view)
		T.expect(ok).toBe(true)
	end)
end)

T.describe("Tourney T2: the rules", function()
	local THURSDAY = 1760000000 -- 2025-10-09 08:53 UTC, a Thursday
	local start = Tourney.startAt(THURSDAY)
	local w = TOURNEY.window

	T.it("the start is Saturday 19:00 UTC; phases on their exact seconds; the id is the date", function()
		T.expect(Schedule.weekday(start)).toBe(6)
		T.expect(start % DAY).toBe(19 * 3600)
		T.expect(Schedule.weekday(THURSDAY)).toBe(4)
		local function phase(t: number): string
			local p = Tourney.phaseAt(t)
			return p
		end
		T.expect(phase(start + w.open - 1)).toBe("idle")
		T.expect(phase(start + w.open)).toBe("signup")
		T.expect(phase(start + w.close - 1)).toBe("signup")
		T.expect(phase(start + w.close)).toBe("closed")
		T.expect(phase(start + w.organize - 1)).toBe("closed")
		T.expect(phase(start + w.organize)).toBe("inviting")
		T.expect(phase(start - 1)).toBe("inviting")
		T.expect(phase(start)).toBe("running")
		local p, nextStart = Tourney.phaseAt(start + DEF.duration)
		T.expect(p).toBe("idle")
		T.expect(nextStart).toBe(start + 7 * DAY)
		-- a Tuesday at the same hour: nothing
		T.expect(phase(start - 4 * DAY)).toBe("idle")
		T.expect(Tourney.idOf(start)).toBe(Schedule.dateKey(start))
		T.expect(string.match(Tourney.idOf(start), "^%d%d%d%d%d%d%d%d$") ~= nil).toBe(true)
	end)

	T.it("canSignup / canUnsign: level first, then the phase, then a signup of this tournament", function()
		local id = Tourney.idOf(start)
		T.expect({ Tourney.canSignup({ level = 19, phase = "signup", signed = nil, id = id }) }).toEqual({
			false,
			"tourney.error.level",
		})
		T.expect({ Tourney.canSignup({ level = 20, phase = "closed", signed = nil, id = id }) }).toEqual({
			false,
			"tourney.error.closed",
		})
		T.expect({ Tourney.canSignup({ level = 30, phase = "signup", signed = { id = id }, id = id }) }).toEqual({
			false,
			"tourney.error.already",
		})
		T.expect({ Tourney.canSignup({ level = 30, phase = "signup", signed = { id = "20000101" }, id = id }) })
			.toEqual({
				true,
				nil,
			})
		T.expect({ Tourney.canSignup({ level = 19, phase = "closed", signed = nil, id = id }) }).toEqual({
			false,
			"tourney.error.level",
		})
		T.expect({ Tourney.canUnsign({ phase = "inviting", signed = { id = id }, id = id }) }).toEqual({
			false,
			"tourney.error.closed",
		})
		T.expect({ Tourney.canUnsign({ phase = "signup", signed = nil, id = id }) }).toEqual({
			false,
			"tourney.error.notSigned",
		})
		T.expect({ Tourney.canUnsign({ phase = "signup", signed = { id = id }, id = id }) }).toEqual({ true, nil })
	end)

	T.it("brackets are the arena's", function()
		for _, level in { 20, 39, 40, 59, 60, 79, 80, 100 } do
			T.expect(Tourney.bracketOf(level)).toBe(ArenaRules.bracketOf(level))
		end
		T.expect(Tourney.bracketOf(19)).toBeNil()
		T.expect(Tourney.rangeOf("20_39")).toBe("20–39")
	end)

	T.it("the sort key: the higher rating first, then the earlier signup; clamped", function()
		T.expect(Tourney.sortKey(1500, 10) < Tourney.sortKey(1400, 0)).toBe(true)
		T.expect(Tourney.sortKey(1500, 5) < Tourney.sortKey(1500, 6)).toBe(true)
		T.expect(Tourney.sortKey(-50, -10)).toBe(Tourney.sortKey(0, 0))
		T.expect(Tourney.sortKey(20000, 20000)).toBe(Tourney.sortKey(9999, 9999))
	end)

	T.it("pick: all under the cap; above it the 32 best ratings, ties by the signup time", function()
		local small: { Tourney.Entry } = {}
		for i = 1, 10 do
			table.insert(small, { key = `{i}_1`, rating = 1000 + i, t = i, name = "x", class = "warrior" })
		end
		local picked, over, threshold = Tourney.pick(small, TOURNEY.cap)
		T.expect(#picked).toBe(10)
		T.expect(#over).toBe(0)
		T.expect(threshold).toBeNil()
		local many: { Tourney.Entry } = {}
		for i = 1, 40 do
			table.insert(many, { key = `{i}_1`, rating = 1000 + i * 10, t = 100 - i, name = "x", class = "warrior" })
		end
		-- a tie at the border: two with the 32nd rating, the earlier signup gets in
		table.insert(many, { key = "late_1", rating = 1000 + 9 * 10, t = 500, name = "x", class = "warrior" })
		local p2, o2, t2 = Tourney.pick(many, TOURNEY.cap)
		T.expect(#p2).toBe(32)
		T.expect(#o2).toBe(9)
		T.expect(p2[1].key).toBe("40_1")
		T.expect(t2).toBe(1000 + 9 * 10)
		T.expect(p2[32].key).toBe("9_1")
		T.expect(o2[1].key).toBe("late_1")
		T.expect(Tourney.seedOrder(many)[1]).toBe("40_1")
	end)

	T.it("rewards: the data and the contract 200 / 100 / 50 SO, 30 tokens, 7 days", function()
		local r1 = Tourney.rewardsFor(1, true)
		T.expect(r1).toEqual({
			shards = 200,
			tokens = 30,
			title = "tourney_champion",
			titleDays = 7,
			cosmetics = { "aura_champion" },
		})
		local r2 = Tourney.rewardsFor(2, true)
		T.expect({ r2.shards, r2.tokens, r2.cosmetics }).toEqual({ 100, 30, { "frame_tourney" } })
		local r3 = Tourney.rewardsFor(3, true)
		T.expect({ r3.shards, r3.tokens, r3.title }).toEqual({ 50, 30, nil })
		local r5 = Tourney.rewardsFor(5, true)
		T.expect({ r5.shards, r5.tokens, #r5.cosmetics }).toEqual({ 0, TOURNEY.participantTokens, 0 })
		local none = Tourney.rewardsFor(1, false)
		T.expect({ none.shards, none.tokens, none.title, #none.cosmetics }).toEqual({ 0, 0, nil, 0 })
		T.expect(TOURNEY.rewards[1].shards).toBe(200)
		T.expect(TOURNEY.rewards[2].shards).toBe(100)
		T.expect(TOURNEY.rewards[3].shards).toBe(50)
		T.expect(TOURNEY.participantTokens).toBe(30)
		T.expect(TOURNEY.rewards[1].titleDays).toBe(7)
	end)

	T.it("a signup of last week is stale on Wednesday; this week's is not while inviting", function()
		local last = Tourney.idOf(start - 7 * DAY)
		T.expect(Tourney.isStale({ id = last }, start + 4 * DAY)).toBe(true)
		T.expect(Tourney.isStale({ id = Tourney.idOf(start) }, start + w.organize + 10)).toBe(false)
		T.expect(Tourney.isStale(nil, start)).toBe(false)
		T.expect(Tourney.placeArg(1)).toBe("@tourney.place.1")
		T.expect(Tourney.placeArg(5)).toEqual({ key = "tourney.place.range", args = { from = 5, to = 8 } })
		T.expect(Tourney.roundKey(5, 5)).toBe("tourney.round.final")
		T.expect(Tourney.roundKey(1, 5)).toBe("tourney.round.r16")
		T.expect(Tourney.clockUtc(start)).toBe("19:00")
	end)
end)

T.describe("Tourney T3: data", function()
	T.it("the Saturday slot, overlapping no other event", function()
		T.expect(DEF.slots).toEqual({ { weekday = 6, hour = 19, minute = 0 } })
		T.expect(DEF.enabled).toBe(true)
		T.expect(DEF.blocksWorldEvents).toBe(false)
		T.expect(#DEF.warn).toBe(0)
		-- [start + open, start + duration) of the tournament against every other event's [start - quietBefore, end)
		local week = 3000
		for _, slot in DEF.slots do
			local s = Schedule.startOf(slot, week)
			local from, to = s + TOURNEY.window.open, s + DEF.duration
			for _, other in ScheduledEvents.list do
				if other.key ~= DEF.key then
					for _, os in other.slots do
						for w = week - 1, week + 1 do
							local o = Schedule.startOf(os, w)
							local oFrom, oTo = o - other.quietBefore, o + other.duration
							T.expect({ other.key, from < oTo and to > oFrom }).toEqual({ other.key, false })
						end
					end
				end
			end
		end
	end)

	T.it("TOURNEY: cap, minimum, the window, fields", function()
		T.expect(TOURNEY.cap).toBe(32)
		T.expect(TOURNEY.minPlayers).toBe(4)
		local w = TOURNEY.window
		T.expect(w.open < w.close and w.close < w.organize and w.organize < 0).toBe(true)
		T.expect(w.open).toBe(-3600)
		T.expect(w.close).toBe(-600)
		T.expect(w.organize).toBe(-300)
		T.expect(w.invite).toBe(120)
		T.expect(TOURNEY.fields).toBe(4)
		for i = 1, TOURNEY.fields do
			T.expect(Arena.venue(`pit_{i}`) ~= nil).toBe(true)
		end
	end)

	T.it("the aura, the frame and the timed title exist, with names", function()
		local aura = Cosmetics.get("aura_champion") :: Cosmetics.Def
		local frame = Cosmetics.get("frame_tourney") :: Cosmetics.Def
		T.expect(aura.kind).toBe("aura")
		T.expect(frame.kind).toBe("frame")
		for _, def in { aura, frame } do
			T.expect(def.obtain ~= nil).toBe(true)
			T.expect({ def.nameKey, pl[def.nameKey] ~= nil, en[def.nameKey] ~= nil })
				.toEqual({ def.nameKey, true, true })
		end
		local title = Titles.get("tourney_champion")
		T.expect(title ~= nil).toBe(true)
		T.expect((title :: any).req.kind).toBe("timed")
		T.expect(pl["title.tourney_champion"] ~= nil and en["title.tourney_champion"] ~= nil).toBe(true)
		T.expect(Titles.get("champion") ~= nil).toBe(true) -- the level 75 title stays
		for _, r in TOURNEY.rewards do
			if r.title then
				T.expect(Titles.get(r.title) ~= nil).toBe(true)
			end
			for _, id in r.cosmetics or {} do
				T.expect({ id, Cosmetics.get(id) ~= nil }).toEqual({ id, true })
			end
		end
	end)
end)

T.describe("Tourney T5: the server source", function()
	local function read(path: string): string
		return fs.readFile(path)
	end
	local SERVICE = "src/server/Services/TourneyService.luau"
	local function serverFiles(): { string }
		local out = { SERVICE }
		for _, name in fs.readDir("src/server/Tourney") do
			if string.match(name, "%.luau$") then
				table.insert(out, `src/server/Tourney/{name}`)
			end
		end
		return out
	end

	T.it("nothing reads purchases or VIP; no own registry of reserved servers", function()
		for _, path in serverFiles() do
			local source = read(path)
			for _, word in { "HasVip", "HasPass", "Data.Products", "Products.", "ps_" } do
				T.expect({ path, word, string.find(source, word, 1, true) ~= nil }).toEqual({ path, word, false })
			end
		end
	end)

	T.it("Roblox services in pcall with a fake; the registry, the claim and the elixir block are wired", function()
		for _, name in { "Store", "Bus" } do
			local source = read(`src/server/Tourney/{name}.luau`)
			T.expect({ name, string.find(source, "pcall(", 1, true) ~= nil }).toEqual({ name, true })
			T.expect({ name, string.find(source, "fake", 1, true) ~= nil }).toEqual({ name, true })
		end
		local hall = read("src/server/Tourney/Hall.luau")
		T.expect(string.find(hall, "KeyStore.new(", 1, true) ~= nil).toBe(true)
		local service = read(SERVICE)
		for _, needle in { "ServerMode.register(", 'ServerMode.claim("tournament"', 'UseGuards.register("tourney"' } do
			T.expect({ needle, string.find(service, needle, 1, true) ~= nil }).toEqual({ needle, true })
		end
		local runner = read("src/server/Tourney/Runner.luau")
		for _, needle in { "Bracket.report", "Bracket.withdraw(", "RunMatch(" } do
			T.expect({ needle, string.find(runner, needle, 1, true) ~= nil }).toEqual({ needle, true })
		end
		local logic = read("src/shared/Logic/Tourney.luau")
		T.expect(string.find(logic, "os.time", 1, true)).toBeNil()
		T.expect(string.find(logic, "os.date", 1, true)).toBeNil()
		local blocks = require("../src/shared/Logic/UseBlocks")
		T.expect(blocks.PENDING.tourney).toBeNil()
	end)
end)

T.describe("Tourney T6: the save", function()
	T.it("character.tourney from the template and reconcile, without a migration", function()
		T.expect(AccountSchema.CURRENT).toBe(8)
		local fresh = AccountSchema.characterTemplate()
		T.expect((fresh :: any).tourney).toEqual({ played = 0, won = 0, best = 0 })
		local old: any = AccountSchema.accountTemplate()
		old.characters["1"] = AccountSchema.characterTemplate()
		old.characters["1"].tourney = nil
		T.expect(AccountSchema.migrate(old)).toEqual({})
		T.expect(old.characters["1"].tourney).toEqual({ played = 0, won = 0, best = 0 })
		local kept: any = AccountSchema.accountTemplate()
		kept.characters["1"] = AccountSchema.characterTemplate()
		kept.characters["1"].tourney =
			{ signed = { id = "20261017", bracket = "40_59" }, played = 3, won = 1, best = 1 }
		AccountSchema.migrate(kept)
		T.expect(kept.characters["1"].tourney.played).toBe(3)
		T.expect(kept.characters["1"].tourney.signed).toEqual({ id = "20261017", bracket = "40_59" })
	end)
end)

return nil
