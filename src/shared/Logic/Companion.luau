--!strict
-- Quest companions (S101b, DESIGN-15 §3.5). Pure (Lune tests); CompanionService runs it on the server. A quest with
-- `companion` has an NPC walk with the player while one of the objectives of `during` is the current one: `follow`
-- (stays next to the player, hurries after them, never fights) or `lead` (walks the route of the quest's `escort`
-- objective, waits for the player and counts the objective when both arrive). At most one companion at a time (the
-- story before side quests); one map. Failing (the player dead or lost while led) sends it back to its start; it
-- never dies. Positions are map-relative flat points (y = 0).

local CavePlan = require("./CavePlan")
local Config = require("../Config")
local Locale = require("../Util/Locale")
local Maps = require("../Data/Maps")
local NavPath = require("./NavPath")
local Npcs = require("../Data/Npcs")
local Quests = require("../Data/Quests")
local SideQuests = require("./SideQuests")

type CompanionDef = Quests.CompanionDef
type Objective = Quests.Objective

export type Point = NavPath.Point
export type Flat = { x: number, z: number }
export type Kind = "main" | "side"
export type Want = { quest: string, kind: Kind, def: CompanionDef, objective: number }
export type Phase = "join" | "follow" | "lead" | "wait" | "arrived" | "back"

export type State = {
	mode: "follow" | "lead",
	phase: Phase,
	from: Flat, -- where it joins and goes back to
	route: { Point }, -- lead: the way to the goal (start, via, goal; CompanionService swaps in the pathfound one)
	goal: { x: number, z: number, radius: number }?, -- lead: the escort objective's place
	segment: number, -- lead: route segment reached (NavPath.progress)
	walking: boolean,
	stillFor: number, -- seconds walking without moving
	farFor: number, -- lead: seconds with the player past failDist
	arrivedAt: number?,
	waitingDead: boolean, -- follow: the player died, show up next to them after the respawn
	lastNow: number?,
}

export type Input = {
	figure: Flat?, -- nil = no figure (gone back, or none could be built)
	player: Flat,
	alive: boolean,
	sameMap: boolean,
	moved: number, -- studs the figure moved since the last step
	inCombat: boolean,
	now: number,
	finished: boolean?, -- every objective of `during` is done while the quest is still active (the follow end)
}

export type ActionKind = "walk" | "stand" | "teleport" | "arrived" | "reset" | "despawn" | "spawn"
export type Action = { kind: ActionKind, to: Point? }

local Companion = {}

local STILL = 0.3 -- studs per step under which a walking figure counts as not moving

local function flat(x: number, z: number): Point
	return { x = x, y = 0, z = z }
end

local function distance(a: Flat, b: Flat): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- A point `dist` studs from `centre` towards `other` (straight east when they coincide).
function Companion.toward(centre: Flat, other: Flat, dist: number): Point
	local dx, dz = other.x - centre.x, other.z - centre.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-6 then
		return flat(centre.x + dist, centre.z)
	end
	return flat(centre.x + dx / length * dist, centre.z + dz / length * dist)
end

-- The first open objective of `during`, while every earlier objective outside `during` is done; nil otherwise
-- (also when the quest is complete). With `focus` the player may work on a later objective of `during` first.
function Companion.openIn(def: CompanionDef, objectives: { Objective }, progress: { number }?): number?
	for i, objective in objectives do
		local open = ((progress or {})[i] or 0) < objective.n
		if open then
			if table.find(def.during, i) then
				return i
			end
			return nil
		end
	end
	return nil
end

-- Whether every objective of `during` is done.
function Companion.duringDone(def: CompanionDef, objectives: { Objective }, progress: { number }?): boolean
	for _, i in def.during do
		local objective = objectives[i]
		if objective and ((progress or {})[i] or 0) < objective.n then
			return false
		end
	end
	return true
end

-- Quest lists `want` looks in (tests pass their own).
export type Source = { main: (id: string) -> any, side: { any } }

local DATA: Source = {
	main = function(id: string): any
		return Quests.Main.get(id)
	end,
	side = Quests.npcList :: { any },
}

-- The companion the character's quests want now (story first, then side quests in Quests.npcList order), or nil.
function Companion.want(quests: any, _level: number?, source: Source?): Want?
	if type(quests) ~= "table" then
		return nil
	end
	local lists = source or DATA
	local main = quests.main
	if type(main) == "table" and type(main.id) == "string" then
		local quest = lists.main(main.id)
		local def = quest and quest.companion
		if quest and def then
			local index = Companion.openIn(def, quest.objectives, main.progress)
			if index then
				return { quest = quest.id, kind = "main", def = def, objective = index }
			end
		end
	end
	local active = SideQuests.activeOf(quests)
	for _, quest in lists.side do
		local entry = active[quest.id]
		local def = quest.companion
		if def and type(entry) == "table" then
			local index = Companion.openIn(def, quest.objectives, entry.progress)
			if index then
				return { quest = quest.id, kind = "side", def = def, objective = index }
			end
		end
	end
	return nil
end

-- The escort objective of a leading companion's quest (one of `during`) and its index.
function Companion.escortOf(quest: any): (Objective?, number?)
	local def = quest.companion
	if not def then
		return nil, nil
	end
	for _, i in def.during do
		local objective = quest.objectives[i]
		if objective and objective.type == "escort" then
			return objective, i
		end
	end
	return nil, nil
end

-- Where the companion joins: `from`, else the NPC's own place when it stands on the companion's map.
function Companion.fromOf(def: CompanionDef): Flat?
	if def.from then
		-- S134h: authored in plan units; a cave map is drawn scaled (Logic/CavePlan)
		local x, z = CavePlan.point(def.map, def.from.x, def.from.z)
		return { x = x, z = z }
	end
	local npc = Npcs.get(def.npc)
	if npc and npc.map == def.map then
		return { x = npc.position.x, z = npc.position.z }
	end
	return nil
end

-- The way a leading companion walks: start, the escort's `via`, the goal (flat points); empty for `follow`.
function Companion.route(def: CompanionDef, objective: Objective?, start: Flat): { Point }
	if def.mode ~= "lead" or not objective or not objective.x or not objective.z then
		return {}
	end
	local out: { Point } = { flat(start.x, start.z) }
	local via: { { x: number, z: number } } = objective.via or {}
	for _, point in via do
		table.insert(out, flat(point.x, point.z))
	end
	table.insert(out, flat(objective.x, objective.z))
	return out
end

-- A fresh state at the join (phase "join").
function Companion.newState(def: CompanionDef, from: Flat, objective: Objective?): State
	local goal = if def.mode == "lead"
			and objective
			and objective.x
			and objective.z
		then { x = objective.x, z = objective.z, radius = objective.radius or 20 }
		else nil
	return {
		mode = def.mode,
		phase = "join",
		from = { x = from.x, z = from.z },
		route = Companion.route(def, objective, from),
		goal = goal,
		segment = 1,
		walking = false,
		stillFor = 0,
		farFor = 0,
		arrivedAt = nil,
		waitingDead = false,
		lastNow = nil,
	}
end

-- Where the figure appears: a leading companion at its start; a following one at its start when the player is within
-- `catchUp` of it, else next to the player.
function Companion.spawnPoint(state: State, player: Flat): Point
	if state.mode == "lead" or distance(state.from, player) <= Config.Companion.catchUp then
		return flat(state.from.x, state.from.z)
	end
	return Companion.toward(player, state.from, Config.Companion.followDist)
end

local function copy(state: State): State
	local out = table.clone(state)
	out.from = table.clone(state.from)
	return out
end

local function act(kind: ActionKind, to: Point?): Action
	return { kind = kind, to = to }
end

-- Back to the start (gone): the route starts again when the player comes back within `rejoin` of it.
local function goBack(s: State): (State, Action)
	s.phase = "back"
	s.walking = false
	s.stillFor = 0
	s.farFor = 0
	s.segment = 1
	s.waitingDead = false
	return s, act("reset")
end

local function stepFollow(s: State, input: Input, figure: Flat, dt: number): (State, Action)
	local c = Config.Companion
	if not input.alive then
		s.waitingDead = true
		s.walking = false
		return s, act("stand")
	end
	if s.waitingDead then
		s.waitingDead = false
		s.walking = false
		s.stillFor = 0
		return s, act("teleport", Companion.toward(input.player, figure, c.followDist))
	end
	local d = distance(figure, input.player)
	if d > c.waitDist then
		s.phase = "wait" -- hurrying after the player
	elseif d < c.resumeDist then
		s.phase = "follow"
	end
	if d > c.catchUp then
		s.walking = false
		s.stillFor = 0
		s.phase = "follow"
		return s, act("teleport", Companion.toward(input.player, figure, c.followDist))
	end
	if input.inCombat then
		s.walking = false
		s.stillFor = 0
		return s, act("stand")
	end
	if s.walking and d <= c.followDist then
		s.walking = false
	elseif not s.walking and d > c.walkFrom then
		s.walking = true
		s.stillFor = 0
	end
	if not s.walking then
		s.stillFor = 0
		return s, act("stand")
	end
	if input.moved < STILL then
		s.stillFor += dt
		if s.stillFor >= c.stuckSeconds then
			s.stillFor = 0
			s.walking = false
			return s, act("teleport", Companion.toward(input.player, figure, c.followDist))
		end
	else
		s.stillFor = 0
	end
	return s, act("walk", Companion.toward(input.player, figure, c.followDist))
end

local function stepLead(s: State, input: Input, figure: Flat?, dt: number): (State, Action)
	local c = Config.Companion
	if not input.alive then
		return goBack(s)
	end
	local goal = s.goal
	if not figure then
		-- no figure could be built: the escort counts when the player reaches the goal alone (CompanionService)
		if goal and distance(input.player, goal) <= goal.radius then
			s.phase = "arrived"
			s.arrivedAt = input.now
			return s, act("arrived")
		end
		return s, act("stand")
	end
	local d = distance(figure, input.player)
	if d > c.failDist then
		s.farFor += dt
		if s.farFor >= c.failSeconds then
			return goBack(s)
		end
	else
		s.farFor = 0
	end
	if goal and distance(figure, goal) <= goal.radius and d <= c.waitDist then
		s.phase = "arrived"
		s.arrivedAt = input.now
		s.walking = false
		return s, act("arrived")
	end
	if s.phase ~= "wait" and d > c.waitDist then
		s.phase = "wait"
	elseif s.phase == "wait" and d < c.resumeDist then
		s.phase = "lead"
	end
	if s.phase == "wait" or input.inCombat or #s.route == 0 then
		s.walking = false
		s.stillFor = 0
		return s, act("stand")
	end
	local here: Point = flat(figure.x, figure.z)
	local progress = NavPath.progress(s.route, here, s.segment)
	s.segment = progress.segment
	if progress.remaining < 1 then
		s.walking = false
		return s, act("stand")
	end
	s.walking = true
	if input.moved < STILL then
		s.stillFor += dt
		if s.stillFor >= c.stuckSeconds then
			s.stillFor = 0
			local point = NavPath.at(s.route, progress.along + c.lookAhead)
			return s, act("teleport", flat(point.x, point.z))
		end
	else
		s.stillFor = 0
	end
	local point = NavPath.at(s.route, progress.along + c.lookAhead)
	return s, act("walk", flat(point.x, point.z))
end

-- One step of the companion. Phases: join (the first step), follow, lead, wait (lead: waiting for the player;
-- follow: hurrying after them), arrived (staying `arriveLinger` seconds, a follower walks back to its start), back
-- (gone; follow: the player left the map; lead: the player died or got lost). Actions: walk / teleport (point), stand,
-- arrived (fire the escort event), reset (back to the start: remove the figure), despawn (remove the figure), spawn
-- (the figure appears at the point).
function Companion.step(state: State, input: Input): (State, Action)
	local s = copy(state)
	local dt = if s.lastNow then math.max(0, input.now - s.lastNow) else 0
	s.lastNow = input.now
	local c = Config.Companion
	if s.phase == "arrived" then
		if not s.arrivedAt then
			s.arrivedAt = input.now
		end
		if input.now - (s.arrivedAt :: number) >= c.arriveLinger or not input.sameMap then
			return s, act("despawn")
		end
		if s.mode == "follow" and input.figure and distance(input.figure, s.from) > c.followDist then
			return s, act("walk", flat(s.from.x, s.from.z))
		end
		return s, act("stand")
	end
	if not input.sameMap then
		if s.phase == "back" then
			return s, act("stand")
		end
		s.phase = "back"
		s.walking = false
		s.segment = 1
		s.farFor = 0
		s.waitingDead = false
		return s, act("despawn")
	end
	if s.phase == "back" then
		local ready = if s.mode == "follow"
			then input.alive
			else input.alive and distance(input.player, s.from) <= c.rejoin
		if ready then
			s.phase = "join"
			s.segment = 1
			s.stillFor = 0
			s.farFor = 0
			return s, act("spawn", Companion.spawnPoint(s, input.player))
		end
		return s, act("stand")
	end
	if input.finished and s.mode == "follow" then
		s.phase = "arrived"
		s.arrivedAt = input.now
		s.walking = false
		return s, act("stand")
	end
	if s.phase == "join" then
		s.phase = if s.mode == "lead" then "lead" else "follow"
		return s, act("stand")
	end
	if s.mode == "lead" then
		return stepLead(s, input, input.figure, dt)
	end
	if not input.figure then
		return s, act("stand")
	end
	return stepFollow(s, input, input.figure, dt)
end

-- Validation -----------------------------------------------------------------------------------------------------------

-- Problems of the companion data ("<questId>: <problem>"); empty = fine. `list` defaults to every quest.
function Companion.validate(list: { any }?): { string }
	local problems: { string } = {}
	local quests: { any } = list or {}
	if not list then
		for _, quest in Quests.Main.list do
			table.insert(quests, quest)
		end
		for _, quest in Quests.npcList do
			table.insert(quests, quest)
		end
	end
	for _, quest in quests do
		local function bad(text: string)
			table.insert(problems, `{quest.id}: {text}`)
		end
		local def = quest.companion
		local escorts: { number } = {}
		for i, objective in quest.objectives do
			if objective.type == "escort" then
				table.insert(escorts, i)
			end
		end
		if def == nil then
			if #escorts > 0 then
				bad("escort objective without a leading companion")
			end
			continue
		end
		if not Npcs.get(def.npc) then
			bad(`unknown companion NPC {tostring(def.npc)}`)
		end
		if not Maps.get(def.map) then
			bad(`unknown map {tostring(def.map)}`)
		end
		if def.mode ~= "follow" and def.mode ~= "lead" then
			bad(`unknown mode {tostring(def.mode)}`)
		end
		if type(def.during) ~= "table" or #def.during == 0 then
			bad("empty during")
		else
			local seen: { [number]: boolean } = {}
			for _, i in def.during do
				if type(i) ~= "number" or i ~= math.floor(i) or i < 1 or i > #quest.objectives then
					bad(`during {tostring(i)} out of the objectives`)
				elseif seen[i] then
					bad(`during {i} twice`)
				end
				seen[i] = true
			end
		end
		if def.mode == "lead" then
			local inDuring = 0
			for _, i in escorts do
				if table.find(def.during or {}, i) then
					inDuring += 1
				end
			end
			if #escorts ~= 1 or inDuring ~= 1 then
				bad("lead needs exactly one escort objective, in during")
			end
			local objective = Companion.escortOf(quest)
			if objective then
				if objective.npc ~= def.npc then
					bad(`escort NPC {tostring(objective.npc)} is not the companion {def.npc}`)
				end
				if objective.map ~= def.map then
					bad(`escort on map {tostring(objective.map)}, companion on {def.map}`)
				end
				if type(objective.x) ~= "number" or type(objective.z) ~= "number" then
					bad("escort without x / z")
				end
				if type(objective.radius) ~= "number" or objective.radius <= 0 then
					bad("escort without a radius")
				end
				if not (Locale.has(objective.place or "", "pl") and Locale.has(objective.place or "", "en")) then
					bad(`escort place {tostring(objective.place)} has no text`)
				end
				-- CompanionService finds a path for every leg of the route: none longer than legMax
				local start = Companion.fromOf(def)
				local route = if start then Companion.route(def, objective, start) else {}
				for i = 1, #route - 1 do
					if distance(route[i], route[i + 1]) > Config.Companion.legMax then
						bad(`route leg {i} longer than {Config.Companion.legMax} studs`)
					end
				end
			end
		elseif #escorts > 0 then
			bad("follow with an escort objective")
		end
		if Companion.fromOf(def) == nil then
			bad(`no start: {def.npc} does not stand on {def.map} and there is no from`)
		end
		if def.lines ~= nil then
			for event, n in def.lines :: any do
				if not table.find({ "join", "wait", "arrive", "back" }, event) then
					bad(`unknown companion line {tostring(event)}`)
				elseif type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > 4 then
					bad(`{event}: {tostring(n)} variants (1..4)`)
				end
			end
		end
	end
	return problems
end

return Companion
