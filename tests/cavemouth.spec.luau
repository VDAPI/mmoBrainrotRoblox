--!strict
-- Studio review 2026-10-21 (Moss Cave on the Meadows: "the rocks look like smooth boxes"): the rock mouth of a cave on
-- a region map (Data/CaveMouth, World/Prefabs.caveMouth) is leaning slabs of Rock round the dark hole; none reaches
-- into the portal's arch or before the hole within the arch's width, the back slab closes the hole from behind.

local fs = require("@lune/fs")

local CaveMouth = require("../src/shared/Data/CaveMouth")
local PortalClearance = require("./PortalClearance")
local Portals = require("../src/shared/Data/Portals")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function half(size: { number }): { number }
	return { size[1] / 2, size[2] / 2, size[3] / 2 }
end

-- The corners of a slab in the portal's frame.
local function corners(slab: CaveMouth.Slab): { { number } }
	local m = CaveMouth.matrix(slab.r)
	local h = half(slab.size)
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local v = { sx * h[1], sy * h[2], sz * h[3] }
				table.insert(out, {
					slab.p[1] + m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
					slab.p[2] + m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
					slab.p[3] + m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
				})
			end
		end
	end
	return out
end

describe("Cave mouth: natural rock round the portal (studio review 2026-10-21)", function()
	local box = assert(Portals.clearance("cave"), "cave clearance")
	-- before the hole, as wide and tall as the arch's opening: what the player sees the portal against
	local view = {
		center = { 0, box.center[2], (-20 + CaveMouth.HOLE.p[3] - 0.2) / 2 },
		half = { box.half[1], box.half[2], (CaveMouth.HOLE.p[3] - 0.2 + 20) / 2 },
	}

	it("keeps every slab out of the arch and from before the hole", function()
		for i, slab in CaveMouth.SLABS do
			local m = CaveMouth.matrix(slab.r)
			for _, b in { box, view } do
				if PortalClearance.overlaps(slab.p, m, half(slab.size), b.center, b.half) then
					error(`slab {i} ({slab.name}) reaches into the arch or before the hole`)
				end
			end
		end
	end)

	it("keeps the pillars' boulders out of the arch and from before the hole", function()
		local B = CaveMouth.BOULDERS
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local r = (B.size - i) / 2
				local x = side * (B.x + i * B.step)
				-- a ball against an axis-aligned box: the nearest point of the box
				for _, b in { box, view } do
					local d2 = 0
					local c = { x, B.y0 + i * B.rise, B.z }
					for k = 1, 3 do
						local lo, hi = b.center[k] - b.half[k], b.center[k] + b.half[k]
						local q = math.clamp(c[k], lo, hi)
						d2 += (c[k] - q) ^ 2
					end
					expect(d2 > r * r).toBe(true)
				end
			end
		end
	end)

	it("closes the hole from behind and frames it on every side", function()
		local hole = CaveMouth.HOLE
		local back = hole.p[3] + hole.size[3] / 2
		local reach = { left = 0, right = 0, top = 0 }
		for _, slab in CaveMouth.SLABS do
			for _, c in corners(slab) do
				reach.left = math.min(reach.left, c[1])
				reach.right = math.max(reach.right, c[1])
				reach.top = math.max(reach.top, c[2])
			end
			if slab.name == "Back" then
				for _, c in corners(slab) do
					expect(c[3] > back).toBe(true)
				end
				-- wider and taller than the hole
				expect(slab.size[1] > hole.size[1] + 8 and slab.size[2] > hole.size[2] + 4).toBe(true)
			end
		end
		-- the old box reached 17 studs to each side and 26 up
		expect(reach.left < -17 and reach.right > 17 and reach.top > 26).toBe(true)
	end)

	it("is turned and shaded like rock, not one smooth box (Prefabs uses the slabs, Rock)", function()
		local turned, shades = 0, {}
		for _, slab in CaveMouth.SLABS do
			if math.abs(slab.r[1]) + math.abs(slab.r[2]) + math.abs(slab.r[3]) >= 3 then
				turned += 1
			end
			shades[slab.shade] = true
		end
		expect(turned).toBe(#CaveMouth.SLABS)
		expect(shades[-1] and shades[0] and shades[1]).toBe(true)
		local src = fs.readFile("src/server/World/Prefabs.luau")
		local from = assert(string.find(src, "function Prefabs.caveMouth(", 1, true))
		local body = string.sub(src, from, (string.find(src, "\nend\n", from, true)))
		expect(string.find(body, "CaveMouth.SLABS", 1, true) ~= nil).toBe(true)
		expect(string.find(body, "Enum.Material.Slate", 1, true)).toBe(nil)
		expect(string.find(body, "Enum.Material.Rock", 1, true) ~= nil).toBe(true)
	end)
end)

return nil
