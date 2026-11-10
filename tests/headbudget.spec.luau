--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"; code review 2026-11-10):
-- Logic/HeadBudget picks the looks of the monsters without bones that wear a turning head (the nearest within the
-- graphics level's radius, AnimLab's subject always; a dying look, a look out of the world and one that never can are
-- left out, so the next takes the place at once) and says when a look keeps and reads its model's head mesh: never on
-- the lowest level or beyond the radius, so nothing is read, skinned or kept there. client/Anim/MeshHead plays these
-- rules, builds the head's part with the look's own collision and lets go of a mesh that leaves the world.
local fs = require("@lune/fs")

local GraphicsLevel = require("../src/shared/Logic/GraphicsLevel")
local HeadBudget = require("../src/shared/Logic/HeadBudget")
local T = require("./Test")

-- (client/Anim/MeshHead's)
local HYSTERESIS = 10

local function look(d: number, over: { [string]: any }?): HeadBudget.Look
	local made: { [string]: any } = { d = d, wanted = false, lab = false, dying = false, present = true, off = false }
	for key, value in over or {} do
		made[key] = value
	end
	return made :: any
end

-- The indices `quality` wants of `looks`, in order.
local function picked(looks: { HeadBudget.Look }, quality: string): { number }
	local level = GraphicsLevel.get(quality)
	local out = {}
	for i in HeadBudget.pick(looks, level.heads, level.headRadius, HYSTERESIS) do
		table.insert(out, i)
	end
	table.sort(out)
	return out
end

T.describe("HeadBudget: the looks that wear a head", function()
	T.it("the lowest level wants none, however near, so no look keeps or reads a mesh there", function()
		local looks = { look(0), look(3), look(12, { wanted = true }), look(40) }
		T.expect(picked(looks, "low")).toEqual({})
		for _, state in { "rest", "waiting" } do
			T.expect(HeadBudget.keeps(state, false)).toBe(false)
		end
		-- (AnimLab's subject still shows it)
		T.expect(picked({ look(0), look(5, { lab = true }) }, "low")).toEqual({ 2 })
	end)

	T.it("the nearest few within the radius; one already wearing it counts nearer", function()
		local medium = GraphicsLevel.get("medium")
		local looks = {}
		for k = 1, medium.heads + 2 do
			table.insert(looks, look(k * medium.headRadius / (medium.heads + 1)))
		end
		local want = {}
		for k = 1, medium.heads do
			table.insert(want, k)
		end
		T.expect(picked(looks, "medium")).toEqual(want)
		-- past the radius never (unless already wearing it, within the hysteresis)
		T.expect(picked({ look(medium.headRadius + 5) }, "medium")).toEqual({})
		T.expect(picked({ look(medium.headRadius + 5, { wanted = true }) }, "medium")).toEqual({ 1 })
		T.expect(picked({ look(medium.headRadius + HYSTERESIS + 1, { wanted = true }) }, "medium")).toEqual({})
		-- the last place: a look wearing it at 45 keeps it from a new one at 38
		local full = {}
		for k = 1, medium.heads - 1 do
			table.insert(full, look(k))
		end
		table.insert(full, look(45, { wanted = true }))
		table.insert(full, look(38))
		T.expect(picked(full, "medium")[medium.heads]).toBe(medium.heads)
	end)

	T.it("a dying look gives its place up at once: the next look takes it", function()
		local medium = GraphicsLevel.get("medium")
		local looks = {}
		for k = 1, medium.heads + 1 do
			table.insert(looks, look(k * 10, { wanted = k <= medium.heads }))
		end
		looks[1] = look(10, { wanted = true, dying = true })
		local got = picked(looks, "medium")
		T.expect(table.find(got, 1)).toBeNil()
		T.expect(table.find(got, medium.heads + 1) ~= nil).toBe(true)
		T.expect(#got).toBe(medium.heads)
	end)

	T.it("a look out of the world (streamed out, destroyed) and one that never can hold no place", function()
		local high = GraphicsLevel.get("high")
		local looks = { look(2, { wanted = true, present = false }), look(3, { off = true }) }
		for k = 1, high.heads do
			table.insert(looks, look(10 + k))
		end
		local got = picked(looks, "high")
		T.expect(#got).toBe(high.heads)
		T.expect(table.find(got, 1)).toBeNil()
		T.expect(table.find(got, 2)).toBeNil()
	end)

	T.it("AnimLab's subject always and outside the count, unless it dies or is gone", function()
		local medium = GraphicsLevel.get("medium")
		local looks = { look(500, { lab = true }) }
		for k = 1, medium.heads do
			table.insert(looks, look(k))
		end
		T.expect(#picked(looks, "medium")).toBe(medium.heads + 1)
		T.expect(picked({ look(0, { lab = true, dying = true }) }, "high")).toEqual({})
		T.expect(picked({ look(0, { lab = true, present = false }) }, "high")).toEqual({})
	end)
end)

T.describe("HeadBudget: a look's entry, a failed model", function()
	T.it("a look's entry carries what its handle knows: state, last pass, lab, dying, presence, distance", function()
		T.expect(HeadBudget.look("rest", true, false, true, true, 12))
			.toEqual({ d = 12, wanted = true, lab = false, dying = true, present = true, off = false })
		T.expect(HeadBudget.look("live", false, true, false, false, math.huge))
			.toEqual({ d = math.huge, wanted = false, lab = true, dying = false, present = false, off = false })
		for _, state in { "rest", "waiting", "live" } do
			T.expect(HeadBudget.look(state, true, false, false, true, 1).off).toBe(false)
		end
		T.expect(HeadBudget.look("off", true, true, false, true, 1).off).toBe(true)
	end)

	T.it("through the entries a corpse, a look streamed out and one that never can leave their places", function()
		-- (MeshHead's handles: a look out of Workspace is measured at math.huge)
		local medium = GraphicsLevel.get("medium")
		local handles = {
			{ state = "live", wanted = true, dying = true, present = true, d = 5 }, -- a corpse
			{ state = "rest", wanted = true, dying = false, present = false, d = math.huge }, -- streamed out
			{ state = "off", wanted = false, dying = false, present = true, d = 8 }, -- its model failed
		}
		for k = 1, medium.heads + 1 do
			table.insert(handles, { state = "rest", wanted = false, dying = false, present = true, d = 10 + 5 * k })
		end
		local entries = {}
		for _, h in handles do
			table.insert(entries, HeadBudget.look(h.state, h.wanted, false, h.dying, h.present, h.d))
		end
		local got = HeadBudget.pick(entries, medium.heads, medium.headRadius, HYSTERESIS)
		local want = {}
		for k = 1, medium.heads do
			want[3 + k] = true
		end
		T.expect(got).toEqual(want)
	end)

	T.it("a failed model's looks at rest or waiting go off and their places go to another model's looks", function()
		T.expect(HeadBudget.quits("rest")).toBe(true)
		T.expect(HeadBudget.quits("waiting")).toBe(true)
		-- (one wearing it turns on until it takes it off; one off is off)
		T.expect(HeadBudget.quits("live")).toBe(false)
		T.expect(HeadBudget.quits("off")).toBe(false)
		-- model a fails with three looks nearest the camera (one wearing the head) and one beyond the radius
		local medium = GraphicsLevel.get("medium")
		local handles = {
			{ model = "a", state = "waiting", wanted = true, d = 5 },
			{ model = "a", state = "rest", wanted = true, d = 6 },
			{ model = "a", state = "live", wanted = true, d = 7 },
			{ model = "a", state = "rest", wanted = false, d = medium.headRadius + 30 },
		}
		for k = 1, medium.heads do
			table.insert(handles, { model = "b", state = "rest", wanted = false, d = 10 * k })
		end
		for _, h in handles do
			if h.model == "a" and HeadBudget.quits(h.state) then
				h.state, h.wanted = "off", false
			end
		end
		local entries = {}
		for _, h in handles do
			table.insert(entries, HeadBudget.look(h.state, h.wanted, false, false, true, h.d))
		end
		local got = HeadBudget.pick(entries, medium.heads, medium.headRadius, HYSTERESIS)
		-- a's head still on keeps its place, b's nearest take the others
		local want = { [3] = true }
		for k = 1, medium.heads - 1 do
			want[4 + k] = true
		end
		T.expect(got).toEqual(want)
		T.expect(handles[4].state).toBe("off")
	end)
end)

T.describe("HeadBudget: the model's mesh", function()
	T.it("a look keeps it while it wears it or is wanted, never when it cannot wear it", function()
		T.expect(HeadBudget.keeps("rest", true)).toBe(true)
		T.expect(HeadBudget.keeps("waiting", true)).toBe(true)
		T.expect(HeadBudget.keeps("live", true)).toBe(true)
		-- (out of the budget, still wearing it until its head is back at rest)
		T.expect(HeadBudget.keeps("live", false)).toBe(true)
		T.expect(HeadBudget.keeps("rest", false)).toBe(false)
		T.expect(HeadBudget.keeps("waiting", false)).toBe(false)
		T.expect(HeadBudget.keeps("off", true)).toBe(false)
		T.expect(HeadBudget.keeps("off", false)).toBe(false)
	end)

	T.it("the first look keeping it reads one not read yet or freed, and a failed one once its retry is due", function()
		T.expect(HeadBudget.reads("cold", nil, 0)).toBe(true)
		T.expect(HeadBudget.reads("loading", nil, 0)).toBe(false)
		T.expect(HeadBudget.reads("ready", nil, 0)).toBe(false)
		T.expect(HeadBudget.reads("failed", nil, 1e9)).toBe(false)
		T.expect(HeadBudget.reads("failed", 30, 29.9)).toBe(false)
		T.expect(HeadBudget.reads("failed", 30, 30)).toBe(true)
	end)

	T.it("walking past a pack: kept only while a look is near, never on the lowest level", function()
		-- six looks of one model in a row; the camera walks by 30 studs to the side
		local spots = { -25, -15, -5, 5, 15, 25 }
		for _, quality in { "low", "medium", "high" } do
			local level = GraphicsLevel.get(quality)
			local wanted = { false, false, false, false, false, false }
			local kept, most, nearest = 0, 0, math.huge
			for x = -300, 300, 5 do
				local looks = {}
				for i, at in spots do
					local d = math.sqrt((at - x) ^ 2 + 30 ^ 2)
					nearest = math.min(nearest, d)
					table.insert(looks, look(d, { wanted = wanted[i] }))
				end
				local got = HeadBudget.pick(looks, level.heads, level.headRadius, HYSTERESIS)
				local holders = 0
				for i in spots do
					wanted[i] = got[i] == true
					if HeadBudget.keeps("rest", wanted[i]) then
						holders += 1
					end
				end
				if holders > 0 then
					kept += 1
				end
				most = math.max(most, holders)
				-- far off, none
				if math.abs(x) > 25 + level.headRadius + HYSTERESIS then
					T.expect(holders).toBe(0)
				end
			end
			T.expect(nearest < 31).toBe(true)
			if quality == "low" then
				T.expect(kept).toBe(0)
			else
				T.expect(kept > 0).toBe(true)
				T.expect(most).toBe(math.min(level.heads, #spots))
			end
		end
	end)
end)

T.describe("HeadBudget: client/Anim/MeshHead", function()
	local src: string? = nil
	local function has(text: string): boolean
		src = src or fs.readFile("src/client/Anim/MeshHead.luau")
		return string.find(src :: string, text, 1, true) ~= nil
	end

	T.it("picks, keeps and reads by these rules, each look's dying flag taken from its frame", function()
		T.expect(has(`local HYSTERESIS = {HYSTERESIS}`)).toBe(true)
		T.expect(has("HeadBudget.pick(list, level.heads, level.headRadius, HYSTERESIS)")).toBe(true)
		T.expect(has("HeadBudget.keeps(h.state, h.wanted)")).toBe(true)
		T.expect(has("HeadBudget.reads(shared.state, shared.retryAt, os.clock())")).toBe(true)
		T.expect(has("h.dying = dying")).toBe(true)
	end)

	T.it("gives each handle its entry with what it knows and turns a failed model's waiting looks off", function()
		-- (the entry's every field from the handle: a corpse, a look out of the world and one off hold no place)
		T.expect(has("local present = h.mesh:IsDescendantOf(Workspace)")).toBe(true)
		T.expect(has("table.insert(list, HeadBudget.look(h.state, h.wanted, h.lab, h.dying, present, d))")).toBe(true)
		T.expect(has("h.wanted = wanted[i] == true")).toBe(true)
		src = src or fs.readFile("src/client/Anim/MeshHead.luau")
		local failing = string.match(src :: string, "local function fail%(.-\nend\n")
		T.expect(failing ~= nil).toBe(true)
		local turnsOff = "h%.shared == shared and HeadBudget%.quits%(h%.state%) then%s+off%(h, why%)"
		T.expect(string.find(failing or "", turnsOff) ~= nil).toBe(true)
	end)

	T.it("builds the head's part with the look's own collision: a live head takes the clicks its look took", function()
		T.expect(has("mesh.CollisionFidelity")).toBe(true)
		T.expect(has("CollisionFidelity = collision,")).toBe(true)
		T.expect(has("Enum.CollisionFidelity")).toBe(false)
	end)

	T.it("lets go of its model's mesh when the look's leaves the world", function()
		T.expect(has("mesh.AncestryChanged:Connect(")).toBe(true)
		T.expect(has("if not mesh:IsDescendantOf(game) then")).toBe(true)
		T.expect(has("if h.shared.holders[h] and not h.mesh:IsDescendantOf(game) then")).toBe(true)
	end)
end)
