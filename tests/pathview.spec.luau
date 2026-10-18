--!strict
-- The skills window's path views (S59, ROZWOJ 4): Logic/PathView on the test paths (tests/fixtures/paths.luau) and the
-- node helpers of Logic/Paths it relies on (nodeScale, nodeArgs, iconWeapon, isTwoHanded). S138: directions (no main
-- path, no direction weapon): tab states from the leading direction, the capstone and upgrade rows.

local Fixture = require("./fixtures/paths")
local RankFill = require("./RankFill")
local GamePaths = require("../src/shared/Logic/Paths")
local PathView = require("../src/shared/Logic/PathView")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local P = GamePaths.withSource(Fixture.source)
local View = PathView.with(P)

local function state(nodes: { [string]: number }?, bp: any?): any
	return { nodes = nodes or {}, bp = bp or {} }
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

-- S137: the old automatic ranks as bought ranks (tests/RankFill: every pool at its limit, no free skill points)
local function char(level: number, path: any?): any
	local c = { class = "Mage", level = level, path = path or state(), hotbar = {}, equipment = {} }
	return RankFill.fill(c, Fixture.skills)
end

local function nodeView(view: any, nodeId: string): any
	for _, row in view.rows do
		for _, n in row.nodes do
			if n.node.id == nodeId then
				return n
			end
		end
	end
	error(`no node {nodeId}`)
end

local function hasEntry(list: { any }, want: { [string]: any }): boolean
	for _, entry in list do
		local same = true
		for key, value in want do
			if entry[key] ~= value then
				same = false
			end
		end
		if same then
			return true
		end
	end
	return false
end

local function hasSkill(list: { any }, skillId: string): boolean
	return hasEntry(list, { skillId = skillId })
end

local STAFF = { main = "staff" }
local FOUR = { fxStorm_fxSpark = 1, fxStorm_focus = 3 }

T.describe("PathView (S59)", function()
	T.it("tab states", function()
		T.expect(View.tabState(char(9), "fxStorm")).toBe("closed")
		T.expect(View.tabState(char(9), "fxRune")).toBe("closed")
		T.expect(View.tabState(char(10), "fxStorm")).toBe("open")
		local c = char(30, state(fill("fxStorm", 2))) -- 13 ranks: fxStorm leads
		T.expect(View.tabState(c, "fxStorm")).toBe("main")
		T.expect(View.tabState(c, "fxRune")).toBe("open")
		T.expect(View.leading(c)).toEqual({ pathId = "fxStorm", need = P.MAIN_MIN_POINTS })
		T.expect(View.leading(char(30, state(table.clone(FOUR))))).toEqual({ need = P.MAIN_MIN_POINTS })
	end)

	T.it("rows, their nodes and why they are closed", function()
		local c = char(30, state(table.clone(FOUR)))
		local view = View.path(c, "fxStorm", STAFF) :: any
		T.expect(#view.rows).toBe(11)
		T.expect(#view.rows[2].nodes).toBe(3)
		T.expect(view.rows[3].choice).toBe(true)
		T.expect(#view.rows[3].nodes).toBe(2)
		T.expect(#view.rows[8].nodes).toBe(1)
		T.expect(view.rows[3].open).toBe(true)
		T.expect(view.rows[4].open).toBe(false)
		T.expect(view.rows[4].closedKey).toBe("paths.closed.need")
		T.expect(view.rows[4].closedArgs).toEqual({ need = 6, have = 4 })
		T.expect(view.rows[5].closedKey).toBe("paths.closed.level")
		T.expect(view.rows[5].closedArgs).toEqual({ level = 33 })
		T.expect(view.spent).toBe(4)
		T.expect(view.leading).toBe(false)
		-- S138: row 3 of the other direction closes only for its own points
		local rune = View.path(c, "fxRune", STAFF) :: any
		T.expect(rune.rows[3].closedKey).toBe("paths.closed.need")
		T.expect(rune.rows[3].closedArgs).toEqual({ need = 4, have = 0 })
		T.expect(View.path(c, "nope", STAFF)).toBeNil()
	end)

	T.it("one capstone per set and the upgrade of its own direction (S138)", function()
		local nodes = fill("fxStorm", 7)
		nodes.fxStorm_fxCataclysm = 1
		local c = char(100, state(nodes))
		local storm = View.path(c, "fxStorm", STAFF) :: any
		T.expect(storm.leading).toBe(true)
		T.expect(storm.rows[8].closedKey).toBeNil()
		local rune = View.path(c, "fxRune", STAFF) :: any
		T.expect(rune.rows[8].open).toBe(false)
		T.expect(rune.rows[8].closedKey).toBe("skills.error.capstoneTaken")
		-- the row's own requirement comes first while it is not met
		T.expect(rune.rows[8].nodes[1].buyReason).toBe("paths.error.need")
		T.expect(rune.rows[11].closedKey).toBe("paths.error.upgrade")
		local empty = View.path(char(100), "fxStorm", STAFF) :: any
		T.expect(empty.rows[8].closedKey).toBe("paths.closed.need")
		T.expect(empty.rows[11].closedKey).toBe("paths.error.upgrade")
	end)

	T.it("a choice row takes the other node", function()
		local nodes = table.clone(FOUR)
		nodes.fxStorm_surge = 1
		local view = View.path(char(30, state(nodes)), "fxStorm", STAFF) :: any
		local echo = nodeView(view, "fxStorm_echo")
		T.expect(echo.taken).toBe(true)
		T.expect(echo.canBuy).toBe(false)
		T.expect(echo.buyReason).toBe("paths.error.choice")
		T.expect(nodeView(view, "fxStorm_surge").taken).toBe(false)
	end)

	T.it("one third strength below TEAM_FULL_POINTS in the direction (S138) and node arguments", function()
		local outside = View.path(char(30, state(table.clone(FOUR))), "fxStorm", STAFF) :: any
		T.expect(math.abs(nodeView(outside, "fxStorm_hex").scale - 1 / 3) < 1e-9).toBe(true)
		local inside = View.path(char(30, state(fill("fxStorm", 2))), "fxStorm", STAFF) :: any
		T.expect(nodeView(inside, "fxStorm_hex").scale).toBe(1)
		local focus = P.findNode("fxStorm_focus") :: any
		T.expect(P.nodeArgs(focus, 1).int).toBe(2)
		T.expect(P.nodeArgs(focus, 2).int).toBe(4)
		T.expect(P.nodeArgs(focus, 3).int).toBe(6)
		T.expect(P.nodeArgs(focus, 2, 1 / 3).int).toBe(1.3)
		local surge = P.findNode("fxStorm_surge") :: any
		local v = P.nodeValues(surge, 2, 1).cd
		T.expect(P.nodeArgs(surge, 2, 1 / 3).cd).toBe(Skills.roundArg(1 + (v - 1) / 3))
		T.expect(P.nodeArgs(P.findNode("fxRune_mend") :: any, 1)).toEqual({})
	end)

	T.it("no direction weapon (S138); weapon texts for node requirements", function()
		local c = char(30, state(table.clone(FOUR)))
		local wrong = View.path(c, "fxStorm", { main = "runestaff" }) :: any
		local right = View.path(c, "fxStorm", STAFF) :: any
		T.expect(wrong.weaponOk).toBeNil()
		for i, row in wrong.rows do
			T.expect({ i, row.open, row.weaponBlocked }).toEqual({ i, right.rows[i].open, nil })
		end
		T.expect(View.weaponText({ main = { "staff", "wand" }, offhand = { "orb" } }, "pl"))
			.toBe("Kostur albo Różdżka + Kula")
		T.expect(View.weaponText({ offhand = { "relic" } }, "pl")).toBe("dowolna broń jednoręczna + Relikwia")
		T.expect(View.weaponText(nil, "en")).toBe("any weapon of the class")
		T.expect(P.iconWeapon(Fixture.source.path("fxStorm") :: any)).toBe("staff")
		T.expect(P.isTwoHanded("staff")).toBe(true)
		T.expect(P.isTwoHanded("wand")).toBe(false)
	end)

	T.it("the attention badge", function()
		local fresh = View.attention(char(10))
		T.expect(fresh.points).toBe(true)
		T.expect(fresh.paths.fxStorm).toBe(true)
		T.expect(fresh.any).toBe(true)
		local spentAll = View.attention(char(10, state({ fxStorm_fxSpark = 1, fxStorm_focus = 3, fxRune_fxGlyph = 1 })))
		T.expect(spentAll.points).toBe(false)
		T.expect(spentAll.any).toBe(false)
		local c = char(26, state({ fxStorm_fxSpark = 1 }))
		T.expect(hasEntry(View.pendingBreakpoints(c), { skillId = "fxSpark", at = 5 })).toBe(true)
		T.expect(View.attention(c).paths.fxStorm).toBe(true)
		c.path.bp["fxSpark:5"] = "a"
		T.expect(hasSkill(View.pendingBreakpoints(c), "fxSpark")).toBe(false)
	end)

	T.it("the attention badge per pool tab and the directions tab (S139)", function()
		local real = { class = "Mage", level = 10, path = state(), hotbar = {}, equipment = {} } :: any
		real.ranks = { fire = { firebolt = 1 } }
		local a = PathView.attention(real)
		T.expect(a.skills).toBe(true)
		T.expect(a.pools.fire).toBe(true)
		T.expect(a.pools.ice).toBeNil()
		T.expect(a.directions).toBe(true) -- a free talent point with a node to buy
		local fresh = View.attention(char(10))
		T.expect(fresh.directions).toBe(true)
		local spentAll = View.attention(char(10, state({ fxStorm_fxSpark = 1, fxStorm_focus = 3, fxRune_fxGlyph = 1 })))
		T.expect(spentAll.directions).toBe(false)
		-- a breakpoint to choose marks the active pool's tab and its direction
		local c = char(26, state({ fxStorm_fxSpark = 1 }))
		local pending = View.attention(c)
		T.expect(pending.paths.fxStorm).toBe(true)
		T.expect(pending.pools.fire).toBe(true)
		T.expect(pending.directions).toBe(true)
	end)

	T.it("rank-ups and new breakpoints on a level-up", function()
		local c = char(26, state({ fxStorm_fxSpark = 1 }))
		T.expect(hasEntry(View.rankUps(c, 25, 26), { skillId = "fxSpark", rank = 5 })).toBe(true)
		T.expect(hasEntry(View.newBreakpoints(c, 25, 26), { skillId = "fxSpark", at = 5 })).toBe(true)
		T.expect(hasSkill(View.rankUps(c, 26, 27), "fxSpark")).toBe(false)
		T.expect(hasSkill(View.newBreakpoints(c, 26, 27), "fxSpark")).toBe(false)
		T.expect(#View.rankUps(c, 20, 20)).toBe(0)
		T.expect(hasSkill(View.rankUps(c, 9, 10), "fxSpark")).toBe(false)
	end)
end)

-- S139 (DESIGN-18 §5, §12): the pool tree and the details of a clicked skill.

local Progression = require("../src/shared/Data/Progression")
local SkillData = require("../src/shared/Data/Skills")
local SkillPoints = require("../src/shared/Logic/SkillPoints")

-- A real Mage (Data/Skills; S142: no longer transitional) with bought ranks in the fire pool (no weapon: the default pool).
local function mage(level: number, fire: { [string]: number }, path: any?): any
	return {
		class = "Mage",
		level = level,
		path = path or state(),
		hotbar = { ["1"] = "firebolt" },
		barPool = "fire",
		equipment = {},
		ranks = { fire = fire },
	}
end

local function rowOf(view: any, kind: string): any
	for _, row in view.rows do
		if row.kind == kind then
			return row
		end
	end
	return nil
end

local function tileOf(view: any, skillId: string): any
	for _, row in view.rows do
		for _, tile in row.tiles do
			if tile.skillId == skillId then
				return tile
			end
		end
	end
	error(`no tile {skillId}`)
end

local function ids(tiles: { any }): { string }
	local out = {}
	for _, tile in tiles do
		table.insert(out, tile.skillId)
	end
	return out
end

local function fake(id: string, role: string?, unlock: number): any
	return { id = id, role = role, unlock = unlock }
end

T.describe("PathView pool tree (S139)", function()
	T.it("rows by the shared ladder, role columns, direction and other rows", function()
		local rows = PathView.layout({
			fake("s1", "S1", 1),
			fake("c1", "C1", 4),
			fake("p1", "P1", 20),
			fake("u", "U", 60),
			fake("late", nil, 30),
			fake("early", nil, 6),
		}, { fake("dir", nil, 10) })
		local levels = {}
		for _, row in rows do
			if row.kind == "ladder" then
				table.insert(levels, row.level)
			end
		end
		T.expect(levels).toEqual({ 1, 3, 4, 6, 10, 12, 15, 20, 26, 30, 33, 40, 45, 50, 60 })
		local function ladderRow(level: number): any
			for _, row in rows do
				if row.kind == "ladder" and row.level == level then
					return row
				end
			end
			error(`no row {level}`)
		end
		T.expect({ ladderRow(1).code, ladderRow(1).column, ladderRow(1).skills[1].id }).toEqual({ "S1", "S", "s1" })
		T.expect({ ladderRow(4).code, ladderRow(4).column, ladderRow(4).skills[1].id }).toEqual({ "C1", "C", "c1" })
		T.expect({ ladderRow(20).column, ladderRow(20).skills[1].id }).toEqual({ "P", "p1" })
		T.expect({ ladderRow(60).column, ladderRow(60).skills[1].id }).toEqual({ "U", "u" })
		T.expect(#ladderRow(3).skills).toBe(0)
		T.expect(rows[16].kind).toBe("paths")
		T.expect(rows[16].skills[1].id).toBe("dir")
		T.expect(rows[17].kind).toBe("other")
		T.expect({ rows[17].skills[1].id, rows[17].skills[2].id }).toEqual({ "early", "late" })
		T.expect(PathView.COLUMNS).toEqual({ "S", "A", "K", "O", "P", "U", "C" })
	end)

	-- S140: the fire pool and the common skills sit on the ladder. S142: the Mage is no longer transitional (Fire Bolt is
	-- the fire pool's S1): every ladder row holds one skill, nothing in Others
	T.it("the Mage's full pools: one skill on every ladder row, nothing in Others", function()
		local view = PathView.poolView(mage(10, { firebolt = 2 }), "fire") :: any
		T.expect(view.transitional).toBeNil() -- S145: no class is transitional, the field is gone
		T.expect(view.active).toBe(true)
		local ladder, filled = 0, 0
		for _, row in view.rows do
			if row.kind == "ladder" then
				ladder += 1
				filled += #row.tiles
				T.expect(#row.tiles).toBe(1)
			end
		end
		T.expect(ladder).toBe(15)
		T.expect(filled).toBe(15)
		T.expect(rowOf(view, "paths")).toBeNil()
		T.expect(rowOf(view, "other")).toBeNil()
		T.expect(view.points).toBe(SkillPoints.pointsAt(10))
		T.expect(view.free).toBe(SkillPoints.pointsAt(10) - 2)
		T.expect(PathView.poolView(mage(10, {}), "nope")).toBeNil()
		local other = PathView.poolView(mage(10, {}), "ice") :: any
		T.expect(other.active).toBe(false)
		-- S141: the ice pool sits on the ladder too; S142: nothing in Others
		T.expect(rowOf(other, "other")).toBeNil()
	end)

	T.it("tiles: rank, limit, lock, bar, reservation and refund price", function()
		local view = PathView.poolView(mage(10, { firebolt = 2 }), "fire", { fireball = 1 }) :: any
		local bolt = tileOf(view, "firebolt")
		local firebolt = SkillData.get("firebolt") :: any
		T.expect({ bolt.rank, bolt.bought, bolt.reserved, bolt.max }).toEqual({ 2, 2, 0, 10 })
		T.expect(bolt.cap).toBe(Skills.rankAt(firebolt, 10))
		T.expect(bolt.onBar).toBe("1")
		T.expect(bolt.buyable).toBe(true)
		T.expect(bolt.refundable).toBe(true)
		T.expect(bolt.refundCost).toBe(0) -- below Progression.freeRespecLevel
		local ball = tileOf(view, "fireball")
		T.expect({ ball.rank, ball.bought, ball.reserved, ball.refundable, ball.refundCost })
			.toEqual({ 1, 0, 1, true, 0 })
		T.expect(view.reserved).toBe(1)
		T.expect(view.free).toBe(SkillPoints.pointsAt(10) - 3)
		local meteor = tileOf(view, "meteor")
		T.expect(meteor.locked).toBe(true)
		T.expect(meteor.unlock).toBe(26) -- S140: LADDER A2
		T.expect(meteor.buyable).toBe(false)
		T.expect(meteor.buyReason).toBe("skills.error.limit")
		T.expect(meteor.refundable).toBe(false)
		T.expect(meteor.nextLevel).toBe(26)
		-- the limit holds the next rank back: its level
		local capped = PathView.poolView(mage(1, { firebolt = 1 }), "fire") :: any
		T.expect(tileOf(capped, "firebolt").nextLevel).toBe(Skills.rankLevel(firebolt, 2))
		-- no free points: nothing to buy
		local broke = PathView.poolView(mage(10, { firebolt = SkillPoints.pointsAt(10) }), "fire") :: any
		T.expect(broke.free).toBe(0)
		T.expect(tileOf(broke, "fireball").buyable).toBe(false)
		T.expect(tileOf(broke, "fireball").buyReason).toBe("skills.error.points")
		-- from freeRespecLevel a bought rank comes back for gold
		local level = Progression.freeRespecLevel + 5
		local paid = PathView.poolView(mage(level, { firebolt = 3 }), "fire") :: any
		T.expect(tileOf(paid, "firebolt").refundCost).toBe(Progression.rankRefundGold * level)
	end)

	T.it("breakpoint marks on a tile", function()
		local view = PathView.poolView(mage(60, { firebolt = 10 }), "fire") :: any
		local marks = tileOf(view, "firebolt").bp
		T.expect(#marks).toBe(2)
		T.expect(marks[1].at).toBe(5)
		local firebolt = SkillData.get("firebolt") :: any
		local hasB = firebolt.breakpoints[5].b ~= nil
		T.expect(marks[1].mark).toBe(if hasB then "pending" else "a")
		local chosen =
			PathView.poolView(mage(60, { firebolt = 10 }, state(nil, { ["firebolt:5"] = "b" })), "fire") :: any
		T.expect(tileOf(chosen, "firebolt").bp[1].mark).toBe(if hasB then "b" else "a")
		local low = PathView.poolView(mage(60, { firebolt = 4 }), "fire") :: any
		T.expect(tileOf(low, "firebolt").bp[1].mark).toBe("none")
	end)

	-- S142: Fire Bolt is fire only; a common skill (Blink) shares its breakpoint choice across the pools (DESIGN-18 §8)
	T.it("a breakpoint reached in another pool: one rank for the server, the tiles and the dot", function()
		local c = mage(60, {})
		c.ranks.ice = { blink = 10 }
		T.expect(GamePaths.skillRank(c, "blink")).toBe(0) -- the active pool (fire)
		T.expect(GamePaths.bpRank(c, "blink")).toBe(10)
		local blink = SkillData.get("blink") :: any
		local hasB = blink.breakpoints[5].b ~= nil
		T.expect((GamePaths.canChooseBreakpoint(c, "blink", 5, "a"))).toBe(hasB)
		local want = if hasB then "pending" else "a"
		T.expect(tileOf(PathView.poolView(c, "fire") :: any, "blink").bp[1].mark).toBe(want)
		T.expect(tileOf(PathView.poolView(c, "ice") :: any, "blink").bp[1].mark).toBe(want)
		T.expect(hasEntry(PathView.pendingBreakpoints(c), { skillId = "blink", at = 5 })).toBe(hasB)
		T.expect(PathView.attention(c).pools.ice == true).toBe(hasB)
	end)

	T.it("direction skills in their own row (node bought)", function()
		local view = View.poolView(char(30, state({ fxStorm_fxSpark = 1 })), "fire") :: any
		local row = rowOf(view, "paths")
		T.expect(ids(row.tiles)).toEqual({ "fxSpark" })
		T.expect(row.tiles[1].path).toBe("fxStorm")
		T.expect(rowOf(View.poolView(char(30), "fire") :: any, "paths")).toBeNil()
	end)

	T.it("details: sections, the rank table, the highest rank, changes from directions", function()
		local c = mage(30, { firebolt = 3 })
		local d = PathView.skillDetails(c, "fire", "firebolt") :: any
		T.expect(d.shortKey).toBe("skill.firebolt.short")
		T.expect(d.rank).toBe(3)
		T.expect(d.nextRank).toBe(4)
		local opts = { level = 30, choices = {}, mods = {} }
		local firebolt = SkillData.get("firebolt") :: any
		local now = Skills.descriptionArgs(firebolt, 3, opts :: any)
		local after = Skills.descriptionArgs(firebolt, 4, opts :: any)
		T.expect(d.rows[1]).toEqual({
			field = "dmg",
			now = now.dmg,
			after = after.dmg,
			diff = Skills.roundArg(after.dmg - now.dmg),
		})
		T.expect(d.args.dmg).toBe(now.dmg)
		T.expect(table.find(d.sections, "what")).toBe(1)
		T.expect(table.find(d.sections, "rank")).toBe(2)
		T.expect(table.find(d.sections, "cost")).toBe(3)
		T.expect(d.sections[#d.sections]).toBe("full")
		T.expect(table.find(d.sections, "items")).toBeNil()
		T.expect(d.canBar).toBe(true)
		T.expect(d.onBar).toBe("1")
		-- the highest rank: no next rank, no difference
		local top = PathView.skillDetails(mage(100, { firebolt = 10 }), "fire", "firebolt") :: any
		T.expect(top.nextRank).toBeNil()
		T.expect(top.rows[1].after).toBeNil()
		T.expect(top.rows[1].diff).toBeNil()
		-- not learned: only the next rank's numbers
		local fresh = PathView.skillDetails(mage(30, {}), "fire", "fireball") :: any
		T.expect(fresh.rank).toBe(0)
		T.expect(fresh.rows[1].now).toBeNil()
		T.expect(fresh.rows[1].after ~= nil).toBe(true)
		T.expect(fresh.canBar).toBe(false)
		-- a member of another pool only
		T.expect(PathView.skillDetails(mage(30, {}), "fire", "iceShard")).toBeNil()
		-- modify nodes: listed with their state; a bought one works
		local dir = char(30, state({ fxStorm_fxSpark = 1, fxStorm_focus = 3, fxStorm_surge = 1 }))
		local spark = View.skillDetails(dir, "fire", "fxSpark") :: any
		T.expect(table.find(spark.sections, "directions") ~= nil).toBe(true)
		local surge, echo
		for _, mod in spark.mods do
			if mod.nodeId == "fxStorm_surge" then
				surge = mod
			elseif mod.nodeId == "fxStorm_echo" then
				echo = mod
			end
		end
		T.expect({ surge.rank, surge.active, surge.pathId, surge.row }).toEqual({ 1, true, "fxStorm", 3 })
		T.expect({ echo.rank, echo.active }).toEqual({ 0, false })
		T.expect(spark.path).toBe("fxStorm")
	end)

	T.it("details of a passive: no cost section", function()
		local c = { class = "Warrior", level = 30, path = state(), hotbar = {}, equipment = {} } :: any
		c.ranks = { onehand = { steelSkin = 2 } }
		local d = PathView.skillDetails(c, "onehand", "steelSkin") :: any
		T.expect(d.passive).toBe(true)
		T.expect(table.find(d.sections, "cost")).toBeNil()
		T.expect(table.find(d.sections, "breakpoints")).toBeNil()
		T.expect(d.canBar).toBe(false)
	end)

	T.it("planned: the reservation bought on a copy", function()
		local c = mage(10, { firebolt = 2 })
		T.expect(PathView.planned(c, "fire", {})).toBe(c)
		local p = PathView.planned(c, "fire", { firebolt = 2, fireball = 1 }) :: any
		T.expect(p.ranks.fire).toEqual({ firebolt = 4, fireball = 1 })
		T.expect(c.ranks.fire).toEqual({ firebolt = 2 })
	end)
end)
