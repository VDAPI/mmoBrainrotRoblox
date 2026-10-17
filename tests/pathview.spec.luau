--!strict
-- The skills window's path views (S59, ROZWOJ 4): Logic/PathView on the test paths (tests/fixtures/paths.luau) and the
-- node helpers of Logic/Paths it relies on (nodeScale, nodeArgs, iconWeapon, isTwoHanded).

local Fixture = require("./fixtures/paths")
local RankFill = require("./RankFill")
local GamePaths = require("../src/shared/Logic/Paths")
local PathView = require("../src/shared/Logic/PathView")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local P = GamePaths.withSource(Fixture.source)
local View = PathView.with(P)

local function state(main: string?, nodes: { [string]: number }?, bp: any?): any
	return { main = main, nodes = nodes or {}, bp = bp or {}, freeUsed = main ~= nil }
end

-- S137: the old automatic ranks as bought ranks (tests/RankFill: every pool at its limit, no free skill points)
local function char(level: number, path: any?): any
	local c = { class = "Mage", level = level, path = path or state(nil), hotbar = {}, equipment = {} }
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
		T.expect(View.tabState(char(10), "fxStorm")).toBe("dip")
		local c = char(30, state("fxStorm"))
		T.expect(View.tabState(c, "fxStorm")).toBe("main")
		T.expect(View.tabState(c, "fxRune")).toBe("dip")
	end)

	T.it("rows, their nodes and why they are closed", function()
		local c = char(30, state("fxStorm", table.clone(FOUR)))
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
		T.expect(view.main.reason).toBe("paths.error.sameMain")
		local rune = View.path(c, "fxRune", STAFF) :: any
		T.expect(rune.rows[3].closedKey).toBe("paths.closed.main")
		T.expect(rune.main.ok).toBe(true)
		T.expect(rune.main.cost).toBe("scroll")
		T.expect(View.path(c, "nope", STAFF)).toBeNil()
	end)

	T.it("a choice row takes the other node", function()
		local nodes = table.clone(FOUR)
		nodes.fxStorm_surge = 1
		local view = View.path(char(30, state("fxStorm", nodes)), "fxStorm", STAFF) :: any
		local echo = nodeView(view, "fxStorm_echo")
		T.expect(echo.taken).toBe(true)
		T.expect(echo.canBuy).toBe(false)
		T.expect(echo.buyReason).toBe("paths.error.choice")
		T.expect(nodeView(view, "fxStorm_surge").taken).toBe(false)
	end)

	T.it("one third strength outside the main path and node arguments", function()
		local outside = View.path(char(30, state("fxRune")), "fxStorm", STAFF) :: any
		T.expect(math.abs(nodeView(outside, "fxStorm_hex").scale - 1 / 3) < 1e-9).toBe(true)
		local inside = View.path(char(30, state("fxStorm")), "fxStorm", STAFF) :: any
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

	T.it("the path weapon", function()
		local c = char(30, state("fxStorm", table.clone(FOUR)))
		local wrong = View.path(c, "fxStorm", { main = "runestaff" }) :: any
		T.expect(wrong.weaponOk).toBe(false)
		for _, row in wrong.rows do
			T.expect({ row = row.index, blocked = row.weaponBlocked }).toEqual({
				row = row.index,
				blocked = row.index > 2,
			})
		end
		local right = View.path(c, "fxStorm", STAFF) :: any
		for _, row in right.rows do
			T.expect(row.weaponBlocked).toBe(false)
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
		local spentAll =
			View.attention(char(10, state(nil, { fxStorm_fxSpark = 1, fxStorm_focus = 3, fxRune_fxGlyph = 1 })))
		T.expect(spentAll.points).toBe(false)
		T.expect(spentAll.any).toBe(false)
		local c = char(26, state(nil, { fxStorm_fxSpark = 1 }))
		T.expect(hasEntry(View.pendingBreakpoints(c), { skillId = "fxSpark", at = 5 })).toBe(true)
		T.expect(View.attention(c).paths.fxStorm).toBe(true)
		c.path.bp["fxSpark:5"] = "a"
		T.expect(hasSkill(View.pendingBreakpoints(c), "fxSpark")).toBe(false)
	end)

	T.it("rank-ups and new breakpoints on a level-up", function()
		local c = char(26, state(nil, { fxStorm_fxSpark = 1 }))
		T.expect(hasEntry(View.rankUps(c, 25, 26), { skillId = "fxSpark", rank = 5 })).toBe(true)
		T.expect(hasEntry(View.newBreakpoints(c, 25, 26), { skillId = "fxSpark", at = 5 })).toBe(true)
		T.expect(hasSkill(View.rankUps(c, 26, 27), "fxSpark")).toBe(false)
		T.expect(hasSkill(View.newBreakpoints(c, 26, 27), "fxSpark")).toBe(false)
		T.expect(#View.rankUps(c, 20, 20)).toBe(0)
		T.expect(hasSkill(View.rankUps(c, 9, 10), "fxSpark")).toBe(false)
	end)
end)
