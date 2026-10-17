--!strict
-- W08: the base motion of player characters (Data/Locomotion, Logic/LocomotionPick).

local Locomotion = require("../src/shared/Data/Locomotion")
local LocomotionPick = require("../src/shared/Logic/LocomotionPick")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function isId(id: string): boolean
	return string.match(id, "^rbxassetid://%d+$") ~= nil
end

describe("Locomotion data (W08)", function()
	it("has a clip id for every state and valid fallbacks", function()
		for _, set in { Locomotion.clips, Locomotion.fallback } do
			for _, key in { "idle", "walk", "run", "jump", "fall", "climb", "swim", "swimIdle" } do
				local id = (set :: any)[key]
				expect(`{key} {isId(id)}`).toBe(`{key} true`)
			end
			expect(set.land == "" or isId(set.land)).toBe(true)
			for _, id in set.idleVariants do
				expect(isId(id)).toBe(true)
			end
		end
	end)

	it("keeps strides positive and the thresholds rising", function()
		for _, key in { "walk", "run", "climb", "swim" } do
			expect(((Locomotion.stride :: any)[key] :: number) > 0).toBe(true)
		end
		local b = Locomotion.blend
		expect(b.moving < b.walkUntil and b.walkUntil < b.runFrom).toBe(true)
		expect(b.rate[1] > 0 and b.rate[1] < 1 and b.rate[2] > 1).toBe(true)
		local v = Locomotion.idle.variantEvery
		expect(v[1] > 0 and v[1] < v[2]).toBe(true)
	end)
end)

describe("Locomotion pick (W08)", function()
	it("picks the clip of every state", function()
		expect(LocomotionPick.clip({ state = "ground", speed = 0 })).toBe("idle")
		expect(LocomotionPick.clip({ state = "ground", speed = 10 })).toBe("move")
		expect(LocomotionPick.clip({ state = "jump", speed = 10, airTime = 0.1 })).toBe("jump")
		expect(LocomotionPick.clip({ state = "jump", speed = 10, airTime = 2 })).toBe("fall")
		expect(LocomotionPick.clip({ state = "fall", speed = 0 })).toBe("fall")
		expect(LocomotionPick.clip({ state = "climb", speed = 4 })).toBe("climb")
		expect(LocomotionPick.clip({ state = "swim", speed = 8 })).toBe("swim")
		expect(LocomotionPick.clip({ state = "swim", speed = 0 })).toBe("swimIdle")
		expect(LocomotionPick.clip({ state = "dead", speed = 0 })).toBe("none")
		expect(LocomotionPick.clip({ state = "ground", speed = 16, mounted = true })).toBe("idle")
	end)

	it("blends walk into run monotonically with weights summing to 1", function()
		local lastRun = -1
		for v = 0, 30 do
			local b = LocomotionPick.blend(v)
			expect(math.abs(b.walk + b.run - 1) < 1e-9).toBe(true)
			expect(b.run >= lastRun).toBe(true)
			lastRun = b.run
			local r = Locomotion.blend.rate
			expect(b.walkSpeed >= r[1] and b.walkSpeed <= r[2]).toBe(true)
			expect(b.runSpeed >= r[1] and b.runSpeed <= r[2]).toBe(true)
		end
		expect(LocomotionPick.blend(Locomotion.blend.walkUntil - 1).run).toBe(0)
		expect(LocomotionPick.blend(Locomotion.blend.runFrom + 1).walk).toBe(0)
	end)

	it("lands only after a high fall (and only with a landing clip)", function()
		expect(LocomotionPick.lands(1)).toBe(false)
		expect(LocomotionPick.lands(Locomotion.air.landHeight + 5)).toBe(Locomotion.clips.land ~= "")
	end)

	it("allows an idle variant only standing, rested and out of combat", function()
		local due = LocomotionPick.variantDelay(0.5)
		local quiet = Locomotion.idle.combatQuiet
		local hasVariants = #Locomotion.clips.idleVariants > 0
		expect(LocomotionPick.variantAllowed("idle", due + 1, due, quiet + 1)).toBe(hasVariants)
		expect(LocomotionPick.variantAllowed("move", due + 1, due, quiet + 1)).toBe(false)
		expect(LocomotionPick.variantAllowed("idle", due - 1, due, quiet + 1)).toBe(false)
		expect(LocomotionPick.variantAllowed("idle", due + 1, due, quiet - 1)).toBe(false)
		local e = Locomotion.idle.variantEvery
		expect(LocomotionPick.variantDelay(0)).toBe(e[1])
		expect(LocomotionPick.variantDelay(1)).toBe(e[2])
	end)
end)
