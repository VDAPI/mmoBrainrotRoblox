--!strict
-- Class paths (S57, ROZWOJ 2.2-2.10, 3.4): Logic/Paths on the test paths (tests/fixtures/paths.luau) and the checks
-- every class in Data/Paths must pass.

local Classes = require("../src/shared/Data/Classes")
local EffectCategoryRules = require("./EffectCategoryRules")
local EffectStack = require("../src/shared/Logic/EffectStack")
local Fixture = require("./fixtures/paths")
local PartyBuffRules = require("./PartyBuffRules")
local PathData = require("../src/shared/Data/Paths")
local GamePaths = require("../src/shared/Logic/Paths")
local ItemScore = require("../src/shared/Logic/ItemScore")
local RankFill = require("./RankFill")
local SkillPools = require("../src/shared/Logic/SkillPools")
local Progression = require("../src/shared/Data/Progression")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local StatPlan = require("../src/shared/Logic/StatPlan")
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local P = GamePaths.withSource(Fixture.source)

-- Unlocks of the 14 skills per class in 05b859d (before S53): rule A of ROZWOJ 2.2 (row 1 skill unlocks at <= 34).
local TODAY_UNLOCK: { [string]: number } = {
	mightyStrike = 1,
	battleCry = 3,
	charge = 6,
	bladeWhirl = 10,
	steelSkin = 14,
	cleave = 18,
	taunt = 23,
	fortitude = 28,
	earthquake = 34,
	bloodlust = 40,
	riposte = 48,
	crushingBlow = 56,
	lastBastion = 65,
	titansWrath = 75,
	aimedShot = 1,
	doubleShot = 3,
	disengage = 6,
	arrowRain = 10,
	hawkEye = 14,
	venomArrow = 18,
	frostTrap = 23,
	agility = 28,
	piercingArrow = 34,
	huntersMark = 40,
	predatorInstinct = 48,
	volley = 56,
	camouflage = 65,
	stormArrow = 75,
	firebolt = 1,
	iceShard = 3,
	blink = 6,
	fireball = 10,
	focus = 14,
	chainLightning = 18,
	manaShield = 23,
	elementalist = 28,
	frostNova = 34,
	meteor = 40,
	arcaneMind = 48,
	firewall = 56,
	evocation = 65,
	meteorStorm = 75,
	holyStrike = 1,
	heal = 3,
	renew = 6,
	radiance = 10,
	devotion = 14,
	circleOfLight = 18,
	purify = 23,
	auraOfEndurance = 28,
	resurrection = 34,
	shieldOfFaith = 40,
	divineWrath = 48,
	judgement = 56,
	prayer = 65,
	divineIntervention = 75,
}

local function char(level: number, path: any?, extra: { [string]: any }?): any
	local c: { [string]: any } = {
		class = "Mage",
		level = level,
		path = path or { nodes = {}, bp = {} },
		hotbar = {},
		equipment = {},
	}
	for key, value in extra or {} do
		c[key] = value
	end
	-- S137: the ranks of the old automatic curve as bought ranks (tests/RankFill), unless the test gives its own
	return RankFill.fill(c, Fixture.skills)
end

-- S137: skills with a rank in any weapon pool of the class (a reference build names skills of every element pool)
local function availableAny(c: any): { string }
	local out: { string } = {}
	for _, poolId in SkillPools.ids(c.class) do
		for _, id in GamePaths.availableSkills(c, poolId) do
			if not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	return out
end

-- S138: a path state has nodes and breakpoint choices only (no main path, no freeUsed)
local function state(nodes: { [string]: number }?, bp: any?): any
	return { nodes = nodes or {}, bp = bp or {} }
end

-- S138: ranks of rows 1..row-1 of a fixture path, bottom-up and node by node (first node in choice rows), until the
-- requirement of `row` (PathData.ROWS[row].need) is met: the fewest points that open `row`.
local function upTo(pathId: string, row: number, nodes: { [string]: number }?): { [string]: number }
	local out = nodes or {}
	local path = Fixture.source.path(pathId) :: any
	local left = PathData.ROWS[row].need
	for r = 1, row - 1 do
		for _, node in path.rows[r].nodes do
			if left <= 0 then
				return out
			end
			local add = math.min(node.maxRank, left)
			out[node.id] = add
			left -= add
			if path.rows[r].choice then
				break
			end
		end
	end
	return out
end

-- S138: `nodes` plus ranks of other nodes of rows 1..DIP_ROWS of `pathId` (game data or the fixture; nodes that are not
-- team nodes and change no skill first) until the direction holds TEAM_FULL_POINTS ranks: its team nodes then work in
-- full. Only the ranks of `pathId` in `nodes` count.
local function teamFull(pathId: string, nodes: { [string]: number }): { [string]: number }
	local out = table.clone(nodes)
	local path = (PathData.get(pathId) or Fixture.source.path(pathId)) :: any
	local have = 0
	for r = 1, #PathData.ROWS do
		for _, node in path.rows[r].nodes do
			have += out[node.id] or 0
		end
	end
	for pass = 1, 2 do
		for r = 1, PathData.DIP_ROWS do
			for _, node in path.rows[r].nodes do
				local quiet = node.modify == nil and not GamePaths.isTeamNode(node)
				if have < PathData.TEAM_FULL_POINTS and out[node.id] == nil and (quiet or pass == 2) then
					local add = math.min(node.maxRank, PathData.TEAM_FULL_POINTS - have)
					out[node.id] = add
					have += add
				end
			end
		end
	end
	return out
end

-- The most ranks one direction can hold: every row, the larger node of a choice row (S138 coverage).
local function wholeOf(path: any): number
	local total = 0
	for _, row in path.rows do
		local best = 0
		for _, node in row.nodes do
			best = if row.choice then math.max(best, node.maxRank) else best + node.maxRank
		end
		total += best
	end
	return total
end

-- Every rank of rows 1..upTo of a fixture path (first node in choice rows).
local function fill(pathId: string, upTo: number, nodes: { [string]: number }?): { [string]: number }
	local out = nodes or {}
	local path = Fixture.source.path(pathId) :: any
	for r = 1, upTo do
		for _, node in path.rows[r].nodes do
			out[node.id] = node.maxRank
			if path.rows[r].choice then
				break
			end
		end
	end
	return out
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function hasRef(value: any, fields: { [string]: any }, bad: { string })
	if type(value) ~= "table" then
		return
	end
	if type(value.ref) == "string" then
		if fields[value.ref] == nil then
			table.insert(bad, value.ref)
		end
		return
	end
	for _, inner in value do
		hasRef(inner, fields, bad)
	end
end

-- Structure check (K2) for every path of `classId` on `api`.
local function problems(api: any, classId: string): { string }
	local out: { string } = {}
	local function bad(what: string)
		table.insert(out, what)
	end
	local class = Classes.get(classId)
	local allowed: { [string]: boolean } = {}
	for _, t in (class and class.weaponTypes) or {} do
		allowed[t] = true
	end
	for _, t in (class and class.offhandTypes) or {} do
		allowed[t] = true
	end
	local function weaponTypesOk(req: any, where: string)
		if req == nil then
			return
		end
		for _, list in { req.main or {}, req.offhand or {} } do
			for _, t in list do
				if not allowed[t] then
					bad(`{where}: weapon type {t} is not of {classId}`)
				end
			end
		end
	end
	local rows = api.rowsFor(classId)
	local ids: { [string]: boolean } = {}
	-- S140 (DESIGN-18 §7): a class whose skill nodes all sit in PathData.SKILL_ROWS (the Mage from S140) has none in
	-- row 1; the classes before their session keep the old rule (exactly one)
	local skillRowsOnly = true
	for _, path in api.pathsOf(classId) do
		for r, row in path.rows do
			for _, n in row.nodes do
				if n.kind == "skill" and table.find(PathData.SKILL_ROWS, r) == nil then
					skillRowsOnly = false
				end
			end
		end
	end
	for _, path in api.pathsOf(classId) do
		local pid = path.id
		if #path.rows ~= #rows then
			bad(`{pid}: {#path.rows} rows`)
			continue
		end
		weaponTypesOk(path.weapon, pid)
		local skillNodes: { [string]: number } = {}
		for r, row in path.rows do
			local info = rows[r]
			local where = `{pid} row {r}`
			if row.choice ~= info.choice then
				bad(`{where}: choice flag`)
			end
			local extras = 0
			for i, n in row.nodes do
				if n.extra then
					extras += 1
					if not info.extra or i ~= #row.nodes then
						bad(`{where}: extra node {n.id} out of place`)
					end
				end
			end
			if info.kind == "choice" then
				if #row.nodes ~= 2 then
					bad(`{where}: a choice row has 2 nodes`)
				end
			elseif info.kind == "capstone" then
				local n = row.nodes[1]
				if #row.nodes ~= 1 or n.maxRank ~= 1 or (n.kind ~= "skill" and n.kind ~= "keystone") then
					bad(`{where}: the capstone is one skill or keystone node of rank 1`)
				end
			elseif info.kind == "upgrade" then
				if #row.nodes ~= 1 or row.nodes[1].maxRank ~= 2 then
					bad(`{where}: the upgrade is one node of rank 2`)
				end
			else
				local want = if info.extra then 3 else 2
				if #row.nodes ~= want or extras ~= (if info.extra then 1 else 0) then
					bad(`{where}: {want} nodes expected`)
				end
			end
			local skillsInRow = 0
			for _, n in row.nodes do
				if ids[n.id] then
					bad(`{where}: duplicate node id {n.id}`)
				end
				ids[n.id] = true
				if string.sub(n.id, 1, #pid + 1) ~= pid .. "_" then
					bad(`{n.id}: id must start with {pid}_`)
				end
				if type(n.maxRank) ~= "number" or n.maxRank < 1 or n.maxRank > 3 then
					bad(`{n.id}: maxRank 1..3`)
				end
				weaponTypesOk(n.weapon, n.id)
				if n.dipScale ~= nil and (n.dipScale <= 0 or n.dipScale >= 1) then
					bad(`{n.id}: dipScale in (0, 1)`)
				end
				local fields = n.values or {}
				if n.kind == "skill" then
					skillsInRow += 1
					local skill = api.source.skill(n.skill or "")
					if n.maxRank ~= 1 or n.id ~= `{pid}_{n.skill}` then
						bad(`{n.id}: a skill node has rank 1 and id {pid}_<skillId>`)
					end
					if not skill then
						bad(`{n.id}: unknown skill {n.skill}`)
					elseif skill.path ~= pid or skill.class ~= classId or skill.unlock ~= info.level then
						bad(`{n.id}: skill {skill.id} needs path {pid}, class {classId}, unlock {info.level}`)
					else
						skillNodes[skill.id] = (skillNodes[skill.id] or 0) + 1
					end
				end
				if n.modify then
					local target = api.source.skill(n.modify.skill)
					if not target or target.class ~= classId then
						bad(`{n.id}: modify of unknown skill {n.modify.skill}`)
					end
					if n.modify.at ~= nil and n.modify.at ~= 5 and n.modify.at ~= 10 then
						bad(`{n.id}: modify.at is 5 or 10`)
					end
					if n.modify.option == "b" then
						local pair = target and target.breakpoints and target.breakpoints[n.modify.at or 5]
						if not (pair and pair.b) then
							bad(`{n.id}: option b without a B breakpoint`)
						end
					end
					local missing = {}
					hasRef(n.modify.bp, fields, missing)
					for _, ref in missing do
						bad(`{n.id}: ref {ref} is not in values`)
					end
				end
				for _, group in
					{ n.passive and n.passive.flat, n.passive and n.passive.pct, n.passive and n.passive.hooks }
				do
					for _, field in group or {} do
						if fields[field] == nil then
							bad(`{n.id}: passive field {field} is not in values`)
						end
					end
				end
				for _, field in (n.aura and n.aura.stats) or {} do
					if fields[field] == nil then
						bad(`{n.id}: aura field {field} is not in values`)
					end
				end
				for _, field in n.luck or {} do
					if fields[field] == nil then
						bad(`{n.id}: luck field {field} is not in values`)
					end
				end
			end
			if info.choice and skillsInRow > 0 then
				bad(`{where}: a choice row has no skill nodes`)
			end
			if r == 1 and skillsInRow ~= (if skillRowsOnly then 0 else 1) then
				bad(`{where}: row 1 holds {if skillRowsOnly then "no skill" else "exactly one skill"}`)
			end
		end
		for _, skill in api.source.classSkills(classId) do
			if skill.path == pid and skillNodes[skill.id] ~= 1 then
				bad(`{pid}: skill {skill.id} needs exactly one skill node`)
			end
		end
	end
	return out
end

-- Ranks of a path counted once (choice rows: one node).
local function pathRanks(path: any, fromRow: number, toRow: number): number
	local total = 0
	for r = fromRow, toRow do
		local row = path.rows[r]
		if row.choice then
			total += row.nodes[1].maxRank
		else
			for _, n in row.nodes do
				total += n.maxRank
			end
		end
	end
	return total
end

-- Buys a reference build rank by rank at level 100 through canBuy / canChooseBreakpoint (S138: no main path; its own
-- direction leads at the end and holds the set's one capstone).
local function checkReference(api: any, path: any, build: any)
	local c = char(100, state({}, {}), { class = path.class })
	for _, entry in build.nodes do
		local id, rank = entry[1], entry[2]
		for _ = 1, rank do
			local can, why = api.canBuy(c, id)
			assert(can, `{build.id}: {id} {why}`)
			c.path.nodes[id] = (c.path.nodes[id] or 0) + 1
		end
	end
	assert(api.spent(c) <= api.pointsAt(100), `{build.id}: spends more than pointsAt(100)`)
	assert(api.mainOf(c) == path.id, `{build.id}: leading direction {api.mainOf(c)}`)
	local capstone = api.capstoneOf(c)
	assert(capstone == nil or capstone == path.id, `{build.id}: capstone in {capstone}`)
	for key, option in build.bp or {} do
		local skillId, at = string.match(key, "^(.+):(%d+)$")
		local can, why = api.canChooseBreakpoint(c, skillId, tonumber(at), option)
		assert(can, `{build.id}: bp {key} {why}`)
	end
end

T.describe("Paths: layout and points", function()
	T.it("ROWS, constants and pointsAt", function()
		local levels, needs = {}, {}
		for _, row in PathData.ROWS do
			table.insert(levels, row.level)
			table.insert(needs, row.need)
		end
		T.expect(levels).toEqual({ 10, 15, 20, 26, 33, 40, 48, 60, 70, 80, 90 })
		T.expect(needs).toEqual({ 0, 2, 4, 6, 9, 12, 15, 18, 21, 24, 28 })
		T.expect(PathData.DIP_ROWS).toBe(2)
		T.expect(PathData.DIP_SCALE).toBe(1 / 3)
		T.expect(Progression.pathPointsEvery).toBe(2)
		T.expect(P.pointsAt(9)).toBe(4)
		T.expect(P.pointsAt(10)).toBe(5)
		T.expect(P.pointsAt(20)).toBe(10)
		T.expect(P.pointsAt(60)).toBe(30)
		T.expect(P.pointsAt(100)).toBe(50)
		-- S138 (DESIGN-18 §7): directions instead of the main path
		T.expect(P.MAIN_LEVEL).toBeNil()
		T.expect(P.canChooseMain).toBeNil()
		T.expect(P.mainWeaponOk).toBeNil()
		T.expect(PathData.CAPSTONES_MAX).toBe(1)
		T.expect(PathData.MAIN_MIN_POINTS).toBe(12)
		T.expect(PathData.TEAM_FULL_POINTS).toBe(6)
		T.expect(PathData.SKILL_ROWS).toEqual({ 4, 8 })
		T.expect(P.CAPSTONES_MAX).toBe(PathData.CAPSTONES_MAX)
	end)

	T.it("rowsFor: twoPathExtra only with two paths", function()
		local extra = {}
		for _, row in P.rowsFor("Mage") do
			if row.extra then
				table.insert(extra, row.index)
			end
		end
		T.expect(extra).toEqual({ 2, 5, 10 })
		local three = GamePaths.withSource(GamePaths.sourceOf({
			{ id = "a", class = "Mage", order = 1, rows = {} } :: any,
			{ id = "b", class = "Mage", order = 2, rows = {} } :: any,
			{ id = "c", class = "Mage", order = 3, rows = {} } :: any,
		}, nil))
		for _, api in { three, P } do
			for _, row in api.rowsFor(if api == three then "Mage" else "Warrior") do
				T.expect(row.extra).toBe(false)
			end
		end
		T.expect(P.rowsFor("Mage")[3].choice).toBe(true)
		T.expect(P.classHasPaths("Mage")).toBe(true)
		T.expect(P.classHasPaths("Warrior")).toBe(false)
		T.expect(P.isPublished("fxStorm")).toBe(true)
		T.expect(P.isPublished("fxGone")).toBe(false)
	end)
end)

T.describe("Paths: structure", function()
	T.it("the fixture has no problems", function()
		T.expect(problems(P, "Mage")).toEqual({})
	end)

	T.it("broken copies are caught", function()
		local function broken(edit: (paths: { any }, skills: { any }) -> ()): { string }
			local paths = deepCopy(Fixture.paths)
			local skills = deepCopy(Fixture.skills)
			edit(paths, skills)
			return problems(GamePaths.withSource(GamePaths.sourceOf(paths, skills)), "Mage")
		end
		local cases = {
			function(_, skills)
				for _, s in skills do
					if s.id == "fxBolt" then
						s.unlock = 11
					end
				end
			end,
			function(paths)
				table.insert(paths[1].rows[8].nodes, deepCopy(paths[1].rows[8].nodes[1]))
				paths[1].rows[8].nodes[2].id = "fxStorm_second"
			end,
			function(paths)
				table.remove(paths[1].rows[2].nodes, 3)
			end,
			function(paths)
				paths[1].rows[4].nodes[2].id = paths[1].rows[1].nodes[2].id
			end,
			function(paths)
				paths[1].rows[3].nodes[1].modify.bp.mul.cooldown.ref = "nope"
			end,
		}
		for i, edit in cases do
			if #broken(edit) == 0 then
				error(`broken case {i} not caught`)
			end
		end
	end)
end)

T.describe("Paths: buying and refunding", function()
	T.it("rows open by level and points in the lower rows of the direction (S138: no main path)", function()
		local c = char(10)
		T.expect(P.free(c)).toBe(5)
		T.expect(P.rowOpen(c, "fxStorm", 1)).toBe(true)
		T.expect(P.rowOpen(c, "fxRune", 1)).toBe(true)
		T.expect(select(2, P.rowOpen(c, "fxStorm", 2))).toBe("paths.error.level")
		T.expect(P.canBuy(c, "fxStorm_focus")).toBe(true)
		local c15 = char(15)
		T.expect(select(2, P.rowOpen(c15, "fxStorm", 2))).toBe("paths.error.need")
		c15.path.nodes = { fxStorm_focus = 2 }
		T.expect(P.rowOpen(c15, "fxStorm", 2)).toBe(true)
		T.expect(select(2, P.canBuy(c15, "nope_node"))).toBe("paths.error.unknown")
		local c20 = char(20, state({ fxStorm_focus = 3, fxStorm_fxSpark = 1 }))
		T.expect(P.rowOpen(c20, "fxStorm", 3)).toBe(true)
		T.expect(select(2, P.rowOpen(c20, "fxRune", 3))).toBe("paths.error.need")
		T.expect(select(2, P.rowOpen(char(19, state({ fxStorm_focus = 3, fxStorm_fxSpark = 1 })), "fxStorm", 3)))
			.toBe("paths.error.level")
		-- row 3 of the second direction with its own points, next to the first one
		local both = char(20, state({ fxStorm_focus = 3, fxStorm_fxSpark = 1, fxRune_fxGlyph = 1, fxRune_mend = 3 }))
		T.expect(P.rowOpen(both, "fxStorm", 3)).toBe(true)
		T.expect(P.rowOpen(both, "fxRune", 3)).toBe(true)
		T.expect(P.canBuy(c20, "fxStorm_surge")).toBe(true)
		c20.path.nodes.fxStorm_surge = 1
		T.expect(select(2, P.canBuy(c20, "fxStorm_echo"))).toBe("paths.error.choice")
		T.expect(P.canBuy(c20, "fxStorm_surge")).toBe(true)
		c20.path.nodes.fxStorm_surge = 3
		T.expect(select(2, P.canBuy(c20, "fxStorm_surge"))).toBe("paths.error.maxRank")
		local poor = char(10, state({ fxStorm_focus = 3, fxStorm_fxSpark = 1, fxRune_fxGlyph = 1 }))
		T.expect(P.free(poor)).toBe(0)
		T.expect(select(2, P.canBuy(poor, "fxRune_mend"))).toBe("paths.error.points")
	end)

	T.it("refunds keep the row requirements and go from the top", function()
		local nodes = fill("fxStorm", 4)
		local c = char(40, state(nodes, { ["fxSpark:5"] = "b" }))
		-- rows 1-2 hold 13, row 4 needs 6: one rank of row 1 may go, row 3 needs 4
		T.expect(P.canRefund(c, "fxStorm_focus")).toBe(true)
		T.expect(select(2, P.canRefund(c, "fxStorm_echo"))).toBe("paths.error.noRank")
		local thin = char(40, state({ fxStorm_fxSpark = 1, fxStorm_focus = 1, fxStorm_surge = 1 }))
		T.expect(select(2, P.canRefund(thin, "fxStorm_focus"))).toBe("paths.error.needAbove")
		T.expect(P.canRefund(thin, "fxStorm_surge")).toBe(true)

		local all = P.refund(c, nil)
		T.expect(all).toEqual({ nodes = {}, bp = { ["fxSpark:5"] = "b" } })
		local low = P.refund(c, { fromRow = 3 })
		T.expect(low.nodes).toEqual(fill("fxStorm", 2))
		local two = P.refund(c, { points = 2 })
		-- row 4: the last node (power, 3 ranks) loses 2
		T.expect(two.nodes.fxStorm_power).toBe(1)
		T.expect(two.nodes.fxStorm_fxBolt).toBe(1)
		T.expect(P.spent(char(40, two))).toBe(P.spent(c) - 2)
		local other = P.refund(char(40, state(fill("fxStorm", 2, { fxRune_fxGlyph = 1 }))), { path = "fxRune" })
		T.expect(other.nodes.fxRune_fxGlyph).toBeNil()
		T.expect(other.nodes.fxStorm_focus).toBe(3)
	end)
end)

T.describe("Paths: directions (S138, DESIGN-18 §7)", function()
	T.it("one capstone per set; the upgrade only with its own capstone", function()
		local capRow, upRow = 8, 11
		T.expect(PathData.ROWS[capRow].kind).toBe("capstone")
		T.expect(PathData.ROWS[upRow].kind).toBe("upgrade")
		-- both directions filled to the capstone's requirement (18 + 18 of 50 points)
		local nodes = upTo("fxRune", capRow, upTo("fxStorm", capRow))
		local c = char(100, state(nodes))
		T.expect(P.canBuy(c, "fxStorm_fxCataclysm")).toBe(true)
		T.expect(P.canBuy(c, "fxRune_fxRuneStorm")).toBe(true)
		T.expect(P.capstoneOf(c)).toBeNil()
		c.path.nodes.fxStorm_fxCataclysm = 1
		T.expect(P.capstoneOf(c)).toBe("fxStorm")
		T.expect({ P.canBuy(c, "fxRune_fxRuneStorm") }).toEqual({ false, "skills.error.capstoneTaken" })
		-- refunding the first capstone frees the slot
		T.expect(P.canRefund(c, "fxStorm_fxCataclysm")).toBe(true)
		c.path.nodes.fxStorm_fxCataclysm = nil
		T.expect(P.canBuy(c, "fxRune_fxRuneStorm")).toBe(true)
		-- the upgrade: a direction at its requirement without the capstone may not buy it
		local bare = char(100, state(upTo("fxRune", upRow)))
		T.expect(P.spent(bare)).toBe(PathData.ROWS[upRow].need)
		T.expect({ P.canBuy(bare, "fxRune_runeStormPlus") }).toEqual({ false, "paths.error.upgrade" })
		-- with its capstone it may, and then the capstone stays until the upgrade goes
		local own = upTo("fxStorm", upRow)
		own.fxStorm_fxCataclysm = 1
		local deep = char(100, state(own))
		T.expect(P.canBuy(deep, "fxStorm_cataclysmPlus")).toBe(true)
		deep.path.nodes.fxStorm_cataclysmPlus = 1
		T.expect({ P.canRefund(deep, "fxStorm_fxCataclysm") }).toEqual({ false, "paths.error.needAbove" })
		T.expect(P.canRefund(deep, "fxStorm_cataclysmPlus")).toBe(true)
	end)

	T.it("mainOf: the most ranks, at least MAIN_MIN_POINTS, a tie goes to the lower order", function()
		local need = PathData.MAIN_MIN_POINTS
		T.expect(P.mainOf(char(100))).toBeNil()
		local below = fill("fxStorm", 1) -- 4 ranks
		T.expect(P.mainOf(char(100, state(below)))).toBeNil()
		local storm = fill("fxStorm", 2) -- 13 ranks
		T.expect(P.pathSpent(char(100, state(storm)), "fxStorm")).toBe(13)
		T.expect(P.mainOf(char(100, state(storm)))).toBe("fxStorm")
		-- exactly the threshold
		local exact = upTo("fxStorm", 3) -- 4
		exact.fxStorm_beacon = 3
		exact.fxStorm_surge = 3
		exact.fxStorm_power = need - 10
		T.expect(P.pathSpent(char(100, state(exact)), "fxStorm")).toBe(need)
		T.expect(P.mainOf(char(100, state(exact)))).toBe("fxStorm")
		exact.fxStorm_power -= 1
		T.expect(P.mainOf(char(100, state(exact)))).toBeNil()
		-- more ranks in the second direction win; a tie goes to the lower order (fxStorm)
		local rune = fill("fxRune", 2, fill("fxStorm", 2)) -- 13 + 13
		T.expect(P.mainOf(char(100, state(rune)))).toBe("fxStorm")
		rune.fxRune_r3a = 3
		T.expect(P.mainOf(char(100, state(rune)))).toBe("fxRune")
		T.expect(P.pathSpent(char(100, state(rune)), "fxGone")).toBe(0)
		T.expect(P.mainOf(char(100, state(rune), { class = "Warrior" }))).toBeNil()
	end)

	T.it("PathDef.weapon blocks nothing; node.weapon greys its node in every row", function()
		local c = char(40, state(fill("fxStorm", 4)))
		for _, weapons in { { main = "runestaff" }, { main = "wand" }, {} } do
			T.expect(P.skillUsable(c, "fxBolt", weapons)).toBe(true)
		end
		local active: { [string]: boolean } = {}
		for _, a in P.activeNodes(c, { main = "runestaff" }) do
			active[a.node.id] = true
		end
		T.expect(active.fxStorm_power).toBe(true) -- row 4 without the old path weapon
		local paths = deepCopy(Fixture.paths)
		paths[1].rows[4].nodes[1].weapon = { main = { "staff" } } -- fxBolt's node
		paths[1].rows[4].nodes[2].weapon = { main = { "staff" } } -- power
		local api = GamePaths.withSource(GamePaths.sourceOf(paths, Fixture.skills))
		T.expect({ api.skillUsable(c, "fxBolt", { main = "wand" }) }).toEqual({ false, "cast.error.pathWeapon" })
		T.expect(api.skillUsable(c, "fxBolt", { main = "staff" })).toBe(true)
		local withWand: { [string]: boolean } = {}
		for _, a in api.activeNodes(c, { main = "wand" }) do
			withWand[a.node.id] = true
		end
		T.expect(withWand.fxStorm_power).toBeNil()
		T.expect(withWand.fxStorm_focus).toBe(true)
	end)

	T.it("50 points: one whole direction with its capstone and upgrade, never two", function()
		local function whole(pathId: string): number
			local path = Fixture.source.path(pathId) :: any
			local total = 0
			for _, row in path.rows do
				local best = 0
				for _, node in row.nodes do
					if row.choice then
						best = math.max(best, node.maxRank)
					else
						best += node.maxRank
					end
				end
				total += best
			end
			return total
		end
		T.expect(whole("fxStorm") <= P.pointsAt(100)).toBe(true)
		T.expect(whole("fxRune") <= P.pointsAt(100)).toBe(true)
		T.expect(whole("fxStorm") + whole("fxRune") > P.pointsAt(100)).toBe(true)
	end)
end)

T.describe("Paths: skills", function()
	T.it("skillRank, availableSkills", function()
		local c = char(40, state(fill("fxStorm", 3)))
		T.expect(P.skillRank(c, "fxBolt")).toBe(0)
		c.path.nodes.fxStorm_fxBolt = 1
		local bolt = Fixture.source.skill("fxBolt") :: any
		T.expect(P.skillRank(c, "fxBolt")).toBe(Skills.rankAt(bolt, 40))
		T.expect(P.skillRank(c, "fxBolt") > 1).toBe(true)
		-- S138: a row-4 skill works in any direction with its node (no main path)
		T.expect(P.skillRank(c, "fxSpark") > 0).toBe(true)
		local young = char(25, state(c.path.nodes))
		T.expect(P.skillRank(young, "fxBolt")).toBe(0) -- the row's level (26) not reached
		local orphan = char(100, state({ fxGone_fxOrphan = 1 }), { hotbar = { ["1"] = "fxOrphan" } })
		T.expect(P.skillRank(orphan, "fxOrphan")).toBe(0)
		T.expect(table.find(P.availableSkills(orphan), "fxOrphan")).toBeNil()
		T.expect((P.validHotbar(orphan))).toEqual({})
		local list = P.availableSkills(char(40, state(fill("fxStorm", 4))))
		T.expect(table.find(list, "firebolt") ~= nil).toBe(true) -- class base
		T.expect(table.find(list, "fxSpark") ~= nil).toBe(true)
		T.expect(table.find(list, "fxBolt") ~= nil).toBe(true)
		T.expect(table.find(list, "fxNova")).toBeNil()
		T.expect(table.find(list, "firebolt") < table.find(list, "fxSpark")).toBe(true)
		T.expect(P.skillRank(char(40, nil, { class = "Warrior" }), "fxSpark")).toBe(0)
	end)
end)

T.describe("Paths: weapons", function()
	T.it("weaponOk both ways", function()
		local storm = (Fixture.source.path("fxStorm") :: any).weapon
		T.expect(P.weaponOk(storm, { main = "staff" })).toBe(true)
		T.expect(P.weaponOk(storm, { main = "wand" })).toBe(false)
		T.expect(P.weaponOk(storm, { main = "wand", offhand = "orb" })).toBe(true)
		T.expect(P.weaponOk(storm, { main = "runestaff" })).toBe(false)
		T.expect(P.weaponOk(storm, {})).toBe(false)
		local tome = { offhand = { "tome" } }
		T.expect(P.weaponOk(tome, { main = "staff" })).toBe(false) -- a two-hander not listed in main
		T.expect(P.weaponOk(tome, { main = "wand", offhand = "tome" })).toBe(true)
		T.expect(P.weaponOk(nil, {})).toBe(true)
		T.expect(P.weaponTypesOf({ weapon = { id = "wand_1" } } :: any)).toEqual({ main = "wand" })
		T.expect(P.weaponTypesOf(nil)).toEqual({})
	end)

	T.it("skillUsable: no direction weapon (S138), node.weapon everywhere", function()
		local c = char(40, state(fill("fxStorm", 4)))
		T.expect(P.skillUsable(c, "fxBolt", { main = "runestaff" })).toBe(true)
		T.expect(P.skillUsable(c, "fxBolt", { main = "staff" })).toBe(true)
		T.expect(P.skillUsable(c, "fxSpark", { main = "runestaff" })).toBe(true)
		T.expect(P.skillUsable(c, "firebolt", {})).toBe(true)
		T.expect({ P.skillUsable(c, "fxNova", { main = "staff" }) }).toEqual({ false, "cast.error.notLearned" })
		local paths = deepCopy(Fixture.paths)
		paths[1].rows[1].nodes[1].weapon = { main = { "staff" } }
		local api = GamePaths.withSource(GamePaths.sourceOf(paths, Fixture.skills))
		T.expect({ api.skillUsable(c, "fxSpark", { main = "wand" }) }).toEqual({ false, "cast.error.pathWeapon" })
		T.expect(api.skillUsable(c, "fxSpark", { main = "staff" })).toBe(true)
	end)
end)

T.describe("Paths: node values and skill changes", function()
	T.it("nodeValues", function()
		local focus = P.findNode("fxStorm_focus") :: any
		T.expect(P.nodeValues(focus, 1).int).toBe(2)
		T.expect(P.nodeValues(focus, 2).int).toBe(4)
		T.expect(P.nodeValues(focus, 3).int).toBe(6)
		T.expect(P.nodeValues(focus, 3, 0.5).int).toBe(3)
		local node, path, row = P.findNode("fxStorm_cataclysmPlus")
		T.expect({ (node :: any).id, (path :: any).id, row }).toEqual({ "fxStorm_cataclysmPlus", "fxStorm", 11 })
	end)

	T.it("skillMods resolves refs, keeps row order and follows the option", function()
		local nodes = fill("fxStorm", 2)
		nodes.fxStorm_surge = 2
		local c = char(40, state(nodes))
		local mods = P.skillMods(c, "fxSpark", { main = "staff" })
		T.expect(#mods).toBe(2)
		T.expect(mods[1].values.hexGuard).toBe(9)
		T.expect(mods[2].mul.cooldown).toBeNear(0.8, 1e-9)
		-- S138: rows 3+ need no direction weapon
		T.expect(#P.skillMods(c, "fxSpark", { main = "runestaff" })).toBe(2)
		-- the echo node (option b at 5) only with B chosen
		nodes.fxStorm_surge = nil
		nodes.fxStorm_echo = 1
		T.expect(#P.skillMods(c, "fxSpark", { main = "staff" })).toBe(1)
		c.path.bp = { ["fxSpark:5"] = "b" }
		local withB = P.skillMods(c, "fxSpark", { main = "staff" })
		T.expect(#withB).toBe(2)
		T.expect(withB[2].add.range).toBe(2)
	end)

	T.it("effectiveFor adds node values to the skill (ROZWOJ 2.7)", function()
		local nodes = fill("fxStorm", 7)
		nodes.fxStorm_fxCataclysm = 1
		nodes.fxStorm_fury = 3
		local c = char(70, state(nodes))
		local spark = Fixture.source.skill("fxSpark") :: any
		local rank = P.skillRank(c, "fxSpark")
		local def = P.effectiveFor(c, "fxSpark", { main = "staff" })
		T.expect(Skills.valueAt(def, "dmg", rank)).toBeNear(Skills.valueAt(spark, "dmg", rank) + 30 + 60, 1e-9)
		local plain = P.effectiveFor(c, "fxSpark", { main = "runestaff" })
		-- S138: any weapon of the class, the nodes of every row work
		T.expect(Skills.valueAt(plain, "dmg", rank)).toBeNear(Skills.valueAt(spark, "dmg", rank) + 30 + 60, 1e-9)
	end)

	T.it("team nodes of rows 1-2 are weaker below TEAM_FULL_POINTS in their direction (S138)", function()
		local nodes = fill("fxStorm", 2, fill("fxRune", 1))
		-- 5 ranks in fxStorm (< TEAM_FULL_POINTS = 6): the dip scale; 13: in full
		local few = { fxStorm_fxSpark = 1, fxStorm_beacon = 2, fxStorm_hex = 1, fxStorm_ward = 1 }
		T.expect(P.pathSpent(char(20, state(few)), "fxStorm")).toBe(PathData.TEAM_FULL_POINTS - 1)
		local outside = char(20, state(few))
		local inside = char(20, state(nodes))
		local function scaleOf(c: any, id: string): number?
			for _, a in P.activeNodes(c, { main = "staff" }) do
				if a.node.id == id then
					return a.scale
				end
			end
			return nil
		end
		T.expect(scaleOf(outside, "fxStorm_beacon")).toBe(1 / 3)
		T.expect(scaleOf(outside, "fxStorm_hex")).toBe(1 / 3)
		T.expect(scaleOf(outside, "fxStorm_ward")).toBe(0.5)
		T.expect(P.nodeScale(outside, "fxStorm", 1, P.findNode("fxStorm_focus") :: any)).toBe(1)
		T.expect(scaleOf(inside, "fxStorm_beacon")).toBe(1)
		T.expect(scaleOf(inside, "fxStorm_hex")).toBe(1)
		-- the threshold itself works in full
		local at = table.clone(few)
		at.fxStorm_ward += 1
		T.expect(P.pathSpent(char(20, state(at)), "fxStorm")).toBe(PathData.TEAM_FULL_POINTS)
		T.expect(scaleOf(char(20, state(at)), "fxStorm_hex")).toBe(1)
		local mend = P.findNode("fxRune_mend") :: any
		T.expect(P.isTeamNode(mend)).toBe(false)
		T.expect(scaleOf(inside, "fxRune_mend")).toBe(1)
		local outsideMods = P.skillMods(outside, "fxSpark", { main = "staff" })
		T.expect(outsideMods[1].values.hexGuard).toBeNear(1, 1e-9) -- rank 1 (3) at 1/3
	end)

	T.it("a dip-scaled mul ref resolves as 1 + (x - 1) * scale, like nodeArgs", function()
		local copy = deepCopy(Fixture.paths)
		local hex: any = nil
		for _, row in copy[1].rows do
			for _, node in row.nodes do
				if node.id == "fxStorm_hex" then
					hex = node
				end
			end
		end
		hex.values.cd = { 0.7, 0.7 }
		hex.modify.bp.mul = { cooldown = { ref = "cd" } }
		local api = GamePaths.withSource(GamePaths.sourceOf(copy, Fixture.skills))
		local nodes = fill("fxStorm", 2, fill("fxRune", 1))
		local few = { fxStorm_fxSpark = 1, fxStorm_hex = 3 } -- 4 ranks: the dip scale
		local mods = api.skillMods(char(20, state(few)), "fxSpark", { main = "staff" })
		T.expect(mods[1].mul.cooldown).toBeNear(1 + (0.7 - 1) / 3, 1e-9)
		T.expect(api.nodeArgs(hex, 3, 1 / 3).cd).toBe(Skills.roundArg(mods[1].mul.cooldown))
		local inside = api.skillMods(char(20, state(nodes)), "fxSpark", { main = "staff" })
		T.expect(inside[1].mul.cooldown).toBeNear(0.7, 1e-9)
	end)
end)

T.describe("Paths: passives and active nodes", function()
	T.it("passiveTotals: node passives, path skill passives, weapon", function()
		local nodes = fill("fxStorm", 4, { fxRune_fxGlyph = 1 })
		local c = char(40, state(nodes))
		local base = P.passiveTotals(char(40), { main = "staff" })
		local full = P.passiveTotals(c, { main = "staff" })
		local glyph = Fixture.source.skill("fxGlyph") :: any
		local glyphInt = Skills.valueAt(glyph, "int", Skills.rankAt(glyph, 40))
		T.expect(full.flat.int).toBeNear((base.flat.int or 0) + 6 + glyphInt, 1e-9)
		T.expect(full.pct.magAtk).toBe((base.pct.magAtk or 0) + 3) -- power (row 4)
		-- S138: no direction weapon, so another weapon of the class keeps every node
		local noWeapon = P.passiveTotals(c, { main = "runestaff" })
		T.expect(noWeapon.pct.magAtk).toBe((base.pct.magAtk or 0) + 3)
		T.expect(noWeapon.flat.int).toBeNear((base.flat.int or 0) + 6 + glyphInt, 1e-9)
	end)

	T.it("a character without nodes keeps the base passives (same numbers as before S57)", function()
		local function warrior(level: number): any
			return char(level, nil, { class = "Warrior" })
		end
		local at50 = GamePaths.passiveTotals(warrior(50), {})
		T.expect(at50.pct.armor).toBe(25)
		-- S75: Fortitude is a guardian row 1 skill, it works only with the node
		T.expect(at50.pct.maxHp).toBeNil()
		T.expect(at50.hooks.riposte).toBe(4)
		T.expect(GamePaths.passiveTotals(warrior(44), {}).hooks.riposte).toBeNil()
		T.expect(GamePaths.passiveTotals(warrior(13), {})).toEqual({ flat = {}, pct = {}, hooks = {} })
		local at100 = GamePaths.passiveTotals(warrior(100), {})
		T.expect(at100.pct.armor).toBe(25)
		T.expect(at100.pct.maxHp).toBeNil()
		T.expect(at100.hooks.riposte).toBe(12)
	end)

	T.it("activeNodes in row order", function()
		local nodes = fill("fxStorm", 4, { fxRune_fxGlyph = 1 })
		local list = P.activeNodes(char(40, state(nodes)), { main = "staff" })
		local rows = {}
		for _, a in list do
			table.insert(rows, a.row)
			T.expect(a.rank > 0 and a.path ~= nil and a.scale > 0).toBe(true)
		end
		for i = 2, #rows do
			T.expect(rows[i] >= rows[i - 1]).toBe(true)
		end
		T.expect(list[1].node.id).toBe("fxStorm_fxSpark")
		T.expect(list[3].node.id).toBe("fxRune_fxGlyph")
		T.expect(#list).toBe(9)
	end)
end)

T.describe("Paths: hotbar and breakpoints", function()
	T.it("validHotbar drops what the character does not have", function()
		local nodes = fill("fxStorm", 4)
		local c = char(40, state(nodes, { ["fxSpark:5"] = "b", ["fxSpark:10"] = "a", ["fxBolt:5"] = "b" }), {
			hotbar = {
				["1"] = "fxSpark",
				["2"] = "fxBolt",
				["3"] = "focus", -- passive
				["4"] = "mightyStrike", -- other class
				["5"] = "fxSpark",
				["6"] = "fxOrphan",
				["7"] = "firebolt",
			},
		})
		local bar, bp, changed = P.validHotbar(c)
		T.expect(bar).toEqual({ ["1"] = "fxSpark", ["2"] = "fxBolt", ["7"] = "firebolt" })
		T.expect(bp).toEqual({ ["fxSpark:5"] = "b" }) -- no B at 10, fxBolt has no breakpoints (S81: every real skill has B)
		T.expect(changed).toBe(true)
		c.hotbar = bar
		c.path.bp = bp
		local _, _, again = P.validHotbar(c)
		T.expect(again).toBe(false)
		-- refunding the node drops the skill from the bar but keeps its choice (S138, DESIGN-18 §8)
		c.path.nodes.fxStorm_fxSpark = nil
		local bar2, bp2, changed2 = P.validHotbar(c)
		T.expect(bar2).toEqual({ ["2"] = "fxBolt", ["7"] = "firebolt" })
		T.expect(bp2).toEqual({ ["fxSpark:5"] = "b" })
		T.expect(changed2).toBe(true)
		-- a choice for a rank not reached yet stays
		local young = char(10, state({ fxStorm_fxSpark = 1 }, { ["fxSpark:5"] = "b" }))
		local _, bp3, changed3 = P.validHotbar(young)
		T.expect(bp3).toEqual({ ["fxSpark:5"] = "b" })
		T.expect(changed3).toBe(false)
		local _, _, notTable = P.validHotbar(char(10, nil, { hotbar = "oops" }))
		T.expect(notTable).toBe(true)
	end)

	T.it("canPutOnBar (moved from skills.spec: Hunter at 30)", function()
		local hunter = char(30, nil, { class = "Hunter" })
		T.expect(GamePaths.canPutOnBar(hunter, "aimedShot")).toBe(true)
		T.expect({ GamePaths.canPutOnBar(hunter, "hawkEye") }).toEqual({ false, "skills.error.locked" })
		T.expect(GamePaths.canPutOnBar(hunter, "piercingArrow")).toBe(false) -- S78: a marksman node
		T.expect(GamePaths.canPutOnBar(hunter, "firebolt")).toBe(false) -- other class
		local bar, _, changed = GamePaths.validHotbar(char(20, nil, {
			class = "Hunter",
			hotbar = {
				["1"] = "aimedShot",
				["2"] = "hawkEye",
				["3"] = "frostTrap",
				["4"] = "firebolt",
				["5"] = "aimedShot",
				["6"] = "nope",
				["7"] = "doubleShot",
				["11"] = "disengage",
			},
		}))
		T.expect(bar).toEqual({ ["1"] = "aimedShot", ["7"] = "doubleShot" })
		T.expect(changed).toBe(true)
	end)
end)

T.describe("Paths: clampToLevel", function()
	T.it("cuts rows, points, unknown nodes and broken requirements", function()
		local nodes = fill("fxStorm", 11, { fxRune_fxGlyph = 1, fxRune_r3a = 3, nope_x = 2 })
		nodes.fxStorm_focus = 7 -- above maxRank
		nodes.fxStorm_echo = 2 -- second node of a choice row
		local c = char(100, state(nodes, { ["fxSpark:5"] = "b" }))
		local s = P.clampToLevel(c, 30)
		local after = char(30, s)
		T.expect(s.nodes.nope_x).toBeNil()
		T.expect(s.nodes.fxRune_r3a).toBeNil()
		T.expect(s.nodes.fxStorm_focus).toBe(3)
		T.expect(s.nodes.fxStorm_echo).toBeNil()
		-- 21 ranks left in rows 1-4 at 30 (15 points): row 4 (power, fxBolt) and 2 ranks of surge go back
		T.expect(s.nodes.fxStorm_surge).toBe(1)
		T.expect(s.nodes.fxStorm_power).toBeNil()
		T.expect(s.nodes.fxStorm_fxBolt).toBeNil()
		T.expect(s.nodes.fxRune_fxGlyph).toBe(1)
		for _, id in { "fxStorm_overload", "fxStorm_fxNova", "fxStorm_fxCataclysm" } do
			T.expect(s.nodes[id]).toBeNil()
		end
		T.expect(P.spent(after) <= P.pointsAt(30)).toBe(true)
		T.expect(P.spent(after)).toBe(P.pointsAt(30))
		T.expect(s.bp).toEqual({ ["fxSpark:5"] = "b" })
		-- S138: the old fields are not copied
		T.expect(s.freeUsed).toBeNil()
		T.expect(s.main).toBeNil()
		-- a row without its requirement goes with every higher row
		local holes = char(40, state({ fxStorm_fxSpark = 1, fxStorm_surge = 3, fxStorm_fxBolt = 1 }))
		local fixed = P.clampToLevel(holes, 40)
		T.expect(fixed.nodes).toEqual({ fxStorm_fxSpark = 1 })
		-- S138: an old save with a main path and freeUsed loses both
		local old = char(40, { main = "fxStorm", nodes = { fxStorm_fxSpark = 1 }, bp = {}, freeUsed = true })
		T.expect(P.clampToLevel(old, 40)).toEqual({ nodes = { fxStorm_fxSpark = 1 }, bp = {} })
	end)

	T.it("two capstones (an old main path + admin): the leading direction keeps its own", function()
		-- 19 + 19 ranks, a tie: the lower order (fxStorm) leads and keeps its capstone
		local nodes = upTo("fxRune", 8, upTo("fxStorm", 8))
		nodes.fxStorm_fxCataclysm = 1
		nodes.fxRune_fxRuneStorm = 1
		local c = char(100, state(nodes))
		T.expect(P.mainOf(c)).toBe("fxStorm")
		T.expect(P.capstoneOf(c)).toBe("fxStorm")
		local s = P.clampToLevel(c, 100)
		T.expect(s.nodes.fxStorm_fxCataclysm).toBe(1)
		T.expect(s.nodes.fxRune_fxRuneStorm).toBeNil()
		T.expect(s.nodes.fxRune_fxGlyph).toBe(1)
		-- more ranks in fxRune (22 against 19): its capstone stays
		local swap = upTo("fxRune", 9, upTo("fxStorm", 8))
		swap.fxStorm_fxCataclysm = 1
		swap.fxRune_fxRuneStorm = 1
		local mixed = char(100, state(swap))
		T.expect(P.mainOf(mixed)).toBe("fxRune")
		T.expect(P.capstoneOf(mixed)).toBe("fxRune")
		local kept = P.clampToLevel(mixed, 100)
		T.expect(kept.nodes.fxRune_fxRuneStorm).toBe(1)
		T.expect(kept.nodes.fxStorm_fxCataclysm).toBeNil()
		-- the leading direction's upgrade stays, the other capstone goes (31 + 19 = 50 points)
		local up = upTo("fxRune", 11, upTo("fxStorm", 8))
		up.fxStorm_fxCataclysm = 1
		up.fxRune_fxRuneStorm = 1
		up.fxRune_runeStormPlus = 2
		T.expect(P.mainOf(char(100, state(up)))).toBe("fxRune")
		local both = P.clampToLevel(char(100, state(up)), 100)
		T.expect(both.nodes.fxRune_runeStormPlus).toBe(2)
		T.expect(both.nodes.fxRune_fxRuneStorm).toBe(1)
		T.expect(both.nodes.fxStorm_fxCataclysm).toBeNil()
	end)
end)

T.describe("Paths: edit rules and breakpoints", function()
	T.it("canEdit (B5)", function()
		local function edit(action: string, inCombat: boolean, inTown: boolean, nearGate: boolean): any
			return { P.canEdit({ action = action, inCombat = inCombat, inTown = inTown, nearGate = nearGate } :: any) }
		end
		for _, action in { "buy", "refund", "chooseBp", "changeBp" } do
			T.expect(edit(action, true, true, true)).toEqual({ false, "paths.error.combat" })
			T.expect(edit(action, false, true, false)[1]).toBe(true)
		end
		for _, action in { "buy", "chooseBp" } do
			T.expect(edit(action, false, false, false)[1]).toBe(true)
			T.expect(edit(action, false, false, true)[1]).toBe(true)
		end
		for _, action in { "refund", "changeBp" } do
			T.expect(edit(action, false, false, true)[1]).toBe(true)
			T.expect(edit(action, false, false, false)).toEqual({ false, "paths.error.place" })
		end
		-- S138 (DESIGN-18 §3.2): a node refund below freeRespecLevel anywhere out of combat (ctx.level)
		local free = Progression.freeRespecLevel
		local function refundAt(level: number, inCombat: boolean): any
			return {
				P.canEdit({ action = "refund", inCombat = inCombat, inTown = false, nearGate = false, level = level }),
			}
		end
		T.expect(refundAt(free - 1, false)).toEqual({ true })
		T.expect(refundAt(free - 1, true)).toEqual({ false, "paths.error.combat" })
		T.expect(refundAt(free, false)).toEqual({ false, "paths.error.place" })
		T.expect(
			select(2, P.canEdit({ action = "changeBp", inCombat = false, inTown = false, nearGate = false, level = 1 }))
		)
			.toBe("paths.error.place")
		T.expect(edit("changeMain", false, true, true)).toEqual({ false, "error.badRequest" })
	end)

	T.it("canChooseBreakpoint", function()
		local c = char(70, state({ fxStorm_fxSpark = 1 }))
		T.expect({ P.canChooseBreakpoint(c, "fxSpark", 10, "b") }).toEqual({ false, "bp.error.noOption", false })
		T.expect({ P.canChooseBreakpoint(char(20, state({ fxStorm_fxSpark = 1 })), "fxSpark", 5, "b") }).toEqual({
			false,
			"bp.error.rank",
			false,
		})
		T.expect({ P.canChooseBreakpoint(c, "fxSpark", 5, "b") }).toEqual({ true, nil, false })
		c.path.bp["fxSpark:5"] = "b"
		T.expect({ P.canChooseBreakpoint(c, "fxSpark", 5, "b") }).toEqual({ true, nil, false })
		T.expect({ P.canChooseBreakpoint(c, "fxSpark", 5, "a") }).toEqual({ true, nil, true })
		T.expect(select(2, P.canChooseBreakpoint(c, "fxSpark", 7, "a"))).toBe("error.badRequest")
		T.expect(select(2, P.canChooseBreakpoint(c, "fxSpark", 5, "c"))).toBe("error.badRequest")
		-- S81: every real class has B on both ranks, so a fixture skill without breakpoints
		local bolt = char(70, state(fill("fxStorm", 4)))
		T.expect(select(2, P.canChooseBreakpoint(bolt, "fxBolt", 5, "b"))).toBe("bp.error.noOption")
	end)
end)

T.describe("Paths: reference builds", function()
	T.it("the fixture builds buy through the rules", function()
		for _, path in Fixture.paths do
			for _, build in path.reference do
				checkReference(P, path, build)
			end
		end
	end)
end)

T.describe("Paths: party auras (S61)", function()
	local O = { x = 0, z = 0 }
	local TARGET = { x = 0, z = -10 }
	local BEHIND = { shape = "behind" }

	T.it("inAura circle", function()
		T.expect(GamePaths.inAura({}, O, { x = 29, z = 0 })).toBe(true)
		T.expect(GamePaths.inAura({ shape = "circle" }, O, { x = 31, z = 0 })).toBe(false)
		T.expect(GamePaths.inAura({ radius = 10 }, O, { x = 0, z = 11 })).toBe(false)
		T.expect(P.inAura({ radius = 10 }, O, { x = 6, z = 6 })).toBe(true)
	end)

	T.it("inAura behind: a cone behind the owner on the target -> owner line", function()
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, TARGET)).toBe(true)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = -5 }, TARGET)).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 5, z = 5 }, TARGET)).toBe(true)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 10, z = 3 }, TARGET)).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 16 }, TARGET)).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 })).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, nil, {})).toBe(false)
		local monsters = { { x = 0, z = -8 }, { x = 0, z = 30 } }
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, nil, monsters)).toBe(true)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, { x = 0, z = 30 })).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, nil, { { x = 0, z = -45 } })).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, O, TARGET)).toBe(false)
		T.expect(GamePaths.inAura(BEHIND, O, { x = 0, z = 5 }, O)).toBe(false)
	end)

	T.it("auras of rows 1-2: full from TEAM_FULL_POINTS in the direction, dip scale below (S138)", function()
		local beacon = P.findNode("fxStorm_beacon") :: any
		local nodes = { fxStorm_beacon = 3, fxStorm_focus = 3 }
		local inside = P.auras(char(20, state(nodes)), {})
		T.expect(#inside).toBe(1)
		T.expect(inside[1].nodeId).toBe("fxStorm_beacon")
		T.expect(inside[1].category).toBe("allyAttack")
		T.expect(inside[1].shape).toBe("circle")
		T.expect(inside[1].radius).toBe(PathData.AURA.radius)
		T.expect(inside[1].stats.magAtk).toBeNear(P.nodeValues(beacon, 3, 1).atk, 1e-9)
		local outside = P.auras(char(20, state({ fxStorm_beacon = 3 })), {})
		T.expect(outside[1].stats.magAtk).toBeNear(P.nodeValues(beacon, 3, 1 / 3).atk, 1e-9)
		T.expect(P.auras(char(20), {})).toEqual({})
		T.expect(GamePaths.auras(char(40, nil, { class = "Warrior" }), {})).toEqual({})
	end)

	T.it("auras of deeper rows: any direction and weapon (S138), the row level", function()
		local copy = deepCopy(Fixture.paths)
		local found = false
		for _, row in copy[1].rows do
			for i, node in row.nodes do
				if node.id == "fxStorm_grit" then
					row.nodes[i] = {
						id = node.id,
						kind = "aura",
						maxRank = 3,
						values = { atk = { 2, 6 } },
						aura = { category = "allyAttack", stats = { physAtk = "atk", magAtk = "atk" } },
						extra = true,
						glyph = node.glyph,
						nameKey = node.nameKey,
						descKey = node.descKey,
					}
					found = true
				end
			end
		end
		T.expect(found).toBe(true)
		local api = GamePaths.withSource(GamePaths.sourceOf(copy, Fixture.skills))
		local c = char(40, state({ fxStorm_grit = 3 }))
		local list = api.auras(c, { main = "staff" })
		T.expect(#list).toBe(1)
		T.expect(list[1].stats).toEqual({ physAtk = 6, magAtk = 6 })
		T.expect(list[1].shape).toBe("circle")
		T.expect(list[1].radius).toBe(30)
		T.expect(#api.auras(c, { main = "runestaff" })).toBe(1)
		T.expect(api.auras(char(32, state({ fxStorm_grit = 3 })), { main = "staff" })).toEqual({}) -- row 5 at 33
	end)

	T.it("ROZWOJ 7.3: party buff rules", function()
		local function buff(id: string, duration: number, cooldown: number, extra: { [string]: any }?): any
			local def: { [string]: any } = {
				id = id,
				class = "Mage",
				order = 1,
				unlock = 1,
				maxLevel = 10,
				type = "groupBuff",
				target = "self",
				cost = 10,
				cooldown = cooldown,
				radius = 20,
				duration = duration,
				values = { v = 10 },
				effects = {
					{
						kind = "statBuff",
						duration = duration,
						stats = { physAtk = "v" },
						pct = true,
						target = "allies",
						category = "allyAttack",
					},
				},
				glyph = "*",
				vfx = "",
				nameKey = "x",
				descKey = "x",
			}
			for key, value in extra or {} do
				def[key] = value
			end
			return def
		end
		local function team(kind: string, duration: number, cooldown: number, category: string?): any
			return buff(kind, duration, cooldown, {
				effects = { { kind = kind, duration = duration, value = "v", target = "allies", category = category } },
			})
		end
		T.expect(#PartyBuffRules.check(buff("ok", 20, 30))).toBe(0)
		T.expect(#PartyBuffRules.check(buff("short", 6, 30)) > 0).toBe(true)
		T.expect(#PartyBuffRules.check(buff("long", 70, 90)) > 0).toBe(true)
		T.expect(#PartyBuffRules.check(buff("wide", 20, 30, { radius = 45 })) > 0).toBe(true)
		T.expect(#PartyBuffRules.check(buff("spam", 20, 15)) > 0).toBe(true)
		T.expect(PartyBuffRules.check(team("damageReduction", 6, 20, "allyGuard"))).toEqual({})
		T.expect(PartyBuffRules.check(team("intercept", 4, 20))).toEqual({})
		T.expect(PartyBuffRules.check(team("invuln", 3, 30))).toEqual({})
		T.expect(PartyBuffRules.check(buff("shield", 4, 12, { type = "shield", effects = {} }))).toEqual({})
		T.expect(#PartyBuffRules.check(team("damageReduction", 12, 8, "allyGuard")) > 0).toBe(true)
		-- own effects of a group buff are not party effects
		local own = buff("own", 3, 30)
		own.effects[1].target = nil
		own.effects[1].category = "own"
		T.expect(PartyBuffRules.check(own)).toEqual({})
		for _, path in Fixture.paths do
			T.expect(PartyBuffRules.checkAuras(path)).toEqual({})
		end
	end)
end)

T.describe("Data: Paths (game)", function()
	-- S67: item weights of paths name known axes, stats and traits (Logic/ItemScore.validateWeights).
	T.it("item weights of paths are valid", function()
		for _, path in PathData.list do
			if path.itemWeights then
				T.expect({ path.id, ItemScore.validateWeights(path.itemWeights) }).toEqual({ path.id, {} })
			end
		end
		for _, path in Fixture.paths do
			if path.itemWeights then
				T.expect({ path.id, ItemScore.validateWeights(path.itemWeights) }).toEqual({ path.id, {} })
			end
		end
	end)

	local function isTeamEffect(effect: any): boolean
		return type(effect) == "table" and not EffectStack.isOwn(effect.category)
	end

	T.it("every class with paths passes the checks", function()
		local classes: { [string]: boolean } = {}
		for _, path in PathData.list do
			classes[path.class] = true
		end
		for classId in classes do
			local paths = GamePaths.pathsOf(classId)
			T.expect(#paths >= 2 and #paths <= 3).toBe(true)
			T.expect(problems(GamePaths, classId)).toEqual({})
			-- S61 (ROZWOJ 7.3): party buff rules for every skill and aura of a class with paths
			for _, skill in SkillData.byClass[classId] or {} do
				T.expect(PartyBuffRules.check(skill)).toEqual({})
			end
			for _, path in paths do
				T.expect(PartyBuffRules.checkAuras(path)).toEqual({})
			end
			-- S138 (DESIGN-18 §7): 50 points hold one whole direction with its capstone and upgrade, never two
			for _, main in paths do
				T.expect({ main.id, wholeOf(main) <= GamePaths.pointsAt(100) }).toEqual({ main.id, true })
				for _, other in paths do
					if other ~= main then
						T.expect(wholeOf(main) + wholeOf(other) > GamePaths.pointsAt(100)).toBe(true)
					end
				end
			end
			-- weapons: every class weapon fits some path, every off-hand with some one-handed weapon
			local class = Classes.get(classId) :: any
			local function fitsSome(weapons: any): boolean
				for _, path in paths do
					if GamePaths.weaponOk(path.weapon, weapons) then
						return true
					end
				end
				return false
			end
			for _, main in class.weaponTypes do
				local ok = fitsSome({ main = main })
				for _, off in class.offhandTypes do
					ok = ok or fitsSome({ main = main, offhand = off })
				end
				T.expect({ classId, main, ok }).toEqual({ classId, main, true })
			end
			for _, off in class.offhandTypes do
				local ok = false
				for _, main in class.weaponTypes do
					ok = ok or fitsSome({ main = main, offhand = off })
				end
				T.expect({ classId, off, ok }).toEqual({ classId, off, true })
			end
		end
	end)

	-- S138 (DESIGN-18 §7): skill nodes sit in SKILL_ROWS, at most one per row of a direction; asserted only for classes
	-- whose pools are no longer transitional (the class sessions S140-S145 move them out of rows 1, 7 and 10)
	T.it("skill nodes in SKILL_ROWS for classes past their transitional pools", function()
		local checked = 0
		for _, classId in Classes.order do
			if not SkillPools.isTransitional(classId) then
				for _, path in GamePaths.pathsOf(classId) do
					for r, row in path.rows do
						local count = 0
						for _, n in row.nodes do
							count += if n.kind == "skill" then 1 else 0
						end
						if count > 0 then
							checked += 1
							T.expect({ path.id, r, table.find(PathData.SKILL_ROWS, r) ~= nil, count <= 1 })
								.toEqual({ path.id, r, true, true })
						end
					end
				end
			end
		end
		T.expect(checked >= 0).toBe(true)
	end)

	T.it("texts, rule A, team nodes and reference builds", function()
		for _, path in PathData.list do
			for _, key in { path.nameKey, path.descKey } do
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
			for r, row in path.rows do
				for _, n in row.nodes do
					if n.kind ~= "skill" then
						for _, key in { n.nameKey, n.descKey } do
							T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
						end
					end
					if r == 1 and n.kind == "skill" then
						local skill = SkillData.get(n.skill or "") :: any
						local today = TODAY_UNLOCK[n.skill or ""]
						T.expect({ n.id, today ~= nil and today <= 34 }).toEqual({ n.id, true })
						local effects = {}
						for _, e in skill.effects or {} do
							table.insert(effects, e)
						end
						-- ROZWOJ 2.2 (S71 reads it as written): only effects with a category other than "own" break
						-- rule A; an invulnerability without a category (Resurrection 10A) is allowed.
						for _, e in skill.allyEffects or {} do
							table.insert(effects, e)
						end
						for _, at in Skills.BREAKPOINT_LEVELS do
							local pair = skill.breakpoints and skill.breakpoints[at]
							for _, option in { pair and pair.a, pair and pair.b } do
								for _, key in { "effect", "selfEffect", "allyEffect" } do
									if option and option[key] then
										table.insert(effects, option[key])
									end
								end
								for _, key in { "effects", "selfEffects", "allyEffects" } do
									for _, e in (option and option[key]) or {} do
										table.insert(effects, e)
									end
								end
							end
						end
						for _, e in effects do
							T.expect({ n.id, isTeamEffect(e) }).toEqual({ n.id, false })
						end
					end
					if r <= PathData.DIP_ROWS and GamePaths.isTeamNode(n) then
						-- S138: below TEAM_FULL_POINTS in its direction a team node is weaker, from it in full
						local outside = char(100, state({ [n.id] = n.maxRank }), { class = path.class })
						T.expect(GamePaths.nodeScale(outside, path.id, r, n) < 1).toBe(true)
						local full = char(100, state(teamFull(path.id, { [n.id] = n.maxRank })), { class = path.class })
						T.expect(GamePaths.nodeScale(full, path.id, r, n)).toBe(1)
					end
				end
			end
			for _, build in path.reference do
				checkReference(GamePaths, path, build)
			end
		end
	end)
end)

-- S71: the Cleric on real paths (ROZWOJ 9), the data rules every class session copies -----------------------------

T.describe("Data: Cleric paths (S71)", function()
	local fs = require("@lune/fs")
	local BreakpointKeys = require("./BreakpointKeys")
	local Locale = require("../src/shared/Util/Locale")

	local function cleric(_main: string?, nodes: { [string]: number }): any
		return char(100, state(nodes, {}), { class = "Cleric" })
	end

	-- Every .luau file under a directory (as tests/data.spec).
	local function sources(dir: string, out: { string }): { string }
		for _, name in fs.readDir(dir) do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				sources(path, out)
			elseif string.match(name, "%.luau$") then
				table.insert(out, path)
			end
		end
		return out
	end

	-- Main and off-hand that fit a path's weapon rule (a one-handed main when only the off-hand is required).
	local function weaponsFor(path: any): any
		local req = path.weapon
		local class = Classes.get(path.class) :: any
		local main = req.main and req.main[1]
		if not main then
			for _, t in class.weaponTypes do
				if not GamePaths.isTwoHanded(t) then
					main = t
					break
				end
			end
		end
		local offhand = req.offhand and req.offhand[1]
		return { main = main, offhand = offhand }
	end

	T.it("weapons of the three paths and the off-hand nodes of row 3", function()
		local function ok(pathId: string, main: string?, offhand: string?): boolean
			return GamePaths.weaponOk((PathData.get(pathId) :: any).weapon, { main = main, offhand = offhand })
		end
		T.expect(ok("healer", "scepter", "shield")).toBe(true)
		T.expect(ok("healer", "holystaff")).toBe(true)
		T.expect(ok("healer", "mace1h")).toBe(false)
		T.expect(ok("fortune", "mace1h", "relic")).toBe(true)
		T.expect(ok("fortune", "scepter", "relic")).toBe(true)
		T.expect(ok("fortune", "holystaff")).toBe(false)
		T.expect(ok("fortune", "mace1h", "shield")).toBe(false)
		T.expect(ok("inquisitor", "flail1h", "relic")).toBe(true)
		T.expect(ok("inquisitor", "mace1h", "shield")).toBe(true)
		T.expect(ok("inquisitor", "scepter")).toBe(false)
		local c = cleric("inquisitor", { inquisitor_shield = 3, inquisitor_relic = 3 })
		local function active(weapons: any, id: string): boolean
			for _, a in GamePaths.activeNodes(c, weapons) do
				if a.node.id == id then
					return true
				end
			end
			return false
		end
		T.expect(active({ main = "mace1h", offhand = "shield" }, "inquisitor_shield")).toBe(true)
		T.expect(active({ main = "mace1h", offhand = "relic" }, "inquisitor_shield")).toBe(false)
		T.expect(active({ main = "mace1h", offhand = "relic" }, "inquisitor_relic")).toBe(true)
		T.expect(active({ main = "mace1h", offhand = "shield" }, "inquisitor_relic")).toBe(false)
		-- coverage: every Cleric weapon and off-hand fits a path (two-handed rule included)
		local class = Classes.get("Cleric") :: any
		for _, t in class.weaponTypes do
			local fits = false
			for _, path in GamePaths.pathsOf("Cleric") do
				fits = fits or GamePaths.weaponOk(path.weapon, { main = t })
				for _, off in class.offhandTypes do
					fits = fits
						or (
							not GamePaths.isTwoHanded(t)
							and GamePaths.weaponOk(path.weapon, { main = t, offhand = off })
						)
				end
			end
			T.expect({ t, fits }).toEqual({ t, true })
		end
		for _, off in { "shield", "relic" } do
			local fits = false
			for _, path in GamePaths.pathsOf("Cleric") do
				fits = fits or GamePaths.weaponOk(path.weapon, { main = "mace1h", offhand = off })
			end
			T.expect({ off, fits }).toEqual({ off, true })
		end
	end)

	T.it("ranks: 42 per main path, 10 in rows 1-2 of the others, 50 / 62 coverage", function()
		local paths = GamePaths.pathsOf("Cleric")
		T.expect(#paths).toBe(3)
		for _, main in paths do
			T.expect({ main.id, pathRanks(main, 1, #PathData.ROWS) }).toEqual({ main.id, 42 })
			local total = 42
			for _, other in paths do
				if other ~= main then
					T.expect({ other.id, pathRanks(other, 1, PathData.DIP_ROWS) }).toEqual({ other.id, 10 })
					total += 10
				end
			end
			T.expect(total).toBe(62)
			T.expect(wholeOf(main) <= GamePaths.pointsAt(100)).toBe(true) -- S138: one whole direction
		end
	end)

	T.it("Evil Eye works at 1/3 below TEAM_FULL_POINTS in Fortune (dip scale, S138)", function()
		local relic = { main = "mace1h", offhand = "relic" }
		local skill = SkillData.get("holyStrike") :: any
		local function misfortune(nodes: { [string]: number }): number
			local c = cleric(nil, nodes)
			local def = Skills.effective(skill, 10, {}, GamePaths.skillMods(c, "holyStrike", relic), true)
			return Skills.valueAt(def, "misfortune", 10)
		end
		T.expect(misfortune(teamFull("fortune", { fortune_evilEye = 3 }))).toBeNear(6, 1e-9)
		T.expect(misfortune({ fortune_evilEye = 3 })).toBeNear(2, 1e-9)
	end)

	T.it("model builds spend exactly 50 and name usable breakpoints", function()
		for _, path in GamePaths.pathsOf("Cleric") do
			T.expect(#path.reference > 0).toBe(true)
			for _, build in path.reference do
				T.expect({ build.id, build.damageReference }).toEqual({ build.id, nil })
				T.expect(build.stats).toEqual(path.statPlan)
				local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
				T.expect({ build.id, GamePaths.weaponOk(path.weapon, weapons) }).toEqual({ build.id, true })
				local nodes: { [string]: number } = {}
				local c = cleric(path.id, nodes)
				for _, entry in build.nodes do
					for _ = 1, entry[2] do
						local can, why = GamePaths.canBuy(c, entry[1])
						T.expect({ build.id, entry[1], can, why }).toEqual({ build.id, entry[1], true, nil })
						nodes[entry[1]] = (nodes[entry[1]] or 0) + 1
					end
				end
				T.expect({ build.id, GamePaths.spent(c) }).toEqual({ build.id, GamePaths.pointsAt(100) })
				local available = availableAny(c)
				for key in build.bp do
					local skillId, at = string.match(key, "^(.+):(%d+)$")
					T.expect({ key, at == "5" or at == "10" }).toEqual({ key, true })
					T.expect({ key, table.find(available, skillId or "") ~= nil }).toEqual({ key, true })
				end
				for _, step in build.rotation do
					T.expect({ build.id, step.skill, table.find(available, step.skill) ~= nil })
						.toEqual({ build.id, step.skill, true })
				end
			end
		end
	end)

	T.it("every passive hook of a path node has a receiver in the code", function()
		local files = sources("src/server", {})
		sources("src/shared/Logic", files)
		local texts: { string } = {}
		for _, file in files do
			table.insert(texts, fs.readFile(file))
		end
		-- hooks read through a name built in code (none yet): id -> why
		local BUILT: { [string]: string } = {}
		for _, path in PathData.list do
			for _, row in path.rows do
				for _, n in row.nodes do
					for hook in (n.passive and n.passive.hooks) or {} do
						local found = BUILT[hook] ~= nil
						for _, text in texts do
							if found then
								break
							end
							found = string.find(text, `"{hook}"`, 1, true) ~= nil
						end
						T.expect({ n.id, hook, found }).toEqual({ n.id, hook, true })
					end
				end
			end
		end
	end)

	T.it("modify.bp keys are breakpoint keys and node effects follow the S53 category rules", function()
		-- S71: node effects pass the same rules as skill breakpoints (EffectCategoryRules), per skill
		local bySkill: { [string]: { { id: string, bp: any } } } = {}
		for _, path in PathData.list do
			for _, row in path.rows do
				for _, n in row.nodes do
					local bp = n.modify and n.modify.bp
					for key in bp or {} do
						T.expect({ n.id, key, BreakpointKeys[key] == true }).toEqual({ n.id, key, true })
					end
					if n.modify and bp then
						local list = bySkill[n.modify.skill] or {}
						bySkill[n.modify.skill] = list
						table.insert(list, { id = n.id, bp = bp })
					end
				end
			end
		end
		local all: { string } = {}
		for skillId, nodes in bySkill do
			local skill = SkillData.byId[skillId]
			T.expect({ skillId, skill ~= nil }).toEqual({ skillId, true })
			if skill then
				for _, problem in EffectCategoryRules.problems(skill, nodes) do
					table.insert(all, problem)
				end
			end
		end
		T.expect(all).toEqual({})
	end)

	T.it("node descriptions resolve every placeholder; multipliers give <field>Pct", function()
		for _, path in PathData.list do
			for _, row in path.rows do
				for _, n in row.nodes do
					if n.kind ~= "skill" then
						for _, rank in { 1, n.maxRank } do
							local args = GamePaths.nodeArgs(n, rank)
							for _, lang in { "pl", "en" } do
								local text = Locale.T(n.descKey, args, lang)
								T.expect({ n.id, lang, rank, string.find(text, "{", 1, true) })
									.toEqual({ n.id, lang, rank, nil })
							end
						end
					end
				end
			end
		end
		local salvation = GamePaths.findNode("healer_salvation") :: any
		local one, three = GamePaths.nodeArgs(salvation, 1), GamePaths.nodeArgs(salvation, 3)
		T.expect({ one.salvationPct, three.salvationPct }).toEqual({ 8, 25 })
		T.expect(GamePaths.nodeArgs(salvation, 2).salvationPct).toBe(16.5)
		T.expect({ one.salvation, three.salvation }).toEqual({ Skills.roundArg(0.92), Skills.roundArg(0.75) })
		T.expect(P.nodeArgs(P.findNode("fxStorm_surge") :: any, 1).cdPct).toBe(10)
		for key in GamePaths.nodeArgs(GamePaths.findNode("healer_grace") :: any, 3) do
			T.expect(string.find(key, "Pct$")).toBeNil()
		end
	end)

	T.it("ROZWOJ 7.3 with every modify node at max rank, each path as the main one", function()
		local classes: { [string]: boolean } = {}
		for _, path in PathData.list do
			classes[path.class] = true
		end
		for classId in classes do
			local all: { [string]: number } = {}
			for _, path in GamePaths.pathsOf(classId) do
				for _, row in path.rows do
					for _, n in row.nodes do
						all[n.id] = n.maxRank
					end
				end
			end
			for _, main in GamePaths.pathsOf(classId) do
				local c = char(100, state(all, {}), { class = classId })
				local weapons = weaponsFor(main)
				for _, skill in SkillData.byClass[classId] do
					local mods = GamePaths.skillMods(c, skill.id, weapons)
					T.expect({ main.id, PartyBuffRules.check(skill, mods) }).toEqual({ main.id, {} })
				end
				T.expect(PartyBuffRules.checkAuras(main)).toEqual({})
			end
		end
	end)
end)

-- S75: the Warrior on real paths (ROZWOJ 10) ---------------------------------------------------------------------------

T.describe("Data: Warrior paths (S75)", function()
	local function warrior(_main: string?, nodes: { [string]: number }, bp: { [string]: string }?): any
		return char(100, state(nodes, bp or {}), { class = "Warrior" })
	end

	local function ok(pathId: string, main: string?, offhand: string?): boolean
		return GamePaths.weaponOk((PathData.get(pathId) :: any).weapon, { main = main, offhand = offhand })
	end

	local function active(c: any, weapons: any, id: string): boolean
		for _, a in GamePaths.activeNodes(c, weapons) do
			if a.node.id == id then
				return true
			end
		end
		return false
	end

	T.it("weapons of the three paths and the Block node", function()
		T.expect(ok("berserker", "axe2h")).toBe(true)
		T.expect(ok("berserker", "sword1h", "shield")).toBe(false)
		T.expect(ok("guardian", "sword1h")).toBe(false)
		T.expect(ok("guardian", "axe1h", "shield")).toBe(true)
		T.expect(ok("guardian", "sword2h")).toBe(false)
		T.expect(ok("standard", "saber1h")).toBe(true)
		T.expect(ok("standard", "saber1h", "shield")).toBe(true)
		T.expect(ok("standard", "spear2h")).toBe(false)
		T.expect(ok("standard", "axe1h")).toBe(false)
		-- Block: own shield requirement in row 2, also outside the main path
		local c = warrior("berserker", { guardian_block = 3 })
		T.expect(active(c, { main = "axe2h" }, "guardian_block")).toBe(false)
		T.expect(active(c, { main = "mace1h", offhand = "shield" }, "guardian_block")).toBe(true)
		-- coverage: every Warrior weapon and the shield fit a path; axe1h and mace1h only with a shield
		local class = Classes.get("Warrior") :: any
		for _, t in class.weaponTypes do
			local bare, shielded = false, false
			for _, path in GamePaths.pathsOf("Warrior") do
				bare = bare or GamePaths.weaponOk(path.weapon, { main = t })
				shielded = shielded
					or (
						not GamePaths.isTwoHanded(t)
						and GamePaths.weaponOk(path.weapon, { main = t, offhand = "shield" })
					)
			end
			T.expect({ t, bare or shielded }).toEqual({ t, true })
			if t == "axe1h" or t == "mace1h" then
				T.expect({ t, bare, shielded }).toEqual({ t, false, true })
			end
		end
	end)

	T.it("ranks: 42 per main path, 10 in rows 1-2 of the others, 50 / 62 coverage, 60 nodes", function()
		local paths = GamePaths.pathsOf("Warrior")
		T.expect(#paths).toBe(3)
		local nodes, skills = 0, 0
		for _, main in paths do
			T.expect(main.wiki).toBe(false)
			T.expect({ main.id, pathRanks(main, 1, #PathData.ROWS) }).toEqual({ main.id, 42 })
			local total = 42
			for _, other in paths do
				if other ~= main then
					T.expect({ other.id, pathRanks(other, 1, PathData.DIP_ROWS) }).toEqual({ other.id, 10 })
					total += 10
				end
			end
			T.expect(total).toBe(62)
			T.expect(wholeOf(main) <= GamePaths.pointsAt(100)).toBe(true) -- S138: one whole direction
			for _, row in main.rows do
				for _, n in row.nodes do
					nodes += 1
					skills += if n.kind == "skill" then 1 else 0
				end
			end
		end
		T.expect({ nodes, skills }).toEqual({ 60, 12 })
	end)

	T.it("model builds spend exactly 50; Fury is the only damage reference", function()
		local references = {}
		for _, path in PathData.list do
			for _, build in path.reference do
				if build.damageReference then
					table.insert(references, `{path.id}:{build.id}:{build.weapon.main}`)
				end
			end
		end
		T.expect(references).toEqual({ "berserker:fury:axe2h" })
		for _, path in GamePaths.pathsOf("Warrior") do
			T.expect(#path.reference).toBe(2)
			for _, build in path.reference do
				T.expect(build.stats).toEqual(path.statPlan)
				local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
				T.expect({ build.id, GamePaths.weaponOk(path.weapon, weapons) }).toEqual({ build.id, true })
				local nodes: { [string]: number } = {}
				local c = warrior(path.id, nodes)
				for _, entry in build.nodes do
					for _ = 1, entry[2] do
						local can, why = GamePaths.canBuy(c, entry[1])
						T.expect({ build.id, entry[1], can, why }).toEqual({ build.id, entry[1], true, nil })
						nodes[entry[1]] = (nodes[entry[1]] or 0) + 1
					end
				end
				T.expect({ build.id, GamePaths.spent(c) }).toEqual({ build.id, GamePaths.pointsAt(100) })
				local available = availableAny(c)
				for key in build.bp do
					local skillId, at = string.match(key, "^(.+):(%d+)$")
					local def = SkillData.get(skillId or "") :: any
					T.expect({ key, at == "5" or at == "10", def ~= nil and def.type ~= "passive" })
						.toEqual({ key, true, true })
					T.expect({ key, table.find(available, skillId or "") ~= nil }).toEqual({ key, true })
				end
				for _, step in build.rotation do
					T.expect({ build.id, step.skill, table.find(available, step.skill) ~= nil })
						.toEqual({ build.id, step.skill, true })
				end
			end
		end
	end)

	T.it("Cover at 1/3 below TEAM_FULL_POINTS in Guardian (S138)", function()
		local shield = { main = "sword1h", offhand = "shield" }
		local function cover(nodes: { [string]: number }): number
			for _, aura in GamePaths.auras(warrior(nil, nodes), shield) do
				if aura.nodeId == "guardian_cover" then
					return aura.stats.value
				end
			end
			return 0
		end
		T.expect(cover(teamFull("guardian", { guardian_cover = 3 }))).toBeNear(10, 1e-9)
		T.expect(cover({ guardian_cover = 3 })).toBeNear(10 / 3, 1e-9)
	end)

	-- Composition with nodes (ROZWOJ 2.7): Skills.effective(skill, rank, choices, Paths.skillMods(...)).
	local function eff(
		skillId: string,
		main: string,
		nodes: { [string]: number },
		bp: { [string]: string },
		weapons: any
	): (any, any)
		local c = warrior(main, nodes, bp)
		local skill = SkillData.get(skillId) :: any
		return Skills.effective(skill, 10, bp :: any, GamePaths.skillMods(c, skillId, weapons), true)
	end
	local SABER = { main = "saber1h" }
	local SHIELD = { main = "sword1h", offhand = "shield" }
	local AXE = { main = "axe2h" }
	local function effectOf(list: { any }?, kind: string): any
		for _, e in list or {} do
			if e.kind == kind then
				return e
			end
		end
		return nil
	end

	T.it("Battle Cry: Fervor, Battle Breath, Commander's Voice and Hold the Line!", function()
		local d1 = eff("battleCry", "standard", { standard_fervor = 3 }, { ["battleCry:5"] = "b" }, SABER)
		T.expect(Skills.valueAt(d1, "atk", 10)).toBeNear(31, 1e-9) -- S89: 16 + 3 + 12
		local d2 = eff("battleCry", "standard", { standard_breath = 3 }, { ["battleCry:10"] = "a" }, SABER)
		T.expect(Skills.scaled(d2, d2.cooldown, 10)).toBeNear(30, 1e-9)
		T.expect((Skills.cost(d2, 10, 100, "Warrior"))).toBeNear(10, 1e-9)
		local nodes = { standard_command = 3, standard_formation = 3 }
		local d3 = eff("battleCry", "standard", nodes, { ["battleCry:10"] = "b" }, SABER)
		T.expect(#d3.allyEffects).toBe(2)
		local attack = d3.allyEffects[1]
		local vigor = d3.allyEffects[2]
		T.expect({ attack.category, Skills.valueAt(d3, attack.stats.physAtk, 10), attack.duration })
			.toEqual({ "allyAttack", 3, 24 })
		T.expect({ vigor.category, Skills.valueAt(d3, vigor.stats.armor, 10), vigor.duration })
			.toEqual({ "allyVigor", 9, 24 })
		T.expect(d3.effects[1].category).toBe("own")
		-- S138: below TEAM_FULL_POINTS in Standard the team node works at 1/3
		local d4 = eff("battleCry", "guardian", { standard_command = 3 }, { ["battleCry:10"] = "b" }, SHIELD)
		T.expect(Skills.valueAt(d4, "cmdAtk", 10)).toBeNear(1, 1e-9)
		-- S138: no direction weapon: rows 3+ work with an axe as with a saber
		local both = { standard_fervor = 3, standard_command = 3 }
		local d5 = eff("battleCry", "standard", both, {}, AXE)
		local d6 = eff("battleCry", "standard", both, {}, SABER)
		T.expect(Skills.valueAt(d5, "atk", 10)).toBeNear(Skills.valueAt(d6, "atk", 10), 1e-9)
		T.expect(Skills.valueAt(d5, "atk", 10) > 16).toBe(true)
		T.expect(Skills.valueAt(d5, "cmdAtk", 10)).toBeNear(3, 1e-9)
	end)

	T.it("War Banner, Crushing Blow, Titan's Wrath", function()
		local bp = { ["warBanner:5"] = "a", ["warBanner:10"] = "a" }
		local banner = eff("warBanner", "standard", { standard_wide = 3, standard_colours = 3 }, bp, SABER)
		T.expect(banner.radius).toBe(26)
		T.expect(Skills.scaled(banner, banner.duration, 10)).toBeNear(18, 1e-9)
		local blow = eff("crushingBlow", "standard", { standard_sunder = 3 }, { ["crushingBlow:5"] = "a" }, SABER)
		T.expect(effectOf(blow.effects, "armorBreak").duration).toBeNear(12, 1e-9)
		T.expect(effectOf(blow.effects, "stun").duration).toBeNear(0.7, 1e-9)
		local wrath = eff("titansWrath", "berserker", { berserker_thunder = 3 }, { ["titansWrath:10"] = "b" }, AXE)
		T.expect({ wrath.hits, Skills.valueAt(wrath, "dmg", 10) }).toEqual({ 4, 135 }) -- S89
		T.expect(Skills.scaled(wrath, wrath.cooldown, 10)).toBeNear(36, 1e-9)
	end)

	T.it("Shield Wall, Intercept, Carnage", function()
		local bp = { ["shieldWall:5"] = "a", ["shieldWall:10"] = "a" }
		local wall = eff("shieldWall", "guardian", { guardian_fortress = 3, guardian_shieldWall2 = 2 }, bp, SHIELD)
		T.expect(wall.radius).toBe(20)
		T.expect(Skills.scaled(wall, wall.cooldown, 10)).toBeNear(45, 1e-9)
		T.expect(effectOf(wall.effects, "intercept").duration).toBeNear(10, 1e-9)
		T.expect(Skills.valueAt(wall, "share", 10)).toBeNear(30, 1e-9)

		local nodes = { guardian_sacrifice = 3, guardian_aegis = 3 }
		local guard, behaviour = eff("intercept", "guardian", nodes, { ["intercept:5"] = "a" }, SHIELD)
		T.expect(effectOf(guard.effects, "intercept").duration).toBeNear(7.5, 1e-9)
		local own = guard.selfEffects[1]
		T.expect({ own.kind, own.value, Skills.valueAt(guard, "sacrificeGuard", 10) })
			.toEqual({ "damageReduction", "sacrificeGuard", 15 })
		T.expect(own.duration).toBeNear(7.5, 1e-9)
		T.expect(Skills.resolve(guard, behaviour.allyShield.hpPct, 10)).toBeNear(15, 1e-9)

		local carnage = eff("carnage", "berserker", { berserker_carnage2 = 2 }, { ["carnage:5"] = "a" }, AXE)
		local effect = effectOf(carnage.effects, "carnage")
		T.expect({ effect.duration, effect.value, Skills.valueAt(carnage, "furyRestore", 10) })
			.toEqual({ 12, "furyRestore", 10 })
		local plain = eff("carnage", "berserker", {}, {}, AXE)
		T.expect(Skills.valueAt(plain, "furyRestore", 10)).toBe(0)
	end)
end)

-- S78: the Hunter on real paths (ROZWOJ 11) ----------------------------------------------------------------------------

T.describe("Data: Hunter paths (S78)", function()
	local TooltipModel = require("../src/shared/Logic/TooltipModel")

	local function hunter(_main: string?, nodes: { [string]: number }): any
		return char(100, state(nodes, {}), { class = "Hunter" })
	end

	local function ok(pathId: string, main: string?, offhand: string?): boolean
		return GamePaths.weaponOk((PathData.get(pathId) :: any).weapon, { main = main, offhand = offhand })
	end

	T.it("weapons of the three paths and their coverage", function()
		T.expect(ok("marksman", "longbow")).toBe(true)
		T.expect(ok("marksman", "longbow", "quiver")).toBe(true)
		T.expect(ok("marksman", "heavycrossbow")).toBe(true)
		for _, t in { "bow", "crossbow", "shortbow" } do
			T.expect({ t, ok("marksman", t) }).toEqual({ t, false })
		end
		T.expect(ok("trapper", "crossbow")).toBe(true)
		T.expect(ok("trapper", "bow", "quiver")).toBe(true)
		for _, t in { "longbow", "heavycrossbow", "shortbow" } do
			T.expect({ t, ok("trapper", t) }).toEqual({ t, false })
		end
		T.expect(ok("scout", "shortbow")).toBe(true)
		T.expect(ok("scout", "bow")).toBe(true)
		for _, t in { "longbow", "crossbow", "heavycrossbow" } do
			T.expect({ t, ok("scout", t) }).toEqual({ t, false })
		end
		-- every Hunter weapon fits a path, the bow exactly two, the quiver all three
		local class = Classes.get("Hunter") :: any
		for _, t in class.weaponTypes do
			local fits = {}
			for _, path in GamePaths.pathsOf("Hunter") do
				if GamePaths.weaponOk(path.weapon, { main = t, offhand = "quiver" }) then
					table.insert(fits, path.id)
				end
			end
			T.expect({ t, #fits >= 1 }).toEqual({ t, true })
			if t == "bow" then
				T.expect(fits).toEqual({ "trapper", "scout" })
			end
		end
		T.expect(class.offhandTypes).toEqual({ "quiver" })
		for _, path in GamePaths.pathsOf("Hunter") do
			T.expect({ path.id, path.weapon.offhand }).toEqual({ path.id, nil })
		end
		-- S138: a bow in a Marksman's hands: no direction weapon, row 3 (Slayer) works as row 2 (Rhythm)
		local c = hunter(nil, { marksman_slayer = 3, marksman_rhythm = 3 })
		local hooks = GamePaths.passiveTotals(c, { main = "bow" }).hooks
		T.expect(hooks.bossDamage ~= nil).toBe(true)
		T.expect(hooks.bossDamage).toBe(GamePaths.passiveTotals(c, { main = "longbow" }).hooks.bossDamage)
		local mods = GamePaths.skillMods(c, "aimedShot", { main = "bow" })
		T.expect(#mods).toBe(1)
		T.expect(mods[1].critCdr).toBeNear(50, 1e-9)
	end)

	T.it("ranks: 42 / 42 / 40 per main path, 10 in rows 1-2 of the others, 60 nodes, 12 skill nodes", function()
		local paths = GamePaths.pathsOf("Hunter")
		T.expect(#paths).toBe(3)
		local want = { marksman = 42, trapper = 42, scout = 40 }
		local nodes, skills = 0, 0
		for _, main in paths do
			T.expect(main.wiki).toBe(false)
			T.expect({ main.id, pathRanks(main, 1, #PathData.ROWS) }).toEqual({ main.id, want[main.id] })
			local total = want[main.id]
			for _, other in paths do
				if other ~= main then
					T.expect({ other.id, pathRanks(other, 1, PathData.DIP_ROWS) }).toEqual({ other.id, 10 })
					total += 10
				end
			end
			T.expect(total > GamePaths.pointsAt(100)).toBe(true)
			T.expect(wholeOf(main) <= GamePaths.pointsAt(100)).toBe(true) -- S138: one whole direction
			for _, row in main.rows do
				for _, n in row.nodes do
					nodes += 1
					skills += if n.kind == "skill" then 1 else 0
				end
			end
		end
		T.expect({ nodes, skills }).toEqual({ 60, 12 })
		T.expect((GamePaths.findNode("scout_royalFalcon") :: any).kind).toBe("keystone")
	end)

	T.it("team hooks of the Scout's rows 1-2 at 1/3 below TEAM_FULL_POINTS in Scout (S138)", function()
		local nodes = { scout_eye = 3, scout_spotting = 3, scout_vigilance = 3 }
		local outside = GamePaths.passiveTotals(hunter(nil, { scout_eye = 3, scout_spotting = 2 }), {}).hooks
		T.expect(outside.minimapEliteBonus).toBeNear(60, 1e-9)
		local spotting = GamePaths.findNode("scout_spotting") :: any
		local field = (spotting.passive.hooks :: any).spotOnHit
		T.expect(outside.spotOnHit).toBeNear(GamePaths.nodeValues(spotting, 2, 1 / 3)[field], 1e-9)
		local inside = GamePaths.passiveTotals(hunter(nil, nodes), { main = "longbow" }).hooks
		T.expect(inside.minimapEliteBonus).toBeNear(180, 1e-9)
		T.expect(inside.spotOnHit).toBeNear(6, 1e-9)
		T.expect(inside.vigilanceMove).toBeNear(20, 1e-9)
		local team = {}
		for _, path in GamePaths.pathsOf("Hunter") do
			for _, row in path.rows do
				for _, n in row.nodes do
					if GamePaths.isTeamNode(n) then
						table.insert(team, n.id)
					end
				end
			end
		end
		table.sort(team)
		T.expect(team).toEqual({ "scout_eye", "scout_spotting", "scout_vigilance" })
		-- the keystone's hook counts like any passive
		local royal = GamePaths.passiveTotals(hunter("scout", { scout_royalFalcon = 1 }), { main = "bow" }).hooks
		T.expect(royal.royalFalcon).toBe(1)
	end)

	T.it("Falcon Bond text value bondDive follows HOOK_RULES.royalFalcon.bondDive", function()
		local bond = GamePaths.findNode("scout_bond") :: any
		local perSecond = (PathData.HOOK_RULES :: any).royalFalcon.bondDive
		for _, rank in { 1, bond.maxRank } do
			local args = GamePaths.nodeArgs(bond, rank)
			T.expect({ rank, args.bondDive }).toEqual({ rank, args.bond * perSecond })
		end
	end)

	T.it("model builds spend exactly 50; the Trapper's are R7-exempt; Fury stays the only damage reference", function()
		local exempt = {}
		for _, path in GamePaths.pathsOf("Hunter") do
			T.expect(#path.reference).toBe(2)
			for _, build in path.reference do
				T.expect({ build.id, build.damageReference }).toEqual({ build.id, nil })
				if build.r7Exempt then
					table.insert(exempt, build.id)
				end
				T.expect(build.stats).toEqual(path.statPlan)
				T.expect(build.weapon.offhand).toBe("quiver")
				local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
				T.expect({ build.id, GamePaths.weaponOk(path.weapon, weapons) }).toEqual({ build.id, true })
				local nodes: { [string]: number } = {}
				local c = hunter(path.id, nodes)
				for _, entry in build.nodes do
					for _ = 1, entry[2] do
						local can, why = GamePaths.canBuy(c, entry[1])
						T.expect({ build.id, entry[1], can, why }).toEqual({ build.id, entry[1], true, nil })
						nodes[entry[1]] = (nodes[entry[1]] or 0) + 1
					end
				end
				T.expect({ build.id, GamePaths.spent(c) }).toEqual({ build.id, GamePaths.pointsAt(100) })
				local available = availableAny(c)
				for key in build.bp do
					local skillId, at = string.match(key, "^(.+):(%d+)$")
					local def = SkillData.get(skillId or "") :: any
					T.expect({ key, at == "5" or at == "10", def ~= nil and def.type ~= "passive" })
						.toEqual({ key, true, true })
					T.expect({ key, table.find(available, skillId or "") ~= nil }).toEqual({ key, true })
				end
				for _, step in build.rotation do
					T.expect({ build.id, step.skill, table.find(available, step.skill) ~= nil })
						.toEqual({ build.id, step.skill, true })
				end
			end
		end
		table.sort(exempt)
		T.expect(exempt).toEqual({ "poacher", "poisoner" })
		local references = {}
		for _, path in PathData.list do
			for _, build in path.reference do
				if build.damageReference then
					table.insert(references, build.id)
				end
			end
		end
		T.expect(references).toEqual({ "fury" })
	end)

	T.it("weapon traits list the Trapper's nodes (S68 nodeHooks)", function()
		local trapperPaths = { PathData.get("trapper") }
		local function names(traitId: string): { string }
			local out = {}
			for _, entry in TooltipModel.traitNodes(traitId, trapperPaths, nil, "pl") do
				table.insert(out, entry.node)
			end
			return out
		end
		T.expect(names("easyPrey")).toEqual({ "Uwięzienie", "Paraliżujący Jad" })
		T.expect(names("toxicBarbs")).toEqual({ "Jad Myśliwski", "Zaraza", "Paraliżujący Jad", "Jad Bazyliszka" })
	end)
end)

-- S81: the Mage on real paths (ROZWOJ 12) ------------------------------------------------------------------------------

T.describe("Data: Mage paths (S81)", function()
	local TooltipModel = require("../src/shared/Logic/TooltipModel")

	local function mage(_main: string?, nodes: { [string]: number }): any
		return char(100, state(nodes, {}), { class = "Mage" })
	end

	local function ok(pathId: string, main: string?, offhand: string?): boolean
		return GamePaths.weaponOk((PathData.get(pathId) :: any).weapon, { main = main, offhand = offhand })
	end

	T.it("weapons of ROZWOJ 12.1 and their coverage", function()
		T.expect(ok("destroyer", "staff")).toBe(true)
		T.expect(ok("destroyer", "runestaff")).toBe(false)
		T.expect(ok("destroyer", "wand", "orb")).toBe(true)
		T.expect(ok("destroyer", "wand", "tome")).toBe(false)
		T.expect(ok("destroyer", "wand")).toBe(false)
		T.expect(ok("arcanist", "runestaff")).toBe(true)
		T.expect(ok("arcanist", "staff")).toBe(false)
		T.expect(ok("arcanist", "wand", "tome")).toBe(true)
		T.expect(ok("arcanist", "wand", "orb")).toBe(false)
		T.expect(ok("arcanist", "wand")).toBe(false)
		T.expect(ok("fortune", "holystaff")).toBe(false)
		T.expect(ok("fortune", "mace1h", "relic")).toBe(true)
		-- staff and orb only for the Destroyer, runestaff and tome only for the Arcanist, the wand for both
		local function fits(main: string, offhand: string?): { string }
			local out = {}
			for _, path in GamePaths.pathsOf("Mage") do
				if GamePaths.weaponOk(path.weapon, { main = main, offhand = offhand }) then
					table.insert(out, path.id)
				end
			end
			return out
		end
		T.expect(fits("staff")).toEqual({ "destroyer" })
		T.expect(fits("runestaff")).toEqual({ "arcanist" })
		T.expect(fits("wand", "orb")).toEqual({ "destroyer" })
		T.expect(fits("wand", "tome")).toEqual({ "arcanist" })
		T.expect(fits("wand")).toEqual({})
		-- S138: a tome in a Destroyer's hands: no direction weapon, row 3 (Volatile Power) works as row 2
		local c = mage(nil, { destroyer_volatile = 3, destroyer_trace = 3 })
		local hooks = GamePaths.passiveTotals(c, { main = "wand", offhand = "tome" }).hooks
		T.expect(hooks.areaCost).toBeNear(30, 1e-9)
		T.expect(hooks.areaDamage).toBe(GamePaths.passiveTotals(c, { main = "staff" }).hooks.areaDamage)
		T.expect(hooks.areaLingering).toBeNear(2, 1e-9)
		for _, weapons in { { main = "runestaff" }, { main = "staff" }, { main = "wand", offhand = "orb" } } do
			T.expect(GamePaths.passiveTotals(c, weapons).hooks.areaLingering).toBeNear(2, 1e-9)
		end
		T.expect(GamePaths.passiveTotals(c, { main = "staff" }).hooks.areaCost).toBeNear(30, 1e-9)
	end)

	-- S140: Elementalist and Arcane Mind are 3-rank nodes, Grit and Will 2 (one whole direction = 50), 4 skill nodes
	T.it("twoPathExtra rows, ranks 50 / 15 and 13, 63 / 65 coverage, 46 nodes, 4 skill nodes", function()
		local extraRows = {}
		for _, row in GamePaths.rowsFor("Mage") do
			if row.extra then
				table.insert(extraRows, row.index)
			end
		end
		T.expect(extraRows).toEqual({ 2, 5, 10 })
		local paths = GamePaths.pathsOf("Mage")
		T.expect(#paths).toBe(2)
		local nodes, skills = 0, 0
		local early = { destroyer = 15, arcanist = 13 }
		for _, main in paths do
			T.expect(main.wiki).toBe(false)
			T.expect({ main.id, pathRanks(main, 1, #PathData.ROWS) }).toEqual({ main.id, 50 })
			local total = 50
			for _, other in paths do
				if other ~= main then
					T.expect({ other.id, pathRanks(other, 1, PathData.DIP_ROWS) })
						.toEqual({ other.id, early[other.id] })
					total += early[other.id]
				end
			end
			T.expect(total).toBe(if main.id == "destroyer" then 63 else 65)
			T.expect(wholeOf(main)).toBe(GamePaths.pointsAt(100))
			T.expect(wholeOf(main) <= GamePaths.pointsAt(100)).toBe(true) -- S138: one whole direction
			for r, row in main.rows do
				local extras = 0
				for i, n in row.nodes do
					nodes += 1
					skills += if n.kind == "skill" then 1 else 0
					if n.extra then
						extras += 1
						T.expect({ n.id, i }).toEqual({ n.id, #row.nodes })
					end
				end
				local want = if r == 2 or r == 5 or r == 10 then 1 else 0
				T.expect({ main.id, r, extras }).toEqual({ main.id, r, want })
				if want == 1 then
					T.expect({ main.id, r, #row.nodes }).toEqual({ main.id, r, 3 })
				end
			end
		end
		T.expect({ nodes, skills }).toEqual({ 46, 4 })
		-- classes with three paths have no extra nodes
		for _, path in PathData.list do
			if path.class ~= "Mage" then
				for _, row in path.rows do
					for _, n in row.nodes do
						T.expect({ n.id, n.extra }).toEqual({ n.id, nil })
					end
				end
			end
		end
	end)

	T.it(
		"model builds spend exactly 50; areaCap 3.0 for the Destroyer; Fury stays the only damage reference",
		function()
			local caps = {}
			for _, path in GamePaths.pathsOf("Mage") do
				T.expect(#path.reference).toBe(4) -- S140: + the fire variant; S141: + the ice variant
				for _, build in path.reference do
					T.expect({ build.id, build.damageReference }).toEqual({ build.id, nil })
					caps[build.id] = build.areaCap or 2
					T.expect(build.stats).toEqual(path.statPlan)
					local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
					T.expect({ build.id, GamePaths.weaponOk(path.weapon, weapons) }).toEqual({ build.id, true })
					local nodes: { [string]: number } = {}
					local c = mage(path.id, nodes)
					for _, entry in build.nodes do
						for _ = 1, entry[2] do
							local can, why = GamePaths.canBuy(c, entry[1])
							T.expect({ build.id, entry[1], can, why }).toEqual({ build.id, entry[1], true, nil })
							nodes[entry[1]] = (nodes[entry[1]] or 0) + 1
						end
					end
					T.expect({ build.id, GamePaths.spent(c) }).toEqual({ build.id, GamePaths.pointsAt(100) })
					local available = availableAny(c)
					for key in build.bp do
						local skillId, at = string.match(key, "^(.+):(%d+)$")
						local def = SkillData.get(skillId or "") :: any
						T.expect({ key, at == "5" or at == "10", def ~= nil and def.type ~= "passive" })
							.toEqual({ key, true, true })
						T.expect({ key, table.find(available, skillId or "") ~= nil }).toEqual({ key, true })
					end
					for _, step in build.rotation do
						T.expect({ build.id, step.skill, table.find(available, step.skill) ~= nil })
							.toEqual({ build.id, step.skill, true })
					end
				end
			end
			T.expect(caps).toEqual({
				destroyerExp = 3,
				destroyerBoss = 3,
				destroyerFire = 3,
				destroyerIce = 3, -- S141
				arcanistIce = 2, -- S141
				arcanistBoss = 2,
				arcanistOverload = 2,
				arcanistFire = 2,
			})
			local references = {}
			for _, path in PathData.list do
				for _, build in path.reference do
					if build.damageReference then
						table.insert(references, build.id)
					end
				end
			end
			T.expect(references).toEqual({ "fury" })
		end
	)

	-- S140 (DESIGN-18 §6.1, §7): the target shape of the Mage's directions (asserted here while the Mage is transitional)
	T.it(
		"S140: skill nodes only in rows 4 and 8, the moved skills are passive nodes, every modify skill exists",
		function()
			local skillRows: { string } = {}
			for _, path in GamePaths.pathsOf("Mage") do
				for r, row in path.rows do
					for _, n in row.nodes do
						if n.kind == "skill" then
							table.insert(skillRows, `{path.id}:{r}:{n.skill}`)
						end
						if n.modify then
							T.expect({ n.id, SkillData.get(n.modify.skill) ~= nil }).toEqual({ n.id, true })
						end
					end
				end
			end
			T.expect(skillRows).toEqual({
				"destroyer:4:elementalVortex",
				"destroyer:8:cataclysm",
				"arcanist:4:arcaneDischarge",
				"arcanist:8:arcaneTorrent",
			})
			local elementalist = (GamePaths.findNode("destroyer_elementalist")) :: any
			local mind = (GamePaths.findNode("arcanist_arcaneMind")) :: any
			T.expect({ elementalist.kind, elementalist.maxRank }).toEqual({ "passive", 3 })
			T.expect({ mind.kind, mind.maxRank }).toEqual({ "passive", 3 })
			-- the old ranks 1 / 3 / 5 of the skills
			T.expect(GamePaths.nodeValues(elementalist, 2).bonus).toBeNear(9, 1e-9)
			T.expect(GamePaths.nodeValues(mind, 3).critDmg).toBeNear(2.8, 1e-9)
			local c = mage(nil, { destroyer_elementalist = 3, arcanist_arcaneMind = 1 })
			local totals = GamePaths.passiveTotals(c, { main = "staff" })
			T.expect(totals.hooks.elementDamage).toBeNear(15, 1e-9)
			T.expect(totals.flat.critChance).toBeNear(0.35, 1e-9)
			for _, id in { "elementalist", "arcaneMind" } do
				T.expect(SkillData.get(id)).toBeNil()
			end
		end
	)

	T.it("weapon traits list Elements in the Veins (S68 nodeHooks)", function()
		local destroyerPaths = { PathData.get("destroyer") }
		local function names(traitId: string): { string }
			local out = {}
			for _, entry in TooltipModel.traitNodes(traitId, destroyerPaths, nil, "pl") do
				table.insert(out, entry.node)
			end
			return out
		end
		T.expect(names("elementalMight")).toEqual({ "Żywioł w Żyłach" })
		T.expect(names("elementalSpark")).toEqual({ "Żywioł w Żyłach" })
	end)
end)

-- Build sets (S58, ROZWOJ 2.9, 2.11, 3.4) ----------------------------------------------------------------------------

T.describe("Build sets (S58)", function()
	local api = P

	local function mage(level: number): any
		return {
			class = "Mage",
			level = level,
			stats = StatPlan.startOf("Mage"),
			statPoints = StatPlan.total(level),
			hotbar = Skills.startHotbar("Mage", level),
			path = { nodes = {}, bp = {} },
			buildSlot = 1,
			buildOther = nil,
			equipment = {},
			ranks = RankFill.auto("Mage", level, Fixture.skills), -- S137
		}
	end

	-- The fxStorm reference build at level 100: nodes, bp, 495 stat points spent, a checked bar.
	local function fullSet(): any
		local ref = (Fixture.source.path("fxStorm") :: any).reference[1]
		local nodes: { [string]: number } = {}
		for _, entry in ref.nodes do
			nodes[entry[1]] = entry[2]
		end
		local c = mage(100)
		c.path = { nodes = nodes, bp = table.clone(ref.bp) }
		local spent = StatPlan.suggest({ int = 3, vit = 2 }, StatPlan.startOf("Mage") :: any, c.stats, 495)
		for id, n in spent do
			c.stats[id] += n
		end
		c.statPoints = 0
		c.hotbar["10"] = "fxSpark"
		c.ranks = (api.cleanRanks(c)) -- S137: the legal ranks of the set (points per pool)
		local bar, bp = api.validHotbar(c)
		c.hotbar = bar
		c.path.bp = bp
		return api.activeSet(c)
	end

	local function withActive(set: any, level: number?): any
		local c = mage(level or 100)
		c.path = TableUtil.deepCopy(set.path)
		c.stats = TableUtil.deepCopy(set.stats)
		c.statPoints = set.statPoints
		c.hotbar = TableUtil.deepCopy(set.hotbar)
		-- S137: the set's ranks and pool bars
		c.ranks = TableUtil.deepCopy(set.ranks)
		c.bars = TableUtil.deepCopy(set.bars)
		c.barPool = set.barPool
		c.respecFree = set.respecFree
		c.poolsVersion = set.poolsVersion
		return c
	end

	local function apply(c: any, swap: any)
		c.stats = swap.active.stats
		c.statPoints = swap.active.statPoints
		c.hotbar = swap.active.hotbar
		c.ranks = swap.active.ranks
		c.bars = swap.active.bars
		c.barPool = swap.active.barPool
		c.respecFree = swap.active.respecFree
		c.poolsVersion = swap.active.poolsVersion
		c.path = swap.active.path
		c.buildOther = swap.other
		c.buildSlot = swap.slot
	end

	local function statTotal(set: any): number
		return StatPlan.spent("Mage", set.stats) + set.statPoints
	end

	T.it("1. the first switch gives an empty set and keeps the old one apart", function()
		local full = fullSet()
		T.expect(full.path.bp["fxSpark:5"]).toBe("b")
		local c = withActive(full)
		local swap = api.swapSets(c)
		T.expect(swap.slot).toBe(2)
		T.expect(swap.active.path).toEqual({ nodes = {}, bp = {} })
		T.expect(swap.active.stats).toEqual(StatPlan.startOf("Mage"))
		T.expect(swap.active.statPoints).toBe(495)
		-- S137: an empty set has no bought ranks and an empty bar (nothing is bought by itself)
		T.expect(swap.active.hotbar).toEqual({})
		T.expect(swap.active.ranks).toEqual({})
		T.expect(swap.other).toEqual(full)
		T.expect(swap.other.path.nodes ~= c.path.nodes).toBe(true)
		T.expect(swap.other.stats ~= c.stats).toBe(true)
		T.expect(swap.other.hotbar ~= c.hotbar).toBe(true)
		swap.other.stats.int += 50
		swap.other.path.nodes.fxStorm_focus = nil
		swap.other.hotbar["1"] = nil
		T.expect(api.activeSet(c)).toEqual(full)
	end)

	T.it("2. there and back loses and doubles nothing", function()
		local full = fullSet()
		local c = withActive(full)
		local before = api.spent(c)
		local first = api.swapSets(c)
		local empty = TableUtil.deepCopy(first.active)
		apply(c, first)
		T.expect(statTotal(c)).toBe(StatPlan.total(100))
		T.expect(statTotal(c.buildOther)).toBe(StatPlan.total(100))
		T.expect(api.spent(c)).toBe(0)
		T.expect(api.spent(api.setView(c, c.buildOther))).toBe(before)
		local second = api.swapSets(c)
		apply(c, second)
		T.expect(second.slot).toBe(1)
		T.expect(api.activeSet(c)).toEqual(full)
		T.expect(c.buildOther).toEqual(empty)
		T.expect(statTotal(c)).toBe(StatPlan.total(100))
		T.expect(statTotal(c.buildOther)).toBe(StatPlan.total(100))
		T.expect(api.spent(c)).toBe(before)
		T.expect(api.spent(api.setView(c, c.buildOther))).toBe(0)
	end)

	T.it("3. a copy keeps the target's respecFree", function()
		local full = fullSet()
		local c = withActive(full)
		local copy = api.copySet(c)
		T.expect(api.mainOf(api.setView(c, copy))).toBe("fxStorm")
		T.expect(copy.path.nodes).toEqual(full.path.nodes)
		T.expect(copy.path.bp).toEqual(full.path.bp)
		T.expect(copy.hotbar).toEqual(full.hotbar)
		T.expect(copy.stats).toEqual(full.stats)
		T.expect(copy.statPoints).toBe(full.statPoints)
		T.expect(copy.respecFree).toBe(false)
		T.expect(copy.path.nodes ~= c.path.nodes).toBe(true)
		T.expect(copy.stats ~= c.stats).toBe(true)
		T.expect(copy.hotbar ~= c.hotbar).toBe(true)
		c.buildOther = api.emptySet("Mage", 100)
		c.buildOther.respecFree = true
		T.expect(api.copySet(c).respecFree).toBe(true)
	end)

	T.it("4. S138: a set with the old main path and freeUsed loses them on copy and clean", function()
		local c = mage(30)
		c.buildOther = api.emptySet("Mage", 30)
		c.buildOther.path = { main = "fxRune", nodes = { fxRune_fxGlyph = 1 }, bp = {}, freeUsed = true }
		local cleaned, changed = api.cleanSet(c, c.buildOther, 30)
		T.expect(changed).toBe(true)
		T.expect(cleaned.path).toEqual({ nodes = { fxRune_fxGlyph = 1 }, bp = {} })
		c.path = { main = "fxStorm", nodes = {}, bp = {}, freeUsed = true }
		local copy = api.copySet(c)
		T.expect(copy.path).toEqual({ nodes = {}, bp = {} })
	end)

	T.it("5. refunds keep the breakpoint choices and drop nothing else in every set", function()
		local c = mage(100)
		c.buildOther = fullSet()
		local swap = api.swapSets(c)
		local views = {
			api.setView(c, swap.active),
			api.setView(c, c.buildOther),
		}
		for _, view in views do
			for _, opts in { nil, { fromRow = 3 }, { points = 3 } } :: { any } do
				local state = api.refund(view, opts)
				T.expect(state.bp).toEqual(view.path.bp)
				T.expect(state.main).toBeNil()
			end
		end
	end)

	T.it("6. SetLevel down clamps both sets", function()
		local full = fullSet()
		local c = withActive(full)
		c.buildOther = fullSet()
		local function levelDown(set: any, level: number): any
			local out = api.cleanSet(c, set, level)
			out.stats, out.statPoints = StatPlan.refit("Mage", level, out.stats)
			return out
		end
		for _, set in { api.activeSet(c), c.buildOther } do
			local out = levelDown(set, 30)
			local view = api.setView(c, out, 30)
			T.expect(api.spent(view) <= api.pointsAt(30)).toBe(true)
			for id in out.path.nodes do
				local _, _, row = api.findNode(id)
				T.expect(api.ROWS[row].level <= 30).toBe(true)
			end
			for _, id in out.hotbar do
				T.expect(api.skillRank(view, id) > 0).toBe(true)
			end
			-- S137 (DESIGN-18 §8): a choice stays without a rank; a path skill's only while its node rule holds
			for key in out.path.bp do
				local skillId = string.match(key, "^(.+):%d+$") :: string
				local def = api.source.skill(skillId) :: any
				T.expect(def.path == nil or api.pathSkillOpen(view, def)).toBe(true)
			end
			T.expect(out.stats).toEqual(StatPlan.startOf("Mage"))
			T.expect(out.statPoints).toBe(StatPlan.total(30))
			T.expect(out.path.main).toBeNil()
		end
		local small = api.emptySet("Mage", 100)
		small.stats.int += 100
		small.statPoints = 395
		local out = levelDown(small, 30)
		T.expect(out.stats.int).toBe(StatPlan.startOf("Mage").int + 100)
		T.expect(out.statPoints).toBe(45)
	end)

	T.it("7. cleanSet on load repairs only what is wrong", function()
		local full = fullSet()
		local c = withActive(full)
		local same, changed = api.cleanSet(c, full, 100)
		T.expect(changed).toBe(false)
		T.expect(same).toEqual(full)
		local base = TableUtil.deepCopy(full)
		base.hotbar["9"] = nil -- the base bar is full at 100
		local broken = TableUtil.deepCopy(base)
		broken.path.nodes.fxGone_x = 2
		broken.hotbar["9"] = "fxOrphan"
		broken.path.bp["fxBolt:5"] = "b" -- no breakpoints
		local fixed, changed2 = api.cleanSet(c, broken, 100)
		T.expect(changed2).toBe(true)
		T.expect(fixed.path.nodes.fxGone_x).toBeNil()
		T.expect(fixed.hotbar["9"]).toBeNil()
		T.expect(fixed.path.bp["fxBolt:5"]).toBeNil()
		T.expect(fixed).toEqual(base)
		local repaired = api.cloneSet({ path = nil, stats = nil, statPoints = "x" }, "Mage", 40)
		T.expect(repaired.path).toEqual({ nodes = {}, bp = {} })
		T.expect(repaired.stats).toEqual(StatPlan.startOf("Mage"))
		T.expect(repaired.statPoints).toBe(StatPlan.total(40))
		T.expect(repaired.hotbar).toEqual({})
	end)

	T.it("8. canEdit for build sets", function()
		local function ctx(action: string, extra: { [string]: any }): any
			local out: { [string]: any } = { action = action, inCombat = false, inTown = false, nearGate = false }
			for key, value in extra do
				out[key] = value
			end
			return out
		end
		local town = { inTown = true }
		T.expect(select(2, api.canEdit(ctx("switchSet", { inTown = true, dead = true })))).toBe("buildset.error.dead")
		T.expect(select(2, api.canEdit(ctx("switchSet", { nearGate = true, inRun = true })))).toBe("buildset.error.run")
		T.expect(select(2, api.canEdit(ctx("switchSet", { inTown = true, inCombat = true }))))
			.toBe("paths.error.combat")
		T.expect(select(2, api.canEdit(ctx("switchSet", {})))).toBe("paths.error.place")
		T.expect(api.canEdit(ctx("switchSet", town))).toBe(true)
		T.expect(api.canEdit(ctx("switchSet", { nearGate = true }))).toBe(true)
		T.expect(select(2, api.canEdit(ctx("copySet", { dead = true })))).toBe("buildset.error.dead")
		T.expect(select(2, api.canEdit(ctx("copySet", { inCombat = true })))).toBe("paths.error.combat")
		T.expect(api.canEdit(ctx("copySet", {}))).toBe(true)
		-- the S57 actions ignore dead / inRun
		T.expect(api.canEdit(ctx("buy", {}))).toBe(true)
		T.expect(select(2, api.canEdit(ctx("refund", {})))).toBe("paths.error.place")
		T.expect(api.canEdit(ctx("refund", { nearGate = true, dead = true, inRun = true }))).toBe(true)
		T.expect(select(2, api.canEdit(ctx("changeMain", { nearGate = true })))).toBe("error.badRequest") -- S138
		T.expect(select(2, api.canEdit(ctx("chooseBp", { inCombat = true })))).toBe("paths.error.combat")
	end)

	T.it("9. the stat plan of the leading direction (S138)", function()
		local c = mage(40)
		c.path = { nodes = fill("fxStorm", 2), bp = {} } -- 13 ranks: fxStorm leads
		local plan, planDef = api.statPlan(c)
		T.expect(plan).toEqual({ int = 3, vit = 2 })
		T.expect(planDef and planDef.id).toBe("fxStorm")
		c.path = { nodes = fill("fxRune", 2, fill("fxStorm", 1)), bp = {} } -- fxRune leads, it has no plan
		local classPlan, none = api.statPlan(c)
		T.expect(classPlan).toEqual((Classes.get("Mage") :: any).statPlan)
		T.expect(none).toBeNil()
		c.path = { nodes = fill("fxStorm", 1), bp = {} } -- below MAIN_MIN_POINTS
		T.expect(api.statPlan(c)).toEqual((Classes.get("Mage") :: any).statPlan)
		c.path = nil
		T.expect(api.statPlan(c)).toEqual((Classes.get("Mage") :: any).statPlan)
	end)
end)
