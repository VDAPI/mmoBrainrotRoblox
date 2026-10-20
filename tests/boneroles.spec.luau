--!strict
-- W26: the bones of a four-legged rig get legs that trot, knees, a tail and a head; a winged one gets wings.
local T = require("./Test")
local BoneRoles = require("../src/shared/Logic/BoneRoles")

local function quadruped(): { BoneRoles.BoneIn }
	local b: { BoneRoles.BoneIn } = {
		{ name = "Root", pos = { 0, 0, 0 } },
		{ name = "Spine_0", parent = 1, pos = { 0, 1.9, 0.5 } },
		{ name = "Head_0", parent = 2, pos = { 0, 2.3, -1.2 } },
		{ name = "Tail_0", parent = 2, pos = { 0, 1.6, 1.4 } },
		{ name = "Tail_1", parent = 4, pos = { 0, 1.2, 1.7 } },
	}
	for _, leg in { { -0.4, -1 }, { 0.4, -1 }, { -0.4, 1 }, { 0.4, 1 } } do
		local x, z = leg[1], leg[2]
		table.insert(b, { name = "limb", parent = 2, pos = { x, 1.8, z } })
		table.insert(b, { name = "limb", parent = #b, pos = { x, 1.0, z } })
		table.insert(b, { name = "limb", parent = #b, pos = { x, 0.1, z } })
	end
	return b
end

T.describe("BoneRoles", function()
	T.it("finds four trotting legs with knees, a tail, a head and a spine", function()
		local roles = BoneRoles.classify(quadruped(), 3, 1.6, 0)
		local count: { [string]: number } = {}
		local phase: { [string]: number } = {}
		for _, r in roles do
			count[r.role] = (count[r.role] or 0) + 1
			if r.role == "leg" then
				phase[`{r.front}{r.side}`] = r.phase
			end
		end
		T.expect(count).toEqual({ leg = 4, knee = 4, tail = 2, head = 1, spine = 1 })
		-- diagonal pairs move together
		T.expect(phase["1-1"]).toBe(phase["-11"])
		T.expect(phase["11"]).toBe(phase["-1-1"])
		T.expect(phase["1-1"] ~= phase["11"]).toBe(true)
	end)

	T.it("finds wings far out and high", function()
		local b = quadruped()
		table.insert(b, { name = "w", parent = 2, pos = { -0.3, 2.2, 0 } })
		table.insert(b, { name = "w", parent = #b, pos = { -1.5, 2.6, 0 } })
		table.insert(b, { name = "w", parent = 2, pos = { 0.3, 2.2, 0 } })
		table.insert(b, { name = "w", parent = #b, pos = { 1.5, 2.6, 0 } })
		local wings = 0
		for _, r in BoneRoles.classify(b, 3, 3.2, 0) do
			if r.role == "wing" then
				wings += 1
			end
		end
		T.expect(wings).toBe(2)
	end)

	T.it("is still at rest", function()
		for _, r in BoneRoles.classify(quadruped(), 3, 1.6, 0) do
			if r.role == "leg" or r.role == "knee" then
				T.expect(BoneRoles.angle(r, 0, 0, 0, 0, 0, 0, 0)).toBe(0)
			end
		end
	end)
end)
