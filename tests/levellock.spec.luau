--!strict
-- Owner 2026-10-20: out-levelled elites and bosses are locked; ordinary monsters and the world boss never.
local T = require("./Test")
local Config = require("../src/shared/Config")
local LevelLock = require("../src/shared/Logic/LevelLock")

T.describe("LevelLock", function()
	T.it("locks elites, Elite II and dungeon bosses from the gap on", function()
		local gap = Config.LevelLock.gap
		for _, variant in { "elite", "elite2", "boss" } do
			T.expect({ variant, LevelLock.blocked(30 + gap - 1, 30, variant) }).toEqual({ variant, false })
			T.expect({ variant, LevelLock.blocked(30 + gap, 30, variant) }).toEqual({ variant, true })
		end
	end)

	T.it("never locks ordinary monsters nor the world boss", function()
		T.expect(LevelLock.blocked(100, 1, "normal")).toBe(false)
		T.expect(LevelLock.blocked(100, 1, "boss", true)).toBe(false)
		T.expect(LevelLock.blocked(100, 1, nil)).toBe(false)
	end)
end)

T.describe("S157 LevelLock on the monster (capLevel)", function()
	local gap = Config.LevelLock.gap

	T.it("the gap is 10 and the highest allowed level is one below it", function()
		T.expect(gap).toBe(10)
		T.expect(LevelLock.maxLevel(40)).toBe(40 + gap - 1)
	end)

	T.it("covers Elites, Elites II, dungeon bosses and their helpers only", function()
		T.expect(LevelLock.applies({ variant = "elite" })).toBe(true)
		T.expect(LevelLock.applies({ variant = "elite2" })).toBe(true)
		T.expect(LevelLock.applies({ variant = "boss", dungeonBoss = true })).toBe(true)
		T.expect(LevelLock.applies({ variant = "normal", dungeonBoss = true })).toBe(true) -- a boss helper
		T.expect(LevelLock.applies({ variant = "normal" })).toBe(false)
		T.expect(LevelLock.applies({ variant = "boss" })).toBe(false) -- the world boss (no dungeon flag)
		T.expect(LevelLock.applies({ variant = "boss", worldBoss = true, dungeonBoss = true })).toBe(false)
		T.expect(LevelLock.applies({ variant = "elite2", worldEvent = true })).toBe(false)
		T.expect(LevelLock.capOf({ variant = "elite" }, 30)).toBe(30 + gap - 1)
		T.expect(LevelLock.capOf({ variant = "normal" }, 30)).toBeNil()
	end)

	T.it("+gap-1 is allowed, +gap is locked (the same edge as LevelLock.blocked)", function()
		local cap = LevelLock.maxLevel(50)
		T.expect(LevelLock.over(50 + gap - 1, cap)).toBe(false)
		T.expect(LevelLock.over(50 + gap, cap)).toBe(true)
		T.expect(LevelLock.over(1, cap)).toBe(false)
		T.expect(LevelLock.over(100, nil)).toBe(false)
		for level = 45, 70 do
			T.expect(LevelLock.over(level, cap)).toBe(LevelLock.blocked(level, 50, "elite"))
		end
	end)

	T.it("an area attack keeps only the targets the character may hit", function()
		type Target = { id: string, cap: number? }
		local targets: { Target } = {
			{ id = "wolf", cap = nil }, -- normal monster
			{ id = "elite30", cap = LevelLock.maxLevel(30) },
			{ id = "elite40", cap = LevelLock.maxLevel(40) },
			{ id = "e2_50", cap = LevelLock.maxLevel(50) },
		}
		local function capOf(t: Target): number?
			return t.cap
		end
		local ids = {}
		for _, t in LevelLock.filter(targets, 30 + gap, capOf) do
			table.insert(ids, t.id)
		end
		T.expect(ids).toEqual({ "wolf", "elite40", "e2_50" })
		T.expect(#LevelLock.filter(targets, 30 + gap - 1, capOf)).toBe(4)
	end)

	T.it("the dungeon gate refuses a member gap or more levels above the boss", function()
		T.expect(LevelLock.bossEntry(60 + gap - 1, 60)).toBeNil()
		T.expect(LevelLock.bossEntry(60 + gap, 60)).toBe("dungeon.reason.overLevel")
		T.expect(LevelLock.bossEntry(55, 60)).toBeNil()
	end)
end)

return nil
