--!strict
-- S101b (DESIGN-15 §3.5): quest companions (Logic/Companion): which companion the quests want, the step machine of
-- `follow` and `lead` on flat points, the route, the data and the `escort` objective.

local Companion = require("../src/shared/Logic/Companion")
local Config = require("../src/shared/Config")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local SideQuests = require("../src/shared/Logic/SideQuests")
local Talk = require("../src/shared/Data/Quests/Talk")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local C = Config.Companion

local function quests(fields: { [string]: any }?): any
	local out: any = {
		main = nil,
		mainDone = 0,
		daily = { day = 0, list = {}, rerolls = 0 },
		side = { active = {}, done = {} },
		said = {},
	}
	for key, value in fields or {} do
		out[key] = value
	end
	return out
end

-- A story quest led by Mira along a road to (100, 0) through (50, 0), after a talk objective outside `during`.
local LEAD: any = {
	id = "test_lead",
	level = 5,
	giver = "scout_meadows",
	turnIn = "scout_meadows",
	objectives = {
		{ type = "talk", n = 1, npc = "scout_meadows" },
		Talk.escort("scout_meadows", "meadows", 100, 0, 8, "area.meadows_toadmire", { { x = 50, z = 0 } }),
	},
	reward = { exp = 1, gold = 1 },
	companion = Talk.lead("scout_meadows", "meadows", { 2 }, { join = 1, wait = 1, arrive = 1 }, { x = 0, z = 0 }),
}

-- A side quest followed by Borys through three objectives; the first one outside `during`.
local FOLLOW: any = {
	id = "test_follow",
	level = 5,
	giver = "hunter_borys",
	turnIn = "hunter_borys",
	arc = "ravine",
	pages = 1,
	objectives = {
		{ type = "kill", n = 1, monster = "rabbit" },
		{ type = "kill", n = 2, monster = "wolf" },
		{ type = "kill", n = 2, monster = "boar" },
	},
	reward = { exp = 1, gold = 1 },
	companion = Talk.follow("hunter_borys", "meadows", { 2, 3 }),
}

local SOURCE: Companion.Source = {
	main = function(id: string): any
		return if id == LEAD.id then LEAD else nil
	end,
	side = { FOLLOW },
}

describe("Companion.want (S101b T6)", function()
	it("the story before side quests, at most one", function()
		local both = quests({
			main = { id = "test_lead", progress = { 1, 0 } },
			side = { active = { test_follow = { progress = { 1, 0, 0 }, used = {} } }, done = {} },
		})
		local want = assert(Companion.want(both, 5, SOURCE))
		expect(want.quest).toBe("test_lead")
		expect(want.kind).toBe("main")
		expect(want.objective).toBe(2)
		-- the story's objective before `during` still open: the side quest's companion
		local early = quests({
			main = { id = "test_lead", progress = { 0, 0 } },
			side = { active = { test_follow = { progress = { 1, 0, 0 }, used = {} } }, done = {} },
		})
		local other = assert(Companion.want(early, 5, SOURCE))
		expect(other.quest).toBe("test_follow")
		expect(other.def.npc).toBe("hunter_borys")
	end)

	it("only while an open objective of `during` comes first (focus may skip within `during`)", function()
		local function want(progress: { number }): string?
			local w = Companion.want(
				quests({ side = { active = { test_follow = { progress = progress, used = {} } }, done = {} } }),
				5,
				SOURCE
			)
			return if w then `{w.quest}#{w.objective}` else nil
		end
		expect(want({ 0, 0, 0 })).toBeNil()
		expect(want({ 1, 0, 0 })).toBe("test_follow#2")
		expect(want({ 1, 2, 0 })).toBe("test_follow#3")
		expect(want({ 1, 0, 2 })).toBe("test_follow#2")
		expect(want({ 1, 2, 2 })).toBeNil()
		expect(Companion.want(nil, 5, SOURCE)).toBeNil()
	end)

	it("Borys walks with the player through side_den until both objectives are done", function()
		local function want(progress: { number }): string?
			local w = Companion.want(
				quests({ side = { active = { side_den = { progress = progress, used = {} } }, done = {} } }),
				19
			)
			return if w then w.def.npc else nil
		end
		expect(want({ 0, 0 })).toBe("hunter_borys")
		expect(want({ 1, 3 })).toBe("hunter_borys")
		expect(want({ 0, 6 })).toBe("hunter_borys")
		expect(want({ 1, 6 })).toBeNil()
		expect(Companion.want(quests(), 19)).toBeNil()
	end)
end)

-- One step with defaults.
local function input(fields: { [string]: any }): Companion.Input
	local out: any = {
		figure = { x = 0, z = 0 },
		player = { x = 0, z = 0 },
		alive = true,
		sameMap = true,
		moved = 1,
		inCombat = false,
		now = 0,
	}
	for key, value in fields do
		out[key] = value
	end
	if out.figure == false then
		out.figure = nil -- `figure = false` in a test: no figure
	end
	return out
end

local function followState(): Companion.State
	local state = Companion.newState(FOLLOW.companion, { x = 0, z = 0 }, nil)
	local s = Companion.step(state, input({}))
	expect(s.phase).toBe("follow")
	return s
end

local function leadState(): Companion.State
	local objective = Companion.escortOf(LEAD)
	local state = Companion.newState(LEAD.companion, { x = 0, z = 0 }, objective)
	local s = Companion.step(state, input({}))
	expect(s.phase).toBe("lead")
	return s
end

describe("Companion.step: follow (S101b T7)", function()
	it("stands near the player, walks once they are farther than walkFrom", function()
		local s = followState()
		local s1, a1 = Companion.step(s, input({ player = { x = C.walkFrom - 1, z = 0 }, now = 1 }))
		expect(a1.kind).toBe("stand")
		local s2, a2 = Companion.step(s1, input({ player = { x = C.walkFrom + 2, z = 0 }, now = 2 }))
		expect(a2.kind).toBe("walk")
		local to = assert(a2.to, "expected a value")
		expect(to.x).toBeNear(C.walkFrom + 2 - C.followDist, 1e-6)
		-- arrived at followDist: stands again
		local _, a3 = Companion.step(
			s2,
			input({
				figure = { x = C.walkFrom + 2 - C.followDist, z = 0 },
				player = { x = C.walkFrom + 2, z = 0 },
				now = 3,
			})
		)
		expect(a3.kind).toBe("stand")
	end)

	it("teleports past catchUp and after stuckSeconds without moving", function()
		local s = followState()
		local _, far = Companion.step(s, input({ player = { x = C.catchUp + 10, z = 0 }, now = 1 }))
		expect(far.kind).toBe("teleport")
		expect((assert(far.to, "expected a value")).x).toBeNear(C.catchUp + 10 - C.followDist, 1e-6)
		local state = s
		local action: Companion.Action = { kind = "stand" }
		local t = 1
		local teleported = false
		for _ = 1, 20 do
			state, action = Companion.step(state, input({ player = { x = 20, z = 0 }, moved = 0, now = t }))
			t += 0.5
			if action.kind == "teleport" then
				teleported = true
				break
			end
		end
		expect(teleported).toBe(true)
	end)

	it("stands while the player fights; hurries (wait) past waitDist", function()
		local s = followState()
		local _, fight = Companion.step(s, input({ player = { x = 20, z = 0 }, inCombat = true, now = 1 }))
		expect(fight.kind).toBe("stand")
		local lag, walk = Companion.step(s, input({ player = { x = C.waitDist + 5, z = 0 }, now = 1 }))
		expect(lag.phase).toBe("wait")
		expect(walk.kind).toBe("walk")
		local back = Companion.step(lag, input({ player = { x = 2, z = 0 }, now = 2 }))
		expect(back.phase).toBe("follow")
	end)

	it("after the player's death it appears next to them", function()
		local s = followState()
		local dead, a1 = Companion.step(s, input({ alive = false, player = { x = 30, z = 0 }, now = 1 }))
		expect(a1.kind).toBe("stand")
		local _, a2 = Companion.step(dead, input({ player = { x = 40, z = 0 }, now = 5 }))
		expect(a2.kind).toBe("teleport")
	end)

	it("a map change sends it away; back on the map it joins next to the player", function()
		local s = followState()
		local gone, a1 = Companion.step(s, input({ sameMap = false, now = 1 }))
		expect(gone.phase).toBe("back")
		expect(a1.kind).toBe("despawn")
		local still, a2 = Companion.step(gone, input({ sameMap = false, figure = false, now = 2 }))
		expect(still.phase).toBe("back")
		expect(a2.kind).toBe("stand")
		local joined, a3 = Companion.step(gone, input({ figure = false, player = { x = 500, z = 0 }, now = 3 }))
		expect(joined.phase).toBe("join")
		expect(a3.kind).toBe("spawn")
		expect((assert(a3.to, "expected a value")).x).toBeNear(500 - C.followDist, 1e-6)
		-- near its start it appears there
		local _, a4 = Companion.step(gone, input({ figure = false, player = { x = 10, z = 0 }, now = 3 }))
		expect((assert(a4.to, "expected a value")).x).toBe(0)
	end)

	it("once its objectives are done it walks back to its start and goes", function()
		local s = followState()
		local done, a1 = Companion.step(s, input({ finished = true, figure = { x = 40, z = 0 }, now = 1 }))
		expect(done.phase).toBe("arrived")
		expect(a1.kind).toBe("stand")
		local _, a2 = Companion.step(done, input({ figure = { x = 40, z = 0 }, now = 2 }))
		expect(a2.kind).toBe("walk")
		local _, a3 = Companion.step(done, input({ figure = { x = 40, z = 0 }, now = 1 + C.arriveLinger }))
		expect(a3.kind).toBe("despawn")
	end)
end)

describe("Companion.step: lead (S101b T7)", function()
	it("the route is the start, the waypoints and the goal", function()
		local objective = Companion.escortOf(LEAD)
		local route = Companion.route(LEAD.companion, objective, { x = 0, z = 0 })
		expect(#route).toBe(3)
		expect(route[2].x).toBe(50)
		expect(route[3].x).toBe(100)
		expect(#Companion.route(FOLLOW.companion, nil, { x = 0, z = 0 })).toBe(0)
	end)

	it("walks the route, waits for the player and walks on when they come close", function()
		local s = leadState()
		local s1, a1 = Companion.step(s, input({ player = { x = 2, z = 0 }, now = 1 }))
		expect(a1.kind).toBe("walk")
		expect((assert(a1.to, "expected a value")).x).toBeNear(C.lookAhead, 1e-6)
		local waiting, a2 =
			Companion.step(s1, input({ figure = { x = 40, z = 0 }, player = { x = 0, z = 0 }, now = 2 }))
		expect(waiting.phase).toBe("wait")
		expect(a2.kind).toBe("stand")
		local still =
			Companion.step(waiting, input({ figure = { x = 40, z = 0 }, player = { x = 20, z = 0 }, now = 3 }))
		expect(still.phase).toBe("wait")
		local going, a3 =
			Companion.step(waiting, input({ figure = { x = 40, z = 0 }, player = { x = 30, z = 0 }, now = 4 }))
		expect(going.phase).toBe("lead")
		expect(a3.kind).toBe("walk")
	end)

	it("arrives only with the player near, then goes after arriveLinger", function()
		local s = leadState()
		local alone = Companion.step(s, input({ figure = { x = 96, z = 0 }, player = { x = 60, z = 0 }, now = 1 }))
		expect(alone.phase).toBe("wait")
		local there, a1 = Companion.step(s, input({ figure = { x = 96, z = 0 }, player = { x = 90, z = 0 }, now = 1 }))
		expect(there.phase).toBe("arrived")
		expect(a1.kind).toBe("arrived")
		local _, a2 = Companion.step(there, input({ figure = { x = 96, z = 0 }, player = { x = 90, z = 0 }, now = 2 }))
		expect(a2.kind).toBe("stand")
		local _, a3 = Companion.step(there, input({ now = 1 + C.arriveLinger }))
		expect(a3.kind).toBe("despawn")
	end)

	it("the player's death or getting lost sends it back; the route starts again at its start", function()
		local s = leadState()
		local back, a1 = Companion.step(s, input({ alive = false, now = 1 }))
		expect(back.phase).toBe("back")
		expect(a1.kind).toBe("reset")
		local _, wait = Companion.step(back, input({ figure = false, player = { x = 60, z = 0 }, now = 2 }))
		expect(wait.kind).toBe("stand")
		local again, spawn =
			Companion.step(back, input({ figure = false, player = { x = C.rejoin - 1, z = 0 }, now = 3 }))
		expect(again.phase).toBe("join")
		expect(spawn.kind).toBe("spawn")
		expect((assert(spawn.to, "expected a value")).x).toBe(0)
		-- lost: farther than failDist for failSeconds
		local state = s
		local action: Companion.Action = { kind = "stand" }
		local t = 1
		while t < C.failSeconds + 5 and action.kind ~= "reset" do
			state, action = Companion.step(state, input({ player = { x = C.failDist + 50, z = 0 }, now = t }))
			t += 1
		end
		expect(action.kind).toBe("reset")
		expect(state.phase).toBe("back")
		expect(t - 1 >= C.failSeconds).toBe(true)
	end)

	it("without a figure the escort counts when the player reaches the goal", function()
		local s = leadState()
		local _, a1 = Companion.step(s, input({ figure = false, player = { x = 50, z = 0 }, now = 1 }))
		expect(a1.kind).toBe("stand")
		local arrived, a2 = Companion.step(s, input({ figure = false, player = { x = 97, z = 0 }, now = 1 }))
		expect(arrived.phase).toBe("arrived")
		expect(a2.kind).toBe("arrived")
	end)

	it("a map change sends it away", function()
		local s = leadState()
		local gone, a1 = Companion.step(s, input({ sameMap = false, now = 1 }))
		expect(gone.phase).toBe("back")
		expect(a1.kind).toBe("despawn")
	end)
end)

describe("Companion data and the escort objective (S101b T8)", function()
	it("the data is valid", function()
		expect(Companion.validate()).toEqual({})
		expect(Companion.validate({ LEAD, FOLLOW })).toEqual({})
	end)

	it("the validator catches broken companions", function()
		local noEscort: any = table.clone(LEAD)
		noEscort.objectives = { LEAD.objectives[1] }
		noEscort.companion = Talk.lead("scout_meadows", "meadows", { 1 }, nil, { x = 0, z = 0 })
		expect(#Companion.validate({ noEscort }) >= 1).toBe(true)
		local wrongNpc: any = table.clone(LEAD)
		wrongNpc.companion = Talk.lead("hunter_borys", "meadows", { 2 }, nil, { x = 0, z = 0 })
		expect(#Companion.validate({ wrongNpc })).toBe(1)
		local followEscort: any = table.clone(LEAD)
		followEscort.companion = Talk.follow("scout_meadows", "meadows", { 2 }, nil, { x = 0, z = 0 })
		expect(#Companion.validate({ followEscort })).toBe(1)
		local stray: any = table.clone(LEAD)
		stray.companion = nil
		expect(#Companion.validate({ stray })).toBe(1)
		local offMap: any = table.clone(FOLLOW)
		offMap.companion = Talk.follow("captain", "meadows", { 2 })
		expect(#Companion.validate({ offMap })).toBe(1)
		local badDuring: any = table.clone(FOLLOW)
		badDuring.companion = Talk.follow("hunter_borys", "meadows", { 4 }, { join = 9 })
		expect(#Companion.validate({ badDuring })).toBe(2)
	end)

	it("escort counts for the companion's NPC only", function()
		local objective = LEAD.objectives[2]
		expect(QuestLogic.amount(objective, "escort", { npc = "scout_meadows" }, 0)).toBe(1)
		expect(QuestLogic.amount(objective, "escort", { npc = "hunter_borys" }, 0)).toBe(0)
		expect(QuestLogic.amount(objective, "talk", { npc = "scout_meadows" }, 0)).toBe(0)
		local progress = { 1, 0 }
		local changed = QuestLogic.advance(progress, LEAD.objectives, "escort", { npc = "scout_meadows" }, Rng.new(1))
		expect(changed).toEqual({ 2 })
		expect(QuestLogic.isComplete(progress, LEAD.objectives)).toBe(true)
		-- a side quest with an escort objective
		local side: any = table.clone(FOLLOW)
		side.objectives = { LEAD.objectives[2] }
		local entry = SideQuests.newEntry(side)
		expect(SideQuests.advance(entry, side, "escort", { npc = "scout_meadows" }, Rng.new(1))).toEqual({ 1 })
		expect(SideQuests.isComplete(entry, side)).toBe(true)
	end)

	it("side_den keeps its objectives (no escort: progress of running quests and the ledger stay)", function()
		local den = assert(Quests.Side.get("side_den"))
		expect(#den.objectives).toBe(2)
		expect(den.objectives[1].type).toBe("use")
		expect(den.objectives[2].type).toBe("kill")
		local def = assert(den.companion, "expected a value")
		expect(def.mode).toBe("follow")
		expect(Companion.fromOf(def) ~= nil).toBe(true)
	end)

	it("speeds: following at least the player's walk, at most twice", function()
		local Stats = require("../src/shared/Data/Stats")
		local walk = (Stats :: any).Formula.walkSpeed
		expect(C.speedFollow >= walk).toBe(true)
		expect(C.speedFollow <= 2 * walk).toBe(true)
		expect(C.resumeDist < C.waitDist).toBe(true)
		expect(C.followDist < C.walkFrom).toBe(true)
		expect(C.catchUp < C.failDist).toBe(true)
	end)
end)

describe("Companions of story chapter I (S102 T12)", function()
	it(
		"frostSign route: Dobiesław leads from the guardhouse to the temple, every waypoint free, legs <= legMax",
		function()
			local TownPlaces = require("../src/shared/Logic/TownPlaces")
			local quest = assert(Quests.Main.get("frostSign"))
			local def = assert(quest.companion, "companion")
			expect(def.npc).toBe("sergeant")
			expect(def.mode).toBe("lead")
			local escort = quest.objectives[2]
			expect(escort.type).toBe("escort")
			local route = Companion.route(def, escort, assert(Companion.fromOf(def), "from"))
			expect(#route >= 3).toBe(true)
			for i, point in route do
				if i > 1 then
					-- the start is the sergeant's own place in the guardhouse
					expect(`{point.x},{point.z} {TownPlaces.isFree(point.x, point.z)}`).toBe(`{point.x},{point.z} true`)
					local prev = route[i - 1]
					local leg = math.sqrt((point.x - prev.x) ^ 2 + (point.z - prev.z) ^ 2)
					expect(leg <= C.legMax).toBe(true)
				end
			end
			local function want(progress: { number }): any
				return Companion.want(quests({ main = { id = "frostSign", progress = progress } }))
			end
			local w = want({ 1, 0, 0 })
			expect(w and w.def.npc).toBe("sergeant")
			expect(w and w.objective).toBe(2)
			expect(want({ 0, 0, 0 })).toBeNil()
			expect(want({ 1, 1, 0 })).toBeNil()
		end
	)

	it("frostRuins: Mira follows during the objectives 1 and 2", function()
		local function want(progress: { number }): any
			return Companion.want(quests({ main = { id = "frostRuins", progress = progress } }))
		end
		for _, progress in { { 0, 0, 0 }, { 1, 0, 0 } } do
			local w = want(progress)
			expect(w and w.def.npc).toBe("scout_meadows")
			expect(w and w.def.mode).toBe("follow")
		end
		expect(want({ 1, 1, 0 })).toBeNil()
	end)
end)

describe("Companions of story chapter II (S103)", function()
	local MapTerrain = require("../src/shared/Logic/MapTerrain")
	local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
	local T = assert(RegionTerrain.get("duskwood"))

	it("lostHunters: Radomir's route through Duskwood is walkable, dry and in legs of at most legMax", function()
		local quest = assert(Quests.Main.get("lostHunters"))
		local def = assert(quest.companion, "companion")
		local escort = assert(Companion.escortOf(quest))
		local start = assert(Companion.fromOf(def))
		local route = Companion.route(def, escort, start)
		expect(#route >= 3).toBe(true)
		for i, point in route do
			expect(`{i} {MapTerrain.walkable("duskwood", point.x, point.z, 4)}`).toBe(`{i} true`)
			expect(T.water(point.x, point.z)).toBeNil()
			if i > 1 then
				local before = route[i - 1]
				local leg = math.sqrt((point.x - before.x) ^ 2 + (point.z - before.z) ^ 2)
				expect(leg <= Config.Companion.legMax).toBe(true)
			end
		end
		-- the goal before the lost camp, 12+ studs from its anchor
		local Areas = require("../src/shared/Data/Areas")
		local anchor = assert(Areas.anchorById("lost_camp"))
		local gx, gz = escort.x :: number, escort.z :: number
		expect(math.sqrt((gx - anchor.x) ^ 2 + (gz - anchor.z) ^ 2) >= 12).toBe(true)
		expect(Companion.validate()).toEqual({})
	end)

	it("witchCounsel: Ragna joins at her place by the stilt village and follows during the marsh objectives", function()
		local quest = assert(Quests.Main.get("witchCounsel"))
		local def = assert(quest.companion, "companion")
		local from = assert(Companion.fromOf(def))
		local npc = assert(require("../src/shared/Data/Npcs").get("witch_ragna"))
		expect(from.x).toBe(npc.position.x)
		expect(from.z).toBe(npc.position.z)
		expect(quest.objectives[2].area).toBe("duskwood_witchmarsh")
		expect(quest.objectives[3].area).toBe("duskwood_witchmarsh")
	end)
end)

describe("Companions of story chapter III (S104)", function()
	local MapTerrain = require("../src/shared/Logic/MapTerrain")
	local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
	local Areas = require("../src/shared/Data/Areas")
	local T = assert(RegionTerrain.get("ashen"))

	it("deadOasis: Brokk's route to his caravan is walkable, dry, away from lava, legs <= legMax", function()
		local quest = assert(Quests.Main.get("deadOasis"))
		local def = assert(quest.companion, "companion")
		local escort = assert(Companion.escortOf(quest))
		local start = assert(Companion.fromOf(def))
		local npc = assert(require("../src/shared/Data/Npcs").get("runesmith_brokk"))
		expect(start.x).toBe(npc.position.x)
		expect(start.z).toBe(npc.position.z)
		local route = Companion.route(def, escort, start)
		expect(#route >= 3).toBe(true)
		for i, point in route do
			expect(`{i} {MapTerrain.walkable("ashen", point.x, point.z, 4)}`).toBe(`{i} true`)
			expect(T.isWater(point.x, point.z)).toBe(false)
			expect(T.lavaDistance(point.x, point.z) >= RegionTerrain.LAVA_CLEARANCE).toBe(true)
			for _, lake in Areas.byMap.ashen.lakes do
				expect(math.sqrt((point.x - lake.x) ^ 2 + (point.z - lake.z) ^ 2) > lake.r).toBe(true)
			end
			if i > 1 then
				local before = route[i - 1]
				local leg = math.sqrt((point.x - before.x) ^ 2 + (point.z - before.z) ^ 2)
				expect(leg <= Config.Companion.legMax).toBe(true)
			end
		end
		-- the goal lies in the caravan graveyard's avoid circle (no monster group there)
		local grave = assert(Areas.byMap.ashen.sites).caravanGrave
		local gx, gz = escort.x :: number, escort.z :: number
		expect(math.sqrt((gx - grave.x) ^ 2 + (gz - grave.z) ^ 2) <= 34 - 2).toBe(true)
		expect(Companion.validate()).toEqual({})
	end)

	it("forgeChains: Brokk joins by the cave's respawn point on the cave floor and follows the posts", function()
		local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
		local Maps = require("../src/shared/Data/Maps")
		local quest = assert(Quests.Main.get("forgeChains"))
		local def = assert(quest.companion, "companion")
		local from = assert(Companion.fromOf(def))
		local cave = assert(CaveTerrain.get("ashen_cave"))
		expect(cave.floor(from.x, from.z) ~= nil).toBe(true)
		expect(cave.liquid(from.x, from.z)).toBeNil()
		local spawn = assert(Maps.get("ashen_cave")).spawn
		expect(math.sqrt((from.x - spawn.x) ^ 2 + (from.z - spawn.z) ^ 2) <= Config.Companion.rejoin).toBe(true)
		local function want(progress: { number }): any
			return Companion.want(quests({ main = { id = "forgeChains", progress = progress } }))
		end
		local w = want({ 1, 0 })
		expect(w and w.def.npc).toBe("runesmith_brokk")
		expect(want({ 3, 0 })).toBeNil()
	end)
end)
